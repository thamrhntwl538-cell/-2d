extends "res://scripts/stage/m22_foreground.gd"
## The bindery has a fixed wide encounter camera. Keep its body/air space open.
func setup(world: Node2D, room_definition: Dictionary) -> void:
	super.setup(world,room_definition)
	name="BellSafePaperForeground"

func _draw_camera_frame() -> void:
	if int(definition.get("id",0))!=12:
		super._draw_camera_frame()
		return
	if not is_instance_valid(world_ref): return
	var camera: Camera2D=world_ref.get("camera") as Camera2D
	if not is_instance_valid(camera): return
	var view:=get_viewport_rect().size/camera.zoom
	var origin:=camera_point-view*.5
	var unit:=view.x/1280.0
	# Small page folds live at the top corners only. Tall side silhouettes
	# would overlap the whole hero or airborne bell at the combat extremes.
	var left:=Rect2(origin,Vector2(116,34)*unit)
	var right:=Rect2(origin+Vector2(view.x-110*unit,0),Vector2(110,30)*unit)
	if _edge_piece_clear(left):
		draw_colored_polygon(PackedVector2Array([left.position,left.position+Vector2(left.size.x,0),left.position+Vector2(left.size.x*.35,left.size.y*.42),left.position+Vector2(0,left.size.y)]),Color("070c15"))
	if _edge_piece_clear(right):
		draw_colored_polygon(PackedVector2Array([right.position,right.position+Vector2(right.size.x,0),right.end,right.position+Vector2(right.size.x*.68,right.size.y*.34)]),Color("070c15"))
