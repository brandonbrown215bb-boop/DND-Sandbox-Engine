class_name WardRules
extends RefCounted

const CURRENT_WARD_STATE_VERSION := 1
const SUPPORTED_CREATION_TRIGGERS := ["spell_cast_with_slot"]
const SUPPORTED_CREATION_USES_PER := ["long_rest"]
const SUPPORTED_ABILITIES := ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
const SUPPORTED_SCHOOLS := [
	"Abjuration", "Conjuration", "Divination", "Enchantment",
	"Evocation", "Illusion", "Necromancy", "Transmutation"
]
const SUPPORTED_PROJECTION_TRIGGERS := ["visible_creature_damaged"]
const SUPPORTED_PROJECTION_ACTION_COSTS := ["reaction"]
const SUPPORTED_PROJECTION_PREDICATES := [
	"visible_creature_within_range",
	"ally_visible_within_range"
]

static var _damage_occurrence_serial: int = 0


static func next_damage_occurrence_id() -> int:
	_damage_occurrence_serial += 1
	return _damage_occurrence_serial


static func pool_definitions(character: Character) -> Array[Dictionary]:
	var pools: Array[Dictionary] = []
	if character == null:
		return pools
	for feat in character.features:
		if not (feat is Dictionary) or not bool(feat.get("enabled", true)):
			continue
		var feature_id := str(feat.get("id", "")).strip_edges()
		var feature_name := str(feat.get("name", feature_id)).strip_edges()
		for effect in feat.get("effects", []):
			if not (effect is Dictionary) or str(effect.get("type", "")) != "damage_ward_pool":
				continue
			var pool_id := str(effect.get("pool_id", feature_id)).strip_edges()
			if pool_id.is_empty():
				continue
			var schools: Array[String] = []
			for school in effect.get("trigger_schools", []):
				var s := str(school).strip_edges()
				if not s.is_empty():
					schools.append(s)
			pools.append({
				"pool_id": pool_id,
				"feature_id": feature_id,
				"feature_name": feature_name,
				"creation_trigger": str(effect.get("creation_trigger", "spell_cast_with_slot")).strip_edges(),
				"trigger_schools": schools,
				"creation_uses_per": str(effect.get("creation_uses_per", "long_rest")).strip_edges(),
				"max_hp_level_multiplier": int(effect.get("max_hp_level_multiplier", 2)),
				"max_hp_ability": str(effect.get("max_hp_ability", "INT")).strip_edges().to_upper(),
				"max_hp_flat_bonus": int(effect.get("max_hp_flat_bonus", 0)),
				"recharge_slot_multiplier": int(effect.get("recharge_slot_multiplier", 2)),
				"bonus_action_slot_recharge": bool(effect.get("bonus_action_slot_recharge", false)),
				"max_hp": compute_max_hp(character, effect),
			})
	return pools


static func pool_definition(character: Character, pool_id: String) -> Dictionary:
	for pool in pool_definitions(character):
		if str(pool.get("pool_id", "")) == pool_id or str(pool.get("feature_id", "")) == pool_id:
			return pool
	return {}


static func projection_definitions(character: Character) -> Array[Dictionary]:
	var projections: Array[Dictionary] = []
	if character == null:
		return projections
	for feat in character.features:
		if not (feat is Dictionary) or not bool(feat.get("enabled", true)):
			continue
		var feature_id := str(feat.get("id", "")).strip_edges()
		var feature_name := str(feat.get("name", feature_id)).strip_edges()
		for effect in feat.get("effects", []):
			if not (effect is Dictionary) or str(effect.get("type", "")) != "damage_ward_projection":
				continue
			var pool_id := str(effect.get("pool_id", "")).strip_edges()
			if pool_id.is_empty():
				continue
			projections.append({
				"pool_id": pool_id,
				"feature_id": feature_id,
				"feature_name": feature_name,
				"trigger": str(effect.get("trigger", "visible_creature_damaged")).strip_edges(),
				"action_cost": str(effect.get("action_cost", "reaction")).strip_edges(),
				"range_feet": int(effect.get("range_feet", 30)),
				"target_predicate": str(effect.get("target_predicate", "visible_creature_within_range")).strip_edges(),
			})
	return projections


