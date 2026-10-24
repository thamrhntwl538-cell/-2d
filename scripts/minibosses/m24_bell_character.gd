extends Node2D
## Native reconstruction of the approved Bell silhouette from unchanged atlas pixels.
## Crops rotate rigidly about measured joints. No pose changes texture/bone scale.
const ATLAS=preload("res://assets/minibosses/m24/bell_character_parts.png")
const HEIGHT:=194.0
const HEAD_SCALE:=146.0/576.0
const LIMB_SCALE:=.235
const MASTER_SOURCE:=Rect2(97,25,598,826)
const MASTER_ORIGIN:=Vector2(414.5,851)
const MASTER_SCALE:=HEIGHT/826.0
const PARTS:={
	"head":{"source":Rect2(757,22,524,576),"origin":Vector2(1056,598),"scale":HEAD_SCALE,"offset":Vector2(0,-48)},
	"torso":{"source":Rect2(1400,289,247,274),"origin":Vector2(1510,563),"scale":LIMB_SCALE,"offset":Vector2(0,-23)},
	"near_leg":{"source":Rect2(868,614,244,228),"origin":Vector2(1156,842),"scale":LIMB_SCALE,"offset":Vector2(8,0)},
	"far_leg":{"source":Rect2(1392,586,301,265),"origin":Vector2(1365,851),"scale":LIMB_SCALE,"offset":Vector2(-10,0)}
}
const ORDER:=["far_leg","near_leg","torso","head"]
const SPREAD:={"head":Vector2(0,-40),"torso":Vector2(0,7),"near_leg":Vector2(-52,43),"far_leg":Vector2(52,43)}
# Joint landmarks in source-image coordinates. Broad texture pieces overlap at knees.
const JOINTS:={
	"near_leg":[Vector2(1080,653),Vector2(973,730),Vector2(966,802)],
	"far_leg":[Vector2(1442,628),Vector2(1546,735),Vector2(1602,810)]
}
const LEG_CROPS:={
	"near_leg":[Rect2(868,614,244,126),Rect2(868,719,244,94),Rect2(868,794,244,48)],
	"far_leg":[Rect2(1392,586,301,160),Rect2(1392,727,301,96),Rect2(1392,802,301,49)]
}
var facing:int=-1
var age:=0.0
var breathing:=true
var exploded:=false
var guides:=false
var use_master:=false
var pose_name:="idle"
var pose_progress:=0.0
var motion_velocity:=Vector2.ZERO
var _rig:Dictionary={}
var _body:=Vector2.ZERO
var _head_angle:=0.0
var _cloth_angle:=0.0

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var lit:=CanvasItemMaterial.new()
	lit.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material=lit

func _process(delta:float) -> void:
	if breathing:age+=delta
	queue_redraw()

func set_pose(name:String, progress:float=0.0, velocity:Vector2=Vector2.ZERO) -> void:
	pose_name=name
	pose_progress=clampf(progress,0,1)
	motion_velocity=velocity
	queue_redraw()

func source_point(id:String, point:Vector2) -> Vector2:
	var part:Dictionary=PARTS[id]
	return (point-part.origin)*part.scale+part.offset

func part_rect(id:String) -> Rect2:
	var part:Dictionary=PARTS[id]
	return Rect2(source_point(id,part.source.position),part.source.size*part.scale)

func get_part_bounds() -> Dictionary:
	var result:Dictionary={}
	for id in ORDER:result[id]=part_rect(id)
	return result

func get_character_bounds() -> Rect2:
	var bounds:Rect2=part_rect("head")
	for id in ORDER:bounds=bounds.merge(part_rect(id))
	return bounds

func _solve_leg(id:String, body:Vector2, foot_offset:Vector2) -> Dictionary:
	var points:Array=JOINTS[id]
	var hip_rest:=source_point(id,points[0])
	var knee_rest:=source_point(id,points[1])
	var ankle_rest:=source_point(id,points[2])
	var upper:=hip_rest.distance_to(knee_rest)
	var lower:=knee_rest.distance_to(ankle_rest)
	var hip:=hip_rest+body
	var target:=ankle_rest+foot_offset
	# Preserve the requested ankle height (and therefore the level sole).
	# A planted step may shorten its horizontal reach, never its bones.
	var maximum:=upper+lower-.001
	var vertical:=target.y-hip.y
	if absf(vertical)<maximum:
		var horizontal_limit:=sqrt(maxf(0,maximum*maximum-vertical*vertical))
		target.x=hip.x+clampf(target.x-hip.x,-horizontal_limit,horizontal_limit)
	var delta:=target-hip
	var distance:=clampf(delta.length(),absf(upper-lower)+.001,maximum)
	var axis:=delta.normalized()
	if axis==Vector2.ZERO:axis=Vector2.DOWN
	var ankle:=hip+axis*distance
	var along:=(upper*upper-lower*lower+distance*distance)/(2.0*distance)
	var high:=sqrt(maxf(0,upper*upper-along*along))
	var bend:=1.0 if (ankle_rest-hip_rest).cross(knee_rest-hip_rest)>0 else -1.0
	var knee:=hip+axis*along+Vector2(-axis.y,axis.x)*high*bend
	return {"hip":hip,"knee":knee,"ankle":ankle,"rest_hip":hip_rest,"rest_knee":knee_rest,"rest_ankle":ankle_rest,"upper_length":upper,"lower_length":lower,"upper_rotation":(knee-hip).angle()-(knee_rest-hip_rest).angle(),"lower_rotation":(ankle-knee).angle()-(ankle_rest-knee_rest).angle(),"requested_ankle":target}

