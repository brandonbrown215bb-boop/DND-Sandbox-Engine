## Shared cast interruption, cancellation, stopping-cost policy and recipient negation rules (Batch 029: S-142, S-115, S-143, S-116).
class_name CastInterruptionRules
extends RefCounted

const STOPPING_SCOPES := ["whole_cast"]
const SETTLEMENT_POLICIES := ["commit", "refund"]
const ITEM_POLICIES := ["keep", "consume_charge", "dispose_copy"]
const CONTEST_TYPES := ["none", "save", "check"]
const SPELL_SCHOOLS := [
	"abjuration", "conjuration", "divination", "enchantment",
	"evocation", "illusion", "necromancy", "transmutation"
]
const SOURCE_KINDS := ["class", "book", "innate", "item", "ritual", "feature"]


# =========================================================================
# Schema and content validation
# =========================================================================

static func settlement_policy_error(policy: Variant) -> String:
	if policy is String:
		if str(policy) not in SETTLEMENT_POLICIES:
			return "Settlement policy must be 'commit' or 'refund'."
		return ""
	if not policy is Dictionary or policy.is_empty():
		return "Settlement policy must be a string or nonempty object."
	for key in policy:
		if key not in ["interruption", "failure", "empty_effect", "on_success", "on_failure", "on_interrupted", "on_negated"]:
			return "Settlement policy contains unsupported outcome '%s'." % str(key)
		if policy[key] is Dictionary and str(key).begins_with("on_"):
			for resource in policy[key]:
				if resource not in ["slot", "resource", "item", "free_cast"] or str(policy[key][resource]) not in SETTLEMENT_POLICIES:
					return "Unsupported cast settlement resource policy."
			continue
		if str(policy[key]) not in SETTLEMENT_POLICIES:
			return "Settlement policy for '%s' must be 'commit' or 'refund'." % str(key)
	return ""


static func cancellation_rule_error(rule: Variant) -> String:
	if not rule is Dictionary or rule.is_empty():
		return "Cancellation rule must be a nonempty object."
	for key in rule:
		if key not in ["target_scope", "min_spell_level", "max_spell_level", "spell_levels", "schools", "sources", "spell_ids", "contest", "stopping_cost_policy"]:
			return "Cancellation rule contains unsupported field '%s'." % str(key)
	if rule.has("target_scope") and str(rule["target_scope"]) != "whole_cast":
		return "cancellation_rule target_scope must be 'whole_cast'."
	var min_lvl := int(rule.get("min_spell_level", 0))
	var max_lvl := int(rule.get("max_spell_level", 9))
	if rule.has("min_spell_level") and not ResourcePoolRules._integer(rule["min_spell_level"], 0, 9):
		return "cancellation_rule min_spell_level must be an integer from 0 to 9."
	if rule.has("max_spell_level") and not ResourcePoolRules._integer(rule["max_spell_level"], 0, 9):
		return "cancellation_rule max_spell_level must be an integer from 0 to 9."
	if rule.has("min_spell_level") and rule.has("max_spell_level") and min_lvl > max_lvl:
		return "cancellation_rule min_spell_level cannot exceed max_spell_level."
	if rule.has("spell_levels"):
		if not rule["spell_levels"] is Array or rule["spell_levels"].is_empty():
			return "cancellation_rule spell_levels must be a nonempty array."
		for lvl in rule["spell_levels"]:
			if not ResourcePoolRules._integer(lvl, 0, 9):
				return "cancellation_rule spell_levels entries must be integers 0 to 9."
	if rule.has("schools"):
		if not rule["schools"] is Array or rule["schools"].is_empty():
			return "cancellation_rule schools must be a nonempty array."
		for s in rule["schools"]:
			if str(s).to_lower() not in SPELL_SCHOOLS:
				return "cancellation_rule contains unsupported school '%s'." % str(s)
	if rule.has("sources"):
		if not rule["sources"] is Array or rule["sources"].is_empty():
			return "cancellation_rule sources must be a nonempty array."
		for src in rule["sources"]:
			if str(src) not in SOURCE_KINDS:
				return "cancellation_rule contains unsupported source '%s'." % str(src)
	if rule.has("spell_ids"):
		if not rule["spell_ids"] is Array or rule["spell_ids"].is_empty():
			return "cancellation_rule spell_ids must be a nonempty array."
		for sid in rule["spell_ids"]:
			if not sid is String or str(sid).is_empty():
				return "cancellation_rule spell_ids entries must be nonempty strings."
	if rule.has("contest"):
		var c_err := _contest_error(rule["contest"])
		if not c_err.is_empty():
			return c_err
	if rule.has("stopping_cost_policy"):
		var p_err := stopping_cost_policy_error(rule["stopping_cost_policy"])
		if not p_err.is_empty():
			return p_err
	return ""


