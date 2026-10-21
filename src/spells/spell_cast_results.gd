## Per-target spell results and shared action completion.
class_name SpellCastResults
extends RefCounted

static func _resolve_spell_cast_targets(cast: SpellCastContext) -> void:
	if cast.spell.has("steps"):
		await _resolve_stepped_spell_cast(cast)
		return
	# Apply spell to all entities in the targets list
	cast.successful = false
	cast.interrupted = false
	cast.damage_dealt = 0
	var area_spell_id := str(cast.spell.get("id", ""))
	if area_spell_id in ["entangle", "black_tentacles", "sleet_storm", "wall_of_fire", "cloudkill", "conjure_animals", "conjure_celestial", "conjure_elemental", "conjure_fey", "conjure_minor_elementals", "conjure_woodland_beings", "spirit_guardians", "aura_of_life", "antilife_shell", "moonbeam"]:
		cast.areas._spell_zone_serial += 1
		cast.area_source_id = "%s:%s:%d" % [area_spell_id, cast.caster.character_id, cast.areas._spell_zone_serial]
	for target_index in cast.targets.size():
		var target_hex: Vector2i = cast.targets[target_index]
		if str(cast.spell.get("id", "")) in ["conjure_woodland_beings", "spirit_guardians", "aura_of_life", "antilife_shell"]:
			continue
		# Check if player is there
		var p_target: Character = null
		var chain_target_id := str(cast.chain_target_ids[target_index]) if target_index < cast.chain_target_ids.size() else ""
		if chain_target_id.is_empty() or chain_target_id.begins_with("player:"):
			for p in cast.players:
				if p["hex_position"] != target_hex:
					continue
				var candidate: Character = p["character"]
				var candidate_id := candidate.character_id if not candidate.character_id.is_empty() else "runtime_%d" % candidate.get_instance_id()
				if str(cast.spell.get("id", "")) in ["revivify", "gentle_repose"]:
					if candidate.is_dead() and candidate.character_id == str(cast.spell.get("_recovery_target_id", "")):
						p_target = candidate
						break
					continue
				if (chain_target_id.is_empty() or chain_target_id == "player:%s" % candidate_id) and (candidate.is_alive or SpellCastTargeting.can_target_downed(candidate, cast.spell) or (str(cast.spell.get("id", "")) in ["revivify", "gentle_repose"] and candidate.is_dead())):
					p_target = candidate
					break

		# Check if monster is there
		var m_target: Dictionary = {}
		if chain_target_id.is_empty() or chain_target_id.begins_with("monster:"):
			for m in cast.monsters:
				if m["hex_position"] == target_hex and m["is_alive"] and (chain_target_id.is_empty() or chain_target_id == "monster:%s" % str(m.get("id", ""))):
					m_target = m
					break
		if str(cast.spell.get("id", "")) == "entangle" and p_target == cast.caster:
			continue

		if str(cast.spell.get("id", "")) == "conjure_celestial" and (p_target != null or not m_target.is_empty()):
			var celestial_target = p_target if p_target != null else m_target
			var celestial_target_id := cast.areas._spell_zone_target_id(celestial_target)
			var celestial_target_name := p_target.character_name if p_target != null else str(m_target.get("name", "The creature"))
			var light_choice := str(cast.spell.get("_test_conjure_celestial_light", ""))
			if light_choice.is_empty():
				light_choice = await cast.hud.request_conjure_celestial_light(celestial_target_name)
			if light_choice not in ["healing", "searing"]:
				light_choice = "searing"
			if light_choice == "healing":
				SpellZoneConjurations._apply_conjure_celestial_healing(cast.areas, celestial_target, cast.caster, cast.slot_level_used)
				cast.successful = true
				cast.initial_targets[celestial_target_id] = cast.areas._current_spell_trigger_turn()
				continue
		elif str(cast.spell.get("id", "")) == "conjure_animals":
			continue
		if p_target != null:
			await _resolve_player_target(cast, p_target, target_hex, area_spell_id == "chain_lightning" and target_index > 0)
		elif not m_target.is_empty():
			await _resolve_monster_target(cast, m_target, target_hex, area_spell_id == "chain_lightning" and target_index > 0)
		var object_target: Dictionary = CombatObjectRules.by_key(cast.grid, target_hex, chain_target_id.trim_prefix("object:")) if chain_target_id.begins_with("object:") else CombatObjectRules.at(cast.grid, target_hex)
		var object_owner: Character = null
		if area_spell_id == "chain_lightning" and chain_target_id.begins_with("object:") and object_target.is_empty():
			var owned_item := CombatObjectRules.owned_item_record_at(cast.players, target_hex, chain_target_id.trim_prefix("object:"))
			if not owned_item.is_empty():
				object_owner = owned_item["character"]
				object_target = CombatObjectRules.make_owned_item(owned_item["record"], object_owner.character_id, chain_target_id.trim_prefix("object:") in object_owner.inventory.copies.equipped.values(), target_hex)
		var fire_bolt_object_target := (bool(cast.spell.get("targets_objects", false)) or area_spell_id == "fire_bolt") and p_target == null and m_target.is_empty() and CombatObjectRules.can_take_spell_damage(object_target)
		if area_spell_id == "chain_lightning" and (chain_target_id.begins_with("object:") or (chain_target_id.is_empty() and p_target == null and m_target.is_empty())) and CombatObjectRules.can_target(object_target):
			await _resolve_object_target(cast, object_target, target_hex, target_index > 0)
			if object_owner != null:
				CombatObjectRules.sync_owned_item_object(object_owner, chain_target_id.trim_prefix("object:"), object_target)
		elif fire_bolt_object_target:
			await _resolve_object_target(cast, object_target, target_hex)
			if (bool(cast.spell.get("ignites_objects", false)) or area_spell_id == "fire_bolt") and bool(cast.spell.get("_last_object_hit", false)) and CombatObjectRules.ignite(object_target):
				cast.hud.add_log("%s catches fire." % str(object_target.get("name", "The object")))
		elif area_spell_id == "meteor_swarm":
			for area_object in CombatObjectRules.all_at(cast.grid, target_hex):
				if CombatObjectRules.can_take_spell_damage(area_object):
					await _resolve_meteor_object_target(cast, area_object)
		elif bool(cast.spell.get("ignites_objects", false)) or area_spell_id in ["burning_hands", "fireball"]:
			for area_object in CombatObjectRules.all_at(cast.grid, target_hex):
				if CombatObjectRules.can_take_spell_damage(area_object) and CombatObjectRules.ignite(area_object):
					cast.successful = true
					cast.hud.add_log("%s catches fire." % str(area_object.get("name", "A flammable object")))
		if cast.interrupted:
			break


