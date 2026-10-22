extends CanvasLayer
## Localized environment HUD. The world owns mechanics, persistence and pause state.
signal action(action_id: String, value: Variant)

const Text = preload("res://scripts/ui/m17_text.gd")
const FONT = preload("res://assets/fonts/DejaVuSans.ttf")
const INK := Color("101e2c")
const PAPER := Color("eee1c2")
const GOLD := Color("c5a66a")
const CYAN := Color("76c3cf")
var world_ref: Node2D
var language: String = "ar"
var panel_open: bool = false
var current_panel: String = ""
var panel_context: Dictionary = {}
var current_room: Dictionary = {}
var current_progress: Dictionary = {}
var current_hint: String = ""
var current_hint_args: Array = []
var toast_time: float = 0.0
var rendered_language: String = ""
var canvas: Control
var title_label: Label
var room_label: Label
var objective_label: Label
var hint_label: Label
var toast_label: Label
var controls_label: Label
var status_label: Label
var modal_shade: ColorRect
var modal: PanelContainer
var modal_box: VBoxContainer
var modal_title: Label
var modal_body: VBoxContainer
var modal_footer: HBoxContainer
var top_buttons: HBoxContainer
var health_icons: HealthDisplay

class HealthDisplay extends Control:
 var hp: int = 6
 func _draw() -> void:
  for i in range(6):
   var color = Color("d7c089") if i < hp else Color("39414a")
   var p = Vector2(10 + i * 21, 10)
   draw_circle(p, 6.0, color)
   if i < hp: draw_circle(p + Vector2(-1,-1), 2.0, Color("fff1c8"))

