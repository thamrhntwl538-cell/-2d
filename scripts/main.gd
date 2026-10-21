extends Node2D

const HeroSceneScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const BossScript = preload("res://scripts/boss.gd")
const STAGE_ROOMS: Array = [
	["UNIVERSITY ENTRANCE", "07:45", "Find the abandoned programming laboratory"],
	["ABANDONED LAB", "07:55", "Collect the Debug Blade with E"],
	["CORRUPTED CODE CORRIDOR", "08:00", "Defeat every enemy to unlock the passage"],
	["THE PROGRAMMING LOCK", "08:10", "Activate INPUT → PROCESS → OUTPUT in order"],
	["THE QUIET BENCH", "08:20", "Rest and save your progress using E"],
	["LAST COMPILATION CORRIDOR", "08:35", "Defeat the guards and collect the Compiler Seal"],
	["DR. COMPILER", "08:45", "Confront the programming professor"]
]

var room: int = 0
var mode: String = "menu"
var gameplay_active: bool = false
var hero: LastLecturePlayer
var boss: LastLectureCompiler
var enemies: Array = []
var terrain_bodies: Array = []
var camera: Camera2D
var hall_texture: Texture2D
var boss_texture: Texture2D
var puzzle_step: int = 0
var completed_rooms: Dictionary = {}
var got_blade: bool = false
var seal_taken: bool = false
var seal_available: bool = false
var seal_location: Vector2 = Vector2(1380,549)
var last_kill_x: float = 1380.0
var last_checkpoint: Dictionary = {}
var next_room_tip: float = 0.0
var scene_clock: float = 0.0
var scene_line: int = -1
var intro_seen: bool = false
var rescue_sequence: Array = []
var rescue_index: int = 0
var rescue_delay: float = 0.0
var rescue_deadline: float = 0.0
var phase_timer: float = 0.0
var qte_attempted: bool = false
var projectiles: Array = []
var ground_warnings: Array = []
var bursts: Array = []
var time_accum: float = 0.0
var tip_time: float = 0.0
var sword_sfx_volume: float = -19.0
var menu_panel: ColorRect
var menu_label: Label
var menu_resume: Button
var menu_start: Button
var hud_title: Label
var hud_health: Label
var hud_equipment: Label
var hud_objective: Label
var hud_tip: Label
var boss_bar: ProgressBar
var boss_name: Label
var cinematic_panel: ColorRect
var cinematic_speaker: Label
var cinematic_line: Label
var cinematic_ar: Label
var cinematic_skip: Button
var qte_panel: ColorRect
var qte_title: Label
var qte_prompt: Label
var win_panel: ColorRect
var music_player: AudioStreamPlayer
var ambient_music: AudioStream
var boss_music_1: AudioStream
var boss_music_2: AudioStream
var music_type: String = ""
var sfxs: Dictionary = {}
var camera_focus: float = 0.0
var boss_lines: Array = [
	["Another student... another error.","طالب آخر... وخطأ جديد."],
	["You escaped the code that tried to erase you.","نجوت من الشيفرة التي حاولت محوك."],
	["Yet the compiler always has the final word.","لكن المترجم يحتفظ دائمًا بالكلمة الأخيرة."],
	["Your syntax is broken.","صياغتك البرمجية مليئة بالأخطاء."],
	["Let me correct you.","دعني أصحح أخطاءك."]
]

func _ready() -> void:
	_register_inputs()
	hall_texture = load("res://assets/backgrounds/university_hall.webp")
	boss_texture = load("res://assets/backgrounds/compiler_hall.webp")
	ambient_music = load("res://assets/audio/ambient.wav")
	boss_music_1 = load("res://assets/audio/boss_phase1.wav")
	boss_music_2 = load("res://assets/audio/boss_phase2.wav")
	sfxs = {
		"swing":load("res://assets/audio/sword_swing.mp3"),
		"hit":load("res://assets/audio/sword_hit.mp3"),
		"parry":load("res://assets/audio/parry_clang.mp3"),
		"jump":load("res://assets/audio/jump.wav"),
		"dash":load("res://assets/audio/dash.wav"),
		"pickup":load("res://assets/audio/pickup.wav"),
		"hurt":load("res://assets/audio/hurt.wav"),
		"boss_attack":load("res://assets/audio/boss_attack.wav"),
		"parry_light":load("res://assets/audio/parry_light.wav"),
		"save":load("res://assets/audio/save.wav")
	}
	camera = Camera2D.new()
	camera.position = Vector2(640,360)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 1800
	camera.limit_bottom = 720
	camera.enabled = true
	add_child(camera)
	hero = HeroSceneScript.new()
	hero.world_ref = self
	add_child(hero)
	hero.position = Vector2(110,600)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -23.0
	add_child(music_player)
	music_player.finished.connect(_music_finished)
	_build_ui()
	enter_room(0)
	set_mode("menu")

