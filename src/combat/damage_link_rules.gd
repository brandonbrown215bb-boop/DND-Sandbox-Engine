## Source-owned, linked incoming-damage split and redirection.
class_name DamageLinkRules
extends RefCounted

const LINK_FIELD := "damage_link"

static func link_error(value: Variant) -> String:
	if not value is Dictionary or value.is_empty(): return "Damage link must be a nonempty object."
	for key in value:
		if str(key) not in ["operation", "share_percent", "rounding", "fallback", "require_willing"]:
			return "Damage link has unsupported field '%s'." % str(key)
	var operation := str(value.get("operation", ""))
	if operation not in ["split", "redirect"]: return "Damage link operation must be split or redirect."
	var percent: Variant = value.get("share_percent", null)
	if not (percent is int or percent is float) or percent is bool or not is_finite(float(percent)) or float(percent) != float(int(percent)) or int(percent) < 1 or int(percent) > 100: return "Damage link share_percent must be an integer from 1 through 100."
	if operation == "split" and int(percent) >= 100: return "A split must leave damage with the original recipient."
	if str(value.get("rounding", "floor")) not in ["floor", "ceil"]: return "Damage link rounding must be floor or ceil."
	if str(value.get("fallback", "keep_original")) not in ["keep_original", "refuse"]: return "Damage link fallback must be keep_original or refuse."
	if value.has("require_willing") and not value["require_willing"] is bool: return "Damage link require_willing must be Boolean."
	return ""

static func grant(target, cast: Dictionary, policy: Dictionary) -> bool:
	if target == null or cast.is_empty() or not (target is Character or target is Dictionary): return false
	var err := link_error(policy)
	if not err.is_empty(): return false
	var source := str(cast.get("source_id", ""))
	var owner := str(cast.get("caster_id", ""))
	var target_id := _actor_id(target)
	if source.is_empty() or owner.is_empty() or target_id.is_empty() or target_id == owner: return false
	var record: Dictionary = SpellEffects.records(target).get(source, cast.duplicate(true))
	record["recipient_id"] = target_id
	record[LINK_FIELD] = policy.duplicate(true)
	SpellEffects.records(target)[source] = record
	if target is Dictionary: target["spell_effects"] = SpellEffects.records(target)
	return true

