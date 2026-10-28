extends SceneTree
## A boss receipt must place every physical coin outside solid book geometry.
const Journey=preload("res://scripts/stage/m28_journey.gd")
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("m28_reward_userdata"):quit(1);return
	var world: Node2D=load(Journey.WORLD_SCENE).instantiate()
	world.restore_saved_game=false
	root.add_child(world);current_scene=world
	await process_frame
	var session:={"schema":28,"boss":"archivist","status":"victory","origin":{"room":6,"position":[2620,1980]},"checkpoint":{"room":1,"position":[310,1260]},"progress":world.progress.duplicate(true),"combat":world.combat_state.serialize(),"hp":3,"energy":17,"victory_receipt":{"boss":"archivist","hp":0,"state":"victory"}}
	Journey.atomic_write(Journey.SESSION_PATH,session)
	world._read_trial_return()
	var coins: Array=world.CurrencyLedger.room_pending(world.progress,6)
	if coins.size()!=6:failures.append("victory must issue six physical coin parcels")
	var geometry: Array=world._room_layout(6).platforms
	for coin in coins:
		var point:=Vector2(float(coin.position[0]),float(coin.position[1]))
		for platform in geometry:
			if bool(platform.get("one_way",true)):continue
			if (platform.rect as Rect2).has_point(point):failures.append("coin trapped inside solid geometry at "+str(point))
	var capacity: int=world.combat_state.capacity
	world._read_trial_return()
	if world.combat_state.capacity!=capacity or world.CurrencyLedger.room_pending(world.progress,6).size()!=6:failures.append("replayed receipt duplicated capacity or coins")
	Journey.remove_session()
	world.gameplay_active=false
	current_scene=null;root.remove_child(world);world.free()
	await process_frame
	OS.delay_msec(180)
	var report:={"checks":8,"failures":failures,"engine":Engine.get_version_info().string,"scope":"Boss-receipt replay and all six coin positions checked against real archive solid geometry"}
	FileAccess.open("user://m28_reward_clearance_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M28 REWARD CLEARANCE ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
