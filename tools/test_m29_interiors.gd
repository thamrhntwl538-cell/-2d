extends SceneTree
## Actual native world entry/exit input plus configured starts and death/receipt
## fixtures. No claim of a human-played Bell victory or full-stage playthrough.
const WORLD="res://scenes/stage_01/folding_library_m29.tscn"
const Travel=preload("res://scripts/stage/m29_journey.gd")
var world: Node2D
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func step(n:int=1) -> void:
	for unused in range(n):
		await physics_frame
		await process_frame
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		push_error(message)
func release() -> void:
	for key in ["move_left","move_right","interact","look_up","jump","attack","heal","bench_inventory","pause_game"]:
		if InputMap.has_action(key): Input.action_release(key)
func key(code:int) -> void:
	await physics_frame
	var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=true;Input.parse_input_event(e)
	await step(2)
	e=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=false;Input.parse_input_event(e)
	await step(2)
func place(room:int,point:Vector2) -> void:
	release()
	world.interior_kind=""
	world._load_room(room,"left",point)
	await step(40)
func open(restore:bool) -> void:
	world=load(WORLD).instantiate();world.restore_saved_game=restore;world.transition_seconds=.08
	root.add_child(world);current_scene=world
	await step(40)
func close() -> void:
	release()
	if is_instance_valid(world):
		current_scene=null;world.queue_free()
		await step(5)
		OS.delay_msec(180)
func enter_market() -> void:
	await place(4,Vector2(2050,1260));await key(KEY_E);await step(45)
func exit_market() -> void:
	world.hero.position=Vector2(150,620);world.hero.velocity=Vector2.ZERO;await step(35);await key(KEY_W);await step(45)
func enter_bell() -> void:
	await place(12,Vector2(1000,1260));await key(KEY_E);await step(45)
