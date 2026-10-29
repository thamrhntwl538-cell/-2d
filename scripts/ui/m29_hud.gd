extends "res://scripts/ui/m28_hud.gd"
## A seated loadout sheet. The world owns seating, equipment and persistence;
## this view only selects real inventory and emits validated action requests.
const FITIL_ORDER := ["wick","reach","focus"]
var bench_tab := "fitils"
var bench_selection := "wick"
var bench_inventory_selection := "lantern"
var bench_shell: PanelContainer
var bench_rest_hint: Label
var bench_buttons: Dictionary = {}
var bench_tab_buttons: Dictionary = {}
var bench_detail_title: Label
var bench_detail_copy: Label
var bench_detail_meta: Label
var bench_notice_label: Label
var bench_action: Button
var bench_capacity: Control
var _bench_tween: Tween
var _detail_tween: Tween
var _equip_tween: Tween
var _bench_base_position := Vector2.ZERO
var _bench_hidden_controls: Array[Dictionary] = []
var _interior_hidden_controls: Array[Dictionary] = []
var _bench_notice := ""
var _bench_rest_context: Dictionary = {}
var _bench_size := Vector2.ZERO

class FitilIcon extends Control:
	var identity := "wick"
	var owned := true
	var equipped := false
	var icon_scale := 1.0
	func _draw() -> void:
		var c := size*.5
		var scale_value := minf(size.x,size.y)/64.0*icon_scale
		draw_set_transform(c,0,Vector2.ONE*scale_value)
		var gold := Color("e5c491") if owned else Color("515565")
		var ember := Color("f3ae60") if owned else Color("414651")
		draw_circle(Vector2.ZERO,24,Color("192334") if owned else Color("111926"))
		draw_arc(Vector2.ZERO,24,0,TAU,56,gold,1.2,true)
		if equipped:
			draw_arc(Vector2.ZERO,28,.12,PI-.12,30,Color("fae7bd"),1.8,true)
			draw_arc(Vector2.ZERO,28,PI+.12,TAU-.12,30,Color("fae7bd"),1.8,true)
		if not owned:
			draw_circle(Vector2.ZERO,3,gold)
			for angle in [0.0,PI*.5,PI,PI*1.5]:
				draw_line(Vector2.from_angle(angle)*10,Vector2.from_angle(angle)*14,gold,1.4,true)
		else:
			match identity:
				"reach","blade":
					draw_line(Vector2(-10,12),Vector2(11,-13),Color("f9e2b0"),3.5,true)
					draw_line(Vector2(-12,4),Vector2(-4,11),gold,2,true)
					draw_line(Vector2(1,-1),Vector2(13,-10),ember,1.6,true)
				"focus":
					draw_arc(Vector2.ZERO,12,-PI*.35,PI*1.27,36,gold,2.3,true)
					draw_circle(Vector2(2,1),5,ember)
					draw_line(Vector2(-5,-15),Vector2(1,-19),Color("f6ddb0"),1.4,true)
				"map","atlas":
					var page := PackedVector2Array([Vector2(-15,-12),Vector2(-5,-9),Vector2(5,-12),Vector2(15,-9),Vector2(15,13),Vector2(5,10),Vector2(-5,13),Vector2(-15,10),Vector2(-15,-12)])
					draw_polyline(page,gold,1.7,true)
					for x in [-5.0,5.0]: draw_line(Vector2(x,-9),Vector2(x,10),ember,1.2,true)
					if identity=="atlas": draw_circle(Vector2(8,1),2.8,Color("fff0d0"))
				"pagefinder":
					draw_arc(Vector2.ZERO,14,0,TAU,40,gold,1.2,true)
					draw_colored_polygon(PackedVector2Array([Vector2(0,-16),Vector2(5,6),Vector2(0,2),Vector2(-5,6)]),ember)
				"dash":
					for i in range(3):
						var x := -12.0+float(i)*10
						draw_polyline(PackedVector2Array([Vector2(x-5,-8),Vector2(x+3,0),Vector2(x-5,8)]),gold,2.4,true)
				"spell":
					draw_arc(Vector2(-1,1),13,-PI*.8,PI*.5,40,gold,3,true)
					draw_circle(Vector2(10,-10),3.5,ember)
				_:
					var flame := PackedVector2Array([Vector2(0,-18),Vector2(8,-5),Vector2(10,5),Vector2(5,14),Vector2(-5,14),Vector2(-11,7),Vector2(-8,-3),Vector2(-3,4),Vector2(0,-18)])
					draw_colored_polygon(flame,ember)
					draw_colored_polygon(PackedVector2Array([Vector2(1,-4),Vector2(5,8),Vector2(0,12),Vector2(-4,7),Vector2(1,-4)]),Color("fff0c9"))
		draw_set_transform(Vector2.ZERO)

