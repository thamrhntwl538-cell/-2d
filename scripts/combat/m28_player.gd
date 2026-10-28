extends "res://scripts/combat/m23_player.gd"
## M28 keeps the approved rig, jump/attack clocks and movement tuning. Two
## traversal fixes live here so archived encounters retain their original actor.
## Down + Jump descends through the actual one-way shelf supporting the hero.
const DROP_START_SPEED := 70.0
const DROP_HEAD_CLEARANCE := 96.0
var shelf_drops := 0
var wall_dash_stops := 0
var _drop_supports: Array[Dictionary] = []

func _physics_process(delta: float) -> void:
	if world_ref == null or not world_ref.gameplay_active: return
	_update_drop_exceptions()
	var dropped := false
	if hp>0 and hurt_time<=0 and is_on_floor() and Input.is_action_pressed("look_down") and Input.is_action_just_pressed("jump"):
		var supports := _supporting_one_way_shelves()
		if not supports.is_empty():
			_begin_shelf_drop(supports)
			dropped = true
	super._physics_process(delta)
	# Consume only the drop's original Jump press. A later fresh press can still
	# use the inherited landing buffer on the lower shelf.
	if dropped: jump_buffer = 0.0
	# A solid wall already stopped the native body. End the pose as well, letting
	# ordinary steering respond next tick; the air token and .50s cooldown stay spent.
	if dash_time>0.0 and is_on_wall() and hurt_time<=0:
		for index in range(get_slide_collision_count()):
			if get_slide_collision(index).get_normal().x*float(facing)<-0.7:
				dash_time = 0.0
				wall_dash_stops += 1
				_update_animation()
				break
	_update_drop_exceptions()

func _supporting_one_way_shelves() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(get_slide_collision_count()):
		var contact := get_slide_collision(index)
		if contact.get_normal().y>=-0.7: continue
		var body := contact.get_collider() as PhysicsBody2D
		if body == null: return []
		var shape_node := contact.get_collider_shape() as CollisionShape2D
		# A solid support at a seam wins over a neighbouring pass-through page.
		if shape_node == null or not shape_node.one_way_collision: return []
		var already_present := false
		for record in result:
			if record.body == body: already_present = true
		if not already_present: result.append({"body":body,"shape":shape_node})
	return result

func _begin_shelf_drop(supports: Array[Dictionary]) -> void:
	_clear_drop_exceptions()
	for record in supports:
		add_collision_exception_with(record.body)
		_drop_supports.append(record)
	_cancel_heal(true)
	dash_time = 0.0
	dash_buffer = 0.0
	jump_grace = 0.0
	jump_buffer = 0.0
	_jump_cut_available = false
	land_timer = 0.0
	# Refresh native floor contact before the inherited jump handler sees this
	# press. Only this small downward advance is extra; horizontal motion occurs
	# once in the normal physics step. Other terrain collisions remain enabled.
	var horizontal := velocity.x
	velocity = Vector2(0,DROP_START_SPEED)
	move_and_slide()
	velocity.x = horizontal
	shelf_drops += 1

func _update_drop_exceptions() -> void:
	for index in range(_drop_supports.size()-1,-1,-1):
		var record := _drop_supports[index]
		if not is_instance_valid(record.body) or not is_instance_valid(record.shape):
			_drop_supports.remove_at(index)
			continue
		var body: PhysicsBody2D = record.body
		var shape_node: CollisionShape2D = record.shape
		var local_bounds: Rect2 = shape_node.shape.get_rect()
		var bounds := Rect2(shape_node.to_global(local_bounds.position),Vector2.ZERO)
		for point in [local_bounds.end,Vector2(local_bounds.end.x,local_bounds.position.y),Vector2(local_bounds.position.x,local_bounds.end.y)]:
			bounds = bounds.expand(shape_node.to_global(point))
		var clear_below := global_position.y>bounds.position.y+DROP_HEAD_CLEARANCE
		var clear_side := global_position.x<bounds.position.x-24.0 or global_position.x>bounds.end.x+24.0
		# Rising bodies can safely re-enable one-way terrain, which never blocks
		# their upward travel. Never remove other actors' collision exceptions.
		if clear_below or clear_side or velocity.y<0.0:
			remove_collision_exception_with(body)
			_drop_supports.remove_at(index)

func _clear_drop_exceptions() -> void:
	for record in _drop_supports:
		if is_instance_valid(record.body): remove_collision_exception_with(record.body)
	_drop_supports.clear()

func reset_combat_motion() -> void:
	_clear_drop_exceptions()
	super.reset_combat_motion()
	# A jump queued before a door, respawn or knockback reset belongs to the old
	# location. Held Jump does not become a new press in the next room.
	jump_buffer = 0.0
	jump_grace = 0.0
	land_timer = 0.0
	stop_timer = 0.0
	was_ground_running = false

func hurt(amount: int, attack_x: float) -> void:
	super.hurt(amount,attack_x)
	if hp<=0: _clear_drop_exceptions()

func get_movement_snapshot() -> Dictionary:
	return {"shelf_drops":shelf_drops,"wall_dash_stops":wall_dash_stops,"ignored_supports":_drop_supports.size(),"coyote_seconds":0.11,"jump_buffer_seconds":0.13,"jump_force":JUMP_FORCE,"speed":SPEED,"gravity":GRAVITY,"dash_duration":DASH_DURATION,"dash_cooldown":DASH_COOLDOWN}
