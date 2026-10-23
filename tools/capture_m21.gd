extends "res://tools/capture_m18.gd"
## Native M21 visual review. Actor/scene composition is declared as fixtures.
## Additional expression/action footage is added after the M21 timing API is settled.
## Contact and airborne frames use the real player actions after placement.
const M21_WORLD_PATH := "res://scenes/stage_01/folding_library_m21.tscn"
const M21_OUTPUT := "res://previews/m21"
const M21_REPORT := "user://m21_visual_review.json"

var footage_label: Label
var footage_frames: int = 0
var footage_start_frame: int = 0
var footage_zoom: float = 3.0
var footage_offset := Vector2(0,-49)
var footage_segments: Array[Dictionary] = []
var lighting_metrics: Dictionary = {}
var hero_preservation: Dictionary = {}

func _initialize() -> void:
	call_deferred("run_footage" if "--footage" in OS.get_cmdline_user_args() else ("run_initial_capture" if "--initial" in OS.get_cmdline_user_args() else ("run_pair_only" if "--pair-only" in OS.get_cmdline_user_args() else "run_capture")))

func film_step(count: int) -> void:
	for tick in range(count):
		await step(1)
		world.camera.zoom = Vector2.ONE*footage_zoom
		world.camera.position = world.hero.position+footage_offset
		world.camera.reset_smoothing()
		world.camera.force_update_scroll()
		footage_frames += 1

func film_segment(title: String, zoom_value: float = 3.0, offset_value: Vector2 = Vector2(0,-49)) -> void:
	if footage_segments.is_empty(): footage_start_frame = Engine.get_process_frames()
	footage_zoom = zoom_value
	footage_offset = offset_value
	footage_label.text = "M21 / NATIVE GODOT FIXTURE / "+title
	footage_segments.append({"frame":footage_frames,"label":title,"camera_zoom":footage_zoom,"camera_offset":[footage_offset.x,footage_offset.y]})

func film_pulse(action: String, pressed: int, after: int) -> void:
	await physics_frame
	Input.action_press(action)
	await film_step(pressed)
	Input.action_release(action)
	await film_step(after)

func film_drive_toward(x: float) -> void:
	var actor = world.hero
	var error: float = x-actor.position.x
	var accel: float = 2650.0 if actor.is_on_floor() else 1950.0
	var braking: float = actor.velocity.x*actor.velocity.x/(2.0*accel)
	if absf(error)<3.0 or (actor.velocity.x*error>0 and absf(error)<braking+3):
		Input.action_release("move_left")
		Input.action_release("move_right")
	elif error>0:
		Input.action_release("move_left")
		Input.action_press("move_right")
	else:
		Input.action_release("move_right")
		Input.action_press("move_left")

