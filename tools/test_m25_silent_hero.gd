extends SceneTree
## Native presentation fixture using the actual inherited hero attack method.
## No combat victory or human listening claim. Writes only M25_AUDIO_QA.json.
const Soundscape = preload("res://scripts/audio/m24_soundscape.gd")
const Legacy = preload("res://scripts/audio/m23_soundscape.gd")
const Score = preload("res://scripts/audio/m24_bell_music.gd")
var world: Node2D
var sound: Node
var capture: AudioEffectCapture
var checks := 0
var failures: Array[String] = []
var observations: Dictionary = {}

class StrikeHero extends "res://scripts/combat/m23_player.gd":
	# Use the production _start_attack and strike_serial without loading a
	# whole encounter/save or letting traversal generate unrelated audio.
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

class ProbeWorld extends Node2D:
	var gameplay_active := true
	var paused := false
	var boss_active := true
	var hit_stop_remaining := 0.0
	var hero: CharacterBody2D
	var hud: Node
	var soundscape: Node
	func play_sfx(cue: String) -> void:
		if is_instance_valid(soundscape): soundscape.play_event(cue)

class ProbeHUD extends Node:
	var panel_open := false

func _initialize() -> void:
	call_deferred("run_check")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("M25 SILENT HERO FAIL ", label)

func frames(count: int) -> void:
	for tick in range(count): await process_frame

func wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout

func fresh_sound() -> void:
	if is_instance_valid(sound):
		sound.stop_all()
		sound.queue_free()
		await frames(2)
	sound = Soundscape.new()
	world.add_child(sound)
	world.soundscape = sound
	sound.setup(world)
	await frames(2)

func measure(samples: PackedVector2Array) -> Dictionary:
	var peak := 0.0
	var squares := 0.0
	var clipped := 0
	for sample in samples:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		squares += (sample.x * sample.x + sample.y * sample.y) * .5
		if absf(sample.x) >= 1 or absf(sample.y) >= 1: clipped += 1
	return {"stereo_frames": samples.size(), "sample_rate": AudioServer.get_mix_rate(),
		"peak": peak, "rms": sqrt(squares / maxi(1, samples.size())), "clipped_frames": clipped}

func capture_measure() -> Dictionary:
	return measure(capture.get_buffer(capture.get_frames_available()))

func no_hero_voice_logged() -> bool:
	for event in sound.event_log:
		if str(event.category) == "hero_voice": return false
	return true