static func _resolve_object_target(cast: SpellCastContext, object: Dictionary, target_hex: Vector2i, ignore_spell_range: bool = false) -> void:
	var target := CombatObjectRules.make_resolution_target(object)
	var origin: Vector2i = cast.players[cast.player_index].get("hex_position", Vector2i.ZERO)
	var distance_feet := 0 if ignore_spell_range else HexUtils.get_distance(cast.spell_origin, target_hex) * 5
	var decisions := SpellCastResults._spell_decisions_for_target(cast, cast.counterspell_decisions, cast.counterspell_pending)
	decisions["spell_visibility"] = {"grid": cast.grid, "caster_position": origin, "target_position": target_hex}
	var observers := cast.counterspell_observers if cast.counterspell_pending else []
	var result := CombatAction.resolve_spell(cast.caster, target, cast.spell, false, decisions, observers, cast.slot_level_used, distance_feet, cast)
	cast.spell["_last_object_hit"] = bool(result.get("hit", false))
	result = await SpellCastResults._settle_empowered_spell(cast, target, result, decisions)
	CombatObjectRules.sync_resolution_target(object, target)
	cast.counterspell_pending = false
	if result.get("success", true):
		cast.successful = true
	if int(result.get("damage", 0)) > 0:
		cast.damage_dealt += int(result["damage"])
	cast.hud.add_log(str(result.get("message", "%s is affected." % str(object.get("name", "The object")))))
	if not result.get("success", true):
		cast.interrupted = true


static func _resolve_meteor_object_target(cast: SpellCastContext, object: Dictionary) -> void:
	var result := CombatObjectRules.resolve_meteor_swarm(cast.caster, object, cast.spell, cast.slot_level_used)
	if not result.get("success", false):
		return
	cast.successful = true
	cast.damage_dealt += int(result.get("damage", 0))
	cast.hud.add_log(str(result.get("message", "The object is struck by Meteor Swarm.")))

