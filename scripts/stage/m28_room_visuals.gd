extends "res://scripts/stage/m24_room_visuals.gd"
## Close, layered landmarks use the same coordinates as playable mechanisms.
## Architecture stays behind actors; hazard jets have a separate readable lip.
const M28Foreground=preload("res://scripts/stage/m28_foreground.gd")
const MARKET_ART="res://assets/environments/m28/margin_exchange.png"
const VAULT_ART="res://assets/environments/m27_archivist/sealed_catalog_vault.png"
const BELL_ARCH_ART="res://assets/environments/m28/bell_bound_arch.png"
var m28_architecture: Array[Dictionary]=[]

func setup(world: Node2D, room_definition: Dictionary) -> void:
	super.setup(world,room_definition)
	name="AuthoredPaperRoomsM28"
	ambient.color=Color(.33,.35,.41,1)
	# Vary the close wall by material family while retaining actual warm pools.
	var tint: Color=[Color(.78,.84,.98),Color(.87,.81,.83),Color(.77,.91,.94),Color(.88,.83,.97)][posmod(room_id-1,4)]
	for sprite in far_sprites: sprite.modulate=tint
	remove_child(foreground)
	foreground.free()
	foreground=M28Foreground.new()
	add_child(foreground)
	foreground.setup(world,definition)
	if room_id==4: _build_market_art()
	if room_id==6: _build_vault_art()
	if room_id==12: _build_bell_art()
	var details: Node2D=load("res://scripts/stage/m28_surface_details.gd").new()
	add_child(details)
	details.setup(world,definition)

func _build_bell_art() -> void:
	var painting:=Sprite2D.new()
	painting.name="PaintedBoundBellEntrance"
	painting.texture=load(BELL_ARCH_ART)
	painting.centered=false
	painting.position=Vector2(1000-728.5*.39,1260-1018*.39)
	painting.scale=Vector2(.39,.39)
	painting.z_index=1
	var material_value:=CanvasItemMaterial.new()
	material_value.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
	painting.material=material_value
	painting.modulate=Color(.70,.74,.84,1)
	add_child(painting)

func _build_vault_art() -> void:
	var painting:=Sprite2D.new()
	painting.name="PaintedArchivistVaultEntrance"
	var atlas:=AtlasTexture.new()
	atlas.atlas=load(VAULT_ART)
	atlas.region=Rect2(310,0,1052,840)
	painting.texture=atlas
	painting.centered=false
	painting.position=Vector2(2710-(835-310)*.55,1980-806*.55)
	painting.scale=Vector2(.55,.55)
	painting.z_index=1
	var shader:=Shader.new()
	shader.code="shader_type canvas_item; render_mode unshaded; varying vec2 local_uv; void vertex(){local_uv=VERTEX/vec2(1052.0,840.0);} void fragment(){ vec4 c=texture(TEXTURE,UV); c.rgb*=vec3(.86,.89,.97); float f=smoothstep(0.0,.10,local_uv.x)*smoothstep(0.0,.10,1.0-local_uv.x)*smoothstep(0.0,.09,local_uv.y); c.a*=f; COLOR=c; }"
	var material_value:=ShaderMaterial.new()
	material_value.shader=shader
	painting.material=material_value
	add_child(painting)

func _build_market_art() -> void:
	var painting:=Sprite2D.new()
	painting.name="PaintedMarginExchange"
	painting.texture=load(MARKET_ART)
	painting.centered=false
	painting.position=Vector2(1266,700)
	painting.scale=Vector2(.8,.8)
	painting.z_index=1
	var shader:=Shader.new()
	shader.code="shader_type canvas_item; render_mode unshaded; void fragment(){ vec4 c=texture(TEXTURE,UV); c.rgb*=vec3(.84,.88,.96); c.a*=smoothstep(0.0,.095,UV.x)*smoothstep(0.0,.06,UV.y); COLOR=c; }"
	var material_value:=ShaderMaterial.new()
	material_value.shader=shader
	painting.material=material_value
	add_child(painting)

