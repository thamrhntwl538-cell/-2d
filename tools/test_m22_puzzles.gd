extends SceneTree
## Contract tests for an optional spatial puzzle: harmless retries, save
## migration, one-time rewards and unchanged approved folding mechanisms.
const Puzzle = preload("res://scripts/stage/m22_puzzle_state.gd")
const Base = preload("res://scripts/stage/m17_puzzle_state.gd")
var checks := 0
var failures: Array[String] = []
var sequence_cases := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value and not failures.has(message):
		failures.append(message)
		printerr("M22 PUZZLE FAIL: ", message)

func _lamp(station: int) -> Dictionary:
	return {"id": "lamp_" + str(station), "kind": "margin_lantern", "station": station}

func _interact(progress: Dictionary, station: int) -> Dictionary:
	return Puzzle.act(progress, _lamp(station))

func _run() -> void:
	_test_correct_route_and_persistence()
	_test_harmless_retries()
	_test_migration_and_guards()
	_test_legacy_folds()
	_test_observation_catalog()
	_test_short_sequence_space()
	var report := {"checks": checks, "failures": failures, "sequence_cases": sequence_cases,
		"coverage": ["physical sequence", "idempotent activation", "harmless retry", "save reload", "one-time reward", "old-save migration", "legacy folding semantics", "bilingual observation clue"]}
	var file := FileAccess.open("user://m22_puzzle_report.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("M22_PUZZLES ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _test_correct_route_and_persistence() -> void:
	var progress: Dictionary = Puzzle.new_progress()
	var first := _interact(progress, 1)
	_check(first.ok and first.changed and progress.lantern_sequence_step == 1, "first observed lamp stores one linked step")
	_check(not progress.margin_lantern_solved and int(first.get("currency_reward", 0)) == 0, "partial progress cannot award a discovery")
	var same := _interact(progress, 1)
	_check(same.ok and not same.changed and progress.lantern_sequence_step == 1, "double activation cannot reset or advance a lit lamp")
	# JSON converts numbers and arrays exactly as an actual save/reload does.
	progress = JSON.parse_string(JSON.stringify(progress))
	var second := _interact(progress, 0)
	_check(second.ok and progress.lantern_sequence_step == 2, "a saved partial route resumes at its next physical lamp")
	progress = JSON.parse_string(JSON.stringify(progress))
	var last := _interact(progress, 2)
	_check(last.ok and last.changed and progress.margin_lantern_solved, "third observed lamp permanently completes the optional puzzle")
	_check(int(last.get("currency_reward", 0)) == 15, "the completed discovery awards exactly fifteen currency")
	_check(progress.notes.count("margin_lantern_record") == 1, "one discovery leaf is kept in the journal")
	_check(progress.events.count("secret:margin_lantern") == 1, "the discovery has one persistent event")
	_check(not progress.get("boss_defeated", false) and not progress.get("guard_clear", false), "optional light discovery cannot award any encounter victory")
	progress = JSON.parse_string(JSON.stringify(progress))
	for station in [2, 0, 1, 2, 1, 0]:
		var repeated := _interact(progress, station)
		_check(repeated.ok and not repeated.changed and int(repeated.get("currency_reward", 0)) == 0, "a saved completion cannot duplicate rewards")
	_check(progress.notes.count("margin_lantern_record") == 1 and progress.events.count("secret:margin_lantern") == 1, "journal and event are not duplicated after revisits")

func _test_harmless_retries() -> void:
	var progress: Dictionary = Puzzle.new_progress()
	progress.book_inventory = ["TRIANGLE", "SQUARE", "CIRCLE"]
	progress.credits = 42
	progress.weapon_owned = true
	progress.ink_route_solved = true
	var protected := {"book_inventory": progress.book_inventory.duplicate(), "credits": 42, "weapon_owned": true, "ink_route_solved": true}
	_interact(progress, 1)
	var wrong := _interact(progress, 2)
	_check(not wrong.ok and wrong.changed and progress.lantern_sequence_step == 0, "out-of-order lamp gently clears the unfinished line")
	for key in protected:
		_check(progress[key] == protected[key], "retry preserves permanent progress and resources: " + key)
	_check(not wrong.has("damage") and not wrong.has("energy_cost") and not wrong.has("currency_reward"), "retry imposes no health, energy or currency penalty")
	for station in [1, 0, 1, 0, 2]:
		_interact(progress, station)
	_check(progress.margin_lantern_solved, "a new attempt can restart immediately without reloading")
	_check(Puzzle.requirement_met(progress, "margin_lantern_solved"), "completion exposes the optional reward leaf through normal visibility guards")

func _test_migration_and_guards() -> void:
	var old: Dictionary = Base.new_progress()
	old.ink_route_solved = true
	old.book_inventory = ["SQUARE"]
	var result := _interact(old, 1)
	_check(result.ok and old.lantern_sequence_step == 1, "an unchanged M18-M21 progress object can start the new puzzle")
	_check(old.ink_route_solved and old.book_inventory == ["SQUARE"], "old save migration preserves existing route and book progress")
	for corrupt in [null, "broken", [0], [1, 2], [1, 0, 2, 1], [1.5], [1, 0, 2]]:
		var progress: Dictionary = Puzzle.new_progress()
		progress.lantern_sequence_history = corrupt
		progress.lantern_sequence_step = 99
		var next := _interact(progress, 1)
		_check(next.ok and progress.lantern_sequence_step == 1 and not progress.margin_lantern_solved, "invalid partial history resets to a safe new attempt")
	var locked := Puzzle.new_progress()
	locked.world1_departed = true
	var before := locked.duplicate(true)
	_check(not _interact(locked, 1).ok and locked == before, "a closed first world cannot be altered or farmed")
	var gated := Puzzle.new_progress()
	_check(not Puzzle.act(gated, {"kind": "margin_lantern", "station": 1, "requires": "missing_key"}).ok, "normal interaction requirements apply to new lamps")
	for invalid in [-1, 3, 999, "1", 1.5, null]:
		var invalid_progress := Puzzle.new_progress()
		var invalid_before := invalid_progress.duplicate(true)
		_check(not Puzzle.act(invalid_progress, {"kind": "margin_lantern", "station": invalid}).ok and invalid_progress == invalid_before, "invalid station cannot advance or reward the puzzle")

func _test_legacy_folds() -> void:
	var progress := Puzzle.new_progress()
	var ink: Dictionary = {"kind": "ink_control"}
	_check(not Puzzle.act(progress, ink, {"action": "confirm"}).ok, "incorrect ink connection still fails safely")
	for index in range(3):
		Puzzle.act(progress, ink, {"index": index, "value": [2, 0, 3][index]})
	var request := Puzzle.act(progress, ink, {"action": "confirm"})
	_check(request.get("commit_flag", "") == "ink_route_solved" and not progress.ink_route_solved, "correct ink still requests a safe geometry fold before saving the flag")
	_check(Puzzle.commit_fold(progress, "ink_route_solved").ok and progress.ink_route_solved, "settled ink geometry keeps the approved commit behavior")
	for book in ["TRIANGLE", "SQUARE", "CIRCLE"]:
		Puzzle.act(progress, {"kind": "book", "symbol": book})
	var process := {"kind": "process_control"}
	for index in range(3):
		Puzzle.act(progress, process, {"index": index, "value": ["TRIANGLE", "SQUARE", "CIRCLE"][index]})
	_check(Puzzle.act(progress, process, {"action": "confirm"}).ok and progress.book_order_verified, "approved collected-book order is unchanged")
	var output := Puzzle.act(progress, {"kind": "output_control"})
	_check(output.get("commit_flag", "") == "output_open" and not progress.output_open, "output still requests a safe fold")
	_check(Puzzle.commit_fold(progress, "output_open").ok, "output commit accepts approved book progress")
	Puzzle.act(progress, {"kind": "balance_control"}, {"index": 0, "value": 0})
	var balance := Puzzle.act(progress, {"kind": "balance_control"}, {"action": "confirm"})
	_check(balance.get("commit_flag", "") == "balance_bridge_locked" and not progress.balance_bridge_locked, "approved one-unit balance still requests a safe bridge fold")
	_check(Puzzle.commit_fold(progress, "balance_bridge_locked").ok, "approved balance locks only after the geometry settles")
	_check(not Puzzle.commit_fold(Puzzle.new_progress(), "margin_lantern_solved").ok, "light discovery cannot be forged through a fold commit")
	# Representative old interactions must return byte-for-byte equivalent state
	# and responses; new defaults are removed before comparison.
	for definition in [{"kind": "weapon"}, {"kind": "note", "id": "entrance_note"}, {"kind": "dialogue"}, {"kind": "shortcut", "flag": "archive_return_open"}, {"kind": "world_exit"}]:
		var old := Base.new_progress()
		var fresh := Puzzle.new_progress()
		var expected := Base.act(old, definition)
		var actual := Puzzle.act(fresh, definition)
		for key in ["lantern_sequence_step", "lantern_sequence_history", "margin_lantern_solved"]:
			fresh.erase(key)
		_check(expected == actual and old == fresh, "legacy interaction is exactly preserved: " + str(definition.kind))

func _test_observation_catalog() -> void:
	var notes: Array[Dictionary] = Puzzle.extra_notes()
	_check(notes.size() == 2, "one clue leaf and one discovery leaf are cataloged")
	var ids: Array[String] = []
	for note in notes:
		_check(not ids.has(str(note.id)), "journal catalog IDs are unique")
		ids.append(str(note.id))
		_check(not str(note.get("title_ar", "")).is_empty() and not str(note.get("title_en", "")).is_empty(), "new leaf has Arabic and English names")
		_check(not str(note.get("text_ar", "")).is_empty() and not str(note.get("text_en", "")).is_empty(), "new leaf has Arabic and English reading text")
	_check(notes[0].illustration == "lantern_sequence" and notes[0].glyphs == ["DIAMOND", "ARCH", "RAYS"], "visual clue uses the same three spatial lamp markings")
	_check(notes[1].visible_requires == "margin_lantern_solved" and notes[1].requires == ["margin_lantern_solved"], "physical reward page is hidden and locked until the actual puzzle completes")

func _test_short_sequence_space() -> void:
	# Explore every 5-input physical attempt. Across wrong turns and repeated
	# keys, rewards must remain at most one and a saved result must be stable.
	for encoded in range(243):
		sequence_cases += 1
		var progress := Puzzle.new_progress()
		var cursor := encoded
		var reward := 0
		for index in range(5):
			var station := cursor % 3
			cursor /= 3
			var result := _interact(progress, station)
			reward += int(result.get("currency_reward", 0))
			_check(reward <= 15, "any physical attempt awards at most one discovery")
			_check(int(progress.lantern_sequence_step) >= 0 and int(progress.lantern_sequence_step) <= 3, "any input leaves a bounded visible lamp state")
			_check(bool(progress.margin_lantern_solved) == (int(progress.lantern_sequence_step) == 3), "finished lamp state and persistent flag agree")
		if progress.margin_lantern_solved:
			var saved: Dictionary = JSON.parse_string(JSON.stringify(progress))
			_check(int(_interact(saved, 1).get("currency_reward", 0)) == 0, "every solved input history remains non-farmable after reload")
