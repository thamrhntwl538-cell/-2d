extends CanvasLayer
## A short, non-blocking chapter title; never consumes controls or room geometry.
const FONT := preload("res://assets/fonts/DejaVuSans.ttf")
var card: Control
var chapter: Label
var title: Label
var ornament: HSeparator
var motion: Tween
var reveal_count: int = 0

func _ready() -> void:
	layer = 12
	card = Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	stack.position = Vector2(-310,96)
	stack.size = Vector2(620,130)
	stack.add_theme_constant_override("separation",8)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(stack)
	chapter = _label(13,Color("b69767"))
	title = _label(28,Color("edddbf"))
	stack.add_child(chapter)
	stack.add_child(title)
	ornament = HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color(0.75,0.56,0.30,0.55)
	line.thickness = 1
	ornament.add_theme_stylebox_override("separator",line)
	stack.add_child(ornament)
	card.modulate.a = 0.0

func _label(size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",FONT)
	label.add_theme_font_size_override("font_size",size_px)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color(0.01,0.02,0.03,0.96))
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func present(room: Dictionary, language: String) -> void:
	if not is_instance_valid(card): return
	if is_instance_valid(motion): motion.kill()
	chapter.text = "المكتبة المطوية  ·  %02d" % int(room.id) if language=="ar" else "THE FOLDING LIBRARY  ·  %02d" % int(room.id)
	title.text = str(room.get("title_ar",room.get("arabic_title",""))) if language=="ar" else str(room.get("title",""))
	title.text_direction = Control.TEXT_DIRECTION_RTL if language=="ar" else Control.TEXT_DIRECTION_LTR
	card.modulate.a = 0.0
	reveal_count += 1
	motion = create_tween()
	motion.tween_property(card,"modulate:a",1.0,0.65).set_trans(Tween.TRANS_SINE)
	motion.tween_interval(1.7)
	motion.tween_property(card,"modulate:a",0.0,0.8).set_trans(Tween.TRANS_SINE)

func dismiss() -> void:
	if is_instance_valid(motion): motion.kill()
	if is_instance_valid(card): card.modulate.a = 0.0
