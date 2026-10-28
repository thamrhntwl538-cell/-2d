extends "res://tools/capture_m28_world.gd"
## Independent native integration audit. Deliberate room/equipment/wallet starts
## are labelled fixtures. UI opens, selection, language and purchases use input.
const ShopAudit=preload("res://scripts/shop/m28_shop.gd")
const JourneyAudit=preload("res://scripts/stage/m28_journey.gd")
var checks:=0
var audit_events: Array[Dictionary]=[]
var backups: Dictionary={}

func check(ok: bool, label: String) -> bool:
	checks+=1
	if not ok:
		failures.append(label)
		print("M28 INDEPENDENT FAIL ",label)
	return ok

func backup_files() -> void:
	for path in [JourneyAudit.SAVE_PATH,JourneyAudit.SESSION_PATH,"user://folding_library_m18_settings.cfg","user://folding_library_m18_controls.cfg"]:
		backups[path]=FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func restore_files() -> void:
	for path in backups:
		if backups[path]==null:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else: FileAccess.open(path,FileAccess.WRITE).store_buffer(backups[path])
		check(not FileAccess.file_exists(path) if backups[path]==null else FileAccess.get_file_as_bytes(path)==backups[path],"original file bytes restored: "+path)

func joy(button: int) -> void:
	var event:=InputEventJoypadButton.new()
	event.button_index=button
	event.pressed=true
	Input.parse_input_event(event)
	await step(3)
	event=InputEventJoypadButton.new()
	event.button_index=button
	event.pressed=false
	Input.parse_input_event(event)
	await step(12)

func button(name: String) -> Button:
	return world.hud.modal_body.find_child(name,true,false) as Button

func walk_to(x: float, limit: int=120) -> bool:
	for tick in range(limit):
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(hero.position.x-x)<5 and absf(hero.velocity.x)<3:
			return true
		var braking: float=hero.velocity.x*hero.velocity.x/(2.0*2650.0)
		if absf(x-hero.position.x)>maxf(4,braking+3): Input.action_press("move_right" if x>hero.position.x else "move_left")
		await step()
	release()
	return false

