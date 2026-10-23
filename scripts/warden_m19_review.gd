extends Node2D
## Native M19 character study. The gallery is separate from the playable world.
## All displayed poses use the same runtime model and the same source atlas.
const Model = preload("res://scripts/warden_model_m19.gd")
const FONT = preload("res://assets/fonts/DejaVuSans.ttf")
const FEET := Vector2(256,456)
const PAPER := Color("e9dfcb")
const GOLD := Color("d8ad72")
const MUTED := Color("9398ae")
const POSES := [
	{"id":"idle","en":"IDLE","ar":"الوقوف"},
	{"id":"run","en":"RUN","ar":"الجري"},
	{"id":"air","en":"JUMP / FALL","ar":"القفز والهبوط"},
	{"id":"slash","en":"FORWARD SLASH","ar":"ضربة أمامية"},
	{"id":"slash_up","en":"UPWARD SLASH","ar":"ضربة علوية"},
	{"id":"slash_down","en":"DOWNWARD SLASH","ar":"ضربة سفلية"},
	{"id":"heal","en":"FOCUS","ar":"العلاج"},
	{"id":"recoil","en":"HURT","ar":"تلقي الإصابة"},
	{"id":"death","en":"DEATH / RETURN","ar":"الموت والعودة"}
]
var models: Array[Node2D] = []
var holders: Array[Node2D] = []
var master: Node2D
var master_holder: Node2D
var master_index: int = 0
var master_label: Label
var state_label: Label
var clock: float = 0.0
var playing: bool = true
var _captured: bool = false

func _label(value: String, point: Vector2, area: Vector2, font_size: int = 16, color_value: Color = PAPER, centered: bool = false) -> Label:
	var node := Label.new()
	node.text = value
	node.position = point
	node.size = area
	node.add_theme_font_override("font",FONT)
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color_value)
	node.text_direction = Control.TEXT_DIRECTION_AUTO
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node

func _make_model(at_feet: Vector2, display_scale: float) -> Array[Node2D]:
	var holder := Node2D.new()
	holder.position = at_feet
	holder.scale = Vector2.ONE*display_scale
	add_child(holder)
	var model := Model.new()
	model.position = -FEET
	holder.add_child(model)
	return [holder,model]

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0b1019"))
	_label("LAST LECTURE   /   THE LANTERN WARDEN",Vector2(34,23),Vector2(900,25),15,GOLD)
	_label("M19  /  A SINGLE FLAME, ONE SHARED MODEL",Vector2(34,56),Vector2(1200,43),28,PAPER)
	_label("فانوس دافئ أكبر، جسم أقصر، وهيئة واحدة في جميع الحركات",Vector2(34,104),Vector2(1200,28),18,MUTED)
	var made := _make_model(Vector2(230,540),1.0)
	master_holder = made[0]
	master = made[1]
	master_label = _label("",Vector2(53,565),Vector2(350,29),18,GOLD,true)
	_label("GAME HEIGHT ≈104 px  /  DRAW SCALE 0.37",Vector2(50,606),Vector2(362,23),13,MUTED,true)
	_label("عرض مكبّر ووضعيات مصغّرة لفحص الرسم",Vector2(42,636),Vector2(390,23),12,MUTED,true)
	for index in range(POSES.size()):
		var column := index%3
		var row := index/3
		var center := Vector2(575+column*235,266+row*166)
		var pair := _make_model(center,0.32)
		holders.append(pair[0])
		models.append(pair[1])
		_label(str(POSES[index].en),center+Vector2(-104,8),Vector2(208,18),12,GOLD,true)
		_label(str(POSES[index].ar),center+Vector2(-104,27),Vector2(208,17),12,MUTED,true)
	state_label = _label("",Vector2(455,653),Vector2(770,23),13,MUTED,true)
	_label("SPACE  pause / resume     ← / →  master pose     ESC  return to game",Vector2(34,684),Vector2(1210,24),14,MUTED,true)
	_update_poses()
	queue_redraw()

func _show_pose(model: Node2D, holder: Node2D, kind: String, large: bool = false) -> void:
	# These are deliberately readable study loops, not combat timing measurements.
	var phase := fposmod(clock*0.85,1.0)
	holder.position.y = 540 if large else holder.get_meta("feet_y",holder.position.y)
	model.sword_visible = kind in ["slash","slash_up","slash_down"]
	model.sword_reach = 1.0
	if kind in ["slash","slash_up","slash_down","recoil","death"]:
		model.set_combat_pose(kind,phase,kind=="slash_down",clock)
	elif kind=="run":
		model.set_motion("run",clock*13.0)
	elif kind=="air":
		model.set_motion("air",phase*7.0)
		holder.position.y -= sin(phase*PI)*(46.0 if large else 12.0)
	elif kind=="heal":
		model.set_motion("heal",fposmod(clock*0.7,1.0))
	else:
		model.set_motion("idle",fposmod(clock*0.6,1.0))

func _update_poses() -> void:
	if not is_instance_valid(master): return
	_show_pose(master,master_holder,str(POSES[master_index].id),true)
	master_label.text = str(POSES[master_index].ar)+"  /  "+str(POSES[master_index].en)
	for index in range(models.size()):
		if not holders[index].has_meta("feet_y"): holders[index].set_meta("feet_y",holders[index].position.y)
		_show_pose(models[index],holders[index],str(POSES[index].id))
	state_label.text = ("PLAYING" if playing else "PAUSED")+"  ·  SAME ATLAS / PALETTE / LIMB LENGTHS  ·  معاينة هيكل الرسم"

func _process(delta: float) -> void:
	if playing: clock += delta
	_update_poses()
	if "--capture-review" in OS.get_cmdline_user_args() and clock>1.75 and not _captured:
		_captured = true
		await RenderingServer.frame_post_draw
		var result := get_viewport().get_texture().get_image().save_jpg("user://m19_hero_review.jpg",0.94)
		print("M19 HERO REVIEW capture=",result," path=",ProjectSettings.globalize_path("user://m19_hero_review.jpg"))
		if "--keep-review-open" not in OS.get_cmdline_user_args(): get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_SPACE: playing = not playing
		KEY_LEFT: master_index = posmod(master_index-1,POSES.size())
		KEY_RIGHT: master_index = posmod(master_index+1,POSES.size())
		KEY_ESCAPE:
			get_tree().change_scene_to_file(str(ProjectSettings.get_setting("application/run/main_scene")))
	_update_poses()
	get_viewport().set_input_as_handled()

func _panel(rect: Rect2) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111a28")
	style.border_color = Color("384050")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	draw_style_box(style,rect)

func _draw() -> void:
	_panel(Rect2(32,150,396,516))
	draw_line(Vector2(62,540),Vector2(399,540),Color("6a5841"),1.2,true)
	draw_line(Vector2(83,257),Vector2(83,540),Color("5a5144"),1,true)
	for y in [257,540]: draw_line(Vector2(77,y),Vector2(89,y),GOLD,1,true)
	for index in range(POSES.size()):
		var column := index%3
		var row := index/3
		var rect := Rect2(455+column*235,150+row*166,220,162)
		_panel(rect)
		draw_line(rect.position+Vector2(16,116),rect.position+Vector2(204,116),Color("3b4050"),1,true)
