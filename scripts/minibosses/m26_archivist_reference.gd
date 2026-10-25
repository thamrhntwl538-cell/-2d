extends Node2D
## Native review of the supplied art, frame clocks, phases and sound map.
const Actor = preload("res://scripts/minibosses/m26_archivist_sprite.gd")
const SFX = preload("res://scripts/audio/m26_archivist_sfx.gd")
const FONT = preload("res://assets/fonts/DejaVuSans.ttf")
const ORDER: Array[String] = ["idle","walk","slam","sweep","shut","pagestorm","tomes","combo3","p2tr","combo5","redpass","indexlock","burning","pageflip","finale","hurt","death","appear"]
const NAMES: Array[String] = ["وقفة القراءة","المشية المتواصلة","ضربة الفهرس","مسح الهامش","إغلاق الغلاف","عاصفة الصفحات","سقوط المجلدات","كومبو المسح والفهرس","الطبعة المحرّمة","فصل الضربات الخمس","المقطع الأحمر","قفلة الفهرس","الفصل المحترق","قلب الصفحة","الفصل الأخير","تلقّي ضربة","الصفحة الأخيرة","الظهور"]
const SEQUENCE: Array = [["appear",0.0],["idle",2.0],["walk",1.6],["slam",0.0],["idle",.5],["sweep",0.0],["walk",1.0],["shut",0.0],["pagestorm",0.0],["tomes",0.0],["walk",.8],["combo3",0.0],["hurt",0.0],["p2tr",0.0],["idle",1.2],["combo5",0.0],["redpass",0.0],["indexlock",0.0],["burning",0.0],["pageflip",0.0],["walk",.8],["finale",0.0],["hurt",0.0],["death",0.0]]
const TRIAL := "res://scenes/minibosses/archivist_trial_m26.tscn"
const GOLD := Color("e2aa42")
const PAPER := Color("eadfcb")
var actor: Node2D
var sound: Node
var phase := 1
var paused := false
var sound_enabled := true
var show_boxes := false
var rage := false
var sequence_playing := false
var _sequence_index := 0
var _sequence_time := 0.0
var _hold := 0.0
var speed := 1.0
var info: Label
var status: Label
var frame_slider: HSlider
var play_button: Button
var phase_button: Button
var audio_button: Button
var rage_button: Button
var move_buttons: Array[Button] = []

func label(text: String, at: Vector2, area: Vector2, font_size: int = 18, color: Color = PAPER) -> Label:
	var item := Label.new()
	item.text = text
	item.position = at
	item.size = area
	item.add_theme_font_override("font",FONT)
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",color)
	item.text_direction = Control.TEXT_DIRECTION_AUTO
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(item)
	return item

func button(text: String, at: Vector2, area: Vector2, action: Callable) -> Button:
	var item := Button.new()
	item.position = at
	item.size = area
	item.text = text
	item.add_theme_font_override("font",FONT)
	item.add_theme_font_size_override("font_size",16)
	item.focus_mode = Control.FOCUS_NONE
	item.pressed.connect(action)
	add_child(item)
	return item

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0b0806"))
	label("أمين الأرشيف · الرسم والحركات المرفقة",Vector2(352,16),Vector2(890,45),27,GOLD)
	label("معاينة فعلية داخل Godot · الطوران وتوقيت الصوت",Vector2(352,62),Vector2(890,26),16)
	label("الحركات",Vector2(22,18),Vector2(260,38),25)
	for index in range(ORDER.size()):
		var n := index
		move_buttons.append(button("%02d  %s" % [index+1,NAMES[index]],Vector2(20,70+index*29),Vector2(260,27),func(): select_animation(ORDER[n])))
	var stage := Control.new()
	stage.name = "ReferenceViewport"
	stage.position = Vector2(299,99)
	stage.size = Vector2(963,466)
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	actor = Actor.new()
	actor.name = "SuppliedArchivist"
	actor.position = Vector2(341,436)
	actor.visual_scale = .60
	stage.add_child(actor)
	sound = SFX.new()
	add_child(sound)
	sound.setup(actor)
	info = label("",Vector2(315,596),Vector2(935,30),17,GOLD)
	status = label("",Vector2(315,628),Vector2(935,25),14)
	frame_slider = HSlider.new()
	frame_slider.position = Vector2(320,570)
	frame_slider.size = Vector2(920,20)
	frame_slider.step = 1
	frame_slider.value_changed.connect(_scrub_frame)
	add_child(frame_slider)
	play_button = button("إيقاف / Space",Vector2(20,611),Vector2(260,30),func(): set_paused(not paused))
	phase_button = button("الطور ١ / 1–2",Vector2(20,646),Vector2(260,30),func(): set_phase(3-phase))
	button("قلب / F",Vector2(320,660),Vector2(125,30),func(): actor.set_facing(-actor.facing))
	audio_button = button("الصوت: يعمل / S",Vector2(452,660),Vector2(185,30),_toggle_sound)
	rage_button = button("الغضب / R",Vector2(644,660),Vector2(155,30),_toggle_rage)
	button("عرض المعركة / C",Vector2(806,660),Vector2(200,30),start_sequence)
	button("تجربة القتال / Enter",Vector2(1013,660),Vector2(230,30),open_trial)
	select_animation("idle")

