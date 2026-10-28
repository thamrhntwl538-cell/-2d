extends Node2D
## Native source/assembly comparison and reproducible anatomy fixtures.
const Character=preload("res://scripts/minibosses/m24_bell_character.gd")
const HeroModel=preload("res://scripts/warden_model_m21.gd")
const FONT=preload("res://assets/fonts/DejaVuSans.ttf")
var models:Array[Node2D]=[]
var content:Node2D
var page:="master"
var title:Label
var subtitle:Label
var mode:Label
var exploded:=false
var stable:=true
var labels:Array[Label]=[]

func label(text:String,pos:Vector2,area:Vector2,font_size:int) -> Label:
	var item:=Label.new()
	item.text=text;item.position=pos;item.size=area
	item.add_theme_font_override("font",FONT)
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",Color("e8dfcb"))
	item.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(item)
	return item

func character(pos:Vector2,zoom:float,face:int=-1,pose:String="idle",progress:float=0) -> Node2D:
	var model:=Character.new()
	model.position=pos;model.scale=Vector2.ONE*zoom;model.facing=face
	model.breathing=not stable
	model.set_pose(pose,progress)
	content.add_child(model);models.append(model)
	return model

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("101722"))
	set_page(page)

func set_page(value:String) -> void:
	page=value
	if is_instance_valid(content):
		remove_child(content)
		content.queue_free()
	content=Node2D.new();add_child(content)
	models.clear();labels.clear()
	title=label("حارس الجرس · مراجعة الشخصية",Vector2(40,20),Vector2(1200,44),29)
	subtitle=label("أجزاء أصلية ثابتة الحجم · مفاصل بطول ثابت · بطل اللعبة دون تعديل",Vector2(40,68),Vector2(1200,32),16)
	match page:
		"master":
			var master:=character(Vector2(340,620),2.4)
			master.use_master=true
			character(Vector2(930,620),2.4)
			label("الصورة المرجعية الكاملة",Vector2(80,117),Vector2(500,32),20)
			label("التجميع الأصلي داخل Godot",Vector2(680,117),Vector2(500,32),20)
			mode=label("نفس ميل الجرس، الحلقة، العين الواحدة، الوشاح الطويل والرجلين الممتلئتين",Vector2(30,662),Vector2(1220,35),17)
		"parts":
			character(Vector2(330,620),2.25)
			var model:=character(Vector2(920,540),1.8)
			model.exploded=true;model.guides=true
			label("الشخصية مجمّعة",Vector2(70,115),Vector2(500,32),20)
			label("الجرس · الجذع والوشاح · الرجل القريبة · الرجل البعيدة",Vector2(640,112),Vector2(580,40),16)
			mode=label("الأجزاء منفصلة في الرسم فقط؛ تفاصيل المصدر ونِسَبه محفوظة",Vector2(30,663),Vector2(1220,35),17)
		"scale":
			character(Vector2(615,620),2.25)
			character(Vector2(1040,620),2.25,1)
			var holder:=Node2D.new()
			holder.position=Vector2(170,620)
			holder.scale=Vector2.ONE*.37*2.25
			content.add_child(holder)
			var hero:=HeroModel.new()
			hero.position=Vector2(-256,-456)
			var unlit:=CanvasItemMaterial.new();unlit.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
			hero.material=unlit;holder.add_child(hero)
			hero.set_combat_pose("idle",0,false,0,false)
			label("البطل · 104 px",Vector2(35,126),Vector2(270,32),20)
			label("الحارس · 194 px",Vector2(400,126),Vector2(400,32),20)
			label("الاتجاه المقابل",Vector2(850,126),Vector2(350,32),20)
			mode=label("القدمان على نفس مستوى الأرض · حجم البطل ورسومه محفوظان",Vector2(30,662),Vector2(1220,35),17)
		"motion":
			var poses:Array=[
				["idle",0.0,"وقوف"],["walk",.25,"مشي"],["run",.25,"ركض"],["crouch",1.0,"انثناء قبل القفز"],
				["jump",.25,"صعود"],["fall",.75,"هبوط"],["land",.15,"ارتكاز بعد الهبوط"],["death",1.0,"سقوط"]]
			for index in poses.size():
				var data:Array=poses[index]
				var col:=index%4
				var row:=index/4
				var pos:=Vector2(160+col*320,352+row*296)
				var model:=character(pos,1.12,-1,data[0],data[1])
				model.guides=false
				label(data[2],pos+Vector2(-140,8),Vector2(280,30),17)
			mode=label("لا تمديد للرجلين أو الجرس أثناء الحركة",Vector2(30,687),Vector2(1220,28),14)
	mode.position.y=658
	mode.size.y=28
	label("1 المرجع · 2 الأجزاء · 3 المقاسات · 4 الحركة · Enter / A تجربة الجرس",Vector2(30,691),Vector2(1220,27),14)
	queue_redraw()

func set_exploded(value:bool) -> void:
	exploded=value
	set_page("parts" if value else "master")

func _unhandled_input(event:InputEvent) -> void:
	if get_tree().has_meta("m28_studio_return"):
		if (event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE) or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_BACK):
			get_tree().change_scene_to_file("res://scenes/minibosses/archivist_reference_m26.tscn")
			return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER,KEY_KP_ENTER:_start_trial()
			KEY_1:set_page("master")
			KEY_2,KEY_TAB:set_page("parts" if page!="parts" else "master")
			KEY_3:set_page("scale")
			KEY_4:set_page("motion")
			KEY_SPACE:
				stable=not stable
				for model in models:model.breathing=not stable
			KEY_G:
				for model in models:model.guides=not model.guides
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_A:_start_trial()
		elif event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_DPAD_LEFT]:_next_page(-1)
		elif event.button_index in [JOY_BUTTON_RIGHT_SHOULDER,JOY_BUTTON_DPAD_RIGHT]:_next_page(1)

func _next_page(direction:int) -> void:
	var pages: Array[String]=["master","parts","scale","motion"]
	set_page(pages[posmod(pages.find(page)+direction,pages.size())])

func _start_trial() -> void:
	get_tree().change_scene_to_file("res://scenes/minibosses/bell_trial_m24.tscn")

func _draw() -> void:
	draw_rect(Rect2(24,109,1232,543),Color("141f2b"))
	if page=="motion":
		for y in [354,650]:draw_line(Vector2(30,y),Vector2(1250,y),Color("6d6254"),1.0,true)
		for x in [320,640,960]:draw_line(Vector2(x,112),Vector2(x,680),Color(.70,.72,.78,.12),1,true)
	else:
		draw_line(Vector2(30,622),Vector2(1250,622),Color("6d6254"),1.3,true)
		if page in ["master","parts"]:draw_line(Vector2(630,115),Vector2(630,650),Color(.70,.72,.78,.15),1,true)
