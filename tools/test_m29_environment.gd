extends SceneTree
## Native geometry contracts. Advanced puzzle requirements are configured only
## to inspect each door's actual supporting body; this is not a campaign win.
const Layouts=preload("res://scripts/stage/m29_layouts.gd")
const Previous=preload("res://scripts/stage/m28_layouts.gd")
const WORLD="res://scenes/stage_01/folding_library_m29.tscn"
var checks:=0
var failures: Array[String]=[]
var support: Array[Dictionary]=[]
var world: Node2D

func _initialize() -> void: run.call_deferred()
func step(n: int=1) -> void:
	for i in range(n): await physics_frame
func check(value: bool, label: String) -> void:
	checks+=1
	if not value:
		failures.append(label)
		print("M29 ENV FAIL ",label)
func open_requirements(value: Variant) -> void:
	if value is Array:
		for flag in value: open_requirements(flag)
	elif value is String and not value.is_empty(): world.progress[value]=true
func floor_at(point: Vector2) -> bool:
	var query:=PhysicsRayQueryParameters2D.create(point-Vector2(0,3),point+Vector2(0,12),1)
	return not world.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("m29_environment"):
		push_error("Use an isolated m29_environment userdata path")
		quit(2)
		return
	var originals:=Previous.all_rooms()
	var rooms:=Layouts.all_rooms()
	check(rooms.size()==15,"The approved fifteen-area graph is retained")
	var portal_count:=0
	var door_count:=0
	for i in range(15):
		var d: Dictionary=rooms[i]
		check(d.platforms==originals[i].platforms,"Room %d keeps approved collision surfaces" % [i+1])
		check(d.hazards==originals[i].hazards,"Room %d keeps approved traversal hazard timing" % [i+1])
		check(d.exits==originals[i].exits,"Room %d keeps approved exits and puzzle gates" % [i+1])
		for exit in d.exits:
			var matches:=0
			for b in d.m29_buildings:
				if str(b.id)==str(exit.id) and (b.door as Vector2).distance_to(exit.pos)<.01: matches+=1
			check(matches==1,"Room %d exit %s has exactly one whole-building anchor" % [i+1,exit.id])
			door_count+=1
		for object in d.objects:
			if str(object.get("kind",""))=="building_portal":
				portal_count+=1
				check(str(object.destination) in ["market","archivist","bell"],"A building names a real authored interior")
	check(portal_count==3,"The three major entrances are market, vault and bindery")
	var market:=Layouts.interior_room("market")
	check(market.size==Vector2(1280,720) and market.floor_y==620.0,"Market interior is a close one-screen room")
	check(market.exits.is_empty() and market.hazards.is_empty() and market.encounters.is_empty(),"Quiet market has a real return object and no encounter hazards")
	var bell:=Layouts.interior_room("bell")
	check(bell.platforms==originals[11].platforms and bell.floor_y==1260.0,"Bell interior retains approved combat floor geometry")
	check(bell.objects.any(func(item: Dictionary): return str(item.get("kind",""))=="interior_exit" and (item.pos as Vector2).distance_to(Vector2(556,1260))>118),"Bell return door does not collide with the bench interaction")
	world=load(WORLD).instantiate()
	world.restore_saved_game=false
	root.add_child(world)
	await step(10)
	for d in rooms:
		for p in d.platforms: open_requirements(p.get("requires",[]))
	world.progress.weapon_owned=true
	world.combat_state.dash_owned=true
	world.combat_state.spell_owned=true
	for id in range(1,16):
		world.interior_kind=""
		world._load_room(id,"left")
		await step(3)
		check(is_instance_valid(world.visuals) and world.visuals.has_method("get_m29_environment_snapshot"),"Room %d creates the actual close architecture renderer" % id)
		check(floor_at(world.hero.position),"Room %d entrance rests on native collision" % id)
		for b in world.data.get("m29_buildings",[]):
			var valid:=floor_at(b.door)
			support.append({"room":id,"id":b.id,"point":[b.door.x,b.door.y],"supported":valid})
			check(valid,"Room %d building %s threshold is physically supported" % [id,b.id])
	for kind in ["market","bell"]:
		world.interior_kind=kind
		world._load_room(4 if kind=="market" else 12,"left")
		await step(3)
		check(str(world.data.get("m29_interior",""))==kind,"The real room provider builds the %s interior" % kind)
		check(floor_at(world.hero.position),"The %s interior entry is supported" % kind)
		for item in world.data.objects:
			if str(item.get("kind","")) in ["bench","shop","interior_exit"]:
				check(floor_at(item.pos),"The %s %s anchor is supported" % [kind,item.id])
	var report: Dictionary={"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"doors_checked":door_count,"major_buildings":portal_count,"native_threshold_support":support,"scope":"Geometry/door contracts, all fifteen configured room starts and real surface rays, and compact market/Bell interiors. Requirements opened for geometry inspection; not a full campaign traversal."}
	FileAccess.open("user://m29_environment_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	world.queue_free()
	await step(5)
	print("M29 ENVIRONMENT ",checks," checks; failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
