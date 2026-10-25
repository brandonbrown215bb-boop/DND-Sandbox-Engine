class_name Batch075Checks
extends RefCounted
## Batch 075 (S-162): every removal path passes its cause through
## Inventory.remove_exact; only causes the bond's loss_causes author dispose
## linked mates. Two linked pairs of identical copies prove that removing one
## copy never touches the other pair or an unlinked copy.

const CLASS_ID := "fixture:b075_class"
const PAIR_A := "b075:pair_a"
const PAIR_B := "b075:pair_b"

static func load_fixtures() -> void:
	Batch042Checks.load_fixtures()
	if not DataLoader.get_character_class(CLASS_ID).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_075/classes/linked_causes.json", "class")

static func linker(id: String) -> Character:
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 12, "DEX": 14, "CON": 14, "INT": 12, "WIS": 12, "CHA": 16})
	var c := Character.new()
	c.initialize(id, "human", CLASS_ID, scores)
	c.character_id = id
	c.max_hp = 30
	c.current_hp = 30
	return c

static func owns(actor: Character, id: String) -> bool:
	return Batch042Checks.owns(actor, id)

static func _rule(index: int) -> Dictionary:
	return DataLoader.get_character_class(CLASS_ID).features_by_level["1"][index].duplicate(true)

## Author exactly `causes` on both pairs of `actor`.
static func author(actor: Character, causes: Array) -> void:
	# Features share the loaded class records; author a private copy so the fixture stays pristine.
	for i in actor.features.size():
		var f: Variant = actor.features[i]
		if f is Dictionary and str(f.get("bond_id", "")) in [PAIR_A, PAIR_B]:
			var own: Dictionary = f.duplicate(true)
			own["loss_causes"] = causes.duplicate()
			actor.features[i] = own

## Two linked pairs plus one unlinked copy of the same definition.
static func pairs(actor: Character, definition := "dagger") -> Dictionary:
	var out := {}
	for k in ["a1", "a2", "b1", "b2", "loose"]: out[k] = Batch042Checks.add(actor, definition)
	BondRules.bond(actor, PAIR_A, out.a1)
	BondRules.bond(actor, PAIR_A, out.a2)
	BondRules.bond(actor, PAIR_B, out.b1)
	BondRules.bond(actor, PAIR_B, out.b2)
	return out

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "075 linked-cause fixture class loads: %s" % str(DataLoader.get_load_errors()))
	_validation(check)
	_matrix(check)
	_unspecified(check)
	_refusals(check)
	_saves(check)

static func _validation(check: Callable) -> void:
	check.call(BondRules.rule_error(_rule(0)).is_empty() and BondRules.rule_error(DataLoader.get_character_class(Batch042Checks.CLASS_ID).features_by_level["1"][0]).is_empty(), "075 authored loss_causes validate and 042 rules without them still validate")
	var bad := 0
	for mutate in [
		func(r): r.on_loss = "keep_survivors",
		func(r): r.loss_causes = ["melt"],
		func(r): r.loss_causes = [],
		func(r): r.loss_causes = ["sale", "sale"],
		func(r): r.loss_causes = "sale",
	]:
		var r := _rule(0)
		mutate.call(r)
		if not BondRules.rule_error(r).is_empty(): bad += 1
	check.call(bad == 5, "075 loader refuses loss_causes without dispose_group, unknown, empty, repeated or non-list causes (%d/5)" % bad)

## Remove `id` from `a` through the production path for `cause`.
static func _remove(a: Character, friend: Character, id: String, cause: String) -> bool:
	match cause:
		"give": return a.inventory.transfer_instance(id, friend.inventory)
		"drop":
			if not a.inventory.equip_instance(Inventory.Slot.WEAPON, id): return false
			return str(a.inventory.drop_equipped_instance(Inventory.Slot.WEAPON).get("instance_id", "")) == id
		"projection": return ItemProjectionRules.project(a, id).get("projected", false)
		_: return not a.inventory.remove_exact(id, cause).is_empty()

