## SC-05 support 02: Blindness/Deafness, Blur, Charm Person and Faerie Fire as shared data.
## New generic pieces: grant_condition.condition_options (caster-chosen condition), the
## shared charmed/blurred/outlined conditions with condition-keyed attack consumers, and
## the save_advantage_if_fighting_target shared field.
class_name CrownSc05Support02Flow
extends RefCounted

const P := "SC-05 support 02: "
const SLOT := "crown_sc_05_support_02"

static func _humanoid(id: String, hex: Vector2i, scores: Dictionary) -> Dictionary:
	var m := CrownSc01Support01Flow._monster(id, hex, 10, scores)
	m["creature_type"] = "humanoid"
	return m

static func _contract_checks(h) -> void:
	var bd := DataLoader.get_spell("blindness/deafness")
	h._assert(SharedSpell.uses(bd) and SharedSpell.content_error(bd).is_empty() and int(bd.range) == 24 and bd.repeat_save == "CON" and bd.repeat_save_schedule == "target_turn_end" and bd.effects[0].condition_options == ["blinded", "deafened"], P + "Blindness/Deafness is shared data (120 ft, Con save, caster-chosen Blinded/Deafened, end-of-turn repeat save)")
	h._assert(SharedSpell.uses(DataLoader.get_spell("blur")) and SharedSpell.content_error(DataLoader.get_spell("blur")).is_empty(), P + "Blur is shared data")
	var cp := DataLoader.get_spell("charm_person")
	h._assert(SharedSpell.uses(cp) and SharedSpell.content_error(cp).is_empty() and cp.target_creature_types == ["humanoid"] and bool(cp.end_on_party_damage) and bool(cp.save_advantage_if_fighting_target), P + "Charm Person is shared data (Humanoid, Wis save with Advantage when fighting, ends on party damage)")
	h._assert(SharedSpell.uses(DataLoader.get_spell("faerie_fire")) and SharedSpell.content_error(DataLoader.get_spell("faerie_fire")).is_empty(), P + "Faerie Fire is shared data")
	var bad := bd.duplicate(true)
	bad.effects[0]["condition_options"] = ["blinded"]
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "a one-entry condition_options list is rejected")
	bad.effects[0]["condition_options"] = ["blinded", "charmed_by_magic"]
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "an unknown condition option is rejected")
	bad.effects[0]["condition_options"] = ["blinded", "deafened"]
	bad.effects[0]["condition"] = "blinded"
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "condition and condition_options together are rejected")
	var bad_adv := cp.duplicate(true)
	bad_adv["save_advantage_if_fighting_target"] = "yes"
	h._assert(not SharedSpell.content_error(bad_adv).is_empty(), P + "a non-Boolean save_advantage_if_fighting_target is rejected")
	var probe := bd.duplicate(true)
	probe["_selected_spell_slot_level"] = 4
	var cprobe := cp.duplicate(true)
	cprobe["_selected_spell_slot_level"] = 3
	h._assert(SpellCastTargeting._spell_upcast_maximum_targets(null, probe) == 3 and SpellCastTargeting._spell_upcast_maximum_targets(null, cprobe) == 3, P + "upcasting adds one target per slot level above the base level")

