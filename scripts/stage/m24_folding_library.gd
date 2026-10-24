extends "res://scripts/stage/m23_folding_library.gd"
## First of the four approved minibosses. All old routes remain authored as-is.
const Bell=preload("res://scripts/minibosses/m24_bell_warden.gd")
const BellHUD=preload("res://scripts/ui/m24_hud.gd")
const BellSound=preload("res://scripts/audio/m24_soundscape.gd")
const BellMusic=preload("res://scripts/audio/m24_bell_music.gd")
const BellRoomVisuals=preload("res://scripts/stage/m24_room_visuals.gd")
const BellImpact=preload("res://scripts/stage/m25_bell_impact.gd")
const BELL_ROOM:=12
const BELL_TRIAL:="res://scenes/minibosses/bell_trial_m24.tscn"
const BELL_LIBRARY:="res://scenes/stage_01/folding_library_m24.tscn"
const BELL_RETURN:="user://bell_trial_return_m24.json"
const BELL_SPEC:={"arena_rect":Rect2(1110,940,1080,320),"floor_y":1260.0,"intro_threshold_x":1150.0,"safe_checkpoint_spawn":Vector2(620,1260),"boss_spawn":Vector2(1850,1260),"camera_center":Vector2(1650,1010),"camera_zoom":Vector2(.94,.94),"gate_rects":[Rect2(1070,940,40,320),Rect2(2190,940,40,320)]}
var bell_impact: Node2D
var bell_impact_count:=0

func _physics_process(delta: float) -> void:
	# Closed book gates are the physical limits. A small interior margin also
	# contains knockback and dash endpoints without changing the hero's code.
	if boss_active and gameplay_active and current_room==BELL_ROOM:
		_constrain_bell_fighter()
	super._physics_process(delta)
	if boss_active and gameplay_active and current_room==BELL_ROOM:
		_constrain_bell_fighter()

func _constrain_bell_fighter() -> void:
	var minimum: float=BELL_SPEC.arena_rect.position.x+20.0
	var maximum: float=BELL_SPEC.arena_rect.end.x-20.0
	if hero.position.x<minimum:
		hero.position.x=minimum
		hero.velocity.x=maxf(0,hero.velocity.x)
	elif hero.position.x>maximum:
		hero.position.x=maximum
		hero.velocity.x=minf(0,hero.velocity.x)

func _open_panel(kind: String) -> void:
	# Exploration pages stay outside the encounter; intentional pause/settings
	# are still available through Esc/Start throughout both phases.
	if boss_active and kind in ["map","journal","note"]: return
	super._open_panel(kind)

func _ready() -> void:
	_register_inputs()
	progress = Puzzle.new_progress()
	CurrencyLedger.sanitize(progress)
	progress.preview_departed = false
	hud = BellHUD.new()
	add_child(hud)
	hud.setup(self)
	hud.action.connect(_on_ui_action)
	if hud.has_signal("panel_closed"):
		hud.connect("panel_closed", _panel_close_finished)
	arrival_title = ArrivalTitle.new()
	add_child(arrival_title)
	camera = RoomCamera.new()
	add_child(camera)
	hero = Hero.new()
	hero.name = "LanternWarden_M24"
	hero.world_ref = self
	hero.z_index = 5
	add_child(hero)
	camera.target = hero
	_camera_zoom = camera.zoom
	if is_boss_trial:
		_setup_trial_loadout()
	elif restore_saved_game:
		_restore_save()
	# Interface settings are newer than the last checkpoint. A language switch
	# must survive quitting before the next gameplay save.
	_restore_settings()
	if not is_boss_trial: _read_trial_return()
	var resume_point: Dictionary = _return_record if not _return_record.is_empty() else checkpoint
	_load_room(int(resume_point.room), "left", Vector2(float(resume_point.position[0]), float(resume_point.position[1])))
	if not _return_record.is_empty():
		hero.hp = clampi(int(_return_record.get("hp",6)),1,6)
		hero.energy = clampf(float(_return_record.get("energy",99.0)),0,99)
	var presentation := CanvasLayer.new()
	presentation.layer = 90
	add_child(presentation)
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.color = Color(0.025,0.035,0.06,1)
	presentation.add_child(fade)
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/ambient.wav")
	music.volume_db = -29
	add_child(music)
	music.finished.connect(music.play)
	music.play()
	boss_music = BellMusic.new()
	add_child(boss_music)
	boss_music.setup(music)
	boss_music.set_muted(boss_music_muted)
	soundscape = BellSound.new()
	add_child(soundscape)
	soundscape.setup(self)
	if is_boss_trial: _save()
	create_tween().tween_property(fade,"color:a",0.0,0.65)
	gameplay_active = true
	if bool(progress.get("preview_departed",false)) and environment_preview:
		_finish_preview.call_deferred()


