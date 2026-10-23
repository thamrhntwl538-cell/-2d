extends SceneTree
## Reward ledger + genuine physical coin callbacks, using an isolated wallet.
## Campaign floor selection and Input routes are covered by the M22 world QA.
const Ledger = preload("res://scripts/combat/m22_currency_ledger.gd")
const Coin = preload("res://scripts/combat/m22_coin.gd")
const CombatState = preload("res://scripts/combat/m18_combat_state.gd")

var checks: int = 0
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var world: FixtureWorld

class FixtureWorld extends Node2D:
	var hero: Node2D
	var gameplay_active: bool = true
	var accept_pickup: bool = true
	var progress: Dictionary = {}
	var wallet = CombatState.new()
	var claims: int = 0
	var callback_attempts: int = 0
	func collect_world_coin(definition: Dictionary) -> bool:
		callback_attempts += 1
		if not gameplay_active or not accept_pickup:
			return false
		# The node cannot choose its payout by changing the visible definition.
		var amount: int = Ledger.claim(progress, str(definition.get("reward_id", "")), int(definition.get("coin_index", -1)))
		if amount <= 0:
			return false
		wallet.wallet += amount
		claims += 1
		return true

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		print("FAIL ", description)

func step(count: int) -> void:
	for tick in range(count):
		await physics_frame
	await process_frame

func amount_sum(definitions: Array) -> int:
	var total: int = 0
	for definition in definitions:
		total += int(definition.amount)
	return total

func coin_nodes() -> Array[Node]:
	var result: Array[Node] = []
	for coin in get_nodes_in_group("m22_coins"):
		if coin.get_parent() == world:
			result.append(coin)
	return result

func clear_coins() -> void:
	for coin in coin_nodes():
		coin.queue_free()
	await step(2)

func spawn(definitions: Array) -> void:
	for definition in definitions:
		var coin := Coin.new()
		world.add_child(coin)
		coin.setup(world, definition)

