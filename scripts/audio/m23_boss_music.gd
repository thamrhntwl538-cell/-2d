extends Node
## Original two-part score. Pause ducks the score; attack clocks freeze elsewhere.
## Streams crossfade without restarting the active section on every status update.
const PHASE_PATHS := ["res://assets/audio/m23/compiler_phase_1.ogg","res://assets/audio/m23/compiler_phase_2.ogg"]
const BATTLE_DB := -6.0
const FADE_SECONDS := 1.2
var tracks: Array[AudioStreamPlayer] = []
var weights: Array[float] = [0.0,0.0]
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
	ambient = ambient_player
	for path in PHASE_PATHS:
		var player := AudioStreamPlayer.new()
		player.name = "CompilerScorePhase%d" % (tracks.size()+1)
		player.volume_db = -80
		if ResourceLoader.exists(path):
			player.stream = load(path)
			if player.stream is AudioStreamOggVorbis: player.stream.loop = true
		add_child(player)
		tracks.append(player)
	victory = AudioStreamPlayer.new()
	victory.name = "CompilerVictoryCadence"
	victory.volume_db = -7
	var path := "res://assets/audio/m23/compiler_victory.ogg"
	if ResourceLoader.exists(path): victory.stream = load(path)
	add_child(victory)
	assets_ready = tracks.size()==2 and tracks[0].stream!=null and tracks[1].stream!=null

func set_phase(value: int) -> void:
	var requested := clampi(value,1,2)
	if fight_playing and requested==current_phase: return
	current_phase = requested
	phase_changes += 1
	fight_playing = true
	if is_instance_valid(victory): victory.stop()
	var player := tracks[current_phase-1] if tracks.size()==2 else null
	if player!=null and player.stream!=null and not player.playing: player.play()

func set_paused(value: bool) -> void: paused_mix = value
func set_warning(value: bool) -> void: warning_mix = value
func set_cinematic(value: bool) -> void: cinematic_mix = value
func set_muted(value: bool) -> void: muted = value

func stop_fight(won: bool = false) -> void:
	fight_playing = false
	current_phase = 0
	warning_mix = false
	cinematic_mix = false
	if won and is_instance_valid(victory) and victory.stream!=null:
		victory.play()

func _process(delta: float) -> void:
	var duck := -12.0 if paused_mix or cinematic_mix else -3.5 if warning_mix else 0.0
	current_duck_db = move_toward(current_duck_db,duck,delta*42)
	for index in range(tracks.size()):
		var desired := 1.0 if fight_playing and current_phase==index+1 else 0.0
		weights[index] = move_toward(weights[index],desired,delta/FADE_SECONDS)
		var gain := weights[index]
		tracks[index].volume_db = -80 if muted or gain<.0001 else BATTLE_DB+linear_to_db(gain)+current_duck_db
		if gain<=.0001 and desired<=0 and tracks[index].playing: tracks[index].stop()
	if is_instance_valid(ambient):
		ambient.volume_db = move_toward(ambient.volume_db,-80.0 if fight_playing else -29.0,delta*52)
	if is_instance_valid(victory): victory.volume_db = -80 if muted else -7

func stop_all() -> void:
	fight_playing = false
	for player in tracks:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	if is_instance_valid(victory):
		victory.stop()
		victory.stream = null

func _exit_tree() -> void: stop_all()
