extends SceneTree
## Rendered M18 review fixtures. These deliberately place actors and inventory;
## the sword/focus pictures use real Input actions. They are not traversal proof.
const WORLD_PATH := "res://scenes/stage_01/folding_library_m18.tscn"
const OUTPUT := "res://previews/m18"
const REPORT := "user://m18_visual_review.json"
var world: Node2D
var captures: Array[Dictionary] = []
var failures: Array[String] = []
var user_backups: Dictionary = {}
var original_user_files: Array[String] = []

func _initialize() -> void:
	call_deferred("run_capture")

func step(count: int) -> void:
	for tick in range(count): await physics_frame

func stop_audio(node: Node) -> void:
	for child in node.get_children(): stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null

func remember_files() -> void:
	var directory := DirAccess.open("user://")
	if directory == null: return
	for name in directory.get_files():
		original_user_files.append(name)
		if "m18" in name.to_lower(): user_backups[name] = FileAccess.get_file_as_bytes("user://"+name)

func restore_files() -> bool:
	var directory := DirAccess.open("user://")
	if directory == null: return user_backups.is_empty()
	for name in user_backups:
		if name == REPORT.get_file(): continue
		var file := FileAccess.open("user://"+name,FileAccess.WRITE)
		if file: file.store_buffer(user_backups[name])
	for name in directory.get_files():
		if "m18" in name.to_lower() and name != REPORT.get_file() and not original_user_files.has(name):
			DirAccess.remove_absolute("user://"+name)
	for name in user_backups:
		if FileAccess.get_file_as_bytes("user://"+name) != user_backups[name]: return false
	return true

func capture(tag: String, note: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	var path: String = OUTPUT + "/" + tag + ".jpg"
	if frame.is_empty():
		failures.append("Empty rendered viewport " + tag)
		return
	DirAccess.make_dir_recursive_absolute("user://m18_capture_sources")
	frame.save_png("user://m18_capture_sources/"+tag+".png")
	if frame.save_jpg(path,0.90) != OK: failures.append("Cannot write " + path)
	captures.append({"path":path,"room":world.current_room,"width":frame.get_width(),"height":frame.get_height(),"configured_fixture":true,"note":note})
	print("M18 CAPTURE ",path)

func fixture_room(id: int, at: Vector2) -> void:
	if world.hud.panel_open:
		world.hud.action.emit("close_panel",null)
		await step(3)
	world.progress.weapon_owned = true
	world.combat_state.dash_owned = true
	world.combat_state.spell_owned = true
	world._load_room(id,"left",at)
	world.hero.has_blade = true
	world.hero.has_dash = true
	world.hero.has_code_slash = true
	world.hero.velocity = Vector2.ZERO
	world.camera.position = world.camera.bounded(at+Vector2(180,-230))
	world.camera.reset_smoothing()
	await step(15)
	if world.get("fade") != null: world.fade.visible = false

func run_capture() -> void:
	remember_files()
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var scene: PackedScene = load(WORLD_PATH)
	if scene == null:
		failures.append("M18 scene missing")
		quit(1)
		return
	world = scene.instantiate()
	scene = null
	world.restore_saved_game = false
	world.environment_preview = true
	world.transition_seconds = 0.001
	root.add_child(world)
	await step(40)
	await fixture_room(2,Vector2(1035,1260))
	world.hud.language = "ar"
	var enemy: Node2D
	for actor in world.enemies:
		if is_instance_valid(actor):
			enemy = actor
			break
	if is_instance_valid(enemy):
		enemy.position = Vector2(1200,1260)
		enemy.entry_grace = 100.0
		enemy.direction = -1
		enemy.state = "crawl"
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	world.hero.hp = 6
	world.hero.energy = 77.0
	await step(18)
	await capture("01_first_larva","Configured encounter composition; native actor, original art and live six-heart/shared-energy HUD.")
	if is_instance_valid(enemy):
		enemy.position = Vector2(1150,1260)
		world.hero.position = Vector2(1065,1260)
		world.hero.facing = 1
		world.hero.energy = 33.0
		await step(3)
		Input.action_press("attack")
		await step(2)
		Input.action_release("attack")
		await step(7)
		await capture("02_sword_contact","Configured target; actual attack Input produces the native sword contact pose and hit response.")
		await step(30)
		enemy.hp = 3
		enemy.invulnerable = 0.0
		enemy.position = Vector2(1150,1260)
		world.hero.position = Vector2(1150,1175)
		world.hero.velocity = Vector2.ZERO
		Input.action_press("look_down")
		Input.action_press("attack")
		await step(10)
		Input.action_release("attack")
		Input.action_release("look_down")
		await capture("03_downward_pogo","Configured airborne start; real downward attack Input, native damage acceptance and pogo response.")
	await fixture_room(1,Vector2(1250,1260))
	world.hero.hp = 4
	world.hero.energy = 99.0
	Input.action_press("heal")
	await step(26)
	# Focus behavior is exercised in the native mechanics suite; the public
	# review contains six representative screenshots to keep download size small.
	Input.action_release("heal")
	await step(5)
	await fixture_room(1,Vector2(330,1260))
	for id in ["wick","reach","focus"]: world.combat_state.acquire(id)
	world.combat_state.equip("wick",true)
	world.combat_state.equip("focus",true)
	world.hero.energy = 66.0
	await step(5)
	Input.action_press("interact")
	await step(2)
	Input.action_release("interact")
	await step(7)
	world.hud.action.emit("fitils",null)
	await step(10)
	await capture("05_fitils_ar","Configured owned inventory, then ordinary bench interaction and native loadout UI; Arabic.")
	world.hud.action.emit("language","en")
	await step(10)
	await capture("06_fitils_en","Same native loadout panel and state after actual language action; English.")
	world.hud.action.emit("controls",null)
	await step(10)
	await capture("07_controls","Native controls/remapping panel; keyboard and gamepad both bind to the same gameplay actions.")
	for action in ["attack","look_down","heal","interact"]:
		if InputMap.has_action(action): Input.action_release(action)
	stop_audio(world)
	# Let the real-time Dummy mixer release its stopped ambient voice.
	OS.delay_msec(120)
	await process_frame
	world.queue_free()
	world = null
	await process_frame
	await process_frame
	var restored: bool = restore_files()
	if not restored: failures.append("Original save/settings files were not restored")
	var report := {"engine":Engine.get_version_info().string,"rendered":true,"captures":captures,"failures":failures,"save_restored":restored,"scope":"configured visual fixtures only; input-driven mechanics are separately checked by test_m18_combat.gd"}
	FileAccess.open(REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	OS.delay_msec(50)
	await process_frame
	quit(0 if failures.is_empty() else 1)
