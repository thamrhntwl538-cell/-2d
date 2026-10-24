extends SceneTree
## Native Bell mixer/voice lifecycle probe. Objective PCM; no listening claim.
const Soundscape = preload("res://scripts/audio/m24_soundscape.gd")
const Score = preload("res://scripts/audio/m24_bell_music.gd")
const EVENTS = "res://assets/audio/m24/events.json"
const OUT = "res://previews/m24/audio"
var world: Node2D
var sound: Node
var capture: AudioEffectCapture
var checks := 0
var failures: Array[String] = []
var observations: Dictionary = {}
var album := PackedVector2Array()

class ProbeWorld extends Node2D:
	var gameplay_active := true
	var paused := false
	var boss_active := true
	var hit_stop_remaining := 0.0
	var hero: Node2D
	var hud: Node

class ProbeHUD extends Node:
	var panel_open := false

func _initialize() -> void:
	call_deferred("run_check")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("M24 AUDIO FAIL ", label)

func frames(count: int) -> void:
	for index in range(count): await process_frame

func wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout

func fresh_sound() -> void:
	if is_instance_valid(sound):
		sound.stop_all()
		sound.queue_free()
		await frames(2)
	sound = Soundscape.new()
	world.add_child(sound)
	sound.setup(world)
	await frames(2)

func active_voice() -> Node:
	for entry in sound._players:
		if str(entry.category) == "boss_voice": return entry.player
	return null

func measurement(samples: PackedVector2Array) -> Dictionary:
	var peak := 0.0
	var power := 0.0
	var clipped := 0
	for sample in samples:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		power += (sample.x * sample.x + sample.y * sample.y) * .5
		if absf(sample.x) >= 1 or absf(sample.y) >= 1: clipped += 1
	return {"stereo_frames": samples.size(), "sample_rate": AudioServer.get_mix_rate(), "peak": peak,
		"rms": sqrt(power / maxi(1, samples.size())), "clipped_frames": clipped}

func append_pcm(samples: PackedVector2Array) -> void:
	album.append_array(samples)
	for index in range(roundi(AudioServer.get_mix_rate() * .12)):
		album.append(Vector2.ZERO)

