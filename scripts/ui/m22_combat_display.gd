extends "res://scripts/ui/m18_hud.gd".LanternDisplay
## One shared reserve; lantern health replaces the former heart silhouettes.
const FITIL_CATALOG := preload("res://scripts/combat/m18_combat_state.gd").FITILS
const ORB_CENTER := Vector2(53,60)
const ORB_RADIUS := 42.0
const HEALTH_START := Vector2(121,24)
const HEALTH_STEP := 31.0
var gain_flash: float = 0.0
var heal_flash: float = 0.0
var wallet_flash: float = 0.0
var hurt_slots: Array[int] = []
var healed_slots: Array[int] = []
var previous_wallet: int = 0

func _ready() -> void:
	super._ready()
	custom_minimum_size = Vector2(340,146)

func update_context(value: Dictionary, locale: String) -> void:
	var next_hp := clampi(int(value.get("hp",6)),0,6)
	var next_energy := float(value.get("energy",99.0))
	if next_hp<old_hp:
		hurt_slots.clear()
		for index in range(next_hp,old_hp): hurt_slots.append(index)
	elif next_hp>old_hp:
		heal_flash = .30
		healed_slots.clear()
		for index in range(old_hp,next_hp): healed_slots.append(index)
	if next_energy>last_energy+.01: gain_flash = .24
	var next_wallet := int(value.get("wallet",0))
	if next_wallet!=previous_wallet: wallet_flash = .25
	previous_wallet = next_wallet
	super.update_context(value,locale)

func _process(delta: float) -> void:
	super._process(delta)
	gain_flash = maxf(0,gain_flash-delta)
	heal_flash = maxf(0,heal_flash-delta)
	wallet_flash = maxf(0,wallet_flash-delta)

