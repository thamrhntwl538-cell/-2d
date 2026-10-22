extends Node2D
## An original short ink-cleave wave. The actor owns its travel and hit list;
## the world's melee path alone awards energy, so spells cannot refill spells.

const SPEED := 650.0
const MAX_LIFETIME := 1.0
const DAMAGE := 2
const HIT_SIZE := Vector2(22.0, 36.0)
var world_ref: Node
var direction: int = 1
var age: float = 0.0
var hit_enemies: Array[int] = []
var _configured: bool = false
var _spent: bool = false

func setup(world: Node, at: Vector2, facing: int) -> void:
	world_ref = world
	global_position = at
	direction = 1 if facing >= 0 else -1
	_configured = true
	z_index = 7
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _spent or not _configured:
		return
	if not is_instance_valid(world_ref):
		queue_free()
		return
	if not bool(world_ref.get("gameplay_active")):
		return
	age += delta
	if age >= MAX_LIFETIME:
		_spent = true
		queue_free()
		return
	var start: Vector2 = global_position
	var end: Vector2 = start + Vector2(float(direction) * SPEED * delta, 0.0)
	# Raycast along the leading edge as well as the center, so the visible
	# wave cannot clip through a thin obstacle before the next physics tick.
	for offset in [Vector2(float(direction) * 19.0, -15.0), Vector2(float(direction) * 19.0, 0.0), Vector2(float(direction) * 19.0, 15.0)]:
		var ray := PhysicsRayQueryParameters2D.create(start + offset, end + offset, 1)
		ray.hit_from_inside = true
		var wall: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
		if not wall.is_empty():
			global_position = wall.position - offset
			_finish(false)
			return
	global_position = end
	var traveled: float = absf(end.x - start.x)
	var hit_rect := Rect2(Vector2(minf(start.x, end.x) - HIT_SIZE.x * 0.5, end.y - HIT_SIZE.y * 0.5), Vector2(HIT_SIZE.x + traveled, HIT_SIZE.y))
	var actors: Variant = world_ref.get("enemies")
	if actors is Array:
		for actor in actors:
			if not is_instance_valid(actor) or bool(actor.get("is_dead")):
				continue
			var identity: int = actor.get_instance_id()
			if hit_enemies.has(identity) or not actor.has_method("get_hitbox") or not actor.has_method("take_hit"):
				continue
			if hit_rect.intersects(actor.get_hitbox()):
				# Mark before the callback, since a real defeat can remove this
				# actor from the world's list synchronously.
				hit_enemies.append(identity)
				if bool(actor.take_hit(DAMAGE, global_position.x, "spell")):
					_finish(true)
					return
	queue_redraw()

func _finish(hit: bool) -> void:
	if _spent:
		return
	_spent = true
	if is_instance_valid(world_ref):
		if world_ref.has_method("emit_burst"):
			world_ref.emit_burst(global_position, Color("9de4df"), 8 if hit else 4)
		if hit and world_ref.has_method("play_sfx"):
			world_ref.play_sfx("hit")
	queue_free()

func _draw() -> void:
	var fade: float = minf(1.0, (MAX_LIFETIME - age) * 6.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(direction), 1.0))
	var outer := PackedVector2Array([Vector2(-34,-14), Vector2(-14,-10), Vector2(4,-22), Vector2(19,0), Vector2(4,22), Vector2(-14,10), Vector2(-34,14), Vector2(-21,0)])
	var core := PackedVector2Array([Vector2(-22,-7), Vector2(-5,-7), Vector2(6,-16), Vector2(15,0), Vector2(6,16), Vector2(-5,7), Vector2(-22,7), Vector2(-11,0)])
	draw_colored_polygon(outer, Color(0.29,0.77,0.82,0.16 * fade))
	draw_colored_polygon(core, Color(0.83,0.93,0.82,0.88 * fade))
	draw_polyline(PackedVector2Array([Vector2(4,-19), Vector2(17,0), Vector2(4,19)]), Color(0.64,0.94,0.92,fade),2.0,true)
	draw_line(Vector2(-32,-5),Vector2(-11,-5),Color(0.37,0.84,0.88,0.36*fade),1.2,true)
	draw_line(Vector2(-37,6),Vector2(-17,6),Color(0.37,0.84,0.88,0.22*fade),1.1,true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
