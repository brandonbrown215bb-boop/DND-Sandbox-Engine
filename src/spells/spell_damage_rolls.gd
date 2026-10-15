## Spell damage/healing scaling, damage rolls, rerolls and settlement.
class_name SpellDamageRolls
extends RefCounted

const FAILED_SAVE_BONUS_PAYMENT_POLICIES := ["pay_on_choice", "pay_on_converted_success"]
const RESOLUTION_WINDOW_ORDER := ["before_roll", "after_natural", "provisional_outcome", "pre_damage", "post_damage"]
const RESOLUTION_COMMON_FIELDS := ["kind", "actor_id", "target_id", "action_id", "action_invocation_id", "spell_definition_id", "spell_invocation_id", "source_definition_id", "source_instance_id", "source_owner_id"]
const RESOLUTION_WINDOW_FIELDS := {
	"before_roll": [],
	"after_natural": ["roll_natural", "roll_modifier", "roll_total"],
	"provisional_outcome": ["roll_natural", "roll_modifier", "roll_total", "target_ac", "provisional_hit", "provisional_critical"],
	"pre_damage": ["roll_natural", "roll_modifier", "roll_total", "target_ac", "final_hit", "critical", "roll_outcome_override", "attack_adjustment"],
	"post_damage": ["roll_natural", "roll_modifier", "roll_total", "target_ac", "final_hit", "critical", "damage_occurrence_id", "damage_type", "damage_raw", "damage_resolved", "damage_hp_loss"]
}

static func spell_damage_formula(caster: Character, spell_data: Dictionary, slot_level: int = 0) -> String:
	var formula := str(spell_data.get("damage", "0"))
	if caster == null:
		return formula
	var base_level := int(spell_data.get("level", 0))
	if base_level == 0:
		var scaling: Dictionary = spell_data.get("scaling", {})
		var thresholds: Array[int] = []
		for threshold in scaling:
			if str(threshold).is_valid_int():
				thresholds.append(int(threshold))
		thresholds.sort()
		for threshold in thresholds:
			if caster.level >= threshold:
				formula = str(scaling[str(threshold)])
	var upcast: Dictionary = spell_data.get("upcast", {})
	var extra_dice := str(upcast.get("damage_per_level", ""))
	var start_level := int(upcast.get("starting_level", base_level))
	var interval := maxi(1, int(upcast.get("levels_per_increment", 1)))
	var increments := int(maxi(0, slot_level - start_level) / interval)
	if increments > 0 and not extra_dice.is_empty():
		var die_pattern := RegEx.new()
		die_pattern.compile("^([0-9]*)[dD]([0-9]+)$")
		var die_match := die_pattern.search(extra_dice.replace(" ", ""))
		if die_match != null:
			var dice_per_increment := 1 if die_match.get_string(1).is_empty() else int(die_match.get_string(1))
			var sides := int(die_match.get_string(2))
			formula += " + %dd%d" % [dice_per_increment * increments, sides]
	return formula


static func spell_delayed_damage_for_resolution(caster: Character, spell_data: Dictionary, resolution: Dictionary) -> Dictionary:
	var delayed: Dictionary = spell_data.get("delayed_damage", {})
	if delayed.is_empty() or not bool(resolution.get("hit", false)):
		return {}
	var delayed_spell := spell_data.duplicate(true)
	delayed_spell["damage"] = str(delayed.get("damage", ""))
	delayed_spell["damage_type"] = str(delayed.get("damage_type", spell_data.get("damage_type", "acid")))
	return {
		"spell_id": str(spell_data.get("id", "")),
		"formula": SpellDamageRolls.spell_damage_formula(caster, delayed_spell, int(resolution.get("slot_level", spell_data.get("level", 0)))),
		"damage_type": str(delayed_spell["damage_type"]),
		"trigger": str(delayed.get("trigger", "end_of_target_next_turn"))
	}


static func spell_effects_for_slot_level(spell_data: Dictionary, slot_level: int) -> Array:
	var effects: Array = spell_data.get("effects", []).duplicate(true)
	var upcast: Dictionary = spell_data.get("upcast", {})
	var start_level := int(upcast.get("starting_level", int(spell_data.get("level", 0))))
	var healing_per_level := int(upcast.get("healing_per_level", 0))
	var extra_healing := maxi(0, slot_level - start_level) * healing_per_level
	var healing_dice_per_level := str(upcast.get("healing_dice_per_level", ""))
	var healing_increments := maxi(0, slot_level - start_level)
	var temp_hp_per_level := int(upcast.get("temporary_hp_per_level", 0))
	var extra_temp_hp := maxi(0, slot_level - start_level) * temp_hp_per_level
	var hp_per_level := int(upcast.get("hit_points_per_level", 0))
	var extra_hit_points := maxi(0, slot_level - start_level) * hp_per_level
	for index in effects.size():
		var effect_type := str(effects[index].get("type", ""))
		if effect_type == "heal" and extra_healing > 0:
			effects[index]["value"] = int(effects[index].get("value", 0)) + extra_healing
		elif effect_type == "heal" and healing_increments > 0 and not healing_dice_per_level.is_empty():
			var die_pattern := RegEx.new()
			die_pattern.compile("^([0-9]*)[dD]([0-9]+)$")
			var die_match := die_pattern.search(healing_dice_per_level.replace(" ", ""))
			if die_match != null:
				var dice_per_increment := 1 if die_match.get_string(1).is_empty() else int(die_match.get_string(1))
				var sides := int(die_match.get_string(2))
				var base_value := str(effects[index].get("value", "0"))
				effects[index]["value"] = "%s + %dd%d" % [base_value, dice_per_increment * healing_increments, sides]
		elif effect_type == "temporary_hp" and extra_temp_hp > 0:
			effects[index]["value"] = "%s + %d" % [str(effects[index].get("value", "0")), extra_temp_hp]
		elif effect_type == "aid_hp_bonus" and extra_hit_points > 0:
			effects[index]["value"] = int(effects[index].get("value", 0)) + extra_hit_points
	return effects


static func _roll_spell_damage(caster: Character, formula: String, repetitions: int, decisions: Dictionary) -> Dictionary:
	var context: Dictionary = decisions.get("spell_damage_context", {})
	# A damaging area spell rolls damage once for every target of that cast.
	if context.has("details"):
		return context["details"]
	var details := {"formula": formula, "dice_terms": [], "modifiers": [], "final_total": 0}
	for _repeat in repetitions:
		var roll := Dice.parse_dice_details(formula, {}, caster)
		details["dice_terms"].append_array(roll["dice_terms"])
		details["final_total"] = int(details["final_total"]) + int(roll["final_total"])
	if decisions.has("spell_damage_context"):
		context["details"] = details
	return details


static func _roll_sorcerous_burst_damage(caster: Character, formula: String, explode_on: int, ability: String) -> Dictionary:
	var details := Dice.parse_dice_details(formula, {}, caster)
	details["_sorcerous_burst_explode_on"] = explode_on
	details["_sorcerous_burst_extra_limit"] = maxi(0, caster.ability_scores.get_ability_modifier(ability))
	details["_sorcerous_burst_extra_rolled"] = 0
	details["_sorcerous_burst_triggered"] = []
	return SpellDamageRolls._resolve_sorcerous_burst_explosions(caster, details)


static func _resolve_sorcerous_burst_explosions(caster: Character, details: Dictionary) -> Dictionary:
	if not details.has("_sorcerous_burst_explode_on"):
		return details
	var explode_on := int(details["_sorcerous_burst_explode_on"])
	var extra_limit := int(details["_sorcerous_burst_extra_limit"])
	var extra_rolled := int(details["_sorcerous_burst_extra_rolled"])
	var triggered: Array = details["_sorcerous_burst_triggered"]
	for term_index in details.get("dice_terms", []).size():
		var term: Dictionary = details["dice_terms"][term_index]
		if int(term.get("sides", 0)) != 8 or str(term.get("label", "")).begins_with("-"):
			continue
		var index := 0
		while index < term.get("results", []).size() and extra_rolled < extra_limit:
			var trigger_key := "%d:%d" % [term_index, index]
			var is_kept := bool(term["kept"][index])
			if is_kept and int(term["results"][index]) == explode_on and not trigger_key in triggered:
				triggered.append(trigger_key)
				var should_explode := true
				while should_explode and extra_rolled < extra_limit:
					var roll := Dice.roll_single_details(8, caster)
					var result := int(roll["total"])
					var added_index: int = term["results"].size()
					term["results"].append_array(roll["rolls"])
					term["kept"].append_array(roll["kept"])
					term["count"] = term["results"].size()
					term["subtotal"] = int(term["subtotal"]) + result
					details["final_total"] = int(details["final_total"]) + result
					extra_rolled += 1
					if result == explode_on:
						var added_key := "%d:%d" % [term_index, added_index]
						triggered.append(added_key)
						should_explode = true
					else:
						should_explode = false
			index += 1
	details["_sorcerous_burst_extra_rolled"] = extra_rolled
	return details


static func _can_empower(caster: Character, decisions: Dictionary) -> bool:
	if caster == null or not bool(decisions.get("metamagic:empowered", false)):
		return false
	if not caster.has_feature("sorcerer_metamagic") or not "empowered_spell" in caster.sorcerer_metamagic_choices:
		return false
	var cha_mod := maxi(1, caster.ability_scores.get_ability_modifier("CHA"))
	var remaining: int = int(decisions.get("empowered_remaining_dice", cha_mod))
	if remaining <= 0:
		return false
	var sp_spent := bool(decisions.get("empowered_sp_spent", false))
	if not sp_spent:
		if caster.get_sorcery_points() < 1:
			var free_cost := bool(decisions.get("metamagic:arcane_apotheosis", false)) and caster.has_feature("sorcerer_arcane_apotheosis") and caster.has_condition("innate_sorcery") and not bool(caster.feature_uses.get("sorcerer_arcane_apotheosis_used_this_turn", false))
			if not free_cost:
				return false
	return true


static func _apply_empowered_spell(caster: Character, details: Dictionary, decisions: Dictionary) -> Dictionary:
	var context: Dictionary = decisions.get("spell_damage_context", {})
	if context.get("empowered_resolved", false):
		return {"details": context.get("details", details), "used": bool(context.get("empowered_used", false))}
	var indices: Array = decisions.get("metamagic:empowered_dice", [])
	var cha_mod := maxi(1, caster.ability_scores.get_ability_modifier("CHA"))
	var remaining: int = int(decisions.get("empowered_remaining_dice", cha_mod))
	var maximum := mini(remaining, cha_mod)
	var used := false
	if SpellDamageRolls._can_empower(caster, decisions) and Dice.valid_reroll_selection(details, indices, maximum):
		var sp_spent := bool(decisions.get("empowered_sp_spent", false))
		var paid := true
		if not sp_spent:
			paid = SorcererRules.spend_metamagic_cost(caster, 1, decisions)
			if paid:
				decisions["empowered_sp_spent"] = true
		if paid:
			details = Dice.reroll_selected_dice(details, indices, maximum, caster)["details"]
			used = true
			decisions["empowered_remaining_dice"] = remaining - indices.size()
	decisions.erase("metamagic:empowered_dice")
	if decisions.has("spell_damage_context"):
		context["empowered_resolved"] = true
		context["empowered_used"] = used
		context["details"] = details
	return {"details": details, "used": used}


