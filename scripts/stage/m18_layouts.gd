extends RefCounted
const Base = preload("res://scripts/stage/m17_layouts.gd")
static func count() -> int: return 15
static func room(id: int) -> Dictionary: return all_rooms()[clampi(id,1,15)-1]
static func all_rooms() -> Array[Dictionary]:
	var rooms: Array[Dictionary] = Base.all_rooms()
	rooms[0].objects.append({"id":"first_wick","kind":"fitil_pickup","fitil":"wick","pos":Vector2(445,1260)})
	rooms[0].objects.append({"id":"lantern_dash","kind":"dash_pickup","pos":Vector2(1500,1260)})
	rooms[0].objects.append({"id":"entry_pogo_ring","kind":"pogo_anchor","pos":Vector2(1760,1160)})
	rooms[1].objects.append({"id":"ink_cleave","kind":"spell_pickup","pos":Vector2(1450,1260)})
	rooms[1].objects.append({"id":"long_wick","kind":"fitil_pickup","fitil":"reach","pos":Vector2(3050,900)})
	rooms[1].objects.append({"id":"assignment_pogo_ring","kind":"pogo_anchor","pos":Vector2(700,1155)})
	rooms[2].objects.append({"id":"lantern_capacity_1","kind":"capacity_pickup","pos":Vector2(790,1260)})
	rooms[2].objects.append({"id":"ink_pogo_ring","kind":"pogo_anchor","pos":Vector2(1530,1130)})
	rooms[5].objects.append({"id":"quiet_fitil","kind":"fitil_pickup","fitil":"focus","pos":Vector2(390,1980)})
	for exit in rooms[1].exits:
		if int(exit.get("target",0))==3: exit.combat_preview=false
	return rooms
