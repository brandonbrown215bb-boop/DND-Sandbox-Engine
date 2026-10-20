class_name Batch049Checks
extends RefCounted
## Batch 049 (card Q-20261020-154337-209c): species, species-feat and exact
## equipped/attuned item copies own mode_choice/rule_upgrade features.

const KIN := "fixture:b049_kin"
const FEAT := "fixture:b049_feat"
const CIRCLET := "fixture:b049_circlet"
const ASPECT := "fixture:b049_kin_aspect"
const SURGE := "fixture:b049_feat_surge"

static func load_fixtures() -> void:
	Batch048Checks.load_fixtures()
	if not DataLoader.get_item(CIRCLET).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_049/feats/surge.json", "feat")
	DataLoader._load_json_file("res://data/fixtures/batch_049/races/kin.json", "race")
	DataLoader._load_json_file("res://data/fixtures/batch_049/items/circlet.json", "item")

static func focus(id: String) -> String:
	return "focus@" + id

## A kin actor: species acquisition runs through the production initialize path.
static func actor(id: String) -> Character:
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 12, "DEX": 14, "CON": 14, "INT": 10, "WIS": 12, "CHA": 10})
	var a := Character.new()
	a.initialize(id, KIN, "fighter", scores)
	a.character_id = id
	a.max_hp = 40
	a.current_hp = 40
	return a

## Equip a fresh circlet on the head; attune when asked. Returns the copy id.
static func wear(a: Character, attune: bool = true) -> String:
	var id := Batch041Checks.add_copy(a, CIRCLET)
	a.inventory.equip_instance(Inventory.Slot.HEAD, id)
	if attune: a.inventory.attune_instance(id, a.character_id)
	return id

static func _loads(data: Dictionary, kind: String) -> bool:
	var before := DataLoader._load_errors.size()
	var ok: bool = DataLoader._validate_content(data, kind, "batch_049_probe")
	DataLoader._load_errors.resize(before)
	return ok

static func _ids(a: Character) -> Array:
	return a.features.map(func(f): return str(f.get("id", "")))

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty() and not DataLoader.get_feat(FEAT).is_empty() and not DataLoader.get_race(KIN).is_empty(), "049 feat, species and item feature fixtures load: %s" % str(DataLoader.get_load_errors()))
	_loader(check)
	_species_and_feat(check)
	_item_copy(check)
	_reload(check)
	_unowned(check)
	_legacy(check)

static func _loader(check: Callable) -> void:
	var item := DataLoader.get_item(CIRCLET).duplicate(true)
	for key in ["_source", "_source_record"]: item.erase(key)
	var passive := item.duplicate(true)
	passive.features.append({"id": "aura", "name": "Aura", "type": "passive"})
	var at := item.duplicate(true)
	at.features[0]["id"] = "fo@cus"
	var foreign := item.duplicate(true)
	foreign.features[1]["rule"] = "fixture:b038_stance"
	var pinned := item.duplicate(true)
	pinned.features[0]["source_instance_id"] = "x"
	var race := DataLoader.get_race(KIN).duplicate(true)
	for key in ["_source", "_source_record"]: race.erase(key)
	var twice := race.duplicate(true)
	twice.feats = [FEAT, FEAT]
	check.call(_loads(item, "item") and _loads(race, "race") and not _loads(passive, "item") and not _loads(at, "item") and not _loads(foreign, "item") and not _loads(pinned, "item") and not _loads(twice, "race") and not _loads({"id": "f", "name": "F"}, "feat"), "049 loader refuses unsupported, reserved, foreign-target and pinned item features, repeated species feats and featureless feats")

