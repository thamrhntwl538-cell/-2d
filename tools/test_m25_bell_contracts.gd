extends SceneTree
## Deterministic mechanics fixtures, explicitly not a live-input fight.
const SCENE:="res://scenes/minibosses/bell_trial_m24.tscn"
const ARENA:=Rect2(1110,940,1080,320)
const DT:=1.0/60.0
var world:Node2D
var hero:CharacterBody2D
var bell:Node2D
var checks:=0
var failures:Array[String]=[]
var endpoints:Array[Dictionary]=[]
var outrun:Array[Dictionary]=[]
var report:Dictionary={}

func _initialize() -> void: call_deferred("run")

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		print("M25 FAIL ",label)

func reset_hero(point:Vector2) -> void:
	hero.position=point
	hero.hp=6
	hero.invulnerable=0
	hero.hurt_time=0
	hero.active_strike_time=0
	hero.velocity=Vector2.ZERO
	world.gameplay_active=true
	world.hit_stop_remaining=0

func make_wave(x:float,side:int,speed:float,volley:String="fixture") -> Node2D:
	var wave=bell.Wave.new()
	world.active_room.add_child(wave)
	wave.setup(world,bell,"chain",Vector2(x,1248),{"velocity":Vector2(side*speed,0),"width":48,"height":24,"boundary_x":1110 if side<0 else 2190,"phase":bell.phase,"volley":volley})
	wave.set_physics_process(false)
	bell.attack_nodes.append(wave)
	return wave

func advance_waves(seconds:float,actor_too:bool=false) -> void:
	for i in range(ceili(seconds/DT)):
		for wave in bell.attack_nodes.duplicate():
			if is_instance_valid(wave) and not wave.spent: wave._physics_process(DT)
		if actor_too: bell._physics_process(DT)

func reset_actor() -> void:
	bell.clear_attacks("fixture_reset")
	bell.position=Vector2(1650,1260)
	bell.phase=1
	bell.phase_pending=false
	bell.phase_transition_count=0
	bell.hp=18
	bell.invulnerable=0
	bell.flight_velocity=Vector2.ZERO
	bell.pattern_index=0
	bell.current_pattern=""
	bell._enter("idle",.22)

func boundaries() -> void:
	for landing in [1210.0,1650.0,2090.0]:
		for speed in [520.0,620.0]:
			for side in [-1,1]:
				reset_hero(Vector2(1130 if side<0 else 2170,1260))
				var wave=make_wave(clampf(landing+side*88,1110,2190),side,speed)
				for i in range(240):
					if wave.spent: break
					wave._physics_process(DT)
				var label:="landing %.0f speed %.0f side %d"%[landing,speed,side]
				check(wave.spent and wave.reached_boundary and wave.expired_reason=="boundary" and absf(wave.position.x-wave.boundary_x)<.01,"full boundary completion: "+label)
				check(hero.hp==5,"standing at the legal arena edge is hit: "+label)
				endpoints.append({"landing":landing,"speed":speed,"side":side,"end_x":wave.position.x,"boundary_x":wave.boundary_x,"reason":wave.expired_reason,"hero_hp":hero.hp})
	reset_hero(Vector2(2170,1260))
	var long_wave=make_wave(1298,1,520)
	long_wave._physics_process(1.15)
	check(not long_wave.spent and long_wave.position.x<2190,"a far crest survives the former 1.15-second cutoff")
	long_wave._physics_process(10)
	check(long_wave.reached_boundary and hero.hp==5,"one long physics segment still sweeps to the endpoint and hurts an edge camper")
	check(bell.attack_nodes.is_empty(),"completed waves prune references without consuming live siblings")

func moving_and_jumping() -> void:
	for speed in [520.0,620.0]:
		for side in [-1,1]:
			var start_x:=1300.0 if side>0 else 2000.0
			reset_hero(Vector2(start_x+side*100,1260))
			var wave=make_wave(start_x,side,speed)
			for i in range(240):
				if wave.spent: break
				hero.position.x=clampf(hero.position.x+side*330*DT,1130,2170)
				wave._physics_process(DT)
			check(hero.hp==5 and wave.reached_boundary,"running faster than the original hero cannot outrun a %.0f crest toward edge %d"%[speed,side])
			outrun.append({"wave_speed":speed,"fixture_run_speed":330,"original_hero_run_speed":hero.SPEED,"side":side,"hero_hp":hero.hp,"reached_boundary":wave.reached_boundary})
	reset_hero(Vector2(1900,1260))
	var first=make_wave(1488,1,620,"landing")
	var second:Node2D
	var jumping:=false
	var vy:=0.0
	var jumps:=0
	for frame in range(200):
		if frame==58: second=make_wave(1488,1,620,"echo")
		if not jumping:
			for wave in [first,second]:
				if is_instance_valid(wave) and not wave.spent and wave.position.x<hero.position.x and hero.position.x-wave.position.x<140:
					jumping=true;vy=hero.JUMP_FORCE;jumps+=1
					break
		if jumping:
			vy+=hero.GRAVITY*DT
			hero.position.y+=vy*DT
			if hero.position.y>=1260 and vy>0:
				hero.position.y=1260;jumping=false
		for wave in [first,second]:
			if is_instance_valid(wave) and not wave.spent: wave._physics_process(DT)
	check(jumps==2 and hero.hp==6,"two original-hero ballistic jumps clear primary and delayed echo crests without invulnerability")
	check(first.reached_boundary and second.reached_boundary,"both jumped crests still reach the edge rather than disappearing on a dodge")
	check(bell.ECHO_SECONDS>2*absf(hero.JUMP_FORCE)/hero.GRAVITY+.15,"echo spacing allows a complete original jump plus a grounded reset")

