extends Node2D
## Original low brass/paper bench. No physics or inventory lives in furniture.
var seat_height := 28.0
var occupied := false
var glow := 0.0
const PULSE_SECONDS := .55
var pulse_remaining := 0.0

func setup(height_value: float=28.0) -> void:
	seat_height=clampf(height_value,20,36)
	z_index=3
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_process(false)
	queue_redraw()

func set_occupied(value: bool) -> void:
	occupied=value
	pulse_remaining=PULSE_SECONDS if value else 0.0
	set_process(value)
	queue_redraw()

func _process(delta: float) -> void:
	pulse_remaining=maxf(0,pulse_remaining-delta)
	if pulse_remaining<=0: set_process(false)
	queue_redraw()

func get_pulse_snapshot() -> Dictionary:
	return {"active":pulse_remaining>0,"remaining":pulse_remaining,"occupied":occupied,"duration":PULSE_SECONDS,"physics_nodes":0}

func _draw() -> void:
	var brass:=Color("a88c5b")
	var shadow:=Color("161d2b")
	var edge:=Color("6d6455")
	# Footing is the same room floor used by the actor and checkpoint.
	draw_set_transform(Vector2.ZERO)
	for side in [-1.0,1.0]:
		var x: float=float(side)*56
		draw_polyline(PackedVector2Array([Vector2(x-side*6,-seat_height+4),Vector2(x,-8),Vector2(x+side*8,-1),Vector2(x+side*14,-1)]),shadow,7,true)
		draw_polyline(PackedVector2Array([Vector2(x-side*6,-seat_height+4),Vector2(x,-8),Vector2(x+side*8,-1),Vector2(x+side*14,-1)]),brass,2,true)
	var back:=StyleBoxFlat.new()
	back.bg_color=Color("192532")
	back.border_color=edge
	back.set_border_width_all(2)
	back.set_corner_radius_all(12)
	draw_style_box(back,Rect2(-67,-seat_height-33,134,30))
	draw_line(Vector2(-53,-seat_height-19),Vector2(53,-seat_height-19),Color("3f4951"),1,true)
	for side in [-1.0,1.0]:
		var x: float=float(side)*65
		var p:=PackedVector2Array()
		for i in range(19):
			var t:=float(i)/18
			p.append(Vector2(x+side*(10*sin(t*PI)),lerpf(-seat_height+4,-seat_height-15,t)))
		draw_polyline(p,shadow,7,true)
		draw_polyline(p,brass,2.2,true)
		draw_arc(Vector2(x,-seat_height-19),5,PI*.15,PI*1.8,24,brass,2,true)
	var cushion:=StyleBoxFlat.new()
	cushion.bg_color=Color("27323c")
	cushion.border_color=brass
	cushion.set_border_width_all(1)
	cushion.set_corner_radius_all(4)
	draw_style_box(cushion,Rect2(-74,-seat_height,148,8))
	draw_line(Vector2(-66,-seat_height+2),Vector2(66,-seat_height+2),Color("bca77d"),1.4,true)
	# Small seam marks stay broad enough to read at gameplay scale.
	for x in [-48,-24,0,24,48]: draw_line(Vector2(x,-seat_height+5),Vector2(x+5,-seat_height+5),Color("64716f"),1,true)
	if occupied:
		draw_arc(Vector2(0,-seat_height-16),4,PI*.15,PI*.85,14,Color("ddbc80"),1.4,true)
	if pulse_remaining>0:
		var strength:=pulse_remaining/PULSE_SECONDS
		var age:=1-strength
		var center:=Vector2(0,-seat_height-12)
		for i in range(4,0,-1):
			draw_circle(center,float(i)*17.0,Color(1,.68,.30,.012*strength*strength))
		draw_arc(center,24+age*38,PI*1.08,PI*1.92,42,Color(1,.79,.43,.24*strength*strength),1.4,true)
		for i in range(5):
			var point:=center+Vector2(-29+float(i)*14.5+sin(age*3+float(i)*1.7)*3,-3-age*(12+float(i%3)*6))
			draw_circle(point,.85+float(i%2)*.2,Color(1,.81,.48,.62*strength*strength),true,-1,true)
