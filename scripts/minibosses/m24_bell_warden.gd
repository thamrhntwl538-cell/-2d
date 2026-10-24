extends CharacterBody2D
## Natural motion supplies the information: no warning text, flash, beep or marks.
const Wave = preload("res://scripts/minibosses/m24_bell_wave.gd")
const Visual = preload("res://scripts/minibosses/m24_bell_visual.gd")
const APPROACH_SECONDS := .52
const APPROACH_SPEED := 45.0
const RUSH_SECONDS := .34
var world_ref: Node2D
var hp := 18
var max_hp := 18
var phase := 1
var alive := true
var is_dead := false
var activated := false
var state := "dormant"
var state_time := 0.0
var state_duration := 0.0
var age := 0.0
var direction := -1
var arena := Rect2(900,940,1500,320)
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
var leap_count := 0
var total_lands := 0
var total_launches := 0
var voice_hurt_cooldown := 0.0
var walk_footfalls := 0
var history: Array[String] = []
var attack_nodes: Array[Node2D] = []
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
	state_time=maxf(0,state_time-delta)
	match state:
		"intro":
			if state_time<=0: _enter("idle",.3)
		"idle":
			if state_time<=0: _next_pattern()
		"walk":
			# Two measured steps close a distant gap. The captured destination is
			# fixed, so crossing behind the bell never turns this into pursuit.
			position=motion_start.lerp(motion_end,clampf(1.0-state_time/APPROACH_SECONDS,0,1))
			var elapsed := APPROACH_SECONDS-state_time
			if elapsed>=APPROACH_SECONDS*.5 and walk_footfalls==0:
				walk_footfalls=1
				_sound("bell_step")
			if elapsed>=APPROACH_SECONDS and walk_footfalls==1:
				walk_footfalls=2
				_sound("bell_step")
			if state_time<=0: _begin_pattern()
		"drawback":
			if state_time<=0:
				motion_start=position
				motion_end=Vector2(clampf(position.x+direction*260,arena.position.x+90,arena.end.x-90),floor_y)
				_enter("rush",RUSH_SECONDS)
				_sound("bell_swing")
		"rush":
			var progress:=clampf(1.0-state_time/RUSH_SECONDS,0,1)
			position=motion_start.lerp(motion_end,progress)
			# This fast committed movement is a low bound. Short fixed legs tuck
			# through its middle, then plant when recovery reaches the floor.
			position.y-=sin(progress*PI)*8
			if state_time<=0: _enter("recover",.78)
		"crouch":
			if state_time<=0: _launch(false)
		"air":
			flight_velocity.y+=1900*delta
			position+=flight_velocity*delta
			position.x=clampf(position.x,arena.position.x+80,arena.end.x-80)
			if position.y>=floor_y and flight_velocity.y>0: _land()
		"spring":
			if state_time<=0: _launch(true)
		"resonance":
			if state_time<=0: _enter("recover",.60)
		"recover","stagger":
			if state_time<=0: _enter("idle",.22)
	if is_instance_valid(visual): visual.queue_redraw()

func _next_pattern() -> void:
	clear_attacks()
	var order := ["rush","leap","rush","echo_leap"] if hp<=9 else ["rush","leap","leap"]
	current_pattern=order[pattern_index%order.size()]
	pattern_index+=1
	captured_target=world_ref.hero.position
	direction=1 if captured_target.x>position.x else -1
	leap_count=0
	if current_pattern=="rush" and absf(captured_target.x-position.x)>330:
		motion_start=position
		motion_end=Vector2(clampf(position.x+direction*APPROACH_SPEED*APPROACH_SECONDS,arena.position.x+90,arena.end.x-90),floor_y)
		walk_footfalls=0
		_enter("walk",APPROACH_SECONDS)
		return
	_begin_pattern()

func _begin_pattern() -> void:
	_enter("drawback" if current_pattern=="rush" else "crouch",.36 if current_pattern=="rush" else .32)

func _launch(second: bool) -> void:
	var launch_speed := 590.0 if second else 710.0
	var duration := launch_speed*2/1900.0
	var target := clampf(captured_target.x,position.x-340,position.x+340)
	if second: target=clampf(captured_target.x+direction*110,position.x-240,position.x+240)
	target=clampf(target,arena.position.x+100,arena.end.x-100)
	flight_velocity=Vector2((target-position.x)/duration,-launch_speed)
	_enter("air",duration)
	_sound("bell_takeoff")
	if total_launches%2==0: _sound("bell_voice_strain")
	total_launches+=1

func _land() -> void:
	position.y=floor_y
	flight_velocity=Vector2.ZERO
	total_lands+=1
	_sound("bell_impact")
	world_ref.emit_burst(position+Vector2(0,-4),Color("edbb72"),12)
	world_ref.boss_trauma=.30
	if current_pattern=="echo_leap" and leap_count==0:
		leap_count=1
		_enter("spring",.24)
		return
	for side in [-1,1]:
		var wave := Wave.new()
		get_parent().add_child(wave)
		wave.setup(world_ref,self,"chain",position+Vector2(side*88,-12),{"warning":0,"duration":1.15,"velocity":Vector2(side*380,0),"width":46,"height":16})
		attack_nodes.append(wave)
	_enter("resonance",1.35)

func get_hitbox() -> Rect2:
	return Rect2() if is_dead else Rect2(global_position+Vector2(-59,-164),Vector2(118,150))

func danger_rect() -> Rect2:
	if is_dead or not activated: return Rect2()
	if state=="rush": return Rect2(global_position+Vector2(-63,-132),Vector2(126,118))
	if state=="air" and flight_velocity.y>60: return Rect2(global_position+Vector2(-57,-142),Vector2(114,134))
	return Rect2()

func get_contact_damage() -> int: return 2 if state=="air" else 1

func clash_rect() -> Rect2:
	if state!="rush": return Rect2()
	return Rect2(global_position+Vector2(44 if direction>0 else -74,-88),Vector2(30,56))

func on_clash() -> bool:
	if state!="rush": return false
	position.y=floor_y
	_enter("stagger",.42)
	# The world's melee resolver owns the single impact sound and hit stop.
	return true

func take_hit(amount: int, _from_x: float, _kind: String="melee") -> bool:
	if is_dead or not activated or state=="intro" or invulnerable>0 or amount<=0: return false
	hp=maxi(0,hp-amount)
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
		clear_attacks()
		_sound("bell_fall")
		_sound("bell_voice_death")
		world_ref.on_compiler_defeated(self)
	return true

func attacks_allowed() -> bool:
	return activated and not is_dead and is_instance_valid(world_ref) and world_ref.gameplay_active and world_ref.boss_active

func clear_attacks() -> void:
	for node in attack_nodes:
		if is_instance_valid(node): node.consume()
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
