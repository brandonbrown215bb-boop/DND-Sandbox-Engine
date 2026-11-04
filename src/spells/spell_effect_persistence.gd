## Validation and plain save records for source-owned spell effects.
class_name SpellEffectPersistence
extends RefCounted

static func saved_concentration(caster: Character) -> Dictionary:
	if str(caster.concentrating_on.get("effect_source", "")).is_empty():
		return {}
	var saved := caster.concentrating_on.duplicate()
	saved.erase("targets")
	return saved


static func saved_state_error(dto: Dictionary) -> String:
	var state: Variant = dto.get("spell_effects", {})
	var sources: Variant = dto.get("condition_sources", {})
	var concentration: Variant = dto.get("spell_concentration", {})
	if not state is Dictionary or not sources is Dictionary or not concentration is Dictionary:
		return "invalid saved spell effect state"
	for condition in sources:
		if not condition is String or not sources[condition] is Dictionary:
			return "invalid saved condition sources"
		for source in sources[condition]:
			var value: Variant = sources[condition][source]
			var permanent_sight_rot: bool = condition == "blinded" and str(source) == "disease:sight_rot" and (value is int or value is float) and float(value) == -1.0
			if not source is String or not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)) or (int(value) <= 0 and not permanent_sight_rot and not _until_dispelled_source(state, source, value)):
				return "invalid saved condition source duration"
	var serial: Variant = dto.get("spell_cast_serial", 0)
	if not (serial is int or serial is float) or not is_finite(float(serial)) or float(serial) != floor(float(serial)) or int(serial) < 0:
		return "invalid saved spell cast serial"
	var projection_state_error := ActorProjectionRules.saved_state_error(dto)
	if not projection_state_error.is_empty(): return projection_state_error
	var carrier_error := SourceBenefitRules.saved_cast_error(dto)
	if not carrier_error.is_empty(): return carrier_error
	for source in state:
		var record: Variant = state[source]
		if not source is String or not record is Dictionary:
			return "invalid saved spell effect record"
		var spell_id := str(record.get("spell_id", ""))
		if str(record.get("source_id", "")) != source or str(record.get("caster_id", "")).is_empty() or (not SpellEffects.manages(DataLoader.get_spell(spell_id)) and spell_id not in SpellEffects.PERSISTED_AREA_MARKER_SPELLS):
			return "invalid saved spell effect identity"
		if record.has("source_end_rules") or SpellEffects.damage_budget_cap(DataLoader.get_spell(spell_id)) > 0:
			var definition := DataLoader.get_spell(spell_id)
			var end_rules_error := SharedSpell.source_end_rules_error(record.get("source_end_rules"))
			if not SharedSpell.uses(definition) or not definition.has("source_end_rules") or record.get("source_end_rules") != definition["source_end_rules"] or not end_rules_error.is_empty():
				return "invalid saved spell source end rules"
		var damage_budget_cap := 0
		for end_rule in record.get("source_end_rules", []):
			if end_rule is Dictionary and end_rule.has("damage_budget"):
				damage_budget_cap = int(end_rule.get("damage_budget", 0))
				break
		if damage_budget_cap > 0:
			var damage_total: Variant = record.get("damage_budget_total", null)
			if not (damage_total is int or damage_total is float) or not is_finite(float(damage_total)) or float(damage_total) != floor(float(damage_total)) or int(damage_total) < 0 or int(damage_total) >= damage_budget_cap:
				return "invalid saved damage budget"
		elif record.has("damage_budget_total"):
			return "unexpected saved damage budget"
		# Legacy records captured before the field existed may omit it.
		if record.has("end_aftermath") and (record["end_aftermath"] != DataLoader.get_spell(spell_id).get("end_aftermath", null) or not SourceEndAftermathRules.validate(record["end_aftermath"]).is_empty()):
			return "invalid saved spell end aftermath"
		var remaining: Variant = record.get("remaining_seconds", null)
		var indefinite_power_word_stun := str(record.get("spell_id", "")) == "power_word_stun" and (remaining is int or remaining is float) and float(remaining) == -1.0
		# A higher-slot tier authored as -1 lasts until dispelled; older saves never carry the flag.
		if record.has("until_dispelled") and (not record["until_dispelled"] is bool or not bool(record["until_dispelled"]) or not (remaining is int or remaining is float) or float(remaining) != -1.0 or not DataLoader.get_spell(spell_id).get("duration_by_slot", []).any(func(tier): return tier is Dictionary and int(tier.get("duration_seconds", 0)) == -1)):
			return "invalid saved until-dispelled duration"
		indefinite_power_word_stun = indefinite_power_word_stun or bool(record.get("until_dispelled", false))
		if not (remaining is int or remaining is float) or not is_finite(float(remaining)) or float(remaining) != floor(float(remaining)) or (int(remaining) <= 0 and not indefinite_power_word_stun) or int(remaining) > 172800:
			return "invalid saved spell effect duration"
		var saved_phase := str(record.get("expiry_phase", ""))
		var recipient_phase := saved_phase in ["recipient_start", "recipient_end"] and not str(record.get("recipient_id", "")).is_empty()
		if (saved_phase not in ["start", "end"] and not recipient_phase) or not record.get("conditions", null) is Array:
			return "invalid saved spell effect boundary"
		# A saved magnitude is an authored benefit, not a free value in the global range.
		if record.has("condition_amounts"):
			var saved_amounts: Variant = record["condition_amounts"]
			if not saved_amounts is Dictionary: return "invalid saved condition amounts"
			for amount_condition in saved_amounts:
				var amount_range: Array = SharedSpell.AMOUNT_CONDITIONS.get(str(amount_condition), [])
				var amount_value: Variant = saved_amounts[amount_condition]
				if amount_range.is_empty() or amount_condition not in record["conditions"] or not (amount_value is int or amount_value is float) or not is_finite(float(amount_value)) or float(amount_value) != floor(float(amount_value)) or int(amount_value) < int(amount_range[0]) or int(amount_value) > int(amount_range[1]) or not _declares_condition_amount(DataLoader.get_spell(spell_id), str(amount_condition), int(amount_value)):
					return "invalid saved condition amounts"
		for condition in record["conditions"]:
			if SharedSpell.AMOUNT_CONDITIONS.has(str(condition)) and not record.get("condition_amounts", {}).has(condition):
				return "missing saved condition amount"
		if record.has("attitude_scope_ids"):
			var scope: Variant = record["attitude_scope_ids"]
			if not scope is Array or scope.size() > 100:
				return "invalid saved attitude scope"
			var scoped_condition := false
			for condition in record["conditions"]:
				if CombatAction.condition_rule(str(condition), "attitude_indifferent") and _declares_condition(DataLoader.get_spell(spell_id), str(condition)): scoped_condition = true
			if not scoped_condition: return "undeclared saved attitude scope"
			var seen_scope := {}
			for id in scope:
				if not id is String or id.is_empty() or id != id.strip_edges() or id.length() > 512 or id.contains("\n") or id.contains("\r") or id.contains("\t") or seen_scope.has(id):
					return "invalid saved attitude scope"
				seen_scope[id] = true
		var save_dc: Variant = record.get("save_dc", null)
		var repeat_definition := DataLoader.get_spell(spell_id)
		# Only old, unstaged default-turn definitions may omit history entirely.
		var requires_repeat_history := SharedSpell.uses(repeat_definition) and (repeat_definition.has("repeat_save_schedule") or repeat_definition.has("repeat_save_stages") or repeat_definition.has("repeat_save_dc_progression"))
		if requires_repeat_history or record.has("repeat_save_schedule") or record.has("repeat_save_attempts") or record.has("repeat_save_stages") or record.has("repeat_save_dc_progression") or record.has("repeat_save_context") or record.has("repeat_save_purpose"):
			for field in ["repeat_save_schedule", "repeat_save_attempts", "repeat_save_dc_adjustment", "repeat_save_stage_index", "repeat_save_stage_successes", "repeat_save_context", "repeat_save_purpose", "recipient_id"]:
				if not record.has(field): return "incomplete saved repeat-save state"
			var definition := DataLoader.get_spell(spell_id)
			var schedule := str(record.get("repeat_save_schedule", ""))
			var attempts: Variant = record.get("repeat_save_attempts", null)
			var adjustment: Variant = record.get("repeat_save_dc_adjustment", null)
			var stage_index: Variant = record.get("repeat_save_stage_index", null)
			var stage_successes: Variant = record.get("repeat_save_stage_successes", null)
			var expected_stages: Array = definition.get("repeat_save_stages", [])
			var is_integer := func(value): return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))
			var expected_context: Dictionary = definition.get("save_context", {})
			var expected_purpose := str(expected_context.get("purpose_id", "repeat_save"))
			if not SharedSpell.uses(definition) or not definition.has("repeat_save") or schedule not in ["target_turn_end", "elapsed_seconds"] or schedule != str(definition.get("repeat_save_schedule", "target_turn_end")) or not is_integer.call(attempts) or int(attempts) < 0 or int(attempts) > 100000 or not is_integer.call(adjustment) or int(adjustment) < 0 or int(adjustment) > 100 or not is_integer.call(stage_index) or not is_integer.call(stage_successes) or str(record.get("recipient_id", "")) != str(dto.get("character_id", dto.get("id", ""))) or record.get("repeat_save_context", {}) != expected_context or str(record.get("repeat_save_purpose", "")) != expected_purpose:
				return "invalid saved repeat-save state"
			if schedule == "elapsed_seconds":
				var next_at: Variant = record.get("repeat_save_next_at_seconds", null)
				if not is_integer.call(next_at) or int(next_at) < 0 or int(next_at) > 2147483647: return "invalid saved repeat-save deadline"
			elif record.has("repeat_save_next_at_seconds"):
				return "turn-based repeat save cannot have a clock deadline"
			if record.get("repeat_save_stages", []) != expected_stages or record.get("repeat_save_dc_progression", {}) != definition.get("repeat_save_dc_progression", {}):
				return "saved repeat-save rules do not match the loaded definition"
			if expected_stages.is_empty():
				if int(stage_index) != 0 or int(stage_successes) != 0: return "saved repeat-save has an invalid stage cursor"
			else:
				if int(stage_index) < 0 or int(stage_index) >= expected_stages.size() or int(stage_successes) < 0 or int(stage_successes) >= int(expected_stages[int(stage_index)].get("successes_required", 1)) or record.get("conditions", []) != [str(expected_stages[int(stage_index)].get("condition", ""))]:
					return "saved repeat-save has an invalid stage cursor"
			var progression: Dictionary = definition.get("repeat_save_dc_progression", {})
			if int(adjustment) > int(progression.get("maximum", 0)): return "saved repeat-save DC adjustment exceeds its rule"
		elif record.has("repeat_save_next_at_seconds") or record.has("repeat_save_dc_adjustment") or record.has("repeat_save_stage_index") or record.has("repeat_save_stage_successes"):
			return "incomplete saved repeat-save state"
		var aid_value: Variant = record.get("aid_hp_bonus", 0)
		var barkskin_floor: Variant = record.get("ac_floor", null)
		var berry_count: Variant = record.get("berries_remaining", null)
		var valid_aid_bonus: bool = (aid_value is int or aid_value is float) and is_finite(float(aid_value)) and float(aid_value) == floor(float(aid_value)) and int(aid_value) > 0 and int(aid_value) <= 1000
		var valid_aid_record: bool = str(record.get("spell_id", "")) == "aid" and valid_aid_bonus
		var valid_barkskin_floor: bool = (barkskin_floor is int or barkskin_floor is float) and is_finite(float(barkskin_floor)) and float(barkskin_floor) == floor(float(barkskin_floor)) and int(barkskin_floor) == 17 and str(record.get("spell_id", "")) == "barkskin"
		var valid_barkskin_record: bool = str(record.get("spell_id", "")) == "barkskin" and valid_barkskin_floor and record["conditions"].is_empty()
		var valid_goodberry_count: bool = (berry_count is int or berry_count is float) and is_finite(float(berry_count)) and float(berry_count) == floor(float(berry_count)) and int(berry_count) > 0 and int(berry_count) <= 10
		var valid_goodberry_record: bool = str(record.get("spell_id", "")) == "goodberry" and valid_goodberry_count and record["conditions"].is_empty() and not bool(record.get("concentration", true))
		var identify_target: Variant = record.get("identify_target", null)
		var identify_kind := str(identify_target.get("kind", "")) if identify_target is Dictionary else ""
		var valid_identify_target := identify_target is Dictionary and ((identify_kind == "item" and not str(identify_target.get("item_id", "")).is_empty()) or (identify_kind == "creature" and not str(identify_target.get("target_id", "")).is_empty()))
		var valid_identify_record: bool = str(record.get("spell_id", "")) == "identify" and valid_identify_target and record["conditions"].is_empty() and bool(record.get("concentration", false))
		var valid_area_marker_record: bool = str(record.get("spell_id", "")) in SpellEffects.PERSISTED_AREA_MARKER_SPELLS and record["conditions"].is_empty() and bool(record.get("concentration", false))
		var link_value: Variant = record.get("damage_link", null)
		var valid_damage_link: bool = link_value is Dictionary and str(record.get("recipient_id", "")) == str(dto.get("character_id", "")) and str(record.get("recipient_id", "")) != str(record.get("caster_id", "")) and DamageLinkRules.link_error(link_value).is_empty() and _definition_has_damage_link(DataLoader.get_spell(spell_id), link_value)
		if record.has("damage_link") and not valid_damage_link: return "invalid saved damage link"
		var response: Variant = record.get("damage_response", null)
		var valid_response: bool = response is Dictionary and str(source).begins_with("spell:%s:" % str(record.get("caster_id", ""))) and str(record.get("recipient_id", "")) == str(dto.get("character_id", "")) and DamageResponseRules.policy_error(response).is_empty() and DamageResponseRules.definition_has_policy(DataLoader.get_spell(spell_id), response)
		if record.has("damage_response") and not valid_response: return "invalid saved damage response"
		var max_hp_link_error := MaxHpSourceRules.saved_link_error(dto, str(source), record)
		if not max_hp_link_error.is_empty(): return max_hp_link_error
		if record.has("projection"):
			var projection_error := ActorProjectionRules.saved_record_error(dto, record)
			if not projection_error.is_empty(): return projection_error
		if record.has("created_actors"):
			var created_error := CreatedActorRules.saved_record_error(dto, record)
			if not created_error.is_empty(): return created_error
		for transient in ["_damage_cause", "countereffect_receipts", "replacement_receipts", "_response_depth"]:
			if record.has(transient): return "transient damage response state cannot be saved"
		if not (save_dc is int or save_dc is float) or not is_finite(float(save_dc)) or float(save_dc) != floor(float(save_dc)) or int(save_dc) < 0 or int(save_dc) > 100 or not record.get("concentration", null) is bool or (record["conditions"].is_empty() and not valid_aid_record and not valid_barkskin_record and not valid_goodberry_record and not valid_identify_record and not valid_area_marker_record and not record.has("source_benefits") and not record.has("created_actors") and not record.has("projection") and not record.has("magic_suppression") and not record.has("max_hp_source") and not valid_damage_link and not valid_response and damage_budget_cap <= 0):
			return "invalid saved spell effect rules"
		if record.has("aid_hp_bonus") and (not valid_aid_record or str(record.get("spell_id", "")) != "aid"):
			return "invalid saved Aid bonus"
		if record.has("ac_floor") and not valid_barkskin_floor:
			return "invalid saved Barkskin AC floor"
		if record.has("berries_remaining") and not valid_goodberry_record:
			return "invalid saved Goodberry pool"
		if record.has("identify_target") and not valid_identify_record:
			return "invalid saved Identify casting target"
		for condition in record["conditions"]:
			if not condition is String or not sources.get(condition, {}) is Dictionary or not sources.get(condition, {}).has(source):
				return "saved spell effect lacks its condition source"
			var definition := DataLoader.get_spell(spell_id)
			var declares_condition := false
			if SharedSpell.uses(definition):
				for eff in definition.get("effects", []):
					if eff is Dictionary and eff.get("type", "") in ["grant_condition", "bind_tether"] and (eff.get("condition", "") == condition or condition in eff.get("condition_options", [])): # S-168 tethers grant their declared condition.
						declares_condition = true
						break
				if not declares_condition:
					for step in definition.get("steps", []):
						if step is Dictionary:
							for eff in step.get("effects", []):
								if eff is Dictionary and eff.get("type", "") == "grant_condition" and eff.get("condition", "") == condition:
									declares_condition = true
									break
				if not declares_condition:
					for stage in definition.get("repeat_save_stages", []):
						if stage is Dictionary and str(stage.get("condition", "")) == str(condition):
							declares_condition = true
							break
				if not declares_condition:
					return "saved shared spell has an undeclared condition"
	if not concentration.is_empty() and (str(concentration.get("effect_source", "")).is_empty() or (not SpellEffects.manages(DataLoader.get_spell(str(concentration.get("spell_id", "")))) and str(concentration.get("spell_id", "")) not in SpellEffects.PERSISTED_AREA_MARKER_SPELLS)):
		return "invalid saved spell concentration"
	return ""


