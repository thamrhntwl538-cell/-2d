extends CharacterBody2D
## Dr. Compiler / Execution Chancellor. One learned pattern at a time, clear
## captured targets, a planted floor anchor, and finite counterattack windows.
const Attack = preload("res://scripts/bosses/m23_boss_attack.gd")
const VISUAL_PATH := "res://scripts/bosses/m23_compiler_visual.gd"
const PHASE_THRESHOLD := 24
const BOLT_WARNING := .82
const SWEEP_WARNING := .78
const PILLAR_WARNING := .95
const CHAIN_WARNING := .90
const PHASE_TRANSITION_SECONDS := 2.0
const FACING_DEADZONE := 12.0
const FACING_TRACK_STATES := ["dormant","intro","idle","recover"]
var world_ref: Node
var hp := 48
var max_hp := 48
var damage := 1
var phase := 1
var is_dead := false
var alive := true
var activated := false
var state := "intro"
var current_pattern := ""
var direction := -1
var age := 0.0
var state_time := 1.20
var state_duration := 1.20
var invulnerable := 0.0
var hit_flash := 0.0
var attack_id := 0
var pattern_index := 0
var shots_fired := 0
var total_shots := 0
var warning_fraction := 0.0
var warning_text_ar := ""
var warning_text_en := ""
var warning_progress: float:
	get: return warning_fraction
var warning_ar: String:
	get: return warning_text_ar
var warning_en: String:
	get: return warning_text_en
var arena := Rect2(1320,940,1500,500)
var floor_y := 1440.0
var home_position := Vector2.ZERO
var captured_target := Vector2.ZERO
var pillar_targets: Array[float] = []
var aim := Vector2.LEFT
var attack_nodes: Array[Node2D] = []
var visual: Node2D
var combat_overlay: Node2D
var _configured := false
var _defeat_notified := false
var _phase_changed := false
var _dash_start := Vector2.ZERO
var _dash_finish := Vector2.ZERO
var _dash_elapsed := 0.0
var _warning_total := 0.0
var _pattern_history: Array[String] = []
var _burst_complete := false
var death_visual_time := 0.0
var _voice_cooldown := 0.0
var _voice_variant := 0
var _phase_resonance_remaining := -1.0
var _danger_light: Texture2D

class CombatOverlay extends Node2D:
	var actor: Node2D
	func _process(_delta: float) -> void: queue_redraw()
	func _draw() -> void:
		if is_instance_valid(actor): actor.draw_combat_fx(self)

func setup(world: Node, spawn: Vector2, battle_rect: Rect2 = Rect2(1320,940,1500,500)) -> void:
	world_ref = world
	position = spawn
	home_position = spawn
	floor_y = spawn.y
	arena = battle_rect
	_configured = true
	_enter("dormant",0)
	queue_redraw()

func start_encounter() -> void:
	if activated or is_dead: return
	activated = true
	_enter("intro",1.20)
	_play_voice("compiler_voice_intro",true)

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	z_index = 5
	# Combat warnings keep their authored contrast in the dark arena. The
	# separate painted body rig remains under the arena's actual lighting.
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unlit
	_danger_light = _make_danger_light()
	add_to_group("m18_enemies")
	add_to_group("m23_compiler")
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(110,245)
	collision.shape = shape
	collision.position = Vector2(0,-122.5)
	collision.name = "CompilerRigidCore"
	add_child(collision)
	install_visual()
	combat_overlay = CombatOverlay.new()
	combat_overlay.actor = self
	combat_overlay.name = "CompilerVisibleDangerField"
	combat_overlay.z_index = 12
	combat_overlay.material = unlit
	combat_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(combat_overlay)

func _make_danger_light() -> Texture2D:
	# A native soft light wash, not an edited art asset. Every texel retains a
	# faint alpha so the complete collision field remains visible; the raised
	# elliptical interior removes the appearance of a flat debug rectangle.
	var image := Image.create(128,32,false,Image.FORMAT_RGBA8)
	for y in range(32):
		var v := float(y)/31.0
		for x in range(128):
			var u := float(x)/127.0
			var curve := pow(maxf(0.0,sin(v*PI)),1.45)*pow(maxf(0.0,sin(u*PI)),.65)
			image.set_pixel(x,y,Color(.20,.63,.82,.024+.13*curve))
	return ImageTexture.create_from_image(image)

