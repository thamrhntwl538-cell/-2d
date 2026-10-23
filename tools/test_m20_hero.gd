extends "res://tools/test_m18_combat.gd"
## M20 hero-specific QA. Reuses native input-driving/save-backup helpers.
## A shared physical timeline is checked against rendered fire geometry and input behavior.
## Geometry/pose fixtures are declared separately from the uninterrupted opening.
const M20_WORLD_PATH := "res://scenes/stage_01/folding_library_m20.tscn"
const M20_REPORT := "user://m20_hero_report.json"
const M20_ATLAS := "res://assets/warden_m20/warden_parts.png"
var model_samples: Array[Dictionary] = []
var pose_samples: Array[Dictionary] = []
var archive_jumps: int = 0
var opening_jumps: int = 0
var pose_assertions: int = 0
var movement_samples: Array[Dictionary] = []
var expression_samples: Array[Dictionary] = []
var strike_samples: Array[Dictionary] = []
var expression_assertions: int = 0
var arc_assertions: int = 0

func check(value: bool, message: String) -> bool:
	checks += 1
	if not value:
		var labelled: String = phase+": "+message
		if not failures.has(labelled): failures.append(labelled)
		print("M20 QA FAIL ",labelled)
	return value

func pose_geometry_checks() -> void:
	phase = "shared model pose and rigid proportions"
	var starting_checks: int = checks
	var rig: Node2D = load("res://scripts/warden_model_m20.gd").new()
	rig.visible = false
	root.add_child(rig)
	await process_frame
	var jobs: Array = []
	for motion in ["idle","run","dash","air","land","stop","heal"]:
		for index in range(9): jobs.append({"motion":motion,"sample":float(index)/8.0*(6.0 if motion in ["run","dash"] else 7.0 if motion=="air" else 1.0)})
	for motion in ["slash","slash_up","slash_down","recoil","death"]:
		for index in range(9): jobs.append({"motion":motion,"sample":float(index)/8.0})
	var head: AtlasTexture = rig.textures.get("head")
	var head_identity: int = head.get_instance_id()
	for job in jobs:
		if job.motion in ["slash","slash_up","slash_down","recoil","death"]:
			rig.set_combat_pose(job.motion,job.sample,false,0)
		else:
			rig.set_motion(job.motion,job.sample)
		check(rig.textures.head.get_instance_id()==head_identity,"head source is identical through "+job.motion)
		check((rig.joints.lantern[1] as Vector2).is_equal_approx(Vector2(90,108)),"solid head dimensions are constant through "+job.motion)
		check(absf(rig.joints.torso[0].distance_to(rig.joints.torso[1])-60.0)<0.001,"torso remains rigid through "+job.motion)
		for side in ["near","far"]:
			var arm: Array = rig.joints[side+"_arm"]
			var leg: Array = rig.joints[side+"_leg"]
			check(absf(arm[0].distance_to(arm[1])-30.0)<0.001 and absf(arm[1].distance_to(arm[2])-26.0)<0.001,"arm segment lengths remain fixed through "+job.motion)
			check(absf(leg[0].distance_to(leg[1])-32.0)<0.001 and absf(leg[1].distance_to(leg[2])-24.0)<0.001 and absf(leg[2].distance_to(leg[3])-8.0)<0.001,"leg segment lengths remain fixed through "+job.motion)
			if bool(rig.contacts.get(side,false)):
				check(absf(leg[3].y-456.0)<0.05,"contact sole stays on its ground baseline through "+job.motion)
		check(rig.lantern_center.is_finite() and rig.sword_start.is_finite() and rig.sword_end.is_finite(),"rig anchors are finite through "+job.motion)
		pose_samples.append({"motion":job.motion,"sample":job.sample,"head_size":[rig.joints.lantern[1].x,rig.joints.lantern[1].y],"head_center":[rig.lantern_center.x,rig.lantern_center.y],"near_sole":[rig.joints.near_leg[3].x,rig.joints.near_leg[3].y],"far_sole":[rig.joints.far_leg[3].x,rig.joints.far_leg[3].y]})
	rig.set_motion("run",0.12)
	var a: Vector2 = rig.joints.near_leg[3]
	rig.set_motion("run",0.18)
	var b: Vector2 = rig.joints.near_leg[3]
	var world_slide: Vector2 = (b-a)*0.37+Vector2(300.0*(0.01*6.0/13.0),0)
	check(world_slide.length()<0.1,"support foot cancels forward travel during the running stance")
	rig.queue_free()
	await process_frame
	pose_assertions = checks-starting_checks