static func _resolve_player_target(cast: SpellCastContext, p_target: Character, target_hex: Vector2i, ignore_spell_range: bool = false) -> void:
	var paladin_hp_before := p_target.current_hp
	var target_spell_decisions := SpellCastResults._spell_decisions_for_target(cast, cast.counterspell_decisions, cast.counterspell_pending)
	target_spell_decisions["spell_visibility"] = {"grid": cast.grid, "caster_position": cast.players[cast.player_index]["hex_position"], "target_position": target_hex}
	target_spell_decisions["grid"] = cast.grid
	target_spell_decisions["players"] = cast.players
	target_spell_decisions["monsters"] = cast.monsters
	target_spell_decisions["cast_context"] = cast
	target_spell_decisions["hud"] = cast.hud
	target_spell_decisions["tracker"] = cast.tracker
	target_spell_decisions["trigger_enemy_defeat_features"] = cast.trigger_enemy_defeat_features
	if CombatAction.spell_requires_saving_throw(cast.spell):
		target_spell_decisions.merge(await cast.collect_stroke_of_luck_save_decision.call(p_target, str(cast.spell.get("name", "this spell"))), true)
	if not SorcererRules.is_careful_spell_target(cast.caster, cast.spell, p_target, cast.counterspell_decisions.get("metamagic:careful_targets", [])):
		target_spell_decisions.merge(await cast.collect_bardic_inspiration_save_decision.call(p_target, cast.spell), true)
	var spell_target_distance := 0 if ignore_spell_range else HexUtils.get_distance(cast.spell_origin, target_hex) * 5
	var charm_context: Dictionary = await cast.collect_countercharm_decisions.call(p_target, target_hex, cast.spell)
	target_spell_decisions.merge(charm_context.get("decisions", {}), true)
	var target_observers: Array = cast.counterspell_observers.duplicate() if cast.counterspell_pending else []
	for observer in charm_context.get("observers", []):
		if observer not in target_observers:
			target_observers.append(observer)
		var counterspell_key := "counterspell:%s" % observer.character_name
		if not target_spell_decisions.has(counterspell_key):
			target_spell_decisions[counterspell_key] = false
	target_spell_decisions.merge(await cast.collect_spell_shield_decision.call(p_target, cast.spell, target_spell_decisions), true)
	if cast.collect_roll_token_decision.is_valid():
		if CombatAction.spell_requires_saving_throw(cast.spell):
			target_spell_decisions.merge(await cast.collect_roll_token_decision.call(p_target, "save", "%s saving throw against %s" % [str(cast.spell.get("save", "Spell")), str(cast.spell.get("name", "spell"))], target_spell_decisions), true)
		elif str(cast.spell.get("attack_type", "none")) != "none":
			target_spell_decisions.merge(await cast.collect_roll_token_decision.call(cast.caster, "attack", "%s spell attack against %s" % [str(cast.spell.get("name", "Spell")), p_target.character_name], target_spell_decisions), true)
	if cast.collect_projected_ward_decision.is_valid():
		target_spell_decisions.merge(await cast.collect_projected_ward_decision.call(p_target), true)
	var target_temp_hp_before := p_target.temp_hp
	var p_target_was_shape_shifted := DruidRules.is_shaped(p_target)
	var target_spell_data := cast.spell.duplicate(true)
	if str(cast.spell.get("id", "")) == "entangle":
		target_spell_data["condition_on_failed_save"] = ""
	if str(cast.spell.get("id", "")) == "black_tentacles":
		target_spell_data["condition_on_failed_save"] = ""
	if str(cast.spell.get("id", "")) == "true_strike":
		target_spell_data["range"] = SpellCastTargeting._spell_target_range(cast, cast.spell)
	if str(cast.spell.get("id", "")) in ["magic_missile", "scorching_ray", "eldritch_blast"]:
		var target_key := "%d,%d" % [target_hex.x, target_hex.y]
		var assigned_count := int(cast.spell.get("_projectile_target_counts", {}).get(target_key, SpellCastTargeting._spell_projectile_total(cast, cast.spell)))
		if str(cast.spell.get("id", "")) == "magic_missile":
			target_spell_data["_magic_missile_darts_for_target"] = assigned_count
		else:
			target_spell_data["_scorching_ray_count_for_target"] = assigned_count
	if str(target_spell_data.get("attack_type", "none")) != "none":
		target_spell_data["_conjure_minor_elementals_bonus_packets"] = await SpellZoneConjurations._conjure_minor_elementals_spell_attack_choices(cast.areas, cast.caster, p_target, target_spell_data)
	var res := CombatAction.resolve_spell(cast.caster, p_target, target_spell_data, false, target_spell_decisions, target_observers, cast.slot_level_used, spell_target_distance, cast)
	res = await _settle_failed_save_numeric_bonus(cast, p_target, res)
	res = await _settle_shared_spell_attack_bonus(cast, p_target, res)
	if bool(res.get("recipient_negated", false)):
		CastInterruptionRules.observe_host_result(cast, res)
		cast.successful = true
		cast.counterspell_pending = false
		cast.hud.add_log(str(res.get("message", "Spell effect negated.")))
		return
	if str(cast.spell.get("id", "")) == "moonbeam" and not bool(res.get("saved", true)) and p_target_was_shape_shifted:
		SpellZoneTerrain._apply_moonbeam_shape_change(cast.areas, p_target, cast.area_source_id, cast.shape_locked_targets, true)
	if str(cast.spell.get("id", "")) == "entangle" and not bool(res.get("saved", true)):
		CombatAction.apply_condition(p_target, "restrained", 99, cast.area_source_id)
		if p_target.condition_sources.get("restrained", {}).has(cast.area_source_id):
			cast.restrained_targets.append(p_target)
			cast.hud.add_log("[color=purple]%s is Restrained by Entangle.[/color]" % p_target.character_name)
	if str(cast.spell.get("id", "")) == "black_tentacles" and not bool(res.get("saved", true)):
		SpellZoneTerrain._apply_black_tentacles_restrained(cast.areas, p_target, cast.area_source_id, cast.restrained_targets)
	if str(cast.spell.get("id", "")) == "true_strike" and bool(res.get("success", false)):
		var true_strike_profile: Dictionary = DataLoader.get_item(str(cast.spell.get("_true_strike_weapon_id", ""))).duplicate(true)
		true_strike_profile["ability"] = SpellPermissionRules.selected_ability(cast.spell, cast.caster.get_spellcasting_ability())
		true_strike_profile["_true_strike"] = true
		true_strike_profile["damage_type"] = str(cast.spell.get("_true_strike_damage_type", true_strike_profile.get("damage_type", "bludgeoning")))
		var strike_distance := HexUtils.get_distance(cast.players[cast.player_index].get("hex_position", Vector2i.ZERO), target_hex)
		true_strike_profile["attack_distance"] = strike_distance
		target_spell_decisions.merge(await cast.collect_attack_inspiration_decision.call(cast.caster), true)
		target_spell_decisions.merge(await cast.collect_reaction_decisions.call(p_target), true)
		var bonus_dice := CombatAction.true_strike_bonus_damage(cast.caster.level)
		var strike_advantage := not CombatPerception.can_see_target(p_target, cast.caster, target_hex, cast.players[cast.player_index]["hex_position"], cast.grid)
		var strike_disadvantage := not CombatPerception.can_see_target(cast.caster, p_target, cast.players[cast.player_index]["hex_position"], target_hex, cast.grid)
		if CombatAction.is_invisible(p_target) and not CombatAction.can_perceive_invisible(cast.caster, strike_distance * 5):
			strike_disadvantage = true
		if CombatAction.is_invisible(cast.caster) and not CombatAction.can_perceive_invisible(p_target, strike_distance * 5):
			strike_advantage = true
		if cast.caster.has_condition("hidden"):
			strike_advantage = true
			cast.caster.remove_condition("hidden")
		var strike_additional_damage := {"formula": bonus_dice, "type": "radiant", "label": "True Strike Radiant"} if not bonus_dice.is_empty() else {}
		var fey_damage_packet := await SpellZoneConjurations._conjure_minor_elementals_damage_choice(cast.areas, cast.caster, p_target)
		if not fey_damage_packet.is_empty():
			strike_additional_damage["packets"] = [fey_damage_packet]
		var strike_result := CombatAction.resolve_weapon_attack(cast.caster, p_target, true_strike_profile, strike_advantage, strike_disadvantage, target_spell_decisions, strike_additional_damage)
		await cast.offer_divine_smite.call(p_target, true_strike_profile, strike_result, cast.caster)
		var cast_message := str(res.get("message", "True Strike resolves."))
		res.merge(strike_result, true)
		res["success"] = true
		res["message"] = cast_message + " " + str(strike_result.get("message", "The attack misses."))
		cast.publish_true_strike_activity.call({"id": p_target.character_id, "name": p_target.character_name}, true_strike_profile, strike_result)
	res = await SpellCastResults._settle_empowered_spell(cast, p_target, res, target_spell_decisions)
	if res.has("damage_components"): cast.damage_receipts.append_array(res["damage_components"].duplicate(true))
	if int(res.get("damage", 0)) > 0:
		ClericRules.clear_turning_after_damage(p_target)
	cast.damage_dealt += int(res.get("damage", 0)) + maxi(0, target_temp_hp_before - p_target.temp_hp)
	cast.hud.add_log(res.get("message", ""))
	cast.counterspell_pending = false
	if not res.get("success", true):
		cast.interrupted = true
		return
	cast.successful = true
	if str(cast.spell.get("id", "")) == "enhance_ability":
		var enhance_coord_key := "%d,%d" % [target_hex.x, target_hex.y]
		var enhance_ability := str(cast.spell.get("_enhance_ability_choices", {}).get(enhance_coord_key, "STR"))
		if SpellEffects.grant_enhance_ability(p_target, cast.spell.get("_effect_cast", {}), enhance_ability):
			cast.hud.add_log("[color=cyan]%s gains Advantage on %s checks while %s concentrates.[/color]" % [p_target.character_name, enhance_ability, cast.caster.character_name])
	if str(cast.spell.get("id", "")) == "beacon_of_hope":
		SpellEffects.grant_beacon_of_hope(p_target, cast.spell.get("_effect_cast", {}))
		cast.hud.add_log("[color=cyan]%s is strengthened by Beacon of Hope.[/color]" % p_target.character_name)
	if str(cast.spell.get("id", "")) == "conjure_celestial":
		cast.initial_targets[cast.areas._spell_zone_target_id(p_target)] = cast.areas._current_spell_trigger_turn()
	
	if cast.spell.get("concentration", false):
		cast.caster.concentrating_on["targets"].append(p_target)
		
	await cast.offer_power_word_heal_stand.call(p_target, cast.spell)
	await SpellEffectApplication.apply(cast, p_target, {}, cast.spell, cast.players[cast.player_index].get("hex_position", Vector2i.ZERO), target_hex, res)
	if p_target == cast.caster and int(cast.spell.get("level", 0)) >= 1:
		cast.apply_find_steed_life_bond.call(p_target, maxi(0, p_target.current_hp - paladin_hp_before), cast.players[cast.player_index].get("hex_position", Vector2i.ZERO))