func install_visual() -> void:
	if is_instance_valid(visual) or not ResourceLoader.exists(VISUAL_PATH): return
	var script: Script = load(VISUAL_PATH)
	visual = script.new()
	add_child(visual)
	if visual.has_method("setup"): visual.setup(self)
	if visual.has_method("set_external_blade"): visual.set_external_blade(true)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not _configured or not is_instance_valid(world_ref): return
	if not bool(world_ref.get("gameplay_active")): return
	if is_dead: return
	age += delta
	invulnerable = maxf(0,invulnerable-delta)
	hit_flash = maxf(0,hit_flash-delta)
	_voice_cooldown = maxf(0,_voice_cooldown-delta)
	if _phase_resonance_remaining>=0.0:
		_phase_resonance_remaining -= delta
		if _phase_resonance_remaining<=0.0:
			_phase_resonance_remaining = -1.0
			_play("compiler_phase")
	_face_hero_when_safe()
	if not activated:
		_update_visual()
		return
	if not _arena_visible() or not _battle_enabled():
		if state not in ["intro","idle","recover","phase_transition"]: cancel_for_pause()
		return
	state_time = maxf(0,state_time-delta)
	warning_fraction = clampf(1.0-state_time/maxf(.01,_warning_total),0,1) if state.ends_with("_warning") else 0.0
	match state:
		"intro":
			if state_time <= 0: _enter("idle",.38)
		"idle":
			if state_time <= 0: _begin_next_pattern()
		"bolts_warning":
			if state_time <= 0:
				shots_fired = 0
				_burst_complete = false
				_enter("bolts_active",0)
		"bolts_active":
			if state_time <= 0:
				if _burst_complete:
					_recover(.78 if phase==1 else .55)
				else:
					_fire_bolt()
					shots_fired += 1
					if shots_fired >= (4 if phase==2 else 3):
						_burst_complete = true
						var muzzle := global_position+Vector2(float(direction)*45,-205)
						state_time = clampf(captured_target.distance_to(muzzle)/(525.0 if phase==2 else 460.0)+.2,.45,2.45)
					else: state_time = .25 if phase==2 else .30
		"sweep_warning":
			if state_time <= 0:
				_dash_start = global_position
				_dash_finish = Vector2(clampf(global_position.x+float(direction)*240,arena.position.x+90,arena.end.x-90),floor_y)
				_dash_elapsed = 0
				damage = 2
				_enter("sweep_active",.28)
				_play("compiler_release")
		"sweep_active":
			_dash_elapsed = minf(.28,_dash_elapsed+delta)
			global_position = _dash_start.lerp(_dash_finish,_dash_elapsed/.28)
			if state_time <= 0: _recover(.92 if phase==1 else .58)
		"pillars_warning":
			if state_time <= 0: _enter("pillars_active",.48)
		"pillars_active":
			if state_time <= 0: _recover(1.0 if phase==1 else .58)
		"chains_warning":
			if state_time <= 0:
				_spawn_chain(Vector2(arena.position.x+10,floor_y-24),Vector2(370,0))
				_spawn_chain(Vector2(arena.end.x-10,floor_y-24),Vector2(-370,0))
				_enter("chains_active",2.10)
				_play("compiler_release")
		"chains_active":
			if state_time <= 0: _recover(.60)
		"recover","stagger":
			if state_time <= 0: _enter("idle",.16 if phase==2 else .25)
		"phase_transition":
			if state_time <= 0: _enter("idle",.30)
	global_position.y = floor_y
	velocity = Vector2.ZERO
	_update_visual()
	queue_redraw()

func _process(delta: float) -> void:
	if not is_dead: return
	# Defeat presentation continues while the world suspends combat for its
	# victory panel. No attack timer or receiving volume survives this path.
	death_visual_time = minf(1.15,death_visual_time+delta)
	var progress := death_visual_time/1.15
	self_modulate.a = 1.0-progress
	if is_instance_valid(visual) and visual.has_method("update_pose"):
		visual.modulate = Color.WHITE
		visual.update_pose("dead",age+death_visual_time,progress,0)

func _battle_enabled() -> bool:
	if not activated: return false
	var active: Variant = world_ref.get("boss_active")
	if active is bool and not active: return false
	var hero := world_ref.get("hero") as Node2D
	return is_instance_valid(hero) and hero.global_position.x>=arena.position.x-70 and hero.global_position.x<=arena.end.x+70

func _face_hero_when_safe() -> void:
	# The side-view rig faces its opponent between actions. Warning, active
	# and stagger states keep the direction captured for the entire attack;
	# neither an old projectile origin nor the execution field can flip.
	if state not in FACING_TRACK_STATES: return
	_capture_hero_direction()

func _capture_hero_direction() -> void:
	var hero := world_ref.get("hero") as Node2D
	if not is_instance_valid(hero): return
	var offset := hero.global_position.x-global_position.x
	if absf(offset)>FACING_DEADZONE:
		direction = 1 if offset>0 else -1

