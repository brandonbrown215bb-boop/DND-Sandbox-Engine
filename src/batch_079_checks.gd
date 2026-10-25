class_name Batch079Checks
extends RefCounted
## Batch 079 (#43 follow-up, S-130/S-131). Brandon: "require an explicit stacking
## policy in new max-HP definitions, keeping existing data compatible. SRD p.106:
## overlapping castings of the same spell use the strongest effect, and the newest
## wins equal-strength ties. Accumulating reductions need their own stated
## behavior. Display names alone must not decide. Fix the bug where replacing a
## weaker increase grants too much current HP; resolve it against the source."

const LOW := "fixture:b079_vigor_low"
const HIGH := "fixture:b079_vigor_high"
const OTHER := "fixture:b079_vigor_other"

static func load_fixtures() -> void:
	if not DataLoader.get_spell(LOW).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_079/spells/max_hp.json", "spell")

static func rule(spell_id: String) -> Dictionary:
	return DataLoader.get_spell(spell_id).effects[0].rule.duplicate(true)

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(not DataLoader.get_spell(HIGH).is_empty() and not DataLoader.get_spell(OTHER).is_empty(), "079 fixtures with explicit policies load")
	_policy(check)
	_strongest(check)
	_ties(check)
	_overheal(check)
	_names(check)
	_accumulate(check)
	_legacy(check)

static func _policy(check: Callable) -> void:
	var no_combine := {"id": "b079:x", "kind": "increase", "amount": 3}
	var no_accumulate := {"id": "b079:y", "kind": "reduction", "amount": 3, "combine": "sum"}
	check.call(not MaxHpSourceRules.validate_rule(no_combine).is_empty(), "079 new definition without combine is refused")
	check.call(not MaxHpSourceRules.validate_rule(no_accumulate).is_empty(), "079 new reduction without a stated accumulate is refused")
	check.call(not MaxHpSourceRules.validate_rule(no_combine.merged({"combine": "stack"})).is_empty(), "079 unknown combine policy is refused")
	var spell_error := SharedSpell._validate_single_effect({"type": "max_hp_source", "rule": no_combine})
	check.call(not spell_error.is_empty(), "079 spell content without a stacking policy is refused (%s)" % spell_error)
	check.call(MaxHpSourceRules.validate_rule(no_combine, true).is_empty(), "079 documented legacy path still accepts a historical rule at runtime")

static func _strongest(check: Callable) -> void:
	var c := Batch031Checks._character("b079_strong", 40)
	MaxHpSourceRules.apply(c, rule(LOW), "low")
	MaxHpSourceRules.apply(c, rule(HIGH), "high")
	check.call(c.max_hp == 47, "079 weaker then stronger: strongest applies, no stacking (%d)" % c.max_hp)
	var d := Batch031Checks._character("b079_strong2", 40)
	MaxHpSourceRules.apply(d, rule(HIGH), "high")
	MaxHpSourceRules.apply(d, rule(LOW), "low")
	check.call(d.max_hp == 47 and int(d.max_hp_sources["low"].applied) == 0, "079 stronger then weaker: weaker stays inactive (%d)" % d.max_hp)
	MaxHpSourceRules.remove(d, "high")
	check.call(d.max_hp == 43, "079 stronger ends: weaker resumes (%d)" % d.max_hp)

static func _ties(check: Callable) -> void:
	var c := Batch031Checks._character("b079_tie", 40)
	MaxHpSourceRules.apply(c, rule(HIGH), "first")
	MaxHpSourceRules.apply(c, rule(HIGH), "second")
	var s := c.max_hp_sources
	check.call(c.max_hp == 47 and int(s["second"].applied) == 7 and int(s["first"].applied) == 0, "079 equal strength: the newest casting is the active one")
	var dto: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var back := Character.new()
	back.from_dict(dto)
	check.call(back.max_hp == 47 and int(back.max_hp_sources["second"].applied) == 7 and int(back.max_hp_sources["second"].applied_seq) > int(back.max_hp_sources["first"].applied_seq), "079 tie order survives a JSON round trip")
	MaxHpSourceRules.apply(back, rule(HIGH), "first")
	check.call(back.max_hp == 47 and int(back.max_hp_sources["first"].applied) == 7 and int(back.max_hp_sources["second"].applied) == 0, "079 recasting the older one makes it newest and active")
	var bad := dto.duplicate(true)
	bad.max_hp_sources["first"].applied_seq = -2
	check.call(not MaxHpSourceRules.saved_error(bad).is_empty(), "079 saved order must be a positive integer")