static func stopping_cost_policy_error(policy: Variant) -> String:
	if not policy is Dictionary or policy.is_empty():
		return "stopping_cost_policy must be a nonempty object."
	for key in policy:
		if key not in ["on_success", "on_failure"]:
			return "stopping_cost_policy contains unsupported branch '%s'." % str(key)
		var branch: Variant = policy[key]
		if not branch is Dictionary:
			return "stopping_cost_policy branch '%s' must be an object." % str(key)
		for item in branch:
			if item not in ["slot", "item", "reaction", "free_cast"]:
				return "stopping_cost_policy.%s contains unsupported field '%s'." % [str(key), str(item)]
			if item in ["slot", "reaction", "free_cast"] and str(branch[item]) not in SETTLEMENT_POLICIES:
				return "stopping_cost_policy.%s.%s must be 'commit' or 'refund'." % [str(key), str(item)]
			if item == "item" and str(branch[item]) not in ITEM_POLICIES:
				return "stopping_cost_policy.%s.item must be 'keep', 'consume_charge', or 'dispose_copy'." % str(key)
	return ""


static func incoming_negation_rule_error(rule: Variant) -> String:
	if not rule is Dictionary or rule.is_empty():
		return "incoming_negation_rule must be a nonempty object."
	for key in rule:
		if key not in ["target_scope", "min_spell_level", "max_spell_level", "spell_levels", "schools", "spell_ids", "step_types", "negate_payload"]:
			return "incoming_negation_rule contains unsupported field '%s'." % str(key)
	if rule.has("negate_payload") and not rule.negate_payload is bool: return "negate_payload must be a boolean."
	if rule.has("target_scope") and str(rule["target_scope"]) != "recipient_effect":
		return "incoming_negation_rule target_scope must be 'recipient_effect'."
	if rule.has("min_spell_level") and not ResourcePoolRules._integer(rule["min_spell_level"], 0, 9):
		return "incoming_negation_rule min_spell_level must be an integer from 0 to 9."
	if rule.has("max_spell_level") and not ResourcePoolRules._integer(rule["max_spell_level"], 0, 9):
		return "incoming_negation_rule max_spell_level must be an integer from 0 to 9."
	if rule.has("min_spell_level") and rule.has("max_spell_level") and int(rule["min_spell_level"]) > int(rule["max_spell_level"]):
		return "incoming_negation_rule min_spell_level cannot exceed max_spell_level."
	if rule.has("spell_levels"):
		if not rule["spell_levels"] is Array or rule["spell_levels"].is_empty():
			return "incoming_negation_rule spell_levels must be a nonempty array."
		for lvl in rule["spell_levels"]:
			if not ResourcePoolRules._integer(lvl, 0, 9):
				return "incoming_negation_rule spell_levels entries must be integers 0 to 9."
	if rule.has("schools"):
		if not rule["schools"] is Array or rule["schools"].is_empty():
			return "incoming_negation_rule schools must be a nonempty array."
		for s in rule["schools"]:
			if str(s).to_lower() not in SPELL_SCHOOLS:
				return "incoming_negation_rule contains unsupported school '%s'." % str(s)
	if rule.has("spell_ids"):
		if not rule["spell_ids"] is Array or rule["spell_ids"].is_empty():
			return "incoming_negation_rule spell_ids must be a nonempty array."
		for sid in rule["spell_ids"]:
			if not sid is String or str(sid).is_empty():
				return "incoming_negation_rule spell_ids entries must be nonempty strings."
	if rule.has("step_types"):
		if not rule["step_types"] is Array or rule["step_types"].is_empty():
			return "incoming_negation_rule step_types must be a nonempty array."
		for st in rule["step_types"]:
			if str(st) not in ["attack", "save", "damage", "effect"]:
				return "incoming_negation_rule contains unsupported step_type '%s'." % str(st)
	return ""


