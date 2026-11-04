## SC-07 support 06: Calm Emotions, common-scope implementation.
## New generic pieces: grant_condition choice_per_target (ask per affected
## creature before payment); attitude_scope_ids on the source record
## (InfluenceRules.effective_attitude(monster, toward_id)); the
## ends_on_seen_ally_damage consequence via DamageWitnessRules (same-side
## creatures that can see a damaged ally); raw conditions readers routed through
## CombatAction.has_condition / marker_suppresses.
class_name CrownSc07Support06Flow
extends RefCounted

const P := "SC-07 s6: "
const SLOT := "crown_sc_07_support_06"
const OLD_SLOT := "crown_sc_07_support_05"

static func _contract_checks(h) -> void:
	_persistence_contract_checks(h)
	var spell := DataLoader.get_spell("calm_emotions")
	h._assert(SharedSpell.content_error(spell).is_empty() and SharedSpell.per_target_condition_choices(spell) == ["calmed", "calmed_indifferent"] and CombatAction.condition_rule("calmed_indifferent", "ends_on_seen_ally_damage"), P + "Calm Emotions authors choice_per_target and option 2 carries ends_on_seen_ally_damage")
	var bad := spell.duplicate(true)
	bad.effects[1]["choice_per_target"] = "yes"
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "a non-boolean choice_per_target is rejected")

static func _renamed_checks(h) -> void:
	var caster := ConversionBatch002Checks.actor("crown-sc07s6-renamed", "bard", 5)
	var other := ConversionBatch002Checks.actor("crown-sc07s6-other", "fighter", 1)
	var hush := CrownSc01Support01Flow._renamed(h, "calm_emotions", "crown_sc_07_support_06:neutral_hush")
	var a := CrownSc07Support05Flow._humanoid("crown-sc07s6-r1", Vector2i(3, 0), -1000)
	var b := CrownSc07Support05Flow._humanoid("crown-sc07s6-r2", Vector2i(3, 1), -1000)
	var c := CrownSc07Support05Flow._humanoid("crown-sc07s6-r3", Vector2i(9, 9), -1000)
	hush["_chosen_conditions"] = {str(a.id): "calmed_indifferent", str(b.id): "calmed_indifferent", str(c.id): "calmed_indifferent"}
	hush["_attitude_scope_ids"] = [caster.character_id]
	for m in [a, b, c]: CombatAction.resolve_spell(caster, m, hush, false, {}, [], 2, 3)
	var rec: Dictionary = SpellEffects.records(a).values()[0] if not SpellEffects.records(a).is_empty() else {}
	h._assert(rec.get("attitude_scope_ids", []) == [caster.character_id], P + "renamed: the caster's chosen creatures ride on the source record through CombatAction.resolve_spell")
	h._assert(InfluenceRules.effective_attitude(a, caster.character_id) == "indifferent" and InfluenceRules.effective_attitude(a, other.character_id) == "hostile", P + "indifference applies only toward chosen creatures")
	var r := InfluenceRules.roll(other, a, {"skill": "Persuasion"}, {})
	var r_chosen := InfluenceRules.roll(caster, a, {"skill": "Persuasion"}, {})
	h._assert(bool(r.get("disadvantage", false)) and not bool(r_chosen.get("disadvantage", false)), P + "an Influence roll by an unchosen creature keeps Hostile Disadvantage; the chosen caster's does not")
	var ended := DamageWitnessRules.witness(a, [], [a, b, c], null)
	h._assert(ended.is_empty(), P + "with no grid no witness is assumed")
	CrownSc01Support01Flow._forget(str(hush.id))

