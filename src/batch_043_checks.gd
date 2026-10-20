class_name Batch043Checks
extends RefCounted

const SATCHEL := "fixture:b043_satchel"
const FLASK := "fixture:b043_flask"
const BRICK := "fixture:b043_brick"
const HEX := "fixture:b043_hex_blade"
const WARD := "fixture:b043_ward_ring"

static func load_fixtures() -> void:
	Batch042Checks.load_fixtures()
	if not DataLoader.get_item(SATCHEL).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_043/items/containers_curses.json", "item")

static func carrier(id: String) -> Character:
	var c := Batch042Checks.linker(id)
	return c

static func add(actor: Character, definition: String) -> String:
	return Batch041Checks.add_copy(actor, definition)

static func owns(actor: Character, id: String) -> bool:
	return actor.inventory.owned_instances().any(func(c): return str(c.instance_id) == id)

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "043 neutral container and curse fixtures load: %s" % str(DataLoader.get_load_errors()))
	_container_validation(check)
	_containers(check)
	_container_saves(check)
	_curse_validation(check)
	_curses(check)
	_curse_saves(check)
	review_stress(check)

static func _container_validation(check: Callable) -> void:
	var policy: Dictionary = DataLoader.get_item(SATCHEL).container.duplicate(true)
	check.call(ContainerRules.policy_error(policy).is_empty(), "043 S-196 declared compartments validate")
	var bad := 0
	for mutate in [func(p): p.compartments[1].id = "main", func(p): p.compartments[0].max_count = 0, func(p): p.compartments[0].max_count = 1.5, func(p): p.compartments[0]["holds_anything"] = true, func(p): p.compartments[0].item_types = [], func(p): p.compartments[1].max_volume = -1, func(p): p["slots"] = 2]:
		var p := policy.duplicate(true)
		mutate.call(p)
		if not ContainerRules.policy_error(p).is_empty(): bad += 1
	check.call(bad == 7, "043 S-196 loader refuses duplicate, empty, fractional, unknown and negative compartment rules (%d/7)" % bad)

static func _containers(check: Callable) -> void:
	var a := carrier("b043_packer")
	var inv := a.inventory
	var bag := add(a, SATCHEL)
	var flask := add(a, FLASK)
	var record := inv.get_instance(flask)
	record.state["label"] = "b043"
	inv.update_instance(record)
	var r := ContainerRules.put(inv, bag, flask, "sleeve")
	var held := ContainerRules.contents(inv, bag, "sleeve")
	check.call(r.success and not owns(a, flask) and held.size() == 1 and str(held[0].instance_id) == flask and held[0].state.get("label", "") == "b043", "043 S-196 the exact copy moves into its compartment with identity and state")
	var brick := add(a, BRICK)
	var before := inv.to_dict()
	var refusals := [
		ContainerRules.put(inv, bag, brick, "sleeve"),
		ContainerRules.put(inv, bag, brick, "lid"),
		ContainerRules.put(inv, bag, bag, "main"),
	]
	check.call(refusals.all(func(x): return not x.success) and inv.to_dict() == before, "043 S-196 full, undeclared and self compartments refuse before anything moves")
	var b2 := add(a, BRICK)
	var first := ContainerRules.put(inv, bag, brick, "main")
	before = inv.to_dict()
	var heavy := ContainerRules.put(inv, bag, b2, "main")
	check.call(first.success and not heavy.success and "weight" in heavy.message and inv.to_dict() == before and owns(a, b2), "043 S-196 the mass limit refuses the copy that would exceed it, with nothing moved")
	var dagger := add(a, "dagger")
	check.call(not ContainerRules.put(inv, bag, dagger, "main").success and owns(a, dagger), "043 S-196 a compartment refuses item types it does not declare")
	var other := add(a, SATCHEL)
	check.call(not ContainerRules.put(inv, other, bag, "main").success and owns(a, bag), "043 S-196 nested containers are refused")
	var ring := add(a, WARD)
	inv.attune_instance(ring, a.character_id)
	check.call(not ContainerRules.put(inv, other, ring, "main").success, "043 S-196 an attuned copy is refused (wrong type or attunement), staying in hand")
	var token := add(a, BRICK)
	var bonded := BondRules.bond(a, Batch042Checks.TOTEM, token)
	check.call(bonded.get("bonded", false) and not ContainerRules.put(inv, other, token, "main").success and BondRules.is_bonded(a, Batch042Checks.TOTEM, token) and owns(a, token), "043 S-196 a bonded copy is refused so no container trigger touches its bond")
	var out := ContainerRules.remove(inv, bag, flask)
	check.call(out.success and owns(a, flask) and inv.get_instance(flask).state.get("label", "") == "b043" and ContainerRules.contents(inv, bag, "sleeve").is_empty() and inv.count_item(FLASK) == 1, "043 S-196 removal returns the same copy once")
	check.call(not ContainerRules.remove(inv, bag, flask).success and inv.count_item(FLASK) == 1, "043 S-196 removing a copy that is not inside refuses without duplicating")
	var stow := ContainerRules.stow(inv, flask)
	var back := ContainerRules.retrieve_last(inv, bag)
	check.call(stow.success and back.success and str(back.instance_id) == flask and owns(a, flask), "043 S-196 HUD stow and retrieve move the exact selected copy")
	var heir := carrier("b043_heir")
	check.call(inv.transfer_instance(bag, heir.inventory) and ContainerRules.contents(heir.inventory, bag).map(func(c): return str(c.instance_id)) == [brick], "043 S-196 giving the container carries its exact contents")

