extends Node2D
## The Execution Chancellor's original approved silhouette, rigged from an
## unchanged generated atlas. Combat rectangles and attack effects stay on the
## actor: this rig never deals damage or changes timing/physics.

const ART_PATH := "res://assets/bosses/m23/compiler_profile_rig_atlas.png"
const BODY_REGION := Rect2(10, 0, 1170, 887)
const BODY_ORIGIN := Vector2(815, 879)
const BODY_SCALE := 300.0 / 879.0
const BODY_RECT := Rect2((BODY_REGION.position - BODY_ORIGIN) * BODY_SCALE, BODY_REGION.size * BODY_SCALE)
const BLADE_REGION := Rect2(1575, 12, 164, 856)
const BLADE_SCALE := 0.32
const BLADE_SOURCE_GRIP := Vector2(1657, 737)
const BLADE_RECT := Rect2((BLADE_REGION.position - BLADE_SOURCE_GRIP) * BLADE_SCALE, BLADE_REGION.size * BLADE_SCALE)
const CROWN_REGION := Rect2(724, 10, 182, 204)
const CROWN_RECT := Rect2((CROWN_REGION.position - BODY_ORIGIN) * BODY_SCALE, CROWN_REGION.size * BODY_SCALE)
const ARM_REGION := Rect2(1136, 295, 284, 242)
const HAND_REGION := Rect2(1324, 440, 96, 97)
const ARM_SOURCE_ROOT := Vector2(1178, 349)
const ARM_SOURCE_ELBOW := Vector2(1276, 429)
const ARM_SOURCE_WRIST := Vector2(1335, 466)
const ARM_SOURCE_GRIP := Vector2(1384, 493)
const UPPER_ARM_LENGTH := 43.176422118412205
const FOREARM_LENGTH := 23.7685806777886
const PALM_LENGTH := 19.094335468531558
const ARM_ROOT := (Vector2(757, 303) - BODY_ORIGIN) * BODY_SCALE
const REST_GRIP := ARM_ROOT + (ARM_SOURCE_GRIP - ARM_SOURCE_ROOT) * BODY_SCALE
const ACTIVE_GRIP := Vector2(20, -118)
const REST_BLADE_ANGLE := 1.37
const BODY_ROWS := 22
const BODY_COLUMNS := 6

var actor: Node2D
var pose_state: String = "idle"
var pose_age: float = 0.0
var pose_progress: float = 0.0
var warning_fraction: float = 0.0
var external_blade: bool = false
var second_phase: bool = false
var facing: int = 1
var _art: Texture2D
var _body_mesh := ArrayMesh.new()
var _core_glow: GradientTexture2D
var _pose_enter_age: float = 0.0
var _death_progress: float = 0.0
var _highlights: Node2D
var _near_arm: Node2D
var _near_hand: Node2D
var _arm_mesh := ArrayMesh.new()
var _current_grip := REST_GRIP
var _current_arm_root := ARM_ROOT
var _current_elbow := ARM_ROOT + (ARM_SOURCE_ELBOW - ARM_SOURCE_ROOT) * BODY_SCALE
var _current_wrist := ARM_ROOT + (ARM_SOURCE_WRIST - ARM_SOURCE_ROOT) * BODY_SCALE
var _upper_rotation: float = 0.0
var _forearm_rotation: float = 0.0
var _hand_rotation: float = 0.0
var _far_arm_accent: Node2D
var _far_arm_mesh := ArrayMesh.new()

class FlameAndBlade extends Node2D:
	var rig: Node2D
	func _draw() -> void:
		if is_instance_valid(rig):
			rig.draw_highlights(self)

class NearLimb extends Node2D:
	var rig: Node2D
	var hand_only: bool = false
	func _draw() -> void:
		if is_instance_valid(rig):
			if hand_only: rig.draw_hand(self)
			else: rig.draw_arm(self)

class ExistingFarArmLight extends Node2D:
	var rig: Node2D
	func _draw() -> void:
		if is_instance_valid(rig): rig.draw_far_arm_accent(self)

