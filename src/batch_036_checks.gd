class_name Batch036Checks
extends RefCounted

static func load_fixtures() -> void:
	if not DataLoader.get_spell("fixture:b036_mark").is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_036/spells/marks.json", "spell")
	DataLoader._load_json_file("res://data/fixtures/batch_036/items/wands.json", "item")

static func mark(caster: Character, target) -> String:
	var cast := SpellEffects.begin_cast(caster, DataLoader.get_spell("fixture:b036_mark"))
	SpellEffects.grant(target, cast, "blessed")
	caster.concentrating_on = {"spell_id": "fixture:b036_mark", "targets": [target], "effect_source": str(cast.source_id)}
	return str(cast.source_id)

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "036 neutral end-aftermath spell and last-charge items load: %s" % str(DataLoader.get_load_errors()))
	_source_end(check)
	_last_charge(check)

static func _source_end(check: Callable) -> void:
	var caster := Batch031Checks._character("b036_caster", 30)
	var t := Batch031Checks._character("b036_t", 30)
	var source := mark(caster, t)
	check.call(t.spell_effects.has(source) and t.spell_effects[source].end_aftermath.size() == 2, "036 S-086 cast captures declared end aftermath on the exact source")
	SpellEffects.clear_source_end_events()
	SpellEffects.advance_time([caster, t], 12)
	var events := SpellEffects.source_end_events().filter(func(e): return e.source_id == source)
	check.call(events.size() == 1 and events[0].end_reason == "expired" and events[0].aftermath.size() == 1 and events[0].aftermath[0].aftermath_id == "lapse" and t.current_hp == 27 and not t.has_condition("prone"), "036 S-086 expiry emits one final event and only its own follow-up")
	SpellEffects.advance_time([caster, t], 12)
	check.call(SpellEffects.source_end_events().filter(func(e): return e.source_id == source).size() == 1 and t.current_hp == 27, "036 S-086 an ended source cannot emit or follow up again")
	var d := Batch031Checks._character("b036_d", 30)
	source = mark(caster, d)
	var ev := SpellEffects.remove(d, source, "dismissed")
	check.call(ev.aftermath.size() == 1 and ev.aftermath[0].aftermath_id == "recoil" and d.has_condition("prone") and d.current_hp == 30, "036 S-086 dismissal fires its own follow-up, not the expiry one")
	check.call(SpellEffects.remove(d, source, "dismissed").is_empty(), "036 S-086 repeated dismissal is a no-op")
	var c := Batch031Checks._character("b036_c", 30)
	source = mark(caster, c)
	SpellEffects.clear_source_end_events()
	SpellEffects.end_concentration(caster, [c])
	events = SpellEffects.source_end_events().filter(func(e): return e.source_id == source)
	check.call(events.size() == 1 and events[0].end_reason == "concentration_ended" and c.has_condition("prone") and c.current_hp == 30, "036 S-086 concentration end is its own reason with its own follow-up")
	var o := Batch031Checks._character("b036_o", 30)
	source = mark(caster, o)
	ev = SpellEffects.remove(o, source, "damage")
	check.call(ev.aftermath.is_empty() and o.current_hp == 30 and not o.has_condition("prone"), "036 S-086 undeclared reason emits the final event without any follow-up")
	var m := {"id": "b036_monster", "name": "M", "current_hp": 20, "max_hp": 20, "is_alive": true, "conditions": {}, "hex_position": Vector2i(2, 3)}
	source = mark(caster, m)
	ev = SpellEffects.remove(m, source, "expired")
	check.call(ev.aftermath.size() == 1 and int(m.current_hp) == 17 and ev.aftermath[0].location == Vector2i(2, 3) and ev.aftermath[0].origin_id == "b036_monster", "036 S-086 creature host records its origin/location and settles the follow-up")
	# Saved records: captured aftermath must match definition; legacy omission loads.
	var p := Batch031Checks._character("b036_p", 30)
	source = mark(caster, p)
	var dto := p.to_dict()
	check.call(SpellEffectPersistence.saved_state_error(dto).is_empty(), "036 S-086 live record with captured aftermath validates")
	for defect in ["changed", "legacy"]:
		var bad := dto.duplicate(true)
		if defect == "changed": bad.spell_effects[source].end_aftermath[0].reasons = ["death"]
		else: bad.spell_effects[source].erase("end_aftermath")
		var err: String = SpellEffectPersistence.saved_state_error(bad)
		check.call((defect == "changed") != err.is_empty(), "036 S-086 saved %s aftermath %s" % [defect, "refuses" if defect == "changed" else "still loads"])
	for defect in ["reasons", "effect", "damage", "dup"]:
		var bad: Array = DataLoader.get_spell("fixture:b036_mark").end_aftermath.duplicate(true)
		match defect:
			"reasons": bad[0].reasons = []
			"effect": bad[0].effects[0].type = "teleport"
			"damage": bad[0].effects[0].damage_type = "sonic"
			"dup": bad[1].id = "lapse"
		check.call(not SourceEndAftermathRules.validate(bad).is_empty(), "036 S-086 malformed aftermath %s refuses" % defect)

