class_name Batch081Checks
extends RefCounted
## Batch 081 (#45 follow-up, S-119). Brandon: "support a declared fallback, not
## an automatic one on every death effect. Power Word Kill deals 12d12 Psychic
## above 100 HP; other effects follow their own text. Support explicit object
## destruction separately from creature death, reusing the existing destruction
## handling."

const PWK := "power_word_kill"
const UNMAKE := "fixture:b081_unmake_object"

static func load_fixtures() -> void:
	Batch073Checks.load_fixtures()
	if not DataLoader.get_spell(UNMAKE).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_081/spells/object_destruction.json", "spell")

static func caster(id: String) -> Character:
	var a := Batch031Checks._character(id, 40)
	a.spell_slots = {"1": 4, "9": 4}
	return a

static func cast(owner: Character, target, spell_id: String) -> Dictionary:
	var spell := DataLoader.get_spell(spell_id)
	return SpellResolver.resolve(owner, target, spell, true, {}, [], int(spell.get("level", 1)))

static func pwk_policy() -> Dictionary:
	return Batch073Checks.policy(PWK)

static func loose_object(id: String, hp: int, magical: bool = false) -> Dictionary:
	var inv := Inventory.new()
	inv.add_item("dagger")
	var record: Dictionary = inv.backpack_instances()[0]
	var object := CombatObjectRules.make_dropped_item(record, Vector2i(2, 0), "b081")
	object["id"] = id
	object["hp"] = hp
	object["max_hp"] = hp
	if magical: object["magical"] = true
	return object

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty() and SharedSpell.content_error(DataLoader.get_spell(PWK)).is_empty() and SharedSpell.content_error(DataLoader.get_spell(UNMAKE)).is_empty(), "081 Power Word Kill and the object-destruction fixture load and validate: %s" % str(DataLoader.get_load_errors()))
	var fb: Dictionary = pwk_policy().get("fallback", {})
	check.call(int(pwk_policy().eligibility.max_current_hp) == 100 and fb.get("damage", "") == "12d12" and fb.get("damage_type", "") == "psychic" and not pwk_policy().eligibility.has("excluded_creature_types"), "081 Power Word Kill data declares SRD p.154: dies at 100 HP or fewer, otherwise 12d12 Psychic; no type exclusions")
	check.call(not Batch073Checks.policy(Batch073Checks.ENDING).has("fallback"), "081 the 073 death fixture declares no fallback")
	_validation(check)
	_threshold(check)
	_no_fallback(check)
	_objects(check)
	_saves(check)
	_review(check)

static func _validation(check: Callable) -> void:
	var good: Dictionary = DataLoader.get_spell(PWK).duplicate(true)
	var refused := 0
	var cases := [
		func(s): s.effects[0].policy.fallback["extra"] = 1,
		func(s): s.effects[0].policy.fallback.when = "always",
		func(s): s.effects[0].policy.fallback.erase("when"),
		func(s): s.effects[0].policy.eligibility.erase("max_current_hp"),
		func(s): s.effects[0].policy.fallback.damage = 30,
		func(s): s.effects[0].policy.fallback.damage = "lots",
		func(s): s.effects[0].policy.fallback.damage_type = "spite",
		func(s): s.effects[0].policy.fallback = "12d12",
	]
	for mutate in cases:
		var s := good.duplicate(true)
		mutate.call(s)
		if not SharedSpell.content_error(s).is_empty(): refused += 1
	check.call(refused == cases.size(), "081 loader refuses unknown fallback fields, undeclared/unknown when, fallback without an HP limit, non-dice damage and unknown damage types (%d/%d)" % [refused, cases.size()])
	var obj: Dictionary = DataLoader.get_spell(UNMAKE).duplicate(true)
	refused = 0
	var object_cases := [
		func(s): s.effects[0].policy.erase("magical"),
		func(s): s.effects[0].policy.magical = "allow",
		func(s): s.effects[0].policy.erase("cause"),
		func(s): s.effects[0].policy["outcome"] = "death",
		func(s): s.effects[0]["damage"] = "1d6",
	]
	for mutate in object_cases:
		var s := obj.duplicate(true)
		mutate.call(s)
		if not SharedSpell.content_error(s).is_empty(): refused += 1
	check.call(refused == object_cases.size(), "081 loader refuses object destruction with no magical rule, unsupported allow, missing cause, unknown fields and damage (%d/%d)" % [refused, object_cases.size()])

