extends RefCounted
## M22 keeps the approved folding mechanisms and adds a physical observation
## puzzle. Its three lamps are separate world objects on the existing margins
## stair: the player follows a surviving drawn line, rather than entering a code
## in a menu. Geometry is never changed by this optional puzzle.

const Base = preload("res://scripts/stage/m17_puzzle_state.gd")
const BOOKS = Base.BOOKS
const INK_TARGET = Base.INK_TARGET
const POP_TARGET = Base.POP_TARGET
const MOVABLE_WEIGHTS = Base.MOVABLE_WEIGHTS
const ENVIRONMENT_LATCHES = Base.ENVIRONMENT_LATCHES
const FOLD_FLAGS = Base.FOLD_FLAGS
const LANTERN_SEQUENCE := [1, 0, 2]
const LANTERN_REWARD := 15
const LANTERN_FLAG := "margin_lantern_solved"
const LANTERN_EVENT := "secret:margin_lantern"
const LANTERN_NOTE := "margin_lantern_record"

static func new_progress() -> Dictionary:
	var progress: Dictionary = Base.new_progress()
	progress.merge({
		"lantern_sequence_step": 0,
		"lantern_sequence_history": [],
		"margin_lantern_solved": false
	})
	return progress

static func requirement_met(progress: Dictionary, requirement: String) -> bool:
	return Base.requirement_met(progress, requirement)

static func requirements_met(progress: Dictionary, requirements: Variant) -> bool:
	return Base.requirements_met(progress, requirements)

static func ink_flow(progress: Dictionary) -> int:
	return Base.ink_flow(progress)

static func balance_totals(progress: Dictionary) -> Vector2i:
	return Base.balance_totals(progress)

static func commit_fold(progress: Dictionary, flag: String) -> Dictionary:
	return Base.commit_fold(progress, flag)

static func _feedback(ok: bool, changed: bool, key: String, en: String, ar: String, extra: Dictionary = {}) -> Dictionary:
	var result := {"ok": ok, "changed": changed, "message_key": key, "message_en": en, "message_ar": ar}
	result.merge(extra, true)
	return result

static func _normalize_lanterns(progress: Dictionary) -> Array:
	# Old M18-M21 saves need no conversion of their existing fields. A partial
	# puzzle survives saving; malformed or out-of-order histories reset safely.
	var history: Array = []
	if bool(progress.get(LANTERN_FLAG, false)):
		history = LANTERN_SEQUENCE.duplicate()
	else:
		var stored: Variant = progress.get("lantern_sequence_history", [])
		if stored is Array and stored.size() <= LANTERN_SEQUENCE.size():
			for i in range(stored.size()):
				if not (stored[i] is int or stored[i] is float) or float(stored[i]) != float(LANTERN_SEQUENCE[i]):
					history.clear()
					break
				history.append(int(stored[i]))
		# An uncommitted full history cannot bypass the final activation/reward.
		if history.size() == LANTERN_SEQUENCE.size():
			history.clear()
	progress.lantern_sequence_history = history
	progress.lantern_sequence_step = history.size()
	return history

