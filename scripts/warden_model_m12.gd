extends Node2D
## One authored cutout model. Pose changes rotate joints; limb lengths never change.
## All measurements are source pixels, before the shared gameplay scale of 0.40.
const ATLAS_PATH = "res://art_source/m12/warden_parts.png"
const REGIONS = {
	"head": Rect2(118, 86, 215, 333),
	"torso": Rect2(486, 54, 286, 414),
	"cape": Rect2(829, 45, 393, 438),
	"upper_arm": Rect2(178, 508, 139, 312),
	"forearm": Rect2(575, 510, 133, 314),
	"thigh": Rect2(950, 509, 194, 319),
	"boot": Rect2(157, 858, 214, 324),
	"shin": Rect2(157, 858, 138, 247),
	"foot": Rect2(177, 1071, 194, 112),
	"flap": Rect2(511, 845, 274, 381),
	"belt_lantern": Rect2(1004, 921, 110, 245)
}
const RUN = [
	{"legs": [-22.0, -16.0, 48.0, 100.0], "arms": [30.0, -114.0, -36.0, -90.0], "lean": 9.0, "cape": 17.0},
	{"legs": [-48.0, 44.0, 30.0, 103.0], "arms": [39.0, -120.0, -20.0, -104.0], "lean": 10.0, "cape": 11.0},
	{"legs": [-57.0, 100.0, 4.0, 47.0], "arms": [30.0, -111.0, 8.0, -118.0], "lean": 8.0, "cape": 14.0},
	{"legs": [48.0, 100.0, -22.0, -16.0], "arms": [-36.0, 68.0, 30.0, -114.0], "lean": 9.0, "cape": 17.0},
	{"legs": [30.0, 103.0, -48.0, 44.0], "arms": [-20.0, 52.0, 39.0, -120.0], "lean": 10.0, "cape": 11.0},
	{"legs": [4.0, 47.0, -57.0, 100.0], "arms": [8.0, 20.0, 30.0, -111.0], "lean": 8.0, "cape": 14.0}
]
const AIR = [
	{"hip_y": 365.0, "lean": 6.0, "legs": [-28.0, 28.0, 32.0, -29.0], "arms": [8.0, -30.0, -8.0, -15.0], "cape": 2.0},
	{"hip_y": 350.0, "lean": 9.0, "legs": [-19.0, 4.0, 36.0, 73.0], "arms": [18.0, -87.0, -22.0, -95.0], "cape": 10.0},
	{"hip_y": 344.0, "lean": 9.0, "legs": [-51.0, 67.0, 10.0, 93.0], "arms": [26.0, -110.0, -15.0, -108.0], "cape": 6.0},
	{"hip_y": 343.0, "lean": 7.0, "legs": [-64.0, 96.0, -14.0, 106.0], "arms": [30.0, -118.0, -11.0, -111.0], "cape": -5.0},
	{"hip_y": 345.0, "lean": 5.0, "legs": [-43.0, 76.0, 5.0, 74.0], "arms": [25.0, -110.0, -16.0, -98.0], "cape": -10.0},
	{"hip_y": 348.0, "lean": 3.0, "legs": [-21.0, 31.0, 15.0, 45.0], "arms": [14.0, -83.0, -24.0, -74.0], "cape": -13.0},
	{"hip_y": 350.0, "lean": 2.0, "legs": [-7.0, 6.0, 7.0, -6.0], "arms": [5.0, -40.0, -12.0, -30.0], "cape": -8.0},
	{"hip_y": 369.0, "lean": 11.0, "legs": [-36.0, 32.0, 36.0, -32.0], "arms": [2.0, -41.0, -9.0, -34.0], "cape": 1.0}
]
var textures: Dictionary = {}
var pose: Dictionary = {}
var joints: Dictionary = {}
var feet_planted: bool = false

func _ready() -> void:
	var atlas: Texture2D = load(ATLAS_PATH)
	for key in REGIONS:
		var tex := AtlasTexture.new()
		tex.atlas = atlas
		tex.region = REGIONS[key]
		tex.filter_clip = true
		textures[key] = tex
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_motion("idle", 0.0)

