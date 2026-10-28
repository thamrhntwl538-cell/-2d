extends SceneTree
## Transaction and live HUD contracts. No gameplay save files are touched.
const Shop = preload("res://scripts/shop/m28_shop.gd")
const State = preload("res://scripts/combat/m18_combat_state.gd")
const Hud = preload("res://scripts/ui/m28_hud.gd")
var checks: Array[Dictionary]=[]

class FixtureHero extends Node2D:
	var hp:=6

class FixtureWorld extends Node2D:
	var combat_state = preload("res://scripts/combat/m18_combat_state.gd").new()
	var progress: Dictionary={"visited":[4,6,12],"notes":[],"secrets":[],"book_inventory":[]}
	var hero: Node2D
	var boss_active:=false
	var gameplay_active:=true
	var data: Dictionary={"id":4,"title":"Black Flame Alcove","title_ar":"ركن الشعلة السوداء","size":Vector2(2800,1440),"objects":[{"id":"needle_page","kind":"note","pos":Vector2(1100,1260)}]}
	func combat_hud_context() -> Dictionary:
		var result: Dictionary=combat_state.serialize()
		result.merge({"hp":6,"max_hp":6,"energy":99,"max_energy":99,"used_capacity":combat_state.used_capacity(),"at_bench":false})
		return result
	func control_hint(action_name: String) -> String: return {"jump":"SPACE","attack":"J","dash":"K","heal":"H","spell":"L","interact":"E","stage_map":"M"}.get(action_name,action_name)
	func _object_visible(_definition: Dictionary) -> bool: return true
	func _requirements_met(_requirements: Variant) -> bool: return true

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String, detail: Variant=null) -> void:
	checks.append({"passed":ok,"name":label,"detail":detail})
	print(("PASS " if ok else "FAIL ")+label)

