## Spell damage/healing scaling, damage rolls, rerolls and settlement.
class_name SpellDamageRolls
extends RefCounted

static func spell_damage_formula(caster: Character, spell_data: Dictionary, slot_level: int = 0) -> String:
	var formula := str(spell_data.get("damage", "0"))
	if caster == null:
		return formula
	var base_level := int(spell_data.get("level", 0))
	if base_level == 0:
		var scaling: Dictionary = spell_data.get("scaling", {})
		var thresholds: Array[int] = []
		for threshold in scaling:
			if str(threshold).is_valid_int():
				thresholds.append(int(threshold))
		thresholds.sort()
		for threshold in thresholds:
			if caster.level >= threshold:
				formula = str(scaling[str(threshold)])
	var upcast: Dictionary = spell_data.get("upcast", {})
	var extra_dice := str(upcast.get("damage_per_level", ""))
	var start_level := int(upcast.get("starting_level", base_level))
	var interval := maxi(1, int(upcast.get("levels_per_increment", 1)))
	var increments := int(maxi(0, slot_level - start_level) / interval)
	if increments > 0 and not extra_dice.is_empty():
		var die_pattern := RegEx.new()
		die_pattern.compile("^([0-9]*)[dD]([0-9]+)$")
		var die_match := die_pattern.search(extra_dice.replace(" ", ""))
		if die_match != null:
			var dice_per_increment := 1 if die_match.get_string(1).is_empty() else int(die_match.get_string(1))
			var sides := int(die_match.get_string(2))
			formula += " + %dd%d" % [dice_per_increment * increments, sides]
	return formula


static func spell_delayed_damage_for_resolution(caster: Character, spell_data: Dictionary, resolution: Dictionary) -> Dictionary:
	var delayed: Dictionary = spell_data.get("delayed_damage", {})
	if delayed.is_empty() or not bool(resolution.get("hit", false)):
		return {}
	var delayed_spell := spell_data.duplicate(true)
	delayed_spell["damage"] = str(delayed.get("damage", ""))
	delayed_spell["damage_type"] = str(delayed.get("damage_type", spell_data.get("damage_type", "acid")))
	return {
		"spell_id": str(spell_data.get("id", "")),
		"formula": SpellDamageRolls.spell_damage_formula(caster, delayed_spell, int(resolution.get("slot_level", spell_data.get("level", 0)))),
		"damage_type": str(delayed_spell["damage_type"]),
		"trigger": str(delayed.get("trigger", "end_of_target_next_turn"))
	}


static func spell_effects_for_slot_level(spell_data: Dictionary, slot_level: int) -> Array:
	var effects: Array = spell_data.get("effects", []).duplicate(true)
	var upcast: Dictionary = spell_data.get("upcast", {})
	var start_level := int(upcast.get("starting_level", int(spell_data.get("level", 0))))
	var healing_per_level := int(upcast.get("healing_per_level", 0))
	var extra_healing := maxi(0, slot_level - start_level) * healing_per_level
	var healing_dice_per_level := str(upcast.get("healing_dice_per_level", ""))
	var healing_increments := maxi(0, slot_level - start_level)
	var temp_hp_per_level := int(upcast.get("temporary_hp_per_level", 0))
	var extra_temp_hp := maxi(0, slot_level - start_level) * temp_hp_per_level
	var hp_per_level := int(upcast.get("hit_points_per_level", 0))
	var extra_hit_points := maxi(0, slot_level - start_level) * hp_per_level
	for index in effects.size():
		var effect_type := str(effects[index].get("type", ""))
		if effect_type == "heal" and extra_healing > 0:
			effects[index]["value"] = int(effects[index].get("value", 0)) + extra_healing
		elif effect_type == "heal" and healing_increments > 0 and not healing_dice_per_level.is_empty():
			var die_pattern := RegEx.new()
			die_pattern.compile("^([0-9]*)[dD]([0-9]+)$")
			var die_match := die_pattern.search(healing_dice_per_level.replace(" ", ""))
			if die_match != null:
				var dice_per_increment := 1 if die_match.get_string(1).is_empty() else int(die_match.get_string(1))
				var sides := int(die_match.get_string(2))
				var base_value := str(effects[index].get("value", "0"))
				effects[index]["value"] = "%s + %dd%d" % [base_value, dice_per_increment * healing_increments, sides]
		elif effect_type == "temporary_hp" and extra_temp_hp > 0:
			effects[index]["value"] = "%s + %d" % [str(effects[index].get("value", "0")), extra_temp_hp]
		elif effect_type == "aid_hp_bonus" and extra_hit_points > 0:
			effects[index]["value"] = int(effects[index].get("value", 0)) + extra_hit_points
	return effects


