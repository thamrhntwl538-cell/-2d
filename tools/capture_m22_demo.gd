extends "res://tools/capture_m18.gd"
## Configured native MovieWriter showcase, not an uninterrupted playthrough.
## Scene positions and already-kept pages are declared fixtures. Interacting,
## opening/closing the reader, language keys and enemy attack AI remain real.
const M22_SCENE := "res://scenes/stage_01/folding_library_m22.tscn"
const DEMO_REPORT := "user://m22_demo_source_report.json"
var caption: Label
var segments: Array[Dictionary] = []
var first_movie_frame := 0
var last_movie_frame := 0
var tracked_frames := 0
var zoom_value := 1.6
var camera_center := Vector2.ZERO
var follow_hero := false
var observations: Dictionary = {}

func _initialize() -> void:
	call_deferred("run_demo")

func film(frames: int) -> void:
	for tick in range(frames):
		await step(1)
		world.camera.zoom = Vector2.ONE*zoom_value
		world.camera.position = world.hero.position+Vector2(0,-95) if follow_hero else camera_center
		world.camera.reset_smoothing()
		world.camera.force_update_scroll()
		tracked_frames += 1

func segment(title: String, zoom: float, center: Vector2, follow: bool = false) -> void:
	zoom_value = zoom
	camera_center = center
	follow_hero = follow
	caption.text = "M22 / CONFIGURED NATIVE SHOWCASE / "+title
	if segments.is_empty(): first_movie_frame = Engine.get_process_frames()
	segments.append({"frame":Engine.get_process_frames(),"tracked_frame":tracked_frames,"room":world.current_room,"caption":title,"configured_room_and_position":true,"camera_zoom":zoom})
	print("M22 DEMO SEGMENT ",Engine.get_process_frames()," ",title)

func action_once(action: String, held: int = 2, after: int = 0) -> void:
	Input.action_press(action)
	await film(held)
	Input.action_release(action)
	if after > 0: await film(after)

