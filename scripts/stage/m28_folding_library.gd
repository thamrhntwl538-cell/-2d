extends "res://scripts/stage/m24_folding_library.gd"
## The approved fifteen-room library, its real encounters, market and optional
## movement routes now share one journey and one durable inventory.
const M28Layouts=preload("res://scripts/stage/m28_layouts.gd")
const M28Hero=preload("res://scripts/combat/m28_player.gd")
const M28HUD=preload("res://scripts/ui/m28_hud.gd")
const M28Visuals=preload("res://scripts/stage/m28_room_visuals.gd")
const EnvironmentDirector=preload("res://scripts/stage/m28_environment_director.gd")
const Shop=preload("res://scripts/shop/m28_shop.gd")
const Journey=preload("res://scripts/stage/m28_journey.gd")
const ARCHIVE_PORTAL_ID := "archivist_vault_portal"
const ARCHIVE_PORTAL_POINT := Vector2(2710,1980)
const CATALOG_SCENE := "res://scenes/minibosses/archivist_reference_m26.tscn"
var environment_director: Node2D
var shop_error := ""
var _journey_consumed := false

func _room_layout(id: int) -> Dictionary: return M28Layouts.room(id)
func _all_layouts() -> Array[Dictionary]: return M28Layouts.all_rooms()
func _create_hero() -> CharacterBody2D: return M28Hero.new()
func _create_hud() -> CanvasLayer: return M28HUD.new()
func _create_room_visuals() -> Node2D: return M28Visuals.new()
func save_path() -> String: return Journey.SAVE_PATH

func _ready() -> void:
	environment_preview=true
	is_boss_trial=false
	super._ready()
	hero.name="LanternWarden_M28"
	Shop.sanitize(progress,combat_state)
	if _journey_consumed:
		_save()
		Journey.remove_session()
	_update_hud()

func _restore_save() -> void:
	# Copy a prior exploration checkpoint once; never rewrite its original file.
	if not FileAccess.file_exists(save_path()) and FileAccess.file_exists(PREVIEW_SAVE_FILE):
		var old: Variant=JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_SAVE_FILE))
		if old is Dictionary and int(old.get("version",0))==18 and bool(old.get("environment_preview",false)):
			Journey.atomic_write(save_path(),old)
	super._restore_save()
	if bool(progress.get("preview_bell_defeated",false)):
		progress.miniboss_bell_defeated=true
	progress.preview_departed=false
	Shop.sanitize(progress,combat_state)

func _load_room(id: int, spawn_name: String="left", exact_position: Vector2=Vector2.INF) -> void:
	super._load_room(id,spawn_name,exact_position)
	if current_room==BELL_ROOM and is_instance_valid(boss_arena):
		# The painting replaces only the old arena's flat edge folios.
		# Children retain their gate drawing, locking and native collisions.
		boss_arena.self_modulate=Color(1,1,1,0)
	# Landmark art owns these facades; keep the real interaction nodes active
	# without drawing their inherited generic terminal underneath the doorway.
	for entry in objects:
		if str(entry.definition.get("kind","")) in ["shop","market","boss_portal"]:
			entry.node.self_modulate.a=0.0
	environment_director=EnvironmentDirector.new()
	environment_director.name="AuthoredLibraryChallenges"
	active_room.add_child(environment_director)
	environment_director.setup(self,data)

func _compiler_flag() -> String: return "miniboss_bell_defeated"

func can_use_exit(exit: Dictionary) -> bool:
	if boss_active or tour_finished or bool(progress.get("world1_departed",false)): return false
	# Area15 is an exploration threshold. The selected final boss is not yet
	# authored, so reaching this room never writes a fabricated boss receipt.
	if current_room==14 and int(exit.get("target",0))==15: return true
	return _requirements_met(exit.get("requires",[]),bool(exit.get("combat_preview",false)))

func _request_departure() -> void:
	if current_room!=15: return
	_tip("بوابة نائم الرفوف لم تُفتح بعد. يمكنك متابعة استكشاف المكتبة ومواجهة حارسيها.","The Sleeping Shelf's threshold remains sealed. You can keep exploring the library and challenge its two keepers.")

func _confirm_departure() -> void:
	_request_departure()

func _activate(entry: Dictionary) -> void:
	var definition: Dictionary=entry.get("definition",entry)
	match str(definition.get("kind","")):
		"shop","market":
			shop_error=""
			_panel_definition=definition
			_open_panel("shop")
			return
		"boss_portal":
			_enter_archive(definition)
			return
	super._activate(entry)

func _panel_context() -> Dictionary:
	var context:=super._panel_context()
	context.shop_error=shop_error
	context.shop_feedback=shop_error
	context.m28=true
	return context

func _on_ui_action(action: String, value: Variant=null) -> void:
	if action=="shop_buy":
		if panel_closing or not hud.panel_open or hud.current_panel!="shop" or not _at_market(): return
		var result: Dictionary=Shop.purchase(progress,combat_state,str(value))
		shop_error="purchased" if bool(result.get("ok",false)) else str(result.get("code","unknown"))
		if bool(result.get("changed",false)):
			play_sfx("puzzle_success")
			_save()
		_update_hud()
		hud.refresh_panel(_panel_context())
		return
	super._on_ui_action(action,value)

func _at_market() -> bool:
	if boss_active: return false
	for object in objects:
		if str(object.definition.get("kind","")) in ["shop","market"] and hero.position.distance_to(object.definition.pos)<118: return true
	return false

