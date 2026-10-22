extends SceneTree
## Native M18 combat QA. Fixture placement/configuration is labelled explicitly;
## positive sword, jump, dash, focus and cast behavior uses ordinary Input actions.
const WORLD_PATH := "res://scenes/stage_01/folding_library_m18.tscn"
const REPORT := "user://m18_combat_report.json"
var world: Node2D
var hero: CharacterBody2D
var checks: int = 0
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var physics_ticks: int = 0
var user_backups: Dictionary = {}
var original_user_files: Array[String] = []
var phase: String = "startup"
var opening_route_complete: bool = false
var route_jumps: int = 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> bool:
	checks += 1
	if not value:
		var labelled: String = phase + ": " + message
		if not failures.has(labelled): failures.append(labelled)
		print("M18 QA FAIL ", labelled)
	return value

func sample(kind: String, value: Dictionary) -> void:
	value["kind"] = kind
	value["phase"] = phase
	value["physics_tick"] = physics_ticks
	samples.append(value)

func step(count: int) -> void:
	for tick in range(count):
		await physics_frame
		physics_ticks += 1

func release_controls() -> void:
	for key in ["move_left","move_right","look_up","look_down","jump","attack","dash","heal","spell","interact","parry"]:
		if InputMap.has_action(key): Input.action_release(key)

func pulse(key: String, count: int = 2) -> void:
	await physics_frame
	Input.action_press(key)
	await step(count)
	Input.action_release(key)
	await step(2)

func hold(key: String, count: int) -> void:
	await physics_frame
	Input.action_press(key)
	await step(count)
	Input.action_release(key)
	await step(2)

func stop_audio(node: Node) -> void:
	for child in node.get_children(): stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null

func remember_user_files() -> void:
	var directory := DirAccess.open("user://")
	if directory == null: return
	for name in directory.get_files():
		original_user_files.append(name)
		if "m18" in name.to_lower():
			user_backups[name] = FileAccess.get_file_as_bytes("user://" + name)

func restore_user_files() -> bool:
	var directory := DirAccess.open("user://")
	if directory == null: return user_backups.is_empty()
	# Restore backups even when a controls reset removed the original file.
	for name in user_backups:
		if name == REPORT.get_file(): continue
		var file := FileAccess.open("user://"+name,FileAccess.WRITE)
		if file: file.store_buffer(user_backups[name])
	for name in directory.get_files():
		if "m18" in name.to_lower() and name != REPORT.get_file() and not original_user_files.has(name):
			DirAccess.remove_absolute("user://" + name)
	for name in user_backups:
		if FileAccess.get_file_as_bytes("user://"+name) != user_backups[name]: return false
	return true

func make_world(restore: bool = false) -> bool:
	release_controls()
	if is_instance_valid(world):
		stop_audio(world)
		# Dummy audio mixes in real time while fixed-fps QA runs unthrottled.
		OS.delay_msec(120)
		await process_frame
		world.queue_free()
		world = null
		await process_frame
		await process_frame
	var scene: PackedScene = load(WORLD_PATH)
	if not check(scene != null, "M18 scene loads"): return false
	world = scene.instantiate()
	scene = null
	world.set("restore_saved_game",restore)
	world.set("environment_preview",true)
	world.set("transition_seconds",0.001)
	root.add_child(world)
	await step(45)
	hero = world.get("hero")
	return check(is_instance_valid(hero) and hero.is_on_floor(), "initial hero is supported")

func fixture_room(id: int, at: Vector2) -> void:
	release_controls()
	if world.hud.panel_open:
		world.hud.action.emit("close_panel",null)
		await step(3)
	world.progress.weapon_owned = true
	world._load_room(id,"left",at)
	hero = world.hero
	hero.has_blade = true
	hero.has_dash = true
	hero.has_code_slash = true
	world.combat_state.dash_owned = true
	world.combat_state.spell_owned = true
	await step(5)
	sample("configured_fixture",{"room":id,"hero_position":[hero.position.x,hero.position.y]})

func fixture_enemy() -> Node2D:
	await fixture_room(2,Vector2(800,1260))
	var enemies: Array = world.get("enemies")
	for candidate in enemies:
		if is_instance_valid(candidate) and not candidate.is_dead:
			return candidate
	check(false,"native area02 contains the first larva")
	return null

func freeze_enemy(enemy: Node2D, at: Vector2) -> void:
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.position = at
	enemy.velocity = Vector2.ZERO
	enemy.state = "crawl"
	enemy.state_time = 0.0
	enemy.invulnerable = 0.0
	enemy.hp = 3
	enemy.is_dead = false
	sample("configured_stationary_target",{"enemy_position":[at.x,at.y],"scope":"target placement only; sword and collision run normally"})