func moving_attack_and_landing_gait_checks() -> void:
	phase = "moving slash and moving landing preserve running feet"
	await fixture_room(1,Vector2(1250,1260))
	reset_hero(Vector2(1250,1260))
	await step(5)
	Input.action_press("move_right")
	await step(12)
	Input.action_press("attack")
	await step(3)
	Input.action_release("attack")
	var near_a: Vector2 = hero.combat_model.joints.near_leg[3]
	var far_a: Vector2 = hero.combat_model.joints.far_leg[3]
	var start_x: float = hero.position.x
	await step(5)
	var near_b: Vector2 = hero.combat_model.joints.near_leg[3]
	var far_b: Vector2 = hero.combat_model.joints.far_leg[3]
	check(hero.attack_time>0 and hero.velocity.x>250,"grounded moving slash preserves travel and its active attack")
	check(near_a.distance_to(near_b)>6 or far_a.distance_to(far_b)>6,"moving slash advances its lower-body gait instead of planting both feet")
	sample("moving_slash_gait",{"actual_input":true,"travel":hero.position.x-start_x,"near_sole_change":near_a.distance_to(near_b),"far_sole_change":far_a.distance_to(far_b)})
	await step(30)
	Input.action_press("jump")
	var airborne := false
	var landed := false
	for tick in range(90):
		await step(1)
		if tick==29: Input.action_release("jump")
		if not hero.is_on_floor(): airborne = true
		if airborne and hero.is_on_floor():
			landed = true
			break
	Input.action_release("jump")
	check(landed and hero.velocity.x>250,"held moving jump lands while its run input remains active")
	await step(1)
	check(str(hero.current_pose).ends_with("_run"),"moving landing selects running feet immediately")
	Input.action_release("move_right")
	await step(8)
	check(absf(hero.velocity.x)<10,"moving landing can still brake promptly")

func runtime_expression_checks() -> void:
	phase = "native look inputs and nearby-enemy alert"
	await fixture_room(1,Vector2(1250,1260))
	reset_hero(Vector2(1250,1260))
	await step(20)
	check(hero.expression_kind=="idle","neutral exploration settles to the idle expression")
	Input.action_press("look_up")
	await step(24)
	check(hero.expression_kind=="look_up" and hero.combat_model.expression_name=="look_up" and hero.combat_model.expression_tilt<0,"held look-up input inclines the shared head upward")
	Input.action_release("look_up")
	Input.action_press("look_down")
	await step(24)
	check(hero.expression_kind=="look_down" and hero.combat_model.expression_tilt>0,"held look-down input inclines the shared head downward")
	Input.action_release("look_down")
	await step(24)
	check(hero.expression_kind=="idle","releasing look input returns to the original neutral head")
	var enemy: Node2D = await fixture_enemy()
	if not is_instance_valid(enemy): return
	reset_hero(Vector2(1250,1260))
	freeze_enemy(enemy,Vector2(1450,1260))
	await step(25)
	check(hero.expression_kind=="alert" and hero.combat_model.flame_intensity>1,"nearby living enemy triggers the native alert flame")
	enemy.position.x = 2200.0
	await step(45)
	check(hero.expression_kind=="idle","alert releases after enemy leaves and its linger elapses")
	sample("native_expression_inputs",{"actual_input":true,"look_up":true,"look_down":true,"alert_fixture":"living enemy positioned at200px then removed to950px; no attack state injected"})

