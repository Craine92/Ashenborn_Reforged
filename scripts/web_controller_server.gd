class_name WebControllerServer
extends Node

signal card_selected(index: int)
signal player_selected(player_id: String, index: int)
signal connection_changed(connected: bool)
signal players_changed(players: Array)
signal player_connection_changed(player_id: String, connected: bool)

const DEFAULT_HTTP_PORT := 8765
const DEFAULT_WS_PORT := 8766
const MAX_REQUEST_BYTES := 8192
const MAX_ACTIVE_PLAYERS := 2

var http_port := DEFAULT_HTTP_PORT
var websocket_port := DEFAULT_WS_PORT
var is_running := false
var state_provider := Callable()
var public_state_provider := Callable()
var private_state_provider := Callable()

var _http_server := TCPServer.new()
var _websocket_server := TCPServer.new()
var _http_clients: Array[Dictionary] = []
var _websocket_clients: Array[Dictionary] = []
var _player_slots: Dictionary = {}
var _art_cache: Dictionary = {}
var _smartphone_connected := false
var _match_active := false
var _match_player_ids: Array[String] = []
var _last_roster_json := ""
var _crypto := Crypto.new()


func start(custom_http_port: int = DEFAULT_HTTP_PORT, custom_ws_port: int = DEFAULT_WS_PORT) -> bool:
	http_port = custom_http_port
	websocket_port = custom_ws_port
	var http_error := _http_server.listen(http_port, "0.0.0.0")
	var ws_error := _websocket_server.listen(websocket_port, "0.0.0.0")
	if http_error != OK or ws_error != OK:
		stop()
		push_error("Webcontroller konnte Ports %d/%d nicht öffnen." % [http_port, websocket_port])
		return false
	is_running = true
	set_process(true)
	return true


func stop() -> void:
	_http_server.stop()
	_websocket_server.stop()
	_http_clients.clear()
	_websocket_clients.clear()
	_player_slots.clear()
	_match_player_ids.clear()
	_match_active = false
	is_running = false
	set_process(false)
	_set_smartphone_connected(false)
	_emit_roster_if_changed()


func begin_match(player_ids: Array[String]) -> void:
	_match_active = true
	_match_player_ids = player_ids.duplicate()
	for player_id in _player_slots:
		var slot: Dictionary = _player_slots[player_id]
		if not _match_player_ids.has(player_id):
			slot["role"] = "spectator"
	_emit_roster_if_changed()


func end_match() -> void:
	_match_active = false
	_match_player_ids.clear()
	for player_id in _player_slots:
		_player_slots[player_id]["role"] = "player"
	_emit_roster_if_changed()


func controller_url() -> String:
	var address := local_network_address()
	return "" if address.is_empty() else "http://%s:%d" % [address, http_port]


func local_network_address() -> String:
	var fallback := ""
	for address in IP.get_local_addresses():
		if not address.contains(".") or address.begins_with("127.") or address.begins_with("169.254.") or address == "0.0.0.0":
			continue
		if address.begins_with("192.168.") or address.begins_with("10.") or _is_private_172(address):
			return address
		if fallback.is_empty():
			fallback = address
	return fallback


func has_network_address() -> bool:
	return not local_network_address().is_empty()


func is_smartphone_connected() -> bool:
	return _smartphone_connected


func connected_player_count() -> int:
	return get_active_player_ids().size()


func get_active_player_ids() -> Array[String]:
	var result: Array[String] = []
	for index in MAX_ACTIVE_PLAYERS:
		var player_id := "player_%d" % (index + 1)
		if not _player_slots.has(player_id):
			continue
		var slot: Dictionary = _player_slots[player_id]
		if slot.get("connected", false) and slot.get("role", "player") == "player":
			result.append(player_id)
	return result


func lobby_players() -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	for index in MAX_ACTIVE_PLAYERS:
		var player_id := "player_%d" % (index + 1)
		var slot: Dictionary = _player_slots.get(player_id, {})
		roster.append({
			"id": player_id,
			"display_name": "Spieler %d" % (index + 1),
			"connected": slot.get("connected", false) and slot.get("role", "player") == "player",
		})
	return roster


