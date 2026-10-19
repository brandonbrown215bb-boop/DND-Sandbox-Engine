## Bounded contributions to the existing captured weapon-attack choice.
class_name PartyInterventionRules
extends RefCounted

static func content_error(feature: Dictionary) -> String:
	if feature.get("executor") != "class_feature" or feature.get("type") != "active" or feature.get("target") != "self" or feature.get("action_cost") != "free": return "Intervention requires a common free self feature."
	for field in ["uses", "uses_per", "resource_id", "resource_cost", "resource_exchange", "transfer_grant", "allocation"]:
		if feature.has(field): return "Intervention uses its own numeric pool only."
	if not feature.get("effects", []) is Array or not feature.get("effects", []).is_empty() or not feature.get("passive_effects", []) is Array or not feature.get("passive_effects", []).is_empty(): return "Intervention cannot combine effects."
	var error := ResourcePoolRules.definition_error(feature)
	if not error.is_empty(): return error
	if feature.resource_pool.has("die_size"): return "Intervention requires a numeric pool."
	var spec: Variant = feature.get("roll_intervention")
	if not spec is Dictionary or spec.size() != 3 or spec.get("domain") != "weapon_attack" or spec.get("use_cost") != "reaction" or not ResourcePoolRules._integer(spec.get("amount"), 1, 100): return "Intervention requires weapon_attack, a fixed amount and Reaction."
	return ""

static func capable(actor: Character) -> bool:
	return actor != null and actor.is_alive and not actor.is_downed() and not CombatAction.is_incapacitated(actor) and actor.reaction_available

static func options(actor: Character, players: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if actor == null or not actor.is_alive or actor.is_downed() or CombatAction.is_incapacitated(actor): return result
	for gift in CapturedGrantRules.query(actor):
		if gift.effect != "weapon_attack_bonus" or not capable(actor): continue
		result.append({"source_instance_id":gift.grant_id, "resolution":"party_bonus", "amount":int(gift.value), "bonus_kind":"numeric", "cost":1, "payment_policy":"pay_on_choice", "domain":"weapon_attack", "source_owner_id":actor.character_id, "label":"%s: captured gift +%d (Reaction)" % [actor.character_name, int(gift.value)], "spender":actor, "grant":gift.duplicate(true)})
	# Each helper is a live player Character, never caller-supplied owner metadata.
	for entry in players:
		var helper: Character = entry.get("character")
		if helper == actor or not capable(helper) or not CapturedGrantRules.recipient_eligible(actor, helper): continue
		for feature in helper.features:
			if not feature.has("roll_intervention") or not content_error(feature).is_empty(): continue
			for source in ResourcePoolRules.source_instance_ids(helper, str(feature.resource_pool.id)):
				if not str(feature.get("source_instance_id", source)).is_empty() and str(feature.get("source_instance_id", source)) != source: continue
				if int(ResourcePoolRules.availability(helper, source).get("spendable", 0)) < 1: continue
				var pool: Dictionary = helper.numeric_resource_pools[source]
				result.append({"source_instance_id":"party:%d:%s" % [helper.get_instance_id(), source], "resolution":"party_bonus", "amount":int(feature.roll_intervention.amount), "bonus_kind":"numeric", "cost":1, "payment_policy":"pay_on_choice", "domain":"weapon_attack", "source_owner_id":helper.character_id, "label":"%s: %s +%d (Reaction)" % [helper.character_name, feature.name, int(feature.roll_intervention.amount)], "spender":helper, "pool_source":source, "pool_anchor":_anchor(pool), "pool_snapshot":pool.duplicate(true), "feature_snapshot":feature.duplicate(true)})
	return result

static func current(offered: Dictionary, actor: Character, players: Array) -> bool:
	for option in options(actor, players):
		if option.source_instance_id != offered.source_instance_id: continue
		for field in ["spender", "source_owner_id", "amount", "resolution", "payment_policy", "domain", "cost", "grant", "pool_source", "pool_snapshot", "feature_snapshot"]:
			if option.get(field) != offered.get(field): return false
		if offered.has("pool_anchor") and not is_same(option.spender.numeric_resource_pools.get(option.pool_source), offered.pool_anchor.get_meta("pool")): return false
		return true
	return false

static func pay(selected: Dictionary) -> Dictionary:
	var spender: Character = selected.get("spender")
	if not capable(spender): return {"success":false}
	if selected.has("grant"):
		if not CapturedGrantRules.query(spender).has(selected.grant): return {"success":false}
		spender.captured_grants = spender.captured_grants.filter(func(gift): return gift.grant_id != selected.grant.grant_id)
	else:
		var source := str(selected.get("pool_source", ""))
		if not is_same(spender.numeric_resource_pools.get(source), selected.pool_anchor.get_meta("pool")) or spender.numeric_resource_pools.get(source) != selected.get("pool_snapshot") or spender.get_feature(str(selected.feature_snapshot.id)) != selected.feature_snapshot: return {"success":false}
		if not ResourcePoolRules.spend(spender, source, 1).get("success", false): return {"success":false}
	spender.reaction_available = false
	return {"success":true, "state":"committed", "owner_id":spender.character_id, "source_instance_id":selected.source_instance_id, "amount":1, "reaction_paid":true, "captured_value":int(selected.amount)}

static func _anchor(pool: Dictionary) -> RefCounted:
	var ref := RefCounted.new()
	ref.set_meta("pool", pool)
	return ref
