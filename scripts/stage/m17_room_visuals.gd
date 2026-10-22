extends Node2D
## M17 authored paper architecture. Dressing is non-solid; walkable faces belong
## to m17_paper_platform.gd. Collectible books and the shadow NPC are interactables.
const ART_ROOT := "res://assets/environments/folding_library/"
const IVORY := Color("d6c39f")
const INK := Color("142432")
const BRASS := Color("ad8a51")
const RED := Color("792e3c")
const CYAN := Color("6bc4cc")
var world_ref: Node2D
var definition: Dictionary = {}
var room_size := Vector2(3840,1440)
var floor_y := 1260.0
var room_id := 1
var elapsed := 0.0
var dust: Array[Dictionary] = []
var far_sprites: Array[Sprite2D] = []
var far_layer: CanvasLayer
var far_texture: Texture2D
var arch_texture: Texture2D
var portal_texture: Texture2D
var _redraw_clock := 0.0
var _camera_point := Vector2.ZERO
var _visible_world := Rect2(-1000,-1000,6000,6000)

func setup(world: Node2D, room_definition: Dictionary) -> void:
	world_ref = world
	definition = room_definition
	room_id = int(definition.get("id",1))
	room_size = definition.get("size",Vector2(3840,1440))
	floor_y = float(definition.get("floor_y",room_size.y-180))
	z_index = -6
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var family := "library"
	if room_id == 6: family = "archive"
	elif room_id in [3,7,8,9]: family = "lab"
	elif room_id in [10,12]: family = "bindery"
	elif room_id in [13,14,15]: family = "tribunal"
	var path := ART_ROOT+family+".png"
	if ResourceLoader.exists(path): far_texture = load(path) as Texture2D
	if ResourceLoader.exists(ART_ROOT+"open_book_arch.png"): arch_texture = load(ART_ROOT+"open_book_arch.png") as Texture2D
	if room_id == 15 and ResourceLoader.exists(ART_ROOT+"portal_beyond.png"):
		portal_texture = load(ART_ROOT+"portal_beyond.png") as Texture2D
	_build_far_layer()
	_build_lights()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1700+room_id*31
	for i in range(clampi(int(room_size.x/100.0),25,55)):
		dust.append({"base":Vector2(rng.randf_range(0,room_size.x),rng.randf_range(120,room_size.y-100)),"phase":rng.randf_range(0,TAU),"speed":rng.randf_range(2.5,7.5)})
	_update_far_layer()
	queue_redraw()

func _build_far_layer() -> void:
	far_layer = CanvasLayer.new()
	far_layer.name = "PaintedDistantLibrary"
	far_layer.layer = -18
	add_child(far_layer)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0,0.45,1])
	gradient.colors = PackedColorArray([Color("0b1420"),Color("1b3042"),Color("0b1723")])
	var shade := GradientTexture2D.new()
	shade.gradient = gradient
	shade.width = 1280
	shade.height = 720
	shade.fill_from = Vector2(0,0)
	shade.fill_to = Vector2(0,1)
	var base := TextureRect.new()
	base.name = "Atmosphere"
	base.texture = shade
	base.size = Vector2(1280,720)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	far_layer.add_child(base)
	for i in range(3):
		var sprite := Sprite2D.new()
		sprite.name = "ParallaxPainting_%d"%i
		sprite.texture = far_texture
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.modulate = Color(0.63,0.67,0.72,0.94)
		far_layer.add_child(sprite)
		far_sprites.append(sprite)
	var veil := ColorRect.new()
	veil.name = "DistantInkVeil"
	veil.color = Color(0.035,0.065,0.1,0.12)
	veil.size = Vector2(1280,720)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	far_layer.add_child(veil)

func _build_lights() -> void:
	var glow_path := "res://assets/warden_clean/glow.png"
	if not ResourceLoader.exists(glow_path): return
	var glow: Texture2D = load(glow_path)
	var anchors := [Vector2(290,floor_y-190),Vector2(room_size.x*0.58,floor_y-230),Vector2(room_size.x-360,floor_y-180)]
	if room_id == 6: anchors = [Vector2(260,2600),Vector2(room_size.x-310,1840),Vector2(280,1120),Vector2(room_size.x-310,410)]
	for i in range(anchors.size()):
		var point := PointLight2D.new()
		point.name = "WarmReadingPool_%d"%i
		point.texture = glow
		point.position = anchors[i]
		point.color = Color("e4b56a")
		point.energy = 0.35
		point.texture_scale = 2.8
		add_child(point)

func _process(delta: float) -> void:
	elapsed = float(world_ref.get("elapsed")) if is_instance_valid(world_ref) and world_ref.get("elapsed") != null else elapsed+delta
	_update_far_layer()
	_redraw_clock += delta
	if _redraw_clock >= 1.0/30.0:
		_redraw_clock = 0.0
		queue_redraw()