func lifecycle() -> void:
	reset_actor()
	reset_hero(Vector2(1800,1260))
	bell.hp=10
	bell.current_pattern="leap"
	bell.captured_target=hero.position
	bell._launch(false)
	bell._physics_process(.10)
	var old_y:float=bell.position.y
	check(bell.take_hit(4,hero.position.x,"spell") and bell.hp==9 and bell.phase_pending,"a threshold-crossing spell caps phase-one health at nine")
	bell.invulnerable=0
	check(not bell.take_hit(99,hero.position.x,"spell") and not bell.is_dead and bell.hp==9,"burst followups cannot skip the second phase")
	bell._begin_phase_change()
	check(bell.state=="air" and bell.position.y==old_y and bell.phase_transition_count==0,"half-health transformation never snaps an airborne bell to the floor")
	for i in range(90):
		if bell.state!="air": break
		bell._physics_process(DT)
	check(bell.state=="phase_change" and bell.phase_transition_count==1 and bell.live_wave_count()==2,"first landing starts one grounded transformation and retains its real released waves")
	bell._physics_process(.80)
	check(bell.phase==1 and bell.state=="phase_change" and bell.live_wave_count()==2,"finished transformation pose waits for old crests instead of overlapping a new attack")
	var paused_age:float=bell.age
	var wave:Node2D=bell.attack_nodes[0]
	var paused_wave_age:float=wave.age
	var paused_position:Vector2=wave.position
	world.gameplay_active=false
	bell._physics_process(.5);wave._physics_process(.5)
	check(bell.age==paused_age and wave.age==paused_wave_age and wave.position==paused_position and not wave.spent,"pause freezes transformation and the same live crest")
	world.gameplay_active=true
	for i in range(180):
		advance_waves(DT)
		bell._physics_process(DT)
		if bell.phase==2: break
	check(bell.phase==2 and bell.hp==9 and not bell.phase_pending and bell.live_wave_count()==0,"phase two starts vulnerable at nine only after old waves complete")
	bell.invulnerable=0
	check(bell.take_hit(1,hero.position.x) and bell.hp==8,"phase-two health is damageable immediately after transformation")
	bell.invulnerable=0
	bell._physics_process(.12)
	check(bell.phase_transition_count==1,"further half-health damage cannot repeat the transformation")

