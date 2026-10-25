class_name Batch080Checks
extends RefCounted
## Batch 080 (#44 follow-up, S-060/S-203). Brandon: "follow each item's text;
## there's no universal keep/lose rule. Staff of Power keeps its +2 weapon bonus
## after its last-charge failure; Staff of Striking can become nonmagical (SRD
## p.246). Reaching zero charges doesn't universally erase bonuses. Keep
## unsupported item conversions blocked until those distinctions work."

const POWER := "staff_of_power"
const STRIKING := "staff_of_striking"
const SPENT := "fixture:b080_spent_blade"

static func load_fixtures() -> void:
	if not DataLoader.get_item(SPENT).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_080/items.json", "item")

static func wielder(id: String, definition: String) -> Array:
	var c := Batch031Checks._character(id, 40)
	var copy := Batch041Checks.add_copy(c, definition)
	c.inventory.equip_instance(Inventory.Slot.WEAPON, copy)
	if bool(DataLoader.get_item(definition).get("requires_attunement", false)): c.inventory.attune_instance(copy, c.character_id)
	return [c, copy]

## Spend every charge through the shared item-charge payment boundary; the last spend rolls `face`.
static func drain(c: Character, copy: String, face: int) -> Dictionary:
	var left := int(c.inventory.get_instance(copy).state.charges)
	if left > 1: c.inventory.spend_instance_charges(copy, left - 1)
	c.inventory.forced_last_charge_roll = face
	c.inventory.spend_instance_charges(copy, 1)
	return c.inventory.last_charge_receipt

static func bonus(c: Character, definition: String) -> Dictionary:
	return MagicPropertyRules.weapon_copy_bonus(c, definition)

static func hit_bonus(c: Character, definition: String) -> int:
	var target := Batch031Checks._character("b080_target_%s" % definition, 200)
	Batch031Controls._seed_hit()
	var res := CombatAction.resolve_weapon_attack(c, target, DataLoader.get_item(definition).duplicate(true), false, false, {})
	var attack := 0
	for m in res.get("activity_roll", {}).get("modifiers", []):
		if str(m.get("label", "")) == "Weapon bonus": attack = int(m.value)
	if res.get("hit", false):
		var damage := 0
		for m in res.get("activity_damage", {}).get("modifiers", []):
			if str(m.get("label", "")) == "Weapon bonus": damage = int(m.value)
		if damage != attack: return -2
	return attack

static func run(check: Callable) -> void:
	load_fixtures()
	var power := DataLoader.get_item(POWER)
	var striking := DataLoader.get_item(STRIKING)
	check.call(int(power.weapon_bonus.attack) == 2 and int(power.weapon_bonus.damage) == 2 and power.last_charge_aftermath.keep_properties == ["weapon_bonus"] and int(power.maximum_charges) == 20, "080 Staff of Power data follows SRD p.246 (+2, 20 charges, keeps only the +2)")
	check.call(int(striking.weapon_bonus.attack) == 3 and int(striking.weapon_bonus.damage) == 3 and str(striking.last_charge_aftermath.outcome) == "nonmagical" and int(striking.maximum_charges) == 10, "080 Staff of Striking data follows SRD p.246 (+3, 10 charges, becomes nonmagical)")
	_power(check)
	_striking(check)
	_zero(check)
	_refusals(check)
	_saved(check)

static func _power(check: Callable) -> void:
	var w := wielder("b080_power", POWER)
	var c: Character = w[0]
	var copy: String = w[1]
	var ac := SourceBenefitRules.total(c, "AC")
	check.call(bonus(c, POWER).attack == 2 and ac == 2 and hit_bonus(c, POWER) == 2, "080 attuned Staff of Power: +2 attack/damage on a real attack, +2 AC")
	var miss := drain(c, copy, 7)
	check.call(miss.get("rolled", false) and not miss.get("triggered", true) and bonus(c, POWER).attack == 2 and SourceBenefitRules.total(c, "AC") == 2, "080 last charge without the failure face keeps everything at 0 charges")
	var w2 := wielder("b080_power_fail", POWER)
	var r := drain(w2[0], w2[1], 1)
	var b := bonus(w2[0], POWER)
	check.call(r.get("degraded", false) and r.get("kept_properties", []) == ["weapon_bonus"] and r.get("lost_properties", []) == ["source_benefits"] and not r.get("nonmagical", true), "080 Staff of Power failure keeps the +2 and loses all other properties (%s)" % str(r))
	check.call(b.attack == 2 and b.damage == 2 and b.magical and SourceBenefitRules.total(w2[0], "AC") == 0 and hit_bonus(w2[0], POWER) == 2, "080 failed Staff of Power still adds +2 to a real attack's damage; AC +2 is gone")

