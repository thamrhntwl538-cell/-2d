extends "res://scripts/warden_model_m13.gd"
## M18 attacks reuse the approved M13 cutout parts and rigid segment lengths.
## This is a native pose overlay, not a second character or a replacement atlas.

var combat_kind: String = "slash"
var combat_phase: float = 0.0
var sword_visible: bool = true
var _sword_angle: float = -65.0
var _blade_length: float = 126.0

# Samples are phase, near upper/forearm, far upper/forearm, lean, cape, sword.
# The active contact lies near phase .5; each direction has its own readable arc.
const FORWARD_KEYS := [
	[0.0, 14.0, -11.0, 8.0, -5.0, 0.0, 0.0, -65.0],
	[0.22, -70.0, -145.0, 18.0, -25.0, -2.0, 3.0, -115.0],
	[0.48, -12.0, -65.0, 20.0, -20.0, 4.0, -4.0, 4.0],
	[0.70, 22.0, -35.0, 14.0, -15.0, 2.0, -2.0, 44.0],
	[1.0, 14.0, -11.0, 8.0, -5.0, 0.0, 0.0, -65.0]
]
const UP_KEYS := [
	[0.0, 14.0, -11.0, 8.0, -5.0, 0.0, 0.0, 18.0],
	[0.22, -20.0, -40.0, 18.0, -18.0, 2.0, -2.0, -5.0],
	[0.48, -125.0, -165.0, 25.0, -30.0, -2.0, 3.0, -105.0],
	[0.70, -145.0, -175.0, 18.0, -20.0, -3.0, 3.0, -145.0],
	[1.0, 14.0, -11.0, 8.0, -5.0, 0.0, 0.0, -65.0]
]
const DOWN_KEYS := [
	[0.0, 14.0, -11.0, 8.0, -5.0, 0.0, 0.0, -65.0],
	[0.22, -105.0, -155.0, 28.0, -35.0, -3.0, 4.0, -85.0],
	[0.48, 8.0, 20.0, 34.0, -40.0, 3.0, -3.0, 90.0],
	[0.70, 14.0, 16.0, 26.0, -30.0, 4.0, -4.0, 96.0],
	[1.0, 14.0, -11.0, 8.0, -5.0, 0.0, 0.0, -65.0]
]

func set_combat_pose(kind: String, phase: float, airborne: bool = false, movement_sample: float = 0.0) -> void:
	combat_kind = kind
	combat_phase = clampf(phase, 0.0, 1.0)
	# Keep the identical lantern, torso, cape and leg construction used by M13.
	# Existing M13 source coordinates retain their shared (256,456) feet origin.
	super.set_motion("air" if airborne else "idle", 3.5 if airborne else fposmod(movement_sample, 1.0))
	_blade_length = 164.0 if kind == "slash_down" else 126.0
	if kind in ["slash", "slash_follow", "slash_up", "slash_down"]:
		var keys: Array = UP_KEYS if kind == "slash_up" else (DOWN_KEYS if kind == "slash_down" else FORWARD_KEYS)
		var sample: Array = _sample(keys, combat_phase)
		pose.arms = [sample[0], sample[1], sample[2], sample[3]]
		pose.lean = sample[4]
		pose.cape = float(pose.cape) + float(sample[5])
		_sword_angle = sample[6]
	elif kind == "recoil":
		var recoil: float = sin(combat_phase * PI)
		pose.lean = -7.0 * recoil
		pose.cape = 5.0 * recoil
		pose.arms = [14.0 + recoil * 18.0, -11.0 - recoil * 12.0, 8.0 - recoil * 14.0, -5.0]
		_sword_angle = -65.0 + 22.0 * recoil
	elif kind == "death":
		var settle: float = smoothstep(0.0, 1.0, combat_phase)
		pose.hip_y = lerpf(float(pose.hip_y), 405.0, settle)
		pose.lean = 25.0 * settle
		pose.cape = -8.0 * settle
		pose.arms = [lerpf(14.0, 34.0, settle), lerpf(-11.0, 18.0, settle), 8.0, -5.0]
		_sword_angle = lerpf(-65.0, 24.0, settle)
	if not airborne:
		# Recompute planted soles after changing a hip height. No leg is stretched.
		feet_planted = true
		var near: Array = leg_ik(Vector2(270.0, float(pose.hip_y)), Vector2(270.0, 456.0), -1.0)
		var far: Array = leg_ik(Vector2(242.0, float(pose.hip_y)), Vector2(242.0, 456.0), 1.0)
		pose.legs = [near[0], near[1], far[0], far[1]]
	queue_redraw()

func _sample(keys: Array, phase: float) -> Array:
	for index in range(keys.size() - 1):
		var a: Array = keys[index]
		var b: Array = keys[index + 1]
		if phase <= float(b[0]):
			var weight: float = smoothstep(0.0, 1.0, inverse_lerp(float(a[0]), float(b[0]), phase))
			var result: Array = []
			for component in range(1, a.size()):
				result.append(lerpf(float(a[component]), float(b[component]), weight))
			return result
	return keys.back().slice(1)

func _draw() -> void:
	super._draw()
	if not sword_visible or not joints.has("near_arm"):
		return
	var hand: Vector2 = joints.near_arm[2]
	var angle: float = deg_to_rad(_sword_angle)
	if combat_kind.begins_with("slash") and combat_phase > 0.3 and combat_phase < 0.7:
		var amount: float = sin(inverse_lerp(0.3, 0.7, combat_phase) * PI)
		var sweep: float = -1.0 if combat_kind == "slash_up" else 1.0
		var points := PackedVector2Array()
		for index in range(13):
			var segment_angle: float = angle - sweep * lerpf(0.58, 0.0, float(index) / 12.0)
			points.append(hand + Vector2.RIGHT.rotated(segment_angle) * (_blade_length * 0.84))
		draw_polyline(points, Color(0.62, 0.94, 0.96, 0.30 * amount), 6.0, true)
		draw_polyline(points, Color(0.91, 1.0, 0.98, 0.66 * amount), 2.0, true)
	draw_set_transform(hand, angle)
	# Short brass grip and guard, with a restrained ivory/cyan blade.
	draw_line(Vector2(-19, 0), Vector2(3, 0), Color("17212b"), 9.0, true)
	draw_line(Vector2(-18, 0), Vector2(1, 0), Color("a88952"), 5.0, true)
	draw_line(Vector2(0, -10), Vector2(0, 10), Color("19252c"), 7.0, true)
	draw_line(Vector2(0, -9), Vector2(0, 9), Color("d0b477"), 4.0, true)
	var blade := PackedVector2Array([Vector2(3, -4.0), Vector2(_blade_length - 16, -3.0), Vector2(_blade_length, 0), Vector2(_blade_length - 16, 3.0), Vector2(3, 4.0)])
	draw_colored_polygon(blade, Color("e9f2dc"))
	var outline := blade.duplicate()
	outline.append(blade[0])
	draw_polyline(outline, Color("213d48"), 2.0, true)
	draw_line(Vector2(5, 0), Vector2(_blade_length - 3, 0), Color("b5edf0"), 1.4, true)
	draw_set_transform(Vector2.ZERO)
