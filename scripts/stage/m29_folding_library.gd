extends "res://scripts/stage/m28_folding_library.gd"
## One authoritative inventory across the street, its actual interiors and rests.
const Layout29=preload("res://scripts/stage/m29_layouts.gd")
const Hero29=preload("res://scripts/combat/m29_player.gd")
const HUD29=preload("res://scripts/ui/m29_hud.gd")
const Visual29=preload("res://scripts/stage/m29_room_visuals.gd")
const BenchDirector29=preload("res://scripts/stage/m29_bench_director.gd")
const Travel29=preload("res://scripts/stage/m29_journey.gd")
const OUTSIDE_ANCHORS={"market":{"room":4,"position":[1960.0,1260.0]},"bell":{"room":12,"position":[900.0,1260.0]},"archivist":{"room":6,"position":[2620.0,1980.0]}}
var interior_kind:=""
var building_return: Dictionary={}
var bench_director: Node
var _m29_consumed:=false
var _fresh_reset_pending:=false
var _door_guard:=.4
var _door_released:=false
var _bench_saved:=false
var _stand_after_panel:=false
var _bench_definition: Dictionary={}

func _room_layout(id: int) -> Dictionary:
	return Layout29.interior_room(interior_kind) if not interior_kind.is_empty() else Layout29.room(id)
func _all_layouts() -> Array[Dictionary]: return Layout29.all_rooms()
func _create_hero() -> CharacterBody2D: return Hero29.new()
func _create_hud() -> CanvasLayer: return HUD29.new()
func _create_room_visuals() -> Node2D: return Visual29.new()
func save_path() -> String: return Travel29.SAVE_PATH

func _ready() -> void:
	super._ready()
	hero.name="LanternWarden"
	bench_director=BenchDirector29.new()
	add_child(bench_director)
	bench_director.setup(self)
	bench_director.seated.connect(_on_bench_seated)
	bench_director.stood.connect(_on_bench_stood)
	bench_director.bind_room()
	if _fresh_reset_pending:
		_save()
	if _m29_consumed:
		_save()
		Travel29.remove_session()
	_update_hud()

func _register_inputs() -> void:
	super._register_inputs()
	if not InputMap.has_action("bench_inventory"): InputMap.add_action("bench_inventory")
	InputMap.action_erase_events("bench_inventory")
	for key in [KEY_I,KEY_TAB]:
		var event:=InputEventKey.new()
		event.physical_keycode=key
		InputMap.action_add_event("bench_inventory",event)
	var event:=InputEventJoypadButton.new()
	event.button_index=JOY_BUTTON_Y
	InputMap.action_add_event("bench_inventory",event)

func _restore_save() -> void:
	if get_tree().has_meta("m29_fresh_restart"):
		get_tree().remove_meta("m29_fresh_restart")
		_fresh_reset_pending=true
		return
	if not FileAccess.file_exists(save_path()) and FileAccess.file_exists(Journey.SAVE_PATH):
		var record: Variant=JSON.parse_string(FileAccess.get_file_as_string(Journey.SAVE_PATH))
		if record is Dictionary and int(record.get("version",0))==18:
			Travel29.atomic_write(save_path(),record)
			var previous: Dictionary=Journey.read_session()
			if not previous.is_empty() and _valid_anchor(previous.origin) and _valid_anchor(previous.checkpoint):
				previous.schema=29
				Travel29.atomic_write(Travel29.SESSION_PATH,previous)
	super._restore_save()
	if not FileAccess.file_exists(save_path()): return
	var record: Variant=JSON.parse_string(FileAccess.get_file_as_string(save_path()))
	if not record is Dictionary: return
	var saved: Variant=record.get("checkpoint",{})
	if saved is Dictionary and _valid_anchor(saved):
		checkpoint=saved.duplicate(true)
		interior_kind=str(saved.get("interior",""))
		building_return=saved.get("outside",{}).duplicate(true) if saved.get("outside",{}) is Dictionary else {}
	_normalize_locations()

