extends CharacterBody2D
class_name LastLecturePlayer

# LAST LECTURE — M12 unified locomotion model, Godot 4.x actor.
# The player is *not* holding a sword until the Debug Blade is collected.
# Single-model, clean-lined layered illustration; every frame uses the same feet baseline.
# Keyframe animation is built from editable authored vector layers, not traced/game-ripped sprites.
const SPEED: float = 300.0
const GROUND_ACCEL: float = 2650.0
const AIR_ACCEL: float = 1950.0
const JUMP_FORCE: float = -790.0
const GRAVITY: float = 2050.0
const DASH_SPEED: float = 900.0
const ART_SCALE: float = 0.40
const ART_FOOT_Y: float = 456.0

const MotionLibrary = preload("res://scripts/warden_motion_m12.gd")

var world_ref: Node = null
var facing: int = 1
var max_hp: int = 6
var hp: int = 6
var energy: float = 100.0
var has_blade: bool = false
var has_code_slash: bool = false
var credits: int = 0
var invulnerable: float = 0.0
var hurt_time: float = 0.0
var attack_time: float = 0.0
var attack_cooldown: float = 0.0
var attack_direction: String = "attack"
var dash_time: float = 0.0
var dash_cooldown: float = 0.0
var parry_time: float = 0.0
var parry_cooldown: float = 0.0
var jump_grace: float = 0.0
var jump_buffer: float = 0.0
var animation_age: float = 0.0
var current_pose: String = ""
var lantern_sprite: AnimatedSprite2D
var land_timer: float = 0.0
var was_grounded: bool = false
var visual_blade_state: bool = false
var hit_fired: bool = false
var dash_afterimage_timer: float = 0.0
var turn_lock: float = 0.0
var walking_step_timer: float = 0.0
var stop_timer: float = 0.0
var was_ground_running: bool = false
var lantern_light: PointLight2D
var blade_light: PointLight2D
var sword_trail_soft: Line2D
var sword_trail_core: Line2D
var art_anchors: Dictionary = {}

func _ready() -> void:
	var rig_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://WARDEN_M12_RIG_AUDIT.json"))
	for record in rig_data.get("frames", []):
		art_anchors[str(record.file).get_file().get_basename()] = record.joints.torso[0]
	collision_layer = 2
	collision_mask = 1
	var collider := CollisionShape2D.new()
	collider.name = "StableGameplayCollider"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(30, 58)
	collider.shape = shape
	collider.position = Vector2(0, -29)
	add_child(collider)

	lantern_sprite = AnimatedSprite2D.new()
	lantern_sprite.name = "LanternWarden_M12_Unified"
	lantern_sprite.centered = true
	lantern_sprite.position = Vector2(0.0, (256.0 - ART_FOOT_Y) * ART_SCALE)
	lantern_sprite.scale = Vector2.ONE * ART_SCALE
	lantern_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	lantern_sprite.z_index = 5
	var library: SpriteFrames = MotionLibrary.build()
	lantern_sprite.sprite_frames = library
	add_child(lantern_sprite)
	lantern_sprite.frame_changed.connect(_on_art_frame_changed)
	# A restrained, always-on lantern emission: palette matches the selected design.
	lantern_light = PointLight2D.new()
	lantern_light.name = "LanternCoreLight"
	lantern_light.texture = load("res://assets/warden_clean/glow.png")
	lantern_light.texture_scale = 1.5
	lantern_light.energy = 0.35
	lantern_light.position = Vector2(6, -112)
	add_child(lantern_light)
	blade_light = PointLight2D.new()
	blade_light.name = "DebugBladeLight"
	blade_light.texture = load("res://assets/warden_clean/glow.png")
	blade_light.texture_scale = 1.1
	blade_light.energy = 0.20
	blade_light.position = Vector2(35, -35)
	blade_light.visible = false
	add_child(blade_light)
	# Sword arc is a separate effect. It is never baked into movement sprites,
	# so the player cannot accidentally show an extra character or duplicate blade.
	sword_trail_soft = Line2D.new()
	sword_trail_soft.name = "SoftSwordArc"
	sword_trail_soft.width = 12.0
	sword_trail_soft.default_color = Color(0.32, 0.86, 1.0, 0.20)
	sword_trail_soft.z_index = 8
	sword_trail_soft.antialiased = true
	add_child(sword_trail_soft)
	sword_trail_core = Line2D.new()
	sword_trail_core.name = "SharpSwordArc"
	sword_trail_core.width = 3.8
	sword_trail_core.default_color = Color(0.92, 1.0, 1.0, 0.85)
	sword_trail_core.z_index = 9
	sword_trail_core.antialiased = true
	add_child(sword_trail_core)
	lantern_sprite.play("unarmed_idle")
	current_pose = "unarmed_idle"
	was_grounded = is_on_floor()

