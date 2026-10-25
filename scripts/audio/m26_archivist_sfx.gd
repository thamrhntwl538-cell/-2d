extends Node
## Exact supplied event-to-sound map, on an animation clock rather than timers.
const ROOT := "res://assets/audio/m26_imported/"
const MAP_PATH := ROOT + "sfx_map.json"
const MIX_DB := -16.0
var playback_speed := 1.0
var animation := ""
var phase := 1
var clock := 0.0
var paused := false
var history: Array[Dictionary] = []
var schedule: Array[Dictionary] = []
var _source: Node2D
var _map: Dictionary = {}
var _cache: Dictionary = {}
var _voices: Array[AudioStreamPlayer2D] = []
var _loops: Dictionary = {}
var _pending_paused: Dictionary = {}
var _cursor := 0
var _duration := 0.0
var _loop_animation := false
var _generation := 0

func setup(source: Node2D) -> void:
	stop_all()
	_source = source
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	_map = parsed if parsed is Dictionary else {}

func play_animation(name: String, source_phase: int, metadata: Dictionary, speed: float = 1.0) -> void:
	_stop_loops()
	_generation += 1
	animation = name
	phase = source_phase
	clock = 0.0
	playback_speed = speed
	_duration = float(metadata.get("duration", 1.0))
	_loop_animation = bool(metadata.get("loop", false))
	_cursor = 0
	schedule.clear()
	var mapping: Dictionary = _map.get("animations", {}).get(name, {})
	var events: Array = [{"name":"anim_start", "time":0.0}]
	events.append_array(metadata.get("events", []))
	for event in events:
		var event_name := String(event.name)
		var event_time := float(event.get("time", float(event.get("u", 0.0)) * _duration))
		# Stops are on the same source clock, independent of audio clip length.
		schedule.append({"time":event_time, "stop_event":event_name})
		for entry in mapping.get(event_name, []):
			var item: Dictionary = entry.duplicate(true)
			item["time"] = maxf(0.0, event_time + float(entry.get("offset",0.0)))
			item["event"] = event_name
			schedule.append(item)
	schedule.sort_custom(func(a:Dictionary,b:Dictionary): return float(a.time) < float(b.time))
	_dispatch_until(0.0)

func advance(delta: float) -> void:
	if paused or animation.is_empty() or delta <= 0.0: return
	var target := clock + delta * playback_speed
	if _loop_animation and _duration > 0.0:
		while target >= _duration:
			_dispatch_until(_duration)
			target -= _duration
			_cursor = 0
			clock = 0.0
			# Loop breath is continuous. Footsteps recur at the next cycle start.
			_dispatch_until(0.0)
	_dispatch_until(target)
	clock = target
	_prune_voices()

func seek(seconds: float) -> void:
	# Scrubbing is silent; it never replays all crossed impacts in one burst.
	stop_all()
	clock = maxf(seconds,0.0)
	_cursor = 0
	while _cursor < schedule.size() and float(schedule[_cursor].time) <= clock:
		_cursor += 1

func _dispatch_until(target: float) -> void:
	while _cursor < schedule.size() and float(schedule[_cursor].time) <= target + 0.000001:
		var item: Dictionary = schedule[_cursor]
		_cursor += 1
		if item.has("stop_event"):
			for key in _loops.keys():
				if String(_loops[key].stop_on) == String(item.stop_event):
					_release_voice(_loops[key].voice)
					_loops.erase(key)
		else:
			_play_item(item)

