extends SceneTree
## Focused Dr.Compiler integration QA. Positive battle actions use ordinary
## Input; fixture setup, observed states and save scopes are recorded separately.
const REPORT := "user://m23_boss_world_report.json"
const TRIAL_SCENE := "res://scenes/bosses/compiler_trial_m23.tscn"
const LIBRARY_SCENE := "res://scenes/stage_01/folding_library_m23.tscn"
const HERO_ATLAS := "res://assets/warden_m20/warden_parts.png"
const HERO_ATLAS_SHA256 := "6eca7436c7a8c39451256aa56db465d664df0d6dbb42d8e7f24122592b34bb66"
var world: Node2D
var hero: CharacterBody2D
var boss: Node2D
var checks: int = 0
var failures: Array[String] = []
var evidence: Array[Dictionary] = []
var physics_ticks: int = 0
var stage := "startup"
var user_backups: Dictionary = {}
var original_files: Array[String] = []
var fight_states: Array[String] = []
var fight_stats: Dictionary = {}
var battle_damage: Array[Dictionary] = []
var last_attack_press: int = -100
var last_spell_press: int = -100
var score_samples: Array[Dictionary] = []
var positive_hit_kinds: Dictionary = {}
var battle_start_tick := 0
var trial_normal_file_hashes: Dictionary={}
var phase2_clear_seen := false
var phase2_music_seen := false
var release_phase_checked := false

