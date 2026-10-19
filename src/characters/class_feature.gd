## Class Feature
## Resolves and executes class feature abilities during combat or events.
class_name ClassFeature
extends RefCounted

## Common self-targeted class activations use the same costs, budgets and
## effect vocabulary. Targeted combat actions keep their existing resolvers.
const COMMON_SELF_EFFECTS := [
	"heal", "heal_self", "temporary_hp", "full_heal",
	"grant_condition", "apply_condition", "remove_condition",
	"remove_all_conditions", "stat_modifier", "ac_bonus",
	"speed_modifier", "roll_modifier", "restore_resource",
	"pact_magic_recovery", "innate_sorcery", "clear_concentration",
	"timed_protection", "heal_by_pool_rolls", "timed_numeric_modifier", "next_matching_melee_hit", "timed_temporary_hp",
]

static func content_error(feature: Dictionary) -> String:
	if feature.has("attack_unit_substitution"):
		if CombatChildActions.units(feature) == 0 or feature.get("action_cost") != "action" or feature.get("executor") != "class_feature" or feature.has("resource_pool") or feature.get("effects", []).is_empty() or not feature.get("effects", []).all(func(effect): return effect is Dictionary and str(effect.get("type", "")) in ["heal", "heal_self"]): return "Strike substitution supports ordinary self-healing activations only."
	if feature.has("child_actions"): return CombatChildActions.content_error(feature)
	if feature.has("temporary_hp_grant"): return TemporaryHPRules.content_error(feature)
	if feature.has("allocation"): return PartyAllocationRules.content_error(feature)
	if feature.has("roll_intervention"): return PartyInterventionRules.content_error(feature)
	if feature.has("transfer_grant"): return CapturedGrantRules.content_error(feature)
	if feature.get("executor", "") != "class_feature":
		return "Unknown feature executor"
	if feature.get("type", "") != "active" or feature.get("target", "self") != "self":
		return "Common class activations must target the user"
	var has_exchange := feature.has("resource_exchange")
	if has_exchange:
		var exchange: Variant = feature["resource_exchange"]
		if not exchange is Dictionary:
			return "A resource exchange must be an object."
		for field in exchange:
			if field not in ["payment_pool_id", "payment_quantity", "restoration_pool_id", "restoration_quantity", "restoration_recipient"]:
				return "Resource exchange contains an unsupported field."
		if str(exchange.get("restoration_recipient", "self")) not in ["self", "party_member"]:
			return "Resource exchange recipient must be self or an active party member."
		var payment_id := str(exchange.get("payment_pool_id", "")).strip_edges()
		var slot_payment := payment_id in ["spell_slots:ordinary", "spell_slots:pact"]
		# Classes load before items. Resolve item existence when offering/committing.
		if payment_id.begins_with("inventory:") and (payment_id.trim_prefix("inventory:").strip_edges().is_empty() or not ResourcePoolRules._integer(exchange.get("payment_quantity", null), 1, Inventory.MAX_BACKPACK_SIZE)):
			return "Inventory exchange requires an item ID and a backpack quantity from 1 to 40."
		if payment_id.is_empty() or str(exchange.get("restoration_pool_id", "")).strip_edges().is_empty() or not ResourcePoolRules._integer(exchange.get("payment_quantity", null), 1, ResourcePoolRules.MAX_CAPACITY) or not ResourcePoolRules._integer(exchange.get("restoration_quantity", null), 1, ResourcePoolRules.MAX_CAPACITY):
			return "Resource exchange requires eligible pool IDs and fixed positive quantities from 1 to 100."
		if slot_payment and payment_id == "spell_slots:ordinary" and exchange.get("payment_quantity", 0) > 9:
			return "Spell-slot exchange quantity exceeds the supported pool size."
		for field in ["resource_pool", "resource_id", "resource_cost", "uses", "uses_by_level", "uses_ability", "uses_per", "minimum_uses", "short_rest_recovery"]:
			if feature.has(field):
				return "An exchange activation uses only its authored exchange payment."
		if not feature.get("effects", []) is Array or not feature.get("effects", []).is_empty():
			return "An exchange activation uses only its authored exchange payment."
	if feature.has("resource_pool"):
		for field in ["resource_id", "uses", "uses_by_level", "uses_ability", "uses_per", "minimum_uses", "short_rest_recovery"]:
			if feature.has(field):
				return "A resource-pool activation cannot also declare legacy resource field '%s'." % field
	if feature.has("requires_no_heavy_armor") and not feature["requires_no_heavy_armor"] is bool:
		return "Armor requirements must be boolean"
	if feature.get("action_cost", "") not in ["action", "magic_action", "bonus_action", "free"]:
		return "Unsupported action cost"
	if feature.has("resource_id"):
		if not feature["resource_id"] is String or feature["resource_id"].is_empty():
			return "Resource reference must be a nonempty ID"
	elif feature.has("resource_pool"):
		var pool_error := ResourcePoolRules.definition_error(feature)
		if not pool_error.is_empty():
			return pool_error
	elif not has_exchange and feature.get("uses_per", "") not in ["short_rest", "long_rest", "rest", "turn", "combat"]:
		return "An active feature requires an explicit resource recovery cadence"
	var cost: Variant = feature.get("resource_cost", 1)
	if not (cost is int or cost is float) or float(cost) != float(int(cost)) or int(cost) < 1 or int(cost) > 100:
		return "Resource cost must be a positive integer up to 100"
	if not feature.get("effects", []) is Array or (feature.get("effects", []).is_empty() and not has_exchange):
		return "Common class activations require an effect"
	var protection_count := 0
	for effect in feature["effects"]:
		if effect is Dictionary and effect.get("type")=="timed_protection": protection_count+=1
	if protection_count>0 and (feature["effects"].size()!=1 or not feature.has("resource_pool")):
		return "Protection activation requires one effect and its exact resource pool."
	var timed_grant_count := 0
	var next_hit_grant_count := 0
	var timed_temporary_hp_grant_count := 0
	for effect in feature["effects"]:
		var error := _effect_content_error(effect, feature)
		if not error.is_empty():
			return error
		match str(effect.get("type", "")):
			"timed_numeric_modifier":
				timed_grant_count += 1
			"next_matching_melee_hit":
				next_hit_grant_count += 1
			"timed_temporary_hp":
				timed_temporary_hp_grant_count += 1
	if timed_grant_count > 1:
		return "An activation supports at most one timed numeric modifier per source."
	if next_hit_grant_count > 1:
		return "An activation supports at most one next melee-hit grant per source."
	if timed_temporary_hp_grant_count > 1:
		return "An activation supports at most one timed Temporary HP grant per source."
	var pool_roll_heal_count := 0
	for effect in feature["effects"]:
		if str(effect.get("type", "")) == "heal_by_pool_rolls":
			pool_roll_heal_count += 1
	if feature.get("resource_pool", {}).has("die_size") and pool_roll_heal_count != 1:
		return "This dice-pool slice requires exactly one pool-roll healing effect."
	if not feature.get("resource_pool", {}).has("die_size") and pool_roll_heal_count > 0:
		return "Pool-roll healing requires a dice pool."
	if pool_roll_heal_count > 0 and feature["effects"].size() != 1:
		return "Pool-roll healing must be the activation's only effect."
	var passive_effects: Variant = feature.get("passive_effects", [])
	if feature.get("resource_pool", {}).has("die_size") and (not passive_effects is Array or not passive_effects.is_empty()):
		return "This dice-pool slice does not combine activations with passive effects."
	if not feature.get("passive_effects", []) is Array:
		return "Passive class effects must be an array"
	for effect in feature.get("passive_effects", []):
		var error := passive_effect_content_error(effect)
		if not error.is_empty():
			return error
		if effect is Dictionary and effect.get("type", "") == "weapon_damage_rider" and effect.has("use_limit") and not feature.has("resource_pool"):
			return "A bounded weapon damage rider requires its source feature's resource pool."
		if effect is Dictionary and effect.get("type", "") == "weapon_attack_numeric_bonus" and (not feature.has("resource_pool") or not feature["resource_pool"] is Dictionary or feature["resource_pool"].is_empty()):
			return "An attack bonus requires its source feature's numeric pool."
	return ""


