extends SceneTree
## Rendered inspection fixtures, separate from the actual-input traversal QA.
## Each view uses real scene/collision/light rendering at a labelled checkpoint.
## Default: matched revisions 15 and16. --m16-only captures the new style only.
## --case=07_output re-captures one matched pair and retains other evidence.
const STAGE = preload("res://scenes/stage_01/forgotten_wing.tscn")
const SAVE_FILE := "user://forgotten_wing_m15.json"
const OUTPUT := "res://previews/m16"
const CASES: Array[Dictionary] = [
	{"id":"01_entrance_floor","room":0,"position":Vector2(440,1260)},
	{"id":"01_entrance_gallery","room":0,"position":Vector2(2475,780)},
	{"id":"02_corridor_floor","room":1,"position":Vector2(1800,1260)},
	{"id":"02_corridor_balcony","room":1,"position":Vector2(1320,900)},
	{"id":"03_lab_walkway","room":2,"position":Vector2(1880,1260)},
	{"id":"03_lab_maintenance","room":2,"position":Vector2(450,1620)},
	{"id":"03_lab_service_gallery","room":2,"position":Vector2(2200,900)},
	{"id":"04_archive_bottom","room":3,"position":Vector2(1125,2700)},
	{"id":"04_archive_lower","room":3,"position":Vector2(720,1980)},
	{"id":"04_archive_middle","room":3,"position":Vector2(1700,1260)},
	{"id":"04_archive_upper","room":3,"position":Vector2(1650,660)},
	{"id":"05_input","room":4,"position":Vector2(780,1260)},
	{"id":"06_process","room":5,"position":Vector2(1310,1260)},
	{"id":"07_output","room":6,"position":Vector2(1210,1260)},
	{"id":"08_approach_bench","room":7,"position":Vector2(350,1260)},
	{"id":"08_approach_encounter","room":7,"position":Vector2(2000,1260)},
	{"id":"09_tribunal_centre","room":8,"position":Vector2(2100,1620)},
	{"id":"09_tribunal_west","room":8,"position":Vector2(200,1620)},
	{"id":"10_aftermath","room":9,"position":Vector2(1100,1260)}
]
var world: Node2D
var failures: Array[String] = []
var records: Array[Dictionary] = []
var geometry_before: Dictionary = {}
var exits_before: Dictionary = {}
var comparisons: Array[Dictionary] = []
var physics_ticks: int = 0
var renderer: String = ""
var had_save: bool = false
var original_save: String = ""

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> bool:
	if not condition and not failures.has(message):
		failures.append(message)
		print("M16 VISUAL FAILURE: ",message)
	return condition

func step(count: int) -> void:
	for i in range(count):
		await physics_frame
		physics_ticks += 1

func property_exists(node: Object, property_name: String) -> bool:
	for item in node.get_property_list():
		if item.name==property_name: return true
	return false

func rounded_vector(point: Vector2) -> Array:
	return [snappedf(point.x,0.001),snappedf(point.y,0.001)]

func collision_records(node: Node, destination: Array[String]) -> void:
	if node is CollisionShape2D and node.shape!=null:
		var body: CollisionObject2D = node.get_parent() as CollisionObject2D
		if body:
			var record := {"body":body.get_class(),"shape":node.shape.get_class(),"one_way":node.one_way_collision,"margin":node.one_way_collision_margin,"layer":body.collision_layer,"mask":body.collision_mask}
			if node.shape is RectangleShape2D: record.size = rounded_vector(node.shape.size)
			elif node.shape is CircleShape2D: record.radius = node.shape.radius
			elif node.shape is CapsuleShape2D:
				record.radius = node.shape.radius
				record.height = node.shape.height
			if body is AnimatableBody2D:
				record.offset = rounded_vector(node.position)
				if property_exists(body,"positions"):
					var stops: Array = []
					for point in body.positions: stops.append(rounded_vector(point))
					record.stops = stops
			else:
				record.position = rounded_vector(node.global_position)
			destination.append(JSON.stringify(record))
	for child in node.get_children(): collision_records(child,destination)

func geometry_signature() -> Array[String]:
	var result: Array[String] = []
	collision_records(world.active_room,result)
	result.sort()
	return result

func exit_signature() -> Array[String]:
	var result: Array[String] = []
	for exit in world.data.exits:
		result.append(JSON.stringify({"id":exit.id,"position":rounded_vector(exit.pos),"target":exit.target,"spawn":exit.target_spawn,"requires":exit.get("requires",""),"preview_bypass":exit.get("preview_bypass",false)}))
	result.sort()
	return result

