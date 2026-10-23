extends "res://scripts/ui/m21_hud.gd"
## The world owns collected/read IDs, puzzle state, pause and persistence.
## This layer presents those records as an accessible bilingual field journal.
signal panel_closed

const READING_PANELS := ["journal","note"]
const PAGE_INK := Color("302c29")
const PAGE_MUTED := Color("76664f")
const PAGE_PAPER := Color("e9dcba")
const M22CombatDisplay = preload("res://scripts/ui/m22_combat_display.gd")
var closing_panel: bool = false
var reading_page: int = 0
var reading_page_count: int = 1
var journal_cursor: Dictionary = {}
var _panel_tween: Tween
var _leaf_tween: Tween
var _reader_scroll: ScrollContainer
var _index_scroll: ScrollContainer
var _reader_panel: PanelContainer
var _page_leaf: PageLeaf
var _active_record: Dictionary = {}
var _index_buttons: Array[Button] = []
var _page_next: Button
var _page_previous: Button
var _close_button: Button

class Binding extends Control:
	func _draw() -> void:
		var cover := StyleBoxFlat.new()
		cover.bg_color = Color("111e2b")
		cover.border_color = Color("8d7249")
		cover.set_border_width_all(1)
		cover.set_corner_radius_all(12)
		cover.shadow_color = Color(0,0,0,.40)
		cover.shadow_size = 18
		draw_style_box(cover,Rect2(Vector2.ZERO,size))
		for inset in [7.0,11.0]:
			draw_rect(Rect2(Vector2.ONE*inset,size-Vector2.ONE*inset*2),Color(.70,.55,.32,.24),false,1)
		for point in [Vector2(17,17),Vector2(size.x-17,17),Vector2(17,size.y-17),size-Vector2(17,17)]:
			draw_circle(point,2,Color("b99b62"))
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

class PageLeaf extends Control:
	var amount: float = 1.0:
		set(value):
			amount = value
			queue_redraw()
	var reverse: bool = false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
	func _draw() -> void:
		if amount>=.999: return
		var x := size.x*(1.0-amount)
		var fold := sin(amount*PI)*minf(92,size.x*.26)
		var points := PackedVector2Array([Vector2(x,0),Vector2(minf(size.x,x+fold),12),Vector2(minf(size.x,x+fold),size.y-12),Vector2(x,size.y)])
		if reverse:
			for index in range(points.size()): points[index].x = size.x-points[index].x
		draw_colored_polygon(points,Color("f4e8cb"))
		draw_polyline(points,Color(.34,.25,.14,.26),1.3,true)
		var edge := size.x-x if reverse else x
		draw_line(Vector2(edge,3),Vector2(edge,size.y-3),Color(.25,.17,.10,.18),5,true)

class LanternDiagram extends Control:
	var glyphs: Array = ["DIAMOND","ARCH","RAYS"]
	func _ready() -> void:
		custom_minimum_size = Vector2(0,92)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var y := size.y*.45
		for index in range(2):
			var a := Vector2(size.x*(.20+.30*index)+20,y)
			var b := Vector2(size.x*(.50+.30*index)-20,y)
			draw_line(a,b,Color("a78952"),2.0,true)
			draw_line(b-Vector2(7,5),b,Color("a78952"),1.5,true)
			draw_line(b-Vector2(7,-5),b,Color("a78952"),1.5,true)
		for index in range(3):
			var center := Vector2(size.x*(.20+.30*index),y)
			var ink := Color("725d39")
			draw_circle(center,24,Color(1,.84,.46,.20-.04*index))
			var glyph: String = str(glyphs[index]) if index<glyphs.size() else "ARCH"
			if glyph=="DIAMOND":
				draw_polyline(PackedVector2Array([center+Vector2(0,-13),center+Vector2(10,0),center+Vector2(0,13),center+Vector2(-10,0),center+Vector2(0,-13)]),ink,2,true)
			elif glyph=="RAYS":
				for angle in [-.65,0,.65]:
					draw_line(center+Vector2(0,9),center+Vector2(sin(angle)*15,-12),ink,2,true)
			else:
				draw_arc(center+Vector2(0,4),12,PI,TAU,24,ink,2,true)
				draw_line(center+Vector2(-12,4),center+Vector2(-12,12),ink,2,true)
				draw_line(center+Vector2(12,4),center+Vector2(12,12),ink,2,true)

