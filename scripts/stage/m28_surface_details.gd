extends Node2D
## Exact solid-volume covers above the generic paper surfaces, below actors.
var world_ref: Node2D
var definition: Dictionary
func setup(world: Node2D, data: Dictionary) -> void:
	world_ref=world
	definition=data
	name="BoundVolumeCollisionFacesM28"
	z_index=8 # Parent is world-6, so this is world2; hero remains world5.

func _draw() -> void:
	for item in definition.get("m28_hurdles",[]):
		var r: Rect2=item.rect
		var style:=StyleBoxFlat.new()
		style.bg_color=Color("343641")
		style.border_color=Color("72634c")
		style.set_border_width_all(2)
		style.set_corner_radius_all(5)
		draw_style_box(style,Rect2(r.position+Vector2(1,1),r.size-Vector2(2,2)))
		for y in [r.position.y+13,r.end.y-15]:
			draw_line(Vector2(r.position.x+6,y),Vector2(r.end.x-6,y),Color("ac8f60"),4,true)
		draw_line(r.position+Vector2(5,1),Vector2(r.end.x-4,r.position.y+1),Color("d4b785"),2,true)
		draw_line(r.position+Vector2(12,20),Vector2(r.position.x+12,r.end.y-21),Color("191f2b"),3,true)
