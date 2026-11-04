## SC-07 support 05: Calm Emotions as shared data.
## New generic pieces: suppress_<condition> marker consequences (CombatAction.
## marker_suppresses) that suppress an existing condition and block new ones;
## the attitude_indifferent consequence read by InfluenceRules.effective_attitude;
## the ends_on_damage marker consequence (per-target end on damage); and
## per-target condition_options picks (spell._chosen_conditions by target id).
class_name CrownSc07Support05Flow
extends RefCounted

const P := "SC-07 s5: "
const SLOT := "crown_sc_07_support_05"

static func _humanoid(id: String, hex: Vector2i, bonus: int, attitude: String = "hostile") -> Dictionary:
	var m := CrownSc01Support01Flow._monster(id, hex, 10, {"charisma": 10})
	m["creature_type"] = "humanoid"
	m["saving_throw_bonuses"] = {"CHA": bonus}
	m["influence"] = {"attitude": attitude, "manipulates_objects": true, "requests": []}
	return m

static func _contract_checks(h) -> void:
	var spell := DataLoader.get_spell("calm_emotions")
	h._assert(SharedSpell.uses(spell) and SharedSpell.content_error(spell).is_empty() and int(spell.range) == 12 and spell.save == "CHA" and spell.target == "area" and int(spell.area_radius) == 4 and spell.target_creature_types == ["humanoid"] and bool(spell.concentration) and int(spell.duration_seconds) == 60, P + "Calm Emotions is shared data (60 ft, 20-ft Sphere, Humanoids, Cha save, concentration 1 min)")
	h._assert(SharedSpell.condition_choices(spell) == ["calmed", "calmed_indifferent"] and CombatAction.condition_rule("calmed", "suppress_charmed") and CombatAction.condition_rule("calmed", "suppress_frightened") and CombatAction.condition_rule("calmed_indifferent", "attitude_indifferent") and CombatAction.condition_rule("calmed_indifferent", "ends_on_damage"), P + "the two options are markers carrying suppression / attitude / end-on-damage consequences")
	var bad := spell.duplicate(true)
	bad.effects[1]["condition_options"] = ["calmed", "serene_forever"]
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "an unknown option marker is rejected")

static func _renamed_checks(h) -> void:
	var caster := ConversionBatch002Checks.actor("crown-sc07s5-renamed", "bard", 5)
	var hush := CrownSc01Support01Flow._renamed(h, "calm_emotions", "crown_sc_07_support_05:neutral_hush")
	var scared := _humanoid("crown-sc07s5-r1", Vector2i(3, 0), -1000)
	var angry := _humanoid("crown-sc07s5-r2", Vector2i(3, 1), -1000)
	var beast := _humanoid("crown-sc07s5-r3", Vector2i(3, 2), -1000)
	beast["creature_type"] = "beast"
	CombatAction.apply_condition(scared, "frightened", 10, "dread_source")
	CombatAction.apply_condition(scared, "charmed", 10, "charm_source")
	h._assert(CombatAction.has_condition(scared, "frightened") and CombatAction.has_condition(scared, "charmed"), P + "fixture starts Frightened and Charmed")
	hush["_chosen_conditions"] = {str(scared.id): "calmed", str(angry.id): "calmed_indifferent"}
	var r1 := CombatAction.resolve_spell(caster, scared, hush, false, {}, [], 2, 3)
	var r2 := CombatAction.resolve_spell(caster, angry, hush, false, {}, [], 2, 3)
	h._assert(not bool(r1.get("saved", true)) and CombatAction.has_condition(scared, "calmed") and not CombatAction.has_condition(scared, "calmed_indifferent"), P + "renamed calm: a per-target pick grants option 1 to the first creature through CombatAction.resolve_spell")
	h._assert(not CombatAction.has_condition(scared, "frightened") and not CombatAction.has_condition(scared, "charmed") and scared.conditions.has("frightened") and scared.conditions.has("charmed"), P + "existing Frightened and Charmed are suppressed, not removed")
	CombatAction.apply_condition(scared, "frightened", 10, "second_dread")
	h._assert(CombatAction.is_immune_to_condition(scared, "frightened") and not str(scared.condition_sources.get("frightened", {}).keys()).contains("second_dread"), P + "new Frightened is blocked by the immunity")
	h._assert(not bool(r2.get("saved", true)) and CombatAction.has_condition(angry, "calmed_indifferent") and InfluenceRules.effective_attitude(angry) == "indifferent" and angry.influence.attitude == "hostile", P + "the second creature's pick is option 2: Hostile reads Indifferent; the profile is untouched")
	var friendly := _humanoid("crown-sc07s5-r4", Vector2i(4, 0), -1000, "friendly")
	SpellEffects.grant(friendly, SpellEffects.begin_cast(caster, hush), "calmed_indifferent")
	h._assert(InfluenceRules.effective_attitude(friendly) == "friendly", P + "option 2 changes only a Hostile attitude")
	CombatAction.resolve_damage(angry, 3, "fire", {}, false, false, caster)
	h._assert(not CombatAction.has_condition(angry, "calmed_indifferent") and InfluenceRules.effective_attitude(angry) == "hostile" and CombatAction.has_condition(scared, "calmed"), P + "damage ends option 2 on that creature only; its attitude returns to Hostile")
	var r3 := CombatAction.resolve_spell(caster, beast, hush, false, {}, [], 2, 3)
	h._assert(not CombatAction.has_condition(beast, "calmed") and not CombatAction.has_condition(beast, "calmed_indifferent"), P + "a non-Humanoid is not affected (%s)" % str(r3.get("message", "")))
	for key in SpellEffects.records(scared).keys(): SpellEffects.remove(scared, str(key))
	h._assert(not CombatAction.has_condition(scared, "calmed") and CombatAction.has_condition(scared, "frightened") and CombatAction.has_condition(scared, "charmed"), P + "when the spell ends the suppressed conditions resume")
	CrownSc01Support01Flow._forget(str(hush.id))

