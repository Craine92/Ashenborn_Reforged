class_name WebControllerServer
extends Node

signal card_selected(index: int)
signal connection_changed(connected: bool)

const DEFAULT_HTTP_PORT := 8765
const DEFAULT_WS_PORT := 8766
const MAX_REQUEST_BYTES := 8192

var http_port := DEFAULT_HTTP_PORT
var websocket_port := DEFAULT_WS_PORT
var is_running := false
var state_provider := Callable()

var _http_server := TCPServer.new()
var _websocket_server := TCPServer.new()
var _http_clients: Array[Dictionary] = []
var _websocket_clients: Array[Dictionary] = []
var _art_cache: Dictionary = {}
var _smartphone_connected := false


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
	is_running = false
	set_process(false)
	_set_smartphone_connected(false)


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


func broadcast_state() -> void:
	if not is_running or not state_provider.is_valid():
		return
	var message := JSON.stringify({"type": "state", "state": state_provider.call()})
	for entry: Dictionary in _websocket_clients:
		var socket: WebSocketPeer = entry["socket"]
		if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			socket.send_text(message)


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
		var error := socket.accept_stream(tcp)
		if error == OK:
			_websocket_clients.append({"socket": socket, "tcp": tcp, "welcomed": false})


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
			if not entry["welcomed"]:
				entry["welcomed"] = true
				_send_state(socket)
				_refresh_connection_state()
			while socket.get_available_packet_count() > 0:
				var packet := socket.get_packet().get_string_from_utf8()
				_handle_websocket_message(socket, packet)
		elif ready == WebSocketPeer.STATE_CLOSED:
			_websocket_clients.remove_at(index)
	_refresh_connection_state()


func _handle_websocket_message(socket: WebSocketPeer, message: String) -> void:
	var parsed = JSON.parse_string(message)
	if typeof(parsed) != TYPE_DICTIONARY or parsed.get("type", "") != "select":
		socket.send_text(JSON.stringify({"type": "error", "message": "Ungültige Nachricht"}))
		return
	var index := int(parsed.get("index", -1))
	card_selected.emit(index)
	_send_state(socket)


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
		var state: Dictionary = {} if not state_provider.is_valid() else state_provider.call()
		_send_response(peer, 200, "application/json; charset=utf-8", JSON.stringify(state).to_utf8_buffer())
	elif path == "/api/select":
		var selected_index := _query_integer(target, "index", -1)
		card_selected.emit(selected_index)
		var state: Dictionary = {} if not state_provider.is_valid() else state_provider.call()
		_send_response(peer, 200, "application/json; charset=utf-8", JSON.stringify(state).to_utf8_buffer())
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
		var target_width := maxi(1, roundi(float(image.get_width()) * scale_factor))
		var target_height := maxi(1, roundi(float(image.get_height()) * scale_factor))
		image.resize(target_width, target_height, Image.INTERPOLATE_LANCZOS)
		bytes = image.save_jpg_to_buffer(0.82)
		_art_cache[card_id] = bytes
	if bytes.is_empty():
		_send_text(peer, 404, "Bild nicht gefunden")
		return
	_send_response(peer, 200, "image/jpeg", bytes, "public, max-age=3600")


func _send_state(socket: WebSocketPeer) -> void:
	if not state_provider.is_valid() or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	socket.send_text(JSON.stringify({"type": "state", "state": state_provider.call()}))


func _send_text(peer: StreamPeerTCP, status: int, body: String) -> void:
	_send_response(peer, status, "text/plain; charset=utf-8", body.to_utf8_buffer())


func _send_response(peer: StreamPeerTCP, status: int, content_type: String, body: PackedByteArray, cache_control: String = "no-store") -> void:
	var reason := "OK" if status == 200 else "Error"
	var headers := "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: %s\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n" % [status, reason, content_type, body.size(), cache_control]
	var response := headers.to_utf8_buffer()
	response.append_array(body)
	peer.put_data(response)
	peer.disconnect_from_host()


func _query_integer(target: String, key: String, fallback: int) -> int:
	if not target.contains("?"):
		return fallback
	var query := target.get_slice("?", 1)
	for item in query.split("&"):
		if item.get_slice("=", 0) == key:
			return int(item.get_slice("=", 1))
	return fallback


func _refresh_connection_state() -> void:
	var connected := false
	for entry: Dictionary in _websocket_clients:
		var socket: WebSocketPeer = entry["socket"]
		if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			connected = true
			break
	_set_smartphone_connected(connected)


