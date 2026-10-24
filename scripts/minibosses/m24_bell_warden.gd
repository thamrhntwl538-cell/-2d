extends CharacterBody2D
## Natural motion supplies the information: no warning text, flash, beep or marks.
const Wave = preload("res://scripts/minibosses/m24_bell_wave.gd")
const Visual = preload("res://scripts/minibosses/m24_bell_visual.gd")
const APPROACH_SECONDS := .52
const APPROACH_SPEED := 45.0
const RUSH_SECONDS := .34
const DOUBLE_RUSH_SECONDS := .26
const PHASE_CHANGE_SECONDS := .72
const WAVE_SPEED := 520.0
const FAST_WAVE_SPEED := 620.0
const ECHO_SECONDS := .96
var world_ref: Node2D
var hp := 18
var max_hp := 18
var phase := 1
var phase_pending := false
var phase_transition_count := 0
var alive := true
var is_dead := false
var activated := false
var state := "dormant"
var state_time := 0.0
var state_duration := 0.0
var age := 0.0
var direction := -1
var arena := Rect2(1110,940,1080,320)
var floor_y := 1260.0
var visual: Node2D
var invulnerable := 0.0
var hit_flash := 0.0
var pattern_index := 0
var current_pattern := ""
var captured_target := Vector2.ZERO
var motion_start := Vector2.ZERO
var motion_end := Vector2.ZERO
var flight_velocity := Vector2.ZERO
var flight_gravity := 1900.0
var rush_number := 0
var leap_count := 0
var total_lands := 0
var total_launches := 0
var voice_hurt_cooldown := 0.0
var walk_footfalls := 0
var history: Array[String] = []
var attack_nodes: Array[Node2D] = []
var wave_history: Array[Dictionary] = []
var waves_spawned := 0
var waves_completed := 0
var warning_ar := ""
var warning_en := ""
var warning_progress := 0.0
var _death_age := 0.0

func setup(world: Node2D, spawn: Vector2, rect: Rect2) -> void:
	world_ref=world
	global_position=spawn
	floor_y=spawn.y
	arena=rect
	_enter("dormant",0)

func _ready() -> void:
	collision_layer=4
	collision_mask=0
	z_index=5
	add_to_group("m18_enemies")
	add_to_group("m24_miniboss")
	visual=Visual.new()
	add_child(visual)
	visual.actor=self

func start_encounter() -> void:
	if activated or is_dead: return
	activated=true
	_enter("intro",.85)

func _enter(next: String, seconds: float) -> void:
	state=next
	state_time=seconds
	state_duration=seconds
	if next not in ["dormant","idle","recover"]: history.append(next)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(world_ref) or not world_ref.gameplay_active or is_dead: return
	age+=delta
	invulnerable=maxf(0,invulnerable-delta)
	hit_flash=maxf(0,hit_flash-delta)
	voice_hurt_cooldown=maxf(0,voice_hurt_cooldown-delta)
	if state in ["dormant","intro","idle","recover"]:
		var dx: float=world_ref.hero.position.x-position.x
		if absf(dx)>12: direction=1 if dx>0 else -1
	if not activated: return
	if phase_pending and state in ["idle","recover","stagger","resonance"]:
		_begin_phase_change()
	state_time=maxf(0,state_time-delta)
	match state:
		"intro":
			if state_time<=0: _enter("idle",.3)
		"idle":
			if state_time<=0: _next_pattern()
		"walk":
			position=motion_start.lerp(motion_end,clampf(1.0-state_time/APPROACH_SECONDS,0,1))
			var elapsed := APPROACH_SECONDS-state_time
			if elapsed>=APPROACH_SECONDS*.5 and walk_footfalls==0:
				walk_footfalls=1
				_sound("bell_step")
			if elapsed>=APPROACH_SECONDS and walk_footfalls==1:
				walk_footfalls=2
				_sound("bell_step")
			if state_time<=0:
				if phase_pending: _begin_phase_change()
				else: _begin_pattern()
		"drawback","double_drawback":
			if state_time<=0: _start_rush()
		"rush","double_rush":
			var progress:=clampf(1.0-state_time/maxf(.001,state_duration),0,1)
			position=motion_start.lerp(motion_end,progress)
			position.y-=sin(progress*PI)*8
			if state_time<=0:
				if current_pattern=="double_rush" and rush_number==1:
					_enter("turn_gap",.36)
				else: _enter("recover",.68 if phase==2 else .78)
		"turn_gap":
			if state_time<=0:
				_capture_target()
				_enter("double_drawback",.20)
		"crouch":
			if state_time<=0: _launch(false)
		"high_crouch":
			if state_time<=0: _launch_high()
		"air","high_air":
			flight_velocity.y+=flight_gravity*delta
			position+=flight_velocity*delta
			position.x=clampf(position.x,arena.position.x+80,arena.end.x-80)
			if position.y>=floor_y and flight_velocity.y>0: _land()
		"echo_wait":
			if state_time<=0:
				_ground_impact()
				_spawn_waves(FAST_WAVE_SPEED,"echo")
				_enter("resonance",.18)
		"resonance":
			if state_time<=0 and live_wave_count()==0: _enter("recover",.60)
		"recover","stagger":
			if state_time<=0: _enter("idle",.18 if phase==2 else .22)
		"phase_change":
			# Old floor crests continue while the planted body settles. Holding
			# the last pose prevents a fresh attack overlapping those crests.
			if state_time<=0 and live_wave_count()==0:
				phase=2
				phase_pending=false
				pattern_index=0
				invulnerable=0
				_enter("idle",.18)
	if is_instance_valid(visual): visual.queue_redraw()