static func _striking(check: Callable) -> void:
	var w := wielder("b080_striking", STRIKING)
	var c: Character = w[0]
	check.call(bonus(c, STRIKING).attack == 3 and hit_bonus(c, STRIKING) == 3, "080 attuned Staff of Striking adds +3")
	var r := drain(c, w[1], 1)
	var b := bonus(c, STRIKING)
	var rec: Dictionary = c.inventory.get_instance(w[1])
	check.call(r.get("nonmagical", false) and r.get("kept_properties", ["x"]).is_empty() and r.get("lost_properties", []) == ["weapon_bonus"] and not b.magical and b.attack == 0 and hit_bonus(c, STRIKING) == 0, "080 Staff of Striking failure becomes nonmagical: no bonus on a real attack (%s)" % str(r))
	check.call(str(rec.definition_id) == STRIKING and str(rec.instance_id) == str(w[1]) and str(DataLoader.get_item(STRIKING).damage) == "1d6", "080 nonmagical copy keeps its identity and mundane quarterstaff fields (no conversion)")
	var d := Batch031Checks._character("b080_other", 40)
	var other := Batch041Checks.add_copy(d, STRIKING)
	check.call(not c.inventory.attune_instance(w[1], "b080_someone").get("success", true) and str(c.inventory.attune_instance(w[1], "b080_someone").get("message", "")).contains("lost its magic") and d.inventory.attune_instance(other, d.character_id).get("success", false), "080 nonmagical copy refuses attunement; an independent copy still attunes")
	c.inventory.recover_daily_charges()
	check.call(int(c.inventory.get_instance(w[1]).state.charges) == 0, "080 nonmagical copy does not regain charges at dawn")

static func _zero(check: Callable) -> void:
	var w := wielder("b080_zero", SPENT)
	var c: Character = w[0]
	c.inventory.spend_instance_charges(w[1], 1)
	var b := bonus(c, SPENT)
	check.call(int(c.inventory.get_instance(w[1]).state.charges) == 0 and c.inventory.last_charge_receipt.is_empty() and b.attack == 1 and b.magical and hit_bonus(c, SPENT) == 1, "080 zero charges with no declared aftermath keep the weapon bonus")
	var u := wielder("b080_unattuned", POWER)
	(u[0] as Character).inventory.get_instance(u[1])
	var rec: Dictionary = (u[0] as Character).inventory.copies.records[u[1]]
	rec.state.erase("attuned_to")
	check.call(bonus(u[0], POWER).attack == 0, "080 unattuned Staff of Power grants no weapon bonus")

static func _refusals(check: Callable) -> void:
	var base := {"outcome": "degrade", "roll": {"die": 20, "trigger_on": [1]}, "keep_properties": []}
	var no_keep := base.duplicate(true)
	no_keep.erase("keep_properties")
	check.call(LastChargeRules.validate(no_keep).contains("must state keep_properties"), "080 degrade without keep_properties is refused (no default survivor list)")
	var convert := {"outcome": "degrade", "keep_properties": [], "becomes": "quarterstaff"}
	var e := LastChargeRules.validate(convert)
	check.call(e.contains("conversion into another item") and e.contains("unsupported"), "080 conversion into another item is refused with a clear reason (%s)" % e)
	var vanish := LastChargeRules.validate({"outcome": "vanish"})
	check.call(vanish.contains("'vanish' is unsupported"), "080 unknown outcome is refused with its name (%s)" % vanish)
	check.call(not LastChargeRules.validate({"outcome": "degrade", "keep_properties": [], "extra": 1}).is_empty(), "080 unknown aftermath keys are refused")
	var item := DataLoader.get_item(STRIKING).duplicate(true)
	item.last_charge_aftermath = {"outcome": "nonmagical", "keep_properties": ["weapon_bonus"]}
	check.call(not LastChargeRules.definition_error(item).is_empty(), "080 nonmagical with keep_properties is refused")
	var bad := DataLoader.get_item(POWER).duplicate(true)
	bad.weapon_bonus = {"attack": 2}
	check.call(not MagicPropertyRules.weapon_bonus_error(bad).is_empty(), "080 malformed weapon_bonus is refused")
	var mundane := DataLoader.get_item("quarterstaff").duplicate(true)
	mundane["weapon_bonus"] = {"attack": 1, "damage": 1}
	check.call(not MagicPropertyRules.weapon_bonus_error(mundane).is_empty(), "080 weapon_bonus on a nonmagical weapon is refused")

static func _saved(check: Callable) -> void:
	var w := wielder("b080_saved", POWER)
	var c: Character = w[0]
	drain(c, w[1], 1)
	var dto: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var back := Character.new()
	back.from_dict(dto)
	check.call(bonus(back, POWER).attack == 2 and SourceBenefitRules.total(back, "AC") == 0, "080 JSON-text DTO keeps the failed Power staff's +2 only")
	var rec: Dictionary = dto.inventory.copies.records[w[1]]
	rec.state.magical = false
	check.call(not InventoryCopies.record_state_error(rec).is_empty(), "080 tampered magical flag on a kept-bonus copy is refused")
	var legacy := {"instance_id": "legacy:1", "definition_id": POWER, "state": {}}
	check.call(InventoryCopies.record_state_error(legacy).is_empty(), "080 legacy uncharged Staff of Power record still validates (legacy_charge_state: full)")
	var ring := {"instance_id": "legacy:2", "definition_id": "fixture:b072_ember_ring", "state": {}}
	Batch072Checks.load_fixtures()
	check.call(not InventoryCopies.record_state_error(ring).is_empty(), "080 items without the declaration still refuse a missing charge state")
	var copies := InventoryCopies.new()
	var inv := Inventory.new()
	inv.backpack.assign([POWER])
	copies.restore(inv, {"inventory_id": "legacy", "next_id": 2, "records": {"legacy:1": legacy}, "backpack": ["legacy:1"], "equipped": {}})
	check.call(int(copies.records["legacy:1"].state.get("charges", -1)) == 20, "080 legacy uncharged copy restores full (20)")
