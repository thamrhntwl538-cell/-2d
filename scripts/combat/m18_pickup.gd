extends Node2D
## Original brass/ivory combat discoveries. The stage owns range checks, rewards,
## persistence and pogo responses; this node is presentation plus a strike target.
const INK := Color("142633")
const GOLD := Color("b98e4e")
const GOLD_LIGHT := Color("e4c48c")
const IVORY := Color("f0e2c4")
const CYAN := Color("78d5da")
const FONT = preload("res://assets/fonts/DejaVuSans.ttf")
const POGO_RECT := Rect2(-25.0, -45.0, 50.0, 40.0)

var world_ref: Node2D
var definition: Dictionary = {}
var id: String = ""
var kind: String = "fitil_pickup"
var elapsed: float = 0.0
var highlighted: bool = false

func setup(world: Node2D, data: Dictionary) -> void:
	world_ref = world
	definition = data.duplicate(true)
	id = str(data.get("id", ""))
	kind = str(data.get("kind", "fitil_pickup"))
	position = data.get("pos", Vector2.ZERO)
	z_index = 3
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()

func _process(delta: float) -> void:
	if not is_instance_valid(world_ref) or not bool(world_ref.get("gameplay_active")):
		return
	elapsed = fposmod(elapsed + delta, TAU * 12.0)
	var hero: Variant = world_ref.get("hero")
	highlighted = is_instance_valid(hero) and global_position.distance_to(hero.global_position) <= 100.0
	queue_redraw()

func get_hitbox() -> Rect2:
	# In particular, the hinge never floats with its decorative glow.
	return Rect2(global_position + POGO_RECT.position, POGO_RECT.size) if kind == "pogo_anchor" else Rect2()

func visual_size() -> Vector2:
	return Vector2(68, 62) if kind == "pogo_anchor" else Vector2(68, 82)

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(elapsed * 2.2)
	if kind == "pogo_anchor":
		_draw_anchor(pulse)
		return
	var bob := sin(elapsed * 1.8) * 2.6
	var center := Vector2(0, -32 + bob)
	_ellipse(Vector2(0, 1), Vector2(23, 4), Color(INK, 0.4))
	_glow(center, 29.0, pulse)
	if kind == "currency_drop":
		_draw_currency(center)
		return
	_frame(center, pulse)
	match kind:
		"dash_pickup": _draw_dash(center)
		"spell_pickup": _draw_spell(center)
		"capacity_pickup": _draw_capacity(center)
		_: _draw_fitil(center)
	# A few quiet motes keep discoveries visible against painted backgrounds.
	for i in range(3):
		var phase := elapsed * 0.42 + i * 2.1
		var p := center + Vector2(sin(phase) * (23 + i * 2), -22 - cos(phase * 0.7) * 8)
		draw_circle(p, 0.9 if i != 1 else 1.3, Color(IVORY, 0.2 + pulse * 0.2), true, -1.0, true)

func _glow(center: Vector2, radius: float, pulse: float) -> void:
	var emphasis := 1.35 if highlighted else 1.0
	for ring in range(4, 0, -1):
		var fraction := float(ring) / 4.0
		draw_circle(center, radius * fraction, Color(CYAN, (0.025 + pulse * 0.013) * emphasis), true, -1.0, true)

func _frame(center: Vector2, pulse: float) -> void:
	draw_circle(center, 22.0, Color(INK, 0.85), true, -1.0, true)
	draw_arc(center, 22.0, 0.0, TAU, 56, GOLD, 1.5, true)
	draw_arc(center, 19.0, -PI * 0.88, -PI * 0.12, 28, Color(GOLD_LIGHT, 0.65), 0.7, true)
	draw_arc(center, 25.5, -PI * 0.84, -PI * 0.16, 24, Color(CYAN, 0.17 + pulse * 0.12), 1.0, true)
	for direction in [-1.0, 1.0]:
		var p := center + Vector2(direction * 22.0, 0)
		draw_circle(p, 2.1, GOLD_LIGHT, true, -1.0, true)
	# An ivory notch and hanging brass pin make this a crafted object, not a UI orb.
	draw_line(center + Vector2(-4, -22), center + Vector2(4, -22), IVORY, 2.0, true)
	draw_line(center + Vector2(0, 22), center + Vector2(0, 28), GOLD, 1.6, true)
	draw_circle(center + Vector2(0, 28), 1.8, GOLD_LIGHT, true, -1.0, true)

func _draw_dash(center: Vector2) -> void:
	for offset in [-7.0, 5.0]:
		var points := PackedVector2Array([center + Vector2(offset - 4, -9), center + Vector2(offset + 4, 0), center + Vector2(offset - 4, 9)])
		draw_polyline(points, CYAN, 3.1, true)
		draw_polyline(points, Color(IVORY, 0.75), 0.9, true)
	draw_line(center + Vector2(-15, 0), center + Vector2(-10, 0), GOLD_LIGHT, 1.3, true)

func _draw_spell(center: Vector2) -> void:
	_flame(center + Vector2(0, 9), 24, CYAN)
	for direction in [-1.0, 1.0]:
		draw_arc(center + Vector2(direction * 6, -1), 11, -0.6 if direction > 0 else PI - 0.6, 0.6 if direction > 0 else PI + 0.6, 14, GOLD_LIGHT, 1.0, true)
	draw_line(center + Vector2(-10, 12), center + Vector2(10, 12), GOLD, 1.8, true)

