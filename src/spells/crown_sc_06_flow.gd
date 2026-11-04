## SC-06: Sleep and Hypnotic Pattern as shared data.
## New generic pieces: save_auto_success_traits, final repeat-save stages with on_success routes,
## area_creature_choice, area_save_requires_sight, end_on_shake_action and the speed_zero condition.
class_name CrownSc06Flow
extends RefCounted

const P := "SC-06: "
const SLOT := "crown_sc_06"

static func _wis(id: String, hex: Vector2i, wisdom: int) -> Dictionary:
	var m := CrownSc01Support01Flow._monster(id, hex, 10, {"wisdom": wisdom})
	m["creature_type"] = "humanoid"
	return m

static func _source(target) -> String:
	for key in SpellEffects.records(target): return str(key)
	return ""

static func _contract_checks(h) -> void:
	var sleep := DataLoader.get_spell("sleep")
	h._assert(SharedSpell.uses(sleep) and SharedSpell.content_error(sleep).is_empty() and int(sleep.range) == 12 and sleep.save == "WIS" and bool(sleep.area_creature_choice) and bool(sleep.end_on_shake_action) and sleep.save_auto_success_traits == ["magical_sleep_immunity"] and sleep.repeat_save_stages.size() == 2, P + "Sleep is shared data (60 ft, 5-ft Sphere, chosen creatures, Wis save, Incapacitated then Unconscious, trait auto-success)")
	var hp := DataLoader.get_spell("hypnotic_pattern")
	h._assert(SharedSpell.uses(hp) and SharedSpell.content_error(hp).is_empty() and int(hp.range) == 24 and bool(hp.area_save_requires_sight) and bool(hp.end_on_shake_action) and bool(hp.end_on_any_damage), P + "Hypnotic Pattern is shared data (120 ft, 30-ft area, sight-gated Wis save, Charmed/Incapacitated/Speed 0)")
	var bad := sleep.duplicate(true)
	bad["save_auto_success_traits"] = ["never_sleeps_forever"]
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "an unknown auto-success trait is rejected")
	bad = sleep.duplicate(true)
	bad["area_creature_choice"] = "yes"
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "a non-Boolean area_creature_choice is rejected")
	bad = sleep.duplicate(true)
	bad.repeat_save_stages[1]["successes_required"] = 1
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "a final stage that still asks for saves is rejected")
	bad = sleep.duplicate(true)
	bad.repeat_save_stages[0]["on_success"] = "sideways"
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "an unknown on_success route is rejected")
	bad = hp.duplicate(true)
	bad["target"] = "single"
	bad.effects.remove_at(0)
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "area_save_requires_sight without an area is rejected")

static func _renamed_checks(h) -> void:
	var caster := ConversionBatch002Checks.actor("crown-sc06-renamed", "wizard", 5)
	var doze := CrownSc01Support01Flow._renamed(h, "sleep", "crown_sc_06:neutral_doze")
	var sleeper := _wis("crown-sc06-r1", Vector2i(2, 0), 1)
	sleeper["saving_throw_bonuses"] = {"WIS": -1000}
	CombatAction.resolve_spell(caster, sleeper, doze, false, {}, [], 1, 2)
	h._assert(CombatAction.has_condition(sleeper, "incapacitated") and not CombatAction.has_condition(sleeper, "unconscious"), P + "renamed staged spell: a failed save grants Incapacitated through CombatAction.resolve_spell")
	var source := _source(sleeper)
	var second := CombatAction.resolve_condition_spell_repeat_save(sleeper, source)
	h._assert(not bool(second.get("saved", true)) and CombatAction.has_condition(sleeper, "unconscious") and not CombatAction.has_condition(sleeper, "incapacitated"), P + "a second failed save advances to the final Unconscious stage")
	h._assert(not CombatAction.resolve_condition_spell_repeat_save(sleeper, source).get("success", false) and SpellEffects.repeat_save_stage_final(sleeper, source), P + "the final stage asks for no more saves")
	CombatAction.resolve_damage(sleeper, 1, "bludgeoning")
	h._assert(SpellEffects.records(sleeper).is_empty() and not CombatAction.has_condition(sleeper, "unconscious"), P + "damage ends the final stage")
	var waker := _wis("crown-sc06-r2", Vector2i(2, 0), 1)
	waker["saving_throw_bonuses"] = {"WIS": -1000}
	CombatAction.resolve_spell(caster, waker, doze, false, {}, [], 1, 2)
	waker["saving_throw_bonuses"] = {"WIS": 1000}
	var woke := CombatAction.resolve_condition_spell_repeat_save(waker, _source(waker))
	h._assert(bool(woke.get("saved", false)) and SpellEffects.records(waker).is_empty() and not CombatAction.has_condition(waker, "incapacitated"), P + "a successful first repeat save ends the spell (on_success end)")
	var elf := _wis("crown-sc06-r3", Vector2i(2, 0), 1)
	elf["saving_throw_bonuses"] = {"WIS": -1000}
	elf["condition_immunities"] = ["exhaustion"]
	var auto := CombatAction.resolve_spell(caster, elf, doze, false, {}, [], 1, 2)
	h._assert(bool(auto.get("automatic_save", false)) and bool(auto.get("saved", false)) and SpellEffects.records(elf).is_empty(), P + "a creature with the magical-sleep trait automatically succeeds")
	CrownSc01Support01Flow._forget(str(doze.id))
	var swirl := CrownSc01Support01Flow._renamed(h, "hypnotic_pattern", "crown_sc_06:neutral_swirl")
	var gazer := _wis("crown-sc06-r4", Vector2i(3, 0), 1)
	gazer["saving_throw_bonuses"] = {"WIS": -1000}
	CombatAction.resolve_spell(caster, gazer, swirl, false, {}, [], 3, 3)
	h._assert(CombatAction.has_condition(gazer, "charmed") and CombatAction.has_condition(gazer, "incapacitated") and CombatAction.is_speed_zero(gazer) and SpellEffects.records(gazer).size() == 1, P + "renamed pattern: one source grants Charmed, Incapacitated and Speed 0")
	CombatAction.resolve_damage(gazer, 1, "fire")
	h._assert(not CombatAction.has_condition(gazer, "charmed") and not CombatAction.is_speed_zero(gazer) and SpellEffects.records(gazer).is_empty(), P + "any damage ends all three conditions")
	CrownSc01Support01Flow._forget(str(swirl.id))

