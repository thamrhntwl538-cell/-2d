extends Node2D
## M17 native environment implementation. Preview access never records combat wins.
signal room_changed(room_id: int)
const Layouts = preload("res://scripts/stage/m17_layouts.gd")
const Hero = preload("res://scripts/player.gd")
const RoomCamera = preload("res://scripts/camera/academic_camera.gd")
const PaperPlatform = preload("res://scripts/stage/m17_paper_platform.gd")
const RoomVisuals = preload("res://scripts/stage/m17_room_visuals.gd")
const Puzzle = preload("res://scripts/stage/m17_puzzle_state.gd")
const Item = preload("res://scripts/interactables/m17/library_interactable.gd")
const HUD = preload("res://scripts/ui/m17_hud.gd")
const SAVE_FILE := "user://folding_library_m17.json"
const PREVIEW_SAVE_FILE := "user://folding_library_m17_preview.json"
const SETTINGS_FILE := "user://folding_library_m17_settings.cfg"
const COMBAT_FLAGS := ["encounter_assignments_cleared", "guard_clear", "compiler_seal_owned", "seal_registered", "boss_defeated"]
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

func _ready() -> void:
	_register_inputs()
	progress = Puzzle.new_progress()
	progress.preview_departed = false
	hud = HUD.new()
	add_child(hud)
	hud.setup(self)
	hud.action.connect(_on_ui_action)
	camera = RoomCamera.new()
	add_child(camera)
	hero = Hero.new()
	hero.name = "LanternWarden_M13"
	hero.world_ref = self
	hero.z_index = 5
	add_child(hero)
	camera.target = hero
	if restore_saved_game:
		_restore_save()
	# Interface settings are newer than the last checkpoint. A language switch
	# must survive quitting before the next gameplay save.
	_restore_settings()
	_load_room(int(checkpoint.room), "left", Vector2(float(checkpoint.position[0]), float(checkpoint.position[1])))
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
	create_tween().tween_property(fade,"color:a",0.0,0.65)
	gameplay_active = true
	if bool(progress.get("preview_departed",false)) and environment_preview:
		_finish_preview.call_deferred()