func _draw_fitil(center: Vector2) -> void:
	var points := PackedVector2Array()
	for i in range(33):
		var t := float(i) / 32.0
		var angle := -PI * 0.3 + t * TAU * 1.4
		var radius := 2.0 + t * 8.0
		points.append(center + Vector2(-1, 4) + Vector2(cos(angle), sin(angle)) * radius)
	draw_polyline(points, GOLD_LIGHT, 2.3, true)
	draw_line(center + Vector2(7, 6), center + Vector2(8, -5), IVORY, 1.6, true)
	_flame(center + Vector2(8, -4), 13.0, CYAN)

func _draw_capacity(center: Vector2) -> void:
	var cage := PackedVector2Array([center + Vector2(-12, 12), center + Vector2(-12, -6), center + Vector2(-6, -13), center + Vector2(6, -13), center + Vector2(12, -6), center + Vector2(12, 12), center + Vector2(-12, 12)])
	draw_polyline(cage, GOLD_LIGHT, 1.8, true)
	draw_line(center + Vector2(-5, 0), center + Vector2(5, 0), CYAN, 2.5, true)
	draw_line(center + Vector2(0, -5), center + Vector2(0, 5), CYAN, 2.5, true)
	for x in [-7.0, 0.0, 7.0]:
		draw_circle(center + Vector2(x, 9), 1.2, IVORY, true, -1.0, true)

func _draw_currency(center: Vector2) -> void:
	var body := PackedVector2Array([center + Vector2(-15, 8), center + Vector2(-18, -3), center + Vector2(-9, -14), center + Vector2(0, -18), center + Vector2(10, -13), center + Vector2(17, -2), center + Vector2(14, 9), center + Vector2(0, 15)])
	draw_colored_polygon(body, Color(INK, 0.94))
	var outline := body.duplicate()
	outline.append(outline[0])
	draw_polyline(outline, Color(GOLD, 0.95), 1.2, true)
	for offset in [Vector2(-7, 3), Vector2(1, 6), Vector2(7, -1)]:
		draw_circle(center + offset, 5.5, GOLD, true, -1.0, true)
		draw_arc(center + offset, 3.8, -PI, 0.5, 18, GOLD_LIGHT, 0.8, true)
	_flame(center + Vector2(-1, -3), 17.0, Color(CYAN, 0.9))
	var amount := int(definition.get("amount", 0))
	if amount > 0:
		var text := str(amount)
		var font_size := 12 if text.length() <= 5 else 10
		var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string_outline(FONT, Vector2(-width * 0.5, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, INK)
		draw_string(FONT, Vector2(-width * 0.5, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, IVORY)

func _draw_anchor(pulse: float) -> void:
	_glow(Vector2(0, -25), 29.0, pulse * 0.45)
	_ellipse(Vector2(0, 3), Vector2(31, 4.5), Color(INK, 0.6))
	# Rigid square shoulders and a continuous bright upper rim advertise contact.
	var frame := PackedVector2Array([Vector2(-30, 0), Vector2(-25, -5), Vector2(-25, -45), Vector2(-15, -45), Vector2(-15, -41), Vector2(15, -41), Vector2(15, -45), Vector2(25, -45), Vector2(25, -5), Vector2(30, 0)])
	draw_colored_polygon(frame, INK)
	draw_polyline(frame, GOLD, 2.7, true)
	draw_line(Vector2(-25, -45), Vector2(25, -45), GOLD_LIGHT, 4.2, true)
	draw_line(Vector2(-23, -46), Vector2(23, -46), IVORY, 1.4, true)
	draw_arc(Vector2(0, -24), 16, 0, TAU, 48, GOLD, 3.2, true)
	draw_arc(Vector2(0, -24), 12, PI * 1.1, PI * 1.9, 20, Color(IVORY, 0.85), 1.0, true)
	for x in [-25.0, 25.0]:
		draw_circle(Vector2(x, -8), 2.2, GOLD_LIGHT, true, -1.0, true)
	draw_line(Vector2(-9, -25), Vector2(0, -33), CYAN, 1.7, true)
	draw_line(Vector2(0, -33), Vector2(9, -25), CYAN, 1.7, true)
	draw_line(Vector2(0, -32), Vector2(0, -15), Color(CYAN, 0.8), 1.2, true)
	draw_line(Vector2(-29, 1), Vector2(29, 1), GOLD_LIGHT, 1.4, true)

func _flame(foot: Vector2, height: float, color: Color) -> void:
	var points := PackedVector2Array([
		foot + Vector2(0, 0), foot + Vector2(-height * 0.22, -height * 0.09),
		foot + Vector2(-height * 0.28, -height * 0.30), foot + Vector2(-height * 0.19, -height * 0.54),
		foot + Vector2(-height * 0.05, -height * 0.75), foot + Vector2(height * 0.02, -height),
		foot + Vector2(height * 0.13, -height * 0.77), foot + Vector2(height * 0.12, -height * 0.59),
		foot + Vector2(height * 0.23, -height * 0.45), foot + Vector2(height * 0.25, -height * 0.27),
		foot + Vector2(height * 0.17, -height * 0.09), foot
	])
	draw_colored_polygon(points, Color(color, color.a * 0.75))
	draw_polyline(points, color, 0.8, true)
	draw_line(foot + Vector2(0, -height * 0.12), foot + Vector2(height * 0.02, -height * 0.57), Color(IVORY, color.a), maxf(1.0, height * 0.08), true)

func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(40):
		var angle := TAU * float(i) / 40.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)
