extends "res://tools/test_m21_paper_shadows.gd"
## The only configured start is room05's normal entrance. Every shelf ascent,
## observation, retry and completion below uses normal Input actions. A later
## configured revisit isolates the already-solved reward guard after reload.
## Run with a native display, e.g. DISPLAY=:94 godot --audio-driver Dummy
## --fixed-fps 60 --path . --script res://tools/test_m22_lantern_route.gd
const LANTERN_WORLD := "res://scenes/stage_01/folding_library_m22.tscn"
const LANTERN_REPORT := "user://m22_lantern_route_report.json"
const M22Puzzle = preload("res://scripts/stage/m22_puzzle_state.gd")
const CoinLedger = preload("res://scripts/combat/m22_currency_ledger.gd")
var captures: Array[String] = []
var continuous_route_passed := false

func reward_coins(identity: String) -> Array:
	var result: Array = []
	for coin in get_nodes_in_group("m22_coins"):
		if is_instance_valid(coin) and world.is_ancestor_of(coin) and str(coin.definition.get("reward_id","")) == identity:
			result.append(coin)
	return result

func collect_lantern_reward(starting_wallet: int) -> void:
	var identity := "puzzle:margin_lantern_solved"
	var spawned := reward_coins(identity)
	var value := 0
	for coin in spawned:
		value += int(coin.definition.get("amount",0))
		check(coin.get_script().resource_path == "res://scripts/combat/m22_coin.gd", "reward is a visible native coin object")
	check(not spawned.is_empty() and value == 15, "completion spawns physical discs whose combined value is fifteen")
	check(world.combat_state.wallet == starting_wallet, "the wallet does not receive an uncollected reward automatically")
	check(CoinLedger.room_pending(world.progress,5).size() == spawned.size(), "every uncollected physical disc is represented in the persistent ledger")
	await capture("m22_lantern_coin_drop")
	# The hero is already beside the reward. Ordinary movement within the pickup
	# area demonstrates automatic collection after the short visible spawn arc.
	for tick in range(100):
		if world.combat_state.wallet == starting_wallet+15: break
		drive_toward(1800.0 if tick<35 else 1780.0)
		await step(1)
	release_controls()
	await step(4)
	check(world.combat_state.wallet == starting_wallet+15, "walking near the settled discs automatically collects exactly fifteen coins")
	check(reward_coins(identity).is_empty() and CoinLedger.room_pending(world.progress,5).is_empty(), "collected discs disappear and no pending reward remains")
	sample("physical_lantern_reward",{"reward_id":identity,"spawned_discs":spawned.size(),"combined_value":value,"wallet_before":starting_wallet,"wallet_after":world.combat_state.wallet,"collection":"actual proximity and ordinary movement; no pickup button or direct wallet mutation"})

func check(value: bool, message: String) -> bool:
	checks += 1
	if not value:
		var labelled := phase + ": " + message
		if not failures.has(labelled): failures.append(labelled)
		printerr("M22 LANTERN FAIL ", labelled)
	return value

func make_world(restore: bool = false) -> bool:
	release_controls()
	if is_instance_valid(world):
		stop_audio(world)
		OS.delay_msec(120)
		await step(2)
		world.queue_free()
		world = null
		await step(4)
	var packed: PackedScene = load(LANTERN_WORLD)
	if not check(packed != null, "M22 campaign scene loads"): return false
	world = packed.instantiate()
	packed = null
	world.restore_saved_game = restore
	world.environment_preview = true
	world.transition_seconds = 0.001
	root.add_child(world)
	await step(50)
	hero = world.hero
	return check(is_instance_valid(hero) and hero.is_on_floor(), "M22 hero starts on a real support surface")

func capture(name: String) -> void:
	await step(10)
	await RenderingServer.frame_post_draw
	var path := "user://" + name + ".jpg"
	var image := root.get_texture().get_image()
	var error := image.save_jpg(path, 0.94)
	check(error == OK and image.get_width() >= 1000, "native rendered sample saved: " + name)
	captures.append(ProjectSettings.globalize_path(path))

func close_reader() -> void:
	await pulse("pause_game")
	for tick in range(90):
		if not world.hud.panel_open and world.gameplay_active: return
		await step(1)
	check(false, "reader closes and gameplay resumes after its animation")

func climb_to_arch() -> bool:
	if not await walk_to(Vector2(476,1260)): return false
	if not await jump_to(Vector2(532,1140)): return false
	if not await walk_to(Vector2(700,1140)): return false
	if not await jump_to(Vector2(802,1020)): return false
	if not await walk_to(Vector2(970,1020)): return false
	if not await jump_to(Vector2(1072,900)): return false
	return await walk_to(Vector2(1180,900))

