extends SceneTree
## Configured native environment comparison; this is not fight completion proof.
const LegacyVisuals=preload("res://scripts/stage/m23_room_visuals.gd")
const BellVisuals=preload("res://scripts/stage/m24_room_visuals.gd")
const Layouts=preload("res://scripts/stage/m23_layouts.gd")
var world: Node2D
var checks:=0
var failures: Array[String]=[]
var captures: Array[Dictionary]=[]

func _initialize() -> void: call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
	print("M24 ENV ","PASS " if ok else "FAIL ",label)

func swap_visuals(script: Script, room_data: Dictionary) -> void:
	world.active_room.remove_child(world.visuals)
	world.visuals.free()
	world.visuals=script.new()
	world.active_room.add_child(world.visuals)
	world.visuals.setup(world,room_data)
	await process_frame
	await process_frame

func photo(tag: String, caption: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var frame:=root.get_texture().get_image()
	var path:="res://previews/m24/"+tag+".jpg"
	frame.save_jpg(path,.94)
	captures.append({"path":path,"width":frame.get_width(),"height":frame.get_height(),"caption":caption})

func run() -> void:
	world=load("res://scenes/minibosses/bell_trial_m24.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.gameplay_active=false
	world.set_process(false)
	world.set_physics_process(false)
	world.hero.set_physics_process(false)
	world.registered_boss.set_physics_process(false)
	world.hero.position=Vector2(1360,1260)
	world.registered_boss.position=Vector2(1850,1260)
	world.camera.target=null
	world.camera.position=Vector2(1650,1010)
	world.camera.zoom=Vector2(.84,.84)
	world.camera.reset_smoothing()
	world.elapsed=0.0
	world.fade.color.a=0.0
	world.arrival_title.dismiss()
	world.hud.objective_label.text=""
	world.hud.update_boss_status({"visible":true,"name_ar":"حارس الجرس","name_en":"Bell Warden","hp":18,"max_hp":18,"phase":1,"state":"dormant"})
	var platforms_before: Array=world.data.platforms.duplicate(true)
	var objects_before: Array=world.data.objects.duplicate(true)
	# Reconstruct only the inherited visual press list for the before image.
	# World damage stays disabled; both photos share one scene and positions.
	var old_dressing: Dictionary=world.data.duplicate(true)
	old_dressing.hazards=Layouts.room(12).hazards.duplicate(true)
	await swap_visuals(LegacyVisuals,old_dressing)
	await photo("20_arena_before","Configured native comparison: inherited close wall, repeated near shelves and three original press frames. Hero/actor physics suspended; visual press list reconstructed solely for this before image.")
	await swap_visuals(BellVisuals,world.data)
	await photo("21_arena_after","Configured native comparison: same scene, positions and camera, M24 parked side presses and clear body/air space. Not an input fight or victory proof.")
	check(world.data.platforms==platforms_before,"visual replacement preserves all physical platform definitions")
	check(world.data.objects==objects_before,"visual replacement preserves both benches, latches and reading objects")
	check(world.visuals.find_children("*","CollisionObject2D",true,false).is_empty(),"M24 scenery introduces no collision objects")
	check(world.visuals.light_specs.size()<=6,"room uses a small fixed set of local lamps")
	for foot in BellVisuals.PARKED_PRESS_FEET:
		check(not Rect2(foot-Vector2(72,448),Vector2(144,466)).intersects(BellVisuals.BELL_QUIET_ZONE),"parked press stays outside combat body zone at x"+str(foot.x))
	var foreground: Node2D=world.visuals.foreground
	check(foreground.safe_lip_margin>=11,"foreground books stay below the physical landing lip")
	var shape_count: int=world.surface_root.find_children("*","CollisionShape2D",true,false).size()
	check(shape_count==platforms_before.size(),"the authored room platforms retain their physical shapes")
	await physics_frame
	await process_frame
	var space: PhysicsDirectSpaceState2D=world.get_world_2d().direct_space_state
	var floor_samples: Array=[]
	for x in [620.0,960.0,1200.0,1500.0,1850.0,2200.0,2340.0,2604.0]:
		var floor_query:=PhysicsRayQueryParameters2D.create(Vector2(x,1250),Vector2(x,1280),1)
		var hit:=space.intersect_ray(floor_query)
		var supported: bool=not hit.is_empty() and absf((hit.position as Vector2).y-1260.0)<.5
		check(supported,"real floor supports arena/rest sample x"+str(x))
		var body_query:=PhysicsRayQueryParameters2D.create(Vector2(x,1249),Vector2(x,980),1)
		var clear:=space.intersect_ray(body_query).is_empty()
		check(clear,"real body/air space is clear at x"+str(x))
		floor_samples.append({"x":x,"supported":supported,"body_space_clear":clear})
	var report: Dictionary={"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"camera":{"center":[1650,1010],"zoom":[.84,.84]},"actors":{"hero":[1360,1260],"bell":[1850,1260]},"platform_count":shape_count,"light_count":world.visuals.light_specs.size(),"physics_samples":floor_samples,"captures":captures,"scope":"Room12 visual/collision ownership review only. Configured frozen actor comparison. No 15-room rerun, full fight or subjective feel claim."}
	FileAccess.open("user://m24_environment_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M24 ENVIRONMENT REPORT ",JSON.stringify(report))
	world.active_room.process_mode=Node.PROCESS_MODE_DISABLED
	world.soundscape.stop_all()
	world.boss_music.stop_all()
	for player in world.get_children():
		if player is AudioStreamPlayer:
			player.stop()
			player.stream=null
	await create_timer(.15).timeout
	world.queue_free()
	world=null
	for index in range(4): await process_frame
	quit(0 if failures.is_empty() else 1)
