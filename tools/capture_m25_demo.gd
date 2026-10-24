extends "res://tools/test_m24_bell.gd"
## Real-input M25 review. Default output is outside the repository for tuning.
## Only use --final-capture after the root agent explicitly freezes production.
const PRELIMINARY_OUTPUT := "/workspace/work/m25_preliminary"
const FINAL_OUTPUT := "res://previews/m25"
var output_dir := PRELIMINARY_OUTPUT
var final_capture := false
var waves: Dictionary = {}
var phase_patterns: Dictionary = {1: [], 2: []}
var phase_states: Dictionary = {1: [], 2: []}
var jump_clears: Array[Dictionary] = []
var retreat_samples: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var stills: Array[Dictionary] = []
var source_hashes: Dictionary = {}
var arena_bounds := Rect2(1110,940,1080,320)
var phase_seen: Array[int] = []
var jump_held := false
var last_jump_tick := -100
var last_sword_tick := -100
var last_spell_tick := -100
var retreat_wave_id := 0
var retreat_started_tick := -1
var retreat_finished := false
var fight_start_tick := 0
var fight_start_age := 0.0
var wall_start_msec := 0
var travel_distance := 0.0
var previous_hero_position := Vector2.ZERO
var properties: Dictionary = {}

func property(object: Object, key: String, fallback: Variant = null) -> Variant:
	if not is_instance_valid(object): return fallback
	var id := object.get_instance_id()
	if not properties.has(id):
		var names: Dictionary = {}
		for item in object.get_property_list(): names[str(item.name)] = true
		properties[id] = names
	return object.get(key) if properties[id].has(key) else fallback

func phase_number() -> int:
	return int(property(bell,"phase",1))

func phase_clear_count(phase: int) -> int:
	var count := 0
	for item in jump_clears:
		if item.phase == phase: count += 1
	return count

func endpoint_count(phase: int = 0) -> int:
	var count := 0
	for item in waves.values():
		if item.get("ended",false) and item.get("reached_endpoint",false) and (phase == 0 or item.phase == phase): count += 1
	return count

func finish_wave(id: int) -> void:
	if not waves.has(id): return
	var item: Dictionary = waves[id]
	var node: Node2D = item.reference.get_ref()
	if is_instance_valid(node):
		item.last_x = node.position.x
		item.last_age = float(property(node,"age",item.last_age))
		item.hero_hits = int(property(node,"hero_hits",0))
		item.was_blocked = bool(property(node,"was_blocked",false))
		item.end_reason = str(property(node,"expired_reason",property(node,"termination_reason",property(node,"end_reason","unreported"))))
		item.reached_boundary = bool(property(node,"reached_boundary",false))
		item.boundary_x = property(node,"boundary_x",null)
	item.ended = true
	item.end_tick = ticks
	item.reached_endpoint = item.get("reached_boundary",false) or minf(absf(item.last_x-arena_bounds.position.x),absf(item.last_x-arena_bounds.end.x)) < 35.0
	item.travelled = absf(item.last_x-item.origin_x)

