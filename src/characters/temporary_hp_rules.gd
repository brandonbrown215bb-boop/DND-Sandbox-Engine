## Recipient decisions for source-owned Temporary HP. Only settled grants persist.
class_name TemporaryHPRules
extends RefCounted

var pending: Dictionary = {}
var generation := 0

static func content_error(feature: Dictionary) -> String:
	if feature.get("executor") != "class_feature" or feature.get("type") != "active" or feature.get("target") != "self" or feature.get("action_cost") not in ["action", "bonus_action", "free"]: return "Temporary HP requires a common active feature."
	for key in ["transfer_grant", "allocation", "resource_exchange", "resource_id", "uses", "uses_per", "resource_cost"]:
		if feature.has(key): return "Temporary HP grants use one exact numeric pool quantity."
	if feature.get("effects", []) != [] or feature.get("passive_effects", []) != []: return "Temporary HP grants cannot combine additional effects."
	var error := ResourcePoolRules.definition_error(feature)
	if not error.is_empty(): return error
	if feature.get("resource_pool", {}).has("die_size"): return "Temporary HP grants require a numeric pool."
	return spec_error(feature.get("temporary_hp_grant"))

static func spec_error(spec: Variant) -> String:
	if not spec is Dictionary or spec.size() != 4: return "Temporary HP requires amount, duration, beneficiary and benefits."
	if not ResourcePoolRules._integer(spec.get("amount"), 1, 100000) or not ResourcePoolRules._integer(spec.get("duration_seconds"), 1, 86400) or spec.get("beneficiary") not in ["recipient", "supplier"]: return "Invalid Temporary HP amount, duration or beneficiary."
	return benefit_error(spec.get("benefits"))

static func benefit_error(benefits: Variant) -> String:
	if not benefits is Dictionary or benefits.size() != 2 or not ResourcePoolRules._integer(benefits.get("ac_bonus"), 0, 10) or not ResourcePoolRules._integer(benefits.get("save_bonus"), 0, 10): return "Benefits require bounded AC and saving-throw bonuses."
	return ""

static func availability(actor: Character, feature: Dictionary, budget: CombatTurnBudget, source: String) -> Dictionary:
	feature = actor.get_feature(str(feature.get("id", ""))) if actor != null else {}
	var error := content_error(feature)
	if error.is_empty() and (actor == null or not actor.is_alive or CombatAction.is_incapacitated(actor) or actor.get_feature(str(feature.get("id", ""))) != feature): error = "Temporary HP supplier is unavailable."
	var pool: Dictionary = actor.numeric_resource_pools.get(source, {}) if actor != null else {}
	if error.is_empty() and (pool.get("owner_id") != actor.character_id or pool.get("definition_id") != feature.resource_pool.id or not ResourcePoolRules.availability(actor, source).get("available", false)): error = "Temporary HP source is unavailable."
	if error.is_empty() and str(feature.get("source_instance_id", source)) != source: error = "Temporary HP belongs to another exact source."
	if error.is_empty() and budget != null and not budget.can_spend(str(feature.action_cost)): error = "Temporary HP action is unavailable."
	if error.is_empty() and (actor.temporary_hp_supply_serial >= 2147483647 or int(GameManager.campaign_elapsed_seconds) + int(feature.temporary_hp_grant.duration_seconds) > 2147483647): error = "Temporary HP clock or serial exhausted."
	return {"available":error.is_empty(), "reason":error, "remaining":int(pool.get("current", 0)), "maximum":int(pool.get("capacity", 0)), "cost":1, "action_cost":feature.get("action_cost", "action")}

static func eligible(recipient: Character) -> bool:
	return recipient != null and not recipient.character_id.is_empty() and recipient.is_alive and recipient.willingness == "willing" and not bool(recipient.feature_uses.get("is_hostile", false))

func clear() -> void:
	pending.clear()
	generation += 1

