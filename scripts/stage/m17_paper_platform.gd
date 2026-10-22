@tool
extends StaticBody2D
## A thick, ink-edged book-page surface. y=0 is the art and collision top.
@export var width: float = 240.0:
	set(value):
		width = maxf(12.0, value)
		_refresh()
@export var depth: float = 58.0:
	set(value):
		depth = maxf(8.0, value)
		_refresh()
@export var support_height: float = 0.0:
	set(value):
		support_height = maxf(0.0, value)
		_refresh()
@export var one_way: bool = true:
	set(value):
		one_way = value
		_refresh()
@export var paper_tint := Color("d7c7a8"):
	set(value):
		paper_tint = value
		queue_redraw()
@export var ribbon: bool = true
const PAPER_TEXTURE_PATH := "res://assets/environments/folding_library/paper_platform.png"
static var _paper_texture: Texture2D
var collider: CollisionShape2D

func configure(rect: Rect2, pass_through: bool = true) -> void:
	position = rect.position
	width = rect.size.x
	depth = minf(rect.size.y, 66.0)
	support_height = maxf(0.0, rect.size.y-depth)
	one_way = pass_through

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	if _paper_texture == null and ResourceLoader.exists(PAPER_TEXTURE_PATH):
		_paper_texture = load(PAPER_TEXTURE_PATH) as Texture2D
	_sync_collision()
	queue_redraw()

func _refresh() -> void:
	queue_redraw()
	if is_inside_tree(): _sync_collision()

func _sync_collision() -> void:
	if not is_instance_valid(collider):
		collider = get_node_or_null("Collision") as CollisionShape2D
		if collider == null:
			collider = CollisionShape2D.new()
			collider.name = "Collision"
			add_child(collider)
	var box := RectangleShape2D.new()
	box.size = Vector2(width, depth+support_height)
	collider.shape = box
	collider.position = Vector2(width*0.5, (depth+support_height)*0.5)
	collider.one_way_collision = one_way
	collider.one_way_collision_margin = 7.0

func _draw() -> void:
	var total := depth+support_height
	if _paper_texture:
		_draw_painted_pages(total)
		return
	# Soft stacked silhouettes supply depth without a noisy rock texture.
	for shadow in range(5, 0, -1):
		draw_rect(Rect2(3.0+shadow, 7.0+shadow, width-1.0, total+2.0), Color(0.015,0.025,0.04,0.035))
	var cover := PackedVector2Array([Vector2(-3,4),Vector2(width+3,4),Vector2(width+2,total-1),Vector2(width-9,total+7),Vector2(9,total+7),Vector2(-3,total-1)])
	draw_colored_polygon(cover, Color("101e2b"))
	var paper := PackedVector2Array([Vector2(0,0),Vector2(width,0),Vector2(width,total-12),Vector2(width-12,total-5),Vector2(13,total-5),Vector2(0,total-13)])
	var bottom_tint := paper_tint.darkened(0.23)
	draw_polygon(paper, PackedColorArray([paper_tint.lightened(0.09),paper_tint.lightened(0.06),bottom_tint,bottom_tint,bottom_tint,paper_tint.darkened(0.09)]))
	var count := clampi(int(total/7.0), 3, 40)
	for n in range(count):
		var y := 7.0+float(n)*maxf(3.0,(total-17.0)/maxf(1.0,float(count-1)))
		var points := PackedVector2Array()
		for i in range(13):
			var u := float(i)/12.0
			points.append(Vector2(4.0+u*(width-8.0), y+sin(u*PI)*1.35+sin(u*TAU*2.0+n)*0.42))
		draw_polyline(points,Color(0.28,0.25,0.22,0.22 if n%3 else 0.34),0.8,true)
	# A continuous high-value lip makes every actual landing readable.
	draw_line(Vector2(0,0.7),Vector2(width,0.7),Color("eee1c6"),2.8,true)
	draw_line(Vector2(0,3.1),Vector2(width,3.1),Color("bbaa8d"),1.0,true)
	draw_line(Vector2(2,total-5),Vector2(width-2,total-5),Color("766c5b"),1.4,true)
	draw_line(Vector2(0,0),Vector2(0,total-12),Color(0.16,0.17,0.18,0.75),1.2,true)
	draw_line(Vector2(width,0),Vector2(width,total-12),Color(0.16,0.17,0.18,0.8),1.2,true)
	if width >= 170.0:
		var bands := maxi(1, int(width/640.0))
		for i in range(bands):
			var x := width*(float(i)+0.5)/float(bands)
			var band_width := minf(26.0,width*0.08)
			draw_rect(Rect2(x-band_width*0.5,total-4,band_width,10),Color("192736"))
			draw_line(Vector2(x-band_width*0.5,total+2),Vector2(x+band_width*0.5,total+2),Color("a98b54"),0.8,true)
	if ribbon and width>350.0:
		var rx := width*0.74
		var length := clampf(total*0.65,26.0,65.0)
		var cloth := PackedVector2Array([Vector2(rx-8,1),Vector2(rx+8,1),Vector2(rx+11,total+length),Vector2(rx+2,total+length-8),Vector2(rx-6,total+length+2)])
		draw_colored_polygon(cloth,Color("6d2936"))
		draw_polyline(PackedVector2Array([Vector2(rx-7,1),Vector2(rx-5,total+length)]),Color("a54a45"),1.3,true)
		draw_line(Vector2(rx-8,1),Vector2(rx+8,1),Color("d6ad77"),1.1,true)


func _draw_painted_pages(total: float) -> void:
	# Authored texture regions preserve brushwork; no physics or image files are
	# altered. Source y=275 is the straight landing lip, including the end caps.
	var tint := Color(0.94,0.93,0.91,1.0)
	for shadow in range(4,0,-1):
		draw_rect(Rect2(2+shadow,6+shadow,width,total),Color(0.015,0.025,0.04,0.03))
	var y := 0.0
	while y<total-0.1:
		var row := minf(72.0,total-y)
		var left_cap := minf(width/3.0,183.0/190.0*row)
		var right_cap := minf(width/3.0,205.0/190.0*row)
		draw_texture_rect_region(_paper_texture,Rect2(0,y,left_cap,row),Rect2(17,275,183,190),tint)
		draw_texture_rect_region(_paper_texture,Rect2(width-right_cap,y,right_cap,row),Rect2(1950,275,205,190),tint)
		var x := left_cap
		var section := 0
		while x<width-right_cap-0.1:
			var piece := minf(1750.0/190.0*row,width-right_cap-x)
			var sw := minf(1750.0,piece/row*190.0)
			var sx := 200.0+fposmod(float(section)*277.0,maxf(1.0,1750.0-sw))
			draw_texture_rect_region(_paper_texture,Rect2(x,y,piece,row),Rect2(sx,275,sw,190),tint)
			x += piece
			section += 1
		y += row
	draw_line(Vector2(0,0.5),Vector2(width,0.5),Color(0.96,0.89,0.73,0.50),1.0,true)