func save_path() -> String:
	return "user://bell_trial_m24.json" if is_boss_trial else super.save_path()

func _restore_save() -> void:
	super._restore_save()
	# Reopen a completed old preview for the new encounter without forging or
	# clearing any actual guardian/final-boss receipt or world departure.
	if environment_preview and not progress.get("preview_bell_defeated",false): progress.preview_departed=false

func _setup_trial_loadout() -> void:
	super._setup_trial_loadout()
	checkpoint={"room":BELL_ROOM,"position":[620.0,1260.0]}

func _load_room(id: int, spawn_name: String="left", exact_position: Vector2=Vector2.INF) -> void:
	super._load_room(id,spawn_name,exact_position)
	if current_room!=BELL_ROOM: return
	# The three old animated presses intersect this encounter and its rest.
	# In this version they are parked scenery, matching the room art.
	data.hazards=[]
	data.compiler_trial=BELL_SPEC.duplicate(true)
	for point in [Vector2(556,1260),Vector2(2540,1260)]:
		var definition: Dictionary={"id":"bell_bench_left" if point.x<1000 else "bell_bench_right","kind":"bench","pos":point,"text_key":"bench","title_ar":"استراحة الجرس","title_en":"Bell Rest"}
		data.objects.append(definition)
		var item=Item.new()
		active_room.add_child(item)
		item.setup(self,definition)
		item.position=point
		objects.append({"definition":definition,"node":item})
		data.reading_nooks.append({"id":definition.id,"object_id":definition.id,"anchor":point,"rect":Rect2(point-Vector2(140,130),Vector2(280,180)),"style":"rest","height":72.0})
	data.challenge_summary.append("Bell Warden: fixed miniboss encounter on the bindery floor; quiet rest outside both book gates.")
	if is_instance_valid(visuals):
		active_room.remove_child(visuals)
		visuals.free()
	visuals=BellRoomVisuals.new()
	active_room.add_child(visuals)
	visuals.setup(self,data)
	bell_impact=BellImpact.new()
	active_room.add_child(bell_impact)
	bell_impact.setup(self)
	bell_impact_count=0
	_spawn_bell()
	_refresh_objects()
	if is_instance_valid(visuals): visuals.queue_redraw()

func _spawn_compiler() -> void:
	# Old M23 scene remains available as an archived review. The current world
	# reserves its final encounter for the user's chosen Sleeping Shelf.
	pass

func _spawn_bell() -> void:
	boss_arena=CompilerArena.new()
	active_room.add_child(boss_arena)
	boss_arena.setup(self,data)
	if _compiler_won():
		boss_arena.set_defeated(true)
		return
	var actor:=Bell.new()
	actor.name="BellWarden"
	active_room.add_child(actor)
	actor.setup(self,BELL_SPEC.boss_spawn,BELL_SPEC.arena_rect)
	registered_boss=actor
	enemies.append(actor)
	boss_last_phase=1

func _compiler_flag() -> String:
	return "trial_bell_defeated" if is_boss_trial else "preview_bell_defeated" if environment_preview else "miniboss_bell_defeated"

func _check_compiler_entry() -> void:
	if current_room!=BELL_ROOM or boss_active or _compiler_won() or _respawning or not is_instance_valid(registered_boss): return
	if hero.position.x<BELL_SPEC.intro_threshold_x or hero.position.x>BELL_SPEC.arena_rect.end.x-40 or absf(hero.position.y-BELL_SPEC.floor_y)>180: return
	if not hero.has_blade or not combat_state.dash_owned: return
	boss_active=true
	boss_attempts+=1
	boss_arena.set_locked(true)
	camera.target=null
	if is_instance_valid(_boss_camera_tween): _boss_camera_tween.kill()
	_boss_camera_tween=create_tween().set_parallel(true)
	_boss_camera_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_boss_camera_tween.tween_property(camera,"zoom",BELL_SPEC.camera_zoom,.65)
	_boss_camera_tween.tween_property(camera,"position",BELL_SPEC.camera_center,.65)
	registered_boss.start_encounter()
	if is_instance_valid(arrival_title): arrival_title.dismiss()
	if is_instance_valid(boss_music): boss_music.set_phase(1)
	hud.show_boss_intro()

