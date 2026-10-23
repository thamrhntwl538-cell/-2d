extends SceneTree
## Objective native sound routing/physics probe. No listening claim or game win.
const Soundscape = preload("res://scripts/audio/m23_soundscape.gd")
var world: Node2D
var sound: Node
var checks: int = 0
var failures: Array[String] = []
var observations: Dictionary = {}
var capture_effect: AudioEffectCapture

class ProbeHero extends CharacterBody2D:
	var hp: int = 6
	var strike_serial: int = 0
	var healing: bool = false
	var dash_time: float = 0
	var command: float = 0
	var launch: bool = false
	var world_ref: Node
	func _ready() -> void:
		collision_layer = 2
		collision_mask = 1
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(16,60)
		shape.shape = rectangle
		shape.position.y = -30
		add_child(shape)
	func _physics_process(delta: float) -> void:
		if not world_ref.gameplay_active: return
		velocity.x = command
		velocity.y += 1500*delta
		if launch:
			velocity.y = -500
			launch = false
		move_and_slide()

class ProbeWorld extends Node2D:
	var gameplay_active: bool = true
	var paused: bool = false
	var boss_active: bool = false
	var hit_stop_remaining: float = 0
	var current_room: int = 1
	var hero: CharacterBody2D
	var hud: Node
	var data: Dictionary = {}

class ProbeHUD extends Node:
	var panel_open: bool = false

func _initialize() -> void:
	call_deferred("run_check")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		print("M23 SOUNDSCAPE FAIL ",message)

func frames(count: int) -> void:
	for tick in range(count): await process_frame

func active_voice(category: String) -> Node:
	for active in sound._players:
		if str(active.category)==category: return active.player
	return null

func count(cue: String) -> int:
	return int(sound.event_counts.get(cue,0))