func _ready() -> void:
	_art = load(ART_PATH) as Texture2D
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var glow_gradient := Gradient.new()
	glow_gradient.colors = PackedColorArray([Color(0.25, 0.82, 0.95, 0.14), Color(0.25, 0.82, 0.95, 0.0)])
	_core_glow = GradientTexture2D.new()
	_core_glow.gradient = glow_gradient
	_core_glow.width = 96
	_core_glow.height = 96
	_core_glow.fill = GradientTexture2D.FILL_RADIAL
	_core_glow.fill_from = Vector2(0.5, 0.5)
	_core_glow.fill_to = Vector2(0.5, 1.0)
	_highlights = FlameAndBlade.new()
	_highlights.rig = self
	_highlights.name = "CompilerFlameAndDataBlade"
	_highlights.z_index = 11
	_highlights.texture_filter = texture_filter
	var emissive := CanvasItemMaterial.new()
	emissive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_highlights.material = emissive
	add_child(_highlights)
	_far_arm_accent = ExistingFarArmLight.new()
	_far_arm_accent.rig = self
	_far_arm_accent.name = "CompilerExistingFarArmEdge"
	_far_arm_accent.z_index = 1
	_far_arm_accent.material = emissive
	add_child(_far_arm_accent)
	_near_arm = NearLimb.new()
	_near_arm.rig = self
	_near_arm.name = "CompilerNearArm"
	_near_arm.texture_filter = texture_filter
	_near_arm.z_index = 10
	add_child(_near_arm)
	_near_hand = NearLimb.new()
	_near_hand.rig = self
	_near_hand.hand_only = true
	_near_hand.name = "CompilerGrippingFingers"
	_near_hand.texture_filter = texture_filter
	_near_hand.z_index = 13
	add_child(_near_hand)
	_update_arm_pose()
	_rebuild_body_mesh()
	queue_redraw()

func setup(boss_actor: Node2D) -> void:
	actor = boss_actor
	position = Vector2.ZERO
	update_pose("idle", 0.0)

func set_external_blade(enabled: bool) -> void:
	# The combat actor renders its exact active sweep shape. Hide the held prop
	# only while that active blade is on screen, preventing a second false blade.
	external_blade = enabled
	if is_instance_valid(_highlights): _highlights.queue_redraw()
	queue_redraw()

func update_pose(state: String, age: float, phase: float = 0.0, warning: float = 0.0) -> void:
	if state != pose_state:
		_pose_enter_age = maxf(0.0, age)
	pose_state = state
	pose_age = maxf(0.0, age)
	pose_progress = clampf(phase, 0.0, 1.0)
	warning_fraction = clampf(warning, 0.0, 1.0)
	if is_instance_valid(actor):
		var raw_direction: Variant = actor.get("direction")
		if raw_direction is int or raw_direction is float:
			facing = -1 if float(raw_direction) < 0.0 else 1
		var raw_phase: Variant = actor.get("phase")
		second_phase = (raw_phase is int or raw_phase is float) and float(raw_phase) >= 2.0
	scale.x = float(facing)
	var alpha: float = 1.0
	if pose_state in ["death", "dead"]:
		# A defeated actor can keep its final attack timer frozen. Its continuing
		# presentation age still completes this harmless visual dissolve.
		_death_progress = maxf(pose_progress, clampf(pose_age - _pose_enter_age, 0.0, 1.0))
		alpha = 1.0 - smoothstep(0.08, 1.0, _death_progress)
	elif pose_state == "intro":
		alpha = lerpf(0.65, 1.0, pose_progress)
	self_modulate = Color(1.0, 1.0, 1.0, alpha)
	if is_instance_valid(_highlights):
		_highlights.modulate = Color(1.0, 1.0, 1.0, alpha)
		_highlights.queue_redraw()
	for limb in [_near_arm, _near_hand, _far_arm_accent]:
		if is_instance_valid(limb):
			limb.modulate = Color(1.0, 1.0, 1.0, alpha)
			limb.queue_redraw()
	_update_arm_pose()
	_rebuild_body_mesh()
	queue_redraw()

func get_body_bounds() -> Rect2:
	return BODY_RECT

func get_held_blade_tip() -> Vector2:
	return get_weapon_grip_local() + Vector2(0.0, BLADE_RECT.position.y).rotated(_blade_angle())

func get_weapon_grip_local() -> Vector2:
	return _current_grip

