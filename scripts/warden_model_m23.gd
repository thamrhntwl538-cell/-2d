extends "res://scripts/warden_model_m21.gd"
## Approved M20 atlas/M21 face, with the requested compact ember strike.
## Attack timing and locomotion live in the existing player. Only authored
## joints, the small held blade and its matching short flame envelope change.
const COMPACT_BLADE_LENGTH := 52.0
const COMPACT_FORWARD_WIDTH := 158.0
const COMPACT_FORWARD_HEIGHT := 116.0
const COMPACT_UP_WIDTH := 180.0
const COMPACT_DOWN_WIDTH := 162.0
const COMPACT_ARC_END := 0.56
const DRIVE_KEYS := [
	[0.0,0.0], [0.16,-2.0], [0.29,15.0], [0.43,13.0],
	[0.60,-4.0], [0.78,-1.5], [1.0,0.0]
]

func set_combat_pose(kind: String, phase: float, airborne: bool = false, movement_sample: float = 0.0, grounded_running: bool = false) -> void:
	super.set_combat_pose(kind,phase,airborne,movement_sample,grounded_running)
	if kind in ["slash","slash_follow"]:
		# Feet retain their distance-driven support. The shoulder/head travel
		# briefly forward through a rigid torso lean, then settle behind ready.
		pose.lean = float(_sample(DRIVE_KEYS,combat_phase)[0])
		pose.cape = float(pose.cape) + 4.0*sin(combat_phase*PI)
		_update_geometry()
		queue_redraw()

func _update_geometry() -> void:
	_blade_length = COMPACT_BLADE_LENGTH
	super._update_geometry()

func _update_fire_arc() -> void:
	strike_polygon.clear()
	arc_polygon.clear()
	strike_active = false
	_arc_opacity = 0.0
	if not combat_kind.begins_with("slash"): return
	if combat_phase<ARC_START or combat_phase>COMPACT_ARC_END: return
	_arc_opacity = smoothstep(ARC_START,CONTACT_START,combat_phase) if combat_phase<CONTACT_START else (1.0 if combat_phase<=CONTACT_END else 1.0-smoothstep(CONTACT_END,COMPACT_ARC_END,combat_phase))
	_arc_scale = maxf(0.25,sword_reach)
	_arc_angle = 0.0
	_arc_origin = FEET+Vector2(8,-108)
	_arc_width = COMPACT_FORWARD_WIDTH
	_arc_height = COMPACT_FORWARD_HEIGHT
	if combat_kind=="slash_up":
		_arc_angle = -PI*0.5
		_arc_origin = FEET+Vector2(0,-180)
		_arc_width = COMPACT_UP_WIDTH
		_arc_height = 136.0
	elif combat_kind=="slash_down":
		_arc_angle = PI*0.5
		_arc_origin = FEET+Vector2(0,-5)
		_arc_width = COMPACT_DOWN_WIDTH
		_arc_height = 132.0
	var variant := attack_variant if combat_kind in ["slash","slash_follow"] else 0
	var local := _crescent(_arc_width*_arc_scale,_arc_height*_arc_scale,variant)
	for point in local: arc_polygon.append(_arc_origin+point.rotated(_arc_angle))
	strike_active = combat_phase>=CONTACT_START and combat_phase<=CONTACT_END
	if strike_active:
		var minimum := maxf(48.0,float(joints.head_axis[0].x-_arc_origin.x)+HEAD_RECT.end.x+6.0)
		if combat_kind=="slash_up": minimum = maxf(18,_arc_origin.y-float(joints.head_axis[0].y)+114)
		elif combat_kind=="slash_down": minimum = maxf(18,FEET.y-_arc_origin.y+6)
		for point in _clip_forward(local,minimum): strike_polygon.append(_arc_origin+point.rotated(_arc_angle))

func _draw_sword() -> void:
	# A short ember blade, shown only for the existing attack/recoil pose.
	var angle := deg_to_rad(_sword_angle)
	var length := _blade_length*sword_reach
	draw_set_transform(sword_start,angle)
	draw_line(Vector2(-12,0),Vector2(2,0),Color("211b20"),6.5,true)
	draw_line(Vector2(-11,0),Vector2(1,0),Color("ad7d43"),3.5,true)
	draw_line(Vector2(0,-6),Vector2(0,6),Color("d7ad6f"),3.0,true)
	var blade := PackedVector2Array([Vector2(3,-3.4),Vector2(length-12,-2.3),Vector2(length,0),Vector2(length-12,2.3),Vector2(3,3.4)])
	draw_colored_polygon(blade,Color("f5ad57"))
	var outline := blade.duplicate()
	outline.append(blade[0])
	draw_polyline(outline,Color("654027"),1.6,true)
	draw_line(Vector2(4,0),Vector2(length-5,0),Color("fff0c7"),2.2,true)
	draw_set_transform(Vector2.ZERO)
	if not arc_polygon.is_empty():
		var edge := arc_polygon.duplicate()
		edge.append(arc_polygon[0])
		draw_polyline(edge,Color(1.0,0.53,0.18,0.06*_arc_opacity),9.0,true)
		draw_polyline(edge,Color(1.0,0.67,0.30,0.12*_arc_opacity),4.5,true)
		draw_colored_polygon(arc_polygon,Color(1.0,0.56,0.20,0.88*_arc_opacity))
		var inner := PackedVector2Array()
		var variant := attack_variant if combat_kind in ["slash","slash_follow"] else 0
		for point in _crescent(_arc_width*_arc_scale*0.975,_arc_height*_arc_scale*0.93,variant):
			inner.append(_arc_origin+(point+Vector2(1.3,0)).rotated(_arc_angle))
		draw_colored_polygon(inner,Color(1.0,0.91,0.68,_arc_opacity))
		draw_polyline(edge,Color(1.0,0.76,0.36,0.25*_arc_opacity),1.2,true)
