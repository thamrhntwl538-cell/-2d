extends Control
## Presentation only: the encounter remains the sole owner of health and phases.
const FONT := preload("res://assets/fonts/DejaVuSans.ttf")
var context: Dictionary = {}
var locale: String = "ar"
var shown_hp: float = 48.0
var chip_hp: float = 48.0
var damage_flash: float = 0.0
var chip_delay: float = 0.0
var _initialized: bool = false
var _clock: float = 0.0
var name_label: Label
var phase_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label = _make_label(20,Color("f2e0bf"))
	phase_label = _make_label(11,Color("b99e78"))
	resized.connect(_layout)
	_layout()

func _make_label(font_size: int, ink: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",FONT)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",ink)
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,.92))
	label.add_theme_constant_override("shadow_offset_y",2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	return label

func _layout() -> void:
	if not is_instance_valid(name_label): return
	name_label.position = Vector2(30,0)
	name_label.size = Vector2(size.x-60,29)
	phase_label.position = Vector2(20,49)
	phase_label.size = Vector2(size.x-40,19)
	queue_redraw()

func update_context(value: Dictionary, language: String) -> void:
	var was_visible := bool(context.get("visible",false))
	var maximum := maxf(1.0,float(value.get("max_hp",48)))
	var health := clampf(float(value.get("hp",maximum)),0,maximum)
	if not _initialized or (bool(value.get("visible",false)) and not was_visible):
		shown_hp = health
		chip_hp = health
		_initialized = true
	elif health<float(context.get("hp",health)):
		damage_flash = 1.0
		chip_delay = .28
	elif health>float(context.get("hp",health)):
		chip_hp = health
	context = value.duplicate(false)
	locale = "en" if language=="en" else "ar"
	if is_instance_valid(name_label):
		name_label.text = str(context.get("name_ar","د. كومبايلر")) if locale=="ar" else str(context.get("name_en","Dr. Compiler"))
		name_label.text_direction = Control.TEXT_DIRECTION_RTL if locale=="ar" else Control.TEXT_DIRECTION_LTR
		var second := int(context.get("phase",1))>=2
		phase_label.text = ("الطور الثاني" if second else "الطور الأول") if locale=="ar" else ("PHASE II" if second else "PHASE I")
		phase_label.text_direction = name_label.text_direction
	queue_redraw()

func _process(delta: float) -> void:
	_clock += delta
	var health := clampf(float(context.get("hp",48)),0,maxf(1.0,float(context.get("max_hp",48))))
	shown_hp = lerpf(shown_hp,health,1.0-exp(-22.0*delta))
	chip_delay = maxf(0.0,chip_delay-delta)
	if chip_delay<=0: chip_hp = lerpf(chip_hp,health,1.0-exp(-4.5*delta))
	chip_hp = maxf(chip_hp,shown_hp)
	damage_flash = maxf(0,damage_flash-delta*4.2)
	queue_redraw()

func _draw() -> void:
	var maximum := maxf(1.0,float(context.get("max_hp",48)))
	var second := int(context.get("phase",1))>=2
	var accent := Color("d5b678") if not second else Color("e39a73")
	var bar := Rect2(24,34,maxf(40,size.x-48),9)
	# A dark, narrow folio beneath the name; gameplay remains visible around it.
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(.025,.035,.047,.82)
	backing.set_corner_radius_all(3)
	backing.shadow_color = Color(0,0,0,.38)
	backing.shadow_size = 10
	draw_style_box(backing,Rect2(8,28,size.x-16,21))
	draw_rect(bar,Color("161820"))
	draw_rect(Rect2(bar.position,Vector2(bar.size.x*clampf(chip_hp/maximum,0,1),bar.size.y)),Color("7b685c"))
	var fill := accent.lerp(Color("fff4d6"),damage_flash*.52)
	draw_rect(Rect2(bar.position,Vector2(bar.size.x*clampf(shown_hp/maximum,0,1),bar.size.y)),fill)
	draw_line(bar.position+Vector2(0,1),bar.position+Vector2(bar.size.x*clampf(shown_hp/maximum,0,1),1),Color(1,.91,.73,.55),1,true)
	draw_rect(bar.grow(2),Color(accent,.46),false,1)
	for fraction in [.25,.5,.75]:
		var x := bar.position.x+bar.size.x*float(fraction)
		draw_line(Vector2(x,33),Vector2(x,44),Color(.05,.065,.08,.48),1,true)
	for side in [0,1]:
		var center := Vector2(14 if side==0 else size.x-14,38.5)
		draw_polyline(PackedVector2Array([center+Vector2(0,-7),center+Vector2(5,0),center+Vector2(0,7),center+Vector2(-5,0),center+Vector2(0,-7)]),accent,1.3,true)
	if bool(context.get("stagger",str(context.get("state",""))=="stagger")):
		var strength := .28+.18*sin(_clock*7.0)
		draw_rect(bar.grow(4),Color(1,.88,.58,strength),false,1)
