extends Node2D
## Floor response starts only when the actor reports an actual landing.
## Cosmetic only: the two travelling waves own their own visible damage shapes.
const MAX_BURSTS:=3
const MAX_DUST:=72
const MAX_PAPERS:=24
const DUST_PER_SIDE:=12
const PAPER_PER_SIDE:=4
var world_ref: Node2D
var bursts: Array[Dictionary]=[]
var dust: Array[Dictionary]=[]
var papers: Array[Dictionary]=[]
var strike_count:=0
var arena_rect:=Rect2(1110,940,1080,320)
var _rng:=RandomNumberGenerator.new()
var _dust_texture: GradientTexture2D

func setup(world: Node2D) -> void:
	world_ref=world
	name="BellFloorResponse"
	z_as_relative=false
	z_index=3 # Below hero/bell5 and travelling waves7; above the paper floor.
	var unlit:=CanvasItemMaterial.new()
	unlit.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material=unlit
	_rng.seed=2501260
	if is_instance_valid(world_ref):
		var room: Variant=world_ref.get("data")
		if room is Dictionary:
			var spec: Dictionary=room.get("compiler_trial",{})
			arena_rect=spec.get("arena_rect",arena_rect)
	_build_dust_texture()
	clear()

func _build_dust_texture() -> void:
	var gradient:=Gradient.new()
	gradient.offsets=PackedFloat32Array([0,.42,1])
	gradient.colors=PackedColorArray([Color(1,1,1,.86),Color(1,1,1,.42),Color(1,1,1,0)])
	_dust_texture=GradientTexture2D.new()
	_dust_texture.gradient=gradient
	_dust_texture.width=64
	_dust_texture.height=64
	_dust_texture.fill=GradientTexture2D.FILL_RADIAL
	_dust_texture.fill_from=Vector2(.5,.5)
	_dust_texture.fill_to=Vector2(1,.5)

func strike(point: Vector2, phase: int=1) -> void:
	if not is_instance_valid(world_ref) or is_queued_for_deletion(): return
	if _dust_texture==null: _build_dust_texture()
	strike_count+=1
	var strength:=1.0 if phase<=1 else 1.20
	var local_point:=to_local(point)
	bursts.append({"point":local_point,"age":0.0,"life":.38,"strength":strength})
	while bursts.size()>MAX_BURSTS: bursts.pop_front()
	for side in [-1.0,1.0]:
		for index in range(DUST_PER_SIDE):
			var speed:=_rng.randf_range(115,330)*strength
			var radius:=_rng.randf_range(12,26)*strength
			dust.append({"point":local_point+Vector2(side*_rng.randf_range(8,38),-4),"velocity":Vector2(side*speed,_rng.randf_range(-155,-65)*strength),"floor":local_point.y-2,"age":0.0,"life":_rng.randf_range(.44,.78),"radius":radius,"tone":_rng.randf_range(.80,1.0)})
		for index in range(PAPER_PER_SIDE):
			papers.append({"point":local_point+Vector2(side*_rng.randf_range(18,52),-6),"velocity":Vector2(side*_rng.randf_range(80,225)*strength,_rng.randf_range(-245,-145)*strength),"floor":local_point.y-2,"age":0.0,"life":_rng.randf_range(.84,1.22),"size":Vector2(_rng.randf_range(7,14),_rng.randf_range(4,8)),"angle":_rng.randf_range(-PI,PI),"spin":_rng.randf_range(-5.5,5.5),"flutter":_rng.randf_range(0,TAU),"tone":_rng.randf_range(.70,.94)})
	while dust.size()>MAX_DUST: dust.pop_front()
	while papers.size()>MAX_PAPERS: papers.pop_front()
	queue_redraw()

func clear() -> void:
	bursts.clear()
	dust.clear()
	papers.clear()
	queue_redraw()