func airborne_dash_and_variant_checks() -> void:
	phase = "air dash token and manual forward alternation"
	await fixture_room(1,Vector2(1250,650))
	reset_hero(Vector2(1250,650))
	await step(3)
	await pulse("dash",1)
	check(hero.air_dash_used,"airborne dash consumes its single air token")
	await step(33)
	check(not hero.is_on_floor() and hero.dash_cooldown<=0,"second-dash check waits for cooldown while remaining airborne")
	await pulse("dash",1)
	check(hero.dash_time<=0 and hero.air_dash_used,"cooldown expiry does not grant a second airborne dash")
	await step(100)
	check(hero.is_on_floor() and not hero.air_dash_used,"landing restores the air dash token")
	reset_hero(Vector2(1250,1260))
	await step(5)
	var serial: int = hero.strike_serial
	Input.action_press("attack")
	await step(45)
	var first_variant: int = hero.attack_variant
	Input.action_release("attack")
	await step(3)
	check(hero.strike_serial==serial+1,"holding attack does not invent an automatic combo")
	await pulse("attack",1)
	var second_variant: int = hero.attack_variant
	check(second_variant!=first_variant,"a second manual forward press uses the alternate authored swing")
	await step(40)
	await pulse("attack",1)
	check(hero.attack_variant==first_variant,"manual forward swings alternate consistently")
	await step(45)
	reset_hero(Vector2(1250,1260))
	await step(5)
	await pulse("dash",1)
	hero.invulnerable = 0.0
	var before_hp: int = hero.hp
	hero.hurt(1,hero.position.x+100)
	check(hero.hp==before_hp-1,"basic dash grants no damage immunity")
	await step(80)

func reset_hero(at: Vector2) -> void:
	super.reset_hero(at)
	hero.reset_combat_motion()
	hero.jump_buffer = 0.0
	hero.land_timer = 0.0
	hero.stop_timer = 0.0

func live_strike_region_checks() -> void:
	phase = "native directional fire arc equals the live hit region"
	await fixture_room(1,Vector2(1250,1260))
	for look in [1,-1]:
		for direction in ["attack","up","down"]:
			reset_hero(Vector2(1250,1165 if direction=="down" else 1260))
			hero.facing = look
			await step(3)
			var contact_frames := 0
			var outside_window_empty := true
			var geometry_matches := true
			var serial: int = hero.strike_serial
			await physics_frame
			if direction=="up": Input.action_press("look_up")
			elif direction=="down": Input.action_press("look_down")
			Input.action_press("attack")
			for tick in range(28):
				await step(1)
				if tick==0: Input.action_release("attack")
				var actual: Rect2 = hero.strike_rect(direction,look)
				if hero.active_strike_time>0:
					contact_frames += 1
					var source: Rect2 = hero.combat_model.get_strike_rect()
					var a: Vector2 = hero.combat_model.to_global(source.position)
					var b: Vector2 = hero.combat_model.to_global(source.end)
					var expected := Rect2(a,b-a).abs()
					if not actual.position.is_equal_approx(expected.position) or not actual.size.is_equal_approx(expected.size): geometry_matches = false
				else:
					if actual.has_area(): outside_window_empty = false
			Input.action_release("look_up")
			Input.action_release("look_down")
			check(hero.strike_serial==serial+1,"one directional input begins exactly one strike")
			check(contact_frames>=3 and contact_frames<=6,"native strike has a short readable contact window")
			check(outside_window_empty,"native attack cannot damage during anticipation or visual tail")
			check(geometry_matches,"live hit region equals the transformed filled fire arc in both facings")
			sample("native_strike_region",{"direction":direction,"facing":look,"contact_frames":contact_frames,"outside_window_empty":outside_window_empty,"geometry_matches":geometry_matches,"actual_input":true})
			await step(70)

func expression_and_hand_checks() -> void:
	phase = "four expressions and two exposed resting hands"
	var starting_checks: int = checks
	var rig: Node2D = load("res://scripts/warden_model_m20.gd").new()
	rig.visible = false
	root.add_child(rig)
	await process_frame
	var signatures: Array[Vector2] = []
	for expression in ["idle","look_up","look_down","alert"]:
		rig.set_motion("idle",0.25)
		rig.set_expression(expression,1.0)
		check(rig.expression_name==expression,"expression selector preserves "+expression)
		check((rig.joints.lantern[1] as Vector2).is_equal_approx(Vector2(90,108)),"expression preserves the solid cage dimensions")
		var signature := Vector2(rig.expression_tilt,rig.flame_intensity)
		check(not signatures.has(signature),"expression changes a visible head/core parameter distinctly")
		signatures.append(signature)
		var far_hand: Vector2 = rig.joints.far_hand
		var near_hand: Vector2 = rig.joints.near_hand
		var shoulder: Vector2 = rig.joints.torso[0]
		check(far_hand.x<shoulder.x-25.0,"far pale hand rests outside the torso silhouette")
		check(near_hand.distance_to(far_hand)>35.0,"resting palms have distinct separated locations")
		expression_samples.append({"expression":expression,"tilt":rig.expression_tilt,"flame_intensity":rig.flame_intensity,"far_hand":[far_hand.x,far_hand.y],"near_hand":[near_hand.x,near_hand.y],"head_size":[rig.joints.lantern[1].x,rig.joints.lantern[1].y]})
	check(signatures[1].x<signatures[0].x and signatures[2].x>signatures[0].x,"look up and down incline the same cage in opposite directions")
	check(signatures[3].y>signatures[0].y,"alert brightens the original flame")
	rig.queue_free()
	await process_frame
	expression_assertions = checks-starting_checks

