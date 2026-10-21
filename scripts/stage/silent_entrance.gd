extends Node2D
## M14: an environment-first opening. No enemies or boss logic is instantiated.
const HeroScript = preload("res://scripts/player.gd")
const KIT = preload("res://assets/environments/silent_entrance/academic_kit.png")
const ARCH = preload("res://assets/environments/silent_entrance/academic_arch.png")
const DISTANT = preload("res://assets/environments/silent_entrance/distant_academy.png")
const ROOM_RECT := Rect2(0, 0, 3840, 1440)
const FLOOR_Y := 1260.0
const SAVE_FILE := "user://silent_entrance_checkpoint.json"
const BENCH_POSITION := Vector2(350, 1260)
var gameplay_active: bool = true
var hero: LastLecturePlayer
var elapsed: float = 0.0
var route_open: bool = false
var discovered_note: bool = false
var reached_threshold: bool = false
var checkpoint_position := Vector2(220, 1260)
var toast_timer: float = 0.0
var particles: Array[Dictionary] = []
var far_sprites: Array[Sprite2D] = []
var arches: Array[Sprite2D] = []
var screens: Array[Sprite2D] = []
var music: AudioStreamPlayer
@onready var camera: Camera2D = $AcademicCamera
@onready var gate: Node2D = $Architecture/EntranceGate
@onready var terminal: Node2D = $Architecture/GalleryTerminal
@onready var hint: Label = $Presentation/HUD/Interaction
@onready var objective: Label = $Presentation/HUD/Objective
@onready var toast: Label = $Presentation/HUD/Toast
@onready var pause_panel: PanelContainer = $Presentation/Pause

func _ready() -> void:
	_register_inputs()
	_build_depth()
	_build_dressing()
	hero = HeroScript.new()
	hero.name = "LanternWarden"
	hero.world_ref = self
	hero.movement_bounds = Vector2(34, 3806)
	hero.fall_limit = 1590
	hero.position = checkpoint_position
	hero.z_index = 4
	add_child(hero)
	camera.target = hero
	camera.position = camera.bounded(hero.position + Vector2(130, -230))
	terminal.activated.connect(_terminal_activated)
	gate.opened.connect(func(): show_tip("The programming wing is open / فُتحت بوابة الجناح"))
	$Presentation/Pause/Buttons/Resume.pressed.connect(toggle_pause)
	$Presentation/Pause/Buttons/Restart.pressed.connect(restart_opening)
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/ambient.wav")
	music.volume_db = -28.0
	music.finished.connect(music.play)
	add_child(music)
	music.play()
	show_tip("THE SILENT ENTRANCE  /  المدخل الصامت")
	var fade := create_tween()
	fade.tween_property($Presentation/Fade, "color:a", 0.0, 1.3)
	var saved: Variant = null
	if FileAccess.file_exists(SAVE_FILE):
		saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE_FILE))
	if saved is Dictionary and saved.get("version", 0) == 14:
		checkpoint_position = BENCH_POSITION + Vector2(90, 0)
		hero.position = checkpoint_position
		# Restore all state before activate() emits its persistence callback.
		discovered_note = bool(saved.get("note", false))
		if bool(saved.get("route_open", false)):
			terminal.activate()
			gate.progress = 1.0

func _register_inputs() -> void:
	var binds := {"move_left":[KEY_A, KEY_LEFT], "move_right":[KEY_D, KEY_RIGHT], "look_up":[KEY_W, KEY_UP], "look_down":[KEY_S, KEY_DOWN], "jump":[KEY_SPACE], "dash":[KEY_K], "interact":[KEY_E], "pause_game":[KEY_ESCAPE], "attack":[KEY_J], "parry":[KEY_F], "spell":[KEY_L]}
	for action in binds:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in binds[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)

func _build_depth() -> void:
	# Screen-space far layer: independent, gently scrolling, with no world-camera edge.
	var layer := CanvasLayer.new()
	layer.name = "FarAcademicArchitecture"
	layer.layer = -20
	add_child(layer)
	for i in range(3):
		var sprite := Sprite2D.new()
		sprite.texture = DISTANT
		sprite.centered = false
		sprite.scale = Vector2(1.2, 1.2)
		sprite.modulate = Color(0.72, 0.80, 0.88, 1.0)
		layer.add_child(sprite)
		far_sprites.append(sprite)
	# Mid-distance arches are independent transparent artwork, not baked level geometry.
	for i in range(4):
		var arch := Sprite2D.new()
		arch.texture = ARCH
		arch.centered = false
		arch.scale = Vector2(0.98, 1.16)
		arch.modulate = Color(0.65, 0.72, 0.79, 0.72)
		arch.z_index = -8
		$Depth.add_child(arch)
		arches.append(arch)

