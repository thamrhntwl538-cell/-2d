extends Node2D
## M23 Dr. Compiler encounter, isolated replay trial and original adaptive score.
signal room_changed(room_id: int)
const Layouts = preload("res://scripts/stage/m23_layouts.gd")
const Hero = preload("res://scripts/combat/m23_player.gd")
const RoomCamera = preload("res://scripts/camera/academic_camera.gd")
const PaperPlatform = preload("res://scripts/stage/m17_paper_platform.gd")
const RoomVisuals = preload("res://scripts/stage/m23_room_visuals.gd")
const Puzzle = preload("res://scripts/stage/m22_puzzle_state.gd")
const Item = preload("res://scripts/interactables/m22/library_interactable.gd")
const HUD = preload("res://scripts/ui/m23_hud.gd")
const SAVE_FILE := "user://folding_library_m18.json"
const PREVIEW_SAVE_FILE := "user://folding_library_m18_preview.json"
const SETTINGS_FILE := "user://folding_library_m18_settings.cfg"
const CombatState = preload("res://scripts/combat/m18_combat_state.gd")
const Controls = preload("res://scripts/combat/m18_controls.gd")
const Larva = preload("res://scripts/enemies/m21_glitch_larva.gd")
const PopupWraith = preload("res://scripts/enemies/m22_popup_wraith.gd")
const SyntaxTurret = preload("res://scripts/enemies/m22_syntax_turret.gd")
const StoryText = preload("res://scripts/ui/m17_text.gd")
const ArrivalTitle = preload("res://scripts/ui/m22_arrival_title.gd")
const CombatPickup = preload("res://scripts/combat/m18_pickup.gd")
const Coin = preload("res://scripts/combat/m22_coin.gd")
const CurrencyLedger = preload("res://scripts/combat/m22_currency_ledger.gd")
const Cleave = preload("res://scripts/combat/m18_projectile.gd")
const Compiler = preload("res://scripts/bosses/m23_dr_compiler.gd")
const CompilerArena = preload("res://scripts/stage/m23_compiler_arena.gd")
const CompilerMusic = preload("res://scripts/audio/m23_boss_music.gd")
const Soundscape = preload("res://scripts/audio/m23_soundscape.gd")
const TRIAL_SAVE := "user://compiler_trial_m23.json"
const TRIAL_RETURN := "user://compiler_trial_return_m23.json"
const TRIAL_SCENE := "res://scenes/bosses/compiler_trial_m23.tscn"
const LIBRARY_SCENE := "res://scenes/stage_01/folding_library_m23.tscn"
const COMBAT_FLAGS := ["encounter_assignments_cleared", "guard_clear", "compiler_seal_owned", "seal_registered", "boss_defeated"]
@export var is_boss_trial: bool = false
@export var environment_preview: bool = true
@export var restore_saved_game: bool = true
@export var transition_seconds: float = 0.28
@export_file("*.tscn") var next_world_scene: String = ""
var current_room: int = 1
var data: Dictionary = {}
var progress: Dictionary = {}
var checkpoint: Dictionary = {"room":1, "position":[310.0,1260.0]}
var gameplay_active: bool = false
var transitioning: bool = false
var paused: bool = false
var tour_finished: bool = false
var elapsed: float = 0.0
var hero: CharacterBody2D
var camera: Camera2D
var hud: CanvasLayer
var active_room: Node2D
var visuals: Node2D
var surface_root: Node2D
var objects: Array[Dictionary] = []
var fold_active: bool = false
var fold_progress: float = 0.0
var fold_flag: String = ""
var fade: ColorRect
var music: AudioStreamPlayer
var encounter_actors: Dictionary = {}
var registered_boss: Node2D
var _panel_definition: Dictionary = {}
var _hud_timer: float = 0.0
var _respawning: bool = false
var _fold_preview: Node2D
var combat_state = CombatState.new()
var controls = Controls.new()
var enemies: Array[Node2D] = []
var at_bench: bool = false
var awaiting_action: String = ""
var hit_stop_remaining: float = 0.0
var _rewarded_enemies: Dictionary = {}
var suppress_pause_frames: int = 0
var arrival_grace: float = 1.2
var arrival_title: CanvasLayer
var panel_closing: bool = false
var _coin_sound_time: float = 0.0
var boss_active := false
var boss_arena: Node2D
var boss_music: Node
var soundscape: Node
var sound_events: Dictionary:
	get: return soundscape.event_counts if is_instance_valid(soundscape) else {}
var boss_attempts := 0
var boss_last_phase := 1
var boss_trauma := 0.0
var boss_music_muted := false
var _camera_zoom := Vector2.ONE
var _boss_camera_tween: Tween
var _return_record: Dictionary = {}
var protected_kinds := ["note", "secret", "book", "bench", "dialogue", "ink_control", "process_control", "output_control", "balance_control", "secret_overlay", "secret_pop", "margin_lantern"]

# Creation/layout hooks preserve prior releases while allowing the integrated
# M28 journey to reuse the same world, controls, journal and combat authority.
func _room_layout(id: int) -> Dictionary: return Layouts.room(id)
func _all_layouts() -> Array[Dictionary]: return Layouts.all_rooms()
func _create_hero() -> CharacterBody2D: return Hero.new()
func _create_hud() -> CanvasLayer: return HUD.new()
func _create_room_visuals() -> Node2D: return RoomVisuals.new()

func _ready() -> void:
	_register_inputs()
	progress = Puzzle.new_progress()
	CurrencyLedger.sanitize(progress)
	progress.preview_departed = false
	hud = _create_hud()
	add_child(hud)
	hud.setup(self)
	hud.action.connect(_on_ui_action)
	if hud.has_signal("panel_closed"):
		hud.connect("panel_closed", _panel_close_finished)
	arrival_title = ArrivalTitle.new()
	add_child(arrival_title)
	camera = RoomCamera.new()
	add_child(camera)
	hero = _create_hero()
	hero.name = "LanternWarden_M23"
	hero.world_ref = self
	hero.z_index = 5
	add_child(hero)
	camera.target = hero
	_camera_zoom = camera.zoom
	if is_boss_trial:
		_setup_trial_loadout()
	elif restore_saved_game:
		_restore_save()
	# Interface settings are newer than the last checkpoint. A language switch
	# must survive quitting before the next gameplay save.
	_restore_settings()
	if not is_boss_trial: _read_trial_return()
	var resume_point: Dictionary = _return_record if not _return_record.is_empty() else checkpoint
	_load_room(int(resume_point.room), "left", Vector2(float(resume_point.position[0]), float(resume_point.position[1])))
	if not _return_record.is_empty():
		hero.hp = clampi(int(_return_record.get("hp",6)),1,6)
		hero.energy = clampf(float(_return_record.get("energy",99.0)),0,99)
	var presentation := CanvasLayer.new()
	presentation.layer = 90
	add_child(presentation)
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.color = Color(0.025,0.035,0.06,1)
	presentation.add_child(fade)
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/ambient.wav")
	music.volume_db = -29
	add_child(music)
	music.finished.connect(music.play)
	music.play()
	boss_music = CompilerMusic.new()
	add_child(boss_music)
	boss_music.setup(music)
	boss_music.set_muted(boss_music_muted)
	soundscape = Soundscape.new()
	add_child(soundscape)
	soundscape.setup(self)
	if is_boss_trial: _save()
	create_tween().tween_property(fade,"color:a",0.0,0.65)
	gameplay_active = true
	if bool(progress.get("preview_departed",false)) and environment_preview:
		_finish_preview.call_deferred()

