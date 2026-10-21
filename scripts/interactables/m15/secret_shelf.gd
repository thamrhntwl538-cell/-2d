@tool
extends Node2D
class_name M15SecretShelf
## A solid, painted shelf guarding a real route. The stage owns the lever flag;
## this scene only handles the visible slide and its matching collision release.
signal opened

const DEFAULT_TEXTURE = preload("res://assets/environments/forgotten_wing/props.png")
@export var texture: Texture2D = DEFAULT_TEXTURE
@export var source_rect := Rect2(730, 10, 348, 490)
@export var art_size := Vector2(90, 200)
@export var slide_distance: float = -90.0
@export var duration: float = 1.0
var progress: float = 0.0
var opening: bool = false
var is_open: bool = false

func _ready() -> void:
	$Barrier.collision_layer = 1
	$Barrier.collision_mask = 0
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(70, 200)
	$Barrier/Collision.shape = rectangle
	$Barrier/Collision.position = Vector2(0, -100)
	queue_redraw()

func unlock() -> void:
	opening = true

func _process(delta: float) -> void:
	if not Engine.is_editor_hint() and opening and not is_open:
		progress = minf(1.0, progress + delta / maxf(0.05, duration))
		if progress >= 0.9:
			# At 90% the painted right edge has cleared the original barrier.
			is_open = true
			$Barrier/Collision.set_deferred("disabled", true)
			opened.emit()
	elif not Engine.is_editor_hint() and opening and progress < 1.0:
		progress = minf(1.0, progress + delta / maxf(0.05, duration))
	queue_redraw()

func _draw() -> void:
	if not texture: return
	var eased := smoothstep(0.0, 1.0, clampf(progress, 0.0, 1.0))
	var position_offset := Vector2(slide_distance * eased, 0)
	draw_texture_rect_region(texture, Rect2(Vector2(-art_size.x/2.0, -art_size.y)+position_offset, art_size), source_rect)