func _register_inputs() -> void:
	var bindings := {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"look_up":[KEY_W,KEY_UP],"look_down":[KEY_S,KEY_DOWN],"jump":[KEY_SPACE],"interact":[KEY_E],"dash":[KEY_K],"pause_game":[KEY_ESCAPE],"stage_map":[KEY_M],"journal":[KEY_N,KEY_TAB],"switch_language":[KEY_F2],"attack":[KEY_J],"parry":[KEY_F],"spell":[KEY_L]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			if not InputMap.action_has_event(action,event):
				InputMap.action_add_event(action,event)

func _load_room(id: int, spawn_name: String = "left", exact_position: Vector2 = Vector2.INF) -> void:
	encounter_actors.clear()
	registered_boss = null
	objects.clear()
	if is_instance_valid(active_room):
		remove_child(active_room)
		active_room.free()
	current_room = clampi(id,1,15)
	data = Layouts.room(current_room)
	var scene_path := str(data.get("scene",""))
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		active_room = load(scene_path).instantiate()
	else:
		active_room = Node2D.new()
	active_room.name = "LibraryArea_%02d" % current_room
	add_child(active_room)
	visuals = RoomVisuals.new()
	active_room.add_child(visuals)
	visuals.setup(self,data)
	surface_root = Node2D.new()
	surface_root.name = "PlayablePaperGeometry"
	active_room.add_child(surface_root)
	_refresh_geometry()
	for definition in data.get("objects",[]):
		var item := Item.new()
		item.name = str(definition.id).validate_node_name()
		active_room.add_child(item)
		item.setup(self,definition)
		item.position = definition.pos
		objects.append({"definition":definition,"node":item})
	var spawns: Dictionary = data.get("spawns",{})
	hero.position = spawns.get(spawn_name,spawns.get("left",Vector2(180,float(data.floor_y)))) if exact_position == Vector2.INF else exact_position
	hero.velocity = Vector2.ZERO
	hero.hp = hero.max_hp
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
	_panel_definition = {}
	_update_hud()
	room_changed.emit(current_room)

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
	if bool(progress.get("world1_departed",false)) or tour_finished:
		return false
	return _requirements_met(exit.get("requires",[]),bool(exit.get("combat_preview",false)))

func _physics_process(delta: float) -> void:
	if transitioning or fold_active:
		return
	if Input.is_action_just_pressed("switch_language"):
		_on_ui_action("language","en" if hud.language == "ar" else "ar")
	if Input.is_action_just_pressed("pause_game"):
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
			if rect.intersects(Rect2(hero.position-Vector2(15,58),Vector2(30,58))):
				hero.hurt(1,rect.get_center().x)
	_hud_timer += delta
	if _hud_timer > 0.12:
		_hud_timer = 0
		_update_hud()

func _process(delta: float) -> void:
	if gameplay_active:
		elapsed += delta

func nearest_action() -> Dictionary:
	var nearest: Dictionary = {}
	var distance := 112.0
	for entry in objects:
		var definition: Dictionary = entry.definition
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
	var names := {
		"bench":["Rest and save","استراحة وحفظ"],"note":["Read this page","قراءة الصفحة"],"weapon":["Take the Warden's tool","أخذ أداة الحارس"],"dialogue":["Speak to the stranger","التحدث مع الغريب"],"ink_control":["Connect the ink channels","توصيل قنوات الحبر"],"book":["Collect the book","جمع الكتاب"],"process_control":["Arrange the three books","ترتيب الكتب الثلاثة"],"output_control":["Unfold the page","فتح درج الصفحات"],"balance_control":["Balance the bridge","موازنة الجسر"],"shortcut":["Open the return passage","فتح ممر العودة"],"secret_overlay":["Align the transparent pages","مطابقة الصفحات الشفافة"],"secret_pop":["Unfold the paper model","فتح المجسّم الورقي"],"secret":["Examine the hidden page","تفحّص الصفحة المخفية"],"world_exit":["Examine the threshold","تفحّص عتبة العبور"],"combat_socket":["Examine the seal socket","تفحّص مقبس الختم"]}
	var pair: Array = names.get(str(definition.get("kind","")),["Interact","تفاعل"])
	return pair[1] if arabic else pair[0]

func _exit_label(exit: Dictionary) -> String:
	var target := int(exit.get("target",16))
	if target > 15:
		return "عتبة المحاضرة التالية" if hud.language == "ar" else "The next lecture"
	var destination: Dictionary = Layouts.room(target)
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
		if int(exit.get("target",16)) > 15:
			_request_departure()
		elif can_use_exit(exit):
			_begin_transition(exit)
		else:
			_tip("أكمل آلية المنطقة لفتح هذا الطريق.","Complete this area's mechanism to open this route.")

func _activate(entry: Dictionary) -> void:
	var definition: Dictionary = entry.get("definition",entry)
	var kind := str(definition.get("kind",""))
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
		checkpoint = {"room":current_room,"position":[definition.pos.x+64.0,definition.pos.y]}
		hero.hp = hero.max_hp
		_save()
	_panel_definition = effective
	_handle_result(result)

func _handle_result(result: Dictionary) -> void:
	var message := str(result.get("message_ar",result.get("message_key",""))) if hud.language == "ar" else str(result.get("message_en",result.get("message_key","")))
	if not message.is_empty():
		hud.show_toast(message)
	hero.has_blade = bool(progress.get("weapon_owned",false))
	if bool(result.get("changed",false)):
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
	for room in Layouts.all_rooms():
		for definition in room.get("objects",[]):
			if str(definition.get("kind","")) in ["note","secret"] and progress.get("notes",[]).has(str(definition.id)):
				notes.append(definition)
	return {"progress":progress,"state":progress,"definition":_panel_definition,"room":data,"rooms":Layouts.all_rooms(),"notes":notes,"environment_preview":environment_preview,"preview_departed":tour_finished}

func _open_panel(kind: String) -> void:
	_set_paused(true)
	hud.open_panel(kind,_panel_context())

func _close_panel() -> void:
	if tour_finished:
		hud.open_panel("completion",_panel_context())
		return
	hud.close_panel()
	_panel_definition = {}
	_set_paused(false)

func _on_ui_action(action: String, value: Variant = null) -> void:
	match action:
		"map": toggle_map()
		"journal": _open_panel("journal")
		"pause": toggle_pause()
		"resume", "close_panel": _close_panel()
		"restart": restart_stage()
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
	hud.close_panel()
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
	play_sfx("pickup")

func _begin_transition(exit: Dictionary) -> void:
	if transitioning or not can_use_exit(exit):
		return
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
	paused = value
	gameplay_active = not value and not transitioning and not fold_active and not tour_finished
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

func save_path() -> String:
	return PREVIEW_SAVE_FILE if environment_preview else SAVE_FILE

func _save() -> void:
	var record := {"version":17,"environment_preview":environment_preview,"progress":progress,"checkpoint":checkpoint,"language":hud.language}
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
	if not record is Dictionary or int(record.get("version",0)) != 17 or bool(record.get("environment_preview",false)) != environment_preview:
		return
	var saved: Variant = record.get("progress",{})
	if saved is Dictionary:
		progress.merge(saved,true)
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
			var room: Dictionary = Layouts.room(int(point.room))
			var candidate := Vector2(float(position_value[0]),float(position_value[1]))
			if Rect2(Vector2.ZERO,room.size).has_point(candidate):
				checkpoint = {"room":int(point.room),"position":[candidate.x,candidate.y]}
	if not environment_preview and int(checkpoint.room) == 13 and not (requirement_met("guard_clear") and requirement_met("compiler_seal_owned")):
		checkpoint = {"room":10,"position":[310.0,1260.0]}
	hud.language = "en" if str(record.get("language",hud.language)) == "en" else "ar"

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("interface","language",hud.language)
	config.save(SETTINGS_FILE)

func _restore_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		hud.language = "en" if str(config.get_value("interface","language","ar")) == "en" else "ar"

func restart_stage() -> void:
	if FileAccess.file_exists(save_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path()))
	get_tree().reload_current_scene()