static func _container_saves(check: Callable) -> void:
	var a := carrier("b043_pack_save")
	var bag := add(a, SATCHEL)
	var flask := add(a, FLASK)
	var brick := add(a, BRICK)
	ContainerRules.put(a.inventory, bag, flask, "sleeve")
	ContainerRules.put(a.inventory, bag, brick, "main")
	var dto := a.to_dict()
	check.call(ContainerRules.saved_error(dto).is_empty() and InventoryCopies.saved_error(dto.inventory).is_empty(), "043 S-196 saved contents validate (%s)" % ContainerRules.saved_error(dto))
	var back := Character.new()
	back.from_dict(dto)
	check.call(ContainerRules.contents(back.inventory, bag, "sleeve").map(func(c): return str(c.instance_id)) == [flask] and ContainerRules.contents(back.inventory, bag, "main").map(func(c): return str(c.instance_id)) == [brick] and not owns(back, flask), "043 S-196 reload keeps exact contents per compartment")
	var records: Dictionary = dto.inventory.copies.records
	var defects := {
		"duplicate": func(d): d.inventory.copies.records[bag].state.contents.main.append(d.inventory.copies.records[bag].state.contents.sleeve[0].duplicate(true)),
		"also carried": func(d):
			d.inventory.copies.records[flask] = d.inventory.copies.records[bag].state.contents.sleeve[0].duplicate(true),
		"undeclared": func(d): d.inventory.copies.records[bag].state.contents["lid"] = [d.inventory.copies.records[bag].state.contents.main.pop_back()],
		"over limit": func(d):
			var extra: Dictionary = d.inventory.copies.records[bag].state.contents.main[0].duplicate(true)
			extra.instance_id = "bag_foreign:9"
			d.inventory.copies.records[bag].state.contents.main.append(extra),
		"non-container": func(d):
			var host: Dictionary = d.inventory.copies.records[bag]
			host.definition_id = FLASK,
		"future serial": func(d): d.inventory.copies.records[bag].state.contents.main[0].instance_id = "%s:999" % d.inventory.copies.inventory_id,
	}
	var refused := 0
	for label in defects:
		var bad := dto.duplicate(true)
		defects[label].call(bad)
		if not ContainerRules.saved_error(bad).is_empty(): refused += 1
	check.call(refused == 6, "043 S-196 saved contents refuse duplicated, re-carried, undeclared, over-limit, non-container and future-serial copies (%d/6)" % refused)
	var party := {"party": {"characters": {"a": dto, "b": dto.duplicate(true)}}}
	party.party.characters.b.inventory.copies.records = {}
	party.party.characters.b.inventory.copies.records[bag + "x"] = {"state": {"contents": {"main": [{"instance_id": brick}]}}}
	check.call(not InventoryCopies.ownership_error(party).is_empty(), "043 S-196 one contained copy can't be owned by two characters")

static func _curse_validation(check: Callable) -> void:
	var item: Dictionary = DataLoader.get_item(HEX).duplicate(true)
	check.call(CurseRules.policy_error(item).is_empty(), "043 S-202 declared curse validates")
	var bad := 0
	for mutate in [func(i): i.cursed = false, func(i): i.curse.removal = "sometimes", func(i): i.curse.erase("break"), func(i): i.curse["break"].spells = ["no_such_spell"], func(i): i.curse["break"].min_slot_level = 12, func(i): i.curse.lingering = {"blocks_everything": true}]:
		var i := item.duplicate(true)
		mutate.call(i)
		if not CurseRules.policy_error(i).is_empty(): bad += 1
	check.call(bad == 6, "043 S-202 loader refuses uncursed, unknown removal, missing/unknown/too-high breaks and unknown lingering (%d/6)" % bad)

