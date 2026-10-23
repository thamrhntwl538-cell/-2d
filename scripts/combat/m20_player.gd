extends "res://scripts/combat/m18_player.gd"
## M20 uses one native rig and one physics attack timeline for art and contact.
const ModelM20 = preload("res://scripts/warden_model_m20.gd")
const DRAW_SCALE := 0.37
var m20_ready: bool = false
var run_sample: float = 0.0
var head_collider: CollisionShape2D
# Authored values, informed by reference footage; not frame-exact HK measurements.
const ATTACK_DURATION := 0.30
const ATTACK_COOLDOWN := 0.36
const CONTACT_START := 0.06
const CONTACT_END := 0.14
const DASH_DURATION := 0.16
const DASH_COOLDOWN := 0.50
const GROUND_RESPONSE := 9000.0
const GROUND_BRAKE := 12000.0
const AIR_RESPONSE := 7200.0
const JUMP_RELEASE_SPEED := -420.0
const ACTION_BUFFER := 0.10
const EXPRESSION_SECONDS := 0.10
var attack_elapsed: float = 0.0
var attack_variant: int = 0
var expression_kind: String = "idle"
var expression_target: String = "idle"
var expression_blend: float = 1.0
var _next_forward_variant: int = 0
var _buffered_attack_direction: String = "attack"
var _jump_cut_available: bool = false
var _alert_linger: float = 0.0

func _ready() -> void:
	energy = MAX_ENERGY
	collision_layer = 2
	collision_mask = 1
	var body := CollisionShape2D.new()
	body.name = "StableGameplayCollider"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24,52)
	body.shape = shape
	body.position = Vector2(0,-26)
	add_child(body)
	head_collider = CollisionShape2D.new()
	head_collider.name = "SolidLanternCollider"
	var head_shape := RectangleShape2D.new()
	head_shape.size = Vector2(36,40)
	head_collider.shape = head_shape
	head_collider.position = Vector2(3,-68)
	add_child(head_collider)
	# Only a transparent timing clock remains: no old hero atlas is loaded.
	lantern_sprite = AnimatedSprite2D.new()
	lantern_sprite.name = "M20PresentationClock"
	lantern_sprite.sprite_frames = _build_clock()
	lantern_sprite.visible = false
	add_child(lantern_sprite)
	# Construct ready-to-use neutral texture RIDs before adding the lights.
	# This avoids replacing a not-yet-submitted GLES light-atlas texture.
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var radius := Vector2(x-31.5,y-31.5).length()/32.0
			var alpha := pow(maxf(0,1.0-radius),2.1)*0.75
			image.set_pixel(x,y,Color(1,1,1,alpha))
	var glow := ImageTexture.create_from_image(image)
	lantern_light = PointLight2D.new()
	lantern_light.name = "AmberLanternCore"
	lantern_light.texture = glow
	lantern_light.color = Color("f3ae68")
	lantern_light.texture_scale = 3.2
	lantern_light.energy = 0.35
	add_child(lantern_light)
	blade_light = PointLight2D.new()
	blade_light.name = "AmberSwordLight"
	blade_light.texture = glow
	blade_light.color = Color("f6c68d")
	blade_light.texture_scale = 2.0
	blade_light.energy = 0.20
	blade_light.visible = false
	add_child(blade_light)
	combat_container = Node2D.new()
	combat_container.name = "M20SingleHeroRig"
	combat_container.z_index = 5
	add_child(combat_container)
	combat_model = ModelM20.new()
	combat_model.position = Vector2(-256,-456)
	combat_container.add_child(combat_model)
	lantern_sprite.frame_changed.connect(_on_art_frame_changed)
	m20_ready = true
	was_grounded = is_on_floor()
	_update_animation()

func _process(delta: float) -> void:
	if not m20_ready: return
	if hp<=0:
		# Death still presents while the world suspends gameplay for its respawn UI.
		# Neither attack time nor contact may advance through this visual-only path.
		death_visual_time += delta
		attack_time = 0.0
		active_strike_time = 0.0
		expression_kind = "idle"
		expression_blend = 1.0
		_update_animation()
	else:
		death_visual_time = 0.0