static func _threshold(check: Callable) -> void:
	var a := caster("b081_a")
	var m := Batch071Checks.monster("b081_m100", 100)
	var r := cast(a, m, PWK)
	check.call(r.get("success", false) and r.get("killed", false) and not bool(m.is_alive) and m.get("zero_hp_aftermath", {}).get("cause", "") == "power_word_kill" and int(a.spell_slots["9"]) == 3 and int(r.get("damage", -1)) == 0, "081 Power Word Kill: exactly 100 HP dies outright, no damage, one 9th-level slot")
	var c := Batch031Checks._character("b081_c90", 90)
	cast(a, c, PWK)
	check.call(c.is_dead() and c.body_death_serial == 1 and c.death_save_failures == 3 and c.corpse_state.cause == "power_word_kill", "081 Power Word Kill: a 90-HP character dies outright with no Death Saves")
	var big := Batch071Checks.monster("b081_m150", 150)
	check.call(ZeroHpAftermathRules.explicit_cast_error(big, DataLoader.get_spell(PWK)).is_empty(), "081 a 150-HP creature is not refused before cost (the fallback applies)")
	r = cast(a, big, PWK)
	var dealt := int(r.get("damage", -1))
	check.call(r.get("success", false) and bool(r.get("settle_death", {}).get("fallback", false)) and dealt >= 12 and dealt <= 144 and int(big.current_hp) == 150 - dealt and not big.has("zero_hp_aftermath") and int(a.spell_slots["9"]) == 1, "081 Power Word Kill: 150 HP takes 12d12 Psychic instead (%d), no death record, slot paid" % dealt)
	var edge := Batch071Checks.monster("b081_m101", 101)
	r = cast(a, edge, PWK)
	check.call(bool(r.get("settle_death", {}).get("fallback", false)) and str(r.settle_death.damage_type) == "psychic" and int(edge.current_hp) == 101 - int(r.damage), "081 Power Word Kill: 101 HP is above the limit and takes the fallback")
	var immune := Batch071Checks.monster("b081_immune", 140)
	immune["damage_immunities"] = ["psychic"]
	a.spell_slots["9"] = 2
	r = cast(a, immune, PWK)
	check.call(bool(r.get("settle_death", {}).get("fallback", false)) and int(r.get("damage", -1)) == 0 and int(immune.current_hp) == 140, "081 the fallback is ordinary damage: Psychic immunity takes 0")
	var pc := Batch031Checks._character("b081_pc", 120)
	pc.temp_hp = 5
	r = cast(a, pc, PWK)
	check.call(not pc.is_dead() and pc.corpse_state.is_empty() and pc.current_hp == 120 - maxi(0, int(r.settle_death.rolled) - 5) and pc.temp_hp == maxi(0, 5 - int(r.settle_death.rolled)) and bool(r.settle_death.fallback), "081 a 120-HP character takes the fallback through the shared damage boundary (temp HP first)")
	var corpse := Batch071Checks.monster("b081_dead", 0)
	corpse["is_alive"] = false
	corpse["zero_hp_aftermath"] = {"outcome": "death"}
	check.call(not ZeroHpAftermathRules.explicit_cast_error(corpse, DataLoader.get_spell(PWK)).is_empty(), "081 an already-dead creature is still refused before cost")

static func _no_fallback(check: Callable) -> void:
	var a := Batch071Checks.caster("b081_nf")
	var spell := DataLoader.get_spell(Batch073Checks.ENDING)
	var big := Batch071Checks.monster("b081_nf_big", 40)
	var refusal := ZeroHpAftermathRules.explicit_cast_error(big, spell)
	var stale := ZeroHpAftermathRules.settle_explicit(big, Batch073Checks.policy(Batch073Checks.ENDING), "spell:stale", a)
	check.call(not refusal.is_empty() and not stale.get("applied", true) and not stale.has("fallback") and int(big.current_hp) == 40 and not ZeroHpAftermathRules.fallback_applies(big, Batch073Checks.policy(Batch073Checks.ENDING)), "081 a death effect without a declared fallback gets none: refused, no damage, HP unchanged")