func _register_inputs() -> void:
	var binds: Dictionary = {
		"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],
		"look_up":[KEY_W,KEY_UP],"look_down":[KEY_S,KEY_DOWN],
		"jump":[KEY_SPACE],"attack":[KEY_J],"dash":[KEY_K],
		"parry":[KEY_F],"interact":[KEY_E],"spell":[KEY_L],"pause_game":[KEY_ESCAPE]
	}
	for action_name in binds.keys():
		if not InputMap.has_action(action_name):InputMap.add_action(action_name)
		for key_code in binds[action_name]:
			var ev:=InputEventKey.new()
			ev.physical_keycode=key_code
			InputMap.action_add_event(action_name,ev)

func _add_label(parent: Node, pos: Vector2, text_value: String, font_size: int=18, color: Color=Color.WHITE) -> Label:
	var label := Label.new()
	label.position = pos
	label.text = text_value
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,.94))
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.add_theme_font_size_override("font_size",font_size)
	parent.add_child(label)
	return label

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	hud_title = _add_label(ui,Vector2(22,12),"LAST LECTURE",25,Color("f4f2fd"))
	hud_health = _add_label(ui,Vector2(24,47),"♥ ♥ ♥ ♥ ♥ ♥",25,Color("ffa2b4"))
	hud_equipment = _add_label(ui,Vector2(24,85),"DEBUG BLADE —  | CODE SLASH —",15,Color("b0d8f0"))
	hud_objective = _add_label(ui,Vector2(700,23),"",18,Color("dce5f8"))
	hud_objective.custom_minimum_size=Vector2(555,70)
	hud_objective.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hud_tip = _add_label(ui,Vector2(150,614),"",20,Color("a9ebff"))
	hud_tip.custom_minimum_size=Vector2(980,65)
	hud_tip.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	boss_name = _add_label(ui,Vector2(366,44),"DR. COMPILER — THE CORRUPTED PROFESSOR",15,Color("ffb8c7"))
	boss_bar = ProgressBar.new()
	boss_bar.position=Vector2(362,73)
	boss_bar.size=Vector2(570,17)
	boss_bar.show_percentage=false
	boss_bar.max_value=42
	ui.add_child(boss_bar)
	_add_label(ui,Vector2(14,681),"A / D MOVE   SPACE JUMP   J SWORD   K DASH   F PARRY   E INTERACT   L CODE SLASH   ESC PAUSE",14,Color("a7b9cb"))
	menu_panel = ColorRect.new()
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_panel.color=Color("050915ef")
	ui.add_child(menu_panel)
	menu_label = _add_label(menu_panel,Vector2(350,130),"LAST LECTURE\nTHE PROGRAMMING WING\n\nStage 01 — A corrupted university\nSeven connected rooms, puzzles, enemies and Dr. Compiler",30,Color("e4e9ff"))
	menu_label.custom_minimum_size=Vector2(750,270)
	menu_start=Button.new()
	menu_start.text="START STAGE 1"
	menu_start.position=Vector2(474,410)
	menu_start.size=Vector2(330,57)
	menu_panel.add_child(menu_start)
	menu_start.pressed.connect(start_new_game)
	menu_resume=Button.new()
	menu_resume.text="CONTINUE SAVED GAME"
	menu_resume.position=Vector2(474,485)
	menu_resume.size=Vector2(330,51)
	menu_panel.add_child(menu_resume)
	menu_resume.pressed.connect(load_checkpoint)
	cinematic_panel=ColorRect.new()
	cinematic_panel.color=Color("080814dc")
	cinematic_panel.position=Vector2(0,510)
	cinematic_panel.size=Vector2(1280,210)
	ui.add_child(cinematic_panel)
	cinematic_speaker=_add_label(cinematic_panel,Vector2(78,18),"DR. COMPILER",21,Color("ff7597"))
	cinematic_line=_add_label(cinematic_panel,Vector2(78,70),"",27,Color("ffffff"))
	cinematic_ar=_add_label(cinematic_panel,Vector2(78,113),"",22,Color("bed9ff"))
	cinematic_skip=Button.new()
	cinematic_skip.text="SKIP INTRO (ENTER)"
	cinematic_skip.position=Vector2(1004,18)
	cinematic_skip.size=Vector2(225,43)
	cinematic_panel.add_child(cinematic_skip)
	cinematic_skip.pressed.connect(end_boss_intro)
	qte_panel=ColorRect.new()
	qte_panel.color=Color("120b1bf0")
	qte_panel.position=Vector2(220,220)
	qte_panel.size=Vector2(840,265)
	ui.add_child(qte_panel)
	qte_title=_add_label(qte_panel,Vector2(84,29),"SECOND CHANCE — فرصة ثانية",30,Color("ffa3bc"))
	qte_prompt=_add_label(qte_panel,Vector2(86,122),"",25,Color("e6f6ff"))
	win_panel=ColorRect.new()
	win_panel.color=Color("061722ed")
	win_panel.position=Vector2(258,170)
	win_panel.size=Vector2(770,335)
	ui.add_child(win_panel)
	_add_label(win_panel,Vector2(65,48),"DR. COMPILER DEFEATED",34,Color("aafde5"))
	_add_label(win_panel,Vector2(65,109),"CODE SLASH UNLOCKED  [L]",24,Color("aeeaff"))
	_add_label(win_panel,Vector2(65,160),"Stage 1 complete — ready for Data Structures.",21,Color("e6e9f1"))
	_add_label(win_panel,Vector2(65,214),"تم إنهاء الفصل الأول — البرمجة",21,Color("c3d7fb"))
	var retry := Button.new()
	retry.text="PLAY STAGE 1 AGAIN"
	retry.position=Vector2(244,274)
	retry.size=Vector2(270,40)
	win_panel.add_child(retry)
	retry.pressed.connect(start_new_game)

