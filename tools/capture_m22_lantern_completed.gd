extends "res://tools/test_m22_lantern_route.gd"
## Visual-only finished-state fixture after the foreground/nook refinement.
## This does not replace the actual-input route proof. See its separate report.

func run_checks() -> void:
	remember_user_files()
	phase = "finished-state visual fixture; no gameplay claim"
	var visual_path := ""
	if check(DisplayServer.get_name() != "headless", "capture uses a native renderer") and await make_world():
		world.progress.margin_lantern_solved = true
		world.progress.lantern_sequence_history = [1,0,2]
		world.progress.lantern_sequence_step = 3
		world.progress.notes = ["margin_lantern_clue","margin_lantern_record"]
		world.combat_state.wallet = 15
		world._load_room(5,"left",Vector2(1780,780))
		hero = world.hero
		world.arrival_title.dismiss()
		await step(160)
		await capture("m22_lantern_completed_final")
		visual_path = captures[-1] if not captures.is_empty() else ""
		check(hero.is_on_floor() and absf(hero.position.y-780)<3, "finished-state fixture is supported by the actual shelf")
	release_controls()
	if is_instance_valid(world):
		stop_audio(world)
		OS.delay_msec(120)
		await step(2)
		world.queue_free()
		world = null
		await step(4)
	phase = "fixture cleanup"
	check(restore_user_files(), "existing saves and settings restored exactly")
	var report := {"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,
		"fixture":true,"scope":"native finished-state visual fixture after appearance-only changes; lamps, wallet and reading progress are configured for this image",
		"gameplay_evidence":"docs/M22_LANTERN_ROUTE_REPORT.json records the separately verified real input route, retries, reward and disk reload",
		"image":visual_path}
	var output := FileAccess.open("user://m22_lantern_visual_fixture_report.json",FileAccess.WRITE)
	if output:
		output.store_string(JSON.stringify(report,"\t"))
		output.close()
	print("M22_LANTERN_VISUAL_FIXTURE ",JSON.stringify(report))
	OS.delay_msec(50)
	await process_frame
	quit(0 if failures.is_empty() else 1)
