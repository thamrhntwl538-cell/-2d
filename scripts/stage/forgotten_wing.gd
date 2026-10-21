extends Node2D
## Connected environment tour. Combat callbacks require registered real actors;
## the tour can cross combat-only doors without awarding those accomplishments.
signal room_changed(room_id: int)
const Layouts = preload("res://scripts/stage/stage_01_layouts.gd")
const Hero = preload("res://scripts/player.gd")
const Camera = preload("res://scripts/camera/academic_camera.gd")
const Interactable = preload("res://scripts/interactables/m15/academic_interactable.gd")
const Elevator = preload("res://scripts/interactables/m15/academic_elevator.gd")
const Reaction = preload("res://scripts/interactables/m15/academic_reaction.gd")
const Gate = preload("res://scripts/interactables/academic_gate.gd")
const GateScene = preload("res://scenes/interactables/academic_gate.tscn")
const ShelfScene = preload("res://scenes/interactables/m15/secret_shelf.tscn")
const Visuals = preload("res://scripts/stage/m15_room_visuals.gd")
const QuietVisuals = preload("res://scripts/stage/m16_room_visuals.gd")
const SurfaceSkin = preload("res://scripts/stage/m16_surface_skin.gd")
const LocalLighting = preload("res://scripts/stage/m16_lighting.gd")
const KIT = preload("res://assets/environments/silent_entrance/academic_kit.png")
const FONT = preload("res://assets/fonts/DejaVuSans.ttf")
const SAVE_FILE := "user://forgotten_wing_m15.json"
@export var environment_preview: bool = true
@export var restore_saved_game: bool = true
@export var transition_seconds: float = 0.22
@export_range(15,16) var visual_revision: int = 16
var current_room: int = 0
var data: Dictionary = {}
var gameplay_active: bool = false
var transitioning: bool = false
var paused: bool = false
var elapsed: float = 0.0
var hero: LastLecturePlayer
var camera: Camera2D
var active_room: Node2D
var visuals: Node2D
var lighting: Node2D
var surface_counts: Dictionary = {}
var elevator: AnimatableBody2D
var objects: Array[Dictionary] = []
var gates: Array[Dictionary] = []
var reactions: Array[Node2D] = []
var progress: Dictionary = {"entrance_access":false,"input":false,"process":false,"output":false,"puzzle_complete":false,"archive_shortcut":false,"archive_secret":false,"compiler_seal":false,"boss_defeated":false,"encounters":{},"notes":[],"visited":[]}
var checkpoint: Dictionary = {"room":0,"position":[440.0,1260.0]}
var encounter_actors: Dictionary = {}
var registered_boss: Node2D
var tour_finished: bool = false
var toast_timer: float = 0.0
var room_label: Label
var objective: Label
var hint: Label
var toast: Label
var sequence: Label
var map_label: Label
var map_panel: PanelContainer
var pause_panel: PanelContainer
var fade: ColorRect
var music: AudioStreamPlayer

func _ready() -> void:
	_register_inputs()
	_build_ui()
	camera = Camera.new()
	add_child(camera)
	hero = Hero.new()
	hero.name = "LanternWarden_M13"
	hero.world_ref = self
	hero.z_index = 4
	add_child(hero)
	camera.target = hero
	if restore_saved_game: _restore_save()
	_load_room(int(checkpoint.room), "left", Vector2(float(checkpoint.position[0]), float(checkpoint.position[1])))
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/ambient.wav")
	music.volume_db = -29
	music.finished.connect(music.play)
	add_child(music)
	music.play()
	fade.color.a = 1
	create_tween().tween_property(fade, "color:a", 0.0, 0.7)
	gameplay_active = true

func _register_inputs() -> void:
	var bindings := {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"look_up":[KEY_W,KEY_UP],"look_down":[KEY_S,KEY_DOWN],"jump":[KEY_SPACE],"interact":[KEY_E],"dash":[KEY_K],"pause_game":[KEY_ESCAPE],"stage_map":[KEY_M],"attack":[KEY_J],"parry":[KEY_F],"spell":[KEY_L]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action,event): InputMap.action_add_event(action,event)