static func _renamed_checks(h) -> void:
	var caster := ConversionBatch002Checks.actor("crown-sc05s2-renamed", "wizard", 9)
	# Chosen condition plus target-turn repeat save.
	var dim := CrownSc01Support01Flow._renamed(h, "blindness/deafness", "crown_sc_05_support_02:neutral_dim")
	var target := CrownSc01Support01Flow._monster("crown-sc05s2-r1", Vector2i(20, 0), 10, {"constitution": 1})
	dim["_chosen_condition"] = "deafened"
	for _try in 40:
		CombatAction.resolve_spell(caster, target, dim, false, {}, [], 2, 20)
		if target.conditions.has("deafened"): break
	h._assert(target.conditions.has("deafened") and not target.conditions.has("blinded"), P + "renamed chosen-condition spell grants only the picked Deafened through CombatAction.resolve_spell")
	var unpicked := CrownSc01Support01Flow._monster("crown-sc05s2-r2", Vector2i(2, 0), 10, {"constitution": 1})
	var bare := dim.duplicate(true)
	bare.erase("_chosen_condition")
	for _try in 10: CombatAction.resolve_spell(caster, unpicked, bare, false, {}, [], 2, 2)
	h._assert(not unpicked.conditions.has("blinded") and not unpicked.conditions.has("deafened"), P + "with no legal pick nothing is granted")
	var source := ""
	for key in target.spell_effects: source = str(key)
	target["ability_scores"] = {"constitution": 30}
	var repeat := {}
	var failed_repeat_kept := true
	for _try in 40:
		repeat = CombatAction.resolve_condition_spell_repeat_save(target, source)
		if bool(repeat.get("saved", false)): break
		failed_repeat_kept = failed_repeat_kept and target.conditions.has("deafened")
	h._assert(bool(repeat.get("saved", false)) and failed_repeat_kept and not target.conditions.has("deafened"), P + "a successful repeat Con save ends the chosen condition")
	CrownSc01Support01Flow._forget(str(dim.id))
	# Self disadvantage grant with the Blindsight/Truesight exemption.
	var haze := CrownSc01Support01Flow._renamed(h, "blur", "crown_sc_05_support_02:neutral_haze")
	CombatAction.resolve_spell(caster, caster, haze, false, {}, [], 2, 0)
	var seer := CrownSc01Support01Flow._monster("crown-sc05s2-seer", Vector2i(1, 0), 10)
	var sensed := CrownSc01Support01Flow._monster("crown-sc05s2-sensed", Vector2i(1, 0), 10)
	sensed["senses"] = {"blindsight": 10}
	var trued := CrownSc01Support01Flow._monster("crown-sc05s2-true", Vector2i(1, 0), 10)
	trued["senses"] = {"truesight": 120}
	h._assert(caster.has_condition("blurred") and CombatAction.is_blurred_against(caster, seer, 5) and not CombatAction.is_blurred_against(caster, sensed, 5) and not CombatAction.is_blurred_against(caster, trued, 5), P + "renamed self grant: attackers have Disadvantage unless they have Blindsight or Truesight")
	CrownSc01Support01Flow._forget(str(haze.id))
	# Charmed, fighting Advantage and the party-damage end.
	var lull := CrownSc01Support01Flow._renamed(h, "charm_person", "crown_sc_05_support_02:neutral_lull")
	var person := _humanoid("crown-sc05s2-person", Vector2i(2, 0), {"wisdom": 1})
	for _try in 40:
		CombatAction.resolve_spell(caster, person, lull, false, {}, [], 1, 2)
		if person.conditions.has("charmed"): break
	h._assert(person.conditions.has("charmed") and CombatAction.is_charmed_by(person, caster), P + "renamed Humanoid charm grants Charmed by the caster")
	# SRD "if you or your allies are fighting it": opposing initiative sides, not monster-ness.
	var fight := SpellResolutionContext.new()
	fight.caster = caster
	fight.spatial_host = SpellCastContext.new()
	fight.spatial_host.tracker = InitiativeTracker.new()
	var foe := _humanoid("crown-sc05s2-foe", Vector2i(4, 0), {})
	var bystander := _humanoid("crown-sc05s2-bystander", Vector2i(4, 1), {})
	var befriended := _humanoid("crown-sc05s2-friend", Vector2i(4, 2), {})
	befriended["influence"] = {"attitude": "friendly"}
	var party_ally := ConversionBatch002Checks.actor("crown-sc05s2-party", "fighter", 1)
	h._assert(not SpellSaveResolver.is_fighting_caster_side(fight, foe), P + "with no initiative running, nobody is fighting the target")
	fight.spatial_host.tracker.add_combatant(CombatAction.actor_id(caster), "caster", true, caster, 10, 10)
	fight.spatial_host.tracker.add_combatant(CombatAction.actor_id(party_ally), "ally", true, party_ally, 9, 10)
	fight.spatial_host.tracker.add_combatant(str(foe.id), "foe", false, foe, 8, 10)
	fight.spatial_host.tracker.add_combatant(str(befriended.id), "friend", false, befriended, 7, 10)
	h._assert(SpellSaveResolver.is_fighting_caster_side(fight, foe) and not SpellSaveResolver.is_fighting_caster_side(fight, bystander) and not SpellSaveResolver.is_fighting_caster_side(fight, befriended) and not SpellSaveResolver.is_fighting_caster_side(fight, party_ally), P + "fighting = an opposing-side initiative combatant; bystanders, friendly-attitude creatures and the caster's allies are not fighting")
	CombatAction._end_damage_broken_spell_effects(person, true)
	h._assert(not person.conditions.has("charmed"), P + "damage from the caster's side ends the charm")
	CrownSc01Support01Flow._forget(str(lull.id))
	# Outline: no Invisible benefit, Advantage for a sighted attacker.
	var glow := CrownSc01Support01Flow._renamed(h, "faerie_fire", "crown_sc_05_support_02:neutral_glow")
	var lit := CrownSc01Support01Flow._monster("crown-sc05s2-lit", Vector2i(3, 0), 10, {"dexterity": 1})
	lit.conditions["invisible"] = true
	for _try in 40:
		CombatAction.resolve_spell(caster, lit, glow, false, {}, [], 1, 3)
		if lit.conditions.has("outlined"): break
	var blind_attacker := ConversionBatch002Checks.actor("crown-sc05s2-blind", "fighter", 1)
	blind_attacker.add_condition("blinded", 10)
	h._assert(lit.conditions.has("outlined") and not CombatAction.is_invisible(lit) and CombatAction.is_outlined_for(lit, caster) and not CombatAction.is_outlined_for(lit, blind_attacker), P + "renamed outline removes the Invisible benefit and grants Advantage only to an attacker that can see")
	CrownSc01Support01Flow._forget(str(glow.id))

