## Spell-specific grants and benefit queries; lifetime and removal remain in SpellEffects.
class_name SpellEffectBenefits
extends RefCounted

static func grant_aid(target: Character, cast: Dictionary, amount: int) -> bool:
	if target == null or target.is_dead() or amount <= 0 or SpellEffects.has_spell(target, "aid"):
		return false
	var source := str(cast.get("source_id", ""))
	if source.is_empty():
		return false
	var record: Dictionary = cast.duplicate(true)
	record["conditions"] = []
	record["aid_hp_bonus"] = amount
	target.spell_effects[source] = record
	target.max_hp += amount
	target.current_hp += amount
	if target.current_hp > 0:
		target.is_alive = true
		target.death_save_successes = 0
		target.death_save_failures = 0
	return true


static func grant_barkskin(target, cast: Dictionary, ac_floor: int = 17) -> bool:
	if target == null or ac_floor <= 0:
		return false
	var source := str(cast.get("source_id", ""))
	if source.is_empty():
		return false
	var record: Dictionary = cast.duplicate(true)
	record["spell_id"] = "barkskin"
	record["remaining_seconds"] = maxi(1, int(record.get("remaining_seconds", 3600)))
	record["expiry_phase"] = str(record.get("expiry_phase", "start"))
	record["conditions"] = []
	record["ac_floor"] = ac_floor
	SpellEffects.records(target)[source] = record
	if target is Dictionary:
		target["spell_effects"] = SpellEffects.records(target)
	return true


static func grant_beacon_of_hope(target, cast: Dictionary) -> bool:
	if target == null:
		return false
	var source := str(cast.get("source_id", ""))
	if source.is_empty():
		return false
	var record: Dictionary = cast.duplicate(true)
	record["spell_id"] = "beacon_of_hope"
	record["conditions"] = []
	var all_records := SpellEffects.records(target)
	all_records[source] = record
	if target is Dictionary:
		target["spell_effects"] = all_records
	return true


static func grant_divine_favor(caster: Character, cast: Dictionary) -> bool:
	if caster == null:
		return false
	var source := str(cast.get("source_id", ""))
	if source.is_empty():
		return false
	for existing_source in caster.spell_effects.keys().duplicate():
		if str(caster.spell_effects[existing_source].get("spell_id", "")) == "divine_favor":
			SpellEffects.remove(caster, str(existing_source))
	var record: Dictionary = cast.duplicate(true)
	record["spell_id"] = "divine_favor"
	record["conditions"] = []
	caster.spell_effects[source] = record
	return true


static func grant_death_ward(target, cast: Dictionary) -> bool:
	if target == null:
		return false
	var source := str(cast.get("source_id", ""))
	if source.is_empty():
		return false
	for existing_source in SpellEffects.records(target).keys().duplicate():
		if str(SpellEffects.records(target)[existing_source].get("spell_id", "")) == "death_ward":
			SpellEffects.remove(target, str(existing_source))
	var record: Dictionary = cast.duplicate(true)
	record["spell_id"] = "death_ward"
	record["conditions"] = []
	SpellEffects.records(target)[source] = record
	if target is Dictionary:
		target["spell_effects"] = SpellEffects.records(target)
	return true


static func grant_goodberries(caster: Character, cast: Dictionary, count: int) -> bool:
	if caster == null or count <= 0:
		return false
	var source := str(cast.get("source_id", ""))
	if source.is_empty():
		return false
	var record: Dictionary = cast.duplicate(true)
	record["spell_id"] = "goodberry"
	record["conditions"] = []
	record["berries_remaining"] = count
	caster.spell_effects[source] = record
	return true


static func grant_sanctuary(target, cast: Dictionary) -> bool:
	if target == null:
		return false
	var source := str(cast.get("source_id", ""))
	if source.is_empty():
		return false
	for existing_source in SpellEffects.records(target).keys().duplicate():
		if str(SpellEffects.records(target)[existing_source].get("spell_id", "")) == "sanctuary":
			SpellEffects.remove(target, str(existing_source))
	var record: Dictionary = cast.duplicate(true)
	record["spell_id"] = "sanctuary"
	record["conditions"] = []
	SpellEffects.records(target)[source] = record
	if target is Dictionary:
		target["spell_effects"] = SpellEffects.records(target)
	return true


static func grant_heroism(target: Character, cast: Dictionary, temporary_hp: int) -> bool:
	if target == null:
		return false
	var source := str(cast.get("source_id", ""))
	if source.is_empty():
		return false
	for existing_source in target.spell_effects.keys().duplicate():
		if str(target.spell_effects[existing_source].get("spell_id", "")) == "heroism":
			SpellEffects.remove(target, str(existing_source))
	var record: Dictionary = cast.duplicate(true)
	record["spell_id"] = "heroism"
	record["conditions"] = []
	record["temporary_hp_per_turn"] = maxi(0, temporary_hp)
	target.spell_effects[source] = record
	return true