class LocalizedPuzzleArt extends PuzzleArt:
	var locale: String = "ar"
	func _ink() -> void:
		super._ink()
		if locale=="ar":
			draw_rect(Rect2(43,77,94,21),Color("0e1d2b"))
			_text(Vector2(90,93),"المصدر",Color("76c3cf"),13)
			draw_rect(Rect2(480,5,60,27),Color("bba476"))
			_text(Vector2(510,25),"الطية",Color("182734"),13)
	func _balance() -> void:
		super._balance()
		if locale=="ar":
			var sides: Array = _values("balance_sides",[1,1,1])
			var totals := [2,0]
			for index in range(3): totals[clampi(int(sides[index]),0,1)] += [1,1,2][index]
			var offset := clampf(float(totals[1]-totals[0])*10.0,-30,30)
			draw_rect(Rect2(119,160-offset,68,18),Color("0e1d2b"))
			_text(Vector2(153,173-offset),"ثابت",Color("b9ab87"),11)

func setup(world: Node2D) -> void:
	super.setup(world)
	# Godot's project defaults may contain keyboard-only ui_accept events.
	# Add the controller confirm button without replacing any existing binding.
	var controller_accept := InputEventJoypadButton.new()
	controller_accept.button_index = JOY_BUTTON_A
	if not InputMap.action_has_event("ui_accept",controller_accept):
		InputMap.action_add_event("ui_accept",controller_accept)
	canvas.name = "M22ReadingAndCombatHUD"
	var prior_index := combat_display.get_index()
	var previous := combat_display
	canvas.remove_child(previous)
	previous.queue_free()
	combat_display = M22CombatDisplay.new()
	combat_display.name = "LanternHealthAndSharedGlow"
	combat_display.position = Vector2(22,16)
	combat_display.size = Vector2(340,146)
	canvas.add_child(combat_display)
	canvas.move_child(combat_display,prior_index)
	update_combat_status()
	_layout_combat_header()

func _layout_combat_header() -> void:
	super._layout_combat_header()
	if is_instance_valid(status_label): status_label.text = "M22 · المكتبة المطوية" if language=="ar" else "M22 · The Folding Library"
	_size_modal()

func t(key: String, args: Array = []) -> String:
	if key=="world_title": return "المكتبة المطوية" if language=="ar" else "The Folding Library"
	return super.t(key,args)

func _size_modal() -> void:
	if not is_instance_valid(modal) or not is_instance_valid(canvas): return
	var available := canvas.size if canvas.size.x>1 else Vector2(1280,720)
	var desired := Vector2(1120,636) if current_panel in READING_PANELS else Vector2(1080,608)
	modal.size = Vector2(minf(desired.x,available.x-40),minf(desired.y,available.y-40))
	modal.position = (available-modal.size)*.5
	modal.pivot_offset = modal.size*.5

func localized_room_name(value: Variant) -> String:
	var room: Dictionary = value if value is Dictionary else {}
	var room_id := int(room.get("id",value if value is int else 0))
	if room.is_empty():
		for candidate in panel_context.get("rooms",[]):
			if int(candidate.get("id",0))==room_id:
				room = candidate
				break
	if room.is_empty() and int(current_room.get("id",0))==room_id: room = current_room
	var key := "title_ar" if language=="ar" else "title_en"
	var fallback := str(room.get("arabic_title","")) if language=="ar" else str(room.get("title",""))
	var result := str(room.get(key,fallback))
	return result if not result.is_empty() else Text.get_text("room_"+str(room_id),language)

func update_status(room: Dictionary, progress: Dictionary, hint_key: String = "", hint_args: Array = []) -> void:
	super.update_status(room,progress,hint_key,hint_args)
	if is_instance_valid(room_label): room_label.text = "%02d  ·  %s" % [int(room.get("id",1)),localized_room_name(room)]