func _update_far_layer() -> void:
	if not is_instance_valid(world_ref): return
	var camera: Camera2D = world_ref.get("camera") as Camera2D
	_camera_point = camera.position if camera else Vector2.ZERO
	var view := get_viewport_rect().size
	var zoom_value := camera.zoom if camera else Vector2.ONE
	var visible_size := view/zoom_value
	_visible_world = Rect2(_camera_point-visible_size*0.5,visible_size).grow(300.0)
	if far_layer and far_layer.get_child_count()>0:
		var base := far_layer.get_child(0) as TextureRect
		if base: base.size = view
		var veil := far_layer.get_child(far_layer.get_child_count()-1) as ColorRect
		if veil: veil.size = view
	if far_texture == null: return
	var tex_size := far_texture.get_size()
	var scale_value := maxf(view.x/tex_size.x*1.32,view.y/tex_size.y*1.32)
	var tile_size := tex_size*scale_value
	var yoff := -(tile_size.y-view.y)*(0.35+clampf(_camera_point.y/room_size.y,0.0,1.0)*0.25)
	for i in range(far_sprites.size()):
		far_sprites[i].scale = Vector2.ONE*scale_value
		far_sprites[i].position = Vector2(-fposmod(_camera_point.x*0.10,tile_size.x)+(i-1)*tile_size.x,yoff)

func _flag(key: String) -> bool:
	if not is_instance_valid(world_ref): return false
	var progress: Variant = world_ref.get("progress")
	return bool(progress.get(key,false)) if progress is Dictionary else false

func _anchor(kind: String, fallback: Vector2) -> Vector2:
	for item in definition.get("objects",[]):
		if str(item.get("kind","")) == kind: return item.get("pos",fallback)
	return fallback

func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points),color)

func _curve(points: Array, color: Color, width_value := 1.0) -> void:
	draw_polyline(PackedVector2Array(points),color,width_value,true)

func _glow(point: Vector2, radius: float, color: Color, alpha := 0.1) -> void:
	for i in range(7,0,-1):
		var c := color
		c.a = alpha*(1.0-float(i)/8.0)*0.21
		draw_circle(point,radius*float(i)/7.0,c)

func _ribbon(a: Vector2, b: Vector2, w := 14.0, phase := 0.0) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(23):
		var u := float(i)/22.0
		var p := a.lerp(b,u)+Vector2(sin(u*PI*2.0+phase+elapsed*0.35)*8.0,sin(u*PI)*28.0)
		left.append(p+Vector2(-w*0.5,0))
		right.insert(0,p+Vector2(w*0.5,0))
	left.append_array(right)
	draw_colored_polygon(left,RED.darkened(0.14))
	var thread := PackedVector2Array()
	for i in range(23):
		var u := float(i)/22.0
		thread.append(a.lerp(b,u)+Vector2(sin(u*PI*2.0+phase+elapsed*0.35)*8.0-w*0.35,sin(u*PI)*28.0))
	draw_polyline(thread,Color(0.72,0.35,0.30,0.65),1.5,true)

func _paper(rect: Rect2, tint: Color = IVORY, ruled := false) -> void:
	var a := rect.position
	var s := rect.size
	draw_rect(Rect2(a+Vector2(7,8),s),Color(0.015,0.025,0.04,0.28))
	_poly([a,a+Vector2(s.x,2),a+s,a+Vector2(2,s.y)],tint)
	draw_polyline(PackedVector2Array([a+Vector2(1,s.y),a,a+Vector2(s.x,2),a+s]),Color(0.25,0.25,0.23,0.5),1.0,true)
	_poly([a+Vector2(s.x-18,2),a+Vector2(s.x-18,20),a+Vector2(s.x,20)],tint.darkened(0.28))
	if ruled:
		for i in range(int((s.y-25.0)/14.0)):
			var y := a.y+23.0+i*14.0
			draw_line(Vector2(a.x+15,y),Vector2(a.x+s.x-18-fposmod(float(i*19),35.0),y+0.7),Color(0.25,0.24,0.22,0.2),0.8,true)

func _book(rect: Rect2, color: Color, sideways := false) -> void:
	draw_rect(Rect2(rect.position+Vector2(5,5),rect.size),Color(0.01,0.025,0.035,0.3))
	draw_rect(rect,color)
	draw_rect(Rect2(rect.position+Vector2(3,3),rect.size-Vector2(6,6)),color.lightened(0.045),false,1.2)
	if sideways:
		draw_rect(Rect2(rect.position+Vector2(8,4),Vector2(rect.size.x-14,rect.size.y-8)),IVORY.darkened(0.25))
		for y in range(3): draw_line(rect.position+Vector2(10,8+y*4),rect.position+Vector2(rect.size.x-8,8+y*4),Color(0.25,0.23,0.2,0.22),0.7,true)
	else:
		draw_line(rect.position+Vector2(5,3),rect.position+Vector2(5,rect.size.y-3),Color(0,0,0,0.25),2.5,true)
		for y in [0.15,0.24,0.78,0.87]:
			draw_line(rect.position+Vector2(7,rect.size.y*y),rect.position+Vector2(rect.size.x-5,rect.size.y*y),Color(0.7,0.57,0.35,0.53),1.0,true)

