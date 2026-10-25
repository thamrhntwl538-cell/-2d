extends SceneTree
## M27 regression tests for effective attack spacing and independently live
## paper sheets. Uses the original hero's shared one-second invulnerability.
const SCENE := "res://scenes/minibosses/archivist_trial_m26.tscn"
const HERO_PATH := "res://scripts/combat/m23_player.gd"
const P1 := ["slam","sweep","pagestorm","shut","tomes","combo3"]
const P2 := ["combo5","redpass","sweep","indexlock","burning","pageflip","pagestorm","finale","tomes","combo3","slam","shut"]
var game: Node2D
var checks: Array[Dictionary] = []
var _source_hashes: Dictionary = {}

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool, label: String, detail: Variant = null) -> void:
	checks.append({"passed":ok,"name":label,"detail":detail})
	print("%s %s" % ["PASS" if ok else "FAIL",label])

func _frames(count: int) -> void:
	for index in range(count): await physics_frame
	await process_frame

func _release_inputs() -> void:
	for action in ["move_left","move_right","look_up","look_down","jump","attack","dash","spell","heal"]:
		if InputMap.has_action(action): Input.action_release(action)

func _reset_fixture(source_phase: int = 1) -> void:
	_release_inputs()
	game.set_physics_process(false)
	game.hero.set_physics_process(false)
	game._release_grab()
	game.hero.set_physics_process(false)
	game.paused = false
	game.gameplay_active = true
	game.encounter_started = true
	game.boss_active = true
	game.is_dead = false
	game.hp = 48
	game.phase = source_phase
	game.phase_pending = false
	game.phase_transition_count = 0
	game.pattern_index = 0
	game.hit_stop_remaining = 0.0
	game.boss_hit_cooldown = 0.0
	game.state = "idle"
	game.state_time = 100.0
	game.reset_ai_intent()
	game.keeper.position = Vector2(1440,617)
	game.keeper.set_playing(true)
	game.hero.hp = 6
	game.hero.energy = 99
	game.hero.invulnerable = 0.0
	game.hero.reset_combat_motion()
	game.hero.position = Vector2(850,620)
	game.hero.movement_bounds = Vector2(774,1916)
	game.hero.fall_limit = 920
	game._start_clip("idle")
	game.singing.stop_for_encounter()

func _paper_fixture(source_phase: int, rage: bool, facing: int, source_u: float) -> Array:
	_reset_fixture(source_phase)
	game.hp = 7 if rage else 48
	game.attack_direction = facing
	game.keeper.set_facing(facing)
	game.state = "attack"
	game._start_clip("pagestorm")
	game.keeper.seek(source_u*2.3)
	game.keeper_sound.seek(source_u*2.3)
	return _papers()

func _papers() -> Array:
	var result: Array = []
	for hit in game._runtime_hitboxes():
		if str(hit.get("kind",""))=="proj": result.append(hit)
	return result

func _paper_for(entries: Array, volley: int, sheet: int = -1) -> Dictionary:
	for item in entries:
		if int(item.get("volley",-1))==volley and (sheet<0 or int(item.get("sheet",-1))==sheet): return item
	return {}

func _put_hero_at(rectangle: Rect2, foot_offset: float = 26.0) -> void:
	game.hero.position = rectangle.get_center()+Vector2(0,foot_offset)
	game.hero.velocity = Vector2.ZERO

func _recorded_start() -> Dictionary:
	return game.get_trial_snapshot().get("attack_start_record",{})

func _inside_band(record: Dictionary) -> bool:
	var band: Dictionary = record.get("band",{})
	var gap := float(record.get("gap",-999))
	return gap>=float(band.get("min",99999))-.01 and gap<=float(band.get("max",-99999))+.01

func _any_overlap(entries: Array, hero_position: Vector2) -> bool:
	var original: Vector2 = game.hero.position
	game.hero.position = hero_position
	var result := false
	for hit in entries:
		for hurt in game.hero.get_hurtboxes():
			if hurt.intersects(hit.rect): result = true
	game.hero.position = original
	return result

func _run() -> void:
	# Parent supplies production changes before this test is executed.
	game = load(SCENE).instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(4)
	_check(game.has_method("_update_approach"),"M27 approach API is present")
	if not game.has_method("_update_approach"):
		await _finish()
		return
	await _test_approach()
	await _test_papers()
	await _finish()

