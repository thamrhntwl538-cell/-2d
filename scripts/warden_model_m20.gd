extends Node2D
## One shared M20 rig: clean reference art, rigid parts and immediate anchors.
## Source canvas: 512 square; feet (256,456). Parent draws at 0.37 world scale.
const ATLAS_PATH := "res://assets/warden_m20/warden_parts.png"
const DRAW_SCALE := 0.37
const FEET := Vector2(256,456)
const HEAD_LEAD_PX := 8.0
const TORSO_LENGTH := 60.0
const UPPER_ARM_LENGTH := 30.0
const FOREARM_LENGTH := 26.0
const THIGH_LENGTH := 32.0
const SHIN_LENGTH := 24.0
const FOOT_LENGTH := 8.0
const RUN_PERIOD := 6.0/13.0
const RUN_WORLD_SPEED := 300.0
const STANCE_FRACTION := 0.18
const HEAD_RECT := Rect2(-86.9357,-149.2283,137.9335,154.02)
const CONTACT_START := 0.20
const CONTACT_END := 0.14/0.30
const ARC_START := 0.17
const ARC_END := 0.58
const REGIONS := {
	"head":Rect2(24,2,403,450),"torso":Rect2(483,134,179,311),
	"cape":Rect2(684,73,402,420),"scarf":Rect2(47,484,367,174),
	"upper_arm":Rect2(563,513,120,112),"forearm_hand":Rect2(889,505,131,279),
	"thigh":Rect2(147,797,130,204),"shin":Rect2(521,799,83,154),
	"foot":Rect2(844,870,150,98)
}
const SLASH_KEYS := [
	[0.0,-12.0,-4.0,30.0,18.0,0.0,0.0,-70.0],
	[0.16,-74.0,-142.0,38.0,10.0,-2.0,8.0,-118.0],
	[0.29,-50.0,-98.0,32.0,16.0,5.0,-4.0,-6.0],
	[0.47,-12.0,-64.0,34.0,20.0,5.0,-5.0,36.0],
	[0.68,4.0,-24.0,32.0,20.0,2.0,-2.0,55.0],
	[1.0,-12.0,-4.0,30.0,18.0,0.0,0.0,-70.0]
]
const FOLLOW_KEYS := [
	[0.0,-12.0,-4.0,30.0,18.0,0.0,0.0,55.0],
	[0.16,18.0,-42.0,38.0,22.0,-2.0,8.0,72.0],
	[0.29,-22.0,-82.0,32.0,18.0,5.0,-4.0,8.0],
	[0.47,-55.0,-116.0,34.0,22.0,4.0,-5.0,-42.0],
	[0.68,-38.0,-72.0,32.0,20.0,2.0,-2.0,-64.0],
	[1.0,-12.0,-4.0,30.0,18.0,0.0,0.0,-70.0]
]
const UP_KEYS := [
	[0.0,-12.0,-4.0,30.0,18.0,0.0,0.0,-70.0],
	[0.16,-24.0,-62.0,36.0,16.0,1.0,-3.0,-32.0],
	[0.29,-132.0,-162.0,34.0,20.0,-2.0,5.0,-95.0],
	[0.47,-148.0,-176.0,32.0,22.0,-3.0,4.0,-110.0],
	[0.68,-120.0,-146.0,30.0,20.0,-2.0,2.0,-120.0],
	[1.0,-12.0,-4.0,30.0,18.0,0.0,0.0,-70.0]
]
const DOWN_KEYS := [
	[0.0,-12.0,-4.0,30.0,18.0,0.0,0.0,-70.0],
	[0.16,-112.0,-146.0,38.0,18.0,-3.0,6.0,-100.0],
	[0.29,-12.0,-18.0,36.0,24.0,4.0,-4.0,86.0],
	[0.47,4.0,12.0,34.0,22.0,4.0,-4.0,96.0],
	[0.68,8.0,14.0,32.0,20.0,2.0,-2.0,102.0],
	[1.0,-12.0,-4.0,30.0,18.0,0.0,0.0,-70.0]
]

