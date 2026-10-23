extends Node2D
## A straight, swept projectile. World terrain is tested before the clipped
## hero segment, so a thin bookcase blocks even a fast shot without tunnelling.

const RADIUS := 5.0
var world_ref: Node
var source_ref: WeakRef
var travel := Vector2.ZERO
var lifetime := 3.0
var age := 0.0
var spent := false
var blocked_by_cover := false
var hit_hero := false

func setup(world: Node, source: Node2D, origin: Vector2, speed: Vector2) -> void:
	world_ref = world
	source_ref = weakref(source)
	global_position = origin
	travel = speed
	rotation = travel.angle()
	add_to_group("m22_hostile_projectiles")
	z_index = 7
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unlit
	queue_redraw()

func _physics_process(delta: float) -> void:
	if spent or not is_instance_valid(world_ref): return
	if not bool(world_ref.get("gameplay_active")): return
	var source := source_ref.get_ref() as Node2D if source_ref != null else null
	if not is_instance_valid(source) or bool(source.get("is_dead")):
		consume()
		return
	if source.has_method("projectile_can_continue") and not bool(source.projectile_can_continue()):
		consume()
		return
	if world_ref.has_method("enemy_can_attack") and not bool(world_ref.enemy_can_attack(source)):
		consume()
		return
	age += delta
	if age >= lifetime:
		consume()
		return
	var origin := global_position
	var destination := origin + travel * delta
	var query := PhysicsRayQueryParameters2D.create(origin, destination, 1)
	var obstruction := get_world_2d().direct_space_state.intersect_ray(query)
	var clipped: Vector2 = obstruction.get("position", destination)
	var hero := world_ref.get("hero") as Node2D
	if is_instance_valid(hero) and hero.has_method("get_hurtboxes"):
		for box in hero.get_hurtboxes():
			if segment_hits_box(origin, clipped, (box as Rect2).grow(RADIUS)):
				global_position = clipped
				hit_hero = true
				hero.hurt(1, source.global_position.x)
				consume()
				return
	global_position = clipped
	if not obstruction.is_empty():
		blocked_by_cover = true
		if world_ref.has_method("emit_burst"):
			world_ref.emit_burst(clipped, Color("8ae0e9"), 4)
		consume()
	queue_redraw()

static func segment_hits_box(start: Vector2, finish: Vector2, box: Rect2) -> bool:
	var delta := finish - start
	var near := 0.0
	var far := 1.0
	for axis in range(2):
		if absf(delta[axis]) < 0.00001:
			if start[axis] < box.position[axis] or start[axis] > box.end[axis]: return false
		else:
			var a: float = (box.position[axis] - start[axis]) / delta[axis]
			var b: float = (box.end[axis] - start[axis]) / delta[axis]
			near = maxf(near, minf(a, b))
			far = minf(far, maxf(a, b))
			if near > far: return false
	return true

func consume() -> void:
	if spent: return
	spent = true
	visible = false
	queue_free()

func _draw() -> void:
	draw_line(Vector2(-26,0), Vector2(-5,0), Color(0.33,0.84,0.94,0.20), 5, true)
	draw_line(Vector2(-15,0), Vector2.ZERO, Color("78d4e3"), 3, true)
	var diamond := PackedVector2Array([Vector2(10,0),Vector2(0,-5),Vector2(-5,0),Vector2(0,5)])
	draw_colored_polygon(diamond, Color("d5faf4"))
	draw_polyline(PackedVector2Array([Vector2(-11,-5),Vector2(-16,0),Vector2(-11,5)]),Color("74d3e3"),1.4,true)
