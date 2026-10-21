extends Node2D

# Preview independent of combat/world: run this scene with F6.
# Blue horizontal guide is the shared feet line. All frames have same logical anchor.
const COUNTS := {
	"unarmed_idle": 1,
	"unarmed_run": 10,
	"unarmed_jump": 5,
	"unarmed_fall": 5,
	"unarmed_land": 5,
	"armed_idle": 1,
	"armed_ready": 1,
	"armed_run": 10,
	"armed_jump": 5,
	"armed_fall": 5,
	"armed_land": 5,
	"armed_dash": 6,
	"armed_crouch": 5,
	"slash": 8,
	"slash_follow": 6,
	"slash_up": 8,
	"slash_down": 8,
	"parry": 7,
	"recoil": 6,
	"death": 9
}
const FPS := {
	"unarmed_idle": 9,
	"unarmed_run": 12,
	"unarmed_jump": 15,
	"unarmed_fall": 15,
	"unarmed_land": 15,
	"armed_idle": 9,
	"armed_ready": 9,
	"armed_run": 12,
	"armed_jump": 15,
	"armed_fall": 15,
	"armed_land": 15,
	"armed_dash": 18,
	"armed_crouch": 15,
	"slash": 23,
	"slash_follow": 20,
	"slash_up": 23,
	"slash_down": 23,
	"parry": 18,
	"recoil": 15,
	"death": 11
}
var sprite: AnimatedSprite2D
var header: Label
var info: Label
var selected: int = 0
var equipped: bool = false
var speed_multiplier: float = 1.0
var unarmed_names: Array[String] = ["unarmed_idle", "unarmed_run", "unarmed_jump", "unarmed_fall", "unarmed_land"]
var armed_names: Array[String] = ["armed_ready", "armed_run", "armed_jump", "armed_fall", "armed_land", "armed_dash", "armed_crouch", "slash", "slash_follow", "slash_up", "slash_down", "parry", "recoil", "death"]

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("0e1722")
	background.size = Vector2(1280,720)
	add_child(background)
	var ground := ColorRect.new()
	ground.color = Color("263a4b")
	ground.position = Vector2(0,620)
	ground.size = Vector2(1280,100)
	add_child(ground)
	var baseline := Line2D.new()
	baseline.points = PackedVector2Array([Vector2(0,620),Vector2(1280,620)])
	baseline.width = 2.0
	baseline.default_color = Color("69cbef")
	add_child(baseline)
	sprite = AnimatedSprite2D.new()
	sprite.name = "CleanMotionLanternWarden"
	sprite.position = Vector2(640.0,620.0 + (256.0 - 456.0) * 0.84)
	sprite.scale = Vector2.ONE * 0.84
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var frames := SpriteFrames.new()
	for label in COUNTS.keys():
		var anim: String = str(label)
		frames.add_animation(anim)
		frames.set_animation_speed(anim,float(FPS[anim]))
		frames.set_animation_loop(anim,anim in ["unarmed_idle","unarmed_run","armed_idle","armed_ready","armed_run"])
		if anim in ["unarmed_idle", "armed_idle", "armed_ready"]:
			frames.add_frame(anim,load("res://assets/warden_m09_whole_body/unarmed_idle.png" if anim == "unarmed_idle" else "res://assets/warden_m09_whole_body/sheathed_idle.png"))
			frames.set_animation_speed(anim,1.0)
			continue
		if anim in ["unarmed_run", "armed_run"]:
			for idx in range(6):
				frames.add_frame(anim,load("res://assets/warden_run_m02/run_%02d.png" % idx))
		else:
			for idx in range(int(COUNTS[anim])):
				frames.add_frame(anim,load("res://assets/warden_clean/%s_%02d.png" % [anim,idx]))
	sprite.sprite_frames = frames
	add_child(sprite)
	var title := Label.new()
	title.position = Vector2(60,35)
	title.text = "LAST LECTURE  /  THE LANTERN WARDEN  /  ANIMATION TEST LAB"
	title.add_theme_font_size_override("font_size",26)
	add_child(title)
	header = Label.new()
	header.position = Vector2(60,95)
	header.add_theme_font_size_override("font_size",21)
	add_child(header)
	info = Label.new()
	info.position = Vector2(60,670)
	info.add_theme_font_size_override("font_size",17)
	info.text = "LEFT/RIGHT: state   |   B: sword pickup toggle   |   SPACE: replay   |   F: face left/right   |   +/-: speed"
	add_child(info)
	_show_selected()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_RIGHT:
		selected = (selected + 1) % _state_list().size()
		_show_selected()
	elif event.keycode == KEY_LEFT:
		selected = (selected - 1 + _state_list().size()) % _state_list().size()
		_show_selected()
	elif event.keycode == KEY_B:
		equipped = not equipped
		selected = 0
		_show_selected()
	elif event.keycode == KEY_F:
		sprite.flip_h = not sprite.flip_h
	elif event.keycode == KEY_SPACE:
		sprite.set_frame_and_progress(0,0.0)
		sprite.play()
	elif event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD:
		speed_multiplier = minf(2.0,speed_multiplier+0.2)
		_show_selected()
	elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
		speed_multiplier = maxf(0.4,speed_multiplier-0.2)
		_show_selected()

func _state_list() -> Array[String]:
	return armed_names if equipped else unarmed_names

func _show_selected() -> void:
	var anim: String = _state_list()[selected]
	sprite.play(anim)
	sprite.set_frame_and_progress(0,0.0)
	sprite.speed_scale = speed_multiplier
	header.text = "%s  |  %s  |  %d frames  |  %.1fx  |  weapon: %s" % ["After pickup" if equipped else "Before pickup", anim.to_upper(), int(COUNTS[anim]),speed_multiplier, "EQUIPPED" if equipped else "LOCKED"]