func reset_hero(at: Vector2) -> void:
	release_controls()
	hero.position = at
	hero.velocity = Vector2.ZERO
	hero.hp = 6
	hero.energy = 0.0
	hero.invulnerable = 0.0
	hero.hurt_time = 0.0
	hero.attack_time = 0.0
	hero.attack_cooldown = 0.0
	hero.active_strike_time = 0.0
	hero.dash_time = 0.0
	hero.dash_cooldown = 0.0
	hero.air_dash_used = false
	hero.hit_targets.clear()

func drive_toward(x: float) -> void:
	var error: float = x-hero.position.x
	var accel: float = 2650.0 if hero.is_on_floor() else 1950.0
	var braking: float = hero.velocity.x*hero.velocity.x/(2.0*accel)
	if absf(error)<3.0 or (hero.velocity.x*error>0 and absf(error)<braking+3):
		Input.action_release("move_left")
		Input.action_release("move_right")
	elif error>0:
		Input.action_release("move_left")
		Input.action_press("move_right")
	else:
		Input.action_release("move_right")
		Input.action_press("move_left")

func walk_to(point: Vector2) -> bool:
	for tick in range(1200):
		drive_toward(point.x)
		await step(1)
		if absf(hero.position.x-point.x)<=6.0 and absf(hero.velocity.x)<3.0 and hero.is_on_floor() and absf(hero.position.y-point.y)<3.0:
			release_controls()
			return true
	release_controls()
	return check(false,"actual walk failed to reach "+str(point)+" from "+str(hero.position))

func jump_to(point: Vector2) -> bool:
	var start: Vector2 = hero.position
	var airborne: bool = false
	var landed: bool = false
	await physics_frame
	Input.action_press("jump")
	for tick in range(140):
		drive_toward(point.x)
		await step(1)
		if tick==2: Input.action_release("jump")
		if not hero.is_on_floor(): airborne = true
		if airborne and hero.is_on_floor():
			landed = true
			break
	Input.action_release("jump")
	var passed: bool = airborne and landed and absf(hero.position.y-point.y)<3.0
	if passed: route_jumps += 1
	sample("continuous_route_jump",{"start":[start.x,start.y],"target":[point.x,point.y],"landing":[hero.position.x,hero.position.y],"actual_input":true,"passed":passed})
	if not check(passed,"actual jump reaches "+str(point)): return false
	return await walk_to(point)

func initial_route_combat() -> void:
	phase = "continuous opening route by actual Input"
	if not await walk_to(Vector2(330,1260)): return
	await pulse("interact")
	check(world.hud.panel_open and world.hud.current_panel=="fitils","opening route rests at a real bench")
	world.hud.action.emit("close_panel",null)
	await step(3)
	if not await walk_to(Vector2(445,1260)): return
	await pulse("interact")
	check(world.combat_state.owns_fitil("wick"),"opening route collects the first wick")
	if not await walk_to(Vector2(650,1260)): return
	await pulse("interact")
	check(hero.has_blade and world.progress.weapon_owned,"opening route acquires the blade through actual interaction")
	if not await walk_to(Vector2(1500,1260)): return
	await pulse("interact")
	check(hero.has_dash and world.combat_state.dash_owned,"opening route learns the early dash through actual interaction")
	if not await walk_to(Vector2(1936,1260)): return
	if not await jump_to(Vector2(1992,1140)): return
	if not await walk_to(Vector2(2180,1140)): return
	if not await jump_to(Vector2(2282,1020)): return
	if not await walk_to(Vector2(2690,1020)): return
	await pulse("interact")
	for tick in range(100):
		await step(1)
		if world.current_room==2 and not world.transitioning: break
	check(world.current_room==2,"opening route crosses the actual first portal")
	if world.current_room!=2: return
	var enemy: Node2D
	for actor in world.enemies:
		if is_instance_valid(actor): enemy=actor; break
	if not check(is_instance_valid(enemy),"native larva exists after actual room entry"): return
	var hp_before: int = hero.hp
	var start_tick: int = physics_ticks
	var seen_states: Array[String] = []
	for tick in range(1800):
		if not is_instance_valid(enemy) or enemy.is_dead: break
		if not seen_states.has(enemy.state): seen_states.append(enemy.state)
		if tick%60==0: sample("fight_trace",{"hero_position":[hero.position.x,hero.position.y],"enemy_position":[enemy.position.x,enemy.position.y],"enemy_hp":enemy.hp,"hero_facing":hero.facing,"attack_time":hero.attack_time,"strike_serial":hero.strike_serial,"active":world.gameplay_active,"pose":hero.current_pose})
		var dx: float = enemy.position.x-hero.position.x
		if tick%20==3: Input.action_release("attack")
		Input.action_release("jump")
		Input.action_release("look_down")
		if absf(dx)>115.0:
			drive_toward(enemy.position.x-float(signf(dx))*95.0)
		else:
			Input.action_release("move_left")
			Input.action_release("move_right")
			if hero.facing!=int(signf(dx)) and absf(dx)>3.0 and hero.attack_time<=0:
				Input.action_press("move_right" if dx>0 else "move_left")
			if hero.is_on_floor() and enemy.state=="windup" and enemy.state_time<0.19:
				Input.action_press("jump")
			if not hero.is_on_floor() and hero.position.y<enemy.position.y-28.0:
				Input.action_press("look_down")
			if tick%20==0 and hero.hurt_time<=0.0:
				Input.action_press("attack")
		await step(1)
	release_controls()
	var won: bool = bool(world.progress.get("encounter_assignments_cleared",false))
	check(won,"continuous opening route defeats the native active larva without configured hits or positions")
	check(hero.hp>0,"opening encounter can be completed without a death reset")
	sample("continuous_native_fight",{"won":won,"frames":physics_ticks-start_tick,"states_seen":seen_states,"health_before":hp_before,"health_after":hero.hp,"actual_input":true,"teleported":false,"enemy_frozen":false})
	if not won: return
	await step(30)
	if not await walk_to(Vector2(1450,1260)): return
	await pulse("interact")
	check(hero.has_code_slash and world.combat_state.spell_owned,"genuine first victory unlocks the actual technique pickup")
	if not await walk_to(Vector2(1476,1260)): return
	if not await jump_to(Vector2(1532,1140)): return
	if not await walk_to(Vector2(1720,1140)): return
	if not await jump_to(Vector2(1822,1020)): return
	if not await walk_to(Vector2(2010,1020)): return
	if not await jump_to(Vector2(2112,900)): return
	if not await walk_to(Vector2(3490,900)): return
	await pulse("interact")
	for tick in range(100):
		await step(1)
		if world.current_room==3 and not world.transitioning: break
	opening_route_complete = world.current_room==3
	check(opening_route_complete,"actual combat victory opens the real route to area03")

