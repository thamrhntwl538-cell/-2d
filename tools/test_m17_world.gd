extends SceneTree
## Native Godot M17 QA. Positive route movement uses Input actions and authored
## takeoff/landing waypoints. Configured room spawns are explicitly isolated fixtures.
const WORLD_PATH := "res://scenes/stage_01/folding_library.tscn"
const REPORT := "user://m17_world_report.json"
var world: Node2D
var hero: CharacterBody2D
var failures: Array[String] = []
var checks: int = 0
var physics_ticks: int = 0
var landings: Array[Dictionary] = []
var transitions: Array[Dictionary] = []
var fixture_results: Array[Dictionary] = []
var rooms_walked: Array[int] = []
var route_complete: bool = false
var saved_original: String = ""
var had_save: bool = false
var save_path: String = "user://folding_library_m17_preview.json"
var save_backups: Dictionary = {}
var current_goal := "startup"

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> bool:
	checks += 1
	if not value and not failures.has(message):
		failures.append(message)
		print("M17 QA FAIL: ", message)
	return value

func stop_audio(node: Node) -> void:
	for child in node.get_children(): stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null

func step(count: int) -> void:
	for tick in range(count):
		await physics_frame
		physics_ticks += 1

func release_controls() -> void:
	for key in ["move_left", "move_right", "jump", "interact", "pause_game", "stage_map", "dash"]:
		if InputMap.has_action(key): Input.action_release(key)

func pulse(key: String) -> void:
	await physics_frame
	Input.action_press(key)
	await step(3)
	Input.action_release(key)
	await step(3)

func physical_key(code: int) -> void:
	await physics_frame
	var pressed := InputEventKey.new()
	pressed.physical_keycode = code
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await step(3)
	var released := InputEventKey.new()
	released.physical_keycode = code
	released.pressed = false
	Input.parse_input_event(released)
	await step(3)

func drive_toward(x: float) -> void:
	var error: float = x - hero.position.x
	var acceleration: float = 2650.0 if hero.is_on_floor() else 1950.0
	var braking: float = hero.velocity.x * hero.velocity.x / (2.0 * acceleration)
	if absf(error) < 3.0 or (hero.velocity.x * error > 0.0 and absf(error) < braking + 3.0):
		Input.action_release("move_left")
		Input.action_release("move_right")
	elif error > 0.0:
		Input.action_release("move_left")
		Input.action_press("move_right")
	else:
		Input.action_release("move_right")
		Input.action_press("move_left")

func walk_to(point: Vector2, limit: int = 1500) -> bool:
	for tick in range(limit):
		drive_toward(point.x)
		await step(1)
		if absf(hero.position.x - point.x) <= 6.0 and absf(hero.velocity.x) < 3.0 and hero.is_on_floor() and absf(hero.position.y - point.y) < 3.0:
			release_controls()
			return true
	release_controls()
	return check(false, "Room %d walk %s stopped %s (%s)" % [world.current_room, point, hero.position, current_goal])

func jump_to(point: Vector2) -> bool:
	var start: Vector2 = hero.position
	var airborne: bool = false
	var landed: bool = false
	var apex: float = hero.position.y
	await physics_frame
	Input.action_press("jump")
	for tick in range(140):
		drive_toward(point.x)
		await step(1)
		if tick == 2: Input.action_release("jump")
		apex = minf(apex, hero.position.y)
		if not hero.is_on_floor(): airborne = true
		if airborne and hero.is_on_floor():
			landed = true
			break
	Input.action_release("jump")
	var correct: bool = airborne and landed and absf(hero.position.y - point.y) < 3.0
	landings.append({"room":world.current_room,"start":[start.x,start.y],"target":[point.x,point.y],"landed":[hero.position.x,hero.position.y],"apex_y":apex,"actual_input":true,"passed":correct})
	if not check(correct, "Room %d jump %s landed %s (%s)" % [world.current_room, point, hero.position, current_goal]):
		release_controls()
		return false
	return await walk_to(point, 200)