func _build_lights() -> void:
	if room_id==4:
		_append_lamp(Vector2(1910,1274),208,.92)
		_append_lamp(Vector2(2230,1274),208,.88)
	if room_id==6: _append_lamp(Vector2(2670,1994),235,1.02)
	if room_id==12: _append_lamp(Vector2(990,1274),237,.92)
	for plate in definition.get("m28_pressure_plates",[]): _append_lamp((plate.pos as Vector2)+Vector2(62,10),110,.67)
	if room_id==10: _append_lamp(Vector2(2475,910),235,.8)
	super._build_lights()

func _draw_structural_depth() -> void:
	# Broad painted walls provide the room envelope. Keep the middle silhouettes
	# restrained, so landmarks and traversable edges retain breathing room.
	super._draw_structural_depth()

func _draw_atmosphere() -> void:
	super._draw_atmosphere()
	for doorway in definition.get("m28_doorways",[]):
		_draw_threshold(doorway.pos,int(doorway.target))
	for hurdle in definition.get("m28_hurdles",[]): _spine(hurdle.rect)
	for gap in definition.get("m28_gaps",[]): _torn_binding(gap.rect)
	for vent in definition.get("m28_vents",[]): _ink_nozzle(vent)
	for plate in definition.get("m28_pressure_plates",[]): _floor_seal(plate.pos,bool(world_ref.progress.get(str(plate.flag),false)),3)
	if room_id==10: _counterweight_relay()
	match room_id:
		1: _round_landmark(Vector2(650,1260),Color("71614b"),0)
		2: _notice_cabinet(Vector2(1080,1260))
		3: _ink_manifold(Vector2(1920,1260))
		4: pass # The native painting supplies the complete shop facade.
		5: _hanging_scrolls(Vector2(1810,780),2)
		6: pass # The existing approved vault painting now forms its real doorway.
		7: _round_landmark(Vector2(1660,1020),Color("687161"),1)
		8: _ink_manifold(Vector2(1620,1260))
		9: _hanging_scrolls(Vector2(2160,780),3)
		10: _round_landmark(Vector2(1100,1260),Color("75634b"),2)
		11: _notice_cabinet(Vector2(1630,900))
		12: pass # An original transparent bound-book bell arch frames the entry.
		13: _hanging_scrolls(Vector2(2540,1260),1)
		14: _sleeping_recess(Vector2(2320,1440))
		15: _round_landmark(Vector2(2070,1260),Color("5d526e"),3)

func _in_view(point: Vector2, size_value: Vector2) -> bool:
	return _visible_world.intersects(Rect2(point-Vector2(size_value.x*.5,size_value.y),size_value).grow(30))

func _draw_threshold(p: Vector2, target: int) -> void:
	if not _in_view(p,Vector2(250,290)): return
	var c:=Color("393542")
	for side in [-1.0,1.0]:
		_book(Rect2(p+Vector2(side*103-19,-239),Vector2(38,239)),c)
		draw_line(p+Vector2(side*103,-223),p+Vector2(side*103,-12),Color("a88b5c"),2,true)
	var arch: Array=[]
	for i in range(25):
		var a:=PI+PI*float(i)/24
		arch.append(p+Vector2(cos(a)*122,-236+sin(a)*38))
	_curve(arch,Color("30313c"),22)
	_curve(arch,Color("887050"),2)
	# A short chain of dots is a wayfinding mark; names come from the bilingual
	# interaction label rather than painting illegible text into the scenery.
	for i in range(clampi(target,1,5)):
		draw_circle(p+Vector2((i-2)*8,-248),1.7,Color("b09666"))

