## Bounded reusable projections; the carrier owns identity and lifetime.
class_name SourceBenefitRules
extends RefCounted

static func benefits_error(value: Variant) -> String:
	if not value is Array or value.is_empty() or value.size() > 8:
		return "Source benefits require one to eight stat additions."
	var seen := {}
	for benefit in value:
		if not benefit is Dictionary or benefit.size() != 2 or benefit.get("stat", "") not in ["AC", "speed"]:
			return "Source benefits support only AC and speed additions."
		var amount: Variant = benefit.get("amount")
		if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) != floorf(float(amount)) or float(amount) < 1 or float(amount) > 10:
			return "Source benefit amounts must be integers from 1 to 10."
		if seen.has(benefit.stat): return "Duplicate source benefit stat."
		seen[benefit.stat] = true
	return ""

static func query(actor: Character) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if actor == null or actor.character_id.is_empty(): return result
	actor.inventory.copies.sync(actor.inventory)
	for copy_id in actor.inventory.copies.equipped.values():
		if ActorProjectionRules.merged(actor, str(copy_id)): continue # S-164 merged copies are suppressed.
		var copy: Dictionary = actor.inventory.copies.records.get(copy_id, {})
		var item := DataLoader.get_item(str(copy.get("definition_id", "")))
		if item.has("source_benefits") and (not bool(item.get("requires_attunement", false)) or copy.get("state", {}).get("attuned_to", "") == actor.character_id):
			_append(result, actor, "item", str(copy_id), str(item.id), item.source_benefits)
	for feature in actor.features:
		for effect in actor._feature_effects(feature):
			if effect.get("type", "") == "source_benefits":
				_append(result, actor, "progression", "progression:" + JSON.stringify([actor.character_id, feature.id]), str(feature.id), effect.get("benefits"))
		var choice := ClassProgression.feature_choice_effect(actor, str(feature.get("id", "")))
		var selections: Array = actor.feature_choices.get(str(feature.get("id", "")), [])
		for index in selections.size():
			for option in choice.get("options", []):
				if option.get("id", "") != selections[index]: continue
				for effect in option.get("effects", []):
					if effect.get("type", "") == "source_benefits":
						var identity := "progression:" + JSON.stringify([actor.character_id, feature.id, option.id, index])
						_append(result, actor, "progression", identity, str(option.id), effect.get("benefits"))
	for carrier in FeatureModeRules.carriers(actor):
		_append(result, actor, "mode", carrier.source_instance_id, carrier.definition_id, carrier.benefits)
	for source in actor.spell_effects:
		var record: Dictionary = actor.spell_effects[source]
		if int(record.get("remaining_seconds", 0)) > 0 and record.get("caster_id", "") == actor.character_id:
			var spell := DataLoader.get_spell(str(record.get("spell_id", "")))
			for effect in spell.get("effects", []):
				if effect.get("type", "") == "grant_source_benefits" and record.get("source_benefits", []) == effect.get("benefits", []):
					_append(result, actor, "cast", str(source), str(spell.id), effect.benefits)
	return result

static func _append(result: Array[Dictionary], actor: Character, kind: String, source: String, definition: String, benefits: Variant) -> void:
	if benefits_error(benefits).is_empty():
		result.append({"owner_id":actor.character_id, "recipient_id":actor.character_id, "source_instance_id":source, "kind":kind, "definition_id":definition, "benefits":benefits.duplicate(true)})

static func total(actor: Character, stat: String) -> int:
	var amount := 0
	for carrier in query(actor):
		for benefit in carrier.benefits:
			if benefit.stat == stat: amount += int(benefit.amount)
	return amount

static func can_dismiss(actor: Character, source: String) -> bool:
	return query(actor).any(func(carrier): return carrier.kind == "cast" and carrier.source_instance_id == source)

static func dismiss(actor: Character, source: String) -> bool:
	if not can_dismiss(actor, source): return false
	if actor.concentrating_on.get("effect_source", "") == source:
		SpellEffects.end_concentration(actor, [actor])
	else:
		SpellEffects.remove(actor, source)
	return true

static func grant(actor: Character, cast: Dictionary, benefits: Array) -> bool:
	if actor == null or cast.get("caster_id", "") != actor.character_id or not benefits_error(benefits).is_empty() or str(cast.get("source_id", "")).is_empty(): return false
	var source := str(cast.source_id)
	if actor.spell_effects.has(source): return false
	var record := cast.duplicate(true)
	record["source_benefits"] = benefits.duplicate(true)
	var concentration := {"effect_source":source, "spell_id":str(cast.get("spell_id", ""))} if bool(cast.get("concentration", false)) else {}
	if not saved_cast_error({"character_id":actor.character_id, "spell_cast_serial":actor.spell_cast_serial, "spell_effects":{source:record}, "spell_concentration":concentration}).is_empty(): return false
	actor.spell_effects[source] = record
	return true

static func saved_cast_error(dto: Dictionary) -> String:
	for record in dto.get("spell_effects", {}).values():
		if not record is Dictionary: return "Invalid source carrier record."
		var spell := DataLoader.get_spell(str(record.get("spell_id", "")))
		var declared: Array = []
		for effect in spell.get("effects", []):
			if effect.get("type", "") == "grant_source_benefits": declared = effect.get("benefits", [])
		if record.has("source_benefits") or not declared.is_empty():
			var prefix := "spell:%s:" % str(dto.get("character_id", ""))
			var identity := str(record.get("source_id", ""))
			var serial := identity.trim_prefix(prefix)
			if not identity.begins_with(prefix) or not serial.is_valid_int() or str(int(serial)) != serial or int(serial) < 1 or int(serial) > int(dto.get("spell_cast_serial", 0)):
				return "Saved source carrier has an invalid cast identity."
			if not benefits_error(record.get("source_benefits")).is_empty() or record.get("source_benefits") != declared or record.get("caster_id", "") != dto.get("character_id", "") or int(record.get("remaining_seconds", 0)) > int(spell.get("duration_seconds", 0)) or record.get("concentration") != spell.get("concentration", false) or record.get("conditions", []) != []:
				return "Saved source benefits differ from the owned self-cast definition."
			if bool(record.get("concentration", false)) and (dto.get("spell_concentration", {}).get("effect_source", "") != identity or dto.get("spell_concentration", {}).get("spell_id", "") != spell.get("id", "")):
				return "Saved source carrier lacks its matching concentration."
	var concentration: Dictionary = dto.get("spell_concentration", {})
	if SharedSpell.has_effect(DataLoader.get_spell(str(concentration.get("spell_id", ""))), "grant_source_benefits"):
		var held: Dictionary = dto.get("spell_effects", {}).get(str(concentration.get("effect_source", "")), {})
		if not bool(held.get("concentration", false)) or held.get("spell_id", "") != concentration.get("spell_id", "") or held.get("caster_id", "") != dto.get("character_id", ""):
			return "Saved concentration lacks its matching self-cast source carrier."
	return ""