func _arena_visible() -> bool:
	if not is_inside_tree(): return false
	var point := get_global_transform_with_canvas()*Vector2(0,-150)
	return get_viewport_rect().grow(-12).has_point(point)

func attacks_allowed() -> bool:
	return not is_dead and _configured and is_instance_valid(world_ref) and bool(world_ref.get("gameplay_active")) and _battle_enabled() and _arena_visible() and state not in ["intro","phase_transition"]

func _begin_next_pattern() -> void:
	var hero := world_ref.get("hero") as Node2D
	if not is_instance_valid(hero): _enter("idle",.30); return
	# A new warning may not hide a lingering old projectile behind it. The
	# burst state first allows the final shot to pass its captured old target.
	clear_attacks()
	var order := ["bolts","sweep","pillars"] if phase==1 else ["bolts","sweep","pillars","chains","sweep","pillars"]
	current_pattern = order[pattern_index%order.size()]
	pattern_index += 1
	_pattern_history.append(current_pattern)
	attack_id += 1
	captured_target = hero.global_position+Vector2(0,-45)
	direction = 1 if captured_target.x>global_position.x else -1
	match current_pattern:
		"bolts":
			aim = (captured_target-(global_position+Vector2(float(direction)*45,-205))).normalized()
			_warn("bolts_warning",BOLT_WARNING,"شيفرة قادمة — غيّر موضعك","INCOMING CODE — change position")
		"sweep":
			_warn("sweep_warning",SWEEP_WARNING,"ضربة تنفيذ — اقفز أو ابتعد عن النصل","EXECUTION — jump or clear the blade")
		"pillars":
			pillar_targets.clear()
			for offset in [-235.0,0.0,235.0]:
				var x := clampf(captured_target.x+offset,arena.position.x+65,arena.end.x-65)
				var duplicate := false
				for old in pillar_targets:
					if absf(old-x)<80: duplicate = true
				if not duplicate: pillar_targets.append(x)
			_warn("pillars_warning",PILLAR_WARNING,"أعمدة التجميع — اخرج من العلامات","COMPILE PILLARS — leave the marked ground")
			for x in pillar_targets:
				_spawn_attack("pillar",Vector2(x,floor_y),{"warning":PILLAR_WARNING,"duration":.48,"width":74.0,"height":330.0,"damage":1})
		"chains":
			_warn("chains_warning",CHAIN_WARNING,"سلاسل التحليل — اقفز فوق السلاسل المنخفضة","PARSE CHAINS — jump the low chains")

func _warn(next: String, seconds: float, arabic: String, english: String) -> void:
	_enter(next,seconds)
	_warning_total = seconds
	warning_fraction = 0
	warning_text_ar = arabic
	warning_text_en = english
	_play("compiler_sweep" if current_pattern=="chains" else "compiler_"+current_pattern)
	if _play_voice("compiler_voice_attack_"+str(_voice_variant%3+1)):
		_voice_variant += 1
	if world_ref.has_method("compiler_telegraph"): world_ref.compiler_telegraph(current_pattern,arabic,english)

func _enter(next: String, seconds: float) -> void:
	state = next
	state_time = seconds
	state_duration = seconds
	if not next.ends_with("_warning"):
		warning_text_ar = ""
		warning_text_en = ""
		warning_fraction = 0
	if next != "sweep_active": damage = 1

func _recover(seconds: float) -> void:
	_enter("recover",seconds)

func _fire_bolt() -> void:
	var spread: float = [-.05,0.0,.05,-.025][shots_fired]
	var origin := global_position+Vector2(float(direction)*45,-205)
	_spawn_attack("bolt",origin,{"velocity":aim.rotated(spread)*(525.0 if phase==2 else 460.0),"duration":3.4,"damage":1})
	total_shots += 1
	_play("compiler_release")

func _spawn_chain(origin: Vector2, speed: Vector2) -> void:
	_spawn_attack("chain",origin,{"velocity":speed,"duration":2.05,"width":68.0,"height":18.0,"damage":1})

func _spawn_attack(kind: String, origin: Vector2, options: Dictionary) -> Node2D:
	for index in range(attack_nodes.size()-1,-1,-1):
		if not is_instance_valid(attack_nodes[index]): attack_nodes.remove_at(index)
	var node := Attack.new()
	get_parent().add_child(node)
	node.setup(world_ref,self,kind,origin,options)
	attack_nodes.append(node)
	return node

func clear_attacks() -> void:
	for node in attack_nodes:
		if is_instance_valid(node): node.consume()
	attack_nodes.clear()

