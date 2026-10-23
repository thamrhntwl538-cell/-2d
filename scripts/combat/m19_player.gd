extends "res://scripts/combat/m18_player.gd"
## M19 uses one reference-matched native rig for every visible state.
const ModelM19 = preload("res://scripts/warden_model_m19.gd")
const DRAW_SCALE := 0.37
var m19_ready: bool = false
var run_sample: float = 0.0
var head_collider: CollisionShape2D

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
	lantern_sprite.name = "M19CombatClock"
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
	combat_container.name = "M19SingleHeroRig"
	combat_container.z_index = 5
	add_child(combat_container)
	combat_model = ModelM19.new()
	combat_model.position = Vector2(-256,-456)
	combat_container.add_child(combat_model)
	lantern_sprite.frame_changed.connect(_on_art_frame_changed)
	m19_ready = true
	was_grounded = is_on_floor()
	_update_animation()

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
	if is_instance_valid(world_ref) and world_ref.gameplay_active:
		run_sample += absf(velocity.x)/SPEED*13.0*delta
	super._physics_process(delta)

func _update_animation() -> void:
	if not m19_ready:
		super._update_animation()
		return
	var pose := "armed_ready" if has_blade else "unarmed_idle"
	if hp<=0: pose = "death"
	elif hurt_time>0: pose = "recoil"
	elif attack_time>0 and has_blade:
		pose = "slash" if attack_direction=="attack" else ("slash_up" if attack_direction=="up" else "slash_down")
	elif dash_time>0: pose = "armed_dash" if has_blade else "unarmed_run"
	elif not is_on_floor(): pose = ("armed_jump" if velocity.y<0 else "armed_fall") if has_blade else ("unarmed_jump" if velocity.y<0 else "unarmed_fall")
	elif land_timer>0: pose = "armed_land" if has_blade else "unarmed_land"
	elif absf(velocity.x)>32: pose = "armed_run" if has_blade else "unarmed_run"
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
	combat_model.sword_visible = has_blade and pose in ["slash","slash_up","slash_down","recoil","death"]
	combat_model.sword_reach = world_ref.combat_state.reach_multiplier() if is_instance_valid(world_ref) else 1.0
	if pose in ["slash","slash_up","slash_down","recoil","death"]:
		var phase: float = 1.0-attack_time/0.255
		if pose=="recoil": phase = 1.0-hurt_time/0.25
		elif pose=="death": phase = death_visual_time/0.38
		combat_model.set_combat_pose(pose,clampf(phase,0,1),not is_on_floor(),run_sample)
	elif healing:
		combat_model.set_motion("heal",animation_age)
	elif dash_time>0:
		combat_model.set_motion("dash",run_sample)
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
	if is_instance_valid(head_collider): head_collider.position.x = 3*facing
	blade_light.visible = has_blade and attack_time>0
	blade_light.position = Vector2(facing*33,-40)
	_update_lantern_anchor()

func _update_lantern_anchor() -> void:
	if m19_ready and is_instance_valid(combat_model):
		lantern_light.position = to_local(combat_model.to_global(combat_model.lantern_center))
	else:
		super._update_lantern_anchor()

func get_hurtboxes() -> Array[Rect2]:
	return [Rect2(global_position+Vector2(-12,-52),Vector2(24,52)),Rect2(global_position+Vector2(3*facing-18,-88),Vector2(36,40))]

func get_visual_bounds() -> Rect2:
	return Rect2(global_position+Vector2(-56,-106),Vector2(112,110))

func strike_rect(_direction: String, _look: int) -> Rect2:
	if not m19_ready or not has_blade: return Rect2()
	var start: Vector2 = combat_model.to_global(combat_model.sword_start)
	var end: Vector2 = combat_model.to_global(combat_model.sword_end)
	return Rect2(start,end-start).abs().grow(4.0)
