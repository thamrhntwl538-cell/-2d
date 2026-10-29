extends SceneTree
## Component integration with real player physics and input. Geometry/starting
## HP are fixture configuration. Full-world save/UI QA is a separate suite.
const Hero=preload("res://scripts/combat/m29_player.gd")
const Director=preload("res://scripts/stage/m29_bench_director.gd")
const State=preload("res://scripts/combat/m18_combat_state.gd")
const Controls=preload("res://scripts/combat/m18_controls.gd")
const Paper=preload("res://scripts/stage/m17_paper_platform.gd")
const Model=preload("res://scripts/warden_model_m29.gd")
const PreviousModel=preload("res://scripts/warden_model_m23.gd")
var checks:=0
var failures: Array[String]=[]
var evidence: Array[Dictionary]=[]
var results: Array[Dictionary]=[]
var world: Node2D

class FixtureHUD extends RefCounted:
	var panel_open:=false
	var closing_panel:=false

class FixtureWorld extends Node2D:
	var gameplay_active:=true
	var boss_active:=false
	var combat_state=State.new()
	var hero: CharacterBody2D
	var active_room: Node2D
	var hud=FixtureHUD.new()
	var objects: Array[Dictionary]=[]
	var director: Node
	var commits:=0
	var resumes:=0
	var strikes:=0
	var sounds: Array[String]=[]
	var checkpoint:=Vector2.ZERO
	var bench: Dictionary={"id":"native_rest","kind":"bench","pos":Vector2(230,620),"seat_height":28.0}
	func _physics_process(_delta: float) -> void:
		if director!=null and not director.is_busy() and Input.is_action_just_pressed("interact"):
			if director.begin(bench):
				gameplay_active=false
				hero.process_mode=Node.PROCESS_MODE_DISABLED
				active_room.process_mode=Node.PROCESS_MODE_DISABLED
	func settled(_definition: Dictionary) -> void:
		commits+=1
		hero.hp=6
		hero.energy=99
		checkpoint=bench.pos+Vector2(64,0)
	func resumed() -> void:
		resumes+=1
		gameplay_active=true
		if is_instance_valid(hero): hero.process_mode=Node.PROCESS_MODE_INHERIT
		if is_instance_valid(active_room): active_room.process_mode=Node.PROCESS_MODE_INHERIT
	func emit_burst(_p: Vector2,_c: Color,_n: int) -> void: pass
	func play_sfx(cue: String) -> void: sounds.append(cue)
	func hero_strike(_kind: String,_facing: int) -> void: strikes+=1
	func cast_code_slash(_point: Vector2,_facing: int) -> void: pass
	func combat_changed() -> void: pass
	func on_player_death() -> void: gameplay_active=false
	func player_fell() -> void: gameplay_active=false
	func show_tip(_text: String) -> void: pass

func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	results.append({"passed":ok,"name":message})
	if not ok:
		failures.append(message)
		print("M29 BENCH FAIL ",message)
func step(ticks: int=1) -> void:
	for _i in range(ticks):
		await physics_frame
		await process_frame
func release_all() -> void:
	for action in Controls.ACTIONS:
		if InputMap.has_action(action): Input.action_release(action)
func pulse(action: String,ticks: int=2) -> void:
	Input.action_press(action)
	await step(ticks)
	Input.action_release(action)
	await step(2)
func fixture(terrain: Array=[],start:=Vector2(140,620)) -> void:
	release_all()
	if is_instance_valid(world):
		world.queue_free()
		await step(3)
	world=FixtureWorld.new()
	root.add_child(world)
	world.active_room=Node2D.new()
	world.add_child(world.active_room)
	if terrain.is_empty(): terrain=[Rect2(0,620,1000,80)]
	for rect in terrain:
		var floor_node:=Paper.new()
		floor_node.configure(rect,false)
		world.active_room.add_child(floor_node)
	world.hero=Hero.new()
	world.hero.world_ref=world
	world.hero.position=start
	world.hero.movement_bounds=Vector2(-1000,2000)
	world.hero.fall_limit=2000
	world.hero.has_blade=true
	world.hero.has_dash=true
	world.hero.has_code_slash=true
	world.add_child(world.hero)
	world.hero.hp=2
	world.hero.energy=12
	var marker:=Node2D.new()
	world.active_room.add_child(marker)
	world.objects.append({"definition":world.bench,"node":marker})
	world.director=Director.new()
	world.add_child(world.director)
	world.director.setup(world)
	world.director.seated.connect(world.settled)
	world.director.stood.connect(world.resumed)
	await step(5)