func stop_audio(node: Node) -> void:
	for child in node.get_children(): stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null

func remove_world() -> void:
	if is_instance_valid(world):
		stop_audio(world)
		world.queue_free()
		await process_frame
		await process_frame

func luminance(color: Color) -> float:
	return color.r*0.2126+color.g*0.7152+color.b*0.0722

func pixel_luma(frame: Image, point: Vector2) -> float:
	return luminance(frame.get_pixel(clampi(int(point.x),0,frame.get_width()-1),clampi(int(point.y),0,frame.get_height()-1)))

func metrics(frame: Image, head: Vector2, feet: Vector2) -> Dictionary:
	var mean: float = 0.0
	var samples: int = 0
	var edge_count: int = 0
	var bright_samples: int = 0
	# Advisory background values exclude HUD, lower interaction text and the
	# character. They support visual review rather than scoring artistic quality.
	for y in range(200,530,4):
		for x in range(40,frame.get_width()-40,4):
			if absf(float(x)-feet.x)<75.0 and y>int(feet.y)-145: continue
			var value := pixel_luma(frame,Vector2(x,y))
			mean += value
			samples += 1
			if value>0.28: bright_samples += 1
			var horizontal := absf(value-pixel_luma(frame,Vector2(x+3,y)))
			var vertical := absf(value-pixel_luma(frame,Vector2(x,y+3)))
			if maxf(horizontal,vertical)>0.035: edge_count += 1
	var lantern_peak: float = 0.0
	for y in range(-15,16):
		for x in range(-12,13):
			lantern_peak = maxf(lantern_peak,pixel_luma(frame,head+Vector2(x,y)))
	var local_background: float = 0.0
	for i in range(64):
		local_background += pixel_luma(frame,head+Vector2.from_angle(TAU*float(i)/64.0)*42.0)
	local_background /= 64.0
	var floor_luma: float = 0.0
	var above_floor_luma: float = 0.0
	var lip_samples: int = 0
	for x in range(-60,61,3):
		if absi(x)<24: continue
		floor_luma += pixel_luma(frame,feet+Vector2(x,2))
		above_floor_luma += pixel_luma(frame,feet+Vector2(x,-7))
		lip_samples += 1
	return {"gameplay_background_mean_luma":mean/maxi(1,samples),"background_edge_fraction":float(edge_count)/maxi(1,samples),"background_bright_fraction":float(bright_samples)/maxi(1,samples),"lantern_peak_luma":lantern_peak,"lantern_local_background_luma":local_background,"lantern_peak_minus_local_background":lantern_peak-local_background,"platform_lip_mean_luma":floor_luma/maxi(1,lip_samples),"above_platform_mean_luma":above_floor_luma/maxi(1,lip_samples),"note":"Image values are advisory sRGB luma proxies; manual review remains required."}