func run_footage() -> void:
	remember_files()
	var packed: PackedScene = load(M21_WORLD_PATH)
	world = packed.instantiate()
	packed = null
	world.restore_saved_game = false
	world.environment_preview = true
	world.transition_seconds = 0.001
	root.add_child(world)
	await step(45)
	await fixture_room(1,Vector2(1000,1260))
	world.hero.hp = 6
	world.hero.energy = 99
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
	film_segment("ROOM01 / MOVING LANTERN / UNCHANGED M20 HERO + EYES",2.2,Vector2(0,-65))
	Input.action_press("move_right")
	await film_step(90)
	Input.action_release("move_right")
	await film_step(60)
	film_segment("ROOM01 / REAL WORLD LANTERN OFF THEN ON",2.2,Vector2(0,-65))
	world.hero.lantern_light.visible = false
	await film_step(30)
	world.hero.lantern_light.visible = true
	await film_step(60)
	await fixture_room(2,Vector2(1065,1260))
	world.hero.hp = 6
	world.hero.invulnerable = 0
	world.hero.reset_combat_motion()
	world.camera.process_mode = Node.PROCESS_MODE_DISABLED
	film_segment("ROOM02 / NATIVE LARVA WARNING AND LUNGE",2.0,Vector2(110,-70))
	await film_step(180)
	Input.action_press("jump")
	Input.action_press("attack")
	await film_step(8)
	Input.action_release("jump")
	Input.action_release("attack")
	await film_step(52)
	await fixture_room(6,Vector2(275,2700))
	world.hero.hp = 6
	world.hero.invulnerable = 0
	world.hero.reset_combat_motion()
	world.camera.process_mode = Node.PROCESS_MODE_DISABLED
	film_segment("ROOM06 / CLOSE PAPER DEPTH / ACTUAL HELD JUMP",1.8,Vector2(80,-105))
	await film_step(60)
	Input.action_press("jump")
	var archive_airborne := false
	for tick in range(120):
		film_drive_toward(332.0)
		await film_step(1)
		if not world.hero.is_on_floor(): archive_airborne = true
		if archive_airborne and world.hero.velocity.y>=0: Input.action_release("jump")
	Input.action_release("jump")
	Input.action_release("move_left")
	Input.action_release("move_right")
	var archive_landed: bool = archive_airborne and world.hero.is_on_floor() and absf(world.hero.position.y-2580.0)<3.0
	if not archive_landed: failures.append("Archive demo jump did not reach its intended landing")
	await film_step(60)
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
	var report := {"engine":Engine.get_version_info().string,"configured_fixture":true,"actual_input":true,"motion_frames":footage_frames,"archive_jump_landed":archive_landed,"failures":failures,"movie_start_frame":footage_start_frame,"movie_end_frame":Engine.get_process_frames(),"segments":footage_segments,"save_restored":restored,"scope":"native MovieWriter review with declared configured cuts room01/02/06, moving localized lantern, original M20 hero with eyes, active native larva and one input jump; not uninterrupted campaign traversal evidence"}
	FileAccess.open("user://m21_footage_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M21 FOOTAGE ",JSON.stringify(report))
	OS.delay_msec(50)
	await process_frame
	quit(0 if restored and failures.is_empty() else 1)

func run_pair_only() -> void:
	remember_files()
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(M21_REPORT))
	var packed: PackedScene = load(M21_WORLD_PATH)
	world = packed.instantiate()
	packed = null
	world.restore_saved_game = false
	world.environment_preview = true
	world.transition_seconds = 0.001
	root.add_child(world)
	await step(45)
	await frozen_lantern_pair()
	stop_audio(world)
	OS.delay_msec(120)
	await process_frame
	world.queue_free()
	world = null
	await process_frame
	await process_frame
	var restored := restore_files()
	var kept: Array = []
	for item in previous.get("captures",[]):
		if not item.path.get_file() in ["16_lantern_on.jpg","17_lantern_off.jpg"]: kept.append(item)
	kept.append_array(captures)
	previous.captures = kept
	previous.lighting_pair = lighting_metrics
	previous.failures = failures
	previous.save_restored = restored
	previous.lighting_pair_refreshed_after_world_only_layer_filter = true
	FileAccess.open(M21_REPORT,FileAccess.WRITE).store_string(JSON.stringify(previous,"\t"))
	OS.delay_msec(50)
	await process_frame
	quit(0 if failures.is_empty() and restored else 1)

func luma(color: Color) -> float:
	return color.r*0.2126+color.g*0.7152+color.b*0.0722

func frame_metrics(frame: Image) -> Dictionary:
	var total := 0.0
	var dark := 0
	var lit := 0
	var count := 0
	for y in range(165,frame.get_height()-48,4):
		for x in range(0,frame.get_width(),4):
			var value := luma(frame.get_pixel(x,y))
			total += value
			dark += 1 if value<0.12 else 0
			lit += 1 if value>0.28 else 0
			count += 1
	return {"world_mean_luma":total/maxi(1,count),"dark_fraction_below_.12":float(dark)/maxi(1,count),"lit_fraction_above_.28":float(lit)/maxi(1,count),"sample_step":4,"hud_top_and_bottom_excluded":true}

func capture_frame(tag: String, note: String) -> Image:
	await capture(tag,note)
	return Image.load_from_file("user://m21_capture_sources/"+tag+".png")

