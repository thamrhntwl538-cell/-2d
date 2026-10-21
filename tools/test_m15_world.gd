extends SceneTree
## Native-engine traversal QA. The main tour uses actual input and visible room
## portals only. Checkpoint-position fixtures below are isolated negative tests.
const STAGE = preload("res://scenes/stage_01/forgotten_wing.tscn")
const SAVE_FILE := "user://forgotten_wing_m15.json"
var world: Node2D
var hero: CharacterBody2D
var failures: Array[String] = []
var landings: Array[Dictionary] = []
var transitions: Array[Dictionary] = []
var lift_rides: Array[Dictionary] = []
var fixtures: Array[Dictionary] = []
var room_order: Array[int] = []
var physics_ticks: int = 0
var tour_ticks: int = 0
var touring: bool = false
var camera_samples: int = 0
var camera_bounds_valid: bool = true
var maximum_camera_step: float = 0.0
var last_camera_room: int = -1
var last_camera_position := Vector2.ZERO
var previous_save: String = ""
var had_save: bool = false
var complete_tour: bool = false
var restore_checks: int = 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> bool:
	if not condition and not failures.has(message):
		failures.append(message)
		print("M15 QA FAILURE: ", message)
	return condition

func release_controls() -> void:
	for action in ["move_left","move_right","jump","interact","pause_game","stage_map","dash"]:
		if InputMap.has_action(action): Input.action_release(action)

func step(count: int) -> void:
	for i in range(count):
		await physics_frame
		physics_ticks += 1
		if touring and is_instance_valid(world):
			tour_ticks += 1
			if not world.transitioning:
				var camera: Camera2D = world.camera
				var position_value: Vector2 = camera.position
				var half_view: Vector2 = root.get_visible_rect().size / camera.zoom / 2.0
				var bounds: Rect2 = camera.room_rect
				camera_bounds_valid = camera_bounds_valid and position_value.x-half_view.x >= bounds.position.x-0.5 and position_value.y-half_view.y >= bounds.position.y-0.5 and position_value.x+half_view.x <= bounds.end.x+0.5 and position_value.y+half_view.y <= bounds.end.y+0.5
				if last_camera_room == world.current_room:
					maximum_camera_step = maxf(maximum_camera_step,position_value.distance_to(last_camera_position))
				last_camera_room = world.current_room
				last_camera_position = position_value
				camera_samples += 1

func pulse(action: String) -> void:
	await physics_frame
	Input.action_press(action)
	await step(3)
	Input.action_release(action)
	await step(3)

func drive_toward(target_x: float) -> void:
	var error: float = target_x-hero.position.x
	var acceleration: float = 2650.0 if hero.is_on_floor() else 1950.0
	var braking: float = hero.velocity.x*hero.velocity.x/(2.0*acceleration)
	if absf(error)<3.0 or (hero.velocity.x*error>0.0 and absf(error)<braking+3.0):
		Input.action_release("move_left")
		Input.action_release("move_right")
	elif error>0.0:
		Input.action_release("move_left")
		Input.action_press("move_right")
	else:
		Input.action_release("move_right")
		Input.action_press("move_left")

func walk_to(target_x: float, maximum_ticks: int = 1100) -> bool:
	for i in range(maximum_ticks):
		drive_toward(target_x)
		await step(1)
		if absf(hero.position.x-target_x)<=6.0 and absf(hero.velocity.x)<3.0 and hero.is_on_floor():
			release_controls()
			return true
	release_controls()
	return check(false,"Room %d cannot walk to %.1f, stopped at %s" % [world.current_room,target_x,hero.position])

