## Bounded lifetime/ownership for the first shared condition-spell batch.
## Existing class conditions and other spell handlers keep their current paths.
class_name SpellEffects
extends RefCounted

const MANAGED_SPELLS := ["bless", "bane", "jump", "fly", "levitate", "spider_climb", "freedom_of_movement", "water_walk", "aid", "alter_self", "barkskin", "mage_armor", "hold_monster", "ray_of_sickness", "ray_of_enfeeblement", "animal_friendship", "charm_person", "charm_monster", "power_word_stun", "sleep", "blindness/deafness", "sunburst", "beacon_of_hope", "divine_favor", "death_ward", "sanctuary", "heroism", "magic_weapon", "enhance_ability", "faerie_fire", "invisibility", "darkvision", "see_invisibility", "true_seeing", "detect_magic", "blur", "detect_evil_and_good", "detect_poison_and_disease", "identify", "goodberry"]
const PERSISTED_AREA_MARKER_SPELLS := ["fog_cloud", "darkness", "black_tentacles", "antilife_shell", "spike_growth", "entangle", "cloud_of_daggers", "sleet_storm", "moonbeam", "wall_of_fire", "animate_objects"]

static func manages(spell: Dictionary) -> bool:
	if spell.has("execution"):
		return SharedSpell.manages(spell)
	return str(spell.get("id", "")) in MANAGED_SPELLS

static func caster_id(caster: Character) -> String:
	return caster.character_id if not caster.character_id.is_empty() else "runtime_%d" % caster.get_instance_id()

static func is_spell_source(source_id: String) -> bool:
	if source_id.begins_with("spell:"):
		return true
	var spell_id := source_id.get_slice(":", 0)
	return not spell_id.is_empty() and not DataLoader.get_spell(spell_id).is_empty()

static func begin_cast(caster: Character, spell: Dictionary) -> Dictionary:
	caster.spell_cast_serial += 1
	var owner := caster_id(caster)
	var spell_id := str(spell.get("id", ""))
	var duration := int(spell.get("duration_seconds", 60))
	if spell_id == "power_word_stun":
		duration = -1
	elif spell_id == "identify":
		duration = int(spell.get("cast_time_seconds", 60))
	var expiry_phase := "target_end" if spell_id == "sunburst" else "start"
	return {"source_id": "spell:%s:%d" % [owner, caster.spell_cast_serial], "caster_id": owner, "spell_id": str(spell.get("id", "")), "remaining_seconds": duration, "expiry_phase": expiry_phase, "save_dc": caster.get_spell_save_dc(), "concentration": bool(spell.get("concentration", false)), "end_on_target_damage": bool(spell.get("end_on_target_damage", spell.get("end_on_party_damage", false))), "end_on_any_damage": bool(spell.get("end_on_any_damage", false)), "conditions": []}

static func records(target) -> Dictionary:
	return target.spell_effects if target is Character else target.get("spell_effects", {})

static func grant(target, cast: Dictionary, condition: String, expiry_phase: String = "start", seconds: int = -1) -> void:
	if target == null or condition.is_empty():
		return
	var source := str(cast["source_id"])
	var record: Dictionary = records(target).get(source, cast.duplicate(true))
	record["expiry_phase"] = expiry_phase
	if seconds >= 0:
		record["remaining_seconds"] = seconds
	var grants: Array = record.get("conditions", [])
	if condition not in grants:
		grants.append(condition)
	record["conditions"] = grants
	CombatAction.apply_condition(target, condition, maxi(1, int(ceil(float(record["remaining_seconds"]) / 6.0))), source)
	# An immune target must not acquire a timer or become a concentration target.
	if not has_grant(target, source, condition):
		return
	if not CombatAction.has_condition(target, condition):
		CombatAction.remove_condition_source(target, source, [condition])
		return
	var all_records := records(target)
	all_records[source] = record
	if target is Dictionary:
		target["spell_effects"] = all_records

static func grant_aid(target: Character, cast: Dictionary, amount: int) -> bool:
	return SpellEffectBenefits.grant_aid(target, cast, amount)




static func grant_barkskin(target, cast: Dictionary, ac_floor: int = 17) -> bool:
	return SpellEffectBenefits.grant_barkskin(target, cast, ac_floor)




static func grant_beacon_of_hope(target, cast: Dictionary) -> bool:
	return SpellEffectBenefits.grant_beacon_of_hope(target, cast)