func broadcast_state() -> void:
	if not is_running:
		return
	for entry: Dictionary in _websocket_clients:
		if entry.get("authenticated", false):
			_send_state(entry)


func _process(_delta: float) -> void:
	if not is_running:
		return
	_accept_http_clients()
	_accept_websocket_clients()
	_poll_http_clients()
	_poll_websocket_clients()


func _accept_http_clients() -> void:
	while _http_server.is_connection_available():
		var peer := _http_server.take_connection()
		_http_clients.append({"peer": peer, "buffer": PackedByteArray(), "age": 0})


func _accept_websocket_clients() -> void:
	while _websocket_server.is_connection_available():
		var tcp := _websocket_server.take_connection()
		var socket := WebSocketPeer.new()
		if socket.accept_stream(tcp) == OK:
			_websocket_clients.append({
				"socket": socket,
				"tcp": tcp,
				"opened": false,
				"authenticated": false,
				"player_id": "",
				"token": "",
				"role": "spectator",
			})


func _poll_http_clients() -> void:
	for index in range(_http_clients.size() - 1, -1, -1):
		var entry: Dictionary = _http_clients[index]
		var peer: StreamPeerTCP = entry["peer"]
		peer.poll()
		entry["age"] = int(entry["age"]) + 1
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED and peer.get_available_bytes() > 0:
			var received := peer.get_data(peer.get_available_bytes())
			if received[0] == OK:
				var buffer: PackedByteArray = entry["buffer"]
				buffer.append_array(received[1])
				entry["buffer"] = buffer
				if buffer.size() > MAX_REQUEST_BYTES:
					_send_text(peer, 413, "Anfrage zu groß")
					_http_clients.remove_at(index)
					continue
				var request := buffer.get_string_from_utf8()
				if request.contains("\r\n\r\n"):
					_handle_http_request(peer, request)
					_http_clients.remove_at(index)
					continue
		if peer.get_status() in [StreamPeerTCP.STATUS_ERROR, StreamPeerTCP.STATUS_NONE] or int(entry["age"]) > 300:
			_http_clients.remove_at(index)


func _poll_websocket_clients() -> void:
	for index in range(_websocket_clients.size() - 1, -1, -1):
		var entry: Dictionary = _websocket_clients[index]
		var socket: WebSocketPeer = entry["socket"]
		socket.poll()
		var ready := socket.get_ready_state()
		if ready == WebSocketPeer.STATE_OPEN:
			entry["opened"] = true
			while socket.get_available_packet_count() > 0:
				_handle_websocket_message(entry, socket.get_packet().get_string_from_utf8())
		elif ready == WebSocketPeer.STATE_CLOSED:
			_disconnect_entry(entry)
			_websocket_clients.remove_at(index)
	_refresh_connection_state()


func _handle_websocket_message(entry: Dictionary, message: String) -> void:
	var parsed = JSON.parse_string(message)
	var socket: WebSocketPeer = entry["socket"]
	if typeof(parsed) != TYPE_DICTIONARY:
		_send_socket_error(socket, "Ungültige Nachricht")
		return
	var message_type := String(parsed.get("type", ""))
	if message_type == "hello":
		_authenticate_entry(entry, String(parsed.get("token", "")))
		return
	if message_type != "select" or not entry.get("authenticated", false):
		_send_socket_error(socket, "Zuerst anmelden")
		return
	if entry.get("role", "spectator") != "player":
		_send_socket_error(socket, "Zuschauer können keine Upgrades wählen")
		return
	var player_id := String(entry.get("player_id", ""))
	if _match_active and not _match_player_ids.has(player_id):
		_send_socket_error(socket, "Dieses Gerät nimmt nicht an der Partie teil")
		return
	var index := int(parsed.get("index", -1))
	player_selected.emit(player_id, index)
	_send_state(entry)


