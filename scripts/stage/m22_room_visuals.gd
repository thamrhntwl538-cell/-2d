extends "res://scripts/stage/m21_room_visuals.gd"
## M22 adds quiet, geometry-aligned reading nooks and small book-door frames.
## Actual books, desks and lecterns belong to the M22 interactable renderer.
var curated_nooks: Array = []
var entrance_frames: Array = []
var solid_book_overlay: Node2D
const M22Foreground=preload("res://scripts/stage/m22_foreground.gd")

class SolidBookOverlay extends Node2D:
	var covers: Array[Rect2] = []
	func _draw() -> void:
		for rect in covers:
			# Leave the physical top lip visible. A closed binding differentiates
			# a solid projectile shield from an open, one-way paper shelf.
			draw_rect(Rect2(rect.position+Vector2(2,5),rect.size-Vector2(4,7)),Color("29303b"))
			for fraction in [0.25,0.73]:
				var y := rect.position.y+rect.size.y*float(fraction)
				draw_line(Vector2(rect.position.x+4,y),Vector2(rect.end.x-4,y),Color("b49361"),4.0,true)
			draw_line(rect.position+Vector2(6,8),Vector2(rect.position.x+6,rect.end.y-8),Color("73654f"),1.6,true)

func setup(world: Node2D, room_definition: Dictionary) -> void:
	curated_nooks = room_definition.get("reading_nooks",[])
	entrance_frames = room_definition.get("entrance_frames",[])
	super.setup(world,room_definition)
	# Keep the frozen M21 foreground intact; only M22 substitutes broader groups.
	remove_child(foreground)
	foreground.free()
	foreground=M22Foreground.new()
	add_child(foreground)
	foreground.setup(world,definition)
	var overlay := SolidBookOverlay.new()
	overlay.name="SolidBookBindings"
	overlay.z_index=8 # M21 dressing is -6; bindings draw at world2, below hero5.
	for platform in definition.get("platforms",[]):
		var id := str(platform.get("id",""))
		if id.begins_with("turret_cover_") or id in ["corrector_book_threshold","departure_book_threshold"]:
			overlay.covers.append(platform.rect)
	add_child(overlay)
	solid_book_overlay=overlay

func _build_lights() -> void:
	# Register raised lamps before M21 instantiates its real PointLight2D pools.
	# The same specs draw the physical fixtures, so light never floats alone.
	for nook in curated_nooks:
		var anchor: Vector2 = nook.anchor
		_append_lamp(anchor+Vector2(-76,12),126.0,0.68)
	super._build_lights()

func _draw_atmosphere() -> void:
	for frame in entrance_frames: _draw_book_door(frame)
	for nook in curated_nooks: _draw_reading_alcove(nook)
	super._draw_atmosphere()

func _draw_book_door(frame: Dictionary) -> void:
	var p: Vector2 = frame.anchor
	var side := -1.0 if str(frame.side)=="left" else 1.0
	var jamb := p+Vector2(side*90,0)
	if not _visible_world.intersects(Rect2(p-Vector2(150,250),Vector2(300,270))): return
	# One close cabinet edge marks the entrance; the open centre stays clear.
	_book(Rect2(jamb+Vector2(-20,-228),Vector2(40,228)),Color("293039"))
	draw_line(jamb+Vector2(-side*18,-220),jamb+Vector2(-side*18,-12),Color("9c8055"),2.0,true)
	_poly([jamb+Vector2(-28,-228),jamb+Vector2(-28,-246),jamb+Vector2(-side*115,-246),jamb+Vector2(-side*115,-235)],Color("363844"))
	draw_line(p+Vector2(-50,4),p+Vector2(50,4),Color("ad956e"),3.0,true)

func _draw_reading_alcove(nook: Dictionary) -> void:
	var p: Vector2 = nook.anchor
	var bounds := Rect2(p-Vector2(140,178),Vector2(280,180))
	if not _visible_world.intersects(bounds): return
	var rest := str(nook.style)=="rest"
	var half_width := 127.0 if rest else 114.0
	var top := p.y-(148.0 if rest else 138.0)
	# Open-backed bindings leave the painted wall visible. Adjacent reading
	# places remain separate objects instead of joining into a black panel.
	var left := Rect2(p.x-half_width,top+17,18,p.y-top-22)
	var right := Rect2(p.x+half_width-17,top+40,15,p.y-top-45)
	draw_style_box(_binding_style(),left)
	draw_style_box(_binding_style(),right)
	draw_line(left.position+Vector2(4,9),Vector2(left.position.x+4,left.end.y-9),Color("62563f"),1.4,true)
	draw_line(right.position+Vector2(4,9),Vector2(right.position.x+4,right.end.y-7),Color("51483c"),1.3,true)
	draw_line(p+Vector2(-half_width+4,-5),p+Vector2(half_width-4,-5),Color("4d4439"),3.0,true)
	# Two closed volumes indicate a deliberately arranged alcove rather than
	# a trail of loose pages. Interactive foreground props remain unique.
	if not rest:
		_book(Rect2(p+Vector2(62,-27),Vector2(33,20)),Color("5c4b48"),true)
		_book(Rect2(p+Vector2(58,-39),Vector2(36,12)),Color("4c515c"),true)

func _binding_style() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color=Color("202631")
	panel.corner_radius_top_left=5
	panel.corner_radius_top_right=8
	return panel