static func passive_effect_content_error(effect: Variant) -> String:
	if not effect is Dictionary:
		return "Passive class effects must be dictionaries"
	var effect_type := str(effect.get("type", ""))
	if effect_type in ["ability_check_roll_mode", "ability_check_roll_mode_policy", "ability_check_numeric_bonus"] or (effect_type == "ability_check_mandatory_reroll" and str(effect.get("domain", "")) == "event_skill_check"):
		var filter_error := ability_check_filter_error(effect)
		if not filter_error.is_empty(): return filter_error
	if effect_type == "check_floor": return CheckFloorRules.content_error(effect)
	if effect_type == "weapon_damage_rider":
		return DataLoader._weapon_damage_rider_error(effect)
	if effect_type not in ["ability_check_override", "ability_check_advantage", "ability_check_floor", "saving_throw_advantage", "weapon_attack_numeric_bonus", "ability_check_numeric_bonus", "ability_check_mandatory_reroll", "ability_check_roll_mode", "ability_check_roll_mode_policy", "roll_outcome_override", "recipient_damage_map"]:
		return "Unsupported shared passive operation"
	if effect_type == "recipient_damage_map":
		if str(effect.get("domain", "")) != "shared_spell_save" or str(effect.get("id", "")).is_empty() or not str(effect.get("id", "")).is_valid_identifier() or str(effect.get("ability", "")).to_upper() not in DataLoader.VALID_ABILITIES:
			return "Recipient damage maps require a shared_spell_save domain, effect ID and save ability."
		for field in ["cause_id", "purpose_id", "origin_effect_id"]:
			if not str(effect.get(field, "")).is_valid_identifier(): return "Recipient damage maps require exact save-cause context."
		if not ((effect.get("success_scale") is int or effect.get("success_scale") is float) and float(effect.success_scale) >= 0.0 and float(effect.success_scale) <= 1.0 and (effect.get("failure_scale") is int or effect.get("failure_scale") is float) and float(effect.failure_scale) >= 0.0 and float(effect.failure_scale) <= 1.0):
			return "Recipient damage maps require success and failure scales from 0 through 1."
		for field in effect:
			if field not in ["type", "id", "domain", "ability", "cause_id", "purpose_id", "origin_effect_id", "success_scale", "failure_scale"]:
				return "Recipient damage map contains an unsupported field."
		return ""
	if effect_type == "roll_outcome_override":
		var domains: Variant = effect.get("domains", null)
		var outcomes: Variant = effect.get("outcomes", null)
		var ability := str(effect.get("ability", "")).to_upper()
		var stage := str(effect.get("stage", ""))
		var cost: Variant = effect.get("cost", null)
		if not domains is Array or domains.is_empty() or not outcomes is Array or outcomes.is_empty() or not ResourcePoolRules._integer(cost, 1, ResourcePoolRules.MAX_CAPACITY):
			return "Roll outcome override requires domains, outcomes and a valid pool cost"
		for domain in domains:
			if domain not in ["weapon_attack", "shared_spell_attack", "shared_spell_save"]:
				return "Roll outcome override contains an unsupported domain"
			var expected_stage := "after_roll_before_consequences" if domain == "shared_spell_save" else "provisional_outcome"
			var expected_outcomes: Array = ["success", "failure"] if domain == "shared_spell_save" else ["hit", "miss"]
			if stage != expected_stage:
				return "Roll outcome override stage does not match its domain"
			for outcome in outcomes:
				if outcome not in expected_outcomes:
					return "Roll outcome override outcome does not match its domain"
		if domains.has("shared_spell_save") and ability not in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
			return "Saving-throw outcome override requires a supported ability"
		if not domains.has("shared_spell_save") and effect.has("ability"):
			return "Attack outcome override cannot declare a save ability"
		for field in effect:
			if field not in ["type", "domains", "outcomes", "stage", "ability", "cost"]:
				return "Roll outcome override contains an unsupported field"
		return ""
	if effect_type in ["ability_check_roll_mode", "ability_check_roll_mode_policy"]:
		var mode := str(effect.get("mode", ""))
		var operation := str(effect.get("operation", "grant" if effect_type == "ability_check_roll_mode" else ""))
		var ability := str(effect.get("ability", "")).to_upper()
		var skill := str(effect.get("skill", ""))
		var exemptions: Variant = effect.get("exempt_source_definition_ids", [])
		var instance_exemptions: Variant = effect.get("exempt_source_instance_ids", [])
		if not str(effect.get("id", "")).is_valid_identifier() or str(effect.get("domain", "")) != "event_skill_check" or mode not in ["advantage", "disadvantage"] or operation not in ["grant", "cancel", "prohibit"] or ability not in ["STR", "DEX", "CON", "INT", "WIS", "CHA"] or (not skill.is_empty() and skill not in DataLoader.VALID_SKILLS) or not exemptions is Array or not instance_exemptions is Array:
			return "Ability-check roll modes require an ability, mode and supported operation"
		for source_definition_id in exemptions:
			if not source_definition_id is String or str(source_definition_id).strip_edges().is_empty():
				return "Roll-mode exemptions must name source definition IDs"
		for source_instance_id in instance_exemptions:
			if not source_instance_id is String or str(source_instance_id).strip_edges().is_empty():
				return "Roll-mode exemptions must name exact source instance IDs"
		for field in effect:
			if field not in ["type", "id", "domain", "operation", "mode", "ability", "skill", "task_id", "purpose_id", "source_event_id", "source_check_id", "exempt_source_definition_ids", "exempt_source_instance_ids"]:
				return "Ability-check roll mode contains an unsupported field"
		if effect_type == "ability_check_roll_mode" and (not operation == "grant" or not exemptions.is_empty() or not instance_exemptions.is_empty()):
			return "Roll-mode grant sources cannot declare policy exemptions"
		if effect_type == "ability_check_roll_mode_policy" and operation == "grant":
			return "Roll-mode policies must cancel or prohibit a mode"
		return ""
	if effect_type == "ability_check_numeric_bonus":
		var amount: Variant = effect.get("amount", null)
		var has_amount: bool = effect.has("amount") and not effect.has("die_size") and ResourcePoolRules._integer(amount, 1, 20)
		var has_die: bool = effect.has("die_size") and not effect.has("amount") and ResourcePoolRules._integer(effect.get("die_size"), 1, 20) and int(effect.get("die_size")) in ResourcePoolRules.SUPPORTED_DIE_SIZES
		if str(effect.get("domain", "")) != "event_skill_check" or not str(effect.get("id", "")).is_valid_identifier() or not (has_amount or has_die) or not ResourcePoolRules._integer(effect.get("cost", null), 1, ResourcePoolRules.MAX_CAPACITY):
			return "Ability-check modifier requires an event_skill_check domain, effect ID, one bounded bonus and pool cost"
		var effect_skill := str(effect.get("skill", ""))
		if str(effect.get("ability", "")).to_upper() not in ["STR", "DEX", "CON", "INT", "WIS", "CHA"] or (not effect_skill.is_empty() and effect_skill not in DataLoader.VALID_SKILLS):
			return "Ability-check modifier requires an ability and optional skill eligibility"
		if str(effect.get("payment_policy", "pay_on_choice")) not in SpellDamageRolls.FAILED_SAVE_BONUS_PAYMENT_POLICIES:
			return "Ability-check modifier uses an unsupported payment policy"
		for field in effect:
			if field not in ["type", "id", "domain", "ability", "skill", "task_id", "purpose_id", "required_tool_id", "source_event_id", "source_check_id", "amount", "die_size", "cost", "payment_policy"]:
				return "Ability-check modifier contains an unsupported field"
		return ""
	if effect_type == "ability_check_mandatory_reroll":
		var outcomes: Variant = effect.get("eligible_outcomes", null)
		var domain := str(effect.get("domain", ""))
		if domain not in ["event_skill_check", "weapon_attack", "shared_spell_attack", "shared_spell_save"] or not str(effect.get("id", "")).is_valid_identifier() or not ResourcePoolRules._integer(effect.get("cost", null), 1, ResourcePoolRules.MAX_CAPACITY):
			return "Test rerolls require a supported domain, effect ID and pool cost"
		var skill := str(effect.get("skill", ""))
		if str(effect.get("ability", "")).to_upper() not in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
			return "Test rerolls require an exact ability"
		var allowed_outcomes: Array = ["success", "failure"] if domain in ["event_skill_check", "shared_spell_save"] else ["hit", "miss"]
		if domain == "event_skill_check":
			if (not skill.is_empty() and skill not in DataLoader.VALID_SKILLS):
				return "Event-check rerolls require valid optional skill eligibility"
		elif not skill.is_empty() or effect.has("task_id") or effect.has("purpose_id") or effect.has("required_tool_id") or effect.has("source_event_id") or effect.has("source_check_id"):
			return "Combat rerolls cannot declare event-check eligibility fields"
		if not outcomes is Array or outcomes.is_empty() or outcomes.size() > 2 or outcomes.any(func(value): return value not in allowed_outcomes) or (outcomes.size() == 2 and outcomes[0] == outcomes[1]):
			return "Test rerolls require unique eligible outcomes for their domain"
		if str(effect.get("reroll_mode", "")) not in ["natural_only", "whole_test"] or str(effect.get("bonus_dice_policy", "")) not in ["keep", "reroll"]:
			return "Ability-check rerolls require a supported reroll and bonus-dice policy"
		if str(effect.get("selection_policy", "mandatory_new")) not in ["mandatory_new", "choose_old_or_new"] or str(effect.get("new_roll_mode", "captured")) not in ["captured", "normal", "advantage", "disadvantage"]:
			return "Ability-check rerolls require a supported kept-result and new-test mode policy"
		if effect.has("level_bonus_formula") and (not SharedStepExecutor.formula_content_error(effect.get("level_bonus_formula")).is_empty() or not ResourcePoolRules._actor_formula_error(effect.get("level_bonus_formula")).is_empty()):
			return "Ability-check reroll level bonus requires a deterministic actor-only formula"
		for field in effect:
			if field not in ["type", "id", "domain", "ability", "skill", "task_id", "purpose_id", "required_tool_id", "source_event_id", "source_check_id", "spell_id", "eligible_outcomes", "reroll_mode", "bonus_dice_policy", "selection_policy", "new_roll_mode", "level_bonus_formula", "cost"]:
				return "Test reroll contains an unsupported field"
		return ""
	if effect_type == "weapon_attack_numeric_bonus":
		var amount: Variant = effect.get("amount", null)
		var has_numeric_bonus: bool = effect.has("amount") and not effect.has("die_size") and ResourcePoolRules._integer(amount, 1, 20)
		var has_die_bonus: bool = effect.has("die_size") and not effect.has("amount") and ResourcePoolRules._integer(effect.get("die_size"), 1, 20) and int(effect.get("die_size")) in ResourcePoolRules.SUPPORTED_DIE_SIZES
		var cost: Variant = effect.get("cost", null)
		var domains: Variant = effect.get("domains", [])
		var policy: Variant = effect.get("payment_policy", "pay_on_choice")
		if not (has_numeric_bonus or has_die_bonus) or not ResourcePoolRules._integer(cost, 1, ResourcePoolRules.MAX_CAPACITY):
			return "Weapon attack bonuses require one amount (1-20) or supported die_size and pool cost from 1 to 100"
		if not domains is Array or domains.is_empty() or domains.size() > 2:
			return "Attack bonuses must name one or more supported attack domains"
		var seen_domains: Array[String] = []
		for domain in domains:
			if not domain is String or domain not in ["weapon_attack", "shared_spell_attack"] or domain in seen_domains:
				return "Attack bonuses must name unique weapon_attack or shared_spell_attack domains"
			seen_domains.append(str(domain))
		if not policy is String or str(policy) not in SpellDamageRolls.FAILED_SAVE_BONUS_PAYMENT_POLICIES:
			return "Weapon attack bonuses require a supported payment_policy"
		for field in effect:
			if field not in ["type", "amount", "die_size", "cost", "domains", "payment_policy"]:
				return "Attack bonus contains an unsupported field"
		return ""
	var ability := str(effect.get("ability", "")).to_upper()
	if ability not in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
		return "Passive check operation requires a supported ability"
	if effect_type == "ability_check_override":
		var skills: Variant = effect.get("skills", [])
		if not skills is Array or skills.is_empty() or skills.size() > 18:
			return "Ability check override requires a bounded skill list"
		for skill in skills:
			if not skill is String or skill.is_empty() or skill.length() > 32:
				return "Ability check override contains an invalid skill"
	if effect_type == "ability_check_floor":
		var applies_to: Variant = effect.get("applies_to", [])
		if not applies_to is Array or applies_to.is_empty():
			return "Ability check floor requires a check type"
		for check_type in applies_to:
			if check_type not in ["ability_check", "saving_throw"]:
				return "Ability check floor contains an unsupported check type"
	for field in ["condition", "unless_condition"]:
		if effect.has(field) and (not effect[field] is String or effect[field].is_empty() or not effect[field].is_valid_identifier()):
			return "Conditional feature effect requires a simple condition ID"
	return ""

