extends SceneTree
## Native M28 media. Room starts and late-game equipment are explicit fixtures;
## subsequent locomotion, interactions, rendering, audio and UI use game code.
const WORLD_SCENE := "res://scenes/stage_01/folding_library_m28.tscn"
const OUTPUT := "res://previews/m28"
const CaptureManifest=preload("res://tools/m28_capture_manifest.gd")
var world: Node2D
var hero: CharacterBody2D
var ticks := 0
var shots: Array[Dictionary] = []
var evidence: Array[Dictionary] = []
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func step(count: int=1) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
		ticks+=1

func release() -> void:
	for action in ["move_left","move_right","jump","dash","attack","spell","heal","interact","look_up","look_down","pause_game","stage_map","journal"]:
		if InputMap.has_action(action): Input.action_release(action)

func physical_key(code: int) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await step(3)
	event=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=false
	Input.parse_input_event(event)
	await step(3)

func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.stop()
		node.stream=null
	for child in node.get_children(): stop_audio(child)

func source_hashes() -> Dictionary:
	var result: Dictionary={}
	for path in ["project.godot","scripts/stage/m28_folding_library.gd","scripts/stage/m28_layouts.gd","scripts/stage/m28_room_visuals.gd","scripts/stage/m28_surface_details.gd","scripts/stage/m28_foreground.gd","scripts/stage/m28_environment_director.gd","scripts/stage/m28_journey.gd","scripts/combat/m28_player.gd","scripts/ui/m28_hud.gd","scripts/shop/m28_shop.gd","scripts/minibosses/m28_archivist_journey.gd","assets/warden_m20/warden_parts.png","assets/environments/m28/margin_exchange.png"]:
		if FileAccess.file_exists("res://"+path): result[path]=FileAccess.get_sha256("res://"+path)
	for path in DirAccess.get_files_at("res://assets/audio/m28"):
		if path.ends_with(".wav"): result["assets/audio/m28/"+path]=FileAccess.get_sha256("res://assets/audio/m28/"+path)
	result["scripts/audio/m24_soundscape.gd"]=FileAccess.get_sha256("res://scripts/audio/m24_soundscape.gd")
	return CaptureManifest.hashes(result.keys())

func screenshot(tag: String, scope: String) -> void:
	await RenderingServer.frame_post_draw
	var frame: Image=root.get_texture().get_image()
	var path:=OUTPUT+"/"+tag+".jpg"
	if frame.save_jpg(path,.95)!=OK:
		failures.append("Cannot save native viewport: "+path)
		return
	var item: Dictionary={"path":path,"scope":scope,"native_godot_viewport":true,"configured_room_start":true,"hero_position":[hero.position.x,hero.position.y],"hero_hp":hero.hp,"room":world.current_room,"camera_position":[world.camera.position.x,world.camera.position.y],"physics_tick":ticks,"boss_active":world.boss_active,"sha256":FileAccess.get_sha256(path)}
	if world.has_method("get_m28_world_snapshot"): item.world=world.get_m28_world_snapshot()
	shots.append(item)
	print("M28 NATIVE IMAGE ",path)

func fixture_room(room_id: int, point: Vector2) -> bool:
	release()
	if world.hud.panel_open:
		await physical_key(KEY_ESCAPE)
		await step(30)
	world._load_room(room_id,"left",point)
	await step(75)
	if not is_instance_valid(world.visuals) or not is_instance_valid(world.surface_root):
		failures.append("Room renderer or geometry failed to instantiate: "+str(room_id))
		return false
	world.arrival_title.dismiss()
	await step(3)
	return true

func run_gallery() -> void:
	# Each image is the running game, with ordinary idle animation and lighting.
	# These deliberate supported starts do not claim a continuous playthrough.
	var cases: Array[Dictionary]=[
		{"room":1,"point":Vector2(760,1260),"tag":"01_bound_volume_threshold"},
		{"room":4,"point":Vector2(1980,1260),"tag":"02_margin_market"},
		{"room":9,"point":Vector2(2390,780),"tag":"03_torn_output_route","flags":{"output_open":true}},
		{"room":6,"point":Vector2(2630,1980),"tag":"04_archivist_vault_door"},
		{"room":10,"point":Vector2(2460,900),"tag":"05_counterweight_seals","flags":{"balance_bridge_locked":true}},
		{"room":12,"point":Vector2(900,1260),"tag":"06_bell_bindery_gate"},
		{"room":13,"point":Vector2(2050,1260),"tag":"07_final_spine_challenge"}
	]
	for sample in cases:
		if "--early" in OS.get_cmdline_user_args() and int(sample.room) not in [4,6]: continue
		for key in sample.get("flags",{}): world.progress[key]=sample.flags[key]
		if not await fixture_room(int(sample.room),sample.point): continue
		await screenshot(str(sample.tag),"Configured supported room start; live original hero, world geometry, lighting and decoration. Not a continuous world traversal.")

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Native M28 capture requires a display")
		quit(1)
		return
	root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var packed: PackedScene=load(WORLD_SCENE)
	if packed==null:
		push_error("M28 world does not load")
		quit(1)
		return
	world=packed.instantiate()
	if world.get_script()==null or not world.has_method("_load_room"):
		push_error("M28 world controller has not compiled")
		world.free()
		quit(1)
		return
	world.restore_saved_game=false
	root.add_child(world)
	current_scene=world
	await step(45)
	hero=world.hero
	if not is_instance_valid(world.visuals) or not is_instance_valid(world.surface_root):
		push_error("M28 initial world rendering or geometry failed")
		quit(1)
		return
	# Late-route visual fixtures use legitimately supported equipment flags.
	# They do not award story receipts or pretend that a boss was defeated.
	world.progress.weapon_owned=true
	world.combat_state.dash_owned=true
	world.combat_state.spell_owned=true
	hero.has_blade=true
	hero.has_dash=true
	hero.has_code_slash=true
	var hashes_before:=source_hashes()
	await run_gallery()
	release()
	var metadata: Dictionary={"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"viewport":[1280,720],"scope":"Native running M28 world views. Deliberate room spawns and supported late-route equipment are configured fixtures; not an unbroken exploration playthrough or proof of boss victories.","shots":shots,"evidence":evidence,"source_sha256":hashes_before,"sources_unchanged_during_capture":hashes_before==source_hashes(),"failures":failures}
	FileAccess.open(OUTPUT+"/world_capture_metadata.json",FileAccess.WRITE).store_string(JSON.stringify(metadata,"\t"))
	world.gameplay_active=false
	stop_audio(world)
	OS.delay_msec(180)
	current_scene=null
	world.queue_free()
	await step(4)
	quit(0 if failures.is_empty() else 1)