static func _persistence_contract_checks(h) -> void:
	var caster := ConversionBatch002Checks.actor("crown-persistence-review-caster", "cleric", 5)
	var target := ConversionBatch002Checks.actor("crown-persistence-review-target", "fighter", 5)
	var frost_cast := SpellEffects.begin_cast(caster, DataLoader.get_spell("ray_of_frost"))
	var frost_source := str(frost_cast.source_id)
	SpellEffects.grant(target, frost_cast, "speed_reduced")
	SpellEffects.set_condition_amount(target, frost_cast, "speed_reduced", 2)
	var valid := target.to_dict()
	var changed := valid.duplicate(true)
	changed.spell_effects[frost_source].condition_amounts.speed_reduced = 12
	var missing := valid.duplicate(true)
	missing.spell_effects[frost_source].erase("condition_amounts")
	h._assert(SpellEffectPersistence.saved_state_error(valid).is_empty() and not SpellEffectPersistence.saved_state_error(changed).is_empty() and not SpellEffectPersistence.saved_state_error(missing).is_empty(), P + "persistence: authored magnitudes survive restore; changed or erased amounts refuse")
	changed = valid.duplicate(true)
	changed.spell_effects[frost_source].attitude_scope_ids = [caster.character_id]
	h._assert(not SpellEffectPersistence.saved_state_error(changed).is_empty(), P + "persistence: an unrelated condition cannot carry an attitude scope")
	SpellEffects.remove(target, frost_source)

	var calm_cast := SpellEffects.begin_cast(caster, DataLoader.get_spell("calm_emotions"))
	var calm_source := str(calm_cast.source_id)
	SpellEffects.grant(target, calm_cast, "calmed_indifferent")
	target.spell_effects[calm_source]["attitude_scope_ids"] = [caster.character_id]
	valid = target.to_dict()
	var legacy := valid.duplicate(true)
	legacy.spell_effects[calm_source].erase("attitude_scope_ids")
	h._assert(SpellEffectPersistence.saved_state_error(valid).is_empty() and SpellEffectPersistence.saved_state_error(legacy).is_empty(), P + "persistence: exact scoped and pre-scope legacy records remain readable")
	var malformed_refused := true
	for scope in [123, [caster.character_id, caster.character_id], [123], [""]]:
		changed = valid.duplicate(true)
		changed.spell_effects[calm_source].attitude_scope_ids = scope
		malformed_refused = malformed_refused and not SpellEffectPersistence.saved_state_error(changed).is_empty()
	h._assert(malformed_refused, P + "persistence: malformed, duplicate and empty scope ids refuse before restore")
	SpellEffects.remove(target, calm_source)


static func _find_popup(combat) -> PopupMenu:
	for child in combat.hud.get_children():
		if child is PopupMenu and child.visible: return child
	return null

static func _find_dialog(combat) -> ConfirmationDialog:
	for child in combat.hud.get_children():
		if child is ConfirmationDialog and child.visible: return child
	return null

static func _collect_late_targets(cast: SpellCastContext, state: Dictionary) -> void:
	await SpellCastTargeting.collect_targets(cast)
	state["done"] = true

