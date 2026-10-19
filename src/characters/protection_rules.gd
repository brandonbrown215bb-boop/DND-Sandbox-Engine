## Source-owned stat projections. Queries never acquire, spend or move clocks.
class_name ProtectionRules
extends RefCounted

static func content_error(effect: Dictionary) -> String:
	for key in effect:
		if key not in ["type", "duration_seconds", "group", "stacking", "eligibility", "benefits"]: return "Protection contains an unsupported field."
	if not ResourcePoolRules._integer(effect.get("duration_seconds"),1,86400) or not effect.get("group") is String or not str(effect.group).is_valid_identifier() or effect.get("stacking") not in ["stack", "exclusive"]: return "Protection requires duration, group and stack/exclusive policy."
	var eligibility: Variant = effect.get("eligibility")
	if not eligibility is Dictionary or eligibility.size()!=2 or eligibility.get("armor") not in ["none","worn","any"] or eligibility.get("shield") not in ["none","any"]: return "Protection requires explicit armor and shield eligibility."
	var benefits: Variant = effect.get("benefits")
	if not benefits is Array or benefits.is_empty() or benefits.size()>8: return "Protection requires 1-8 stat benefits."
	var seen := {}
	for benefit in benefits:
		if not benefit is Dictionary or benefit.size()!=3 or not benefit.has("value"): return "Protection benefit requires stat, operation and value."
		var stat := str(benefit.get("stat",""))
		var operation := str(benefit.get("operation",""))
		if (stat=="AC" and operation not in ["base","add"]) or (stat in AbilityScores.ABILITIES and operation not in ["set","floor","cap","add"]) or (stat!="AC" and stat not in AbilityScores.ABILITIES): return "Unsupported protection stat/operation."
		var key := stat+":"+operation
		if seen.has(key): return "Duplicate protection stat operation."
		seen[key]=true
		if stat=="AC" and operation=="base":
			if not SharedStepExecutor.formula_content_error(benefit.value).is_empty() or not ResourcePoolRules._actor_formula_error(benefit.value).is_empty(): return "Base AC requires an actor numeric formula."
		elif not ResourcePoolRules._integer(benefit.value,-30 if operation=="add" else 1,30): return "Score/additive protection requires a bounded integer."
	return ""

static func eligible(actor: Character, effect: Dictionary) -> bool:
	if actor==null or actor.inventory==null or not content_error(effect).is_empty(): return false
	var armor := actor.inventory.get_armor()
	var shield := actor.inventory.get_equipped(Inventory.Slot.SHIELD)
	# Unknown equipped definitions are missing facts, never permission to be unarmored.
	if not armor.is_empty() and DataLoader.get_item(armor).get("armor_type", "") not in ["light","medium","heavy"]: return false
	if not shield.is_empty() and DataLoader.get_item(shield).get("type", "") != "shield": return false
	return (effect.eligibility.armor=="any" or (effect.eligibility.armor=="none" and armor.is_empty()) or (effect.eligibility.armor=="worn" and not armor.is_empty())) and (effect.eligibility.shield=="any" or shield.is_empty())

static func activation_error(actor: Character, feature: Dictionary, source: String, effect: Dictionary) -> String:
	var error := content_error(effect)
	if not error.is_empty(): return error
	if actor==null or actor.character_id.is_empty() or source.is_empty() or str(actor.numeric_resource_pools.get(source,{}).get("definition_id",""))!=str(feature.get("resource_pool",{}).get("id","")): return "Protection requires its exact owned pool source."
	if not eligible(actor,effect): return "Equipment does not permit this protection."
	var now := int(GameManager.campaign_elapsed_seconds)
	if now<0 or now+int(effect.duration_seconds)>2147483647 or actor.protection_serial>=2147483647: return "Protection clock/serial limit reached."
	for grant in actor.protection_grants:
		if int(grant.expires_at_seconds)<=now: continue
		if grant.source_instance_id==source: return "This source already has a protection."
		if grant.effect.group==effect.group and grant.effect.stacking!=effect.stacking: return "A protection group cannot mix stacking policies."
	for benefit in effect.benefits:
		if benefit.stat=="AC" and benefit.operation=="base":
			var evaluated := SharedStepExecutor.evaluate_actor_formula(benefit.value,actor)
			if not evaluated.get("success",false) or not ResourcePoolRules._integer(evaluated.get("value"),1,100): return "Base AC formula is unavailable."
	return ""

