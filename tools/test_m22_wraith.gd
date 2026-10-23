extends SceneTree
## Focused native physics fixtures for the fixed-target Popup Wraith.
## The hero is a movable foot-anchor fixture; campaign combat is tested separately.
const Wraith = preload("res://scripts/enemies/m22_popup_wraith.gd")
var checks: int = 0
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var world: FixtureWorld
var enemy: CharacterBody2D

class FixtureWorld extends Node2D:
	var hero: Node2D
	var gameplay_active: bool = true
	var allow_attack: bool = true
	var rewarded: int = 0
	var wallet: int = 0
	var cues: Array[String] = []
	func enemy_can_attack(_actor: Node, _zone: Rect2 = Rect2()) -> bool:
		return gameplay_active and allow_attack
	func on_enemy_defeated(_actor: Node) -> void:
		rewarded += 1
		wallet += 12
	func emit_burst(_point: Vector2, _color: Color, _amount: int) -> void: pass
	func play_sfx(cue: String) -> void: cues.append(cue)

func _initialize() -> void: call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		print("FAIL ",message)

func step(count: int) -> void:
	for tick in range(count): await physics_frame
	await process_frame

func wait_state(value: String, limit: int = 240) -> bool:
	for tick in range(limit):
		if not is_instance_valid(enemy): return false
		if enemy.state==value: return true
		await step(1)
	return false

func spawn_at(at: Vector2 = Vector2(760,430), hero_at: Vector2 = Vector2(700,600), zone: Rect2 = Rect2(400,300,550,330)) -> void:
	if is_instance_valid(enemy):
		enemy.queue_free()
		await step(2)
	world.hero.position = hero_at
	world.gameplay_active = true
	world.allow_attack = true
	enemy = Wraith.new()
	world.add_child(enemy)
	enemy.setup(world,at,Vector2(at.x-100,at.x+100),600,zone)
	await step(4)

