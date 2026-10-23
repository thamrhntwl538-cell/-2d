extends SceneTree
## Configured native UI fixture. This checks the reader, not level traversal.
const HUD = preload("res://scripts/ui/m22_hud.gd")
const Puzzle = preload("res://scripts/stage/m22_puzzle_state.gd")
var world: Node2D
var hud: CanvasLayer
var failures: Array[String] = []
var checks: int = 0
var closed_signals: int = 0
var captures: Array[Dictionary] = []
var close_requests: int = 0
var cursor_requests: int = 0

class UIWorld extends Node2D:
	var hero: Node2D
	func combat_hud_context() -> Dictionary:
		return {"hp":6,"energy":99,"max_energy":99,"wallet":0,"equipped":[],"capacity":3,"used_capacity":0}

func _initialize() -> void:
	call_deferred("run_check")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func frames(count: int = 3) -> void:
	for index in range(count): await process_frame

func capture(name: String, note: String) -> void:
	if "--capture-journal" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://m22_journal_samples")
	var path := "user://m22_journal_samples/"+name+".jpg"
	check(not frame.is_empty(),"Native UI viewport is nonempty")
	if not frame.is_empty(): check(frame.save_jpg(path,.94)==OK,"Native UI sample saved")
	captures.append({"path":path,"width":frame.get_width(),"height":frame.get_height(),"configured_ui_fixture":true,"note":note})
	print("M22 JOURNAL SAMPLE ",ProjectSettings.globalize_path(path))