func _prop(node_name: String, source: Rect2, foot: Vector2, size: Vector2, color := Color.WHITE) -> Sprite2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = KIT
	atlas.region = source
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = atlas
	sprite.centered = false
	sprite.scale = size / source.size
	sprite.position = foot - Vector2(size.x / 2.0, size.y)
	sprite.modulate = color
	sprite.z_index = -1
	$Dressing.add_child(sprite)
	return sprite

func _build_dressing() -> void:
	var locker := Rect2(726, 24, 210, 452)
	for x in [105.0, 530.0, 2845.0, 3000.0]:
		screens.append(_prop("DormantEquipment", locker, Vector2(x, FLOOR_Y), Vector2(83, 180), Color(0.68, 0.74, 0.78)))
	_prop("AssignmentBoard", Rect2(1063, 26, 440, 411), Vector2(495, 1050), Vector2(230, 215), Color(0.72, 0.76, 0.79))
	_prop("GalleryNotices", Rect2(1063, 26, 440, 411), Vector2(2110, 727), Vector2(190, 178), Color(0.72, 0.76, 0.79))
	_prop("CheckpointBench", Rect2(53, 720, 605, 214), BENCH_POSITION, Vector2(176, 62))
	# Deterministic seed keeps restrained dust reproducible during engine QA.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1401
	for i in range(48):
		particles.append({"position":Vector2(rng.randf_range(0, 3840), rng.randf_range(200, 1250)), "velocity":Vector2(rng.randf_range(-6, 5), rng.randf_range(-8, -2)), "phase":rng.randf_range(0, TAU)})

func _process(delta: float) -> void:
	var motion_delta := delta if gameplay_active else 0.0
	elapsed += motion_delta
	for i in range(far_sprites.size()):
		far_sprites[i].position = Vector2(-fposmod(camera.position.x * 0.12, 1843.2) + (i-1)*1843.2, -180.0 - camera.position.y * 0.055)
	for i in range(arches.size()):
		arches[i].position = Vector2(-1120 + i * 1420, 82) + camera.position * Vector2(0.22, 0.10)
	for i in range(screens.size()):
		screens[i].self_modulate = Color.WHITE * (0.94 + sin(elapsed * 3.2 + i * 2.3) * 0.035)
	for particle in particles:
		particle.position += particle.velocity * motion_delta
		if particle.position.y < 100: particle.position.y = 1240
	toast_timer = maxf(0, toast_timer - delta)
	toast.modulate.a = minf(1.0, toast_timer)
	_update_interaction()
	if hero.position.x > 3530 and route_open and not reached_threshold:
		reached_threshold = true
		show_tip("THE FORGOTTEN PROGRAMMING WING / جناح البرمجة المنسي")
	objective.text = "The wing awaits  /  جناح البرمجة أمامك" if reached_threshold else ("Pass through the opened arch  /  اعبر البوابة" if route_open else "Restore access from the upper gallery  /  فعّل جهاز الشرفة العلوية")
	queue_redraw()

func _physics_process(_delta: float) -> void:
	# Keep interaction edges on the same fixed-tick input path as the actor.
	if Input.is_action_just_pressed("pause_game"): toggle_pause()
	if gameplay_active and Input.is_action_just_pressed("interact"): interact()

func _update_interaction() -> void:
	hint.text = ""
	if not gameplay_active: return
	if hero.position.distance_to(terminal.position) < 96 and not route_open:
		hint.text = "E  ·  RESTORE ACCESS / تفعيل البوابة"
	elif hero.position.distance_to(BENCH_POSITION) < 112:
		hint.text = "E  ·  REST & SAVE / استراحة وحفظ"
	elif hero.position.distance_to(Vector2(2410, 550)) < 90 and not discovered_note:
		hint.text = "E  ·  READ THE NOTE / قراءة الملاحظة"
	elif absf(hero.position.x - gate.position.x) < 140 and not route_open:
		hint.text = "Access relay above  ↑  /  جهاز التحكم في الشرفة"

func interact() -> void:
	if hero.position.distance_to(terminal.position) < 96 and not route_open:
		terminal.activate()
	elif hero.position.distance_to(BENCH_POSITION) < 112:
		checkpoint_position = BENCH_POSITION + Vector2(90, 0)
		hero.hp = hero.max_hp
		_save()
		play_sfx("save")
		show_tip("Progress remembered / تم حفظ التقدم")
	elif hero.position.distance_to(Vector2(2410, 550)) < 90 and not discovered_note:
		discovered_note = true
		_save()
		play_sfx("pickup")
		show_tip("Office hours: indefinitely postponed. / الساعات المكتبية: مؤجلة إلى أجل غير مسمى.")

func _terminal_activated() -> void:
	route_open = true
	gate.unlock()
	play_sfx("pickup")
	emit_burst(terminal.position + Vector2(0, -90), Color("b1d4d2"), 18)
	show_tip("Access restored — the entrance gate is rising / عاد التيار، البوابة تُفتح")
	_save()