func open_panel(kind: String, context: Dictionary = {}) -> void:
	if is_instance_valid(_panel_tween): _panel_tween.kill()
	closing_panel = false
	var effective := context.duplicate(false)
	if effective.get("journal_cursor",{}) is Dictionary and not effective.get("journal_cursor",{}).is_empty():
		restore_journal_cursor(effective.journal_cursor)
	if kind=="journal" and not journal_cursor.is_empty():
		var section := str(journal_cursor.get("section","notes"))
		if not effective.has("journal_section"): effective.journal_section = section
		var key := "selected_area" if section=="places" else "selected_note"
		if not effective.has(key): effective[key] = str(journal_cursor.get("id",""))
		if not effective.has("reading_page"): effective.reading_page = int(journal_cursor.get("page",0))
	super.open_panel(kind,effective)
	_size_modal()
	modal.modulate.a = 0
	modal.scale = Vector2(.95,.98)
	modal.rotation = -.008 if language=="ar" else .008
	modal_shade.modulate.a = 0
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_panel_tween.tween_property(modal,"modulate:a",1.0,.23)
	_panel_tween.tween_property(modal,"scale",Vector2.ONE,.30)
	_panel_tween.tween_property(modal,"rotation",0.0,.30)
	_panel_tween.tween_property(modal_shade,"modulate:a",1.0,.23)
	if kind in READING_PANELS: _animate_leaf()

func close_panel(immediate: bool = false) -> void:
	if not panel_open and not closing_panel: return
	if immediate:
		if is_instance_valid(_panel_tween): _panel_tween.kill()
		_finish_close()
		return
	if closing_panel or not panel_open: return
	closing_panel = true
	if is_instance_valid(_panel_tween): _panel_tween.kill()
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_panel_tween.tween_property(modal,"modulate:a",0.0,.20)
	_panel_tween.tween_property(modal,"scale",Vector2(.94,.985),.20)
	_panel_tween.tween_property(modal,"rotation",.008 if language=="ar" else -.008,.20)
	_panel_tween.tween_property(modal_shade,"modulate:a",0.0,.20)
	if current_panel in READING_PANELS and is_instance_valid(_page_leaf):
		if is_instance_valid(_leaf_tween): _leaf_tween.kill()
		_page_leaf.amount = 1.0
		_page_leaf.show()
		_panel_tween.tween_property(_page_leaf,"amount",0.0,.20)
	_panel_tween.chain().tween_callback(_finish_close)

func _finish_close() -> void:
	if is_instance_valid(_leaf_tween): _leaf_tween.kill()
	super.close_panel()
	closing_panel = false
	modal.scale = Vector2.ONE
	modal.rotation = 0
	modal.modulate.a = 1
	modal_shade.modulate.a = 1
	panel_closed.emit()

func _request_close() -> void:
	if not closing_panel: action.emit("close_panel",null)

func refresh_panel(context: Dictionary = {}) -> void:
	var scroll_y := _reader_scroll.scroll_vertical if is_instance_valid(_reader_scroll) else 0
	super.refresh_panel(context)
	if is_instance_valid(_reader_scroll): _restore_reader_scroll.call_deferred(scroll_y)

func _restore_reader_scroll(value: int) -> void:
	if is_instance_valid(_reader_scroll): _reader_scroll.scroll_vertical = value

func _rebuild_panel() -> void:
	if not is_instance_valid(modal): return
	if current_panel not in READING_PANELS:
		modal.add_theme_stylebox_override("panel",_style(Color("0e1d2b"),Color("8f805d"),10,23))
		super._rebuild_panel()
		_size_modal()
		return
	_rebuild_reading_panel()

func _choice_label(arabic: String, english: String) -> String:
	return arabic if language=="ar" else english

func restore_journal_cursor(value: Dictionary) -> void:
	journal_cursor = {"id":str(value.get("id","")).left(120),"page":clampi(int(value.get("page",0)),0,100),"section":"places" if str(value.get("section","notes"))=="places" else "notes"}