var textures: Dictionary = {}
var pose: Dictionary = {}
var joints: Dictionary = {}
var contacts: Dictionary = {}
var foot_targets: Dictionary = {}
var motion_name: String = "idle"
var run_phase: float = 0.0
var leg_running: bool = false
var feet_planted: bool = true
var sword_visible: bool = false
var sword_reach: float = 1.0
var sword_start := Vector2.ZERO
var sword_end := Vector2.ZERO
var sword_bounds := Rect2()
var lantern_center := Vector2.ZERO
var combat_kind: String = ""
var combat_phase: float = 0.0
var attack_variant: int = 0
var slash_variant: int:
	get: return attack_variant
	set(value): attack_variant = posmod(value,2)
var expression_name: String = "idle"
var expression_blend: float = 1.0
var expression_tilt: float = 0.0
var flame_intensity: float = 1.0
var strike_active: bool = false
var strike_polygon := PackedVector2Array()
var arc_polygon := PackedVector2Array()
var _arc_origin := Vector2.ZERO
var _arc_angle: float = 0.0
var _arc_opacity: float = 0.0
var _arc_scale: float = 1.0
var _arc_width: float = 340.0
var _arc_height: float = 225.0
var _sword_angle: float = -70.0
var _blade_length: float = 88.0
var _leg_angles: Dictionary = {}
var _foot_angles: Dictionary = {}

func _ready() -> void:
	var atlas: Texture2D = load(ATLAS_PATH)
	for key in REGIONS:
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = REGIONS[key]
		texture.filter_clip = true
		textures[key] = texture
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_motion("idle",0)

func set_motion(motion: String, sample: float) -> void:
	motion_name = motion
	leg_running = motion=="run"
	combat_kind = ""
	combat_phase = 0.0
	pose = {"hip_y":394.0,"lean":0.0,"cape":0.0,"head_tilt":0.0,"arms":[-12.0,-4.0,30.0,18.0],"legs":[0.0,0.0,0.0,0.0]}
	feet_planted = true
	_sword_angle = -70.0
	_blade_length = 88.0
	if motion in ["run","dash"]:
		run_phase = fposmod(sample/6.0,1.0)
		pose.hip_y = 404.0+0.7*sin(run_phase*TAU*2.0)
		pose.lean = 8.0+sin(run_phase*TAU*2.0)*0.5
		pose.cape = 17.0+sin(run_phase*TAU-0.6)*3.0
		var near := compact_run_arm(run_phase)
		var far := compact_run_arm(fposmod(run_phase+0.5,1.0))
		pose.arms = [near[0],near[1],far[0],far[1]]
		if motion=="dash":
			feet_planted = false
			pose.hip_y = 398.0
			pose.lean = 21.0
			pose.cape = 35.0
			pose.head_tilt = -2.0
			pose.arms = [36.0,18.0,58.0,36.0]
			pose.legs = [42.0,74.0,52.0,92.0]
	elif motion=="air":
		feet_planted = false
		var t := clampf(sample/7.0,0,1)
		pose.hip_y = 397.0
		pose.lean = 5.0+sin(t*PI)*4.0
		pose.cape = 12.0+sin(t*PI)*12.0
		pose.head_tilt = lerpf(-2,1,t)
		pose.arms = [lerpf(-26,-10,t),lerpf(-62,-12,t),lerpf(38,28,t),lerpf(26,18,t)]
		pose.legs = [lerpf(-36,-10,t),lerpf(46,8,t),lerpf(42,16,t),lerpf(84,22,t)]
	elif motion in ["land","stop"]:
		var t := smoothstep(0,1,clampf(sample,0,1))
		pose.hip_y = lerpf(405.0,394.0,t)
		pose.lean = lerpf(7.0,0.0,t)
		pose.cape = lerpf(10.0,0.0,t)
		pose.arms = [lerpf(8,-12,t),lerpf(-40,-4,t),lerpf(42,30,t),lerpf(28,18,t)]
	elif motion=="heal":
		pose.hip_y = 397.0+0.45*sin(sample*TAU)
		pose.arms = [-34.0,-118.0,46.0,102.0]
		pose.cape = sin(sample*TAU)*0.7
	else:
		pose.hip_y = 394.0+0.35*(1.0-cos(sample*TAU))
		pose.cape = sin(sample*TAU)*0.8
		pose.head_tilt = sin(sample*TAU)*0.30
	_update_geometry()
	queue_redraw()