static func _player_casts(h) -> void:
	var bard := ConversionBatch002Checks.actor("crown-sc07s5-bard", "bard", 1)
	var learned := ConversionBatch001Flow._prepare(bard, [])
	for _level in 2:
		bard.level_up()
	learned = learned and ConversionBatch001Flow._prepare(bard, ["calm_emotions"])
	h._assert(learned and bard.level == 3 and "calm_emotions" in bard.get_spell_option_ids(false), P + "a Bard reaches level 3 and selects Calm Emotions through ordinary class selection")
	PlayerManager.set_player_character(0, bard)
	PartyManager.reset()
	PartyManager.register_player_character(0, bard)
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	h._ready_spell_components(bard)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	var scared := _humanoid("crown-sc07s5-scared", Vector2i(3, 0), -1000)
	var wolf := _humanoid("crown-sc07s5-wolf", Vector2i(3, 1), -1000)
	wolf["creature_type"] = "beast"
	CombatAction.apply_condition(scared, "frightened", 10, "dread_source")
	combat.monster_entities.clear()
	combat.monster_entities.assign([scared, wolf])
	for m in [scared, wolf]: combat.tracker.add_combatant(str(m.id), str(m.name), false, m, 5, 10)
	combat._update_grid_entities()
	bard.spell_slots = {"1": 0, "2": 2}
	GameManager.test_mode = false
	combat.turn_budget.action_available = true
	ConversionBatch002Flow._select(h, combat, bard, "calm_emotions", 2)
	for _frame in 60:
		var level_menu: PopupMenu = null
		for child in combat.hud.get_children():
			if child is PopupMenu and child.visible and child.item_count > 0 and child.get_item_text(0).begins_with("Level"): level_menu = child
		if level_menu != null:
			level_menu.id_pressed.emit(level_menu.get_item_id(0))
			break
		await h.get_tree().process_frame
	await h.get_tree().process_frame
	combat._on_hex_clicked(Vector2i(3, 0))
	var menu: PopupMenu = null
	for _frame in 120:
		for child in combat.hud.get_children():
			if child is PopupMenu and child.visible: menu = child
		if menu != null and menu.get_item_text(0).begins_with("Level"):
			menu.id_pressed.emit(menu.get_item_id(0))
			menu = null
		if menu != null: break
		await h.get_tree().process_frame
	h._assert(menu != null and menu.item_count == 2 and menu.get_item_text(0) == "Calmed" and menu.get_item_text(1) == "Calmed Indifferent", P + "the player is offered both Calm Emotions options")
	if menu != null: menu.id_pressed.emit(0)
	# Since support 06 the option is asked per creature in the Sphere (the Bard is in it too).
	var answered := [menu]
	for _frame in 120:
		for child in combat.hud.get_children():
			if child is PopupMenu and child.visible and child not in answered:
				answered.append(child)
				child.id_pressed.emit(0)
		await h.get_tree().process_frame
	await ConversionBatch002Flow._wait_resolution(h, combat)
	h._assert(CombatAction.has_condition(scared, "calmed") and not CombatAction.has_condition(scared, "frightened") and not CombatAction.has_condition(wolf, "calmed") and str(bard.concentrating_on.get("spell_id", "")) == "calm_emotions" and int(bard.spell_slots["2"]) == 1, P + "picker + option prompt + area click: the Humanoid fails, is calmed and its Frightened is suppressed; the beast is skipped (%s | %s | %s)" % [str(scared.conditions), str(bard.concentrating_on.get("spell_id", "")), combat.hud.log_text.text.right(500)])
	SpellEffects.end_concentration(bard, [scared, wolf])
	bard.concentrating_on = {}
	h._assert(not CombatAction.has_condition(scared, "calmed") and CombatAction.has_condition(scared, "frightened"), P + "ending concentration restores the suppressed Frightened")
	GameManager.test_mode = true
	h._teardown_scene(combat)