func jump_to(target_x: float, target_y: float, label: String) -> bool:
	var start: Vector2 = hero.position
	var airborne: bool = false
	var landed: bool = false
	var landing: Vector2 = hero.position
	var apex: float = hero.position.y
	await physics_frame
	Input.action_press("jump")
	for i in range(120):
		drive_toward(target_x)
		await step(1)
		if i==2: Input.action_release("jump")
		apex = minf(apex,hero.position.y)
		if not hero.is_on_floor(): airborne = true
		if airborne and hero.is_on_floor():
			landing = hero.position
			landed = true
			break
	Input.action_release("jump")
	var correct: bool = airborne and landed and absf(landing.y-target_y)<2.0
	check(correct,"Room %d %s landed at %s, expected y=%.1f" % [world.current_room,label,landing,target_y])
	if correct: correct = await walk_to(target_x,150)
	else: release_controls()
	landings.append({"room":world.current_room,"name":label,"start":[start.x,start.y],"landing":[landing.x,landing.y],"target":[target_x,target_y],"apex_y":apex,"passed":correct,"actual_input":true})
	return correct

func stop_audio(node: Node) -> void:
	for child in node.get_children(): stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null

func instantiate_stage(restore: bool = false, preview: bool = true, fixture_room: int = -1, fixture_position := Vector2.ZERO) -> bool:
	release_controls()
	if is_instance_valid(world):
		stop_audio(world)
		world.queue_free()
		await process_frame
		await process_frame
	world = STAGE.instantiate()
	world.environment_preview = preview
	world.restore_saved_game = restore
	world.transition_seconds = 0.001
	if fixture_room>=0:
		world.checkpoint = {"room":fixture_room,"position":[fixture_position.x,fixture_position.y]}
	root.add_child(world)
	if world.get("hero")==null: return check(false,"Stage did not construct a hero; inspect engine startup errors")
	hero = world.hero
	await step(50)
	return check(hero.is_on_floor(),"Stage spawn lacks floor support in room %d at %s" % [world.current_room,hero.position])

func exit_definition(exit_id: String) -> Dictionary:
	for exit in world.data.exits:
		if exit.id==exit_id: return exit
	return {}

func use_portal(exit_id: String, expected_room: int) -> bool:
	var definition: Dictionary = exit_definition(exit_id)
	if not check(not definition.is_empty(),"Missing portal "+exit_id): return false
	if not await walk_to(definition.pos.x): return false
	if not check(hero.position.distance_to(definition.pos)<103.0,"Portal "+exit_id+" is not at a reachable elevation"): return false
	var from_room: int = world.current_room
	var bypass: bool = not world.requirement_met(definition.get("requires","")) and bool(definition.get("preview_bypass",false))
	await pulse("interact")
	for i in range(120):
		await step(1)
		if expected_room<0 and world.tour_finished and not world.transitioning: break
		if expected_room>=0 and world.current_room==expected_room and not world.transitioning: break
	var arrived: bool = world.tour_finished if expected_room<0 else world.current_room==expected_room
	check(arrived and not world.transitioning,"Portal "+exit_id+" did not finish its room transition")
	transitions.append({"from":from_room,"to":expected_room,"portal":exit_id,"preview_bypass":bypass,"passed":arrived,"actual_interact_input":true})
	if arrived and expected_room>=0:
		await step(15)
		check(hero.is_on_floor(),"Portal arrival is not supported on the floor in room %d" % expected_room)
		if room_order.is_empty() or room_order[-1]!=expected_room: room_order.append(expected_room)
		print("M15 QA ROOM ",expected_room," ",world.data.title," position=",hero.position)
	return arrived

func wait_for_lift(stop_index: int) -> bool:
	for i in range(1100):
		await step(1)
		if not world.elevator.moving and world.elevator.current_stop==stop_index:
			await step(12)
			return true
	return check(false,"Archive lift did not arrive at stop %d" % stop_index)

