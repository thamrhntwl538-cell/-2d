extends SceneTree
## Independent M28 audio checks. Starts are configured in the real world;
## running, jumping and sword swings use ordinary Input actions. Use isolated
## XDG_DATA_HOME containing m28_steps_userdata; no normal saves are touched.
const WORLD := "res://scenes/stage_01/folding_library_m28.tscn"
const LEGACY := preload("res://scripts/audio/m23_soundscape.gd")
var world: Node2D
var checks: Array[Dictionary]=[]
var assets: Array[Dictionary]=[]
var observations: Dictionary={}
var foot_positions: Array[Vector2]=[]
var capture: AudioEffectCapture

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String, detail: Variant=null) -> void:
	checks.append({"passed":ok,"name":label,"detail":detail})
	print(("PASS " if ok else "FAIL ")+label)
func release_all() -> void:
	for action in ["move_left","move_right","jump","dash","attack","heal","look_up","look_down","spell"]:
		if InputMap.has_action(action): Input.action_release(action)
func step(count:=1) -> void:
	for index in range(count):
		await physics_frame
		await process_frame
		if is_instance_valid(world) and is_instance_valid(world.hero): foot_positions.append(world.hero.global_position)
func foot_events() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for event in world.soundscape.event_log:
		if str(event.cue).begins_with("footstep"): result.append(event)
	return result
func count_steps() -> int: return foot_events().size()
func pcm_statistics(path: String) -> Dictionary:
	var stream:=AudioStreamWAV.load_from_file(path)
	if stream==null: return {"loaded":false}
	var raw:=stream.data
	var peak:=0.0
	var squares:=0.0
	var dc:=0.0
	var clipped:=0
	var longest_body_silence:=0
	var silent_run:=0
	var previous:=0.0
	var max_delta:=0.0
	var first:=0.0
	var last:=0.0
	var total:=raw.size()/2
	for index in range(total):
		var integer:=int(raw[index*2])+(int(raw[index*2+1])<<8)
		if integer>32767: integer-=65536
		var value:=float(integer)/32768.0
		if index==0: first=value
		last=value
		peak=maxf(peak,absf(value))
		squares+=value*value
		dc+=value
		max_delta=maxf(max_delta,absf(value-previous))
		previous=value
		if absf(value)>=.999: clipped+=1
		if index>=int(stream.mix_rate*.006) and index<int(stream.mix_rate*.065):
			if integer==0: silent_run+=1
			else: silent_run=0
			longest_body_silence=maxi(longest_body_silence,silent_run)
	return {"loaded":true,"path":path,"sample_rate":stream.mix_rate,"stereo":stream.stereo,"format":stream.format,"samples":total,"seconds":stream.get_length(),"peak":peak,"rms":sqrt(squares/maxi(1,total)),"dc":dc/maxi(1,total),"clipped_samples":clipped,"first":first,"last":last,"maximum_adjacent_delta":max_delta,"longest_zero_run_in_audible_body":longest_body_silence,"sha256":FileAccess.get_sha256(path)}
func inspect_assets() -> void:
	var hashes: Array[String]=[]
	for surface in ["stone","paper"]:
		for variant in range(1,4):
			var path: String="res://assets/audio/m28/soft_step_%s_%d.wav" % [surface,variant]
			var stats:=pcm_statistics(path)
			assets.append(stats)
			check(bool(stats.loaded) and stats.sample_rate==48000 and not stats.stereo and stats.format==AudioStreamWAV.FORMAT_16_BITS,"Native WAV load: "+surface+" "+str(variant))
			check(stats.clipped_samples==0 and stats.peak>.40 and stats.peak<.43,"PCM has headroom: "+surface+" "+str(variant))
			check(stats.first==0 and stats.last==0 and stats.maximum_adjacent_delta<.16,"PCM boundaries and contact avoid hard discontinuities: "+surface+" "+str(variant),stats.maximum_adjacent_delta)
			check(stats.longest_zero_run_in_audible_body<48 and stats.rms>.04 and stats.seconds>=.15 and stats.seconds<.17,"Audible contact body has no 1ms silent gaps: "+surface+" "+str(variant))
			hashes.append(stats.sha256)
	check(hashes.size()==6 and hashes.reduce(func(acc: Array, value):
		if not acc.has(value): acc.append(value)
		return acc,[]).size()==6,"Six generated contacts are distinct waveforms")

