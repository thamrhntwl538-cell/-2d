@tool
extends Node2D
signal activated
@export var texture: Texture2D
@export var source_rect := Rect2(512, 512, 512, 512)
var active: bool = false
var time: float = 0.0

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	if texture:
		draw_texture_rect_region(texture, Rect2(-41, -122, 82, 122), source_rect)
	var cyan := Color("9ad9d5") if active else Color("568f9d")
	cyan.a = 0.15 + sin(time * 2.0) * 0.04
	draw_circle(Vector2(0, -90), 18, cyan)

func activate() -> void:
	if active: return
	active = true
	activated.emit()
