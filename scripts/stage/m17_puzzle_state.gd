extends RefCounted
## Pure M17 interaction state. The stage owns range checks, safe swept volumes,
## animation and saves. A correct answer requests a fold; only commit_fold()
## records the solved geometry after the stage has settled its static surfaces.

const BOOKS := ["TRIANGLE", "SQUARE", "CIRCLE"]
const INK_TARGET := [2, 0, 3]
const POP_TARGET := [1, 2, 1]
const MOVABLE_WEIGHTS := [1, 1, 2]
const ENVIRONMENT_LATCHES := ["archive_return_open", "workshop_main_passage_open", "workshop_archive_return_open", "guard_approach_return_open"]
const FOLD_FLAGS := ["ink_route_solved", "output_open", "balance_bridge_locked", "secret_S03_open", "secret_S06_open"]
const MESSAGES := {
	"locked": ["The mechanism is not ready yet.", "الآلية غير جاهزة بعد."],
	"already_solved": ["This mechanism is already settled and saved.", "هذه الآلية مستقرة ومحفوظة بالفعل."],
	"weapon_found": ["The Warden's tool is yours. Try it in the safe practice space.", "حصلت على أداة الحارس. جرّبها في مساحة التدريب الآمنة."],
	"book_found": ["Book collected. Its symbol is recorded in your journal.", "جُمِع الكتاب وسُجّل رمزه في يومياتك."],
	"books_complete": ["All three books collected. Take them to PROCESS.", "جُمعت الكتب الثلاثة. توجّه بها إلى قاعة الترتيب PROCESS."],
	"note_read": ["The page has been kept in your journal.", "حُفظت الصفحة في يومياتك."],
	"dialogue_seen": ["The stranger's warning is kept in your journal.", "حُفظ تحذير الغريب في يومياتك."],
	"checkpoint_saved": ["Rest here. Your route and solved mechanisms are remembered.", "استرح هنا. مسارك والآليات المحلولة محفوظة."],
	"mechanism_changed": ["Watch how the mechanism responds.", "راقب كيف تستجيب الآلية."],
	"ink_retry": ["The ink returns to the basin. Rotate the channels and try again.", "عاد الحبر إلى الحوض. دوّر القنوات وحاول مجددًا."],
	"ink_ready": ["The ink reaches the folder. Stand clear while the walkway settles.", "وصل الحبر إلى آلة الطي. ابقَ بعيدًا حتى يستقر الممشى."],
	"books_missing": ["Collect the triangle, square and circle books in INPUT first.", "اجمع كتب المثلث والمربع والدائرة من INPUT أولًا."],
	"order_retry": ["Follow the nearby clue: triangle, square, circle. No books are lost.", "اتبع الدليل القريب: مثلث، مربع، دائرة. لم تفقد أي كتاب."],
	"order_verified": ["The books are correctly arranged together. OUTPUT is ready.", "ترتبت الكتب معًا بشكل صحيح. جهاز OUTPUT جاهز."],
	"output_ready": ["The page is unfolding. Wait on the fixed control pad.", "الصفحة تنفتح. انتظر على أرض التحكم الثابتة."],
	"balance_retry": ["The bridge is tilted. Move a weight between the two trays.", "الجسر مائل. انقل ثقلًا بين الكفتين."],
	"balance_ready": ["The trays balance. The bridge will lock into place.", "تعادلت الكفتان. سيثبت الجسر في موضعه."],
	"overlay_retry": ["The two page marks do not yet overlap.", "علامتا الصفحتين لم تتطابقا بعد."],
	"overlay_ready": ["The missing margin appears. Its shelf is unfolding.", "ظهر الهامش المفقود. رفّه ينفتح الآن."],
	"pop_retry": ["Follow the three folds shown beside the book.", "اتبع الطيات الثلاث الموضحة بجوار الكتاب."],
	"pop_ready": ["The paper model opens a way to the repairer's room.", "فتح المجسّم الورقي طريقًا إلى حجرة المصلح."],
	"shortcut_open": ["The return passage is open from both sides.", "ممر العودة مفتوح الآن من الجهتين."],
	"secret_found": ["An optional discovery has been recorded.", "سُجّل اكتشاف اختياري في يومياتك."],
	"seal_missing": ["The seal is earned from the guardian. This socket cannot create it.", "يُكتسب الختم من الحارس. هذا المقبس لا يصنعه."],
	"seal_registered": ["The earned seal is registered. It remains yours.", "سُجّل الختم المكتسب، ويظل بحوزتك."],
	"departure_confirm": ["Crossing closes the first world. You can stay and explore before deciding.", "العبور يغلق العالم الأول. يمكنك البقاء والاستكشاف قبل اتخاذ القرار."],
	"unknown_action": ["This interaction is not available.", "هذا التفاعل غير متاح."],
	"fold_committed": ["The route is stable and will remain open.", "المسار ثابت وسيظل مفتوحًا."]
}

