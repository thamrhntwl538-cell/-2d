extends "res://scripts/stage/m21_foreground.gd"
## Broad near-paper groups with breathing room, not a repeated jagged stripe.
func setup(world: Node2D, room_definition: Dictionary) -> void:
	super.setup(world,room_definition)
	name="NearCuratedPaperGroups"

func _draw() -> void:
	if definition.is_empty(): return
	var room_seed := int(definition.get("id",1))*157
	for item in definition.get("platforms",[]):
		if not _active(item): continue
		var rect: Rect2 = item.get("rect",Rect2())
		if rect.size.x<170 or rect.size.y<40 or not visible_world.intersects(rect.grow(110)): continue
		# Never cover a solid obstacle or the readable top of a small landing.
		if bool(item.get("m22_added",false)) and not bool(item.get("one_way",true)): continue
		var height_limit := minf(86.0,rect.size.y-safe_lip_margin-3)
		if height_limit<22: continue
		var drift := -camera_point.x*(parallax_factor-1.0) if rect.size.x>600 else 0.0
		var rng := RandomNumberGenerator.new()
		rng.seed=room_seed+int(rect.position.x)*19+int(rect.position.y)
		var count := maxi(1,int(rect.size.x/420.0))
		for index in range(count):
			var cell_width := rect.size.x/float(count)
			var width_value := minf(cell_width*0.57,rng.randf_range(110,190))
			var local_x := cell_width*index+cell_width*rng.randf_range(0.14,0.34)+drift
			if rect.size.x>600: local_x=fposmod(local_x,maxf(1,rect.size.x-width_value))
			local_x=clampf(local_x,7,maxf(7,rect.size.x-width_value-7))
			var base := Vector2(rect.position.x+local_x,rect.position.y+safe_lip_margin+height_limit)
			if base.x>visible_world.end.x+100 or base.x+width_value<visible_world.position.x-100: continue
			var h := minf(height_limit,rng.randf_range(33,60))
			if posmod(index+room_seed,3)==0: _scroll_bundle(base,width_value,h)
			else: _closed_volumes(base,width_value,h,index+room_seed)
	_draw_camera_frame()

func _edge_piece_clear(bounds: Rect2) -> bool:
	# Edge dressing yields to every real landing and the important live actor
	# bounds. It never masks an enemy's head, warning or nearby interaction.
	var actor: Node2D = world_ref.get("hero") as Node2D
	if is_instance_valid(actor) and bounds.intersects(Rect2(actor.position-Vector2(43,210),Vector2(86,230))): return false
	var enemies: Variant = world_ref.get("enemies")
	if enemies is Array:
		for enemy in enemies:
			if is_instance_valid(enemy) and bounds.intersects(Rect2(enemy.position-Vector2(95,230),Vector2(190,270))): return false
	for item in definition.get("platforms",[]):
		if not _active(item): continue
		var rect: Rect2=item.rect
		if bounds.intersects(Rect2(rect.position-Vector2(0,11),Vector2(rect.size.x,26))): return false
	for exit in definition.get("exits",[]):
		var at: Vector2=exit.get("pos",Vector2.INF)
		if bounds.intersects(Rect2(at-Vector2(80,210),Vector2(160,235))): return false
	for item in definition.get("objects",[]):
		if str(item.get("kind","")) in ["pogo_anchor","dash_pickup","spell_pickup","fitil_pickup","capacity_pickup"]: continue
		var at: Vector2=item.get("pos",Vector2.INF)
		if bounds.intersects(Rect2(at-Vector2(80,180),Vector2(160,205))): return false
	return true

