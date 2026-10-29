extends "res://scripts/stage/m28_foreground.gd"
## Original near-book silhouette framing. Nothing here changes collision.
func _draw_camera_frame() -> void:
	if not is_instance_valid(world_ref): return
	var camera: Camera2D=world_ref.get("camera") as Camera2D
	if not is_instance_valid(camera): return
	var view:=get_viewport_rect().size/camera.zoom
	var origin:=camera_point-view*.5
	var unit:=view.x/1280.0
	var inside:=not str(definition.get("m29_interior","")).is_empty()
	var tint:=Color("050912")
	# Broad curved bindings at the ceiling make the room feel enclosed, while
	# the centre remains entirely clear for jump arcs and enemy silhouettes.
	for side in [-1.0,1.0]:
		var left: bool=side<0
		var base:=origin+Vector2(0 if left else view.x,0)
		var points:=PackedVector2Array([base])
		for i in range(25):
			var u:=float(i)/24
			var x:=u*(330.0 if inside else 210.0)*unit
			var y:=(14.0+pow(1.0-u,2.4)*(77.0 if inside else 48.0))*unit
			points.append(base+Vector2(x if left else -x,y))
		points.append(base+Vector2((330.0 if inside else 210.0)*unit*(1 if left else -1),0))
		draw_colored_polygon(points,tint)
	var lower:=origin+Vector2(0,view.y-5*unit)
	for side in [-1.0,1.0]:
		var x:=28.0 if side<0 else 1192.0
		var bounds:=Rect2(origin+Vector2(x,view.y/unit-180)*unit,Vector2(58,180)*unit)
		if _edge_piece_clear(bounds):
			var p:=bounds.position
			var silhouette:=PackedVector2Array([p+Vector2(0,180)*unit,p+Vector2(4,42)*unit,p+Vector2(19,0)*unit,p+Vector2(49,12)*unit,p+Vector2(57,180)*unit])
			draw_colored_polygon(silhouette,tint)
			draw_line(p+Vector2(17,24)*unit,p+Vector2(18,165)*unit,Color("101724"),2*unit,true)
