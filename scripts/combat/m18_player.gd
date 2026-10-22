extends "res://scripts/player.gd"
## M18 combat uses the unchanged M13 art, running cadence and traversal constants.
const MAX_ENERGY := 99.0
const ACTION_COST := 33.0
const CombatModel = preload("res://scripts/combat/m18_warden_combat_model.gd")
var has_dash: bool = false
var air_dash_used: bool = false
var active_strike_time: float = 0.0
var strike_serial: int = 0
var hit_targets: Dictionary = {}
var attack_buffer: float = 0.0
var dash_buffer: float = 0.0
var heal_time: float = 0.0
var healing: bool = false
var heal_release_required: bool = false
var spell_cooldown: float = 0.0
var last_safe_position := Vector2.ZERO
var combat_container: Node2D
var combat_model: Node2D
var death_visual_time: float = 0.0

func _ready() -> void:
	energy = MAX_ENERGY
	super._ready()
	combat_container = Node2D.new()
	combat_container.name = "SharedM13CombatPresentation"
	combat_container.z_index = 5
	combat_container.visible = false
	add_child(combat_container)
	combat_model = CombatModel.new()
	combat_model.position = Vector2(-256,-456)
	combat_container.add_child(combat_model)
	_update_animation()

func _process(delta: float) -> void:
	if hp<=0 and is_instance_valid(combat_model):
		death_visual_time += delta
		combat_model.set_combat_pose("death",clampf(death_visual_time/0.38,0,1),false)
		_update_lantern_anchor()
	else:
		death_visual_time = 0.0

func _update_animation() -> void:
	super._update_animation()
	if not is_instance_valid(combat_model): return
	var use_rig: bool = current_pose in ["slash","slash_up","slash_down","recoil","death"]
	lantern_sprite.visible = not use_rig
	combat_container.visible = use_rig
	if not use_rig: return
	combat_container.scale = Vector2(ART_SCALE*facing,ART_SCALE)
	combat_container.modulate = lantern_sprite.modulate
	combat_model.sword_visible = has_blade
	var phase: float = 1.0-attack_time/0.255
	if current_pose=="recoil": phase = 1.0-hurt_time/0.25
	elif current_pose=="death": phase = clampf(death_visual_time/0.38,0,1)
	combat_model.set_combat_pose(current_pose,clampf(phase,0,1),not is_on_floor(),animation_age)
	_update_lantern_anchor()

func _update_lantern_anchor() -> void:
	if is_instance_valid(combat_model) and is_instance_valid(combat_container) and combat_container.visible and not combat_model.pose.is_empty():
		var pose: Dictionary = combat_model.pose
		var lean: float = deg_to_rad(float(pose.get("lean",0)))
		var shoulder := Vector2(256,float(pose.get("hip_y",350)))-Vector2.DOWN.rotated(lean)*94.0
		var center := shoulder+Vector2(16,0).rotated(lean)+Vector2(0,-42).rotated(lean*0.32)
		var offset := (center-Vector2(256,456))*ART_SCALE
		offset.x *= facing
		if is_instance_valid(lantern_light): lantern_light.position = offset
	else:
		super._update_lantern_anchor()

func _physics_process(delta: float) -> void:
	if world_ref == null or not world_ref.gameplay_active: return
	animation_age += delta
	if not Input.is_action_pressed("heal"): heal_release_required = false
	for property in ["invulnerable","hurt_time","attack_time","attack_cooldown","dash_time","dash_cooldown","parry_time","land_timer","turn_lock","active_strike_time","spell_cooldown"]:
		set(property,maxf(0.0,float(get(property))-delta))
	attack_buffer = maxf(0.0,attack_buffer-delta)
	dash_buffer = maxf(0.0,dash_buffer-delta)
	jump_grace = 0.11 if is_on_floor() else maxf(0.0,jump_grace-delta)
	jump_buffer = 0.13 if Input.is_action_just_pressed("jump") else maxf(0.0,jump_buffer-delta)
	if is_on_floor():
		air_dash_used = false
		last_safe_position = global_position
	var input_dir := Input.get_axis("move_left","move_right")
	if absf(input_dir)>0.05 and dash_time<=0 and attack_time<=0:
		var requested := 1 if input_dir>0 else -1
		if requested != facing:
			facing = requested
			turn_lock = 0.045
	if has_blade != visual_blade_state:
		visual_blade_state = has_blade
		current_pose = ""
		if has_blade: world_ref.emit_burst(global_position+Vector2(0,-50),Color("82e9f8"),12)
	if Input.is_action_just_pressed("attack"):
		attack_buffer = 0.20
		_cancel_heal(true)
	if Input.is_action_just_pressed("dash"):
		dash_buffer = 0.30
		_cancel_heal(true)
	if jump_buffer>0 and jump_grace>0 and hurt_time<=0 and dash_time<=0:
		_cancel_heal(true)
		velocity.y = JUMP_FORCE
		jump_grace = 0.0
		jump_buffer = 0.0
		land_timer = 0.0
		world_ref.play_sfx("jump")
	if dash_buffer>0 and has_dash and dash_cooldown<=0 and hurt_time<=0 and attack_time<=0 and not air_dash_used:
		dash_buffer = 0.0
		dash_time = 0.16
		dash_cooldown = 0.50
		air_dash_used = true
		world_ref.play_sfx("dash")
		world_ref.emit_burst(global_position+Vector2(0,-26),Color("70d9ff"),6)
	if attack_buffer>0 and attack_cooldown<=0 and hurt_time<=0 and dash_time<=0:
		attack_buffer = 0.0
		_start_attack()
	if Input.is_action_just_pressed("spell") and has_code_slash and energy>=ACTION_COST and hurt_time<=0 and dash_time<=0 and spell_cooldown<=0:
		_cancel_heal(true)
		energy -= ACTION_COST
		spell_cooldown = 0.40
		world_ref.cast_code_slash(global_position+Vector2(facing*34,-34),facing)
	_update_healing(delta,input_dir)
	if dash_time>0:
		velocity = Vector2(DASH_SPEED*facing,0)
	else:
		var target_speed := input_dir*SPEED if not healing and hurt_time<=0 else 0.0
		velocity.x = move_toward(velocity.x,target_speed,(GROUND_ACCEL if is_on_floor() else AIR_ACCEL)*delta)
		velocity.y = minf(velocity.y+GRAVITY*delta,980.0)
	move_and_slide()
	if active_strike_time>0:
		world_ref.hero_strike(attack_direction,facing)
	var grounded_running := is_on_floor() and absf(velocity.x)>32.0
	if was_ground_running and not grounded_running and absf(input_dir)<0.05 and is_on_floor() and hurt_time<=0:
		stop_timer = 0.105
	elif grounded_running or not is_on_floor() or absf(input_dir)>0.05:
		stop_timer = 0.0
	was_ground_running = grounded_running
	stop_timer = maxf(0,stop_timer-delta)
	if is_on_floor() and not was_grounded:
		land_timer = 0.12
		world_ref.emit_burst(global_position+Vector2(0,-2),Color("8499a6"),5)
	was_grounded = is_on_floor()
	position.x = clampf(position.x,movement_bounds.x,movement_bounds.y)
	if position.y>fall_limit: world_ref.player_fell()
	_update_animation()
	_update_sword_trail()
	lantern_light.energy = 0.35+(0.12+sin(animation_age*13)*0.05 if healing else 0.0)

