extends CharacterBody2D
## A warning first, then one dive onto the captured OLD landing point.
## setup(world, lower_cloak_anchor, horizontal_limits, floor_hint_y, attack_zone)
## Contact is resolved by the world; this actor never calls hero.hurt().
const ART_PATH := "res://assets/enemies/m22/popup_wraith.png"
const ART_REGION := Rect2(54,19,1448,986)
const ART_WIDTH := 136.0
const ART_RECT := Rect2(-120,-92.6077,136,92.6077)
const WINDUP_SECONDS := 0.65
const DIVE_SECONDS := 0.24
const RECOVER_SECONDS := 0.85
const RETURN_SECONDS := 0.60
const ARRIVAL_GRACE := 1.20
const NOTICE_DISTANCE := 340.0

var world_ref: Node
var hp: int = 3
var max_hp: int = 3
var damage: int = 1
var is_dead: bool = false
var state: String = "hover"
var direction: int = -1
var attack_id: int = 0
var state_time: float = 0.0
var entry_grace: float = ARRIVAL_GRACE
var attack_cooldown: float = 0.0
var invulnerable: float = 0.0
var hit_flash: float = 0.0
var age: float = 0.0
var death_time: float = 0.0
var home_position := Vector2.ZERO
var patrol_limits := Vector2(-INF,INF)
var floor_hint_y: float = INF
var attack_zone := Rect2()
var captured_target := Vector2.ZERO
var captured_hero_position := Vector2.ZERO
var marker_world_position := Vector2.ZERO
var target_valid: bool = false
var marker_visible: bool = false
var _art: Texture2D
var _configured: bool = false
var _defeat_notified: bool = false
var _segment_start := Vector2.ZERO
var _segment_elapsed: float = 0.0
var _hit_recoil := Vector2.ZERO

func setup(world: Node, spawn: Vector2, limits: Vector2 = Vector2(-INF,INF), landing_floor_y: float = INF, zone: Rect2 = Rect2()) -> void:
	world_ref = world
	position = spawn
	home_position = spawn
	patrol_limits = Vector2(minf(limits.x,limits.y),maxf(limits.x,limits.y))
	floor_hint_y = landing_floor_y
	attack_zone = zone
	entry_grace = ARRIVAL_GRACE
	_configured = true
	queue_redraw()

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	z_index = 4
	add_to_group("m18_enemies")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40,48)
	var collider := CollisionShape2D.new()
	collider.name = "PopupHoodBody"
	collider.shape = shape
	collider.position = Vector2(0,-54)
	add_child(collider)
	if ResourceLoader.exists(ART_PATH): _art = load(ART_PATH) as Texture2D
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _physics_process(delta: float) -> void:
	if not _configured or not is_instance_valid(world_ref) or not bool(world_ref.get("gameplay_active")): return
	age += delta
	if is_dead:
		death_time += delta
		modulate.a = maxf(0,1.0-death_time/0.42)
		if death_time>=0.42: queue_free()
		queue_redraw()
		return
	entry_grace = maxf(0,entry_grace-delta)
	invulnerable = maxf(0,invulnerable-delta)
	hit_flash = maxf(0,hit_flash-delta)
	attack_cooldown = maxf(0,attack_cooldown-delta)
	state_time = maxf(0,state_time-delta)
	_hit_recoil = _hit_recoil.move_toward(Vector2.ZERO,180*delta)
	if state in ["windup","dive"] and not _attack_allowed():
		_enter_state("recover",0.40)
	match state:
		"hover":
			var desired := home_position+Vector2(sin(age*0.9)*16,sin(age*1.7)*6)
			desired.x = clampf(desired.x,patrol_limits.x,patrol_limits.y)
			_move_to(desired+_hit_recoil*delta)
			var hero := _hero()
			if is_instance_valid(hero):
				var dx: float = hero.global_position.x-global_position.x
				if absf(dx)>12: direction = 1 if dx>0 else -1
				var dy: float = hero.global_position.y-global_position.y
				if entry_grace<=0 and attack_cooldown<=0 and absf(dx)<NOTICE_DISTANCE and dy>24 and dy<330 and _attack_allowed():
					if _capture_landing(hero):
						_enter_state("windup",WINDUP_SECONDS)
						_play("parry_light")
					else: attack_cooldown = 0.45
		"windup":
			velocity = Vector2.ZERO
			if state_time<=0:
				attack_id += 1
				_segment_start = global_position
				_segment_elapsed = 0
				_enter_state("dive",DIVE_SECONDS)
				_play("swing")
		"dive":
			_segment_elapsed = minf(DIVE_SECONDS,_segment_elapsed+delta)
			# Both segment endpoints were captured before the warning. No homing.
			var destination := _segment_start.lerp(captured_target,_segment_elapsed/DIVE_SECONDS)
			velocity = (destination-global_position)/maxf(delta,0.0001)
			var collision := move_and_collide(destination-global_position)
			if collision!=null or _segment_elapsed>=DIVE_SECONDS:
				_enter_state("recover",RECOVER_SECONDS)
				_play("parry_light")
		"recover","stagger":
			velocity = Vector2.ZERO
			if state_time<=0:
				_segment_start = global_position
				_segment_elapsed = 0
				_enter_state("return",RETURN_SECONDS)
		"return":
			_segment_elapsed = minf(RETURN_SECONDS,_segment_elapsed+delta)
			var t := smoothstep(0,1,_segment_elapsed/RETURN_SECONDS)
			var collision := _move_to(_segment_start.lerp(home_position,t))
			if _segment_elapsed>=RETURN_SECONDS:
				# An obstacle must never cause a teleport through level geometry.
				if collision or global_position.distance_to(home_position)>8: home_position=global_position
				attack_cooldown = 0.90
				_enter_state("hover",0)
	queue_redraw()