func _test_approach() -> void:
	_reset_fixture(1)
	game.hero.position = Vector2(850,620)
	game.keeper.position = Vector2(1550,617)
	game._next_attack()
	game.set_physics_process(true)
	game.hero.set_physics_process(true)
	await _frames(75)
	_check(game.state=="walk" and game.pending_attack=="slam" and game.pattern_index==0,
		"Far melee keeps approaching beyond 0.9 s without wasting its pending attack",
		{"state":game.state,"gap":absf(game.hero.position.x-game.keeper.position.x),"pattern_index":game.pattern_index})
	for index in range(420):
		await physics_frame
		if game.state=="attack": break
	_check(game.state=="attack" and game.current_animation=="slam" and _inside_band(_recorded_start()),
		"Far melee commits only after entering its own effective strike band",_recorded_start())
	_check(game.pattern_index==1 and game.pending_attack.is_empty(),"Attack order advances exactly once on an actual committed strike")

	_reset_fixture(1)
	game.hero.position = Vector2(900,620)
	game._next_attack()
	game.set_physics_process(true)
	game.hero.set_physics_process(true)
	await _frames(20)
	var before: float = game.keeper.position.x
	game.hero.position = Vector2(1850,620)
	await _frames(10)
	_check(game.state=="walk" and game.keeper.position.x>before and int(game.get_trial_snapshot().get("approach_direction",0))==1,
		"Keeper turns toward a hero crossing behind during approach",game.get_trial_snapshot())

	for source_phase in [1,2]:
		var order: Array = P2 if source_phase==2 else P1
		for name in order:
			for facing in [-1,1]:
				_reset_fixture(source_phase)
				game.pattern_index = order.find(name)
				var band: Dictionary = game.ATTACK_SPACING.get(name,{})
				game.hero.position = game.keeper.position+Vector2(float(band.get("preferred",999))*facing,3)
				game._next_attack()
				var record := _recorded_start()
				_check(game.state=="attack" and game.current_animation==name and _inside_band(record),
					"P%d %s facing %d starts inside its own spacing band" % [source_phase,name,facing],record)
				_check(int(record.get("facing",0))==facing and record.get("target",Vector2.INF)==game.hero.position,
					"P%d %s facing %d captures its target and facing once" % [source_phase,name,facing])
				if source_phase==1 and name=="slam" and facing==-1:
					var locked: Dictionary = record.duplicate(true)
					var fixed_origin: Vector2 = game.keeper.position
					game.hero.position.x = game.keeper.position.x+310
					game.set_physics_process(true)
					game.hero.set_physics_process(true)
					await _frames(20)
					_check(game.state=="attack" and game.attack_direction==-1 and game.keeper.facing==-1,
						"Started staff attack keeps its facing when the hero dodges behind")
					_check(_recorded_start().get("target",Vector2.ZERO)==locked.get("target",Vector2.INF) and game.keeper.position.is_equal_approx(fixed_origin),
						"Started staff attack does not home toward a moving target")

	for side in [-1,1]:
		_reset_fixture(1)
		game.hero.position = Vector2(774 if side<0 else 1916,620)
		game.keeper.position = Vector2(1050 if side<0 else 1650,617)
		game._next_attack()
		game.set_physics_process(true)
		game.hero.set_physics_process(true)
		for index in range(240):
			await physics_frame
			if game.state=="attack": break
		_check(game.state=="attack" and _inside_band(_recorded_start()),
			"Keeper reaches a valid melee band at arena edge %d without walking forever" % side,_recorded_start())

	# A player can move at 300 px/s while the keeper retreats at 105. Staying
	# close must not trap the AI in an infinite range-finding walk at a wall.
	for pressure_case in [{"phase":1,"name":"slam","facing":-1},{"phase":2,"name":"pageflip","facing":1},{"phase":2,"name":"finale","facing":-1}]:
		_reset_fixture(int(pressure_case.phase))
		var order: Array = P2 if int(pressure_case.phase)==2 else P1
		game.pattern_index = order.find(str(pressure_case.name))
		game.hero.position = game.keeper.position+Vector2(int(pressure_case.facing)*45,3)
		var history_start: int = game._animation_history.size()
		game._next_attack()
		game.set_physics_process(true)
		game.hero.set_physics_process(true)
		var responded := false
		for index in range(360):
			var dx: float = game.keeper.position.x-game.hero.position.x
			Input.action_release("move_left")
			Input.action_release("move_right")
			if absf(dx)>43:
				Input.action_press("move_right" if dx>0 else "move_left")
			await physics_frame
			for name in game._animation_history.slice(history_start):
				if name not in ["idle","walk"]: responded = true
			if responded: break
		_release_inputs()
		_check(responded,"Close moving-player pressure on %s cannot cause endless retreat" % pressure_case.name,
			{"state":game.state,"pending":game.pending_attack,"gap":absf(game.hero.position.x-game.keeper.position.x),"keeper":game.keeper.position,"hero":game.hero.position})

	_reset_fixture(1)
	game.pattern_index = P1.find("pagestorm")
	game.hero.position = game.keeper.position+Vector2(40,3)
	game._next_attack()
	_check(game.current_animation=="shut" and bool(_recorded_start().get("reaction",false)),"A hugging hero receives the existing closed-book defense rather than endless retreat")
	_check(game.pattern_index==P1.find("pagestorm"),"A defensive response does not consume the intended ranged attack")
	game.keeper.advance(3.0)
	_check(game.state=="idle" and game.pending_attack=="pagestorm","Defense completion restores the original planned move")
	game.hero.position = game.keeper.position+Vector2(260,3)
	game._next_attack()
	_check(game.current_animation=="pagestorm" and not bool(_recorded_start().get("reaction",true)) and game.pattern_index==P1.find("pagestorm")+1,"The restored ranged attack commits normally once its distance opens")

