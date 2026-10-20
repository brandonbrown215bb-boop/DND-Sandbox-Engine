class_name Batch035Checks
extends RefCounted

static func load_fixtures() -> void:
	if not DataLoader.get_monster("fixture:b035_drainer").is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_035/classes/profile.json", "class")
	DataLoader._load_json_file("res://data/fixtures/batch_035/monsters/drainer.json", "monster")

static func feature(index: int) -> Dictionary:
	return DataLoader.get_character_class("fixture:b035_class").features_by_level["1"][index].duplicate(true)

static func drain_rule() -> Dictionary:
	return DataLoader.get_monster("fixture:b035_drainer").attacks[0].extra_effects[0].rule.duplicate(true)

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "035 neutral profile class and max-HP creature load: %s" % str(DataLoader.get_load_errors()))
	_max_hp(check)
	_profiles(check)
	review_stress(check)

static func _max_hp(check: Callable) -> void:
	var rule := drain_rule()
	var a := Batch031Checks._character("b035_hp", 40)
	var r := MaxHpSourceRules.apply(a, rule, "drainer_a:b035:hollow", 6)
	check.call(a.max_hp == 34 and a.current_hp == 34 and r.delta == -6, "035 S-130 reduction lowers maximum and clamps current HP")
	MaxHpSourceRules.apply(a, rule, "drainer_b:b035:hollow", 5)
	check.call(a.max_hp == 29 and a.max_hp_sources.size() == 2, "035 S-130 equivalent rule from a second source instance is owned separately")
	MaxHpSourceRules.remove(a, "drainer_a:b035:hollow")
	check.call(a.max_hp == 35 and a.max_hp_sources.has("drainer_b:b035:hollow"), "035 S-130 removing one equivalent source reverts only its own delta")
	MaxHpSourceRules.apply(a, rule, "drainer_b:b035:hollow", 4)
	check.call(a.max_hp == 31 and int(a.max_hp_sources["drainer_b:b035:hollow"].requested) == 9, "035 S-130 accumulating source adds to its own request")
	var receipts := MaxHpSourceRules.on_event(a, "turn_started")
	check.call(a.max_hp == 30 and receipts.size() == 1, "035 S-130 periodic reduction grows on its declared event")
	var floor_actor := Batch031Checks._character("b035_floor", 10)
	r = MaxHpSourceRules.apply(floor_actor, rule, "big:b035:hollow", 50)
	check.call(floor_actor.max_hp == 1 and r.clamped and int(floor_actor.max_hp_sources["big:b035:hollow"].applied) == -9, "035 S-130 floor clamps applied delta; requested amount is retained")
	MaxHpSourceRules.remove(floor_actor, "big:b035:hollow")
	check.call(floor_actor.max_hp == 10, "035 S-130 clamped source reverts exactly what it applied")
	var inc := {"id": "b035:bolster", "kind": "increase", "amount": 5, "raise_current": true}
	var b := Batch031Checks._character("b035_inc", 20)
	MaxHpSourceRules.apply(b, inc, "ally1:b035:bolster")
	MaxHpSourceRules.apply(b, inc, "ally1:b035:bolster")
	check.call(b.max_hp == 25 and b.current_hp == 25, "035 S-130 non-accumulating reapplication of the same source does not stack")
	MaxHpSourceRules.apply(b, inc, "ally2:b035:bolster")
	MaxHpSourceRules.remove(b, "ally1:b035:bolster")
	check.call(b.max_hp == 25 and b.current_hp == 25, "035 S-130 second equivalent increase survives the first's removal")
	var protected := Batch031Checks._character("b035_aura", 20)
	protected.aura_of_life_sources.append("aura:test")
	r = MaxHpSourceRules.apply(protected, rule, "x:b035:hollow", 5)
	check.call(not r.applied and protected.max_hp == 20, "035 S-130 maximum protection refuses reduction")
	# Save round trip, malformed DTOs and legacy load.
	var dto := a.to_dict()
	check.call(MaxHpSourceRules.saved_error(dto).is_empty(), "035 S-130 live sources produce a valid DTO")
	var back := Character.new()
	back.from_dict(dto)
	check.call(back.max_hp == a.max_hp and back.max_hp_sources == a.max_hp_sources, "035 S-130 sources restore without replaying deltas")
	for defect in ["kind", "sign", "over", "event", "field", "total"]:
		var bad := dto.duplicate(true)
		var e: Dictionary = bad.max_hp_sources["drainer_b:b035:hollow"]
		match defect:
			"kind": e.kind = "drain"
			"sign": e.applied = 3
			"over": e.applied = -999
			"event": e.cure_on = ["sunrise"]
			"field": e["extra"] = 1
			"total": bad.max_hp = -100
		check.call(not MaxHpSourceRules.saved_error(bad).is_empty(), "035 S-130 malformed saved source %s refuses" % defect)
	var legacy := dto.duplicate(true)
	legacy.erase("max_hp_sources")
	check.call(MaxHpSourceRules.saved_error(legacy).is_empty(), "035 S-130 legacy DTO without sources validates")
	# Real completed Long Rest cures declared sources before HP restoration.
	a.current_hp = 5
	RestRules.complete_long_rest([a], {"allow_in_test": true, "skip_campaign_time": true})
	check.call(a.max_hp == 40 and a.max_hp_sources.is_empty() and a.current_hp == 40, "035 S-130 real Long Rest cures the reduction and restores to the cured maximum")
	# Production monster rider consumer.
	var monster := DataLoader.get_monster("fixture:b035_drainer").duplicate(true)
	monster["id"] = "b035_live"
	var t := Batch031Checks._character("b035_victim", 30)
	var results := CombatAction.resolve_monster_attack_effects(monster, t, monster.attacks[0], {"hit": true, "damage": 6})
	check.call(t.max_hp == 24 and t.max_hp_sources.has("b035_live:b035:hollow") and results[0].receipt.delta == -6, "035 S-130 monster attack rider applies damage-dealt reduction owned by the exact creature")
	for defect in ["kind", "amount", "periodic_inc", "cure"]:
		var bad := drain_rule()
		match defect:
			"kind": bad.kind = "drain"
			"amount": bad.amount = "half"
			"periodic_inc": bad.kind = "increase"
			"cure": bad.cure_on = ["dawn"]
		check.call(not MaxHpSourceRules.validate_rule(bad).is_empty(), "035 S-130 malformed rule %s refuses" % defect)

