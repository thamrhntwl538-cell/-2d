extends "res://scripts/minibosses/m26_archivist_trial.gd"
## The exact imported Archivist encounter inside the world journey. Original
## frame/event/hitbox logic, song cutoff, attack bands and grace remain inherited.
const Journey=preload("res://scripts/stage/m29_journey.gd")
const JourneyHero=preload("res://scripts/combat/m29_player.gd")
var journey: Dictionary={}
var progress: Dictionary={}
var _victory_committed:=false
var _death_return_pending:=false
var _journey_ready:=false
var _returning:=false
var _last_saved_vitals:=""
var pile: Node2D

class LostEmbers extends Node2D:
	var clock:=0.0
	func _process(delta: float) -> void:
		clock+=delta
		queue_redraw()
	func _draw() -> void:
		var pulse:=.8+.15*sin(clock*3)
		draw_circle(Vector2(0,-14),25,Color(.93,.54,.18,.07*pulse))
		draw_circle(Vector2(0,-14),14,Color(.93,.59,.24,.16*pulse))
		for dx in [-7,0,7]:
			draw_circle(Vector2(dx,-10-absf(dx)*.65),4.5,Color("f1bd74"))

func _create_hero() -> CharacterBody2D: return JourneyHero.new()

func _ready() -> void:
	journey=Journey.read_session()
	if journey.is_empty():
		_returning=true
		get_tree().change_scene_to_file.call_deferred(Journey.WORLD_SCENE)
		return
	progress=journey.progress.duplicate(true)
	super._ready()
	combat_state.restore(journey.combat)
	hero.has_blade=bool(progress.get("weapon_owned",false))
	hero.has_dash=combat_state.dash_owned
	hero.has_code_slash=combat_state.spell_owned
	hero.hp=clampi(int(journey.get("hp",6)),1,6)
	hero.energy=clampf(float(journey.get("energy",0)),0,99)
	_journey_ready=true
	_spawn_lost_embers()
	if bool(progress.get("miniboss_archivist_defeated",false)):
		encounter_started=true
		is_dead=true
		hp=0
		state="victory"
		gate_open=true
		singing.stop_for_encounter()
		keeper.set_animation("death",2)
		keeper.seek(float(keeper.get_snapshot().duration))
		keeper.set_playing(false)
		_victory_committed=true
	_sync_session("entered")
	_refresh_hud()

func _physics_process(delta: float) -> void:
	if not _journey_ready or _returning: return
	super._physics_process(delta)
	if not paused and gameplay_active and not combat_state.death_drop.is_empty() and is_instance_valid(pile):
		if hero.position.distance_to(pile.position)<76 and Input.is_action_just_pressed("interact"):
			if combat_state.recover_drop()>0:
				progress.erase("m29_archivist_pile")
				progress.m29_death_location=""
				pile.queue_free()
				play_sfx("coin")
				_sync_session("victory" if _victory_committed else "entered")
	if state=="victory" and not _victory_committed:
		_commit_victory()
	if state=="victory" and not paused and Input.is_action_just_pressed("interact"):
		_return_to_catalog()

func _spawn_lost_embers() -> void:
	var saved: Variant=progress.get("m29_archivist_pile",{})
	if not saved is Dictionary or combat_state.death_drop.is_empty() or not Journey.valid_point(saved.get("position")): return
	var point:=Vector2(float(saved.position[0]),float(saved.position[1]))
	if not Rect2(45,200,1935,440).has_point(point): return
	pile=LostEmbers.new()
	pile.name="LostJourneyCoins"
	pile.position=point
	pile.z_index=12
	var unshaded:=CanvasItemMaterial.new()
	unshaded.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
	pile.material=unshaded
	active_room.add_child(pile)

func _commit_victory() -> void:
	if _victory_committed or not is_dead or hp!=0 or state!="victory": return
	_victory_committed=true
	progress.miniboss_archivist_defeated=true
	combat_state.increase_capacity("archivist_capacity",1)
	journey.victory_receipt={"boss":"archivist","hp":0,"state":"victory"}
	_sync_session("victory")
	_refresh_hud()

func _sync_session(status: String) -> bool:
	if not _journey_ready or journey.is_empty(): return false
	journey.status=status
	journey.progress=progress.duplicate(true)
	journey.combat=combat_state.serialize()
	journey.hp=hero.hp
	journey.energy=hero.energy
	_last_saved_vitals="%d:%.3f:%d" % [hero.hp,hero.energy,combat_state.wallet]
	# Session first, then checkpoint: an interruption at either boundary is
	# reconciled by the world's idempotent receipt when the project next opens.
	if not Journey.atomic_write(Journey.SESSION_PATH,journey): return false
	return Journey.atomic_write(Journey.SAVE_PATH,Journey.checkpoint_record(journey))

