extends SceneTree
## Native movement fixtures. Initial positions/terrain are configured; every
## positive jump, descent, dash and sword action uses ordinary Input events.
const Player = preload("res://scripts/combat/m28_player.gd")
const PreviousPlayer = preload("res://scripts/combat/m23_player.gd")
const State = preload("res://scripts/combat/m18_combat_state.gd")
const Controls = preload("res://scripts/combat/m18_controls.gd")
const Paper = preload("res://scripts/stage/m17_paper_platform.gd")
var checks := 0
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var world: Node2D
var hero: CharacterBody2D

class FixtureWorld extends Node2D:
	var gameplay_active := true
	var combat_state = State.new()
	var enemies: Array[Node2D] = []
	var strikes: Array[Dictionary] = []
	var sfx: Array[String] = []
	var deaths := 0
	func emit_burst(_point: Vector2,_color: Color,_count: int) -> void: pass
	func play_sfx(kind: String) -> void: sfx.append(kind)
	func hero_strike(kind: String, facing: int) -> void: strikes.append({"kind":kind,"facing":facing,"tick":Engine.get_physics_frames()})
	func cast_code_slash(_point: Vector2,_look: int) -> void: pass
	func combat_changed() -> void: pass
	func on_player_death() -> void:
		deaths += 1
		gameplay_active = false
	func player_fell() -> void:
		deaths += 1
		gameplay_active = false
	func show_tip(_text: String) -> void: pass

func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func step(count := 1) -> void:
	for _i in range(count):
		await physics_frame
		await process_frame
func release_all() -> void:
	for action in Controls.ACTIONS: Input.action_release(action)
func surface(rect: Rect2,one_way := false) -> void:
	var floor_node := Paper.new()
	floor_node.configure(rect,one_way)
	world.add_child(floor_node)
func fixture(start: Vector2, terrain: Array, previous := false) -> void:
	release_all()
	if is_instance_valid(world):
		world.queue_free()
		await step(2)
	world = FixtureWorld.new()
	root.add_child(world)
	for record in terrain: surface(record.rect,bool(record.get("one_way",false)))
	hero = PreviousPlayer.new() if previous else Player.new()
	hero.world_ref = world
	hero.position = start
	hero.movement_bounds = Vector2(-2000,6000)
	hero.fall_limit = 5000
	hero.has_blade = true
	hero.has_dash = true
	hero.has_code_slash = true
	world.add_child(hero)
	await step(4)
func pulse(action: String,frames := 1) -> void:
	Input.action_press(action)
	await step(frames)
	Input.action_release(action)
func sample(kind: String,data: Dictionary) -> void:
	data.kind = kind
	samples.append(data)

func jump_profile(held: int,previous := false) -> Dictionary:
	await fixture(Vector2(200,600),[{"rect":Rect2(0,600,1000,80)}],previous)
	var top: float = hero.position.y
	var starting_y: float = hero.position.y
	var airborne := false
	var landed := false
	Input.action_press("jump")
	var frames := 0
	for frame in range(120):
		await step()
		frames += 1
		top = minf(top,hero.position.y)
		if frame+1>=held: Input.action_release("jump")
		if not hero.is_on_floor(): airborne = true
		if airborne and hero.is_on_floor(): landed = true; break
	release_all()
	var result := {"held_frames":held,"previous_actor":previous,"height":starting_y-top,"frames":frames,"landed":landed}
	sample("jump_profile",result.duplicate())
	return result

func inherited_motion() -> void:
	var prior_short := await jump_profile(2,true)
	var prior_held := await jump_profile(30,true)
	var short := await jump_profile(2)
	var held := await jump_profile(30)
	check(short.landed and held.landed,"tap and held jumps return to the same native floor")
	check(absf(short.height-prior_short.height)<0.01 and absf(held.height-prior_held.height)<0.01,"M28 preserves both approved jump arcs exactly against prior actor")
	check(held.frames==prior_held.frames and short.frames==prior_short.frames,"M28 preserves tap/held airtime against prior actor")
	check(held.height>short.height*1.4 and held.height>122.0,"held jump retains meaningful variable height and 120px stair clearance")
	await fixture(Vector2(200,600),[{"rect":Rect2(0,600,1000,80)}])
	Input.action_press("move_right"); await step(4)
	check(hero.velocity.x>=280,"run still reaches normal speed within four ticks")
	Input.action_release("move_right"); Input.action_press("move_left"); await step(4)
	check(hero.facing==-1 and hero.velocity.x< -250,"ground reverse remains responsive")
	Input.action_release("move_left"); await step(4)
	check(absf(hero.velocity.x)<10,"ground release still brakes promptly")