func frozen_lantern_pair() -> void:
	await fixture_room(1,Vector2(1240,1260))
	world.hero.hp = 6
	world.hero.invulnerable = 0
	world.hero.reset_combat_motion()
	world.camera.process_mode = Node.PROCESS_MODE_DISABLED
	world.camera.zoom = Vector2.ONE
	world.camera.position = world.hero.position+Vector2(100,-230)
	world.camera.reset_smoothing()
	world.camera.force_update_scroll()
	await step(5)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	# The wall-light bridge updates, while its elapsed time comes from frozen world.
	world.visuals.process_mode = Node.PROCESS_MODE_ALWAYS
	world.hero.lantern_light.visible = true
	await process_frame
	await process_frame
	var on: Image = await capture_frame("16_lantern_on","Frozen room01 fixture, actual hero lantern ON; exact matching OFF composition in17.")
	world.hero.lantern_light.visible = false
	await process_frame
	await process_frame
	var off: Image = await capture_frame("17_lantern_off","Same frozen actor/camera/world/HUD; only native hero lantern and its synchronized close-wall light are OFF.")
	var center: Vector2 = world.hero.get_global_transform_with_canvas().origin
	var exclude_hero := Rect2(center-Vector2(64,118),Vector2(128,128))
	var near_delta := 0.0
	var near_count := 0
	var far_delta := 0.0
	var far_count := 0
	var hud_max := 0.0
	for y in range(165,on.get_height()-48,3):
		for x in range(0,on.get_width(),3):
			var point := Vector2(x,y)
			if exclude_hero.has_point(point): continue
			var difference := luma(on.get_pixel(x,y))-luma(off.get_pixel(x,y))
			if point.distance_to(center)<220:
				near_delta += difference
				near_count += 1
			elif point.distance_to(center)>340:
				far_delta += absf(difference)
				far_count += 1
	for y in range(18,151,3):
		for x in range(24,325,3):
			var a: Color = on.get_pixel(x,y)
			var b: Color = off.get_pixel(x,y)
			hud_max = maxf(hud_max,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
	lighting_metrics = {"on":"res://previews/m21/16_lantern_on.jpg","off":"res://previews/m21/17_lantern_off.jpg","near_world_mean_luma_gain":near_delta/maxi(1,near_count),"far_world_mean_abs_luma_change":far_delta/maxi(1,far_count),"hud_max_channel_change":hud_max,"hero_pixels_excluded":true,"world_time_frozen":true,"actor_camera_frozen":true,"hero_light_layers":[world.hero.lantern_light.range_layer_min,world.hero.lantern_light.range_layer_max],"wall_light_layers":[world.visuals.wall_lantern_light.range_layer_min,world.visuals.wall_lantern_light.range_layer_max],"near_radius":220,"far_min_radius":340}
	if float(lighting_metrics.near_world_mean_luma_gain)<0.001: failures.append("Native lantern produces no measurable nearby world illumination")
	if hud_max>0.004: failures.append("Lantern toggle changes the frozen HUD")
	if world.hero.lantern_light.range_layer_min!=0 or world.hero.lantern_light.range_layer_max!=0: failures.append("Hero world light is not restricted to canvas layer0")
	if world.visuals.wall_lantern_light.range_layer_min!= -18 or world.visuals.wall_lantern_light.range_layer_max!= -18: failures.append("Close-wall light is not restricted to its separate layer")
	if float(lighting_metrics.far_world_mean_abs_luma_change)>maxf(0.001,float(lighting_metrics.near_world_mean_luma_gain)*0.2): failures.append("Lantern influence is not localized")
	print("M21 LIGHT PAIR ",JSON.stringify(lighting_metrics))
	world.hero.lantern_light.visible = true
	world.visuals.process_mode = Node.PROCESS_MODE_INHERIT
	world.process_mode = Node.PROCESS_MODE_INHERIT

func compare_original_hero_render() -> void:
	var viewports: Array[SubViewport] = []
	var rigs: Array[Node2D] = []
	for script in ["res://scripts/warden_model_m20.gd","res://scripts/warden_model_m21.gd"]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(512,512)
		viewport.transparent_bg = true
		viewport.disable_3d = true
		viewport.world_2d = World2D.new()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var rig: Node2D = load(script).new()
		rig.process_mode = Node.PROCESS_MODE_DISABLED
		viewport.add_child(rig)
		rig.set_motion("idle",0.25)
		rig.set_expression("idle",1.0)
		viewports.append(viewport)
		rigs.append(rig)
	await process_frame
	await RenderingServer.frame_post_draw
	var old: Image = viewports[0].get_texture().get_image()
	var eyes: Image = viewports[1].get_texture().get_image()
	var maximum := 0.0
	var outside_changed := 0
	var inside_changed := 0
	for y in range(512):
		for x in range(512):
			var mask := false
			for bounds in rigs[1].eye_bounds:
				if bounds.grow(3).has_point(Vector2(x,y)): mask = true
			var a: Color = old.get_pixel(x,y)
			var b: Color = eyes.get_pixel(x,y)
			var difference := maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),maxf(absf(a.b-b.b),absf(a.a-b.a))))
			if mask:
				if difference>0.004: inside_changed += 1
			else:
				maximum = maxf(maximum,difference)
				if difference>0.004: outside_changed += 1
	old.save_png("user://m21_neutral_m20.png")
	eyes.save_png("user://m21_neutral_eyes.png")
	hero_preservation = {"native_neutral_viewports":true,"pose":"idle.25 / idle expression","size":[512,512],"m20_atlas_sha256":FileAccess.get_sha256("res://assets/warden_m20/warden_parts.png"),"outside_eye_changed_pixels":outside_changed,"outside_eye_max_rgba_difference":maximum,"inside_eye_changed_pixels":inside_changed,"eye_mask_padding_source_px":3}
	if outside_changed>0: failures.append("Native M21 hero render differs from M20 outside the eye region")
	if inside_changed<10: failures.append("Native eye overlay is not visible in neutral comparison")
	for viewport in viewports: viewport.queue_free()
	await process_frame
	print("M21 HERO PRESERVATION ",JSON.stringify(hero_preservation))

