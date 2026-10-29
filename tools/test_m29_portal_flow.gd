extends "res://tools/test_m29_bench_flow.gd"
## Independent actual door acceptance. Room starts and owned kit below are
## configured fixtures; approach, Up/E, fades, rest, purchase and return are real.
const Shop=preload("res://scripts/shop/m28_shop.gd")

func walk_to(x: float, limit: int=500) -> bool:
	for unused in range(limit):
		Input.action_release("move_left")
		Input.action_release("move_right")
		var difference: float=x-hero.position.x
		var braking: float=hero.velocity.x*hero.velocity.x/(2.0*2650.0)
		if absf(difference)<5 and absf(hero.velocity.x)<3:
			return true
		if absf(difference)>maxf(4,braking+3): Input.action_press("move_right" if difference>0 else "move_left")
		await frames()
	release()
	return check(false,"actual walk reaches "+str(x)+" from "+str(hero.position))

func until_interior(kind: String, limit: int=240) -> bool:
	for unused in range(limit):
		if str(world.get("interior_kind"))==kind and not world.transitioning: return true
		await frames()
	return check(false,"door transition reaches interior "+kind)

func fixture_room(id: int, point: Vector2) -> void:
	release()
	world._load_room(id,"left",point)
	await frames(35)
	if is_instance_valid(world.arrival_title): world.arrival_title.dismiss()
	check(hero.is_on_floor() and hero.hp>0,"configured outside landing is physically supported")

func door_exit() -> void:
	release()
	await frames(30)
	await key(KEY_E)
	await until_interior("")