func _process(delta: float) -> void:
	if not is_instance_valid(world_ref):
		queue_free()
		return
	if not bool(world_ref.get("gameplay_active")): return
	if bursts.is_empty() and dust.is_empty() and papers.is_empty(): return
	for index in range(bursts.size()-1,-1,-1):
		bursts[index].age=float(bursts[index].age)+delta
		if float(bursts[index].age)>=float(bursts[index].life): bursts.remove_at(index)
	for index in range(dust.size()-1,-1,-1):
		var particle: Dictionary=dust[index]
		particle.age=float(particle.age)+delta
		if float(particle.age)>=float(particle.life):
			dust.remove_at(index)
			continue
		var velocity: Vector2=particle.velocity
		velocity.x*=exp(-1.8*delta)
		velocity.y+=360*delta
		var point: Vector2=(particle.point as Vector2)+velocity*delta
		if point.y>float(particle.floor):
			point.y=float(particle.floor)
			velocity.y=0
		point.x=clampf(point.x,arena_rect.position.x+3,arena_rect.end.x-3)
		particle.point=point
		particle.velocity=velocity
	for index in range(papers.size()-1,-1,-1):
		var paper: Dictionary=papers[index]
		paper.age=float(paper.age)+delta
		if float(paper.age)>=float(paper.life):
			papers.remove_at(index)
			continue
		var velocity: Vector2=paper.velocity
		velocity.x*=exp(-.95*delta)
		velocity.y+=390*delta
		var point: Vector2=(paper.point as Vector2)+velocity*delta
		if point.y>float(paper.floor):
			point.y=float(paper.floor)
			velocity*=Vector2(.72,-.16)
		point.x=clampf(point.x,arena_rect.position.x+8,arena_rect.end.x-8)
		paper.point=point
		paper.velocity=velocity
		paper.angle=float(paper.angle)+float(paper.spin)*delta
	queue_redraw()

func _draw() -> void:
	# This flattened contact response dies near the landing point. It never
	# becomes a third travelling wave or paints an incoming danger marker.
	for burst in bursts:
		var age:=float(burst.age)
		var life:=float(burst.life)
		var progress:=clampf(age/life,0,1)
		var fade:=pow(1-progress,1.8)
		var point: Vector2=burst.point
		var strength:=float(burst.strength)
		var radius: float=lerpf(22,166,1-pow(1-progress,3))*strength
		var ring:=PackedVector2Array()
		for index in range(57):
			var angle:=TAU*float(index)/56.0
			ring.append(point+Vector2(cos(angle)*radius,sin(angle)*(7+progress*4)-1))
		draw_polyline(ring,Color(.84,.70,.47,.68*fade),1.8,true)
		if age<.115:
			var contact_fade:=1-age/.115
			draw_line(point+Vector2(-45*strength,-2),point+Vector2(45*strength,-2),Color(.92,.78,.51,.68*contact_fade),2.4,true)
	for particle in dust:
		var progress:=float(particle.age)/float(particle.life)
		var fade:=pow(1-progress,1.4)
		var radius:=float(particle.radius)*(1+progress*1.35)
		var point: Vector2=particle.point
		var size_value:=Vector2(radius*3.2,radius*1.25)
		var tint:=Color(.75,.65,.50,.88*fade*float(particle.tone))
		draw_texture_rect(_dust_texture,Rect2(point-size_value*.5,size_value),false,tint)
	for paper in papers:
		var age:=float(paper.age)
		var fade:=clampf((float(paper.life)-age)/.32,0,1)
		var size_value: Vector2=paper.size
		var flutter:=sin(age*17+float(paper.flutter))
		var point: Vector2=(paper.point as Vector2)+Vector2(0,flutter*3)
		draw_set_transform(point,float(paper.angle),Vector2(1,.45+.55*absf(flutter)))
		var half:=size_value*.5
		var tint:=Color(.80,.73,.60,.76*fade*float(paper.tone))
		draw_colored_polygon(PackedVector2Array([Vector2(-half.x,-half.y),Vector2(half.x,-half.y*.65),half,Vector2(-half.x*.86,half.y*.70)]),tint)
		draw_line(Vector2(-half.x*.7,0),Vector2(half.x*.6,0),Color(.36,.31,.25,tint.a*.65),.75,true)
		draw_set_transform(Vector2.ZERO)
