extends RefCounted
## Existing traversal remains native. Architecture is anchored to real doors;
## compact interiors keep their original world ID for inventory/coin receipts.
const Base=preload("res://scripts/stage/m28_layouts.gd")

static func count() -> int: return 15
static func room(id: int) -> Dictionary: return all_rooms()[clampi(id,1,15)-1]

static func _building(identity: String, point: Vector2, kind: String, side: int=0, target: int=0) -> Dictionary:
	return {"id":identity,"door":point,"kind":kind,"side":side,"target":target,"width":480.0 if kind=="passage" else 740.0,"height":335.0 if kind=="passage" else 460.0}

static func all_rooms() -> Array[Dictionary]:
	var rooms: Array[Dictionary]=Base.all_rooms()
	for d in rooms:
		d.m29_environment=true
		d.m29_interior=""
		d.m29_buildings=[]
		for e in d.exits:
			var point: Vector2=e.pos
			var side:=(-1 if point.x<float(d.size.x)*.22 else 1 if point.x>float(d.size.x)*.78 else 0)
			d.m29_buildings.append(_building(str(e.id),point,"passage",side,int(e.target)))
		for object in d.objects:
			if str(object.get("kind",""))=="bench":
				object.m29_bench=true
				object.seat_height=28.0
			if str(object.id)=="m28_market":
				object.kind="building_portal"
				object.destination="market"
				object.title_ar="دكان الهامش"
				object.title_en="The Margin Exchange"
				d.m29_buildings.append(_building(str(object.id),object.pos,"market"))
			elif str(object.id)=="archivist_vault_portal":
				object.kind="building_portal"
				object.destination="archivist"
				d.m29_buildings.append(_building(str(object.id),object.pos,"archivist"))
	rooms[11].objects.append({"id":"m29_bell_building","kind":"building_portal","destination":"bell","pos":Vector2(1000,1260),"title_ar":"مشغل حارس الجرس","title_en":"Bell Warden's Bindery"})
	rooms[11].m29_buildings.append(_building("m29_bell_building",Vector2(1000,1260),"bell"))
	rooms[11].challenge_summary.append("Enter the complete bindery building to reach the real Bell chamber. Its exterior does not start combat.")
	return rooms

static func interior_room(kind: String) -> Dictionary:
	if kind=="bell":
		var d: Dictionary=Base.room(12)
		d.m29_environment=true
		d.m29_interior="bell"
		d.m29_buildings=[]
		d.exits=[]
		d.objects.append({"id":"m29_bell_interior_exit","kind":"interior_exit","pos":Vector2(360,1260),"title_ar":"العودة إلى رواق التجليد","title_en":"Return to the bindery street"})
		for object in d.objects:
			if str(object.get("kind",""))=="bench":
				object.m29_bench=true
				object.seat_height=28.0
		return d
	# Quiet, enclosed room: light and objects are close to the player rather
	# than a large faraway hall. Camera limits resolve to one native screen.
	return {"id":4,"title":"The Margin Exchange","title_en":"The Margin Exchange","title_ar":"داخل دكان الهامش","theme":"market","size":Vector2(1280,720),"floor_y":620.0,"scene":"","spawns":{"default":Vector2(280,620),"left":Vector2(280,620),"right":Vector2(280,620)},"platforms":[{"id":"m29_market_floor","rect":Rect2(0,620,1280,100),"one_way":false}],"objects":[{"id":"m29_market_return","kind":"interior_exit","pos":Vector2(150,620),"title_ar":"الخروج إلى ركن الشعلة","title_en":"Return to the Black Flame's corner"},{"id":"m29_market_inside_bench","kind":"bench","pos":Vector2(500,620),"text_key":"bench","title_ar":"استراحة دكان الهامش","title_en":"Margin Exchange Rest","m29_bench":true,"seat_height":28.0},{"id":"m29_market_counter","kind":"shop","pos":Vector2(940,620),"title_ar":"تصفّح أدوات الهامش","title_en":"Browse the Margin tools"}],"exits":[],"hazards":[],"encounters":[],"arrival_flags":[],"encounter_reservations":[],"reading_nooks":[{"id":"m29_market_rest","object_id":"m29_market_inside_bench","anchor":Vector2(500,620),"rect":Rect2(370,480,260,180),"style":"rest","height":72.0}],"protected_spaces":[Rect2(0,0,1280,720)],"entrance_frames":[],"challenge_summary":["A close one-screen shop, safe resting seat and physical return doorway."],"qa_paths":{},"qa_actions":{},"m28_hurdles":[],"m28_gaps":[],"m28_vents":[],"m28_pressure_plates":[],"m28_relays":[],"m28_routes":{},"m28_doorways":[],"m29_environment":true,"m29_interior":"market","m29_buildings":[]}
