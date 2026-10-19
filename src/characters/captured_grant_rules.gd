## Captured, independently expiring gifts. Requests belong to one combat host;
## only the resulting recipient records and giver serial survive checkpoints.
class_name CapturedGrantRules
extends RefCounted

var _pending: Dictionary = {}
var _serial := 0

static func content_error(feature: Dictionary) -> String:
	if feature.get("executor") != "class_feature" or feature.get("type") != "active" or feature.get("target") != "self": return "Transfer requires an active common feature."
	if feature.get("action_cost") not in ["action", "bonus_action", "free"]: return "Unsupported transfer action."
	for field in ["resource_id", "resource_exchange", "uses", "uses_per", "resource_cost"]:
		if feature.has(field): return "Transfer uses exactly one of its own pool quantities."
	if not feature.get("effects", []) is Array or not feature.get("effects", []).is_empty() or not feature.get("passive_effects", []) is Array or not feature.get("passive_effects", []).is_empty(): return "Transfer cannot combine additional effects."
	var error := ResourcePoolRules.definition_error(feature)
	if not error.is_empty(): return error
	var spec: Variant = feature.get("transfer_grant")
	if not spec is Dictionary: return "Transfer grant must be an object."
	for key in spec:
		if key not in ["kind", "value_policy", "amount_formula", "die_size", "effect", "use_cost", "duration_seconds", "max_recipients"]: return "Unknown transfer field."
	if spec.get("kind") not in ["die", "token", "permission"] or spec.get("effect") not in ["heal_self", "temporary_hp", "weapon_attack_bonus"] or spec.get("use_cost") not in ["action", "bonus_action", "reaction"]: return "Unsupported captured grant kind, effect or recipient budget."
	if not ResourcePoolRules._integer(spec.get("duration_seconds"), 1, 86400) or not ResourcePoolRules._integer(spec.get("max_recipients"), 1, 4): return "Transfer requires bounded duration and recipients."
	if spec.effect == "weapon_attack_bonus" and (spec.get("value_policy") != "shared_roll" or spec.use_cost != "reaction"): return "Captured attack bonus requires a shared roll and recipient Reaction."
	var policy := str(spec.get("value_policy", ""))
	var pool: Dictionary = feature.resource_pool
	match policy:
		"pool_die":
			if spec.kind != "die" or int(spec.max_recipients) != 1 or pool.get("capture_policy") != "on_acquire" or int(pool.spend_choice.minimum) != 1 or int(pool.spend_choice.maximum) != 1 or spec.has("amount_formula") or spec.has("die_size"): return "An exact captured pool die transfers to one recipient."
		"shared_roll":
			if spec.kind != "die" or pool.has("die_size") or (not ResourcePoolRules._integer(spec.get("die_size"), 1, 20) or int(spec.die_size) not in ResourcePoolRules.SUPPORTED_DIE_SIZES) or spec.has("amount_formula"): return "Shared gifts roll one supported die from a numeric pool."
		"formula":
			if spec.kind not in ["token", "permission"] or pool.has("die_size") or spec.has("die_size") or not spec.has("amount_formula"): return "Token/permission gifts capture an actor formula."
			if not SharedStepExecutor.formula_content_error(spec.amount_formula).is_empty() or not ResourcePoolRules._actor_formula_error(spec.amount_formula).is_empty(): return "Unsupported transfer formula."
		_: return "Unknown captured value policy."
	return ""

static func availability(actor: Character, feature: Dictionary, budget: CombatTurnBudget, source: String) -> Dictionary:
	var owned := actor.get_feature(str(feature.get("id", ""))) if actor != null else {}
	var error := "Transfer feature is not owned." if owned.is_empty() else content_error(owned)
	var pool := ResourcePoolRules.availability(actor, source)
	if error.is_empty() and (not actor.is_alive or actor.is_downed() or CombatAction.is_incapacitated(actor)): error = "Giver cannot act."
	if error.is_empty() and (not pool.get("available", false) or int(pool.get("current", 0)) < 1 or actor.numeric_resource_pools[source].get("definition_id") != owned.resource_pool.id): error = "Transfer requires its exact available source."
	if error.is_empty() and not str(owned.get("source_instance_id", source)).is_empty() and str(owned.get("source_instance_id", source)) != source: error = "Feature belongs to another exact source."
	if error.is_empty() and budget != null and not budget.can_spend(str(owned.action_cost)): error = "Giver's action is unavailable."
	if error.is_empty() and (actor.grant_transfer_serial >= 2147483647 or int(GameManager.campaign_elapsed_seconds) + int(owned.transfer_grant.duration_seconds) > 2147483647): error = "Transfer clock/serial exhausted."
	if error.is_empty() and owned.transfer_grant.value_policy == "pool_die" and not actor.transferred_die_serials.has(source) and actor.transferred_die_serials.size() >= 100: error = "Transferred source ledger is full."
	if error.is_empty() and owned.transfer_grant.value_policy == "formula":
		var result := SharedStepExecutor.evaluate_actor_formula(owned.transfer_grant.amount_formula, actor)
		if not result.get("success", false) or not ResourcePoolRules._integer(result.get("value"), 1, 100): error = "Transfer value is unavailable."
	return {"available":error.is_empty(), "reason":error, "remaining":int(pool.get("current", 0)), "maximum":int(pool.get("capacity", 0)), "action_cost":str(owned.get("action_cost", "action")), "cost":1}