func _spine(r: Rect2) -> void:
	if not _visible_world.intersects(r.grow(20)): return
	_book(r,Color("43434d"))
	for y in [r.position.y+11,r.end.y-14]:
		draw_line(Vector2(r.position.x+6,y),Vector2(r.end.x-6,y),Color("b39766"),4,true)
	draw_line(r.position+Vector2(5,1),Vector2(r.end.x-4,r.position.y+1),Color("dfc18c"),2.4,true)
	# Visible dark side face gives the exact blocking volume a solid read.
	draw_rect(Rect2(r.position+Vector2(r.size.x-13,5),Vector2(10,r.size.y-7)),Color("292e3a"))

func _torn_binding(r: Rect2) -> void:
	if not _visible_world.intersects(r.grow(90)): return
	for side in [-1.0,1.0]:
		var x:=r.position.x if side<0 else r.end.x
		draw_line(Vector2(x,r.position.y+8),Vector2(x-side*30,r.position.y+65),Color("7f5a4e"),5,true)
		draw_line(Vector2(x-side*8,r.position.y+13),Vector2(x-side*22,r.position.y+45),Color("b9a17c"),2,true)
	# No floor is drawn across the open interval. The landing lips stay exact.

func _ink_nozzle(spec: Dictionary) -> void:
	var p: Vector2=spec.foot
	if not _in_view(p,Vector2(120,125)): return
	var t:=fposmod(float(world_ref.elapsed)+float(spec.phase_offset),float(spec.period))
	var live:=t>=float(spec.telegraph) and t<float(spec.telegraph)+float(spec.active)
	_book(Rect2(p+Vector2(-35,-9),Vector2(70,16)),Color("3b3d48"),true)
	draw_arc(p+Vector2(0,-10),17,PI,TAU,22,Color("ad8b59"),4,true)
	for dx in [-10.0,0.0,10.0]:
		var height_value:=42.0 if live else (10.0+sin(t*7)*3.0 if t<float(spec.telegraph) else 3.0)
		draw_line(p+Vector2(dx,-12),p+Vector2(dx+sin(elapsed*6+dx)*3,-height_value),Color("a5d2cd") if live else Color("607677"),3.4,true)
	if live: _glow(p-Vector2(0,25),37,Color("8ec9c6"),.07)

func _floor_seal(p: Vector2, active: bool, glyph: int) -> void:
	if not _in_view(p,Vector2(110,120)): return
	draw_arc(p+Vector2(0,2),29,PI,TAU,28,Color("514a3c"),7,true)
	draw_arc(p+Vector2(0,1),23,PI,TAU,28,Color("f3c47b") if active else Color("ae956b"),2,true)
	for i in range(glyph+1):
		draw_line(p+Vector2((i-glyph*.5)*7,-12),p+Vector2((i-glyph*.5)*7,-23),Color("ffe0a1") if active else Color("938469"),2,true)
	if active: _glow(p-Vector2(0,10),48,Color("e8b56e"),.04)

func _counterweight_relay() -> void:
	var solved:=bool(world_ref.progress.get("m28_counterweight_relay_solved",false))
	var history: Array=world_ref.progress.get("m28_counterweight_relay_history",[])
	for relay in definition.get("m28_relays",[]): _floor_seal(relay.pos,solved or history.has(int(relay.glyph)),int(relay.glyph))
	var origin:=Vector2(2460,635)
	if not _in_view(origin,Vector2(420,210)): return
	var rope:=PackedVector2Array()
	for i in range(25):
		var u:=float(i)/24
		rope.append(origin+Vector2(-150+u*300,sin(u*PI)*8))
	draw_polyline(rope,Color("77634a"),5,true)
	draw_polyline(rope,Color("b39a70"),1.3,true)
	for i in range(3):
		var p:=origin+Vector2((i-1)*95,15)
		draw_line(p,p+Vector2(0,47),Color("b69b70"),2,true)
		var mark: int=[0,2,1][i]
		for n in range(mark+1): draw_line(p+Vector2((n-mark*.5)*7,55),p+Vector2((n-mark*.5)*7,75),Color("d1b47f"),3,true)

