extends Node

func _ready() -> void:
	call_deferred("_recover")

func _recover() -> void:
	Batch033Checks.load_fixtures()
	var rolls := [0]
	var observe := func(_details: Dictionary): rolls[0] += 1
	Dice.dice_rolled.connect(observe)
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://batch_033_manifest.json"))
	if OS.get_environment("B033_RELAUNCH_PHASE") != "recover" or not manifest is Dictionary or not SaveManager.load_game("batch_033_history"):
		fail("could not load checkpoint")
		return
	var a: Character = PartyManager.characters.get(str(manifest.target_id))
	if a == null or a.zero_hp_history != manifest.history or a.numeric_resource_pools != manifest.pools or a.current_hp != int(manifest.hp) or rolls[0] != 0 or OS.get_process_id() == int(manifest.pid) or not SpellDamageRolls._pending_requests.is_empty():
		fail("history/source/reset/payment/HP changed or recovery rolled")
		return
	# A new occurrence uses recovered DC/reset state and existing fuel, with no
	# acquisition call. Only this occurrence may roll or spend.
	var fuel: int = ResourcePoolRules.availability(a, "b033:pool").current
	a.current_hp = 3
	var receipt: Dictionary = CombatAction.resolve_damage(a, 7, "fire", Batch033Checks.choice(a)).zero_hp_receipt
	if receipt.is_empty() or receipt.saves[0].dc != 10 or a.current_hp != 6 or a.zero_hp_history["b033:stand"].attempts != 1 or a.zero_hp_history["b033:anchor"].attempts != 1 or ResourcePoolRules.availability(a, "b033:pool").current != fuel - 1:
		fail("new occurrence did not retain recovered DC/reset/sibling/payment state: " + JSON.stringify(receipt))
		return
	# A recovered attempt after the declared rest is in that same reset
	# generation. Its current count cannot be replaced with zero on either DTO.
	if not SaveManager.save_game("batch_033_recovered_attempt"):
		fail("recovered valid attempt could not checkpoint")
		return
	var retained_history := a.zero_hp_history.duplicate(true)
	var retained_pools := a.numeric_resource_pools.duplicate(true)
	for route in ["party", "players"]:
		var bad: Dictionary = SaveManager._read_save("batch_033_recovered_attempt").duplicate(true)
		var dto: Dictionary = bad.party.characters[a.character_id] if route == "party" else bad.players[0].character
		dto.zero_hp_history["b033:stand"].attempts = 0
		var file := FileAccess.open(SaveManager.SAVE_DIR + "batch_033_recovered_bad.sav", FileAccess.WRITE)
		file.store_string(JSON.stringify(bad))
		file.close()
		if SaveManager.load_game("batch_033_recovered_bad") or PartyManager.characters.get(a.character_id) != a or a.zero_hp_history != retained_history or a.numeric_resource_pools != retained_pools:
			fail("post-reset recovered count corruption accepted on " + route)
			return
	print("B033 R2 RECOVERED COUNT REFUSALS PASSED: both DTO paths preserve live state")
	print("B033 RECOVERED NEW ATTEMPT ", JSON.stringify(receipt))
	print("BATCH 033 FRESH RELAUNCH PASSED: parent=%d pid=%d zero RNG; exact attempts, DC policies, reset stamps, source identity, payments and HP" % [int(manifest.pid), OS.get_process_id()])
	Dice.dice_rolled.disconnect(observe)
	get_tree().quit(0)

func fail(message: String) -> void:
	printerr("BATCH 033 FRESH RELAUNCH FAILED: " + message)
	get_tree().quit(1)
