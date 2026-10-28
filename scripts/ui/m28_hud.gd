extends "res://scripts/ui/m24_hud.gd"
## Exploration tools and the reading-room market share the normal paused modal.
const Shop = preload("res://scripts/shop/m28_shop.gd")
var page_needle: Control
var page_needle_label: Label
var shop_selection: String = "atlas"

class Needle extends Control:
	var direction := Vector2.RIGHT
	func _draw() -> void:
		var center:=Vector2(19,19)
		draw_arc(center,15,0,TAU,48,Color("70614d"),1,true)
		draw_circle(center,2,Color("e3ba78"))
		var tip:=center+direction.normalized()*12
		var tail:=center-direction.normalized()*7
		var side:=direction.normalized().orthogonal()*4
		draw_colored_polygon(PackedVector2Array([tip,tail+side,tail-side]),Color("e3ba78"))

class SurveyMap extends MapDisplay:
	var rooms: Array = []
	var annotated:=false
	func _draw() -> void:
		super._draw()
		var visited: Array = progress.get("visited",[])
		for room in rooms:
			var id:=int(room.get("id",0))
			if not POS.has(id) or (id!=room_id and not visited.has(id)): continue
			# Read the current world's authored names rather than the archived
			# M17 Compiler names embedded in the original free-map renderer.
			var title:=str(room.get("title_ar" if language=="ar" else "title_en",room.get("title","")))
			var p: Vector2=_p(id)
			draw_rect(Rect2(p+Vector2(-67,1),Vector2(134,19)),Color("243a49"))
			draw_string(font,p+Vector2(-font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x*.5,13),title,HORIZONTAL_ALIGNMENT_LEFT,132,11,Color("cad7d9"))
			if not annotated: continue
			var foot: Vector2 = _p(id)+Vector2(-55,-12)
			var has_rest:=false
			var has_market:=false
			for object in room.get("objects",[]):
				has_rest=has_rest or str(object.get("kind",""))=="bench"
				has_market=has_market or str(object.get("kind","")) in ["shop","market"]
			if has_rest:
				draw_line(foot+Vector2(-5,0),foot+Vector2(5,0),Color("8ebfbb"),2,true)
				for x in [-3,3]: draw_line(foot+Vector2(x,0),foot+Vector2(x,5),Color("8ebfbb"),1.5,true)
			if has_market:
				var pin:=_p(id)+Vector2(55,-12)
				draw_polyline(PackedVector2Array([pin+Vector2(0,-5),pin+Vector2(5,0),pin+Vector2(0,5),pin+Vector2(-5,0),pin+Vector2(0,-5)]),Color("f0c184"),2,true)
			if id in [6,12]:
				var pin:=_p(id)+Vector2(55,-12)
				var defeated:=bool(progress.get("miniboss_archivist_defeated",false)) if id==6 else bool(progress.get("miniboss_bell_defeated",false))
				defeated=defeated or bool(progress.get("m28_archivist_defeated",false) if id==6 else progress.get("m28_bell_defeated",false))
				var col:=Color("79988c") if defeated else Color("d69378")
				draw_arc(pin,5,0,TAU,20,col,1.6,true)
				if defeated: draw_polyline(PackedVector2Array([pin+Vector2(-3,0),pin+Vector2(-1,2),pin+Vector2(3,-2)]),col,1.3,true)
				else: draw_line(pin+Vector2(-3,-3),pin+Vector2(3,3),col,1.5,true)

func setup(world: Node2D) -> void:
	super.setup(world)
	canvas.name="M28WorldJournalAndMarketHUD"
	page_needle=Needle.new()
	page_needle.name="IndexNeedle"
	page_needle.position=Vector2(22,176)
	page_needle.size=Vector2(290,40)
	page_needle.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(page_needle)
	canvas.move_child(page_needle,modal_shade.get_index())
	page_needle_label=_label(page_needle,"",Vector2(45,3),Vector2(225,38),13)
	page_needle_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	page_needle_label.add_theme_color_override("font_color",Color("d0be9c"))
	page_needle.hide()

func _layout_combat_header() -> void:
	super._layout_combat_header()
	if is_instance_valid(status_label): status_label.text="M28 · المكتبة المطوية" if language=="ar" else "M28 · The Folding Library"

