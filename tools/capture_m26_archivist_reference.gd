extends SceneTree
## Native imported-art catalog captures. Final movies require a production freeze.
const SCENE := "res://scenes/minibosses/archivist_reference_m26.tscn"
const DEFAULT_OUTPUT := "/workspace/work/m26_imported_gallery"
const FINAL_OUTPUT := "res://previews/m26_imported"
var output := DEFAULT_OUTPUT
var studio: Node2D
var captures: Array[Dictionary] = []
var failures: Array[String] = []
var hashes: Dictionary = {}
var _video := false

func _initialize() -> void:
	call_deferred("run")

func json_value(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i: return [value.x,value.y]
	if value is Rect2: return [value.position.x,value.position.y,value.size.x,value.size.y]
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[str(key)] = json_value(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value: result.append(json_value(item))
		return result
	return value

func photo(tag: String, caption: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	var target := output+"/"+tag+".jpg"
	if frame.save_jpg(target,.96) != OK: failures.append("Cannot write "+target)
	captures.append({"path":target,"caption":caption,"scope":"Native art/animation catalog fixture; no combat claim.","snapshot":json_value(studio.get_review_snapshot())})
	print("ARCHIVIST NATIVE CAPTURE ",target)

func select(name: String, phase: int, seconds: float, facing: int = 1) -> void:
	studio.phase = phase
	studio.select_animation(name)
	studio.set_paused(true)
	studio.actor.set_facing(facing)
	studio.actor.seek(seconds)
	studio.sound.seek(seconds)
	studio._update_status()
	studio.frame_slider.set_value_no_signal(studio.actor.frame_index)
	studio.queue_redraw()

func stills() -> void:
	select("idle",1,.7)
	await photo("01_idle","الرسم المرفق داخل Godot · وقفة القراءة")
	select("walk",1,.225)
	await photo("02_walk","المشية المرفقة · حمل المطرقة بيد واحدة")
	select("slam",1,.65)
	await photo("03_two_hand_raise","رفع المطرقة باليدين قبل ضربة الفهرس")
	select("slam",1,.99)
	await photo("04_index_slam","ضربة الفهرس ومؤثراتها المرفقة")
	select("p2tr",1,2.2)
	await photo("05_transformation","التحول المرفق إلى الطبعة المحرّمة")
	select("idle",2,.7)
	await photo("06_phase_two","شكل الطور الثاني المرفق")
	select("indexlock",2,1.40)
	await photo("07_page_walls","قفلة الفهرس · جدران الصفحات")
	select("finale",2,1.35)
	await photo("08_final_chapter","الفصل الأخير · الاندفاع المرفق")
	select("walk",1,.225,-1)
	await photo("09_walk_left","نفس نقطة القدم عند قلب الاتجاه")

func segment(name: String, phase: int, seconds: float = -1.0) -> void:
	studio.phase = phase
	studio.select_animation(name)
	studio.set_paused(false)
	studio.actor.set_facing(1)
	var snap: Dictionary = studio.actor.get_snapshot()
	var duration: float = float(snap.duration)/studio.actor.playback_speed if seconds<0 else seconds
	for frame in range(roundi(duration*60)):
		studio._process(1.0/60.0)
		await process_frame
		await RenderingServer.frame_post_draw
	studio.set_paused(true)

func movie() -> void:
	# Explicit configured catalog review. Every attack is played, rather than
	# representing a scrubbed still as live gameplay or changing boss health.
	if "--quick-video" in OS.get_cmdline_user_args():
		await segment("walk",1,.9)
		await segment("slam",1)
		await segment("p2tr",1)
		await segment("combo5",2)
		return
	await segment("appear",1)
	await segment("idle",1,1.3)
	await segment("walk",1,1.8)
	for name in ["slam","sweep","shut","pagestorm","tomes","combo3"]:
		await segment(name,1)
	await segment("p2tr",1)
	await segment("idle",2,1.0)
	for name in ["combo5","redpass","indexlock","burning","pageflip","finale"]:
		await segment(name,2)
	await segment("hurt",2)
	await segment("death",2)

func collect_hashes() -> void:
	for path in ["scripts/minibosses/m26_archivist_reference.gd","scripts/minibosses/m26_archivist_sprite.gd","scripts/audio/m26_archivist_sfx.gd","assets/minibosses/m26_imported/manifest.json","assets/minibosses/m26_imported/meta_p1.json","assets/minibosses/m26_imported/meta_p2.json","assets/audio/m26_imported/sfx_map.json","tools/capture_m26_archivist_reference.gd"]:
		hashes[path] = FileAccess.get_sha256("res://"+path)
	for directory in ["assets/minibosses/m26_imported/","assets/audio/m26_imported/wav/"]:
		for filename in DirAccess.get_files_at("res://"+directory):
			if filename.ends_with(".zip") or filename.ends_with(".wav"):
				var path: String = str(directory)+filename
				hashes[path] = FileAccess.get_sha256("res://"+path)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A native renderer is required for visual capture")
		quit(1)
		return
	root.size = Vector2i(1280,720)
	_video = "--video" in OS.get_cmdline_user_args()
	if "--final-capture" in OS.get_cmdline_user_args(): output = FINAL_OUTPUT
	DirAccess.make_dir_recursive_absolute(output)
	collect_hashes()
	studio = load(SCENE).instantiate()
	root.add_child(studio)
	await process_frame
	studio.set_process(false)
	studio.set_paused(true)
	if _video: await movie()
	else: await stills()
	var changed: Array[String] = []
	for path in hashes:
		if FileAccess.get_sha256("res://"+path) != hashes[path]: changed.append(path)
	if _video and not changed.is_empty(): failures.append("Sources changed during movie capture: "+str(changed))
	var report := {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"native":true,"scope":"Configured animation catalog, not a combat recording.","viewport":[1280,720],"fps":60,"movie":_video,"source_sha256":hashes,"source_files_changed":changed,"captures":captures,"failures":failures,"audio":"Native supplied WAV event router; no added soundtrack."}
	FileAccess.open(output+("/catalog_movie_metadata.json" if _video else "/catalog_still_metadata.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	studio.sound.stop_all()
	studio.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
