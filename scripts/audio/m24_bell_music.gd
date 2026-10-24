extends Node
## Original miniature score, independent of individual attack preparations.
## One continuous section: repeated phase requests never restart the motif.
const PHASE_PATHS := ["res://assets/audio/m24/music/bell_warden_clockwork.ogg"]
const VICTORY_PATH := "res://assets/audio/m24/music/bell_warden_release.ogg"
const BATTLE_DB := -8.0
const VICTORY_DB := -8.0
const FADE_SECONDS := 0.85
const END_FADE_SECONDS := 0.65
var tracks: Array[AudioStreamPlayer] = []
var weights: Array[float] = [0.0]
var ambient: AudioStreamPlayer
var victory: AudioStreamPlayer
var current_phase := 0
var fight_playing := false
var paused_mix := false
var warning_mix := false
var cinematic_mix := false
var muted := false
var assets_ready := false
var phase_changes := 0
var current_duck_db := 0.0

func setup(ambient_player: AudioStreamPlayer) -> void:
	if not tracks.is_empty(): return
	process_mode = Node.PROCESS_MODE_ALWAYS
	ambient = ambient_player
	for path in PHASE_PATHS:
		var player := AudioStreamPlayer.new()
		player.name = "BellWardenMiniature"
		player.volume_db = -80.0
		if ResourceLoader.exists(path):
			player.stream = load(path)
			if player.stream is AudioStreamOggVorbis: player.stream.loop = true
		add_child(player)
		tracks.append(player)
	victory = AudioStreamPlayer.new()
	victory.name = "BellWardenReleaseCadence"
	victory.volume_db = VICTORY_DB
	if ResourceLoader.exists(VICTORY_PATH):
		victory.stream = load(VICTORY_PATH)
		if victory.stream is AudioStreamOggVorbis: victory.stream.loop = false
	add_child(victory)
	assets_ready = tracks.size() == 1 and tracks[0].stream != null and victory.stream != null

func set_phase(value: int) -> void:
	if value <= 0 or tracks.is_empty() or not assets_ready: return
	if fight_playing and current_phase == 1: return
	current_phase = 1
	phase_changes += 1
	fight_playing = true
	if is_instance_valid(victory): victory.stop()
	if not tracks[0].playing: tracks[0].play()

func set_paused(value: bool) -> void: paused_mix = value
func set_cinematic(value: bool) -> void: cinematic_mix = value
func set_muted(value: bool) -> void: muted = value

func set_warning(value: bool) -> void:
	# Keep the shared API, but do not make music predict attack preparation.
	warning_mix = value

func stop_fight(won: bool = false) -> void:
	fight_playing = false
	current_phase = 0
	warning_mix = false
	cinematic_mix = false
	if won and is_instance_valid(victory) and victory.stream != null:
		victory.play()

func _process(delta: float) -> void:
	var duck := -12.0 if paused_mix or cinematic_mix else 0.0
	current_duck_db = move_toward(current_duck_db, duck, delta * 42.0)
	for index in range(tracks.size()):
		var desired := 1.0 if fight_playing else 0.0
		var fade := FADE_SECONDS if fight_playing else END_FADE_SECONDS
		weights[index] = move_toward(weights[index], desired, delta / fade)
		var gain := weights[index]
		tracks[index].volume_db = -80.0 if muted or gain < 0.0001 else BATTLE_DB + linear_to_db(gain) + current_duck_db
		if gain <= 0.0001 and desired <= 0.0 and tracks[index].playing: tracks[index].stop()
	if is_instance_valid(ambient):
		ambient.volume_db = move_toward(ambient.volume_db, -80.0 if fight_playing else -29.0, delta * 52.0)
	if is_instance_valid(victory):
		victory.volume_db = -80.0 if muted else VICTORY_DB + current_duck_db

func stop_all() -> void:
	fight_playing = false
	current_phase = 0
	warning_mix = false
	assets_ready = false
	for index in range(tracks.size()):
		weights[index] = 0.0
		if is_instance_valid(tracks[index]):
			tracks[index].stop()
			tracks[index].stream = null
	if is_instance_valid(victory):
		victory.stop()
		victory.stream = null

func _exit_tree() -> void: stop_all()
