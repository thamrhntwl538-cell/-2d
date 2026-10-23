extends "res://scripts/combat/m21_player.gd"
## Presentation-only body drive/short weapon plus collision from the same
## compact native flame shape. Approved art, movement and clocks are inherited.
const ModelM23 = preload("res://scripts/warden_model_m23.gd")

func _ready() -> void:
	super._ready()
	var previous: Node2D = combat_model
	combat_container.remove_child(previous)
	previous.free()
	combat_container.name = "M23CompactEmberHeroRig"
	combat_model = ModelM23.new()
	combat_model.position = Vector2(-256,-456)
	var self_lit := CanvasItemMaterial.new()
	self_lit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	combat_model.material = self_lit
	combat_container.add_child(combat_model)
	_update_animation()