func _capture_target() -> void:
	captured_target=world_ref.hero.position
	if absf(captured_target.x-position.x)>1:
		direction=1 if captured_target.x>position.x else -1

func _next_pattern() -> void:
	if phase_pending:
		_begin_phase_change()
		return
	if live_wave_count()>0:
		_enter("resonance",0)
		return
	var order := ["double_rush","high_leap"] if phase==2 else ["rush","leap","leap"]
	current_pattern=order[pattern_index%order.size()]
	pattern_index+=1
	_capture_target()
	rush_number=0
	leap_count=0
	if current_pattern=="rush" and absf(captured_target.x-position.x)>330:
		motion_start=position
		motion_end=Vector2(clampf(position.x+direction*APPROACH_SPEED*APPROACH_SECONDS,arena.position.x+90,arena.end.x-90),floor_y)
		walk_footfalls=0
		_enter("walk",APPROACH_SECONDS)
		return
	_begin_pattern()

func _begin_pattern() -> void:
	match current_pattern:
		"rush": _enter("drawback",.36)
		"double_rush": _enter("double_drawback",.28)
		"high_leap": _enter("high_crouch",.26)
		_: _enter("crouch",.32)

func _start_rush() -> void:
	var double := current_pattern=="double_rush"
	motion_start=position
	motion_end=Vector2(clampf(position.x+direction*(240 if double else 260),arena.position.x+90,arena.end.x-90),floor_y)
	rush_number+=1
	_enter("double_rush" if double else "rush",DOUBLE_RUSH_SECONDS if double else RUSH_SECONDS)
	_sound("bell_swing")

func _launch(second: bool) -> void:
	# Preserve the phase-one launch API for the original focused fixtures.
	_launch_toward(590.0 if second else 710.0,1900.0,340.0,"air")

func _launch_high() -> void:
	_launch_toward(1000.0,3000.0,360.0,"high_air")

func _launch_toward(speed: float, gravity: float, reach: float, air_state: String) -> void:
	var duration := speed*2/gravity
	var target := clampf(captured_target.x,position.x-reach,position.x+reach)
	target=clampf(target,arena.position.x+100,arena.end.x-100)
	flight_gravity=gravity
	flight_velocity=Vector2((target-position.x)/duration,-speed)
	_enter(air_state,duration)
	_sound("bell_takeoff")
	if total_launches%2==0: _sound("bell_voice_strain")
	total_launches+=1

func _land() -> void:
	position.y=floor_y
	flight_velocity=Vector2.ZERO
	total_lands+=1
	_ground_impact()
	_spawn_waves(FAST_WAVE_SPEED if current_pattern=="high_leap" else WAVE_SPEED,"landing")
	if phase_pending: _begin_phase_change()
	elif current_pattern=="high_leap": _enter("echo_wait",ECHO_SECONDS)
	else: _enter("resonance",.18)

func _ground_impact() -> void:
	_sound("bell_impact")
	if world_ref.has_method("on_bell_ground_impact"):
		world_ref.on_bell_ground_impact(global_position,phase)
	else:
		world_ref.emit_burst(position+Vector2(0,-4),Color("edbb72"),12)
		world_ref.boss_trauma=.30