func mix_pose(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var result: Dictionary = {}
	for key in a:
		if a[key] is Array:
			var values: Array = []
			for i in range(a[key].size()):
				values.append(lerpf(float(a[key][i]), float(b[key][i]), t))
			result[key] = values
		else:
			result[key] = lerpf(float(a[key]), float(b[key]), t)
	return result

func set_motion(motion: String, sample: float) -> void:
	pose = {"hip_y": 350.0, "lean": 0.0, "legs": [0.0, 0.0, 0.0, 0.0], "arms": [2.0, -5.0, -3.0, 4.0], "cape": 0.0}
	if motion == "run" or motion == "dash":
		var p: float = fposmod(sample, 6.0)
		pose.merge(mix_pose(RUN[int(p)], RUN[(int(p) + 1) % 6], p - floorf(p)), true)
		pose.hip_y = 354.0 + sin(p * TAU / 3.0) * 1.5
		if motion == "dash":
			pose.lean += 12.0
			pose.cape += 10.0
	elif motion == "air":
		var p: float = clampf(sample, 0.0, 7.0)
		pose.merge(mix_pose(AIR[int(p)], AIR[mini(int(p) + 1, 7)], p - floorf(p)), true)
	elif motion == "land":
		pose.merge(mix_pose(AIR[7], pose.duplicate(true), clampf(sample, 0.0, 1.0)), true)
	elif motion == "stop":
		var t: float = clampf(sample, 0.0, 1.0)
		pose.lean = lerpf(5.0, 0.0, t)
		pose.cape = lerpf(12.0, 0.0, t)
		pose.arms = [lerpf(20.0, 2.0, t), lerpf(-80.0, -5.0, t), -3.0, 4.0]
	else:
		pose.hip_y = 350.0 + 0.7 * (1.0 - cos(sample * TAU))
		pose.cape = sin(sample * TAU) * 0.7
	# Planted soles use two-bone IK; breathing/crouch never stretch a leg.
	feet_planted = motion in ["idle", "stop", "land"] or (motion == "air" and (sample < 0.01 or sample > 6.99))
	if feet_planted:
		var left: Array = leg_ik(Vector2(242.0, float(pose.hip_y)), Vector2(242.0, 456.0), -1.0)
		var right: Array = leg_ik(Vector2(270.0, float(pose.hip_y)), Vector2(270.0, 456.0), 1.0)
		pose.legs = [left[0], left[1], right[0], right[1]]
	queue_redraw()

func leg_ik(hip: Vector2, sole: Vector2, bend: float) -> Array:
	var ankle: Vector2 = sole - Vector2(0, 12)
	var d: float = clampf(hip.distance_to(ankle), 14.001, 94.0)
	var base: float = (ankle - hip).angle() - PI / 2.0
	var a: float = acos(clampf((54.0 * 54.0 + d * d - 40.0 * 40.0) / (2.0 * 54.0 * d), -1.0, 1.0))
	var thigh_angle: float = base + bend * a
	var knee: Vector2 = hip + Vector2.DOWN.rotated(thigh_angle) * 54.0
	var shin_angle: float = (ankle - knee).angle() - PI / 2.0
	return [rad_to_deg(thigh_angle), rad_to_deg(shin_angle)]

func part(key: String, origin: Vector2, rect: Rect2, angle: float = 0.0, tint: Color = Color.WHITE) -> void:
	draw_set_transform(origin, angle)
	draw_texture_rect(textures[key], rect, false, tint)
	draw_set_transform(Vector2.ZERO)

func limb(origin: Vector2, degrees: float, length: float) -> Vector2:
	return origin + Vector2.DOWN.rotated(deg_to_rad(degrees)) * length

func arm(origin: Vector2, angles: Array, far: bool) -> void:
	var tint := Color(0.78, 0.80, 0.84) if far else Color.WHITE
	var elbow: Vector2 = limb(origin, angles[0], 44.0)
	draw_circle(elbow, 7.0, Color("29272b"))
	part("upper_arm", origin, Rect2(-10, -3, 20, 50), deg_to_rad(angles[0]), tint)
	part("forearm", elbow, Rect2(-9, -4, 20, 54), deg_to_rad(angles[1]), tint)
	joints["far_arm" if far else "near_arm"] = [origin, elbow, limb(elbow, angles[1], 42.0)]

func leg(origin: Vector2, angles: Array, far: bool) -> void:
	var tint := Color(0.79, 0.81, 0.85) if far else Color.WHITE
	var knee: Vector2 = limb(origin, angles[0], 54.0)
	draw_circle(knee, 7.0, Color("29272b"))
	part("thigh", origin, Rect2(-13, -3, 26, 60), deg_to_rad(angles[0]), tint)
	var ankle: Vector2 = limb(knee, angles[1], 40.0)
	var foot_angle: float = 0.0 if feet_planted else float(angles[1]) * 0.6
	var sole: Vector2 = limb(ankle, foot_angle, 12.0)
	# Dedicated ankle joint keeps the sole horizontal at ground contact.
	# Shin/boot art overlaps above the ankle; all three rigid lengths sum to 106.
	part("shin", knee, Rect2(-12, -3, 26, 46), deg_to_rad(angles[1]), tint)
	part("foot", sole, Rect2(-9, -20, 35, 20), deg_to_rad(foot_angle), tint)
	joints["far_leg" if far else "near_leg"] = [origin, knee, ankle, sole]

func _draw() -> void:
	if textures.is_empty() or pose.is_empty():
		return
	joints.clear()
	var hip := Vector2(256.0, float(pose.hip_y))
	var lean: float = deg_to_rad(float(pose.lean))
	var shoulder: Vector2 = hip - Vector2.DOWN.rotated(lean) * 94.0
	var across: Vector2 = Vector2.RIGHT.rotated(lean) * 44.0
	joints.torso = [shoulder, hip]
	joints.shoulders = [shoulder - across, shoulder + across]
	joints.lantern = [shoulder, Vector2(64, 86)]
	part("cape", shoulder + Vector2(-20, 3).rotated(lean), Rect2(-128, -4, 140, 177), deg_to_rad(float(pose.cape)))
	arm(shoulder - across, [pose.arms[2], pose.arms[3]], true)
	leg(hip + Vector2(-14, 0), [pose.legs[2], pose.legs[3]], true)
	leg(hip + Vector2(14, 0), [pose.legs[0], pose.legs[1]], false)
	part("flap", hip + Vector2(-14, -4), Rect2(-14, 0, 39, 77), deg_to_rad(float(pose.cape) * 0.6))
	# Continuous scarf underlay and collar overlap close the head/neck join.
	draw_set_transform(shoulder, lean)
	draw_style_box(neck_style(), Rect2(-16, -14, 32, 36))
	draw_set_transform(Vector2.ZERO)
	part("torso", shoulder, Rect2(-48, -12, 96, 150), lean)
	arm(shoulder + across, [pose.arms[0], pose.arms[1]], false)
	part("belt_lantern", hip + Vector2(-32, -3), Rect2(-7.5, 0, 15, 33), deg_to_rad(-float(pose.cape) * 0.5))
	# Identical head texture/size/face in every frame; a small rigid tilt is allowed.
	part("head", shoulder, Rect2(-32, -86, 64, 86), lean * 0.32)

func neck_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("29272b")
	style.border_color = Color("17181d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style