func run_checks() -> void:
	world = FixtureWorld.new()
	root.add_child(world)
	world.hero = Node2D.new()
	world.add_child(world.hero)
	var camera := Camera2D.new()
	camera.position = Vector2(640,360)
	world.add_child(camera)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1000,40)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.position = Vector2(500,620)
	body.add_child(collision)
	world.add_child(body)
	await step(4)
	await spawn_at()
	check(enemy.hp==3 and enemy.max_hp==3,"three-hit base enemy")
	await step(28)
	check(enemy.state=="hover" and enemy.entry_grace>0,"arrival grace prevents an immediate attack")
	var grace: float = enemy.entry_grace
	world.gameplay_active = false
	await step(25)
	check(is_equal_approx(enemy.entry_grace,grace),"arrival grace counts actual gameplay, not a paused panel")
	check(not enemy.danger_rect().has_area(),"no dangerous contact while paused")
	world.gameplay_active = true
	check(await wait_state("windup"),"actual floor target starts a warning")
	check(enemy.marker_visible and enemy.target_valid,"warning exposes a landing marker")
	var captured: Vector2 = enemy.captured_target
	var marker: Vector2 = enemy.marker_world_position
	check(absf(captured.x-700)<0.1 and absf(captured.y-600)<0.1,"ray captures the old hero floor point")
	check(not enemy.danger_rect().has_area(),"warning is harmless")
	world.hero.position.x = 860
	var remaining: float = enemy.state_time
	world.gameplay_active = false
	await step(20)
	check(is_equal_approx(enemy.state_time,remaining),"reading/pause freezes the warning timer")
	world.gameplay_active = true
	check(await wait_state("dive"),"warning completes into a real dive")
	check(enemy.captured_target.is_equal_approx(captured) and enemy.marker_world_position.is_equal_approx(marker),"moving the hero during warning never retargets the marker")
	var dive_frames := 0
	var old_target_danger := false
	var new_target_danger := false
	while enemy.state=="dive" and dive_frames<30:
		var danger: Rect2 = enemy.danger_rect()
		old_target_danger = old_target_danger or danger.intersects(Rect2(Vector2(682,512),Vector2(36,40)))
		new_target_danger = new_target_danger or danger.intersects(Rect2(Vector2(842,512),Vector2(36,40)))
		check(enemy.captured_target.is_equal_approx(captured),"dive retains captured endpoint")
		await step(1)
		dive_frames += 1
	check(enemy.state=="recover","fixed dive reaches a safe recovery")
	check(enemy.global_position.distance_to(captured)<1,"dive lands on old target, not current hero")
	check(old_target_danger and not new_target_danger,"active hood threatened the old position and missed the hero's new position")
	check(not enemy.danger_rect().has_area() and not enemy.marker_visible,"landing/recovery has no contact damage")
	check(dive_frames>=12 and dive_frames<=16,"authored .24-second dive stays within one physics tick")
	samples.append({"case":"old_target_dive","captured":[captured.x,captured.y],"hero_moved_to":[860,600],"dive_frames":dive_frames,"old_target_contact":old_target_danger,"new_target_contact":new_target_danger})
	await step(25)
	check(enemy.state=="recover","recovery leaves a readable punish window")
	check(await wait_state("return"),"recovery returns home without a second attack")
	check(not enemy.danger_rect().has_area(),"return flight is harmless")
	check(await wait_state("hover"),"return completes normally")
	check(enemy.global_position.distance_to(enemy.home_position)<8,"return reaches its hover home")

	# A guard change must suppress contact immediately, not one physics tick later.
	await spawn_at()
	check(await wait_state("dive"),"second fixture reaches dive")
	world.allow_attack = false
	check(not enemy.danger_rect().has_area() and not enemy.clash_rect().has_area(),"protected-zone guard removes contact immediately")
	await step(1)
	check(enemy.state=="recover" and not enemy.marker_visible,"protected-zone entry aborts the current attack")
	world.allow_attack = true

	await spawn_at()
	check(await wait_state("dive"),"clash fixture reaches actual dive")
	check(enemy.on_clash(),"the diving lower window frame can be clashed")
	check(enemy.state=="stagger" and not enemy.danger_rect().has_area(),"clash creates a safe stagger, without fake damage")
	check(enemy.hp==3,"a clash does not secretly damage the enemy")

	await spawn_at(Vector2(3500,430),Vector2(3500,600),Rect2(3200,300,600,330))
	await step(150)
	check(enemy.state=="hover" and enemy.attack_id==0,"an offscreen wraith never begins a dive")
	await spawn_at(Vector2(1170,430),Vector2(1200,600),Rect2(1050,300,430,330))
	await step(160)
	check(enemy.attack_id==0 and not enemy.target_valid,"a gap with no physical floor never gets an invented landing target")
	await spawn_at()
	world.allow_attack = false
	await step(120)
	check(enemy.state=="hover" and enemy.attack_id==0,"a protected reading area is never attacked")
	world.allow_attack = true
	world.rewarded = 0
	world.wallet = 0
	check(enemy.take_hit(1,enemy.position.x-30),"normal melee damage is accepted")
	check(not enemy.take_hit(1,enemy.position.x-30),"same-moment repeated hits do not bypass damage immunity")
	await step(9)
	check(enemy.take_hit(1,enemy.position.x-30,"spell"),"special ability damage uses the same health API")
	await step(9)
	check(enemy.take_hit(1,enemy.position.x-30),"third real hit defeats the wraith")
	check(enemy.is_dead and enemy.hp==0,"death state is immediate")
	check(not enemy.get_hitbox().has_area() and not enemy.danger_rect().has_area(),"dead enemy is neither target nor hazard")
	check(world.rewarded==1 and world.wallet==12,"death emits one campaign reward callback")
	check(not enemy.take_hit(1,0) and world.rewarded==1,"repeated death hits cannot duplicate rewards")
	await step(35)
	check(not is_instance_valid(enemy),"native death fade frees the enemy")
	var report := {"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"samples":samples,"scope":"Focused native physics fixtures; actual floor ray, old-target dive, pause/protected/offscreen/grace/clash/hit/death/reward. Hero foot-anchor fixture rather than a full campaign playthrough."}
	FileAccess.open("user://m22_wraith_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	world.queue_free()
	world = null
	for tick in range(4): await process_frame
	print("M22 WRAITH REPORT checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