func _normalize_locations() -> void:
	if progress.get("m28_archivist_pile",{}) is Dictionary and not progress.get("m28_archivist_pile",{}).is_empty():
		progress.m29_archivist_pile=progress.m28_archivist_pile.duplicate(true)
		progress.erase("m28_archivist_pile")
		progress.m29_death_location="archivist"
	var scopes: Dictionary=progress.get("m29_reward_locations",{}).duplicate(true) if progress.get("m29_reward_locations",{}) is Dictionary else {}
	if progress.get("currency_rewards",{}).has("miniboss:bell_warden"): scopes["miniboss:bell_warden"]="bell"
	progress.m29_reward_locations=scopes
	if not progress.has("m29_death_location") and int(combat_state.death_drop.get("room",0))==12 and Travel29.valid_point(combat_state.death_drop.get("position")):
		var at: Array=combat_state.death_drop.position
		if float(at[0])>=BELL_SPEC.arena_rect.position.x and float(at[0])<=BELL_SPEC.arena_rect.end.x and absf(float(at[1])-BELL_SPEC.floor_y)<180:
			progress.m29_death_location="bell"

func _valid_anchor(anchor: Dictionary) -> bool:
	if not Travel29.valid_point(anchor.get("position")): return false
	var id:=int(anchor.get("room",0))
	if id<1 or id>15: return false
	var kind:=str(anchor.get("interior",""))
	if kind not in ["","market","bell"]: return false
	var room: Dictionary=Layout29.room(id) if kind.is_empty() else Layout29.interior_room(kind)
	if not kind.is_empty() and int(room.get("id",0))!=id: return false
	return Rect2(Vector2.ZERO,room.size).has_point(Vector2(float(anchor.position[0]),float(anchor.position[1])))

func _load_room(id: int, spawn_name: String="left", exact_position: Vector2=Vector2.INF) -> void:
	if is_instance_valid(bench_director): bench_director.cancel(true)
	super._load_room(id,spawn_name,exact_position)
	for entry in objects:
		if str(entry.definition.get("kind","")) in ["building_portal","interior_exit"]: entry.node.self_modulate.a=0
	if is_instance_valid(bench_director): bench_director.bind_room()

func _spawn_bell() -> void:
	if interior_kind=="bell": super._spawn_bell()

func _check_compiler_entry() -> void:
	if interior_kind=="bell": super._check_compiler_entry()

func _physics_process(delta: float) -> void:
	_door_guard=maxf(0,_door_guard-delta)
	if not Input.is_action_pressed("interact") and not Input.is_action_pressed("look_up"): _door_released=true
	if is_instance_valid(bench_director) and bench_director.is_busy():
		if Input.is_action_just_pressed("switch_language"):
			_on_ui_action("language","en" if hud.language=="ar" else "ar")
		if bench_director.is_seated() and not hud.panel_open and Input.is_action_just_pressed("bench_inventory"):
			_open_panel("bench")
		_update_bench_hint()
		return
	if gameplay_active and not boss_active and Input.is_action_just_pressed("look_up") and _can_door_input() and _door_actor_ready():
		var action:=nearest_action()
		if str(action.get("type",""))=="object" and str(action.entry.definition.get("kind","")) in ["building_portal","interior_exit"]:
			_activate(action.entry)
			return
		if str(action.get("type",""))=="exit" and can_use_exit(action.exit):
			_begin_transition(action.exit)
			return
	super._physics_process(delta)

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(bench_director) and bench_director.is_busy(): gameplay_active=false

func _can_door_input() -> bool: return _door_guard<=0 and _door_released and not transitioning

func _door_actor_ready() -> bool:
	if not is_instance_valid(hero) or not hero.is_on_floor() or hero.hp<=0 or hero.hurt_time>0 or hero.dash_time>0 or hero.active_strike_time>0 or hero.healing: return false
	for action in ["attack","spell","jump"]:
		if Input.is_action_just_pressed(action): return false
	return not Input.is_action_pressed("heal")

