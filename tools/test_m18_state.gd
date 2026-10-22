extends SceneTree
## Pure inventory/death/save scenarios. No user save files are read or changed.
const CombatState = preload("res://scripts/combat/m18_combat_state.gd")
const REPORT := "user://m18_state_report.json"
var checks := 0
var failures: Array[String] = []
var scenarios: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("M18 STATE FAIL: ", message)

func record(name_value: String, previous: int) -> void:
	scenarios.append({"name": name_value, "passed": failures.size() == previous})

func run_checks() -> void:
	var prior := failures.size()
	var state = CombatState.new()
	check(state.owned.is_empty() and state.equipped.is_empty(), "New games have no unearned fitils")
	check(not state.equip("reach", true), "Cannot equip an unowned fitil")
	check(not state.acquire("unknown"), "Unknown fitils are not invented")
	check(state.acquire("reach"), "A discovered fitil can be collected")
	check(state.owns_fitil("reach") and not state.has_fitil("reach"), "Acquisition alone does not apply its effect")
	check(is_equal_approx(state.reach_multiplier(), 1.0), "Unequipped reach leaves ordinary hitboxes unchanged")
	check(not state.acquire("reach"), "Revisiting a fitil pickup does not duplicate it")
	check(not state.equip("reach", false), "Equipping away from a bench is refused")
	check(state.equipped.is_empty(), "Refused equip does not change the loadout")
	check(state.equip("reach", true), "A bench permits equipping an owned fitil")
	check(state.has_fitil("reach") and state.reach_multiplier() > 1.0, "Equipped reach affects the strike multiplier")
	check(not state.equip("reach", true), "An equipped fitil cannot be duplicated")
	check(state.acquire("wick") and state.equip("wick", true), "Cost-two and cost-one fitils fit the initial capacity")
	check(state.used_capacity() == 3 and state.equipped.size() == 2, "Shared capacity counts costs, not number of icons")
	check(state.energy_per_hit() > CombatState.ENERGY_PER_HIT, "Kindling changes gain only while equipped")
	check(state.acquire("focus"), "Acquiring a third fitil does not require free equip capacity")
	var full_loadout: Array = state.equipped.duplicate()
	check(not state.equip("focus", true) and state.equipped == full_loadout, "Over-capacity equip fails without silently replacing another fitil")
	check(not state.unequip("reach", false) and state.has_fitil("reach"), "Unequipping also requires a bench")
	check(state.unequip("reach", true) and state.reach_multiplier() == 1.0, "Unequipping removes the effect immediately")
	check(state.equip("focus", true), "Space released at a bench can be reused")
	check(state.focus_duration_multiplier() < 1.0, "Equipped focus shortens treatment duration")
	record("bench_only_loadouts_and_capacity", prior)

	prior = failures.size()
	check(state.increase_capacity("capacity_area03"), "An earned capacity pickup increases capacity")
	check(state.capacity == 4, "Capacity pickup changes the allowance once")
	check(not state.increase_capacity("capacity_area03") and state.capacity == 4, "Reloading or revisiting the same capacity pickup cannot farm it")
	check(not state.increase_capacity("invalid_capacity", -1), "Negative capacity awards are rejected")
	check(not state.increase_capacity("oversized_capacity", CombatState.MAX_CAPACITY), "Oversized capacity awards are rejected")
	check(not state.collected.has("invalid_capacity") and not state.collected.has("oversized_capacity"), "Invalid awards do not consume pickup identities")
	check(state.unequip("wick", true) and state.equip("reach", true), "Expanded capacity permits a genuinely different combination")
	check(state.used_capacity() == 4 and state.has_fitil("reach") and state.has_fitil("focus"), "Two cost-two fitils fit after an upgrade")
	check(not state.equip("wick", true), "Expanded capacity still has a limit")
	record("persistent_capacity_pickups", prior)

	prior = failures.size()
	check(state.collect_currency("room02_larva_first_reward", 27), "A currency source can pay its first reward")
	check(not state.collect_currency("room02_larva_first_reward", 27) and state.wallet == 27, "The same reward identity never pays twice")
	check(not state.collect_currency("negative", -1), "Negative currency rewards are rejected")
	check(not state.collect_currency("zero", 0), "Zero currency awards do not consume a pickup")
	check(not state.collect_currency("huge", CombatState.MAX_WALLET + 1), "An oversized currency reward is rejected before addition")
	check(not state.collect_currency("", 1), "Empty pickup identities are rejected")
	check(not state.collect_currency("bad\nclaim", 1), "Control-character pickup identities are rejected")
	check(state.collect_currency("negative", 3) and state.wallet == 30, "A previously rejected identity can later be used by a valid reward")
	var loaded = CombatState.new()
	loaded.restore(JSON.parse_string(JSON.stringify(state.serialize())))
	check(loaded.wallet == 30 and not loaded.collect_currency("room02_larva_first_reward", 27), "Currency claims survive a real JSON round trip")
	check(loaded.capacity == 4 and loaded.equipped == state.equipped, "JSON loading restores the earned loadout and capacity")
	check(not loaded.increase_capacity("capacity_area03"), "Capacity claims also survive a JSON round trip")
	record("reward_identity_and_json_reload", prior)

	prior = failures.size()
	loaded.dash_owned = true
	loaded.spell_owned = true
	var retained_owned: Array = loaded.owned.duplicate()
	var retained_equipped: Array = loaded.equipped.duplicate()
	var retained_claims: Array = loaded.collected.duplicate()
	loaded.drop_on_death(2, Vector2(1150, 1260))
	check(loaded.wallet == 0 and int(loaded.death_drop.amount) == 30, "Death transfers carried money into one recoverable pile")
	check(int(loaded.death_drop.room) == 2 and loaded.death_drop.position == [1150.0, 1260.0], "The pile records its actual room and location")
	check(loaded.owned == retained_owned and loaded.equipped == retained_equipped and loaded.collected == retained_claims, "Death preserves fitils, chosen loadout and pickup history")
	check(loaded.dash_owned and loaded.spell_owned and loaded.capacity == 4, "Death preserves permanent abilities and capacity")
	var after_death = CombatState.new()
	after_death.restore(JSON.parse_string(JSON.stringify(loaded.serialize())))
	check(after_death.wallet == 0 and after_death.death_drop == loaded.death_drop, "An unrecovered pile persists after quitting and loading")
	check(after_death.recover_drop() == 30 and after_death.wallet == 30, "Reaching the pile restores exactly the dropped wallet")
	check(after_death.recover_drop() == 0 and after_death.wallet == 30, "A recovered pile cannot pay twice")
	loaded.drop_on_death(3, Vector2(510, 900))
	check(loaded.death_drop.is_empty() and loaded.wallet == 0, "A second death with an empty wallet still destroys the previous pile")
	check(loaded.collect_currency("room03_coin", 7), "New money can be earned after death")
	loaded.drop_on_death(3, Vector2(510, 900))
	check(int(loaded.death_drop.amount) == 7 and int(loaded.death_drop.room) == 3, "A later death creates only the currently carried money")
	check(loaded.recover_drop() == 7 and loaded.wallet == 7, "New pile recovery does not resurrect lost older money")
	check(loaded.collect_currency("room03_more_coin", 5), "More money can be earned between deaths")
	loaded.drop_on_death(3, Vector2(520, 900))
	check(loaded.collect_currency("room03_after_coin", 2), "Currency can coexist with an unrecovered pile")
	loaded.drop_on_death(4, Vector2(210, 1260))
	check(int(loaded.death_drop.amount) == 2 and loaded.recover_drop() == 2, "Second death replaces rather than merges an old pile")
	record("death_recovery_and_second_death", prior)

	prior = failures.size()
	var malformed = CombatState.new()
	malformed.restore({"wallet": -5, "capacity": 3, "dash_owned": "true", "spell_owned": 1, "owned": ["reach", "reach", "focus", "not_real", 3], "equipped": ["reach", "reach", "focus", "wick"], "collected": ["valid", "valid", "", 5, " bad "]})
	check(malformed.wallet == 0 and not malformed.dash_owned and not malformed.spell_owned, "Malformed numeric and boolean fields cannot invent currency or abilities")
	check(malformed.owned == ["reach", "focus"], "Unknown and duplicate fitils are removed from restored inventory")
	check(malformed.equipped == ["reach"] and malformed.used_capacity() <= malformed.capacity, "Restored equipment must be owned, unique and within capacity")
	check(malformed.collected == ["valid"], "Invalid or duplicate pickup identities are removed")
	malformed.restore({"wallet": 1e30, "capacity": 1e30, "death_drop": {"room": 2, "position": [1, 2], "amount": 1e30}})
	check(malformed.wallet == 0 and malformed.capacity == CombatState.BASE_CAPACITY and malformed.death_drop.is_empty(), "Out-of-range floats are rejected before integer conversion")
	malformed.restore({"wallet": 1.5, "capacity": 4.5})
	check(malformed.wallet == 0 and malformed.capacity == CombatState.BASE_CAPACITY, "Fractional currency and capacity cannot be truncated into rewards")
	malformed.restore({"wallet": "17", "capacity": "7"})
	check(malformed.wallet == 0 and malformed.capacity == CombatState.BASE_CAPACITY, "String numbers do not bypass save validation")
	malformed.restore({"wallet": NAN, "capacity": INF, "death_drop": {"room": 2, "position": [NAN, 2], "amount": 4}})
	check(malformed.wallet == 0 and malformed.capacity == CombatState.BASE_CAPACITY and malformed.death_drop.is_empty(), "Non-finite values never enter live wallet, capacity or position")
	for bad_drop in [
		{"room": 0, "position": [1, 2], "amount": 4},
		{"room": 16, "position": [1, 2], "amount": 4},
		{"room": 2, "position": ["1", 2], "amount": 4},
		{"room": 2, "position": [1, 2, 3], "amount": 4},
		{"room": 2, "position": [1000000, 2], "amount": 4},
		{"room": 2, "position": [1, 2], "amount": -4}]:
		malformed.restore({"death_drop": bad_drop})
		check(malformed.death_drop.is_empty(), "Invalid pile is discarded: " + str(bad_drop))
	malformed.restore({"wallet": 17.0, "capacity": 4.0, "death_drop": {"room": 2.0, "position": [10, 20], "amount": 3.0}})
	check(malformed.wallet == 17 and malformed.capacity == 4 and int(malformed.death_drop.amount) == 3, "Integral JSON numeric values are accepted")
	malformed.restore({})
	check(malformed.wallet == 0 and malformed.capacity == CombatState.BASE_CAPACITY and malformed.death_drop.is_empty() and malformed.owned.is_empty(), "Restoring an empty record does not retain the prior session")
	malformed.restore({"schema": 999, "wallet": 123})
	check(malformed.wallet == 0, "Unsupported save schemas cannot silently grant progress")
	record("malformed_and_future_save_validation", prior)

	prior = failures.size()
	var source = state.serialize()
	var detached = CombatState.new()
	detached.restore(source)
	source.owned.clear()
	source.equipped.clear()
	source.collected.clear()
	check(not detached.owned.is_empty() and not detached.equipped.is_empty() and not detached.collected.is_empty(), "Restored arrays do not alias a mutable decoded save")
	var output = detached.serialize()
	output.owned.clear()
	output.equipped.clear()
	output.collected.clear()
	check(not detached.owned.is_empty() and not detached.equipped.is_empty() and not detached.collected.is_empty(), "Returned save arrays do not alias live inventory")
	detached.wallet = CombatState.MAX_WALLET
	check(not detached.collect_currency("wallet_overflow", 1) and detached.wallet == CombatState.MAX_WALLET, "Adding at the technical ceiling cannot overflow")
	detached.death_drop = {"room": 2, "position": [10, 20], "amount": 3}
	check(detached.recover_drop() == 0 and not detached.death_drop.is_empty(), "A capped wallet leaves its pile recoverable instead of deleting money")
	detached.wallet -= 3
	check(detached.recover_drop() == 3 and detached.death_drop.is_empty(), "Pile remains recoverable after space becomes available")
	var many_claims: Array = []
	for i in range(CombatState.MAX_CLAIMS + 40):
		many_claims.append("claim_%s" % i)
	detached.restore({"collected": many_claims})
	check(detached.collected.size() == CombatState.MAX_CLAIMS, "Restoration bounds claim history storage")
	check(not detached.collect_currency("new_claim", 1) and detached.wallet == 0, "A full history fails closed instead of allowing untracked reward farming")
	record("save_ownership_and_technical_bounds", prior)

	var report := {"engine": Engine.get_version_info().string, "checks": checks, "failures": failures, "scenarios": scenarios, "touches_user_save_files": false}
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print("M18 STATE REPORT checks=", checks, " failures=", failures.size(), " path=", REPORT)
	quit(0 if failures.is_empty() else 1)
