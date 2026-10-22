extends SceneTree
## Isolated native-physics verification for the first enemy. These fixtures are
## not a claim of continuous campaign traversal or player-input combat coverage.
const Larva = preload("res://scripts/enemies/m18_glitch_larva.gd")
var checks: int = 0
var failures: Array[String] = []
var world: FixtureWorld
var enemy: CharacterBody2D

class FixtureWorld extends Node2D:
	var gameplay_active: bool = true
	var hero: Node2D
	var defeats: int = 0
	func play_sfx(_cue: String) -> void: pass
	func emit_burst(_point: Vector2, _color: Color, _amount: int) -> void: pass
	func on_enemy_defeated(_enemy: Node2D) -> void: defeats += 1

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("M18 LARVA FAIL: ", message)

func step(ticks: int) -> void:
	for _i in range(ticks): await physics_frame

func make_fixture(spawn: Vector2, target: Vector2, limits: Vector2, floor_width: float = 2000.0) -> void:
	if is_instance_valid(world):
		world.queue_free()
		await process_frame
		await process_frame
	world = FixtureWorld.new()
	root.add_child(world)
	world.hero = Node2D.new()
	world.add_child(world.hero)
	world.hero.position = target
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var floor_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(floor_width, 100.0)
	floor_shape.shape = rectangle
	floor_shape.position = Vector2(floor_width / 2.0, 550.0)
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	enemy = Larva.new()
	world.add_child(enemy)
	enemy.setup(world, spawn, limits)
	await step(4)

func wait_state(expected: String, max_ticks: int = 180) -> bool:
	for _i in range(max_ticks):
		if enemy.state == expected: return true
		await step(1)
	return false

func run() -> void:
	await make_fixture(Vector2(400,500), Vector2(600,500), Vector2(300,750))
	check(enemy.is_on_floor(), "native body settles on real floor")
	check(enemy.state == "crawl", "room-entry grace prevents an immediate attack")
	check(not enemy.danger_rect().has_area(), "soft body does not deal passive contact damage")
	await step(20)
	check(enemy.attack_id == 0, "no attack in the first second after spawn")
	world.gameplay_active = false
	var stopped_position: Vector2 = enemy.position
	var stopped_age: float = enemy.age
	var stopped_grace: float = enemy.entry_grace
	await step(25)
	check(enemy.position == stopped_position and enemy.age == stopped_age and enemy.entry_grace == stopped_grace, "pause freezes movement, warning and entry-grace timers")
	world.gameplay_active = true
	check(await wait_state("windup"), "approach enters readable windup")
	check(not enemy.danger_rect().has_area(), "warning is non-damaging")
	var committed_facing: int = enemy.direction
	world.hero.position.x = enemy.position.x - 150.0 * float(committed_facing)
	check(await wait_state("lunge"), "windup transitions to lunge")
	check(enemy.direction == committed_facing, "lunge cannot retarget a player who crosses the jaw")
	check(enemy.danger_rect().has_area() and enemy.clash_rect().has_area(), "only active lunge exposes danger and sword-clash rectangles")
	check(enemy.on_clash(), "a sword clash cancels the active lunge")
	check(not enemy.danger_rect().has_area() and not enemy.clash_rect().has_area(), "clash immediately clears attack danger")
	check(not enemy.on_clash(), "one attack cannot be parried repeatedly")
	check(enemy.take_hit(1, enemy.position.x - 100.0), "valid sword hit damages the enemy")
	check(enemy.hp == 2, "one hit removes exactly one hp")
	check(not enemy.take_hit(1, enemy.position.x - 100.0), "same-frame overlap cannot damage twice")
	await step(8)
	check(enemy.take_hit(1, enemy.position.x - 100.0), "a later distinct hit is accepted")
	await step(8)
	check(enemy.take_hit(1, enemy.position.x - 100.0), "third valid hit is lethal")
	check(enemy.is_dead and enemy.hp == 0 and world.defeats == 1, "death reports exactly one genuine defeat")
	check(not enemy.take_hit(1, enemy.position.x), "dead enemy cannot be farmed for extra hits")
	check(not enemy.danger_rect().has_area() and not enemy.get_hitbox().has_area(), "death removes danger and damageable target immediately")
	await step(32)
	check(not is_instance_valid(enemy), "death animation releases the actor")

	await make_fixture(Vector2(1600,500), Vector2(1490,500), Vector2(1400,1850))
	await step(180)
	check(enemy.attack_id == 0 and enemy.state == "crawl", "offscreen actor cannot begin an attack")

	await make_fixture(Vector2(735,500), Vector2(930,500), Vector2(0,1850),800.0)
	await step(240)
	check(enemy.position.y <= 501.0 and enemy.position.x < 770.0, "edge probe stops rush before unsupported ground")
	check(enemy.is_on_floor(), "enemy remains on the real landing after edge cancellation")

	if is_instance_valid(world):
		world.queue_free()
		await process_frame
		await process_frame
	var report := {"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"fixture_type":"isolated native-physics enemy states; no player-input or campaign traversal claim"}
	FileAccess.open("user://m18_larva_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M18 LARVA REPORT ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
