extends RefCounted
## M28 preserves the fifteen-room graph while adding real, recoverable traversal.
## Every lip in m28_routes belongs to a collision-bearing platform below.
const Base = preload("res://scripts/stage/m23_layouts.gd")

static func count() -> int: return 15
static func room(id: int) -> Dictionary: return all_rooms()[clampi(id,1,15)-1]

static func _surface(d: Dictionary, id: String, rect: Rect2, one_way: bool=false, requires: Variant=[]) -> void:
	d.platforms.append({"id":id,"rect":rect,"one_way":one_way,"requires":requires,"m28_added":true,"footstep_surface":"paper"})

static func _hurdle(d: Dictionary, id: String, x: float, floor_value: float, width_value: float, height_value: float) -> void:
	var rect := Rect2(x,floor_value-height_value,width_value,height_value)
	_surface(d,id,rect)
	d.m28_hurdles.append({"id":id,"rect":rect})
	d.challenge_summary.append("A solid bound-volume threshold asks for a controlled jump: "+id)

static func _gap(d: Dictionary, id: String, source: String, x: float, width_value: float) -> void:
	for p in d.platforms.duplicate():
		if str(p.id)!=source: continue
		var r: Rect2=p.rect
		d.platforms.erase(p)
		_surface(d,source+"_west",Rect2(r.position,Vector2(x-r.position.x,r.size.y)),true,p.get("requires",[]))
		_surface(d,source+"_east",Rect2(x+width_value,r.position.y,r.end.x-x-width_value,r.size.y),true,p.get("requires",[]))
		d.m28_gaps.append({"id":id,"rect":Rect2(x,r.position.y,width_value,r.size.y),"safe_floor":float(d.floor_y)})
		d.challenge_summary.append("A 300px torn shelf asks for a held jump and air dash, with a solid recovery floor below: "+id)
		return

static func _vent(d: Dictionary, id: String, point: Vector2, offset: float) -> void:
	var rect := Rect2(point-Vector2(37,44),Vector2(74,44))
	d.hazards.append({"id":id,"rect":rect,"period":4.8,"telegraph":1.5,"active":.85,"phase_offset":offset,"offset":offset,"type":"m28_ink_vent"})
	d.m28_vents.append({"id":id,"foot":point,"rect":rect,"period":4.8,"telegraph":1.5,"active":.85,"phase_offset":offset})
	d.challenge_summary.append("A visible ink nozzle has a fixed 4.8s rhythm and a safe waiting ledge: "+id)

static func _plate(d: Dictionary, id: String, point: Vector2, flag: String, reward: int=0) -> void:
	d.m28_pressure_plates.append({"id":id,"pos":point,"flag":flag,"reward":reward})

static func _route(d: Dictionary, id: String, start: Vector2, actions: Array) -> void:
	d.m28_routes[id]={"start":start,"actions":actions,"configured_start_only":true}

static func _walk(p: Vector2) -> Dictionary: return {"type":"walk","target":p}
static func _jump(p: Vector2) -> Dictionary: return {"type":"jump","target":p}
static func _drop(p: Vector2) -> Dictionary: return {"type":"drop","target":p}
static func _dash(p: Vector2) -> Dictionary: return {"type":"jump_dash","target":p}
static func _wait(t: int=24) -> Dictionary: return {"type":"wait","ticks":t}

