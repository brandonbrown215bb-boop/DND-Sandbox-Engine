## Focused regression checks for repeat-save timing, stages and escalation.
class_name Batch026Checks
extends RefCounted

static func _character(id: String) -> Character:
	var scores := AbilityScores.new()
	scores.from_dict({"INT": 16, "CON": 14, "WIS": 14})
	var character := Character.new()
	character.initialize(id, "human", "wizard", scores)
	character.character_id = id
	return character

static func _monster(id: String, bonus: int) -> Dictionary:
	return {"id": id, "name": id, "is_alive": true, "current_hp": 20, "max_hp": 20, "armor_class": 10, "creature_type": "humanoid", "conditions": {}, "condition_sources": {}, "spell_effects": {}, "saving_throw_bonuses": {"WIS": bonus}}

static func _cast(caster: Character, target: Dictionary, spell_id: String) -> Dictionary:
	var spell := DataLoader.get_spell(spell_id)
	var cast := SpellEffects.begin_cast(caster, spell)
	spell["_effect_cast"] = cast
	var result := CombatAction.resolve_spell(caster, target, spell, false, {}, [], int(spell["level"]), 1)
	return {"result": result, "source": str(cast["source_id"]), "spell": spell}

static func _lifecycle_context() -> SpellCastContext:
	var context := SpellCastContext.new()
	context.areas = CombatSpellZones.new()
	return context

static func run(check: Callable) -> void:
	DataLoader._load_content_type("res://data/fixtures/shared_spells/spells/", "spell")
	var staged_spell := DataLoader.get_spell("fixture:026_target_turn_staged")
	var elapsed_spell := DataLoader.get_spell("fixture:026_elapsed_repeat")
	check.call(not staged_spell.is_empty() and not elapsed_spell.is_empty() and SharedSpell.content_error(staged_spell).is_empty() and SharedSpell.content_error(elapsed_spell).is_empty(), "Batch 026 neutral scheduled-repeat fixtures load through the production validator")
	var malformed := staged_spell.duplicate(true)
	malformed["repeat_save_schedule"] = "whenever"
	check.call(not SharedSpell.content_error(malformed).is_empty(), "Batch 026 rejects an unsupported repeat-save schedule")
	malformed = staged_spell.duplicate(true)
	malformed["repeat_save_stages"][0]["successes_required"] = 0
	check.call(not SharedSpell.content_error(malformed).is_empty(), "Batch 026 rejects an unbounded/empty stage threshold")

	var caster := _character("batch026-caster")
	var target := _monster("batch026-target", -100)
	var initial := _cast(caster, target, "fixture:026_target_turn_staged")
	var sibling := _cast(caster, target, "fixture:026_target_turn_staged")
	var first_source := str(initial["source"])
	var sibling_source := str(sibling["source"])
	check.call(initial["result"].get("success", false) and sibling["result"].get("success", false) and SpellEffects.has_grant(target, first_source, "restrained") and SpellEffects.has_grant(target, sibling_source, "restrained"), "Batch 026 initial saves grant two independently owned first-stage conditions")
	SpellEncounterLifecycle._resolve_condition_spell_repeat_saves(_lifecycle_context(), target)
	var first_attempt: Dictionary = SpellEffects.records(target)[first_source]
	SpellEncounterLifecycle._resolve_condition_spell_repeat_saves(_lifecycle_context(), target)
	check.call(int(first_attempt.get("repeat_save_attempts", -1)) == 1 and int(first_attempt.get("repeat_save_dc_adjustment", 0)) == 1 and SpellEffects.records(target).has(sibling_source), "Batch 026 deduplicates a due target-turn save and escalates only its source DC")
	target["saving_throw_bonuses"]["WIS"] = 100
	var first_success := CombatAction.resolve_condition_spell_repeat_save(target, first_source)
	check.call(first_success.get("saved", false) and int(first_success.get("stage_successes", 0)) == 1 and int(first_success.get("dc_adjustment", -1)) == 0 and str(first_success.get("source_id", "")) == first_source and str(first_success.get("recipient_id", "")) == str(target.get("id", "")) and str(first_success.get("purpose_id", "")) == "escape_snare" and first_success.get("save_context", {}).get("origin_effect_id", "") == "constricting_vines" and SpellEffects.has_grant(target, first_source, "restrained"), "Batch 026 keeps the original save purpose/source/recipient through a qualifying repeat save and DC reset")
	target["saving_throw_bonuses"]["WIS"] = -100
	CombatAction.resolve_condition_spell_repeat_save(target, first_source)
	target["saving_throw_bonuses"]["WIS"] = 100
	CombatAction.resolve_condition_spell_repeat_save(target, first_source)
	CombatAction.resolve_condition_spell_repeat_save(target, first_source)
	var advanced: Dictionary = SpellEffects.records(target).get(first_source, {})
	check.call(advanced.get("conditions", []) == ["paralyzed"] and SpellEffects.has_grant(target, first_source, "paralyzed") and SpellEffects.has_grant(target, sibling_source, "restrained"), "Batch 026 transitions one source to its next condition without erasing a sibling cast")
	var ended := CombatAction.resolve_condition_spell_repeat_save(target, first_source)
	check.call(ended.get("saved", false) and not SpellEffects.records(target).has(first_source) and SpellEffects.has_grant(target, sibling_source, "restrained"), "Batch 026 ends the exact staged source after its final qualifying save")

	var clock_before := int(GameManager.campaign_elapsed_seconds)
	var clock_target := _monster("batch026-clock-target", -100)
	var clock_cast := _cast(caster, clock_target, "fixture:026_elapsed_repeat")
	var clock_source := str(clock_cast["source"])
	var base_dc := int(SpellEffects.records(clock_target)[clock_source].get("save_dc", 0))
	SpellEncounterLifecycle._resolve_condition_spell_repeat_saves(_lifecycle_context(), clock_target)
	check.call(int(SpellEffects.records(clock_target)[clock_source].get("repeat_save_attempts", -1)) == 0, "Batch 026 elapsed-time saves do not fire from the unrelated target-turn-end hook")
	GameManager.campaign_elapsed_seconds = clock_before + 12
	SpellEffects.advance_time([clock_target], 12)
	var after_jump: Dictionary = SpellEffects.records(clock_target).get(clock_source, {})
	check.call(int(after_jump.get("repeat_save_attempts", 0)) == 2 and int(after_jump.get("repeat_save_next_at_seconds", -1)) == clock_before + 18 and int(after_jump.get("repeat_save_dc_adjustment", 0)) == 4 and int(after_jump.get("remaining_seconds", 0)) == 588, "Batch 026 resolves each elapsed-time deadline once across a large clock jump")
	clock_target["saving_throw_bonuses"]["WIS"] = 100
	GameManager.campaign_elapsed_seconds = clock_before + 18
	SpellEffects.advance_time([clock_target], 6)
	check.call(not SpellEffects.records(clock_target).has(clock_source) and base_dc > 0, "Batch 026 resolves the next clock deadline against its accumulated DC and removes the exact source on success")
	GameManager.campaign_elapsed_seconds = clock_before
	_review_regressions(check)

