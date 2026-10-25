extends Node
## The user-provided singing comes from the Keeper's body, before encounter only.
const RECORDING := "res://assets/audio/m26/archive_keeper_singing.ogg"
const EMITTER_OFFSET := Vector2(0,-115)
const LISTENER_OFFSET := Vector2(0,-55)
const BASE_VOLUME_DB := -7.0
const MAX_DISTANCE := 1500.0
const DISTANCE_ATTENUATION := 1.15
var player: AudioStreamPlayer2D
var listener: AudioListener2D
var encounter_started: bool:
	get: return _encounter_started
var _source: Node2D
var _listener_body: Node2D
var _encounter_started := false
var _dormant_requested := false
var _paused := false
var _room_exited := false
var _pending_start := false

func setup(source: Node2D) -> void:
	_release_nodes()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_source = source
	_encounter_started = false
	_dormant_requested = false
	_paused = false
	_room_exited = false
	if not is_instance_valid(_source): return
	player = AudioStreamPlayer2D.new()
	player.name = "ArchiveKeeperBodySinging"
	player.position = EMITTER_OFFSET
	player.volume_db = BASE_VOLUME_DB
	player.max_distance = MAX_DISTANCE
	player.attenuation = DISTANCE_ATTENUATION
	player.panning_strength = 1.0
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	_source.add_child(player)
	_load_recording()

func _load_recording() -> void:
	if not is_instance_valid(player) or player.stream != null: return
	var stream := AudioStreamOggVorbis.load_from_file(RECORDING)
	if stream == null: return
	stream.loop = true
	stream.loop_offset = 0.0
	player.stream = stream

func set_listener(body: Node2D) -> void:
	if is_instance_valid(listener):
		listener.clear_current()
		listener.queue_free()
	listener = null
	_listener_body = body
	if not is_instance_valid(_listener_body) or _room_exited: return
	listener = AudioListener2D.new()
	listener.name = "HeroSingingListener"
	listener.position = LISTENER_OFFSET
	_listener_body.add_child(listener)
	listener.make_current()

func start_dormant() -> bool:
	if _encounter_started or _room_exited or not is_instance_valid(player): return false
	_load_recording()
	if player.stream == null: return false
	_dormant_requested = true
	if _paused:
		_pending_start = true
	elif not player.playing:
		player.play()
	return true

func stop_for_encounter() -> void:
	# Synchronous stop: no fade, distance gate, timer, or auto-resume callback.
	_encounter_started = true
	_dormant_requested = false
	_stop_recording()

func reset_dormant() -> bool:
	# Only an explicit fresh-encounter reset clears the fight latch.
	if _room_exited: return false
	_encounter_started = false
	_stop_recording()
	return start_dormant()

func set_paused(value: bool) -> void:
	_paused = value
	if is_instance_valid(player) and not _encounter_started and not _room_exited:
		if value and _dormant_requested and (player.get_stream_playback() == null or player.get_playback_position() <= .000001):
			player.stop()
			_pending_start = true
		elif not value and _pending_start and _dormant_requested:
			_pending_start = false
			player.play()
		else:
			player.stream_paused = value

func is_singing() -> bool:
	return _dormant_requested and not _encounter_started and not _room_exited and not _paused and is_instance_valid(player) and player.playing and not player.stream_paused

func get_distance_gain_db() -> float:
	if not is_instance_valid(player) or not is_instance_valid(listener): return -80.0
	var distance := player.global_position.distance_to(listener.global_position)
	var factor := pow(maxf(0.0,1.0-distance/MAX_DISTANCE),DISTANCE_ATTENUATION)
	return maxf(-80.0,linear_to_db(factor))

func stop_for_room_exit() -> void:
	_room_exited = true
	_dormant_requested = false
	_stop_recording()
	_release_nodes()

func _stop_recording() -> void:
	_pending_start = false
	if not is_instance_valid(player): return
	player.stop()
	player.stream_paused = false
	player.stream = null

func _release_nodes() -> void:
	_stop_recording()
	if is_instance_valid(player): player.queue_free()
	if is_instance_valid(listener):
		listener.clear_current()
		listener.queue_free()
	player = null
	listener = null
	_source = null
	_listener_body = null

func _exit_tree() -> void:
	_room_exited = true
	_dormant_requested = false
	_release_nodes()
