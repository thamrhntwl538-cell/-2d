extends "res://scripts/audio/m23_soundscape.gd"
func setup(world: Node) -> void:
	super.setup(world)
	var path := "res://assets/audio/m24/events.json"
	if FileAccess.file_exists(path):
		var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary: _events.merge(data.get("events",{}),true)
