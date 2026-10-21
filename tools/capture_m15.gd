extends SceneTree
## Isolated visual review, not a claim of continuous traversal. Full actual-input
## route validation is tools/test_m15_world.gd and M15_ENVIRONMENT_QA.json.
var world: Node2D
var captures: Array[String] = []
const SHOTS := [Vector2(220,1260),Vector2(1420,900),Vector2(1920,1260),Vector2(1560,1260),Vector2(780,1260),Vector2(1310,1260),Vector2(1210,1260),Vector2(350,1260),Vector2(2100,1620),Vector2(1100,1260)]

func _initialize() -> void:
	call_deferred("run_review")

func run_review() -> void:
	world = load("res://scenes/stage_01/forgotten_wing.tscn").instantiate()
	world.restore_saved_game = false
	root.add_child(world)
	DirAccess.make_dir_recursive_absolute("res://previews/m15")
	for index in range(10):
		await process_frame
		world._load_room(index,"left",SHOTS[index])
		for tick in range(60): await physics_frame
		if index in [4,5,6,8]:
			await physics_frame
			Input.action_press("interact")
			for tick in range(3): await physics_frame
			Input.action_release("interact")
		for tick in range(45): await physics_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var filename := "res://previews/m15/%02d_%s.png" % [index+1,world.data.mood]
		root.get_texture().get_image().save_png(filename)
		captures.append(filename)
		print("M15 VISUAL CAPTURE ",filename)
	# An actual-input, native-platform ride follows the isolated room compositions.
	await process_frame
	world._load_room(3,"left")
	for tick in range(30): await physics_frame
	Input.action_press("move_right")
	for tick in range(240):
		await physics_frame
		if world.hero.position.x > 1105: break
	Input.action_release("move_right")
	for tick in range(20): await physics_frame
	for stop in range(3):
		await physics_frame
		Input.action_press("interact")
		for tick in range(3): await physics_frame
		Input.action_release("interact")
		for tick in range(400):
			await physics_frame
			if not world.elevator.moving and world.elevator.current_stop == stop+1: break
		for tick in range(12): await physics_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var lift_image := "res://previews/m15/11_archive_native_lift.png"
	root.get_texture().get_image().save_png(lift_image)
	captures.append(lift_image)
	FileAccess.open("res://M15_VISUAL_REVIEW.json",FileAccess.WRITE).store_string(JSON.stringify({"godot":Engine.get_version_info().string,"captures":captures,"method":"Ten isolated room compositions followed by an actual-input native elevator ride. Room-loading/shot positions are explicit visual-review fixtures, separate from the full continuous-input route QA.","frames_per_room":105,"native_lift_end_y":world.hero.position.y,"native_lift_stop":world.elevator.current_stop},"\t"))
	world.queue_free()
	await process_frame
	await process_frame
	quit()
