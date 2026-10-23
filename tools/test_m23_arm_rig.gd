extends SceneTree
## Anatomy regression: fixed painted bone lengths, rigid hand size, a connected
## rendered wrist and one real sword grip. No combat/world/hero mutations.
const Visual = preload("res://scripts/bosses/m23_compiler_visual.gd")
const ART_PATH := "res://assets/bosses/m23/compiler_profile_rig_atlas.png"
const ART_SHA := "bf7d5ded2b9422f07ce2d7fa6863d9447564902ffed0d3da7fbb1f2516c09bf8"
const HAND_SCALE := 300.0 / 879.0
const TOLERANCE := 0.0002
## Calibrated against the painted shoulder, elbow hinge, wrist cuff and palm
## in the unchanged atlas, independently inspected in the native joint study.
const SOURCE_SHOULDER := Vector2(1178, 349)
const SOURCE_ELBOW := Vector2(1276, 429)
const SOURCE_WRIST := Vector2(1335, 466)
const SOURCE_GRIP := Vector2(1384, 493)

class Actor extends Node2D:
	var direction: int = 1
	var phase: int = 1

var actor: Node2D
var visual: Node2D
var checks: int = 0
var failures: Array[String] = []
var max_bone_error: float = 0.0
var max_grip_error: float = 0.0
var max_render_joint_error: float = 0.0
var max_phase_elbow_step: float = 0.0
var baseline_lengths: Dictionary = {}
var extrema := {"upper_min": INF, "upper_max": 0.0, "forearm_min": INF, "forearm_max": 0.0, "palm_min": INF, "palm_max": 0.0}

func _initialize() -> void: call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		print("FAIL ",message)

func check_pose(state: String, progress: float, age: float, direction: int, phase: int = 1) -> Dictionary:
	actor.direction = direction
	actor.phase = phase
	visual.update_pose(state, age, progress, progress if state.ends_with("_warning") else 0.0)
	var joints: Dictionary = visual.get_arm_joints_local()
	var lengths: Dictionary = visual.get_arm_lengths()
	var measured := {"upper": Vector2(joints.shoulder).distance_to(Vector2(joints.elbow)), "forearm": Vector2(joints.elbow).distance_to(Vector2(joints.wrist)), "palm": Vector2(joints.wrist).distance_to(Vector2(joints.grip))}
	for id in ["upper", "forearm", "palm"]:
		var error: float = absf(float(measured[id]) - float(baseline_lengths[id]))
		max_bone_error = maxf(max_bone_error, error)
		extrema[id + "_min"] = minf(float(extrema[id + "_min"]), float(measured[id]))
		extrema[id + "_max"] = maxf(float(extrema[id + "_max"]), float(measured[id]))
		check(error < TOLERANCE, "%s %s facing%d keeps painted %s length" % [state, str(progress), direction, id])
		check(absf(float(lengths[id]) - float(baseline_lengths[id])) < TOLERANCE, "bone calibration cannot change with a pose")
	var hand_point: Vector2 = visual.get_hand_grip_local()
	var weapon_point: Vector2 = visual.get_weapon_grip_local()
	var error: float = hand_point.distance_to(weapon_point)
	max_grip_error = maxf(max_grip_error, error)
	check(error < TOLERANCE, "%s rendered hand remains on the actual weapon hilt" % state)
	check(Vector2(joints.grip).distance_to(hand_point) < TOLERANCE, "the reported palm endpoint is the rendered hand")
	check(is_finite(hand_point.x) and is_finite(hand_point.y), "clamping never creates a non-finite limb position")
	check(visual.scale.x == float(direction), "the whole rig mirrors exactly once toward the opponent")
	var actual_world: Vector2 = visual.to_global(hand_point)
	var actor_world: Vector2 = actor.to_global(Vector2(weapon_point.x * float(direction), weapon_point.y))
	check(actual_world.distance_to(actor_world) < TOLERANCE, "the actor's mirrored combat grip and rendered hand coincide")
	if visual.has_method("get_hand_transform_local"):
		var hand_transform: Transform2D = visual.get_hand_transform_local()
		check(absf(hand_transform.x.length() - HAND_SCALE) < TOLERANCE and absf(hand_transform.y.length() - HAND_SCALE) < TOLERANCE, "the closed fist is rigid and keeps the same size")
	if visual.has_method("get_rendered_arm_joints_local"):
		var rendered: Dictionary = visual.get_rendered_arm_joints_local()
		for id in ["shoulder", "elbow", "wrist"]:
			var mapping_error: float = Vector2(rendered[id]).distance_to(Vector2(joints[id]))
			max_render_joint_error = maxf(max_render_joint_error, mapping_error)
			check(mapping_error < TOLERANCE, "the rendered source %s maps to the solved anatomical joint" % id)
	return joints