static func _objects(check: Callable) -> void:
	var a := Batch071Checks.caster("b081_o")
	var spell := DataLoader.get_spell(UNMAKE)
	var crate := loose_object("b081_crate", 30)
	var target := CombatObjectRules.make_resolution_target(crate)
	check.call(ObjectDestructionRules.cast_error(target, spell).is_empty(), "081 a nonmagical unattended object is eligible")
	var r := cast(a, target, UNMAKE)
	CombatObjectRules.sync_resolution_target(crate, target)
	check.call(r.get("success", false) and bool(r.get("destroy_object", {}).get("applied", false)) and int(crate.hp) == 0 and bool(crate.get("copy_destroyed", false)) and str(crate.get("destroyed_cause", "")) == "unmade_object" and int(a.spell_slots["1"]) == 3, "081 object destruction zeroes the object and the existing settle_destruction marks the copy destroyed")
	check.call(bool(crate.get("removed", false)) and not ObjectDestructionRules.cast_error(CombatObjectRules.make_resolution_target(crate), spell).is_empty(), "081 a destroyed object is refused again")
	var ring := loose_object("b081_ring", 5, true)
	var m := Batch071Checks.monster("b081_creature", 10)
	var c := Batch031Checks._character("b081_char", 10)
	var errors := [ObjectDestructionRules.cast_error(CombatObjectRules.make_resolution_target(ring), spell), ObjectDestructionRules.cast_error(m, spell), ObjectDestructionRules.cast_error(c, spell), ObjectDestructionRules.cast_error(null, spell)]
	check.call(errors.all(func(e): return not str(e).is_empty()) and bool(m.is_alive) and int(m.current_hp) == 10, "081 magic objects, monsters, characters and empty ground are refused: %s" % str(errors))
	check.call(not ZeroHpAftermathRules.explicit_cast_error(CombatObjectRules.make_resolution_target(loose_object("b081_x", 3)), DataLoader.get_spell(PWK)).is_empty(), "081 creature death (Power Word Kill) still refuses objects")

static func _saves(check: Callable) -> void:
	var a := caster("b081_s")
	var c := Batch031Checks._character("b081_saved", 80)
	cast(a, c, PWK)
	var back := Character.new()
	back.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	check.call(back.is_dead() and back.corpse_state.cause == "power_word_kill" and back.corpse_state.cause_source.policy_id == "power_word_kill" and back.body_death_serial == 1, "081 JSON-text DTO keeps the Power Word Kill death once")
	var legacy: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	legacy.corpse_state.erase("cause_source")
	check.call(CorpseRules.saved_error(legacy).is_empty(), "081 a legacy Power Word Kill corpse (no cause detail) still loads")

## Reviewer stress (batch 081 acceptance).
static func _review(check: Callable) -> void:
	var good: Dictionary = DataLoader.get_spell(PWK).duplicate(true)
	var bad := ["0d12", "-1d12", "12d13", "", "12d12x"]
	var refused := 0
	for dice in bad:
		var s := good.duplicate(true)
		s.effects[0].policy.fallback.damage = dice
		if not SharedSpell.content_error(s).is_empty(): refused += 1
	var s2 := good.duplicate(true)
	s2.effects[0].policy.fallback.erase("damage_type")
	if not SharedSpell.content_error(s2).is_empty(): refused += 1
	var s3 := good.duplicate(true)
	s3.effects[0].policy.fallback.erase("damage")
	if not SharedSpell.content_error(s3).is_empty(): refused += 1
	check.call(refused == bad.size() + 2, "081 review: zero/negative/bad dice and a missing damage or damage_type are refused (%d/%d)" % [refused, bad.size() + 2])
	var a := caster("b081_rv")
	var m := Batch071Checks.monster("b081_rv_temp", 100)
	m["temp_hp"] = 50
	var r := cast(a, m, PWK)
	check.call(r.get("killed", false) and not bool(m.is_alive) and int(m.temp_hp) == 0 and not bool(r.get("settle_death", {}).get("fallback", false)) and int(r.get("damage", -1)) == 0, "081 review: 100 HP + 50 temp HP still dies (temp HP ignored for the limit, cleared on death)")
	var big := Batch071Checks.monster("b081_rv_big", 101)
	big["temp_hp"] = 200
	r = cast(a, big, PWK)
	check.call(int(big.current_hp) == 101 and int(big.temp_hp) == 200 - int(r.settle_death.rolled) and int(r.get("damage", 0)) == int(r.settle_death.damage) and bool(big.is_alive), "081 review: fallback damage hits temp HP first and is counted once")