func _authenticate_entry(entry: Dictionary, requested_token: String) -> void:
	if entry.get("authenticated", false):
		return
	var player_id := _player_id_for_token(requested_token)
	var token := requested_token
	var role := "player"
	if player_id.is_empty():
		var available_player_id := _available_player_id()
		if _match_active or available_player_id.is_empty():
			role = "spectator"
			token = _new_token()
		else:
			player_id = available_player_id
			token = _new_token()
			_player_slots[player_id] = {
				"id": player_id,
				"display_name": "Spieler %s" % player_id.trim_prefix("player_"),
				"token": token,
				"connected": false,
				"socket": null,
				"role": "player",
			}
	elif _match_active and not _match_player_ids.has(player_id):
		role = "spectator"
	entry["authenticated"] = true
	entry["player_id"] = player_id
	entry["token"] = token
	entry["role"] = role
	if role == "player" and _player_slots.has(player_id):
		var slot: Dictionary = _player_slots[player_id]
		var old_socket: WebSocketPeer = slot.get("socket")
		if old_socket != null and old_socket != entry["socket"] and old_socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			old_socket.close(4001, "Identität auf neuem Gerät wiederhergestellt")
		slot["connected"] = true
		slot["socket"] = entry["socket"]
		slot["role"] = role
		player_connection_changed.emit(player_id, true)
	var socket: WebSocketPeer = entry["socket"]
	socket.send_text(JSON.stringify({
		"type": "welcome",
		"token": token,
		"player_id": player_id,
		"display_name": _display_name(player_id) if role == "player" else "Zuschauer",
		"role": role,
	}))
	_send_state(entry)
	_refresh_connection_state()


func _disconnect_entry(entry: Dictionary) -> void:
	if not entry.get("authenticated", false) or entry.get("role", "spectator") != "player":
		return
	var player_id := String(entry.get("player_id", ""))
	if not _player_slots.has(player_id):
		return
	var slot: Dictionary = _player_slots[player_id]
	if slot.get("socket") == entry.get("socket"):
		slot["connected"] = false
		slot["socket"] = null
		player_connection_changed.emit(player_id, false)


func _handle_http_request(peer: StreamPeerTCP, request: String) -> void:
	var first_line := request.get_slice("\r\n", 0)
	var parts := first_line.split(" ")
	if parts.size() < 2:
		_send_text(peer, 400, "Ungültige Anfrage")
		return
	var target: String = parts[1]
	var path := target.get_slice("?", 0)
	if path == "/" or path == "/index.html":
		_send_response(peer, 200, "text/html; charset=utf-8", _controller_html().to_utf8_buffer())
	elif path == "/api/state":
		_send_response(peer, 200, "application/json; charset=utf-8", JSON.stringify(_public_state()).to_utf8_buffer())
	elif path == "/api/select":
		_send_text(peer, 405, "Auswahl ist ausschließlich über die gebundene WebSocket-Verbindung erlaubt")
	elif path.begins_with("/asset/"):
		_serve_card_art(peer, path.trim_prefix("/asset/"))
	else:
		_send_text(peer, 404, "Nicht gefunden")


func _serve_card_art(peer: StreamPeerTCP, card_id: String) -> void:
	var card := AbilityDatabase.get_ability(card_id)
	if card.is_empty():
		card = CardDatabase.get_card(card_id)
	if card.is_empty():
		card = HeroDatabase.get_hero(card_id)
	if card.is_empty():
		_send_text(peer, 404, "Bild nicht gefunden")
		return
	var bytes: PackedByteArray = _art_cache.get(card_id, PackedByteArray())
	if bytes.is_empty():
		var texture: Texture2D = load(card["artwork"])
		var image: Image = null if texture == null else texture.get_image()
		if image == null or image.is_empty():
			_send_text(peer, 404, "Bild nicht gefunden")
			return
		var scale_factor := minf(360.0 / float(image.get_width()), 540.0 / float(image.get_height()))
		image.resize(maxi(1, roundi(image.get_width() * scale_factor)), maxi(1, roundi(image.get_height() * scale_factor)), Image.INTERPOLATE_LANCZOS)
		bytes = image.save_jpg_to_buffer(0.82)
		_art_cache[card_id] = bytes
	_send_response(peer, 200, "image/jpeg", bytes, "public, max-age=3600")


