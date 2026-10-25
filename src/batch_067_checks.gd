class_name Batch067Checks
extends RefCounted
## Batch 067 (S-127): authored weapon damage-type choices. The rule names its
## window (activation or hit) in data; the choice changes only that attack's
## profile; cancelling or a stale choice spends nothing; a hit request settles once.

static func load_fixtures() -> void:
	if not DataLoader.get_character_class("fixture:b067_class").is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_067/classes/weapon_choice.json", "class")

static func feature(index: int) -> Dictionary:
	return DataLoader.get_character_class("fixture:b067_class").features_by_level["1"][index].duplicate(true)

static func _actor(id: String) -> Character:
	var a := Batch031Checks._character(id, 60)
	a.features.append(feature(0))
	a.features.append(feature(1))
	return a

static func _target(id: String) -> Dictionary:
	return {"id": id, "name": "Dummy", "armor_class": -100, "current_hp": 500, "max_hp": 500, "is_alive": true, "conditions": {}}

static func _hit(a: Character, target: Dictionary, weapon: Dictionary, decisions: Dictionary) -> Dictionary:
	# A natural 1 always misses; retry so the check exercises the hit stage.
	for _i in 20:
		var r := CombatAction.resolve_weapon_attack(a, target, weapon, false, false, decisions.duplicate(true))
		if r.get("hit", false): return r
	return {}

