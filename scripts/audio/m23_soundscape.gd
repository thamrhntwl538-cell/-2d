extends Node
## Original event audio presentation. Never writes hero/world gameplay state.
const MANIFEST := "res://assets/audio/m23/event_manifest.json"
const MAX_PLAYERS := 16
const MAX_LOG := 256
const CATEGORY_GAP := {"hero_voice":.22,"boss_voice":.28}
const ALIASES := {"journal_open":"book_open","journal_close":"book_close","journal_page":"book_page","bench":"save","coin":"pickup","room_transition":"room_enter","heal_start":"hero_focus","heal_complete":"parry_light","heal_cancel":"book_close"}
const FALLBACKS := {
	"jump":{"files":["res://assets/audio/jump.wav"],"category":"effects","volume_db":-9.0,"cooldown":.16},
	"dash":{"files":["res://assets/audio/dash.wav"],"category":"effects","volume_db":-10.0,"cooldown":.20},
	"swing":{"files":["res://assets/audio/swing.wav","res://assets/audio/dash.wav"],"category":"effects","volume_db":-10.0,"cooldown":.10},
	"hit":{"files":["res://assets/audio/hit.wav","res://assets/audio/parry_light.wav"],"category":"effects","volume_db":-8.0,"cooldown":.08},
	"hurt":{"files":["res://assets/audio/hurt.wav"],"category":"effects","volume_db":-5.0,"cooldown":.25},
	"pickup":{"files":["res://assets/audio/pickup.wav"],"category":"ui","volume_db":-12.0,"cooldown":.08},
	"coin":{"files":["res://assets/audio/pickup.wav"],"category":"ui","volume_db":-14.0,"cooldown":.065},
	"save":{"files":["res://assets/audio/save.wav"],"category":"ui","volume_db":-8.0,"cooldown":.40},
	"bench":{"files":["res://assets/audio/save.wav"],"category":"ui","volume_db":-8.0,"cooldown":.40},
	"parry_light":{"files":["res://assets/audio/parry_light.wav"],"category":"effects","volume_db":-7.0,"cooldown":.18},
	"compiler_release":{"files":["res://assets/audio/m23/compiler_sweep.wav"],"category":"effects","volume_db":-8.0,"cooldown":.12}
}
var world_ref: Node
var event_counts: Dictionary:
	get: return _event_counts.duplicate(true)
var event_log: Array[Dictionary]:
	get: return _event_log.duplicate(true)
var rejected_counts: Dictionary:
	get: return _rejected_counts.duplicate(true)
var active_player_count: int:
	get: return _players.size()
var manifest_loaded: bool = false
var _events: Dictionary = {}
var _event_counts: Dictionary = {}
var _event_log: Array[Dictionary] = []
var _rejected_counts: Dictionary = {}
var _streams: Dictionary = {}
var _players: Array[Dictionary] = []
var _next_event: Dictionary = {}
var _next_category: Dictionary = {}
var _variant: Dictionary = {}
var _category_rules: Dictionary = {}
var _properties: Dictionary = {}
var _clock: float = 0.0
var _suspended: bool = false
var _hero_id: int = 0
var _previous_position := Vector2.ZERO
var _previous_ground: bool = false
var _ground_valid: bool = false
var _air_time: float = 0.0
var _fall_speed: float = 0.0
var _step_distance: float = 0.0
var _previous_healing: bool = false
var _previous_hp: int = 6
var _environment_time: float = 0.0
var _environment_index: int = 0
var _swing_hero_id: int = 0
var _last_strike_serial: int = 0
var _paused_audio: bool = false
var _room_id: int = -999

func setup(world: Node) -> void:
	stop_all()
	world_ref = world
	_properties.clear()
	_events = FALLBACKS.duplicate(true)
	_category_rules = {}
	manifest_loaded = false
	if FileAccess.file_exists(MANIFEST):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if parsed is Dictionary and parsed.get("events",{}) is Dictionary:
			_events.merge(parsed.events,true)
			_category_rules = parsed.get("category_rules",{}).duplicate(true)
			manifest_loaded = true
	for alias in ALIASES:
		if not _events.has(alias) and _events.has(ALIASES[alias]): _events[alias] = _events[ALIASES[alias]].duplicate(true)
	_hero_id = 0
	_room_id = -999
	_suspended = false
	_paused_audio = false
	var hero := _hero()
	_swing_hero_id = hero.get_instance_id() if is_instance_valid(hero) else 0
	_last_strike_serial = int(_read(hero,"strike_serial",0))

func _read(object: Object, key: String, fallback: Variant = null) -> Variant:
	if not is_instance_valid(object): return fallback
	var identity := object.get_instance_id()
	if not _properties.has(identity):
		var names: Dictionary = {}
		for property in object.get_property_list(): names[str(property.name)] = true
		_properties[identity] = names
	return object.get(key) if _properties[identity].has(key) else fallback

func _hero() -> Node2D:
	return _read(world_ref,"hero",null) as Node2D

func _panel_open() -> bool:
	var hud: Object = _read(world_ref,"hud",null)
	return bool(_read(hud,"panel_open",false))

