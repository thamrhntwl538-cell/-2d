@tool
extends Node2D
class_name M15AcademicReaction
## Restrained decorative reaction, deliberately without attack or damage logic.
## Rotating rings, code arcs and motes are procedural supporting effects. Supply
## separate painted machinery through texture/source_rect for the main object.

signal reacted(mode: String)

@export_enum("process", "output", "tribunal") var kind: String = "process":
	set(value):
		kind = value
		queue_redraw()
@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
@export var source_rect := Rect2():
	set(value):
		source_rect = value
		queue_redraw()
## Art and effects are centred on this node; room layout owns the world position.
@export var art_size := Vector2(320, 320)
@export var active: bool = false
var mode: String = "idle"
var elapsed: float = 0.0
var pulse: float = 0.0

func _process(delta: float) -> void:
	elapsed += delta
	pulse = maxf(0.0, pulse - delta * 0.65)
	queue_redraw()

func react(next_mode: String = "activate") -> void:
	mode = next_mode
	active = next_mode not in ["idle", "reset", "deactivate"]
	pulse = 1.0 if active else 0.0
	if next_mode == "victory": pulse = 0.65
	reacted.emit(next_mode)

func _draw() -> void:
	var phase_two := mode == "phase2"
	var calmer := mode == "victory"
	var activity := 1.0 if active else 0.28
	if phase_two: activity = 1.35
	if calmer: activity = 0.38
	var cyan := Color(0.34, 0.58, 0.61, 0.16 * activity)
	var bronze := Color(0.49, 0.41, 0.28, 0.30)
	var rotation_rate := 0.10 if active else 0.025
	if phase_two: rotation_rate = 0.17
	if calmer: rotation_rate = 0.035
	var slow_angle := elapsed * rotation_rate
	if texture:
		var region := source_rect
		if region.size.x <= 0 or region.size.y <= 0:
			region = Rect2(Vector2.ZERO, texture.get_size())
		draw_texture_rect_region(texture, Rect2(-art_size / 2.0, art_size), region)
	# The background ring remains well below the contrast of the hero's lantern.
	var radius := minf(art_size.x, art_size.y) * 0.42
	if kind == "process":
		draw_arc(Vector2.ZERO, radius, slow_angle, slow_angle + TAU * 0.82, 60, bronze, 2.0, true)
		draw_arc(Vector2.ZERO, radius * 0.73, -slow_angle, -slow_angle + TAU * 0.65, 52, cyan, 1.8, true)
		for i in range(8):
			var angle := slow_angle + i * TAU / 8.0
			var direction := Vector2.from_angle(angle)
			draw_line(direction * (radius - 5), direction * (radius + 5), bronze, 2, true)
		if active:
			for i in range(4):
				var angle := -slow_angle + i * TAU / 4.0
				draw_circle(Vector2.from_angle(angle) * radius * 0.73, 3.5, Color(0.50, 0.74, 0.74, 0.34))
	elif kind == "output":
		var bob := Vector2(0, sin(elapsed * 0.9) * 4)
		draw_circle(bob, radius * 0.20, Color(0.32, 0.61, 0.65, 0.06 + pulse * 0.06))
		draw_arc(bob, radius * 0.5, slow_angle, slow_angle + TAU * 0.75, 52, bronze, 1.8, true)
		for i in range(9):
			var angle := i * TAU / 9.0 + slow_angle
			var distance := radius * (0.65 + sin(elapsed * 0.45 + i) * 0.15)
			draw_circle(bob + Vector2.from_angle(angle) * distance, 2.0, cyan)
			if active:
				draw_line(bob + Vector2.from_angle(angle) * (radius * 0.22), bob + Vector2.from_angle(angle) * distance, Color(cyan, 0.08), 1.0, true)
	else:
		# Arena accents frame the central space; they never draw a beam across it.
		for side in [-1.0, 1.0]:
			var center := Vector2(side * radius * 1.25, 0)
			draw_arc(center, radius * 0.65, -PI * 0.5, PI * 0.5, 32, bronze, 2, true)
			if active:
				draw_arc(center, radius * 0.54, -PI * 0.4 + sin(slow_angle) * 0.04, PI * 0.4, 32, cyan, 1.4, true)
			if phase_two:
				# A second narrow flank ring and three settled code motes signal
				# stronger arena corruption, with the playable centre kept clear.
				draw_arc(center, radius * 0.44, -PI * 0.38 - slow_angle * 0.15, PI * 0.38 - slow_angle * 0.15, 32, Color(0.40, 0.65, 0.67, 0.16), 1.2, true)
				for i in range(3):
					draw_circle(center + Vector2(side * radius * 0.14, (i-1)*18), 2.3, Color(0.51, 0.73, 0.72, 0.24))
			elif calmer:
				draw_circle(center + Vector2(0, -radius * 0.4), 3, Color(0.68, 0.66, 0.48, 0.15))
	if pulse > 0:
		draw_arc(Vector2.ZERO, radius * (1.0 + (1.0-pulse) * 0.25), 0, TAU, 64, Color(0.49, 0.73, 0.72, pulse * 0.12), 2, true)