## Answer the popup whose first item matches `first` (the slot picker can stay visible).
static func _answer(h, hud, first: String, index: int) -> void:
	for _frame in 120:
		for child in hud.get_children():
			if child is PopupMenu and child.visible and not child.is_queued_for_deletion() and child.item_count > 0 and child.get_item_text(0).to_lower() == first:
				child.id_pressed.emit(index)
				return
		await h.get_tree().process_frame

## Ordinary level-up choice: keep the saved selection, add the wanted spells, fill any rest.
static func _learn_on_level_up(c: Character, wanted: Array) -> bool:
	var feature_id := c.get_spellcasting_feature_id()
	var chosen: Array[String] = []
	for id in c.feature_choices.get(feature_id, []): chosen.append(str(id))
	for id in wanted:
		if id not in chosen: chosen.append(str(id))
	for id in c.get_spell_option_ids(true) + c.get_spell_option_ids(false):
		var cantrip := int(DataLoader.get_spell(id).get("level", 0)) == 0
		var have := chosen.filter(func(x): return (int(DataLoader.get_spell(x).get("level", 0)) == 0) == cantrip).size()
		if have < c.get_spellcasting_capacity("cantrips" if cantrip else "prepared_spells") and id not in chosen: chosen.append(id)
	var ok := ClassProgression.choose_spell_selection(c, chosen)
	return ok

