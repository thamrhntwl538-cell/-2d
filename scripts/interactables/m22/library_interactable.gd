extends "res://scripts/interactables/m17/library_interactable.gd"
## definition.pos remains the reachable feet anchor. Reading furniture is drawn
## above that anchor, so notes sit in curated nooks rather than on the floor.

var reading_style: String = "lectern"
var reading_height: float = 72.0

func setup(world: Node2D, data: Dictionary) -> void:
	super.setup(world,data)
	reading_style = str(data.get("reading_style","lectern"))
	if reading_style not in ["lectern","shelf","desk"]: reading_style = "lectern"
	reading_height = clampf(float(data.get("reading_height",72.0)),48.0,90.0)

func sync_state() -> void:
	var before := active
	super.sync_state()
	if kind=="margin_lantern":
		var progress := _progress()
		active = bool(progress.get("margin_lantern_solved",false)) or progress.get("lantern_sequence_history",[]).has(int(definition.get("station",-1)))
	if before!=active: activation_pulse = 1.0
	queue_redraw()

func visual_size() -> Vector2:
	if kind in ["note","secret","book"]: return Vector2(120,reading_height+40)
	if kind=="margin_lantern": return Vector2(86,132)
	return super.visual_size()

func _reading_support() -> void:
	var h := reading_height
	_ellipse(Vector2(0,3),Vector2(49,7),Color(0,0,0,.35))
	match reading_style:
		"desk":
			for x in [-37,37]:
				draw_line(Vector2(x,-h+14),Vector2(x-signf(float(x))*4,-2),Color("65523a"),5,true)
				draw_line(Vector2(x-4,-5),Vector2(x+4,-5),GOLD,2,true)
			_round_rect(Rect2(-51,-h+4,102,13),Color("3a332b"),3,Color("927548"),1)
			draw_line(Vector2(-48,-h+5),Vector2(48,-h+5),Color("ba9861"),1.4,true)
			_book(Vector2(-32,-h+2),Vector2(19,11),Color("364252"),"",false)
		"shelf":
			_round_rect(Rect2(-48,-h-22,96,h+22),Color("15232e"),3,Color("735c3d"),1)
			for x in [-43,43]: draw_line(Vector2(x,-h-20),Vector2(x,-2),Color("7d6541"),3,true)
			for y in [-h+19,-13]:
				draw_line(Vector2(-45,y),Vector2(45,y),Color("a48756"),4,true)
			for index in range(5):
				var x := -34+index*13
				var height := 24+(index%3)*5
				_round_rect(Rect2(x,-13-height,10,height),[Color("394357"),Color("583d39"),Color("33463f")][index%3],1,Color("72634b"),1)
				draw_line(Vector2(x+2,-13-height+5),Vector2(x+8,-13-height+5),Color("b49b6d"),1,true)
		"lectern":
			_round_rect(Rect2(-25,-7,50,7),Color("34302a"),3,GOLD,1)
			draw_line(Vector2(0,-h+12),Vector2(0,-7),Color("7d6341"),7,true)
			draw_line(Vector2(-13,-h+24),Vector2(0,-h+11),Color("a28553"),2.5,true)
			draw_line(Vector2(13,-h+24),Vector2(0,-h+11),Color("a28553"),2.5,true)
			var board := PackedVector2Array([Vector2(-37,-h+5),Vector2(29,-h-6),Vector2(38,-h+12),Vector2(-29,-h+23)])
			draw_colored_polygon(board,Color("3c352c"))
			var edge := board.duplicate()
			edge.append(edge[0])
			draw_polyline(edge,Color("a28655"),1.2,true)

