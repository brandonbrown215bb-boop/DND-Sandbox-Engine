## Live normal-control and durable recovery checks for Conversion Batch 002.
class_name ConversionBatch002Flow
extends RefCounted

const SLOT := "conversion_batch_002"
const PLAYER_SLOT := "conversion_batch_002_player_only"

static func _select(h, combat, caster: Character, id: String, slot: int) -> void:
	ConversionBatch001Flow._select(h, combat, caster, id, slot)
	for player_index in combat.player_entities.size():
		var entity: Dictionary = combat.player_entities[player_index]
		if entity.get("character") == caster:
			combat.current_player_idx = player_index
			combat.active_character = caster
			combat.active_combatant = {"is_player": true, "entity": caster}
			combat.turn_budget.reset(caster, combat.player_entities)
			break

static func _wait_resolution(h, combat) -> void:
	for _frame in 120:
		if combat.pending_action_type.is_empty() and not combat.resolving_player_action: return
		await h.get_tree().process_frame

static func run(h) -> void:
	h._enter_test("conversion_batch_002_flow")
	var recovery_mode := OS.get_environment("CONVERSION_BATCH_002_RECOVER")
	if not recovery_mode.is_empty():
		_recover(h, recovery_mode)
		h._exit_test()
		return
	h._setup_world()
	var wizard := ConversionBatch002Checks.actor("conversion002-live-sorcerer", "sorcerer", 13)
	var bard := ConversionBatch002Checks.actor("conversion002-live-bard", "bard", 5)
	var fighter := ConversionBatch002Checks.actor("conversion002-live-fighter", "fighter", 5)
	h._assert(ConversionBatch001Flow._prepare(wizard, ["hold_monster", "circle_of_death"]), "Conversion 002: Sorcerer prepares both converted spells through ordinary class selection")
	h._assert(ConversionBatch001Flow._prepare(bard, ["cure_wounds", "healing_word"]), "Conversion 002: Bard prepares both corrected healing spells through normal class selection")
	wizard.inventory.add_item("component_pouch")
	wizard.inventory.add_item("black_pearl_powder_500gp")
	PlayerManager.set_player_character(0, wizard)
	PlayerManager.set_player_character(1, bard)
	if PlayerManager.get_player_count() < 3: PlayerManager.add_player("Fighter")
	PlayerManager.set_player_character(2, fighter)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	PartyManager.register_player_character(1, bard)
	PartyManager.register_player_character(2, fighter)
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	combat.player_entities[1].hex_position = Vector2i(1, 0)
	combat.player_entities[2].hex_position = Vector2i(2, 0)
	bard.ability_scores.wisdom = 1
	fighter.ability_scores.wisdom = 40
	bard.max_hp = 100
	bard.current_hp = 100
	fighter.max_hp = 100
	fighter.current_hp = 100
	var area_save := {"id":"conversion002-area-save", "name":"Area save", "creature_type":"beast", "hex_position":Vector2i(3, 0), "is_alive":true, "current_hp":1000, "max_hp":1000, "temp_hp":0, "armor_class":10, "conditions":{}, "condition_sources":{}, "spell_effects":{}, "damage_resistances":[], "saving_throw_bonuses":{"CON":1000}, "spell_slots":{}}
	var area_fail := {"id":"conversion002-area-fail", "name":"Area failure", "creature_type":"fiend", "hex_position":Vector2i(4, 0), "is_alive":true, "current_hp":1000, "max_hp":1000, "temp_hp":0, "armor_class":10, "conditions":{}, "condition_sources":{}, "spell_effects":{}, "damage_resistances":[], "saving_throw_bonuses":{"CON":-1000}, "spell_slots":{}}
	combat.monster_entities.clear()
	combat.monster_entities.assign([area_save, area_fail])
	combat._update_grid_entities()
	GameManager.test_mode = false

	# Hold Monster's upcast selects two visible creatures, and each save resolves independently.
	_select(h, combat, wizard, "hold_monster", 6)
	var hold_slots := int(wizard.spell_slots["6"])
	await combat._on_hex_clicked(Vector2i(1, 0))
	h._assert(int(wizard.spell_slots["6"]) == hold_slots and combat.turn_budget.action_available, "Conversion 002: first Hold Monster target click records a choice without paying early")
	await combat._on_hex_clicked(Vector2i(2, 0))
	await _wait_resolution(h, combat)
	var hold_source := str(wizard.concentrating_on.get("effect_source", ""))
	h._assert(not hold_source.is_empty() and bard.has_condition("paralyzed") and not fighter.has_condition("paralyzed") and int(wizard.spell_slots["6"]) == hold_slots - 1 and not combat.turn_budget.action_available, "Conversion 002: upcast Hold Monster applies independent failed/successful saves and pays once")
	bard.add_condition("paralyzed", 60, "conversion002:other-source")
	var held_effect: Dictionary = SpellEffects.records(bard).get(hold_source, {}).duplicate(true)
	SpellEffects.advance_time([wizard, bard, fighter], 13)
	h._assert(int(bard.spell_effects.get(hold_source, {}).get("remaining_seconds", 0)) == int(held_effect.get("remaining_seconds", 0)) - 13, "Conversion 002: the real Hold Monster source advances on the ordinary campaign clock")

	# Circle selection/cancellation and invalid center must leave costs untouched; valid sphere pays once.
	combat.turn_budget.reset(wizard, combat.player_entities)
	_select(h, combat, wizard, "circle_of_death", 7)
	var circle_slots := int(wizard.spell_slots["7"])
	var pearl_count: bool = wizard.inventory.has_item("black_pearl_powder_500gp")
	combat._on_hud_action("cancel", {})
	h._assert(int(wizard.spell_slots["7"]) == circle_slots and combat.turn_budget.action_available, "Conversion 002: cancelling Circle of Death selection spends no slot or action")
	await combat._on_hex_clicked(Vector2i(3, 0))
	h._assert(int(wizard.spell_slots["7"]) == circle_slots and combat.turn_budget.action_available, "Conversion 002: stale Circle center after cancellation cannot cast or pay")
	_select(h, combat, wizard, "circle_of_death", 7)
	await combat._on_hex_clicked(Vector2i(9999, 9999))
	h._assert(int(wizard.spell_slots["7"]) == circle_slots and wizard.inventory.has_item("black_pearl_powder_500gp") == pearl_count, "Conversion 002: invalid Circle center refuses before payment")
	await combat._on_hex_clicked(Vector2i(3, 0))
	await _wait_resolution(h, combat)
	h._assert(int(wizard.spell_slots["7"]) == circle_slots - 1 and wizard.inventory.has_item("black_pearl_powder_500gp") == pearl_count and int(area_save.current_hp) < 1000 and int(area_fail.current_hp) < int(area_save.current_hp) and not combat.turn_budget.action_available, "Conversion 002: Circle resolves a sphere with mixed CON saves, spends one slot/action, and retains its priced component")

	# Both corrections use ordinary player selection and preserve creature-type eligibility.
	# Select Bard's combatant directly; starting a monster turn here would run unrelated AI.
	for index in combat.tracker.combatants.size():
		if str(combat.tracker.combatants[index].get("name", "")) == bard.character_name:
			combat.tracker.active_index = index
			break
	combat.active_combatant = combat.tracker.get_active()
	combat.current_player_idx = 1
	combat.active_character = bard
	combat._end_concentration(wizard)
	CombatAction.remove_condition_source(bard, "conversion002:other-source", ["paralyzed"])
	combat.turn_budget.reset(bard, combat.player_entities)
	combat._update_grid_entities()
	fighter.current_hp = 0
	fighter.is_alive = false
	var cure_slots := int(bard.spell_slots["3"])
	_select(h, combat, bard, "cure_wounds", 3)
	await combat._on_hex_clicked(Vector2i(2, 0))
	await _wait_resolution(h, combat)
	h._assert(fighter.current_hp > 0 and fighter.is_alive and int(bard.spell_slots["3"]) == cure_slots - 1 and not combat.turn_budget.action_available, "Conversion 002: live Cure Wounds revives a downed ally and spends one upcast slot/action")
	combat.turn_budget.reset(bard, combat.player_entities)
	var word_slots := int(bard.spell_slots["2"])
	fighter.current_hp = 1
	_select(h, combat, bard, "healing_word", 2)
	await combat._on_hex_clicked(Vector2i(2, 0))
	await _wait_resolution(h, combat)
	h._assert(fighter.current_hp > 0 and int(bard.spell_slots["2"]) == word_slots - 1 and not combat.turn_budget.bonus_action_available, "Conversion 002: live Healing Word heals a visible ally in range and pays once")

	# Return to a real overworld save boundary with the held source attached to a player character.
	combat._end_concentration(wizard)
	# Recast on the Bard at level 5 so the durable source is unambiguous and remains live.
	wizard.ability_scores.wisdom = 1
	bard.ability_scores.wisdom = 1
	bard.add_condition("paralyzed", 60, "conversion002:other-source")
	combat.turn_budget.reset(wizard, combat.player_entities)
	_select(h, combat, wizard, "hold_monster", 5)
	await combat._on_hex_clicked(Vector2i(1, 0))
	hold_source = str(wizard.concentrating_on.get("effect_source", ""))
	SpellEffects.advance_time([wizard, bard, fighter], 13)
	h._teardown_scene(combat)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.test_mode = true
	GameManager.game_in_progress = true
	h._assert(not hold_source.is_empty() and SaveManager.get_save_block_reason().is_empty() and SaveManager.save_game(SLOT), "Conversion 002: actual Hold Monster source saves at the supported overworld checkpoint")
	if hold_source.is_empty():
		h._exit_test()
		return
	var dto := SaveManager._read_save(SLOT)
	h._assert(SaveManager._validate_save_data(dto).is_empty(), "Conversion 002: full party DTO passes production save preflight")
	var player_only := dto.duplicate(true)
	player_only.erase("party")
	h._assert(SaveManager._validate_save_data(player_only).is_empty(), "Conversion 002: player-only DTO passes production save preflight")
	var file := FileAccess.open(SaveManager.SAVE_DIR + PLAYER_SLOT + ".sav", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(player_only, "\t"))
		file.close()
	h._assert(file != null and SaveManager.load_game(SLOT), "Conversion 002: full party checkpoint reloads through SaveManager")
	var restored: Character = PartyManager.characters.get(bard.character_id)
	var restored_wizard: Character = PartyManager.characters.get(wizard.character_id)
	h._assert(restored != null and int(restored.spell_effects.get(hold_source, {}).get("remaining_seconds", 0)) == 47 and restored_wizard.concentrating_on.get("targets", []).has(restored), "Conversion 002: full party checkpoint restores the exact partially elapsed source")
	h._assert(SaveManager.load_game(PLAYER_SLOT), "Conversion 002: player-only checkpoint reloads through SaveManager")
	restored = PlayerManager.get_player(1).get("character")
	h._assert(restored != null and int(restored.spell_effects.get(hold_source, {}).get("remaining_seconds", 0)) == 47, "Conversion 002: player-only checkpoint restores the source without replay")
	print("CONVERSION_BATCH_002_CHECKPOINT_READY")
	h._exit_test()

