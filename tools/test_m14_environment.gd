extends SceneTree
## Actual-input traversal QA for the M14 opening, with separately labelled
## isolated collision probes. Run with a dedicated XDG_DATA_HOME for QA.
const OPENING = preload("res://scenes/stage_01/silent_entrance.tscn")
const SAVE_FILE := "user://silent_entrance_checkpoint.json"
const PREVIEW_DIRECTORY := "res://previews/m14"
var world: Node2D
var hero: CharacterBody2D
var failures: Array[String] = []
var route: Array[Dictionary] = []
var captures: Array[String] = []
var physics_ticks: int = 0
var route_ticks: int = 0
var camera_samples: int = 0
var max_camera_step: float = 0.0
var last_camera_position := Vector2.ZERO
var sample_route: bool = false
var had_saved_checkpoint: bool = false
var previous_checkpoint: String = ""
var camera_bounds_valid: bool = true

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)

func release_controls() -> void:
	for action in ["move_left", "move_right", "jump", "interact", "pause_game", "dash"]:
		if InputMap.has_action(action): Input.action_release(action)

func step(count: int) -> void:
	for i in range(count):
		await physics_frame
		physics_ticks += 1
		if sample_route and is_instance_valid(world):
			route_ticks += 1
			var camera: Camera2D = world.camera
			var center: Vector2 = camera.get_screen_center_position()
			var half_view: Vector2 = root.get_visible_rect().size / camera.zoom / 2.0
			var room: Rect2 = camera.room_rect
			var inside: bool = center.x - half_view.x >= room.position.x - 0.5 and center.y - half_view.y >= room.position.y - 0.5 and center.x + half_view.x <= room.end.x + 0.5 and center.y + half_view.y <= room.end.y + 0.5
			camera_bounds_valid = camera_bounds_valid and inside
			if camera_samples > 0:
				max_camera_step = maxf(max_camera_step, center.distance_to(last_camera_position))
			last_camera_position = center
			camera_samples += 1

func pulse(action: String) -> void:
	# Production input is sampled on the fixed physics path. In particular,
	# capture() resumes after drawing, so align a fresh edge to the next physics
	# signal instead of stamping an idle frame that has already been processed.
	await physics_frame
	Input.action_press(action)
	await step(3)
	Input.action_release(action)
	await step(3)

func move_toward_x(target_x: float) -> void:
	var error: float = target_x - hero.position.x
	var acceleration: float = 2650.0 if hero.is_on_floor() else 1950.0
	var braking_distance: float = hero.velocity.x * hero.velocity.x / (2.0 * acceleration)
	var moving_toward: bool = hero.velocity.x * error > 0.0
	if absf(error) < 3.0 or (moving_toward and absf(error) < braking_distance + 3.0):
		Input.action_release("move_left")
		Input.action_release("move_right")
	elif error > 0.0:
		Input.action_release("move_left")
		Input.action_press("move_right")
	else:
		Input.action_release("move_right")
		Input.action_press("move_left")

func walk_to(target_x: float, maximum_ticks: int = 900) -> bool:
	for i in range(maximum_ticks):
		move_toward_x(target_x)
		await step(1)
		if absf(hero.position.x - target_x) <= 6.0 and absf(hero.velocity.x) < 3.0 and hero.is_on_floor():
			release_controls()
			return true
	Input.action_release("move_left")
	Input.action_release("move_right")
	check(false, "Could not walk to x=%.1f; stopped at %s" % [target_x, hero.position])
	return false

func jump_to(target_x: float, platform_y: float, label: String) -> bool:
	var start: Vector2 = hero.position
	var began_airborne: bool = false
	var minimum_y: float = hero.position.y
	var landing: Vector2 = hero.position
	var landed: bool = false
	Input.action_press("jump")
	for i in range(100):
		move_toward_x(target_x)
		await step(1)
		if i == 2: Input.action_release("jump")
		minimum_y = minf(minimum_y, hero.position.y)
		if not hero.is_on_floor(): began_airborne = true
		if began_airborne and hero.is_on_floor():
			landing = hero.position
			landed = true
			break
	Input.action_release("jump")
	check(began_airborne, label + ": jump never left the support surface")
	check(landed, label + ": did not land within 100 physics ticks")
	check(landed and absf(landing.y - platform_y) < 2.0, label + ": landed on wrong elevation: " + str(landing))
	var arrived: bool = false
	if landed and absf(landing.y - platform_y) < 2.0:
		arrived = await walk_to(target_x, 120)
	else:
		release_controls()
	var result: bool = began_airborne and landed and absf(landing.y - platform_y) < 2.0 and arrived
	route.append({"name":label, "start":[start.x,start.y], "landing":[landing.x,landing.y], "target":[target_x,platform_y], "apex_y":minimum_y, "passed":result, "uses_real_input":true, "teleport":false})
	return result

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var file: String = PREVIEW_DIRECTORY + "/" + label + ".png"
	var result: Error = root.get_texture().get_image().save_png(file)
	check(result == OK, "Could not save preview " + label)
	captures.append(file)