func set_expression(kind: String, blend: float = 1.0) -> void:
	expression_name = kind if kind in ["idle","look_up","look_down","alert"] else "idle"
	expression_blend = clampf(blend,0,1)
	if not pose.is_empty():
		_update_geometry()
		queue_redraw()

func set_combat_pose(kind: String, phase: float, airborne: bool = false, movement_sample: float = 0.0, grounded_running: bool = false) -> void:
	# A moving strike preserves the distance-driven support/swing feet while
	# the attack keys independently pose the upper body. Four-argument callers
	# retain their standing or airborne behavior.
	var moving_strike := grounded_running and not airborne and kind.begins_with("slash")
	set_motion("air" if airborne else ("run" if moving_strike else "idle"),3.5 if airborne else (movement_sample if moving_strike else fposmod(movement_sample,1.0)))
	combat_kind = kind
	combat_phase = clampf(phase,0,1)
	motion_name = kind
	_blade_length = 82.0 if kind=="slash_up" else 88.0
	if kind in ["slash","slash_follow","slash_up","slash_down"]:
		var keys: Array = UP_KEYS if kind=="slash_up" else (DOWN_KEYS if kind=="slash_down" else (FOLLOW_KEYS if attack_variant%2==1 or kind=="slash_follow" else SLASH_KEYS))
		var values := _sample(keys,combat_phase)
		pose.arms = values.slice(0,4)
		pose.lean = values[4]
		pose.cape = float(pose.cape)+float(values[5])
		_sword_angle = float(values[6])
	elif kind=="recoil":
		var t := sin(combat_phase*PI)
		pose.lean = -8.0*t
		pose.cape = 8.0*t
		pose.arms = [-12.0+20*t,-4.0-18*t,30.0+12*t,18.0+8*t]
		_sword_angle = -70.0+18.0*t
	elif kind=="death":
		var t := smoothstep(0,1,combat_phase)
		pose.hip_y = lerpf(float(pose.hip_y),423.0,t)
		pose.lean = 17.0*t
		pose.cape = -5.0*t
		pose.arms = [lerpf(-12,18,t),lerpf(-4,15,t),lerpf(30,42,t),lerpf(18,30,t)]
		_sword_angle = lerpf(-70,18,t)
	_update_geometry()
	queue_redraw()

func _sample(keys: Array, phase: float) -> Array:
	for index in range(keys.size()-1):
		var a: Array = keys[index]
		var b: Array = keys[index+1]
		if phase<=float(b[0]):
			var t := smoothstep(0,1,inverse_lerp(float(a[0]),float(b[0]),phase))
			var value: Array = []
			for component in range(1,a.size()): value.append(lerpf(float(a[component]),float(b[component]),t))
			return value
	return keys.back().slice(1)

func compact_run_arm(phase: float) -> Array:
	var upper := 10.0+32.0*sin(phase*TAU)
	return [upper,upper-57.0-7.0*sin(phase*TAU+PI/3)]

func limb(origin: Vector2, angle: float, length: float) -> Vector2:
	return origin+Vector2.DOWN.rotated(deg_to_rad(angle))*length