func _remember_cursor(record: Dictionary) -> void:
	if str(record.get("id","")) in ["","empty"]: return
	var next_cursor := {"id":str(record.id),"page":reading_page,"section":"places" if bool(record.get("is_area",false)) else "notes"}
	if journal_cursor!=next_cursor:
		journal_cursor = next_cursor
		action.emit("journal_cursor",journal_cursor.duplicate(true))

func _journal_entries() -> Array:
	var catalog: Dictionary = {}
	for room in panel_context.get("rooms",[]):
		for source in room.get("objects",[]):
			if str(source.get("kind","")) not in ["note","secret"]: continue
			var record: Dictionary = source.duplicate(true)
			record.room_id = int(room.get("id",0))
			catalog[str(record.get("id",""))] = record
	var supplied: Array = panel_context.get("journal_catalog",[]).duplicate()
	supplied.append_array(panel_context.get("note_catalog",[]))
	for source in supplied:
		if source is Dictionary:
			var identity := str(source.get("id",""))
			var merged: Dictionary = catalog.get(identity,{}).duplicate(true)
			merged.merge(source,true)
			catalog[identity] = merged
	var collected: Array = _state().get("notes",panel_context.get("read_ids",[])).duplicate()
	for source in panel_context.get("notes",[]):
		if source is Dictionary:
			var identity := str(source.get("id",source.get("text_key","")))
			var merged: Dictionary = catalog.get(identity,{}).duplicate(true)
			merged.merge(source,true)
			catalog[identity] = merged
			if not collected.has(identity): collected.append(identity)
		elif not collected.has(source): collected.append(source)
	var entries: Array = []
	var seen: Array[String] = []
	for source in collected:
		var identity := str(source.get("id","")) if source is Dictionary else str(source)
		if identity.is_empty() or seen.has(identity): continue
		seen.append(identity)
		var record: Dictionary = catalog.get(identity,{"id":identity,"text_key":identity}).duplicate(true)
		record.id = identity
		entries.append(record)
	return entries

func _place_entries() -> Array:
	var entries: Array = []
	for room in panel_context.get("rooms",[]):
		var room_id := int(room.get("id",0))
		if not _state().get("visited",[]).has(room_id): continue
		var names: Array[String] = []
		for record in _journal_entries():
			if int(record.get("room_id",0))==room_id: names.append(_record_text(record).title)
		var body := _choice_label("وصلت إلى هذه المنطقة وسجلت موضعها في خريطتك.","You reached this area and recorded its position on your map.")
		body += "\n\n"+_choice_label("الصفحات المحفوظة هنا:","Pages kept from this area:")+"\n"+("\n".join(names) if not names.is_empty() else _choice_label("لم تحفظ صفحة من هنا بعد.","No page from this area has been kept yet."))
		entries.append({"id":"area:"+str(room_id),"room_id":room_id,"title_ar":localized_room_name(room),"title_en":localized_room_name(room),"text_ar":body,"text_en":body,"is_area":true})
	return entries

func _record_text(record: Dictionary) -> Dictionary:
	var identity := str(record.get("text_key",record.get("note_id",record.get("id","entrance_note"))))
	var fallback: Dictionary = Text.note(identity,language)
	var title := str(record.get("title_ar" if language=="ar" else "title_en",record.get("name_ar" if language=="ar" else "name_en",fallback.title)))
	var body := str(record.get("text_ar" if language=="ar" else "text_en",record.get("body_ar" if language=="ar" else "body_en",record.get("text",record.get("body",fallback.body)))))
	return {"title":title,"body":body}