func energy_and_heal_checks() -> void:
	phase = "shared energy and focus via Input"
	await fixture_room(1,Vector2(1200,1260))
	hero.energy = 0.0
	await step(120)
	check(is_zero_approx(hero.energy),"idle does not regenerate energy")
	await pulse("attack")
	await step(25)
	check(is_zero_approx(hero.energy),"empty sword swing does not generate energy")
	hero.hp = 4
	hero.energy = 99.0
	await physics_frame
	Input.action_press("heal")
	await step(20)
	check(hero.hp == 4,"focus does not heal before its channel completes")
	check(is_equal_approx(hero.energy,66.0),"focus reserves exactly33 from shared99 pool")
	for tick in range(70):
		await step(1)
		if hero.hp > 4: break
	Input.action_release("heal")
	await step(2)
	check(hero.hp == 5,"completed focus restores one heart")
	check(is_equal_approx(hero.energy,66.0),"one completed focus costs33 total")
	hero.hp = 4
	hero.energy = 99.0
	hero.invulnerable = 0.0
	await physics_frame
	Input.action_press("heal")
	await step(18)
	hero.hurt(1,hero.position.x+100)
	Input.action_release("heal")
	await step(80)
	check(hero.hp == 3,"damage interrupts focus without delayed healing")
	check(is_equal_approx(hero.energy,66.0),"interrupted focus retains the spent33 cost")
	hero.hurt_time = 0.0
	hero.invulnerable = 0.0
	hero.energy = 32.0
	await hold("heal",75)
	check(hero.hp == 3 and is_equal_approx(hero.energy,32.0),"insufficient focus energy causes no heal or debit")
	hero.hp = 6
	hero.energy = 99.0
	await hold("heal",15)
	check(is_equal_approx(hero.energy,99.0),"full health does not spend focus energy")
	hero.energy = 99.0
	await pulse("spell")
	await step(30)
	check(is_equal_approx(hero.energy,66.0),"one actual spell input consumes the shared33 cost")
	hero.energy = 32.0
	await pulse("spell")
	await step(10)
	check(is_equal_approx(hero.energy,32.0),"insufficient spell energy causes no debit")
	await step(30)
	hero.hp = 4
	hero.energy = 99.0
	await physics_frame
	Input.action_press("heal")
	await step(12)
	await pulse("spell")
	await step(85)
	check(hero.hp==4 and not hero.healing,"holding heal after a spell interruption cannot silently restart focus")
	check(is_equal_approx(hero.energy,33.0),"focus then spell spends33each with no extra hidden focus debit")
	Input.action_release("heal")
	await step(3)