class Sockets extends Control:
	var capacity := 3
	var used := 0
	func _draw() -> void:
		var gap := minf(36,(size.x-12)/float(maxi(1,capacity)))
		var start := size.x*.5-float(capacity-1)*gap*.5
		for i in range(mini(capacity,12)):
			var c := Vector2(start+float(i)*gap,size.y*.5)
			draw_circle(c,8,Color("192636"))
			draw_arc(c,8,0,TAU,32,Color("ab926b") if i<used else Color("647082"),1.2,true)
			if i<used:
				draw_colored_polygon(PackedVector2Array([c+Vector2(0,-6),c+Vector2(4,1),c+Vector2(0,5),c+Vector2(-4,1)]),Color("f0c58b"))

func setup(world: Node2D) -> void:
	super.setup(world)
	canvas.name="SeatedLanternAndInventoryHUD"
	bench_shell=PanelContainer.new()
	bench_shell.name="SeatedLoadoutSheet"
	bench_shell.add_theme_stylebox_override("panel",_bench_style(Color(.035,.051,.078,.97),Color("8d7956"),16,16))
	bench_shell.hide()
	canvas.add_child(bench_shell)
	bench_rest_hint=_label(canvas,"",Vector2.ZERO,Vector2.ZERO,15)
	bench_rest_hint.name="SeatedRestInstructions"
	bench_rest_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	bench_rest_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	bench_rest_hint.add_theme_color_override("font_color",Color("e4ceaa"))
	bench_rest_hint.add_theme_color_override("font_shadow_color",Color(0,0,0,.95))
	bench_rest_hint.add_theme_constant_override("shadow_offset_y",2)
	bench_rest_hint.hide()

func _layout_combat_header() -> void:
	super._layout_combat_header()
	if is_instance_valid(status_label): status_label.hide()

func t(key: String,args: Array=[]) -> String:
	if key=="environment_build": return "رحلتك بين الرفوف" if language=="ar" else "Your Journey Between the Shelves"
	return super.t(key,args)

func _process(delta: float) -> void:
	super._process(delta)
	_apply_interior_quiet()
	if (panel_open and current_panel=="bench") or _bench_busy():
		for node in [title_label,room_label,objective_label,top_buttons,hint_label,controls_label,toast_label,page_needle]:
			if is_instance_valid(node): node.hide()

func update_status(room: Dictionary,progress: Dictionary,hint_key: String="",hint_args: Array=[]) -> void:
	super.update_status(room,progress,hint_key,hint_args)
	_apply_interior_quiet()

func _apply_interior_quiet() -> void:
	var kind: Variant=world_ref.get("interior_kind") if is_instance_valid(world_ref) else null
	if kind is String and not kind.is_empty():
		for control in [title_label,room_label,objective_label,top_buttons,controls_label,page_needle]:
			if not is_instance_valid(control): continue
			if _interior_hidden_controls.is_empty() or not _interior_hidden_controls.any(func(entry):return entry.control==control):
				_interior_hidden_controls.append({"control":control,"visible":control.visible})
			control.hide()
	elif not _interior_hidden_controls.is_empty():
		for entry in _interior_hidden_controls:
			if is_instance_valid(entry.control): entry.control.visible=bool(entry.visible)
		_interior_hidden_controls.clear()

