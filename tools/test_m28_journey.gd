extends SceneTree
## Transaction fixtures for the actual native world/vault scene bridge. Boss
## damage and positions below are controlled fixtures, not skill-play evidence.
const Journey=preload("res://scripts/stage/m28_journey.gd")
var checks:=0
var failures: Array[String]=[]
var world: Node2D

func _initialize() -> void: run.call_deferred()
func step(count: int=1) -> void:
	for unused in range(count):
		await physics_frame
		await process_frame
func check(value: bool, caption: String) -> void:
	checks+=1
	if not value:
		failures.append(caption)
		push_error("M28 journey: "+caption)

func open_world(fresh:=false) -> Node2D:
	var node: Node2D=load(Journey.WORLD_SCENE).instantiate()
	if fresh: node.restore_saved_game=false
	root.add_child(node)
	current_scene=node
	await step(5)
	return node

func prepare_vault(value: Node2D) -> Dictionary:
	value.progress.weapon_owned=true
	value.combat_state.dash_owned=true
	value.combat_state.spell_owned=false
	value._load_room(6,"left",Vector2(2620,1980))
	await step(3)
	for entry in value.objects:
		if str(entry.definition.get("kind",""))=="boss_portal": return entry.definition
	return {}

func enter_vault(value: Node2D) -> Node2D:
	var definition: Dictionary=await prepare_vault(value)
	value._enter_archive(definition)
	await step(45)
	return current_scene

func close_current() -> void:
	if is_instance_valid(current_scene):
		var old:=current_scene
		current_scene=null
		root.remove_child(old)
		old.free()
	await step(8)
	OS.delay_msec(180) # Flush real audio work before the next native scene.