func drop_to(point: Vector2) -> bool:
	for tick in range(320):
		drive_toward(point.x)
		await step(1)
		if hero.is_on_floor() and absf(hero.position.y-point.y)<3.0 and absf(hero.position.x-point.x)<7.0:
			release_controls()
			return true
	release_controls()
	return check(false, "Room %d drop %s stopped %s" % [world.current_room, point, hero.position])

func emit_ui(action_id: String, value: Variant = null) -> void:
	world.hud.action.emit(action_id, value)
	await step(3)

func object_definition(id: String) -> Dictionary:
	for definition in world.data.get("objects", []):
		if str(definition.get("id", "")) == id: return definition
	return {}

func interact_with(id: String, solve: bool = true) -> bool:
	var definition: Dictionary = object_definition(id)
	if not check(not definition.is_empty(), "Missing object " + id): return false
	if not check(hero.position.distance_to(definition.pos)<115.0, "Object " + id + " is out of interact range at " + str(hero.position)): return false
	await pulse("interact")
	if not solve: return true
	var kind: String = str(definition.get("kind", ""))
	if kind in ["ink_control", "process_control", "output_control", "balance_control", "secret_overlay", "secret_pop"]:
		return await solve_open_puzzle(kind)
	if world.hud.panel_open:
		await emit_ui("close_panel")
	return true

func solve_open_puzzle(kind: String) -> bool:
	# Native UI action signals are the same path as the real panel buttons.
	# The controller owns validation, animation, persistence and geometry commits.
	var state_key := ""
	var target: Array = []
	var operation := "rotate"
	match kind:
		"ink_control":
			state_key = "ink_rotations"
			target = [2,0,3]
		"process_control":
			state_key = "book_order"
			target = ["TRIANGLE","SQUARE","CIRCLE"]
			operation = "cycle"
		"balance_control":
			state_key = "balance_sides"
			target = [0,1,1]
			operation = "toggle"
		"secret_overlay":
			state_key = "overlay_offsets"
			target = [0,0]
		"secret_pop":
			state_key = "pop_folds"
			target = [1,2,1]
		_:
			if world.hud.panel_open: await emit_ui("puzzle_confirm", kind)
			await step(120)
			return true
	for index in range(target.size()):
		for attempt in range(8):
			var state: Array = world.progress.get(state_key, [])
			if state.size()<=index: return check(false, "Missing puzzle state " + state_key)
			if state[index] == target[index]: break
			await emit_ui("puzzle_choice", {"kind":kind,"action":operation,"index":index})
		if not check(world.progress.get(state_key, [])[index] == target[index], "Panel could not set " + state_key + " slot " + str(index)): return false
	await emit_ui("puzzle_confirm", kind)
	await step(150)
	if world.hud.panel_open: await emit_ui("close_panel")
	return true

func run_actions(name: String = "main") -> bool:
	var routes: Dictionary = world.data.get("qa_actions", {})
	if not check(routes.has(name), "Room %d lacks QA actions %s" % [world.current_room,name]): return false
	for action in routes[name]:
		current_goal = str(action)
		match str(action.get("type", "walk")):
			"walk":
				if not await walk_to(action.target): return false
			"jump":
				if not await jump_to(action.target): return false
			"drop":
				if not await drop_to(action.target): return false
			"interact":
				if not await interact_with(str(action.id)): return false
			"press_cross":
				if not await cross_press(str(action.id), action.target): return false
			"wait": await step(int(action.get("ticks",60)))
	return true

func cross_press(id: String, target: Vector2) -> bool:
	var hazard: Dictionary = {}
	for candidate in world.data.get("hazards",[]):
		if str(candidate.get("id",""))==id: hazard=candidate
	if not check(not hazard.is_empty(),"Missing press "+id): return false
	var y: float = hero.position.y
	if not await walk_to(Vector2(float(hazard.get("safe_wait_x",hazard.rect.position.x-80)),y)): return false
	var warning: float = float(hazard.get("telegraph",1.5))
	var active: float = float(hazard.get("active",0.85))
	var period: float = float(hazard.get("period",6.2))
	var offset: float = float(hazard.get("offset",hazard.get("phase_offset",0.0)))
	for tick in range(500):
		var phase: float = fposmod(world.elapsed+offset,period)
		if phase>=warning+active+0.1 and phase<warning+active+0.4: break
		await step(1)
	var hp_before: int = hero.hp
	var passed: bool = await walk_to(target)
	return check(passed and hero.hp==hp_before,"Press "+id+" did not permit a clean cooldown crossing")

