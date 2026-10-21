extends Node2D
class_name LastLectureEnemy

var world_ref: Node
var enemy_kind: String = "bug"
var hp: int = 4
var max_hp: int = 4
var home: Vector2 = Vector2.ZERO
var direction: int = -1
var age: float = 0.0
var fire_cooldown: float = 0.6
var rush_time: float = 0.0
var windup: float = 0.0
var invulnerable: float = 0.0
var death_time: float = 0.0
var is_dead: bool = false
var move_rate: float = 70.0

func setup(kind: String, start_pos: Vector2, game: Node) -> void:
	enemy_kind = kind
	world_ref = game
	position = start_pos
	home = start_pos
	hp = {"bug":3,"wraith":4,"ta":8,"turret":7}.get(kind,4)
	max_hp = hp
	move_rate = {"bug":87.0,"wraith":62.0,"ta":46.0,"turret":0.0}.get(kind,60.0)
	fire_cooldown = randf_range(.9,1.7)

func _process(delta: float) -> void:
	age += delta
	if is_dead:
		death_time += delta
		modulate.a = maxf(0.0, 1.0-death_time*3.5)
		if death_time > .32:
			queue_free()
		queue_redraw()
		return
	if not world_ref.gameplay_active:
		queue_redraw()
		return
	fire_cooldown -= delta
	invulnerable = maxf(0.0,invulnerable-delta)
	var hero: Node2D = world_ref.hero
	var dx: float = hero.global_position.x-global_position.x
	direction = 1 if dx > 0 else -1
	if enemy_kind == "bug":
		if absf(dx) < 310.0:
			position.x += direction*move_rate*delta*(2.35 if rush_time>0 else 1.0)
		if fire_cooldown<=0.0 and absf(dx)<220:
			rush_time = .28
			fire_cooldown=2.25
		rush_time=maxf(0.0,rush_time-delta)
	elif enemy_kind=="wraith":
		position.y = home.y + sin(age*2.7)*18.0
		position.x += clampf(dx,-1.0,1.0)*move_rate*delta
		if fire_cooldown<=0.0 and absf(dx)<540:
			world_ref.spawn_projectile(position+Vector2(direction*25,-5), Vector2(direction*310,0),"wraith",1)
			fire_cooldown=2.05
	elif enemy_kind=="ta":
		if absf(dx)>88.0 and absf(dx)<350.0:
			position.x+=direction*move_rate*delta
		if fire_cooldown<=0.0 and absf(dx)<125:
			windup=.46
			fire_cooldown=2.5
	elif enemy_kind=="turret":
		if fire_cooldown<=0.0 and absf(dx)<720:
			for oy in [-12.0,9.0]:
				world_ref.spawn_projectile(position+Vector2(direction*30,oy-22),Vector2(direction*390,randf_range(-20,20)),"turret",1)
			fire_cooldown=2.1
	if windup>0.0:
		windup-=delta
		if windup<=0.0:
			world_ref.enemy_melee(position+Vector2(direction*48,-34),55.0,2 if enemy_kind=="ta" else 1)
			world_ref.emit_burst(position+Vector2(direction*42,-30),Color("f8729a"),15)
	if hero.global_position.distance_to(global_position+Vector2(0,-22)) < (36.0 if enemy_kind=="bug" else 41.0):
		hero.hurt(2 if enemy_kind=="ta" else 1,global_position.x)
	position.x = clampf(position.x,30.0,1765.0)
	queue_redraw()

func get_hitbox() -> Rect2:
	var sz: Vector2 = {"bug":Vector2(60,45),"wraith":Vector2(62,74),"ta":Vector2(66,104),"turret":Vector2(66,74)}.get(enemy_kind,Vector2(60,70))
	return Rect2(global_position+Vector2(-sz.x/2,-sz.y),sz)

func take_hit(amount: int, from_x: float) -> void:
	if is_dead or invulnerable>0.0:
		return
	hp-=amount
	invulnerable=.12
	world_ref.play_sfx("hit")
	world_ref.emit_burst(global_position+Vector2(0,-34),Color("ff658c"),10)
	position.x += 20.0 if from_x < position.x else -20.0
	if hp<=0:
		is_dead=true
		world_ref.on_enemy_defeated(self)

func _draw() -> void:
	var glow_color: Color = Color("ff8aa5")
	var ybob: float = sin(age*5.0)*3.0
	draw_set_transform(Vector2(0,ybob),0.0,Vector2(float(direction),1.0))
	match enemy_kind:
		"bug":
			_draw_filled_ellipse(Vector2(0,-20), 26,18,Color("291d37"))
			for leg in [-1,1]:
				for i in range(3):
					draw_line(Vector2(i*11-9,-16),Vector2(i*15-19,-2+leg*5),Color("866077"),3.0)
			draw_circle(Vector2(16,-24),5,glow_color)
		"wraith":
			var shape:=PackedVector2Array([Vector2(-21,-61),Vector2(0,-81),Vector2(24,-59),Vector2(17,-22),Vector2(5,-6),Vector2(-5,-22),Vector2(-17,-10)])
			draw_colored_polygon(shape,Color("332840cc"))
			draw_circle(Vector2(-7,-59),4,glow_color)
			draw_circle(Vector2(8,-59),4,glow_color)
			draw_arc(Vector2(1,-43),25,-.4,2.2,13,Color("a785d4"),2.0)
		"ta":
			draw_rect(Rect2(-22,-85,44,70),Color("57495b"))
			draw_rect(Rect2(-16,-103,30,25),Color("1b2131"))
			draw_circle(Vector2(7,-93),4,Color("ff4e72"))
			draw_line(Vector2(16,-67),Vector2(43,-22),Color("c6aacb"),6.0)
			draw_rect(Rect2(-15,-13,12,13),Color("11121d"))
			draw_rect(Rect2(6,-13,12,13),Color("11121d"))
		"turret":
			draw_rect(Rect2(-26,-67,52,59),Color("3b354d"))
			draw_rect(Rect2(-31,-53,62,9),Color("8f6baf"))
			draw_circle(Vector2(10,-51),10,glow_color)
			draw_line(Vector2(21,-51),Vector2(45,-51),Color("c67eb0"),8.0)
	if windup>0:
		draw_arc(Vector2(0,-43),54,-2.0,-.15,24,Color("ff507c"),5.0)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
	if hp<max_hp:
		draw_rect(Rect2(-32,-116,64,5),Color("271b2d"))
		draw_rect(Rect2(-32,-116,64.0*float(hp)/float(max_hp),5),Color("fd698e"))

func _draw_filled_ellipse(center: Vector2, radius_x: float, radius_y: float, color: Color) -> void:
	var pts:=PackedVector2Array()
	for i in range(20):
		var a:=TAU*float(i)/20.0
		pts.append(center+Vector2(cos(a)*radius_x,sin(a)*radius_y))
	draw_colored_polygon(pts,color)
