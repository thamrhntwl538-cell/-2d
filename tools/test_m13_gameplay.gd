extends SceneTree
var world: Node2D
var hero: CharacterBody2D
var observed: Dictionary = {}
var failures: Array[String] = []
var ticks: int = 0
var initial_y: float = 0.0

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, reason: String) -> void:
	if not condition:
		failures.append(reason)

func step(count: int) -> void:
	for i in range(count):
		await physics_frame
		ticks += 1
		observed[hero.current_pose] = true
		check(hero.lantern_sprite.scale.is_equal_approx(Vector2(0.4, 0.4)), "Sprite scale changed")
		check(hero.lantern_sprite.position.is_equal_approx(Vector2(0, -80)), "Foot pivot changed")
		check(hero.get_node("StableGameplayCollider").shape.size == Vector2(30, 58), "Collider changed")
		var texture: Texture2D = hero.lantern_sprite.sprite_frames.get_frame_texture(hero.lantern_sprite.animation, hero.lantern_sprite.frame)
		check(texture.resource_path.begins_with("res://assets/warden_m13/"), "Old locomotion art selected")
		var key: String = texture.resource_path.get_file().get_basename()
		var point: Array = hero.art_anchors[key]
		var expected_light := Vector2((float(point[0]) - 256.0) * 0.4 * float(hero.facing), (float(point[1]) - 456.0) * 0.4)
		check(hero.lantern_light.position.is_equal_approx(expected_light), "Lantern light does not follow the moved head: " + hero.current_pose)
		if hero.current_pose.ends_with("_run") and hero.dash_time <= 0.0:
			check(is_equal_approx(hero.lantern_sprite.speed_scale, clampf(absf(hero.velocity.x) / 300.0, 0.1, 1.0)), "Run timing is not tied to travel speed")

func capture(name_value: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://qa_m13/" + name_value + ".png")

func run_checks() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.start_new_game()
	hero = world.hero
	DirAccess.make_dir_recursive_absolute("res://qa_m13")
	await step(30)
	check(hero.is_on_floor(), "Player did not settle on the floor")
	initial_y = hero.position.y
	await capture("gameplay_idle")
	Input.action_press("move_right")
	await step(40)
	check(hero.velocity.x > 290.0, "Run speed changed")
	check(hero.current_pose == "unarmed_run", "Run animation not selected")
	await capture("gameplay_run")
	Input.action_press("jump")
	await step(1)
	Input.action_release("jump")
	await step(10)
	check(hero.position.y < initial_y - 50, "Jump did not lift the player")
	await capture("gameplay_jump")
	await step(45)
	Input.action_release("move_right")
	await step(25)
	check(hero.is_on_floor(), "Player did not land")
	check(absf(hero.position.y - initial_y) < 1.0, "Floor anchor drifted")
	Input.action_press("move_left")
	await step(20)
	check(hero.lantern_sprite.flip_h, "Left facing was not mirrored")
	Input.action_release("move_left")
	await step(20)
	hero.has_blade = true
	await step(10)
	check(hero.current_pose == "armed_ready", "Equipped idle not selected")
	var lib: SpriteFrames = hero.lantern_sprite.sprite_frames
	for suffix in ["idle", "run", "jump", "fall", "land", "stop"]:
		check(lib.get_frame_texture("unarmed_" + suffix, 0) == lib.get_frame_texture("armed_" + suffix, 0), "Different anatomy after equipping: " + suffix)
	Input.action_press("move_right")
	await step(20)
	Input.action_press("jump")
	await step(1)
	Input.action_release("jump")
	await step(12)
	await capture("gameplay_equipped_jump")
	await step(44)
	Input.action_release("move_right")
	await step(25)
	for suffix in ["idle", "run", "jump", "fall", "land", "stop"]:
		check(observed.has("unarmed_" + suffix), "State not exercised: unarmed_" + suffix)
	for suffix in ["ready", "run", "jump", "fall", "land", "stop"]:
		check(observed.has("armed_" + suffix), "State not exercised: armed_" + suffix)
	check(is_equal_approx(float(lib.get_frame_count("unarmed_run")) / lib.get_animation_speed("unarmed_run"), 6.0 / 13.0), "Original run cycle duration changed")
	var report: Dictionary = {"godot": Engine.get_version_info().string, "renderer": RenderingServer.get_video_adapter_name(), "physics_ticks": ticks, "states": observed.keys(), "failures": failures, "passed": failures.is_empty(), "scale": 0.4, "collider": [30, 58], "run_frames": lib.get_frame_count("unarmed_run"), "run_fps": lib.get_animation_speed("unarmed_run"), "run_cycle_seconds": float(lib.get_frame_count("unarmed_run")) / lib.get_animation_speed("unarmed_run")}
	FileAccess.open("res://WARDEN_M13_GAMEPLAY_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("M13 GAMEPLAY ", "PASS" if failures.is_empty() else "FAIL", ": ", JSON.stringify(report))
	world.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
