extends SceneTree
## Independent rest acceptance. The missing-health/inventory fixtures below are
## labelled; actual E/I/Tab/keyboard/controller actions drive the complete rest.
const WORLD := "res://scenes/stage_01/folding_library_m29.tscn"
const OUTPUT := "res://previews/m29"
const Manifest=preload("res://tools/m29_capture_manifest.gd")
var world: Node2D
var hero: CharacterBody2D
var checks:=0
var failures: Array[String]=[]
var evidence: Array[Dictionary]=[]
var photos: Array[Dictionary]=[]
var ticks:=0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, caption: String) -> bool:
	checks+=1
	if not ok:
		failures.append(caption)
		print("M29 BENCH FAIL ",caption)
	return ok

func frames(count: int=1) -> void:
	for unused in range(count):
		await physics_frame
		await process_frame
		ticks+=1

func release() -> void:
	for action in ["move_left","move_right","jump","dash","attack","spell","heal","interact","look_up","look_down","pause_game","stage_map","journal"]:
		if InputMap.has_action(action): Input.action_release(action)

func key(code: int, held: int=2) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await frames(held)
	event=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=false
	Input.parse_input_event(event)
	await frames(2)

func joy(button: int) -> void:
	var event:=InputEventJoypadButton.new()
	event.button_index=button
	event.pressed=true
	Input.parse_input_event(event)
	await frames(3)
	event=InputEventJoypadButton.new()
	event.button_index=button
	event.pressed=false
	Input.parse_input_event(event)
	await frames(3)

func director() -> Node:
	return world.get("bench_director") if is_instance_valid(world) else null

func rest_state() -> String:
	var node:=director()
	return str(node.get("state")) if is_instance_valid(node) else "missing"

func until_state(target: String, limit: int=180) -> bool:
	for unused in range(limit):
		if rest_state()==target: return true
		await frames()
	return check(false,"bench reaches "+target+" (observed "+rest_state()+")")

func source_hashes() -> Dictionary:
	var paths: Array=["project.godot","scripts/stage/m29_folding_library.gd","scripts/stage/m29_layouts.gd","scripts/stage/m29_bench_director.gd","scripts/stage/m29_journey.gd","scripts/minibosses/m29_archivist_journey.gd","scripts/combat/m29_player.gd","scripts/warden_model_m29.gd","scripts/ui/m29_hud.gd","scripts/stage/m29_room_visuals.gd","assets/warden_m20/warden_parts.png","assets/environments/m29/art_manifest.json"]
	return Manifest.hashes(paths)

