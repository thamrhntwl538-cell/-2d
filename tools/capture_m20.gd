extends "res://tools/capture_m18.gd"
## Native M20 visual review. Actor/scene composition is declared as fixtures.
## Additional expression/action footage is added after the M20 timing API is settled.
## Contact and airborne frames use the real player actions after placement.
const M20_WORLD_PATH := "res://scenes/stage_01/folding_library_m20.tscn"
const M20_OUTPUT := "res://previews/m20"
const M20_REPORT := "user://m20_visual_review.json"

var footage_label: Label
var footage_frames: int = 0
var footage_start_frame: int = 0
var footage_zoom: float = 3.0
var footage_offset := Vector2(0,-49)
var footage_segments: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run_footage" if "--footage" in OS.get_cmdline_user_args() else "run_capture")

func film_step(count: int) -> void:
	for tick in range(count):
		await step(1)
		world.camera.zoom = Vector2.ONE*footage_zoom
		world.camera.position = world.hero.position+footage_offset
		world.camera.reset_smoothing()
		world.camera.force_update_scroll()
		footage_frames += 1

func film_segment(title: String) -> void:
	if footage_segments.is_empty(): footage_start_frame = Engine.get_process_frames()
	footage_zoom = 2.4 if "UPWARD" in title or "DOWNWARD" in title else 3.0
	footage_offset = Vector2(0,-80) if "UPWARD" in title else (Vector2(0,-10) if "DOWNWARD" in title else Vector2(0,-49))
	footage_label.text = "M20 / NATIVE GODOT FIXTURE / "+title
	footage_segments.append({"frame":footage_frames,"label":title,"camera_zoom":footage_zoom,"camera_offset":[footage_offset.x,footage_offset.y]})

func film_pulse(action: String, pressed: int, after: int) -> void:
	await physics_frame
	Input.action_press(action)
	await film_step(pressed)
	Input.action_release(action)
	await film_step(after)

func run_footage() -> void:
	remember_files()
	var packed: PackedScene = load(M20_WORLD_PATH)
	if packed==null:
		quit(1)
		return
	world = packed.instantiate()
	packed = null
	world.restore_saved_game = false
	world.environment_preview = true
	world.transition_seconds = 0.001
	root.add_child(world)
	await step(45)
	await fixture_room(1,Vector2(1250,1260))
	world.hero.hp = 6
	world.hero.energy = 99
	world.hero.facing = 1
	world.hero.reset_combat_motion()
	close_view()
	var overlay := CanvasLayer.new()
	overlay.layer = 99
	root.add_child(overlay)
	var backing := ColorRect.new()
	backing.position = Vector2(0,678)
	backing.size = Vector2(1280,42)
	backing.color = Color(0.025,0.03,0.05,0.94)
	overlay.add_child(backing)
	footage_label = Label.new()
	footage_label.position = Vector2(10,684)
	footage_label.size = Vector2(1260,30)
	footage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footage_label.add_theme_font_size_override("font_size",18)
	footage_label.add_theme_color_override("font_color",Color("ead6b3"))
	overlay.add_child(footage_label)
	film_segment("SHARED HERO / IDLE")
	await film_step(45)
	film_segment("RUN / TURN / STOP")
	Input.action_press("move_right")
	await film_step(60)
	Input.action_release("move_right")
	Input.action_press("move_left")
	await film_step(50)
	Input.action_release("move_left")
	await film_step(50)
	film_segment("SHORT TAP JUMP")
	await film_pulse("jump",2,34)
	film_segment("HELD HIGH JUMP")
	await film_pulse("jump",30,50)
	film_segment("BASIC DASH / NO INVINCIBILITY")
	await film_pulse("dash",1,59)
	film_segment("FORWARD FLAME SLASH")
	await film_pulse("attack",1,29)
	await film_pulse("attack",1,29)
	await film_pulse("attack",1,29)
	film_segment("UPWARD FLAME SLASH")
	Input.action_press("look_up")
	await film_pulse("attack",1,29)
	await film_pulse("attack",1,29)
	await film_pulse("attack",1,29)
	Input.action_release("look_up")
	film_segment("AIRBORNE DOWNWARD SLASH")
	for repetition in range(2):
		Input.action_press("jump")
		await film_step(10)
		Input.action_release("jump")
		Input.action_press("look_down")
		await film_pulse("attack",1,39)
		Input.action_release("look_down")
		await film_step(10)
	film_segment("LOOK UP / LOOK DOWN")
	Input.action_press("look_up")
	await film_step(60)
	Input.action_release("look_up")
	Input.action_press("look_down")
	await film_step(60)
	Input.action_release("look_down")
	film_segment("JUMP + DASH + ATTACK INPUTS")
	Input.action_press("move_right")
	Input.action_press("jump")
	await film_step(8)
	Input.action_release("jump")
	Input.action_press("dash")
	await film_step(2)
	Input.action_release("dash")
	Input.action_press("attack")
	await film_step(2)
	Input.action_release("attack")
	await film_step(20)
	Input.action_release("move_right")
	await film_step(58)
	film_segment("ONE ATLAS / ORIGINAL ENVIRONMENT")
	await film_step(45)
	for action in ["attack","look_down","look_up","jump","heal","dash","move_left","move_right"]:
		if InputMap.has_action(action): Input.action_release(action)
	stop_audio(world)
	OS.delay_msec(120)
	await process_frame
	world.queue_free()
	world = null
	overlay.queue_free()
	await process_frame
	await process_frame
	var restored := restore_files()
	var report := {"engine":Engine.get_version_info().string,"configured_fixture":true,"actual_input":true,"follow_camera_zoom":3,"motion_frames":footage_frames,"movie_start_frame":footage_start_frame,"movie_end_frame":Engine.get_process_frames(),"segments":footage_segments,"save_restored":restored,"scope":"native MovieWriter demonstration after declared room/actor setup; not uninterrupted campaign traversal evidence"}
	FileAccess.open("user://m20_footage_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M20 FOOTAGE ",JSON.stringify(report))
	OS.delay_msec(50)
	await process_frame
	quit(0 if restored else 1)

