extends SceneTree
## Rendered visual fixtures only. These shots do not substitute for the
## continuous input-driven traversal in test_m17_world.gd.
const WORLD_PATH := "res://scenes/stage_01/folding_library.tscn"
const OUTPUT := "res://previews/m17"
const REPORT := "user://m17_visual_review.json"
var world: Node2D
var captures: Array[Dictionary] = []
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_capture")

func stop_audio(node: Node) -> void:
	for child in node.get_children(): stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null

func step(count: int) -> void:
	for tick in range(count): await physics_frame

func pulse(key: String) -> void:
	await physics_frame
	Input.action_press(key)
	await step(3)
	Input.action_release(key)
	await step(3)

func capture(id: int, tag: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = OUTPUT + "/%02d_%s.png" % [id,tag]
	var image: Image = root.get_texture().get_image()
	if image.is_empty():
		failures.append("Empty viewport " + path)
		return
	var status: Error = image.save_png(path)
	if status != OK: failures.append("Failed to save " + path)
	captures.append({"room":id,"path":path,"width":image.get_width(),"height":image.get_height(),"fixture":true})
	print("M17 CAPTURE ",path)

func choose_shot(definition: Dictionary) -> Vector2:
	var room_id: int = int(definition.id)
	if room_id==1: return Vector2(float(definition.size.x)*0.47-180,float(definition.floor_y))
	if room_id==4:
		for item in definition.objects:
			if item.kind=="dialogue": return item.pos-Vector2(170,0)
	if room_id==9: return Vector2(1220,1140)
	if room_id==12: return Vector2(1600,float(definition.floor_y))
	if room_id==14: return Vector2(float(definition.size.x)*0.5-150,float(definition.floor_y))
	if room_id==15: return Vector2(float(definition.size.x)-400,float(definition.floor_y))
	var desired: Vector2 = Vector2(float(definition.size.x)*0.48, float(definition.floor_y))
	if int(definition.id)==6:
		for item in definition.objects:
			if item.kind=="bench": return item.pos + Vector2(120,0)
	if int(definition.id)==9:
		for item in definition.objects:
			if item.kind=="output_control": return item.pos + Vector2(100,0)
	if int(definition.id)==10:
		for item in definition.objects:
			if item.kind=="balance_control": return item.pos + Vector2(270,0)
	var closest: Vector2 = definition.spawns.get("left", desired)
	var distance: float = INF
	for surface in definition.platforms:
		var rect: Rect2 = surface.rect
		if absf(rect.position.y-desired.y)>200.0: continue
		var point: Vector2 = Vector2(clampf(desired.x, rect.position.x+35,rect.end.x-35),rect.position.y)
		var score: float = point.distance_to(desired)
		if score < distance:
			distance = score
			closest = point
	return closest

func run_capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var scene: PackedScene = load(WORLD_PATH)
	if scene==null:
		print("M17 capture scene missing")
		quit(1)
		return
	world = scene.instantiate()
	scene = null
	world.restore_saved_game = false
	world.environment_preview = true
	world.transition_seconds = 0.001
	root.add_child(world)
	await step(40)
	for key in ["ink_route_solved","books_collected","book_order_verified","output_open","balance_bridge_locked","archive_return_open","workshop_main_passage_open","workshop_archive_return_open","guard_approach_return_open"]:
		world.progress[key] = true
	world.progress.book_inventory = ["TRIANGLE","SQUARE","CIRCLE"]
	world.progress.book_order = ["TRIANGLE","SQUARE","CIRCLE"]
	var shots: Array = [[1,"first_page"],[4,"black_flame_alcove"],[6,"folded_archive"],[9,"output_stair"],[10,"balance_hall"],[12,"bindery"],[14,"tribunal"],[15,"next_page"]]
	for shot in shots:
		world._load_room(int(shot[0]),"left")
		var point: Vector2 = choose_shot(world.data)
		world.hero.position = point
		world.hero.velocity = Vector2.ZERO
		world.camera.position = world.camera.bounded(point+Vector2(130,-230))
		world.camera.reset_smoothing()
		await step(45)
		if world.get("fade") != null: world.fade.visible = false
		if world.hud.panel_open: world.hud.close_panel()
		await capture(int(shot[0]),str(shot[1]))
	# Separate UI and landmark fixtures. These deliberately configure the viewing
	# location, then exercise the same E and language action path as the player.
	world._load_room(6,"left",Vector2(850,1260))
	await step(35)
	await capture(6,"archive_reading_tier")
	world._load_room(9,"left",Vector2(1800,900))
	await step(35)
	await capture(9,"output_upper")
	world._load_room(4,"left",Vector2(960,1260))
	world.hud.language = "ar"
	await step(20)
	await pulse("interact")
	await capture(4,"dialogue_ar")
	world.hud.action.emit("language","en")
	await step(10)
	await capture(4,"dialogue_en")
	world.hud.action.emit("close_panel",null)
	await step(5)
	world.progress.ink_route_solved = false
	world._load_room(3,"left",Vector2(850,1260))
	world.hud.language = "ar"
	await step(20)
	await pulse("interact")
	await capture(3,"ink_puzzle_panel")
	world.hud.action.emit("close_panel",null)
	await step(5)
	world.progress.visited = range(1,16)
	world.toggle_map()
	await step(10)
	await capture(3,"world_map_panel")
	world.hud.action.emit("close_panel",null)
	await step(5)
	world._load_room(15,"left",Vector2(2670,1260))
	await step(20)
	await pulse("interact")
	await capture(15,"departure_confirmation")
	world.hud.action.emit("close_panel",null)
	await step(5)
	world.hud.action.emit("journal",null)
	await step(10)
	await capture(15,"journal_panel")
	stop_audio(world)
	await process_frame
	world.queue_free()
	world = null
	await process_frame
	await process_frame
	FileAccess.open(REPORT,FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"rendered":true,"captures":captures,"failures":failures,"scope":"configured visual fixtures; actual traversal is separate"},"\t"))
	OS.delay_msec(40)
	await process_frame
	quit(0 if failures.is_empty() else 1)