static func all_rooms() -> Array[Dictionary]:
	var rooms: Array[Dictionary]=Base.all_rooms()
	for d in rooms:
		d.m28_hurdles=[]
		d.m28_gaps=[]
		d.m28_vents=[]
		d.m28_pressure_plates=[]
		d.m28_relays=[]
		d.m28_routes={}
		d.m28_environment=true
		d.m28_doorways=[]
		for e in d.exits:
			d.m28_doorways.append({"id":e.id,"pos":e.pos,"target":int(e.target),"requires":e.get("requires",[])})

	_hurdle(rooms[0],"m28_first_bookstep",842,1260,90,82)
	_route(rooms[0],"first_bookstep",Vector2(770,1260),[_walk(Vector2(795,1260)),_jump(Vector2(885,1178)),_drop(Vector2(978,1260))])

	_hurdle(rooms[1],"m28_assignment_binding",2510,900,96,86)
	_route(rooms[1],"assignment_binding",Vector2(2440,900),[_jump(Vector2(2556,814)),_drop(Vector2(2680,900))])

	_vent(rooms[2],"m28_ink_lab_nozzle",Vector2(2650,780),.4)
	_route(rooms[2],"ink_lab_vent",Vector2(2510,780),[_walk(Vector2(2550,780)),_jump(Vector2(2750,780))])

	# The market is a quiet room, separate from the stranger and his reading leaf.
	rooms[3].objects.append({"id":"m28_market","kind":"shop","pos":Vector2(2050,1260),"title_ar":"دكان الهامش","title_en":"The Margin Exchange"})
	rooms[3].objects.append({"id":"m28_market_bench","kind":"bench","pos":Vector2(1740,1260),"text_key":"bench","title_ar":"استراحة السوق","title_en":"Market Rest"})
	rooms[3].reading_nooks.append({"id":"rest_m28_market","object_id":"m28_market_bench","anchor":Vector2(1740,1260),"rect":Rect2(1600,1125,280,180),"style":"rest","height":72.0})
	rooms[3].protected_spaces.append(Rect2(1610,1030,700,300))
	rooms[3].challenge_summary.append("A peaceful bookshop and save bench sit beyond the Black Flame's alcove.")

	_gap(rooms[4],"m28_margin_rift","margin_reading",2360,300)
	_route(rooms[4],"margin_dash",Vector2(2280,780),[_walk(Vector2(2325,780)),_dash(Vector2(2710,780))])

	# Keeper's song comes from the separate real vault beyond this physical door.
	rooms[5].objects.append({"id":"archivist_vault_portal","kind":"boss_portal","boss":"archivist","pos":Vector2(2710,1980),"requires":["weapon_owned"],"title_ar":"باب خزنة أمين الأرشيف","title_en":"Archivist's Vault Door"})
	rooms[5].objects.append({"id":"m28_vault_bench","kind":"bench","pos":Vector2(2460,1860),"text_key":"bench","title_ar":"استراحة خزنة الأرشيف","title_en":"Vault Rest"})
	rooms[5].reading_nooks.append({"id":"rest_m28_vault","object_id":"m28_vault_bench","anchor":Vector2(2460,1860),"rect":Rect2(2340,1725,260,180),"style":"rest","height":72.0})
	rooms[5].protected_spaces.append(Rect2(2470,1770,440,270))
	rooms[5].challenge_summary.append("The Keeper's sealed side vault has a save bench on its outside landing.")

	_hurdle(rooms[6],"m28_input_binding",2130,900,96,90)
	_route(rooms[6],"input_binding",Vector2(2060,900),[_jump(Vector2(2176,810)),_drop(Vector2(2300,900))])

	_vent(rooms[7],"m28_process_nozzle",Vector2(1620,1260),2.2)
	_route(rooms[7],"process_vent",Vector2(1480,1260),[_walk(Vector2(1520,1260)),_jump(Vector2(1720,1260))])

	_gap(rooms[8],"m28_output_rift","output_upper",2450,300)
	_surface(rooms[8],"m28_output_return_bridge",Rect2(2450,780,300,54),true,["output_open","m28_output_span_open"])
	_plate(rooms[8],"output_return_plate",Vector2(2910,780),"m28_output_span_open",12)
	_route(rooms[8],"output_dash_latch",Vector2(2350,780),[_walk(Vector2(2415,780)),_dash(Vector2(2830,780)),_walk(Vector2(2910,780)),_wait()])

	_hurdle(rooms[9],"m28_counterweight_spine",2720,900,110,96)
	# Physical observation puzzle: the ceiling rope shows I, III, II.
	rooms[9].m28_relays=[{"id":"relay_one","pos":Vector2(2150,900),"glyph":0},{"id":"relay_two","pos":Vector2(2490,900),"glyph":1},{"id":"relay_three","pos":Vector2(3080,900),"glyph":2}]
	rooms[9].m28_relay_order=[0,2,1]
	rooms[9].m28_relay_flag="m28_counterweight_relay_solved"
	rooms[9].m28_relay_reward=24
	_surface(rooms[9],"m28_relay_return_step",Rect2(2970,1140,220,54),true,"m28_counterweight_relay_solved")
	_surface(rooms[9],"m28_relay_return_upper_step",Rect2(3240,1020,160,54),true,"m28_counterweight_relay_solved")
	rooms[9].challenge_summary.append("Three pressure seals must be visited I, III, II. A nearby hanging rope gives the order; the 24-coin reward and return step persist.")
	_route(rooms[9],"counterweight_relay",Vector2(2040,900),[_walk(Vector2(2150,900)),_wait(),_walk(Vector2(2660,900)),_jump(Vector2(2775,804)),_drop(Vector2(2920,900)),_walk(Vector2(3080,900)),_wait(),_walk(Vector2(2890,900)),_jump(Vector2(2775,804)),_drop(Vector2(2630,900)),_walk(Vector2(2490,900)),_wait()])
	_route(rooms[9],"relay_return_stair",Vector2(3040,1260),[_jump(Vector2(3050,1140)),_walk(Vector2(3140,1140)),_jump(Vector2(3290,1020)),_jump(Vector2(3300,900))])

	_gap(rooms[10],"m28_lecture_torn_row","lecture_lower",3000,300)
	_route(rooms[10],"lecture_dash",Vector2(2900,900),[_walk(Vector2(2965,900)),_dash(Vector2(3360,900))])

	# Bindery encounter remains the frozen Bell Warden. Decoration has no new
	# collision inside its active arena and introduces no additional hazards.
	rooms[11].m28_bell_door=Vector2(1000,1260)

	_hurdle(rooms[12],"m28_corrector_spine_a",1450,1260,100,90)
	_vent(rooms[12],"m28_corrector_nozzle",Vector2(1830,1260),1.1)
	_hurdle(rooms[12],"m28_corrector_spine_b",2170,1260,110,112)
	_plate(rooms[12],"corrector_tall_plate",Vector2(2225,1148),"m28_corrector_shelf_found",15)
	_route(rooms[12],"corrector_last_spine",Vector2(2100,1260),[_jump(Vector2(2225,1148)),_wait(),_drop(Vector2(2370,1260))])

	rooms[13].title="Sleeping Shelves"
	rooms[13].title_en="Sleeping Shelves"
	rooms[13].title_ar="قاعة الرفوف النائمة"
	rooms[13].challenge_summary.append("The final chamber is reserved for the approved Sleeping Shelf. No missing boss or victory is fabricated.")
	rooms[14].challenge_summary.append("The final threshold remains an explicit one-way departure after real world completion.")
	for capture in [
		{"room":4,"position":Vector2(2050,1260),"tag":"margin_exchange"},
		{"room":6,"position":Vector2(2630,1980),"tag":"archivist_vault_door"},
		{"room":9,"position":Vector2(2370,780),"tag":"torn_output_shelf"},
		{"room":10,"position":Vector2(2460,900),"tag":"counterweight_seals"},
		{"room":12,"position":Vector2(980,1260),"tag":"bell_bindery_door"},
		{"room":13,"position":Vector2(2220,1148),"tag":"corrector_spines"}
	]: rooms[int(capture.room)-1].m28_capture=capture
	return rooms