func until_state(name: String,limit: int=180) -> bool:
	for _i in range(limit):
		if world.director.state==name: return true
		await step()
	return false
func seat() -> void:
	await pulse("interact")
	check(await until_state("seated"),"Ordinary interaction completes the bench lifecycle")
	await step(4)

func pose_checks() -> void:
	var rig:=Model.new()
	var previous:=PreviousModel.new()
	root.add_child(rig)
	root.add_child(previous)
	for motion in ["idle","run","air","land","heal","dash"]:
		rig.set_motion(motion,.37)
		previous.set_motion(motion,.37)
		check(rig.joints==previous.joints,"Non-rest joint geometry identical: "+motion)
	for blend in [0.0,.2,.5,.8,1.0]:
		rig.set_bench_pose(blend,.1,28)
		check(not rig.sword_visible and not rig.strike_active,"Rest cannot expose a sword/contact at blend "+str(blend))
		for side in ["near","far"]:
			var arm: Array=rig.joints[side+"_arm"]
			var leg: Array=rig.joints[side+"_leg"]
			check(is_equal_approx(arm[0].distance_to(arm[1]),30) and is_equal_approx(arm[1].distance_to(arm[2]),26),"Rigid arm lengths retained "+side+" "+str(blend))
			check(is_equal_approx(leg[0].distance_to(leg[1]),32) and is_equal_approx(leg[1].distance_to(leg[2]),24),"Rigid leg lengths retained "+side+" "+str(blend))
	var hip: Vector2=rig.joints.torso[1]
	check(absf((hip.y-456)*.37+28)<.01,"Pelvis meets actual cushion top at28world pixels")
	check(rig.eye_bounds.size()==2,"Both approved eyes retained while seated")
	for side in ["near","far"]:
		var palm: Vector2=rig.joints[side+"_hand"]
		check(absf(palm.y-hip.y)<12 and absf(palm.x-hip.x)<32,"Relaxed palm remains on lap, not held forward: "+side)
	check(rig.HEAD_RECT==previous.HEAD_RECT and rig.ATLAS_PATH==previous.ATLAS_PATH,"No head resize or alternate character texture")
	check((rig.joints.near_leg[3] as Vector2).y<456 and (rig.joints.far_leg[3] as Vector2).y<456,"Both bent legs visibly dangle from cushion, not a compressed sprite")
	rig.free()
	previous.free()

