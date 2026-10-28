extends "res://scripts/stage/m22_foreground.gd"
## Broader paper silhouettes frame the camera while preserving every true lip.
func _draw() -> void:
	super._draw()
	if definition.is_empty(): return
	# Near bindings are placed below the top face, never over a takeoff edge.
	for item in definition.get("platforms",[]):
		if not _active(item): continue
		var r: Rect2=item.rect
		if r.size.x<600 or r.size.y<50 or not visible_world.intersects(r.grow(70)): continue
		var seed_value:=int(definition.id)*71+int(r.position.y)
		for i in range(1+int(r.size.x/750)):
			var x:=r.position.x+190+float(i)*705+float(posmod(seed_value,75))
			if x+130>r.end.x-10: continue
			_closed_volumes(Vector2(x,r.position.y+minf(r.size.y-5,75)),122,minf(r.size.y-26,47),seed_value+i)