func static_fire_arc_checks() -> void:
	phase = "filled fire arc and nonlethal anticipation tail"
	var starting_checks: int = checks
	var rig: Node2D = load("res://scripts/warden_model_m20.gd").new()
	rig.visible = false
	root.add_child(rig)
	await process_frame
	for direction in ["slash","slash_up","slash_down"]:
		for variant in range(2 if direction=="slash" else 1):
			for timeline in [0.0,0.16,0.20,0.32,0.46,0.52,0.70,1.0]:
				rig.attack_variant = variant
				rig.set_combat_pose(direction,timeline,direction=="slash_down",0)
				var rectangle: Rect2 = rig.get_strike_rect()
				var expected: bool = timeline>=0.20 and timeline<=0.14/0.30
				check(rig.strike_active==expected,"fire contact follows its authored interval")
				check(rectangle.has_area()==expected,"anticipation and visual tail have no damaging rectangle")
				if expected:
					check(rig.arc_polygon.size()>20 and rig.strike_polygon.size()>20,"active slash uses a filled curved silhouette")
					check(minf(rectangle.size.x,rectangle.size.y)>100.0,"fire strike has meaningful thickness in both axes")
					var contained := true
					for point in rig.strike_polygon:
						if not rectangle.grow(0.001).has_point(point): contained = false
					check(contained,"source hit rectangle contains its filled damaging arc")
				elif timeline==0.52:
					check(not rig.arc_polygon.is_empty(),"recovery retains a visual-only fire tail")
				strike_samples.append({"kind":direction,"variant":variant,"phase":timeline,"active":rig.strike_active,"source_rect":[rectangle.position.x,rectangle.position.y,rectangle.size.x,rectangle.size.y],"polygon_points":rig.strike_polygon.size(),"visual_points":rig.arc_polygon.size()})
	rig.queue_free()
	await process_frame
	arc_assertions = checks-starting_checks

func action_combination_checks() -> void:
	phase = "slash jump dash boundaries by actual input"
	await fixture_room(1,Vector2(1250,1260))
	reset_hero(Vector2(1250,1260))
	await step(4)
	Input.action_press("jump")
	Input.action_press("attack")
	await step(5)
	check(not hero.is_on_floor() and hero.attack_time>0,"jump and slash begin together without erasing the attack")
	check(str(hero.current_pose)=="slash","aerial forward strike keeps its slash pose")
	Input.action_release("attack")
	Input.action_release("jump")
	await step(80)
	reset_hero(Vector2(1250,1260))
	await step(5)
	await physics_frame
	Input.action_press("attack")
	await step(1)
	Input.action_release("attack")
	Input.action_press("dash")
	var contact_seen := false
	var dashed := false
	var dash_before_contact := false
	var contact_elapsed: Array[float] = []
	for tick in range(32):
		await step(1)
		if tick==0: Input.action_release("dash")
		if hero.active_strike_time>0:
			contact_seen = true
			contact_elapsed.append(0.30-float(hero.attack_time))
		if hero.dash_time>0:
			dashed = true
			if not contact_seen: dash_before_contact = true
	check(contact_seen,"early dash request preserves the slash contact window")
	check(dashed and not dash_before_contact,"early dash waits through contact before recovery cancellation")
	for elapsed in contact_elapsed:
		check(elapsed>=0.04 and elapsed<=0.16,"native slash contact lies within the authored .06–.14 window to one physics tick")
	sample("attack_then_dash",{"actual_input":true,"contact_seen":contact_seen,"dash_seen":dashed,"dash_before_contact":dash_before_contact,"contact_elapsed":contact_elapsed})
	await step(55)
	reset_hero(Vector2(1250,1260))
	await step(5)
	await physics_frame
	Input.action_press("dash")
	await step(2)
	Input.action_release("dash")
	var serial: int = hero.strike_serial
	Input.action_press("attack")
	await step(1)
	Input.action_release("attack")
	var queued_attack := false
	var attacked_during_dash := false
	var exit_speed := 0.0
	var previous_dash: float = hero.dash_time
	for tick in range(35):
		await step(1)
		if previous_dash>0 and hero.dash_time<=0: exit_speed = absf(hero.velocity.x)
		if hero.strike_serial>serial:
			queued_attack = true
			if hero.dash_time>0: attacked_during_dash = true
		previous_dash = hero.dash_time
	check(queued_attack and not attacked_during_dash,"attack during dash queues to the dash exit")
	check(exit_speed<=301.0,"dash exit clamps velocity to ordinary movement speed")
	sample("dash_then_attack",{"actual_input":true,"queued_attack":queued_attack,"attacked_during_dash":attacked_during_dash,"exit_horizontal_speed":exit_speed})
	await step(55)
	reset_hero(Vector2(1250,1260))
	await step(5)
	await physics_frame
	Input.action_press("dash")
	await step(2)
	Input.action_release("dash")
	Input.action_press("jump")
	await step(3)
	check(not hero.is_on_floor() and hero.velocity.y<0 and hero.dash_time<=0,"grounded jump exits dash and preserves an upward launch")
	Input.action_release("jump")
	await step(90)
	check(hero.is_on_floor(),"dash-cancel jump returns to the original floor")