func _label(parent: Node, position_value: Vector2, size_value: Vector2, text_value: String, font_size: int = 17) -> Label:
	var label := Label.new()
	label.position = position_value
	label.size = size_value
	label.text = text_value
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("c7d3d1"))
	label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.9))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Presentation"
	layer.layer = 30
	add_child(layer)
	var hud := Control.new()
	hud.name = "HUD"
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0,0.65,1])
	gradient.colors = PackedColorArray([Color(0.02,0.035,0.05,0.85),Color(0.02,0.035,0.05,0.58),Color(0.02,0.035,0.05,0)])
	var shade := GradientTexture2D.new()
	shade.gradient = gradient
	shade.width = 1280
	shade.height = 166
	shade.fill_from = Vector2(0,0)
	shade.fill_to = Vector2(0,1)
	var top := TextureRect.new()
	top.texture = shade
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(top)
	_label(hud,Vector2(32,15),Vector2(980,40),"LAST LECTURE" if visual_revision >= 16 else "LAST LECTURE / THE FORGOTTEN PROGRAMMING WING",18 if visual_revision >= 16 else 21)
	_label(hud,Vector2(1000,22),Vector2(260,40),"08:00 — 08:10",15)
	room_label = _label(hud,Vector2(34,58),Vector2(1150,38),"",17)
	objective = _label(hud,Vector2(34,100),Vector2(1200,38),"",14)
	sequence = _label(hud,Vector2(32,145),Vector2(1000,40),"",14)
	hint = _label(hud,Vector2(120,565),Vector2(1040,50),"",18)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast = _label(hud,Vector2(60,620),Vector2(1160,48),"",16)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(hud,Vector2(32,681),Vector2(1200,30),"A/D  MOVE    SPACE  JUMP    E  INTERACT / DOOR    K  DASH    M  MAP    ESC  PAUSE",13)
	if visual_revision >= 16:
		room_label.position.y = 50
		room_label.add_theme_font_size_override("font_size",15)
		objective.position.y = 82
		objective.add_theme_font_size_override("font_size",13)
		objective.modulate.a = 0.72
		sequence.position.y = 116
		sequence.modulate.a = 0.8
		for child in hud.get_children():
			if child is Label and child.position.y == 681: child.modulate.a = 0.55
	map_panel = _panel(layer,Vector2(245,160),Vector2(790,470))
	map_label = _label(map_panel,Vector2.ZERO,Vector2(730,420),"",16)
	pause_panel = _panel(layer,Vector2(405,240),Vector2(470,270))
	var buttons := VBoxContainer.new()
	pause_panel.add_child(buttons)
	_label(buttons,Vector2.ZERO,Vector2(400,50),"PAUSED / متوقف",22)
	for item in [["Continue / متابعة",toggle_pause],["Begin again / البداية من جديد",restart_stage]]:
		var button := Button.new()
		button.text = item[0]
		button.add_theme_font_override("font",FONT)
		button.add_theme_font_size_override("font_size",19)
		button.pressed.connect(item[1])
		buttons.add_child(button)
	fade = ColorRect.new()
	fade.size = Vector2(1280,720)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.color = Color(0.01,0.02,0.03,0)
	layer.add_child(fade)

func _panel(parent: Node, pos: Vector2, panel_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = panel_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.045,0.06,0.98)
	style.border_color = Color("75664a")
	style.set_border_width_all(1)
	style.content_margin_left = 24
	style.content_margin_top = 18
	style.content_margin_right = 24
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel",style)
	panel.visible = false
	parent.add_child(panel)
	return panel

