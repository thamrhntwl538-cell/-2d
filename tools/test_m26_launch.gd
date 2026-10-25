extends "res://tools/test_m24_bell.gd"
## Actual input/routing smoke of supplied art and playable isolated trial.
func key(code:int) -> void:
	var e:=InputEventKey.new()
	e.keycode=code;e.physical_keycode=code;e.pressed=true
	Input.parse_input_event(e);await step(2)
	e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=false
	Input.parse_input_event(e);await step(2)

func run() -> void:
	var normal_path:="user://folding_library_m18_preview.json"
	var before:Variant=FileAccess.get_file_as_bytes(normal_path) if FileAccess.file_exists(normal_path) else null
	var main:String=ProjectSettings.get_setting("application/run/main_scene")
	check(main=="res://scenes/minibosses/archivist_reference_m26.tscn","F5 launches the new Archive Keeper studio")
	var review:Node=load(main).instantiate()
	root.add_child(review);current_scene=review
	await step(8)
	check(review.has_method("get_review_snapshot") and review.has_method("select_animation"),"native project main is the real character studio")
	check(is_instance_valid(review.actor) and review.move_buttons.size()==18 and review.actor.get_snapshot().frames==39,"all18 controls and real native39-frame sprite load")
	check((not FileAccess.file_exists(normal_path)) if before==null else FileAccess.get_file_as_bytes(normal_path)==before,"opening art studio does not mutate library progress")

	await key(KEY_SPACE)
	var frame:int=review.actor.frame_index
	await step(15)
	check(review.paused and review.actor.frame_index==frame,"actualSpace pauses sourceclock")
	await key(KEY_RIGHT)
	check(review.actor.frame_index==mini(frame+1,38),"actualRight scrubs sourceframe")
	await key(KEY_DOWN)
	check(review.actor.animation_name=="walk","actualDown selects sourcewalk")
	await key(KEY_2)
	check(review.actor.resolved_source_phase==2,"actual2 selects burningphase2")
	await key(KEY_F)
	check(review.actor.facing==-1,"actualF mirrors fixedfootpivot")
	await key(KEY_ENTER);await step(15)
	var trial:Node=current_scene
	check(trial.has_method("get_trial_snapshot"),"actualEnter opens playableArchivist")
	if not trial.has_method("get_trial_snapshot"):
		quit(1)
		return
	check(trial.hero.hp==6 and trial.hp==48 and not trial.encounter_started,"freshsixhealthhero/dormantArchivist")
	check(trial.singing.is_singing() and trial.singing.player.get_parent()==trial.keeper and trial.singing.listener.get_parent()==trial.hero,"songsourceonbody/listeneronhero")
	var initial_gain:float=trial.singing.get_distance_gain_db()
	Input.action_press("move_right")
	var moves:=0
	while not trial.encounter_started and moves<200:
		await step()
		moves+=1
	Input.action_release("move_right")
	await step(3)
	check(trial.encounter_started,"actualwalkentersfight")
	check(trial.singing.get_distance_gain_db()>initial_gain+4.0,"actualapproachincreasessonggain")
	check(not trial.singing.is_singing() and trial.singing.player.stream==null,"fightentrycutsongimmediately")
	check(not trial.singing.start_dormant(),"fightlatchrejectssongrestart")
	await key(KEY_P)
	check(trial.paused,"actualPpausestrial")
	await key(KEY_P)
	check(not trial.paused and not trial.singing.is_singing(),"resumeremainssilent")
	check(not trial.boss_display.visible,"combathudonlyplayervitals")
	await key(KEY_ESCAPE);await step(8)
	check(current_scene.has_method("get_review_snapshot"),"actualEscreturnstoreference")
	await key(KEY_B);await step(6)
	review=null
	check(current_scene.get_script().resource_path=="res://scripts/minibosses/m24_character_review.gd","actualB opens the unchanged Bell character review")
	check(current_scene.page=="master","Bell review keeps its original master page")
	await key(KEY_ENTER);await step(35)
	world=current_scene;hero=world.hero;bell=world.registered_boss
	check(world.is_boss_trial and world.current_room==12,"actualEnter still opens the previous isolated Bell trial")
	check(hero.hp==6 and is_equal_approx(hero.energy,99),"original Bell trial retains six health/shared99 energy")
	check(bell.hp==18 and bell.phase==1 and not bell.activated,"original Bell remains full-health and dormant before entry")
	check(world.BELL_SPEC.arena_rect==Rect2(1110,940,1080,320),"M25 Bell arena geometry remains unchanged")
	check((not FileAccess.file_exists(normal_path)) if before==null else FileAccess.get_file_as_bytes(normal_path)==before,"review routing and isolated trial preserve normal save bytes")
	check(FileAccess.get_sha256("res://assets/warden_m20/warden_parts.png")=="6eca7436c7a8c39451256aa56db465d664df0d6dbb42d8e7f24122592b34bb66","approved hero artwork unchanged")
	check(FileAccess.get_sha256("res://assets/minibosses/m24/bell_character_parts.png")=="5e2e45ad2c3eaed31955aeae347929e0899a0de5d5d0a5a478caad4cf94c4d81","approved Bell artwork unchanged")
	current_scene=null
	await cleanup()
	var out:Dictionary={"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"scope":"ActualF5/nativecontrols/newtrial/actualwalksingingcutoff/pause/returnandpreservedBell/save/art. Notafullskill-playedfightproof."}
	FileAccess.open("user://m26_launch_report.json",FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
	print("M26 LAUNCH ",JSON.stringify(out))
	quit(0 if failures.is_empty() else 1)
