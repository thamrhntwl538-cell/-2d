extends "res://tools/test_m17_world.gd"
## M22 native integration QA. Full-route actor movement and portal use are real
## Input actions; isolated encounter and restoration fixtures are labelled.
const M22_WORLD := "res://scenes/stage_01/folding_library_m22.tscn"
const M22_REPORT := "user://m22_world_report.json"
var stage := "startup"
var evidence: Array[Dictionary] = []
var genuine_first_victory := false
var encounter_results: Array[Dictionary] = []
var ui_results: Array[Dictionary] = []
var lamp_result: Dictionary = {}
var native_reader_checked := false
var native_journal_checked := false
var native_captures: Array[String] = []
var cover_blocks: int = 0
var observed_bolts: Dictionary = {}
var run_mode := "full"
var focused_suite_completed := false

func focus_snapshot() -> Dictionary:
	var focused: Control = root.gui_get_focus_owner()
	return {"path":str(focused.get_path()),"class":focused.get_class(),"text":focused.text if focused is Button else "","index":world.hud._index_buttons.find(focused)} if is_instance_valid(focused) else {}

func native_capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var path := "user://m22_native_"+name+".jpg"
	var rendered: Image = root.get_texture().get_image()
	if check(rendered.save_jpg(path,0.94)==OK,"native image saved: "+name): native_captures.append(path)

func joy_button(button: int) -> void:
	await physics_frame
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = true
	if button==JOY_BUTTON_A:
		record("controller_accept_binding",{"matches_ui_accept":event.is_action_pressed("ui_accept"),"events":InputMap.action_get_events("ui_accept").map(func(item):return item.as_text())})
	Input.parse_input_event(event)
	await step(3)
	event = InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = false
	Input.parse_input_event(event)
	await step(3)

func reader_and_journal_input_checks(identity: String) -> void:
	stage = "native curated leaf and bilingual journal"
	await step(25)
	var hud = world.hud
	check(hud.panel_open and hud.current_panel=="note" and not world.gameplay_active,"actual physical leaf opens the paused native reader")
	check(str(hud._active_record.get("id",""))==identity,"reader shows the physically selected leaf")
	check(world.progress.get("notes",[]).has(identity),"physical reading adds the same persistent journal ID")
	var origin: Vector2 = hero.position
	var velocity: Vector2 = hero.velocity
	var elapsed_before: float = world.elapsed
	var initial_language: String = hud.language
	var first_text: Dictionary = hud._record_text(hud._active_record)
	check(not str(first_text.title).is_empty() and not str(first_text.body).is_empty(),"physical reader has a title and complete body")
	await native_capture("reading_"+hud.language)
	await physical_key(KEY_F2)
	await step(12)
	var second_text: Dictionary = hud._record_text(hud._active_record)
	check(hud.language!=initial_language and str(hud._active_record.get("id",""))==identity,"F2 changes language without changing the selected physical record")
	check(str(first_text.title)!=str(second_text.title) and str(first_text.body)!=str(second_text.body),"real reader has different authored Arabic and English content")
	await native_capture("reading_"+hud.language)
	check(hero.position.is_equal_approx(origin) and hero.velocity.is_equal_approx(velocity) and is_equal_approx(world.elapsed,elapsed_before),"reading and switching language freeze actor and hazard time")
	await physical_key(KEY_F2)
	await step(8)
	check(hud.language==initial_language,"F2 restores the original language")
	ui_results.append({"kind":"physical_bilingual_leaf","record":identity,"actual_world_interact":true,"actual_F2_keys":true,"paused_world":true})
	native_reader_checked = true
	if not await close_panel_input(): return
	await physical_key(KEY_N)
	await step(25)
	check(hud.panel_open and hud.current_panel=="journal" and not world.gameplay_active,"physical N opens the actual full journal")
	var ids: Array[String] = []
	for entry in hud._journal_entries(): ids.append(str(entry.id))
	check(ids.has(identity),"the discovered physical leaf is listed in the full journal")
	var focused: Control = root.gui_get_focus_owner()
	check(is_instance_valid(focused) and focused is Button and hud._index_buttons.has(focused),"opening journal gives a real list button controller focus")
	if is_instance_valid(focused):
		await joy_button(JOY_BUTTON_A)
		await step(12)
		check(hud.panel_open and hud.current_panel=="journal" and not str(hud._active_record.get("id","")).is_empty(),"controller accept selects the focused journal record")
	if hud._index_buttons.size()>1:
		var old_focus: Control = root.gui_get_focus_owner()
		await joy_button(JOY_BUTTON_DPAD_DOWN)
		check(is_instance_valid(root.gui_get_focus_owner()) and root.gui_get_focus_owner()!=old_focus,"real controller D-pad moves journal focus")
		await joy_button(JOY_BUTTON_A)
		await step(10)
	var selected: String = str(hud._active_record.get("id",""))
	var saved_page: int = hud.reading_page
	await physical_key(KEY_F2)
	await step(10)
	check(str(hud._active_record.get("id",""))==selected and hud.reading_page==saved_page,"journal selection/page survive a real language change")
	await physical_key(KEY_F2)
	await step(8)
	await joy_button(JOY_BUTTON_RIGHT_SHOULDER)
	await joy_button(JOY_BUTTON_LEFT_SHOULDER)
	check(not world.gameplay_active and hud.panel_open,"controller page/scroll shoulders stay inside the paused reader")
	ui_results.append({"kind":"native_journal_controller","kept_ids":ids,"actual_N_key":true,"actual_gamepad_events":true,"selected_record":selected,"page":hud.reading_page})
	await native_capture("journal_first_leaf")
	native_journal_checked = true
	await close_panel_input()