class PuzzleArt extends Control:
 var kind: String = ""
 var state: Dictionary = {}
 var font: Font = preload("res://assets/fonts/DejaVuSans.ttf")
 func _ready() -> void:
  custom_minimum_size = Vector2(760,215)
  mouse_filter = Control.MOUSE_FILTER_IGNORE
 func _draw() -> void:
  var scale_value: float = minf(size.x / 800.0, size.y / 220.0)
  draw_set_transform(Vector2((size.x-800*scale_value)/2,0),0,Vector2.ONE*scale_value)
  match kind:
   "ink": _ink()
   "process": _books()
   "balance": _balance()
   "overlay": _overlay()
   "pop": _pop()
   "output": _output()
 func _values(key: String, fallback: Array) -> Array:
  var value = state.get(key,fallback)
  return value if value is Array and value.size() >= fallback.size() else fallback
 func _text(p: Vector2, value: String, color: Color = Color("eee1c2"), sz: int = 18) -> void:
  var w: float = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,sz).x
  draw_string(font,p-Vector2(w/2,0),value,HORIZONTAL_ALIGNMENT_LEFT,-1,sz,color)
 func _ink() -> void:
  var points = [Vector2(265,55),Vector2(265,165),Vector2(510,165)]
  var cyan = Color("76c3cf")
  var muted = Color("425768")
  var rotations: Array = _values("ink_rotations",[0,0,0])
  var connections = [[0,1],[1,2],[2,3],[3,0]]
  var dirs = [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]
  draw_line(Vector2(90,55),points[0]-Vector2(42,0),cyan,6,true)
  draw_circle(Vector2(90,55),10,cyan)
  draw_line(points[0]+Vector2(0,42),points[1]-Vector2(0,42),muted,6,true)
  draw_line(points[1]+Vector2(42,0),points[2]-Vector2(42,0),muted,6,true)
  draw_line(points[2]-Vector2(0,42),Vector2(510,32),muted,6,true)
  draw_rect(Rect2(480,5,60,27),Color("bba476"),true)
  _text(Vector2(510,25),"FOLD",Color("182734"),13)
  for i in range(3):
   var p: Vector2 = points[i]
   draw_rect(Rect2(p-Vector2(43,43),Vector2(86,86)),Color("1b3040"),true)
   draw_rect(Rect2(p-Vector2(43,43),Vector2(86,86)),Color("6d8490"),false,1.5)
   for port in range(4):
    draw_circle(p+dirs[port]*39,3,Color("88939a"))
   var value: int = posmod(int(rotations[i]),4)
   for port in connections[value]: draw_line(p,p+dirs[port]*39,cyan,8,true)
   draw_circle(p,5,cyan)
   _text(p+Vector2(-28,-25),["A","B","C"][i],Color("d1bd8e"),14)
  _text(Vector2(90,92),"SOURCE",cyan,13)
 func _books() -> void:
  var order: Array = _values("book_order",["CIRCLE","TRIANGLE","SQUARE"])
  var glyphs = {"TRIANGLE":"△","SQUARE":"□","CIRCLE":"○"}
  var colors = {"TRIANGLE":Color("78403a"),"SQUARE":Color("263e52"),"CIRCLE":Color("303739")}
  draw_line(Vector2(165,184),Vector2(635,184),Color("c3af7e"),9,true)
  draw_line(Vector2(180,184),Vector2(180,210),Color("786b51"),6,true)
  draw_line(Vector2(620,184),Vector2(620,210),Color("786b51"),6,true)
  for i in range(3):
   var key: String = str(order[i]) if i < order.size() else "TRIANGLE"
   if not glyphs.has(key): key = ["TRIANGLE","SQUARE","CIRCLE"][posmod(int(order[i]),3)]
   var x: float = 225+i*175
   draw_rect(Rect2(x-48,67,96,110),colors[key],true)
   draw_rect(Rect2(x-48,67,96,110),Color("c5a66a"),false,2)
   draw_line(Vector2(x-37,70),Vector2(x-37,174),Color("c5a66a"),1.5,true)
   _text(Vector2(x,53),str(i+1),Color("76c3cf"),17)
   _text(Vector2(x+3,137),glyphs[key],Color("eee1c2"),42)
 func _balance() -> void:
  var sides: Array = _values("balance_sides",[1,1,1])
  var weights = [1,1,2]
  var sums = [2,0]
  for i in range(3): sums[clampi(int(sides[i]),0,1)] += weights[i]
  var offset: float = clampf(float(sums[1]-sums[0])*10.0,-30,30)
  var left = Vector2(205,152-offset)
  var right = Vector2(595,152+offset)
  draw_line(Vector2(400,55),Vector2(400,205),Color("b09b6f"),7,true)
  draw_line(Vector2(375,205),Vector2(425,205),Color("b09b6f"),7,true)
  draw_line(Vector2(205,65-offset),Vector2(595,65+offset),Color("d6c591"),6,true)
  for p in [left,right]:
   draw_line(Vector2(p.x, p.y-87),p,Color("b09b6f"),2,true)
   draw_line(p-Vector2(95,0),p+Vector2(95,0),Color("d6c591"),5,true)
  draw_rect(Rect2(left+Vector2(-78,-57),Vector2(53,53)),Color("70684f"),true)
  _text(left+Vector2(-52,-21),"2",Color("eee1c2"),25)
  _text(left+Vector2(-52,21),"FIXED",Color("b9ab87"),11)
  var slots = [0,0]
  for i in range(3):
   var side: int = clampi(int(sides[i]),0,1)
   var base: Vector2 = left if side == 0 else right
   var x: float = base.x+(-8 if side==0 else -60)+slots[side]*57
   slots[side] += 1
   var h: float = 29 if weights[i]==1 else 53
   draw_rect(Rect2(x-22,base.y-h-4,44,h),Color("c6ad79"),true)
   _text(Vector2(x,base.y-h/2+4),str(weights[i]),Color("182734"),23)
  if sums[0] == sums[1]: _text(Vector2(400,33),"3 = 3",Color("76c3cf"),26)
 func _overlay() -> void:
  var offsets: Array = _values("overlay_offsets",[2,1])
  var shifts = [Vector2.ZERO,Vector2(44,0),Vector2(44,32),Vector2(0,32)]
  var origin = Vector2(310,22)
  draw_rect(Rect2(origin,Vector2(165,175)),Color("c5a66a"),false,2)
  for i in range(2):
   var p: Vector2 = origin + shifts[posmod(int(offsets[i]),4)]
   draw_rect(Rect2(p,Vector2(165,175)),Color(0.8,0.86,0.85,0.12),true)
   draw_rect(Rect2(p,Vector2(165,175)),Color("76c3cf") if i==0 else Color("d7bb83"),false,2)
   var line_points = PackedVector2Array([p+Vector2(24,120),p+Vector2(58,84),p+Vector2(84,107)]) if i==0 else PackedVector2Array([p+Vector2(84,107),p+Vector2(117,60),p+Vector2(143,88)])
   draw_polyline(line_points,Color("eee1c2"),4,true)
   _text(p+Vector2(145,25),str(i+1),Color("eee1c2"),17)
 func _pop() -> void:
  var folds: Array = _values("pop_folds",[0,0,0])
  draw_line(Vector2(160,182),Vector2(640,182),Color("c7b181"),7,true)
  for i in range(3):
   var x: float = 235+i*165
   var value: int = posmod(int(folds[i]),3)
   var p = Vector2(x,176)
   var tip = p+([Vector2(58,-7),Vector2(42,-60),Vector2(2,-95)][value])
   var polygon = PackedVector2Array([p-Vector2(30,0),p+Vector2(30,0),tip+Vector2(30,0),tip-Vector2(30,0)])
   draw_colored_polygon(polygon,Color("d3bc89"))
   draw_polyline(PackedVector2Array([polygon[0],polygon[3],polygon[2],polygon[1]]),Color("f0ddae"),2,true)
   _text(Vector2(x,52),str(i+1),Color("76c3cf"),17)
 func _output() -> void:
  var path = PackedVector2Array([Vector2(360,185),Vector2(425,185),Vector2(425,150),Vector2(490,150),Vector2(490,115),Vector2(555,115),Vector2(555,80),Vector2(620,80)])
  draw_line(Vector2(90,185),Vector2(285,185),Color("c7b181"),8,true)
  draw_polyline(path,Color("dfcda3"),8,true)
  draw_rect(Rect2(190,112,38,70),Color("233c4c"),true)
  draw_rect(Rect2(190,112,38,70),Color("76c3cf"),false,2)
  draw_circle(Vector2(145,128),11,Color("d7c089"))
  draw_line(Vector2(145,140),Vector2(145,175),Color("d7c089"),4,true)
  draw_line(Vector2(145,175),Vector2(130,185),Color("d7c089"),4,true)
  draw_line(Vector2(145,175),Vector2(160,185),Color("d7c089"),4,true)
  draw_dashed_line(Vector2(300,80),Vector2(300,190),Color("a55a4f"),2,6,true)

