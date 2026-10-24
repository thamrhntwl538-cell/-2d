extends SceneTree
const SCENE:="res://scenes/minibosses/bell_trial_m24.tscn"
var world: Node2D
var hero: CharacterBody2D
var bell: Node2D
var checks:=0
var failures: Array[String]=[]
var history: Array[String]=[]
var stats: Dictionary={}
var ticks:=0
var report: Dictionary={}
var captured: Dictionary={}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks+=1
 if not ok: failures.append(label);print("BELL FAIL ",label)
func step(n:=1) -> void:
 for i in range(n):
  await physics_frame
  await process_frame
  ticks+=1
func release() -> void:
 for action in ["move_left","move_right","look_up","look_down","attack","jump","dash","spell","heal","pause_game"]: Input.action_release(action)
func move_to(x: float) -> void:
 Input.action_release("move_left");Input.action_release("move_right")
 if absf(x-hero.position.x)>10: Input.action_press("move_right" if x>hero.position.x else "move_left")
func photo(tag: String) -> void:
 if DisplayServer.get_name()=="headless" or captured.has(tag):return
 captured[tag]=true
 await RenderingServer.frame_post_draw
 var im: Image=root.get_texture().get_image()
 im.save_jpg("res://previews/m24/"+tag+".jpg",.93)
func stop_audio_tree(node:Node) -> void:
 if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
  node.stop();node.stream=null
 for child in node.get_children():stop_audio_tree(child)
func cleanup() -> void:
 release()
 if is_instance_valid(world):
  world.gameplay_active=false
  world.set_process(false);world.set_physics_process(false)
  world.hero.set_physics_process(false)
  world.active_room.process_mode=Node.PROCESS_MODE_DISABLED
  world.soundscape.stop_all();world.boss_music.stop_all()
  stop_audio_tree(world)
  # Fixed-fps QA can advance a nominal timer before the audio mixing thread
  # has released stream playback refs. Let real mixer time pass at shutdown.
  OS.delay_msec(180)
  await process_frame
  await process_frame
  if is_instance_valid(world.active_room): world.active_room.set_process(false)
  world.queue_free()
  world=null;hero=null;bell=null
  await step(4)
func fresh() -> void:
 world=load(SCENE).instantiate()
 root.add_child(world)
 await step(10)
 hero=world.hero;bell=world.registered_boss