func _enter_archive(definition: Dictionary) -> void:
	if transitioning or boss_active or _respawning or current_room!=6: return
	if str(definition.get("boss","archivist"))!="archivist": return
	if not hero.has_blade or not combat_state.dash_owned:
		_tip("أحضر سلاحك وتعلّم اندفاع الفانوس قبل فتح باب الخزنة.","Bring your blade and learn the lantern dash before opening the vault.")
		return
	_save()
	var return_point: Vector2=definition.get("pos",ARCHIVE_PORTAL_POINT)-Vector2(90,0)
	var session: Dictionary={"schema":28,"boss":"archivist","status":"entered","origin":{"room":6,"position":[return_point.x,return_point.y]},"checkpoint":checkpoint.duplicate(true),"progress":progress.duplicate(true),"combat":combat_state.serialize(),"hp":hero.hp,"energy":hero.energy,"language":hud.language,"journal_cursor":hud.journal_cursor.duplicate(true)}
	if not Journey.atomic_write(Journey.SESSION_PATH,session):
		_tip("تعذر فتح الخزنة؛ تقدمك ما زال محفوظًا.","The vault could not open; your progress remains saved.")
		return
	transitioning=true
	_set_paused(true)
	if is_instance_valid(fade): await create_tween().tween_property(fade,"color:a",1.0,transition_seconds).finished
	var result:=get_tree().change_scene_to_file(Journey.ARCHIVE_SCENE)
	if result!=OK:
		transitioning=false
		_set_paused(false)
		Journey.remove_session()

func _read_trial_return() -> void:
	# A character-studio visit keeps its exact exploration anchor in memory;
	# the standalone tests themselves never mutate this world inventory.
	if get_tree().has_meta("m28_studio_anchor"):
		var anchor: Variant=get_tree().get_meta("m28_studio_anchor")
		get_tree().remove_meta("m28_studio_anchor")
		if anchor is Dictionary and int(anchor.get("room",0))>=1 and int(anchor.get("room",0))<=15 and Journey.valid_point(anchor.get("position")):
			var at:=Vector2(float(anchor.position[0]),float(anchor.position[1]))
			if Rect2(Vector2.ZERO,_room_layout(int(anchor.room)).size).has_point(at): _return_record=anchor
	# M28 deliberately ignores archived standalone-trial return files.
	var session: Dictionary=Journey.read_session()
	if session.is_empty(): return
	# Validate both restored anchors before mutating any progress or inventory.
	for key in ["origin","checkpoint"]:
		var anchor: Dictionary=session[key]
		var point:=Vector2(float(anchor.position[0]),float(anchor.position[1]))
		if not Rect2(Vector2.ZERO,_room_layout(int(anchor.room)).size).has_point(point): return
	progress.merge(session.progress,true)
	combat_state.restore(session.combat)
	CurrencyLedger.sanitize(progress)
	Shop.sanitize(progress,combat_state)
	var status:=str(session.status)
	if status=="victory" and _valid_archive_receipt(session):
		progress.miniboss_archivist_defeated=true
		combat_state.increase_capacity("archivist_capacity",1)
		CurrencyLedger.create_reward(progress,"miniboss:archivist",6,ARCHIVE_PORTAL_POINT-Vector2(40,0),60)
	var destination: Dictionary=session.checkpoint if status=="death" else session.origin
	var room_definition: Dictionary=_room_layout(int(destination.room))
	var point:=Vector2(float(destination.position[0]),float(destination.position[1]))
	if not Rect2(Vector2.ZERO,room_definition.size).has_point(point): return
	_return_record={"room":int(destination.room),"position":destination.position.duplicate(),"hp":6 if status=="death" else clampi(int(session.get("hp",6)),1,6),"energy":clampf(float(session.get("energy",0)),0,99)}
	checkpoint=session.checkpoint.duplicate(true)
	_journey_consumed=true

func _valid_archive_receipt(session: Dictionary) -> bool:
	var receipt: Variant=session.get("victory_receipt",{})
	return receipt is Dictionary and str(receipt.get("boss",""))=="archivist" and int(receipt.get("hp",-1))==0 and str(receipt.get("state",""))=="victory"

func _spawn_death_drop() -> void:
	# Vault losses stay at their exact native chamber position, recovered when
	# re-entering. The normalized base drop only carries the matching amount.
	if progress.get("m28_archivist_pile",{}) is Dictionary and not progress.get("m28_archivist_pile",{}).is_empty(): return
	super._spawn_death_drop()

func on_player_death() -> void:
	progress.erase("m28_archivist_pile")
	super.on_player_death()

func _enter_boss_trial() -> void:
	_save()
	var at: Vector2=hero.last_safe_position
	get_tree().set_meta("m28_studio_anchor",{"room":current_room,"position":[at.x,at.y],"hp":hero.hp,"energy":hero.energy})
	get_tree().set_meta("m28_studio_return",Journey.WORLD_SCENE)
	get_tree().change_scene_to_file(CATALOG_SCENE)

func restart_stage() -> void:
	Journey.remove_session()
	super.restart_stage()

func get_m28_world_snapshot() -> Dictionary:
	return {"room":current_room,"save_path":save_path(),"boss_active":boss_active,"bell_defeated":bool(progress.get("miniboss_bell_defeated",false)),"archivist_defeated":bool(progress.get("miniboss_archivist_defeated",false)),"hero_hp":hero.hp,"hero_energy":hero.energy,"wallet":combat_state.wallet,"checkpoint":checkpoint.duplicate(true),"journey_pending":FileAccess.file_exists(Journey.SESSION_PATH),"shop":progress.get("m28_shop",{}),"environment":environment_director.get_environment_snapshot() if is_instance_valid(environment_director) and environment_director.has_method("get_environment_snapshot") else {}}
