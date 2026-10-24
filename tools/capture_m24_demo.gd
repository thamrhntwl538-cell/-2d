extends "res://tools/test_m24_bell.gd"
## Native MovieWriter wrapper: art fixtures first, then the real Input driver.
## Use a fresh XDG_DATA_HOME, --write-movie outside the repository and --fixed-fps 60.
const REVIEW_SCENE := "res://scenes/minibosses/bell_character_review_m24.tscn"
const DEMO_OUTPUT := "res://previews/m24"
const STILL_NAMES := {
	"01_bell_at_rest": "30_native_rest",
	"02_bell_encounter": "31_native_encounter",
	"03_bell_swing": "32_native_swing",
	"04_bell_air_drop": "33_native_air_drop",
	"05_bell_resonance": "34_native_resonance",
	"06_bell_victory": "35_native_victory",
	"07_bell_walk": "36_native_walk",
	"08_bell_crouch": "37_native_crouch"
}
var native_stills: Array[Dictionary] = []

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Movie capture requires a native viewport")
		quit(1)
		return
	root.size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(DEMO_OUTPUT)
	if "--skip-art" not in OS.get_cmdline_user_args():
		var art: Node2D = load(REVIEW_SCENE).instantiate()
		root.add_child(art)
		await step(3)
		if art.has_method("set_page"): art.set_page("motion")
		# This opening is explicitly a configured animation review, not gameplay.
		await step(240)
		art.queue_free()
		await step(2)
	ticks = 0
	# The inherited driver starts at the rest, walks through the gate, then uses
	# actual movement/jump/sword/spell input. It never injects positive damage.
	await super.run()

func photo(tag: String) -> void:
	if DisplayServer.get_name() == "headless" or captured.has(tag) or not STILL_NAMES.has(tag): return
	captured[tag] = true
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	var target: String = DEMO_OUTPUT + "/" + STILL_NAMES[tag] + ".jpg"
	if frame.save_jpg(target,.95) != OK:
		failures.append("Unable to save native gameplay still " + target)
		return
	native_stills.append({
		"path": target, "width": frame.get_width(), "height": frame.get_height(),
		"actual_inputs_only": true, "configured_fixture": false,
		"hero_hp": hero.hp, "bell_hp": bell.hp, "bell_state": bell.state,
		"physics_tick": ticks, "sound_events": world.sound_events.duplicate(true)
	})
	print("M24 NATIVE DEMO STILL ",target)

func cleanup() -> void:
	# Let the genuine collapse and the original release cadence finish audibly.
	# The boss is already defeated and the hero remains a live, idle actor.
	if stats.get("won", false) and is_instance_valid(world): await step(390)
	await super.cleanup()
	var metadata := {
		"engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"viewport": [1280,720], "movie_fps": 60,
		"opening_art_fixture_seconds": 0 if "--skip-art" in OS.get_cmdline_user_args() else 4,
		"victory_outro_seconds": 6.5 if stats.get("won", false) else 0,
		"opening_art_fixture": "Configured native animation review; no gameplay claim.",
		"gameplay_scope": "Inherited actual Input driver enters the arena and fights with real jump, movement, sword and spell. No positive damage injection or frozen fighters.",
		"audio_scope": "Native game mixer captured by Godot MovieWriter; no replacement audio track.",
		"native_stills": native_stills, "fight": stats, "failures": failures
	}
	FileAccess.open(DEMO_OUTPUT + "/demo_capture_metadata.json",FileAccess.WRITE).store_string(JSON.stringify(metadata,"\t"))