func set_mode(new_mode: String) -> void:
	mode=new_mode
	gameplay_active = mode=="play"
	if menu_panel!=null:
		menu_panel.visible=mode=="menu" or mode=="pause"
		menu_label.text="LAST LECTURE\nTHE PROGRAMMING WING\n\nPress START to play Stage 1" if mode=="menu" else "PAUSED\n\nPress ESC again to resume"
		menu_start.visible=mode=="menu"
		menu_resume.visible=mode=="menu"
	if cinematic_panel!=null:cinematic_panel.visible=mode=="intro"
	if qte_panel!=null:qte_panel.visible=mode=="revive"
	if win_panel!=null:win_panel.visible=mode=="win"
	if boss_bar!=null:boss_bar.visible=room==6 and boss!=null and boss.alive and mode not in ["menu","win"]

func start_new_game() -> void:
	completed_rooms.clear()
	last_checkpoint.clear()
	got_blade=false
	seal_taken=false
	seal_available=false
	puzzle_step=0
	intro_seen=false
	qte_attempted=false
	hero.hp=6
	hero.energy=100
	hero.has_blade=false
	hero.has_code_slash=false
	hero.credits=0
	enter_room(0)
	set_mode("play")
	play_music("ambient")
	show_tip("Find the Debug Blade — explore the programming wing")

func enter_room(next_room: int) -> void:
	room=clampi(next_room,0,6)
	for e in enemies:
		if is_instance_valid(e):e.queue_free()
	enemies.clear()
	if boss!=null and is_instance_valid(boss):boss.queue_free()
	boss=null
	for body in terrain_bodies:
		if is_instance_valid(body):body.queue_free()
	terrain_bodies.clear()
	projectiles.clear()
	ground_warnings.clear()
	bursts.clear()
	seal_available=false
	seal_taken=bool(completed_rooms.get("seal",false)) if room==5 else false
	if room==5 and completed_rooms.get("5",false) and not seal_taken:
		seal_available=true
		seal_location=Vector2(float(completed_rooms.get("seal_x",1480)),550)
	if room==3:puzzle_step=int(completed_rooms.get("puzzle",0))
	_build_floor()
	if room==2 and not completed_rooms.get("2",false):
		_spawn_enemy("bug",355,600)
		_spawn_enemy("wraith",765,495)
		_spawn_enemy("ta",1230,600)
	if room==5 and not completed_rooms.get("5",false):
		_spawn_enemy("bug",350,600)
		_spawn_enemy("wraith",720,497)
		_spawn_enemy("turret",1120,600)
		_spawn_enemy("ta",1320,600)
	if room==6 and not completed_rooms.get("boss",false):
		boss=BossScript.new()
		add_child(boss)
		boss.setup(self)
	hero.position=Vector2(100,600)
	hero.velocity=Vector2.ZERO
	hero.invulnerable=1.1
	camera.position=Vector2(640,360)
	if room==6 and boss!=null and not intro_seen:
		start_boss_intro()
	else:
		if mode!="menu":set_mode("play")
	if mode!="menu":show_tip(str(STAGE_ROOMS[room][0]))
	_update_hud()
	queue_redraw()

