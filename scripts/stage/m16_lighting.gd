extends Node2D
class_name M16RoomLighting
## Canvas lighting only: no collisions, movement, room rules or progression.
## Far architecture and HUD use their own CanvasLayers and remain independent.
## The existing faint glow PNG is a native light texture, never a bloom layer.

const GLOW = preload("res://assets/warden_clean/glow.png")
const AMBER := Color(1.0, 0.42, 0.15)
const CYAN := Color(0.48, 0.76, 0.80)
@export var max_visible_pools: int = 3
@export var vertical_floor_range: float = 500.0
@export var lantern_energy: float = 1.9
@export var lantern_texture_scale: float = 1.8
var world_ref: Node2D
var definition: Dictionary = {}
var lighting_enabled: bool = true
var ambient: CanvasModulate
var lights: Array[PointLight2D] = []
var candidate_info: Array[Dictionary] = []
var visible_pool_count: int = 0
var visible_light_count: int = 0
var ambient_color := Color(0.38, 0.41, 0.45)
var _hero_sprite: CanvasItem
var _hero_light: PointLight2D
var _hero_original_material: Material
var _unshaded_material: CanvasItemMaterial
var _hero_original_light: Dictionary = {}
var _hero_baseline_saved: bool = false

func setup(world: Node2D, room_definition: Dictionary) -> void:
	_restore_hero()
	_clear_nodes()
	world_ref = world
	definition = room_definition
	ambient_color = _ambient_for(str(definition.get("mood", "entrance")))
	ambient = CanvasModulate.new()
	ambient.name = "WorldAmbientOnly"
	ambient.color = ambient_color
	add_child(ambient)
	_capture_hero()
	_build_pools()
	set_enabled(lighting_enabled)

func _ambient_for(mood: String) -> Color:
	match mood:
		"lab", "process": return Color(0.35, 0.39, 0.43)
		"archive": return Color(0.36, 0.39, 0.43)
		"approach", "tribunal": return Color(0.35, 0.38, 0.42)
		"aftermath": return Color(0.40, 0.43, 0.45)
	return Color(0.38, 0.41, 0.45)

func _capture_hero() -> void:
	_hero_baseline_saved = false
	if not is_instance_valid(world_ref): return
	var actor := world_ref.get("hero") as Node2D
	if not is_instance_valid(actor): return
	_hero_sprite = actor.get("lantern_sprite") as CanvasItem
	_hero_light = actor.get("lantern_light") as PointLight2D
	if is_instance_valid(_hero_sprite):
		_hero_original_material = _hero_sprite.material
		_unshaded_material = CanvasItemMaterial.new()
		_unshaded_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	if is_instance_valid(_hero_light):
		_hero_original_light = {"energy":_hero_light.energy,"scale":_hero_light.texture_scale,"color":_hero_light.color,"enabled":_hero_light.enabled}
	_hero_baseline_saved = true

func _apply_hero() -> void:
	if not _hero_baseline_saved: return
	if is_instance_valid(_hero_sprite):
		# Preserve the exact M13 art palette under the darker world ambient.
		_hero_sprite.material = _unshaded_material
	if is_instance_valid(_hero_light):
		_hero_light.energy = lantern_energy
		_hero_light.texture_scale = lantern_texture_scale
		_hero_light.color = Color.WHITE

func _restore_hero() -> void:
	if not _hero_baseline_saved: return
	if is_instance_valid(_hero_sprite): _hero_sprite.material = _hero_original_material
	if is_instance_valid(_hero_light) and not _hero_original_light.is_empty():
		_hero_light.energy = float(_hero_original_light.energy)
		_hero_light.texture_scale = float(_hero_original_light.scale)
		_hero_light.color = _hero_original_light.color
		_hero_light.enabled = bool(_hero_original_light.enabled)

func _clear_nodes() -> void:
	for light in lights:
		if is_instance_valid(light): light.free()
	lights.clear()
	candidate_info.clear()
	if is_instance_valid(ambient): ambient.free()
	visible_pool_count = 0
	visible_light_count = 0

func _build_pools() -> void:
	# A handful of meaningful sources, never an evenly spaced row of lamps.
	for entry in world_ref.get("objects"):
		var object_definition: Dictionary = entry.definition
		var kind := str(object_definition.get("kind", "terminal"))
		if kind == "note": continue
		var node := entry.node as Node2D
		var role := "device"
		var color := CYAN
		var energy := 4.8
		var diameter := 300.0
		var priority := 1.0
		if kind == "bench":
			role = "rest"
			color = AMBER
			energy = 7.2
			diameter = 350.0
			priority = 0.0
		elif kind in ["lever", "lift_call", "seal_socket"]:
			role = "landing" if kind == "lift_call" else "lever"
			color = AMBER
			energy = 6.2
			diameter = 290.0
			priority = 1.0 if kind == "lift_call" else 1.5
		elif kind == "arena_reaction":
			energy = 4.0
			diameter = 330.0
		_add_pool(str(object_definition.get("id", role)), object_definition.pos, Vector2(0, -72), color, energy, diameter, priority, node)
	for exit in definition.get("exits", []):
		var point: Vector2 = exit.get("pos", Vector2.ZERO)
		_add_pool("portal_"+str(exit.get("id", lights.size())), point, Vector2(0,-92), AMBER, 5.0, 310.0, 3.0)
	var lift := world_ref.get("elevator") as Node2D
	if is_instance_valid(lift):
		_add_pool("archive_lift", lift.position, Vector2(0,-62), AMBER, 6.0, 270.0, 0.6, lift)
	# One introductory landing may receive a pool; all other lips stay readable
	# through the restrained ambient contrast and their painted ivory edges.
	if str(definition.get("mood", "")) != "archive":
		var floor_y := float(definition.get("floor_y", 1260))
		for platform in definition.get("platforms", []):
			var rect: Rect2 = platform.get("rect", Rect2())
			if rect.position.y < floor_y-40 and rect.size.x < 900 and rect.position.x > 160:
				_add_pool("first_landing", Vector2(rect.position.x+minf(rect.size.x*0.5,150), rect.position.y), Vector2(0,-60), AMBER, 4.2, 250.0, 4.0)
				break

