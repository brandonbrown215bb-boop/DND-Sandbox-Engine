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
			if not source is String or not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)) or (int(value) <= 0 and not permanent_sight_rot):
				return "invalid saved condition source duration"
	var serial: Variant = dto.get("spell_cast_serial", 0)
	if not (serial is int or serial is float) or not is_finite(float(serial)) or float(serial) != floor(float(serial)) or int(serial) < 0:
		return "invalid saved spell cast serial"
	for source in state:
		var record: Variant = state[source]
		if not source is String or not record is Dictionary:
			return "invalid saved spell effect record"
		var spell_id := str(record.get("spell_id", ""))
		if str(record.get("source_id", "")) != source or str(record.get("caster_id", "")).is_empty() or (not SpellEffects.manages(DataLoader.get_spell(spell_id)) and spell_id not in SpellEffects.PERSISTED_AREA_MARKER_SPELLS):
			return "invalid saved spell effect identity"
		var remaining: Variant = record.get("remaining_seconds", null)
		var indefinite_power_word_stun := str(record.get("spell_id", "")) == "power_word_stun" and (remaining is int or remaining is float) and float(remaining) == -1.0
		if not (remaining is int or remaining is float) or not is_finite(float(remaining)) or float(remaining) != floor(float(remaining)) or (int(remaining) <= 0 and not indefinite_power_word_stun) or int(remaining) > 172800:
			return "invalid saved spell effect duration"
		if str(record.get("expiry_phase", "")) not in ["start", "end"] or not record.get("conditions", null) is Array:
			return "invalid saved spell effect boundary"
		var save_dc: Variant = record.get("save_dc", null)
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
		if not (save_dc is int or save_dc is float) or not is_finite(float(save_dc)) or float(save_dc) != floor(float(save_dc)) or int(save_dc) < 0 or int(save_dc) > 100 or not record.get("concentration", null) is bool or (record["conditions"].is_empty() and not valid_aid_record and not valid_barkskin_record and not valid_goodberry_record and not valid_identify_record and not valid_area_marker_record):
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
					if eff is Dictionary and eff.get("type", "") == "grant_condition" and eff.get("condition", "") == condition:
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
					return "saved shared spell has an undeclared condition"
	if not concentration.is_empty() and (str(concentration.get("effect_source", "")).is_empty() or (not SpellEffects.manages(DataLoader.get_spell(str(concentration.get("spell_id", "")))) and str(concentration.get("spell_id", "")) not in SpellEffects.PERSISTED_AREA_MARKER_SPELLS)):
		return "invalid saved spell concentration"
	return ""


static func saved_party_error(characters: Dictionary) -> String:
	for dto in characters.values():
		for source in dto.get("spell_effects", {}):
			var record: Dictionary = dto["spell_effects"][source]
			var owner := str(record["caster_id"])
			if not characters.has(owner) or not str(source).begins_with("spell:%s:" % owner):
				return "saved spell effect references a missing caster"
			var serial := str(source).get_slice(":", str(source).get_slice_count(":") - 1)
			if not serial.is_valid_int() or int(serial) <= 0 or int(serial) > int(characters[owner].get("spell_cast_serial", 0)):
				return "saved spell effect has an invalid cast identity"
	return ""