func observe() -> void:
	if not is_instance_valid(bell) or not is_instance_valid(hero): return
	var phase := phase_number()
	if not phase_seen.has(phase): phase_seen.append(phase)
	if not phase_states.has(phase): phase_states[phase] = []
	if not phase_patterns.has(phase): phase_patterns[phase] = []
	if not phase_states[phase].has(bell.state): phase_states[phase].append(bell.state)
	var pattern := str(property(bell,"current_pattern",""))
	if not pattern.is_empty() and bell.state not in ["intro","idle","phase_change"] and not phase_patterns[phase].has(pattern): phase_patterns[phase].append(pattern)
	for wave in get_nodes_in_group("m23_boss_attacks"):
		if not is_instance_valid(wave) or bool(property(wave,"spent",false)): continue
		var id: int = wave.get_instance_id()
		if not waves.has(id):
			waves[id] = {"reference":weakref(wave),"phase":phase,"origin_x":wave.position.x,"last_x":wave.position.x,"last_age":0.0,"speed":wave.travel.x,"spawn_tick":ticks,"ended":false,"crossed":false,"relative_x":wave.position.x-hero.position.x,"hero_hp_before":hero.hp}
			wave.tree_exiting.connect(finish_wave.bind(id))
		var item: Dictionary = waves[id]
		var relative: float = wave.position.x-hero.position.x
		if not item.crossed and relative*float(item.relative_x) <= 0 and absf(relative-float(item.relative_x)) < 100:
			item.crossed = true
			var overlap := false
			for box in hero.get_hurtboxes():
				if (box as Rect2).intersects(wave.damage_rect()): overlap = true
			var height: float = bell.floor_y-hero.position.y
			var immune := float(property(hero,"invulnerable",0.0)) > 0
			if not hero.is_on_floor() and height > 24 and not overlap and not immune and int(property(wave,"hero_hits",0)) == 0 and last_jump_tick >= int(item.spawn_tick)-10 and ticks-last_jump_tick < 60:
				jump_clears.append({"wave_id":id,"phase":phase,"tick":ticks,"hero_height":height,"hero_hp":hero.hp,"wave_x":wave.position.x,"hero_x":hero.position.x,"invulnerable":false,"actual_jump_input_tick":last_jump_tick})
		item.relative_x = relative
		item.last_x = wave.position.x
		item.last_age = wave.age
		item.hero_hits = int(property(wave,"hero_hits",0))
	if ticks%15 == 0 and (trace.is_empty() or trace[-1].tick != ticks):
		trace.append({"tick":ticks,"phase":phase,"bell_state":bell.state,"pattern":pattern,"bell_hp":bell.hp,"hero_hp":hero.hp,"hero_x":hero.position.x,"hero_y":hero.position.y,"bell_x":bell.position.x,"bell_y":bell.position.y,"live_waves":get_nodes_in_group("m23_boss_attacks").size()})

func incoming_wave() -> Node2D:
	var result: Node2D
	var best := INF
	for wave in get_nodes_in_group("m23_boss_attacks"):
		if not is_instance_valid(wave) or wave.spent or absf(wave.travel.x) < 1: continue
		var gap: float = hero.position.x-wave.position.x
		if gap*wave.travel.x <= 0: continue
		var contact: float = absf(gap/wave.travel.x)
		if contact < best: best = contact;result = wave
	return result

func jump_now() -> void:
	if hero.is_on_floor() and ticks-last_jump_tick > 10:
		Input.action_press("jump")
		jump_held = true
		last_jump_tick = ticks

func desired_side(centre: float) -> int:
	var left_space := centre-(arena_bounds.position.x+35)
	var right_space := arena_bounds.end.x-35-centre
	var side := -1 if hero.position.x < centre else 1
	if side < 0 and left_space < 170: side = 1
	elif side > 0 and right_space < 170: side = -1
	return side

func drive() -> void:
	Input.action_release("attack");Input.action_release("spell")
	Input.action_release("look_up");Input.action_release("look_down")
	if jump_held and hero.velocity.y >= 0:
		Input.action_release("jump");jump_held = false
	var phase := phase_number()
	var centre: float = bell.position.x
	var target: float
	if bell.state in ["air","high_air"]:
		var vy: float = bell.flight_velocity.y
		var gravity := 3000.0 if bell.state == "high_air" else 1900.0
		var remaining := (-vy+sqrt(maxf(0,vy*vy+2*gravity*(bell.floor_y-bell.position.y))))/gravity
		centre = clampf(bell.position.x+bell.flight_velocity.x*remaining,arena_bounds.position.x+80,arena_bounds.end.x-80)
		var distance := 245.0 if not retreat_finished else 160.0
		target = centre+desired_side(centre)*distance
	else:
		var spacing := 105.0 if phase_clear_count(phase)>0 else 180.0
		if bell.state == "echo_wait": spacing = 170.0
		target = centre+desired_side(centre)*spacing
	move_to(clampf(target,arena_bounds.position.x+20,arena_bounds.end.x-20))
	var wave := incoming_wave()
	if is_instance_valid(wave):
		var gap: float = absf(hero.position.x-wave.position.x)
		var contact: float = gap/absf(wave.travel.x)
		if retreat_wave_id == 0 and not retreat_finished and hero.is_on_floor() and contact > .21:
			retreat_wave_id = wave.get_instance_id();retreat_started_tick = ticks
		if wave.get_instance_id() == retreat_wave_id and not retreat_finished:
			move_to(hero.position.x+signf(wave.travel.x)*100)
			retreat_samples.append({"tick":ticks,"gap":gap,"wave_x":wave.position.x,"hero_x":hero.position.x,"wave_speed":wave.travel.x,"hero_speed":hero.velocity.x,"wave_age":wave.age})
			if contact <= .12 or ticks-retreat_started_tick >= 10:
				retreat_finished = true
		if contact <= .24 and (wave.get_instance_id() != retreat_wave_id or retreat_finished):
			jump_now()
			# Jumping toward the wave clears it promptly, rather than escaping it.
			move_to(clampf(hero.position.x-signf(wave.travel.x)*90,arena_bounds.position.x+20,arena_bounds.end.x-20))
	var dx: float = bell.position.x-hero.position.x
	if bell.state in ["drawback","double_drawback"] and bell.state_time < .24 and absf(dx) < 360: jump_now()
	var ready := phase_clear_count(1)>0 and endpoint_count()>0
	if phase >= 2: ready = ready and phase_patterns[phase].size()>=2 and phase_clear_count(phase)>0 and endpoint_count(phase)>0
	var safe: bool = bell.state in ["recover","resonance","idle","stagger","crouch","high_crouch","echo_wait"]
	if ready:
		if not hero.is_on_floor() and absf(dx)<85: Input.action_press("look_down")
		elif absf(dx)<40: Input.action_press("look_up")
		if safe and absf(dx)<300 and ticks-last_spell_tick>115 and hero.energy>=33:
			move_to(bell.position.x)
			Input.action_press("spell");last_spell_tick=ticks
		if safe and absf(dx)<125 and ticks-last_sword_tick>23:
			move_to(bell.position.x)
			Input.action_press("attack");last_sword_tick=ticks

