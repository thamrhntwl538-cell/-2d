extends Node2D
## Pressure switches are physical, not menu solutions. All rewards use the
## existing persistent coin ledger and can be collected once across reloads.
var world_ref: Node2D
var definition: Dictionary
var plate_hold: Dictionary={}
var relay_hold: Dictionary={}
var latched_relay: int=-1
var plate_visits: int=0

func setup(world: Node2D, data: Dictionary) -> void:
	world_ref=world
	definition=data
	name="PhysicalShelfMechanismsM28"
	z_index=2

func _standing_at(at: Vector2) -> bool:
	var actor: CharacterBody2D=world_ref.get("hero")
	return is_instance_valid(actor) and actor.hp>0 and actor.is_on_floor() and absf(actor.position.x-at.x)<27 and absf(actor.position.y-at.y)<5

func _physics_process(delta: float) -> void:
	if not is_instance_valid(world_ref) or not bool(world_ref.get("gameplay_active")) or bool(world_ref.get("boss_active")): return
	var progress: Dictionary=world_ref.get("progress")
	for plate in definition.get("m28_pressure_plates",[]):
		if bool(progress.get(str(plate.flag),false)): continue
		var identity:=str(plate.id)
		plate_hold[identity]=float(plate_hold.get(identity,0.0))+delta if _standing_at(plate.pos) else 0.0
		if float(plate_hold[identity])>=.20:
			progress[str(plate.flag)]=true
			plate_visits+=1
			_commit_reward(identity,int(plate.get("reward",0)),plate.pos)
			world_ref._tip("ثبت الممر · حُفظ اكتشافك.","The passage is secured · Your discovery is saved.")
	var relays: Array=definition.get("m28_relays",[])
	if relays.is_empty() or bool(progress.get(str(definition.get("m28_relay_flag","")),false)): return
	var active_index: int=-1
	for relay in relays:
		var index:=int(relay.glyph)
		relay_hold[index]=float(relay_hold.get(index,0.0))+delta if _standing_at(relay.pos) else 0.0
		if float(relay_hold[index])>=.20: active_index=index
	if active_index<0:
		latched_relay=-1
		return
	if active_index==latched_relay: return
	latched_relay=active_index
	var order: Array=definition.get("m28_relay_order",[0,2,1])
	var history: Array=progress.get("m28_counterweight_relay_history",[])
	if history.size()>=order.size(): history=[]
	if active_index==int(order[history.size()]):
		history.append(active_index)
		world_ref.play_sfx("puzzle_success")
	else:
		history=[active_index] if active_index==int(order[0]) else []
		world_ref.play_sfx("puzzle_error")
	progress.m28_counterweight_relay_history=history
	if history.size()==order.size():
		progress[str(definition.m28_relay_flag)]=true
		_commit_reward("counterweight_relay",int(definition.get("m28_relay_reward",24)),relays[active_index].pos)
		world_ref._tip("تعادلت الفتائل · ظهر درج العودة.","The wick seals balance · The return step unfolds.")
	else:
		world_ref._save()
		_refresh_visuals()

func _commit_reward(identity: String, amount: int, point: Vector2) -> void:
	if amount>0: world_ref._issue_coin_reward("m28_environment:"+identity,point,amount)
	world_ref.play_sfx("puzzle_success")
	world_ref._refresh_geometry()
	world_ref._save()
	_refresh_visuals()

func _refresh_visuals() -> void:
	var renderer: Node2D=world_ref.get("visuals")
	if is_instance_valid(renderer): renderer.queue_redraw()

func get_environment_snapshot() -> Dictionary:
	return {"pressure_activations":plate_visits,"relay_latched":latched_relay,"relay_history":world_ref.progress.get("m28_counterweight_relay_history",[]).duplicate(),"output_span_open":bool(world_ref.progress.get("m28_output_span_open",false))}