static func grant(actor: Character, feature: Dictionary, source: String, effect: Dictionary) -> Dictionary:
	# Called after the same synchronous preflight and once-only common feature payment.
	actor.protection_serial+=1
	var now := int(GameManager.campaign_elapsed_seconds)
	var record := {"owner_id":actor.character_id,"source_instance_id":source,"source_definition_id":str(feature.id),"pool_definition_id":str(feature.resource_pool.id),"grant_instance_id":"%s:protection:%d" % [actor.character_id,actor.protection_serial],"order":actor.protection_serial,"started_at_seconds":now,"expires_at_seconds":now+int(effect.duration_seconds),"effect":effect.duplicate(true)}
	actor.protection_grants.append(record)
	return record.duplicate(true)

static func owned(actor: Character, eligible_only: bool = true) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if actor==null: return records
	for grant in actor.protection_grants:
		if grant.owner_id!=actor.character_id or int(grant.expires_at_seconds)<=int(GameManager.campaign_elapsed_seconds): continue
		var pool: Dictionary = actor.numeric_resource_pools.get(grant.source_instance_id,{})
		if pool.get("owner_id")!=actor.character_id or pool.get("source_instance_id")!=grant.source_instance_id or pool.get("definition_id")!=grant.pool_definition_id: continue
		if not eligible_only or eligible(actor,grant.effect): records.append(grant)
	records.sort_custom(func(a,b): return int(a.order)<int(b.order))
	return records

static func selected(actor: Character) -> Array[Dictionary]:
	var records := owned(actor)
	var groups := {}
	for grant in records:
		if grant.effect.stacking=="stack": continue
		var group: String = grant.effect.group
		if not groups.has(group) or actor.protection_selections.get(group,"")==grant.grant_instance_id: groups[group]=grant
	var result: Array[Dictionary] = []
	for grant in records:
		if grant.effect.stacking=="stack" or groups[grant.effect.group].grant_instance_id==grant.grant_instance_id: result.append(grant)
	return result

static func score(actor: Character, stat: String, permanent: int) -> int:
	var value := permanent
	var grants := selected(actor)
	var applies := false
	for record in grants:
		for benefit in record.effect.benefits:
			if benefit.stat==stat: applies=true
	if not applies: return permanent
	# Setting uses the highest legal value; ties retain the earliest exact source.
	var setting := -1
	for grant in grants:
		for benefit in grant.effect.benefits:
			if benefit.stat==stat and benefit.operation=="set": setting=maxi(setting,int(benefit.value))
	if setting>=0: value=setting
	for operation in ["floor","cap","add"]:
		for grant in grants:
			for benefit in grant.effect.benefits:
				if benefit.stat!=stat or benefit.operation!=operation: continue
				if operation=="floor": value=maxi(value,int(benefit.value))
				elif operation=="cap": value=mini(value,int(benefit.value))
				else: value+=int(benefit.value)
	return clampi(value,1,30)

static func ac(actor: Character, ordinary_base: int) -> Dictionary:
	var base := ordinary_base
	var addition := TemporaryHPRules.bonus(actor, "ac_bonus") + AuraProtectionRules.bonus(actor, "ac_bonus")
	var contributions: Array[Dictionary] = []
	for grant in selected(actor):
		for benefit in grant.effect.benefits:
			if benefit.stat!="AC": continue
			var evaluated := SharedStepExecutor.evaluate_actor_formula(benefit.value,actor)
			if not evaluated.get("success",false) or not ResourcePoolRules._integer(evaluated.get("value"),-100,100): continue
			var value := int(evaluated.value)
			if benefit.operation=="base":
				var shield_id := actor.inventory.get_equipped(Inventory.Slot.SHIELD)
				if not shield_id.is_empty(): value+=int(DataLoader.get_item(shield_id).get("ac_bonus",2))
				base=maxi(base,value)
			else: addition+=value
			contributions.append({"source_instance_id":grant.source_instance_id,"grant_instance_id":grant.grant_instance_id,"operation":benefit.operation,"value":value,"expires_at_seconds":grant.expires_at_seconds})
	return {"base":base,"addition":addition,"sources":contributions}

static func remove_source(actor: Character, source: String) -> void:
	var had := actor.protection_grants.any(func(g): return g.source_instance_id==source)
	actor.protection_grants=actor.protection_grants.filter(func(g): return g.source_instance_id!=source)
	if had: actor._recalculate_ac()
	prune(actor,int(GameManager.campaign_elapsed_seconds))