static func grant_divine_favor(caster: Character, cast: Dictionary) -> bool:
	return SpellEffectBenefits.grant_divine_favor(caster, cast)




static func grant_death_ward(target, cast: Dictionary) -> bool:
	return SpellEffectBenefits.grant_death_ward(target, cast)




static func grant_goodberries(caster: Character, cast: Dictionary, count: int) -> bool:
	return SpellEffectBenefits.grant_goodberries(caster, cast, count)




static func goodberry_count(caster: Character) -> int:
	return SpellEffectBenefits.goodberry_count(caster)




static func goodberry_count_for_party(casters: Array) -> int:
	return SpellEffectBenefits.goodberry_count_for_party(casters)




static func consume_goodberry_from_party(casters: Array) -> bool:
	return SpellEffectBenefits.consume_goodberry_from_party(casters)




static func grant_sanctuary(target, cast: Dictionary) -> bool:
	return SpellEffectBenefits.grant_sanctuary(target, cast)




static func grant_heroism(target: Character, cast: Dictionary, temporary_hp: int) -> bool:
	return SpellEffectBenefits.grant_heroism(target, cast, temporary_hp)




static func apply_turn_start(target) -> void:
	SpellEffectBenefits.apply_turn_start(target)




static func grant_enhance_ability(target, cast: Dictionary, ability: String) -> bool:
	return SpellEffectBenefits.grant_enhance_ability(target, cast, ability)




static func has_enhance_ability_advantage(target, ability: String) -> bool:
	return SpellEffectBenefits.has_enhance_ability_advantage(target, ability)




static func grant_magic_weapon(target: Character, cast: Dictionary, weapon_id: String, bonus: int) -> bool:
	return SpellEffectBenefits.grant_magic_weapon(target, cast, weapon_id, bonus)




static func magic_weapon_bonus(target, weapon_id: String) -> int:
	return SpellEffectBenefits.magic_weapon_bonus(target, weapon_id)




static func consume_spell(target, spell_id: String) -> void:
	for source in records(target).keys().duplicate():
		if str(records(target)[source].get("spell_id", "")) == spell_id:
			remove(target, str(source))


static func maximize_healing(target, rolled_amount: int, maximum_amount: int) -> int:
	return SpellEffectBenefits.maximize_healing(target, rolled_amount, maximum_amount)




static func effective_ac(target, base_ac: int) -> int:
	return SpellEffectBenefits.effective_ac(target, base_ac)




static func end_mage_armor_if_armored(target) -> void:
	SpellEffectBenefits.end_mage_armor_if_armored(target)



static func has_grant(target, source: String, condition: String) -> bool:
	var sources: Dictionary = target.condition_sources if target is Character else target.get("condition_sources", {})
	return sources.get(condition, {}).has(source)

static func remove(target, source: String) -> void:
	var all_records := records(target)
	if not all_records.has(source):
		return
	var record: Dictionary = all_records[source]
	CombatAction.remove_condition_source(target, source, record.get("conditions", []))
	var aid_bonus := maxi(0, int(record.get("aid_hp_bonus", 0)))
	if aid_bonus > 0 and target is Character:
		target.max_hp = maxi(1, target.max_hp - aid_bonus)
		target.current_hp = mini(target.current_hp, target.max_hp)
	all_records.erase(source)
	if target is Dictionary:
		target["spell_effects"] = all_records
		if not has_spell(target, "animal_friendship"):
			target.erase("animal_friendship_caster_ids")

static func has_spell(target, spell_id: String) -> bool:
	for record in records(target).values():
		if str(record.get("spell_id", "")) == spell_id:
			return true
	return false

static func _advance(target, source: String, seconds: int) -> void:
	var record: Dictionary = records(target)[source]
	if int(record.get("remaining_seconds", 0)) < 0:
		return # Repeat-save spells can persist until their own rules end the grant.
	var remaining := int(record["remaining_seconds"]) - seconds
	if remaining <= 0:
		remove(target, source)
		return
	record["remaining_seconds"] = remaining
	var sources: Dictionary = target.condition_sources if target is Character else target.get("condition_sources", {})
	var conditions: Dictionary = target.conditions if target is Character else target.get("conditions", {})
	for condition in record["conditions"]:
		if not has_grant(target, source, str(condition)):
			continue
		sources[condition][source] = maxi(1, int(ceil(float(remaining) / 6.0)))
		conditions[condition] = int(sources[condition].values().max())

