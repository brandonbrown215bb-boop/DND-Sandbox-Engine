## Focused S-111/S-112 checks on the shared production damage boundary.
class_name Batch031Checks
extends RefCounted

static func load_fixtures() -> void:
	DataLoader._load_json_file("res://data/fixtures/batch_031/spells/linked_damage.json", "spell")

static func _character(id: String, hp: int = 40) -> Character:
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 16, "DEX": 14, "CON": 14, "INT": 12, "WIS": 12, "CHA": 10})
	var character := Character.new()
	character.initialize(id, "human", "fighter", scores)
	character.character_id = id
	character.max_hp = hp
	character.current_hp = hp
	return character

static func _grant(target: Character, caster: Character, policy_spell: String) -> String:
	var spell := DataLoader.get_spell(policy_spell)
	var cast := SpellEffects.begin_cast(caster, spell)
	DamageLinkRules.grant(target, cast, spell.get("effects", [])[0].get("policy", {}))
	return str(cast.get("source_id", ""))

static func run(check: Callable) -> void:
	load_fixtures()
	if not DataLoader.get_load_errors().is_empty():
		print("Batch 031 fixture errors: ", DataLoader.get_load_errors())
	check.call(DataLoader.get_load_errors().is_empty(), "031 loaded neutral and renamed source-link consumers pass ordinary spell validation")
	var protector := _character("b031_protector")
	var partner := _character("b031_partner")
	var foe := _character("b031_foe")
	protector.willingness = "willing"
	partner.willingness = "willing"
	partner.feature_uses["damage_resistances"] = ["fire"]
	protector.feature_uses["damage_vulnerabilities"] = ["fire"]
	PartyManager.characters[protector.character_id] = protector
	PartyManager.characters[partner.character_id] = partner
	var link_source := _grant(partner, protector, "fixture:b031_split_link")
	SpellEffects.prune(partner)
	check.call(SpellEffects.records(partner).has(link_source), "031 source-owned link survives the shared effect pruning pass without needing a condition")
	var fire := CombatAction.resolve_damage(partner, 5, "fire", {"players": [protector, partner]}, false, false, foe, 301, [], 5)
	var split: Dictionary = fire.get("damage_link", {})
	check.call(split.get("amount_transferred", -1) == 2 and split.get("amount_retained", -1) == 3 and split.get("rounding", "") == "floor", "031 odd split rounds the transferred share down and conserves five damage at its split stage")
	check.call(fire.get("recipient_receipts", []).size() == 2 and fire.recipient_receipts[0].raw == 3 and fire.recipient_receipts[0].resolved == 1 and fire.recipient_receipts[1].raw == 2 and fire.recipient_receipts[1].resolved == 4, "031 both recipients keep separate raw/resolved receipts and apply their own resistance or vulnerability")
	check.call(int(fire.get("damage", 0)) == 5 and int(fire.get("resolved", 0)) == 5, "031 recipient defenses change outcomes without rerolling or losing the split-stage total")
	var cold := CombatAction.resolve_damage(partner, 3, "cold", {"players": [protector, partner]}, false, false, foe, 302, [], 3)
	check.call(cold.get("damage_link", {}).get("amount_transferred", -1) == 1 and cold.get("recipient_receipts", []).size() == 2, "031 mixed typed components split independently under the same linked actors")

	var hp_before_protector := protector.current_hp
	var hp_before_partner := partner.current_hp
	var redirect_source := _grant(partner, protector, "fixture:b031_renamed_redirect_link")
	var redirect := CombatAction.resolve_damage(partner, 7, "cold", {"players": [protector, partner], "damage_link_source_instance_id": redirect_source}, false, false, foe, 303, [], 7)
	check.call(redirect.get("damage_link", {}).get("operation", "") == "redirect" and redirect.get("damage_link", {}).get("amount_transferred", -1) == 7 and redirect.recipient_receipts.size() == 1, "031 renamed definition redirects the full typed occurrence to its exact linked actor")
	check.call(partner.current_hp == hp_before_partner and protector.current_hp < hp_before_protector and redirect.get("hp_loss", 0) == 7, "031 full redirect leaves the original target untouched and settles the recipient once")
	var partial_source := _grant(partner, protector, "fixture:b031_partial_redirect_link")
	var partial := CombatAction.resolve_damage(partner, 5, "cold", {"players": [protector, partner], "damage_link_source_instance_id": partial_source}, false, false, foe, 307, [], 5)
	check.call(partial.get("damage_link", {}).get("operation", "") == "redirect" and partial.get("damage_link", {}).get("amount_transferred", -1) == 3 and partial.get("damage_link", {}).get("amount_retained", -1) == 2 and partial.get("recipient_receipts", []).size() == 2, "031 partial redirect rounds the transferred share up and leaves the remainder on the original target")

	var declined_before := protector.current_hp
	var partner_before_decline := partner.current_hp
	var declined := CombatAction.resolve_damage(partner, 5, "cold", {"players": [protector, partner], "damage_link_declined": true}, false, false, foe, 304, [], 5)
	check.call(declined.get("damage_link", {}).is_empty() and partner.current_hp == partner_before_decline - 5 and protector.current_hp == declined_before, "031 cancellation follows keep_original without transferring or charging a second action")
	var stale := CombatAction.resolve_damage(partner, 5, "cold", {"players": [protector, partner], "damage_link_source_instance_id": "spell:missing:77", "damage_link_fallback": "keep_original"}, false, false, foe, 305, [], 5)
	check.call(stale.get("damage_link", {}).is_empty() and partner.current_hp == partner_before_decline - 10 and protector.current_hp == declined_before, "031 stale source selection follows its captured fallback and cannot transfer damage to a replacement recipient")

	# Only one overlapping link participates; an explicit current exact source
	# is revalidated and never stacks with its sibling.
	SpellEffects.remove(partner, link_source, "source_removed")
	var selected_link := CombatAction.resolve_damage(partner, 5, "cold", {"players": [protector, partner], "damage_link_source_instance_id": redirect_source}, false, false, foe, 306, [], 5)
	check.call(selected_link.get("damage_link", {}).get("source_instance_id", "") == redirect_source and selected_link.get("recipient_receipts", []).size() == 1, "031 source removal disables only its exact link and an explicit sibling selection settles once")
	SpellEffects.remove(partner, redirect_source, "source_removed")
	SpellEffects.remove(partner, partial_source, "source_removed")
	PartyManager.characters.erase(protector.character_id)
	PartyManager.characters.erase(partner.character_id)
	_review_regressions(check)