static func recipient_eligible(actor: Character, recipient: Character) -> bool:
	return recipient != null and recipient != actor and not recipient.character_id.is_empty() and recipient.is_alive and not recipient.is_downed() and recipient.willingness == "willing" and not CombatAction.is_incapacitated(recipient) and not bool(recipient.feature_uses.get("is_hostile", false)) and not bool(recipient.feature_uses.get("is_monster_actor", false)) and query(recipient).size() < 100

func begin(actor: Character, feature_id: String, source: String, budget: CombatTurnBudget, recipients: Array) -> Dictionary:
	# Opening a new prompt revokes every earlier answer on this host.
	_pending.clear()
	var feature := actor.get_feature(feature_id) if actor != null else {}
	if budget == null or not availability(actor, feature, budget, source).available: return {}
	var offered: Array = []
	var ids: Array = []
	for recipient in recipients:
		if recipient is Character and recipient_eligible(actor, recipient) and recipient.character_id not in ids:
			offered.append(recipient)
			ids.append(recipient.character_id)
	if offered.is_empty(): return {}
	_serial += 1
	var request_id := "transfer:%d:%d" % [get_instance_id(), _serial]
	var pool: Dictionary = actor.numeric_resource_pools[source]
	_pending = {"request_id":request_id, "actor":actor, "feature":feature.duplicate(true), "source":source, "pool_ref":pool, "pool":pool.duplicate(true), "budget":budget, "recipients":offered, "recipient_ids":ids, "turn":CombatAction.active_turn_serial, "clock":int(GameManager.campaign_elapsed_seconds)}
	return {"request_id":request_id, "recipient_ids":ids.duplicate(), "max_recipients":int(feature.transfer_grant.max_recipients)}

func clear() -> void:
	_pending.clear()

func settle(request_id: String, actor: Character, selected_ids: Array, live_recipients: Array) -> Dictionary:
	if _pending.is_empty() or request_id != _pending.request_id or actor != _pending.actor: return {"success":false}
	var request := _pending
	_pending = {}
	if selected_ids.is_empty(): return {"success":true, "declined":true}
	var feature: Dictionary = request.feature
	if selected_ids.size() > int(feature.transfer_grant.max_recipients) or CombatAction.active_turn_serial != request.turn or int(GameManager.campaign_elapsed_seconds) != request.clock: return {"success":false}
	if actor.get_feature(str(feature.id)) != feature or not is_same(actor.numeric_resource_pools.get(request.source), request.pool_ref) or actor.numeric_resource_pools.get(request.source) != request.pool or not availability(actor, feature, request.budget, request.source).available: return {"success":false}
	var recipients: Array = []
	for id in selected_ids:
		var index: int = request.recipient_ids.find(id)
		if index < 0: return {"success":false}
		var recipient: Character = request.recipients[index]
		if recipient in recipients or recipient not in live_recipients or recipient.character_id != id or not recipient_eligible(actor, recipient): return {"success":false}
		recipients.append(recipient)
	var spec: Dictionary = feature.transfer_grant
	var value := 0
	var die: Dictionary = {}
	if spec.value_policy == "pool_die":
		if request.pool.get("captured_dice", []).is_empty(): return {"success":false}
		die = request.pool.captured_dice[0].duplicate(true)
		value = int(die.face)
	elif spec.value_policy == "formula":
		value = int(SharedStepExecutor.evaluate_actor_formula(spec.amount_formula, actor).value)
	# All refusal paths precede RNG, payment and recipient mutation.
	var paid := ResourcePoolRules.spend(actor, request.source, 1)
	if not paid.get("success", false): return paid
	request.budget.spend(str(feature.action_cost))
	if spec.value_policy == "shared_roll": value = Dice.roll(int(spec.die_size), actor)
	if spec.value_policy == "pool_die": actor.transferred_die_serials[request.source] = int(request.pool.die_serial)
	actor.grant_transfer_serial += 1
	var group := "%s:gift:%d" % [actor.character_id, actor.grant_transfer_serial]
	var grants: Array = []
	for recipient in recipients:
		var grant := {"grant_id":group + ":" + recipient.character_id, "group_id":group, "serial":actor.grant_transfer_serial, "giver_id":actor.character_id, "recipient_id":recipient.character_id, "source_instance_id":request.source, "source_class_id":actor.class_id, "feature_id":feature.id, "generation_level":actor.level, "kind":spec.kind, "value_policy":spec.value_policy, "value":value, "die":die.duplicate(true), "die_size":int(die.get("die_size", spec.get("die_size", 0))), "effect":spec.effect, "use_cost":spec.use_cost, "started_at_seconds":request.clock, "expires_at_seconds":int(request.clock) + int(spec.duration_seconds)}
		prune(recipient, int(request.clock))
		recipient.captured_grants.append(grant)
		grants.append(grant.duplicate(true))
	return {"success":true, "grants":grants, "message":"Captured gifts transferred."}