## Delay only the damage settlement while the owner selects already-rolled dice.
## Attack/save rolls and slot charges are never repeated, and HP is not changed
## until the final roll has passed through the ordinary damage boundary.


static var _pending_requests: Dictionary = {}
static var _active_request_id_by_caster: Dictionary = {}
static var _request_counter: int = 0
static var _epoch: int = 0
static var _resolution_occurrence_counter: int = 0


static func _resolution_actor_id(actor: Variant) -> String:
	if actor is Character:
		return str(actor.character_id)
	if actor is Dictionary:
		return str(actor.get("id", ""))
	return ""


static func begin_resolution_occurrence(cast: SpellResolutionContext, kind: String) -> void:
	if cast == null or not cast.resolution_window_context.is_empty():
		return
	_resolution_occurrence_counter += 1
	var base := {
		"occurrence_id": "spell_roll_occurrence:%d" % _resolution_occurrence_counter,
		"kind": kind,
		"actor_id": _resolution_actor_id(cast.caster),
		"target_id": _resolution_actor_id(cast.target),
		"action_id": cast.action_id,
		"action_invocation_id": cast.action_invocation_id,
		"spell_definition_id": cast.spell_definition_id,
		"spell_invocation_id": cast.invocation_id,
		"source_definition_id": cast.source_definition_id,
		"source_owner_id": cast.source_owner_id,
	}
	if not cast.source_instance_id.is_empty():
		base["source_instance_id"] = cast.source_instance_id
	cast.resolution_window_context = {"base": base, "windows": []}
	cast.resolution_window_target = cast.target


static func record_resolution_window(cast: SpellResolutionContext, window: String, fields: Dictionary = {}) -> bool:
	if cast == null or window not in RESOLUTION_WINDOW_ORDER:
		return false
	begin_resolution_occurrence(cast, "spell_attack")
	if cast.resolution_window_context.is_empty():
		return false
	var windows: Array = cast.resolution_window_context.get("windows", [])
	if windows.any(func(receipt): return receipt is Dictionary and str(receipt.get("window", "")) == window):
		return false
	var base: Dictionary = cast.resolution_window_context.get("base", {})
	var receipt: Dictionary = {"window": window, "occurrence_id": str(base.get("occurrence_id", ""))}
	for field in RESOLUTION_COMMON_FIELDS:
		if base.has(field) and not str(base[field]).is_empty():
			receipt[field] = base[field]
	for field in RESOLUTION_WINDOW_FIELDS[window]:
		if fields.has(field):
			receipt[field] = fields[field]
	receipt["available_fields"] = receipt.keys()
	windows.append(receipt)
	cast.resolution_window_context["windows"] = windows
	cast.resolution_window = receipt
	return true


static func publish_resolution_windows(cast: SpellResolutionContext, result: Dictionary) -> void:
	if cast == null or cast.resolution_window_context.is_empty():
		return
	result["resolution_occurrence_id"] = str(cast.resolution_window_context.get("base", {}).get("occurrence_id", ""))
	result["resolution_windows"] = cast.resolution_window_context.get("windows", []).duplicate(true)


static func failed_save_numeric_bonus_options(target: Character, ability: String) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if target == null:
		return options
	for effect in ClassProgression.selected_feature_effects_of_type(target, "failed_save_numeric_bonus"):
		if str(effect.get("ability", "")).to_upper() != ability.to_upper():
			continue
		var source_id := str(effect.get("source_instance_id", ""))
		var pool_id := str(effect.get("resource_pool_definition_id", ""))
		var pool: Variant = target.numeric_resource_pools.get(source_id, {})
		if source_id.is_empty() or pool_id.is_empty() or not pool is Dictionary:
			continue
		if str(pool.get("owner_id", "")) != target.character_id or str(pool.get("source_instance_id", "")) != source_id or str(pool.get("definition_id", "")) != pool_id or int(pool.get("current", 0)) < int(effect.get("cost", 0)):
			continue
		options.append({
			"resolution": "die_bonus" if effect.has("die_size") else "numeric_bonus",
			"bonus_kind": "die" if effect.has("die_size") else "numeric",
			"source_instance_id": source_id,
			"feature_id": str(effect.get("feature_id", "")),
			"pool_definition_id": pool_id,
			"ability": ability.to_upper(),
			"amount": int(effect.get("amount", 0)),
			"die_size": int(effect.get("die_size", 0)),
			"cost": int(effect.get("cost", 0)),
			"payment_policy": str(effect.get("payment_policy", "pay_on_choice")),
			"label": str(effect.get("feature_name", effect.get("feature_id", source_id))),
		})
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("source_instance_id", "")) < str(b.get("source_instance_id", "")))
	return options


static func attack_numeric_bonus_options(owner: Character, domain: String) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if owner == null or domain not in ["weapon_attack", "shared_spell_attack"]:
		return options
	for effect in ClassProgression.selected_feature_effects_of_type(owner, "weapon_attack_numeric_bonus"):
		if domain not in effect.get("domains", []):
			continue
		var source_id := str(effect.get("source_instance_id", ""))
		var pool_id := str(effect.get("resource_pool_definition_id", ""))
		var pool: Variant = owner.numeric_resource_pools.get(source_id, {})
		var cost := int(effect.get("cost", 0))
		if source_id.is_empty() or pool_id.is_empty() or not pool is Dictionary:
			continue
		if str(pool.get("owner_id", "")) != owner.character_id or str(pool.get("source_instance_id", "")) != source_id or str(pool.get("definition_id", "")) != pool_id or int(pool.get("current", 0)) < cost:
			continue
		options.append({
			"source_instance_id": source_id,
			"feature_id": str(effect.get("feature_id", "")),
			"pool_definition_id": pool_id,
			"amount": int(effect.get("amount", 0)),
			"die_size": int(effect.get("die_size", 0)),
			"bonus_kind": "die" if effect.has("die_size") else "numeric",
			"cost": cost,
			"payment_policy": str(effect.get("payment_policy", "pay_on_choice")),
			"domain": domain,
			"label": str(effect.get("feature_name", effect.get("feature_id", source_id))),
		})
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("source_instance_id", "")) < str(b.get("source_instance_id", "")))
	return options


static func weapon_attack_numeric_bonus_options(owner: Character) -> Array[Dictionary]:
	return attack_numeric_bonus_options(owner, "weapon_attack")


## One optional owned modifier for a failed, loaded EventDialog ability check.
## Eligibility comes entirely from the captured check facts and authored effect.
static func ability_check_numeric_bonus_options(owner: Character, check_result: Dictionary) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if owner == null or bool(check_result.get("success", true)) or check_result.has("ability_check_bonus_resolved") or check_result.has("post_roll_bonus_source"):
		return options
	if str(check_result.get("actor_id", "")) != owner.character_id:
		return options
	var context: Dictionary = check_result.get("check_context", {})
	var origin_event_id := str(context.get("origin_event_id", ""))
	var origin_check_id := str(context.get("origin_check_id", ""))
	if origin_event_id.is_empty() or origin_check_id.is_empty():
		return options
	var loaded: Dictionary = DataLoader.get_event_check_record(origin_event_id, origin_check_id)
	var loaded_check: Dictionary = loaded.get("check", {})
	var loaded_context: Dictionary = loaded_check.get("check_context", {})
	if loaded.is_empty() or loaded_context.is_empty() or str(loaded_check.get("skill", "")) != str(context.get("skill", "")) or int(loaded_check.get("dc", -1)) != int(check_result.get("dc", -2)):
		return options
	for field in ["task_id", "purpose_id", "required_tool_id"]:
		if str(loaded_context.get(field, "")) != str(context.get(field, "")):
			return options
	if str(check_result.get("ability", "")).to_upper() != str(context.get("ability", "")).to_upper():
		return options
	for effect in ClassProgression.selected_feature_effects_of_type(owner, "ability_check_numeric_bonus"):
		if str(effect.get("domain", "")) != "event_skill_check":
			continue
		if str(effect.get("ability", "")).to_upper() != str(check_result.get("ability", "")).to_upper():
			continue
		if str(effect.get("skill", "")) != str(context.get("skill", "")):
			continue
		if str(effect.get("task_id", "")) != str(context.get("task_id", "")) or str(effect.get("purpose_id", "")) != str(context.get("purpose_id", "")):
			continue
		if str(effect.get("required_tool_id", "")) != str(context.get("required_tool_id", "")):
			continue
		if str(effect.get("source_event_id", "")) != str(context.get("origin_event_id", "")) or str(effect.get("source_check_id", "")) != str(context.get("origin_check_id", "")):
			continue
		var source_id := str(effect.get("source_instance_id", ""))
		var pool_id := str(effect.get("resource_pool_definition_id", ""))
		var cost := int(effect.get("cost", 0))
		var pool: Variant = owner.numeric_resource_pools.get(source_id, {})
		if source_id.is_empty() or pool_id.is_empty() or not pool is Dictionary:
			continue
		if str(pool.get("owner_id", "")) != owner.character_id or str(pool.get("source_instance_id", "")) != source_id or str(pool.get("definition_id", "")) != pool_id or int(pool.get("current", 0)) < cost:
			continue
		options.append({
			"effect_id": str(effect.get("id", "")),
			"source_instance_id": source_id,
			"feature_id": str(effect.get("feature_id", "")),
			"pool_definition_id": pool_id,
			"domain": "event_skill_check",
			"ability": str(effect.get("ability", "")).to_upper(),
			"skill": str(effect.get("skill", "")),
			"task_id": str(effect.get("task_id", "")),
			"purpose_id": str(effect.get("purpose_id", "")),
			"required_tool_id": str(effect.get("required_tool_id", "")),
			"source_event_id": str(effect.get("source_event_id", "")),
			"source_check_id": str(effect.get("source_check_id", "")),
			"amount": int(effect.get("amount", 0)),
			"die_size": int(effect.get("die_size", 0)),
			"bonus_kind": "die" if effect.has("die_size") else "numeric",
			"cost": cost,
			"payment_policy": str(effect.get("payment_policy", "pay_on_choice")),
			"label": str(effect.get("feature_name", effect.get("feature_id", source_id))),
		})
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("source_instance_id", "")) < str(b.get("source_instance_id", "")))
	return options


## All supported post-roll choices share one captured check and one chance to
## modify it. A source with more than one effect gets distinct offer IDs.
static func ability_check_post_roll_options(owner: Character, check_result: Dictionary) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if owner == null or check_result.has("ability_check_bonus_resolved") or check_result.has("ability_check_reroll_resolved"):
		return options
	for option in ability_check_numeric_bonus_options(owner, check_result):
		var tagged: Dictionary = option.duplicate(true)
		tagged["operation_kind"] = "numeric_bonus"
		tagged["offer_id"] = _ability_check_offer_id(tagged)
		options.append(tagged)
	options.append_array(ability_check_mandatory_reroll_options(owner, check_result))
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("offer_id", "")) < str(b.get("offer_id", "")))
	return options


