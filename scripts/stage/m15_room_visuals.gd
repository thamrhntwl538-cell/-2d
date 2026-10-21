extends Node2D
## Layered environment dressing. All nodes here are non-solid.
## Painted PNGs supply architecture/props; supporting atmosphere is procedural.

const OLD_KIT_PATH := "res://assets/environments/silent_entrance/academic_kit.png"
const ARCH_PATH := "res://assets/environments/silent_entrance/academic_arch.png"
const ENTRANCE_PATH := "res://assets/environments/silent_entrance/distant_academy.png"
const NEW_ART := "res://assets/environments/forgotten_wing/"
const OLD_REGIONS := {
	"locker":Rect2(726, 24, 210, 452),
	"notices":Rect2(1063, 26, 440, 411),
	"bench":Rect2(53, 720, 605, 214),
	"terminal":Rect2(721, 507, 216, 458)
}
# Atlas cutouts are kept here so artists can replace or refine the individual art.
const PROP_REGIONS := {
	"desk":Rect2(9, 150, 674, 336),
	"bookshelf":Rect2(730, 10, 348, 490),
	"server":Rect2(1184, 5, 310, 499),
	"machine":Rect2(63, 506, 549, 495),
	"core":Rect2(714, 499, 270, 497),
	"banner":Rect2(1104, 514, 423, 510)
}

var world_ref: Node2D
var definition: Dictionary = {}
var room_size := Vector2(2400, 1440)
var floor_y: float = 1260.0
var route_y: float = 1260.0
var mood: String = "entrance"
var elapsed: float = 0.0
var kit: Texture2D
var props: Texture2D
var background: Texture2D
var far_sprites: Array[Sprite2D] = []
var arch_sprites: Array[Sprite2D] = []
var foreground_sprites: Array[Sprite2D] = []
var floating_cores: Array[Dictionary] = []
var screen_sprites: Array[Sprite2D] = []
var dust: Array[Dictionary] = []
var active_gear_centres: Array[Vector2] = []

func setup(world: Node2D, room_definition: Dictionary) -> void:
	world_ref = world
	definition = room_definition
	room_size = definition.get("size", Vector2(2400, 1440))
	floor_y = float(definition.get("floor_y", room_size.y-180.0))
	route_y = float(definition.get("route_y", definition.get("mainroute_y", floor_y)))
	mood = str(definition.get("mood", "entrance"))
	kit = _load_texture(OLD_KIT_PATH)
	props = _load_texture(NEW_ART + "props.png")
	background = _load_texture(_background_path())
	if background == null: background = _load_texture(ENTRANCE_PATH)
	_build_far_layer()
	_build_arches()
	_build_dressing()
	_build_foreground_corners()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1500 + int(definition.get("room_id", definition.get("id", 0)))
	for i in range(42):
		dust.append({"base":Vector2(rng.randf_range(0, room_size.x), rng.randf_range(80, floor_y-24)), "phase":rng.randf_range(0, TAU), "speed":rng.randf_range(2.0, 6.0)})
	_update_layers()
	queue_redraw()

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path): return load(path) as Texture2D
	return null

func _background_path() -> String:
	match mood:
		"lab", "input", "process": return NEW_ART + "lab.png"
		"archive": return NEW_ART + "archive.png"
		"output", "approach", "tribunal", "aftermath": return NEW_ART + "tribunal.png"
	return ENTRANCE_PATH

func _far_tint() -> Color:
	match mood:
		"lab": return Color(0.63, 0.76, 0.80)
		"archive": return Color(0.76, 0.77, 0.77)
		"input": return Color(0.75, 0.74, 0.69)
		"process": return Color(0.61, 0.72, 0.76)
		"output": return Color(0.66, 0.77, 0.78)
		"approach": return Color(0.55, 0.60, 0.69)
		"tribunal": return Color(0.70, 0.75, 0.82)
		"aftermath": return Color(0.85, 0.83, 0.74)
	return Color(0.72, 0.80, 0.88)

func _build_far_layer() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DistantAcademicSpace"
	layer.layer = -20
	add_child(layer)
	for i in range(3):
		var sprite := Sprite2D.new()
		sprite.texture = background
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.modulate = _far_tint()
		layer.add_child(sprite)
		far_sprites.append(sprite)

func _build_arches() -> void:
	# The tribunal painting already carries its monumental columns and central
	# projection screen. Keep that centre open for the arena and future boss.
	if mood == "tribunal": return
	var texture := _load_texture(ARCH_PATH)
	if texture == null: return
	var rows := maxi(1, ceili(room_size.y / 1450.0))
	var columns := ceili(room_size.x / 1420.0)+1
	for row in range(rows):
		for column in range(columns):
			var arch := Sprite2D.new()
			arch.texture = texture
			arch.centered = false
			arch.scale = Vector2(0.98, 1.16)
			arch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			arch.modulate = Color(0.56, 0.64, 0.72, 0.48 if mood in ["lab", "process"] else 0.64)
			arch.z_index = -8
			arch.set_meta("base_position", Vector2(-1120+column*1420, 82+row*1450))
			add_child(arch)
			arch_sprites.append(arch)

