extends "res://scripts/stage/m28_room_visuals.gd"
## Close original paper architecture. Doors belong to complete roofed masses;
## their interaction, fade and interior destination belong to the world.
const NearFrame=preload("res://scripts/stage/m29_foreground.gd")
const ART_MANIFEST="res://assets/environments/m29/art_manifest.json"
var interior_kind: String=""
var painted_facades:=0
var painted_interiors:=0
var _art: Dictionary={}

class HouseCrest extends Node2D:
	var kind: String="market"
	func _draw() -> void:
		draw_line(Vector2(0,-24),Vector2(0,-7),Color("8d7754"),2,true)
		var panel:=StyleBoxFlat.new()
		panel.bg_color=Color("242936")
		panel.border_color=Color("8e7855")
		panel.set_border_width_all(2)
		panel.set_corner_radius_all(6)
		draw_style_box(panel,Rect2(-25,-6,50,51))
		if kind=="bell":
			draw_arc(Vector2(0,10),10,PI,TAU,18,Color("d5b77d"),2,true)
			draw_colored_polygon(PackedVector2Array([Vector2(-10,10),Vector2(-15,29),Vector2(15,29),Vector2(10,10)]),Color("bfa06c"))
			draw_circle(Vector2(0,33),3,Color("e0bf80"))
		elif kind=="archivist":
			for i in range(3):
				draw_rect(Rect2(-15+i,7+i*8,29,7),Color("bd9e70"))
				draw_line(Vector2(-11+i,9+i*8),Vector2(11+i,9+i*8),Color("5c5144"),1,true)
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(-16,7),Vector2(0,12),Vector2(16,6),Vector2(18,29),Vector2(0,35),Vector2(-16,29)]),Color("bda67a"))
			draw_line(Vector2(0,12),Vector2(0,35),Color("5b4e40"),2,true)

func setup(world: Node2D, room_definition: Dictionary) -> void:
	interior_kind=str(room_definition.get("m29_interior",""))
	if FileAccess.file_exists(ART_MANIFEST):
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(ART_MANIFEST))
		if parsed is Dictionary: _art=parsed
	super.setup(world,room_definition)
	name="CloseBuildingsAndInteriorsM29"
	ambient.color=Color(.28,.31,.40,1)
	far_parallax_factor=.43
	mid_parallax_factor=.88
	for sprite in far_sprites: sprite.modulate=Color(.68,.72,.87,1)
	remove_child(foreground)
	foreground.free()
	foreground=NearFrame.new()
	add_child(foreground)
	foreground.setup(world,definition)
	if interior_kind=="market": _build_market_interior()
	else:
		for building in definition.get("m29_buildings",[]): _build_painted_facade(building)

# Suppress the former facade-only paintings. M29 draws the exterior mass and
# uses the actual quiet shop painting only after the player enters the door.
func _build_market_art() -> void: pass
func _build_vault_art() -> void: pass
func _build_bell_art() -> void: pass
func _draw_threshold(_point: Vector2, _target: int) -> void: pass

func _round_landmark(p: Vector2, tint: Color, mark: int) -> void:
	# A small wall clock belongs among the shelves. The old room-sized disk
	# competed with the seated character and looked like an unfinished panel.
	if not _in_view(p,Vector2(140,290)): return
	var centre:=p-Vector2(0,214)
	draw_circle(centre,42,Color(.08,.105,.16,.82),true,-1,true)
	draw_arc(centre,42,0,TAU,64,Color(tint,.72),3,true)
	draw_arc(centre,36,0,TAU,64,Color("6b6054"),1,true)
	for i in range(12):
		var direction:=Vector2.UP.rotated(float(i)*TAU/12)
		draw_line(centre+direction*29,centre+direction*33,Color("94846a"),1.5,true)
	draw_line(centre,centre+Vector2(7,-22).rotated(float(mark)*.35),Color("b19b71"),2.5,true)
	draw_line(centre,centre+Vector2(-15,-6),Color("8f7d5c"),2,true)
	draw_circle(centre,3,Color("c0a579"),true,-1,true)