func get_hand_grip_local() -> Vector2:
	return get_hand_transform_local() * (ARM_SOURCE_GRIP - ARM_SOURCE_WRIST)

func get_hand_transform_local() -> Transform2D:
	return Transform2D(_hand_rotation, Vector2(BODY_SCALE, BODY_SCALE), 0.0, _current_wrist)

func get_arm_joints_local() -> Dictionary:
	return {"shoulder": _current_arm_root, "elbow": _current_elbow, "wrist": _current_wrist, "grip": get_hand_grip_local()}

func get_rendered_arm_joints_local() -> Dictionary:
	# These are the same source-point maps used by the textured arm mesh and
	# rigid hand renderer, rather than a second copy of the requested IK goal.
	return {"shoulder": _map_arm_point(ARM_SOURCE_ROOT), "elbow": _map_arm_point(ARM_SOURCE_ELBOW), "wrist": _map_arm_point(ARM_SOURCE_WRIST), "grip": get_hand_grip_local()}

func get_arm_lengths() -> Dictionary:
	return {"upper": UPPER_ARM_LENGTH, "forearm": FOREARM_LENGTH, "palm": PALM_LENGTH}

func get_weapon_angle_local() -> float:
	return _blade_angle()

func is_held_blade_visible() -> bool:
	return not (external_blade and _is_sweep()) and self_modulate.a > 0.0

func _is_warning() -> bool:
	return pose_state == "windup" or pose_state.ends_with("_warning")

func _is_sweep() -> bool:
	return pose_state in ["sweep", "sweep_active"]

func _is_transition() -> bool:
	return pose_state in ["transition", "phase_transition"]

func _phase_fold() -> float:
	if not _is_transition(): return 0.0
	return smoothstep(0.0, 0.22, pose_progress) * (1.0 - smoothstep(0.25, 0.55, pose_progress))

func _phase_raise() -> float:
	if not _is_transition(): return 0.0
	return smoothstep(0.32, 0.58, pose_progress) * (1.0 - smoothstep(0.76, 1.0, pose_progress))

func _phase_flare() -> float:
	if not _is_transition(): return 0.0
	return smoothstep(0.20, 0.42, pose_progress) * (1.0 - smoothstep(0.70, 0.95, pose_progress))

func _phase_release() -> float:
	if not _is_transition(): return 0.0
	return smoothstep(0.46, 0.64, pose_progress) * (1.0 - smoothstep(0.80, 1.0, pose_progress))

func _phase_top_transform() -> Transform2D:
	var fold: float = _phase_fold()
	var angle: float = 0.18 * fold
	var hip := Vector2(0, -104)
	return Transform2D(angle, hip - hip.rotated(angle) + Vector2(0, 28.0 * fold))

func _phase_body_point(point: Vector2) -> Vector2:
	if not _is_transition(): return point
	# Upper torso/crown are a rigid unit; the hips blend into the planted feet.
	var weight: float = smoothstep(80.0, 150.0, -point.y)
	return point.lerp(_phase_top_transform() * point, weight)

func _blade_angle() -> float:
	var rest: float = REST_BLADE_ANGLE
	if pose_state == "sweep_warning" or (pose_state == "windup" and warning_fraction > 0.0):
		return lerpf(rest, rest - 0.9, smoothstep(0.0, 1.0, warning_fraction))
	if _is_sweep():
		return (Vector2(304, -70) - ACTIVE_GRIP).angle() + PI * 0.5
	if pose_state == "recover":
		return lerpf((Vector2(304, -70) - ACTIVE_GRIP).angle() + PI * 0.5, rest, smoothstep(0.0, 1.0, pose_progress))
	if pose_state == "stagger":
		return rest + 0.15
	if _is_transition():
		return lerpf(rest + _phase_fold() * 0.30, 0.08, _phase_raise())
	if pose_state in ["death", "dead"]:
		return lerpf(rest, 2.1, _death_progress)
	return rest

