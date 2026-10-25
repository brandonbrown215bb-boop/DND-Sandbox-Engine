class_name Batch073Checks
extends RefCounted
## Batch 073 (S-119): explicit death/destruction without damage through the
## real shared-spell resolver — living, already-zero and ineligible targets,
## with no duplicate remains or effects.

const ENDING := "fixture:b073_word_of_ending"
const UNMAKING := "fixture:b073_unmaking"

static func load_fixtures() -> void:
	if not DataLoader.get_spell(ENDING).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_073/spells/explicit_death.json", "spell")

static func policy(spell_id: String) -> Dictionary:
	return DataLoader.get_spell(spell_id).get("effects", [{}])[0].get("policy", {})

static func downed(id: String) -> Character:
	var c := Batch031Checks._character(id, 20)
	c.current_hp = 0
	c.is_alive = false
	c.death_save_failures = 1
	return c

static func cast(owner: Character, target, spell_id: String) -> Dictionary:
	return SpellResolver.resolve(owner, target, DataLoader.get_spell(spell_id), true, {}, [], 1)

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty() and SharedSpell.content_error(DataLoader.get_spell(ENDING)).is_empty() and SharedSpell.content_error(DataLoader.get_spell(UNMAKING)).is_empty(), "073 explicit-death fixtures load and validate: %s" % str(DataLoader.get_load_errors()))
	_validation(check)
	_living(check)
	_already_zero(check)
	_ineligible(check)
	_saves(check)

static func _validation(check: Callable) -> void:
	var good: Dictionary = DataLoader.get_spell(ENDING).duplicate(true)
	var refused := 0
	for mutate in [
		func(s): s.effects[0].policy.erase("at_zero"),
		func(s): s.effects[0].policy.erase("eligibility"),
		func(s): s.effects[0].policy["trigger"] = "reduced_to_zero",
		func(s): s.effects[0].policy.eligibility["min_level"] = 3,
		func(s): s.effects[0].policy.eligibility.max_current_hp = -1,
		func(s): s.effects[0].policy.outcome = "destruction",
		func(s): s.effects[0].policy["successor"] = {},
		func(s): s.effects[0]["damage"] = "1d6",
		func(s): s.effects[0].policy.eligibility["creature_types"] = [],
		func(s): s.effects[0].policy.at_zero = "maybe",
	]:
		var s := good.duplicate(true)
		mutate.call(s)
		if not SharedSpell.content_error(s).is_empty(): refused += 1
	check.call(refused == 10, "073 loader refuses missing at_zero/eligibility, unknown fields, bad thresholds/types, destruction with intact remains and damage fields (%d/10)" % refused)

static func _living(check: Callable) -> void:
	var a := Batch071Checks.caster("b073_a")
	var m := Batch071Checks.monster("b073_m", 20)
	var r := cast(a, m, ENDING)
	var after: Dictionary = m.get("zero_hp_aftermath", {})
	check.call(r.get("success", false) and not bool(m.is_alive) and int(m.current_hp) == 0 and int(m.max_hp) == 20 and after.get("outcome", "") == "death" and after.get("remains", "") == "intact" and after.get("cause", "") == "word_of_ending" and int(a.spell_slots["1"]) == 3, "073 living 20-HP monster dies outright: intact remains, cause recorded, maximum untouched, one slot")
	check.call(int(r.get("settle_death", {}).get("damage", -1)) == 0 and not after.get("cause_source", {}).has("damage_type"), "073 settlement reports no damage and no damage type")
	var snapshot := JSON.stringify(after)
	var refusal := ZeroHpAftermathRules.explicit_cast_error(m, DataLoader.get_spell(ENDING))
	var stale := ZeroHpAftermathRules.settle_explicit(m, policy(ENDING), "spell:stale", a)
	check.call(not refusal.is_empty() and not stale.get("applied", true) and JSON.stringify(m.get("zero_hp_aftermath", {})) == snapshot, "073 a dead monster is refused before cost; a stale settlement changes nothing (no second death or remains)")
	var c := Batch031Checks._character("b073_living", 25)
	c.inventory.add_item("dagger")
	c.inventory.add_item("ring_of_protection")
	r = cast(a, c, ENDING)
	check.call(c.is_dead() and c.body_death_serial == 1 and c.corpse_state.remains == "intact" and c.corpse_state.cause == "word_of_ending" and c.corpse_state.cause_source.policy_id == "b073:ending" and c.inventory.has_item("dagger"), "073 living character dies once with intact remains and retained gear")
	var stale_c := ZeroHpAftermathRules.settle_explicit(c, policy(ENDING), "spell:stale", a)
	check.call(not stale_c.get("applied", true) and c.body_death_serial == 1 and c.corpse_state.cause == "word_of_ending", "073 repeat settlement on the corpse is refused; death serial stays 1")
	var u := Batch031Checks._character("b073_unmade", 25)
	u.inventory.add_item("dagger")
	u.inventory.add_item("ring_of_protection")
	r = cast(a, u, UNMAKING)
	check.call(u.is_dead() and u.corpse_state.remains == "destroyed" and r.get("settle_death", {}).get("outcome", "") == "destruction" and not u.inventory.has_item("dagger") and u.inventory.has_item("ring_of_protection") and CorpseRules.target_error(u, "revivify", 0) == "No remains are available to touch.", "073 destruction: no remains, nonmagical gear destroyed, magic retained, touch revival refused")