func t(key: String, args: Array = []) -> String:
	match key:
		"room_14": return "قاعة الرف النائم" if language=="ar" else "Hall of the Sleeping Shelf"
		"environment_build": return "M28 · الممرات وغرف الحراس" if language=="ar" else "M28 · Passages and keeper chambers"
		"preview_exit_title": return "عند عتبة العالم التالي" if language=="ar" else "At the Next World's Threshold"
		"preview_exit_body": return "يمكنك استكشاف المكتبة ومواجهة حارس الجرس وأمين الأرشيف. قاعة الرف النائم والعالم الثاني لم يكتمل قتالهما بعد. لا تمنح هذه العتبة انتصارًا على الزعيم الأخير." if language=="ar" else "Explore the library and face the Bell Warden and Archivist. The Sleeping Shelf encounter and World Two are still unfinished. This threshold awards no final-boss victory."
		"completion_body": return "حُفظت الصفحات والأدوات وحلول الألغاز والمسارات التي فتحتها. مواجهتا حارس الجرس وأمين الأرشيف تحفظان انتصاراتهما الفعلية. قتال الرف النائم والعالم الثاني ما زالا قيد التطوير." if language=="ar" else "Your pages, tools, puzzle solutions and opened routes are saved. Bell Warden and Archivist victories are recorded only when won. The Sleeping Shelf encounter and World Two remain in development."
	return super.t(key,args)

func _update_controls_hint() -> void:
	super._update_controls_hint()
	if is_instance_valid(controls_label):
		var drop_caption: String=("     ↓ + %s نزول من رف" if language=="ar" else "     ↓ + %s Drop through shelf") % _hint("jump","SPACE")
		if not controls_label.text.ends_with(drop_caption): controls_label.text+=drop_caption

func _pause_panel() -> void:
	modal_title.text="استراحة" if language=="ar" else "Pause"
	_paragraph(modal_body,t("world_title"),24)
	_paragraph(modal_body,t("environment_build"),14).modulate.a=.65
	var at_bench:=bool(_panel_combat().get("at_bench",false))
	_button(modal_body,"الفانوس والفتائل" if language=="ar" else "Lantern and fitils",func(): action.emit("fitils",null),not at_bench)
	if not at_bench: _paragraph(modal_body,"تُغيّر الفتائل عند المقاعد فقط." if language=="ar" else "Change fitils at benches only.",13).modulate.a=.68
	var row:=HBoxContainer.new()
	_localize(row)
	modal_body.add_child(row)
	_button(row,t("map"),func(): action.emit("map",null))
	_button(row,t("journal"),func(): action.emit("journal",null))
	_button(modal_body,"التحكم وتعيين الأزرار" if language=="ar" else "Controls and bindings",func(): action.emit("controls",null))
	var studio:=_button(modal_body,"استوديو الشخصيات والتجارب" if language=="ar" else "Character and trial studio",func(): action.emit("boss_trial",null))
	studio.set_meta("action_id","boss_trial")
	var muted:=_boss_music_muted()
	_button(modal_body,("موسيقى المواجهات: مكتومة" if muted else "موسيقى المواجهات: مفعلة") if language=="ar" else ("Encounter music: muted" if muted else "Encounter music: on"),func(): action.emit("boss_music_toggle",null))
	_button(modal_body,t("restart"),func(): open_panel("restart",panel_context))
	_defer_focus(_button(modal_footer,t("resume"),_request_close))

func _process(delta: float) -> void:
	super._process(delta)
	_update_page_needle()

func _update_page_needle() -> void:
	if not is_instance_valid(page_needle): return
	page_needle.hide()
	if not is_instance_valid(world_ref) or not is_instance_valid(world_ref.hero): return
	if panel_open or closing_panel or bool(world_ref.boss_active) or not bool(world_ref.gameplay_active): return
	if not Shop.owns(world_ref.progress,world_ref.combat_state,"pagefinder"): return
	var nearest: Dictionary = {}
	var distance:=960.0
	var origin: Vector2=world_ref.hero.position-Vector2(0,65)
	for object in world_ref.data.get("objects",[]):
		if str(object.get("kind","")) not in ["note","book","secret"]: continue
		var id:=str(object.get("id",""))
		if world_ref.progress.get("notes",[]).has(id): continue
		if str(object.get("kind",""))=="book" and world_ref.progress.get("book_inventory",[]).has(str(object.get("book_id",object.get("symbol",""))).to_upper()): continue
		if str(object.get("kind",""))=="secret" and world_ref.progress.get("secrets",[]).has(str(object.get("secret_id",id))): continue
		if world_ref.has_method("_object_visible") and not world_ref._object_visible(object): continue
		if world_ref.has_method("_requirements_met") and not world_ref._requirements_met(object.get("requires","")): continue
		var point: Vector2=object.get("pos",Vector2.ZERO)-Vector2(0,65)
		var gap:=point.distance_to(origin)
		if gap<distance:
			distance=gap
			nearest=object
	if nearest.is_empty(): return
	var direction: Vector2=(nearest.pos-Vector2(0,65))-origin
	page_needle.direction=direction.normalized() if direction.length()>1 else Vector2.UP
	page_needle.queue_redraw()
	page_needle_label.text="صفحة قريبة لم تُقرأ" if language=="ar" else "An unread page is nearby"
	page_needle_label.text_direction=Control.TEXT_DIRECTION_RTL if language=="ar" else Control.TEXT_DIRECTION_LTR
	page_needle.show()

