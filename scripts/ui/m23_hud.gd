extends "res://scripts/ui/m22_hud.gd"
## Boss presentation adds no combat authority and never pauses the world.
const BossDisplay = preload("res://scripts/ui/m23_boss_display.gd")
var boss_context: Dictionary = {}
var boss_display: Control
var boss_warning: Panel
var boss_warning_label: Label
var boss_warning_progress: ProgressBar
var boss_title: VBoxContainer
var boss_title_caption: Label
var boss_title_name: Label
var _boss_alpha: float = 0.0
var _warning_alpha: float = 0.0
var _title_elapsed: float = 0.0
var _title_duration: float = 0.0
var _title_kind: String = ""
var _title_context: Dictionary = {}

func setup(world: Node2D) -> void:
	super.setup(world)
	canvas.name = "M23CompilerAndReadingHUD"
	boss_display = BossDisplay.new()
	boss_display.name = "CompilerHealth"
	_add_encounter_control(boss_display)
	boss_display.modulate.a = 0
	boss_warning = Panel.new()
	boss_warning.name = "CompilerAttackCue"
	boss_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cue_style := _style(Color(.025,.036,.05,.87),Color(.69,.53,.32,.60),4,10)
	cue_style.content_margin_top = 7
	cue_style.content_margin_bottom = 6
	boss_warning.add_theme_stylebox_override("panel",cue_style)
	_add_encounter_control(boss_warning)
	# A fixed-height panel avoids the one-frame minimum-height expansion that
	# container-based wrapped labels can produce before their first layout.
	boss_warning_label = _label(boss_warning,"",Vector2(10,4),Vector2(560,45),17)
	boss_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_warning_progress = ProgressBar.new()
	boss_warning_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_warning_progress.custom_minimum_size = Vector2(0,3)
	boss_warning_progress.max_value = 1
	boss_warning_progress.show_percentage = false
	boss_warning_progress.add_theme_stylebox_override("background",_style(Color("202934"),Color(0,0,0,0),0))
	boss_warning_progress.add_theme_stylebox_override("fill",_style(Color("d9ad70"),Color(0,0,0,0),0))
	boss_warning.add_child(boss_warning_progress)
	boss_warning.modulate.a = 0
	boss_title = VBoxContainer.new()
	boss_title.name = "CompilerEncounterTitle"
	boss_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_title.add_theme_constant_override("separation",5)
	_add_encounter_control(boss_title)
	boss_title_caption = _label(boss_title,"",Vector2.ZERO,Vector2.ZERO,13)
	boss_title_caption.add_theme_color_override("font_color",Color("d6b178"))
	boss_title_name = _label(boss_title,"",Vector2.ZERO,Vector2.ZERO,36)
	boss_title_name.add_theme_color_override("font_shadow_color",Color(0,0,0,.95))
	boss_title_name.add_theme_constant_override("shadow_offset_y",3)
	for label in [boss_title_caption,boss_title_name]: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var line := HSeparator.new()
	var line_style := StyleBoxLine.new()
	line_style.color = Color(.78,.61,.36,.66)
	line_style.thickness = 1
	line.add_theme_stylebox_override("separator",line_style)
	boss_title.add_child(line)
	boss_title.modulate.a = 0
	_layout_combat_header()
	update_boss_status({"visible":false})

func _add_encounter_control(control: Control) -> void:
	canvas.add_child(control)
	# Reading/pause panels always render above the encounter presentation.
	canvas.move_child(control,modal_shade.get_index())

func _layout_combat_header() -> void:
	super._layout_combat_header()
	if is_instance_valid(status_label): status_label.text = "M23 · د. كومبايلر" if language=="ar" else "M23 · Dr. Compiler"
	if not is_instance_valid(boss_display): return
	var screen := _boss_screen()
	var bar_width := minf(680,screen.x-100)
	boss_display.position = Vector2((screen.x-bar_width)*.5,screen.y-116)
	boss_display.size = Vector2(bar_width,68)
	boss_warning.size = Vector2(minf(580,screen.x-80),68)
	boss_warning_label.position = Vector2(10,4)
	boss_warning_label.size = Vector2(boss_warning.size.x-20,45)
	boss_warning_progress.position = Vector2(10,55)
	boss_warning_progress.size = Vector2(boss_warning.size.x-20,3)
	boss_title.position = Vector2((screen.x-minf(640,screen.x-80))*.5,screen.y*.28)
	boss_title.size = Vector2(minf(640,screen.x-80),110)
	_place_warning()
	if bool(boss_context.get("visible",false)):
		toast_label.position.y = 205

func _boss_screen() -> Vector2:
	return canvas.size if canvas.size.x>1 and canvas.size.y>1 else Vector2(1280,720)

func _place_warning() -> void:
	if not is_instance_valid(boss_warning): return
	var screen := _boss_screen()
	var center: Vector2 = boss_context.get("warning_position",Vector2(screen.x*.5,151))
	center.x = clampf(center.x,boss_warning.size.x*.5+20,screen.x-boss_warning.size.x*.5-20)
	center.y = clampf(center.y,133,screen.y-230)
	boss_warning.position = center-Vector2(boss_warning.size.x*.5,0)

func update_boss_status(context: Dictionary) -> void:
	boss_context = context.duplicate(false)
	if not is_instance_valid(boss_display): return
	boss_display.update_context(boss_context,language)
	boss_warning_label.text = str(context.get("warning_ar","")) if language=="ar" else str(context.get("warning_en",""))
	boss_warning_label.text_direction = Control.TEXT_DIRECTION_RTL if language=="ar" else Control.TEXT_DIRECTION_LTR
	boss_warning_progress.value = clampf(float(context.get("warning_progress",0)),0,1)
	boss_warning_progress.visible = str(context.get("state","")).ends_with("_warning")
	_place_warning()
	_layout_combat_header()