func _shelf(foot: Vector2, size_value: Vector2, seed_value: int = 0, alpha := 1.0) -> void:
	if far_texture: alpha *= 0.57
	var top := foot-size_value
	if not _visible_world.intersects(Rect2(top-Vector2(15,15),size_value+Vector2(30,30))): return
	var frame := Color(0.12,0.16,0.20,alpha)
	draw_rect(Rect2(top-Vector2(8,9),size_value+Vector2(16,14)),frame)
	draw_rect(Rect2(top,size_value),Color(0.035,0.07,0.10,alpha))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value+room_id*107
	var rows := maxi(2,int(size_value.y/92.0))
	for row in range(rows):
		var bottom := top.y+(row+1)*size_value.y/rows
		draw_rect(Rect2(top.x-4,bottom,size_value.x+8,8),Color(0.24,0.24,0.21,alpha))
		draw_line(Vector2(top.x-4,bottom),Vector2(top.x+size_value.x+4,bottom),Color(0.62,0.52,0.34,alpha*0.5),1.0,true)
		var x := top.x+5
		while x<top.x+size_value.x-10:
			var bw := rng.randf_range(13,27)
			var bh := rng.randf_range(46,size_value.y/rows-10)
			var tint := [Color("293442"),Color("463b39"),Color("544631"),Color("263f42"),Color("4b3038")][rng.randi_range(0,4)] as Color
			tint.a = alpha
			_book(Rect2(x,bottom-bh,bw,bh),tint)
			x += bw+3
	for x in [top.x-8,top.x+size_value.x+1]:
		draw_rect(Rect2(x,top.y-8,7,size_value.y+22),Color(0.25,0.23,0.19,alpha))

func _lamp(foot: Vector2, height_value := 145.0, cyan := false) -> void:
	var color := CYAN if cyan else Color("deb46d")
	var p := foot-Vector2(0,height_value)
	_glow(p,95,color,0.20)
	draw_line(foot, p+Vector2(0,23),Color("27303a"),5,true)
	draw_line(foot+Vector2(-15,1),foot+Vector2(15,1),Color("6e6249"),4,true)
	_poly([p+Vector2(-12,-9),p+Vector2(12,-9),p+Vector2(10,19),p+Vector2(-10,19)],Color("493f2d"))
	_poly([p+Vector2(-8,-5),p+Vector2(8,-5),p+Vector2(6,15),p+Vector2(-6,15)],color.darkened(0.03))
	draw_line(p+Vector2(0,-5),p+Vector2(0,15),color.lightened(0.35),2.0,true)
	draw_rect(Rect2(p+Vector2(-15,-13),Vector2(30,5)),BRASS)
	draw_rect(Rect2(p+Vector2(-13,20),Vector2(26,4)),BRASS.darkened(0.15))
	draw_arc(p+Vector2(0,-17),5,PI,TAU,14,BRASS,1.6,true)

func _crt(foot: Vector2, size_value := Vector2(120,108), active := true) -> void:
	var p := foot-size_value*Vector2(0.5,1)
	draw_rect(Rect2(p+Vector2(5,5),size_value),Color(0.02,0.04,0.06,0.3))
	draw_polygon(PackedVector2Array([p,p+Vector2(size_value.x-8,0),p+size_value,p+Vector2(4,size_value.y)]),PackedColorArray([Color("a49c81"),Color("77796d"),Color("4e5c57"),Color("777a69")]))
	draw_line(p+Vector2(4,3),p+Vector2(size_value.x-11,3),Color("c2baa1"),1.5,true)
	draw_line(p+Vector2(size_value.x-7,6),p+size_value-Vector2(3,9),Color("333f3f"),2,true)
	draw_rect(Rect2(p+Vector2(7,6),size_value-Vector2(23,24)),Color("101f28"))
	if active:
		var screen := Rect2(p+Vector2(11,10),size_value-Vector2(31,32))
		draw_polygon(PackedVector2Array([screen.position,Vector2(screen.end.x,screen.position.y),screen.end,Vector2(screen.position.x,screen.end.y)]),PackedColorArray([Color("21434a"),Color("17383e"),Color("0e242c"),Color("18343b")]))
		_poly([screen.position+Vector2(3,3),screen.position+Vector2(screen.size.x*0.55,3),screen.position+Vector2(3,screen.size.y*0.65)],Color(0.62,0.82,0.81,0.035))
		for i in range(5):
			var yy := screen.position.y+10+i*9
			draw_line(Vector2(screen.position.x+8,yy),Vector2(screen.end.x-10-fposmod(float(i*11),28.0),yy),Color(0.40,0.77,0.79,0.55),1,true)
		draw_rect(Rect2(screen.end-Vector2(15,11),Vector2(5,2)),CYAN)
		_glow(screen.get_center(),70,CYAN,0.06)
	draw_circle(p+Vector2(size_value.x-9,size_value.y-13),2.0,CYAN if active else Color("4f5350"))
	draw_rect(Rect2(foot+Vector2(-24,-2),Vector2(48,9)),Color("434b4a"))

