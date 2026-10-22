extends CharacterBody2D
class_name M18GlitchLarva
## First learned encounter: a readable, fixed-direction ground lunge.
## The stage resolves sword/clash/contact in that order. This actor deliberately
## never calls hero.hurt(): its soft body is safe and only danger_rect() hurts.

const ART_PATH := "res://assets/enemies/m18/glitch_larva.png"
const ART_REGION := Rect2(40.0, 215.0, 1720.0, 585.0)
const GRAVITY := 2050.0
const CRAWL_SPEED := 54.0
const LUNGE_SPEED := 510.0
const WINDUP_SECONDS := 0.45
const LUNGE_SECONDS := 0.24
const RECOVER_SECONDS := 0.65
const NOTICE_DISTANCE := 280.0

var world_ref: Node
var hp: int = 3
var max_hp: int = 3
var damage: int = 1
var is_dead: bool = false
var state: String = "crawl"
var direction: int = -1
var attack_id: int = 0
var patrol_limits := Vector2(900.0, 1450.0)
var entry_grace: float = 1.0
var age: float = 0.0
var invulnerable: float = 0.0
var hit_flash: float = 0.0
var hit_recoil: float = 0.0
var death_time: float = 0.0
var state_time: float = 0.0
var attack_cooldown: float = 0.0
var _art: Texture2D
var _configured: bool = false
var _defeat_notified: bool = false

func setup(world: Node, spawn: Vector2, limits: Vector2 = Vector2(900.0, 1450.0)) -> void:
	world_ref = world
	position = spawn
	patrol_limits = Vector2(minf(limits.x, limits.y), maxf(limits.x, limits.y))
	_configured = true
	if is_inside_tree():
		queue_redraw()

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	add_to_group("m18_enemies")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(78.0, 30.0)
	var collision := CollisionShape2D.new()
	collision.name = "GroundBody"
	collision.shape = shape
	collision.position = Vector2(0.0, -15.0)
	add_child(collision)
	if ResourceLoader.exists(ART_PATH):
		_art = load(ART_PATH) as Texture2D
	z_index = 4
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not _configured or not is_instance_valid(world_ref):
		return
	if not bool(world_ref.get("gameplay_active")):
		return
	age += delta
	if is_dead:
		death_time += delta
		modulate.a = clampf(1.0 - death_time / 0.40, 0.0, 1.0)
		if death_time >= 0.40:
			queue_free()
		queue_redraw()
		return
	entry_grace = maxf(0.0, entry_grace - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	hit_recoil = move_toward(hit_recoil, 0.0, 1350.0 * delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	state_time = maxf(0.0, state_time - delta)
	var hero: Node2D = world_ref.get("hero") as Node2D
	var target_speed: float = 0.0
	match state:
		"crawl":
			if is_instance_valid(hero):
				var dx: float = hero.global_position.x - global_position.x
				var dy: float = hero.global_position.y - global_position.y
				if absf(dx) > 95.0 and absf(dx) < 430.0:
					direction = 1 if dx > 0.0 else -1
				if _can_start_attack(hero) and absf(dx) < NOTICE_DISTANCE and absf(dy) < 95.0:
					direction = 1 if dx > 0.0 else -1
					_enter_state("windup", WINDUP_SECONDS)
					_play("parry_light")
			if state == "crawl":
				if not _can_move(direction):
					direction *= -1
				target_speed = float(direction) * CRAWL_SPEED if _can_move(direction) else 0.0
		"windup":
			# Facing stays fixed from the warning onward, so jumping over the
			# jaw or retreating is a real choice, not defeated by auto-aim.
			if state_time <= 0.0:
				if _can_continue_attack():
					attack_id += 1
					_enter_state("lunge", LUNGE_SECONDS)
					_play("swing")
				else:
					_enter_state("recover", RECOVER_SECONDS)
		"lunge":
			if state_time <= 0.0 or not _can_move(direction):
				_enter_state("recover", RECOVER_SECONDS)
			else:
				target_speed = float(direction) * LUNGE_SPEED
		"recover", "stagger":
			if state_time <= 0.0:
				_enter_state("crawl", 0.0)
				attack_cooldown = 0.30
	velocity.x = target_speed + hit_recoil * (0.22 if state == "lunge" else 1.0)
	velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)
	move_and_slide()
	position.x = clampf(position.x, patrol_limits.x, patrol_limits.y)
	if is_on_wall() and state == "lunge":
		_enter_state("recover", RECOVER_SECONDS)
	queue_redraw()

func _enter_state(next: String, seconds: float) -> void:
	state = next
	state_time = seconds

func _can_start_attack(hero: Node2D) -> bool:
	return not is_dead and entry_grace <= 0.0 and attack_cooldown <= 0.0 and is_on_floor() and is_instance_valid(hero) and _is_on_screen()

func _can_continue_attack() -> bool:
	return not is_dead and _is_on_screen() and _can_move(direction)

func _is_on_screen() -> bool:
	# Canvas coordinates include the real camera transform; there is no
	# guessed world-distance visibility that can trigger an offscreen lunge.
	var center: Vector2 = get_global_transform_with_canvas() * Vector2(0.0, -28.0)
	return get_viewport_rect().grow(-36.0).has_point(center)

func _can_move(towards: int) -> bool:
	var projected_x: float = position.x + float(towards) * 48.0
	if projected_x < patrol_limits.x or projected_x > patrol_limits.y:
		return false
	if not is_inside_tree():
		return false
	# Stop before an edge rather than dropping to an unseen lower platform.
	var from := global_position + Vector2(float(towards) * 50.0, -12.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 48.0), 1)
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func get_hitbox() -> Rect2:
	return Rect2() if is_dead else Rect2(global_position + Vector2(-52.0, -52.0), Vector2(104.0, 52.0))