func photo(tag: String) -> void:
	if DisplayServer.get_name()=="headless" or captured.has(tag) or "--no-photos" in OS.get_cmdline_user_args(): return
	captured[tag]=true
	await RenderingServer.frame_post_draw
	var frame:Image=root.get_texture().get_image()
	var target:=output_dir+"/"+tag+".jpg"
	frame.save_jpg(target,.95)
	stills.append({"path":target,"tick":ticks,"phase":phase_number(),"bell_state":bell.state,"hero_hp":hero.hp,"bell_hp":bell.hp,"actual_inputs_only":true,"configured_fixture":false})

func run() -> void:
	final_capture = "--final-capture" in OS.get_cmdline_user_args()
	output_dir = FINAL_OUTPUT if final_capture else PRELIMINARY_OUTPUT
	if not final_capture:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--output-dir=/workspace/work/"): output_dir=arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	for path in ["tools/capture_m25_demo.gd","scripts/minibosses/m24_bell_warden.gd","scripts/minibosses/m24_bell_wave.gd","scripts/minibosses/m24_bell_character.gd","scripts/minibosses/m24_bell_visual.gd","scripts/stage/m24_folding_library.gd","scripts/stage/m25_bell_impact.gd","scripts/ui/m24_hud.gd","scripts/audio/m24_soundscape.gd","scripts/audio/m24_bell_music.gd","assets/minibosses/m24/bell_character_parts.png","assets/warden_m20/warden_parts.png","assets/audio/m24/events.json","assets/audio/m24/music/bell_warden_clockwork.ogg","assets/audio/m24/music/bell_warden_release.ogg"]:
		source_hashes[path]=FileAccess.get_sha256("res://"+path)
	await fresh()
	arena_bounds=bell.arena
	check(hero.hp==6 and hero.energy==99 and bell.hp==bell.max_hp,"fresh native loadout is unchanged")
	check(arena_bounds.size.x<=1100,"M25 arena width is at most 1100 px")
	Input.action_press("move_right")
	while not world.boss_active and ticks<300: await step()
	release()
	check(world.boss_active and bell.activated,"real movement enters and locks the arena")
	fight_start_tick=ticks;fight_start_age=bell.age;wall_start_msec=Time.get_ticks_msec()
	previous_hero_position=hero.position
	await photo("10_native_arena_entry")
	for frame in range(3600):
		if bell.is_dead or hero.hp<=0 or world._respawning: break
		observe();drive()
		await step()
		travel_distance+=hero.position.distance_to(previous_hero_position);previous_hero_position=hero.position
		observe()
		var phase:=phase_number()
		if bell.state=="phase_change" and bell.state_time<bell.state_duration*.65: await photo("19_native_phase_change")
		if phase==2: await photo("20_native_phase2")
		if bell.state=="double_rush" and bell.state_time<bell.state_duration*.65: await photo("21_native_double_rush")
		if bell.state=="high_air" and bell.flight_velocity.y>0: await photo("24_native_high_leap")
		if phase_clear_count(1)>0: await photo("12_native_phase1_jump")
		if phase_clear_count(2)>0: await photo("23_native_phase2_jump")
		if phase_clear_count(2)>1: await photo("26_native_echo_jump")
		for wave in get_nodes_in_group("m23_boss_attacks"):
			if is_instance_valid(wave) and wave.age>.06 and wave.age<.14:
				await photo("14_native_ground_slam" if phase==1 else "27_native_ground_slam_phase2")
			if is_instance_valid(wave) and waves.has(wave.get_instance_id()) and absf(wave.position.x-float(waves[wave.get_instance_id()].origin_x))>130:
				await photo("11_native_phase1_wave" if phase==1 else "22_native_phase2_wave")
			if is_instance_valid(wave) and absf(float(property(wave,"boundary_x",wave.position.x))-wave.position.x)>20 and absf(float(property(wave,"boundary_x",wave.position.x))-wave.position.x)<90:
				await photo("13_native_phase1_wave_edge" if phase==1 else "25_native_phase2_wave_edge")
		if frame%300==0: print("M25 DRIVER ",frame," phase=",phase," hero=",hero.hp," bell=",bell.hp," jumpclears=",jump_clears.size()," endpoints=",endpoint_count())
	release();observe()
	check(phase_seen.has(1) and phase_seen.has(2),"actual input reaches both real phases")
	check(phase_patterns[2].has("double_rush") and phase_patterns[2].has("high_leap"),"actual phase two performs both distinct new patterns")
	check(phase_clear_count(1)>0 and phase_clear_count(2)>0,"actual nonimmune jump clears a wave in each phase")
	check(endpoint_count()>0,"at least one live wave travels to an arena endpoint")
	var gap_closed:=retreat_samples.size()>1 and float(retreat_samples[-1].gap)<float(retreat_samples[0].gap)-5
	var retreat_wave_completed:bool=waves.has(retreat_wave_id) and waves[retreat_wave_id].get("reached_endpoint",false)
	check(gap_closed and retreat_wave_completed,"running away leaves the faster wave alive, closing the gap, and reaching its endpoint")
	check(bell.is_dead and hero.hp>0,"real sword/spell/movement inputs win without injected damage")
	if bell.is_dead:
		await photo("30_native_victory")
		await step(390)
	var wave_report:Array[Dictionary]=[]
	for item in waves.values():
		var copy:Dictionary=item.duplicate();copy.erase("reference");wave_report.append(copy)
	stats={"won":bell.is_dead,"hero_hp":hero.hp,"bell_hp":bell.hp,"phases":phase_seen,"phase_patterns":phase_patterns,"phase_states":phase_states,"active_combat_seconds":bell.age-fight_start_age,"ticks":ticks-fight_start_tick,"wall_seconds":(Time.get_ticks_msec()-wall_start_msec)/1000.0,"travel_distance":travel_distance,"jump_clears":jump_clears,"retreat_samples":retreat_samples,"waves":wave_report,"actual_inputs_only":true,"positive_injected_damage":false}
	var result:={"engine":Engine.get_version_info().string,"final_capture":final_capture,"scope":"Actual Input review only. No actor placement, direct positive damage, HP/energy changes, or frozen combatants.","arena":[arena_bounds.position.x,arena_bounds.position.y,arena_bounds.size.x,arena_bounds.size.y],"fight":stats,"checks":checks,"failures":failures,"stills":stills,"trace":trace,"source_sha256":source_hashes,"audio_scope":"Original native game music and SFX mixer; no replacement track."}
	FileAccess.open(output_dir+"/demo_capture_metadata.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("M25 DRIVER REPORT ",JSON.stringify({"checks":checks,"failures":failures,"won":stats.won,"hero_hp":stats.hero_hp,"bell_hp":stats.bell_hp,"phases":phase_seen,"jump_clears":jump_clears.size(),"endpoints":endpoint_count()}))
	await cleanup()
	quit(0 if failures.is_empty() else 1)
