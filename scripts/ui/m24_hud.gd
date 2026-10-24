extends "res://scripts/ui/m23_hud.gd"
## No warning UI: only enemy name/health and normal encounter title.
func setup(world: Node2D) -> void:
	super.setup(world)
	boss_warning.hide()
	canvas.name="M24BellAndJournalHUD"

func _layout_combat_header() -> void:
	super._layout_combat_header()
	if is_instance_valid(status_label): status_label.text="M24 · حارس الجرس" if language=="ar" else "M24 · Bell Warden"

func update_status(room: Dictionary, progress: Dictionary, hint_key: String="", hint_args: Array=[]) -> void:
	super.update_status(room,progress,hint_key,hint_args)
	if int(room.get("id",0))==12 and is_instance_valid(objective_label):
		objective_label.text="استكشف مشغل التجليد وافتح ممر الخدمة." if language=="ar" else "Explore the bindery and open the service passage."

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(objective_label): objective_label.visible=not bool(boss_context.get("visible",false))

func update_boss_status(context: Dictionary) -> void:
	var clean := context.duplicate(false)
	clean.warning_ar=""
	clean.warning_en=""
	clean.warning_progress=0.0
	super.update_boss_status(clean)
	if is_instance_valid(boss_display.phase_label): boss_display.phase_label.text="ميني بوس" if language=="ar" else "MINIBOSS"
	if is_instance_valid(boss_warning): boss_warning.hide()

func _refresh_boss_title() -> void:
	if not is_instance_valid(boss_title): return
	boss_title_caption.text=("حارس مشغل التجليد" if language=="ar" else "KEEPER OF THE BINDERY") if _title_kind=="intro" else ("سكن الجرس" if language=="ar" else "THE BELL FALLS SILENT")
	boss_title_name.text="حارس الجرس" if language=="ar" else "Bell Warden"
	for label in [boss_title_caption,boss_title_name]: label.text_direction=Control.TEXT_DIRECTION_RTL if language=="ar" else Control.TEXT_DIRECTION_LTR

func _pause_panel() -> void:
	super._pause_panel()
	for control in modal_body.find_children("*","Button",true,false):
		if str(control.get_meta("action_id",""))=="boss_trial": control.text="تجربة حارس الجرس" if language=="ar" else "Bell Warden trial"
