extends SceneTree
## Native visual fixtures. These images document art, never combat outcomes.
const SCENE := "res://scenes/minibosses/bell_character_review_m24.tscn"
const OUTPUT := "res://previews/m24"
const ATLAS := "res://assets/minibosses/m24/bell_character_parts.png"
const PAGES := {
	"master": "14_character_reference_match",
	"parts": "11_character_parts",
	"scale": "12_character_scale",
	"motion": "13_character_motion"
}
var review: Node2D
var captures: Array[Dictionary] = []
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func step(frames: int = 1) -> void:
	for frame in range(frames):
		await process_frame

func selected_pages() -> Array[String]:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pages="):
			var result: Array[String] = []
			for page in arg.trim_prefix("--pages=").split(","):
				if PAGES.has(page): result.append(page)
			return result
	return ["master", "parts", "scale", "motion"]

func capture(page: String) -> void:
	if review.has_method("set_page"):
		review.set_page(page)
	elif page == "parts" and review.has_method("set_exploded"):
		review.set_exploded(true)
	elif page != "master":
		failures.append("Review scene has no page API for " + page)
		return
	if page != "motion" and "models" in review:
		for model in review.models:
			model.breathing = false
			model.age = 0.0
	await step(3)
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	if frame.is_empty():
		failures.append("Empty native viewport on page " + page)
		return
	var filename: String = PAGES[page]
	var target := OUTPUT + "/" + filename + ".jpg"
	var png_target := "/workspace/work/m24_character_sources/" + filename + ".png"
	if frame.save_jpg(target, .95) != OK:
		failures.append("Failed to save " + target)
	frame.save_png(png_target)
	captures.append({
		"page": page, "path": target, "source_png": png_target,
		"width": frame.get_width(), "height": frame.get_height(),
		"configured_fixture": true, "gameplay_evidence": false,
		"note": "Native character art review page. Poses and layout are configured for inspection."
	})
	print("M24 CHARACTER CAPTURE ", target)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use the native renderer for visual captures")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	DirAccess.make_dir_recursive_absolute("/workspace/work/m24_character_sources")
	review = load(SCENE).instantiate()
	root.add_child(review)
	await step(4)
	for page in selected_pages(): await capture(page)
	var report := {
		"engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"scene": SCENE, "atlas": ATLAS,
		"atlas_sha256": FileAccess.get_sha256(ATLAS),
		"scope": "Configured native character visual fixtures only; no combat, traversal, or victory claim.",
		"captures": captures, "failures": failures
	}
	FileAccess.open(OUTPUT + "/character_capture_metadata.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	review.queue_free()
	await step(2)
	quit(0 if failures.is_empty() else 1)