func _build_floor() -> void:
	_build_solid(Rect2(0,600,1800,120))
	if room in [1,2,5]:
		_build_solid(Rect2(320,515,220,17))
		_build_solid(Rect2(850,474,220,17))

func _build_solid(rect: Rect2) -> void:
	var body:=StaticBody2D.new()
	body.collision_layer=1
	body.collision_mask=0
	var shape:=CollisionShape2D.new()
	var collision:=RectangleShape2D.new()
	collision.size=rect.size
	shape.shape=collision
	shape.position=rect.position+rect.size/2
	body.add_child(shape)
	add_child(body)
	terrain_bodies.append(body)

func _spawn_enemy(kind: String, x: float, y: float) -> void:
	var enemy=EnemyScript.new()
	add_child(enemy)
	enemy.setup(kind,Vector2(x,y),self)
	enemies.append(enemy)

func _process(delta: float) -> void:
	time_accum+=delta
	if tip_time>0.0:
		tip_time-=delta
		if tip_time<=0.0:hud_tip.text=""
	if mode=="intro":
		scene_clock+=delta
		var next_line: int=mini(int(maxf(0.0,scene_clock-1.2)/2.1),boss_lines.size()-1)
		if next_line!=scene_line:
			scene_line=next_line
			cinematic_line.text=str(boss_lines[next_line][0])
			cinematic_ar.text=str(boss_lines[next_line][1])
		if scene_clock>12.5:end_boss_intro()
	if mode=="revive":
		rescue_delay=maxf(0.0,rescue_delay-delta)
		if rescue_delay>0.0:
			qte_prompt.text="Get ready... %.1f" % rescue_delay
		else:
			rescue_deadline-=delta
			qte_prompt.text="PRESS  %s  —  %d / 6  (%.1f sec)" % [rescue_sequence[rescue_index],rescue_index+1,rescue_deadline]
			if rescue_deadline<=0:fail_rescue()
	if mode=="transform":
		phase_timer-=delta
		if phase_timer<=0:
			if boss!=null:boss.transformation=0.0
			set_mode("play")
	if mode=="play":
		_update_simulation(delta)
		if Input.is_action_just_pressed("interact"):_interact()
		var blocked:bool=not _can_leave_room()
		if hero.position.x>1722 and blocked:
			hero.position.x=1722
			hero.velocity.x=0
			next_room_tip-=delta
			if next_room_tip<=0:
				show_tip("GATE LOCKED — complete this room first")
				next_room_tip=2.2
		elif hero.position.x>1770 and not blocked:
			if room==6:
				set_mode("win")
			else:
				enter_room(room+1)
	_update_hud()
	var target_cam:float=hero.position.x+195.0
	if mode=="intro" and boss!=null:target_cam=1220
	camera.position=Vector2(lerpf(camera.position.x,clampf(target_cam,640,1160),minf(1.0,delta*3)),360)
	queue_redraw()

func _can_leave_room() -> bool:
	match room:
		1:return hero.has_blade
		2:return bool(completed_rooms.get("2",false))
		3:return puzzle_step==3
		5:return bool(completed_rooms.get("5",false)) and seal_taken
		6:return bool(completed_rooms.get("boss",false))
	return true