class MapDisplay extends Control:
 var progress: Dictionary = {}
 var room_id: int = 1
 var language: String = "ar"
 var font: Font = preload("res://assets/fonts/DejaVuSans.ttf")
 const POS = {1:Vector2(.07,.86),2:Vector2(.29,.86),3:Vector2(.51,.86),4:Vector2(.73,.86),5:Vector2(.97,.62),6:Vector2(.73,.56),7:Vector2(.51,.56),8:Vector2(.29,.56),9:Vector2(.07,.56),10:Vector2(.07,.26),11:Vector2(.29,.26),12:Vector2(.51,.26),13:Vector2(.73,.26),14:Vector2(.73,.0),15:Vector2(.51,.0)}
 func _ready() -> void:
  custom_minimum_size = Vector2(920,320)
  mouse_filter = Control.MOUSE_FILTER_IGNORE
 func _p(id: int) -> Vector2:
  return Vector2(80,31)+(size-Vector2(180,65))*POS[id]
 func _draw() -> void:
  var main = [1,2,3,4,6,7,8,9,10,11,12,13,14,15]
  for i in range(main.size()-1): draw_line(_p(main[i]),_p(main[i+1]),Color("77848a"),2,true)
  for pair in [[4,5],[5,6]]: draw_dashed_line(_p(pair[0]),_p(pair[1]),Color("a88dc0"),2,6,true)
  var paths = [
   ["archive_return_open",[_p(6),Vector2(size.x-12,_p(6).y),Vector2(size.x-12,size.y-5),Vector2(_p(2).x,size.y-5),_p(2)]],
   ["output_open",[_p(9),Vector2(5,_p(9).y),Vector2(5,size.y-19),Vector2(_p(3).x,size.y-19),_p(3)]],
   ["workshop_archive_return_open",[_p(12),Vector2(_p(12).x,_p(6).y-52),Vector2(_p(6).x,_p(6).y-52),_p(6)]],
   ["guard_approach_return_open",[_p(13),Vector2(_p(13).x,_p(13).y-50),Vector2(_p(10).x,_p(10).y-50),_p(10)]]]
  for item in paths:
   var col = Color("76c3cf") if bool(progress.get(item[0],false)) else Color("33434d")
   for i in range(item[1].size()-1): draw_dashed_line(item[1][i],item[1][i+1],col,2,6,true)
  var visited_ids: Array = progress.get("visited",[])
  for id in POS:
   var p: Vector2 = _p(id)
   var seen: bool = visited_ids.has(id) or id == room_id
   var rect = Rect2(p-Vector2(69,24),Vector2(138,48))
   draw_style_box(_node_style(id==room_id,seen),rect)
   var text: String = "%02d" % id
   var title: String = Text.get_text("room_"+str(id),language) if seen else "—"
   var title_width: float = font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
   draw_string(font,p+Vector2(-font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x/2,-4),text,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("d4bc83"))
   draw_string(font,p+Vector2(-title_width/2,13),title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("cad7d9") if seen else Color("68737c"))
   if id in [1,6,10,13]: draw_rect(Rect2(p+Vector2(54,-17),Vector2(5,5)),Color("c5a66a"),true)
 func _node_style(current: bool, seen: bool) -> StyleBoxFlat:
  var style = StyleBoxFlat.new()
  style.bg_color = Color("243a49") if seen else Color("142432")
  style.border_color = Color("d0af68") if current else Color("516a7b") if seen else Color("2c404f")
  style.set_border_width_all(2 if current else 1)
  style.set_corner_radius_all(5)
  return style