func _draw() -> void:
	draw_rect(Rect2(299,99,963,466),Color("120d09"))
	for k in range(8):
		var x := 310.0+k*123
		draw_rect(Rect2(x,118,105,420),Color("18110d"))
		for row in range(4):
			var y := 139.0+row*102
			for book in range(6):
				var height := 48.0+float((book*17+row*11+k*7)%27)
				draw_rect(Rect2(x+5+book*16,y+73-height,13,height),[Color("342019"),Color("25232a"),Color("3c2c1b")][(book+row+k)%3])
			draw_line(Vector2(x,y+75),Vector2(x+105,y+75),Color("51371e"),3)
	draw_line(Vector2(300,535),Vector2(1260,535),Color("816142"),2)
	if show_boxes and is_instance_valid(actor):
		for item in actor.get_hitboxes_world():
			draw_rect(item.rect,Color(1,.35,.15,.2))
			draw_rect(item.rect,Color(1,.55,.2,.8),false,1.5)

func _metadata(name: String) -> Dictionary:
	return actor._meta[actor.resolved_source_phase].get(name,{})

func _apply_speed() -> void:
	var category := String(_metadata(actor.animation_name).get("category","base"))
	actor.playback_speed = speed * (1.3 if rage else 1.0) * (1.15 if phase == 2 and category not in ["base","phase"] else 1.0)
	sound.playback_speed = actor.playback_speed

func select_animation(name: String, manual: bool = true) -> void:
	if not name in ORDER: return
	if manual: sequence_playing = false
	if name in ["combo5","redpass","indexlock","burning","pageflip","finale"]: phase = 2
	if name == "p2tr": phase = 1
	actor.set_animation(name,phase)
	_apply_speed()
	actor.set_playing(not paused)
	sound.play_animation(name,actor.resolved_source_phase,_metadata(name),actor.playback_speed)
	sound.set_paused(paused or not sound_enabled)
	_hold = 0.0
	frame_slider.max_value = maxi(1,int(actor.get_snapshot().frames)-1)
	frame_slider.set_value_no_signal(0)
	for i in range(move_buttons.size()): move_buttons[i].modulate = GOLD if ORDER[i] == name else Color.WHITE
	_update_status()

func set_phase(value: int) -> void:
	phase = clampi(value,1,2)
	if phase == 1 and actor.animation_name in ["combo5","redpass","indexlock","burning","pageflip","finale"]:
		select_animation("idle")
	else:
		select_animation(actor.animation_name)

func set_paused(value: bool) -> void:
	paused = value
	actor.set_playing(not paused)
	sound.set_paused(paused or not sound_enabled)
	_update_status()

func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	if not sound_enabled: sound.stop_all()
	else: sound.seek(actor.animation_time)
	sound.set_paused(paused or not sound_enabled)
	_update_status()

func _toggle_rage() -> void:
	rage = not rage
	_apply_speed()
	_update_status()