static func _resolve_monster_target(cast: SpellCastContext, m_target: Dictionary, target_hex: Vector2i, ignore_spell_range: bool = false) -> void:
	var spell_target_distance := 0 if ignore_spell_range else HexUtils.get_distance(cast.spell_origin, target_hex) * 5
	var target_spell_decisions := SpellCastResults._spell_decisions_for_target(cast, cast.counterspell_decisions, cast.counterspell_pending)
	target_spell_decisions["spell_visibility"] = {"grid": cast.grid, "caster_position": cast.players[cast.player_index]["hex_position"], "target_position": target_hex}
	target_spell_decisions["grid"] = cast.grid
	target_spell_decisions["players"] = cast.players
	target_spell_decisions["monsters"] = cast.monsters
	target_spell_decisions["cast_context"] = cast
	target_spell_decisions["hud"] = cast.hud
	if cast.collect_roll_token_decision.is_valid():
		if CombatAction.spell_requires_saving_throw(cast.spell):
			target_spell_decisions.merge(await cast.collect_roll_token_decision.call(m_target, "monster_save", "%s saving throw against %s" % [str(cast.spell.get("save", "Spell")), str(cast.spell.get("name", "spell"))], target_spell_decisions), true)
		elif str(cast.spell.get("attack_type", "none")) != "none":
			target_spell_decisions.merge(await cast.collect_roll_token_decision.call(cast.caster, "attack", "%s spell attack against %s" % [str(cast.spell.get("name", "Spell")), str(m_target.get("name", "target"))], target_spell_decisions), true)
	var target_temp_hp_before := int(m_target.get("temp_hp", 0))
	var target_spell_data := cast.spell.duplicate(true)
	if str(cast.spell.get("id", "")) == "entangle":
		target_spell_data["condition_on_failed_save"] = ""
	if str(cast.spell.get("id", "")) == "black_tentacles":
		target_spell_data["condition_on_failed_save"] = ""
	if str(cast.spell.get("id", "")) == "true_strike":
		target_spell_data["range"] = SpellCastTargeting._spell_target_range(cast, cast.spell)
	if str(cast.spell.get("id", "")) in ["magic_missile", "scorching_ray", "eldritch_blast"]:
		var target_key := "%d,%d" % [target_hex.x, target_hex.y]
		var assigned_count := int(cast.spell.get("_projectile_target_counts", {}).get(target_key, SpellCastTargeting._spell_projectile_total(cast, cast.spell)))
		if str(cast.spell.get("id", "")) == "magic_missile":
			target_spell_data["_magic_missile_darts_for_target"] = assigned_count
		else:
			target_spell_data["_scorching_ray_count_for_target"] = assigned_count
	if str(target_spell_data.get("attack_type", "none")) != "none":
		target_spell_data["_conjure_minor_elementals_bonus_packets"] = await SpellZoneConjurations._conjure_minor_elementals_spell_attack_choices(cast.areas, cast.caster, m_target, target_spell_data)
	var res := CombatAction.resolve_spell(cast.caster, m_target, target_spell_data, false, target_spell_decisions, cast.counterspell_observers if cast.counterspell_pending else [], cast.slot_level_used, spell_target_distance, cast)
	res = await _settle_shared_spell_attack_bonus(cast, m_target, res)
	if bool(res.get("recipient_negated", false)):
		CastInterruptionRules.observe_host_result(cast, res)
		cast.successful = true
		cast.counterspell_pending = false
		cast.hud.add_log(str(res.get("message", "Spell effect negated.")))
		return
	if str(cast.spell.get("id", "")) == "entangle" and not bool(res.get("saved", true)):
		CombatAction.apply_condition(m_target, "restrained", 99, cast.area_source_id)
		if CombatAction.has_condition_source(m_target, cast.area_source_id):
			cast.restrained_targets.append(m_target)
			cast.hud.add_log("[color=purple]%s is Restrained by Entangle.[/color]" % str(m_target.get("name", "The creature")))
	if str(cast.spell.get("id", "")) == "black_tentacles" and not bool(res.get("saved", true)):
		SpellZoneTerrain._apply_black_tentacles_restrained(cast.areas, m_target, cast.area_source_id, cast.restrained_targets)
	if str(cast.spell.get("id", "")) == "true_strike" and bool(res.get("success", false)):
		var true_strike_profile: Dictionary = DataLoader.get_item(str(cast.spell.get("_true_strike_weapon_id", ""))).duplicate(true)
		true_strike_profile["ability"] = SpellPermissionRules.selected_ability(cast.spell, cast.caster.get_spellcasting_ability())
		true_strike_profile["_true_strike"] = true
		true_strike_profile["damage_type"] = str(cast.spell.get("_true_strike_damage_type", true_strike_profile.get("damage_type", "bludgeoning")))
		var strike_distance := HexUtils.get_distance(cast.players[cast.player_index].get("hex_position", Vector2i.ZERO), target_hex)
		true_strike_profile["attack_distance"] = strike_distance
		var strike_reactions := SpellCastResults._spell_decisions_for_target(cast, cast.counterspell_decisions, false)
		strike_reactions.merge(await cast.collect_attack_inspiration_decision.call(cast.caster), true)
		var bonus_dice := CombatAction.true_strike_bonus_damage(cast.caster.level)
		var strike_advantage := not CombatPerception.can_see_target(m_target, cast.caster, target_hex, cast.players[cast.player_index]["hex_position"], cast.grid)
		var strike_disadvantage := not CombatPerception.can_see_target(cast.caster, m_target, cast.players[cast.player_index]["hex_position"], target_hex, cast.grid)
		if CombatAction.is_invisible(m_target) and not CombatAction.can_perceive_invisible(cast.caster, strike_distance * 5):
			strike_disadvantage = true
		if CombatAction.is_invisible(cast.caster) and not CombatAction.can_perceive_invisible(m_target, strike_distance * 5):
			strike_advantage = true
		if cast.caster.has_condition("hidden"):
			strike_advantage = true
			cast.caster.remove_condition("hidden")
		var strike_additional_damage := {"formula": bonus_dice, "type": "radiant", "label": "True Strike Radiant"} if not bonus_dice.is_empty() else {}
		var fey_damage_packet := await SpellZoneConjurations._conjure_minor_elementals_damage_choice(cast.areas, cast.caster, m_target)
		if not fey_damage_packet.is_empty():
			strike_additional_damage["packets"] = [fey_damage_packet]
		var strike_result := CombatAction.resolve_weapon_attack(cast.caster, m_target, true_strike_profile, strike_advantage, strike_disadvantage, strike_reactions, strike_additional_damage)
		await cast.offer_divine_smite.call(m_target, true_strike_profile, strike_result, cast.caster)
		await cast.offer_sneak_attack.call(m_target, true_strike_profile, strike_result, cast.caster, strike_advantage, strike_disadvantage)
		await cast.offer_weapon_damage_riders.call(cast.caster, m_target, true_strike_profile, strike_result)
		var cast_message := str(res.get("message", "True Strike resolves."))
		res.merge(strike_result, true)
		res["success"] = true
		res["message"] = cast_message + " " + str(strike_result.get("message", "The attack misses."))
		cast.publish_true_strike_activity.call(m_target, true_strike_profile, strike_result)
	res = await SpellCastResults._settle_empowered_spell(cast, m_target, res, target_spell_decisions)
	if res.has("damage_components"): cast.damage_receipts.append_array(res["damage_components"].duplicate(true))
	if int(res.get("damage", 0)) > 0:
		ClericRules.clear_turning_after_damage(m_target)
	cast.damage_dealt += int(res.get("damage", 0)) + maxi(0, target_temp_hp_before - int(m_target.get("temp_hp", 0)))
	cast.hud.add_log(res.get("message", ""))
	cast.counterspell_pending = false
	if not res.get("success", true):
		cast.interrupted = true
		return
	cast.successful = true
	if str(cast.spell.get("id", "")) == "beacon_of_hope":
		SpellEffects.grant_beacon_of_hope(m_target, cast.spell.get("_effect_cast", {}))
		cast.hud.add_log("[color=cyan]%s is strengthened by Beacon of Hope.[/color]" % str(m_target.get("name", "The creature")))
	if str(cast.spell.get("id", "")) == "conjure_celestial":
		cast.initial_targets[cast.areas._spell_zone_target_id(m_target)] = cast.areas._current_spell_trigger_turn()
	if str(cast.spell.get("id", "")) == "animal_messenger" and not bool(res.get("saved", true)):
		var messenger_order: Dictionary = cast.spell.get("_animal_messenger_order", {})
		var messenger_result := GameManager.register_animal_messenger(
			cast.caster,
			PartyManager.get_exploration_position(),
			cast.slot_level_used,
			bool(m_target.get("can_fly", false)),
			messenger_order
		)
		cast.hud.add_log("[color=cyan]%s[/color]" % messenger_result.get("message", "Animal Messenger could not dispatch its Beast."))
	
	if cast.spell.get("concentration", false):
		cast.caster.concentrating_on["targets"].append(m_target)
		
	await cast.offer_power_word_heal_stand.call(m_target, cast.spell)
	await SpellEffectApplication.apply(cast, null, m_target, cast.spell, cast.players[cast.player_index].get("hex_position", Vector2i.ZERO), target_hex, res)
	if str(cast.spell.get("id", "")) == "animal_friendship" and not bool(res.get("saved", true)) and str(res.get("condition", "")) == "charmed":
		var friendship_caster_ids: Array = m_target.get("animal_friendship_caster_ids", [])
		var friendship_caster_id := str(cast.caster.character_id)
		if not friendship_caster_id.is_empty() and friendship_caster_id not in friendship_caster_ids:
			friendship_caster_ids.append(friendship_caster_id)
			m_target["animal_friendship_caster_ids"] = friendship_caster_ids
	
	if int(m_target.get("current_hp", 0)) <= 0:
		m_target["is_alive"] = false
		cast.hud.add_log("[color=green]%s was defeated![/color]" % m_target["name"])
		cast.tracker.remove_combatant(m_target["id"])
		cast.trigger_enemy_defeat_features.call(m_target, cast.caster)