func _build_market_interior() -> void:
	var spec: Dictionary=_art.get("market_interior",{})
	var path:=str(spec.get("path",""))
	if path.is_empty() or not ResourceLoader.exists(path): return
	var image:=load(path) as Texture2D
	if image==null: return
	var painting:=Sprite2D.new()
	painting.name="CloseMarginExchangeInterior"
	painting.texture=image
	painting.centered=false
	# A uniformly closer rear painting gives the room the enclosed scale of
	# the reference; the hero, furniture and collision sizes stay unchanged.
	var k:=1280.0/image.get_width()*1.1
	painting.scale=Vector2.ONE*k
	painting.position=Vector2(0,620.0-float(spec.get("source_floor_y",806.0))*k)
	painting.z_index=1
	var shader:=Shader.new()
	shader.code="shader_type canvas_item; render_mode unshaded; void fragment(){ vec4 p=texture(TEXTURE,UV); p.rgb*=vec3(.78,.83,.95); p.a*=smoothstep(0.0,.08,UV.y); COLOR=p; }"
	var material_value:=ShaderMaterial.new()
	material_value.shader=shader
	painting.material=material_value
	add_child(painting)
	painted_interiors+=1
	_match_market_floor.call_deferred()

func _match_market_floor() -> void:
	if interior_kind!="market" or not is_instance_valid(world_ref): return
	var surfaces: Node2D=world_ref.get("surface_root") as Node2D
	if not is_instance_valid(surfaces): return
	for body in surfaces.get_children():
		if str(body.name)=="m29_market_floor":
			# Keep the exact body/ray support, while the authored stone lip from
			# the interior painting supplies its surface instead of an extra book.
			body.self_modulate=Color(1,1,1,0)

func _build_painted_facade(building: Dictionary) -> void:
	var kind:=str(building.kind)
	var specs: Dictionary=_art.get("facades",{})
	var spec: Dictionary=specs.get(kind,specs.get("passage",{}))
	var path:=str(spec.get("path",""))
	if path.is_empty() or not ResourceLoader.exists(path): return
	var image:=load(path) as Texture2D
	if image==null: return
	var painting:=Sprite2D.new()
	painting.name="WholeBuilding_"+kind
	painting.texture=image
	painting.centered=false
	var k:=float(spec.get("scale",.50))
	var source_door: Array=spec.get("source_door",[image.get_width()*.5,image.get_height()*.95])
	var mirror:=int(building.get("side",0))<0
	var source_x:=float(image.get_width())-float(source_door[0]) if mirror else float(source_door[0])
	painting.position=(building.door as Vector2)-Vector2(source_x,float(source_door[1]))*k
	painting.flip_h=mirror
	painting.scale=Vector2.ONE*k
	painting.z_index=1
	var material_value:=CanvasItemMaterial.new()
	material_value.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
	painting.material=material_value
	painting.modulate=Color(.77,.80,.90,1) if kind=="archivist" else Color(.86,.83,.91,1)
	add_child(painting)
	if kind!="passage":
		var crest:=HouseCrest.new()
		crest.kind=kind
		crest.position=(building.door as Vector2)+Vector2(-92 if mirror else 92,-204)
		crest.z_index=2
		crest.material=material_value
		add_child(crest)
	building["painted"]=true
	painted_facades+=1

func _build_lights() -> void:
	if interior_kind=="market":
		_append_lamp(Vector2(500,634),205,.88)
		_append_lamp(Vector2(940,634),260,.82)
		_append_lamp(Vector2(160,634),190,.62)
	else:
		for building in definition.get("m29_buildings",[]):
			var door: Vector2=building.door
			_append_lamp(door+Vector2(-147,14),235,.74)
			if str(building.kind)!="passage": _append_lamp(door+Vector2(155,14),265,.84)
	super._build_lights()

func _draw() -> void:
	if definition.is_empty(): return
	if interior_kind=="market":
		_draw_market_interior()
		return
	super._draw()
	if interior_kind=="bell": _draw_bindery_interior()

func _draw_atmosphere() -> void:
	super._draw_atmosphere()
	if interior_kind.is_empty():
		for building in definition.get("m29_buildings",[]): _draw_complete_building(building)
	for object in definition.get("objects",[]):
		if str(object.get("kind",""))=="bench": _draw_rest_alcove(object.pos)
		elif str(object.get("kind",""))=="interior_exit": _draw_return_door(object.pos)

