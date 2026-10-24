extends "res://scripts/bosses/m23_boss_attack.gd"
## A released floor crest travels to its arena edge, never a short-lived timer.
var boundary_x:=0.0
var reached_boundary:=false
var expired_reason:=""
var start_position:=Vector2.ZERO
var wave_phase:=1
var volley:="landing"
var _bounded:=false

func setup(world: Node, source: Node2D, attack_kind: String, origin: Vector2, options: Dictionary={}) -> void:
	super.setup(world,source,attack_kind,origin,options)
	start_position=origin
	wave_phase=int(options.get("phase",1))
	volley=str(options.get("volley","landing"))
	_bounded=options.has("boundary_x")
	if _bounded:
		boundary_x=float(options.boundary_x)
		active_seconds=absf(boundary_x-origin.x)/maxf(1,absf(travel.x))
		fade_seconds=0
		warning_seconds=0

func _physics_process(delta: float) -> void:
	if not _bounded:
		super._physics_process(delta)
		return
	if spent or not is_instance_valid(world_ref): return
	if not bool(world_ref.get("gameplay_active")): return
	var source: Node2D=source_ref.get_ref() as Node2D if source_ref!=null else null
	if not is_instance_valid(source) or bool(source.get("is_dead")):
		consume_with_reason("source_dead")
		return
	if source.has_method("attacks_allowed") and not bool(source.attacks_allowed()):
		consume_with_reason("source_inactive")
		return
	age+=delta
	active=true
	var hero:=world_ref.get("hero") as Node2D
	if is_instance_valid(hero) and world_ref.has_method("hero_strike") and float(hero.get("active_strike_time"))>0:
		world_ref.hero_strike(str(hero.get("attack_direction")),int(hero.get("facing")))
		if spent or bool(source.get("is_dead")) or not bool(world_ref.get("gameplay_active")): return
	var remaining:=maxf(0,(boundary_x-global_position.x)*signf(travel.x))
	var used_delta:=minf(delta,remaining/maxf(1,absf(travel.x)))
	# Sweep the visible 48x24 crest through native hurtboxes and terrain;
	# clamp only its final segment, including a long single-frame delta.
	super._move_swept(used_delta,source,hero)
	if spent:
		return
	if absf(global_position.x-boundary_x)<.01:
		global_position.x=boundary_x
		reached_boundary=true
		consume_with_reason("boundary")
	queue_redraw()

func consume_with_reason(reason: String) -> void:
	if spent: return
	expired_reason=reason
	consume()

func consume() -> void:
	if spent: return
	if _bounded and absf(global_position.x-boundary_x)<.01 and expired_reason in ["","terrain","boundary"]:
		reached_boundary=true
		expired_reason="boundary"
	if expired_reason.is_empty(): expired_reason="terrain" if was_blocked else "cleanup"
	var source: Node2D=source_ref.get_ref() as Node2D if source_ref!=null else null
	if is_instance_valid(source) and source.has_method("_on_wave_finished"):
		source._on_wave_finished(self,expired_reason)
	super.consume()

func _draw() -> void:
	if spent: return
	var fade:=1.0 if _bounded else clampf(1.0-(age-active_seconds)/maxf(.001,fade_seconds),0,1)
	draw_set_transform(Vector2.ZERO,0,Vector2(1 if travel.x>=0 else -1,1))
	var crest:=PackedVector2Array([Vector2(-24,10),Vector2(-16,4),Vector2(-8,-5),Vector2(0,-12),Vector2(9,-7),Vector2(16,1),Vector2(24,10)])
	draw_colored_polygon(crest,Color(.94,.48,.12,.62*fade))
	draw_polyline(crest,Color(1,.82,.42,.98*fade),2.7,true)
	draw_line(Vector2(-24,10),Vector2(24,10),Color(1,.94,.68,fade),3,true)
	draw_polyline(PackedVector2Array([Vector2(-15,8),Vector2(-7,1),Vector2(0,-7),Vector2(9,-2),Vector2(15,6)]),Color(1,.69,.24,.86*fade),2,true)
	draw_set_transform(Vector2.ZERO)