func run_check() -> void:
	world = ProbeWorld.new()
	root.add_child(world)
	world.hud = ProbeHUD.new()
	world.add_child(world.hud)
	var floor := StaticBody2D.new()
	floor.position = Vector2(1400,400)
	floor.set_meta("footstep_surface","stone")
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4000,40)
	shape.shape = rectangle
	shape.position.y = 20
	floor.add_child(shape)
	world.add_child(floor)
	world.hero = ProbeHero.new()
	world.hero.world_ref = world
	world.hero.position = Vector2(100,400)
	world.add_child(world.hero)
	sound = Soundscape.new()
	world.add_child(sound)
	sound.setup(world)
	capture_effect = AudioEffectCapture.new()
	capture_effect.buffer_length = 1.0
	AudioServer.add_bus_effect(0,capture_effect)
	await frames(8)
	check(sound.manifest_loaded,"Original event manifest loads")
	check(sound._events.has("spell") and sound._events.has("footstep_paper") and sound._events.has("heal_complete"),"Extended spell/heal/material events are present")
	check(world.hero.is_on_floor(),"Native probe hero rests on an actual floor")
	var assets_ready := true
	for cue in sound._events:
		for path in sound._events[cue].get("files",[]):
			if not FileAccess.file_exists(str(path)): assets_ready = false
	check(assets_ready,"Every final manifest event points to a real audio asset")
	capture_effect.clear_buffer()
	check(sound.play_event("jump"),"Hero jump voice actually starts")
	check(not sound.play_event("jump"),"Jump repeat is rejected inside its event cooldown")
	check(not sound.play_event("hero_attack"),"A different hero bark cannot bypass the category cooldown")
	var jump: Node = active_voice("hero_voice")
	check(is_instance_valid(jump) and jump.volume_db>=-8 and jump.volume_db<=0,"Hero voice is routed at a clear bounded gain")
	await frames(10)
	var available := capture_effect.get_frames_available()
	var samples := capture_effect.get_buffer(available)
	var peak := 0.0
	var squares := 0.0
	for sample in samples:
		peak = maxf(peak,maxf(absf(sample.x),absf(sample.y)))
		squares += (sample.x*sample.x+sample.y*sample.y)*.5
	var rms := sqrt(squares/maxi(1,samples.size()))
	observations.native_hero_jump_mix = {"stereo_frames":samples.size(),"peak":peak,"rms":rms,"method":"AudioEffectCapture on the actual native Master mix; objective data, not a listening claim"}
	check(samples.size()>0 and peak>.005 and rms>.0005,"Actual native output contains non-silent hero jump voice samples")
	check(peak<=1.0,"Captured solo hero voice stays inside the digital output range")
	await frames(18)
	check(sound.play_event("hero_attack"),"Hero attack bark starts after its category gap")
	var hero_voice := active_voice("hero_voice")
	check(sound.play_event("compiler_voice_hurt"),"Boss hurt voice starts independently of hero voice")
	check(not sound.play_event("compiler_voice_attack_2"),"A different boss bark cannot bypass its shared1.1-second category gap")
	var old_boss := active_voice("boss_voice")
	check(sound.play_event("compiler_voice_phase"),"Critical phase roar bypasses the small-bark cooldown")
	var phase := active_voice("boss_voice")
	check(phase!=old_boss and is_instance_valid(phase),"Phase roar replaces only the previous boss voice")
	check(active_voice("hero_voice")==hero_voice,"Boss preemption preserves the concurrent hero voice")
	check(not sound.play_event("compiler_voice_hurt_2"),"A small hurt bark cannot interrupt the phase roar")
	check(sound.play_event("hero_death"),"Critical hero death preempts its own attack voice")
	check(active_voice("boss_voice")==phase,"Hero death preemption preserves the boss voice group")
	world.paused = true
	world.gameplay_active = false
	world.hud.panel_open = true
	await frames(3)
	check(is_instance_valid(phase) and phase.stream_paused,"Real pause retains and pauses the current phase voice stream")
	var held_position: float = phase.get_playback_position()
	await frames(10)
	check(absf(phase.get_playback_position()-held_position)<.025,"Paused phase voice playback position remains frozen")
	check(not sound.play_event("jump"),"Paused gameplay cannot start another hero voice")
	check(sound.play_event("journal_page"),"Semantic page audio remains usable while reading")
	world.paused = false
	world.gameplay_active = true
	world.hud.panel_open = false
	await frames(10)
	check(active_voice("boss_voice")==phase and not phase.stream_paused,"Resume continues the same phase stream without restarting it")
	check(phase.get_playback_position()>held_position+.05,"Resumed phase voice actually advances")
	world.gameplay_active = false
	world.hit_stop_remaining = .04
	await frames(4)
	check(is_instance_valid(phase) and not phase.stream_paused,"Short hit-stop preserves the current voice tail")
	world.gameplay_active = true
	world.hit_stop_remaining = 0
	sound.stop_all()
	await frames(3)
	check(sound.active_player_count==0,"stop_all clears players and stream references")
	var attacks_before := count("hero_attack")
	check(sound.play_event("swing"),"Generic inherited enemy swing still plays its weapon effect")
	check(count("hero_attack")==attacks_before,"Unchanged hero strike serial prevents enemy whooshes from voicing the hero")
	await frames(8)
	world.hero.strike_serial += 1
	check(sound.play_event("swing"),"Actual new hero strike serial starts the slash effect")
	check(count("hero_attack")==attacks_before+1,"A genuine new hero strike adds exactly one attack bark")
	await frames(8)
	sound.play_event("swing")
	check(count("hero_attack")==attacks_before+1,"Further enemy swings cannot reuse the hero serial to add a voice")
	sound.stop_all()
	var stone_before := count("footstep_stone")
	world.hero.command = 210
	await frames(48)
	world.hero.command = 0
	await frames(4)
	check(count("footstep_stone")>stone_before,"Actual grounded movement generates stone footsteps by distance")
	floor.set_meta("footstep_surface","paper")
	world.hero.command = 210
	await frames(42)
	world.hero.command = 0
	await frames(4)
	check(count("footstep_paper")>0,"Actual material metadata selects the distinct paper step event")
	var spatial_steps := true
	for event in sound.event_log:
		if str(event.cue).begins_with("footstep") and not bool(event.spatial): spatial_steps = false
	check(spatial_steps,"Footsteps are anchored in the native world stereo field")
	var still_before := count("footstep_stone")+count("footstep_paper")
	await frames(35)
	check(count("footstep_stone")+count("footstep_paper")==still_before,"Standing still produces no fake steps")
	var land_before := count("land")
	world.hero.launch = true
	await frames(55)
	check(world.hero.is_on_floor() and count("land")==land_before+1,"One real airborne-to-floor transition produces one landing sound")
	world.current_room += 1
	world.hero.position.x += 500
	await frames(8)
	check(count("land")==land_before+1,"A room/position cut never invents another landing")
	world.hero.healing = true
	await frames(4)
	world.hero.hp += 1
	world.hero.healing = false
	await frames(4)
	check(count("heal_start")>0 and count("heal_complete")>0,"Observed healing start/completion routes original semantic cues")
	world.boss_active = false
	sound.play_at("chain_tink",world.hero.position+Vector2(200,-80))
	var quiet_event: Dictionary = sound.event_log[-1]
	world.boss_active = true
	await frames(4)
	sound.play_at("lamp_flicker",world.hero.position+Vector2(-200,-80))
	var fight_event: Dictionary = sound.event_log[-1]
	check(bool(quiet_event.spatial) and bool(fight_event.spatial) and float(fight_event.volume_db)<=-20,"Environment accents stay spatial and quieter during a fight")
	var returned: Dictionary = sound.event_counts
	returned.jump = 9999
	check(count("jump")!=9999,"Public event counter snapshots cannot mutate internal state")
	var burst_accepted := 0
	var peak_players := 0
	for cue in ["swing","dash","hit","hurt","parry_light","compiler_release","compiler_bolts","compiler_sweep","compiler_pillars","compiler_phase","journal_open","journal_page","journal_close","bench","coin","puzzle_success","puzzle_error","paper_rustle","room_transition","spell"]:
		if sound.play_event(cue): burst_accepted += 1
		peak_players = maxi(peak_players,sound.active_player_count)
	check(burst_accepted>=16 and peak_players<=16,"A multi-category burst reaches the load bound without exceeding16 active players")
	observations.burst_bound = {"accepted_events":burst_accepted,"peak_active_players":peak_players,"limit":16}
	sound.stop_all()
	world.gameplay_active = false
	await frames(2)
	check(sound.play_event("hero_death"),"Critical death can start during the automatic inactive respawn window")
	var death := active_voice("hero_voice")
	await frames(8)
	check(is_instance_valid(death) and death.playing and not death.stream_paused,"Death breath continues in real time through respawn rather than resuming stale")
	sound.stop_all()
	await frames(3)
	check(sound.active_player_count==0 and sound.get_child_count()==0,"Final cleanup frees every pooled playback node")
	observations.accepted_event_counts = sound.event_counts
	observations.rejected_event_counts = sound.rejected_counts
	observations.event_log = sound.event_log
	var report := {"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"configured_native_audio_and_floor_probe":true,"human_listening_claim":false,"observations":observations}
	FileAccess.open("user://m23_soundscape_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M23 SOUNDSCAPE REPORT ",JSON.stringify({"checks":checks,"failures":failures,"native_hero_jump_mix":observations.native_hero_jump_mix}))
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	world.queue_free()
	world = null
	sound = null
	await frames(4)
	quit(0 if failures.is_empty() else 1)