static func projection_definition(character: Character, pool_id: String = "") -> Dictionary:
	var def := pool_definition(character, pool_id) if not pool_id.is_empty() else {}
	var resolved_pool_id := str(def.get("pool_id", pool_id))
	for proj in projection_definitions(character):
		if pool_id.is_empty() or str(proj.get("pool_id", "")) in [pool_id, resolved_pool_id] or str(proj.get("feature_id", "")) == pool_id:
			return proj
	return {}


static func pool_definitions_for_data(data: Dictionary, subclass: Dictionary, level: int, ability_scores_dict: Dictionary = {}) -> Dictionary:
	var raw_features: Array = []
	for source in [data, subclass]:
		var by_level: Variant = source.get("features_by_level", {})
		if not (by_level is Dictionary):
			continue
		for lvl_key in by_level:
			if int(lvl_key) > level:
				continue
			var list: Variant = by_level[lvl_key]
			if not (list is Array):
				continue
			for feat in list:
				if feat is Dictionary and bool(feat.get("enabled", true)):
					raw_features.append(feat)
	var pools: Dictionary = {}
	for feat in raw_features:
		var feature_id := str(feat.get("id", "")).strip_edges()
		var feature_name := str(feat.get("name", feature_id)).strip_edges()
		for effect in feat.get("effects", []):
			if not (effect is Dictionary) or str(effect.get("type", "")) != "damage_ward_pool":
				continue
			var pool_id := str(effect.get("pool_id", feature_id)).strip_edges()
			if pool_id.is_empty():
				continue
			var max_hp := compute_max_hp_from_scores(level, ability_scores_dict, effect)
			pools[pool_id] = {
				"pool_id": pool_id,
				"feature_id": feature_id,
				"feature_name": feature_name,
				"max_hp": max_hp,
				"recharge_slot_multiplier": int(effect.get("recharge_slot_multiplier", 2)),
				"bonus_action_slot_recharge": bool(effect.get("bonus_action_slot_recharge", false)),
			}
	return pools


static func compute_max_hp(character: Character, effect: Dictionary) -> int:
	if character == null:
		return 1
	var level_mult := int(effect.get("max_hp_level_multiplier", 2))
	var ability := str(effect.get("max_hp_ability", "INT")).strip_edges().to_upper()
	var flat_bonus := int(effect.get("max_hp_flat_bonus", 0))
	var mod := character.ability_scores.get_ability_modifier(ability) if character.ability_scores != null else 0
	return maxi(1, character.level * level_mult + mod + flat_bonus)


static func compute_max_hp_from_scores(level: int, scores_dict: Dictionary, effect: Dictionary) -> int:
	var level_mult := int(effect.get("max_hp_level_multiplier", 2))
	var ability := str(effect.get("max_hp_ability", "INT")).strip_edges().to_upper()
	var flat_bonus := int(effect.get("max_hp_flat_bonus", 0))
	var score := int(scores_dict.get(ability, 10))
	var mod := AbilityScores.get_modifier(score)
	return maxi(1, maxi(1, level) * level_mult + mod + flat_bonus)


static func ensure_ward_container(character: Character) -> Dictionary:
	if character == null:
		return {"version": CURRENT_WARD_STATE_VERSION, "pools": {}}
	if not (character.damage_wards is Dictionary) or not character.damage_wards.has("pools") or not (character.damage_wards.get("pools") is Dictionary):
		character.damage_wards = {
			"version": CURRENT_WARD_STATE_VERSION,
			"pools": {}
		}
	character.damage_wards["version"] = CURRENT_WARD_STATE_VERSION
	return character.damage_wards


static func sync_pools_on_acquire(character: Character) -> void:
	if character == null:
		return
	var container := ensure_ward_container(character)
	var pools_dict: Dictionary = container["pools"]
	var defs := pool_definitions(character)
	var valid_ids: Dictionary = {}
	for def in defs:
		var pool_id := str(def.get("pool_id", ""))
		var feature_id := str(def.get("feature_id", ""))
		var max_hp := int(def.get("max_hp", 1))
		valid_ids[pool_id] = true
		if not pools_dict.has(pool_id) or not (pools_dict[pool_id] is Dictionary):
			pools_dict[pool_id] = {
				"pool_id": pool_id,
				"source_feature_id": feature_id,
				"active": false,
				"created_since_long_rest": false,
				"current_hp": 0,
				"max_hp": max_hp,
			}
		else:
			var existing: Dictionary = pools_dict[pool_id]
			existing["pool_id"] = pool_id
			existing["source_feature_id"] = feature_id
			existing["max_hp"] = max_hp
			existing["current_hp"] = clampi(int(existing.get("current_hp", 0)), 0, max_hp)
	for existing_key in pools_dict.keys():
		if not valid_ids.has(str(existing_key)):
			pools_dict.erase(existing_key)