static func _recover(h, mode: String) -> void:
	var slot := PLAYER_SLOT if mode == "player_only" else SLOT
	h._assert(SaveManager.load_game(slot), "Conversion 002: a fresh process loads the real %s checkpoint" % mode)
	var wizard: Character = PartyManager.characters.get("conversion002-live-sorcerer")
	var bard: Character = PartyManager.characters.get("conversion002-live-bard")
	if wizard == null or bard == null:
		h._assert(false, "Conversion 002: original caster and target identities recover")
		return
	var source := str(wizard.concentrating_on.get("effect_source", ""))
	h._assert(not source.is_empty() and bard.has_condition("paralyzed") and int(bard.spell_effects.get(source, {}).get("remaining_seconds", 0)) == 47 and wizard.concentrating_on.get("targets", []).has(bard), "Conversion 002: fresh-process %s recovery rebinds the same concentration source" % mode)
	bard.ability_scores.wisdom = 40
	var repeat := CombatAction.resolve_hold_monster_repeat_save(bard, int(wizard.concentrating_on.get("save_dc", 0)), source)
	h._assert(repeat.get("saved", false) and bard.condition_sources.get("paralyzed", {}).has("conversion002:other-source") and not bard.spell_effects.has(source), "Conversion 002: repeat-save cleanup removes only the recovered Hold Monster source")
	print("CONVERSION_BATCH_002_FRESH_PROCESS_%s_PASSED" % mode.to_upper())
