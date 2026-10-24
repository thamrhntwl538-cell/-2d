extends "res://scripts/bosses/m23_boss_attack.gd"
## Only the moving resonance is dangerous; nothing is drawn before impact.
func _draw() -> void:
	if spent: return
	var fade := clampf(1.0-(age-active_seconds)/fade_seconds,0,1)
	var c := Color(1,.70,.30,fade)
	draw_arc(Vector2(0,8),20,PI,TAU,24,Color(.95,.55,.19,.28*fade),8,true)
	draw_arc(Vector2(0,8),20,PI,TAU,24,c,2.5,true)
	draw_line(Vector2(-22,5),Vector2(22,5),Color(1,.87,.54,.85*fade),2,true)
	for x in [-13,0,13]: draw_line(Vector2(x,3),Vector2(x+5,-4),Color(1,.80,.44,.5*fade),1.3,true)