func _arch(centre: Vector2, span: float, height_value: float, tint := Color("263745")) -> void:
	var left := centre.x-span*0.5
	var right := centre.x+span*0.5
	var crown := centre.y-height_value
	if not _visible_world.intersects(Rect2(left-50,crown-50,span+100,height_value+100)): return
	# Quadratic arch bands leave the central silhouette open.
	for side in [-1.0,1.0]:
		var edge := left if side<0 else right
		draw_rect(Rect2(edge-22,centre.y-height_value*0.65,44,height_value*0.65),tint)
		var pts := PackedVector2Array()
		for i in range(26):
			var u := float(i)/25.0
			pts.append(Vector2(centre.x+side*span*0.5*(1.0-u),centre.y-height_value*0.65-height_value*0.35*sin(u*PI*0.5)))
		draw_polyline(pts,tint,40.0,true)
		draw_polyline(pts,tint.lightened(0.17),2.0,true)
		draw_line(Vector2(edge-25,centre.y),Vector2(edge+25,centre.y),tint.lightened(0.12),7,true)
	draw_circle(Vector2(centre.x,crown+2),9,tint.lightened(0.22))

func _draw() -> void:
	if definition.is_empty(): return
	_draw_structural_depth()
	match room_id:
		1: _first_page()
		2: _assignments()
		3: _ink_lab()
		4: _black_corner()
		5: _erased_margins()
		6: _archive()
		7: _input_room()
		8: _process_room()
		9: _output_room()
		10: _balance_hall()
		11: _lecture()
		12: _bindery()
		13: _corrector()
		14: _tribunal()
		15: _next_page()
	_draw_atmosphere()

func _draw_structural_depth() -> void:
	# Distant repeated forms move more slowly than the actual surfaces.
	var parallax := _camera_point*Vector2(0.16,0.05)
	var columns := 0 if far_texture else ceili(room_size.x/860.0)+1
	for i in range(columns):
		var x := -240.0+i*860.0+parallax.x
		for row in range(maxi(1,ceili(room_size.y/1350.0))):
			var base_y := 1360.0+row*1350.0+parallax.y
			_arch(Vector2(x,base_y),540,1150,Color(0.08,0.14,0.20,0.42))
			_shelf(Vector2(x-230,base_y-120),Vector2(130,500),i*91+row,0.42)
			_shelf(Vector2(x+325,base_y-120),Vector2(135,650),i*39+row,0.36)
	for i in range(ceili(room_size.x/1150.0)):
		var x := 420.0+i*1150.0
		_ribbon(Vector2(x,120),Vector2(x+130,500),18,float(i))
		_paper(Rect2(x+130,290,80,115),Color(0.60,0.58,0.48,0.24),true)

func _first_page() -> void:
	var c := Vector2(room_size.x*0.47,floor_y+30)
	if arch_texture:
		draw_texture_rect(arch_texture,Rect2(c-Vector2(630,840),Vector2(1260,840)),false,Color(0.88,0.85,0.80,1.0))
		_lamp(c+Vector2(-590,-30),175)
		_lamp(c+Vector2(590,-30),175)
		_crt(Vector2(room_size.x-590,floor_y-50),Vector2(125,110))
		return
	_shelf(c+Vector2(-430,0),Vector2(205,540),11,0.54)
	_shelf(c+Vector2(655,0),Vector2(220,700),12,0.56)
	var l := c+Vector2(-450,-20)
	var r := c+Vector2(450,-20)
	var left_page := PackedVector2Array([l+Vector2(-60,0),l+Vector2(-35,-730),c+Vector2(-40,-930),c+Vector2(-25,-830),l+Vector2(62,-660),l+Vector2(75,0)])
	var right_page := PackedVector2Array([r+Vector2(-75,0),r+Vector2(-62,-660),c+Vector2(25,-830),c+Vector2(40,-930),r+Vector2(35,-730),r+Vector2(60,0)])
	draw_polygon(left_page,PackedColorArray([IVORY.darkened(0.32),IVORY.darkened(0.17),IVORY.lightened(0.03),IVORY.darkened(0.10),IVORY.darkened(0.24),IVORY.darkened(0.33)]))
	draw_polygon(right_page,PackedColorArray([IVORY.darkened(0.29),IVORY.darkened(0.11),IVORY.lightened(0.04),IVORY.darkened(0.12),IVORY.darkened(0.26),IVORY.darkened(0.39)]))
	for i in range(8):
		var d := float(i)*5
		_curve([l+Vector2(-40+d,-10),l+Vector2(-20+d,-690),c+Vector2(-35+d,-882)],Color(0.31,0.29,0.25,0.3),0.9)
		_curve([r+Vector2(40-d,-10),r+Vector2(20-d,-690),c+Vector2(35-d,-882)],Color(0.31,0.29,0.25,0.3),0.9)
	_ribbon(c+Vector2(-12,-920),c+Vector2(-190,-370),26,1.4)
	_lamp(c+Vector2(-545,-40),180)
	_lamp(c+Vector2(530,-40),180)
	_crt(Vector2(room_size.x-590,floor_y-50),Vector2(125,110))