func _update_simulation(delta: float) -> void:
	for p in projectiles:
		var ppos: Vector2=p["pos"]
		ppos += p["velocity"]*delta
		p["pos"]=ppos
		p["lifetime"]-=delta
		var hit_rect:=Rect2(ppos-Vector2(10,10),Vector2(20,20))
		if p["type"]=="own":
			for e in enemies:
				if is_instance_valid(e) and not e.is_dead and hit_rect.intersects(e.get_hitbox()):
					e.take_hit(int(p["damage"]),hero.position.x)
					p["lifetime"]=0.0
			if boss!=null and boss.alive and hit_rect.intersects(boss.get_hitbox()):
				boss.take_hit(int(p["damage"]))
				p["lifetime"]=0.0
		elif hit_rect.intersects(hero_hitbox()):
			hero.hurt(int(p["damage"]),ppos.x)
			p["lifetime"]=0.0
	projectiles=projectiles.filter(func(p):return p["lifetime"]>0.0 and p["pos"].x>-80.0 and p["pos"].x<1950.0 and p["pos"].y<820)
	for a in ground_warnings:
		a["timer"]-=delta
		if a["timer"]<=0 and not a["fired"]:
			a["fired"]=true
			if absf(hero.position.x-a["x"])<a["width"]/2 and hero.position.y>480:
				hero.hurt(1,a["x"])
			emit_burst(Vector2(a["x"],585),Color("ff627c"),26)
	ground_warnings=ground_warnings.filter(func(a):return a["timer"]>-.35)
	for b in bursts:
		var bpos: Vector2 = b["position"]
		var bvel: Vector2 = b["velocity"]
		bpos += bvel*delta
		bvel.y += 420.0*delta
		b["position"] = bpos
		b["velocity"] = bvel
		b["time"]-=delta
	bursts=bursts.filter(func(b):return b["time"]>0.0)

func _interact() -> void:
	if room==1 and not hero.has_blade and absf(hero.position.x-510)<105:
		hero.has_blade=true
		got_blade=true
		play_sfx("pickup")
		emit_burst(Vector2(510,502),Color("89efff"),30)
		show_tip("DEBUG BLADE ACQUIRED — press J to attack")
		return
	if room==3:
		var locs: Array=[420,820,1190]
		for idx in range(3):
			if absf(hero.position.x-float(locs[idx]))<110:
				if idx==puzzle_step:
					puzzle_step+=1
					completed_rooms["puzzle"]=puzzle_step
					play_sfx("pickup")
					show_tip(["INPUT ✓","PROCESS ✓","OUTPUT ✓ — ACCESS GRANTED"][idx])
				else:
					puzzle_step=0
					completed_rooms["puzzle"]=0
					hero.hurt(1,hero.position.x+50)
					show_tip("SYNTAX ERROR — restart the sequence")
				return
	if room in [4,5]:
		var bench_x:float=720.0 if room==4 else 1610.0
		if absf(hero.position.x-bench_x)<115:
			save_checkpoint()
			return
	if room==5 and seal_available and not seal_taken and absf(hero.position.x-seal_location.x)<110:
		seal_taken=true
		completed_rooms["seal"]=true
		play_sfx("pickup")
		show_tip("COMPILER SEAL COLLECTED — the boss gate is open")

func hero_hitbox() -> Rect2:
	return Rect2(hero.position-Vector2(16,57),Vector2(32,57))

func hero_strike(direction: String, facing: int) -> void:
	var rect: Rect2
	if direction=="up":
		rect=Rect2(hero.position+Vector2(-40,-133),Vector2(80,92))
	elif direction=="down":
		rect=Rect2(hero.position+Vector2(-38,-2),Vector2(77,75))
	else:
		rect=Rect2(hero.position+Vector2(0 if facing>0 else -111,-84),Vector2(111,82))
	var hit: bool=false
	for e in enemies:
		if is_instance_valid(e) and not e.is_dead and rect.intersects(e.get_hitbox()):
			e.take_hit(2,hero.position.x)
			hit=true
	if boss!=null and boss.alive and rect.intersects(boss.get_hitbox()):
		boss.take_hit(2)
		hit=true
	if hit:
		play_sfx("hit")
		if direction=="down":hero.velocity.y=-460.0
		emit_burst(hero.position+Vector2(facing*45,-35),Color("b8f3ff"),10)

func cast_code_slash(pos: Vector2, dir: int) -> void:
	if room!=6:return
	spawn_projectile(pos,Vector2(float(dir)*670,0),"own",3)

func enemy_melee(center: Vector2, radius: float, damage: int) -> void:
	if hero.position.distance_to(center)<radius:
		hero.hurt(damage,center.x)

func on_enemy_defeated(enemy: LastLectureEnemy) -> void:
	hero.credits+=30
	last_kill_x=enemy.position.x
	var left:int=0
	for e in enemies:
		if is_instance_valid(e) and not e.is_dead:left+=1
	if left==0:
		completed_rooms[str(room)]=true
		if room==5:
			seal_available=true
			seal_location=Vector2(clampf(last_kill_x,220,1590),550)
			completed_rooms["seal_x"]=seal_location.x
			show_tip("ALL ENEMIES DEFEATED — pick up the glowing Compiler Seal with E")
		else:
			show_tip("AREA CLEARED — forward gate opened")