func _physics_process(delta: float) -> void:
	if world_ref == null:
		return
	animation_age += delta
	if not world_ref.gameplay_active:
		velocity = Vector2.ZERO
		_update_animation()
		_update_sword_trail()
		return
	invulnerable = maxf(0.0, invulnerable - delta)
	hurt_time = maxf(0.0, hurt_time - delta)
	attack_time = maxf(0.0, attack_time - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	dash_time = maxf(0.0, dash_time - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	parry_time = maxf(0.0, parry_time - delta)
	parry_cooldown = maxf(0.0, parry_cooldown - delta)
	land_timer = maxf(0.0, land_timer - delta)
	turn_lock = maxf(0.0, turn_lock - delta)
	energy = minf(100.0, energy + 6.0 * delta)
	jump_grace = 0.11 if is_on_floor() else maxf(0.0, jump_grace - delta)
	jump_buffer = 0.13 if Input.is_action_just_pressed("jump") else maxf(0.0, jump_buffer - delta)

	# Save state owns the weapon. We never show an equipped blade before the pickup.
	if has_blade != visual_blade_state:
		visual_blade_state = has_blade
		current_pose = ""
		if has_blade:
			world_ref.emit_burst(global_position + Vector2(0, -50), Color("82e9f8"), 18)

	if jump_buffer > 0.0 and jump_grace > 0.0 and hurt_time <= 0.0:
		velocity.y = JUMP_FORCE
		jump_grace = 0.0
		jump_buffer = 0.0
		land_timer = 0.0
		world_ref.play_sfx("jump")
		world_ref.emit_burst(global_position + Vector2(0, -4), Color("9be7ff"), 9)
	if Input.is_action_just_pressed("parry") and parry_cooldown <= 0.0 and hurt_time <= 0.0:
		if has_blade:
			parry_time = 0.19
			parry_cooldown = 0.62
			world_ref.play_sfx("parry_light")
		else:
			world_ref.show_tip("First obtain the Debug Blade to parry / احصل على السيف للصد")
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0 and hurt_time <= 0.0:
		dash_time = 0.16
		dash_cooldown = 0.78
		invulnerable = maxf(invulnerable, 0.12)
		dash_afterimage_timer = 0.0
		world_ref.play_sfx("dash")
		world_ref.emit_burst(global_position + Vector2(0, -26), Color("70d9ff"), 13)
	if Input.is_action_just_pressed("attack") and attack_cooldown <= 0.0 and hurt_time <= 0.0:
		_start_attack()
	if Input.is_action_just_pressed("spell") and has_code_slash and energy >= 20.0:
		energy -= 20.0
		world_ref.cast_code_slash(global_position + Vector2(facing * 34, -34), facing)

	var input_dir: float = Input.get_axis("move_left", "move_right")
	if absf(input_dir) > 0.05:
		var requested_facing: int = 1 if input_dir > 0.0 else -1
		if requested_facing != facing and dash_time <= 0.0:
			facing = requested_facing
			turn_lock = 0.045
	if dash_time > 0.0:
		velocity.x = DASH_SPEED * facing
		velocity.y = 0.0
		dash_afterimage_timer -= delta
		if dash_afterimage_timer <= 0.0:
			dash_afterimage_timer = 0.042
			# No duplicate whole-character echo: it looked like a second broken sprite in V3.
			# Keep the small SFX and blue burst from the dash entry instead.
	else:
		var target_speed: float = input_dir * SPEED
		velocity.x = move_toward(velocity.x, target_speed, (GROUND_ACCEL if is_on_floor() else AIR_ACCEL) * delta)
		velocity.y = minf(velocity.y + GRAVITY * delta, 980.0)
	move_and_slide()
	# Run -> grounded stop -> idle. Never swap instantly into a different front-facing model.
	var grounded_running: bool = is_on_floor() and absf(velocity.x) > 32.0
	if was_ground_running and not grounded_running and absf(input_dir) < 0.05 and is_on_floor() and hurt_time <= 0.0:
		stop_timer = 0.105
	elif grounded_running or not is_on_floor() or absf(input_dir) > 0.05:
		stop_timer = 0.0
	was_ground_running = grounded_running
	if stop_timer > 0.0:
		stop_timer = maxf(0.0, stop_timer - delta)
	if is_on_floor() and not was_grounded:
		land_timer = 0.12
		world_ref.emit_burst(global_position + Vector2(0, -2), Color("8499a6"), 6)
	was_grounded = is_on_floor()
	position.x = clampf(position.x, 18.0, 1780.0)
	if position.y > 850.0:
		world_ref.player_fell()
	_update_animation()
	_update_sword_trail()

func _start_attack() -> void:
	if not has_blade:
		world_ref.show_tip("Find the Debug Blade first! / ابحث عن السيف أولاً")
		return
	if Input.is_action_pressed("look_up"):
		attack_direction = "up"
	elif Input.is_action_pressed("look_down") and not is_on_floor():
		attack_direction = "down"
	else:
		attack_direction = "attack"
	attack_time = 0.255
	attack_cooldown = 0.275
	hit_fired = false
	current_pose = ""
	# Sound starts at wind-up; real damage occurs on keyframe 2 (not on input).
	world_ref.play_sfx("swing")

func _on_art_frame_changed() -> void:
	_update_lantern_anchor()
	if not world_ref or not world_ref.gameplay_active:
		return
	if hit_fired or attack_time <= 0.0:
		return
	var active_pose: String = "slash" if attack_direction == "attack" else ("slash_up" if attack_direction == "up" else "slash_down")
	if lantern_sprite.animation == active_pose and lantern_sprite.frame >= 3:
		hit_fired = true
		world_ref.hero_strike(attack_direction, facing)

func _update_lantern_anchor() -> void:
	if lantern_light == null or lantern_sprite == null or lantern_sprite.sprite_frames == null:
		return
	var texture: Texture2D = lantern_sprite.sprite_frames.get_frame_texture(lantern_sprite.animation, lantern_sprite.frame)
	if texture == null:
		return
	var key: String = texture.resource_path.get_file().get_basename()
	if art_anchors.has(key):
		var point: Array = art_anchors[key]
		var local_point := Vector2(float(point[0]) - 256.0, float(point[1]) - 42.0 - ART_FOOT_Y) * ART_SCALE
		local_point.x *= float(facing)
		lantern_light.position = local_point

func _update_sword_trail() -> void:
	# The authored animation has a short slash flash on contact frames 2-4.
	# Do not overlay a second giant, persistent Line2D arc (V3 defect).
	if sword_trail_core != null:
		sword_trail_core.visible = false
	if sword_trail_soft != null:
		sword_trail_soft.visible = false

func _spawn_dash_echo() -> void:
	if lantern_sprite == null or lantern_sprite.sprite_frames == null:
		return
	var pose: String = lantern_sprite.animation
	var tex: Texture2D = lantern_sprite.sprite_frames.get_frame_texture(pose, lantern_sprite.frame)
	if tex == null:
		return
	var afterimage := Sprite2D.new()
	afterimage.texture = tex
	afterimage.centered = true
	afterimage.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	afterimage.scale = Vector2.ONE * ART_SCALE
	afterimage.flip_h = facing < 0
	afterimage.modulate = Color(0.38, 0.92, 1.0, 0.24)
	afterimage.z_index = 3
	get_parent().add_child(afterimage)
	afterimage.global_position = global_position + lantern_sprite.position
	var fade: Tween = create_tween()
	fade.tween_property(afterimage, "modulate:a", 0.0, 0.15)
	fade.tween_callback(afterimage.queue_free)

func hurt(amount: int, attack_x: float) -> void:
	if not world_ref.gameplay_active:
		return
	if has_blade and parry_time > 0.0:
		parry_time = 0.0
		world_ref.on_parry(attack_x)
		return
	if dash_time > 0.0:
		energy = minf(100.0, energy + 18.0)
		world_ref.on_perfect_dodge()
		return
	if invulnerable > 0.0:
		return
	hp = maxi(0, hp - amount)
	hurt_time = 0.25
	invulnerable = 1.05
	velocity.x = -280.0 if attack_x > position.x else 280.0
	velocity.y = -260.0
	world_ref.play_sfx("hurt")
	world_ref.emit_burst(global_position + Vector2(0, -32), Color("ef6885"), 14)
	if hp <= 0:
		world_ref.on_player_death()

func _update_animation() -> void:
	if lantern_sprite == null:
		return
	var pose: String = "armed_ready" if has_blade else "unarmed_idle"
	if hp <= 0:
		pose = "death"
	elif hurt_time > 0.0:
		pose = "recoil" if has_blade else "unarmed_land"
	elif has_blade and parry_time > 0.0:
		pose = "parry"
	elif attack_time > 0.0 and has_blade:
		pose = "slash" if attack_direction == "attack" else ("slash_up" if attack_direction == "up" else "slash_down")
	elif dash_time > 0.0:
		pose = "armed_dash" if has_blade else "unarmed_run"
	elif not is_on_floor():
		pose = ("armed_jump" if velocity.y < 0.0 else "armed_fall") if has_blade else ("unarmed_jump" if velocity.y < 0.0 else "unarmed_fall")
	elif land_timer > 0.0:
		# A short M12 landing pose; physics remains active.
		pose = "armed_land" if has_blade else "unarmed_land"
	elif absf(velocity.x) > 32.0:
		pose = "armed_run" if has_blade else "unarmed_run"
	elif stop_timer > 0.0:
		pose = "armed_stop" if has_blade else "unarmed_stop"
	lantern_sprite.flip_h = facing < 0
	_update_lantern_anchor()
	blade_light.visible = has_blade and (attack_time > 0.0 or parry_time > 0.0)
	blade_light.position.x = float(facing) * 35.0
	if pose != current_pose:
		current_pose = pose
		lantern_sprite.play(pose)
	# Keep texture scale and floor pivot fixed across all frames; only the alpha changes.
	lantern_sprite.modulate = Color(1,1,1,0.58) if invulnerable > 0.0 and int(animation_age * 16.0) % 2 == 0 else Color.WHITE
