extends SceneTree
## Tests imported SFX against the supplied map, then captures real singing PCM.
const SFX = preload("res://scripts/audio/m26_archivist_sfx.gd")
const SONG = preload("res://scripts/audio/m26_archive_singing.gd")
const META := "res://assets/minibosses/m26_imported/meta_p1.json"
const AUDIO_ROOT := "res://assets/audio/m26_imported/"
var failures: Array[String] = []
var checks := 0
var observations: Dictionary = {}
var room: Node2D
var keeper: Node2D
var hero: Node2D
var sfx: Node
var singing: Node
var capture: AudioEffectCapture
var mapping: Dictionary
var metadata: Dictionary

func _initialize() -> void:
	call_deferred("run_checks")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("M26 IMPORTED AUDIO FAIL ",label)

func frames(count: int = 3) -> void:
	for ignored in range(count): await process_frame

func seconds(time: float) -> void:
	await create_timer(time).timeout

func fresh_sfx() -> void:
	if is_instance_valid(sfx):
		sfx.stop_all()
		sfx.queue_free()
		await frames()
	sfx = SFX.new()
	room.add_child(sfx)
	sfx.setup(keeper)

func mapped_items(animation: String, phase: int) -> Array:
	var result: Array = []
	var data: Dictionary = metadata[animation]
	var animation_map: Dictionary = mapping.animations.get(animation,{})
	var events: Array = [{"name":"anim_start","time":0.0}]
	events.append_array(data.events)
	for event in events:
		for item in animation_map.get(String(event.name),[]):
			var name := String(item.sound)
			if phase == 2: name = String(mapping.notes.p2_swap.get(name,name))
			result.append({"sound":name,"source_time":maxf(0.0,float(event.time)+float(item.offset))})
	result.sort_custom(func(a:Dictionary,b:Dictionary):
		if absf(float(a.source_time)-float(b.source_time)) < .000001: return String(a.sound) < String(b.sound)
		return float(a.source_time) < float(b.source_time))
	return result

func normalize_history(history: Array) -> Array:
	var result: Array = []
	for item in history: result.append({"sound":String(item.sound),"source_time":float(item.source_time)})
	result.sort_custom(func(a:Dictionary,b:Dictionary):
		if absf(float(a.source_time)-float(b.source_time)) < .000001: return String(a.sound) < String(b.sound)
		return float(a.source_time) < float(b.source_time))
	return result

func equal_history(a: Array,b: Array) -> bool:
	if a.size() != b.size(): return false
	for index in range(a.size()):
		if String(a[index].sound) != String(b[index].sound): return false
		if absf(float(a[index].source_time)-float(b[index].source_time)) > .00001: return false
	return true

func pcm_metrics() -> Dictionary:
	var pcm := capture.get_buffer(capture.get_frames_available())
	var energy := 0.0
	var peak := 0.0
	var last := -1
	for index in range(pcm.size()):
		var sample := pcm[index]
		energy += sample.length_squared()*.5
		var level := maxf(absf(sample.x),absf(sample.y))
		peak = maxf(peak,level)
		if level > .00001: last = index
	return {"frames":pcm.size(),"rms":sqrt(energy/maxi(1,pcm.size())),"peak":peak,
		"last_nonzero_seconds":float(last+1)/AudioServer.get_mix_rate()}

