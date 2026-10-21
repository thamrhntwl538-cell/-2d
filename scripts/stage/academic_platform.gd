@tool
extends StaticBody2D
## Reusable painted ledge. Local y=0 is the exact top of both art and collision.
@export var width: float = 240.0:
	set(value):
		width = value
		queue_redraw()
@export var depth: float = 54.0
@export var support_height: float = 0.0
@export var one_way: bool = true
@export var texture: Texture2D
@export var source_rect := Rect2(0, 0, 512, 512)

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var collider := get_node_or_null("Collision") as CollisionShape2D
	if collider == null:
		collider = CollisionShape2D.new()
		collider.name = "Collision"
		add_child(collider)
	var box := RectangleShape2D.new()
	box.size = Vector2(width, depth + support_height)
	collider.shape = box
	collider.position = Vector2(width / 2.0, (depth + support_height) / 2.0)
	collider.one_way_collision = one_way
	collider.one_way_collision_margin = 8.0

func _draw() -> void:
	if texture:
		if support_height > 0.0:
			# A low starting ledge is a solid masonry pedestal; the full-size
			# lantern cannot visually intersect a low one-way ceiling underneath.
			var support_y := 10.0
			while support_y < depth + support_height:
				var row_height := minf(35, depth + support_height - support_y)
				draw_texture_rect_region(texture, Rect2(0, support_y, width, row_height), Rect2(104, 247, 482, 73))
				support_y += row_height
		# Preserve end caps, repeat the stone centre instead of stretching masonry.
		var cap := minf(width / 3.0, 40.0)
		var source_cap := source_rect.size.x * 0.12
		draw_texture_rect_region(texture, Rect2(0, 0, cap, depth), Rect2(source_rect.position, Vector2(source_cap, source_rect.size.y)))
		draw_texture_rect_region(texture, Rect2(width-cap, 0, cap, depth), Rect2(source_rect.end.x-source_cap, source_rect.position.y, source_cap, source_rect.size.y))
		var x := cap
		while x < width-cap-0.1:
			var piece := minf(190.0, width-cap-x)
			draw_texture_rect_region(texture, Rect2(x, 0, piece, depth), Rect2(source_rect.position.x+source_cap, source_rect.position.y, source_rect.size.x-source_cap*2, source_rect.size.y))
			x += piece
