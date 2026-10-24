extends "res://scripts/minibosses/m24_bell_character.gd"
## Combat adapter. The reviewed native character is also the gameplay character.
var actor:Node2D
var _last_state:=""
var _recover_from:=""

func _process(delta:float) -> void:
	if not is_instance_valid(actor):
		super._process(delta)
		return
	age=actor.age
	facing=actor.direction
	var state:String=actor.state
	if state!=_last_state:
		if state=="recover":_recover_from=_last_state
		_last_state=state
	var progress:=clampf(1.0-actor.state_time/maxf(.001,actor.state_duration),0,1)
	var name:=state
	match state:
		"dormant","intro","idle":name="idle"
		"walk":name="walk"
		"rush":name="rush"
		"air":name="jump" if actor.flight_velocity.y<0 else "fall"
		"high_air":name="high_jump" if actor.flight_velocity.y<0 else "high_fall"
		"spring":name="crouch"
		"resonance":
			var elapsed:float=actor.state_duration-actor.state_time
			name=("slam_land" if actor.phase>=2 else "land") if elapsed<.18 else "recover"
			progress=clampf(elapsed/.18,0,1) if elapsed<.18 else progress
		"recover":
			var elapsed:float=actor.state_duration-actor.state_time
			if _recover_from in ["rush","double_rush"] and elapsed<.16:
				name="slam_land" if _recover_from=="double_rush" else "land"
				progress=clampf(elapsed/.16,0,1)
		"stagger":name="hurt"
		"dead":name="death";progress=clampf(actor._death_age/.7,0,1)
	modulate=Color(1.25,1.15,1.02) if actor.hit_flash>0 else Color.WHITE
	set_pose(name,progress,actor.flight_velocity)