func _vault_front(p: Vector2, bell: bool) -> void:
	if not _in_view(p,Vector2(470,440)): return
	var frame:=Color("2c303c")
	# Two broad bound volumes form an inhabitable doorway, not a floating icon.
	for side in [-1.0,1.0]:
		_book(Rect2(p+Vector2(side*151-39,-318),Vector2(78,318)),frame)
		for y in [-285.0,-170.0,-43.0]: draw_line(p+Vector2(side*151-32,y),p+Vector2(side*151+32,y),Color("8f744e"),6,true)
	_book(Rect2(p+Vector2(-212,-340),Vector2(424,38)),Color("373641"),true)
	_book(Rect2(p+Vector2(-171,-368),Vector2(342,25)),Color("494148"),true)
	_arch(p-Vector2(0,3),260,305,Color("363744"))
	var ink:=Color("0c1421")
	var dome: Array=[p+Vector2(-111,0),p+Vector2(-111,-202)]
	for i in range(25):
		var a:=PI+PI*float(i)/24
		dome.append(p+Vector2(cos(a)*111,-202+sin(a)*83))
	dome.append(p+Vector2(111,0))
	_poly(dome,ink)
	_curve(dome.slice(1,dome.size()-1),Color("a28558"),3)
	if bell:
		draw_arc(p+Vector2(0,-326),19,PI,TAU,24,Color("c2a06c"),3,true)
		_poly([p+Vector2(-17,-326),p+Vector2(-24,-299),p+Vector2(24,-299),p+Vector2(17,-326)],Color("c2a06c"))
		draw_circle(p+Vector2(0,-293),4,Color("e7c58a"))
	else:
		_book(Rect2(p+Vector2(-24,-345),Vector2(48,34)),Color("705945"))
		draw_line(p+Vector2(0,-341),p+Vector2(0,-316),Color("d6b683"),2,true)
	for side in [-1.0,1.0]: _shelf(p+Vector2(side*212,12),Vector2(58,220),room_id+int(side),.86)
	_glow(p-Vector2(0,215),83,Color("f2bc6c"),.025)

func _market_front(p: Vector2) -> void:
	if not _in_view(p,Vector2(500,470)): return
	_book(Rect2(p+Vector2(-224,-318),Vector2(448,318)),Color("17202d"))
	for side in [-1.0,1.0]: _shelf(p+Vector2(side*168,0),Vector2(96,268),10+int(side),.98)
	# Open service window stays behind the hero; no merchant body is invented.
	_book(Rect2(p+Vector2(-113,-267),Vector2(226,184)),Color("0b121f"))
	_book(Rect2(p+Vector2(-124,-88),Vector2(248,24)),Color("6f5941"),true)
	_book(Rect2(p+Vector2(-108,-65),Vector2(216,65)),Color("302c34"))
	for x in [-60.0,30.0]: _book(Rect2(p+Vector2(x,-131),Vector2(32,41)),Color("756144"))
	# Brass shop sign: a coin, map fold and wick, with no baked text.
	_book(Rect2(p+Vector2(-129,-360),Vector2(258,40)),Color("3e3540"),true)
	draw_arc(p+Vector2(-62,-341),11,0,TAU,30,Color("d2b27a"),2,true)
	draw_line(p+Vector2(-62,-348),p+Vector2(-62,-334),Color("d2b27a"),2,true)
	_poly([p+Vector2(-12,-350),p+Vector2(10,-345),p+Vector2(28,-351),p+Vector2(31,-333),p+Vector2(10,-328),p+Vector2(-10,-333)],Color("bfa77c"))
	draw_line(p+Vector2(10,-345),p+Vector2(10,-328),Color("5b5144"),1.5,true)
	draw_arc(p+Vector2(71,-338),9,PI,TAU,18,Color("e0b16c"),2,true)
	var canopy:=PackedVector2Array([p+Vector2(-249,-319),p+Vector2(249,-319),p+Vector2(276,-278),p+Vector2(231,-265),p+Vector2(0,-284),p+Vector2(-233,-263),p+Vector2(-274,-278)])
	draw_colored_polygon(canopy,Color("40323e"))
	draw_polyline(canopy,Color("917259"),2,true)
	for x in [-191.0,191.0]: _lamp(p+Vector2(x,-30),184)