func release_native_snapshot(tag: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image=root.get_texture().get_image()
	var target: String="res://previews/m23/"+tag+".jpg"
	check(not frame.is_empty() and frame.save_jpg(target,.94)==OK,"actual battle native frame saved: "+tag)
	record("release_native_frame",{"path":target,"actual_input_battle":true,"boss_state":boss.state,"boss_hp":boss.hp,"phase_progress":boss.visual.pose_progress,"paused":world.paused,"camera_zoom":[world.camera.zoom.x,world.camera.zoom.y]})

func release_sound_checks() -> void:
	stage="final actual battle voice and event-sound paths"
	# The combat pause test opens a map, not a book. Exercise the actual
	# journal before checking its intentionally distinct alias counters.
	await pulse("journal")
	check(world.hud.panel_open and world.hud.current_panel=="journal","actual journal input opens its reading panel for audio acceptance")
	await close_panel_input()
	var audio: Node=world.get("soundscape")
	if not check(is_instance_valid(audio) and audio.manifest_loaded,"original event-sound manifest is loaded in the actual trial"): return
	var counts: Dictionary=audio.event_counts
	for cue in ["compiler_voice_intro","compiler_voice_phase","compiler_voice_death","compiler_bolts","compiler_sweep","compiler_pillars","compiler_release","compiler_phase","swing","hit","spell","coin","journal_open","journal_close"]:
		check(int(counts.get(cue,0))>0,"actual fight/menu/reward path plays "+cue)
	var boss_attack_voices:=0
	for cue in ["compiler_voice_attack_1","compiler_voice_attack_2","compiler_voice_attack_3"]: boss_attack_voices+=int(counts.get(cue,0))
	check(boss_attack_voices>0,"actual warnings play original boss exertion voice")
	check(int(counts.get("hero_attack",0))+int(counts.get("hero_dash_voice",0))+int(counts.get("hero_spell_voice",0))>0,"actual player actions play original hero exertion voice")
	check(int(counts.get("footstep_stone",0))+int(counts.get("footstep_paper",0))+int(counts.get("footstep",0))>0,"real movement triggers measured-distance surface footsteps")
	check(audio.active_player_count<=16,"actual full encounter keeps the event-audio pool within16 players")
	var log_paths_valid:=true
	for entry in audio.event_log:
		if not ResourceLoader.exists(str(entry.get("path",""))): log_paths_valid=false
	check(log_paths_valid,"every actually logged event references an importable shipped audio stream")
	var copy: Dictionary=audio.event_counts
	copy["test_mutation"]=-1
	check(not audio.event_counts.has("test_mutation"),"read-only event counter snapshots do not mutate playback state")
	record("release_actual_sound_paths",{"event_counts":counts,"recent_event_log":audio.event_log,"rejected_counts":audio.rejected_counts,"active_player_count":audio.active_player_count,"actual_gameplay_paths":true,"subjective_listening_claim":false,"not_a_full_all_events_fixture":true})

func phase_transition_release_checks() -> void:
	stage="final actual two-second phase transformation pause and invulnerability"
	release_controls()
	var starting_boss_hp: int=boss.hp
	var starting_hero_hp: int=hero.hp
	check(boss.state=="phase_transition" and boss.phase==2,"real sword/spell damage enters the authored phase-II transformation")
	check(absf(boss.state_duration-2.0)<.02,"phase choreography owns the documented safe two-second interval")
	var cleared:=true
	for attack in get_nodes_in_group("m23_boss_attacks"):
		if is_instance_valid(attack) and not attack.spent and not attack.is_queued_for_deletion(): cleared=false
	check(cleared,"phase transformation clears every prior damaging attack")
	await physical_key(KEY_M)
	await step(5)
	check(world.hud.panel_open and not world.gameplay_active,"actual map input pauses the transformation")
	var time_before: float=boss.state_time
	var age_before: float=boss.age
	var visual_progress: float=boss.visual.pose_progress
	await step(24)
	check(boss.state=="phase_transition" and is_equal_approx(boss.state_time,time_before) and is_equal_approx(boss.age,age_before),"phase clock and actor age freeze throughout the actual pause")
	check(is_equal_approx(boss.visual.pose_progress,visual_progress),"the side-view choreography holds its exact pose while paused")
	check(world.boss_music.current_phase==2 and world.boss_music.current_duck_db<=-11.5,"transformation keeps phase-II score and its cinematic/pause duck")
	await release_native_snapshot("16_phase_paused")
	await close_panel_input()
	# Contact is produced through ordinary movement and attack inputs. This
	# does not call take_hit and cannot inject damage into a protected phase.
	var contacts:=0
	var tick:=0
	var phase_photo_taken:=false
	while boss.state=="phase_transition" and boss.state_time>.24 and tick<160:
		drive_toward(boss.position.x)
		Input.action_release("look_up")
		Input.action_release("look_down")
		Input.action_press("look_up" if hero.is_on_floor() else "look_down")
		if tick%3==0: Input.action_release("attack")
		if hero.attack_cooldown<=0: Input.action_press("attack")
		await step(1)
		if hero.active_strike_time>0 and hero.strike_rect(hero.attack_direction,hero.facing).intersects(boss.get_hitbox()): contacts+=1
		if not phase_photo_taken and boss.state_time<=1.04:
			phase_photo_taken=true
			await release_native_snapshot("17_phase_transformation")
		tick+=1
	release_controls()
	check(contacts>0,"an actual active sword volume reaches the transforming boss")
	check(boss.hp==starting_boss_hp and hero.hp==starting_hero_hp,"the transformation neither receives sword damage nor damages the hero")
	check(world.boss_music.current_phase==2 and world.boss_music.weights[1]>.98,"original phase-II score finishes its crossfade without a restart")
	record("release_phase_transform",{"duration_seconds":boss.state_duration,"actual_map_pause":true,"pause_remaining_time":time_before,"paused_visual_progress":visual_progress,"actual_sword_contact_frames":contacts,"boss_hp_before":starting_boss_hp,"boss_hp_after":boss.hp,"hero_hp_before":starting_hero_hp,"hero_hp_after":hero.hp,"positive_damage_injected":false,"old_hazards_cleared":cleared})
	stage="final full48-health fight by reactive ordinary inputs"

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> bool:
	checks += 1
	if not value:
		var labelled := stage+": "+message
		if not failures.has(labelled): failures.append(labelled)
		print("M23 QA FAIL ",labelled)
	return value

func record(kind: String, value: Dictionary) -> void:
	value.kind=kind
	value.stage=stage
	value.physics_tick=physics_ticks
	evidence.append(value)

func step(count: int) -> void:
	for tick in range(count):
		await physics_frame
		physics_ticks+=1

func release_controls() -> void:
	for action in ["move_left","move_right","look_up","look_down","jump","attack","dash","spell","heal","interact","pause_game","journal","stage_map","ui_accept","ui_cancel"]:
		if InputMap.has_action(action): Input.action_release(action)

func pulse(action: String, held: int = 2) -> void:
	await physics_frame
	Input.action_press(action)
	await step(held)
	Input.action_release(action)
	await step(2)

func physical_key(code: int) -> void:
	await physics_frame
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await step(2)
	event=InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=false
	Input.parse_input_event(event)
	await step(2)

func controller_button(button: int) -> void:
	await physics_frame
	var event := InputEventJoypadButton.new()
	event.button_index=button
	event.pressed=true
	Input.parse_input_event(event)
	await step(2)
	event=InputEventJoypadButton.new()
	event.button_index=button
	event.pressed=false
	Input.parse_input_event(event)
	await step(2)

func drive_toward(x: float) -> void:
	var error: float=x-hero.position.x
	var acceleration: float=9000.0 if hero.is_on_floor() else 7200.0
	var stopping: float=hero.velocity.x*hero.velocity.x/(2.0*acceleration)
	if absf(error)<3.0 or (hero.velocity.x*error>0 and absf(error)<stopping+3):
		Input.action_release("move_left")
		Input.action_release("move_right")
	elif error>0:
		Input.action_release("move_left")
		Input.action_press("move_right")
	else:
		Input.action_release("move_right")
		Input.action_press("move_left")

func walk_to(point: Vector2, limit: int = 900) -> bool:
	for tick in range(limit):
		drive_toward(point.x)
		await step(1)
		if hero.is_on_floor() and absf(hero.position.x-point.x)<6 and absf(hero.position.y-point.y)<3 and absf(hero.velocity.x)<3:
			release_controls()
			return true
	release_controls()
	return check(false,"actual walk to %s stopped at%s"%[point,hero.position])

func remember_user_files() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://"))
	var directory := DirAccess.open("user://")
	for name in directory.get_files():
		original_files.append(name)
		if name.begins_with("folding_library_") or name.begins_with("compiler_trial_"):
			user_backups[name]=FileAccess.get_file_as_bytes("user://"+name)

func restore_user_files() -> bool:
	var directory := DirAccess.open("user://")
	for name in user_backups:
		FileAccess.open("user://"+name,FileAccess.WRITE).store_buffer(user_backups[name])
	for name in directory.get_files():
		if (name.begins_with("folding_library_") or name.begins_with("compiler_trial_")) and not original_files.has(name):
			DirAccess.remove_absolute("user://"+name)
	for name in user_backups:
		if FileAccess.get_file_as_bytes("user://"+name)!=user_backups[name]: return false
	return true

func stop_audio(node: Node) -> void:
	for child in node.get_children(): stop_audio(child)
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.stop()
		node.stream=null

func dispose_world() -> void:
	release_controls()
	if not is_instance_valid(world): return
	stop_audio(world)
	OS.delay_msec(120)
	await process_frame
	if current_scene==world: current_scene=null
	world.queue_free()
	world=null
	hero=null
	boss=null
	await process_frame
	await process_frame

func make_world(trial: bool = true, restore: bool = false) -> bool:
	await dispose_world()
	var packed: PackedScene = load(TRIAL_SCENE if trial else LIBRARY_SCENE)
	if not check(packed!=null,"M23 scene exists"): return false
	world=packed.instantiate()
	packed=null
	if not check(world.get_script()!=null and world.has_method("_check_compiler_entry"),"M23 controller and preloads compile"):
		world.free();world=null
		return false
	world.restore_saved_game=restore
	world.transition_seconds=.001
	root.add_child(world)
	current_scene=world
	await step(50)
	hero=world.hero
	boss=world.registered_boss
	return check(is_instance_valid(hero) and hero.is_on_floor(),"M23 hero starts supported")

func begin_trial() -> bool:
	if not check(world.is_boss_trial and world.current_room==14,"standalone trial is isolated in room14"): return false
	check(world.save_path()=="user://compiler_trial_m23.json","trial uses its own save path")
	check(hero.hp==6 and hero.energy==99 and world.combat_state.capacity==4,"fresh trial gives its documented six-health99-energy capacity4 loadout")
	check(not world.boss_active and boss.hp==48 and not boss.activated,"boss waits beyond the safe outside checkpoint")
	check(not world.boss_arena.locked,"book gates are open before entry")
	if "--short-hero" in OS.get_cmdline_user_args():
		check(hero.get_script().resource_path=="res://scripts/combat/m23_player.gd","actual trial loads the final short-strike M23 player")
		check(hero.combat_model.get_script().resource_path=="res://scripts/warden_model_m23.gd","actual visible hero uses the M23 shared-atlas short-strike model")
	if not await walk_to(Vector2(1400,1440)): return false
	await step(3)
	check(world.boss_active and boss.activated and world.boss_arena.locked,"actual threshold crossing activates the encounter and book gates")
	check(FileAccess.get_sha256(HERO_ATLAS)==HERO_ATLAS_SHA256,"hero art remains byte-identical to approved M20")
	return true

func close_panel_input() -> bool:
	if not world.hud.panel_open: return true
	await physical_key(KEY_ESCAPE)
	for tick in range(60):
		if not world.hud.panel_open and not world.panel_closing: break
		await step(1)
	return check(not world.hud.panel_open and world.gameplay_active,"actual close input waits for the panel animation before play resumes")

func pause_and_score_checks() -> void:
	stage="actual map pause preserves live attack clocks and ducks original score"
	for tick in range(300):
		if not get_nodes_in_group("m23_boss_attacks").is_empty(): break
		await step(1)
	var attacks: Array= get_nodes_in_group("m23_boss_attacks")
	if not check(not attacks.is_empty(),"real boss emits an attack before the pause test"): return
	await physical_key(KEY_M)
	await step(8)
	check(world.hud.panel_open and world.hud.current_panel=="map" and not world.gameplay_active,"actual M opens a paused map during a live boss pattern")
	var state: String=boss.state
	var remaining: float=boss.state_time
	var position_before: Vector2=hero.position
	var snapshots: Array[Dictionary]=[]
	for attack in attacks:
		if is_instance_valid(attack): snapshots.append({"node":attack,"position":attack.global_position,"age":attack.age})
	await step(30)
	check(boss.state==state and is_equal_approx(boss.state_time,remaining) and hero.position.is_equal_approx(position_before),"pause freezes player and exact boss pattern time")
	for entry in snapshots:
		check(is_instance_valid(entry.node) and entry.node.global_position.is_equal_approx(entry.position) and is_equal_approx(entry.node.age,entry.age),"pause preserves each live projectile instead of cancelling a dangerous pattern")
	check(world.boss_music.assets_ready and world.boss_music.fight_playing and world.boss_music.current_phase==1,"original phase-one score is actually loaded and playing")
	check(world.boss_music.current_duck_db<=-11.5,"paused score reaches its quieter12dB duck")
	record("native_pause_and_music",{"live_attack_count":snapshots.size(),"boss_state":state,"state_time":remaining,"score_phase":world.boss_music.current_phase,"duck_db":world.boss_music.current_duck_db,"actual_map_input":true,"projectiles_cancelled":false})
	await close_panel_input()
	await step(6)
	var resumed:=false
	for entry in snapshots:
		if is_instance_valid(entry.node) and entry.node.global_position.distance_to(entry.position)>1: resumed=true
	check(resumed,"the same live attack resumes motion after closing the map")

func real_music_toggle_checks() -> void:
	stage="actual controller music mute preserves the adaptive score phase"
	await physical_key(KEY_ESCAPE)
	await step(20)
	var phase_before: int=world.boss_music.current_phase
	var changes_before: int=world.boss_music.phase_changes
	var button: Button=action_button(world.hud,"boss_music_toggle")
	if not check(button!=null,"actual trial pause contains a music toggle"): return
	button.grab_focus()
	await controller_button(JOY_BUTTON_A)
	await step(6)
	check(world.boss_music_muted and world.boss_music.muted,"real controller accept enables the boss music mute preference")
	var silent:=true
	for track in world.boss_music.tracks:
		if track.volume_db> -79.0: silent=false
	check(silent,"mute actually lowers every score player to silence")
	button=action_button(world.hud,"boss_music_toggle")
	button.grab_focus()
	await controller_button(JOY_BUTTON_A)
	await step(6)
	check(not world.boss_music_muted and not world.boss_music.muted,"real controller accept restores boss music")
	check(world.boss_music.current_phase==phase_before and world.boss_music.phase_changes==changes_before,"mute/unmute does not restart the active phase or crossfade")
	check(world.boss_music.tracks[phase_before-1].volume_db> -79.0,"unmute restores the active score gain")
	record("actual_music_toggle",{"controller_input":true,"phase_preserved":phase_before,"phase_changes_preserved":changes_before,"muted_gain_db":-80,"preference_restored":true})
	await close_panel_input()

func actual_loss_retry_checks() -> bool:
	stage="actual lethal pressure loss and quick supported retry"
	if not check(hero.hp<=0 and world._respawning,"cheap pressure causes an actual lethal attack rather than injected player damage"): return false
	var death_tick:=physics_ticks
	for tick in range(80):
		await step(1)
		if not world._respawning and world.gameplay_active: break
	boss=world.registered_boss
	check(hero.hp==6 and hero.is_on_floor() and hero.position.distance_to(Vector2(1040,1440))<3,"automatic retry returns six health to the safe supported outside checkpoint")
	check(is_instance_valid(boss) and boss.hp==48 and boss.phase==1 and not boss.activated,"actual retry resets all48 health and phase-one dormant state")
	check(get_nodes_in_group("m23_boss_attacks").is_empty() and not world.boss_arena.locked,"death removes old attacks and reopens book gates")
	check(not world.boss_music.fight_playing and world.boss_music.current_phase==0,"defeat leaves the battle score out of active-fight mode")
	check(physics_ticks-death_tick<=60,"automatic supported retry completes in under one nominal second")
	record("actual_death_retry",{"nominal_retry_frames":physics_ticks-death_tick,"position":[hero.position.x,hero.position.y],"boss_hp":boss.hp,"actual_lethal_attack":true,"teleported_by_test":false})
	await pulse("interact")
	check(world.hud.panel_open and world.hud.current_panel=="fitils" and hero.energy==99,"ordinary rest at the nearby trial bench refills energy for the next attempt")
	await close_panel_input()
	return hero.hp==6 and hero.energy==99

func watch_damage(previous_hp: int, previous_boss_hp: int, previous_state: String, previous_time: float) -> void:
	if hero.hp<previous_hp:
		battle_damage.append({"tick":physics_ticks,"boss_state":previous_state,"health_before":previous_hp,"health_after":hero.hp,"hero":[hero.position.x,hero.position.y],"boss":[boss.position.x,boss.position.y]})
	if boss.hp<previous_boss_hp:
		var kind: String=hero.attack_direction if hero.attack_time>0 else "spell_or_resolving_hit"
		positive_hit_kinds[kind]=int(positive_hit_kinds.get(kind,0))+previous_boss_hp-boss.hp
		if previous_state==boss.state and previous_state.ends_with("_warning"):
			check(boss.state_time<=previous_time+.025,"ordinary sword damage does not restart the current warning")
	if not fight_states.has(boss.state): fight_states.append(boss.state)

func closest_pillar_gap() -> float:
	var candidates: Array[float]=[]
	for x in boss.pillar_targets:
		candidates.append(clampf(float(x)-117.5,1360,2780))
		candidates.append(clampf(float(x)+117.5,1360,2780))
	var chosen: float=hero.position.x
	var best:=INF
	for candidate in candidates:
		var safe:=true
		for x in boss.pillar_targets:
			if absf(candidate-float(x))<76: safe=false
		if not safe: continue
		var cost: float=absf(candidate-hero.position.x)+absf(candidate-boss.position.x)*.18
		if cost<best: best=cost;chosen=candidate
	return chosen

func incoming_chain_near() -> bool:
	for attack in get_nodes_in_group("m23_boss_attacks"):
		if not is_instance_valid(attack) or attack.kind!="chain": continue
		var dx: float=hero.position.x-attack.global_position.x
		if dx*attack.travel.x>0 and absf(dx)<135: return true
	return false

func reactive_input_fight(max_ticks: int = 18000) -> bool:
	stage="full48-health fight by reactive ordinary inputs"
	battle_start_tick=physics_ticks
	var start_hp: int=boss.hp
	var start_health: int=hero.hp
	var minimum_health: int=hero.hp
	var run_distance:=0.0
	var dash_uses:=0
	var jump_uses:=0
	var cast_uses:=0
	var actual_jumps:=0
	var actual_dashes:=0
	var actual_casts:=0
	var forward_contact_samples:=0
	var maximum_forward_contact:=0.0
	var pillar_gap: float=hero.position.x
	var seen_attack_id: int=-1
	var heal_started_hp: int=-1
	for tick in range(max_ticks):
		if not is_instance_valid(boss) or boss.is_dead: break
		if hero.hp<=0 or world._respawning: break
		var old_x: float=hero.position.x
		var old_hp: int=hero.hp
		var old_boss_hp: int=boss.hp
		var old_state: String=boss.state
		var old_time: float=boss.state_time
		var old_floor: bool=hero.is_on_floor()
		var old_dash: float=hero.dash_time
		var old_spell: float=hero.spell_cooldown
		if tick-last_attack_press>=3: Input.action_release("attack")
		if tick-last_spell_press>=2: Input.action_release("spell")
		Input.action_release("dash")
		Input.action_release("look_up")
		Input.action_release("look_down")
		if not hero.is_on_floor() and hero.velocity.y>=0: Input.action_release("jump")
		var dx: float=boss.position.x-hero.position.x
		if boss.attack_id!=seen_attack_id:
			seen_attack_id=boss.attack_id
			if boss.state=="pillars_warning": pillar_gap=closest_pillar_gap()
		if boss.state=="pillars_warning":
			pillar_gap=closest_pillar_gap()
			drive_toward(pillar_gap)
		elif boss.state=="pillars_active":
			drive_toward(pillar_gap)
		elif boss.state in ["sweep_warning","sweep_active"]:
			# Move behind the captured facing rather than dash through damage.
			drive_toward(clampf(boss.position.x-float(boss.direction)*90,1370,2770))
			if hero.is_on_floor() and boss.state=="sweep_warning" and boss.state_time<.26:
				Input.action_press("jump");jump_uses+=1
		elif boss.state in ["bolts_warning","bolts_active"]:
			# The warning stores the old target. Crossing behind the caster is
			# a real positional dodge of the fixed aim, not immunity.
			drive_toward(clampf(boss.position.x-float(boss.direction)*80,1370,2770))
		else:
			drive_toward(clampf(boss.position.x-float(signf(dx))*68,1370,2770))
			if absf(dx)>220 and hero.dash_cooldown<=0 and boss.state in ["recover","idle"]:
				Input.action_press("dash");dash_uses+=1
		if incoming_chain_near() and hero.is_on_floor():
			Input.action_press("jump");jump_uses+=1
		if hero.hp<=3 and hero.energy>=33 and boss.state=="chains_warning" and boss.state_time>.70:
			Input.action_press("heal");heal_started_hp=hero.hp
		if hero.healing:
			Input.action_release("move_left");Input.action_release("move_right")
			if hero.hp>heal_started_hp or incoming_chain_near(): Input.action_release("heal")
		else:
			Input.action_release("heal")
			if absf(dx)<155 and hero.attack_cooldown<=0 and boss.state not in ["intro","phase_transition"]:
				if not hero.is_on_floor() and hero.position.y<boss.floor_y-45: Input.action_press("look_down")
				elif absf(dx)<50: Input.action_press("look_up")
				Input.action_press("attack");last_attack_press=tick
			if absf(dx)>135 and absf(dx)<580 and hero.energy>=33 and hero.spell_cooldown<=0 and boss.state in ["recover","bolts_warning"]:
				Input.action_press("spell");last_spell_press=tick;cast_uses+=1
		await step(1)
		if not is_instance_valid(boss): break
		run_distance+=absf(hero.position.x-old_x)
		minimum_health=mini(minimum_health,hero.hp)
		if old_floor and not hero.is_on_floor() and hero.velocity.y < -300: actual_jumps+=1
		if old_dash<=0 and hero.dash_time>0: actual_dashes+=1
		if hero.spell_cooldown>old_spell+.1: actual_casts+=1
		if hero.active_strike_time>0 and hero.attack_direction=="attack":
			var strike: Rect2=hero.strike_rect(hero.attack_direction,hero.facing)
			if strike.has_area():
				forward_contact_samples+=1
				var extent: float=strike.end.x-hero.global_position.x if hero.facing>0 else hero.global_position.x-strike.position.x
				maximum_forward_contact=maxf(maximum_forward_contact,extent)
		watch_damage(old_hp,old_boss_hp,old_state,old_time)
		if boss.state=="phase_transition":
			if not phase2_clear_seen:
				phase2_clear_seen=true
				var safe_clear:=true
				for attack in get_nodes_in_group("m23_boss_attacks"):
					if is_instance_valid(attack) and not attack.spent and not attack.is_queued_for_deletion(): safe_clear=false
				check(safe_clear,"the real phase change removes dangerous remnants of phase one")
			if "--release-fight" in OS.get_cmdline_user_args() and not release_phase_checked:
				release_phase_checked=true
				await phase_transition_release_checks()
			if boss.state_time<.06 and not phase2_music_seen:
				phase2_music_seen=true
				check(world.boss_music.current_phase==2 and world.boss_music.weights[1]>.98 and world.boss_music.weights[0]<.02,"actual phase transition finishes the original-score crossfade")
		if tick%300==0: print("M23 FIGHT ",tick," hero=",hero.position," hp=",hero.hp," boss=",boss.hp," ",boss.state)
	release_controls()
	var won: bool=is_instance_valid(boss) and boss.is_dead and boss.hp==0
	fight_stats={"won":won,"start_boss_hp":start_hp,"end_boss_hp":boss.hp if is_instance_valid(boss) else -1,"start_player_hp":start_health,"end_player_hp":hero.hp,"minimum_player_hp":minimum_health,"physics_frames":physics_ticks-battle_start_tick,"nominal_seconds":float(physics_ticks-battle_start_tick)/60.0,"states_seen":fight_states,"run_distance":run_distance,"jump_requests":jump_uses,"dash_requests":dash_uses,"spell_requests":cast_uses,"actual_jump_starts":actual_jumps,"actual_dash_starts":actual_dashes,"actual_spell_casts":actual_casts,"positive_damage_by_input_state":positive_hit_kinds,"forward_contact_samples":forward_contact_samples,"maximum_forward_contact_pixels":maximum_forward_contact,"actual_input_only":true,"player_teleported_during_fight":false,"boss_frozen":false,"positive_damage_injected":false}
	record("reactive_full_health_fight",fight_stats.duplicate(true))
	check(won,"actual movement/jump/sword/spell inputs defeat all48 boss health")
	check(run_distance>800,"the winning driver repositions substantially instead of farming a stationary target")
	if "--short-hero" in OS.get_cmdline_user_args():
		check(forward_contact_samples>0 and maximum_forward_contact>45 and maximum_forward_contact<72,"live model-derived forward contact uses the shortened hero reach rather than the old92px strike")
	return won

func cheap_pressure_probe() -> void:
	stage="cheap inside-body chase and upward slash without defensive decisions"
	var start_tick:=physics_ticks
	var minimum_health: int=hero.hp
	var states: Array[String]=[]
	for tick in range(12000):
		if not is_instance_valid(boss) or boss.is_dead or hero.hp<=0 or world._respawning: break
		if not states.has(boss.state): states.append(boss.state)
		drive_toward(boss.position.x)
		Input.action_press("look_up")
		if tick%24==0: Input.action_press("attack")
		if tick%24==3: Input.action_release("attack")
		await step(1)
		minimum_health=mini(minimum_health,hero.hp)
		if tick%600==0: print("M23 CHEAP ",tick," hp=",hero.hp," boss=",boss.hp," ",boss.state)
	release_controls()
	var won: bool=is_instance_valid(boss) and boss.is_dead
	fight_stats={"cheap_strategy_won":won,"boss_hp_remaining":boss.hp if is_instance_valid(boss) else -1,"hero_hp":hero.hp,"minimum_hero_hp":minimum_health,"frames":physics_ticks-start_tick,"nominal_seconds":float(physics_ticks-start_tick)/60.0,"states_seen":states,"strategy":"constant chase to boss centre plus manual upward slash; no state-dependent dodge, no jump/dash/spell/heal","actual_input_only":true,"positive_hits_injected":false}
	record("cheap_pressure_probe",fight_stats.duplicate(true))
	check(not won,"unreactive inside-body pressure cannot defeat the complete boss before losing")

func blind_pogo_probe() -> void:
	stage="blind centre chase and downward slash without reading boss warnings"
	var start_tick:=physics_ticks
	var first_jump_started:=false
	var jump_requested:=false
	var states: Array[String]=[]
	for tick in range(12000):
		if not is_instance_valid(boss) or boss.is_dead or hero.hp<=0 or world._respawning: break
		if not states.has(boss.state): states.append(boss.state)
		drive_toward(boss.position.x)
		if not hero.is_on_floor(): first_jump_started=true
		if not jump_requested and hero.is_on_floor() and absf(hero.position.x-boss.position.x)<85:
			Input.action_press("jump");jump_requested=true
		if not hero.is_on_floor() and hero.velocity.y>=0: Input.action_release("jump")
		if not hero.is_on_floor(): Input.action_press("look_down")
		else: Input.action_release("look_down")
		if tick%24==0: Input.action_press("attack")
		if tick%24==3: Input.action_release("attack")
		await step(1)
		if tick%600==0: print("M23 BLIND POGO ",tick," hp=",hero.hp," boss=",boss.hp," y=",hero.position.y)
	release_controls()
	var won: bool=is_instance_valid(boss) and boss.is_dead
	fight_stats={"blind_pogo_won":won,"boss_hp_remaining":boss.hp if is_instance_valid(boss) else -1,"hero_hp":hero.hp,"frames":physics_ticks-start_tick,"nominal_seconds":float(physics_ticks-start_tick)/60.0,"initial_jump_occurred":first_jump_started,"states_seen":states,"strategy":"constant chase to boss centre; one ordinary initial jump then downward slash every.4s; no state/marker-dependent dodges, no dash/spell/heal","actual_input_only":true,"positive_hits_injected":false}
	record("blind_pogo_probe",fight_stats.duplicate(true))
	check(not won,"blind downward pressure cannot defeat the full boss without reading any warnings")

func seed_normal_save_fixture() -> void:
	var puzzle=load("res://scripts/stage/m22_puzzle_state.gd")
	var progress_data: Dictionary=puzzle.new_progress()
	progress_data.weapon_owned=true
	progress_data.visited=[1]
	progress_data.notes=["entrance_note"]
	var state=load("res://scripts/combat/m18_combat_state.gd").new()
	state.wallet=37
	state.capacity=5
	state.dash_owned=true
	state.spell_owned=true
	state.acquire("reach")
	for path in ["user://folding_library_m18.json","user://folding_library_m18_preview.json"]:
		var saved_progress: Dictionary=progress_data.duplicate(true)
		if "preview" in path: saved_progress.preview_departed=true
		var data: Dictionary={"version":18,"environment_preview":"preview" in path,"progress":saved_progress,"checkpoint":{"room":1,"position":[394.0,1260.0]},"language":"ar","combat":state.serialize(),"energy":66.0}
		FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(data))
		trial_normal_file_hashes[path]=FileAccess.get_sha256(path)