static func _roll_spell_damage(caster: Character, formula: String, repetitions: int, decisions: Dictionary) -> Dictionary:
	var context: Dictionary = decisions.get("spell_damage_context", {})
	# A damaging area spell rolls damage once for every target of that cast.
	if context.has("details"):
		return context["details"]
	var details := {"formula": formula, "dice_terms": [], "modifiers": [], "final_total": 0}
	for _repeat in repetitions:
		var roll := Dice.parse_dice_details(formula, {}, caster)
		details["dice_terms"].append_array(roll["dice_terms"])
		details["final_total"] = int(details["final_total"]) + int(roll["final_total"])
	if decisions.has("spell_damage_context"):
		context["details"] = details
	return details


static func _roll_sorcerous_burst_damage(caster: Character, formula: String, explode_on: int, ability: String) -> Dictionary:
	var details := Dice.parse_dice_details(formula, {}, caster)
	details["_sorcerous_burst_explode_on"] = explode_on
	details["_sorcerous_burst_extra_limit"] = maxi(0, caster.ability_scores.get_ability_modifier(ability))
	details["_sorcerous_burst_extra_rolled"] = 0
	details["_sorcerous_burst_triggered"] = []
	return SpellDamageRolls._resolve_sorcerous_burst_explosions(caster, details)


static func _resolve_sorcerous_burst_explosions(caster: Character, details: Dictionary) -> Dictionary:
	if not details.has("_sorcerous_burst_explode_on"):
		return details
	var explode_on := int(details["_sorcerous_burst_explode_on"])
	var extra_limit := int(details["_sorcerous_burst_extra_limit"])
	var extra_rolled := int(details["_sorcerous_burst_extra_rolled"])
	var triggered: Array = details["_sorcerous_burst_triggered"]
	for term_index in details.get("dice_terms", []).size():
		var term: Dictionary = details["dice_terms"][term_index]
		if int(term.get("sides", 0)) != 8 or str(term.get("label", "")).begins_with("-"):
			continue
		var index := 0
		while index < term.get("results", []).size() and extra_rolled < extra_limit:
			var trigger_key := "%d:%d" % [term_index, index]
			var is_kept := bool(term["kept"][index])
			if is_kept and int(term["results"][index]) == explode_on and not trigger_key in triggered:
				triggered.append(trigger_key)
				var should_explode := true
				while should_explode and extra_rolled < extra_limit:
					var roll := Dice.roll_single_details(8, caster)
					var result := int(roll["total"])
					var added_index: int = term["results"].size()
					term["results"].append_array(roll["rolls"])
					term["kept"].append_array(roll["kept"])
					term["count"] = term["results"].size()
					term["subtotal"] = int(term["subtotal"]) + result
					details["final_total"] = int(details["final_total"]) + result
					extra_rolled += 1
					if result == explode_on:
						var added_key := "%d:%d" % [term_index, added_index]
						triggered.append(added_key)
						should_explode = true
					else:
						should_explode = false
			index += 1
	details["_sorcerous_burst_extra_rolled"] = extra_rolled
	return details


static func _can_empower(caster: Character, decisions: Dictionary) -> bool:
	if caster == null or not bool(decisions.get("metamagic:empowered", false)):
		return false
	if not caster.has_feature("sorcerer_metamagic") or not "empowered_spell" in caster.sorcerer_metamagic_choices:
		return false
	var cha_mod := maxi(1, caster.ability_scores.get_ability_modifier("CHA"))
	var remaining: int = int(decisions.get("empowered_remaining_dice", cha_mod))
	if remaining <= 0:
		return false
	var sp_spent := bool(decisions.get("empowered_sp_spent", false))
	if not sp_spent:
		if caster.get_sorcery_points() < 1:
			var free_cost := bool(decisions.get("metamagic:arcane_apotheosis", false)) and caster.has_feature("sorcerer_arcane_apotheosis") and caster.has_condition("innate_sorcery") and not bool(caster.feature_uses.get("sorcerer_arcane_apotheosis_used_this_turn", false))
			if not free_cost:
				return false
	return true


