extends SceneTree
## Isolated native-engine tests of the stable application-name save migration.
## Run with XDG_DATA_HOME containing "m16_migration_qa"; existing fixture files
## are backed up and restored. No real user save directory is accepted.
const Controller = preload("res://scripts/stage/forgotten_wing.gd")
const SAVE := "user://forgotten_wing_m15.json"
const MARKER := "user://m15_save_migration.done"
var legacy_path: String
var failures: Array[String] = []
var scenarios: Array[Dictionary] = []
var originals: Dictionary = {}
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
		print("M16 MIGRATION FAILURE: ",message)
	return condition

func write_text(path: String, contents: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var handle := FileAccess.open(path,FileAccess.WRITE)
	if check(handle!=null,"Cannot write isolated fixture "+path): handle.store_string(contents)

func clear_fixtures() -> void:
	for path in paths:
		if FileAccess.file_exists(path): check(DirAccess.remove_absolute(path)==OK,"Cannot remove isolated fixture "+path)

func snapshot_files() -> void:
	for path in paths:
		originals[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null

func restore_files() -> void:
	clear_fixtures()
	for path in paths:
		if originals[path] is String: write_text(path,originals[path])

func restore_subject() -> Node2D:
	# This invokes the same startup persistence path used by _ready(), without
	# building visual assets or unrelated room/gameplay nodes.
	var subject: Node2D = Controller.new()
	subject._restore_save()
	return subject

func add_result(name_value: String, prior_failures: int, evidence: Dictionary) -> void:
	evidence.name = name_value
	evidence.passed = failures.size()==prior_failures
	scenarios.append(evidence)
	print("M16 MIGRATION ",name_value," ","PASS" if evidence.passed else "FAIL")

func valid_legacy() -> String:
	return JSON.stringify({"version":15,"progress":{"entrance_access":true,"input":true,"process":false,"output":false,"puzzle_complete":false,"archive_shortcut":true,"archive_secret":false,"compiler_seal":false,"boss_defeated":false,"encounters":{},"notes":["legacy_note"],"visited":[0,1,2,3,4]},"checkpoint":{"room":4,"position":[500,1260]}},"\t")

func run_checks() -> void:
	var task_data_root := OS.get_environment("XDG_DATA_HOME")
	if not task_data_root.contains("m16_migration_qa"):
		push_error("Refusing save fixtures outside an explicit m16_migration_qa XDG_DATA_HOME")
		quit(1)
		return
	check(str(ProjectSettings.get_setting("application/config/name"))=="LAST LECTURE — The Forgotten Programming Wing","Project application name is not stable")
	legacy_path = OS.get_user_data_dir().get_base_dir().path_join("LAST LECTURE — M15 The Forgotten Programming Wing").path_join("forgotten_wing_m15.json")
	paths = [ProjectSettings.globalize_path(SAVE),ProjectSettings.globalize_path(MARKER),legacy_path]
	snapshot_files()
	var legacy := valid_legacy()

	# A genuine old-name save is copied exactly, then restored through the
	# controller's real startup method. The old source remains untouched.
	clear_fixtures()
	write_text(legacy_path,legacy)
	var count_before: int = failures.size()
	var subject := restore_subject()
	check(FileAccess.file_exists(SAVE) and FileAccess.get_file_as_string(SAVE)==legacy,"Valid legacy save was not copied exactly")
	check(FileAccess.file_exists(MARKER),"Successful migration did not create its attempt marker")
	check(subject.progress.input and subject.progress.archive_shortcut and subject.progress.notes.has("legacy_note"),"Copied legacy progress was not restored")
	check(int(subject.checkpoint.room)==4 and subject.checkpoint.position==[500.0,1260.0],"Copied checkpoint was not restored")
	check(FileAccess.get_file_as_string(legacy_path)==legacy,"Migration modified the legacy source file")
	add_result("valid_legacy_migrates_and_restores",count_before,{"copied_byte_for_byte":FileAccess.get_file_as_string(SAVE)==legacy,"legacy_source_unchanged":FileAccess.get_file_as_string(legacy_path)==legacy,"restored_room":subject.checkpoint.room})
	subject.free()

	# Begin again deletes the active save and keeps this marker. Repeating the
	# startup migration must leave a genuine reset rather than resurrect M15.
	count_before = failures.size()
	DirAccess.remove_absolute(SAVE)
	subject = restore_subject()
	check(not FileAccess.file_exists(SAVE),"Reset re-imported the old M15 save despite its marker")
	check(not subject.progress.input and subject.progress.notes.is_empty(),"Reset retained imported legacy progress")
	check(FileAccess.file_exists(MARKER) and FileAccess.get_file_as_string(legacy_path)==legacy,"Reset removed its marker or altered the old source")
	add_result("begin_again_marker_prevents_reimport",count_before,{"active_save_absent":not FileAccess.file_exists(SAVE),"legacy_source_unchanged":FileAccess.get_file_as_string(legacy_path)==legacy,"reset_method":"same active-save deletion used by Begin again; startup restore repeated"})
	subject.free()

	# Broken JSON and a wrong-version object are rejected independently. Neither
	# should poison the stable save slot or destroy the original source evidence.
	for bad_case in [{"name":"malformed_legacy_json","contents":"{\"version\":15,\"progress\":"},{"name":"unsupported_legacy_version","contents":"{\"version\":14,\"progress\":{}}"}]:
		clear_fixtures()
		write_text(legacy_path,bad_case.contents)
		count_before = failures.size()
		subject = restore_subject()
		check(not FileAccess.file_exists(SAVE),bad_case.name+" was copied into the active slot")
		check(not subject.progress.input and subject.progress.notes.is_empty(),bad_case.name+" changed in-memory progress")
		check(FileAccess.file_exists(MARKER),bad_case.name+" did not mark its attempted migration")
		check(FileAccess.get_file_as_string(legacy_path)==bad_case.contents,bad_case.name+" altered the original source")
		add_result(bad_case.name,count_before,{"active_save_absent":not FileAccess.file_exists(SAVE),"legacy_source_unchanged":FileAccess.get_file_as_string(legacy_path)==bad_case.contents})
		subject.free()

	# A valid stable-name save takes precedence over conflicting legacy progress.
	clear_fixtures()
	write_text(legacy_path,legacy)
	var newer := JSON.stringify({"version":15,"progress":{"input":false,"notes":["new_saved_note"],"visited":[0]},"checkpoint":{"room":0,"position":[440,1260]}},"\t")
	write_text(ProjectSettings.globalize_path(SAVE),newer)
	count_before = failures.size()
	subject = restore_subject()
	check(FileAccess.get_file_as_string(SAVE)==newer,"Existing stable-name save was overwritten by migration")
	check(not subject.progress.input and subject.progress.notes.has("new_saved_note") and not subject.progress.notes.has("legacy_note"),"Legacy state displaced an existing stable save")
	check(FileAccess.file_exists(MARKER),"Existing stable save did not mark migration complete")
	check(FileAccess.get_file_as_string(legacy_path)==legacy,"Existing-save migration altered legacy source")
	add_result("existing_stable_save_takes_precedence",count_before,{"active_save_unchanged":FileAccess.get_file_as_string(SAVE)==newer,"restored_room":subject.checkpoint.room,"legacy_source_unchanged":FileAccess.get_file_as_string(legacy_path)==legacy})
	subject.free()

	# First launch without an old save is also a completed migration attempt;
	# a later unrelated file appearing in the old slot must not undo a reset.
	clear_fixtures()
	count_before = failures.size()
	subject = restore_subject()
	check(FileAccess.file_exists(MARKER) and not FileAccess.file_exists(SAVE),"No-legacy first launch did not leave an empty marked slot")
	subject.free()
	write_text(legacy_path,legacy)
	subject = restore_subject()
	check(not FileAccess.file_exists(SAVE) and not subject.progress.input,"Completed no-legacy attempt later imported an unrelated old save")
	add_result("empty_first_launch_is_not_retried",count_before,{"active_save_absent":not FileAccess.file_exists(SAVE),"legacy_source_unchanged":FileAccess.get_file_as_string(legacy_path)==legacy})
	subject.free()

	restore_files()
	var report := {"passed":failures.is_empty(),"godot":Engine.get_version_info().string,"scenario_count":scenarios.size(),"scenarios":scenarios,"failures":failures,"isolated_data_root":task_data_root,"source_save_read_only":true,"original_fixture_files_restored":true,"method":"Real controller startup _restore_save() and migration methods, using isolated old/stable application save directories. No scene geometry or progression injection is involved.","limitations":["Begin again is represented by the same active-save deletion and subsequent startup restore; this narrow migration test does not click the menu UI.","These checks cover application-name migration and valid/invalid JSON/version precedence, not recovery from arbitrary malformed nested gameplay state."]}
	FileAccess.open("res://M16_SAVE_MIGRATION_QA.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("M16 SAVE MIGRATION ","PASS" if failures.is_empty() else "FAIL"," scenarios=",scenarios.size()," failures=",JSON.stringify(failures))
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
