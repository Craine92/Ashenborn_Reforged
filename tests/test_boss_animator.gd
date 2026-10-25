extends SceneTree

var _failures: Array[String] = []
var _audit_lines: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest_path := "res://assets/bosses/morvath/manifest.json"
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	_check(typeof(parsed) == TYPE_DICTIONARY, "Morvath-Manifest ist gültiges JSON")
	if typeof(parsed) == TYPE_DICTIONARY:
		_audit_manifest(parsed, manifest_path.get_base_dir())
	await _test_runtime_animator()
	for line in _audit_lines:
		print("ASSET AUDIT: " + line)
	if _failures.is_empty():
		print("PASS: Manifest, Frames, FPS, Bewegung und echte Laufzeit-Sequenzen")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _audit_manifest(manifest: Dictionary, root_path: String) -> void:
	var expected := ["idle", "energy_charge", "skull_swarm", "spell_blast", "hit_reaction", "death"]
	var definitions: Array = manifest.get("animations", [])
	_check(definitions.size() == expected.size(), "Manifest definiert genau sechs benötigte Animationen")
	var found: Array[String] = []
	for definition: Dictionary in definitions:
		var animation_name := String(definition.get("name", ""))
		found.append(animation_name)
		var files: Array = definition.get("files", [])
		var expected_count := int(definition.get("frames", 0))
		var size_data: Dictionary = definition.get("frame_size", {})
		var expected_size := Vector2i(int(size_data.get("width", 0)), int(size_data.get("height", 0)))
		_check(files.size() == expected_count, "%s besitzt die manifestierte Framezahl" % animation_name)
		_check(float(definition.get("suggested_fps", 0)) > 0.0, "%s besitzt eine gültige FPS-Empfehlung" % animation_name)
		var hashes := {}
		var transparent_frames := 0
		var transparent_corner_frames := 0
		var actual_sizes := {}
		var manifest_size_matches := 0
		var opaque_sample_ratio_total := 0.0
		var previous_small: Image
		var minimum_difference := 1.0
		for relative_file in files:
			var resource_path := root_path.path_join(String(relative_file))
			_check(FileAccess.file_exists(resource_path), "Frame existiert: " + resource_path)
			var frame_texture: Texture2D = load(resource_path)
			var image: Image = null if frame_texture == null else frame_texture.get_image()
			_check(image != null and not image.is_empty(), "Frame ist lesbares PNG: " + resource_path)
			if image == null or image.is_empty():
				continue
			var actual_size := Vector2i(image.get_width(), image.get_height())
			actual_sizes[str(actual_size)] = true
			if actual_size == expected_size:
				manifest_size_matches += 1
			var hashing := HashingContext.new()
			hashing.start(HashingContext.HASH_SHA256)
			hashing.update(image.get_data())
			var frame_hash := hashing.finish().hex_encode()
			_check(not hashes.has(frame_hash), "%s enthält keine doppelten Frames" % animation_name)
			hashes[frame_hash] = true
			if image.detect_alpha() != Image.ALPHA_NONE:
				transparent_frames += 1
			if image.get_pixel(0, 0).a < 0.98 or image.get_pixel(image.get_width() - 1, 0).a < 0.98 or image.get_pixel(0, image.get_height() - 1).a < 0.98 or image.get_pixel(image.get_width() - 1, image.get_height() - 1).a < 0.98:
				transparent_corner_frames += 1
			var opaque_samples := 0
			var sample_count := 0
			for sample_y in range(0, image.get_height(), 8):
				for sample_x in range(0, image.get_width(), 8):
					sample_count += 1
					if image.get_pixel(sample_x, sample_y).a >= 0.98:
						opaque_samples += 1
			opaque_sample_ratio_total += float(opaque_samples) / float(maxi(1, sample_count))
			var small := image.duplicate()
			small.resize(32, 32, Image.INTERPOLATE_BILINEAR)
			if previous_small != null:
				minimum_difference = minf(minimum_difference, _image_difference(previous_small, small))
			previous_small = small
		_check(minimum_difference > 0.002, "%s zeigt messbare Veränderung zwischen allen aufeinanderfolgenden Frames" % animation_name)
		var opaque_percent := 100.0 * opaque_sample_ratio_total / float(maxi(1, files.size()))
		_audit_lines.append("%s: %d Frames, %d FPS, Manifest %s (%d/%d passend), real %s, Alpha %d/%d, mittlere Deckfläche %.1f %%, kleinste Bildänderung %.4f" % [animation_name, files.size(), int(definition.get("suggested_fps", 0)), str(expected_size), manifest_size_matches, files.size(), ", ".join(actual_sizes.keys()), transparent_frames, files.size(), opaque_percent, minimum_difference])
	for animation_name in expected:
		_check(found.has(animation_name), "Manifest enthält " + animation_name)


func _test_runtime_animator() -> void:
	var animator := BossAnimator.new()
	root.add_child(animator)
	await process_frame
	_check(animator.animation_names().size() == 6, "BossAnimator lädt alle Manifest-Sequenzen")
	_check(is_equal_approx(animator.animation_info("spell_blast")["speed_multiplier"], 0.55), "Kampfanimationen laufen konfigurierbar mit 55 % Geschwindigkeit")
	_check(animator.animation_info("death")["duration"] > animator.animation_info("spell_blast")["duration"], "Tod ist bewusst langsamer als der Kampfzauber")
	_check(animator.animation_info("idle")["speed_multiplier"] > animator.animation_info("spell_blast")["speed_multiplier"], "Idle bleibt flüssiger als Kampfanimationen")
	_check(animator.current_animation() == "idle" and animator.is_animation_playing(), "Idle startet automatisch als Loop")
	var idle_start := animator.current_frame()
	await create_timer(0.3).timeout
	_check(animator.current_animation() == "idle" and animator.current_frame() != idle_start, "Idle-Frames laufen kontinuierlich weiter")
	var visited: Dictionary = {}
	animator.frame_changed.connect(func(name: String, frame: int) -> void:
		if not visited.has(name):
			visited[name] = {}
		visited[name][frame] = true
	)
	_check(await animator.play_once("hit_reaction"), "Trefferreaktion wird vollständig abgespielt")
	_check(Dictionary(visited.get("hit_reaction", {})).size() == 6, "Trefferreaktion verwendet alle sechs Einzelbilder")
	_check(await animator.play_once("energy_charge"), "Energieaufladung wird vollständig abgespielt")
	_check(await animator.play_once("spell_blast"), "Spell Blast wird vollständig abgespielt")
	_check(await animator.play_once("skull_swarm"), "Skull Swarm wird als alternative Angriffssequenz abgespielt")
	_check(await animator.play_death(), "Todessequenz wird vollständig abgespielt")
	var death_info := animator.animation_info("death")
	_check(animator.current_animation() == "death" and animator.current_frame() == int(death_info["frame_count"]) - 1 and not animator.is_animation_playing(), "Tod bleibt nach dem letzten Frame stehen")
	animator.free()


func _image_difference(first: Image, second: Image) -> float:
	var total := 0.0
	for y in first.get_height():
		for x in first.get_width():
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			total += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a)
	return total / float(first.get_width() * first.get_height() * 4)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
