extends SceneTree
## Independent loadout-view checks. The world fixture owns real CombatState;
## buttons and pad inputs only request changes through its validation callback.
const HUD=preload("res://scripts/ui/m29_hud.gd")
const State=preload("res://scripts/combat/m18_combat_state.gd")
const Hero=preload("res://scripts/combat/m28_player.gd")
var world: Node2D
var hud: CanvasLayer
var checks: Array[Dictionary]=[]
var actions: Array=[]

class FixtureWorld extends Node2D:
	var combat_state=preload("res://scripts/combat/m18_combat_state.gd").new()
	var progress: Dictionary={"weapon_owned":true,"visited":[1],"notes":[],"secrets":[],"book_inventory":[],"m28_shop":{"version":1,"purchases":["atlas"]}}
	var hero: Node2D
	var boss_active:=false
	var gameplay_active:=false
	var seated:=true
	var interior_kind:=""
	var controls=preload("res://scripts/combat/m18_controls.gd").new()
	var data: Dictionary={"id":1,"title":"First Page","title_ar":"بهو الصفحة الأولى","size":Vector2(2800,1440),"objects":[]}
	func combat_hud_context() -> Dictionary:
		var result: Dictionary=combat_state.serialize()
		result.merge({"hp":6,"max_hp":6,"energy":99,"max_energy":99,"used_capacity":combat_state.used_capacity(),"at_bench":seated})
		return result
	func control_hint(id: String) -> String:
		if controls.gamepad: return {"jump":"A","interact":"LB"}.get(id,id)
		return {"jump":"SPACE","attack":"J","dash":"K","heal":"H","spell":"L","interact":"E","stage_map":"M"}.get(id,id)
	func _object_visible(_definition: Dictionary) -> bool: return true
	func _requirements_met(_requirements: Variant) -> bool: return true

func _initialize() -> void: run.call_deferred()

func check(ok: bool,name: String,detail: Variant=null) -> void:
	checks.append({"passed":ok,"name":name,"detail":detail})
	print(("PASS " if ok else "FAIL ")+name)