func use_exit(target_room: int) -> bool:
	var definition: Dictionary = {}
	for candidate in world.data.get("exits", []):
		if int(candidate.target)==target_room:
			definition = candidate
			break
	if not check(not definition.is_empty(), "Room %d lacks exit to %d" % [world.current_room,target_room]): return false
	if not await walk_to(definition.pos): return false
	var origin: int = world.current_room
	await pulse("interact")
	for tick in range(160):
		await step(1)
		if world.current_room==target_room and not world.transitioning: break
	var passed: bool = world.current_room==target_room and not world.transitioning
	transitions.append({"from":origin,"to":target_room,"actual_interact":true,"passed":passed})
	if not check(passed, "Portal %d → %d failed" % [origin,target_room]): return false
	await step(12)
	return check(hero.is_on_floor(), "Portal arrival unsupported in " + str(target_room))

func make_world(restore: bool = false, preview: bool = true) -> bool:
	release_controls()
	if is_instance_valid(world):
		stop_audio(world)
		await process_frame
		world.queue_free()
		await process_frame
		await process_frame
	var scene: PackedScene = load(WORLD_PATH)
	if not check(scene != null, "M17 scene does not load"): return false
	world = scene.instantiate()
	world.environment_preview = preview
	world.restore_saved_game = restore
	world.transition_seconds = 0.001
	root.add_child(world)
	await step(35)
	hero = world.get("hero")
	return check(is_instance_valid(hero) and hero.is_on_floor(), "Initial hero has no support")

func fixture_room(id: int, spawn: String = "left", at: Vector2 = Vector2.INF) -> void:
	current_goal = "isolated fixture"
	release_controls()
	if world.hud.panel_open: await emit_ui("close_panel")
	world._load_room(id, spawn, at)
	await step(35)
	hero = world.hero

func save_restore_checks() -> void:
	var expected: Dictionary = world.progress.duplicate(true)
	var saved_checkpoint: Dictionary = world.checkpoint.duplicate(true)
	world._save()
	if not await make_world(true,true): return
	for key in ["weapon_owned","ink_route_solved","books_collected","book_order_verified","output_open","balance_bridge_locked","archive_return_open","workshop_main_passage_open","workshop_archive_return_open","guard_approach_return_open"]:
		check(world.progress.get(key,false)==expected.get(key,false),"Saved progress changed for "+key)
	check(world.progress.book_inventory==expected.book_inventory,"Reload changed collected books")
	check(world.progress.book_order==expected.book_order,"Reload changed table arrangement")
	check(int(world.checkpoint.room)==int(saved_checkpoint.room),"Reload changed saved bench room")
	check(world.current_room==int(saved_checkpoint.room) and hero.is_on_floor(),"Reload did not restore a supported bench")
	for flag in ["guard_clear","compiler_seal_owned","seal_registered","boss_defeated","world1_departed"]:
		check(not bool(world.progress.get(flag,false)),"Reload forged combat or departure fact "+flag)
	fixture_results.append({"kind":"actual_tour_save_reload","passed":true,"checkpoint_room":world.current_room})

func settings_restore_checks() -> void:
	world.hud.language = "ar"
	world._save()
	await emit_ui("language","en") # Changes preferences without checkpoint/progress save.
	if not await make_world(true,true): return
	check(world.hud.language=="en","Newer F2 language preference was overwritten by the older checkpoint language")
	var preferences: String = "user://folding_library_m17_settings.cfg"
	if FileAccess.file_exists(preferences): DirAccess.remove_absolute(preferences)
	if not await make_world(true,true): return
	check(world.hud.language=="ar","Absent settings did not fall back to the saved progress language")
	fixture_results.append({"kind":"newer_language_setting_precedence","passed":true})

