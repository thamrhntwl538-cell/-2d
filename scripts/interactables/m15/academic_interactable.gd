@tool
extends Node2D
class_name M15AcademicInteractable
## A painted, non-solid academic object. The stage owns range checks and HUD text.
## Small screen/cursor/lever accents below are procedural supporting effects.

signal activated(id: String)

const DEFAULT_KIT = preload("res://assets/environments/silent_entrance/academic_kit.png")

@export_enum("terminal", "bench", "lever", "note") var kind: String = "terminal":
	set(value):
		kind = value
		queue_redraw()
@export var id: String = ""
@export var label: String = ""
@export var texture: Texture2D = DEFAULT_KIT:
	set(value):
		texture = value
		queue_redraw()
## A zero-size rectangle selects the painted region appropriate to kind.
@export var source_rect := Rect2():
	set(value):
		source_rect = value
		queue_redraw()
## Bench and elevator call switches can opt into repeated activation.
@export var can_repeat: bool = false
@export var active: bool = false:
	set(value):
		active = value
		queue_redraw()
var elapsed: float = 0.0
var activation_pulse: float = 0.0

func _process(delta: float) -> void:
	elapsed += delta
	activation_pulse = maxf(0.0, activation_pulse - delta * 1.8)
	queue_redraw()

func activate() -> bool:
	if active and not can_repeat:
		return false
	active = true
	activation_pulse = 1.0
	activated.emit(id)
	return true

func _region() -> Rect2:
	if source_rect.size.x > 0.0 and source_rect.size.y > 0.0:
		return source_rect
	match kind:
		"bench": return Rect2(53, 720, 605, 214)
		"note": return Rect2(1120, 162, 63, 88)
	return Rect2(721, 507, 216, 458)

func visual_size() -> Vector2:
	match kind:
		"bench": return Vector2(176, 62)
		"note": return Vector2(28, 37)
	return Vector2(82, 122)

func _draw() -> void:
	var size := visual_size()
	var tint := Color.WHITE
	if kind == "note" and active:
		tint = Color(0.8, 0.85, 0.84, 0.34)
	if texture:
		draw_texture_rect_region(texture, Rect2(-size.x / 2.0, -size.y, size.x, size.y), _region(), tint)
	var wave := (sin(elapsed * 1.8) + 1.0) * 0.5
	var glow_alpha := 0.065 + wave * 0.025 + activation_pulse * 0.07
	match kind:
		"bench":
			draw_circle(Vector2(0, -32), 34, Color(0.73, 0.57, 0.31, glow_alpha * 0.65))
		"note":
			if not active:
				draw_circle(Vector2(0, -44), 2.5, Color(0.78, 0.75, 0.60, 0.4 + wave * 0.2))
		"lever":
			var pivot := Vector2(2, -58)
			var tip := pivot + Vector2(17 if active else -17, -25)
			draw_line(pivot, tip, Color("8e7853"), 4.0, true)
			draw_circle(tip, 5.0, Color("8bb7b3") if active else Color("baa17a"))
			draw_circle(Vector2(0, -90), 20, Color(0.37, 0.64, 0.66, glow_alpha))
		_:
			draw_circle(Vector2(0, -91), 21, Color(0.37, 0.64, 0.66, glow_alpha))
			if active:
				draw_line(Vector2(-7, -93), Vector2(-1, -88), Color("bdd8ce"), 1.5, true)
				draw_line(Vector2(-1, -88), Vector2(10, -99), Color("bdd8ce"), 1.5, true)
			elif fmod(elapsed, 1.6) < 0.9:
				draw_line(Vector2(3, -87), Vector2(10, -87), Color("7aa9ad"), 1.2, true)
