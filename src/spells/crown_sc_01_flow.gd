## SC-01 live player-control and durable recovery proof for shared Ray of Sickness
## and the generic caster-turn condition expiry it consumes.
class_name CrownSc01Flow
extends RefCounted

const SLOT := "crown_sc_01"
const RENAMED_ID := "crown_sc_01:neutral_ray"

static func _monster(id: String, hex: Vector2i, ac: int, immunities: Array = []) -> Dictionary:
	return {"id": id, "name": id, "creature_type": "beast", "hex_position": hex, "is_alive": true, "current_hp": 1000, "max_hp": 1000, "temp_hp": 0, "armor_class": ac, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "damage_resistances": [], "condition_immunities": immunities, "spell_slots": {}}

## Casts through the real picker and hex click until `stop` holds; each attempt must pay exactly one slot.
static func _cast_until(h, combat, caster: Character, id: String, slot: int, hex: Vector2i, stop: Callable, label: String) -> bool:
	for _attempt in 40:
		caster.spell_slots[str(slot)] = 4
		ConversionBatch002Flow._select(h, combat, caster, id, slot)
		await combat._on_hex_clicked(hex)
		await ConversionBatch002Flow._wait_resolution(h, combat)
		if int(caster.spell_slots[str(slot)]) != 3 or combat.turn_budget.action_available:
			h._assert(false, "SC-01: %s pays exactly one slot and the action" % label)
			return false
		if stop.call(): return true
	return false

static func _renamed_check(h) -> void:
	var definition := DataLoader.get_spell("ray_of_sickness").duplicate(true)
	for key in definition.keys():
		if str(key).begins_with("_"): definition.erase(key)
	definition.id = RENAMED_ID
	definition.name = "Neutral Ray"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.artifacts/crown-sc-01"))
	var path := "res://.artifacts/crown-sc-01/renamed-spells.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify([definition]))
	file.close()
	DataLoader._load_json_file(path, "spell")
	var renamed := DataLoader.get_spell(RENAMED_ID)
	h._assert(DataLoader.get_load_errors().is_empty() and SharedSpell.uses(renamed) and SharedSpell.content_error(renamed).is_empty(), "SC-01: renamed Ray of Sickness passes the production loader as shared data")
	var bad := definition.duplicate(true)
	bad.effects[0].expiry = {"boundary": "target_turn_middle", "turns": 1}
	h._assert(not SharedSpell.content_error(bad).is_empty(), "SC-01: an unsupported expiry boundary is rejected before play")
	bad.effects[0].expiry = {"boundary": "caster_turn_end", "turns": 0}
	h._assert(not SharedSpell.content_error(bad).is_empty(), "SC-01: a zero-turn expiry is rejected before play")
	bad.effects[0].expiry = {"boundary": "caster_turn_end", "turns": 2, "extra": 1}
	h._assert(not SharedSpell.content_error(bad).is_empty(), "SC-01: expiry accepts only boundary and turns")
	var caster := ConversionBatch002Checks.actor("crown-sc01-renamed-caster", "wizard", 5)
	var target := _monster("crown-sc01-renamed-target", Vector2i(1, 0), -100)
	var result := {}
	for _attempt in 40:
		result = CombatAction.resolve_spell(caster, target, renamed, false, {}, [], 1, 5)
		if target.conditions.has("poisoned"): break
	var source := str(result.get("effect_cast", {}).get("source_id", ""))
	h._assert(target.conditions.has("poisoned") and str(target.spell_effects.get(source, {}).get("expiry_phase", "")) == "end" and int(target.spell_effects.get(source, {}).get("remaining_seconds", 0)) == 12, "SC-01: renamed definition grants Poisoned with a caster end-of-turn expiry and no ID registration")
	DataLoader.spells.erase(RENAMED_ID)
	DataLoader._registered_sources.get("spell", {}).erase(RENAMED_ID)