static func _contest_error(contest: Variant) -> String:
	if not contest is Dictionary or contest.is_empty():
		return "Contest must be a nonempty object."
	for key in contest:
		if key not in ["type", "ability", "dc", "dc_from", "formula"]:
			return "Contest contains unsupported field '%s'." % str(key)
	var type_str := str(contest.get("type", "none"))
	if type_str not in CONTEST_TYPES:
		return "Contest type must be 'none', 'save', or 'check'."
	if type_str in ["save", "check"]:
		var ability_str := str(contest.get("ability", "")).to_upper()
		if ability_str not in AbilityScores.ABILITIES and ability_str != "SPELLCASTING":
			return "Contest requires a valid ability."
	if contest.has("dc") and not ResourcePoolRules._integer(contest["dc"], 0, 99):
		return "Contest DC must be an integer from 0 to 99."
	if contest.has("dc_from") and str(contest["dc_from"]) not in ["stopping_caster", "caster"]:
		return "Contest dc_from must be 'stopping_caster' or 'caster'."
	if contest.has("formula") and str(contest["formula"]) not in ["10_plus_level"]:
		return "Unsupported contest formula."
	return ""


# =========================================================================
# S-142: Interruption/Failure Reserve and Refund (V-031)
# =========================================================================

## Capture only a real payment receipt. An unpaid resolver call must never mint resources.
static func reserve_cast_payment(cast: SpellResolutionContext, _spell_selection: Dictionary = {}) -> void:
	if cast == null:
		return
	if cast.spatial_host != null and not cast.spatial_host.payment_receipt.is_empty():
		cast.decisions["cast_payment_receipt"] = cast.spatial_host.payment_receipt
		return
	var receipt: Dictionary = {}
	if cast.incoming_slot_spent:
		receipt = {"kind":"slot", "source_id":cast.incoming_slot_pool_id, "amount":int(cast.incoming_slot_key), "spell_id":cast.spell_definition_id}
	elif cast.spatial_host != null:
		receipt = cast.spatial_host.payment_receipt
	cast.decisions["cast_payment_receipt"] = receipt
	cast.decisions["incoming_payment_kind"] = str(receipt.get("kind", ""))


static func payment_receipt(caster: Character, selection: Dictionary, slot_result: Dictionary = {}, paid_permission: Dictionary = {}) -> Dictionary:
	var kind := str(selection.get("_spell_payment_kind", "slot" if not slot_result.is_empty() else ""))
	var permission := paid_permission if not paid_permission.is_empty() else SpellPermissionRules.selected_permission(caster, selection)
	var source_id := str(selection.get("_spell_payment_source_id", ""))
	var amount := 1
	if kind == "slot":
		if bool(slot_result.get("slot_recalled", false)): return {}
		source_id = str(slot_result.get("slot_pool_id", selection.get("_spell_slot_pool_id", "ordinary")))
		amount = int(slot_result.get("slot_level", selection.get("_selected_spell_slot_level", selection.get("level", 0))))
	elif kind == "item_charges":
		amount = int(permission.get("charge_cost", 0))
	elif kind == "points":
		source_id = str(permission.get("point_payment", {}).get("resource_id", ""))
		amount = SpellPermissionRules.point_payment_cost(permission, int(selection.get("level", 0)))
	if kind.is_empty() or amount <= 0: return {}
	return {"kind":kind,"source_id":source_id,"amount":amount,"spell_id":str(selection.get("id", "")),"permission_kind":str(permission.get("kind", "")), "settled":false}


static func refund_cast_payment(cast: SpellResolutionContext, reason: String = "") -> Dictionary:
	if cast == null or cast.caster == null:
		return {"refunded": false, "reason": "no_caster"}
	var payment: Dictionary = cast.decisions.get("cast_payment_receipt", {})
	if payment.is_empty() or bool(payment.get("settled", false)):
		return {"refunded": false, "reason": "unpaid_or_already_settled"}
	var kind := str(payment.get("kind", ""))
	var source_id := str(payment.get("source_id", ""))
	var amount := int(payment.get("amount", 0))
	var refunded := false
	match kind:
		"slot":
			SpellSlotRules.restore(cast.caster, source_id, amount)
			cast.incoming_slot_spent = false
			if cast.spatial_host != null: cast.spatial_host.incoming_slot_spent = false
			refunded = true
		"free_cast":
			if source_id == "warlock_mystic_arcanum":
				for level in cast.caster.warlock_mystic_arcanum:
					if cast.caster.warlock_mystic_arcanum[level] == payment.spell_id:
						cast.caster.warlock_arcanum_uses[str(level)] = 1
						refunded = true
			else:
				refunded = cast.caster.restore_free_spell_cast(str(payment.spell_id), source_id)
		"item_charges":
			var copy := cast.caster.inventory.get_instance(source_id)
			if not copy.is_empty() and amount > 0:
				copy.state.charges = int(copy.state.get("charges", 0)) + amount
				cast.caster.inventory.copies.records[source_id] = copy
				refunded = true
		"points":
			if not source_id.is_empty() and amount > 0:
				cast.caster.feature_uses[source_id] = int(cast.caster.feature_uses.get(source_id, 0)) + amount
				refunded = true
	payment["settled"] = true
	payment["refunded"] = refunded
	cast.decisions["incoming_payment_refunded"] = refunded
	return {"refunded":refunded,"kind":kind,"source_id":source_id,"amount":amount,"reason":reason}