static func new_progress() -> Dictionary:
	return {
		"version": 17,
		"weapon_owned": false,
		"encounter_assignments_cleared": false,
		"ink_route_solved": false,
		"black_flame_warning_seen": false,
		"archive_upper_landing_reached": false,
		"archive_return_open": false,
		"book_triangle_owned": false,
		"book_square_owned": false,
		"book_circle_owned": false,
		"books_collected": false,
		"book_order_verified": false,
		"output_open": false,
		"balance_bridge_locked": false,
		"workshop_main_passage_open": false,
		"workshop_archive_return_open": false,
		"guard_approach_return_open": false,
		"guard_clear": false,
		"compiler_seal_owned": false,
		"seal_registered": false,
		"boss_defeated": false,
		"world1_departed": false,
		"secret_S03_open": false,
		"secret_S06_open": false,
		"ink_rotations": [0, 0, 0],
		"book_inventory": [],
		"book_order": ["CIRCLE", "TRIANGLE", "SQUARE"],
		"balance_sides": [1, 1, 1],
		"overlay_offsets": [2, 1],
		"pop_folds": [0, 0, 0],
		"solved_secrets": [],
		"notes": [],
		"visited": [],
		"events": [],
		"credits": 0
	}

static func requirement_met(progress: Dictionary, requirement: String) -> bool:
	if requirement.is_empty():
		return true
	if requirement.begins_with("secret:"):
		return progress.get("solved_secrets", []).has(requirement.trim_prefix("secret:"))
	if requirement.begins_with("book:"):
		return progress.get("book_inventory", []).has(requirement.trim_prefix("book:").to_upper())
	return bool(progress.get(requirement, false))

static func requirements_met(progress: Dictionary, requirements: Variant) -> bool:
	if requirements is String:
		return requirement_met(progress, requirements)
	if requirements is Array:
		for requirement in requirements:
			if not requirement_met(progress, str(requirement)):
				return false
	return true

static func _result(ok: bool, changed: bool, key: String, extra: Dictionary = {}) -> Dictionary:
	var texts: Array = MESSAGES.get(key, MESSAGES.unknown_action)
	var result := {"ok": ok, "changed": changed, "message_key": key, "message_en": texts[0], "message_ar": texts[1]}
	result.merge(extra, true)
	return result

static func _array(progress: Dictionary, key: String, fallback: Array) -> Array:
	var value: Variant = progress.get(key, [])
	if not value is Array or value.size() != fallback.size():
		progress[key] = fallback.duplicate()
	return progress[key]

static func _choice_action(choice: Variant, fallback: String) -> String:
	if choice is Dictionary:
		return str(choice.get("action", fallback))
	if choice is String and choice == "confirm":
		return "confirm"
	return fallback

static func _choice_index(choice: Variant, length: int) -> int:
	if choice is Dictionary:
		return clampi(int(choice.get("index", 0)), 0, length - 1)
	return 0

