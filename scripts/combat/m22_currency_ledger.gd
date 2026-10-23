extends RefCounted
## Physical rewards live in progress until each individual coin is collected.
## Keep spent entries: their stable source IDs are the receipt against duplicate
## kills, puzzle actions, room revisits, and save/load. No wallet changes here.

const KEY := "currency_rewards"
const SCHEMA := 1
const MAX_REWARD := 99999999
const MAX_COINS := 6
const MAX_ROOM := 15
const POSITION_LIMIT := 100000.0

static func create_reward(progress: Dictionary, reward_id: String, room: int, ground_anchor: Vector2, total: int) -> Array[Dictionary]:
	sanitize(progress)
	if not _valid_id(reward_id):
		return []
	# An existing ID always wins, even when a caller changes its amount or room.
	if progress[KEY].has(reward_id):
		return _pending_for(reward_id, progress[KEY][reward_id])
	if room < 1 or room > MAX_ROOM or total < 1 or total > MAX_REWARD or not _valid_point(ground_anchor):
		return []
	var count: int = mini(MAX_COINS, ceili(float(total) / 3.0))
	var base: int = total / count
	var remainder: int = total % count
	var coins: Array[Dictionary] = []
	for index in range(count):
		# The world supplies a real floor point with at least 28 px of ledge margin.
		# These saved settled positions never follow the transient magnet animation.
		var spread: float = 0.0 if count == 1 else lerpf(-28.0, 28.0, float(index) / float(count - 1))
		coins.append({
			"amount": base + (1 if index < remainder else 0),
			"position": [ground_anchor.x + spread, ground_anchor.y - 12.0],
			"collected": false
		})
	progress[KEY][reward_id] = {"schema": SCHEMA, "room": room, "total": total, "coins": coins}
	return _pending_for(reward_id, progress[KEY][reward_id])

static func claim(progress: Dictionary, reward_id: String, coin_index: int) -> int:
	sanitize(progress)
	if not _valid_id(reward_id) or not progress[KEY].has(reward_id):
		return 0
	var receipt: Dictionary = progress[KEY][reward_id]
	var coins: Array = receipt.coins
	if coin_index < 0 or coin_index >= coins.size() or bool(coins[coin_index].collected):
		return 0
	var amount: int = int(coins[coin_index].amount)
	# Mark first. A second callback for the same node/source cannot pay again.
	coins[coin_index].collected = true
	return amount

static func room_pending(progress: Dictionary, room: int) -> Array[Dictionary]:
	sanitize(progress)
	var result: Array[Dictionary] = []
	if room < 1 or room > MAX_ROOM:
		return result
	for reward_id in progress[KEY]:
		var receipt: Dictionary = progress[KEY][reward_id]
		if int(receipt.room) == room:
			result.append_array(_pending_for(str(reward_id), receipt))
	return result

static func sanitize(progress: Dictionary) -> void:
	var clean: Dictionary = {}
	var raw: Variant = progress.get(KEY, {})
	if raw is Dictionary:
		for reward_id in raw:
			if not _valid_id(reward_id):
				continue
			# Preserve valid source IDs even if their payload is corrupt. Making a
			# harmless spent receipt is safer than reopening an already-paid reward.
			clean[reward_id] = _normalized_receipt(raw[reward_id])
	progress[KEY] = clean

static func _normalized_receipt(raw: Variant) -> Dictionary:
	var spent := {"schema": SCHEMA, "room": 0, "total": 0, "coins": []}
	if not raw is Dictionary or _integer(raw.get("schema"), -1, SCHEMA, SCHEMA) != SCHEMA:
		return spent
	var room: int = _integer(raw.get("room"), 0, 1, MAX_ROOM)
	var total: int = _integer(raw.get("total"), 0, 1, MAX_REWARD)
	var source_coins: Variant = raw.get("coins", [])
	if room == 0 or total == 0 or not source_coins is Array or source_coins.is_empty() or source_coins.size() > MAX_COINS:
		return spent
	var coins: Array[Dictionary] = []
	var counted: int = 0
	for coin in source_coins:
		if not coin is Dictionary:
			return spent
		var amount: int = _integer(coin.get("amount"), 0, 1, MAX_REWARD)
		var position: Variant = coin.get("position", [])
		if amount == 0 or counted > MAX_REWARD - amount or not _valid_saved_point(position):
			return spent
		if not coin.get("collected") is bool:
			return spent
		counted += amount
		coins.append({"amount": amount, "position": [float(position[0]), float(position[1])], "collected": coin.collected})
	if counted != total:
		return spent
	return {"schema": SCHEMA, "room": room, "total": total, "coins": coins}

static func _pending_for(reward_id: String, receipt: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(receipt.coins.size()):
		var coin: Dictionary = receipt.coins[index]
		if not bool(coin.collected):
			result.append({"reward_id": reward_id, "coin_index": index, "room": int(receipt.room), "amount": int(coin.amount), "position": coin.position.duplicate()})
	return result

static func _valid_id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 160 and value.strip_edges() == value and not value.contains("\n") and not value.contains("\r") and not value.contains("\t")

static func _integer(value: Variant, fallback: int, minimum: int, maximum: int) -> int:
	if value is int:
		return value if value >= minimum and value <= maximum else fallback
	if value is float and is_finite(value) and value == floorf(value) and value >= minimum and value <= maximum:
		return int(value)
	return fallback

static func _valid_point(point: Vector2) -> bool:
	return is_finite(point.x) and is_finite(point.y) and absf(point.x) <= POSITION_LIMIT - 32.0 and absf(point.y) <= POSITION_LIMIT - 32.0

static func _valid_saved_point(raw: Variant) -> bool:
	if not raw is Array or raw.size() != 2:
		return false
	for value in raw:
		if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value)) > POSITION_LIMIT:
			return false
	return true