func key_once(code: Key, after: int = 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await film(2)
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await film(maxi(2,after))

func setup_room(id: int, at: Vector2) -> void:
	if world.hud.panel_open:
		world.hud.action.emit("close_panel",null)
		for tick in range(60):
			if not world.panel_closing: break
			await step(1)
	for action in ["move_left","move_right","attack","jump","interact"]: Input.action_release(action)
	world._load_room(id,"left",at)
	world.hero.hp = 6
	world.hero.energy = 99
	world.hero.velocity = Vector2.ZERO
	world.hero.reset_combat_motion()
	world.camera.process_mode = Node.PROCESS_MODE_DISABLED
	world.camera.zoom = Vector2.ONE*zoom_value
	world.camera.position = camera_center
	world.camera.reset_smoothing()
	world.camera.force_update_scroll()
	world.fade.visible = false
	await step(18)
	if not world.hero.is_on_floor(): failures.append("Demo position is unsupported in room%02d"%id)

func enemy_of(kind: String) -> Node2D:
	for actor in world.enemies:
		if is_instance_valid(actor) and actor.get_script().resource_path.ends_with(kind+".gd"): return actor
	return null

func run_demo() -> void:
	remember_files()
	var packed: PackedScene = load(M22_SCENE)
	if packed == null:
		push_error("M22 demo scene is not ready")
		quit(1)
		return
	world = packed.instantiate()
	packed = null
	if not world.get_script() is GDScript or world.get_script().resource_path != "res://scripts/stage/m22_folding_library.gd":
		push_error("M22 world script did not load; finish product dependencies before capture")
		world.free()
		quit(1)
		return
	world.restore_saved_game = false
	world.environment_preview = true
	world.transition_seconds = .001
	root.add_child(world)
	await step(40)
	world.progress.weapon_owned = true
	world.combat_state.dash_owned = true
	world.combat_state.spell_owned = true
	world.hero.has_blade = true
	world.hero.has_dash = true
	world.hero.has_code_slash = true
	world.hud.set_language("ar")
	var overlay := CanvasLayer.new()
	overlay.layer = 99
	root.add_child(overlay)
	var backing := ColorRect.new()
	backing.position = Vector2(0,678)
	backing.size = Vector2(1280,42)
	backing.color = Color(.025,.03,.05,.96)
	overlay.add_child(backing)
	caption = Label.new()
	caption.position = Vector2(10,683)
	caption.size = Vector2(1260,30)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",17)
	caption.add_theme_color_override("font_color",Color("ead6b3"))
	overlay.add_child(caption)
	zoom_value = 1.65
	camera_center = Vector2(1170,1050)
	await setup_room(1,Vector2(1060,1140))
	segment("ROOM01 / CURATED READING NOOK + APPROVED HERO",1.65,Vector2(1170,1050))
	await film(30)
	await action_once("move_right",20,50)
	segment("REAL INTERACT / ARABIC READER / OPENING ANIMATION",1.65,camera_center)
	await action_once("interact",2,72)
	observations.physical_reader_opened = world.hud.panel_open and world.hud.current_panel=="note"
	if not observations.physical_reader_opened: failures.append("Real Interact did not open the physical reading leaf")
	segment("F2 INPUT / SAME PAGE IN ENGLISH",1.65,camera_center)
	await key_once(KEY_F2,52)
	observations.reader_english = world.hud.language=="en"
	await key_once(KEY_ESCAPE,18)
	# A configured kept-page inventory makes the journal index visible without
	# claiming those records were acquired during this short room-cut showcase.
	for identity in ["assignment_note","archive_note","margin_lantern_clue"]:
		if not world.progress.notes.has(identity): world.progress.notes.append(identity)
	for room_id in [1,2,5,6]:
		if not world.progress.visited.has(room_id): world.progress.visited.append(room_id)
	await key_once(KEY_F2,2)
	segment("N INPUT / JOURNAL WITH CONFIGURED KEPT-PAGE INVENTORY",1.65,camera_center)
	await key_once(KEY_N,62)
	observations.journal_opened = world.hud.panel_open and world.hud.current_panel=="journal"
	segment("INDEX SELECTION / REAL ENTER / PAGE-LEAF ANIMATION",1.65,camera_center)
	var selected := false
	for button in world.hud._index_buttons:
		if str(button.get_meta("journal_entry_id",""))=="assignment_note":
			button.grab_focus()
			selected = true
			break
	if selected: await key_once(KEY_ENTER,56)
	else: failures.append("Configured journal record missing from index")
	observations.index_record = str(world.hud._active_record.get("id",""))
	segment("F2 INPUT / BILINGUAL JOURNAL + PLACE NAMES",1.65,camera_center)
	await key_once(KEY_F2,52)
	# The visible Places button is activated through keyboard focus and Enter.
	var places := find_button(world.hud.modal,"Places")
	if is_instance_valid(places):
		places.grab_focus()
		await key_once(KEY_ENTER,48)
	else: failures.append("Places journal section button missing")
	observations.places_section = str(world.hud.panel_context.get("journal_section",""))
	await key_once(KEY_ESCAPE,18)
	zoom_value = 1.8
	camera_center = Vector2(1070,800)
	await setup_room(3,Vector2(1040,900))
	segment("ROOM03 / REAL WRAITH WARNING / DIVE TO OLD TARGET",1.8,Vector2(1070,800))
	var wraith := enemy_of("m22_popup_wraith")
	var warned := false
	for tick in range(145):
		await film(1)
		if is_instance_valid(wraith) and wraith.state=="windup":
			warned = true
			break
	if warned:
		var old_target: Vector2 = wraith.captured_target
		await action_once("move_left",16,32)
		observations.wraith_locked_old_target = is_instance_valid(wraith) and wraith.captured_target==old_target
		observations.wraith_dodge_distance = absf(world.hero.position.x-old_target.x)
		Input.action_press("jump")
		Input.action_press("attack")
		await film(8)
		Input.action_release("jump")
		Input.action_release("attack")
		await film(80)
	else: failures.append("Native wraith did not begin its own warning")
	observations.wraith_warning_observed = warned
	zoom_value = 1.4
	camera_center = Vector2(2800,775)
	await setup_room(8,Vector2(2600,900))
	segment("ROOM08 / REAL TURRET BURST / SOLID BOOK COVER / RELOAD",1.4,Vector2(2800,775))
	var turret := enemy_of("m22_syntax_turret")
	var states: Array[String] = []
	var starting_hp: int = world.hero.hp
	for tick in range(300):
		await film(1)
		if is_instance_valid(turret) and not states.has(turret.state): states.append(turret.state)
	observations.turret_states = states
	observations.turret_actual_shots = turret.total_shots if is_instance_valid(turret) else 0
	observations.cover_hero_hp_unchanged = world.hero.hp==starting_hp
	if not states.has("burst") or not states.has("reload"): failures.append("Native turret burst/reload missing from demo")
	if not observations.cover_hero_hp_unchanged: failures.append("Book cover failed to protect the configured hero")
	last_movie_frame = Engine.get_process_frames()
	for action in ["attack","jump","move_left","move_right","interact","journal","switch_language"]: Input.action_release(action)
	stop_audio(world)
	OS.delay_msec(120)
	await process_frame
	world.queue_free()
	world = null
	overlay.queue_free()
	await process_frame
	await process_frame
	var restored := restore_files()
	var report := {"engine":Engine.get_version_info().string,"capture":"native Godot MovieWriter, 60fps","configured_showcase":true,"uninterrupted_playthrough":false,"configured_kept_pages":["assignment_note","archive_note","margin_lantern_clue"],"configured_visited_places":[1,2,5,6],"configured_abilities":["sword","dash","spell"],"actual_input":["move_right","interact","F2","Escape","N","focused index Enter","focused Places Enter","move_left","jump","attack"],"enemy_attack_state_injection":false,"movie_start_frame":first_movie_frame,"movie_end_frame":last_movie_frame,"tracked_frames":tracked_frames,"segments":segments,"observations":observations,"failures":failures,"save_restored":restored,"scope":"Configured room01/03/08 positions and kept-page inventory; actual bilingual reader/journal controls and original hero; native wraith old-target dive and native turret burst/cover/reload. Not campaign traversal or benchmark evidence."}
	FileAccess.open(DEMO_REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M22_DEMO_RESULT ",JSON.stringify(report))
	OS.delay_msec(50)
	await process_frame
	quit(0 if restored and failures.is_empty() else 1)

func find_button(node: Node, title: String) -> Button:
	if node is Button and node.text==title: return node
	for child in node.get_children():
		var found := find_button(child,title)
		if is_instance_valid(found): return found
	return null