func _begin_transition(exit: Dictionary) -> void:
	if not _can_door_input() or not _door_actor_ready(): return
	_door_released=false
	_door_guard=.4
	await super._begin_transition(exit)

func _activate(entry: Dictionary) -> void:
	var definition: Dictionary=entry.get("definition",entry)
	match str(definition.get("kind","")):
		"bench":
			if boss_active or transitioning or not _requirements_met(definition.get("requires",[]),environment_preview): return
			if is_instance_valid(bench_director) and bench_director.begin(definition):
				_bench_saved=false
				if is_instance_valid(arrival_title): arrival_title.dismiss()
				_bench_definition=definition
				at_bench=false
				_set_paused(true)
				_update_bench_hint()
			return
		"building_portal":
			if not _can_door_input() or boss_active or not _door_actor_ready(): return
			var destination:=str(definition.get("destination",""))
			if destination=="archivist": _enter_archive(definition)
			elif destination in ["market","bell"]:
				if destination=="bell" and (not hero.has_blade or not combat_state.dash_owned):
					_tip("أحضر سلاحك واندفاع الفانوس قبل دخول مشغل الجرس.","Bring your blade and lantern dash before entering the bindery.")
					return
				_enter_interior(destination,definition.pos)
			return
		"interior_exit":
			if _can_door_input() and not boss_active and _door_actor_ready(): _leave_interior(definition.pos)
			return
	super._activate(entry)

func _object_label(definition: Dictionary) -> String:
	if str(definition.get("kind",""))=="building_portal":
		return ("دخول · " if hud.language=="ar" else "Enter · ")+str(definition.get("title_ar" if hud.language=="ar" else "title_en",""))
	if str(definition.get("kind",""))=="interior_exit": return "الخروج إلى المكتبة" if hud.language=="ar" else "Return to the library"
	return super._object_label(definition)

func _enter_interior(kind: String, doorway: Vector2=Vector2.INF) -> void:
	if transitioning or not interior_kind.is_empty(): return
	building_return=OUTSIDE_ANCHORS[kind].duplicate(true)
	await _change_context(kind,int(building_return.room),Vector2.INF,doorway)

func _leave_interior(doorway: Vector2=Vector2.INF) -> void:
	if interior_kind.is_empty() or transitioning: return
	var anchor: Dictionary=building_return if _valid_anchor(building_return) else OUTSIDE_ANCHORS[interior_kind]
	await _change_context("",int(anchor.room),Vector2(float(anchor.position[0]),float(anchor.position[1])),doorway)

func _change_context(kind: String, room_id: int, point: Vector2, doorway: Vector2=Vector2.INF) -> void:
	transitioning=true
	_door_released=false
	_door_guard=.4
	hero.velocity=Vector2.ZERO
	hero.reset_combat_motion()
	hero._update_animation()
	play_sfx("room_transition")
	if not await _approach_door(doorway):
		transitioning=false
		_set_paused(false)
		return
	_set_paused(true)
	if is_instance_valid(arrival_title): arrival_title.dismiss()
	if is_instance_valid(fade): await create_tween().tween_property(fade,"color:a",1.0,transition_seconds).finished
	interior_kind=kind
	_load_room(room_id,"left",point)
	hero.facing=1
	hero._update_animation()
	hero.combat_model.set_motion("idle",0)
	_save()
	if is_instance_valid(fade): await create_tween().tween_property(fade,"color:a",0.0,transition_seconds).finished
	transitioning=false
	_set_paused(false)
	_update_hud()