func spawn_projectile(pos: Vector2, speed: Vector2, kind: String, damage: int) -> void:
	projectiles.append({"pos":pos,"velocity":speed,"type":kind,"damage":damage,"lifetime":3.6})

func spawn_ground_warning(x: float, width: float, delay_time: float) -> void:
	ground_warnings.append({"x":clampf(x,140,1660),"width":width,"timer":delay_time,"fired":false})

func emit_burst(pos: Vector2, color: Color, amount: int) -> void:
	for i in range(amount):
		bursts.append({"position":pos,"velocity":Vector2(randf_range(-210,210),randf_range(-350,30)),"color":color,"time":randf_range(.18,.52)})

func on_parry(from_x: float) -> void:
	play_sfx("parry")
	emit_burst(hero.position+Vector2((1 if from_x>hero.position.x else -1)*40,-37),Color("b4faff"),35)
	if boss!=null:boss.hit_stagger=.75
	hero.energy=minf(hero.energy+18,100)
	show_tip("PERFECT PARRY! — رد مثالي")

func on_perfect_dodge() -> void:
	play_sfx("dash")
	show_tip("PERFECT DODGE! — تفادي مثالي")

func player_fell() -> void:
	hero.position=Vector2(maxf(90,hero.position.x-160),385)
	hero.velocity=Vector2.ZERO
	hero.hurt(1,hero.position.x+40)

func on_player_death() -> void:
	if room==6 and boss!=null and boss.alive and not boss.has_used_second_chance:
		boss.has_used_second_chance=true
		rescue_sequence=[]
		var letters: Array=["A","S","D","J","K","L"]
		for i in range(6):rescue_sequence.append(letters.pick_random())
		rescue_index=0
		rescue_delay=3.0
		rescue_deadline=1.35
		set_mode("revive")
		return
	show_tip("You have fallen — returning to last checkpoint")
	respawn_checkpoint()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):return
	if not event.pressed or event.echo:return
	if mode=="intro" and event.keycode==KEY_ENTER:
		end_boss_intro()
		get_viewport().set_input_as_handled()
	elif mode=="revive" and rescue_delay<=0.0:
		var mapping: Dictionary={KEY_A:"A",KEY_S:"S",KEY_D:"D",KEY_J:"J",KEY_K:"K",KEY_L:"L"}
		var key_str: String=mapping.get(event.keycode,"")
		if key_str==rescue_sequence[rescue_index]:
			rescue_index+=1
			rescue_deadline=1.35
			if rescue_index>=6:rescue_success()
		elif key_str!="":fail_rescue()
		get_viewport().set_input_as_handled()
	elif event.keycode==KEY_ESCAPE:
		if mode=="play":set_mode("pause")
		elif mode=="pause":set_mode("play")
		get_viewport().set_input_as_handled()

func rescue_success() -> void:
	hero.hp=3
	hero.energy=100
	hero.invulnerable=2.2
	projectiles.clear()
	ground_warnings.clear()
	set_mode("play")
	show_tip("SECOND CHANCE! — back with three hearts; boss HP unchanged")
	play_sfx("pickup")

func fail_rescue() -> void:
	show_tip("Second Chance failed — respawning")
	respawn_checkpoint()

func start_boss_intro() -> void:
	intro_seen=true
	scene_clock=0
	scene_line=-1
	set_mode("intro")
	if boss!=null:boss.frozen=true
	change_boss_music(0)

func end_boss_intro() -> void:
	if mode!="intro":return
	set_mode("play")
	hero.position=Vector2(820,600)
	hero.velocity=Vector2.ZERO
	hero.invulnerable=1.3
	if boss!=null:
		boss.frozen=false
		boss.attack_timer=0.7
	change_boss_music(1)
	show_tip("BOSS FIGHT — DR. COMPILER")

func start_boss_transformation() -> void:
	phase_timer=2.8
	set_mode("transform")
	show_tip("PHASE 2 — INFINITE LOOP. The compiler is unstable!")
	play_sfx("boss_attack")

func on_boss_defeated() -> void:
	completed_rooms["boss"]=true
	hero.has_code_slash=true
	hero.credits+=250
	hero.energy=100
	projectiles.clear()
	ground_warnings.clear()
	play_sfx("pickup")
	set_mode("win")
	play_music("ambient")
	show_tip("DR. COMPILER DEFEATED — CODE SLASH UNLOCKED")