func _draw_complete_building(spec: Dictionary) -> void:
	var p: Vector2=spec.door
	var width_value:=float(spec.width)
	var height_value:=float(spec.height)
	if not _in_view(p,Vector2(width_value+120,height_value+100)): return
	if bool(spec.get("painted",false)): return
	var side:=int(spec.get("side",0))
	var centre:=p+Vector2(-side*95,0)
	var kind:=str(spec.kind)
	var w:=width_value
	var h:=height_value
	var face:=Rect2(centre+Vector2(-w*.5,-h*.78),Vector2(w,h*.78+8))
	var shell:=StyleBoxFlat.new()
	shell.bg_color=Color("16202f")
	shell.border_color=Color("3e414e")
	shell.set_border_width_all(3)
	shell.set_corner_radius_all(28)
	draw_style_box(shell,face)
	# Full walls, roof, two binding supports and foundation give the doorway a
	# tangible inhabited volume even where the room edge crops one side.
	for s in [-1.0,1.0]:
		var at:=centre+Vector2(s*(w*.5-24),-h*.73)
		_book(Rect2(at,Vector2(25,h*.73)),Color("282b3a"))
		draw_line(at+Vector2(7,24),at+Vector2(7,h*.68),Color("71604d"),2,true)
		for yy in [.22,.61]: draw_line(at+Vector2(-3,h*yy),at+Vector2(28,h*yy),Color("827054"),4,true)
	var roof:=PackedVector2Array()
	var upper:=PackedVector2Array()
	for i in range(31):
		var u:=float(i)/30
		var at:=centre+Vector2((u-.5)*(w+66),-h*.76-86*pow(sin(u*PI),.78))
		roof.append(at)
		upper.append(at)
	for i in range(30,-1,-1): roof.append(upper[i]+Vector2(0,31))
	draw_colored_polygon(roof,Color("272936"))
	draw_polyline(upper,Color("847154"),2.6,true)
	var ridge:=upper.duplicate()
	for i in range(ridge.size()): ridge[i]+=Vector2(0,24)
	draw_polyline(ridge,Color("403c43"),3,true)
	for s in [-1.0,1.0]:
		var at:=centre+Vector2(s*w*.30,-h*.47)
		if absf(at.x-p.x)<110: continue
		_draw_glass_window(at,Vector2(31,53))
	_draw_door_opening(p,83,255 if kind=="passage" else 290)
	_book(Rect2(centre+Vector2(-w*.5-7,1),Vector2(w+14,12)),Color("3b3740"),true)
	if kind!="passage": _draw_house_crest(p-Vector2(0,342),kind)
	# Grouped scrolls sit on a side wall rather than as loose floor litter.
	if side!=0:
		var at:=centre+Vector2(-side*w*.30,-34)
		for i in range(3): draw_arc(at+Vector2(i*14,0),7,0,TAU,20,Color("61574d"),4,true)

func _draw_door_opening(p: Vector2, half_width: float, height_value: float) -> void:
	var cap:=half_width*.92
	var spring:=height_value-cap
	var shape:=PackedVector2Array([p+Vector2(-half_width,4),p+Vector2(-half_width,-spring)])
	var band:=PackedVector2Array()
	for i in range(31):
		var angle:=PI+PI*float(i)/30
		var at:=p+Vector2(cos(angle)*half_width,-spring+sin(angle)*cap)
		shape.append(at)
		band.append(at)
	shape.append(p+Vector2(half_width,4))
	draw_colored_polygon(shape,Color("070e1a"))
	draw_polyline(band,Color("9b805a"),3,true)
	for side in [-1.0,1.0]: draw_line(p+Vector2(side*half_width,-spring),p+Vector2(side*half_width,-3),Color("6f604b"),3,true)
	draw_line(p+Vector2(-half_width-5,0),p+Vector2(half_width+5,0),Color("c6ab78"),3,true)

func _draw_glass_window(p: Vector2, size_value: Vector2) -> void:
	var shape:=PackedVector2Array()
	for i in range(33):
		var a:=TAU*float(i)/32
		shape.append(p+Vector2(cos(a)*size_value.x,sin(a)*size_value.y))
	draw_colored_polygon(shape,Color("6e6d76"))
	draw_polyline(shape,Color("a38c67"),4,true)
	_glow(p,size_value.y*1.4,Color("f3c484"),.035)
	draw_line(p+Vector2(0,-size_value.y+4),p+Vector2(0,size_value.y-4),Color("34313b"),3,true)
	draw_line(p+Vector2(-size_value.x+4,5),p+Vector2(size_value.x-4,5),Color("34313b"),3,true)