static func _effect_content_error(effect: Variant, feature: Dictionary) -> String:
	if not effect is Dictionary or str(effect.get("type", "")) not in COMMON_SELF_EFFECTS:
		return "Unsupported common self-effect"
	var effect_type := str(effect["type"])
	if effect_type=="timed_protection": return ProtectionRules.content_error(effect)
	if effect_type == "timed_numeric_modifier":
		if feature.get("resource_pool", {}) is not Dictionary or feature.get("resource_pool", {}).is_empty():
			return "A timed numeric modifier requires its exact source resource pool."
		if str(effect.get("kind", "")) != "stat" or str(effect.get("key", "")) != "AC":
			return "This timed modifier supports only an AC stat bonus."
		var amount: Variant = effect.get("amount", null)
		var duration: Variant = effect.get("duration_seconds", null)
		var cooldown: Variant = effect.get("cooldown_seconds", 0)
		if not (amount is int or amount is float) or float(amount) != float(int(amount)) or int(amount) < -100 or int(amount) > 100 or int(amount) == 0:
			return "Timed modifier amount must be a nonzero integer from -100 to 100."
		if not (duration is int or duration is float) or float(duration) != float(int(duration)) or int(duration) < 1 or int(duration) > 86400:
			return "Timed modifier duration must be 1-86400 campaign seconds."
		if not (cooldown is int or cooldown is float) or not is_finite(float(cooldown)) or float(cooldown) != floor(float(cooldown)) or int(cooldown) < 0 or int(cooldown) > 86400:
			return "Timed modifier cooldown must be 0-86400 campaign seconds."
		for field in effect:
			if field not in ["type", "kind", "key", "amount", "duration_seconds", "cooldown_seconds"]:
				return "Timed modifier contains an unsupported field."
		return ""
	if effect_type == "next_matching_melee_hit":
		if feature.get("resource_pool", {}) is not Dictionary or feature.get("resource_pool", {}).is_empty():
			return "A next melee-hit grant requires its exact source resource pool."
		var amount: Variant = effect.get("amount", null)
		var damage_type := str(effect.get("damage_type", ""))
		if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) != floor(float(amount)) or int(amount) < 1 or int(amount) > 100:
			return "Next melee-hit damage must be a fixed integer from 1 to 100."
		if damage_type not in DataLoader.VALID_DAMAGE_TYPES or damage_type == "none":
			return "Next melee-hit damage requires a supported damage type."
		var duration: Variant = effect.get("duration_seconds", null)
		if not (duration is int or duration is float) or not is_finite(float(duration)) or float(duration) != floor(float(duration)) or int(duration) < 1 or int(duration) > 86400:
			return "Next melee-hit grant duration must be 1-86400 campaign seconds."
		for field in effect:
			if field not in ["type", "amount", "damage_type", "duration_seconds"]:
				return "Next melee-hit grant contains an unsupported field."
		return ""
	if effect_type == "timed_temporary_hp":
		if feature.get("resource_pool", {}) is not Dictionary or feature.get("resource_pool", {}).is_empty():
			return "Timed Temporary HP requires its exact source resource pool."
		var amount: Variant = effect.get("amount", null)
		var duration: Variant = effect.get("duration_seconds", null)
		if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) != floor(float(amount)) or int(amount) < 1 or int(amount) > 100000:
			return "Timed Temporary HP amount must be an integer from 1 to 100000."
		if not (duration is int or duration is float) or not is_finite(float(duration)) or float(duration) != floor(float(duration)) or int(duration) < 1 or int(duration) > 86400:
			return "Timed Temporary HP duration must be 1-86400 campaign seconds."
		for field in effect:
			if field not in ["type", "amount", "duration_seconds"]:
				return "Timed Temporary HP contains an unsupported field."
		return ""
	if effect_type == "heal_by_pool_rolls":
		var pool: Dictionary = feature.get("resource_pool", {})
		if not pool.has("die_size") or not pool.has("spend_choice"):
			return "Pool-roll healing requires an authored dice pool and spend choice."
		return ""
	if effect_type in ["heal", "heal_self", "temporary_hp"]:
		var expressions: Array = [effect.get("value", "")]
		if effect.has("value_by_level"):
			if not effect["value_by_level"] is Dictionary or effect["value_by_level"].is_empty() or not effect["value_by_level"].has("1"):
				return "Healing scaling requires a level table with a level-1 baseline"
			expressions = effect["value_by_level"].values()
			for key in effect["value_by_level"]:
				if not str(key).is_valid_int() or str(int(key)) != str(key) or int(key) < 1 or int(key) > 20:
					return "Healing scaling level must be 1-20"
		var expression := RegEx.new()
		expression.compile("^[1-9][0-9]?d(4|6|8|10|12|20)(\\+(level|STR|DEX|CON|INT|WIS|CHA|[0-9]{1,3}))?$")
		for value in expressions:
			if not value is String or expression.search(value) == null:
				return "Healing requires bounded dice with an optional level, ability modifier or constant"
	if effect_type in ["grant_condition", "apply_condition", "remove_condition"]:
		var condition := str(effect.get("condition", ""))
		if condition.is_empty() or condition.length() > 48 or not condition.is_valid_identifier():
			return "Condition effects require a simple condition ID"
		if effect_type != "remove_condition" and (int(effect.get("duration", 1)) < 1 or int(effect.get("duration", 1)) > 100):
			return "Condition duration must be 1-100 turns"
	if effect_type in ["stat_modifier", "ac_bonus", "speed_modifier", "roll_modifier"]:
		var amount := int(effect.get("amount", effect.get("value", 0)))
		if amount < -100 or amount > 100:
			return "Modifier amount must be between -100 and 100"
		if int(effect.get("duration", 1)) < 1 or int(effect.get("duration", 1)) > 100:
			return "Modifier duration must be 1-100 turns"
		if effect.has("amount_by_level"):
			var levels: Variant = effect["amount_by_level"]
			if not levels is Dictionary or levels.is_empty() or not levels.has("1"):
				return "Modifier scaling requires a level table with a level-1 baseline"
			for key in levels:
				var value: Variant = levels[key]
				if not str(key).is_valid_int() or str(int(key)) != str(key) or int(key) < 1 or int(key) > 20:
					return "Modifier scaling level must be 1-20"
				if not (value is int or value is float) or float(value) != float(int(value)) or int(value) < -100 or int(value) > 100:
					return "Modifier scaling amount must be an integer from -100 to 100"
	if effect_type == "restore_resource":
		if str(effect.get("resource_id", effect.get("feature_id", ""))).is_empty() or int(effect.get("amount", 1)) < 1 or int(effect.get("amount", 1)) > 100:
			return "Resource recovery requires a resource ID and amount from 1-100"
	if effect_type == "pact_magic_recovery":
		var fraction := float(effect.get("fraction", 0.5))
		if fraction <= 0.0 or fraction > 1.0:
			return "Pact Magic recovery fraction must be above 0 and at most 1"
		if effect.has("fraction_by_level"):
			var fractions: Variant = effect["fraction_by_level"]
			if not fractions is Dictionary or fractions.is_empty() or not fractions.has("1"):
				return "Pact Magic recovery fractions require a level-1 baseline"
			for key in fractions:
				var level_fraction: Variant = fractions[key]
				if not str(key).is_valid_int() or str(int(key)) != str(key) or int(key) < 1 or int(key) > 20 or not (level_fraction is int or level_fraction is float) or float(level_fraction) <= 0.0 or float(level_fraction) > 1.0:
					return "Pact Magic recovery fractions must be between 0 and 1 at levels 1-20"
	if effect_type == "innate_sorcery" and (int(effect.get("duration", 10)) < 1 or int(effect.get("duration", 10)) > 100):
		return "Innate Sorcery duration must be 1-100 turns"
	return ""