static func ability_check_mandatory_reroll_options(owner: Character, check_result: Dictionary) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if owner == null or bool(check_result.get("stroke_of_luck_used", false)) or check_result.has("ability_check_reroll_resolved") or check_result.has("ability_check_bonus_resolved"):
		return options
	if str(check_result.get("actor_id", "")) != owner.character_id:
		return options
	var context: Dictionary = check_result.get("check_context", {})
	var origin_event_id := str(context.get("origin_event_id", ""))
	var origin_check_id := str(context.get("origin_check_id", ""))
	if origin_event_id.is_empty() or origin_check_id.is_empty():
		return options
	var loaded: Dictionary = DataLoader.get_event_check_record(origin_event_id, origin_check_id)
	var loaded_check: Dictionary = loaded.get("check", {})
	var loaded_context: Dictionary = loaded_check.get("check_context", {})
	if loaded.is_empty() or loaded_context.is_empty() or str(loaded_check.get("skill", "")) != str(context.get("skill", "")) or int(loaded_check.get("dc", -1)) != int(check_result.get("dc", -2)):
		return options
	for field in ["task_id", "purpose_id", "required_tool_id"]:
		if str(loaded_context.get(field, "")) != str(context.get(field, "")):
			return options
	if str(check_result.get("ability", "")).to_upper() != str(context.get("ability", "")).to_upper():
		return options
	var outcome := "success" if bool(check_result.get("success", false)) else "failure"
	for effect in ClassProgression.selected_feature_effects_of_type(owner, "ability_check_mandatory_reroll"):
		if str(effect.get("domain", "")) != "event_skill_check" or outcome not in effect.get("eligible_outcomes", []):
			continue
		if str(effect.get("ability", "")).to_upper() != str(check_result.get("ability", "")).to_upper() or str(effect.get("skill", "")) != str(context.get("skill", "")):
			continue
		if str(effect.get("task_id", "")) != str(context.get("task_id", "")) or str(effect.get("purpose_id", "")) != str(context.get("purpose_id", "")) or str(effect.get("required_tool_id", "")) != str(context.get("required_tool_id", "")):
			continue
		if str(effect.get("source_event_id", "")) != origin_event_id or str(effect.get("source_check_id", "")) != origin_check_id:
			continue
		if not EventResolver.can_reroll_captured_skill_check(check_result, str(effect.get("reroll_mode", "")), str(effect.get("bonus_dice_policy", ""))):
			continue
		var source_id := str(effect.get("source_instance_id", ""))
		var pool_id := str(effect.get("resource_pool_definition_id", ""))
		var cost := int(effect.get("cost", 0))
		var pool_value: Variant = owner.numeric_resource_pools.get(source_id, {})
		if source_id.is_empty() or pool_id.is_empty() or not pool_value is Dictionary:
			continue
		if str(pool_value.get("owner_id", "")) != owner.character_id or str(pool_value.get("source_instance_id", "")) != source_id or str(pool_value.get("definition_id", "")) != pool_id or int(pool_value.get("current", 0)) < cost:
			continue
		var option := {
			"effect_id": str(effect.get("id", "")), "source_instance_id": source_id,
			"feature_id": str(effect.get("feature_id", "")), "pool_definition_id": pool_id,
			"operation_kind": "mandatory_reroll", "domain": "event_skill_check",
			"ability": str(effect.get("ability", "")).to_upper(), "skill": str(effect.get("skill", "")),
			"task_id": str(effect.get("task_id", "")), "purpose_id": str(effect.get("purpose_id", "")),
			"required_tool_id": str(effect.get("required_tool_id", "")),
			"source_event_id": origin_event_id, "source_check_id": origin_check_id,
			"eligible_outcomes": effect.get("eligible_outcomes", []).duplicate(true),
			"reroll_mode": str(effect.get("reroll_mode", "")),
			"bonus_dice_policy": str(effect.get("bonus_dice_policy", "")),
			"cost": cost, "label": str(effect.get("feature_name", effect.get("feature_id", source_id))),
		}
		option["offer_id"] = _ability_check_offer_id(option)
		options.append(option)
	return options


static func _ability_check_offer_id(option: Dictionary) -> String:
	return "%s|%s|%s" % [str(option.get("operation_kind", "")), str(option.get("source_instance_id", "")), str(option.get("effect_id", ""))]


static func create_ability_check_post_roll_request(owner: Character, check_result: Dictionary, host: Node) -> Dictionary:
	if owner == null or host == null or not is_instance_valid(host):
		return {"success": false}
	var available := ability_check_post_roll_options(owner, check_result)
	if available.is_empty():
		return {"success": false, "message": "No matching owned ability-check source is available."}
	var owner_id := str(owner.get_instance_id())
	if not str(_active_request_id_by_caster.get(owner_id, "")).is_empty():
		return {"success": false, "message": "Another choice is already pending for this actor."}
	_request_counter += 1
	var request_id := "ability_check_post_roll_req_%d_%s_%d" % [_epoch, owner_id, _request_counter]
	_pending_requests[request_id] = {
		"request_id": request_id, "kind": "ability_check_post_roll", "caster": owner, "target": owner,
		"check_result": check_result.duplicate(true), "context": check_result.get("check_context", {}).duplicate(true),
		"options": available.duplicate(true), "host_node": host, "settled": false, "serial": _request_counter,
	}
	_active_request_id_by_caster[owner_id] = request_id
	return {"success": true, "ability_check_post_roll_request": {"request_id": request_id}, "options": available.duplicate(true)}


static func settle_ability_check_post_roll(owner: Character, request: Dictionary, selected_offer_id: String) -> Dictionary:
	var validation := _validate_request(owner, owner, request, "ability_check_post_roll")
	if not bool(validation.get("valid", false)):
		return {"success": false, "refused": true, "message": str(validation.get("error", "Invalid ability-check choice."))}
	var record: Dictionary = validation["record"]
	var captured: Dictionary = record.get("check_result", {}).duplicate(true)
	var selected: Dictionary = {}
	if not selected_offer_id.is_empty():
		for option in record.get("options", []):
			if str(option.get("offer_id", "")) == selected_offer_id:
				selected = option
				break
		if selected.is_empty():
			return {"success": false, "refused": true, "message": "The selected ability-check operation was not offered."}
		var current: Dictionary = {}
		for option in ability_check_post_roll_options(owner, captured):
			if str(option.get("offer_id", "")) == selected_offer_id:
				current = option
				break
		for field in ["effect_id", "source_instance_id", "feature_id", "pool_definition_id", "operation_kind", "domain", "ability", "skill", "task_id", "purpose_id", "required_tool_id", "source_event_id", "source_check_id", "cost", "payment_policy", "amount", "die_size", "bonus_kind", "eligible_outcomes", "reroll_mode", "bonus_dice_policy"]:
			if current.is_empty() or current.get(field) != selected.get(field):
				selected.clear()
				break
	var result := captured.duplicate(true)
	result["ability_check_bonus_resolved"] = true
	result["ability_check_reroll_resolved"] = true
	if selected.is_empty():
		_consume_request(record)
		return {"success": true, "check_result": result, "selected_source_id": "", "source_changed": not selected_offer_id.is_empty()}
	if str(selected.get("operation_kind", "")) == "mandatory_reroll" and not EventResolver.can_reroll_captured_skill_check(captured, str(selected.get("reroll_mode", "")), str(selected.get("bonus_dice_policy", ""))):
		_consume_request(record)
		return {"success": true, "check_result": result, "selected_source_id": "", "source_changed": true}
	var pool: Dictionary = owner.numeric_resource_pools.get(str(selected.get("source_instance_id", "")), {})
	if str(pool.get("owner_id", "")) != owner.character_id or str(pool.get("definition_id", "")) != str(selected.get("pool_definition_id", "")) or int(pool.get("current", 0)) < int(selected.get("cost", 0)):
		selected.clear()
		_consume_request(record)
		result["source_changed"] = true
		return {"success": true, "check_result": result, "selected_source_id": "", "source_changed": true}
	var should_pay := true
	if str(selected.get("operation_kind", "")) == "numeric_bonus":
		var rolled_option := _roll_accepted_bonus_die(owner, selected)
		if rolled_option.is_empty():
			return {"success": false, "refused": true, "message": "The selected ability-check bonus die is unsupported."}
		var bonus := int(rolled_option.get("bonus_amount", rolled_option.get("amount", 0)))
		result["total"] = int(result.get("total", 0)) + bonus
		result["success"] = int(result["total"]) >= int(result.get("dc", 0))
		result["post_roll_bonus"] = bonus
		result["post_roll_bonus_source"] = str(selected.get("source_instance_id", ""))
		result["post_roll_bonus_policy"] = str(selected.get("payment_policy", "pay_on_choice"))
		if selected.get("bonus_kind", "numeric") == "die":
			result["post_roll_bonus_die"] = rolled_option.get("bonus_roll", {}).duplicate(true)
			result["post_roll_bonus_die_source"] = str(selected.get("source_instance_id", ""))
		should_pay = str(selected.get("payment_policy", "pay_on_choice")) == "pay_on_choice" or bool(result.get("success", false))
		result["post_roll_bonus_cost_paid"] = should_pay
	else:
		var reroll_payment := ResourcePoolRules.spend(owner, str(selected.get("source_instance_id", "")), int(selected.get("cost", 0)))
		if not bool(reroll_payment.get("success", false)):
			_consume_request(record)
			return {"success": true, "check_result": result, "selected_source_id": "", "source_changed": true}
		should_pay = false
		var original_receipt := {
			"raw_natural_roll": captured.get("raw_natural_roll", captured.get("natural_roll", 0)),
			"natural_roll": captured.get("natural_roll", 0),
			"total": captured.get("total", 0),
			"success": captured.get("success", false),
			"modifier": captured.get("modifier", 0),
			"base_modifier": captured.get("base_modifier", captured.get("modifier", 0)),
			"dc": captured.get("dc", 0),
			"ability": captured.get("ability", ""),
			"check_context": captured.get("check_context", {}).duplicate(true),
			"roll_mode": captured.get("roll_mode", "normal"),
			"roll_details": captured.get("roll_details", {}).duplicate(true),
			"roll_floor_minimum": captured.get("roll_floor_minimum", 1),
			"total_floor_minimum": captured.get("total_floor_minimum", 0),
			"total_floor_active": captured.get("total_floor_active", false),
			"bonus_dice": captured.get("check_bonus_dice", []).duplicate(true),
		}
		var rerolled := EventResolver.reroll_captured_skill_check(owner, captured, str(selected.get("reroll_mode", "")), str(selected.get("bonus_dice_policy", "")))
		if rerolled.is_empty():
			return {"success": false, "refused": true, "message": "The captured ability-check dice cannot be rerolled under this source."}
		result = rerolled
		result["ability_check_bonus_resolved"] = true
		result["ability_check_reroll_resolved"] = true
		result["post_roll_reroll_source"] = str(selected.get("source_instance_id", ""))
		result["post_roll_reroll_cost_paid"] = true
		result["post_roll_reroll"] = {"source_instance_id": str(selected.get("source_instance_id", "")), "effect_id": str(selected.get("effect_id", "")), "reroll_mode": str(selected.get("reroll_mode", "")), "bonus_dice_policy": str(selected.get("bonus_dice_policy", "")), "original": original_receipt, "new_roll": result.get("roll_details", {}).duplicate(true), "bonus_dice": result.get("check_bonus_dice", []).duplicate(true)}
	if should_pay:
		var payment := ResourcePoolRules.spend(owner, str(selected.get("source_instance_id", "")), int(selected.get("cost", 0)))
		if not bool(payment.get("success", false)):
			# No reroll is ever generated before this spend succeeds. Numeric bonus
			# paths also have not mutated durable state before payment.
			return {"success": false, "refused": true, "message": str(payment.get("message", "The selected source can no longer pay."))}
	_consume_request(record)
	return {"success": true, "check_result": result, "selected_source_id": str(selected.get("source_instance_id", "")), "operation_kind": str(selected.get("operation_kind", ""))}