static func run(h) -> void:
	h._enter_test("crown_sc_01_flow")
	if OS.get_environment("CROWN_SC_01_RECOVER") == "1":
		_recover(h)
		h._exit_test()
		return
	h._setup_world()
	_renamed_check(h)
	var spell := DataLoader.get_spell("ray_of_sickness")
	h._assert(SharedSpell.uses(spell) and SharedSpell.content_error(spell).is_empty() and int(spell.range) == 6, "SC-01: Ray of Sickness is shared data with the SRD 30-foot range")
	var wizard := ConversionBatch002Checks.actor("crown-sc01-wizard", "sorcerer", 1)
	var ally := ConversionBatch002Checks.actor("crown-sc01-ally", "fighter", 5)
	h._assert(ConversionBatch001Flow._prepare(wizard, ["ray_of_sickness"]), "SC-01: Sorcerer prepares Ray of Sickness through ordinary class selection")
	while wizard.level < 5: wizard.level_up()
	h._assert("ray_of_sickness" in wizard.known_spells, "SC-01: the level-5 Sorcerer keeps Ray of Sickness after ordinary level-ups")
	h._assert(CombatAction.spell_damage_formula(wizard, spell, 1) == "2d8" and CombatAction.spell_damage_formula(wizard, spell, 3) == "2d8 + 2d8", "SC-01: damage is 2d8 and scales by 1d8 per slot above 1 (level-5 caster, no cantrip scaling)")
	PlayerManager.set_player_character(0, wizard)
	if PlayerManager.get_player_count() < 2: PlayerManager.add_player("Ally")
	PlayerManager.set_player_character(1, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	PartyManager.register_player_character(1, ally)
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	combat.player_entities[1].hex_position = Vector2i(1, 0)
	var hit_target := _monster("crown-sc01-hit", Vector2i(2, 0), -100)
	var miss_target := _monster("crown-sc01-miss", Vector2i(3, 0), 1000)
	var immune_target := _monster("crown-sc01-immune", Vector2i(2, 1), -100, ["poisoned"])
	var far_target := _monster("crown-sc01-far", Vector2i(9, 0), -100)
	combat.monster_entities.clear()
	combat.monster_entities.assign([hit_target, miss_target, immune_target, far_target])
	combat._update_grid_entities()
	GameManager.test_mode = false

	# Out of range (45 ft) refuses before payment.
	wizard.spell_slots["1"] = 4
	ConversionBatch002Flow._select(h, combat, wizard, "ray_of_sickness", 1)
	await combat._on_hex_clicked(Vector2i(9, 0))
	await ConversionBatch002Flow._wait_resolution(h, combat)
	h._assert(int(wizard.spell_slots["1"]) == 4 and not far_target.conditions.has("poisoned") and int(far_target.current_hp) == 1000, "SC-01: a target beyond 30 feet is refused before payment")
	combat._on_hud_action("cancel", {})

	# Miss: no damage and no Poisoned.
	var missed := await _cast_until(h, combat, wizard, "ray_of_sickness", 1, Vector2i(3, 0), func(): return int(miss_target.current_hp) == 1000, "miss cast")
	h._assert(missed and not miss_target.conditions.has("poisoned") and miss_target.spell_effects.is_empty(), "SC-01: a missed ray deals no damage and grants nothing")
	miss_target.current_hp = 1000
	miss_target.conditions.clear()
	miss_target.spell_effects.clear()

	# Immunity: hit damages but grants no condition or timer.
	var immune_hit := await _cast_until(h, combat, wizard, "ray_of_sickness", 1, Vector2i(2, 1), func(): return int(immune_target.current_hp) < 1000, "immune cast")
	h._assert(immune_hit and not immune_target.conditions.has("poisoned") and immune_target.spell_effects.is_empty(), "SC-01: a Poison-immune target takes the hit without a Poisoned record")

	# Hit at slot 2 with an overlapping longer Poisoned source on the same creature.
	hit_target.conditions["poisoned"] = 10
	hit_target.condition_sources["poisoned"] = {"crown-sc01:other-source": 10}
	var upcast_hit := await _cast_until(h, combat, wizard, "ray_of_sickness", 2, Vector2i(2, 0), func(): return int(hit_target.current_hp) < 1000, "upcast hit")
	var source := ""
	for key in hit_target.spell_effects: source = str(key)
	var record: Dictionary = hit_target.spell_effects.get(source, {})
	h._assert(upcast_hit and int(hit_target.current_hp) >= 1000 - 32 and int(hit_target.current_hp) <= 1000 - 3 and hit_target.conditions.has("poisoned") and str(record.get("expiry_phase", "")) == "end" and int(record.get("remaining_seconds", 0)) == 12, "SC-01: an upcast hit deals 3d8 Poison and records Poisoned until the end of the caster's next turn")
	h._assert(CombatAction.attacker_has_condition_disadvantage(hit_target), "SC-01: the Poisoned target's next attack roll has Disadvantage")

	# Caster/target turn boundaries: the target's own turns do not advance the caster-owned timer.
	var targets := [hit_target]
	var owner := SpellEffects.caster_id(wizard)
	SpellEffects.tick_boundary(targets, str(hit_target.id), "start")
	SpellEffects.tick_boundary(targets, str(hit_target.id), "end")
	h._assert(int(hit_target.spell_effects.get(source, {}).get("remaining_seconds", 0)) == 12, "SC-01: the target's turn boundaries leave the caster-owned expiry untouched")
	SpellEffects.tick_boundary(targets, owner, "start")
	h._assert(int(hit_target.spell_effects.get(source, {}).get("remaining_seconds", 0)) == 12, "SC-01: a caster start-of-turn boundary does not advance an end-of-turn expiry")
	SpellEffects.tick_boundary(targets, owner, "end")
	h._assert(hit_target.spell_effects.has(source) and hit_target.conditions.has("poisoned"), "SC-01: Poisoned survives the end of the casting turn")
	SpellEffects.tick_boundary(targets, owner, "end")
	h._assert(not hit_target.spell_effects.has(source) and hit_target.conditions.has("poisoned") and hit_target.condition_sources.get("poisoned", {}).has("crown-sc01:other-source"), "SC-01: expiry at the end of the caster's next turn removes only the ray's source")
	CombatAction.remove_condition_source(hit_target, "crown-sc01:other-source", ["poisoned"])
	h._assert(not hit_target.conditions.has("poisoned") and not CombatAction.attacker_has_condition_disadvantage(hit_target), "SC-01: after both sources end, the next unrelated attack roll has no Disadvantage")

	# Durable checkpoint: a hit on the party ally carries the live record across save and reload.
	ally.ability_scores.dexterity = 1
	var ally_hit := await _cast_until(h, combat, wizard, "ray_of_sickness", 1, Vector2i(1, 0), func(): return ally.has_condition("poisoned"), "ally hit")
	var ally_source := ""
	for key in ally.spell_effects: ally_source = str(key)
	SpellEffects.tick_boundary([ally], owner, "end")
	h._assert(ally_hit and int(ally.spell_effects.get(ally_source, {}).get("remaining_seconds", 0)) == 6, "SC-01: the ally's record has one caster turn left after the casting turn ends")
	h._teardown_scene(combat)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.test_mode = true
	GameManager.game_in_progress = true
	h._assert(not ally_source.is_empty() and SaveManager.get_save_block_reason().is_empty() and SaveManager.save_game(SLOT), "SC-01: the live Ray of Sickness record saves at the overworld checkpoint")
	var dto := SaveManager._read_save(SLOT)
	h._assert(SaveManager._validate_save_data(dto).is_empty(), "SC-01: the DTO passes production save preflight")
	h._assert(SaveManager.load_game(SLOT), "SC-01: the checkpoint reloads through SaveManager")
	var restored: Character = PartyManager.characters.get(ally.character_id)
	h._assert(restored != null and restored.has_condition("poisoned") and str(restored.spell_effects.get(ally_source, {}).get("expiry_phase", "")) == "end" and int(restored.spell_effects.get(ally_source, {}).get("remaining_seconds", 0)) == 6, "SC-01: reload restores the exact boundary and remaining caster turn")
	h._assert(SaveManager.save_game(SLOT), "SC-01: the reloaded state saves again")
	print("CROWN_SC_01_CHECKPOINT_READY")
	h._exit_test()

static func _recover(h) -> void:
	h._assert(SaveManager.load_game(SLOT), "SC-01: a fresh process loads the real checkpoint")
	var wizard: Character = PartyManager.characters.get("crown-sc01-wizard")
	var ally: Character = PartyManager.characters.get("crown-sc01-ally")
	if wizard == null or ally == null:
		h._assert(false, "SC-01: caster and target identities recover")
		return
	var source := ""
	for key in ally.spell_effects: source = str(key)
	h._assert(ally.has_condition("poisoned") and int(ally.spell_effects.get(source, {}).get("remaining_seconds", 0)) == 6, "SC-01: fresh-process recovery keeps the ray's Poisoned record")
	SpellEffects.tick_boundary([ally], SpellEffects.caster_id(wizard), "start")
	h._assert(ally.has_condition("poisoned"), "SC-01: the recovered record ignores the caster's start boundary")
	SpellEffects.tick_boundary([ally], SpellEffects.caster_id(wizard), "end")
	h._assert(not ally.has_condition("poisoned") and not ally.spell_effects.has(source), "SC-01: the recovered record ends at the caster's next end-of-turn boundary")
	h._assert(SaveManager.save_game(SLOT), "SC-01: the recovered state saves")
	print("CROWN_SC_01_FRESH_PROCESS_PASSED")