func capture_case(definition: Dictionary, revision: int) -> bool:
	await remove_world()
	world = STAGE.instantiate()
	if not property_exists(world,"visual_revision"):
		return check(false,"Stage root does not expose visual_revision yet")
	world.visual_revision = revision
	world.restore_saved_game = false
	world.environment_preview = true
	world.checkpoint = {"room":definition.room,"position":[definition.position.x,definition.position.y]}
	root.add_child(world)
	await step(72)
	var hero: CharacterBody2D = world.hero
	var stable: bool = hero.is_on_floor() and absf(hero.position.y-definition.position.y)<2.0 and absf(hero.position.x-definition.position.x)<1.0
	check(stable,"Revision%d %s did not settle at its intended visual-review floor: %s" % [revision,definition.id,hero.position])
	check(hero.get_node("StableGameplayCollider").shape.size==Vector2(30,58),"Revision%d changed actor collision dimensions" % revision)
	check(hero.lantern_sprite.scale.is_equal_approx(Vector2(0.4,0.4)),"Revision%d changed actor art scale" % revision)
	check(hero.lantern_sprite.position.is_equal_approx(Vector2(0,-80)),"Revision%d changed actor foot pivot" % revision)
	check(not world.progress.compiler_seal and not world.progress.boss_defeated and world.progress.encounters.is_empty(),"Visual fixture fabricated combat progress")
	var camera: Camera2D = world.camera
	var half_view: Vector2 = root.get_visible_rect().size/camera.zoom/2.0
	var bounds: Rect2 = camera.room_rect
	var covered: bool = camera.position.x-half_view.x>=bounds.position.x-0.5 and camera.position.y-half_view.y>=bounds.position.y-0.5 and camera.position.x+half_view.x<=bounds.end.x+0.5 and camera.position.y+half_view.y<=bounds.end.y+0.5
	check(covered,"Revision%d %s camera extends beyond its room" % [revision,definition.id])
	# Freeze a repeatable real rendered idle pose without changing any asset.
	world.gameplay_active = false
	hero.set_physics_process(false)
	hero.lantern_sprite.frame = 0
	hero.lantern_sprite.pause()
	world.toast.text = ""
	await process_frame
	await RenderingServer.frame_post_draw
	var folder: String = "before" if revision==15 else "after"
	var file: String = OUTPUT+"/"+folder+"/"+definition.id+".png"
	var frame: Image = root.get_texture().get_image()
	check(frame.get_width()==1280 and frame.get_height()==720,"Visual review viewport is not1280x720")
	check(frame.save_png(file)==OK,"Could not save "+file)
	var head: Vector2 = hero.get_global_transform_with_canvas()*hero.lantern_light.position
	var feet: Vector2 = hero.get_global_transform_with_canvas()*Vector2.ZERO
	var measurements: Dictionary = metrics(frame,head,feet)
	var lighting_diagnostics: Dictionary = {}
	var skin_diagnostics: Dictionary = {}
	# These deliberately weak checks catch accidental blacked-out lanterns;
	# they do not claim that an image statistic proves full-body readability.
	if revision==16:
		check(float(measurements.lantern_peak_luma)>0.15,"M16 lantern is nearly black in "+definition.id)
		check(float(measurements.lantern_peak_minus_local_background)>0.05,"M16 lantern lost local contrast in "+definition.id)
		skin_diagnostics = world.surface_counts.duplicate(true)
		check(skin_diagnostics.get("missing_assets",[]).is_empty(),"M16 surface assets are missing in "+definition.id)
		check(int(skin_diagnostics.get("platforms",0))==world.data.platforms.size(),"An M15 ornate platform skin remains in "+definition.id)
		check(int(skin_diagnostics.get("gates",0))==world.data.gates.size(),"An M15 gate skin remains in "+definition.id)
		check(int(skin_diagnostics.get("shelves",0))==world.data.get("secret_passages",[]).size(),"An M15 shelf skin remains in "+definition.id)
		var expected_moving_surfaces: int = world.data.get("moving_platforms",[]).size()+(0 if world.data.get("elevator",{}).is_empty() else 1)
		check(int(skin_diagnostics.get("moving_surfaces",0))==expected_moving_surfaces,"An M15 moving-surface skin remains in "+definition.id)
		if is_instance_valid(world.lighting):
			lighting_diagnostics = world.lighting.diagnostics()
			check(int(lighting_diagnostics.visible_pool_count)<=3 and int(lighting_diagnostics.visible_light_count)<=4,"M16 exceeded its limited visible light budget in "+definition.id)
		else: check(false,"M16 local lighting is absent in "+definition.id)
	var geometry: Array[String] = geometry_signature()
	var exits: Array[String] = exit_signature()
	if revision==15:
		geometry_before[definition.id] = geometry
		exits_before[definition.id] = exits
	elif geometry_before.has(definition.id):
		var unchanged: bool = geometry_before[definition.id]==geometry and exits_before[definition.id]==exits
		check(unchanged,"M16 changed collision or exit requirements in "+definition.id)
		comparisons.append({"id":definition.id,"room":definition.room,"collision_and_exit_requirements_unchanged":unchanged})
	records.append({"id":definition.id,"room":definition.room,"revision":revision,"file":file,"fixture_spawn":[definition.position.x,definition.position.y],"observed_feet":rounded_vector(hero.position),"head_screen":rounded_vector(head),"feet_screen":rounded_vector(feet),"camera_covered":covered,"collision_shape_count":geometry.size(),"metrics":measurements,"lighting":lighting_diagnostics,"surface_skin":skin_diagnostics})
	print("M16 CAPTURE ",revision," ",definition.id," head_contrast=",measurements.lantern_peak_minus_local_background)
	return true