func danger_rect() -> Rect2:
	if is_dead or state != "lunge":
		return Rect2()
	var left: float = 32.0 if direction > 0 else -72.0
	return Rect2(global_position + Vector2(left, -46.0), Vector2(40.0, 39.0))

func clash_rect() -> Rect2:
	# Only the forward, active jaw can meet the sword. Striking the safe
	# flank remains an ordinary damaging hit, never a gratuitous parry.
	if is_dead or state != "lunge":
		return Rect2()
	var left: float = 43.0 if direction > 0 else -73.0
	return Rect2(global_position + Vector2(left, -44.0), Vector2(30.0, 25.0))

func on_clash() -> bool:
	if is_dead or state != "lunge":
		return false
	_enter_state("stagger", 0.38)
	attack_cooldown = 0.60
	velocity.x = 0.0
	hit_recoil = -float(direction) * 90.0
	hit_flash = 0.07
	return true

func take_hit(amount: int, from_x: float, _kind: String = "melee") -> bool:
	if is_dead or amount <= 0 or invulnerable > 0.0:
		return false
	hp = maxi(0, hp - amount)
	invulnerable = 0.10
	hit_flash = 0.09
	# Recoil is short and does not reset telegraphs or recovery. Repeated
	# swings cannot keep restarting an enemy's entire attack state.
	hit_recoil = 130.0 if from_x < global_position.x else -130.0
	if hp <= 0:
		_die()
	else:
		_play("hit")
	queue_redraw()
	return true

func _die() -> void:
	is_dead = true
	state = "dead"
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if world_ref.has_method("emit_burst"):
		world_ref.emit_burst(global_position + Vector2(0.0, -28.0), Color("6bd6e8"), 18)
	_play("hit")
	if not _defeat_notified and world_ref.has_method("on_enemy_defeated"):
		_defeat_notified = true
		world_ref.on_enemy_defeated(self)

func _play(cue: String) -> void:
	if is_instance_valid(world_ref) and world_ref.has_method("play_sfx"):
		world_ref.play_sfx(cue)

