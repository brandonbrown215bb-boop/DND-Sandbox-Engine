class_name Batch072Checks
extends RefCounted
## Batch 072 (S-060/S-203): last-charge property loss. `keep_properties` decides
## which MagicPropertyRules properties survive a declared degrade on the exact
## copy; every other one stops working through MagicPropertyRules.active.

const EMBER := "fixture:b072_ember_ring"
const HUSK := "fixture:b072_husk_ring"
const KEEPER := "fixture:b072_keeper_ring"
const MEND := "fixture:b072_mend"

static func load_fixtures() -> void:
	Batch044Checks.load_fixtures()
	if not DataLoader.get_item(EMBER).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_072/last_charge.json", "spell")
	DataLoader._load_json_file("res://data/fixtures/batch_072/items.json", "item")

static func wearer(id: String, definition: String, copies: int = 2) -> Array:
	var c := Batch031Checks._character(id, 40)
	var ids: Array = []
	for i in copies:
		var copy := Batch041Checks.add_copy(c, definition)
		c.inventory.equip_instance(Inventory.Slot.RING_1 if i == 0 else Inventory.Slot.RING_2, copy)
		ids.append(copy)
	return [c] + ids

static func offers(c: Character, copy: String) -> bool:
	return SpellPermissionRules.for_spell(c, DataLoader.get_spell(MEND)).any(func(p): return str(p.get("source_id", "")) == copy)

static func item_choice(c: Character, copy: String) -> Dictionary:
	for choice in SpellPermissionRules.payment_choices(c, MEND):
		if choice.get("_spell_payment_kind") == "item_charges" and str(choice.get("_spell_payment_source_id", "")) == copy: return choice
	return {}

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "072 last-charge fixtures load: %s" % str(DataLoader.get_load_errors()))
	_validation(check)
	_ember(check)
	_husk_and_keeper(check)
	_saves(check)

static func _validation(check: Callable) -> void:
	var base := DataLoader.get_item(EMBER).duplicate(true)
	var unknown := base.duplicate(true); unknown.last_charge_aftermath.keep_properties = ["light"]
	var lacks := base.duplicate(true); lacks.last_charge_aftermath.keep_properties = ["item_effects"]
	var destroy := base.duplicate(true); destroy.last_charge_aftermath = {"outcome": "destroy", "keep_properties": []}
	check.call(LastChargeRules.definition_error(base).is_empty() and not LastChargeRules.definition_error(unknown).is_empty() and not LastChargeRules.definition_error(lacks).is_empty() and not LastChargeRules.definition_error(destroy).is_empty(), "072 keep_properties refuses unsupported names, properties the item lacks, and destroy outcomes")
	var errors_before: int = DataLoader._load_errors.size()
	unknown.id = "fixture:b072_bad_keep"
	var accepted: bool = DataLoader._validate_semantics(unknown, "item", "b072 test")
	var added: Array = DataLoader._load_errors.slice(errors_before)
	DataLoader._load_errors.resize(errors_before)
	check.call(not accepted and added.any(func(e): return "unsupported property 'light'" in str(e)), "072 the loader refuses an unsupported kept property (%s)" % str(added))
	check.call(LastChargeRules.kept_properties(EMBER) == ["source_benefits"] and LastChargeRules.lost_properties(EMBER) == ["spell_permissions"], "072 ember ring keeps its benefit and loses its spell permission by data")