func _spawn_waves(speed: float, volley: String) -> void:
	for side in [-1,1]:
		var wave := Wave.new()
		get_parent().add_child(wave)
		var origin := Vector2(clampf(position.x+side*88,arena.position.x,arena.end.x),floor_y-12)
		wave.setup(world_ref,self,"chain",origin,{"warning":0,"velocity":Vector2(side*speed,0),"width":48,"height":24,"boundary_x":arena.position.x if side<0 else arena.end.x,"volley":volley,"phase":phase})
		attack_nodes.append(wave)
		waves_spawned+=1

func live_wave_count() -> int:
	var count:=0
	for wave in attack_nodes:
		if is_instance_valid(wave) and not wave.spent: count+=1
	return count

func _on_wave_finished(wave: Node2D, reason: String) -> void:
	attack_nodes.erase(wave)
	waves_completed+=1
	wave_history.append({"reason":reason,"boundary_x":wave.boundary_x,"position":wave.global_position,"start":wave.start_position,"phase":wave.wave_phase,"volley":wave.volley,"reached_boundary":wave.reached_boundary,"hero_hits":wave.hero_hits})
	if wave_history.size()>64: wave_history.pop_front()

func _begin_phase_change() -> void:
	if phase!=1 or not phase_pending or state=="phase_change": return
	if state in ["rush","double_rush"] or absf(position.y-floor_y)>.01 or not flight_velocity.is_zero_approx(): return
	position.y=floor_y
	flight_velocity=Vector2.ZERO
	phase_transition_count+=1
	_enter("phase_change",PHASE_CHANGE_SECONDS)

func get_hitbox() -> Rect2:
	return Rect2() if is_dead else Rect2(global_position+Vector2(-59,-164),Vector2(118,150))

func danger_rect() -> Rect2:
	if is_dead or not activated: return Rect2()
	if state in ["rush","double_rush"]: return Rect2(global_position+Vector2(-63,-132),Vector2(126,118))
	if state in ["air","high_air"] and flight_velocity.y>60: return Rect2(global_position+Vector2(-57,-142),Vector2(114,134))
	return Rect2()

func get_contact_damage() -> int: return 2 if state in ["air","high_air"] else 1

func clash_rect() -> Rect2:
	if state not in ["rush","double_rush"]: return Rect2()
	return Rect2(global_position+Vector2(44 if direction>0 else -74,-88),Vector2(30,56))

func on_clash() -> bool:
	if state not in ["rush","double_rush"]: return false
	position.y=floor_y
	_enter("stagger",.55 if phase==2 else .42)
	# The world's melee resolver owns the single impact sound and hit stop.
	return true

func take_hit(amount: int, _from_x: float, _kind: String="melee") -> bool:
	if is_dead or not activated or state=="intro" or phase_pending or state=="phase_change" or invulnerable>0 or amount<=0: return false
	hp=maxi(9 if phase==1 else 0,hp-amount)
	if phase==1 and hp<=9: phase_pending=true
	invulnerable=.11
	hit_flash=.07
	_sound("bell_hit")
	if hp>0 and voice_hurt_cooldown<=0:
		_sound("bell_voice_hurt")
		voice_hurt_cooldown=1.6
	world_ref.emit_burst(position+Vector2(0,-75),Color("efbd77"),5)
	if hp==0:
		is_dead=true
		alive=false
		state="dead"
		clear_attacks("death")
		_sound("bell_fall")
		_sound("bell_voice_death")
		world_ref.on_compiler_defeated(self)
	return true

func attacks_allowed() -> bool:
	return activated and not is_dead and is_instance_valid(world_ref) and world_ref.gameplay_active and world_ref.boss_active

func clear_attacks(reason: String="cleanup") -> void:
	for node in attack_nodes.duplicate():
		if is_instance_valid(node): node.consume_with_reason(reason)
	attack_nodes.clear()

func _sound(cue: String) -> void:
	if not is_instance_valid(world_ref): return
	if is_instance_valid(world_ref.soundscape):
		world_ref.soundscape.play_at(cue,global_position)
	else:
		world_ref.play_sfx(cue)

func _process(delta: float) -> void:
	if is_dead:
		_death_age+=delta
		modulate.a=1.0-smoothstep(.3,1.2,_death_age)
	if is_instance_valid(visual): visual.queue_redraw()
