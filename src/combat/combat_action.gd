## Combat Action Resolver
## Implements D&D 5e combat mechanics: attack rolls, spellcasting, healing, and AC protection.
class_name CombatAction
extends RefCounted

static var active_turn_serial: int = 0
static var active_turn_actor_id: int = 0
## Per-source, per-option hit locks live only for the active combat session.
static var bounded_hit_rider_locks: Dictionary = {}
## These locks survive other actors' turns and clear only at the owner's next turn start.
static var bounded_owner_turn_rider_locks: Dictionary = {}
static var active_combat_round: int = 0
static var bounded_round_rider_locks: Dictionary = {}
static var weapon_rider_rolls: Dictionary = {}
static var weapon_rider_roll_serial: int = 0


static func advance_combat_turn(actor: Character = null, round_number: int = -1) -> void:
	bounded_hit_rider_locks.clear()
	weapon_rider_rolls.clear()
	if round_number >= 0 and round_number != active_combat_round:
		bounded_round_rider_locks.clear()
	if round_number >= 0:
		active_combat_round = round_number
	active_turn_serial += 1
	active_turn_actor_id = actor.get_instance_id() if actor != null else 0
	if actor != null: MaxHpSourceRules.on_event(actor, "turn_started")
	if actor != null: FeatureModeRules.on_event(actor, "turn_start")


static func reset_bounded_owner_turn_rider_locks() -> void:
	bounded_owner_turn_rider_locks.clear()
	bounded_round_rider_locks.clear()
	weapon_rider_rolls.clear()
	active_combat_round = 0


static func start_bounded_owner_turn_interval(actor: Character) -> void:
	if actor == null or actor.character_id.is_empty():
		return
	bounded_owner_turn_rider_locks.erase(actor.character_id)


## Invisibility affects attacks only when the opposing creature cannot perceive
## the invisible creature. Occupied hexes remain legal targets in this game;
## an unperceived target imposes the normal attack disadvantage.
static func is_invisible(entity) -> bool:
	if SpellEffects.has_spell(entity, "faerie_fire"):
		return false
	if entity is Character:
		return entity.has_condition("invisible") and not entity.has_condition("starry_wisp")
	if entity is Dictionary:
		var conditions: Dictionary = entity.get("conditions", {})
		return conditions.has("invisible") and not conditions.has("starry_wisp")
	return false


static func is_unconscious(entity) -> bool:
	if entity is Character:
		return entity.has_condition("unconscious")
	if entity is Dictionary:
		return entity.get("conditions", {}).has("unconscious")
	return false


static func is_incapacitated(entity) -> bool:
	for condition in ["incapacitated", "paralyzed", "petrified", "stunned", "unconscious"]:
		if entity is Character and entity.has_condition(condition):
			return true
		if entity is Dictionary and entity.get("conditions", {}).has(condition):
			return true
	return false


static func has_condition(entity, condition: String) -> bool:
	if entity is Character:
		return entity.has_condition(condition)
	if entity is Dictionary:
		return entity.get("conditions", {}).has(condition)
	return false


static func is_immune_to_condition(entity, condition: String) -> bool:
	if entity == null or condition.is_empty():
		return false
	if entity is Dictionary:
		return condition in entity.get("condition_immunities", [])
	if entity is not Character:
		return false
	var race: Dictionary = DataLoader.get_race(entity.race_id)
	for race_trait in race.get("traits", []):
		for effect in race_trait.get("effects", []):
			if str(effect.get("type", "")) == "immunity" and str(effect.get("condition", "")) == condition:
				return true
	for feature in entity.features:
		for effect in feature.get("effects", []) + feature.get("passive_effects", []):
			if str(effect.get("type", "")) == "immunity" and str(effect.get("condition", "")) == condition:
				return true
	return false


static func is_immune_to_magical_sleep(entity) -> bool:
	if entity is Dictionary:
		var immunities: Array = entity.get("condition_immunities", [])
		return bool(entity.get("does_not_sleep", false)) or "magical_sleep" in immunities or "exhaustion" in immunities
	if entity is not Character:
		return false
	var race: Dictionary = DataLoader.get_race(entity.race_id)
	for race_trait in race.get("traits", []):
		for effect in race_trait.get("effects", []):
			if str(effect.get("type", "")) == "immunity" and str(effect.get("condition", "")) in ["magical_sleep", "exhaustion"]:
				return true
	for feature in entity.features:
		for effect in feature.get("effects", []) + feature.get("passive_effects", []):
			if str(effect.get("type", "")) == "immunity" and str(effect.get("condition", "")) in ["magical_sleep", "exhaustion"]:
				return true
	return false


static func is_paralyzed(entity) -> bool:
	return has_condition(entity, "paralyzed")


static func is_same_character(left, right) -> bool:
	return left is Character and right is Character and left == right


static func resolve_hold_monster_repeat_save(target, save_dc: int, source: String = "") -> Dictionary:
	if not has_condition(target, "paralyzed"):
		return {"success": false, "message": "The target is not held by Hold Monster."}
	var total := 0
	if target is Character:
		total = int(target.saving_throw_test_to_dc("WIS", save_dc).get("total", 0))
	elif target is Dictionary:
		total = BarbarianRules.roll_monster_save(target, "WIS")
	var saved := total >= save_dc
	if saved:
		if not source.is_empty():
			SpellEffects.remove(target, source)
		elif target is Character:
			target.remove_condition("paralyzed")
		elif target is Dictionary:
			target.get("conditions", {}).erase("paralyzed")
			target.get("condition_sources", {}).erase("paralyzed")
	return {"success": true, "saved": saved, "total": total, "save_dc": save_dc}

static func resolve_condition_spell_repeat_save(target, source: String) -> Dictionary:
	var record: Dictionary = SpellEffects.records(target).get(source, {})
	var spell_id := str(record.get("spell_id", ""))
	var shared_spell := DataLoader.get_spell(spell_id)
	if SharedSpell.uses(shared_spell):
		if not shared_spell.has("repeat_save") or record.get("conditions", []).is_empty():
			return {"success": false}
		var shared_dc := int(record["save_dc"]) + int(record.get("repeat_save_dc_adjustment", 0))
		var shared_ability := str(shared_spell["repeat_save"])
		var shared_total: int = int(target.saving_throw_test_to_dc(shared_ability, shared_dc).get("total", 0)) if target is Character else BarbarianRules.roll_monster_save(target, shared_ability)
		var shared_saved := shared_total >= shared_dc
		var progress := SpellEffects.record_shared_repeat_save(target, source, shared_saved, shared_total, shared_dc)
		return {"success": true, "saved": shared_saved, "total": shared_total, "save_dc": shared_dc, "spell_id": spell_id, "source_id": source, "caster_id": str(record.get("caster_id", "")), "recipient_id": str(record.get("recipient_id", SpellEffects.caster_id(target) if target is Character else target.get("id", ""))), "purpose_id": str(record.get("repeat_save_purpose", "repeat_save")), "save_context": record.get("repeat_save_context", {}).duplicate(true), "attempt": int(progress.get("attempt", 0)), "stage_index": int(progress.get("stage_index", -1)), "stage_successes": int(progress.get("stage_successes", 0)), "dc_adjustment": int(progress.get("dc_adjustment", 0)), "ended": bool(progress.get("ended", false))}
	if spell_id not in ["hold_person", "hold_monster", "ray_of_enfeeblement", "power_word_stun", "sleep", "blindness/deafness", "sunburst"] or (spell_id not in ["power_word_stun", "sleep", "blindness/deafness", "sunburst"] and not bool(record.get("concentration", false))):
		return {"success": false}
	if spell_id == "sleep" and "incapacitated" not in record.get("conditions", []):
		return {"success": false}
	var ability := str(DataLoader.get_spell(spell_id).get("repeat_save_ability", DataLoader.get_spell(spell_id).get("save", "WIS")))
	var dc := int(record["save_dc"])
	var total: int = int(target.saving_throw_test_to_dc(ability, dc).get("total", 0)) if target is Character else BarbarianRules.roll_monster_save(target, ability)
	var saved := total >= dc
	if saved:
		SpellEffects.remove(target, source, "repeat_save_succeeded", {"ability": ability, "total": total, "dc": dc})
		return {"success": true, "saved": true, "total": total, "save_dc": dc, "spell_id": spell_id}
	if spell_id == "sunburst":
		# Sunburst's one-minute duration is measured on the affected creature's
		# turns; a caster-owned round timer could expire before that creature acts.
		SpellEffects._advance(target, source, 6)
		return {"success": true, "saved": false, "total": total, "save_dc": dc, "spell_id": spell_id}
	if spell_id == "sleep":
		var updated_record := record.duplicate(true)
		var conditions: Array = updated_record.get("conditions", []).duplicate()
		conditions.erase("incapacitated")
		updated_record["conditions"] = conditions
		remove_condition_source(target, source, ["incapacitated"])
		var records := SpellEffects.records(target)
		records[source] = updated_record
		if target is Dictionary:
			target["spell_effects"] = records
		SpellEffects.grant(target, updated_record, "unconscious", "start")
	return {"success": true, "saved": false, "total": total, "save_dc": dc, "spell_id": spell_id, "condition": "unconscious" if spell_id == "sleep" else ""}


static func can_perceive_invisible(entity, distance_feet: int) -> bool:
	if entity != null and SpellEffects.has_spell(entity, "see_invisibility"):
		return true
	if entity != null and SpellEffects.has_spell(entity, "true_seeing"):
		return distance_feet >= 0 and distance_feet <= 120
	if entity is Character:
		for effect in ClassProgression.selected_feature_effects_of_type(entity, "blindsight"):
			if distance_feet <= int(effect.get("range_feet", 0)):
				return true
	elif entity is Dictionary:
		var senses: Dictionary = entity.get("senses", {})
		var range_feet := int(entity.get("blindsight_range_feet", senses.get("blindsight", 0)))
		return distance_feet <= range_feet
	return false


static func can_perceive_blur(entity, distance_feet: int) -> bool:
	if entity == null:
		return false
	if SpellEffects.has_spell(entity, "true_seeing") and distance_feet >= 0 and distance_feet <= 120:
		return true
	var blindsight_range := 0
	var truesight_range := 0
	if entity is Character:
		blindsight_range = int(entity.feature_uses.get("monster_blindsight_range_feet", 0))
		truesight_range = int(entity.feature_uses.get("monster_truesight_range_feet", 0))
		for effect in ClassProgression.selected_feature_effects_of_type(entity, "blindsight"):
			blindsight_range = maxi(blindsight_range, int(effect.get("range_feet", 0)))
	elif entity is Dictionary:
		var senses: Dictionary = entity.get("senses", {})
		blindsight_range = int(entity.get("blindsight_range_feet", senses.get("blindsight", 0)))
		truesight_range = int(entity.get("truesight_range_feet", senses.get("truesight", 0)))
	return distance_feet >= 0 and distance_feet <= maxi(blindsight_range, truesight_range)


static func spell_target_is_visible_to(caster: Character, target, spell_data: Dictionary, distance_feet: int) -> bool:
	if not bool(spell_data.get("requires_target_sight", false)) or not is_invisible(target):
		return true
	return distance_feet >= 0 and can_perceive_invisible(caster, distance_feet)


static func spell_range_in_hexes(spell_data: Dictionary, character_level: int) -> int:
	var range_hexes := maxi(0, int(spell_data.get("range", 6)))
	var range_table: Dictionary = spell_data.get("range_by_character_level_feet", {})
	for threshold in range_table:
		if str(threshold).is_valid_int() and character_level >= int(threshold):
			range_hexes = maxi(range_hexes, int(ceil(float(range_table[threshold]) / 5.0)))
	return range_hexes


## Apply one already-validated movement step for either a player or monster.
## Path legality and opportunity attacks stay with CombatState, while this
## boundary owns the shared position mutation and result shape.
static func resolve_movement_step(entity_dict: Dictionary, from_hex: Vector2i, to_hex: Vector2i) -> Dictionary:
	if entity_dict.is_empty() or not entity_dict.has("hex_position"):
		return {"success": false, "from": from_hex, "to": to_hex, "message": "Movement needs a positioned entity."}
	if entity_dict["hex_position"] != from_hex:
		return {"success": false, "from": from_hex, "to": to_hex, "message": "Movement path is stale."}
	entity_dict["hex_position"] = to_hex
	var mover: Variant = entity_dict.get("character", null)
	if mover is Character:
		SpellEffects.publish_event(mover, {"type": "movement", "actor_id": SpellEffects.caster_id(mover), "from": [from_hex.x, from_hex.y], "to": [to_hex.x, to_hex.y], "distance_feet": HexUtils.get_distance(from_hex, to_hex) * 5})
	else:
		var mover_id := str(entity_dict.get("id", ""))
		if not mover_id.is_empty():
			SpellEffects.publish_event(entity_dict, {"type": "movement", "actor_id": mover_id, "from": [from_hex.x, from_hex.y], "to": [to_hex.x, to_hex.y], "distance_feet": HexUtils.get_distance(from_hex, to_hex) * 5})
	if entity_dict.get("is_created_creature", false):
		var record := CreatedCreatureRules.get_record(entity_dict["character"].character_id)
		if not record.is_empty(): record["position"] = [to_hex.x, to_hex.y]
	return {"success": true, "from": from_hex, "to": to_hex, "message": "Movement step resolved."}


## Apply a condition through the same Character/monster and immunity boundary.
static func apply_condition(target, condition: String, duration: int, source: String = "") -> void:
	if target is Character:
		if condition in ["paralyzed", "restrained"] and SpellEffects.has_spell(target, "freedom_of_movement") and SpellEffects.is_spell_source(source):
			return
		if is_immune_to_condition(target, condition):
			return
		target.add_condition(condition, duration, source)
	elif target is Dictionary and condition == "frightened" and SpellEffects.has_spell(target, "heroism"):
		return
	elif target is Dictionary and condition not in target.get("condition_immunities", []):
		var conditions: Dictionary = target.get("conditions", {})
		var sources: Dictionary = target.get("condition_sources", {})
		if not source.is_empty() or sources.has(condition):
			var grants: Dictionary = sources.get(condition, {}) if conditions.has(condition) else {}
			if grants.is_empty() and conditions.has(condition):
				grants["ordinary"] = int(conditions[condition])
			var source_id := source if not source.is_empty() else "ordinary"
			grants[source_id] = maxi(int(grants.get(source_id, 0)), duration)
			sources[condition] = grants
			target["condition_sources"] = sources
			conditions[condition] = int(grants.values().max())
		else:
			conditions[condition] = maxi(int(conditions.get(condition, 0)), duration)
		target["conditions"] = conditions
	if has_condition(target, condition):
		var subject_id := SpellEffects.caster_id(target) if target is Character else str(target.get("id", "")) if target is Dictionary else ""
		SpellEffects.publish_event(target, {"type": "status", "actor_id": subject_id, "status": condition, "state": "applied", "source_instance_id": source})


## Resolve spell effects that explicitly occur only after a successful attack hit.
## Non-hit spell effects remain in CombatState's normal effect dispatch.
static func apply_spell_hit_effects(target, spell_data: Dictionary, resolution: Dictionary, source_id: String = "") -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if target == null or not bool(resolution.get("hit", false)):
		return results
	for effect in spell_data.get("effects", []):
		if not effect is Dictionary or not bool(effect.get("on_spell_hit", false)):
			continue
		if str(effect.get("type", "")) == "prevent_healing":
			if source_id.is_empty():
				continue
			var source_turns := maxi(2, int(effect.get("source_turns", 2)))
			if target is Character:
				target.healing_suppression_sources[source_id] = maxi(int(target.healing_suppression_sources.get(source_id, 0)), source_turns)
			elif target is Dictionary:
				var suppression_sources: Dictionary = target.get("healing_suppression_sources", {}).duplicate(true)
				suppression_sources[source_id] = maxi(int(suppression_sources.get(source_id, 0)), source_turns)
				target["healing_suppression_sources"] = suppression_sources
			results.append({"type": "prevent_healing", "source_id": source_id, "source_turns": source_turns})
			continue
		var condition := str(effect.get("condition", ""))
		if str(effect.get("type", "")) != "grant_condition" or condition.is_empty():
			continue
		var duration := maxi(1, int(effect.get("duration", 1)))
		if SpellEffects.manages(spell_data) and not resolution.get("effect_cast", {}).is_empty():
			SpellEffects.grant(target, resolution["effect_cast"], condition, "end", 12)
		else:
			apply_condition(target, condition, duration)
		results.append({"condition": condition, "duration": duration})
	return results


