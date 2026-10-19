## One combat-local allocation. Only completed pool/HP changes persist.
class_name PartyAllocationRules
extends RefCounted

var _pending: Dictionary = {}
var _serial := 0

static func content_error(feature: Dictionary) -> String:
	if feature.get("executor") != "class_feature" or feature.get("type") != "active" or feature.get("target") != "self" or feature.get("action_cost") not in ["action", "bonus_action", "free"]: return "Allocation requires an active common self feature."
	for field in ["uses", "uses_per", "resource_id", "resource_cost", "resource_exchange", "transfer_grant", "roll_intervention"]:
		if feature.has(field): return "Allocation uses its own source pool only."
	if not feature.get("effects", []) is Array or not feature.get("effects", []).is_empty() or not feature.get("passive_effects", []) is Array or not feature.get("passive_effects", []).is_empty(): return "Allocation cannot combine effects."
	var error := ResourcePoolRules.definition_error(feature)
	if not error.is_empty(): return error
	var spec: Variant = feature.get("allocation")
	if not spec is Dictionary: return "Allocation must be an object."
	for key in spec:
		if key not in ["mode", "effect", "total_formula", "die_size", "max_recipients", "per_target_cap", "unspent_policy", "cancel_policy"]: return "Unknown allocation field."
	if spec.get("effect") not in ["heal", "temporary_hp"] or spec.get("unspent_policy") not in ["forfeit", "retain_unselected_dice", "require_full"] or not ResourcePoolRules._integer(spec.get("max_recipients"), 1, 4) or not ResourcePoolRules._integer(spec.get("per_target_cap"), 1, 100): return "Allocation needs bounded recipients, cap, effect and remainder policy."
	if spec.get("mode") == "captured_dice" and spec.unspent_policy == "forfeit" or spec.get("mode") != "captured_dice" and spec.unspent_policy == "retain_unselected_dice": return "Remainder policy must match the allocation budget kind."
	match spec.get("mode"):
		"fixed_total":
			if feature.resource_pool.has("die_size") or spec.has("die_size") or spec.get("cancel_policy") != "no_payment" or not spec.has("total_formula"): return "Fixed allocation needs an actor formula and no-payment cancel."
			if not SharedStepExecutor.formula_content_error(spec.total_formula).is_empty() or not ResourcePoolRules._actor_formula_error(spec.total_formula).is_empty(): return "Unsupported allocation formula."
		"rolled_total":
			if feature.resource_pool.has("die_size") or spec.has("total_formula") or not ResourcePoolRules._integer(spec.get("die_size"), 1, 20) or int(spec.die_size) not in ResourcePoolRules.SUPPORTED_DIE_SIZES or spec.get("cancel_policy") != "forfeit": return "Rolled allocation pays on reveal and forfeits on cancel."
		"captured_dice":
			if feature.resource_pool.get("capture_policy") != "on_acquire" or spec.has("die_size") or spec.has("total_formula") or spec.get("cancel_policy") != "no_payment": return "Dice allocation requires retained owned dice and no-payment cancel."
		_: return "Unknown allocation mode."
	return ""

static func availability(actor: Character, feature: Dictionary, budget: CombatTurnBudget, source: String) -> Dictionary:
	var error := content_error(feature)
	if actor == null or actor.get_feature(str(feature.get("id", ""))) != feature: error = "Allocation is not owned."
	if error.is_empty() and (not actor.is_alive or actor.is_downed() or CombatAction.is_incapacitated(actor)): error = "Allocator cannot act."
	if error.is_empty() and (budget != null and not budget.can_spend(str(feature.action_cost))): error = "Allocator action is unavailable."
	if error.is_empty() and (int(ResourcePoolRules.availability(actor, source).get("spendable", 0)) < 1 or actor.numeric_resource_pools[source].definition_id != feature.resource_pool.id): error = "Exact allocation source is unavailable."
	if error.is_empty() and not str(feature.get("source_instance_id", source)).is_empty() and str(feature.get("source_instance_id", source)) != source: error = "Allocation belongs to another source."
	if error.is_empty() and feature.allocation.mode == "fixed_total":
		var total := SharedStepExecutor.evaluate_actor_formula(feature.allocation.total_formula, actor)
		if not total.get("success", false) or not ResourcePoolRules._integer(total.get("value"), 1, 100): error = "Allocation total is unavailable."
	return {"available":error.is_empty(), "reason":error, "action_cost":str(feature.get("action_cost", "action")), "remaining":int(ResourcePoolRules.availability(actor, source).get("current", 0)), "maximum":int(ResourcePoolRules.availability(actor, source).get("capacity", 0)), "cost":1}

static func eligible(actor: Character, recipient: Character) -> bool:
	return recipient == actor and actor.is_alive and not actor.is_downed() and not CombatAction.is_incapacitated(actor) or CapturedGrantRules.recipient_eligible(actor, recipient)

func clear() -> void:
	_pending = {}