func attack_movement_checks() -> void:
	phase = "jump slash and dash input overlap"
	await fixture_room(1,Vector2(1250,1260))
	reset_hero(Vector2(1250,1260))
	await step(3)
	await physics_frame
	Input.action_press("jump")
	Input.action_press("attack")
	await step(6)
	Input.action_release("jump")
	Input.action_release("attack")
	check(not hero.is_on_floor(),"jump input produces an airborne sword attack")
	check(hero.attack_time > 0.0,"jump does not cancel the active slash")
	check(str(hero.current_pose).begins_with("slash"),"airborne attack retains a sword pose")
	check(hero.combat_container.visible and not hero.lantern_sprite.visible,"combat displays one M13 rig instead of the hidden legacy timing sprite")
	var head: AtlasTexture = hero.combat_model.textures.get("head")
	check(head != null and head.atlas.resource_path=="res://art_source/m12/warden_parts.png","attack head uses the same approved cutout atlas as M13 movement")
	check(hero.combat_container.scale.is_equal_approx(Vector2(0.4*hero.facing,0.4)),"attack keeps the approved M13 art scale")
	sample("actual_jump_attack",{"airborne":not hero.is_on_floor(),"pose":hero.current_pose,"attack_remaining":hero.attack_time})
	await step(90)
	check(hero.lantern_sprite.visible and not hero.combat_container.visible,"attack completion returns to the original movement art without a duplicate hero")
	reset_hero(Vector2(1250,1260))
	await step(3)
	var serial: int = hero.strike_serial
	await pulse("attack",1)
	await pulse("dash",1)
	var retained: bool = hero.attack_time > 0.0
	var dashed: bool = hero.dash_time > 0.0
	for tick in range(30):
		await step(1)
		if hero.dash_time > 0.0: dashed = true
	check(retained,"dash request does not erase the pending slash")
	check(dashed,"dash requested during slash executes after the action boundary")
	check(hero.strike_serial > serial,"buffered dash does not prevent the sword strike from starting")
	await step(60)
	reset_hero(Vector2(1250,1260))
	await step(3)
	await pulse("dash",1)
	serial = hero.strike_serial
	await pulse("attack",1)
	var attacked: bool = false
	for tick in range(30):
		await step(1)
		if hero.strike_serial > serial: attacked = true
	check(attacked,"attack requested during dash is buffered and executed")
	await step(70)
	reset_hero(Vector2(1250,650))
	await step(3)
	await pulse("dash",1)
	check(hero.air_dash_used,"air dash consumes its airborne token")
	await step(33)
	check(hero.dash_cooldown <= 0.0,"air dash token test waits for its cooldown to expire")
	var before: float = hero.dash_time
	await pulse("dash",1)
	check(hero.dash_time <= before and hero.air_dash_used,"a second airborne dash cannot bypass its spent token")
	await step(100)
	check(hero.is_on_floor() and not hero.air_dash_used,"landing restores the airborne dash token")
	reset_hero(Vector2(1250,1260))
	await step(3)
	await pulse("dash",1)
	hero.invulnerable = 0.0
	var hp: int = hero.hp
	hero.hurt(1,hero.position.x+100)
	check(hero.hp == hp-1,"basic dash does not grant damage immunity")
	await step(2)
	check(hero.current_pose=="recoil" and hero.combat_container.visible and not hero.lantern_sprite.visible,"hurt response keeps the same M13 character rig")
	hero.has_blade = false
	hero.invulnerable = 0.0
	hero.hurt(1,hero.position.x+100)
	await step(2)
	check(not hero.combat_container.visible or not hero.combat_model.sword_visible,"unarmed hurt presentation does not invent an equipped sword")
	check(not InputMap.has_action("parry") or InputMap.action_get_events("parry").is_empty(),"M18 has no separate parry button")