static func _cycle_value(choice: Variant, current: int, modulo: int) -> int:
	if choice is Dictionary and choice.has("value"):
		return posmod(int(choice.value), modulo)
	return posmod(current + 1, modulo)

static func _event(progress: Dictionary, id: String) -> void:
	if not progress.has("events") or not progress.events is Array:
		progress.events = []
	if not progress.events.has(id):
		progress.events.append(id)

static func _mark_secret(progress: Dictionary, secret: String) -> bool:
	if secret.is_empty():
		return false
	if not progress.has("solved_secrets") or not progress.solved_secrets is Array:
		progress.solved_secrets = []
	if progress.solved_secrets.has(secret):
		return false
	progress.solved_secrets.append(secret)
	progress.credits = int(progress.get("credits", 0)) + 15
	_event(progress, "secret:" + secret)
	return true

static func ink_flow(progress: Dictionary) -> int:
	# Elbows: 0=N/E, 1=E/S, 2=S/W, 3=W/N. On the grid A(0,0),
	# B(0,1), C(1,1), ink enters A from the west and leaves C north.
	var rotations: Array = _array(progress, "ink_rotations", [0, 0, 0])
	var connected := 0
	for i in range(3):
		if posmod(int(rotations[i]), 4) != int(INK_TARGET[i]):
			break
		connected += 1
	return connected

static func balance_totals(progress: Dictionary) -> Vector2i:
	var sides: Array = _array(progress, "balance_sides", [1, 1, 1])
	var totals := Vector2i(2, 0)
	for i in range(3):
		if int(sides[i]) == 0:
			totals.x += int(MOVABLE_WEIGHTS[i])
		else:
			totals.y += int(MOVABLE_WEIGHTS[i])
	return totals

static func act(progress: Dictionary, definition: Dictionary, choice: Variant = null) -> Dictionary:
	var kind := str(definition.get("kind", ""))
	var id := str(definition.get("id", kind))
	if bool(progress.get("world1_departed", false)):
		return _result(false, false, "locked")
	var required: Variant = definition.get("requires", definition.get("requires_all", []))
	if not requirements_met(progress, required):
		return _result(false, false, "seal_missing" if kind == "combat_socket" else "locked")
	match kind:
		"weapon":
			var changed: bool = not bool(progress.get("weapon_owned", false))
			progress.weapon_owned = true
			_event(progress, "weapon_pickup")
			return _result(true, changed, "weapon_found")
		"book":
			var symbol := str(definition.get("symbol", definition.get("book_id", definition.get("book", "")))).to_upper()
			if symbol not in BOOKS:
				return _result(false, false, "unknown_action")
			if not progress.has("book_inventory") or not progress.book_inventory is Array:
				progress.book_inventory = []
			var changed: bool = not progress.book_inventory.has(symbol)
			if changed:
				progress.book_inventory.append(symbol)
			progress["book_" + symbol.to_lower() + "_owned"] = true
			progress.books_collected = true
			for book in BOOKS:
				if not progress.book_inventory.has(book):
					progress.books_collected = false
			_event(progress, "book:" + symbol)
			return _result(true, changed, "books_complete" if progress.books_collected else "book_found", {"book": symbol})
		"note":
			if not progress.has("notes") or not progress.notes is Array:
				progress.notes = []
			var changed: bool = not progress.notes.has(id)
			if changed:
				progress.notes.append(id)
			var secret := str(definition.get("secret_id", definition.get("secret", "")))
			if not secret.is_empty():
				changed = _mark_secret(progress, secret) or changed
			return _result(true, changed, "note_read", {"needs_panel": "note"})
		"dialogue":
			var changed: bool = not bool(progress.get("black_flame_warning_seen", false))
			progress.black_flame_warning_seen = true
			_event(progress, "black_flame_warning")
			return _result(true, changed, "dialogue_seen", {"needs_panel": "dialogue"})
		"bench":
			return _result(true, false, "checkpoint_saved", {"checkpoint": true})
		"shortcut":
			var flag := str(definition.get("flag", ""))
			if flag not in ENVIRONMENT_LATCHES:
				return _result(false, false, "unknown_action")
			if flag == "workshop_archive_return_open" and not bool(progress.get("workshop_main_passage_open", false)):
				return _result(false, false, "locked")
			var changed: bool = not bool(progress.get(flag, false))
			progress[flag] = true
			_event(progress, flag)
			return _result(true, changed, "shortcut_open")
		"ink_control":
			return _ink(progress, choice)
		"process_control":
			return _process_books(progress, choice)
		"output_control":
			if not bool(progress.get("book_order_verified", false)):
				return _result(false, false, "books_missing")
			if bool(progress.get("output_open", false)):
				return _result(true, false, "already_solved")
			return _result(true, false, "output_ready", {"animation": "output", "commit_flag": "output_open"})
		"balance_control":
			return _balance(progress, choice)
		"secret_overlay":
			return _overlay(progress, choice)
		"secret_pop":
			return _pop(progress, choice)
		"secret":
			var secret := str(definition.get("secret_id", id))
			return _result(true, _mark_secret(progress, secret), "secret_found", {"needs_panel": "note"})
		"combat_socket":
			if not bool(progress.get("guard_clear", false)) or not bool(progress.get("compiler_seal_owned", false)):
				return _result(false, false, "seal_missing")
			var changed: bool = not bool(progress.get("seal_registered", false))
			progress.seal_registered = true
			return _result(true, changed, "seal_registered")
		"world_exit":
			if not bool(progress.get("boss_defeated", false)):
				return _result(false, false, "locked")
			return _result(true, false, "departure_confirm", {"needs_panel": "world_exit"})
	return _result(false, false, "unknown_action")