static func _overheal(check: Callable) -> void:
	var c := Batch031Checks._character("b079_heal", 40)
	c.current_hp = 20
	MaxHpSourceRules.apply(c, rule(LOW), "low")
	check.call(c.max_hp == 43 and c.current_hp == 23, "079 weak increase raises current by 3 (%d/%d)" % [c.current_hp, c.max_hp])
	var r := MaxHpSourceRules.apply(c, rule(HIGH), "high")
	check.call(c.max_hp == 47 and c.current_hp == 27 and int(r.current_hp) == 27, "079 replacing the weaker increase raises current only by the net +4, not +7 (%d/%d)" % [c.current_hp, c.max_hp])
	MaxHpSourceRules.apply(c, rule(LOW), "low2")
	check.call(c.max_hp == 47 and c.current_hp == 27, "079 a weaker recast under a stronger one grants nothing (%d/%d)" % [c.current_hp, c.max_hp])

static func _names(check: Callable) -> void:
	check.call(str(DataLoader.get_spell(LOW).name) == str(DataLoader.get_spell(OTHER).name), "079 fixtures share a display name")
	var c := Batch031Checks._character("b079_name", 40)
	MaxHpSourceRules.apply(c, rule(HIGH), "high")
	MaxHpSourceRules.apply(c, rule(OTHER), "other")
	check.call(c.max_hp == 49, "079 same display name, different source id: both apply, not merged (%d)" % c.max_hp)

static func _accumulate(check: Callable) -> void:
	var acc := {"id": "b079:drain", "kind": "reduction", "amount": "damage_dealt", "accumulate": true, "combine": "sum"}
	var once := {"id": "b079:mark", "kind": "reduction", "amount": "damage_dealt", "accumulate": false, "combine": "sum"}
	check.call(MaxHpSourceRules.validate_rule(acc).is_empty() and MaxHpSourceRules.validate_rule(once).is_empty(), "079 reductions with a stated accumulate validate")
	var c := Batch031Checks._character("b079_acc", 40)
	MaxHpSourceRules.apply(c, acc, "m:drain", 5)
	MaxHpSourceRules.apply(c, acc, "m:drain", 4)
	check.call(c.max_hp == 31, "079 accumulate:true adds repeated hits from one source (40 -> %d)" % c.max_hp)
	var d := Batch031Checks._character("b079_once", 40)
	MaxHpSourceRules.apply(d, once, "m:mark", 5)
	MaxHpSourceRules.apply(d, once, "m:mark", 4)
	check.call(d.max_hp == 35, "079 accumulate:false keeps the larger single request (40 -> %d)" % d.max_hp)

static func _legacy(check: Callable) -> void:
	var c := Batch031Checks._character("b079_legacy", 30)
	var dto := c.to_dict()
	dto.max_hp = 24
	dto.current_hp = 24
	dto["max_hp_sources"] = {
		"a": {"rule_id": "old", "kind": "reduction", "requested": 3, "applied": -3, "accumulate": false, "floor": 1, "cure_on": [], "periodic": {}, "raise_current": false},
		"b": {"rule_id": "old", "kind": "reduction", "requested": 3, "applied": -3, "accumulate": false, "floor": 1, "cure_on": [], "periodic": {}, "raise_current": false}}
	check.call(MaxHpSourceRules.saved_error(dto).is_empty(), "079 legacy saved sources without combine or order validate")
	var back := Character.new()
	back.from_dict(JSON.parse_string(JSON.stringify(dto)))
	check.call(back.max_hp == 24 and back.max_hp_sources.size() == 2, "079 legacy save loads unchanged (legacy sum)")
	MaxHpSourceRules.remove(back, "a")
	check.call(back.max_hp == 27, "079 legacy source removal reverts only its own delta (%d)" % back.max_hp)
