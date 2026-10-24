extends "res://tools/test_m24_bell.gd"
## Explicit presentation/containment fixtures; this is not a full combat win.
func run() -> void:
	await fresh()
	world.set_physics_process(false)
	world.set_process(false)
	hero.set_physics_process(false)
	bell.set_physics_process(false)
	world.gameplay_active=true
	check(is_equal_approx(world.BELL_SPEC.arena_rect.size.x,1080.0),"arena is 28 percent narrower than M24's1500px")
	check(world.boss_arena.gate_rects[0].end.x==1110 and world.boss_arena.gate_rects[1].position.x==2190,"physical gates match travelling wave endpoints")
	check(world.bell_impact.bursts.is_empty() and world.bell_impact.dust.is_empty() and world.bell_impact.papers.is_empty(),"no environmental response appears before an impact")
	world.on_bell_ground_impact(Vector2(1650,1260),2)
	check(world.bell_impact_count==0,"inactive encounter cannot trigger combat shake or debris")
	world.boss_active=true
	world.boss_arena.set_locked(true)
	world.hud.update_boss_status({"visible":true,"phase":1,"hp":18,"max_hp":18})
	world.hud.show_boss_intro()
	var clean:bool=world.hud.combat_display.visible
	for child in world.hud.canvas.get_children():
		if child==world.hud.combat_display or child==world.hud.modal or child==world.hud.modal_shade: continue
		if child is CanvasItem and child.visible: clean=false
	check(clean,"combat canvas contains only the top-left player vitals")
	world._open_panel("map");world._open_panel("journal")
	check(not world.hud.panel_open and world.gameplay_active,"map and journal cannot interrupt the active encounter")
	hero.position.x=1100;hero.velocity.x=-400
	world._constrain_bell_fighter()
	check(hero.position.x==1130 and hero.velocity.x==0,"left combat margin contains knockback")
	hero.position.x=2200;hero.velocity.x=400
	world._constrain_bell_fighter()
	check(hero.position.x==2170 and hero.velocity.x==0,"right combat margin contains dash endpoint")
	world.bell_impact.set_process(false)
	world.on_bell_ground_impact(Vector2(1650,1260),2)
	check(world.bell_impact_count==1 and world.bell_impact.bursts.size()==1 and world.bell_impact.dust.size()==24 and world.bell_impact.papers.size()==8,"actual callback produces bounded bilateral dust and paper")
	check(is_equal_approx(world.boss_trauma,1.15),"phase2 contact starts stronger bounded shake")
	world.gameplay_active=false
	var before:Dictionary=world.bell_impact.dust[0].duplicate(true)
	world.bell_impact._process(.5)
	check(world.bell_impact.dust[0]==before,"paused impact retains exact particle position and age")
	world.gameplay_active=true
	bell.phase=2
	world._update_compiler_presentation(0)
	check(world.hud.boss_display.phase_label.text.contains("الثاني") and not world.hud.boss_display.visible and not world.hud.boss_warning.visible,"phase2 state remains correct while opponent UI and warnings stay hidden")
	world.hud.language="en"
	world._update_compiler_presentation(0)
	check(world.hud.boss_display.phase_label.text.contains("PHASE II"),"English live HUD reflects real phase2")
	world.elapsed=.047
	world._update_compiler_presentation(.02)
	check(world.camera.offset.length()>0 and world.camera.offset.length()<=8.14,"post-contact camera reaction is visible and bounded")
	world._update_compiler_presentation(.23)
	check(is_zero_approx(world.boss_trauma) and world.camera.offset.is_zero_approx(),"contact shake ends in less than quarter second")
	world.bell_impact._process(1.3)
	check(world.bell_impact.dust.is_empty() and world.bell_impact.papers.is_empty() and world.bell_impact.bursts.is_empty(),"all cosmetic floor response expires")
	for i in range(10):world.on_bell_ground_impact(Vector2(1650,1260),2)
	check(world.bell_impact.dust.size()<=72 and world.bell_impact.papers.size()<=24 and world.bell_impact.bursts.size()<=3,"repeated contacts cannot accumulate unbounded effects")
	world.bell_impact.clear()
	check(world.bell_impact.dust.is_empty() and world.bell_impact.papers.is_empty(),"clear immediately removes cosmetic debris")
	world.boss_active=false
	world.hud.update_boss_status({"visible":false})
	check(world.hud.top_buttons.visible and world.hud.room_label.visible and world.hud.controls_label.visible,"exploration UI returns after the encounter")
	check(FileAccess.get_sha256("res://assets/warden_m20/warden_parts.png")=="6eca7436c7a8c39451256aa56db465d664df0d6dbb42d8e7f24122592b34bb66","approved hero source pixels preserved")
	check(FileAccess.get_sha256("res://assets/minibosses/m24/bell_character_parts.png")=="5e2e45ad2c3eaed31955aeae347929e0899a0de5d5d0a5a478caad4cf94c4d81","Bell source atlas pixels preserved")
	await cleanup()
	var out:Dictionary={"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"scope":"Direct fixtures for arena margins, real presentation callbacks, localized post-contact response, live Arabic/English phase HUD, pause/expiry/caps and immutable source atlases. Not full fight proof."}
	FileAccess.open("user://m25_presentation_report.json",FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
	print("M25 PRESENTATION ",JSON.stringify(out))
	quit(0 if failures.is_empty() else 1)