func _approach_door(point: Vector2) -> bool:
	if point==Vector2.INF: return true
	if absf(hero.position.x-point.x)>118 or absf(hero.position.y-point.y)>5: return false
	var leases: Array[Dictionary]=[]
	var bodies: Array=[hero]
	for body in active_room.find_children("*","CollisionObject2D",true,false):
		if int(body.collision_layer)&1: bodies.append(body)
	for body in bodies:
		leases.append({"body":body,"mode":body.disable_mode})
		body.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	_set_paused(true)
	hero.begin_bench_lock()
	var age:=0.0
	var successful:=true
	while absf(hero.position.x-point.x)>.5:
		var dt:=clampf(get_process_delta_time(),.001,.05)
		age+=dt
		var error: float=point.x-hero.position.x
		var motion:=Vector2(clampf(error,-240*dt,240*dt),0)
		var next: Vector2=hero.position+motion
		var ray:=PhysicsRayQueryParameters2D.create(next-Vector2(0,3),next+Vector2(0,8),1)
		if age>.65 or get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			successful=false
			break
		var previous: float=hero.position.x
		var contact=hero.move_and_collide(motion)
		hero.set_bench_walk(motion.x/dt,age)
		if contact!=null and absf(hero.position.x-previous)<absf(motion.x)*.5:
			successful=false
			break
		await get_tree().process_frame
	hero.end_bench_lock()
	for lease in leases:
		var body=lease.body
		if is_instance_valid(body): body.disable_mode=int(lease.mode)
	return successful

func _on_bench_seated(definition: Dictionary) -> void:
	if transitioning or _respawning or not is_instance_valid(bench_director) or not bench_director.is_seated() or not _physically_at_bench(): return
	if is_instance_valid(arrival_title): arrival_title.dismiss()
	var point: Vector2=definition.get("checkpoint_spawn",definition.pos+Vector2(64,0))
	checkpoint={"room":current_room,"position":[point.x,point.y],"interior":interior_kind,"bench_id":str(definition.id),"outside":building_return.duplicate(true)}
	hero.hp=hero.max_hp
	# Rest restores health; glow is earned from valid combat hits.
	at_bench=true
	progress.m29_rest_serial=int(progress.get("m29_rest_serial",0))+1
	_save()
	var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string(save_path())) if FileAccess.file_exists(save_path()) else null
	_bench_saved=saved is Dictionary and int(saved.get("progress",{}).get("m29_rest_serial",-1))==int(progress.m29_rest_serial)
	play_sfx("bench")
	_update_hud()
	_update_bench_hint()

func _on_bench_stood() -> void:
	at_bench=false
	_bench_definition={}
	_bench_saved=false
	if not transitioning and not _respawning and is_instance_valid(hero) and hero.is_inside_tree() and hero.hp>0: _set_paused(false)
	_update_bench_hint()

func _update_bench_hint() -> void:
	if is_instance_valid(hud) and hud.has_method("update_bench_rest"): hud.update_bench_rest(_panel_context())

func _panel_context() -> Dictionary:
	var context:=super._panel_context()
	var state: Dictionary=bench_director.get_snapshot() if is_instance_valid(bench_director) else {"state":"idle"}
	var seated: bool=is_instance_valid(bench_director) and bench_director.is_seated()
	context.bench={"state":state.get("state","idle"),"seated":seated,"can_equip":seated,"saved":_bench_saved,"name_ar":_bench_definition.get("title_ar","استراحة الفانوس"),"name_en":_bench_definition.get("title_en","Lantern Rest")}
	context.m29=true
	context.interior=interior_kind
	return context

func combat_hud_context() -> Dictionary:
	var context:=super.combat_hud_context()
	context.at_bench=is_instance_valid(bench_director) and bench_director.is_seated() and _physically_at_bench()
	return context

func _open_panel(kind: String) -> void:
	if kind in ["bench","fitils"]:
		if not is_instance_valid(bench_director) or not bench_director.is_seated(): return
		_panel_definition=_bench_definition
		_set_paused(true)
		hud.open_panel("bench",_panel_context())
		return
	super._open_panel(kind)

