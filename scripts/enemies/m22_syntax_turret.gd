extends CharacterBody2D
## Candelabra Sentinel: a planted, safe-body turret with a fixed-aim burst.
## Its long warning and open reload are independent from sword hit reactions.

const Bolt = preload("res://scripts/enemies/m22_ink_bolt.gd")
const ART_PATH := "res://assets/enemies/m22/syntax_turret.png"
const WINDUP_SECONDS := 0.85
const BURST_INTERVAL := 0.28
const RELOAD_SECONDS := 1.65
const BOLT_SPEED := 360.0
const NOTICE_DISTANCE := 650.0
const EYE := Vector2(0,-117)
var world_ref: Node
var hp := 4
var max_hp := 4
var damage := 1
var is_dead := false
var state := "scan"
var direction := -1
var attack_id := 0
var age := 0.0
var state_time := 0.0
var entry_grace := 1.25
var invulnerable := 0.0
var hit_flash := 0.0
var death_time := 0.0
var attack_cooldown := 0.0
var aim := Vector2.LEFT
var locked_target := Vector2.ZERO
var shots_fired := 0
var total_shots := 0
var projectiles: Array[Node2D] = []
var danger_zone := Rect2()
var protected_zones: Array[Rect2] = []
var _configured := false
var _defeat_notified := false
var _art: Texture2D
var _art_region := Rect2()

func setup(world: Node, spawn: Vector2, _limits: Vector2 = Vector2.ZERO) -> void:
	world_ref = world
	position = spawn
	_configured = true
	queue_redraw()

func configure_encounter(zone: Rect2, safe_zones: Array[Rect2] = []) -> void:
	danger_zone = zone
	protected_zones = safe_zones

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	add_to_group("m18_enemies")
	add_to_group("m22_syntax_turrets")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(62,158)
	var collision := CollisionShape2D.new()
	collision.name = "PlantedPedestal"
	collision.position = Vector2(0,-79)
	collision.shape = shape
	add_child(collision)
	if ResourceLoader.exists(ART_PATH):
		_art = load(ART_PATH) as Texture2D
		# Draw-region crop removes only transparent margins. The original PNG
		# stays byte-identical and the 741:1282 approved silhouette is rigid.
		_art_region = Rect2(230,10,741,1282)
	z_index = 4
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not _configured or not is_instance_valid(world_ref): return
	if not bool(world_ref.get("gameplay_active")): return
	age += delta
	if is_dead:
		death_time += delta
		modulate.a = clampf(1.0-death_time/0.45,0,1)
		if death_time >= 0.45: queue_free()
		return
	entry_grace = maxf(0, entry_grace-delta)
	invulnerable = maxf(0, invulnerable-delta)
	hit_flash = maxf(0, hit_flash-delta)
	attack_cooldown = maxf(0, attack_cooldown-delta)
	state_time = maxf(0, state_time-delta)
	var hero := world_ref.get("hero") as Node2D
	match state:
		"scan":
			if _can_attack(hero) and attack_cooldown <= 0:
				locked_target = hero.global_position + Vector2(0,-45)
				aim = (locked_target-(global_position+EYE)).normalized()
				direction = 1 if aim.x > 0 else -1
				_enter_state("windup", WINDUP_SECONDS)
				_play("parry_light")
		"windup":
			if not _can_attack(hero):
				_enter_state("reload", RELOAD_SECONDS)
			elif state_time <= 0:
				attack_id += 1
				shots_fired = 0
				_enter_state("burst", 0)
		"burst":
			if not _can_attack(hero):
				_enter_state("reload", RELOAD_SECONDS)
			elif state_time <= 0:
				_fire()
				shots_fired += 1
				if shots_fired >= 3: _enter_state("reload", RELOAD_SECONDS)
				else: state_time = BURST_INTERVAL
		"reload":
			if state_time <= 0:
				_enter_state("scan",0)
				attack_cooldown = 0.30
	velocity = Vector2.ZERO
	queue_redraw()

func _can_attack(hero: Node2D) -> bool:
	if is_dead or entry_grace > 0 or not is_instance_valid(hero) or not _is_on_screen(): return false
	if global_position.distance_to(hero.global_position) > NOTICE_DISTANCE: return false
	if absf(global_position.y-hero.global_position.y) > 200: return false
	if danger_zone.has_area() and not danger_zone.has_point(hero.global_position): return false
	for safe in protected_zones:
		if safe.has_point(hero.global_position): return false
	if world_ref.has_method("enemy_can_attack"):
		return bool(world_ref.enemy_can_attack(self))
	return true

func _is_on_screen() -> bool:
	var center := get_global_transform_with_canvas() * EYE
	return get_viewport_rect().grow(-36).has_point(center)

func projectile_can_continue() -> bool:
	# Entering the lower reading floor cancels existing ink as well as new
	# bursts; a shot may not trail a reader out of the optional gallery.
	return _can_attack(world_ref.get("hero") as Node2D)

func _enter_state(next: String, seconds: float) -> void:
	state = next
	state_time = seconds

func _fire() -> void:
	# The three directions are captured before the first shot. Moving after
	# the warning remains useful; the turret never tracks during the burst.
	var spread: float = [-0.055,0.0,0.055][shots_fired]
	var bolt := Bolt.new()
	get_parent().add_child(bolt)
	bolt.setup(world_ref,self,global_position+EYE+aim*29,aim.rotated(spread)*BOLT_SPEED)
	# A freed Node remains an invalid Object in a typed Array until removed.
	# A typed filter lambda attempts to cast that freed Object before its
	# validity guard can run, so prune indices without converting elements.
	for index in range(projectiles.size()-1,-1,-1):
		if not is_instance_valid(projectiles[index]): projectiles.remove_at(index)
	projectiles.append(bolt)
	total_shots += 1
	_play("swing")