static func _curses(check: Callable) -> void:
	var a := carrier("b043_cursed")
	var inv := a.inventory
	var blade := add(a, HEX)
	var spare := add(a, HEX)
	inv.attune_instance(blade, a.character_id)
	check.call(inv.equip_instance(Inventory.Slot.WEAPON, blade) and not inv.unattune_instance(blade, a.character_id).success, "043 S-202 voluntary unattunement of the cursed copy is refused")
	var off := inv.unequip(Inventory.Slot.WEAPON)
	check.call(off == HEX and owns(a, blade) and CurseRules.is_cursed(inv.get_instance(blade)) and not inv.transfer_instance(blade, carrier("b043_taker").inventory), "043 S-202 a removal-allowed curse lets the copy be unequipped but the curse stays on it")
	check.call(not CurseRules.is_cursed(inv.get_instance(spare)) and inv.get_instance(spare).state.get("attuned_to", "") == "", "043 S-202 another copy of the same item stays independent")
	var weak := CurseRules.break_with(a, "remove_curse", 3)
	check.call(weak.broken.is_empty() and blade in weak.refused and CurseRules.is_cursed(inv.get_instance(blade)), "043 S-202 a cast below the declared slot level does not break the curse")
	check.call(inv.break_cursed_item_attunements(a.character_id) == 0 and CurseRules.is_cursed(inv.get_instance(blade)), "043 S-202 the legacy blanket break skips declared curses")
	inv.equip_instance(Inventory.Slot.WEAPON, blade)
	var lost := inv.drop_equipped_instance(Inventory.Slot.WEAPON)
	var ring := add(a, WARD)
	var refused := inv.attune_instance(ring, a.character_id)
	check.call(not lost.is_empty() and a.item_curses.has(blade) and not refused.success and "lingering" in refused.message, "043 S-202 losing the cursed copy leaves its lingering curse, which blocks new attunement")
	var strong := CurseRules.break_with(a, "remove_curse", 4)
	check.call(blade in strong.lingering_ended and a.item_curses.is_empty() and inv.attune_instance(ring, a.character_id).success, "043 S-202 a cast meeting the exact requirement ends the lingering curse")
	var legacy := carrier("b043_legacy")
	var sword := add(legacy, "sword_of_vengeance")
	legacy.inventory.attune_instance(sword, legacy.character_id)
	check.call(CurseRules.is_cursed(legacy.inventory.get_instance(sword)) and legacy.inventory.break_cursed_item_attunements(legacy.character_id) == 1 and not CurseRules.is_cursed(legacy.inventory.get_instance(sword)), "043 S-202 an undeclared legacy cursed item keeps its existing break route")

static func _curse_saves(check: Callable) -> void:
	var a := carrier("b043_curse_save")
	var blade := add(a, HEX)
	add(a, "dagger")
	a.inventory.attune_instance(blade, a.character_id)
	a.inventory.equip_instance(Inventory.Slot.WEAPON, blade)
	a.inventory.drop_equipped_instance(Inventory.Slot.WEAPON)
	var dto := a.to_dict()
	check.call(CurseRules.saved_error(dto).is_empty() and dto.item_curses.has(blade), "043 S-202 a lingering curse validates in the save (%s)" % CurseRules.saved_error(dto))
	var back := Character.new()
	back.from_dict(dto)
	var ring := add(back, WARD)
	check.call(back.item_curses.has(blade) and not back.inventory.attune_instance(ring, back.character_id).success, "043 S-202 reload keeps the lingering curse and its restriction")
	var defects := {
		"undeclared": func(d): d.item_curses[blade].definition_id = "sword_of_vengeance",
		"weakened": func(d): d.item_curses[blade].blocks_attunement = false,
		"extra": func(d): d.item_curses[blade]["cured"] = true,
		"still held": func(d): d.item_curses[d.inventory.copies.records.keys()[0]] = d.item_curses[blade].duplicate(true),
	}
	var refused := 0
	for label in defects:
		var bad := dto.duplicate(true)
		defects[label].call(bad)
		if not CurseRules.saved_error(bad).is_empty(): refused += 1
	check.call(refused == 4, "043 S-202 saved curses refuse undeclared, weakened, extended and still-held records (%d/4)" % refused)
	var legacy := dto.duplicate(true)
	legacy.erase("item_curses")
	check.call(CurseRules.saved_error(legacy).is_empty(), "043 legacy saves without item curses still validate")

const POUCH := "fixture:b043_review_pouch"

static func _stowed_dto(id: String, child_state: Dictionary) -> Dictionary:
	var c := carrier(id)
	var bag := add(c, SATCHEL)
	var flask := add(c, FLASK)
	ContainerRules.put(c.inventory, bag, flask, "main")
	var dto := c.to_dict()
	var host: Dictionary = dto.inventory.copies.records[bag]
	host.state.contents.main[0].state = child_state
	return dto