func _panel_close_finished() -> void:
	if is_instance_valid(bench_director) and bench_director.is_busy():
		panel_closing=false
		awaiting_action=""
		at_bench=bench_director.is_seated()
		if _stand_after_panel:
			_stand_after_panel=false
			bench_director.request_stand()
		_update_bench_hint()
		return
	super._panel_close_finished()

func _on_ui_action(action: String, value: Variant=null) -> void:
	if action in ["equip_fitil","unequip_fitil"]:
		var permitted: bool=not panel_closing and is_instance_valid(bench_director) and bench_director.is_seated() and hud.panel_open and hud.current_panel=="bench" and _physically_at_bench()
		var changed: bool=combat_state.equip(str(value),permitted) if action=="equip_fitil" else combat_state.unequip(str(value),permitted)
		if changed: _save()
		if hud.panel_open and hud.current_panel=="bench": hud.refresh_panel(_panel_context())
		_update_hud()
		return
	if action=="bench_close":
		_close_panel()
		return
	if action=="bench_stand":
		_stand_after_panel=true
		if hud.panel_open: _close_panel()
		elif is_instance_valid(bench_director):
			_stand_after_panel=false
			bench_director.request_stand()
		return
	super._on_ui_action(action,value)

func _enter_archive(definition: Dictionary) -> void:
	if transitioning or boss_active or _respawning or current_room!=6 or not interior_kind.is_empty(): return
	if not hero.has_blade or not combat_state.dash_owned:
		_tip("أحضر سلاحك وتعلّم اندفاع الفانوس قبل فتح باب الخزنة.","Bring your blade and learn the lantern dash before opening the vault.")
		return
	_save()
	var session: Dictionary={"schema":29,"boss":"archivist","status":"entered","origin":OUTSIDE_ANCHORS.archivist.duplicate(true),"checkpoint":checkpoint.duplicate(true),"progress":progress.duplicate(true),"combat":combat_state.serialize(),"hp":hero.hp,"energy":hero.energy,"language":hud.language,"journal_cursor":hud.journal_cursor.duplicate(true)}
	if not Travel29.atomic_write(Travel29.SESSION_PATH,session): return
	transitioning=true
	if not await _approach_door(definition.get("pos",Vector2(2710,1980))):
		transitioning=false
		_set_paused(false)
		Travel29.remove_session()
		return
	_set_paused(true)
	if is_instance_valid(fade): await create_tween().tween_property(fade,"color:a",1.0,transition_seconds).finished
	var result:=get_tree().change_scene_to_file(Travel29.ARCHIVE_SCENE)
	if result!=OK:
		transitioning=false
		_set_paused(false)
		Travel29.remove_session()

func _read_trial_return() -> void:
	if get_tree().has_meta("m28_studio_anchor"):
		var anchor: Variant=get_tree().get_meta("m28_studio_anchor")
		get_tree().remove_meta("m28_studio_anchor")
		if anchor is Dictionary and _valid_anchor(anchor):
			_return_record=anchor
			interior_kind=str(anchor.get("interior",""))
			building_return=anchor.get("outside",{}).duplicate(true) if anchor.get("outside",{}) is Dictionary else {}
	var session:=Travel29.read_session()
	if session.is_empty() or not _valid_anchor(session.origin) or not _valid_anchor(session.checkpoint): return
	progress.merge(session.progress,true)
	combat_state.restore(session.combat)
	_normalize_locations()
	CurrencyLedger.sanitize(progress)
	Shop.sanitize(progress,combat_state)
	var status:=str(session.status)
	if status=="victory" and _valid_archive_receipt(session):
		progress.miniboss_archivist_defeated=true
		combat_state.increase_capacity("archivist_capacity",1)
		CurrencyLedger.create_reward(progress,"miniboss:archivist",6,Vector2(2670,1980),60)
	var destination: Dictionary=session.checkpoint if status=="death" else session.origin
	interior_kind=str(destination.get("interior",""))
	building_return=destination.get("outside",{}).duplicate(true) if destination.get("outside",{}) is Dictionary else {}
	_return_record={"room":int(destination.room),"position":destination.position.duplicate(),"hp":6 if status=="death" else clampi(int(session.get("hp",6)),1,6),"energy":clampf(float(session.get("energy",0)),0,99)}
	checkpoint=session.checkpoint.duplicate(true)
	_door_guard=.4
	_door_released=false
	_m29_consumed=true

