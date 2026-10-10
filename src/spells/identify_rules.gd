## Builds Identify results from item and active-spell records the game stores.
class_name IdentifyRules
extends RefCounted

static func is_magic_item(item: Dictionary) -> bool:
	if bool(item.get("magical", false)) or item.has("rarity"):
		return true
	var source := str(item.get("_source", ""))	
	return source.contains("/items/imported_magic_")


static func item_report(item: Dictionary, copy_state: Dictionary = {}) -> String:
	var item_name := str(item.get("name", "Item"))
	if not is_magic_item(item):
		return "%s is not a magic item in its current record." % item_name
	var lines: Array[String] = ["Identify reveals %s's recorded properties:" % item_name]
	var description := str(item.get("description", "")).strip_edges()
	if not description.is_empty():
		lines.append(description)
	for key in ["damage", "damage_type", "armor_class", "ac_bonus", "range", "properties", "effects"]:
		if not item.has(key) or str(item[key]).is_empty() or str(item[key]) == "[]":
			continue
		lines.append("%s: %s" % [key.replace("_", " ").capitalize(), str(item[key])])
	var description_lower := description.to_lower()
	if item.has("requires_attunement") or item.has("attunement"):
		lines.append("Attunement: %s%s" % [str(item.get("requires_attunement", item.get("attunement", false))), " (currently attuned)" if not str(copy_state.get("attuned_to", "")).is_empty() else " (not currently attuned)"])
	elif not description_lower.contains("attunement"):
		lines.append("Attunement requirement: not recorded in the item data.")
	if copy_state.has("charges"):
		lines.append("Charges: %d" % int(copy_state["charges"]))
	elif item.has("charges") or item.has("maximum_charges"):
		lines.append("Charges: %s" % str(item.get("charges", item.get("maximum_charges", 0))))
	elif not description_lower.contains("charge"):
		lines.append("Charge count: not recorded in the item data.")
	if item.has("created_by_spell"):
		lines.append("Created by: %s" % str(item["created_by_spell"]))
	return "\n".join(lines)


static func ongoing_spell_names(target) -> Array[String]:
	var names: Array[String] = []
	for record in SpellEffects.records(target).values():
		if not record is Dictionary:
			continue
		var spell_id := str(record.get("spell_id", ""))
		if spell_id.is_empty() or spell_id == "identify" or spell_id in names:
			continue
		var spell := DataLoader.get_spell(spell_id)
		names.append(str(spell.get("name", spell_id.replace("_", " ").capitalize())))
	names.sort()
	return names