func _send_state(entry: Dictionary) -> void:
	var socket: WebSocketPeer = entry["socket"]
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var state := _public_state()
	if entry.get("role", "spectator") == "player":
		state = _private_state(String(entry.get("player_id", "")))
	socket.send_text(JSON.stringify({"type": "state", "state": state}))


func _public_state() -> Dictionary:
	if public_state_provider.is_valid():
		return public_state_provider.call()
	if state_provider.is_valid():
		var state: Dictionary = state_provider.call()
		state["hand"] = []
		state["can_select"] = false
		state.erase("player")
		return state
	return {}


func _private_state(player_id: String) -> Dictionary:
	if private_state_provider.is_valid():
		return private_state_provider.call(player_id)
	if state_provider.is_valid():
		return state_provider.call()
	return {}


func _send_socket_error(socket: WebSocketPeer, message: String) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify({"type": "error", "message": message}))


func _send_text(peer: StreamPeerTCP, status: int, body: String) -> void:
	_send_response(peer, status, "text/plain; charset=utf-8", body.to_utf8_buffer())


func _send_response(peer: StreamPeerTCP, status: int, content_type: String, body: PackedByteArray, cache_control: String = "no-store") -> void:
	var reason := "OK" if status == 200 else "Error"
	var headers := "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: %s\r\nConnection: close\r\n\r\n" % [status, reason, content_type, body.size(), cache_control]
	var response := headers.to_utf8_buffer()
	response.append_array(body)
	peer.put_data(response)
	peer.disconnect_from_host()


func _refresh_connection_state() -> void:
	var connected := false
	for entry: Dictionary in _websocket_clients:
		var socket: WebSocketPeer = entry["socket"]
		if socket.get_ready_state() == WebSocketPeer.STATE_OPEN and entry.get("authenticated", false):
			connected = true
			break
	_set_smartphone_connected(connected)
	_emit_roster_if_changed()


func _set_smartphone_connected(connected: bool) -> void:
	if _smartphone_connected == connected:
		return
	_smartphone_connected = connected
	connection_changed.emit(connected)


func _emit_roster_if_changed() -> void:
	var roster := lobby_players()
	var serialized := JSON.stringify(roster)
	if serialized == _last_roster_json:
		return
	_last_roster_json = serialized
	players_changed.emit(roster)


func _player_id_for_token(token: String) -> String:
	if token.is_empty():
		return ""
	for player_id in _player_slots:
		if _player_slots[player_id].get("token", "") == token:
			return player_id
	return ""


func _next_player_id() -> String:
	for index in MAX_ACTIVE_PLAYERS:
		var candidate := "player_%d" % (index + 1)
		if not _player_slots.has(candidate):
			return candidate
	return ""


func _available_player_id() -> String:
	var unused := _next_player_id()
	if not unused.is_empty():
		return unused
	for index in MAX_ACTIVE_PLAYERS:
		var player_id := "player_%d" % (index + 1)
		if _player_slots.has(player_id) and not _player_slots[player_id].get("connected", false):
			return player_id
	return ""


func _display_name(player_id: String) -> String:
	return String(_player_slots.get(player_id, {}).get("display_name", player_id))


func _new_token() -> String:
	return _crypto.generate_random_bytes(16).hex_encode()


func _is_private_172(address: String) -> bool:
	if not address.begins_with("172."):
		return false
	var parts := address.split(".")
	return parts.size() == 4 and int(parts[1]) >= 16 and int(parts[1]) <= 31


func _controller_html() -> String:
	return CONTROLLER_HTML.replace("__WS_PORT__", str(websocket_port))


