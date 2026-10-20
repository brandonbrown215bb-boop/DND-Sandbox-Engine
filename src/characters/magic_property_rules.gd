class_name MagicPropertyRules
extends RefCounted
## S-203 suppression, restoration and destruction of specified magical properties
## on exact copies. Suppression is owned by a live source record; when that source
## ends the still-owned copy's effects return without reacquisition (attunement,
## charges and identity are untouched). Destruction is permanent and names its
## cause. Unlisted properties, and every mundane field, stay as they were.

const PROPERTIES := ["source_benefits", "spell_permissions", "incoming_negation_rule", "attachment_sets"]

static func effect_error(effect: Dictionary) -> String:
	if effect.keys().any(func(k): return str(k) not in ["type", "properties", "mode"]): return "Magic suppression accepts only type, properties and mode."
	var props: Variant = effect.get("properties")
	if not props is Array or props.is_empty() or props.any(func(p): return not p is String or str(p) not in PROPERTIES): return "Magic suppression needs known magical properties."
	var seen := {}
	for p in props:
		if seen.has(p): return "Magic suppression lists a property twice."
		seen[p] = true
	if str(effect.get("mode", "suppress")) not in ["suppress", "destroy"]: return "Magic suppression mode must be suppress or destroy."
	return ""

## Whether the item definition actually has this magical property.
static func has_property(definition_id: String, property: String) -> bool:
	var item := DataLoader.get_item(definition_id)
	if not (bool(item.get("magical", false)) or item.has("rarity")): return false
	if property == "attachment_sets": return not item.get("attachments", {}).get("sets", []).is_empty()
	return item.has(property)

## The shared effect on the self-cast actor: affects its equipped exact copies.
static func apply(actor: Character, cast: Dictionary, effect: Dictionary) -> Dictionary:
	if actor == null or not effect_error(effect).is_empty() or str(cast.get("source_id", "")).is_empty() or cast.get("caster_id", "") != actor.character_id:
		return {"applied": false, "reason": "invalid source"}
	var source := str(cast.source_id)
	if actor.spell_effects.has(source): return {"applied": false, "reason": "source already applied"}
	var mode := str(effect.get("mode", "suppress"))
	var inv := actor.inventory
	inv.copies.sync(inv)
	var affected := {}
	for copy_id in inv.copies.equipped.values():
		var definition := str(inv.copies.records.get(copy_id, {}).get("definition_id", ""))
		var props: Array = effect.properties.filter(func(p): return has_property(definition, str(p)) and not destroyed(inv.copies.records.get(copy_id, {}), str(p)))
		if not props.is_empty(): affected[str(copy_id)] = props
	if affected.is_empty(): return {"applied": false, "reason": "No equipped copy has those magical properties."}
	if mode == "destroy":
		for copy_id in affected:
			var record: Dictionary = inv.copies.records[copy_id]
			var gone: Dictionary = record.state.get("destroyed_magic", {})
			for p in affected[copy_id]: gone[str(p)] = {"cause": str(cast.get("spell_id", "")), "source_id": source}
			record.state["destroyed_magic"] = gone
	var record := cast.duplicate(true)
	record["magic_suppression"] = {"mode": mode, "properties": effect.properties.duplicate(), "copies": affected}
	actor.spell_effects[source] = record
	return {"applied": true, "mode": mode, "copies": affected}

static func destroyed(record: Dictionary, property: String) -> bool:
	return record.get("state", {}).get("destroyed_magic", {}).has(property)

## Production hook: false while a live source suppresses, or after a cause destroyed, this property.
static func active(actor, copy_id: String, property: String) -> bool:
	if not actor is Character: return true
	if destroyed(actor.inventory.copies.records.get(copy_id, {}), property): return false
	for record in actor.spell_effects.values():
		var s: Variant = record.get("magic_suppression") if record is Dictionary else null
		if s is Dictionary and str(s.get("mode", "")) == "suppress" and property in s.get("copies", {}).get(copy_id, []): return false
	return true

static func saved_error(dto: Dictionary) -> String:
	var records: Dictionary = dto.get("inventory", {}).get("copies", {}).get("records", {}) if dto.get("inventory", {}).get("copies", {}).get("records") is Dictionary else {}
	for record in records.values():
		if not record is Dictionary or not record.get("state") is Dictionary or not record.state.has("destroyed_magic"): continue
		var gone: Variant = record.state.destroyed_magic
		if not gone is Dictionary or gone.is_empty(): return "destroyed magic is malformed"
		for p in gone:
			if not has_property(str(record.get("definition_id", "")), str(p)): return "destroyed magic names a property the item lacks"
			var why: Variant = gone[p]
			if not why is Dictionary or why.size() != 2 or str(why.get("cause", "")).is_empty() or str(why.get("source_id", "")).is_empty(): return "destroyed magic lacks its cause"
	for source in dto.get("spell_effects", {}):
		var record: Variant = dto.spell_effects[source]
		if not record is Dictionary or not record.has("magic_suppression"): continue
		var s: Variant = record.magic_suppression
		var declared := {}
		for e in DataLoader.get_spell(str(record.get("spell_id", ""))).get("effects", []):
			if e is Dictionary and e.get("type", "") == "suppress_item_magic": declared = e
		if declared.is_empty() or not s is Dictionary or s.keys().size() != 3 or str(s.get("mode", "")) != str(declared.get("mode", "suppress")) or s.get("properties") != declared.get("properties"): return "saved magic suppression differs from its spell"
		if str(record.get("caster_id", "")) != str(dto.get("character_id", "")) or not str(source).begins_with("spell:%s:" % str(dto.get("character_id", ""))): return "saved magic suppression has an invalid owner"
		if not s.get("copies") is Dictionary or s.copies.is_empty(): return "saved magic suppression names no copies"
		for copy_id in s.copies:
			var props: Variant = s.copies[copy_id]
			if not props is Array or props.is_empty() or props.any(func(p): return str(p) not in declared.properties): return "saved magic suppression widens its properties"
	return ""