func _move_to(destination: Vector2) -> bool:
	return move_and_collide(destination-global_position)!=null

func _enter_state(next: String, seconds: float) -> void:
	state = next
	state_time = seconds
	marker_visible = next in ["windup","dive"] and target_valid
	if next not in ["dive"]: velocity=Vector2.ZERO

func _hero() -> Node2D:
	if not is_instance_valid(world_ref): return null
	return world_ref.get("hero") as Node2D

func _attack_allowed() -> bool:
	if is_dead or not is_instance_valid(world_ref) or not bool(world_ref.get("gameplay_active")) or not _is_on_screen(): return false
	var hero := _hero()
	if not is_instance_valid(hero): return false
	if attack_zone.has_area() and not attack_zone.has_point(hero.global_position): return false
	# The campaign guard owns arrival grace and protected reading/bench/UI zones.
	# It does not query danger_rect(), so the contact getter may use it too.
	if world_ref.has_method("enemy_can_attack"): return bool(world_ref.enemy_can_attack(self))
	return true

func _is_on_screen() -> bool:
	var point: Vector2 = get_global_transform_with_canvas()*Vector2(0,-58)
	return get_viewport_rect().grow(-28).has_point(point)

func _capture_landing(hero: Node2D) -> bool:
	target_valid = false
	captured_hero_position = hero.global_position
	var from := captured_hero_position-Vector2(0,4)
	var bottom := captured_hero_position.y+420
	if attack_zone.has_area(): bottom=minf(bottom,attack_zone.end.y)
	if is_finite(floor_hint_y): bottom=minf(bottom,floor_hint_y+24)
	if bottom<=from.y: return false
	var query := PhysicsRayQueryParameters2D.create(from,Vector2(from.x,bottom),1)
	query.exclude = [get_rid()]
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty(): return false
	var landing: Vector2 = result.position
	if attack_zone.has_area() and not attack_zone.grow(1).has_point(landing): return false
	# A hint bounds the search; it never creates an imaginary floor over a gap.
	if is_finite(floor_hint_y) and absf(landing.y-floor_hint_y)>80: return false
	captured_target = landing
	marker_world_position = landing-Vector2(0,2)
	target_valid = true
	if absf(landing.x-global_position.x)>8: direction=1 if landing.x>global_position.x else -1
	return true

