extends Node2D
const Library = preload("res://scripts/warden_motion_m12.gd")
const DISPLAY_SCALE = 0.90
var sprites: Array[AnimatedSprite2D] = []
var playing: bool = true
var info: Label
var air_index: int = 0
var clock: float = 0.0
var air_cycle: Array[String] = ["unarmed_jump", "unarmed_fall", "unarmed_land"]

func label_at(value: String, point: Vector2, size_value: int, color_value: Color = Color("e9eced")) -> Label:
	var node := Label.new()
	node.text = value
	node.position = point
	node.add_theme_font_size_override("font_size", size_value)
	node.add_theme_color_override("font_color", color_value)
	add_child(node)
	return node

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("10191f"))
	label_at("LAST LECTURE   /   THE LANTERN WARDEN", Vector2(42, 26), 16, Color("76b7c2"))
	label_at("ONE CHARACTER. EVERY MOTION.", Vector2(42, 57), 32)
	label_at("M12   /   UNIFIED LOCOMOTION", Vector2(950, 35), 14, Color("d7ba80"))
	label_at("Same lantern, anatomy and palette  /  Rigid joints  /  Soft illustrated contours", Vector2(42, 108), 17, Color("9daeb7"))
	var library: SpriteFrames = Library.build()
	for i in range(3):
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = library
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.scale = Vector2.ONE * DISPLAY_SCALE
		sprite.position = Vector2(220.0 + float(i) * 420.0, 501.0 + (256.0 - 456.0) * DISPLAY_SCALE)
		add_child(sprite)
		sprites.append(sprite)
		sprite.play(["unarmed_idle", "unarmed_run", "unarmed_jump"][i])
		label_at(["01  /  IDLE", "02  /  RUN", "03  /  JUMP + FALL"][i], Vector2(64.0 + float(i) * 420.0, 526), 22)
		label_at(["285 px standing height", "Original 6-pose rhythm + in-betweens", "Same lengths through every bend"][i], Vector2(64.0 + float(i) * 420.0, 563), 15, Color("9daeb7"))
	info = label_at("", Vector2(42, 609), 16, Color("77ced5"))
	label_at("SPACE play / pause   |   LEFT / RIGHT step run   |   J next airborne state   |   ESC return to game", Vector2(42, 674), 15, Color("9daeb7"))
	sprites[2].animation_finished.connect(_air_finished)
	queue_redraw()

func _air_finished() -> void:
	air_index = (air_index + 1) % air_cycle.size()
	sprites[2].play(air_cycle[air_index])

func _process(delta: float) -> void:
	clock += delta
	info.text = "SOURCE 512 x 512    /    GAME SCALE 0.40    /    LANTERN 64 x 86    /    TORSO 94    /    ARM 44 + 42    /    LEG 106"
	if "--capture-review" in OS.get_cmdline_user_args() and clock > 1.3:
		set_process(false)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://WARDEN_M12_GODOT_REVIEW.png")
		if "--keep-review-open" not in OS.get_cmdline_user_args():
			get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			playing = not playing
			for sprite in sprites:
				if playing:
					sprite.play()
				else:
					sprite.pause()
		elif event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT:
			sprites[1].pause()
			sprites[1].frame = posmod(sprites[1].frame + (1 if event.keycode == KEY_RIGHT else -1), 24)
		elif event.keycode == KEY_J:
			air_index = (air_index + 1) % air_cycle.size()
			sprites[2].play(air_cycle[air_index])
		elif event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/main.tscn")

func _draw() -> void:
	for i in range(3):
		var left: float = 42.0 + float(i) * 420.0
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color("19262e")
		panel.set_corner_radius_all(12)
		draw_style_box(panel, Rect2(left, 160, 382, 432))
		draw_line(Vector2(left + 22, 501), Vector2(left + 360, 501), Color("6aa1a8"), 1.5, true)
		draw_line(Vector2(left + 22, 501 - 285 * DISPLAY_SCALE), Vector2(left + 360, 501 - 285 * DISPLAY_SCALE), Color("344752"), 1, true)
		draw_circle(Vector2(220 + i * 420, 501), 3, Color("dbba7e"))