func _clip_liquid(points: PackedVector2Array, surface: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	if points.is_empty(): return result
	var previous := points[-1]
	var previous_inside := previous.y>=surface
	for current in points:
		var current_inside := current.y>=surface
		if current_inside!=previous_inside:
			var t := (surface-previous.y)/(current.y-previous.y)
			result.append(previous.lerp(current,t))
		if current_inside: result.append(current)
		previous = current
		previous_inside = current_inside
	return result

func _has_polygon_area(points: PackedVector2Array) -> bool:
	if points.size()<3: return false
	var twice_area := 0.0
	for i in range(points.size()): twice_area += points[i].cross(points[(i+1)%points.size()])
	return absf(twice_area)>.01

func _energy_orb(ratio: float) -> void:
	var center := ORB_CENTER
	var radius := ORB_RADIUS
	for index in range(5,0,-1):
		draw_circle(center,radius+index*2.8,Color(.95,.65,.24,.014+.006*gain_flash/.24))
	draw_circle(center,radius+4,Color("080f18"))
	draw_circle(center,radius+1,Color("604c35"))
	draw_circle(center,radius-1,Color("111c27"))
	var disk := PackedVector2Array()
	for index in range(80): disk.append(center+Vector2(cos(TAU*index/80.0),sin(TAU*index/80.0))*(radius-4))
	var surface := center.y+(radius-4)*(1.0-2.0*ratio)
	var liquid := _clip_liquid(disk,surface)
	if _has_polygon_area(liquid):
		draw_colored_polygon(liquid,Color("bf7c36") if spend_flash<=0 else Color("f6c97b"))
		var core := _clip_liquid(disk,surface+4)
		if _has_polygon_area(core): draw_colored_polygon(core,Color(.98,.66,.27,.31))
		var half_width := sqrt(maxf(0,pow(radius-4,2)-pow(surface-center.y,2)))
		if half_width>1:
			draw_line(Vector2(center.x-half_width,surface),Vector2(center.x+half_width,surface),Color(1,.84,.53,.65),1.2,true)
	if ratio>.015:
		var height := lerpf(8.0,44.0,ratio)
		var sway := sin(age*3.4)*1.4
		var flame := PackedVector2Array([center+Vector2(-13,24),center+Vector2(-16,13),center+Vector2(-10,2),center+Vector2(-5,11-height*.48),center+Vector2(3+sway,20-height),center+Vector2(7,3),center+Vector2(15,17),center+Vector2(11,27),center+Vector2(0,31)])
		draw_colored_polygon(flame,Color("ffe4a3"))
		var white_core := PackedVector2Array([center+Vector2(-6,25),center+Vector2(-5,16),center+Vector2(1,17-height*.32),center+Vector2(7,23),center+Vector2(2,30)])
		draw_colored_polygon(white_core,Color("fff8db"))
	draw_arc(center,radius,0,TAU,90,Color("c8a66b"),1.6,true)
	draw_arc(center,radius-5,PI*1.05,PI*1.72,30,Color(1,.91,.70,.42),1.1,true)
	# The handle and bottom collar make the round vessel part of the lantern family.
	draw_arc(center+Vector2(0,-radius-3),6,PI,TAU,18,Color("d0ac70"),1.5,true)
	draw_line(center+Vector2(-13,-radius-2),center+Vector2(13,-radius-2),Color("a88a59"),2,true)
	draw_line(center+Vector2(-17,radius+4),center+Vector2(17,radius+4),Color("8e754e"),2.3,true)
	for index in range(3):
		var angle := PI*.28+index*.22
		var tick := center+Vector2(cos(angle),sin(angle))*(radius+5)
		draw_circle(tick,1.7,Color("ffe4a0") if ratio>=(index+1)/3.0-.002 else Color("6b6555"))
	if gain_flash>0: draw_arc(center,radius+6,PI*.92,PI*2.06,54,Color(1,.85,.48,gain_flash/.24*.50),1.5,true)

func _health_lantern(index: int, filled: bool) -> void:
	var center := HEALTH_START+Vector2(HEALTH_STEP*index,0)
	var hurt_t := damage_flash/.22 if hurt_slots.has(index) else 0.0
	var heal_t := heal_flash/.30 if healed_slots.has(index) else 0.0
	var jitter := Vector2(sin(age*64.0)*hurt_t*1.1,(1.0-hurt_t)*hurt_t*4.0)
	draw_set_transform(center+jitter)
	if filled: draw_circle(Vector2(0,1),14,Color(1,.70,.26,.06+.09*heal_t))
	var shell := PackedVector2Array([Vector2(-8,-10),Vector2(8,-10),Vector2(9,-4),Vector2(7,11),Vector2(-7,11),Vector2(-9,-4),Vector2(-8,-10)])
	draw_colored_polygon(shell,Color("17212a") if filled else Color("101820"))
	draw_polyline(shell,Color("e0bf80") if filled else Color("6b6d64"),1.1,true)
	draw_line(Vector2(-10,-11),Vector2(10,-11),Color("d0ae70") if filled else Color("737364"),1.7,true)
	draw_line(Vector2(-7,13),Vector2(7,13),Color("a58c61") if filled else Color("5b625d"),1.6,true)
	draw_arc(Vector2(0,-13),3.1,PI,TAU,13,Color("c2a36d") if filled else Color("676d64"),1.1,true)
	var alpha := 1.0-heal_t*.75 if filled else hurt_t*.82
	if alpha>.01:
		var flame := PackedVector2Array([Vector2(-4.5,7),Vector2(-5,2),Vector2(-2,-2),Vector2(.7,-7),Vector2(2,-1),Vector2(5,4),Vector2(3,8),Vector2(-1,9)])
		draw_colored_polygon(flame,Color(1,.77,.31,alpha))
		draw_colored_polygon(PackedVector2Array([Vector2(-2,7),Vector2(0,0),Vector2(2.2,6),Vector2(0,8)]),Color(1,.97,.80,alpha))
	if hurt_t>0:
		for spark in range(3):
			var travel := 1.0-hurt_t
			var point := Vector2((spark-1)*5.0*travel,-6-13*travel+spark*2)
			draw_circle(point,1.0,Color(1,.73,.33,hurt_t*.8))
	if heal_t>0: draw_arc(Vector2.ZERO,15,PI*.1,PI*1.9,30,Color(1,.86,.53,heal_t*.6),1.0,true)
	draw_set_transform(Vector2.ZERO)

func _small_fitil(center: Vector2, identity: String) -> void:
	draw_circle(center,9,Color("13212b"))
	draw_arc(center,9,0,TAU,28,Color("ab966f"),1.0,true)
	var ink := Color("e6d3a5")
	match identity:
		"reach":
			draw_line(center+Vector2(-4,4),center+Vector2(5,-5),ink,1.8,true)
			draw_line(center+Vector2(-4,0),center+Vector2(0,4),Color("a68d5d"),1.2,true)
		"focus":
			draw_arc(center,4.5,PI*.12,PI*1.85,20,ink,1.3,true)
			draw_circle(center,1.6,Color("ffe9b2"))
		_:
			draw_polyline(PackedVector2Array([center+Vector2(-3,4),center+Vector2(-4,0),center+Vector2(1,-5),center+Vector2(4,2),center+Vector2(1,5)]),ink,1.4,true)

func _technique(center: Vector2) -> void:
	var owned := bool(context.get("spell_owned",false))
	var ready := owned and float(context.get("energy",0))>=33.0
	var ink := Color("ffe2a0") if ready else Color("5f6d70")
	var points := PackedVector2Array([center+Vector2(0,-13),center+Vector2(13,0),center+Vector2(0,13),center+Vector2(-13,0),center+Vector2(0,-13)])
	draw_colored_polygon(points,Color("322c23") if ready else Color("14212a"))
	draw_polyline(points,ink,1.2,true)
	if owned: draw_polyline(PackedVector2Array([center+Vector2(-5,4),center+Vector2(2,-6),center+Vector2(0,1),center+Vector2(5,-3)]),ink,1.5,true)
	else:
		draw_arc(center+Vector2(0,-2),3.5,PI,TAU,12,ink,1,true)
		draw_rect(Rect2(center+Vector2(-3.5,-2),Vector2(7,6)),ink,false,1)

func _draw() -> void:
	var ratio := clampf(shown_energy/maxf(1.0,float(context.get("max_energy",99.0))),0,1)
	_energy_orb(ratio)
	var health := clampi(int(context.get("hp",6)),0,6)
	for index in range(6): _health_lantern(index,index<health)
	var coin := Vector2(121,69)
	draw_circle(coin,5.5,Color("74572d"))
	draw_arc(coin,5.5,0,TAU,24,Color("e6c47e"),1.0,true)
	draw_line(coin+Vector2(-1,-3),coin+Vector2(-1,3),Color("ffe7af"),1.2,true)
	draw_line(coin+Vector2(2,-3),coin+Vector2(2,3),Color("caa55b"),1.0,true)
	draw_string(font,Vector2(134,75),str(int(context.get("wallet",0))),HORIZONTAL_ALIGNMENT_LEFT,130,18,Color("fff0c6") if wallet_flash>0 else Color("dfd0ac"))
	_technique(Vector2(306,70))
	var equipped: Array = context.get("equipped",[])
	for index in range(equipped.size()): _small_fitil(Vector2(122+index*25,111),str(equipped[index]))
	var used := int(context.get("used_capacity",0))
	for index in range(mini(int(context.get("capacity",3)),12)):
		draw_circle(Vector2(244+index*6,111),1.55,Color("d3bc85") if index<used else Color("40515a"))
	if bool(context.get("healing",false)):
		var fraction := clampf(float(context.get("heal_progress",0)),0,1)
		draw_arc(ORB_CENTER,ORB_RADIUS+8,-PI*.5,-PI*.5+TAU*fraction,70,Color("f7dfa4"),1.8,true)

func _get_tooltip(at_position: Vector2) -> String:
	if at_position.distance_to(ORB_CENTER)<ORB_RADIUS+9:
		return ("وهج مشترك للعلاج والقدرات: %d / %d" if language=="ar" else "Shared Focus and technique glow: %d / %d") % [int(context.get("energy",0)),int(context.get("max_energy",99))]
	if Rect2(106,2,190,43).has_point(at_position):
		return ("فوانيس الصحة: %d / 6" if language=="ar" else "Health lanterns: %d / 6") % int(context.get("hp",6))
	if at_position.distance_to(Vector2(306,70))<17:
		if not bool(context.get("spell_owned",false)): return "تقنية لم تُكتسب بعد" if language=="ar" else "Technique not yet acquired"
		return ("القدرة جاهزة" if language=="ar" else "Technique ready") if float(context.get("energy",0))>=33 else ("تحتاج إلى مزيد من الوهج" if language=="ar" else "Needs more glow")
	var equipped: Array = context.get("equipped",[])
	for index in range(equipped.size()):
		if at_position.distance_to(Vector2(122+index*25,111))<11:
			var info: Dictionary = FITIL_CATALOG.get(str(equipped[index]),{})
			return str(info.get("name_ar" if language=="ar" else "name_en",""))+"\n"+str(info.get("description_ar" if language=="ar" else "description_en",""))
	return ""
