extends SceneTree
## Native M27 trial captures driven only by normal gameplay input.
const SCENE := "res://scenes/minibosses/archivist_trial_m26.tscn"
var output := "/workspace/work/m27_gallery"
var world: Node2D
var ticks := 0
var photos: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var failures: Array[String] = []
var source_hashes: Dictionary = {}
var recorded: Dictionary = {}
var final_capture := false
var encounter_tick := -1
var first_strike_tick := -1
var first_damage_tick := -1
var second_approach_tick := -1
var jump_held := false
var input_log: Array[Dictionary] = []
var fixture_mode := false
var fixture_reports: Array[Dictionary] = []

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

func action(name: String, held: bool) -> void:
	if held: Input.action_press(name)
	else: Input.action_release(name)
	input_log.append({"tick":ticks,"action":name,"held":held})

func release_inputs() -> void:
	for name in ["move_left","move_right","jump","attack","dash","spell","focus","look_up","look_down"]:
		if InputMap.has_action(name): Input.action_release(name)
	jump_held = false

func step(count: int = 1) -> void:
	for index in range(count):
		await physics_frame
		await process_frame
		ticks += 1
		if ticks%6 == 0 and is_instance_valid(world) and world.has_method("get_trial_snapshot"):
			var snapshot: Dictionary = world.get_trial_snapshot()
			snapshot["capture_tick"] = ticks
			snapshot["singing_distance_gain_db"] = world.singing.get_distance_gain_db()
			trace.append(json_value(snapshot))

func photo(tag: String, caption: String) -> void:
	if recorded.has(tag): return
	recorded[tag] = true
	await RenderingServer.frame_post_draw
	var target := output+"/"+tag+".jpg"
	var image: Image = root.get_texture().get_image()
	if image.save_jpg(target,.96) != OK: failures.append("Could not write "+target)
	var snapshot: Dictionary = world.get_trial_snapshot()
	photos.append({"path":target,"caption":caption,"tick":ticks,"actual_input_only":not fixture_mode,"configured_fixture":fixture_mode,"snapshot":json_value(snapshot),"arena":json_value(world.arena_art.get_arena_snapshot())})
	print("M27 NATIVE PHOTO ",target)

func hash_sources() -> void:
	for path in ["tools/capture_m27_archivist.gd","scenes/minibosses/archivist_trial_m26.tscn","scripts/minibosses/m26_archivist_trial.gd","scripts/minibosses/m26_archivist_sprite.gd","scripts/stage/m27_archivist_arena.gd","assets/environments/m27_archivist/sealed_catalog_vault.png","assets/environments/m27_archivist/provenance.json","assets/minibosses/m26_imported/manifest.json","scripts/audio/m26_archive_singing.gd","scripts/audio/m26_archivist_sfx.gd","scripts/audio/m24_soundscape.gd","scripts/ui/m22_combat_display.gd","assets/audio/m26/archive_keeper_singing.ogg","assets/audio/m26_imported/sfx_map.json","scripts/combat/m23_player.gd","scripts/warden_model_m23.gd","assets/warden_m20/warden_parts.png","assets/fonts/DejaVuSans.ttf"]:
		if FileAccess.file_exists("res://"+path): source_hashes[path] = FileAccess.get_sha256("res://"+path)
	for directory in ["assets/minibosses/m26_imported/","assets/audio/m26_imported/wav/"]:
		for filename in DirAccess.get_files_at("res://"+directory):
			if filename.ends_with(".zip") or filename.ends_with(".wav"):
				var path: String = str(directory)+filename
				source_hashes[path] = FileAccess.get_sha256("res://"+path)

func approach() -> void:
	await step(60)
	await photo("00_singing_approach","الاقتراب الفعلي من الغناء عند مدخل الخزانة")
	action("move_right",true)
	for index in range(420):
		await step()
		if world.encounter_started:
			encounter_tick = ticks
			break
	action("move_right",false)
	if encounter_tick<0:
		failures.append("Normal right movement did not enter encounter")
		return
	if world.singing.is_singing() or world.singing.player.stream != null:
		failures.append("Singing did not stop at encounter boundary")
	await step(34)
	await photo("01_book_vault_entry","قاعة أمين الأرشيف الخاصة داخل المواجهة الفعلية")