func sword_hit_checks() -> void:
	phase = "directional sword hits and reward uniqueness"
	var enemy: Node2D = await fixture_enemy()
	if not is_instance_valid(enemy): return
	freeze_enemy(enemy,Vector2(1150,1260))
	reset_hero(Vector2(1065,1260))
	hero.facing = 1
	await step(3)
	await pulse("attack")
	await step(22)
	check(enemy.hp == 2,"one forward sword input damages the larva once")
	check(is_equal_approx(hero.energy,11.0),"one valid melee hit earns exactly11 energy")
	check(enemy.hp == 2,"one slash cannot hit the same target repeatedly")
	var other_energy: float = hero.energy
	enemy.invulnerable = 10.0
	hero.attack_cooldown = 0.0
	await pulse("attack")
	await step(20)
	check(is_equal_approx(hero.energy,other_energy),"invulnerable target does not generate energy")
	enemy.invulnerable = 0.0
	freeze_enemy(enemy,Vector2(1150,1260))
	reset_hero(Vector2(1150,1175))
	hero.air_dash_used = true
	await physics_frame
	Input.action_press("look_down")
	Input.action_press("attack")
	await step(8)
	Input.action_release("look_down")
	Input.action_release("attack")
	var bounced: bool = hero.velocity.y < -100.0
	for tick in range(14):
		await step(1)
		if enemy.hp < 3 and hero.velocity.y < -100.0: bounced = true
	check(enemy.hp == 2,"downward aerial sword input damages the target")
	check(bounced,"successful downward strike bounces the hero")
	check(not hero.air_dash_used,"successful pogo restores the airborne dash token")
	check(is_equal_approx(hero.energy,11.0),"pogo earns energy only from its accepted melee hit")
	freeze_enemy(enemy,Vector2(1150,1135))
	reset_hero(Vector2(1150,1260))
	await step(3)
	await physics_frame
	Input.action_press("look_up")
	Input.action_press("attack")
	await step(10)
	Input.action_release("look_up")
	Input.action_release("attack")
	await step(12)
	check(enemy.hp == 2,"upward sword input damages a target overhead")
	freeze_enemy(enemy,Vector2(1150,1260))
	reset_hero(Vector2(1065,1260))
	hero.energy = 99.0
	hero.facing = 1
	await step(3)
	await pulse("spell")
	await step(30)
	check(enemy.hp < 3,"a spell can hit the enemy through its native projectile path")
	check(is_equal_approx(hero.energy,66.0),"spell damage does not recharge its own energy")

func clash_and_contact_checks() -> void:
	phase = "active jaw contact and sword clash"
	var enemy: Node2D = await fixture_enemy()
	if not is_instance_valid(enemy): return
	freeze_enemy(enemy,Vector2(1150,1260))
	reset_hero(Vector2(1150,1260))
	await step(15)
	check(hero.hp == 6,"soft inactive body contact causes no damage")
	check(enemy.danger_rect().size == Vector2.ZERO,"inactive larva has no dangerous jaw volume")
	enemy.state = "lunge"
	enemy.direction = 1
	enemy.state_time = 0.24
	reset_hero(Vector2(1202,1260))
	await step(3)
	check(hero.hp == 5,"active jaw contact damages exactly one heart")
	await step(8)
	check(hero.hp == 5,"damage grace prevents repeated overlap damage")
	freeze_enemy(enemy,Vector2(1150,1260))
	enemy.state = "lunge"
	enemy.direction = -1
	enemy.state_time = 0.24
	reset_hero(Vector2(1050,1260))
	hero.facing = 1
	await step(2)
	await pulse("attack")
	await step(16)
	check(enemy.state == "stagger","sword meeting the active jaw produces a clash")
	check(hero.hp == 6,"successful clash does not also apply jaw contact damage")
	check(is_zero_approx(hero.energy),"clash does not farm energy as a damaging hit")

func enemy_behavior_checks() -> void:
	phase = "native larva telegraph and pursuit"
	var enemy: Node2D = await fixture_enemy()
	if not is_instance_valid(enemy): return
	enemy.position = Vector2(1150,1260)
	enemy.direction = 1
	enemy.state = "crawl"
	enemy.entry_grace = 1.0
	enemy.attack_cooldown = 0.0
	hero.position = Vector2(1240,1260)
	world.camera.position = world.camera.bounded(Vector2(1250,1030))
	world.camera.reset_smoothing()
	await step(30)
	check(enemy.state == "crawl","room-entry grace blocks an immediate lunge")
	var warned: bool = false
	var lunged: bool = false
	var recovered: bool = false
	var warning_ticks: int = 0
	var locked_facing: int = 0
	for tick in range(150):
		await step(1)
		if enemy.state == "windup":
			warning_ticks += 1
			if not warned:
				warned = true
				locked_facing = enemy.direction
				# Isolated target relocation tests the lock; it is not claimed
				# as an input-driven combat escape.
				hero.position.x = enemy.position.x - 140.0*float(locked_facing)
			check(enemy.direction == locked_facing,"warning direction remains locked")
		if enemy.state == "lunge":
			lunged = true
			check(enemy.direction == locked_facing,"lunge does not auto-aim after warning")
		if lunged and enemy.state == "recover":
			recovered = true
			break
	check(warned and warning_ticks >= 23,"native windup visibly precedes the lunge for about0.45sec")
	check(lunged and recovered,"larva completes lunge then enters punishable recovery")
	sample("native_enemy_cycle",{"warning_ticks":warning_ticks,"lunged":lunged,"recovered":recovered,"direction":locked_facing})
	enemy.state = "crawl"
	enemy.entry_grace = 0.0
	enemy.attack_cooldown = 0.0
	hero.position = enemy.position+Vector2(100,0)
	world.camera.process_mode = Node.PROCESS_MODE_DISABLED
	world.camera.position = Vector2(3300,1000)
	world.camera.reset_smoothing()
	world.camera.force_update_scroll()
	await step(40)
	check(enemy.state == "crawl","offscreen enemy cannot start a new attack")
	world.camera.process_mode = Node.PROCESS_MODE_INHERIT
	var before: Vector2 = enemy.position
	var elapsed: float = enemy.age
	world.gameplay_active = false
	await step(25)
	check(enemy.position.is_equal_approx(before) and is_equal_approx(enemy.age,elapsed),"paused gameplay stops enemy state and motion")
	world.gameplay_active = true