static func create_ability_check_numeric_bonus_request(owner: Character, check_result: Dictionary, options: Array[Dictionary], host: Node) -> Dictionary:
	if owner == null or host == null or not is_instance_valid(host) or options.is_empty():
		return {"success": false}
	var available := ability_check_numeric_bonus_options(owner, check_result)
	if available.is_empty():
		return {"success": false, "message": "No matching owned ability-check source is available."}
	var owner_id := str(owner.get_instance_id())
	if not str(_active_request_id_by_caster.get(owner_id, "")).is_empty():
		return {"success": false, "message": "Another choice is already pending for this actor."}
	_request_counter += 1
	var request_id := "ability_check_bonus_req_%d_%s_%d" % [_epoch, owner_id, _request_counter]
	var context: Dictionary = check_result.get("check_context", {}).duplicate(true)
	_pending_requests[request_id] = {
		"request_id": request_id, "kind": "ability_check_bonus", "caster": owner, "target": owner,
		"check_result": check_result.duplicate(true), "context": context,
		"options": available.duplicate(true), "host_node": host, "settled": false, "serial": _request_counter,
	}
	_active_request_id_by_caster[owner_id] = request_id
	return {"success": true, "ability_check_bonus_request": {"request_id": request_id}, "options": available.duplicate(true)}


static func settle_ability_check_numeric_bonus(owner: Character, result: Dictionary, selected_source_id: String) -> Dictionary:
	var validation := _validate_request(owner, owner, result, "ability_check_bonus")
	if not bool(validation.get("valid", false)):
		return {"success": false, "refused": true, "message": str(validation.get("error", "Invalid ability-check bonus request."))}
	var record: Dictionary = validation["record"]
	var captured: Dictionary = record.get("check_result", {}).duplicate(true)
	var selected: Dictionary = {}
	if not selected_source_id.is_empty():
		for option in record.get("options", []):
			if str(option.get("source_instance_id", "")) == selected_source_id:
				selected = option
				break
		if selected.is_empty():
			return {"success": false, "refused": true, "message": "The selected ability-check source was not offered."}
		var current: Dictionary = {}
		for option in ability_check_numeric_bonus_options(owner, captured):
			if str(option.get("source_instance_id", "")) == selected_source_id:
				current = option
				break
		for field in ["effect_id", "feature_id", "pool_definition_id", "domain", "ability", "skill", "task_id", "purpose_id", "required_tool_id", "source_event_id", "source_check_id", "amount", "die_size", "bonus_kind", "cost", "payment_policy"]:
			if current.is_empty() or current.get(field) != selected.get(field):
				# A stale offered row resolves as decline so its captured roll and
				# ordinary outcome can continue instead of stranding the check.
				selected.clear()
				break
	if not selected.is_empty():
		var pool: Dictionary = owner.numeric_resource_pools.get(selected_source_id, {})
		if int(pool.get("current", 0)) < int(selected.get("cost", 0)):
			selected.clear()
	if not selected.is_empty():
		selected = _roll_accepted_bonus_die(owner, selected)
		if selected.is_empty():
			return {"success": false, "refused": true, "message": "The selected ability-check bonus die is unsupported."}
	var bonus := int(selected.get("bonus_amount", selected.get("amount", 0))) if not selected.is_empty() else 0
	var settled := captured.duplicate(true)
	settled["ability_check_bonus_resolved"] = true
	var should_pay := false
	if not selected.is_empty() and bonus > 0:
		settled["total"] = int(settled.get("total", 0)) + bonus
		settled["success"] = int(settled["total"]) >= int(settled.get("dc", 0))
		settled["post_roll_bonus"] = bonus
		settled["post_roll_bonus_source"] = selected_source_id
		settled["post_roll_bonus_policy"] = str(selected.get("payment_policy", "pay_on_choice"))
		if selected.get("bonus_kind", "numeric") == "die":
			settled["post_roll_bonus_die"] = selected.get("bonus_roll", {}).duplicate(true)
			settled["post_roll_bonus_die_source"] = selected_source_id
		should_pay = not selected.is_empty() and (str(selected.get("payment_policy", "pay_on_choice")) == "pay_on_choice" or bool(settled.get("success", false)))
	if should_pay:
		var payment := ResourcePoolRules.spend(owner, selected_source_id, int(selected.get("cost", 0)))
		if not bool(payment.get("success", false)):
			return {"success": false, "refused": true, "message": str(payment.get("message", "The selected source can no longer pay."))}
	settled["post_roll_bonus_cost_paid"] = should_pay
	_consume_request(record)
	return {"success": true, "check_result": settled, "selected_source_id": selected_source_id if not selected.is_empty() else "", "source_changed": not selected_source_id.is_empty() and selected.is_empty()}


static func cancel_ability_check_requests_for_host(host: Node) -> void:
	for record in _pending_requests.values():
		if str(record.get("kind", "")) not in ["ability_check_bonus", "ability_check_post_roll"] or record.get("host_node") != host or bool(record.get("settled", false)):
			continue
		_consume_request(record)


static func _roll_accepted_bonus_die(owner: Character, option: Dictionary) -> Dictionary:
	var captured := option.duplicate(true)
	if str(captured.get("bonus_kind", "numeric")) != "die":
		return captured
	var die_size := int(captured.get("die_size", 0))
	if die_size not in ResourcePoolRules.SUPPORTED_DIE_SIZES:
		return {}
	var details := Dice.roll_single_details(die_size, owner)
	captured["bonus_roll"] = details.duplicate(true)
	captured["bonus_amount"] = int(details.get("total", 0))
	return captured


static func has_attack_bonus_choice_host(decisions: Dictionary) -> bool:
	var host = decisions.get("cast_context")
	return host is SpellCastContext and host.hud != null and host.hud.has_method("request_weapon_attack_numeric_bonus") and host.owner_label_for_character.is_valid()


static func create_weapon_attack_bonus_request(owner: Character, target, context: Dictionary, options: Array[Dictionary], decisions: Dictionary, domain: String = "weapon_attack") -> Dictionary:
	if owner == null or target == null or options.is_empty():
		return {"success": false}
	var owner_id := str(owner.get_instance_id())
	if not str(_active_request_id_by_caster.get(owner_id, "")).is_empty():
		return {"success": false, "message": "Another choice is already pending for this attacker."}
	_request_counter += 1
	var request_id := "weapon_bonus_req_%d_%s_%d" % [_epoch, owner_id, _request_counter]
	var host_players = decisions.get("players", null)
	var host_monsters = decisions.get("monsters", null)
	var captured_context := context.duplicate(true)
	captured_context["attacker"] = owner
	captured_context["target"] = target
	captured_context["reaction_decisions"] = context.get("reaction_decisions", {}).duplicate(false)
	captured_context["attack_domain"] = domain
	_pending_requests[request_id] = {
		"request_id": request_id, "kind": "weapon_attack_bonus", "caster": owner,
		"target": target, "context": captured_context, "options": options.duplicate(true),
		"decisions": decisions, "host_players": host_players, "host_monsters": host_monsters,
		"caster_hosted": _host_contains(host_players, host_monsters, owner),
		"target_hosted": _host_contains(host_players, host_monsters, target),
		"settled": false, "serial": _request_counter, "attack_domain": domain,
	}
	_active_request_id_by_caster[owner_id] = request_id
	var noun := "weapon attack" if domain == "weapon_attack" else "spell attack"
	var outcome_word := "hit" if bool(context.get("provisional_hit", false)) else "miss"
	return {"success": true, "weapon_attack_bonus_request": {"request_id": request_id}, "options": options.duplicate(true), "attack_roll": int(context.get("attack_result", {}).get("total", 0)), "target_ac": int(context.get("original_target_ac", 0)), "provisional_hit": bool(context.get("provisional_hit", false)), "message": "The %s provisionally %s; choose one owned option or decline." % [noun, outcome_word]}


static func weapon_attack_bonus_record(owner: Character, target, result: Dictionary) -> Dictionary:
	var validation := _validate_request(owner, target, result, "weapon_attack_bonus")
	return validation.get("record", {}) if bool(validation.get("valid", false)) else {}


static func settle_weapon_attack_bonus(owner: Character, target, result: Dictionary, selected_source_id: String) -> Dictionary:
	var validation := _validate_request(owner, target, result, "weapon_attack_bonus")
	if not bool(validation.get("valid", false)):
		return {"success": false, "refused": true, "message": str(validation.get("error", "Invalid weapon attack bonus request."))}
	var record: Dictionary = validation["record"]
	var selected: Dictionary = {}
	if not selected_source_id.is_empty():
		for option in record.get("options", []):
			if str(option.get("source_instance_id", "")) == selected_source_id:
				selected = option
				break
		if selected.is_empty():
			return {"success": false, "refused": true, "message": "The selected weapon bonus source was not offered."}
		var current: Dictionary = {}
		var domain := str(record.get("attack_domain", "weapon_attack"))
		var captured_attack: Dictionary = record.get("context", {}).get("attack_result", {})
		var natural := int(captured_attack.get("natural", 0))
		var provisional_hit := bool(record.get("context", {}).get("provisional_hit", false))
		var can_offer_numeric := not provisional_hit and natural != 1 and not bool(captured_attack.get("is_crit", false)) and not bool(captured_attack.get("is_miss", false))
		var can_offer_adjustment := provisional_hit and not bool(captured_attack.get("is_crit", false)) and not bool(captured_attack.get("is_miss", false))
		for option in attack_choice_options(owner, domain, provisional_hit, can_offer_numeric, can_offer_adjustment):
			if str(option.get("source_instance_id", "")) == selected_source_id:
				current = option
				break
		for field in ["resolution", "feature_id", "pool_definition_id", "source_owner_id", "amount", "die_size", "bonus_kind", "cost", "payment_policy", "domain", "stage", "outcome", "ability", "trigger"]:
			if current.is_empty() or current.get(field) != selected.get(field):
				return {"success": false, "refused": true, "message": "The selected weapon bonus source changed or is no longer available."}
		if str(selected.get("resolution", "numeric_bonus")) not in ["outcome_override", "attack_total_adjustment", "defending_ac_adjustment"]:
			selected = _roll_accepted_bonus_die(owner, selected)
			if selected.is_empty():
				return {"success": false, "refused": true, "message": "The selected weapon bonus die is no longer supported."}
	_consume_request(record)
	if str(record.get("attack_domain", "weapon_attack")) == "shared_spell_attack":
		var resumed := SpellAttackResolver.resume_numeric_bonus(record, selected)
		var ordered_cont = record.get("ordered_continuation")
		if ordered_cont is Dictionary:
			var ordered_cast: SpellResolutionContext = ordered_cont.get("cast")
			SharedStepExecutor._bind_resolution_window(ordered_cast, record.get("target"), resumed)
			if resumed.has("damage_request") or resumed.has("concentration_request"):
				var next_key := "damage_request" if resumed.has("damage_request") else "concentration_request"
				var next_id := str(resumed.get(next_key, {}).get("request_id", ""))
				attach_continuation(next_id, ordered_cont, ordered_cont.get("cast", record.get("context", {}).get("spell_cast")))
				return resumed
			return SharedStepExecutor.resume_spell_steps(ordered_cast.caster, record.get("target"), resumed, ordered_cast.decisions, ordered_cont)
		return resumed
	return CombatAction.resume_weapon_attack_bonus(record, selected)