static func settle(target, amount: int, damage_type: String, decisions: Dictionary, source_character: Character, occurrence_id: int, bypass_layers: Array, original_raw_amount: int, reduction_prevented: int) -> Dictionary:
	if amount <= 0 or target == null or bool(decisions.get("_damage_link_child", false)):
		return {"handled": false}
	var candidates := _links(target)
	if candidates.is_empty(): return {"handled": false}
	var wanted := str(decisions.get("damage_link_source_instance_id", ""))
	var selected: Dictionary = {}
	if not wanted.is_empty():
		for option in candidates:
			if str(option.get("source_id", "")) == wanted: selected = option; break
		if selected.is_empty():
			var missing_fallback := str(decisions.get("damage_link_fallback", "keep_original"))
			return {"handled": true, "refused_choice": true, "fallback": missing_fallback if missing_fallback in ["keep_original", "refuse"] else "keep_original", "recipient_receipts": []}
	else:
		selected = candidates[0]
	if not _link_is_eligible(selected, target, decisions):
		var ineligible_policy: Dictionary = selected.get("record", {}).get(LINK_FIELD, {})
		return {"handled": true, "refused_choice": true, "fallback": str(ineligible_policy.get("fallback", "keep_original")), "recipient_receipts": []}
	if bool(decisions.get("damage_link_declined", false)):
		var declined_policy: Dictionary = selected.get("record", {}).get(LINK_FIELD, {})
		return {"handled": true, "declined": true, "fallback": str(declined_policy.get("fallback", "keep_original")), "recipient_receipts": []}
	var record: Dictionary = selected["record"]
	var link: Dictionary = record[LINK_FIELD]
	var linked_actor = selected["linked_actor"]
	var source_penalty := 0 if bool(decisions.get("_damage_response_child", false)) else CombatAction.damage_source_penalty(amount, source_character)
	amount -= source_penalty
	var pct := int(link["share_percent"])
	var transferred := int(floor(float(amount * pct) / 100.0))
	if str(link.get("rounding", "floor")) == "ceil" and (amount * pct) % 100 != 0: transferred += 1
	transferred = mini(amount, transferred)
	var primary_amount := amount - transferred
	var child_decisions := decisions.duplicate()
	child_decisions["_damage_link_child"] = true
	child_decisions.erase("damage_link_source_instance_id")
	child_decisions.erase("damage_link_declined")
	child_decisions["damage_source_instance_id"] = str(decisions.get("damage_source_instance_id", source_character.character_id if source_character != null else ""))
	var receipts: Array[Dictionary] = []
	if primary_amount > 0:
		var primary := CombatAction.resolve_damage(target, primary_amount, damage_type, child_decisions, false, false, source_character, occurrence_id, bypass_layers, primary_amount, 0)
		primary["actor_id"] = _actor_id(target)
		primary["role"] = "original"
		receipts.append(primary)
	if transferred > 0:
		# The original target keeps its aftermath; a linked share is ordinary damage.
		var linked_decisions := child_decisions.duplicate()
		linked_decisions.erase("zero_hp_aftermath")
		var linked := CombatAction.resolve_damage(linked_actor, transferred, damage_type, linked_decisions, false, false, source_character, occurrence_id, bypass_layers, transferred, 0)
		linked["actor_id"] = _actor_id(linked_actor)
		linked["role"] = "linked"
		linked["link_source_instance_id"] = str(selected["source_id"])
		receipts.append(linked)
	var total := _sum(receipts, "damage")
	var resolved := _sum(receipts, "resolved")
	var absorbed := _sum(receipts, "absorbed")
	var hp_loss := _sum(receipts, "hp_loss")
	var prevented := maxi(0, original_raw_amount - resolved)
	var primary_receipt: Dictionary = receipts[0] if not receipts.is_empty() and str(receipts[0].get("role", "")) == "original" else receipts[0] if not receipts.is_empty() else {}
	var combined := primary_receipt.duplicate(true)
	combined["countereffect_receipts"] = [] # Consequences belong to recipient receipts.
	combined.merge({"damage": total, "raw": maxi(0, original_raw_amount), "resolved": resolved, "prevented": prevented, "reduction_prevented": maxi(0, reduction_prevented), "absorbed": absorbed, "hp_loss": hp_loss,
		"ward_absorbed": _sum(receipts, "ward_absorbed"), "temp_hp_absorbed": _sum(receipts, "temp_hp_absorbed"), "recipient_receipts": receipts.duplicate(true), "source_roll_penalty": source_penalty,
		"damage_source_actor_id": str(decisions.get("damage_source_actor_id", source_character.character_id if source_character != null else "")),
		"damage_source_instance_id": str(decisions.get("damage_source_instance_id", source_character.character_id if source_character != null else "")),
		"damage_occurrence_id": occurrence_id,
		"damage_link": {"operation": str(link["operation"]), "source_instance_id": str(selected["source_id"]), "linked_actor_id": _actor_id(linked_actor), "share_percent": pct, "amount_transferred": transferred, "amount_retained": primary_amount, "rounding": str(link.get("rounding", "floor")), "receipts": receipts.duplicate(true)}} , true)
	return {"handled": true, "receipt": combined}

## One aftermath entry per actual recipient of this occurrence, across its typed
## components. Empty means the caller should retain its ordinary unlinked path.
static func recipient_settlements(target, result: Dictionary, monsters: Array = []) -> Array[Dictionary]:
	var components: Array = result.get("damage_components", [])
	var has_link := false
	for component in components:
		var receipt: Dictionary = component.get("receipt", component)
		if not receipt.get("recipient_receipts", []).is_empty(): has_link = true
		if not receipt.get("countereffect_receipts", []).is_empty(): has_link = true
	if not has_link: return []
	var entries: Array[Dictionary] = []
	for component in components:
		var receipt: Dictionary = component.get("receipt", component)
		var recipients: Array = receipt.get("recipient_receipts", [])
		if recipients.is_empty(): recipients = [{"actor_id": _actor_id(target), "resolved": receipt.get("resolved", 0), "damage": receipt.get("hp_loss", 0), "role": "original", "knocked_out": bool(receipt.get("knocked_out", false))}]
		for recipient in recipients:
			var actor = target if str(recipient.get("role", "")) == "original" else PartyManager.characters.get(str(recipient.get("actor_id", "")))
			if actor == null: continue
			var entry: Dictionary = {}
			for existing in entries:
				if existing["actor"] == actor and not existing.has("occurrence"): entry = existing; break
			if entry.is_empty():
				entry = {"actor": actor, "resolved": 0, "damage": 0}
				entries.append(entry)
			entry["resolved"] += int(recipient.get("resolved", 0))
			entry["damage"] += int(recipient.get("hp_loss", recipient.get("damage", 0)))
			entry["knocked_out"] = bool(entry.get("knocked_out", false)) or bool(recipient.get("knocked_out", false))
		_collect_counter_settlements(receipt, entries, target, monsters)
	return entries