static func _matrix(check: Callable) -> void:
	for cause in Inventory.REMOVAL_CAUSES:
		for authored in [true, false]:
			var a := linker("b075_%s_%s" % [cause, authored])
			var friend := linker("b075_friend_%s_%s" % [cause, authored])
			author(a, [cause] if authored else Inventory.REMOVAL_CAUSES.filter(func(c): return c != cause))
			var def := Batch042Checks.FIGURINE if cause == "projection" else "dagger"
			var p := pairs(a, def)
			var moved := _remove(a, friend, p.a1, cause)
			var mate_gone: bool = not owns(a, p.a2)
			var others: bool = owns(a, p.b1) and owns(a, p.b2) and owns(a, p.loose) and BondRules.bonded(a, PAIR_B) == [p.b1, p.b2]
			var pair_a := BondRules.bonded(a, PAIR_A)
			var expect_a: Array = ([p.a1] if cause == "projection" else []) if authored else ([p.a1, p.a2] if cause == "projection" else [p.a2])
			check.call(moved and mate_gone == authored and others and pair_a == expect_a, "075 %s %s: removes the exact copy, %s its linked mate, never the other pair or the unlinked copy (moved=%s mate_gone=%s pair_a=%s)" % [cause, "authored" if authored else "not authored", "disposes" if authored else "keeps", moved, mate_gone, str(pair_a)])
			if authored: check.call(str(BondRules.last_disposal.get("cause", "")) == cause and BondRules.last_disposal.get("disposed", []) == [p.a2], "075 %s receipt names the cause and exactly the disposed mate" % cause)

static func _unspecified(check: Callable) -> void:
	var a := linker("b075_internal")
	author(a, Inventory.REMOVAL_CAUSES.duplicate())
	var p := pairs(a)
	a.inventory.take_instance(p.a1) # internal consumption: no authored cause
	check.call(owns(a, p.a2) and BondRules.bonded(a, PAIR_A) == [p.a2] and BondRules.bonded(a, PAIR_B) == [p.b1, p.b2], "075 an internal removal with no cause releases only that copy's bond and disposes nothing")
	var legacy := Batch042Checks.linker("b075_legacy")
	var friend := Batch042Checks.linker("b075_legacy_friend")
	var d1 := Batch042Checks.add(legacy, "dagger")
	var d2 := Batch042Checks.add(legacy, "dagger")
	BondRules.bond(legacy, Batch042Checks.PAIR, d1)
	BondRules.bond(legacy, Batch042Checks.PAIR, d2)
	legacy.inventory.transfer_instance(d1, friend.inventory)
	check.call(owns(friend, d1) and not owns(legacy, d2), "075 a legacy dispose_group rule without loss_causes keeps its authored any-loss fate")

static func _refusals(check: Callable) -> void:
	var a := linker("b075_refuse")
	author(a, Inventory.REMOVAL_CAUSES.duplicate())
	var p := pairs(a)
	var before := a.inventory.to_dict()
	var bonds := a.exclusive_bonds.duplicate(true)
	var r1 := a.inventory.remove_exact(p.a1, "melt")
	var r2 := a.inventory.remove_exact("no_such_copy", "sale")
	check.call(r1.is_empty() and r2.is_empty() and a.inventory.to_dict() == before and a.exclusive_bonds == bonds, "075 an unknown cause or missing copy refuses with nothing removed or disposed")
	var cursed := a.inventory.get_instance(p.b1)
	cursed.state["cursed_attunement"] = true
	a.inventory.update_instance(cursed)
	before = a.inventory.to_dict()
	check.call(a.inventory.remove_exact(p.b1, "sale").is_empty() and a.inventory.to_dict() == before and BondRules.bonded(a, PAIR_B) == [p.b1, p.b2], "075 a copy that cannot leave refuses the sale before any mate is disposed")
	Batch068Checks.load_fixtures()
	Batch042Checks.add(a, Batch068Checks.SAT)
	var bonded_options := ContainerRules.stow_options(a.inventory, p.a1)
	Batch043Checks.load_fixtures()
	var loose_options := ContainerRules.stow_options(a.inventory, Batch043Checks.add(a, Batch043Checks.FLASK))
	check.call(bonded_options.is_empty() and not loose_options.is_empty() and owns(a, p.a1) and owns(a, p.a2), "075 a bonded copy is still offered no carried-container compartment (unchanged 068 refusal); an unlinked flask is")

static func _saves(check: Callable) -> void:
	for form in ["dict", "json"]:
		var a := linker("b075_save_" + form)
		var p := pairs(a)
		var dto := a.to_dict()
		var back := Character.new()
		back.from_dict(dto if form == "dict" else JSON.parse_string(JSON.stringify(dto)))
		var friend := linker("b075_save_friend_" + form)
		back.inventory.transfer_instance(p.a1, friend.inventory)
		var kept: bool = owns(back, p.a2) and BondRules.bonded(back, PAIR_A) == [p.a2]
		back.inventory.destroy_instance(p.b1)
		check.call(BondRules.saved_error(dto).is_empty() and kept and not owns(back, p.b2) and owns(back, p.loose), "075 %s reload: an unauthored give keeps the mate, an authored destruction disposes exactly the other pair's mate" % form)