func run_check() -> void:
	world = ProbeWorld.new()
	root.add_child(world)
	world.hud = ProbeHUD.new()
	world.add_child(world.hud)
	world.hero = StrikeHero.new()
	world.hero.world_ref = world
	world.hero.has_blade = true
	world.hero.position = Vector2(360, 320)
	world.add_child(world.hero)
	var listener := AudioListener2D.new()
	world.hero.add_child(listener)
	listener.make_current()
	capture = AudioEffectCapture.new()
	capture.buffer_length = 3.0
	AudioServer.add_bus_effect(0, capture)
	await fresh_sound()
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/m23/event_manifest.json"))
	var bell: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/m24/events.json"))
	var muted: Array[String] = []
	for cue in original.events:
		if str(original.events[cue].category) == "hero_voice" and cue != "jump": muted.append(cue)
	var voices_removed := true
	var vocal_layers_removed := true
	for cue in sound._events:
		var entry: Dictionary = sound._events[cue]
		if str(entry.get("category", "")) == "hero_voice": voices_removed = false
		for layer in entry.get("layers", []):
			if muted.has(str(layer)): vocal_layers_removed = false
	check(voices_removed, "M24 local event map contains no hero_voice entries")
	check(vocal_layers_removed, "All inherited hero vocal layers are stripped")
	check(sound._events.jump == Legacy.FALLBACKS.jump, "Jump retains its original nonvocal movement effect")
	var bell_unchanged := true
	for cue in bell.events:
		if sound._events.get(cue) != bell.events[cue]: bell_unchanged = false
	check(bell_unchanged, "All ten Bell effects/voice definitions and gains remain unchanged")
	var retained := true
	for cue in original.events:
		var entry: Dictionary = original.events[cue].duplicate(true)
		if str(entry.category) == "hero_voice": continue
		var kept: Array = []
		for layer in entry.get("layers", []):
			if not muted.has(str(layer)): kept.append(layer)
		entry.layers = kept
		if sound._events.get(cue) != entry: retained = false
	check(retained, "Inherited sword/contact/movement/enemy/UI definitions are preserved except hero vocal layers")
	capture.clear_buffer()
	for cue in muted:
		check(not sound.play_event(cue), "Direct hero vocal is silent: " + cue)
	world.gameplay_active = false
	check(not sound.play_event("hero_death"), "Inactive respawn death exception cannot bypass hero mute")
	world.gameplay_active = true
	await wait_seconds(.16)
	var silence := capture_measure()
	check(sound.event_log.is_empty() and sound.active_player_count == 0, "Muted aliases allocate no players and log no successful playback")
	check(silence.stereo_frames > 0 and silence.peak < .000001, "Actual native Master output stays silent for direct hero vocal calls")
	observations.muted_direct_cues = muted
	observations.native_muted_output = silence
	capture.clear_buffer()
	var serial: int = world.hero.strike_serial
	world.hero._start_attack()
	check(world.hero.strike_serial == serial + 1 and int(sound.event_counts.get("swing", 0)) == 1,
		"Production hero _start_attack advances a real strike serial and starts the sword effect")
	check(sound.event_log.size() == 1 and sound.event_log[0].path.ends_with("hero_slash_1.wav"),
		"A real hero strike selects only its sword slash sample")
	await wait_seconds(.23)
	var sword := capture_measure()
	check(sword.stereo_frames > 0 and sword.peak > .005 and sword.rms > .0005 and sword.clipped_frames == 0,
		"Sword-only native output remains audible and unclipped")
	for index in range(2):
		world.hero._start_attack()
		await wait_seconds(.10)
	check(world.hero.strike_serial == serial + 3 and int(sound.event_counts.get("swing", 0)) == 3,
		"Three genuine strike serials retain three sword effects")
	check(int(sound.event_counts.get("hero_attack", 0)) == 0 and no_hero_voice_logged(),
		"New strike serials never layer hero attack vocals")
	observations.sword_only_native_output = sword
	observations.actual_production_strikes = {"start_serial": serial, "end_serial": world.hero.strike_serial,
		"sword_events": sound.event_counts.get("swing", 0), "hero_attack_events": sound.event_counts.get("hero_attack", 0)}
	await fresh_sound()
	sound._events["future_hero_alias"] = original.events.hero_attack.duplicate(true)
	check(not sound.play_event("future_hero_alias"), "Playback boundary rejects a hero_voice alias added after setup")
	sound._events["future_layered_sword"] = sound._events.swing.duplicate(true)
	sound._events.future_layered_sword.layers = ["future_hero_alias"]
	check(sound.play_event("future_layered_sword"), "Playback boundary preserves a parent effect with a newly added vocal layer")
	check(int(sound.event_counts.get("future_hero_alias", 0)) == 0 and no_hero_voice_logged(),
		"A future recursive vocal layer cannot start audio")
	await fresh_sound()
	var physical_events := ["dash", "hurt", "hit", "parry_light", "jump", "land", "footstep_stone", "footstep_paper", "spell", "heal_complete", "heal_cancel", "paper_rustle", "bell_cloth"]
	var accepted := true
	for cue in physical_events:
		if not sound.play_at(cue, world.hero.global_position): accepted = false
	check(accepted, "Nonvocal dash/hurt/jump/healing/spell/footsteps/cloth/contact effects still play")
	check(no_hero_voice_logged(), "Physical action burst logs no hero voice")
	check(sound.active_player_count <= 16, "Physical action burst respects the inherited 16-player bound")
	await fresh_sound()
	capture.clear_buffer()
	check(sound.play_event("bell_voice_strain"), "Bell exertion voice remains enabled")
	await wait_seconds(.25)
	var enemy := capture_measure()
	check(enemy.stereo_frames > 0 and enemy.peak > .005 and enemy.rms > .0005 and enemy.clipped_frames == 0,
		"Bell voice still produces unclipped native PCM")
	check(sound.play_event("bell_voice_death"), "Priority Bell death still preempts ordinary Bell voice")
	observations.native_bell_voice = enemy
	await fresh_sound()
	check(sound.play_event("compiler_voice_hurt"), "Existing enemy/boss voice category is preserved")
	await fresh_sound()
	world.paused = true
	world.gameplay_active = false
	world.hud.panel_open = true
	check(sound.play_event("journal_page"), "Reading UI still plays during pause")
	check(not sound.play_event("hero_focus"), "Healing vocal stays silent while reading")
	world.paused = false
	world.gameplay_active = true
	world.hud.panel_open = false
	await fresh_sound()
	var score := Score.new()
	world.add_child(score)
	score.setup(null)
	score.set_phase(1)
	await wait_seconds(1.30)
	check(score.assets_ready and score.tracks[0].playing, "Continuous original M24 score still plays through the unchanged helper")
	capture.clear_buffer()
	for cue in ["bell_impact", "bell_hit", "bell_swing", "bell_takeoff", "bell_step", "bell_cloth", "bell_voice_hurt", "hit", "parry_light", "hurt"]:
		sound.play_at(cue, world.hero.global_position)
	await wait_seconds(1.25)
	var mix := capture_measure()
	check(mix.stereo_frames > 0 and mix.peak > .01 and mix.peak < .95 and mix.clipped_frames == 0,
		"Unchanged score plus nonvocal hero/Bell contact has native output headroom")
	check(no_hero_voice_logged(), "Combined score/contact mix contains no logged hero voice")
	observations.native_score_contact_mix = mix
	observations.retained_physical_events = physical_events
	observations.final_event_log = sound.event_log
	score.stop_all()
	score.queue_free()
	sound.stop_all()
	await wait_seconds(.10)
	check(sound.active_player_count == 0 and sound.get_child_count() == 0, "Cleanup releases all playback nodes")
	var hashes: Dictionary = {}
	for path in ["res://scripts/audio/m23_soundscape.gd", "res://assets/audio/m23/event_manifest.json", "res://scripts/audio/m24_bell_music.gd", "res://assets/audio/m24/events.json", "res://assets/audio/m24/music/bell_warden_clockwork.ogg"]:
		hashes[path] = FileAccess.get_sha256(path)
	var report := {"version": 1, "engine": Engine.get_version_info().string, "checks": checks, "failures": failures,
		"passed": failures.is_empty(), "hero_voice_enabled": false,
		"scope": "M24 presentation-only hero mute: attack, jump, hurt, dash, healing, spell and death. Nonvocal movement/contact/sword, Bell/enemy voices, UI and continuous music retained. Production hero attack method is called in an isolated native fixture; no live combat claim.",
		"implementation": "Remove local hero_voice entries and their layers; restore original nonvocal jump fallback; reject hero_voice at recursive playback boundary.",
		"human_listening_claim": false, "native_output_method": "AudioEffectCapture on native Godot Master mixer",
		"observations": observations, "retained_source_sha256": hashes,
		"asset_or_music_changes": false, "impact_gain_changed": false,
		"command": "DISPLAY=:95 godot --path /workspace/-2d --rendering-method gl_compatibility --audio-driver Dummy --script res://tools/test_m25_silent_hero.gd"}
	FileAccess.open("res://docs/M25_AUDIO_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("M25 SILENT HERO REPORT ", JSON.stringify({"checks": checks, "failures": failures, "native_score_contact_mix": mix}))
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	world.queue_free()
	world = null
	sound = null
	await frames(4)
	quit(0 if failures.is_empty() else 1)