func _update_healing(delta: float, input_dir: float) -> void:
	var valid := Input.is_action_pressed("heal") and not heal_release_required and is_on_floor() and hp>0 and hp<max_hp and absf(input_dir)<0.05 and hurt_time<=0 and attack_time<=0 and dash_time<=0 and attack_buffer<=0 and dash_buffer<=0 and spell_cooldown<=0
	if not valid:
		_cancel_heal()
		return
	if not healing:
		if energy<ACTION_COST: return
		energy -= ACTION_COST
		healing = true
		heal_time = 1.141*world_ref.combat_state.focus_duration_multiplier()
		world_ref.play_sfx("parry_light")
	heal_time -= delta
	if heal_time<=0:
		hp = mini(max_hp,hp+1)
		healing = false
		world_ref.emit_burst(global_position+Vector2(0,-54),Color("b9f3e9"),12)
		world_ref.combat_changed()

func _cancel_heal(lock_until_release: bool = false) -> void:
	if lock_until_release and Input.is_action_pressed("heal"): heal_release_required = true
	healing = false
	heal_time = 0.0

func _start_attack() -> void:
	if not has_blade:
		world_ref.show_tip("ابحث عن أداة الحارس أولًا" if world_ref.hud.language=="ar" else "Find the Warden's blade first")
		return
	attack_direction = "up" if Input.is_action_pressed("look_up") else ("down" if Input.is_action_pressed("look_down") and not is_on_floor() else "attack")
	attack_time = 0.255
	attack_cooldown = 0.275
	hit_fired = false
	active_strike_time = 0.0
	hit_targets.clear()
	strike_serial += 1
	current_pose = ""
	world_ref.play_sfx("swing")

func _on_art_frame_changed() -> void:
	_update_lantern_anchor()
	if not world_ref or not world_ref.gameplay_active or hit_fired or attack_time<=0: return
	var pose := "slash" if attack_direction=="attack" else ("slash_up" if attack_direction=="up" else "slash_down")
	if lantern_sprite.animation==pose and lantern_sprite.frame>=3:
		hit_fired = true
		active_strike_time = 0.070
		world_ref.hero_strike(attack_direction,facing)

func strike_rect(direction: String, look: int) -> Rect2:
	var reach: float = world_ref.combat_state.reach_multiplier()
	if direction=="up": return Rect2(global_position+Vector2(-31,-46-91*reach),Vector2(62,91*reach))
	if direction=="down": return Rect2(global_position+Vector2(-30,-8),Vector2(60,65*reach))
	return Rect2(global_position+Vector2(4 if look>0 else -92*reach-4,-79),Vector2(92*reach,74))

func gain_energy(amount: float) -> void:
	energy = clampf(energy+amount,0,MAX_ENERGY)

func pogo() -> void:
	velocity.y = -510.0
	air_dash_used = false
	jump_grace = 0.0

func hurt(amount: int, attack_x: float) -> void:
	if not world_ref.gameplay_active or invulnerable>0 or hp<=0: return
	_cancel_heal(true)
	attack_time = 0.0
	active_strike_time = 0.0
	attack_buffer = 0.0
	dash_buffer = 0.0
	dash_time = 0.0
	hp = maxi(0,hp-amount)
	hurt_time = 0.25
	invulnerable = 1.0
	velocity = Vector2(-280 if attack_x>position.x else 280,-260)
	world_ref.play_sfx("hurt")
	world_ref.emit_burst(global_position+Vector2(0,-32),Color("ef6885"),10)
	world_ref.combat_changed()
	if hp<=0: world_ref.on_player_death()

func reset_combat_motion() -> void:
	for property in ["hurt_time","attack_time","attack_cooldown","active_strike_time","dash_time","dash_cooldown","parry_time","parry_cooldown","attack_buffer","dash_buffer"]: set(property,0.0)
	_cancel_heal()
	air_dash_used = false
	velocity = Vector2.ZERO
	hit_targets.clear()
