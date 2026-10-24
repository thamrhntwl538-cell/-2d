extends "res://scripts/ui/m23_hud.gd"
## M25 combat keeps only the top-left player vitals. Menus remain explicit pause.
var _clean_encounter:=false
var _prior_visibility: Array[Dictionary]=[]
func setup(world: Node2D) -> void:
	super.setup(world)
	boss_warning.hide()
	canvas.name="M24BellAndJournalHUD"

func _layout_combat_header() -> void:
	super._layout_combat_header()
	if is_instance_valid(status_label): status_label.text="M25 · حارس الجرس" if language=="ar" else "M25 · Bell Warden"

func update_status(room: Dictionary, progress: Dictionary, hint_key: String="", hint_args: Array=[]) -> void:
	super.update_status(room,progress,hint_key,hint_args)
	if int(room.get("id",0))==12 and is_instance_valid(objective_label):
		objective_label.text="استكشف مشغل التجليد وافتح ممر الخدمة." if language=="ar" else "Explore the bindery and open the service passage."

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(objective_label): objective_label.visible=not bool(boss_context.get("visible",false))
	_apply_encounter_clean()

func _apply_encounter_clean() -> void:
	if not is_instance_valid(canvas) or not is_instance_valid(world_ref): return
	var active:=bool(world_ref.get("boss_active"))
	if active:
		for child in canvas.get_children():
			# The player can still deliberately pause with Esc/Start. Those
			# modal controls are already hidden by their normal panel lifecycle.
			if child==combat_display or child==modal or child==modal_shade: continue
			if child is CanvasItem:
				if not _clean_encounter: _prior_visibility.append({"control":child,"visible":child.visible})
				child.hide()
		_clean_encounter=true
	elif _clean_encounter:
		for record in _prior_visibility:
			if is_instance_valid(record.control): record.control.visible=bool(record.visible)
		_prior_visibility.clear()
		_clean_encounter=false

func show_boss_intro(_context: Dictionary={}) -> void:
	# Entry is conveyed by the gates and the character, without a title card.
	_title_duration=0
	_title_elapsed=0
	_apply_encounter_clean()

func show_boss_victory(context: Dictionary={}) -> void:
	_apply_encounter_clean()
	super.show_boss_victory(context)
	boss_title.show()

func update_boss_status(context: Dictionary) -> void:
	var clean := context.duplicate(false)
	clean.warning_ar=""
	clean.warning_en=""
	clean.warning_progress=0.0
	super.update_boss_status(clean)
	if is_instance_valid(boss_display.phase_label):
		var second:=int(clean.get("phase",1))>=2
		boss_display.phase_label.text=("ميني بوس · الطور الثاني" if second else "ميني بوس · الطور الأول") if language=="ar" else ("MINIBOSS · PHASE II" if second else "MINIBOSS · PHASE I")
	if is_instance_valid(boss_warning): boss_warning.hide()
	_apply_encounter_clean()

func _refresh_boss_title() -> void:
	if not is_instance_valid(boss_title): return
	boss_title_caption.text=("حارس مشغل التجليد" if language=="ar" else "KEEPER OF THE BINDERY") if _title_kind=="intro" else ("سكن الجرس" if language=="ar" else "THE BELL FALLS SILENT")
	boss_title_name.text="حارس الجرس" if language=="ar" else "Bell Warden"
	for label in [boss_title_caption,boss_title_name]: label.text_direction=Control.TEXT_DIRECTION_RTL if language=="ar" else Control.TEXT_DIRECTION_LTR

func _pause_panel() -> void:
	super._pause_panel()
	for control in modal_body.find_children("*","Button",true,false):
		if str(control.get_meta("action_id",""))=="boss_trial": control.text="تجربة حارس الجرس" if language=="ar" else "Bell Warden trial"
		if bool(world_ref.get("boss_active")) and control.text in [t("journal"),t("map")]: control.hide()