static func sync_pools_on_level_up(character: Character) -> void:
	sync_pools_on_acquire(character)


static func clear_for_long_rest(character: Character) -> void:
	if character == null:
		return
	var container := ensure_ward_container(character)
	var pools_dict: Dictionary = container["pools"]
	pools_dict.clear()
	for def in pool_definitions(character):
		var pool_id := str(def.get("pool_id", ""))
		pools_dict[pool_id] = {
			"pool_id": pool_id,
			"source_feature_id": str(def.get("feature_id", "")),
			"active": false,
			"created_since_long_rest": false,
			"current_hp": 0,
			"max_hp": int(def.get("max_hp", 1)),
		}


static func pool_state(character: Character, pool_id: String = "") -> Dictionary:
	if character == null:
		return {}
	sync_pools_on_acquire(character)
	var pools_dict: Dictionary = character.damage_wards.get("pools", {})
	if not pool_id.is_empty():
		if pools_dict.has(pool_id):
			return pools_dict[pool_id]
		var def := pool_definition(character, pool_id)
		var resolved_id := str(def.get("pool_id", ""))
		if not resolved_id.is_empty() and pools_dict.has(resolved_id):
			return pools_dict[resolved_id]
		return {}
	for def in pool_definitions(character):
		var pid := str(def.get("pool_id", ""))
		if pools_dict.has(pid):
			return pools_dict[pid]
	return {}


static func is_ward_active(character: Character, pool_id: String = "") -> bool:
	var state := pool_state(character, pool_id)
	return bool(state.get("active", false))


static func current_ward_hp(character: Character, pool_id: String = "") -> int:
	var state := pool_state(character, pool_id)
	if not bool(state.get("active", false)):
		return 0
	return maxi(0, int(state.get("current_hp", 0)))


static func max_ward_hp(character: Character, pool_id: String = "") -> int:
	var state := pool_state(character, pool_id)
	if not state.is_empty():
		return maxi(0, int(state.get("max_hp", 0)))
	var def := pool_definition(character, pool_id)
	return maxi(0, int(def.get("max_hp", 0)))


static func ward_state(character: Character, pool_id: String = "") -> Dictionary:
	return pool_state(character, pool_id)


static func has_active_ward(character: Character, pool_id: String = "") -> bool:
	return is_ward_active(character, pool_id)


static func get_ward_hp(character: Character, pool_id: String = "") -> int:
	return current_ward_hp(character, pool_id)


static func get_ward_max_hp(character: Character, pool_id: String = "") -> int:
	return max_ward_hp(character, pool_id)


static func ward_display_name(character: Character, pool_id: String = "") -> String:
	var def := pool_definition(character, pool_id)
	return str(def.get("feature_name", pool_id if not pool_id.is_empty() else "Ward"))


static func feature_definitions_for_character(character: Character) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if character == null:
		return out
	for feat in character.features:
		if feat is Dictionary and bool(feat.get("enabled", true)):
			out.append(feat)
	return out


static func spend_slot_for_ward_recharge(character: Character, pool_id: String, slot_level: int) -> Dictionary:
	return recharge_ward_from_slot_bonus_action(character, pool_id, slot_level)


static func spell_qualifies_for_pool(spell_data: Dictionary, pool_def: Dictionary, slot_level: int, cast_metadata: Dictionary = {}) -> bool:
	if spell_data.is_empty() or pool_def.is_empty() or slot_level < 1:
		return false
	if int(spell_data.get("level", 0)) < 1:
		return false
	if bool(spell_data.get("_ritual_cast", false)) or bool(cast_metadata.get("ritual_cast", false)):
		return false
	if bool(spell_data.get("_free_cast", false)) or bool(spell_data.get("_wizard_free_cast", false)) or bool(cast_metadata.get("free_cast", false)):
		return false
	if bool(spell_data.get("_magic_item_activation", false)) or bool(cast_metadata.get("magic_item_activation", false)):
		return false
	if bool(cast_metadata.get("divine_intervention", false)) or bool(cast_metadata.get("mystic_arcanum", false)):
		return false
	if bool(cast_metadata.get("countered", false)):
		return false
	var spell_school := str(spell_data.get("school", "")).strip_edges().to_lower()
	if spell_school.is_empty():
		return false
	for allowed in pool_def.get("trigger_schools", []):
		if str(allowed).strip_edges().to_lower() == spell_school:
			return true
	return false


