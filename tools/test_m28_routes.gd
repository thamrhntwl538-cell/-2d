extends SceneTree
## Independent native traversal checks. The starter route uses a fresh save and
## ordinary inputs. Later room checks explicitly configure an initial room and
## puzzle unlocks, then move the real M28 hero through authored geometry.
const WORLD := "res://scenes/stage_01/folding_library_m28.tscn"
const Layouts = preload("res://scripts/stage/m28_layouts.gd")
const Ledger = preload("res://scripts/combat/m22_currency_ledger.gd")
var world: Node2D
var hero: CharacterBody2D
var checks := 0
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var stage := "startup"
var ticks := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(stage+": "+message)
		print("M28 ROUTE FAIL ",stage,": ",message)
	return ok
func sample(kind: String, data: Dictionary) -> void:
	data.kind = kind
	data.stage = stage
	samples.append(data)
func step(count := 1) -> void:
	for _i in range(count):
		await physics_frame
		await process_frame
		ticks += 1
func release_all() -> void:
	for action in ["move_left","move_right","look_up","look_down","jump","dash","attack","spell","heal","interact","pause_game","stage_map","journal"]:
		if InputMap.has_action(action): Input.action_release(action)
func drive(x: float) -> void:
	var difference := x-hero.position.x
	var acceleration := 2650.0 if hero.is_on_floor() else 1950.0
	var braking := hero.velocity.x*hero.velocity.x/(2.0*acceleration)
	if absf(difference)<2.5 or (hero.velocity.x*difference>0 and absf(difference)<braking+2.5):
		Input.action_release("move_left"); Input.action_release("move_right")
	elif difference>0:
		Input.action_release("move_left"); Input.action_press("move_right")
	else:
		Input.action_release("move_right"); Input.action_press("move_left")
func walk(point: Vector2, limit := 1000) -> bool:
	for _tick in range(limit):
		drive(point.x)
		await step()
		if absf(hero.position.x-point.x)<6 and absf(hero.velocity.x)<4 and hero.is_on_floor() and absf(hero.position.y-point.y)<3:
			release_all()
			return true
	release_all()
	return check(false,"walk to %s stopped at %s" % [point,hero.position])
func pulse(action: String, held := 2) -> void:
	await step()
	Input.action_press(action)
	await step(held)
	Input.action_release(action)
	await step(3)
func jump(point: Vector2, with_dash := false) -> bool:
	var starting := hero.position
	var apex := starting.y
	var airborne := false
	var landed := false
	var dash_started := false
	Input.action_press("jump")
	for tick in range(160):
		drive(point.x)
		# Dash near the actual apex: early dashes cut off the rising velocity.
		if with_dash and not dash_started and airborne and hero.velocity.y>=-100:
			Input.action_press("dash")
			dash_started = true
		if tick>=30: Input.action_release("jump")
		await step()
		Input.action_release("dash")
		apex = minf(apex,hero.position.y)
		if not hero.is_on_floor(): airborne = true
		if airborne and hero.is_on_floor(): landed = true; break
	Input.action_release("jump")
	var correct := airborne and landed and absf(hero.position.y-point.y)<3
	sample("native_jump",{"room":world.current_room,"start":[starting.x,starting.y],"target":[point.x,point.y],"landing":[hero.position.x,hero.position.y],"apex_y":apex,"dash_requested":with_dash,"dash_started":dash_started,"actual_input":true,"passed":correct})
	if not check(correct,"%s to %s landed at %s" % ["jump+dash" if with_dash else "held jump",point,hero.position]):
		release_all()
		return false
	return await walk(point,250)
func drop(point: Vector2) -> bool:
	return await walk(point,400)
func interact(id: String) -> bool:
	var found := false
	for object in world.data.objects:
		if str(object.id)==id:
			found = true
			if not check(hero.position.distance_to(object.pos)<112,"interaction in reach: "+id): return false
	if not check(found,"interaction exists: "+id): return false
	await pulse("interact")
	if world.hud.panel_open:
		world.hud.action.emit("close_panel")
		await step(35)
	return true
func quiet_enemies() -> void:
	# Geometry fixtures exclude opponent AI. The fresh starter route below does
	# not invoke this helper and does not bypass the mandatory first larva.
	for actor in world.enemies:
		if is_instance_valid(actor): actor.process_mode=Node.PROCESS_MODE_DISABLED
func room_fixture(id: int, point: Vector2) -> void:
	release_all()
	world.gameplay_active=true
	world.paused=false
	world.transitioning=false
	world.progress.weapon_owned=true
	world.combat_state.dash_owned=true
	world.progress.ink_route_solved=true
	world.progress.output_open=true
	world.progress.balance_bridge_locked=true
	world._load_room(id,"left",point)
	hero=world.hero
	hero.hp=6
	hero.energy=99
	quiet_enemies()
	await step(5)
	check(hero.is_on_floor() and absf(hero.position.y-point.y)<3,"configured route starts on a real collision surface: %s" % point)