## Apply spell conditions that occur only after a failed saving throw.
static func apply_spell_failed_save_effects(target, spell_data: Dictionary, resolution: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if SpellEffects.manages(spell_data) and not resolution.get("effect_cast", {}).is_empty():
		return results # Already applied once by the shared save settlement.
	if target == null or bool(resolution.get("saved", false)):
		return results
	for effect in spell_data.get("effects", []):
		if not effect is Dictionary or not bool(effect.get("on_failed_save", false)):
			continue
		if str(effect.get("type", "")) == "command":
			results.append({"type": "command"})
			continue
		if str(effect.get("type", "")) != "grant_condition":
			continue
		var condition := str(effect.get("condition", ""))
		if condition.is_empty():
			continue
		if str(resolution.get("caster_creature_type", "")) in protected_creature_types_for_target(target) and condition in ["charmed", "frightened"]:
			continue
		var duration := maxi(1, int(effect.get("duration", 1)))
		apply_condition(target, condition, duration)
		results.append({"condition": condition, "duration": duration})
	return results


static func protected_creature_types_for_target(target) -> Array:
	var protected_types: Array = []
	var sources: Dictionary = {}
	if target is Character:
		sources = target.protection_from_evil_and_good_sources
	elif target is Dictionary:
		sources = target.get("protection_from_evil_and_good_sources", {})
	for source_types in sources.values():
		if source_types is Array:
			for protected_type in source_types:
				if protected_type not in protected_types:
					protected_types.append(protected_type)
	return protected_types


## True while a hit spell effect prevents this target from regaining Hit Points.
static func is_healing_suppressed(target) -> bool:
	if target is Character:
		return not target.healing_suppression_sources.is_empty()
	if target is Dictionary:
		return not target.get("healing_suppression_sources", {}).is_empty()
	return false


## Remove one caster-owned healing restriction at the end of that caster's turn.
static func tick_healing_suppression_for_source(target, source_id: String) -> void:
	if source_id.is_empty():
		return
	var sources: Dictionary = {}
	if target is Character:
		sources = target.healing_suppression_sources.duplicate(true)
	elif target is Dictionary:
		sources = target.get("healing_suppression_sources", {}).duplicate(true)
	else:
		return
	if not sources.has(source_id):
		return
	var turns_left := int(sources[source_id]) - 1
	if turns_left <= 0:
		sources.erase(source_id)
	else:
		sources[source_id] = turns_left
	if target is Character:
		target.healing_suppression_sources = sources
	elif target is Dictionary:
		target["healing_suppression_sources"] = sources


## Guiding Bolt grants Advantage on one attack against its marked target.
static func consume_guiding_bolt_advantage(target) -> bool:
	if target is Character:
		if not target.has_condition("guiding_bolt"):
			return false
		target.remove_condition("guiding_bolt")
		return true
	if target is Dictionary:
		var conditions: Dictionary = target.get("conditions", {})
		if not conditions.has("guiding_bolt"):
			return false
		conditions.erase("guiding_bolt")
		target["conditions"] = conditions
		var sources: Dictionary = target.get("condition_sources", {})
		sources.erase("guiding_bolt")
		target["condition_sources"] = sources
		return true
	return false


static func blocks_opportunity_attack(target) -> bool:
	if target is Character:
		return target.has_condition("shocking_grasp")
	if target is Dictionary:
		return target.get("conditions", {}).has("shocking_grasp")
	return false


## Help applies to the next actual attack roll, including spell attacks.
static func consume_attack_help(target) -> bool:
	if not target is Dictionary or str(target.get("familiar_helped_by", "")).is_empty(): return false
	target.erase("familiar_helped_by")
	return true


## Blade Ward penalizes every attack roll against the protected creature while
## its concentration-bound condition remains active.
static func apply_blade_ward_attack_penalty(target, attacker: Character, attack_result: Dictionary) -> int:
	var warded: bool = false
	if target is Character:
		warded = target.has_condition("blade_ward")
	elif target is Dictionary:
		warded = target.get("conditions", {}).has("blade_ward")
	if not warded or attacker == null:
		return 0
	var penalty := Dice.roll(4, attacker)
	attack_result["total"] = int(attack_result.get("total", 0)) - penalty
	var modifiers: Array = attack_result.get("activity_modifiers", [])
	modifiers.append({"label": "Blade Ward", "value": -penalty})
	attack_result["activity_modifiers"] = modifiers
	var bonus_terms: Array = attack_result.get("bonus_dice_terms", [])
	bonus_terms.append({"count": 1, "sides": 4, "results": [penalty], "kept": [true], "label": "Blade Ward penalty", "subtotal": -penalty})
	attack_result["bonus_dice_terms"] = bonus_terms
	return penalty


static func clear_shocking_grasp(target) -> void:
	if target is Character:
		target.remove_condition("shocking_grasp")
	elif target is Dictionary:
		var conditions: Dictionary = target.get("conditions", {})
		conditions.erase("shocking_grasp")
		target["conditions"] = conditions
		var sources: Dictionary = target.get("condition_sources", {})
		sources.erase("shocking_grasp")
		target["condition_sources"] = sources


## Bounded source bookkeeping for overlapping combat monster conditions.
static func has_condition_source(target: Dictionary, source: String) -> bool:
	for grants in target.get("condition_sources", {}).values():
		if grants.has(source):
			return true
	return false


static func remove_condition_source(target, source: String, condition_names: Array) -> void:
	var sources: Dictionary = target.condition_sources if target is Character else target.get("condition_sources", {})
	var conditions: Dictionary = target.conditions if target is Character else target.get("conditions", {})
	for condition in condition_names:
		if not conditions.has(condition):
			sources.erase(condition)
			continue
		if not sources.has(condition):
			# Compatibility with an already-marked target without source metadata.
			conditions.erase(condition)
			continue
		var grants: Dictionary = sources[condition]
		grants.erase(source)
		if grants.is_empty():
			sources.erase(condition)
			conditions.erase(condition)
		else:
			conditions[condition] = int(grants.values().max())
	if target is Dictionary:
		target["conditions"] = conditions
		target["condition_sources"] = sources


static func nonmagical_restraint_sources(target: Character) -> Array[String]:
	var result: Array[String] = []
	if target == null or not target.has_condition("restrained"):
		return result
	var sources: Dictionary = target.condition_sources.get("restrained", {})
	if sources.is_empty():
		result.append("ordinary")
		return result
	for source_value in sources:
		var source := str(source_value)
		if not SpellEffects.is_spell_source(source):
			result.append(source)
	return result


static func escape_nonmagical_restraint(target: Character) -> bool:
	if target == null:
		return false
	var sources := nonmagical_restraint_sources(target)
	if sources.is_empty():
		return false
	for source in sources:
		remove_condition_source(target, source, ["restrained"])
	return not target.has_condition("restrained")


static func tick_condition_sources(target) -> void:
	var sources: Dictionary = target.condition_sources if target is Character else target.get("condition_sources", {})
	var conditions: Dictionary = target.conditions if target is Character else target.get("conditions", {})
	for condition in sources.keys():
		var grants: Dictionary = sources[condition]
		# A full condition removal (for example a cleansing spell) clears sources.
		if not conditions.has(condition):
			sources.erase(condition)
			continue
		for source in grants.keys():
			if SpellEffects.records(target).has(source):
				continue
			if int(grants[source]) == -1:
				continue
			grants[source] = int(grants[source]) - 1
			if int(grants[source]) <= 0:
				grants.erase(source)
		if grants.is_empty():
			sources.erase(condition)
			conditions.erase(condition)
		else:
			conditions[condition] = int(grants.values().max())
	if target is Dictionary:
		target["conditions"] = conditions
		target["condition_sources"] = sources


static func is_immune_to_damage(target, damage_type: String) -> bool:
	if target == null or damage_type.is_empty():
		return false
	if target is Dictionary:
		return damage_type in target.get("damage_immunities", [])
	if target is not Character:
		return false
	if target.class_id == "created_creature":
		if damage_type == "poison":
			return true
		if damage_type == "psychic" and str(target.feature_uses.get("created_form_id", "")) == "animated_object":
			return true
	var custom_immunities: Variant = target.feature_uses.get("damage_immunities", [])
	if custom_immunities is Array and damage_type in custom_immunities:
		return true
	return false


## One typed settlement path; reductions/saves resolve before calling it.
## CombatState keeps concentration prompts and positional/death presentation.
static func resolve_damage(target, amount: int, damage_type: String, reaction_decisions: Dictionary = {}, bypass_resistance: bool = false, preserve_turning: bool = false, source_character: Character = null, damage_occurrence_id: int = 0, bypass_layers: Array = [], original_raw_amount: int = -1, reduction_prevented: int = 0) -> Dictionary:
	if damage_occurrence_id <= 0: damage_occurrence_id = WardRules.next_damage_occurrence_id()
	reaction_decisions = DamageResponseRules.begin(reaction_decisions, damage_occurrence_id, source_character)
	var linked := DamageLinkRules.settle(target, amount, damage_type, reaction_decisions, source_character, damage_occurrence_id, bypass_layers, original_raw_amount if original_raw_amount >= 0 else amount, reduction_prevented)
	if bool(linked.get("handled", false)):
		if linked.has("receipt"): return linked["receipt"]
		if str(linked.get("fallback", "keep_original")) == "refuse":
			return {"damage": 0, "raw": maxi(0, amount), "resolved": 0, "prevented": maxi(0, amount), "absorbed": 0, "hp_loss": 0, "damage_link_refused": true, "recipient_receipts": []}
		# Declined and stale choices keep the original recipient damage intact.
	var source_is_target := is_same_character(source_character, target)
	if ((has_condition(target, "resilient_sphere") and not source_is_target) or (source_character != null and has_condition(source_character, "resilient_sphere") and not source_is_target)) and not bypass_layers.has("prevention"):
		var blocked_raw := maxi(0, original_raw_amount if original_raw_amount >= 0 else amount)
		var blocked_receipt := {"damage": 0, "raw": blocked_raw, "prevented": blocked_raw, "reduction_prevented": maxi(0, reduction_prevented), "absorbed": 0, "resolved": 0, "hp_loss": 0, "blocked_by_resilient_sphere": true, "bypassed_layers": bypass_layers.duplicate()}
		_record_settled_damage_history(target, source_character, blocked_receipt, reaction_decisions)
		_finalize_damage_responses(target, source_character, damage_type, blocked_receipt, reaction_decisions, damage_occurrence_id)
		return blocked_receipt
	var resolved := maxi(0, amount)
	var enfeeblement_penalty := 0
	if resolved > 0 and not bool(reaction_decisions.get("_damage_link_child", false)) and not bool(reaction_decisions.get("_damage_response_child", false)):
		enfeeblement_penalty = damage_source_penalty(resolved, source_character)
		resolved -= enfeeblement_penalty
	var response_raw := maxi(0, original_raw_amount if original_raw_amount >= 0 else amount)
	var incoming_replacement := DamageResponseRules.replacements(target, "incoming", resolved, response_raw, damage_type, reaction_decisions)
	resolved = int(incoming_replacement.remaining)
	var resistance_spell_reduction := 0
	if resolved > 0 and not bypass_layers.has("resistance") and target is Character and target.has_condition("resistance_spell") and target.resistance_last_turn_serial != active_turn_serial and target.resistance_damage_type == damage_type:
		resistance_spell_reduction = mini(resolved, Dice.roll(4, target))
		resolved -= resistance_spell_reduction
		target.resistance_last_turn_serial = active_turn_serial
	elif resolved > 0 and not bypass_layers.has("resistance") and target is Dictionary:
		var target_conditions: Dictionary = target.get("conditions", {})
		if target_conditions.has("resistance_spell") and int(target.get("resistance_last_turn_serial", -1)) != active_turn_serial and str(target.get("resistance_damage_type", "")) == damage_type:
			resistance_spell_reduction = mini(resolved, Dice.roll(4))
			resolved -= resistance_spell_reduction
			target["resistance_last_turn_serial"] = active_turn_serial
	if target is Character:
		if not bypass_resistance and not bypass_layers.has("resistance"):
			resolved = target.resist_damage(resolved, damage_type)
		var char_vulns: Variant = target.feature_uses.get("damage_vulnerabilities", [])
		if (target.class_id == "created_creature" and damage_type == "bludgeoning" and str(target.feature_uses.get("created_form_id", "")) == "skeleton") or (char_vulns is Array and damage_type in char_vulns):
			resolved *= 2
	elif target is Dictionary:
		if not bypass_resistance and not bypass_layers.has("resistance") and (damage_type in target.get("damage_resistances", []) or str(target.get("protection_from_energy_type", "")) == damage_type or (damage_type == "poison" and target.get("conditions", {}).has("protection_from_poison")) or (damage_type == "necrotic" and not target.get("aura_of_life_sources", []).is_empty())):
			resolved = int(floor(float(resolved) / 2.0))
		if damage_type in target.get("damage_vulnerabilities", []):
			resolved *= 2
	else:
		return {"damage": 0, "resolved": 0}
	var ward_res := {"absorbed": 0, "remaining_damage": resolved, "projected": false, "pool_id": "", "owner_id": "", "ward_remaining_hp": 0, "message": ""}
	if not bypass_layers.has("ward"):
		ward_res = WardRules.absorb_damage(target, resolved, reaction_decisions, damage_occurrence_id)
	resolved = int(ward_res.get("remaining_damage", resolved))
	if resolved > 0 and not bypass_layers.has("immunity") and is_immune_to_damage(target, damage_type):
		resolved = 0
	var resolved_replacement := DamageResponseRules.replacements(target, "resolved", resolved, response_raw, damage_type, reaction_decisions)
	resolved = int(resolved_replacement.remaining)
	var actual := 0
	var death_ward_prevented := false
	var undead_fortitude_saved := false
	var is_alive_before: bool = target.is_alive if target is Character else bool(target.get("is_alive", true))
	var created_hp_before: int = target.current_hp if target is Character else int(target.get("current_hp", 0))
	var created_temp_hp_before: int = target.temp_hp if target is Character else int(target.get("temp_hp", 0))
	if target is Character:
		var ward_hp_damage := maxi(0, resolved - target.temp_hp)
		if target.current_hp > 0 and ward_hp_damage >= target.current_hp and SpellEffects.has_spell(target, "death_ward"):
			var hp_before_ward: int = target.current_hp
			target.absorb_temporary_hp(resolved)
			target.current_hp = 1
			target.is_alive = true
			actual = hp_before_ward - 1
			death_ward_prevented = true
			SpellEffects.consume_spell(target, "death_ward", "depleted", {"source_instance_id": str(reaction_decisions.get("damage_source_instance_id", ""))})
		else:
			var damage_facts := {
				"hp_before": created_hp_before,
				"damage": resolved,
				"damage_type": damage_type,
				"critical": bool(reaction_decisions.get("damage_is_critical", false)),
				"decisions": reaction_decisions,
			}
			actual = target.take_damage(resolved, bool(reaction_decisions.get("relentless_rage_bardic_inspiration", false)), bool(reaction_decisions.get("damage_is_critical", false)), damage_facts)
			if bool(damage_facts.get("zero_hp_replacement_saved", false)):
				undead_fortitude_saved = true
				actual = maxi(0, created_hp_before - int(damage_facts.get("replacement_hp", target.current_hp)))
	elif resolved > 0:
		var monster_hp := int(target.get("current_hp", 0))
		var monster_temp_hp := int(target.get("temp_hp", 0))
		var monster_hp_damage := maxi(0, resolved - monster_temp_hp)
		if monster_hp > 0 and monster_hp_damage >= monster_hp and SpellEffects.has_spell(target, "death_ward"):
			target["temp_hp"] = maxi(0, monster_temp_hp - resolved)
			target["current_hp"] = 1
			target["is_alive"] = true
			actual = monster_hp - 1
			death_ward_prevented = true
			SpellEffects.consume_spell(target, "death_ward", "depleted", {"source_instance_id": str(reaction_decisions.get("damage_source_instance_id", ""))})
		else:
			var absorbed := mini(resolved, maxi(0, monster_temp_hp))
			if absorbed > 0:
				target["temp_hp"] = monster_temp_hp - absorbed
			var hp_damage := resolved - absorbed
			var new_hp := monster_hp - hp_damage
			if monster_hp > 0 and new_hp <= 0:
				target["current_hp"] = 0
				reaction_decisions["zero_hp_outright_death"] = hp_damage >= monster_hp + int(target.get("max_hp", 0))
				var replaced := resolve_zero_hp_replacement(target, monster_hp, resolved, damage_type, bool(reaction_decisions.get("damage_is_critical", false)), reaction_decisions)
				if replaced:
					undead_fortitude_saved = true
					actual = maxi(0, monster_hp - int(target.get("current_hp", 1)))
				else:
					target["current_hp"] = 0
					target["is_alive"] = false
					actual = mini(hp_damage, maxi(0, monster_hp))
			else:
				actual = mini(hp_damage, maxi(0, monster_hp))
				target["current_hp"] = new_hp
				if int(target["current_hp"]) <= 0:
					target["is_alive"] = false
	var aftermath_receipt := ZeroHpAftermathRules.settle(target, created_hp_before, is_alive_before, damage_type, reaction_decisions, source_character)
	if target is Character and target.feature_uses.get("created_form_id", "") == "animated_object": AnimatedObjectRules.damage(target, created_hp_before, maxi(0, resolved - created_temp_hp_before))
	if resolved > 0:
		_end_damage_broken_spell_effects(target, source_character != null and not source_character.character_id.is_empty(), {"actor_id": source_character.character_id if source_character != null else "", "source_instance_id": str(reaction_decisions.get("damage_source_instance_id", source_character.character_id if source_character != null else "")), "resolved": resolved})
		if source_character != null:
			var damage_cause := {"actor_id": source_character.character_id, "source_instance_id": str(reaction_decisions.get("damage_source_instance_id", source_character.character_id))}
			SpellEffects.consume_spell(source_character, "sanctuary", "damage", damage_cause)
			SpellEffects.consume_spell(source_character, "invisibility", "damage", damage_cause)
	if resolved > 0 and target is Dictionary and has_condition_source(target, RogueRules.CUNNING_KNOCKOUT_SOURCE):
		remove_condition_source(target, RogueRules.CUNNING_KNOCKOUT_SOURCE, ["unconscious"])
		target.erase("rogue_cunning_knock_out_dc")
	elif resolved > 0 and target is Character and target.has_condition("unconscious"):
		target.remove_condition("unconscious")
	# Temporary HP still counts as taking damage, even with no HP loss.
	if resolved > 0:
		if not preserve_turning:
			ClericRules.clear_turning_after_damage(target)
		elif target is Dictionary:
			PaladinRules.clear_abjure_foes_after_damage(target)
	var hp_after: int = target.current_hp if target is Character else int(target.get("current_hp", 0))
	var temp_hp_after: int = target.temp_hp if target is Character else int(target.get("temp_hp", 0))
	var is_alive_after: bool = target.is_alive if target is Character else bool(target.get("is_alive", true))
	var temp_hp_absorbed: int = maxi(0, created_temp_hp_before - temp_hp_after)
	var is_crit: bool = bool(reaction_decisions.get("damage_is_critical", false))
	var receipt_raw := maxi(0, original_raw_amount if original_raw_amount >= 0 else amount)
	var receipt := {
		"damage": actual,
		"raw": receipt_raw,
		"prevented": maxi(0, receipt_raw - resolved),
		"reduction_prevented": maxi(0, reduction_prevented),
		"bypassed_layers": bypass_layers.duplicate(),
		"absorbed": int(ward_res.get("absorbed", 0)) + temp_hp_absorbed,
		# This receipt is captured at this settlement boundary. `actual` may
		# include damage absorbed by Temporary HP or exceed remaining HP.
		"hp_loss": maxi(0, maxi(0, created_hp_before) - maxi(0, hp_after)),
		"resolved": resolved,
		"ward_absorbed": int(ward_res.get("absorbed", 0)),
		"ward_pool_id": str(ward_res.get("ward_pool_id", "")),
		"ward_owner_id": str(ward_res.get("ward_owner_id", "")),
		"ward_remaining_hp": int(ward_res.get("ward_remaining_hp", 0)),
		"ward_projected": bool(ward_res.get("projected", false)),
		"ward_message": str(ward_res.get("message", "")),
		"temp_hp_absorbed": temp_hp_absorbed,
		"hp_before": created_hp_before,
		"hp_after": hp_after,
		"temp_hp_before": created_temp_hp_before,
		"temp_hp_after": temp_hp_after,
		"is_alive_before": is_alive_before,
		"is_alive_after": is_alive_after,
		"knocked_out": resolved > 0 and hp_after <= 0,
		"critical": is_crit,
		"damage_is_critical": is_crit,
		"source_roll_penalty": enfeeblement_penalty,
		"resistance_spell_reduction": resistance_spell_reduction,
		"death_ward_prevented": death_ward_prevented,
		"undead_fortitude_saved": undead_fortitude_saved,
		"zero_hp_replacement_saved": undead_fortitude_saved
	}
	receipt["zero_hp_receipt"] = reaction_decisions.get("zero_hp_receipt", {}).duplicate(true)
	reaction_decisions.erase("zero_hp_receipt")
	receipt["zero_hp_aftermath"] = aftermath_receipt
	receipt["replacement_receipts"] = incoming_replacement.receipts + resolved_replacement.receipts
	receipt["replacement_absorbed"] = int(incoming_replacement.replaced) + int(resolved_replacement.replaced)
	receipt["absorbed"] += int(receipt["replacement_absorbed"])
	_record_settled_damage_history(target, source_character, receipt, reaction_decisions)
	_finalize_damage_responses(target, source_character, damage_type, receipt, reaction_decisions, damage_occurrence_id)
	return receipt


static func _finalize_damage_responses(target, source_character: Character, damage_type: String, receipt: Dictionary, reaction_decisions: Dictionary, damage_occurrence_id: int) -> void:
	receipt["root_occurrence_id"] = reaction_decisions["_damage_cause"].root
	receipt["damage_occurrence_id"] = damage_occurrence_id
	var origin = reaction_decisions.get("_damage_origin", source_character)
	if not reaction_decisions.has("_damage_origin"):
		var origin_id := str(reaction_decisions.get("damage_source_actor_id", ""))
		for entity in reaction_decisions.get("monsters", []):
			if entity is Dictionary and str(entity.get("id", "")) == origin_id: origin = entity; break
	receipt["countereffect_receipts"] = DamageResponseRules.counters(target, origin, damage_type, receipt, reaction_decisions)


static func damage_source_penalty(amount: int, source: Character) -> int:
	return mini(maxi(0, amount), Dice.roll(8, source)) if amount > 0 and source != null and source.has_condition("ray_of_enfeeblement") else 0


static func _record_settled_damage_history(target, source: Character, receipt: Dictionary, decisions: Dictionary) -> void:
	if not target is Character or source == null or source.character_id.is_empty():
		return
	var at_seconds := int(GameManager.campaign_elapsed_seconds)
	var source_instance_id := str(decisions.get("damage_source_instance_id", source.character_id))
	if source_instance_id.is_empty():
		source_instance_id = source.character_id
	target.record_recent_damage(source.character_id, source_instance_id, int(receipt.get("raw", 0)), int(receipt.get("prevented", 0)), int(receipt.get("absorbed", 0)), int(receipt.get("resolved", 0)), int(receipt.get("hp_loss", 0)), at_seconds)
	var history: Variant = decisions.get("combat_history", null)
	if history is CombatActionHistory:
		history.record_damage(target, source, source_instance_id, receipt)


static func get_zero_hp_replacement_rule(target) -> Dictionary:
	return SharedStepExecutor.get_zero_hp_replacement_rule(target)


static func resolve_zero_hp_replacement(target, hp_before: int, damage: int, damage_type: String, critical: bool, decisions: Dictionary = {}) -> bool:
	return SharedStepExecutor.resolve_zero_hp_replacement(target, hp_before, damage, damage_type, critical, decisions)


static func _end_damage_broken_spell_effects(target, party_damage: bool = true, cause: Dictionary = {}) -> void:
	if target == null:
		return
	SpellEffects.publish_event(target, {"type": "damage"}.merged(cause, true))
	for source in SpellEffects.records(target).keys():
		var record: Dictionary = SpellEffects.records(target)[source]
		if SpellEffects._has_end_rule_for_event(record, "damage"):
			continue
		if bool(record.get("end_on_any_damage", false)) or (party_damage and bool(record.get("end_on_target_damage", false))):
			SpellEffects.remove(target, str(source), "damage", cause)
	if not party_damage or not target is Dictionary:
		return
	var sources: Dictionary = target.get("condition_sources", {}).get("charmed", {})
	var friendship_sources: Array[String] = []
	var friendship_caster_ids: Array = target.get("animal_friendship_caster_ids", []).duplicate()
	for source_id in sources:
		if str(source_id).begins_with("animal_friendship:"):
			friendship_sources.append(str(source_id))
	for source_id in friendship_sources:
		remove_condition_source(target, source_id, ["charmed"])
		friendship_caster_ids.erase(str(source_id).trim_prefix("animal_friendship:"))
	if friendship_sources.size() > 0:
		target["animal_friendship_caster_ids"] = friendship_caster_ids


## Resolve Lay on Hands against a living or downed allied character.
## The caller supplies the amount requested; the pool and missing HP cap it.
static func resolve_lay_on_hands(caster: Character, target: Character, requested_amount: int, conditions_to_remove: Array[String] = []) -> Dictionary:
	if caster == null or target == null or requested_amount < 0:
		return {"success": false, "healing": 0, "conditions_removed": [], "message": "Lay on Hands needs a valid target."}
	if target.is_dead():
		return {"success": false, "healing": 0, "conditions_removed": [], "message": "%s is dead and cannot be restored by Lay on Hands." % target.character_name}
	var pool := int(caster.feature_uses.get("paladin_lay_on_hands", 0))
	var remove_cost := 0
	var unique_conditions: Array[String] = []
	for condition in conditions_to_remove:
		var eligible := condition == "poisoned" and caster.has_feature("paladin_lay_on_hands") or condition in PaladinRules.RESTORING_TOUCH_CONDITIONS and caster.has_feature("paladin_restoring_touch")
		if not eligible or not target.conditions.has(condition) or condition in unique_conditions:
			return {"success": false, "healing": 0, "conditions_removed": [], "message": "Lay on Hands cannot remove that condition from the target."}
		unique_conditions.append(condition)
	remove_cost = unique_conditions.size() * 5
	if pool < remove_cost:
		return {"success": false, "healing": 0, "conditions_removed": [], "message": "Lay on Hands needs 5 healing-pool points per condition removed."}
	var missing := maxi(0, target.max_hp - target.current_hp)
	var healing_request := mini(requested_amount, mini(pool - remove_cost, missing))
	var healing := target.heal(healing_request) if healing_request > 0 else 0
	if healing <= 0 and unique_conditions.is_empty():
		var message := "%s can't regain Hit Points right now." % target.character_name if is_healing_suppressed(target) else "%s has no wounds or eligible conditions Lay on Hands can restore." % target.character_name
		return {"success": false, "healing": 0, "conditions_removed": [], "message": message}
	for condition in unique_conditions:
		target.remove_condition(condition)
	if healing > 0:
		target.is_alive = true
	caster.feature_uses["paladin_lay_on_hands"] = pool - remove_cost - healing
	var message := "%s restores %d hit points to %s." % [caster.character_name, healing, target.character_name] if healing > 0 else "%s uses Lay on Hands on %s." % [caster.character_name, target.character_name]
	if not unique_conditions.is_empty():
		message += " Removes %s." % ", ".join(unique_conditions)
	return {"success": true, "healing": healing, "conditions_removed": unique_conditions, "message": message}


## Resolve a monk bonus unarmed strike through the normal weapon attack boundary.
static func resolve_unarmed_attack(attacker: Character, target_entity) -> Dictionary:
	if attacker == null or target_entity == null:
		return {"hit": false, "damage": 0, "message": "Unarmed Strike needs a valid target."}
	return resolve_weapon_attack(attacker, target_entity, unarmed_attack_profile(attacker))


static func unarmed_attack_profile(attacker: Character) -> Dictionary:
	if attacker == null:
		return {}
	for damage_type in ["slashing", "piercing", "bludgeoning"]:
		if attacker.has_condition("alter_self_natural_%s" % damage_type):
			var spell_ability := attacker.get_spellcasting_ability()
			return {
				"id": "alter_self_natural_weapons", "type": "weapon", "weapon_type": "simple", "properties": [],
				"ability": spell_ability, "damage": "1d6+%s" % spell_ability,
				"damage_type": damage_type, "range": 1,
			}
	var martial_arts := attacker.can_use_martial_arts()
	var damage_die := attacker.get_martial_arts_die() if martial_arts else "1"
	var damage_type := "force" if attacker.has_feature("monk_empowered_strikes") else "bludgeoning"
	return {
		"id": "unarmed_strike", "type": "weapon", "weapon_type": "simple", "properties": [],
		"ability": "DEX" if martial_arts and attacker.ability_scores.get_score("DEX") >= attacker.ability_scores.get_score("STR") else "STR",
		"damage": damage_die + "+DEX" if martial_arts and attacker.ability_scores.get_score("DEX") >= attacker.ability_scores.get_score("STR") else damage_die + "+STR",
		"damage_type": damage_type,
		"range": 1,
	}


## Resolve the two unarmed strikes granted by Monk Flurry of Blows.
static func resolve_stunning_strike(attacker: Character, target: Dictionary, decisions: Dictionary = {}) -> Dictionary:
	if attacker == null or not attacker.has_feature("monk_stunning_strike") or int(target.get("current_hp", 0)) <= 0 or int(attacker.feature_uses.get("stunning_strike_used", 0)) > 0 or attacker.get_focus_points() < 1:
		return {"success": false, "message": "Stunning Strike is unavailable."}
	attacker.spend_focus_points(1)
	attacker.feature_uses["stunning_strike_used"] = 1
	var dc := 8 + attacker.proficiency_bonus + attacker.ability_scores.get_ability_modifier("WIS")
	var total := BarbarianRules.roll_monster_save(target, "CON", null, false, false, decisions)
	var failed := total < dc
	var conditions: Dictionary = target.get("conditions", {})
	if failed and "stunned" not in target.get("condition_immunities", []):
		# Separate source-bound status from ordinary duration-based spell stuns.
		target["stunning_strike_stunned"] = true
		var stun_sources: Array = target.get("stunning_strike_stun_sources", [])
		if attacker.get_instance_id() not in stun_sources:
			stun_sources.append(attacker.get_instance_id())
		target["stunning_strike_stun_sources"] = stun_sources
		if not conditions.has("stunned"):
			conditions["stunned"] = 99
			target["stunning_strike_owns_condition"] = true
	elif not failed:
		target["stunning_strike_advantage"] = true
		var slow_sources: Array = target.get("stunning_strike_slow_sources", [])
		if attacker.get_instance_id() not in slow_sources:
			slow_sources.append(attacker.get_instance_id())
		target["stunning_strike_slow_sources"] = slow_sources
		if not target.has("stunning_strike_speed"):
			target["stunning_strike_speed"] = int(target.get("speed", 6))
			target["speed"] = int(floor(float(target.get("speed", 6)) / 2.0))
		target["stunning_strike_advantage_source"] = attacker.get_instance_id()
	target["stunning_strike_source"] = attacker.get_instance_id()
	target["conditions"] = conditions
	var outcome := "Stunned" if target.get("stunning_strike_stunned", false) else ("immune to Stunned" if failed else "slowed; next attack has Advantage")
	return {"success": true, "save_total": total, "dc": dc, "stunned": target.get("stunning_strike_stunned", false), "message": "Stunning Strike: %s (%d vs DC %d), until the Monk's next turn." % [outcome, total, dc]}


static func resolve_deflect_redirect(monk: Character, target: Dictionary, damage_type: String) -> Dictionary:
	if monk == null or not monk.has_feature("monk_deflect_attacks") or int(target.get("current_hp", 0)) <= 0 or not monk.spend_focus_points(1):
		return {"success": false, "damage": 0}
	var dc := 8 + monk.proficiency_bonus + monk.ability_scores.get_ability_modifier("WIS")
	var save := BarbarianRules.roll_monster_save(target, "DEX")
	var rolled := 0
	if save < dc:
		rolled = maxi(0, Dice.parse_dice_string(monk.get_martial_arts_die()) + Dice.parse_dice_string(monk.get_martial_arts_die()) + monk.ability_scores.get_ability_modifier("DEX"))
	var damage := int(resolve_damage(target, rolled, damage_type, {}, false, false, monk)["damage"])
	return {"success": true, "damage": damage, "message": "Deflect Attacks redirects %d %s damage to %s (DEX %d vs DC %d)." % [damage, damage_type, target.get("name", "target"), save, dc]}


## Costs belong to the validated command, not to individual strikes.
static func resolve_flurry_of_blows(attacker: Character, target_entity) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var strike_count := 3 if attacker != null and attacker.has_feature("monk_heightened_focus") else 2
	for strike_index in strike_count:
		if target_entity is Character and not target_entity.is_alive:
			break
		if target_entity is Dictionary and not target_entity.get("is_alive", true):
			break
		results.append(resolve_unarmed_attack(attacker, target_entity))
		if target_entity is Dictionary and int(target_entity.get("current_hp", 0)) <= 0:
			target_entity["is_alive"] = false
	return results


static func spell_grants_condition(spell_data: Dictionary, condition: String) -> bool:
	if str(spell_data.get("condition_on_failed_save", "")) == condition:
		return true
	for effect in spell_data.get("effects", []):
		if effect is Dictionary and str(effect.get("type", "")) == "grant_condition" and str(effect.get("condition", "")) == condition and bool(effect.get("on_failed_save", false)):
			return true
	return false


## Activate Barbarian Reckless Attack for the current turn.
## The marker lasts through the rest of the round so monster attacks gain
## advantage, then CombatState clears it when the barbarian's next turn starts.
static func activate_reckless_attack(attacker: Character) -> Dictionary:
	if attacker == null or not attacker.has_feature("barbarian_reckless_attack"):
		return {"success": false, "message": "Reckless Attack is unavailable."}
	if int(attacker.feature_uses.get("barbarian_reckless_attack_used_this_turn", 0)) > 0:
		return {"success": false, "message": "Reckless Attack was already chosen this turn."}
	attacker.feature_uses["barbarian_reckless_attack_used_this_turn"] = 1
	attacker.add_condition("reckless_attack", 2)
	return {"success": true, "message": "%s attacks recklessly until their next turn." % attacker.character_name}


## Detect nearby celestial, fiend, and undead monster records for Paladin Divine Sense.
## Monster creature types come from curated production data, never name matching.
static func resolve_divine_sense(caster: Character, monsters: Array, origin: Vector2i, max_distance: int = 12, current_round: int = 0, refreshing: bool = false) -> Dictionary:
	const FEATURE_ID := "paladin_channel_divinity_divine_sense"
	if caster == null or not caster.has_feature(FEATURE_ID):
		return {"success": false, "target_ids": [], "message": "Divine Sense is unavailable."}
	var detection_types: Array = ["celestial", "fiend", "undead"]
	var duration_rounds := 100
	var feature_data: Dictionary = caster.get_feature(FEATURE_ID)
	for effect in feature_data.get("effects", []):
		if effect.get("type", "") == "divine_sense":
			if effect.get("creature_types", []) is Array:
				detection_types = effect.get("creature_types", [])
			duration_rounds = maxi(1, int(effect.get("duration_minutes", 10)) * 10)
			break
	var target_ids: Array[String] = []
	var target_labels: Array[String] = []
	for monster in monsters:
		if not monster is Dictionary or not monster.get("is_alive", true):
			continue
		var creature_type := str(monster.get("creature_type", ""))
		if creature_type not in detection_types:
			continue
		if HexUtils.get_distance(origin, monster.get("hex_position", Vector2i.ZERO)) > max_distance:
			continue
		var target_id := str(monster.get("id", ""))
		if target_id.is_empty():
			continue
		target_ids.append(target_id)
		var target_position: Vector2i = monster.get("hex_position", Vector2i.ZERO)
		target_labels.append("%s (%s) at %s" % [monster.get("name", target_id), creature_type, target_position])
	caster.feature_uses["paladin_divine_sense_targets"] = target_ids
	if not refreshing:
		caster.feature_uses["paladin_divine_sense_expires_round"] = current_round + duration_rounds
	return {"success": true, "target_ids": target_ids, "labels": target_labels, "message": "Divine Sense detects: %s." % ", ".join(target_labels) if not target_labels.is_empty() else "Divine Sense detects no nearby celestial, fiend, or undead."}


## Grant one captured, hour-long die for a failed D20 Test.
static func resolve_bardic_inspiration(caster: Character, target: Character, distance_feet: int = 0) -> Dictionary:
	if not BardicInspirationRules.can_receive(caster, target, distance_feet) or not caster.has_feature("bard_bardic_inspiration"):
		return {"success": false, "message": "Bardic Inspiration needs another valid ally."}
	if BardicInspirationRules.has_die(target):
		return {"success": false, "message": "%s already has Bardic Inspiration." % target.character_name}
	if not caster.use_feature("bard_bardic_inspiration"):
		return {"success": false, "message": "%s has no Bardic Inspiration uses remaining." % caster.character_name}
	var die := "1d6"
	var feature := caster.get_feature("bard_bardic_inspiration")
	for effect in feature.get("effects", []):
		if effect.get("type", "") != "bardic_inspiration":
			continue
		var die_by_level: Dictionary = effect.get("die_by_level", {})
		var threshold := 0
		for key in die_by_level:
			if int(key) <= caster.level and int(key) > threshold:
				threshold = int(key)
		if threshold > 0:
			die = str(die_by_level[str(threshold)])
		else:
			die = str(effect.get("die", die))
	target.feature_uses["bardic_inspiration_die"] = die
	target.feature_uses["bardic_inspiration_source"] = caster.character_name
	target.feature_uses["bardic_inspiration_seconds_remaining"] = 3600
	return {"success": true, "die": die, "message": "%s grants %s Bardic Inspiration (%s)." % [caster.character_name, target.character_name, die]}


## Mark a monster for a ranger's concentration-bound Favored Foe feature.
static func resolve_favored_foe_mark(attacker: Character, target_entity: Dictionary) -> Dictionary:
	if attacker == null or target_entity.is_empty() or not attacker.has_feature("ranger_favored_foe"):
		return {"success": false, "message": "Favored Foe needs a valid ranger and target."}
	var target_id := str(target_entity.get("id", ""))
	if target_id.is_empty():
		return {"success": false, "message": "Favored Foe target has no stable combat identity."}
	var conditions: Dictionary = target_entity.get("conditions", {})
	conditions["favored_foe"] = 10
	target_entity["conditions"] = conditions
	attacker.feature_uses["ranger_favored_foe_target_id"] = target_id
	attacker.concentrating_on = {
		"spell_id": "ranger_favored_foe",
		"targets": [],
		"effects": []
	}
	return {"success": true, "target_id": target_id, "message": "%s marks %s as a Favored Foe." % [attacker.character_name, target_entity.get("name", "the target")]}


## Resolve the once-per-turn bonus damage from an active Favored Foe mark.
static func resolve_favored_foe_damage(attacker: Character, target_entity: Dictionary) -> Dictionary:
	if attacker == null or target_entity.is_empty() or not attacker.has_feature("ranger_favored_foe"):
		return {"success": false, "damage": 0, "message": "No Favored Foe damage applies."}
	var target_id := str(target_entity.get("id", ""))
	if str(attacker.feature_uses.get("ranger_favored_foe_target_id", "")) != target_id:
		return {"success": false, "damage": 0, "message": "Target is not the ranger's Favored Foe."}
	if not target_entity.get("conditions", {}).has("favored_foe") or int(attacker.feature_uses.get("ranger_favored_foe_used_this_turn", 0)) > 0:
		return {"success": false, "damage": 0, "message": "Favored Foe damage is unavailable this turn."}
	var dice := "1d4"
	if attacker.level >= 14:
		dice = "1d8"
	elif attacker.level >= 6:
		dice = "1d6"
	var rolled := Dice.parse_dice_string(dice)
	var actual := int(resolve_damage(target_entity, rolled, "", {}, false, false, attacker)["damage"])
	attacker.feature_uses["ranger_favored_foe_used_this_turn"] = 1
	return {"success": true, "damage": actual, "dice": dice, "message": "Favored Foe deals +%d %s damage." % [actual, dice]}


## Mark a monster for the concentration-bound Hunter's Mark spell.
static func resolve_hunters_mark(caster: Character, target_entity: Dictionary) -> Dictionary:
	if caster == null or target_entity.is_empty():
		return {"success": false, "message": "Hunter's Mark needs a valid target."}
	var target_id := str(target_entity.get("id", ""))
	if target_id.is_empty():
		return {"success": false, "message": "Hunter's Mark target has no stable combat identity."}
	var conditions: Dictionary = target_entity.get("conditions", {})
	conditions["hunters_mark"] = 10
	target_entity["conditions"] = conditions
	caster.feature_uses["hunters_mark_target_id"] = target_id
	caster.concentrating_on = {
		"spell_id": "hunters_mark",
		"targets": [],
		"effects": [{"type": "hunters_mark", "dice": "1d6", "duration": 10}],
	}
	return {"success": true, "target_id": target_id, "message": "%s marks %s as their quarry." % [caster.character_name, target_entity.get("name", "the target")]}


## Resolve Hunter's Mark's extra damage on every weapon hit against its target.
static func resolve_hunters_mark_damage(attacker: Character, target_entity: Dictionary) -> Dictionary:
	if attacker == null or target_entity.is_empty():
		return {"success": false, "damage": 0, "message": "No Hunter's Mark damage applies."}
	var target_id := str(target_entity.get("id", ""))
	if str(attacker.feature_uses.get("hunters_mark_target_id", "")) != target_id or not target_entity.get("conditions", {}).has("hunters_mark"):
		return {"success": false, "damage": 0, "message": "Target is not marked by Hunter's Mark."}
	var dice := "1d6"
	for feature in attacker.features:
		for effect in attacker._feature_effects(feature):
			if effect.get("type", "") == "spell_damage_dice_override" and str(effect.get("spell_id", "")) == "hunters_mark":
				dice = str(effect.get("dice", dice))
	var rolled := Dice.parse_dice_string(dice)
	var actual := int(resolve_damage(target_entity, rolled, "force", {}, false, false, attacker)["damage"])
	return {"success": true, "damage": actual, "dice": dice, "damage_type": "force", "message": "Hunter's Mark deals +%d %s force damage." % [actual, dice]}


## Resolve a basic weapon attack.
## Returns a result dictionary describing the hit, miss, crit, damage, and logs.
static func shillelagh_damage_die(character_level: int) -> String:
	if character_level >= 17:
		return "2d6"
	if character_level >= 11:
		return "1d12"
	if character_level >= 5:
		return "1d10"
	return "1d8"


static func true_strike_bonus_damage(character_level: int) -> String:
	if character_level >= 17:
		return "3d6"
	if character_level >= 11:
		return "2d6"
	if character_level >= 5:
		return "1d6"
	return ""


static func resolve_weapon_attack(attacker: Character, target_entity, weapon_data: Dictionary, advantage: bool = false, disadvantage: bool = false, reaction_decisions: Dictionary = {}, additional_damage: Dictionary = {}) -> Dictionary:
	weapon_data = weapon_data.duplicate(true)
	if has_condition(attacker, "resilient_sphere") or has_condition(target_entity, "resilient_sphere"):
		return {"hit": false, "damage": 0, "blocked_by_resilient_sphere": true, "message": "The attack cannot pass through Resilient Sphere."}
	var magic_weapon_bonus := SpellEffects.magic_weapon_bonus(attacker, str(weapon_data.get("id", "")))
	if magic_weapon_bonus > 0:
		weapon_data["magical"] = true
	if SpellEffects.has_spell(target_entity, "sanctuary"):
		var sanctuary_dc := _spell_effect_save_dc(target_entity, "sanctuary", attacker.get_spell_save_dc())
		var sanctuary_save := int(attacker.saving_throw_test_to_dc("WIS", sanctuary_dc, false, false, reaction_decisions).get("total", 0))
		if sanctuary_save < sanctuary_dc:
			return {"hit": false, "damage": 0, "sanctuary_blocked": true, "sanctuary_save_total": sanctuary_save, "sanctuary_save_dc": sanctuary_dc, "message": "%s fails the Wisdom save against Sanctuary and loses the attack." % attacker.character_name}
	SpellEffects.consume_spell(attacker, "sanctuary", "attack", {"actor_id": attacker.character_id, "action": "attack"})
	if attacker.creature_type in protected_creature_types_for_target(target_entity):
		disadvantage = true
	BarbarianRules.maintain_rage(attacker)
	if attacker.has_condition("shillelagh"):
		if str(weapon_data.get("id", "")) != attacker.shillelagh_weapon_id:
			attacker.remove_condition("shillelagh")
			attacker.shillelagh_weapon_id = ""
		else:
			weapon_data["ability"] = attacker.get_spellcasting_ability()
			weapon_data["damage"] = shillelagh_damage_die(attacker.level)
			weapon_data["damage"] += "+" + str(weapon_data["ability"])
			weapon_data["damage_type"] = str(reaction_decisions.get("shillelagh_damage_type", weapon_data.get("damage_type", "bludgeoning")))
			weapon_data["magical"] = true
	if weapon_data.get("type", "") == "weapon" and not weapon_data.has("wild_shape_attack"):
		var properties: Array = weapon_data.get("properties", [])
		if "finesse" in properties and not bool(weapon_data.get("_true_strike", false)) and not attacker.has_condition("shillelagh"):
			weapon_data["ability"] = "DEX" if attacker.ability_scores.get_score("DEX") > attacker.ability_scores.get_score("STR") else "STR"
		var damage := str(weapon_data.get("damage", "1"))
		if "versatile" in properties and attacker.inventory.get_equipped(Inventory.Slot.SHIELD).is_empty() and attacker.inventory.get_equipped(Inventory.Slot.OFFHAND).is_empty():
			var die := "1d10" if str(weapon_data.get("id", "")) in ["longsword", "battleaxe", "warhammer", "war_pick", "trident"] else "1d8"
			damage = damage.replace(damage.split("+")[0].strip_edges(), die)
		weapon_data["damage"] = damage
	if attacker.class_id == "warlock" and WarlockRules.has_invocation(attacker, "pact_of_the_blade") and str(weapon_data.get("type", "")) == "weapon" and int(weapon_data.get("range", 1)) <= 1 and str(weapon_data.get("id", "")) in [attacker.inventory.get_weapon(), attacker.inventory.get_equipped(Inventory.Slot.OFFHAND)]:
		weapon_data["ability"] = "CHA"
	if attacker.can_use_martial_arts() and (attacker.is_monk_weapon(weapon_data) or weapon_data.get("id", "") == "unarmed_strike"):
		if attacker.ability_scores.get_score("DEX") > attacker.ability_scores.get_score("STR") and not bool(weapon_data.get("_true_strike", false)):
			weapon_data["ability"] = "DEX"
		var current_die := str(weapon_data.get("damage", "1d4")).split("+")[0].strip_edges()
		if current_die.begins_with("1d") and current_die.substr(2).to_int() < attacker.get_martial_arts_die().substr(2).to_int():
			weapon_data["damage"] = attacker.get_martial_arts_die()
		if not ["STR", "DEX", "CON", "INT", "WIS", "CHA"].any(func(token): return token in str(weapon_data.get("damage", ""))):
			weapon_data["damage"] = str(weapon_data.get("damage", "1d6")) + "+" + str(weapon_data.get("ability", "STR"))
	if bool(weapon_data.get("_true_strike", false)) and not attacker.has_condition("shillelagh"):
		var weapon_die := str(weapon_data.get("damage", "1d4")).split("+")[0].strip_edges()
		weapon_data["damage"] = weapon_die + "+" + str(weapon_data.get("ability", attacker.get_spellcasting_ability()))
	weapon_data = AttackProfileRules.apply_weapon(attacker, weapon_data, reaction_decisions)
	# Ordinary catalog weapons carry dice, not the wielder's ability bonus.
	# Add it only after all ability overrides, leaving stat-block profiles alone.
	if weapon_data.get("type", "") == "weapon" and not weapon_data.has("wild_shape_attack") and not bool(weapon_data.get("fixed_damage", false)):
		var formula := str(weapon_data.get("damage", "1"))
		if "d" in formula.to_lower() and not ["STR", "DEX", "CON", "INT", "WIS", "CHA"].any(func(token): return token in formula.to_upper()):
			weapon_data["damage"] = formula + "+" + str(weapon_data.get("ability", "STR"))
	if target_entity is Dictionary and target_entity.has("stunning_strike_advantage"):
		advantage = true
		target_entity.erase("stunning_strike_advantage")
	if target_entity is Dictionary and target_entity.get("conditions", {}).has("stunned"):
		advantage = true
	if has_condition(target_entity, "reckless_attack"):
		advantage = true
	if (target_entity is Character and target_entity.has_condition("guiding_bolt")) or (target_entity is Dictionary and target_entity.get("conditions", {}).has("guiding_bolt")):
		advantage = true
		consume_guiding_bolt_advantage(target_entity)
	if is_unconscious(target_entity) or is_paralyzed(target_entity):
		advantage = true
	if target_entity is Dictionary and target_entity.get("conditions", {}).has("prone"):
		if int(weapon_data.get("attack_distance", weapon_data.get("range", 1))) <= 1:
			advantage = true
		else:
			disadvantage = true
	var fog_obscures_attack := has_condition(attacker, "fog_cloud_obscured") or has_condition(target_entity, "fog_cloud_obscured") or has_condition(attacker, "darkness_obscured") or has_condition(target_entity, "darkness_obscured")
	var attack_distance_feet := maxi(0, int(weapon_data.get("attack_distance", weapon_data.get("range", 1))) * 5)
	var invisible_attack_advantage := is_invisible(attacker) and not can_perceive_invisible(target_entity, attack_distance_feet)
	var unseen_target_disadvantage := is_invisible(target_entity) and not can_perceive_invisible(attacker, attack_distance_feet)
	var blur_target_disadvantage := SpellEffects.has_spell(target_entity, "blur") and not can_perceive_blur(attacker, attack_distance_feet)
	var ability: String = weapon_data.get("ability", "STR")
	if ability == "STR" and attacker.has_condition("reckless_attack"):
		advantage = true
	advantage = FighterRules.attack_advantage(attacker, target_entity) or has_condition(target_entity, "restrained") or SpellEffects.has_spell(target_entity, "faerie_fire") or fog_obscures_attack or invisible_attack_advantage or advantage
	if target_entity is Dictionary:
		var target_conditions: Dictionary = target_entity.get("conditions", {})
		for feature in attacker.features:
			for effect in attacker._feature_effects(feature):
				if effect.get("type", "") == "attack_advantage_against_condition" and target_conditions.has(str(effect.get("condition", ""))):
					advantage = true
	if target_entity is Character and target_entity.has_feature("rogue_elusive") and not target_entity.has_condition("incapacitated"):
		# Elusive cancels Advantage sources against the Rogue unless incapacitated.
		advantage = false
	var brutal_effects: Array[String] = []
	# These penalties are applied by make_attack_roll too; eligibility must see
	# them before it commits the one Brutal Strike attack, even for direct callers.
	disadvantage = disadvantage or attacker.has_condition("blinded") or fog_obscures_attack or unseen_target_disadvantage or blur_target_disadvantage or attacker.has_condition("poisoned") or attacker.has_condition("restrained") or attacker.has_condition("vicious_mockery_disadvantage") or (ability == "STR" and attacker.has_condition("ray_of_enfeeblement"))
	var requested_brutal: Variant = reaction_decisions.get("barbarian_brutal_strike_effects", [])
	if requested_brutal is Array:
		for effect in requested_brutal:
			if effect is String:
				brutal_effects.append(effect)
	if not brutal_effects.is_empty() and BarbarianRules.commit_brutal_strike(attacker, weapon_data, disadvantage, brutal_effects):
		# Brutal Strike trades every source of Advantage on this roll.
		advantage = false
	else:
		brutal_effects.clear()

	# Resolve the comparison target before any terminal outcome so even natural
	# misses carry the same authoritative activity shape as ordinary attacks.
	var target_ac := 10
	if target_entity is Character:
		target_ac = target_entity.get_ac()
	elif target_entity is Dictionary:
		target_ac = SpellEffects.effective_ac(target_entity, int(target_entity.get("armor_class", 10)) + (2 if has_condition(target_entity, "shield_of_faith") else 0))

	# Roll attack
	var helped_attack := consume_attack_help(target_entity)
	advantage = advantage or helped_attack
	var attack_result := attacker.make_attack_roll(ability, advantage, disadvantage, weapon_data, reaction_decisions)
	SpellEffects.consume_spell(attacker, "invisibility", "attack", {"actor_id": attacker.character_id, "action": "attack"})
	if magic_weapon_bonus > 0:
		attack_result["total"] = int(attack_result.get("total", 0)) + magic_weapon_bonus
		attack_result["activity_modifiers"].append({"label": "Magic Weapon", "value": magic_weapon_bonus})
	apply_blade_ward_attack_penalty(target_entity, attacker, attack_result)
	var stroke_result := RogueRules.apply_stroke_of_luck_to_attack(attacker, attack_result, bool(reaction_decisions.get("stroke_of_luck", false)))
	attack_result = stroke_result.get("result", attack_result)
	var sundering_bonus := BarbarianRules.consume_sundering_bonus(attacker, target_entity) if target_entity is Dictionary else false
	if sundering_bonus:
		attack_result["total"] = int(attack_result.get("total", 0)) + 5
		attack_result["activity_modifiers"].append({"label": "Sundering Blow", "value": 5})
	var irresistible_ability := ClassProgression.epic_boon_ability(attacker, "irresistible_offense")
	var irresistible_damage := int(attacker.ability_scores.get_score(irresistible_ability)) if not irresistible_ability.is_empty() else 0
	var bardic_bonus := 0
	var bardic_message := ""
	var bardic_die := ""
	var bardic_result := BardicInspirationRules.apply_to_attack_result(attacker, attack_result, target_ac, bool(reaction_decisions.get("bardic_inspiration_attack", reaction_decisions.get("bardic_inspiration", false))))
	if bardic_result.get("used", false):
		bardic_bonus = int(bardic_result.get("bonus", 0))
		bardic_die = str(bardic_result.get("die", "1d6"))
		bardic_message = " [color=cyan]%s[/color]" % bardic_result.get("message", "Bardic Inspiration")
	var provisional_hit: bool = bool(attack_result["is_crit"]) or (not bool(attack_result["is_miss"]) and int(attack_result["total"]) >= target_ac)
	if not provisional_hit and attacker.heroic_inspiration and attacker.fighter_training.get("auto_inspiration", false):
		attacker.heroic_inspiration = false
		var reroll := Dice.roll(20)
		attack_result["total"] += reroll - int(attack_result["natural"])
		attack_result["natural"] = reroll
		for i in attack_result["roll_kept"].size():
			attack_result["roll_kept"][i] = false
		attack_result["roll_results"].append(reroll)
		attack_result["roll_kept"].append(true)
		attack_result["is_crit"] = reroll >= attacker.crit_range
		attack_result["is_miss"] = reroll == 1

	var captured := {
		"attacker": attacker, "target": target_entity, "weapon_data": weapon_data,
		"reaction_decisions": reaction_decisions, "additional_damage": additional_damage,
		"original_target_ac": target_ac,
		"crit_range": attacker.crit_range,
		"ability": ability, "attack_result": attack_result, "magic_weapon_bonus": magic_weapon_bonus,
		"stroke_result": stroke_result, "sundering_bonus": sundering_bonus,
		"irresistible_damage": irresistible_damage, "bardic_bonus": bardic_bonus,
		"bardic_message": bardic_message, "bardic_die": bardic_die, "brutal_effects": brutal_effects
	}
	if bool(reaction_decisions.get("allow_weapon_attack_bonus", false)) and attacker is Character and (target_entity is Dictionary or target_entity is Character) and not bool(stroke_result.get("used", false)):
		captured["provisional_hit"] = provisional_hit
		var allow_numeric_bonus := not provisional_hit and int(attack_result.get("natural", 0)) != 1 and not bool(attack_result.get("is_crit", false)) and not bool(attack_result.get("is_miss", false))
		var allow_hit_adjustments := provisional_hit and not bool(attack_result.get("is_crit", false)) and not bool(attack_result.get("is_miss", false))
		var bonus_options := SpellDamageRolls.attack_choice_options(attacker, "weapon_attack", provisional_hit, allow_numeric_bonus, allow_hit_adjustments, attack_result, ability, target_ac)
		if allow_numeric_bonus:
			bonus_options.append_array(PartyInterventionRules.options(attacker, reaction_decisions.get("players", [])))
		if not bonus_options.is_empty():
			var pending := SpellDamageRolls.create_weapon_attack_bonus_request(attacker, target_entity, captured, bonus_options, reaction_decisions)
			if bool(pending.get("success", false)):
				return pending
	return _settle_weapon_attack_context(captured)


static func _settle_weapon_attack_context(context: Dictionary) -> Dictionary:
	var attacker: Character = context["attacker"]
	var target_entity = context["target"]
	var weapon_data: Dictionary = context["weapon_data"]
	var reaction_decisions: Dictionary = context["reaction_decisions"]
	var additional_damage: Dictionary = context["additional_damage"]
	var ability: String = str(context["ability"])
	var attack_result: Dictionary = context["attack_result"]
	var original_attack_result: Dictionary = attack_result.duplicate(true)
	var original_target_ac: int = int(context.get("original_target_ac", 0))
	var target_ac: int = int(context["original_target_ac"])
	var magic_weapon_bonus: int = int(context["magic_weapon_bonus"])
	var stroke_result: Dictionary = context["stroke_result"]
	var sundering_bonus: bool = bool(context["sundering_bonus"])
	var irresistible_damage: int = int(context["irresistible_damage"]) if int(attack_result.get("natural",0))==20 else 0
	var bardic_bonus: int = int(context["bardic_bonus"])
	var bardic_message: String = str(context["bardic_message"])
	var bardic_die: String = str(context["bardic_die"])
	var brutal_effects: Array[String] = context["brutal_effects"]
	var selected_bonus: Dictionary = context.get("selected_bonus", {})
	var override_outcome := ""
	if not selected_bonus.is_empty() and str(selected_bonus.get("resolution", "")) == "outcome_override":
		override_outcome = str(selected_bonus.get("outcome", ""))
		attack_result["outcome_override"] = override_outcome
		attack_result["outcome_override_source"] = str(selected_bonus.get("source_instance_id", ""))
		attack_result["outcome_override_domain"] = str(selected_bonus.get("domain", "weapon_attack"))
		attack_result["outcome_override_stage"] = str(selected_bonus.get("stage", "provisional_outcome"))
	elif not selected_bonus.is_empty() and str(selected_bonus.get("resolution", "")) not in ["attack_total_adjustment", "defending_ac_adjustment", "test_reroll"]:
		var bonus_amount := int(selected_bonus.get("bonus_amount", selected_bonus.get("amount", 0)))
		attack_result["total"] = int(attack_result.get("total", 0)) + bonus_amount
		if str(selected_bonus.get("bonus_kind", "numeric")) == "die":
			var bonus_roll: Dictionary = selected_bonus.get("bonus_roll", {})
			var bonus_terms: Array = attack_result.get("bonus_dice_terms", [])
			bonus_terms.append({
				"count": 1, "sides": int(selected_bonus.get("die_size", 0)),
				"results": bonus_roll.get("rolls", []).duplicate(true),
				"kept": bonus_roll.get("kept", []).duplicate(true),
				"label": str(selected_bonus.get("label", "Attack Bonus")),
				"subtotal": bonus_amount,
			})
			attack_result["bonus_dice_terms"] = bonus_terms
			attack_result["post_roll_bonus_die"] = bonus_roll.duplicate(true)
			attack_result["post_roll_bonus_source"] = str(selected_bonus.get("source_instance_id", ""))
		else:
			var attack_modifiers: Array = attack_result.get("activity_modifiers", [])
			attack_modifiers.append({"label": str(selected_bonus.get("label", "Weapon Attack Bonus")), "value": bonus_amount})
			attack_result["activity_modifiers"] = attack_modifiers
	var is_crit := bool(attack_result["is_crit"])
	if selected_bonus.get("post_roll_reroll", {}) is Dictionary and not selected_bonus.get("post_roll_reroll", {}).is_empty():
		attack_result["post_roll_reroll"] = selected_bonus["post_roll_reroll"].duplicate(true)
	# Native reactions and Peerless Aim see the actual roll outcome. Apply the
	# selected override afterward so its synthetic miss cannot spend a native use.
	var is_hit: bool = is_crit or (not attack_result["is_miss"] and attack_result["total"] >= target_ac)
	if is_hit and (is_unconscious(target_entity) or is_paralyzed(target_entity)) and int(weapon_data.get("attack_distance", weapon_data.get("range", 1))) <= 1:
		is_crit = true
		attack_result["is_crit"] = true
	var reaction_msg := ""
	if stroke_result.get("used", false):
		reaction_msg = "[color=gold]Stroke of Luck turns the failed attack roll into a 20.[/color] "

	# Check reaction Shield spell for Player Character target
	if is_hit and not is_crit and target_entity is Character:
		var shield_payment := SpellPermissionRules.spend_reaction(target_entity, "shield", reaction_decisions) if target_entity.reaction_available and _reaction_accepted("shield", reaction_decisions) else {}
		if not shield_payment.is_empty():
			target_entity.add_condition("shield", 1)
			target_ac = target_entity.get_ac()
			is_hit = attack_result["total"] >= target_ac
			reaction_msg = "[color=cyan]%s casts Shield as a reaction! AC increases to %d.[/color]\n" % [target_entity.character_name, target_ac]
			var shield_ward: Array = shield_payment.get("ward_events", [])
			for ward_ev in shield_ward:
				if not str(ward_ev.get("message", "")).is_empty():
					reaction_msg += "%s\n" % str(ward_ev["message"])

	var before_peerless := is_hit
	is_hit = FighterRules.peerless_aim(attacker, is_hit)
	if is_hit and not before_peerless:
		reaction_msg += "Peerless Aim turns the miss into a hit. "
	if override_outcome in ["hit", "miss"]:
		is_hit = override_outcome == "hit"
		if not is_hit:
			is_crit = false
			attack_result["is_crit"] = false
		elif (is_unconscious(target_entity) or is_paralyzed(target_entity)) and int(weapon_data.get("attack_distance", weapon_data.get("range", 1))) <= 1:
			is_crit = true
			attack_result["is_crit"] = true
	var adjustment_operation := str(selected_bonus.get("resolution", ""))
	if adjustment_operation in ["attack_total_adjustment", "defending_ac_adjustment"]:
		var adjusted := SpellDamageRolls.apply_attack_result_adjustment(attack_result, target_ac, selected_bonus)
		attack_result = adjusted.get("attack_result", attack_result)
		target_ac = int(adjusted.get("target_ac", target_ac))
		is_hit = is_crit or (not bool(attack_result.get("is_miss", false)) and int(attack_result.get("total", 0)) >= target_ac)
	var token_replaced := bool(attack_result.get("roll_token_replaced", false))
	var adjustment_cost_paid := false
	var selected_payment_receipt: Dictionary = {}
	if not selected_bonus.is_empty() and str(selected_bonus.get("resolution", "")) != "test_reroll":
		var policy := "pay_on_choice" if override_outcome in ["hit", "miss"] else str(selected_bonus.get("payment_policy", "pay_on_choice"))
		var payment_selection := selected_bonus.duplicate(true)
		payment_selection["payment_policy"] = policy
		var payment_reservation := SpellDamageRolls.begin_selected_payment(attacker, payment_selection)
		if not bool(payment_reservation.get("success", false)):
			return {"hit": false, "attack_roll": int(attack_result.get("total", 0)) - int(selected_bonus.get("bonus_amount", selected_bonus.get("amount", 0))), "target_ac": target_ac, "refused": true, "message": str(payment_reservation.get("message", "Selected attack bonus source could not reserve its payment."))}
		var payment := SpellDamageRolls.finish_selected_payment(attacker, payment_selection, is_hit, str(payment_reservation.get("reservation_id", "")))
		if not bool(payment.get("success", false)):
			return {"hit": false, "attack_roll": int(attack_result.get("total", 0)) - int(selected_bonus.get("bonus_amount", selected_bonus.get("amount", 0))), "target_ac": target_ac, "refused": true, "message": str(payment.get("message", "Selected attack bonus source could not pay."))}
		selected_payment_receipt = payment
		adjustment_cost_paid = str(payment.get("state", "")) == "committed"
	if not is_hit:
		var miss := {
			"hit": false,
			"attack_roll": attack_result["total"],
			"target_ac": target_ac,
			"roll_token_replaced": token_replaced,
			"activity_roll": _attack_activity_roll(attack_result, target_ac, false),
			"activity_damage": {},
			"can_divine_smite": false,
			"divine_smite_eligible": false,
			"message": reaction_msg + "Miss! Attack roll %d vs AC %d" % [attack_result["total"], target_ac]
		}
		if token_replaced:
			miss["roll_token_id"] = str(attack_result.get("roll_token_id", ""))
			miss["roll_token_value"] = int(attack_result.get("roll_token_value", 0))
		if not selected_bonus.is_empty():
			miss["selected_payment"] = selected_payment_receipt.duplicate(true)
			if adjustment_operation in ["attack_total_adjustment", "defending_ac_adjustment"]:
				var adjustment_receipt := SpellDamageRolls.attack_adjustment_receipt(selected_bonus, original_attack_result, original_target_ac, attack_result, target_ac, false, false, adjustment_cost_paid, {"domain": "weapon_attack", "ability": ability, "weapon": weapon_data})
				miss["attack_adjustment_receipt"] = adjustment_receipt
				miss["original_attack_result"] = original_attack_result.duplicate(true)
				miss["original_target_ac"] = original_target_ac
				miss["activity_roll"]["attack_adjustment_receipt"] = adjustment_receipt.duplicate(true)
			elif override_outcome in ["hit", "miss"]:
				miss["attack_outcome_override"] = override_outcome
				miss["attack_outcome_override_source"] = str(selected_bonus.get("source_instance_id", ""))
				miss["attack_outcome_override_feature_id"] = str(selected_bonus.get("feature_id", ""))
				miss["attack_outcome_override_pool_definition_id"] = str(selected_bonus.get("pool_definition_id", ""))
				miss["attack_outcome_override_owner_id"] = attacker.character_id
				miss["attack_outcome_override_domain"] = str(selected_bonus.get("domain", "weapon_attack"))
				miss["attack_outcome_override_stage"] = str(selected_bonus.get("stage", "provisional_outcome"))
				miss["attack_outcome_override_cost_paid"] = true
				miss["activity_roll"]["outcome_override"] = {
					"outcome": override_outcome,
					"source_instance_id": str(selected_bonus.get("source_instance_id", "")),
					"feature_id": str(selected_bonus.get("feature_id", "")),
					"pool_definition_id": str(selected_bonus.get("pool_definition_id", "")),
					"owner_id": attacker.character_id,
					"domain": str(selected_bonus.get("domain", "weapon_attack")),
					"stage": str(selected_bonus.get("stage", "provisional_outcome")),
					"cost_paid": true,
				}
			else:
				if str(selected_bonus.get("resolution", "")) == "test_reroll":
					miss["post_roll_reroll"] = selected_bonus.get("post_roll_reroll", {}).duplicate(true)
				else:
					miss["post_roll_bonus"] = int(selected_bonus.get("bonus_amount", selected_bonus.get("amount", 0)))
					miss["post_roll_bonus_source"] = str(selected_bonus.get("source_instance_id", ""))
					if selected_bonus.get("bonus_roll", {}) is Dictionary:
						miss["post_roll_bonus_die"] = selected_bonus.get("bonus_roll", {}).duplicate(true)
		FighterRules.apply_mastery(attacker, target_entity, weapon_data, miss)
		if sundering_bonus:
			miss["sundering_bonus"] = 5
		_record_attack_history(reaction_decisions, attacker, target_entity)
		return miss

	# Capture and consume a matching source-owned grant after the final hit/miss
	# outcome, but before base damage can down the target. The snapshot travels
	# with this synchronous resolution, so a later activation cannot be consumed
	# by an older hit completion.
	var next_hit_grant: Dictionary = attacker.take_oldest_next_melee_hit_grant(int(GameManager.campaign_elapsed_seconds)) if _is_melee_weapon_attack(weapon_data) else {}

	# Roll damage
	var damage_str: String = weapon_data.get("damage", "1d4")
	var damage_type: String = weapon_data.get("damage_type", "bludgeoning")
	if attacker is Character and attacker.class_id == "warlock" and WarlockRules.has_invocation(attacker, "pact_of_the_blade") and not attacker.pact_weapon_damage_type.is_empty() and not bool(weapon_data.get("_true_strike", false)):
		damage_type = attacker.pact_weapon_damage_type
	
	var mod := attacker.ability_scores.get_ability_modifier(ability)
	if bool(weapon_data.get("fixed_damage", false)):
		mod = 0
	if weapon_data.get("light_extra", false) and not FighterRules.has_style(attacker, "two_weapon_fighting"):
		mod = mini(0, mod)
	if weapon_data.get("cleave_extra", false):
		mod = mini(0, mod)
	var modifiers := {"STR": mod, "DEX": mod, "CON": mod, "INT": mod, "WIS": mod, "CHA": mod}
	
	var damage_detail: Dictionary = Dice.parse_dice_details(damage_str, modifiers, attacker)
	var damage_roll := int(damage_detail.get("final_total", 0)) + FighterRules.weapon_damage(attacker, weapon_data, damage_detail)
	var additional_damage_packets: Array[Dictionary] = []
	var packet_inputs: Array = []
	if not str(additional_damage.get("formula", "")).is_empty():
		packet_inputs.append(additional_damage)
	for packet in additional_damage.get("packets", []):
		if packet is Dictionary and not str(packet.get("formula", "")).is_empty():
			packet_inputs.append(packet)
	if not next_hit_grant.is_empty():
		packet_inputs.append({"fixed_amount": int(next_hit_grant.get("amount", 2)), "type": str(next_hit_grant.get("damage_type", "fire")), "label": "Next melee hit"})
	if str(weapon_data.get("type", "")) == "weapon" and SpellEffects.has_spell(attacker, "divine_favor"):
		packet_inputs.append({"formula": "1d4", "type": "radiant", "label": "Divine Favor"})
	var additional_damage_roll := 0
	for packet_value in packet_inputs:
		var packet: Dictionary = packet_value
		var formula := str(packet.get("formula", ""))
		var detail: Dictionary = {}
		var packet_roll := int(packet.get("fixed_amount", 0))
		if not formula.is_empty():
			detail = Dice.parse_dice_details(formula, {}, attacker)
			packet_roll = int(detail.get("final_total", 0))
		if attack_result["is_crit"] and not formula.is_empty():
			var critical_detail: Dictionary = Dice.parse_dice_details(formula, {}, attacker)
			packet_roll += int(critical_detail.get("final_total", 0))
			for critical_term in critical_detail.get("dice_terms", []):
				var labeled_critical_term: Dictionary = critical_term.duplicate(true)
				labeled_critical_term["label"] = "Critical %s" % str(labeled_critical_term.get("label", "damage die"))
				detail["dice_terms"].append(labeled_critical_term)
		additional_damage_roll += packet_roll
		additional_damage_packets.append({"packet": packet, "detail": detail, "roll": packet_roll})
	damage_roll += additional_damage_roll
	if irresistible_damage > 0:
		damage_roll += irresistible_damage
		damage_detail["modifiers"].append({"label": "Boon of Irresistible Offense", "value": irresistible_damage})
	if damage_type in ["bludgeoning", "piercing", "slashing"] and attacker is Character:
		var physical_modifier := attacker.get_modifier("stat", "damage:physical")
		damage_roll += physical_modifier
		if physical_modifier != 0:
			damage_detail["modifiers"].append({"label": "Physical damage", "value": physical_modifier})
	if attacker is Character and ability == "STR" and attacker.has_condition("raging"):
		var rage_bonus := attacker.get_modifier("stat", "damage:rage")
		damage_roll += rage_bonus
		if rage_bonus != 0:
			damage_detail["modifiers"].append({"label": "Rage damage", "value": rage_bonus})
	
	# Crits double damage dice
	if attack_result["is_crit"]:
		# Roll damage dice a second time
		var critical_detail: Dictionary = Dice.parse_dice_details(_critical_dice_formula(damage_str), {}, attacker)
		damage_roll += int(critical_detail.get("final_total", 0)) + FighterRules.weapon_damage(attacker, weapon_data, critical_detail)
		for critical_term in critical_detail.get("dice_terms", []):
			var labeled_term: Dictionary = critical_term.duplicate(true)
			labeled_term["label"] = "Critical %s" % str(labeled_term.get("label", "damage die"))
			damage_detail["dice_terms"].append(labeled_term)
	if magic_weapon_bonus > 0:
		damage_roll += magic_weapon_bonus
		damage_detail["modifiers"].append({"label": "Magic Weapon", "value": magic_weapon_bonus})
	var brutal_damage := 0
	var brutal_dice := ""
	if not brutal_effects.is_empty():
		brutal_dice = BarbarianRules.brutal_strike_dice(attacker)
		var brutal_detail: Dictionary = Dice.parse_dice_details(brutal_dice, {}, attacker)
		brutal_damage = int(brutal_detail.get("final_total", 0))
		if attack_result["is_crit"]:
			var critical_brutal: Dictionary = Dice.parse_dice_details(brutal_dice, {}, attacker)
			brutal_damage += int(critical_brutal.get("final_total", 0))
			for term in critical_brutal.get("dice_terms", []):
				var critical_term: Dictionary = term.duplicate(true)
				critical_term["label"] = "Critical Brutal Strike"
				brutal_detail["dice_terms"].append(critical_term)
		damage_roll += brutal_damage
		for term in brutal_detail.get("dice_terms", []):
			var brutal_term: Dictionary = term.duplicate(true)
			brutal_term["label"] = "Brutal Strike"
			damage_detail["dice_terms"].append(brutal_term)

	var weapon_component_damage := maxi(0, damage_roll - additional_damage_roll)
	var rolled_damage := damage_roll
	var mitigation: Array[Dictionary] = []
	var deflected := false
	var has_physical_additional := additional_damage_packets.any(func(entry: Dictionary) -> bool: return str(entry["packet"].get("type", "")) in ["bludgeoning", "piercing", "slashing"])
	if target_entity is Character and target_entity.is_alive and not target_entity.has_condition("stunned") and not target_entity.has_condition("paralyzed") and target_entity.reaction_available and target_entity.has_feature("monk_deflect_attacks") and (damage_type in ["bludgeoning", "piercing", "slashing"] or has_physical_additional or target_entity.has_feature("monk_deflect_energy")) and bool(reaction_decisions.get("deflect_attacks", false)):
		target_entity.reaction_available = false
		var reduction: int = Dice.roll(10) + target_entity.ability_scores.get_ability_modifier("DEX") + target_entity.level
		damage_roll = maxi(0, damage_roll - reduction)
		deflected = damage_roll == 0
		mitigation.append({"label": "Deflect Attacks", "from": rolled_damage, "to": damage_roll})
		reaction_msg += "%s deflects %d damage. " % [target_entity.character_name, mini(rolled_damage, reduction)]
	# Uncanny Dodge Reaction
	if target_entity is Character and target_entity.reaction_available and (target_entity.has_feature("uncanny_dodge") or target_entity.has_feature("rogue_uncanny_dodge")) and _reaction_accepted("uncanny_dodge", reaction_decisions):
		target_entity.reaction_available = false
		damage_roll = int(floor(float(damage_roll) / 2.0))
		mitigation.append({"label": "Uncanny Dodge", "from": rolled_damage, "to": damage_roll})
		reaction_msg += "[color=cyan]%s uses Uncanny Dodge as a reaction to halve the incoming damage![/color]\n" % target_entity.character_name

	var before_resistance := damage_roll
	# Apply attack-level mitigation before settling each damage type. When a
	# reaction reduces the combined hit, the reduction comes off the weapon
	# component first; any remainder reduces the additional component.
	var weapon_component_after_reactions := mini(weapon_component_damage, damage_roll)
	var remaining_additional_after_reactions := maxi(0, damage_roll - weapon_component_after_reactions)
	var bypass_weapon_resistance := ClassProgression.has_epic_boon(attacker, "irresistible_offense") and damage_type in ["bludgeoning", "piercing", "slashing"]
	var weapon_damage_decisions := reaction_decisions.duplicate()
	weapon_damage_decisions["damage_is_critical"] = bool(attack_result["is_crit"])
	if weapon_data.get("zero_hp_aftermath") is Dictionary:
		weapon_damage_decisions["zero_hp_aftermath"] = weapon_data["zero_hp_aftermath"]
		weapon_damage_decisions["zero_hp_aftermath_carrier"] = AftermathSuccessorRules.carrier_for_weapon(weapon_data)
	var damage_occurrence_id := WardRules.next_damage_occurrence_id()
	weapon_damage_decisions = DamageResponseRules.begin(weapon_damage_decisions, damage_occurrence_id, attacker)
	var weapon_settlement := resolve_damage(target_entity, weapon_component_after_reactions, damage_type, weapon_damage_decisions, bypass_weapon_resistance, false, attacker, damage_occurrence_id)
	var additional_settlements: Array[Dictionary] = []
	var additional_actual_dealt := 0
	var additional_resolved := 0
	var total_ward_absorbed := int(weapon_settlement.get("ward_absorbed", 0))
	if not str(weapon_settlement.get("ward_message", "")).is_empty():
		reaction_msg += "[color=cyan]%s[/color] " % str(weapon_settlement["ward_message"])
	for entry in additional_damage_packets:
		var packet: Dictionary = entry["packet"]
		var component := mini(int(entry["roll"]), remaining_additional_after_reactions)
		remaining_additional_after_reactions -= component
		var settlement: Dictionary = {"resolved": 0, "damage": 0}
		if component > 0 and not str(packet.get("type", "")).is_empty():
			settlement = resolve_damage(target_entity, component, str(packet["type"]), weapon_damage_decisions, false, false, attacker, damage_occurrence_id)
		additional_settlements.append(settlement)
		additional_actual_dealt += int(settlement.get("damage", 0))
		additional_resolved += int(settlement.get("resolved", 0))
		total_ward_absorbed += int(settlement.get("ward_absorbed", 0))
		if not str(settlement.get("ward_message", "")).is_empty():
			reaction_msg += "[color=cyan]%s[/color] " % str(settlement["ward_message"])
	damage_roll = int(weapon_settlement["resolved"]) + additional_resolved
	var actual_dealt := int(weapon_settlement["damage"]) + additional_actual_dealt
	if damage_roll != before_resistance:
		mitigation.append({"label": "Damage Mitigation", "from": before_resistance, "to": damage_roll})

	var crit_prefix := "CRITICAL HIT! " if attack_result["is_crit"] else ""
	damage_detail["rolled_total"] = rolled_damage
	damage_detail["final_total"] = rolled_damage
	damage_detail["resolved_total"] = damage_roll
	damage_detail["applied"] = actual_dealt
	damage_detail["type"] = damage_type
	damage_detail["mitigation"] = mitigation
	for entry in additional_damage_packets:
		var packet: Dictionary = entry["packet"]
		for term in entry["detail"].get("dice_terms", []):
			var labeled_term: Dictionary = term.duplicate(true)
			labeled_term["label"] = str(packet.get("label", "Additional damage")) + " — " + str(labeled_term.get("label", "damage die"))
			damage_detail["dice_terms"].append(labeled_term)
	if not additional_damage_packets.is_empty():
		damage_detail["rolled_total"] = rolled_damage
		damage_detail["resolved_total"] = damage_roll
		damage_detail["applied"] = actual_dealt
	if not str(additional_damage.get("formula", "")).is_empty():
		damage_detail["additional_damage_formula"] = str(additional_damage.get("formula", ""))
		damage_detail["additional_damage_type"] = str(additional_damage.get("type", ""))
	var damage_components: Array[Dictionary] = [{"label": "%s damage" % damage_type.capitalize(), "value": int(weapon_settlement["damage"]), "type": damage_type, "receipt": weapon_settlement.duplicate(true)}]
	for index in additional_settlements.size():
		var settlement: Dictionary = additional_settlements[index]
		var packet: Dictionary = additional_damage_packets[index]["packet"]
		if settlement.has("raw"):
			damage_components.append({"label": str(packet.get("label", "%s damage" % str(packet.get("type", "")).capitalize())), "value": int(settlement["damage"]), "type": str(packet.get("type", "")), "formula": str(packet.get("formula", "")), "receipt": settlement.duplicate(true)})
	var damage_message := "Dealing %d %s damage." % [actual_dealt, damage_type] if additional_damage_packets.is_empty() else "Dealing %d damage." % actual_dealt
	var result := {
		"hit": true,
		"crit": attack_result["is_crit"],
		"stroke_of_luck_used": bool(stroke_result.get("used", false)),
		"roll_token_replaced": token_replaced,
		"damage": actual_dealt,
		"resolved": damage_roll,
		"ward_absorbed": total_ward_absorbed,
		"ward_remaining_hp": int(weapon_settlement.get("ward_remaining_hp", 0)),
		"ward_projected": bool(weapon_settlement.get("ward_projected", false)),
		"damage_type": damage_type,
		"deflected": deflected,
		"attack_roll": attack_result["total"],
		"target_ac": target_ac,
		"bardic_bonus": bardic_bonus,
		"bardic_die": bardic_die,
		"activity_roll": _attack_activity_roll(attack_result, target_ac, true),
		"activity_damage": damage_detail,
		"damage_components": damage_components,
		"consumed_next_hit_grant": next_hit_grant.duplicate(true),
		"message": reaction_msg + bardic_message + "%sHit! (%d vs AC %d) %s" % [crit_prefix, attack_result["total"], target_ac, damage_message]
	}
	if not selected_payment_receipt.is_empty(): result["selected_payment"] = selected_payment_receipt.duplicate(true)
	if adjustment_operation in ["attack_total_adjustment", "defending_ac_adjustment"]:
		var adjustment_receipt := SpellDamageRolls.attack_adjustment_receipt(selected_bonus, original_attack_result, original_target_ac, attack_result, target_ac, true, is_crit, adjustment_cost_paid, {"domain": "weapon_attack", "ability": ability, "weapon": weapon_data})
		result["attack_adjustment_receipt"] = adjustment_receipt
		result["original_attack_result"] = original_attack_result.duplicate(true)
		result["original_target_ac"] = original_target_ac
		result["activity_roll"]["attack_adjustment_receipt"] = adjustment_receipt.duplicate(true)
	if token_replaced:
		result["roll_token_id"] = str(attack_result.get("roll_token_id", ""))
		result["roll_token_value"] = int(attack_result.get("roll_token_value", 0))
	if not selected_bonus.is_empty():
		if adjustment_operation in ["attack_total_adjustment", "defending_ac_adjustment"]:
			pass
		elif override_outcome in ["hit", "miss"]:
			result["attack_outcome_override"] = override_outcome
			result["attack_outcome_override_source"] = str(selected_bonus.get("source_instance_id", ""))
			result["attack_outcome_override_feature_id"] = str(selected_bonus.get("feature_id", ""))
			result["attack_outcome_override_pool_definition_id"] = str(selected_bonus.get("pool_definition_id", ""))
			result["attack_outcome_override_owner_id"] = attacker.character_id
			result["attack_outcome_override_domain"] = str(selected_bonus.get("domain", "weapon_attack"))
			result["attack_outcome_override_stage"] = str(selected_bonus.get("stage", "provisional_outcome"))
			result["attack_outcome_override_cost_paid"] = true
			result["activity_roll"]["outcome_override"] = {
				"outcome": override_outcome,
				"source_instance_id": str(selected_bonus.get("source_instance_id", "")),
				"feature_id": str(selected_bonus.get("feature_id", "")),
				"pool_definition_id": str(selected_bonus.get("pool_definition_id", "")),
				"owner_id": attacker.character_id,
				"domain": str(selected_bonus.get("domain", "weapon_attack")),
				"stage": str(selected_bonus.get("stage", "provisional_outcome")),
				"cost_paid": true,
			}
		else:
			if str(selected_bonus.get("resolution", "")) == "test_reroll":
				result["post_roll_reroll"] = selected_bonus.get("post_roll_reroll", {}).duplicate(true)
			else:
				result["post_roll_bonus"] = int(selected_bonus.get("bonus_amount", selected_bonus.get("amount", 0)))
				result["post_roll_bonus_source"] = str(selected_bonus.get("source_instance_id", ""))
				if selected_bonus.get("bonus_roll", {}) is Dictionary:
					result["post_roll_bonus_die"] = selected_bonus.get("bonus_roll", {}).duplicate(true)
	if not additional_damage_packets.is_empty():
		result["message"] += " Includes %s." % ", ".join(additional_damage_packets.map(func(entry: Dictionary) -> String: return "%d %s" % [int(additional_settlements[additional_damage_packets.find(entry)].get("damage", 0)), str(entry["packet"].get("type", "damage"))]))
	if target_entity is Dictionary and str(weapon_data.get("type", "")) == "weapon":
		weapon_rider_roll_serial += 1
		result["weapon_rider_roll_id"] = weapon_rider_roll_serial
		weapon_rider_rolls[weapon_rider_roll_serial] = {"actor": attacker, "target": target_entity, "result": result, "weapon_id": str(weapon_data.get("id", "")), "weapon": weapon_data.duplicate(true), "critical": is_crit, "parent": str(reaction_decisions.get("parent_action", {}).get("action_id", "opportunity_attack" if bool(weapon_data.get("opportunity_attack", false)) else "weapon_attack")), "causal_parent":reaction_decisions.get("parent_action", {}).duplicate(true), "used": {}}
	FighterRules.apply_mastery(attacker, target_entity, weapon_data, result)
	if not brutal_effects.is_empty() and target_entity is Dictionary:
		var brutal_result := BarbarianRules.apply_brutal_strike_effects(attacker, target_entity, brutal_effects)
		result["barbarian_brutal_strike"] = brutal_result
		result["damage"] = actual_dealt
		result["damage_components"].append({"label": "Brutal Strike", "value": brutal_damage, "type": damage_type, "formula": BarbarianRules.brutal_strike_dice(attacker)})
		result["message"] += " %s adds %s." % [str(brutal_result.get("message", "Brutal Strike")), brutal_dice]
	if sundering_bonus:
		result["sundering_bonus"] = 5

	# Divine Smite trigger wiring
	var is_melee_hit: bool = _is_melee_weapon_attack(weapon_data)
	var target_alive: bool = (target_entity is Character and target_entity.is_alive) or (target_entity is Dictionary and int(target_entity.get("current_hp", 0)) > 0)
	var smite_spell: Dictionary = DataLoader.get_spell("divine_smite")
	var can_smite: bool = is_melee_hit and target_alive and attacker is Character and attacker.has_feature("paladin_paladins_smite") and not is_incapacitated(attacker) and not attacker.has_condition("raging") and DruidRules.can_cast_spell(attacker, smite_spell) and (attacker.has_free_spell_cast("divine_smite") or get_spell_slot_level(attacker, smite_spell) > 0)
	result["can_divine_smite"] = can_smite
	result["divine_smite_eligible"] = can_smite
	if can_smite and reaction_decisions.has("divine_smite") and reaction_decisions["divine_smite"] != null:
		var smite_decision = reaction_decisions["divine_smite"]
		if smite_decision is Callable:
			smite_decision = smite_decision.call(attacker, target_entity, result)
		if smite_decision is bool and smite_decision:
			var free_cast: bool = attacker.has_free_spell_cast("divine_smite")
			var slot_level: int = 1 if free_cast else get_spell_slot_level(attacker, smite_spell)
			smite_decision = {"free_cast": free_cast, "slot_level": slot_level}
		if smite_decision is Dictionary and not smite_decision.is_empty():
			var slot_lvl: int = int(smite_decision.get("slot_level", 1))
			var is_free: bool = bool(smite_decision.get("free_cast", false))
			var smite_reactions: Dictionary = smite_decision.get("reactions", {}) if smite_decision.has("reactions") else reaction_decisions
			var smite_res := resolve_divine_smite(attacker, target_entity, slot_lvl, is_free, bool(attack_result["is_crit"]), smite_reactions)
			result["divine_smite"] = smite_res
			if smite_res.get("success", false):
				var added_dmg: int = int(smite_res.get("damage", 0))
				result["damage"] = int(result.get("damage", 0)) + added_dmg
				var detail: Dictionary = result.get("activity_damage", {})
				for term in smite_res.get("activity_damage", {}).get("dice_terms", []):
					var labeled: Dictionary = term.duplicate(true)
					labeled["label"] = "Divine Smite — " + str(labeled.get("label", "d8"))
					detail.get_or_add("dice_terms", []).append(labeled)
				for field in ["rolled_total", "resolved_total", "applied"]:
					detail[field] = int(detail.get(field, 0)) + int(smite_res.get("activity_damage", {}).get(field, added_dmg))
				detail["final_total"] = detail["rolled_total"]
				detail.get_or_add("mitigation", []).append_array(smite_res.get("activity_damage", {}).get("mitigation", []))
				result.get_or_add("damage_components", []).append({"label": "Divine Smite", "value": added_dmg, "type": "radiant", "formula": smite_res.get("damage_formula", "")})
				if added_dmg > 0:
					ClericRules.clear_turning_after_damage(target_entity)
				result["message"] = str(result.get("message", "")) + " " + str(smite_res.get("message", ""))
	_record_attack_history(reaction_decisions, attacker, target_entity)
	var attack_event := {"type": "attack", "actor_id": SpellEffects.caster_id(attacker), "recipient_id": SpellEffects.caster_id(target_entity) if target_entity is Character else str(target_entity.get("id", "")) if target_entity is Dictionary else "", "action": "attack", "weapon_id": str(weapon_data.get("id", "")), "hit": bool(result.get("hit", false))}
	SpellEffects.publish_event(attacker, attack_event)
	SpellEffects.publish_event(target_entity, attack_event)
	# S-104: a settled hit may open its owner's declared mode-switch window.
	result["mode_switch_windows"] = FeatureModeRules.on_event(attacker, "hit")
	return result


static func _record_attack_history(decisions: Dictionary, attacker, target) -> void:
	var history: Variant = decisions.get("combat_history", null)
	if history is CombatActionHistory:
		history.record_attack(attacker, target)


static func resume_weapon_attack_bonus(record: Dictionary, selected: Dictionary, stroke: Dictionary = {}) -> Dictionary:
	var context: Dictionary = record.get("context", {}).duplicate(true)
	if context.is_empty():
		return {"hit": false, "refused": true, "message": "The captured weapon attack is no longer available."}
	context["attacker"] = record.get("caster")
	context["target"] = record.get("target")
	context["reaction_decisions"] = record.get("context", {}).get("reaction_decisions", {}).duplicate(false)
	context["selected_bonus"] = selected.duplicate(true)
	if not stroke.is_empty():
		context["attack_result"] = stroke.get("result", context.get("attack_result", {})).duplicate(true)
		context["stroke_result"] = stroke.duplicate(true)
	var settled := _settle_weapon_attack_context(context)
	settled["weapon_attack_bonus_settled"] = true
	return settled


## Convert the final attack comparison into the immutable roll payload contract.
static func _attack_activity_roll(attack_result: Dictionary, target_ac: int, is_hit: bool) -> Dictionary:
	var results: Array = attack_result.get("roll_results", [attack_result.get("natural", 0)]).duplicate()
	var kept: Array = attack_result.get("roll_kept", [true]).duplicate()
	var dice_terms: Array = [{
		"count": results.size(),
		"sides": 20,
		"results": results,
		"kept": kept,
		"label": "d20",
		"subtotal": int(attack_result.get("natural", 0)),
	}]
	for bonus_term in attack_result.get("bonus_dice_terms", []):
		dice_terms.append(bonus_term.duplicate(true))
	var formula_parts: Array[String] = ["2d20kh1" if bool(attack_result.get("advantage", false)) else ("2d20kl1" if bool(attack_result.get("disadvantage", false)) else "1d20")]
	for modifier in attack_result.get("activity_modifiers", []):
		formula_parts.append("%+d" % int(modifier.get("value", 0)))
	for bonus_term in attack_result.get("bonus_dice_terms", []):
		formula_parts.append("+ %dd%d" % [int(bonus_term.get("count", 1)), int(bonus_term.get("sides", 0))])
	var final_total := int(attack_result.get("total", 0))
	var roll_receipt := {
		"formula": " ".join(formula_parts),
		"dice_terms": dice_terms,
		"modifiers": attack_result.get("activity_modifiers", []).duplicate(true),
		"natural_total": int(attack_result.get("natural", 0)),
		"advantage": bool(attack_result.get("advantage", false)),
		"disadvantage": bool(attack_result.get("disadvantage", false)),
		"final_total": final_total,
		"comparison": {
			"kind": "armor_class",
			"target": target_ac,
			"margin": final_total - target_ac,
			"result": "hit" if is_hit else "miss",
		},
	}
	if attack_result.get("post_roll_reroll", {}) is Dictionary and not attack_result.get("post_roll_reroll", {}).is_empty():
		roll_receipt["post_roll_reroll"] = attack_result["post_roll_reroll"].duplicate(true)
	return roll_receipt


## Resolve production monster attack riders after the base attack hits.
## Monster data stays declarative; this boundary owns saves, conditions, and
## persistent target damage so AI and player-triggered fixtures share behavior.
static func resolve_monster_attack_effects(monster: Dictionary, target: Character, attack_data: Dictionary, attack_result: Dictionary, reaction_decisions: Dictionary = {}, source_character: Character = null) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if monster.is_empty() or target == null or not attack_result.get("hit", false):
		return results
	for effect in attack_data.get("extra_effects", []):
		var effect_type := str(effect.get("type", ""))
		match effect_type:
			"poison_save", "restrain", "paralyze_save":
				var save_ability := str(effect.get("save", "CON"))
				var dc := int(effect.get("dc", 10))
				var save_total := target.saving_throw_to_dc(save_ability, dc, false, false, reaction_decisions)
				if save_total >= dc:
					results.append({"type": effect_type, "success": true, "message": "%s resists %s (%d vs DC %d)." % [target.character_name, effect_type.replace("_", " "), save_total, dc]})
					continue
				var duration := maxi(1, int(effect.get("duration", 1)))
				if effect_type == "poison_save":
					target.add_condition("poisoned", duration)
					var poison_damage := Dice.parse_dice_string(str(effect.get("damage", "1d6")))
					var poison_receipt := resolve_damage(target, poison_damage, "poison", reaction_decisions, false, false, source_character, WardRules.next_damage_occurrence_id())
					var actual_poison := int(poison_receipt["damage"])
					results.append({"type": effect_type, "success": false, "damage": actual_poison, "resolved": int(poison_receipt.get("resolved", 0)), "damage_components": [{"type": "poison", "value": actual_poison, "receipt": poison_receipt}], "message": "%s is poisoned and takes %d poison damage." % [target.character_name, actual_poison]})
				elif effect_type == "restrain":
					target.add_condition("restrained", duration)
					results.append({"type": effect_type, "success": false, "message": "%s is restrained for %d turn(s)." % [target.character_name, duration]})
				else:
					target.add_condition("paralyzed", duration)
					results.append({"type": effect_type, "success": false, "message": "%s is paralyzed for %d turn(s)." % [target.character_name, duration]})
			"corrode_armor":
				target.add_modifier("stat", "AC", -1, int(effect.get("duration", 10)))
				results.append({"type": effect_type, "success": true, "message": "%s's armor corrodes (-1 AC)." % target.character_name})
			"max_hp_source":
				var source_rule: Dictionary = effect.get("rule", {})
				var amount := int(attack_result.get("damage", 0)) if str(source_rule.get("amount", "")) == "damage_dealt" else -1
				var source_id := "%s:%s" % [str(monster.get("id", monster.get("name", "monster"))), str(source_rule.get("id", ""))]
				var change := MaxHpSourceRules.apply(target, source_rule, source_id, amount)
				results.append({"type": effect_type, "success": true, "receipt": change, "message": "%s's Hit Point maximum is now %d." % [target.character_name, target.max_hp]})
			"reduce_max_hp":
				var reduction := int(attack_result.get("damage", 0))
				if str(effect.get("value", "")) != "damage_dealt":
					reduction = int(effect.get("value", reduction))
				if not target.aura_of_life_sources.is_empty():
					results.append({"type": effect_type, "success": true, "value": 0, "message": "%s's Aura of Life prevents its Hit Point maximum from being reduced." % target.character_name})
				else:
					target.max_hp = maxi(1, target.max_hp - maxi(0, reduction))
					target.current_hp = mini(target.current_hp, target.max_hp)
					results.append({"type": effect_type, "success": true, "value": reduction, "message": "%s loses %d maximum hit point(s)." % [target.character_name, reduction]})
	if not target.last_save_note.is_empty():
		for result in results:
			result["message"] += " " + target.last_save_note
	return results


## Extract dice only: critical hits never repeat ability or flat modifiers.
static func _critical_dice_formula(formula: String) -> String:
	var pattern := RegEx.new()
	pattern.compile("[+-]?\\s*[0-9]*[dD][0-9]+")
	var terms: Array[String] = []
	for match_result in pattern.search_all(formula):
		terms.append(match_result.get_string().strip_edges())
	return "+".join(terms) if not terms.is_empty() else "0"


## Apply Divine Smite after a confirmed melee hit; the caller owns its prompt.
static func resolve_divine_smite(caster: Character, target_entity, slot_level: int = 0, free_cast: bool = false, critical: bool = false, reaction_decisions: Dictionary = {}, reaction_observers: Array = []) -> Dictionary:
	if caster == null or not caster.has_feature("paladin_paladins_smite") or target_entity == null:
		return {"success": false, "damage": 0, "message": "Divine Smite is unavailable."}
	var spell_data := DataLoader.get_spell("divine_smite")
	if spell_data.is_empty():
		return {"success": false, "damage": 0, "message": "Divine Smite has no spell record."}
	if is_incapacitated(caster) or caster.has_condition("raging") or not DruidRules.can_cast_spell(caster, spell_data):
		return {"success": false, "damage": 0, "message": "You cannot cast Divine Smite in this state."}
	if not caster.inventory.has_required_spell_component(spell_data, caster.class_id):
		return {"success": false, "damage": 0, "message": "Divine Smite's components are unavailable."}
	var bounded_level := 1
	var incoming_slot_spent := false
	if free_cast:
		if not caster.spend_free_spell_cast("divine_smite"):
			return {"success": false, "damage": 0, "message": "No free Divine Smite cast remains before a Long Rest."}
	else:
		var slot_result := spend_spell_slot(caster, spell_data, slot_level)
		if not slot_result.get("success", false):
			return {"success": false, "damage": 0, "message": slot_result.get("message", "No spell slots remain for Divine Smite.")}
		bounded_level = int(slot_result.get("slot_level", 1))
		incoming_slot_spent = not bool(slot_result.get("slot_recalled", false))
	var damage_formula := str(spell_data.get("damage", "2d8"))
	var dice_parts := damage_formula.to_lower().split("d", false, 1)
	var dice_count := int(dice_parts[0]) if dice_parts.size() == 2 and dice_parts[0].is_valid_int() else 2
	var upcast_data: Dictionary = spell_data.get("upcast", {})
	dice_count += maxi(0, bounded_level - int(spell_data.get("level", 1))) * int(upcast_data.get("extra_dice_per_level", 1))
	var creature_types: Array = spell_data.get("bonus_damage_creature_types", [])
	var creature_type := str(target_entity.get("creature_type", "")) if target_entity is Dictionary else ""
	if creature_type in creature_types:
		dice_count += int(spell_data.get("bonus_damage_dice", 1))
	var damage_type := str(spell_data.get("damage_type", "radiant"))
	# Use the shared spell interruption boundary; the caller already confirmed a hit.
	var cast := SpellResolutionContext.new()
	cast.caster = caster
	cast.target = target_entity
	cast.spell = spell_data
	cast.slot_level = bounded_level
	cast.decisions = reaction_decisions
	cast.observers = reaction_observers
	cast.incoming_slot_spent = incoming_slot_spent
	cast.incoming_slot_key = str(bounded_level)
	SpellEffects.consume_spell(caster, "sanctuary", "cast", {"actor_id": SpellEffects.caster_id(caster), "spell_id": str(cast.spell.get("id", ""))})
	SpellEffects.consume_spell(caster, "invisibility", "cast", {"actor_id": SpellEffects.caster_id(caster), "spell_id": str(cast.spell.get("id", ""))})
	var interruption := SpellResolver._resolve_counterspell(cast)
	if not interruption.is_empty():
		interruption["cast_committed"] = true
		return interruption
	if critical:
		dice_count *= 2
	var damage_detail := Dice.parse_dice_details("%dd8" % dice_count)
	var rolled_damage := int(damage_detail["final_total"])
	var settlement := resolve_damage(target_entity, rolled_damage, damage_type, {}, false, false, caster)
	var actual := int(settlement["damage"])
	var resolved := int(settlement["resolved"])
	damage_detail["rolled_total"] = rolled_damage
	damage_detail["applied"] = actual
	damage_detail["resolved_total"] = resolved
	damage_detail["type"] = damage_type
	damage_detail["mitigation"] = [{"label": "Divine Smite mitigation", "from": rolled_damage, "to": resolved}] if resolved != rolled_damage else []
	return {
		"success": true,
		"cast_committed": true,
		"activity_damage": damage_detail,
		"damage": actual,
		"damage_type": damage_type,
		"damage_formula": "%dd8" % dice_count,
		"slot_level": bounded_level,
		"message": "Divine Smite deals %d %s damage %s." % [actual, damage_type, "as its free Long Rest cast" if free_cast else "using a level %d spell slot" % bounded_level]
	}


## Eldritch Smite: expend a Pact Magic slot on a pact weapon hit for (1 + slot_level)d8 force damage and knock prone.
static func resolve_eldritch_smite(attacker: Character, target_entity, slot_level: int = -1) -> Dictionary:
	return WarlockRules.resolve_eldritch_smite(attacker, target_entity, slot_level)


## Hurl Through Hell: transport target through the Lower Planes on hit.
static func resolve_hurl_through_hell(attacker: Character, target_entity) -> Dictionary:
	return WarlockRules.resolve_hurl_through_hell(attacker, target_entity)


## Validate the entity selected for a spell before spending a slot or action.
## Self and ally-only spells must not silently resolve against an invalid target.
static func validate_spell_target(caster: Character, target_entity, spell_data: Dictionary, distance_feet: int = -1) -> Dictionary:
	if caster == null or spell_data.is_empty():
		return {"success": false, "message": "Spell needs a valid caster and spell record."}
	if str(spell_data.get("casting_time", "action")) == "reaction":
		return {"success": false, "message": "%s resolves only through its reaction boundary." % spell_data.get("name", "This spell")}
	var recovery_spell_id := str(spell_data.get("id", ""))
	if target_entity is Character and target_entity.is_dead() and recovery_spell_id not in ["revivify", "gentle_repose"]:
		return {"success": false, "message": "A dead party member requires revival magic before ordinary creature spells can affect it."}
	if recovery_spell_id in ["revivify", "gentle_repose"]:
		var recovery_error := CorpseRules.target_error(target_entity if target_entity is Character else null, recovery_spell_id, int(GameManager.campaign_elapsed_seconds))
		if not recovery_error.is_empty(): return {"success": false, "message": recovery_error}
	var target_type := str(spell_data.get("target", "single"))
	var required_creature_types: Array = spell_data.get("target_creature_types", [])
	if not required_creature_types.is_empty():
		var target_creature_type := ""
		if target_entity is Character:
			target_creature_type = target_entity.get_creature_type()
		elif target_entity is Dictionary:
			target_creature_type = str(target_entity.get("creature_type", ""))
		if target_creature_type not in required_creature_types:
			return {"success": false, "message": "%s can only target %s." % [spell_data.get("name", "This spell"), ", ".join(required_creature_types)]}
	var required_sizes: Array = spell_data.get("target_sizes", [])
	if not required_sizes.is_empty():
		var target_size := str(target_entity.get("size", "")).to_lower() if target_entity is Dictionary else str(DataLoader.get_race(target_entity.race_id).get("size", "medium")).to_lower() if target_entity is Character else ""
		var allowed_sizes: Array[String] = []
		for size in required_sizes:
			allowed_sizes.append(str(size).to_lower())
		if target_size not in allowed_sizes:
			return {"success": false, "message": "%s needs a %s target." % [spell_data.get("name", "This spell"), " or ".join(allowed_sizes)]}
	var excluded_creature_types: Array = spell_data.get("target_creature_type_exclusions", [])
	if not excluded_creature_types.is_empty():
		var excluded_target_type := ""
		if target_entity is Character:
			excluded_target_type = target_entity.get_creature_type()
		elif target_entity is Dictionary:
			excluded_target_type = str(target_entity.get("creature_type", ""))
		if excluded_target_type in excluded_creature_types:
			return {"success": false, "message": "%s has no effect on %s." % [spell_data.get("name", "This spell"), excluded_target_type + "s"]}
	if not spell_target_is_visible_to(caster, target_entity, spell_data, distance_feet):
		return {"success": false, "message": "%s requires a target you can see." % spell_data.get("name", "This spell")}
	var spell_id := str(spell_data.get("id", ""))
	var target_is_caster := is_same_character(target_entity, caster)
	var damage_prevention_bypass := SharedSpell.allows_damage_prevention_bypass(spell_data)
	if ((has_condition(target_entity, "resilient_sphere") and not target_is_caster and spell_id != "disintegrate") or (has_condition(caster, "resilient_sphere") and not target_is_caster)) and not damage_prevention_bypass:
		return {"success": false, "message": "Resilient Sphere blocks the spell's effect across its barrier."}
	if str(spell_data.get("id", "")) == "shillelagh" and caster.inventory.get_weapon() not in ["club", "quarterstaff"]:
		return {"success": false, "message": "Shillelagh needs a Club or Quarterstaff equipped in your weapon hand."}
	match target_type:
		"self":
			if not target_entity is Character or target_entity != caster:
				return {"success": false, "message": "%s can only target its caster." % spell_data.get("name", "This spell")}
		"single_ally":
			if not target_entity is Character:
				return {"success": false, "message": "%s needs a living ally target." % spell_data.get("name", "This spell")}
	return {"success": true}


## Resolve casting a spell.
## Supports single-target, healing, and saving-throw based spells.
static func resolve_spell(caster: Character, target_entity, spell_data: Dictionary, deduct_slot: bool = false, reaction_decisions: Dictionary = {}, reaction_observers: Array = [], slot_level_override: int = 0, distance_feet: int = -1, owned_cast_context: SpellCastContext = null) -> Dictionary:
	return SpellResolver.resolve(caster, target_entity, spell_data, deduct_slot, reaction_decisions, reaction_observers, slot_level_override, distance_feet, owned_cast_context)


static func _slot_key_for_spell(caster: Character, spell_level: int, spell_data: Dictionary = {}) -> String:
	var available_keys: Array[int] = []
	var pool_id := str(spell_data.get("_spell_slot_pool_id", SpellSlotRules.default_pool_id(caster)))
	for row in SpellSlotRules.pool_rows(caster):
		if str(row.pool_id) == pool_id and int(row.level) >= spell_level and int(row.remaining) > 0:
			available_keys.append(int(row.level))
	available_keys.sort()
	if not available_keys.is_empty():
		return str(available_keys[0])
	return str(spell_level)


static func _resolve_magic_missile(caster: Character, target_entity, spell_data: Dictionary, reaction_decisions: Dictionary = {}, slot_level: int = 0) -> Dictionary:
	return SpellProjectileResolver._resolve_magic_missile(caster, target_entity, spell_data, reaction_decisions, slot_level)


static func magic_missile_dart_count(spell_data: Dictionary, slot_level: int = 0) -> int:
	return SpellProjectileResolver.magic_missile_dart_count(spell_data, slot_level)


static func _resolve_scorching_ray(caster: Character, target_entity, spell_data: Dictionary, reaction_decisions: Dictionary, slot_level: int = 0, distance_feet: int = -1) -> Dictionary:
	return SpellProjectileResolver._resolve_scorching_ray(caster, target_entity, spell_data, reaction_decisions, slot_level, distance_feet)


static func _roll_attack_damage_packets(caster: Character, choices: Array, critical_hits: Array) -> Array[Dictionary]:
	var packets: Array[Dictionary] = []
	for index in mini(choices.size(), critical_hits.size()):
		var choice: Variant = choices[index]
		if not choice is Dictionary:
			continue
		var formula := str(choice.get("formula", ""))
		if formula.is_empty():
			continue
		packets.append({"details": _roll_spell_damage(caster, formula, 2 if bool(critical_hits[index]) else 1, {}), "type": str(choice.get("type", "acid")), "label": str(choice.get("label", "Additional attack damage")), "formula": formula})
	return packets


static func scorching_ray_count(caster: Character, spell_data: Dictionary, slot_level: int = 0) -> int:
	return SpellProjectileResolver.scorching_ray_count(caster, spell_data, slot_level)


static func spell_damage_bonus(caster: Character, spell_data: Dictionary) -> int:
	if spell_data.has("_spell_damage_bonus_override"):
		return int(spell_data["_spell_damage_bonus_override"])
	if caster == null or bool(spell_data.get("_wish_duplicate", false)) or int(spell_data.get("level", -1)) != 0:
		return 0
	var class_data := DataLoader.get_character_class(caster.class_id)
	if str(spell_data.get("id", "")) not in class_data.get("spell_list_ids", []):
		return 0
	var bonus := 0
	for effect in ClassProgression.selected_feature_effects_of_type(caster, "spell_damage_bonus"):
		if int(effect.get("spell_level", -1)) != 0 or str(effect.get("spell_list", "")) != caster.class_id:
			continue
		if effect.has("spell_ids") and str(spell_data.get("id", "")) not in effect["spell_ids"]:
			continue
		bonus += maxi(0, caster.ability_scores.get_ability_modifier(str(effect.get("ability", "WIS"))))
	return bonus


static func spell_range_bonus_feet(caster: Character, spell_data: Dictionary) -> int:
	if caster == null or int(spell_data.get("level", -1)) != 0:
		return 0
	var class_data := DataLoader.get_character_class(caster.class_id)
	if str(spell_data.get("id", "")) not in class_data.get("spell_list_ids", []):
		return 0
	var bonus := 0
	for effect in ClassProgression.selected_feature_effects_of_type(caster, "spell_range_bonus"):
		if int(effect.get("spell_level", -1)) != 0 or str(effect.get("spell_list", "")) != caster.class_id or (not str(effect.get("requires_feature", "")).is_empty() and not caster.has_feature(str(effect.get("requires_feature", "")))):
			continue
		if effect.has("spell_ids") and str(spell_data.get("id", "")) not in effect["spell_ids"]:
			continue
		if int(spell_data.get("range", 0)) * 5 < int(effect.get("minimum_range_feet", 0)):
			continue
		var range_table: Dictionary = effect.get("bonus_feet_by_level", {})
		for key in range_table:
			if int(key) <= caster.level:
				bonus = maxi(bonus, int(range_table[key]))
		if effect.has("bonus_feet_per_level"):
			bonus = maxi(bonus, int(effect.get("bonus_feet_per_level", 0)) * caster.level)
	return bonus


static func resolve_weapon_damage_riders(attacker: Character, target: Dictionary, damage_type_choices: Dictionary = {}, weapon_data: Dictionary = {}, critical_hit: bool = false, qualifying_hit: bool = true, attack_receipt: Dictionary = {}) -> Array[Dictionary]:
	var applied: Array[Dictionary] = []
	if not qualifying_hit or attacker == null or target.is_empty() or not target.get("is_alive", true):
		return applied
	var roll: Dictionary = weapon_rider_rolls.get(int(attack_receipt.get("weapon_rider_roll_id", 0)), {})
	if not roll.is_empty() and (roll.actor != attacker or not is_same(roll.target, target) or not is_same(roll.result, attack_receipt) or str(roll.weapon_id) != str(weapon_data.get("id", ""))):
		roll = {}
	# A supplied receipt must belong to this actual settled hit in the current turn.
	if not attack_receipt.is_empty() and (roll.is_empty() or not bool(attack_receipt.get("hit", false))):
		return applied
	if not roll.is_empty():
		if bool(roll.get("riders_settled", false)):
			return applied
		# Completion belongs to the hit even if no option currently qualifies.
		# Later activation or replenishment cannot reopen that old hit.
		roll["riders_settled"] = true
		weapon_data = roll.weapon
		critical_hit = bool(roll.critical)
	for effect in ClassProgression.selected_feature_effects_of_type(attacker, "weapon_damage_rider"):
		if str(effect.get("trigger", "")) != "weapon_attack_hit":
			continue
		if bool(effect.get("melee_only", false)) and int(weapon_data.get("range", 1)) > 1:
			continue
		if bool(effect.get("own_turn_only", false)) and active_turn_actor_id != attacker.get_instance_id():
			continue
		if bool(effect.get("first_round_only", false)) and active_combat_round != 1:
			continue
		if bool(effect.get("optional", false)) and not damage_type_choices.has(str(effect.get("id", ""))):
			continue
		var use_limit := str(effect.get("use_limit", ""))
		var lock_key := ""
		var owner_turn_lock := false
		var use_cost := 1
		var grant: Dictionary = {}
		var payment_waived := false
		var replacement_payment_source := ""
		var replacement_payment_quantity := 0
		var replacement_payment_receipt: Dictionary = {}
		if not use_limit.is_empty():
			if str(weapon_data.get("type", "")) != "weapon":
				continue
			var target_id := _weapon_rider_target_id(target)
			var source_id := str(effect.get("source_instance_id", ""))
			var option_id := str(effect.get("id", ""))
			if source_id.is_empty() or option_id.is_empty() or (use_limit == "once_per_target_per_combat_turn" and target_id.is_empty()):
				continue
			var pool_definition_id := str(effect.get("resource_pool_definition_id", ""))
			var pool := ResourcePoolRules.availability(attacker, source_id)
			if pool_definition_id.is_empty() or str(ResourcePoolRules._owned_pool(attacker, source_id).get("definition_id", "")) != pool_definition_id:
				continue
			grant = _weapon_rider_active_grant(attacker, source_id)
			if effect.has("payment_waiver") and not roll.is_empty() and not grant.is_empty() and str(effect.payment_waiver.parent) == str(roll.parent):
				use_cost = 0
				payment_waived = true
			if effect.has("payment_replacement"):
				var replacement: Dictionary = effect.payment_replacement
				replacement_payment_quantity = int(replacement.get("quantity", 0))
				for candidate_source in ResourcePoolRules.source_instance_ids(attacker, str(replacement.get("pool_id", ""))):
					if str(candidate_source) == source_id:
						continue
					var candidate := ResourcePoolRules.availability(attacker, candidate_source)
					var candidate_pool := ResourcePoolRules._owned_pool(attacker, candidate_source)
					if bool(candidate.get("available", false)) and int(candidate.get("current", 0)) >= replacement_payment_quantity and str(candidate_pool.get("definition_id", "")) == str(replacement.get("pool_id", "")):
						replacement_payment_source = candidate_source
						break
				if replacement_payment_source.is_empty():
					continue
				use_cost = 0
			if use_cost > 0 and not pool.get("available", false):
				continue
			if use_limit == "once_per_owner_turn_interval":
				if attacker.character_id.is_empty():
					continue
				owner_turn_lock = true
				lock_key = _bounded_owner_turn_rider_lock_key(source_id, option_id)
				var owner_locks: Dictionary = bounded_owner_turn_rider_locks.get(attacker.character_id, {})
				if owner_locks.has(lock_key):
					continue
			elif use_limit == "once_per_round":
				if active_combat_round < 1:
					continue
				lock_key = JSON.stringify([attacker.get_instance_id(), source_id, option_id, active_combat_round])
				if bounded_round_rider_locks.has(lock_key):
					continue
			elif use_limit == "once_per_roll":
				lock_key = JSON.stringify([source_id, option_id])
				if roll.is_empty() or roll.used.has(lock_key):
					continue
			elif use_limit == "once_per_active_instance":
				if grant.is_empty() or option_id in grant.get("used_rider_options", []) or grant.get("used_rider_options", []).size() >= 100:
					continue
			else:
				lock_key = _bounded_hit_rider_lock_key(attacker.character_id, source_id, option_id, active_turn_serial, target_id if use_limit == "once_per_target_per_combat_turn" else "")
				if bounded_hit_rider_locks.has(lock_key):
					continue
		var marker := "%s_%s_used_this_turn" % [str(effect.get("id", "weapon_damage_rider")), attacker.class_id]
		var once_per_turn: bool = bool(effect.get("once_per_turn", effect.get("uses_per", "") == "turn"))
		if use_limit.is_empty() and once_per_turn and int(attacker.feature_uses.get(marker, 0)) > 0:
			continue
		var dice_table: Dictionary = effect.get("dice_by_level", {})
		var eligible_levels: Array[int] = []
		for level_key in dice_table:
			if int(level_key) <= attacker.level:
				eligible_levels.append(int(level_key))
		eligible_levels.sort()
		if eligible_levels.is_empty():
			continue
		var formula := str(dice_table[str(eligible_levels[-1])])
		if critical_hit and "d" in formula:
			var parts := formula.split("d", false, 1)
			formula = "%dd%s" % [int(parts[0]) * 2, parts[1]]
		var options: Array = effect.get("damage_type_options", [])
		var default_type := str(effect.get("damage_type", "radiant"))
		var damage_type := str(damage_type_choices.get(str(effect.get("id", "")), default_type))
		if not options.is_empty() and damage_type not in options:
			continue
		if not use_limit.is_empty():
			if not replacement_payment_source.is_empty():
				replacement_payment_receipt = ResourcePoolRules.spend(attacker, replacement_payment_source, replacement_payment_quantity)
				if not replacement_payment_receipt.get("success", false):
					continue
			elif use_cost > 0:
				var spend := ResourcePoolRules.spend(attacker, str(effect.get("source_instance_id", "")), use_cost)
				if not spend.get("success", false):
					continue
			if owner_turn_lock:
				var owner_locks: Dictionary = bounded_owner_turn_rider_locks.get(attacker.character_id, {})
				owner_locks[lock_key] = true
				bounded_owner_turn_rider_locks[attacker.character_id] = owner_locks
			elif use_limit == "once_per_round":
				bounded_round_rider_locks[lock_key] = true
			elif use_limit == "once_per_roll":
				roll.used[lock_key] = true
			elif use_limit == "once_per_active_instance":
				if not grant.has("used_rider_options"): grant["used_rider_options"] = []
				grant.used_rider_options.append(str(effect.id))
			else:
				bounded_hit_rider_locks[lock_key] = true
		var rolled := Dice.parse_dice_string(formula, {}, attacker)
		var actual := int(resolve_damage(target, rolled, damage_type, {}, false, false, attacker)["damage"])
		if once_per_turn:
			attacker.feature_uses[marker] = 1
		applied.append({"damage": actual, "damage_type": damage_type, "formula": formula, "feature_id": str(effect.get("feature_id", "cleric_blessed_strikes")), "source_instance_id": str(effect.get("source_instance_id", "")), "option_id": str(effect.get("id", "")), "use_limit": use_limit, "payment_waived": payment_waived, "pool_cost": use_cost if not use_limit.is_empty() else 0, "payment_source_instance_id": replacement_payment_source, "replacement_payment": replacement_payment_receipt.duplicate(true), "grant_instance_id": str(grant.get("grant_instance_id", "")), "roll_id": int(attack_receipt.get("weapon_rider_roll_id", 0))})
	return applied


static func _weapon_rider_active_grant(actor: Character, source_id: String) -> Dictionary:
	for modifier in actor.modifiers:
		if str(modifier.get("owner_id", "")) == actor.character_id and str(modifier.get("source_instance_id", "")) == source_id and not str(modifier.get("grant_instance_id", "")).is_empty() and int(modifier.get("expires_at_seconds", 0)) > int(GameManager.campaign_elapsed_seconds):
			return modifier
	return {}


static func _weapon_rider_target_id(target: Dictionary) -> String:
	return str(target.get("character_id", target.get("id", ""))).strip_edges()


static func _is_melee_weapon_attack(weapon_data: Dictionary) -> bool:
	if str(weapon_data.get("type", "")) != "weapon":
		return false
	var properties: Array = weapon_data.get("properties", [])
	return "ranged" not in properties and "ammunition" not in properties


static func _bounded_hit_rider_lock_key(owner_id: String, source_id: String, option_id: String, turn_serial: int, target_id: String) -> String:
	return JSON.stringify([owner_id, source_id, option_id, turn_serial, target_id])


static func _bounded_owner_turn_rider_lock_key(source_id: String, option_id: String) -> String:
	return JSON.stringify([source_id, option_id])


static func resolve_spell_cast_riders(caster: Character, spell_data: Dictionary, action_cost: String, damage_dealt: int = 0, recipient = null) -> Array[Dictionary]:
	var applied: Array[Dictionary] = []
	if caster == null:
		return applied
	var class_data := DataLoader.get_character_class(caster.class_id)
	if int(spell_data.get("level", -1)) != 0 or str(spell_data.get("id", "")) not in class_data.get("spell_list_ids", []):
		return applied
	for effect in ClassProgression.selected_feature_effects_of_type(caster, "spell_cast_temporary_hp"):
		if int(effect.get("spell_level", -1)) != 0 or str(effect.get("spell_list", "")) != caster.class_id or not caster.has_feature(str(effect.get("requires_feature", ""))):
			continue
		if bool(effect.get("requires_damage", false)) and (damage_dealt <= 0 or recipient == null):
			continue
		if not bool(effect.get("requires_damage", false)) and action_cost != str(effect.get("action_cost", "magic_action")):
			continue
		var beneficiary = recipient if recipient != null else caster
		var amount := maxi(0, caster.ability_scores.get_ability_modifier(str(effect.get("ability", "WIS"))) * int(effect.get("multiplier", 1)))
		if beneficiary is Character:
			beneficiary.temp_hp = maxi(beneficiary.temp_hp, amount)
		elif beneficiary is Dictionary:
			beneficiary["temp_hp"] = maxi(int(beneficiary.get("temp_hp", 0)), amount)
		applied.append({"granted": amount})
	return applied


static func _resolve_words_power_spell(caster: Character, target_entity, spell_data: Dictionary, reaction_decisions: Dictionary = {}) -> Dictionary:
	return SpellHealingResolver._resolve_words_power_spell(caster, target_entity, spell_data, reaction_decisions)


static func can_receive_power_word_heal(target: Character) -> bool:
	return target != null and not target.is_dead()


static func stand_after_power_word_heal(target) -> bool:
	if not has_condition(target, "prone") or is_incapacitated(target):
		return false
	if target is Character and target.reaction_available:
		target.remove_condition("prone")
		target.reaction_available = false
		return true
	if target is Dictionary and bool(target.get("reaction_available", true)):
		target.get("conditions", {}).erase("prone")
		target["reaction_available"] = false
		return true
	return false


static func spend_spell_slot(caster: Character, spell_data: Dictionary, requested_slot_level: int = 0) -> Dictionary:
	var spell_level: int = int(spell_data.get("level", 0))
	if spell_level <= 0:
		return {"success": true, "slot_level": 0}
	if caster.class_id == "warlock" and spell_level > 5:
		return {"success": false, "message": "Warlock spells above level 5 require Mystic Arcanum."}
	var pool_id := str(spell_data.get("_spell_slot_pool_id", SpellSlotRules.default_pool_id(caster)))
	var slot_key := _slot_key_for_spell(caster, spell_level, spell_data)
	if requested_slot_level > 0:
		slot_key = str(requested_slot_level)
		if requested_slot_level < spell_level or SpellSlotRules.remaining(caster, pool_id, requested_slot_level) <= 0:
			return {"success": false, "message": "No level %d spell slot is available for this cast." % requested_slot_level}
	var current_slots := SpellSlotRules.remaining(caster, pool_id, int(slot_key))
	if current_slots <= 0:
		return {"success": false, "message": "No level %d spell slots remaining!" % spell_level}
	if ClassProgression.has_epic_boon(caster, "spell_recall") and int(slot_key) <= 4 and Dice.roll(4) == int(slot_key):
		return {"success": true, "slot_level": int(slot_key), "slot_pool_id":pool_id, "slot_recalled": true}
	if not SpellSlotRules.spend(caster, pool_id, int(slot_key)):
		return {"success": false, "message": "No level %d spell slots remaining!" % spell_level}
	return {"success": true, "slot_level": int(slot_key), "slot_pool_id":pool_id}


static func get_spell_slot_level(caster: Character, spell_data: Dictionary) -> int:
	var spell_level := int(spell_data.get("level", 0))
	if spell_level <= 0:
		return 0
	return int(_slot_key_for_spell(caster, spell_level, spell_data))


## Resolve the base damage formula after cantrip upgrades and generic slot scaling.
## Spells use `scaling` for character-level thresholds and
## `upcast.damage_per_level` for each slot level above `upcast.starting_level`.
static func spell_damage_formula(caster: Character, spell_data: Dictionary, slot_level: int = 0) -> String:
	return SpellDamageRolls.spell_damage_formula(caster, spell_data, slot_level)


static func spell_delayed_damage_for_resolution(caster: Character, spell_data: Dictionary, resolution: Dictionary) -> Dictionary:
	return SpellDamageRolls.spell_delayed_damage_for_resolution(caster, spell_data, resolution)


static func spell_requires_saving_throw(spell_data: Dictionary) -> bool:
	if not str(spell_data.get("save", "")).strip_edges().is_empty():
		return true
	for step in spell_data.get("steps", []):
		if step is Dictionary and (step.get("type", "") == "save" or not str(step.get("save", "")).strip_edges().is_empty()):
			return true
	return false


static func _spell_effect_save_dc(target, spell_id: String, fallback: int) -> int:
	for record in SpellEffects.records(target).values():
		if str(record.get("spell_id", "")) == spell_id:
			return int(record.get("save_dc", fallback))
	return fallback


static func _spell_directly_damages_target(spell_data: Dictionary) -> bool:
	if str(spell_data.get("attack_type", "none")) != "none":
		return true
	if spell_data.has("damage_per_dart") or spell_data.has("damage_per_ray"):
		return true
	return spell_data.has("damage") and not str(spell_data.get("damage_type", "")).is_empty()


static func _spell_is_area_effect(spell_data: Dictionary) -> bool:
	if str(spell_data.get("target", "")) in ["area", "cone", "emanation"]:
		return true
	return int(spell_data.get("area_radius", 0)) > 0 or int(spell_data.get("area_radius_feet", 0)) > 0 or int(spell_data.get("cone_size", 0)) > 0 or int(spell_data.get("emanation_radius_feet", 0)) > 0 or int(spell_data.get("emanation_radius_hexes", 0)) > 0


## Apply slot scaling declared for healing effects before CombatState dispatches them.
static func spell_effects_for_slot_level(spell_data: Dictionary, slot_level: int) -> Array:
	return SpellDamageRolls.spell_effects_for_slot_level(spell_data, slot_level)


static func _roll_spell_damage(caster: Character, formula: String, repetitions: int, decisions: Dictionary) -> Dictionary:
	return SpellDamageRolls._roll_spell_damage(caster, formula, repetitions, decisions)


static func _roll_sorcerous_burst_damage(caster: Character, formula: String, explode_on: int, ability: String) -> Dictionary:
	return SpellDamageRolls._roll_sorcerous_burst_damage(caster, formula, explode_on, ability)


static func _resolve_sorcerous_burst_explosions(caster: Character, details: Dictionary) -> Dictionary:
	return SpellDamageRolls._resolve_sorcerous_burst_explosions(caster, details)


static func _can_empower(caster: Character, decisions: Dictionary) -> bool:
	return SpellDamageRolls._can_empower(caster, decisions)


static func _apply_empowered_spell(caster: Character, details: Dictionary, decisions: Dictionary) -> Dictionary:
	return SpellDamageRolls._apply_empowered_spell(caster, details, decisions)
static func _finish_spell_damage(caster: Character, target, details: Dictionary, bonus: int, scale: float, damage_type: String, decisions: Dictionary, result: Dictionary, condition_duration: int = 1, additional_damage_packets: Array[Dictionary] = []) -> Dictionary:
	return SpellDamageRolls._finish_spell_damage(caster, target, details, bonus, scale, damage_type, decisions, result, condition_duration, additional_damage_packets)


static func finish_pending_spell_damage(caster: Character, target, result: Dictionary, decisions: Dictionary) -> Dictionary:
	if not result.has("damage_request"):
		return result
	# The caller supplies only the owner's answer; every other fact comes from the
	# registered request, so a copied/stale payload can not redirect or replace it.
	var answer := {}
	if decisions.has("metamagic:empowered_dice"):
		answer["metamagic:empowered_dice"] = decisions["metamagic:empowered_dice"]
	if decisions.has("zero_hp_source"):
		answer["zero_hp_source"] = decisions["zero_hp_source"]
	var settlement := SpellDamageRolls.settle_pending_request(caster, target, result, answer)
	if not settlement.get("valid", false):
		if bool(settlement.get("no_op", false)):
			return result
		var err_msg: String = str(settlement.get("error", "Request validation failed."))
		push_warning("[CombatAction] finish_pending_spell_damage refused: %s" % err_msg)
		return {"success": false, "refused": true, "error": err_msg, "message": err_msg}

	for key in ["empowered_sp_spent", "empowered_remaining_dice"]:
		if answer.has(key):
			decisions[key] = answer[key]
	var record: Dictionary = settlement["record"]
	var working_result: Dictionary = settlement["result"]
	result.erase("damage_request")
	result.erase("ordered_continuation")

	var ordered_cont = record.get("ordered_continuation")
	if ordered_cont is Dictionary:
		if working_result.has("damage_request"):
			SpellDamageRolls.attach_continuation(str(working_result.damage_request.request_id), ordered_cont, ordered_cont.get("cast"))
			return working_result
		return SharedSpell.resume_pending_steps(record["caster"], record["target"], working_result, record["decisions"], ordered_cont)
	return working_result


static func finish_pending_concentration_choice(caster: Character, target, result: Dictionary, answer: Dictionary) -> Dictionary:
	if not result.has("concentration_request"):
		return result
	var settlement := SpellDamageRolls.settle_pending_concentration_request(caster, target, result, answer)
	if not settlement.get("valid", false):
		if bool(settlement.get("no_op", false)):
			return result
		var err_msg: String = str(settlement.get("error", "Request validation failed."))
		push_warning("[CombatAction] finish_pending_concentration_choice refused: %s" % err_msg)
		return {"success": false, "refused": true, "error": err_msg, "message": err_msg}

	var record: Dictionary = settlement["record"]
	var ordered_cont = record.get("ordered_continuation")
	result.erase("concentration_request")
	result.erase("ordered_continuation")

	if bool(settlement.get("has_next_request", false)):
		var next_req_id: String = settlement["next_request_id"]
		result["concentration_request"] = {
			"request_id": next_req_id,
			"target": record["target"],
			"dc": settlement["next_dc"],
			"roll": settlement["next_roll"],
			"feature": settlement["next_feature"],
			"save_test": settlement["save_test"]
		}
		if ordered_cont is Dictionary:
			result["ordered_continuation"] = ordered_cont
		return result

	if ordered_cont is Dictionary:
		return SharedStepExecutor.resume_spell_steps_occurrence(record["caster"], record["target"], result, record["decisions"], ordered_cont, settlement)
	return result



static func _reaction_accepted(reaction_id: String, decisions: Dictionary) -> bool:
	# Existing direct resolver callers retain the deterministic automatic policy.
	# CombatState supplies an explicit decision map for owner-facing prompts.
	return bool(decisions.get(reaction_id, true))


static func evaluate_physical_eligibility(target, filter: Dictionary) -> Dictionary:
	return PhysicalFactsRules.evaluate_physical_eligibility(target, filter)


static func is_space_available(grid: HexGrid, position: Vector2i, size: String = "medium", plane: String = PhysicalFactsRules.DEFAULT_PLANE, context: Dictionary = {}) -> Dictionary:
	return PhysicalFactsRules.is_space_available(grid, position, size, plane, context)


static func calculate_movement_step_cost(actor, mode: String, terrain_type: String = "normal", surface: String = "ground", context: Dictionary = {}) -> Dictionary:
	return PhysicalFactsRules.calculate_movement_step_cost(actor, mode, terrain_type, surface, context)


static func attempt_movement_step(actor, mode: String, from_pos: Vector2i, to_pos: Vector2i, current_budget_feet: int, grid: HexGrid, surface: String = "ground", terrain_type: String = "normal", context: Dictionary = {}) -> Dictionary:
	return PhysicalFactsRules.attempt_movement_step(actor, mode, from_pos, to_pos, current_budget_feet, grid, surface, terrain_type, context)
