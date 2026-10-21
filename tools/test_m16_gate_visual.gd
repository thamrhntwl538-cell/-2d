extends SceneTree
## Isolated render fixture: real gate.unlock() and _process animation.
## Actual-input gameplay progression is covered by the separate stage regression.
const STAGE = preload("res://scenes/stage_01/forgotten_wing.tscn")
const SurfaceSkin = preload("res://scripts/stage/m16_surface_skin.gd")
const OUT := "res://previews/m16/gate/"
var world: Node2D
var gate: Node2D
var failures: Array[String] = []
var records: Array[Dictionary] = []
var ticks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func step(n: int) -> void:
	for i in range(n):
		await physics_frame
		ticks += 1
func stop_audio(node: Node) -> void:
	for child in node.get_children(): stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream=null
func capture(name: String) -> Image:
	world.toast.text=""
	world.hint.text=""
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	check(frame.save_png(OUT+name+".png")==OK,"Failed to save "+name)
	records.append({"state":name,"file":OUT+name+".png","progress":gate.progress,"collider_disabled":gate.get_node("Barrier/Collision").disabled,"is_open":gate.is_open,"gate_position":[gate.position.x,gate.position.y]})
	return frame
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	world=STAGE.instantiate()
	world.visual_revision=16
	world.restore_saved_game=false
	world.environment_preview=true
	world.checkpoint={"room":0,"position":[3240.0,1260.0]}
	root.add_child(world)
	stop_audio(world)
	await step(72)
	gate=world.gates[0].node
	check(gate.get_node_or_null("M16GateArtwork")!=null,"New gate artwork is missing")
	check(not gate.is_open and gate.progress==0.0,"Entrance fixture was not initially closed")
	check(not gate.get_node("Barrier/Collision").disabled,"Closed gate collider missing")
	world.gameplay_active=false
	world.hero.set_physics_process(false)
	world.hero.lantern_sprite.frame=0
	world.hero.lantern_sprite.pause()
	world.camera.set_process(false)
	world.camera.zoom=Vector2(1.4,1.4)
	world.camera.position=world.camera.bounded(Vector2(3340,1100))
	world.camera.reset_smoothing()
	world.camera.force_update_scroll()
	await step(3)
	world.visuals.set_process(false)
	var starting_position: Vector2 = gate.position
	var collider_size: Vector2 = gate.get_node("Barrier/Collision").shape.size
	await capture("closed")
	gate.unlock()
	for i in range(120):
		await step(1)
		if gate.progress>=0.49: break
	check(gate.progress>=0.49 and gate.progress<0.60,"Half animation checkpoint was missed")
	check(not gate.get_node("Barrier/Collision").disabled,"Gate released collision too early")
	await capture("half")
	for i in range(150):
		await step(1)
		if gate.is_open: break
	await step(3)
	check(gate.is_open and gate.get_node("Barrier/Collision").disabled,"Real opening did not release gate collision")
	check(gate.position==starting_position,"Authoritative gate moved")
	check(gate.get_node("Barrier/Collision").shape.size==collider_size,"Authoritative gate shape changed")
	var open_frame: Image = await capture("open")
	# Render a matching no-gate reference to test the actual central opening for
	# any retained closed panel or opaque atlas halo. This does not edit artwork.
	gate.visible=false
	await process_frame
	await RenderingServer.frame_post_draw
	var reference: Image = root.get_texture().get_image()
	reference.save_png("user://m16_open_reference_no_gate.png")
	gate.visible=true
	var from: Vector2 = gate.get_global_transform_with_canvas()*Vector2(-35,-150)
	var to: Vector2 = gate.get_global_transform_with_canvas()*Vector2(35,-20)
	var differing := 0
	var sampled := 0
	var max_difference := 0.0
	for y in range(int(ceil(from.y)),int(floor(to.y))):
		for x in range(int(ceil(from.x)),int(floor(to.x))):
			var a := open_frame.get_pixel(x,y)
			var b := reference.get_pixel(x,y)
			var delta := maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
			max_difference=maxf(max_difference,delta)
			if delta>2.0/255.0: differing+=1
			sampled+=1
	check(sampled>10000,"Opening reference test had insufficient pixels")
	check(float(differing)/maxi(1,sampled)<0.001,"Opaque art remained across the open passage")
	var frame: Vector4 = SurfaceSkin.GATE_FRAME_FRACTIONS
	var opening_size := Vector2(180.0*(1.0-frame.x-frame.y),gate.gate_height*(1.0-frame.z-frame.w))
	check(opening_size.x>=60 and opening_size.y>=114,"Painted opening does not comfortably fit the unchanged Warden art")
	var report := {"passed":failures.is_empty(),"godot":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),"physics_ticks":ticks,"fixture_room":0,"fixture_hero_position":[3240,1260],"fixture_camera_zoom":1.4,"activation":"Real gate.unlock() followed by the existing _process animation; isolated visual fixture, not gameplay traversal.","records":records,"gate_collider_size":[collider_size.x,collider_size.y],"gate_position_unchanged":gate.position==starting_position,"painted_opening_world_size":[opening_size.x,opening_size.y],"unchanged_hero_art_scale":0.4,"open_passage_reference":{"sampled_pixels":sampled,"different_pixels":differing,"different_fraction":float(differing)/maxi(1,sampled),"max_channel_difference":max_difference,"sample_local_rect":[-35,-150,70,130],"reference":"Gate hidden for a single matching rendered frame; no art editing."},"manual_review":"Closed, half and open actual-engine images saved for review.","failures":failures}
	FileAccess.open("res://M16_GATE_VISUAL_QA.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M16 GATE VISUAL ",JSON.stringify(report))
	stop_audio(world)
	world.queue_free()
	await process_frame
	await process_frame
	OS.delay_msec(120)
	quit(0 if failures.is_empty() else 1)