func _is_bench_kind(kind: String,context: Dictionary={}) -> bool:
	return kind=="bench" or (kind=="fitils" and bool(context.get("bench",{}).get("seated",false)))

func open_panel(kind: String, context: Dictionary={}) -> void:
	if not _is_bench_kind(kind,context):
		if is_instance_valid(bench_shell): bench_shell.hide()
		_restore_bench_controls()
		modal_shade.color=Color(.008,.017,.026,.84)
		super.open_panel(kind,context)
		return
	if is_instance_valid(_panel_tween): _panel_tween.kill()
	if is_instance_valid(_bench_tween): _bench_tween.kill()
	panel_context=context.duplicate(false)
	current_panel="bench"
	panel_open=true
	closing_panel=false
	_bench_notice=""
	modal.hide()
	modal_shade.color=Color(.006,.011,.024,.30)
	modal_shade.modulate.a=0
	modal_shade.show()
	_hide_bench_controls()
	bench_rest_hint.hide()
	_rebuild_bench()
	bench_shell.modulate.a=0
	bench_shell.position=_bench_base_position+Vector2(-18 if _bench_base_position.x<100 else 18,0)
	bench_shell.show()
	_bench_tween=create_tween().set_parallel(true)
	_bench_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_bench_tween.tween_property(bench_shell,"modulate:a",1.0,.24)
	_bench_tween.tween_property(bench_shell,"position",_bench_base_position,.28)
	_bench_tween.tween_property(modal_shade,"modulate:a",1.0,.24)

func close_panel(immediate: bool=false) -> void:
	if current_panel!="bench":
		super.close_panel(immediate)
		return
	if closing_panel and not immediate: return
	if is_instance_valid(_bench_tween): _bench_tween.kill()
	if immediate:
		_finish_bench_close()
		return
	closing_panel=true
	_bench_tween=create_tween().set_parallel(true)
	_bench_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_bench_tween.tween_property(bench_shell,"modulate:a",0.0,.17)
	_bench_tween.tween_property(modal_shade,"modulate:a",0.0,.17)
	_bench_tween.tween_property(bench_shell,"position",_bench_base_position+Vector2(-12 if _bench_base_position.x<100 else 12,0),.17)
	_bench_tween.chain().tween_callback(_finish_bench_close)

func _finish_bench_close() -> void:
	bench_shell.hide()
	bench_shell.modulate.a=1
	modal_shade.hide()
	modal_shade.modulate.a=1
	modal_shade.color=Color(.008,.017,.026,.84)
	panel_open=false
	current_panel=""
	closing_panel=false
	_restore_bench_controls()
	panel_closed.emit()
	update_bench_rest(_bench_rest_context)

func _request_close() -> void:
	if current_panel=="bench":
		if not closing_panel: action.emit("bench_close",null)
	else: super._request_close()

func refresh_panel(context: Dictionary={}) -> void:
	if current_panel=="bench":
		var previous: Array=_bench_combat().get("equipped",[]).duplicate()
		if not context.is_empty(): panel_context=context.duplicate(false)
		_rebuild_bench()
		if previous!=_bench_combat().get("equipped",[]) and bench_buttons.has(bench_selection):
			var button: Button=bench_buttons[bench_selection]
			button.modulate=Color(1.3,1.18,.94)
			_equip_tween=create_tween()
			_equip_tween.tween_property(button,"modulate",Color.WHITE,.26)
	else: super.refresh_panel(context)

func _rebuild_panel() -> void:
	if current_panel=="bench": _rebuild_bench()
	else: super._rebuild_panel()

func _bench_style(bg: Color,border: Color,radius: int,pad: int=10) -> StyleBoxFlat:
	var value:=StyleBoxFlat.new()
	value.bg_color=bg
	value.border_color=border
	value.set_border_width_all(1)
	value.set_corner_radius_all(radius)
	value.content_margin_left=pad
	value.content_margin_right=pad
	value.content_margin_top=pad
	value.content_margin_bottom=pad
	return value