func _reading_page() -> void:
	var h := reading_height
	var paper := Color("e7d6ae") if not active else Color("c9bc9c")
	var left := PackedVector2Array([Vector2(-30,-h-10),Vector2(-2,-h-7),Vector2(0,-h+15),Vector2(-27,-h+11)])
	var right := PackedVector2Array([Vector2(-2,-h-7),Vector2(27,-h-13),Vector2(31,-h+8),Vector2(0,-h+15)])
	draw_colored_polygon(left,paper.darkened(.04))
	draw_colored_polygon(right,paper)
	draw_polyline(PackedVector2Array([left[0],left[1],right[1],right[2],left[3],left[0]]),Color("9b8252"),.9,true)
	draw_line(Vector2(-2,-h-7),Vector2(0,-h+14),Color("9a865d"),1,true)
	for index in range(3):
		var y := -h-3+index*4
		draw_line(Vector2(-24,y),Vector2(-7,y+2),Color("82775c"),.8,true)
		draw_line(Vector2(6,y+1),Vector2(24,y-2),Color("82775c"),.8,true)
	# A physical ribbon marks a page already entered in the field journal.
	if active:
		draw_colored_polygon(PackedVector2Array([Vector2(12,-h-11),Vector2(17,-h-12),Vector2(20,-h+18),Vector2(16,-h+15),Vector2(13,-h+19)]),Color("84503d"))
	else:
		_glow(Vector2(3,-h),25,Color("e5b967"),.025+.025*float(highlighted))
	if activation_pulse>0:
		draw_arc(Vector2(0,-h+2),32,PI*.08,PI*.92,30,Color(1,.78,.39,activation_pulse*.42),1.6,true)

func _reading_book() -> void:
	var symbol := str(definition.get("symbol",definition.get("book_id","TRIANGLE"))).to_upper()
	var cover := Color("714942") if symbol=="TRIANGLE" else (Color("35495c") if symbol=="SQUARE" else Color("30483f"))
	if not active:
		_book(Vector2(0,-reading_height+15),Vector2(39,49),cover,symbol)
		if highlighted: _glow(Vector2(0,-reading_height-6),31,Color("e4bd77"),.035)
	else:
		_glyph(symbol,Vector2(0,-reading_height+1),9,Color(GOLD,.42),1.1)

func _lamp_glyph(center: Vector2, station: int, color: Color) -> void:
	match station:
		0:
			draw_arc(center+Vector2(0,3),10,PI,TAU,24,color,1.8,true)
			draw_line(center+Vector2(-10,3),center+Vector2(-10,10),color,1.8,true)
			draw_line(center+Vector2(10,3),center+Vector2(10,10),color,1.8,true)
		1:
			draw_polyline(PackedVector2Array([center+Vector2(0,-12),center+Vector2(9,0),center+Vector2(0,12),center+Vector2(-9,0),center+Vector2(0,-12)]),color,1.8,true)
		2:
			for angle in [-.65,0,.65]: draw_line(center+Vector2(0,8),center+Vector2(sin(angle)*13,-10),color,1.8,true)

func _margin_lamp() -> void:
	_ellipse(Vector2(0,3),Vector2(30,6),Color(0,0,0,.35))
	_round_rect(Rect2(-23,-7,46,7),Color("332f29"),3,GOLD,1)
	draw_line(Vector2(0,-49),Vector2(0,-7),Color("6b583e"),6,true)
	_round_rect(Rect2(-22,-114,44,65),Color("172431"),5,Color("ad8a50"),2)
	draw_line(Vector2(-25,-116),Vector2(25,-116),Color("c7a05f"),3,true)
	draw_arc(Vector2(0,-117),8,PI,TAU,20,GOLD,2,true)
	draw_line(Vector2(-16,-52),Vector2(16,-52),GOLD,2,true)
	var strength := .10+.24*float(active)+.07*float(highlighted)+activation_pulse*.13
	_glow(Vector2(0,-82),39,Color("efbc64"),strength*.28)
	_round_rect(Rect2(-16,-108,32,52),Color(.88,.60,.24,.09+.15*float(active)),2)
	_lamp_glyph(Vector2(0,-82),int(definition.get("station",0)),Color("ffe3a1") if active else Color("b6a482"))
	if active: draw_circle(Vector2(0,-61),2.1,Color("ffe6a0"))

func _draw() -> void:
	if kind in ["note","secret","book"]:
		_reading_support()
		if kind=="book": _reading_book()
		else: _reading_page()
		if highlighted:
			draw_arc(Vector2(0,-4),26,PI*.12,PI*.88,30,Color(.91,.73,.38,.28+.06*sin(elapsed*2)),1.3,true)
	elif kind=="margin_lantern":
		_margin_lamp()
	else:
		super._draw()