## Runtime Reviewer stress (RC1-RC8).
static func review_stress(check: Callable) -> void:
	if DataLoader.get_item(POUCH).is_empty(): DataLoader._load_json_file("res://data/fixtures/batch_043/items/review_pouch.json", "item")
	# RC1/RC2: contained copies get the same per-copy state validation as carried ones.
	var bad_food := _stowed_dto("b043_rc1", {"food_remaining_daily_fraction": 7.0})
	var bad_charges := _stowed_dto("b043_rc2", {"charges": -5})
	check.call(not ContainerRules.saved_error(bad_food).is_empty() and not ContainerRules.saved_error(bad_charges).is_empty(), "043 RC1 tampered contained copy state (ration fraction, negative charges) is refused (%s / %s)" % [ContainerRules.saved_error(bad_food), ContainerRules.saved_error(bad_charges)])
	var c := carrier("b043_rc1b")
	var bag := add(c, SATCHEL)
	var flask := add(c, FLASK)
	ContainerRules.put(c.inventory, bag, flask, "main")
	check.call(ContainerRules.saved_error(c.to_dict()).is_empty(), "043 RC2 an untampered contained copy still validates")
	# RC3: SRD 5.2.1 - stowing an attuned item does not end attunement; the copy keeps it and still counts.
	var d := carrier("b043_rc3")
	var pouch := add(d, POUCH)
	var ring := add(d, WARD)
	d.inventory.attune_instance(ring, d.character_id)
	var put := ContainerRules.put(d.inventory, pouch, ring, "main")
	var others: Array = []
	for i in 3:
		var r := add(d, WARD)
		others.append(d.inventory.attune_instance(r, d.character_id).get("success", false))
	check.call(put.get("success", false) and str(ContainerRules.contents(d.inventory, pouch)[0].state.get("attuned_to", "")) == d.character_id and others == [true, true, false], "043 RC3 an attuned copy can be stowed, stays attuned and counts toward the three-item limit (put=%s others=%s)" % [str(put.get("message", "")), str(others)])
	var ddto := d.to_dict()
	check.call(ContainerRules.saved_error(ddto).is_empty() and InventoryCopies.saved_error(ddto.inventory).is_empty(), "043 RC3 a save with a stowed attuned copy validates")
	# RC4: a tampered save with four attunements (one hidden in a container) is refused.
	var over := ddto.duplicate(true)
	for id in over.inventory.copies.records:
		var rec: Dictionary = over.inventory.copies.records[id]
		if str(rec.definition_id) == WARD and not rec.state.has("attuned_to"): rec.state["attuned_to"] = d.character_id
	check.call(not ContainerRules.saved_error(over).is_empty(), "043 RC4 a hidden contained attunement cannot exceed the three-item limit")
	# RC5: destroying an ordinary container spills its exact contents to the holder instead of destroying them.
	var e := carrier("b043_rc5")
	var sat := add(e, SATCHEL)
	var f1 := add(e, FLASK)
	ContainerRules.put(e.inventory, sat, f1, "main")
	e.inventory.destroy_instance(sat)
	check.call(not owns(e, sat) and owns(e, f1), "043 RC5 destroying an ordinary container leaves its contents with the holder")
	# RC6: cursed copies still cannot be stowed.
	var f := carrier("b043_rc6")
	var p2 := add(f, POUCH)
	var hex := add(f, HEX)
	f.inventory.attune_instance(hex, f.character_id)
	check.call(not ContainerRules.put(f.inventory, p2, hex, "main").success and owns(f, hex), "043 RC6 a cursed copy is refused before it moves")
	# RC7: SRD Remove Curse at 3rd level still breaks an undeclared cursed item's attunement (legacy route).
	var g := carrier("b043_rc7")
	var sv := add(g, "sword_of_vengeance")
	g.inventory.attune_instance(sv, g.character_id)
	var cursed_before := CurseRules.is_cursed(g.inventory.get_instance(sv))
	var broken := g.inventory.break_cursed_item_attunements(g.character_id)
	var declared := CurseRules.break_with(g, "remove_curse", 3)
	check.call(cursed_before and broken == 1 and not CurseRules.is_cursed(g.inventory.get_instance(sv)) and declared.refused.is_empty(), "043 RC7 undeclared SRD cursed item breaks at slot 3 as before")
	# RC8: an over-limit put changes nothing.
	var h := carrier("b043_rc8")
	var sat2 := add(h, SATCHEL)
	var bricks: Array = [add(h, BRICK), add(h, BRICK)]
	var first := ContainerRules.put(h.inventory, sat2, bricks[0], "main")
	var second := ContainerRules.put(h.inventory, sat2, bricks[1], "main")
	check.call(first.success and not second.success and owns(h, bricks[1]) and ContainerRules.contents(h.inventory, sat2).size() == 1, "043 RC8 a put over the weight limit refuses before the copy moves")