static func _ink(progress: Dictionary, choice: Variant) -> Dictionary:
	if bool(progress.get("ink_route_solved", false)):
		return _result(true, false, "already_solved")
	if choice == null:
		return _result(true, false, "mechanism_changed", {"needs_panel": "ink"})
	if _choice_action(choice, "rotate") == "confirm":
		if ink_flow(progress) == 3:
			return _result(true, false, "ink_ready", {"animation": "ink", "commit_flag": "ink_route_solved"})
		return _result(false, false, "ink_retry", {"needs_panel": "ink"})
	var rotations: Array = _array(progress, "ink_rotations", [0, 0, 0])
	var index := _choice_index(choice, 3)
	rotations[index] = _cycle_value(choice, int(rotations[index]), 4)
	return _result(true, true, "mechanism_changed", {"needs_panel": "ink", "flow": ink_flow(progress)})

static func _process_books(progress: Dictionary, choice: Variant) -> Dictionary:
	if not bool(progress.get("books_collected", false)):
		return _result(false, false, "books_missing")
	if bool(progress.get("book_order_verified", false)):
		return _result(true, false, "already_solved")
	if choice == null:
		return _result(true, false, "mechanism_changed", {"needs_panel": "process"})
	var order: Array = _array(progress, "book_order", ["CIRCLE", "TRIANGLE", "SQUARE"])
	if _choice_action(choice, "cycle") == "confirm":
		if order == BOOKS:
			progress.book_order_verified = true
			_event(progress, "book_order_verified")
			return _result(true, true, "order_verified")
		return _result(false, false, "order_retry", {"needs_panel": "process"})
	var index := _choice_index(choice, 3)
	if choice is Dictionary and choice.has("value"):
		var value: Variant = choice.value
		if value is String and value.to_upper() in BOOKS:
			order[index] = value.to_upper()
		else:
			order[index] = BOOKS[posmod(int(value), 3)]
	else:
		order[index] = BOOKS[posmod(BOOKS.find(str(order[index])) + 1, 3)]
	return _result(true, true, "mechanism_changed", {"needs_panel": "process"})

