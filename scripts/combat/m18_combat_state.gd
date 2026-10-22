extends RefCounted
class_name M18CombatState
## Persistent M18 combat inventory. Physics, damage and energy live on the actor.
## All mutations that can award currency or capacity use unique pickup identities.
## Save restoration rejects malformed numbers before converting them to integers.

const SCHEMA_VERSION := 1
const MAX_ENERGY := 99.0
const ENERGY_PER_HIT := 11.0
const HEAL_COST := 33.0
const SPELL_COST := 33.0
const BASE_CAPACITY := 3
# Technical save-validation ceilings, not promises of obtainable progression.
const MAX_CAPACITY := 12
const MAX_WALLET := 99999999
const MAX_CLAIMS := 1024
const MAX_ROOM_ID := 15
const POSITION_LIMIT := 100000.0

const FITILS := {
	"reach": {
		"cost": 2,
		"name_ar": "فتيل المدى", "name_en": "Reach Wick",
		"description_ar": "يوسّع مدى ضربات السيف قليلًا.",
		"description_en": "Extends the reach of ordinary sword strikes.",
		"reach_multiplier": 1.15
	},
	"wick": {
		"cost": 1,
		"name_ar": "فتيل الاستمداد", "name_en": "Kindling Wick",
		"description_ar": "يزيد الوهج المكتسب من إصابات السيف الناجحة.",
		"description_en": "Gains a little more glow from successful sword hits.",
		"extra_energy": 2.0
	},
	"focus": {
		"cost": 2,
		"name_ar": "فتيل السكينة", "name_en": "Stillness Wick",
		"description_ar": "يقلّل وقت إكمال العلاج مع بقاء كلفته كما هي.",
		"description_en": "Completes healing sooner without changing its energy cost.",
		"focus_duration_multiplier": 0.8
	}
}

var wallet: int = 0
var dash_owned: bool = false
var spell_owned: bool = false
var owned: Array[String] = []
var equipped: Array[String] = []
var capacity: int = BASE_CAPACITY
var collected: Array[String] = []
var death_drop: Dictionary = {}

func acquire(id: String) -> bool:
	if not FITILS.has(id) or owned.has(id):
		return false
	owned.append(id)
	return true

func owns_fitil(id: String) -> bool:
	return owned.has(id) and FITILS.has(id)

func has_fitil(id: String) -> bool:
	# "Has" means equipped and owned; acquisition alone never applies an effect.
	return equipped.has(id) and owns_fitil(id)

func used_capacity() -> int:
	var total := 0
	var counted: Array[String] = []
	for id in equipped:
		if owns_fitil(id) and not counted.has(id):
			total += int(FITILS[id].cost)
			counted.append(id)
	return total

func equip(id: String, at_bench: bool) -> bool:
	if not at_bench or not owns_fitil(id) or equipped.has(id):
		return false
	var cost: int = int(FITILS[id].cost)
	if used_capacity() + cost > capacity:
		return false
	equipped.append(id)
	return true

func unequip(id: String, at_bench: bool) -> bool:
	if not at_bench or not equipped.has(id):
		return false
	equipped.erase(id)
	return true

func reach_multiplier() -> float:
	return float(FITILS.reach.reach_multiplier) if has_fitil("reach") else 1.0

func energy_per_hit() -> float:
	return ENERGY_PER_HIT + (float(FITILS.wick.extra_energy) if has_fitil("wick") else 0.0)

func focus_duration_multiplier() -> float:
	return float(FITILS.focus.focus_duration_multiplier) if has_fitil("focus") else 1.0

func collect_currency(claim_id: String, amount: int) -> bool:
	if not _can_claim(claim_id) or amount <= 0 or amount > MAX_WALLET:
		return false
	# Subtraction is checked before addition, so oversized amounts cannot overflow.
	if wallet < 0 or wallet > MAX_WALLET - amount:
		return false
	wallet += amount
	collected.append(claim_id)
	return true

func increase_capacity(claim_id: String, amount: int = 1) -> bool:
	if not _can_claim(claim_id) or amount <= 0 or amount > MAX_CAPACITY:
		return false
	if capacity < BASE_CAPACITY or capacity > MAX_CAPACITY - amount:
		return false
	capacity += amount
	collected.append(claim_id)
	return true

func drop_on_death(room: int, position: Vector2) -> void:
	var dropped: int = clampi(wallet, 0, MAX_WALLET)
	wallet = 0
	# Always erase the previous pile, even if the second death carries no money.
	death_drop = {}
	if dropped <= 0 or room < 1 or room > MAX_ROOM_ID or not _valid_position(position):
		return
	death_drop = {"room": room, "position": [position.x, position.y], "amount": dropped}

