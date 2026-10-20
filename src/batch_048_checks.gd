class_name Batch048Checks
extends RefCounted

const BOOTS := "fixture:b048_boots"
const CIRCLET := "fixture:b048_circlet"
const CHARM := "fixture:b048_charm"
const STAFF := "fixture:b048_staff"
const ROD := "fixture:b048_rod"
## SRD 5.2.1 p.95 Adventuring Gear table, p.96 Arcane Focuses, p.97 Druidic Focuses, p.94 Musical Instrument variants (printed page = PDF page).
const CITED := {"backpack": 5, "bedroll": 7, "crowbar": 5, "climbers_kit": 12, "healers_kit": 3, "lantern_hooded": 2, "caltrops": 2, "mirror": 0.5, "rations": 2, "arcane_staff": 4, "arcane_rod": 2, "wooden_staff": 4, "viol": 1, "dulcimer": 10}
## SRD gives "—" or no weight: these stay unknown.
const UNKNOWN := ["bell", "antitoxin", "basic_poison", "gemstone_100gp"]

static func load_fixtures() -> void:
	Batch047Checks.load_fixtures()
	if not DataLoader.get_item(BOOTS).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_048/items/magic_types.json", "item")

static func actor(id: String) -> Character:
	return Batch031Checks._character(id, 40)

static func add(a: Character, definition: String) -> String:
	return Batch041Checks.add_copy(a, definition)

## Loader verdict for a candidate definition, leaving the load-error list as it was.
static func _loads(data: Dictionary) -> bool:
	var before := DataLoader._load_errors.size()
	var ok: bool = DataLoader._validate_content(data, "item", "batch_048_probe")
	DataLoader._load_errors.resize(before)
	return ok

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty() and [BOOTS, CIRCLET, CHARM, STAFF, ROD].all(func(i): return not DataLoader.get_item(i).is_empty()), "048 wondrous, staff and rod fixtures load as their own types: %s" % str(DataLoader.get_load_errors()))
	_loader(check)
	_held_and_worn(check)
	_measurements(check)
	_backpack(check)
	_saves(check)

static func _loader(check: Callable) -> void:
	var base := {"id": "b048_probe", "name": "Probe", "type": "wondrous", "value": 0}
	var refused := 0
	for mutate in [func(x): x.type = "gizmo", func(x): x["worn_slot"] = "neck", func(x):
			x.type = "tool"
			x["worn_slot"] = "head", func(x): x["weight"] = -1, func(x): x["volume"] = "small", func(x): x["source_benefits"] = [{"stat": "AC", "amount": 1}]]:
		var x := base.duplicate(true)
		mutate.call(x)
		if not _loads(x): refused += 1
	check.call(_loads(base) and refused == 6, "048 loader accepts a plain wondrous item; refuses unknown type, bad or misplaced worn_slot, bad measurements and unworn benefits (%d/6)" % refused)
	var staff := {"id": "b048_probe_staff", "name": "Probe Staff", "type": "staff", "value": 0, "source_benefits": [{"stat": "AC", "amount": 1}]}
	check.call(_loads(staff) and _loads({"id": "b048_probe_rod", "name": "Probe Rod", "type": "rod", "value": 0}), "048 staffs and rods load (with held benefits) without pretending to be tools")
	var weight_only := {"compartments": [{"id": "main", "max_weight": 30}]}
	var none := {"compartments": [{"id": "main"}]}
	check.call(ContainerRules.policy_error(weight_only).is_empty() and not ContainerRules.policy_error(none).is_empty(), "048 a compartment may state only its source weight limit, but needs at least one limit")

static func _held_and_worn(check: Callable) -> void:
	var a := actor("b048_holder")
	a.inventory.unequip(Inventory.Slot.SHIELD)
	a.inventory.add_item(STAFF)
	var hands_before := a.inventory.available_spellcasting_hands()
	var staff_ok := a.inventory.can_equip(Inventory.Slot.HANDS, STAFF) and not a.inventory.can_equip(Inventory.Slot.WEAPON, STAFF)
	a.inventory.equip(Inventory.Slot.HANDS, STAFF)
	check.call(staff_ok and a.inventory.get_equipped(Inventory.Slot.HANDS) == STAFF and SourceBenefitRules.total(a, "AC") == 1 and a.inventory.available_spellcasting_hands() == maxi(0, hands_before - 1), "048 a staff is held in the hand slot (not wielded as a tool or weapon) and its benefit applies while held")
	a.inventory.add_item(ROD)
	check.call(a.inventory.can_equip(Inventory.Slot.HANDS, ROD) and not a.inventory.can_equip(Inventory.Slot.RING_1, ROD), "048 a rod is held in the hand slot")
	var b := actor("b048_wearer")
	b.inventory.add_item(BOOTS)
	b.inventory.add_item(CIRCLET)
	b.inventory.add_item(CHARM)
	var feet := b.inventory.can_equip(Inventory.Slot.FEET, BOOTS) and not b.inventory.can_equip(Inventory.Slot.HEAD, BOOTS)
	var head := b.inventory.can_equip(Inventory.Slot.HEAD, CIRCLET)
	var carried := Inventory.Slot.values().all(func(s): return not b.inventory.can_equip(s, CHARM))
	check.call(feet and head and carried, "048 wondrous items are worn only where declared; an undeclared one is only carried")
	b.inventory.equip(Inventory.Slot.FEET, BOOTS)
	var unattuned := SourceBenefitRules.total(b, "speed")
	var boots_id := b.inventory.equipped_instance_id(Inventory.Slot.FEET)
	var att := b.inventory.attune_instance(boots_id, b.character_id)
	check.call(unattuned == 0 and att.get("success", false) and SourceBenefitRules.total(b, "speed") == 1, "048 worn wondrous boots need attunement before their benefit applies")

