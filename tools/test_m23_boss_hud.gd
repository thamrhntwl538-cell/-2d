extends SceneTree
## Native configured UI proof, not a combat win or world traversal recording.
const HUD = preload("res://scripts/ui/m23_hud.gd")
const Puzzle = preload("res://scripts/stage/m22_puzzle_state.gd")
var world: Node2D
var hud: CanvasLayer
var checks: int = 0
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var observed_actions: Array[String] = []

class UIWorld extends Node2D:
	var hero: Node2D
	var is_boss_trial: bool = false
	var boss_music_muted: bool = false
	func combat_hud_context() -> Dictionary:
		return {"hp":6,"energy":66,"max_energy":99,"wallet":28,"equipped":["draw","reach"],"capacity":4,"used_capacity":3,"spell_owned":true}

func _initialize() -> void:
	call_deferred("run_check")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func frames(count: int) -> void:
	for index in range(count): await process_frame

func pad(button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await frames(3)
	event.pressed = false
	Input.parse_input_event(event)
	await frames(3)

func find_action(identity: String, node: Node = null) -> Button:
	if node==null: node = hud.modal_body
	if node is Button and str(node.get_meta("action_id",""))==identity: return node
	for child in node.get_children():
		var result := find_action(identity,child)
		if result: return result
	return null

func activate(identity: String) -> void:
	var button := find_action(identity)
	check(is_instance_valid(button),"Pause has action "+identity)
	if not is_instance_valid(button): return
	button.grab_focus()
	await frames(2)
	await pad(JOY_BUTTON_A)
	check(not observed_actions.is_empty() and observed_actions[-1]==identity,"Real JOY_A activates "+identity)

func capture(tag: String, description: String) -> void:
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	var folder := "user://m23_ui_samples"
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder+"/"+tag+".jpg"
	check(not frame.is_empty() and frame.save_jpg(path,.94)==OK,"Native sample saved: "+tag)
	samples.append({"path":path,"configured_ui_fixture":true,"description":description})
	print("M23 UI SAMPLE ",ProjectSettings.globalize_path(path))

func run_check() -> void:
	world = UIWorld.new()
	root.add_child(world)
	var background := ColorRect.new()
	background.color = Color("17202b")
	background.size = Vector2(root.size)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(background)
	hud = HUD.new()
	world.add_child(hud)
	hud.setup(world)
	hud.action.connect(func(identity: String, _value: Variant): observed_actions.append(identity))
	var room := {"id":14,"title_ar":"مدرج المترجم","title_en":"The Compiler's Hall"}
	var progress := Puzzle.new_progress()
	progress.visited = [14]
	hud.update_status(room,progress)
	var status := {"visible":true,"hp":48,"max_hp":48,"phase":1,"state":"bolts_warning","warning_ar":"شيفرة قادمة — غيّر موضعك","warning_en":"INCOMING CODE — change position","warning_progress":.45}
	var original_progress := JSON.stringify(progress)
	hud.update_boss_status(status)
	await frames(22)
	check(hud.boss_display.modulate.a>.99,"Boss bar fades into view")
	check(hud.boss_display.name_label.text=="د. كومبايلر","Arabic boss name is shaped by a native Label")
	check(hud.boss_warning_label.text==str(status.warning_ar),"Arabic warning uses the actual encounter cue")
	check(absf(hud.boss_warning_progress.value-.45)<.01,"Warning progress follows encounter timing")
	check(hud.boss_warning.size.y<=68 and hud.boss_warning.position.y+hud.boss_warning.size.y<root.size.y*.35,"Initial Arabic cue stays compact and clears the arena floor")
	check(not hud.hint_label.visible,"Boss bar does not collide with interaction hints")
	check(hud.toast_label.position.y<hud.boss_display.position.y,"Boss toasts avoid the ground-level health bar")
	check(hud.boss_display.position.y+hud.boss_display.size.y<root.size.y-38,"Boss bar clears bottom controls")
	check(hud.combat_display.get_script().resource_path=="res://scripts/ui/m22_combat_display.gd","Six lanterns and round shared-energy HUD remain unchanged")
	await capture("boss_warning_ar","Configured native Arabic bar and exact incoming-code warning; neutral diagnostic background.")
	status.hp = 41
	hud.update_boss_status(status)
	await frames(3)
	check(hud.boss_display.damage_flash>0,"Boss damage gives a restrained local bar flash")
	check(hud.boss_display.chip_hp>hud.boss_display.shown_hp,"Delayed damage chip preserves the removed health briefly")
	await frames(90)
	check(absf(hud.boss_display.shown_hp-41)<.05 and absf(hud.boss_display.chip_hp-41)<.15,"HP and damage chip settle to authoritative health")
	status.hp = 24
	status.phase = 2
	status.state = "pillars_warning"
	status.warning_ar = "أعمدة التجميع — اخرج من العلامات"
	status.warning_en = "COMPILE PILLARS — leave the marked ground"
	status.warning_progress = .7
	hud.set_language("en")
	hud.update_boss_status(status)
	await frames(22)
	check(hud.boss_display.name_label.text=="Dr. Compiler" and hud.boss_display.phase_label.text=="PHASE II","English name and second-phase label update together")
	check(hud.boss_warning_label.text==str(status.warning_en),"English safe instruction follows the same attack")
	check(hud.boss_warning_label.text_direction==Control.TEXT_DIRECTION_LTR,"English cue uses native LTR direction")
	check(hud.boss_warning.size.y<=68,"English cue preserves the same compact card height")
	await capture("boss_phase_two_en","Configured phase-II native bar at24/48 and actual marked-ground warning.")
	status.state = "stagger"
	status.warning_ar = ""
	status.warning_en = ""
	hud.update_boss_status(status)
	await frames(10)
	check(hud.boss_warning.modulate.a<.05 and not hud.boss_warning_progress.visible,"Warning disappears outside authored warning states")
	check(str(hud.boss_display.context.state)=="stagger","Stagger presentation reads the encounter state without changing it")
	hud.show_boss_intro()
	await frames(15)
	check(hud.boss_title.modulate.a>.8 and not paused,"Intro title appears without pausing the runtime")
	await frames(90)
	check(hud.boss_title.modulate.a<.01,"Nonblocking intro fades after1.5 seconds")
	hud.show_boss_victory()
	await frames(15)
	check(hud.boss_title_caption.text=="JUDGMENT ENDED" and not paused,"Localized victory title does not pause gameplay")
	var panel := {"progress":progress,"room":room,"rooms":[room],"is_boss_trial":false,"boss_music_muted":false}
	hud.open_panel("pause",panel)
	await frames(24)
	check(hud.boss_display.modulate.a<.01 and hud.boss_title.modulate.a<.01,"Pause ducks boss bar and encounter title")
	check(hud.canvas.get_children().find(hud.boss_display)<hud.modal_shade.get_index(),"Boss UI draws below the modal shade and reading panels")
	check(find_action("trial_return")==null and find_action("trial_retry")==null,"Story pause offers no trial-only return or retry")
	await activate("boss_trial")
	await activate("boss_music_toggle")
	hud.close_panel(true)
	world.is_boss_trial = true
	world.boss_music_muted = true
	panel.is_boss_trial = true
	panel.boss_music_muted = true
	hud.open_panel("pause",panel)
	await frames(24)
	check(find_action("boss_trial")==null,"Trial pause replaces the story trial-entry action")
	check(find_action("boss_music_toggle").text.contains("muted"),"Pause reflects authoritative music mute state")
	await activate("trial_return")
	find_action("trial_return").grab_focus()
	await pad(JOY_BUTTON_DPAD_RIGHT)
	check(root.gui_get_focus_owner()==find_action("trial_retry"),"Real D-pad Right moves from trial return to retry")
	await pad(JOY_BUTTON_A)
	check(observed_actions[-1]=="trial_retry","Real controller A activates the D-pad-selected retry")
	check(hud.modal_body.get_parent().follow_focus,"Long pause menus follow controller focus while scrolling")
	await activate("boss_music_toggle")
	await capture("boss_trial_pause_en","Configured trial pause: actual native controller buttons emit return/retry/music actions; story progress stays world owned.")
	hud.close_panel(true)
	hud.open_panel("restart",panel)
	await frames(24)
	check(hud.modal_title.text=="Restart the encounter","Trial restart title describes an isolated encounter retry")
	check(hud.t("restart_body")=="Start a fresh attempt without changing library progress.","Trial restart never claims a return to the First Page or a story reset")
	var retry_confirm := find_action("trial_retry",hud.modal_footer)
	check(is_instance_valid(retry_confirm),"Trial restart confirms through the isolated trial_retry action")
	retry_confirm.grab_focus()
	await pad(JOY_BUTTON_A)
	check(observed_actions[-1]=="trial_retry","Real controller A confirms isolated retry from the restart dialog")
	hud.close_panel(true)
	var note := {"id":"entrance_notice","kind":"note","text_key":"entrance_note","room_id":1}
	panel.definition = note
	panel.notes = [note]
	panel.progress.notes = [note.id]
	hud.open_panel("note",panel)
	await frames(24)
	check(hud.panel_open and hud.current_panel=="note" and hud.boss_display.modulate.a<.01,"Individual reader remains usable with boss presentation ducked")
	hud.close_panel(true)
	progress.notes = []
	check(JSON.stringify(progress)==original_progress,"Boss presentation never grants or mutates story progress")
	hud.update_boss_status({"visible":false,"hp":0,"max_hp":48})
	await frames(22)
	check(hud.boss_display.modulate.a<.01 and hud.hint_label.visible,"Ending an encounter restores ordinary HUD space")
	var report := {"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"configured_ui_fixture":true,"real_controller_confirm_events":true,"samples":samples}
	FileAccess.open("user://m23_ui_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M23 UI REPORT ",JSON.stringify(report))
	world.queue_free()
	world = null
	hud = null
	await frames(4)
	quit(0 if failures.is_empty() else 1)