func _bench_button(parent: Node, caption: String, call: Callable) -> Button:
	var button:=_button(parent,caption,call)
	button.add_theme_stylebox_override("normal",_bench_style(Color("142031"),Color("566074"),9,8))
	button.add_theme_stylebox_override("hover",_bench_style(Color("263247"),Color("c7aa78"),9,8))
	button.add_theme_stylebox_override("pressed",_bench_style(Color("354255"),Color("ecd1a0"),9,8))
	button.add_theme_stylebox_override("focus",_bench_style(Color(0,0,0,0),Color("f0d9ad"),9,8))
	button.add_theme_color_override("font_color",Color("dfd2bb"))
	button.add_theme_font_size_override("font_size",14)
	button.custom_minimum_size.y=34
	return button

func _bench_combat() -> Dictionary:
	var c: Variant=panel_context.get("combat",{})
	return c if c is Dictionary else {}

func _screen_size() -> Vector2:
	var value:=get_viewport().get_visible_rect().size
	return value if value.x>10 and value.y>10 else Vector2(1280,720)

func _bench_permission() -> bool:
	var bench: Dictionary=panel_context.get("bench",{})
	return bool(bench.get("seated",false)) and bool(bench.get("can_equip",true)) and bool(_bench_combat().get("at_bench",false))

func _rebuild_bench() -> void:
	if not is_instance_valid(bench_shell): return
	if is_instance_valid(_equip_tween): _equip_tween.kill()
	if is_instance_valid(_detail_tween): _detail_tween.kill()
	for child in bench_shell.get_children():
		bench_shell.remove_child(child)
		child.queue_free()
	bench_buttons.clear()
	bench_tab_buttons.clear()
	var screen:=_screen_size()
	var width_value:=minf(572,screen.x*.47)
	var height_value:=minf(488 if bench_tab=="fitils" else 558,screen.y-145)
	var hero_x:=screen.x*.72
	if is_instance_valid(world_ref) and is_instance_valid(world_ref.get("hero")):
		hero_x=world_ref.hero.get_global_transform_with_canvas().origin.x
	var left:=hero_x>=screen.x*.5
	_bench_base_position=Vector2(28 if left else screen.x-width_value-28,maxf(112,minf(142,screen.y-height_value-30)))
	_bench_size=Vector2(width_value,height_value)
	bench_shell.position=_bench_base_position
	bench_shell.size=_bench_size
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	bench_shell.add_child(column)
	var header:=HBoxContainer.new()
	_localize(header)
	column.add_child(header)
	var title:=_paragraph(header,"وهجٌ يستقر" if language=="ar" else "A Quiet Flame",23)
	title.custom_minimum_size.y=30
	title.add_theme_color_override("font_color",Color("e9d0a2"))
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var lang:=_bench_button(header,"EN" if language=="ar" else "عربي",func(): action.emit("language","en" if language=="ar" else "ar"))
	lang.custom_minimum_size=Vector2(56,34)
	var tabs:=HBoxContainer.new()
	_localize(tabs)
	tabs.add_theme_constant_override("separation",8)
	column.add_child(tabs)
	for id in ["fitils","inventory"]:
		var caption: String=("الفانوس والفتائل" if language=="ar" else "Lantern & Wicks") if id=="fitils" else ("المقتنيات" if language=="ar" else "Inventory")
		var tab:=_bench_button(tabs,caption,func(): _set_bench_tab(id))
		tab.name="BenchTab_"+id
		tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		if bench_tab==id: tab.add_theme_stylebox_override("normal",_bench_style(Color("354152"),Color("c8aa76"),9,8))
		bench_tab_buttons[id]=tab
	if bench_tab=="fitils": _build_fitils(column)
	else: _build_inventory(column)
	var footer:=HBoxContainer.new()
	_localize(footer)
	footer.add_theme_constant_override("separation",10)
	column.add_child(footer)
	var close:=_bench_button(footer,"إغلاق القائمة" if language=="ar" else "Close Menu",_request_close)
	close.name="BenchClose"
	close.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var stand:=_bench_button(footer,"النهوض" if language=="ar" else "Stand Up",func(): action.emit("bench_stand",null))
	stand.name="BenchStand"
	stand.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var help:=_paragraph(column,"Tab / LB / RB  ·  الصفحات     A / Enter  ·  اختيار     B / Esc  ·  إغلاق" if language=="ar" else "Tab / LB / RB · Pages     A / Enter · Select     B / Esc · Close",12)
	help.text_direction=Control.TEXT_DIRECTION_LTR
	help.modulate.a=.64
	help.custom_minimum_size.y=14
	_defer_focus(bench_buttons.get(bench_selection if bench_tab=="fitils" else bench_inventory_selection,close))

