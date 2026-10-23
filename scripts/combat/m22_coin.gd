extends Node2D
## A small original brass ember disc. The authoritative settled position stays
## in the ledger; this node only animates its spawn arc and short pickup magnet.
## The world owns the atomic claim + wallet + save transaction.

const MAGNET_RADIUS := 90.0
const PICKUP_RADIUS := 18.0
const SPAWN_DURATION := 0.48
const MAGNET_SPEED := 205.0

var world_ref: Node
var definition: Dictionary = {}
var settled_position := Vector2.ZERO
var age: float = 0.0
var spawn_time: float = 0.0
var pickup_retry: float = 0.0
var magnetized: bool = false
var collected: bool = false
var visual_phase: float = 0.0

func _ready() -> void:
	add_to_group("m22_coins")
	z_index = 18
	# Brass remains readable under the world's dark ambient CanvasModulate; this
	# does not illuminate scenery or enlarge the hero's light.
	var brass_material := CanvasItemMaterial.new()
	brass_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = brass_material

func setup(world: Node, coin_definition: Dictionary) -> void:
	world_ref = world
	definition = coin_definition.duplicate(true)
	var point: Variant = definition.get("position", [])
	if not point is Array or point.size() != 2 or not _valid_number(point[0]) or not _valid_number(point[1]):
		queue_free()
		return
	settled_position = Vector2(float(point[0]), float(point[1]))
	global_position = settled_position
	visual_phase = float(int(definition.get("coin_index", 0))) * 1.77
	set_meta("reward_id", str(definition.get("reward_id", "")))
	set_meta("coin_index", int(definition.get("coin_index", -1)))
	queue_redraw()

func _physics_process(delta: float) -> void:
	if collected or not is_instance_valid(world_ref) or not bool(world_ref.get("gameplay_active")):
		return
	age += delta
	pickup_retry = maxf(0.0, pickup_retry - delta)
	var hero: Node2D = world_ref.get("hero") as Node2D
	if not is_instance_valid(hero):
		return
	if spawn_time < SPAWN_DURATION:
		spawn_time = minf(SPAWN_DURATION, spawn_time + delta)
		var t: float = spawn_time / SPAWN_DURATION
		# The saved point is on supported floor; the temporary fan always returns
		# there and cannot roll into a pit or change a persistent reward position.
		var fan: float = sin(visual_phase) * 12.0
		global_position = settled_position + Vector2(sin(t * PI) * fan, -sin(t * PI) * (30.0 + 5.0 * cos(visual_phase)))
		queue_redraw()
		return
	var target: Vector2 = hero.global_position + Vector2(0.0, -22.0)
	var distance: float = global_position.distance_to(target)
	magnetized = distance <= MAGNET_RADIUS and _line_open(target)
	if magnetized:
		global_position = global_position.move_toward(target, MAGNET_SPEED * delta)
		if global_position.distance_to(target) <= PICKUP_RADIUS and pickup_retry <= 0.0 and world_ref.has_method("collect_world_coin"):
			pickup_retry = 0.15
			if bool(world_ref.collect_world_coin(definition)):
				collected = true
				queue_free()
	else:
		# Losing the magnet returns a coin gently to its known safe floor point.
		global_position = global_position.move_toward(settled_position, 90.0 * delta)
	queue_redraw()

func _line_open(target: Vector2) -> bool:
	# A close coin on another side of a solid wall still requires a real route.
	if global_position.is_equal_approx(target):
		return true
	var ray := PhysicsRayQueryParameters2D.create(global_position, target, 1)
	ray.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _draw() -> void:
	if collected:
		return
	var pulse: float = 0.82 + sin(age * 4.0 + visual_phase) * 0.10
	draw_circle(Vector2.ZERO, 11.5, Color(1.0, 0.53, 0.15, 0.055 * pulse))
	draw_circle(Vector2.ZERO, 8.5, Color(1.0, 0.63, 0.22, 0.10 * pulse))
	# A soft edge spin gives a little life without flicker or tiny surface marks.
	var width: float = 0.82 + absf(cos(age * 2.2 + visual_phase)) * 0.18
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(width, 1.0))
	draw_circle(Vector2(0.0, 1.0), 5.6, Color("171724"))
	draw_circle(Vector2.ZERO, 5.3, Color("b5793e"))
	draw_circle(Vector2(-0.25, -0.6), 4.2, Color("efba70"))
	draw_arc(Vector2.ZERO, 4.5, -2.9, -0.45, 10, Color("ffe5aa"), 1.0, true)
	var ember := PackedVector2Array([Vector2(-1.8, 1.9), Vector2(-1.2, -0.5), Vector2(0.5, -2.5), Vector2(0.5, -0.2), Vector2(1.8, 0.7), Vector2(0.8, 2.0)])
	draw_colored_polygon(ember, Color("9d5734"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _valid_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) <= 100000.0
