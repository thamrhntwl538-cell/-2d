extends Node2D
## One shared M19 cutout rig. Every motion uses the same reference-derived parts.
## Source canvas: 512 square; feet (256,456). Parent draws at 0.37 world scale.
const ATLAS_PATH := "res://assets/warden_m19/warden_parts.png"
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
const HEAD_RECT := Rect2(-86.7,-150.62,133.96,154.02)
const REGIONS := {
	"head":Rect2(22,0,394,453),"torso":Rect2(489,133,167,311),
	"cape":Rect2(690,80,388,412),"scarf":Rect2(50,492,355,172),
	"upper_arm":Rect2(566,515,111,111),"forearm_hand":Rect2(892,510,126,274),
	"thigh":Rect2(148,798,121,201),"shin":Rect2(525,800,76,154),
	"foot":Rect2(849,870,134,96)
}
const SLASH_KEYS := [
	[0.0,12.0,-4.0,10.0,-10.0,0.0,0.0,-70.0],
	[0.22,-62.0,-135.0,22.0,-24.0,-3.0,5.0,-115.0],
	[0.48,-12.0,-72.0,20.0,-24.0,4.0,-4.0,0.0],
	[0.72,24.0,-28.0,16.0,-16.0,2.0,-2.0,36.0],
	[1.0,12.0,-4.0,10.0,-10.0,0.0,0.0,-70.0]
]
const UP_KEYS := [
	[0.0,12.0,-4.0,10.0,-10.0,0.0,0.0,-70.0],
	[0.22,-18.0,-45.0,20.0,-24.0,2.0,-3.0,-8.0],
	[0.48,-128.0,-165.0,30.0,-36.0,-2.0,5.0,-98.0],
	[0.72,-142.0,-170.0,24.0,-28.0,-3.0,4.0,-135.0],
	[1.0,12.0,-4.0,10.0,-10.0,0.0,0.0,-70.0]
]
const DOWN_KEYS := [
	[0.0,12.0,-4.0,10.0,-10.0,0.0,0.0,-70.0],
	[0.22,-105.0,-145.0,26.0,-32.0,-3.0,6.0,-90.0],
	[0.48,8.0,18.0,32.0,-40.0,4.0,-4.0,90.0],
	[0.72,16.0,12.0,28.0,-32.0,4.0,-4.0,96.0],
	[1.0,12.0,-4.0,10.0,-10.0,0.0,0.0,-70.0]
]

var textures: Dictionary = {}
var pose: Dictionary = {}
var joints: Dictionary = {}
var contacts: Dictionary = {}
var foot_targets: Dictionary = {}
var motion_name: String = "idle"
var run_phase: float = 0.0
var feet_planted: bool = true
var sword_visible: bool = false
var sword_reach: float = 1.0
var sword_start := Vector2.ZERO
var sword_end := Vector2.ZERO
var sword_bounds := Rect2()
var lantern_center := Vector2.ZERO
var combat_kind: String = ""
var combat_phase: float = 0.0
var _sword_angle: float = -70.0
var _blade_length: float = 170.0
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
	combat_kind = ""
	combat_phase = 0.0
	pose = {"hip_y":394.0,"lean":0.0,"cape":0.0,"head_tilt":0.0,"arms":[12.0,-4.0,10.0,-10.0],"legs":[0.0,0.0,0.0,0.0]}
	feet_planted = true
	_sword_angle = -70.0
	_blade_length = 170.0
	if motion in ["run","dash"]:
		run_phase = fposmod(sample/6.0,1.0)
		pose.hip_y = 404.0+0.7*sin(run_phase*TAU*2.0)
		pose.lean = 6.0+sin(run_phase*TAU*2.0)*0.7
		pose.cape = 12.0+sin(run_phase*TAU-0.6)*3.0
		var near := compact_run_arm(run_phase)
		var far := compact_run_arm(fposmod(run_phase+0.5,1.0))
		pose.arms = [near[0],near[1],far[0],far[1]]
		if motion=="dash":
			pose.lean = 17.0
			pose.cape = 22.0
			pose.arms = [38.0,-66.0,30.0,-58.0]
	elif motion=="air":
		feet_planted = false
		var t := clampf(sample/7.0,0,1)
		pose.hip_y = 397.0
		pose.lean = 4.0+sin(t*PI)*4.0
		pose.cape = 4.0+sin(t*PI*1.6)*9.0
		pose.arms = [lerpf(24,8,t),lerpf(-58,-16,t),lerpf(20,5,t),lerpf(-52,-14,t)]
		pose.legs = [lerpf(-42,-10,t),lerpf(46,10,t),lerpf(35,12,t),lerpf(72,20,t)]
	elif motion in ["land","stop"]:
		var t := smoothstep(0,1,clampf(sample,0,1))
		pose.hip_y = lerpf(405.0,394.0,t)
		pose.lean = lerpf(7.0,0.0,t)
		pose.cape = lerpf(10.0,0.0,t)
		pose.arms = [lerpf(28,12,t),lerpf(-40,-4,t),lerpf(24,10,t),lerpf(-34,-10,t)]
	elif motion=="heal":
		pose.hip_y = 397.0+0.45*sin(sample*TAU)
		pose.arms = [-28.0,-110.0,-20.0,-98.0]
		pose.cape = sin(sample*TAU)*0.7
	else:
		pose.hip_y = 394.0+0.35*(1.0-cos(sample*TAU))
		pose.cape = sin(sample*TAU)*0.8
		pose.head_tilt = sin(sample*TAU)*0.30
	_update_geometry()
	queue_redraw()