func _assignments() -> void:
	for i in range(5):
		var x := 360.0+i*650
		_paper(Rect2(x,floor_y-420,116,152),IVORY.darkened(0.36),true)
		_curve([Vector2(x+18,floor_y-385),Vector2(x+43,floor_y-370),Vector2(x+83,floor_y-402)],Color(0.54,0.24,0.25,0.58),2.4)
		for j in range(4): _book(Rect2(x+160+j*3,floor_y-35-j*19,180-j*9,17),Color("49413a"),true)
	_lamp(Vector2(660,floor_y+25),195)
	_lamp(Vector2(room_size.x-510,floor_y+25),190)

func _ink_lab() -> void:
	var a := _anchor("ink_control",Vector2(room_size.x*0.46,floor_y))
	var p := a+Vector2(300,-340)
	var solved := _flag("ink_route_solved")
	for i in range(3):
		var q := p+Vector2(i*140,-70)
		_curve([q+Vector2(0,-190),q+Vector2(0,130),q+Vector2(80,165),p+Vector2(450,220)],Color("253c46"),15)
		_curve([q+Vector2(0,-190),q+Vector2(0,130),q+Vector2(80,165),p+Vector2(450,220)],Color(0.35,0.76,0.79,0.60 if solved else 0.27),5)
		draw_rect(Rect2(q+Vector2(-33,-135),Vector2(66,135)),Color("142731"))
		draw_rect(Rect2(q+Vector2(-28,-130),Vector2(56,125)),Color(0.22,0.57,0.61,0.5))
		for y in [-143,-12]: draw_rect(Rect2(q+Vector2(-40,y),Vector2(80,10)),BRASS.darkened(0.25))
		draw_arc(q+Vector2(0,-65),16,0,TAU,40,CYAN,1.4,true)
	_crt(a+Vector2(-165,-10),Vector2(144,125))
	_shelf(Vector2(room_size.x-230,floor_y+30),Vector2(180,460),31,0.72)

func _black_corner() -> void:
	var a := _anchor("dialogue",Vector2(room_size.x*0.62,floor_y))
	_arch(a+Vector2(0,35),670,760,Color("303440"))
	_shelf(a+Vector2(-265,15),Vector2(130,590),41,0.84)
	_shelf(a+Vector2(375,15),Vector2(140,650),42,0.84)
	_paper(Rect2(a+Vector2(250,-320),Vector2(92,125)),IVORY.darkened(0.40),true)
	_ribbon(a+Vector2(260,-680),a+Vector2(210,-390),20,0.4)
	_lamp(a+Vector2(-330,25),145)
	_glow(a+Vector2(-40,-120),180,Color("18202a"),0.10)

func _erased_margins() -> void:
	for i in range(5):
		var p := Vector2(320+i*550,floor_y-560-(i%2)*100)
		_paper(Rect2(p,Vector2(220,340)),IVORY.darkened(0.25),true)
		for j in range(5):
			var y := p.y+65+j*43
			for k in range(3): draw_line(Vector2(p.x+26,y+k*2),Vector2(p.x+182,y+k*2-2),Color(0.2,0.24,0.27,0.44),1.0,true)
		_ribbon(p+Vector2(200,-60),p+Vector2(225,220),12,float(i))

func _archive() -> void:
	var floors := [2700.0,1980.0,1260.0,540.0]
	for i in range(4):
		var y: float = floors[i]
		_shelf(Vector2(300,y+32),Vector2(235,485),61+i,0.83)
		_shelf(Vector2(room_size.x-70,y+32),Vector2(240,505),71+i,0.83)
		_lamp(Vector2(370,y+25),165,i==2)
		_lamp(Vector2(room_size.x-350,y+25),165)
		_paper(Rect2(room_size.x-285,y-420,105,145),IVORY.darkened(0.28),true)
		for n in range(i+1): draw_line(Vector2(room_size.x-255+n*13,y-380),Vector2(room_size.x-255+n*13,y-330),Color("665a42"),3,true)
	_ribbon(Vector2(room_size.x*0.54,110),Vector2(room_size.x*0.54+110,2670),31,0.4)
	for i in range(3):
		var y := 900.0+i*720
		_arch(Vector2(room_size.x*0.5,y+170),820,690,Color(0.13,0.20,0.27,0.43))