func check_normal_saves_unchanged() -> void:
	for path in trial_normal_file_hashes:
		check(FileAccess.get_sha256(path)==trial_normal_file_hashes[path],"isolated boss trial does not overwrite normal M22 save bytes: "+str(path))

func victory_reward_checks() -> void:
	stage="real victory flags, permanent reward receipt and physical coin collection"
	check(boss.is_dead and boss.hp==0 and not world.boss_active,"actual victory ends combat")
	check(world.progress.get("trial_compiler_defeated",false),"actual standalone victory records only its trial flag")
	for flag in ["guard_clear","compiler_seal_owned","seal_registered","boss_defeated","preview_compiler_defeated"]:
		check(not world.progress.get(flag,false),"trial victory forges no story eligibility or preview flag: "+flag)
	check(world.combat_state.capacity==5 and world.combat_state.collected.has("dr_compiler_capacity"),"actual victory grants its once-only capacity upgrade")
	check(not world.boss_arena.locked and world.boss_arena.defeated,"actual victory opens the book gates")
	check(get_nodes_in_group("m23_boss_attacks").is_empty(),"actual victory clears all remaining boss attacks")
	var exit_allowed:=false
	for exit in world.data.exits:
		if int(exit.target)==15: exit_allowed=world.can_use_exit(exit)
	check(exit_allowed,"actual standalone victory unlocks its outward trial exit")
	var wallet_before: int=world.combat_state.wallet
	var definitions: Array=[]
	for coin in get_nodes_in_group("m22_coins"):
		if is_instance_valid(coin) and str(coin.get_meta("reward_id",""))=="boss:dr_compiler": definitions.append(coin.definition.duplicate(true))
	check(definitions.size()==6,"actual boss reward emits six physical90-total coin discs")
	for definition in definitions:
		var point: Array=definition.position
		if not await walk_to(Vector2(float(point[0]),1440),300): return
		await step(45)
	await step(8)
	check(world.combat_state.wallet==wallet_before+90,"ordinary proximity collection credits all90 physical boss coins")
	var saved_wallet: int=world.combat_state.wallet
	world.on_compiler_defeated(boss)
	await step(5)
	check(world.combat_state.capacity==5 and world.combat_state.wallet==saved_wallet,"duplicate defeat callback grants neither a second capacity upgrade nor currency")
	for definition in definitions: check(not world.collect_world_coin(definition),"a collected boss coin cannot pay twice")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(int(saved.combat.capacity)==5 and int(saved.combat.wallet)==saved_wallet and saved.progress.get("trial_compiler_defeated",false),"real trial save retains the upgrade, collected wallet and victory receipt")
	record("actual_victory_rewards",{"capacity":world.combat_state.capacity,"physical_coins":definitions.size(),"currency_earned":90,"saved_wallet":saved_wallet,"story_flags_granted":false,"trial_replay_is_fresh_by_design":true})
	check_normal_saves_unchanged()