func run_check() -> void:
	world = UIWorld.new()
	root.add_child(world)
	hud = HUD.new()
	world.add_child(hud)
	hud.setup(world)
	hud.panel_closed.connect(func(): closed_signals+=1)
	hud.action.connect(func(action_id: String, _value: Variant):
		if action_id=="close_panel": close_requests+=1
		elif action_id=="journal_cursor": cursor_requests+=1)
	var notes: Array = Puzzle.extra_notes()
	var clue: Dictionary = {}
	for item in notes:
		if str(item.id)=="margin_lantern_clue": clue = item
	var entrance := {"id":"entrance_notice","kind":"note","text_key":"entrance_note","room_id":1}
	var archive := {"id":"archive_note_1","kind":"note","text_key":"archive_water","room_id":6}
	var long_note := {"id":"ui_long_fixture","kind":"note","title_ar":"اختبار صفحات القارئ","title_en":"Reader pagination fixture","pages_ar":["صفحة عربية أولى للتحقق من فصل الصفحات.","صفحة عربية ثانية للتحقق من متابعة القراءة. ".repeat(45)],"pages_en":["First English page used to verify independent page reading.","Second English page used to verify continued reading. ".repeat(45)]}
	var progress := Puzzle.new_progress()
	progress.notes = ["entrance_notice","archive_note_1","margin_lantern_clue","ui_long_fixture"]
	progress.visited = [1,5,6]
	var rooms := [
		{"id":1,"title_ar":"بهو الصفحة الأولى","title_en":"The First Page","objects":[entrance]},
		{"id":5,"title_ar":"الهوامش المحذوفة","title_en":"Erased Margins","objects":[clue]},
		{"id":6,"title_ar":"الأرشيف المطوي","title_en":"Folded Archive","objects":[archive]}
	]
	var context := {"progress":progress,"rooms":rooms,"room":rooms[0],"notes":[entrance,archive,clue,long_note],"note_catalog":notes+[long_note],"selected_note":"ui_long_fixture"}
	var before := JSON.stringify(progress)
	hud.update_status(rooms[0],progress)
	hud.open_panel("journal",context)
	await frames(24)
	check(hud.panel_open and hud.current_panel=="journal","Journal opens")
	check(cursor_requests>0,"Opening a new selected page requests bookmark persistence")
	check(hud._journal_entries().size()==4,"Journal preserves authored records by stable ID")
	check(hud.reading_page_count==2 and hud.reading_page==0,"Authored pages remain individual pages")
	check(hud._record_text(clue).title==str(clue.title_ar),"Custom Arabic note title survives catalog normalization")
	check(hud._record_text(clue).body==str(clue.text_ar),"Custom Arabic note body survives catalog normalization")
	check(is_instance_valid(hud._index_scroll) and hud._index_scroll.follow_focus,"Journal list follows keyboard/controller focus")
	check(is_instance_valid(root.gui_get_focus_owner()),"Modal supplies a focus target")
	check(str(root.gui_get_focus_owner().get_meta("journal_entry_id",""))=="ui_long_fixture","Initial focus follows the selected journal entry")
	var next := InputEventJoypadButton.new()
	next.button_index = JOY_BUTTON_RIGHT_SHOULDER
	next.pressed = true
	Input.parse_input_event(next)
	await frames(20)
	check(hud.reading_page==1,"Controller right shoulder turns a reader page")
	check(hud._reader_scroll.get_v_scroll_bar().max_value>hud._reader_scroll.get_v_scroll_bar().page,"Long page remains vertically scrollable")
	next.pressed = false
	Input.parse_input_event(next)
	hud.set_language("en")
	await frames(3)
	check(str(hud.panel_context.selected_note)=="ui_long_fixture" and hud.reading_page==1,"Language switch preserves selected stable note and page")
	check(hud._record_text(clue).title==str(clue.title_en),"Custom English title is used")
	check(hud._record_text(clue).body==str(clue.text_en),"Custom English body is used")
	check(hud.localized_room_name(rooms[2])=="Folded Archive","Area names use the room catalog")
	var remembered: Dictionary = hud.journal_cursor.duplicate(true)
	hud.close_panel(true)
	hud.journal_cursor = {}
	hud.restore_journal_cursor(remembered)
	var reopened: Dictionary = context.duplicate(false)
	reopened.erase("selected_note")
	reopened.erase("reading_page")
	hud.open_panel("journal",reopened)
	await frames(24)
	check(str(hud.panel_context.selected_note)=="ui_long_fixture" and hud.reading_page==1,"Restored bookmark resumes the same note and page on reopening")
	var previous := InputEventKey.new()
	previous.keycode = KEY_PAGEUP
	previous.pressed = true
	Input.parse_input_event(previous)
	await frames(20)
	check(hud.reading_page==0,"Keyboard PageUp turns to the previous page")
	previous.pressed = false
	Input.parse_input_event(previous)
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.pressed = true
	Input.parse_input_event(back)
	await frames(2)
	check(close_requests==1 and hud.panel_open,"Controller back requests world-owned closing without unpausing itself")
	back.pressed = false
	Input.parse_input_event(back)
	var prior_closed := closed_signals
	hud.close_panel()
	check(hud.panel_open and hud.closing_panel,"Closing animation holds the open/modal state")
	await frames(20)
	check(not hud.panel_open and not hud.closing_panel and closed_signals==prior_closed+1,"Closing emits exactly one completion signal")
	hud.close_panel(true)
	check(closed_signals==prior_closed+1,"Closing an already closed panel does not emit another completion")
	check(JSON.stringify(progress)==before,"Reader and journal do not rewrite collected/puzzle progress")
	# Native samples use authored game notes only; the pagination fixture is removed.
	progress.notes.erase("ui_long_fixture")
	context.notes = [entrance,archive,clue]
	context.note_catalog = notes
	context.selected_note = "margin_lantern_clue"
	context.reading_page = 0
	hud.set_language("ar")
	hud.open_panel("journal",context)
	await frames(24)
	await capture("journal_ar","Configured journal showing actual authored M22 clue, Arabic localization and native reading diagram.")
	hud.set_language("en")
	await frames(4)
	await capture("journal_en","Same authored note and stable selection, English localization.")
	hud.close_panel(true)
	context.definition = clue
	hud.set_language("ar")
	hud.open_panel("note",context)
	await frames(24)
	await capture("reading_ar","Configured individual reader with the authored physical-lantern clue; no journal list.")
	hud.close_panel(true)
	await frames(2)
	var report := {"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"configured_ui_fixture":true,"captures":captures}
	FileAccess.open("user://m22_journal_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M22 JOURNAL REPORT ",JSON.stringify(report))
	world.queue_free()
	world = null
	hud = null
	await frames(4)
	quit(0 if failures.is_empty() else 1)