func _register_inputs() -> void:
	controls.setup()

func _load_room(id: int, spawn_name: String = "left", exact_position: Vector2 = Vector2.INF) -> void:
	_reset_compiler_room()
	enemies.clear()
	_rewarded_enemies.clear()
	arrival_grace = 1.2
	panel_closing = false
	at_bench = false
	encounter_actors.clear()
	registered_boss = null
	objects.clear()
	if is_instance_valid(active_room):
		remove_child(active_room)
		active_room.free()
	current_room = clampi(id,1,15)
	data = _room_layout(current_room)
	var scene_path := str(data.get("scene",""))
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		active_room = load(scene_path).instantiate()
	else:
		active_room = Node2D.new()
	active_room.name = "LibraryArea_%02d" % current_room
	add_child(active_room)
	visuals = _create_room_visuals()
	active_room.add_child(visuals)
	visuals.setup(self,data)
	surface_root = Node2D.new()
	surface_root.name = "PlayablePaperGeometry"
	active_room.add_child(surface_root)
	_refresh_geometry()
	for definition in data.get("objects",[]):
		var item = CombatPickup.new() if str(definition.get("kind","")) in ["dash_pickup","spell_pickup","fitil_pickup","capacity_pickup","pogo_anchor"] else Item.new()
		item.name = str(definition.id).validate_node_name()
		active_room.add_child(item)
		item.setup(self,definition)
		item.position = definition.pos
		objects.append({"definition":definition,"node":item})
	var spawns: Dictionary = data.get("spawns",{})
	hero.position = spawns.get(spawn_name,spawns.get("left",Vector2(180,float(data.floor_y)))) if exact_position == Vector2.INF else exact_position
	hero.velocity = Vector2.ZERO
	hero.reset_combat_motion()
	hero.last_safe_position = hero.position
	hero.has_dash = combat_state.dash_owned
	hero.has_code_slash = combat_state.spell_owned
	hero.has_blade = bool(progress.get("weapon_owned",false))
	hero.movement_bounds = Vector2(32,float(data.size.x)-32)
	hero.fall_limit = float(data.size.y)+180
	camera.room_rect = Rect2(Vector2.ZERO,data.size)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(data.size.x)
	camera.limit_bottom = int(data.size.y)
	camera.position = camera.bounded(hero.position+Vector2(100,-230))
	camera.reset_smoothing()
	if not progress.visited.has(current_room):
		progress.visited.append(current_room)
	_spawn_room_enemy()
	_spawn_death_drop()
	_spawn_room_coins()
	_refresh_objects()
	_panel_definition = {}
	_update_hud()
	room_changed.emit(current_room)
	if is_instance_valid(arrival_title):
		arrival_title.present(data, hud.language)

func _refresh_geometry() -> void:
	for child in surface_root.get_children():
		surface_root.remove_child(child)
		child.free()
	for definition in data.get("platforms",[]):
		if not _requirements_met(definition.get("requires","")):
			continue
		var rect: Rect2 = definition.rect
		var platform := PaperPlatform.new()
		platform.name = str(definition.get("id","PaperSurface")).validate_node_name()
		platform.position = rect.position
		platform.width = rect.size.x
		platform.depth = rect.size.y
		platform.one_way = bool(definition.get("one_way",true))
		platform.set_meta("footstep_surface",str(definition.get("footstep_surface","paper" if platform.one_way else "stone")))
		platform.z_index = 1
		surface_root.add_child(platform)
	if is_instance_valid(visuals):
		visuals.queue_redraw()
	for entry in objects:
		if is_instance_valid(entry.node):
			entry.node.queue_redraw()

func requirement_met(flag: String) -> bool:
	return Puzzle.requirement_met(progress,flag)

func _requirements_met(requirements: Variant, combat_bypass: bool = false) -> bool:
	var flags: Array = [requirements] if requirements is String else (requirements if requirements is Array else [])
	for value in flags:
		var flag := str(value)
		if requirement_met(flag):
			continue
		if combat_bypass and environment_preview and flag in COMBAT_FLAGS:
			continue
		return false
	return true

func can_use_exit(exit: Dictionary) -> bool:
	if boss_active: return false
	if current_room==14 and int(exit.get("target",0))==15:
		if is_boss_trial: return requirement_met("trial_compiler_defeated")
		if environment_preview: return requirement_met("preview_compiler_defeated")
	if bool(progress.get("world1_departed",false)) or tour_finished:
		return false
	return _requirements_met(exit.get("requires",[]),bool(exit.get("combat_preview",false)))

func _physics_process(delta: float) -> void:
	var suppress_pause: bool = suppress_pause_frames>0
	suppress_pause_frames = maxi(0,suppress_pause_frames-1)
	if transitioning or fold_active:
		return
	if Input.is_action_just_pressed("switch_language"):
		_on_ui_action("language","en" if hud.language == "ar" else "ar")
	if Input.is_action_just_pressed("pause_game") and not suppress_pause:
		if hud.panel_open:
			_close_panel()
		elif not tour_finished:
			toggle_pause()
	if Input.is_action_just_pressed("stage_map") and not tour_finished:
		toggle_map()
	if Input.is_action_just_pressed("journal") and not tour_finished:
		if hud.panel_open and hud.current_panel == "journal":
			_close_panel()
		else:
			_open_panel("journal")
	if not gameplay_active:
		return
	_check_compiler_entry()
	if Input.is_action_just_pressed("interact"):
		interact.call_deferred()
	for zone in data.get("arrival_flags",[]):
		var rect: Rect2 = zone.rect
		if hero.is_on_floor() and rect.has_point(hero.position) and not requirement_met(str(zone.flag)):
			progress[str(zone.flag)] = true
			_save()
	for hazard in data.get("hazards",[]):
		if requirement_met(str(hazard.get("disabled_by",""))) and not str(hazard.get("disabled_by","")).is_empty():
			continue
		var phase := fposmod(elapsed+float(hazard.get("phase_offset",hazard.get("offset",0.0))),float(hazard.get("period",4.5)))
		var warning := float(hazard.get("telegraph",1.2))
		if phase >= warning and phase < warning+float(hazard.get("active",0.65)):
			var rect: Rect2 = hazard.rect
			if _hero_overlaps(rect):
				hero.hurt(1,rect.get_center().x)
	_resolve_enemy_contact()
	_hud_timer += delta
	if _hud_timer > 0.12:
		_hud_timer = 0
		_update_hud()

func _process(delta: float) -> void:
	if hit_stop_remaining > 0:
		hit_stop_remaining = maxf(0,hit_stop_remaining-delta)
		if hit_stop_remaining <= 0:
			gameplay_active = not paused and not transitioning and not fold_active and not tour_finished and not _respawning
	if gameplay_active:
		_coin_sound_time = maxf(0.0,_coin_sound_time-delta)
		elapsed += delta
		arrival_grace = maxf(0.0, arrival_grace-delta)
		if hero_in_reading_zone():
			_clear_hostile_projectiles()
	_update_compiler_presentation(delta)

func nearest_action() -> Dictionary:
	if boss_active: return {}
	var nearest: Dictionary = {}
	var distance := 112.0
	for entry in objects:
		var definition: Dictionary = entry.definition
		if str(definition.get("kind","")) == "pogo_anchor": continue
		if not _object_visible(definition):
			continue
		var separation := hero.position.distance_to(definition.pos)
		if separation < distance:
			distance = separation
			nearest = {"type":"object","entry":entry,"label":_object_label(definition)}
	for exit in data.get("exits",[]):
		var separation := hero.position.distance_to(exit.pos)
		if separation < distance:
			distance = separation
			nearest = {"type":"exit","exit":exit,"label":_exit_label(exit)}
	return nearest

