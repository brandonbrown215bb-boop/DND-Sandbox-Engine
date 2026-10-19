## Sorcerer-only Font of Magic conversions.
class_name SorcererRules
extends RefCounted

const SLOT_POINT_COSTS := {1: 2, 2: 3, 3: 5, 4: 6, 5: 7}
const SLOT_MINIMUM_LEVELS := {1: 2, 2: 3, 3: 5, 4: 7, 5: 9}
const QUICKENED_SPELL_COST := 2
const TWINNED_SPELL_COST := 1
const METAMAGIC_OPTIONS := {
	"careful_spell": "Careful Spell", "distant_spell": "Distant Spell",
	"empowered_spell": "Empowered Spell", "extended_spell": "Extended Spell",
	"heightened_spell": "Heightened Spell", "quickened_spell": "Quickened Spell",
	"seeking_spell": "Seeking Spell", "subtle_spell": "Subtle Spell",
	"transmuted_spell": "Transmuted Spell", "twinned_spell": "Twinned Spell"
}
const TRANSMUTED_DAMAGE_TYPES := ["acid", "cold", "fire", "lightning", "poison", "thunder"]


static func metamagic_capacity(level: int) -> int:
	return (2 if level >= 2 else 0) + (2 if level >= 10 else 0) + (2 if level >= 17 else 0)


static func metamagic_options() -> Dictionary:
	return METAMAGIC_OPTIONS.duplicate()


static func can_quicken_spell(c: Character, spell_data: Dictionary, used_levelled_spell_this_turn: bool, turn_budget: CombatTurnBudget, free_cost_available: bool = false) -> bool:
	if c == null or c.class_id != "sorcerer" or not c.has_feature("sorcerer_metamagic"):
		return false
	if "quickened_spell" not in c.sorcerer_metamagic_choices or str(spell_data.get("casting_time", "action")) != "action":
		return false
	if used_levelled_spell_this_turn or bool(c.feature_uses.get("sorcerer_quickened_spell_cast_this_turn", false)):
		return false
	if turn_budget == null or not turn_budget.can_spend("bonus_action"):
		return false
	return c.get_sorcery_points() >= QUICKENED_SPELL_COST or free_cost_available


static func apply_quickened_spell(spell_data: Dictionary, free_cost: bool = false) -> Dictionary:
	var quickened := spell_data.duplicate(true)
	quickened["casting_time"] = "bonus_action"
	quickened["_metamagic_quickened"] = true
	quickened["_metamagic_quickened_free"] = free_cost
	return quickened


static func quickened_spell_blocks_cast(c: Character, spell_data: Dictionary) -> bool:
	return c != null and c.class_id == "sorcerer" and int(spell_data.get("level", 0)) >= 1 and bool(c.feature_uses.get("sorcerer_quickened_spell_cast_this_turn", false))


static func careful_spell_target_limit(c: Character) -> int:
	return maxi(1, c.ability_scores.get_ability_modifier("CHA")) if c != null else 1


static func careful_spell_target_id(target) -> String:
	if target is Character:
		return str(target.character_id)
	if target is Dictionary:
		return str(target.get("id", ""))
	return ""


static func is_careful_spell_target(caster: Character, spell_data: Dictionary, target, selected_target_ids: Array) -> bool:
	if caster == null or caster.class_id != "sorcerer" or not caster.has_feature("sorcerer_metamagic"):
		return false
	if "careful_spell" not in caster.sorcerer_metamagic_choices or not CombatAction.spell_requires_saving_throw(spell_data):
		return false
	var target_id := careful_spell_target_id(target)
	return not target_id.is_empty() and target_id in selected_target_ids


static func can_extend_spell(caster: Character, spell_data: Dictionary) -> bool:
	# Fixed source-carrier durations have no captured upgrade policy yet.
	if SharedSpell.has_effect(spell_data, "grant_source_benefits"):
		return false
	return caster != null and caster.class_id == "sorcerer" and caster.has_feature("sorcerer_metamagic") and "extended_spell" in caster.sorcerer_metamagic_choices and not bool(spell_data.get("_metamagic_extended", false)) and int(spell_data.get("duration_seconds", 0)) >= 60


static func apply_extended_spell(spell_data: Dictionary) -> Dictionary:
	var extended := spell_data.duplicate(true)
	var duration_seconds := int(extended.get("duration_seconds", 0))
	if duration_seconds < 60:
		return extended
	extended["duration_seconds"] = mini(duration_seconds * 2, 86400)
	extended["_metamagic_extended"] = true
	# Timed effects use combat rounds (six seconds) in this game. Permanent
	# effects use -1 and are deliberately left unchanged.
	if extended.has("condition_duration"):
		extended["condition_duration"] = mini(maxi(1, int(extended["condition_duration"])) * 2, 14400)
	for effect in extended.get("effects", []):
		if effect is Dictionary and effect.has("duration") and int(effect["duration"]) > 0:
			effect["duration"] = mini(int(effect["duration"]) * 2, 14400)
	return extended