func get_hitbox() -> Rect2:
	return Rect2() if is_dead else Rect2(global_position+Vector2(-22,-82),Vector2(44,58))

func danger_rect() -> Rect2:
	if state!="dive" or not _attack_allowed(): return Rect2()
	return Rect2(global_position+Vector2(-23,-82),Vector2(46,58))

func clash_rect() -> Rect2:
	if state!="dive" or not _attack_allowed(): return Rect2()
	return Rect2(global_position+Vector2(-18,-53),Vector2(36,25))

func on_clash() -> bool:
	if state!="dive" or not _attack_allowed(): return false
	_enter_state("stagger",0.42)
	attack_cooldown = 1.0
	hit_flash = 0.08
	return true

func take_hit(amount: int, from_x: float, _kind: String = "melee") -> bool:
	if is_dead or amount<=0 or invulnerable>0: return false
	hp = maxi(0,hp-amount)
	invulnerable = 0.12
	hit_flash = 0.09
	if state=="hover": _hit_recoil=Vector2(48 if from_x<global_position.x else -48,-12)
	_play("hit")
	if hp<=0: _die()
	queue_redraw()
	return true

func _die() -> void:
	is_dead = true
	state = "dead"
	marker_visible = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if is_instance_valid(world_ref):
		if world_ref.has_method("emit_burst"): world_ref.emit_burst(global_position+Vector2(0,-58),Color("88dce6"),14)
		if not _defeat_notified and world_ref.has_method("on_enemy_defeated"):
			_defeat_notified = true
			world_ref.on_enemy_defeated(self)

func _play(cue: String) -> void:
	if is_instance_valid(world_ref) and world_ref.has_method("play_sfx"): world_ref.play_sfx(cue)

func get_visual_bounds() -> Rect2:
	return Rect2(global_position+Vector2(-120 if direction>0 else -16,-94),Vector2(136,96))

func _draw() -> void:
	if marker_visible:
		var marker := to_local(marker_world_position)
		var pulse := 0.5+sin(age*19)*0.5
		var points := PackedVector2Array()
		for i in range(33):
			var theta := TAU*float(i)/32
			points.append(marker+Vector2(cos(theta)*25,sin(theta)*5))
		draw_colored_polygon(points,Color(0.14,0.63,0.71,0.10+pulse*0.07))
		draw_polyline(points,Color(0.54,0.91,0.94,0.55+pulse*0.25),1.3,true)
		for offset in [-1,1]: draw_line(marker+Vector2(offset*30,0),marker+Vector2(offset*36,0),Color("b7e9e7"),1.2,true)
	var angle := sin(age*1.6)*0.018 if state=="hover" else (-0.05 if state in ["recover","stagger"] else 0.0)
	var stretch := Vector2(0.96,1.025) if state=="windup" else (Vector2(0.96,1.04) if state=="dive" else Vector2.ONE)
	draw_set_transform(Vector2.ZERO,angle,Vector2(float(direction),1)*stretch)
	if _art!=null:
		var tint := Color(1.8,1.8,1.8,1) if hit_flash>0 else Color.WHITE
		draw_texture_rect_region(_art,ART_RECT,ART_REGION,tint)
	else:
		# Native development fallback shares the pointed window/core silhouette.
		var hood := PackedVector2Array([Vector2(-20,-88),Vector2(18,-78),Vector2(15,-52),Vector2(0,-24),Vector2(-17,-51)])
		draw_colored_polygon(hood,Color("d5c9a8"))
		draw_colored_polygon(PackedVector2Array([Vector2(-13,-78),Vector2(11,-73),Vector2(9,-52),Vector2(0,-34),Vector2(-11,-54)]),Color("101824"))
		draw_circle(Vector2(-4,-62),3,Color("8ee4ea"))
		draw_circle(Vector2(5,-60),2.5,Color("8ee4ea"))
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