func _scrub_frame(value: float) -> void:
	sequence_playing = false
	set_paused(true)
	var spec := _metadata(actor.animation_name)
	var denominator := float(spec.frames if bool(spec.loop) else int(spec.frames)-1)
	actor.seek(value / denominator * float(spec.duration))
	sound.seek(actor.animation_time)
	_update_status()

func start_sequence() -> void:
	sequence_playing = true
	_sequence_index = 0
	_sequence_time = 0.0
	phase = 1
	set_paused(false)
	select_animation("appear",false)

func _process(delta: float) -> void:
	if not is_instance_valid(actor): return
	if not paused:
		sound.advance(delta)
		actor.advance(delta)
		var snapshot: Dictionary = actor.get_snapshot()
		if not bool(snapshot.loop) and actor.animation_time >= float(snapshot.duration):
			_hold += delta*speed
		_sequence_time += delta*speed
		if sequence_playing:
			if (bool(snapshot.loop) and _sequence_time >= float(SEQUENCE[_sequence_index][1])) or (not bool(snapshot.loop) and _hold > .25):
				if actor.animation_name == "p2tr": phase = 2
				_sequence_index = (_sequence_index+1)%SEQUENCE.size()
				if _sequence_index == 0: phase = 1
				_sequence_time = 0.0
				select_animation(SEQUENCE[_sequence_index][0],false)
		elif _hold > .7:
			select_animation(actor.animation_name)
	frame_slider.set_value_no_signal(actor.frame_index)
	_update_status()
	queue_redraw()

func _update_status() -> void:
	if not is_instance_valid(info): return
	var snapshot: Dictionary = actor.get_snapshot()
	var index := ORDER.find(actor.animation_name)
	info.text = "%s · %d / %d · %.2f s · %.2f×" % [NAMES[index],int(snapshot.frame)+1,int(snapshot.frames),actor.animation_time,actor.playback_speed]
	status.text = "H: صناديق الإصابة  |  ← →: إطار  |  ↑ ↓: حركة  |  B: حارس الجرس  |  الغناء عند الاقتراب في تجربة القتال"
	phase_button.text = "الطور %d / 1–2" % phase
	audio_button.text = "الصوت: %s / S" % ("يعمل" if sound_enabled else "صامت")
	rage_button.modulate = GOLD if rage else Color.WHITE
	play_button.text = ("تشغيل" if paused else "إيقاف")+" / Space"

func open_trial() -> void:
	sound.stop_all()
	get_tree().change_scene_to_file(TRIAL)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: set_paused(not paused)
			KEY_1: set_phase(1)
			KEY_2: set_phase(2)
			KEY_F: actor.set_facing(-actor.facing)
			KEY_H: show_boxes = not show_boxes
			KEY_S: _toggle_sound()
			KEY_R: _toggle_rage()
			KEY_C: start_sequence()
			KEY_ENTER: open_trial()
			KEY_B: get_tree().change_scene_to_file("res://scenes/minibosses/bell_character_review_m24.tscn")
			KEY_LEFT: frame_slider.value = maxi(0,actor.frame_index-1)
			KEY_RIGHT: frame_slider.value = mini(int(frame_slider.max_value),actor.frame_index+1)
			KEY_UP: select_animation(ORDER[posmod(ORDER.find(actor.animation_name)-1,ORDER.size())])
			KEY_DOWN: select_animation(ORDER[(ORDER.find(actor.animation_name)+1)%ORDER.size()])
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_START: set_paused(not paused)
			JOY_BUTTON_A: open_trial()
			JOY_BUTTON_X: actor.set_facing(-actor.facing)
			JOY_BUTTON_Y: set_phase(3-phase)
			JOY_BUTTON_LEFT_SHOULDER: select_animation(ORDER[posmod(ORDER.find(actor.animation_name)-1,ORDER.size())])
			JOY_BUTTON_RIGHT_SHOULDER: select_animation(ORDER[(ORDER.find(actor.animation_name)+1)%ORDER.size()])

func get_review_snapshot() -> Dictionary:
	return {"native_reference":true,"actor":actor.get_snapshot(),"phase":phase,"paused":paused,"sound_enabled":sound_enabled,"rage":rage,"sequence":sequence_playing}

func _exit_tree() -> void:
	if is_instance_valid(sound): sound.stop_all()
