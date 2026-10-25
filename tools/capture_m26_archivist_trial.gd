extends SceneTree
## Actual-input approach recording of the supplied character in the new trial.
## No invulnerability, HP overrides, forced attacks or pose substitutions.
const SCENE := "res://scenes/minibosses/archivist_trial_m26.tscn"
var output := "/workspace/work/m26_imported_trial_gallery"
var world: Node2D
var frames := 0
var trace: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var failures: Array[String] = []
var source_hashes: Dictionary = {}
var recorded: Dictionary = {}
var encounter_frame := -1

func _initialize() -> void: call_deferred("run")

func json_value(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i: return [value.x,value.y]
	if value is Rect2: return [value.position.x,value.position.y,value.size.x,value.size.y]
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[str(key)] = json_value(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value: result.append(json_value(item))
		return result
	return value

func photo(tag: String, caption: String) -> void:
	if recorded.has(tag): return
	recorded[tag] = true
	await RenderingServer.frame_post_draw
	var target := output+"/"+tag+".jpg"
	var image: Image = root.get_texture().get_image()
	if image.save_jpg(target,.96) != OK: failures.append("Cannot write "+target)
	captures.append({"path":target,"frame":frames,"caption":caption,"actual_input_only":true,"snapshot":json_value(world.get_trial_snapshot())})
	print("ARCHIVIST ACTUAL-INPUT CAPTURE ",target)

func step() -> void:
	await physics_frame
	await process_frame
	frames += 1
	if frames%6 == 0:
		var snap: Dictionary = world.get_trial_snapshot()
		snap["capture_frame"] = frames
		snap["singing_gain_db"] = world.singing.get_distance_gain_db()
		trace.append(json_value(snap))

func collect_hashes() -> void:
	for path in ["tools/capture_m26_archivist_trial.gd","scenes/minibosses/archivist_trial_m26.tscn","scripts/minibosses/m26_archivist_trial.gd","scripts/minibosses/m26_archivist_sprite.gd","assets/minibosses/m26_imported/manifest.json","scripts/audio/m26_archive_singing.gd","scripts/audio/m26_archivist_sfx.gd","assets/audio/m26/archive_keeper_singing.ogg","assets/audio/m26_imported/sfx_map.json","scripts/combat/m23_player.gd","scripts/warden_model_m23.gd"]:
		if FileAccess.file_exists("res://"+path): source_hashes[path] = FileAccess.get_sha256("res://"+path)
	for directory in ["assets/minibosses/m26_imported/","assets/audio/m26_imported/wav/"]:
		for filename in DirAccess.get_files_at("res://"+directory):
			if filename.ends_with(".zip") or filename.ends_with(".wav"):
				var path: String = str(directory)+filename
				source_hashes[path] = FileAccess.get_sha256("res://"+path)

func press_key(keycode: int) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	Input.parse_input_event(down)
	await step()
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	Input.parse_input_event(up)
	await step()

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native visual/audio renderer required")
		quit(1)
		return
	root.size = Vector2i(1280,720)
	if "--final-capture" in OS.get_cmdline_user_args(): output = "res://previews/m26_imported"
	DirAccess.make_dir_recursive_absolute(output)
	collect_hashes()
	world = load(SCENE).instantiate()
	root.add_child(world)
	await step()
	if not world.has_method("get_trial_snapshot") or not is_instance_valid(world.get("singing")):
		push_error("Playable trial is not ready; capture aborted")
		quit(1)
		return
	if not world.singing.is_singing(): failures.append("Fresh approach did not start body singing")
	var initial_gain: float = world.singing.get_distance_gain_db()
	for index in range(60): await step()
	await photo("20_singing_far","الصوت من جسم أمين الأرشيف · البطل بعيد")
	Input.action_press("move_right")
	for index in range(420):
		await step()
		if world.hero.position.x > 900 and not world.encounter_started:
			await photo("21_singing_near","الاقتراب الفعلي يزيد مستوى غناء العدو")
		if world.encounter_started:
			encounter_frame = frames
			break
	Input.action_release("move_right")
	if encounter_frame < 0: failures.append("Actual walk did not enter encounter")
	else:
		if world.singing.is_singing() or world.singing.player.stream != null: failures.append("Song survived encounter boundary")
		await photo("22_encounter_cutoff","بدء المواجهة يقطع الغناء فورًا")
		await press_key(KEY_P)
		if not world.paused: failures.append("Actual P input failed to pause encounter")
		for index in range(24): await step()
		if world.singing.is_singing(): failures.append("Paused encounter restarted body singing")
		await press_key(KEY_P)
		if world.paused: failures.append("Actual P input failed to resume encounter")
		Input.action_press("move_left")
		for index in range(28): await step()
		Input.action_release("move_left")
		Input.action_press("move_right")
		for index in range(28): await step()
		Input.action_release("move_right")
		if world.singing.is_singing() or world.singing.player.stream != null: failures.append("Moving away and back restarted body singing")
	var heard_nearer := false
	for item in trace:
		if float(item.singing_gain_db) > initial_gain+8.0: heard_nearer = true
	if not heard_nearer: failures.append("Approach did not yield an8dB distance rise")
	for index in range(600):
		await step()
		var actor_snapshot: Dictionary = world.keeper.get_snapshot()
		var u := float(actor_snapshot.get("time",0))/maxf(.001,float(actor_snapshot.get("duration",1)))
		if world.state == "attack" and u>=.47 and u<=.58:
			await photo("23_first_attack","أول هجمة فعلية في التجربة؛ صحة البطل طبيعية")
		if world.hero.hp < 6: await photo("24_first_damage","ضرر فعلي من مؤثر الهجمة؛ دون تغيير صحة البطل")
		if world.hero.hp <= 0: break
	var changed: Array[String] = []
	for path in source_hashes:
		if FileAccess.get_sha256("res://"+path) != source_hashes[path]: changed.append(path)
	if "--final-capture" in OS.get_cmdline_user_args() and not changed.is_empty(): failures.append("Sources changed during final recording")
	var report := {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Actual-input approach and live isolated encounter; no health/AI/pose overrides.","actual_input_only":true,"fps":60,"frames":frames,"encounter_frame":encounter_frame,"initial_distance_gain_db":initial_gain,"source_sha256":source_hashes,"source_files_changed":changed,"captures":captures,"trace":trace,"failures":failures,"audio_scope":"Native positional user recording, then actual mapped fight audio; no added audio bed."}
	FileAccess.open(output+"/approach_capture_metadata.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	world.singing.stop_for_room_exit()
	world.keeper_sound.stop_all()
	world.soundscape.stop_all()
	world.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
