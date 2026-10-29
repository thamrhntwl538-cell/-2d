extends SceneTree
## Door intent/collision and read-only M28 save migration probes. Starts and
## a temporary wall are explicit fixtures; physical key events execute entry.
const WORLD="res://scenes/stage_01/folding_library_m29.tscn"
const Travel=preload("res://scripts/stage/m29_journey.gd")
const OldTravel=preload("res://scripts/stage/m28_journey.gd")
var world:Node2D
var checks:=0
var failures:Array[String]=[]
func _initialize() -> void: run.call_deferred()
func step(n:int=1) -> void:
	for unused in range(n):await physics_frame;await process_frame
func check(ok:bool,caption:String) -> void:
	checks+=1
	if not ok:failures.append(caption);push_error(caption)
func event_key(code:int,pressed:bool) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func pulse(code:int) -> void:
	event_key(code,true);await step(2);event_key(code,false);await step(2)
func released() -> void:
	for a in ["interact","look_up","attack","jump","heal","move_left","move_right"]:
		if InputMap.has_action(a):Input.action_release(a)
func open(restore:bool=false) -> void:
	world=load(WORLD).instantiate();world.restore_saved_game=restore;world.transition_seconds=.06;root.add_child(world);current_scene=world;await step(50)
func close() -> void:
	released();current_scene=null;world.queue_free();await step(5);OS.delay_msec(180)
func place(room:int,p:Vector2) -> void:
	released();world.interior_kind="";world._load_room(room,"left",p);await step(50)
func wait_transition() -> void:
	for tick in range(300):
		await step()
		if not world.transitioning:return
	check(false,"door transition has bounded completion")