func _build_fitils(column: VBoxContainer) -> void:
	var c:=_bench_combat()
	var meter_row:=HBoxContainer.new()
	_localize(meter_row)
	column.add_child(meter_row)
	var status:=_paragraph(meter_row,("السعة: %d من %d" if language=="ar" else "Capacity  %d / %d") % [int(c.get("used_capacity",0)),int(c.get("capacity",3))],15)
	status.custom_minimum_size=Vector2(150,28)
	var sockets:=Sockets.new()
	sockets.name="EquippedCapacitySockets"
	sockets.capacity=int(c.get("capacity",3))
	sockets.used=int(c.get("used_capacity",0))
	sockets.custom_minimum_size=Vector2(180,28)
	sockets.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	meter_row.add_child(sockets)
	bench_capacity=sockets
	var grid:=GridContainer.new()
	grid.columns=3
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",8)
	_localize(grid)
	column.add_child(grid)
	for id in FITIL_ORDER:
		var owned: bool=c.get("owned",[]).has(id)
		var equipped: bool=c.get("equipped",[]).has(id)
		var name_value: String=str(FITIL_INFO[id]["name_"+language]) if owned else ("غير مكتشف" if language=="ar" else "Undiscovered")
		var button:=_bench_button(grid,"",func(): _select_bench_item(id,"fitils"); _activate_bench_fitil())
		button.name="BenchFitil_"+id
		button.set_meta("fitil_id",id)
		button.custom_minimum_size=Vector2(maxf(100,(_bench_size.x-68)/3),88)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.focus_entered.connect(func(): _select_bench_item(id,"fitils"))
		var icon:=FitilIcon.new()
		icon.identity=id
		icon.owned=owned
		icon.equipped=equipped
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		icon.position=Vector2((button.custom_minimum_size.x-50)*.5,4)
		icon.size=Vector2(50,50)
		button.add_child(icon)
		var label:=_label(button,name_value,Vector2(3,58),Vector2(button.custom_minimum_size.x-6,24),13)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		bench_buttons[id]=button
	_build_details(column)
	_select_bench_item(bench_selection,"fitils",false)