func _load_room(index: int, spawn_name: String = "left", exact_position: Vector2 = Vector2.INF) -> void:
	# Leaving a room never converts freed actors into verified combat victories.
	encounter_actors.clear()
	registered_boss = null
	if active_room:
		remove_child(active_room)
		active_room.free()
	current_room = clampi(index,0,9)
	data = Layouts.room(current_room)
	active_room = load(data.scene).instantiate()
	active_room.name = "Room_%02d" % current_room
	add_child(active_room)
	objects.clear()
	gates.clear()
	reactions.clear()
	elevator = null
	lighting = null
	surface_counts.clear()
	hero.lantern_sprite.material = null
	hero.position = data.spawns.get(spawn_name,data.spawn_left) if exact_position == Vector2.INF else exact_position
	hero.velocity = Vector2.ZERO
	hero.movement_bounds = Vector2(34,data.size.x-34)
	hero.fall_limit = data.size.y+180
	camera.room_rect = Rect2(Vector2.ZERO,data.size)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(data.size.x)
	camera.limit_bottom = int(data.size.y)
	camera.position = camera.bounded(hero.position+Vector2(130,-230))
	camera.reset_smoothing()
	visuals = QuietVisuals.new() if visual_revision >= 16 else Visuals.new()
	active_room.add_child(visuals)
	visuals.setup(self,data)
	for definition in data.interactables: _add_object(definition)
	for definition in data.get("lift_calls",[]):
		var call_definition: Dictionary = definition.duplicate(true)
		call_definition.kind = "lift_call"
		call_definition.label = "CALL ARCHIVE LIFT / طلب المصعد"
		_add_object(call_definition)
	for definition in data.gates:
		var gate: Node2D = GateScene.instantiate()
		gate.texture = KIT
		gate.source_rect = Rect2(1070,482,412,479)
		gate.gate_height = float(definition.get("height",286))
		gate.position = definition.pos
		active_room.add_child(gate)
		gates.append({"definition":definition,"node":gate})
	for definition in data.get("secret_passages",[]):
		var shelf: Node2D = ShelfScene.instantiate()
		shelf.position = definition.pos
		active_room.add_child(shelf)
		gates.append({"definition":definition,"node":shelf})
	_build_elevator()
	_build_reactions()
	_build_portals()
	if visual_revision >= 16:
		surface_counts = SurfaceSkin.setup(self,data)
		lighting = LocalLighting.new()
		active_room.add_child(lighting)
		lighting.setup(self,data)
	_refresh_gates(true)
	if not progress.visited.has(current_room): progress.visited.append(current_room)
	room_label.text = "%02d / %s  ·  %s" % [current_room+1,data.title,data.arabic_title]
	show_tip(data.title+" / "+data.arabic_title)
	_update_hud()
	room_changed.emit(current_room)

func _add_object(definition: Dictionary) -> void:
	var item := Interactable.new()
	item.id = definition.id
	item.kind = definition.kind if definition.kind in ["terminal","bench","lever","note"] else "terminal"
	item.label = definition.get("label",definition.id)
	item.position = definition.pos
	item.can_repeat = definition.kind in ["bench","lift_call","arena_reaction","seal_socket"]
	item.active = progress.notes.has(definition.id) if definition.kind == "note" else bool(progress.get(definition.get("flag",definition.id),false))
	active_room.add_child(item)
	objects.append({"definition":definition,"node":item})

func _build_elevator() -> void:
	var definition: Dictionary = data.get("elevator",{})
	if not definition.is_empty():
		elevator = Elevator.new()
		elevator.name = "ArchiveLift"
		elevator.width = definition.width
		elevator.speed = definition.speed
		var stops: Array = []
		for y in definition.stops: stops.append(Vector2(definition.pos.x,y))
		elevator.configure_stops(stops)
		active_room.add_child(elevator)
	for moving in data.get("moving_platforms",[]):
		var platform := Elevator.new()
		platform.width = moving.width
		platform.speed = moving.speed
		platform.draw_cables = false
		platform.configure_stops(moving.points)
		active_room.add_child(platform)
		platform.arrived.connect(func(_stop): platform.trigger.call_deferred())
		platform.trigger()

func _build_reactions() -> void:
	if current_room not in [4,5,6,8]: return
	var reaction := Reaction.new()
	reaction.kind = "tribunal" if current_room == 8 else ("output" if current_room == 6 else "process")
	reaction.position = data.get("core",{}).get("pos",Vector2(data.size.x/2,data.floor_y-300))
	reaction.art_size = Vector2(410,410) if current_room == 8 else Vector2(320,320)
	reaction.z_index = -1
	active_room.add_child(reaction)
	reactions.append(reaction)
	if requirement_met("input" if current_room == 4 else ("process" if current_room == 5 else ("output" if current_room == 6 else "arena_charged"))): reaction.react("activate")