func _update_compiler_presentation(delta: float) -> void:
	if not is_instance_valid(hud): return
	var actor: Node2D=registered_boss if is_instance_valid(registered_boss) else null
	var shown:=actor!=null and boss_active
	if shown and actor.phase!=boss_last_phase:
		boss_last_phase=actor.phase
		# Phase identity changes on the health display. No gate flash or music
		# cue predicts any attack, and the continuous score never restarts.
		if is_instance_valid(boss_music): boss_music.set_phase(actor.phase)
	hud.update_boss_status({"visible":shown,"name_ar":"حارس الجرس","name_en":"Bell Warden","hp":actor.hp if actor else 0,"max_hp":18,"phase":actor.phase if actor else 1,"state":actor.state if actor else "dormant"})
	if is_instance_valid(boss_music):
		boss_music.set_warning(false)
		boss_music.set_cinematic(shown and actor.state=="intro")
	if boss_active and gameplay_active:
		# A sharp sub-quarter-second reaction follows the actual floor contact.
		# No sustained shake, phase pulse or anticipation shakes the camera.
		boss_trauma=maxf(0,boss_trauma-delta*6.0)
		camera.offset=Vector2(sin(elapsed*71),sin(elapsed*89))*boss_trauma*5.0
	elif is_instance_valid(camera): camera.offset=Vector2.ZERO

func on_bell_ground_impact(point: Vector2, phase: int=1) -> void:
	if not boss_active or not gameplay_active or current_room!=BELL_ROOM: return
	bell_impact_count+=1
	boss_trauma=maxf(boss_trauma,1.15 if phase>=2 else .90)
	if is_instance_valid(bell_impact): bell_impact.strike(point,phase)

func on_compiler_defeated(actor: Node2D) -> void:
	if not is_instance_valid(actor) or actor!=registered_boss or not actor.is_dead or actor.alive or actor.hp!=0 or _compiler_won(): return
	progress[_compiler_flag()]=true
	boss_active=false
	_clear_compiler_attacks()
	boss_arena.set_defeated(true)
	combat_state.increase_capacity("bell_warden_capacity",1)
	_issue_coin_reward("miniboss:bell_warden",actor.position,45)
	_save()
	boss_music.stop_fight(true)
	hud.show_boss_victory()
	if is_instance_valid(_boss_camera_tween): _boss_camera_tween.kill()
	_boss_camera_tween=create_tween()
	_boss_camera_tween.tween_property(camera,"zoom",_camera_zoom,.65)
	_boss_camera_tween.tween_callback(func():
		if is_instance_valid(camera): camera.target=hero)
	_tip("سكن الجرس · توسعت سعة الفتائل. اجمع العملات.","The bell is silent · Fitil capacity expanded. Collect the coins.")

func _enter_boss_trial() -> void:
	if is_boss_trial:
		_restart_boss_trial()
		return
	_save()
	var p: Vector2=hero.last_safe_position
	var file:=FileAccess.open(BELL_RETURN,FileAccess.WRITE)
	if file==null: return
	file.store_string(JSON.stringify({"room":current_room,"position":[p.x,p.y],"hp":hero.hp,"energy":hero.energy}))
	file.close()
	get_tree().change_scene_to_file(BELL_TRIAL)

func _read_trial_return() -> void:
	if not FileAccess.file_exists(BELL_RETURN): return
	var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string(BELL_RETURN))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BELL_RETURN))
	if not saved is Dictionary or not saved.get("position",null) is Array or saved.position.size()!=2: return
	var room_id:=int(saved.get("room",0))
	if room_id<1 or room_id>15: return
	var p:=Vector2(float(saved.position[0]),float(saved.position[1]))
	if Rect2(Vector2.ZERO,Layouts.room(room_id).size).has_point(p): _return_record=saved

func _return_from_trial() -> void:
	if is_boss_trial: get_tree().change_scene_to_file(BELL_LIBRARY)

func _restart_boss_trial() -> void:
	if is_boss_trial: get_tree().change_scene_to_file(BELL_TRIAL)