func set_combat_pose(kind: String, phase: float, airborne: bool = false, movement_sample: float = 0.0) -> void:
	set_motion("air" if airborne else "idle",3.5 if airborne else fposmod(movement_sample,1.0))
	combat_kind = kind
	combat_phase = clampf(phase,0,1)
	motion_name = kind
	_blade_length = 160.0 if kind=="slash_up" else 170.0
	if kind in ["slash","slash_follow","slash_up","slash_down"]:
		var keys: Array = UP_KEYS if kind=="slash_up" else (DOWN_KEYS if kind=="slash_down" else SLASH_KEYS)
		var values := _sample(keys,combat_phase)
		pose.arms = values.slice(0,4)
		pose.lean = values[4]
		pose.cape = float(pose.cape)+float(values[5])
		_sword_angle = float(values[6])
	elif kind=="recoil":
		var t := sin(combat_phase*PI)
		pose.lean = -8.0*t
		pose.cape = 8.0*t
		pose.arms = [12.0+20*t,-4.0-18*t,10.0-16*t,-10.0]
		_sword_angle = -70.0+18.0*t
	elif kind=="death":
		var t := smoothstep(0,1,combat_phase)
		pose.hip_y = lerpf(float(pose.hip_y),423.0,t)
		pose.lean = 17.0*t
		pose.cape = -5.0*t
		pose.arms = [lerpf(12,30,t),lerpf(-4,15,t),10.0,-10.0]
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
	var upper := 24.0+11.0*sin(phase*TAU)
	return [upper,upper-69.0-5.0*sin(phase*TAU+PI/3)]

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
	var head_angle := lean*0.22+deg_to_rad(float(pose.get("head_tilt",0)))
	lantern_center = head_base+Vector2(-1.36,-44.2).rotated(head_angle)
	joints.torso = [shoulder,hip]
	joints.shoulders = [shoulder-across,shoulder+across]
	joints.lantern = [head_base,Vector2(90,108)]
	joints.head_axis = [head_base,lantern_center,head_base+Vector2(0,-108).rotated(head_angle)]
	joints.head_hook = [head_base+Vector2(0,-150.62).rotated(head_angle)]
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
		if motion_name in ["run","dash"]:
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

func part(key: String, origin: Vector2, rectangle: Rect2, angle: float = 0.0, tint: Color = Color.WHITE) -> void:
	draw_set_transform(origin,angle)
	draw_texture_rect(textures[key],rectangle,false,tint)
	draw_set_transform(Vector2.ZERO)

func _draw_arm(far: bool, section: String = "full") -> void:
	var key := "far" if far else "near"
	var points: Array = joints[key+"_arm"]
	var angles: Array = [pose.arms[2],pose.arms[3]] if far else [pose.arms[0],pose.arms[1]]
	var tint := Color(0.78,0.79,0.85) if far else Color.WHITE
	if section!="lower":
		part("upper_arm",points[0],Rect2(-12.18,-6.96,32.19,32.19),deg_to_rad(float(angles[0])),tint)
	if section!="upper":
		draw_circle(points[1],4.0,Color("171722"))
		part("forearm_hand",points[1],Rect2(-6.20,-2.40,20,43.49),deg_to_rad(float(angles[1])),tint)

func _draw_leg(far: bool) -> void:
	var key := "far" if far else "near"
	var points: Array = joints[key+"_leg"]
	var angles: Array = _leg_angles[key]
	var tint := Color(0.74,0.75,0.82) if far else Color.WHITE
	draw_circle(points[1],3.8,Color("14141e"))
	part("thigh",points[0],Rect2(-9.54,-3.24,21.78,36.18),deg_to_rad(float(angles[0])),tint)
	part("shin",points[1],Rect2(-6.16,-2.11,13.38,27.10),deg_to_rad(float(angles[1])),tint)
	part("foot",points[3],Rect2(-4.76,-16.32,22.78,16.32),deg_to_rad(float(_foot_angles[key])),tint)

func _draw() -> void:
	if textures.is_empty() or pose.is_empty(): return
	var shoulder: Vector2 = joints.torso[0]
	var head_base: Vector2 = joints.head_axis[0]
	var lean := deg_to_rad(float(pose.lean))
	_draw_arm(true,"upper")
	part("cape",shoulder,Rect2(-75,-4,104,110),deg_to_rad(float(pose.cape)))
	# Let the far ivory glove peek out while its shoulder stays behind the cloak.
	_draw_arm(true,"lower")
	_draw_leg(true)
	_draw_leg(false)
	part("torso",shoulder,Rect2(-23,-3,46,86),lean)
	_draw_arm(false)
	# Rigid head atlas and collar overlap never change their dimensions by pose.
	part("scarf",shoulder+Vector2(5,0).rotated(lean),Rect2(-62.62,-13.18,90,43.61),lean*0.30)
	part("head",head_base,HEAD_RECT,lean*0.22+deg_to_rad(float(pose.get("head_tilt",0))))
	if sword_visible: _draw_sword()

func _draw_sword() -> void:
	var angle := deg_to_rad(_sword_angle)
	var length := _blade_length*sword_reach
	if combat_kind.begins_with("slash") and combat_phase>0.3 and combat_phase<0.7:
		var opacity := sin(inverse_lerp(0.3,0.7,combat_phase)*PI)
		var sign_value := -1.0 if combat_kind=="slash_up" else 1.0
		var points := PackedVector2Array()
		for i in range(15): points.append(sword_start+Vector2.RIGHT.rotated(angle-sign_value*lerpf(0.64,0,float(i)/14))*length*0.86)
		draw_polyline(points,Color(1.0,0.64,0.31,0.29*opacity),7,true)
		draw_polyline(points,Color(1.0,0.89,0.68,0.70*opacity),2.2,true)
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
