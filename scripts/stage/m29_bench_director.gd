extends Node
## Rest is an explicit lifecycle. Commit/save belongs to the world only after
## seated emits. Closing the equipment overlay does not leave this lifecycle.
signal seated(definition: Dictionary)
signal stood
const Furniture=preload("res://scripts/stage/m29_bench_furniture.gd")
const ALIGN_SPEED := 220.0
const MAX_ALIGN_DISTANCE := 118.0
const SIT_SECONDS := .46
const RISE_SECONDS := .34
var world_ref: Node2D
var state := "idle"
var definition: Dictionary={}
var seat_height := 28.0
var age := 0.0
var state_time := 0.0
var align_distance := 0.0
var rest_count := 0
var stand_count := 0
var cancellation_reason := ""
var furniture: Dictionary={}
var _target := Vector2.ZERO
var _rise_jump := false
var _settle_frame := -1
var _stand_inputs_armed := false
var _collision_leases: Array[Dictionary]=[]
var _overlay_guard_seen := false

func setup(world: Node2D) -> void:
	world_ref=world
	process_mode=Node.PROCESS_MODE_ALWAYS
	process_priority=10
	bind_room()

func bind_room() -> void:
	if state!="idle": cancel(true)
	for old in furniture.values():
		if is_instance_valid(old): old.free()
	furniture.clear()
	if not is_instance_valid(world_ref) or not is_instance_valid(world_ref.get("active_room")): return
	for record in world_ref.objects:
		var item: Dictionary=record.definition
		if str(item.get("kind",""))!="bench": continue
		if is_instance_valid(record.node): record.node.self_modulate.a=0
		var seat:=Furniture.new()
		seat.name="RestBench_"+str(item.get("id","bench"))
		world_ref.active_room.add_child(seat)
		seat.position=item.pos
		seat.setup(float(item.get("seat_height",28)))
		furniture[str(item.id)]=seat

func begin(bench: Dictionary) -> bool:
	if state!="idle" or not is_instance_valid(world_ref): return false
	var hero:=_hero()
	if not is_instance_valid(hero) or not hero.has_method("begin_bench_lock") or hero.hp<=0 or not hero.is_on_floor() or hero.hurt_time>0: return false
	if bool(world_ref.get("boss_active")): return false
	var point: Vector2=bench.get("seat_pos",bench.get("pos",Vector2.INF))
	if not point.is_finite() or absf(hero.position.y-point.y)>5 or absf(hero.position.x-point.x)>MAX_ALIGN_DISTANCE: return false
	if not _supported(point) or not _supported(hero.position): return false
	definition=bench.duplicate(true)
	_target=point
	seat_height=clampf(float(bench.get("seat_height",28)),20,36)
	age=0
	state_time=0
	align_distance=absf(hero.position.x-point.x)
	cancellation_reason=""
	_rise_jump=false
	_stand_inputs_armed=false
	_overlay_guard_seen=false
	_lease_collision(hero)
	_lease_terrain(world_ref.get("active_room"))
	hero.begin_bench_lock()
	state="aligning"
	return true

func _supported(point: Vector2) -> bool:
	var query:=PhysicsRayQueryParameters2D.create(point+Vector2(0,-3),point+Vector2(0,8),1)
	return not world_ref.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _hero() -> CharacterBody2D:
	if not is_instance_valid(world_ref): return null
	var value: Variant=world_ref.get("hero")
	return value as CharacterBody2D if is_instance_valid(value) else null

func _lease_collision(body: CollisionObject2D) -> void:
	if not is_instance_valid(body): return
	for record in _collision_leases:
		if is_instance_valid(record.body) and record.body==body: return
	_collision_leases.append({"body":body,"mode":body.disable_mode})
	body.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE

func _lease_terrain(node: Node) -> void:
	if not is_instance_valid(node): return
	if node is PhysicsBody2D and (node.collision_layer&1)!=0: _lease_collision(node)
	for child in node.get_children(): _lease_terrain(child)

func _restore_collision() -> void:
	for record in _collision_leases:
		if is_instance_valid(record.body): record.body.disable_mode=int(record.mode)
	_collision_leases.clear()