func action_button(node: Node, identity: String) -> Button:
	if node is Button and str(node.get_meta("action_id",""))==identity: return node
	for child in node.get_children():
		var result: Button=action_button(child,identity)
		if result!=null: return result
	return null

func activate_menu_action(identity: String) -> bool:
	await physical_key(KEY_ESCAPE)
	await step(20)
	var button: Button=action_button(world.hud,identity)
	if not check(button!=null,"native pause menu contains "+identity): return false
	button.grab_focus()
	await controller_button(JOY_BUTTON_A)
	await step(45)
	world=current_scene
	if not check(is_instance_valid(world) and world.has_method("_check_compiler_entry"),"real controller menu activation loads an M23 world"): return false
	hero=world.hero
	boss=world.registered_boss
	return true

func real_trial_return_checks() -> void:
	stage="actual menu entry and return preserve original bench and inventory"
	if not await make_world(false,true): return
	check(not world.is_boss_trial and world.current_room==1 and world.combat_state.wallet==37 and world.combat_state.capacity==5,"main library loads its preserved normal M22 inventory")
	check(world.gameplay_active and not world.tour_finished and not world.progress.get("preview_departed",false),"a completed old M22 preview reopens for the newly authored boss without clearing real inventory")
	var checkpoint_before: Dictionary=world.checkpoint.duplicate(true)
	hero.hp=4
	hero.energy=55
	if not await walk_to(Vector2(900,1260)): return
	var return_point: Vector2=hero.last_safe_position
	var original_combat: Dictionary=world.combat_state.serialize().duplicate(true)
	if not await activate_menu_action("boss_trial"): return
	check(world.is_boss_trial and hero.hp==6 and hero.energy==99 and world.combat_state.wallet==0,"real menu launches an independent fresh trial loadout")
	var stored: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://compiler_trial_return_m23.json"))
	check(Vector2(float(stored.position[0]),float(stored.position[1])).distance_to(return_point)<1,"trial entry records the actual safe return position")
	var normal_hash:=FileAccess.get_sha256("user://folding_library_m18_preview.json")
	if not await activate_menu_action("trial_return"): return
	check(not world.is_boss_trial and hero.position.distance_to(return_point)<6 and hero.is_on_floor(),"real controller Return restores the supported previous library position")
	check(hero.hp==4 and is_equal_approx(hero.energy,55.0),"real trial return restores previous health and energy")
	check(JSON.parse_string(JSON.stringify(world.checkpoint))==JSON.parse_string(JSON.stringify(checkpoint_before)),"temporary return position does not replace the actual saved bench checkpoint")
	check(JSON.parse_string(JSON.stringify(world.combat_state.serialize()))==JSON.parse_string(JSON.stringify(original_combat)),"return restores exact wallet, capacity, equipment and owned inventory")
	check(FileAccess.get_sha256("user://folding_library_m18_preview.json")==normal_hash,"trial runtime and return do not rewrite the entry-saved normal inventory record")
	check(not FileAccess.file_exists("user://compiler_trial_return_m23.json"),"temporary return record is consumed once")
	record("real_menu_trial_roundtrip",{"actual_controller_buttons":true,"return_position":[return_point.x,return_point.y],"bench_checkpoint":checkpoint_before,"restored_hp":hero.hp,"restored_energy":hero.energy,"restored_wallet":world.combat_state.wallet,"normal_inventory_equal":true})

