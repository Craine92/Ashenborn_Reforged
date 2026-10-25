extends Node

var _game: GameState
var _server: WebControllerServer
var _menu: MainMenu
var _lobby: ConnectionLobby
var _battle: BattleView
var _connection_overlay: ConnectionLobby
var _music: AudioStreamPlayer
var _sounds: Dictionary = {}
var _server_started := false


func _ready() -> void:
	_build_audio()
	_game = GameState.new()
	add_child(_game)
	_game.state_changed.connect(_on_state_changed)
	_game.audio_cue.connect(_on_audio_cue)

	_menu = MainMenu.new()
	add_child(_menu)
	_menu.play_requested.connect(_show_lobby)
	_menu.volume_changed.connect(_set_volume)

	_lobby = ConnectionLobby.new()
	_lobby.visible = false
	add_child(_lobby)
	_lobby.start_requested.connect(func() -> void: _start_battle(false))
	_lobby.solo_requested.connect(func() -> void: _start_battle(true))
	_lobby.back_requested.connect(_return_to_menu)

	_battle = BattleView.new()
	_battle.visible = false
	add_child(_battle)
	_battle.card_selected.connect(func(index: int) -> void: _game.select_upgrade(index, "pc"))
	_battle.restart_requested.connect(_show_lobby)
	_battle.menu_requested.connect(_return_to_menu)
	_battle.connection_menu_requested.connect(_show_connection_overlay)
	_battle.combat_audio.connect(_on_combat_audio)
	_battle.combat_sequence_finished.connect(_game.confirm_visual_resolution)

	_connection_overlay = ConnectionLobby.new()
	_connection_overlay.visible = false
	add_child(_connection_overlay)
	_connection_overlay.set_ingame_mode()
	_connection_overlay.close_requested.connect(func() -> void: _connection_overlay.visible = false)

	_server = WebControllerServer.new()
	add_child(_server)
	_server.public_state_provider = Callable(_game, "get_public_snapshot")
	_server.private_state_provider = Callable(_game, "get_private_snapshot")
	_server.player_selected.connect(func(player_id: String, index: int) -> void: _game.select_upgrade(player_id, index, "web"))
	_server.connection_changed.connect(_on_connection_changed)
	_server.players_changed.connect(_on_players_changed)
	_server.player_connection_changed.connect(_on_player_connection_changed)
	_server_started = _server.start()
	_configure_connection_views()
	_set_volume(75.0)
	_music.play()


func _exit_tree() -> void:
	if is_instance_valid(_server):
		_server.stop()


func _start_battle(pc_test_mode: bool = false) -> void:
	_menu.visible = false
	_lobby.visible = false
	_connection_overlay.visible = false
	_battle.set_pc_test_mode(pc_test_mode)
	_battle.visible = true
	var player_ids: Array[String] = []
	if pc_test_mode:
		player_ids.append(GameState.DEFAULT_PLAYER_ID)
		_server.begin_match([])
	else:
		player_ids = _server.get_active_player_ids()
		_server.begin_match(player_ids)
	_game.start_game(-1, player_ids)


func _show_lobby() -> void:
	_game.return_to_menu()
	_server.end_match()
	_menu.visible = false
	_battle.visible = false
	_connection_overlay.visible = false
	_configure_connection_views()
	_lobby.visible = true


func _show_connection_overlay() -> void:
	_configure_connection_views()
	_connection_overlay.visible = true


func _return_to_menu() -> void:
	_game.return_to_menu()
	_server.end_match()
	_battle.visible = false
	_lobby.visible = false
	_connection_overlay.visible = false
	_menu.visible = true
	_menu.show_home()


func _configure_connection_views() -> void:
	var url := _server.controller_url() if is_instance_valid(_server) else ""
	var has_address := is_instance_valid(_server) and _server.has_network_address()
	var connected := is_instance_valid(_server) and _server.is_smartphone_connected()
	_lobby.configure(url, _server_started, has_address)
	_lobby.set_players(_server.lobby_players())
	_connection_overlay.configure(url, _server_started, has_address)
	_connection_overlay.set_players(_server.lobby_players())
	_battle.set_connection_info(url, _server_started and has_address)
	_battle.set_smartphone_connected(connected)


func _on_connection_changed(connected: bool) -> void:
	_battle.set_smartphone_connected(connected)


func _on_players_changed(players: Array) -> void:
	_lobby.set_players(players)
	_connection_overlay.set_players(players)


func _on_player_connection_changed(player_id: String, connected: bool) -> void:
	_game.set_player_connected(player_id, connected)


func _on_state_changed(_snapshot: Dictionary) -> void:
	_battle.set_state(_game.get_public_snapshot(_battle.is_pc_test_mode()))
	_server.broadcast_state()


func _set_volume(value: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, -80.0 if value <= 0.0 else linear_to_db(value / 100.0))


func _build_audio() -> void:
	_music = AudioStreamPlayer.new()
	_music.stream = load("res://assets/audio/music/menu/forest_2.ogg")
	_music.volume_db = -12.0
	add_child(_music)
	_add_sound("start", "res://assets/audio/voices/game-start.mp3", -5.0)
	_add_sound("attack", "res://assets/audio/sfx/combat/magical_4.ogg", -2.0)
	_add_sound("boss_attack", "res://assets/audio/sfx/combat/magical_5.ogg", -2.0)
	_add_sound("new_round", "res://assets/audio/sfx/cards/card-shuffle.ogg", -8.0)
	_add_sound("victory", "res://assets/audio/voices/victory.mp3", -3.0)
	_add_sound("defeat", "res://assets/audio/voices/defeat.mp3", -3.0)


func _add_sound(cue: String, path: String, volume: float) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.volume_db = volume
	add_child(player)
	_sounds[cue] = player


func _on_audio_cue(cue: String) -> void:
	if cue in ["attack", "victory", "defeat"]:
		return
	_play_sound(cue)


func _on_combat_audio(cue: String) -> void:
	_play_sound(cue)


func _play_sound(cue: String) -> void:
	var player: AudioStreamPlayer = _sounds.get(cue)
	if player:
		player.play()