func solid_rect(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.position = rect.get_center()
	body.add_child(collision)
	world.add_child(body)
	return body

func run_checks() -> void:
	var progress: Dictionary = {"unrelated_story_flag": true}
	Ledger.sanitize(progress)
	check(progress.currency_rewards.is_empty() and progress.unrelated_story_flag, "an old save gains an empty ledger without changing story progress")
	var earned: Array[Dictionary] = Ledger.create_reward(progress, "enemy:opening_larva", 1, Vector2(300, 600), 12)
	check(earned.size() == 4 and amount_sum(earned) == 12, "a 12-coin enemy reward splits into four actual three-value discs")
	check(Ledger.room_pending(progress, 2).is_empty(), "another room does not materialize this reward")
	check(Ledger.create_reward(progress, "enemy:opening_larva", 8, Vector2(800, 900), 999) == earned, "repeating the source cannot change its room, positions, or payout")
	var external: Array[Dictionary] = earned.duplicate(true)
	external[0].position[0] = -999
	external[0].amount = 999
	check(Ledger.room_pending(progress, 1)[0].position[0] == 272.0 and Ledger.room_pending(progress, 1)[0].amount == 3, "returned definitions cannot mutate saved amounts or anchors")
	check(Ledger.claim(progress, "enemy:opening_larva", 0) == 3, "the first physical claim returns its exact denomination")
	check(Ledger.claim(progress, "enemy:opening_larva", 0) == 0, "the same source and index cannot be claimed twice")
	check(Ledger.claim(progress, "enemy:opening_larva", -1) == 0 and Ledger.claim(progress, "enemy:opening_larva", 10) == 0 and Ledger.claim(progress, "missing", 0) == 0, "invalid indices and missing rewards pay nothing")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(progress))
	Ledger.sanitize(restored)
	check(Ledger.room_pending(restored, 1).size() == 3 and amount_sum(Ledger.room_pending(restored, 1)) == 9, "JSON round-trip restores only the nine uncollected coins")
	check(Ledger.create_reward(restored, "enemy:opening_larva", 1, Vector2.ZERO, 12).size() == 3, "revisiting a defeated source restores pending coins without duplicating spent ones")
	var full_total: int = 3
	for definition in Ledger.room_pending(restored, 1):
		full_total += Ledger.claim(restored, definition.reward_id, definition.coin_index)
	check(full_total == 12 and Ledger.room_pending(restored, 1).is_empty(), "collecting the remaining discs conserves the original reward")
	var collected_reload: Dictionary = JSON.parse_string(JSON.stringify(restored))
	check(Ledger.create_reward(collected_reload, "enemy:opening_larva", 1, Vector2(300, 600), 12).is_empty(), "fully collected source remains a spent receipt after save/load")
	for total in [1, 2, 3, 12, 15, 19, Ledger.MAX_REWARD]:
		var split: Array[Dictionary] = Ledger.create_reward(progress, "test:denomination_" + str(total), 3, Vector2(500, 600), total)
		check(split.size() <= Ledger.MAX_COINS and amount_sum(split) == total, "bounded disc count conserves denomination " + str(total))
	check(Ledger.create_reward(progress, "bad:room", 0, Vector2.ZERO, 12).is_empty() and Ledger.create_reward(progress, "bad:amount", 1, Vector2.ZERO, -1).is_empty(), "invalid new rewards are rejected")
	check(Ledger.create_reward(progress, "bad:position", 1, Vector2(NAN, 0), 12).is_empty() and Ledger.create_reward(progress, "bad:id\n", 1, Vector2.ZERO, 12).is_empty(), "non-finite anchors and control characters are rejected")
	var malformed: Dictionary = {Ledger.KEY: {"valid:corrupt": {"schema": 1, "room": 1, "total": 12, "coins": [{"amount": 12, "position": [NAN, 0], "collected": false}]}, "valid:wrong_type": 99, " bad": {}}}
	Ledger.sanitize(malformed)
	check(malformed.currency_rewards.size() == 2 and Ledger.room_pending(malformed, 1).is_empty(), "malformed existing receipts keep valid IDs but expose no unsafe pending positions")
	check(Ledger.create_reward(malformed, "valid:corrupt", 1, Vector2(300, 600), 12).is_empty() and Ledger.create_reward(malformed, "valid:wrong_type", 1, Vector2.ZERO, 12).is_empty(), "corruption cannot reopen a previously recorded source")
	var ambiguous: Dictionary = {Ledger.KEY: {"valid:ambiguous": {"schema": 1, "room": 1, "total": 3, "coins": [{"amount": 3, "position": [300, 588], "collected": "true"}]}}}
	check(Ledger.room_pending(ambiguous, 1).is_empty(), "an invalid collected flag cannot become a fresh payable coin")
	var wallet = CombatState.new()
	wallet.wallet = 37
	var death_progress: Dictionary = {}
	Ledger.create_reward(death_progress, "puzzle:uncollected", 2, Vector2(300, 600), 15)
	wallet.drop_on_death(2, Vector2(100, 600))
	check(wallet.wallet == 0 and wallet.death_drop.amount == 37 and amount_sum(Ledger.room_pending(death_progress, 2)) == 15, "death drops only held currency and leaves world pending rewards intact")
	check(wallet.recover_drop() == 37 and wallet.wallet == 37, "physical world rewards preserve the existing recoverable-wallet contract")

	world = FixtureWorld.new()
	root.add_child(world)
	world.hero = Node2D.new()
	world.hero.position = Vector2(800, 600)
	world.add_child(world.hero)
	var camera := Camera2D.new()
	camera.position = Vector2(480, 360)
	world.add_child(camera)
	solid_rect(Rect2(0, 600, 1000, 40))
	await step(3)
	var physical_reward: Array[Dictionary] = Ledger.create_reward(world.progress, "physical:opening", 1, Vector2(300, 600), 12)
	spawn(physical_reward)
	await step(12)
	check(world.wallet.wallet == 0 and coin_nodes().size() == 4, "spawning a real reward creates discs without paying the wallet")
	var arc_coin: Node2D = coin_nodes()[0]
	var arc_position: Vector2 = arc_coin.global_position
	var arc_time: float = arc_coin.spawn_time
	world.gameplay_active = false
	await step(25)
	check(arc_coin.global_position.is_equal_approx(arc_position) and is_equal_approx(arc_coin.spawn_time, arc_time), "reading/pause freezes the visual drop arc and pickup")
	world.gameplay_active = true
	await step(70)
	check(world.wallet.wallet == 0 and world.callback_attempts == 0, "distant floor coins never auto-pay after their drop settles")
	var saved_before_magnet: Array[Dictionary] = Ledger.room_pending(world.progress, 1)
	check(arc_coin.global_position.is_equal_approx(arc_coin.settled_position), "visual drop returns to the saved supported-floor anchor")
	world.hero.position = Vector2(500, 600)
	await step(20)
	check(world.wallet.wallet == 0, "walking closer but remaining outside the magnet radius does not collect")
	world.hero.position = Vector2(300, 600)
	await step(35)
	check(world.wallet.wallet == 12 and world.claims == 4 and coin_nodes().is_empty(), "walking near settled discs physically auto-collects exactly the enemy's twelve currency")
	check(Ledger.room_pending(world.progress, 1).is_empty(), "all physically collected coins become spent ledger entries")
	check(Ledger.claim(world.progress, "physical:opening", 0) == 0 and world.wallet.wallet == 12, "a repeated post-pickup callback cannot increase the wallet")
	samples.append({"case": "physical_enemy_reward", "earned": 12, "discs": 4, "claims": world.claims, "saved_floor_positions": saved_before_magnet})

	# A partial pickup must survive leaving before the rest is collected.
	world.hero.position = Vector2(500, 600)
	spawn(Ledger.create_reward(world.progress, "physical:partial", 2, Vector2(600, 600), 12))
	await step(50)
	check(world.wallet.wallet == 15 and coin_nodes().size() == 3, "the edge of the magnet picks only the reachable leftmost disc")
	await clear_coins()
	var room_exit_save: String = JSON.stringify(world.progress)
	world.progress = JSON.parse_string(room_exit_save)
	var returned: Array[Dictionary] = Ledger.room_pending(world.progress, 2)
	check(returned.size() == 3 and amount_sum(returned) == 9, "leaving and reloading retains exactly the three pending discs")
	world.hero.position = Vector2(600, 600)
	spawn(returned)
	await step(65)
	check(world.wallet.wallet == 24 and Ledger.room_pending(world.progress, 2).is_empty(), "returning to the room collects the remaining nine without re-paying the first three")

	# Rejecting a transaction keeps the coin visible and retryable.
	world.accept_pickup = false
	spawn(Ledger.create_reward(world.progress, "physical:retry", 1, Vector2(600, 600), 1))
	await step(55)
	check(world.wallet.wallet == 24 and coin_nodes().size() == 1 and amount_sum(Ledger.room_pending(world.progress, 1)) == 1, "a rejected wallet/save callback does not erase an unpaid coin")
	world.accept_pickup = true
	world.gameplay_active = false
	await step(20)
	check(world.wallet.wallet == 24, "a point-blank pending coin cannot be claimed through a paused panel")
	world.gameplay_active = true
	await step(20)
	check(world.wallet.wallet == 25 and coin_nodes().is_empty(), "the same pending coin is collected once when play and transactions resume")

	var wall := solid_rect(Rect2(303, 530, 8, 70))
	world.hero.position = Vector2(330, 600)
	spawn(Ledger.create_reward(world.progress, "physical:wall", 1, Vector2(280, 600), 1))
	await step(70)
	check(world.wallet.wallet == 25 and coin_nodes().size() == 1, "short-range attraction cannot pull a coin through a solid wall")
	wall.queue_free()
	await step(35)
	check(world.wallet.wallet == 26 and coin_nodes().is_empty(), "removing the physical obstruction makes that same pending coin collectible")

	var report := {"schema": "m22-currency-native-1", "checks": checks, "failures": failures, "samples": samples}
	var file := FileAccess.open("user://m22_currency_report.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("M22 currency: ", checks, " checks, ", failures.size(), " failures")
	world.queue_free()
	await step(2)
	quit(0 if failures.is_empty() else 1)
