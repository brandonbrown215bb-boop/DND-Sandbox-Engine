## Normal player controls plus an optional separate-process checkpoint reader.
class_name ConversionBatch001Flow
extends RefCounted

const SLOT := "conversion_batch_001"

static func _select(h, combat, caster: Character, id: String, slot: int) -> void:
	combat._on_hud_action("cancel", {})
	combat.current_player_idx = 0
	combat.active_character = caster
	combat.active_combatant = {"is_player": true, "entity": caster}
	combat.turn_budget.reset(caster, combat.player_entities)
	combat.remaining_attack_swings = 0
	combat.hud.update_hud(caster, combat.tracker)
	combat.hud._show_spell_selection()
	var index := -1
	for i in combat.hud.spells_registered.size():
		if str(combat.hud.spells_registered[i].get("id", "")) == id: index = i
	h._assert(index >= 0 and not combat.hud.spell_list.is_item_disabled(index), "Conversion 001: %s is available through the real spell picker" % id)
	if index < 0: return
	combat.hud._on_spell_selected(index)
	combat.pending_spell_data["_selected_spell_slot_level"] = slot

static func _prepare(caster: Character, wanted: Array[String]) -> bool:
	var chosen: Array[String] = []
	for id in caster.get_spell_option_ids(true).slice(0, caster.get_spellcasting_capacity("cantrips")): chosen.append(id)
	var spells := wanted.duplicate()
	for id in caster.get_spell_option_ids(false):
		if spells.size() >= caster.get_spellcasting_capacity("prepared_spells"): break
		if id not in spells: spells.append(id)
	chosen.append_array(spells)
	return ClassProgression.choose_spell_selection(caster, chosen)

