extends Node2D
## Near book/page silhouettes sit below real landing lips. They are decoration,
## not collision geometry, and never rise into the hero's foot baseline.
var world_ref: Node2D
var definition: Dictionary = {}
var camera_point := Vector2.ZERO
var visible_world := Rect2()
var parallax_factor := 1.08
var safe_lip_margin := 11.0

func setup(world: Node2D, room_definition: Dictionary) -> void:
	world_ref = world
	definition = room_definition
	z_as_relative = false
	z_index = 18
	name = "NearPaperSilhouettes"
	queue_redraw()

func _process(_delta: float) -> void:
	if not is_instance_valid(world_ref): return
	var camera: Camera2D = world_ref.get("camera") as Camera2D
	if camera:
		camera_point = camera.position
		visible_world = Rect2(camera_point-get_viewport_rect().size/camera.zoom*0.5,get_viewport_rect().size/camera.zoom).grow(100)
	queue_redraw()

func _active(item: Dictionary) -> bool:
	if is_instance_valid(world_ref) and world_ref.has_method("_requirements_met"):
		return world_ref._requirements_met(item.get("requires",""))
	return true

func _draw() -> void:
	if definition.is_empty(): return
	for item in definition.get("platforms",[]):
		if not _active(item): continue
		var rect: Rect2 = item.get("rect",Rect2())
		if rect.size.x<70 or rect.size.y<25 or not visible_world.intersects(rect.grow(70)): continue
		var top := rect.position.y+safe_lip_margin
		var band_height := minf(72.0,rect.size.y-safe_lip_margin)
		if band_height<12: continue
		# A low ink band unifies nearby overlapping page fragments.
		draw_rect(Rect2(rect.position.x,top+band_height*0.56,rect.size.x,band_height*0.44+5),Color("080d16"))
		var count := maxi(1,int(rect.size.x/115.0))
		var drift := -camera_point.x*(parallax_factor-1.0) if rect.size.x>600 else 0.0
		for i in range(count+1):
			var seed_value := i*37+int(definition.get("id",1))*13
			var offset := fposmod(float(i)*115.0+drift,maxf(1,rect.size.x-50))
			var x := rect.position.x+10+offset
			if x<visible_world.position.x-80 or x>visible_world.end.x+80: continue
			var height_value := minf(band_height,float(22+posmod(seed_value,37)))
			var base := top+band_height
			var tint := Color("0a101b") if i%2 else Color("0d1420")
			match posmod(seed_value,3):
				0:
					# Closed books: large quiet cover and a single worn page lip.
					draw_colored_polygon(PackedVector2Array([Vector2(x,base),Vector2(x+3,base-height_value),Vector2(x+31,base-height_value-3),Vector2(x+37,base),Vector2(x,base)]),tint)
					draw_line(Vector2(x+6,base-height_value+5),Vector2(x+28,base-height_value+2),Color("17202c"),1.2,true)
				1:
					# Rolled sheets resemble a near paper audience without creatures.
					var centre := Vector2(x+18,base-height_value*0.42)
					var points := PackedVector2Array()
					for n in range(19):
						var angle := PI+PI*float(n)/18.0
						points.append(centre+Vector2(cos(angle)*22,sin(angle)*height_value*0.65))
					points.append(Vector2(x+40,base+5))
					points.append(Vector2(x-4,base+5))
					draw_colored_polygon(points,tint)
					draw_arc(centre,8,PI*1.15,TAU,16,Color("17202c"),1.2,true)
				2:
					# Folded margins and bent bookmarks, kept below the walkable top.
					draw_colored_polygon(PackedVector2Array([Vector2(x-2,base+4),Vector2(x+6,base-height_value),Vector2(x+22,base-height_value*0.65),Vector2(x+31,base-height_value*0.9),Vector2(x+47,base+4)]),tint)
					draw_line(Vector2(x+8,base-height_value+5),Vector2(x+21,base-height_value*0.60),Color("19222e"),1.0,true)