static func _review_regressions(check: Callable) -> void:
	var clock_before := int(GameManager.campaign_elapsed_seconds)
	var caster := _character("batch026-review-caster")
	var original := DataLoader.get_spell("fixture:026_elapsed_repeat")
	var short_spell := original.duplicate(true)
	short_spell["duration_seconds"] = 12
	DataLoader.spells[short_spell["id"]] = short_spell
	# Retain the record reference to inspect the attempts even after expiry removes it.
	var target := _monster("batch026-expiring", -100)
	var cast := _cast(caster, target, str(short_spell["id"]))
	var record: Dictionary = SpellEffects.records(target)[cast["source"]]
	GameManager.campaign_elapsed_seconds = clock_before + 13
	SpellEffects.advance_time([target], 13)
	check.call(int(record.get("repeat_save_attempts", 0)) == 1 and not SpellEffects.records(target).has(cast["source"]) and int(GameManager.campaign_elapsed_seconds) == clock_before + 13, "Batch 026 resolves the 6-second save before 12-second expiry, with no save at/after expiry, and retains the final clock")
	# A success at the first deadline ends the source and cancels later deadlines.
	GameManager.campaign_elapsed_seconds = clock_before
	target = _monster("batch026-early-end", -100)
	cast = _cast(caster, target, str(short_spell["id"]))
	record = SpellEffects.records(target)[cast["source"]]
	target["saving_throw_bonuses"]["WIS"] = 100
	GameManager.campaign_elapsed_seconds = clock_before + 30
	SpellEffects.advance_time([target], 30)
	check.call(int(record.get("repeat_save_attempts", 0)) == 1 and not SpellEffects.records(target).has(cast["source"]), "Batch 026 an early successful clock save cancels all later crossed deadlines")
	DataLoader.spells[original["id"]] = original
	GameManager.campaign_elapsed_seconds = clock_before
	for spell_id in ["fixture:026_target_turn_staged", "fixture:026_elapsed_repeat"]:
		var actor := _character("batch026-missing-history")
		var spell := DataLoader.get_spell(spell_id)
		var effect := SpellEffects.begin_cast(actor, spell)
		SpellEffects.grant(actor, effect, str(spell["effects"][0]["condition"]))
		var dto := actor.to_dict()
		var saved: Dictionary = dto.spell_effects[effect.source_id]
		for key in saved.keys():
			if str(key).begins_with("repeat_save_"): saved.erase(key)
		check.call(not SpellEffects.saved_state_error(dto).is_empty(), "Batch 026 loaded rules require complete history even when every repeat-save field is missing: " + spell_id)
		for required in ["repeat_save_context", "repeat_save_purpose", "repeat_save_stage_index", "repeat_save_dc_adjustment"]:
			var partial := actor.to_dict()
			partial.spell_effects[effect.source_id].erase(required)
			check.call(not SpellEffects.saved_state_error(partial).is_empty(), "Batch 026 refuses individually missing history even when its default value would match: " + str(required))
	# Old ordinary repeat-save records had no history; retain that explicit case.
	var legacy := original.duplicate(true)
	for field in ["repeat_save_schedule", "repeat_save_interval_seconds", "repeat_save_dc_progression"]: legacy.erase(field)
	DataLoader.spells[legacy["id"]] = legacy
	var legacy_actor := _character("batch026-legacy")
	var legacy_cast := SpellEffects.begin_cast(legacy_actor, legacy)
	SpellEffects.grant(legacy_actor, legacy_cast, "frightened")
	var legacy_dto := legacy_actor.to_dict()
	var legacy_record: Dictionary = legacy_dto.spell_effects[legacy_cast.source_id]
	for key in legacy_record.keys():
		if str(key).begins_with("repeat_save_"): legacy_record.erase(key)
	check.call(SharedSpell.content_error(legacy).is_empty() and SpellEffects.saved_state_error(legacy_dto).is_empty(), "Batch 026 preserves old unstaged default-turn saves without new history")
	DataLoader.spells[original["id"]] = original