func _build_portals() -> void:
	for exit in data.exits:
		var sign_label := _label(active_room,exit.pos+Vector2(-100,-185),Vector2(270,70),"↔  "+exit.label,13)
		sign_label.z_index = -1
	for passage in data.get("secret_passages",[]):
		var label := _label(active_room,passage.pos+Vector2(-80,-150),Vector2(260,60),passage.label,13)
		label.modulate.a = 0.6

func requirement_met(requirement: String) -> bool:
	if requirement.is_empty(): return true
	if requirement.begins_with("encounter:"): return bool(progress.encounters.get(requirement.trim_prefix("encounter:"),false))
	return bool(progress.get(requirement,false))

func can_use_exit(exit: Dictionary) -> bool:
	return requirement_met(exit.get("requires","")) or (environment_preview and bool(exit.get("preview_bypass",false)))

func _refresh_gates(instant: bool = false) -> void:
	for entry in gates:
		var definition: Dictionary = entry.definition
		var permitted := requirement_met(definition.get("requires","")) or (environment_preview and bool(definition.get("preview_bypass",false)))
		if permitted:
			entry.node.unlock()
			if instant: entry.node.progress = 1.0

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause_game") and not transitioning: toggle_pause()
	if Input.is_action_just_pressed("stage_map") and not transitioning: toggle_map()
	if not gameplay_active: return
	if Input.is_action_just_pressed("interact"): interact()
	for hazard in data.get("hazards",[]):
		var phase := fposmod(elapsed,float(hazard.get("period",4.5)))
		var telegraph := float(hazard.get("telegraph_seconds",1.2))
		if phase >= telegraph and phase < telegraph+float(hazard.get("active_seconds",0.7)):
			var area := Rect2(hazard.pos-Vector2(hazard.width/2,hazard.height),Vector2(hazard.width,hazard.height))
			if area.intersects(Rect2(hero.position-Vector2(15,58),Vector2(30,58))): hero.hurt(1,hazard.pos.x)

func _process(delta: float) -> void:
	if gameplay_active: elapsed += delta
	toast_timer = maxf(0,toast_timer-delta)
	toast.modulate.a = minf(1.0,toast_timer)
	if is_instance_valid(hero):
		_update_hud()
		queue_redraw()

func nearest_action() -> Dictionary:
	if elevator and absf(hero.position.y-elevator.position.y)<24 and absf(hero.position.x-elevator.position.x)<elevator.width/2-10 and not elevator.moving:
		return {"type":"ride","label":"NEXT ARCHIVE FLOOR / الطابق التالي"}
	var nearest: Dictionary = {}
	var distance := 103.0
	for entry in objects:
		var definition: Dictionary = entry.definition
		if entry.node.active and not entry.node.can_repeat: continue
		var separation: float = hero.position.distance_to(definition.pos)
		if separation < distance:
			distance = separation
			nearest = {"type":"object","entry":entry,"label":definition.get("label",definition.id)}
	for exit in data.exits:
		var separation: float = hero.position.distance_to(exit.pos)
		if separation < distance:
			distance = separation
			nearest = {"type":"exit","exit":exit,"label":exit.label}
	return nearest

func interact() -> void:
	var action := nearest_action()
	match action.get("type",""):
		"ride":
			elevator.trigger()
			play_sfx("pickup")
		"object": _activate(action.entry)
		"exit":
			if can_use_exit(action.exit):
				_begin_transition.call_deferred(action.exit)
			else: show_tip("Access still locked / أكمل آلية هذه الغرفة أولًا")