func responsiveness_checks() -> void:
	phase = "run turn braking and airborne steering"
	await fixture_room(1,Vector2(1250,1260))
	reset_hero(Vector2(1250,1260))
	await step(5)
	Input.action_press("move_right")
	await step(4)
	var start_speed: float = hero.velocity.x
	check(start_speed>=280.0,"ground movement reaches normal speed within four physics frames")
	await step(15)
	Input.action_release("move_right")
	Input.action_press("move_left")
	await step(4)
	var turn_speed: float = hero.velocity.x
	check(hero.facing==-1 and turn_speed< -250.0,"a grounded reverse request turns and changes travel promptly")
	Input.action_release("move_left")
	await step(4)
	var stopped_speed: float = hero.velocity.x
	check(absf(stopped_speed)<10.0,"ground release settles without a long slide")
	Input.action_press("jump")
	Input.action_press("move_right")
	await step(9)
	var air_right: float = hero.velocity.x
	Input.action_release("move_right")
	Input.action_press("move_left")
	await step(7)
	var air_left: float = hero.velocity.x
	check(not hero.is_on_floor() and air_right>200.0 and air_left< -200.0,"airborne steering can reverse travel while preserving the jump")
	Input.action_release("jump")
	Input.action_release("move_left")
	await step(90)
	check(hero.is_on_floor(),"steered jump returns to the original floor")
	var result := {"actual_input":true,"ground_start_after_4_frames":start_speed,"turn_after_4_frames":turn_speed,"released_after_4_frames":stopped_speed,"air_right_after_9_frames":air_right,"air_left_after_7_frames":air_left}
	movement_samples.append(result)
	sample("responsiveness_profile",result.duplicate(true))

func jump_profile(held_frames: int) -> Dictionary:
	reset_hero(Vector2(1250,1260))
	await step(5)
	var start: Vector2 = hero.position
	var highest: float = start.y
	var airborne := false
	var landed := false
	var elapsed_frames := 0
	await physics_frame
	Input.action_press("jump")
	for tick in range(150):
		await step(1)
		elapsed_frames += 1
		highest = minf(highest,hero.position.y)
		if tick+1>=held_frames: Input.action_release("jump")
		if not hero.is_on_floor(): airborne = true
		if airborne and hero.is_on_floor():
			landed = true
			break
	Input.action_release("jump")
	var result := {"actual_input":true,"held_frames":held_frames,"apex_height":start.y-highest,"airborne_frames":elapsed_frames,"landed":landed,"landing":[hero.position.x,hero.position.y]}
	movement_samples.append(result)
	sample("variable_jump_profile",result.duplicate(true))
	return result