func _update_arm_pose() -> void:
	_current_arm_root = ARM_ROOT
	_current_grip = REST_GRIP
	if pose_state == "sweep_warning" or pose_state == "windup":
		_current_grip = ARM_ROOT + (REST_GRIP - ARM_ROOT).rotated(-0.72 * smoothstep(0.0, 1.0, warning_fraction))
	elif _is_sweep():
		_current_grip = ACTIVE_GRIP
	elif pose_state == "recover":
		_current_grip = ACTIVE_GRIP.lerp(REST_GRIP, smoothstep(0.0, 1.0, pose_progress))
	elif pose_state == "stagger":
		_current_grip += Vector2(-4, 7)
		var jitter: float = sin(pose_age * 32.0) * 2.1 * (1.0 - pose_progress)
		_current_arm_root.x += jitter
		_current_grip.x += jitter
	elif _is_transition():
		var lowered: Vector2 = REST_GRIP + Vector2(-10, 15) * _phase_fold()
		_current_arm_root = _phase_body_point(ARM_ROOT)
		_current_grip = _phase_body_point(lowered.lerp(Vector2(41, -224), _phase_raise()))
	if pose_state in ["death", "dead"]:
		_current_arm_root.y += 12.0 * _death_progress
		_current_grip.y += 12.0 * _death_progress
	_solve_arm(_current_grip)
	_rebuild_arm_mesh()
	_rebuild_far_arm_mesh()

func _solve_arm(desired_grip: Vector2) -> void:
	# Solve the two fixed painted bones to the WRIST. The rigid palm offset then
	# rotates around that wrist with the weapon; it never scales or opens a seam.
	_hand_rotation = _blade_angle() - REST_BLADE_ANGLE
	var hand_offset: Vector2 = ((ARM_SOURCE_GRIP - ARM_SOURCE_WRIST) * BODY_SCALE).rotated(_hand_rotation)
	var desired_wrist: Vector2 = desired_grip - hand_offset
	var delta: Vector2 = desired_wrist - _current_arm_root
	var distance: float = clampf(delta.length(), absf(UPPER_ARM_LENGTH - FOREARM_LENGTH) + 0.001, UPPER_ARM_LENGTH + FOREARM_LENGTH - 0.001)
	var axis: Vector2 = delta.normalized() if delta.length_squared() > 0.000001 else Vector2.RIGHT
	_current_wrist = _current_arm_root + axis * distance
	var cosine: float = (UPPER_ARM_LENGTH * UPPER_ARM_LENGTH + distance * distance - FOREARM_LENGTH * FOREARM_LENGTH) / (2.0 * UPPER_ARM_LENGTH * distance)
	# Positive bend matches the actual proximal elbow hinge in the source art.
	var upper_angle: float = axis.angle() + acos(clampf(cosine, -1.0, 1.0))
	_current_elbow = _current_arm_root + Vector2.from_angle(upper_angle) * UPPER_ARM_LENGTH
	_upper_rotation = (_current_elbow - _current_arm_root).angle() - (ARM_SOURCE_ELBOW - ARM_SOURCE_ROOT).angle()
	_forearm_rotation = (_current_wrist - _current_elbow).angle() - (ARM_SOURCE_WRIST - ARM_SOURCE_ELBOW).angle()
	_current_grip = get_hand_grip_local()

func _map_arm_point(source: Vector2) -> Vector2:
	var upper: Vector2 = _current_arm_root + (source - ARM_SOURCE_ROOT).rotated(_upper_rotation) * BODY_SCALE
	var forearm: Vector2 = _current_elbow + (source - ARM_SOURCE_ELBOW).rotated(_forearm_rotation) * BODY_SCALE
	var along_forearm: float = (source - ARM_SOURCE_ELBOW).dot((ARM_SOURCE_WRIST - ARM_SOURCE_ELBOW).normalized())
	var forearm_weight: float = smoothstep(-13.0, 13.0, along_forearm)
	return upper.lerp(forearm, forearm_weight)