func melee_review() -> void:
	# The hero initially stands in place to expose the first real hammer hit.
	# Health and enemy state remain untouched by this capture script.
	for index in range(360):
		await step()
		if world.state=="walk": await photo("02_walk_into_range","يمشي أمين الأرشيف حتى يدخل مدى ضربته")
		if world.state=="attack" and world.current_animation=="slam":
			if first_strike_tick<0: first_strike_tick=ticks
			var source: Dictionary = world.keeper.get_snapshot()
			var progress := float(source.time)/float(source.duration)
			if progress>=.30 and progress<=.40: await photo("03_staff_ready_in_range","رفع المطرقة داخل مدى الضربة الفعلي")
		if world.hero.hp<6:
			first_damage_tick=ticks
			await photo("04_staff_contact","أول ضربة تصل إلى البطل بصحته الطبيعية")
			break
	if first_strike_tick<0: failures.append("No first hammer attack started")
	if first_damage_tick<0: failures.append("First hammer blow never contacted a stationary hero")
	var hp_before_dodge: int = world.hero.hp
	if not world.attack_start_record.is_empty():
		var record: Dictionary = world.attack_start_record
		if float(record.gap)>float(record.band.max)+.1: failures.append("First melee attack started outside its own reach band")
	# Retreat with the ordinary movement input, then let the same AI approach
	# again. A normal jump and short dash demonstrate movement during its next
	# committed strike; no attack is selected or forced for the camera.
	action("move_left",true)
	await step(34)
	action("move_left",false)
	var next_attack_seen := false
	var next_attack_tick := -1
	var dash_released := true
	for index in range(520):
		await step()
		if jump_held and world.hero.velocity.y>=0:
			action("jump",false)
			jump_held=false
		if second_approach_tick<0 and world.state=="walk":
			second_approach_tick=ticks
			await photo("05_reapproach_after_retreat","يقترب مجددًا بعد ابتعاد البطل؛ لا يضرب الفراغ")
		if second_approach_tick>0 and world.state=="attack" and not next_attack_seen:
			next_attack_seen=true
			next_attack_tick=ticks
			action("jump",true)
			jump_held=true
			action("move_right",true)
		if next_attack_seen and ticks-next_attack_tick==13:
			action("dash",true)
			dash_released=false
		if not dash_released and ticks-next_attack_tick>=15:
			action("dash",false)
			dash_released=true
		if next_attack_seen and ticks-next_attack_tick==22:
			await photo("06_normal_jump_and_dash","قفز وداش بأزرار اللعب العادية أثناء الضربة التالية")
		if next_attack_seen and ticks-next_attack_tick==38:
			action("move_right",false)
		if next_attack_seen and ticks-next_attack_tick>125: break
		if world.hero.hp<=0: break
	release_inputs()
	if second_approach_tick<0: failures.append("AI did not approach again after actual retreat")
	if world.hero.hp<hp_before_dodge: failures.append("Normal jump and dash did not clear the next committed attack")
	if world.singing.is_singing() or world.singing.player.stream != null:
		failures.append("Moving around the live fight restarted singing")

