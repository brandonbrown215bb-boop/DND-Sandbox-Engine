## Chosen, timed entry protections. Membership is live; entry receipts persist.
class_name AuraProtectionRules
extends RefCounted

static func content_error(effect: Dictionary) -> String:
	if effect.size() != 6 or effect.get("type") != "protection_aura" or not effect.get("group") is String or not str(effect.group).is_valid_identifier(): return "Aura protection requires a group and explicit entry policy."
	if not ResourcePoolRules._integer(effect.get("radius_feet"), 5, 150) or int(effect.radius_feet) % 5 != 0: return "Aura protection requires a radius in 5-foot steps."
	if not ((effect.get("entry_policy") == "once_per_source" and ResourcePoolRules._integer(effect.get("duration_seconds"), 1, 86400)) or (effect.get("entry_policy") == "membership" and effect.get("duration_seconds") == 0)): return "Aura requires membership/zero duration or once_per_source/timed entry policy."
	return TemporaryHPRules.benefit_error(effect.get("benefits"))

static func refresh(members: Array) -> void:
	var now := int(GameManager.campaign_elapsed_seconds)
	for member in members:
		var recipient: Character = member.character
		for other in members:
			var source: Character = other.character
			if not source.is_alive or not recipient.is_alive or CombatAction.is_incapacitated(source): continue
			for feature in source.features:
				for effect in source._feature_effects(feature):
					if effect.get("type") != "protection_aura" or not content_error(effect).is_empty() or HexUtils.get_distance(member.position, other.position) * 5 > int(effect.radius_feet): continue
					var key := "%s:aura:%s" % [source.character_id, feature.id]
					# A refresh, exit/reentry, save or reload cannot reacquire this use.
					if recipient.aura_entry_receipts.has(key) or recipient.aura_entry_receipts.size() >= 100 or now + int(effect.duration_seconds) > 2147483647: continue
					recipient.aura_entry_receipts[key] = {"source_owner_id":source.character_id, "bearer_id":source.character_id, "recipient_id":recipient.character_id, "feature_id":feature.id, "started_at_seconds":now, "expires_at_seconds":now+int(effect.duration_seconds), "effect":effect.duplicate(true)}

static func offers(actor: Character, group: String = "") -> Dictionary:
	var result := {}
	for key in actor.aura_entry_receipts:
		var record: Dictionary = actor.aura_entry_receipts[key]
		var active := _membership_active(actor, record) if record.effect.entry_policy == "membership" else int(record.expires_at_seconds) > int(GameManager.campaign_elapsed_seconds)
		if active and (group.is_empty() or group == record.effect.group): result[key] = record.duplicate(true)
	return result

static func _membership_active(actor: Character, record: Dictionary) -> bool:
	if not actor.is_alive: return false
	for entry in actor.aura_source_memberships:
		if entry.source_owner_id != record.source_owner_id or entry.bearer_id != record.bearer_id or entry.recipient_id != actor.character_id or int(entry.distance_feet) > int(record.effect.radius_feet): continue
		var source := AuraRules._source_from_entry(entry)
		if not AuraRules._source_is_active(source): continue
		var feature := source.get_feature(str(record.feature_id))
		if record.effect in feature.get("effects", []): return true
	return false

static func bonus(actor: Character, stat: String) -> int:
	var groups := {}
	var records := offers(actor)
	for key in records:
		var group: String = records[key].effect.group
		if not groups.has(group) or actor.aura_protection_selections.get(group) == key: groups[group] = key
	var value := 0
	for key in groups.values(): value += int(records[key].effect.benefits[stat])
	return value

static func choose(actor: Character, snapshot: Dictionary, key: String) -> bool:
	if not snapshot.has(key): return false
	var record: Dictionary = snapshot[key]
	if offers(actor, str(record.effect.group)) != snapshot: return false
	actor.aura_protection_selections[record.effect.group] = key
	return true

static func saved_error(data: Dictionary, now: int) -> String:
	var records: Variant = data.get("aura_entry_receipts", {})
	var selected: Variant = data.get("aura_protection_selections", {})
	if not records is Dictionary or records.size() > 100 or not selected is Dictionary: return "Invalid aura entry state."
	for key in records:
		var r: Variant = records[key]
		if not key is String or not r is Dictionary or r.size() != 7 or not r.get("effect") is Dictionary or not content_error(r.effect).is_empty(): return "Invalid aura entry receipt."
		if not r.get("source_owner_id") is String or str(r.source_owner_id).is_empty() or r.get("bearer_id") != r.source_owner_id or r.get("recipient_id") != data.get("character_id") or not r.get("feature_id") is String or key != "%s:aura:%s" % [r.source_owner_id, r.feature_id]: return "Invalid aura entry participants."
		if not ResourcePoolRules._integer(r.get("started_at_seconds"), 0, now) or not ResourcePoolRules._integer(r.get("expires_at_seconds"), 0, 2147483647) or int(r.expires_at_seconds) != int(r.started_at_seconds)+int(r.effect.duration_seconds): return "Invalid aura entry deadline."
		var feature := ProtectionRules._loaded_feature(str(r.feature_id))
		if feature.is_empty() or r.effect not in feature.get("effects", []): return "Aura entry differs from its loaded source."
	for group in selected:
		if not group is String or not selected[group] is String or not records.has(selected[group]) or records[selected[group]].effect.group != group: return "Invalid selected aura protection."
	return ""

static func saved_links_error(save: Dictionary) -> String:
	var actors: Dictionary = save.get("party", {}).get("characters", {}).duplicate(true)
	for player in save.get("players", []):
		var dto: Variant = player.get("character")
		if not dto is Dictionary: continue
		var id := str(dto.get("character_id", ""))
		if actors.has(id) and (actors[id].get("aura_entry_receipts", {}) != dto.get("aura_entry_receipts", {}) or actors[id].get("aura_protection_selections", {}) != dto.get("aura_protection_selections", {})): return "Player/party aura entries disagree."
		actors[id] = dto
	for dto in actors.values():
		for r in dto.get("aura_entry_receipts", {}).values():
			if not actors.has(r.source_owner_id): return "Aura entry supplier is missing."
	return ""
