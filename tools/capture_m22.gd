extends "res://tools/capture_m18.gd"
## Configured native review of the M22 curated reading spaces. These supported
## scene placements and fitted cameras are visual fixtures, not route evidence.
const M22_WORLD := "res://scenes/stage_01/folding_library_m22.tscn"
const M22_OUTPUT := "res://previews/m22"
const M22_REPORT := "user://m22_visual_review.json"

func capture(tag: String, note: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	var path := M22_OUTPUT+"/"+tag+".jpg"
	if frame.is_empty(): failures.append("Empty viewport "+tag); return
	DirAccess.make_dir_recursive_absolute("user://m22_capture_sources")
	frame.save_png("user://m22_capture_sources/"+tag+".png")
	if frame.save_jpg(path,.93)!=OK: failures.append("Cannot save "+path)
	captures.append({"path":path,"room":world.current_room,"size":[frame.get_width(),frame.get_height()],"configured_fixture":true,"supported_actor":world.hero.is_on_floor(),"hero_position":[world.hero.position.x,world.hero.position.y],"camera_zoom":[world.camera.zoom.x,world.camera.zoom.y],"note":note})
	print("M22 CAPTURE ",path)

func fixture_room(id: int, at: Vector2) -> void:
	if world.hud.panel_open:
		world.hud.action.emit("close_panel",null)
		for tick in range(80):
			if not world.panel_closing: break
			await step(1)
	world._load_room(id,"left",at)
	world.hero.velocity = Vector2.ZERO
	world.hero.hp = 6
	world.hero.energy = 99
	world.hero.reset_combat_motion()
	world.camera.process_mode = Node.PROCESS_MODE_DISABLED
	world.camera.zoom = Vector2.ONE*1.35
	world.camera.position = world.camera.bounded(at+Vector2(80,-155))
	world.camera.reset_smoothing()
	world.camera.force_update_scroll()
	if is_instance_valid(world.fade): world.fade.visible=false
	await step(24)
	if not world.hero.is_on_floor(): failures.append("Unsupported configured review placement room%02d at%s"%[id,world.hero.position])

func run_capture() -> void:
	remember_files()
	DirAccess.make_dir_recursive_absolute(M22_OUTPUT)
	var packed: PackedScene = load(M22_WORLD)
	if packed==null: failures.append("M22 scene missing"); quit(1); return
	world = packed.instantiate()
	packed = null
	world.restore_saved_game = false
	world.environment_preview = true
	world.transition_seconds = .001
	root.add_child(world)
	await step(45)
	var layouts = load("res://scripts/stage/m22_layouts.gd")
	for room_id in range(1,16):
		var definition: Dictionary = layouts.room(room_id)
		var at: Vector2 = definition.spawns.left
		var feature := "native arrival and room entrance"
		for item in definition.objects:
			if str(item.get("kind","")) in ["note","book"] and not item.has("visible_requires"):
				at = item.pos-Vector2(60,0)
				feature = "curated %s reading nook for %s"%[item.get("reading_style","lectern"),item.id]
				break
		await fixture_room(room_id,at)
		await capture("%02d_room_%02d"%[room_id,room_id],feature+"; configured supported position, fitted1.35 camera, original M20 hero plus native eyes")
	await fixture_room(8,Vector2(2600,900))
	world.camera.zoom = Vector2.ONE*1.1
	world.camera.position = world.camera.bounded(Vector2(2810,760))
	world.camera.force_update_scroll()
	for tick in range(160):
		await step(1)
		var warned := false
		for actor in world.enemies:
			if is_instance_valid(actor) and actor.state=="windup": warned=true
		if warned: break
	await capture("16_turret_gallery","configured real optional gallery; native turret warning and solid book cover, no target or warning injection")
	await fixture_room(3,Vector2(1040,900))
	world.camera.zoom = Vector2.ONE*1.6
	world.camera.position = world.camera.bounded(Vector2(1050,795))
	world.camera.force_update_scroll()
	for tick in range(160):
		await step(1)
		var warned := false
		for actor in world.enemies:
			if is_instance_valid(actor) and actor.state=="windup": warned=true
		if warned: break
	await capture("17_wraith_warning","configured actual balcony; native wraith warning and captured floor marker, no injected attack state")
	for action in ["move_left","move_right","attack","jump","interact","look_up","look_down"]:
		if InputMap.has_action(action): Input.action_release(action)
	stop_audio(world)
	OS.delay_msec(120)
	await process_frame
	world.queue_free()
	world = null
	await process_frame
	await process_frame
	var restored := restore_files()
	if not restored: failures.append("Original save/settings bytes not restored")
	FileAccess.open(M22_REPORT,FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"captures":captures,"failures":failures,"save_restored":restored,"scope":"native configured15-room reading/arrival visual review and actual AI warning fixtures; genuine input-only route and UI evidence are separate test_m22_world reports"},"\t"))
	OS.delay_msec(50)
	await process_frame
	quit(0 if failures.is_empty() else 1)