func fresh_starter() -> void:
	stage="fresh starter route without progression injection"
	check(world.current_room==1 and not hero.has_blade and not world.combat_state.dash_owned,"fresh world begins in first page without blade or dash")
	if not await walk(Vector2(330,1260)): return
	if not await interact("bench_1"): return
	if not await walk(Vector2(445,1260)): return
	if not await interact("first_wick"): return
	if not await walk(Vector2(650,1260)): return
	if not await interact("weapon_pickup"): return
	check(hero.has_blade and bool(world.progress.get("weapon_owned",false)),"ordinary interaction acquires the permanent blade")
	if not await walk(Vector2(795,1260)): return
	if not await jump(Vector2(885,1178)): return
	if not await drop(Vector2(978,1260)): return
	if not await jump(Vector2(1080,1140)): return
	if not await walk(Vector2(1180,1140)): return
	if not await interact("entrance_note"): return
	if not await drop(Vector2(1430,1260)): return
	if not await walk(Vector2(1500,1260)): return
	if not await interact("lantern_dash"): return
	check(hero.has_dash and world.combat_state.dash_owned,"ordinary interaction learns the exploration dash")
	if not await walk(Vector2(1936,1260)): return
	if not await jump(Vector2(2040,1140)): return
	if not await walk(Vector2(2180,1140)): return
	if not await jump(Vector2(2350,1020)): return
	if not await walk(Vector2(2690,1020)): return
	await pulse("interact")
	await step(45)
	check(world.current_room==2 and hero.is_on_floor(),"ordinary exit interaction transitions from fresh room1 to supported room2")
	check(not bool(world.progress.get("encounter_assignments_cleared",false)),"starter proof does not forge a victory against the mandatory first larva")
	sample("fresh_starter",{"room":world.current_room,"hp":hero.hp,"dash_owned":world.combat_state.dash_owned,"blade_owned":hero.has_blade,"actual_input":true,"combat_bypass":false})

func room_setup_matrix() -> void:
	stage="configured fifteen-room scene/support matrix"
	var rooms: Array=Layouts.all_rooms()
	check(rooms.size()==15,"approved fifteen-room count remains intact")
	for definition in rooms:
		var id:=int(definition.id)
		for exit in definition.exits:
			var target:=int(exit.target)
			check(target>=1 and target<=16,"room %d exit %s has a valid destination" % [id,exit.id])
		for platform in definition.platforms:
			var rectangle: Rect2=platform.rect
			check(rectangle.size.x>0 and rectangle.size.y>0,"room %d platform %s has positive collision dimensions" % [id,platform.id])
		var point: Vector2=definition.spawns.get("left",definition.spawns.get("default",Vector2(180,float(definition.floor_y))))
		await room_fixture(id,point)
		await step(15)
		check(world.current_room==id and is_instance_valid(world.active_room) and is_instance_valid(world.visuals),"room %d builds native scene/renderer" % id)
		check(hero.is_on_floor() and hero.position.y<float(definition.size.y),"room %d left entrance has real collision support" % id)
		sample("room_setup",{"room":id,"spawn":[point.x,point.y],"supported":[hero.position.x,hero.position.y],"platform_nodes":world.surface_root.get_child_count(),"objects":world.objects.size(),"fixture":true})

func authored_challenges() -> void:
	for definition in Layouts.all_rooms():
		for identity in definition.m28_routes:
			stage="authored route "+str(identity)
			var route: Dictionary=definition.m28_routes[identity]
			# Initial room/puzzle unlocks are explicit fixtures. No input action
			# teleports the hero or calls a plate/relay completion callback.
			if str(identity)=="relay_return_stair": world.progress.m28_counterweight_relay_solved=true
			await room_fixture(int(definition.id),route.start)
			var good:=true
			for action in route.actions:
				match str(action.type):
					"walk": good=await walk(action.target)
					"jump": good=await jump(action.target)
					"jump_dash": good=await jump(action.target,true)
					"drop": good=await drop(action.target)
					"wait": await step(int(action.get("ticks",24)))
				if not good: break
			check(good,"all authored actions finish through real native hero motion")
			if str(identity)=="output_dash_latch":
				check(bool(world.progress.get("m28_output_span_open",false)),"standing on the far plate unfolds the physical return bridge")
				var bridge: Node=world.surface_root.get_node_or_null("m28_output_return_bridge")
				check(is_instance_valid(bridge),"return bridge has a real collision body after plate completion")
				var before:=Ledger.room_pending(world.progress,9).size()
				await step(60)
				check(Ledger.room_pending(world.progress,9).size()<=before,"holding a solved plate cannot duplicate reward coins")
			if str(identity)=="counterweight_relay":
				check(bool(world.progress.get("m28_counterweight_relay_solved",false)),"I, III, II pressure-seal route completes through foot contact")
			if str(identity)=="corrector_last_spine":
				check(bool(world.progress.get("m28_corrector_shelf_found",false)),"landing and standing on the tallest spine earns its exploration receipt")
			sample("authored_route",{"room":int(definition.id),"id":identity,"passed":good,"final":[hero.position.x,hero.position.y],"hp":hero.hp,"fixture_start":true,"actual_input":true})

