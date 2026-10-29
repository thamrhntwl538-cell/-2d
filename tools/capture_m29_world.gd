extends "res://tools/test_m29_portal_flow.gd"
## Short native MovieWriter sequences. Each begins at a declared exterior
## fixture; there are no mid-recording teleports, clock scrubs or boss damage.
var bell_mode:=false

func run() -> void:
	if DisplayServer.get_name()=="headless": push_error("M29 native movies require a display");quit(1);return
	if not OS.get_environment("XDG_DATA_HOME").contains("m29"): quit(1);return
	root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	bell_mode="--bell" in OS.get_cmdline_user_args()
	var packed: PackedScene=load(WORLD)
	world=packed.instantiate()
	world.restore_saved_game=false
	world.checkpoint={"room":12 if bell_mode else 4,"position":[900.0,1260.0] if bell_mode else [1960.0,1260.0]}
	root.add_child(world)
	current_scene=world
	hero=world.hero
	# The initial state is explicit. All actions after this setup use physical
	# controls and the unmodified world/room/actor implementation.
	hero.energy=0
	world.combat_state.wallet=41 if not bell_mode else 0
	if bell_mode:
		world.progress.weapon_owned=true
		hero.has_blade=true
		world.combat_state.dash_owned=true
		hero.has_dash=true
	else:
		for id in ["wick","focus","reach"]: world.combat_state.acquire(id)
	world._update_hud()
	var before:=source_hashes()
	await frames(55)
	check(hero.is_on_floor() and world.interior_kind.is_empty(),"movie starts at its declared supported exterior")
	if bell_mode: await bell_sequence()
	else: await market_sequence()
	await finish(before)

func market_sequence() -> void:
	await photograph("30_actual_market_approach","Declared initial room4 outside/41coins/threefitils fixture. All subsequent entry, rest, UI, purchase and return use ordinary inputs.")
	await key(KEY_UP)
	if not await until_interior("market"): return
	check(hero.energy==0 and world.combat_state.wallet==41,"actual threshold grants no energy or coins")
	if not await walk_to(500): return
	await key(KEY_E)
	if not await until_state("seated"): return
	await frames(36)
	check(hero.hp==6 and hero.energy==0,"actual bench rests without filling combat energy")
	await key(KEY_I)
	await frames(25)
	check(world.hud.current_panel=="bench" and rest_state()=="seated","actual inventory opens over genuine seated pose")
	await joy(JOY_BUTTON_A)
	await frames(12)
	check(world.combat_state.equipped.has("wick"),"controller A equips the real declared owned Kindling fitil")
	await joy(JOY_BUTTON_RIGHT_SHOULDER)
	await frames(24)
	await photograph("31_actual_inside_seated_inventory","Actual market entry, bench rest and controller inventory tab. Three fitils and41coins were declared at initial setup; no ability is added during this sequence.")
	await key(KEY_ESCAPE)
	await frames(60)
	check(rest_state()=="seated" and not world.hud.panel_open,"closed inventory leaves an uninterrupted full second of actual rest")
	await photograph("32_actual_menu_closed_rest","Actual Escape closes the gear sheet; the hero remains seated for a full second before the next movement input.")
	Input.action_press("move_right")
	await until_state("idle")
	await frames(8)
	release()
	if not await walk_to(930): return
	await key(KEY_E)
	await frames(24)
	check(world.hud.current_panel=="shop","actual interior counter opens the real market")
	await joy(JOY_BUTTON_A)
	await frames(12)
	check(Shop.owns(world.progress,world.combat_state,"atlas") and world.combat_state.wallet==17,"real purchase deducts exactly24 from declared initial41coins")
	await key(KEY_ESCAPE)
	await frames(25)
	if not await walk_to(150): return
	await frames(25)
	await key(KEY_UP)
	if not await until_interior(""): return
	await frames(25)
	check(world.current_room==4 and hero.is_on_floor() and world.combat_state.wallet==17,"actual return keeps purchased kit and remaining coins")
	await photograph("33_actual_market_return","Ordinary inputs return from the market to the original outside building, carrying the real purchase and17remainingcoins.")

func bell_sequence() -> void:
	await photograph("34_actual_bindery_approach","Declared outside room12 start with the required blade and dash. No health, boss damage or encounter timer is changed.")
	await key(KEY_E)
	if not await until_interior("bell"): return
	check(is_instance_valid(world.registered_boss) and not world.boss_active,"actual building E reaches the dormant original Bell inside")
	if not await walk_to(1170): return
	await frames(65)
	check(world.boss_active and world.boss_arena.locked,"actual approach starts the original boss and closes real gates")
	await photograph("35_actual_bindery_encounter","Actual doorway entry and ordinary walking begin the native Bell fight, its original camera/music and actual closed gates. This is not a boss victory.")
	await frames(35)

func finish(before: Dictionary) -> void:
	release()
	var mode: String="bell" if bell_mode else "market"
	var result: Dictionary={"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"failures":failures,"photos":photos,"source_sha256":before,"sources_unchanged_during_capture":before==source_hashes(),"physics_ticks":ticks,"movie_fps":60,"scope":"Declared exterior room12/blade/dash start followed by actual E, walking and original encounter activation. No boss damage, positive health or victory is injected." if bell_mode else "Declared exterior room4/41coin/threeownedfitil start followed by actual Up/E movement, rest, controller gear selection, shop purchase and real return. No mid-recording position/health/energy injection.","initial_fixture":true,"mid_recording_teleports":false,"audio_scope":"Original Godot runtime mixer recorded by MovieWriter; no replacement audio."}
	FileAccess.open(OUTPUT+"/"+mode+"_movie_metadata.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	if is_instance_valid(world):
		world.gameplay_active=false
		stop_audio(world)
		OS.delay_msec(180)
		current_scene=null
		world.queue_free()
		await frames(5)
	print("M29 MOVIE ",mode," ",checks," checks failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