static func _player_casts(h) -> void:
	var bard := ConversionBatch002Checks.actor("crown-sc07s6-bard", "bard", 1)
	var learned := ConversionBatch001Flow._prepare(bard, [])
	for _level in 2: bard.level_up()
	learned = learned and ConversionBatch001Flow._prepare(bard, ["calm_emotions"])
	h._assert(learned and "calm_emotions" in bard.get_spell_option_ids(false), P + "a level-3 Bard selects Calm Emotions")
	PlayerManager.set_player_character(0, bard)
	PartyManager.reset()
	PartyManager.register_player_character(0, bard)
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	h._ready_spell_components(bard)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	var scared := CrownSc07Support05Flow._humanoid("crown-sc07s6-scared", Vector2i(3, 0), -1000)
	var angry := CrownSc07Support05Flow._humanoid("crown-sc07s6-angry", Vector2i(3, 1), -1000)
	CombatAction.apply_condition(scared, "frightened", 10, "dread_source")
	combat.monster_entities.clear()
	combat.monster_entities.assign([scared, angry])
	for m in [scared, angry]: combat.tracker.add_combatant(str(m.id), str(m.name), false, m, 5, 10)
	combat._update_grid_entities()
	bard.spell_slots = {"1": 0, "2": 2}
	GameManager.test_mode = false
	combat.turn_budget.action_available = true
	ConversionBatch002Flow._select(h, combat, bard, "calm_emotions", 2)
	await h.get_tree().process_frame
	combat._on_hex_clicked(Vector2i(3, 0))
	var cancel_menu: PopupMenu = null
	for _frame in 60:
		cancel_menu = _find_popup(combat)
		if cancel_menu != null and cancel_menu.get_item_text(0).begins_with("Level"):
			cancel_menu.id_pressed.emit(cancel_menu.get_item_id(0))
			cancel_menu = null
		elif cancel_menu != null: break
		await h.get_tree().process_frame
	if cancel_menu != null: cancel_menu.hide()
	await ConversionBatch002Flow._wait_resolution(h, combat)
	h._assert(cancel_menu != null and int(bard.spell_slots["2"]) == 2 and combat.turn_budget.action_available and bard.concentrating_on.is_empty() and not CombatAction.has_condition(scared, "calmed"), P + "cancelling a required recipient option spends no slot or Action and grants nothing (menu=%s slots=%s action=%s concentration=%s log=%s)" % [str(cancel_menu != null), str(bard.spell_slots), str(combat.turn_budget.action_available), str(bard.concentrating_on), combat.hud.log_text.text.right(600)])
	ConversionBatch002Flow._select(h, combat, bard, "calm_emotions", 2)
	await h.get_tree().process_frame
	combat._on_hex_clicked(Vector2i(3, 0))
	var titles := []
	var picks := [0, 0, 1] # area order: the Bard (in the Sphere), scared, angry
	var scope_count := 0
	var handled := []
	for _frame in 600:
		var menu := _find_popup(combat)
		if menu != null and menu in handled: menu = null
		if menu != null: handled.append(menu)
		if menu != null and menu.get_item_text(0).begins_with("Level"):
			menu.id_pressed.emit(menu.get_item_id(0))
			await h.get_tree().process_frame
			continue
		if menu != null and not picks.is_empty():
			titles.append(menu.get_item_text(0) + "/" + menu.get_item_text(1))
			menu.id_pressed.emit(picks.pop_front())
		var dialog := _find_dialog(combat)
		if dialog != null and dialog not in handled and dialog.dialog_text.contains("Indifferent toward"):
			handled.append(dialog)
			scope_count += 1
			dialog.confirmed.emit()
		if picks.is_empty() and scope_count == 3: break
		await h.get_tree().process_frame
	await ConversionBatch002Flow._wait_resolution(h, combat)
	h._assert(titles.size() == 3 and scope_count == 3, P + "before payment the player picks each recipient option and can scope Indifference toward party and nonparty creatures (%s)" % str(titles))
	h._assert(CombatAction.has_condition(scared, "calmed") and not CombatAction.has_condition(scared, "frightened") and CombatAction.has_condition(angry, "calmed_indifferent") and not CombatAction.has_condition(angry, "calmed") and InfluenceRules.effective_attitude(angry, bard.character_id) == "indifferent" and InfluenceRules.effective_attitude(angry, "someone-else") == "hostile", P + "each creature got its own option; indifference is scoped to the chosen party member (%s | %s | %s)" % [str(scared.conditions), str(angry.conditions), combat.hud.log_text.text.right(600)])
	h._assert(InfluenceRules.effective_attitude(angry, str(scared.id)) == "indifferent" and int(bard.spell_slots["2"]) == 1 and not combat.turn_budget.action_available, P + "a chosen nonparty creature is covered and all choices settle one slot and Action")
	var late := CrownSc07Support05Flow._humanoid("crown-sc07s6-late", Vector2i(2, 1), -1000)
	combat.monster_entities.append(late)
	var late_cast: SpellCastContext = combat._spell_cast_context(Vector2i(3, 0))
	late_cast.spell = DataLoader.get_spell("calm_emotions").duplicate(true)
	late_cast.target_type = "area"
	late_cast.area_selection = {"shape": "sphere", "radius": 4}
	late_cast.spell["_chosen_conditions"] = {bard.character_id: "calmed", str(scared.id): "calmed", str(angry.id): "calmed_indifferent"}
	late_cast.spell["_condition_choices_ready"] = true
	late_cast.spell["_attitude_choices_ready"] = true
	var late_state := {"done": false}
	_collect_late_targets(late_cast, late_state)
	var late_menu: PopupMenu = null
	for _frame in 60:
		late_menu = _find_popup(combat)
		if late_menu != null: break
		await h.get_tree().process_frame
	if late_menu != null: late_menu.id_pressed.emit(0)
	for _frame in 60:
		if bool(late_state.done): break
		await h.get_tree().process_frame
	h._assert(late_menu != null and bool(late_state.done) and late_cast.spell.get("_chosen_conditions", {}).get(str(late.id)) == "calmed" and Vector2i(2, 1) in late_cast.targets and int(bard.spell_slots["2"]) == 1, P + "an eligible creature arriving during reactions gets its own explicit choice without omission or a second payment")
	CombatAction.apply_condition(angry, "blinded", 10, "test_blind")
	CombatAction.resolve_damage(scared, 2, "fire", {}, false, false, bard)
	h._assert(CombatAction.has_condition(angry, "calmed_indifferent") and CombatAction.has_condition(scared, "calmed"), P + "a Blinded ally can't see the damage, so option 2 holds; option 1 is not ended by damage")
	CombatAction.remove_condition_source(angry, "test_blind", ["blinded"])
	CombatAction.resolve_damage(scared, 2, "fire", {}, false, false, bard)
	h._assert(not CombatAction.has_condition(angry, "calmed_indifferent") and InfluenceRules.effective_attitude(angry, bard.character_id) == "hostile", P + "option 2 ends when the creature sees an ally take damage")
	SpellEffects.end_concentration(bard, [scared, angry])
	bard.concentrating_on = {}
	GameManager.test_mode = true
	h._teardown_scene(combat)