func begin(actor: Character, feature_id: String, source: String, budget: CombatTurnBudget, recipient: Character) -> Dictionary:
	clear()
	var feature := actor.get_feature(feature_id) if actor != null else {}
	if budget == null or not availability(actor, feature, budget, source).available or not eligible(recipient): return {}
	prune(recipient, int(GameManager.campaign_elapsed_seconds))
	pending = {"generation":generation, "actor":actor, "feature":feature.duplicate(true), "source":source, "pool_ref":actor.numeric_resource_pools[source], "pool":actor.numeric_resource_pools[source].duplicate(true), "budget":budget, "recipient":recipient, "recipient_id":recipient.character_id, "hp":recipient.temp_hp, "linked":recipient.linked_temporary_hp.duplicate(true), "timed":recipient.timed_temporary_hp_current_grant_id, "clock":int(GameManager.campaign_elapsed_seconds), "turn":CombatAction.active_turn_serial}
	return {"generation":generation, "recipient_id":recipient.character_id, "current":recipient.temp_hp, "incoming":int(feature.temporary_hp_grant.amount)}

func settle(request: Dictionary, replace: bool, live_recipients: Array) -> Dictionary:
	if pending.is_empty() or request.get("generation") != pending.generation: return {"success":false}
	var p := pending
	pending = {}
	var actor: Character = p.actor
	var recipient: Character = p.recipient
	if recipient not in live_recipients or not eligible(recipient) or recipient.character_id != p.recipient_id or recipient.temp_hp != p.hp or recipient.linked_temporary_hp != p.linked or recipient.timed_temporary_hp_current_grant_id != p.timed or int(GameManager.campaign_elapsed_seconds) != p.clock or CombatAction.active_turn_serial != p.turn: return {"success":false}
	if actor.get_feature(str(p.feature.id)) != p.feature or not is_same(actor.numeric_resource_pools.get(p.source), p.pool_ref) or actor.numeric_resource_pools.get(p.source) != p.pool or not availability(actor, p.feature, p.budget, p.source).available: return {"success":false}
	# Keeping the old grant is a decline: no payment, supplier or clock changes.
	if not replace: return {"success":true, "declined":true}
	var paid := ResourcePoolRules.spend(actor, p.source, 1)
	if not paid.get("success", false): return paid
	p.budget.spend(str(p.feature.action_cost))
	actor.temporary_hp_supply_serial += 1
	var spec: Dictionary = p.feature.temporary_hp_grant
	recipient.clear_temporary_hp_ownership()
	recipient.temp_hp = int(spec.amount)
	# Even equal-value replacement changes ownership; retaining does not.
	recipient.timed_temporary_hp_current_grant_id = ""
	recipient.linked_temporary_hp = {"grant_id":"%s:temporary_hp:%d" % [actor.character_id, actor.temporary_hp_supply_serial], "serial":actor.temporary_hp_supply_serial, "supplier_id":actor.character_id, "recipient_id":recipient.character_id, "source_instance_id":p.source, "feature_id":p.feature.id, "started_at_seconds":p.clock, "expires_at_seconds":int(p.clock)+int(spec.duration_seconds), "spec":spec.duplicate(true)}
	return {"success":true, "grant":recipient.linked_temporary_hp.duplicate(true)}

static func prune(actor: Character, now: int) -> void:
	if actor.linked_temporary_hp.is_empty(): return
	if int(actor.linked_temporary_hp.expires_at_seconds) <= now: actor.temp_hp = 0
	if actor.temp_hp <= 0: actor.linked_temporary_hp = {}

static func remove_source(supplier: Character, source: String) -> void:
	var recipients: Array = PartyManager.characters.values().duplicate()
	if supplier not in recipients: recipients.append(supplier)
	for recipient in recipients:
		if recipient is Character and recipient.linked_temporary_hp.get("supplier_id") == supplier.character_id and recipient.linked_temporary_hp.get("source_instance_id") == source: recipient.temp_hp = 0