static func run(h) -> void:
	h._enter_test("conversion_batch_001_flow")
	if OS.get_environment("CONVERSION_BATCH_001_RECOVER") == "1":
		_recover(h)
		h._exit_test()
		return
	h._setup_world()
	var caster := ConversionBatch001Checks.actor("conversion-live-caster", "cleric", 5)
	var ally := ConversionBatch001Checks.actor("conversion-live-ally", "fighter", 5)
	caster.inventory.add_item("component_pouch")
	caster.inventory.add_item("holy_symbol")
	caster.inventory.unequip(Inventory.Slot.WEAPON)
	h._assert(_prepare(caster, ["bless", "bane", "mass_healing_word"]), "Conversion 001: production class choices prepare all three real spells")
	PlayerManager.set_player_character(0, caster)
	PlayerManager.set_player_character(1, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, caster)
	PartyManager.register_player_character(1, ally)
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	combat.player_entities[1].hex_position = Vector2i(1, 0)
	combat.monster_entities.clear()
	for i in 5:
		combat.monster_entities.append({"id": "conversion-live-%d" % i, "name": "Candidate %d" % i, "creature_type": "beast", "hex_position": Vector2i(i % 3, 1 + i / 3), "is_alive": true, "current_hp": 1, "max_hp": 100, "temp_hp": 0, "armor_class": 10, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "damage_resistances": [], "saving_throw_bonuses": {"CHA": -1000 if i == 0 else 1000}, "spell_slots": {}})
	combat._update_grid_entities()
	GameManager.test_mode = false
	_select(h, combat, caster, "bless", 1)
	await combat._on_hex_clicked(Vector2i(1, 0))
	var slots := int(caster.spell_slots["1"])
	combat._on_hud_action("cancel", {})
	h._assert(int(caster.spell_slots["1"]) == slots and combat.turn_budget.action_available and not ally.has_condition("blessed"), "Conversion 001: cancelling a selected Bless spends nothing")
	ally.current_hp = 0
	ally.is_alive = false
	_select(h, combat, caster, "bless", 2)
	ally.death_save_failures = 3
	await combat._on_hex_clicked(Vector2i(1, 0))
	h._assert(combat.pending_command_target_coords.is_empty(), "Conversion 001: ordinary Bless refuses a dead creature")
	ally.death_save_failures = 0
	await combat._on_hex_clicked(Vector2i(1, 0))
	await combat._on_hex_clicked(Vector2i(1, 0))
	h._assert(ally.has_condition("blessed") and caster.concentrating_on.get("targets", []).size() == 1 and int(caster.spell_slots["2"]) == 2 and not combat.turn_budget.action_available, "Conversion 001: upcast Bless accepts one already-downed creature and pays once")
	var bless_source := str(caster.concentrating_on.get("effect_source", ""))
	_select(h, combat, caster, "bane", 2)
	var failed: Dictionary = combat.monster_entities[0]
	var saved: Dictionary = combat.monster_entities[1]
	await combat._on_hex_clicked(failed.hex_position)
	await combat._on_hex_clicked(saved.hex_position)
	var original_charisma := ally.ability_scores.charisma
	ally.ability_scores.charisma = -100
	await combat._on_hex_clicked(Vector2i(1, 0))
	await combat._on_hex_clicked(Vector2i(1, 0))
	ally.ability_scores.charisma = original_charisma
	h._assert(CombatAction.has_condition(failed, "baned") and ally.has_condition("baned") and not CombatAction.has_condition(saved, "baned") and not ally.has_condition("blessed") and not SpellEffects.records(ally).has(bless_source), "Conversion 001: mixed Bane saves include a downed creature and replace earlier concentration exactly")
	# A downed creature must be selectable first, including when invisible.
	ally.current_hp = 0
	ally.is_alive = false
	ally.add_condition("invisible", 10)
	_select(h, combat, caster, "mass_healing_word", 3)
	await combat._on_hex_clicked(Vector2i(1, 0))
	h._assert(combat.pending_command_target_coords.size() == 1, "Conversion 001: a downed ally can be the first multi-healing recipient")
	slots = int(caster.spell_slots["3"])
	await combat._on_hex_clicked(Vector2i(1, 0))
	h._assert(ally.current_hp == 0 and int(caster.spell_slots["3"]) == slots and combat.turn_budget.bonus_action_available, "Conversion 001: an invisible downed recipient refuses before payment")
	combat._on_hud_action("cancel", {})
	ally.remove_condition("invisible")
	_select(h, combat, caster, "mass_healing_word", 3)
	await combat._on_hex_clicked(Vector2i(1, 0))
	for i in 5: await combat._on_hex_clicked(combat.monster_entities[i].hex_position)
	h._assert(ally.current_hp > 0 and ally.is_alive and combat.monster_entities.all(func(m): return int(m.current_hp) > 1), "Conversion 001: six chosen recipients include a downed ally and nonparty creatures")
	h._assert(int(caster.spell_slots["3"]) == slots - 1 and not combat.turn_budget.bonus_action_available, "Conversion 001: six-target healing pays one slot and one Bonus Action")
	# The existing preflight must also reject forged/stale recipient lists.
	_select(h, combat, caster, "mass_healing_word", 3)
	var chosen: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0)]
	for m in combat.monster_entities: chosen.append(m.hex_position)
	slots = int(caster.spell_slots["3"])
	await combat._execute_player_spell(chosen[0], Vector2i(9999, 9999), chosen)
	h._assert(int(caster.spell_slots["3"]) == slots and combat.turn_budget.bonus_action_available, "Conversion 001: seven-recipient healing refuses before payment")
	_select(h, combat, caster, "mass_healing_word", 3)
	var stale: SpellCastContext = combat._spell_cast_context(Vector2i(1, 0))
	stale.extra_target_coords.assign([Vector2i(1, 0), Vector2i(200, 200)])
	h._assert(not SpellCastValidation.validate_creatures_and_components(stale) and int(caster.spell_slots["3"]) == slots, "Conversion 001: a stale out-of-range recipient refuses without spending")
	_select(h, combat, caster, "bless", 1)
	await combat._on_hex_clicked(Vector2i(1, 0))
	await combat._on_hex_clicked(Vector2i(1, 0))
	ally.current_hp = 1
	ClassFeature.execute(ally, ally.get_feature("fighter_second_wind"))
	var spent_uses := int(ally.feature_uses.fighter_second_wind)
	SpellEffects.advance_time([caster, ally], 13)
	var source := str(caster.concentrating_on.get("effect_source", ""))
	h._assert(not source.is_empty() and int(ally.spell_effects.get(source, {}).get("remaining_seconds", 0)) == 47, "Conversion 001: the actual cast retains its partially elapsed source")
	SpellEffects.finish_encounter([caster, ally], combat._spell_effect_targets())
	h._teardown_scene(combat)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.test_mode = true
	GameManager.game_in_progress = true
	var wrote := SaveManager.save_game(SLOT)
	h._assert(wrote, "Conversion 001: the actual spell and spent Second Wind save at a supported checkpoint")
	if not wrote or source.is_empty():
		h._exit_test()
		return
	var dto := SaveManager._read_save(SLOT)
	h._assert(SaveManager._validate_save_data(dto).is_empty(), "Conversion 001: party checkpoint passes production preflight")
	var player_only := dto.duplicate(true)
	player_only.erase("party")
	h._assert(SaveManager._validate_save_data(player_only).is_empty(), "Conversion 001: player-only checkpoint passes production preflight")
	var party_bad := dto.duplicate(true)
	party_bad.party.characters[ally.character_id].spell_effects[source].remaining_seconds = "forever"
	var player_bad := player_only.duplicate(true)
	player_bad.players[1].character.spell_effects[source].remaining_seconds = "forever"
	h._assert(not SaveManager._validate_save_data(party_bad).is_empty() and not SaveManager._validate_save_data(player_bad).is_empty() and PartyManager.characters[ally.character_id] == ally, "Conversion 001: both malformed duration DTOs refuse without replacing the session")
	h._assert(SaveManager.load_game(SLOT), "Conversion 001: actual disk checkpoint reloads")
	var restored: Character = PartyManager.characters[ally.character_id]
	h._assert(restored.has_condition("blessed") and int(restored.spell_effects[source].remaining_seconds) == 47 and int(restored.feature_uses.fighter_second_wind) == spent_uses, "Conversion 001: reload preserves duration, identity and spent resource without replay")
	print("CONVERSION_BATCH_001_CHECKPOINT_READY")
	h._exit_test()

static func _recover(h) -> void:
	h._assert(SaveManager.load_game(SLOT), "Conversion 001: a fresh process loads the real checkpoint")
	var caster: Character = PartyManager.characters.get("conversion-live-caster")
	var ally: Character = PartyManager.characters.get("conversion-live-ally")
	if caster == null or ally == null:
		h._assert(false, "Conversion 001: both original actor identities recover")
		return
	var source := str(caster.concentrating_on.get("effect_source", ""))
	h._assert(ally.has_condition("blessed") and int(ally.spell_effects.get(source, {}).get("remaining_seconds", 0)) == 47 and caster.concentrating_on.get("targets", []).has(ally), "Conversion 001: fresh-process recovery rebinds the same partially elapsed concentration source")
	h._assert(int(ally.feature_uses.fighter_second_wind) == ally.get_feature_max_uses("fighter_second_wind") - 1, "Conversion 001: fresh-process recovery does not refill Second Wind")
	GameManager.advance_campaign_time(47)
	h._assert(not ally.has_condition("blessed") and caster.concentrating_on.is_empty(), "Conversion 001: recovered Bless expires without replay")