func shortcut_checks() -> void:
	var pairs: Array = [[6,2,"archive_return"],[9,3,"lab_return"],[12,6,"archive"],[13,10,"balance_return"]]
	for pair in pairs:
		await fixture_room(int(pair[0]),str(pair[2]))
		var first: bool = await use_exit(int(pair[1]))
		var second: bool = await use_exit(int(pair[0])) if first else false
		fixture_results.append({"kind":"earned_shortcut_round_trip","from":pair[0],"to":pair[1],"configured_start":true,"actual_portal_inputs":true,"passed":first and second})

func optional_route_checks() -> void:
	for id in [6,9,11,12]:
		await fixture_room(id)
		var passed: bool = await run_actions("secret")
		if id==6 and passed and world.data.qa_actions.has("secret_return"):
			passed = await run_actions("secret_return")
		fixture_results.append({"kind":"optional_route","room":id,"configured_start":true,"actual_movement_and_ui":true,"passed":passed})

	for secret in ["S01","S02","S03","S04","S05","S06"]:
		check(world.progress.solved_secrets.has(secret),"Discovered secret was not registered: "+secret)
	check(world.progress.solved_secrets.size()==6,"Expected exactly six registered discoveries")

func negative_checks() -> void:
	if not await make_world(false,true): return
	for id in [2,3,6,9,10,12,13]:
		await fixture_room(id)
		for exit in world.data.get("exits",[]):
			if str(exit.id).begins_with("shortcut_"):
				check(not world.can_use_exit(exit),"Fresh preview bypassed shortcut "+str(exit.id))
	# Actual UI confirmation of a wrong answer stays harmless and preserves panel.
	await fixture_room(3,"left",Vector2(850,1260))
	await pulse("interact")
	var hp_before: int = hero.hp
	var coins_before: int = int(world.progress.credits)
	await emit_ui("puzzle_confirm","ink")
	check(world.hud.panel_open and world.hud.current_panel=="ink","Wrong ink answer dismissed the retry panel")
	check(not bool(world.progress.ink_route_solved) and not world.fold_active,"Wrong ink answer started or committed a fold")
	check(hero.hp==hp_before and int(world.progress.credits)==coins_before,"Wrong answer cost health or resources")
	var rotations_before: Array = world.progress.ink_rotations.duplicate()
	var old_language: String = world.hud.language
	await emit_ui("language","en" if old_language=="ar" else "ar")
	check(world.hud.panel_open and world.hud.current_panel=="ink" and world.progress.ink_rotations==rotations_before,"Language switch lost the active puzzle")
	await emit_ui("close_panel")
	check(world.gameplay_active,"Closing a puzzle did not resume play")
	for id in [8,9]:
		await fixture_room(id)
		var kind: String = "process_control" if id==8 else "output_control"
		for item in world.data.objects:
			if item.kind==kind:
				await fixture_room(id,"left",item.pos)
				await pulse("interact")
				break
		check(not bool(world.progress.book_order_verified) and not bool(world.progress.output_open),"Out-of-order book pipeline completed in room "+str(id))
	# Non-preview production eligibility must retain genuine future-combat requirements.
	if not await make_world(false,false): return
	await fixture_room(13,"left",Vector2(3020,1260))
	var checkpoint_before: Dictionary = world.checkpoint.duplicate(true)
	await pulse("interact")
	check(world.checkpoint==checkpoint_before,"Production bench13 activated without guard victory and earned seal")
	await fixture_room(13,"left",Vector2(2670,1260))
	await pulse("interact")
	check(not bool(world.progress.guard_clear) and not bool(world.progress.compiler_seal_owned) and not bool(world.progress.seal_registered),"Seal socket invented combat or seal progress")
	world.on_boss_defeated()
	world.register_encounter("guard_clear",[])
	check(not bool(world.progress.boss_defeated) and not bool(world.progress.guard_clear),"Unregistered or empty combat callback granted victory")
	for pair in [[2,3],[13,14],[14,15]]:
		await fixture_room(int(pair[0]))
		for exit in world.data.exits:
			if int(exit.target)==int(pair[1]):check(not world.can_use_exit(exit),"Production combat exit unexpectedly unlocked "+str(pair))
	await fixture_room(15,"left",Vector2(2670,1260))
	await pulse("interact")
	check(not world.hud.panel_open and not bool(world.progress.world1_departed),"Production threshold opened without boss victory")
	world.progress.boss_defeated = true # Explicit eligibility fixture, never a played victory.
	await pulse("interact")
	await emit_ui("depart_confirm")
	check(world.current_room==15 and not bool(world.progress.world1_departed),"Absent World2 destination committed a real departure")
	if world.hud.panel_open: await emit_ui("close_panel")