func ride_lift(stop_index: int, pause_midway: bool = false) -> bool:
	if not await walk_to(1125.0): return false
	var start: Vector2 = hero.position
	var support_samples: int = 0
	var ride_samples: int = 0
	var maximum_gap: float = 0.0
	await pulse("interact")
	if not check(world.elevator.moving,"Lift interaction did not start an actual ride"): return false
	for i in range(1100):
		await step(1)
		ride_samples += 1
		if hero.is_on_floor(): support_samples += 1
		maximum_gap = maxf(maximum_gap,absf(hero.position.y-world.elevator.position.y))
		if pause_midway and i==65:
			await pulse("pause_game")
			var paused_actor: Vector2 = hero.position
			var paused_lift: Vector2 = world.elevator.position
			await step(30)
			check(not world.gameplay_active and hero.position.distance_to(paused_actor)<0.1 and world.elevator.position.distance_to(paused_lift)<0.1,"Actor or archive lift moved while paused")
			await pulse("pause_game")
		if not world.elevator.moving: break
	await step(12)
	var expected_y: float = [2700.0,1980.0,1260.0,660.0][stop_index]
	var passed: bool = world.elevator.current_stop==stop_index and not world.elevator.moving and absf(hero.position.y-expected_y)<2.0 and hero.is_on_floor() and maximum_gap<14.0
	check(passed,"Native lift failed to carry its rider to stop %d; hero=%s lift=%s max_gap=%.2f" % [stop_index,hero.position,world.elevator.position,maximum_gap])
	lift_rides.append({"stop":stop_index,"start_y":start.y,"end_y":hero.position.y,"height_gain":start.y-hero.position.y,"support_samples":support_samples,"samples":ride_samples,"maximum_rider_gap":maximum_gap,"paused_midway":pause_midway,"passed":passed,"actor_position_injected":false})
	print("M15 QA LIFT stop=",stop_index," hero_y=",hero.position.y," passed=",passed)
	return passed

func puzzle_step(key: String, x: float) -> bool:
	if not await walk_to(x): return false
	check(not world.progress.get(key,false),"Puzzle "+key+" was already completed before its input")
	await pulse("interact")
	if not check(bool(world.progress.get(key,false)),"Puzzle "+key+" did not respond to actual interact input"): return false
	check(not world.reactions.is_empty() and world.reactions[0].active,"Puzzle "+key+" has no environmental reaction")
	check(not world.gates[0].node.get_node("Barrier/Collision").disabled,"Puzzle "+key+" gate collision disappeared before its opening animation")
	await step(115)
	check(world.gates[0].node.get_node("Barrier/Collision").disabled,"Puzzle "+key+" failed to clear its physical gate")
	print("M15 QA PUZZLE ",key," activated")
	return true

func isolated_checks() -> void:
	print("M15 QA ISOLATED FIXTURES — not part of traversed route")
	for item in [[5,Vector2(1310,1260),"process"],[6,Vector2(1210,1260),"output"]]:
		await instantiate_stage(false,true,int(item[0]),item[1])
		await pulse("interact")
		var denied: bool = not bool(world.progress.get(item[2],false)) and not world.progress.puzzle_complete and not world.gates[0].node.get_node("Barrier/Collision").disabled
		check(denied,"Fresh out-of-order "+str(item[2])+" completed the puzzle")
		fixtures.append({"purpose":"out_of_order_"+str(item[2]),"configured_room":item[0],"configured_spawn":true,"passed":denied})
	for item in [[1,Vector2(2320,1260),2400.0,"assignments"],[7,Vector2(2740,1260),2820.0,"compiler_seal"],[8,Vector2(3690,1620),3770.0,"boss_defeated"]]:
		await instantiate_stage(false,false,int(item[0]),item[1])
		Input.action_press("move_right")
		await step(70)
		Input.action_release("move_right")
		await step(10)
		var blocked: bool = absf(hero.position.x-float(item[2]))<2.0 and not world.gates[0].node.get_node("Barrier/Collision").disabled
		check(blocked,"Production-only "+str(item[3])+" gate failed its real-collider probe")
		if int(item[0])==7:
			await pulse("interact")
			check(not world.progress.compiler_seal,"Seal socket granted a key without an encounter")
		fixtures.append({"purpose":"production_gate_"+str(item[3]),"configured_room":item[0],"configured_spawn":true,"stopped_x":hero.position.x,"passed":blocked})
	for action in ["pause_game","stage_map"]:
		await instantiate_stage(false,true,0,Vector2(440,1260))
		await pulse("jump")
		await step(4)
		var rising_velocity: Vector2 = hero.velocity
		await pulse(action)
		var paused_position: Vector2 = hero.position
		var paused_velocity: Vector2 = hero.velocity
		await step(30)
		var preserved: bool = not world.gameplay_active and hero.position.distance_to(paused_position)<0.1 and hero.velocity.is_equal_approx(paused_velocity) and paused_velocity.y < -200.0 and absf(paused_velocity.y-rising_velocity.y)<80.0
		check(preserved,"Airborne "+action+" did not preserve actor position and momentum")
		await pulse(action)
		check(world.gameplay_active and hero.velocity.y < -100.0 and hero.position.y<paused_position.y,"Airborne "+action+" did not resume its upward motion")
		await step(90)
		check(hero.is_on_floor(),"Airborne "+action+" did not return safely to the floor")
		fixtures.append({"purpose":"airborne_"+action,"configured_room":0,"configured_spawn":true,"velocity_before_pause":[rising_velocity.x,rising_velocity.y],"velocity_frozen":[paused_velocity.x,paused_velocity.y],"passed":preserved,"uses_real_input":true})

