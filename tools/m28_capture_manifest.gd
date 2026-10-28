extends RefCounted
## Optional release manifest supplied by the release builder. The manifest is
## only a list of project resource paths; it contains no credentials or saves.
const DEFAULT_MANIFEST := "/workspace/work/m28_release/runtime_paths.json"

static func hashes(fallback: Array) -> Dictionary:
	var manifest:=DEFAULT_MANIFEST
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--runtime-manifest="): manifest=argument.trim_prefix("--runtime-manifest=")
	var paths: Array=fallback.duplicate()
	if FileAccess.file_exists(manifest):
		var decoded: Variant=JSON.parse_string(FileAccess.get_file_as_string(manifest))
		if decoded is Array: paths=decoded
		elif decoded is Dictionary and decoded.get("paths") is Array: paths=decoded.paths
	paths=paths.duplicate()
	paths.append_array(["tools/m28_capture_manifest.gd","tools/capture_m28_world.gd","tools/capture_m28_movement.gd"])
	var result: Dictionary={}
	for entry in paths:
		var path: String=str(entry.get("path","")) if entry is Dictionary else str(entry)
		path=path.trim_prefix("res://")
		if path.is_empty() or path.begins_with("/") or path.contains("..") or path.ends_with(".import") or path.ends_with(".uid"): continue
		if FileAccess.file_exists("res://"+path): result[path]=FileAccess.get_sha256("res://"+path)
	return result