func _activate(entry: Dictionary) -> void:
	var definition: Dictionary = entry.definition
	var kind: String = definition.kind
	if kind == "lift_call":
		if elevator: elevator.request_stop(int(definition.stop))
		entry.node.activate()
		return
	if kind == "seal_socket":
		show_tip("Compiler Seal is earned in the later combat encounter / مفتاح الزعيم مرتبط بالقتال لاحقًا")
		return
	if kind.begins_with("puzzle_"):
		var step_name := kind.trim_prefix("puzzle_")
		if step_name == "process" and not requirement_met("input") or step_name == "output" and not requirement_met("process"):
			play_sfx("hurt")
			show_tip("INPUT  →  PROCESS  →  OUTPUT / أكمل التسلسل بالترتيب")
			return
		progress[step_name] = true
		if step_name == "output": progress.puzzle_complete = true
	elif kind == "bench":
		checkpoint = {"room":current_room,"position":[definition.pos.x+85,definition.pos.y]}
		hero.hp = hero.max_hp
		show_tip("Progress remembered / تم حفظ التقدم")
	elif kind == "note":
		if not progress.notes.has(definition.id): progress.notes.append(definition.id)
		show_tip(definition.get("text","")+" / "+definition.get("arabic_text",""))
	else:
		progress[definition.get("flag",definition.id)] = true
		show_tip("Mechanism restored / تم تفعيل الآلية")
	entry.node.activate()
	for reaction in reactions: reaction.react("phase2" if current_room == 8 else "activate")
	_refresh_gates()
	_save()
	play_sfx("save" if kind == "bench" else "pickup")

func _begin_transition(exit: Dictionary) -> void:
	if transitioning: return
	transitioning = true
	gameplay_active = false
	var hide := create_tween()
	hide.tween_property(fade,"color:a",1.0,transition_seconds)
	await hide.finished
	if int(exit.target) < 0:
		tour_finished = true
		show_tip("The next lecture awaits / انتهى مسار البيئة عند عتبة المرحلة التالية")
	else:
		_load_room(int(exit.target),exit.target_spawn)
	var reveal := create_tween()
	reveal.tween_property(fade,"color:a",0.0,transition_seconds)
	await reveal.finished
	transitioning = false
	gameplay_active = true

func _update_hud() -> void:
	var action := nearest_action() if gameplay_active else {}
	hint.text = "E  ·  "+str(action.label) if not action.is_empty() else ""
	var status: String = "ENVIRONMENT TOUR / استكشاف البيئة" if environment_preview else "STAGE 01 / المرحلة الأولى"
	objective.text = status+"   ·   "+("Restore the gallery relay / فعّل جهاز الشرفة" if current_room == 0 and not requirement_met("entrance_access") else ("M  MAP / الخريطة" if visual_revision >= 16 else "Explore the wing · M map / استكشف الجناح والخريطة بزر M"))
	var steps: Array[String] = []
	for key in ["input","process","output"]:
		steps.append(("● " if requirement_met(key) else "○ ")+key.to_upper())
	sequence.text = "  →  ".join(steps) if current_room in [4,5,6] else ""

func toggle_pause() -> void:
	if map_panel.visible:
		toggle_map()
		return
	paused = not paused
	pause_panel.visible = paused
	_set_paused(paused)

func toggle_map() -> void:
	if pause_panel.visible: return
	map_panel.visible = not map_panel.visible
	_set_paused(map_panel.visible)
	var lines: Array[String] = ["THE PROGRAMMING WING / خريطة الجناح", ""]
	for room in Layouts.all_rooms():
		lines.append(("◆ " if room.id == current_room else ("● " if progress.visited.has(room.id) else "○ "))+"%02d  %s / %s" % [room.id+1,room.title,room.arabic_title])
	lines.append("\n04 ↔ 02: "+("OPEN" if requirement_met("archive_shortcut") else "LOCKED")+"    07 ↔ 03: "+("OPEN" if requirement_met("puzzle_complete") else "LOCKED")+"\nM / ESC  CLOSE / إغلاق")
	map_label.text = "\n".join(lines)

func _set_paused(value: bool) -> void:
	gameplay_active = not value
	active_room.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	# Preserve airborne momentum and the exact animation frame while menus are up.
	hero.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	if value: hero.lantern_sprite.pause()
	else: hero.lantern_sprite.play()

func _save() -> void:
	var save := {"version":15,"progress":progress,"checkpoint":checkpoint}
	FileAccess.open(SAVE_FILE,FileAccess.WRITE).store_string(JSON.stringify(save,"\t"))

func _restore_save() -> void:
	_migrate_m15_save()
	if not FileAccess.file_exists(SAVE_FILE): return
	var save: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_FILE))
	if save is Dictionary and int(save.get("version",0)) == 15:
		progress.merge(save.get("progress",{}),true)
		# JSON numbers return as floats; normalize room IDs before Array.has().
		var visited: Array[int] = []
		for value in progress.get("visited",[]):
			var room_id := clampi(int(value),0,9)
			if not visited.has(room_id): visited.append(room_id)
		progress.visited = visited
		checkpoint = save.get("checkpoint",checkpoint)