static func _finish_spell_cast(cast: SpellCastContext) -> void:
	CastInterruptionRules.settle_host(cast)
	if cast.counterspell_decisions.has("counterspell_saved_by"):
		cast.hud.add_log("[color=yellow]%s resists Counterspell; the spell continues.[/color]" % str(cast.counterspell_decisions["counterspell_saved_by"]))
	if not cast.interrupted and cast.incoming_slot_spent and cast.slot_level_used >= 1:
		for ward_ev in WardRules.on_slot_spell_cast(cast.caster, cast.spell, cast.slot_level_used):
			if cast.hud != null and not str(ward_ev.get("message", "")).is_empty():
				cast.hud.add_log("[color=cyan]%s[/color]" % str(ward_ev["message"]))

	if cast.successful and not cast.interrupted and not cast.result_recovery_queued and cast.incoming_slot_spent and cast.slot_level_used >= 1:
		cast.result_recovery_queued = true
		var recovery_host: Node = cast.hud if cast.hud != null else GameManager
		var settled_result: Dictionary = cast.ordered_result if not cast.ordered_result.is_empty() else cast.completed_cast_facts
		RestRules.queue_spell_result_recovery(cast.caster, settled_result, cast.slot_level_used, cast.incoming_slot_pool_id, recovery_host)

	# Finish spellcasting
	var spell_cost := str(cast.spell.get("casting_time", "action"))
	if spell_cost not in ["action", "bonus_action"]:
		spell_cost = "action"
	if cast.successful and not bool(cast.spell.get("_produce_flame_hurl", false)):
		await cast.offer_potent_spellcasting_vitality.call(cast.spell, cast.damage_dealt)
	if cast.successful and not cast.interrupted and cast.spell.has("_placement") and cast.attach_created_actors.is_valid():
		var placed: Array = cast.attach_created_actors.call(cast.caster, PlacementRules.decode(cast.spell["_placement"]))
		if not placed.is_empty() and cast.hud != null: cast.hud.add_log("%d created creature%s take%s their places." % [placed.size(), "" if placed.size() == 1 else "s", "s" if placed.size() == 1 else ""])
	_publish_completed_cast(cast)
	cast.spend_action_cost.call("bonus_action" if spell_cost == "bonus_action" else "magic_action")
	cast.clear_pending(SpellCastContext.CLEAR_ACTION)
	cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
	cast.clear_pending(SpellCastContext.CLEAR_WISH)
	cast.finish_targeting.call()
	cast.check_battle_end_conditions.call()
	cast.highlight_reachable.call()

static func _publish_completed_cast(cast: SpellCastContext) -> void:
	if cast == null or not cast.successful or cast.interrupted or not cast.completed_cast_facts.is_empty(): return
	var effect_cast: Dictionary = cast.spell.get("_effect_cast", {})
	cast.completed_cast_facts = {
		"type": "cast", "completed": true, "actor_id": SpellEffects.caster_id(cast.caster),
		"spell_id": str(cast.spell.get("id", "")), "school": str(cast.spell.get("school", "")),
		"slot_level": cast.slot_level_used,
		"paid_slot_level": cast.slot_level_used if cast.incoming_slot_spent else 0,
		"source_instance_id": str(effect_cast.get("source_id", "")),
		"invocation_id": cast.invocation_id, "action_id": cast.action_id,
		"parent_invocation_id":cast.action_invocation_id, "parent_source_id":cast.parent_source_id
	}
	var seen: Dictionary = {}
	for player in cast.players:
		var actor: Character = player.get("character")
		if actor == null: continue
		var actor_id := SpellEffects.caster_id(actor)
		if seen.has(actor_id): continue
		seen[actor_id] = true
		SpellEffects.publish_event(actor, cast.completed_cast_facts)
	for monster in cast.monsters:
		SpellEffects.publish_event(monster, cast.completed_cast_facts)