func _record_pages(record: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var authored: Variant = record.get("pages_ar" if language=="ar" else "pages_en",record.get("pages",[]))
	if authored is Array and not authored.is_empty():
		for page in authored: result.append(str(page))
		return result
	var body: String = _record_text(record).body
	var page_text := ""
	for paragraph in body.split("\n\n"):
		if page_text.length()+paragraph.length()>880 and not page_text.is_empty():
			result.append(page_text)
			page_text = ""
		if paragraph.length()>1100:
			for word in paragraph.split(" "):
				if page_text.length()+word.length()>880:
					result.append(page_text)
					page_text = ""
				page_text += (" " if not page_text.is_empty() else "")+word
		else: page_text += ("\n\n" if not page_text.is_empty() else "")+paragraph
	if not page_text.is_empty(): result.append(page_text)
	if result.is_empty(): result.append(_choice_label("لا توجد كتابة على هذه الصفحة.","There is no writing on this page."))
	return result

func _rebuild_reading_panel() -> void:
	if is_instance_valid(_leaf_tween): _leaf_tween.kill()
	for child in modal.get_children():
		modal.remove_child(child)
		child.queue_free()
	_index_buttons.clear()
	modal.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	modal.add_child(Binding.new())
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,22)
	modal.add_child(margin)
	modal_box = VBoxContainer.new()
	modal_box.add_theme_constant_override("separation",12)
	margin.add_child(modal_box)
	var head := HBoxContainer.new()
	_localize(head)
	head.add_theme_constant_override("separation",12)
	modal_box.add_child(head)
	modal_title = _label(head,_choice_label("دفتر الرحلة","The Field Journal") if current_panel=="journal" else _choice_label("صفحة من المكتبة","A Page from the Library"),Vector2.ZERO,Vector2.ZERO,25)
	modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_title.add_theme_color_override("font_color",GOLD)
	_button(head,"EN" if language=="ar" else "عربي",func(): action.emit("language","en" if language=="ar" else "ar"))
	_close_button = _button(head,"×",_request_close)
	_close_button.tooltip_text = t("close")
	var compact := canvas.size.x<940
	var spread: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	_localize(spread)
	spread.add_theme_constant_override("separation",14)
	spread.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_box.add_child(spread)
	var entries: Array = _journal_entries()
	var places := str(panel_context.get("journal_section","notes"))=="places"
	var records: Array = _place_entries() if places else entries
	var record: Dictionary = panel_context.get("definition",{}).duplicate(true)
	if current_panel=="journal":
		var selection_key := "selected_area" if places else "selected_note"
		var selected := str(panel_context.get(selection_key,str(records[-1].id) if not records.is_empty() else ""))
		record = {}
		for candidate in records:
			if str(candidate.id)==selected: record = candidate
		if record.is_empty() and not records.is_empty(): record = records[-1]
		if not record.is_empty(): panel_context[selection_key] = str(record.id)
	else:
		if panel_context.has("note_id"): record.text_key = str(panel_context.note_id)
		for field in ["body","body_ar","body_en"]:
			if panel_context.has(field): record[field] = panel_context[field]
	if record.is_empty(): record = {"id":"empty","title_ar":"صفحات تنتظر من يجدها","title_en":"Pages Waiting to Be Found","text_ar":"بين الرفوف والممرات شهادات ورسائل وملاحظات. افتح صفحة في العالم، وستبقى محفوظة هنا لتعود إليها متى شئت.","text_en":"Testimonies, letters and notes wait among the shelves. Read a page in the world and it will remain here for you to revisit."}
	_active_record = record
	if current_panel=="journal": _build_journal_index(spread,records,entries.size(),places,compact)
	_build_reader(spread,record)
	modal_footer = HBoxContainer.new()
	_localize(modal_footer)
	modal_footer.add_theme_constant_override("separation",10)
	modal_box.add_child(modal_footer)
	var count := _label(modal_footer,_choice_label("%d صفحة محفوظة · %d مكان مكتشف","%d kept pages · %d discovered places") % [entries.size(),_state().get("visited",[]).size()],Vector2.ZERO,Vector2.ZERO,13)
	count.text += "\n"+_choice_label("للقراءة: PageUp / PageDown أو LB / RB · رجوع: B","Read: PageUp / PageDown or LB / RB · Back: B")
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	count.modulate.a = .70
	_button(modal_footer,t("close"),_request_close)
	_size_modal()
	if current_panel=="note": _defer_focus(_reader_scroll)
	elif not _index_buttons.is_empty():
		var focus_button := _index_buttons[0]
		for button in _index_buttons:
			if str(button.get_meta("journal_entry_id",""))==str(_active_record.get("id","")): focus_button = button
		_defer_focus(focus_button)
	else: _defer_focus(_close_button)