func write_report(sample_only: bool) -> void:
	var changed: Array[String] = []
	for path in source_hashes:
		if FileAccess.get_sha256("res://"+path)!=source_hashes[path]: changed.append(path)
	if final_capture and not changed.is_empty(): failures.append("Sources changed during final capture")
	var report := {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Native M27 isolated trial driven by ordinary gameplay input. No health, AI, attack-selection or pose overrides.","actual_input_only":true,"sample_only":sample_only,"fps":60,"ticks":ticks,"encounter_tick":encounter_tick,"first_strike_tick":first_strike_tick,"first_damage_tick":first_damage_tick,"second_approach_tick":second_approach_tick,"source_sha256":source_hashes,"source_files_changed":changed,"photos":photos,"inputs":input_log,"trace":trace,"failures":failures,"audio_scope":"Original body-positioned user singing, stopped at encounter start, then actual source-mapped effects. No replacement music/audio."}
	FileAccess.open(output+("/arena_sample_metadata.json" if sample_only else "/actual_input_capture_metadata.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))

func paper_case(volley: int, tag: String) -> void:
	# Explicit diagnostic fixture, separate from the actual-input movie. Fresh
	# normal health, a fixed source clock and a position on the later sheet.
	world.set_physics_process(false)
	world.hero.set_physics_process(false)
	world.encounter_started=true
	world.boss_active=true
	world.gate_open=false
	world.state="attack"
	world.singing.stop_for_encounter()
	world.keeper.position=Vector2(1440,617)
	world.attack_direction=-1
	world.keeper.set_facing(-1)
	world.camera.position=Vector2(1345,360)
	world._start_clip("pagestorm")
	var source_seconds := float([.40,.54,.68][volley])*2.3+.35
	world.keeper.seek(source_seconds)
	world.keeper_sound.seek(source_seconds)
	var selected: Dictionary = {}
	for entry in world._runtime_hitboxes():
		if str(entry.get("kind",""))=="proj" and int(entry.get("volley",-1))==volley and int(entry.get("sheet",-1))==6:
			selected=entry
			break
	if selected.is_empty():
		failures.append("No later-volley visible sheet in diagnostic fixture")
		return
	var rectangle: Rect2 = selected.rect
	world.hero.position=rectangle.get_center()+Vector2(0,26)
	var earlier_overlap := false
	for entry in world._runtime_hitboxes():
		if str(entry.get("kind",""))=="proj" and int(entry.get("volley",-1))<volley:
			if world._hero_overlaps(entry.rect): earlier_overlap=true
	var before_hp: int = world.hero.hp
	world._resolve_source_hits()
	world._refresh_hud()
	var actual_volley := -1
	if not world._hitbox_history.is_empty(): actual_volley=int(world._hitbox_history[-1].get("volley",-1))
	if before_hp!=6 or world.hero.hp!=5 or actual_volley!=volley or earlier_overlap:
		failures.append("Diagnostic fixture did not isolate requested later paper volley")
	var panel := ColorRect.new()
	panel.color=Color(.025,.035,.06,.92)
	panel.position=Vector2(280,145)
	panel.size=Vector2(720,72)
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	world.hud.add_child(panel)
	var label := Label.new()
	label.position=Vector2(290,151)
	label.size=Vector2(700,62)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",load("res://assets/fonts/DejaVuSans.ttf"))
	label.add_theme_font_size_override("font_size",18)
	label.text="اختبار مضبوط · الدفعة %s\nقبل الاصطدام: ٦ · بعد الاصطدام: ٥ · دون ضرر سابق" % ("الثانية" if volley==1 else "الثالثة")
	world.hud.add_child(label)
	await process_frame
	await photo(tag,"اختبار اصطدام مضبوط للدفعة اللاحقة؛ ليس تسجيل تفادٍ أو قتال طبيعي")
	fixture_reports.append({"requested_volley_zero_based":volley,"actual_hit_volley_zero_based":actual_volley,"source_seconds":source_seconds,"source_frame":world.keeper.frame_index,"before_hp":before_hp,"after_hp":world.hero.hp,"earlier_volley_overlap":earlier_overlap,"no_prior_damage":before_hp==6,"hero_position":json_value(world.hero.position),"sheet_world_rect":json_value(rectangle)})

func paper_fixtures() -> void:
	await paper_case(1,"20_configured_second_volley")
	world.singing.stop_for_room_exit()
	world.keeper_sound.stop_all()
	world.soundscape.stop_all()
	world.queue_free()
	await process_frame
	await process_frame
	world=load(SCENE).instantiate()
	root.add_child(world)
	await process_frame
	await paper_case(2,"21_configured_third_volley")
	var changed: Array[String] = []
	for path in source_hashes:
		if FileAccess.get_sha256("res://"+path)!=source_hashes[path]: changed.append(path)
	if final_capture and not changed.is_empty(): failures.append("Sources changed during paper fixture capture")
	var report := {"engine":Engine.get_version_info().string,"scope":"Explicit configured collision fixtures, not gameplay or actual player dodges. Original later sheets, fresh normal six health, no earlier sheet overlapping the target position.","configured_fixture":true,"actual_input_only":false,"source_sha256":source_hashes,"source_files_changed":changed,"fixtures":fixture_reports,"photos":photos,"failures":failures}
	FileAccess.open(output+"/paper_fixture_metadata.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Native graphics and audio are required")
		quit(1)
		return
	root.size=Vector2i(1280,720)
	final_capture="--final-capture" in OS.get_cmdline_user_args()
	var sample_only := "--sample" in OS.get_cmdline_user_args()
	fixture_mode="--paper-fixtures" in OS.get_cmdline_user_args()
	if final_capture or sample_only: output="res://previews/m27"
	DirAccess.make_dir_recursive_absolute(output)
	hash_sources()
	world=load(SCENE).instantiate()
	root.add_child(world)
	await step()
	if not world.has_method("get_trial_snapshot") or not is_instance_valid(world.get("arena_art")):
		push_error("M27 trial arena is not ready")
		quit(1)
		return
	if fixture_mode:
		await paper_fixtures()
	else:
		await approach()
		if encounter_tick>=0 and not sample_only: await melee_review()
		write_report(sample_only)
	release_inputs()
	world.singing.stop_for_room_exit()
	world.keeper_sound.stop_all()
	world.soundscape.stop_all()
	world.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