func run_checks() -> void:
	root.size = Vector2i(1280,720)
	room = Node2D.new()
	root.add_child(room)
	keeper = Node2D.new()
	keeper.name = "KeeperBody"
	keeper.position = Vector2(640,620)
	room.add_child(keeper)
	hero = Node2D.new()
	hero.name = "SilentHero"
	hero.position = Vector2(640,620)
	room.add_child(hero)
	var camera := Camera2D.new()
	room.add_child(camera)
	camera.position = Vector2(640,360)
	camera.make_current()
	metadata = JSON.parse_string(FileAccess.get_file_as_string(META))
	mapping = JSON.parse_string(FileAccess.get_file_as_string(SFX.MAP_PATH))
	var hashes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AUDIO_ROOT+"source_hashes.json"))
	check(metadata.size() == 18 and mapping.animations.size() == 18,"All 18 source animation maps and metadata load")
	await fresh_sfx()
	var wav_count := 0
	var raw_container_ok := true
	var bad_wavs: Array = []
	for path in hashes:
		check(FileAccess.get_sha256(AUDIO_ROOT+path)==String(hashes[path]),"Uploaded bytes unchanged: "+String(path))
		if not String(path).ends_with(".wav"): continue
		wav_count += 1
		var source_bytes := FileAccess.get_file_as_bytes(AUDIO_ROOT+path)
		raw_container_ok = raw_container_ok and source_bytes.decode_u16(20)==65534 and source_bytes.decode_u16(22)==2 and source_bytes.decode_u32(24)==48000 and source_bytes.decode_u16(34)==24 and source_bytes.slice(44,60).hex_encode()=="0100000000001000800000aa00389b71"
		var sound: AudioStreamWAV = sfx._load_sound(String(path).get_file().get_basename())
		if sound == null or not sound.stereo or sound.mix_rate != 48000 or sound.get_length() <= 0:
			bad_wavs.append(path)
	check(wav_count == 43 and bad_wavs.is_empty(),"All 43 supplied raw WAV files decode as 48000 Hz stereo inside Godot")
	check(raw_container_ok,"All source WAV containers are original PCM24 stereo 48 kHz WAVE_FORMAT_EXTENSIBLE")
	observations.decoded_wavs = {"count":wav_count,"failures":bad_wavs,"raw_files_sha256_verified":true,"source_bits":24,"source_rate":48000,"source_channels":2,"source_container":"WAVE_FORMAT_EXTENSIBLE / PCM GUID","runtime_container_adaptation":"In-memory format tag only; source files and PCM payload bytes are preserved. Godot decodes to its supported internal PCM representation."}
	var schedule_rows: Array = []
	for phase in [1,2]:
		for animation in metadata:
			await fresh_sfx()
			sfx.play_animation(animation,phase,metadata[animation],1.15 if phase == 2 else 1.0)
			var duration := float(metadata[animation].duration)
			# Include all positive sound offsets, without crossing a second loop.
			var source_time := duration-.00001 if metadata[animation].loop else duration+2.0
			sfx.advance(source_time/sfx.playback_speed)
			var expected := mapped_items(animation,phase)
			var actual := normalize_history(sfx.history)
			check(equal_history(actual,expected),"Exact event/offset/phase schedule "+str(phase)+":"+String(animation))
			schedule_rows.append({"animation":animation,"phase":phase,"expected":expected,"actual":actual})
	observations.schedules = schedule_rows
	await fresh_sfx()
	sfx.set_paused(true)
	sfx.play_animation("death",1,metadata.death)
	await frames(4)
	check(sfx._voices.all(func(voice):return voice.stream_paused or not voice.playing),"Starting a new clip while paused never starts an unpaused pending 2D voice")
	sfx.set_paused(false)
	await fresh_sfx()
	sfx.play_animation("slam",1,metadata.slam)
	sfx.advance(.473)
	check(not sfx.history.any(func(item):return item.sound=="whoosh_overhead"),"Overhead whoosh does not start before source 0.474 s")
	sfx.advance(.002)
	check(sfx.history.any(func(item):return item.sound=="whoosh_overhead" and absf(item.source_time-.474)<.00001),"Negative 0.4 s offset starts overhead whoosh before 0.874 s impact")
	var before_pause: float = sfx.clock
	var count_pause: int = sfx.history.size()
	sfx.set_paused(true)
	sfx.advance(2.0)
	check(sfx.clock==before_pause and sfx.history.size()==count_pause and sfx._voices.all(func(voice):return voice.stream_paused or (not voice.playing and sfx._pending_paused.has(voice.get_instance_id()))),"Pause freezes the source clock and actual voices")
	sfx.set_paused(false)
	sfx.advance(.4)
	check(sfx.history.any(func(item):return item.sound=="impact_slam"),"Resume preserves upcoming impact")
	var tail: AudioStreamPlayer2D
	for voice in sfx._voices:
		if voice.name=="Archivist_impact_slam": tail=voice
	check(is_instance_valid(tail) and tail.get_parent()==keeper,"SFX emitter belongs to the actual Keeper body")
	sfx.play_animation("idle",1,metadata.idle)
	check(is_instance_valid(tail) and tail.stream!=null,"One-shot impact tail survives the following animation")
	await fresh_sfx()
	sfx.play_animation("indexlock",2,metadata.indexlock)
	sfx.advance(1.2)
	check(sfx._loops.has("wall_close_loop"),"Walls loop starts from walls_close_begin")
	sfx.advance(1.0)
	check(not sfx._loops.has("wall_close_loop"),"Walls loop stops at the exact walls_sink event")
	await fresh_sfx()
	sfx.play_animation("burning",2,metadata.burning)
	sfx.advance(1.10)
	check(sfx._loops.has("fire_loop"),"Fire loop starts with the first ignition")
	sfx.advance(1.12)
	check(not sfx._loops.has("fire_loop"),"Fire loop stops at fire_end")
	# Regression: a loop stopped by an animation switch remains in the voice
	# array until pruning. Let queue_free complete before each cleanup path.
	await fresh_sfx()
	sfx.play_animation("idle",1,metadata.idle)
	await frames(3)
	sfx.play_animation("walk",1,metadata.walk)
	await frames(5)
	check(sfx._voices.any(func(voice):return not is_instance_valid(voice)),"Regression fixture contains a previously freed loop voice before stop_all")
	sfx.stop_all()
	await frames(3)
	check(sfx._voices.is_empty() and keeper.get_child_count()==0,"stop_all safely clears previously freed loop voices")
	sfx.play_animation("idle",1,metadata.idle)
	await frames(3)
	sfx.play_animation("walk",1,metadata.walk)
	await frames(5)
	check(sfx._voices.any(func(voice):return not is_instance_valid(voice)),"Regression fixture contains a freed loop voice before seek")
	sfx.seek(.6)
	await frames(3)
	check(sfx._voices.is_empty() and keeper.get_child_count()==0,"seek safely clears previously freed loop voices")
	sfx.play_animation("idle",1,metadata.idle)
	await frames(3)
	sfx.play_animation("walk",1,metadata.walk)
	await frames(5)
	sfx.play_animation("slam",2,metadata.slam)
	sfx.advance(.6)
	await frames(3)
	check(sfx.history.any(func(item):return item.animation=="slam"),"New animation safely prunes and replaces freed loop voices")
	sfx.play_animation("idle",1,metadata.idle)
	await frames(3)
	sfx.play_animation("walk",1,metadata.walk)
	await frames(5)
	sfx.queue_free()
	sfx=null
	await frames(5)
	check(keeper.get_child_count()==0,"Scene cleanup frees the router after deferred loop deletion without leaked emitters")
	await fresh_sfx()
	sfx.play_animation("walk",1,metadata.walk)
	sfx.advance(1.85)
	check(sfx.history.filter(func(item):return item.sound=="footstep_1").size()==3 and sfx.history.filter(func(item):return item.sound=="footstep_2").size()==2,
		"Two full walk cycles repeat L/R footsteps without losing frame zero")
	sfx.seek(.60)
	var scrub_count: int = sfx.history.size()
	check(sfx._voices.is_empty(),"Scrubbing immediately clears all voices")
	sfx.advance(.01)
	check(sfx.history.size()==scrub_count,"Scrubbing does not burst crossed historical events")
	sfx.stop_all()
	await frames(4)
	capture=AudioEffectCapture.new()
	capture.buffer_length=2.0
	AudioServer.add_bus_effect(0,capture)
	var listener := AudioListener2D.new()
	listener.position=Vector2(0,-55)
	hero.add_child(listener)
	listener.make_current()
	capture.clear_buffer()
	sfx.play_extra("impact_slam")
	sfx.set_paused(true)
	await seconds(.28)
	var pending_pause_pcm := pcm_metrics()
	check(pending_pause_pcm.frames>4000 and pending_pause_pcm.last_nonzero_seconds<.025,"Pausing immediately after a pending 2D play prevents an audible unpaused clip")
	sfx.set_paused(false)
	capture.clear_buffer()
	await seconds(.14)
	var pending_resume_pcm := pcm_metrics()
	check(pending_resume_pcm.frames>1000 and pending_resume_pcm.rms>.0001,"A paused pending 2D clip begins normally when resumed")
	sfx.stop_all()
	await frames(4)
	sfx.play_animation("slam",1,metadata.slam)
	sfx.seek(.85)
	sfx.advance(.025)
	capture.clear_buffer()
	await seconds(.3)
	var impact_pcm := pcm_metrics()
	check(impact_pcm.frames>4000 and impact_pcm.rms>.0001 and impact_pcm.peak<1.0,"Native SFX impact produces audible unclipped stereo PCM")
	sfx.set_paused(true)
	await seconds(.06)
	capture.clear_buffer()
	await seconds(.12)
	var sfx_pause_pcm := pcm_metrics()
	check(sfx_pause_pcm.frames>1000 and sfx_pause_pcm.last_nonzero_seconds<.025,"Pausing actual SFX voices makes Master PCM silent after one mix boundary")
	sfx.set_paused(false)
	capture.clear_buffer()
	await seconds(.13)
	var sfx_resumed_pcm := pcm_metrics()
	check(sfx_resumed_pcm.frames>1000 and sfx_resumed_pcm.rms>.00001,"Resuming actual SFX voices continues their PCM tails")
	sfx.stop_all()
	await frames(4)
	sfx.play_animation("indexlock",2,metadata.indexlock)
	sfx.seek(1.1)
	sfx.advance(.03)
	capture.clear_buffer()
	await seconds(.2)
	var wall_pcm := pcm_metrics()
	check(wall_pcm.frames>4000 and wall_pcm.rms>.00001 and wall_pcm.peak<1.0,"Wall close loop outputs actual unclipped PCM")
	sfx.advance(1.1)
	sfx.stop_all()
	await seconds(.06)
	capture.clear_buffer()
	await seconds(.12)
	var sfx_stopped_pcm := pcm_metrics()
	check(sfx_stopped_pcm.frames>1000 and sfx_stopped_pcm.last_nonzero_seconds<.025,"Stopping imported SFX clears real output within one mix boundary")
	capture.clear_buffer()
	await seconds(.12)
	var sfx_locked_pcm := pcm_metrics()
	check(sfx_locked_pcm.frames>1000 and sfx_locked_pcm.peak<.000001,"Stopped SFX output stays exactly silent after the boundary")
	observations.sfx_pcm={"pending_pause":pending_pause_pcm,"pending_resume":pending_resume_pcm,"impact":impact_pcm,"paused":sfx_pause_pcm,"resumed":sfx_resumed_pcm,"wall_loop":wall_pcm,"stopped":sfx_stopped_pcm,"locked_silence":sfx_locked_pcm}
	listener.clear_current()
	listener.queue_free()
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	sfx.queue_free()
	sfx=null
	await frames(6)
	check(keeper.get_child_count()==0,"Freeing SFX router leaves no body emitters or loop voices")

	capture=AudioEffectCapture.new()
	capture.buffer_length=2.0
	AudioServer.add_bus_effect(0,capture)
	singing=SONG.new()
	room.add_child(singing)
	singing.setup(keeper)
	singing.set_listener(hero)
	check(singing.player.get_parent()==keeper and singing.listener.get_parent()==hero,"Singing emitter and listener physically follow the Keeper and hero")
	singing.set_paused(true)
	check(singing.start_dormant() and not singing.player.playing,"A dormant song requested while paused remains pending and silent")
	await seconds(.15)
	capture.clear_buffer()
	await seconds(.15)
	var singing_pending_pcm := pcm_metrics()
	check(singing_pending_pcm.frames>1000 and singing_pending_pcm.peak<.000001,"Paused pending singing produces no real PCM")
	singing.stop_for_encounter()
	singing.set_paused(false)
	check(not singing.player.playing and not singing.start_dormant(),"Encounter cancels a paused pending singing start permanently")
	check(singing.reset_dormant(),"An explicit fresh encounter reset starts dormant singing")
	singing.set_paused(true)
	await seconds(.15)
	capture.clear_buffer()
	await seconds(.15)
	var immediate_singing_pcm := pcm_metrics()
	check(immediate_singing_pcm.frames>1000 and immediate_singing_pcm.last_nonzero_seconds<.025,"Immediate singing pause also cancels the pending 2D start")
	singing.set_paused(false)
	await frames(4)
	check(singing.is_singing(),"The full provided song starts while dormant after resume")
	singing.player.seek(4.0)
	await seconds(.6)
	var near := pcm_metrics()
	check(near.frames>4000 and near.rms>.001 and near.peak<1.0,"Native Master PCM contains unclipped provided body voice")
	var same_player: AudioStreamPlayer2D = singing.player
	var same_stream: AudioStream = same_player.stream
	singing.set_paused(true)
	var held_position := same_player.get_playback_position()
	await seconds(.15)
	capture.clear_buffer()
	await seconds(.15)
	var singing_paused_pcm := pcm_metrics()
	check(absf(same_player.get_playback_position()-held_position)<.025 and singing_paused_pcm.last_nonzero_seconds<.025,"Normal singing pause freezes the exact position and silences PCM")
	singing.set_paused(false)
	capture.clear_buffer()
	await seconds(.15)
	var singing_resumed_pcm := pcm_metrics()
	check(singing.player==same_player and same_player.stream==same_stream and same_player.get_playback_position()>held_position+.06 and singing_resumed_pcm.rms>.0001,"Normal singing resume preserves the same stream and continues its PCM")
	singing.stop_for_encounter()
	hero.position.x-=1200
	singing.reset_dormant()
	singing.player.seek(4.0)
	await seconds(.10)
	capture.clear_buffer()
	await seconds(.55)
	var far := pcm_metrics()
	check(far.rms>.0001 and float(near.rms)/maxf(float(far.rms),.0000001)>2.5,"The same body singing is actually quieter when the hero is far away")
	singing.stop_for_encounter()
	hero.position.x+=1200
	singing.reset_dormant()
	singing.player.seek(4.0)
	await seconds(.20)
	capture.clear_buffer()
	singing.stop_for_encounter()
	check(singing.encounter_started and not singing.player.playing and singing.player.stream==null,"Fight start synchronously cuts off and clears the actual stream")
	capture.clear_buffer()
	await seconds(.24)
	var cutoff := pcm_metrics()
	check(cutoff.frames>4000 and cutoff.last_nonzero_seconds<.05,"Real PCM stops within one mix boundary after encounter start")
	hero.position.x-=1200
	check(not singing.start_dormant(),"Leaving range cannot restart the encounter song")
	hero.position.x+=1200
	singing.set_paused(true)
	singing.set_paused(false)
	check(not singing.start_dormant(),"Returning and pausing cannot restart the encounter song")
	capture.clear_buffer()
	await seconds(.18)
	var locked := pcm_metrics()
	check(locked.frames>0 and locked.peak<.000001,"Locked encounter output stays actually silent")
	observations.singing_pcm={"paused_pending":singing_pending_pcm,"immediate_pause":immediate_singing_pcm,"normal_pause":singing_paused_pcm,"resumed":singing_resumed_pcm,"near":near,"far":far,"near_far_rms_ratio":float(near.rms)/maxf(float(far.rms),.0000001),"cutoff":cutoff,"locked":locked,"rate":AudioServer.get_mix_rate()}
	singing.stop_for_room_exit()
	singing.queue_free()
	await frames(5)
	check(keeper.get_child_count()==0 and hero.get_child_count()==0,"Room exit frees the body voice and hero listener")
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	var report: Dictionary={"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"passed":failures.is_empty(),
		"scope":"Native Godot raw WAV decode, supplied source bytes and SFX event map, spatial body voice PCM encounter cutoff. No human listening claim.",
		"observations":observations,"hero_voice_added":false,"script_sha256":FileAccess.get_sha256("res://scripts/audio/m26_archivist_sfx.gd")}
	report["command"] = "godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script res://tools/test_m26_imported_audio.gd"
	report["runtime_notes"] = {"rendering":"Native X11 OpenGL compatibility on Mesa llvmpipe; no hardware performance claim", "audio_driver":"Dummy with native AudioEffectCapture Master PCM", "device_sample_rate":AudioServer.get_mix_rate(), "source_wav_sample_rate":48000, "mix_boundary_seconds":512.0/AudioServer.get_mix_rate(), "human_listening_claim":false}
	var frozen: Dictionary = {}
	for path in ["scripts/audio/m26_archivist_sfx.gd", "scripts/audio/m26_archive_singing.gd", "tools/test_m26_imported_audio.gd", "assets/audio/m26_imported/sfx_map.json", "assets/minibosses/m26_imported/meta_p1.json"]:
		frozen[path] = FileAccess.get_sha256("res://"+path)
	report["tested_files_sha256"] = frozen
	FileAccess.open("res://docs/M26_IMPORTED_AUDIO_QA.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	FileAccess.open("user://m26_imported_audio_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M26 IMPORTED AUDIO REPORT ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty()}))
	room.queue_free()
	await frames(5)
	await seconds(.18)
	quit(0 if failures.is_empty() else 1)