static func _answer_targets(h, hud, title: String, include_name: String, wanted: int) -> int:
	var seen := 0
	for _frame in 180:
		for child in hud.get_children():
			if child is ConfirmationDialog and child.title == title and child.visible and not child.is_queued_for_deletion():
				seen += 1
				if str(child.dialog_text).contains(include_name): child.confirmed.emit()
				else: child.canceled.emit()
				break
		if seen >= wanted: return seen
		await h.get_tree().process_frame
	return seen

static func _player_casts(h) -> void:
	var wizard := ConversionBatch002Checks.actor("crown-sc06-wiz", "sorcerer", 1)
	var learned := ConversionBatch001Flow._prepare(wizard, ["sleep"])
	for _level in 4:
		wizard.level_up()
	learned = learned and ConversionBatch001Flow._prepare(wizard, ["sleep", "hypnotic_pattern"])
	h._assert(learned and wizard.level == 5, P + "Sorcerer learns Sleep at level 1 and adds Hypnotic Pattern at level 5 through ordinary class selection")
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	h._ready_spell_components(wizard)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	var chosen := _wis("crown-sc06-chosen", Vector2i(2, 0), 1)
	chosen["saving_throw_bonuses"] = {"WIS": -1000}
	var spared := _wis("crown-sc06-spared", Vector2i(3, 0), 1)
	spared["saving_throw_bonuses"] = {"WIS": -1000}
	combat.monster_entities.clear()
	combat.monster_entities.assign([chosen, spared])
	combat._update_grid_entities()
	GameManager.test_mode = false
	wizard.spell_slots = {"1": 1, "2": 0, "3": 0}
	ConversionBatch002Flow._select(h, combat, wizard, "sleep", 1)
	combat._on_hex_clicked(Vector2i(2, 0))
	var asked: int = await _answer_targets(h, combat.hud, "Sleep Targets", "crown-sc06-chosen", 2)
	await ConversionBatch002Flow._wait_resolution(h, combat)
	h._assert(asked == 2 and CombatAction.has_condition(chosen, "incapacitated") and not CombatAction.has_condition(spared, "incapacitated") and int(wizard.spell_slots["1"]) == 0, P + "picker + hex click + per-creature choice: only the chosen creature is put to sleep (%s)" % combat.hud.log_text.text.right(200))
	CombatAction.resolve_condition_spell_repeat_save(chosen, _source(chosen))
	h._assert(CombatAction.has_condition(chosen, "unconscious"), P + "the live target fails its second save and falls Unconscious")
	SpellEffects.end_concentration(wizard, [chosen])
	# Hypnotic Pattern: sighted creatures save, a Blinded one in the area is unaffected.
	for m in [chosen, spared]:
		m.conditions.clear(); m.condition_sources.clear(); m.spell_effects.clear()
	var blind := _wis("crown-sc06-blind", Vector2i(4, 0), 1)
	blind["saving_throw_bonuses"] = {"WIS": -1000}
	blind.conditions["blinded"] = true
	combat.monster_entities.append(blind)
	combat._update_grid_entities()
	wizard.spell_slots = {"1": 0, "2": 0, "3": 1}
	ConversionBatch002Flow._select(h, combat, wizard, "hypnotic_pattern", 3)
	await combat._on_hex_clicked(Vector2i(4, 0))
	await ConversionBatch002Flow._wait_resolution(h, combat)
	h._assert(CombatAction.has_condition(chosen, "charmed") and CombatAction.has_condition(spared, "incapacitated") and CombatAction.is_speed_zero(spared) and not CombatAction.has_condition(blind, "charmed") and int(wizard.spell_slots["3"]) == 0, P + "picker + hex click: sighted creatures in the area are Charmed, Incapacitated and at Speed 0; a Blinded creature is unaffected (%s)" % combat.hud.log_text.text.right(240))
	# An ally (here the caster) steps next to a mesmerized creature and spends an action to shake it.
	combat.player_entities[0].hex_position = Vector2i(1, 0)
	combat.turn_budget.reset(wizard, combat.player_entities)
	combat.pending_action_type = ""
	await combat._on_hex_clicked(Vector2i(2, 0))
	h._assert(not CombatAction.has_condition(chosen, "charmed") and SpellEffects.records(chosen).is_empty() and CombatAction.has_condition(spared, "charmed") and not combat.turn_budget.action_available, P + "an adjacent creature spends its action to shake one target free; others stay mesmerized")
	GameManager.test_mode = true
	h._teardown_scene(combat)