func run_capture() -> void:
	remember_files()
	DirAccess.make_dir_recursive_absolute(M21_OUTPUT)
	if FileAccess.file_exists(M21_REPORT):
		var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(M21_REPORT))
		if previous is Dictionary:
			for item in previous.get("captures",[]):
				if item.path.get_file() in ["01_first_page.jpg","02_first_enemy.jpg","18_hero_eyes.jpg"]: captures.append(item)
	var packed: PackedScene = load(M21_WORLD_PATH)
	world = packed.instantiate()
	packed = null
	world.restore_saved_game = false
	world.environment_preview = true
	world.transition_seconds = 0.001
	root.add_child(world)
	await step(45)
	await frozen_lantern_pair()
	await compare_original_hero_render()
	var layouts: RefCounted = load("res://scripts/stage/m18_layouts.gd").new()
	for room_id in range(3,16):
		var definition: Dictionary = layouts.room(room_id)
		var at: Vector2 = definition.get("spawns",{}).get("left",Vector2(180,float(definition.floor_y)))
		var focus := "left spawn"
		for item in definition.get("objects",[]):
			if str(item.get("kind","")).ends_with("_control") or str(item.get("kind",""))=="dialogue":
				at = item.pos-Vector2(120,0)
				focus = str(item.id)
				break
		await fixture_room(room_id,at)
		for enemy in world.enemies:
			if is_instance_valid(enemy): enemy.process_mode = Node.PROCESS_MODE_DISABLED
		world.hero.hp = 6
		world.hero.invulnerable = 0
		world.hero.reset_combat_motion()
		world.camera.process_mode = Node.PROCESS_MODE_DISABLED
		world.camera.zoom = Vector2.ONE
		world.camera.position = world.camera.bounded(world.hero.position+Vector2(140,-230))
		world.camera.reset_smoothing()
		world.camera.force_update_scroll()
		await step(4)
		await capture("%02d_room_%02d"%[room_id,room_id],"Configured room tour near "+focus+"; real room art, foreground, native lamps and interaction context; not traversal proof.")
	await prepare_hero()
	world.camera.process_mode = Node.PROCESS_MODE_DISABLED
	world.camera.zoom = Vector2(2.4,2.4)
	world.camera.position = Vector2(1180,1210)
	world.camera.reset_smoothing()
	world.camera.force_update_scroll()
	await step(3)
	await capture("19_first_enemy_close","Configured2.4×native first-enemy art inspection; same inherited M18 contour scale and combat.")
	stop_audio(world)
	OS.delay_msec(120)
	await process_frame
	world.queue_free()
	world = null
	await process_frame
	await process_frame
	var restored := restore_files()
	if not restored: failures.append("Original user data was not restored")
	var report := {"engine":Engine.get_version_info().string,"rendered":true,"captures":captures,"lighting_pair":lighting_metrics,"hero_render_preservation":hero_preservation,"failures":failures,"save_restored":restored,"scope":"native configured15-room tour/closeups, frozen paired real lantern comparison and original M20-versus-eye neutral rendering; mechanics proof separately in test_m21_paper_shadows.gd"}
	FileAccess.open(M21_REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	OS.delay_msec(50)
	await process_frame
	quit(0 if failures.is_empty() else 1)

func capture(tag: String, note: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	if frame.is_empty():
		failures.append("Empty rendered viewport "+tag)
		return
	DirAccess.make_dir_recursive_absolute("user://m21_capture_sources")
	frame.save_png("user://m21_capture_sources/"+tag+".png")
	var path := M21_OUTPUT+"/"+tag+".jpg"
	if frame.save_jpg(path,0.92)!=OK: failures.append("Cannot write "+path)
	captures.append({"path":path,"room":world.current_room,"width":frame.get_width(),"height":frame.get_height(),"hero_pose":world.hero.current_pose,"airborne":not world.hero.is_on_floor(),"attack_elapsed":world.hero.attack_elapsed,"contact_active":world.hero.active_strike_time>0,"expression":world.hero.expression_kind,"configured_fixture":true,"camera_zoom":world.camera.zoom.x,"hero_supported":world.hero.is_on_floor(),"pixel_metrics":frame_metrics(frame),"note":note})
	print("M21 CAPTURE ",path)

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

func run_initial_capture() -> void:
	remember_files()
	DirAccess.make_dir_recursive_absolute(M21_OUTPUT)
	var packed: PackedScene = load(M21_WORLD_PATH)
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
	await fixture_room(1,Vector2(330,1260))
	world.hud.set_language("ar")
	await step(5)
	await capture("01_first_page","Configured native room01 start at actual gameplay scale; approved M20 art with native eyes, layered paper environment and localized light.")
	await prepare_hero()
	world.camera.process_mode = Node.PROCESS_MODE_DISABLED
	world.camera.zoom = Vector2.ONE
	world.camera.position = world.hero.position+Vector2(120,-230)
	world.camera.reset_smoothing()
	world.camera.force_update_scroll()
	await step(4)
	await capture("02_first_enemy","Configured room02 encounter composition at actual gameplay scale; clean original larva silhouette and native world light.")
	close_view()
	await step(3)
	await capture("18_hero_eyes","Configured3×close camera for original M20 hero art with only native eyes added inside the unchanged flame/head.")
	for action in ["attack","look_down","look_up","jump","heal","dash","move_left","move_right"]:
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
	var report := {"engine":Engine.get_version_info().string,"rendered":true,"captures":captures,"failures":failures,"save_restored":restored,"scope":"declared M21 native environmental/hero review fixtures; mechanics proof separately in test_m21_paper_shadows.gd"}
	FileAccess.open(M21_REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	OS.delay_msec(50)
	await process_frame
	quit(0 if failures.is_empty() else 1)