func player_fell() -> void:
	if _respawning or transitioning or tour_finished:
		return
	_respawning = true
	_respawn.call_deferred()

func _respawn() -> void:
	_set_paused(true)
	_load_room(int(checkpoint.room),"left",Vector2(float(checkpoint.position[0]),float(checkpoint.position[1])))
	hero.hp = hero.max_hp
	hero.invulnerable = 1.2
	_respawning = false
	_set_paused(false)

func on_player_death() -> void: player_fell()
func hero_strike(_direction: String,_facing: int) -> void: pass
func cast_code_slash(_point: Vector2,_direction: int) -> void: pass
func on_parry(_from_x: float) -> void: pass
func on_perfect_dodge() -> void: pass
func emit_burst(_point: Vector2,_color: Color,_amount: int) -> void: pass

func show_tip(message: String) -> void:
	if is_instance_valid(hud):
		hud.show_toast(message)

func _tip(arabic: String, english: String) -> void:
	show_tip(arabic if hud.language == "ar" else english)

func play_sfx(cue: String) -> void:
	var path := "res://assets/audio/"+cue+".wav"
	if not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.volume_db = -25
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
	if not is_instance_valid(actor) or not bool(actor.get("is_dead")):
		return
	for id in encounter_actors:
		var record: Dictionary = encounter_actors[id]
		var identity := actor.get_instance_id()
		if not record.members.has(identity):
			continue
		if not record.defeated.has(identity):
			record.defeated.append(identity)
		if record.defeated.size() == record.members.size():
			progress[str(id)] = true
	_save()

func on_boss_defeated() -> void:
	if not is_instance_valid(registered_boss) or bool(registered_boss.get("alive")):
		return
	progress.boss_defeated = true
	_save()

func _exit_tree() -> void:
	# Release active audio voices before scene reloads, including a reload that
	# interrupts a fold. Playback must not keep the old world's streams alive.
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
