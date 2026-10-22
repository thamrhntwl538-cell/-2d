extends Node2D
## Non-solid illustrated interaction objects. The world alone owns interaction
## range, puzzle panels, checkpoint writes, collision folds and story progress.

signal activated(id: String)

const PAPER := Color("e0ceab")
const PAPER_LIGHT := Color("f0e1bd")
const INK := Color("142633")
const GOLD := Color("b88e4a")
const CYAN := Color("75d0d3")
const RED := Color("792c36")
const FONT = preload("res://assets/fonts/DejaVuSans.ttf")

var definition: Dictionary = {}
var world_ref: Node2D
var id: String = ""
var kind: String = "terminal"
var label: String = ""
var active: bool = false
var can_repeat: bool = true
var elapsed: float = 0.0
var activation_pulse: float = 0.0
var highlighted: bool = false

func setup(world: Node2D, data: Dictionary) -> void:
	world_ref = world
	definition = data.duplicate(true)
	id = str(data.get("id", ""))
	kind = str(data.get("kind", "terminal"))
	label = str(data.get("text_key", id))
	position = data.get("pos", Vector2.ZERO)
	can_repeat = kind not in ["weapon", "book"]
	z_index = 2 if kind != "dialogue" else 1
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sync_state()

func _progress() -> Dictionary:
	if not is_instance_valid(world_ref):
		return {}
	var value: Variant = world_ref.get("progress")
	return value if value is Dictionary else {}

func sync_state() -> void:
	var progress: Dictionary = _progress()
	match kind:
		"weapon": active = bool(progress.get("weapon_owned", false))
		"book":
			var symbol := str(definition.get("symbol", definition.get("book_id", ""))).to_upper()
			active = progress.get("book_inventory", []).has(symbol)
		"note": active = progress.get("notes", []).has(id)
		"dialogue": active = bool(progress.get("black_flame_warning_seen", false))
		"ink_control": active = bool(progress.get("ink_route_solved", false))
		"process_control": active = bool(progress.get("book_order_verified", false))
		"output_control": active = bool(progress.get("output_open", false))
		"balance_control": active = bool(progress.get("balance_bridge_locked", false))
		"shortcut": active = bool(progress.get(str(definition.get("flag", "")), false))
		"secret_overlay": active = bool(progress.get("secret_S03_open", false))
		"secret_pop": active = bool(progress.get("secret_S06_open", false))
		"combat_socket": active = bool(progress.get("seal_registered", false))
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	activation_pulse = maxf(0.0, activation_pulse - delta * 1.5)
	if is_instance_valid(world_ref):
		var hero: Variant = world_ref.get("hero")
		highlighted = is_instance_valid(hero) and global_position.distance_to(hero.global_position) < 108.0
	sync_state()

func activate() -> bool:
	activation_pulse = 1.0
	activated.emit(id)
	sync_state()
	return true

func visual_size() -> Vector2:
	match kind:
		"bench": return Vector2(188, 80)
		"book": return Vector2(85, 115)
		"note": return Vector2(43, 55)
		"dialogue": return Vector2(174, 158)
		"weapon": return Vector2(90, 112)
		"process_control": return Vector2(230, 119)
		"balance_control": return Vector2(138, 155)
		"secret_overlay": return Vector2(137, 107)
		"secret_pop": return Vector2(150, 105)
	return Vector2(96, 125)

func _round_rect(rect: Rect2, color: Color, radius: int = 4, border: Color = Color.TRANSPARENT, border_width: int = 1) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(border_width if border.a > 0.0 else 0)
	draw_style_box(style, rect)

func _ellipse(center: Vector2, size: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(40):
		var angle := TAU * float(i) / 40.0
		points.append(center + Vector2(cos(angle), sin(angle)) * size)
	draw_colored_polygon(points, color)

func _glow(center: Vector2, radius: float, color: Color, alpha: float = 0.08) -> void:
	for i in range(5, 0, -1):
		var shade := Color(color, alpha * (1.0 - float(i - 1) / 6.0))
		draw_circle(center, radius * (0.3 + float(i) * 0.15), shade)

func _glyph(symbol: String, center: Vector2, radius: float, color: Color = PAPER_LIGHT, thickness: float = 2.0) -> void:
	match symbol.to_upper():
		"TRIANGLE", "△":
			var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, radius * 0.7), center + Vector2(-radius, radius * 0.7), center + Vector2(0, -radius)])
			draw_polyline(points, color, thickness, true)
		"SQUARE", "□": draw_rect(Rect2(center - Vector2.ONE * radius * 0.8, Vector2.ONE * radius * 1.6), color, false, thickness)
		"CIRCLE", "○": draw_arc(center, radius * 0.9, 0.0, TAU, 36, color, thickness, true)