func check(value: bool, message: String) -> bool:
	checks += 1
	if not value:
		var labelled := stage+": "+message
		if not failures.has(labelled): failures.append(labelled)
		print("M22 QA FAIL: ",labelled)
	return value

func record(kind: String, value: Dictionary) -> void:
	value.kind = kind
	value.stage = stage
	value.physics_tick = physics_ticks
	evidence.append(value)

func release_controls() -> void:
	for action in ["move_left","move_right","look_up","look_down","jump","attack","dash","heal","spell","interact","pause_game","stage_map","journal","switch_language","ui_up","ui_down","ui_left","ui_right","ui_accept","ui_cancel"]:
		if InputMap.has_action(action): Input.action_release(action)

func make_world(restore: bool = false, preview: bool = true) -> bool:
	release_controls()
	if is_instance_valid(world):
		stop_audio(world)
		OS.delay_msec(120)
		await process_frame
		world.queue_free()
		world = null
		await process_frame
		await process_frame
	var packed: PackedScene = load(M22_WORLD)
	if not check(packed!=null,"M22 campaign scene loads"): return false
	world = packed.instantiate()
	packed = null
	if not check(world.get_script()!=null and world.has_method("_load_room"),"M22 controller and every preload compile before testing"):
		world.free()
		world = null
		return false
	world.restore_saved_game = restore
	world.environment_preview = preview
	world.transition_seconds = 0.001
	root.add_child(world)
	await step(45)
	hero = world.hero
	return check(is_instance_valid(hero) and hero.is_on_floor(),"initial actor is physically supported")

func close_panel_input() -> bool:
	if not world.hud.panel_open: return true
	await physical_key(KEY_ESCAPE)
	for tick in range(80):
		if not world.panel_closing and not world.hud.panel_open: break
		await step(1)
	return check(not world.panel_closing and not world.hud.panel_open and world.gameplay_active,"native ESC closes the full panel animation and resumes play")

func emit_ui(action_id: String, value: Variant = null) -> void:
	world.hud.action.emit(action_id,value)
	await step(3)
	if action_id in ["close_panel","resume"]:
		for tick in range(80):
			if not world.panel_closing: break
			await step(1)

func fixture_room(id: int, spawn: String = "left", at: Vector2 = Vector2.INF) -> void:
	release_controls()
	if world.hud.panel_open: await close_panel_input()
	world._load_room(id,spawn,at)
	hero = world.hero
	await step(35)
	record("configured_room_start",{"room":id,"spawn":spawn,"position":[hero.position.x,hero.position.y],"configured_start_only":true})