func run() -> void:
	if not check(OS.get_environment("XDG_DATA_HOME").contains("m29"),"portal acceptance uses isolated userdata"): quit(1);return
	root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var packed: PackedScene=load(WORLD)
	if not check(packed!=null,"M29 integrated world loads"): quit(1);return
	world=packed.instantiate()
	world.restore_saved_game=false
	root.add_child(world)
	current_scene=world
	await frames(45)
	hero=world.hero
	if not check(is_instance_valid(hero) and world.has_method("get_m29_world_snapshot"),"actual M29 controller and hero are ready"): await finish({});return
	var before:=source_hashes()
	# These starts isolate entrances from the long world traversal. They never
	# claim that the required earlier rooms or boss encounters were completed.
	world.progress.weapon_owned=true
	hero.has_blade=true
	world.combat_state.dash_owned=true
	hero.has_dash=true
	world.combat_state.wallet=41
	hero.hp=4
	hero.energy=27
	await fixture_room(4,Vector2(1960,1260))
	var initial_checkpoint: Dictionary=world.checkpoint.duplicate(true)
	var initial_kit: Dictionary=world.combat_state.serialize()
	await photograph("10_market_building_outside","Configured supported room4 approach with declared blade/dash and vitals fixture. The complete building surrounds the real market entrance.")
	Input.action_press("look_up")
	if not await until_interior("market"): await finish(before);return
	check(world.current_room==4 and hero.is_on_floor(),"actual Up enters a different supported market room")
	check(hero.hp==4 and is_equal_approx(hero.energy,27),"door entry does not heal or recharge")
	check(world.combat_state.serialize()==initial_kit,"same real inventory and wallet cross the building threshold")
	check(world.data.get("m29_interior","")=="market" and world.data.size==Vector2(1280,720),"market interior is an authored close room")
	check(not world.hud.panel_open,"entering a building does not auto-open a shop menu")
	check(world.checkpoint==initial_checkpoint,"door entry does not replace last resting checkpoint")
	if DisplayServer.get_name()!="headless": await frames(190) # Let the actual location title finish naturally.
	await photograph("11_market_inside","Actual Up crosses the exterior threshold and completes the fade into the market interior. No health, energy or kit is granted by entry.")
	if "--early" in OS.get_cmdline_user_args():
		await finish(before)
		return
	if not await walk_to(150): await finish(before);return
	await frames(35)
	check(str(world.interior_kind)=="market","held Up cannot immediately bounce back through the nearby return door")
	await key(KEY_E)
	check(str(world.interior_kind)=="market","opposite door cannot activate before the held entry direction is released")
	Input.action_release("look_up")
	await frames(4)
	await key(KEY_E)
	if not await until_interior(""): await finish(before);return
	check(world.current_room==4 and absf(hero.position.x-1960)<5 and hero.is_on_floor(),"physical return reaches the correct outside building landing")
	check(hero.hp==4 and is_equal_approx(hero.energy,27) and world.combat_state.wallet==41,"return preserves the actual spent vitals and currency")
	# Re-enter and genuinely rest inside. The new checkpoint must carry its
	# interior namespace, otherwise restore/death would strand the player.
	await frames(30)
	await key(KEY_E)
	if not await until_interior("market"): await finish(before);return
	if not await walk_to(500): await finish(before);return
	await key(KEY_E)
	if not await until_state("seated"): await finish(before);return
	check(str(world.checkpoint.get("interior",""))=="market","inside rest records the actual interior checkpoint")
	check(hero.hp==6 and is_equal_approx(hero.energy,27),"completed interior rest restores health without minting combat energy")
	check(world.combat_state.wallet==41,"interior rest does not issue currency")
	await photograph("12_market_inside_rest","Actual movement reaches the real market bench and completes E rest. Its checkpoint records the interior and outside return anchor.")
	await frames(6) # Release/settle before a fresh stand intent, as in the UI flow.
	Input.action_press("move_right")
	await until_state("idle")
	await frames(10)
	release()
	if not await walk_to(930): await finish(before);return
	await key(KEY_E)
	await frames(25)
	check(world.hud.panel_open and world.hud.current_panel=="shop","actual interior counter opens the existing real market")
	await joy(JOY_BUTTON_A)
	await frames(10)
	check(Shop.owns(world.progress,world.combat_state,"atlas") and world.combat_state.wallet==17,"actual controller purchase uses the same cross-room wallet")
	await photograph("13_market_inside_shop","Actual E counter interaction and controller A purchase buy the Atlas from the declared41-coin fixture. The wallet is deducted by24.")
	await key(KEY_ESCAPE)
	await frames(30)
	check(not world.hud.panel_open and rest_state()=="idle","closing shop resumes normal interior movement")
	var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(saved is Dictionary and str(saved.get("checkpoint",{}).get("interior",""))=="market","world save preserves inside bench context")
	check(int(saved.get("combat",{}).get("wallet",-1))==17,"purchase and persistent interior checkpoint save together")
	# A deliberate save/reopen fixture exercises real restore without invoking
	# a debug travel command as positive transition evidence.
	stop_audio(world)
	OS.delay_msec(180)
	current_scene=null
	world.queue_free()
	await frames(5)
	world=packed.instantiate()
	root.add_child(world)
	current_scene=world
	await frames(35)
	hero=world.hero
	check(str(world.interior_kind)=="market" and hero.is_on_floor(),"native reload restores the inside bench on real collision")
	check(world.combat_state.wallet==17 and Shop.owns(world.progress,world.combat_state,"atlas"),"inside restore retains actual purchases and remaining coins")
	var gear_before: Array=world.combat_state.equipped.duplicate()
	world.combat_state.acquire("focus")
	world._on_ui_action("equip_fitil","focus")
	check(world.combat_state.equipped==gear_before,"standing near an inside bench cannot forge seated equip permission")
	if not await walk_to(150): await finish(before);return
	await door_exit()
	check(str(world.interior_kind).is_empty(),"restored interior keeps a working physical return door")
	await fixture_room(12,Vector2(900,1260))
	check(not world.boss_active and not is_instance_valid(world.registered_boss),"outside bindery has a building but no corridor boss")
	await photograph("14_bell_building_outside","Configured supported room12 outside approach. The complete bindery building is separate from its actual boss chamber.")
	await key(KEY_E)
	if not await until_interior("bell"): await finish(before);return
	check(is_instance_valid(world.registered_boss) and not world.boss_active,"actual E reaches the dormant original Bell encounter inside")
	check(world.combat_state.wallet==17 and Shop.owns(world.progress,world.combat_state,"atlas"),"boss doorway carries the same permanent inventory")
	await photograph("15_bell_chamber_inside","Actual exterior E transition enters the separate bindery interior with the unchanged dormant Bell Warden.")
	if not await walk_to(360): await finish(before);return
	await door_exit()
	check(world.current_room==12 and str(world.interior_kind).is_empty() and absf(hero.position.x-900)<5,"real bindery return lands at its own outside doorway")
	check(not bool(world.progress.get("miniboss_bell_defeated",false)) and not bool(world.progress.get("miniboss_archivist_defeated",false)),"door and rest inspections never fabricate boss wins")
	await frames(30)
	await key(KEY_E)
	if not await until_interior("bell"): await finish(before);return
	if not await walk_to(1170): await finish(before);return
	await frames(45)
	check(world.boss_active and world.boss_arena.locked,"ordinary walking into the real bindery starts and locks the actual Bell encounter")
	check(world.registered_boss.alive and not world.registered_boss.is_dead,"Bell combat starts with the original living actor")
	await photograph("16_bell_encounter_inside","Actual E building entry followed by ordinary walking starts the real Bell encounter and camera framing. No boss damage or victory is injected.")
	evidence.append({"kind":"actual_building_flow","configured_outside_room_starts":true,"owned_kit_and_vitals_fixture":true,"entry_inputs":["Up","E"],"actual_interior_rest":true,"actual_market_purchase":true,"save_restore_fixture":true,"victory_claim":false})
	await finish(before)

func finish(before: Dictionary) -> void:
	release()
	var result: Dictionary={"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"failures":failures,"photos":photos,"evidence":evidence,"source_sha256":before,"sources_unchanged_during_capture":before==source_hashes(),"scope":"Independent actual door/interior/rest/shop/return inputs from explicit supported outside room and inventory/vitals fixtures; reload is a labelled storage fixture. No continuous campaign or boss victory is claimed."}
	FileAccess.open("user://m29_portal_flow_report.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	FileAccess.open(OUTPUT+"/portal_capture_metadata.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	if is_instance_valid(world):
		world.gameplay_active=false
		stop_audio(world)
		OS.delay_msec(180)
		current_scene=null
		world.queue_free()
		await frames(5)
	print("M29 PORTAL FLOW ",checks," checks failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