func _blocked() -> bool:
	if not is_instance_valid(world_ref): return true
	if bool(_read(world_ref,"paused",false)) or _panel_open(): return true
	# Hit-stop suspends movement briefly; it must not cut the impact or voice
	# that caused it. Reading/real pause still stop gameplay audio immediately.
	return not bool(_read(world_ref,"gameplay_active",true)) and float(_read(world_ref,"hit_stop_remaining",0.0))<=0

func _priority(cue: String, category: String) -> int:
	if category not in ["hero_voice","boss_voice"]: return 0
	if cue.ends_with("death"): return 4
	if cue.ends_with("phase"): return 3
	if cue.ends_with("intro"): return 2
	return 1

func _reject(cue: String) -> bool:
	_rejected_counts[cue] = int(_rejected_counts.get(cue,0))+1
	return false

func play_event(cue: String) -> bool:
	var hero := _hero()
	return play_at(cue,hero.global_position if is_instance_valid(hero) else Vector2.ZERO)

func play_at(cue: String, point: Vector2) -> bool:
	var hero_swing := false
	if cue=="swing":
		var hero := _hero()
		if is_instance_valid(hero):
			var serial := int(_read(hero,"strike_serial",0))
			if _swing_hero_id!=hero.get_instance_id() or serial<_last_strike_serial:
				_swing_hero_id = hero.get_instance_id()
				_last_strike_serial = 0
			hero_swing = serial>_last_strike_serial
			_last_strike_serial = serial
	return _play_entry(cue,point,0,hero_swing)

func _play_entry(cue: String, point: Vector2, depth: int, hero_swing: bool = false) -> bool:
	if depth>3 or not _events.has(cue): return _reject(cue)
	var entry: Dictionary = _events[cue] if _events[cue] is Dictionary else {}
	var category := str(entry.get("category","effects"))
	var death_tail := is_instance_valid(world_ref) and cue in ["hero_death","compiler_voice_death"] and not bool(_read(world_ref,"paused",false)) and not _panel_open()
	if category!="ui" and _blocked() and not death_tail: return _reject(cue)
	if _clock<float(_next_event.get(cue,-1)): return _reject(cue)
	var priority := _priority(cue,category)
	if bool(entry.get("preempt_category",false)): priority = maxi(2,priority)
	var voice := category in ["hero_voice","boss_voice"]
	if voice:
		if priority<2 and _clock<float(_next_category.get(category,-1)): return _reject(cue)
		for active in _players:
			if str(active.category)==category and int(active.priority)>priority: return _reject(cue)
	var files: Array = entry.get("files",[])
	var available: Array[String] = []
	for file in files:
		var path := str(file)
		if FileAccess.file_exists(path) or ResourceLoader.exists(path): available.append(path)
	if available.is_empty(): return _reject(cue)
	var variant := int(_variant.get(cue,0))%available.size()
	var path := available[variant]
	var stream := _stream(path)
	if stream==null: return _reject(cue)
	if voice:
		for active in _players.duplicate():
			if str(active.category)==category: _stop(active)
	else:
		var same: Array[Dictionary] = []
		for active in _players:
			if str(active.cue)==cue: same.append(active)
		if same.size()>=maxi(1,int(entry.get("max_instances",2))): _stop(same[0])
	if _players.size()>=MAX_PLAYERS:
		var removed := false
		for active in _players.duplicate():
			if str(active.category) not in ["hero_voice","boss_voice"]:
				_stop(active)
				removed = true
				break
		if not removed: return _reject(cue)
	var spatial := category=="environment" or cue.begins_with("footstep") or cue=="land" or bool(entry.get("spatial",false))
	var player: Node = AudioStreamPlayer2D.new() if spatial else AudioStreamPlayer.new()
	player.name = "M23Audio_"+cue.validate_node_name()
	var gain := clampf(float(entry.get("volume_db",-8)),-42,0)
	if category=="environment" and bool(_read(world_ref,"boss_active",false)): gain -= 9.0
	player.stream = stream
	player.volume_db = gain
	var low := clampf(float(entry.get("pitch_min",1)),.8,1.2)
	var high := clampf(float(entry.get("pitch_max",1)),low,1.2)
	player.pitch_scale = lerpf(low,high,float((variant*37+int(_event_counts.get(cue,0))*17)%101)/100.0)
	if spatial:
		player.position = point
		player.max_distance = 1500
		player.attenuation = .70
		player.panning_strength = .72
	add_child(player)
	var active := {"player":player,"cue":cue,"category":category,"priority":priority}
	_players.append(active)
	player.finished.connect(func(): _stop(active))
	player.play()
	_variant[cue] = variant+1
	_next_event[cue] = _clock+maxf(.015,float(entry.get("cooldown",.10)))
	if voice:
		var rules: Dictionary = _category_rules.get(category,{})
		_next_category[category] = _clock+float(rules.get("cooldown",CATEGORY_GAP.get(category,.25)))
	_event_counts[cue] = int(_event_counts.get(cue,0))+1
	_event_log.append({"cue":cue,"category":category,"path":path,"volume_db":gain,"pitch_scale":player.pitch_scale,"priority":priority,"clock":_clock,"spatial":spatial,"position":[point.x,point.y],"duration":stream.get_length()})
	if _event_log.size()>MAX_LOG: _event_log.pop_front()
	for layer in entry.get("layers",[]):
		# Inherited enemies also use the legacy generic swing event. Only an
		# advance of the actual hero's strike serial may add its attack voice.
		if cue=="swing" and str(layer)=="hero_attack" and not hero_swing: continue
		_play_entry(str(layer),point,depth+1)
	return true