static func _checkpoint(h) -> void:
	var caster := ConversionBatch002Checks.actor("crown-sc07s5-saver", "bard", 5)
	var ally := ConversionBatch002Checks.actor("crown-sc07s5-ally", "fighter", 1)
	PartyManager.reset()
	PlayerManager.set_player_character(0, caster)
	PlayerManager.set_player_character(1, ally)
	PartyManager.register_player_character(0, caster)
	PartyManager.register_player_character(1, ally)
	ally.race_id = "human"
	ally.ability_scores.from_dict({"STR": 16, "DEX": 10, "CON": 12, "INT": 10, "WIS": 10, "CHA": 1})
	ally.add_condition("frightened", 600, "old_dread")
	var spell := DataLoader.get_spell("calm_emotions").duplicate(true)
	spell["_chosen_condition"] = "calmed"
	for _attempt in 80:
		CombatAction.resolve_spell(caster, ally, spell, false, {}, [], 2, 2)
		if ally.conditions.has("calmed"): break
		for key in SpellEffects.records(ally).keys(): SpellEffects.remove(ally, str(key))
	caster.concentrating_on = {"spell_id": "calm_emotions", "effect_source": CrownSc07Support01Flow._source(ally), "targets": [ally]}
	h._assert(ally.has_condition("calmed") and not ally.has_condition("frightened") and ally.conditions.has("frightened"), P + "a party member carries a calmed record with Frightened suppressed")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.test_mode = true
	GameManager.game_in_progress = true
	h._assert(SaveManager.get_save_block_reason().is_empty() and SaveManager.save_game(SLOT), P + "the record saves at the overworld checkpoint")
	h._assert(SaveManager._validate_save_data(SaveManager._read_save(SLOT)).is_empty(), P + "the DTO passes production save preflight")
	h._assert(SaveManager.load_game(SLOT), P + "the checkpoint reloads through SaveManager")
	print("CROWN_SC_07_SUPPORT_05_CHECKPOINT_READY")

static func _recover(h) -> void:
	h._assert(SaveManager.load_game(SLOT), P + "a fresh process loads the real checkpoint")
	var ally: Character = PartyManager.characters.get("crown-sc07s5-ally")
	var caster: Character = PartyManager.characters.get("crown-sc07s5-saver")
	if ally == null or caster == null:
		h._assert(false, P + "the caster and target identities recover")
		return
	h._assert(ally.has_condition("calmed") and not ally.has_condition("frightened") and CombatAction.is_immune_to_condition(ally, "charmed"), P + "fresh-process recovery keeps calmed: Frightened stays suppressed and Charmed is blocked")
	SpellEffects.end_concentration(caster, [ally])
	h._assert(not ally.has_condition("calmed") and ally.has_condition("frightened"), P + "the recovered record ends with concentration and Frightened resumes")
	print("CROWN_SC_07_SUPPORT_05_FRESH_PROCESS_PASSED")

static func run(h) -> void:
	h._enter_test("crown_sc_07_support_05_flow")
	if OS.get_environment("CROWN_SC_07_SUPPORT_05_RECOVER") == "1":
		_recover(h)
		h._exit_test()
		return
	h._setup_world()
	_contract_checks(h)
	_renamed_checks(h)
	await _player_casts(h)
	_checkpoint(h)
	h._exit_test()
