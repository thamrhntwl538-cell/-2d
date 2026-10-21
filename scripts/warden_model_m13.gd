extends "res://scripts/warden_model_m12.gd"
## M13 corrects the head attachment, arm arc and running foot contact.
## The approved atlas, palette, part sizes and rigid segment lengths are reused.
const HEAD_LEAD_PX: float = 16.0
const RUN_PERIOD: float = 6.0 / 13.0
const RUN_WORLD_SPEED: float = 300.0
const ART_SCALE: float = 0.40
const STANCE_FRACTION: float = 0.22
const RUN_HIP_Y: float = 359.0
const SWING_LIFT: float = 64.0
const AIR_ARMS = [
	[18.0, -18.0, 12.0, -20.0],
	[28.0, -42.0, 20.0, -40.0],
	[36.0, -58.0, 28.0, -51.0],
	[32.0, -54.0, 26.0, -49.0],
	[26.0, -43.0, 20.0, -38.0],
	[18.0, -30.0, 12.0, -26.0],
	[10.0, -16.0, 4.0, -12.0],
	[12.0, -14.0, 6.0, -12.0]
]
var motion_name: String = "idle"
var run_phase: float = 0.0
var contacts: Dictionary = {}
var foot_targets: Dictionary = {}

func set_motion(motion: String, sample: float) -> void:
	super.set_motion(motion, sample)
	motion_name = motion
	contacts.clear()
	foot_targets.clear()
	var idle_arms: Array = [14.0, -11.0, 8.0, -5.0]
	if motion in ["run", "dash"]:
		run_phase = fposmod(sample / 6.0, 1.0)
		pose.hip_y = RUN_HIP_Y + 1.2 * sin(run_phase * TAU * 2.0)
		var near: Array = compact_run_arm(run_phase)
		var far: Array = compact_run_arm(fposmod(run_phase + 0.5, 1.0))
		pose.arms = [near[0], near[1], far[0], far[1]]
	elif motion == "air":
		var p: float = clampf(sample, 0.0, 7.0)
		var a: Array = AIR_ARMS[int(p)]
		var b: Array = AIR_ARMS[mini(int(p) + 1, 7)]
		var t: float = smoothstep(0.0, 1.0, p - floorf(p))
		pose.arms = []
		for i in range(4):
			pose.arms.append(lerpf(a[i], b[i], t))
	elif motion in ["stop", "land"]:
		var t: float = smoothstep(0.0, 1.0, clampf(sample, 0.0, 1.0))
		if motion == "stop":
			pose.hip_y = lerpf(RUN_HIP_Y, 350.0, t)
			var left: Array = leg_ik(Vector2(242, pose.hip_y), Vector2(242, 456), -1.0)
			var right: Array = leg_ik(Vector2(270, pose.hip_y), Vector2(270, 456), 1.0)
			pose.legs = [left[0], left[1], right[0], right[1]]
		var start: Array = [36.0, -56.0, 36.0, -56.0] if motion == "stop" else AIR_ARMS[7]
		pose.arms = []
		for i in range(4):
			pose.arms.append(lerpf(start[i], idle_arms[i], t))
	else:
		pose.arms = idle_arms
	queue_redraw()

func compact_run_arm(phase: float) -> Array:
	var upper: float = 36.0 + 10.0 * sin(phase * TAU)
	var elbow_flex: float = 92.0 + 7.0 * sin(phase * TAU + PI / 3.0)
	return [upper, upper - elbow_flex]

func running_foot(origin: Vector2, phase: float) -> Dictionary:
	var local_speed: float = RUN_WORLD_SPEED / ART_SCALE
	var half_stride: float = local_speed * RUN_PERIOD * STANCE_FRACTION / 2.0
	var x: float
	var y: float
	var angle: float
	var contact: bool = phase < STANCE_FRACTION
	if contact:
		# Local backward motion cancels the player's forward speed during support.
		x = lerpf(half_stride, -half_stride, phase / STANCE_FRACTION)
		y = 456.0
		angle = 0.0
	else:
		var u: float = (phase - STANCE_FRACTION) / (1.0 - STANCE_FRACTION)
		var v: float = 1.0 - u
		# Endpoint tangents match support velocity at toe-off and the next strike.
		var control: float = half_stride + local_speed * RUN_PERIOD * (1.0 - STANCE_FRACTION) / 3.0
		x = -half_stride * v * v * v - 3.0 * control * v * v * u + 3.0 * control * v * u * u + half_stride * u * u * u
		y = 456.0 - SWING_LIFT * pow(maxf(0.0, sin(PI * u)), 1.15)
		angle = 18.0 * sin(TAU * u) - 8.0 * sin(PI * u)
	var sole := Vector2(origin.x + x, y)
	var ankle: Vector2 = sole - Vector2.DOWN.rotated(deg_to_rad(angle)) * 12.0
	return {"sole": sole, "ankle": ankle, "angle": angle, "contact": contact, "phase": phase}