func _add_pool(id: String, point: Vector2, offset: Vector2, color: Color, energy: float, diameter: float, priority: float, anchor: Node2D = null) -> void:
	# Duplicate doorway/switch sources would wash out the same small space.
	if id != "archive_lift":
		for info in candidate_info:
			if (info.point as Vector2).distance_to(point) < 105.0: return
	var light := PointLight2D.new()
	light.name = "Pool_"+id.validate_node_name()
	light.texture = GLOW
	light.texture_scale = diameter / 128.0
	light.color = color
	light.energy = 0.0
	light.shadow_enabled = false
	light.enabled = false
	light.visible = false
	add_child(light)
	light.position = point+offset
	lights.append(light)
	candidate_info.append({"id":id,"point":point,"offset":offset,"anchor":anchor,"energy":energy,"diameter":diameter,"priority":priority,"selected":false})

func set_enabled(value: bool) -> void:
	lighting_enabled = value
	if is_instance_valid(ambient): ambient.visible = value
	if value:
		_apply_hero()
		_update_lights(1.0)
	else:
		_restore_hero()
		for light in lights:
			light.enabled = false
			light.visible = false
			light.energy = 0.0
		visible_pool_count = 0
		_update_total_count()

func _process(delta: float) -> void:
	if lighting_enabled and is_instance_valid(world_ref): _update_lights(delta)

func _update_lights(delta: float) -> void:
	var camera := world_ref.get("camera") as Camera2D
	var actor := world_ref.get("hero") as Node2D
	var center := camera.global_position if is_instance_valid(camera) else Vector2(640,720)
	var hero_position := actor.global_position if is_instance_valid(actor) else center+Vector2(0,230)
	var half_view := get_viewport_rect().size/2.0
	if is_instance_valid(camera): half_view /= camera.zoom
	var ranked: Array[Dictionary] = []
	for index in range(lights.size()):
		var info: Dictionary = candidate_info[index]
		var anchor := info.anchor as Node2D
		var foot: Vector2 = to_global(info.point)
		if is_instance_valid(anchor): foot = anchor.global_position
		lights[index].global_position = foot + (info.offset as Vector2)
		var local_distance := lights[index].global_position-center
		if absf(foot.y-hero_position.y) > vertical_floor_range: continue
		if absf(local_distance.x) > half_view.x+150 or absf(local_distance.y) > half_view.y+150: continue
		var score := foot.distance_to(hero_position)*0.55 + foot.distance_to(center)*0.45 + float(info.priority)*65
		if bool(info.selected): score -= 70.0
		ranked.append({"index":index,"score":score})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary): return a.score < b.score)
	var selected: Array[int] = []
	for candidate in ranked:
		if selected.size() >= clampi(max_visible_pools, 0, 3): break
		var candidate_index := int(candidate.index)
		var overlaps_pool := false
		for selected_index in selected:
			if lights[candidate_index].global_position.distance_to(lights[selected_index].global_position) < 120.0:
				overlaps_pool = true
				break
		if not overlaps_pool: selected.append(candidate_index)
	visible_pool_count = 0
	for index in range(lights.size()):
		var picked := selected.has(index)
		candidate_info[index].selected = picked
		lights[index].enabled = picked
		lights[index].visible = picked
		if picked:
			var strength := float(candidate_info[index].energy)
			lights[index].energy = move_toward(lights[index].energy, strength, strength*maxf(0,delta)*5.0)
			visible_pool_count += 1
		else:
			lights[index].energy = 0.0
	_update_total_count()

func _update_total_count() -> void:
	visible_light_count = visible_pool_count
	if is_instance_valid(_hero_light) and _hero_light.enabled and _hero_light.is_visible_in_tree(): visible_light_count += 1

func diagnostics() -> Dictionary:
	var active: Array[Dictionary] = []
	for index in range(lights.size()):
		if lights[index].enabled and lights[index].visible:
			active.append({"id":candidate_info[index].id,"position":[lights[index].global_position.x,lights[index].global_position.y],"energy":lights[index].energy})
	return {"enabled":lighting_enabled,"ambient":[ambient_color.r,ambient_color.g,ambient_color.b],"pool_nodes":lights.size(),"visible_pool_count":visible_pool_count,"visible_light_count":visible_light_count,"visible_light_cap_including_hero":4,"active_pools":active}

func _exit_tree() -> void:
	# A shared actor survives room swaps; release this room's material override.
	_restore_hero()
