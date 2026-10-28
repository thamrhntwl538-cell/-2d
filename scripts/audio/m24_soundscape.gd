extends "res://scripts/audio/m23_soundscape.gd"
## M25: the hero is wordless. Keep physical effects and enemy voices intact.

func setup(world: Node) -> void:
	super.setup(world)
	var path := "res://assets/audio/m24/events.json"
	if FileAccess.file_exists(path):
		var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary: _events.merge(data.get("events",{}),true)
	var hero_voice_cues: Dictionary = {}
	for cue in _events:
		var entry: Variant = _events[cue]
		if entry is Dictionary and str(entry.get("category",""))=="hero_voice":
			hero_voice_cues[cue] = true
	for cue in hero_voice_cues:
		_events.erase(cue)
	# The manifest replaced this movement cue with a vocal. Restore its
	# original nonvocal effect while voice-only healing/death remain silent.
	if hero_voice_cues.has("jump"):
		_events["jump"] = FALLBACKS["jump"].duplicate(true)
	for cue in _events:
		var entry: Variant = _events[cue]
		if not entry is Dictionary or not entry.has("layers"): continue
		var retained_layers: Array = []
		for layer in entry.get("layers",[]):
			if not hero_voice_cues.has(str(layer)): retained_layers.append(layer)
		entry["layers"] = retained_layers
	_install_soft_steps()

func _install_soft_steps() -> void:
	# M28: a muted sole contact replaces the bright run click. Ground-distance
	# timing, spatial position, pause/airborne filtering and all combat sounds
	# still belong to the existing soundscape; no movement state is modified.
	for surface in ["stone","paper"]:
		var files: Array[String] = []
		for variant in range(1,4):
			files.append("res://assets/audio/m28/soft_step_%s_%d.wav" % [surface,variant])
		var entry := {"files":files,"category":"effects","volume_db":-14.0 if surface=="stone" else -15.0,"pitch_min":.97,"pitch_max":1.03,"cooldown":.095,"max_instances":2,"layers":[],"spatial":true}
		_events["footstep_"+surface] = entry
		if surface=="stone": _events["footstep"] = entry.duplicate(true)

func _play_entry(cue: String, point: Vector2, depth: int, hero_swing: bool = false) -> bool:
	# Also protect the playback boundary if a later manifest/alias adds a
	# hero vocal after setup, including a vocal reached through a layer.
	var entry: Variant = _events.get(cue,{})
	if entry is Dictionary and str(entry.get("category",""))=="hero_voice":
		return _reject(cue)
	return super._play_entry(cue,point,depth,hero_swing)