static func _profiles(check: Callable) -> void:
	var a := Batch031Checks._character("b035_profile", 30)
	a.ability_scores.from_dict({"STR": 10, "DEX": 10, "CON": 14, "INT": 10, "WIS": 18, "CHA": 10})
	a.features.append(feature(0))
	a.features.append(feature(1))
	a.features.append(feature(2))
	a.add_condition("blessed", 999)
	var sword := DataLoader.get_item("longsword")
	var p := AttackProfileRules.apply_weapon(a, sword, {"attack_profile_damage_type": "radiant"})
	check.call(p.ability == "WIS" and str(p.damage).begins_with("1d10") and p.damage_type == "radiant" and p._attack_profile.sources.size() == 2, "035 S-126 first qualifying source replaces ability/die/chosen type")
	check.call(int(p.attack_bonus_override) == a.ability_scores.get_ability_modifier("WIS") + a.proficiency_bonus + 1 and str(p.damage).ends_with("+2"), "035 S-126 additive attack/damage bonuses apply on the replaced ability")
	check.call(DataLoader.get_item("longsword").damage == "1d8" and DataLoader.get_item("longsword").damage_type == "slashing" and not DataLoader.get_item("longsword").has("attack_bonus_override"), "035 S-126 catalog weapon record is unchanged")
	p = AttackProfileRules.apply_weapon(a, sword, {"attack_profile_damage_type": "psychic"})
	check.call(p.damage_type == "slashing", "035 S-126 an unoffered damage-type choice keeps the inherited type")
	a.remove_condition("blessed")
	p = AttackProfileRules.apply_weapon(a, sword)
	check.call(p.get("ability", "STR") != "WIS" and p.damage_type == "fire" and p._attack_profile.sources == ["b035:edge"], "035 S-126 condition-gated source drops out; the remaining source still applies")
	var bow := DataLoader.get_item("shortbow")
	p = AttackProfileRules.apply_weapon(a, bow)
	check.call(not p.has("_attack_profile") and p.damage_type == bow.damage_type, "035 S-126 unrelated weapon is inherited unchanged")
	# Real weapon attack resolution.
	a.add_condition("blessed", 999)
	var target := {"id": "b035_dummy", "name": "Dummy", "armor_class": -100, "current_hp": 500, "max_hp": 500, "is_alive": true, "conditions": {}}
	var res := CombatAction.resolve_weapon_attack(a, target, sword, false, false, {"attack_profile_damage_type": "force"})
	check.call(res.get("hit", false) and str(res.get("activity_damage", {}).get("type", "")) == "force", "035 S-126 actual weapon attack settles with the profile's chosen damage type")
	# Spell DC.
	var base := a.get_spell_save_dc()
	check.call(SpellPermissionRules.save_dc(a, {"id": "x", "school": "evocation"}) == base + 2 and SpellPermissionRules.save_dc(a, {"id": "y", "school": "enchantment"}) == base, "035 S-126 spell DC add is scoped to the qualifying school")
	var fixed := {"id": "fixture:b035_fixed", "type": "attack_profile", "source_instance_id": "b035:fixed", "scope": {"kind": "spell", "ids": ["x"]}, "replace": {"save_dc": 17}}
	a.features.append(fixed)
	check.call(SpellPermissionRules.save_dc(a, {"id": "x", "school": "evocation"}) == 19, "035 S-126 fixed DC replacement plus compatible addition apply once each")
	for defect in ["scope", "replace", "add", "spell_field", "weapon_dc", "die", "empty"]:
		var bad := feature(0)
		match defect:
			"scope": bad.scope.kind = "cantrip"
			"replace": bad.replace["range"] = 30
			"add": bad["add"] = {"attack_bonus": "lots"}
			"spell_field": bad.scope.kind = "spell"
			"weapon_dc": bad.replace["save_dc"] = 14
			"die": bad.replace.damage_die = "1d7"
			"empty": bad.erase("replace")
		check.call(not AttackProfileRules.validate_rule(bad).is_empty(), "035 S-126 malformed profile %s refuses" % defect)