func run() -> void:
	check(OS.get_environment("XDG_DATA_HOME").contains("m29_interiors_userdata"),"isolated userdata required")
	if not failures.is_empty():quit(1);return
	Travel.remove_session()
	if FileAccess.file_exists(Travel.SAVE_PATH):DirAccess.remove_absolute(ProjectSettings.globalize_path(Travel.SAVE_PATH))
	await open(false)
	world.progress.weapon_owned=true;world.combat_state.dash_owned=true
	world.hero.hp=3;world.hero.energy=21;world.combat_state.wallet=120
	await place(12,Vector2(1200,1260))
	check(not is_instance_valid(world.registered_boss) and not world.boss_active,"walking through exterior bindery does not start a hidden corridor fight")
	await enter_market()
	check(world.interior_kind=="market" and world.current_room==4,"actual E enters separate compact market room")
	check(world.active_room.name.begins_with("LibraryArea") and world.data.size==Vector2(1280,720),"interior owns a new bounded collision room")
	check(world.hero.hp==3 and is_equal_approx(world.hero.energy,21) and world.combat_state.wallet==120,"entering house grants no health, energy or money")
	check(world.hero.is_on_floor() and absf(world.hero.position.y-620)<2,"interior arrival is on the real 620px floor")
	check(world.building_return.position==[1960.0,1260.0],"interior remembers its exterior door anchor")
	world.hero.position=Vector2(940,620);world.hero.velocity=Vector2.ZERO;await step(6)
	await key(KEY_E);await step(25)
	check(world.hud.panel_open and world.hud.current_panel=="shop","physical shop interaction opens original real market offers")
	world.hud.action.emit("shop_buy","atlas");await step(3)
	check(world.combat_state.wallet==96 and world.Shop.owns(world.progress,world.combat_state,"atlas"),"real world purchase spends 24 coins and grants actual atlas")
	await key(KEY_ESCAPE);await step(35)
	await exit_market()
	check(world.interior_kind.is_empty() and world.current_room==4,"actual up input exits shop to its own street")
	check(absf(world.hero.position.x-1960)<3 and absf(world.hero.position.y-1260)<2,"return from house uses safe paired exterior anchor")
	check(world.hero.hp==3 and is_equal_approx(world.hero.energy,21) and world.combat_state.wallet==96,"house exit preserves spent vitals and persistent purchase")
	await enter_bell()
	check(world.interior_kind=="bell" and is_instance_valid(world.registered_boss),"actual bindery E enters actual approved Bell chamber")
	check(not world.boss_active and world.hero.position.x<world.BELL_SPEC.intro_threshold_x,"Bell does not start before physical approach threshold")
	check(world.data.compiler_trial.arena_rect==Rect2(1110,940,1080,320),"approved 1080px Bell arena is retained inside the building")
	world.hero.invulnerable=999
	Input.action_press("move_right")
	for tick in range(600):
		await step()
		if world.boss_active: break
	Input.action_release("move_right")
	print("BELL ENTRY OBSERVED ",world.get_m29_world_snapshot()," actor ",world.hero.position," v ",world.hero.velocity," paused ",world.paused," play ",world.gameplay_active," mode ",world.hero.process_mode," lock ",world.hero.bench_locked," kit ",world.hero.has_blade,"/",world.hero.has_dash)
	check(world.boss_active and world.boss_arena.locked,"ordinary movement toward Bell starts fight and locks physical gates")
	if not world.boss_active:
		await close();quit(1);return
	var exitdef:Dictionary={}
	for object in world.data.objects:
		if str(object.get("kind",""))=="interior_exit":exitdef=object
	world._activate(exitdef);await step(3)
	check(world.interior_kind=="bell" and world.boss_active,"interior return door cannot escape an active fight")
	# A controlled actual-actor death-state fixture tests the unchanged receipt
	# callback and NEW interior scoping; this is not a combat win demonstration.
	var actor:Node2D=world.registered_boss
	actor.is_dead=true;actor.alive=false;actor.hp=0
	var cap:int=world.combat_state.capacity
	world.on_compiler_defeated(actor);await step(45)
	check(bool(world.progress.get("miniboss_bell_defeated",false)) and not world.boss_active,"actual Bell callback commits the permanent victory")
	check(world.combat_state.capacity==cap+1,"Bell permanent reward applies once")
	check(world._reward_context("miniboss:bell_warden")=="bell","Bell coin receipt is scoped to the interior")
	var pending:Array=world.CurrencyLedger.room_pending(world.progress,12)
	var total:=0
	for coin in pending:
		if str(coin.reward_id)=="miniboss:bell_warden":total+=int(coin.amount)
	check(total==45,"unchanged forty-five physical reward coins exist in chamber")
	world.on_compiler_defeated(actor);await step(2)
	check(world.combat_state.capacity==cap+1,"duplicate Bell callback cannot expand capacity twice")
	world.hero.position=Vector2(360,1260);world.hero.velocity=Vector2.ZERO;await step(35);await key(KEY_E);await step(45)
	check(world.interior_kind.is_empty() and world.current_room==12,"victory returns through the actual bindery exit to its street")
	var outside_coins:=0
	for coin in get_nodes_in_group("m22_coins"):
		if world.is_ancestor_of(coin) and str(coin.get_meta("reward_id",""))=="miniboss:bell_warden":outside_coins+=1
	check(outside_coins==0,"interior Bell rewards do not materialize through the exterior building walls")
	await enter_bell()
	check(not is_instance_valid(world.registered_boss),"defeated Bell does not respawn on normal re-entry")
	var inside_coins:=0
	for coin in get_nodes_in_group("m22_coins"):
		if world.is_ancestor_of(coin) and str(coin.get_meta("reward_id",""))=="miniboss:bell_warden":inside_coins+=1
	check(inside_coins>0,"uncollected reward parcels persist in the correct chamber")
	world.hero.position=Vector2(1850,1260);world.hero.velocity=Vector2.ZERO;await step(45)
	check(world.combat_state.wallet==141,"physical magnet/collection recovers exactly the one Bell reward")
	await enter_market()
	world.hero.position=Vector2(500,620);world.hero.velocity=Vector2.ZERO;await step(8);await key(KEY_E);await step(100)
	check(world.bench_director.is_seated() and not world.hud.panel_open,"market has a genuine seated rest without forced menu")
	check(world.hero.hp==6 and is_equal_approx(world.hero.energy,21),"actual sit restores health while preserving combat-earned energy")
	check(str(world.checkpoint.get("interior",""))=="market" and world.checkpoint.position==[564.0,620.0],"indoor bench saves indoor checkpoint instead of ambiguous street coordinates")
	check(world._bench_saved,"bench saved caption reflects verified persistent checkpoint write")
	await close();await open(true)
	check(world.interior_kind=="market" and world.current_room==4,"restarting project restores last indoor bench topology")
	check(absf(world.hero.position.y-620)<2 and world.hero.is_on_floor(),"restored indoor bench position stays on interior floor")
	check(world.building_return.position==[1960.0,1260.0] and world.combat_state.wallet==141,"indoor checkpoint preserves correct outside return and wallet")
	# Lost currency belongs to the chamber; its room ID must not leak it to
	# another context that intentionally shares that persistent room number.
	await enter_bell()
	world.hero.position=Vector2(1500,1260);world.hero.last_safe_position=world.hero.position
	world.hero.hp=0;world.on_player_death();await step(70)
	check(world.interior_kind=="market" and world.hero.hp==6,"Bell death revives at last actual indoor market rest")
	check(str(world.progress.get("m29_death_location",""))=="bell" and int(world.combat_state.death_drop.get("amount",0))==141,"new loss retains chamber context and full carried amount")
	check(not world.objects.any(func(entry):return str(entry.definition.get("kind",""))=="currency_drop"),"indoor checkpoint never displays a chamber pile in the wrong room")
	await enter_bell()
	check(world.objects.any(func(entry):return str(entry.definition.get("kind",""))=="currency_drop"),"returning to correct Bell chamber restores the recoverable pile")
	world.hero.position=Vector2(1500,1260);world.hero.velocity=Vector2.ZERO;await step(35);await key(KEY_E);await step(5)
	check(world.combat_state.wallet==141 and world.combat_state.death_drop.is_empty(),"genuine E recovers contextual lost coins once")
	await close()
	var report:Dictionary={"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"scope":"Actual keyboard house enter/exit and movement fight entry; configured late starts and death/reward fixtures labelled in source. Indoor checkpoint/reload/context isolation tested."}
	FileAccess.open("user://m29_interiors_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M29 INTERIORS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