func _object_visible(definition: Dictionary) -> bool:
	var kind := str(definition.get("kind",""))
	if not _requirements_met(definition.get("visible_requires", [])): return false
	if kind == "dash_pickup": return not combat_state.dash_owned
	if kind == "spell_pickup": return not combat_state.spell_owned and requirement_met("encounter_assignments_cleared")
	if kind == "fitil_pickup": return not combat_state.owns_fitil(str(definition.get("fitil","")))
	if kind == "capacity_pickup": return not combat_state.collected.has(str(definition.id))
	if kind == "currency_drop": return not combat_state.death_drop.is_empty()
	if kind == "weapon" and requirement_met("weapon_owned"):
		return false
	if kind == "book":
		var book := str(definition.get("book_id",definition.get("symbol",""))).to_upper()
		return not progress.get("book_inventory",[]).has(book)
	return true

func _object_label(definition: Dictionary) -> String:
	var arabic: bool = hud.language == "ar"
	if definition.has("label_ar") and arabic:
		return str(definition.label_ar)
	if definition.has("label") and not arabic:
		return str(definition.label)
	var kind := str(definition.get("kind",""))
	if kind in ["note","secret"]:
		var entry: Dictionary = StoryText.note(str(definition.get("text_key",definition.get("id",""))),hud.language)
		var title := str(definition.get("title_ar" if arabic else "title_en",entry.title))
		return ("قراءة · " if arabic else "Read · ")+title
	if definition.has("title_ar" if arabic else "title_en"):
		return str(definition.get("title_ar" if arabic else "title_en"))
	if kind=="book":
		var symbol := str(definition.get("book_id",definition.get("symbol",""))).to_upper()
		var book_names := {"TRIANGLE":["Triangle volume","مجلد المثلث"],"SQUARE":["Square volume","مجلد المربع"],"CIRCLE":["Circle volume","مجلد الدائرة"]}
		var pair: Array = book_names.get(symbol,["Collect the volume","جمع المجلد"])
		return str(pair[1] if arabic else pair[0])
	var names := {
		"dash_pickup":["Learn the lantern dash","تعلم اندفاع الفانوس"],"spell_pickup":["Learn Ink cleave","تعلم شق الحبر"],"fitil_pickup":["Collect the fitil","جمع الفتيل"],"capacity_pickup":["Expand lantern capacity","توسعة سعة الفانوس"],"currency_drop":["Recover lost coins","استعادة العملة المفقودة"],
		"bench":["Rest and save","استراحة وحفظ"],"note":["Read this page","قراءة الصفحة"],"weapon":["Take the Warden's tool","أخذ أداة الحارس"],"dialogue":["Speak to the stranger","التحدث مع الغريب"],"ink_control":["Connect the ink channels","توصيل قنوات الحبر"],"book":["Collect the book","جمع الكتاب"],"process_control":["Arrange the three books","ترتيب الكتب الثلاثة"],"output_control":["Unfold the page","فتح درج الصفحات"],"balance_control":["Balance the bridge","موازنة الجسر"],"shortcut":["Open the return passage","فتح ممر العودة"],"secret_overlay":["Align the transparent pages","مطابقة الصفحات الشفافة"],"secret_pop":["Unfold the paper model","فتح المجسّم الورقي"],"secret":["Examine the hidden page","تفحّص الصفحة المخفية"],"world_exit":["Examine the threshold","تفحّص عتبة العبور"],"combat_socket":["Examine the seal socket","تفحّص مقبس الختم"]}
	var pair: Array = names.get(str(definition.get("kind","")),["Interact","تفاعل"])
	return pair[1] if arabic else pair[0]

func _exit_label(exit: Dictionary) -> String:
	if is_boss_trial: return "العودة إلى المكتبة" if hud.language=="ar" else "Return to the library"
	var target := int(exit.get("target",16))
	if target > 15:
		return "عتبة المحاضرة التالية" if hud.language == "ar" else "The next lecture"
	var destination: Dictionary = _room_layout(target)
	var label := str(destination.get("title_ar",destination.get("arabic_title",""))) if hud.language == "ar" else str(destination.title)
	return label + (" · ممر مغلق" if hud.language == "ar" else " · locked") if not can_use_exit(exit) else label

func interact() -> void:
	if not gameplay_active or transitioning or fold_active:
		return
	var action := nearest_action()
	if action.get("type","") == "object":
		_activate(action.entry)
	elif action.get("type","") == "exit":
		var exit: Dictionary = action.exit
		if is_boss_trial:
			if can_use_exit(exit): _return_from_trial()
			return
		if int(exit.get("target",16)) > 15:
			_request_departure()
		elif can_use_exit(exit):
			_begin_transition(exit)
		else:
			_tip("أكمل آلية المنطقة لفتح هذا الطريق.","Complete this area's mechanism to open this route.")

func _activate(entry: Dictionary) -> void:
	var definition: Dictionary = entry.get("definition",entry)
	var kind := str(definition.get("kind",""))
	if _activate_combat_pickup(definition): return
	if kind == "world_exit":
		_request_departure()
		return
	var effective := definition.duplicate(true)
	# Traversal of the empty guardian court is allowed only in environment preview.
	# Resting there still cannot award a seal or victory.
	if environment_preview and kind == "bench":
		var required: Variant = effective.get("requires",[])
		var kept: Array = []
		for flag in ([required] if required is String else required):
			if str(flag) not in COMBAT_FLAGS:
				kept.append(flag)
		effective.requires = kept
	var result: Dictionary = Puzzle.act(progress,effective)
	if bool(result.get("checkpoint",false)):
		play_sfx("bench")
		checkpoint = {"room":current_room,"position":[definition.pos.x+64.0,definition.pos.y]}
		hero.hp = hero.max_hp
		hero.energy = 99.0
		_save()
		at_bench = true
		_panel_definition = effective
		_open_panel("fitils")
		return
	_panel_definition = effective
	_handle_result(result)

func _handle_result(result: Dictionary) -> void:
	var feedback := str(result.get("lantern_feedback",""))
	if feedback == "retry" or (not bool(result.get("ok",true)) and str(result.get("message_key","")) not in ["locked","unknown_action"]):
		play_sfx("puzzle_error")
	elif bool(result.get("changed",false)) and (not str(result.get("committed_flag","")).is_empty() or int(result.get("currency_reward",0))>0):
		play_sfx("puzzle_success")
	var message := str(result.get("message_ar",result.get("message_key",""))) if hud.language == "ar" else str(result.get("message_en",result.get("message_key","")))
	if not message.is_empty():
		hud.show_toast(message)
	hero.has_blade = bool(progress.get("weapon_owned",false))
	if bool(result.get("changed",false)):
		var reward := maxi(0,int(result.get("currency_reward",0)))
		if reward > 0:
			var source_id := str(result.get("discovery_flag",_panel_definition.get("id","discovery")))
			_issue_coin_reward("puzzle:"+source_id,hero.position,reward)
		var completed := str(result.get("committed_flag",""))
		var fold_rewards := {"ink_route_solved":9,"output_open":9,"balance_bridge_locked":12,"secret_S03_open":6,"secret_S06_open":6}
		if fold_rewards.has(completed):
			reward_completed_task("fold:"+completed,completed,int(fold_rewards[completed]),hero.position)
		if str(_panel_definition.get("kind",""))=="shortcut":
			var completed_flag := str(_panel_definition.get("flag",""))
			reward_completed_task("passage:"+completed_flag,completed_flag,5,_panel_definition.get("pos",hero.position))
		_save()
		_refresh_objects()
	if result.has("commit_flag") and bool(result.get("ok",false)):
		_start_fold(str(result.commit_flag))
		return
	if result.has("needs_panel"):
		var kind := str(result.needs_panel)
		if hud.panel_open and hud.current_panel == kind:
			hud.refresh_panel(_panel_context())
		else:
			_open_panel(kind)
	elif bool(result.get("ok",false)) and hud.panel_open:
		_close_panel()
	_update_hud()