static func availability(character: Character, feature: Dictionary, budget: CombatTurnBudget = null, source_instance_id: String = "", selected_pool_quantity: int = 0) -> Dictionary:
	var owned := character.get_feature(str(feature.get("id", "")))
	if owned.has("allocation"): return PartyAllocationRules.availability(character, owned, budget, source_instance_id)
	if owned.has("roll_intervention"): return {"available":false, "reason":"Available during an ally’s missed weapon attack", "remaining":0, "maximum":0, "cost":1, "action_cost":"free"}
	if owned.has("temporary_hp_grant"): return TemporaryHPRules.availability(character, owned, budget, source_instance_id)
	if owned.has("transfer_grant"): return CapturedGrantRules.availability(character, owned, budget, source_instance_id)
	var error := "Feature is not owned" if owned.is_empty() else content_error(owned)
	var exact_source_id := source_instance_id if not source_instance_id.is_empty() else str(owned.get("source_instance_id", ""))
	var pool := str(owned.get("resource_id", owned.get("id", "")))
	var pool_state := ResourcePoolRules.availability(character, exact_source_id) if owned.has("resource_pool") else {}
	var remaining := int(pool_state.get("current", character.feature_uses.get(pool, 0)))
	var cost := int(owned.get("resource_cost", 1))
	var pool_definition: Variant = owned.get("resource_pool", {})
	var is_dice_pool: bool = pool_definition is Dictionary and pool_definition.has("die_size")
	var is_exchange: bool = owned.has("resource_exchange")
	if is_exchange:
		remaining = 1
		cost = 1
		if ResourcePoolRules.exchange_payment_sources(character, owned["resource_exchange"]).is_empty():
			error = "No exact source pair can make this exchange."
	if is_dice_pool:
		var spend_choice: Variant = pool_definition.get("spend_choice", {})
		if not spend_choice is Dictionary or not spend_choice.has("minimum") or not spend_choice.has("maximum"):
			error = "The dice pool has no valid spend range."
		elif selected_pool_quantity == 0:
			# The feature list asks whether a choice can be offered before the
			# player has selected its quantity. Check the cheapest valid choice;
			# execute() still requires an explicit positive selection.
			cost = int(spend_choice["minimum"])
		elif selected_pool_quantity < int(spend_choice["minimum"]) or selected_pool_quantity > int(spend_choice["maximum"]):
			error = "Choose a positive amount within this dice pool's spend range."
		else:
			cost = selected_pool_quantity
	if str(owned.get("id", "")) == "barbarian_rage" and character.has_condition("raging"):
		cost = 0
	var action := str(owned.get("action_cost", "action"))
	if error.is_empty() and owned.has("resource_pool") and exact_source_id.is_empty():
		error = "Activation requires its exact source-instance identity."
	if error.is_empty():
		for effect in owned.get("effects", []):
			if str(effect.get("type", "")) == "timed_protection":
				error=ProtectionRules.activation_error(character,owned,exact_source_id,effect)
				if not error.is_empty(): break
			if str(effect.get("type", "")) == "timed_numeric_modifier":
				character.expire_campaign_modifiers(int(GameManager.campaign_elapsed_seconds))
				if character.has_campaign_modifier_source(exact_source_id):
					error = "This source already has an active timed grant."
					break
				var ready_at := character.campaign_modifier_cooldown_for_source(exact_source_id, int(GameManager.campaign_elapsed_seconds))
				if ready_at > 0:
					error = "This source is cooling down for %d more campaign seconds." % (ready_at - int(GameManager.campaign_elapsed_seconds))
					break
			if str(effect.get("type", "")) == "next_matching_melee_hit" and character.has_next_melee_hit_grant_source(exact_source_id):
				error = "This source already has an unspent next melee-hit grant."
				break
			if str(effect.get("type", "")) == "timed_temporary_hp":
				character.expire_timed_temporary_hp_grants(int(GameManager.campaign_elapsed_seconds))
				if character.has_timed_temporary_hp_grant_source(exact_source_id, int(GameManager.campaign_elapsed_seconds)):
					error = "This source already has a pending timed Temporary HP grant."
					break
				if int(GameManager.campaign_elapsed_seconds) + int(effect["duration_seconds"]) > 2147483647:
					error = "Timed Temporary HP deadline exceeds the campaign clock limit."
					break
	if error.is_empty() and owned.has("resource_pool") and str(character.numeric_resource_pools.get(exact_source_id, {}).get("definition_id", "")) != str(owned["resource_pool"].get("id", "")):
		error = "The selected source instance does not own this resource-pool definition."
	if error.is_empty() and is_dice_pool:
		var die := ResourcePoolRules.evaluate_die_size(pool_definition["die_size"], character)
		if not die.get("success", false) or int(character.numeric_resource_pools.get(exact_source_id, {}).get("die_size", 0)) != int(die.get("value", 0)):
			error = "The selected source's saved die size does not match its authored progression."
		if pool_definition.has("capture_policy") != character.numeric_resource_pools.get(exact_source_id, {}).has("captured_dice"):
			error = "The selected source's capture policy does not match its owned definition."
	if error.is_empty() and owned.has("resource_pool") and not pool_state.get("available", false):
		error = str(pool_state.get("message", "No uses remaining"))
	if error.is_empty() and bool(owned.get("requires_no_heavy_armor", false)) and character._is_wearing_heavy_armor():
		error = "Unavailable while wearing heavy armor"
	if error.is_empty() and not is_exchange and remaining < cost:
		error = "No uses remaining"
	if error.is_empty() and budget != null and not budget.can_spend(action):
		error = "No %s available" % action.replace("_", " ")
	return {"available": error.is_empty(), "reason": error, "remaining": remaining, "maximum": int(pool_state.get("capacity", character.get_feature_max_uses(pool))), "cost": cost, "action_cost": action, "source_instance_id": exact_source_id}