func write_pcm() -> void:
	var data := PackedByteArray()
	data.resize(album.size() * 4)
	for index in range(album.size()):
		data.encode_s16(index * 4, roundi(clampf(album[index].x, -.999969, .999969) * 32767))
		data.encode_s16(index * 4 + 2, roundi(clampf(album[index].y, -.999969, .999969) * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = AudioServer.get_mix_rate()
	wav.stereo = true
	wav.data = data
	check(wav.save_to_wav(OUT + "/bell_native_event_samples.wav") == OK, "Native Master PCM sample reel is saved")

func run_check() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	world = ProbeWorld.new()
	root.add_child(world)
	world.hud = ProbeHUD.new()
	world.add_child(world.hud)
	world.hero = Node2D.new()
	world.hero.position = Vector2(360, 320)
	world.add_child(world.hero)
	var listener := AudioListener2D.new()
	world.hero.add_child(listener)
	listener.make_current()
	capture = AudioEffectCapture.new()
	capture.buffer_length = 3.0
	AudioServer.add_bus_effect(0, capture)
	await fresh_sound()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EVENTS))
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/m23/event_manifest.json"))
	var preserved := true
	for key in legacy.events:
		if sound._events.get(key) != legacy.events[key]: preserved = false
	check(preserved and legacy.events.size() == 51, "All 51 M23 event definitions remain unchanged")
	check(manifest.events.size() == 10, "Ten original Bell event families are loaded")
	var assets_ready := true
	var unique: Dictionary = {}
	var audited: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/m24/audit.json"))
	var audited_lengths: Dictionary = {}
	for entry in audited.files: audited_lengths["res://" + entry.file] = float(entry.seconds)
	for cue in manifest.events:
		for path in manifest.events[cue].files:
			var stream: AudioStream = sound._stream(path)
			if stream == null or absf(stream.get_length() - float(audited_lengths.get(path, -1))) > .001: assets_ready = false
			unique[path] = true
	check(assets_ready and unique.size() == 25, "All 25 production WAV variants import and decode natively")
	var solos: Dictionary = {}
	for cue in manifest.events:
		await fresh_sound()
		capture.clear_buffer()
		check(sound.play_at(cue, world.hero.global_position), "Native playback accepts " + cue)
		var stream: AudioStream = sound._stream(manifest.events[cue].files[0])
		await wait_seconds(stream.get_length() + .12)
		var pcm := capture.get_buffer(capture.get_frames_available())
		var measured := measurement(pcm)
		measured["cue"] = cue
		measured["source"] = manifest.events[cue].files[0]
		measured["runtime_gain_db"] = manifest.events[cue].volume_db
		measured["source_duration_seconds"] = stream.get_length()
		solos[cue] = measured
		append_pcm(pcm)
		check(measured.stereo_frames > 2000 and measured.peak > .005 and measured.rms > .0005 and measured.clipped_frames == 0,
			"Native output is non-silent and unclipped for " + cue)
	observations.native_solo_events = solos
	await fresh_sound()
	check(sound.play_at("bell_step", world.hero.global_position), "First planted foot starts")
	check(not sound.play_at("bell_step", world.hero.global_position), "Immediate duplicate planted foot is rejected")
	await wait_seconds(.20)
	check(sound.play_at("bell_step", world.hero.global_position), "Second separated planted foot starts")
	check(sound.event_log[-1].path.ends_with("bell_step_2.wav"), "Footstep event advances to its second actual sample variant")
	check(sound.event_log[-1].spatial and sound.event_log[-1].position == [360.0, 320.0], "Body sound retains actual world position")
	await fresh_sound()
	check(sound.play_event("bell_voice_strain"), "Sparse exertion starts")
	check(not sound.play_event("bell_voice_hurt"), "Small hurt cannot bypass the shared boss voice gap")
	var prior := active_voice()
	check(sound.play_event("bell_voice_death"), "Critical Bell death bypasses small-bark cooldown")
	var death := active_voice()
	check(death != prior and is_instance_valid(death), "Bell death replaces earlier boss voice")
	check(not sound.play_event("bell_voice_strain"), "Ordinary exertion cannot interrupt Bell death")
	world.paused = true
	world.gameplay_active = false
	world.hud.panel_open = true
	await frames(4)
	check(is_instance_valid(death) and death.stream_paused, "Reading/pause retains and pauses the exact Bell death stream")
	var held: float = death.get_playback_position()
	await wait_seconds(.12)
	check(absf(death.get_playback_position() - held) < .025, "Paused Bell playback position stays frozen")
	check(not sound.play_event("bell_hit"), "Pause rejects new Bell gameplay effects")
	world.paused = false
	world.gameplay_active = true
	world.hud.panel_open = false
	await wait_seconds(.12)
	check(active_voice() == death and not death.stream_paused and death.get_playback_position() > held + .04,
		"Resume advances the same Bell voice without a restart")
	world.gameplay_active = false
	await wait_seconds(.10)
	check(is_instance_valid(death) and death.playing, "Already-started priority Bell death survives inactive defeat transition")
	world.gameplay_active = true
	await fresh_sound()
	capture.clear_buffer()
	var accepted := 0
	var peak_players := 0
	for cue in ["bell_impact", "bell_hit", "bell_swing", "bell_takeoff", "bell_step", "bell_cloth", "bell_voice_hurt", "hit", "parry_light", "hero_hurt"]:
		if sound.play_at(cue, world.hero.global_position): accepted += 1
		peak_players = maxi(peak_players, sound.active_player_count)
	await wait_seconds(.65)
	var burst_pcm := capture.get_buffer(capture.get_frames_available())
	var burst := measurement(burst_pcm)
	burst.accepted_events = accepted
	burst.peak_players = peak_players
	observations.native_contact_load = burst
	append_pcm(burst_pcm)
	check(accepted == 10 and peak_players <= 16, "Mixed hero/Bell contact keeps the inherited player bound")
	check(burst.peak > .01 and burst.peak < .95 and burst.clipped_frames == 0, "Native recommended-gain contact mix has output headroom")
	await fresh_sound()
	var score := Score.new()
	world.add_child(score)
	score.setup(null)
	score.set_phase(1)
	await wait_seconds(1.30)
	check(score.assets_ready and score.tracks[0].playing, "Original Bell score plays through its final native helper")
	capture.clear_buffer()
	for cue in ["bell_impact", "bell_hit", "bell_swing", "bell_takeoff", "bell_step", "bell_cloth", "bell_voice_hurt", "hit", "parry_light", "hero_hurt"]:
		sound.play_at(cue, world.hero.global_position)
	await wait_seconds(1.25)
	var score_pcm := capture.get_buffer(capture.get_frames_available())
	var score_mix := measurement(score_pcm)
	score_mix.score_source = Score.PHASE_PATHS[0]
	score_mix.score_runtime_gain_db = Score.BATTLE_DB
	observations.native_score_contact_load = score_mix
	append_pcm(score_pcm)
	check(score_mix.stereo_frames > 2000 and score_mix.peak > .01 and score_mix.peak < .95 and score_mix.clipped_frames == 0,
		"Native final score plus hero/Bell contact mix remains unclipped with output headroom")
	score.stop_all()
	score.queue_free()
	var returned: Dictionary = sound.event_counts
	returned.bell_hit = 9999
	check(sound.event_counts.bell_hit != 9999, "Bell counters remain read-only snapshots")
	sound.stop_all()
	await wait_seconds(.10)
	check(sound.active_player_count == 0 and sound.get_child_count() == 0, "Cleanup releases all Bell players and stream references")
	write_pcm()
	var report := {"engine": Engine.get_version_info().string, "checks": checks, "failures": failures,
		"passed": failures.is_empty(), "observations": observations, "native_audio_output": true,
		"sample_reel": "previews/m24/audio/bell_native_event_samples.wav", "human_listening_claim": false,
		"method": "AudioEffectCapture reads actual native Godot Master mixer PCM; programmatic event fixture, not a live encounter or listening judgment."}
	FileAccess.open(OUT + "/native_audio_report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("M24 AUDIO REPORT ", JSON.stringify({"checks": checks, "failures": failures, "native_contact_load": burst, "native_score_contact_load": score_mix}))
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	world.queue_free()
	sound = null
	world = null
	await frames(4)
	quit(0 if failures.is_empty() else 1)