static func _balance(progress: Dictionary, choice: Variant) -> Dictionary:
	if bool(progress.get("balance_bridge_locked", false)):
		return _result(true, false, "already_solved")
	if choice == null:
		return _result(true, false, "mechanism_changed", {"needs_panel": "balance"})
	if _choice_action(choice, "toggle") == "confirm":
		var totals := balance_totals(progress)
		if totals.x == totals.y:
			return _result(true, false, "balance_ready", {"animation": "balance", "commit_flag": "balance_bridge_locked"})
		return _result(false, false, "balance_retry", {"needs_panel": "balance"})
	var sides: Array = _array(progress, "balance_sides", [1, 1, 1])
	var index := _choice_index(choice, 3)
	sides[index] = _cycle_value(choice, int(sides[index]), 2)
	return _result(true, true, "mechanism_changed", {"needs_panel": "balance", "totals": balance_totals(progress)})

static func _overlay(progress: Dictionary, choice: Variant) -> Dictionary:
	if bool(progress.get("secret_S03_open", false)):
		return _result(true, false, "already_solved")
	if choice == null:
		return _result(true, false, "mechanism_changed", {"needs_panel": "overlay"})
	var offsets: Array = _array(progress, "overlay_offsets", [2, 1])
	if _choice_action(choice, "cycle") == "confirm":
		if int(offsets[0]) == 0 and int(offsets[1]) == 0:
			return _result(true, false, "overlay_ready", {"animation": "overlay", "commit_flag": "secret_S03_open"})
		return _result(false, false, "overlay_retry", {"needs_panel": "overlay"})
	var index := _choice_index(choice, 2)
	offsets[index] = _cycle_value(choice, int(offsets[index]), 4)
	return _result(true, true, "mechanism_changed", {"needs_panel": "overlay"})

static func _pop(progress: Dictionary, choice: Variant) -> Dictionary:
	if bool(progress.get("secret_S06_open", false)):
		return _result(true, false, "already_solved")
	if choice == null:
		return _result(true, false, "mechanism_changed", {"needs_panel": "pop"})
	var folds: Array = _array(progress, "pop_folds", [0, 0, 0])
	if _choice_action(choice, "cycle") == "confirm":
		if folds == POP_TARGET:
			return _result(true, false, "pop_ready", {"animation": "pop", "commit_flag": "secret_S06_open"})
		return _result(false, false, "pop_retry", {"needs_panel": "pop"})
	var index := _choice_index(choice, 3)
	folds[index] = _cycle_value(choice, int(folds[index]), 3)
	return _result(true, true, "mechanism_changed", {"needs_panel": "pop"})

static func commit_fold(progress: Dictionary, flag: String) -> Dictionary:
	if flag not in FOLD_FLAGS or bool(progress.get("world1_departed", false)):
		return _result(false, false, "locked")
	if bool(progress.get(flag, false)):
		return _result(true, false, "already_solved")
	var valid := false
	match flag:
		"ink_route_solved": valid = ink_flow(progress) == 3
		"output_open": valid = bool(progress.get("book_order_verified", false)) and bool(progress.get("books_collected", false))
		"balance_bridge_locked":
			var totals := balance_totals(progress)
			valid = totals.x == totals.y
		"secret_S03_open":
			var offsets: Array = _array(progress, "overlay_offsets", [2, 1])
			valid = int(offsets[0]) == 0 and int(offsets[1]) == 0
		"secret_S06_open": valid = _array(progress, "pop_folds", [0, 0, 0]) == POP_TARGET
	if not valid:
		return _result(false, false, "locked")
	progress[flag] = true
	_event(progress, flag)
	if flag == "secret_S03_open":
		_mark_secret(progress, "S03")
	elif flag == "secret_S06_open":
		_mark_secret(progress, "S06")
	return _result(true, true, "fold_committed", {"committed_flag": flag})
