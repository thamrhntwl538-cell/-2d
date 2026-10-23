extends RefCounted
## M22 keeps the approved world graph and folding geometry, then curates safe
## reading places, optional encounters, cover and a few real book thresholds.
const Base = preload("res://scripts/stage/m18_layouts.gd")
const Puzzle = preload("res://scripts/stage/m22_puzzle_state.gd")

static func count() -> int: return 15
static func room(id: int) -> Dictionary: return all_rooms()[clampi(id,1,15)-1]

static func _platform(room_data: Dictionary, id: String, rect: Rect2, one_way := true) -> void:
	room_data.platforms.append({"id":id,"rect":rect,"one_way":one_way,"m22_added":true})

static func _walk(point: Vector2) -> Dictionary: return {"type":"walk","target":point}
static func _jump(point: Vector2) -> Dictionary: return {"type":"jump","target":point}
static func _drop(point: Vector2) -> Dictionary: return {"type":"drop","target":point}
static func _interact(id: String) -> Dictionary: return {"type":"interact","id":id}

static func _replace_value(value: Variant, old_point: Vector2, new_point: Vector2) -> Variant:
	if value is Vector2: return new_point if value.is_equal_approx(old_point) else value
	if value is Array:
		var array: Array = []
		for entry in value: array.append(_replace_value(entry,old_point,new_point))
		return array
	if value is Dictionary:
		var dictionary: Dictionary = {}
		for key in value: dictionary[key] = _replace_value(value[key],old_point,new_point)
		return dictionary
	return value

static func _curate(room_data: Dictionary, id: String, point: Vector2, style: String, approach: Array = [], height_value := 72.0) -> void:
	for object in room_data.objects:
		if str(object.id)!=id: continue
		var old_point: Vector2 = object.pos
		object.pos = point
		object.reading_style = style
		object.reading_height = height_value
		object.nook_id = "reading_"+id
		if room_data.has("qa_paths"):
			room_data.qa_paths = _replace_value(room_data.qa_paths,old_point,point)
		if room_data.has("qa_actions"):
			for route in room_data.qa_actions:
				var actions: Array = []
				for action in room_data.qa_actions[route]:
					if action.has("target") and (action.target as Vector2).is_equal_approx(old_point):
						if not approach.is_empty(): actions.append_array(approach.duplicate(true))
						else:
							var replacement: Dictionary = action.duplicate(true)
							replacement.target = point
							actions.append(replacement)
					else: actions.append(action)
				room_data.qa_actions[route] = actions
		break

static func _paths_from_actions(room_data: Dictionary) -> void:
	for route in room_data.get("qa_actions",{}):
		var points: Array = []
		for action in room_data.qa_actions[route]:
			if action.has("target"): points.append(action.target)
		room_data.qa_paths[route] = points

static func _nooks(room_data: Dictionary) -> void:
	room_data.reading_nooks = []
	room_data.protected_spaces = []
	for key in room_data.spawns:
		var at: Vector2 = room_data.spawns[key]
		room_data.protected_spaces.append(Rect2(at-Vector2(160,150),Vector2(320,210)))
	for object in room_data.objects:
		var kind := str(object.get("kind",""))
		if kind in ["note","book"]:
			if not object.has("reading_style"): object.reading_style="lectern" if kind=="note" else "shelf"
			if not object.has("reading_height"): object.reading_height=72.0
			if not object.has("nook_id"): object.nook_id="reading_"+str(object.id)
			var anchor: Vector2 = object.pos
			room_data.reading_nooks.append({"id":object.nook_id,"object_id":object.id,"anchor":anchor,"rect":Rect2(anchor-Vector2(130,145),Vector2(260,190)),"style":object.reading_style,"height":object.reading_height,"requires":object.get("requires",[])})
			room_data.protected_spaces.append(Rect2(anchor-Vector2(145,155),Vector2(290,215)))
		elif kind in ["bench","dialogue","shortcut","secret_overlay","secret_pop"] or kind.ends_with("_control"):
			var anchor: Vector2 = object.pos
			room_data.protected_spaces.append(Rect2(anchor-Vector2(170,170),Vector2(340,230)))
			if kind=="bench": room_data.reading_nooks.append({"id":"rest_"+str(object.id),"object_id":object.id,"anchor":anchor,"rect":Rect2(anchor-Vector2(145,130),Vector2(290,180)),"style":"rest","height":72.0,"requires":object.get("requires",[])})
	room_data.entrance_frames = []
	for side in ["left","right"]:
		if room_data.spawns.has(side):
			room_data.entrance_frames.append({"id":"entry_"+side,"side":side,"anchor":room_data.spawns[side],"span":190.0,"height":230.0})

