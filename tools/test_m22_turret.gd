extends SceneTree
## Native scene fixture: fixed-aim cadence, swept cover interception and safe
## reading/offscreen states. It does not replace the integrated world tour.
const Turret = preload("res://scripts/enemies/m22_syntax_turret.gd")
const Bolt = preload("res://scripts/enemies/m22_ink_bolt.gd")
var failures: Array[String] = []
var checks := 0
var arena: Arena
var actor: Node2D
var cover: StaticBody2D
var timeline: Array[String] = []

class TestHero extends Node2D:
	var hp := 6
	var hits := 0
	var grace := 0.0
	func get_hurtboxes() -> Array[Rect2]:
		return [Rect2(global_position+Vector2(-14,-88),Vector2(28,88))]
	func hurt(amount: int, _attack_x: float) -> void:
		if grace > 0: return
		hp -= amount
		hits += 1
		grace = 1.0
	func _physics_process(delta: float) -> void:
		grace = maxf(0,grace-delta)
	func _draw() -> void:
		draw_rect(Rect2(-14,-54,28,54),Color("212d42"))
		draw_circle(Vector2(0,-67),20,Color("edac66"))
		draw_circle(Vector2(-5,-70),2,Color("172337"))
		draw_circle(Vector2(5,-70),2,Color("172337"))

class Arena extends Node2D:
	var hero: TestHero
	var gameplay_active := true
	var attack_allowed := true
	var defeats := 0
	var cover_blocks := 0
	func enemy_can_attack(_actor: Node2D) -> bool:
		return gameplay_active and attack_allowed
	func play_sfx(_cue: String) -> void: pass
	func emit_burst(_point: Vector2,_color: Color,amount: int) -> void:
		if amount == 4: cover_blocks += 1
	func on_enemy_defeated(_enemy: Node2D) -> void:
		defeats += 1
	func _draw() -> void:
		draw_rect(Rect2(0,0,960,540),Color("111c2a"))
		for x in range(50,960,130):
			draw_rect(Rect2(x,70,104,340),Color("1b2935"))
			for y in range(130,390,62):
				draw_line(Vector2(x,y),Vector2(x+104,y),Color("35414b"),3,true)
				for book in range(6):
					draw_rect(Rect2(x+6+book*15,y-43,11,40),Color("3c454c"))
		draw_rect(Rect2(0,420,960,120),Color("0b131e"))
		draw_line(Vector2(0,420),Vector2(960,420),Color("b1a081"),3,true)
		var font := ThemeDB.fallback_font
		draw_string(font,Vector2(35,42),"M22 / SYNTAX TURRET — native Godot test",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("d7c6a8"))
		draw_string(font,Vector2(35,485),"Fixed warning → three ink shots → open reload",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("8cabb7"))

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		print("M22 turret FAIL: ",message)

func step(frames: int) -> void:
	for tick in range(frames):
		await physics_frame
		await process_frame
		if is_instance_valid(actor) and not timeline.has(actor.state): timeline.append(actor.state)

func fresh(at: Vector2 = Vector2(660,420)) -> void:
	if is_instance_valid(actor):
		actor.clear_projectiles()
		actor.queue_free()
	await process_frame
	actor = Turret.new()
	arena.add_child(actor)
	actor.setup(arena,at)
	arena.hero.position = Vector2(250,420)
	arena.hero.hp = 6
	arena.hero.hits = 0
	arena.hero.grace = 0
	arena.attack_allowed = true
	arena.gameplay_active = true

