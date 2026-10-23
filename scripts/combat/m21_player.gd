extends "res://scripts/combat/m20_player.gd"
## M20 hero preserved exactly; M21 adds eyes and a useful warm world light.
const EyeModel = preload("res://scripts/warden_model_m21.gd")
const LANTERN_LIGHT_SCALE := 7.5
const LANTERN_LIGHT_ENERGY := 1.05

func _ready() -> void:
	super._ready()
	var previous: Node2D = combat_model
	combat_container.remove_child(previous)
	previous.free()
	combat_container.name = "M21SingleHeroRig"
	combat_model = EyeModel.new()
	combat_model.position = Vector2(-256,-456)
	# The flame lights the world, while the approved hero palette stays readable.
	var self_lit := CanvasItemMaterial.new()
	self_lit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	combat_model.material = self_lit
	combat_container.add_child(combat_model)
	lantern_light.texture_scale = LANTERN_LIGHT_SCALE
	lantern_light.energy = LANTERN_LIGHT_ENERGY
	# World illumination must not spill into the HUD's separate canvas.
	lantern_light.range_layer_min = 0
	lantern_light.range_layer_max = 0
	blade_light.range_layer_min = 0
	blade_light.range_layer_max = 0
	_update_animation()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_instance_valid(lantern_light):
		lantern_light.energy = LANTERN_LIGHT_ENERGY+(0.12+sin(animation_age*13)*0.05 if healing else 0.0)