## Execute an active class feature on a character.
## Returns a result dictionary describing what happened.
static func execute(character: Character, feature: Dictionary, target = null, budget: CombatTurnBudget = null, source_instance_id: String = "", selected_pool_quantity: int = 0) -> Dictionary:
	var exact_source_id := source_instance_id if not source_instance_id.is_empty() else str(feature.get("source_instance_id", ""))
	var selected_payment_source_id := str(feature.get("selected_payment_source_instance_id", ""))
	var selected_restoration_source_id := str(feature.get("selected_restoration_source_instance_id", ""))
	# Commands and direct callers both resolve current owned production metadata.
	feature = character.get_feature(str(feature.get("id", ""))).duplicate(true)
	if feature.is_empty():
		return {"success": false, "message": "Feature is not owned."}
	if not selected_payment_source_id.is_empty() or not selected_restoration_source_id.is_empty():
		feature["selected_payment_source_instance_id"] = selected_payment_source_id
		feature["selected_restoration_source_instance_id"] = selected_restoration_source_id
	if feature.has("temporary_hp_grant"): return {"success":false, "message":"Choose a Temporary HP recipient through combat controls."}
	if feature.has("transfer_grant"): return {"success":false, "message":"Choose gift recipients through combat controls."}
	var feature_id: String = feature.get("id", "")
	var feature_name: String = feature.get("name", "Unknown")
	var sorcery_incarnate_reactivation := feature_id == "sorcerer_innate_sorcery" and character.class_id == "sorcerer" and character.level >= 7 and int(character.feature_uses.get(feature_id, 0)) <= 0
	if feature_id == "sorcerer_innate_sorcery" and character.has_condition("innate_sorcery"):
		return {"success": false, "message": "Innate Sorcery is already active."}
	if sorcery_incarnate_reactivation and character.get_sorcery_points() < 2:
		return {"success": false, "message": "Sorcery Incarnate can reactivate Innate Sorcery for 2 Sorcery Points."}
	if feature.has("executor"):
		var pool_definition: Variant = feature.get("resource_pool", {})
		if pool_definition is Dictionary and pool_definition.has("die_size") and selected_pool_quantity <= 0:
			return {"success": false, "message": "Choose a positive amount within this dice pool's spend range."}
		var available := availability(character, feature, budget, exact_source_id, selected_pool_quantity)
		if (not available["available"] and not sorcery_incarnate_reactivation) or (target != null and target != character):
			return {"success": false, "message": available["reason"] if not available["available"] else "This feature can only target its user."}
		if feature.has("resource_exchange"):
			var payment_source_id := str(feature.get("selected_payment_source_instance_id", ""))
			var restoration_source_id := str(feature.get("selected_restoration_source_instance_id", ""))
			var exchange: Dictionary = feature["resource_exchange"]
			var exchanged := ResourcePoolRules.exchange(character, payment_source_id, restoration_source_id, str(exchange["payment_pool_id"]), int(exchange["payment_quantity"]), str(exchange["restoration_pool_id"]), int(exchange["restoration_quantity"]), true, str(exchange.get("restoration_recipient", "self")) == "party_member")
			if not exchanged.get("success", false):
				return exchanged
			if budget != null:
				budget.spend(str(feature.get("action_cost", "action")))
			return {"success": true, "feature_name": feature.get("name", "Resource Exchange"), "results": [{"message": "%s exchanges %d resources for %d uses." % [character.character_name, int(exchange["payment_quantity"]), int(exchange["restoration_quantity"])]}], "exchange": exchanged}
	elif budget != null and not budget.can_spend(str(feature.get("action_cost", "action"))):
		return {"success": false, "message": "Action unavailable."}
	if feature_id == "barbarian_rage" and character.has_condition("raging"):
		if budget != null:
			budget.spend("bonus_action")
		BarbarianRules.maintain_rage(character)
		return {"success": true, "rage_extended": true, "results": [{"message": "%s extends Rage." % character.character_name}]}

	# Check if the character has uses remaining
	if sorcery_incarnate_reactivation and budget != null and not budget.can_spend(str(feature.get("action_cost", "action"))):
		return {"success": false, "message": "No Bonus Action is available to reactivate Innate Sorcery."}
	var pool_activation: Dictionary = {}
	if sorcery_incarnate_reactivation:
		character.spend_sorcery_points(2)
		if budget != null:
			budget.spend(str(feature.get("action_cost", "action")))
	elif feature.has("resource_pool"):
		pool_activation = ResourcePoolRules.begin_dice_activation(character, exact_source_id, selected_pool_quantity) if feature["resource_pool"].has("die_size") else ResourcePoolRules.spend(character, exact_source_id, int(feature.get("resource_cost", 1)))
		if not pool_activation.get("success", false):
			return {"success": false, "message": str(pool_activation.get("message", "No uses remaining for %s!" % feature_name))}
	elif not character.use_feature(feature_id):
		return {"success": false, "message": "No uses remaining for %s!" % feature_name}
	if budget != null and not sorcery_incarnate_reactivation:
		budget.spend(str(feature.get("action_cost", "action")))

	var effects: Array = feature.get("effects", [])
	var results: Array[Dictionary] = []

	for effect in effects:
		var result: Dictionary
		if str(effect.get("type", "")) == "timed_protection":
			var protection := ProtectionRules.grant(character,feature,exact_source_id,effect)
			result={"type":"timed_protection","grant":protection,"message":"%s gains %s until campaign second %d." % [character.character_name,feature_name,int(protection.expires_at_seconds)]}
		elif str(effect.get("type", "")) == "timed_numeric_modifier":
			var cooldown_seconds := int(effect.get("cooldown_seconds", 0))
			var grant := character.add_campaign_modifier(str(effect["kind"]), str(effect["key"]), int(effect["amount"]), int(effect["duration_seconds"]), cooldown_seconds, exact_source_id)
			var cooldown_message := "; this source then waits %d seconds before reuse" % cooldown_seconds if cooldown_seconds > 0 else ""
			result = {"type": "timed_numeric_modifier", "source_instance_id": exact_source_id, "grant_instance_id": grant.get("grant_instance_id", ""), "expires_at_seconds": grant.get("expires_at_seconds", 0), "cooldown_seconds": grant.get("cooldown_seconds", 0), "message": "%s gains %s %d for %d campaign seconds%s." % [character.character_name, str(effect["key"]), int(effect["amount"]), int(effect["duration_seconds"]), cooldown_message]} if grant.get("success", false) else {}
		elif str(effect.get("type", "")) == "next_matching_melee_hit":
			var next_grant := character.add_next_melee_hit_grant(int(effect["amount"]), str(effect["damage_type"]), int(effect["duration_seconds"]), exact_source_id)
			result = {"type": "next_matching_melee_hit", "source_instance_id": exact_source_id, "grant_instance_id": next_grant.get("grant_instance_id", ""), "expires_at_seconds": next_grant.get("expires_at_seconds", 0), "message": "%s prepares +%d %s damage for their next melee weapon hit." % [character.character_name, int(effect["amount"]), str(effect["damage_type"]).capitalize()]} if next_grant.get("success", false) else {}
		elif str(effect.get("type", "")) == "timed_temporary_hp":
			var temporary_hp_grant := character.offer_timed_temporary_hp(int(effect["amount"]), int(effect["duration_seconds"]), exact_source_id)
			result = {"type": "timed_temporary_hp", "source_instance_id": exact_source_id, "grant_instance_id": str(temporary_hp_grant.get("grant", {}).get("grant_instance_id", "")), "expires_at_seconds": int(temporary_hp_grant.get("grant", {}).get("expires_at_seconds", 0)), "accepted": bool(temporary_hp_grant.get("accepted", false)), "message": str(temporary_hp_grant.get("message", ""))} if temporary_hp_grant.get("success", false) else {}
		elif str(effect.get("type", "")) == "heal_by_pool_rolls":
			var pool_state: Dictionary = character.numeric_resource_pools.get(exact_source_id, {})
			var captured: Array = pool_activation.get("captured_dice", [])
			var rolls: Array = []
			if pool_state.has("capture_policy"):
				for die in captured: rolls.append(int(die.face))
			else:
				rolls = Dice.roll_multiple(selected_pool_quantity, int(pool_state.get("die_size", 0)), character)
			var total := 0
			for roll in rolls:
				total += roll
			var healing_result := EventResolver._apply_single_effect(character, {"type": "heal", "value": str(total)})
			result = {
				"type": "heal",
				"rolls": rolls,
				"captured_dice": captured.duplicate(true),
				"die_size": int(pool_state.get("die_size", 0)),
				"total": total,
				"amount": int(healing_result.get("amount", 0)),
				"owner_id": str(pool_activation.get("owner_id", character.character_id)),
				"source_instance_id": exact_source_id,
				"activation_id": str(pool_activation.get("activation_id", "")),
				"message": "%s rolls %s for %d healing and restores %d HP." % [character.character_name, str(rolls), total, int(healing_result.get("amount", 0))],
			}
		else:
			result = _resolve_feature_effect(character, effect, target)
		if not result.is_empty():
			results.append(result)
	if feature_id == "barbarian_rage":
		BarbarianRules.start_rage(character)

	return {
		"success": true,
		"feature_name": feature_name,
		"results": results,
		"message": "%s used %s%s!" % [character.character_name, feature_name, " for 2 Sorcery Points" if sorcery_incarnate_reactivation else ""],
	}


## Resolve a single feature effect.
static func _resolve_feature_effect(character: Character, effect: Dictionary, target) -> Dictionary:
	var effect_type: String = effect.get("type", "")

	match effect_type:
		"grant_extra_action":
			return {"type": "extra_action", "message": "%s gains an extra action!" % character.character_name}

		_:
			# Pass through to EventResolver for common effects
			return EventResolver._apply_single_effect(character, effect)


## Omitted event filters are unrestricted; present filters must be meaningful.
static func ability_check_filter_error(effect: Dictionary) -> String:
	for field in ["task_id", "purpose_id", "source_event_id", "source_check_id"]:
		if not effect.has(field): continue
		var value: Variant = effect[field]
		if not value is String or str(value).strip_edges().is_empty():
			return "Ability-check filters must be nonempty strings when declared"
		if field != "source_event_id" and not str(value).is_valid_identifier():
			return "Ability-check task, purpose and check filters must be identifiers"
	return ""