func cancel_for_pause() -> void:
	clear_attacks()
	if not is_dead:
		_enter("recover",.45)
		_dash_elapsed = 0
		velocity = Vector2.ZERO

func get_hitbox() -> Rect2:
	return Rect2() if is_dead else Rect2(global_position+Vector2(-59,-260),Vector2(118,260))

func danger_rect() -> Rect2:
	if is_dead or state!="sweep_active": return Rect2()
	return Rect2(global_position+Vector2(-72 if direction>0 else -312,-118),Vector2(384,96))

func get_contact_damage() -> int:
	return 2 if state=="sweep_active" else 1

func clash_rect() -> Rect2:
	if is_dead or state!="sweep_active": return Rect2()
	return Rect2(global_position+Vector2(266 if direction>0 else -312,-110),Vector2(46,68))

func on_clash() -> bool:
	if is_dead or state!="sweep_active": return false
	clear_attacks()
	_enter("stagger",.48)
	_play("parry_light")
	return true

func take_hit(amount: int, _from_x: float, _kind: String = "melee") -> bool:
	if not activated or is_dead or amount<=0 or invulnerable>0 or state in ["dormant","intro","phase_transition"]: return false
	hp = maxi(0,hp-amount)
	invulnerable = .10
	hit_flash = .09
	_play("hit")
	if hp<=0:
		_die()
	elif hp<=PHASE_THRESHOLD and not _phase_changed:
		_phase_changed = true
		phase = 2
		pattern_index = 0
		clear_attacks()
		_capture_hero_direction()
		_enter("phase_transition",PHASE_TRANSITION_SECONDS)
		_play_voice("compiler_voice_phase",true)
		_phase_resonance_remaining = .22
	elif _play_voice("compiler_voice_hurt_2" if _voice_variant%2 else "compiler_voice_hurt"):
		_voice_variant += 1
	_update_visual()
	queue_redraw()
	return true

func _die() -> void:
	if is_dead: return
	is_dead = true
	alive = false
	state = "dead"
	process_mode = Node.PROCESS_MODE_ALWAYS
	damage = 0
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	warning_text_ar = ""
	warning_text_en = ""
	clear_attacks()
	_play_voice("compiler_voice_death",true)
	if world_ref.has_method("emit_burst"): world_ref.emit_burst(global_position+Vector2(0,-160),Color("a2edf0"),32)
	if not _defeat_notified:
		_defeat_notified = true
		if world_ref.has_method("on_compiler_defeated"): world_ref.on_compiler_defeated(self)
		elif world_ref.has_method("on_enemy_defeated"): world_ref.on_enemy_defeated(self)

func _play(cue: String) -> void:
	if is_instance_valid(world_ref) and world_ref.has_method("play_sfx"): world_ref.play_sfx(cue)

func _play_voice(cue: String, force: bool = false) -> bool:
	# The world's mixer owns separate hero/boss voice groups and critical-line
	# preemption. This local cooldown prevents small barks on every sword hit.
	if not force and _voice_cooldown>0.0: return false
	_voice_cooldown = 1.10
	_play(cue)
	return true

func _update_visual() -> void:
	if is_instance_valid(visual) and visual.has_method("update_pose"):
		var progress := clampf(1.0-state_time/maxf(.01,state_duration),0,1)
		visual.update_pose(state,age,progress,warning_fraction)
		visual.modulate = Color(1.65,1.75,1.8) if hit_flash>0 else Color.WHITE

func _draw() -> void:
	if not is_instance_valid(visual): _draw_fallback()

func _active_weapon_grip() -> Vector2:
	if is_instance_valid(visual) and visual.has_method("get_weapon_grip_local"):
		var local_grip: Variant = visual.get_weapon_grip_local()
		if local_grip is Vector2 and local_grip.is_finite():
			# The rig exposes unmirrored visual-local coordinates. Its complete
			# transform applies facing exactly once, including the hand overlay.
			return to_local(visual.to_global(local_grip))
	return Vector2(float(direction)*32.0,-104.0)