static func _last_charge(check: Callable) -> void:
	var a := Batch031Checks._character("b036_items", 30)
	a.inventory.add_item("fixture:b036_brittle_wand")
	a.inventory.add_item("fixture:b036_brittle_wand")
	var wands := a.inventory.owned_instances().filter(func(r): return r.definition_id == "fixture:b036_brittle_wand")
	var w1 := str(wands[0].instance_id)
	var w2 := str(wands[1].instance_id)
	a.inventory.spend_instance_charges(w1, 1)
	check.call(a.inventory.last_charge_receipt.is_empty(), "036 S-060 a non-final spend has no aftermath")
	a.inventory.forced_last_charge_roll = 1
	a.inventory.spend_instance_charges(w1, 2)
	var r := a.inventory.last_charge_receipt
	check.call(r.rolled and r.roll == 1 and r.destroyed and a.inventory.get_instance(w1).is_empty() and not a.inventory.get_instance(w2).is_empty(), "036 S-060 last-charge roll of 1 destroys only that exact copy")
	a.inventory.forced_last_charge_roll = 7
	a.inventory.spend_instance_charges(w2, 3)
	r = a.inventory.last_charge_receipt
	check.call(r.rolled and not r.triggered and not a.inventory.get_instance(w2).is_empty() and int(a.inventory.get_instance(w2).state.charges) == 0, "036 S-060 a non-triggering roll keeps the empty copy")
	check.call(not a.inventory.spend_instance_charges(w2, 1) and a.inventory.last_charge_receipt == r, "036 S-060 an empty copy cannot spend or roll again")
	a.inventory.add_item("fixture:b036_spent_rod")
	var rod := str(a.inventory.owned_instances().filter(func(x): return x.definition_id == "fixture:b036_spent_rod")[0].instance_id)
	a.inventory.spend_instance_charges(rod, 2)
	r = a.inventory.last_charge_receipt
	var state: Dictionary = a.inventory.get_instance(rod).state
	check.call(r.degraded and not r.rolled and r.kept_properties == ["light"] and state.degraded and not state.magical and not ZeroHpAftermathRules._is_magic(a.inventory.get_instance(rod)), "036 S-060 degrade keeps the same copy, now nonmagical, with declared properties")
	a.inventory.recover_daily_charges()
	check.call(int(a.inventory.get_instance(rod).state.charges) == 0 and int(a.inventory.get_instance(w2).state.charges) > 0, "036 S-060 degraded copy does not recover; an undegraded empty copy still does")
	var inv := a.inventory.to_dict()
	check.call(InventoryCopies.saved_error(inv) == "", "036 S-060 degraded copy DTO validates")
	var back := Character.new()
	back.from_dict(a.to_dict())
	check.call(bool(back.inventory.get_instance(rod).state.get("degraded", false)) and back.inventory.get_instance(rod).instance_id == rod, "036 S-060 degraded copy restores with its identity")
	for defect in ["outcome", "die", "face"]:
		var bad: Dictionary = DataLoader.get_item("fixture:b036_brittle_wand").last_charge_aftermath.duplicate(true)
		match defect:
			"outcome": bad.outcome = "explode"
			"die": bad.roll.die = 7
			"face": bad.roll.trigger_on = [21]
		check.call(not LastChargeRules.validate(bad).is_empty(), "036 S-060 malformed aftermath %s refuses" % defect)
	check.call(not LastChargeRules.saved_state_error("fixture:b036_brittle_wand", {"charges": 0, "degraded": true, "magical": false}).is_empty() and not LastChargeRules.saved_state_error("fixture:b036_spent_rod", {"charges": 2, "degraded": true, "magical": false}).is_empty() and LastChargeRules.saved_state_error("fixture:b036_spent_rod", {"charges": 2}).is_empty(), "036 S-060 saved degradation is valid only for a declared degrade at zero charges; legacy state loads")
