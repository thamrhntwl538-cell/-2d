extends Node2D
## Visual-only dedicated Archive Keeper room. World origin remains (0,0).
## Draw above the old approach backdrop and below combat actors (z4 / z5).
const BACKDROP_PATH := "res://assets/environments/m27_archivist/sealed_catalog_vault.png"
const SOURCE_SIZE := Vector2(1672,941)
const SOURCE_FLOOR_Y := 806.5
const WORLD_LEFT := 705.0
const VIEW_WIDTH := 1280.0
const FLOOR_Y := 620.0
const ART_SCALE := VIEW_WIDTH / SOURCE_SIZE.x
const ART_TOP := FLOOR_Y - SOURCE_FLOOR_Y * ART_SCALE
const LEFT_FEATHER := 120.0
const LAMP_POINTS := [Vector2(1035.72,225.36),Vector2(1658.11,226.12)]

class Ambience extends Node2D:
	var room: Node2D
	func _draw() -> void:
		if room == null:
			return
		var t: float = room.elapsed
		for index in range(LAMP_POINTS.size()):
			var lamp: Vector2 = LAMP_POINTS[index]
			var pulse := .45 + .02 * sin(t * 1.25 + index * 2.1) + .012 * sin(t * 2.7 + index)
			draw_texture_rect(room._lamp_glow,Rect2(lamp-Vector2(64,83),Vector2(128,166)),false,Color(1,1,1,pulse))
		# Few small illuminated dust motes, always behind the combat actors.
		# Deterministic motion avoids restart flicker and consumes no scene RNG.
		for index in range(18):
			var phase := float(index) * 2.399963
			var base_x := 827.0 + fposmod(float(index) * 73.29,1000.0)
			var base_y := 149.0 + fposmod(float(index) * 67.83,395.0)
			var p := Vector2(base_x + sin(t * .12 + phase) * 11.0,base_y + sin(t * .09 + phase * 1.7) * 7.0)
			var alpha := .045 + .045 * (.5 + .5 * sin(t * .37 + phase))
			draw_circle(p,.65 + float(index % 3) * .2,Color(.74,.56,.34,alpha),true,-1,true)

var elapsed := 0.0
var paused := false
var background: Sprite2D
var _ambience: Ambience
var _lamp_glow: GradientTexture2D

func _ready() -> void:
	z_index = 1
	setup()

func setup() -> void:
	if is_instance_valid(background):
		return
	var source := Image.load_from_file(BACKDROP_PATH)
	if source == null:
		push_error("Archive Keeper arena background could not be read")
		return
	background = Sprite2D.new()
	background.name = "SealedCatalogVault"
	background.texture = ImageTexture.create_from_image(source)
	background.centered = false
	background.position = Vector2(WORLD_LEFT,ART_TOP)
	background.scale = Vector2.ONE * ART_SCALE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float left_feather = 0.09375;
uniform float top_feather = 0.0035;
void fragment() {
 vec4 paint = texture(TEXTURE,UV);
 paint.a *= smoothstep(0.0,left_feather,UV.x) * smoothstep(0.0,top_feather,UV.y);
 COLOR = paint;
}
"""
	var blend := ShaderMaterial.new()
	blend.shader = shader
	background.material = blend
	add_child(background)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,.24,.62,1.0])
	gradient.colors = PackedColorArray([Color(1.0,.52,.12,.13),Color(1.0,.43,.08,.055),Color(.85,.28,.04,.015),Color(.6,.2,.01,0)])
	_lamp_glow = GradientTexture2D.new()
	_lamp_glow.width = 128
	_lamp_glow.height = 128
	_lamp_glow.gradient = gradient
	_lamp_glow.fill = GradientTexture2D.FILL_RADIAL
	_lamp_glow.fill_from = Vector2(.5,.5)
	_lamp_glow.fill_to = Vector2(1,.5)
	_ambience = Ambience.new()
	_ambience.name = "QuietArchiveAir"
	_ambience.room = self
	add_child(_ambience)
	queue_redraw()

func _process(delta: float) -> void:
	if not paused:
		elapsed += delta
		if is_instance_valid(_ambience):
			_ambience.queue_redraw()

func set_paused(value: bool) -> void:
	paused = value

func _draw() -> void:
	# The original painting is uniformly scaled and lowered until its actual
	# painted floor edge equals worldy620. A dark ceiling cap fills the space
	# above it, with the same gradual entrance blend as the arena art.
	var ceiling := Color("05070e")
	for strip in range(64):
		var x := WORLD_LEFT + float(strip) * VIEW_WIDTH / 64.0
		var center_x := x - WORLD_LEFT + VIEW_WIDTH / 128.0
		ceiling.a = smoothstep(0.0,LEFT_FEATHER,center_x)
		draw_rect(Rect2(x,0,VIEW_WIDTH/64.0+1.0,ART_TOP+5.0),ceiling)

func get_arena_snapshot() -> Dictionary:
	return {
		"dedicated_archivist_arena":true,
		"visual_only":true,
		"source":BACKDROP_PATH,
		"source_size":SOURCE_SIZE,
		"world_view":Rect2(WORLD_LEFT,0,VIEW_WIDTH,720),
		"world_origin":Vector2.ZERO,
		"floor_y":FLOOR_Y,
		"painted_floor_y":ART_TOP+SOURCE_FLOOR_Y*ART_SCALE,
		"art_scale":Vector2.ONE*ART_SCALE,
		"art_top":ART_TOP,
		"left_transition_width":LEFT_FEATHER,
		"lights":LAMP_POINTS,
		"elapsed":elapsed,
		"paused":paused,
		"dust_motes":18,
		"background_loaded":is_instance_valid(background) and background.texture != null,
	}