static func can_subtle_spell(caster: Character, spell_data: Dictionary) -> bool:
	if caster == null or caster.class_id != "sorcerer" or not caster.has_feature("sorcerer_metamagic") or "subtle_spell" not in caster.sorcerer_metamagic_choices or bool(spell_data.get("_metamagic_subtle", false)):
		return false
	var components: Variant = spell_data.get("components", null)
	if not components is Array or components.is_empty():
		return false
	for component in components:
		if str(component) in ["V", "S"]:
			return true
		if str(component) == "M" and int(spell_data.get("material_component_cost", 0)) <= 0 and not bool(spell_data.get("material_component_consumed", false)):
			return true
	return false


static func apply_subtle_spell(spell_data: Dictionary) -> Dictionary:
	var subtle := spell_data.duplicate(true)
	var remaining_components: Array = []
	var removed_components: Array[String] = []
	for component in subtle.get("components", []):
		var component_id := str(component)
		if component_id in ["V", "S"]:
			removed_components.append(component_id)
		elif component_id == "M" and int(subtle.get("material_component_cost", 0)) <= 0 and not bool(subtle.get("material_component_consumed", false)):
			removed_components.append(component_id)
		else:
			remaining_components.append(component)
	if removed_components.is_empty():
		return subtle
	subtle["components"] = remaining_components
	subtle["_metamagic_subtle"] = true
	subtle["_metamagic_subtle_removed_components"] = removed_components
	return subtle


static func twinned_extra_target_count(spell_data: Dictionary, slot_level: int) -> int:
	var spell_level := int(spell_data.get("level", 0))
	var upcast_data: Dictionary = spell_data.get("upcast", {})
	var extra_targets_per_level := int(upcast_data.get("additional_targets_per_level", upcast_data.get("extra_targets_per_level", 0)))
	if spell_level <= 0 or extra_targets_per_level <= 0 or slot_level < spell_level or slot_level >= 9:
		return 0
	return extra_targets_per_level


static func can_twinned_spell(caster: Character, spell_data: Dictionary, slot_level: int, free_cost_available: bool = false) -> bool:
	if caster == null or caster.class_id != "sorcerer" or not caster.has_feature("sorcerer_metamagic") or "twinned_spell" not in caster.sorcerer_metamagic_choices:
		return false
	# Twinned Spell adds one effective spell level. Test target scaling after
	# that increase so a level-1 spell with one extra target at level 2 can be
	# twinned while spent from a level-1 slot.
	if bool(spell_data.get("_metamagic_twinned", false)) or twinned_extra_target_count(spell_data, slot_level + 1) <= 0:
		return false
	return caster.get_sorcery_points() >= TWINNED_SPELL_COST or free_cost_available


static func apply_twinned_spell(spell_data: Dictionary) -> Dictionary:
	var twinned := spell_data.duplicate(true)
	twinned["_metamagic_twinned"] = true
	twinned["_metamagic_twinned_free"] = false
	return twinned


static func remaining_metamagic_points(c: Character, spell_data: Dictionary) -> int:
	if c == null:
		return 0
	var remaining := c.get_sorcery_points()
	if bool(spell_data.get("_metamagic_quickened", false)) and not bool(spell_data.get("_metamagic_quickened_free", false)):
		remaining -= QUICKENED_SPELL_COST
	if bool(spell_data.get("_metamagic_distant", false)) and not bool(spell_data.get("_metamagic_distant_free", false)):
		remaining -= 1
	if bool(spell_data.get("_metamagic_transmuted", false)) and not bool(spell_data.get("_metamagic_transmuted_free", false)):
		remaining -= 1
	if bool(spell_data.get("_metamagic_subtle", false)) and not bool(spell_data.get("_metamagic_subtle_free", false)):
		remaining -= 1
	if bool(spell_data.get("_metamagic_twinned", false)) and not bool(spell_data.get("_metamagic_twinned_free", false)):
		remaining -= TWINNED_SPELL_COST
	return maxi(0, remaining)


static func mark_spell_cast_this_turn(c: Character, spell_data: Dictionary) -> void:
	if c == null or c.class_id != "sorcerer" or int(spell_data.get("level", 0)) < 1:
		return
	c.feature_uses["sorcerer_levelled_spell_cast_this_turn"] = true


static func distant_spell_range(range_in_hexes: int) -> int:
	if range_in_hexes <= 0:
		return range_in_hexes
	return 6 if range_in_hexes == 1 else range_in_hexes * 2