func _draw() -> void:
	var warning: bool = state == "windup"
	var striking: bool = state == "lunge"
	var pulse: float = 0.5 + sin(age * (24.0 if warning else 4.0)) * 0.5
	# The warning flicker is a cosmetic deformation around the planted
	# feet. It never teleports a collision volume or hides the actual jaw.
	var squash := Vector2(1.0 + (0.05 if striking else -0.045 if warning else 0.0), 0.93 if warning else 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(direction), 1.0) * squash)
	for i in range(4, 0, -1):
		var a: float = float(i) / 4.0
		_draw_ellipse_shape(Vector2(-5.0, -1.0), Vector2(55.0 + a * 5.0, 4.0 + a), Color(0.015, 0.022, 0.030, 0.05))
	for i in range(4):
		var x: float = -40.0 + float(i) * 22.0
		var step: float = sin(age * (17.0 if striking else 8.0) + float(i) * 1.6)
		draw_polyline(PackedVector2Array([Vector2(x, -13.0), Vector2(x - 10.0, -6.0 + step * 2.0), Vector2(x - 17.0, -1.0)]), Color("17242b"), 3.0, true)
	if _art != null:
		var tint := Color(1.8, 1.8, 1.8, 1.0) if hit_flash > 0.0 else Color.WHITE
		# Crop the artist's transparent canvas margin; preserve the actual
		# long, low proportions and align the opaque feet to the floor.
		var height: float = 140.0 * ART_REGION.size.y / ART_REGION.size.x
		draw_texture_rect_region(_art, Rect2(-70.0, -height, 140.0, height), ART_REGION, tint)
	else:
		_draw_fallback(pulse)
	if warning:
		draw_arc(Vector2(44.0, -36.0), 16.0 + pulse * 3.0, -1.6, 1.6, 20, Color(0.45, 0.92, 1.0, 0.42 + pulse * 0.3), 1.4, true)
		draw_line(Vector2(55.0, -19.0), Vector2(70.0, -19.0), Color(0.6, 0.95, 1.0, 0.65), 1.5, true)
	if striking:
		draw_line(Vector2(-67.0, -27.0), Vector2(-102.0, -27.0), Color(0.32, 0.78, 0.91, 0.25), 2.5, true)
		draw_line(Vector2(-53.0, -14.0), Vector2(-83.0, -14.0), Color(0.32, 0.78, 0.91, 0.20), 1.4, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_fallback(pulse: float) -> void:
	# Editable original vector fallback remains coherent at game scale if a
	# resource is absent during development, rather than a placeholder box.
	var outline := PackedVector2Array([Vector2(-64,-8),Vector2(-49,-32),Vector2(-23,-45),Vector2(-5,-39),Vector2(14,-52),Vector2(40,-57),Vector2(58,-43),Vector2(64,-22),Vector2(44,-8),Vector2(10,-3),Vector2(-20,-5)])
	draw_colored_polygon(outline, Color("101b24") if hit_flash <= 0.0 else Color("def8f2"))
	draw_polyline(outline, Color("243741"), 2.0, true)
	var paper_colors := [Color("a99e80"),Color("d2c7a7"),Color("6b7775"),Color("e4d8b5")]
	for i in range(5):
		var x: float = -48.0 + float(i) * 18.0
		var y: float = -24.0 - sin(float(i) * 1.5) * 8.0
		var sheet := PackedVector2Array([Vector2(x-11,y+8),Vector2(x-9,y-18),Vector2(x+10,y-13),Vector2(x+15,y+4),Vector2(x+5,y),Vector2(x+1,y+13)])
		draw_colored_polygon(sheet, paper_colors[i % paper_colors.size()])
		draw_line(Vector2(x-5,y-9),Vector2(x+5,y-7),Color("485458"),0.8,true)
		draw_line(Vector2(x-5,y-4),Vector2(x+3,y-2),Color("485458"),0.8,true)
	_draw_ellipse_shape(Vector2(43,-34),Vector2(13,17),Color("0a151e"))
	for i in range(4,0,-1):
		draw_circle(Vector2(44,-34),float(i)*4.0,Color(0.25,0.75,0.87,0.06))
	var flame := PackedVector2Array([Vector2(42,-21),Vector2(35,-31),Vector2(42,-47),Vector2(45,-37),Vector2(50,-43),Vector2(52,-29),Vector2(47,-22)])
	draw_colored_polygon(flame,Color("7deaf1"))
	draw_line(Vector2(-34,-48),Vector2(-26,-48),Color(0.36,0.77,0.88,0.35+pulse*0.15),1.7,true)
	draw_line(Vector2(-11,-58),Vector2(-5,-58),Color(0.36,0.77,0.88,0.45),1.7,true)

func _draw_ellipse_shape(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle: float = TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radii)
	draw_colored_polygon(points, color)