func frames(n: int=1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame

func context() -> Dictionary:
	return {"combat":world.combat_hud_context(),"progress":world.progress,"state":world.progress,"room":world.data,"rooms":[world.data],"bench":{"seated":world.seated,"can_equip":world.seated,"saved":true,"state":"seated"}}

func on_action(id: String,value: Variant) -> void:
	actions.append([id,value])
	if id in ["equip_fitil","unequip_fitil"]:
		var changed: bool=world.combat_state.equip(str(value),world.seated) if id=="equip_fitil" else world.combat_state.unequip(str(value),world.seated)
		if changed: hud.refresh_panel(context())
	elif id=="bench_close": hud.close_panel()
	elif id=="language": hud.set_language(str(value))

func key(code: int) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await frames(2)
	event=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=false
	Input.parse_input_event(event)
	await frames(2)

func pad(code: int) -> void:
	var event:=InputEventJoypadButton.new()
	event.button_index=code
	event.pressed=true
	Input.parse_input_event(event)
	await frames(2)
	event=InputEventJoypadButton.new()
	event.button_index=code
	event.pressed=false
	Input.parse_input_event(event)
	await frames(2)

func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	image.save_jpg("/workspace/work/"+name+".jpg",.95)

func run() -> void:
	root.size=Vector2i(1280,720)
	world=FixtureWorld.new()
	root.add_child(world)
	world.hero=Hero.new()
	world.hero.world_ref=world
	world.hero.position=Vector2(890,620)
	world.add_child(world.hero)
	for id in ["wick","reach","focus"]: world.combat_state.acquire(id)
	world.combat_state.dash_owned=true
	world.combat_state.spell_owned=true
	hud=HUD.new()
	world.add_child(hud)
	hud.setup(world)
	hud.action.connect(on_action)
	await frames(3)
	check(not hud.panel_open and not hud.bench_shell.visible,"Loadout does not auto-open on creation")
	hud.open_panel("bench",context())
	await frames(25)
	check(hud.panel_open and hud.current_panel=="bench" and hud.bench_shell.visible,"Native seated sheet opens through the shared panel lifecycle")
	check(hud.get_bench_ui_snapshot().seated_permission,"Genuine seated context enables equipment requests")
	check(hud.bench_buttons.size()==3,"Fitil view uses the three real catalog entries")
	check(hud.bench_shell.position.x<100 and hud.bench_shell.get_global_rect().end.x<world.hero.global_position.x-40,"Sheet chooses the side opposite the actual hero")
	var rect: Rect2=hud.bench_shell.get_global_rect()
	check(rect.end.y<=root.size.y-8,"Complete sheet fits the viewport including footer",str(rect))
	check(not hud.objective_label.visible and not hud.top_buttons.visible and not hud.status_label.visible,"Bench screen hides exploration clutter and build text")
	check(root.gui_get_focus_owner()==hud.bench_buttons.wick,"First real owned fitil receives keyboard/controller focus")
	await pad(JOY_BUTTON_A)
	check(world.combat_state.has_fitil("wick") and world.combat_state.used_capacity()==1,"Actual controller confirm equips the focused owned fitil")
	check(int(hud.get_bench_ui_snapshot().used_capacity)==1,"Socket display updates from the authoritative equipment state")
	await key(KEY_ENTER)
	check(not world.combat_state.has_fitil("wick") and world.combat_state.used_capacity()==0,"Actual Enter removes a previously equipped fitil")
	await pad(JOY_BUTTON_DPAD_LEFT)
	check(hud.bench_selection=="reach","Actual D-pad navigation follows the visible Arabic icon row")
	await pad(JOY_BUTTON_A)
	check(world.combat_state.has_fitil("reach") and world.combat_state.used_capacity()==2,"Distinct cost-two fitil is equipped through the same request path")
	hud.bench_buttons.focus.grab_focus()
	await frames(2)
	var count:=actions.size()
	await pad(JOY_BUTTON_A)
	check(not world.combat_state.has_fitil("focus") and world.combat_state.used_capacity()==2 and actions.size()==count,"Insufficient capacity explains refusal without emitting a mutation request")
	check(not hud.get_bench_ui_snapshot().notice.is_empty(),"Capacity refusal is visible beside the selected description")
	check(hud.bench_detail_meta.text.contains("2") and hud.bench_notice_label.visible,"A refusal keeps the selected cost and collection status visible")
	check(hud.bench_shell.get_global_rect().end.y<=root.size.y-8,"Refusal feedback does not push the footer out of the screen")
	await capture("m29_bench_ui_fitils_ar")
	await pad(JOY_BUTTON_RIGHT_SHOULDER)
	check(hud.bench_tab=="inventory" and hud.current_panel=="bench","Actual shoulder button changes to the inventory tab without leaving the seat")
	var owned: Array=hud.get_bench_ui_snapshot().inventory_ids
	check(owned==["lantern","map","blade","dash","spell","atlas"],"Inventory lists real abilities and the bought atlas, never an unowned needle",owned)
	hud.set_language("en")
	await frames(4)
	check(hud.bench_tab=="inventory" and hud.bench_detail_title.text=="Warden's Lantern","Language switch retains tab and selection with English descriptions")
	await pad(JOY_BUTTON_DPAD_DOWN)
	await pad(JOY_BUTTON_DPAD_DOWN)
	check(hud.bench_inventory_selection=="spell","Actual D-pad reaches owned abilities below the first inventory row")
	var scroll: ScrollContainer=hud.bench_shell.find_child("BenchOwnedInventoryScroll",true,false)
	check(scroll.scroll_vertical>0,"Inventory scroll follows controller focus instead of hiding the selected item")
	await capture("m29_bench_ui_inventory_en")
	await key(KEY_TAB)
	check(hud.bench_tab=="fitils","Actual Tab returns to fitils without triggering journal or world actions")
	world.seated=false
	hud.refresh_panel(context())
	await frames(3)
	hud.bench_buttons.wick.grab_focus()
	await frames(2)
	count=actions.size()
	await pad(JOY_BUTTON_A)
	check(not hud.get_bench_ui_snapshot().seated_permission and actions.size()==count and not world.combat_state.has_fitil("wick"),"A stale panel cannot request equipping after seat permission is revoked")
	world.seated=true
	hud.refresh_panel(context())
	await frames(3)
	await pad(JOY_BUTTON_B)
	await frames(25)
	check(not hud.panel_open and not hud.bench_shell.visible and world.seated,"Actual cancel closes only the menu and retains the seated world state")
	check(actions.any(func(a):return a[0]=="bench_close") and not actions.any(func(a):return a[0]=="bench_stand"),"Menu cancel does not emit a stand request")
	hud.update_bench_rest(context())
	check(hud.bench_rest_hint.visible and hud.bench_rest_hint.text.contains("Y ·") and hud.bench_rest_hint.text.contains("A / LB"),"Seated rest hint follows the controller's actual open and rise controls")
	world.controls.gamepad=false
	hud.update_bench_rest(context())
	check(hud.bench_rest_hint.text.contains("I / Tab") and hud.bench_rest_hint.text.contains("SPACE / E"),"Seated rest hint switches back to the keyboard's actual controls")
	hud.open_panel("bench",context())
	await frames(22)
	var stand: Button=hud.bench_shell.find_child("BenchStand",true,false)
	stand.emit_signal("pressed")
	check(actions[-1][0]=="bench_stand","Explicit Stand Up emits a separate rise request")
	hud.close_panel(true)
	await frames(3)
	check(not hud.status_label.visible,"No implementation build label returns after closing the sheet")
	hud.update_bench_rest({"bench":{"state":"rising","seated":false}})
	await frames(3)
	check(not hud.top_buttons.visible and not hud.objective_label.visible and not hud.controls_label.visible,"Exploration clutter remains hidden through the rise animation")
	hud.update_bench_rest({"bench":{"state":"idle","seated":false}})
	await frames(3)
	check(hud.top_buttons.visible and hud.objective_label.visible and hud.controls_label.visible,"Exploration controls return only once standing is complete")
	world.interior_kind="market"
	hud.update_status(world.data,world.progress)
	await frames(4)
	check(not hud.title_label.visible and not hud.room_label.visible and not hud.objective_label.visible and not hud.top_buttons.visible and not hud.controls_label.visible,"A building interior hides stale outside objectives and persistent exploration chrome")
	check(hud.combat_display.visible and hud.hint_label.visible,"Interior quiet mode preserves vitals and the contextual interaction layer")
	await frames(4)
	check(not hud.objective_label.visible,"Inherited HUD process cannot flash the outside objective back into an interior")
	hud.open_panel("map",context())
	await frames(3)
	check(hud.current_panel=="map" and hud.modal.visible,"Map remains available while interior top buttons are hidden")
	hud.close_panel(true)
	world.interior_kind=""
	hud.update_status(world.data,world.progress)
	await frames(3)
	check(hud.title_label.visible and hud.room_label.visible and hud.objective_label.visible and hud.top_buttons.visible and hud.controls_label.visible,"Leaving the building restores the outside exploration UI")
	world.queue_free()
	await frames(4)
	var failed:=checks.filter(func(c):return not c.passed)
	var report: Dictionary={"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"passed":checks.size()-failed.size(),"failed":failed.size(),"scope":"Isolated real native HUD and CombatState. Actor position, owned items and seat state are explicit fixtures, not a full world sit animation or save integration test.","existing_saves_touched":false,"source_sha256":{"scripts/ui/m29_hud.gd":FileAccess.get_sha256("res://scripts/ui/m29_hud.gd"),"tools/test_m29_bench_ui.gd":FileAccess.get_sha256("res://tools/test_m29_bench_ui.gd")}}
	FileAccess.open("res://docs/M29_BENCH_UI_QA.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M29 BENCH UI %d/%d passed" % [checks.size()-failed.size(),checks.size()])
	quit(0 if failed.is_empty() else 1)
