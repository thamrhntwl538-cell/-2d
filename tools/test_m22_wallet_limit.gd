extends SceneTree
## Run with an isolated XDG_DATA_HOME, like the other M22 integration fixtures.
var world: Node2D
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, text: String) -> void:
	checks += 1
	if not value: failures.append(text)
func stop_audio(node: Node) -> void:
	for child in node.get_children(): stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
func run() -> void:
	world = load("res://scenes/stage_01/folding_library_m22.tscn").instantiate()
	world.restore_saved_game = false
	root.add_child(world)
	for frame in range(5): await physics_frame
	world._issue_coin_reward("test:wallet_cap",world.hero.position,3)
	var ledger = load("res://scripts/combat/m22_currency_ledger.gd")
	var pending: Array = ledger.room_pending(world.progress,1)
	check(pending.size()==1,"one pending three-coin denomination")
	world.combat_state.wallet = world.CombatState.MAX_WALLET
	check(not world.collect_world_coin(pending[0]),"full wallet rejects without claiming")
	check(ledger.room_pending(world.progress,1).size()==1,"rejected coin stays pending")
	check(world.combat_state.serialize().wallet==world.CombatState.MAX_WALLET,"full wallet serializes intact")
	world.combat_state.wallet -= 3
	check(world.collect_world_coin(pending[0]),"coin can be claimed after space is available")
	check(world.combat_state.wallet==world.CombatState.MAX_WALLET,"accepted coin fills without overflow")
	check(not world.collect_world_coin(pending[0]),"repeated callback cannot pay twice")
	check(ledger.room_pending(world.progress,1).is_empty(),"claimed receipt remains spent")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(int(saved.combat.wallet)==world.CombatState.MAX_WALLET,"disk wallet remains intact")
	check(ledger.room_pending(saved.progress,1).is_empty(),"disk receipt remains spent")
	stop_audio(world)
	OS.delay_msec(120)
	await process_frame
	world.queue_free()
	world = null
	for frame in range(4): await process_frame
	print("M22 WALLET LIMIT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