static func commit_cast_payment(cast: SpellResolutionContext) -> Dictionary:
	if cast == null: return {"committed":false}
	var payment: Dictionary = cast.decisions.get("cast_payment_receipt", {})
	if bool(payment.get("settled", false)): return {"committed":false,"reason":"already_settled"}
	payment["settled"] = true
	return {"committed":true,"slot_spent":cast.incoming_slot_spent}


static func settle_cast_outcome(cast: SpellResolutionContext, outcome: String) -> Dictionary:
	if cast == null: return {"settled":false}
	var policy_decl: Variant = cast.spell.get("cast_settlement", null)
	var policy_str := "commit"
	if policy_decl is String:
		policy_str = policy_decl
	elif policy_decl is Dictionary:
		var key: String = {"interrupted":"on_interrupted","countered":"on_interrupted","failed":"on_failure","negated":"on_negated","success":"on_success"}.get(outcome, outcome)
		var branch: Variant = policy_decl.get(key, policy_decl.get({"interrupted":"interruption","failed":"failure"}.get(outcome, outcome), "commit"))
		if branch is Dictionary:
			var kind := str(cast.decisions.get("cast_payment_receipt", {}).get("kind", ""))
			var resource_key: String = {"points":"resource","item_charges":"item"}.get(kind, kind)
			policy_str = str(branch.get(resource_key, "commit"))
		else: policy_str = str(branch)
	else:
		match outcome:
			"interrupted", "countered": policy_str = str(cast.spell.get("interruption_policy", "commit"))
			"failed": policy_str = str(cast.spell.get("failure_policy", "commit"))
			"empty_effect": policy_str = str(cast.spell.get("empty_effect_policy", "commit"))
	var result := refund_cast_payment(cast, outcome) if policy_str == "refund" else commit_cast_payment(cast)
	result.merge({"outcome":outcome,"policy":policy_str}, true)
	return result


static func result_outcome(spell: Dictionary, result: Dictionary) -> String:
	if bool(result.get("countered", false)): return "interrupted"
	if not bool(result.get("success", true)): return "failed"
	if bool(result.get("recipient_negated", false)): return "negated"
	if not spell.has("steps") and not spell.has("damage") and not spell.has("save") and spell.get("attack_type", "none") == "none" and spell.get("damage_components", []).is_empty() and spell.get("effects", []).is_empty(): return "empty_effect"
	return "success"


static func observe_host_result(cast: SpellCastContext, result: Dictionary) -> void:
	if cast.payment_receipt.is_empty(): return
	var outcomes: Array = cast.payment_receipt.get("outcomes", [])
	outcomes.append(result_outcome(cast.spell, result))
	cast.payment_receipt["outcomes"] = outcomes


static func settle_host(cast: SpellCastContext) -> void:
	if cast.payment_receipt.is_empty() or bool(cast.payment_receipt.get("settled", false)): return
	var context := SpellResolutionContext.new()
	context.caster = cast.caster
	context.spell = cast.spell
	context.spatial_host = cast
	context.incoming_slot_spent = cast.incoming_slot_spent
	context.decisions["cast_payment_receipt"] = cast.payment_receipt
	var outcomes: Array = cast.payment_receipt.get("outcomes", [])
	var outcome := "empty_effect"
	if "success" in outcomes: outcome = "success"
	elif "failed" in outcomes or cast.interrupted: outcome = "failed"
	elif "negated" in outcomes: outcome = "negated"
	elif cast.successful: outcome = result_outcome(cast.spell, {"success":true})
	settle_cast_outcome(context, outcome)