func _book(foot: Vector2, size: Vector2, cover: Color, symbol: String = "", show_symbol: bool = true) -> void:
	var rect := Rect2(foot - Vector2(size.x * 0.5, size.y), size)
	_round_rect(Rect2(rect.position + Vector2(4, 4), size), Color(0.015, 0.025, 0.03, 0.52), 3)
	_round_rect(Rect2(rect.position + Vector2(3, 2), size - Vector2(2, 3)), PAPER, 3)
	for y in range(4, int(size.y) - 2, 4):
		draw_line(rect.position + Vector2(size.x - 2, y), rect.position + Vector2(size.x + 2, y), Color("a79b7c"), 0.7, true)
	_round_rect(Rect2(rect.position, size - Vector2(4, 4)), cover, 4, GOLD, 1)
	draw_line(rect.position + Vector2(7, 4), rect.position + Vector2(7, size.y - 8), Color(0.03, 0.035, 0.04, 0.8), 3.0, true)
	draw_rect(Rect2(rect.position + Vector2(11, 5), size - Vector2(21, 14)), Color(GOLD, 0.55), false, 0.8)
	if show_symbol and not symbol.is_empty():
		_glyph(symbol, rect.get_center() + Vector2(1, -1), minf(size.x, size.y) * 0.23)

func _stand() -> void:
	_ellipse(Vector2(0, 2), Vector2(45, 7), Color(0.015, 0.025, 0.035, 0.45))
	_round_rect(Rect2(-43, -14, 86, 12), INK, 2, GOLD, 1)
	draw_rect(Rect2(-34, -19, 68, 7), PAPER)
	for y in [-17, -14, -11]:
		draw_line(Vector2(-34, y), Vector2(34, y), Color("a99573"), 0.7, true)

func _draw_bench() -> void:
	_glow(Vector2(0, -24), 85, Color("e2aa52"), 0.045)
	_ellipse(Vector2(0, 4), Vector2(108, 10), Color(0.015, 0.025, 0.035, 0.48))
	for x in [-69, 69]:
		draw_line(Vector2(x, -10), Vector2(x - signf(float(x)) * 7.0, -50), GOLD, 5.0, true)
		draw_arc(Vector2(x, -54), 10, PI, TAU, 16, GOLD, 3.0, true)
	_round_rect(Rect2(-83, -63, 166, 32), Color("1b3041"), 9, GOLD, 2)
	draw_line(Vector2(-70, -48), Vector2(70, -48), Color("57616a"), 1.0, true)
	_round_rect(Rect2(-90, -34, 180, 15), Color("283d49"), 4, GOLD, 1)
	draw_rect(Rect2(-75, -31, 150, 4), PAPER)
	for x in [-57, 57]:
		draw_line(Vector2(x, -20), Vector2(x - signf(float(x)) * 10, -2), Color("8c6b3a"), 5.0, true)
	draw_line(Vector2(-64, -8), Vector2(64, -8), Color("6b5434"), 3.0, true)

func _draw_terminal(mode: String) -> void:
	_stand()
	_round_rect(Rect2(-23, -45, 46, 29), Color("514734"), 3, GOLD, 1)
	_round_rect(Rect2(-43, -112, 86, 70), Color("a99975"), 7, GOLD, 1)
	_round_rect(Rect2(-36, -105, 72, 49), Color("0b202a"), 5, Color("594f3e"), 2)
	for y in range(-101, -57, 4):
		draw_line(Vector2(-31, y), Vector2(31, y), Color(0.21, 0.7, 0.73, 0.035), 0.8)
	_glow(Vector2(0, -82), 29, CYAN, 0.04)
	var color := Color("c3e7db") if active else CYAN
	match mode:
		"ink":
			draw_polyline(PackedVector2Array([Vector2(-23,-87),Vector2(-11,-87),Vector2(-11,-72),Vector2(9,-72),Vector2(9,-87),Vector2(24,-87)]),color,2.5,true)
		"output":
			draw_polyline(PackedVector2Array([Vector2(-24,-68),Vector2(-10,-68),Vector2(-10,-79),Vector2(3,-79),Vector2(3,-90),Vector2(20,-90)]),color,2.0,true)
		"socket":
			draw_arc(Vector2(0,-82),14,0,TAU,28,GOLD,2.0,true)
			draw_line(Vector2(0,-96),Vector2(0,-68),color,1.5,true)
		_:
			var pivot := Vector2(-6, -81)
			draw_line(pivot, pivot + Vector2(15 if active else -15,-13), color, 3, true)
			draw_circle(pivot + Vector2(15 if active else -15,-13), 4, PAPER_LIGHT)
	for x in [-24, -16, -8]:
		draw_line(Vector2(x,-49), Vector2(x+5,-49), Color("63573f"), 1.0)
	draw_circle(Vector2(28,-48),2.4,CYAN if active else GOLD)