static func grant_enhance_ability(target, cast: Dictionary, ability: String) -> bool:
	if target == null or ability.to_upper() not in ["STR", "DEX", "INT", "WIS", "CHA"]:
		return false
	var source := str(cast.get("source_id", ""))
	if source.is_empty():
		return false
	var record: Dictionary = cast.duplicate(true)
	record["spell_id"] = "enhance_ability"
	record["ability"] = ability.to_upper()
	record["conditions"] = []
	SpellEffects.records(target)[source] = record
	if target is Dictionary:
		target["spell_effects"] = SpellEffects.records(target)
	return true


static func grant_magic_weapon(target: Character, cast: Dictionary, weapon_id: String, bonus: int) -> bool:
	if target == null or weapon_id.is_empty() or bonus <= 0:
		return false
	var source := str(cast.get("source_id", ""))
	if source.is_empty():
		return false
	for existing_source in target.spell_effects.keys().duplicate():
		if str(target.spell_effects[existing_source].get("spell_id", "")) == "magic_weapon":
			SpellEffects.remove(target, str(existing_source))
	var record: Dictionary = cast.duplicate(true)
	record["spell_id"] = "magic_weapon"
	record["weapon_id"] = weapon_id
	record["weapon_bonus"] = bonus
	record["conditions"] = []
	target.spell_effects[source] = record
	return true


static func goodberry_count(caster: Character) -> int:
	if caster == null:
		return 0
	var count := 0
	for record in caster.spell_effects.values():
		if record is Dictionary and str(record.get("spell_id", "")) == "goodberry":
			count += maxi(0, int(record.get("berries_remaining", 0)))
	return count


static func goodberry_count_for_party(casters: Array) -> int:
	var count := 0
	for caster in casters:
		count += SpellEffects.goodberry_count(caster as Character)
	return count


static func consume_goodberry_from_party(casters: Array) -> bool:
	var selected_caster: Character = null
	var selected_source := ""
	var soonest_expiry := 2147483647
	for candidate in casters:
		if candidate is not Character:
			continue
		for source_value in candidate.spell_effects.keys():
			var source := str(source_value)
			var record: Dictionary = candidate.spell_effects[source]
			if str(record.get("spell_id", "")) != "goodberry" or int(record.get("berries_remaining", 0)) <= 0:
				continue
			var expiry := int(record.get("remaining_seconds", 0))
			if expiry < soonest_expiry:
				soonest_expiry = expiry
				selected_caster = candidate
				selected_source = source
	if selected_caster == null or selected_source.is_empty():
		return false
	var selected_record: Dictionary = selected_caster.spell_effects[selected_source]
	selected_record["berries_remaining"] = int(selected_record["berries_remaining"]) - 1
	if int(selected_record["berries_remaining"]) <= 0:
		selected_caster.spell_effects.erase(selected_source)
	return true


static func apply_turn_start(target) -> void:
	if target is not Character:
		return
	for record in SpellEffects.records(target).values():
		if str(record.get("spell_id", "")) == "heroism":
			target.temp_hp = maxi(target.temp_hp, maxi(0, int(record.get("temporary_hp_per_turn", 0))))


static func has_enhance_ability_advantage(target, ability: String) -> bool:
	for record in SpellEffects.records(target).values():
		if str(record.get("spell_id", "")) == "enhance_ability" and str(record.get("ability", "")).to_upper() == ability.to_upper():
			return true
	return false


static func magic_weapon_bonus(target, weapon_id: String) -> int:
	for record in SpellEffects.records(target).values():
		if str(record.get("spell_id", "")) == "magic_weapon" and str(record.get("weapon_id", "")) == weapon_id:
			return int(record.get("weapon_bonus", 0))
	return 0


static func maximize_healing(target, rolled_amount: int, maximum_amount: int) -> int:
	return maxi(rolled_amount, maximum_amount) if SpellEffects.has_spell(target, "beacon_of_hope") else rolled_amount


static func effective_ac(target, base_ac: int) -> int:
	var result := base_ac
	for record in SpellEffects.records(target).values():
		if str(record.get("spell_id", "")) == "barkskin":
			result = maxi(result, int(record.get("ac_floor", 0)))
	return result


static func end_mage_armor_if_armored(target) -> void:
	for source in SpellEffects.records(target).keys().duplicate():
		if str(SpellEffects.records(target)[source].get("spell_id", "")) == "mage_armor":
			SpellEffects.remove(target, str(source))


