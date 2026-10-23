extends SceneTree
## Configured HUD state transitions. The world remains the sole resource owner.
const HUD = preload("res://scripts/ui/m22_hud.gd")
var world: Node2D
var hud: CanvasLayer
var failures: Array[String] = []
var checks: int = 0
var samples: Array[Dictionary] = []

class DisplayWorld extends Node2D:
	var hero: Node2D
	var status := {"hp":6,"energy":66.0,"max_energy":99.0,"wallet":12,"equipped":["draw","reach"],"capacity":4,"used_capacity":3,"spell_owned":true}
	func combat_hud_context() -> Dictionary:
		return status

func _initialize() -> void:
	call_deferred("run_check")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func frames(count: int) -> void:
	for index in range(count): await process_frame

func frame_image() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func capture(tag: String, note: String) -> Image:
	var frame: Image = await frame_image()
	DirAccess.make_dir_recursive_absolute("user://m22_combat_samples")
	var path := "user://m22_combat_samples/"+tag+".jpg"
	check(not frame.is_empty(),"Native HUD viewport is nonempty")
	if not frame.is_empty(): check(frame.save_jpg(path,.94)==OK,"Native HUD sample saved")
	samples.append({"path":path,"configured_hud_state":true,"note":note})
	print("M22 COMBAT SAMPLE ",ProjectSettings.globalize_path(path))
	return frame

func run_check() -> void:
	world = DisplayWorld.new()
	root.add_child(world)
	hud = HUD.new()
	world.add_child(hud)
	hud.setup(world)
	var room := {"id":1,"title_ar":"بهو الصفحة الأولى","title_en":"The First Page"}
	hud.update_status(room,{"visited":[1]})
	await frames(35)
	var display: Control = hud.combat_display
	check(display.get_script().resource_path=="res://scripts/ui/m22_combat_display.gd","M22 replaces only the combat display")
	check(absf(display.shown_energy-66)<.2,"Round reserve settles to authoritative world energy")
	check(display.context.hp==6,"Initial health shows six charged lanterns")
	var full: Image = await capture("hud_full","Six health lanterns, one shared round energy vessel at66/99, actual wallet/fitil/technique context.")
	world.status.hp = 5
	hud.update_combat_status()
	await frames(2)
	check(display.damage_flash>0 and display.hurt_slots.has(5),"Losing one health ignites the sixth-lantern damage animation")
	await frames(22)
	var damaged: Image = await capture("hud_damaged","World health5: sixth health lantern is unlit; shared reserve is unchanged.")
	check(display.context.energy==66.0,"Health damage does not invent another energy pool")
	if not full.is_empty() and not damaged.is_empty():
		check(full.get_pixel(298,45).get_luminance()>damaged.get_pixel(298,45).get_luminance()+.2,"Native sixth-lantern flame visibly extinguishes")
	world.status.energy = 77.0
	hud.update_combat_status()
	check(display.gain_flash>0,"A world melee-energy gain produces the orb charge response")
	await frames(24)
	check(display.shown_energy>76.5,"Orb fill follows the melee gain")
	world.status.hp = 6
	world.status.energy = 44.0
	hud.update_combat_status()
	check(display.heal_flash>0 and display.healed_slots.has(5),"Healing relights the spent health lantern")
	check(display.spend_flash>0,"Healing consumes the same shared glow and triggers its spend response")
	await frames(25)
	var healed: Image = await capture("hud_healed","World heal restores sixth health lantern while spending33 from the same77-energy reserve, leaving44.")
	if not damaged.is_empty() and not healed.is_empty():
		check(healed.get_pixel(298,45).get_luminance()>damaged.get_pixel(298,45).get_luminance()+.2,"Native healed flame becomes bright again")
	world.status.energy = 11.0
	hud.update_combat_status()
	await frames(25)
	var spent: Image = await capture("hud_energy_spent","Technique spends33 from44, leaving11; no second reserve is created and the technique becomes unavailable.")
	check(absf(display.shown_energy-11)<.3,"Technique use lowers the same displayed reserve")
	check(display._get_tooltip(Vector2(306,70)).contains("مزيد"),"Technique readiness reflects insufficient shared energy")
	if not full.is_empty() and not spent.is_empty():
		check(full.get_pixel(52,68).get_luminance()>spent.get_pixel(52,68).get_luminance()+.10,"Native round-vessel liquid visibly drains")
	world.status.wallet = 19
	hud.update_combat_status()
	check(display.context.wallet==19 and display.wallet_flash>0,"Authoritative collected currency updates the wallet counter")
	hud.set_language("en")
	await frames(2)
	check(display._get_tooltip(Vector2(306,70))=="Needs more glow","Display localization follows the HUD")
	var report := {"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"configured_hud_states":true,"samples":samples}
	FileAccess.open("user://m22_combat_display_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M22 COMBAT DISPLAY REPORT ",JSON.stringify(report))
	world.queue_free()
	world = null
	hud = null
	await frames(4)
	quit(0 if failures.is_empty() else 1)