func clear_projectiles() -> void:
	for bolt in projectiles:
		if is_instance_valid(bolt): bolt.consume()
	projectiles.clear()

func get_hitbox() -> Rect2:
	return Rect2() if is_dead else Rect2(global_position+Vector2(-43,-168),Vector2(86,168))

func danger_rect() -> Rect2:
	# The ornate frame is safe to touch. Only visible flying ink deals damage.
	return Rect2()

func clash_rect() -> Rect2:
	return Rect2()

func on_clash() -> bool:
	return false

func take_hit(amount: int, _from_x: float, _kind: String = "melee") -> bool:
	if is_dead or amount <= 0 or invulnerable > 0: return false
	hp = maxi(0,hp-amount)
	invulnerable = 0.10
	hit_flash = 0.09
	_play("hit")
	if hp <= 0: _die()
	queue_redraw()
	return true

func _die() -> void:
	is_dead = true
	state = "dead"
	collision_layer = 0
	collision_mask = 0
	clear_projectiles()
	if world_ref.has_method("emit_burst"):
		world_ref.emit_burst(global_position+EYE,Color("83dbe7"),20)
	if not _defeat_notified and world_ref.has_method("on_enemy_defeated"):
		_defeat_notified = true
		world_ref.on_enemy_defeated(self)

func _play(cue: String) -> void:
	if is_instance_valid(world_ref) and world_ref.has_method("play_sfx"):
		world_ref.play_sfx(cue)

func _draw() -> void:
	var warning := state == "windup"
	var progress := 1.0-state_time/WINDUP_SECONDS if warning else 0.0
	if warning:
		var muzzle := EYE+aim*30
		var reach := minf(510,locked_target.distance_to(global_position+EYE))
		draw_line(muzzle,muzzle+aim*reach,Color(0.41,0.83,0.91,0.12+0.20*progress),1.2,true)
		draw_arc(EYE,29+progress*5,0,TAU,40,Color(0.53,0.91,0.96,0.4+0.35*progress),1.4,true)
	if _art != null:
		var tint := Color(1.8,1.8,1.8) if hit_flash > 0 else Color.WHITE
		draw_texture_rect_region(_art,Rect2(-55.79,-193,111.58,193),_art_region,tint)
	else:
		_draw_candelabra()
	# The core remains visible at game scale and communicates reload honestly.
	var core := Color("a0edf0") if state != "reload" else Color("477481")
	if warning: core = core.lerp(Color("edffff"),progress)
	draw_colored_polygon(PackedVector2Array([EYE+Vector2(0,-13),EYE+Vector2(5,0),EYE+Vector2(0,13),EYE+Vector2(-5,0)]),core)
	if state == "reload":
		var fill := 1-state_time/RELOAD_SECONDS
		draw_arc(EYE,22,-PI*0.5,-PI*0.5+TAU*fill,32,Color(0.40,0.71,0.76,0.65),1.3,true)

func _draw_candelabra() -> void:
	var ink := Color("17222c") if hit_flash <= 0 else Color("dff9f5")
	var brass := Color("a18459")
	var paper := Color("d5c8ad")
	var body := PackedVector2Array([Vector2(-57,0),Vector2(-47,-12),Vector2(-30,-18),Vector2(-19,-79),Vector2(-27,-103),Vector2(-23,-132),Vector2(-9,-147),Vector2(-6,-177),Vector2(0,-193),Vector2(6,-177),Vector2(9,-147),Vector2(23,-132),Vector2(27,-103),Vector2(19,-79),Vector2(30,-18),Vector2(47,-12),Vector2(57,0)])
	draw_colored_polygon(body,ink)
	var closed := body.duplicate()
	closed.append(body[0])
	draw_polyline(closed,brass,1.8,true)
	for sign_value in [-1.0,1.0]:
		var side: float = sign_value
		draw_polyline(PackedVector2Array([Vector2(side*13,-102),Vector2(side*52,-123),Vector2(side*64,-146),Vector2(side*62,-157)]),brass,3.0,true)
		draw_colored_polygon(PackedVector2Array([Vector2(side*62,-178),Vector2(side*67,-162),Vector2(side*62,-155),Vector2(side*57,-162)]),Color("a0edf0"))
		draw_colored_polygon(PackedVector2Array([Vector2(side*45,-119),Vector2(side*58,-115),Vector2(side*57,-58),Vector2(side*49,-69),Vector2(side*43,-59)]),paper)
		draw_line(Vector2(side*50,-105),Vector2(side*50,-87),ink,1.5,true)
		draw_polyline(PackedVector2Array([Vector2(side*24,-18),Vector2(side*11,-71),Vector2(side*11,-88)]),brass,1.3,true)
	draw_colored_polygon(PackedVector2Array([Vector2(-9,-77),Vector2(9,-77),Vector2(14,-23),Vector2(2,-31),Vector2(-11,-23)]),paper)
	draw_circle(EYE,21,Color("08141d"))
	draw_arc(EYE,23,0,TAU,40,brass,2,true)
	draw_line(Vector2(-43,-10),Vector2(43,-10),brass,1.5,true)