func jump_to(point: Vector2) -> bool:
	var start: Vector2 = hero.position
	var airborne := false
	var landed := false
	var apex: float = start.y
	await physics_frame
	Input.action_press("jump")
	for tick in range(140):
		drive_toward(point.x)
		await step(1)
		apex = minf(apex,hero.position.y)
		if not hero.is_on_floor(): airborne = true
		if airborne and hero.velocity.y>=0: Input.action_release("jump")
		if airborne and hero.is_on_floor():
			landed = true
			break
	Input.action_release("jump")
	var passed := airborne and landed and absf(hero.position.y-point.y)<3.0
	landings.append({"room":world.current_room,"start":[start.x,start.y],"target":[point.x,point.y],"landed":[hero.position.x,hero.position.y],"apex_y":apex,"actual_input":true,"hold":"through ascent","passed":passed})
	if not check(passed,"held jump to %s landed %s (%s)"%[point,hero.position,current_goal]):
		release_controls()
		return false
	return await walk_to(point,200)

func interact_with(id: String, solve: bool = true) -> bool:
	var definition := object_definition(id)
	if not check(not definition.is_empty(),"object exists: "+id): return false
	if not check(hero.position.distance_to(definition.pos)<112,"actual actor is in range of "+id): return false
	var nearest: Dictionary = world.nearest_action()
	if not check(nearest.get("type","")=="object" and str(nearest.entry.definition.id)==id,"native nearest-action selects "+id): return false
	await pulse("interact")
	if not solve: return true
	if str(definition.get("kind","")) in ["note","secret"] and not native_reader_checked:
		await reader_and_journal_input_checks(id)
		return not world.hud.panel_open
	if str(definition.get("kind","")) in ["ink_control","process_control","output_control","balance_control","secret_overlay","secret_pop"]:
		return await solve_open_puzzle(str(definition.kind))
	if world.hud.panel_open: return await close_panel_input()
	return true

func fight_first_larva() -> bool:
	stage = "continuous first native larva victory" if run_mode=="full" else "configured native first larva and physical reward"
	if not await walk_to(Vector2(1160,1260)): return false
	var enemy: Node2D
	for actor in world.enemies:
		if is_instance_valid(actor) and not actor.is_dead: enemy=actor; break
	if not check(is_instance_valid(enemy),"room02 contains its live larva"): return false
	var states: Array[String] = []
	var health_before: int = hero.hp
	var wallet_before: int = world.combat_state.wallet
	for tick in range(1800):
		if not is_instance_valid(enemy) or enemy.is_dead: break
		if not states.has(enemy.state): states.append(enemy.state)
		var dx: float = enemy.position.x-hero.position.x
		if tick%20==3: Input.action_release("attack")
		Input.action_release("jump")
		Input.action_release("look_down")
		if absf(dx)>115:
			drive_toward(enemy.position.x-float(signf(dx))*95)
		else:
			Input.action_release("move_left")
			Input.action_release("move_right")
			if hero.facing!=int(signf(dx)) and absf(dx)>3 and hero.attack_time<=0:
				Input.action_press("move_right" if dx>0 else "move_left")
			if hero.is_on_floor() and enemy.state=="windup" and enemy.state_time<0.19: Input.action_press("jump")
			if not hero.is_on_floor() and hero.position.y<enemy.position.y-28: Input.action_press("look_down")
			# Observe one complete real warning/lunge/recovery before attacking;
			# a fast early kill otherwise need not expose every legal AI state.
			if tick%20==0 and hero.hurt_time<=0 and states.has("recover") and states.has("lunge"): Input.action_press("attack")
		await step(1)
	release_controls()
	genuine_first_victory = bool(world.progress.get("encounter_assignments_cleared",false))
	check(genuine_first_victory and hero.hp>0,"real manual-input strikes defeat the active larva without death, injected hits or target freeze")
	check(states.has("windup") and states.has("lunge") and states.has("recover"),"genuine fight observes warning, lunge and recovery")
	check(world.combat_state.wallet==wallet_before,"enemy death creates physical coins before wallet credit")
	if run_mode=="native-focused":
		world._save()
		var record_on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
		check(not record_on_disk.progress.get("currency_rewards",{}).is_empty(),"the real kill persists unclaimed physical currency")
		if not await make_world(true,true): return false
		# Revisit outside the legitimate90px pickup magnet, then walk back.
		await fixture_room(2,"left",Vector2(800,1260))
		check(world.enemies.is_empty() and world.combat_state.wallet==wallet_before,"leaving and recreating the world keeps the earned larva clear without crediting its unclaimed coins")
		record("unclaimed_reward_real_reload",{"after_actual_kill":true,"room_revisit_configured":true,"enemy_stays_defeated":world.enemies.is_empty(),"wallet_before_collection":world.combat_state.wallet})
	await collect_reward_coins("enemy:encounter_assignments_cleared",wallet_before,12)
	record("native_larva_fight",{"actual_input":true,"configured_start_only":run_mode!="full","won":genuine_first_victory,"states_seen":states,"health_before":health_before,"health_after":hero.hp,"coins":world.combat_state.wallet-wallet_before,"actor_teleported_during_fight":false,"enemy_frozen":false,"hits_injected":false})
	await step(30)
	return genuine_first_victory