func show_tip(msg: String) -> void:
	hud_tip.text=msg
	tip_time=3.3

func _update_hud() -> void:
	hud_title.text="LAST LECTURE  ·  %s  ·  %s" % [STAGE_ROOMS[room][0],STAGE_ROOMS[room][1]]
	hud_health.text="♥ ".repeat(hero.hp)+"♡ ".repeat(hero.max_hp-hero.hp)
	hud_equipment.text="Credits %d  •  Debug Blade %s  •  Code Slash [L] %s  •  Energy %d%%" % [hero.credits,"✓" if hero.has_blade else "—","✓" if hero.has_code_slash else "—",int(hero.energy)]
	hud_objective.text="STAGE 1 / 3 — PROGRAMMING\n%s" % STAGE_ROOMS[room][2]
	if boss!=null and boss.alive:
		boss_bar.value=boss.hp
		boss_name.text="DR. COMPILER  |  %s  |  %s" % ["INFINITE LOOP" if boss.phase==2 else "INITIAL COMPILE",boss.warning_attack]
	boss_bar.visible=room==6 and boss!=null and boss.alive and mode not in ["menu","win"]

func save_checkpoint() -> void:
	hero.hp=hero.max_hp
	hero.energy=100
	last_checkpoint={"room":room,"x":hero.position.x,"has_blade":hero.has_blade,"credits":hero.credits,"completed":completed_rooms.duplicate(true),"puzzle_step":puzzle_step,"seal_taken":seal_taken}
	var file:=FileAccess.open("user://lastlecture_stage1_save.json",FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(last_checkpoint))
	play_sfx("save")
	show_tip("CHECKPOINT SAVED — health restored")

func load_checkpoint() -> void:
	if not FileAccess.file_exists("user://lastlecture_stage1_save.json"):
		start_new_game()
		return
	var raw:String=FileAccess.get_file_as_string("user://lastlecture_stage1_save.json")
	var data:Variant=JSON.parse_string(raw)
	if typeof(data)!=TYPE_DICTIONARY:
		start_new_game()
		return
	last_checkpoint=data
	_restore_save()

func respawn_checkpoint() -> void:
	if last_checkpoint.is_empty():
		if FileAccess.file_exists("user://lastlecture_stage1_save.json"):
			load_checkpoint()
		else:
			hero.hp=6
			enter_room(0)
			set_mode("play")
	else:_restore_save()

func _restore_save() -> void:
	var d:Dictionary=last_checkpoint
	completed_rooms=d.get("completed",{}).duplicate(true)
	puzzle_step=int(d.get("puzzle_step",0))
	got_blade=bool(d.get("has_blade",false))
	seal_taken=bool(d.get("seal_taken",false))
	hero.has_blade=got_blade
	hero.has_code_slash=false
	hero.hp=6
	hero.credits=int(d.get("credits",0))
	enter_room(int(d.get("room",0)))
	hero.position=Vector2(float(d.get("x",100)),600)
	set_mode("play")
	play_music("ambient")
	show_tip("CHECKPOINT RESTORED")

func change_boss_music(phase: int) -> void:
	play_music("ambient" if phase==0 else "boss1" if phase==1 else "boss2")

func play_music(kind: String) -> void:
	if music_type==kind and music_player.playing:return
	music_type=kind
	music_player.stop()
	music_player.stream=ambient_music if kind=="ambient" else boss_music_1 if kind=="boss1" else boss_music_2
	music_player.volume_db=-26.0 if kind=="ambient" else -22.0
	music_player.play()

func _music_finished() -> void:
	if music_type!="" and mode!="menu":music_player.play()

func play_sfx(name: String) -> void:
	var snd:AudioStream=sfxs.get(name,null)
	if snd==null:return
	var speaker:=AudioStreamPlayer.new()
	speaker.stream=snd
	speaker.volume_db=sword_sfx_volume if name in ["hit","swing","parry"] else -17.0
	speaker.pitch_scale=randf_range(.95,1.05)
	add_child(speaker)
	speaker.finished.connect(speaker.queue_free)
	speaker.play()