func loadout_and_persistence_checks() -> void:
	phase = "bench-only native loadout and pickups"
	await fixture_room(1,Vector2(1200,1260))
	world.combat_state.equipped.clear()
	world.combat_state.acquire("wick")
	world.combat_state.acquire("reach")
	world.combat_state.acquire("focus")
	world.combat_state.capacity = 3
	world.hud.action.emit("equip_fitil","wick")
	await step(3)
	check(world.combat_state.equipped.is_empty(),"UI equip action is rejected away from a bench")
	world.hud.action.emit("fitils",null)
	await step(3)
	check(not world.hud.panel_open,"loadout panel cannot open away from a bench")
	hero.position = Vector2(330,1260)
	hero.velocity = Vector2.ZERO
	hero.hp = 3
	hero.energy = 12.0
	await step(3)
	await pulse("interact")
	check(world.hud.panel_open and world.hud.current_panel=="fitils","actual bench interaction opens the native loadout panel")
	check(hero.hp==6 and is_equal_approx(hero.energy,99.0),"resting restores all hearts and shared energy")
	check(world.at_bench and world.combat_hud_context().at_bench,"HUD reports genuine physical bench access")
	world.hud.action.emit("equip_fitil","wick")
	await step(3)
	world.hud.action.emit("equip_fitil","focus")
	await step(3)
	check(world.combat_state.has_fitil("wick") and world.combat_state.has_fitil("focus"),"native loadout choices equip two fitils within capacity")
	check(world.combat_state.used_capacity()==3,"different fitil costs share one capacity")
	world.hud.action.emit("equip_fitil","reach")
	await step(3)
	check(not world.combat_state.has_fitil("reach"),"native loadout cannot overfill capacity")
	var equipped: Array = world.combat_state.equipped.duplicate()
	world.hud.action.emit("language","en")
	await step(5)
	check(world.hud.panel_open and world.hud.current_panel=="fitils" and world.combat_state.equipped==equipped,"language switch preserves the loadout panel and equipment")
	world.hud.action.emit("close_panel",null)
	await step(3)
	check(not world.at_bench,"closing the bench panel ends equip permission")
	world.hud.action.emit("unequip_fitil","wick")
	await step(3)
	check(world.combat_state.has_fitil("wick"),"UI unequip is rejected after leaving the bench session")
	# A declared pickup-location fixture, followed by actual interaction.
	await fixture_room(3,Vector2(790,1260))
	var capacity: int = world.combat_state.capacity
	await pulse("interact")
	check(world.combat_state.capacity==capacity+1,"actual capacity pickup expands the shared fitil capacity")
	await fixture_room(3,Vector2(790,1260))
	await pulse("interact")
	check(world.combat_state.capacity==capacity+1,"revisiting the capacity pickup cannot duplicate the reward")
	if world.hud.panel_open:
		world.hud.action.emit("close_panel",null)
		await step(3)
	hero.hp = 4
	hero.energy = 55.0
	await fixture_room(2,Vector2(800,1260))
	check(hero.hp==4 and is_equal_approx(hero.energy,55.0),"room changes do not give free healing or energy")
	# Remove fitils for the subsequent base-value combat checks.
	world.combat_state.equipped.clear()

func enemy_reward_checks() -> void:
	phase = "real defeat and idempotent rewards"
	var enemy: Node2D = await fixture_enemy()
	if not is_instance_valid(enemy): return
	freeze_enemy(enemy,Vector2(1150,1260))
	enemy.hp = 1
	reset_hero(Vector2(1065,1260))
	hero.facing = 1
	world.progress.encounter_assignments_cleared = false
	var coins: int = world.combat_state.wallet
	await step(3)
	await pulse("attack")
	await step(20)
	check(enemy.is_dead,"actual sword contact can defeat the larva")
	check(world.progress.encounter_assignments_cleared,"only the real registered defeat clears the first encounter")
	check(world.combat_state.wallet==coins+12,"the actual first defeat awards its12coins once")
	world.on_enemy_defeated(enemy)
	check(world.combat_state.wallet==coins+12,"duplicate defeat callback does not duplicate currency")
	check(enemy.danger_rect().size==Vector2.ZERO and not enemy.take_hit(1,hero.position.x),"dead larva has no damage or repeat-hit reward")