func combat_changed() -> void:
	super.combat_changed()
	if not _journey_ready or _returning or _death_return_pending: return
	var signature:="%d:%.3f:%d" % [hero.hp,hero.energy,combat_state.wallet]
	if signature!=_last_saved_vitals and hero.hp>0:
		_sync_session("victory" if _victory_committed else "entered")

func on_player_death() -> void:
	super.on_player_death()
	if _death_return_pending or not _journey_ready: return
	_death_return_pending=true
	progress.m29_death_location="archivist"
	# Keep the exact chamber coordinates, while the normalized legacy drop
	# stores its room6 portal anchor and amount for inventory validation.
	var point:=Vector2(clampf(hero.position.x,45,1980),FLOOR_Y)
	combat_state.drop_on_death(6,Vector2(float(journey.origin.position[0]),float(journey.origin.position[1])))
	progress.erase("m29_archivist_pile")
	if not combat_state.death_drop.is_empty():
		progress.m29_archivist_pile={"position":[point.x,point.y],"amount":int(combat_state.death_drop.amount)}
	hero.energy=0
	_sync_session("death")
	_refresh_hud()
	_finish_death.call_deferred()

func _finish_death() -> void:
	await get_tree().create_timer(.9).timeout
	if not _returning: _return_to_catalog()

func _refresh_hud() -> void:
	super._refresh_hud()
	if not _journey_ready or not is_instance_valid(vitals): return
	var language:=str(journey.get("language","ar"))
	var arabic:=language=="ar"
	var context:={"hp":hero.hp,"max_hp":6,"energy":hero.energy,"max_energy":99,"wallet":combat_state.wallet,"equipped":combat_state.equipped,"spell_owned":combat_state.spell_owned}
	context.merge(healing_status_context(),true)
	vitals.update_context(context,language)
	_update_focus_hint(language)
	if paused:
		message.text="متوقف مؤقتًا" if arabic else "Paused"
		caption.text="P / Start: متابعة · Esc / Back: العودة إلى الخزنة" if arabic else "P / Start: Resume · Esc / Back: Leave the vault"
	elif hero.hp<=0:
		message.text="انطفأت الشعلة" if arabic else "The flame went out"
		caption.text="العودة إلى آخر مقعد · العملات تبقى في موضع سقوطك" if arabic else "Returning to your last bench · Lost coins remain where you fell"
	elif state=="victory":
		message.text="سكنت الصفحات" if arabic else "The pages fall silent"
		caption.text="E / A: العودة للمكتبة · العملات تنتظرك أمام الخزنة" if arabic else "E / A: Return to the library · Reward coins await outside the vault"
	elif not encounter_started:
		message.text="أمين الأرشيف" if arabic else "The Archivist"
		caption.text="اقترب من صوته · Esc / Back: العودة إلى المكتبة" if arabic else "Follow his voice · Esc / Back: Return to the library"

func _unhandled_input(event: InputEvent) -> void:
	if not _journey_ready or _returning: return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: _return_to_catalog()
			KEY_P: set_paused(not paused)
			KEY_ENTER:
				if state=="victory": _return_to_catalog()
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_BACK: _return_to_catalog()
			JOY_BUTTON_START: set_paused(not paused)
			JOY_BUTTON_A:
				if state=="victory": _return_to_catalog()

func _return_to_catalog() -> void:
	if _returning or not _journey_ready: return
	# Let the approved death sequence finish before issuing a victory receipt.
	if is_dead and state!="victory" and hero.hp>0: return
	if state=="victory" and not _victory_committed: _commit_victory()
	var status:="death" if hero.hp<=0 else "victory" if _victory_committed else "retreat"
	if not _sync_session(status):
		message.text="تعذر حفظ العودة · حاول مجددًا"
		return
	_returning=true
	_scene_exiting=true
	singing.stop_for_room_exit()
	keeper_sound.stop_all()
	soundscape.stop_all()
	get_tree().change_scene_to_file(Journey.WORLD_SCENE)

func get_journey_snapshot() -> Dictionary:
	return {"ready":_journey_ready,"status":journey.get("status",""),"victory_committed":_victory_committed,"wallet":combat_state.wallet,"hero_hp":hero.hp if is_instance_valid(hero) else 0,"hero_energy":hero.energy if is_instance_valid(hero) else 0,"origin":journey.get("origin",{}),"checkpoint":journey.get("checkpoint",{}),"pile":progress.get("m29_archivist_pile",{}),"base_trial":get_trial_snapshot() if _journey_ready else {}}
