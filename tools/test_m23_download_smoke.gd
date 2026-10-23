extends SceneTree
var world: Node2D
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame

func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
		node.stop()
		node.stream = null
	for child in node.get_children(): stop_audio(child)

func run() -> void:
	var path := str(ProjectSettings.get_setting("application/run/main_scene"))
	verify(path=="res://scenes/bosses/compiler_trial_m23.tscn","Downloaded project defaults to the actual M23 trial")
	var packed: PackedScene = load(path)
	verify(packed!=null,"Default downloaded scene loads")
	if packed==null:
		quit(1)
		return
	world = packed.instantiate()
	root.add_child(world)
	current_scene = world
	await frames(16)
	var hero: Node2D = world.get("hero")
	var boss: Node2D = world.get("registered_boss")
	verify(is_instance_valid(hero) and is_instance_valid(boss),"Actual hero and compiler spawn from downloaded source")
	verify(str(hero.get_script().resource_path)=="res://scripts/combat/m23_player.gd","Downloaded game uses the compact M23 hero")
	verify(bool(world.get("is_boss_trial")),"Downloaded F5 enters the isolated trial")
	verify(int(hero.get("hp"))==6,"Fresh download has six health")
	verify(FileAccess.get_sha256("res://assets/warden_m20/warden_parts.png")=="6eca7436c7a8c39451256aa56db465d664df0d6dbb42d8e7f24122592b34bb66","Approved hero texture is identical in downloaded ZIP")
	var sound: Node = world.get("soundscape")
	var music: Node = world.get("boss_music")
	verify(bool(sound.get("manifest_loaded")) and bool(music.get("assets_ready")),"Original sound manifest and both score assets load")
	Input.action_press("move_right")
	var steps := 0
	while hero.position.x<1385 and steps<220:
		await frames(1)
		steps += 1
	Input.action_release("move_right")
	verify(bool(world.get("boss_active")) and bool(boss.get("activated")),"Real input crosses the downloaded encounter threshold")
	Input.action_press("attack")
	await frames(1)
	Input.action_release("attack")
	await frames(100)
	verify(int(hero.get("strike_serial"))>0,"Downloaded compact attack responds to actual input")
	verify(int(boss.get("direction"))==-1,"Boss faces the hero on its left")
	verify(bool(music.get("fight_playing")) and int(music.get("current_phase"))==1,"Actual encounter plays its first original score")
	var wait_ticks := 0
	while str(boss.get("state")) in ["dormant","intro","idle"] and wait_ticks<150:
		await frames(1)
		wait_ticks += 1
	var events: Dictionary = sound.get("event_counts")
	verify(int(events.get("compiler_voice_intro",0))>0 and int(events.get("hero_attack",0))>0,"Downloaded original boss and hero voice paths trigger")
	verify(str(boss.get("state")) not in ["dormant","intro","idle"],"Downloaded native AI starts an actual pattern after its normal idle interval")
	verify(int(events.get("compiler_bolts",0))>0,"Downloaded first-pattern warning sound fires through real AI")
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("user://m23_download_native.png")
	var result := {"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"main_scene":path,"actual_input":true,"boss_state":str(boss.get("state")),"event_counts":events,"scope":"Cold GitHub ZIP native import and startup/input smoke; full48HP combat is verified separately on identical source hashes."}
	FileAccess.open("user://m23_download_smoke.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	sound.call("stop_all")
	music.call("stop_all")
	stop_audio(world)
	await create_timer(.15).timeout
	await frames(2)
	current_scene = null
	world.queue_free()
	world = null
	hero = null
	boss = null
	sound = null
	music = null
	await frames(4)
	await create_timer(.05).timeout
	print("M23 DOWNLOADED ZIP SMOKE ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
