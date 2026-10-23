extends "res://tools/capture_m18.gd"
## Native M19 visual review. Actor/scene composition is declared as fixtures.
## Contact and airborne frames use the real player actions after placement.
const M19_WORLD_PATH := "res://scenes/stage_01/folding_library_m19.tscn"
const M19_OUTPUT := "res://previews/m19"
const M19_REPORT := "user://m19_visual_review.json"

func capture(tag: String, note: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	if frame.is_empty():
		failures.append("Empty rendered viewport "+tag)
		return
	DirAccess.make_dir_recursive_absolute("user://m19_capture_sources")
	frame.save_png("user://m19_capture_sources/"+tag+".png")
	var path := M19_OUTPUT+"/"+tag+".jpg"
	if frame.save_jpg(path,0.92)!=OK: failures.append("Cannot write "+path)
	captures.append({"path":path,"room":world.current_room,"width":frame.get_width(),"height":frame.get_height(),"hero_pose":world.hero.current_pose,"airborne":not world.hero.is_on_floor(),"configured_fixture":true,"note":note})
	print("M19 CAPTURE ",path)

func close_view() -> void:
	world.camera.process_mode = Node.PROCESS_MODE_DISABLED
	world.camera.zoom = Vector2(3,3)
	world.camera.position = world.hero.position+Vector2(0,-49)
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
	DirAccess.make_dir_recursive_absolute(M19_OUTPUT)
	var packed: PackedScene = load(M19_WORLD_PATH)
	if packed==null:
		failures.append("M19 scene missing")
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
	await step(7)
	await capture("03_forward_slash","Native attack Input from a configured closeup; same M19 parts and geometry during contact.")
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
	await capture("05_jumping","Actual jump Input with the new M19 body and lantern; original traversal physics.")
	await step(90)
	await prepare_hero()
	close_view()
	Input.action_press("look_up")
	Input.action_press("attack")
	await step(10)
	Input.action_release("attack")
	Input.action_release("look_up")
	await capture("06_upward_slash","Actual upward slash Input; shared lantern size, warm light and wrist-anchored sword.")
	await step(30)
	await prepare_hero()
	world.hero.position = Vector2(1065,1165)
	world.hero.velocity = Vector2.ZERO
	await step(2)
	close_view()
	Input.action_press("look_down")
	Input.action_press("attack")
	await step(10)
	Input.action_release("attack")
	Input.action_release("look_down")
	close_view()
	await capture("07_downward_slash","Configured airborne location followed by actual downward-attack Input; not traversal proof.")
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
	var report := {"engine":Engine.get_version_info().string,"rendered":true,"captures":captures,"failures":failures,"save_restored":restored,"scope":"declared M19 visual fixtures; native action samples after actor placement; mechanics evidence separately in test_m19_hero.gd"}
	FileAccess.open(M19_REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	OS.delay_msec(50)
	await process_frame
	quit(0 if failures.is_empty() else 1)