func _build_clock() -> SpriteFrames:
	var image := Image.create(1,1,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var texture := ImageTexture.create_from_image(image)
	var library := SpriteFrames.new()
	library.remove_animation("default")
	var movement := {"idle":[16,8,true],"ready":[16,8,true],"run":[48,104,true],"jump":[15,45,false],"fall":[6,30,false],"land":[4,36,false],"stop":[6,54,false],"dash":[12,36,false],"crouch":[4,36,false]}
	for prefix in ["unarmed_","armed_"]:
		for kind in movement:
			var id: String = prefix+kind
			library.add_animation(id)
			library.set_animation_speed(id,movement[kind][1])
			library.set_animation_loop(id,movement[kind][2])
			for frame in range(movement[kind][0]): library.add_frame(id,texture)
	for kind in ["slash","slash_up","slash_down","recoil","death"]:
		library.add_animation(kind)
		library.set_animation_speed(kind,23 if kind.begins_with("slash") else 15)
		library.set_animation_loop(kind,false)
		for frame in range(8): library.add_frame(kind,texture)
	return library

func _physics_process(delta: float) -> void:
	if world_ref == null or not world_ref.gameplay_active: return
	animation_age += delta
	if not Input.is_action_pressed("heal"): heal_release_required = false
	var was_dashing: bool = dash_time>0.0
	for property in ["invulnerable","hurt_time","attack_cooldown","dash_time","dash_cooldown","parry_time","land_timer","turn_lock","spell_cooldown"]:
		set(property,maxf(0.0,float(get(property))-delta))
	if attack_time>0:
		attack_elapsed += delta
		attack_time = maxf(0.0,ATTACK_DURATION-attack_elapsed)
	_sync_strike_window()
	attack_buffer = maxf(0.0,attack_buffer-delta)
	dash_buffer = maxf(0.0,dash_buffer-delta)
	jump_grace = 0.11 if is_on_floor() else maxf(0.0,jump_grace-delta)
	jump_buffer = 0.13 if Input.is_action_just_pressed("jump") else maxf(0.0,jump_buffer-delta)
	if is_on_floor():
		air_dash_used = false
		last_safe_position = global_position
	var input_dir := Input.get_axis("move_left","move_right")
	# A dash ends decisively. Its 900px/s velocity cannot leak into normal movement.
	if was_dashing and dash_time<=0 and hurt_time<=0:
		velocity.x = input_dir*SPEED
	if absf(input_dir)>0.05 and dash_time<=0 and (attack_time<=0 or attack_elapsed>=CONTACT_END):
		var requested := 1 if input_dir>0 else -1
		if requested!=facing:
			facing = requested
			turn_lock = 0.045
	if has_blade!=visual_blade_state:
		visual_blade_state = has_blade
		current_pose = ""
		if has_blade: world_ref.emit_burst(global_position+Vector2(0,-50),Color("f6c58b"),12)
	if Input.is_action_just_pressed("attack"):
		_buffered_attack_direction = "up" if Input.is_action_pressed("look_up") else ("down" if Input.is_action_pressed("look_down") and (not is_on_floor() or Input.is_action_just_pressed("jump")) else "attack")
		attack_buffer = ACTION_BUFFER+dash_time
		if has_blade: _cancel_heal(true)
	if Input.is_action_just_pressed("dash") and has_dash:
		var until_contact_ends: float = maxf(0,CONTACT_END-attack_elapsed) if attack_time>0 else 0.0
		dash_buffer = maxf(ACTION_BUFFER,until_contact_ends+0.04)
		_cancel_heal(true)
	var jumped_this_frame := false
	if jump_buffer>0 and jump_grace>0 and hurt_time<=0:
		# A grounded jump cancels a dash, retaining the actual upward impulse.
		_cancel_heal(true)
		if dash_time>0: velocity.x = input_dir*SPEED
		dash_time = 0.0
		dash_buffer = 0.0
		velocity.y = JUMP_FORCE
		jump_grace = 0.0
		jump_buffer = 0.0
		land_timer = 0.0
		_jump_cut_available = true
		jumped_this_frame = true
		world_ref.play_sfx("jump")
	if dash_buffer>0 and has_dash and dash_cooldown<=0 and hurt_time<=0 and not air_dash_used and not jumped_this_frame:
		if attack_time<=0 or attack_elapsed>=CONTACT_END:
			_cancel_attack()
			dash_buffer = 0.0
			dash_time = DASH_DURATION
			dash_cooldown = DASH_COOLDOWN
			air_dash_used = true
			_jump_cut_available = false
			if attack_buffer>0: attack_buffer=maxf(attack_buffer,DASH_DURATION+ACTION_BUFFER)
			world_ref.play_sfx("dash")
			world_ref.emit_burst(global_position+Vector2(0,-26),Color("f4c38a"),5)
	if attack_buffer>0 and attack_cooldown<=0 and hurt_time<=0 and dash_time<=0:
		attack_buffer = 0.0
		_start_attack()
	if Input.is_action_just_pressed("spell") and has_code_slash and energy>=ACTION_COST and hurt_time<=0 and dash_time<=0 and spell_cooldown<=0:
		_cancel_heal(true)
		energy -= ACTION_COST
		spell_cooldown = 0.40
		world_ref.cast_code_slash(global_position+Vector2(facing*34,-34),facing)
	_update_healing(delta,input_dir)
	if _jump_cut_available and not Input.is_action_pressed("jump") and velocity.y<JUMP_RELEASE_SPEED and dash_time<=0:
		velocity.y = JUMP_RELEASE_SPEED
		_jump_cut_available = false
	if velocity.y>=0: _jump_cut_available = false
	if dash_time>0:
		velocity = Vector2(DASH_SPEED*facing,0)
	else:
		var target_speed := input_dir*SPEED if not healing and hurt_time<=0 else 0.0
		var response: float = GROUND_BRAKE if is_on_floor() and absf(input_dir)<0.05 else (GROUND_RESPONSE if is_on_floor() else AIR_RESPONSE)
		if hurt_time>0: response=GROUND_ACCEL if is_on_floor() else AIR_ACCEL
		velocity.x = move_toward(velocity.x,target_speed,response*delta)
		velocity.y = minf(velocity.y+GRAVITY*delta,980.0)
	var before_x: float = global_position.x
	move_and_slide()
	if dash_time<=0 and is_on_floor(): run_sample += absf(global_position.x-before_x)/SPEED*13.0
	var grounded_running := is_on_floor() and absf(velocity.x)>32.0
	if was_ground_running and not grounded_running and absf(input_dir)<0.05 and is_on_floor() and hurt_time<=0:
		stop_timer = 0.105
	elif grounded_running or not is_on_floor() or absf(input_dir)>0.05:
		stop_timer = 0.0
	was_ground_running = grounded_running
	stop_timer = maxf(0,stop_timer-delta)
	if is_on_floor() and not was_grounded:
		land_timer = 0.12
		world_ref.emit_burst(global_position+Vector2(0,-2),Color("f0c48f"),5)
	was_grounded = is_on_floor()
	position.x = clampf(position.x,movement_bounds.x,movement_bounds.y)
	if position.y>fall_limit: world_ref.player_fell()
	_update_expression(delta)
	# Pose geometry must be current BEFORE a contact test queries the fire arc.
	_update_animation()
	if active_strike_time>0:
		hit_fired = true
		world_ref.hero_strike(attack_direction,facing)
	lantern_light.energy = 0.35+(0.12+sin(animation_age*13)*0.05 if healing else 0.0)

func _sync_strike_window() -> void:
	active_strike_time = maxf(0.0,CONTACT_END-attack_elapsed) if attack_time>0 and attack_elapsed>=CONTACT_START and attack_elapsed<CONTACT_END else 0.0

func _cancel_attack() -> void:
	attack_time = 0.0
	active_strike_time = 0.0
	hit_fired = true

func _start_attack() -> void:
	if not has_blade:
		world_ref.show_tip("ابحث عن أداة الحارس أولًا" if world_ref.hud.language=="ar" else "Find the Warden's blade first")
		return
	attack_direction = _buffered_attack_direction
	if attack_direction=="down" and is_on_floor() and velocity.y>=0: attack_direction="attack"
	attack_variant = _next_forward_variant if attack_direction=="attack" else 0
	if attack_direction=="attack": _next_forward_variant=1-_next_forward_variant
	attack_elapsed = 0.0
	attack_time = ATTACK_DURATION
	attack_cooldown = ATTACK_COOLDOWN
	active_strike_time = 0.0
	hit_fired = false
	hit_targets.clear()
	strike_serial += 1
	current_pose = ""
	world_ref.play_sfx("swing")

func _on_art_frame_changed() -> void:
	# Presentation clocks never grant damage. Physics owns the sole contact timeline.
	_update_lantern_anchor()

func _update_expression(delta: float) -> void:
	_alert_linger = maxf(0,_alert_linger-delta)
	var actors: Variant = world_ref.get("enemies")
	if actors is Array:
		for actor in actors:
			if is_instance_valid(actor) and not bool(actor.get("is_dead")) and absf(actor.global_position.x-global_position.x)<330 and absf(actor.global_position.y-global_position.y)<150:
				_alert_linger = 0.35
	expression_target = "idle"
	if attack_time<=0 and dash_time<=0 and hurt_time<=0 and hp>0 and not healing and is_on_floor():
		if Input.is_action_pressed("look_up"): expression_target="look_up"
		elif Input.is_action_pressed("look_down"): expression_target="look_down"
		elif _alert_linger>0: expression_target="alert"
	if expression_kind!=expression_target:
		expression_blend = maxf(0,expression_blend-delta/EXPRESSION_SECONDS)
		if expression_blend<=0: expression_kind=expression_target
	else:
		expression_blend = minf(1,expression_blend+delta/EXPRESSION_SECONDS)

func pogo() -> void:
	super.pogo()
	_jump_cut_available = false

func reset_combat_motion() -> void:
	super.reset_combat_motion()
	attack_elapsed = 0.0
	_jump_cut_available = false
	expression_kind = "idle"
	expression_target = "idle"
	expression_blend = 1.0
	_alert_linger = 0.0

func _update_animation() -> void:
	if not m20_ready:
		super._update_animation()
		return
	var pose := "armed_ready" if has_blade else "unarmed_idle"
	if hp<=0: pose = "death"
	elif hurt_time>0: pose = "recoil"
	elif attack_time>0 and has_blade:
		pose = "slash" if attack_direction=="attack" else ("slash_up" if attack_direction=="up" else "slash_down")
	elif dash_time>0: pose = "armed_dash" if has_blade else "unarmed_run"
	elif not is_on_floor(): pose = ("armed_jump" if velocity.y<0 else "armed_fall") if has_blade else ("unarmed_jump" if velocity.y<0 else "unarmed_fall")
	elif absf(velocity.x)>32: pose = "armed_run" if has_blade else "unarmed_run"
	elif land_timer>0: pose = "armed_land" if has_blade else "unarmed_land"
	elif stop_timer>0: pose = "armed_stop" if has_blade else "unarmed_stop"
	lantern_sprite.flip_h = facing<0
	lantern_sprite.speed_scale = clampf(absf(velocity.x)/SPEED,0.10,1.0) if pose.ends_with("_run") else 1.0
	if current_pose!=pose:
		current_pose = pose
		lantern_sprite.play(pose)
	# The hidden clock is never displayed, including during recoil and death.
	lantern_sprite.visible = false
	combat_container.visible = true
	combat_container.scale = Vector2(DRAW_SCALE*facing,DRAW_SCALE)
	combat_container.modulate = Color(1,1,1,.58) if invulnerable>0 and int(animation_age*16)%2==0 else Color.WHITE
	combat_model.attack_variant = attack_variant
	combat_model.sword_visible = has_blade and pose in ["slash","slash_up","slash_down","recoil"]
	combat_model.sword_reach = world_ref.combat_state.reach_multiplier() if is_instance_valid(world_ref) else 1.0
	if pose in ["slash","slash_up","slash_down","recoil","death"]:
		var phase: float = attack_elapsed/ATTACK_DURATION
		if pose=="recoil": phase = 1.0-hurt_time/0.25
		elif pose=="death": phase = death_visual_time/0.38
		var moving_slash: bool = pose.begins_with("slash") and is_on_floor() and absf(velocity.x)>32.0
		combat_model.set_combat_pose(pose,clampf(phase,0,1),not is_on_floor(),run_sample,moving_slash)
	elif healing:
		combat_model.set_motion("heal",animation_age)
	elif dash_time>0:
		combat_model.set_motion("dash",1.0-dash_time/DASH_DURATION)
	elif not is_on_floor():
		var air_phase := 1.0+2.0*clampf(1.0-absf(velocity.y)/absf(JUMP_FORCE),0,1) if velocity.y<0 else 4.0+2.0*clampf(velocity.y/790.0,0,1)
		combat_model.set_motion("air",air_phase)
	elif pose.ends_with("_run"):
		combat_model.set_motion("run",run_sample)
	elif pose.ends_with("_land"):
		combat_model.set_motion("land",1.0-land_timer/.12)
	elif pose.ends_with("_stop"):
		combat_model.set_motion("stop",1.0-stop_timer/.105)
	else:
		combat_model.set_motion("idle",fposmod(animation_age*.8,1.0))
	combat_model.set_expression(expression_kind,expression_blend)
	if is_instance_valid(head_collider): head_collider.position.x = 3*facing
	blade_light.visible = has_blade and attack_time>0
	blade_light.position = Vector2(facing*33,-40)
	_update_lantern_anchor()

func _update_lantern_anchor() -> void:
	if m20_ready and is_instance_valid(combat_model):
		lantern_light.position = to_local(combat_model.to_global(combat_model.lantern_center))
	else:
		super._update_lantern_anchor()

func get_hurtboxes() -> Array[Rect2]:
	return [Rect2(global_position+Vector2(-12,-52),Vector2(24,52)),Rect2(global_position+Vector2(3*facing-18,-88),Vector2(36,40))]

func get_visual_bounds() -> Rect2:
	return Rect2(global_position+Vector2(-56,-106),Vector2(112,110))

func strike_rect(_direction: String, _look: int) -> Rect2:
	if not m20_ready or not has_blade or active_strike_time<=0: return Rect2()
	var source: Rect2 = combat_model.get_strike_rect()
	if not source.has_area(): return Rect2()
	var start: Vector2 = combat_model.to_global(source.position)
	var end: Vector2 = combat_model.to_global(source.end)
	return Rect2(start,end-start).abs()
