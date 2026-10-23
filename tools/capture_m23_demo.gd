extends "res://tools/test_m23_boss_world.gd"
## Native MovieWriter fixture with declared cuts, not an uninterrupted win.
## Only phase selection/HP and composition at labelled cuts are configured.
## The warning clocks, attack geometry, actor motion, audio mix and dodges run.
const DEMO_REPORT := "user://m23_demo_source_report.json"
var caption: Label
var segments: Array[Dictionary] = []
var observations: Dictionary = {}
var first_movie_frame: int = 0
var last_movie_frame: int = 0
var movie_ticks: int = 0
var states_seen: Array[String] = []
var source_hashes: Dictionary = {}

func _initialize() -> void:
	call_deferred("run_demo")

func segment(title: String, configured: Dictionary = {}) -> void:
	caption.text = "M23  /  NATIVE CONFIGURED SHOWCASE  /  "+title
	segments.append({"movie_frame":Engine.get_process_frames(),"tracked_tick":movie_ticks,"caption":title,"configured_cut":configured,"boss_hp":boss.hp,"boss_phase":boss.phase,"hero_hp":hero.hp})
	print("M23 DEMO SEGMENT ",Engine.get_process_frames()," ",title)

func film(count: int) -> void:
	for tick in range(count):
		await step(1)
		movie_ticks += 1
		if is_instance_valid(boss) and not states_seen.has(boss.state): states_seen.append(boss.state)

func composition(pattern: int) -> void:
	release_controls()
	boss.clear_attacks()
	boss.global_position = Vector2(2450,1440)
	hero.position = Vector2(2050,1440)
	hero.velocity = Vector2.ZERO
	hero.reset_combat_motion()
	boss.pattern_index = pattern
	boss._begin_next_pattern()

func snapshot_sources() -> void:
	for path in ["res://scripts/stage/m23_folding_library.gd","res://scripts/combat/m23_player.gd","res://scripts/warden_model_m23.gd","res://scripts/bosses/m23_dr_compiler.gd","res://scripts/bosses/m23_boss_attack.gd","res://scripts/bosses/m23_compiler_visual.gd","res://assets/bosses/m23/compiler_profile_rig_atlas.png","res://scripts/ui/m23_hud.gd","res://scripts/ui/m23_boss_display.gd","res://scripts/audio/m23_boss_music.gd","res://scripts/audio/m23_soundscape.gd","res://assets/audio/m23/event_manifest.json","res://assets/audio/m23/compiler_phase_1.ogg","res://assets/audio/m23/compiler_phase_2.ogg",HERO_ATLAS]:
		source_hashes[path] = FileAccess.get_sha256(path)

func hero_attack_study() -> void:
	release_controls()
	boss.clear_attacks()
	boss.global_position = Vector2(2450,1440)
	hero.position = Vector2(2338,1440)
	hero.velocity = Vector2.ZERO
	hero.reset_combat_motion()
	hero.facing = 1
	boss.pattern_index = 0
	# This cut starts at the same .92-second recovery used by the native
	# phase-one execution. The boss then progresses normally; it is not frozen.
	boss._enter("recover",.92)
	var original_zoom: Vector2 = world.camera.zoom
	var original_center: Vector2 = world.camera.position
	world.camera.zoom = Vector2.ONE*1.05
	world.camera.position = Vector2(2390,1230)
	world.camera.reset_smoothing()
	world.camera.force_update_scroll()
	var serial_before: int = hero.strike_serial
	var health_before: int = boss.hp
	var voice_before := int(world.soundscape.event_counts.get("hero_attack",0))
	var flame_seen := false
	var drive_seen := false
	var settle_seen := false
	for tick in range(150):
		if tick in [12,58,104]: Input.action_press("attack")
		if tick in [14,60,106]: Input.action_release("attack")
		await film(1)
		if hero.attack_time>0:
			flame_seen = flame_seen or not hero.combat_model.arc_polygon.is_empty()
			drive_seen = drive_seen or float(hero.combat_model.pose.get("lean",0))>8
			settle_seen = settle_seen or (hero.attack_elapsed>.15 and float(hero.combat_model.pose.get("lean",0))<0)
	release_controls()
	observations.hero_strike_study = {"actual_attack_inputs":3,"actual_strikes_started":hero.strike_serial-serial_before,"boss_damage_from_actual_inputs":health_before-boss.hp,"hero_attack_voices":int(world.soundscape.event_counts.get("hero_attack",0))-voice_before,"native_compact_flame_seen":flame_seen,"native_body_drive_seen":drive_seen,"native_follow_through_seen":settle_seen,"camera_zoom":1.05,"boss_frozen":false,"configured_initial_recovery":.92}
	check(hero.strike_serial-serial_before==3,"three actual attack inputs start three native compact hero strikes")
	check(health_before-boss.hp>=2,"nearby boss health responds to the actual short flame contacts")
	check(flame_seen and drive_seen and settle_seen,"actual hero input shows the compact orange flame, body drive and recovery")
	check(int(world.soundscape.event_counts.get("hero_attack",0))-voice_before>=2,"actual compact attacks trigger their guarded hero voices")
	world.camera.zoom = original_zoom
	world.camera.position = original_center
	world.camera.reset_smoothing()
	world.camera.force_update_scroll()