func new_rest_support() -> void:
	stage="new market and vault rest checkpoints"
	for id in [4,6]:
		var definition: Dictionary=Layouts.room(id)
		for item in definition.objects:
			if str(item.id) not in ["m28_market_bench","m28_vault_bench"]: continue
			var point: Vector2=item.pos+Vector2(64,0)
			await room_fixture(id,item.pos)
			await interact(str(item.id))
			check(int(world.checkpoint.room)==id and absf(float(world.checkpoint.position[0])-point.x)<1,"new rest writes its physically clear native checkpoint: "+str(item.id))
			await room_fixture(id,point)
			check(hero.is_on_floor() and absf(hero.position.y-point.y)<3,"new rest checkpoint remains on a real surface: "+str(item.id))
			sample("new_rest_checkpoint",{"room":id,"id":item.id,"point":[point.x,point.y],"supported":hero.is_on_floor(),"fixture_start":true,"actual_interaction":true})
	# The vault rest sits on the archive's existing solid book stack, clear of
	# both the shortcut door and the vault's interaction radius.
	await room_fixture(6,Vector2(2280,1980))
	var reached:=await jump(Vector2(2440,1860))
	if reached: reached=await walk(Vector2(2460,1860))
	if reached: reached=await interact("m28_vault_bench")
	if reached: check(absf(float(world.checkpoint.position[0])-2524)<1 and absf(float(world.checkpoint.position[1])-1860)<1,"vault landing rest records its clear upper-stack checkpoint")
	if reached: reached=await walk(Vector2(2550,1860))
	if reached: reached=await drop(Vector2(2630,1980))
	if reached: reached=await walk(Vector2(2710,1980))
	check(reached,"the outside vault rest reaches its physical boss doorway by a held book-stack jump")
	sample("vault_rest_to_door",{"passed":reached,"start":[2280,1980],"rest_checkpoint":[2524,1860],"final":[hero.position.x,hero.position.y],"fixture_start":true,"actual_input":true,"portal_entered":false})

func pause_probe() -> void:
	stage="physical pressure mechanism pause"
	world.progress.erase("m28_output_span_open")
	await room_fixture(9,Vector2(2910,780))
	world._set_paused(true)
	await step(40)
	check(not bool(world.progress.get("m28_output_span_open",false)),"a paused hero cannot finish a pressure plate")
	world._set_paused(false)
	await step(30)
	check(bool(world.progress.get("m28_output_span_open",false)),"physical plate resumes normally after explicit unpause")

func cleanup() -> void:
	release_all()
	world.gameplay_active=false
	world.set_physics_process(false)
	world.hero.set_physics_process(false)
	if is_instance_valid(world.music): world.music.stop()
	if is_instance_valid(world.boss_music): world.boss_music.stop_fight()
	if is_instance_valid(world.soundscape) and world.soundscape.has_method("stop_all"): world.soundscape.stop_all()
	OS.delay_msec(180)
	world.queue_free()
	await step(8)
func run() -> void:
	var packed: PackedScene=load(WORLD)
	if not check(packed!=null,"M28 world scene compiles"): quit(1); return
	world=packed.instantiate()
	var controller: Script=world.get_script()
	if not check(controller!=null and controller.can_instantiate(),"M28 world dependencies are compiled before physics fixtures"):
		world.free(); quit(1); return
	world.restore_saved_game=false
	world.transition_seconds=.001
	root.add_child(world)
	await step(45)
	hero=world.hero
	await fresh_starter()
	await room_setup_matrix()
	await new_rest_support()
	await authored_challenges()
	await pause_probe()
	await cleanup()
	var report: Dictionary={"engine":Engine.get_version_info().string,"checks":checks,"passed":checks-failures.size(),"failures":failures,"physics_ticks":ticks,"samples":samples,"scope":"Fresh actual-input first-room acquisition and exit. Remaining rooms/challenge starts are labelled configured fixtures with puzzle gates opened for geometry checks; no full campaign win or human difficulty claim.","rendering":DisplayServer.get_name()}
	var file:=FileAccess.open("user://m28_route_qa.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("M28 ROUTE QA: %d/%d passed" % [checks-failures.size(),checks])
	quit(0 if failures.is_empty() else 1)