func _build_journal_index(parent: BoxContainer, records: Array, kept_count: int, places: bool, compact: bool) -> void:
	var index := VBoxContainer.new()
	index.custom_minimum_size = Vector2(0,134) if compact else Vector2(260,0)
	index.size_flags_vertical = 0 if compact else Control.SIZE_EXPAND_FILL
	index.add_theme_constant_override("separation",8)
	parent.add_child(index)
	var sections := HBoxContainer.new()
	_localize(sections)
	index.add_child(sections)
	for section in ["notes","places"]:
		var value: String = section
		var button := _button(sections,_choice_label("الصفحات","Pages") if section=="notes" else _choice_label("الأماكن","Places"),func():
			panel_context.journal_section = value
			panel_context.reading_page = 0
			_rebuild_panel())
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if places==(section=="places"): button.add_theme_color_override("font_color",Color("fff0ba"))
	_index_scroll = ScrollContainer.new()
	_index_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_index_scroll.follow_focus = true
	_index_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	index.add_child(_index_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",6)
	_index_scroll.add_child(list)
	for record in records:
		var identity := str(record.id)
		var name_value: String = _record_text(record).title
		var button := _button(list,name_value,func(): _select_record(identity,places))
		button.set_meta("journal_entry_id",identity)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size",15)
		button.custom_minimum_size = Vector2(250 if not compact else 0,48)
		var selection_key := "selected_area" if places else "selected_note"
		if identity==str(panel_context.get(selection_key,"")):
			button.add_theme_stylebox_override("normal",_style(Color("2c3b41"),GOLD,5,12))
		button.tooltip_text = localized_room_name(int(record.get("room_id",0))) if int(record.get("room_id",0))>0 else _choice_label("صفحة محفوظة","A kept page")
		_index_buttons.append(button)
	if records.is_empty(): _paragraph(list,_choice_label("تبدأ الحكاية بصفحة واحدة.","The story begins with a single page."),16).modulate.a = .7

func _build_reader(parent: BoxContainer, record: Dictionary) -> void:
	_reader_panel = PanelContainer.new()
	_reader_panel.clip_contents = true
	_reader_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reader_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reader_panel.add_theme_stylebox_override("panel",_style(PAGE_PAPER,Color("ae9468"),5,24))
	parent.add_child(_reader_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",10)
	_reader_panel.add_child(stack)
	var entry := _record_text(record)
	var title := _paragraph(stack,str(entry.title),25)
	title.add_theme_color_override("font_color",PAGE_INK)
	title.custom_minimum_size.y = 35
	var room_id := int(record.get("room_id",0))
	var eyebrow := localized_room_name(room_id) if room_id>0 else _choice_label("من محفوظات المكتبة","From the library's records")
	var byline := _paragraph(stack,eyebrow,13)
	byline.add_theme_color_override("font_color",PAGE_MUTED)
	byline.custom_minimum_size.y = 20
	stack.add_child(HSeparator.new())
	_reader_scroll = ScrollContainer.new()
	_reader_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_reader_scroll.follow_focus = true
	_reader_scroll.focus_mode = Control.FOCUS_ALL
	_reader_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_reader_scroll)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation",14)
	_reader_scroll.add_child(words)
	if str(record.get("illustration",""))=="lantern_sequence":
		var diagram := LanternDiagram.new()
		diagram.glyphs = record.get("glyphs",["DIAMOND","ARCH","RAYS"])
		words.add_child(diagram)
	var pages := _record_pages(record)
	reading_page_count = pages.size()
	reading_page = clampi(int(panel_context.get("reading_page",0)),0,reading_page_count-1)
	panel_context.reading_page = reading_page
	_remember_cursor(record)
	var text := _paragraph(words,pages[reading_page],22)
	text.add_theme_color_override("font_color",PAGE_INK)
	text.add_theme_constant_override("line_spacing",8)
	text.custom_minimum_size.y = 80
	var nav := HBoxContainer.new()
	_localize(nav)
	nav.add_theme_constant_override("separation",10)
	stack.add_child(nav)
	_page_previous = _button(nav,_choice_label("السابقة","Previous"),func(): _turn_page(-1),reading_page<=0)
	var folio := _label(nav,_choice_label("صفحة %d من %d","Page %d of %d") % [reading_page+1,reading_page_count],Vector2.ZERO,Vector2.ZERO,14)
	folio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	folio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	folio.add_theme_color_override("font_color",PAGE_MUTED)
	_page_next = _button(nav,_choice_label("التالية","Next"),func(): _turn_page(1),reading_page>=reading_page_count-1)
	for button in [_page_previous,_page_next]:
		button.add_theme_color_override("font_color",PAGE_INK)
		button.add_theme_color_override("font_disabled_color",Color("a4997f"))
		for state in ["normal","hover","pressed","focus","disabled"]:
			button.add_theme_stylebox_override(state,_style(Color("e2d3ae") if state!="hover" else Color("f5e8c6"),Color("a58b5b") if state=="focus" else Color("c5b48c"),4,9))
	_page_leaf = PageLeaf.new()
	_page_leaf.reverse = language=="ar"
	_page_leaf.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reader_panel.add_child(_page_leaf)

func _select_record(identity: String, places: bool = false) -> void:
	if closing_panel: return
	panel_context["selected_area" if places else "selected_note"] = identity
	panel_context.reading_page = 0
	_rebuild_panel()
	_animate_leaf()

func _turn_page(direction: int) -> void:
	if closing_panel: return
	var next_page := clampi(reading_page+direction,0,reading_page_count-1)
	if next_page==reading_page: return
	panel_context.reading_page = next_page
	_rebuild_panel()
	_animate_leaf(direction<0)
	_defer_focus(_page_next if direction>0 and not _page_next.disabled else _page_previous if not _page_previous.disabled else _reader_scroll)

func _animate_leaf(reverse: bool = false) -> void:
	if not is_instance_valid(_page_leaf): return
	if is_instance_valid(_leaf_tween): _leaf_tween.kill()
	_page_leaf.reverse = reverse != (language=="ar")
	_page_leaf.amount = 0
	_page_leaf.show()
	_leaf_tween = create_tween()
	_leaf_tween.tween_property(_page_leaf,"amount",1.0,.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_leaf_tween.tween_callback(func():
		if is_instance_valid(_page_leaf): _page_leaf.hide())

func _unhandled_input(event: InputEvent) -> void:
	if not panel_open or closing_panel or current_panel not in READING_PANELS: return
	var direction := 0
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_PAGEDOWN: direction = 1
		elif event.keycode==KEY_PAGEUP: direction = -1
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_B:
			_request_close()
			get_viewport().set_input_as_handled()
			return
		if event.button_index==JOY_BUTTON_RIGHT_SHOULDER: direction = 1
		elif event.button_index==JOY_BUTTON_LEFT_SHOULDER: direction = -1
	if direction!=0:
		if reading_page_count>1: _turn_page(direction)
		elif is_instance_valid(_reader_scroll): _reader_scroll.scroll_vertical += direction*maxi(60,int(_reader_scroll.size.y*.8))
		get_viewport().set_input_as_handled()

func _puzzle_panel() -> void:
	super._puzzle_panel()
	for child in modal_body.get_children():
		if child is PuzzleArt:
			var replacement := LocalizedPuzzleArt.new()
			replacement.kind = child.kind
			replacement.state = child.state
			replacement.locale = language
			var index := child.get_index()
			modal_body.remove_child(child)
			child.queue_free()
			modal_body.add_child(replacement)
			modal_body.move_child(replacement,index)

func _pause_panel() -> void:
	super._pause_panel()
	for child in modal_body.get_children():
		if child is Label and child.text.begins_with("M18"):
			child.text = localized_room_name(current_room)