func _draw_process() -> void:
	_ellipse(Vector2(0,4),Vector2(124,10),Color(0.015,0.025,0.035,0.5))
	_round_rect(Rect2(-111,-29,222,16), Color("69553b"), 3, GOLD, 1)
	draw_rect(Rect2(-111,-32,222,7),PAPER)
	for x in [-86,86]:
		draw_line(Vector2(x,-15),Vector2(x,-1),GOLD,7,true)
	var progress: Dictionary = _progress()
	var order: Array = progress.get("book_order",["CIRCLE","TRIANGLE","SQUARE"])
	for i in range(3):
		var x: float = (i-1)*64.0
		if bool(progress.get("books_collected",false)):
			var book_id := str(order[i]) if i<order.size() else ""
			_book(Vector2(x,-34),Vector2(46,60),[RED,Color("203e57"),Color("172e37")][i],book_id)
		else:
			draw_rect(Rect2(x-23,-95,46,61),Color(0.73,0.6,0.36,0.28),false,1)
		_glyph(["TRIANGLE","SQUARE","CIRCLE"][i],Vector2(x,-112),9,Color(GOLD,0.8),1.5)
	if active:
		draw_line(Vector2(-106,-23),Vector2(106,-23),Color(CYAN,0.65),2,true)

func _draw_balance() -> void:
	_stand()
	var progress: Dictionary = _progress()
	var sides: Array = progress.get("balance_sides",[1,1,1])
	var left: int = 2
	var right: int = 0
	for i in range(mini(3,sides.size())):
		if int(sides[i])==0: left += [1,1,2][i]
		else: right += [1,1,2][i]
	var tilt := clampf(float(right-left)*4.0,-14,14)
	draw_line(Vector2(0,-19),Vector2(0,-133),GOLD,5,true)
	draw_circle(Vector2(0,-133),7,PAPER_LIGHT)
	draw_line(Vector2(-56,-122-tilt),Vector2(56,-122+tilt),GOLD,4,true)
	for direction in [-1,1]:
		var end := Vector2(direction*56,-122+direction*tilt)
		draw_line(end,end+Vector2(0,43),GOLD,1,true)
		draw_line(end+Vector2(-23,43),end+Vector2(23,43),PAPER_LIGHT,4,true)
		var count: int = left if direction==-1 else right
		for j in range(count):
			draw_rect(Rect2(end+Vector2(-18+j*9,30),Vector2(8,11)),Color("c6af7d"))

func _draw_overlay() -> void:
	_stand()
	var progress: Dictionary = _progress()
	var offsets: Array = progress.get("overlay_offsets",[2,1])
	for i in range(2):
		var offset: float = float(offsets[i]) * 6.0
		var origin := Vector2(-43 + i*14 + offset,-98+i*8)
		_round_rect(Rect2(origin,Vector2(70,76)),Color(0.8,0.78,0.65,0.58),3,Color(GOLD,0.8),1)
		_glyph("TRIANGLE",origin+Vector2(35,31),16,Color("264750"),1.5)
		for j in range(2):
			draw_line(origin+Vector2(13,54+j*6),origin+Vector2(55,54+j*6),Color(0.08,0.2,0.24,0.4),1,true)
	if active: _glow(Vector2(0,-66),52,CYAN,0.06)

func _draw_pop_book() -> void:
	_stand()
	draw_colored_polygon(PackedVector2Array([Vector2(-65,-35),Vector2(-11,-48),Vector2(0,-31),Vector2(-50,-21)]),PAPER)
	draw_colored_polygon(PackedVector2Array([Vector2(0,-31),Vector2(12,-48),Vector2(65,-35),Vector2(50,-21)]),PAPER_LIGHT)
	draw_polyline(PackedVector2Array([Vector2(-65,-35),Vector2(-11,-48),Vector2(0,-31),Vector2(12,-48),Vector2(65,-35)]),GOLD,1.5,true)
	var rises: Array = [26,45,26] if active else [16,25,16]
	for i in range(3):
		var x: float = (i-1)*22
		draw_colored_polygon(PackedVector2Array([Vector2(x-11,-38),Vector2(x,-38-rises[i]),Vector2(x+11,-38)]),PAPER_LIGHT if i%2==0 else PAPER)
		draw_line(Vector2(x,-38-rises[i]),Vector2(x,-38),Color("ac9266"),1,true)

