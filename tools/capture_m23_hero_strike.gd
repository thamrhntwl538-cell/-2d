extends SceneTree
## Configured native review of the requested hero strike. This is not a win.
const World = preload("res://scripts/stage/m23_folding_library.gd")
const Player = preload("res://scripts/combat/m23_player.gd")
const OldModel = preload("res://scripts/warden_model_m21.gd")
const NewModel = preload("res://scripts/warden_model_m23.gd")
const HERO_ATLAS := "res://assets/warden_m20/warden_parts.png"
const HERO_SHA := "6eca7436c7a8c39451256aa56db465d664df0d6dbb42d8e7f24122592b34bb66"
const OUT := "user://m23_hero_strike"

class ReviewWorld extends World:
	func _save() -> void: pass
	func _save_settings() -> void: pass
	func _restore_settings() -> void: pass

var world: Node2D
var hero: CharacterBody2D
var checks := 0
var failures: Array[String] = []
var bounds: Array[Dictionary] = []
var captures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		print("FAIL ",message)

func step(count: int) -> void:
	for tick in range(count): await physics_frame
	await process_frame

func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.stop()
		node.stream = null
	for child in node.get_children(): stop_audio(child)

func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var target := OUT.path_join(filename+".jpg")
	check(root.get_texture().get_image().save_jpg(target,.96)==OK,"save native "+filename)
	captures.append(ProjectSettings.globalize_path(target))
	print("HERO_CAPTURE ",ProjectSettings.globalize_path(target))

func pose(direction: String, fraction: float, look: int = 1) -> void:
	hero.facing = look
	hero.attack_direction = direction
	hero.attack_elapsed = fraction*.30
	hero.attack_time = .30-hero.attack_elapsed
	hero.active_strike_time = maxf(0,.14-hero.attack_elapsed) if hero.attack_elapsed>=.06 and hero.attack_elapsed<.14 else 0.0
	hero._update_animation()

func geometry_checks() -> void:
	var model: Node2D = hero.combat_model
	for look in [-1,1]:
		for direction in ["attack","up","down"]:
			for reach in [1.0,1.15]:
				for fraction in [.21,.30,.40,.46]:
					pose(direction,fraction,look)
					model.sword_reach = reach
					model.set_combat_pose("slash" if direction=="attack" else "slash_"+direction,fraction,false,0.0,false)
					var rect: Rect2 = hero.strike_rect(direction,look)
					var visible: Rect2 = model.get_strike_rect()
					check(rect.has_area(),"compact contact exists for "+direction+" / "+str(look)+" / "+str(reach)+" / "+str(fraction))
					var a: Vector2 = model.to_global(visible.position)
					var b: Vector2 = model.to_global(visible.end)
					check(rect.is_equal_approx(Rect2(a,b-a).abs()),"world contact follows the same mirrored native flame bounds")
					if direction=="attack" and reach==1.0:
						check(rect.size.x>=29.0,"head clipping preserves a practical full contact band, not a tiny tip")
						var near_target := Rect2(hero.position+Vector2(float(look)*44-8,-52),Vector2(16,20))
						var remote_target := Rect2(hero.position+Vector2(float(look)*80-8,-52),Vector2(16,20))
						check(rect.intersects(near_target),"an ordinary nearby target overlaps the visible compact swing")
						check(not rect.intersects(remote_target),"a target beyond the visible small flame receives no invisible extra reach")
					if fraction==.30:
						bounds.append({"direction":direction,"facing":look,"reach_multiplier":reach,"relative_rect":[rect.position.x-hero.position.x,rect.position.y-hero.position.y,rect.size.x,rect.size.y],"held_blade_world_px":model.sword_start.distance_to(model.sword_end)*.37})
	for phase in [0.0,.16,.19,.48,.60,.99]:
		pose("attack",phase)
		check(not hero.strike_rect("attack",1).has_area(),"contact stays absent outside the existing .06-.14 second window")
	model.sword_reach = 1.0
	model.set_combat_pose("slash",.29,false)
	var forward: float = float(model.joints.torso[0].x)-256.0
	model.set_combat_pose("slash",.60,false)
	var recoil: float = float(model.joints.torso[0].x)-256.0
	model.set_combat_pose("slash",1.0,false)
	check(forward*.37>4.5 and forward*.37<6.5,"short rigid shoulder drive is about five to six world pixels")
	check(recoil<0,"follow-through settles briefly behind the ready shoulder")
	check(absf(float(model.joints.torso[0].x)-256.0)<.001,"recovery returns precisely to ready, without accumulating a body offset")
	check(is_equal_approx(model.sword_start.distance_to(model.sword_end)*.37,19.24),"base held ember blade is19.24 world pixels")
	model.set_combat_pose("slash",.30,false)
	var edge := -INF
	for point in model.arc_polygon: edge = maxf(edge,(point.x-256.0)*.37)
	check(edge>=58 and edge<=65,"base flame tip remains short at about61 world pixels")
	model.set_motion("idle",0)
	check(model.arc_polygon.is_empty() and not model.get_strike_rect().has_area(),"idle has no lingering flame or damaging volume")