static func tick_boundary(targets: Array, owner: String, phase: String) -> void:
	for target in targets:
		for source in records(target).keys():
			var record: Dictionary = records(target)[source]
			if str(record["caster_id"]) == owner and str(record["expiry_phase"]) == phase:
				_advance(target, str(source), 6)

static func advance_time(targets: Array, elapsed_seconds: int) -> void:
	if elapsed_seconds <= 0:
		return
	for target in targets:
		for source in records(target).keys():
			_advance(target, str(source), elapsed_seconds)
	var casters: Array = targets.filter(func(target): return target is Character)
	reconcile(casters, targets)

static func end_concentration(caster: Character, targets: Array) -> bool:
	AnimatedObjectRules.end_source(caster.character_id, str(caster.concentrating_on.get("effect_source", "")))
	GameManager.clear_room_area_concentration(caster)
	var source := str(caster.concentrating_on.get("effect_source", ""))
	if source.is_empty():
		return false
	for target in targets:
		remove(target, source)
	caster.concentrating_on.clear()
	return true

## Rebuild live references from stable source IDs; only this batch is managed.
static func prune(target) -> void:
	for source in records(target).keys():
		var record: Dictionary = records(target)[source]
		if str(record.get("spell_id", "")) in ["beacon_of_hope", "divine_favor", "death_ward", "sanctuary", "heroism", "magic_weapon", "enhance_ability"]:
			continue # This benefit is represented by the source record, not a condition.
		if str(record.get("spell_id", "")) == "identify" and record.has("identify_target"):
			continue # This record tracks concentration during its one-minute casting.
		if str(record.get("spell_id", "")) in PERSISTED_AREA_MARKER_SPELLS and bool(record.get("concentration", false)) and record["conditions"].is_empty():
			continue # The saved source marker owns a transferred area zone.
		if str(record.get("spell_id", "")) == "goodberry" and int(record.get("berries_remaining", 0)) > 0:
			continue # Remaining berries are tracked on their owning spell record.
		if str(record.get("spell_id", "")) == "aid" and int(record.get("aid_hp_bonus", 0)) > 0:
			continue
		record["conditions"] = record["conditions"].filter(func(condition): return has_grant(target, str(source), str(condition)))
		if record["conditions"].is_empty() and not record.has("aid_hp_bonus") and not record.has("ac_floor"):
			remove(target, str(source))

static func reconcile(casters: Array, targets: Array) -> void:
	var owners: Dictionary = {}
	for caster: Character in casters:
		owners[caster_id(caster)] = caster
	for target in targets:
		prune(target)
		for source in records(target).keys():
			var record: Dictionary = records(target)[source]
			var owner: Character = owners.get(str(record["caster_id"]))
			if bool(record["concentration"]) and (owner == null or str(owner.concentrating_on.get("effect_source", "")) != source):
				remove(target, str(source))
	for caster: Character in casters:
		var source := str(caster.concentrating_on.get("effect_source", ""))
		if source.is_empty():
			continue
		if not caster.is_alive or CombatAction.is_incapacitated(caster):
			end_concentration(caster, targets)
			continue
		var caster_record: Dictionary = records(caster).get(source, {})
		if str(caster_record.get("spell_id", "")) in PERSISTED_AREA_MARKER_SPELLS and caster_record["conditions"].is_empty():
			# The source record belongs to the caster but is not a creature target.
			# Keep Concentration without storing a self-reference in `targets`.
			caster.concentrating_on["targets"] = []
			continue
		var held: Array = []
		for target in targets:
			if records(target).has(source):
				held.append(target)
		if held.is_empty():
			end_concentration(caster, targets)
		else:
			caster.concentrating_on["targets"] = held

## Monsters have no persistent campaign identity. Their effects end with the
## encounter; surviving party effects keep their seconds and stable caster ID.
static func finish_encounter(casters: Array, targets: Array) -> void:
	for target in targets:
		if target is Dictionary:
			for source in records(target).keys():
				remove(target, str(source))
	var party_targets: Array = targets.filter(func(target): return target is Character)
	reconcile(casters, party_targets)

static func saved_concentration(caster: Character) -> Dictionary:
	return SpellEffectPersistence.saved_concentration(caster)



static func saved_state_error(dto: Dictionary) -> String:
	return SpellEffectPersistence.saved_state_error(dto)



static func saved_party_error(characters: Dictionary) -> String:
	return SpellEffectPersistence.saved_party_error(characters)