func begin(actor: Character, feature_id: String, source: String, budget: CombatTurnBudget, recipients: Array) -> Dictionary:
	clear()
	var feature := actor.get_feature(feature_id) if actor != null else {}
	if budget == null or not availability(actor, feature, budget, source).available: return {}
	var offered: Array = []
	var ids: Array = []
	for recipient in recipients:
		if recipient is Character and eligible(actor, recipient) and recipient.character_id not in ids:
			offered.append(recipient)
			ids.append(recipient.character_id)
	if offered.is_empty(): return {}
	var spec: Dictionary = feature.allocation
	var total := 0
	var roll: Dictionary = {}
	if spec.mode == "fixed_total": total = int(SharedStepExecutor.evaluate_actor_formula(spec.total_formula, actor).value)
	if spec.mode == "rolled_total":
		if not ResourcePoolRules.spend(actor, source, 1).get("success", false): return {}
		budget.spend(str(feature.action_cost))
		roll = Dice.roll_single_details(int(spec.die_size), actor)
		total = int(roll.total)
	var pool: Dictionary = actor.numeric_resource_pools[source]
	if spec.mode == "captured_dice": total = mini(int(pool.current), int(feature.resource_pool.spend_choice.maximum))
	_serial += 1
	var id := "allocation:%d:%d" % [get_instance_id(), _serial]
	_pending = {"request_id":id, "actor":actor, "actor_id":actor.character_id, "feature":feature.duplicate(true), "source":source, "pool_ref":pool, "pool":pool.duplicate(true), "budget":budget, "budget_state":[budget.action_available,budget.bonus_action_available,budget.surge_actions], "recipients":offered, "recipient_ids":ids, "turn":CombatAction.active_turn_serial, "clock":int(GameManager.campaign_elapsed_seconds), "total":total, "roll":roll}
	return {"request_id":id, "recipient_ids":ids.duplicate(), "total":total, "spec":spec.duplicate(true), "dice":pool.get("captured_dice", []).duplicate(true), "roll":roll.duplicate(true)}

func settle(id: String, actor: Character, rows: Array, live: Array) -> Dictionary:
	if _pending.is_empty() or id != _pending.request_id or actor != _pending.actor: return {"success":false}
	var request := _pending
	clear()
	if rows.is_empty(): return {"success":true, "declined":true, "forfeited":request.feature.allocation.mode == "rolled_total", "total":request.total}
	var feature: Dictionary = request.feature
	var spec: Dictionary = feature.allocation
	if actor.character_id != request.actor_id or actor.get_feature(str(feature.id)) != feature or not actor.is_alive or actor.is_downed() or CombatAction.is_incapacitated(actor) or request.turn != CombatAction.active_turn_serial or request.clock != int(GameManager.campaign_elapsed_seconds) or not is_same(actor.numeric_resource_pools.get(request.source), request.pool_ref) or actor.numeric_resource_pools.get(request.source) != request.pool or request.budget_state != [request.budget.action_available,request.budget.bonus_action_available,request.budget.surge_actions] or rows.size() > int(spec.max_recipients): return {"success":false}
	if spec.mode != "rolled_total" and not availability(actor, feature, request.budget, request.source).available: return {"success":false}
	var recipients: Array = []
	var amounts: Array[int] = []
	var dice_ids: Array = []
	var used := 0
	for row in rows:
		if not row is Dictionary or row.size() != 2: return {"success":false}
		var index: int = request.recipient_ids.find(row.get("recipient_id"))
		if index < 0: return {"success":false}
		var recipient: Character = request.recipients[index]
		if recipient in recipients or recipient not in live or recipient.character_id != row.recipient_id or not eligible(actor, recipient): return {"success":false}
		var amount := 0
		if spec.mode == "captured_dice":
			var selected: Variant = row.get("dice_ids")
			if not selected is Array or selected.is_empty() or selected.size() > int(spec.per_target_cap): return {"success":false}
			for die_id in selected:
				if die_id in dice_ids: return {"success":false}
				var found := false
				for die in request.pool.captured_dice:
					if die.die_id == die_id:
						amount += int(die.face)
						found = true
				if not found: return {"success":false}
				dice_ids.append(die_id)
			used += selected.size()
		else:
			if not ResourcePoolRules._integer(row.get("amount"), 1, int(spec.per_target_cap)): return {"success":false}
			amount = int(row.amount)
			used += amount
		recipients.append(recipient)
		amounts.append(amount)
	if used > int(request.total) or (spec.unspent_policy == "require_full" and used != int(request.total)): return {"success":false}
	if spec.mode == "captured_dice" and used < int(feature.resource_pool.spend_choice.minimum): return {"success":false}
	# Every recipient, amount and identity validates before the one commit.
	if spec.mode != "rolled_total":
		var paid := ResourcePoolRules.spend_selected_dice(actor, request.source, dice_ids) if spec.mode == "captured_dice" else ResourcePoolRules.spend(actor, request.source, 1)
		if not paid.get("success", false): return {"success":false}
		request.budget.spend(str(feature.action_cost))
	var results: Array = []
	for index in recipients.size():
		var recipient: Character = recipients[index]
		var before := recipient.current_hp if spec.effect == "heal" else recipient.temp_hp
		if spec.effect == "heal": recipient.heal(amounts[index])
		else: recipient.temp_hp = maxi(recipient.temp_hp, amounts[index])
		results.append({"recipient_id":recipient.character_id, "allocated":amounts[index], "before":before, "after":recipient.current_hp if spec.effect == "heal" else recipient.temp_hp})
	return {"success":true, "total":request.total, "used":used, "unspent":int(request.total)-used, "roll":request.roll, "dice_ids":dice_ids, "results":results}