static func on_slot_spell_cast(caster: Character, spell_data: Dictionary, slot_level: int, cast_metadata: Dictionary = {}) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if caster == null or spell_data.is_empty() or slot_level < 1:
		return events
	var defs := pool_definitions(caster)
	if defs.is_empty():
		return events
	sync_pools_on_acquire(caster)
	var pools_dict: Dictionary = caster.damage_wards.get("pools", {})
	for def in defs:
		if not spell_qualifies_for_pool(spell_data, def, slot_level, cast_metadata):
			continue
		var pool_id := str(def.get("pool_id", ""))
		var feature_id := str(def.get("feature_id", ""))
		var feature_name := str(def.get("feature_name", feature_id))
		var max_hp := int(def.get("max_hp", 1))
		var entry: Dictionary = pools_dict.get(pool_id, {
			"pool_id": pool_id,
			"source_feature_id": feature_id,
			"active": false,
			"created_since_long_rest": false,
			"current_hp": 0,
			"max_hp": max_hp,
		})
		entry["max_hp"] = max_hp
		if not bool(entry.get("created_since_long_rest", false)):
			entry["active"] = true
			entry["created_since_long_rest"] = true
			entry["current_hp"] = max_hp
			pools_dict[pool_id] = entry
			events.append({
				"pool_id": pool_id,
				"feature_id": feature_id,
				"feature_name": feature_name,
				"action": "created",
				"slot_level": slot_level,
				"restored_hp": max_hp,
				"current_hp": max_hp,
				"max_hp": max_hp,
				"message": "[color=cyan]%s weaves %s (%d/%d HP).[/color]" % [caster.character_name, feature_name, max_hp, max_hp],
			})
		elif bool(entry.get("active", false)):
			var before := clampi(int(entry.get("current_hp", 0)), 0, max_hp)
			var gain := maxi(0, int(def.get("recharge_slot_multiplier", 2)) * slot_level)
			var after := mini(max_hp, before + gain)
			var restored := maxi(0, after - before)
			entry["current_hp"] = after
			pools_dict[pool_id] = entry
			events.append({
				"pool_id": pool_id,
				"feature_id": feature_id,
				"feature_name": feature_name,
				"action": "recharged",
				"slot_level": slot_level,
				"restored_hp": restored,
				"current_hp": after,
				"max_hp": max_hp,
				"message": "[color=cyan]%s's %s regains %d HP (%d/%d HP).[/color]" % [caster.character_name, feature_name, restored, after, max_hp],
			})
	return events


static func available_bonus_action_recharge_slots(character: Character, pool_id: String = "") -> Array[int]:
	var levels: Array[int] = []
	if character == null:
		return levels
	var def := pool_definition(character, pool_id) if not pool_id.is_empty() else (pool_definitions(character)[0] if not pool_definitions(character).is_empty() else {})
	if def.is_empty() or not bool(def.get("bonus_action_slot_recharge", false)):
		return levels
	var resolved_id := str(def.get("pool_id", ""))
	var state := pool_state(character, resolved_id)
	if not bool(state.get("active", false)) or not bool(state.get("created_since_long_rest", false)):
		return levels
	if int(state.get("current_hp", 0)) >= int(state.get("max_hp", 0)):
		return levels
	for key in character.spell_slots:
		var lvl := int(key)
		if lvl >= 1 and int(character.spell_slots[key]) > 0:
			levels.append(lvl)
	levels.sort()
	return levels


