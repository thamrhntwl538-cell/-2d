extends "res://scripts/ui/m17_hud.gd"
## M18 combat presentation. Gameplay, loadout validation and saves belong to the world.
## The lantern uses the SAME reserve for Focus and techniques; the small diamond
## indicates the selected technique's readiness and is not a second energy pool.

const FITIL_INFO := preload("res://scripts/combat/m18_combat_state.gd").FITILS

var combat_display: LanternDisplay
var combat_context: Dictionary = {}
var _controls_signature: String = ""
var _bottom_shade: ColorRect

class LanternDisplay extends Control:
 var context: Dictionary = {}
 var language: String = "ar"
 var font: Font = preload("res://assets/fonts/DejaVuSans.ttf")
 var shown_energy: float = 99.0
 var old_hp: int = 6
 var damage_flash: float = 0.0
 var spend_flash: float = 0.0
 var age: float = 0.0
 var last_energy: float = 99.0

 func _ready() -> void:
  mouse_filter = Control.MOUSE_FILTER_PASS
  focus_mode = Control.FOCUS_NONE
  custom_minimum_size = Vector2(310,146)

 func update_context(value: Dictionary, locale: String) -> void:
  var hp: int = int(value.get("hp",6))
  var energy: float = float(value.get("energy",99.0))
  if hp < old_hp: damage_flash = 0.22
  if energy < last_energy - 1.0: spend_flash = 0.24
  old_hp = hp
  last_energy = energy
  context = value.duplicate(false)
  language = locale
  queue_redraw()

 func _process(delta: float) -> void:
  age += delta
  damage_flash = maxf(0.0,damage_flash-delta)
  spend_flash = maxf(0.0,spend_flash-delta)
  shown_energy = lerpf(shown_energy,float(context.get("energy",99.0)),1.0-exp(-delta*13.0))
  queue_redraw()

 func _heart(center: Vector2, filled: bool, flash: bool) -> void:
  var points := PackedVector2Array()
  for i in range(49):
   var angle: float = TAU*float(i)/48.0
   var px: float = 16.0*pow(sin(angle),3.0)
   var py: float = -(13.0*cos(angle)-5.0*cos(2.0*angle)-2.0*cos(3.0*angle)-cos(4.0*angle))
   points.append(center+Vector2(px,py)*0.55)
  draw_colored_polygon(points,Color("fff0c4") if flash else Color("e2c68d") if filled else Color("192b37"))
  draw_polyline(points,Color("fff2ce") if filled else Color("657174"),1.1,true)
  if filled:
   draw_arc(center+Vector2(-3,-3),3.2,PI*1.1,PI*1.85,8,Color(1,1,.9,.42),1.0,true)

 func _flame(center: Vector2, ratio: float) -> void:
  # The glass silhouette stays stable while the inner flame and reserve change.
  var gold := Color("c4a266")
  var shell := PackedVector2Array([center+Vector2(-12,-23),center+Vector2(12,-23),center+Vector2(18,-12),center+Vector2(17,20),center+Vector2(10,25),center+Vector2(-10,25),center+Vector2(-17,20),center+Vector2(-18,-12),center+Vector2(-12,-23)])
  draw_circle(center,30,Color(0.15,.66,.75,.045+.025*sin(age*2.0)))
  draw_colored_polygon(shell,Color("0b1c28"))
  draw_polyline(shell,gold,1.5,true)
  draw_line(center+Vector2(-9,-27),center+Vector2(9,-27),gold,2,true)
  draw_arc(center+Vector2(0,-30),5,PI,TAU,15,gold,1.3,true)
  var flame_height: float = lerpf(5.0,31.0,ratio)
  var sway: float = sin(age*3.2)*1.2
  var flame := PackedVector2Array([
   center+Vector2(-9,16),center+Vector2(-11,8),center+Vector2(-7,0),
   center+Vector2(-3,7-flame_height*.40),center+Vector2(2+sway,13-flame_height),
   center+Vector2(5,3),center+Vector2(10,10),center+Vector2(8,17),center+Vector2(0,20),center+Vector2(-9,16)])
  draw_colored_polygon(flame,Color("4eb1c1") if ratio > .015 else Color("315461"))
  draw_polyline(flame,Color("a5eff0") if ratio > .015 else Color("456875"),1.0,true)
  if ratio > .015:
   var core := PackedVector2Array([center+Vector2(-4,16),center+Vector2(0,4-flame_height*.22),center+Vector2(5,15),center+Vector2(0,19)])
   draw_colored_polygon(core,Color("d5fbef"))
  draw_line(center+Vector2(-11,28),center+Vector2(11,28),gold,2,true)

 func _fitil(center: Vector2, id: String, lit: bool = true) -> void:
  var color := Color("bca574") if lit else Color("52606a")
  draw_circle(center,11,Color("122a37"))
  draw_arc(center,11,0,TAU,32,color,1.2,true)
  match id:
   "reach":
    draw_line(center+Vector2(-5,5),center+Vector2(6,-6),Color("c9eee6"),2,true)
    draw_line(center+Vector2(-5,0),center+Vector2(0,5),color,1.5,true)
   "focus":
    draw_arc(center,5,PI*.15,PI*1.8,24,Color("c9eee6"),1.5,true)
    draw_circle(center+Vector2(1,0),2,Color("e9d1a0"))
   _:
    draw_polyline(PackedVector2Array([center+Vector2(-4,5),center+Vector2(-5,0),center+Vector2(1,-7),center+Vector2(5,3),center+Vector2(2,6)]),Color("bde9dd"),1.6,true)

 func _draw() -> void:
  var backing := StyleBoxFlat.new()
  backing.bg_color = Color(0.023,0.052,0.073,0.84)
  backing.border_color = Color(.66,.58,.38,.37)
  backing.set_border_width_all(1)
  backing.set_corner_radius_all(13)
  draw_style_box(backing,Rect2(0,0,310,146))
  draw_line(Vector2(17,46),Vector2(291,46),Color(.59,.55,.41,.25),1,true)
  var hp: int = int(context.get("hp",6))
  for i in range(6): _heart(Vector2(26+i*30,26),i<hp,damage_flash>0.0 and i>=hp)
  var ratio: float = clampf(shown_energy/maxf(1.0,float(context.get("max_energy",99.0))),0,1)
  _flame(Vector2(38,89),ratio)
  var bar := Rect2(79,64,144,13)
  draw_style_box(_rounded(Color("101c27"),Color("6b725d"),5),bar)
  if ratio > .002:
   draw_style_box(_rounded(Color("67b7c2") if spend_flash <= 0 else Color("9cdce1"),Color(0,0,0,0),4),Rect2(bar.position+Vector2(2,2),Vector2(maxf(1,(bar.size.x-4)*ratio),bar.size.y-4)))
  for i in [1,2]: draw_line(Vector2(bar.position.x+bar.size.x*float(i)/3,bar.position.y+1),Vector2(bar.position.x+bar.size.x*float(i)/3,bar.end.y-1),Color("132a38"),1.5,true)
  var owned: bool = bool(context.get("spell_owned",false))
  var ready: bool = owned and float(context.get("energy",0))>=33.0
  var icon_center := Vector2(265,73)
  var icon_color := Color("a4ede5") if ready else Color("51636b")
  var diamond := PackedVector2Array([icon_center+Vector2(0,-14),icon_center+Vector2(14,0),icon_center+Vector2(0,14),icon_center+Vector2(-14,0),icon_center+Vector2(0,-14)])
  draw_colored_polygon(diamond,Color("153443") if ready else Color("101f2a"))
  draw_polyline(diamond,icon_color,1.5,true)
  if owned:
   draw_polyline(PackedVector2Array([icon_center+Vector2(-6,4),icon_center+Vector2(1,-6),icon_center+Vector2(-1,2),icon_center+Vector2(6,-3)]),icon_color,1.6,true)
  else:
   draw_arc(icon_center+Vector2(0,-2),4,PI,TAU,12,icon_color,1.1,true)
   draw_rect(Rect2(icon_center+Vector2(-4,-2),Vector2(8,7)),icon_color,false,1)
  draw_circle(Vector2(85,94),3,Color("d2b47a"))
  draw_arc(Vector2(85,94),5,0,TAU,22,Color("837752"),1,true)
  draw_string(font,Vector2(98,99),str(int(context.get("wallet",0))),HORIZONTAL_ALIGNMENT_LEFT,100,15,Color("e4d5b2"))
  var equipped: Array = context.get("equipped",[])
  for i in range(equipped.size()): _fitil(Vector2(87+i*28,124),str(equipped[i]))
  var used: int = int(context.get("used_capacity",0))
  var capacity: int = int(context.get("capacity",3))
  for i in range(mini(capacity,12)):
   draw_circle(Vector2(228+i*6,119),1.65,Color("d3bc85") if i<used else Color("40525a"))
  if bool(context.get("healing",false)):
   var fraction: float = clampf(float(context.get("heal_progress",0.0)),0,1)
   draw_arc(Vector2(38,89),32,-PI*.5,-PI*.5+TAU*fraction,50,Color("e9d6a4"),2,true)

 func _rounded(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
  var style := StyleBoxFlat.new()
  style.bg_color = bg
  style.border_color = border
  style.set_border_width_all(1)
  style.set_corner_radius_all(radius)
  return style

 func _get_tooltip(at_position: Vector2) -> String:
  if Rect2(12,49,215,60).has_point(at_position):
   return "وهج مشترك للعلاج والقدرات" if language=="ar" else "One reserve for Focus and techniques"
  if Rect2(246,54,39,42).has_point(at_position):
   if not bool(context.get("spell_owned",false)): return "تقنية لم تُكتسب بعد" if language=="ar" else "Technique not yet acquired"
   return ("القدرة جاهزة" if language=="ar" else "Technique ready") if float(context.get("energy",0))>=33.0 else ("تحتاج إلى مزيد من الوهج" if language=="ar" else "Needs more glow")
  var equipped: Array = context.get("equipped",[])
  for i in range(equipped.size()):
   if at_position.distance_to(Vector2(87+i*28,124)) <= 13:
    var info: Dictionary = FITIL_INFO.get(str(equipped[i]),{})
    return str(info.get("name_ar" if language=="ar" else "name_en",str(equipped[i])))+"\n"+str(info.get("description_ar" if language=="ar" else "description_en",""))
  return ""

func setup(world: Node2D) -> void:
 super.setup(world)
 canvas.name = "M18Presentation"
 combat_display = LanternDisplay.new()
 combat_display.name = "LiveLanternCombatHUD"
 combat_display.position = Vector2(22,16)
 combat_display.size = Vector2(310,146)
 # Keep all modal panels above the non-interactive combat display.
 canvas.add_child(combat_display)
 canvas.move_child(combat_display,canvas.get_child_count()-3)
 for child in canvas.get_children():
  if child is ColorRect and child != modal_shade and child.position.y > 500:
   _bottom_shade = child
 canvas.resized.connect(_layout_combat_header)
 _layout_combat_header()
 update_combat_status()

func _layout_combat_header() -> void:
 if not is_instance_valid(canvas): return
 var screen_size: Vector2 = canvas.size
 if screen_size.x < 1.0 or screen_size.y < 1.0: screen_size = Vector2(1280,720)
 if is_instance_valid(health_icons): health_icons.hide()
 if canvas.get_child_count()>0 and canvas.get_child(0) is ColorRect:
  canvas.get_child(0).size = Vector2(screen_size.x,114)
  canvas.get_child(0).color = Color(.025,.04,.06,.40)
 for label in [title_label,room_label,objective_label]:
  if not is_instance_valid(label): continue
  label.position.x = 355
  label.size.x = maxf(220.0,screen_size.x-697.0)
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 title_label.position.y = 15
 room_label.position.y = 40
 room_label.add_theme_font_size_override("font_size",20)
 objective_label.position.y = 76
 top_buttons.position = Vector2(screen_size.x-306,18)
 top_buttons.size = Vector2(280,40)
 status_label.position = Vector2(screen_size.x-314,66)
 status_label.text = "M18 · القتال الأول" if language=="ar" else "M18 · First combat"
 hint_label.position = Vector2((screen_size.x-1000)/2,screen_size.y-73)
 hint_label.size.y = 31
 toast_label.position = Vector2((screen_size.x-1100)/2,screen_size.y-116)
 toast_label.size.y = 40
 controls_label.position = Vector2(38,screen_size.y-31)
 controls_label.size.x = screen_size.x-76
 if is_instance_valid(_bottom_shade):
  _bottom_shade.position.y = screen_size.y-38
  _bottom_shade.size.x = screen_size.x
 if is_instance_valid(modal):
  modal.position = Vector2(maxf(16,(screen_size.x-modal.size.x)/2),maxf(16,(screen_size.y-modal.size.y)/2))

func _refresh_static() -> void:
 super._refresh_static()
 _layout_combat_header()
 _update_controls_hint()

func _snapshot() -> Dictionary:
 if not is_instance_valid(world_ref): return combat_context
 if world_ref.has_method("combat_hud_context"):
  var result: Variant = world_ref.call("combat_hud_context")
  if result is Dictionary: return result
 var result: Dictionary = combat_context.duplicate(false)
 var player: Variant = world_ref.get("hero")
 if is_instance_valid(player):
  for key in ["hp","max_hp","energy"]: result[key] = player.get(key)
  result["healing"] = bool(player.get("healing")) if "healing" in player else false
 var state: Variant = world_ref.get("combat_state")
 if is_instance_valid(state):
  if state.has_method("serialize"): result.merge(state.serialize(),true)
  if state.has_method("used_capacity"): result["used_capacity"] = state.used_capacity()
 return result

func update_combat_status(context: Dictionary = {}) -> void:
 combat_context = _snapshot() if context.is_empty() else context.duplicate(false)
 if is_instance_valid(combat_display): combat_display.update_context(combat_context,language)
 _update_controls_hint()

func update_status(room: Dictionary, progress: Dictionary, hint_key: String = "", hint_args: Array = []) -> void:
 super.update_status(room,progress,hint_key,hint_args)
 _layout_combat_header()
 if is_instance_valid(hint_label) and not hint_key.is_empty():
  hint_label.text = _hint("interact","E")+"  ·  "+t(hint_key,hint_args)
 update_combat_status()
 var room_id: int = int(room.get("id",1))
 if room_id == 2:
  objective_label.text = t("objective_continue") if bool(progress.get("encounter_assignments_cleared",false)) else ("راقب انكماش اليرقة، تفادَ الاندفاع، ثم اضرب." if language=="ar" else "Watch the larva wind up, evade, then strike.")
 elif room_id == 1 and bool(progress.get("weapon_owned",false)) and not bool(combat_context.get("dash_owned",false)):
  objective_label.text = "ابحث عن اندفاع الفانوس قبل الدرج." if language=="ar" else "Find the lantern dash before the stairs."

func _process(delta: float) -> void:
 super._process(delta)
 if is_instance_valid(combat_display): combat_display.update_context(_snapshot(),language)

func _hint(action_name: String, fallback: String) -> String:
 if is_instance_valid(world_ref) and world_ref.has_method("control_hint"):
  return str(world_ref.call("control_hint",action_name))
 return fallback

func _update_controls_hint() -> void:
 if not is_instance_valid(controls_label): return
 var captions: Array = ["ضرب","قفز","داش","علاج","قدرة","تفاعل","خريطة"] if language=="ar" else ["Attack","Jump","Dash","Focus","Technique","Interact","Map"]
 var actions: Array = ["attack","jump","dash","heal","spell","interact","stage_map"]
 var defaults: Array = ["J","SPACE","K","H","L","E","M"]
 var parts: PackedStringArray = []
 for i in range(actions.size()): parts.append(_hint(str(actions[i]),str(defaults[i]))+"  "+str(captions[i]))
 var value: String = "     ".join(parts)
 if value != _controls_signature:
  _controls_signature = value
  controls_label.text = value
  controls_label.text_direction = Control.TEXT_DIRECTION_AUTO

func _note_panel() -> void:
 match current_panel:
  "fitils": _fitils_panel()
  "controls": _controls_panel()
  _: super._note_panel()

func _pause_panel() -> void:
 modal_title.text = "استراحة" if language=="ar" else "Pause"
 _paragraph(modal_body,t("world_title"),25)
 _paragraph(modal_body,"M18 · يرقة الخلل وأساس القتال" if language=="ar" else "M18 · Glitch Larva and combat foundations",16)
 var at_bench: bool = bool(_panel_combat().get("at_bench",false))
 _button(modal_body,"الفانوس والفتائل" if language=="ar" else "Lantern and fitils",func(): action.emit("fitils",null),not at_bench)
 if not at_bench:
  _paragraph(modal_body,"تُغيّر الفتائل عند المقعد فقط." if language=="ar" else "Change fitils at a bench.",14).modulate.a = .68
 _button(modal_body,"التحكم وتعيين الأزرار" if language=="ar" else "Controls and bindings",func(): action.emit("controls",null))
 _button(modal_body,t("journal"),func(): action.emit("journal",null))
 _button(modal_body,t("restart"),func(): open_panel("restart",panel_context))
 _defer_focus(_button(modal_footer,t("resume"),_request_close))

func _panel_combat() -> Dictionary:
 var value: Variant = panel_context.get("combat",panel_context.get("combat_state",{}))
 if value is Dictionary and not value.is_empty(): return value
 return _snapshot()

func _fitil_info(id: String) -> Dictionary:
 var all: Variant = _panel_combat().get("catalog",FITIL_INFO)
 if all is Dictionary and all.get(id,{}) is Dictionary: return all.get(id,{})
 return FITIL_INFO.get(id,{})

func _fitils_panel() -> void:
 modal_title.text = "الفانوس والفتائل" if language=="ar" else "Lantern and fitils"
 var state: Dictionary = _panel_combat()
 var equipped: Array = state.get("equipped",[])
 var owned: Array = state.get("owned",[])
 var at_bench: bool = bool(state.get("at_bench",false))
 var used: int = 0
 for id in equipped: used += int(_fitil_info(str(id)).get("cost",1))
 var capacity: int = int(state.get("capacity",3))
 var capacity_text: String = "سعة الفانوس: %d / %d" if language=="ar" else "Lantern capacity: %d / %d"
 _paragraph(modal_body,capacity_text % [used,capacity],21).add_theme_color_override("font_color",CYAN)
 _paragraph(modal_body,"التركيب مجاني عند المقعد. القدرات الدائمة لا تستهلك سعة." if language=="ar" else "Equip freely at a bench. Permanent abilities do not consume capacity.",15)
 if owned.is_empty(): _paragraph(modal_body,"لم تجمع فتيلًا بعد. ابحث بين رفوف المكتبة." if language=="ar" else "No fitil collected yet. Search among the library shelves.",20)
 var first: Button
 for value in owned:
  var id: String = str(value)
  var info: Dictionary = _fitil_info(id)
  var card := PanelContainer.new()
  card.add_theme_stylebox_override("panel",_style(Color("142b38"),Color("6b765f") if equipped.has(id) else Color("344a54"),7,12))
  modal_body.add_child(card)
  var row := HBoxContainer.new()
  row.add_theme_constant_override("separation",14)
  _localize(row)
  card.add_child(row)
  var words := VBoxContainer.new()
  words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  row.add_child(words)
  var name_value: String = str(info.get("name_ar" if language=="ar" else "name_en",id))
  _paragraph(words,name_value+"  ·  "+str(int(info.get("cost",1))),18).custom_minimum_size.y = 25
  _paragraph(words,str(info.get("description_ar" if language=="ar" else "description_en","")),14).custom_minimum_size.y = 28
  var is_equipped: bool = equipped.has(id)
  var button: Button = _button(row,("إزالة" if is_equipped else "تركيب") if language=="ar" else ("Remove" if is_equipped else "Equip"),func(): action.emit("unequip_fitil" if is_equipped else "equip_fitil",id),not at_bench or (not is_equipped and used+int(info.get("cost",1))>capacity))
  if first == null and not button.disabled: first = button
 var close_button: Button = _button(modal_footer,t("close"),_request_close)
 _defer_focus(first if first != null else close_button)

func _controls_panel() -> void:
 modal_title.text = "التحكم" if language=="ar" else "Controls"
 _paragraph(modal_body,"الكيبورد ويد التحكم متاحان. اختر زرًا لتعيين بديله، أو Esc للإلغاء." if language=="ar" else "Keyboard and controller are supported. Select a binding, then press its replacement; Esc cancels.",16)
 var awaiting: String = str(panel_context.get("awaiting_action",""))
 if not awaiting.is_empty(): _paragraph(modal_body,"اضغط الزر الجديد…" if language=="ar" else "Press the new binding…",20).add_theme_color_override("font_color",CYAN)
 var bindings: Array = panel_context.get("bindings",[])
 var first: Button
 for record in bindings:
  if not record is Dictionary: continue
  var action_name: String = str(record.get("action",""))
  var row := HBoxContainer.new()
  row.add_theme_constant_override("separation",20)
  _localize(row)
  modal_body.add_child(row)
  var label: Label = _paragraph(row,str(record.get("label_ar" if language=="ar" else "label_en",action_name)),17)
  label.custom_minimum_size.y = 42
  label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  var button: Button = _button(row,str(record.get("binding",_hint(action_name,"—"))),func(): action.emit("rebind",action_name),not awaiting.is_empty())
  button.custom_minimum_size.x = 190
  if first == null: first = button
 if bindings.is_empty(): _paragraph(modal_body,controls_label.text,17)
 _button(modal_footer,"استعادة الافتراضي" if language=="ar" else "Restore defaults",func(): action.emit("reset_bindings",null),not awaiting.is_empty())
 var close_button: Button = _button(modal_footer,t("close"),_request_close)
 _defer_focus(first if first != null and awaiting.is_empty() else close_button)