func fold_integration_checks() -> void:
	if not await make_world(false,true): return
	world.progress.books_collected = true
	world.progress.book_order_verified = true
	world.progress.book_inventory = ["TRIANGLE","SQUARE","CIRCLE"]
	await fixture_room(9)
	var regions: Array = world._fold_rectangles("output_open")
	if not check(not regions.is_empty(),"OUTPUT has no fold safety volumes"): return
	var region: Rect2 = regions[0]
	hero.position = region.get_center() # Deliberately unsafe isolated fixture.
	world._start_fold("output_open")
	await step(5)
	check(not world.fold_active and not bool(world.progress.output_open),"Occupied fold volume did not refuse safely")
	await fixture_room(9,"left",Vector2(750,1260))
	await pulse("interact")
	check(world.fold_active and not bool(world.progress.output_open),"OUTPUT committed before its animation settled")
	world._save() # Simulates a save request during motion; only committed state is serialized.
	if not await make_world(true,true): return
	check(not world.fold_active and not bool(world.progress.output_open),"Reload during a fold restored a partial or prematurely open page")
	await fixture_room(9,"left",Vector2(750,1260))
	await pulse("interact")
	await step(115)
	check(bool(world.progress.output_open) and not world.fold_active,"Safe OUTPUT fold did not settle and commit")
	var expected_surfaces: int = 0
	for surface in world.data.platforms:
		if str(surface.get("requires",""))=="output_open": expected_surfaces+=1
	var actual_surfaces: int = 0
	for child in world.surface_root.get_children():
		for surface in world.data.platforms:
			if str(surface.get("requires",""))=="output_open" and str(child.name)==str(surface.id): actual_surfaces+=1
	check(expected_surfaces>0 and actual_surfaces==expected_surfaces,"Settled OUTPUT collision geometry does not match the saved open state")
	world._save()
	if not await make_world(true,true): return
	check(bool(world.progress.output_open) and not world.fold_active,"Committed OUTPUT state failed reload")
	fixture_results.append({"kind":"fold_clearance_commit_reload","configured_actor_fixture":true,"passed":true})

func exit_checks() -> void:
	if not await make_world(false,true): return
	await fixture_room(15,"left",Vector2(2670,1260))
	await pulse("interact")
	check(world.hud.panel_open and world.hud.current_panel=="world_exit","Preview threshold did not request explicit confirmation")
	await emit_ui("close_panel")
	check(world.gameplay_active and not bool(world.progress.get("preview_departed",false)) and not world.tour_finished,"Cancelling departure prevented continued exploration")
	await pulse("interact")
	await emit_ui("depart_confirm")
	check(world.tour_finished and bool(world.progress.preview_departed),"Confirmed environment-preview departure did not finish the preview")
	check(not bool(world.progress.world1_departed) and not bool(world.progress.boss_defeated),"Preview completion forged a real departure or boss victory")
	await emit_ui("journal")
	check(world.hud.current_panel=="journal" and not world.gameplay_active,"Completion journal did not open safely")
	await emit_ui("close_panel")
	check(world.hud.current_panel=="completion" and not world.gameplay_active,"Closing completion journal did not return to the safe completion panel")
	await pulse("pause_game")
	check(world.tour_finished and not world.gameplay_active and world.hud.panel_open,"ESC re-entered World1 after preview completion")