static func recharge_ward_from_slot_bonus_action(character: Character, pool_id: String, slot_level: int) -> Dictionary:
	if character == null:
		return {"success": false, "message": "Ward recharge requires a valid character."}
	var def := pool_definition(character, pool_id) if not pool_id.is_empty() else (pool_definitions(character)[0] if not pool_definitions(character).is_empty() else {})
	if def.is_empty() or not bool(def.get("bonus_action_slot_recharge", false)):
		return {"success": false, "message": "This character cannot recharge a ward with a Bonus Action spell slot."}
	var resolved_id := str(def.get("pool_id", ""))
	var feature_name := str(def.get("feature_name", resolved_id))
	sync_pools_on_acquire(character)
	var state := pool_state(character, resolved_id)
	if not bool(state.get("active", false)) or not bool(state.get("created_since_long_rest", false)):
		return {"success": false, "message": "%s has not been created yet since your last Long Rest." % feature_name}
	var max_hp := int(def.get("max_hp", 1))
	var before := clampi(int(state.get("current_hp", 0)), 0, max_hp)
	if before >= max_hp:
		return {"success": false, "message": "%s is already at full Hit Points (%d/%d)." % [feature_name, before, max_hp]}
	if slot_level < 1:
		return {"success": false, "message": "Choose a level 1 or higher spell slot to recharge %s." % feature_name}
	var slot_key := str(slot_level)
	var available_slots := int(character.spell_slots.get(slot_key, 0))
	if available_slots <= 0:
		return {"success": false, "message": "No level %d spell slots remaining to recharge %s." % [slot_level, feature_name]}
	character.spell_slots[slot_key] = available_slots - 1
	var gain := maxi(0, int(def.get("recharge_slot_multiplier", 2)) * slot_level)
	var after := mini(max_hp, before + gain)
	var restored := maxi(0, after - before)
	state["max_hp"] = max_hp
	state["current_hp"] = after
	character.damage_wards["pools"][resolved_id] = state
	return {
		"success": true,
		"pool_id": resolved_id,
		"feature_id": str(def.get("feature_id", "")),
		"feature_name": feature_name,
		"slot_level": slot_level,
		"restored_hp": restored,
		"current_hp": after,
		"max_hp": max_hp,
		"message": "[color=cyan]%s expends a level %d spell slot as a Bonus Action; %s regains %d HP (%d/%d HP).[/color]" % [character.character_name, slot_level, feature_name, restored, after, max_hp],
	}


static func _target_identity_key(target) -> String:
	if target is Character:
		return "char:%s:%d" % [target.character_id, target.get_instance_id()]
	if target is Dictionary:
		return "dict:%s" % str(target.get("id", target.get("name", "monster")))
	return ""


