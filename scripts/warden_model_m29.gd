extends "res://scripts/warden_model_m23.gd"
## The approved parts and limb lengths are unchanged. Resting is a joint pose,
## not a smaller sprite: the pelvis rests on the actual low bench cushion.
var bench_blend := 0.0
var bench_age := 0.0
var bench_seat_height := 28.0

func set_bench_pose(amount: float, age: float=0.0, seat_height: float=28.0) -> void:
	bench_blend=clampf(amount,0,1)
	bench_age=age
	bench_seat_height=clampf(seat_height,20,36)
	super.set_motion("idle",0.0)
	var near_angles: Array=_leg_angles.near.duplicate()
	var far_angles: Array=_leg_angles.far.duplicate()
	var b:=bench_blend
	motion_name="bench_rest"
	leg_running=false
	feet_planted=false
	sword_visible=false
	combat_kind=""
	combat_phase=0
	pose.hip_y=lerpf(394.0,FEET.y-bench_seat_height/DRAW_SCALE,b)-sin(b*PI)*5.5
	pose.lean=lerpf(0,-2.5,b)
	pose.head_tilt=sin(age*1.2)*.30*b
	pose.cape=lerpf(0,-6.0,b)+sin(age*1.35)*.5*b
	# Both knees turn gently outward. The short shins hang from the cushion,
	# as real legs do; the standing physics body remains supported by the floor.
	pose.legs=[lerpf(float(near_angles[0]),-79,b),lerpf(float(near_angles[1]),14,b),lerpf(float(far_angles[0]),79,b),lerpf(float(far_angles[1]),-14,b)]
	pose.arms=[lerpf(-12,20,b),lerpf(-4,-15,b),lerpf(30,-20,b),lerpf(18,15,b)]
	expression_name="idle"
	expression_blend=1
	var phase:=fposmod(age,4.6)
	eye_blink=sin(inverse_lerp(4.30,4.43,phase)*PI)*b if phase>=4.30 and phase<=4.43 else 0.0
	_update_geometry()
	queue_redraw()

func get_bench_pose_snapshot() -> Dictionary:
	return {"blend":bench_blend,"age":bench_age,"seat_height":bench_seat_height,"pelvis":joints.get("torso",[Vector2.ZERO,Vector2.ZERO])[1],"near_leg":joints.get("near_leg",[]),"far_leg":joints.get("far_leg",[]),"near_arm":joints.get("near_arm",[]),"far_arm":joints.get("far_arm",[]),"head_rect":HEAD_RECT,"atlas_path":ATLAS_PATH,"sword_visible":sword_visible,"strike_active":strike_active}