static func query(actor: Character) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if actor == null: return result
	for grant in actor.captured_grants:
		if grant.recipient_id == actor.character_id and int(grant.expires_at_seconds) > int(GameManager.campaign_elapsed_seconds): result.append(grant.duplicate(true))
	return result

static func use(actor: Character, grant_id: String, budget: CombatTurnBudget) -> Dictionary:
	if actor == null or budget == null or not actor.is_alive or actor.is_downed() or CombatAction.is_incapacitated(actor): return {"success":false}
	for grant in query(actor):
		if grant.grant_id != grant_id or grant.effect == "weapon_attack_bonus": continue
		var cost := str(grant.use_cost)
		if cost == "reaction":
			if not actor.reaction_available: return {"success":false}
		else:
			if not budget.can_spend(cost): return {"success":false}
		if cost == "reaction": actor.reaction_available = false
		else: budget.spend(cost)
		actor.captured_grants = actor.captured_grants.filter(func(record): return record.grant_id != grant_id)
		var before := actor.current_hp if grant.effect == "heal_self" else actor.temp_hp
		if grant.effect == "heal_self": actor.heal(int(grant.value))
		else: actor.temp_hp = maxi(actor.temp_hp, int(grant.value))
		return {"success":true, "grant":grant, "before":before, "after":actor.current_hp if grant.effect == "heal_self" else actor.temp_hp, "message":"Used captured gift (%d)." % int(grant.value)}
	return {"success":false}

static func prune(actor: Character, now: int) -> void:
	actor.captured_grants = actor.captured_grants.filter(func(grant): return int(grant.expires_at_seconds) > now)

static func saved_links_error(save: Dictionary) -> String:
	var actors: Dictionary = save.get("party", {}).get("characters", {}).duplicate(true)
	for player in save.get("players", []):
		var data: Variant = player.get("character")
		if not data is Dictionary: continue
		var id := str(data.get("character_id", ""))
		if actors.has(id):
			if actors[id].get("captured_grants", []) != data.get("captured_grants", []) or actors[id].get("grant_transfer_serial", 0) != data.get("grant_transfer_serial", 0) or actors[id].get("transferred_die_serials", {}) != data.get("transferred_die_serials", {}): return "Player/party captured gifts disagree."
		else: actors[id] = data
	var groups := {}
	var dice := {}
	for data in actors.values():
		for gift in data.get("captured_grants", []):
			var giver: Dictionary = actors.get(gift.giver_id, {})
			if giver.is_empty() or int(giver.get("grant_transfer_serial", 0)) < int(gift.serial): return "Captured gift has no original giver/serial."
			var common: Dictionary = gift.duplicate(true)
			common.erase("recipient_id")
			common.erase("grant_id")
			if groups.has(gift.group_id) and groups[gift.group_id] != common: return "Shared gifts disagree about their captured value."
			groups[gift.group_id] = common
			if gift.value_policy == "pool_die":
				if int(giver.get("transferred_die_serials", {}).get(gift.source_instance_id, 0)) < int(gift.die.serial): return "Giver lost transferred die identity history."
				if dice.has(gift.die.die_id): return "Captured die transferred twice."
				dice[gift.die.die_id] = true
				for pool in giver.get("numeric_resource_pools", {}).values():
					for die in pool.get("captured_dice", []):
						if die.die_id == gift.die.die_id: return "Transferred die remains in the giver pool."
	return ""