static func _apply_empowered_spell(caster: Character, details: Dictionary, decisions: Dictionary) -> Dictionary:
	var context: Dictionary = decisions.get("spell_damage_context", {})
	if context.get("empowered_resolved", false):
		return {"details": context.get("details", details), "used": bool(context.get("empowered_used", false))}
	var indices: Array = decisions.get("metamagic:empowered_dice", [])
	var cha_mod := maxi(1, caster.ability_scores.get_ability_modifier("CHA"))
	var remaining: int = int(decisions.get("empowered_remaining_dice", cha_mod))
	var maximum := mini(remaining, cha_mod)
	var used := false
	if SpellDamageRolls._can_empower(caster, decisions) and Dice.valid_reroll_selection(details, indices, maximum):
		var sp_spent := bool(decisions.get("empowered_sp_spent", false))
		var paid := true
		if not sp_spent:
			paid = SorcererRules.spend_metamagic_cost(caster, 1, decisions)
			if paid:
				decisions["empowered_sp_spent"] = true
		if paid:
			details = Dice.reroll_selected_dice(details, indices, maximum, caster)["details"]
			used = true
			decisions["empowered_remaining_dice"] = remaining - indices.size()
	decisions.erase("metamagic:empowered_dice")
	if decisions.has("spell_damage_context"):
		context["empowered_resolved"] = true
		context["empowered_used"] = used
		context["details"] = details
	return {"details": details, "used": used}


## Delay only the damage settlement while the owner selects already-rolled dice.
## Attack/save rolls and slot charges are never repeated, and HP is not changed
## until the final roll has passed through the ordinary damage boundary.


static var _pending_requests: Dictionary = {}
static var _active_request_id_by_caster: Dictionary = {}
static var _request_counter: int = 0
static var _epoch: int = 0


## Encounter/session replacement invalidates every outstanding callback. The
## counter is never reset, so a cleared ID can not alias a later request for the
## same caster/actor.
static func clear_pending_requests() -> void:
	_pending_requests.clear()
	_active_request_id_by_caster.clear()
	_epoch += 1


## Registers the one authoritative owner record for a rolled, not-yet-applied
## damage packet. Only the request ID is ever read back from a caller payload.
static func create_damage_request(caster: Character, target, details: Dictionary, bonus: int, scale: float, damage_type: String, condition_duration: int = 1, additional_damage_packets: Array[Dictionary] = [], decisions: Dictionary = {}, base_result: Dictionary = {}) -> String:
	_request_counter += 1
	var caster_id := str(caster.get_instance_id()) if caster != null else "0"
	var request_id := "dmg_req_%d_%s_%d" % [_epoch, caster_id, _request_counter]
	var host_players = decisions.get("players", null)
	var host_monsters = decisions.get("monsters", null)
	var record := {
		"request_id": request_id,
		"kind": "damage",
		"caster": caster,
		"target": target,
		"details": details,
		"bonus": bonus,
		"scale": scale,
		"damage_type": damage_type,
		"condition_duration": condition_duration,
		"additional_damage_packets": additional_damage_packets,
		"decisions": decisions.duplicate(),
		"result_base": base_result.duplicate(false),
		"host_players": host_players,
		"host_monsters": host_monsters,
		"target_hosted": _host_contains(host_players, host_monsters, target),
		"caster_hosted": _host_contains(host_players, host_monsters, caster),
		"settled": false,
		"serial": _request_counter
	}
	_pending_requests[request_id] = record
	_active_request_id_by_caster[caster_id] = request_id
	return request_id


## Registers the one authoritative owner record for an outstanding concentration
## save reaction choice.
static func create_concentration_request(caster: Character, target: Character, dc: int, roll: int, feature: String, decisions: Dictionary = {}, base_result: Dictionary = {}, save_test: Dictionary = {}) -> String:
	_request_counter += 1
	var caster_id := str(caster.get_instance_id()) if caster != null else "0"
	var request_id := "conc_req_%d_%s_%d" % [_epoch, caster_id, _request_counter]
	var host_players = decisions.get("players", null)
	var host_monsters = decisions.get("monsters", null)
	var effective_save_test: Dictionary
	if not save_test.is_empty():
		effective_save_test = save_test.duplicate(true)
	else:
		effective_save_test = {
			"natural_roll": roll,
			"modifier": 0,
			"total": roll,
			"dc": dc,
			"success": roll >= dc
		}
	var record := {
		"request_id": request_id,
		"kind": "concentration",
		"caster": caster,
		"target": target,
		"dc": dc,
		"roll": roll,
		"feature": feature,
		"save_test": effective_save_test,
		"decisions": decisions.duplicate(),
		"result_base": base_result.duplicate(false),
		"host_players": host_players,
		"host_monsters": host_monsters,
		"target_hosted": _host_contains(host_players, host_monsters, target),
		"caster_hosted": _host_contains(host_players, host_monsters, caster),
		"settled": false,
		"serial": _request_counter
	}
	_pending_requests[request_id] = record
	_active_request_id_by_caster[caster_id] = request_id
	return request_id