func recover_drop() -> int:
	var validated := _normalized_drop(death_drop)
	if validated.is_empty():
		death_drop = {}
		return 0
	var amount: int = int(validated.amount)
	if wallet < 0 or wallet > MAX_WALLET - amount:
		# Keep the pile available if a technical wallet ceiling prevents recovery.
		return 0
	wallet += amount
	death_drop = {}
	return amount

func serialize() -> Dictionary:
	var saved_owned := _normalized_owned(owned)
	var saved_capacity := _bounded_integer(capacity, BASE_CAPACITY, BASE_CAPACITY, MAX_CAPACITY)
	return {
		"schema": SCHEMA_VERSION,
		"wallet": _bounded_integer(wallet, 0, 0, MAX_WALLET),
		"dash_owned": dash_owned,
		"spell_owned": spell_owned,
		"owned": saved_owned,
		"equipped": _normalized_equipped(equipped, saved_owned, saved_capacity),
		"capacity": saved_capacity,
		"collected": _normalized_claims(collected),
		"death_drop": _normalized_drop(death_drop)
	}

func restore(record: Dictionary) -> void:
	# Clear first: a partial or invalid record must not retain another session's data.
	wallet = 0
	dash_owned = false
	spell_owned = false
	owned.clear()
	equipped.clear()
	capacity = BASE_CAPACITY
	collected.clear()
	death_drop = {}
	if _bounded_integer(record.get("schema", SCHEMA_VERSION), 0, SCHEMA_VERSION, SCHEMA_VERSION) != SCHEMA_VERSION:
		return
	wallet = _bounded_integer(record.get("wallet", 0), 0, 0, MAX_WALLET)
	dash_owned = record.get("dash_owned", false) is bool and record.get("dash_owned", false)
	spell_owned = record.get("spell_owned", false) is bool and record.get("spell_owned", false)
	capacity = _bounded_integer(record.get("capacity", BASE_CAPACITY), BASE_CAPACITY, BASE_CAPACITY, MAX_CAPACITY)
	owned = _normalized_owned(record.get("owned", []))
	equipped = _normalized_equipped(record.get("equipped", []), owned, capacity)
	collected = _normalized_claims(record.get("collected", []))
	death_drop = _normalized_drop(record.get("death_drop", {}))

func _can_claim(claim_id: String) -> bool:
	return _valid_claim(claim_id) and not collected.has(claim_id) and collected.size() < MAX_CLAIMS

static func _valid_claim(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 96 and value.strip_edges() == value and not value.contains("\n") and not value.contains("\r") and not value.contains("\t")

static func _bounded_integer(value: Variant, fallback: int, minimum: int, maximum: int) -> int:
	if value is int:
		return value if value >= minimum and value <= maximum else fallback
	if value is float:
		if is_finite(value) and value >= minimum and value <= maximum and value == floor(value):
			return int(value)
	return fallback

static func _normalized_owned(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if not raw is Array:
		return result
	for value in raw:
		if value is String and FITILS.has(value) and not result.has(value):
			result.append(value)
	return result

static func _normalized_equipped(raw: Variant, owned_ids: Array[String], allowed_capacity: int) -> Array[String]:
	var result: Array[String] = []
	if not raw is Array:
		return result
	var remaining := allowed_capacity
	for value in raw:
		if not value is String or not owned_ids.has(value) or not FITILS.has(value) or result.has(value):
			continue
		var cost: int = int(FITILS[value].cost)
		if cost <= remaining:
			result.append(value)
			remaining -= cost
	return result

static func _normalized_claims(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if not raw is Array:
		return result
	for value in raw:
		if _valid_claim(value) and not result.has(value):
			result.append(value)
			if result.size() == MAX_CLAIMS:
				break
	return result

static func _valid_position(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y) and absf(value.x) <= POSITION_LIMIT and absf(value.y) <= POSITION_LIMIT

static func _normalized_drop(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var room := _bounded_integer(raw.get("room", 0), 0, 1, MAX_ROOM_ID)
	var amount := _bounded_integer(raw.get("amount", 0), 0, 1, MAX_WALLET)
	var coordinates: Variant = raw.get("position", [])
	if room == 0 or amount == 0 or not coordinates is Array or coordinates.size() != 2:
		return {}
	if not (coordinates[0] is int or coordinates[0] is float) or not (coordinates[1] is int or coordinates[1] is float):
		return {}
	var position := Vector2(float(coordinates[0]), float(coordinates[1]))
	if not _valid_position(position):
		return {}
	return {"room": room, "position": [position.x, position.y], "amount": amount}