func walkthrough() -> void:
	stage = "continuous fifteen-room route"
	if not await make_world(false,true): return
	for room_id in range(1,16):
		stage = "continuous route room%02d"%room_id
		if not check(world.current_room==room_id,"continuous route reaches the expected room"): return
		print("M22 QA WALK ROOM ",room_id)
		if room_id==2 and not await fight_first_larva(): return
		if not await run_actions("main"): return
		rooms_walked.append(room_id)
		if room_id<15:
			if room_id==4 and world.data.qa_actions.has("to_optional"):
				if not await run_actions("to_optional"): return
			if not await use_exit(room_id+1): return
		for flag in ["guard_clear","compiler_seal_owned","seal_registered","boss_defeated","world1_departed"]:
			if not check(not bool(world.progress.get(flag,false)),"preview traversal does not forge absent combat or real departure: "+flag): return
	route_complete = true

func find_enemy(script_path: String) -> Node2D:
	for actor in world.enemies:
		if is_instance_valid(actor) and not actor.is_dead and actor.get_script().resource_path==script_path: return actor
	return null

func wait_enemy_state(actor: Node2D, wanted: String, limit: int = 300) -> bool:
	for tick in range(limit):
		if not is_instance_valid(actor): return false
		if actor.state==wanted: return true
		await step(1)
	return false

func native_melee_victory(actor: Node2D, label: String, limit: int = 1000) -> bool:
	var wallet_before: int = world.combat_state.wallet
	var health_before: int = hero.hp
	var definition: Dictionary = actor.get_meta("encounter_definition",{})
	var reward_id := "enemy:"+str(definition.get("clear_flag",definition.get("id",actor.name)))
	var states: Array[String] = []
	for tick in range(limit):
		if not is_instance_valid(actor) or actor.is_dead: break
		if not states.has(actor.state): states.append(actor.state)
		var dx: float = actor.position.x-hero.position.x
		if tick%24==4: Input.action_release("attack")
		Input.action_release("look_up")
		Input.action_release("look_down")
		if absf(dx)>75:
			drive_toward(actor.position.x-signf(dx)*66)
		else:
			Input.action_release("move_left")
			Input.action_release("move_right")
			if hero.facing!=int(signf(dx)) and absf(dx)>3 and hero.attack_time<=0:
				Input.action_press("move_right" if dx>0 else "move_left")
		if actor.position.y<hero.position.y-55: Input.action_press("look_up")
		if tick%24==0 and hero.hurt_time<=0: Input.action_press("attack")
		await step(1)
	release_controls()
	var won: bool = not is_instance_valid(actor) or actor.is_dead
	check(won and hero.hp>0,label+": active enemy defeated using native attack/movement inputs")
	check(world.combat_state.wallet==wallet_before,label+": no instant wallet credit at death")
	if won: await collect_reward_coins(reward_id,wallet_before,12)
	encounter_results.append({"kind":label,"configured_start_only":true,"actual_input_fight":true,"won":won,"states_seen":states,"health_before":health_before,"health_after":hero.hp,"coins_earned":world.combat_state.wallet-wallet_before,"target_frozen":false,"hits_injected":false})
	return won