## The stepped executor registers the exact suspended continuation and cast that
## own this request. Settlement reads them from here, never from the payload.
static func attach_continuation(request_id: String, continuation: Dictionary, cast) -> void:
	if request_id.is_empty() or not _pending_requests.has(request_id):
		return
	_pending_requests[request_id]["ordered_continuation"] = continuation
	_pending_requests[request_id]["cast"] = cast


static func create_roll_choice_request(cast: SpellResolutionContext, target, roller, test_kind: String, label: String, continuation: Dictionary) -> Dictionary:
	_request_counter += 1
	var caster_id := str(cast.caster.get_instance_id())
	var request_id := "roll_req_%d_%s_%d" % [_epoch, caster_id, _request_counter]
	_pending_requests[request_id] = {
		"request_id": request_id, "kind": "roll_choice", "caster": cast.caster,
		"target": target, "roller": roller, "test_kind": test_kind, "label": label,
		"decisions": cast.decisions, "cast": cast, "ordered_continuation": continuation,
		"host_players": cast.decisions.get("players"), "host_monsters": cast.decisions.get("monsters"),
		"caster_hosted": _host_contains(cast.decisions.get("players"), cast.decisions.get("monsters"), cast.caster),
		"target_hosted": _host_contains(cast.decisions.get("players"), cast.decisions.get("monsters"), target),
		"settled": false,
	}
	_active_request_id_by_caster[caster_id] = request_id
	return {"success": true, "roll_choice_request": {"request_id": request_id}, "step_results": continuation.get("step_results", [])}


static func roll_choice_record(caster: Character, result: Dictionary) -> Dictionary:
	var request: Dictionary = result.get("roll_choice_request", {})
	var record: Dictionary = _pending_requests.get(str(request.get("request_id", "")), {})
	var validation := _validate_request(caster, record.get("target"), result, "roll_choice")
	return record if bool(validation.get("valid", false)) else {}


static func settle_roll_choice(caster: Character, target, result: Dictionary, answer: Dictionary) -> Dictionary:
	var validation := _validate_request(caster, target, result, "roll_choice")
	if not bool(validation.get("valid", false)):
		return {"success": false, "refused": true, "message": str(validation.get("error", "Invalid roll choice."))}
	var record: Dictionary = validation["record"]
	var selected: Dictionary = answer.get("roll_token_replacement", {})
	if not selected.is_empty():
		var check := RollTokenRules.validate_replacement_request(selected.get("owner"), record["roller"], str(selected.get("pool_id", "")), str(selected.get("token_id", "")), record["decisions"])
		if not bool(check.get("valid", false)):
			return {"success": false, "refused": true, "message": str(check.get("reason", "Invalid token choice."))}
	_consume_request(record)
	return SharedStepExecutor.resume_roll_choice(record, selected)


## Canonical actor recorded for an outstanding request, or null when unknown/settled.
static func owner_target(result: Dictionary):
	if result.has("damage_request") and result["damage_request"] is Dictionary:
		var req_id: String = str(result["damage_request"].get("request_id", ""))
		var rec = _pending_requests.get(req_id, null)
		if rec is Dictionary and not bool(rec.get("settled", false)) and str(rec.get("kind", "")) == "damage":
			return rec.get("target")
	if result.has("concentration_request") and result["concentration_request"] is Dictionary:
		var req_id: String = str(result["concentration_request"].get("request_id", ""))
		var rec = _pending_requests.get(req_id, null)
		if rec is Dictionary and not bool(rec.get("settled", false)) and str(rec.get("kind", "")) == "concentration":
			return rec.get("target")
	return null


## Canonical identity: the live object/Dictionary itself. Matching IDs or equal
## Dictionary contents are never proof that a callback holds the owner's actor.
static func _is_canonical_actor(a, b) -> bool:
	if a == null or b == null:
		return false
	if a is Object or b is Object:
		return a is Object and b is Object and is_instance_valid(a) and is_instance_valid(b) and a == b
	return is_same(a, b)


