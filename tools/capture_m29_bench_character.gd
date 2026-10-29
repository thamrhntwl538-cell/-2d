extends "res://tools/test_m29_bench.gd"
## Native component review, not a claim of full-world exploration. This uses
## the actual approved atlas and same bench director/control path as gameplay.
var _camera: Camera2D

func capture(tag: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/workspace/work/m29_bench_"+tag+".png")

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	root.size=Vector2i(760,540)
	RenderingServer.set_default_clear_color(Color("0b101b"))
	Controls.new().defaults()
	await fixture([],Vector2(200,620))
	_camera=Camera2D.new()
	_camera.position=Vector2(230,550)
	_camera.zoom=Vector2(3,3)
	world.add_child(_camera)
	await step(6)
	await capture("01_standing")
	await pulse("interact")
	await until_state("sitting")
	await step(14)
	await capture("02_settling")
	await until_state("seated")
	await step(4)
	await capture("03_seated")
	var report: Dictionary={"scope":"Native3x component render for joint/seat review. Configured floor/position/startingHP; actual interaction/director pose. No world traversal claim.","actor":world.hero.get_bench_snapshot(),"director":world.director.get_snapshot()}
	FileAccess.open("/workspace/work/m29_bench_character_capture.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	await step(5)
	await pulse("interact")
	await until_state("idle")
	await capture("04_standing_again")
	release_all()
	world.queue_free()
	await step(4)
	quit()