static func _resolve_ice_knife_splash(cast: SpellCastContext, center: Vector2i, spell_data: Dictionary, slot_level: int, cast_decisions: Dictionary) -> void:
	var splash_data := spell_data.duplicate(true)
	splash_data["attack_type"] = "none"
	splash_data["damage"] = str(spell_data.get("splash_damage", "2d6"))
	splash_data["damage_type"] = str(spell_data.get("splash_damage_type", "cold"))
	splash_data["save"] = str(spell_data.get("splash_save", "DEX"))
	splash_data["half_on_save"] = true
	splash_data["range"] = maxi(int(splash_data.get("range", 0)), 9999)
	splash_data["requires_target_sight"] = false
	var upcast: Dictionary = splash_data.get("upcast", {}).duplicate(true)
	upcast.erase("damage_per_level")
	if upcast.has("splash_damage_per_level"):
		upcast["damage_per_level"] = upcast["splash_damage_per_level"]
	splash_data["upcast"] = upcast
	var radius := maxi(0, int(spell_data.get("splash_radius", 1)))
	for target_hex in Targeting.get_sphere_targets(center, radius, cast.grid):
		var p_target: Character = null
		for player in cast.players:
			if player["hex_position"] == target_hex and player["character"].is_alive:
				p_target = player["character"]
				break
		var m_target: Dictionary = {}
		for monster in cast.monsters:
			if monster["hex_position"] == target_hex and monster["is_alive"]:
				m_target = monster
				break
		var target = p_target if p_target != null else m_target
		if target is Dictionary and target.is_empty():
			continue
		var distance_feet := HexUtils.get_distance(cast.players[cast.player_index].get("hex_position", Vector2i.ZERO), target_hex) * 5
		var decisions := SpellCastResults._spell_decisions_for_target(cast, cast_decisions, false)
		if p_target != null:
			decisions.merge(await cast.collect_stroke_of_luck_save_decision.call(p_target, "Ice Knife"), true)
			decisions.merge(await cast.collect_bardic_inspiration_save_decision.call(p_target, splash_data), true)
		var result := CombatAction.resolve_spell(cast.caster, target, splash_data, false, decisions, [], slot_level, distance_feet, cast)
		result = await SpellCastResults._settle_empowered_spell(cast, target, result, decisions)
		if int(result.get("damage", 0)) > 0:
			ClericRules.clear_turning_after_damage(target)
		cast.hud.add_log(result.get("message", ""))
		if m_target.size() > 0 and int(m_target.get("current_hp", 0)) <= 0:
			m_target["is_alive"] = false
			cast.hud.add_log("[color=green]%s was defeated![/color]" % m_target["name"])
			cast.tracker.remove_combatant(m_target["id"])
			cast.trigger_enemy_defeat_features.call(m_target, cast.caster)


static func _spell_decisions_for_target(cast: SpellCastContext, cast_decisions: Dictionary, first_target: bool) -> Dictionary:
	if first_target:
		return cast_decisions.duplicate()
	# Carry shared damage and chosen Careful targets forward without charging
	# unrelated first-target Metamagic options again on the next creature.
	var decisions := {}
	for key in ["metamagic:empowered", "metamagic:empowered_dice", "defer_empowered", "spell_damage_context", "metamagic:careful_targets"]:
		if cast_decisions.has(key):
			decisions[key] = cast_decisions[key]
	if bool(cast_decisions.get("metamagic:empowered", false)):
		decisions["metamagic:arcane_apotheosis"] = bool(cast_decisions.get("metamagic:arcane_apotheosis", false))
	return decisions


## Optional source authorization precedes settlement. Eligibility, exclusions and
## exact definition are checked again at the existing zero-HP boundary.
static func choose_zero_hp_source(hud: Node, target, rules: Array) -> String:
	if hud == null or rules.is_empty(): return ""
	var options: Array[String] = [""]
	var labels := {"": "Decline"}
	for rule in rules:
		var source := str(rule.source_instance_id)
		options.append(source)
		labels[source] = str(rule.get("name", source))
	return await hud._request_popup_choice("Zero HP replacement", options, labels)

static func _settle_empowered_spell(cast: SpellCastContext, target, result: Dictionary, decisions: Dictionary) -> Dictionary:
	while result.has("damage_request"):
		var req_target = target
		var owner_actor = SpellDamageRolls.owner_target(result)
		if owner_actor != null:
			req_target = owner_actor
		if bool(result["damage_request"].get("zero_hp", false)):
			var validation := SpellDamageRolls.validate_damage_request(cast.caster, req_target, result)
			if not validation.get("valid", false): return validation
			decisions["zero_hp_source"] = await choose_zero_hp_source(cast.hud, req_target, validation.record.get("zero_hp_options", []))
		elif cast.hud != null:
			var max_dice := int(result["damage_request"].get("max_dice", -1))
			decisions["metamagic:empowered_dice"] = await cast.hud.request_empowered_spell_dice(cast.caster, result["damage_request"]["details"], max_dice)
		else:
			decisions["metamagic:empowered_dice"] = decisions.get("metamagic:empowered_dice", [])
		result = CombatAction.finish_pending_spell_damage(cast.caster, req_target, result, decisions)
		if result.has("concentration_request"):
			result = await SpellCastResults._settle_concentration_choice(cast, target, result, decisions)
	result = SharedSpell.apply(cast.caster, target, cast.spell, result) if SharedSpell.uses(cast.spell) and not cast.spell.has("steps") else result
	if not cast.spell.has("steps"):
		for recipient in DamageLinkRules.recipient_settlements(target, result):
			if recipient["actor"] is Character:
				if bool(recipient.get("knocked_out", false)):
					SpellEncounterLifecycle._end_concentration(cast, recipient["actor"])
				else:
					await SpellEncounterLifecycle._check_concentration_save(cast, recipient["actor"], int(recipient["resolved"]))
	CastInterruptionRules.observe_host_result(cast, result)
	return result