func run_checks() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("M16 visual review requires a rendered display, not --headless")
		quit(1)
		return
	renderer = RenderingServer.get_video_adapter_name()
	had_save = FileAccess.file_exists(SAVE_FILE)
	if had_save: original_save = FileAccess.get_file_as_string(SAVE_FILE)
	DirAccess.make_dir_recursive_absolute(OUTPUT+"/before")
	DirAccess.make_dir_recursive_absolute(OUTPUT+"/after")
	var case_filter: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--case="): case_filter = argument.trim_prefix("--case=")
	var revisions: Array[int] = []
	if not OS.get_cmdline_user_args().has("--m16-only"): revisions.append(15)
	revisions.append(16)
	var selected_cases: Array[Dictionary] = []
	for definition in CASES:
		if case_filter.is_empty() or definition.id==case_filter: selected_cases.append(definition)
	if selected_cases.is_empty() or (not case_filter.is_empty() and revisions.size()!=2):
		push_error("Unknown visual case, or selective mode lacks its matched before revision")
		quit(1)
		return
	var previous_report: Dictionary = {}
	if not case_filter.is_empty():
		var previous_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://M16_VISUAL_QA.json"))
		if not previous_data is Dictionary or not previous_data.has("records") or not previous_data.has("geometry_comparisons"):
			push_error("Selective visual capture requires an existing complete M16_VISUAL_QA.json")
			quit(1)
			return
		previous_report = previous_data
		for record in previous_report.records:
			if record.id!=case_filter: records.append(record)
		for comparison in previous_report.geometry_comparisons:
			if comparison.id!=case_filter: comparisons.append(comparison)
		for failure in previous_report.get("failures",[]):
			if not str(failure).contains(case_filter): failures.append(str(failure))
	var ready: bool = true
	for definition in selected_cases:
		for revision in revisions:
			if not await capture_case(definition,revision):
				ready = false
				break
		if not ready: break
	await remove_world()
	OS.delay_msec(120)
	if had_save: FileAccess.open(SAVE_FILE,FileAccess.WRITE).store_string(original_save)
	elif FileAccess.file_exists(SAVE_FILE): DirAccess.remove_absolute(SAVE_FILE)
	records.sort_custom(func(a: Dictionary,b: Dictionary): return str(a.id)+"_"+str(a.revision)<str(b.id)+"_"+str(b.revision))
	comparisons.sort_custom(func(a: Dictionary,b: Dictionary): return str(a.id)<str(b.id))
	var capture_runs: Array = previous_report.get("capture_runs",[]).duplicate(true)
	if not previous_report.is_empty() and capture_runs.is_empty(): capture_runs.append({"case_filter":"all","fixture_count":CASES.size(),"rendered_records":previous_report.records.size(),"physics_ticks":previous_report.physics_ticks})
	capture_runs.append({"case_filter":"all" if case_filter.is_empty() else case_filter,"fixture_count":selected_cases.size(),"rendered_records":selected_cases.size()*revisions.size(),"physics_ticks":physics_ticks})
	var report := {"passed":failures.is_empty(),"godot":Engine.get_version_info().string,"renderer":renderer,"rendered":true,"physics_ticks":physics_ticks+int(previous_report.get("physics_ticks",0)),"latest_run_physics_ticks":physics_ticks,"fixture_count_per_revision":CASES.size(),"revisions":revisions,"records":records,"geometry_comparisons":comparisons,"capture_runs":capture_runs,"failures":failures,"inspection_method":"Actual native Godot rendered checkpoint fixtures. These fixture placements are visual inspection, not traversal completion.","manual_review_required":true,"manual_review_status":"pending review of every captured room and lower/upper level" if case_filter.is_empty() else "selective recapture complete; manual review pending for "+case_filter,"limitations":["Advisory pixel statistics do not certify artistic quality, smoothness, or whole-body silhouette readability.","The independent M15 actual-input traversal test must be run after final integration.","No enemy or boss combat is implemented or validated by this visual review."]}
	if previous_report.get("manual_review") is Dictionary:
		var earlier_review: Dictionary = previous_report.manual_review.duplicate(true)
		var accepted: Array = []
		for accepted_id in earlier_review.get("accepted_after_fixtures",[]):
			if str(accepted_id)!=case_filter: accepted.append(accepted_id)
		earlier_review.accepted_after_fixtures = accepted
		earlier_review.pending_after_fixtures = [case_filter]
		report.manual_review = earlier_review
	FileAccess.open("res://M16_VISUAL_QA.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M16 VISUAL ","PASS" if failures.is_empty() else "FAIL"," rendered_records=",records.size()," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