func run() -> void:
	check(OS.get_environment("XDG_DATA_HOME").contains("m29_door_safety_userdata"),"isolated save directory")
	if not failures.is_empty():quit(1);return
	Travel.remove_session()
	OldTravel.remove_session()
	if FileAccess.file_exists(OldTravel.SAVE_PATH):DirAccess.remove_absolute(ProjectSettings.globalize_path(OldTravel.SAVE_PATH))
	if FileAccess.file_exists(Travel.SAVE_PATH):DirAccess.remove_absolute(ProjectSettings.globalize_path(Travel.SAVE_PATH))
	await open()
	world.progress.weapon_owned=true;world.combat_state.dash_owned=true
	await place(4,Vector2(1990,1260))
	var serial:int=world.hero.strike_serial
	event_key(KEY_W,true);event_key(KEY_J,true);await step(5);event_key(KEY_W,false);event_key(KEY_J,false);await step(10)
	check(world.interior_kind.is_empty() and not world.transitioning,"Up plus sword stays outside instead of consuming attack as doorway")
	check(world.hero.strike_serial>serial,"same Up plus sword request produces actual approved attack")
	await step(60)
	# Physical wall blocks the short automatic approach; no position snap or
	# through-wall transition is allowed even though E is in prompt radius.
	world.hero.position=Vector2(1960,1260);world.hero.velocity=Vector2.ZERO;await step(5)
	var wall:=StaticBody2D.new();wall.collision_layer=1;var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(12,140);shape.shape=box;shape.position=Vector2(2000,1190);wall.add_child(shape);world.active_room.add_child(wall)
	await pulse(KEY_E);await wait_transition();await step(5)
	check(world.interior_kind.is_empty() and not world.transitioning,"blocked threshold refuses transition")
	check(world.hero.position.x<1990,"blocked alignment never teleports through a real obstacle")
	check(not world.hero.bench_locked and world.hero.disable_mode==CollisionObject2D.DISABLE_MODE_REMOVE,"failed entry restores actor control and original physics mode")
	check(world.gameplay_active and not world.paused,"failed entry resumes normal world play")
	wall.queue_free();await step(3)
	world.hero.position=Vector2(1990,1260);world.hero.velocity=Vector2.ZERO;await step(50)
	event_key(KEY_E,true);await step(3);await wait_transition();await step(80)
	check(world.interior_kind=="market" and not world.transitioning,"clear threshold enters after a real short approach")
	check(world.hero.disable_mode==CollisionObject2D.DISABLE_MODE_REMOVE and not world.hero.bench_locked,"successful entry leaves no alignment collision lease")
	check(world.hero.position.x>200 and world.hero.position.y<625,"held entry input cannot bounce immediately through inside return")
	event_key(KEY_E,false);await step(5)
	world.hero.position=Vector2(150,620);world.hero.velocity=Vector2.ZERO;await step(45)
	await pulse(KEY_W);await wait_transition();await step(5)
	check(world.interior_kind.is_empty() and absf(world.hero.position.x-1960)<3,"fresh up exits to correct paired street anchor")
	await close()
	# A migrated legacy Bell receipt and pile belonged to its old arena, now
	# inside the bindery. Do not expose them in exterior scenery of same roomID.
	if FileAccess.file_exists(Travel.SAVE_PATH):DirAccess.remove_absolute(ProjectSettings.globalize_path(Travel.SAVE_PATH))
	var state=load("res://scripts/combat/m18_combat_state.gd").new();state.dash_owned=true;state.wallet=11;state.death_drop={"room":12,"position":[1500.0,1260.0],"amount":9}
	var progress:Dictionary=load("res://scripts/stage/m22_puzzle_state.gd").new_progress();progress.weapon_owned=true;progress.preview_bell_defeated=true
	load("res://scripts/combat/m22_currency_ledger.gd").create_reward(progress,"miniboss:bell_warden",12,Vector2(1850,1260),45)
	var legacy:Dictionary={"version":18,"environment_preview":true,"checkpoint":{"room":1,"position":[310.0,1260.0]},"progress":progress,"combat":state.serialize(),"energy":44,"language":"ar"}
	OldTravel.atomic_write(OldTravel.SAVE_PATH,legacy)
	var legacysha:=FileAccess.get_sha256(OldTravel.SAVE_PATH)
	await open(true)
	check(FileAccess.get_sha256(OldTravel.SAVE_PATH)==legacysha,"M28 migration leaves original save bytes untouched")
	check(world.combat_state.wallet==11 and bool(world.progress.get("miniboss_bell_defeated",false)),"migration preserves actual wallet and Bell victory")
	check(world._reward_context("miniboss:bell_warden")=="bell" and str(world.progress.get("m29_death_location",""))=="bell","legacy arena reward and death pile are scoped to new real interior")
	await place(12,Vector2(1500,1260))
	check(not world.objects.any(func(entry):return str(entry.definition.get("kind",""))=="currency_drop"),"legacy Bell loss does not appear in outside bindery")
	await place(12,Vector2(1000,1260));await pulse(KEY_E);await wait_transition();await step(5)
	check(world.interior_kind=="bell" and not is_instance_valid(world.registered_boss),"legacy beaten boss chamber remains open without respawning boss")
	check(world.objects.any(func(entry):return str(entry.definition.get("kind",""))=="currency_drop"),"legacy Bell coins remain recoverable in their real chamber")
	check(FileAccess.get_sha256(OldTravel.SAVE_PATH)==legacysha,"entering migrated interior still never writes the old M28 file")
	await close()
	# First migration also reconciles an unconsumed legacy vault envelope,
	# preserving its latest vitals and once-only reward without writing it.
	if FileAccess.file_exists(Travel.SAVE_PATH):DirAccess.remove_absolute(ProjectSettings.globalize_path(Travel.SAVE_PATH))
	state.increase_capacity("archivist_capacity",1)
	var envelope:Dictionary={"schema":28,"boss":"archivist","status":"victory","origin":{"room":6,"position":[2620.0,1980.0]},"checkpoint":{"room":1,"position":[310.0,1260.0]},"progress":progress.duplicate(true),"combat":state.serialize(),"hp":2,"energy":19,"victory_receipt":{"boss":"archivist","hp":0,"state":"victory"}}
	OldTravel.atomic_write(OldTravel.SESSION_PATH,envelope)
	var oldsession_sha:=FileAccess.get_sha256(OldTravel.SESSION_PATH)
	await open(true)
	check(world.current_room==6 and world.hero.hp==2 and is_equal_approx(world.hero.energy,19),"legacy unconsumed vault session migrates latest actual vitals and return")
	check(bool(world.progress.get("miniboss_archivist_defeated",false)) and world.combat_state.capacity==4,"legacy true vault victory preserves once-only capacity receipt")
	var remaining:=0
	for coin in world.CurrencyLedger.room_pending(world.progress,6):
		if str(coin.reward_id)=="miniboss:archivist":remaining+=int(coin.amount)
	check(world.combat_state.wallet+remaining==71,"legacy unconsumed victory pays exactly sixty via physical coins once")
	check(FileAccess.get_sha256(OldTravel.SAVE_PATH)==legacysha and FileAccess.get_sha256(OldTravel.SESSION_PATH)==oldsession_sha,"legacy save and envelope are both byte-identical after migration")
	var prior:Node=world
	world.restart_stage()
	for tick in range(240):
		await step()
		if is_instance_valid(current_scene) and current_scene!=prior:break
	world=current_scene
	await step(40)
	check(world.current_room==1 and world.interior_kind.is_empty() and not bool(world.progress.get("weapon_owned",false)),"explicit restart creates a genuinely new world instead of recopying old save")
	check(world.combat_state.wallet==0 and world.combat_state.capacity==3 and FileAccess.file_exists(Travel.SAVE_PATH),"fresh restart is durably saved with initial inventory")
	check(FileAccess.get_sha256(OldTravel.SAVE_PATH)==legacysha and FileAccess.get_sha256(OldTravel.SESSION_PATH)==oldsession_sha,"new-game reset does not delete or rewrite either older M28 file")
	await close();await open(true)
	check(world.current_room==1 and world.combat_state.wallet==0 and not bool(world.progress.get("weapon_owned",false)),"fresh reset survives next restart without legacy reimport")
	await close()
	var report:Dictionary={"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"scope":"Actual door key/collision/held-input safety plus labelled temporary-wall and legacy-save fixtures."}
	FileAccess.open("user://m29_door_safety_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("M29 DOOR SAFETY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