func close_modal() -> void:
	await physical_key(KEY_ESCAPE)
	await step(35)
	check(not world.hud.panel_open and world.gameplay_active,"Escape completes native modal close and resumes world")

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Native independent audit needs an actual display")
		quit(1)
		return
	root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	DirAccess.make_dir_recursive_absolute("user://")
	backup_files()
	var packed: PackedScene=load(WORLD_SCENE)
	world=packed.instantiate()
	if not check(world.get_script()!=null and world.has_method("_load_room"),"M28 world controller and every native dependency compile"):
		world.free()
		restore_files()
		quit(1)
		return
	world.restore_saved_game=false
	root.add_child(world)
	current_scene=world
	await step(55)
	hero=world.hero
	check(world.current_room==1 and hero.is_on_floor(),"fresh M28 world starts physically supported in area1")
	check(hero.hp==6 and world.combat_state.wallet==0,"fresh world uses six lanterns and zero coins")
	check(FileAccess.get_sha256("res://assets/warden_m20/warden_parts.png")=="6eca7436c7a8c39451256aa56db465d664df0d6dbb42d8e7f24122592b34bb66","approved hero art remains byte-identical")
	check(world.save_path()==JourneyAudit.SAVE_PATH,"M28 uses its own durable save path")
	for id in range(1,16):
		world._load_room(id)
		await step(15)
		check(world.current_room==id and hero.is_on_floor() and hero.hp>0,"area%d left entrance physically supports a living hero" % id)
		check(is_instance_valid(world.visuals) and world.visuals.get_script().resource_path.ends_with("m28_room_visuals.gd"),"area%d uses new world visual provider" % id)
		check(not world.boss_active,"area%d arrival never auto-starts an offscreen boss" % id)
		print("M28 AUDIT AREA ",id," supported=",hero.is_on_floor()," hp=",hero.hp)
	check(not world.progress.get("boss_defeated",false) and not world.progress.get("miniboss_archivist_defeated",false) and not world.progress.get("miniboss_bell_defeated",false),"room inspection does not fabricate victories or world departure")
	# Native market input from a configured room4 landing. No free currency is
	# granted until after the insufficient-funds case is checked.
	await fixture_room(4,Vector2(1920,1260))
	check(await walk_to(2040),"ordinary movement reaches the actual market prop")
	release()
	await physical_key(KEY_E)
	await step(40)
	check(world.hud.panel_open and world.hud.current_panel=="shop" and not world.gameplay_active,"actual E opens the real market and freezes gameplay")
	var before: float=world.elapsed
	var old_position: Vector2=hero.position
	await step(20)
	check(is_equal_approx(world.elapsed,before) and hero.position.is_equal_approx(old_position),"native shop freezes hazard clock and hero position")
	var atlas:=button("ShopBuy_atlas")
	if check(atlas!=null and not atlas.disabled,"unaffordable atlas remains reachable and explains the failure"):
		atlas.grab_focus()
		await joy(JOY_BUTTON_A)
		check(world.combat_state.wallet==0 and not ShopAudit.owns(world.progress,world.combat_state,"atlas"),"controller attempt without coins cannot charge or grant an item")
		check(str(world._panel_context().get("shop_feedback",""))=="insufficient_funds","insufficient funds reaches the native feedback context")
		await screenshot("20_market_insufficient_funds","Configured room4 supported start. Actual E and controller A inputs; original zero-wallet failure path.")
	# This explicit wallet fixture isolates purchase/UI correctness. It is not
	# advertised as coins earned in a continuous exploration recording.
	world.combat_state.wallet=200
	world.hud.refresh_panel(world._panel_context())
	await step(8)
	atlas=button("ShopBuy_atlas")
	if check(atlas!=null,"atlas offer exists after balance fixture"):
		atlas.grab_focus()
		await joy(JOY_BUTTON_A)
		check(ShopAudit.owns(world.progress,world.combat_state,"atlas") and world.combat_state.wallet==176,"actual controller A buys atlas for exactly24 coins")
		check(button("ShopBuy_atlas").disabled,"owned atlas becomes disabled against repeat purchase")
		check(str(world._panel_context().get("shop_feedback",""))=="purchased","successful purchase receives a native feedback response")
	var stored: Variant=JSON.parse_string(FileAccess.get_file_as_string(JourneyAudit.SAVE_PATH))
	check(stored is Dictionary and int(stored.get("combat",{}).get("wallet",-1))==176,"world save commits the purchase and deducted wallet together")
	var initial_language: String=world.hud.language
	await physical_key(KEY_F2)
	await step(10)
	check(world.hud.language!=initial_language and world.hud.current_panel=="shop","F2 changes shop language while keeping the open market")
	check(world.hud.modal_title.text==("The Margin Market" if world.hud.language=="en" else "دكان الهامش"),"market title is authored in the selected language")
	await screenshot("21_native_market_purchase","Configured room4 and200-coin wallet fixture. Real E/controllerA/F2 inputs, permanent atlas ownership and live native market UI.")
	await physical_key(KEY_F2)
	await step(8)
	var reached_last:=false
	for i in range(8):
		var focused: Control=root.gui_get_focus_owner()
		if is_instance_valid(focused) and str(focused.get_meta("shop_item",""))=="stillness":
			reached_last=true
			break
		await joy(JOY_BUTTON_DPAD_DOWN)
	check(reached_last,"actual controller D-pad reaches the last shop offer through the scroll view")
	if reached_last:
		var last: Button=button("ShopBuy_stillness")
		var visible_bounds:=Rect2(Vector2.ZERO,Vector2(root.size))
		check(visible_bounds.encloses(last.get_global_rect()),"focused last offer is visible inside the native viewport")
		await screenshot("24_market_controller_scroll","Actual controller D-pad scrolls to the last native offer. No additional purchase or currency change.")
	await close_modal()
	await physical_key(KEY_M)
	await step(35)
	check(world.hud.panel_open and world.hud.current_panel=="map","actual M opens native world map")
	check(world.hud.modal_body.find_child("PurchasedSurveyMap",true,false)!=null,"purchased atlas really replaces the free map with annotated renderer")
	await screenshot("22_annotated_world_map","Native M opens purchased atlas. All-area visit list comes from explicit room-start fixtures in this audit; no continuous discovery claim.")
	await close_modal()
	# Read a physical raised page, then open the collected journal with N.
	await fixture_room(1,Vector2(1170,1140))
	await physical_key(KEY_E)
	await step(30)
	check(world.hud.panel_open and world.hud.current_panel=="note" and world.progress.get("notes",[]).has("entrance_note"),"actual E reads the physical raised entry page and records its ID")
	await close_modal()
	await physical_key(KEY_N)
	await step(35)
	check(world.hud.panel_open and world.hud.current_panel=="journal","actual N opens the complete collected journal")
	check(not world.hud._journal_entries().is_empty(),"journal contains the newly read physical page")
	await screenshot("23_native_collected_journal","Configured supported reading-shelf start. Actual E reads the existing physical page, then N opens its collected native journal.")
	await close_modal()
	check(not world.progress.get("world1_departed",false),"all UI audits preserve the one-way world departure state")
	release()
	world.gameplay_active=false
	stop_audio(world)
	OS.delay_msec(180)
	current_scene=null
	world.queue_free()
	await step(4)
	restore_files()
	var report: Dictionary={"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"display_server":DisplayServer.get_name(),"scope":"Independent native all15-area supported-start audit, real marketE/controllerA/languageF2/mapM/journalN inputs. Later room positions, all-area visit list and200-coin purchase wallet are explicit fixtures, not an unbroken playthrough or boss wins.","shots":shots,"source_sha256":source_hashes(),"physics_ticks":ticks,"prior_files_restored":true}
	FileAccess.open("res://docs/M28_INDEPENDENT_QA.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	FileAccess.open(OUTPUT+"/native_ui_capture_metadata.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M28 INDEPENDENT REPORT ",checks," checks failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