const CONTROLLER_HTML := """<!doctype html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"><title>Ashenborn Controller</title>
<style>
:root{color-scheme:dark;--ink:#06080d;--cyan:#55cfe4;--gold:#dfb763;--muted:#9ca8b8;--player:#55cfe4}*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}html,body{margin:0;width:100%;height:100%;overflow:hidden;background:radial-gradient(circle at 50% -10%,#1b3445 0,#0b1119 38%,#06080d 78%);color:#f5f0e6;font-family:system-ui,-apple-system,sans-serif}main{width:100%;min-width:0;height:100dvh;overflow:hidden;display:grid;grid-template-rows:auto auto auto auto auto minmax(0,1fr) auto;gap:7px;padding:max(8px,env(safe-area-inset-top)) 10px max(8px,env(safe-area-inset-bottom));max-width:600px;margin:auto}header{display:flex;align-items:center;justify-content:space-between;min-height:22px}h1{font-family:Georgia,serif;font-size:15px;letter-spacing:.15em;margin:0;color:var(--cyan)}#status{font-size:10px;color:var(--muted)}#identity{min-width:0;overflow:hidden;overflow-wrap:anywhere;text-align:center;padding:7px 8px;border:1px solid var(--player);border-radius:8px;color:var(--player);font-family:Georgia,serif;font-size:clamp(15px,4.1vw,21px);font-weight:800;letter-spacing:.04em;background:#0b111be8}.stats{min-width:0;display:grid;grid-template-columns:repeat(3,minmax(0,1fr));background:#0c121ae8;border-bottom:1px solid #9c744a88;border-radius:9px;overflow:hidden}.stat{padding:5px 3px;text-align:center;font-size:9px;letter-spacing:.08em;color:var(--muted);min-width:0}.stat+.stat{border-left:1px solid #ffffff12}.stat b{display:block;color:#fff;font-size:17px;margin-top:1px}#intent{min-width:0;overflow-wrap:anywhere;padding:7px 9px;border-left:3px solid var(--gold);border-radius:7px;background:#18120de8;color:var(--gold);font-size:11px;font-weight:800;letter-spacing:.035em;text-align:center}#intent.targeted{border-color:var(--player);color:var(--player)}#build{min-width:0;border:1px solid color-mix(in srgb,var(--player) 55%,transparent);border-radius:8px;background:#0b111be8;color:#fff;overflow:hidden}#build summary{cursor:pointer;list-style:none;padding:7px 10px;color:var(--player);font-size:12px;font-weight:800;letter-spacing:.08em}#build summary::-webkit-details-marker{display:none}#build summary:after{content:' ＋';float:right}#build[open] summary:after{content:' −'}#build[open]{max-height:24vh;overflow-y:auto}#buildList{padding:0 9px 8px}.ability,.synergy{padding:6px 0;border-top:1px solid #ffffff12;font-size:11px;line-height:1.25}.ability b{color:var(--rarity);font-size:12px}.synergy b{color:var(--cyan);font-size:12px}.ability .effect,.synergy span{display:block;color:#e3e7ed;margin-top:2px}.ability .trigger{display:block;color:var(--gold);margin-top:2px}.synergyTitle{color:var(--cyan);font-size:10px;font-weight:900;letter-spacing:.08em;padding-top:7px}.empty{color:var(--muted);font-size:11px;padding:3px 0}#cards{min-width:0;min-height:0;display:grid;grid-template-columns:repeat(3,minmax(0,1fr));align-items:center;gap:clamp(5px,1.8vw,9px);padding:2px 0}.card{position:relative;width:100%;aspect-ratio:2/3;min-width:0;border:2px solid var(--rarity);border-radius:12px;overflow:hidden;background:#080c12;box-shadow:0 9px 22px #0009;padding:0;color:#fff;text-align:left}.card.selected{transform:translateY(-5px);border-width:4px;filter:brightness(1.12)}.card:disabled{filter:saturate(.6) brightness(.72)}.card img{position:absolute;inset:0;width:100%;height:100%;object-fit:contain;object-position:center;background:#080c12}.info{position:absolute;z-index:1;left:0;right:0;bottom:0;padding:26px 7px 7px;background:linear-gradient(transparent,#090d13ee 25%,#090d13 52%);text-shadow:0 2px 3px #000}.name{display:block;font-family:Georgia,serif;font-size:clamp(10px,2.9vw,15px);line-height:1.05;overflow-wrap:anywhere}.desc{display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;min-height:2.25em;margin-top:3px;color:#d7dce4;font-size:clamp(8px,2.05vw,11px);line-height:1.12}.meta{display:flex;justify-content:space-between;gap:3px;margin-top:5px;font-size:clamp(9px,2.45vw,12px);color:var(--rarity)}.rank{color:var(--gold);font-weight:800;text-align:right}#action{min-height:34px;display:grid;place-items:center}#hint{text-align:center;color:var(--player);font-size:12px;font-weight:700}#overlay{position:fixed;inset:0;background:#06080df2;display:none;place-items:center;padding:25px;text-align:center;z-index:5}#overlay.show{display:grid}.wait{font-family:Georgia,serif;color:var(--player);font-size:25px}.small{color:var(--muted);font-size:14px;margin-top:12px}@media(max-height:590px){main{padding:5px;gap:4px}#identity{padding:4px;font-size:14px}.stat{padding:3px}.stat b{font-size:15px}#intent{padding:4px;font-size:9px}#build summary{padding:5px 8px}.info{padding:20px 5px 5px}}@media(max-width:340px){main{padding-left:6px;padding-right:6px}.info{padding-left:4px;padding-right:4px}.name{font-size:9px}.desc,.meta{font-size:7px}}
</style></head><body><main><header><h1>ASHENBORN</h1><span id="status">VERBINDE …</span></header><div id="identity">IDENTITÄT WIRD GELADEN</div><section class="stats"><div class="stat">MORVATH<b id="boss">—</b></div><div class="stat">RUNDE<b id="round">—</b></div><div class="stat">MEINE LP<b id="player">—</b></div></section><div id="intent">MORVATHS ABSICHT WIRD GELESEN …</div><details id="build"><summary>MEIN BUILD</summary><div id="buildList"><div class="empty">Noch keine Fähigkeiten.</div></div></details><section id="cards"></section><section id="action"><div id="hint">Spiel wird geladen …</div></section></main><div id="overlay"><div><div class="wait" id="waitTitle">VERBINDE</div><div class="small" id="waitText">Identität wird geladen …</div></div></div>
<script>
const colors={common:'#55c271',rare:'#4b91e2',epic:'#a868e8',legendary:'#e9b94c'};let socket,state,locked=true,role='spectator',selectedLabel='';const el=id=>document.getElementById(id);
function renderBuild(p){const list=el('buildList'),hero=p.hero||{},abilities=hero.abilities||[],synergies=hero.synergies||[];list.replaceChildren();if(!abilities.length&&!synergies.length){list.innerHTML='<div class="empty">Noch keine Fähigkeiten.</div>';return}abilities.forEach(a=>{const row=document.createElement('div');row.className='ability';row.style.setProperty('--rarity',colors[a.rarity]||colors.common);row.innerHTML=`<b>${a.name} · RANG ${a.rank}</b><span class="effect">${a.effect_text||''}</span>${a.trigger_text?`<span class="trigger">${a.trigger_text}</span>`:''}`;list.appendChild(row)});if(synergies.length){const title=document.createElement('div');title.className='synergyTitle';title.textContent='AKTIVE SYNERGIEN';list.appendChild(title);synergies.forEach(s=>{const row=document.createElement('div');row.className='synergy';row.innerHTML=`<b>${s.name}</b><span>${s.requirements_text}</span><span>${s.effect_text}</span>`;list.appendChild(row)})}}
function renderIntent(s,p){const i=s.boss_intent||{},node=el('intent'),targeted=i.target_player_id===p.id;node.classList.toggle('targeted',targeted);node.textContent='MORVATH · '+(i.display_text||i.name||'UNBEKANNT')+(targeted?' · DU BIST DAS ZIEL':'')}
function ownTriggers(s,p){const attacks=((s.combat||{}).attacks||[]),own=attacks.find(a=>a.player_id===p.id)||attacks[0];return own&&own.triggered_effects&&own.triggered_effects.length?own.triggered_effects.join(' · '):'SCHAU AUF DEN TV'}
function render(s){state=s;const p=s.player||{},spectating=role==='spectator';locked=!s.can_select;const playerColor='#'+(p.color||'55cfe4');document.documentElement.style.setProperty('--player',spectating?'#dfb763':playerColor);el('identity').textContent=spectating?'ZUSCHAUER':((p.display_name||'SPIELER')+' – '+(((p.hero||{}).name)||'ASCHENRITTER')).toUpperCase();el('boss').textContent=(s.boss_hp??'—')+' / '+(s.boss_max_hp??'—');el('player').textContent=(p.hp??s.player_hp??'—')+' / '+(p.max_hp??s.player_max_hp??'—');el('round').textContent=s.round??'—';renderIntent(s,p);renderBuild(p);const cards=el('cards');cards.replaceChildren();(s.hand||[]).forEach((c,i)=>{const b=document.createElement('button');b.className='card';b.style.setProperty('--rarity',colors[c.rarity]||colors.common);b.disabled=locked;b.innerHTML=`<img src="${c.artwork_url}" alt="${c.name}"><span class="info"><b class="name">${c.name}</b><span class="desc">${c.description}</span><span class="meta"><span>${c.rarity_label}</span><span class="rank">${c.rank_label}</span></span></span>`;b.onclick=()=>choose(i,b);cards.appendChild(b)});const ended=s.phase==='victory'||s.phase==='defeat',menu=s.phase==='menu',fighting=s.phase==='resolving',ready=p.ready&&s.phase==='awaiting_selection',own=((s.combat||{}).attacks||[]).find(a=>a.player_id===p.id),discovery=own&&own.new_synergies&&own.new_synergies[0];el('overlay').classList.toggle('show',ended||menu||fighting||spectating||!p.alive);el('waitTitle').textContent=spectating?'ZUSCHAUER':menu?'AM PC STARTEN':ended?(s.phase==='victory'?'SIEG':'NIEDERLAGE'):!p.alive?'HELD GEFALLEN':fighting?(discovery?discovery.name.toUpperCase()+' FREIGESCHALTET':'KAMPF LÄUFT'):'BITTE WARTEN';el('waitText').textContent=spectating?'Diese Partie hat bereits zwei aktive Spieler.':fighting?(discovery?'NEUE SYNERGIE · SCHAU AUF DEN TV':ownTriggers(s,p)):(s.result||'');el('hint').textContent=s.can_select?'UPGRADE ANTIPPEN':ready?'BEREIT – WARTE AUF MITSPIELER':(s.result||'BITTE WARTEN')}
function choose(index,button){if(locked||role!=='player'||!socket||socket.readyState!==1)return;locked=true;const chosen=(state.hand||[])[index]||{};selectedLabel=(chosen.name||'UPGRADE')+' · '+(chosen.rank_label||'');button.classList.add('selected');document.querySelectorAll('.card').forEach(x=>x.disabled=true);el('waitTitle').textContent='UPGRADE ERHALTEN';el('waitText').textContent=selectedLabel;el('overlay').classList.add('show');socket.send(JSON.stringify({type:'select',index}))}
function connect(){socket=new WebSocket('ws://'+location.hostname+':__WS_PORT__');socket.onopen=()=>socket.send(JSON.stringify({type:'hello',token:localStorage.getItem('ashenborn_session')||''}));socket.onmessage=e=>{const m=JSON.parse(e.data);if(m.type==='welcome'){role=m.role;localStorage.setItem('ashenborn_session',m.token);el('status').textContent=m.role==='player'?'VERBUNDEN':'ZUSCHAUER'}else if(m.type==='state')render(m.state)};socket.onclose=()=>{el('status').textContent='NEUVERBINDUNG …';setTimeout(connect,1200)}}connect();
</script></body></html>"""