## Reviewer stress cases (Batch 035 review).
static func review_stress(check: Callable) -> void:
	load_fixtures()
	var red := {"id": "rv:red", "kind": "reduction", "amount": 0}
	var inc := {"id": "rv:inc", "kind": "increase", "amount": 0, "raise_current": true}
	# ST1 two reductions under the floor: removing one restores the other's full request.
	var a := Batch031Checks._character("rv_a", 10)
	MaxHpSourceRules.apply(a, red, "x:a", 8)
	MaxHpSourceRules.apply(a, red, "y:b", 5)
	check.call(a.max_hp == 1, "035 review ST1 stacked reductions clamp at floor (max=%d)" % a.max_hp)
	MaxHpSourceRules.remove(a, "x:a")
	check.call(a.max_hp == 5, "035 review ST1 removing one clamped reduction re-honors the other's request (max=%d, want 5)" % a.max_hp)
	MaxHpSourceRules.remove(a, "y:b")
	check.call(a.max_hp == 10 and a.max_hp_sources.is_empty(), "035 review ST1 removing all reductions restores the natural maximum (max=%d)" % a.max_hp)
	# ST2 increase then over-floor reduction, removed in either order, never drifts.
	var b := Batch031Checks._character("rv_b", 10)
	MaxHpSourceRules.apply(b, inc, "s:inc", 5)
	MaxHpSourceRules.apply(b, red, "s:red", 20)
	check.call(b.max_hp == 1, "035 review ST2 reduction past increase clamps to floor (max=%d)" % b.max_hp)
	MaxHpSourceRules.remove(b, "s:inc")
	check.call(b.max_hp == 1, "035 review ST2 removing the increase keeps floor (max=%d)" % b.max_hp)
	MaxHpSourceRules.remove(b, "s:red")
	check.call(b.max_hp == 10, "035 review ST2 no drift after both removals (max=%d, want 10)" % b.max_hp)
	# ST3 increase with raise_current; removal clamps current; reduction never raises current.
	var c := Batch031Checks._character("rv_c", 20)
	MaxHpSourceRules.apply(c, inc, "c:inc", 5)
	check.call(c.max_hp == 25 and c.current_hp == 25, "035 review ST3 raise_current increase raises current by the change")
	MaxHpSourceRules.apply(c, inc, "c:inc", 3)
	check.call(c.max_hp == 25, "035 review ST3 non-accumulating increase does not stack or shrink on smaller re-apply (max=%d)" % c.max_hp)
	MaxHpSourceRules.remove(c, "c:inc")
	check.call(c.max_hp == 20 and c.current_hp == 20, "035 review ST3 removing the increase clamps current HP")
	# ST4 downed actor: increase with raise_current does not revive.
	var d := Batch031Checks._character("rv_d", 20)
	d.current_hp = 0
	MaxHpSourceRules.apply(d, inc, "d:inc", 5)
	check.call(d.current_hp == 0 and d.max_hp == 25, "035 review ST4 increase does not revive a 0-HP actor")
	# ST5 refusal before cost: protected maximum creates no entry and changes nothing.
	var e := Batch031Checks._character("rv_e", 20)
	e.aura_of_life_sources.append("aura:x")
	var r := MaxHpSourceRules.apply(e, red, "e:red", 6)
	check.call(not r.applied and e.max_hp == 20 and e.max_hp_sources.is_empty(), "035 review ST5 protected reduction is refused before any change")
	r = MaxHpSourceRules.apply(e, {"id": "bad", "kind": "reduction", "amount": -3}, "e:bad", -1)
	check.call(not r.applied and e.max_hp_sources.is_empty(), "035 review ST5 malformed rule is refused before any change")
	# ST6 legacy DTO without the field and garbage DTO.
	var f := Batch031Checks._character("rv_f", 30)
	var legacy := f.to_dict()
	legacy.erase("max_hp_sources")
	check.call(MaxHpSourceRules.saved_error(legacy).is_empty(), "035 review ST6 legacy DTO without max_hp_sources validates")
	var g := Character.new()
	g.from_dict(legacy)
	check.call(g.max_hp == 30 and g.max_hp_sources.is_empty(), "035 review ST6 legacy DTO restores natural maximum with no sources")
	var bad := legacy.duplicate(true)
	bad["max_hp_sources"] = {"z": {"rule_id": "r", "kind": "increase", "requested": 3, "applied": 9, "accumulate": false, "floor": 1, "cure_on": [], "periodic": {}, "raise_current": false}}
	check.call(not MaxHpSourceRules.saved_error(bad).is_empty(), "035 review ST6 contradictory increase DTO is refused")
	# ST7 round trip with clamped sources keeps exact removal semantics.
	var h := Batch031Checks._character("rv_h", 10)
	MaxHpSourceRules.apply(h, red, "h:a", 8)
	MaxHpSourceRules.apply(h, red, "h:b", 5)
	var dto := h.to_dict()
	check.call(MaxHpSourceRules.saved_error(dto).is_empty(), "035 review ST7 clamped DTO validates")
	var h2 := Character.new()
	h2.from_dict(dto)
	MaxHpSourceRules.remove(h2, "h:a")
	MaxHpSourceRules.remove(h2, "h:b")
	check.call(h2.max_hp == 10, "035 review ST7 reloaded clamped sources revert to natural maximum (max=%d)" % h2.max_hp)
	# ST8 periodic growth honors protection and floor; cure removes exactly.
	var k := Batch031Checks._character("rv_k", 5)
	var rule := drain_rule()
	MaxHpSourceRules.apply(k, rule, "k:drain", 3)
	for _i in 10: MaxHpSourceRules.on_event(k, "turn_started")
	check.call(k.max_hp == 1, "035 review ST8 periodic growth stops at floor (max=%d)" % k.max_hp)
	MaxHpSourceRules.on_event(k, "long_rest_completed")
	check.call(k.max_hp == 5 and k.max_hp_sources.is_empty(), "035 review ST8 cure restores exact natural maximum (max=%d)" % k.max_hp)
	# ST9 profile does not leak into an unrelated actor or the catalog after use.
	var p := Batch031Checks._character("rv_p", 20)
	p.features.append(feature(1))
	var sword := DataLoader.get_item("longsword")
	var prof := AttackProfileRules.apply_weapon(p, sword)
	var q := Batch031Checks._character("rv_q", 20)
	check.call(prof.get("damage_type") == "fire" and AttackProfileRules.apply_weapon(q, sword).get("damage_type") == "slashing" and sword.damage_type == "slashing", "035 review ST9 profile is scoped to its owner and never mutates the catalog")
