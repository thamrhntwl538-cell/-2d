extends RefCounted
## M16 texture replacement only. The caller owns all geometry, progress, positions,
## collisions, animations and interaction state. Call after room objects are built.

const ART_ROOT := "res://assets/environments/polished_wing/"
const PLATFORM_SCRIPT := "res://scripts/stage/academic_platform.gd"
const LIFT_SCRIPT := "res://scripts/interactables/m15/academic_elevator.gd"
const SHELF_SCRIPT := "res://scripts/interactables/m15/secret_shelf.gd"
const GATE_SCRIPT := "res://scripts/interactables/academic_gate.gd"
const Visuals = preload("res://scripts/stage/m16_room_visuals.gd")

# The inner top edge is flat at y=422. Trimming the perspective end bevels
# keeps the painted lip within one source pixel of the collision's local y=0.
const PLATFORM_REGION := Rect2(72, 422, 1392, 226)
const SUPPORT_REGION := Rect2(90, 490, 1300, 150)
const INTERACTION_REGIONS := {
	"bench":Rect2(117, 75, 770, 239),
	"terminal":Rect2(1085, 11, 214, 418),
	"gate":Rect2(168, 316, 654, 672),
	"wall_lamp":Rect2(1058, 511, 231, 403)
}
# Left post, right post, crown and sill proportions of the reviewed gate crop.
const GATE_FRAME_FRACTIONS := Vector4(0.228, 0.228, 0.42, 0.015)

class GateArtwork:
	extends Node2D
	## The original parent keeps all authoritative opening/collision behavior.
	## Only its own old drawing is hidden; this child paints the same footprint.
	var gate: Node2D
	var texture: Texture2D
	var source_rect := Rect2()
	var frame_fractions := Vector4(0.228, 0.228, 0.42, 0.015)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(gate) or texture == null: return
		var dimensions := source_rect.size
		var left := dimensions.x * frame_fractions.x
		var right := dimensions.x * frame_fractions.y
		var crown := dimensions.y * frame_fractions.z
		var sill := dimensions.y * frame_fractions.w
		var panel := Rect2(left, crown, dimensions.x-left-right, dimensions.y-crown-sill)
		var hidden := panel.size.y * smoothstep(0.0, 1.0, clampf(float(gate.get("progress")), 0.0, 1.0))
		if hidden < panel.size.y:
			var remaining := Rect2(panel.position + Vector2(0, hidden), Vector2(panel.size.x, panel.size.y-hidden))
			_piece(remaining, Vector2(0, -hidden))
		_piece(Rect2(0, 0, left, dimensions.y))
		_piece(Rect2(dimensions.x-right, 0, right, dimensions.y))
		_piece(Rect2(left, 0, dimensions.x-left-right, crown))
		_piece(Rect2(left, dimensions.y-sill, dimensions.x-left-right, sill))

	func _piece(piece: Rect2, offset := Vector2.ZERO) -> void:
		var scale_factor := Vector2(180.0 / source_rect.size.x, float(gate.get("gate_height")) / source_rect.size.y)
		var destination := Rect2(Vector2(-90, -float(gate.get("gate_height"))) + (piece.position+offset)*scale_factor, piece.size*scale_factor)
		draw_texture_rect_region(texture, destination, Rect2(source_rect.position+piece.position, piece.size))

