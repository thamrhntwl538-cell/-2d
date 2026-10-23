extends Node2D
## Native M20 art study. Display loops are separate from playable action timing.
## All three pages instantiate the same model and parts used by the player.
const Model = preload("res://scripts/warden_model_m20.gd")
const FONT = preload("res://assets/fonts/DejaVuSans.ttf")
const FEET := Vector2(256,456)
const PAPER := Color("e9dfcb")
const GOLD := Color("d8ad72")
const MUTED := Color("9398ae")
const EXPRESSIONS := [
	{"id":"idle","en":"IDLE","ar":"الوقوف"},
	{"id":"look_up","en":"LOOK UP","ar":"النظر إلى الأعلى"},
	{"id":"look_down","en":"LOOK DOWN","ar":"النظر إلى الأسفل"},
	{"id":"alert","en":"ALERT","ar":"الانتباه"}
]
const ACTIONS := [
	{"id":"run","en":"RUN","ar":"الجري"},
	{"id":"air","en":"JUMP / FALL","ar":"القفز والهبوط"},
	{"id":"dash","en":"DASH","ar":"الاندفاع"},
	{"id":"heal","en":"FOCUS","ar":"العلاج"},
	{"id":"recoil","en":"HURT","ar":"تلقي الإصابة"},
	{"id":"death","en":"DEATH / RETURN","ar":"الموت والعودة"}
]
const SLASHES := [
	{"id":"slash","en":"FORWARD SLASH","ar":"ضربة أمامية"},
	{"id":"slash_up","en":"UPWARD SLASH","ar":"ضربة علوية"},
	{"id":"slash_down","en":"DOWNWARD SLASH","ar":"ضربة سفلية"}
]
var models: Array[Node2D] = []
var holders: Array[Node2D] = []
var card_labels: Array[Label] = []
var master: Node2D
var master_holder: Node2D
var master_label: Label
var master_scale_label: Label
var page_label: Label
var state_label: Label
var page: int = 0
var master_index: int = 0
var clock: float = 0.0
var playing: bool = true
var captured: bool = false
var capture_requested: bool = false

func _label(value: String, point: Vector2, area: Vector2, font_size: int = 16, ink: Color = PAPER, centered: bool = false) -> Label:
	var node := Label.new()
	node.text = value
	node.position = point
	node.size = area
	node.add_theme_font_override("font",FONT)
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",ink)
	node.text_direction = Control.TEXT_DIRECTION_AUTO
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node

func _make_model(at_feet: Vector2, display_scale: float) -> Array[Node2D]:
	var holder := Node2D.new()
	holder.position = at_feet
	holder.scale = Vector2.ONE*display_scale
	holder.set_meta("feet_y",at_feet.y)
	add_child(holder)
	var model := Model.new()
	model.position = -FEET
	holder.add_child(model)
	return [holder,model]

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0b1019"))
	_label("LAST LECTURE   /   THE LANTERN WARDEN",Vector2(34,23),Vector2(900,25),15,GOLD)
	_label("M20  /  THE SAME HERO, A CLEANER FLAME",Vector2(34,56),Vector2(1200,43),28,PAPER)
	_label("رسم أنعم، يدان واضحتان، وتعبيرات الفانوس المعتمدة",Vector2(34,104),Vector2(1200,28),18,MUTED)
	var made := _make_model(Vector2(230,540),1.0)
	master_holder = made[0]
	master = made[1]
	master_label = _label("",Vector2(53,565),Vector2(350,29),18,GOLD,true)
	master_scale_label = _label("",Vector2(50,606),Vector2(362,23),13,MUTED,true)
	_label("عرض مكبّر ووضعيات مصغّرة لفحص الرسم",Vector2(42,636),Vector2(390,23),12,MUTED,true)
	page_label = _label("",Vector2(455,124),Vector2(780,24),14,GOLD,true)
	state_label = _label("",Vector2(455,653),Vector2(770,23),13,MUTED,true)
	_label("TAB / 1 / 2 / 3  pages     ← / →  master pose     SPACE  pause     ESC  game",Vector2(34,684),Vector2(1210,24),14,MUTED,true)
	var arguments := OS.get_cmdline_user_args()
	capture_requested = "--capture-review" in arguments
	page = 1 if "--capture-actions" in arguments else 0
	if "--capture-slashes" in arguments: page = 2
	if "--capture-expressions" in arguments or "--expressions" in arguments: page = 0
	_build_page()