func _save() -> void:
	var data := {"version":14, "route_open":route_open, "note":discovered_note}
	FileAccess.open(SAVE_FILE, FileAccess.WRITE).store_string(JSON.stringify(data, "\t"))

func toggle_pause() -> void:
	gameplay_active = not gameplay_active
	pause_panel.visible = not gameplay_active
	# Pause environment tweens and gate motion together with the actor.
	$Architecture.process_mode = Node.PROCESS_MODE_INHERIT if gameplay_active else Node.PROCESS_MODE_DISABLED
	hero.lantern_sprite.pause() if not gameplay_active else hero.lantern_sprite.play()

func restart_opening() -> void:
	if FileAccess.file_exists(SAVE_FILE): DirAccess.remove_absolute(SAVE_FILE)
	get_tree().reload_current_scene()

func show_tip(message: String) -> void:
	toast.text = message
	toast_timer = 5.0

func play_sfx(cue: String) -> void:
	var file := "res://assets/audio/" + cue + ".wav"
	if not ResourceLoader.exists(file): return
	var speaker := AudioStreamPlayer.new()
	speaker.stream = load(file)
	speaker.volume_db = -25.0 if cue in ["jump", "dash"] else -20.0
	add_child(speaker)
	speaker.finished.connect(speaker.queue_free)
	speaker.play()

func emit_burst(point: Vector2, color: Color, amount: int) -> void:
	# Existing actor callback. No large bright VFX over the environment.
	for i in range(mini(amount, 8)):
		var spark := Sprite2D.new()
		spark.texture = load("res://assets/warden_clean/glow.png")
		spark.position = point
		spark.scale = Vector2.ONE * 0.016
		spark.modulate = Color(color, 0.45)
		spark.z_index = 3
		add_child(spark)
		var tween := create_tween().set_parallel()
		tween.tween_property(spark, "position", point + Vector2(cos(i * 2.4) * 20, -10 - i * 3), 0.5)
		tween.tween_property(spark, "modulate:a", 0.0, 0.5)
		tween.chain().tween_callback(spark.queue_free)

func player_fell() -> void:
	hero.position = checkpoint_position
	hero.velocity = Vector2.ZERO

func on_player_death() -> void: player_fell()
func hero_strike(_direction: String, _facing: int) -> void: pass
func cast_code_slash(_point: Vector2, _direction: int) -> void: pass
func on_parry(_from_x: float) -> void: pass
func on_perfect_dodge() -> void: pass

func _draw() -> void:
	# Procedural supporting effects only: cables, particles, light shafts, wet glints.
	# Architecture, props and ledge surfaces use the separate painted PNG assets.
	draw_rect(Rect2(0, 1340, 3840, 100), Color("080f16"))
	for i in range(6):
		var x := 320.0 + i * 620.0
		var rays := PackedVector2Array([Vector2(x, 100), Vector2(x+45, 100), Vector2(x+300, 1245), Vector2(x+150, 1245)])
		draw_colored_polygon(rays, Color(0.40, 0.52, 0.63, 0.022))
	for i in range(8):
		var x := 180.0 + i * 470.0
		var points := PackedVector2Array()
		for j in range(20):
			var u := float(j) / 19.0
			points.append(Vector2(x + u*235, 880 + sin(u*PI)*65 + sin(elapsed*0.55+i)*2))
		draw_polyline(points, Color("111b25"), 3.0, true)
	for particle in particles:
		var alpha := 0.1 + (sin(elapsed*0.7+particle.phase)+1)*0.09
		draw_circle(particle.position, 1.1, Color(0.72, 0.77, 0.79, alpha))
	for i in range(12):
		var px := 120.0 + i*310
		draw_line(Vector2(px, 1264), Vector2(px+55, 1264), Color(0.55, 0.65, 0.67, 0.16), 1.5, true)
	for i in range(3):
		var paper_y := fposmod(elapsed*9+i*327.0, 980)+200
		var paper_x := 880+i*930+sin(elapsed*0.3+i)*34
		draw_set_transform(Vector2(paper_x, paper_y), sin(elapsed*0.45+i)*0.6)
		draw_rect(Rect2(-3, -2, 6, 4), Color(0.65, 0.64, 0.55, 0.22))
		draw_set_transform(Vector2.ZERO)
	if not discovered_note:
		draw_circle(Vector2(2410, 530), 3.0, Color(0.76, 0.73, 0.60, 0.55+sin(elapsed*2)*0.15))
	if route_open:
		draw_line(Vector2(2475, 777), Vector2(2570, 777), Color("7faaaa"), 2.0, true)
		for i in range(8):
			var x := 2650 + i*85.0
			draw_circle(Vector2(x, 1254), 1.5, Color(0.50, 0.77, 0.76, 0.45))
