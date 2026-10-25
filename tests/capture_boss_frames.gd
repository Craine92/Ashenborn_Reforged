extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output := Image.create_empty(960, 240, false, Image.FORMAT_RGBA8)
	output.fill(Color("07101a"))
	for index in 4:
		var frame_number := index + 2
		var path := "res://assets/bosses/morvath/spell_blast/morvath_spell_blast_%02d.png" % frame_number
		var texture: Texture2D = load(path)
		if texture == null:
			printerr("Fehlender Frame: " + path)
			quit(1)
			return
		var frame := texture.get_image()
		frame.resize(240, 240, Image.INTERPOLATE_LANCZOS)
		output.blit_rect(frame, Rect2i(0, 0, 240, 240), Vector2i(index * 240, 0))
	var target := ProjectSettings.globalize_path("res://docs/screenshots/alpha_02b_morvath_spell_frames.png")
	var error := output.save_png(target)
	if error != OK:
		printerr("Frame-Vorschau konnte nicht gespeichert werden: %s" % error)
		quit(1)
		return
	print("PASS: Vier aufeinanderfolgende Spell-Blast-Frames exportiert")
	quit(0)
