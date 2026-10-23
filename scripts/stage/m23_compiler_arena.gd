extends Node2D
## Close, non-damaging book gates. The world owns encounter state and camera.
var world_ref: Node2D
var definition: Dictionary={}
var arena_rect:=Rect2(1320,1020,1500,420)
var intro_threshold_x:=1370.0
var safe_checkpoint_spawn:=Vector2(1040,1440)
var boss_spawn:=Vector2(2450,1440)
var camera_center:=Vector2(2070,1180)
var camera_zoom:=Vector2(.78,.78)
var locked:=false
var defeated:=false
var phase:=1
var phase_pulse:=0.0
var gates: Array[StaticBody2D]=[]
var gate_rects: Array[Rect2]=[]

class BookGate extends StaticBody2D:
	var closed:=false
	var gate_size:=Vector2(32,320)
	var phase_value:=1
	var shape: CollisionShape2D
	func configure(rect: Rect2) -> void:
		position=Vector2(rect.position.x,rect.end.y)
		gate_size=rect.size
		collision_layer=0
		collision_mask=0
		z_as_relative=false
		z_index=2
		shape=CollisionShape2D.new()
		var box:=RectangleShape2D.new()
		box.size=gate_size
		shape.shape=box
		shape.position=Vector2(gate_size.x*.5,-gate_size.y*.5)
		shape.disabled=true
		add_child(shape)
	func set_closed(value: bool) -> void:
		closed=value
		set_deferred("collision_layer",1 if value else 0)
		shape.set_deferred("disabled",not value)
		queue_redraw()
	func _draw() -> void:
		var visible_height:=gate_size.y if closed else 38.0
		var r:=Rect2(0,-visible_height,gate_size.x,visible_height)
		draw_rect(r,Color("202937"))
		draw_rect(Rect2(5,-visible_height+5,gate_size.x-10,visible_height-5),Color("383a43"))
		draw_line(Vector2(4,-visible_height+3),Vector2(4,-3),Color("c2a371"),2.2,true)
		draw_line(Vector2(gate_size.x-4,-visible_height+3),Vector2(gate_size.x-4,-3),Color("746649"),1.6,true)
		if closed:
			for u in [.13,.43,.79]:
				var yy: float=-gate_size.y*float(u)
				draw_line(Vector2(1,yy),Vector2(gate_size.x-1,yy),Color("a48a5f"),5.0,true)
			var c:=Vector2(gate_size.x*.5,-gate_size.y*.59)
			var color:=Color("d6b27d") if phase_value==1 else Color("dda56c")
			draw_polyline(PackedVector2Array([c+Vector2(0,-13),c+Vector2(7,0),c+Vector2(0,13),c+Vector2(-7,0),c+Vector2(0,-13)]),color,1.8,true)

func setup(world: Node2D, room_data: Dictionary) -> void:
	clear()
	world_ref=world
	definition=room_data
	var spec: Dictionary=definition.get("compiler_trial",{})
	arena_rect=spec.get("arena_rect",arena_rect)
	intro_threshold_x=float(spec.get("intro_threshold_x",1370.0))
	safe_checkpoint_spawn=spec.get("safe_checkpoint_spawn",Vector2(1040,1440))
	boss_spawn=spec.get("boss_spawn",Vector2(2450,1440))
	camera_center=spec.get("camera_center",Vector2(2070,1180))
	camera_zoom=spec.get("camera_zoom",Vector2(.78,.78))
	z_index=-5
	name="CompilerTrialArena"
	for rect in spec.get("gate_rects",[Rect2(1280,1120,32,320),Rect2(2860,1120,32,320)]):
		gate_rects.append(rect)
		var gate:=BookGate.new()
		gate.name="LeftBookGate" if gates.is_empty() else "RightBookGate"
		gate.configure(rect)
		add_child(gate)
		gates.append(gate)
	set_locked(false)
	queue_redraw()

func set_locked(value: bool) -> void:
	locked=value and not defeated
	for gate in gates:
		if is_instance_valid(gate): gate.set_closed(locked)
	queue_redraw()

func pulse_phase(value: int) -> void:
	phase=clampi(value,1,3)
	phase_pulse=1.0
	for gate in gates:
		gate.phase_value=phase
		gate.queue_redraw()
	queue_redraw()

func set_defeated(value: bool=true) -> void:
	defeated=value
	if value: set_locked(false)
	queue_redraw()

func getarena_rect() -> Rect2: return arena_rect
func get_arena_rect() -> Rect2: return arena_rect

func clear() -> void:
	for gate in gates:
		if is_instance_valid(gate):
			remove_child(gate)
			gate.queue_free()
	gates.clear()
	gate_rects.clear()
	locked=false
	defeated=false
	phase=1
	phase_pulse=0.0
	definition={}
	world_ref=null
	queue_redraw()

func _process(delta: float) -> void:
	if phase_pulse>0:
		phase_pulse=maxf(0,phase_pulse-delta*1.25)
		queue_redraw()

func _draw() -> void:
	if definition.is_empty(): return
	# Edge folios sit behind the gates; the1500px combat centre stays quiet.
	var y:=arena_rect.end.y
	for side in [-1.0,1.0]:
		var x:=arena_rect.position.x-62 if side<0 else arena_rect.end.x+62
		var p:=Vector2(x,y)
		draw_colored_polygon(PackedVector2Array([p+Vector2(-24,-9),p+Vector2(-32,-234),p+Vector2(20,-251),p+Vector2(31,-5)]),Color("393945"))
		draw_line(p+Vector2(-21,-219),p+Vector2(-13,-20),Color("7c6e53"),2.0,true)
		for offset in [67.0,145.0]:
			draw_line(p+Vector2(-25,-offset),p+Vector2(25,-offset-5),Color("5c5350"),3.0,true)
	if phase_pulse>0:
		# A restrained glow stays on the edge bindings; no centre-floor shape
		# can be mistaken for an attack warning or a damaging arena hazard.
		for rect in gate_rects:
			draw_line(rect.position+Vector2(-4,9),Vector2(rect.position.x-4,rect.end.y-12),Color(.88,.66,.38,phase_pulse*.28),3.0,true)