func run() -> void:
	# This tool must run under an isolated XDG_DATA_HOME. It never resets a
	# user's real save or rewrites the archived M18/M24/M26 trial files.
	check(OS.get_environment("XDG_DATA_HOME").contains("m28_journey_userdata"),"fixtures use isolated userdata directory")
	if not failures.is_empty(): quit(1);return
	Journey.remove_session()
	if FileAccess.file_exists(Journey.SAVE_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(Journey.SAVE_PATH))
	world=await open_world(true)
	check(world.current_room==1 and not world.is_boss_trial,"integrated world opens first library room")
	check(world.hero.get_script().resource_path.ends_with("m28_player.gd"),"world uses approved hero with M28 movement fixes")
	var portal:=await prepare_vault(world)
	check(not portal.is_empty(),"archive has an authored accessible vault door")
	world.combat_state.dash_owned=false
	world._enter_archive(portal)
	check(not FileAccess.file_exists(Journey.SESSION_PATH),"vault refuses missing traversal kit without session/save exploit")
	world.combat_state.dash_owned=true
	world.hero.hp=4
	world.hero.energy=44
	world.combat_state.wallet=37
	world.checkpoint={"room":1,"position":[310.0,1260.0]}
	world._enter_archive(portal)
	await step(45)
	var trial: Node2D=current_scene
	check(trial.has_method("get_journey_snapshot"),"actual door scene transition opens world-linked native Archivist")
	if not trial.has_method("get_journey_snapshot"): await close_current();quit(1);return
	check(trial.hero.hp==4 and is_equal_approx(trial.hero.energy,44),"vault receives current health and energy without healing")
	check(trial.combat_state.wallet==37 and not trial.combat_state.spell_owned and not trial.hero.has_code_slash,"vault receives actual wallet and owned kit; no free spell")
	check(trial.hero.get_script().resource_path.ends_with("m28_player.gd"),"vault uses same M28 movement hero")
	check(trial.singing.is_singing() and not trial.encounter_started,"vault preserves body-local dormant song")
	trial.hero.hp=3
	trial.hero.energy=17
	trial.combat_changed()
	trial._return_to_catalog()
	await step(10)
	world=current_scene
	check(world.has_method("get_m28_world_snapshot") and world.current_room==6,"retreat returns to actual archive portal")
	check(world.hero.hp==3 and is_equal_approx(world.hero.energy,17) and world.combat_state.wallet==37,"retreat preserves spent health/energy and coins")
	check(not bool(world.progress.get("miniboss_archivist_defeated",false)),"retreat never awards a false victory")
	check(not FileAccess.file_exists(Journey.SESSION_PATH),"successful return atomically consumes session")
	trial=await enter_vault(world)
	trial.hero.position=Vector2(1234,620)
	trial.hero.hp=0
	trial.on_player_death()
	await step(70)
	world=current_scene
	check(world.has_method("get_m28_world_snapshot") and world.current_room==1,"vault death returns to last actual world bench")
	check(world.hero.hp==6 and is_zero_approx(world.hero.energy),"respawn restores health and preserves empty energy")
	check(world.combat_state.wallet==0 and int(world.combat_state.death_drop.get("amount",0))==37,"vault death drops carried currency without losing inventory")
	check(world.progress.m28_archivist_pile.position==[1234.0,620.0],"vault currency pile retains exact native chamber location")
	check(not world.objects.any(func(entry): return str(entry.definition.get("kind",""))=="currency_drop"),"vault pile is not duplicated at world coordinates")
	trial=await enter_vault(world)
	check(is_instance_valid(trial.pile) and trial.pile.position==Vector2(1234,620),"re-entering shows the actual lost pile inside chamber")
	trial.hero.position=Vector2(1234,620)
	trial.hero.velocity=Vector2.ZERO
	Input.action_press("interact")
	await step(2)
	Input.action_release("interact")
	check(trial.combat_state.wallet==37 and trial.combat_state.death_drop.is_empty(),"real interaction recovers previous coins exactly once")
	check(not trial.progress.has("m28_archivist_pile"),"recovery clears chamber metadata")
	trial.hero.hp=5
	trial.hero.energy=22
	trial.hero.invulnerable=999
	trial.start_encounter()
	trial._set_idle(.18)
	check(not trial.singing.is_singing(),"real encounter cutoff stops the supplied song")
	check(trial.damage_boss(48,"controlled_fixture"),"lethal controlled damage enters actual native death sequence")
	check(not trial._victory_committed,"zero boss HP alone waits for approved death animation")
	await step(260)
	check(trial.state=="victory" and trial._victory_committed,"finished native death animation commits real victory receipt")
	var capacity: int=trial.combat_state.capacity
	check(capacity==4,"Archivist expands fitil capacity once")
	trial._commit_victory()
	check(trial.combat_state.capacity==capacity,"duplicate victory callbacks cannot duplicate capacity")
	trial._return_to_catalog()
	await step(12)
	world=current_scene
	check(bool(world.progress.get("miniboss_archivist_defeated",false)),"actual victory survives return to exploration")
	check(world.combat_state.capacity==capacity,"return receipt cannot duplicate already-issued capacity")
	check(world.combat_state.wallet==37,"physical victory coins are not also credited directly")
	var rewards: Array=world.CurrencyLedger.room_pending(world.progress,6)
	var total:=0
	for coin in rewards:
		if str(coin.reward_id)=="miniboss:archivist": total+=int(coin.amount)
	check(total==60,"unique sixty-coin reward physically awaits outside vault")
	check(rewards.all(func(coin): return float(coin.position[1])>1900),"reward coins use the real archive floor, not isolated chamber coordinates")
	world._load_room(14,"left",Vector2(310,1440))
	var exits15: Array=world.data.exits.filter(func(entry): return int(entry.get("target",0))==15)
	check(exits15.size()==1 and world.can_use_exit(exits15[0]),"last exploration room is accessible without obsolete Compiler victory")
	world._load_room(15,"left",Vector2(310,1260))
	world._request_departure()
	check(not bool(world.progress.get("world1_departed",false)) and not bool(world.progress.get("boss_defeated",false)),"unfinished final threshold neither departs nor fabricates final-boss win")
	# Malformed anchors are rejected before any inventory/progress merge.
	var valid: Dictionary={"schema":28,"boss":"archivist","status":"retreat","origin":{"room":6,"position":[99999,99999]},"checkpoint":{"room":1,"position":[310,1260]},"progress":{"malformed_mutation":true},"combat":world.combat_state.serialize(),"hp":3,"energy":11}
	Journey.atomic_write(Journey.SESSION_PATH,valid)
	world._read_trial_return()
	check(not world.progress.has("malformed_mutation"),"out-of-bounds session cannot mutate world progress")
	Journey.remove_session()
	# An interrupted encounter is reconciled at the doorway with the latest
	# actual vitals, not at full health and without an invented boss victory.
	world.hero.hp=2
	world.hero.energy=9
	world.combat_state.wallet=14
	world.progress.miniboss_archivist_defeated=false
	trial=await enter_vault(world)
	trial.hero.hp=2
	trial.hero.energy=9
	trial.combat_changed()
	await close_current()
	world=await open_world()
	check(world.current_room==6 and world.hero.hp==2 and is_equal_approx(world.hero.energy,9),"interrupted encounter reopens at doorway with actual latest vitals")
	check(not bool(world.progress.get("miniboss_archivist_defeated",false)) and world.combat_state.wallet==14,"interruption preserves coins and cannot create a victory")
	check(not FileAccess.file_exists(Journey.SESSION_PATH),"interrupted encounter envelope is consumed after successful reconciliation")
	# A second death replaces an unclaimed chamber pile, including the zero-
	# wallet case: the prior amount must not survive in hidden metadata.
	world.combat_state.death_drop={"room":6,"position":[2620.0,1980.0],"amount":37}
	world.progress.m28_archivist_pile={"position":[1100.0,620.0],"amount":37}
	world.combat_state.wallet=9
	trial=await enter_vault(world)
	trial.hero.position=Vector2(1500,620)
	trial.hero.hp=0
	trial.on_player_death()
	await step(70)
	world=current_scene
	check(world.combat_state.wallet==0 and int(world.combat_state.death_drop.get("amount",0))==9,"second death replaces unclaimed old coins with current carried coins")
	check(world.progress.m28_archivist_pile.position==[1500.0,620.0] and int(world.progress.m28_archivist_pile.amount)==9,"second death updates exact chamber pile position and amount")
	trial=await enter_vault(world)
	trial.hero.hp=0
	trial.on_player_death()
	await step(70)
	world=current_scene
	check(world.combat_state.death_drop.is_empty() and not world.progress.has("m28_archivist_pile"),"zero-coin second death also erases the previous unclaimed pile")
	Journey.remove_session()
	await close_current()
	var report: Dictionary={"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"scope":"Native actual door/world transitions; controlled death/damage fixtures for transaction QA, not a full human-played victory."}
	FileAccess.open("user://m28_journey_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M28 JOURNEY ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