func coyote_and_buffer() -> void:
	for wait_ticks in [3,9]:
		await fixture(Vector2(370,500),[{"rect":Rect2(0,500,400,60)},{"rect":Rect2(400,1400,1000,80)}])
		Input.action_press("move_right")
		var walked_off := false
		for _tick in range(30):
			await step()
			if not hero.is_on_floor(): walked_off = true; break
		await step(wait_ticks)
		await pulse("jump")
		var jumped: bool = hero.velocity.y< -700
		check(walked_off,"coyote fixture walks off a real edge")
		check(jumped if wait_ticks==3 else not jumped,"edge grace accepts 50ms late jump and rejects expired 150ms grace: "+str(wait_ticks))
		sample("coyote",{"wait_ticks":wait_ticks,"jumped":jumped,"velocity":[hero.velocity.x,hero.velocity.y]})
	await fixture(Vector2(250,350),[{"rect":Rect2(0,600,1000,80)}])
	var pressed := false
	var bounced := false
	for _tick in range(100):
		if not pressed and hero.velocity.y>0 and hero.position.y>570:
			Input.action_press("jump")
			pressed = true
		await step()
		if pressed and hero.velocity.y< -700: bounced = true; break
	release_all()
	check(pressed and bounced,"jump pressed shortly before real landing executes through inherited buffer")

func shelf_descent() -> void:
	var terrain := [{"rect":Rect2(0,350,500,52),"one_way":true},{"rect":Rect2(0,470,500,52),"one_way":true},{"rect":Rect2(0,700,1000,80)}]
	await fixture(Vector2(200,350),terrain)
	check(hero.is_on_floor(),"descent fixture starts on an actual one-way shelf")
	Input.action_press("look_down"); Input.action_press("jump")
	await step(2)
	check(hero.velocity.y>0 and hero.position.y>350,"Down+Jump begins downward travel instead of a jump")
	check(hero.collision_mask==1,"shelf descent preserves all terrain collision layers")
	Input.action_release("jump"); Input.action_release("look_down")
	for _tick in range(80):
		await step()
		if hero.is_on_floor(): break
	check(hero.is_on_floor() and absf(hero.position.y-470)<0.2,"descent lands on the next stacked shelf rather than passing through it")
	check(hero.shelf_drops==1 and hero.get_movement_snapshot().ignored_supports==0,"only one support was ignored and its exception clears after head passes")
	await step(10)
	check(absf(hero.position.y-470)<0.2,"consumed drop press cannot auto-jump from the lower shelf")
	Input.action_press("jump")
	await step(30)
	Input.action_release("jump")
	await step(55)
	check(hero.is_on_floor() and absf(hero.position.y-350)<0.2,"fresh held jump can land on the original shelf after descent")
	await fixture(Vector2(200,600),[{"rect":Rect2(0,600,1000,80)}])
	Input.action_press("look_down"); await pulse("jump",2)
	check(hero.velocity.y<0 and hero.shelf_drops==0 and hero.get_collision_exceptions().is_empty(),"Down+Jump on solid ground remains an ordinary jump and never disables the floor")
	Input.action_release("look_down")
	await fixture(Vector2(200,350),terrain)
	Input.action_press("look_down"); await pulse("jump",1); Input.action_release("look_down")
	check(not hero.get_collision_exceptions().is_empty(),"active descent owns a native exception to its exact shelf")
	hero.jump_buffer=0.10; hero.jump_grace=0.10
	hero.reset_combat_motion()
	check(hero.get_collision_exceptions().is_empty() and hero.jump_buffer==0 and hero.jump_grace==0,"room/respawn reset clears shelf exceptions and stale jump/coyote requests")
	await fixture(Vector2(200,350),terrain)
	Input.action_press("look_down"); await pulse("jump",1); Input.action_release("look_down")
	var removed_support: PhysicsBody2D=hero.get_collision_exceptions()[0]
	removed_support.queue_free()
	await step(3)
	check(hero.get_movement_snapshot().ignored_supports==0,"removing an old room's supporting shelf safely clears its stale exception")
	await fixture(Vector2(200,350),terrain)
	Input.action_press("look_down"); await pulse("jump",1); Input.action_release("look_down")
	var fresh_press:=false
	var lower_buffered_jump:=false
	for _tick in range(60):
		if not fresh_press and hero.position.y>445 and hero.velocity.y>0:
			Input.action_press("jump"); fresh_press=true
		await step()
		if fresh_press and hero.velocity.y< -700: lower_buffered_jump=true; break
	release_all()
	check(fresh_press and lower_buffered_jump,"a later fresh Jump press can buffer normally at the next shelf after descent")
	await fixture(Vector2(200,350),terrain)
	Input.action_press("look_down"); await pulse("jump",1); Input.action_release("look_down")
	hero.hurt(6,400)
	check(hero.hp==0 and hero.get_collision_exceptions().is_empty(),"lethal native hurt clears active descent exceptions")
	# Controller parity uses real routed joypad events, not direct method calls.
	await fixture(Vector2(200,350),terrain)
	var down := InputEventJoypadButton.new(); down.button_index=JOY_BUTTON_DPAD_DOWN; down.pressed=true
	var jump := InputEventJoypadButton.new(); jump.button_index=JOY_BUTTON_A; jump.pressed=true
	Input.parse_input_event(down); Input.parse_input_event(jump)
	await step(3)
	check(hero.shelf_drops==1 and hero.velocity.y>0,"controller D-pad Down+A performs the same native shelf descent")
	down.pressed=false; jump.pressed=false; Input.parse_input_event(down); Input.parse_input_event(jump)