func death_and_save_checks() -> void:
	phase = "death drops and permanent progress"
	await fixture_room(1,Vector2(330,1260))
	await pulse("interact")
	if world.hud.panel_open:
		world.hud.action.emit("close_panel",null)
		await step(3)
	world.combat_state.acquire("wick")
	world.combat_state.acquire("focus")
	world.combat_state.equip("wick",true)
	world.progress.ink_route_solved = true
	world.progress.archive_return_open = true
	var permanent: Array = world.combat_state.owned.duplicate()
	var equipped: Array = world.combat_state.equipped.duplicate()
	world.combat_state.wallet = 50
	await fixture_room(2,Vector2(800,1260))
	hero.hp = 1
	hero.invulnerable = 0.0
	hero.energy = 42.0
	hero.last_safe_position = Vector2(800,1260)
	hero.hurt(1,hero.position.x+100)
	check(hero.current_pose=="death" and hero.combat_container.visible and not hero.lantern_sprite.visible,"death presentation also retains the approved M13 rig")
	await step(40)
	check(world.current_room==1 and hero.hp==6,"death returns to the last actual bench with full health")
	check(world.combat_state.wallet==0,"death removes carried currency from the wallet")
	check(int(world.combat_state.death_drop.get("room",0))==2 and int(world.combat_state.death_drop.get("amount",0))==50,"death leaves the actual carried currency in the death room")
	check(world.combat_state.owned==permanent and world.combat_state.equipped==equipped,"death preserves owned and equipped fitils")
	check(world.progress.ink_route_solved and world.progress.archive_return_open and world.progress.weapon_owned,"death preserves solved mechanisms, shortcuts and weapon")
	check(is_zero_approx(hero.energy),"respawn does not silently refill the shared energy")
	world.combat_state.wallet = 7
	hero.position = Vector2(900,1260)
	hero.last_safe_position = Vector2(900,1260)
	hero.hp = 1
	hero.invulnerable = 0.0
	hero.hurt(1,hero.position.x+100)
	await step(40)
	check(int(world.combat_state.death_drop.get("room",0))==1 and int(world.combat_state.death_drop.get("amount",0))==7,"second death replaces the unrecovered previous pile")
	hero.hp = 1
	hero.invulnerable = 0.0
	hero.hurt(1,hero.position.x+100)
	await step(40)
	check(world.combat_state.death_drop.is_empty(),"second death with an empty wallet still deletes the previous pile")
	world.combat_state.wallet = 25
	hero.position = Vector2(1000,1260)
	hero.last_safe_position = Vector2(1000,1260)
	hero.hp = 1
	hero.invulnerable = 0.0
	hero.hurt(1,hero.position.x+100)
	await step(40)
	await fixture_room(1,Vector2(1000,1260))
	await pulse("interact")
	check(world.combat_state.wallet==25 and world.combat_state.death_drop.is_empty(),"actual interaction recovers the visible currency pile once")
	await pulse("interact")
	check(world.combat_state.wallet==25,"repeated interaction cannot recover a consumed pile twice")
	hero.energy = 44.0
	world._save()
	var saved: Dictionary = world.combat_state.serialize()
	if not await make_world(true): return
	check(world.combat_state.serialize()==saved,"reload restores wallet, fitils, capacity, claims and ability ownership")
	check(is_equal_approx(hero.energy,44.0),"reload restores the shared energy")
	check(world.progress.ink_route_solved and world.progress.archive_return_open and world.progress.weapon_owned,"reload preserves permanent world progress")
	check(not bool(world.progress.get("boss_defeated",false)) and not bool(world.progress.get("guard_clear",false)),"combat prototype never invents guardian or boss victories")
	check(int(world.combat_hud_context().hp)==hero.hp and is_equal_approx(float(world.combat_hud_context().energy),hero.energy),"HUD context reads actual actor health and energy")

func joypad_checks() -> void:
	phase = "native controller events"
	await fixture_room(1,Vector2(1250,1260))
	reset_hero(Vector2(1250,1260))
	await step(3)
	var press := InputEventJoypadButton.new()
	press.device = 0
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	Input.parse_input_event(press)
	await step(4)
	var release := InputEventJoypadButton.new()
	release.device = 0
	release.button_index = JOY_BUTTON_A
	release.pressed = false
	Input.parse_input_event(release)
	check(not hero.is_on_floor(),"native controller A event triggers jump")
	await step(80)
	var serial: int = hero.strike_serial
	press = InputEventJoypadButton.new()
	press.device = 0
	press.button_index = JOY_BUTTON_X
	press.pressed = true
	Input.parse_input_event(press)
	await step(5)
	release = InputEventJoypadButton.new()
	release.device = 0
	release.button_index = JOY_BUTTON_X
	release.pressed = false
	Input.parse_input_event(release)
	check(hero.strike_serial > serial,"native controller X event triggers sword attack")

