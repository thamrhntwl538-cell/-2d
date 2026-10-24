extends "res://tools/test_m24_bell.gd"
## Focused state/storage/UI fixtures. Direct damage is only used to verify the
## reward transaction; the separate test_m24_bell fight proves real-input wins.
const LIBRARY:="res://scenes/stage_01/folding_library_m24.tscn"
const NORMAL_SAVE:="user://folding_library_m18_preview.json"
var initial_files: Dictionary={}
func write_json(path: String, value: Dictionary) -> void:
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(value))
func ui_button(id: String) -> Button:
 for control in world.hud.modal_body.find_children("*","Button",true,false):
  if str(control.get_meta("action_id",""))==id:return control
 return null
func menu_action(id: String) -> void:
 Input.action_press("pause_game");await step();Input.action_release("pause_game");await step(20)
 var button:=ui_button(id)
 check(button!=null,"native menu exposes "+id)
 if button==null:return
 button.grab_focus()
 var e:=InputEventJoypadButton.new();e.button_index=JOY_BUTTON_A;e.pressed=true
 Input.parse_input_event(e);await step(2)
 e=InputEventJoypadButton.new();e.button_index=JOY_BUTTON_A;e.pressed=false;Input.parse_input_event(e)
 await step(45)
 world=current_scene
 hero=world.hero;bell=world.registered_boss