static func transmuted_damage_options(damage_type: String) -> Array[String]:
	var options: Array[String] = []
	if damage_type not in TRANSMUTED_DAMAGE_TYPES:
		return options
	for candidate in TRANSMUTED_DAMAGE_TYPES:
		if candidate != damage_type:
			options.append(candidate)
	return options


static func apply_transmuted_damage_type(spell_data: Dictionary, selected_type: String) -> bool:
	if not (spell_data.has("damage") or spell_data.has("damage_per_dart") or spell_data.has("damage_per_ray")):
		return false
	if selected_type not in transmuted_damage_options(str(spell_data.get("damage_type", ""))):
		return false
	spell_data["damage_type"] = selected_type
	return true


static func available_slot_conversion_levels(c: Character) -> Array[int]:
	var levels: Array[int] = []
	if c == null or c.class_id != "sorcerer" or not c.has_feature("sorcerer_sorcery_points"):
		return levels
	for key in c.spell_slots:
		var level := int(key)
		if level > 0 and int(c.spell_slots[key]) > 0 and c.get_sorcery_points() + level <= c.get_max_sorcery_points():
			levels.append(level)
	levels.sort()
	return levels


static func available_created_slot_levels(c: Character) -> Array[int]:
	var levels: Array[int] = []
	if c == null or c.class_id != "sorcerer" or not c.has_feature("sorcerer_sorcery_points"):
		return levels
	for level in SLOT_POINT_COSTS:
		if c.level >= int(SLOT_MINIMUM_LEVELS[level]) and c.get_sorcery_points() >= int(SLOT_POINT_COSTS[level]):
			levels.append(int(level))
	levels.sort()
	return levels


static func spend_metamagic_cost(c: Character, point_cost: int, decisions: Dictionary) -> bool:
	if c == null or point_cost < 0:
		return false
	if bool(decisions.get("metamagic:arcane_apotheosis", false)) and c.has_feature("sorcerer_arcane_apotheosis") and c.has_condition("innate_sorcery") and not bool(c.feature_uses.get("sorcerer_arcane_apotheosis_used_this_turn", false)):
		c.feature_uses["sorcerer_arcane_apotheosis_used_this_turn"] = true
		return true
	return c.spend_sorcery_points(point_cost)


static func convert_slot_to_points(c: Character, slot_level: int) -> Dictionary:
	if c == null or c.class_id != "sorcerer" or not c.has_feature("sorcerer_sorcery_points"):
		return {"success": false, "message": "Font of Magic requires a Sorcerer with Sorcery Points."}
	if slot_level < 1 or int(c.spell_slots.get(str(slot_level), 0)) <= 0:
		return {"success": false, "message": "No spell slot of that level is available."}
	if c.get_sorcery_points() + slot_level > c.get_max_sorcery_points():
		return {"success": false, "message": "Converting that slot would exceed your Sorcery Point maximum."}
	c.spell_slots[str(slot_level)] = int(c.spell_slots[str(slot_level)]) - 1
	c.feature_uses["sorcery_points"] = c.get_sorcery_points() + slot_level
	return {"success": true, "points": slot_level, "message": "Convert a level %d spell slot into %d Sorcery Point%s." % [slot_level, slot_level, "" if slot_level == 1 else "s"]}


static func create_spell_slot(c: Character, slot_level: int, budget: CombatTurnBudget = null) -> Dictionary:
	if c == null or c.class_id != "sorcerer" or not c.has_feature("sorcerer_sorcery_points"):
		return {"success": false, "message": "Font of Magic requires a Sorcerer with Sorcery Points."}
	if not SLOT_POINT_COSTS.has(slot_level) or c.level < int(SLOT_MINIMUM_LEVELS.get(slot_level, 99)):
		return {"success": false, "message": "Your Sorcerer level cannot create a slot of that level."}
	if c.get_sorcery_points() < int(SLOT_POINT_COSTS[slot_level]):
		return {"success": false, "message": "Creating a level %d slot costs %d Sorcery Points." % [slot_level, int(SLOT_POINT_COSTS[slot_level])]}
	if budget != null and not budget.can_spend("bonus_action"):
		return {"success": false, "message": "Creating a spell slot requires your Bonus Action."}
	c.spend_sorcery_points(int(SLOT_POINT_COSTS[slot_level]))
	var key := str(slot_level)
	c.spell_slots[key] = int(c.spell_slots.get(key, 0)) + 1
	if budget != null:
		budget.spend("bonus_action")
	return {"success": true, "slot_level": slot_level, "message": "Create one level %d spell slot for %d Sorcery Points. It disappears after a Long Rest." % [slot_level, int(SLOT_POINT_COSTS[slot_level])]}