func t(key: String, args: Array = []) -> String:
 return Text.get_text(key,language,args)

func setup(world: Node2D) -> void:
 world_ref = world
 layer = 40
 canvas = Control.new()
 canvas.name = "M17Presentation"
 canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(canvas)
 var theme = Theme.new()
 theme.default_font = FONT
 theme.default_font_size = 18
 theme.set_color("font_color","Label",PAPER)
 theme.set_color("font_color","Button",PAPER)
 theme.set_color("font_hover_color","Button",Color("fff0ca"))
 for state in ["normal","hover","pressed","focus","disabled"]:
  var style = _style(Color("142a39") if state != "hover" else Color("243e4d"),Color("677268") if state != "focus" else GOLD,6)
  style.content_margin_left = 17
  style.content_margin_right = 17
  style.content_margin_top = 10
  style.content_margin_bottom = 10
  theme.set_stylebox(state,"Button",style)
 canvas.theme = theme
 var top_shade = ColorRect.new()
 top_shade.position = Vector2.ZERO
 top_shade.size = Vector2(1280,132)
 top_shade.color = Color(0.025,0.04,0.06,0.71)
 top_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
 canvas.add_child(top_shade)
 title_label = _label(canvas,"",Vector2(26,13),Vector2(620,25),13)
 title_label.add_theme_color_override("font_color",GOLD)
 room_label = _label(canvas,"",Vector2(26,39),Vector2(950,36),22)
 objective_label = _label(canvas,"",Vector2(26,81),Vector2(1050,26),14)
 objective_label.modulate.a = .8
 health_icons = HealthDisplay.new()
 health_icons.position = Vector2(27,113)
 health_icons.size = Vector2(130,20)
 canvas.add_child(health_icons)
 top_buttons = HBoxContainer.new()
 top_buttons.position = Vector2(961,17)
 top_buttons.size = Vector2(291,37)
 top_buttons.add_theme_constant_override("separation",7)
 canvas.add_child(top_buttons)
 hint_label = _label(canvas,"",Vector2(140,567),Vector2(1000,43),19)
 hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 hint_label.add_theme_color_override("font_shadow_color",Color(0,0,0,.95))
 hint_label.add_theme_constant_override("shadow_offset_y",2)
 toast_label = _label(canvas,"",Vector2(90,620),Vector2(1100,47),17)
 toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 toast_label.add_theme_color_override("font_shadow_color",Color(0,0,0,.95))
 toast_label.add_theme_constant_override("shadow_offset_y",2)
 var bottom_shade = ColorRect.new()
 bottom_shade.position = Vector2(0,682)
 bottom_shade.size = Vector2(1280,38)
 bottom_shade.color = Color(0.018,0.03,0.045,0.84)
 bottom_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
 canvas.add_child(bottom_shade)
 controls_label = _label(canvas,"",Vector2(38,689),Vector2(1204,23),12)
 controls_label.add_theme_color_override("font_shadow_color",Color(0,0,0,.95))
 controls_label.add_theme_constant_override("shadow_offset_y",1)
 controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 controls_label.modulate.a = .68
 status_label = _label(canvas,"",Vector2(964,58),Vector2(285,27),11)
 status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
 status_label.modulate.a = .65
 modal_shade = ColorRect.new()
 modal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 modal_shade.color = Color(0.008,0.017,0.026,.84)
 modal_shade.mouse_filter = Control.MOUSE_FILTER_STOP
 modal_shade.visible = false
 canvas.add_child(modal_shade)
 modal = PanelContainer.new()
 modal.position = Vector2(100,56)
 modal.size = Vector2(1080,608)
 modal.add_theme_stylebox_override("panel",_style(Color("0e1d2b"),Color("8f805d"),10,23))
 modal.visible = false
 canvas.add_child(modal)
 _refresh_static()