static func _already_zero(check: Callable) -> void:
	var a := Batch071Checks.caster("b073_z")
	var d := downed("b073_downed")
	check.call(ZeroHpAftermathRules.explicit_target_error(d, policy(ENDING)).is_empty(), "073 a downed (0 HP, not dead) character is eligible when at_zero is settle")
	var r := cast(a, d, ENDING)
	check.call(d.is_dead() and d.body_death_serial == 1 and d.death_save_failures == 3 and d.corpse_state.cause == "word_of_ending" and bool(r.get("settle_death", {}).get("was_at_zero", false)), "073 the already-zero character dies once with the declared cause (no Death Save)")
	var e := downed("b073_downed_refused")
	var slots := int(a.spell_slots["1"])
	var refusal := ZeroHpAftermathRules.explicit_target_error(e, policy(UNMAKING))
	var stale := ZeroHpAftermathRules.settle_explicit(e, policy(UNMAKING), "spell:stale", a)
	check.call(not refusal.is_empty() and not stale.get("applied", true) and e.is_downed() and e.corpse_state.is_empty() and e.death_save_failures == 1 and int(a.spell_slots["1"]) == slots, "073 at_zero refuse: a downed target stays downed, no remains, nothing spent")

static func _ineligible(check: Callable) -> void:
	var spell := DataLoader.get_spell(ENDING)
	var big := Batch071Checks.monster("b073_big", 40)
	var undead := Batch071Checks.monster("b073_undead", 5)
	undead["creature_type"] = "undead"
	var object := {"id": "dropped:x", "is_object": true, "current_hp": 3, "name": "Crate"}
	var errors := [ZeroHpAftermathRules.explicit_cast_error(big, spell), ZeroHpAftermathRules.explicit_cast_error(undead, spell), ZeroHpAftermathRules.explicit_cast_error(object, spell), ZeroHpAftermathRules.explicit_cast_error(null, spell), ZeroHpAftermathRules.explicit_cast_error(Batch071Checks.monster("b073_gob", 5), DataLoader.get_spell(UNMAKING))]
	check.call(errors.all(func(e): return not str(e).is_empty()), "073 above-threshold, excluded type, object, empty ground and not-listed type are refused: %s" % str(errors))
	check.call(bool(big.is_alive) and int(big.current_hp) == 40 and not big.has("zero_hp_aftermath"), "073 an ineligible creature is unchanged")
	var edge := Batch071Checks.monster("b073_edge", 30)
	check.call(ZeroHpAftermathRules.explicit_cast_error(edge, spell).is_empty(), "073 exactly the threshold (30) is eligible")

static func _saves(check: Callable) -> void:
	var a := Batch071Checks.caster("b073_s")
	var c := downed("b073_saved")
	cast(a, c, ENDING)
	var dto: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var back := Character.new()
	back.from_dict(dto)
	check.call(CorpseRules.saved_error(dto).is_empty() and back.is_dead() and back.corpse_state.cause == "word_of_ending" and back.corpse_state.cause_source == c.corpse_state.cause_source and back.body_death_serial == 1, "073 JSON-text DTO keeps the explicit cause and single death")
	check.call(not ZeroHpAftermathRules.explicit_target_error(back, policy(ENDING)).is_empty(), "073 the reloaded corpse is still refused")
	var forged: Dictionary = dto.duplicate(true)
	forged.corpse_state.cause_source.outcome = "destruction"
	check.call(not CorpseRules.saved_error(forged).is_empty(), "073 a forged cause contradicting remains is refused on load")
	var legacy: Dictionary = dto.duplicate(true)
	legacy.corpse_state.erase("cause_source")
	check.call(CorpseRules.saved_error(legacy).is_empty(), "073 a legacy corpse without cause detail still loads")