func fixture_checks() -> void:
	for id in range(1,16):
		await fixture_room(id)
		var supported: bool = hero.is_on_floor()
		check(supported, "Room %d left spawn unsupported: %s" % [id,hero.position])
		fixture_results.append({"kind":"left_spawn","room":id,"configured_spawn":true,"passed":supported})
	await fixture_room(1)
	await pulse("jump")
	await step(3)
	await pulse("pause_game")
	var position_before: Vector2 = hero.position
	var velocity_before: Vector2 = hero.velocity
	await step(20)
	check(not world.gameplay_active and hero.position.distance_to(position_before)<0.1 and hero.velocity.is_equal_approx(velocity_before), "Pause did not preserve airborne position/velocity")
	await pulse("pause_game")
	await step(90)
	check(world.gameplay_active and hero.is_on_floor(), "Pause did not resume normally")
	await physical_key(KEY_N)
	check(world.hud.panel_open and world.hud.current_panel=="journal" and not world.gameplay_active,"The displayed physical N journal shortcut did not open the journal")
	await physical_key(KEY_ESCAPE)
	check(world.gameplay_active and not world.hud.panel_open,"Physical ESC did not close the journal and resume")

func walkthrough() -> void:
	if not await make_world(false,true): return
	var order: Array[int] = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]
	for index in range(order.size()):
		if not check(world.current_room==order[index], "Unexpected room in continuous route"): return
		print("M17 QA WALK ROOM ",world.current_room)
		if not await run_actions("main"): return
		rooms_walked.append(world.current_room)
		if index<order.size()-1:
			if world.current_room==4 and world.data.get("qa_actions",{}).has("to_optional"):
				if not await run_actions("to_optional"): return
			if not await use_exit(order[index+1]): return
		for flag in ["encounter_assignments_cleared","guard_clear","compiler_seal_owned","seal_registered","boss_defeated","world1_departed"]:
			if not check(not bool(world.progress.get(flag,false)), "Environment preview falsely awarded " + flag): return
	route_complete = true

func run_checks() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://"))
	for path in ["user://folding_library_m17.json","user://folding_library_m17_preview.json","user://folding_library_m17_settings.cfg"]:
		var existed: bool = FileAccess.file_exists(path)
		save_backups[path] = {"existed":existed,"contents":FileAccess.get_file_as_string(path) if existed else ""}
	if await make_world(false,true): await fixture_checks()
	await walkthrough()
	if route_complete:
		await save_restore_checks()
		await shortcut_checks()
		await optional_route_checks()
		await settings_restore_checks()
	await negative_checks()
	await fold_integration_checks()
	await exit_checks()
	release_controls()
	if is_instance_valid(world):
		stop_audio(world)
		await process_frame
		world.queue_free()
		await process_frame
		await process_frame
	for path in save_backups:
		if save_backups[path].existed:
			FileAccess.open(path,FileAccess.WRITE).store_string(save_backups[path].contents)
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var restored: bool = true
	for path in save_backups:
		var matched: bool = FileAccess.file_exists(path)==bool(save_backups[path].existed)
		if matched and bool(save_backups[path].existed): matched=FileAccess.get_file_as_string(path)==str(save_backups[path].contents)
		if not matched:
			restored=false
			check(false,"QA did not restore the original save/settings file "+str(path))
	var report := {"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"physics_ticks":physics_ticks,"rooms_walked":rooms_walked,"continuous_route_complete":route_complete,"landings":landings,"transitions":transitions,"isolated_fixtures":fixture_results,"save_restored":restored,"puzzle_input":"native UI action signals; movement/portals via Input actions","combat_implemented":false}
	FileAccess.open(REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M17 QA REPORT ",REPORT," checks=",checks," failures=",failures.size()," route_complete=",route_complete)
	OS.delay_msec(40)
	await process_frame
	quit(0 if failures.is_empty() and route_complete else 1)