func _style(bg: Color, border: Color, corner: int = 5, margin: int = 0) -> StyleBoxFlat:
 var s = StyleBoxFlat.new()
 s.bg_color = bg
 s.border_color = border
 s.set_border_width_all(1)
 s.set_corner_radius_all(corner)
 if margin > 0:
  s.content_margin_left = margin
  s.content_margin_right = margin
  s.content_margin_top = margin
  s.content_margin_bottom = margin
 return s

func _label(parent: Node, text: String, p: Vector2 = Vector2.ZERO, sz: Vector2 = Vector2.ZERO, font_size: int = 18) -> Label:
 var label = Label.new()
 label.text = text
 label.position = p
 label.size = sz
 label.add_theme_font_override("font",FONT)
 label.add_theme_font_size_override("font_size",font_size)
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 _localize(label)
 parent.add_child(label)
 return label

func _localize(control: Control) -> void:
 control.layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR
 if control is Label:
  control.text_direction = Control.TEXT_DIRECTION_RTL if language == "ar" else Control.TEXT_DIRECTION_LTR
  control.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT # RTL mirrors semantic start to the right edge.

func _button(parent: Node, text: String, callback: Callable, disabled: bool = false) -> Button:
 var button = Button.new()
 button.text = text
 button.add_theme_font_override("font",FONT)
 button.add_theme_font_size_override("font_size",16)
 button.custom_minimum_size.y = 42
 button.disabled = disabled
 _localize(button)
 button.pressed.connect(callback)
 parent.add_child(button)
 return button

func _defer_focus(control: Control) -> void:
 _focus_if_present.call_deferred(weakref(control))

func _focus_if_present(reference: WeakRef) -> void:
 var control = reference.get_ref()
 if is_instance_valid(control) and control.is_inside_tree(): control.grab_focus()

func _paragraph(parent: Node, value: String, font_size: int = 18) -> Label:
 var label = _label(parent,value,Vector2.ZERO,Vector2.ZERO,font_size)
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 label.custom_minimum_size.y = 40
 return label

func _refresh_static() -> void:
 if not is_instance_valid(canvas): return
 rendered_language = language
 top_buttons.position.x = 26 if language == "ar" else 961
 health_icons.position.x = 1118 if language == "ar" else 27
 title_label.text = t("game_title")+"  /  "+t("world_title")
 controls_label.text = t("controls")
 controls_label.text_direction = Control.TEXT_DIRECTION_LTR
 for child in top_buttons.get_children():
  top_buttons.remove_child(child)
  child.queue_free()
 _button(top_buttons,t("map"),func(): action.emit("map",null))
 _button(top_buttons,t("journal"),func(): action.emit("journal",null))
 _button(top_buttons,"EN" if language=="ar" else "عربي",func(): action.emit("language","en" if language=="ar" else "ar"))
 status_label.text = t("environment_build")
 for label in [title_label,room_label,objective_label]: _localize(label)

func set_language(value: String) -> void:
 language = "en" if value == "en" else "ar"
 _refresh_static()
 update_status(current_room,current_progress,current_hint,current_hint_args)
 if panel_open: _rebuild_panel()

func update_status(room: Dictionary, progress: Dictionary, hint_key: String = "", hint_args: Array = []) -> void:
 current_room = room
 current_progress = progress
 current_hint = hint_key
 current_hint_args = hint_args
 if not is_instance_valid(canvas): return
 if rendered_language != language:
  _refresh_static()
  if panel_open: _rebuild_panel()
 var id: int = int(room.get("id",1))
 room_label.text = "%02d  ·  %s" % [id,t("room_"+str(id))]
 var completed_objectives = {1:"weapon_owned",3:"ink_route_solved",6:"archive_upper_landing_reached",7:"books_collected",8:"book_order_verified",9:"output_open",10:"balance_bridge_locked",12:"workshop_main_passage_open"}
 if completed_objectives.has(id) and bool(progress.get(completed_objectives[id],false)):
  objective_label.text = t("objective_continue")
 elif id == 7:
  objective_label.text = t("objective_books_count",[str(progress.get("book_inventory",[]).size())])
 else:
  objective_label.text = t("objective_"+str(id)) if Text.WORDS.has("objective_"+str(id)) else t("objective_default")
 hint_label.text = t("interact",[t(hint_key,hint_args)]) if not hint_key.is_empty() else ""
 _localize(hint_label)
 hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 if is_instance_valid(world_ref) and is_instance_valid(world_ref.get("hero")):
  health_icons.hp = int(world_ref.hero.hp)
  health_icons.queue_redraw()

