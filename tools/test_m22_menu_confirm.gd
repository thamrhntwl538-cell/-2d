extends "res://tools/test_m22_journal.gd"
## Focused regression for real controller confirm events in native menus.
var observed_actions: Array[String] = []

func pad(button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await frames(3)
	event.pressed = false
	Input.parse_input_event(event)
	await frames(4)

func run_check() -> void:
	var previous_events := InputMap.action_get_events("ui_accept")
	world = UIWorld.new()
	root.add_child(world)
	hud = HUD.new()
	world.add_child(hud)
	hud.setup(world)
	hud.action.connect(func(identity: String, _value: Variant): observed_actions.append(identity))
	var retained := true
	for event in previous_events:
		if not InputMap.action_has_event("ui_accept",event): retained = false
	check(retained,"Adding controller confirm preserves all prior keyboard/menu events")
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	check(accept.is_action_pressed("ui_accept"),"Real JOY_A matches native ui_accept")
	var first := {"id":"entrance_notice","kind":"note","text_key":"entrance_note","room_id":1}
	var second := {"id":"archive_note_1","kind":"note","text_key":"archive_water","room_id":6}
	var progress := Puzzle.new_progress()
	progress.notes = [first.id,second.id]
	progress.visited = [1,6]
	var room := {"id":1,"title_ar":"بهو الصفحة الأولى","title_en":"The First Page","objects":[first,second]}
	var context := {"progress":progress,"room":room,"rooms":[room],"notes":[first,second],"selected_note":second.id}
	hud.update_status(room,progress)
	hud.open_panel("journal",context)
	await frames(22)
	check(str(root.gui_get_focus_owner().get_meta("journal_entry_id",""))==second.id,"Journal opens focused on its remembered last entry")
	await pad(JOY_BUTTON_DPAD_UP)
	check(str(root.gui_get_focus_owner().get_meta("journal_entry_id",""))==first.id,"D-pad Up moves from last entry to the preceding title")
	await pad(JOY_BUTTON_A)
	check(str(hud._active_record.id)==first.id,"Real controller A opens the highlighted journal title")
	hud.close_panel(true)
	hud.open_panel("map",context)
	await frames(22)
	await pad(JOY_BUTTON_A)
	check(not observed_actions.is_empty() and observed_actions[-1]=="close_panel","Controller A activates the native map Close button")
	hud.close_panel(true)
	hud.open_panel("ink",context)
	await frames(22)
	await pad(JOY_BUTTON_A)
	check(not observed_actions.is_empty() and observed_actions[-1]=="puzzle_confirm","Controller A activates native puzzle confirmation")
	hud.close_panel(true)
	await frames(3)
	var report := {"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"real_input_events":true,"configured_ui_fixture":true}
	FileAccess.open("user://m22_menu_confirm_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M22 MENU CONFIRM REPORT ",JSON.stringify(report))
	world.queue_free()
	world = null
	hud = null
	await frames(4)
	quit(0 if failures.is_empty() else 1)