static func saved_error(data: Dictionary, now: int) -> String:
	if not ResourcePoolRules._integer(data.get("grant_transfer_serial", 0), 0, 2147483647): return "Invalid transfer serial."
	var marks: Variant = data.get("transferred_die_serials", {})
	if not marks is Dictionary or marks.size() > 100: return "Invalid transferred die identity ledger."
	for source in marks:
		if not source is String or source.strip_edges().is_empty() or not ResourcePoolRules._integer(marks[source], 1, 2147483647): return "Invalid transferred die serial."
		var pool: Variant = data.get("numeric_resource_pools", {}).get(source)
		if pool != null and (not pool is Dictionary or not ResourcePoolRules._integer(pool.get("die_serial"), int(marks[source]), 2147483647)): return "Reacquired source lost transferred die serial."
	var records: Variant = data.get("captured_grants", [])
	if not records is Array or records.size() > 100: return "Invalid captured grants."
	var seen := {}
	for grant in records:
		if not grant is Dictionary: return "Invalid captured gift record."
		for field in ["grant_id", "group_id", "giver_id", "recipient_id", "source_instance_id", "source_class_id", "feature_id"]:
			if not grant.get(field) is String or str(grant[field]).strip_edges().is_empty(): return "Missing captured gift identity."
		if grant.recipient_id != data.get("character_id") or grant.giver_id == grant.recipient_id or seen.has(grant.grant_id): return "Invalid captured recipient/identity."
		seen[grant.grant_id] = true
		if not ResourcePoolRules._integer(grant.get("serial"), 1, 2147483647) or grant.group_id != "%s:gift:%d" % [grant.giver_id, int(grant.serial)] or grant.grant_id != str(grant.group_id) + ":" + str(grant.recipient_id): return "Invalid captured group/serial."
		var definition := DataLoader.get_character_class(str(grant.source_class_id))
		var feature: Dictionary = {}
		for list in definition.get("features_by_level", {}).values():
			for entry in list:
				if entry is Dictionary and entry.get("id") == grant.feature_id: feature = entry
		if feature.is_empty() or not feature.has("transfer_grant") or not content_error(feature).is_empty(): return "Unknown captured grant definition."
		var spec: Dictionary = feature.transfer_grant
		for field in ["kind", "value_policy", "effect", "use_cost"]:
			if grant.get(field) != spec[field]: return "Captured gift policy differs from its definition."
		if not ResourcePoolRules._integer(grant.get("generation_level"), 1, 20) or not ResourcePoolRules._integer(grant.get("value"), 1, 100): return "Invalid captured value/level."
		if not ResourcePoolRules._integer(grant.get("started_at_seconds"), 0, now) or not ResourcePoolRules._integer(grant.get("expires_at_seconds"), 1, 2147483647) or int(grant.expires_at_seconds) != int(grant.started_at_seconds) + int(spec.duration_seconds): return "Invalid captured gift deadline."
		if not grant.get("die") is Dictionary: return "Invalid captured die payload."
		if spec.value_policy == "pool_die":
			var die: Dictionary = grant.die
			if not ResourcePoolRules._integer(die.get("serial"), 1, 2147483647) or die.get("owner_id") != grant.giver_id or die.get("source_instance_id") != grant.source_instance_id or die.get("die_id") != "%s:%s:die:%d" % [grant.giver_id, grant.source_instance_id, int(die.serial)]: return "Invalid transferred die identity."
			if die.get("face") != grant.value or die.get("die_size") != grant.get("die_size") or not ResourcePoolRules._integer(grant.get("die_size"), 1, 20) or int(grant.die_size) not in ResourcePoolRules.SUPPORTED_DIE_SIZES or int(grant.value) > int(grant.die_size) or not ResourcePoolRules._integer(die.get("generation_level"), 1, int(grant.generation_level)): return "Invalid transferred die face/size/generation."
		elif not grant.die.is_empty() or (spec.value_policy == "shared_roll" and (grant.get("die_size") != spec.die_size or int(grant.value) > int(spec.die_size))) or (spec.value_policy == "formula" and grant.get("die_size") != 0): return "Invalid captured value payload."
	return ""