func definitions() -> void:
	var sound: Node=world.soundscape
	for surface in ["stone","paper"]:
		var entry: Dictionary=sound._events["footstep_"+surface]
		check(entry.files.size()==3 and is_equal_approx(float(entry.volume_db),-14.0 if surface=="stone" else -15.0) and bool(entry.spatial),"Live "+surface+" profile uses muted spatial three-variant contacts")
	check(sound._events.jump==LEGACY.FALLBACKS.jump,"Jump remains the approved nonvocal movement effect")
	var originals: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/m23/event_manifest.json")).events
	var bell: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/m24/events.json")).events
	var expected:=LEGACY.FALLBACKS.duplicate(true)
	expected.merge(originals,true)
	for alias in LEGACY.ALIASES:
		if not expected.has(alias) and expected.has(LEGACY.ALIASES[alias]): expected[alias]=expected[LEGACY.ALIASES[alias]].duplicate(true)
	expected.merge(bell,true)
	var muted: Array[String]=[]
	for cue in expected.keys():
		if str(expected[cue].get("category",""))=="hero_voice": muted.append(str(cue))
	for cue in muted: expected.erase(cue)
	if muted.has("jump"): expected.jump=LEGACY.FALLBACKS.jump.duplicate(true)
	for cue in expected:
		var entry: Dictionary=expected[cue]
		if not entry.has("layers"): continue
		var layers: Array=[]
		for layer in entry.layers:
			if not muted.has(str(layer)): layers.append(layer)
		entry.layers=layers
	var changed: Array[String]=[]
	for cue in expected:
		if str(cue) in ["footstep","footstep_stone","footstep_paper"]: continue
		if expected[cue]!=sound._events.get(cue): changed.append(cue)
	check(changed.is_empty(),"All non-footstep cues and gains match previous silent-hero definitions",changed)
	var voice_entries: Array[String]=[]
	for cue in sound._events:
		if str(sound._events[cue].get("category",""))=="hero_voice": voice_entries.append(cue)
	check(voice_entries.is_empty(),"No hero-vocal entry was reintroduced",voice_entries)

func position_fixture(point: Vector2) -> void:
	release_all()
	world._load_room(1,"left",point)
	world.progress.weapon_owned=true
	world.hero.has_blade=true
	world.hero.has_dash=true
	await step(8)
	check(world.hero.is_on_floor(),"Configured run starts on real collision at "+str(point))

func walk_to(target_x: float) -> void:
	var direction:=1.0 if target_x>world.hero.position.x else -1.0
	var action: String="move_right" if direction>0 else "move_left"
	Input.action_press(action)
	for index in range(180):
		if direction*(target_x-world.hero.position.x)<=8: break
		await step()
	Input.action_release(action)
	await step(3)
	check(absf(world.hero.position.x-target_x)<40,"Real run reaches bounded surface target "+str(target_x),world.hero.position.x)

