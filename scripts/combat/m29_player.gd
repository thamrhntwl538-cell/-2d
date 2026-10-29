extends "res://scripts/combat/m28_player.gd"
## Existing play stays inherited. The bench director alone drives this safe
## presentation lock while menus and rest choreography own the actor.
const RestModel=preload("res://scripts/warden_model_m29.gd")
var bench_locked := false
var bench_blend := 0.0
var bench_age := 0.0
var bench_seat_height := 28.0
var _bench_resume_jump := false
var _bench_jump_grace := 0.0

func _ready() -> void:
	super._ready()
	var previous: Node2D=combat_model
	combat_container.remove_child(previous)
	var material_value: Material=previous.material
	previous.free()
	combat_model=RestModel.new()
	combat_model.position=Vector2(-256,-456)
	combat_model.material=material_value
	combat_container.add_child(combat_model)
	combat_container.name="ApprovedLanternRestRigM29"
	_update_animation()

func _physics_process(delta: float) -> void:
	if bench_locked: return
	if _bench_resume_jump and world_ref!=null and bool(world_ref.gameplay_active):
		_bench_jump_grace=maxf(0,_bench_jump_grace-delta)
		if hp>0 and is_on_floor():
			jump_buffer=.13
			_bench_resume_jump=false
		elif _bench_jump_grace<=0:
			_bench_resume_jump=false
	super._physics_process(delta)

func begin_bench_lock() -> void:
	reset_combat_motion()
	bench_locked=true
	_bench_resume_jump=false
	_bench_jump_grace=0
	velocity=Vector2.ZERO
	set_bench_pose(0)

func set_bench_walk(velocity_x: float, age: float) -> void:
	if not bench_locked or not is_instance_valid(combat_model): return
	bench_blend=0
	bench_age=age
	if absf(velocity_x)>1:
		facing=1 if velocity_x>0 else -1
	combat_container.scale=Vector2(DRAW_SCALE*facing,DRAW_SCALE)
	combat_container.modulate=Color.WHITE
	combat_model.sword_visible=false
	combat_model.set_motion("run",age*13.0)
	combat_model.set_expression("idle",1.0)
	blade_light.visible=false
	_update_lantern_anchor()

func set_bench_pose(amount: float, age: float=0.0, seat_height: float=28.0) -> void:
	if not is_instance_valid(combat_model): return
	bench_blend=clampf(amount,0,1)
	bench_age=age
	bench_seat_height=seat_height
	velocity=Vector2.ZERO
	combat_container.scale=Vector2(DRAW_SCALE,DRAW_SCALE)
	combat_container.modulate=Color.WHITE
	combat_model.set_bench_pose(bench_blend,age,seat_height)
	blade_light.visible=false
	_update_lantern_anchor()

func end_bench_lock(jump_after_rise: bool=false) -> void:
	bench_locked=false
	bench_blend=0
	bench_age=0
	reset_combat_motion()
	velocity=Vector2.ZERO
	_bench_resume_jump=jump_after_rise
	_bench_jump_grace=.13 if jump_after_rise else 0.0
	_update_animation()

func _update_animation() -> void:
	if bench_locked and is_instance_valid(combat_model):
		set_bench_pose(bench_blend,bench_age,bench_seat_height)
		return
	super._update_animation()

func get_bench_snapshot() -> Dictionary:
	return {"locked":bench_locked,"blend":bench_blend,"age":bench_age,"queued_ground_jump":_bench_resume_jump,"seat_height":bench_seat_height,"rig_scale":combat_container.scale if is_instance_valid(combat_container) else Vector2.ZERO,"pose":combat_model.get_bench_pose_snapshot() if bench_locked and is_instance_valid(combat_model) else {}}