func _refresh_objects() -> void:
	for entry in objects:
		entry.node.visible = _object_visible(entry.definition)
		entry.node.queue_redraw()
	if is_instance_valid(visuals):
		visuals.queue_redraw()

func _panel_context() -> Dictionary:
	var notes: Array = []
	if requirement_met("black_flame_warning_seen"):
		notes.append({"id":"black_flame_warning","text_key":"black_flame_warning"})
	var catalog: Array = []
	for room in _all_layouts():
		for source in room.get("objects",[]):
			if str(source.get("kind","")) not in ["note","secret"]: continue
			var definition: Dictionary = source.duplicate(true)
			definition.room_id = int(room.id)
			definition.room_title = str(room.get("title",""))
			definition.room_title_ar = str(room.get("title_ar",room.get("arabic_title","")))
			catalog.append(definition)
			if progress.get("notes",[]).has(str(definition.id)):
				notes.append(definition)
	for definition in Puzzle.extra_notes():
		var exists := false
		for entry in catalog:
			if str(entry.id)==str(definition.id): exists = true
		if not exists: catalog.append(definition)
		if progress.get("notes",[]).has(str(definition.id)) and not notes.any(func(entry): return str(entry.id)==str(definition.id)):
			notes.append(definition)
	return {"progress":progress,"state":progress,"definition":_panel_definition,"room":data,"rooms":_all_layouts(),"notes":notes,"note_catalog":catalog,"read_ids":progress.get("notes",[]),"is_boss_trial":is_boss_trial,"boss_active":boss_active,"boss_victory":_compiler_won(),"boss_music_muted":boss_music_muted,"environment_preview":environment_preview,"preview_departed":tour_finished,"combat":combat_hud_context(),"bindings":controls.rows(),"awaiting_action":awaiting_action}

func _open_panel(kind: String) -> void:
	if kind in ["journal","note"]: play_sfx("journal_open")
	panel_closing = false
	if is_instance_valid(arrival_title): arrival_title.dismiss()
	_set_paused(true)
	hud.open_panel(kind,_panel_context())

func _close_panel() -> void:
	if tour_finished:
		hud.open_panel("completion",_panel_context())
		return
	if panel_closing: return
	panel_closing = true
	if hud.current_panel in ["journal","note"]: play_sfx("journal_close")
	if not hud.panel_open:
		_panel_close_finished()
		return
	hud.close_panel()
	if not hud.has_signal("panel_closed"):
		_panel_close_finished()

func _panel_close_finished() -> void:
	if not panel_closing: return
	panel_closing = false
	_panel_definition = {}
	at_bench = false
	awaiting_action = ""
	if not transitioning and not fold_active and not tour_finished:
		_set_paused(false)

func _on_ui_action(action: String, value: Variant = null) -> void:
	if panel_closing: return
	match action:
		"boss_trial": _enter_boss_trial()
		"trial_return": _return_from_trial()
		"trial_retry": _restart_boss_trial()
		"boss_music_toggle":
			boss_music_muted = not boss_music_muted
			if is_instance_valid(boss_music): boss_music.set_muted(boss_music_muted)
			_save_settings()
			if hud.panel_open: hud.refresh_panel(_panel_context())
		"fitils":
			if _physically_at_bench():
				at_bench = true
				_open_panel("fitils")
		"controls": _open_panel("controls")
		"equip_fitil", "unequip_fitil":
			var permitted: bool = at_bench and hud.panel_open and hud.current_panel=="fitils" and _physically_at_bench()
			var changed: bool = combat_state.equip(str(value),permitted) if action=="equip_fitil" else combat_state.unequip(str(value),permitted)
			if changed: _save()
			if hud.panel_open: hud.refresh_panel(_panel_context())
			_update_hud()
		"rebind":
			if hud.panel_open and hud.current_panel=="controls" and str(value) in Controls.ACTIONS:
				awaiting_action = str(value)
				hud.refresh_panel(_panel_context())
		"reset_bindings":
			controls.reset()
			awaiting_action = ""
			hud.refresh_panel(_panel_context())
		"map": toggle_map()
		"journal": _open_panel("journal")
		"pause": toggle_pause()
		"resume", "close_panel": _close_panel()
		"restart": restart_stage()
		"journal_cursor":
			_save()
			play_sfx("journal_page")
		"language":
			hud.set_language("en" if str(value) == "en" else "ar")
			_save_settings()
			if hud.panel_open:
				hud.refresh_panel(_panel_context())
			_update_hud()
		"puzzle_choice":
			if not _panel_definition.is_empty() and value is Dictionary:
				_handle_result(Puzzle.act(progress,_panel_definition,value))
		"puzzle_confirm":
			if not _panel_definition.is_empty():
				_handle_result(Puzzle.act(progress,_panel_definition,{"action":"confirm"}))
		"depart_confirm": _confirm_departure()

func _fold_rectangles(flag: String) -> Array[Rect2]:
	var zones: Array[Rect2] = []
	for platform in data.get("platforms",[]):
		if str(platform.get("requires","")) == flag:
			zones.append(platform.rect)
	for zone in data.get("fold_zones",[]):
		if str(zone.get("flag","")) == flag:
			zones.append(zone.rect)
	return zones

func _actor_clear_for_fold(flag: String) -> bool:
	var body := Rect2(hero.position-Vector2(32,133),Vector2(64,133))
	for rect in _fold_rectangles(flag):
		if rect.grow(14).intersects(body):
			return false
	return true

