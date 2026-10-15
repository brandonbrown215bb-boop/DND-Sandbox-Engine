extends SceneTree

const SLOT := "s026_relationship_willingness"

func _initialize() -> void:
	call_deferred("_recover")

func _recover() -> void:
	var phase := OS.get_environment("S026_RELATIONSHIP_RELAUNCH_PHASE")
	if phase != "recover":
		_fail("unexpected fresh-process phase: %s" % phase)
		return
	var data_loader = root.get_node("DataLoader")
	data_loader._load_content_type("res://data/fixtures/shared_spells/spells/", "spell")
	var wizard_def: Dictionary = data_loader.classes.get("wizard", {})
	var spell_list: Array = wizard_def.get("spell_list_ids", [])
	for spell_id in ["sandbox:relationship_neutral", "sandbox:relationship_renamed"]:
		if spell_id not in spell_list:
			spell_list.append(spell_id)
	wizard_def["spell_list_ids"] = spell_list
	data_loader.classes["wizard"] = wizard_def
	if not root.get_node("SaveManager").load_game(SLOT):
		_fail("fresh Godot process could not load the willingness save")
		return
	var characters: Dictionary = root.get_node("PartyManager").characters
	var giver_a = characters.get("s026-giver-a")
	var giver_b = characters.get("s026-giver-b")
	var ally = characters.get("s026-ally")
	if giver_a == null or giver_b == null or ally == null:
		_fail("fresh process did not restore all three authoritative Characters")
		return
	if giver_a.willingness != "unknown" or giver_b.willingness != "unknown" or ally.willingness != "unwilling":
		_fail("Character Sheet values changed after fresh process: A=%s B=%s ally=%s" % [giver_a.willingness, giver_b.willingness, ally.willingness])
		return
	print("S026 RELAUNCH PASSED: both givers unknown, ally unwilling")
	quit(0)

func _fail(message: String) -> void:
	printerr("S026 RELAUNCH FAILED: %s" % message)
	quit(1)