static func settle_weapon_attack_bonus_with_stroke(owner: Character, target, result: Dictionary, accepted: bool) -> Dictionary:
	var validation := _validate_request(owner, target, result, "weapon_attack_bonus")
	if not bool(validation.get("valid", false)):
		return {"success": false, "refused": true, "message": str(validation.get("error", "Invalid weapon attack request."))}
	var record: Dictionary = validation["record"]
	var request_context: Dictionary = record.get("context", {})
	if str(request_context.get("attack_domain", "weapon_attack")) != "weapon_attack":
		return {"success": false, "refused": true, "message": "Stroke of Luck settlement only accepts a weapon attack request."}
	if not accepted:
		return {"success": false, "refused": true, "message": "The captured Stroke of Luck choice was not accepted."}
	var captured_attack: Dictionary = record.get("context", {}).get("attack_result", {})
	var stroke_result := RogueRules.apply_stroke_of_luck_to_attack(record.get("caster"), captured_attack, true)
	if not bool(stroke_result.get("used", false)):
		return {"success": false, "refused": true, "message": "Stroke of Luck is no longer available for this captured attack."}
	_consume_request(record)
	return CombatAction.resume_weapon_attack_bonus(record, {}, stroke_result)


static func roll_outcome_override_options(owner: Character, domain: String, current_outcome: String, ability: String = "") -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if owner == null or domain not in ["weapon_attack", "shared_spell_attack", "shared_spell_save"]:
		return options
	var source_effects := ClassProgression.selected_feature_effects_of_type(owner, "roll_outcome_override")
	if domain == "shared_spell_save":
		source_effects.append_array(ClassProgression.selected_feature_effects_of_type(owner, "failed_save_outcome_override"))
	for effect in source_effects:
		if str(effect.get("type", "")) == "roll_outcome_override":
			if domain not in effect.get("domains", []):
				continue
			var expected_stage := "after_roll_before_consequences" if domain == "shared_spell_save" else "provisional_outcome"
			if str(effect.get("stage", "")) != expected_stage:
				continue
		else:
			if domain != "shared_spell_save" or str(effect.get("ability", "")).to_upper() != ability.to_upper():
				continue
			if current_outcome != "failure":
				continue
		if domain == "shared_spell_save" and str(effect.get("ability", ability)).to_upper() != ability.to_upper():
			continue
		var possible_outcomes: Array = ["success"] if str(effect.get("type", "")) == "failed_save_outcome_override" else effect.get("outcomes", [])
		var desired_outcomes := ["success", "failure"] if domain == "shared_spell_save" else ["hit", "miss"]
		for outcome in possible_outcomes:
			if outcome not in desired_outcomes or str(outcome) == current_outcome:
				continue
			var source_id := str(effect.get("source_instance_id", ""))
			var pool_id := str(effect.get("resource_pool_definition_id", ""))
			var cost := int(effect.get("cost", 0))
			var pool: Variant = owner.numeric_resource_pools.get(source_id, {})
			if source_id.is_empty() or pool_id.is_empty() or not pool is Dictionary:
				continue
			if str(pool.get("owner_id", "")) != owner.character_id or str(pool.get("source_instance_id", "")) != source_id or str(pool.get("definition_id", "")) != pool_id or int(pool.get("current", 0)) < cost:
				continue
			options.append({
				"resolution": "outcome_override", "source_instance_id": source_id,
				"feature_id": str(effect.get("feature_id", "")), "pool_definition_id": pool_id,
				"source_owner_id": owner.character_id,
				"domain": domain, "stage": str(effect.get("stage", "after_roll_before_consequences" if domain == "shared_spell_save" else "provisional_outcome")),
				"outcome": str(outcome), "ability": ability.to_upper() if domain == "shared_spell_save" else "",
				"cost": cost, "label": str(effect.get("feature_name", effect.get("feature_id", source_id))),
			})
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("source_instance_id", "")) < str(b.get("source_instance_id", "")))
	return options


static func failed_save_choice_options(target: Character, ability: String, provisional_saved: bool = false) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if not provisional_saved:
		options = failed_save_numeric_bonus_options(target, ability)
	options.append_array(roll_outcome_override_options(target, "shared_spell_save", "success" if provisional_saved else "failure", ability))
	return options


static func attack_choice_options(owner: Character, domain: String, provisional_hit: bool, allow_numeric_bonus: bool = true, allow_hit_adjustments: bool = false) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if allow_numeric_bonus:
		options = attack_numeric_bonus_options(owner, domain)
	if provisional_hit and allow_hit_adjustments:
		options.append_array(attack_result_adjustment_options(owner, domain))
	options.append_array(roll_outcome_override_options(owner, domain, "hit" if provisional_hit else "miss"))
	return options


static func apply_attack_result_adjustment(attack_result: Dictionary, target_ac: int, selected: Dictionary) -> Dictionary:
	var adjusted_result := attack_result.duplicate(true)
	var adjusted_ac := target_ac
	var operation := str(selected.get("resolution", ""))
	if operation == "attack_total_adjustment":
		var amount := int(selected.get("amount", 0))
		adjusted_result["total"] = int(adjusted_result.get("total", 0)) - amount
		var modifiers: Array = adjusted_result.get("activity_modifiers", []).duplicate(true)
		modifiers.append({"label": str(selected.get("label", "Attack Total Adjustment")), "value": -amount})
		adjusted_result["activity_modifiers"] = modifiers
	elif operation == "defending_ac_adjustment":
		adjusted_ac += int(selected.get("amount", 0))
	return {"attack_result": adjusted_result, "target_ac": adjusted_ac}


static func attack_adjustment_receipt(selected: Dictionary, original_attack: Dictionary, original_ac: int, final_attack: Dictionary, final_ac: int, hit: bool, critical: bool, cost_paid: bool, profile: Dictionary) -> Dictionary:
	if str(selected.get("resolution", "")) not in ["attack_total_adjustment", "defending_ac_adjustment"]:
		return {}
	return {
		"kind": str(selected.get("resolution", "")),
		"amount": int(selected.get("amount", 0)),
		"trigger": "provisional_hit",
		"scope": "this_attack_occurrence",
		"source_instance_id": str(selected.get("source_instance_id", "")),
		"feature_id": str(selected.get("feature_id", "")),
		"pool_definition_id": str(selected.get("pool_definition_id", "")),
		"owner_id": str(selected.get("source_owner_id", "")),
		"domain": str(selected.get("domain", "")),
		"stage": "provisional_outcome",
		"payment_policy": str(selected.get("payment_policy", "pay_on_choice")),
		"cost": int(selected.get("cost", 0)),
		"cost_paid": cost_paid,
		"original": {
			"natural": int(original_attack.get("natural", 0)),
			"modifier": int(original_attack.get("modifier", 0)),
			"total": int(original_attack.get("total", 0)),
			"profile": profile.duplicate(true),
			"target_ac": original_ac,
		},
		"final": {
			"natural": int(final_attack.get("natural", 0)),
			"modifier": int(final_attack.get("modifier", 0)),
			"total": int(final_attack.get("total", 0)),
			"target_ac": final_ac,
			"hit": hit,
			"critical": critical,
		},
	}


## S-095 is deliberately narrower than cross-actor intervention: the attacking
## Character owns and pays every adjustment, including a per-occurrence change
## to the defending AC used for this attack only.
static func attack_result_adjustment_options(owner: Character, domain: String) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if owner == null or domain not in ["weapon_attack", "shared_spell_attack"]:
		return options
	for operation in ["attack_total_adjustment", "defending_ac_adjustment"]:
		for effect in ClassProgression.selected_feature_effects_of_type(owner, operation):
			if domain not in effect.get("domains", []) or str(effect.get("trigger", "")) != "provisional_hit":
				continue
			var source_id := str(effect.get("source_instance_id", ""))
			var pool_id := str(effect.get("resource_pool_definition_id", ""))
			var cost := int(effect.get("cost", 0))
			var pool: Variant = owner.numeric_resource_pools.get(source_id, {})
			if source_id.is_empty() or pool_id.is_empty() or not pool is Dictionary:
				continue
			if str(pool.get("owner_id", "")) != owner.character_id or str(pool.get("source_instance_id", "")) != source_id or str(pool.get("definition_id", "")) != pool_id or int(pool.get("current", 0)) < cost:
				continue
			options.append({
				"resolution": str(effect.get("type", "")),
				"source_instance_id": source_id,
				"source_owner_id": owner.character_id,
				"feature_id": str(effect.get("feature_id", "")),
				"pool_definition_id": pool_id,
				"amount": int(effect.get("amount", 0)),
				"cost": cost,
				"payment_policy": str(effect.get("payment_policy", "pay_on_choice")),
				"trigger": "provisional_hit",
				"domain": domain,
				"stage": "provisional_outcome",
				"label": str(effect.get("feature_name", effect.get("feature_id", source_id))),
			})
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("source_instance_id", "")) < str(b.get("source_instance_id", "")))
	return options


static func has_failed_save_choice_host(decisions: Dictionary) -> bool:
	var host = decisions.get("cast_context")
	return host is SpellCastContext and host.hud != null and host.hud.has_method("request_failed_save_numeric_bonus") and host.owner_label_for_character.is_valid()


static func create_failed_save_numeric_bonus_request(cast: SpellResolutionContext, target: Character, ability: String, save_test: Dictionary, result_key: String, options: Array[Dictionary], provisional_saved: bool = false) -> Dictionary:
	_request_counter += 1
	var caster_id := str(cast.caster.get_instance_id()) if cast.caster != null else "0"
	var request_id := "save_bonus_req_%d_%s_%d" % [_epoch, caster_id, _request_counter]
	var decisions := cast.decisions
	var host_players = decisions.get("players", null)
	var host_monsters = decisions.get("monsters", null)
	_pending_requests[request_id] = {
		"request_id": request_id, "kind": "save_bonus", "caster": cast.caster,
		"target": target, "cast": cast, "ability": ability.to_upper(),
		"save_test": save_test.duplicate(true), "result_key": result_key, "provisional_saved": provisional_saved,
		"options": options.duplicate(true), "decisions": decisions,
		"host_players": host_players, "host_monsters": host_monsters,
		"caster_hosted": _host_contains(host_players, host_monsters, cast.caster),
		"target_hosted": _host_contains(host_players, host_monsters, target),
		"settled": false, "serial": _request_counter,
	}
	_active_request_id_by_caster[caster_id] = request_id
	return {"success": true, "save_bonus_request": {"request_id": request_id}, "save_test": save_test.duplicate(true), "save_dc": int(save_test.get("dc", 0)), "save_total": int(save_test.get("total", 0)), "saved": provisional_saved, "message": "%s %s %s save and may choose an owned option." % [target.character_name, "succeeded on" if provisional_saved else "failed", ability.to_upper()]}


