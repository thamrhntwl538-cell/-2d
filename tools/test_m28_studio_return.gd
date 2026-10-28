extends SceneTree
## Review/trial routing keeps the world loadout and return anchor unchanged.
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func step(count:=1) -> void:
	for unused in range(count):
		await physics_frame
		await process_frame
func check(value: bool, caption: String) -> void:
	checks+=1
	if not value: failures.append(caption);push_error(caption)
func key(code: int) -> void:
	var event:=InputEventKey.new()
	event.keycode=code;event.physical_keycode=code;event.pressed=true
	Input.parse_input_event(event)
	await step(2)
	event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=false
	Input.parse_input_event(event)
	await step(4)
func run() -> void:
	check(OS.get_environment("XDG_DATA_HOME").contains("m28_studio_userdata"),"studio fixtures use isolated userdata")
	if not failures.is_empty():quit(1);return
	var world: Node2D=load("res://scenes/stage_01/folding_library_m28.tscn").instantiate()
	world.restore_saved_game=false
	root.add_child(world);current_scene=world
	await step(8)
	world.hero.hp=3;world.hero.energy=19;world.combat_state.wallet=27
	world.hero.last_safe_position=Vector2(360,1260)
	world._enter_boss_trial()
	await step(8)
	check(current_scene.has_method("get_review_snapshot"),"world pause opens original supplied-art catalog")
	check(has_meta("m28_studio_return"),"catalog retains explicit transient world route")
	await key(KEY_B)
	check(current_scene.get_script().resource_path.ends_with("m24_character_review.gd"),"catalog still reaches original Bell review")
	await key(KEY_ESCAPE)
	check(current_scene.has_method("get_review_snapshot"),"Bell review Escape returns to supplied-art catalog")
	await key(KEY_ESCAPE)
	await step(8)
	world=current_scene
	check(world.has_method("get_m28_world_snapshot"),"catalog Escape returns to actual M28 world")
	check(world.hero.hp==3 and is_equal_approx(world.hero.energy,19) and world.combat_state.wallet==27,"studio return preserves actual health, energy and inventory")
	check(world.current_room==1 and absf(world.hero.position.x-360)<2,"studio return restores same safe exploration anchor")
	check(not has_meta("m28_studio_return") and not has_meta("m28_studio_anchor"),"return routing is consumed without a global stale marker")
	current_scene=null
	root.remove_child(world);world.free()
	await step(10)
	OS.delay_msec(180)
	var report:={"checks":checks,"failures":failures,"engine":Engine.get_version_info().string}
	FileAccess.open("user://m28_studio_return_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M28 STUDIO ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