static func can_project_ward(owner: Character, target, pool_id: String = "", context: Dictionary = {}, allow_same_hit_continuation: bool = false) -> Dictionary:
	if owner == null or not owner.is_alive or owner.is_dead():
		return {"eligible": false, "reason": "owner_not_alive"}
	if CombatAction.is_incapacitated(owner):
		return {"eligible": false, "reason": "owner_incapacitated"}
	if target == null or CombatAction.is_same_character(owner, target):
		return {"eligible": false, "reason": "invalid_target"}
	if target is Character and target.is_dead():
		return {"eligible": false, "reason": "target_dead"}
	if target is Dictionary and not bool(target.get("is_alive", true)):
		return {"eligible": false, "reason": "target_dead"}
	if not owner.reaction_available and not allow_same_hit_continuation:
		return {"eligible": false, "reason": "no_reaction_available"}
	var proj := projection_definition(owner, pool_id)
	if proj.is_empty():
		return {"eligible": false, "reason": "no_projection_feature"}
	var resolved_pool_id := str(proj.get("pool_id", ""))
	var state := pool_state(owner, resolved_pool_id)
	if not bool(state.get("active", false)) or int(state.get("current_hp", 0)) <= 0:
		return {"eligible": false, "reason": "ward_depleted_or_inactive"}
	var predicate := str(proj.get("target_predicate", "visible_creature_within_range"))
	if predicate == "ally_visible_within_range" and not (target is Character):
		return {"eligible": false, "reason": "target_not_ally"}
	elif predicate == "visible_creature_within_range" and not (target is Character or target is Dictionary):
		return {"eligible": false, "reason": "target_not_creature"}

	var range_feet := int(proj.get("range_feet", 30))
	var distance_feet := int(context.get("distance_feet", -1))
	var owner_pos: Variant = context.get("owner_position", null)
	var target_pos: Variant = context.get("target_position", null)
	var players: Variant = context.get("players", [])
	var monsters: Variant = context.get("monsters", [])
	if not (owner_pos is Vector2i) and players is Array:
		for p in players:
			if p is Dictionary and p.get("character") == owner and p.get("hex_position") is Vector2i:
				owner_pos = p["hex_position"]
				break
	if not (target_pos is Vector2i):
		if target is Character and players is Array:
			for p in players:
				if p is Dictionary and p.get("character") == target and p.get("hex_position") is Vector2i:
					target_pos = p["hex_position"]
					break
		elif target is Dictionary:
			if target.get("hex_position") is Vector2i:
				target_pos = target["hex_position"]
			elif monsters is Array:
				for m in monsters:
					if m is Dictionary and str(m.get("id", "")) == str(target.get("id", "")) and m.get("hex_position") is Vector2i:
						target_pos = m["hex_position"]
						break
	if distance_feet < 0 and owner_pos is Vector2i and target_pos is Vector2i:
		distance_feet = HexUtils.get_distance(owner_pos, target_pos) * 5
	if distance_feet >= 0 and distance_feet > range_feet:
		return {"eligible": false, "reason": "out_of_range"}

	if context.has("target_visible") and not bool(context.get("target_visible", true)):
		return {"eligible": false, "reason": "target_not_visible"}
	if owner.has_condition("blinded"):
		return {"eligible": false, "reason": "owner_blinded"}
	var grid: HexGrid = context.get("grid") if context.get("grid") is HexGrid else null
	if grid != null and owner_pos is Vector2i and target_pos is Vector2i:
		if not CombatPerception.can_see_target(owner, target, owner_pos, target_pos, grid):
			return {"eligible": false, "reason": "no_line_of_sight"}
	else:
		var check_dist := maxi(0, distance_feet)
		if CombatAction.is_invisible(target) and not CombatAction.can_perceive_invisible(owner, check_dist):
			return {"eligible": false, "reason": "target_invisible"}

	return {
		"eligible": true,
		"pool_id": resolved_pool_id,
		"projection": proj,
		"pool_state": state,
	}