func variable_jump_checks() -> void:
	phase = "tap versus held jump by actual input"
	await fixture_room(1,Vector2(1250,1260))
	var short: Dictionary = await jump_profile(2)
	var held: Dictionary = await jump_profile(30)
	check(bool(short.landed) and bool(held.landed),"tap and held jumps both return to the original floor")
	check(float(held.apex_height)>float(short.apex_height)*1.4,"holding jump produces a meaningfully higher apex than a short tap")
	check(float(held.apex_height)>122.0,"held jump retains clearance for existing 120-pixel route steps")
	check(int(held.airborne_frames)>int(short.airborne_frames),"released jump returns sooner than held jump")

func jump_to(point: Vector2) -> bool:
	# Full route jumps hold the input through ascent. Tap height is tested separately.
	var start: Vector2 = hero.position
	var airborne := false
	var landed := false
	await physics_frame
	Input.action_press("jump")
	for tick in range(140):
		drive_toward(point.x)
		await step(1)
		if airborne and hero.velocity.y>=0: Input.action_release("jump")
		if not hero.is_on_floor(): airborne = true
		if airborne and hero.is_on_floor():
			landed = true
			break
	Input.action_release("jump")
	var passed: bool = airborne and landed and absf(hero.position.y-point.y)<3.0
	if passed: route_jumps += 1
	sample("continuous_route_jump",{"start":[start.x,start.y],"target":[point.x,point.y],"landing":[hero.position.x,hero.position.y],"actual_input":true,"jump_hold":"through ascent","passed":passed})
	if not check(passed,"actual held jump reaches "+str(point)): return false
	return await walk_to(point)

func archive_clearance_checks() -> void:
	phase = "configured archive start with eighteen real jump inputs"
	await fixture_room(6,Vector2(180,2700))
	var before: int = route_jumps
	for action in world.data.qa_actions.main:
		if action.type=="walk":
			if not await walk_to(action.target): return
		elif action.type=="jump":
			if not await jump_to(action.target): return
	archive_jumps = route_jumps-before
	check(archive_jumps==18 and absf(hero.position.y-540.0)<3,"new solid lantern clears all eighteen archive ascent jumps")
	sample("configured_archive_ascent",{"actual_input":true,"jumps":archive_jumps,"final_position":[hero.position.x,hero.position.y],"configured_start_only":true})

func make_world(restore: bool = false) -> bool:
	release_controls()
	if is_instance_valid(world):
		stop_audio(world)
		OS.delay_msec(120)
		await process_frame
		world.queue_free()
		world = null
		await process_frame
		await process_frame
	var packed: PackedScene = load(M20_WORLD_PATH)
	if not check(packed != null,"M20 campaign scene loads"): return false
	world = packed.instantiate()
	packed = null
	world.restore_saved_game = restore
	world.environment_preview = true
	world.transition_seconds = 0.001
	root.add_child(world)
	await step(45)
	hero = world.hero
	return check(is_instance_valid(hero) and hero.is_on_floor(),"M20 initial actor is physically supported")

func check_live_identity(label: String) -> void:
	check(hero.combat_container.visible and not hero.lantern_sprite.visible,label+": only the new M20 rig is visible")
	check(hero.combat_model.get_script().resource_path=="res://scripts/warden_model_m20.gd",label+": all states use the M20 model")
	check(hero.combat_container.scale.is_equal_approx(Vector2(0.37*hero.facing,0.37)),label+": source-to-world size is stable")
	var head: AtlasTexture = hero.combat_model.textures.get("head")
	check(head != null and head.atlas.resource_path==M20_ATLAS,label+": head uses the new original shared atlas")
	var color: Color = hero.lantern_light.color
	check(color.r>color.g and color.g>color.b,label+": lantern illumination remains warm amber")
	var boxes: Array[Rect2] = hero.get_hurtboxes()
	check(boxes.size()==2,label+": body and solid lantern have explicit hurt regions")
	if boxes.size()==2:
		check(boxes[0].size.is_equal_approx(Vector2(24,52)) and boxes[1].size.is_equal_approx(Vector2(36,40)),label+": hurt region sizes do not change with the pose")
		check(boxes[1].grow(7).has_point(hero.lantern_light.global_position),label+": flame illumination follows the visible lantern")
	model_samples.append({"state":label,"pose":hero.current_pose,"facing":hero.facing,"head_light":[hero.lantern_light.position.x,hero.lantern_light.position.y],"head_region":[head.region.position.x,head.region.position.y,head.region.size.x,head.region.size.y] if head != null else [],"hurtboxes":boxes.map(func(rect:Rect2):return [rect.position.x-hero.position.x,rect.position.y-hero.position.y,rect.size.x,rect.size.y])})

