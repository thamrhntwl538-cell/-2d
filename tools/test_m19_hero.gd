extends "res://tools/test_m18_combat.gd"
## M19 hero-specific QA. Reuses proven input-driving/save-backup helpers.
## Geometry/pose fixtures are declared separately from the uninterrupted opening.
const M19_WORLD_PATH := "res://scenes/stage_01/folding_library_m19.tscn"
const M19_REPORT := "user://m19_hero_report.json"
const M19_ATLAS := "res://assets/warden_m19/warden_parts.png"
var model_samples: Array[Dictionary] = []
var pose_samples: Array[Dictionary] = []
var archive_jumps: int = 0
var opening_jumps: int = 0
var pose_assertions: int = 0

func pose_geometry_checks() -> void:
	phase = "shared model pose and rigid proportions"
	var starting_checks: int = checks
	var rig: Node2D = load("res://scripts/warden_model_m19.gd").new()
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
	var packed: PackedScene = load(M19_WORLD_PATH)
	if not check(packed != null,"M19 campaign scene loads"): return false
	world = packed.instantiate()
	packed = null
	world.restore_saved_game = restore
	world.environment_preview = true
	world.transition_seconds = 0.001
	root.add_child(world)
	await step(45)
	hero = world.hero
	return check(is_instance_valid(hero) and hero.is_on_floor(),"M19 initial actor is physically supported")

func check_live_identity(label: String) -> void:
	check(hero.combat_container.visible and not hero.lantern_sprite.visible,label+": only the new M19 rig is visible")
	check(hero.combat_model.get_script().resource_path=="res://scripts/warden_model_m19.gd",label+": all states use the M19 model")
	check(hero.combat_container.scale.is_equal_approx(Vector2(0.37*hero.facing,0.37)),label+": source-to-world size is stable")
	var head: AtlasTexture = hero.combat_model.textures.get("head")
	check(head != null and head.atlas.resource_path==M19_ATLAS,label+": head uses the new original shared atlas")
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

func m19_persistence_check() -> void:
	phase = "M18 save compatibility with M19 presentation"
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
	phase = "Godot version and fresh M19 boot"
	check(Engine.get_version_info().major==4 and Engine.get_version_info().minor==7,"verification uses Godot4.7")
	if await make_world():
		check(hero.hp==6 and is_equal_approx(hero.energy,99.0),"visual redesign keeps established initial gameplay resources")
		var defaults: RefCounted = load("res://scripts/combat/m18_controls.gd").new()
		defaults.defaults()
		await initial_route_combat()
		opening_jumps = route_jumps
		await pose_geometry_checks()
		await live_motion_checks()
		await sword_hit_checks()
		await head_and_body_damage_checks()
		await archive_clearance_checks()
		await m19_persistence_check()
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
	var report := {"engine":Engine.get_version_info().string,"checks":checks,"integration_checks":checks-pose_assertions,"pose_assertions":pose_assertions,"failures":failures,"physics_ticks":physics_ticks,"opening_route_complete":opening_route_complete,"opening_route_jumps":opening_jumps,"archive_jumps":archive_jumps,"model_samples":model_samples,"pose_samples":pose_samples,"samples":samples,"save_restored":restored,"scope":"actual-input opening route01→native larva victory→03, plus declared pose/head-danger/save fixtures and configured-start actual eighteen-jump archive ascent; environment art and layout unchanged"}
	FileAccess.open(M19_REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M19 HERO REPORT checks=",checks," failures=",failures.size()," route=",opening_route_complete)
	OS.delay_msec(50)
	await process_frame
	quit(0 if failures.is_empty() and opening_route_complete else 1)