static func setup(world: Node2D, _room_definition: Dictionary) -> Dictionary:
	var counts := {"revision":16,"platforms":0,"moving_surfaces":0,"interactables":0,"gates":0,"shelves":0,"lamps":0,"missing_assets":[]}
	var room := world.get("active_room") as Node
	if room == null: return counts
	var stone := _texture("platform.png", counts)
	var interactions := _texture("interactions.png", counts)
	var props := _texture("props.png", counts)
	if _valid_region(stone, PLATFORM_REGION) and _valid_region(stone, SUPPORT_REGION):
		_skin_surfaces(room, stone, counts)
	var object_entries: Variant = world.get("objects")
	if object_entries is Array and interactions:
		for entry in object_entries:
			if not entry is Dictionary: continue
			var definition: Dictionary = entry.get("definition", {})
			var node := entry.get("node") as Node2D
			if not is_instance_valid(node): continue
			var kind := str(definition.get("kind", node.get("kind")))
			if kind == "note": continue
			var region: Rect2 = INTERACTION_REGIONS["bench" if kind == "bench" else "terminal"]
			if not _valid_region(interactions, region): continue
			node.set("texture", interactions)
			node.set("source_rect", region)
			node.queue_redraw()
			counts.interactables += 1
			if kind == "bench" and _valid_region(interactions, INTERACTION_REGIONS.wall_lamp):
				_add_bench_lamp(node, interactions)
				counts.lamps += 1
	var gate_entries: Variant = world.get("gates")
	if gate_entries is Array:
		for entry in gate_entries:
			if not entry is Dictionary: continue
			var node := entry.get("node") as Node2D
			if not is_instance_valid(node): continue
			var source: Script = node.get_script()
			if source == null: continue
			if source.resource_path == SHELF_SCRIPT:
				var region: Rect2 = Visuals.M16_PROP_REGIONS.get("bookshelf", Rect2())
				if not _valid_region(props, region): continue
				node.set("texture", props)
				node.set("source_rect", region)
				node.queue_redraw()
				counts.shelves += 1
			elif source.resource_path == GATE_SCRIPT:
				var region: Rect2 = INTERACTION_REGIONS.gate
				if not _valid_region(interactions, region): continue
				_skin_gate(node, interactions, region)
				counts.gates += 1
	return counts

static func _add_bench_lamp(bench: Node2D, texture: Texture2D) -> void:
	# One small visible fixture identifies the controller's existing amber pool;
	# this adds no light, collision, or extra fixture elsewhere in the room.
	var lamp := bench.get_node_or_null("M16BenchWallLamp") as Sprite2D
	if lamp == null:
		lamp = Sprite2D.new()
		lamp.name = "M16BenchWallLamp"
		bench.add_child(lamp)
	var region: Rect2 = INTERACTION_REGIONS.wall_lamp
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	atlas.filter_clip = true
	var dimensions := Vector2(region.size.x / region.size.y * 65.0, 65.0)
	lamp.texture = atlas
	lamp.centered = false
	lamp.position = Vector2(-dimensions.x / 2.0, -72.0 - dimensions.y)
	lamp.scale = dimensions / region.size
	lamp.modulate = Color(0.78, 0.78, 0.78)
	lamp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	lamp.z_index = -1

static func _skin_gate(gate: Node2D, texture: Texture2D, region: Rect2) -> void:
	var art := gate.get_node_or_null("M16GateArtwork") as GateArtwork
	if art == null:
		art = GateArtwork.new()
		art.name = "M16GateArtwork"
		gate.add_child(art)
	art.gate = gate
	art.texture = texture
	art.source_rect = region
	art.frame_fractions = GATE_FRAME_FRACTIONS
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# self_modulate affects this item's drawing only, not child CanvasItems.
	var hidden_color := gate.self_modulate
	hidden_color.a = 0.0
	gate.self_modulate = hidden_color
	art.queue_redraw()

static func _skin_surfaces(node: Node, stone: Texture2D, counts: Dictionary) -> void:
	var script: Script = node.get_script()
	if script:
		if script.resource_path == PLATFORM_SCRIPT:
			node.set("texture", stone)
			node.set("source_rect", PLATFORM_REGION)
			node.set("support_source_rect", SUPPORT_REGION)
			(node as CanvasItem).queue_redraw()
			counts.platforms += 1
		elif script.resource_path == LIFT_SCRIPT:
			node.set("texture", stone)
			node.set("source_rect", PLATFORM_REGION)
			(node as CanvasItem).queue_redraw()
			counts.moving_surfaces += 1
	for child in node.get_children(): _skin_surfaces(child, stone, counts)

static func _texture(filename: String, counts: Dictionary) -> Texture2D:
	var path := ART_ROOT + filename
	if not ResourceLoader.exists(path):
		counts.missing_assets.append(path)
		return null
	return load(path) as Texture2D

static func _valid_region(texture: Texture2D, region: Rect2) -> bool:
	return texture != null and region.size.x > 0.0 and region.size.y > 0.0 and Rect2(Vector2.ZERO, texture.get_size()).encloses(region)