func _note_panel() -> void:
	if current_panel=="shop": _shop_panel()
	else: super._note_panel()

func _shop_panel() -> void:
	modal_title.text="دكان الهامش" if language=="ar" else "The Margin Market"
	if modal_body.get_parent() is ScrollContainer:
		modal_body.get_parent().follow_focus=true
	var state: RefCounted=world_ref.combat_state
	var progress: Dictionary=world_ref.progress
	var top:=HBoxContainer.new()
	_localize(top)
	modal_body.add_child(top)
	var introduction:=_paragraph(top,"قطع صغيرة لرحلة أطول. الشراء دائم؛ تركيب الفتائل عند المقعد." if language=="ar" else "Small tools for a longer journey. Purchases are permanent; equip fitils at a bench.",15)
	introduction.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var wallet:=_paragraph(top,("العملات: %d" if language=="ar" else "Coins: %d") % int(state.wallet),19)
	wallet.custom_minimum_size.x=140
	wallet.size_flags_horizontal=Control.SIZE_SHRINK_END
	wallet.add_theme_color_override("font_color",Color("f0c184"))
	var selected: Button
	var first: Button
	for item in Shop.catalog():
		var id:=str(item.id)
		var offer:=Shop.status(progress,state,id)
		var panel:=PanelContainer.new()
		var style:=_style(Color("152432"),Color("67533d"),7,12)
		panel.add_theme_stylebox_override("panel",style)
		modal_body.add_child(panel)
		var row:=HBoxContainer.new()
		_localize(row)
		row.add_theme_constant_override("separation",20)
		panel.add_child(row)
		var copy:=VBoxContainer.new()
		copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(copy)
		var title:=_paragraph(copy,str(item["name_"+language]),18)
		title.add_theme_color_override("font_color",Color("edcf9d"))
		_paragraph(copy,str(item["description_"+language]),14).modulate.a=.82
		var owned:=bool(offer.owned)
		var label: String=("بحوزتك" if language=="ar" else "Owned") if owned else (("شراء · %d" if language=="ar" else "Buy · %d") % int(item.price))
		# Insufficient funds stays focusable so both controller and mouse can
		# request the same clear response. Only already-owned offers are inert.
		var button:=_button(row,label,func():
			shop_selection=id
			action.emit("shop_buy",id),owned)
		button.name="ShopBuy_"+id
		button.set_meta("shop_item",id)
		button.custom_minimum_size=Vector2(150,50)
		button.tooltip_text=Shop.feedback(str(offer.reason),language) if not bool(offer.can_buy) else ("شراء دائم" if language=="ar" else "Permanent purchase")
		if not owned and first==null: first=button
		if id==shop_selection and not owned: selected=button
	var code:=str(panel_context.get("shop_feedback",panel_context.get("shop_error","")))
	if not code.is_empty():
		var response:=_paragraph(modal_footer,Shop.feedback(code,language),14)
		response.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		response.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		response.add_theme_color_override("font_color",Color("e8ca94") if code=="purchased" else Color("d59a87"))
	var close:=_button(modal_footer,t("close"),_request_close)
	close.name="ShopClose"
	_defer_focus(selected if selected!=null else first if first!=null else close)

func _map_panel() -> void:
	var annotated:=Shop.owns(world_ref.progress,world_ref.combat_state,"atlas")
	modal_title.text=("أطلس الممرات" if language=="ar" else "Passage Atlas") if annotated else t("map")
	var map_display:=SurveyMap.new()
	map_display.name="PurchasedSurveyMap" if annotated else "FreeWorldMap"
	map_display.annotated=annotated
	map_display.progress=_state()
	map_display.language=language
	map_display.rooms=panel_context.get("rooms",[])
	map_display.room_id=int(panel_context.get("room",current_room).get("id",1))
	modal_body.add_child(map_display)
	if annotated:
		_paragraph(modal_body,"◇ دكان الهامش    ⊖ غرفة زعيم    ▰ استراحة\nتظهر العلامات في المناطق المكتشفة فقط. الخطوط الزرقاء اختصارات فتحتها." if language=="ar" else "◇ Margin Market    ⊖ Boss chamber    ▰ Rest\nMarkers appear only in discovered areas. Blue paths are shortcuts you have opened.",14)
	else: _paragraph(modal_body,t("map_legend"),14)
	_paragraph(modal_body,t("map_hint"),13).modulate.a=.72
	_defer_focus(_button(modal_footer,t("close"),_request_close))