func collect_reward_coins(reward_id: String, wallet_before: int, amount: int) -> void:
	var before: Array[Node] = []
	for coin in get_nodes_in_group("m22_coins"):
		if is_instance_valid(coin) and str(coin.get_meta("reward_id",""))==reward_id: before.append(coin)
	check(not before.is_empty(),"native physical reward exists: "+reward_id)
	var definitions: Array = []
	for coin in before: definitions.append(coin.definition.duplicate(true))
	for coin in before:
		if not is_instance_valid(coin): continue
		var settled: Vector2 = coin.settled_position
		if not await walk_to(Vector2(settled.x,hero.position.y),300): return
		await step(60)
	await step(8)
	check(world.combat_state.wallet==wallet_before+amount,"walking near native drops credits the exact reward: "+reward_id)
	var wallet_after: int = world.combat_state.wallet
	for definition in definitions: check(not world.collect_world_coin(definition),"the same collected coin cannot be claimed twice")
	check(world.combat_state.wallet==wallet_after,"duplicate coin callbacks leave wallet unchanged")
	record("actual_coin_collection",{"reward_id":reward_id,"native_drops":definitions.size(),"wallet_before":wallet_before,"wallet_after":wallet_after,"actual_movement_and_autocollect":true,"claim_injected_for_positive_path":false})

func wraith_integration_checks() -> void:
	stage = "native balcony wraith keeps its old floor target"
	await fixture_room(3,"left",Vector2(1040,900))
	var actor := find_enemy("res://scripts/enemies/m22_popup_wraith.gd")
	if not check(is_instance_valid(actor),"canonical optional wraith exists"): return
	if not check(await wait_enemy_state(actor,"windup"),"native wraith starts its warning after arrival grace"): return
	var old_target: Vector2 = actor.captured_target
	var marker: Vector2 = actor.marker_world_position
	var hp_before: int = hero.hp
	check(actor.target_valid and absf(old_target.y-900)<2,"native wraith warning captures a real balcony floor")
	if not await walk_to(Vector2(920,900)): return
	check(actor.captured_target.is_equal_approx(old_target) and actor.marker_world_position.is_equal_approx(marker),"moving during warning leaves the recorded target/marker unchanged")
	check(await wait_enemy_state(actor,"recover",120),"native wraith completes its fixed dive")
	check(actor.captured_target.is_equal_approx(old_target) and hero.hp==hp_before,"fixed dive misses the actor that moved away")
	check(actor.danger_rect().size==Vector2.ZERO,"recovery has no contact damage")
	record("wraith_old_target",{"captured_floor":[old_target.x,old_target.y],"hero_after_dodge":[hero.position.x,hero.position.y],"native_warning_and_dive":true,"target_state_injected":false,"health_lost":hp_before-hero.hp})
	await native_capture("wraith_recovery")
	await native_melee_victory(actor,"optional_wraith_native_victory")
	check(bool(world.progress.get("lab_popup_wraith",false)),"native wraith clear is registered for persistence")

func observe_bolts() -> void:
	for bolt in get_nodes_in_group("m22_hostile_projectiles"):
		if not is_instance_valid(bolt) or observed_bolts.has(bolt.get_instance_id()): continue
		observed_bolts[bolt.get_instance_id()] = true
		bolt.tree_exiting.connect(func():
			if bolt.blocked_by_cover: cover_blocks += 1)

func turret_integration_checks() -> void:
	stage = "native gallery turret bolts hit real book cover"
	await fixture_room(8,"left",Vector2(2600,900))
	var actor := find_enemy("res://scripts/enemies/m22_syntax_turret.gd")
	if not check(is_instance_valid(actor),"canonical optional gallery turret exists"): return
	var hp_before: int = hero.hp
	cover_blocks = 0
	observed_bolts.clear()
	var states: Array[String] = []
	for tick in range(330):
		observe_bolts()
		if not states.has(actor.state): states.append(actor.state)
		await step(1)
		if cover_blocks>=3 and actor.total_shots>=3: break
	check(states.has("windup") and states.has("burst") and states.has("reload"),"native turret exposes warning, three-shot burst and reload")
	check(actor.total_shots>=3 and cover_blocks>=3 and hero.hp==hp_before,"real solid book cover intercepts all three emitted bolts before the hero")
	record("native_turret_cover",{"native_AI":true,"states_seen":states,"shots":actor.total_shots,"cover_blocks":cover_blocks,"hp_before":hp_before,"hp_after":hero.hp,"book_cover_removed":false})
	await native_capture("turret_cover")
	var saw_live_bolt := false
	for tick in range(360):
		observe_bolts()
		await step(1)
		if not get_nodes_in_group("m22_hostile_projectiles").is_empty(): saw_live_bolt=true; break
	check(saw_live_bolt,"a real emitted bolt is available for the pause-cleanup check")
	await physical_key(KEY_M)
	await step(15)
	check(world.hud.panel_open and world.hud.current_panel=="map" and not world.gameplay_active,"actual M opens the paused map during a burst")
	check(get_nodes_in_group("m22_hostile_projectiles").is_empty(),"opening map consumes live hostile bolts")
	var state_time_before: float = actor.state_time
	var age_before: float = actor.age
	await step(30)
	check(is_equal_approx(actor.state_time,state_time_before) and is_equal_approx(actor.age,age_before),"paused map freezes the native turret warning/cadence")
	await close_panel_input()
	if not await walk_to(Vector2(2646,900)): return
	if not await jump_to(Vector2(2702,784)): return
	if not await drop_to(Vector2(2840,900)): return
	await native_melee_victory(actor,"optional_turret_native_victory")
	check(bool(world.progress.get("process_syntax_turret",false)),"native turret clear is registered for persistence")
	await step(5)
	check(get_nodes_in_group("m22_hostile_projectiles").is_empty(),"turret defeat clears all of its surviving ink")