static func act(progress: Dictionary, definition: Dictionary, choice: Variant = null) -> Dictionary:
	if str(definition.get("kind", "")) != "margin_lantern":
		return Base.act(progress, definition, choice)
	if bool(progress.get("world1_departed", false)) or not requirements_met(progress, definition.get("requires", definition.get("requires_all", []))):
		return _feedback(false, false, "locked", "This lamp cannot be reached yet.", "لا يمكن الوصول إلى هذا المصباح بعد.")
	var station_value: Variant = definition.get("station", -1)
	if not (station_value is int or station_value is float) or float(station_value) != floorf(float(station_value)):
		return _feedback(false, false, "unknown_action", "This lamp is not connected.", "هذا المصباح غير متصل.")
	var station := int(station_value)
	if station < 0 or station > 2:
		return _feedback(false, false, "unknown_action", "This lamp is not connected.", "هذا المصباح غير متصل.")
	var history := _normalize_lanterns(progress)
	if bool(progress.get(LANTERN_FLAG, false)):
		return _feedback(true, false, "lantern_already_solved", "The three lamps remember their light.", "احتفظت المصابيح الثلاثة بضوئها.")
	if not history.is_empty() and int(history[-1]) == station:
		return _feedback(true, false, "lantern_already_lit", "This mark is still glowing. Follow the next part of the line.", "هذه العلامة ما زالت مضيئة. اتبع الجزء التالي من الخط.")
	var expected: int = LANTERN_SEQUENCE[history.size()]
	if station != expected:
		# A harmless retry never consumes health, energy, books or currency.
		history.clear()
		if station == LANTERN_SEQUENCE[0]:
			history.append(station)
		progress.lantern_sequence_step = history.size()
		return _feedback(false, true, "lantern_retry", "The thin line fades. The drawing beside the first shelf still holds its trace.", "خفت الخط الرفيع. ما زال الرسم بجوار الرف الأول يحتفظ بأثره.", {"lantern_feedback": "retry"})
	history.append(station)
	progress.lantern_sequence_step = history.size()
	if history.size() < LANTERN_SEQUENCE.size():
		return _feedback(true, true, "lantern_linked", "A line of warm light reaches the next margin.", "وصل خط من الضوء الدافئ إلى الهامش التالي.", {"lantern_feedback": "linked"})
	# This is the single transaction that earns the optional reward. The world
	# issues physical coins only when changed=true; the wallet changes on pickup.
	# Subsequent solved-lamp calls request no additional reward.
	progress[LANTERN_FLAG] = true
	if not progress.get("events", []) is Array:
		progress.events = []
	if not progress.has("events"):
		progress.events = []
	if not progress.events.has(LANTERN_EVENT):
		progress.events.append(LANTERN_EVENT)
	if not progress.get("notes", []) is Array:
		progress.notes = []
	if not progress.has("notes"):
		progress.notes = []
	if not progress.notes.has(LANTERN_NOTE):
		progress.notes.append(LANTERN_NOTE)
	return _feedback(true, true, "lantern_solved", "The missing lines return. A hidden leaf is now kept in your journal.", "عادت السطور الغائبة. حُفظت ورقة مخفية في يومياتك.", {
		"currency_reward": LANTERN_REWARD,
		"lantern_feedback": "solved",
		"journal_updated": true,
		"discovery_flag": LANTERN_FLAG
	})

static func extra_notes() -> Array[Dictionary]:
	# Both the world catalog and the physical reading objects use these same
	# definitions, so the full journal and the opened leaf cannot disagree.
	return [
		{
			"id": "margin_lantern_clue", "kind": "note", "text_key": "margin_lantern_clue", "room_id": 5,
			"title_en": "A Line That Survived", "title_ar": "خط نجا من المحو",
			"text_en": "Most of the writing has been erased. A thin amber line survives along the margin, passing through three carved marks. The same marks are cut into the lamps above the shelves. Follow the line from its bright beginning to its fading end.\n\nA small annotation remains: ‘A mark that still glows does not need to be awakened twice.’",
			"text_ar": "مُحي معظم الكلام. بقي خط كهرماني رفيع على الهامش، يمر بثلاث علامات محفورة. العلامات نفسها منقوشة على المصابيح فوق الرفوف. اتبع الخط من بدايته المضيئة إلى نهايته الخافتة.\n\nبقي تعليق صغير: «العلامة التي ما زالت مضيئة لا تحتاج إلى إيقاظها مرتين». ",
			"illustration": "lantern_sequence", "glyphs": ["DIAMOND", "ARCH", "RAYS"],
			"reading_style": "shelf", "journal_section": "clues"
		},
		{
			"id": LANTERN_NOTE, "kind": "note", "text_key": LANTERN_NOTE, "room_id": 5,
			"title_en": "The Missing Lines", "title_ar": "السطور الغائبة",
			"text_en": "The lamps reveal writing beneath the erased surface.\n\n‘We used to leave light in the margins for those who lost their way. One reader returned with an unburned lantern. He would not say where he had been. He only asked us to stop calling the final page an ending.’\n\nThe next line has been cut out, not erased.",
			"text_ar": "تكشف المصابيح كتابة تحت السطح الممحو.\n\n«كنا نترك الضوء في الهوامش لمن يضل الطريق. عاد قارئ ذات مرة بفانوس لم تحترق فتيلته. لم يقل أين كان. طلب منا فقط ألّا نسمّي الصفحة الأخيرة نهاية».\n\nالسطر التالي مقصوص من الورقة، لا ممحو منها.",
			"reading_style": "shelf", "journal_section": "discoveries",
			"requires": [LANTERN_FLAG], "visible_requires": LANTERN_FLAG
		}
	]