func full_tour() -> bool:
	print("M15 QA CONTINUOUS ACTUAL-INPUT TOUR START")
	if not await instantiate_stage(): return false
	room_order.append(0)
	touring = true
	check(hero.get_node("StableGameplayCollider").shape.size==Vector2(30,58),"M13 collider changed")
	check(hero.lantern_sprite.scale.is_equal_approx(Vector2(0.4,0.4)),"M13 actor art scale changed")
	if not await walk_to(350): return false
	await pulse("interact")
	check(FileAccess.file_exists(SAVE_FILE),"Opening bench failed to create a dedicated M15 save")
	await pulse("stage_map")
	check(world.map_panel.visible and not world.gameplay_active,"Map input did not pause traversal")
	var mapped_position: Vector2 = hero.position
	Input.action_press("move_right")
	await step(24)
	Input.action_release("move_right")
	check(hero.position.distance_to(mapped_position)<0.1,"Actor moved while viewing the map")
	await pulse("stage_map")
	check(not world.map_panel.visible and world.gameplay_active,"Map did not resume traversal")
	if not await walk_to(650): return false
	if not await jump_to(800,1140,"entrance_first_ledge"): return false
	if not await walk_to(880): return false
	if not await jump_to(1080,1020,"entrance_second_ledge"): return false
	if not await walk_to(1170): return false
	if not await jump_to(1375,900,"entrance_third_ledge"): return false
	if not await walk_to(1460): return false
	if not await jump_to(1665,780,"entrance_upper_stair"): return false
	if not await walk_to(1810): return false
	if not await jump_to(2010,780,"entrance_gallery_gap"): return false
	if not await walk_to(2475): return false
	await pulse("interact")
	check(world.progress.entrance_access,"Opening access relay did not unlock through input")
	if not await use_portal("to_assignments",1): return false
	if not await walk_to(490): return false
	if not await jump_to(640,1140,"assignments_pedestal"): return false
	if not await use_portal("to_laboratory",2): return false
	if not await walk_to(910): return false
	if not await jump_to(1060,1140,"laboratory_west_pedestal"): return false
	if not await walk_to(1160): return false
	if not await jump_to(1380,1020,"laboratory_suspended_bridge"): return false
	if not await walk_to(1460): return false
	var laboratory_drop_start: Vector2 = hero.position
	if not await walk_to(1660): return false
	if not check(absf(hero.position.y-1140.0)<2.0,"Lab bridge walk-off did not reach its lower east landing"): return false
	landings.append({"room":2,"name":"laboratory_east_walk_off_landing","start":[laboratory_drop_start.x,laboratory_drop_start.y],"landing":[hero.position.x,hero.position.y],"target":[1660,1140],"passed":true,"actual_input":true,"walk_off":true})
	if not await walk_to(1880): return false
	if not await use_portal("to_archive",3): return false
	if not await ride_lift(1,true): return false
	if not await walk_to(1015): return false
	if not await jump_to(800,1980,"archive_lower_west_balcony"): return false
	if not await walk_to(720): return false
	await pulse("interact")
	check(world.progress.archive_shortcut,"Archive lever did not open its shortcut")
	if not await use_portal("assignment_shortcut",1): return false
	if not await use_portal("archive_shortcut",3): return false
	if not await walk_to(820): return false
	await pulse("interact")
	if not await wait_for_lift(1): return false
	if not await jump_to(1010,1980,"archive_return_to_called_lift"): return false
	if not await ride_lift(2): return false
	if not await walk_to(1235): return false
	if not await jump_to(1450,1260,"archive_middle_east_balcony"): return false
	if not await walk_to(1830): return false
	Input.action_press("move_right")
	await step(24)
	Input.action_release("move_right")
	await step(10)
	check(absf(hero.position.x-1850.0)<2.0,"Closed archive shelf did not physically block its passage")
	await pulse("interact")
	check(world.progress.archive_secret,"Shelf passage lever could not be reached")
	await step(70)
	check(world.gates[0].node.get_node("Barrier/Collision").disabled,"Archive shelf failed to release its passage collider")
	if not await walk_to(2050): return false
	await pulse("interact")
	check(world.progress.notes.has("archive_hidden_note"),"Opened shelf passage did not lead to its hidden note")
	if not await walk_to(1435): return false
	if not await jump_to(1245,1260,"archive_return_from_shelf_passage"): return false
	if not await ride_lift(3): return false
	if not await walk_to(1235): return false
	if not await jump_to(1450,660,"archive_upper_east_balcony"): return false
	if not await use_portal("to_input",4): return false
	if not await puzzle_step("input",780): return false
	check(not world.progress.process and not world.progress.output,"INPUT skipped later puzzle stages")
	if not await use_portal("to_process",5): return false
	if not await puzzle_step("process",1310): return false
	check(not world.progress.output,"PROCESS skipped the OUTPUT stage")
	if not await use_portal("to_output",6): return false
	if not await puzzle_step("output",1210): return false
	check(world.progress.puzzle_complete,"OUTPUT did not complete the ordered programming sequence")
	# Traverse the second shortcut in both directions through actual upper ledges.
	if not await walk_to(410): return false
	if not await jump_to(260,1140,"output_first_stair_from_east"): return false
	if not await walk_to(330): return false
	if not await jump_to(550,1020,"output_upper_stair"): return false
	if not await walk_to(630): return false
	if not await jump_to(850,900,"output_west_gallery"): return false
	if not await walk_to(1050): return false
	if not await jump_to(1240,900,"output_gallery_link"): return false
	if not await walk_to(1390): return false
	if not await jump_to(1590,900,"output_shortcut_gallery"): return false
	if not await use_portal("laboratory_shortcut",2): return false
	if not await use_portal("output_shortcut",6): return false
	if not await use_portal("to_approach",7): return false
	if not await walk_to(350): return false
	await pulse("interact")
	check(int(world.checkpoint.room)==7,"Approach bench did not save a safe checkpoint")
	if not await walk_to(610): return false
	if not await jump_to(760,1140,"approach_scholar_pedestal"): return false
	if not await walk_to(2850): return false
	await pulse("interact")
	check(not world.progress.compiler_seal,"Preview seal socket awarded a combat item")
	if not await use_portal("to_tribunal",8): return false
	if not await walk_to(2100): return false
	var before_reaction_hp: int = hero.hp
	await pulse("interact")
	check(world.progress.get("arena_charged",false),"Tribunal core input did not activate its environment preview")
	check(not world.reactions.is_empty() and world.reactions[0].mode=="phase2","Tribunal did not show its phase-two environment reaction")
	await step(90)
	check(hero.hp==before_reaction_hp,"Decorative arena preview caused combat damage")
	if not await use_portal("to_aftermath",9): return false
	if not await walk_to(1100): return false
	await pulse("interact")
	check(world.progress.notes.has("aftermath_note"),"Aftermath note did not persist its environmental story")
	if not await use_portal("stage_02_threshold",-1): return false
	check(world.tour_finished,"Environment tour did not reach the final threshold")
	return true

