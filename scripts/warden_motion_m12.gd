extends RefCounted
## Locomotion shares the same completed M12 model before/after collecting the blade.
const MOVEMENT = {
	"idle": [16, 8.0, true], "ready": [16, 8.0, true],
	"run": [24, 52.0, true], "stop": [6, 54.0, false],
	"jump": [15, 45.0, false], "fall": [6, 30.0, false],
	"land": [4, 36.0, false], "dash": [12, 36.0, false],
	"crouch": [4, 36.0, false]
}
const LEGACY_COMBAT = {
	"slash": [8, 23], "slash_follow": [6, 20], "slash_up": [8, 23],
	"slash_down": [8, 23], "parry": [7, 18], "recoil": [6, 15], "death": [9, 11]
}

static func build() -> SpriteFrames:
	var library := SpriteFrames.new()
	library.remove_animation("default")
	for prefix in ["unarmed_", "armed_"]:
		for movement in MOVEMENT:
			var name_value: String = prefix + movement
			var source: String = "idle" if movement == "ready" else ("land" if movement == "crouch" else movement)
			library.add_animation(name_value)
			library.set_animation_speed(name_value, MOVEMENT[movement][1])
			library.set_animation_loop(name_value, MOVEMENT[movement][2])
			for i in range(MOVEMENT[movement][0]):
				var path: String = "res://assets/warden_m12/%s_%02d.png" % [source, i]
				var texture: Texture2D = load(path)
				assert(texture != null, "M12 missing movement texture: " + path)
				library.add_frame(name_value, texture)
	# Slash and other combat artwork are preserved as the previous milestone.
	# They are explicitly outside the M12 locomotion review, pending the next art pass.
	for combat in LEGACY_COMBAT:
		library.add_animation(combat)
		library.set_animation_speed(combat, LEGACY_COMBAT[combat][1])
		library.set_animation_loop(combat, false)
		for i in range(LEGACY_COMBAT[combat][0]):
			library.add_frame(combat, load("res://assets/warden_clean/%s_%02d.png" % [combat, i]))
	return library