static func bonus(actor: Character, key: String) -> int:
	var best := 0
	var recipients: Array = PartyManager.characters.values().duplicate()
	if actor not in recipients: recipients.append(actor)
	for recipient in recipients:
		if not recipient is Character: continue
		var grant: Dictionary = recipient.linked_temporary_hp
		if grant.is_empty() or recipient.temp_hp <= 0 or int(grant.expires_at_seconds) <= int(GameManager.campaign_elapsed_seconds): continue
		var id: String = grant.recipient_id if grant.spec.beneficiary == "recipient" else grant.supplier_id
		if id == actor.character_id: best = maxi(best, int(grant.spec.benefits[key]))
	return best

static func saved_error(data: Dictionary, now: int) -> String:
	if not ResourcePoolRules._integer(data.get("temporary_hp_supply_serial", 0), 0, 2147483647): return "Invalid Temporary HP supplier serial."
	var g: Variant = data.get("linked_temporary_hp", {})
	if not g is Dictionary: return "Invalid linked Temporary HP container."
	if g.is_empty(): return ""
	if g.size() != 9 or not spec_error(g.get("spec")).is_empty(): return "Invalid linked Temporary HP grant payload."
	if not g.get("supplier_id") is String or str(g.supplier_id).is_empty() or g.get("recipient_id") != data.get("character_id") or not g.get("source_instance_id") is String or str(g.source_instance_id).is_empty() or not g.get("feature_id") is String: return "Invalid Temporary HP participant/source."
	if not ResourcePoolRules._integer(g.get("serial"), 1, 2147483647) or g.get("grant_id") != "%s:temporary_hp:%d" % [g.supplier_id, int(g.serial)]: return "Invalid Temporary HP grant identity."
	if not ResourcePoolRules._integer(g.get("started_at_seconds"), 0, now) or not ResourcePoolRules._integer(g.get("expires_at_seconds"), now+1, 2147483647) or int(g.expires_at_seconds) != int(g.started_at_seconds)+int(g.spec.duration_seconds): return "Invalid Temporary HP deadline."
	if not ResourcePoolRules._integer(data.get("temp_hp"), 1, int(g.spec.amount)) or not str(data.get("timed_temporary_hp_current_grant_id", "")).is_empty(): return "Linked Temporary HP does not own the current amount."
	var feature := ProtectionRules._loaded_feature(str(g.feature_id))
	if feature.is_empty() or not content_error(feature).is_empty() or feature.temporary_hp_grant != g.spec: return "Temporary HP differs from loaded source."
	return ""

static func saved_links_error(save: Dictionary) -> String:
	var actors: Dictionary = save.get("party", {}).get("characters", {}).duplicate(true)
	for player in save.get("players", []):
		var dto: Variant = player.get("character")
		if not dto is Dictionary: continue
		var id := str(dto.get("character_id", ""))
		if actors.has(id) and (actors[id].get("linked_temporary_hp", {}) != dto.get("linked_temporary_hp", {}) or actors[id].get("temporary_hp_supply_serial", 0) != dto.get("temporary_hp_supply_serial", 0) or actors[id].get("temp_hp", 0) != dto.get("temp_hp", 0)): return "Player/party Temporary HP disagree."
		actors[id] = dto
	var seen := {}
	for dto in actors.values():
		var g: Dictionary = dto.get("linked_temporary_hp", {})
		if g.is_empty(): continue
		var supplier: Dictionary = actors.get(g.supplier_id, {})
		if supplier.is_empty() or int(supplier.get("temporary_hp_supply_serial", 0)) < int(g.serial) or seen.has(g.grant_id): return "Temporary HP lost its supplier or reused a grant."
		var pool: Variant = supplier.get("numeric_resource_pools", {}).get(g.source_instance_id)
		var feature := ProtectionRules._loaded_feature(str(g.feature_id))
		if not pool is Dictionary or pool.get("owner_id") != g.supplier_id or pool.get("source_instance_id") != g.source_instance_id or pool.get("definition_id") != feature.get("resource_pool", {}).get("id"): return "Temporary HP lost its exact supplier pool."
		seen[g.grant_id] = true
	return ""