func _items() -> Array:
	return EXPRESSIONS if page==0 else (ACTIONS if page==1 else SLASHES)

func _card_rect(index: int) -> Rect2:
	var columns := 2 if page==0 else 3
	var column := index%columns
	var row: int = index/columns
	if page==0: return Rect2(455+column*395,154+row*244,380,236)
	if page==1: return Rect2(455+column*235,154+row*244,220,236)
	return Rect2(455+column*235,154,220,480)

func _fit_study(model: Node2D, holder: Node2D, kind: String, area: Rect2, maximum_scale: float) -> float:
	# Fit the entire artwork, including the fire crescent, once per selected pose.
	# Display zoom is labelled and never alters the playable actor's fixed scale.
	var bounds := Rect2(126,140,310,340)
	if kind=="air": bounds = Rect2(126,90,310,390)
	if kind in ["slash","slash_up","slash_down"]:
		for variant in [0,1]:
			model.slash_variant = variant
			for phase in [0.0,0.16,0.32,0.47,0.68,1.0]:
				model.set_combat_pose(kind,phase,kind=="slash_down",0)
				for point in model.arc_polygon: bounds = bounds.expand(point)
		bounds = bounds.grow(8)
	var fitted_scale := minf(maximum_scale,minf(area.size.x/bounds.size.x,area.size.y/bounds.size.y))
	holder.scale = Vector2.ONE*fitted_scale
	holder.position = area.position+(area.size-bounds.size*fitted_scale)*0.5-(bounds.position-FEET)*fitted_scale
	holder.set_meta("feet_y",holder.position.y)
	return fitted_scale

func _fit_master() -> void:
	var kind: String = _items()[master_index].id
	var fitted_scale := _fit_study(master,master_holder,kind,Rect2(58,170,344,370),1.0)
	master_scale_label.text = "STUDY SCALE %.2f  /  GAME SCALE 0.37" % fitted_scale
	queue_redraw()

func _build_page() -> void:
	for holder in holders: holder.queue_free()
	for label in card_labels: label.queue_free()
	models.clear()
	holders.clear()
	card_labels.clear()
	master_index = 0
	var items: Array = _items()
	page_label.text = ["1 / 3   EXPRESSIONS  ·  تعبيرات الفانوس","2 / 3   MOVEMENT  ·  الحركة والحالات","3 / 3   FIRE SLASHES  ·  ضربات السيف"][page]
	for index in range(items.size()):
		var rect := _card_rect(index)
		var center := rect.position+Vector2(rect.size.x*0.5,184 if page==0 else 172)
		var pair := _make_model(center,0.60 if page==0 else 0.50)
		holders.append(pair[0])
		models.append(pair[1])
		var label_origin := center+Vector2(-rect.size.x*0.5+8,8)
		if page==2:
			var fitted_scale := _fit_study(pair[1],pair[0],str(items[index].id),Rect2(rect.position+Vector2(12,28),rect.size-Vector2(24,88)),0.65)
			card_labels.append(_label("STUDY SCALE %.2f" % fitted_scale,rect.position+Vector2(8,7),Vector2(rect.size.x-16,18),11,MUTED,true))
			label_origin = rect.position+Vector2(8,rect.size.y-47)
		card_labels.append(_label(str(items[index].en),label_origin,Vector2(rect.size.x-16,19),14 if page==0 else 12,GOLD,true))
		card_labels.append(_label(str(items[index].ar),label_origin+Vector2(0,22),Vector2(rect.size.x-16,21),14 if page==0 else 12,MUTED,true))
	_fit_master()
	_update_poses()
	queue_redraw()