static func run(check: Callable) -> void:
	load_fixtures()
	var activation := feature(0)
	var hit_rule := feature(1)
	check.call(AttackProfileRules.validate_rule(activation).is_empty() and AttackProfileRules.validate_rule(hit_rule).is_empty(), "067 authored activation and hit window rules validate")
	var no_window := activation.duplicate(true)
	no_window.erase("choice_window")
	var bad_window := activation.duplicate(true)
	bad_window["choice_window"] = "damage"
	var orphan_window := {"id": "x", "type": "attack_profile", "source_instance_id": "b067:x", "scope": {"kind": "weapon"}, "choice_window": "hit", "replace": {"damage_type": "fire"}}
	var both := activation.duplicate(true)
	both.replace["damage_type"] = "fire"
	check.call(not AttackProfileRules.validate_rule(no_window).is_empty() and not AttackProfileRules.validate_rule(bad_window).is_empty(), "067 a choice without an authored window, or an unknown window, is refused (no engine default)")
	check.call(not AttackProfileRules.validate_rule(orphan_window).is_empty() and not AttackProfileRules.validate_rule(both).is_empty(), "067 a window without choices, or a fixed type alongside choices, is refused")
	var errors_before := DataLoader._load_errors.size()
	DataLoader._load_json_file("res://data/fixtures/batch_067/classes/bad_window.json", "class")
	var loaded_bad: Dictionary = DataLoader.get_character_class("fixture:b067_bad_class")
	var loader_refused: bool = DataLoader._load_errors.size() > errors_before and str(DataLoader._load_errors[-1]).contains("choice_window") and loaded_bad.get("features_by_level", {}).get("1", []).is_empty()
	DataLoader._load_errors.resize(errors_before)
	check.call(loader_refused, "067 the loader refuses a damage-type choice that declares no window")

	var a := _actor("b067_owner")
	var sword := DataLoader.get_item("longsword")
	var axe := DataLoader.get_item("handaxe")
	var bow := DataLoader.get_item("shortbow")
	var sword_choice := AttackProfileRules.damage_type_choice(a, sword)
	var axe_choice := AttackProfileRules.damage_type_choice(a, axe)
	check.call(sword_choice.get("window") == "activation" and sword_choice.get("options") == ["radiant", "force"] and axe_choice.get("window") == "hit" and axe_choice.get("options") == ["cold", "lightning"], "067 each qualifying weapon offers its own authored window and eligible types")
	check.call(AttackProfileRules.damage_type_choice(a, bow).is_empty() and AttackProfileRules.damage_type_choice(Batch031Checks._character("b067_plain"), sword).is_empty(), "067 unrelated weapons and other actors are offered nothing")
	var fixed := {"id": "b067_fixed", "type": "attack_profile", "source_instance_id": "b067:fixed", "scope": {"kind": "weapon", "ids": ["longsword"]}, "replace": {"damage_type": "fire"}}
	var b := Batch031Checks._character("b067_fixed_owner")
	b.features.append(fixed)
	b.features.append(feature(0))
	check.call(AttackProfileRules.damage_type_choice(b, sword).is_empty(), "067 a first-winning fixed type means no choice is offered (first source wins)")

	# Activation window: stale rechecks.
	check.call(AttackProfileRules.activation_choice_error(a, sword, sword_choice, "force").is_empty() and not AttackProfileRules.activation_choice_error(a, sword, sword_choice, "psychic").is_empty(), "067 an offered type passes the recheck; an unoffered type is refused")
	var c := _actor("b067_stale")
	c.features = c.features.filter(func(f): return str(f.get("source_instance_id", "")) != "b067:declared")
	check.call(not AttackProfileRules.activation_choice_error(c, sword, sword_choice, "force").is_empty(), "067 a choice whose source left after it was offered is stale")

	# Activation decision changes only that attack.
	var t1 := _target("b067_t1")
	var r1 := _hit(a, t1, sword, {AttackProfileRules.DECISION_KEY: "force"})
	var r2 := _hit(a, t1, sword, {})
	check.call(_dtype(r1) == "force" and _dtype(r2) == "slashing", "067 the chosen type applies to that attack only; the next attack inherits the weapon type")
	check.call(str(sword.get("damage_type")) == "slashing" and str(DataLoader.get_item("longsword").get("damage_type")) == "slashing" and not DataLoader.get_item("longsword").has("_attack_profile"), "067 the catalog weapon is never mutated")

	# Hit window: captured before damage, once-only resume.
	var t2 := _target("b067_t2")
	var pending := {}
	for _i in 20:
		pending = CombatAction.resolve_weapon_attack(a, t2, axe, false, false, {AttackProfileRules.ALLOW_KEY: true})
		if pending.has("attack_profile_choice_request"): break
	check.call(pending.has("attack_profile_choice_request") and int(pending.get("damage", 0)) == 0 and pending.attack_profile_choice_request.options == ["cold", "lightning"], "067 a hit-window rule pauses after the hit and before any damage")
	var settled := AttackProfileRules.resume_hit_choice(pending, "lightning")
	check.call(settled.get("hit", false) and _dtype(settled) == "lightning" and int(settled.get("damage", 0)) > 0, "067 the chosen hit-window type settles the captured hit's damage")
	var replay := AttackProfileRules.resume_hit_choice(pending, "cold")
	check.call(bool(replay.get("refused", false)) and int(replay.get("damage", 0)) == 0, "067 a hit-window request settles once; a replay deals nothing")
	var t3 := _target("b067_t3")
	var pending2 := {}
	for _i in 20:
		pending2 = CombatAction.resolve_weapon_attack(a, t3, axe, false, false, {AttackProfileRules.ALLOW_KEY: true})
		if pending2.has("attack_profile_choice_request"): break
	var cancelled := AttackProfileRules.resume_hit_choice(pending2, "")
	check.call(cancelled.get("hit", false) and _dtype(cancelled) == "slashing" and int(cancelled.get("damage", 0)) > 0, "067 dismissing the hit-window choice keeps the weapon's own type and costs nothing")
	var d := _actor("b067_hit_stale")
	var t4 := _target("b067_t4")
	var pending3 := {}
	for _i in 20:
		pending3 = CombatAction.resolve_weapon_attack(d, t4, axe, false, false, {AttackProfileRules.ALLOW_KEY: true})
		if pending3.has("attack_profile_choice_request"): break
	d.features = d.features.filter(func(f): return str(f.get("source_instance_id", "")) != "b067:striking")
	var stale := AttackProfileRules.resume_hit_choice(pending3, "cold")
	check.call(bool(stale.get("attack_profile_choice_stale", false)) and _dtype(stale) == "slashing", "067 a hit-window choice whose source left before settlement is stale and keeps the inherited type")
	var t5 := _target("b067_t5")
	var unhosted := _hit(a, t5, axe, {})
	check.call(not unhosted.has("attack_profile_choice_request") and _dtype(unhosted) == "slashing", "067 a caller that does not host the choice settles with the inherited type")
	var miss := CombatAction.resolve_weapon_attack(a, {"id": "b067_wall", "name": "Wall", "armor_class": 1000, "current_hp": 10, "max_hp": 10, "is_alive": true, "conditions": {}}, axe, false, false, {AttackProfileRules.ALLOW_KEY: true})
	check.call(not miss.has("attack_profile_choice_request") and not miss.get("hit", true), "067 a miss offers no hit-window choice")

static func _dtype(r: Dictionary) -> String:
	return str(r.get("activity_damage", {}).get("type", r.get("damage_type", "")))