func instantiate_opening() -> void:
	release_controls()
	if is_instance_valid(world):
		world.queue_free()
		await process_frame
		await process_frame
	world = OPENING.instantiate()
	root.add_child(world)
	hero = world.hero
	await step(30)

func run_checks() -> void:
	had_saved_checkpoint = FileAccess.file_exists(SAVE_FILE)
	if had_saved_checkpoint:
		previous_checkpoint = FileAccess.get_file_as_string(SAVE_FILE)
		check(DirAccess.remove_absolute(SAVE_FILE) == OK, "Cannot isolate the opening checkpoint save")
	DirAccess.make_dir_recursive_absolute(PREVIEW_DIRECTORY)
	await instantiate_opening()
	check(hero.is_on_floor(), "Spawn did not settle on solid ground")
	check(absf(hero.position.y - 1260.0) < 1.0, "Spawn floor does not match y=1260")
	check(not world.route_open and not world.terminal.active, "Fresh opening started with its route unlocked")
	check(not world.gate.get_node("Barrier/Collision").disabled, "Fresh gate has no blocking collision")
	check(hero.get_node("StableGameplayCollider").shape.size == Vector2(30,58), "Player collider dimensions changed")
	check(hero.lantern_sprite.scale.is_equal_approx(Vector2(0.4,0.4)), "Player art scale changed")
	check(hero.lantern_sprite.position.is_equal_approx(Vector2(0,-80)), "M13 player foot pivot changed")
	check(not hero.has_blade and not hero.has_code_slash, "Environment opening unexpectedly granted a combat ability")

	# Isolated fixture probe: teleport is used ONLY here to test the far closed
	# gate efficiently. A completely fresh scene then starts the real traversal.
	hero.position = Vector2(3280,1260)
	hero.velocity = Vector2.ZERO
	Input.action_press("move_right")
	await step(60)
	Input.action_release("move_right")
	await step(12)
	var closed_gate_probe_x: float = hero.position.x
	check(closed_gate_probe_x < 3332.0 and closed_gate_probe_x > 3310.0, "Closed gate failed to stop the real player collider")
	await instantiate_opening()
	await step(75)
	await capture("01_silent_entrance_spawn")
	sample_route = true
	camera_samples = 0

	# The complete mandatory route begins at the actual safe spawn. No position
	# assignments, velocity injection, dash, or direct mechanism activation follow.
	check(await walk_to(350.0), "Could not reach the checkpoint bench")
	await pulse("interact")
	check(FileAccess.file_exists(SAVE_FILE), "Bench did not write its checkpoint")
	check(world.checkpoint_position.is_equal_approx(Vector2(440,1260)), "Bench respawn is not on the safe floor")
	var saved_bench: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_FILE))
	check(saved_bench is Dictionary and saved_bench.get("version",0) == 14, "Bench checkpoint schema is invalid")

	await pulse("pause_game")
	check(not world.gameplay_active and world.pause_panel.visible, "Pause input did not pause the opening")
	var paused_position: Vector2 = hero.position
	var paused_elapsed: float = world.elapsed
	Input.action_press("move_right")
	await step(30)
	Input.action_release("move_right")
	check(hero.position.distance_to(paused_position) < 0.1, "Player moved while paused")
	check(absf(world.elapsed-paused_elapsed) < 0.001, "Environment animation clock moved while paused")
	await pulse("pause_game")
	check(world.gameplay_active and not world.pause_panel.visible, "Pause input did not resume the opening")

	await walk_to(650.0)
	await jump_to(800.0,1140.0,"first_ledge")
	await walk_to(880.0)
	await jump_to(1080.0,1020.0,"second_ledge")
	await walk_to(1170.0)
	await jump_to(1375.0,900.0,"third_ledge")
	await capture("02_upper_stair_route")
	await walk_to(1460.0)
	await jump_to(1665.0,780.0,"upper_stair")
	await walk_to(1810.0)
	await jump_to(2010.0,780.0,"gallery_gap")
	await walk_to(2475.0)
	await step(30)
	check(hero.position.distance_to(world.terminal.position) < 96.0, "Terminal is unreachable from its gallery")
	check(not world.route_open, "Gate unlocked without activating the gallery terminal")
	await capture("03_gallery_terminal")
	await pulse("interact")
	check(world.route_open and world.terminal.active and world.gate.opening, "Terminal interaction did not start the access mechanism")
	check(not world.gate.get_node("Barrier/Collision").disabled, "Gate collision disappeared before its opening animation")
	await step(115)
	check(world.gate.is_open and world.gate.get_node("Barrier/Collision").disabled, "Gate animation did not release collision")
	await capture("04_access_restored")

	# Optional vertical exploration is exercised independently of route unlocking.
	await walk_to(2520.0)
	await jump_to(2670.0,660.0,"optional_nook_step")
	await walk_to(2645.0)
	await jump_to(2440.0,550.0,"optional_reading_nook")
	await step(24)
	await pulse("interact")
	check(world.discovered_note, "Optional note could not be discovered through normal traversal")
	await capture("05_optional_reading_nook")

	# Walk off the optional shelf, return to the gapless floor, and cross the
	# previously blocked gate using ordinary movement.
	await walk_to(3560.0)
	check(hero.position.x > 3530.0 and world.reached_threshold, "Opened gate cannot be crossed to the programming-wing threshold")
	check(hero.is_on_floor() and absf(hero.position.y-1260.0) < 1.0, "Return route did not land safely on the ground")
	await step(30)
	await capture("06_open_programming_wing")
	await walk_to(3806.0)
	Input.action_press("move_right")
	await step(45)
	Input.action_release("move_right")
	check(hero.position.x <= 3806.1 and hero.position.x >= 3780.0, "East room boundary is not safe")
	check(camera_bounds_valid, "Camera exposed a viewport outside the intended room")
	check(max_camera_step < 16.0, "Camera made an abrupt step during normal traversal: %.2fpx" % max_camera_step)
	sample_route = false

	# Re-open the scene from the real saved data, preserving the progression
	# written by terminal activation. This is a restore test, not route traversal.
	await instantiate_opening()
	check(hero.position.distance_to(Vector2(440,1260)) < 2.0, "Checkpoint restore does not spawn beside the safe bench")
	check(world.route_open and world.terminal.active, "Checkpoint restore lost the terminal state")
	check(world.discovered_note, "Checkpoint restore lost the optional note discovery")
	check(world.gate.is_open and world.gate.get_node("Barrier/Collision").disabled, "Restored unlocked gate still blocks traversal")
	var saved_after_restore: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_FILE))
	check(saved_after_restore is Dictionary and bool(saved_after_restore.get("note",false)), "Restoring access rewrote the saved note discovery")
	await instantiate_opening()
	check(world.discovered_note, "Second checkpoint reload lost the optional note discovery")
	var saved_after_second_restore: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_FILE))
	check(saved_after_second_restore is Dictionary and bool(saved_after_second_restore.get("note",false)), "Second checkpoint reload rewrote the saved note discovery")

	var report := {"passed":failures.is_empty(), "godot":Engine.get_version_info().string, "renderer":RenderingServer.get_video_adapter_name(), "scene":"res://scenes/stage_01/silent_entrance.tscn", "physics_ticks":physics_ticks, "actual_input_route_ticks":route_ticks, "route":route, "isolated_probe":{"purpose":"closed gate collider only; fresh scene afterwards", "teleport_count":1, "closed_gate_stopped_x":closed_gate_probe_x}, "mandatory_route_teleports":0, "mandatory_route_uses_dash":false, "camera":{"samples":camera_samples,"bounds_valid":camera_bounds_valid,"max_step_px":max_camera_step}, "tested":["safe_spawn","original_M13_actor_scale_and_collider","closed_gate_collision","bench_save","pause_resume","mandatory_platform_traversal","gallery_terminal_input","gate_open_animation","optional_reading_nook","safe_return_route","opened_gate_crossing","east_boundary","camera_bounds_and_continuity","checkpoint_restore"], "previews":captures, "failures":failures, "limitations":["Executed engine version is reported above; no claim of Godot 4.7 execution.","M14 tests the opening room only; remaining Stage 1 areas and approved enemies are deferred.","Camera coverage is checked geometrically; art composition also requires visual review of the captured engine images."]}
	FileAccess.open("res://M14_ENVIRONMENT_QA.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M14 ENVIRONMENT ", "PASS" if failures.is_empty() else "FAIL", ": ", JSON.stringify(report))
	release_controls()
	world.queue_free()
	await process_frame
	await process_frame
	if had_saved_checkpoint:
		FileAccess.open(SAVE_FILE,FileAccess.WRITE).store_string(previous_checkpoint)
	elif FileAccess.file_exists(SAVE_FILE):
		DirAccess.remove_absolute(SAVE_FILE)
	quit(0 if failures.is_empty() else 1)