func check_combat_untouched(label: String) -> void:
	check(not world.progress.compiler_seal,label+": preview fabricated the Compiler Seal")
	check(not world.progress.boss_defeated,label+": preview fabricated boss victory")
	check(world.progress.encounters.is_empty(),label+": preview fabricated encounter clearance")
	check(not hero.has_blade and not hero.has_code_slash,label+": environment tour granted a combat ability")

func persistence_checks() -> void:
	var saved_before: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_FILE))
	if not check(saved_before is Dictionary,"M15 save is not valid JSON"): return
	for pass_index in range(2):
		await instantiate_stage(true)
		check(world.current_room==7 and hero.position.distance_to(Vector2(435,1260))<2.0,"Restore %d did not place the player beside the safe approach bench" % (pass_index+1))
		for flag in ["entrance_access","input","process","output","puzzle_complete","archive_shortcut","archive_secret","arena_charged"]:
			check(bool(world.progress.get(flag,false)),"Restore %d lost progression flag %s" % [pass_index+1,flag])
		check(world.progress.notes.has("aftermath_note") and world.progress.notes.has("archive_hidden_note"),"Restore lost an environmental note")
		check(world.progress.visited.size()==10,"Restore lost room visit history: "+str(world.progress.visited))
		check_combat_untouched("Restore %d" % (pass_index+1))
		var saved_after: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_FILE))
		check(saved_after is Dictionary and saved_after.progress==saved_before.progress,"Restore %d rewrote persisted world progress" % (pass_index+1))
		restore_checks += 1