func _input_room() -> void:
	for item in definition.get("objects",[]):
		if str(item.get("kind","")) == "book":
			var p: Vector2 = item.get("pos",Vector2.ZERO)
			draw_rect(Rect2(p+Vector2(-45,6),Vector2(90,12)),Color("514839"))
			draw_line(p+Vector2(-47,7),p+Vector2(47,7),BRASS,1.1,true)
	_crt(Vector2(room_size.x-470,floor_y-55),Vector2(136,120))
	_ribbon(Vector2(room_size.x*0.4,190),Vector2(room_size.x*0.4+90,550),23,0.8)

func _process_room() -> void:
	var a := _anchor("process_control",Vector2(room_size.x*0.48,floor_y))
	# The actual books and slot state are owned by the interactable/UI.
	draw_rect(Rect2(a+Vector2(-280,-70),Vector2(560,23)),Color("a69776"))
	draw_line(a+Vector2(-285,-73),a+Vector2(285,-73),IVORY,3,true)
	for x in [-240,240]:
		draw_rect(Rect2(a+Vector2(x,-47),Vector2(17,75)),Color("403c35"))
	_paper(Rect2(a+Vector2(-180,-460),Vector2(360,235)),IVORY.darkened(0.12),true)
	for i in range(3):
		var c := a+Vector2(-100+i*100,-385)
		if i==0: _curve([c+Vector2(-15,12),c+Vector2(0,-14),c+Vector2(15,12),c+Vector2(-15,12)],INK,2)
		elif i==1: draw_rect(Rect2(c-Vector2(13,13),Vector2(26,26)),INK,false,2)
		else: draw_arc(c,14,0,TAU,36,INK,2,true)
		_curve([c+Vector2(0,28),c+Vector2(0,48),c+Vector2(-5,41),c+Vector2(0,48),c+Vector2(5,41)],INK,1.6)
	_crt(a+Vector2(520,-10),Vector2(120,108))

func _output_room() -> void:
	var a := _anchor("output_control",Vector2(760,floor_y))
	var hinge := a+Vector2(370,-18)
	draw_circle(hinge,76,Color("192a35"))
	draw_arc(hinge,65,0,TAU,72,BRASS,9,true)
	draw_arc(hinge,48,0,TAU,72,Color("534c3b"),4,true)
	for i in range(10):
		var v := Vector2.from_angle(i*TAU/10.0)
		draw_line(hinge+v*49,hinge+v*72,BRASS,4,true)
	if not _flag("output_open"):
		_poly([hinge+Vector2(40,-20),hinge+Vector2(145,-370),hinge+Vector2(220,-390),hinge+Vector2(120,-30)],IVORY.darkened(0.13))
		for i in range(5): draw_line(hinge+Vector2(49+i*12,-25),hinge+Vector2(157+i*12,-370),Color(0.33,0.29,0.24,0.32),0.8,true)
	_ribbon(hinge+Vector2(8,-5),hinge+Vector2(220,-285),25,0.1)
	_lamp(Vector2(room_size.x-310,floor_y-480),170,true)

func _balance_hall() -> void:
	var a := _anchor("balance_control",Vector2(room_size.x*0.42,floor_y))
	var c := a+Vector2(470,-390)
	var locked := _flag("balance_bridge_locked")
	var tilt := 0.0 if locked else 0.10
	var beam := Vector2(360,0).rotated(tilt)
	draw_line(c+Vector2(0,390),c,Color("263441"),30,true)
	draw_line(c+Vector2(-15,390),c+Vector2(-15,0),BRASS.darkened(0.25),2,true)
	draw_circle(c,46,Color("28343e"))
	draw_arc(c,42,PI,TAU,45,BRASS,4,true)
	draw_line(c-beam,c+beam,BRASS,13,true)
	for side in [-1,1]:
		var top: Vector2 = c+beam*float(side)
		var tray: Vector2 = top+Vector2(0,235)
		for dx in [-105,105]: draw_line(top,tray+Vector2(dx,0),Color("897451"),2.5,true)
		_poly([tray+Vector2(-120,0),tray+Vector2(120,0),tray+Vector2(90,22),tray+Vector2(-90,22)],Color("5d5545"))
		_book(Rect2(tray+Vector2(-60,-28),Vector2(110,24)),Color("544c3b"),true)
		if not locked and side==1: _book(Rect2(tray+Vector2(-43,-56),Vector2(89,24)),Color("504039"),true)
	_lamp(a+Vector2(-250,20),175)