static func settle_failed_save_numeric_bonus(caster: Character, target: Character, result: Dictionary, selected_source_id: String) -> Dictionary:
	var validation := _validate_request(caster, target, result, "save_bonus")
	if not bool(validation.get("valid", false)):
		return {"success": false, "refused": true, "message": str(validation.get("error", "Invalid save bonus request."))}
	var record: Dictionary = validation["record"]
	var selected: Dictionary = {}
	if not selected_source_id.is_empty():
		for option in record.get("options", []):
			if str(option.get("source_instance_id", "")) == selected_source_id:
				selected = option
				break
		if selected.is_empty():
			return {"success": false, "refused": true, "message": "The selected save-bonus source was not offered."}
		var current_options := failed_save_choice_options(target, str(record.get("ability", "")), bool(record.get("provisional_saved", false)))
		var current: Dictionary = {}
		for option in current_options:
			if str(option.get("source_instance_id", "")) == selected_source_id:
				current = option
				break
		for field in ["resolution", "bonus_kind", "feature_id", "pool_definition_id", "source_owner_id", "ability", "amount", "die_size", "cost", "payment_policy", "domain", "stage", "outcome"]:
			if current.is_empty() or current.get(field) != selected.get(field):
				return {"success": false, "refused": true, "message": "The selected save-bonus source changed or is no longer available."}
		if str(selected.get("resolution", "numeric_bonus")) != "outcome_override":
			selected = _roll_accepted_bonus_die(target, selected)
			if selected.is_empty():
				return {"success": false, "refused": true, "message": "The selected save bonus die is no longer supported."}
	var test: Dictionary = record["save_test"].duplicate(true)
	var resolution_kind := str(selected.get("resolution", "numeric_bonus")) if not selected.is_empty() else ""
	var bonus := int(selected.get("bonus_amount", selected.get("amount", 0))) if resolution_kind in ["numeric_bonus", "die_bonus"] else 0
	if resolution_kind == "outcome_override":
		test["outcome_override"] = str(selected.get("outcome", "success"))
		test["outcome_override_source"] = selected_source_id
		test["outcome_override_feature_id"] = str(selected.get("feature_id", ""))
		test["outcome_override_pool_definition_id"] = str(selected.get("pool_definition_id", ""))
		test["outcome_override_owner_id"] = target.character_id
		test["outcome_override_domain"] = str(selected.get("domain", "shared_spell_save"))
		test["outcome_override_stage"] = str(selected.get("stage", "after_roll_before_consequences"))
	elif bonus > 0:
		test["total"] = int(test.get("total", 0)) + bonus
		test["success"] = int(test["total"]) >= int(test.get("dc", 0))
		test["post_roll_bonus"] = bonus
		test["post_roll_bonus_source"] = selected_source_id
		if resolution_kind == "die_bonus":
			test["post_roll_bonus_die"] = selected.get("bonus_roll", {}).duplicate(true)
			test["post_roll_bonus_die_source"] = selected_source_id
	var payment_policy := str(selected.get("payment_policy", "pay_on_choice")) if not selected.is_empty() else "pay_on_choice"
	if payment_policy not in FAILED_SAVE_BONUS_PAYMENT_POLICIES:
		return {"success": false, "refused": true, "message": "The selected save-bonus payment policy is unsupported."}
	var should_pay := not selected.is_empty() and (resolution_kind == "outcome_override" or payment_policy == "pay_on_choice" or bool(test.get("success", false)))
	if should_pay:
		var payment := ResourcePoolRules.spend(target, selected_source_id, int(selected.get("cost", 0)))
		if not bool(payment.get("success", false)):
			return {"success": false, "refused": true, "message": str(payment.get("message", "The source cannot pay for this bonus."))}
	if resolution_kind in ["numeric_bonus", "die_bonus"]:
		test["save_payment_policy"] = payment_policy
		test["save_cost_paid"] = should_pay
	elif resolution_kind == "outcome_override":
		test["save_cost_paid"] = should_pay
	var cast: SpellResolutionContext = record["cast"]
	var cache: Dictionary = cast.decisions.get("failed_save_numeric_bonus_tests", {})
	cache[str(record["result_key"])] = test
	cast.decisions["failed_save_numeric_bonus_tests"] = cache
	_consume_request(record)
	var resumed := SpellSaveResolver.resolve(cast)
	var ordered_cont = record.get("ordered_continuation")
	if ordered_cont is Dictionary:
		# The resumed save can itself suspend for Empowered Spell damage. Keep
		# the ordered save continuation on that damage request until its dice are
		# settled; advancing here would record provisional damage and run riders.
		if resumed.has("damage_request"):
			var damage_request_id := str(resumed.get("damage_request", {}).get("request_id", ""))
			var canonical_cast = ordered_cont.get("cast", cast)
			attach_continuation(damage_request_id, ordered_cont, canonical_cast)
			return resumed
		return SharedStepExecutor.resume_spell_steps(cast.caster, target, resumed, cast.decisions, ordered_cont)
	return resumed


static func failed_save_numeric_bonus_record(caster: Character, target: Character, result: Dictionary) -> Dictionary:
	var validation := _validate_request(caster, target, result, "save_bonus")
	return validation.get("record", {}) if bool(validation.get("valid", false)) else {}


## Encounter/session replacement invalidates every outstanding callback. The
## counter is never reset, so a cleared ID can not alias a later request for the
## same caster/actor.
static func clear_pending_requests() -> void:
	_pending_requests.clear()
	_active_request_id_by_caster.clear()
	_epoch += 1


## Registers the one authoritative owner record for a rolled, not-yet-applied
## damage packet. Only the request ID is ever read back from a caller payload.
static func create_damage_request(caster: Character, target, details: Dictionary, bonus: int, scale: float, damage_type: String, condition_duration: int = 1, additional_damage_packets: Array[Dictionary] = [], decisions: Dictionary = {}, base_result: Dictionary = {}) -> String:
	_request_counter += 1
	var caster_id := str(caster.get_instance_id()) if caster != null else "0"
	var request_id := "dmg_req_%d_%s_%d" % [_epoch, caster_id, _request_counter]
	var host_players = decisions.get("players", null)
	var host_monsters = decisions.get("monsters", null)
	var record := {
		"request_id": request_id,
		"kind": "damage",
		"caster": caster,
		"target": target,
		"details": details,
		"bonus": bonus,
		"scale": scale,
		"damage_type": damage_type,
		"condition_duration": condition_duration,
		"additional_damage_packets": additional_damage_packets,
		"decisions": decisions.duplicate(),
		"result_base": base_result.duplicate(false),
		"host_players": host_players,
		"host_monsters": host_monsters,
		"target_hosted": _host_contains(host_players, host_monsters, target),
		"caster_hosted": _host_contains(host_players, host_monsters, caster),
		"settled": false,
		"serial": _request_counter
	}
	_pending_requests[request_id] = record
	_active_request_id_by_caster[caster_id] = request_id
	return request_id


## Registers the one authoritative owner record for an outstanding concentration
## save reaction choice.
static func create_concentration_request(caster: Character, target: Character, dc: int, roll: int, feature: String, decisions: Dictionary = {}, base_result: Dictionary = {}, save_test: Dictionary = {}) -> String:
	_request_counter += 1
	var caster_id := str(caster.get_instance_id()) if caster != null else "0"
	var request_id := "conc_req_%d_%s_%d" % [_epoch, caster_id, _request_counter]
	var host_players = decisions.get("players", null)
	var host_monsters = decisions.get("monsters", null)
	var effective_save_test: Dictionary
	if not save_test.is_empty():
		effective_save_test = save_test.duplicate(true)
	else:
		effective_save_test = {
			"natural_roll": roll,
			"modifier": 0,
			"total": roll,
			"dc": dc,
			"success": roll >= dc
		}
	var record := {
		"request_id": request_id,
		"kind": "concentration",
		"caster": caster,
		"target": target,
		"dc": dc,
		"roll": roll,
		"feature": feature,
		"save_test": effective_save_test,
		"decisions": decisions.duplicate(),
		"result_base": base_result.duplicate(false),
		"host_players": host_players,
		"host_monsters": host_monsters,
		"target_hosted": _host_contains(host_players, host_monsters, target),
		"caster_hosted": _host_contains(host_players, host_monsters, caster),
		"settled": false,
		"serial": _request_counter
	}
	_pending_requests[request_id] = record
	_active_request_id_by_caster[caster_id] = request_id
	return request_id


## The stepped executor registers the exact suspended continuation and cast that
## own this request. Settlement reads them from here, never from the payload.
static func attach_continuation(request_id: String, continuation: Dictionary, cast) -> void:
	if request_id.is_empty() or not _pending_requests.has(request_id):
		return
	_pending_requests[request_id]["ordered_continuation"] = continuation
	if str(_pending_requests[request_id].get("kind", "")) != "save_bonus":
		_pending_requests[request_id]["cast"] = cast


static func create_roll_choice_request(cast: SpellResolutionContext, target, roller, test_kind: String, label: String, continuation: Dictionary) -> Dictionary:
	_request_counter += 1
	var caster_id := str(cast.caster.get_instance_id())
	var request_id := "roll_req_%d_%s_%d" % [_epoch, caster_id, _request_counter]
	_pending_requests[request_id] = {
		"request_id": request_id, "kind": "roll_choice", "caster": cast.caster,
		"target": target, "roller": roller, "test_kind": test_kind, "label": label,
		"decisions": cast.decisions, "cast": cast, "ordered_continuation": continuation,
		"host_players": cast.decisions.get("players"), "host_monsters": cast.decisions.get("monsters"),
		"caster_hosted": _host_contains(cast.decisions.get("players"), cast.decisions.get("monsters"), cast.caster),
		"target_hosted": _host_contains(cast.decisions.get("players"), cast.decisions.get("monsters"), target),
		"settled": false,
	}
	_active_request_id_by_caster[caster_id] = request_id
	return {"success": true, "roll_choice_request": {"request_id": request_id}, "step_results": continuation.get("step_results", [])}


static func roll_choice_record(caster: Character, result: Dictionary) -> Dictionary:
	var request: Dictionary = result.get("roll_choice_request", {})
	var record: Dictionary = _pending_requests.get(str(request.get("request_id", "")), {})
	var validation := _validate_request(caster, record.get("target"), result, "roll_choice")
	return record if bool(validation.get("valid", false)) else {}


static func settle_roll_choice(caster: Character, target, result: Dictionary, answer: Dictionary) -> Dictionary:
	var validation := _validate_request(caster, target, result, "roll_choice")
	if not bool(validation.get("valid", false)):
		return {"success": false, "refused": true, "message": str(validation.get("error", "Invalid roll choice."))}
	var record: Dictionary = validation["record"]
	var selected: Dictionary = answer.get("roll_token_replacement", {})
	if not selected.is_empty():
		var check := RollTokenRules.validate_replacement_request(selected.get("owner"), record["roller"], str(selected.get("pool_id", "")), str(selected.get("token_id", "")), record["decisions"])
		if not bool(check.get("valid", false)):
			return {"success": false, "refused": true, "message": str(check.get("reason", "Invalid token choice."))}
	_consume_request(record)
	return SharedStepExecutor.resume_roll_choice(record, selected)