func run() -> void:
	check(OS.get_environment("XDG_DATA_HOME").contains("m28_steps_userdata"),"Audio fixtures use isolated userdata")
	if not bool(checks[0].passed): quit(1);return
	inspect_assets()
	world=load(WORLD).instantiate()
	world.restore_saved_game=false
	root.add_child(world)
	current_scene=world
	await step(8)
	world.music.stop()
	world.boss_music.stop_fight(false)
	definitions()
	capture=AudioEffectCapture.new()
	capture.buffer_length=3.0
	AudioServer.add_bus_effect(0,capture)
	await position_fixture(Vector2(1100,1260))
	var idle_before:=count_steps()
	await step(30)
	check(count_steps()==idle_before,"Idle on floor emits no footsteps")
	capture.clear_buffer()
	var stone_start:=count_steps()
	await walk_to(1760)
	var stone_events: Array[Dictionary]=foot_events().slice(stone_start)
	var stone_files: Array[String]=[]
	var all_stone:=true
	for event in stone_events:
		all_stone=all_stone and str(event.path).begins_with("res://assets/audio/m28/soft_step_stone_") and bool(event.spatial) and is_equal_approx(float(event.volume_db),-14)
		if not stone_files.has(event.path): stone_files.append(event.path)
	check(stone_events.size()>=5 and all_stone,"Real ground run emits muted stone contacts",stone_events)
	check(stone_files.size()==3,"Actual stone run cycles all three source variants",stone_files)
	# Read native real-time mixed output; a Dummy output driver still runs the
	# Godot audio mixer. Background score was stopped only in this test fixture.
	var pcm:=capture.get_buffer(capture.get_frames_available())
	var peak:=0.0
	var squares:=0.0
	var clipped:=0
	for sample in pcm:
		peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
		squares+=(sample.x*sample.x+sample.y*sample.y)*.5
		if absf(sample.x)>=1 or absf(sample.y)>=1: clipped+=1
	observations.native_stone_run_mix={"stereo_frames":pcm.size(),"sample_rate":AudioServer.get_mix_rate(),"peak":peak,"rms":sqrt(squares/maxi(1,pcm.size())),"clipped_frames":clipped}
	check(pcm.size()>1000 and peak>.002 and peak<.15 and clipped==0,"Native running mix is audible, bounded and unclipped",observations.native_stone_run_mix)
	await position_fixture(Vector2(2320,1020))
	var paper_start:=count_steps()
	await walk_to(2710)
	await walk_to(2340)
	var paper_events: Array[Dictionary]=foot_events().slice(paper_start)
	var paper_files: Array[String]=[]
	var all_paper:=true
	for event in paper_events:
		all_paper=all_paper and str(event.path).begins_with("res://assets/audio/m28/soft_step_paper_") and bool(event.spatial) and is_equal_approx(float(event.volume_db),-15)
		if not paper_files.has(event.path): paper_files.append(event.path)
	check(paper_events.size()>=6 and all_paper,"Real one-way shelf run emits muted paper contacts",paper_events)
	check(paper_files.size()==3,"Actual paper run cycles all three source variants",paper_files)
	var spatial_ok:=true
	for event in foot_events():
		var location:=Vector2(float(event.position[0]),float(event.position[1]))
		var matched:=false
		for point in foot_positions:
			if point.distance_to(location)<10: matched=true;break
		spatial_ok=spatial_ok and matched
	check(spatial_ok,"Every footstep originates at a recorded actual hero-foot position")
	var jump_count:=int(world.soundscape.event_counts.get("jump",0))
	Input.action_press("jump")
	for index in range(3): await physics_frame
	var air_before:=count_steps()
	Input.action_press("move_right")
	# Count physical ticks here, so a slow graphics frame cannot turn this
	# airborne window into an entire jump plus an ordinary grounded run.
	for index in range(16): await physics_frame
	check(not world.hero.is_on_floor() and count_steps()==air_before,"Moving through the air emits no footsteps")
	check(int(world.soundscape.event_counts.get("jump",0))>jump_count,"Actual jump still produces its nonvocal physical cue")
	release_all()
	await step(50)
	var paused_before:=count_steps()
	var paused_position: Vector2=world.hero.position
	world._set_paused(true)
	Input.action_press("move_right")
	await step(20)
	check(count_steps()==paused_before and world.hero.position.is_equal_approx(paused_position),"Pause freezes movement and emits no new contacts")
	var quiet:=true
	for entry in world.soundscape._players:
		if str(entry.category)!="ui" and is_instance_valid(entry.player): quiet=quiet and entry.player.stream_paused
	check(quiet,"Existing gameplay audio is paused with the world")
	release_all()
	world._set_paused(false)
	await step(6)
	var sword_before:=int(world.soundscape.event_counts.get("swing",0))
	Input.action_press("attack")
	await step(2)
	Input.action_release("attack")
	await step(28)
	check(int(world.soundscape.event_counts.get("swing",0))==sword_before+1,"Actual sword strike retains one ordinary sword cue")
	var vocals: Array[Dictionary]=[]
	for event in world.soundscape.event_log:
		if str(event.category)=="hero_voice": vocals.append(event)
	check(vocals.is_empty(),"No hero voice plays during run, jump, sword or pause",vocals)
	observations.stone_run=stone_events
	observations.paper_run=paper_events
	observations.final_event_counts=world.soundscape.event_counts
	observations.hero_vocal_events=vocals
	world.soundscape.stop_all()
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	current_scene=null
	root.remove_child(world)
	world.free()
	await step(3)
	OS.delay_msec(200)
	var failed:=checks.filter(func(record): return not record.passed).size()
	var report: Dictionary={"scope":"M28 original soft run contacts, independent native world and PCM audit","engine":Engine.get_version_info().string,"command":"DISPLAY=:95 XDG_DATA_HOME=/workspace/work/m28_steps_userdata godot --path /workspace/-2d --rendering-method gl_compatibility --audio-driver Dummy --script res://tools/test_m28_steps.gd","checks":checks,"assets":assets,"observations":observations,"passed":checks.size()-failed,"failed":failed,"total":checks.size(),"human_listening_claim":false,"originality":"Six original synthesized files; no Hollow Knight audio sampled","actual_run_inputs":true,"configured_start_positions":true,"normal_gameplay_saves_touched":false}
	var file:=FileAccess.open("res://docs/M28_AUDIO_QA.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("M28 AUDIO %d/%d passed" % [checks.size()-failed,checks.size()])
	quit(0 if failed==0 else 1)
