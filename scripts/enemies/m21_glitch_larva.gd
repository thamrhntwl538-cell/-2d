extends "res://scripts/enemies/m18_glitch_larva.gd"
## M21 is a presentation-only revision of the approved paper/ink larva.
## AI, HP, timings, collision shapes, hitboxes and rewards are inherited intact.
const CLEAN_ART_PATH := "res://assets/enemies/m21/glitch_larva.png"
const CLEAN_ART_REGION := Rect2(40.0,213.0,1724.0,585.0)

func _ready() -> void:
	super._ready()
	_art = load(CLEAN_ART_PATH) as Texture2D
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()

func _draw() -> void:
	var warning: bool = state=="windup"
	var striking: bool = state=="lunge"
	var pulse: float = 0.5+sin(age*(24.0 if warning else 4.0))*0.5
	# Preserve the inherited planted, small warning squash and attack stretch.
	var squash := Vector2(1.0+(0.05 if striking else -0.045 if warning else 0.0),0.93 if warning else 1.0)
	draw_set_transform(Vector2.ZERO,0.0,Vector2(float(direction),1.0)*squash)
	for i in range(4,0,-1):
		var a: float = float(i)/4.0
		_draw_ellipse_shape(Vector2(-5,-1),Vector2(55+a*5,4+a),Color(0.015,0.022,0.030,0.05))
	for i in range(4):
		var x: float = -40.0+float(i)*22.0
		var step: float = sin(age*(17.0 if striking else 8.0)+float(i)*1.6)
		draw_polyline(PackedVector2Array([Vector2(x,-13),Vector2(x-10,-6+step*2),Vector2(x-17,-1)]),Color("17242b"),3.0,true)
	if _art!=null:
		var tint := Color(1.8,1.8,1.8,1.0) if hit_flash>0 else Color.WHITE
		# A clean source crop keeps the original long, low 140px silhouette.
		# This is not a new size or a change to the 104x52 damage target.
		var height: float = 140.0*CLEAN_ART_REGION.size.y/CLEAN_ART_REGION.size.x
		draw_texture_rect_region(_art,Rect2(-70,-height,140,height),CLEAN_ART_REGION,tint)
	else:
		_draw_fallback(pulse)
	if warning:
		draw_arc(Vector2(44,-36),16+pulse*3,-1.6,1.6,20,Color(0.45,0.92,1.0,0.42+pulse*0.3),1.4,true)
		draw_line(Vector2(55,-19),Vector2(70,-19),Color(0.6,0.95,1.0,0.65),1.5,true)
	if striking:
		draw_line(Vector2(-67,-27),Vector2(-102,-27),Color(0.32,0.78,0.91,0.25),2.5,true)
		draw_line(Vector2(-53,-14),Vector2(-83,-14),Color(0.32,0.78,0.91,0.20),1.4,true)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
