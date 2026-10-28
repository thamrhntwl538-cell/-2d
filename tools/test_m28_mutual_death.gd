extends SceneTree
## Defensive simultaneous-death fixture: a stopped boss death clip must never
## trap the player's already-recorded return to their world checkpoint.
const Journey=preload("res://scripts/stage/m28_journey.gd")
const State=preload("res://scripts/combat/m18_combat_state.gd")
const Puzzle=preload("res://scripts/stage/m22_puzzle_state.gd")
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func step(count: int) -> void:
	for unused in range(count):
		await physics_frame
		await process_frame
func run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("m28_mutual_userdata"): quit(1);return
	var state:=State.new()
	state.dash_owned=true
	state.wallet=7
	var progress: Dictionary=Puzzle.new_progress()
	progress.weapon_owned=true
	var session:={"schema":28,"boss":"archivist","status":"entered","origin":{"room":6,"position":[2620,1980]},"checkpoint":{"room":1,"position":[310,1260]},"progress":progress,"combat":state.serialize(),"hp":1,"energy":0,"language":"en","journal_cursor":{}}
	Journey.atomic_write(Journey.SESSION_PATH,session)
	var trial: Node2D=load(Journey.ARCHIVE_SCENE).instantiate()
	root.add_child(trial);current_scene=trial
	await step(5)
	trial.encounter_started=true
	trial.is_dead=true
	trial.state="death"
	trial.hp=0
	trial.hero.hp=0
	trial.on_player_death()
	await step(75)
	var world: Node=current_scene
	if not world.has_method("get_m28_world_snapshot"): failures.append("simultaneous death did not return to world")
	else:
		if world.current_room!=1 or world.hero.hp!=6: failures.append("last bench/health not restored")
		if bool(world.progress.get("miniboss_archivist_defeated",false)): failures.append("unfinished boss animation incorrectly awarded victory")
		if int(world.combat_state.death_drop.get("amount",0))!=7: failures.append("carried coins not retained as lost pile")
	current_scene=null
	root.remove_child(world);world.free()
	await step(8)
	OS.delay_msec(180)
	var report:={"checks":4,"failures":failures,"engine":Engine.get_version_info().string,"fixture":"Simultaneous player/boss death before source death-animation completion"}
	FileAccess.open("user://m28_mutual_death_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M28 MUTUAL DEATH ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