func capture(tag: String, note: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	if frame.is_empty():
		failures.append("Empty rendered viewport "+tag)
		return
	DirAccess.make_dir_recursive_absolute("user://m20_capture_sources")
	frame.save_png("user://m20_capture_sources/"+tag+".png")
	var path := M20_OUTPUT+"/"+tag+".jpg"
	if frame.save_jpg(path,0.92)!=OK: failures.append("Cannot write "+path)
	captures.append({"path":path,"room":world.current_room,"width":frame.get_width(),"height":frame.get_height(),"hero_pose":world.hero.current_pose,"airborne":not world.hero.is_on_floor(),"attack_elapsed":world.hero.attack_elapsed,"contact_active":world.hero.active_strike_time>0,"expression":world.hero.expression_kind,"configured_fixture":true,"note":note})
	print("M20 CAPTURE ",path)

func close_view() -> void:
	world.camera.process_mode = Node.PROCESS_MODE_DISABLED
	world.camera.zoom = Vector2(3,3)
	world.camera.position = world.hero.position+Vector2(0,-49)
	world.camera.reset_smoothing()
	world.camera.force_update_scroll()

func directional_view(upward: bool) -> void:
	world.camera.process_mode = Node.PROCESS_MODE_DISABLED
	world.camera.zoom = Vector2(2.4,2.4)
	world.camera.position = world.hero.position+Vector2(0,-80 if upward else -10)
	world.camera.reset_smoothing()
	world.camera.force_update_scroll()

func prepare_hero(at: Vector2 = Vector2(1065,1260)) -> void:
	await fixture_room(2,at)
	for actor in world.enemies:
		if is_instance_valid(actor): actor.process_mode = Node.PROCESS_MODE_DISABLED
	world.hero.hp = 6
	world.hero.energy = 99
	world.hero.invulnerable = 0
	world.hero.facing = 1
	world.hero.reset_combat_motion()
	await step(8)
	if is_instance_valid(world.fade): world.fade.hide()

func run_capture() -> void:
	remember_files()
	DirAccess.make_dir_recursive_absolute(M20_OUTPUT)
	var packed: PackedScene = load(M20_WORLD_PATH)
	if packed==null:
		failures.append("M20 scene missing")
		quit(1)
		return
	world = packed.instantiate()
	packed = null
	world.restore_saved_game = false
	world.environment_preview = true
	world.transition_seconds = 0.001
	root.add_child(world)
	await step(45)
	await prepare_hero()
	world.hud.set_language("ar")
	await step(5)
	await capture("01_gameplay_idle","Configured native encounter composition; new compact lantern hero at actual gameplay size.")
	close_view()
	await step(3)
	await capture("02_hero_closeup","Configured3×camera inspection of reference-derived amber lantern, scarf, pale gloves and dark short body.")
	Input.action_press("attack")
	await step(2)
	Input.action_release("attack")
	await step(3)
	await capture("03_forward_slash","Native attack Input from a configured closeup; same M20 parts and geometry during contact.")
	await step(30)
	await prepare_hero()
	close_view()
	Input.action_press("move_right")
	await step(9)
	Input.action_release("move_right")
	await capture("04_running","Actual movement Input sampled during the new run; configured camera only.")
	await prepare_hero()
	close_view()
	Input.action_press("jump")
	await step(3)
	Input.action_release("jump")
	await step(8)
	close_view()
	await capture("05_jumping","Actual jump Input with the new M20 body and lantern; original traversal physics.")
	await step(90)
	await prepare_hero()
	close_view()
	Input.action_press("dash")
	await step(5)
	Input.action_release("dash")
	close_view()
	await capture("14_dash","Actual dash Input from a configured closeup; airborne tucked legs and warm speed wisps, no duplicate body.")
	await step(60)
	await prepare_hero()
	close_view()
	Input.action_press("look_up")
	Input.action_press("attack")
	await step(6)
	Input.action_release("attack")
	Input.action_release("look_up")
	directional_view(true)
	await capture("06_upward_slash","Actual upward slash Input; configured2.4×camera with offset(0,-80) to keep the full flame arc below the HUD.")
	await step(30)
	await prepare_hero()
	world.hero.position = Vector2(1065,1165)
	world.hero.velocity = Vector2.ZERO
	await step(2)
	close_view()
	Input.action_press("look_down")
	Input.action_press("attack")
	await step(6)
	Input.action_release("attack")
	Input.action_release("look_down")
	directional_view(false)
	await capture("07_downward_slash","Configured airborne location followed by actual downward-attack Input;2.4×camera with offset(0,-10) keeps the full arc in view; not traversal proof.")
	await step(60)
	await prepare_hero()
	close_view()
	world.hero.invulnerable = 0
	world.hero.hurt(1,world.hero.position.x+100)
	await step(6)
	await capture("08_recoil","Configured damage fixture demonstrates that recoil retains the same hero model.")
	await step(75)
	await prepare_hero()
	close_view()
	world.hero.hp = 4
	world.hero.energy = 99
	Input.action_press("heal")
	await step(20)
	await capture("09_focus","Actual Focus input with the same amber lantern and shared energy.")
	Input.action_release("heal")
	await step(8)
	world.hero.hp = 0
	world.hero._update_animation()
	await step(12)
	await capture("10_death_pose","Declared death-presentation fixture; no claim of a gameplay loss in this visual composition.")
	for action in ["attack","look_down","look_up","jump","heal","move_right"]:
		if InputMap.has_action(action): Input.action_release(action)
	stop_audio(world)
	OS.delay_msec(120)
	await process_frame
	world.queue_free()
	world = null
	await process_frame
	await process_frame
	var restored := restore_files()
	if not restored: failures.append("Original user data was not restored")
	var report := {"engine":Engine.get_version_info().string,"rendered":true,"captures":captures,"failures":failures,"save_restored":restored,"scope":"declared M20 visual fixtures; native action samples after actor placement; mechanics evidence separately in test_m20_hero.gd"}
	FileAccess.open(M20_REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	OS.delay_msec(50)
	await process_frame
	quit(0 if failures.is_empty() else 1)