static func _species_and_feat(check: Callable) -> void:
	var a := actor("b049_kin")
	var human := Batch031Checks._character("b049_human")
	check.call(ASPECT in _ids(a) and SURGE in _ids(a) and "fixture:b049_feat_extra" in _ids(a) and not SURGE in _ids(human), "049 species and its granted feat acquire their declared rules; another species does not")
	check.call(a.get_feature_max_uses(SURGE) == 2 and int(a.feature_uses.get(SURGE, 0)) == 2, "049 the feat's own upgrade raises the feat activation to two uses on acquisition")
	var chosen := FeatureModeRules.choose(a, ASPECT, "stone")
	var act := FeatureModeRules.activate(a, SURGE, "brace")
	check.call(chosen.success and act.success and SourceBenefitRules.total(a, "AC") == 3 and int(a.feature_uses[SURGE]) == 1, "049 species rest mode and feat activation both grant from their own source")
	var again := OwnedFeatureSources.sync(a)
	check.call(again.is_empty() and _ids(a).count(SURGE) == 1 and SourceBenefitRules.total(a, "AC") == 3 and a.feature_modes[SURGE].active, "049 re-syncing an unchanged source neither duplicates rules nor touches state")

static func _item_copy(check: Callable) -> void:
	var a := actor("b049_item")
	var id := wear(a, false)
	var uses_before := a.feature_uses.duplicate()
	var refused := FeatureModeRules.activate(a, focus(id), "ward")
	check.call(not refused.success and a.feature_uses == uses_before and not a.feature_modes.has(focus(id)) and not focus(id) in _ids(a), "049 checklist (a): an equipped but unattuned copy owns nothing and the refusal spends no use")
	a.inventory.attune_instance(id, a.character_id)
	check.call(focus(id) in _ids(a) and a.get_feature(focus(id)).source_instance_id == id and a.get_feature_max_uses(focus(id)) == 3 and int(a.feature_uses[focus(id)]) == 3, "049 attuning the exact copy acquires its namespaced mode; the default alternative (deep) gives three uses")
	var keen := RuleUpgradeRules.choose_alternative(a, focus(id), "tuning", "keen@" + id)
	check.call(keen and a.get_feature_max_uses(focus(id)) == 2 and int(a.feature_uses[focus(id)]) == 2, "049 choosing the other item alternative clamps held uses to its new maximum")
	var too_many := FeatureModeRules.activate(a, focus(id), "ward", [a, Batch031Checks._character("b049_other")])
	check.call(not too_many.success and int(a.feature_uses[focus(id)]) == 2, "049 checklist (a): an over-target activation is refused before the use is spent")
	var on := FeatureModeRules.activate(a, focus(id), "ward")
	check.call(on.success and int(a.feature_uses[focus(id)]) == 1 and SourceBenefitRules.total(a, "AC") == 1, "049 the item copy's activation spends its own use and grants its mode")
	a.inventory.unequip(Inventory.Slot.HEAD)
	check.call(not focus(id) in _ids(a) and not a.feature_modes.has(focus(id)) and SourceBenefitRules.total(a, "AC") == 0 and int(a.feature_uses[focus(id)]) == 1 and not a.rule_alternatives.has(focus(id) + "|tuning"), "049 unequipping ends the copy's mode and alternative but keeps its spent pool")
	a.inventory.equip_instance(Inventory.Slot.HEAD, id)
	check.call(focus(id) in _ids(a) and int(a.feature_uses[focus(id)]) == 1, "049 re-equipping the same copy cannot refill its uses")
	var other := Batch041Checks.add_copy(a, CIRCLET)
	a.inventory.attune_instance(other, a.character_id)
	var dto := a.to_dict()
	dto.inventory.copies.equipped["HANDS"] = other
	var declared := OwnedFeatureSources.declared_in(dto).map(func(f): return str(f.id))
	check.call(declared.count(focus(id)) + declared.count(focus(other)) == 1, "049 two equipped copies of one item never stack their features")
	var record: Dictionary = a.inventory.get_instance(id)
	check.call(InventoryCopies.record_state_error(record).is_empty(), "049 checklist (b): the attuned copy record still passes record_state_error (no new nested record)")