func route() -> void:
	phase = "configured room05 entrance; continuous input-only optional route"
	await fixture_room(5,Vector2(180,1260))
	# The fixture only chooses a normal room entrance and existing equipment;
	# it never injects a lamp state, discovery, wallet value or puzzle solution.
	var starting_hp: int = hero.hp
	var starting_wallet: int = world.combat_state.wallet
	check(not world.progress.get("margin_lantern_solved",false), "optional puzzle begins unsolved")
	if not await walk_to(Vector2(340,1260)): return
	await pulse("interact")
	await step(45)
	check(world.hud.panel_open and world.hud.current_panel == "note", "physical clue opens the actual reading interface")
	check(world.progress.notes.has("margin_lantern_clue"), "physical clue enters the persistent journal")
	check(world.hud._record_text(world.hud._active_record).title == "خط نجا من المحو", "Arabic reader uses the actual clue name")
	await capture("m22_lantern_clue_ar")
	await pulse("switch_language")
	await step(35)
	check(world.hud.language == "en" and world.hud._record_text(world.hud._active_record).title == "A Line That Survived", "the same physical clue supports English without changing its ID")
	await capture("m22_lantern_clue_en")
	await pulse("switch_language")
	await step(25)
	await close_reader()
	if not await climb_to_arch(): return
	await pulse("interact")
	check(int(world.progress.get("lantern_sequence_step", -1)) == 0 and not world.progress.margin_lantern_solved, "starting at the wrong physical lamp safely resets the unfinished line")
	check(hero.hp == starting_hp and world.combat_state.wallet == starting_wallet, "a real wrong interaction consumes no heart or coin")
	# Walk off each upper shelf to descend; there is no teleport or position
	# assignment anywhere between the configured entrance and the final lamp.
	if not await walk_to(Vector2(970,1020)): return
	if not await walk_to(Vector2(700,1140)): return
	if not await walk_to(Vector2(650,1140)): return
	await pulse("interact")
	check(world.progress.lantern_sequence_history == [1] and not world.progress.margin_lantern_solved, "actual diamond lamp links only the first part")
	await pulse("interact")
	check(world.progress.lantern_sequence_history == [1], "repeated real input at a glowing lamp cannot accidentally reset the attempt")
	if not await walk_to(Vector2(700,1140)): return
	if not await jump_to(Vector2(802,1020)): return
	if not await walk_to(Vector2(970,1020)): return
	if not await jump_to(Vector2(1072,900)): return
	if not await walk_to(Vector2(1180,900)): return
	await pulse("interact")
	check(world.progress.lantern_sequence_history == [1,0], "actual arch lamp links the second part")
	if not await walk_to(Vector2(1240,900)): return
	if not await jump_to(Vector2(1342,780)): return
	if not await walk_to(Vector2(1780,780)): return
	await pulse("interact")
	check(world.progress.margin_lantern_solved and world.progress.lantern_sequence_history == [1,0,2], "input-only shelf traversal solves the observed physical sequence")
	await collect_lantern_reward(starting_wallet)
	check(world.progress.notes.has("margin_lantern_record"), "actual success adds the discovery to the journal")
	await step(20)
	await capture("m22_lantern_completed")
	if not await walk_to(Vector2(2020,780)): return
	await pulse("interact")
	await step(40)
	check(world.hud.panel_open and world.hud.current_panel == "note" and world.hud._record_text(world.hud._active_record).title == "السطور الغائبة", "newly visible reward leaf opens with its proper Arabic name")
	await capture("m22_lantern_record")
	await close_reader()
	await pulse("journal")
	await step(45)
	check(world.hud.panel_open and world.hud.current_panel == "journal", "ordinary journal input opens the complete journal after discovery")
	var journal_ids: Array = world.hud._journal_entries().map(func(record): return str(record.id))
	check(journal_ids.has("margin_lantern_clue") and journal_ids.has("margin_lantern_record"), "both new leaves are available in the real complete journal")
	await capture("m22_lantern_journal")
	await close_reader()
	check(hero.hp == starting_hp, "the observation and retry route finishes without scripted damage")
	continuous_route_passed = failures.is_empty()
	world._save()
	var file := FileAccess.open(world.save_path(),FileAccess.READ)
	var saved: Dictionary = JSON.parse_string(file.get_as_text()) if file else {}
	file = null
	check(saved.get("progress",{}).get("margin_lantern_solved",false) and int(saved.get("combat",{}).get("wallet",-1)) == starting_wallet+15, "the real atomic save contains both completion and its wallet reward")
	phase = "actual save reload; configured solved-lamp revisit"
	if not await make_world(true): return
	check(world.progress.get("margin_lantern_solved",false) and world.progress.notes.has("margin_lantern_record"), "fresh world creation restores the completed puzzle and discovery")
	check(world.combat_state.wallet == starting_wallet+15, "fresh world creation restores the exact earned wallet")
	await fixture_room(5,Vector2(1700,780))
	check(CoinLedger.room_pending(world.progress,5).is_empty() and reward_coins("puzzle:margin_lantern_solved").is_empty(), "a saved collected reward cannot respawn on room re-entry")
	if not await walk_to(Vector2(1780,780)): return
	await pulse("interact")
	await step(65)
	check(world.combat_state.wallet == starting_wallet+15, "physically reusing the solved lamp after reload cannot duplicate the reward")
	check(reward_coins("puzzle:margin_lantern_solved").is_empty(), "a repeated solved-lamp interaction spawns no duplicate physical coins")

func run_checks() -> void:
	remember_user_files()
	phase = "fresh native M22 startup"
	var native_display := check(DisplayServer.get_name() != "headless", "rendered route review uses a native display")
	if native_display and await make_world(): await route()
	release_controls()
	if is_instance_valid(world):
		stop_audio(world)
		OS.delay_msec(120)
		await step(2)
		world.queue_free()
		world = null
		await step(4)
	phase = "safe cleanup"
	check(restore_user_files(), "pre-existing saves, controls and settings restored exactly")
	var report := {"engine":Engine.get_version_info().string, "checks":checks, "failures":failures,
		"continuous_route_passed":continuous_route_passed, "actual_input_jumps":route_jumps,
		"physics_ticks":physics_ticks, "captures":captures, "samples":samples,
		"scope":"configured normal room05 entrance; uninterrupted actual-input observation/wrong retry/shelf traversal/completion; physical coin spawn arc and proximity collection; reading/journal; actual disk save reload; separately configured solved-lamp revisit"}
	var output := FileAccess.open(LANTERN_REPORT,FileAccess.WRITE)
	if output:
		output.store_string(JSON.stringify(report,"\t"))
		output.close()
	print("M22_LANTERN_ROUTE ", JSON.stringify(report))
	OS.delay_msec(50)
	await process_frame
	quit(0 if failures.is_empty() and continuous_route_passed else 1)
