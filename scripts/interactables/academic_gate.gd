@tool
extends Node2D
signal opened
@export var texture: Texture2D
@export var source_rect := Rect2(1024, 512, 512, 512)
@export var gate_height: float = 255.0
var progress: float = 0.0
var opening: bool = false
var is_open: bool = false

func _ready() -> void:
	$Barrier.collision_layer = 1
	$Barrier.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(50, gate_height)
	$Barrier/Collision.shape = shape
	$Barrier/Collision.position = Vector2(0, -gate_height / 2)

func _process(delta: float) -> void:
	if opening and not is_open:
		progress = minf(1.0, progress + delta / 1.8)
		if progress >= 0.96:
			is_open = true
			$Barrier/Collision.set_deferred("disabled", true)
			opened.emit()
	queue_redraw()

func _draw() -> void:
	if texture:
		var ease_value := smoothstep(0.0, 1.0, progress)
		# Raise the bronze leaves behind a stationary stone frame. The atlas itself
		# remains untouched; these regions are editable pieces of the same drawing.
		var panel := Rect2(74, 142, source_rect.size.x-136, source_rect.size.y-154)
		var hidden := panel.size.y * ease_value
		if hidden < panel.size.y:
			var remaining := Rect2(panel.position + Vector2(0, hidden), Vector2(panel.size.x, panel.size.y-hidden))
			_draw_piece(remaining, Vector2(0, -hidden))
		_draw_piece(Rect2(0, 0, 74, source_rect.size.y))
		_draw_piece(Rect2(source_rect.size.x-62, 0, 62, source_rect.size.y))
		_draw_piece(Rect2(74, 0, source_rect.size.x-136, 142))
		_draw_piece(Rect2(74, source_rect.size.y-12, source_rect.size.x-136, 12))

func _draw_piece(piece: Rect2, offset := Vector2.ZERO) -> void:
	var art_scale := Vector2(180.0 / source_rect.size.x, gate_height / source_rect.size.y)
	var destination := Rect2(Vector2(-90, -gate_height) + (piece.position+offset)*art_scale, piece.size*art_scale)
	draw_texture_rect_region(texture, destination, Rect2(source_rect.position+piece.position, piece.size))

func unlock() -> void:
	opening = true