func update_rig() -> void:
	var p:=pose_progress
	_body=Vector2.ZERO
	_head_angle=0.0
	_cloth_angle=0.0
	var near_foot:=Vector2.ZERO
	var far_foot:=Vector2.ZERO
	match pose_name:
		"idle":
			if breathing:_body.y=(sin(age*1.8)+1)*.225
		"walk","run":
			# One full walk cycle travels23.4px in.52s. During stance the
			# local sole drifts opposite root travel at exactly45px/s.
			var travel:=11.7 if pose_name=="walk" else 17.0
			var lift:=4.0 if pose_name=="walk" else 8.0
			if p<=.5:
				near_foot.x=travel*p*2
				var swing:=p*2
				far_foot=Vector2(-travel*smoothstep(0,1,swing),-sin(swing*PI)*lift)
			else:
				far_foot.x=-travel+travel*(p-.5)*2
				var swing:=(p-.5)*2
				near_foot=Vector2(travel*(1-smoothstep(0,1,swing)),-sin(swing*PI)*lift)
			_head_angle=-.025 if pose_name=="walk" else -.075
			_cloth_angle=sin(p*TAU)*.045
		"rush":
			# A fast rush is a short airborne bound. It has no false planted
			# contact sliding over the ground at attack speed.
			var bound:=sin(p*PI)
			_body=Vector2(-3*bound,0)
			near_foot=Vector2(4*bound,-8*bound)
			far_foot=Vector2(-6*bound,-8*bound)
			_head_angle=-.12*bound
			_cloth_angle=.07*bound
		"drawback":
			_body=Vector2(3*p,2*p)
			_head_angle=.095*p
		"crouch":
			_body.y=9.0*sin(p*PI*.5)
			_head_angle=-.045*p
			_cloth_angle=.025*p
		"jump":
			_body.y=-2
			near_foot=Vector2(3,-10)
			far_foot=Vector2(-5,-12)
			_head_angle=-.07
			_cloth_angle=.08
		"fall":
			near_foot=Vector2(-2,-4)
			far_foot=Vector2(3,-5)
			_head_angle=.045
			_cloth_angle=-.055
		"land":
			_body.y=8*pow(1-p,2)
			_head_angle=-.04*(1-p)
		"recover":
			_body.y=2*(1-p)
			_head_angle=.025*sin(p*PI)
		"hurt":
			_body=Vector2(3*(1-p),1)
			_head_angle=.12*(1-p)
		"death":
			_body=Vector2(8*p,22*p)
			_head_angle=.52*p
			_cloth_angle=-.18*p
	_rig={"near_leg":_solve_leg("near_leg",_body,near_foot),"far_leg":_solve_leg("far_leg",_body,far_foot)}

func get_rig_snapshot() -> Dictionary:
	update_rig()
	return _rig.duplicate(true)

func _transform(pivot:Vector2, angle:float=0.0) -> void:
	var flip:=1.0 if facing<0 else -1.0
	draw_set_transform(pivot*Vector2(flip,1),angle*flip,Vector2(flip,1))

func _draw_part(id:String, pivot:Vector2, translation:Vector2, angle:float) -> void:
	_transform(pivot+translation,angle)
	var rect:=part_rect(id)
	rect.position-=pivot
	draw_texture_rect_region(ATLAS,rect,PARTS[id].source)

func _draw_leg(id:String) -> void:
	var rig:Dictionary=_rig[id]
	var crops:Array=LEG_CROPS[id]
	# Round dark overlap remains behind both broad, rigid textured pieces.
	_transform(Vector2.ZERO)
	draw_circle(rig.knee,4.0,Color("101116"))
	for index in 3:
		var pivot:Vector2=rig.hip if index==0 else (rig.knee if index==1 else rig.ankle)
		var rest:Vector2=rig.rest_hip if index==0 else (rig.rest_knee if index==1 else rig.rest_ankle)
		var angle:float=rig.upper_rotation if index==0 else (rig.lower_rotation if index==1 else 0.0)
		_transform(pivot,angle)
		var crop:Rect2=crops[index]
		draw_texture_rect_region(ATLAS,Rect2(source_point(id,crop.position)-rest,crop.size*LIMB_SCALE),crop)
	if guides:
		_transform(Vector2.ZERO)
		draw_polyline(PackedVector2Array([rig.hip,rig.knee,rig.ankle]),Color("e8b97b"),.7,true)
		for point in [rig.hip,rig.knee,rig.ankle]:draw_circle(point,1.5,Color("e8b97b"))

func _draw() -> void:
	if use_master:
		_transform(Vector2.ZERO)
		draw_texture_rect_region(ATLAS,Rect2((MASTER_SOURCE.position-MASTER_ORIGIN)*MASTER_SCALE,MASTER_SOURCE.size*MASTER_SCALE),MASTER_SOURCE)
	elif exploded:
		for id in ORDER:
			_draw_part(id,Vector2.ZERO,SPREAD[id],0)
			if guides:
				_transform(SPREAD[id])
				draw_rect(part_rect(id),Color(.7,.77,.84,.4),false,.6)
	else:
		update_rig()
		_draw_leg("far_leg")
		_draw_leg("near_leg")
		_draw_part("torso",Vector2(0,-63),_body,_cloth_angle)
		_draw_part("head",Vector2(0,-62),_body,_head_angle)
	draw_set_transform(Vector2.ZERO)