func remapping_checks() -> void:
	phase = "persisted per-device controls"
	await fixture_room(1,Vector2(1250,1260))
	var controls: RefCounted = load("res://scripts/combat/m18_controls.gd").new()
	controls.defaults()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_P
	check(controls.rebind("attack",key),"keyboard attack can be rebound to an unused physical key")
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_X
	check(InputMap.action_has_event("attack",joy),"keyboard rebind preserves the controller attack binding")
	var conflict := InputEventKey.new()
	conflict.physical_keycode = KEY_SPACE
	check(not controls.rebind("attack",conflict),"a key already assigned to jump cannot silently replace attack")
	var loaded: RefCounted = load("res://scripts/combat/m18_controls.gd").new()
	loaded.setup()
	check(InputMap.action_has_event("attack",key),"keyboard rebind survives controls reload")
	var before: int = hero.strike_serial
	key.pressed = true
	Input.parse_input_event(key)
	await step(5)
	key = InputEventKey.new()
	key.physical_keycode = KEY_P
	key.pressed = false
	Input.parse_input_event(key)
	check(hero.strike_serial>before,"native remapped P key triggers the real sword action")
	await step(25)
	joy = InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_RIGHT_STICK
	check(loaded.rebind("attack",joy),"controller attack can be rebound independently")
	check(InputMap.action_has_event("attack",key),"controller rebind preserves the keyboard attack binding")
	var persisted: RefCounted = load("res://scripts/combat/m18_controls.gd").new()
	persisted.setup()
	check(InputMap.action_has_event("attack",joy),"controller rebind survives controls reload")
	before = hero.strike_serial
	joy.pressed = true
	Input.parse_input_event(joy)
	await step(5)
	joy = InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_RIGHT_STICK
	joy.pressed = false
	Input.parse_input_event(joy)
	check(hero.strike_serial>before,"native remapped R3 event triggers the real sword action")
	persisted.reset()
	world.hud.action.emit("controls",null)
	await step(3)
	world.hud.action.emit("rebind","attack")
	await step(3)
	check(world.awaiting_action=="attack","native remapping panel enters input capture")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await step(1)
	escape = InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = false
	Input.parse_input_event(escape)
	await step(4)
	check(world.awaiting_action.is_empty() and world.hud.panel_open and world.hud.current_panel=="controls","Escape cancels rebinding without also closing its controls panel")
	world.hud.action.emit("close_panel",null)
	await step(3)

func run_checks() -> void:
	remember_user_files()
	phase = "engine and initial boot"
	check(Engine.get_version_info().major == 4 and Engine.get_version_info().minor == 7,"QA uses Godot4.7")
	if await make_world():
		check(hero.hp == 6 and hero.max_hp == 6,"initial HUD health is six hearts")
		check(is_equal_approx(hero.energy,99.0),"fresh actor begins with the declared99energy cap")
		var defaults: RefCounted = load("res://scripts/combat/m18_controls.gd").new()
		defaults.defaults()
		await initial_route_combat()
		await energy_and_heal_checks()
		await attack_movement_checks()
		await sword_hit_checks()
		await clash_and_contact_checks()
		await enemy_behavior_checks()
		await loadout_and_persistence_checks()
		await enemy_reward_checks()
		await death_and_save_checks()
		await joypad_checks()
		await remapping_checks()
	if is_instance_valid(world):
		release_controls()
		stop_audio(world)
		# Dummy audio mixes in real time while fixed-fps QA runs unthrottled.
		OS.delay_msec(120)
		await process_frame
		world.queue_free()
		world = null
		await process_frame
		await process_frame
	phase = "cleanup"
	var restored: bool = restore_user_files()
	check(restored,"original M18 save/settings files restored byte-for-byte")
	var report := {"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"physics_ticks":physics_ticks,"samples":samples,"save_restored":restored,"opening_route_complete":opening_route_complete,"opening_route_jumps":route_jumps,"scope":"continuous input-driven opening route from area01 through real larva victory and technique pickup to area03, plus separately declared isolated combat fixtures; no claim of a continuous15-area combat traversal"}
	FileAccess.open(REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M18 QA REPORT ",REPORT," checks=",checks," failures=",failures.size())
	OS.delay_msec(50)
	await process_frame
	quit(0 if failures.is_empty() and opening_route_complete else 1)
