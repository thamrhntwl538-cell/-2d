extends "res://scripts/stage/m15_room_visuals.gd"
## M16: quieter painted spaces. Geometry and hero remain owned by the stage.
## This helper adds no lights: the controller places the few actual light pools.

const M16_ART := "res://assets/environments/polished_wing/"
# Tight main-art cutouts, reviewed against alpha bounds of the generated atlas.
const M16_PROP_REGIONS := {
	"desk":Rect2(68, 159, 601, 310),
	"bookshelf":Rect2(697, 10, 309, 455),
	"server":Rect2(1123, 10, 395, 475),
	"machine":Rect2(42, 468, 603, 525),
	"core":Rect2(687, 465, 307, 510),
	"banner":Rect2(1075, 510, 388, 480)
}
const NOTICE_PAPERS := Rect2(1100, 135, 360, 215)

func setup(world: Node2D, room_definition: Dictionary) -> void:
	super.setup(world, room_definition)
	# Base setup owns deterministic particle placement; retain less than half.
	if dust.size() > 20: dust.resize(20)
	queue_redraw()

func _background_path() -> String:
	match mood:
		"corridor", "aftermath": return M16_ART + "corridor.png"
		"lab": return M16_ART + "lab.png"
		"archive": return M16_ART + "archive.png"
		"input", "process": return M16_ART + "machinery.png"
		"output": return M16_ART + "vault.png"
		"tribunal": return M16_ART + "tribunal.png"
	return M16_ART + "entrance.png"

func _far_tint() -> Color:
	match mood:
		"archive": return Color(0.68, 0.71, 0.74)
		"input": return Color(0.69, 0.70, 0.69)
		"output": return Color(0.65, 0.74, 0.76)
		"approach": return Color(0.56, 0.62, 0.70)
		"tribunal": return Color(0.63, 0.69, 0.76)
		"aftermath": return Color(0.75, 0.75, 0.71)
	return Color(0.65, 0.72, 0.78)

func _build_arches() -> void:
	# The paintings already establish the room volumes. Repeating the gilded
	# M15 arch atlas here would fill the negative space and compete with them.
	pass

func _build_foreground_corners() -> void:
	# Keep the upper silhouette and HUD clear; no old gold corner decoration.
	pass

func _prop(kind: String, foot: Vector2, size: Vector2, tint := Color(0.65, 0.70, 0.73)) -> Sprite2D:
	var source_texture: Texture2D = props
	var region: Rect2
	if kind == "notices":
		source_texture = kit
		# Reuse the painted papers without the ornate bronze frame.
		region = NOTICE_PAPERS
	elif M16_PROP_REGIONS.has(kind):
		region = M16_PROP_REGIONS[kind]
	else:
		return null
	if source_texture == null: return null
	var atlas := AtlasTexture.new()
	atlas.atlas = source_texture
	atlas.region = region
	atlas.filter_clip = true
	var sprite := Sprite2D.new()
	sprite.name = "Quiet" + kind.capitalize().replace(" ", "")
	sprite.texture = atlas
	sprite.centered = false
	sprite.position = foot - Vector2(size.x / 2.0, size.y)
	sprite.scale = size / region.size
	sprite.modulate = tint
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.z_index = -3
	add_child(sprite)
	return sprite