func _process(delta: float) -> void:
	if state=="idle" or not is_instance_valid(world_ref): return
	var hero:=_hero()
	if not is_instance_valid(hero) or hero.hp<=0:
		cancel(true,"actor_unavailable")
		return
	var dt:=clampf(delta,0,.05)
	age+=dt
	state_time+=dt
	match state:
		"aligning":
			var error: float=_target.x-hero.position.x
			if absf(error)<.6:
				hero.position.x=_target.x
				hero.velocity=Vector2.ZERO
				state="sitting"
				state_time=0
				return
			var motion:=Vector2(clampf(error,-ALIGN_SPEED*dt,ALIGN_SPEED*dt),0)
			var next:=hero.position+motion
			if not _supported(next):
				cancel(true,"unsupported_alignment")
				return
			var old_x: float=hero.position.x
			var collision:=hero.move_and_collide(motion)
			hero.set_bench_walk(motion.x/maxf(dt,.001),age)
			if collision!=null and absf(hero.position.x-old_x)<absf(motion.x)*.5:
				cancel(true,"blocked_alignment")
		"sitting":
			hero.set_bench_pose(smoothstep(0,SIT_SECONDS,state_time),age,seat_height)
			if state_time>=SIT_SECONDS:
				state="seated"
				state_time=0
				_settle_frame=Engine.get_process_frames()
				_stand_inputs_armed=false
				rest_count+=1
				_set_occupied(true)
				seated.emit(definition.duplicate(true))
		"seated":
			hero.set_bench_pose(1,age,seat_height)
			var hud: Object=world_ref.get("hud")
			var overlay_open:=is_instance_valid(hud) and bool(hud.get("panel_open"))
			var overlay_closing:=is_instance_valid(hud) and bool(hud.get("closing_panel"))
			if overlay_open or overlay_closing:
				_stand_inputs_armed=false
				_overlay_guard_seen=true
				return
			# A direction deliberately held through the first sit can get up.
			# After equipment UI, all buttons must first be released so its
			# directional focus and A/Jump cannot leak into movement.
			if not _overlay_guard_seen and state_time>.10:
				if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
					request_stand()
					return
			if not _stand_inputs_armed:
				var released:=true
				for action in ["move_left","move_right","jump","interact"]:
					if InputMap.has_action(action) and Input.is_action_pressed(action): released=false
				_stand_inputs_armed=released
				return
			if Engine.get_process_frames()>_settle_frame+2:
				for action in ["move_left","move_right","jump","interact"]:
					if InputMap.has_action(action) and Input.is_action_just_pressed(action):
						_rise_jump=action=="jump"
						request_stand()
						break
		"rising":
			hero.set_bench_pose(1-smoothstep(0,RISE_SECONDS,state_time),age,seat_height)
			if state_time>=RISE_SECONDS:
				hero.end_bench_lock(_rise_jump)
				state="idle"
				_set_occupied(false)
				stand_count+=1
				stood.emit()
				_restore_collision()

func request_stand() -> void:
	if state!="seated": return
	state="rising"
	state_time=0

func cancel(immediate: bool=true, reason: String="cancelled") -> void:
	if state=="idle": return
	if not immediate and state=="seated":
		request_stand()
		return
	cancellation_reason=reason
	if is_instance_valid(world_ref):
		var hero:=_hero()
		if is_instance_valid(hero) and hero.has_method("end_bench_lock"): hero.end_bench_lock()
	_set_occupied(false)
	state="idle"
	stood.emit()
	_restore_collision()

func _set_occupied(value: bool) -> void:
	var seat: Variant=furniture.get(str(definition.get("id","")))
	if is_instance_valid(seat): seat.set_occupied(value)

func is_seated() -> bool: return state=="seated"
func is_busy() -> bool: return state!="idle"
func get_snapshot() -> Dictionary:
	return {"state":state,"active":state!="idle","seated":state=="seated","bench_id":definition.get("id",""),"age":age,"state_time":state_time,"sit_progress":clampf(state_time/SIT_SECONDS,0,1) if state=="sitting" else (1.0 if state=="seated" else 0.0),"align_distance":align_distance,"seat_height":seat_height,"rest_count":rest_count,"stand_count":stand_count,"cancellation_reason":cancellation_reason,"target":_target,"collision_leases":_collision_leases.size(),"checkpoint_committed_by_director":false}