func show_toast(message: String) -> void:
 if not is_instance_valid(toast_label): return
 toast_label.text = t(message)
 _localize(toast_label)
 toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 toast_time = 4.8

func _process(delta: float) -> void:
 if is_instance_valid(toast_label):
  toast_time = maxf(0,toast_time-delta)
  toast_label.modulate.a = minf(1.0,toast_time)

func open_panel(kind: String, context: Dictionary = {}) -> void:
 current_panel = kind
 panel_context = context.duplicate(false)
 if not panel_context.has("progress"): panel_context["progress"] = current_progress
 panel_open = true
 modal_shade.visible = true
 modal.visible = true
 hint_label.visible = false
 _rebuild_panel()

func refresh_panel(context: Dictionary = {}) -> void:
 panel_context.merge(context,true)
 if panel_open: _rebuild_panel()

func close_panel() -> void:
 panel_open = false
 current_panel = ""
 modal.visible = false
 modal_shade.visible = false
 hint_label.visible = true

func _request_close() -> void:
 action.emit("close_panel",null)

func _rebuild_panel() -> void:
 if not is_instance_valid(modal): return
 for child in modal.get_children():
  modal.remove_child(child)
  child.queue_free()
 modal_box = VBoxContainer.new()
 modal_box.add_theme_constant_override("separation",14)
 modal.add_child(modal_box)
 var head = HBoxContainer.new()
 _localize(head)
 modal_box.add_child(head)
 modal_title = _label(head,"",Vector2.ZERO,Vector2.ZERO,24)
 modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 modal_title.add_theme_color_override("font_color",GOLD)
 _button(head,"EN" if language=="ar" else "عربي",func(): action.emit("language","en" if language=="ar" else "ar"))
 var line = HSeparator.new()
 line.modulate = Color(.6,.6,.5,.5)
 modal_box.add_child(line)
 var scroll = ScrollContainer.new()
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.custom_minimum_size.y = 310
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 modal_box.add_child(scroll)
 modal_body = VBoxContainer.new()
 modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 modal_body.add_theme_constant_override("separation",13)
 scroll.add_child(modal_body)
 modal_footer = HBoxContainer.new()
 modal_footer.alignment = BoxContainer.ALIGNMENT_END
 modal_footer.add_theme_constant_override("separation",12)
 _localize(modal_footer)
 modal_box.add_child(modal_footer)
 match current_panel:
  "pause": _pause_panel()
  "completion": _completion_panel()
  "restart": _restart_panel()
  "map": _map_panel()
  "journal": _journal_panel()
  "note": _note_panel()
  "dialogue": _dialogue_panel()
  "exit", "world_exit": _exit_panel()
  "ink", "process", "books", "balance", "overlay", "pop", "output": _puzzle_panel()
  _: _note_panel()

func _state_values(state: Dictionary, key: String, fallback: Array) -> Array:
 var value = state.get(key,fallback)
 return value if value is Array and value.size() >= fallback.size() else fallback

func _state() -> Dictionary:
 return panel_context.get("progress",panel_context.get("state",current_progress))

func _pause_panel() -> void:
 modal_title.text = t("pause")
 _paragraph(modal_body,t("world_title"),25)
 _paragraph(modal_body,t("environment_build"),15)
 _paragraph(modal_body,t("controls"),16)
 var language_row = HBoxContainer.new()
 modal_body.add_child(language_row)
 _button(language_row,t("ar"),func(): action.emit("language","ar"))
 _button(language_row,t("en"),func(): action.emit("language","en"))
 _button(modal_body,t("journal"),func(): action.emit("journal",null))
 _button(modal_body,t("restart"),func(): open_panel("restart",panel_context))
 var resume = _button(modal_footer,t("resume"),_request_close)
 _defer_focus(resume)

