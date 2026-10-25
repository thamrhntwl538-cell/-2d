extends SceneTree
## Native integration: actual hero inputs plus every supplied attack in both
## facings, with visual-bound hazards, guard, phase/death and voice lifecycle.
const SCENE := "res://scenes/minibosses/archivist_trial_m26.tscn"
var checks: Array[Dictionary] = []
var game: Node2D

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool, name: String, detail: Variant = null) -> void:
	checks.append({"passed":ok,"name":name,"detail":detail})
	print("%s %s" % ["PASS" if ok else "FAIL",name])

func _frames(count: int) -> void:
	for i in range(count): await physics_frame
	await process_frame

func _key(code: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(2)
	press.pressed = false
	Input.parse_input_event(press)
	await _frames(2)

func _fixture(name: String, source_phase: int, u: float, facing: int) -> void:
	game.set_physics_process(false)
	game.hero.set_physics_process(false)
	game.gameplay_active = true
	game.paused = false
	game.hero.hp = 6
	game.hero.invulnerable = 0.0
	game.hero.dash_time = 0.0
	game.hero.hurt_time = 0.0
	game.hit_stop_remaining = 0.0
	game.is_dead = false
	game.hp = 48
	game.encounter_started = true
	game.phase = source_phase
	game.phase_pending = false
	game.state = "attack"
	game.attack_direction = facing
	game.keeper.position = Vector2(1440,617)
	game.keeper.set_playing(true)
	game.keeper.set_facing(facing)
	game._release_grab()
	game._start_clip(name)
	game.keeper.seek(float(game._meta[name].duration)*u)
	game.keeper_sound.seek(float(game._meta[name].duration)*u)

func _run() -> void:
	game = load(SCENE).instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(12)
	_check(game.hero.hp==6 and game.hp==48,"Isolated trial starts at six lanterns and configured 48 HP")
	_check(game.singing.is_singing() and not game.encounter_started,"Keeper sings before encounter")
	_check(game.singing.player.get_parent()==game.keeper and game.singing.listener.get_parent()==game.hero,"Emitter belongs to enemy body; listener belongs to hero")
	var far: float = game.singing.get_distance_gain_db()
	game.hero.position.x = 1000
	await _frames(3)
	var near: float = game.singing.get_distance_gain_db()
	_check(near>far+9.0 and game.singing.is_singing(),"Approach increases positional voice before entering combat",{"far_db":far,"near_db":near})
	await _key(KEY_P)
	_check(game.paused and not game.singing.is_singing(),"Actual P input pauses both movement and singing")
	await _key(KEY_P)
	_check(not game.paused and game.singing.is_singing(),"Actual P resumes the same singing encounter")
	Input.action_press("move_right")
	for i in range(90):
		await physics_frame
		if game.encounter_started: break
	Input.action_release("move_right")
	await _frames(3)
	_check(game.encounter_started and not game.singing.is_singing() and game.singing.player.stream==null,"Actual walking reaches enemy, synchronously cutting song")
	_check(game.hero.position.distance_to(game.keeper.position)<245,"Encounter starts only near the singing enemy")
	_check(game.current_animation=="idle" and game.state=="intro","Visible singer remains present at combat entry")
	_check(not game.boss_display.visible and not game.caption.visible and not game.message.visible,"Only upper-left vitals remain visible in combat")
	game.hero.position.x = 900
	await _frames(8)
	_check(not game.singing.start_dormant() and game.singing.player.stream==null,"Walking away cannot restart the encounter song")

	# Actual unchanged hero sword input must reach the imported actor and award
	# exactly one hit and one reserve gain for the same strike serial.
	game.set_physics_process(false)
	game.state = "idle"
	game.state_time = 100
	game._start_clip("idle")
	game.hero.position = game.keeper.position+Vector2(-95,3)
	game.hero.facing = 1
	game.hero.energy = 0
	game.hero.reset_combat_motion()
	game.boss_hit_cooldown = 0
	game.gameplay_active = true
	var hp_before: int = game.hp
	Input.action_press("attack")
	await _frames(2)
	Input.action_release("attack")
	await _frames(10)
	_check(game.hp==hp_before-1 and is_equal_approx(game.hero.energy,11.0),"Real J/attack timeline deals one melee hit and grants 11 reserve",{"hp":game.hp,"energy":game.hero.energy})
	_check(game.hero.hit_targets.size()==1,"One strike cannot repeatedly damage the same boss")
	game.hit_stop_remaining = 0
	game.gameplay_active = true
	await _frames(24)
	game.state = "idle"
	game._start_clip("idle")
	game.hero.position = game.keeper.position+Vector2(0,-185)
	game.hero.energy = 0
	game.hero.reset_combat_motion()
	game.hero.air_dash_used = true
	game.boss_hit_cooldown = 0
	hp_before = game.hp
	await _frames(2) # Refresh the native floor contact after the airborne fixture.
	Input.action_press("look_down")
	Input.action_press("attack")
	await _frames(2)
	Input.action_release("attack")
	await _frames(8)
	Input.action_release("look_down")
	_check(game.hp==hp_before-1 and game.hero.velocity.y<0 and not game.hero.air_dash_used,"Actual airborne downward slash pogo-bounces and refreshes air dash",{"hp":game.hp,"vy":game.hero.velocity.y})
	game.hit_stop_remaining = 0
	game.gameplay_active = true
	game.hero.set_physics_process(false)

	var active_points := {"slam":.50,"sweep":.48,"shut":.82,"pagestorm":.53,"tomes":.61,"combo3":.23,"combo5":.16,"redpass":.69,"indexlock":.55,"burning":.65,"pageflip":.63,"finale":.45}
	for source_phase in [1,2]:
		var order: Array = game.P1_ORDER if source_phase==1 else game.P2_ORDER
		for name in order:
			for facing in [-1,1]:
				_fixture(name,source_phase,float(active_points[name]),facing)
				var boxes: Array = game._runtime_hitboxes()
				var rendered: Rect2 = game.keeper.get_snapshot().draw_frame_rect
				rendered.position -= Vector2(380,680)
				_check(not boxes.is_empty(),"P%d %s facing %d has a visible active collider" % [source_phase,name,facing])
				if boxes.is_empty(): continue
				var box: Rect2 = boxes[0].rect
				game.hero.position = box.get_center()+Vector2(0,26)
				game._resolve_source_hits()
				if name=="finale":
					_check(game._grabbed,"Final chapter catches only within its visible grab ring (%d)" % facing)
					game._on_source_event("slam_damage")
					_check(game.hero.hp==4,"Caught hero receives the authored slam at its event (%d)" % facing)
					game._release_grab()
				else:
					_check(game.hero.hp<6,"P%d %s facing %d actually damages an overlapping hero" % [source_phase,name,facing])
				_fixture(name,source_phase,.025,facing)
				_check(game._runtime_hitboxes().is_empty(),"P%d %s facing %d wind-up has no premature damage" % [source_phase,name,facing])
				var all_inside := true
				for hit in boxes:
					var source: Rect2 = hit.source_rect
					all_inside = all_inside and rendered.encloses(source)
				_check(all_inside,"P%d %s facing %d hazards remain inside current rendered art" % [source_phase,name,facing])

	_fixture("shut",1,.40,-1)
	game.boss_hit_cooldown = 0
	_check(not game.damage_boss(1,"melee") and game.hp==48 and game._guard_block_count>0,"Closed book guard blocks actual incoming damage")
	_fixture("p2tr",2,.30,-1)
	game.state = "transform"
	_check(not game.damage_boss(2,"spell"),"Transformation invulnerability prevents damage during source protected interval")
	_fixture("pageflip",2,.30,-1)
	_check(not game.damage_boss(2,"spell"),"Vanished page-flip actor is untargetable")
	_fixture("sweep",1,.1,-1)
	game.hp = 25
	game.boss_hit_cooldown = 0
	game.phase_transition_count = 0
	_check(game.damage_boss(1,"spell") and game.phase_pending and game.phase==1,"50% damage queues transformation until current attack finishes")
	game.keeper.advance(10)
	_check(game.phase==2 and game.current_animation=="p2tr" and game.phase_transition_count==1,"Exactly one source transformation starts after attack completion")
	game.keeper.advance(4)
	game.hp = 20
	game._start_clip("slam")
	_check(is_equal_approx(game.keeper.playback_speed,1.15),"Phase-two ordinary attacks run at source 1.15 multiplier")
	game.hp = 7
	game._start_clip("slam")
	_check(game.rage_active and is_equal_approx(game.keeper.playback_speed,1.495),"Below 15% HP the next clip uses source 1.15 x 1.3 rage speed")
	_check(is_equal_approx(game.keeper_sound.playback_speed,game.keeper.playback_speed),"Animation and sound-event clocks share phase/rage speed")
	game.hp = 1
	game.boss_hit_cooldown = 0
	game.gameplay_active = true
	game.state = "idle"
	game._start_clip("idle")
	_check(game.damage_boss(1,"spell") and game.is_dead and game.current_animation=="death","Defeat plays the supplied last-page death animation")
	game.keeper.advance(5)
	_check(game.state=="victory" and game.gate_open and not game.singing.is_singing(),"Death completion opens gates and leaves singing latched silent")

	# Real restart event reloads this isolated scene; no library save mutation.
	game.set_physics_process(true)
	await _key(KEY_R)
	game = current_scene
	await _frames(8)
	_check(game.hp==48 and game.hero.hp==6 and game.singing.is_singing() and not game.encounter_started,"Actual R restarts a fresh isolated encounter and singing")
	game.set_physics_process(false)
	game.hero.set_physics_process(false)
	game.singing.stop_for_room_exit()
	game.keeper_sound.stop_all()
	game.soundscape.stop_all()
	game.queue_free()
	await _frames(15)
	await create_timer(.2,true,false,true).timeout
	var failed := checks.filter(func(check: Dictionary): return not bool(check.passed))
	var report := {"checks":checks.size(),"passed":checks.size()-failed.size(),"failed":failed.size(),"results":checks}
	var file := FileAccess.open("user://m26_archivist_trial_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("M26 ARCHIVIST TRIAL: %d/%d passed" % [checks.size()-failed.size(),checks.size()])
	quit(0 if failed.is_empty() else 1)