func run() -> void:
	root.size = Vector2i(960,540)
	arena = Arena.new()
	root.add_child(arena)
	arena.hero = TestHero.new()
	arena.add_child(arena.hero)
	await fresh()
	await step(60)
	check(actor.total_shots == 0,"arrival grace prevents immediate attacks")
	for tick in range(120):
		await step(1)
		if actor.state == "windup": break
	check(actor.state == "windup","AI naturally enters a visible warning")
	var captured: Vector2 = actor.aim
	var captured_target: Vector2 = actor.locked_target
	arena.hero.position.x += 85
	await step(12)
	check(actor.aim == captured and actor.locked_target == captured_target,"warning locks previous target without homing")
	for tick in range(150):
		await step(1)
		if actor.state == "reload": break
	check(actor.total_shots == 3,"one native burst emits exactly three shots")
	check(actor.state == "reload","burst has an explicit reload opening")
	check(actor.danger_rect() == Rect2(),"turret body has no contact damage")
	var before: int = actor.total_shots
	await step(65)
	check(actor.total_shots == before,"reload cannot immediately restart a burst")
	await fresh()
	await step(240)
	check(arena.hero.hits > 0,"uninjected native projectile reaches exposed hero")
	await fresh()
	cover = StaticBody2D.new()
	cover.collision_layer = 1
	cover.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14,130)
	collision.shape = shape
	cover.position = Vector2(420,355)
	cover.add_child(collision)
	arena.add_child(cover)
	await step(2)
	arena.cover_blocks = 0
	await step(660)
	check(arena.cover_blocks >= 3 and arena.hero.hits == 0,"solid cover intercepts native burst before hero damage")
	check(actor.total_shots >= 9 and arena.cover_blocks >= 9,"repeated native bursts prune freed projectiles without typed-array conversion errors")
	actor.clear_projectiles()
	arena.attack_allowed = false
	var bolt := Bolt.new()
	arena.add_child(bolt)
	# Permit one swept step that crosses both the thin wall and the hero.
	arena.attack_allowed = true
	bolt.setup(arena,actor,Vector2(650,350),Vector2(-26000,0))
	await step(2)
	check(arena.hero.hits == 0,"high-speed sweep does not tunnel through thin cover")
	cover.queue_free()
	await process_frame
	await fresh()
	arena.attack_allowed = false
	await step(230)
	check(actor.total_shots == 0,"protected reading/puzzle area suppresses attack starts")
	actor.configure_encounter(Rect2(200,300,520,160))
	arena.attack_allowed = true
	actor.entry_grace = 0
	var outside_bolt := Bolt.new()
	arena.add_child(outside_bolt)
	outside_bolt.setup(arena,actor,Vector2(600,350),Vector2(-360,0))
	arena.hero.position.y = 620
	await step(2)
	check(not is_instance_valid(outside_bolt),"existing ink disappears when hero leaves optional gallery for safe floor")
	arena.hero.position.y = 420
	arena.attack_allowed = true
	actor.position.x = 1650
	await step(230)
	check(actor.total_shots == 0,"offscreen actor cannot fire")
	actor.position.x = 660
	await step(35)
	var saved_age: float = actor.age
	arena.gameplay_active = false
	await step(40)
	check(actor.age == saved_age,"paused gameplay does not advance attack clocks")
	arena.gameplay_active = true
	var rewards_before := arena.defeats
	actor.invulnerable = 0
	check(actor.take_hit(4,250),"four-hit health accepts a lethal hit")
	check(actor.is_dead and arena.defeats == rewards_before+1,"death notifies world once")
	check(not actor.take_hit(1,250) and arena.defeats == rewards_before+1,"dead actor cannot duplicate rewards")
	await step(35)
	await fresh()
	arena.attack_allowed = false
	actor.state = "windup"
	actor.state_time = 0.35
	actor.aim = Vector2.LEFT.rotated(-0.12)
	actor.locked_target = arena.hero.position+Vector2(0,-45)
	actor.set_physics_process(false)
	actor.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_jpg("/workspace/work/m22_syntax_turret_native.jpg",0.95)
	var report := {"checks":checks,"failures":failures,"native_states_seen":timeline,"engine":Engine.get_version_info(),"art":actor._art.resource_path if actor._art != null else "fallback"}
	var file := FileAccess.open("/workspace/work/m22_syntax_turret_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("M22_SYNTAX_TURRET_RESULT ",JSON.stringify(report))
	arena.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