func _inventory_entries() -> Array[Dictionary]:
	var c:=_bench_combat()
	var progress: Dictionary=panel_context.get("progress",panel_context.get("state",{}))
	var entries: Array[Dictionary]=[
		{"id":"lantern","ar":"فانوس الحارس","en":"Warden's Lantern","body_ar":"وهج واحد للعلاج والتقنيات. يستمد قوته من إصابات السيف الناجحة.","body_en":"One reserve for Focus and techniques, replenished by successful sword hits."},
		{"id":"map","ar":"خريطة الممرات","en":"Passage Map","body_ar":"تحفظ المناطق التي اكتشفتها ومسارات العودة المفتوحة. الخريطة الأساسية لا تحتاج شراءً.","body_en":"Keeps discovered places and opened return routes. The basic map needs no purchase."}
	]
	if bool(progress.get("weapon_owned",false)):
		entries.append({"id":"blade","ar":"نصل الجمر","en":"Ember Blade","body_ar":"نصل الحارس القصير. وجّه ضرباته إلى الأمام أو أعلى، وإلى أسفل في الهواء.","body_en":"The Warden's compact blade. Strike ahead or upward, and downward in the air."})
	if bool(c.get("dash_owned",false)):
		entries.append({"id":"dash","ar":"اندفاع الفانوس","en":"Lantern Dash","body_ar":"اندفاع قصير لتغيير موضعك. يتجدد في الهواء بعد الهبوط أو ارتداد سفلي ناجح.","body_en":"A short dash for repositioning. Its air use returns on landing or a valid downward bounce."})
	if bool(c.get("spell_owned",false)):
		entries.append({"id":"spell","ar":"شق الحبر","en":"Ink Cleave","body_ar":"تقنية تستخدم من الوهج نفسه الذي يُنفق على العلاج.","body_en":"A technique that spends the same glow used for Focus."})
	var bought: Array=progress.get("m28_shop",{}).get("purchases",[])
	if bought.has("atlas"):
		entries.append({"id":"atlas","ar":"أطلس الممرات","en":"Passage Atlas","body_ar":"يضيف علامات الاستراحات والمتجر وغرف الحراس إلى المناطق المكتشفة.","body_en":"Marks rests, the market and keeper chambers in discovered areas."})
	if bought.has("pagefinder"):
		entries.append({"id":"pagefinder","ar":"إبرة الفهرس","en":"Index Needle","body_ar":"تشير إلى صفحة قريبة لم تُقرأ. تختفي الإشارة أثناء القتال والقراءة.","body_en":"Points toward a nearby unread page. Guidance fades during combat and reading."})
	return entries

func _build_inventory(column: VBoxContainer) -> void:
	var entries:=_inventory_entries()
	var scroll:=ScrollContainer.new()
	scroll.name="BenchOwnedInventoryScroll"
	scroll.follow_focus=true
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y=158
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var grid:=GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",8)
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_localize(grid)
	scroll.add_child(grid)
	for entry in entries:
		var id:=str(entry.id)
		var button:=_bench_button(grid,"",func(): _select_bench_item(id,"inventory"))
		button.name="BenchOwned_"+id
		button.set_meta("inventory_id",id)
		button.custom_minimum_size=Vector2(maxf(150,(_bench_size.x-62)/2),78)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.focus_entered.connect(func(): _select_bench_item(id,"inventory"))
		var icon:=FitilIcon.new()
		icon.identity=id
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		icon.position=Vector2(5,10)
		icon.size=Vector2(52,52)
		button.add_child(icon)
		var label:=_label(button,str(entry[language]),Vector2(60,14),Vector2(button.custom_minimum_size.x-66,51),13)
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		bench_buttons[id]=button
	_build_details(column)
	if not bench_buttons.has(bench_inventory_selection): bench_inventory_selection="lantern"
	_select_bench_item(bench_inventory_selection,"inventory",false)

func _build_details(column: VBoxContainer) -> void:
	var detail:=PanelContainer.new()
	detail.name="BenchSelectedDescription"
	detail.custom_minimum_size.y=120
	detail.size_flags_vertical=Control.SIZE_EXPAND_FILL
	detail.add_theme_stylebox_override("panel",_bench_style(Color("0f1929"),Color("414653"),8,10))
	column.add_child(detail)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",4)
	detail.add_child(box)
	bench_detail_title=_paragraph(box,"",18)
	bench_detail_title.custom_minimum_size.y=22
	bench_detail_title.add_theme_color_override("font_color",Color("efd3a0"))
	bench_detail_copy=_paragraph(box,"",14)
	bench_detail_copy.custom_minimum_size.y=38
	bench_detail_meta=_paragraph(box,"",12)
	bench_detail_meta.custom_minimum_size.y=16
	bench_detail_meta.modulate.a=.75
	bench_notice_label=_paragraph(box,"",12)
	bench_notice_label.custom_minimum_size.y=17
	bench_notice_label.add_theme_color_override("font_color",Color("e8b59a"))
	bench_notice_label.hide()
	bench_action=_bench_button(box,"",_activate_bench_fitil)
	bench_action.name="BenchEquipSelected"
	bench_action.custom_minimum_size.y=30
	bench_action.visible=bench_tab=="fitils"