func run_checks() -> void:
	check(FileAccess.get_sha256(ART_PATH) == ART_SHA, "the art master stays byte-identical during the native anatomy correction")
	actor = Actor.new()
	actor.position = Vector2(400, 600)
	root.add_child(actor)
	visual = Visual.new()
	actor.add_child(visual)
	visual.setup(actor)
	await process_frame
	for api in ["get_arm_joints_local", "get_arm_lengths", "get_hand_grip_local", "get_weapon_grip_local"]:
		check(visual.has_method(api), "anatomical API is exposed: " + api)
	if not visual.has_method("get_arm_joints_local") or not visual.has_method("get_arm_lengths"):
		actor.queue_free()
		await process_frame
		quit(1)
		return
	baseline_lengths = visual.get_arm_lengths()
	check(float(baseline_lengths.upper) > 0.0 and float(baseline_lengths.forearm) > 0.0 and float(baseline_lengths.palm) > 0.0, "both painted bones and rigid palm have positive calibrated lengths")
	var painted_lengths := {"upper": SOURCE_SHOULDER.distance_to(SOURCE_ELBOW) * HAND_SCALE, "forearm": SOURCE_ELBOW.distance_to(SOURCE_WRIST) * HAND_SCALE, "palm": SOURCE_WRIST.distance_to(SOURCE_GRIP) * HAND_SCALE}
	for id in ["upper", "forearm", "palm"]:
		check(absf(float(baseline_lengths[id]) - float(painted_lengths[id])) < TOLERANCE, "fixed %s length comes from the painted armor, not a longer invented bone" % id)
	var poses: Array[String] = ["dormant", "intro", "idle", "bolts_warning", "bolts_active", "sweep_warning", "sweep_active", "pillars_warning", "pillars_active", "chains_warning", "chains_active", "recover", "stagger", "phase_transition", "dead"]
	var sample_count: int = 0
	for direction in [1, -1]:
		for state in poses:
			for progress in [0.0, 0.25, 0.5, 0.75, 1.0]:
				check_pose(state, progress, float(sample_count) * 0.01, direction, 2 if state == "phase_transition" else 1)
				sample_count += 1
		var previous_elbow := Vector2.INF
		for tick in range(121):
			var joints: Dictionary = check_pose("phase_transition", float(tick) / 120.0, 10.0 + float(tick) / 60.0, direction, 2)
			var elbow: Vector2 = joints.elbow
			if is_finite(previous_elbow.x):
				max_phase_elbow_step = maxf(max_phase_elbow_step, elbow.distance_to(previous_elbow))
			previous_elbow = elbow
			sample_count += 1
	check(max_phase_elbow_step < 8.0, "the two-second phase clip has no IK elbow flip or discontinuity")
	var report := {"schema": "m23-arm-anatomy-1", "checks": checks, "failures": failures, "pose_samples": sample_count, "fixed_lengths": baseline_lengths, "measured_extrema": extrema, "max_bone_length_error_px": max_bone_error, "max_hand_hilt_error_px": max_grip_error, "max_rendered_joint_error_px": max_render_joint_error, "max_phase_elbow_step_px": max_phase_elbow_step, "scope": "Fixed painted limb lengths, rendered joint mapping, rigid hand size and grip continuity in all real states, both facings and both 121-sample phase sweeps. Not a combat or victory test."}
	var file := FileAccess.open("user://m23_arm_rig_report.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("M23 arm anatomy: ",checks," checks, ",failures.size()," failures; max bone error ",max_bone_error,"px; max grip error ",max_grip_error,"px")
	actor.queue_free()
	actor = null
	visual = null
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