func run() -> void:
	Controls.new().defaults()
	await pose_checks()
	await fixture()
	check(world.hero.is_on_floor(),"Actual hero starts on native floor")
	await pulse("interact")
	await step(8)
	check(world.director.state=="aligning" and world.hero.position.x>140,"Alignment uses visible supported body movement")
	check(world.hero.hp==2 and world.hero.energy==12 and world.commits==0,"No heal/energy/save receipt before settled")
	check(await until_state("seated"),"Sit settles after alignment and authored animation")
	check(world.commits==1 and world.hero.hp==6 and world.hero.energy==99,"One seated signal commits rest once")
	check(world.hero.position.is_equal_approx(Vector2(230,620)),"Physical feet anchor stays on bench floor, centered on seat")
	check(world.hero.bench_locked and world.hero.bench_blend==1,"Seated actor uses genuine rest pose")
	check(world.hero.combat_container.scale==Vector2(.37,.37),"Approved body draw scale retained")
	var seat_node: Node=world.director.furniture.native_rest
	check(seat_node.get_pulse_snapshot().active,"Rest confirmation starts only when seat is occupied")
	check(not world.gameplay_active and world.active_room.process_mode==Node.PROCESS_MODE_DISABLED,"World remains genuinely paused during seated confirmation")
	await step(42)
	check(not seat_node.get_pulse_snapshot().active and seat_node.get_pulse_snapshot().occupied,"Pure visual halo expires while paused, retaining ordinary rest crest")
	check(world.director.is_seated() and world.commits==1,"Halo expiry neither stands nor grants another rest receipt")
	var origin: Vector2=world.hero.position
	world.hud.panel_open=true
	await pulse("attack")
	Input.action_press("jump")
	await step(8)
	check(world.director.is_seated() and world.strikes==0 and world.hero.position==origin,"Open equipment overlay cannot move/jump/attack")
	world.hud.panel_open=false
	world.hud.closing_panel=true
	await step(8)
	world.hud.closing_panel=false
	await step(6)
	check(world.director.is_seated(),"Held UI-accept/Jump cannot leak into standing after menu closes")
	Input.action_release("jump")
	await step(4)
	check(world.director.is_seated(),"Closing menu alone leaves hero seated")
	await pulse("jump")
	check(world.director.state=="rising","Fresh jump initiates rise only after menu release guard")
	check(await until_state("idle"),"Rise reaches play state")
	await step(4)
	check(not world.hero.bench_locked and world.hero.velocity.y<0 and not world.hero.is_on_floor(),"Jump intention executes once after grounded rise")
	check(world.sounds.count("jump")==1,"Deferred stand-jump emits one original jump effect")
	await fixture()
	await seat()
	Input.action_press("move_right")
	check(await until_state("idle"),"Fresh move requests rise")
	await step(6)
	check(world.hero.position.x>235 and world.hero.velocity.x>0,"Held movement resumes through inherited motor after rise")
	Input.action_release("move_right")
	await pulse("attack")
	await step(10)
	check(world.strikes>0,"Ordinary sword combat resumes after leaving bench")
	await fixture()
	Input.action_press("move_right")
	await pulse("interact")
	check(await until_state("rising"),"Direction held through initial sit can get up without a dead input")
	check(world.commits==1,"Initial held direction still waits for actual seating before rising")
	check(await until_state("idle"),"Initial held-direction rise completes")
	Input.action_release("move_right")
	await fixture()
	await seat()
	world.hud.panel_open=true
	Input.action_press("move_right")
	await step(4)
	world.hud.panel_open=false
	await step(15)
	check(world.director.is_seated(),"Direction held from equipment focus cannot stand after the overlay")
	Input.action_release("move_right")
	await step(3)
	await fixture([Rect2(0,620,1000,80),Rect2(180,480,22,140)])
	await pulse("interact")
	await step(80)
	check(world.director.state=="idle" and world.director.cancellation_reason=="blocked_alignment","A solid book blocks alignment instead of teleporting through it")
	check(world.commits==0 and world.hero.hp==2 and world.hero.position.x<180,"Blocked rest gives no checkpoint or free health")
	await fixture([Rect2(0,620,160,80),Rect2(210,620,400,80)])
	await pulse("interact")
	await step(80)
	check(world.director.state=="idle" and world.commits==0,"Unsupported alignment gap never grants a rest")
	check(world.director.cancellation_reason=="unsupported_alignment","A ledge gap has explicit safe cancellation")
	await fixture()
	await pulse("interact")
	check(await until_state("sitting"),"Safe align reaches sit animation")
	world.director.cancel(true,"fixture_abort")
	await step(4)
	check(world.commits==0 and world.hero.hp==2 and not world.hero.bench_locked,"Cancelled sit before settle cannot heal or keep actor locked")
	await fixture()
	world.boss_active=true
	await pulse("interact")
	check(world.director.state=="idle" and world.commits==0,"Active combat rejects a new bench lifecycle")
	await fixture()
	await pulse("jump")
	await pulse("interact")
	check(world.director.state=="idle" and world.commits==0,"Airborne interaction cannot snap player onto seat")
	release_all()
	if is_instance_valid(world): world.queue_free()
	await step(4)
	var source_hashes: Dictionary={}
	for path in ["scripts/combat/m29_player.gd","scripts/warden_model_m29.gd","scripts/stage/m29_bench_director.gd","scripts/stage/m29_bench_furniture.gd"]: source_hashes[path]=FileAccess.get_sha256("res://"+path)
	var report: Dictionary={"checks":checks,"failures":failures,"results":results,"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"scope":"Real hero physics/input and bench component integration. Floor/obstacle/start-health fixtures are explicit; callback simulates world rest commit. Fullworld save/menu integration belongs to independent QA.","source_sha256":source_hashes,"evidence":evidence}
	FileAccess.open("user://m29_bench_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M29 BENCH REPORT ",checks," checks, failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