func _start_fold(flag: String) -> void:
	if fold_active or not _actor_clear_for_fold(flag):
		_tip("ابتعد عن مجال حركة الصفحة ثم حاول.","Step clear of the moving page and try again.")
		return
	panel_closing = false
	hud.close_panel(true)
	_set_paused(true)
	fold_active = true
	fold_flag = flag
	fold_progress = 0.0
	_fold_preview = Node2D.new()
	_fold_preview.z_index = 2
	active_room.add_child(_fold_preview)
	for rect in _fold_rectangles(flag):
		var page := Polygon2D.new()
		page.position = rect.position
		page.polygon = PackedVector2Array([Vector2.ZERO,Vector2(rect.size.x,0),Vector2(rect.size.x,rect.size.y),Vector2(0,rect.size.y)])
		page.color = Color("cdbc93")
		page.antialiased = true
		page.rotation = -PI*0.47
		_fold_preview.add_child(page)
		create_tween().tween_property(page,"rotation",0.0,1.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var tween := create_tween()
	tween.tween_property(self,"fold_progress",1.0,1.5)
	tween.tween_callback(_complete_fold)

func _complete_fold() -> void:
	# Geometry remains disabled throughout motion. Commit and collision replacement
	# run together after the final shape has settled; no mid-motion state is saved.
	var result: Dictionary = Puzzle.commit_fold(progress,fold_flag)
	if is_instance_valid(_fold_preview):
		_fold_preview.queue_free()
	fold_active = false
	fold_flag = ""
	_panel_definition = {}
	_refresh_geometry()
	_refresh_objects()
	_save()
	_set_paused(false)
	_handle_result(result)
	play_sfx("puzzle_success")

func _begin_transition(exit: Dictionary) -> void:
	if transitioning or not can_use_exit(exit):
		return
	play_sfx("room_transition")
	transitioning = true
	_set_paused(true)
	if is_instance_valid(fade):
		await create_tween().tween_property(fade,"color:a",1.0,transition_seconds).finished
	_load_room(int(exit.target),str(exit.get("spawn",exit.get("target_spawn","left"))))
	_save()
	if is_instance_valid(fade):
		await create_tween().tween_property(fade,"color:a",0.0,transition_seconds).finished
	transitioning = false
	_set_paused(false)

func _request_departure() -> void:
	if current_room != 15:
		return
	if not environment_preview and not requirement_met("boss_defeated"):
		_tip("العبور يتطلب الانتصار على د. كومبايلر.","Crossing requires defeating Dr. Compiler.")
		return
	_panel_definition = {"kind":"world_exit","id":"world_threshold"}
	_open_panel("world_exit")

func _confirm_departure() -> void:
	if current_room != 15 or not hud.panel_open or hud.current_panel != "world_exit":
		return
	if environment_preview:
		progress.preview_departed = true
		_save()
		_finish_preview()
		return
	if not requirement_met("boss_defeated"):
		return
	# The second world has not been authored. A real departure cannot strand a
	# saved game in an absent scene. The environment preview has its own ending.
	if next_world_scene.is_empty() or not ResourceLoader.exists(next_world_scene):
		_tip("البعد التالي يأتي في إصدار لاحق؛ يمكنك متابعة استكشاف المكتبة.","The next dimension comes in a later build; you can keep exploring the library.")
		return
	var destination: PackedScene = load(next_world_scene)
	if destination == null:
		return
	progress.world1_departed = true
	_save()
	get_tree().change_scene_to_packed(destination)

func _finish_preview() -> void:
	tour_finished = true
	_set_paused(true)
	hud.open_panel("completion",_panel_context())

func toggle_pause() -> void:
	if transitioning or fold_active or tour_finished:
		return
	if hud.panel_open:
		_close_panel()
	else:
		_open_panel("pause")

func toggle_map() -> void:
	if transitioning or fold_active or tour_finished:
		return
	if hud.panel_open and hud.current_panel == "map":
		_close_panel()
	else:
		_open_panel("map")

func _set_paused(value: bool) -> void:
	if value: _clear_hostile_projectiles()
	if is_instance_valid(boss_music): boss_music.set_paused(value)
	paused = value
	gameplay_active = not value and not transitioning and not fold_active and not tour_finished and hit_stop_remaining<=0 and not _respawning
	if is_instance_valid(camera):
		camera.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	if is_instance_valid(active_room):
		active_room.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	if is_instance_valid(hero):
		hero.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
		if value:
			hero.lantern_sprite.pause()
		else:
			hero.lantern_sprite.play()
	# UI and stage tweens remain active. Hazard time advances only during play.

func _update_hud() -> void:
	if not is_instance_valid(hud) or data.is_empty():
		return
	var action := nearest_action() if gameplay_active else {}
	hud.update_status(data,progress,str(action.get("label","")),[])
	hud.update_combat_status(combat_hud_context())

func save_path() -> String:
	if is_boss_trial: return TRIAL_SAVE
	return PREVIEW_SAVE_FILE if environment_preview else SAVE_FILE

func _save() -> void:
	var record := {"version":18,"environment_preview":environment_preview,"progress":progress,"checkpoint":checkpoint,"language":hud.language,"combat":combat_state.serialize(),"energy":hero.energy,"journal_cursor":hud.journal_cursor}
	var path := save_path()
	var temp := path+".tmp"
	var file := FileAccess.open(temp,FileAccess.WRITE)
	if file == null:
		_tip("تعذر حفظ التقدم.","Progress could not be saved.")
		return
	file.store_string(JSON.stringify(record,"\t"))
	file.flush()
	file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(path)) != OK:
		_tip("تعذر تثبيت ملف الحفظ.","The save file could not be committed.")

func _restore_save() -> void:
	if not FileAccess.file_exists(save_path()):
		return
	var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path()))
	if not record is Dictionary or int(record.get("version",0)) != 18 or bool(record.get("environment_preview",false)) != environment_preview:
		return
	combat_state.restore(record.get("combat",{}) if record.get("combat",{}) is Dictionary else {})
	hero.energy = clampf(float(record.get("energy",99.0)),0,99)
	var saved: Variant = record.get("progress",{})
	if saved is Dictionary:
		progress.merge(saved,true)
	# M22 tour completion must not hide the newly authored real boss encounter.
	if environment_preview and not is_boss_trial and not bool(progress.get("preview_compiler_defeated",false)):
		progress.preview_departed = false
	CurrencyLedger.sanitize(progress)
	var visited: Array[int] = []
	for value in progress.get("visited",[]):
		var id := int(value)
		if id >= 1 and id <= 15 and not visited.has(id):
			visited.append(id)
	progress.visited = visited
	var point: Variant = record.get("checkpoint",{})
	if point is Dictionary and int(point.get("room",0)) >= 1 and int(point.get("room",0)) <= 15:
		var position_value: Variant = point.get("position",[])
		if position_value is Array and position_value.size() == 2:
			var room: Dictionary = _room_layout(int(point.room))
			var candidate := Vector2(float(position_value[0]),float(position_value[1]))
			if Rect2(Vector2.ZERO,room.size).has_point(candidate):
				checkpoint = {"room":int(point.room),"position":[candidate.x,candidate.y]}
	if not environment_preview and int(checkpoint.room) == 13 and not (requirement_met("guard_clear") and requirement_met("compiler_seal_owned")):
		checkpoint = {"room":10,"position":[310.0,1260.0]}
	hud.language = "en" if str(record.get("language",hud.language)) == "en" else "ar"
	hud.restore_journal_cursor(record.get("journal_cursor",{}) if record.get("journal_cursor",{}) is Dictionary else {})

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("interface","language",hud.language)
	config.set_value("audio","boss_music_muted",boss_music_muted)
	config.save(SETTINGS_FILE)

func _restore_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		hud.language = "en" if str(config.get_value("interface","language","ar")) == "en" else "ar"
		boss_music_muted = bool(config.get_value("audio","boss_music_muted",false))

func restart_stage() -> void:
	if FileAccess.file_exists(save_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path()))
	get_tree().reload_current_scene()

func player_fell() -> void:
	if _respawning or transitioning or tour_finished: return
	if hero.hp>1:
		hero.hp -= 1
		hero.reset_combat_motion()
		hero.position = hero.last_safe_position
		hero.invulnerable = 1.2
		combat_changed()
	else:
		hero.hp = 0
		on_player_death()

func on_player_death() -> void:
	if _respawning or transitioning or tour_finished: return
	play_sfx("hero_death")
	_respawning = true
	_clear_compiler_attacks()
	if is_instance_valid(boss_arena): boss_arena.set_locked(false)
	if is_instance_valid(boss_music): boss_music.stop_fight(false)
	_clear_hostile_projectiles()
	combat_state.drop_on_death(current_room,hero.last_safe_position)
	hero.energy = 0
	_save()
	gameplay_active = false
	hero._update_animation()
	_respawn.call_deferred()