static func _player_casts(h) -> void:
	var wizard := ConversionBatch002Checks.actor("crown-sc05s2-wiz", "sorcerer", 1)
	var learned := ConversionBatch001Flow._prepare(wizard, ["charm_person"])
	for wanted in [[], ["blur", "blindness/deafness"]]:
		wizard.level_up()
		learned = learned and _learn_on_level_up(wizard, wanted)
	h._assert(learned and wizard.level == 3 and ["blindness/deafness", "blur", "charm_person"].all(func(id): return id in wizard.get_castable_spell_ids()) if wizard.has_method("get_castable_spell_ids") else learned, P + "Sorcerer learns Blindness/Deafness, Blur and Charm Person through ordinary class selection")
	var bard := ConversionBatch002Checks.actor("crown-sc05s2-bard", "bard", 1)
	h._assert(ConversionBatch001Flow._prepare(bard, ["faerie_fire"]), P + "Bard prepares Faerie Fire through ordinary class selection")
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	var far := CrownSc01Support01Flow._monster("crown-sc05s2-far", Vector2i(20, 0), 10, {"constitution": 1})
	var person := _humanoid("crown-sc05s2-p", Vector2i(2, 0), {"wisdom": 1})
	var beast := CrownSc01Support01Flow._monster("crown-sc05s2-beast", Vector2i(3, 0), 10, {"wisdom": 1, "dexterity": 1})
	var lit := CrownSc01Support01Flow._monster("crown-sc05s2-lit", Vector2i(5, 0), 10, {"dexterity": 1})
	combat.monster_entities.clear()
	combat.monster_entities.assign([far, person, beast, lit])
	combat._update_grid_entities()
	GameManager.test_mode = false
	# Blindness/Deafness at 100 feet, picking Deafened in the condition popup.
	var ok := false
	for _attempt in 40:
		far.conditions.clear(); far.condition_sources.clear(); far.spell_effects.clear()
		wizard.spell_slots = {"1": 0, "2": 2}
		combat.turn_budget.action_available = true
		ConversionBatch002Flow._select(h, combat, wizard, "blindness/deafness", 2)
		_answer(h, combat.hud, "blinded", 1)
		await combat._on_hex_clicked(far.hex_position)
		await ConversionBatch002Flow._wait_resolution(h, combat)
		if int(wizard.spell_slots["2"]) != 1:
			h._assert(false, P + "Blindness/Deafness pays one slot (%s)" % combat.hud.log_text.text.right(300))
			break
		if far.conditions.has("deafened"):
			ok = true
			break
	h._assert(ok and not far.conditions.has("blinded"), P + "picker + condition popup + hex click: a creature 100 feet away is Deafened as chosen")
	# Blur on self.
	wizard.spell_slots = {"1": 0, "2": 1}
	combat.turn_budget.action_available = true
	ConversionBatch002Flow._select(h, combat, wizard, "blur", 2)
	await combat._on_hex_clicked(Vector2i.ZERO)
	await ConversionBatch002Flow._wait_resolution(h, combat)
	h._assert(wizard.has_condition("blurred") and int(wizard.spell_slots["2"]) == 0 and str(wizard.concentrating_on.get("spell_id", wizard.concentrating_on.get("id", ""))) == "blur", P + "picker + self click: Blur blurs the caster under Concentration (%s)" % str(wizard.concentrating_on.keys()))
	h._assert(CombatAction.is_blurred_against(wizard, beast, 15), P + "a sighted attacker has Disadvantage against the blurred caster")
	# Charm Person: a beast is not a legal target; a Humanoid becomes Charmed.
	wizard.spell_slots = {"1": 1, "2": 0}
	combat.turn_budget.action_available = true
	ConversionBatch002Flow._select(h, combat, wizard, "charm_person", 1)
	await combat._on_hex_clicked(beast.hex_position)
	await ConversionBatch002Flow._wait_resolution(h, combat)
	combat.pending_action_type = ""
	h._assert(not beast.conditions.has("charmed") and int(wizard.spell_slots["1"]) == 1, P + "Charm Person refuses a non-Humanoid without spending the slot")
	ok = false
	for _attempt in 40:
		person.conditions.clear(); person.condition_sources.clear(); person.spell_effects.clear()
		wizard.spell_slots = {"1": 1, "2": 0}
		combat.turn_budget.action_available = true
		ConversionBatch002Flow._select(h, combat, wizard, "charm_person", 1)
		await combat._on_hex_clicked(person.hex_position)
		await ConversionBatch002Flow._wait_resolution(h, combat)
		if person.conditions.has("charmed"):
			ok = true
			break
	h._assert(ok and CombatAction.is_charmed_by(person, wizard), P + "picker + hex click: the Humanoid is Charmed by the caster")
	# The Humanoid joins initiative as the opposing side (as a rolled encounter monster would).
	combat.tracker.add_combatant(str(person.id), str(person.name), false, person, 1, 10)
	var live := SpellResolutionContext.new()
	live.caster = wizard
	live.spatial_host = SpellCastContext.new()
	live.spatial_host.tracker = combat.tracker
	h._assert(SpellSaveResolver.is_fighting_caster_side(live, person), P + "in the live encounter the opposing Humanoid counts as fighting the caster's side (Charm Person save Advantage)")
	combat.tracker.remove_combatant(str(person.id))
	GameManager.test_mode = true
	h._teardown_scene(combat)
	# Faerie Fire 20-foot Cube from the bard, in its own encounter (directed by an adjacent hex click).
	PlayerManager.set_player_character(0, bard)
	PartyManager.reset()
	PartyManager.register_player_character(0, bard)
	combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	combat.monster_entities.clear()
	lit.hex_position = Vector2i(2, 0)
	beast.hex_position = Vector2i(3, 0)
	combat.monster_entities.assign([far, beast, lit])
	combat._update_grid_entities()
	GameManager.test_mode = false
	ok = false
	for _attempt in 40:
		for m in [beast, lit]:
			m.conditions.clear(); m.condition_sources.clear(); m.spell_effects.clear()
		lit.conditions["invisible"] = true
		bard.spell_slots = {"1": 2}
		bard.concentrating_on = {}
		ConversionBatch002Flow._select(h, combat, bard, "faerie_fire", 1)
		await combat._on_hex_clicked(Vector2i(1, 0))
		await ConversionBatch002Flow._wait_resolution(h, combat)
		if int(bard.spell_slots["1"]) != 1:
			h._assert(false, P + "Faerie Fire pays one slot (%s)" % combat.hud.log_text.text.right(300))
			break
		if lit.conditions.has("outlined"):
			ok = true
			break
	h._assert(ok and not CombatAction.is_invisible(lit) and CombatAction.is_outlined_for(lit, wizard), P + "picker + Cube click: an Invisible creature that fails is outlined, loses the Invisible benefit and grants Advantage")
	h._assert(not far.conditions.has("outlined"), P + "a creature outside the Cube is untouched")
	CombatPerception.configure_ambient_light(combat.hex_grid, "dark")
	combat._update_grid_entities()
	h._assert(CombatPerception.illumination_level_at(combat.hex_grid, Vector2i(2, 2)) == "dim" and CombatPerception.illumination_level_at(combat.hex_grid, Vector2i(2, 0)) == "dim" and CombatPerception.illumination_level_at(combat.hex_grid, Vector2i(-2, 0)) == "dark", P + "in darkness the outlined creature sheds Dim Light in a 10-foot radius and no farther")
	GameManager.test_mode = true
	h._teardown_scene(combat)