func run_checks() -> void:
	remember_user_files()
	seed_normal_save_fixture()
	if await make_world(true,false):
		if await begin_trial():
			if "--cheap-only" in OS.get_cmdline_user_args(): await cheap_pressure_probe()
			elif "--pogo-only" in OS.get_cmdline_user_args(): await blind_pogo_probe()
			elif "--settings-only" in OS.get_cmdline_user_args():
				await pause_and_score_checks()
				await real_music_toggle_checks()
				await real_trial_return_checks()
			elif "--release-fight" in OS.get_cmdline_user_args():
				await pause_and_score_checks()
				if await reactive_input_fight():
					await victory_reward_checks()
					await release_sound_checks()
			elif "--fight-only" in OS.get_cmdline_user_args(): await reactive_input_fight()
			else:
				await cheap_pressure_probe()
				if hero.hp<=0 and await actual_loss_retry_checks():
					if await begin_trial():
						await pause_and_score_checks()
						if await reactive_input_fight(): await victory_reward_checks()
				await real_trial_return_checks()
	await dispose_world()
	stage="isolated cleanup"
	check(restore_user_files(),"original normal/trial saves and settings restored byte-for-byte")
	FileAccess.open(REPORT,FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"display_server":DisplayServer.get_name(),"mode_arguments":OS.get_cmdline_user_args(),"checks":checks,"failures":failures,"physics_ticks":physics_ticks,"fight":fight_stats,"damage_taken":battle_damage,"evidence":evidence,"scope":"Actual Input battle after supported trial entrance; no positive injected damage or actor teleport during combat. Normal-save baselines and menu focus are labelled fixtures. A reactive bot is not a human difficulty assessment."},"\t"))
	print("M23 QA REPORT ",REPORT," checks=",checks," failures=",failures.size())
	OS.delay_msec(50)
	await process_frame
	quit(0 if failures.is_empty() else 1)