func solve_ankle(origin: Vector2, ankle: Vector2) -> Array:
	var d: float = clampf(origin.distance_to(ankle), 14.001, 94.0)
	var base: float = (ankle - origin).angle() - PI / 2.0
	var a: float = acos(clampf((54.0 * 54.0 + d * d - 40.0 * 40.0) / (2.0 * 54.0 * d), -1.0, 1.0))
	var thigh: float = base - a
	var knee: Vector2 = origin + Vector2.DOWN.rotated(thigh) * 54.0
	return [rad_to_deg(thigh), rad_to_deg((ankle - knee).angle() - PI / 2.0)]

func leg(origin: Vector2, angles: Array, far: bool) -> void:
	var key: String = "far" if far else "near"
	var foot_angle: float = 0.0 if feet_planted else clampf(float(angles[1]) * 0.3, -20.0, 30.0)
	var target: Dictionary = {}
	if motion_name in ["run", "dash"]:
		var phase: float = fposmod(run_phase + (0.5 if far else 0.0), 1.0)
		target = running_foot(origin, phase)
		angles = solve_ankle(origin, target.ankle)
		foot_angle = target.angle
		contacts[key] = target.contact
		foot_targets[key] = [target.sole.x, target.sole.y, target.angle, target.phase]
	else:
		contacts[key] = feet_planted
	var tint := Color(0.79, 0.81, 0.85) if far else Color.WHITE
	var knee: Vector2 = limb(origin, angles[0], 54.0)
	var ankle: Vector2 = limb(knee, angles[1], 40.0)
	var sole: Vector2 = limb(ankle, foot_angle, 12.0)
	draw_circle(knee, 7.0, Color("29272b"))
	part("thigh", origin, Rect2(-13, -3, 26, 60), deg_to_rad(angles[0]), tint)
	part("shin", knee, Rect2(-12, -3, 26, 46), deg_to_rad(angles[1]), tint)
	part("foot", sole, Rect2(-9, -20, 35, 20), deg_to_rad(foot_angle), tint)
	joints["far_leg" if far else "near_leg"] = [origin, knee, ankle, sole]

func _draw() -> void:
	if textures.is_empty() or pose.is_empty():
		return
	joints.clear()
	contacts.clear()
	foot_targets.clear()
	var hip := Vector2(256.0, float(pose.hip_y))
	var lean: float = deg_to_rad(float(pose.lean))
	var shoulder: Vector2 = hip - Vector2.DOWN.rotated(lean) * 94.0
	var across: Vector2 = Vector2.RIGHT.rotated(lean) * 44.0
	var head_base: Vector2 = shoulder + Vector2(HEAD_LEAD_PX, 0.0).rotated(lean)
	var head_angle: float = lean * 0.32
	joints.torso = [shoulder, hip]
	joints.shoulders = [shoulder - across, shoulder + across]
	joints.lantern = [head_base, Vector2(64, 86)]
	joints.head_axis = [head_base, head_base + Vector2(0, -42).rotated(head_angle), head_base + Vector2(0, -86).rotated(head_angle)]
	# The far arm belongs behind the cape instead of floating over its lining.
	arm(shoulder - across, [pose.arms[2], pose.arms[3]], true)
	part("cape", shoulder + Vector2(-20, 3).rotated(lean), Rect2(-128, -4, 140, 177), deg_to_rad(float(pose.cape)))
	leg(hip + Vector2(-14, 0), [pose.legs[2], pose.legs[3]], true)
	leg(hip + Vector2(14, 0), [pose.legs[0], pose.legs[1]], false)
	part("flap", hip + Vector2(-14, -4), Rect2(-14, 0, 39, 77), deg_to_rad(float(pose.cape) * 0.6))
	draw_set_transform(shoulder + Vector2(6, 0).rotated(lean), lean)
	draw_style_box(neck_style(), Rect2(-14, -14, 36, 36))
	draw_set_transform(Vector2.ZERO)
	part("torso", shoulder, Rect2(-48, -12, 96, 150), lean)
	arm(shoulder + across, [pose.arms[0], pose.arms[1]], false)
	part("belt_lantern", hip + Vector2(-32, -3), Rect2(-7.5, 0, 15, 33), deg_to_rad(-float(pose.cape) * 0.5))
	part("head", head_base, Rect2(-32, -86, 64, 86), head_angle)
