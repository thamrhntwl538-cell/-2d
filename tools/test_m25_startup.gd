extends "res://tools/test_m24_bell.gd"
func key(code: int) -> void:
 var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true
 Input.parse_input_event(e);await step(2)
 e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=false
 Input.parse_input_event(e);await step(2)
func pad(button: int) -> void:
 var e:=InputEventJoypadButton.new();e.button_index=button;e.pressed=true
 Input.parse_input_event(e);await step(2)
 e=InputEventJoypadButton.new();e.button_index=button;e.pressed=false
 Input.parse_input_event(e);await step(2)
func run() -> void:
 var main: String=ProjectSettings.get_setting("application/run/main_scene")
 check(main=="res://scenes/minibosses/bell_character_review_m24.tscn","F5 opens character review first")
 var review: Node2D=load(main).instantiate();root.add_child(review);current_scene=review
 await step(6)
 check(review.page=="master" and review.models.size()==2,"reference and assembled character load in first page")
 await key(KEY_2)
 check(review.page=="parts","actual2 key opens body-part inspection")
 await pad(JOY_BUTTON_RIGHT_SHOULDER)
 check(review.page=="scale","actual right shoulder cycles to hero-scale comparison")
 await key(KEY_4)
 check(review.page=="motion" and review.models.size()==8,"actual4 key opens eight motion poses")
 await pad(JOY_BUTTON_A)
 await step(45)
 review=null;world=current_scene;hero=world.hero;bell=world.registered_boss
 check(world.is_boss_trial and world.current_room==12,"actualA enters isolated Bell trial")
 check(hero.hp==6 and hero.energy==99 and world.combat_state.capacity==4,"trial has documented safe starting loadout")
 check(world.boss_music.assets_ready and world.soundscape._events.has("bell_impact"),"new original audio loads on first launch")
 check(not world.boss_active and bell.hp==18 and not world.hud.boss_warning.visible,"Bell waits with no predictive warnings before encounter")
 Input.action_press("move_right")
 while hero.position.x<float(world.BELL_SPEC.intro_threshold_x)+10 and ticks<450:await step()
 release();await step(110)
 check(world.boss_active and bell.activated,"actualmovement reaches the first encounter")
 check(not world.hud.boss_warning.visible and not world.hud.objective_label.visible,"combat view contains no instruction card or stale objective")
 check(world.boss_music.fight_playing and world.boss_music.current_phase==1,"actual encounter starts the new original score")
 check(world.data.hazards.is_empty(),"parked bindery equipment causes no hidden hazard")
 check(world.hud.combat_display.visible and not world.hud.top_buttons.visible and not world.hud.boss_display.visible and not world.hud.room_label.visible and not world.hud.controls_label.visible,"actual encounter hides exploration chrome and opponent bar while retaining player vitals")
 await key(KEY_M)
 check(not world.hud.panel_open and not world.paused,"actualM cannot open the map during combat")
 await key(KEY_N)
 check(not world.hud.panel_open and not world.paused,"actualN cannot open the journal during combat")
 Input.action_press("pause_game");await step();Input.action_release("pause_game");await step(20)
 check(world.paused and world.hud.panel_open and world.hud.modal.visible,"Esc/Start pause remains available with clean combat HUD")
 Input.action_press("pause_game");await step();Input.action_release("pause_game");await step(25)
 check(not world.paused and not world.hud.panel_open and world.gameplay_active,"actual pause input resumes combat after panel close animation")
 check(world.hud.combat_display.visible and not world.hud.top_buttons.visible and not world.hud.controls_label.visible,"clean combat presentation survives pause and resume")
 if DisplayServer.get_name()!="headless":pass # The gameplay gallery owns M25 screenshots.
 current_scene=null
 await cleanup()
 var out: Dictionary={"checks":checks,"failures":failures,"scope":"Actual keyboard/controller review navigation, entering trial, walking into fight and loading new assets. Not full fight proof.","engine":Engine.get_version_info().string}
 FileAccess.open("user://m25_startup_report.json",FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
 print("M25 STARTUP ",JSON.stringify(out));quit(0 if failures.is_empty() else 1)
