extends SceneTree
## Deterministic combat fixtures. No result here claims an input-only boss win;
## the integrated world QA separately drives the unchanged player controls.
const Boss = preload("res://scripts/bosses/m23_dr_compiler.gd")
var arena: Arena
var boss: Node2D
var checks := 0
var failures: Array[String] = []
var states_seen: Array[String] = []
var observations: Dictionary = {}

class Hero extends Node2D:
	var hp := 999
	var invulnerable := 0.0
	var active_strike_time := 0.0
	var attack_direction := "attack"
	var facing := 1
	var damage_received: Array[int] = []
	func get_hurtboxes() -> Array[Rect2]:
		return [Rect2(global_position+Vector2(-14,-52),Vector2(28,52)),Rect2(global_position+Vector2(-18,-88),Vector2(36,40))]
	func hurt(amount: int,_attack_x: float) -> void:
		if invulnerable>0: return
		hp -= amount
		damage_received.append(amount)
		invulnerable = 1
	func _physics_process(delta: float) -> void:
		invulnerable = maxf(0,invulnerable-delta)
	func _draw() -> void:
		draw_rect(Rect2(-14,-52,28,52),Color("24374a"))
		draw_circle(Vector2(0,-70),19,Color("efb271"))

class Arena extends Node2D:
	var hero: Hero
	var gameplay_active := true
	var boss_active := true
	var defeats := 0
	var cues: Array[String] = []
	var audio_cues: Array[String] = []
	func hero_strike(_direction: String,_facing: int) -> void: pass
	func play_sfx(cue: String) -> void: audio_cues.append(cue)
	func emit_burst(_point: Vector2,_color: Color,_amount: int) -> void: pass
	func compiler_telegraph(pattern: String,_arabic: String,_english: String) -> void: cues.append(pattern)
	func on_compiler_defeated(_actor: Node2D) -> void: defeats += 1
	func _draw() -> void:
		draw_rect(Rect2(1250,700,1650,900),Color("122333"))
		for x in range(1330,2820,180):
			draw_rect(Rect2(x,920,140,510),Color("1b3040"))
			for y in range(1000,1430,80): draw_line(Vector2(x,y),Vector2(x+140,y),Color("41505a"),3,true)
		draw_rect(Rect2(1320,1440,1500,160),Color("0b1722"))
		draw_line(Vector2(1320,1440),Vector2(2820,1440),Color("bca477"),4,true)

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		print("M23 COMPILER FAIL: ",message)

func step(frames: int) -> void:
	for tick in range(frames):
		await physics_frame
		if is_instance_valid(boss) and not states_seen.has(boss.state): states_seen.append(boss.state)

func wait_state(expected: String, limit := 1800) -> bool:
	for tick in range(limit):
		if boss.state==expected: return true
		await step(1)
	return false

func fresh() -> void:
	if is_instance_valid(boss):
		boss.clear_attacks()
		boss.queue_free()
	await process_frame
	arena.gameplay_active = true
	arena.boss_active = true
	arena.hero.position = Vector2(1700,1440)
	arena.hero.hp = 999
	arena.hero.invulnerable = 0
	arena.hero.damage_received.clear()
	arena.audio_cues.clear()
	boss = Boss.new()
	arena.add_child(boss)
	boss.setup(arena,Vector2(2450,1440),Rect2(1320,940,1500,500))
	await step(3)