func _draw_house_crest(p: Vector2, kind: String) -> void:
	if kind=="bell":
		draw_arc(p,15,PI,TAU,24,Color("b99a65"),3,true)
		_poly([p+Vector2(-15,0),p+Vector2(-22,27),p+Vector2(22,27),p+Vector2(15,0)],Color("a68859"))
		draw_circle(p+Vector2(0,30),4,Color("e0bd80"))
	elif kind=="archivist":
		for i in range(3): _book(Rect2(p+Vector2(-24+i*2,i*10),Vector2(47,9)),Color("977b58"),true)
	else:
		_poly([p+Vector2(-26,-4),p+Vector2(-2,2),p+Vector2(22,-6),p+Vector2(25,23),p+Vector2(0,30),p+Vector2(-24,22)],Color("a28c68"))
		draw_line(p+Vector2(-2,2),p+Vector2(0,30),Color("4a4240"),2,true)

func _draw_rest_alcove(p: Vector2) -> void:
	# Furniture belongs to the bench director. A shallow surround and one
	# local lantern make the same sitting anchor legible across all areas.
	if not _in_view(p,Vector2(310,230)): return
	for side in [-1.0,1.0]:
		draw_line(p+Vector2(side*114,-12),p+Vector2(side*114,-170),Color("222b3a"),14,true)
		if side<0: _lamp(p+Vector2(-109,-1),154)
	var canopy:=PackedVector2Array()
	for i in range(25):
		var a:=PI+PI*float(i)/24
		canopy.append(p+Vector2(cos(a)*119,-170+sin(a)*27))
	draw_polyline(canopy,Color("34313c"),18,true)
	draw_polyline(canopy,Color("73614e"),1.5,true)

func _draw_return_door(p: Vector2) -> void:
	_draw_door_opening(p,70,252)
	_lamp(p+Vector2(103,0),210)

func _draw_market_interior() -> void:
	# Fallback architecture also stays useful before the generated plate is
	# imported. The final painted room is a normal Texture2D child at world-5.
	draw_rect(Rect2(0,0,1280,720),Color("060b14"))
	if painted_interiors==0:
		for x in [25.0,1160.0]: _shelf(Vector2(x+75,620),Vector2(120,355),int(x),1)
		_shelf(Vector2(990,620),Vector2(430,360),291,.9)
		_book(Rect2(800,545,370,75),Color("39303a"),true)
		_draw_glass_window(Vector2(685,230),Vector2(85,115))
	_draw_return_door(Vector2(150,620))
	_draw_rest_alcove(Vector2(500,620))
	# Foreground ceiling is carried by NearFrame so it stays in a separate
	# plane and does not move with the painted rear wall.

func _draw_bindery_interior() -> void:
	var centre:=Vector2(1650,1260)
	if not _in_view(centre,Vector2(1550,700)): return
	var arc:=PackedVector2Array()
	for i in range(41):
		var u:=float(i)/40
		arc.append(centre+Vector2(-735+u*1470,-488-sin(u*PI)*160))
	draw_polyline(arc,Color("101725"),38,true)
	draw_polyline(arc,Color("3a3c49"),3,true)
	# One old bell and binding ropes make this chamber distinct from the vault.
	var p:=Vector2(1750,704)
	draw_line(Vector2(p.x,590),p-Vector2(0,28),Color("504534"),5,true)
	draw_arc(p,44,PI,TAU,32,Color("5e5241"),5,true)
	_poly([p+Vector2(-43,0),p+Vector2(-64,77),p+Vector2(64,77),p+Vector2(43,0)],Color("403d39"))
	draw_line(p+Vector2(-66,78),p+Vector2(66,78),Color("746144"),5,true)
	draw_circle(p+Vector2(0,89),9,Color("6d593d"))

func get_m29_environment_snapshot() -> Dictionary:
	return {"interior_kind":interior_kind,"door_buildings":definition.get("m29_buildings",[]).size(),"painted_facades":painted_facades,"painted_interiors":painted_interiors,"layers":["close_painted_wall","complete_near_architecture","readable_play_floor","near_book_silhouettes"]}
