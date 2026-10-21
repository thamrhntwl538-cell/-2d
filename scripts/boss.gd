extends Node2D
class_name LastLectureCompiler

var world_ref: Node
var hp: int = 42
var max_hp: int = 42
var phase: int = 1
var alive: bool = true
var frozen: bool = true
var age: float = 0.0
var attack_index: int = 0
var attack_timer: float = 1.0
var warning_timer: float = 0.0
var warning_attack: String = ""
var dash_time: float = 0.0
var transformation: float = 0.0
var hit_stagger: float = 0.0
var has_used_second_chance: bool = false
var flash: float = 0.0

func setup(game: Node) -> void:
	world_ref = game
	position = Vector2(1440,600)

func _process(delta: float) -> void:
	if not alive:return
	age+=delta
	flash=maxf(0,flash-delta)
	if frozen or not world_ref.gameplay_active:
		queue_redraw()
		return
	if transformation>0.0:
		transformation-=delta
		if transformation<=0:
			world_ref.show_tip("PHASE 2 — INFINITE LOOP")
			world_ref.change_boss_music(2)
		queue_redraw()
		return
	if hit_stagger>0.0:
		hit_stagger-=delta
		queue_redraw()
		return
	if dash_time>0.0:
		dash_time-=delta
		position.x+=(-1 if world_ref.hero.position.x<position.x else 1)*310*delta
	attack_timer-=delta
	if warning_timer>0.0:
		warning_timer-=delta
		if warning_timer<=0.0:
			perform_attack(warning_attack)
	elif attack_timer<=0.0:
		var attacks: Array = ["ERROR BOLT","SYNTAX BEAM","COMPILE DASH"] if phase==1 else ["ERROR STORM","INFINITE LOOP","GROUND CRASH","SYNTAX BEAM"]
		warning_attack = attacks[attack_index%attacks.size()]
		attack_index+=1
		warning_timer = 0.65 if phase==1 else .48
		attack_timer = 2.0 if phase==1 else 1.25
	position.x=clampf(position.x,820,1660)
	queue_redraw()

func perform_attack(kind: String) -> void:
	if not alive:return
	var hero: Node2D=world_ref.hero
	var dir: float=-1.0 if hero.position.x<position.x else 1.0
	match kind:
		"ERROR BOLT":
			for oy in [-40.0,-15.0,12.0]:
				world_ref.spawn_projectile(position+Vector2(dir*42,-95),Vector2(dir*360,oy*2),"error",1)
		"SYNTAX BEAM":
			world_ref.spawn_projectile(position+Vector2(dir*44,-65),Vector2(dir*660,0),"beam",1)
		"COMPILE DASH":
			dash_time=.65
			world_ref.emit_burst(position+Vector2(0,-35),Color("ff658a"),30)
		"ERROR STORM":
			for i in range(9):
				var angle: float=float(i)*TAU/9.0
				world_ref.spawn_projectile(position+Vector2(0,-85),Vector2(cos(angle),sin(angle))*340,"error",1)
		"INFINITE LOOP":
			for i in range(5):
				world_ref.spawn_projectile(position+Vector2(0,-95),Vector2(-1 if i%2==0 else 1,-.25*float(i))*300,"loop",1)
		"GROUND CRASH":
			world_ref.spawn_ground_warning(hero.position.x,130,0.80)
			world_ref.emit_burst(position+Vector2(0,-20),Color("fa547e"),35)
	world_ref.play_sfx("boss_attack")

func take_hit(amount: int) -> void:
	if not alive or frozen or transformation>0 or hit_stagger>0.0:return
	hp=maxi(0,hp-amount)
	flash=.20
	hit_stagger=.06
	world_ref.play_sfx("hit")
	world_ref.emit_burst(position+Vector2(0,-87),Color("ff5978"),15)
	if hp<=0:
		alive=false
		world_ref.on_boss_defeated()
	elif phase==1 and hp<=max_hp/2:
		phase=2
		transformation=2.8
		warning_timer=0.0
		attack_timer=.60
		world_ref.start_boss_transformation()

func get_hitbox() -> Rect2:
	return Rect2(position+Vector2(-48,-165),Vector2(95,160))

func _draw() -> void:
	var bob: float=sin(age*2.0)*4.0
	var purple: Color=Color("d99df8") if phase==2 else Color("f676a8")
	var black: Color=Color("201a30")
	draw_set_transform(Vector2(0,bob),0.0,Vector2.ONE)
	var cape:=PackedVector2Array([Vector2(-25,-130),Vector2(22,-134),Vector2(62,-30),Vector2(41,0),Vector2(-48,0),Vector2(-58,-36)])
	draw_colored_polygon(cape,black)
	draw_colored_polygon(PackedVector2Array([Vector2(-22,-128),Vector2(24,-134),Vector2(33,-31),Vector2(-26,-16)]),Color("4b293f"))
	draw_rect(Rect2(-25,-146,45,21),Color("283044"))
	draw_circle(Vector2(2,-151),19,Color("d3d0df"))
	draw_line(Vector2(-11,-159),Vector2(-24,-178),Color("9c9da9"),7)
	draw_circle(Vector2(-8,-153),3,purple)
	draw_circle(Vector2(9,-153),3,purple)
	draw_line(Vector2(19,-118),Vector2(49,-157),Color("808a9e"),8)
	draw_circle(Vector2(51,-161),11,purple)
	for i in range(6):
		var a:float=age*1.2+i*TAU/6.0
		var pos1:=Vector2(cos(a)*65,-92+sin(a)*42)
		draw_rect(Rect2(pos1-Vector2(6,4),Vector2(12,8)),purple.darkened(.45))
	if warning_timer>0.0:
		draw_arc(Vector2(0,-90),102,-2.2,.2,34,purple,5,true)
	if transformation>0:
		draw_arc(Vector2(0,-85),100,0,TAU,50,purple,6,true)
	if flash>0.0:
		draw_circle(Vector2(0,-100),48,Color(1,1,1,.27))
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