static func _measurements(check: Callable) -> void:
	var wrong: Array = []
	for id in CITED:
		if not is_equal_approx(float(DataLoader.get_item(id).get("weight", -1)), float(CITED[id])): wrong.append(id)
	check.call(wrong.is_empty(), "048 catalog items carry their SRD 5.2.1 weights (wrong=%s)" % str(wrong))
	check.call(UNKNOWN.all(func(id): return not DataLoader.get_item(id).is_empty() and not DataLoader.get_item(id).has("weight")) and not DataLoader.get_item(BOOTS).has("weight"), "048 items without an SRD weight stay unknown (no invented values)")
	check.call(is_equal_approx(float(ContainerRules.compartments("backpack").main.max_weight), 30.0) and not ContainerRules.compartments("backpack").main.has("max_count"), "048 the catalog backpack holds up to 30 lb. (SRD 5.2.1 p.96), with no invented count")

static func _backpack(check: Callable) -> void:
	var a := actor("b048_packer")
	var pack := add(a, "backpack")
	var placed := 0
	for id in ["crowbar", "bedroll", "climbers_kit", "healers_kit", "lantern_hooded"]:
		if ContainerRules.put(a.inventory, pack, add(a, id), "main").get("success", false): placed += 1
	check.call(placed == 5, "048 real catalog items fill the real backpack up to 29 lb. (%d/5)" % placed)
	var caltrops := add(a, "caltrops")
	var before := a.inventory.get_instance(pack)
	var over := ContainerRules.put(a.inventory, pack, caltrops, "main")
	check.call(not over.get("success", false) and not over.has("seconds") and str(over.get("message", "")).contains("limit") and a.inventory.backpack_instances().any(func(c): return str(c.instance_id) == caltrops) and a.inventory.get_instance(pack) == before, "048 a 2 lb. item that would exceed 30 lb. is refused with nothing moved")
	var bell := add(a, "bell")
	var staff := add(a, STAFF)
	var unknown := ContainerRules.put(a.inventory, pack, bell, "main")
	var magic := ContainerRules.put(a.inventory, pack, staff, "main")
	check.call(not unknown.get("success", false) and str(unknown.message).contains("no recorded weight") and not magic.get("success", false) and ContainerRules.contents(a.inventory, pack).size() == 5, "048 unknown-weight items (a real bell, a fixture staff) are refused as unmeasurable")
	var out := ContainerRules.remove(a.inventory, pack, str(ContainerRules.contents(a.inventory, pack)[0].instance_id))
	var fits := ContainerRules.put(a.inventory, pack, caltrops, "main")
	check.call(out.get("success", false) and fits.get("success", false), "048 after taking out 5 lb. the same caltrops fit")

static func _saves(check: Callable) -> void:
	var a := actor("b048_save")
	var pack := add(a, "backpack")
	ContainerRules.put(a.inventory, pack, add(a, "crowbar"), "main")
	a.inventory.add_item(BOOTS)
	a.inventory.equip(Inventory.Slot.FEET, BOOTS)
	a.inventory.attune_instance(a.inventory.equipped_instance_id(Inventory.Slot.FEET), a.character_id)
	var dto := a.to_dict()
	var rec: Dictionary = dto.inventory.copies.records[pack]
	check.call(InventoryCopies.record_state_error(rec).is_empty() and InventoryCopies.saved_error(dto.inventory).is_empty() and ContainerRules.saved_error(dto).is_empty(), "048 a real backpack with contents passes record_state_error and the container save check")
	var back := Character.new()
	back.from_dict(dto)
	check.call(ContainerRules.contents(back.inventory, pack).size() == 1 and str(ContainerRules.contents(back.inventory, pack)[0].definition_id) == "crowbar" and back.inventory.get_equipped(Inventory.Slot.FEET) == BOOTS and SourceBenefitRules.total(back, "speed") == 1, "048 reload keeps the exact contents and the worn attuned wondrous item")
	var heavy := dto.duplicate(true)
	var list: Array = heavy.inventory.copies.records[pack].state.contents.main
	for i in 6: list.append(list[0].duplicate(true))
	for i in range(1, list.size()): list[i]["instance_id"] = "b048_heavy_%d" % i
	var legacy := actor("b048_legacy")
	var old_pack := add(legacy, "backpack")
	var ldto := legacy.to_dict()
	ldto.inventory.copies.records[old_pack].get("state", {}).erase("contents")
	check.call(not ContainerRules.saved_error(heavy).is_empty() and ContainerRules.saved_error(ldto).is_empty() and InventoryCopies.saved_error(ldto.inventory).is_empty(), "048 an overweight saved backpack is refused; a legacy backpack save without contents still loads")