func make_label(parent: Node, value: String, point: Vector2, size: Vector2, font_size: int = 18) -> Label:
	var label := Label.new()
	label.text = value
	label.position = point
	label.size = size
	label.add_theme_font_override("font",load("res://assets/fonts/DejaVuSans.ttf"))
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("eadcc3"))
	parent.add_child(label)
	return label

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Native display required for this visual review")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	check(FileAccess.get_sha256(HERO_ATLAS)==HERO_SHA,"approved M20 atlas remains byte-identical")
	world = ReviewWorld.new()
	world.is_boss_trial = true
	world.restore_saved_game = false
	root.add_child(world)
	await step(40)
	var previous: CharacterBody2D = world.hero
	hero = Player.new()
	hero.world_ref = world
	world.hero = hero
	root.add_child(hero)
	hero.z_index = 5
	hero.position = Vector2(1850,1440)
	hero.movement_bounds = previous.movement_bounds
	hero.fall_limit = previous.fall_limit
	hero.has_blade = true
	hero.has_dash = true
	hero.has_code_slash = true
	hero.last_safe_position = hero.position
	world.camera.target = hero
	previous.queue_free()
	await step(12)
	check(hero.is_on_floor(),"the real inherited player stands on the actual arena floor")
	world._check_compiler_entry()
	await step(70)
	world.gameplay_active = false
	world.set_process(false)
	hero.set_physics_process(false)
	world.registered_boss.set_physics_process(false)
	world.registered_boss.position = Vector2(2250,1440)
	world.registered_boss.state = "idle"
	world.registered_boss.direction = -1
	world.registered_boss.warning_text_ar = ""
	world.registered_boss.warning_text_en = ""
	world.registered_boss._update_visual()
	world.camera.target = null
	if is_instance_valid(world._boss_camera_tween): world._boss_camera_tween.kill()
	world.camera.position = Vector2(2090,1204)
	world.camera.zoom = Vector2(1.2,1.2)
	world.camera.reset_smoothing()
	world.arrival_title.dismiss()
	world.hud._title_elapsed = world.hud._title_duration
	world._update_compiler_presentation(0.0)
	world.boss_music.stop_all()
	stop_audio(world)
	geometry_checks()
	world.combat_state.unequip("reach",true)
	pose("attack",.30)
	await capture("01_compact_flame_in_arena")
	pose("attack",.68)
	await capture("02_short_follow_through_in_arena")
	pose("up",.30)
	await capture("03_compact_upward_in_arena")
	hero.position.y -= 130.0
	pose("down",.30)
	hero.combat_model.set_combat_pose("slash_down",.30,true)
	hero._update_lantern_anchor()
	await capture("04_compact_downward_in_arena")
	# A neutral native comparison clearly separates the old broad effect from
	# the requested compact original strike. These are configured rig samples.
	world.hide()
	hero.hide()
	var studio := CanvasLayer.new()
	studio.layer = 101
	root.add_child(studio)
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO,Vector2(1280,0),Vector2(1280,720),Vector2(0,720)])
	background.color = Color("0d131f")
	studio.add_child(background)
	make_label(studio,"M23 / COMPACT EMBER STRIKE",Vector2(40,28),Vector2(1190,40),28)
	make_label(studio,"Same approved hero / original atlas unchanged / native configured pose review",Vector2(40,72),Vector2(1190,30),18)
	var old := OldModel.new()
	var newer := NewModel.new()
	studio.add_child(old)
	studio.add_child(newer)
	old.position = Vector2(170,570)-Vector2(256,456)*1.2
	newer.position = Vector2(795,570)-Vector2(256,456)*1.2
	old.scale = Vector2(1.2,1.2)
	newer.scale = Vector2(1.2,1.2)
	old.sword_visible = true
	newer.sword_visible = true
	old.set_combat_pose("slash",.30,false)
	newer.set_combat_pose("slash",.30,false)
	make_label(studio,"PREVIOUS BROAD EFFECT",Vector2(58,608),Vector2(560,35),22)
	make_label(studio,"REQUESTED SHORT FLAME STRIKE",Vector2(676,608),Vector2(570,35),22)
	make_label(studio,"Attack 0.30 s / contact 0.06-0.14 s / free movement retained",Vector2(40,672),Vector2(1190,30),17)
	await capture("05_old_and_compact_comparison")
	studio.queue_free()
	await process_frame
	stop_audio(world)
	OS.delay_msec(120)
	world.queue_free()
	hero.queue_free()
	world = null
	hero = null
	await step(4)
	var report := {"schema":"m23-hero-compact-strike-1","engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"hero_atlas_sha256":FileAccess.get_sha256(HERO_ATLAS),"attack_duration_seconds":.30,"cooldown_seconds":.36,"contact_seconds":[.06,.14],"body_motion":"Rigid upper-body forward drive then recoil; original feet, movement and collisions retained.","bounds":bounds,"captures":captures,"scope":"Configured native player/model geometry and artwork review. Does not claim a full fight, input-only victory or subjective game feel."}
	FileAccess.open(OUT.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M23 HERO STRIKE ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
