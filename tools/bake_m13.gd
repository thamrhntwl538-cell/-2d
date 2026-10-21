extends SceneTree
const Model = preload("res://scripts/warden_model_m13.gd")
var viewport: SubViewport
var model: Node2D
var records: Array = []

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1024, 1024)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	model = Model.new()
	model.scale = Vector2.ONE * 2.0
	viewport.add_child(model)
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://assets/warden_m13")
	var jobs: Array = []
	for i in range(16):
		jobs.append(["idle_%02d" % i, "idle", float(i) / 16.0])
	for i in range(48):
		jobs.append(["run_%02d" % i, "run", float(i) / 8.0])
	for i in range(15):
		jobs.append(["jump_%02d" % i, "air", 1.0 + float(i) * 3.0 / 14.0])
	for i in range(6):
		jobs.append(["fall_%02d" % i, "air", 5.0 + float(i) / 5.0])
	for i in range(4):
		jobs.append(["land_%02d" % i, "land", float(i) / 3.0])
	for i in range(6):
		jobs.append(["stop_%02d" % i, "stop", float(i) / 5.0])
	for i in range(12):
		jobs.append(["dash_%02d" % i, "dash", float(i) / 2.0])
	for job in jobs:
		model.set_motion(job[1], job[2])
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		image.resize(512, 512, Image.INTERPOLATE_LANCZOS)
		var path: String = "res://assets/warden_m13/%s.png" % job[0]
		var result: int = image.save_png(path)
		assert(result == OK, "Unable to bake " + path)
		var record: Dictionary = {"file": path, "motion": job[1], "sample": job[2], "joints": {}, "contacts": model.contacts.duplicate(true), "foot_targets": model.foot_targets.duplicate(true)}
		for key in model.joints:
			var points: Array = []
			for point in model.joints[key]:
				points.append([point.x, point.y])
			record.joints[key] = points
		records.append(record)
	var file := FileAccess.open("res://WARDEN_M13_RIG_AUDIT.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer": RenderingServer.get_video_adapter_name(), "bake": "Godot 4, 2x supersampling", "frames": records}, "\t"))
	print("M13 BAKE PASS: ", jobs.size(), " frames, single shared rig")
	quit()