func _completion_panel() -> void:
 modal_title.text = t("completion_title")
 _paragraph(modal_body,t("completion_body"),22)
 _paragraph(modal_body,t("completion_count",[str(_state().get("visited",[]).size())]),16).add_theme_color_override("font_color",CYAN)
 var restart = _button(modal_footer,t("restart"),func():
  panel_context.return_to = "completion"
  open_panel("restart",panel_context))
 _defer_focus(restart)

func _restart_panel() -> void:
 modal_title.text = t("restart_title")
 _paragraph(modal_body,t("restart_body"),21)
 var back = _button(modal_footer,t("cancel"),func(): open_panel(str(panel_context.get("return_to","pause")),panel_context))
 _button(modal_footer,t("restart_confirm"),func(): action.emit("restart",null))
 _defer_focus(back)

func _map_panel() -> void:
 modal_title.text = t("map")
 var map_display = MapDisplay.new()
 map_display.progress = _state()
 map_display.language = language
 map_display.room_id = int(panel_context.get("room",current_room).get("id",1))
 modal_body.add_child(map_display)
 _paragraph(modal_body,t("map_legend"),13)
 _paragraph(modal_body,t("map_hint"),13)
 _defer_focus(_button(modal_footer,t("close"),_request_close))

func _notes_list() -> Array:
 var stored: Array = _state().get("notes",[])
 if panel_context.has("notes"): stored = panel_context.notes
 var normalized: Array = []
 for item in stored:
  var key: String = str(item.get("text_key",item.get("note_id",item.get("id","")))) if item is Dictionary else str(item)
  if not key.is_empty() and not normalized.has(key): normalized.append(key)
 return normalized

func _journal_panel() -> void:
 modal_title.text = t("journal")
 var stored = _notes_list()
 if stored.is_empty():
  _paragraph(modal_body,t("journal_empty"),21)
 else:
  var selected: String = str(panel_context.get("selected_note",stored[-1]))
  var selection = OptionButton.new()
  selection.custom_minimum_size.y = 40
  selection.add_theme_font_override("font",FONT)
  selection.add_theme_font_size_override("font_size",17)
  _localize(selection)
  for i in range(stored.size()):
   selection.add_item(Text.note(str(stored[i]),language).title,i)
   if str(stored[i]) == selected: selection.select(i)
  selection.item_selected.connect(func(index):
   panel_context.selected_note = str(stored[index])
   _rebuild_panel())
  modal_body.add_child(selection)
  var entry = Text.note(selected,language)
  _paragraph(modal_body,entry.title,23).add_theme_color_override("font_color",CYAN)
  _paragraph(modal_body,entry.body,20)
 _paragraph(modal_body,t("journal_hint"),13)
 _defer_focus(_button(modal_footer,t("close"),_request_close))

func _note_panel() -> void:
 var definition: Dictionary = panel_context.get("definition",{})
 var note_id: String = str(panel_context.get("note_id",definition.get("text_key",definition.get("note_id",definition.get("id","entrance_note")))))
 var entry = Text.note(note_id,language)
 if panel_context.has("body"):
  entry.body = str(panel_context.get("body_ar" if language=="ar" else "body_en",panel_context.body))
 if definition.has("text") or definition.has("text_ar"):
  entry.body = str(definition.get("text_ar" if language=="ar" else "text",entry.body))
 modal_title.text = entry.title
 _paragraph(modal_body,entry.body,23)
 _paragraph(modal_body,t("note_read"),13)
 _defer_focus(_button(modal_footer,t("close"),_request_close))

func _dialogue_panel() -> void:
 modal_title.text = t("dialogue_title")
 var index: int = clampi(int(panel_context.get("dialogue_index",0)),0,Text.DIALOGUE.size()-1)
 var entry: Array = Text.DIALOGUE[index]
 var speaker = _paragraph(modal_body,t(str(entry[0])),17)
 speaker.add_theme_color_override("font_color",CYAN if str(entry[0])=="hero_speaker" else GOLD)
 _paragraph(modal_body,str(entry[1 if language=="ar" else 2]),27)
 var page = _paragraph(modal_body,"%02d / %02d" % [index+1,Text.DIALOGUE.size()],13)
 page.text_direction = Control.TEXT_DIRECTION_LTR
 page.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 if index > 0:
  _button(modal_footer,t("previous"),func():
   panel_context.dialogue_index = index-1
   _rebuild_panel())
 _button(modal_footer,t("close"),_request_close)
 var next_button = _button(modal_footer,t("next") if index<Text.DIALOGUE.size()-1 else t("continue"),func():
  if index < Text.DIALOGUE.size()-1:
   panel_context.dialogue_index = index+1
   _rebuild_panel()
  else: _request_close())
 _defer_focus(next_button)