static func _ember(check: Callable) -> void:
	var w := wearer("b072_ember", EMBER)
	var c: Character = w[0]
	var a := str(w[1]); var b := str(w[2])
	var ac := SourceBenefitRules.total(c, "AC")
	check.call(ac == 2 and offers(c, a) and offers(c, b), "072 two undegraded ember copies each grant AC and offer the spell (AC %d)" % ac)
	c.inventory.spend_instance_charges(a, 1)
	check.call(not c.inventory.get_instance(a).state.has("degraded") and offers(c, a), "072 a non-last charge spend keeps everything")
	check.call(not item_choice(c, a).is_empty(), "072 copy A offers its item-charge payment before the last charge")
	var paid := c.inventory.spend_instance_charges(a, 1)
	var r := c.inventory.last_charge_receipt
	var sa: Dictionary = c.inventory.get_instance(a).state
	check.call(paid and r.get("degraded", false) and r.kept_properties == ["source_benefits"] and r.lost_properties == ["spell_permissions"] and bool(sa.degraded) and bool(sa.magical), "072 last charge degrades copy A once with the declared kept and lost lists (%s)" % str(r))
	check.call(not offers(c, a) and offers(c, b) and item_choice(c, a).is_empty() and SourceBenefitRules.total(c, "AC") == 2, "072 copy A no longer offers its spell, keeps its AC; copy B is untouched")
	check.call(not MagicPropertyRules.active(c, a, "spell_permissions") and MagicPropertyRules.active(c, a, "source_benefits") and MagicPropertyRules.active(c, b, "spell_permissions"), "072 MagicPropertyRules.active reads the loss per exact copy")
	c.inventory.recover_daily_charges()
	check.call(int(c.inventory.get_instance(a).state.charges) == 0 and not offers(c, a), "072 dawn recovery does not restore a degraded copy")
	check.call(not c.inventory.spend_instance_charges(a, 1) and c.inventory.last_charge_receipt == r, "072 an empty degraded copy cannot pay or settle again")
	# S-203 gate: kept property still obeys suppression; a lost one is not a suppression target.
	var hush := {"type": "suppress_item_magic", "properties": ["source_benefits"]}
	var unmake := {"type": "suppress_item_magic", "properties": ["spell_permissions"], "mode": "destroy"}
	check.call(MagicPropertyRules._affected(c, hush).has(a) and not MagicPropertyRules._affected(c, unmake).has(a) and MagicPropertyRules._affected(c, unmake).has(b), "072 kept AC is still suppressible; lost permission is no longer a destroy target")
	# Unequip and re-equip: identity and loss follow the copy.
	c.inventory.unequip(Inventory.Slot.RING_1)
	c.inventory.equip_instance(Inventory.Slot.RING_1, a)
	check.call(not offers(c, a) and offers(c, b), "072 re-equipping copy A does not restore its lost permission")

static func _husk_and_keeper(check: Callable) -> void:
	var h := wearer("b072_husk", HUSK, 1)
	var c: Character = h[0]; var a := str(h[1])
	c.inventory.spend_instance_charges(a, 1)
	var st: Dictionary = c.inventory.get_instance(a).state
	check.call(bool(st.degraded) and not bool(st.magical) and SourceBenefitRules.total(c, "AC") == 0 and not offers(c, a) and not ZeroHpAftermathRules._is_magic(c.inventory.get_instance(a)), "072 keep_properties [] ends every magical property; copy is a mundane ring")
	check.call(not MagicPropertyRules.cast_error(c, DataLoader.get_spell(Batch044Checks.UNMAKE)).is_empty(), "072 destroying magic on a fully degraded copy is refused before the slot is spent")
	var k := wearer("b072_keeper", KEEPER, 1)
	var kc: Character = k[0]; var ka := str(k[1])
	kc.inventory.spend_instance_charges(ka, 1)
	check.call(bool(kc.inventory.get_instance(ka).state.degraded) and offers(kc, ka) and SourceBenefitRules.total(kc, "AC") == 1, "072 keeper ring keeps both declared properties after its last charge")

static func _saves(check: Callable) -> void:
	var w := wearer("b072_save", EMBER)
	var c: Character = w[0]; var a := str(w[1]); var b := str(w[2])
	c.inventory.spend_instance_charges(a, 2)
	var dto := c.to_dict()
	check.call(InventoryCopies.saved_error(dto.inventory).is_empty() and InventoryCopies.record_state_error(c.inventory.copies.records[a]).is_empty(), "072 degraded ember copy validates")
	for form in ["dict", "json"]:
		var back := Character.new()
		back.from_dict(dto if form == "dict" else JSON.parse_string(JSON.stringify(dto)))
		check.call(not offers(back, a) and offers(back, b) and SourceBenefitRules.total(back, "AC") == 2 and int(back.inventory.get_instance(b).state.charges) == 2, "072 %s reload keeps copy A's loss and copy B's charges" % form)
	var forged := dto.duplicate(true)
	forged.inventory.copies.records[a].state.magical = false
	check.call(not InventoryCopies.saved_error(forged.inventory).is_empty(), "072 saved magical flag must match the declared kept properties")
	# Legacy: a degraded review ring saved before 072 (no extra fields) still loads and loses its permission.
	var legacy := Batch031Checks._character("b072_legacy", 40)
	var ring := Batch041Checks.add_copy(legacy, "fixture:b036_review_ring")
	var ldto := legacy.to_dict()
	ldto.inventory.copies.records[ring].state = {"charges": 0, "degraded": true, "magical": false}
	check.call(InventoryCopies.saved_error(ldto.inventory).is_empty(), "072 legacy degraded state (036 shape) still validates")