func _stream(path: String) -> AudioStream:
	if _streams.has(path): return _streams[path]
	var result: AudioStream
	if ResourceLoader.exists(path): result = load(path) as AudioStream
	elif path.ends_with(".wav") and FileAccess.file_exists(path): result = AudioStreamWAV.load_from_file(path)
	if result!=null: _streams[path] = result
	return result

func _stop(active: Dictionary) -> void:
	_players.erase(active)
	var player: Node = active.get("player")
	if is_instance_valid(player):
		player.stop()
		player.stream = null
		player.queue_free()

func stop_all() -> void:
	for active in _players.duplicate(): _stop(active)
	_ground_valid = false
	_step_distance = 0
	_air_time = 0
	_environment_time = 0
	_previous_healing = false
	_paused_audio = false

func _surface(hero: Node2D) -> String:
	if hero.has_method("get_slide_collision_count"):
		for index in range(int(hero.call("get_slide_collision_count"))):
			var collision: KinematicCollision2D = hero.call("get_slide_collision",index)
			if collision.get_normal().y>-.5: continue
			var collider := collision.get_collider()
			if collider is Node and collider.has_meta("footstep_surface"): return str(collider.get_meta("footstep_surface"))
			if collider is Node and collider.get_script()!=null and str(collider.get_script().resource_path).ends_with("paper_platform.gd"): return "paper"
	var data: Dictionary = _read(world_ref,"data",{})
	return str(data.get("footstep_surface","stone"))

func _process(delta: float) -> void:
	_clock += delta
	var blocked := _blocked()
	var real_pause := bool(_read(world_ref,"paused",false)) or _panel_open()
	if real_pause!=_paused_audio:
		for active in _players.duplicate():
			if str(active.category)=="environment":
				if real_pause: _stop(active)
			elif str(active.category)!="ui" and is_instance_valid(active.player): active.player.stream_paused = real_pause
		_paused_audio = real_pause
	if blocked and not real_pause:
		for active in _players.duplicate():
			if str(active.category)!="ui" and int(active.priority)<4: _stop(active)
	if blocked:
		_ground_valid = false
		_step_distance = 0
	_suspended = blocked
	if blocked or not bool(_read(world_ref,"gameplay_active",true)): return
	var hero := _hero()
	if not is_instance_valid(hero) or not hero.has_method("is_on_floor"): return
	var point := hero.global_position
	var grounded := bool(hero.call("is_on_floor"))
	var velocity: Vector2 = _read(hero,"velocity",Vector2.ZERO)
	var health := int(_read(hero,"hp",6))
	var healing := bool(_read(hero,"healing",false))
	var room_id := int(_read(world_ref,"current_room",-1))
	if room_id!=_room_id:
		_room_id = room_id
		_ground_valid = false
		_step_distance = 0
		_environment_time = 0
	if _hero_id!=hero.get_instance_id():
		_hero_id = hero.get_instance_id()
		_ground_valid = false
		_previous_healing = healing
		_previous_hp = health
	if not _ground_valid or point.distance_to(_previous_position)>120:
		_previous_position = point
		_previous_ground = grounded
		_ground_valid = true
		_air_time = 0
		_fall_speed = 0
		_step_distance = 0
	if health<=0:
		_previous_position = point
		return
	if not grounded:
		_air_time += delta
		_fall_speed = maxf(_fall_speed,velocity.y)
	elif not _previous_ground:
		if _air_time>.08 or _fall_speed>110: play_event("land")
		_air_time = 0
		_fall_speed = 0
		_step_distance = 0
	var walking := grounded and absf(velocity.x)>35 and float(_read(hero,"dash_time",0.0))<=0 and not healing
	if walking:
		_step_distance += absf(point.x-_previous_position.x)
		if _step_distance>=64:
			play_event("footstep_"+_surface(hero))
			_step_distance = fmod(_step_distance,64)
		_environment_time += delta
		if _environment_time>8.0 and not bool(_read(world_ref,"boss_active",false)):
			var cues := ["paper_rustle","chain_tink","lamp_flicker"]
			play_at(cues[_environment_index%cues.size()],point+Vector2(-220 if _environment_index%2==0 else 220,-80))
			_environment_index += 1
			_environment_time = 0
	else:
		_step_distance = 0
		_environment_time = minf(_environment_time,4)
	if healing and not _previous_healing: play_event("heal_start")
	elif not healing and _previous_healing: play_event("heal_complete" if health>_previous_hp else "heal_cancel")
	_previous_position = point
	_previous_ground = grounded
	_previous_healing = healing
	_previous_hp = health

func _exit_tree() -> void:
	stop_all()
	_streams.clear()
	world_ref = null