func _spawn_death_drop() -> void:
	if progress.get("m29_archivist_pile",{}) is Dictionary and not progress.get("m29_archivist_pile",{}).is_empty(): return
	if str(progress.get("m29_death_location",""))!=interior_kind: return
	super._spawn_death_drop()

func on_player_death() -> void:
	progress.erase("m29_archivist_pile")
	progress.m29_death_location=interior_kind
	if is_instance_valid(bench_director): bench_director.cancel(true)
	super.on_player_death()

func _respawn() -> void:
	await get_tree().create_timer(.38).timeout
	_set_paused(true)
	interior_kind=str(checkpoint.get("interior",""))
	building_return=checkpoint.get("outside",{}).duplicate(true) if checkpoint.get("outside",{}) is Dictionary else {}
	_load_room(int(checkpoint.room),"left",Vector2(float(checkpoint.position[0]),float(checkpoint.position[1])))
	hero.hp=hero.max_hp
	hero.invulnerable=1.2
	_respawning=false
	_set_paused(false)
	_update_hud()

func _reward_context(identity: String) -> String:
	var scopes: Variant=progress.get("m29_reward_locations",{})
	return str(scopes.get(identity,"")) if scopes is Dictionary else ""

func _spawn_room_coins() -> void:
	for definition in CurrencyLedger.room_pending(progress,current_room):
		if _reward_context(str(definition.reward_id))==interior_kind: _spawn_coin_definition(definition)

func _issue_coin_reward(identity: String, point: Vector2, amount: int) -> void:
	var scopes: Dictionary=progress.get("m29_reward_locations",{}).duplicate(true) if progress.get("m29_reward_locations",{}) is Dictionary else {}
	if not scopes.has(identity): scopes[identity]=interior_kind
	progress.m29_reward_locations=scopes
	super._issue_coin_reward(identity,point,amount)

func collect_world_coin(definition: Dictionary) -> bool:
	return super.collect_world_coin(definition) if _reward_context(str(definition.get("reward_id","")))==interior_kind else false

func _enter_boss_trial() -> void:
	_save()
	transitioning=true
	if is_instance_valid(bench_director): bench_director.cancel(true,"studio")
	var at: Vector2=hero.last_safe_position
	get_tree().set_meta("m28_studio_anchor",{"room":current_room,"position":[at.x,at.y],"hp":hero.hp,"energy":hero.energy,"interior":interior_kind,"outside":building_return.duplicate(true)})
	get_tree().set_meta("m28_studio_return",Travel29.WORLD_SCENE)
	get_tree().change_scene_to_file(CATALOG_SCENE)

func restart_stage() -> void:
	Travel29.remove_session()
	if FileAccess.file_exists(save_path()): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path()))
	get_tree().set_meta("m29_fresh_restart",true)
	get_tree().reload_current_scene()

func _exit_tree() -> void:
	if is_instance_valid(bench_director): bench_director.cancel(true,"world_exit")
	super._exit_tree()

func get_m29_world_snapshot() -> Dictionary:
	return {"room":current_room,"interior":interior_kind,"return_anchor":building_return.duplicate(true),"checkpoint":checkpoint.duplicate(true),"hp":hero.hp,"energy":hero.energy,"wallet":combat_state.wallet,"boss_active":boss_active,"registered_boss":is_instance_valid(registered_boss),"bench":bench_director.get_snapshot() if is_instance_valid(bench_director) else {},"bench_saved":_bench_saved,"door_guard":_door_guard,"door_released":_door_released,"save_path":save_path()}