func _draw_stranger() -> void:
	_ellipse(Vector2(0,0),Vector2(88,16),Color(0.01,0.015,0.02,0.7))
	var silhouette := PackedVector2Array([Vector2(-73,-5),Vector2(-58,-29),Vector2(-45,-47),Vector2(-39,-75),Vector2(-28,-99),Vector2(-9,-109),Vector2(12,-95),Vector2(18,-69),Vector2(43,-56),Vector2(55,-28),Vector2(75,-9),Vector2(43,-3),Vector2(16,-18),Vector2(-8,-9),Vector2(-32,-17)])
	draw_colored_polygon(silhouette,Color("080f17"))
	draw_polyline(PackedVector2Array([Vector2(-58,-29),Vector2(-45,-47),Vector2(-39,-75),Vector2(-28,-99)]),Color(0.27,0.33,0.38,0.3),1.4,true)
	draw_polyline(PackedVector2Array([Vector2(-33,-34),Vector2(-12,-24),Vector2(16,-18),Vector2(43,-3)]),Color(0.2,0.26,0.3,0.4),1.2,true)
	# A rim, a black flame and a bowed silhouette only: no final face or costume.
	var lamp := Vector2(-13,-117)
	draw_line(lamp+Vector2(-17,-23),lamp+Vector2(15,-20),Color("5d625d"),2,true)
	draw_polyline(PackedVector2Array([lamp+Vector2(-12,-20),lamp+Vector2(-15,11),lamp+Vector2(11,15),lamp+Vector2(15,-17)]),Color(0.58,0.64,0.62,0.38),1.5,true)
	var flame := PackedVector2Array([lamp+Vector2(-6,9),lamp+Vector2(-9,0),lamp+Vector2(-4,-5),lamp+Vector2(-3,-15),lamp+Vector2(4,-8),lamp+Vector2(3,-1),lamp+Vector2(8,3),lamp+Vector2(4,11),lamp+Vector2(-6,9)])
	draw_colored_polygon(flame,Color("010407"))
	draw_polyline(flame,Color(0.66,0.72,0.7,0.52),0.9,true)

func _draw_note() -> void:
	if not active: _glow(Vector2(0,-26),32,Color("e1bf73"),0.04)
	var alpha := 0.58 if active else 1.0
	draw_colored_polygon(PackedVector2Array([Vector2(-19,-48),Vector2(14,-51),Vector2(23,-43),Vector2(18,-3),Vector2(-17,0)]),Color(PAPER,alpha))
	draw_colored_polygon(PackedVector2Array([Vector2(14,-51),Vector2(14,-42),Vector2(23,-43)]),Color("a99571"))
	for i in range(5):
		draw_line(Vector2(-11,-37+i*6),Vector2(11-(i%2)*5,-39+i*6),Color(0.16,0.23,0.25,0.6*alpha),1,true)
	if not active:
		draw_circle(Vector2(4,-59+sin(elapsed*1.8)*2),2,Color("e3c77e"))

func _draw_weapon() -> void:
	_stand()
	if active: return
	_glow(Vector2(0,-67),49,CYAN,0.045)
	draw_line(Vector2(-14,-27),Vector2(16,-94),Color("5c4c36"),5,true)
	draw_line(Vector2(-7,-43),Vector2(22,-29),GOLD,4,true)
	draw_colored_polygon(PackedVector2Array([Vector2(-4,-47),Vector2(13,-94),Vector2(27,-111),Vector2(27,-88),Vector2(3,-44)]),Color("ccd9cc"))
	draw_line(Vector2(2,-49),Vector2(26,-108),Color("f0f1dc"),1,true)

func _draw() -> void:
	match kind:
		"bench": _draw_bench()
		"book":
			_stand()
			var symbol := str(definition.get("symbol",definition.get("book_id","TRIANGLE"))).to_upper()
			if active:
				_glyph(symbol,Vector2(0,-37),10,Color(GOLD,0.35),1.2)
			else:
				_glow(Vector2(0,-54),44,CYAN,0.04)
				var cover: Color = RED if symbol=="TRIANGLE" else (Color("243d58") if symbol=="SQUARE" else Color("162c35"))
				_book(Vector2(0,-23),Vector2(58,75),cover,symbol)
		"note", "secret": _draw_note()
		"dialogue": _draw_stranger()
		"weapon": _draw_weapon()
		"process_control": _draw_process()
		"balance_control": _draw_balance()
		"secret_overlay": _draw_overlay()
		"secret_pop": _draw_pop_book()
		"ink_control": _draw_terminal("ink")
		"output_control": _draw_terminal("output")
		"combat_socket": _draw_terminal("socket")
		"world_exit":
			_glow(Vector2(0,-82),49,CYAN,0.07)
			draw_arc(Vector2(0,-81),26,0,TAU,40,GOLD,3,true)
			draw_line(Vector2(0,-106),Vector2(0,-55),CYAN,2,true)
			_stand()
		_: _draw_terminal("lever")
	if highlighted and kind not in ["dialogue", "bench"] and not (active and kind in ["book","weapon"]):
		draw_arc(Vector2(0,-4),21,PI*0.08,PI*0.92,24,Color(CYAN,0.22+0.1*sin(elapsed*2.8)),1.3,true)