func _prop(kind: String, foot: Vector2, size: Vector2, tint := Color(0.71, 0.77, 0.80)) -> Sprite2D:
	var source_texture: Texture2D = kit if OLD_REGIONS.has(kind) else props
	if source_texture == null: return null
	var region: Rect2 = OLD_REGIONS.get(kind, PROP_REGIONS.get(kind, Rect2(0, 0, 512, 512)))
	var atlas := AtlasTexture.new()
	atlas.atlas = source_texture
	atlas.region = region
	atlas.filter_clip = true
	var sprite := Sprite2D.new()
	sprite.name = kind.capitalize().replace(" ", "")
	sprite.texture = atlas
	sprite.centered = false
	sprite.position = foot - Vector2(size.x/2.0, size.y)
	sprite.scale = size / region.size
	sprite.modulate = tint
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.z_index = -3
	add_child(sprite)
	return sprite

func _old_equipment(x: float, y: float) -> void:
	var screen := _prop("locker", Vector2(x,y), Vector2(83,180))
	if screen: screen_sprites.append(screen)

func _build_dressing() -> void:
	match mood:
		"entrance":
			for x in [105.0, 530.0, 2845.0, 3000.0]: _old_equipment(x, route_y)
			_prop("notices", Vector2(495, route_y-210), Vector2(230,215))
			_prop("notices", Vector2(2110, 727), Vector2(190,178))
		"corridor":
			for x in [400.0, 1320.0, 2180.0]:
				if x < room_size.x-160:
					_prop("notices", Vector2(x, route_y-180), Vector2(220,205))
			for x in [160.0, 930.0, 1860.0]:
				if x < room_size.x-150: _old_equipment(x, route_y)
			_prop("banner", Vector2(room_size.x*0.63, route_y-300), Vector2(105,260), Color(0.66,0.67,0.67))
		"lab":
			for x in [500.0, 2440.0]:
				var desk := _prop("desk", Vector2(x, route_y), Vector2(260,155))
				if desk: screen_sprites.append(desk)
			_prop("desk", Vector2(1360, floor_y), Vector2(280,168), Color(0.58,0.65,0.68))
			_prop("server", Vector2(room_size.x-390, route_y), Vector2(140,300))
			_prop("server", Vector2(865, floor_y), Vector2(126,270), Color(0.58,0.65,0.70))
			_prop("notices", Vector2(430, route_y-225), Vector2(180,168), Color(0.65,0.71,0.73))
		"archive":
			for level in [floor_y, 1980.0, 1260.0, 660.0]:
				_prop("bookshelf", Vector2(620, level), Vector2(192,315), Color(0.62,0.68,0.72))
				_prop("bookshelf", Vector2(1740, level), Vector2(210,345), Color(0.63,0.69,0.73))
				_prop("banner", Vector2(2040, level-215), Vector2(90,225), Color(0.58,0.62,0.67))
			_old_equipment(210, floor_y)
		"input":
			_prop("machine", Vector2(room_size.x*0.68, route_y), Vector2(300,300), Color(0.76,0.72,0.65))
			_old_equipment(250, route_y)
			_prop("banner", Vector2(room_size.x*0.5, route_y-260), Vector2(120,300))
		"process":
			for x in [520.0, room_size.x-600.0]:
				_prop("machine", Vector2(x, route_y), Vector2(330,330), Color(0.63,0.72,0.75))
				active_gear_centres.append(Vector2(x, route_y-175))
			_prop("server", Vector2(room_size.x*0.52, route_y), Vector2(155,330), Color(0.64,0.68,0.72))
		"output":
			var core := _prop("core", Vector2(room_size.x*0.5, route_y-160), Vector2(220,280), Color(0.72,0.83,0.82))
			if core: floating_cores.append({"sprite":core,"base":core.position,"phase":0.0})
			_prop("machine", Vector2(room_size.x*0.5, route_y), Vector2(390,300), Color(0.64,0.71,0.73))
			for x in [280.0, room_size.x-280.0]: _old_equipment(x, route_y)
		"approach":
			for x in [420.0, 1120.0, 1810.0, 2500.0]:
				if x < room_size.x-150:
					_prop("banner", Vector2(x, route_y-250), Vector2(130,325), Color(0.52,0.57,0.64))
			_prop("notices", Vector2(room_size.x*0.53, route_y-180), Vector2(195,182), Color(0.55,0.58,0.62))
		"tribunal":
			for x in [300.0, room_size.x-300.0]:
				_prop("banner", Vector2(x, route_y-330), Vector2(150,375), Color(0.67,0.69,0.72))
			var tribunal_core := _prop("core", Vector2(room_size.x*0.50, route_y-420), Vector2(150,190), Color(0.62,0.76,0.82))
			if tribunal_core: floating_cores.append({"sprite":tribunal_core,"base":tribunal_core.position,"phase":1.4})
		"aftermath":
			_prop("bookshelf", Vector2(room_size.x*0.70, route_y), Vector2(160,263), Color(0.78,0.76,0.69))
			_prop("banner", Vector2(room_size.x*0.42, route_y-170), Vector2(100,250), Color(0.81,0.77,0.65))
			_prop("notices", Vector2(410, route_y-180), Vector2(180,168), Color(0.77,0.76,0.68))