static func _definition_has_damage_link(definition: Dictionary, expected: Dictionary) -> bool:
	if not SharedSpell.uses(definition): return false
	for effect in definition.get("effects", []):
		if effect is Dictionary and str(effect.get("type", "")) == "grant_damage_link" and effect.get("policy", {}) == expected:
			return true
	for step in definition.get("steps", []):
		if not step is Dictionary: continue
		for effect in step.get("effects", []):
			if effect is Dictionary and str(effect.get("type", "")) == "grant_damage_link" and effect.get("policy", {}) == expected:
				return true
	return false


static func saved_party_error(characters: Dictionary, save_data: Dictionary = {}) -> String:
	var tether_error := TetherRules.saved_party_error(characters, save_data)
	if not tether_error.is_empty(): return tether_error
	for dto in characters.values():
		for source in dto.get("spell_effects", {}):
			var record: Dictionary = dto["spell_effects"][source]
			var owner := str(record["caster_id"])
			if record.has("damage_budget_total") and not characters.get(owner, {}).get("spell_effects", {}).has(source): return "saved damage budget lacks its exact owner"
			var object_tether := str(source).begins_with("object_tether:%s:" % owner)
			if not characters.has(owner) or (not str(source).begins_with("spell:%s:" % owner) and not object_tether):
				return "saved spell effect references a missing caster"
			var serial := str(source).get_slice(":", 2) if object_tether else str(source).get_slice(":", str(source).get_slice_count(":") - 1)
			if not serial.is_valid_int() or int(serial) <= 0 or int(serial) > int(characters[owner].get("spell_cast_serial", 0)):
				return "saved spell effect has an invalid cast identity"
			if object_tether and save_data.is_empty(): return "saved object tether lacks its room record"
	return ""


static func _declares_condition_amount(definition: Dictionary, condition: String, amount: int) -> bool:
	var effects: Array = definition.get("effects", []).duplicate()
	for step in definition.get("steps", []):
		if step is Dictionary: effects.append_array(step.get("effects", []))
	for effect in effects:
		if effect is Dictionary and str(effect.get("type", "")) == "grant_condition" and str(effect.get("condition", "")) == condition and effect.get("amount") == amount:
			return true
	return false


static func _declares_condition(definition: Dictionary, condition: String) -> bool:
	var effects: Array = definition.get("effects", []).duplicate()
	for step in definition.get("steps", []):
		if step is Dictionary: effects.append_array(step.get("effects", []))
	for effect in effects:
		if effect is Dictionary and str(effect.get("type", "")) == "grant_condition" and (str(effect.get("condition", "")) == condition or condition in effect.get("condition_options", [])):
			return true
	return false




## An until-dispelled spell source keeps its granted conditions at duration -1.
static func _until_dispelled_source(state, source, value) -> bool:
	if not state is Dictionary or not (value is int or value is float) or float(value) != -1.0: return false
	var record: Variant = state.get(source, {})
	return record is Dictionary and record.get("until_dispelled", false) is bool and bool(record.get("until_dispelled", false))