func _exit_panel() -> void:
 var preview: bool = bool(panel_context.get("environment_preview",false))
 modal_title.text = t("preview_exit_title" if preview else "exit_title")
 _paragraph(modal_body,t("preview_exit_body" if preview else "exit_warning"),23)
 if not preview: _paragraph(modal_body,t("departure_confirm"),16)
 var stay = _button(modal_footer,t("explore_more" if preview else "stay"),_request_close)
 if preview:
  _button(modal_footer,t("continue"),func(): action.emit("depart_confirm",null))
 else:
  var depart_button = _button(modal_footer,t("depart"),func(): action.emit("depart_confirm",null))
  depart_button.add_theme_color_override("font_color",Color("e8a78a"))
 _defer_focus(stay)

func _puzzle_panel() -> void:
 var kind: String = "process" if current_panel == "books" else current_panel
 modal_title.text = t(kind+"_title")
 _paragraph(modal_body,t(kind+"_instruction"),17)
 var art = PuzzleArt.new()
 art.kind = kind
 art.state = _state()
 modal_body.add_child(art)
 if Text.WORDS.has(kind+"_clue"):
  var clue = _paragraph(modal_body,t(kind+"_clue"),16)
  clue.add_theme_color_override("font_color",CYAN)
  if kind=="process":
   clue.text_direction = Control.TEXT_DIRECTION_LTR
   clue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 var row = HBoxContainer.new()
 row.alignment = BoxContainer.ALIGNMENT_CENTER
 row.add_theme_constant_override("separation",17)
 row.layout_direction = Control.LAYOUT_DIRECTION_LTR
 modal_body.add_child(row)
 var state = _state()
 match kind:
  "ink":
   var values: Array = _state_values(state,"ink_rotations",[0,0,0])
   for i in range(3):
    var index: int = i
    var value: int = (int(values[i])+1)%4
    _button(row,t("rotate",[["A","B","C"][i]]),func(): _choice("ink",index,value))
  "process":
   var values: Array = _state_values(state,"book_order",["CIRCLE","TRIANGLE","SQUARE"])
   var symbols = ["TRIANGLE","SQUARE","CIRCLE"]
   var glyphs = {"TRIANGLE":"△","SQUARE":"□","CIRCLE":"○"}
   for i in range(3):
    var index: int = i
    var current: String = str(values[i])
    var next_value: String = symbols[(symbols.find(current)+1)%3]
    _button(row,t("slot",[str(i+1)])+"  "+str(glyphs.get(current,"?")),func(): _choice("process",index,next_value))
  "balance":
   var values: Array = _state_values(state,"balance_sides",[1,1,1])
   for i in range(3):
    var index: int = i
    var value: int = 1-int(values[i])
    _button(row,t("weight",[str(i+1)])+" → "+t("left" if value==0 else "right"),func(): _choice("balance",index,value))
  "overlay":
   var values: Array = _state_values(state,"overlay_offsets",[2,1])
   for i in range(2):
    var index: int = i
    var value: int = (int(values[i])+1)%4
    _button(row,t("page",[str(i+1)])+" ↻",func(): _choice("overlay",index,value))
  "pop":
   var values: Array = _state_values(state,"pop_folds",[0,0,0])
   for i in range(3):
    var index: int = i
    var value: int = (int(values[i])+1)%3
    _button(row,t("fold",[str(i+1)])+" · "+t("fold_state_"+str(values[i])),func(): _choice("pop",index,value))
 _paragraph(modal_body,t("safe_controls"),12)
 _button(modal_footer,t("close"),_request_close)
 var confirm_key: String = "deploy" if kind=="output" else "set_order" if kind=="process" else "balance_confirm" if kind=="balance" else "confirm"
 var confirm = _button(modal_footer,t(confirm_key),func(): action.emit("puzzle_confirm",kind))
 _defer_focus(confirm)

func _choice(kind: String, index: int, value: Variant) -> void:
 action.emit("puzzle_choice",{"kind":kind,"index":index,"value":value})
