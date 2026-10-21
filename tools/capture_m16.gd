extends SceneTree
## Visual inspection fixtures, not a continuous stage walkthrough. Matched
## entrance looks precede ten room compositions and a genuine input-driven lift
## sequence. Gameplay route validation remains a separate world QA tool.

const OUTPUT := "res://previews/m16"
const REPORT := "res://M16_VISUAL_REVIEW.json"
const TITLE := "LAST LECTURE — M16 Environment Art & Lighting Review"
const WORLD_SCENE := "res://scenes/stage_01/forgotten_wing.tscn"
const FONT = preload("res://assets/fonts/DejaVuSans.ttf")
const COMPARISON_FRAMES := 180
const ROOM_FRAMES := 60
const SHOTS := [Vector2(220,1260),Vector2(1420,900),Vector2(1920,1260),Vector2(1560,1260),Vector2(780,1260),Vector2(1310,1260),Vector2(1210,1260),Vector2(350,1260),Vector2(2100,1620),Vector2(1100,1260)]

var world: Node2D
var captures: Array[String] = []
var failures: Array[String] = []
var physics_ticks: int = 0
var comparison_layer: CanvasLayer
var comparison_label: Label
var lift_rides: Array[Dictionary] = []
var lighting_snapshots: Array[Dictionary] = []
var save_path: String = ""
var previous_save: String = ""
var had_save: bool = false
var save_backed_up: bool = false

func _initialize() -> void:
	call_deferred("run_review")

func step(count: int) -> void:
	for tick in range(count):
		await physics_frame
		physics_ticks += 1

func press_interact() -> void:
	# A screenshot resumes after frame_post_draw. Re-align the input edge to
	# physics before pressing, just as the production actor/interactions poll it.
	await physics_frame
	physics_ticks += 1
	Input.action_press("interact")
	await step(3)
	Input.action_release("interact")
	await step(3)

func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := OUTPUT+"/"+filename+".png"
	var status := root.get_texture().get_image().save_png(path)
	if status != OK: failures.append("Could not capture "+path)
	captures.append(path)
	print("M16 VISUAL CAPTURE ",path)

func build_comparison_label() -> void:
	comparison_layer = CanvasLayer.new()
	comparison_layer.layer = 90
	root.add_child(comparison_layer)
	var backing := ColorRect.new()
	backing.position = Vector2(890,65)
	backing.size = Vector2(355,40)
	backing.color = Color(0.025,0.035,0.045,0.82)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	comparison_layer.add_child(backing)
	comparison_label = Label.new()
	comparison_label.position = Vector2(900,68)
	comparison_label.size = Vector2(335,34)
	comparison_label.add_theme_font_override("font",FONT)
	comparison_label.add_theme_font_size_override("font_size",17)
	comparison_label.add_theme_color_override("font_color",Color("d4d9cd"))
	comparison_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	comparison_layer.add_child(comparison_label)

func hold_current_frame() -> CanvasLayer:
	# Preserve the last rendered comparison image while the previous world's
	# audio/scene resources are released; avoid an empty-frame flash between looks.
	var layer := CanvasLayer.new()
	layer.layer = 100
	var image := TextureRect.new()
	image.texture = ImageTexture.create_from_image(root.get_texture().get_image())
	image.size = root.get_visible_rect().size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(image)
	root.add_child(layer)
	return layer

func make_world(revision: int) -> void:
	world = load(WORLD_SCENE).instantiate()
	if not save_backed_up:
		save_path = str(world.get_script().get_script_constant_map().get("SAVE_FILE", "user://forgotten_wing_m15.json"))
		had_save = FileAccess.file_exists(save_path)
		if had_save: previous_save = FileAccess.get_file_as_string(save_path)
		save_backed_up = true
	world.restore_saved_game = false
	world.visual_revision = revision
	root.add_child(world)
	# Comparison/capture fixtures do not need an introductory screen fade.
	# The game itself retains its normal transition behaviour.
	world.fade.visible = false

func freeze_matching_pose() -> void:
	world.gameplay_active = false
	world.elapsed = 0.0
	world.hero.set_physics_process(false)
	world.hero.lantern_sprite.play("unarmed_idle")
	world.hero.lantern_sprite.frame = 0
	world.hero.lantern_sprite.pause()
	world.camera.set_process(false)

func resume_world() -> void:
	world.gameplay_active = true
	world.hero.set_physics_process(true)
	world.hero.lantern_sprite.play()
	world.camera.set_process(true)

