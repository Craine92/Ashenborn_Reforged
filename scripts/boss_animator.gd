class_name BossAnimator
extends TextureRect

signal animation_started(animation_name: String)
signal frame_changed(animation_name: String, frame_index: int)
signal animation_finished(animation_name: String)

const DEFAULT_MANIFEST := "res://assets/bosses/morvath/manifest.json"
const DEFAULT_SPEED_MULTIPLIERS := {
	"idle": 0.80,
	"energy_charge": 0.55,
	"skull_swarm": 0.55,
	"spell_blast": 0.55,
	"hit_reaction": 0.55,
	"death": 0.45,
}

var manifest_path := DEFAULT_MANIFEST
var _animations: Dictionary = {}
var _current_animation := ""
var _current_frame := 0
var _frame_elapsed := 0.0
var _playing := false
var _looping := false
var _generation := 0
var _completed_generation := -1
var speed_multipliers: Dictionary = DEFAULT_SPEED_MULTIPLIERS.duplicate()


func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_manifest()
	play_loop("idle")


func _process(delta: float) -> void:
	if not _playing or not _animations.has(_current_animation):
		return
	var animation: Dictionary = _animations[_current_animation]
	var fps := effective_fps(_current_animation)
	_frame_elapsed += delta
	var frame_duration := 1.0 / fps
	while _frame_elapsed >= frame_duration and _playing:
		_frame_elapsed -= frame_duration
		var next_frame := _current_frame + 1
		var frames: Array = animation.get("textures", [])
		if next_frame >= frames.size():
			if _looping:
				_set_frame(0)
			else:
				_playing = false
				_completed_generation = _generation
				animation_finished.emit(_current_animation)
		else:
			_set_frame(next_frame)


func play_loop(animation_name: String) -> bool:
	if not _animations.has(animation_name):
		return false
	_generation += 1
	_start_animation(animation_name, true)
	return true


func play_once(animation_name: String, return_to_idle: bool = true, timeout_seconds: float = 0.0) -> bool:
	if not _animations.has(animation_name):
		if return_to_idle:
			play_loop("idle")
		return false
	_generation += 1
	var expected_generation := _generation
	_start_animation(animation_name, false)
	var expected_duration := animation_duration(animation_name)
	var timeout := timeout_seconds if timeout_seconds > 0.0 else expected_duration + 0.5
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while _generation == expected_generation and _completed_generation != expected_generation and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var completed := _completed_generation == expected_generation
	if _generation == expected_generation:
		if return_to_idle:
			play_loop("idle")
		else:
			_playing = false
	return completed


func play_attack_cycle(use_skull_swarm: bool = false) -> bool:
	var charged := await play_once("energy_charge", false)
	if not charged:
		play_loop("idle")
		return false
	var attack_name := "skull_swarm" if use_skull_swarm else "spell_blast"
	return await play_once(attack_name, true)


func play_death() -> bool:
	return await play_once("death", false)


func cancel_and_idle() -> void:
	play_loop("idle")


func has_animation(animation_name: String) -> bool:
	return _animations.has(animation_name)


func animation_names() -> Array[String]:
	var names: Array[String] = []
	for animation_name in _animations:
		names.append(animation_name)
	return names


func animation_info(animation_name: String) -> Dictionary:
	if not _animations.has(animation_name):
		return {}
	var source: Dictionary = _animations[animation_name]
	return {
		"name": animation_name,
		"fps": effective_fps(animation_name),
		"base_fps": source.get("fps", 0),
		"speed_multiplier": speed_multiplier(animation_name),
		"duration": animation_duration(animation_name),
		"frame_count": source.get("textures", []).size(),
		"frame_size": source.get("frame_size", Vector2i.ZERO),
		"files": source.get("files", []).duplicate(),
	}


func set_speed_multiplier(animation_name: String, multiplier: float) -> void:
	speed_multipliers[animation_name] = maxf(0.05, multiplier)


func speed_multiplier(animation_name: String) -> float:
	return maxf(0.05, float(speed_multipliers.get(animation_name, 1.0)))


func effective_fps(animation_name: String) -> float:
	if not _animations.has(animation_name):
		return 1.0
	return maxf(0.1, float(_animations[animation_name].get("fps", 8.0)) * speed_multiplier(animation_name))


func animation_duration(animation_name: String) -> float:
	if not _animations.has(animation_name):
		return 0.0
	return float(_animations[animation_name].get("textures", []).size()) / effective_fps(animation_name)


func current_animation() -> String:
	return _current_animation


func current_frame() -> int:
	return _current_frame


func is_animation_playing() -> bool:
	return _playing


func _load_manifest() -> void:
	_animations.clear()
	if not FileAccess.file_exists(manifest_path):
		push_error("Boss-Animationsmanifest fehlt: " + manifest_path)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Boss-Animationsmanifest ist ungültig: " + manifest_path)
		return
	var root_path := manifest_path.get_base_dir()
	for definition: Dictionary in parsed.get("animations", []):
		var textures: Array[Texture2D] = []
		var resolved_files: Array[String] = []
		for relative_file in definition.get("files", []):
			var resource_path := root_path.path_join(String(relative_file))
			var frame_texture: Texture2D = load(resource_path)
			if frame_texture == null:
				push_error("Boss-Animationsframe fehlt: " + resource_path)
				continue
			textures.append(frame_texture)
			resolved_files.append(resource_path)
		if textures.is_empty():
			continue
		var size_data: Dictionary = definition.get("frame_size", {})
		_animations[String(definition.get("name", ""))] = {
			"textures": textures,
			"files": resolved_files,
			"fps": float(definition.get("suggested_fps", 8)),
			"frame_size": Vector2i(int(size_data.get("width", 0)), int(size_data.get("height", 0))),
		}


func _start_animation(animation_name: String, looping: bool) -> void:
	_current_animation = animation_name
	_current_frame = 0
	_frame_elapsed = 0.0
	_looping = looping
	_playing = true
	_set_frame(0)
	animation_started.emit(animation_name)


func _set_frame(frame_index: int) -> void:
	if not _animations.has(_current_animation):
		return
	var frames: Array = _animations[_current_animation].get("textures", [])
	if frames.is_empty():
		return
	_current_frame = clampi(frame_index, 0, frames.size() - 1)
	texture = frames[_current_frame]
	frame_changed.emit(_current_animation, _current_frame)
