class_name CurseRules
extends RefCounted
## S-202 persistent curse and attunement restrictions on exact copies.
## Item policy "curse": {removal: blocked|allowed, lingering: {blocks_attunement},
## break: {spells: [...], min_slot_level}}. Items without a policy keep legacy behavior.

const KEYS := ["removal", "lingering", "break"]

static func policy(definition_id: String) -> Dictionary:
	var p: Variant = DataLoader.get_item(definition_id).get("curse", {})
	return p if p is Dictionary else {}

static func policy_error(item: Dictionary) -> String:
	var p: Variant = item.get("curse")
	if not p is Dictionary or p.keys().any(func(k): return str(k) not in KEYS): return "curse policy is invalid"
	if not bool(item.get("cursed", false)) or not bool(item.get("requires_attunement", false)): return "curse policy requires a cursed attunement item"
	if str(p.get("removal", "blocked")) not in ["blocked", "allowed"]: return "curse removal must be blocked or allowed"
	if p.has("lingering") and (not p.lingering is Dictionary or p.lingering.keys().any(func(k): return str(k) != "blocks_attunement") or not p.lingering.get("blocks_attunement") is bool): return "curse lingering policy is invalid"
	var b: Variant = p.get("break")
	if not b is Dictionary or b.keys().any(func(k): return str(k) not in ["spells", "min_slot_level"]): return "curse needs a break requirement"
	if not b.get("spells") is Array or b.spells.is_empty() or b.spells.any(func(s): return not s is String or DataLoader.get_spell(str(s)).is_empty()): return "curse break spells are invalid"
	var level: Variant = b.get("min_slot_level", 0)
	if not (level is int or level is float) or float(level) != floorf(float(level)) or int(level) < 0 or int(level) > 9: return "curse min_slot_level is invalid"
	return ""

## Whether this exact cursed copy may leave its slot (the curse stays on the copy).
static func removal_allowed(record: Dictionary) -> bool:
	return str(policy(str(record.get("definition_id", ""))).get("removal", "blocked")) == "allowed"

static func is_cursed(record: Dictionary) -> bool:
	return bool(record.get("state", {}).get("cursed_attunement", false))

## Inventory hook: a cursed attuned copy left its holder by destruction or loss.
static func on_removed(actor, record: Dictionary) -> void:
	if not actor is Character or not is_cursed(record) or str(record.state.get("attuned_to", "")) != actor.character_id: return
	var p := policy(str(record.get("definition_id", "")))
	if not p.get("lingering") is Dictionary: return
	actor.item_curses[str(record.instance_id)] = {"definition_id": str(record.definition_id), "blocks_attunement": bool(p.lingering.get("blocks_attunement", false))}

static func attune_error(actor) -> String:
	if not actor is Character: return ""
	for c in actor.item_curses.values():
		if bool(c.get("blocks_attunement", false)): return "A lingering curse prevents new attunement."
	return ""

static func can_break(definition_id: String, spell_id: String, slot_level: int) -> bool:
	var p := policy(definition_id)
	if p.is_empty(): return spell_id == "remove_curse"
	var b: Dictionary = p.get("break", {})
	return spell_id in b.get("spells", []) and slot_level >= int(b.get("min_slot_level", 0))

## Break exactly the curses on this actor whose declared requirements the cast meets.
static func break_with(actor: Character, spell_id: String, slot_level: int) -> Dictionary:
	var result := {"broken": [], "lingering_ended": [], "refused": []}
	if actor == null: return result
	var inv := actor.inventory
	inv.copies.sync(inv)
	for id in inv.copies.records.keys():
		var record: Dictionary = inv.copies.records[id]
		if not is_cursed(record) or str(record.state.get("attuned_to", "")) != actor.character_id: continue
		if not can_break(str(record.definition_id), spell_id, slot_level):
			result.refused.append(str(id))
			continue
		inv.unattune_instance(str(id), actor.character_id, true)
		result.broken.append(str(id))
	for id in actor.item_curses.keys():
		if can_break(str(actor.item_curses[id].get("definition_id", "")), spell_id, slot_level):
			actor.item_curses.erase(id)
			result.lingering_ended.append(str(id))
		else: result.refused.append(str(id))
	return result

static func restore(actor: Character, data: Dictionary) -> void:
	actor.item_curses = data.get("item_curses", {}).duplicate(true) if data.get("item_curses", {}) is Dictionary else {}

static func saved_error(dto: Dictionary) -> String:
	var curses: Variant = dto.get("item_curses", {})
	if not curses is Dictionary: return "item curses are invalid"
	var held: Dictionary = dto.get("inventory", {}).get("copies", {}).get("records", {}) if dto.get("inventory", {}).get("copies", {}).get("records") is Dictionary else {}
	for id in curses:
		var c: Variant = curses[id]
		if not c is Dictionary or c.keys().any(func(k): return str(k) not in ["definition_id", "blocks_attunement"]) or not c.get("blocks_attunement") is bool: return "item curse record is invalid"
		var p := policy(str(c.get("definition_id", "")))
		if not p.get("lingering") is Dictionary or bool(p.lingering.get("blocks_attunement", false)) != bool(c.blocks_attunement): return "item curse does not match a declared lingering curse"
		if held.has(id): return "a lingering curse names a copy still held"
	return ""