func live_motion_checks() -> void:
	phase = "new hero movement and action identity"
	await fixture_room(1,Vector2(1250,1260))
	reset_hero(Vector2(1250,1260))
	await step(5)
	check_live_identity("idle")
	Input.action_press("move_right")
	await step(22)
	check(absf(hero.velocity.x-300.0)<2.0,"unchanged ordinary running reaches300pixels per second")
	check_live_identity("run right")
	Input.action_release("move_right")
	await step(15)
	Input.action_press("move_left")
	await step(22)
	check(hero.facing==-1,"left running mirrors the same new hero")
	check_live_identity("run left")
	Input.action_release("move_left")
	await step(22)
	await physics_frame
	Input.action_press("jump")
	Input.action_press("attack")
	await step(5)
	Input.action_release("jump")
	Input.action_release("attack")
	check(not hero.is_on_floor() and hero.attack_time>0,"jump preserves a running directional strike")
	check_live_identity("aerial slash")
	await step(11)
	check_live_identity("aerial travel")
	await step(75)
	check(hero.is_on_floor(),"new proportions land on the same floor")
	await pulse("dash",1)
	check(hero.dash_time>0,"dash remains available after the unchanged landing")
	check_live_identity("dash")
	await step(45)
	hero.invulnerable = 0
	hero.hurt(1,hero.position.x+100)
	await step(2)
	check_live_identity("recoil")
	hero.has_blade = false
	hero.invulnerable = 0
	hero.hurt(1,hero.position.x+100)
	await step(2)
	check_live_identity("unarmed recoil")
	check(not hero.combat_model.sword_visible,"unarmed recoil never invents a sword")
	await step(80)
	hero.hp = 4
	hero.energy = 99
	Input.action_press("heal")
	await step(18)
	check(hero.healing,"shared-energy focus still channels")
	check_live_identity("focus")
	Input.action_release("heal")
	await step(3)
	hero.hp = 0
	hero._update_animation()
	await step(3)
	check_live_identity("death presentation fixture")
	hero.hp = 6
	hero._update_animation()
	await step(5)

func real_death_during_slash_check() -> void:
	phase = "native damage death interrupts an active slash"
	await fixture_room(1,Vector2(1250,1260))
	reset_hero(Vector2(1250,1260))
	await step(5)
	hero.hp = 1
	Input.action_press("attack")
	await step(6)
	Input.action_release("attack")
	check(hero.attack_time>0,"death fixture begins during a real active slash")
	hero.invulnerable = 0.0
	hero.hurt(1,hero.position.x+100)
	await step(8)
	check(hero.hp==0 and not world.gameplay_active,"native lethal hurt enters the genuine death pause")
	check(hero.current_pose=="death" and hero.combat_model.combat_kind=="death","real death displays the new native death pose")
	check(hero.death_visual_time>0 and hero.combat_model.combat_phase>0,"death presentation continues while gameplay is paused")
	check(not hero.combat_model.sword_visible and hero.active_strike_time<=0,"lethal damage removes both sword contact and visible attack")
	check_live_identity("native death pause")
	sample("native_lethal_hurt",{"actual_hurt_method":true,"during_slash":true,"death_phase":hero.combat_model.combat_phase,"gameplay_paused":not world.gameplay_active,"sword_hidden":not hero.combat_model.sword_visible})
	await step(35)
	hero = world.hero
	check(hero.hp==6 and world.gameplay_active and hero.is_on_floor(),"native death resumes at the saved bench with restored health")