static func _reload(check: Callable) -> void:
	var a := actor("b049_reload")
	var id := wear(a)
	FeatureModeRules.choose(a, ASPECT, "wind")
	FeatureModeRules.activate(a, SURGE, "dash")
	RuleUpgradeRules.choose_alternative(a, focus(id), "tuning", "keen@" + id)
	FeatureModeRules.activate(a, focus(id), "haste")
	FeatureModeRules.advance_time(a, 24)
	FeatureModeRules.on_event(a, "turn_start")
	var dto: Dictionary = JSON.parse_string(JSON.stringify(a.to_dict()))
	check.call(FeatureModeRules.saved_error(dto).is_empty() and RuleUpgradeRules.saved_error(dto).is_empty(), "049 species, feat and item mode state validate against their owned sources")
	var back := Character.new()
	back.from_dict(dto)
	var twice := Character.new()
	twice.from_dict(JSON.parse_string(JSON.stringify(back.to_dict())))
	var same := func(x: Character) -> bool: return x.feature_modes == a.feature_modes and x.rule_alternatives == a.rule_alternatives and int(x.feature_uses[SURGE]) == int(a.feature_uses[SURGE]) and int(x.feature_uses[focus(id)]) == int(a.feature_uses[focus(id)]) and _ids(x) == _ids(a) and SourceBenefitRules.total(x, "speed") == SourceBenefitRules.total(a, "speed")
	check.call(same.call(back) and same.call(twice) and SourceBenefitRules.total(back, "speed") == 4, "049 reload (twice) keeps choices, uses, deadlines and benefits exactly once")
	check.call(int(back.feature_modes[focus(id)].remaining_seconds) == 576 and int(back.feature_modes[SURGE].remaining_seconds) == 36 and FeatureModeRules.switch(back, focus(id), "ward", "turn_start").success and int(back.feature_uses[focus(id)]) == 1, "049 reloaded deadlines continue and the item's open switch window is still usable once without spending")

static func _unowned(check: Callable) -> void:
	var a := actor("b049_tamper")
	var id := wear(a)
	RuleUpgradeRules.choose_alternative(a, focus(id), "tuning", "deep@" + id)
	FeatureModeRules.activate(a, focus(id), "ward")
	FeatureModeRules.activate(a, SURGE, "brace")
	var dto: Dictionary = JSON.parse_string(JSON.stringify(a.to_dict()))
	var unattuned := dto.duplicate(true)
	unattuned.inventory.copies.records[id].state.erase("attuned_to")
	var unequipped := dto.duplicate(true)
	unequipped.inventory.copies.equipped.erase("HEAD")
	var species := dto.duplicate(true)
	species.race_id = "human"
	species.feature_modes.erase(focus(id))
	species.rule_alternatives.clear()
	var other := dto.duplicate(true)
	other.feature_modes["focus@inv_forged"] = other.feature_modes[focus(id)]
	check.call(a.rule_alternatives.has(focus(id) + "|tuning") and not FeatureModeRules.saved_error(unattuned).is_empty() and not RuleUpgradeRules.saved_error(unattuned).is_empty() and not FeatureModeRules.saved_error(unequipped).is_empty() and not FeatureModeRules.saved_error(species).is_empty() and not FeatureModeRules.saved_error(other).is_empty(), "049 saved modes and alternatives for unattuned, unequipped, wrong-species or forged copies are refused")

static func _legacy(check: Callable) -> void:
	var a := Batch031Checks._character("b049_legacy")
	var dto: Dictionary = JSON.parse_string(JSON.stringify(a.to_dict()))
	dto.erase("feature_modes")
	dto.erase("rule_alternatives")
	dto.inventory.erase("copies")
	var back := Character.new()
	back.from_dict(dto)
	check.call(FeatureModeRules.saved_error(dto).is_empty() and RuleUpgradeRules.saved_error(dto).is_empty() and back.acquired_features.is_empty() and back.feature_modes.is_empty(), "049 a legacy save with no copies, modes or alternatives still loads and acquires nothing")
