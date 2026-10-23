extends "res://scripts/ui/m18_hud.gd"
## Keep the accepted combat HUD; identify this hero presentation milestone.
func _layout_combat_header() -> void:
	super._layout_combat_header()
	if is_instance_valid(status_label):
		status_label.text = "M20 · بطل الفانوس" if language=="ar" else "M20 · Lantern Warden"