static func _settle_concentration_choice(cast: SpellCastContext, target, result: Dictionary, decisions: Dictionary) -> Dictionary:
	while result.has("concentration_request"):
		var req: Dictionary = result["concentration_request"]
		var req_target = req.get("target", target)
		var owner_actor = SpellDamageRolls.owner_target(result)
		if owner_actor != null:
			req_target = owner_actor
		var choice_feature: String = str(req.get("feature", "stroke_of_luck"))
		var accepted := false
		if cast.hud != null and cast.owner_label_for_character.is_valid():
			var owner_label: String = cast.owner_label_for_character.call(req_target)
			if choice_feature == "stroke_of_luck":
				accepted = await cast.hud.request_reaction(owner_label, "stroke_of_luck", "If this concentration save fails, turn its d20 into a 20?", "Use Stroke of Luck on this save?", "Turn the d20 into 20", "Stroke of Luck — %s" % owner_label)
			elif choice_feature == "bardic_inspiration":
				var die := str(req_target.feature_uses.get("bardic_inspiration_die", "1d6"))
				accepted = await cast.hud.request_reaction(owner_label, "bardic_inspiration", "If your concentration save still fails, add %s to the roll?" % die, "Save Bardic Inspiration for this save?", "Use Inspiration", "Bardic Inspiration — %s" % owner_label)
		else:
			var feature_dec = SpellDamageRolls.get_concentration_decision(decisions, req_target, choice_feature, cast.caster)
			accepted = bool(feature_dec) if feature_dec != null else false
		result = CombatAction.finish_pending_concentration_choice(cast.caster, req_target, result, {"feature": choice_feature, "accepted": accepted})
		if result.has("damage_request"):
			result = await SpellCastResults._settle_empowered_spell(cast, target, result, decisions)
	return result


static func _settle_stepped_spell_actors(cast: SpellCastContext, res: Dictionary) -> void:
	var step_results: Array = res.get("step_results", [])
	var actor_damage_map := {}
	var ordered_actors: Array = []
	for step in step_results:
		if not step is Dictionary:
			continue
		for outcome in step.get("target_outcomes", []):
			if not outcome is Dictionary or bool(outcome.get("skipped", false)):
				continue
			if bool(outcome.get("occurrence_settled", false)):
				continue
			var actor = outcome.get("target")
			if actor == null:
				continue
			var found := false
			for known in ordered_actors:
				if SharedStepExecutor._same_actor(known, actor):
					found = true
					break
			if not found:
				ordered_actors.append(actor)
			var actor_key := str(actor.get_instance_id()) if actor is Character else str(actor.get("id", ""))
			var dmg := int(outcome.get("resolved", outcome.get("damage", 0)))
			actor_damage_map[actor_key] = int(actor_damage_map.get(actor_key, 0)) + dmg

	for actor in ordered_actors:
		var actor_key := str(actor.get_instance_id()) if actor is Character else str(actor.get("id", ""))
		var total_dmg: int = int(actor_damage_map.get(actor_key, 0))
		if total_dmg > 0:
			ClericRules.clear_turning_after_damage(actor)
			if actor is Character:
				await SpellEncounterLifecycle._check_concentration_save(cast, actor, total_dmg)
			elif actor is Dictionary:
				if int(actor.get("current_hp", 0)) <= 0 and not bool(actor.get("_defeat_processed", false)):
					actor["_defeat_processed"] = true
					actor["is_alive"] = false
					if cast.hud != null:
						cast.hud.add_log("[color=green]%s was defeated![/color]" % str(actor.get("name", "The creature")))
					if cast.tracker != null:
						cast.tracker.remove_combatant(str(actor.get("id", "")))
					if cast.trigger_enemy_defeat_features != null and cast.trigger_enemy_defeat_features.is_valid():
						cast.trigger_enemy_defeat_features.call(actor, cast.caster)


static func _settle_failed_save_numeric_bonus(cast: SpellCastContext, target: Character, result: Dictionary) -> Dictionary:
	if not result.has("save_bonus_request") or target == null:
		return result
	var record := SpellDamageRolls.failed_save_numeric_bonus_record(cast.caster, target, result)
	if record.is_empty():
		return {"success": false, "refused": true, "message": "The failed-save bonus choice is no longer available."}
	var selected_source_id := ""
	if cast.hud != null and cast.owner_label_for_character.is_valid():
		selected_source_id = await cast.hud.request_failed_save_numeric_bonus(
			cast.owner_label_for_character.call(target), str(record.get("ability", "")),
			int(record.get("save_test", {}).get("total", 0)), int(record.get("save_test", {}).get("dc", 0)), record.get("options", []), bool(record.get("provisional_saved", false))
		)
	var settled := SpellDamageRolls.settle_failed_save_numeric_bonus(cast.caster, target, result, selected_source_id)
	if settled.has("reroll_keep_request"):
		var keep_request: Dictionary = settled["reroll_keep_request"]
		var keep_choice := "old"
		if cast.hud != null:
			var keep_owner := str(cast.owner_label_for_character.call(target)) if cast.owner_label_for_character.is_valid() else target.character_name
			keep_choice = await cast.hud.request_reroll_keep_choice(keep_owner, str(keep_request.get("domain", "shared_spell_save")), int(keep_request.get("original_total", 0)), int(keep_request.get("new_total", 0)))
		settled = SpellDamageRolls.settle_failed_save_reroll_keep(settled, keep_choice)
	# The chooser can outlive the offered pool state. If its selected source is
	# stale, refuse that purchase and finish the captured roll as a decline so
	# the spell does not remain suspended with its original consequences unpaid.
	if not selected_source_id.is_empty() and bool(settled.get("refused", false)):
		var declined := SpellDamageRolls.settle_failed_save_numeric_bonus(cast.caster, target, result, "")
		if not bool(declined.get("refused", false)):
			return declined
	return settled


static func _settle_shared_spell_attack_bonus(cast: SpellCastContext, target, result: Dictionary) -> Dictionary:
	if not result.has("weapon_attack_bonus_request") or target == null:
		return result
	var record := SpellDamageRolls.weapon_attack_bonus_record(cast.caster, target, result)
	if record.is_empty():
		return {"success": false, "refused": true, "message": "The shared spell attack bonus choice is no longer available."}
	var selected_source_id := ""
	if cast.hud != null:
		var owner_label := cast.owner_label
		if cast.owner_label_for_character.is_valid():
			owner_label = str(cast.owner_label_for_character.call(cast.caster))
		selected_source_id = await cast.hud.request_weapon_attack_numeric_bonus(
			owner_label, int(record.get("context", {}).get("attack_result", {}).get("total", 0)),
			int(record.get("context", {}).get("original_target_ac", 10)), record.get("options", []), "spell attack", bool(record.get("context", {}).get("provisional_hit", false))
		)
	var settled := SpellDamageRolls.settle_weapon_attack_bonus(cast.caster, target, result, selected_source_id)
	if settled.has("reroll_keep_request"):
		var keep_request: Dictionary = settled["reroll_keep_request"]
		var keep_choice := "old"
		if cast.hud != null:
			keep_choice = await cast.hud.request_reroll_keep_choice(cast.owner_label, str(keep_request.get("domain", "shared_spell_attack")), int(keep_request.get("original_total", 0)), int(keep_request.get("new_total", 0)))
		settled = SpellDamageRolls.settle_weapon_attack_reroll_keep(settled, keep_choice)
	# As above, a stale selection must not strand the base spell attack. Decline
	# the captured request without consuming or rolling the invalid source.
	if not selected_source_id.is_empty() and bool(settled.get("refused", false)):
		var declined := SpellDamageRolls.settle_weapon_attack_bonus(cast.caster, target, result, "")
		if not bool(declined.get("refused", false)):
			return declined
	return settled


