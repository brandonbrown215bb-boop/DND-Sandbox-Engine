extends Node

func _ready() -> void:
	GameManager.test_mode = true
	TetherGroupChecks.load_fixtures()
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://tether_group_manifest.json"))
	if not manifest is Dictionary or int(manifest.get("pid", 0)) == OS.get_process_id(): return _fail("Recovery requires a separate process")
	if not SaveManager.load_game(TetherGroupFlow.SLOT): return _fail("Allowed tether checkpoint refused")
	var caster: Character = PartyManager.characters.get(str(manifest.caster))
	var first: Character = PartyManager.characters.get(str(manifest.first))
	var second: Character = PartyManager.characters.get(str(manifest.second))
	var helper: Character = PartyManager.characters.get(str(manifest.helper))
	if caster == null or first == null or second == null or helper == null: return _fail("Missing tether participant")
	var source := str(manifest.source)
	var relation := str(manifest.remaining)
	if caster.spell_cast_serial != int(manifest.serial) or int(caster.spell_slots.get("1", -1)) != 1 or caster.tethers.size() != 1 or not caster.tethers.has(relation) or caster.tethers.has(str(manifest.released)) or int(caster.tethers[relation].hp) != 3 or not TetherRules.binding(first, [caster]).is_empty() or not first.spell_effects.is_empty() or not TetherRules.has_source(second, source) or int(second.spell_effects[source].remaining_seconds) != 48: return _fail("Recovery changed identity, HP, original lifetime, payment or released state")
	if TetherRules.rescue(helper, second, [caster], "strike", str(manifest.released)).get("attempted", false) or TetherRules.rescue(helper, second, [caster], "strike", source).get("attempted", false): return _fail("Stale/parent selection fell through to recovered sibling")
	GameManager.advance_campaign_time(6)
	if int(second.spell_effects[source].remaining_seconds) != 42 or int(caster.tethers[relation].hp) != 3 or int(caster.spell_slots["1"]) != 1: return _fail("Recovered lifetime or damage reset")
	SpellEffects.clear_source_end_events()
	SpellEffects.remove(caster, source)
	SpellEffects.remove(caster, source)
	SpellEffects.end_concentration(caster, [first, second])
	if not caster.tethers.is_empty() or not caster.concentrating_on.is_empty() or TetherRules.has_source(second, source) or SpellEffects.source_end_events().filter(func(e): return e.source_id == source).size() != 1 or int(caster.spell_slots["1"]) != 1: return _fail("Recovered parent cleanup did not settle remaining relation exactly once")
	print("TETHER GROUP FRESH-PROCESS RECOVERY PASSED")
	get_tree().quit()

func _fail(message: String) -> void:
	push_error("[TetherGroupRecovery] " + message)
	get_tree().quit(1)
