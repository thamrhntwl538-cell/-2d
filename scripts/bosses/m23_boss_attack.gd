extends Node2D
## Every dangerous shape is also its visible luminous shape. Glow is cosmetic.
## Detached attack nodes stop with gameplay and can be cleared by the stage.
const Sweep = preload("res://scripts/enemies/m22_ink_bolt.gd")
var world_ref: Node
var source_ref: WeakRef
var kind := "bolt"
var age := 0.0
var warning_seconds := 0.0
var active_seconds := 0.5
var fade_seconds := 0.18
var travel := Vector2.ZERO
var damage_amount := 1
var width := 74.0
var height := 330.0
var spent := false
var active := false
var was_blocked := false
var hero_hits := 0

func setup(world: Node, source: Node2D, attack_kind: String, origin: Vector2, options: Dictionary = {}) -> void:
	world_ref = world
	source_ref = weakref(source)
	kind = attack_kind
	global_position = origin
	warning_seconds = float(options.get("warning",0.0))
	active_seconds = float(options.get("duration",3.2 if kind=="bolt" else .48))
	travel = options.get("velocity",Vector2.ZERO)
	damage_amount = int(options.get("damage",1))
	width = float(options.get("width",74.0 if kind=="pillar" else 68.0))
	height = float(options.get("height",330.0 if kind=="pillar" else 18.0))
	add_to_group("m23_boss_attacks")
	z_index = 7
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unlit
	queue_redraw()

func _physics_process(delta: float) -> void:
	if spent or not is_instance_valid(world_ref): return
	if not bool(world_ref.get("gameplay_active")): return
	var source: Node2D = source_ref.get_ref() as Node2D if source_ref != null else null
	if not is_instance_valid(source) or bool(source.get("is_dead")):
		consume()
		return
	if source.has_method("attacks_allowed") and not bool(source.attacks_allowed()):
		consume()
		return
	age += delta
	active = age >= warning_seconds and age < warning_seconds+active_seconds
	if age >= warning_seconds+active_seconds+fade_seconds:
		consume()
		return
	if active:
		# Match the stage's melee-before-contact ordering even when a detached
		# projectile is processed before the boss actor in the scene hierarchy.
		var hero := world_ref.get("hero") as Node2D
		if is_instance_valid(hero) and world_ref.has_method("hero_strike") and float(hero.get("active_strike_time"))>0:
			world_ref.hero_strike(str(hero.get("attack_direction")),int(hero.get("facing")))
			if spent or bool(source.get("is_dead")) or not bool(world_ref.get("gameplay_active")): return
		if kind in ["bolt","chain"]:
			_move_swept(delta,source,hero)
		elif kind=="pillar":
			_hurt_overlaps(hero,damage_rect(),source)
	queue_redraw()

func _move_swept(delta: float, source: Node2D, hero: Node2D) -> void:
	var start := global_position
	var finish := start+travel*delta
	var query := PhysicsRayQueryParameters2D.create(start,finish,1)
	var terrain := get_world_2d().direct_space_state.intersect_ray(query)
	var clipped: Vector2 = terrain.get("position",finish)
	if is_instance_valid(hero) and hero.has_method("get_hurtboxes"):
		for hurtbox in hero.get_hurtboxes():
			var margin := Vector2(7,7) if kind=="bolt" else Vector2(width*.5,height*.5)
			var expanded := Rect2((hurtbox as Rect2).position-margin,(hurtbox as Rect2).size+margin*2)
			if Sweep.segment_hits_box(start,clipped,expanded):
				hero.hurt(damage_amount,source.global_position.x)
				hero_hits += 1
				if kind=="bolt":
					consume()
					return
				break
	global_position = clipped
	if not terrain.is_empty():
		was_blocked = true
		if world_ref.has_method("emit_burst"): world_ref.emit_burst(clipped,Color("a2eff0"),4)
		consume()

func _hurt_overlaps(hero: Node2D, rect: Rect2, source: Node2D) -> void:
	if not is_instance_valid(hero) or not hero.has_method("get_hurtboxes"): return
	for hurtbox in hero.get_hurtboxes():
		if rect.intersects(hurtbox):
			hero.hurt(damage_amount,source.global_position.x)
			hero_hits += 1
			return

func damage_rect() -> Rect2:
	if spent or not active: return Rect2()
	if kind=="pillar": return Rect2(global_position+Vector2(-width*.5,-height),Vector2(width,height))
	if kind=="chain": return Rect2(global_position-Vector2(width,height)*.5,Vector2(width,height))
	return Rect2(global_position-Vector2(7,7),Vector2(14,14))

func consume() -> void:
	if spent: return
	spent = true
	active = false
	visible = false
	queue_free()

func _draw() -> void:
	var cyan := Color("a8f2f2")
	var edge := Color("3da4c0")
	var warning := age < warning_seconds
	var fade := clampf(1.0-(age-warning_seconds-active_seconds)/fade_seconds,0,1)
	if kind=="bolt":
		draw_set_transform(Vector2.ZERO,travel.angle())
		draw_line(Vector2(-35,0),Vector2(-6,0),Color(.22,.72,.87,.22),5,true)
		draw_colored_polygon(PackedVector2Array([Vector2(7,0),Vector2(0,-7),Vector2(-7,0),Vector2(0,7)]),cyan)
		draw_polyline(PackedVector2Array([Vector2(-13,-6),Vector2(-19,0),Vector2(-13,6)]),edge,1.8,true)
	elif kind=="pillar":
		var rect := Rect2(-width*.5,-height,width,height)
		if warning:
			var progress := age/maxf(.01,warning_seconds)
			draw_rect(rect,Color(.22,.74,.85,.08),true)
			draw_rect(rect,Color(.51,.91,.95,.35+.45*progress),false,1.4)
			draw_line(Vector2(-width*.5,0),Vector2(width*.5,0),Color(1,.76,.40,.9),5,true)
			for x in [-width*.35,0,width*.35]: draw_line(Vector2(x,-8),Vector2(x,-28-progress*24),Color(.64,.94,.96,.6),1.5,true)
		else:
			draw_rect(rect,Color(.21,.68,.85,.72*fade))
			draw_rect(rect,Color(.75,1,1,.9*fade),false,2)
			draw_line(Vector2(0,-height),Vector2.ZERO,Color(.78,1,1,.9*fade),4,true)
			for y in range(-int(height)+20,0,37):
				draw_line(Vector2(-width*.32,y),Vector2(width*.32,y+9),Color(.85,1,1,.75*fade),2,true)
	elif kind=="chain":
		var rect := Rect2(-width*.5,-height*.5,width,height)
		draw_rect(rect,Color(.18,.58,.72,.35*fade))
		for index in range(4):
			var center := Vector2(-width*.38+float(index)*width*.25,0)
			draw_arc(center,height*.43,0,TAU,16,Color(.68,.97,1,fade),2,true)
		draw_line(Vector2(-width*.5,0),Vector2(width*.5,0),Color(.45,.82,.9,fade),1.5,true)