func solve_ankle(origin: Vector2, ankle: Vector2, bend: float = -1.0) -> Array:
	var distance := clampf(origin.distance_to(ankle),8.001,55.95)
	var base := (ankle-origin).angle()-PI/2
	var offset := acos(clampf((THIGH_LENGTH*THIGH_LENGTH+distance*distance-SHIN_LENGTH*SHIN_LENGTH)/(2*THIGH_LENGTH*distance),-1,1))
	var thigh := base+bend*offset
	var knee := origin+Vector2.DOWN.rotated(thigh)*THIGH_LENGTH
	return [rad_to_deg(thigh),rad_to_deg((ankle-knee).angle()-PI/2)]

func leg_ik(origin: Vector2, sole: Vector2, bend: float) -> Array:
	return solve_ankle(origin,sole-Vector2(0,FOOT_LENGTH),bend)

func running_foot(origin: Vector2, phase: float) -> Dictionary:
	var local_speed := RUN_WORLD_SPEED/DRAW_SCALE
	var half_stride := local_speed*RUN_PERIOD*STANCE_FRACTION/2.0
	var contact := phase<STANCE_FRACTION
	var x: float
	var y: float = FEET.y
	var angle: float = 0.0
	if contact:
		x = lerpf(half_stride,-half_stride,phase/STANCE_FRACTION)
	else:
		var u := (phase-STANCE_FRACTION)/(1.0-STANCE_FRACTION)
		var v := 1.0-u
		var control := half_stride+local_speed*RUN_PERIOD*(1.0-STANCE_FRACTION)/6.0
		x = -half_stride*v*v*v-3*control*v*v*u+3*control*v*u*u+half_stride*u*u*u
		y -= 32.0*pow(maxf(0,sin(PI*u)),0.85)
		angle = 14.0*sin(TAU*u)-5.0*sin(PI*u)
	var sole := Vector2(origin.x+x,y)
	return {"sole":sole,"ankle":sole-Vector2.DOWN.rotated(deg_to_rad(angle))*FOOT_LENGTH,"angle":angle,"contact":contact,"phase":phase}

func _update_geometry() -> void:
	joints.clear()
	contacts.clear()
	foot_targets.clear()
	_leg_angles.clear()
	_foot_angles.clear()
	var hip := Vector2(FEET.x,float(pose.hip_y))
	var lean := deg_to_rad(float(pose.lean))
	var shoulder := hip-Vector2.DOWN.rotated(lean)*TORSO_LENGTH
	var across := Vector2.RIGHT.rotated(lean)*20.0
	var head_base := shoulder+Vector2(HEAD_LEAD_PX,-8.0).rotated(lean)
	expression_tilt = float({"idle":0.0,"look_up":-6.0,"look_down":7.0,"alert":-2.5}.get(expression_name,0.0))*expression_blend
	flame_intensity = lerpf(1.0,float({"idle":1.0,"look_up":1.09,"look_down":0.88,"alert":1.24}.get(expression_name,1.0)),expression_blend)
	var head_angle := lean*0.22+deg_to_rad(float(pose.get("head_tilt",0))+expression_tilt)
	lantern_center = head_base+Vector2(1.0268,-42.7833).rotated(head_angle)
	joints.torso = [shoulder,hip]
	joints.shoulders = [shoulder-across,shoulder+across]
	joints.lantern = [head_base,Vector2(90,108)]
	joints.head_axis = [head_base,lantern_center,head_base+Vector2(0,-108).rotated(head_angle)]
	joints.head_hook = [head_base+Vector2(0,HEAD_RECT.position.y).rotated(head_angle)]
	joints.flame = [lantern_center,Vector2(flame_intensity,expression_tilt)]
	for far in [true,false]:
		var key: String = "far" if far else "near"
		var arm_origin: Vector2 = shoulder-across if far else shoulder+across
		var arms: Array = [pose.arms[2],pose.arms[3]] if far else [pose.arms[0],pose.arms[1]]
		var elbow := limb(arm_origin,float(arms[0]),UPPER_ARM_LENGTH)
		var wrist := limb(elbow,float(arms[1]),FOREARM_LENGTH)
		joints[key+"_arm"] = [arm_origin,elbow,wrist]
		joints[key+"_hand"] = limb(elbow,float(arms[1]),FOREARM_LENGTH+7.0)
		var origin := hip+Vector2(-10.0 if far else 10.0,0)
		var angles: Array = [pose.legs[2],pose.legs[3]] if far else [pose.legs[0],pose.legs[1]]
		var foot_angle: float = 0.0
		if leg_running:
			var target := running_foot(origin,fposmod(run_phase+(0.5 if far else 0.0),1.0))
			angles = solve_ankle(origin,target.ankle,-1.0)
			foot_angle = float(target.angle)
			contacts[key] = bool(target.contact)
		elif feet_planted:
			angles = leg_ik(origin,Vector2(origin.x,FEET.y),1.0 if far else -1.0)
			contacts[key] = true
		else:
			foot_angle = clampf(float(angles[1])*0.25,-18,18)
			contacts[key] = false
		var knee := limb(origin,float(angles[0]),THIGH_LENGTH)
		var ankle := limb(knee,float(angles[1]),SHIN_LENGTH)
		var sole := limb(ankle,foot_angle,FOOT_LENGTH)
		joints[key+"_leg"] = [origin,knee,ankle,sole]
		_leg_angles[key] = angles
		_foot_angles[key] = foot_angle
		foot_targets[key] = [sole.x,sole.y,foot_angle,fposmod(run_phase+(0.5 if far else 0.0),1.0)]
	sword_start = joints.near_hand
	sword_end = sword_start+Vector2.RIGHT.rotated(deg_to_rad(_sword_angle))*_blade_length*sword_reach
	sword_bounds = Rect2(sword_start,Vector2.ZERO).expand(sword_end).grow(4)
	_update_fire_arc()