static func _settle_ordered_choices(cast: SpellCastContext, target, result: Dictionary, decisions: Dictionary) -> Dictionary:
	while result.has("roll_choice_request") or result.has("save_bonus_request") or result.has("weapon_attack_bonus_request") or result.has("damage_request") or result.has("concentration_request"):
		if result.has("weapon_attack_bonus_request"):
			var bonus_target = SpellDamageRolls.owner_target(result)
			if bonus_target == null:
				var attack_record: Dictionary = SpellDamageRolls.weapon_attack_bonus_record(cast.caster, target, result)
				bonus_target = attack_record.get("target")
			if bonus_target == null:
				return {"success": false, "refused": true, "message": "The shared spell attack bonus owner is unavailable."}
			result = await _settle_shared_spell_attack_bonus(cast, bonus_target, result)
			if bool(result.get("refused", false)):
				return result
		elif result.has("save_bonus_request"):
			var bonus_target: Variant = SpellDamageRolls.owner_target(result)
			if not bonus_target is Character:
				var bonus_record: Dictionary = SpellDamageRolls.failed_save_numeric_bonus_record(cast.caster, target if target is Character else null, result)
				bonus_target = bonus_record.get("target")
			if not bonus_target is Character:
				return {"success": false, "refused": true, "message": "The failed-save bonus owner is unavailable."}
			result = await _settle_failed_save_numeric_bonus(cast, bonus_target, result)
			if bool(result.get("refused", false)):
				return result
		elif result.has("roll_choice_request"):
			var record := SpellDamageRolls.roll_choice_record(cast.caster, result)
			if record.is_empty():
				return {"success": false, "refused": true, "message": "The spell's roll choice is no longer available."}
			var answer: Dictionary = await cast.collect_roll_token_decision.call(record["roller"], record["test_kind"], record["label"])
			result = SpellDamageRolls.settle_roll_choice(cast.caster, record["target"], result, answer)
		elif result.has("damage_request"):
			result = await _settle_empowered_spell(cast, target, result, decisions)
		else:
			result = await _settle_concentration_choice(cast, target, result, decisions)
	return result


static func _resolve_stepped_spell_cast(cast: SpellCastContext) -> void:
	var target = null
	var target_coord := cast.target_coord
	for p in cast.players:
		if p.get("hex_position") == target_coord:
			var candidate: Character = p.get("character")
			if candidate != null and (candidate.is_alive or SpellCastTargeting.can_target_downed(candidate, cast.spell)):
				target = candidate
				break
	if target == null:
		for m in cast.monsters:
			if m.get("hex_position") == target_coord and bool(m.get("is_alive", false)):
				target = m
				break
	if target == null:
		for t_hex in cast.targets:
			for p in cast.players:
				if p.get("hex_position") == t_hex:
					var candidate: Character = p.get("character")
					if candidate != null and (candidate.is_alive or SpellCastTargeting.can_target_downed(candidate, cast.spell)):
						target = candidate
						target_coord = t_hex
						break
			if target != null:
				break
			for m in cast.monsters:
				if m.get("hex_position") == t_hex and bool(m.get("is_alive", false)):
					target = m
					target_coord = t_hex
					break
			if target != null:
				break
	if target == null:
		target = {"hex_position": target_coord, "id": "coord_%d_%d" % [target_coord.x, target_coord.y]}

	var origin: Vector2i = cast.players[cast.player_index].get("hex_position", Vector2i.ZERO) if cast.players.size() > cast.player_index else Vector2i.ZERO
	var distance_feet := HexUtils.get_distance(cast.spell_origin, target_coord) * 5
	var target_spell_decisions := SpellCastResults._spell_decisions_for_target(cast, cast.counterspell_decisions, cast.counterspell_pending)
	target_spell_decisions["spell_visibility"] = {"grid": cast.grid, "caster_position": origin, "target_position": target_coord}
	target_spell_decisions["grid"] = cast.grid
	target_spell_decisions["players"] = cast.players
	target_spell_decisions["monsters"] = cast.monsters
	target_spell_decisions["cast_context"] = cast
	target_spell_decisions["hud"] = cast.hud
	target_spell_decisions["tracker"] = cast.tracker
	target_spell_decisions["trigger_enemy_defeat_features"] = cast.trigger_enemy_defeat_features
	if target is Character and cast.collect_projected_ward_decision.is_valid():
		target_spell_decisions.merge(await cast.collect_projected_ward_decision.call(target), true)

	var observers := cast.counterspell_observers if cast.counterspell_pending else []
	var res := CombatAction.resolve_spell(cast.caster, target, cast.spell, false, target_spell_decisions, observers, cast.slot_level_used, distance_feet, cast)
	res = await SpellCastResults._settle_ordered_choices(cast, target, res, target_spell_decisions)
	cast.ordered_result = res
	for step in res.get("step_results", []):
		if not step is Dictionary: continue
		for outcome in step.get("target_outcomes", []):
			if outcome is Dictionary and outcome.get("damage_components") is Array:
				cast.damage_receipts.append_array(outcome["damage_components"].duplicate(true))
	CastInterruptionRules.observe_host_result(cast, res)
	await SpellCastResults._settle_stepped_spell_actors(cast, res)

	cast.damage_dealt += int(res.get("damage", 0))
	if cast.hud != null:
		cast.hud.add_log(res.get("message", ""))
	cast.counterspell_pending = false
	if not res.get("success", true):
		cast.interrupted = true
		return
	cast.successful = true
	if cast.spell.get("concentration", false):
		cast.caster.concentrating_on["targets"].append(target)
	await SpellEffectApplication.apply(cast, target if target is Character else null, target if target is Dictionary else {}, cast.spell, origin, target_coord, res)