func _rebuild_far_arm_mesh() -> void:
	if not is_instance_valid(_art): return
	# Clip to the already-painted distant arm/fist. This is a low-opacity light
	# accent on the original pixels, never a new limb, pose or displaced hand.
	var source := PackedVector2Array([Vector2(831,369), Vector2(850,390), Vector2(869,417), Vector2(892,445), Vector2(908,472), Vector2(896,477), Vector2(876,458), Vector2(858,436), Vector2(838,412), Vector2(825,389)])
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	for point in source:
		var vertex: Vector2 = (point - BODY_ORIGIN) * BODY_SCALE
		if pose_state == "stagger": vertex.x += sin(pose_age * 32.0) * 2.1 * (1.0 - pose_progress)
		if pose_state in ["death", "dead"]: vertex.y += 12.0 * _death_progress
		vertices.append(_phase_body_point(vertex))
		uvs.append(point / _art.get_size())
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = Geometry2D.triangulate_polygon(source)
	_far_arm_mesh.clear_surfaces()
	_far_arm_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func _rebuild_arm_mesh() -> void:
	if not is_instance_valid(_art): return
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	const COLS := 20
	const ROWS := 18
	for row in range(ROWS + 1):
		for column in range(COLS + 1):
			var uv := Vector2(float(column) / COLS, float(row) / ROWS)
			var source: Vector2 = ARM_REGION.position + ARM_REGION.size * uv
			vertices.append(_map_arm_point(source))
			uvs.append(source / _art.get_size())
	for row in range(ROWS):
		for column in range(COLS):
			var source_center: Vector2 = ARM_REGION.position + ARM_REGION.size * Vector2((float(column) + 0.5) / COLS, (float(row) + 0.5) / ROWS)
			# The closed fingers are a separate rigid layer above the sword hilt.
			if source_center.x > 1340.0 and source_center.y > 444.0: continue
			var current: int = row * (COLS + 1) + column
			indices.append_array(PackedInt32Array([current, current + 1, current + COLS + 1, current + 1, current + COLS + 2, current + COLS + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	_arm_mesh.clear_surfaces()
	_arm_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func _rebuild_body_mesh() -> void:
	if not is_instance_valid(_art):
		return
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var image_size: Vector2 = _art.get_size()
	var amplitude: float = 1.7 if not second_phase else 2.5
	if _is_warning():
		amplitude *= 0.45
	if _is_transition():
		amplitude += sin(pose_progress * PI) * 3.0
	var death_drop: float = 12.0 * _death_progress if pose_state in ["death", "dead"] else 0.0
	var stagger_x: float = sin(pose_age * 32.0) * 2.1 * (1.0 - pose_progress) if pose_state == "stagger" else 0.0
	for row in range(BODY_ROWS + 1):
		var v: float = float(row) / float(BODY_ROWS)
		# Crown and core occupy the upper third and remain a single rigid shape.
		var cloth_weight: float = smoothstep(0.62, 0.96, v)
		for column in range(BODY_COLUMNS + 1):
			var u: float = float(column) / float(BODY_COLUMNS)
			# The separate arm's cell begins at x1141. Crop the empty upper-right
			# canvas in-engine while preserving the body's forward boot below it.
			var source_y: float = BODY_REGION.position.y + BODY_REGION.size.y * v
			var source_right: float = lerpf(1100.0, BODY_REGION.end.x, smoothstep(715.0, 805.0, source_y))
			var source := Vector2(lerpf(BODY_REGION.position.x, source_right, u), source_y)
			var vertex: Vector2 = (source - BODY_ORIGIN) * BODY_SCALE
			vertex.x += sin(pose_age * 1.65 + v * 2.8 + u * 0.7) * amplitude * cloth_weight + stagger_x
			vertex.y += sin(pose_age * 1.35 + u * 3.0) * 0.65 * cloth_weight + death_drop
			vertex = _phase_body_point(vertex)
			if _is_transition():
				# Only the broad trailing paper strips flare. Both boots stay planted.
				var tail_weight: float = 1.0 - smoothstep(-220.0, -145.0, vertex.x)
				vertex += Vector2(-20, -22) * tail_weight * _phase_release()
			points.append(vertex)
			uvs.append(source / image_size)
	for row in range(BODY_ROWS):
		for column in range(BODY_COLUMNS):
			var current: int = row * (BODY_COLUMNS + 1) + column
			indices.append_array(PackedInt32Array([current, current + 1, current + BODY_COLUMNS + 1, current + 1, current + BODY_COLUMNS + 2, current + BODY_COLUMNS + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	_body_mesh.clear_surfaces()
	_body_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func _draw() -> void:
	if not is_instance_valid(_art):
		return
	_draw_windows()
	if _body_mesh.get_surface_count() > 0:
		draw_mesh(_body_mesh, _art)

func draw_highlights(canvas: Node2D) -> void:
	if not is_instance_valid(_art):
		return
	# Paper and armor receive arena illumination; the cyan source and energy
	# blade stay legible using their own emissive canvas, like the hero's flame.
	var offset := Vector2.ZERO
	if pose_state == "stagger":
		offset.x = sin(pose_age * 32.0) * 2.1 * (1.0 - pose_progress)
	if pose_state in ["death", "dead"]:
		offset.y = 12.0 * _death_progress
	if _is_transition(): canvas.draw_set_transform_matrix(_phase_top_transform())
	if is_instance_valid(_core_glow):
		var glow_alpha: float = 0.65 if not _is_warning() else lerpf(0.7, 1.0, warning_fraction)
		var flare: float = _phase_flare()
		var glow_size := Vector2.ONE * (92.0 + 78.0 * flare)
		canvas.draw_texture_rect(_core_glow, Rect2(Vector2(5, -257) + offset - glow_size * 0.5, glow_size), false, Color(1, 1, 1, glow_alpha + flare * 1.6))
		if flare > 0.0:
			var flame := PackedVector2Array([Vector2(-7, -284), Vector2(-3, -311), Vector2(5, -338), Vector2(8, -310), Vector2(16, -329), Vector2(13, -283), Vector2(5, -275)])
			canvas.draw_colored_polygon(flame, Color(0.44, 0.94, 1.0, flare * 0.25))
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(2, -286), Vector2(5, -325), Vector2(9, -287)]), Color(0.83, 1.0, 1.0, flare * 0.48))
	canvas.draw_texture_rect_region(_art, Rect2(CROWN_RECT.position + offset, CROWN_RECT.size), CROWN_REGION)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if is_held_blade_visible():
		canvas.draw_set_transform(get_weapon_grip_local(), _blade_angle(), Vector2.ONE)
		canvas.draw_texture_rect_region(_art, BLADE_RECT, BLADE_REGION)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_arm(canvas: Node2D) -> void:
	if is_instance_valid(_art) and _arm_mesh.get_surface_count() > 0:
		canvas.draw_mesh(_arm_mesh, _art)

func draw_hand(canvas: Node2D) -> void:
	if not is_instance_valid(_art): return
	canvas.draw_set_transform_matrix(get_hand_transform_local())
	canvas.draw_texture_rect_region(_art, Rect2(HAND_REGION.position - ARM_SOURCE_WRIST, HAND_REGION.size), HAND_REGION)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_far_arm_accent(canvas: Node2D) -> void:
	if is_instance_valid(_art) and _far_arm_mesh.get_surface_count() > 0:
		canvas.draw_mesh(_far_arm_mesh, _art, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, 0.12))

func _draw_windows() -> void:
	# Decorative windows remain behind the silhouette. Each has a broad frame
	# and three clear lines, without fine text or a fake damaging projectile.
	var intensity: float = 0.42 + (0.12 if second_phase else 0.0)
	if _is_transition():
		intensity += sin(pose_progress * PI) * 0.22
	for index in range(4):
		var side: float = -1.0 if index < 3 else 1.0
		var tier: int = index % 2
		var origin := Vector2(side * (108.0 + float(tier) * 39.0), -227.0 + float(tier) * 75.0 + sin(pose_age * 1.15 + float(index)) * 3.0)
		if _is_transition():
			origin = _phase_body_point(origin)
			origin.x += side * _phase_release() * 25.0
		var panel := PackedVector2Array([origin + Vector2(-19, -22), origin + Vector2(19, -27), origin + Vector2(19, 22), origin + Vector2(-19, 27)])
		draw_colored_polygon(panel, Color(0.045, 0.13, 0.17, intensity * 0.7))
		var edge: PackedVector2Array = panel.duplicate()
		edge.append(panel[0])
		draw_polyline(edge, Color(0.37, 0.78, 0.83, intensity), 1.0, true)
		for line in range(3):
			var y: float = float(line) * 8.0 - 10.0
			draw_line(origin + Vector2(-12, y), origin + Vector2(10 - line * 3, y - 2.0), Color(0.48, 0.82, 0.83, intensity * 0.72), 1.0, true)