static func _host_contains(players, monsters, actor) -> bool:
	if actor == null:
		return false
	if actor is Dictionary and monsters is Array:
		for monster in monsters:
			if is_same(monster, actor):
				return true
	if actor is Character and players is Array:
		for entry in players:
			if entry is Dictionary and entry.get("character") == actor:
				return true
	return false


## Read-only. Refuses before any HP/SP/grant or request consumption.
static func validate_damage_request(caster: Character, target, result: Dictionary) -> Dictionary:
	return _validate_request(caster, target, result, "damage")


static func _validate_request(caster: Character, target, result: Dictionary, kind: String) -> Dictionary:
	var request_key := "%s_request" % kind
	if not result.has(request_key):
		return {"valid": false, "no_op": true}
	var req = result.get(request_key)
	if not req is Dictionary:
		return {"valid": false, "error": "Invalid %s payload." % request_key}
	var request_id: String = str(req.get("request_id", ""))
	if request_id.is_empty() or not _pending_requests.has(request_id):
		return {"valid": false, "error": "Unknown or missing request ID."}
	var record: Dictionary = _pending_requests[request_id]
	if str(record.get("kind", "")) != kind:
		return {"valid": false, "error": "Request kind mismatch (expected %s request)." % kind}
	if bool(record.get("settled", false)):
		return {"valid": false, "error": "Request has already been settled."}
	var owner_caster = record.get("caster")
	var caster_id := str(owner_caster.get_instance_id()) if owner_caster is Object and is_instance_valid(owner_caster) else "0"
	var active_id: String = str(_active_request_id_by_caster.get(caster_id, ""))
	if not active_id.is_empty() and active_id != request_id:
		return {"valid": false, "error": "Request is stale; a newer request is outstanding."}
	if not _is_canonical_actor(caster, owner_caster):
		return {"valid": false, "error": "Caller caster does not match request caster."}
	if bool(record.get("caster_hosted", false)) and not _host_contains(record.get("host_players"), record.get("host_monsters"), owner_caster):
		return {"valid": false, "error": "Request caster is no longer part of the encounter."}
	if target == null:
		return {"valid": false, "error": "Target actor is missing."}
	var owner_target_actor = record.get("target")
	if not _is_canonical_actor(target, owner_target_actor):
		return {"valid": false, "error": "Target does not match request target."}
	if bool(record.get("target_hosted", false)) and not _host_contains(record.get("host_players"), record.get("host_monsters"), owner_target_actor):
		return {"valid": false, "error": "Request target is no longer part of the encounter."}
	var ordered_cont = record.get("ordered_continuation")
	if ordered_cont is Dictionary and bool(ordered_cont.get("settled", false)):
		return {"valid": false, "error": "Continuation has already been settled."}
	return {"valid": true, "record": record, "request_id": request_id}


static func _consume_request(record: Dictionary) -> void:
	record["settled"] = true
	var owner_caster = record.get("caster")
	var caster_id := str(owner_caster.get_instance_id()) if owner_caster is Object and is_instance_valid(owner_caster) else "0"
	if _active_request_id_by_caster.get(caster_id) == str(record.get("request_id", "")):
		_active_request_id_by_caster.erase(caster_id)