static func _checkpoint(h) -> void:
	var caster := ConversionBatch002Checks.actor("crown-sc07s6-saver", "bard", 5)
	var ally := ConversionBatch002Checks.actor("crown-sc07s6-ally", "fighter", 1)
	PartyManager.reset()
	PlayerManager.set_player_character(0, caster)
	PlayerManager.set_player_character(1, ally)
	PartyManager.register_player_character(0, caster)
	PartyManager.register_player_character(1, ally)
	var spell := DataLoader.get_spell("calm_emotions").duplicate(true)
	spell["_chosen_conditions"] = {ally.character_id: "calmed_indifferent"}
	spell["_attitude_scope_ids"] = [caster.character_id]
	ally.ability_scores.from_dict({"STR": 16, "DEX": 10, "CON": 12, "INT": 10, "WIS": 10, "CHA": 1})
	for _attempt in 80:
		CombatAction.resolve_spell(caster, ally, spell, false, {}, [], 2, 2)
		if ally.conditions.has("calmed_indifferent"): break
		for key in SpellEffects.records(ally).keys(): SpellEffects.remove(ally, str(key))
	var rec: Dictionary = SpellEffects.records(ally).values()[0] if not SpellEffects.records(ally).is_empty() else {}
	caster.concentrating_on = {"spell_id": "calm_emotions", "effect_source": CrownSc07Support01Flow._source(ally), "targets": [ally]}
	h._assert(rec.get("attitude_scope_ids", []) == [caster.character_id], P + "a party member carries a scoped option-2 record")
	GameManager.test_mode = true
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	h._assert(SaveManager.save_game(SLOT) and SaveManager._validate_save_data(SaveManager._read_save(SLOT)).is_empty() and SaveManager.load_game(SLOT), P + "the scoped record saves, passes preflight and reloads")
	print("CROWN_SC_07_SUPPORT_06_CHECKPOINT_READY")

static func _recover(h) -> void:
	h._assert(SaveManager.load_game(SLOT), P + "a fresh process loads the checkpoint")
	var ally: Character = PartyManager.characters.get("crown-sc07s6-ally")
	var rec: Dictionary = SpellEffects.records(ally).values()[0] if ally != null and not SpellEffects.records(ally).is_empty() else {}
	h._assert(ally != null and ally.has_condition("calmed_indifferent") and rec.get("attitude_scope_ids", []) == ["crown-sc07s6-saver"], P + "fresh-process recovery keeps option 2 with its attitude_scope_ids (%s | %s)" % [str(ally.conditions) if ally != null else "", str(rec)])
	# Old-.sav round trip: the support-05 checkpoint (no attitude_scope_ids key) still loads and saves.
	var old_path := "user://saves/%s.sav" % OLD_SLOT
	if SaveManager._read_save(OLD_SLOT).is_empty():
		h._assert(false, P + "old support-05 checkpoint present (run crown_sc_07_support_05_flow first)")
	else:
		var old_ok := SaveManager.load_game(OLD_SLOT)
		var old_ally: Character = PartyManager.characters.get("crown-sc07s5-ally")
		h._assert(old_ok and old_ally != null and old_ally.has_condition("calmed") and SaveManager.save_game(OLD_SLOT + "_resaved") and SaveManager.load_game(OLD_SLOT + "_resaved"), P + "old-.sav round trip: a pre-scope checkpoint loads, re-saves and reloads (%s)" % old_path)
	print("CROWN_SC_07_SUPPORT_06_FRESH_PROCESS_PASSED")

static func run(h) -> void:
	h._enter_test("crown_sc_07_support_06_flow")
	if OS.get_environment("CROWN_SC_07_SUPPORT_06_RECOVER") == "1":
		_recover(h)
		h._exit_test()
		return
	h._setup_world()
	_contract_checks(h)
	_renamed_checks(h)
	await _player_casts(h)
	_checkpoint(h)
	h._exit_test()