func draw_combat_fx(canvas: Node2D) -> void:
	if state=="sweep_warning":
		var extent := 550.0
		canvas.draw_line(Vector2(float(direction)*30,-22),Vector2(float(direction)*extent,-22),Color(1,.73,.38,.38+.35*warning_fraction),3,true)
		for index in range(7):
			var x := float(direction)*(65+float(index)*75)
			canvas.draw_line(Vector2(x,-22),Vector2(x-float(direction)*12,-35),Color(.72,.94,.97,.5),1.4,true)
	elif state=="sweep_active":
		var left := -72.0 if direction>0 else -312.0
		var rect := Rect2(left,-118,384,96)
		# The faint complete field honestly marks all damaging corners, while
		# the pointed data blade and broken inner lines read as an execution
		# sword rather than a debug collision rectangle.
		var sweep_progress := clampf(1.0-state_time/.28,0,1)
		var light_gain := .78+.22*sin(sweep_progress*PI)
		if _danger_light != null:
			canvas.draw_texture_rect(_danger_light,rect,false,Color(1,1,1,light_gain))
		else:
			canvas.draw_rect(rect,Color(.20,.63,.82,.05))
		var grip := _active_weapon_grip()
		var tip := Vector2(float(direction)*304.0,-70.0)
		var axis := (tip-grip).normalized()
		var normal := Vector2(-axis.y,axis.x)
		var base := grip+axis*16.0
		var shoulder := tip-axis*58.0
		var blade := PackedVector2Array([base+normal*10.0,shoulder+normal*29.0,tip,shoulder-normal*27.0,base-normal*10.0])
		canvas.draw_colored_polygon(blade,Color(.40,.86,.95,.58))
		canvas.draw_line(base,tip-axis*6.0,Color("e7ffff"),6,true)
		# A real handle/crossguard begins in the posed closed fist; the rig's
		# z13 finger overlay sits over this z12 field, making the grasp legible.
		canvas.draw_line(grip-axis*18.0,base,Color("172a34"),7,true)
		canvas.draw_line(grip-axis*16.0,base,Color("bba577"),1.4,true)
		canvas.draw_line(base-normal*14.0,base+normal*14.0,Color("a98e61"),3,true)
		# A luminous release arc wraps visibly across the lower coat. It lives
		# above the painted body and inside the same damaging384x96 field.
		canvas.draw_arc(Vector2(0,-70),43,-PI*.5,PI*.5,32,Color(.72,1,1,.88),3,true)
		canvas.draw_arc(Vector2(0,-70),34,PI*.5,PI*1.5,28,Color(.40,.85,.98,.65),2,true)
		for index in range(7):
			var point := base.lerp(shoulder,.08+float(index)*.12)
			canvas.draw_line(point-normal*10.0,point+normal*12.0+axis*4.0,Color(.78,1,1,.82),1.6,true)
	elif state=="chains_warning":
		var start := to_local(Vector2(arena.position.x+10,floor_y-24))
		var finish := to_local(Vector2(arena.end.x-10,floor_y-24))
		canvas.draw_line(start,finish,Color(.45,.83,.92,.24+.35*warning_fraction),2,true)
		for index in range(12):
			var x := lerpf(start.x,finish.x,float(index)/11)
			canvas.draw_arc(Vector2(x,start.y),8,0,TAU,12,Color(.68,.96,1,.55),1.2,true)
	elif state=="phase_transition":
		var pulse := sin(age*12)*.5+.5
		canvas.draw_arc(Vector2(0,-160),132+pulse*12,0,TAU,64,Color(.54,.91,1,.25+.3*pulse),2,true)

func _draw_fallback() -> void:
	var ink := Color("15232d")
	var brass := Color("a38d65")
	var ivory := Color("cbbfa7")
	var coat := PackedVector2Array([Vector2(-142,0),Vector2(-98,-84),Vector2(-78,-174),Vector2(-49,-219),Vector2(-21,-238),Vector2(0,-286),Vector2(21,-238),Vector2(49,-219),Vector2(78,-174),Vector2(98,-84),Vector2(142,0),Vector2(72,-13),Vector2(0,-2),Vector2(-72,-13)])
	draw_colored_polygon(coat,ink)
	var closed := coat.duplicate(); closed.append(coat[0])
	draw_polyline(closed,brass,2,true)
	for index in range(7):
		var x := -75+index*25
		var strips := PackedVector2Array([Vector2(x,-210+absf(x)*.2),Vector2(x+19,-190),Vector2(x*1.5+25,-12),Vector2(x*1.5+10,-28),Vector2(x*1.5,-8)])
		draw_colored_polygon(strips,ivory if index%2==0 else Color("5b6060"))
		draw_line(Vector2(x+7,-151),Vector2(x*1.3+9,-62),ink,2,true)
	draw_colored_polygon(PackedVector2Array([Vector2(0,-300),Vector2(22,-262),Vector2(13,-231),Vector2(0,-211),Vector2(-13,-231),Vector2(-22,-262)]),Color("15232a"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,-287),Vector2(7,-258),Vector2(0,-237),Vector2(-7,-258)]),Color("9ff5f2"))
	draw_arc(Vector2(0,-245),43,PI*.9,PI*2.1,32,brass,1.6,true)