static func _finish_spell_damage(caster: Character, target, details: Dictionary, bonus: int, scale: float, damage_type: String, decisions: Dictionary, result: Dictionary, condition_duration: int = 1, additional_damage_packets: Array[Dictionary] = []) -> Dictionary:
	var context: Dictionary = decisions.get("spell_damage_context", {})
	if SpellDamageRolls._can_empower(caster, decisions) and bool(decisions.get("defer_empowered", false)) and not context.get("empowered_resolved", false) and not Dice.selectable_dice(details).is_empty():
		var cha_mod := maxi(1, caster.ability_scores.get_ability_modifier("CHA")) if caster != null else 1
		var max_dice := mini(int(decisions.get("empowered_remaining_dice", cha_mod)), cha_mod)
		var req_id := SpellDamageRolls.create_damage_request(caster, target, details, bonus, scale, damage_type, condition_duration, additional_damage_packets, decisions, result)
		# The payload is a display copy for the owner prompt; the registry record owns the packet.
		result["damage_request"] = {"request_id": req_id, "details": details.duplicate(true), "bonus": bonus, "scale": scale, "damage_type": damage_type, "condition_duration": condition_duration, "max_dice": max_dice}
		return result
	var metamagic := SpellDamageRolls._apply_empowered_spell(caster, details, decisions)
	details = metamagic["details"]
	details = SpellDamageRolls._resolve_sorcerous_burst_explosions(caster, details)
	var hp_before: int = target.current_hp if target is Character else int(target.get("current_hp", 0))
	var temp_hp_before: int = target.temp_hp if target is Character else int(target.get("temp_hp", 0))
	var is_alive_before: bool = target.is_alive if target is Character else bool(target.get("is_alive", true))
	var amount := int(floor(float(int(details["final_total"]) + bonus) * scale))
	var damage_occurrence_id := WardRules.next_damage_occurrence_id()
	var primary_dmg_res := CombatAction.resolve_damage(target, amount, damage_type, decisions, false, false, caster, damage_occurrence_id)
	var actual: int = int(primary_dmg_res.get("damage", 0))
	var resolved: int = int(primary_dmg_res.get("resolved", 0))
	var ward_absorbed: int = int(primary_dmg_res.get("ward_absorbed", 0))
	var ward_remaining_hp: int = int(primary_dmg_res.get("ward_remaining_hp", 0))
	var ward_projected: bool = bool(primary_dmg_res.get("ward_projected", false))
	var ward_pool_id: String = str(primary_dmg_res.get("ward_pool_id", ""))
	var ward_owner_id: String = str(primary_dmg_res.get("ward_owner_id", ""))
	var ward_messages: Array[String] = []
	if not str(primary_dmg_res.get("ward_message", "")).is_empty():
		ward_messages.append(str(primary_dmg_res["ward_message"]))
	var temp_hp_absorbed: int = int(primary_dmg_res.get("temp_hp_absorbed", 0))
	var additional_components: Array[Dictionary] = []
	for packet in additional_damage_packets:
		var packet_details: Dictionary = packet.get("details", {})
		if packet_details.is_empty():
			continue
		var packet_type := str(packet.get("type", "acid"))
		var packet_amount := int(floor(float(int(packet_details.get("final_total", 0))) * scale))
		var packet_result := CombatAction.resolve_damage(target, packet_amount, packet_type, decisions, false, false, caster, damage_occurrence_id)
		var packet_damage := int(packet_result.get("damage", 0))
		actual += packet_damage
		resolved += int(packet_result.get("resolved", 0))
		ward_absorbed += int(packet_result.get("ward_absorbed", 0))
		if int(packet_result.get("ward_absorbed", 0)) > 0:
			ward_remaining_hp = int(packet_result.get("ward_remaining_hp", ward_remaining_hp))
			ward_projected = ward_projected or bool(packet_result.get("ward_projected", false))
			if ward_pool_id.is_empty():
				ward_pool_id = str(packet_result.get("ward_pool_id", ""))
			if ward_owner_id.is_empty():
				ward_owner_id = str(packet_result.get("ward_owner_id", ""))
			if not str(packet_result.get("ward_message", "")).is_empty():
				ward_messages.append(str(packet_result["ward_message"]))
		temp_hp_absorbed += int(packet_result.get("temp_hp_absorbed", 0))
		additional_components.append({"label": str(packet.get("label", "Additional damage")), "value": packet_damage, "type": packet_type, "formula": str(packet.get("formula", "")), "roll": packet_details})
	var hp_after: int = target.current_hp if target is Character else int(target.get("current_hp", 0))
	var temp_hp_after: int = target.temp_hp if target is Character else int(target.get("temp_hp", 0))
	var is_alive_after: bool = target.is_alive if target is Character else bool(target.get("is_alive", true))
	if not str(result.get("condition", "")).is_empty():
		if not result.get("effect_cast", {}).is_empty():
			SpellEffects.grant(target, result["effect_cast"], str(result["condition"]))
		else:
			CombatAction.apply_condition(target, str(result["condition"]), condition_duration, str(result.get("condition_source", "")))
	result.erase("condition_source")
	result["damage"] = actual
	result["hp_loss"] = actual
	result["resolved"] = resolved
	result["ward_absorbed"] = ward_absorbed
	result["ward_remaining_hp"] = ward_remaining_hp
	result["ward_projected"] = ward_projected
	result["ward_pool_id"] = ward_pool_id
	result["ward_owner_id"] = ward_owner_id
	result["temp_hp_absorbed"] = temp_hp_absorbed
	result["hp_before"] = hp_before
	result["hp_after"] = hp_after
	result["temp_hp_before"] = temp_hp_before
	result["temp_hp_after"] = temp_hp_after
	result["is_alive_before"] = is_alive_before
	result["is_alive_after"] = is_alive_after
	result["critical"] = bool(decisions.get("damage_is_critical", false))
	result["damage_is_critical"] = bool(decisions.get("damage_is_critical", false))
	result["damage_roll"] = details
	result["damage_type"] = damage_type
	result["additional_damage_components"] = additional_components
	result["metamagic_used"] = bool(result.get("metamagic_used", false)) or bool(metamagic["used"])
	result["message"] = str(result["message"]).replace("{damage}", str(actual))
	if not ward_messages.is_empty():
		result["message"] += " " + " ".join(ward_messages)
	if metamagic["used"]:
		result["message"] += " Empowered Spell rerolls the selected damage dice; the new rolls stand."
	return result


