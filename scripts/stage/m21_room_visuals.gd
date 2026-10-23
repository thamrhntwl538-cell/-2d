extends "res://scripts/stage/m17_room_visuals.gd"
## M21 close, layered paper rooms. Lighting affects the real world canvas;
## the painted wall and HUD keep their own canvas presentation.
const Foreground = preload("res://scripts/stage/m21_foreground.gd")
const CLOSE_LIBRARY := "res://assets/environments/paper_shadows/close_library.png"
const CLOSE_ARCHIVE := "res://assets/environments/paper_shadows/close_archive.png"
var ambient_color := Color(0.29,0.32,0.39,1.0)
var ambient: CanvasModulate
var light_anchors: Array[Vector2] = []
var light_specs: Array[Dictionary] = []
var reading_lights: Array[PointLight2D] = []
var depth_layers := PackedStringArray(["close_painted_wall","near_room_objects","front_paper_silhouettes"])
var close_backdrop_loaded := false
var foreground: Node2D
var wall_lantern_light: PointLight2D
var far_parallax_factor := 0.28
var mid_parallax_factor := 0.78
var _light_texture: Texture2D

func setup(world: Node2D, room_definition: Dictionary) -> void:
	world_ref = world
	definition = room_definition
	room_id = int(definition.get("id",1))
	room_size = definition.get("size",Vector2(3840,1440))
	floor_y = float(definition.get("floor_y",room_size.y-180))
	z_index = -6
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var path := CLOSE_ARCHIVE if room_id in [6,10,12,13,14,15] else CLOSE_LIBRARY
	if ResourceLoader.exists(path):
		far_texture = load(path) as Texture2D
		close_backdrop_loaded = far_texture!=null
	# The old towering painted open-book arch is deliberately not loaded.
	arch_texture = null
	portal_texture = null
	_light_texture = _make_ready_light_texture()
	ambient = CanvasModulate.new()
	ambient.name = "PaperRoomAmbient"
	ambient.color = ambient_color
	add_child(ambient)
	_build_far_layer()
	_build_lights()
	foreground = Foreground.new()
	add_child(foreground)
	foreground.setup(world,definition)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2100+room_id*31
	for i in range(clampi(int(room_size.x/190.0),14,30)):
		dust.append({"base":Vector2(rng.randf_range(0,room_size.x),rng.randf_range(120,room_size.y-100)),"phase":rng.randf_range(0,TAU),"speed":rng.randf_range(1.8,4.2)})
	_update_far_layer()
	queue_redraw()