func _migrate_m15_save() -> void:
	# Keep progress when moving from the milestone-specific M15 application name
	# to the stable project name. Mark the attempt so Begin again stays a reset.
	const MARKER := "user://m15_save_migration.done"
	if FileAccess.file_exists(MARKER): return
	if not FileAccess.file_exists(SAVE_FILE):
		var previous := OS.get_user_data_dir().get_base_dir().path_join("LAST LECTURE — M15 The Forgotten Programming Wing").path_join("forgotten_wing_m15.json")
		if FileAccess.file_exists(previous):
			var contents := FileAccess.get_file_as_string(previous)
			var parser := JSON.new()
			var valid_json := parser.parse(contents) == OK
			var saved: Variant = parser.data if valid_json else null
			if saved is Dictionary and int(saved.get("version",0)) == 15:
				FileAccess.open(SAVE_FILE,FileAccess.WRITE).store_string(contents)
	FileAccess.open(MARKER,FileAccess.WRITE).store_string("M16 stable application name\n")

func restart_stage() -> void:
	if FileAccess.file_exists(SAVE_FILE): DirAccess.remove_absolute(SAVE_FILE)
	get_tree().reload_current_scene()

func player_fell() -> void:
	if int(checkpoint.room) == current_room:
		hero.position = Vector2(checkpoint.position[0],checkpoint.position[1])
	else: hero.position = data.spawn_left
	hero.velocity = Vector2.ZERO
	hero.hp = hero.max_hp

func on_player_death() -> void: player_fell()
func hero_strike(_direction: String,_facing: int) -> void: pass
func cast_code_slash(_point: Vector2,_direction: int) -> void: pass
func on_parry(_from_x: float) -> void: pass
func on_perfect_dodge() -> void: pass
func emit_burst(_point: Vector2,_color: Color,_amount: int) -> void: pass

func show_tip(message: String) -> void:
	toast.text = message
	toast_timer = 4.5

func play_sfx(cue: String) -> void:
	var path := "res://assets/audio/"+cue+".wav"
	if not ResourceLoader.exists(path): return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.volume_db = -25
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func register_encounter(id: String, actors: Array) -> void:
	# Future combat integration. Empty lists never count as a cleared encounter.
	var members: Array[int] = []
	for actor in actors:
		if is_instance_valid(actor): members.append(actor.get_instance_id())
	if not members.is_empty(): encounter_actors[id] = {"members":members,"defeated":[]}

func on_enemy_defeated(actor: Node2D) -> void:
	if not is_instance_valid(actor) or not bool(actor.get("is_dead")): return
	var identity := actor.get_instance_id()
	for id in encounter_actors:
		var record: Dictionary = encounter_actors[id]
		if not record.members.has(identity): continue
		if not record.defeated.has(identity): record.defeated.append(identity)
		if record.defeated.size() == record.members.size(): progress.encounters[id] = true
	_refresh_gates()
	_save()

func on_boss_defeated() -> void:
	if not is_instance_valid(registered_boss) or bool(registered_boss.get("alive")): return
	progress.boss_defeated = true
	_refresh_gates()
	_save()

func _draw() -> void:
	for hazard in data.get("hazards",[]):
		var phase := fposmod(elapsed,float(hazard.get("period",4.5)))
		var telegraph := float(hazard.get("telegraph_seconds",1.2))
		var firing := phase >= telegraph and phase < telegraph+float(hazard.get("active_seconds",0.7))
		var alpha := 0.32 if firing else (0.16 if phase < telegraph else 0.04)
		var point: Vector2 = hazard.pos
		draw_line(point-Vector2(hazard.width/2,2),point+Vector2(hazard.width/2,-2),Color(0.8,0.38,0.22,alpha),4,true)
		if firing:
			for i in range(5):
				var x: float = point.x-hazard.width/2+i*hazard.width/4
				draw_line(Vector2(x,point.y),Vector2(x+sin(elapsed*12+i)*8,point.y-hazard.height),Color(0.50,0.72,0.74,0.32),2,true)