func _lecture() -> void:
	var c := Vector2(room_size.x*0.58,floor_y-640)
	_paper(Rect2(c+Vector2(-280,-170),Vector2(560,320)),IVORY.darkened(0.44),false)
	for i in range(6): draw_line(c+Vector2(-220,-100+i*33),c+Vector2(190-i*17,-100+i*33),Color(0.19,0.39,0.44,0.34),1.1,true)
	var projector := Vector2(560,floor_y-530)
	_poly([projector,c+Vector2(-250,-145),c+Vector2(-250,140)],Color(0.54,0.73,0.77,0.055))
	_crt(projector,Vector2(85,65),true)
	for row in range(4):
		var yy := floor_y-45-row*120
		for col in range(5):
			var xx := 900+col*260+row*80
			draw_rect(Rect2(xx,yy,145,12),Color(0.18,0.22,0.25,0.52))
			draw_rect(Rect2(xx+10,yy-60,16,60),Color(0.14,0.19,0.23,0.55))
	_ribbon(Vector2(room_size.x-400,220),Vector2(room_size.x-650,650),20,0.9)

func _bindery() -> void:
	for hazard in definition.get("hazards",[]):
		var rect: Rect2 = hazard.get("rect",Rect2())
		if rect.size.x<=0: continue
		var period := float(hazard.get("period",5.0))
		var warning := float(hazard.get("telegraph",1.2))
		var active := float(hazard.get("active",0.7))
		var phase := fposmod(elapsed+float(hazard.get("phase_offset",hazard.get("offset",0.0))),period)
		var disabled := _flag(str(hazard.get("disabled_by","workshop_main_passage_open")))
		var firing := not disabled and phase>=warning and phase<warning+active
		var announcing := not disabled and phase<warning
		var p := Vector2(rect.get_center().x,rect.end.y)
		var top_y := rect.position.y-260
		for dx in [-rect.size.x*0.5-25,rect.size.x*0.5+25]:
			draw_rect(Rect2(p.x+dx-10,top_y,20,p.y-top_y+45),Color("24333d"))
			draw_line(Vector2(p.x+dx-8,top_y),Vector2(p.x+dx-8,p.y+35),BRASS.darkened(0.26),2,true)
		var crosshead := Rect2(p.x-rect.size.x*0.5-42,top_y-20,rect.size.x+84,45)
		draw_polygon(PackedVector2Array([crosshead.position,Vector2(crosshead.end.x,crosshead.position.y),crosshead.end,Vector2(crosshead.position.x,crosshead.end.y)]),PackedColorArray([Color("55606a"),Color("414c56"),Color("25303a"),Color("2f3943")]))
		draw_line(crosshead.position,crosshead.position+Vector2(crosshead.size.x,0),Color("8c8268"),1.5,true)
		for bolt_x in [-rect.size.x*0.5-24,rect.size.x*0.5+24]:
			draw_circle(Vector2(p.x+bolt_x,top_y+2),5.5,Color("1c2832"))
			draw_arc(Vector2(p.x+bolt_x,top_y+2),4.0,PI,TAU,12,Color("8f7d58"),1.4,true)
		var closed_y := p.y-23 if firing else rect.position.y-120
		if announcing: closed_y += (sin(elapsed*13.0)+1)*3.0
		draw_rect(Rect2(p.x-13,top_y+20,26,closed_y-top_y),Color("675e4c"))
		var press_face := Rect2(p.x-rect.size.x*0.5,closed_y,rect.size.x,23)
		draw_polygon(PackedVector2Array([press_face.position,Vector2(press_face.end.x,press_face.position.y),press_face.end,Vector2(press_face.position.x,press_face.end.y)]),PackedColorArray([Color("a49371"),Color("978365"),Color("554f40"),Color("69604b")]))
		draw_line(press_face.position,press_face.position+Vector2(press_face.size.x,0),Color("c9b58a"),1.5,true)
		draw_line(Vector2(p.x-rect.size.x*0.5,closed_y+23),Vector2(p.x+rect.size.x*0.5,closed_y+23),IVORY.darkened(0.22),2,true)
		if announcing or firing:
			var alpha := 0.26 if firing else 0.11+(sin(elapsed*9)+1)*0.05
			draw_rect(Rect2(rect.position.x,p.y-3,rect.size.x,4),Color(0.92,0.53,0.27,alpha))
			_glow(Vector2(p.x,p.y),rect.size.x*0.7,Color("c48b55"),alpha*0.2)
	for i in range(3):
		var x := 460.0+i*980
		_ribbon(Vector2(x,150),Vector2(x+150,560),27,float(i))
		_book(Rect2(x+30,floor_y-95,180,35),Color("4c443a"),true)