# =========================================================================
# S-115: Whole Pending Cast Cancellation (V-019)
# =========================================================================

static func is_cast_matching_cancellation(cast: SpellResolutionContext, rule: Dictionary) -> Dictionary:
	if cast == null or rule.is_empty():
		return {"matches": false, "reason": "empty_cast_or_rule"}
	var effective_level: int = cast.slot_level if cast.slot_level > 0 else int(cast.spell.get("level", 0))
	if rule.has("min_spell_level") and effective_level < int(rule["min_spell_level"]):
		return {"matches": false, "reason": "level_below_minimum", "level": effective_level, "min": rule["min_spell_level"]}
	if rule.has("max_spell_level") and effective_level > int(rule["max_spell_level"]):
		return {"matches": false, "reason": "level_above_maximum", "level": effective_level, "max": rule["max_spell_level"]}
	if rule.has("spell_levels"):
		var levels: Array = rule["spell_levels"]
		if not (effective_level in levels):
			return {"matches": false, "reason": "level_not_in_allowed_list", "level": effective_level, "allowed": levels}
	if rule.has("schools"):
		var spell_school := str(cast.spell.get("school", "")).to_lower()
		var allowed_schools: Array = rule["schools"]
		if spell_school.is_empty() or not allowed_schools.any(func(s): return str(s).to_lower() == spell_school):
			return {"matches": false, "reason": "school_mismatch", "school": spell_school, "allowed": allowed_schools}
	if rule.has("spell_ids"):
		var allowed_ids: Array = rule["spell_ids"]
		if not (cast.spell_definition_id in allowed_ids):
			return {"matches": false, "reason": "spell_id_mismatch", "spell_id": cast.spell_definition_id, "allowed": allowed_ids}
	if rule.has("sources"):
		var allowed_sources: Array = rule["sources"]
		var permission := SpellPermissionRules.selected_permission(cast.caster, cast.spell) if cast.caster != null else {}
		var spell_source := str(cast.decisions.get("cast_payment_receipt", {}).get("permission_kind", permission.get("kind", ""))).to_lower()
		if not allowed_sources.has(spell_source):
			return {"matches": false, "reason": "source_mismatch", "source": spell_source, "allowed": allowed_sources}
	return {"matches": true}