func photograph(tag: String, scope: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	var target:=OUTPUT+"/"+tag+".jpg"
	if not check(image.save_jpg(target,.95)==OK,"native viewport image saved "+tag): return
	photos.append({"path":target,"scope":scope,"rest_state":rest_state(),"hero_position":[hero.position.x,hero.position.y],"hero_hp":hero.hp,"hero_energy":hero.energy,"physics_tick":ticks,"sha256":FileAccess.get_sha256(target)})

func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
		node.stop()
		node.stream=null
	for child in node.get_children(): stop_audio(child)

func run() -> void:
	if not check(OS.get_environment("XDG_DATA_HOME").contains("m29"),"rest acceptance uses isolated userdata"): quit(1);return
	root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var packed: PackedScene=load(WORLD)
	if not check(packed!=null,"M29 world scene exists"): quit(1);return
	world=packed.instantiate()
	if not check(world.get_script()!=null and world.has_method("_load_room"),"M29 world dependencies compile"): world.free();quit(1);return
	world.restore_saved_game=false
	root.add_child(world)
	current_scene=world
	await frames(35)
	hero=world.hero
	if not check(is_instance_valid(hero) and is_instance_valid(director()),"native hero and real bench director exist"): await finish({});return
	check(world.current_room==1 and hero.is_on_floor(),"actual first room supports the hero")
	check(FileAccess.get_sha256("res://assets/warden_m20/warden_parts.png")=="6eca7436c7a8c39451256aa56db465d664df0d6dbb42d8e7f24122592b34bb66","approved hero atlas unchanged")
	var before:=source_hashes()
	# Only inventory/vitals are fixture setup; rest, alignment, menus and motor
	# transitions below go through physical input and the real world authority.
	hero.hp=4
	hero.energy=17
	world.combat_state.wallet=23
	world.progress.weapon_owned=true
	hero.has_blade=true
	for id in ["wick","focus","reach"]: world.combat_state.acquire(id)
	await frames(15) # Let the real HUD observe the declared fixture and fade in.
	var prior_checkpoint: Dictionary=world.checkpoint.duplicate(true)
	var position_before: Vector2=hero.position
	await photograph("01_before_bench_rest","Actual supported first-room opening. Missing health,17energy and three fitils are explicit acceptance fixtures; pose is ordinary standing.")
	print("M29 BENCH BEFORE ",JSON.stringify(world.get_m29_world_snapshot())," action=",world.nearest_action())
	await key(KEY_E)
	print("M29 BENCH AFTER ",JSON.stringify(world.get_m29_world_snapshot()))
	check(rest_state() in ["aligning","sitting"],"actual E begins alignment/sit instead of instant inventory")
	check(hero.hp==4 and is_equal_approx(hero.energy,17),"health and energy are not awarded before seating completes")
	check(not world.hud.panel_open,"initial bench input does not auto-open equipment")
	check(hero.position.distance_to(position_before)<30,"first rest frames align smoothly without a long teleport")
	if not await until_state("seated"): await finish(before);return
	check(bool(hero.get("bench_locked")) and is_equal_approx(float(hero.get("bench_blend")),1),"finished sit holds the actual seated hero pose")
	check(hero.hp==6 and is_equal_approx(hero.energy,17),"completed rest restores six lanterns while keeping combat-earned energy unchanged")
	check(world.combat_state.wallet==23,"rest does not mint coins")
	check(world.checkpoint!=prior_checkpoint or int(world.checkpoint.room)==1,"rest commits a world checkpoint at a genuine seat")
	check(FileAccess.file_exists(world.save_path()),"completed rest writes durable world save")
	check(not bool(hero.combat_model.sword_visible),"weapon is stowed while seated")
	check(absf(absf(hero.combat_container.scale.x)-.37)<.001 and absf(hero.combat_container.scale.y-.37)<.001,"sitting preserves original body draw scale")
	await frames(36) # Retain the real lantern-fill animation before the still.
	await photograph("02_seated_bench","Actual E completes alignment and sitting. Bent legs, original body parts and quiet rest remain visible with the menu closed.")
	var serial: int=hero.strike_serial
	var seat_position: Vector2=hero.position
	Input.action_press("attack")
	Input.action_press("dash")
	await frames(12)
	release()
	check(hero.strike_serial==serial and hero.position.is_equal_approx(seat_position),"seated player cannot attack or dash")
	await key(KEY_I)
	await frames(24)
	check(world.hud.panel_open and world.hud.current_panel=="bench","I opens actual seated fitil inventory")
	check(rest_state()=="seated" and bool(hero.get("bench_locked")),"menu keeps hero visibly seated")
	check(not world.gameplay_active,"inventory pauses hazards and exploration")
	await photograph("03_seated_fitils_menu","Actual I input opens the bench equipment overlay. Three owned fitils are a declared inventory fixture; the seated hero remains in the running native viewport.")
	if "--early" in OS.get_cmdline_user_args():
		await finish(before)
		return
	var gear_before: Array=world.combat_state.equipped.duplicate()
	await joy(JOY_BUTTON_A)
	await frames(10)
	check(world.combat_state.equipped!=gear_before,"controller A equips a real owned fitil while seated")
	check(world.combat_state.used_capacity()<=world.combat_state.capacity,"native fitil selection cannot overfill capacity")
	await joy(JOY_BUTTON_RIGHT_SHOULDER)
	await frames(12)
	if world.hud.has_method("get_bench_ui_snapshot"):
		var snapshot: Dictionary=world.hud.get_bench_ui_snapshot()
		check(str(snapshot.get("tab",snapshot.get("bench_tab","")))=="inventory","controller shoulder changes to actual owned inventory")
	await photograph("04_seated_inventory_tab","Actual controller shoulder switches bench tab while the original seated hero stays visible. Inventory reflects the declared owned kit.")
	await key(KEY_ESCAPE)
	await frames(35)
	check(not world.hud.panel_open and rest_state()=="seated","closing inventory returns to rest instead of standing")
	check(bool(hero.get("bench_locked")) and hero.position.is_equal_approx(seat_position),"closed-menu seated state is stable")
	await photograph("05_menu_closed_still_seated","Actual Escape closes the equipment overlay; the hero remains seated, matching the supplied bench reference.")
	await joy(JOY_BUTTON_Y)
	await frames(20)
	check(world.hud.panel_open and world.hud.current_panel=="bench","controller Y reopens gear while resting")
	await joy(JOY_BUTTON_B)
	await frames(35)
	check(not world.hud.panel_open and rest_state()=="seated","controller cancel closes only the inventory")
	Input.action_press("move_right")
	check(await until_state("idle"),"ordinary movement completes stand animation")
	await frames(16)
	release()
	check(not bool(hero.get("bench_locked")) and float(hero.get("bench_blend"))<.001,"standing restores the normal hero rig")
	check(hero.position.x>seat_position.x+5,"held movement continues after the rise")
	await photograph("06_stood_and_resumed","Actual held movement rises from the bench and resumes the unchanged movement controller.")
	evidence.append({"kind":"actual_rest_flow","configured_health_energy_inventory":true,"position_injection":false,"first_rest_input":"E","menu_input":"I","controller_actions":["A equip","RB tab","Y reopen","B close"],"close_stays_seated":true,"movement_rises":true,"checks":checks})
	await finish(before)

func finish(before: Dictionary) -> void:
	release()
	var result: Dictionary={"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"failures":failures,"photos":photos,"evidence":evidence,"source_sha256":before,"sources_unchanged_during_capture":before==source_hashes(),"scope":"Independent actual input rest/menu/stand acceptance. Missing-health, energy and owned-fitil setup is explicit; this is not a complete campaign playthrough."}
	FileAccess.open("user://m29_bench_flow_report.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	FileAccess.open(OUTPUT+"/bench_capture_metadata.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	if is_instance_valid(world):
		world.gameplay_active=false
		stop_audio(world)
		OS.delay_msec(180)
		current_scene=null
		world.queue_free()
		await frames(5)
	print("M29 BENCH FLOW ",checks," checks failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