func complete_journal_checks() -> void:
	stage = "actual complete journal and controller focus"
	var progress_before: Dictionary = world.progress.duplicate(true)
	await physical_key(KEY_N)
	await step(25)
	var hud = world.hud
	check(hud.panel_open and hud.current_panel=="journal" and hud._index_buttons.size()>1,"real journal contains the leaves actually found across the continuous tour")
	var first_focus: Control = root.gui_get_focus_owner()
	var first_focus_description := focus_snapshot()
	var navigation := JOY_BUTTON_DPAD_UP if hud._index_buttons.find(first_focus)==hud._index_buttons.size()-1 else JOY_BUTTON_DPAD_DOWN
	await joy_button(navigation)
	var next_focus: Control = root.gui_get_focus_owner()
	var next_focus_description := focus_snapshot()
	check(is_instance_valid(first_focus) and is_instance_valid(next_focus) and next_focus!=first_focus and hud._index_buttons.has(next_focus),"real D-pad moves between native full-journal records")
	var accepted_title: String = next_focus.text if next_focus is Button else ""
	await joy_button(JOY_BUTTON_A)
	await step(15)
	var record_text: Dictionary = hud._record_text(hud._active_record)
	record("journal_focus_trace",{"before":first_focus_description,"after_Dpad":next_focus_description,"after_A":focus_snapshot(),"accepted_title":accepted_title,"actual_title":record_text.title,"active_id":hud._active_record.get("id","")})
	check(str(record_text.title)==accepted_title,"controller accept opens exactly the highlighted full-journal leaf")
	var selected: String = str(hud._active_record.get("id",""))
	var original_language: String = hud.language
	await native_capture("journal_"+hud.language)
	await physical_key(KEY_F2)
	await step(10)
	check(hud.language!=original_language and str(hud._active_record.get("id",""))==selected,"full-journal locale switch preserves chosen record")
	await native_capture("journal_"+hud.language)
	await physical_key(KEY_F2)
	await step(8)
	check(world.progress==progress_before,"browsing/selecting/translating journal invents no discovery or world progress")
	ui_results.append({"kind":"actual_tour_complete_journal","discovered_places":world.progress.visited.size(),"kept_pages":hud._journal_entries().size(),"controller_selection":selected,"real_Dpad_and_A":true,"progress_unchanged":world.progress==progress_before})
	await close_panel_input()