static func resolve_cancellation(cast: SpellResolutionContext) -> Dictionary:
	if cast == null or cast.spell.is_empty():
		return {}
	if bool(cast.spell.get("_skip_counterspell", false)):
		return {}
	var observers: Array = []
	for obs in cast.observers:
		if obs is Character and obs not in observers:
			observers.append(obs)
	for observer in observers:
		if not observer.reaction_available:
			continue
		var observer_name: String = observer.character_name
		var decision_key := "counterspell:%s" % observer_name
		var stopping_key := "stopping_spell:%s" % observer_name
		var is_counterspell := bool(cast.decisions.get(decision_key, cast.decisions.get("counterspell", false)))
		var is_custom_stopping := cast.decisions.has(stopping_key)
		if not is_counterspell and not is_custom_stopping:
			continue
		var stopping_spell: Dictionary = {}
		if is_custom_stopping:
			var custom_val = cast.decisions[stopping_key]
			if custom_val is Dictionary:
				stopping_spell = DataLoader.get_spell(str(custom_val.get("id", "")))
			elif custom_val is String:
				stopping_spell = DataLoader.get_spell(custom_val)
		elif is_counterspell:
			stopping_spell = DataLoader.get_spell("counterspell")
			if not SpellSupport.is_available(stopping_spell):
				continue
			var spell_components: Array = cast.spell.get("components", [])
			if spell_components.is_empty() or not spell_components.any(func(component): return str(component) in ["V", "S", "M"]):
				continue
		if stopping_spell.is_empty() or (not stopping_spell.has("cancellation_rule") and stopping_spell.get("id", "") != "counterspell") or stopping_spell.get("casting_time", "") != "reaction":
			continue
		var cancellation_rule: Dictionary = stopping_spell.get("cancellation_rule", {})
		if not cancellation_rule.is_empty():
			var match_check := is_cast_matching_cancellation(cast, cancellation_rule)
			if not bool(match_check.get("matches", false)):
				continue
		var payment := SpellPermissionRules.spend_reaction(observer, str(stopping_spell.get("id", "counterspell")), cast.decisions)
		if payment.is_empty():
			continue
		stopping_spell = payment.spell
		var stopping_dc := SpellPermissionRules.save_dc(observer, payment.get("spell", stopping_spell))
		var contest_rule: Dictionary = cancellation_rule.get("contest", {"type": "save", "ability": "CON", "dc_from": "stopping_caster"})
		var contest_type: String = str(contest_rule.get("type", "save"))
		var stopped := false
		var save_total := 0
		var check_total := 0
		var contest_dc := stopping_dc
		if contest_type == "none":
			stopped = true
		elif contest_type == "save":
			var ability := str(contest_rule.get("ability", "CON")).to_upper()
			if ability == "SPELLCASTING": ability = cast.caster.get_spellcasting_ability()
			var dc := SpellPermissionRules.save_dc(cast.caster, cast.spell) if contest_rule.get("dc_from", "stopping_caster") == "caster" else stopping_dc
			if contest_rule.has("dc"):
				dc = int(contest_rule["dc"])
			contest_dc = dc
			save_total = int(cast.caster.saving_throw_test_to_dc(ability, dc, false, false, cast.decisions).get("total", 0))
			stopped = save_total < dc
			cast.decisions["counterspell_save_total"] = save_total
			cast.decisions["counterspell_save_dc"] = dc
			if not stopped:
				cast.decisions["counterspell_saved_by"] = observer_name
		elif contest_type == "check":
			var ability := str(contest_rule.get("ability", "spellcasting")).to_upper()
			if ability == "SPELLCASTING": ability = SpellPermissionRules.selected_ability(stopping_spell, observer.get_spellcasting_ability())
			var dc := int(contest_rule.get("dc", 10 + cast.slot_level))
			contest_dc = dc
			check_total = int(observer.ability_check_test(ability, false, false, cast.decisions).get("total", 0))
			stopped = check_total >= dc
			cast.decisions["stopping_check_total"] = check_total
			cast.decisions["stopping_check_dc"] = dc
		settle_stopping_costs(observer, stopping_spell, stopped, payment, cast.decisions)
		if stopped:
			cast.interrupted = true
			cast.canceled = true
			cast.decisions["canceled"] = true
			var counterspell_slot_default: bool = stopping_spell.get("id", "") == "counterspell" and not cast.spell.has("interruption_policy") and not cast.spell.has("cast_settlement") and cast.decisions.get("cast_payment_receipt", {}).get("kind", "") == "slot"
			var target_settlement := refund_cast_payment(cast, "counterspell") if counterspell_slot_default else settle_cast_outcome(cast, "interrupted")
			return {
				"success": false,
				"countered": true,
				"canceled": true,
				"counterspell_save_total": save_total,
				"counterspell_save_dc": contest_dc,
				"stopping_check_total": check_total,
				"stopping_check_dc": contest_dc if contest_type == "check" else 0,
				"incoming_spell_slot_refunded": bool(target_settlement.get("refunded", false)),
				"stopped_by": observer_name,
				"message": "[color=cyan]%s casts %s; the spell is interrupted and dissipates.[/color]" % [observer_name, stopping_spell.get("name", "Counterspell")]
			}
	return {}


# =========================================================================
# S-143: Stopping-Spell Cost Policy (V-031)
# =========================================================================