func _test_papers() -> void:
	var modes := [{"phase":1,"rage":false,"speed":1.0,"name":"P1"},{"phase":2,"rage":false,"speed":1.15,"name":"P2"},{"phase":2,"rage":true,"speed":1.495,"name":"P2 rage"}]
	for mode in modes:
		for facing in [-1,1]:
			for volley in range(3):
				var u: float = float([.4,.54,.68][volley])+.35/2.3
				var papers := _paper_fixture(int(mode.phase),bool(mode.rage),facing,u)
				var selected := _paper_for(papers,volley,6)
				var members := papers.filter(func(item: Dictionary): return int(item.get("volley",-1))==volley)
				var ids: Dictionary = {}
				for member in members: ids[str(member.get("id",""))] = true
				_check(members.size()==7 and ids.size()==7 and not ids.has(""),
					"%s volley %d facing %d retains seven separately identified visible sheets" % [mode.name,volley+1,facing])
				_check(not selected.is_empty(),"Requested later-volley sheet exists independently")
				if selected.is_empty(): continue
				_put_hero_at(selected.rect)
				var only_this_volley := true
				for item in papers:
					if game._hero_overlaps(item.rect) and int(item.get("volley",-1))!=volley: only_this_volley = false
				_check(only_this_volley,"Later volley fixture actually dodged all earlier volleys")
				game._resolve_source_hits()
				var history: Array = game.get_trial_snapshot().get("hit_history",[])
				var last: Dictionary = history[-1] if not history.is_empty() else {}
				_check(game.hero.hp==5 and int(last.get("volley",-1))==volley,
					"%s volley %d facing %d can independently damage after earlier volleys were dodged" % [mode.name,volley+1,facing],last)
				_check(is_equal_approx(game.hero.invulnerable,1.0),"Paper damage keeps the original shared one-second grace")
				_check(is_equal_approx(game.keeper.playback_speed,float(mode.speed)),"Paper animation keeps the source phase/rage timing")

	# The original hero advances its real immunity timer while a fixed test
	# frame holds the papers visible. No cast or paper is consumed on contact.
	var papers := _paper_fixture(1,false,-1,.4+.35/2.3)
	var first := _paper_for(papers,0,6)
	_put_hero_at(first.rect)
	game._resolve_source_hits()
	_check(game.hero.hp==5 and is_equal_approx(game.hero.invulnerable,1.0),"First paper starts shared grace without removing a whole volley")
	game.hero.set_physics_process(true)
	await _frames(20)
	game.hero.set_physics_process(false)
	var second := _paper_for(_papers(),1,6)
	_check(not second.is_empty(),"Second volley remains visible after another sheet hit the hero")
	_put_hero_at(second.rect)
	game._resolve_source_hits()
	_check(game.hero.hp==5 and game.hero.invulnerable>.4,"A second contact during shared immunity correctly causes no extra damage")
	game.hero.set_physics_process(true)
	await _frames(50)
	game.hero.set_physics_process(false)
	_check(game.hero.invulnerable<=0,"The unchanged native hero expires immunity after elapsed physics time")
	_put_hero_at(second.rect)
	game._resolve_source_hits()
	_check(game.hero.hp==4,"A still-visible later sheet damages after shared immunity expires")
	_check(_paper_for(_papers(),1,6).get("id","")==second.get("id","different"),"Invulnerable contact never permanently discards that sheet")

	# A genuine fast relative crossing: hero travels 90 px toward the incoming
	# paper over 0.1 s, within the approved 900 px/s dash speed. Both endpoint
	# snapshots are clear; only continuous collision can register this contact.
	for mode in modes:
		for facing in [-1,1]:
			papers = _paper_fixture(int(mode.phase),bool(mode.rage),facing,.44)
			var middle := _paper_for(papers,0,3)
			var center: Vector2 = middle.rect.get_center()
			var old_hero := center+Vector2(facing*55,70)
			var new_hero := center+Vector2(-facing*35,70)
			game.hero.facing = -facing
			game.hero.position = old_hero
			var starts_clear := not _any_overlap(papers,old_hero)
			game._resolve_source_hits()
			var swept_before: int = int(game.get_trial_snapshot().get("swept_paper_hits",0))
			game.keeper.advance(.1)
			var ends_clear := not _any_overlap(_papers(),new_hero)
			game.hero.position = new_hero
			game._resolve_source_hits(.1)
			_check(starts_clear and ends_clear,"%s facing %d fast-crossing endpoints are both clear" % [mode.name,facing])
			_check(game.hero.hp==5 and int(game.get_trial_snapshot().get("swept_paper_hits",0))==swept_before+1,
				"%s facing %d continuous per-sheet collision catches the actual crossing" % [mode.name,facing],game.get_trial_snapshot().get("hit_history",[]).back())

	# A diagonal's bounding rectangle contains the origin, but its segment
	# does not. This guards against filling empty gaps with merged broad boxes.
	_check(not game._segment_hits_box(Vector2(-50,0),Vector2(0,50),Vector2(5,5)),"Swept solver leaves an empty diagonal corridor harmless")
	_check(game._segment_hits_box(Vector2(-50,-50),Vector2(50,50),Vector2(5,5)),"Swept solver detects a true diagonal crossing")
	_check(not game._segment_hits_box(Vector2(10,-50),Vector2(10,50),Vector2(5,5)),"A parallel paper passing outside a hero box does not damage it")

	# At the keeper's foot pivot, papers on either side are distant. A fresh
	# cast with opposite facing must not sweep old sheets through that center.
	papers = _paper_fixture(1,false,-1,.55)
	game.hero.position = Vector2(1440,620)
	game._resolve_source_hits()
	var old_ids: Array = papers.map(func(item: Dictionary): return str(item.id))
	game.attack_direction = 1
	game.keeper.set_facing(1)
	game._start_clip("pagestorm")
	game.keeper.seek(.55*2.3)
	var new_ids: Array = _papers().map(func(item: Dictionary): return str(item.id))
	game._resolve_source_hits(.016)
	var disjoint := true
	for id in new_ids:
		if id in old_ids: disjoint = false
	_check(disjoint and game.hero.hp==6,"Fresh casts and opposite facings never reuse a paper or create a phantom sweep")

	# Backward/forward scrubbing is a discontinuity, not physical page travel.
	for backwards in [false,true]:
		var old_u := .53 if backwards else .42
		var new_u := .42 if backwards else .53
		var old_pages := _paper_fixture(1,false,1,old_u)
		var old_page := _paper_for(old_pages,0,3)
		game.keeper.seek(new_u*2.3)
		var new_pages := _papers()
		var new_page := _paper_for(new_pages,0,3)
		var candidate: Vector2 = (old_page.rect.get_center()+new_page.rect.get_center())*.5+Vector2(0,70)
		var clear := not _any_overlap(old_pages,candidate) and not _any_overlap(new_pages,candidate)
		game.keeper.seek(old_u*2.3)
		game.hero.position = candidate
		game.reset_hazard_sweep()
		game._resolve_source_hits()
		game.keeper.seek(new_u*2.3)
		game._resolve_source_hits(.016)
		_check(clear and game.hero.hp==6,"A %s seek never turns a clear interval into an attack" % ["backward" if backwards else "forward"])

	_paper_fixture(1,false,-1,.55)
	game.hero.position = Vector2(1440,620)
	game._resolve_source_hits()
	_check(int(game.get_trial_snapshot().get("previous_paper_count",0))>0,"Continuous collision retains live sheets between real physics samples")
	game.set_paused(true)
	_check(int(game.get_trial_snapshot().get("previous_paper_count",-1))==0,"Pausing clears motion samples rather than connecting separate timelines")
	game.set_paused(false)
	game._resolve_source_hits(.016)
	_check(game.hero.hp==6,"Resuming at a clear position never creates phantom paper damage")
	_check(is_equal_approx(float(game._meta.pagestorm.duration),2.3) and int(game._meta.pagestorm.frames)==55,
		"The supplied Page Storm duration and all 55 frames are unchanged")

func _finish() -> void:
	_release_inputs()
	game.set_physics_process(false)
	game.hero.set_physics_process(false)
	game.singing.stop_for_room_exit()
	game.keeper_sound.stop_all()
	game.soundscape.stop_all()
	# A fixed simulation clock can outrun the real audio mixing thread.
	OS.delay_msec(180)
	await _frames(2)
	game.queue_free()
	await _frames(15)
	await create_timer(.2,true,false,true).timeout
	var failed := checks.filter(func(item: Dictionary): return not bool(item.passed))
	var report := {"checks":checks.size(),"passed":checks.size()-failed.size(),"failed":failed.size(),"results":checks}
	var file := FileAccess.open("user://m27_archivist_combat_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("M27 ARCHIVIST COMBAT: %d/%d passed" % [checks.size()-failed.size(),checks.size()])
	quit(0 if failed.is_empty() else 1)