func _select_bench_item(id: String, tab: String, animate: bool=true) -> void:
	if not is_instance_valid(bench_detail_title): return
	if tab=="fitils":
		if bench_selection!=id: _bench_notice=""
		bench_selection=id
		var c:=_bench_combat()
		var owned: bool=c.get("owned",[]).has(id)
		var equipped: bool=c.get("equipped",[]).has(id)
		bench_detail_title.text=str(FITIL_INFO[id]["name_"+language]) if owned else ("فتيل لم تكتشفه" if language=="ar" else "An Undiscovered Wick")
		bench_detail_copy.text=str(FITIL_INFO[id]["description_"+language]) if owned else ("هناك وهج ينتظر أن تعثر عليه بين صفحات العالم." if language=="ar" else "Another glow waits among the world's pages.")
		var cost:=int(FITIL_INFO[id].cost)
		bench_detail_meta.text=("الكلفة: %d  ·  %s" if language=="ar" else "Cost: %d  ·  %s") % [cost,("مجهّز" if language=="ar" else "Equipped") if equipped else ("في مقتنياتك" if language=="ar" else "In your collection") if owned else ("غير مكتشف" if language=="ar" else "Undiscovered")]
		bench_action.text=("نزع الفتيل" if language=="ar" else "Unequip Wick") if equipped else ("تركيب الفتيل" if language=="ar" else "Equip Wick")
		bench_action.disabled=not owned
		if owned and not equipped and int(c.get("used_capacity",0))+cost>int(c.get("capacity",3)):
			bench_detail_meta.text+="  ·  "+("السعة غير كافية" if language=="ar" else "Not enough capacity")
	else:
		bench_inventory_selection=id
		for entry in _inventory_entries():
			if str(entry.id)!=id: continue
			bench_detail_title.text=str(entry[language])
			bench_detail_copy.text=str(entry["body_"+language])
			bench_detail_meta.text="من مقتنيات الرحلة" if language=="ar" else "Kept for your journey"
	bench_notice_label.text=_bench_notice
	bench_notice_label.visible=not _bench_notice.is_empty()
	if animate:
		if is_instance_valid(_detail_tween): _detail_tween.kill()
		bench_detail_title.modulate.a=.35
		_detail_tween=create_tween()
		_detail_tween.tween_property(bench_detail_title,"modulate:a",1.0,.14)

func _activate_bench_fitil() -> void:
	if current_panel!="bench" or closing_panel or bench_tab!="fitils": return
	var c:=_bench_combat()
	if not _bench_permission():
		show_bench_message("اجلس عند المقعد لتغيير الفتائل.","Sit at the bench to change wicks.")
		return
	if not c.get("owned",[]).has(bench_selection):
		show_bench_message("هذا الفتيل غير موجود في مقتنياتك بعد.","This wick is not in your collection yet.")
		return
	var equipped: bool=c.get("equipped",[]).has(bench_selection)
	var cost:=int(FITIL_INFO[bench_selection].cost)
	if not equipped and int(c.get("used_capacity",0))+cost>int(c.get("capacity",3)):
		show_bench_message("السعة لا تكفي. انزع فتيلًا آخر أولًا.","Not enough capacity. Unequip another wick first.")
		return
	_bench_notice=""
	action.emit("unequip_fitil" if equipped else "equip_fitil",bench_selection)

func _set_bench_tab(value: String) -> void:
	if value not in ["fitils","inventory"] or closing_panel: return
	bench_tab=value
	_bench_notice=""
	_rebuild_bench()

func set_bench_context(context: Dictionary) -> void:
	panel_context=context.duplicate(false)
	if panel_open and current_panel=="bench": _rebuild_bench()

func show_bench_message(arabic: String,english: String) -> void:
	_bench_notice=arabic if language=="ar" else english
	if is_instance_valid(bench_notice_label):
		bench_notice_label.text=_bench_notice
		bench_notice_label.show()