func finish_fixture() -> void:
 report={"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"scope":"Deterministic mechanics fixtures. Actors are positioned and clocks stepped directly; sword geometry still comes from the approved hero and native melee resolver. This is not a real-input fight."}
 await cleanup()
 FileAccess.open("user://m24_bell_contracts.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print("M24 BELL CONTRACTS ",JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
func contracts() -> void:
 # Isolate movement and collision from encounter entry/UI clocks. The complete
 # live-input fight remains a separate mode below and never uses this setup.
 world.set_physics_process(false);world.set_process(false)
 hero.set_physics_process(false);bell.set_physics_process(false)
 world.gameplay_active=true;world.boss_active=true
 bell.activated=true;bell.position=Vector2(1600,1260)
 hero.position=Vector2(1200,1260)
 bell.pattern_index=0
 bell._next_pattern()
 var start:Vector2=bell.position
 check(bell.state=="walk" and not bell.danger_rect().has_area(),"distant engagement starts with two safe native steps")
 hero.position.x=1900
 bell._physics_process(.26)
 check(bell.direction==-1 and is_equal_approx(bell.position.x,start.x-11.7),"approach keeps its captured direction when hero crosses behind")
 bell._physics_process(.26)
 check(bell.state=="drawback" and is_equal_approx(bell.position.x,start.x-23.4),"approach travels exactly two fixed steps before drawback")
 check(bell.walk_footfalls==2,"footfall events occur once at each actual planted foot")
 bell._physics_process(.36)
 check(bell.state=="rush" and bell.get_contact_damage()==1 and bell.danger_rect().has_area(),"rush becomes dangerous only at actual release")
 bell._physics_process(.17)
 check(is_equal_approx(bell.position.y,bell.floor_y-8),"fast rush follows the visible low bound instead of skating on planted feet")
 check(bell.clash_rect().get_center().x<bell.position.x,"rush parry is limited to the leading bell edge")
 check(bell.on_clash() and bell.state=="stagger" and not bell.danger_rect().has_area() and is_equal_approx(bell.position.y,bell.floor_y),"clash plants the stopped bound and exposes a recovery")
 check(not bell.on_clash(),"one stopped rush cannot be parried repeatedly")
 bell._enter("crouch",.32);bell.current_pattern="leap"
 bell.captured_target=Vector2(1120,1260)
 bell._launch(false)
 var launched:Vector2=bell.flight_velocity
 hero.position.x=2150
 bell._physics_process(.10)
 check(is_equal_approx(bell.flight_velocity.x,launched.x) and bell.direction==-1,"leap commits to its old target without midair homing")
 check(not bell.danger_rect().has_area(),"ascending bell has no damaging body contact")
 bell.flight_velocity.y=100
 check(bell.danger_rect().has_area() and bell.get_contact_damage()==2,"falling bell uses its visible body for two damage")
 bell._enter("recover",.78)
 check(not bell.danger_rect().has_area(),"resting and recovering body remains safe")
 # A swept travelling wave must hit a native hurtbox even if one step crosses it.
 hero.position=Vector2(1650,1260);hero.hp=6;hero.invulnerable=0
 var wave=bell.Wave.new()
 world.active_room.add_child(wave)
 wave.setup(world,bell,"chain",Vector2(1550,1248),{"warning":0,"duration":1.15,"velocity":Vector2(380,0),"width":46,"height":16})
 wave.set_physics_process(false)
 wave._physics_process(.35)
 check(hero.hp==5 and wave.hero_hits==1,"resonance sweep cannot tunnel through original hero hurtboxes")
 var stopped_age:float=wave.age
 var stopped_position:Vector2=wave.position
 world.gameplay_active=false;wave._physics_process(.25)
 check(is_equal_approx(wave.age,stopped_age) and wave.position.is_equal_approx(stopped_position) and not wave.spent,"pause preserves the same live wave rather than cancelling it")
 world.gameplay_active=true;wave.consume()
 hero.position=Vector2(1650,1140);hero.hp=6;hero.invulnerable=0
 wave=bell.Wave.new();world.active_room.add_child(wave)
 wave.setup(world,bell,"chain",Vector2(1550,1248),{"warning":0,"duration":1.15,"velocity":Vector2(380,0),"width":46,"height":16})
 wave.set_physics_process(false);wave._physics_process(.35)
 check(hero.hp==6 and wave.hero_hits==0,"jump-height native hurtboxes clear the low resonance")
 wave.consume()
 # Add a solid end stop and prove the same swept collision honors terrain.
 hero.position=Vector2(2000,1260)
 var wall:=StaticBody2D.new();wall.collision_layer=1
 var shape:=CollisionShape2D.new();var rectangle:=RectangleShape2D.new()
 rectangle.size=Vector2(30,120);shape.shape=rectangle;wall.add_child(shape)
 world.active_room.add_child(wall);wall.position=Vector2(1780,1200)
 await step(2)
 wave=bell.Wave.new();world.active_room.add_child(wave)
 wave.setup(world,bell,"chain",Vector2(1680,1248),{"warning":0,"duration":1.15,"velocity":Vector2(380,0),"width":46,"height":16})
 wave.set_physics_process(false);wave._physics_process(.4)
 check(wave.spent and wave.was_blocked and wave.position.x<1780,"resonance stops at actual solid bookwork")
 wall.queue_free()
 # Query the real compact sword arc, then place its tip at the actual bell edge.
 hero.position=Vector2(1800,1260);hero.facing=-1;hero.hurt_time=0;hero.velocity=Vector2.ZERO
 hero.attack_direction="attack";hero.attack_elapsed=.10;hero.attack_time=.20;hero.active_strike_time=.04;hero.hit_targets.clear()
 hero._update_animation()
 bell.position=Vector2(1600,1260);bell.direction=1;bell._enter("rush",.34)
 var sword:Rect2=hero.strike_rect("attack",-1)
 check(sword.has_area() and sword.size.x<100,"parry fixture uses the approved compact native sword arc")
 hero.position+=bell.clash_rect().get_center()-sword.get_center()
 world.hero_strike("attack",-1)
 check(bell.state=="stagger" and bell.hp==18,"native front sword contact parries before body damage")
 world.hit_stop_remaining=0;world.gameplay_active=true
 hero.position=Vector2(1400,1260);hero.facing=1;hero.hit_targets.clear();hero._update_animation()
 bell._enter("rush",.34)
 sword=hero.strike_rect("attack",1)
 hero.position+=bell.position+Vector2(-43,-75)-sword.get_center()
 world.hero_strike("attack",1)
 check(bell.state=="rush" and bell.hp==17,"rear sword contact can hurt the bell but cannot stop its committed rush")
 bell.clear_attacks()
 await finish_fixture()
func run() -> void:
 await fresh()
 if "--contracts" in OS.get_cmdline_user_args():
  await contracts()
  return
 check(world.current_room==12 and hero.position.distance_to(Vector2(620,1260))<4,"fresh trial starts at supported bindery rest")
 check(bell.hp==18 and bell.state=="dormant" and not bell.activated,"miniboss remains dormant before entry")
 check(hero.hp==6 and hero.energy==99,"fresh trial has original six-health/shared-energy loadout")
 check(FileAccess.get_sha256("res://assets/warden_m20/warden_parts.png")=="6eca7436c7a8c39451256aa56db465d664df0d6dbb42d8e7f24122592b34bb66","approved hero atlas is unchanged")
 check(not world.hud.boss_warning.visible,"no warning card exists in play")
 await photo("01_bell_at_rest")
 var mode: String="cheap" if "--cheap" in OS.get_cmdline_user_args() else "reactive"
 Input.action_press("move_right")
 while hero.position.x<970 and ticks<180:await step()
 release()
 check(world.boss_active and bell.activated and world.boss_arena.locked,"real input crosses encounter threshold and closes gates")
 await step(60)
 await photo("02_bell_encounter")
 if "--stills" in OS.get_cmdline_user_args():
  await cleanup()
  quit(0 if failures.is_empty() else 1)
  return
 var start:=ticks
 var combat_age_start:float=bell.age
 var wall_start:int=Time.get_ticks_msec()
 var last_attack: int=-100
 var last_cast: int=-100
 var paused_once:=false
 var airhold:=false
 var damage_events:=0
 var last_hp: int=bell.hp
 var distance:=0.0
 var prev: Vector2=hero.position
 for frame in range(5400):
  if bell.is_dead or hero.hp<=0:break
  if not history.has(bell.state):history.append(bell.state)
  if not paused_once and bell.state=="resonance" and not get_nodes_in_group("m23_boss_attacks").is_empty():
   release();Input.action_press("pause_game");await step();Input.action_release("pause_game");await step(2)
   var before: float=bell.state_time
   var old_position: Vector2=bell.position
   var waves: Array=get_nodes_in_group("m23_boss_attacks")
   var wave_age: float=waves[0].age if not waves.is_empty() else -1.0
   await step(15)
   check(world.paused and is_equal_approx(bell.state_time,before) and bell.position.is_equal_approx(old_position),"pause preserves exact live miniboss clock and position")
   check(not waves.is_empty() and is_instance_valid(waves[0]) and is_equal_approx(waves[0].age,wave_age),"live resonance is paused rather than cancelled")
   Input.action_press("pause_game");await step();Input.action_release("pause_game");await step(24)
   check(world.gameplay_active and not world.hud.panel_open,"actual resume input restores play after UI animation")
   paused_once=true
  Input.action_release("attack");Input.action_release("spell")
  Input.action_release("look_up");Input.action_release("look_down")
  var dx: float=bell.position.x-hero.position.x
  var safe: bool=bell.state in ["recover","resonance","idle","stagger","drawback","crouch"]
  if mode=="cheap":
   move_to(bell.position.x)
   Input.action_press("look_up")
  else:
   if bell.state=="air":
    var vy: float=bell.flight_velocity.y
    var remain: float=(-vy+sqrt(maxf(0,vy*vy+3800*(bell.floor_y-bell.position.y))))/1900.0
    var landing: float=clampf(bell.position.x+bell.flight_velocity.x*remain,980,2320)
    move_to(clampf(landing+(-185 if hero.position.x<landing else 185),1000,2300))
   else:move_to(clampf(bell.position.x+(-80 if hero.position.x<bell.position.x else 80),980,2320))
   var jump_needed: bool=bell.state=="drawback" and bell.state_time<.25 and absf(dx)<330
   for wave in get_nodes_in_group("m23_boss_attacks"):
    if is_instance_valid(wave) and not wave.spent and absf(wave.position.x-hero.position.x)<125 and (wave.position.x-hero.position.x)*wave.travel.x<0:jump_needed=true
   if jump_needed and hero.is_on_floor():Input.action_press("jump");airhold=true
   if airhold and hero.velocity.y>=0:Input.action_release("jump");airhold=false
   if not hero.is_on_floor() and absf(dx)<70:Input.action_press("look_down")
   elif absf(dx)<36:Input.action_press("look_up")
   if safe and absf(dx)<310 and frame-last_cast>100 and hero.energy>=33:
    Input.action_press("spell");last_cast=frame
  if absf(dx)<120 and frame-last_attack>21:
   Input.action_press("attack");last_attack=frame
  await step()
  distance+=hero.position.distance_to(prev);prev=hero.position
  if bell.hp<last_hp:damage_events+=1;last_hp=bell.hp
  if bell.state=="rush" and bell.state_time<bell.state_duration*.65:await photo("03_bell_swing")
  if bell.state=="walk" and bell.state_duration-bell.state_time>.12:await photo("07_bell_walk")
  if bell.state=="crouch" and bell.state_time<.16:await photo("08_bell_crouch")
  if bell.state=="air" and bell.flight_velocity.y>0:await photo("04_bell_air_drop")
  if bell.state=="resonance":await photo("05_bell_resonance")
  if frame%300==0:print("BELL FIGHT ",mode," ",frame," hp=",hero.hp," bell=",bell.hp," state=",bell.state)
  if world._respawning:break
 release()
 stats={"mode":mode,"ticks":ticks-start,"seconds_nominal":(ticks-start)/60.0,"active_combat_seconds":bell.age-combat_age_start,"wall_seconds":(Time.get_ticks_msec()-wall_start)/1000.0,"hero_hp":hero.hp,"bell_hp":bell.hp,"won":bell.is_dead,"distance":distance,"damage_events":damage_events,"states":history,"actual_inputs_only":true,"positive_injected_damage":false,"sounds":world.sound_events}
 if mode=="reactive":
  check(bell.is_dead,"real movement/jump/sword/spell defeats full18-health miniboss")
  check(distance>400,"winning driver genuinely repositions")
  check(not world.hud.boss_warning.visible and bell.warning_ar.is_empty(),"no attack instructions or warning markers were introduced")
  if bell.is_dead:
   check(world.progress.get("trial_bell_defeated",false) and not world.progress.get("boss_defeated",false),"mini victory saves its own flag and grants no final-boss victory")
   check(world.combat_state.capacity==5,"miniboss grants its one capacity upgrade")
   check(not world.boss_arena.locked,"book gates open after genuine victory")
   var pool: Array=get_nodes_in_group("m22_coins")
   print("COIN GROUP ",pool.size())
   var before: int=world.combat_state.wallet
   world.on_compiler_defeated(bell)
   check(world.combat_state.capacity==5 and world.combat_state.wallet==before,"duplicate defeat callback cannot duplicate rewards")
   await photo("06_bell_victory")
 else:
  check(not bell.is_dead and hero.hp<=0,"unreactive centre pressure loses without defensive choices")
  await step(75)
  check(hero.hp==6 and world.registered_boss.hp==18 and not world.boss_active,"real death returns to safe rest and resets encounter")
  check(get_nodes_in_group("m23_boss_attacks").is_empty(),"death clears all old resonance attacks")
 report={"checks":checks,"failures":failures,"fight":stats,"engine":Engine.get_version_info().string,"scope":"Actual Input fight; only native screenshots are captured conditionally. No direct positive damage or frozen combatants."}
 await cleanup()
 FileAccess.open("user://m24_bell_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print("M24 BELL REPORT ",JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