static func absorb_damage(target, incoming_damage: int, reaction_decisions: Dictionary = {}, damage_occurrence_id: int = 0) -> Dictionary:
	var out := {
		"absorbed": 0,
		"remaining_damage": maxi(0, incoming_damage),
		"used": false,
		"projected": false,
		"pool_id": "",
		"owner_id": "",
		"ward_remaining_hp": 0,
		"message": "",
	}
	if incoming_damage <= 0 or target == null:
		return out

	var remaining := incoming_damage
	var total_absorbed := 0
	var used_pool_id := ""
	var used_owner_id := ""
	var used_remaining_hp := 0
	var was_projected := false
	var messages: Array[String] = []

	# 1. Self Ward absorption (automatic on any active ward owned by the target Character)
	if target is Character and not target.is_dead():
		sync_pools_on_acquire(target)
		var pools_dict: Dictionary = target.damage_wards.get("pools", {})
		for def in pool_definitions(target):
			if remaining <= 0:
				break
			var pid := str(def.get("pool_id", ""))
			var entry: Dictionary = pools_dict.get(pid, {})
			if not bool(entry.get("active", false)):
				continue
			var ward_hp := maxi(0, int(entry.get("current_hp", 0)))
			if ward_hp <= 0:
				continue
			var absorbed := mini(remaining, ward_hp)
			entry["current_hp"] = ward_hp - absorbed
			pools_dict[pid] = entry
			remaining -= absorbed
			total_absorbed += absorbed
			used_pool_id = pid
			used_owner_id = target.character_id
			used_remaining_hp = int(entry["current_hp"])
			var feat_name := str(def.get("feature_name", pid))
			messages.append("[color=cyan]%s's %s absorbs %d damage (%d/%d HP remaining).[/color]" % [
				target.character_name, feat_name, absorbed, used_remaining_hp, int(entry.get("max_hp", 1))
			])

	# 2. Projected Ward Reaction absorption from another Character
	if remaining > 0 and reaction_decisions.has("projected_ward") and reaction_decisions["projected_ward"] is Dictionary:
		var proj_dec: Dictionary = reaction_decisions["projected_ward"]
		var accepted := bool(proj_dec.get("accepted", true))
		var owner: Character = proj_dec.get("owner") if proj_dec.get("owner") is Character else null
		var requested_pool_id := str(proj_dec.get("pool_id", "")).strip_edges()
		if owner == null and proj_dec.has("owner_id") and reaction_decisions.get("players") is Array:
			var want_id := str(proj_dec.get("owner_id", "")).strip_edges()
			for p in reaction_decisions["players"]:
				if p is Dictionary and p.get("character") is Character and p["character"].character_id == want_id:
					owner = p["character"]
					break
		var target_key := _target_identity_key(target)
		# Only explicitly grouped components of this one occurrence share a Reaction.
		var same_hit_continuation := damage_occurrence_id > 0 and int(proj_dec.get("_committed_occurrence_id", 0)) == damage_occurrence_id and bool(proj_dec.get("_reaction_spent", false)) and str(proj_dec.get("_committed_target_key", "")) == target_key
		if accepted and owner != null:
			var eval_context := reaction_decisions.duplicate()
			for k in ["distance_feet", "target_visible", "owner_position", "target_position", "grid", "players", "monsters"]:
				if proj_dec.has(k):
					eval_context[k] = proj_dec[k]
			var check_res := can_project_ward(owner, target, requested_pool_id, eval_context, same_hit_continuation)
			if bool(check_res.get("eligible", false)):
				var pid := str(check_res.get("pool_id", ""))
				var proj_def: Dictionary = check_res.get("projection", {})
				var entry: Dictionary = check_res.get("pool_state", {})
				var ward_hp := maxi(0, int(entry.get("current_hp", 0)))
				if ward_hp > 0:
					if not same_hit_continuation:
						owner.reaction_available = false
						proj_dec["_reaction_spent"] = true
						proj_dec["_committed_target_key"] = target_key
						proj_dec["_committed_occurrence_id"] = damage_occurrence_id
						if eval_context.get("players") is Array:
							for p in eval_context["players"]:
								if p is Dictionary and p.get("character") == owner:
									p["reaction_available"] = false
					var absorbed := mini(remaining, ward_hp)
					entry["current_hp"] = ward_hp - absorbed
					owner.damage_wards["pools"][pid] = entry
					remaining -= absorbed
					total_absorbed += absorbed
					used_pool_id = pid
					used_owner_id = owner.character_id
					used_remaining_hp = int(entry["current_hp"])
					was_projected = true
					var target_name: String = target.character_name if target is Character else str(target.get("name", "the creature"))
					var proj_name := str(proj_def.get("feature_name", "Projected Ward"))
					messages.append("[color=cyan]%s uses %s to absorb %d damage for %s (%d/%d Ward HP remaining).[/color]" % [
						owner.character_name, proj_name, absorbed, target_name, used_remaining_hp, int(entry.get("max_hp", 1))
					])

	out["absorbed"] = total_absorbed
	out["remaining_damage"] = remaining
	out["used"] = total_absorbed > 0
	out["projected"] = was_projected
	out["pool_id"] = used_pool_id
	out["owner_id"] = used_owner_id
	out["ward_remaining_hp"] = used_remaining_hp
	out["message"] = " ".join(messages).strip_edges()
	return out


static func serialize_wards(damage_wards: Variant) -> Dictionary:
	if not (damage_wards is Dictionary):
		return {"version": CURRENT_WARD_STATE_VERSION, "pools": {}}
	var out_pools: Dictionary = {}
	var raw_pools: Variant = damage_wards.get("pools", {})
	if raw_pools is Dictionary:
		for key in raw_pools:
			var entry: Variant = raw_pools[key]
			if not (entry is Dictionary):
				continue
			out_pools[str(key)] = {
				"pool_id": str(entry.get("pool_id", key)),
				"source_feature_id": str(entry.get("source_feature_id", "")),
				"active": bool(entry.get("active", false)),
				"created_since_long_rest": bool(entry.get("created_since_long_rest", false)),
				"current_hp": int(entry.get("current_hp", 0)),
				"max_hp": int(entry.get("max_hp", 0)),
			}
	return {
		"version": int(damage_wards.get("version", CURRENT_WARD_STATE_VERSION)),
		"pools": out_pools,
	}


static func deserialize_wards(raw: Variant) -> Dictionary:
	return serialize_wards(raw)