func phase_two_moves() -> void:
	reset_hero(Vector2(1300,1260))
	bell.position=Vector2(1650,1260)
	bell.phase=2;bell.phase_pending=false;bell.hp=9;bell.invulnerable=0
	bell.pattern_index=0
	bell._next_pattern()
	check(bell.current_pattern=="double_rush" and bell.state=="double_drawback" and is_equal_approx(bell.state_duration,.28),"phase two opens with its distinct short double-rush preparation")
	bell._physics_process(.28)
	check(bell.state=="double_rush" and 240.0/bell.DOUBLE_RUSH_SECONDS>260.0/bell.RUSH_SECONDS,"new rush release is faster than the original single rush")
	var locked_direction:int=bell.direction
	hero.position.x=1900
	bell._physics_process(.13)
	check(bell.direction==locked_direction and is_equal_approx(bell.position.y,1252),"first fast bound commits facing and follows the native eight-pixel arc")
	bell._physics_process(.13)
	check(bell.state=="turn_gap" and not bell.danger_rect().has_area() and is_equal_approx(bell.position.y,1260),"first fast rush plants into a safe readable turn gap")
	bell._physics_process(.18)
	check(bell.direction==locked_direction,"the body does not track or flip during its planted turn gap")
	bell._physics_process(.18)
	check(bell.state=="double_drawback" and bell.direction==-locked_direction and is_equal_approx(bell.state_duration,.20),"second preparation captures and faces the hero exactly once after the turn")
	bell._physics_process(.20)
	check(bell.state=="double_rush" and bell.rush_number==2,"double rush contains a genuinely separate committed second release")
	bell._physics_process(.26)
	check(bell.state=="recover" and not bell.danger_rect().has_area(),"second rush exposes a grounded recovery")
	bell._next_pattern()
	check(bell.current_pattern=="high_leap" and bell.state=="high_crouch","second phase-two pattern is the new high leap, not an extra old hop")
	bell._physics_process(.26)
	check(bell.state=="high_air" and bell.flight_gravity==3000 and bell.state_duration<710.0*2/1900.0 and 1000.0*1000/6000.0>710.0*710/3800.0,"high leap has a higher apex and shorter flight than the phase-one leap")
	var old_vx:float=bell.flight_velocity.x
	hero.position.x=1130
	bell._physics_process(.10)
	check(bell.flight_velocity.x==old_vx,"high leap keeps its old captured target without homing")
	for i in range(90):
		if bell.state!="high_air": break
		bell._physics_process(DT)
	check(bell.state=="echo_wait" and bell.live_wave_count()==2,"high impact releases its primary full-arena volley")
	var primary_count:int=bell.waves_spawned
	bell._physics_process(.95)
	check(bell.waves_spawned==primary_count,"second pulse is delayed rather than stacked onto the primary hit")
	bell._physics_process(.02)
	check(bell.state=="resonance" and bell.waves_spawned==primary_count+2 and bell.live_wave_count()==4,"natural second floor pulse releases a distinct delayed echo volley")
	var live_before:int=bell.live_wave_count()
	bell._next_pattern()
	check(bell.state=="resonance" and bell.live_wave_count()==live_before,"requesting another pattern cannot cancel any live ground crest")
	bell._physics_process(10)
	check(bell.state=="resonance" and bell.live_wave_count()==live_before,"body attacks wait while either echo volley remains live")
	reset_hero(Vector2(1650,1050))
	advance_waves(3)
	check(bell.live_wave_count()==0 and bell.attack_nodes.is_empty(),"both phase-two volleys complete and prune before the next attack")

func death_cleanup() -> void:
	bell.phase=2;bell.hp=1;bell.invulnerable=0;bell._enter("idle",1)
	bell._spawn_waves(620,"death_fixture")
	var old_waves:Array=bell.attack_nodes.duplicate()
	check(bell.take_hit(1,hero.position.x) and bell.is_dead and bell.live_wave_count()==0,"injected lethal fixture hit clears every live crest immediately")
	var all_death:=true
	for wave in old_waves: all_death=all_death and wave.spent and wave.expired_reason=="death"
	check(all_death and bell.attack_nodes.is_empty(),"death cleanup preserves an honest death reason and releases references")
	check(bell.warning_ar.is_empty() and bell.warning_en.is_empty(),"new phases add no attack warning text")

func stop_audio(node:Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.stop();node.stream=null
	for child in node.get_children():stop_audio(child)

func run() -> void:
	world=load(SCENE).instantiate()
	root.add_child(world)
	for i in range(10): await physics_frame;await process_frame
	hero=world.hero;bell=world.registered_boss
	world.set_process(false);world.set_physics_process(false)
	world.active_room.process_mode=Node.PROCESS_MODE_DISABLED
	hero.set_physics_process(false);bell.set_physics_process(false)
	world.boss_active=true;world.gameplay_active=true
	bell.activated=true;bell.arena=ARENA
	boundaries()
	moving_and_jumping()
	lifecycle()
	phase_two_moves()
	death_cleanup()
	report={"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"scope":"Deterministic fixtures using the native approved hero hurtboxes/constants and real Bell actor/wave collision. Actors and clocks are positioned/stepped directly. Positive fixture damage validates phase/death contracts; this is not a live-input win.","actual_input_fight":false,"fight_win_claim":false,"fixture_damage_to_boss":true,"arena":{"left":1110,"right":2190,"hero_centres":[1130,2170]},"endpoint_matrix":endpoints,"outrun_probes":outrun,"phase_transition_count":bell.phase_transition_count,"wave_completions":bell.waves_completed,"timings":{"phase1_wave_speed":520,"phase2_wave_speed":620,"transformation_animation":.72,"phase2_first_drawback":.28,"phase2_rush_duration":.26,"phase2_rush_distance":240,"turn_gap":.36,"phase2_second_drawback":.20,"high_leap_preparation":.26,"high_leap_launch":1000,"high_leap_gravity":3000,"echo_delay":.96}}
	FileAccess.open("res://docs/M25_COMBAT_QA.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M25 COMBAT REPORT ",JSON.stringify(report))
	world.gameplay_active=false
	world.soundscape.stop_all();world.boss_music.stop_all();stop_audio(world)
	OS.delay_msec(180)
	await process_frame;await process_frame
	world.queue_free()
	await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