static func settle_stopping_costs(stopping_actor: Character, stopping_spell: Dictionary, stopping_succeeded: bool, payment_receipt: Dictionary = {}, decisions: Dictionary = {}) -> Dictionary:
	if stopping_actor == null:
		return {"settled": false}
	var policy: Dictionary = stopping_spell.get("stopping_cost_policy", stopping_spell.get("cancellation_rule", {}).get("stopping_cost_policy", {}))
	var branch: Dictionary = policy.get("on_success", {}) if stopping_succeeded else policy.get("on_failure", {})
	var result := {
		"settled": true,
		"stopping_succeeded": stopping_succeeded,
		"slot_refunded": false,
		"reaction_refunded": false,
		"item_disposed": false
	}
	var paid: Dictionary = payment_receipt.get("payment", {})
	if bool(paid.get("settled", false)): return {"settled":false,"reason":"already_settled"}
	var kind := str(paid.get("kind", ""))
	var refund_key: String = {"item_charges":"item","points":"resource"}.get(kind, kind)
	var refund := str(branch.get(refund_key, "commit")) in ["refund", "keep"]
	if refund:
		var context := SpellResolutionContext.new()
		context.caster = stopping_actor
		context.decisions["cast_payment_receipt"] = paid
		var receipt := refund_cast_payment(context, "stopping_success" if stopping_succeeded else "stopping_failure")
		result["slot_refunded"] = kind == "slot" and bool(receipt.get("refunded", false))
		result["free_cast_refunded"] = kind == "free_cast" and bool(receipt.get("refunded", false))
	else:
		paid["settled"] = true
	if str(branch.get("reaction", "commit")) == "refund" and bool(payment_receipt.get("reaction_spent", false)):
		stopping_actor.reaction_available = true
		result["reaction_refunded"] = true
	if str(branch.get("item", "keep")) == "dispose_copy" and kind == "item_charges":
		var instance_id := str(paid.get("source_id", ""))
		if not instance_id.is_empty() and not stopping_actor.inventory.get_instance(instance_id).is_empty():
			var disposed := stopping_actor.inventory.destroy_instance(instance_id)
			result["item_disposed"] = not disposed.is_empty()
			result["instance_id"] = instance_id

	return result


# =========================================================================
# S-116: One Recipient's Incoming Effect Negation (V-019)
# =========================================================================

static func is_recipient_negated(cast: SpellResolutionContext, recipient: Variant, step: Dictionary = {}) -> bool:
	if cast == null or recipient == null:
		return false
	for declared_rule in [cast.spell.get("incoming_negation_rule", {}), step.get("incoming_negation_rule", {})]:
		if declared_rule is Dictionary and not declared_rule.is_empty() and _matches_negation_predicates(cast, declared_rule, step): return true
	var recipient_id := SpellEffects.caster_id(recipient) if recipient is Character else str(recipient.get("id", ""))
	var negations: Dictionary = cast.decisions.get("recipient_effect_negations", {})
	if negations.has(recipient_id):
		var rule: Variant = negations[recipient_id]
		if rule is bool and bool(rule):
			return true
		elif rule is Dictionary and _matches_negation_predicates(cast, rule, step):
			return true
	if recipient is Character:
		for effect in ClassProgression.selected_feature_effects_of_type(recipient, "incoming_spell_negation"):
			if _matches_negation_predicates(cast, effect, step):
				return true
		for copy_id in recipient.inventory.copies.equipped.values():
			if ActorProjectionRules.merged(recipient, str(copy_id)): continue # Review 041 R2.
			var copy: Dictionary = recipient.inventory.copies.records.get(copy_id, {})
			var item_data := DataLoader.get_item(str(copy.get("definition_id", "")))
			if item_data.has("incoming_negation_rule"):
				if _matches_negation_predicates(cast, item_data["incoming_negation_rule"], step):
					return true
	return false


static func _matches_negation_predicates(cast: SpellResolutionContext, rule: Dictionary, step: Dictionary = {}) -> bool:
	if not bool(rule.get("negate_payload", true)): return false
	var effective_level: int = cast.slot_level if cast.slot_level > 0 else int(cast.spell.get("level", 0))
	if rule.has("min_spell_level") and effective_level < int(rule["min_spell_level"]):
		return false
	if rule.has("max_spell_level") and effective_level > int(rule["max_spell_level"]):
		return false
	if rule.has("spell_levels"):
		var levels: Array = rule["spell_levels"]
		if not (effective_level in levels):
			return false
	if rule.has("schools"):
		var school := str(cast.spell.get("school", "")).to_lower()
		var allowed: Array = rule["schools"]
		if school.is_empty() or not allowed.any(func(s): return str(s).to_lower() == school):
			return false
	if rule.has("spell_ids"):
		var allowed_ids: Array = rule["spell_ids"]
		if not (cast.spell_definition_id in allowed_ids):
			return false
	if rule.has("step_types"):
		var step_type := str(step.get("type", ""))
		var allowed_steps: Array = rule["step_types"]
		if not (step_type in allowed_steps):
			return false
	return true


static func create_negated_result(cast: SpellResolutionContext, recipient: Variant) -> Dictionary:
	var target_name: String = recipient.character_name if recipient is Character else str(recipient.get("name", "The target"))
	return {
		"success": true,
		"hit": false,
		"damage": 0,
		"negated": true,
		"recipient_negated": true,
		"slot_level": cast.slot_level,
		"message": "%s negates the incoming spell effect." % target_name
	}
