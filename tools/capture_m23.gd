extends "res://tools/test_m23_boss_world.gd"
## Native arena review. Each composition states whether its start is configured;
## attacks shown here are the actual boss AI after an ordinary trial entrance.
const OUTPUT := "res://previews/m23"
var captures: Array[Dictionary]=[]
var profile_samples: Array[Dictionary]=[]

func rendered_bone_error(visual: Node2D) -> float:
	if not visual.has_method("get_rendered_arm_joints_local") or not visual.has_method("get_arm_lengths"): return INF
	var joints: Dictionary=visual.get_rendered_arm_joints_local()
	var lengths: Dictionary=visual.get_arm_lengths()
	var shoulder: Vector2=joints.get("shoulder",Vector2.INF)
	var elbow: Vector2=joints.get("elbow",Vector2.INF)
	var wrist: Vector2=joints.get("wrist",Vector2.INF)
	var grip: Vector2=joints.get("grip",Vector2.INF)
	return maxf(absf(shoulder.distance_to(elbow)-float(lengths.get("upper",0))),maxf(absf(elbow.distance_to(wrist)-float(lengths.get("forearm",0))),absf(wrist.distance_to(grip)-float(lengths.get("palm",0)))))

func capture(tag: String, description: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image=root.get_texture().get_image()
	var path:=OUTPUT+"/"+tag+".jpg"
	check(not frame.is_empty() and frame.save_jpg(path,.94)==OK,"native frame saved: "+tag)
	captures.append({"path":path,"size":[frame.get_width(),frame.get_height()],"room":world.current_room,"boss_state":boss.state if is_instance_valid(boss) else "none","boss_hp":boss.hp if is_instance_valid(boss) else 0,"hero_hp":hero.hp,"direction":boss.direction if is_instance_valid(boss) else 0,"camera_zoom":[world.camera.zoom.x,world.camera.zoom.y],"description":description})
	print("M23 CAPTURE ",path)

func profile_grip_sample(label: String) -> void:
	var visual: Node2D=boss.visual
	if not visual.has_method("get_weapon_grip_local") or not visual.has_method("get_hand_grip_local"):
		check(false,"profile rig exposes both actual hand and weapon grip endpoints")
		return
	var weapon: Vector2=visual.get_weapon_grip_local()
	var hand: Vector2=visual.get_hand_grip_local()
	var weapon_global: Vector2=visual.to_global(weapon)
	var hand_global: Vector2=visual.to_global(hand)
	var bone_error:=rendered_bone_error(visual)
	profile_samples.append({"label":label,"state":boss.state,"direction":boss.direction,"visual_facing":visual.facing,"weapon_local":[weapon.x,weapon.y],"hand_local":[hand.x,hand.y],"world_error":weapon_global.distance_to(hand_global),"maximum_rendered_bone_error":bone_error,"held_blade_visible":visual.is_held_blade_visible()})
	check(weapon_global.distance_to(hand_global)<.75,"hand and blade grip coincide: "+label)
	check(visual.facing==boss.direction and signf(visual.scale.x)==float(boss.direction),"profile render mirrors the actor's captured direction: "+label)
	check(bone_error<.002,"actual rendered upper/forearm/palm lengths remain fixed: "+label)

func profile_acceptance(release_images_only: bool = false) -> void:
	stage="configured real-arena side-profile and grip review"
	if not check(is_instance_valid(boss.visual) and boss.visual.has_method("get_hand_grip_local"),"new side-profile rig is installed"): return
	# The real entry/first-warning photos above used normal gameplay. These
	# next cases deliberately isolate presentation: controller combat and hero
	# physics stop, while the actual boss still runs native physics/AI clocks.
	world.set_physics_process(false)
	hero.set_physics_process(false)
	release_controls()
	boss.clear_attacks()
	boss.activated=false
	boss._enter("dormant",0)
	boss.global_position=Vector2(2450,1440)
	world.gameplay_active=true
	world.boss_active=false
	if is_instance_valid(world.arrival_title): world.arrival_title.dismiss()
	if is_instance_valid(world._boss_camera_tween): world._boss_camera_tween.kill()
	world.camera.target=null
	world.camera.zoom=Vector2(1.6,1.6)
	world.camera.global_position=boss.global_position+Vector2(0,-175)
	world.camera.offset=Vector2.ZERO
	for side in [-1,1]:
		hero.global_position=boss.global_position+Vector2(side*260,0)
		hero.velocity=Vector2.ZERO
		await step(3)
		check(boss.direction==side,"actual dormant native physics faces hero side %s"%side)
		profile_grip_sample("dormant side%s"%side)
		if not release_images_only:
			await capture("10_profile_left" if side<0 else "11_profile_right","Configured hero position on this side of the real arena; actual dormant actor tracks the hero. Fitted review camera1.6x; not an input battle.")
	# Within the12px deadzone, the previous safe-facing direction persists.
	hero.global_position=boss.global_position+Vector2(-6,0)
	await step(2)
	check(boss.direction==1,"safe-state facing retains direction inside12px deadzone")
	for side in [-1,1]:
		stage="configured native sweep capture lock side%s"%side
		boss.clear_attacks()
		boss.global_position=Vector2(2450,1440)
		hero.global_position=boss.global_position+Vector2(side*260,0)
		boss.activated=true
		world.boss_active=true
		boss.pattern_index=1 # configured next real AI pattern: sweep
		boss._enter("idle",.001)
		await step(2)
		check(boss.state=="sweep_warning" and boss.direction==side,"native idle transition captures sweep side%s"%side)
		# Cross only the configured hero position, not the attack direction.
		hero.global_position=boss.global_position+Vector2(-side*260,0)
		while boss.state=="sweep_warning" and boss.state_time>.14:
			await step(1)
		check(boss.state=="sweep_warning" and boss.direction==side,"sweep warning keeps captured direction after hero crosses")
		profile_grip_sample("windup side%s"%side)
		if not release_images_only:
			await capture("12_profile_windup_left" if side<0 else "14_profile_windup_right","Configured sweep-pattern diagnostic; actual AI warning clock and captured facing remain fixed after the hero crosses. Review camera1.6x.")
		while boss.state=="sweep_warning": await step(1)
		await step(3)
		check(boss.state=="sweep_active" and boss.direction==side,"active release keeps captured direction after crossing")
		check(boss.danger_rect().size.is_equal_approx(Vector2(384,96)),"side rig preserves tested384x96 heavy sweep")
		profile_grip_sample("release side%s"%side)
		await capture("13_profile_release_left" if side<0 else "15_profile_release_right","Actual sweep release inside a configured pattern review. The visible field uses the unchanged native damaging384x96 rectangle; hero/controller are suspended for inspection.")
		while boss.state=="sweep_active": await step(1)
		await step(2)
		check(boss.state=="recover" and boss.direction==-side,"native recovery safely turns toward the crossed hero")
		profile_grip_sample("recovery side%s"%(-side))
	# Static hand-attachment diagnostics sample rest/windup/release and both
	# mirrors without changing any live encounter health or claiming victory.
	boss.set_physics_process(false)
	var maximum_error:=0.0
	var maximum_bone_error:=0.0
	var samples:=0
	for side in [-1,1]:
		boss.direction=side
		for pose_name in ["idle","sweep_warning","sweep_active","recover"]:
			for progress in [.0,.5,1.0]:
				boss.visual.update_pose(pose_name,2.0+progress,progress,progress if pose_name.ends_with("_warning") else 0.0)
				var weapon: Vector2=boss.visual.get_weapon_grip_local()
				var hand: Vector2=boss.visual.get_hand_grip_local()
				maximum_error=maxf(maximum_error,weapon.distance_to(hand))
				maximum_bone_error=maxf(maximum_bone_error,rendered_bone_error(boss.visual))
				samples+=1
	check(samples==24 and maximum_error<.75,"all24 mirrored rest/windup/release/recovery samples retain one grip")
	check(samples==24 and maximum_bone_error<.002,"all24 mirrored poses retain constant rendered upper/forearm/palm bone lengths")
	check(FileAccess.get_sha256(HERO_ATLAS)==HERO_ATLAS_SHA256,"new boss presentation leaves hero atlas byte-identical")
	record("profile_acceptance_fixture",{"configured_hero_positions":true,"normal_entry_photos":not release_images_only,"release_images_only":release_images_only,"boss_ai_timing_unmodified":true,"fitted_camera_zoom":1.6,"grip_samples":samples,"maximum_grip_error":maximum_error,"maximum_rendered_bone_error":maximum_bone_error,"fixed_bone_lengths":boss.visual.get_arm_lengths(),"samples":profile_samples,"full_fight_rerun":false})

func run_checks() -> void:
	remember_user_files()
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	if await make_world(true,false):
		if "--profile-release-only" in OS.get_cmdline_user_args(): await profile_acceptance(true)
		elif await begin_trial():
			await step(42)
			await capture("01_compiler_intro","Actual threshold entry from the supported trial checkpoint; native intro/camera/music, no injected boss state or health.")
			for tick in range(180):
				if boss.state=="bolts_warning": break
				await step(1)
			await step(14)
			await capture("02_compiler_code_warning","Native first code warning and48-health HUD after ordinary trial entry; original approved hero art retained.")
			if "--profile-review" in OS.get_cmdline_user_args(): await profile_acceptance()
	await dispose_world()
	check(restore_user_files(),"native review restores pre-existing normal/trial files")
	FileAccess.open("user://m23_visual_review.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"checks":checks,"captures":captures,"evidence":evidence,"failures":failures,"scope":"native GL trial entrance plus explicitly configured side-profile fixtures if requested; not a completed battle proof"},"\t"))
	OS.delay_msec(50)
	await process_frame
	quit(0 if failures.is_empty() else 1)