func _bezier(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
	var u := 1.0-t
	return a*u*u*u+b*3.0*u*u*t+c*3.0*u*t*t+d*t*t*t

func _crescent(width: float, height: float, variant: int) -> PackedVector2Array:
	# A broad, filled leaf/banana silhouette. Both ends taper to a point.
	# The inner edge stays hollow; the short nail remains a separate solid part.
	var points := PackedVector2Array()
	var a := Vector2(0,-height*0.5)
	var b := Vector2(width,height*0.03)
	var c := Vector2(width*0.045,height*0.5)
	for index in range(19):
		points.append(_bezier(a,Vector2(width*0.60,-height*0.47),Vector2(width*1.02,-height*0.30),b,index/18.0))
	for index in range(1,19):
		points.append(_bezier(b,Vector2(width*1.01,height*0.30),Vector2(width*0.54,height*0.45),c,index/18.0))
	for index in range(1,15):
		points.append(_bezier(c,Vector2(width*0.26,height*0.28),Vector2(width*0.57,height*0.21),Vector2(width*0.57,0),index/14.0))
	for index in range(1,15):
		points.append(_bezier(Vector2(width*0.57,0),Vector2(width*0.57,-height*0.18),Vector2(width*0.21,-height*0.32),a,index/14.0))
	if variant%2==1:
		for index in range(points.size()): points[index].y = -points[index].y
	return points

func _clip_forward(points: PackedVector2Array, minimum: float) -> PackedVector2Array:
	# Clip the damaging envelope ahead of the body. The decorative tapered tips
	# may trail beside the head, but they never create a hitbox through the hero.
	var output := PackedVector2Array()
	if points.is_empty(): return output
	var previous := points[points.size()-1]
	for current in points:
		if (current.x>=minimum)!=(previous.x>=minimum):
			output.append(previous.lerp(current,(minimum-previous.x)/(current.x-previous.x)))
		if current.x>=minimum: output.append(current)
		previous = current
	return output

func _update_fire_arc() -> void:
	strike_polygon.clear()
	arc_polygon.clear()
	strike_active = false
	_arc_opacity = 0.0
	if not combat_kind.begins_with("slash"): return
	if combat_phase<ARC_START or combat_phase>ARC_END: return
	# Full readable shape spans the contact interval; only its tail fades.
	_arc_opacity = smoothstep(ARC_START,CONTACT_START,combat_phase) if combat_phase<CONTACT_START else (1.0 if combat_phase<=CONTACT_END else 1.0-smoothstep(CONTACT_END,ARC_END,combat_phase))
	_arc_scale = maxf(0.25,sword_reach)
	_arc_angle = -PI/2 if combat_kind=="slash_up" else (PI/2 if combat_kind=="slash_down" else 0.0)
	var shoulder: Vector2 = joints.torso[0]
	_arc_origin = shoulder+Vector2(22,13)
	_arc_width = 340.0
	_arc_height = 225.0
	if combat_kind=="slash_up":
		_arc_origin = shoulder+Vector2(5,2)
		_arc_width = 285.0
		_arc_height = 235.0
	elif combat_kind=="slash_down": _arc_origin = joints.torso[1]+Vector2(2,25)
	var variant := attack_variant if combat_kind in ["slash","slash_follow"] else 0
	var local := _crescent(_arc_width*_arc_scale,_arc_height*_arc_scale,variant)
	for point in local: arc_polygon.append(_arc_origin+point.rotated(_arc_angle))
	strike_active = combat_phase>=CONTACT_START and combat_phase<=CONTACT_END
	if strike_active:
		# AABB collision follows the same filled arc, clipped beyond the solid
		# lantern/body; its bounds never include the head merely due to sweep.
		var minimum := maxf(48.0,float(joints.head_axis[0].x-_arc_origin.x)+HEAD_RECT.end.x+6.0)
		if combat_kind=="slash_up": minimum = maxf(18,_arc_origin.y-float(joints.head_axis[0].y)+114)
		elif combat_kind=="slash_down": minimum = maxf(18,FEET.y-_arc_origin.y+6)
		for point in _clip_forward(local,minimum): strike_polygon.append(_arc_origin+point.rotated(_arc_angle))

func get_strike_rect() -> Rect2:
	if not strike_active or strike_polygon.is_empty(): return Rect2()
	var rectangle := Rect2(strike_polygon[0],Vector2.ZERO)
	for point in strike_polygon: rectangle = rectangle.expand(point)
	return rectangle

func part(key: String, origin: Vector2, rectangle: Rect2, angle: float = 0.0, tint: Color = Color.WHITE) -> void:
	draw_set_transform(origin,angle)
	draw_texture_rect(textures[key],rectangle,false,tint)
	draw_set_transform(Vector2.ZERO)

func _draw_arm(far: bool, section: String = "full") -> void:
	var key := "far" if far else "near"
	var points: Array = joints[key+"_arm"]
	var angles: Array = [pose.arms[2],pose.arms[3]] if far else [pose.arms[0],pose.arms[1]]
	var tint := Color(0.93,0.94,1.0) if far else Color.WHITE
	if section!="lower":
		part("upper_arm",points[0],Rect2(-12.94,-7.19,34.5,32.2),deg_to_rad(float(angles[0])),tint)
	if section!="upper":
		draw_circle(points[1],4.0,Color("171722"))
		part("forearm_hand",points[1],Rect2(-6.39,-2.34,20.42,43.49),deg_to_rad(float(angles[1])),tint)

func _draw_leg(far: bool) -> void:
	var key := "far" if far else "near"
	var points: Array = joints[key+"_leg"]
	var angles: Array = _leg_angles[key]
	var tint := Color(0.74,0.75,0.82) if far else Color.WHITE
	draw_circle(points[1],3.8,Color("14141e"))
	part("thigh",points[0],Rect2(-10.11,-3.19,23.05,36.18),deg_to_rad(float(angles[0])),tint)
	part("shin",points[1],Rect2(-6.69,-2.11,14.61,27.10),deg_to_rad(float(angles[1])),tint)
	part("foot",points[3],Rect2(-5.16,-16.32,24.98,16.32),deg_to_rad(float(_foot_angles[key])),tint)

func _draw() -> void:
	if textures.is_empty() or pose.is_empty(): return
	var shoulder: Vector2 = joints.torso[0]
	var head_base: Vector2 = joints.head_axis[0]
	var lean := deg_to_rad(float(pose.lean))
	if motion_name=="dash": _draw_dash_wake()
	_draw_arm(true,"upper")
	part("cape",shoulder,Rect2(-81.98,-12.31,105.29,110),deg_to_rad(float(pose.cape)))
	_draw_leg(true)
	_draw_leg(false)
	part("torso",shoulder,Rect2(-22.40,-3.32,49.50,86),lean)
	# The far ivory palm is explicitly in front of the cloak/body at the edge.
	_draw_arm(true,"lower")
	_draw_arm(false)
	# Rigid head atlas and collar overlap never change their dimensions by pose.
	part("scarf",shoulder+Vector2(5,0).rotated(lean),Rect2(-62.53,-13.24,90,42.67),lean*0.30)
	part("head",head_base,HEAD_RECT,lean*0.22+deg_to_rad(float(pose.get("head_tilt",0))+expression_tilt))
	# Expression changes the light/core without rescaling the cage or adding eyes.
	if flame_intensity>1.0:
		draw_circle(lantern_center+Vector2(0,12),10.0,Color(1,0.77,0.38,(flame_intensity-1.0)*0.18))
	if sword_visible: _draw_sword()

func _draw_sword() -> void:
	var angle := deg_to_rad(_sword_angle)
	var length := _blade_length*sword_reach
	draw_set_transform(sword_start,angle)
	draw_line(Vector2(-15,0),Vector2(2,0),Color("161620"),8,true)
	draw_line(Vector2(-14,0),Vector2(1,0),Color("ad7d43"),4.5,true)
	draw_line(Vector2(0,-8),Vector2(0,8),Color("d7ad6f"),4,true)
	var blade := PackedVector2Array([Vector2(3,-3.6),Vector2(length-15,-2.6),Vector2(length,0),Vector2(length-15,2.6),Vector2(3,3.6)])
	draw_colored_polygon(blade,Color("f9e6c1"))
	var outline := blade.duplicate()
	outline.append(blade[0])
	draw_polyline(outline,Color("493522"),1.8,true)
	draw_line(Vector2(5,0),Vector2(length-4,0),Color("ffd18e"),1.0,true)
	draw_set_transform(Vector2.ZERO)
	if not arc_polygon.is_empty():
		var edge := arc_polygon.duplicate()
		edge.append(arc_polygon[0])
		# Two restrained AA fringes soften the flash without obscuring enemies.
		draw_polyline(edge,Color(1.0,0.63,0.25,0.055*_arc_opacity),15.0,true)
		draw_polyline(edge,Color(1.0,0.71,0.35,0.10*_arc_opacity),7.0,true)
		draw_colored_polygon(arc_polygon,Color(1.0,0.64,0.27,0.82*_arc_opacity))
		var inner := PackedVector2Array()
		var variant := attack_variant if combat_kind in ["slash","slash_follow"] else 0
		for point in _crescent(_arc_width*_arc_scale*0.987,_arc_height*_arc_scale*0.955,variant):
			inner.append(_arc_origin+(point+Vector2(1.5,0)).rotated(_arc_angle))
		draw_colored_polygon(inner,Color(1.0,0.956,0.81,_arc_opacity))
		draw_polyline(edge,Color(1.0,0.79,0.46,0.26*_arc_opacity),1.4,true)

func _draw_dash_wake() -> void:
	var shoulder: Vector2 = joints.torso[0]
	# Warm tapered speed wisps are effects, never duplicate character sprites.
	for index in range(3):
		var y := 20.0+index*18.0
		var tail := 115.0+index*21.0
		var points := PackedVector2Array([shoulder+Vector2(-tail,y+3),shoulder+Vector2(-35,y-4),shoulder+Vector2(-13,y),shoulder+Vector2(-35,y+4)])
		draw_colored_polygon(points,Color(1.0,0.76,0.42,0.18-index*0.035))