func wall_dash() -> void:
	await fixture(Vector2(340,300),[{"rect":Rect2(0,1600,1000,80)},{"rect":Rect2(420,100,40,1500)}])
	Input.action_press("move_right"); await pulse("dash")
	var stopped := false
	for _tick in range(15):
		await step()
		if hero.wall_dash_stops>0: stopped=true; break
	check(stopped and hero.dash_time==0 and hero.position.x<=405,"solid-wall contact ends the dash pose without entering the wall")
	check(hero.air_dash_used and hero.dash_cooldown>0.30,"wall dash keeps its spent air token and original cooldown")
	Input.action_release("move_right"); Input.action_press("move_left"); await step(3)
	check(hero.velocity.x< -200 and hero.facing==-1,"ordinary steering immediately moves away after wall contact")
	Input.action_release("move_left")
	await step(35)
	check(not hero.is_on_floor() and hero.dash_cooldown==0,"single-air-dash fixture outlasts cooldown while remaining airborne")
	await pulse("dash")
	check(hero.dash_time==0 and hero.air_dash_used,"wall stop cannot grant an extra airborne dash")
	hero.pogo()
	check(not hero.air_dash_used and is_equal_approx(hero.velocity.y,-510),"successful pogo retains the approved bounce and dash refresh")

func combat_boundaries() -> void:
	await fixture(Vector2(200,600),[{"rect":Rect2(0,600,1000,80)}])
	Input.action_press("attack"); Input.action_press("jump"); await step()
	Input.action_release("attack"); Input.action_release("jump"); Input.action_press("dash")
	await step(); Input.action_release("dash")
	var contact := false
	var dashed := false
	var prematurely_dashed := false
	for _tick in range(30):
		await step()
		if not world.strikes.is_empty(): contact=true
		if hero.dash_time>0:
			dashed=true
			if not contact: prematurely_dashed=true
	check(contact and dashed and not prematurely_dashed,"early dash preserves the normal slash contact before cancellation")
	check(hero.ATTACK_DURATION==0.30 and hero.CONTACT_START==0.06 and hero.CONTACT_END==0.14 and hero.ATTACK_COOLDOWN==0.36,"approved sword timeline is unchanged")
	await fixture(Vector2(200,600),[{"rect":Rect2(0,600,1000,80)}])
	await pulse("dash")
	var hp_before: int=hero.hp
	hero.hurt(1,400)
	check(hero.hp==hp_before-1 and hero.invulnerable==1.0,"basic dash grants no immunity and native one-second injury grace stays unchanged")
	await fixture(Vector2(200,600),[{"rect":Rect2(0,600,1000,80)}])
	hero.energy=22
	await step(60)
	check(is_equal_approx(hero.energy,22),"idle traversal cannot regenerate combat energy")
	check(hero.combat_model.get_script().resource_path=="res://scripts/warden_model_m23.gd","M28 uses the unchanged approved short-flame hero rig")

func run() -> void:
	Controls.new().defaults()
	await inherited_motion()
	await coyote_and_buffer()
	await shelf_descent()
	await wall_dash()
	await combat_boundaries()
	release_all()
	if is_instance_valid(world): world.queue_free()
	await step(3)
	var report := {"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"samples":samples,"scope":"Configured native terrain fixtures with actual input-driven coyote/buffer/variable jumps, stacked-shelf descent, controller parity, solid-wall dash, ordinary sword contact, damage/energy and reset/death checks; no claim of a continuous full-world playthrough."}
	FileAccess.open("user://m28_movement_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M28 MOVEMENT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