## Canonical actor recorded for an outstanding request, or null when unknown/settled.
static func owner_target(result: Dictionary):
	if result.has("damage_request") and result["damage_request"] is Dictionary:
		var req_id: String = str(result["damage_request"].get("request_id", ""))
		var rec = _pending_requests.get(req_id, null)
		if rec is Dictionary and not bool(rec.get("settled", false)) and str(rec.get("kind", "")) == "damage":
			return rec.get("target")
	if result.has("concentration_request") and result["concentration_request"] is Dictionary:
		var req_id: String = str(result["concentration_request"].get("request_id", ""))
		var rec = _pending_requests.get(req_id, null)
		if rec is Dictionary and not bool(rec.get("settled", false)) and str(rec.get("kind", "")) == "concentration":
			return rec.get("target")
	if result.has("save_bonus_request") and result["save_bonus_request"] is Dictionary:
		var req_id: String = str(result["save_bonus_request"].get("request_id", ""))
		var rec = _pending_requests.get(req_id, null)
		if rec is Dictionary and not bool(rec.get("settled", false)) and str(rec.get("kind", "")) == "save_bonus":
			return rec.get("target")
	return null


## Canonical identity: the live object/Dictionary itself. Matching IDs or equal
## Dictionary contents are never proof that a callback holds the owner's actor.
static func _is_canonical_actor(a, b) -> bool:
	if a == null or b == null:
		return false
	if a is Object or b is Object:
		return a is Object and b is Object and is_instance_valid(a) and is_instance_valid(b) and a == b
	return is_same(a, b)


static func _host_contains(players, monsters, actor) -> bool:
	if actor == null:
		return false
	if actor is Dictionary and monsters is Array:
		for monster in monsters:
			if is_same(monster, actor):
				return true
	if actor is Character and players is Array:
		for entry in players:
			if entry is Dictionary and entry.get("character") == actor:
				return true
	return false


## Read-only. Refuses before any HP/SP/grant or request consumption.
static func validate_damage_request(caster: Character, target, result: Dictionary) -> Dictionary:
	return _validate_request(caster, target, result, "damage")


static func _validate_request(caster: Character, target, result: Dictionary, kind: String) -> Dictionary:
	var request_key := "%s_request" % kind
	if not result.has(request_key):
		return {"valid": false, "no_op": true}
	var req = result.get(request_key)
	if not req is Dictionary:
		return {"valid": false, "error": "Invalid %s payload." % request_key}
	var request_id: String = str(req.get("request_id", ""))
	if request_id.is_empty() or not _pending_requests.has(request_id):
		return {"valid": false, "error": "Unknown or missing request ID."}
	var record: Dictionary = _pending_requests[request_id]
	if str(record.get("kind", "")) != kind:
		return {"valid": false, "error": "Request kind mismatch (expected %s request)." % kind}
	if bool(record.get("settled", false)):
		return {"valid": false, "error": "Request has already been settled."}
	var owner_caster = record.get("caster")
	var caster_id := str(owner_caster.get_instance_id()) if owner_caster is Object and is_instance_valid(owner_caster) else "0"
	var active_id: String = str(_active_request_id_by_caster.get(caster_id, ""))
	if not active_id.is_empty() and active_id != request_id:
		return {"valid": false, "error": "Request is stale; a newer request is outstanding."}
	if not _is_canonical_actor(caster, owner_caster):
		return {"valid": false, "error": "Caller caster does not match request caster."}
	if bool(record.get("caster_hosted", false)) and not _host_contains(record.get("host_players"), record.get("host_monsters"), owner_caster):
		return {"valid": false, "error": "Request caster is no longer part of the encounter."}
	if target == null:
		return {"valid": false, "error": "Target actor is missing."}
	var owner_target_actor = record.get("target")
	if not _is_canonical_actor(target, owner_target_actor):
		return {"valid": false, "error": "Target does not match request target."}
	if bool(record.get("target_hosted", false)) and not _host_contains(record.get("host_players"), record.get("host_monsters"), owner_target_actor):
		return {"valid": false, "error": "Request target is no longer part of the encounter."}
	var ordered_cont = record.get("ordered_continuation")
	if ordered_cont is Dictionary and bool(ordered_cont.get("settled", false)):
		return {"valid": false, "error": "Continuation has already been settled."}
	return {"valid": true, "record": record, "request_id": request_id}


static func _consume_request(record: Dictionary) -> void:
	record["settled"] = true
	# Settled check-choice tombstones remain for replay refusal, but they no
	# longer need to retain the transient EventDialog that hosted the choice.
	if str(record.get("kind", "")) in ["ability_check_bonus", "ability_check_post_roll"]:
		record["host_node"] = null
	var owner_caster = record.get("caster")
	var caster_id := str(owner_caster.get_instance_id()) if owner_caster is Object and is_instance_valid(owner_caster) else "0"
	if _active_request_id_by_caster.get(caster_id) == str(record.get("request_id", "")):
		_active_request_id_by_caster.erase(caster_id)
	if str(record.get("kind", "")) in ["ability_check_bonus", "ability_check_post_roll"]:
		# Keep only the replay tombstone. The completed receipt is returned to the
		# caller, so retaining its actor, payload and transient chooser serves no
		# later validation purpose.
		record["caster"] = null
		record["target"] = null
		record["check_result"] = {}
		record["context"] = {}
		record["options"] = []


static func _finish_spell_damage(caster: Character, target, details: Dictionary, bonus: int, scale: float, damage_type: String, decisions: Dictionary, result: Dictionary, condition_duration: int = 1, additional_damage_packets: Array[Dictionary] = []) -> Dictionary:
	var context: Dictionary = decisions.get("spell_damage_context", {})
	if SpellDamageRolls._can_empower(caster, decisions) and bool(decisions.get("defer_empowered", false)) and not context.get("empowered_resolved", false) and not Dice.selectable_dice(details).is_empty():
		var cha_mod := maxi(1, caster.ability_scores.get_ability_modifier("CHA")) if caster != null else 1
		var max_dice := mini(int(decisions.get("empowered_remaining_dice", cha_mod)), cha_mod)
		var req_id := SpellDamageRolls.create_damage_request(caster, target, details, bonus, scale, damage_type, condition_duration, additional_damage_packets, decisions, result)
		var resolution_cast: SpellResolutionContext = result.get("_resolution_context")
		if resolution_cast != null:
			SpellDamageRolls.publish_resolution_windows(resolution_cast, result)
			result.erase("_resolution_context")
		# The payload is a display copy for the owner prompt; the registry record owns the packet.
		result["damage_request"] = {"request_id": req_id, "details": details.duplicate(true), "bonus": bonus, "scale": scale, "damage_type": damage_type, "condition_duration": condition_duration, "max_dice": max_dice}
		return result
	var metamagic := SpellDamageRolls._apply_empowered_spell(caster, details, decisions)
	details = metamagic["details"]
	details = SpellDamageRolls._resolve_sorcerous_burst_explosions(caster, details)
	var hp_before: int = target.current_hp if target is Character else int(target.get("current_hp", 0))
	var temp_hp_before: int = target.temp_hp if target is Character else int(target.get("temp_hp", 0))
	var is_alive_before: bool = target.is_alive if target is Character else bool(target.get("is_alive", true))
	var amount := int(floor(float(int(details["final_total"]) + bonus) * scale))
	var damage_occurrence_id := WardRules.next_damage_occurrence_id()
	var primary_dmg_res := CombatAction.resolve_damage(target, amount, damage_type, decisions, false, false, caster, damage_occurrence_id)
	var actual: int = int(primary_dmg_res.get("damage", 0))
	var resolved: int = int(primary_dmg_res.get("resolved", 0))
	var ward_absorbed: int = int(primary_dmg_res.get("ward_absorbed", 0))
	var ward_remaining_hp: int = int(primary_dmg_res.get("ward_remaining_hp", 0))
	var ward_projected: bool = bool(primary_dmg_res.get("ward_projected", false))
	var ward_pool_id: String = str(primary_dmg_res.get("ward_pool_id", ""))
	var ward_owner_id: String = str(primary_dmg_res.get("ward_owner_id", ""))
	var ward_messages: Array[String] = []
	if not str(primary_dmg_res.get("ward_message", "")).is_empty():
		ward_messages.append(str(primary_dmg_res["ward_message"]))
	var temp_hp_absorbed: int = int(primary_dmg_res.get("temp_hp_absorbed", 0))
	var additional_components: Array[Dictionary] = []
	var damage_components: Array[Dictionary] = [{
		"component_id": str(decisions.get("_shared_component_id", "%s:1" % damage_type)),
		"type": damage_type,
		"raw": amount,
		"resolved": int(primary_dmg_res.get("resolved", 0)),
		"prevented": maxi(0, amount - int(primary_dmg_res.get("resolved", 0))),
		"absorbed": int(primary_dmg_res.get("temp_hp_absorbed", 0)),
		"hp_loss": int(primary_dmg_res.get("hp_loss", primary_dmg_res.get("damage", 0)))
	}]
	for packet in additional_damage_packets:
		var packet_details: Dictionary = packet.get("details", {})
		if packet_details.is_empty():
			continue
		var packet_type := str(packet.get("type", "acid"))
		var packet_amount := int(floor(float(int(packet_details.get("final_total", 0))) * scale))
		var packet_result := CombatAction.resolve_damage(target, packet_amount, packet_type, decisions, false, false, caster, damage_occurrence_id)
		var packet_damage := int(packet_result.get("damage", 0))
		damage_components.append({
			"component_id": str(packet.get("component_id", "%s:%d" % [packet_type, damage_components.size() + 1])),
			"type": packet_type,
			"raw": packet_amount,
			"resolved": int(packet_result.get("resolved", 0)),
			"prevented": maxi(0, packet_amount - int(packet_result.get("resolved", 0))),
			"absorbed": int(packet_result.get("temp_hp_absorbed", 0)),
			"hp_loss": int(packet_result.get("hp_loss", packet_damage))
		})
		actual += packet_damage
		resolved += int(packet_result.get("resolved", 0))
		ward_absorbed += int(packet_result.get("ward_absorbed", 0))
		if int(packet_result.get("ward_absorbed", 0)) > 0:
			ward_remaining_hp = int(packet_result.get("ward_remaining_hp", ward_remaining_hp))
			ward_projected = ward_projected or bool(packet_result.get("ward_projected", false))
			if ward_pool_id.is_empty():
				ward_pool_id = str(packet_result.get("ward_pool_id", ""))
			if ward_owner_id.is_empty():
				ward_owner_id = str(packet_result.get("ward_owner_id", ""))
			if not str(packet_result.get("ward_message", "")).is_empty():
				ward_messages.append(str(packet_result["ward_message"]))
		temp_hp_absorbed += int(packet_result.get("temp_hp_absorbed", 0))
		additional_components.append({"label": str(packet.get("label", "Additional damage")), "value": packet_damage, "type": packet_type, "formula": str(packet.get("formula", "")), "roll": packet_details})
	var hp_after: int = target.current_hp if target is Character else int(target.get("current_hp", 0))
	var temp_hp_after: int = target.temp_hp if target is Character else int(target.get("temp_hp", 0))
	var is_alive_after: bool = target.is_alive if target is Character else bool(target.get("is_alive", true))
	if not str(result.get("condition", "")).is_empty():
		if not result.get("effect_cast", {}).is_empty():
			SpellEffects.grant(target, result["effect_cast"], str(result["condition"]))
		else:
			CombatAction.apply_condition(target, str(result["condition"]), condition_duration, str(result.get("condition_source", "")))
	result.erase("condition_source")
	result["damage"] = actual
	result["hp_loss"] = actual
	result["resolved"] = resolved
	result["ward_absorbed"] = ward_absorbed
	result["ward_remaining_hp"] = ward_remaining_hp
	result["ward_projected"] = ward_projected
	result["ward_pool_id"] = ward_pool_id
	result["ward_owner_id"] = ward_owner_id
	result["temp_hp_absorbed"] = temp_hp_absorbed
	result["hp_before"] = hp_before
	result["hp_after"] = hp_after
	result["temp_hp_before"] = temp_hp_before
	result["temp_hp_after"] = temp_hp_after
	result["is_alive_before"] = is_alive_before
	result["is_alive_after"] = is_alive_after
	result["critical"] = bool(decisions.get("damage_is_critical", false))
	result["damage_is_critical"] = bool(decisions.get("damage_is_critical", false))
	result["damage_roll"] = details
	result["damage_type"] = damage_type
	result["additional_damage_components"] = additional_components
	result["damage_components"] = damage_components
	result["metamagic_used"] = bool(result.get("metamagic_used", false)) or bool(metamagic["used"])
	result["message"] = str(result["message"]).replace("{damage}", str(actual))
	if not ward_messages.is_empty():
		result["message"] += " " + " ".join(ward_messages)
	if metamagic["used"]:
		result["message"] += " Empowered Spell rerolls the selected damage dice; the new rolls stand."
	var resolution_cast: SpellResolutionContext = result.get("_resolution_context")
	if resolution_cast != null:
		var primary_component: Dictionary = damage_components[0] if not damage_components.is_empty() else {}
		var pre_damage_window: Dictionary = resolution_cast.resolution_window
		SpellDamageRolls.record_resolution_window(resolution_cast, "post_damage", {
			"roll_natural": int(pre_damage_window.get("roll_natural", 0)),
			"roll_modifier": int(pre_damage_window.get("roll_modifier", 0)),
			"roll_total": int(pre_damage_window.get("roll_total", 0)),
			"target_ac": int(pre_damage_window.get("target_ac", 0)),
			"final_hit": bool(result.get("hit", false)),
			"critical": bool(result.get("critical", false)),
			"damage_occurrence_id": damage_occurrence_id,
			"damage_type": damage_type,
			"damage_raw": int(primary_component.get("raw", amount)),
			"damage_resolved": int(primary_component.get("resolved", 0)),
			"damage_hp_loss": int(primary_component.get("hp_loss", 0)),
		})
		SpellDamageRolls.publish_resolution_windows(resolution_cast, result)
		result.erase("_resolution_context")
	return result