func _draw() -> void:
	var texture: Texture2D=boss_texture if room==6 else hall_texture
	if texture!=null:draw_texture_rect(texture,Rect2(0,-110,1800,850),false)
	draw_rect(Rect2(0,0,1800,720),Color("06101a30"))
	# Foreground and physical ground match the collider at y=600.
	draw_rect(Rect2(0,600,1800,120),Color("07151ff0"))
	draw_rect(Rect2(0,598,1800,8),Color("6f8a9f"))
	for i in range(16):
		draw_rect(Rect2(i*130,642,79,4),Color("214057"))
		draw_rect(Rect2(i*130+39,675,4,45),Color("243c53"))
	if room in [1,2,5]:
		for rect in [Rect2(320,515,220,17),Rect2(850,474,220,17)]:
			draw_rect(rect,Color("32475c"))
			draw_rect(Rect2(rect.position,Vector2(rect.size.x,4)),Color("8aa6bd"))
	for i in range(7):
		var x:float=float(i)*274+56
		draw_rect(Rect2(x,225,12,372),Color("06131d99"))
		draw_rect(Rect2(x-22,218,56,7),Color("284056bb"))
	if room==0:
		_draw_caption(Vector2(440,420),"UNIVERSITY ENTRANCE",Color("e4edff"),26)
		_draw_caption(Vector2(400,468),"ERROR 404: EXIT NOT FOUND",Color("ff8da8"),18)
	if room==1 and not hero.has_blade:
		draw_line(Vector2(510,501),Vector2(510,422),Color("a4faff"),11)
		draw_circle(Vector2(510,422),12,Color("b8f8ff"))
		_draw_caption(Vector2(432,408),"E — DEBUG BLADE",Color("bcf5ff"),20)
	if room==3:
		var labels: Array=["INPUT","PROCESS","OUTPUT"]
		for i in range(3):
			var x:float=float([420,820,1190][i])
			var col:Color=Color("1a686a") if i<puzzle_step else Color("20384f")
			draw_rect(Rect2(x-77,475,155,123),col)
			draw_rect(Rect2(x-66,487,132,58),Color("49bbbb") if i<puzzle_step else Color("45627c"))
			_draw_caption(Vector2(x-51,527),labels[i],Color("ebf6ff"),20)
			_draw_caption(Vector2(x-7,579),"E",Color("bdeeff"),19)
		_draw_caption(Vector2(1440,485),"ACCESS GRANTED" if puzzle_step==3 else "SEQUENCE REQUIRED",Color("80f0ff") if puzzle_step==3 else Color("ffb7be"),17)
	if room in [4,5]:
		var x:float=720 if room==4 else 1610
		draw_rect(Rect2(x-85,547,170,28),Color("566e8b"))
		draw_rect(Rect2(x-66,523,132,26),Color("283e56"))
		_draw_caption(Vector2(x-74,510),"E — REST / SAVE",Color("bbf7ff"),17)
	if room==5 and seal_available and not seal_taken:
		var bob:float=sin(time_accum*4.0)*7.0
		var p:Vector2=seal_location+Vector2(0,bob)
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-26),p+Vector2(21,0),p+Vector2(0,26),p+Vector2(-21,0)]),Color("ac85e5"))
		_draw_caption(p+Vector2(-94,-47),"E — COMPILER SEAL",Color("e3c6ff"),18)
	if room==6:
		_draw_caption(Vector2(930,280),"LECTURE HALL 1 — DR. COMPILER",Color("f3c9e0"),24)
	if not _can_leave_room():
		draw_rect(Rect2(1732,360,24,238),Color("8a3c88b8"))
		for j in range(5):draw_circle(Vector2(1744,380+j*44),9,Color("f98ab4"))
	else:
		draw_rect(Rect2(1735,412,14,185),Color("27868b66"))
		_draw_caption(Vector2(1617,383),"EXIT →",Color("b1f6ed"),17)
	for p in projectiles:
		var col:Color=Color("77efff") if p["type"]=="own" else Color("ff739f")
		draw_circle(p["pos"],9,col)
		draw_arc(p["pos"],13,0,TAU,18,col.darkened(.35),2)
	for a in ground_warnings:
		var danger:bool=a["timer"]<=0
		draw_rect(Rect2(a["x"]-a["width"]/2,588,a["width"],10),Color("ff3b52") if danger else Color("d9688288"))
	for b in bursts:
		draw_circle(b["position"],3,b["color"])

func _draw_caption(pos: Vector2, text_value: String, col: Color, size: int=19) -> void:
	var font:Font=ThemeDB.fallback_font
	if font!=null:draw_string(font,pos,text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,col)