func _build_dressing() -> void:
	props = _load_texture(M16_ART + "props.png")
	# A few grounded academic objects give scale and identity. Open landing lips,
	# elevator clearances and the tribunal's centre are left to the real geometry.
	match mood:
		"entrance":
			_add_screen("desk", Vector2(510, route_y), Vector2(220, 140))
			_prop("notices", Vector2(450, route_y-235), Vector2(162, 97), Color(0.58, 0.62, 0.63))
			_prop("server", Vector2(room_size.x-770, route_y), Vector2(80, 183), Color(0.58, 0.64, 0.68))
		"corridor":
			_prop("notices", Vector2(570, route_y-220), Vector2(170, 102), Color(0.57, 0.61, 0.63))
			_add_screen("desk", Vector2(minf(1690, room_size.x-430), route_y), Vector2(220, 140))
			_prop("banner", Vector2(room_size.x-360, route_y-300), Vector2(80, 200), Color(0.53, 0.58, 0.62))
		"lab":
			_add_screen("desk", Vector2(500, route_y), Vector2(240, 153))
			_prop("server", Vector2(room_size.x-390, route_y), Vector2(105, 240), Color(0.58, 0.65, 0.70))
			_add_screen("desk", Vector2(1360, floor_y), Vector2(220, 140))
		"archive":
			_prop("bookshelf", Vector2(620, floor_y), Vector2(165, 280), Color(0.57, 0.63, 0.67))
			_prop("bookshelf", Vector2(1740, 1980), Vector2(170, 288), Color(0.59, 0.64, 0.68))
			_prop("bookshelf", Vector2(620, 1260), Vector2(165, 280), Color(0.57, 0.63, 0.67))
			_prop("bookshelf", Vector2(1740, 660), Vector2(170, 288), Color(0.59, 0.64, 0.68))
			_prop("notices", Vector2(620, 1980-225), Vector2(144, 86), Color(0.56, 0.61, 0.64))
			_prop("banner", Vector2(2040, 1260-280), Vector2(74, 185), Color(0.52, 0.57, 0.62))
		"input":
			_prop("machine", Vector2(room_size.x*0.68, route_y), Vector2(250, 250), Color(0.66, 0.68, 0.65))
			_add_screen("desk", Vector2(290, route_y), Vector2(190, 121))
		"process":
			var machine_x := room_size.x*0.68
			_prop("machine", Vector2(machine_x, route_y), Vector2(270, 270), Color(0.59, 0.66, 0.69))
			active_gear_centres.append(Vector2(machine_x, route_y-150))
			_prop("server", Vector2(room_size.x*0.30, route_y), Vector2(96, 219), Color(0.56, 0.62, 0.67))
		"output":
			# Hang from beneath the upper walkway, clear of its opaque stone face.
			var core := _prop("core", Vector2(room_size.x*0.5+270, route_y-45), Vector2(150, 249), Color(0.64, 0.77, 0.79))
			if core: floating_cores.append({"sprite":core, "base":core.position, "phase":0.0})
			_prop("machine", Vector2(room_size.x*0.5, route_y), Vector2(270, 220), Color(0.57, 0.65, 0.68))
		"approach":
			_prop("banner", Vector2(520, route_y-280), Vector2(95, 238), Color(0.49, 0.54, 0.61))
			_prop("notices", Vector2(room_size.x-600, route_y-210), Vector2(150, 90), Color(0.51, 0.57, 0.61))
		"tribunal":
			# The painted projector and lecture seating carry the academic identity.
			# A single side banner leaves the entire future fight floor readable.
			_prop("banner", Vector2(280, route_y-325), Vector2(105, 263), Color(0.55, 0.60, 0.66))
		"aftermath":
			_prop("bookshelf", Vector2(room_size.x*0.70, route_y), Vector2(140, 237), Color(0.67, 0.68, 0.64))
			_prop("notices", Vector2(410, route_y-200), Vector2(144, 86), Color(0.64, 0.66, 0.63))

func _add_screen(kind: String, foot: Vector2, size: Vector2) -> void:
	var screen := _prop(kind, foot, size, Color(0.62, 0.69, 0.72))
	if screen: screen_sprites.append(screen)

func _draw() -> void:
	if definition.is_empty(): return
	draw_rect(Rect2(0, floor_y+85, room_size.x, maxf(0, room_size.y-floor_y-85)), Color("060c12"))
	# The new paintings provide local window shafts. No repeated full-room
	# procedural ray triangles are layered over their quiet dark areas.
	if mood in ["entrance", "corridor", "lab", "process"]:
		for i in range(2):
			var x := 220.0 if i == 0 else room_size.x-480.0
			var points := PackedVector2Array()
			for j in range(20):
				var u := float(j)/19.0
				points.append(Vector2(x+u*210.0, route_y-380.0+sin(u*PI)*43.0+sin(elapsed*0.4+i)*1.4))
			draw_polyline(points, Color(0.045, 0.07, 0.09, 0.72), 2.0, true)
	for particle in dust:
		var point: Vector2 = particle.base
		point.x += sin(elapsed*0.16+float(particle.phase))*10.0
		point.y = 80.0+fposmod(point.y-80.0-elapsed*float(particle.speed)*0.65, maxf(100, floor_y-100))
		var alpha := 0.04+(sin(elapsed*0.6+float(particle.phase))+1.0)*0.035
		draw_circle(point, 0.85, Color(0.64, 0.70, 0.74, alpha))
	if mood in ["entrance", "corridor", "lab", "aftermath"]:
		for x in [300.0, room_size.x-440.0]:
			draw_line(Vector2(x, floor_y+4.0), Vector2(x+38.0, floor_y+4.0), Color(0.48, 0.59, 0.63, 0.065), 1.2, true)
	var paper := Vector2(room_size.x*0.39+sin(elapsed*0.22)*22.0, 180.0+fposmod(elapsed*5.5, maxf(180, floor_y-240)))
	draw_set_transform(paper, sin(elapsed*0.36)*0.42)
	draw_rect(Rect2(-2.5, -1.7, 5, 3.4), Color(0.59, 0.60, 0.56, 0.10))
	draw_set_transform(Vector2.ZERO)
	for centre in active_gear_centres:
		draw_arc(centre, 36.0, elapsed*0.12, elapsed*0.12+PI*1.6, 36, Color(0.39, 0.54, 0.59, 0.075), 1.0, true)