func run_demo() -> void:
	remember_user_files()
	if not await make_world(true,false):
		quit(1)
		return
	world.hud.set_language("ar")
	world.boss_music_muted = false
	world.boss_music.set_muted(false)
	if not await begin_trial():
		await dispose_world()
		restore_user_files()
		quit(1)
		return
	var overlay := CanvasLayer.new()
	overlay.layer = 99
	root.add_child(overlay)
	var backing := ColorRect.new()
	backing.position = Vector2(0,680)
	backing.size = Vector2(1280,40)
	backing.color = Color(.018,.026,.04,.98)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(backing)
	caption = Label.new()
	caption.position = Vector2(12,687)
	caption.size = Vector2(1256,27)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font",load("res://assets/fonts/DejaVuSans.ttf"))
	caption.add_theme_font_size_override("font_size",14)
	caption.add_theme_color_override("font_color",Color("e8d5b5"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(caption)
	snapshot_sources()
	first_movie_frame = Engine.get_process_frames()
	segment("NATIVE TRIAL INTRO + FIRST CODE WARNING")
	var evaded_first_target := false
	for tick in range(360):
		Input.action_release("jump")
		if boss.state=="bolts_warning" and not evaded_first_target:
			Input.action_press("move_right")
			evaded_first_target = true
		if hero.position.x>1710: Input.action_release("move_right")
		await film(1)
	observations.first_code_warning_reposition_input = evaded_first_target
	segment("CONFIGURED CUT / NATIVE EXECUTION WARNING + JUMP",{"boss_position":[2450,1440],"hero_position":[2050,1440],"pattern":"sweep"})
	composition(1)
	for tick in range(180):
		if tick==24: Input.action_press("jump")
		if tick==38: Input.action_release("jump")
		await film(1)
	segment("CONFIGURED CUT / NATIVE PILLAR MARKS + REPOSITION",{"boss_position":[2450,1440],"hero_position":[2050,1440],"pattern":"pillars"})
	composition(2)
	for tick in range(180):
		if tick<48: drive_toward(2166)
		else:
			Input.action_release("move_left")
			Input.action_release("move_right")
		await film(1)
	segment("CONFIGURED 1.05X VIEW / ACTUAL HERO ATTACK INPUT + VOICE",{"boss_position":[2450,1440],"hero_position":[2338,1440],"initial_native_recovery":.92,"attack_pose_injection":false,"camera_zoom":1.05})
	await hero_attack_study()
	release_controls()
	boss.clear_attacks()
	boss.invulnerable = 0
	var configured_damage := maxi(0,boss.hp-24)
	segment("DECLARED HP CUT TO 24 / NATIVE PHASE-II TRANSITION + VOICE",{"direct_phase_trigger_damage":configured_damage,"purpose":"show second phase; no player-win claim"})
	check(boss.take_hit(configured_damage,hero.position.x,"configured_movie_phase_cut"),"declared phase cut enters the actual native transition")
	await film(120)
	check(boss.phase==2 and world.boss_music.current_phase==2,"native phase transition switches the actual adaptive score")
	segment("CONFIGURED CUT / PHASE-II LOW CHAINS + INPUT JUMPS",{"boss_position":[2450,1440],"hero_position":[2050,1440],"pattern":"chains","phase":2})
	composition(3)
	var jump_hold := 0
	for tick in range(240):
		if jump_hold>0:
			jump_hold -= 1
			if jump_hold==0: Input.action_release("jump")
		if incoming_chain_near() and hero.is_on_floor() and jump_hold==0:
			Input.action_press("jump")
			jump_hold = 5
		await film(1)
	last_movie_frame = Engine.get_process_frames()
	observations.states_seen = states_seen
	observations.actual_code_shots = boss.total_shots
	observations.final_boss_hp = boss.hp
	observations.hero_hp = hero.hp
	observations.music_phase_changes = world.boss_music.phase_changes
	observations.actual_music_playing = world.boss_music.fight_playing and world.boss_music.tracks[1].playing
	check(hero.hp>0,"configured showcase stays in its live encounter without a death/reset")
	check(states_seen.has("bolts_warning") and states_seen.has("sweep_active") and states_seen.has("pillars_active") and states_seen.has("chains_active"),"native attack warnings and actions all appear")
	check(observations.actual_music_playing,"native original boss score is playing in the captured audio mix")
	var sources_unchanged := true
	for path in source_hashes:
		if FileAccess.get_sha256(path)!=str(source_hashes[path]): sources_unchanged = false
	check(sources_unchanged,"captured product sources remain unchanged throughout the movie")
	await dispose_world()
	overlay.queue_free()
	await process_frame
	var restored := restore_user_files()
	check(restored,"native demo restores prior trial/normal save files")
	var report := {"engine":Engine.get_version_info().string,"writer":"Native Godot MovieWriter","fps":60,"configured_showcase":true,"uninterrupted_playthrough":false,"full_win_claim":false,"actual_input":["ordinary trial entry","move_right away from captured bolts","jump over execution","move into pillar gap","three compact hero attack inputs with body drive/recovery and voice","jump approaching low chains"],"configured_cuts":["sweep composition and pattern","pillar composition and pattern","hero/actor composition and native.92-second recovery start with1.05x study camera; attacks use actual input","explicit direct damage to24HP to demonstrate native phase transition","phase-II chain composition and pattern"],"movie_start_frame":first_movie_frame,"movie_end_frame":last_movie_frame,"tracked_physics_frames":movie_ticks,"segments":segments,"observations":observations,"product_source_sha256":source_hashes,"product_sources_unchanged":sources_unchanged,"save_restored":restored,"failures":failures,"scope":"20.5-second native-rendered configured attack/voice/score showcase. Hero attacks use ordinary attack input. Boss warnings and attacks progress through real code after declared cuts. Not an input-only win or continuous campaign recording."}
	FileAccess.open(DEMO_REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M23 DEMO REPORT ",JSON.stringify(report))
	await process_frame
	quit(0 if failures.is_empty() else 1)