func _round_landmark(p: Vector2, tint: Color, mark: int) -> void:
	if not _in_view(p,Vector2(460,370)): return
	draw_circle(p-Vector2(0,205),119,Color("111a28"))
	draw_arc(p-Vector2(0,205),119,PI,TAU+PI,80,tint,13,true)
	draw_arc(p-Vector2(0,205),105,PI,TAU+PI,80,tint.lightened(.2),1.5,true)
	for i in range(mark+1):
		draw_line(p+Vector2((i-mark*.5)*22,-230),p+Vector2((i-mark*.5)*22,-182),tint.lightened(.27),5,true)
	for side in [-1.0,1.0]: _book(Rect2(p+Vector2(side*148-24,-295),Vector2(48,295)),Color("292b36"))

func _notice_cabinet(p: Vector2) -> void:
	if not _in_view(p,Vector2(330,335)): return
	_book(Rect2(p+Vector2(-142,-303),Vector2(284,270)),Color("252b38"))
	for i in range(3):
		var r:=Rect2(p+Vector2(-116+i*80,-270+float(i%2)*12),Vector2(68,142-float(i%2)*8))
		_paper(r,Color("746d5f"),true)
		_book(Rect2(r.position+Vector2(-4,-6),Vector2(r.size.x+8,11)),Color("5f5140"),true)
	for side in [-1.0,1.0]: draw_line(p+Vector2(side*115,-34),p+Vector2(side*115,0),Color("5a4b3b"),7,true)

func _ink_manifold(p: Vector2) -> void:
	if not _in_view(p,Vector2(300,350)): return
	for i in range(3):
		var c:=p+Vector2((i-1)*67,-142)
		draw_line(c+Vector2(0,132),c+Vector2(0,-112+18*i),Color("283b45"),24,true)
		draw_line(c+Vector2(-8,122),c+Vector2(-8,-100+18*i),Color("5b716e"),3,true)
		for yy in [-88.0,60.0]: draw_line(c+Vector2(-17,yy),c+Vector2(17,yy),Color("9b835b"),6,true)
	_book(Rect2(p+Vector2(-123,-17),Vector2(246,17)),Color("31333b"),true)

func _hanging_scrolls(p: Vector2, count_value: int) -> void:
	if not _in_view(p,Vector2(350,335)): return
	for i in range(count_value):
		var q:=p+Vector2((i-(count_value-1)*.5)*79,-275)
		draw_line(q-Vector2(0,54),q,Color("695d49"),2,true)
		_paper(Rect2(q-Vector2(26,0),Vector2(52,147)),Color("7c7464"),true)
		for yy in [0.0,147.0]: _book(Rect2(q+Vector2(-33,yy-5),Vector2(66,12)),Color("66503e"),true)

func _sleeping_recess(p: Vector2) -> void:
	if not _in_view(p,Vector2(970,500)): return
	# An authored destination for the future final boss, visibly empty today.
	for side in [-1.0,1.0]:
		_shelf(p+Vector2(side*360,8),Vector2(180,350),14+int(side),.9)
		_book(Rect2(p+Vector2(side*255-34,-415),Vector2(68,415)),Color("282b3a"))
	_book(Rect2(p+Vector2(-295,-439),Vector2(590,36)),Color("393442"),true)
	draw_arc(p-Vector2(0,219),110,PI,TAU,60,Color("6d6070"),5,true)
	draw_arc(p-Vector2(0,219),84,PI,TAU,60,Color("4b475b"),2,true)