func _transactions() -> void:
	var progress: Dictionary={}
	var state:=State.new()
	Shop.sanitize(progress,state)
	check(progress[Shop.KEY].purchases.is_empty(),"New inventory starts with no purchases")
	var before:=JSON.stringify(state.serialize())
	var result:=Shop.purchase(progress,state,"atlas")
	check(result.code=="insufficient_funds" and state.wallet==0 and not Shop.owns(progress,state,"atlas"),"Insufficient coins leave tool and wallet untouched")
	check(JSON.stringify(state.serialize())==before,"Failed purchase leaves every combat field unchanged")
	state.wallet=100
	result=Shop.purchase(progress,state,"atlas")
	check(result.ok and result.spent==24 and state.wallet==76 and Shop.owns(progress,state,"atlas"),"Atlas is bought for exactly 24 collected coins")
	result=Shop.purchase(progress,state,"atlas")
	check(not result.ok and result.code=="owned" and state.wallet==76,"Repeated confirmation cannot charge twice")
	var saved: Dictionary=JSON.parse_string(JSON.stringify({"progress":progress,"combat":state.serialize()}))
	var restored:=State.new()
	restored.restore(saved.combat)
	var restored_progress: Dictionary=saved.progress
	Shop.sanitize(restored_progress,restored)
	check(Shop.owns(restored_progress,restored,"atlas") and restored.wallet==76,"Atlas survives real JSON save roundtrip")
	result=Shop.purchase(restored_progress,restored,"pagefinder")
	check(result.ok and restored.wallet==44 and Shop.owns(restored_progress,restored,"pagefinder"),"Pagefinder has an independent once-only receipt")
	restored.drop_on_death(4,Vector2(1900,1260))
	check(restored.wallet==0 and Shop.owns(restored_progress,restored,"atlas") and Shop.owns(restored_progress,restored,"pagefinder"),"Death drops coins while keeping purchased tools")
	check(restored.recover_drop()==44 and restored.wallet==44,"Purchased tools leave original lost-coin recovery unchanged")
	var acquired:=State.new()
	acquired.wallet=200
	acquired.acquire("wick")
	var fresh: Dictionary={}
	Shop.sanitize(fresh,acquired)
	result=Shop.purchase(fresh,acquired,"kindling")
	check(result.code=="owned" and acquired.wallet==200 and acquired.owned==["wick"],"World-acquired fitil is owned without charging at market")
	result=Shop.purchase(fresh,acquired,"stillness")
	check(result.ok and acquired.wallet==135 and acquired.owns_fitil("focus"),"Stillness purchase acquires the real existing fitil")
	check(acquired.equipped.is_empty() and is_equal_approx(acquired.focus_duration_multiplier(),1.0),"Buying a fitil never equips it or grants its effect away from a bench")
	check(not acquired.equip("focus",false) and acquired.equip("focus",true) and is_equal_approx(acquired.focus_duration_multiplier(),.8),"Purchased fitil uses unchanged bench-only equip and actual healing effect")
	result=Shop.purchase(fresh,acquired,"socket")
	check(result.ok and acquired.wallet==65 and acquired.capacity==4 and acquired.collected.has(Shop.SOCKET_CLAIM),"Spare ring expands actual capacity once")
	Shop.sanitize(fresh,acquired)
	result=Shop.purchase(fresh,acquired,"socket")
	check(result.code=="owned" and acquired.wallet==65 and acquired.capacity==4,"Ring cannot sell again after sanitize/re-entry")
	fresh.erase(Shop.KEY)
	Shop.sanitize(fresh,acquired)
	check(Shop.owns(fresh,acquired,"socket") and fresh[Shop.KEY].purchases.has("socket"),"Capacity receipt prevents reselling when progress block is missing")
	var capped:=State.new()
	capped.wallet=100
	capped.capacity=State.MAX_CAPACITY
	result=Shop.purchase({},capped,"socket")
	check(result.code=="capacity_limit" and capped.wallet==100 and capped.capacity==State.MAX_CAPACITY,"Capacity technical ceiling rejects transaction without charging")
	var full:=State.new()
	full.wallet=100
	for index in range(State.MAX_CLAIMS): full.collected.append("fixture:"+str(index))
	result=Shop.purchase({},full,"socket")
	check(not result.ok and full.wallet==100 and full.capacity==3,"Full durable-claim ledger cannot consume coins")
	var malformed: Dictionary={Shop.KEY:{"version":1,"purchases":["atlas","atlas",7,"untrusted_unknown",null,"pagefinder"]}}
	Shop.sanitize(malformed,State.new())
	check(malformed[Shop.KEY].purchases==["atlas","pagefinder"],"Malformed and duplicate purchase IDs are normalized")
	var deep:=Shop.catalog()
	deep[0].price=0
	check(Shop.definition("atlas").price==24,"UI catalog cannot mutate canonical prices")
	var invalid_progress: Dictionary={}
	var invalid_state:=State.new()
	invalid_state.wallet=100
	result=Shop.purchase(invalid_progress,invalid_state,"untrusted_unknown")
	check(result.code=="unknown_item" and invalid_progress.is_empty() and invalid_state.wallet==100,"Unknown item never mutates progression or wallet")

