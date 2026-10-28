extends RefCounted
## A separate, atomic journey envelope joins a real vault encounter to its
## exploration checkpoint. It never touches the archived trial save files.
const SAVE_PATH := "user://folding_library_m28.json"
const SESSION_PATH := "user://archivist_journey_m28.json"
const WORLD_SCENE := "res://scenes/stage_01/folding_library_m28.tscn"
const ARCHIVE_SCENE := "res://scenes/minibosses/archivist_journey_m28.tscn"

static func atomic_write(path: String, record: Dictionary) -> bool:
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify(record,"\t"))
	file.flush()
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))==OK

static func read_session() -> Dictionary:
	if not FileAccess.file_exists(SESSION_PATH): return {}
	var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(SESSION_PATH))
	if not raw is Dictionary or int(raw.get("schema",0))!=28 or str(raw.get("boss",""))!="archivist": return {}
	if str(raw.get("status","")) not in ["entered","retreat","death","victory"]: return {}
	for key in ["progress","combat","origin","checkpoint"]:
		if not raw.get(key) is Dictionary: return {}
	for key in ["origin","checkpoint"]:
		var at: Dictionary=raw[key]
		if int(at.get("room",0))<1 or int(at.get("room",0))>15 or not valid_point(at.get("position")): return {}
	if int(raw.origin.room)!=6: return {}
	return raw

static func valid_point(raw: Variant) -> bool:
	if not raw is Array or raw.size()!=2: return false
	for value in raw:
		if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value))>100000: return false
	return true

static func checkpoint_record(session: Dictionary) -> Dictionary:
	return {"version":18,"environment_preview":true,"progress":session.progress,"checkpoint":session.checkpoint,"language":session.get("language","ar"),"combat":session.combat,"energy":session.get("energy",0.0),"journal_cursor":session.get("journal_cursor",{}),"journey_schema":28}

static func remove_session() -> void:
	if FileAccess.file_exists(SESSION_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