func _load_sound(name: String) -> AudioStreamWAV:
	if _cache.has(name): return _cache[name]
	var bytes := FileAccess.get_file_as_bytes(ROOT + "wav/" + name + ".wav")
	# The supplied WAVs are PCM24 in WAVE_FORMAT_EXTENSIBLE containers.
	# Godot rejects that tag, although it decodes the same PCM payload. Adapt
	# only the in-memory container tag after checking the exact PCM subtype.
	# Original files and every audio payload byte remain untouched.
	var cursor := 12
	while cursor + 8 <= bytes.size():
		var length := int(bytes.decode_u32(cursor+4))
		if length < 0 or cursor+8+length > bytes.size(): return null
		if bytes.slice(cursor,cursor+4).get_string_from_ascii() == "fmt ":
			var offset := cursor+8
			if length >= 40 and bytes.decode_u16(offset) == 65534:
				var pcm_guid := PackedByteArray([1,0,0,0,0,0,16,0,128,0,0,170,0,56,155,113])
				if bytes.slice(offset+24,offset+40) != pcm_guid: return null
				bytes.encode_u16(offset,1)
			break
		cursor += 8+length+(length%2)
	var sound := AudioStreamWAV.load_from_buffer(bytes)
	if sound != null: _cache[name] = sound
	return sound

func _play_item(item: Dictionary) -> void:
	if not is_instance_valid(_source): return
	var name := String(item.get("sound", ""))
	if phase == 2:
		name = String(_map.get("notes", {}).get("p2_swap", {}).get(name, name))
	var looped := item.has("stop_on") or name == "idle_breath"
	if looped and _loops.has(name): return
	var sound := _load_sound(name)
	if sound == null: return
	if looped:
		sound = sound.duplicate()
		sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sound.loop_begin = 0
		sound.loop_end = int(sound.get_length() * sound.mix_rate)
	var voice := AudioStreamPlayer2D.new()
	voice.name = "Archivist_" + name
	voice.position = Vector2(0,-80)
	voice.max_distance = 2000
	voice.attenuation = 0.7
	voice.panning_strength = 0.8
	voice.volume_db = MIX_DB + linear_to_db(maxf(0.001,float(item.get("volume",1.0))))
	voice.stream = sound
	voice.stream_paused = paused
	_source.add_child(voice)
	_voices.append(voice)
	if looped: _loops[name] = {"voice":voice, "stop_on":String(item.get("stop_on","animation_end"))}
	if paused:
		_pending_paused[voice.get_instance_id()] = true
	else:
		voice.play()
	history.append({"sound":name, "source_time":float(item.get("time",clock)), "animation":animation, "phase":phase})

func play_extra(name: String) -> void:
	_play_item({"sound":name,"time":clock,"volume":1.0})

func set_paused(value: bool) -> void:
	paused = value
	for voice in _voices:
		if not is_instance_valid(voice) or voice.is_queued_for_deletion(): continue
		var id := voice.get_instance_id()
		if value:
			if _pending_paused.has(id): continue
			# A 2D play request is deferred to physics. Pausing before that
			# first mix cannot pause a playback object which doesn't exist yet.
			if voice.get_stream_playback() == null or voice.get_playback_position() <= .000001:
				voice.stop()
				_pending_paused[id] = true
			else:
				voice.stream_paused = true
		elif _pending_paused.has(id):
			_pending_paused.erase(id)
			voice.play()
		else:
			voice.stream_paused = false

func _release_voice(voice: Variant) -> void:
	if is_instance_valid(voice):
		_pending_paused.erase(voice.get_instance_id())
		voice.stop()
		voice.stream = null
		voice.queue_free()

func _prune_voices() -> void:
	for index in range(_voices.size()-1,-1,-1):
		var voice := _voices[index]
		if not is_instance_valid(voice):
			_voices.remove_at(index)
		elif not voice.playing and not voice.stream_paused and not _pending_paused.has(voice.get_instance_id()):
			_release_voice(voice)
			_voices.remove_at(index)

func _stop_loops() -> void:
	for item in _loops.values(): _release_voice(item.voice)
	_loops.clear()

func stop_all() -> void:
	for voice in _voices: _release_voice(voice)
	_voices.clear()
	_loops.clear()
	_pending_paused.clear()

func _exit_tree() -> void:
	stop_all()