## Durable checkpoint: a chosen-option Deafened record and a self Blurred record save, pass preflight and reload.
static func _checkpoint(h) -> void:
	var caster := ConversionBatch002Checks.actor("crown-sc05s2-saver", "wizard", 3)
	var ally := ConversionBatch002Checks.actor("crown-sc05s2-ally", "fighter", 1)
	PartyManager.reset()
	PlayerManager.set_player_character(0, caster)
	PlayerManager.set_player_character(1, ally)
	PartyManager.register_player_character(0, caster)
	PartyManager.register_player_character(1, ally)
	var deaf := DataLoader.get_spell("blindness/deafness").duplicate(true)
	deaf["_chosen_condition"] = "deafened"
	ally.ability_scores.from_dict({"STR": 10, "DEX": 10, "CON": 1, "INT": 10, "WIS": 10, "CHA": 10})
	for _attempt in 40:
		CombatAction.resolve_spell(caster, ally, deaf, false, {}, [], 2, 24)
		if ally.has_condition("deafened"): break
	var blur_cast := CombatAction.resolve_spell(caster, caster, DataLoader.get_spell("blur"), false, {}, [], 2, 0)
	caster.concentrating_on = {"spell_id": "blur", "effect_source": str(blur_cast.get("effect_cast", {}).get("source_id", "")), "targets": [caster]}
	h._assert(ally.has_condition("deafened") and not ally.has_condition("blinded") and caster.has_condition("blurred"), P + "the party carries a chosen Deafened record and a Blurred record")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.test_mode = true
	GameManager.game_in_progress = true
	h._assert(SaveManager.get_save_block_reason().is_empty() and SaveManager.save_game(SLOT), P + "the records save at the overworld checkpoint")
	h._assert(SaveManager._validate_save_data(SaveManager._read_save(SLOT)).is_empty(), P + "the DTO passes production save preflight")
	h._assert(SaveManager.load_game(SLOT), P + "the checkpoint reloads through SaveManager")
	var restored_ally: Character = PartyManager.characters.get("crown-sc05s2-ally")
	var restored_caster: Character = PartyManager.characters.get("crown-sc05s2-saver")
	h._assert(restored_ally != null and restored_caster != null and restored_ally.has_condition("deafened") and restored_caster.has_condition("blurred"), P + "reload restores Deafened and Blurred")
	print("CROWN_SC_05_SUPPORT_02_CHECKPOINT_READY")

static func _recover(h) -> void:
	h._assert(SaveManager.load_game(SLOT), P + "a fresh process loads the real checkpoint")
	var ally: Character = PartyManager.characters.get("crown-sc05s2-ally")
	var caster: Character = PartyManager.characters.get("crown-sc05s2-saver")
	if ally == null or caster == null:
		h._assert(false, P + "caster and target identities recover")
		return
	h._assert(ally.has_condition("deafened") and not ally.has_condition("blinded") and caster.has_condition("blurred") and CombatAction.is_blurred_against(caster, {"id": "x", "conditions": {}}, 5), P + "fresh-process recovery keeps the chosen Deafened and the Blurred records")
	var source := ""
	for key in SpellEffects.records(ally): source = str(key)
	ally.ability_scores.from_dict({"STR": 10, "DEX": 10, "CON": 30, "INT": 10, "WIS": 10, "CHA": 10})
	var ended := false
	for _attempt in 40:
		CombatAction.resolve_condition_spell_repeat_save(ally, source)
		if not ally.has_condition("deafened"):
			ended = true
			break
	h._assert(ended and SpellEffects.records(ally).is_empty(), P + "the recovered Deafened record ends on a successful repeat Constitution save")
	h._assert(SaveManager.save_game(SLOT), P + "the recovered state saves")
	print("CROWN_SC_05_SUPPORT_02_FRESH_PROCESS_PASSED")

static func run(h) -> void:
	h._enter_test("crown_sc_05_support_02_flow")
	if OS.get_environment("CROWN_SC_05_SUPPORT_02_RECOVER") == "1":
		_recover(h)
		h._exit_test()
		return
	h._setup_world()
	_contract_checks(h)
	_renamed_checks(h)
	await _player_casts(h)
	_checkpoint(h)
	h._exit_test()