func campaign_restore_checks() -> void:
	stage = "M22 real campaign save and restoration"
	var expected: Dictionary = world.progress.duplicate(true)
	var wallet_before: int = world.combat_state.wallet
	var checkpoint_before: Dictionary = world.checkpoint.duplicate(true)
	world._save()
	if not await make_world(true,true): return
	check(JSON.parse_string(JSON.stringify(world.progress))==JSON.parse_string(JSON.stringify(expected)),"fresh world restores every genuine campaign/puzzle/journal value after JSON number normalization")
	check(world.combat_state.wallet==wallet_before,"fresh world restores exact earned coins")
	check(world.checkpoint==checkpoint_before and world.current_room==int(checkpoint_before.room) and hero.is_on_floor(),"fresh world returns to the actual supported saved bench")
	for room_id in [2,3,8]:
		var flag := "encounter_assignments_cleared" if room_id==2 else "lab_popup_wraith" if room_id==3 else "process_syntax_turret"
		if not bool(expected.get(flag,false)): continue
		await fixture_room(room_id)
		check(world.enemies.is_empty(),"earned canonical encounter clear survives reload without respawn in room%02d"%room_id)
	await physical_key(KEY_N)
	await step(20)
	var ids: Array[String] = []
	for entry in world.hud._journal_entries(): ids.append(str(entry.id))
	for identity in expected.get("notes",[]): check(ids.has(str(identity)),"saved leaf remains selectable after reload: "+str(identity))
	await close_panel_input()
	record("campaign_save_restore",{"checkpoint":checkpoint_before,"earned_wallet":wallet_before,"kept_ids":ids,"restored_world_created_from_disk":true,"canonical_defeats_persist":true})

func fold_reward_checks() -> void:
	stage = "configured output eligibility; native fold and physical task coins"
	world.progress.books_collected=true
	world.progress.book_order_verified=true
	world.progress.book_inventory=["TRIANGLE","SQUARE","CIRCLE"]
	await fixture_room(9,"left",Vector2(750,1260))
	var wallet_before: int = world.combat_state.wallet
	await pulse("interact")
	check(world.fold_active and not world.progress.output_open,"actual console starts a fold before committing its collision/progress")
	for tick in range(150):
		if not world.fold_active: break
		await step(1)
	check(world.progress.output_open and not world.fold_active,"real safe fold animation settles and commits")
	check(world.combat_state.wallet==wallet_before,"main puzzle completion drops coins instead of directly crediting wallet")
	await collect_reward_coins("task:fold:output_open",wallet_before,9)
	var after: int = world.combat_state.wallet
	await pulse("interact")
	await step(60)
	check(world.combat_state.wallet==after,"reusing the completed console cannot duplicate its task reward")
	record("main_fold_physical_reward",{"configured_eligibility_only":true,"actual_console_input":true,"actual_fold_animation":true,"actual_coin_pickups":true,"reward":9,"completed_flag":"output_open"})

func bookmark_disk_checks() -> void:
	stage = "existing-leaf two-page fixture and actual bookmark disk restore"
	await physical_key(KEY_N)
	await step(20)
	var hud = world.hud
	var identity: String = str(hud._active_record.get("id",""))
	if not check(world.progress.notes.has(identity),"pagination fixture uses an existing collected official leaf ID"): return
	# The official leaf is short. Only the reader's runtime catalog gets two
	# authored test pages; no invented leaf or test text enters saved progress.
	for key in ["notes","note_catalog","journal_catalog"]:
		for entry in hud.panel_context.get(key,[]):
			if entry is Dictionary and str(entry.get("id",""))==identity:
				entry.pages_ar=["صفحة اختبار أولى للتحقق من حفظ موضع القراءة.","صفحة اختبار ثانية للتحقق من استعادة موضع القراءة."]
				entry.pages_en=["First authored pagination fixture page.","Second authored pagination fixture page."]
	hud.panel_context.reading_page=0
	hud.refresh_panel()
	await step(10)
	check(hud.reading_page_count==2,"runtime catalog fixture has two real reader pages")
	await joy_button(JOY_BUTTON_RIGHT_SHOULDER)
	await step(18)
	check(hud.reading_page==1 and int(hud.journal_cursor.get("page",-1))==1,"real controller shoulder advances and remembers page two")
	var path: String = world.save_path()
	var saved_text := FileAccess.get_file_as_string(path)
	var saved: Dictionary = JSON.parse_string(saved_text)
	check(str(saved.get("journal_cursor",{}).get("id",""))==identity and int(saved.get("journal_cursor",{}).get("page",-1))==1,"normal world callback atomically writes selected official ID and page two")
	var kept: Array = world.progress.notes.duplicate()
	if not await make_world(true,true): return
	check(str(world.hud.journal_cursor.get("id",""))==identity and int(world.hud.journal_cursor.get("page",-1))==1,"fresh real M22 world restores the exact saved bookmark")
	check(world.progress.notes==kept,"bookmark restoration adds no fictitious discovery")
	var old: Dictionary = saved.duplicate(true)
	old.erase("journal_cursor")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(old))
	if not await make_world(true,true): return
	check(str(world.hud.journal_cursor.get("id",""))=="" and int(world.hud.journal_cursor.get("page",-1))==0,"an older save without the optional bookmark field loads safely")
	check(world.progress.notes==kept,"old-save bookmark compatibility retains all real leaf IDs")
	record("bookmark_disk_restore",{"official_leaf_id":identity,"runtime_two_page_fixture":true,"actual_controller_page_turn":true,"actual_disk_save_and_fresh_world":true,"saved_zero_based_page":1,"old_save_without_bookmark_loads":true,"fictional_ID_saved":false})