static func prune(actor: Character, now: int) -> void:
	var had := not actor.protection_grants.is_empty()
	actor.protection_grants=actor.protection_grants.filter(func(g): return int(g.expires_at_seconds)>now and actor.numeric_resource_pools.has(g.source_instance_id))
	if had and actor.protection_grants.is_empty(): actor._recalculate_ac()
	var ids: Array = actor.protection_grants.map(func(g): return g.grant_instance_id)
	for group in actor.protection_selections.keys():
		if actor.protection_selections[group] not in ids: actor.protection_selections.erase(group)

static func cancel_choice(actor: Character) -> void:
	actor.protection_choice_generation+=1
	actor.pending_protection_choice.clear()

static func begin_choice(actor: Character, group: String) -> Dictionary:
	actor.protection_choice_generation+=1
	var offers: Array[Dictionary] = []
	for grant in owned(actor):
		if grant.effect.group==group and grant.effect.stacking=="exclusive": offers.append(grant.duplicate(true))
	var request := {"actor_ref":weakref(actor),"owner_id":actor.character_id,"group":group,"generation":actor.protection_choice_generation,"offers":offers}
	actor.pending_protection_choice=request.duplicate(true)
	return request

static func answer(actor: Character, request: Dictionary, grant_id: String) -> bool:
	if actor==null or actor.pending_protection_choice!=request or not request.get("actor_ref") is WeakRef or request.actor_ref.get_ref()!=actor or request.get("owner_id")!=actor.character_id or request.get("generation")!=actor.protection_choice_generation: return false
	actor.pending_protection_choice={}
	actor.protection_choice_generation+=1
	if grant_id.is_empty(): return true
	var offer: Dictionary = {}
	for candidate in request.offers:
		if candidate.grant_instance_id==grant_id: offer=candidate
	if offer.is_empty(): return false
	for current in owned(actor):
		if current==offer and current.effect.group==request.group:
			actor.protection_selections[request.group]=grant_id
			return true
	return false

static func saved_error(data: Dictionary, now: int) -> String:
	var grants: Variant = data.get("protection_grants",[])
	var selections: Variant = data.get("protection_selections",{})
	var serial: Variant = data.get("protection_serial",0)
	if not grants is Array or not selections is Dictionary or not ResourcePoolRules._integer(serial,0,2147483647): return "Invalid protection state containers/serial."
	var pools: Variant = data.get("numeric_resource_pools",{})
	if not pools is Dictionary: return "Invalid protection source pool container."
	var ids := {}
	var sources := {}
	var groups := {}
	for grant in grants:
		if not grant is Dictionary or grant.size()!=9 or not grant.get("effect") is Dictionary: return "Invalid protection record."
		if not content_error(grant.effect).is_empty(): return "Invalid protection payload."
		var owner := str(data.get("character_id",""))
		var source := str(grant.get("source_instance_id",""))
		var id := str(grant.get("grant_instance_id",""))
		var pool: Variant = pools.get(source,{})
		if owner.is_empty() or grant.get("owner_id")!=owner or source.is_empty() or sources.has(source) or not pool is Dictionary or pool.get("owner_id")!=owner or pool.get("source_instance_id")!=source or pool.get("definition_id")!=grant.get("pool_definition_id"): return "Invalid protection owner/source."
		if not ResourcePoolRules._integer(grant.get("order"),1,int(serial)) or id!="%s:protection:%d" % [owner,int(grant.order)] or ids.has(id): return "Invalid protection grant identity."
		if not ResourcePoolRules._integer(grant.get("started_at_seconds"),0,now) or not ResourcePoolRules._integer(grant.get("expires_at_seconds"),1,2147483647) or int(grant.expires_at_seconds)!=int(grant.started_at_seconds)+int(grant.effect.duration_seconds): return "Invalid protection deadline."
		var definition := _loaded_feature(str(grant.get("source_definition_id","")))
		if definition.is_empty() or definition.get("resource_pool",{}).get("id")!=grant.pool_definition_id or grant.effect not in definition.get("effects",[]): return "Protection payload differs from its loaded source definition."
		if groups.has(grant.effect.group) and groups[grant.effect.group]!=grant.effect.stacking: return "Conflicting protection group policies."
		groups[grant.effect.group]=grant.effect.stacking
		ids[id]=grant
		sources[source]=true
	for group in selections:
		var selected_id: Variant = selections[group]
		if not group is String or not selected_id is String or not ids.has(selected_id) or ids[selected_id].effect.group!=group or ids[selected_id].effect.stacking!="exclusive": return "Invalid selected protection identity/group."
	return ""

static func _loaded_feature(id: String) -> Dictionary:
	for definition in DataLoader.classes.values():
		for features in definition.get("features_by_level",{}).values():
			for feature in features:
				if feature.get("id")==id: return feature
	return {}
