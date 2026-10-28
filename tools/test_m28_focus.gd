extends SceneTree
## Isolated combat fixtures: real keyboard J hits earn the shared reserve, then
## real held H completes Focus. The AI opening is configured to stay idle so
## resource/timing rules can be measured independently from player skill.
const Journey=preload("res://scripts/stage/m28_journey.gd")
const State=preload("res://scripts/combat/m18_combat_state.gd")
var checks:=0
var failures: Array[String]=[]
var samples: Array[Dictionary]=[]
var game: Node2D
var capture_metadata: Array[Dictionary]=[]

func _initialize() -> void: run.call_deferred()
func step(count:=1) -> void:
	for _i in range(count):
		await physics_frame
		await process_frame
func check(ok: bool,caption: String) -> void:
	checks+=1
	if not ok: failures.append(caption); push_error(caption)
func key(code: Key,pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.keycode=code; event.physical_keycode=code; event.pressed=pressed
	Input.parse_input_event(event)
func release_all() -> void:
	for action in ["heal","attack","jump","dash","move_left","move_right","spell"]: Input.action_release(action)
	for code in [KEY_H,KEY_J,KEY_D]: key(code,false)
func capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var folder:="res://previews/m28/focus"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	root.get_texture().get_image().save_jpg(folder+"/"+name+".jpg",.94)
	capture_metadata.append({"file":name+".jpg","hero_hp":game.hero.hp,"hero_energy":game.hero.energy,"boss_hp":game.hp,"healing":game.hero.healing,"healing_context":game.healing_status_context(),"configured_safe_idle":true,"actual_keyboard_hits":3,"actual_held_H":Input.is_action_pressed("heal")})
func stable_opening() -> void:
	game._set_idle(100.0)
	game.hit_stop_remaining=0.0
	game.gameplay_active=true
	game.hero.position=game.keeper.position+Vector2(-95,3)
	game.hero.reset_combat_motion()
	game.hero.facing=1
	game.boss_hit_cooldown=0.0
	await step(3)
func close_game() -> void:
	release_all()
	if is_instance_valid(game):
		current_scene=null
		root.remove_child(game)
		game.free()
	await step(4)
	OS.delay_msec(180)
func make_game(journey: bool) -> void:
	if journey:
		var inventory:=State.new()
		inventory.dash_owned=true
		inventory.spell_owned=true
		var record:={"schema":28,"boss":"archivist","status":"entered","progress":{"weapon_owned":true},"combat":inventory.serialize(),"origin":{"room":6,"position":[2620,1980]},"checkpoint":{"room":1,"position":[310,1260]},"hp":6,"energy":0.0,"language":"ar"}
		check(Journey.atomic_write(Journey.SESSION_PATH,record),"write isolated journey test envelope")
	game=load(Journey.ARCHIVE_SCENE if journey else "res://scenes/minibosses/archivist_trial_m26.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await step(5)
	game.start_encounter()
	await stable_opening()
	game.hero.hurt(1,game.hero.position.x+100)
	await step(20)
	await stable_opening()
	game.hero.energy=0.0

func focus_suite(journey: bool) -> void:
	await make_game(journey)
	var actor: CharacterBody2D=game.hero
	var variant:="journey" if journey else "standalone"
	check(actor.hp==5,"%s: native injury gives one missing lantern" % variant)
	var before_hp: int=game.hp
	for strike in range(3):
		await stable_opening()
		key(KEY_J,true); await step(2); key(KEY_J,false); await step(25)
		check(game.hp==before_hp-strike-1 and is_equal_approx(actor.energy,11.0*(strike+1)),"%s: actual keyboard sword hit %d earns exactly11energy" % [variant,strike+1])
	await stable_opening()
	await capture(variant+"_01_three_hits_33_glow")
	key(KEY_H,true)
	await step(2)
	check(actor.healing and is_equal_approx(actor.energy,0.0) and actor.hp==5,"%s: holding real H reserves33energy and starts channel without instant health" % variant)
	await step(18)
	check(actor.healing and actor.hp==5,"%s: short H hold does not complete Focus early" % variant)
	check(bool(game.vitals.context.get("healing",false)) and float(game.vitals.context.get("heal_progress",0.0))>0.20,"%s: HUD receives actual Focus channel/progress" % variant)
	check(game.focus_hint.visible and not game.focus_hint.text.is_empty(),"%s: held Focus has a compact upper-left status cue" % variant)
	var channel_context: Dictionary=game.healing_status_context()
	await capture(variant+"_02_holding_H")
	var remaining_ticks:=0
	while actor.hp==5 and remaining_ticks<80:
		await step()
		remaining_ticks+=1
	key(KEY_H,false)
	await step(2)
	check(actor.hp==6 and is_equal_approx(actor.energy,0.0),"%s: completed H hold restores one lantern from the three earned sword hits" % variant)
	check(remaining_ticks>=47 and remaining_ticks<=50,"%s: Focus completes after the unchanged1.141s channel to one physics tick" % variant)
	samples.append({"variant":variant,"energy_per_real_hit":11,"hits":3,"focus_cost":33,"held_ticks_before_wait":20,"remaining_ticks":remaining_ticks,"hp_after":actor.hp,"energy_after":actor.energy,"channel_context":channel_context,"hud_healing_after_completion":game.vitals.context.get("healing",false)})
	await capture(variant+"_03_lantern_restored")
	# Insufficient reserve: no silent free heal, no partial debit.
	actor.hp=4; actor.energy=32.0
	await stable_opening()
	key(KEY_H,true); await step(85)
	check(game.healing_status_context().heal_block_reason=="energy" and game.focus_hint.visible,"%s: insufficient reserve explains the33glow requirement beside vitals" % variant)
	key(KEY_H,false); await step(2)
	check(actor.hp==4 and is_equal_approx(actor.energy,32.0),"%s:32energy cannot heal and is not spent" % variant)
	# A held key after a real interruption must be released before another debit.
	actor.energy=99.0
	await stable_opening()
	key(KEY_H,true); await step(18)
	check(actor.healing and is_equal_approx(actor.energy,66.0),"%s: interrupted channel initially pays exactly33" % variant)
	actor.invulnerable=0.0
	actor.hurt(1,actor.position.x+100)
	await step(90)
	check(actor.hp==3 and not actor.healing and is_equal_approx(actor.energy,66.0),"%s: damage interrupts Focus and held H cannot restart or spend again" % variant)
	check(game.healing_status_context().heal_block_reason=="release" and game.focus_hint.visible,"%s: interrupted hold explains release-and-hold requirement" % variant)
	key(KEY_H,false); await step(2)
	await stable_opening()
	key(KEY_H,true)
	var fresh_ticks:=0
	while actor.hp==3 and fresh_ticks<85:
		await step(); fresh_ticks+=1
	key(KEY_H,false); await step(2)
	check(actor.hp==4 and is_equal_approx(actor.energy,33.0),"%s: releasing and holding H again heals normally with one further33cost" % variant)
	# Full health and lateral movement cannot consume Focus.
	actor.hp=6; actor.energy=99.0
	await stable_opening()
	key(KEY_H,true); await step(15); key(KEY_H,false); await step(2)
	check(is_equal_approx(actor.energy,99.0),"%s: full health never spends Focus energy" % variant)
	actor.hp=4
	key(KEY_D,true); key(KEY_H,true); await step(16)
	check(not actor.healing and is_equal_approx(actor.energy,99.0),"%s: moving with H does not spend energy" % variant)
	key(KEY_D,false); await step(4)
	check(actor.healing and is_equal_approx(actor.energy,66.0),"%s: stationary hold after movement begins the normal paid channel" % variant)
	key(KEY_H,false); await step(2)
	await close_game()

func run() -> void:
	check(OS.get_environment("XDG_DATA_HOME").contains("m28_focus_userdata"),"Focus fixtures use isolated userdata without touching player saves")
	if not failures.is_empty(): quit(1); return
	await focus_suite(false)
	await focus_suite(true)
	var report:={"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"renderer":DisplayServer.get_name(),"samples":samples,"capture_metadata":capture_metadata,"scope":"Real keyboard J hit→11energy, three actual hits→33reserve, heldH→one-lantern Focus in standalone and world-journey native scenes. Safe idle AI opening and initial injury/positions are configured fixtures, not a full boss playthrough. Costs, interruption, insufficientreserve, movement and fullHP negative controls included."}
	FileAccess.open("user://m28_focus_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M28 FOCUS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