func _show_pose(model: Node2D, holder: Node2D, kind: String, large: bool = false) -> void:
	# Slow review loops inspect art; the playable actor drives actual combat timing.
	var phase := fposmod(clock*0.85,1.0)
	if capture_requested and clock>1.70:
		if kind in ["slash","slash_up","slash_down"]: phase = 0.32
		elif kind=="recoil": phase = 0.50
		elif kind=="death": phase = 0.94
	holder.position.y = float(holder.get_meta("feet_y"))
	model.sword_visible = kind in ["slash","slash_up","slash_down"]
	model.sword_reach = 1.0
	model.slash_variant = int(clock*0.85)%2 if kind=="slash" else 0
	if kind in ["slash","slash_up","slash_down","recoil","death"]:
		model.set_combat_pose(kind,phase,kind=="slash_down",clock)
	elif kind in ["run","dash"]:
		model.set_motion(kind,clock*13.0)
	elif kind=="air":
		model.set_motion("air",phase*7.0)
		holder.position.y -= sin(phase*PI)*(46.0 if large else 12.0)
	elif kind=="heal":
		model.set_motion("heal",fposmod(clock*0.7,1.0))
	else:
		model.set_motion("idle",fposmod(clock*0.6,1.0))
	model.set_expression(kind if kind in ["look_up","look_down","alert"] else "idle",1.0)

func _update_poses() -> void:
	if not is_instance_valid(master): return
	var items: Array = _items()
	_show_pose(master,master_holder,str(items[master_index].id),true)
	master_label.text = str(items[master_index].ar)+"  /  "+str(items[master_index].en)
	for index in range(models.size()):
		_show_pose(models[index],holders[index],str(items[index].id))
	state_label.text = ("PLAYING" if playing else "PAUSED")+"  ·  ONE HERO / SHARED PARTS  ·  معاينة الرسم"

func _process(delta: float) -> void:
	if playing: clock += delta
	_update_poses()
	if capture_requested and clock>1.75 and not captured:
		captured = true
		await RenderingServer.frame_post_draw
		var path: String = ["user://m20_hero_review.jpg","user://m20_hero_actions.jpg","user://m20_hero_slashes.jpg"][page]
		var result := get_viewport().get_texture().get_image().save_jpg(path,0.94)
		print("M20 HERO REVIEW capture=",result," page=",page," path=",ProjectSettings.globalize_path(path))
		if "--keep-review-open" not in OS.get_cmdline_user_args(): get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var count: int = _items().size()
	match event.keycode:
		KEY_SPACE: playing = not playing
		KEY_LEFT:
			master_index = posmod(master_index-1,count)
			_fit_master()
		KEY_RIGHT:
			master_index = posmod(master_index+1,count)
			_fit_master()
		KEY_TAB:
			page = (page+1)%3
			_build_page()
		KEY_1:
			page = 0
			_build_page()
		KEY_E:
			page = 0
			_build_page()
		KEY_2:
			page = 1
			_build_page()
		KEY_3:
			page = 2
			_build_page()
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
	_panel(Rect2(32,154,396,512))
	if is_instance_valid(master_holder) and _items()[master_index].id not in ["air","slash_down"]:
		var floor_y: float = master_holder.get_meta("feet_y")
		draw_line(Vector2(62,floor_y),Vector2(399,floor_y),Color("6a5841"),1.2,true)
	var count: int = _items().size()
	for index in range(count):
		var rect := _card_rect(index)
		_panel(rect)
		if page!=2:
			var floor_y := 184.0 if page==0 else 172.0
			draw_line(rect.position+Vector2(16,floor_y),rect.position+Vector2(rect.size.x-16,floor_y),Color("3b4050"),1,true)