static func _encounter(room_data: Dictionary, id: String, type: String, spawn: Vector2, floor_y: float, zone: Rect2, patrol: Vector2, cover_ids: Array = [], optional := true) -> void:
	room_data.encounters.append({"id":id,"type":type,"spawn":spawn,"floor_y":floor_y,"zone":zone,"patrol":patrol,"protected":room_data.protected_spaces.duplicate(),"optional":optional,"cover_ids":cover_ids,"direction":-1,"clear_flag":id,"persist_defeat":true})

static func all_rooms() -> Array[Dictionary]:
	var rooms: Array[Dictionary] = Base.all_rooms()
	for room_data in rooms:
		room_data.encounters = []
		room_data.challenge_summary = []
		room_data.title_en = room_data.get("title","")
		if not room_data.has("qa_paths"): room_data.qa_paths={}
		if not room_data.has("qa_actions"): room_data.qa_actions={}

	# Quiet optional shelves require one deliberate jump, instead of placing
	# every readable page on the same straight floor. Their lower paths stay open.
	_platform(rooms[0],"entrance_reading_shelf",Rect2(1000,1140,300,52))
	_curate(rooms[0],"entrance_note",Vector2(1180,1140),"lectern",[_walk(Vector2(976,1260)),_jump(Vector2(1032,1140)),_walk(Vector2(1180,1140))])
	var opening: Array = []
	for action in rooms[0].qa_actions.main:
		opening.append(action)
		if action.get("id","")=="bench_1": opening.append_array([_walk(Vector2(445,1260)),_interact("first_wick")])
		if action.get("id","")=="entrance_note": opening.append_array([_drop(Vector2(1430,1260)),_walk(Vector2(1500,1260)),_interact("lantern_dash")])
	rooms[0].qa_actions.main=opening
	rooms[0].challenge_summary=["Optional raised reading shelf before the approved exit stair."]

	_platform(rooms[1],"assignment_reading_shelf",Rect2(590,1140,270,52))
	_curate(rooms[1],"assignment_note",Vector2(720,1140),"desk",[_walk(Vector2(566,1260)),_jump(Vector2(622,1140)),_walk(Vector2(720,1140))])
	_curate(rooms[1],"secret_2",Vector2(2900,900),"shelf")
	rooms[1].challenge_summary=["The first encounter remains mandatory; its reading alcove is outside the larva patrol."]

	_platform(rooms[2],"lab_reading_ledge",Rect2(430,1140,260,54))
	_curate(rooms[2],"lab_note",Vector2(520,1140),"shelf",[_walk(Vector2(520,1140))])
	rooms[2].challenge_summary=["Optional upper wraith balcony; the ink console and lower reading route remain safe."]

	_platform(rooms[3],"alcove_reading_shelf",Rect2(1430,1140,300,54))
	_curate(rooms[3],"alcove_note",Vector2(1580,1140),"shelf",[_walk(Vector2(1406,1260)),_jump(Vector2(1462,1140)),_walk(Vector2(1580,1140))])
	rooms[3].challenge_summary=["Peaceful dialogue remains on the floor; a separate raised shelf holds the record."]

	_curate(rooms[4],"secret_5",Vector2(2260,780),"desk")
	for extra in Puzzle.extra_notes():
		var item: Dictionary = extra.duplicate(true)
		item.pos=Vector2(340,1260) if item.id=="margin_lantern_clue" else Vector2(2020,780)
		item.reading_style="lectern" if item.id=="margin_lantern_clue" else "desk"
		item.reading_height=72.0
		rooms[4].objects.append(item)
	for station in [
		{"id":"margin_lantern_arch","station":0,"pos":Vector2(1180,900),"title_ar":"مصباح القوس","title_en":"Arch Lamp"},
		{"id":"margin_lantern_diamond","station":1,"pos":Vector2(650,1140),"title_ar":"مصباح المعيّن","title_en":"Diamond Lamp"},
		{"id":"margin_lantern_rays","station":2,"pos":Vector2(1780,780),"title_ar":"مصباح الأشعة","title_en":"Rays Lamp"}
	]:
		station.kind="margin_lantern"
		station.text_key=station.id
		rooms[4].objects.append(station)
	rooms[4].qa_actions.lantern=[_walk(Vector2(340,1260)),_interact("margin_lantern_clue"),_walk(Vector2(476,1260)),_jump(Vector2(532,1140)),_walk(Vector2(650,1140)),_interact("margin_lantern_diamond"),_walk(Vector2(700,1140)),_jump(Vector2(802,1020)),_walk(Vector2(970,1020)),_jump(Vector2(1072,900)),_walk(Vector2(1180,900)),_interact("margin_lantern_arch"),_walk(Vector2(1240,900)),_jump(Vector2(1342,780)),_walk(Vector2(1780,780)),_interact("margin_lantern_rays"),_walk(Vector2(2020,780)),_interact("margin_lantern_record")]
	rooms[4].challenge_summary=["Optional physical lamp-order puzzle along the existing margins stair; no main-route gate."]

	for entry in [["archive_water_note",Vector2(1950,1980),"desk"],["archive_note",Vector2(850,1260),"shelf"],["secret_6",Vector2(2800,1020),"shelf"],["archive_upper_note",Vector2(1900,540),"lectern"]]:
		_curate(rooms[5],entry[0],entry[1],entry[2])
	rooms[5].challenge_summary=["Approved eighteen-jump main ascent stays unchanged; optional wraith guards the right secret gallery."]

	_platform(rooms[6],"triangle_reading_shelf",Rect2(560,1140,250,54))
	_curate(rooms[6],"book_triangle",Vector2(700,1140),"lectern",[_walk(Vector2(536,1260)),_jump(Vector2(592,1140)),_walk(Vector2(700,1140))],64)
	_curate(rooms[6],"book_square",Vector2(1450,1020),"shelf",[],68)
	_curate(rooms[6],"book_circle",Vector2(2350,900),"desk",[],64)
	rooms[6].challenge_summary=["Three required books are curated at three real shelf heights, with the original collection gate intact."]

	_platform(rooms[7],"process_reading_shelf",Rect2(550,1140,270,54))
	_curate(rooms[7],"process_note",Vector2(670,1140),"lectern",[_walk(Vector2(526,1260)),_jump(Vector2(582,1140)),_walk(Vector2(670,1140))])
	_platform(rooms[7],"turret_cover_08_a",Rect2(2670,784,88,116),false)
	_platform(rooms[7],"turret_cover_08_b",Rect2(3100,790,76,110),false)
	rooms[7].qa_actions.gallery=[_walk(Vector2(1280,1260)),_interact("process_table"),_walk(Vector2(1816,1260)),_jump(Vector2(1872,1140)),_walk(Vector2(2060,1140)),_jump(Vector2(2162,1020)),_walk(Vector2(2350,1020)),_jump(Vector2(2452,900)),_walk(Vector2(2646,900)),_jump(Vector2(2702,784)),_drop(Vector2(2840,900))]
	rooms[7].challenge_summary=["Optional turret balcony with two solid, jumpable book covers; the ground process puzzle remains safe."]

	_curate(rooms[8],"secret_9",Vector2(2640,1260),"shelf")
	rooms[8].challenge_summary=["Approved output stair and lab shortcut remain puzzle-gated; record sits in a curated lower nook."]

	_platform(rooms[9],"balance_reading_shelf",Rect2(470,1140,320,54))
	_curate(rooms[9],"balance_note",Vector2(630,1140),"desk",[_walk(Vector2(446,1260)),_jump(Vector2(502,1140)),_walk(Vector2(630,1140))])
	rooms[9].challenge_summary=["A separate reading step precedes the unchanged balance mechanism and folded bridge."]

	_curate(rooms[10],"lecture_note",Vector2(1450,900),"desk")
	_platform(rooms[10],"lecture_safe_reading_alcove",Rect2(3330,540,360,60))
	_curate(rooms[10],"secret_11",Vector2(3510,540),"shelf")
	_platform(rooms[10],"turret_cover_11_a",Rect2(2690,424,88,116),false)
	_platform(rooms[10],"turret_cover_11_b",Rect2(3120,430,76,110),false)
	var lecture_secret: Array = []
	for action in rooms[10].qa_actions.secret:
		if action.has("target") and (action.target as Vector2).is_equal_approx(Vector2(2760,540)):
			lecture_secret.append_array([_walk(Vector2(2666,540)),_jump(Vector2(2722,424)),_drop(Vector2(2820,540))])
		elif action.has("target") and (action.target as Vector2).is_equal_approx(Vector2(3510,540)):
			lecture_secret.append_array([_walk(Vector2(3096,540)),_jump(Vector2(3152,430)),_jump(Vector2(3352,540)),_walk(Vector2(3510,540))])
		else: lecture_secret.append(action)
	rooms[10].qa_actions.secret=lecture_secret
	rooms[10].qa_actions.secret_return=[_drop(Vector2(3720,900)),_walk(Vector2(3690,900))]
	rooms[10].challenge_summary=["Optional upper turret repeat, cover and a protected reading alcove beyond a short gap; main lower lecture route stays clear."]

	_platform(rooms[11],"bindery_reading_shelf",Rect2(3630,1140,300,54))
	_curate(rooms[11],"secret_12",Vector2(3790,1140),"desk",[_walk(Vector2(3606,1260)),_jump(Vector2(3662,1140)),_walk(Vector2(3790,1140))])
	rooms[11].challenge_summary=["Existing press timing, shutoff and shortcuts stay intact; the optional record is on a safe rear shelf."]

	_platform(rooms[12],"corrector_book_threshold",Rect2(1050,1160,150,100),false)
	for route in ["main","bench"]:
		var actions: Array = []
		for action in rooms[12].qa_actions[route]:
			if action.has("target") and (action.target as Vector2).is_equal_approx(Vector2(2670,1260)):
				actions.append_array([_walk(Vector2(1026,1260)),_jump(Vector2(1082,1160)),_drop(Vector2(1260,1260)),action])
			else: actions.append(action)
		rooms[12].qa_actions[route]=actions
	rooms[12].challenge_summary=["A real 100px book threshold asks for a jump before the future guard approach; guard/seal progression is unchanged."]

	_platform(rooms[13],"tribunal_reading_shelf",Rect2(470,1320,300,54))
	_curate(rooms[13],"tribunal_note",Vector2(620,1320),"lectern",[_walk(Vector2(446,1440)),_jump(Vector2(502,1320)),_walk(Vector2(620,1320))])
	rooms[13].challenge_summary=["Safe entry lectern is lifted off the future boss floor; no boss or victory is fabricated."]

	_platform(rooms[14],"threshold_reading_1",Rect2(950,1140,260,54))
	_platform(rooms[14],"threshold_reading_2",Rect2(1240,1020,300,60))
	_curate(rooms[14],"last_lecture_note",Vector2(1390,1020),"desk")
	_platform(rooms[14],"departure_book_threshold",Rect2(2240,1160,140,100),false)
	rooms[14].qa_actions.main=[_walk(Vector2(926,1260)),_jump(Vector2(982,1140)),_walk(Vector2(1170,1140)),_jump(Vector2(1272,1020)),_walk(Vector2(1390,1020)),_interact("last_lecture_note"),_drop(Vector2(1660,1260)),_walk(Vector2(2216,1260)),_jump(Vector2(2272,1160)),_drop(Vector2(2470,1260)),_walk(Vector2(2670,1260))]
	rooms[14].challenge_summary=["Two-step optional final reading desk and a 100px departure threshold; the approved departure confirmation remains mandatory."]

	for room_data in rooms:
		_nooks(room_data)
		_paths_from_actions(room_data)
	_encounter(rooms[1],"encounter_assignments_cleared","glitch_larva",Vector2(1260,1260),1260,Rect2(1010,1070,490,250),Vector2(1080,1420),[],false)
	_encounter(rooms[2],"lab_popup_wraith","popup_wraith",Vector2(1080,820),900,Rect2(820,610,600,350),Vector2(930,1280))
	_encounter(rooms[5],"archive_popup_wraith","popup_wraith",Vector2(1810,1150),1260,Rect2(1550,960,520,320),Vector2(1640,1990))
	_encounter(rooms[7],"process_syntax_turret","syntax_turret",Vector2(2940,900),900,Rect2(2370,650,830,330),Vector2(2940,2940),["turret_cover_08_a","turret_cover_08_b"])
	_encounter(rooms[10],"lecture_syntax_turret","syntax_turret",Vector2(2910,540),540,Rect2(2510,300,720,300),Vector2(2910,2910),["turret_cover_11_a","turret_cover_11_b"])
	return rooms