func _interface() -> void:
	var world:=FixtureWorld.new()
	root.add_child(world)
	world.hero=FixtureHero.new()
	world.hero.position=Vector2(700,1260)
	world.add_child(world.hero)
	var hud:=Hud.new()
	world.add_child(hud)
	hud.setup(world)
	await process_frame
	await process_frame
	var rooms: Array=[world.data.duplicate(true),{"id":6,"title_en":"Folded Archive","title_ar":"الأرشيف المطوي","objects":[{"kind":"bench"}]},{"id":12,"title_en":"The Bindery","title_ar":"مشغل التجليد","objects":[{"kind":"bench"}]}]
	var context: Dictionary={"progress":world.progress,"room":world.data,"rooms":rooms,"combat":world.combat_hud_context()}
	hud.open_panel("map",context)
	await process_frame
	check(hud.current_panel=="map" and not hud.modal.find_children("FreeWorldMap","Control",true,false).is_empty(),"Basic map opens before any purchase")
	hud.open_panel("shop",context)
	await process_frame
	await process_frame
	var offered:=hud.modal.find_children("ShopBuy_*","Button",true,false)
	check(offered.size()==5,"Native market presents all five real offers")
	var atlas: Button=hud.modal.find_child("ShopBuy_atlas",true,false)
	check(atlas!=null and not atlas.disabled and atlas.focus_mode==Control.FOCUS_ALL,"Unaffordable offer remains reachable by controller and keyboard")
	check(bool(hud.modal_body.get_parent().follow_focus),"Shop scroll follows controller focus to offers below the fold")
	var emitted: Array=[]
	hud.action.connect(func(action_id: String, value: Variant): emitted.append([action_id,value]))
	atlas.emit_signal("pressed")
	check(emitted==[["shop_buy","atlas"]],"Shop button emits item identity to world transaction owner")
	context.shop_error="insufficient_funds"
	hud.refresh_panel(context)
	await process_frame
	check(hud.modal_footer.find_children("*","Label",true,false).any(func(label): return label.text==Shop.feedback("insufficient_funds","ar")),"Insufficient-funds response remains visible in fixed footer")
	hud.set_language("en")
	hud.open_panel("shop",context)
	await process_frame
	check(hud.modal_title.text=="The Margin Market" and str(hud.modal.find_child("ShopBuy_atlas",true,false).text)=="Buy · 24","Market names and offers switch to English")
	world.combat_state.wallet=100
	Shop.purchase(world.progress,world.combat_state,"atlas")
	hud.open_panel("map",context)
	await process_frame
	var survey: Control=hud.modal.find_child("PurchasedSurveyMap",true,false)
	check(survey!=null and survey.annotated,"Bought atlas enables live discovered-room survey markers")
	hud.close_panel(true)
	Shop.purchase(world.progress,world.combat_state,"pagefinder")
	hud._update_page_needle()
	check(hud.page_needle.visible and hud.page_needle.direction.x>.9,"Purchased needle points toward nearby unread page")
	world.progress.notes.append("needle_page")
	hud._update_page_needle()
	check(not hud.page_needle.visible,"Reading target removes it from needle guidance")
	world.progress.notes.clear()
	world.boss_active=true
	hud._update_page_needle()
	check(not hud.page_needle.visible,"Combat suppresses exploration needle")
	world.boss_active=false
	hud.open_panel("journal",context)
	hud._update_page_needle()
	check(not hud.page_needle.visible,"Journal suppresses exploration needle")
	hud.close_panel(true)
	world.hero.position=Vector2(-500,1260)
	hud._update_page_needle()
	check(not hud.page_needle.visible,"Needle does not reveal distant pages across entire room")
	hud.open_panel("pause",context)
	await process_frame
	check(hud.modal.find_children("*","Button",true,false).any(func(button): return button.text=="Character and trial studio"),"Pause routes to current character/trial studio")
	check(hud.status_label.text=="M28 · The Folding Library","M28 world status replaces archived Bell build caption")
	check(hud.controls_label.text.contains("Drop through shelf"),"World control hint documents new shelf drop")
	world.queue_free()
	await process_frame

func _run() -> void:
	_transactions()
	await _interface()
	var failed:=checks.filter(func(record): return not record.passed).size()
	var report: Dictionary={"scope":"M28 shop transactions and native HUD","engine":Engine.get_version_info().string,"checks":checks,"passed":checks.size()-failed,"failed":failed,"total":checks.size(),"existing_gameplay_saves_touched":false}
	var output:=FileAccess.open("res://docs/M28_SHOP_QA.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	output.close()
	print("M28 SHOP %d/%d passed" % [checks.size()-failed,checks.size()])
	quit(0 if failed==0 else 1)