## Settles one owned request exactly once. Validation is read-only and happens
## before any damage, Sorcery Point, grant or request consumption. Only the
## answer's `metamagic:empowered_dice` is accepted; the roll, actors, source,
## result base and Metamagic budget come from the registered owner record. The
## answer dictionary receives the spent/remaining budget so existing callers can
## carry it, but it can never replace owner state.
static func settle_pending_request(caster: Character, target, result: Dictionary, answer: Dictionary) -> Dictionary:
	var validation := validate_damage_request(caster, target, result)
	if not validation.get("valid", false):
		return validation
	var record: Dictionary = validation["record"]
	_consume_request(record)
	var owner_decisions: Dictionary = record["decisions"]
	var final_decisions := owner_decisions.duplicate()
	final_decisions["defer_empowered"] = false
	final_decisions.erase("metamagic:empowered_dice")
	if answer.has("metamagic:empowered_dice"):
		final_decisions["metamagic:empowered_dice"] = answer["metamagic:empowered_dice"]
	var settled := SpellDamageRolls._finish_spell_damage(record["caster"], record["target"], record["details"], int(record["bonus"]), float(record["scale"]), str(record["damage_type"]), final_decisions, record["result_base"].duplicate(false), int(record["condition_duration"]), record["additional_damage_packets"])
	for key in ["empowered_sp_spent", "empowered_remaining_dice"]:
		if final_decisions.has(key):
			owner_decisions[key] = final_decisions[key]
			answer[key] = final_decisions[key]
	var cast_ctx: SpellResolutionContext = record.get("cast")
	if cast_ctx == null and record.get("ordered_continuation") is Dictionary:
		cast_ctx = record["ordered_continuation"].get("cast")
	if cast_ctx != null:
		for key in ["empowered_sp_spent", "empowered_remaining_dice"]:
			if final_decisions.has(key):
				cast_ctx.decisions[key] = final_decisions[key]
		if final_decisions.has("spell_damage_context"):
			cast_ctx.decisions["spell_damage_context"] = final_decisions["spell_damage_context"]
		cast_ctx.decisions.erase("damage_is_critical")
		cast_ctx.decisions.erase("critical")
	return {"valid": true, "record": record, "result": settled}


## Read-only. Refuses before any state mutation or concentration loss.
static func validate_concentration_request(caster: Character, target, result: Dictionary) -> Dictionary:
	return _validate_request(caster, target, result, "concentration")


static func _is_answer_accepted(answer: Dictionary, feature: String) -> bool:
	if answer.is_empty():
		return false
	if answer.has("feature") and str(answer["feature"]) != feature:
		return false
	if answer.has(feature):
		return bool(answer[feature])
	var other_feature: String = "bardic_inspiration" if feature == "stroke_of_luck" else "stroke_of_luck"
	if answer.has(other_feature) and not answer.has(feature) and not answer.has("accepted"):
		return false
	if answer.has("accepted"):
		if answer.has(other_feature) and not answer.has(feature):
			return false
		return bool(answer["accepted"])
	return false


## Extracts an explicit, feature-specific decision for character's concentration save.
## Returns boolean if explicitly answered, or null if no decision is supplied.
static func get_concentration_decision(decisions: Dictionary, character, feature: String, caster: Character = null) -> Variant:
	if decisions.is_empty() or character == null:
		return null
	var char_id: String = character.character_id if character is Character else str(character.get("character_id", ""))

	# 1. Target-scoped concentration keys:
	if not char_id.is_empty():
		var target_keys := [
			"concentration:%s:%s" % [feature, char_id],
			"%s:%s" % [feature, char_id],
			"concentration_%s:%s" % [feature, char_id]
		]
		for k in target_keys:
			if decisions.has(k):
				return bool(decisions[k])

	# 2. General concentration-scoped keys for this feature:
	var conc_feature_keys := [
		"concentration:%s" % feature,
		"concentration_%s" % feature
	]
	for k in conc_feature_keys:
		if decisions.has(k):
			return bool(decisions[k])

	# 3. Generic concentration_choice (only if feature-specific key is not present):
	if decisions.has("concentration_choice"):
		return bool(decisions["concentration_choice"])

	# 4. Bare feature key:
	# Only accepted if character is the caster (or caster is null) AND decisions does not represent
	# an attack roll decision on the caster.
	if decisions.has(feature):
		if caster != null and caster != character:
			return null
		if decisions.has("has_attack") or decisions.has("attack_roll") or decisions.has("damage_is_critical"):
			return null
		return bool(decisions[feature])

	return null


## Settles an outstanding concentration save choice exactly once.
static func settle_pending_concentration_request(caster: Character, target, result: Dictionary, answer: Dictionary) -> Dictionary:
	var validation := validate_concentration_request(caster, target, result)
	if not validation.get("valid", false):
		return validation
	var record: Dictionary = validation["record"]
	_consume_request(record)
	var feature: String = str(record.get("feature", "stroke_of_luck"))
	var accepted: bool = _is_answer_accepted(answer, feature)
	var target_char: Character = record["target"]
	var save_test: Dictionary = record.get("save_test", {}).duplicate(true)
	var dc: int = int(record.get("dc", 10))
	var roll: int = int(record.get("roll", save_test.get("total", 0)))
	var success := false
	var cast_ctx: SpellResolutionContext = record.get("cast")
	var spell_cast_ctx: SpellCastContext = cast_ctx.decisions.get("cast_context") if cast_ctx != null else null
	var hud = cast_ctx.decisions.get("hud", spell_cast_ctx.hud if spell_cast_ctx != null else null)

	if feature == "stroke_of_luck":
		if accepted:
			var stroke := RogueRules.apply_stroke_of_luck(target_char, save_test, true)
			if stroke.get("used", false):
				save_test = stroke.get("result", save_test)
				roll = int(save_test.get("total", roll))
				success = bool(save_test.get("success", false))
				if hud != null:
					hud.add_log("%s uses Stroke of Luck on the concentration save: %d vs DC %d." % [target_char.character_name, roll, dc])
	elif feature == "bardic_inspiration":
		if accepted:
			var inspiration := BardicInspirationRules.apply_to_test(target_char, roll, dc, true)
			if inspiration.get("used", false):
				roll = int(inspiration.get("total", roll))
				success = bool(inspiration.get("success", false))
				save_test["total"] = roll
				save_test["success"] = success
				if hud != null:
					hud.add_log("%s uses Bardic Inspiration (+%d) on the concentration save: %d vs DC %d." % [target_char.character_name, int(inspiration.get("bonus", 0)), roll, dc])

	# Choice sequencing: after declining Stroke or using it but still failing, an available Bardic Inspiration choice must still be offered
	if not success and feature == "stroke_of_luck" and BardicInspirationRules.has_die(target_char):
		var next_req_id := create_concentration_request(record["caster"], target_char, dc, roll, "bardic_inspiration", record["decisions"], record.get("result_base", {}), save_test)
		var ordered_cont: Dictionary = record.get("ordered_continuation", {})
		if not ordered_cont.is_empty():
			ordered_cont["request_id"] = next_req_id
			ordered_cont["continuation_id"] = next_req_id
			attach_continuation(next_req_id, ordered_cont, record.get("cast"))
		return {
			"valid": true,
			"record": record,
			"has_next_request": true,
			"next_request_id": next_req_id,
			"next_feature": "bardic_inspiration",
			"next_roll": roll,
			"next_dc": dc,
			"save_test": save_test,
			"success": false,
			"feature": feature,
			"accepted": accepted
		}

	# All choices finished for this concentration save
	if success:
		if hud != null:
			hud.add_log("[color=green]%s maintained concentration![/color]" % target_char.character_name)
	else:
		if hud != null:
			hud.add_log("[color=red]%s failed CON save! Concentration lost.[/color]" % target_char.character_name)
		SpellEncounterLifecycle._end_concentration(spell_cast_ctx, target_char)

	return {
		"valid": true,
		"record": record,
		"has_next_request": false,
		"success": success,
		"feature": feature,
		"accepted": accepted,
		"roll": roll,
		"dc": dc,
		"save_test": save_test
	}