func _respawn() -> void:
	await get_tree().create_timer(0.38).timeout
	_set_paused(true)
	_load_room(int(checkpoint.room),"left",Vector2(float(checkpoint.position[0]),float(checkpoint.position[1])))
	hero.hp = hero.max_hp
	hero.invulnerable = 1.2
	_respawning = false
	_set_paused(false)
	_update_hud()

func hero_strike(direction: String, facing: int) -> void:
	if not gameplay_active or hero.active_strike_time<=0: return
	var rect: Rect2 = hero.strike_rect(direction,facing)
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_dead: continue
		var id := enemy.get_instance_id()
		if hero.hit_targets.has(id): continue
		if enemy.clash_rect().has_area() and rect.intersects(enemy.clash_rect()) and enemy.on_clash():
			hero.hit_targets[id] = true
			play_sfx("parry_light")
			emit_burst(enemy.position+Vector2(0,-30),Color("f8e4b6"),14)
			if direction=="down": hero.pogo()
			_hit_stop(0.035)
			continue
		if rect.intersects(enemy.get_hitbox()) and enemy.take_hit(1,hero.position.x,"melee"):
			hero.hit_targets[id] = true
			hero.gain_energy(combat_state.energy_per_hit())
			if direction=="down": hero.pogo()
			_hit_stop(0.055 if enemy.is_dead else 0.035)
			combat_changed()
	if direction=="down":
		for entry in objects:
			if str(entry.definition.get("kind",""))!="pogo_anchor": continue
			var node: Node2D = entry.node
			var id := node.get_instance_id()
			if not hero.hit_targets.has(id) and rect.intersects(node.get_hitbox()):
				hero.hit_targets[id] = true
				hero.pogo()
				play_sfx("parry_light")
				emit_burst(node.position-Vector2(0,20),Color("f6d1a0"),6)

func cast_code_slash(point: Vector2, direction: int) -> void:
	var projectile := Cleave.new()
	active_room.add_child(projectile)
	projectile.setup(self,point,direction)
	play_sfx("spell")
	combat_changed()

func on_parry(_from_x: float) -> void: pass
func on_perfect_dodge() -> void: pass

func emit_burst(point: Vector2, color: Color, amount: int) -> void:
	if not is_instance_valid(active_room): return
	if color in [Color("82e9f8"),Color("70d9ff"),Color("8499a6"),Color("b9f3e9")]: color = Color("f4c38a")
	var particles := CPUParticles2D.new()
	particles.position = point
	particles.amount = clampi(amount,3,18)
	particles.lifetime = 0.24
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector2(0,-1)
	particles.spread = 145
	particles.gravity = Vector2(0,200)
	particles.initial_velocity_min = 35
	particles.initial_velocity_max = 100
	particles.scale_amount_min = 1.3
	particles.scale_amount_max = 2.8
	particles.color = color
	particles.z_index = 12
	active_room.add_child(particles)
	particles.finished.connect(particles.queue_free)
	particles.emitting = true

func _hit_stop(seconds: float) -> void:
	hit_stop_remaining = maxf(hit_stop_remaining,seconds)
	gameplay_active = false

func combat_changed() -> void:
	hero.credits = combat_state.wallet
	_update_hud()

func _resolve_enemy_contact() -> void:
	if not gameplay_active: return
	# Player resolves active sword collisions first, regardless of scene order.
	if hero.active_strike_time>0: hero_strike(hero.attack_direction,hero.facing)
	if not gameplay_active: return
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead and enemy.danger_rect().has_area() and _hero_overlaps(enemy.danger_rect()):
			hero.hurt(int(enemy.get_contact_damage()) if enemy.has_method("get_contact_damage") else 1,enemy.position.x)

func _hero_overlaps(rect: Rect2) -> bool:
	for box in hero.get_hurtboxes():
		if rect.intersects(box): return true
	return false

func hero_in_reading_zone() -> bool:
	if not is_instance_valid(hero): return true
	for entry in objects:
		var definition: Dictionary = entry.definition
		if str(definition.get("kind","")) in protected_kinds and _object_visible(definition):
			if hero.position.distance_to(definition.pos) < float(definition.get("safe_radius",112.0)):
				return true
	return false

func enemy_can_attack(actor: Node2D, danger_zone: Rect2 = Rect2()) -> bool:
	if actor==registered_boss:
		return boss_active and gameplay_active and not transitioning and not _respawning
	if not gameplay_active or transitioning or arrival_grace > 0.0 or hero_in_reading_zone(): return false
	if not is_instance_valid(actor) or not is_instance_valid(hero): return false
	var screen_point: Vector2 = actor.get_global_transform_with_canvas() * Vector2.ZERO
	if not get_viewport_rect().grow(-40.0).has_point(screen_point): return false
	var definition: Dictionary = actor.get_meta("encounter_definition",{})
	var zone: Rect2 = definition.get("zone",danger_zone)
	if zone.has_area() and not zone.has_point(hero.position): return false
	for protected in definition.get("protected",[]):
		if (protected as Rect2).has_point(hero.position): return false
	return true

func _clear_hostile_projectiles() -> void:
	if not is_inside_tree(): return
	for projectile in get_tree().get_nodes_in_group("m22_hostile_projectiles"):
		if is_instance_valid(projectile) and is_ancestor_of(projectile):
			if projectile.has_method("consume"): projectile.consume()
			else: projectile.queue_free()

func _spawn_room_enemy() -> void:
	if current_room==14: _spawn_compiler()
	for definition in data.get("encounters",[]):
		var clear_flag := str(definition.get("clear_flag",""))
		if bool(definition.get("persist_defeat",false)) and not clear_flag.is_empty() and requirement_met(clear_flag): continue
		var actor: Node2D
		var kind := str(definition.get("type",""))
		match kind:
			"popup_wraith": actor = PopupWraith.new()
			"syntax_turret": actor = SyntaxTurret.new()
			"glitch_larva": actor = Larva.new()
			_: continue
		actor.name = str(definition.get("id","Encounter")).validate_node_name()
		actor.set_meta("encounter_definition",definition)
		active_room.add_child(actor)
		var spawn: Vector2 = definition.get("spawn",Vector2.ZERO)
		match kind:
			"popup_wraith": actor.setup(self,spawn,definition.get("patrol",Vector2(spawn.x-110,spawn.x+110)),float(definition.get("floor_y",spawn.y+180)),definition.get("zone",Rect2()))
			"syntax_turret":
				actor.setup(self,spawn,definition.get("patrol",Vector2(spawn.x-100,spawn.x+100)))
				var safe_zones: Array[Rect2] = []
				for rect in definition.get("protected",[]): safe_zones.append(rect)
				actor.configure_encounter(definition.get("zone",Rect2()),safe_zones)
			_: actor.setup(self,spawn,definition.get("patrol",Vector2(spawn.x-100,spawn.x+100)))
		enemies.append(actor)
		if not clear_flag.is_empty(): register_encounter(clear_flag,[actor])

func _spawn_death_drop() -> void:
	var drop: Dictionary = combat_state.death_drop
	if drop.is_empty() or int(drop.get("room",0))!=current_room: return
	var at: Array = drop.get("position",[0,0])
	var definition := {"id":"death_drop","kind":"currency_drop","pos":Vector2(float(at[0]),float(at[1])),"amount":int(drop.get("amount",0))}
	var node := CombatPickup.new()
	active_room.add_child(node)
	node.setup(self,definition)
	objects.append({"definition":definition,"node":node})

