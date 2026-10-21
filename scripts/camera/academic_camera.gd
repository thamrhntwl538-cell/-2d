extends Camera2D
## Stable room camera: a dead band absorbs jump bob, while climbing moves the view.
@export var room_rect := Rect2(0, 0, 3840, 1440)
var target: Node2D

func _ready() -> void:
	limit_left = int(room_rect.position.x)
	limit_top = int(room_rect.position.y)
	limit_right = int(room_rect.end.x)
	limit_bottom = int(room_rect.end.y)
	position_smoothing_enabled = false
	if target:
		position = bounded(target.position + Vector2(130, -230))
	reset_smoothing()

func bounded(point: Vector2) -> Vector2:
	var half_view := get_viewport_rect().size / zoom / 2.0
	return point.clamp(room_rect.position + half_view, room_rect.end - half_view)

func _process(delta: float) -> void:
	if not is_instance_valid(target): return
	var desired := position
	var look := target.position.x + 110.0
	if absf(look - position.x) > 90.0:
		desired.x = look - signf(look - position.x) * 90.0
	var vertical := target.position.y - 230.0
	if absf(vertical - position.y) > 70.0:
		desired.y = vertical - signf(vertical - position.y) * 70.0
	position = bounded(position.lerp(bounded(desired), 1.0 - exp(-4.0 * delta)))