func run() -> void:
 for path in [NORMAL_SAVE,"user://bell_trial_m24.json","user://bell_trial_return_m24.json","user://folding_library_m18_settings.cfg"]:
  initial_files[path]=FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
 var progress: Dictionary=preload("res://scripts/stage/m22_puzzle_state.gd").new_progress()
 progress.weapon_owned=true;progress.guard_clear=true;progress.compiler_seal_owned=true;progress.seal_registered=true;progress.preview_compiler_defeated=true;progress.preview_departed=true
 var inventory=preload("res://scripts/combat/m18_combat_state.gd").new()
 inventory.dash_owned=true;inventory.spell_owned=true;inventory.wallet=37;inventory.capacity=6;inventory.acquire("wick");inventory.equip("wick",true)
 write_json(NORMAL_SAVE,{"version":18,"environment_preview":true,"progress":progress,"checkpoint":{"room":12,"position":[620,1260]},"language":"ar","combat":inventory.serialize(),"energy":55})
 world=load(LIBRARY).instantiate();root.add_child(world);current_scene=world
 await step(12);hero=world.hero;bell=world.registered_boss
 check(world.current_room==12 and not world.is_boss_trial,"normal library restores existing checkpoint in bindery")
 check(world.combat_state.wallet==37 and world.combat_state.capacity==6,"normal wallet/capacity retain old save values")
 check(not world.tour_finished and not world.progress.preview_departed,"completed old tour reopens for the new miniboss")
 check(world.progress.preview_compiler_defeated and world.progress.guard_clear and world.progress.compiler_seal_owned,"old story receipts stay intact")
 check(world.data.hazards.is_empty(),"parked presses cannot deal hidden damage in arena or either rest")
 check(preload("res://scripts/stage/m23_layouts.gd").room(12).hazards.size()==3,"old layouts remain unchanged outside M24 instance")
 check(world.boss_music.assets_ready and world.soundscape._events.has("bell_impact"),"new music and Bell events load in normal library")
 check(not world.hud.boss_warning.visible and not world.hud.objective_label.text.contains("راقب المكابس"),"no attack-warning card or stale press objective")
 hero.hp=4;hero.energy=55
 Input.action_press("move_right")
 while hero.position.x<790:await step()
 release();await step(5)
 var checkpoint_before: Dictionary=world.checkpoint.duplicate(true)
 var inventory_before: Dictionary=world.combat_state.serialize().duplicate(true)
 var return_position: Vector2=hero.last_safe_position
 await menu_action("boss_trial")
 check(world.is_boss_trial and world.combat_state.wallet==0 and world.combat_state.capacity==4,"actual controller menu enters fresh isolated trial")
 check(hero.hp==6 and hero.energy==99,"trial entry has documented health/energy")
 var normal_hash:=FileAccess.get_sha256(NORMAL_SAVE)
 check(FileAccess.file_exists("user://bell_trial_return_m24.json"),"trial return record exists independently")
 await menu_action("trial_return")
 check(not world.is_boss_trial and hero.position.distance_to(return_position)<6,"actual Return restores supported previous position")
 check(hero.hp==4 and is_equal_approx(hero.energy,55.0),"Return restores pre-trial health and energy")
 check(world.checkpoint==checkpoint_before,"temporary trial return does not replace saved bench")
 check(world.combat_state.serialize()==inventory_before,"trial return preserves exact normal inventory and wallet")
 check(FileAccess.get_sha256(NORMAL_SAVE)==normal_hash,"isolated trial does not rewrite normal save bytes")
 check(not FileAccess.file_exists("user://bell_trial_return_m24.json"),"return record is consumed once")
 world.on_compiler_defeated(bell)
 check(not world.progress.get("preview_bell_defeated",false) and world.combat_state.capacity==6,"forged living-actor callback grants no reward")
 # Labelled reward fixture. It does not count as an Input-only combat victory.
 world.boss_active=true;bell.activated=true;bell.phase=2;bell._enter("recover",.7)
 check(bell.take_hit(18,hero.position.x,"storage_fixture"),"controlled lethal damage reaches genuine actor defeat callback")
 check(world.progress.preview_bell_defeated and not world.progress.get("boss_defeated",false),"miniboss receipt is distinct from final-world victory")
 check(world.combat_state.capacity==7 and not world.boss_arena.locked,"reward upgrades once and opens safe gates")
 var before_wallet: int=world.combat_state.wallet
 var definitions: Array=[]
 for coin in get_nodes_in_group("m22_coins"):
  if is_instance_valid(coin) and str(coin.get_meta("reward_id",""))=="miniboss:bell_warden":definitions.append(coin.definition.duplicate(true))
 var total:=0
 for entry in definitions:total+=int(entry.get("amount",0))
 check(not definitions.is_empty() and total==45,"reward creates actual45-total coin discs")
 for tick in range(600):
  var coins: Array=get_nodes_in_group("m22_coins")
  if coins.is_empty():break
  var nearest: Node2D=coins[0]
  for c in coins:
   if c.position.distance_to(hero.position)<nearest.position.distance_to(hero.position):nearest=c
  move_to(nearest.position.x)
  await step()
 release()
 check(world.combat_state.wallet==before_wallet+45,"ordinary movement/proximity credits physical45 coins")
 for entry in definitions:check(not world.collect_world_coin(entry),"claimed coin cannot pay twice")
 world.on_compiler_defeated(bell)
 check(world.combat_state.wallet==before_wallet+45 and world.combat_state.capacity==7,"repeated defeat cannot pay a second reward")
 var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(NORMAL_SAVE))
 check(saved.progress.preview_bell_defeated and int(saved.combat.capacity)==7 and int(saved.combat.wallet)==82,"real save retains the miniboss and collected rewards")
 hero.energy=0;world.combat_changed();await step(5)
 check(not world.hud.combat_display._has_polygon_area(PackedVector2Array([Vector2.ZERO,Vector2.ONE,Vector2(2,2)])),"empty-energy degenerate polygons are excluded from drawing")
 world._load_room(12,"left",Vector2(620,1260));await step(5)
 check(not is_instance_valid(world.registered_boss) and world.boss_arena.defeated,"defeated miniboss stays absent on room re-entry")
 check(world.progress.guard_clear and world.progress.compiler_seal_owned and world.progress.preview_compiler_defeated,"new receipt preserves old story progress after reward")
 current_scene=null
 await cleanup()
 for path in initial_files:
  if initial_files[path]==null:
   if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
  else:FileAccess.open(path,FileAccess.WRITE).store_buffer(initial_files[path])
 for path in initial_files:
  check((not FileAccess.file_exists(path)) if initial_files[path]==null else FileAccess.get_file_as_bytes(path)==initial_files[path],"isolated fixture restores previous bytes: "+path)
 var out: Dictionary={"checks":checks,"failures":failures,"scope":"Labelled save/reward fixtures with direct phase=2 and18 damage; actual controller trial/return and actual physical coin collection. Not full combat proof.","engine":Engine.get_version_info().string,"prior_files_restored":true}
 FileAccess.open("user://m25_integration_report.json",FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
 print("M25 INTEGRATION ",JSON.stringify(out))
 quit(0 if failures.is_empty() else 1)