## Settles one owned request exactly once. Validation is read-only and happens
## before any damage, Sorcery Point, grant or request consumption. Only the
## answer's `metamagic:empowered_dice` is accepted; the roll, actors, source,
## result base and Metamagic budget come from the registered owner record. The
## answer dictionary receives the spent/remaining budget so existing callers can
## carry it, but it can never replace owner state.
static func settle_pending_request(caster: Character, target, result: Dictionary, answer: Dictionary) -> Dictionary:
	var validation := validate_damage_request(caster, target, result)
	if not validation.get("valid", false):
		return validation
	var record: Dictionary = validation["record"]
	_consume_request(record)
	var owner_decisions: Dictionary = record["decisions"]
	var final_decisions := owner_decisions.duplicate()
	final_decisions["defer_empowered"] = false
	final_decisions.erase("metamagic:empowered_dice")
	if answer.has("metamagic:empowered_dice"):
		final_decisions["metamagic:empowered_dice"] = answer["metamagic:empowered_dice"]
	var settled := SpellDamageRolls._finish_spell_damage(record["caster"], record["target"], record["details"], int(record["bonus"]), float(record["scale"]), str(record["damage_type"]), final_decisions, record["result_base"].duplicate(false), int(record["condition_duration"]), record["additional_damage_packets"])
	for key in ["empowered_sp_spent", "empowered_remaining_dice"]:
		if final_decisions.has(key):
			owner_decisions[key] = final_decisions[key]
			answer[key] = final_decisions[key]
	var cast_ctx: SpellResolutionContext = record.get("cast")
	if cast_ctx == null and record.get("ordered_continuation") is Dictionary:
		cast_ctx = record["ordered_continuation"].get("cast")
	if cast_ctx != null:
		for key in ["empowered_sp_spent", "empowered_remaining_dice"]:
			if final_decisions.has(key):
				cast_ctx.decisions[key] = final_decisions[key]
		if final_decisions.has("spell_damage_context"):
			cast_ctx.decisions["spell_damage_context"] = final_decisions["spell_damage_context"]
		cast_ctx.decisions.erase("damage_is_critical")
		cast_ctx.decisions.erase("critical")
	return {"valid": true, "record": record, "result": settled}


## Read-only. Refuses before any state mutation or concentration loss.
static func validate_concentration_request(caster: Character, target, result: Dictionary) -> Dictionary:
	return _validate_request(caster, target, result, "concentration")


static func _is_answer_accepted(answer: Dictionary, feature: String) -> bool:
	if answer.is_empty():
		return false
	if answer.has("feature") and str(answer["feature"]) != feature:
		return false
	if answer.has(feature):
		return bool(answer[feature])
	var other_feature: String = "bardic_inspiration" if feature == "stroke_of_luck" else "stroke_of_luck"
	if answer.has(other_feature) and not answer.has(feature) and not answer.has("accepted"):
		return false
	if answer.has("accepted"):
		if answer.has(other_feature) and not answer.has(feature):
			return false
		return bool(answer["accepted"])
	return false