func _activate_combat_pickup(definition: Dictionary) -> bool:
	var kind := str(definition.get("kind",""))
	if kind not in ["dash_pickup","spell_pickup","fitil_pickup","capacity_pickup","currency_drop"]: return false
	if not _object_visible(definition): return true
	match kind:
		"dash_pickup": combat_state.dash_owned = true
		"spell_pickup": combat_state.spell_owned = true
		"fitil_pickup": combat_state.acquire(str(definition.get("fitil","")))
		"capacity_pickup": combat_state.increase_capacity(str(definition.id))
		"currency_drop": combat_state.recover_drop()
	hero.has_dash = combat_state.dash_owned
	hero.has_code_slash = combat_state.spell_owned
	_save()
	_refresh_objects()
	play_sfx("pickup")
	_tip("تمت الإضافة. جهّز الفتائل عند المقعد.","Collected. Fitils can be equipped at a bench.")
	combat_changed()
	return true

func _physically_at_bench() -> bool:
	for entry in objects:
		if str(entry.definition.get("kind",""))=="bench" and hero.position.distance_to(entry.definition.pos)<118 and _requirements_met(entry.definition.get("requires",[]),environment_preview): return true
	return false

func combat_hud_context() -> Dictionary:
	return {"hp":hero.hp if is_instance_valid(hero) else 6,"max_hp":6,"energy":hero.energy if is_instance_valid(hero) else 99,"max_energy":99,"wallet":combat_state.wallet,"spell_owned":combat_state.spell_owned,"dash_owned":combat_state.dash_owned,"equipped":combat_state.equipped,"owned":combat_state.owned,"capacity":combat_state.capacity,"used_capacity":combat_state.used_capacity(),"catalog":CombatState.FITILS,"at_bench":at_bench and _physically_at_bench(),"healing":hero.healing if is_instance_valid(hero) else false,"heal_progress":1.0-hero.heal_time/(1.141*combat_state.focus_duration_multiplier()) if is_instance_valid(hero) and hero.healing else 0.0}

func control_hint(action: String) -> String:
	return controls.hint(action)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion: controls.gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton: controls.gamepad = false
	if awaiting_action.is_empty(): return
	if event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:
		awaiting_action = ""
	elif (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed):
		if not controls.rebind(awaiting_action,event): _tip("هذا الزر مستخدم لحركة أخرى.","That button is already used by another action.")
		awaiting_action = ""
	else: return
	get_viewport().set_input_as_handled()
	suppress_pause_frames = 2
	hud.refresh_panel(_panel_context())

func show_tip(message: String) -> void:
	if is_instance_valid(hud):
		hud.show_toast(message)

func _tip(arabic: String, english: String) -> void:
	show_tip(arabic if hud.language == "ar" else english)

func play_sfx(cue: String) -> void:
	if is_instance_valid(soundscape):
		soundscape.play_event(cue)
		return
	var boss_path := "res://assets/audio/m23/"+cue+".wav"
	var path := boss_path if ResourceLoader.exists(boss_path) else "res://assets/audio/"+cue+".wav"
	if not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.volume_db = -8 if cue.begins_with("compiler_") else -15 if boss_active else -25
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func register_encounter(id: String, actors: Array) -> void:
	var members: Array[int] = []
	for actor in actors:
		if is_instance_valid(actor):
			members.append(actor.get_instance_id())
	if not members.is_empty():
		encounter_actors[id] = {"members":members,"defeated":[]}

func on_enemy_defeated(actor: Node2D) -> void:
	if actor==registered_boss:
		on_compiler_defeated(actor)
		return
	if not is_instance_valid(actor) or not bool(actor.get("is_dead")):
		return
	var identity := actor.get_instance_id()
	if not _rewarded_enemies.has(identity):
		_rewarded_enemies[identity] = true
		var definition: Dictionary = actor.get_meta("encounter_definition",{})
		var source_id := str(definition.get("clear_flag",definition.get("id",actor.name)))
		_issue_coin_reward("enemy:"+source_id,actor.global_position,12)
	for id in encounter_actors:
		var record: Dictionary = encounter_actors[id]
		if not record.members.has(identity):
			continue
		if not record.defeated.has(identity):
			record.defeated.append(identity)
		if record.defeated.size() == record.members.size():
			progress[str(id)] = true
	_refresh_objects()
	_save()

func _coin_anchor(point: Vector2) -> Vector2:
	# Keep rewards on an actual reachable surface even when a wraith dies aloft.
	var origin := Vector2(clampf(point.x,40.0,float(data.size.x)-40),maxf(0.0,point.y-20.0))
	var query := PhysicsRayQueryParameters2D.create(origin,Vector2(origin.x,float(data.size.y)+160.0),1)
	var contact := get_world_2d().direct_space_state.intersect_ray(query)
	if not contact.is_empty():
		var ground: Vector2 = contact.position
		for platform in data.get("platforms",[]):
			var rect: Rect2 = platform.rect
			if _requirements_met(platform.get("requires","")) and absf(rect.position.y-ground.y)<2 and ground.x>=rect.position.x and ground.x<=rect.end.x:
				ground.x = clampf(ground.x,rect.position.x+minf(38,rect.size.x*.3),rect.end.x-minf(38,rect.size.x*.3))
				break
		return ground
	return hero.last_safe_position

func _spawn_coin_definition(definition: Dictionary) -> void:
	for existing in get_tree().get_nodes_in_group("m22_coins"):
		if not is_instance_valid(existing) or not is_ancestor_of(existing): continue
		if str(existing.get_meta("reward_id",""))==str(definition.reward_id) and int(existing.get_meta("coin_index",-1))==int(definition.coin_index): return
	var coin := Coin.new()
	coin.set_meta("reward_id",str(definition.reward_id))
	coin.set_meta("coin_index",int(definition.coin_index))
	active_room.add_child(coin)
	coin.setup(self,definition)

func _spawn_room_coins() -> void:
	for definition in CurrencyLedger.room_pending(progress,current_room):
		_spawn_coin_definition(definition)

func _issue_coin_reward(identity: String, point: Vector2, amount: int) -> void:
	if amount<=0 or not is_instance_valid(active_room): return
	var anchor := _coin_anchor(point)
	for definition in CurrencyLedger.create_reward(progress,identity,current_room,anchor,amount):
		_spawn_coin_definition(definition)
	_save()

func reward_completed_task(identity: String, completed_flag: String, amount: int, point: Vector2) -> bool:
	# Shared path for completed puzzle/passage tasks and later authored quests.
	if completed_flag.is_empty() or not requirement_met(completed_flag): return false
	_issue_coin_reward("task:"+identity,point,amount)
	return true

func collect_world_coin(definition: Dictionary) -> bool:
	if not gameplay_active or int(definition.get("room",0))!=current_room: return false
	CurrencyLedger.sanitize(progress)
	var receipt: Dictionary = progress.get("currency_rewards",{}).get(str(definition.get("reward_id","")),{})
	var index := int(definition.get("coin_index",-1))
	var coins: Array = receipt.get("coins",[])
	if int(receipt.get("room",0))!=current_room or index<0 or index>=coins.size(): return false
	var expected_amount := int(coins[index].get("amount",0))
	if expected_amount<=0 or combat_state.wallet>CombatState.MAX_WALLET-expected_amount: return false
	var amount: int = CurrencyLedger.claim(progress,str(definition.get("reward_id","")),index)
	if amount<=0: return false
	combat_state.wallet += amount
	combat_changed()
	if _coin_sound_time<=0:
		play_sfx("coin")
		_coin_sound_time = 0.08
	_save()
	return true

func on_boss_defeated() -> void:
	if is_instance_valid(registered_boss): on_compiler_defeated(registered_boss)

