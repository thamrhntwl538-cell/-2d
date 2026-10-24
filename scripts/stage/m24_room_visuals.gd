extends "res://scripts/stage/m23_room_visuals.gd"
## M24 keeps the approved close wall and turns the bindery into a quiet stage.
## This renderer owns no collision, attack, hazard clock or encounter state.
const BellForeground=preload("res://scripts/stage/m24_foreground.gd")
const BELL_QUIET_ZONE:=Rect2(900,900,1500,360)
const PARKED_PRESS_FEET: Array[Vector2]=[Vector2(755,1260),Vector2(2690,1260)]

func setup(world: Node2D, room_definition: Dictionary) -> void:
	super.setup(world,room_definition)
	if room_id!=12: return
	name="BellBinderyVisuals"
	# Keep the nearby painted shelves, slightly quieter behind moving bodies.
	for sprite in far_sprites: sprite.modulate=Color(.83,.86,.92,1.0)
	remove_child(foreground)
	foreground.free()
	foreground=BellForeground.new()
	add_child(foreground)
	foreground.setup(world,definition)

func _build_lights() -> void:
	if room_id==12:
		# Only two small, fixed pools sit inside the encounter. The inherited
		# reading pools remain outside the gates, beside the two safe benches.
		_append_lamp(Vector2(1050,floor_y+16),225.0,.46)
		_append_lamp(Vector2(2230,floor_y+16),225.0,.46)
	super._build_lights()

func _draw_structural_depth() -> void:
	if room_id!=12:
		super._draw_structural_depth()
		return
	# No repeated cabinet backs behind the combat silhouettes. The painted
	# close shelves already supply detail; these four groups frame the route.
	for group in [
		{"foot":Vector2(330,floor_y+18),"size":Vector2(150,285),"seed":121},
		{"foot":Vector2(795,floor_y+18),"size":Vector2(110,248),"seed":124},
		{"foot":Vector2(2780,floor_y+18),"size":Vector2(115,250),"seed":127},
		{"foot":Vector2(3420,floor_y+18),"size":Vector2(150,284),"seed":130}
	]:
		_shelf(group.foot,group.size,group.seed,.60)

func _bindery() -> void:
	if room_id!=12:
		super._bindery()
		return
	# The old presses are parked outside x900..2400. No moving bar, ram,
	# flashing floor line or pale slab crosses a body or landing trajectory.
	for foot in PARKED_PRESS_FEET: _draw_parked_press(foot)
	# Closed volumes and a restrained parchment stack retain workshop scale.
	for foot in [Vector2(710,floor_y),Vector2(2740,floor_y)]:
		_book(Rect2(foot+Vector2(-24,-32),Vector2(68,28)),Color("34313a"),true)
		_book(Rect2(foot+Vector2(-20,-44),Vector2(61,11)),Color("3e383c"),true)
	# Dressing near the existing latches stays to the side of their handles.
	_book(Rect2(3000,floor_y-38,86,31),Color("35343d"),true)
	_paper(Rect2(3011,floor_y-46,64,9),Color("746859"))
	_ribbon(Vector2(3400,760),Vector2(3420,965),13,1.6)

func _draw_parked_press(foot: Vector2) -> void:
	var bounds:=Rect2(foot-Vector2(72,448),Vector2(144,466))
	if not _visible_world.intersects(bounds): return
	# A slim pair of side posts and a raised empty platen; the nearest book
	# gate remains the only solid encounter boundary and owns its own render.
	for dx in [-58.0,58.0]:
		var r:=Rect2(foot+Vector2(dx-6,-427),Vector2(12,440))
		draw_style_box(_press_style(Color("202833"),4),r)
		draw_line(r.position+Vector2(2,7),r.position+Vector2(2,r.size.y-9),Color("4c4942"),1.2,true)
	draw_style_box(_press_style(Color("30353e"),5),Rect2(foot+Vector2(-72,-448),Vector2(144,26)))
	draw_line(foot+Vector2(-65,-443),foot+Vector2(63,-443),Color("635a48"),1.5,true)
	draw_style_box(_press_style(Color("4b4841"),4),Rect2(foot+Vector2(-51,-388),Vector2(102,15)))
	draw_line(foot+Vector2(0,-422),foot+Vector2(0,-391),Color("675b44"),7.0,true)
	for dx in [-57.0,57.0]:
		draw_circle(foot+Vector2(dx,-435),3.2,Color("171e29"))
		draw_arc(foot+Vector2(dx,-435),3.2,PI,TAU,12,Color("756347"),1.0,true)

func _press_style(tint: Color, radius: int) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=tint
	style.set_corner_radius_all(radius)
	return style
