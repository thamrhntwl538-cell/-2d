@tool
extends AnimatableBody2D
class_name M15AcademicElevator
## A real fixed-physics lift. CharacterBody2D riders use native platform velocity;
## no actor parenting, position assignment, or teleport is used for the ride.
signal departed(from_stop: int, to_stop: int)
signal arrived(stop_index: int)

const DEFAULT_TEXTURE = preload("res://assets/environments/silent_entrance/academic_kit.png")
@export var positions: Array[Vector2] = [Vector2(1000, 2700), Vector2(1000, 1740), Vector2(1000, 660)]
@export var current_stop: int = 0
@export var width: float = 220.0:
	set(value):
		width = maxf(80.0, value)
		if is_inside_tree(): _rebuild_shape()
		queue_redraw()
@export var speed: float = 160.0
@export var acceleration: float = 220.0
@export var texture: Texture2D = DEFAULT_TEXTURE
@export var source_rect := Rect2(34, 204, 634, 173)
@export var draw_cables: bool = true
var moving: bool = false
var target_stop: int = 0
var travel_speed: float = 0.0
var travelled_distance: float = 0.0
var _motion_target := Vector2.ZERO
var _cable_top: float = 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	# Native AnimatableBody2D velocity is made available to platform riders.
	sync_to_physics = true
	_rebuild_shape()
	if not positions.is_empty():
		current_stop = clampi(current_stop, 0, positions.size()-1)
		position = positions[current_stop]
		target_stop = current_stop
		_motion_target = position
		_cable_top = positions[0].y
		for point in positions: _cable_top = minf(_cable_top, point.y)
	queue_redraw()

func _rebuild_shape() -> void:
	var collider := get_node_or_null("Collision") as CollisionShape2D
	if collider == null:
		collider = CollisionShape2D.new()
		collider.name = "Collision"
		add_child(collider)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, 24.0)
	collider.shape = shape
	collider.position = Vector2(0, 12)
	collider.one_way_collision = true
	collider.one_way_collision_margin = 8.0

func configure_stops(points: Array, initial_stop: int = 0) -> void:
	positions.clear()
	for point in points:
		if point is Vector2: positions.append(point)
	current_stop = clampi(initial_stop, 0, maxi(positions.size()-1, 0))
	if is_inside_tree() and not positions.is_empty():
		position = positions[current_stop]
		target_stop = current_stop
		_motion_target = position
		moving = false
		travel_speed = 0.0
		_cable_top = positions[0].y
		for point in positions: _cable_top = minf(_cable_top, point.y)

func trigger() -> bool:
	if moving or positions.size() < 2: return false
	return request_stop((current_stop+1) % positions.size())

func request_stop(stop_index: int) -> bool:
	if moving or stop_index < 0 or stop_index >= positions.size(): return false
	if position.distance_to(positions[stop_index]) < 0.1:
		current_stop = stop_index
		return false
	target_stop = stop_index
	_motion_target = positions[target_stop]
	travel_speed = 0.0
	moving = true
	departed.emit(current_stop, target_stop)
	return true

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not moving: return
	var remaining := position.distance_to(_motion_target)
	# Acceleration and braking keep take-off/arrival restrained. The final step
	# lands at the exact stop rather than accumulating floating point error.
	var desired_speed := minf(maxf(1.0, speed), sqrt(2.0 * maxf(1.0, acceleration) * remaining))
	travel_speed = move_toward(travel_speed, desired_speed, maxf(1.0, acceleration) * delta)
	var old_position := position
	position = position.move_toward(_motion_target, minf(remaining, travel_speed * delta))
	travelled_distance += old_position.distance_to(position)
	if position.distance_to(_motion_target) <= 0.08:
		position = _motion_target
		current_stop = target_stop
		moving = false
		travel_speed = 0.0
		arrived.emit(current_stop)
	queue_redraw()

func _draw() -> void:
	if draw_cables and not positions.is_empty():
		# Supporting cable lines are procedural effects, not final painted art.
		var cable_length := maxf(180.0, position.y - _cable_top + 190.0)
		for x in [-width*0.40, width*0.40]:
			draw_line(Vector2(x, -cable_length), Vector2(x, 9), Color("29343c"), 4.0, true)
			draw_line(Vector2(x-0.8, -cable_length), Vector2(x-0.8, 9), Color("6a6049"), 1.0, true)
	if texture:
		draw_texture_rect_region(texture, Rect2(-width/2, 0, width, 55), source_rect)
	# Small ivory stop indicator stays below the standing surface.
	for index in range(positions.size()):
		var tone := Color("9ab8b4") if index == current_stop and not moving else Color("5b5547")
		draw_circle(Vector2((index-(positions.size()-1)/2.0)*12, 27), 2.3, tone)
