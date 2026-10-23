extends "res://scripts/stage/m22_room_visuals.gd"
## Only the tribunal changes: close wall stays visible behind the active boss.
func _build_lights() -> void:
	if room_id==14:
		_append_lamp(Vector2(1450,1456),184.0,.72)
		_append_lamp(Vector2(2690,1456),184.0,.72)
	super._build_lights()

func _tribunal() -> void:
	# Keep every large pale page and decoration outside the combat rectangle.
	# M22's painted wall, three depth layers and foreground remain inherited.
	_shelf(Vector2(1200,floor_y+16),Vector2(152,300),23,.72)
	_shelf(Vector2(3170,floor_y+16),Vector2(180,330),31,.70)
	_book(Rect2(1190,floor_y-84,72,84),Color("3d3b44"))
	_book(Rect2(2895,floor_y-112,62,112),Color("343a46"))
	_paper(Rect2(1207,floor_y-99,39,61),Color("8d816a"))
	_paper(Rect2(2905,floor_y-125,34,59),Color("887d6b"))