func _set_smartphone_connected(connected: bool) -> void:
	if _smartphone_connected == connected:
		return
	_smartphone_connected = connected
	connection_changed.emit(connected)


func _is_private_172(address: String) -> bool:
	if not address.begins_with("172."):
		return false
	var parts := address.split(".")
	if parts.size() != 4:
		return false
	var second := int(parts[1])
	return second >= 16 and second <= 31


func _controller_html() -> String:
	return CONTROLLER_HTML.replace("__WS_PORT__", str(websocket_port))


const CONTROLLER_HTML := """<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<title>Ashenborn Controller</title>
<style>
:root{color-scheme:dark;--ink:#06080d;--panel:#0e151f;--cyan:#55cfe4;--gold:#dfb763;--muted:#9ca8b8;--danger:#d45151}
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
html,body{margin:0;width:100%;height:100%;overflow:hidden;background:radial-gradient(circle at 50% -10%,#1b3445 0,#0b1119 38%,#06080d 78%);color:#f5f0e6;font-family:system-ui,-apple-system,sans-serif}
main{width:100%;height:100dvh;display:grid;grid-template-rows:auto auto minmax(0,1fr) auto;gap:9px;padding:max(10px,env(safe-area-inset-top)) 10px max(10px,env(safe-area-inset-bottom));max-width:600px;margin:auto;min-width:0}
header{display:flex;align-items:center;justify-content:space-between;min-height:25px;padding:0 2px}
h1{font-family:Georgia,serif;font-size:16px;letter-spacing:.15em;margin:0;color:var(--cyan)}
#status{font-size:10px;letter-spacing:.08em;color:var(--muted)}
.stats{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));min-width:0;background:#0c121ae8;border-bottom:1px solid #9c744a88;border-radius:9px;overflow:hidden;box-shadow:0 8px 24px #0006}
.stat{padding:7px 3px;text-align:center;font-size:9px;letter-spacing:.09em;color:var(--muted)}
.stat+.stat{border-left:1px solid #ffffff12}
.stat b{display:block;color:#fff;font-size:18px;letter-spacing:0;margin-top:1px}
#cards{min-height:0;min-width:0;display:grid;grid-template-columns:repeat(3,minmax(0,1fr));align-items:center;gap:clamp(5px,1.8vw,9px);padding:4px 0}
.card{position:relative;width:100%;aspect-ratio:2/3;min-width:0;border:2px solid var(--rarity);border-radius:12px;overflow:hidden;background:#080c12;display:block;box-shadow:0 9px 22px #0009;padding:0;color:#fff;text-align:left;transition:transform .14s ease,border-color .14s ease,box-shadow .14s ease,filter .14s ease}
.card:active:not(:disabled){transform:scale(.98);filter:brightness(1.1)}
.card.selected{transform:translateY(-7px);border-width:4px;border-color:var(--rarity);box-shadow:0 0 0 2px #ffffff30,0 14px 30px #000e;filter:brightness(1.12)}
.card:disabled{filter:saturate(.6) brightness(.72)}
.card img{position:absolute;inset:0;width:100%;height:100%;object-fit:contain;object-position:center center;min-height:0;background:#080c12}
.info{position:absolute;z-index:1;left:0;right:0;bottom:0;padding:26px 7px 7px;background:linear-gradient(transparent,#090d13ee 25%,#090d13 52%);min-width:0;text-shadow:0 2px 3px #000}
.name{display:block;font-family:Georgia,serif;font-size:clamp(10px,2.9vw,15px);line-height:1.05;white-space:normal;overflow-wrap:anywhere}
.desc{display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;min-height:2.25em;margin-top:3px;color:#d7dce4;font-size:clamp(8px,2.05vw,11px);line-height:1.12}
.meta{display:flex;justify-content:space-between;gap:3px;margin-top:5px;font-size:clamp(9px,2.45vw,12px);color:var(--rarity)}
.rank{color:var(--gold);font-weight:800;text-align:right}
#action{min-height:42px;display:grid;place-items:center}
#hint{text-align:center;color:var(--cyan);font-size:13px;letter-spacing:.05em;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#overlay{position:fixed;inset:0;background:#06080df2;display:none;place-items:center;padding:25px;text-align:center;z-index:5}
#overlay.show{display:grid}.wait{font-family:Georgia,serif;color:var(--cyan);font-size:25px}.small{color:var(--muted);font-size:14px;margin-top:12px}
@media(max-height:590px){main{padding:6px;gap:5px}.stat{padding:3px}.stat b{font-size:15px}#action{min-height:38px}.info{padding:20px 5px 5px}.meta{margin-top:2px}.desc{-webkit-line-clamp:2}}
@media(max-width:340px){main{padding-left:6px;padding-right:6px}h1{font-size:14px}.info{padding-left:4px;padding-right:4px}.meta{font-size:7px}.name{font-size:9px}.desc{font-size:7px}}
</style>
</head>
<body><main>
<header><h1>ASHENBORN</h1><span id="status">VERBINDE …</span></header>
<section class="stats"><div class="stat">MORVATH<b id="boss">—</b></div><div class="stat">RUNDE<b id="round">—</b></div><div class="stat" id="heroName">ASCHENRITTER<b id="player">—</b></div></section>
<section id="cards"></section><section id="action"><div id="hint">Spiel wird geladen …</div></section>
</main><div id="overlay"><div><div class="wait" id="waitTitle">KAMPF LÄUFT</div><div class="small" id="waitText">Morvath antwortet …</div></div></div>
<script>
const colors={common:'#55c271',rare:'#4b91e2',epic:'#a868e8',legendary:'#e9b94c'};
let socket,state,locked=true,lastRound=-1,noticeUntil=0,selectedLabel='';
const el=id=>document.getElementById(id);
function render(s){state=s;lastRound=s.round;locked=!s.can_select;el('boss').textContent=s.boss_hp+' / '+s.boss_max_hp;el('player').textContent=s.player_hp+' / '+s.player_max_hp;el('round').textContent=s.round;el('heroName').childNodes[0].nodeValue=((s.hero&&s.hero.name)||'ASCHENRITTER').toUpperCase();
 const cards=el('cards');cards.replaceChildren();(s.hand||[]).forEach((c,i)=>{const b=document.createElement('button');b.className='card';b.style.setProperty('--rarity',colors[c.rarity]||colors.common);b.disabled=locked;b.innerHTML=`<img src="${c.artwork_url}" alt="${c.name}"><span class="info"><b class="name">${c.name}</b><span class="desc">${c.description}</span><span class="meta"><span>${c.rarity_label}</span><span class="rank">${c.rank_label}</span></span></span>`;b.onclick=()=>choose(i,b);cards.appendChild(b)});
 const ended=s.phase==='victory'||s.phase==='defeat',menu=s.phase==='menu',fighting=s.phase==='resolving',notice=fighting&&Date.now()<noticeUntil;el('overlay').classList.toggle('show',ended||menu||fighting);el('waitTitle').textContent=menu?'AM PC STARTEN':ended?(s.phase==='victory'?'SIEG':'NIEDERLAGE'):notice?'UPGRADE ERHALTEN':'KAMPF LÄUFT';el('waitText').textContent=menu?'Wähle am Host SPIELEN.':ended?s.result:notice?selectedLabel:'SCHAU AUF DEN TV';el('hint').textContent=s.can_select?'UPGRADE ANTIPPEN':(s.result||'BITTE WARTEN');if(notice)setTimeout(()=>render(state),Math.max(10,noticeUntil-Date.now()+10))}
function choose(index,button){if(locked)return;locked=true;const chosen=(state.hand||[])[index]||{};selectedLabel=(chosen.name||'UPGRADE')+' · '+(chosen.rank_label||'');noticeUntil=Date.now()+550;button.classList.add('selected');document.querySelectorAll('.card').forEach(x=>x.disabled=true);el('waitTitle').textContent='UPGRADE ERHALTEN';el('waitText').textContent=selectedLabel;el('overlay').classList.add('show');if(socket&&socket.readyState===1)socket.send(JSON.stringify({type:'select',index}));else fetch('/api/select?index='+index).then(r=>r.json()).then(render)}
function connect(){socket=new WebSocket('ws://'+location.hostname+':__WS_PORT__');socket.onopen=()=>{el('status').textContent='VERBUNDEN';el('status').style.color='#55c271'};socket.onmessage=e=>{const m=JSON.parse(e.data);if(m.type==='state')render(m.state)};socket.onclose=()=>{el('status').textContent='NEUVERBINDUNG …';el('status').style.color='#e4b95f';setTimeout(connect,1200)}}
fetch('/api/state').then(r=>r.json()).then(render);connect();
</script></body></html>"""