func update_bench_rest(context: Dictionary={}) -> void:
	_bench_rest_context=context.duplicate(false)
	if not is_instance_valid(bench_rest_hint): return
	var seated:=bool(context.get("bench",context).get("seated",false))
	bench_rest_hint.visible=seated and not panel_open and not closing_panel
	if _bench_busy(): _hide_bench_controls()
	elif current_panel!="bench": _restore_bench_controls()
	if not seated:
		return
	var screen:=_screen_size()
	bench_rest_hint.position=Vector2(30,screen.y-82)
	bench_rest_hint.size=Vector2(screen.x-60,47)
	var rise:=_hint("jump","Space")+" / "+_hint("interact","E")
	var controls: Variant=world_ref.get("controls") if is_instance_valid(world_ref) else null
	var gear: String="Y" if controls is RefCounted and bool(controls.get("gamepad")) else "I / Tab"
	bench_rest_hint.text=("%s  ·  الفانوس والمقتنيات     %s  ·  النهوض" if language=="ar" else "%s · Lantern & Inventory     %s · Stand Up") % [gear,rise]
	bench_rest_hint.text_direction=Control.TEXT_DIRECTION_LTR
	if bool(context.get("bench",context).get("saved",false)):
		bench_rest_hint.text=("حُفظت الرحلة\n" if language=="ar" else "Journey saved\n")+bench_rest_hint.text

func _bench_busy() -> bool:
	var bench: Dictionary=_bench_rest_context.get("bench",_bench_rest_context)
	return bool(bench.get("seated",false)) or bool(bench.get("active",false)) or str(bench.get("state","idle")) not in ["","idle"]

func _hide_bench_controls() -> void:
	if not _bench_hidden_controls.is_empty(): return
	for node in [title_label,room_label,objective_label,top_buttons,hint_label,controls_label,toast_label,page_needle]:
		if is_instance_valid(node):
			_bench_hidden_controls.append({"control":node,"visible":node.visible})
			node.hide()

func _restore_bench_controls() -> void:
	for item in _bench_hidden_controls:
		if is_instance_valid(item.control): item.control.visible=bool(item.visible)
	_bench_hidden_controls.clear()

func _input(event: InputEvent) -> void:
	# Tab is normally consumed by GUI focus traversal before unhandled input.
	# Page changes belong to the seated sheet first; arrows and confirm remain
	# normal Control navigation and never reach this interception.
	if not panel_open or current_panel!="bench" or closing_panel: return
	# A consumed cancel/page event must still update the device-aware rest hint.
	var controls: Variant=world_ref.get("controls") if is_instance_valid(world_ref) else null
	if controls is RefCounted:
		if event is InputEventJoypadButton and event.pressed: controls.set("gamepad",true)
		elif event is InputEventKey and event.pressed: controls.set("gamepad",false)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_TAB,KEY_PAGEUP,KEY_PAGEDOWN]:
			_set_bench_tab("inventory" if bench_tab=="fitils" else "fitils")
			get_viewport().set_input_as_handled()
		elif event.keycode==KEY_ESCAPE:
			_request_close()
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]:
			_set_bench_tab("inventory" if bench_tab=="fitils" else "fitils")
			get_viewport().set_input_as_handled()
		elif event.button_index==JOY_BUTTON_B:
			_request_close()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if current_panel!="bench": super._unhandled_input(event)

func get_bench_ui_snapshot() -> Dictionary:
	return {"open":panel_open and current_panel=="bench","closing":closing_panel,"tab":bench_tab,"selection":bench_selection if bench_tab=="fitils" else bench_inventory_selection,"seated_permission":_bench_permission(),"capacity":int(_bench_combat().get("capacity",3)),"used_capacity":int(_bench_combat().get("used_capacity",0)),"inventory_ids":_inventory_entries().map(func(e):return str(e.id)),"sheet_rect":Rect2(_bench_base_position,_bench_size),"notice":_bench_notice}