static func _is_strict_int(value: Variant) -> bool:
	if value is bool:
		return false
	return (value is int) or (value is float and is_finite(float(value)) and float(value) == floor(float(value)))


static func saved_state_error(dto: Dictionary, data: Dictionary, subclass: Dictionary, level: int) -> String:
	if not dto.has("damage_wards"):
		return ""
	var raw: Variant = dto.get("damage_wards")
	if not (raw is Dictionary):
		return "Saved damage_wards must be a dictionary"
	if not raw.has("version") or not _is_strict_int(raw.get("version")) or int(raw.get("version")) != CURRENT_WARD_STATE_VERSION:
		return "Saved damage_wards version is missing or unsupported"
	if not raw.has("pools") or not (raw.get("pools") is Dictionary):
		return "Saved damage_wards.pools must be a dictionary"
	var scores_dict: Dictionary = dto.get("ability_scores", {}) if dto.get("ability_scores") is Dictionary else {}
	var valid_pools := pool_definitions_for_data(data, subclass, level, scores_dict)
	var raw_pools: Dictionary = raw["pools"]
	for pool_key in raw_pools:
		if not (pool_key is String) or str(pool_key).strip_edges().is_empty():
			return "Saved damage ward pool key must be a non-empty string"
		var pool_id := str(pool_key)
		if not valid_pools.has(pool_id):
			return "Saved damage ward pool '%s' is not granted by this character's class or subclass at level %d" % [pool_id, level]
		var entry: Variant = raw_pools[pool_key]
		if not (entry is Dictionary):
			return "Saved damage ward entry '%s' must be a dictionary" % pool_id
		var expected_def: Dictionary = valid_pools[pool_id]
		if str(entry.get("pool_id", "")) != pool_id:
			return "Saved damage ward '%s' has mismatched pool_id" % pool_id
		if str(entry.get("source_feature_id", "")) != str(expected_def.get("feature_id", "")):
			return "Saved damage ward '%s' has mismatched source_feature_id" % pool_id
		if not (entry.get("active") is bool) or not (entry.get("created_since_long_rest") is bool):
			return "Saved damage ward '%s' active and created_since_long_rest flags must be booleans" % pool_id
		var is_active := bool(entry["active"])
		var created := bool(entry["created_since_long_rest"])
		if is_active and not created:
			return "Saved damage ward '%s' cannot be active when created_since_long_rest is false" % pool_id
		if not _is_strict_int(entry.get("current_hp")) or not _is_strict_int(entry.get("max_hp")):
			return "Saved damage ward '%s' current_hp and max_hp must be integers" % pool_id
		var cur_hp := int(entry["current_hp"])
		var max_hp := int(entry["max_hp"])
		var expected_max := int(expected_def.get("max_hp", 1))
		if max_hp <= 0 or max_hp != expected_max:
			return "Saved damage ward '%s' max_hp (%d) does not match derived maximum (%d)" % [pool_id, max_hp, expected_max]
		if cur_hp < 0 or cur_hp > max_hp:
			return "Saved damage ward '%s' current_hp (%d) is out of range 0..%d" % [pool_id, cur_hp, max_hp]
		if not is_active and cur_hp != 0:
			return "Saved damage ward '%s' cannot have positive current_hp when inactive" % pool_id
	return ""


static func summary_lines(character: Character) -> Array[String]:
	var lines: Array[String] = []
	if character == null:
		return lines
	var defs := pool_definitions(character)
	if defs.is_empty():
		return lines
	sync_pools_on_acquire(character)
	var pools_dict: Dictionary = character.damage_wards.get("pools", {})
	for def in defs:
		var pool_id := str(def.get("pool_id", ""))
		var feature_name := str(def.get("feature_name", pool_id))
		var max_hp := int(def.get("max_hp", 1))
		var entry: Dictionary = pools_dict.get(pool_id, {})
		var is_active := bool(entry.get("active", false))
		var cur_hp := clampi(int(entry.get("current_hp", 0)), 0, max_hp)
		var status_text := "%d / %d HP (Active)" % [cur_hp, max_hp] if is_active else "Inactive (0 / %d HP — cast %s spell with slot)" % [max_hp, "/".join(def.get("trigger_schools", ["Abjuration"]))]
		lines.append("%s: %s" % [feature_name, status_text])
	return lines
