extends SceneTree
## Native visual/collision fixture for the painted Bell entrance. Only the
## inherited arena parent's drawing is suppressed; child gates remain real.
var checks := 0
var failures: Array[String] = []
var world: Node2D
var pixel_counts: Array[int] = []

func _initialize() -> void: run.call_deferred()

func check(value: bool, caption: String) -> void:
	checks += 1
	if not value:
		failures.append(caption)
		push_error("M28 Bell door: " + caption)

func step(count: int = 1) -> void:
	for unused in range(count):
		await physics_frame
		await process_frame

func gate_ray(gate: StaticBody2D) -> Dictionary:
	var p := gate.global_position + Vector2(16,-140)
	var query := PhysicsRayQueryParameters2D.create(p-Vector2(50,0),p+Vector2(50,0),1)
	return world.get_world_2d().direct_space_state.intersect_ray(query)

func frame() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("m28_bell_door_userdata"):
		push_error("Use isolated m28_bell_door_userdata")
		quit(1)
		return
	if DisplayServer.get_name()=="headless":
		push_error("This gate visibility probe requires a native display")
		quit(1)
		return
	root.size=Vector2i(1280,720)
	world=load("res://scenes/stage_01/folding_library_m28.tscn").instantiate()
	world.restore_saved_game=false
	root.add_child(world)
	current_scene=world
	await step(20)
	world._load_room(12,"left",Vector2(620,1260))
	await step(20)
	var arena: Node2D=world.boss_arena
	check(is_instance_valid(arena),"Bell room creates its original native gate arena")
	check(arena.self_modulate.a==0 and arena.modulate.a==1,"Only parent self drawing is hidden; inherited modulation stays opaque")
	check(arena.is_visible_in_tree(),"Parent remains visible in the tree")
	check(arena.gates.size()==2,"Both original child book gates are retained")
	check(arena.arena_rect==Rect2(1110,940,1080,320),"Approved narrowed combat bounds remain unchanged")
	check(world.hero.hp==6 and world.hero.is_on_floor(),"Hero has full health and actual floor support before encounter")
	for gate in arena.gates:
		check(gate.is_visible_in_tree() and gate.self_modulate.a==1 and gate.modulate.a==1,"Child gate stays independently visible and opaque")
		check(gate.collision_layer==0 and gate.shape.disabled,"Open child gate has no blocking collision")
		check(gate_ray(gate).is_empty(),"Ray crosses the open gate without colliding")
	world.gameplay_active=false
	world.camera.target=null
	world.camera.position=Vector2(1650,1010)
	world.camera.zoom=Vector2(.94,.94)
	world.fade.color.a=0
	world.arrival_title.dismiss()
	arena.set_locked(true)
	await step(5)
	for gate in arena.gates:
		check(gate.closed and gate.collision_layer==1 and not gate.shape.disabled,"Closed child gate enables its original solid collision")
		check(gate_ray(gate).get("collider")==gate,"Ray hits the real closed child gate")
	var visible_frame: Image=await frame()
	for gate in arena.gates: gate.self_modulate.a=0
	await step(3)
	var hidden_frame: Image=await frame()
	var canvas_transform: Transform2D=world.get_viewport().get_canvas_transform()
	for gate in arena.gates:
		var p1: Vector2=canvas_transform*(gate.global_position-Vector2(0,gate.gate_size.y))
		var p2: Vector2=canvas_transform*(gate.global_position+Vector2(gate.gate_size.x,0))
		var bounds:=Rect2i(Vector2i(p1.floor()),Vector2i((p2-p1).ceil())).intersection(Rect2i(0,0,1280,720))
		var changed:=0
		for y in range(bounds.position.y,bounds.end.y):
			for x in range(bounds.position.x,bounds.end.x):
				var a:=visible_frame.get_pixel(x,y)
				var b:=hidden_frame.get_pixel(x,y)
				if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>.025: changed+=1
		pixel_counts.append(changed)
		check(changed>200,"Native rendered pixels prove a child gate still draws under the hidden parent")
	for gate in arena.gates: gate.self_modulate.a=1
	await step(3)
	var restored_frame: Image=await frame()
	var image_path:=OS.get_environment("XDG_DATA_HOME")+"/bell_door_locked.jpg"
	check(restored_frame.save_jpg(image_path,.94)==OK,"Actual configured native closed-gate frame is saved")
	arena.set_locked(false)
	await step(3)
	for gate in arena.gates:
		check(gate.collision_layer==0 and gate.shape.disabled and gate_ray(gate).is_empty(),"Unlocking restores traversal without removing the child gate")
	check(world.hero.hp==6 and world.hero.is_on_floor(),"Cosmetic gate probe preserves hero health and floor contact")
	world.soundscape.stop_all()
	world.music.stop()
	world.boss_music.stop_fight(false)
	OS.delay_msec(180)
	current_scene=null
	root.remove_child(world)
	world.free()
	await step(3)
	var report:={"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"gate_pixel_differences":pixel_counts,"native_frame":image_path,"scope":"Configured Bell room/fight-camera fixture; real native rendering plus open/closed gate ray collisions. No fight or victory claim."}
	FileAccess.open("user://m28_bell_door_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M28 BELL DOOR ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