## Extracts an explicit, feature-specific decision for character's concentration save.
## Returns boolean if explicitly answered, or null if no decision is supplied.
static func get_concentration_decision(decisions: Dictionary, character, feature: String, caster: Character = null) -> Variant:
	if decisions.is_empty() or character == null:
		return null
	var char_id: String = character.character_id if character is Character else str(character.get("character_id", ""))

	# 1. Target-scoped concentration keys:
	if not char_id.is_empty():
		var target_keys := [
			"concentration:%s:%s" % [feature, char_id],
			"%s:%s" % [feature, char_id],
			"concentration_%s:%s" % [feature, char_id]
		]
		for k in target_keys:
			if decisions.has(k):
				return bool(decisions[k])

	# 2. General concentration-scoped keys for this feature:
	var conc_feature_keys := [
		"concentration:%s" % feature,
		"concentration_%s" % feature
	]
	for k in conc_feature_keys:
		if decisions.has(k):
			return bool(decisions[k])

	# 3. Generic concentration_choice (only if feature-specific key is not present):
	if decisions.has("concentration_choice"):
		return bool(decisions["concentration_choice"])

	# 4. Bare feature key:
	# Only accepted if character is the caster (or caster is null) AND decisions does not represent
	# an attack roll decision on the caster.
	if decisions.has(feature):
		if caster != null and caster != character:
			return null
		if decisions.has("has_attack") or decisions.has("attack_roll") or decisions.has("damage_is_critical"):
			return null
		return bool(decisions[feature])

	return null


## Settles an outstanding concentration save choice exactly once.
static func settle_pending_concentration_request(caster: Character, target, result: Dictionary, answer: Dictionary) -> Dictionary:
	var validation := validate_concentration_request(caster, target, result)
	if not validation.get("valid", false):
		return validation
	var record: Dictionary = validation["record"]
	_consume_request(record)
	var feature: String = str(record.get("feature", "stroke_of_luck"))
	var accepted: bool = _is_answer_accepted(answer, feature)
	var target_char: Character = record["target"]
	var save_test: Dictionary = record.get("save_test", {}).duplicate(true)
	var dc: int = int(record.get("dc", 10))
	var roll: int = int(record.get("roll", save_test.get("total", 0)))
	var success := false
	var cast_ctx: SpellResolutionContext = record.get("cast")
	var spell_cast_ctx: SpellCastContext = cast_ctx.decisions.get("cast_context") if cast_ctx != null else null
	var hud = cast_ctx.decisions.get("hud", spell_cast_ctx.hud if spell_cast_ctx != null else null)

	if feature == "stroke_of_luck":
		if accepted:
			var stroke := RogueRules.apply_stroke_of_luck(target_char, save_test, true)
			if stroke.get("used", false):
				save_test = stroke.get("result", save_test)
				roll = int(save_test.get("total", roll))
				success = bool(save_test.get("success", false))
				if hud != null:
					hud.add_log("%s uses Stroke of Luck on the concentration save: %d vs DC %d." % [target_char.character_name, roll, dc])
	elif feature == "bardic_inspiration":
		if accepted:
			var inspiration := BardicInspirationRules.apply_to_test(target_char, roll, dc, true)
			if inspiration.get("used", false):
				roll = int(inspiration.get("total", roll))
				success = bool(inspiration.get("success", false))
				save_test["total"] = roll
				save_test["success"] = success
				if hud != null:
					hud.add_log("%s uses Bardic Inspiration (+%d) on the concentration save: %d vs DC %d." % [target_char.character_name, int(inspiration.get("bonus", 0)), roll, dc])

	# Choice sequencing: after declining Stroke or using it but still failing, an available Bardic Inspiration choice must still be offered
	if not success and feature == "stroke_of_luck" and BardicInspirationRules.has_die(target_char):
		var next_req_id := create_concentration_request(record["caster"], target_char, dc, roll, "bardic_inspiration", record["decisions"], record.get("result_base", {}), save_test)
		var ordered_cont: Dictionary = record.get("ordered_continuation", {})
		if not ordered_cont.is_empty():
			ordered_cont["request_id"] = next_req_id
			ordered_cont["continuation_id"] = next_req_id
			attach_continuation(next_req_id, ordered_cont, record.get("cast"))
		return {
			"valid": true,
			"record": record,
			"has_next_request": true,
			"next_request_id": next_req_id,
			"next_feature": "bardic_inspiration",
			"next_roll": roll,
			"next_dc": dc,
			"save_test": save_test,
			"success": false,
			"feature": feature,
			"accepted": accepted
		}

	# All choices finished for this concentration save
	if success:
		if hud != null:
			hud.add_log("[color=green]%s maintained concentration![/color]" % target_char.character_name)
	else:
		if hud != null:
			hud.add_log("[color=red]%s failed CON save! Concentration lost.[/color]" % target_char.character_name)
		SpellEncounterLifecycle._end_concentration(spell_cast_ctx, target_char)

	return {
		"valid": true,
		"record": record,
		"has_next_request": false,
		"success": success,
		"feature": feature,
		"accepted": accepted,
		"roll": roll,
		"dc": dc,
		"save_test": save_test
	}