func show_boss_intro(context: Dictionary = {}) -> void:
	_present_boss_title("intro",context,1.5)

func show_boss_victory(context: Dictionary = {}) -> void:
	_present_boss_title("victory",context,2.4)

func _present_boss_title(kind: String, context: Dictionary, duration: float) -> void:
	_title_kind = kind
	_title_context = context.duplicate(false)
	_title_duration = duration
	_title_elapsed = 0
	_refresh_boss_title()

func _refresh_boss_title() -> void:
	if not is_instance_valid(boss_title): return
	boss_title_caption.text = ("حارس المحاضرة الأخيرة" if language=="ar" else "WARDEN OF THE LAST LECTURE") if _title_kind=="intro" else ("انتهى الحكم" if language=="ar" else "JUDGMENT ENDED")
	boss_title_name.text = str(_title_context.get("name_ar","د. كومبايلر")) if language=="ar" else str(_title_context.get("name_en","Dr. Compiler"))
	for label in [boss_title_caption,boss_title_name]:
		label.text_direction = Control.TEXT_DIRECTION_RTL if language=="ar" else Control.TEXT_DIRECTION_LTR

func set_language(value: String) -> void:
	super.set_language(value)
	update_boss_status(boss_context)
	_refresh_boss_title()

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(boss_display): return
	var active := bool(boss_context.get("visible",false))
	var shown := active and not panel_open
	_boss_alpha = move_toward(_boss_alpha,1.0 if shown else 0.0,delta*5.0)
	boss_display.modulate.a = _boss_alpha
	var warning_shown := shown and not boss_warning_label.text.is_empty()
	_warning_alpha = move_toward(_warning_alpha,1.0 if warning_shown else 0.0,delta*8.0)
	boss_warning.modulate.a = _warning_alpha
	hint_label.visible = not panel_open and not active
	if _title_elapsed<_title_duration:
		_title_elapsed = minf(_title_duration,_title_elapsed+delta)
		var envelope := minf(clampf(_title_elapsed/.18,0,1),clampf((_title_duration-_title_elapsed)/.34,0,1))
		boss_title.modulate.a = envelope if not panel_open else 0.0
	else: boss_title.modulate.a = 0

func _is_boss_trial() -> bool:
	if panel_context.has("is_boss_trial"): return bool(panel_context.is_boss_trial)
	if is_instance_valid(world_ref):
		for property in world_ref.get_property_list():
			if str(property.name)=="is_boss_trial": return bool(world_ref.get("is_boss_trial"))
	return false

func t(key: String, args: Array = []) -> String:
	if _is_boss_trial():
		match key:
			"restart", "restart_title": return "إعادة المواجهة" if language=="ar" else "Restart the encounter"
			"restart_body": return "تبدأ محاولة جديدة دون تغيير تقدم المكتبة." if language=="ar" else "Start a fresh attempt without changing library progress."
			"restart_confirm": return "ابدأ محاولة جديدة" if language=="ar" else "Start fresh attempt"
	return super.t(key,args)

func _restart_panel() -> void:
	if not _is_boss_trial():
		super._restart_panel()
		return
	modal_title.text = t("restart_title")
	_paragraph(modal_body,t("restart_body"),21)
	var back := _button(modal_footer,t("cancel"),func(): open_panel(str(panel_context.get("return_to","pause")),panel_context))
	_trial_button(modal_footer,t("restart_confirm"),"trial_retry")
	_defer_focus(back)

func _boss_music_muted() -> bool:
	if panel_context.has("boss_music_muted"): return bool(panel_context.boss_music_muted)
	if is_instance_valid(world_ref):
		for property in world_ref.get_property_list():
			if str(property.name)=="boss_music_muted": return bool(world_ref.get("boss_music_muted"))
	return false

func _trial_button(parent: Node, caption: String, identity: String) -> Button:
	var button := _button(parent,caption,func(): action.emit(identity,null))
	button.name = "CompilerAction_"+identity
	button.set_meta("action_id",identity)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button

func _pause_panel() -> void:
	super._pause_panel()
	var trial := _is_boss_trial()
	if trial:
		for child in modal_body.get_children():
			if child is Button and child.text==t("restart"):
				modal_body.remove_child(child)
				child.queue_free()
	var caption := ("العودة من تجربة الزعيم" if language=="ar" else "Leave boss trial") if trial else ("تجربة د. كومبايلر" if language=="ar" else "Dr. Compiler trial")
	var actions_row := HBoxContainer.new()
	actions_row.name = "CompilerTrialActions"
	actions_row.add_theme_constant_override("separation",9)
	_localize(actions_row)
	modal_body.add_child(actions_row)
	_trial_button(actions_row,caption,"trial_return" if trial else "boss_trial")
	if trial: _trial_button(actions_row,"إعادة تجربة الزعيم" if language=="ar" else "Retry boss trial","trial_retry")
	var muted := _boss_music_muted()
	var music_caption := ("موسيقى الزعيم: مكتومة" if muted else "موسيقى الزعيم: مفعّلة") if language=="ar" else ("Boss music: muted" if muted else "Boss music: on")
	_trial_button(actions_row,music_caption,"boss_music_toggle")
	modal_body.move_child(actions_row,mini(2,modal_body.get_child_count()-1))
	var caption_note := "تجربة مستقلة؛ لا تغيّر تقدم القصة." if language=="ar" else "A separate trial; story progress stays untouched."
	var explanation := _paragraph(modal_body,caption_note,13)
	explanation.modulate.a = .68
	modal_body.move_child(explanation,actions_row.get_index()+1)
	if modal_body.get_parent() is ScrollContainer:
		modal_body.get_parent().follow_focus = true