static func _checkpoint(h) -> void:
	var caster := ConversionBatch002Checks.actor("crown-sc06-saver", "wizard", 5)
	var ally := ConversionBatch002Checks.actor("crown-sc06-ally", "fighter", 1)
	PartyManager.reset()
	PlayerManager.set_player_character(0, caster)
	PlayerManager.set_player_character(1, ally)
	PartyManager.register_player_character(0, caster)
	PartyManager.register_player_character(1, ally)
	ally.ability_scores.from_dict({"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 1, "CHA": 10})
	for _attempt in 80:
		for key in SpellEffects.records(ally).keys(): SpellEffects.remove(ally, str(key))
		CombatAction.resolve_spell(caster, ally, DataLoader.get_spell("sleep"), false, {}, [], 1, 2)
		if ally.has_condition("incapacitated"): CombatAction.resolve_condition_spell_repeat_save(ally, _source(ally))
		if ally.has_condition("unconscious"): break
	caster.concentrating_on = {"spell_id": "sleep", "effect_source": _source(ally), "targets": [ally]}
	h._assert(ally.has_condition("unconscious") and SpellEffects.repeat_save_stage_final(ally, _source(ally)), P + "the party carries a final-stage (Unconscious) Sleep record")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.test_mode = true
	GameManager.game_in_progress = true
	h._assert(SaveManager.get_save_block_reason().is_empty() and SaveManager.save_game(SLOT), P + "the record saves at the overworld checkpoint")
	h._assert(SaveManager._validate_save_data(SaveManager._read_save(SLOT)).is_empty(), P + "the DTO passes production save preflight")
	h._assert(SaveManager.load_game(SLOT), P + "the checkpoint reloads through SaveManager")
	print("CROWN_SC_06_CHECKPOINT_READY")

static func _recover(h) -> void:
	h._assert(SaveManager.load_game(SLOT), P + "a fresh process loads the real checkpoint")
	var ally: Character = PartyManager.characters.get("crown-sc06-ally")
	var caster: Character = PartyManager.characters.get("crown-sc06-saver")
	if ally == null or caster == null:
		h._assert(false, P + "caster and target identities recover")
		return
	var source := _source(ally)
	h._assert(ally.has_condition("unconscious") and SpellEffects.repeat_save_stage_final(ally, source) and not CombatAction.resolve_condition_spell_repeat_save(ally, source).get("success", false), P + "fresh-process recovery keeps the final Unconscious stage and asks for no further saves")
	CombatAction.resolve_damage(ally, 1, "bludgeoning")
	h._assert(SpellEffects.records(ally).is_empty() and not ally.has_condition("unconscious"), P + "damage ends the recovered Sleep record")
	caster.concentrating_on = {}
	for _attempt in 40:
		CombatAction.resolve_spell(caster, ally, DataLoader.get_spell("hypnotic_pattern"), false, {}, [], 3, 2)
		if ally.has_condition("charmed"): break
	caster.concentrating_on = {"spell_id": "hypnotic_pattern", "effect_source": _source(ally), "targets": [ally]}
	h._assert(SaveManager.save_game(SLOT) and SaveManager._validate_save_data(SaveManager._read_save(SLOT)).is_empty() and SaveManager.load_game(SLOT), P + "a Charmed/Incapacitated/Speed 0 record saves, passes preflight and reloads")
	var reloaded: Character = PartyManager.characters.get("crown-sc06-ally")
	h._assert(reloaded != null and reloaded.has_condition("charmed") and reloaded.has_condition("incapacitated") and CombatAction.is_speed_zero(reloaded), P + "reload restores Charmed, Incapacitated and Speed 0")
	print("CROWN_SC_06_FRESH_PROCESS_PASSED")

static func run(h) -> void:
	h._enter_test("crown_sc_06_flow")
	if OS.get_environment("CROWN_SC_06_RECOVER") == "1":
		_recover(h)
		h._exit_test()
		return
	h._setup_world()
	_contract_checks(h)
	_renamed_checks(h)
	await _player_casts(h)
	_checkpoint(h)
	h._exit_test()