func head_and_body_damage_checks() -> void:
	phase = "body and solid-lantern danger coverage"
	await fixture_room(1,Vector2(1250,1260))
	reset_hero(Vector2(1250,1260))
	await step(5)
	var saved_hazards: Array = world.data.get("hazards",[]).duplicate(true)
	var head: Rect2 = hero.get_hurtboxes()[1]
	var head_only := Rect2(head.get_center()-Vector2(3,3),Vector2(6,6))
	check(not hero.get_hurtboxes()[0].intersects(head_only),"configured head hazard is outside the body region")
	world.elapsed = 2.0
	world.data.hazards = [{"rect":head_only,"period":20.0,"telegraph":0.0,"active":10.0}]
	await step(2)
	check(hero.hp==5,"native world hazard tests the enlarged solid lantern head")
	world.data.hazards = saved_hazards
	hero.position = Vector2(1250,1260)
	hero.velocity = Vector2.ZERO
	hero.hp = 6
	hero.invulnerable = 0.0
	hero.hurt_time = 0.0
	await step(4)
	var hook_only := Rect2(hero.position+Vector2(1,-99),Vector2(4,4))
	check(not hero.get_hurtboxes()[0].intersects(hook_only) and not hero.get_hurtboxes()[1].intersects(hook_only),"decorative hook is explicitly outside damage regions")
	world.elapsed = 2.0
	world.data.hazards = [{"rect":hook_only,"period":20.0,"telegraph":0.0,"active":10.0}]
	await step(3)
	check(hero.hp==6,"cosmetic hook-only overlap does not inflict damage")
	world.data.hazards = saved_hazards
	sample("configured_head_damage_fixture",{"native_hazard":true,"head_only_hurt":true,"hook_cosmetic":true})

func m20_persistence_check() -> void:
	phase = "M18 save compatibility with M20 presentation"
	await fixture_room(1,Vector2(330,1260))
	world.combat_state.acquire("wick")
	world.combat_state.equip("wick",true)
	world.combat_state.wallet = 17
	world.progress.ink_route_solved = true
	world._save()
	check("m18" in world.save_path(),"visual upgrade retains the established M18 save location")
	if not await make_world(true): return
	check(world.progress.weapon_owned and world.progress.ink_route_solved,"saved weapon and puzzle facts survive the new hero")
	check(world.combat_state.wallet==17 and world.combat_state.has_fitil("wick"),"wallet and equipped fitils remain compatible")
	check_live_identity("restored M18-compatible save")

func run_checks() -> void:
	remember_user_files()
	phase = "Godot version and fresh M20 boot"
	check(Engine.get_version_info().major==4 and Engine.get_version_info().minor==7,"verification uses Godot4.7")
	if await make_world():
		check(hero.hp==6 and is_equal_approx(hero.energy,99.0),"visual redesign keeps established initial gameplay resources")
		var defaults: RefCounted = load("res://scripts/combat/m18_controls.gd").new()
		defaults.defaults()
		await initial_route_combat()
		opening_jumps = route_jumps
		await pose_geometry_checks()
		await expression_and_hand_checks()
		await static_fire_arc_checks()
		await variable_jump_checks()
		await responsiveness_checks()
		await action_combination_checks()
		await airborne_dash_and_variant_checks()
		await runtime_expression_checks()
		await live_strike_region_checks()
		await moving_attack_and_landing_gait_checks()
		await live_motion_checks()
		await real_death_during_slash_check()
		await sword_hit_checks()
		await head_and_body_damage_checks()
		await archive_clearance_checks()
		await m20_persistence_check()
	if is_instance_valid(world):
		release_controls()
		stop_audio(world)
		OS.delay_msec(120)
		await process_frame
		world.queue_free()
		world = null
		await process_frame
		await process_frame
	phase = "safe cleanup"
	var restored: bool = restore_user_files()
	check(restored,"pre-existing save/settings/control files restored byte-for-byte")
	var report := {"engine":Engine.get_version_info().string,"checks":checks,"integration_checks":checks-pose_assertions-expression_assertions-arc_assertions,"pose_assertions":pose_assertions,"expression_assertions":expression_assertions,"arc_assertions":arc_assertions,"failures":failures,"physics_ticks":physics_ticks,"opening_route_complete":opening_route_complete,"opening_route_jumps":opening_jumps,"archive_jumps":archive_jumps,"model_samples":model_samples,"pose_samples":pose_samples,"movement_samples":movement_samples,"expression_samples":expression_samples,"strike_samples":strike_samples,"samples":samples,"save_restored":restored,"scope":"continuous actual-input opening01→active native larva victory→03; separate configured-start Archive18-jump ascent; tap/held jump, responsive steering, slash/dash/jump boundaries, live fire hit geometry, air token/pogo/energy, four native expressions, true lethal-hurt death, shared-rig/save fixtures; existing environment art/layout retained"}
	FileAccess.open(M20_REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M20 HERO REPORT checks=",checks," failures=",failures.size()," route=",opening_route_complete)
	OS.delay_msec(50)
	await process_frame
	quit(0 if failures.is_empty() and opening_route_complete else 1)
