extends SceneTree
## Native art review, not a fight test. Hero and boss physics are deliberately
## frozen to inspect every real pose against the actual M23 arena and camera.
## This subclass suppresses saves, so capturing cannot alter a player's run.
const World = preload("res://scripts/stage/m23_folding_library.gd")
const ATLAS_PATH := "res://assets/bosses/m23/compiler_profile_rig_atlas.png"
const ATLAS_SHA256 := "bf7d5ded2b9422f07ce2d7fa6863d9447564902ffed0d3da7fbb1f2516c09bf8"
const OUTPUT := "user://m23_art_review"

class ArtReviewWorld extends World:
	func _save() -> void: pass
	func _save_settings() -> void: pass
	func _restore_settings() -> void: pass

var world: Node2D
var boss: Node2D
var checks: int = 0
var failures: Array[String] = []
var captures: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run_review")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		print("FAIL ",description)

func step(count: int) -> void:
	for tick in range(count): await physics_frame
	await process_frame

func pose(state: String, progress: float, phase_number: int = 1) -> void:
	boss.state = state
	boss.state_duration = 1.0
	boss.state_time = 1.0 - progress
	boss.warning_fraction = progress if state.ends_with("_warning") else 0.0
	boss.phase = phase_number
	boss.age += 0.2
	boss._update_visual()
	boss.queue_redraw()
	await step(4)

func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered: Image = root.get_texture().get_image()
	var target: String = OUTPUT.path_join(filename + ".jpg")
	check(rendered.save_jpg(target, 0.96) == OK, "native image saved: " + filename)
	captures.append({"file": target, "state": boss.state, "phase": boss.phase, "held_blade_visible": boss.visual.is_held_blade_visible()})
	print("ART_CAPTURE ",ProjectSettings.globalize_path(target))

func stop_audio_recursive(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.stop()
		node.stream = null
	for child in node.get_children():
		stop_audio_recursive(child)

func run_review() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run this capture tool with a native display, without --headless.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	check(FileAccess.get_sha256(ATLAS_PATH) == ATLAS_SHA256, "active profile atlas remains byte-identical to the generated output")
	world = ArtReviewWorld.new()
	world.restore_saved_game = false
	world.is_boss_trial = true
	root.add_child(world)
	await step(50)
	world.hero.position = Vector2(1750, 1440)
	world.hero.velocity = Vector2.ZERO
	world.hero.set_physics_process(false)
	world._check_compiler_entry()
	boss = world.registered_boss
	check(is_instance_valid(boss) and is_instance_valid(boss.visual), "actual trial creates the real boss and visual rig")
	if not is_instance_valid(boss) or not is_instance_valid(boss.visual):
		quit(1)
		return
	boss.set_physics_process(false)
	if is_instance_valid(world.boss_music): world.boss_music.set_muted(true)
	await step(100)
	check(world.camera.zoom.is_equal_approx(Vector2(0.78, 0.78)), "review uses the actual arena camera framing")
	check(is_equal_approx(boss.visual.get_body_bounds().position.y, -300.0), "crown-to-floor art height remains 300 world pixels")
	var visual: Node2D = boss.visual
	visual.update_pose("idle", 0.0, 0.0, 0.0)
	var neutral: PackedVector2Array = visual._body_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	visual.update_pose("idle", 1.0, 0.0, 0.0)
	var swaying: PackedVector2Array = visual._body_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var rigid: bool = true
	var cloth_moved: bool = false
	for index in range(neutral.size()):
		if neutral[index].y < -205.0 and not neutral[index].is_equal_approx(swaying[index]): rigid = false
		if neutral[index].y > -100.0 and neutral[index].distance_to(swaying[index]) > 0.1: cloth_moved = true
	check(rigid, "crown and upper core remain rigid across an idle animation interval")
	check(cloth_moved, "the lower paper cloak has actual native mesh motion")
	var poses: Array[String] = ["intro", "idle", "bolts_warning", "bolts_active", "sweep_warning", "sweep_active", "pillars_warning", "pillars_active", "chains_warning", "chains_active", "recover", "stagger", "phase_transition", "dead"]
	for index in range(poses.size()):
		var state: String = poses[index]
		var progress: float = 0.94 if state.ends_with("_warning") else 0.5
		if state == "dead": progress = 0.32
		await pose(state, progress, 2 if state == "phase_transition" else 1)
		if state == "sweep_active": check(not visual.is_held_blade_visible(), "the active damaging sweep replaces the held prop instead of drawing a second sword")
		if state == "recover": check(visual.is_held_blade_visible(), "the held blade returns during the safe recovery pose")
		await capture("%02d_%s" % [index + 1, state])
	visual.update_pose("dead", boss.age + 2.0, 0.32, 0.0)
	check(is_zero_approx(visual.self_modulate.a), "the dead visual dissolves even when its final attack timer stays frozen")
	var report := {"schema": "m23-native-art-review-2-profile", "scope": "Configured pose review only. Real M23 world, hero, boss, arena, lighting and camera; deliberately frozen hero and boss physics. Does not prove a fight, damage avoidance or victory.", "checks": checks, "failures": failures, "atlas_path": ATLAS_PATH, "atlas_sha256": ATLAS_SHA256, "captures": captures}
	var file := FileAccess.open(OUTPUT.path_join("art_review_report.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
		file = null
	print("M23 art review: ",checks," checks, ",failures.size()," failures")
	# Muting leaves nested score voices running. Explicitly release every stream
	# and allow the audio mixer to retire its callbacks before freeing the world.
	world.gameplay_active = false
	world.set_process(false)
	if is_instance_valid(world.boss_music): world.boss_music.stop_all()
	world._clear_compiler_attacks()
	stop_audio_recursive(world)
	OS.delay_msec(120)
	await process_frame
	await process_frame
	world.queue_free()
	world = null
	boss = null
	visual = null
	for frame in range(4): await process_frame
	OS.delay_msec(50)
	await process_frame
	quit(0 if failures.is_empty() else 1)