func _make_ready_light_texture() -> Texture2D:
	var image := Image.create(128,128,false,Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var radius := Vector2(x-63.5,y-63.5).length()/64.0
			var alpha := pow(maxf(0,1.0-radius),1.7)
			image.set_pixel(x,y,Color(1,1,1,alpha))
	return ImageTexture.create_from_image(image)

func _build_far_layer() -> void:
	far_layer = CanvasLayer.new()
	far_layer.name = "ClosePaperWall"
	far_layer.layer = -18
	add_child(far_layer)
	var base := ColorRect.new()
	base.name = "QuietInkBackdrop"
	base.color = Color("0b101b")
	base.size = Vector2(1280,720)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	far_layer.add_child(base)
	if far_texture:
		for i in range(3):
			var sprite := Sprite2D.new()
			sprite.name = "CloseMirroredWall_%d"%i
			sprite.texture = far_texture
			sprite.centered = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			sprite.modulate = Color(0.94,0.96,1.0,1.0)
			far_layer.add_child(sprite)
			far_sprites.append(sprite)
	wall_lantern_light = PointLight2D.new()
	wall_lantern_light.name = "LanternOnCloseWall"
	wall_lantern_light.texture = _light_texture
	wall_lantern_light.color = Color("f3ae68")
	wall_lantern_light.energy = 0.27
	wall_lantern_light.range_layer_min = -18
	wall_lantern_light.range_layer_max = -18
	far_layer.add_child(wall_lantern_light)

func _append_lamp(foot: Vector2, height_value := 145.0, energy_value := 0.72) -> void:
	for spec in light_specs:
		if (spec.foot as Vector2).distance_to(foot)<200: return
	light_specs.append({"foot":foot,"height":height_value,"energy":energy_value})

func _build_lights() -> void:
	if room_id==6:
		for y in [2700.0,1980.0,1260.0,540.0]:
			_append_lamp(Vector2(370,y+16),146,0.76)
			_append_lamp(Vector2(room_size.x-330,y+16),146,0.68)
	else:
		_append_lamp(Vector2(320,floor_y+16),148,0.74)
		if room_id==2: _append_lamp(Vector2(1260,floor_y+16),160,0.84)
		for item in definition.get("objects",[]):
			var kind := str(item.get("kind",""))
			if kind=="bench" or kind.ends_with("_control"):
				_append_lamp((item.get("pos",Vector2.ZERO) as Vector2)+Vector2(-140,16),148,0.72)
		var exits: Array = definition.get("exits",[])
		if not exits.is_empty():
			var target: Vector2 = exits[exits.size()-1].get("pos",Vector2(room_size.x-200,floor_y))
			_append_lamp(target+Vector2(-125,16),148,0.66)
		if light_specs.size()<3:
			_append_lamp(Vector2(room_size.x*0.56,floor_y+16),160,0.62)
	for index in range(light_specs.size()):
		var spec: Dictionary = light_specs[index]
		var position_value: Vector2 = spec.foot-Vector2(0,float(spec.height))
		light_anchors.append(position_value)
		var point := PointLight2D.new()
		point.name = "ActualReadingPool_%02d"%index
		point.texture = _light_texture
		point.position = position_value
		point.color = Color("edbb77")
		point.energy = float(spec.energy)
		point.texture_scale = 4.0
		point.range_layer_min = 0
		point.range_layer_max = 0
		add_child(point)
		reading_lights.append(point)

func _update_far_layer() -> void:
	if not is_instance_valid(world_ref): return
	var camera: Camera2D = world_ref.get("camera") as Camera2D
	_camera_point = camera.position if camera else Vector2.ZERO
	var view := get_viewport_rect().size
	var zoom_value := camera.zoom if camera else Vector2.ONE
	var visible_size := view/zoom_value
	_visible_world = Rect2(_camera_point-visible_size*0.5,visible_size).grow(300)
	if far_layer and far_layer.get_child_count()>0:
		var base := far_layer.get_child(0) as ColorRect
		if base: base.size = view
	if far_texture:
		var texture_size := far_texture.get_size()
		var scale_value := maxf(view.x/texture_size.x,view.y/texture_size.y)*1.08
		var tile_size := texture_size*scale_value
		var scroll := _camera_point.x*far_parallax_factor
		var tile_index := floori(scroll/tile_size.x)
		var offset := fposmod(scroll,tile_size.x)
		var yoff := -(tile_size.y-view.y)*(0.5+0.17*sin(_camera_point.y*0.0012))
		for i in range(far_sprites.size()):
			far_sprites[i].scale = Vector2.ONE*scale_value
			far_sprites[i].flip_h = posmod(tile_index+i-1,2)==1
			far_sprites[i].position = Vector2((i-1)*tile_size.x-offset,yoff)
	var actor: Node2D = world_ref.get("hero") as Node2D
	if is_instance_valid(actor) and is_instance_valid(wall_lantern_light):
		var light: PointLight2D = actor.get("lantern_light") as PointLight2D
		if is_instance_valid(light):
			wall_lantern_light.visible = light.visible
			wall_lantern_light.position = light.get_global_transform_with_canvas().origin
			wall_lantern_light.texture_scale = 3.75*zoom_value.x
			wall_lantern_light.energy = light.energy*0.24
			wall_lantern_light.color = light.color

func _draw_structural_depth() -> void:
	# Close cabinet faces, not distant cathedral columns. Their x motion is
	# slower than the walkable surfaces, giving a separate middle depth plane.
	var offset := _camera_point.x*(1.0-mid_parallax_factor)
	var tiers: Array = [floor_y+18]
	if room_id==6: tiers = [2718.0,1998.0,1278.0,558.0]
	for yy in tiers:
		for i in range(-1,ceili(room_size.x/580.0)+1):
			var x := float(i)*580.0+offset
			_shelf(Vector2(x+160,float(yy)),Vector2(145,245+float(posmod(i+room_id,3))*38),room_id*29+i,0.66)
			if posmod(i+room_id,2)==0:
				_book(Rect2(x+220,float(yy)-44,112,24),Color("252a33"),true)

func _shelf(foot: Vector2, size_value: Vector2, seed_value: int = 0, alpha := 1.0) -> void:
	var size_value_close := Vector2(minf(size_value.x,245),minf(size_value.y,360))
	var top := foot-size_value_close
	if not _visible_world.intersects(Rect2(top,size_value_close).grow(20)): return
	draw_rect(Rect2(top-Vector2(6,6),size_value_close+Vector2(12,13)),Color(0.13,0.15,0.20,alpha))
	draw_rect(Rect2(top,size_value_close),Color(0.055,0.07,0.11,alpha))
	var rows := 2 if size_value_close.y>230 else 1
	for row in range(rows):
		var bottom := top.y+(row+1)*size_value_close.y/rows
		draw_rect(Rect2(top.x-4,bottom,size_value_close.x+8,7),Color(0.23,0.22,0.23,alpha))
		for i in range(5):
			var width_value := (size_value_close.x-12)/5.0-3.0
			var h := size_value_close.y/rows*0.72+float(posmod(seed_value+i*7,21))
			var tint := [Color("34323c"),Color("353c43"),Color("3e3436")][posmod(seed_value+i,3)] as Color
			tint.a = alpha
			_book(Rect2(top.x+6+i*(width_value+3),bottom-h,width_value,h),tint)

func _book(rect: Rect2, color: Color, sideways := false) -> void:
	draw_rect(rect,color)
	if sideways:
		draw_rect(Rect2(rect.position+Vector2(5,5),rect.size-Vector2(10,10)),Color(0.46,0.43,0.37,color.a))
	else:
		draw_line(rect.position+Vector2(3,3),rect.position+Vector2(3,rect.size.y-3),color.lightened(0.12),1.3,true)

func _paper(rect: Rect2, tint: Color = IVORY, ruled := false) -> void:
	var p := rect.position
	_poly([p,p+Vector2(rect.size.x,2),rect.end,p+Vector2(2,rect.size.y)],tint)
	_poly([p+Vector2(rect.size.x-14,2),p+Vector2(rect.size.x-14,16),p+Vector2(rect.size.x,16)],tint.darkened(0.23))
	if ruled:
		for i in range(3):
			var y := p.y+rect.size.y*(0.30+i*0.17)
			draw_line(Vector2(p.x+rect.size.x*0.15,y),Vector2(p.x+rect.size.x*0.77,y+0.5),Color(0.20,0.22,0.24,0.22),1.2,true)

func _arch(centre: Vector2, span: float, height_value: float, tint := Color("263745")) -> void:
	super._arch(centre,minf(span,530),minf(height_value,430),tint)

func _lamp(_foot: Vector2, _height_value := 145.0, _cyan := false) -> void:
	# All visible lamps are drawn from the same specs as their real lights below.
	pass

func _draw_registered_lamp(spec: Dictionary) -> void:
	var foot: Vector2 = spec.foot
	var p := foot-Vector2(0,float(spec.height))
	if not _visible_world.intersects(Rect2(p-Vector2(30,35),Vector2(60,float(spec.height)+40))): return
	draw_line(foot,p+Vector2(0,21),Color("30323a"),4,true)
	draw_line(foot+Vector2(-13,0),foot+Vector2(13,0),Color("72614b"),3,true)
	_poly([p+Vector2(-11,-9),p+Vector2(11,-9),p+Vector2(9,18),p+Vector2(-9,18)],Color("80623e"))
	_poly([p+Vector2(-7,-5),p+Vector2(7,-5),p+Vector2(5,13),p+Vector2(-5,13)],Color("ffd18e"))
	_poly([p+Vector2(-5,10),p+Vector2(-2,-3),p+Vector2(1,4),p+Vector2(4,-2),p+Vector2(5,10)],Color("fff1c6"))
	draw_line(p+Vector2(-13,-10),p+Vector2(13,-10),Color("a98450"),3,true)
	draw_arc(p+Vector2(0,-15),4,PI,TAU,14,Color("a98450"),1.4,true)

func _first_page() -> void:
	var c := Vector2(room_size.x*0.47,floor_y+20)
	# The familiar open book now frames a close reading alcove, at a human
	# scale relative to this hero rather than a cathedral in the distance.
	var left := PackedVector2Array([c+Vector2(-198,0),c+Vector2(-185,-255),c+Vector2(-14,-350),c+Vector2(-18,-310),c+Vector2(-150,-230),c+Vector2(-158,0)])
	var right := PackedVector2Array([c+Vector2(158,0),c+Vector2(150,-230),c+Vector2(18,-310),c+Vector2(14,-350),c+Vector2(185,-255),c+Vector2(198,0)])
	draw_colored_polygon(left,Color("6f6b61"))
	draw_colored_polygon(right,Color("817969"))
	_ribbon(c+Vector2(-5,-340),c+Vector2(-70,-210),14,1.4)
	_shelf(c+Vector2(-255,0),Vector2(110,245),11,0.78)
	_shelf(c+Vector2(365,0),Vector2(110,270),12,0.78)
	_crt(Vector2(room_size.x-590,floor_y-50),Vector2(100,88))

func _next_page() -> void:
	var a := _anchor("world_exit",Vector2(room_size.x-300,floor_y))
	var portal := Rect2(a+Vector2(-140,-420),Vector2(280,435))
	draw_rect(portal,Color("393445"))
	draw_rect(portal.grow(-13),Color("7c718d"))
	for i in range(4):
		var x := portal.position.x+30+i*53
		_poly([Vector2(x,portal.position.y+50),Vector2(x+31,portal.position.y+28),Vector2(x+31,portal.end.y-35),Vector2(x,portal.end.y-20)],Color(0.38,0.35,0.49,0.72))
	_arch(a+Vector2(0,20),340,440,Color("45404a"))
	_ribbon(a+Vector2(-172,-395),a+Vector2(-185,-260),15,0.4)

func _draw_atmosphere() -> void:
	for spec in light_specs: _draw_registered_lamp(spec)
	for particle in dust:
		var point: Vector2 = particle.base
		point.x += sin(elapsed*0.16+float(particle.phase))*12
		point.y = 90+fposmod(point.y-90-elapsed*float(particle.speed),maxf(120,room_size.y-160))
		if _visible_world.has_point(point): draw_circle(point,0.7,Color(0.83,0.75,0.62,0.09))