func _exit_tree() -> void:
	if is_instance_valid(soundscape): soundscape.stop_all()
	if is_instance_valid(boss_music): boss_music.stop_all()
	# Release active audio voices before scene reloads, including a reload that
	# interrupts a fold. Playback must not keep the old world's streams alive.
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null


func _setup_trial_loadout() -> void:
	checkpoint = {"room":14,"position":[1040.0,1440.0]}
	progress.weapon_owned = true
	combat_state.dash_owned = true
	combat_state.spell_owned = true
	combat_state.capacity = 4
	for id in ["wick","reach","focus"]: combat_state.acquire(id)
	combat_state.equip("wick",true)
	hero.hp = 6
	hero.energy = 99.0

func _read_trial_return() -> void:
	if not FileAccess.file_exists(TRIAL_RETURN): return
	var stored: Variant = JSON.parse_string(FileAccess.get_file_as_string(TRIAL_RETURN))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TRIAL_RETURN))
	if not stored is Dictionary: return
	var room := int(stored.get("room",0))
	var point: Variant = stored.get("position",[])
	if room<1 or room>15 or not point is Array or point.size()!=2: return
	var at := Vector2(float(point[0]),float(point[1]))
	if not Rect2(Vector2.ZERO,_room_layout(room).size).has_point(at): return
	_return_record = stored

func _enter_boss_trial() -> void:
	if is_boss_trial:
		_restart_boss_trial()
		return
	_save()
	var point: Vector2 = hero.last_safe_position
	var record := {"room":current_room,"position":[point.x,point.y],"hp":hero.hp,"energy":hero.energy}
	var handle := FileAccess.open(TRIAL_RETURN,FileAccess.WRITE)
	if handle==null: return
	handle.store_string(JSON.stringify(record))
	handle.close()
	get_tree().change_scene_to_file(TRIAL_SCENE)

func _return_from_trial() -> void:
	if not is_boss_trial: return
	get_tree().change_scene_to_file(LIBRARY_SCENE)

func _restart_boss_trial() -> void:
	if not is_boss_trial: return
	get_tree().change_scene_to_file(TRIAL_SCENE)

func _compiler_flag() -> String:
	return "trial_compiler_defeated" if is_boss_trial else "preview_compiler_defeated" if environment_preview else "boss_defeated"

func _compiler_won() -> bool:
	return bool(progress.get(_compiler_flag(),false))

func _reset_compiler_room() -> void:
	boss_active = false
	boss_trauma = 0.0
	_clear_compiler_attacks()
	if is_instance_valid(_boss_camera_tween): _boss_camera_tween.kill()
	if is_instance_valid(camera):
		camera.offset = Vector2.ZERO
		camera.zoom = _camera_zoom
		camera.target = hero
	if is_instance_valid(boss_music): boss_music.stop_fight(false)
	boss_arena = null

func _spawn_compiler() -> void:
	boss_arena = CompilerArena.new()
	active_room.add_child(boss_arena)
	boss_arena.setup(self,data)
	if _compiler_won():
		boss_arena.set_defeated(true)
		return
	var actor := Compiler.new()
	actor.name = "DrCompiler"
	active_room.add_child(actor)
	actor.setup(self,boss_arena.boss_spawn,boss_arena.get_arena_rect())
	registered_boss = actor
	enemies.append(actor)
	boss_last_phase = 1

func _check_compiler_entry() -> void:
	if current_room!=14 or boss_active or _compiler_won() or _respawning or not is_instance_valid(registered_boss): return
	if hero.position.x<float(boss_arena.intro_threshold_x) or hero.position.x>boss_arena.get_arena_rect().end.x: return
	if not is_boss_trial and not environment_preview and not _requirements_met(["guard_clear","compiler_seal_owned","seal_registered"]):
		return
	boss_active = true
	boss_attempts += 1
	boss_arena.set_locked(true)
	camera.target = null
	if is_instance_valid(_boss_camera_tween): _boss_camera_tween.kill()
	_boss_camera_tween = create_tween().set_parallel(true)
	_boss_camera_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_boss_camera_tween.tween_property(camera,"zoom",Vector2(.78,.78),.85)
	_boss_camera_tween.tween_property(camera,"position",Vector2(2070,1150),.85)
	registered_boss.start_encounter()
	if is_instance_valid(arrival_title): arrival_title.dismiss()
	if is_instance_valid(boss_music): boss_music.set_phase(1)
	if hud.has_method("show_boss_intro"): hud.show_boss_intro()

func _clear_compiler_attacks() -> void:
	if not is_inside_tree(): return
	for attack in get_tree().get_nodes_in_group("m23_boss_attacks"):
		if is_instance_valid(attack) and is_ancestor_of(attack): attack.queue_free()

func _update_compiler_presentation(delta: float) -> void:
	if not is_instance_valid(hud): return
	var actor: Node2D = registered_boss if is_instance_valid(registered_boss) else null
	var visible_boss := actor!=null and boss_active
	if visible_boss and int(actor.phase)!=boss_last_phase:
		boss_last_phase = int(actor.phase)
		if is_instance_valid(boss_arena): boss_arena.pulse_phase(boss_last_phase)
		if is_instance_valid(boss_music): boss_music.set_phase(boss_last_phase)
		boss_trauma = .65
	if hud.has_method("update_boss_status"):
		hud.update_boss_status({"visible":visible_boss,"name_ar":"د. كومبايلر","name_en":"Dr. Compiler","hp":int(actor.hp) if actor else 0,"max_hp":48,"phase":int(actor.phase) if actor else 1,"state":str(actor.state) if actor else "dormant","warning_ar":str(actor.warning_ar) if actor else "","warning_en":str(actor.warning_en) if actor else "","warning_progress":float(actor.warning_progress) if actor else 0.0})
	if is_instance_valid(boss_music):
		boss_music.set_warning(visible_boss and not str(actor.warning_ar).is_empty())
		boss_music.set_cinematic(visible_boss and str(actor.state) in ["intro","phase_transition"])
	if boss_active and not paused:
		boss_trauma = maxf(0.0,boss_trauma-delta*1.8)
		camera.offset = Vector2(sin(elapsed*73),sin(elapsed*91))*boss_trauma*3
	elif is_instance_valid(camera): camera.offset = Vector2.ZERO

func on_compiler_defeated(actor: Node2D) -> void:
	if not is_instance_valid(actor) or actor!=registered_boss or not bool(actor.is_dead) or bool(actor.alive) or int(actor.hp)!=0: return
	if _compiler_won(): return
	if not is_boss_trial and not environment_preview and not _requirements_met(["guard_clear","compiler_seal_owned","seal_registered"]): return
	progress[_compiler_flag()] = true
	boss_active = false
	_clear_compiler_attacks()
	if is_instance_valid(boss_arena): boss_arena.set_defeated(true)
	combat_state.increase_capacity("dr_compiler_capacity",1)
	_issue_coin_reward("boss:dr_compiler",actor.position,90)
	_save()
	if is_instance_valid(boss_music): boss_music.stop_fight(true)
	if hud.has_method("show_boss_victory"): hud.show_boss_victory()
	if is_instance_valid(_boss_camera_tween): _boss_camera_tween.kill()
	_boss_camera_tween = create_tween()
	_boss_camera_tween.tween_property(camera,"zoom",_camera_zoom,.8).set_trans(Tween.TRANS_SINE)
	_boss_camera_tween.tween_callback(func():
		if is_instance_valid(camera): camera.target = hero)
	_tip("انتهى الحكم · توسعت سعة الفانوس. اجمع العملات.","Judgment ended · Lantern capacity expanded. Collect the coins.")