func finish() -> void:
	touring = false
	release_controls()
	var report := {"passed":failures.is_empty(),"godot":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),"headless":DisplayServer.get_name()=="headless","scene":"res://scenes/stage_01/forgotten_wing.tscn","physics_ticks":physics_ticks,"actual_input_tour_ticks":tour_ticks,"continuous_tour_complete":complete_tour,"room_order":room_order,"mandatory_tour_test_teleports":0,"mandatory_tour_progress_injections":0,"uses_dash":false,"transitions":transitions,"landings":landings,"lift_rides":lift_rides,"isolated_fixtures":fixtures,"checkpoint_restore_passes":restore_checks,"camera":{"samples":camera_samples,"bounds_valid":camera_bounds_valid,"max_step_px":maximum_camera_step},"combat_claims":{"encounter_clearance_tested":false,"compiler_seal_earned":false,"boss_fight_tested":false,"boss_victory_awarded":false,"environment_preview_bypasses_are_explicit":true},"failures":failures,"limitations":["This test runs the native headless engine and does not produce rendered image evidence; room art is reviewed separately in a rendered Godot run.","Enemy and boss combat remain deferred. Explicit environment preview permits their future gates without awarding a seal, defeat, or victory.","Reported engine version is the actual executable used; no unexecuted Godot 4.7 validation is claimed."]}
	FileAccess.open("res://M15_ENVIRONMENT_QA.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M15 WORLD ","PASS" if failures.is_empty() else "FAIL"," ticks=",physics_ticks," rooms=",room_order," failures=",JSON.stringify(failures))
	if is_instance_valid(world):
		stop_audio(world)
		world.queue_free()
	await process_frame
	await process_frame
	# Fixed-fps headless execution can finish before the real-time audio mixer
	# retires its last playback reference. This is shutdown cleanup, not gameplay.
	OS.delay_msec(120)
	if had_save: FileAccess.open(SAVE_FILE,FileAccess.WRITE).store_string(previous_save)
	elif FileAccess.file_exists(SAVE_FILE): DirAccess.remove_absolute(SAVE_FILE)
	quit(0 if failures.is_empty() else 1)

func run_checks() -> void:
	had_save = FileAccess.file_exists(SAVE_FILE)
	if had_save:
		previous_save = FileAccess.get_file_as_string(SAVE_FILE)
		DirAccess.remove_absolute(SAVE_FILE)
	await isolated_checks()
	complete_tour = await full_tour()
	touring = false
	check(complete_tour,"Continuous actual-input tour did not finish")
	check(camera_bounds_valid,"Camera exposed a viewport outside its room bounds")
	check(maximum_camera_step<20.0,"Camera made an abrupt step during normal traversal: %.2fpx" % maximum_camera_step)
	if complete_tour:
		check(world.progress.visited.size()==10,"Tour did not visit all ten rooms")
		check_combat_untouched("Continuous tour")
		await persistence_checks()
	await finish()
