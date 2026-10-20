extends Node

func _ready() -> void:
	call_deferred("_recover")

func _recover() -> void:
	Batch032Checks.load_fixtures()
	var rolls := [0]
	var observe := func(_details: Dictionary): rolls[0] += 1
	Dice.dice_rolled.connect(observe)
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://batch_032_manifest.json"))
	if OS.get_environment("B032_RELAUNCH_PHASE") != "recover" or not manifest is Dictionary or not SaveManager.load_game("batch_032_responses"):
		_fail("could not load allowed checkpoint")
		return
	var a: Character = PartyManager.characters.get(str(manifest.target_id))
	var b: Character = PartyManager.characters.get(str(manifest.owner_id))
	var slots_match: bool = b != null and b.spell_slots.size() == manifest.slots.size()
	if b != null:
		for key in manifest.slots:
			if not b.spell_slots.has(key) or int(b.spell_slots[key]) != int(manifest.slots[key]): slots_match = false
	if a == null or b == null or SpellEffects.records(a) != manifest.sources or a.current_hp != int(manifest.hp) or not slots_match or b.spell_cast_serial != int(manifest.cast_serial) or OS.get_process_id() == int(manifest.pid) or rolls[0] != 0:
		_fail("source/recipient/policy/deadline/HP/payment changed on recovery: actual=%s expected=%s HP=%s/%s slots=%s/%s" % [JSON.stringify(SpellEffects.records(a)) if a != null else "missing", JSON.stringify(manifest.sources), str(a.current_hp) if a != null else "missing", str(manifest.hp), JSON.stringify(b.spell_slots) if b != null else "missing", JSON.stringify(manifest.slots)])
		return
	var before := a.current_hp
	var result := CombatAction.resolve_damage(a, 7, "fire", {}, false, false, b)
	Dice.dice_rolled.disconnect(observe)
	if a.current_hp != mini(a.max_hp, before + 10) or result.replacement_receipts.size() != 1 or result.countereffect_receipts.size() != 1 or rolls[0] != 0:
		_fail("recovered sources did not execute exactly once on fresh damage")
		return
	print("BATCH 032 FRESH RELAUNCH PASSED: parent=%d pid=%d zero RNG; exact source policies, owners, deadlines, HP, slots and fresh occurrence" % [int(manifest.pid), OS.get_process_id()])
	get_tree().quit(0)

func _fail(message: String) -> void:
	printerr("BATCH 032 FRESH RELAUNCH FAILED: " + message)
	get_tree().quit(1)