func _corrector() -> void:
	var c := Vector2(room_size.x*0.54,floor_y+25)
	_arch(c,860,770,Color("34414a"))
	for side in [-1,1]:
		_paper(Rect2(c+Vector2(side*430-55,-630),Vector2(110,590)),IVORY.darkened(0.28),true)
		_lamp(c+Vector2(side*460,0),190)
	_ribbon(c+Vector2(-350,-680),c+Vector2(-270,-300),23,0.2)
	_ribbon(c+Vector2(350,-680),c+Vector2(260,-300),23,2.2)
	var bench := _anchor("bench",Vector2(room_size.x-440,floor_y))
	_arch(bench+Vector2(5,24),490,500,Color("303641"))
	_crt(bench+Vector2(140,-50),Vector2(100,90))

func _tribunal() -> void:
	var c := Vector2(room_size.x*0.5,floor_y+35)
	for side in [-1.0,1.0]:
		var p := c+Vector2(side*185,-460)
		var page := PackedVector2Array([p+Vector2(-side*185,25),p+Vector2(side*175,-25),p+Vector2(side*190,-390),p+Vector2(-side*185,-335)])
		draw_colored_polygon(page,IVORY.darkened(0.12 if side<0 else 0.25))
		for i in range(8):
			var yy := -290+i*35
			draw_line(p+Vector2(-150,yy),p+Vector2(125,yy-12),Color(0.25,0.27,0.26,0.23),1.2,true)
		_poly([c+Vector2(side*8,-80),p+Vector2(-side*175,28),p+Vector2(side*175,-17),c+Vector2(side*400,-80)],Color("38404a"))
		draw_line(c+Vector2(side*400,-80),c+Vector2(side*400,-30),BRASS,5,true)
	_ribbon(c+Vector2(0,-825),c+Vector2(-90,-180),32,0.6)
	var screen := Rect2(c+Vector2(-420,-1240),Vector2(840,410))
	draw_rect(screen,Color(0.07,0.19,0.24,0.62))
	for i in range(10):
		draw_line(screen.position+Vector2(35,34+i*33),screen.position+Vector2(730-fposmod(i*37.0,180.0),34+i*33),Color(0.33,0.62,0.66,0.24),1.1,true)
	draw_arc(screen.get_center(),115,0,TAU,80,Color(0.39,0.69,0.72,0.26),1.6,true)
	_lamp(c+Vector2(-565,0),205)
	_lamp(c+Vector2(565,0),205)

func _next_page() -> void:
	var a := _anchor("world_exit",Vector2(room_size.x-300,floor_y))
	var portal := Rect2(a+Vector2(-215,-890),Vector2(430,930))
	for i in range(18):
		var alpha := 0.025+float(i)*0.002
		draw_rect(Rect2(portal.position-Vector2(i*4,0),portal.size+Vector2(i*8,0)),Color(0.62,0.59,0.84,alpha))
	if portal_texture:
		draw_texture_rect(portal_texture,portal,false,Color(0.96,0.95,1.0,1.0))
	else:
		draw_rect(portal,Color("b7a9d0"))
		for i in range(7):
			var x := portal.position.x+28+i*57
			var y := portal.position.y+120+fposmod(i*191.0,500.0)
			_poly([Vector2(x,y),Vector2(x+34,y-19),Vector2(x+61,y+1),Vector2(x+27,y+21)],Color(0.42,0.40,0.64,0.48))
			_poly([Vector2(x,y),Vector2(x+27,y+21),Vector2(x+27,y+100),Vector2(x,y+76)],Color(0.39,0.37,0.61,0.48))
			_poly([Vector2(x+27,y+21),Vector2(x+61,y+1),Vector2(x+61,y+79),Vector2(x+27,y+100)],Color(0.56,0.50,0.71,0.44))
	_arch(a+Vector2(0,30),500,965,Color("594b40"))
	_ribbon(a+Vector2(-245,-835),a+Vector2(-280,-480),25,0.4)
	_ribbon(a+Vector2(245,-835),a+Vector2(260,-450),25,1.9)

func _draw_atmosphere() -> void:
	for particle in dust:
		var point: Vector2 = particle.base
		point.x += sin(elapsed*0.20+float(particle.phase))*17.0
		point.y = 90.0+fposmod(point.y-90.0-elapsed*float(particle.speed),maxf(120,room_size.y-160))
		if not _visible_world.has_point(point): continue
		var alpha := 0.07+(sin(elapsed*0.65+float(particle.phase))+1)*0.055
		draw_circle(point,0.9,Color(0.85,0.83,0.72,alpha))
	# Broad, low opacity shafts preserve space around the hero.
	for i in range(ceili(room_size.x/1200.0)):
		var x := 280.0+i*1200.0
		_poly([Vector2(x,100),Vector2(x+70,100),Vector2(x+400,floor_y),Vector2(x+170,floor_y)],Color(0.62,0.73,0.78,0.018))