func run() -> void:
	arena = Arena.new()
	root.add_child(arena)
	arena.hero = Hero.new()
	arena.add_child(arena.hero)
	var ground := StaticBody2D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	ground.position = Vector2(2070,1520)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1500,160)
	collider.shape = shape
	ground.add_child(collider)
	arena.add_child(ground)
	var camera := Camera2D.new()
	camera.position = Vector2(2070,1190)
	camera.zoom = Vector2(.78,.78)
	arena.add_child(camera)
	camera.make_current()
	await fresh()
	await step(100)
	check(boss.state=="dormant" and boss.hp==48 and boss.total_shots==0,"inactive boss stays dormant without shooting")
	check(not boss.take_hit(48,1700) and boss.hp==48 and arena.defeats==0,"dormant boss cannot be damaged before legitimate activation")
	arena.hero.position.x = 2660
	await step(2)
	check(boss.direction==1 and boss.state=="dormant","dormant side-view boss faces a hero standing to its right")
	arena.hero.position.x = boss.position.x+5
	await step(2)
	check(boss.direction==1,"small positive centre overlap stays inside the facing deadzone")
	arena.hero.position.x = boss.position.x-5
	await step(2)
	check(boss.direction==1,"crossing inside the12px deadzone does not flicker the side-view rig")
	arena.hero.position.x = 1700
	await step(2)
	check(boss.direction==-1,"dormant side-view boss turns toward the hero on its left")
	boss.start_encounter()
	check(boss.state=="intro" and not boss.take_hit(1,1700),"intro grants its explicit safe activation grace")
	check(arena.audio_cues.count("compiler_voice_intro")==1,"legitimate encounter entry emits its boss introduction voice once")
	arena.hero.position.x = 2660
	await step(2)
	check(boss.direction==1 and boss.state=="intro","safe intro presentation keeps facing the opponent")
	arena.hero.position.x = 1700
	await step(2)
	check(boss.direction==-1,"intro presentation can safely turn back before its first warning")
	check(await wait_state("idle"),"intro reaches its ordinary unchanged idle interval")
	arena.hero.position.x = 2660
	await step(2)
	check(boss.direction==1 and boss.state=="idle","idle side-view rig faces a crossing opponent")
	arena.hero.position.x = 1700
	await step(2)
	check(await wait_state("bolts_warning"),"native phase1 enters code warning")
	check(not boss.warning_ar.is_empty() and not boss.warning_en.is_empty(),"warning supplies concise bilingual instructions")
	var old_target: Vector2 = boss.captured_target
	var old_aim: Vector2 = boss.aim
	var before_shots: int = boss.total_shots
	await step(34)
	check(boss.total_shots==before_shots and boss.state=="bolts_warning","warning provides more than half a second without live shots")
	arena.hero.position.x += 130
	check(boss.captured_target==old_target and boss.aim==old_aim,"moving during warning cannot retarget the captured code burst")
	check(await wait_state("bolts_active"),"native warning becomes active burst")
	var burst_direction: int = boss.direction
	arena.hero.position.x = 2660
	await step(2)
	check(boss.direction==burst_direction and boss.aim==old_aim,"crossing during active code cannot mirror its captured facing or projectile aim")
	var saved_time: float = boss.state_time
	var saved_age: float = boss.age
	var node_ages: Array[float] = []
	for attack in boss.attack_nodes:
		if is_instance_valid(attack): node_ages.append(attack.age)
	arena.gameplay_active = false
	await step(70)
	check(boss.state_time==saved_time and boss.age==saved_age,"pause freezes boss clocks rather than cancelling or retargeting")
	var index := 0
	var attacks_frozen := true
	for attack in boss.attack_nodes:
		if is_instance_valid(attack):
			attacks_frozen = attacks_frozen and attack.age==node_ages[index]
			index += 1
	check(attacks_frozen,"pause freezes detached projectile clocks")
	arena.gameplay_active = true
	check(await wait_state("recover"),"code flight ends in a finite recovery window")
	check(boss.total_shots-before_shots==3,"phase1 emits exactly three native code shots")
	check(arena.audio_cues.count("compiler_release")==3 and not arena.audio_cues.has("swing"),"boss releases use a dedicated effect and cannot trigger generic hero swing vocals")
	await step(2)
	check(boss.direction==1 and boss.state=="recover","the first safe recovery turns the side-view boss toward the new hero position")
	check(await wait_state("sweep_warning"),"next native learned pattern warns before its heavy sweep")
	var fixed_facing: int = boss.direction
	var warning_time: float = boss.state_time
	var accepted_hits := 0
	for hit in range(3):
		if boss.take_hit(1,1700): accepted_hits += 1
		await step(8)
	check(accepted_hits==3 and boss.state=="sweep_warning" and boss.state_time<warning_time,"small sword hits never restart the warning or stunlock the boss")
	arena.hero.position.x = boss.position.x-float(fixed_facing)*210.0
	check(await wait_state("sweep_active"),"heavy sweep naturally activates")
	check(boss.direction==fixed_facing,"crossing the boss during warning never reverses active facing")
	var blade: Rect2 = boss.danger_rect()
	check(blade.size==Vector2(384,96) and blade.position.y==boss.global_position.y-118,"visible execution field matches the exact active damage rectangle")
	check(blade.encloses(boss.clash_rect()) and boss.get_contact_damage()==2,"heavy blade has a reachable clash edge and deals two hearts")
	var jumping := Rect2(Vector2(blade.get_center().x-18,1440-145-88),Vector2(36,88))
	check(not blade.intersects(jumping),"ordinary held jump clears the complete execution field")
	var root_before: Vector2 = boss.global_position
	await step(4)
	check(absf(boss.global_position.x-root_before.x)<=240 and boss.global_position.y==1440,"execution movement stays on the floor with a bounded fixed-facing dash")
	check(boss.on_clash() and boss.state=="stagger" and not boss.danger_rect().has_area(),"legitimate sword clash cancels the active blade into finite stagger")
	check(not boss.on_clash(),"a second clash cannot restart stagger indefinitely")
	await step(8)
	check(boss.direction==fixed_facing and boss.state=="stagger","stagger retains attack-facing until the next safe recovery or idle")
	check(await wait_state("pillars_warning"),"native compiler reaches captured-ground pillar warning")
	var targets: Array[float] = boss.pillar_targets.duplicate()
	check(targets.size()>=2 and targets.size()<=3,"pillar layout creates a bounded count of clear columns")
	var safe_near_target := false
	for x in range(int(boss.captured_target.x-270),int(boss.captured_target.x+270),5):
		if x<1342 or x>2798: continue
		var safe := true
		for column in targets:
			if absf(float(x)-column)<61: safe = false
		if safe: safe_near_target = true
	check(safe_near_target,"an upright44px hero has a reachable unmarked safe gap within the warning's movement budget")
	var harmless_warning := true
	for attack in boss.attack_nodes:
		if is_instance_valid(attack): harmless_warning = harmless_warning and not attack.damage_rect().has_area()
	check(harmless_warning,"all column markers are harmless during their warning")
	arena.hero.position.x -= 170
	await step(15)
	check(boss.pillar_targets==targets,"floor columns preserve old captured positions after hero moves")
	check(await wait_state("pillars_active"),"marked columns activate only after their full warning")
	await step(2)
	var active_columns := 0
	for attack in boss.attack_nodes:
		if is_instance_valid(attack) and attack.kind=="pillar":
			active_columns += 1
			check(attack.damage_rect().size==Vector2(74,330),"active column light rectangle equals its damaging rectangle")
	check(active_columns==targets.size(),"only the earlier warned columns become active")
	await fresh()
	boss.start_encounter()
	check(await wait_state("bolts_active"),"phase-boundary fixture begins with real active code")
	await step(2)
	check(boss.take_hit(24,1700) and boss.hp==24 and boss.phase==2,"exact24HP boundary enters second phase")
	var phase_entry_age: float = boss.age
	var phase_entry_facing: int = boss.direction
	check(boss.state=="phase_transition" and boss.attack_nodes.is_empty(),"phase transition clears previous hazards")
	check(not boss.take_hit(1,1700),"transition cannot be skipped by repeated sword hits")
	check(is_equal_approx(boss.state_duration,Boss.PHASE_TRANSITION_SECONDS),"phase animation uses its named full presentation duration")
	check(arena.audio_cues.count("compiler_voice_phase")==1 and not arena.audio_cues.has("compiler_phase"),"phase voice starts before the delayed resonant phase effect")
	arena.hero.position.x = 2660
	await step(2)
	check(boss.direction==phase_entry_facing and boss.state=="phase_transition","fold and roar keep the opponent-facing direction captured once on phase entry")
	arena.hero.position.x = 1700
	await step(2)
	await step(maxi(0,int((Boss.PHASE_TRANSITION_SECONDS-.10)*60)-4))
	check(boss.state=="phase_transition" and not boss.take_hit(1,1700),"the entire readable transformation remains harmless and invulnerable through its final tenth-second")
	while boss.state=="phase_transition": await step(1)
	var actual_phase_seconds: float = boss.age-phase_entry_age
	check(actual_phase_seconds>=Boss.PHASE_TRANSITION_SECONDS and actual_phase_seconds<Boss.PHASE_TRANSITION_SECONDS+.05,"native phase clock completes the full named duration before the next action")
	check(arena.audio_cues.find("compiler_voice_phase")<arena.audio_cues.find("compiler_phase"),"resonant phase effect follows the original vocal buildup")
	check(await wait_state("bolts_warning"),"second phase resumes known readable code pattern")
	before_shots = boss.total_shots
	check(await wait_state("recover"),"second-phase burst still gives a finite counter window")
	check(boss.total_shots-before_shots==4 and boss.state_duration>=.55,"second phase adds measured pressure with four shots and a real recovery")
	check(await wait_state("chains_warning",2400),"second phase introduces its clearly warned low-chain pattern")
	check(boss.warning_en.contains("jump") and boss.warning_ar.contains("اقفز"),"chain warning states the appropriate ordinary-jump response")
	check(await wait_state("chains_active"),"native chain warning becomes an active low crossing")
	await step(2)
	var chains := 0
	for attack in boss.attack_nodes:
		if is_instance_valid(attack) and attack.kind=="chain":
			chains += 1
			check(attack.damage_rect().size==Vector2(68,18) and absf(attack.travel.x)==370,"parse chains use their visible low18px band at a fixed readable speed")
	check(chains==2,"two edge chains form the learned phase2 jump challenge")
	var previous_defeats := arena.defeats
	boss.invulnerable = 0
	check(boss.take_hit(24,1700) and boss.is_dead and not boss.alive and boss.hp==0,"real lethal hit enters the final dead state")
	check(arena.defeats==previous_defeats+1 and boss.attack_nodes.is_empty(),"death clears every hazard and notifies stage exactly once")
	check(not boss.take_hit(1,1700) and arena.defeats==previous_defeats+1,"dead boss cannot produce another reward callback")
	check(arena.audio_cues.count("compiler_voice_death")==1,"real defeat emits its dedicated boss death voice once")
	check(not boss.get_hitbox().has_area() and not boss.danger_rect().has_area(),"dead boss has no attacking or receiving volume")
	observations={"phase1_pattern_order":["bolts","sweep","pillars"],"phase2_pattern_order":boss._pattern_history,"clash_stagger_seconds":.48,"phase_transition_seconds":Boss.PHASE_TRANSITION_SECONDS,"actual_phase_transition_seconds":actual_phase_seconds,"safe_facing_deadzone":12.0,"safe_facing_states":["dormant","intro","idle","recover"],"warning_active_stagger_and_phase_keep_captured_facing":true,"hero_is_high_health_fixture":true,"real_input_victory_claim":false}
	var report := {"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"states_seen":states_seen,"observations":observations,"scope":"Deterministic native-physics combat fixtures; direct boss hit/clash calls are labelled fixtures, not an input-only campaign win."}
	FileAccess.open("user://m23_compiler_focused_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M23_COMPILER_FOCUSED_RESULT ",JSON.stringify(report))
	boss.clear_attacks()
	arena.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
