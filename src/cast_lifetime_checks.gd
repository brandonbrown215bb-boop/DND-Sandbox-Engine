class_name CastLifetimeChecks
extends RefCounted

const FREE := "fixture:lifetime_free"
const FOCUS := "fixture:lifetime_focus"
const PLAIN := "fixture:lifetime_plain"

static func load_fixtures() -> void:
	if not DataLoader.get_spell(FREE).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/cast_lifetimes/spells.json", "spell")
	DataLoader._load_json_file("res://data/fixtures/cast_lifetimes/classes.json", "class")

static func features() -> Array:
	return DataLoader.get_character_class("fixture:lifetime_profiles").get("features_by_level", {}).get("1", []).duplicate(true)

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "S-141 lifetime fixtures load through production validation: %s" % str(DataLoader.get_load_errors()))
	var caster := Batch031Checks._character("lifetime_checks")
	caster.features.append_array(features())
	var before := DataLoader.get_spell(FOCUS).duplicate(true)
	var invocation := Batch085Checks.invocation(FOCUS)
	var focused := AttackProfileRules.apply_cast(caster, invocation)
	check.call(int(focused.duration_seconds) == 18 and focused.concentration and focused.school == "abjuration" and AttackProfileRules.cast_error(caster, focused).is_empty(), "S-141 one invocation combines a shorter duration, concentration and existing school change")
	check.call(focused._cast_profile.ignored == [{"source": "lifetime:rival", "field": "duration_seconds"}, {"source": "lifetime:rival", "field": "concentration"}], "S-141 each lifetime field keeps its first replacement, recording later conflicts")
	var unbound := AttackProfileRules.apply_cast(caster, Batch085Checks.invocation(FREE))
	var plain := AttackProfileRules.apply_cast(caster, Batch085Checks.invocation(PLAIN))
	check.call(int(unbound.duration_seconds) == 120 and not unbound.concentration and not plain.has("_cast_profile") and int(plain.duration_seconds) == 60 and not plain.concentration, "S-141 an extended nonconcentration cast and an unrelated cast retain separate lifetimes")
	check.call(AttackProfileRules.apply_cast(caster, focused) == focused and DataLoader.get_spell(FOCUS) == before, "S-141 lifetime transformations apply once without catalog mutation")
	var extended := SorcererRules.apply_extended_spell(unbound)
	var extended_result := CombatAction.resolve_spell(caster, caster, extended)
	var extended_source := str(extended_result.get("effect_cast", {}).get("source_id", ""))
	check.call(extended_result.get("success", false) and int(caster.spell_effects.get(extended_source, {}).get("remaining_seconds", 0)) == 240 and not caster.spell_effects.get(extended_source, {}).get("concentration", true) and SpellEffects.saved_state_error(caster.to_dict()).is_empty(), "S-141 native Extended Spell captures the already-transformed duration without restoring catalog concentration")
	var carrier := invocation.duplicate(true)
	carrier["effects"] = [{"type": "grant_source_benefits", "benefits": [{"stat": "AC", "amount": 2}]}]
	check.call(not AttackProfileRules.cast_error(caster, AttackProfileRules.apply_cast(caster, carrier)).is_empty(), "S-141 source-benefit carriers refuse lifetime changes before their stricter saved-definition contract can fail after payment")
	caster.features = caster.features.filter(func(f): return str(f.get("source_instance_id", "")) != "lifetime:held")
	check.call(not AttackProfileRules.cast_error(caster, focused).is_empty(), "S-141 removing the selected lifetime owner invalidates a pending cast")
	var base_rule: Dictionary = features()[2]
	for value in [0, -1, 86401, 1.5, "18", true]:
		var bad := base_rule.duplicate(true)
		bad.replace.duration_seconds = value
		check.call(not AttackProfileRules.validate_rule(bad).is_empty(), "S-141 malformed duration %s refuses" % str(value))
	var bad := base_rule.duplicate(true)
	bad.replace.concentration = "false"
	check.call(not AttackProfileRules.validate_rule(bad).is_empty(), "S-141 concentration must be Boolean")
	bad = base_rule.duplicate(true)
	bad.scope = {"kind": "weapon"}
	check.call(not AttackProfileRules.validate_rule(bad).is_empty(), "S-141 weapon profiles cannot change spell lifetimes")
	caster.features.assign([{"id": "native-lifetime", "type": "attack_profile", "source_instance_id": "native-lifetime", "scope": {"kind": "spell", "ids": ["heroism", "magic_missile"]}, "replace": {"duration_seconds": 120}}])
	for id in ["heroism", "magic_missile"]:
		check.call(not AttackProfileRules.cast_error(caster, AttackProfileRules.apply_cast(caster, Batch085Checks.invocation(id))).is_empty(), "S-141 unsupported lifetime host %s refuses explicitly" % id)