func _build_foreground_corners() -> void:
	var texture := _load_texture(ARCH_PATH)
	if texture == null: return
	var layer := CanvasLayer.new()
	layer.name = "NearUpperCornerFraming"
	layer.layer = 4
	add_child(layer)
	for i in range(2):
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0 if i == 0 else 1216, 0, 320, 165)
		sprite.modulate = Color(0.15,0.20,0.25,0.24)
		layer.add_child(sprite)
		foreground_sprites.append(sprite)

func _process(_delta: float) -> void:
	if not is_instance_valid(world_ref): return
	elapsed = float(world_ref.get("elapsed"))
	_update_layers()
	for i in range(screen_sprites.size()):
		screen_sprites[i].self_modulate = Color.WHITE * (0.94+sin(elapsed*2.8+i*2.2)*0.03)
	for record in floating_cores:
		var sprite: Sprite2D = record.sprite
		sprite.position = record.base + Vector2(0, sin(elapsed*0.8+float(record.phase))*4.0)
	queue_redraw()

func _update_layers() -> void:
	if not is_instance_valid(world_ref): return
	var view := get_viewport_rect().size
	var camera: Camera2D = world_ref.get("camera")
	var camera_point := camera.position if camera else Vector2.ZERO
	if background:
		var tex_size := background.get_size()
		var texture_scale := maxf(view.x/tex_size.x*1.44, view.y/tex_size.y*1.44)
		var tile_size := tex_size*texture_scale
		var vertical_excess := maxf(0.0,tile_size.y-view.y)
		var y_offset := -vertical_excess*(0.4+clampf(camera_point.y/room_size.y,0,1)*0.18)
		for i in range(far_sprites.size()):
			far_sprites[i].scale = Vector2.ONE*texture_scale
			far_sprites[i].position = Vector2(-fposmod(camera_point.x*0.12,tile_size.x)+(i-1)*tile_size.x,y_offset)
	for arch in arch_sprites:
		arch.position = arch.get_meta("base_position") + camera_point*Vector2(0.22,0.07)
	for i in range(foreground_sprites.size()):
		foreground_sprites[i].position = Vector2(-125 if i == 0 else view.x-195, -65)

func _draw() -> void:
	if definition.is_empty(): return
	# Support shade below the painted ground; no collision is created here.
	draw_rect(Rect2(0,floor_y+85,room_size.x,maxf(0,room_size.y-floor_y-85)), Color("080f16"))
	for i in range(ceili(room_size.x/620.0)):
		var x := 260.0+i*620.0
		var rays := PackedVector2Array([Vector2(x,80),Vector2(x+40,80),Vector2(x+260,floor_y-10),Vector2(x+130,floor_y-10)])
		draw_colored_polygon(rays,Color(0.45,0.55,0.63,0.016 if mood != "aftermath" else 0.024))
	if mood in ["entrance","corridor","lab","input","process","approach"]:
		for i in range(ceili(room_size.x/470.0)):
			var x := 180.0+i*470.0
			var points := PackedVector2Array()
			for j in range(18):
				var u := float(j)/17.0
				points.append(Vector2(x+u*235,route_y-380+sin(u*PI)*65+sin(elapsed*0.5+i)*2))
			draw_polyline(points,Color("111b25"),3.0,true)
	for particle in dust:
		var point: Vector2 = particle.base
		point.x += sin(elapsed*0.18+float(particle.phase))*14.0
		point.y = 80.0+fposmod(point.y-80.0-elapsed*float(particle.speed),maxf(100,floor_y-100))
		var alpha := 0.08+(sin(elapsed*0.7+float(particle.phase))+1)*0.065
		draw_circle(point,1.0,Color(0.72,0.77,0.79,alpha))
	for i in range(ceili(room_size.x/340.0)):
		var px := 120.0+i*340
		draw_line(Vector2(px,floor_y+4),Vector2(px+50,floor_y+4),Color(0.55,0.65,0.67,0.14),1.5,true)
	for i in range(3):
		var point := Vector2(540+i*740+sin(elapsed*0.28+i)*28,180+fposmod(elapsed*8+i*290,maxf(180,floor_y-240)))
		draw_set_transform(point,sin(elapsed*0.45+i)*0.5)
		draw_rect(Rect2(-3,-2,6,4),Color(0.65,0.64,0.55,0.18))
		draw_set_transform(Vector2.ZERO)
	for centre in active_gear_centres:
		draw_arc(centre,45,elapsed*0.2,elapsed*0.2+PI*1.8,44,Color(0.48,0.65,0.67,0.16),1.3,true)