static func _collect_counter_settlements(receipt: Dictionary, entries: Array[Dictionary], target, monsters: Array) -> void:
	# Linked children retain their own consequences; never charge their parent
	# aggregate to the original target a second time.
	for recipient in receipt.get("recipient_receipts", []):
		_collect_counter_settlements(recipient, entries, target, monsters)
	for consequence in receipt.get("countereffect_receipts", []):
		if not consequence.has("damage_receipt"): continue
		var child: Dictionary = consequence.damage_receipt
		var actor = consequence.get("recipient_actor")
		if actor == null and str(consequence.get("recipient_id", "")) == _actor_id(target): actor = target
		if actor == null:
			for monster in monsters:
				if str(monster.get("id", "")) == str(consequence.get("recipient_id", "")): actor = monster; break
		if actor == null: continue
		if child.get("recipient_receipts", []).is_empty():
			var entry: Dictionary = {}
			for existing in entries:
				if is_same(existing.actor, actor) and int(existing.get("occurrence", -1)) == int(child.get("damage_occurrence_id", 0)): entry = existing; break
			if entry.is_empty():
				entry = {"actor": actor, "resolved": 0, "damage": 0, "occurrence": int(child.get("damage_occurrence_id", 0)), "source_actor": PartyManager.characters.get(str(consequence.get("reacting_actor_id", "")))}
				entries.append(entry)
			entry.resolved += int(child.get("resolved", 0))
			entry.damage += int(child.get("hp_loss", 0))
			entry["knocked_out"] = bool(entry.get("knocked_out", false)) or bool(child.get("knocked_out", false))
		else:
			for recipient in child.recipient_receipts:
				var linked_actor = actor if str(recipient.get("role", "")) == "original" else PartyManager.characters.get(str(recipient.get("actor_id", "")))
				if linked_actor == null: continue
				var entry: Dictionary = {}
				for existing in entries:
					if is_same(existing.actor, linked_actor) and int(existing.get("occurrence", -1)) == int(child.get("damage_occurrence_id", 0)): entry = existing; break
				if entry.is_empty():
					entry = {"actor": linked_actor, "resolved": 0, "damage": 0, "occurrence": int(child.get("damage_occurrence_id", 0)), "source_actor": PartyManager.characters.get(str(consequence.get("reacting_actor_id", "")))}
					entries.append(entry)
				entry.resolved += int(recipient.get("resolved", 0))
				entry.damage += int(recipient.get("hp_loss", 0))
				entry["knocked_out"] = bool(entry.get("knocked_out", false)) or bool(recipient.get("knocked_out", false))
		_collect_counter_settlements(child, entries, target, monsters)

static func _links(target) -> Array[Dictionary]:
	var records := SpellEffects.records(target)
	var target_id := _actor_id(target)
	var out: Array[Dictionary] = []
	for source in records:
		var record: Variant = records[source]
		if not record is Dictionary or not record.get(LINK_FIELD) is Dictionary: continue
		if str(record.get("recipient_id", "")) != target_id: continue
		if str(record.get("source_id", source)) != str(source): continue
		if not str(source).begins_with("spell:%s:" % str(record.get("caster_id", ""))): continue
		var caster_id := str(record.get("caster_id", ""))
		var linked_actor = PartyManager.characters.get(caster_id)
		var policy: Dictionary = record[LINK_FIELD]
		if not link_error(policy).is_empty(): continue
		out.append({"source_id": str(source), "record": record, "linked_actor": linked_actor})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.source_id) < str(b.source_id))
	return out

static func _link_is_eligible(option: Dictionary, target, decisions: Dictionary) -> bool:
	var linked_actor = option.get("linked_actor")
	if linked_actor == null or linked_actor == target: return false
	var players: Variant = decisions.get("players", null)
	var monsters: Variant = decisions.get("monsters", null)
	if players is Array and not _contains_actor(players, linked_actor): return false
	if monsters is Array and not players is Array and not _contains_actor(monsters, linked_actor): return false
	var policy: Dictionary = option.get("record", {}).get(LINK_FIELD, {})
	if bool(policy.get("require_willing", false)) and (not linked_actor is Character or linked_actor.willingness != "willing"): return false
	return true

static func _contains_actor(entries: Array, actor) -> bool:
	for entry in entries:
		var candidate = entry.get("character", entry) if entry is Dictionary else entry
		if candidate == actor: return true
	return false

static func _actor_id(actor) -> String:
	return str(actor.character_id) if actor is Character else str(actor.get("id", "")) if actor is Dictionary else ""

static func _sum(receipts: Array[Dictionary], key: String) -> int:
	var total := 0
	for receipt in receipts: total += int(receipt.get(key, 0))
	return total
