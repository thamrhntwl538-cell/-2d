extends "res://tools/test_m28_routes.gd"
## Native MovieWriter evidence. Fresh mode starts the actual opening; --gap
## labels a later-room/puzzle/equipment fixture, then uses ordinary input only.
const OUTPUT := "res://previews/m28"
const CaptureManifest=preload("res://tools/m28_capture_manifest.gd")
var photos: Array[Dictionary]=[]
var prior_files: Dictionary={}
var gap_mode:=false

func hash_sources() -> Dictionary:
	var hashes: Dictionary={}
	for path in ["project.godot","scripts/stage/m28_folding_library.gd","scripts/stage/m28_layouts.gd","scripts/stage/m28_room_visuals.gd","scripts/stage/m28_surface_details.gd","scripts/stage/m28_foreground.gd","scripts/stage/m28_environment_director.gd","scripts/stage/m28_journey.gd","scripts/combat/m28_player.gd","scripts/combat/m18_player.gd","scripts/minibosses/m26_archivist_trial.gd","scripts/minibosses/m28_archivist_journey.gd","scripts/audio/m24_soundscape.gd","assets/warden_m20/warden_parts.png"]:
		hashes[path]=FileAccess.get_sha256("res://"+path)
	for name in DirAccess.get_files_at("res://assets/audio/m28"):
		if name.ends_with(".wav"): hashes["assets/audio/m28/"+name]=FileAccess.get_sha256("res://assets/audio/m28/"+name)
	return CaptureManifest.hashes(hashes.keys())

func photo(tag: String, scope: String) -> void:
	await RenderingServer.frame_post_draw
	var frame: Image=root.get_texture().get_image()
	var path:=OUTPUT+"/"+tag+".jpg"
	if frame.save_jpg(path,.95)!=OK:
		failures.append("Native viewport could not save "+path)
		return
	photos.append({"path":path,"scope":scope,"room":world.current_room,"hero_position":[hero.position.x,hero.position.y],"hero_hp":hero.hp,"hero_energy":hero.energy,"tick":ticks,"sha256":FileAccess.get_sha256(path)})

func sample(kind: String, data: Dictionary) -> void:
	super.sample(kind,data)
	if kind=="native_jump":
		print("M28 MOVIE JUMP ",JSON.stringify(data))

func fresh_segment() -> void:
	stage="actual fresh first-room movement"
	if not check(not hero.has_blade and not hero.has_dash,"movie begins with true opening equipment"): return
	await step(20)
	if not await walk(Vector2(330,1260)): return
	if not await interact("bench_1"): return
	if not await walk(Vector2(445,1260)): return
	if not await interact("first_wick"): return
	if not await walk(Vector2(650,1260)): return
	if not await interact("weapon_pickup"): return
	if not await walk(Vector2(795,1260)): return
	if not await jump(Vector2(885,1178)): return
	await photo("30_actual_bound_volume_landing","Fresh world, no equipment or position injection. Actual movement and held jump onto new solid book threshold.")
	if not await drop(Vector2(978,1260)): return
	if not await jump(Vector2(1080,1140)): return
	if not await walk(Vector2(1180,1140)): return
	if not await interact("entrance_note"): return
	if not await drop(Vector2(1430,1260)): return
	if not await walk(Vector2(1500,1260)): return
	if not await interact("lantern_dash"): return
	check(hero.has_blade and world.combat_state.dash_owned,"movie acquires permanent blade and dash through original physical pickups")
	await pulse("dash")
	await step(45)
	await photo("31_actual_learned_dash","Fresh world. Actual original dash pickup and dash input, unchanged approved hero art.")
	sample("actual_fresh_opening",{"room":world.current_room,"hero_hp":hero.hp,"blade_owned":hero.has_blade,"dash_owned":world.combat_state.dash_owned,"actual_input":true,"initial_state_fixture":false})

func gap_segment() -> void:
	stage="configured late-room start, actual gap traversal"
	world.progress.weapon_owned=true
	world.progress.output_open=true
	world.combat_state.dash_owned=true
	world._load_room(9,"left",Vector2(2350,780))
	await step(60)
	world.arrival_title.dismiss()
	check(hero.is_on_floor() and absf(hero.position.y-780)<3,"labelled late-route movie start is physically supported")
	if not await walk(Vector2(2415,780)): return
	if not await jump(Vector2(2830,780),true): return
	await photo("32_actual_gap_landing","Configured room9/output-unlocked/dash-owned start only; actual held jump and air dash cross the real300px gap with original HP and geometry.")
	if not await walk(Vector2(2910,780)): return
	await step(45)
	check(bool(world.progress.get("m28_output_span_open",false)),"actual planted feet on the far seal open the return bridge")
	check(world.surface_root.get_node_or_null("m28_output_return_bridge")!=null,"return bridge has real collision after actual foot contact")
	await photo("33_actual_return_bridge_unfolded","Configured later-room start; actual movement reaches physical floor seal and game code creates its persistent return bridge.")
	await step(45)
	sample("actual_gap_and_latch",{"room":world.current_room,"hp":hero.hp,"return_bridge_open":world.progress.get("m28_output_span_open",false),"initial_state_fixture":true,"actual_input":true})

func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.stop()
		node.stream=null
	for child in node.get_children(): stop_audio(child)

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Native MovieWriter capture requires a display")
		quit(1)
		return
	root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	DirAccess.make_dir_recursive_absolute("user://")
	for path in ["user://folding_library_m28.json","user://archivist_journey_m28.json"]:
		prior_files[path]=FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	gap_mode="--gap" in OS.get_cmdline_user_args()
	var packed: PackedScene=load(WORLD)
	world=packed.instantiate()
	world.restore_saved_game=false
	root.add_child(world)
	current_scene=world
	await step(45)
	hero=world.hero
	var before:=hash_sources()
	if gap_mode: await gap_segment()
	else: await fresh_segment()
	var mode: String="gap" if gap_mode else "fresh"
	var record: Dictionary={"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"viewport":[1280,720],"movie_fps":60,"mode":mode,"checks":checks,"failures":failures,"physics_ticks":ticks,"scope":"Configured room9/output-unlocked/dash-owned opening, then actual held jump, air dash and foot-operated bridge. No heroHP edits or enemyAI changes." if gap_mode else "Actual fresh room1 start, ordinary physical blade/dash pickups, movement and jumps. No position/equipment/HP/coin injection. Existing reader closes through its ordinary UI action signal.","samples":samples,"photos":photos,"source_sha256":before,"sources_unchanged_during_capture":before==hash_sources(),"audio_scope":"Godot's original runtime mixer through MovieWriter; no replacement audio or post-recording game effects."}
	FileAccess.open(OUTPUT+"/"+mode+"_movement_capture_metadata.json",FileAccess.WRITE).store_string(JSON.stringify(record,"\t"))
	release_all()
	world.gameplay_active=false
	stop_audio(world)
	OS.delay_msec(180)
	current_scene=null
	world.queue_free()
	await step(5)
	for path in prior_files:
		if prior_files[path]==null:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else: FileAccess.open(path,FileAccess.WRITE).store_buffer(prior_files[path])
	print("M28 MOVIE REPORT ",mode," checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