static func _concentrating_link(target: Character, owner: Character, spell_id: String = "fixture:b031_split_link") -> String:
	var source := _grant(target, owner, spell_id)
	owner.concentrating_on = {"spell_id": spell_id, "effect_source": source, "targets": [target]}
	return source

static func _review_regressions(check: Callable) -> void:
	var owner := _character("b031_review_owner", 100)
	var target := _character("b031_review_target", 100)
	var foe := _character("b031_review_foe", 100)
	owner.willingness = "willing"
	target.willingness = "willing"
	PartyManager.characters[owner.character_id] = owner
	PartyManager.characters[target.character_id] = target
	owner.add_modifier("roll", "save:CON", -100, 999)
	var source := _concentrating_link(target, owner)
	var ordered := DataLoader.get_spell("fixture:b031_ordered_arc")
	var result := CombatAction.resolve_spell(foe, target, ordered, false, {}, [], 1, 5)
	check.call(owner.current_hp == 98 and target.current_hp == 95 and owner.concentrating_on.is_empty() and not SpellEffects.records(target).has(source) and result.get("step_results", []).size() == 2, "031 R1 linked concentration failure removes the exact link before the later ordered damage step")

	var one_step := ordered.duplicate(true)
	one_step["steps"] = [ordered["steps"][0].duplicate(true)]
	owner.current_hp = 100
	target.current_hp = 100
	source = _concentrating_link(target, owner, "fixture:b031_renamed_redirect_link")
	target.concentrating_on = {"spell_id": "shield_of_faith", "targets": [target]}
	target.add_modifier("roll", "save:CON", -100, 999)
	result = CombatAction.resolve_spell(foe, target, one_step, false, {}, [], 1, 5)
	check.call(target.current_hp == 100 and not target.concentrating_on.is_empty() and owner.current_hp == 95 and owner.concentrating_on.is_empty() and not SpellEffects.records(target).has(source), "031 R1 full redirect checks only the actual recipient's concentration and preserves the untouched original")
	target.concentrating_on.clear()
	owner.current_hp = 1
	source = _concentrating_link(target, owner)
	result = CombatAction.resolve_spell(foe, target, one_step, false, {}, [], 1, 5)
	check.call(owner.current_hp == 0 and owner.concentrating_on.is_empty() and not SpellEffects.records(target).has(source), "031 R1 linked knockout ends concentration and its exact source immediately")

	owner.current_hp = 100
	owner.is_alive = true
	target.current_hp = 100
	source = _concentrating_link(target, owner)
	target.concentrating_on = {"spell_id": "shield_of_faith", "targets": [target]}
	for actor in [target, owner]:
		actor.features.append({"id": "rogue_stroke_of_luck"})
		actor.feature_uses["rogue_stroke_of_luck"] = 1
	result = CombatAction.resolve_spell(foe, target, ordered, false, {}, [], 1, 5)
	check.call(result.has("concentration_request") and result.concentration_request.target == target and target.current_hp == 97 and owner.current_hp == 98, "031 R1 first recipient's pending concentration choice pauses before the later step")
	var first_pending := result.duplicate(true)
	result = CombatAction.finish_pending_concentration_choice(foe, target, result, {"accepted": false})
	check.call(result.has("concentration_request") and result.concentration_request.target == owner and target.current_hp == 97 and owner.current_hp == 98, "031 R1 declining the first concentration choice advances to the linked recipient without replaying damage")
	var refused := CombatAction.finish_pending_concentration_choice(foe, target, first_pending, {"accepted": true})
	check.call(bool(refused.get("refused", false)) and target.current_hp == 97 and owner.current_hp == 98, "031 R1 stale first-recipient callback cannot mutate the newer linked choice")
	result = CombatAction.finish_pending_concentration_choice(foe, owner, result, {"accepted": false})
	# The second step can prompt the original actor again only if it still has
	# concentration. Both declined saves above have already ended it.
	check.call(not result.has("concentration_request") and result.get("step_results", []).size() == 2 and target.current_hp == 95 and owner.current_hp == 98 and owner.concentrating_on.is_empty() and target.concentrating_on.is_empty() and not SpellEffects.records(target).has(source), "031 R1 final linked choice resumes the next step once with the original target and ended link")

	owner.current_hp = 100
	target.current_hp = 100
	source = _grant(target, owner, "fixture:b031_split_link")
	foe.add_condition("ray_of_enfeeblement", 100)
	var rolls := [0]
	var observe := func(detail: Dictionary):
		if int(detail.get("sides", 0)) == 8: rolls[0] += 1
	Dice.dice_rolled.connect(observe)
	result = CombatAction.resolve_damage(target, 40, "cold", {}, false, false, foe, 931)
	Dice.dice_rolled.disconnect(observe)
	var penalty := int(result.get("source_roll_penalty", 0))
	check.call(rolls[0] == 1 and penalty >= 1 and penalty <= 8 and int(result.get("resolved", 0)) == 40 - penalty and int(result.damage_link.amount_retained) + int(result.damage_link.amount_transferred) == 40 - penalty, "031 R2 source penalty rolls once before splitting and the recipients conserve the reduced amount")
	SpellEffects.remove(target, source, "regression_cleanup")
	foe.remove_condition("ray_of_enfeeblement")

	# Extra typed packets can consume only Temporary HP and still require their
	# own recipient amounts in the shared concentration aftermath.
	owner.temp_hp = 100
	target.temp_hp = 100
	source = _grant(target, owner, "fixture:b031_split_link")
	Batch031Controls._seed_hit()
	var weapon := {"damage": "5", "damage_type": "fire", "attack_bonus_override": 100, "ability": "STR"}
	result = CombatAction.resolve_weapon_attack(foe, target, weapon, false, false, {}, {"formula": "30", "type": "cold"})
	var settlements := DamageLinkRules.recipient_settlements(target, result)
	check.call(result.hit and result.damage_components.size() == 2 and settlements.size() == 2 and settlements[0].resolved == 18 and settlements[1].resolved == 17 and target.temp_hp == 82 and owner.temp_hp == 83, "031 linked Temporary-HP-only additional packets retain both recipients' full concentration damage")
	SpellEffects.remove(target, source, "regression_cleanup")
	owner.temp_hp = 0
	target.temp_hp = 0

	var combined := DataLoader.get_spell("fixture:b031_combined_link")
	var cast := SpellEffects.begin_cast(owner, combined)
	SharedSpell.apply_custom_effects(owner, target, combined.effects, {"effect_cast": cast}, 1)
	check.call(SharedSpell.content_error(combined).is_empty() and target.has_condition("blessed") and SpellEffectPersistence.saved_state_error(target.to_dict()).is_empty(), "031 R3 combined link and condition validate under their exact shared source")
	var malformed := target.to_dict()
	malformed["spell_effects"][cast.source_id]["conditions"].append("poisoned")
	check.call(not SpellEffectPersistence.saved_state_error(malformed).is_empty(), "031 R3 combined link does not bypass malformed condition ownership checks")
	SpellEffects.remove(target, cast.source_id, "regression_cleanup")
	owner.concentrating_on.clear()
	target.concentrating_on.clear()
	PartyManager.characters.erase(owner.character_id)
	PartyManager.characters.erase(target.character_id)
