class_name Batch077Checks
extends RefCounted
## Batch 077 (#39 follow-up, S-127): data-declared choice duration. Brandon:
## "ask on every swing for a choice that applies to one attack. Carry it across
## the Attack action only when the feature says it lasts that long."

static func load_fixtures() -> void:
	if not DataLoader.get_character_class("fixture:b077_class").is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_077/classes/swing_choice.json", "class")

static func feature(index: int) -> Dictionary:
	return DataLoader.get_character_class("fixture:b077_class").features_by_level["1"][index].duplicate(true)

static func _actor(id: String) -> Character:
	var a := Batch031Checks._character(id, 60)
	for i in 3: a.features.append(feature(i))
	return a

static func run(check: Callable) -> void:
	load_fixtures()
	Batch067Checks.load_fixtures()
	var each := feature(0)
	var whole := feature(1)
	var whole_hit := feature(2)
	check.call([each, whole, whole_hit].all(func(r): return AttackProfileRules.validate_rule(r).is_empty()), "077 authored per-attack and per-Attack-action rules validate")
	var bad := each.duplicate(true)
	bad["choice_duration"] = "turn"
	var orphan := {"id": "x", "type": "attack_profile", "source_instance_id": "b077:x", "scope": {"kind": "weapon"}, "choice_duration": "attack_action", "replace": {"damage_type": "fire"}}
	check.call(not AttackProfileRules.validate_rule(bad).is_empty() and not AttackProfileRules.validate_rule(orphan).is_empty(), "077 an unknown duration, or a duration without choices, is refused")
	var legacy := Batch067Checks.feature(0)
	check.call(not legacy.has("choice_duration") and AttackProfileRules.validate_rule(legacy).is_empty(), "077 existing data without choice_duration still validates")
	var a := _actor("b077_owner")
	var sword := DataLoader.get_item("longsword")
	var short := DataLoader.get_item("shortsword")
	var mace := DataLoader.get_item("mace")
	check.call(AttackProfileRules.damage_type_choice(a, sword).get("duration") == "attack" and AttackProfileRules.damage_type_choice(a, short).get("duration") == "attack_action" and AttackProfileRules.damage_type_choice(a, mace).get("duration") == "attack_action", "077 each choice reports its declared duration")
	var l := Batch031Checks._character("b077_legacy")
	l.features.append(legacy)
	check.call(AttackProfileRules.damage_type_choice(l, sword).get("duration") == "attack" and AttackProfileRules.carry_record(l, sword, "force").is_empty(), "077 a rule that omits choice_duration lasts one attack and never carries")
	# Per attack: nothing is kept, so the next swing must ask.
	check.call(AttackProfileRules.carry_record(a, sword, "force").is_empty() and AttackProfileRules.carried_choice(a, sword, {"source_instance_id": "b077:each_swing", "damage_type": "force"}).is_empty(), "077 a per-attack pick is never carried to the next swing, even if a record is forged")
	# Per Attack action: carried from the same source while still eligible.
	var rec := AttackProfileRules.carry_record(a, short, "force")
	check.call(rec == {"source_instance_id": "b077:whole_action", "damage_type": "force"} and AttackProfileRules.carried_choice(a, short, rec) == "force", "077 a per-Attack-action pick is kept and carried")
	check.call(AttackProfileRules.carry_record(a, short, "").is_empty() and AttackProfileRules.carry_record(a, short, "psychic").is_empty(), "077 no pick, or an unoffered type, is never kept")
	check.call(AttackProfileRules.carried_choice(a, sword, rec).is_empty() and AttackProfileRules.carried_choice(a, mace, rec).is_empty(), "077 a carry from one source does not leak to another source's weapon")
	var b := _actor("b077_left")
	b.features = b.features.filter(func(f): return str(f.get("source_instance_id", "")) != "b077:whole_action")
	check.call(AttackProfileRules.carried_choice(b, short, rec).is_empty(), "077 a carry whose source left is not reused")
	# Hit window + attack_action: a carried pick skips the request and applies.
	var hit_rec := AttackProfileRules.carry_record(a, mace, "cold")
	var carried := AttackProfileRules.carried_choice(a, mace, hit_rec)
	var r := {}
	for _i in 20:
		r = CombatAction.resolve_weapon_attack(a, {"id": "b077_t", "name": "Dummy", "armor_class": -100, "current_hp": 500, "max_hp": 500, "is_alive": true, "conditions": {}}, mace, false, false, {AttackProfileRules.ALLOW_KEY: true, AttackProfileRules.DECISION_KEY: carried})
		if r.get("hit", false): break
	check.call(carried == "cold" and not r.has("attack_profile_choice_request") and Batch067Checks._dtype(r) == "cold", "077 a carried hit-window pick applies to the next swing without a new request")