func run_checks() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://"))
	for path in ["user://folding_library_m18.json","user://folding_library_m18_preview.json","user://folding_library_m18_settings.cfg","user://m18_controls.cfg"]:
		var existed := FileAccess.file_exists(path)
		save_backups[path] = {"existed":existed,"contents":FileAccess.get_file_as_bytes(path) if existed else PackedByteArray()}
	var args := OS.get_cmdline_user_args()
	run_mode = "ui-only" if "--ui-only" in args else "native-focused" if "--native-focused" in args else "full"
	if run_mode=="ui-only":
		if await make_world(false,true):
			if DisplayServer.get_name()!="headless":
				# Native photos use an actual physical leaf after a labelled
				# supported nook start, ordinary movement and interact input.
				await fixture_room(1,"left",Vector2(1110,1140))
				if await walk_to(Vector2(1180,1140)): await interact_with("entrance_note")
			# Existing official IDs only: a labelled journal-controller fixture,
			# not discovery or continuous-traversal evidence.
			world.progress.notes=["entrance_note","assignment_note","lab_note"]
			world.progress.visited=[1,2,3]
			await complete_journal_checks()
			await bookmark_disk_checks()
			focused_suite_completed=true
	elif run_mode=="native-focused":
		if await make_world(false,true):
			world.progress.weapon_owned=true
			world.combat_state.dash_owned=true
			world.combat_state.spell_owned=true
			hero.has_blade=true
			hero.has_dash=true
			hero.has_code_slash=true
			await fixture_room(2,"left",Vector2(1160,1260))
			await fight_first_larva()
			await wraith_integration_checks()
			await turret_integration_checks()
			await fold_reward_checks()
			await campaign_restore_checks()
			focused_suite_completed=true
	else: await walkthrough()
	if route_complete and run_mode=="full":
		await complete_journal_checks()
		await wraith_integration_checks()
		await turret_integration_checks()
		await campaign_restore_checks()
	release_controls()
	if is_instance_valid(world):
		stop_audio(world)
		OS.delay_msec(120)
		await process_frame
		world.queue_free()
		world = null
		await process_frame
		await process_frame
	var restored := true
	for path in save_backups:
		if save_backups[path].existed:
			FileAccess.open(path,FileAccess.WRITE).store_buffer(save_backups[path].contents)
		elif FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if FileAccess.file_exists(path)!=bool(save_backups[path].existed): restored=false
		elif save_backups[path].existed and FileAccess.get_file_as_bytes(path)!=save_backups[path].contents: restored=false
	check(restored,"QA restores original save/settings bytes")
	var report := {"engine":Engine.get_version_info().string,"mode":run_mode,"display_server":DisplayServer.get_name(),"checks":checks,"failures":failures,"physics_ticks":physics_ticks,"continuous_route_complete":route_complete,"rooms_walked":rooms_walked,"landings":landings,"transitions":transitions,"evidence":evidence,"encounters":encounter_results,"ui":ui_results,"captures":native_captures,"genuine_first_victory":genuine_first_victory,"save_restored":restored,"separate_lamp_suite":"res://tools/test_m22_lantern_route.gd","scope":"full mode: actual movement/portals through15 rooms, actual first larva victory; focused modes: labelled configured native optional fights or journal data only; later guardian/boss remain explicit environment-preview bypass, no real victory claimed"}
	FileAccess.open(M22_REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M22 QA REPORT ",M22_REPORT," checks=",checks," failures=",failures.size()," route_complete=",route_complete)
	OS.delay_msec(50)
	await process_frame
	quit(0 if failures.is_empty() and (route_complete or focused_suite_completed) else 1)
