extends SceneTree
const Character=preload("res://scripts/minibosses/m24_bell_character.gd")
var failures:Array[String]=[]
func check(ok:bool,message:String) -> void:
	if not ok:failures.append(message)
func _initialize() -> void:
	var model:=Character.new()
	model.breathing=false
	var checked:=0
	var max_upper:=0.0
	var max_lower:=0.0
	var max_plant:=0.0
	var max_world_slip:=0.0
	var lengths:Dictionary={}
	var names:=["idle","walk","run","rush","drawback","crouch","jump","fall","land","recover","hurt","death","phase_change","double_drawback","double_rush","turn_gap","high_crouch","high_jump","high_fall","slam_land","echo_wait"]
	for pose in names:
		for frame in 61:
			var p:=frame/60.0
			model.set_pose(pose,p)
			for facing in [-1,1]:
				model.facing=facing
				var rig:Dictionary=model.get_rig_snapshot()
				for id in rig:
					var leg:Dictionary=rig[id]
					var upper_error:=absf(leg.hip.distance_to(leg.knee)-leg.upper_length)
					var lower_error:=absf(leg.knee.distance_to(leg.ankle)-leg.lower_length)
					max_upper=maxf(max_upper,upper_error)
					max_lower=maxf(max_lower,lower_error)
					check(upper_error<.0001,pose+" upper bone length "+id)
					check(lower_error<.0001,pose+" lower bone length "+id)
					check(leg.hip.is_finite() and leg.knee.is_finite() and leg.ankle.is_finite(),pose+" finite joints "+id)
					if pose in ["idle","drawback","crouch","land","recover","hurt","death","phase_change","double_drawback","turn_gap","high_crouch","slam_land","echo_wait"]:
						var planted_error:=absf(leg.ankle.y-leg.rest_ankle.y)
						max_plant=maxf(max_plant,planted_error)
						check(planted_error<.0001,pose+" planted sole "+id)
					if pose in ["walk","run"]:
						var is_support:bool=(p<=.5) if id=="near_leg" else (p>=.5)
						if is_support:
							var planted_error:=absf(leg.ankle.y-leg.rest_ankle.y)
							max_plant=maxf(max_plant,planted_error)
							check(planted_error<.0001,pose+" support sole "+id)
							var travel:=11.7 if pose=="walk" else 17.0
							var world_x:float=leg.ankle.x-2*travel*p
							var reference_x:float=leg.rest_ankle.x-(2*travel if id=="far_leg" else 0.0)
							var slip:=absf(world_x-reference_x)
							max_world_slip=maxf(max_world_slip,slip)
							check(slip<.0001,pose+" world support foot anchor "+id)
				checked+=1
	model.set_pose("idle",0)
	var idle:Dictionary=model.get_rig_snapshot()
	for id in idle:lengths[id]={"upper":idle[id].upper_length,"lower":idle[id].lower_length}
	for id in idle:
		var leg:Dictionary=idle[id]
		check(leg.hip.distance_to(leg.rest_hip)<.0001,"idle hip matches source "+id)
		check(leg.knee.distance_to(leg.rest_knee)<.0001,"idle knee matches source "+id)
		check(leg.ankle.distance_to(leg.rest_ankle)<.0001,"idle ankle matches source "+id)
	var report:Dictionary={"engine":Engine.get_version_info().string,"pose_samples":checked,"poses":names,"phases_per_pose":61,"facings":2,"max_upper_length_error_px":max_upper,"max_lower_length_error_px":max_lower,"max_planted_ankle_error_px":max_plant,"max_world_stance_slip_px":max_world_slip,"bone_lengths_world_px":lengths,"texture_scale_changes_per_pose":false,"result":"PASS" if failures.is_empty() else "FAIL","failures":failures}
	var file:=FileAccess.open("user://m25_character_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	model.free()
	quit(0 if failures.is_empty() else 1)