func close_world() -> void:
	Input.action_release("move_right")
	Input.action_release("move_left")
	Input.action_release("interact")
	if is_instance_valid(world):
		# Detach live audio streams before freeing their scene. This gives the
		# native audio thread a clean shutdown during offline movie recording.
		for player in world.find_children("*","AudioStreamPlayer",true,false):
			player.stop()
			player.stream = null
		await process_frame
		world.queue_free()
		await process_frame
		await process_frame
	world = null

func restore_original_save() -> bool:
	if not save_backed_up: return true
	if had_save:
		var file := FileAccess.open(save_path,FileAccess.WRITE)
		if file == null: return false
		file.store_string(previous_save)
		file.close()
		return FileAccess.get_file_as_string(save_path) == previous_save
	if FileAccess.file_exists(save_path): return DirAccess.remove_absolute(save_path) == OK
	return true

func run_review() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	build_comparison_label()
	make_world(15)
	world._load_room(0,"left",SHOTS[0])
	freeze_matching_pose()
	comparison_label.text = "M15  ·  BEFORE / قبل"
	await step(COMPARISON_FRAMES)
	await capture("00_entrance_before_m15")
	var held_before := hold_current_frame()
	await close_world()
	make_world(16)
	world._load_room(0,"left",SHOTS[0])
	freeze_matching_pose()
	comparison_label.text = "M16  ·  AFTER / بعد"
	held_before.queue_free()
	await step(COMPARISON_FRAMES)
	await capture("00_entrance_after_m16")
	comparison_layer.visible = false
	resume_world()
	for index in range(10):
		await process_frame
		world._load_room(index,"left",SHOTS[index])
		await step(18)
		var interaction_frames := 0
		if index in [4,5,6,8]:
			await press_interact()
			interaction_frames = 7
		await step(ROOM_FRAMES-18-interaction_frames)
		await capture("%02d_%s" % [index+1,world.data.mood])
		if is_instance_valid(world.lighting):
			var snapshot: Dictionary = world.lighting.diagnostics()
			snapshot.room = index
			lighting_snapshots.append(snapshot)
	# This last segment starts at the actual archive entry spawn. Walking and
	# riding use only actions; no hero position assignment or direct lift trigger.
	await process_frame
	world._load_room(3,"left")
	await step(30)
	Input.action_press("move_right")
	for tick in range(240):
		await step(1)
		if world.hero.position.x > 1105: break
	Input.action_release("move_right")
	await step(20)
	if absf(world.hero.position.x-world.elevator.position.x) > world.elevator.width/2-10:
		failures.append("Native lift segment did not walk onto the deck")
	for stop in range(3):
		var start_y: float = world.hero.position.y
		await press_interact()
		for tick in range(400):
			await step(1)
			if not world.elevator.moving and world.elevator.current_stop == stop+1: break
		await step(12)
		var arrived: bool = not world.elevator.moving and world.elevator.current_stop == stop+1
		var carried: bool = world.hero.is_on_floor() and absf(world.hero.position.y-world.elevator.position.y) < 2.0
		if not arrived or not carried: failures.append("Native lift ride failed at stop "+str(stop+1))
		lift_rides.append({"target_stop":stop+1,"hero_start_y":start_y,"hero_end_y":world.hero.position.y,"lift_end_y":world.elevator.position.y,"native_input_only":true,"arrived":arrived,"rider_grounded":carried})
	await capture("11_archive_native_lift")
	var save_preserved := restore_original_save()
	if not save_preserved: failures.append("Could not restore the pre-existing stage save")
	var report := {
		"title":TITLE,
		"godot":Engine.get_version_info().string,
		"captures":captures,
		"passed":failures.is_empty(),
		"failures":failures,
		"method":"Two matched, frozen-pose entrance inspection fixtures (M15 then M16), ten isolated M16 room compositions, then an actual-input walk and native elevator ride from the archive entry. Room loading and SHOTS are inspection fixtures, not a continuous input tour or progression proof.",
		"comparison":{"before_revision":15,"after_revision":16,"frames_each":COMPARISON_FRAMES,"same_room":0,"same_position":[SHOTS[0].x,SHOTS[0].y],"same_idle_frame":0},
		"room_fixture_count":10,
		"frames_per_room":ROOM_FRAMES,
		"physics_ticks":physics_ticks,
		"existing_save_preserved":save_preserved,
		"lighting_snapshots":lighting_snapshots,
		"lift_rides":lift_rides,
		"native_lift_segment_hero_teleports":0,
		"native_lift_end_y":world.hero.position.y,
		"native_lift_stop":world.elevator.current_stop
	}
	FileAccess.open(REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M16 VISUAL REVIEW ",JSON.stringify(report))
	await close_world()
	comparison_layer.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