func _draw_camera_frame() -> void:
	if not is_instance_valid(world_ref): return
	var camera: Camera2D=world_ref.get("camera") as Camera2D
	if not is_instance_valid(camera): return
	var view:=get_viewport_rect().size/camera.zoom
	var origin:=camera_point-view*.5
	var unit:=view.x/1280.0
	var screen_height:=view.y/unit
	# A restrained drift gives these nearest shapes their own depth while the
	# central play space stays open. They are original book/page silhouettes.
	var drift:=sin(camera_point.x*.0012)*9.0
	var pieces: Array[Dictionary]=[
		{"bounds":Rect2(0,0,186,66),"kind":"corner_left"},
		{"bounds":Rect2(1106,0,174,58),"kind":"corner_right"},
		{"bounds":Rect2(-14,screen_height*.30+drift,58,155),"kind":"side_left"},
		{"bounds":Rect2(1240,screen_height*.39-drift,55,175),"kind":"side_right"}
	]
	for piece in pieces:
		var screen_bounds: Rect2=piece.bounds
		var bounds:=Rect2(origin+screen_bounds.position*unit,screen_bounds.size*unit)
		if not _edge_piece_clear(bounds): continue
		var p:=bounds.position
		var size_value:=bounds.size
		var shape:=PackedVector2Array()
		match str(piece.kind):
			"corner_left":
				shape.append(p)
				shape.append(p+Vector2(size_value.x,0))
				for index in range(25):
					var u:=float(index)/24.0
					shape.append(p+Vector2(size_value.x*(1-u),size_value.y*(.12+.88*pow(u,1.7))))
			"corner_right":
				shape.append(p)
				shape.append(p+Vector2(size_value.x,0))
				shape.append(p+size_value)
				for index in range(25):
					var u:=float(index)/24.0
					shape.append(p+Vector2(size_value.x*(1-u),size_value.y*(.20+.80*pow(1-u,2))))
			_:
				var left:=str(piece.kind)=="side_left"
				var edge:=0.0 if left else size_value.x
				shape.append(p+Vector2(edge,0))
				for index in range(25):
					var u:=float(index)/24.0
					var inward:=size_value.x*(.34+.53*sin(u*PI))
					shape.append(p+Vector2(inward if left else size_value.x-inward,u*size_value.y))
				shape.append(p+Vector2(edge,size_value.y))
		draw_colored_polygon(shape,Color("060b13"))
		if str(piece.kind).begins_with("side"):
			var edge_x:=p.x+size_value.x*(.37 if str(piece.kind)=="side_left" else .63)
			draw_line(Vector2(edge_x,p.y+size_value.y*.16),Vector2(edge_x,p.y+size_value.y*.84),Color("111a27"),2.2*unit,true)

func _closed_volumes(base: Vector2, width_value: float, h: float, seed_value: int) -> void:
	var tint := Color("0b111c")
	# An uneven broad pair of low books. No bar joins one group to the next.
	var first := PackedVector2Array([base+Vector2(-4,3),base+Vector2(0,-h*.45),base+Vector2(width_value*.80,-h*.52),base+Vector2(width_value*.83,3)])
	draw_colored_polygon(first,tint)
	var shift := width_value*.12 if seed_value%2==0 else width_value*.05
	var top := PackedVector2Array([base+Vector2(shift,-h*.42),base+Vector2(shift+3,-h),base+Vector2(width_value*.68,-h*.93),base+Vector2(width_value*.71,-h*.44)])
	draw_colored_polygon(top,Color("101723"))
	draw_line(base+Vector2(shift+8,-h*.84),base+Vector2(width_value*.64,-h*.79),Color("1a2330"),1.6,true)

func _scroll_bundle(base: Vector2, width_value: float, h: float) -> void:
	var outline := PackedVector2Array()
	var centre := base+Vector2(width_value*.48,-h*.13)
	for step in range(25):
		var angle := PI+PI*float(step)/24.0
		outline.append(centre+Vector2(cos(angle)*width_value*.43,sin(angle)*h*.86))
	outline.append(base+Vector2(width_value*.92,4))
	outline.append(base+Vector2(.03*width_value,4))
	draw_colored_polygon(outline,Color("0b121e"))
	draw_arc(centre+Vector2(-width_value*.18,-h*.10),h*.18,PI*1.05,TAU*.96,22,Color("1a2430"),1.6,true)
