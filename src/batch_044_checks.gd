class_name Batch044Checks
extends RefCounted

const HOST := "fixture:b044_circlet"
const GEM := "fixture:b044_gem"
const BAND := "fixture:b044_band"
const MANTLE := "fixture:b044_mantle_ring"
const HUSH := "fixture:b044_hush"
const UNMAKE := "fixture:b044_unmake"
const STOP := "fixture:029_charge_stop"

static func load_fixtures() -> void:
	Batch043Checks.load_fixtures()
	if DataLoader.get_spell(STOP).is_empty(): Batch029Checks.load_fixtures()
	if not DataLoader.get_item(HOST).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_044/items/parts_magic.json", "item")
	DataLoader._load_json_file("res://data/fixtures/batch_044/spells/hush.json", "spell")

static func wearer(id: String) -> Character:
	return Batch031Checks._character(id, 40)

static func add(actor: Character, definition: String) -> String:
	return Batch041Checks.add_copy(actor, definition)

static func owns(actor: Character, id: String) -> bool:
	return actor.inventory.owned_instances().any(func(c): return str(c.instance_id) == id)

## The real shared resolver self-cast; concentration is mirrored as in 041.
static func cast(actor: Character, spell_id: String) -> Dictionary:
	actor.spell_slots = {"1": 1}
	if not actor.concentrating_on.is_empty() and DataLoader.get_spell(spell_id).get("concentration", false): SpellEffects.end_concentration(actor, [actor])
	var spell := DataLoader.get_spell(spell_id).duplicate(true)
	var r := SpellResolver.resolve(actor, actor, spell, true, {}, [], 1)
	if bool(spell.get("concentration", false)) and r.get("magic_suppression", {}).get("applied", false): actor.concentrating_on = {"spell_id": spell_id, "effect_source": str(r.effect_cast.source_id), "targets": [actor]}
	return r

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "044 neutral host, parts, mantle ring and suppression spells load: %s" % str(DataLoader.get_load_errors()))
	_attachment_validation(check)
	_attachments(check)
	_attachment_saves(check)
	_magic_validation(check)
	_magic(check)
	_magic_saves(check)
	review_stress(check)

static func _attachment_validation(check: Callable) -> void:
	var policy: Dictionary = DataLoader.get_item(HOST).attachments.duplicate(true)
	check.call(AttachmentRules.policy_error(policy).is_empty(), "044 S-210 declared sockets and sets validate")
	var bad := 0
	for mutate in [func(p): p.sockets[1].id = "gem_a", func(p): p.sockets[2].erase("item_types"), func(p): p.sets[0].requires = ["gem_c"], func(p): p.sets[0].benefits = [{"stat": "luck", "amount": 1}], func(p): p.sets[1].id = "paired_gems", func(p): p["slots"] = 1]:
		var p := policy.duplicate(true)
		mutate.call(p)
		if not AttachmentRules.policy_error(p).is_empty(): bad += 1
	check.call(bad == 6, "044 S-210 loader refuses duplicate, open, undeclared, unsupported and unknown attachment rules (%d/6)" % bad)

static func _attachments(check: Callable) -> void:
	var a := wearer("b044_setter")
	var inv := a.inventory
	var host := add(a, HOST)
	var g1 := add(a, GEM)
	var g2 := add(a, GEM)
	var band := add(a, BAND)
	var rec := inv.get_instance(g1)
	rec.state["cut"] = "rose"
	inv.update_instance(rec)
	var base_ac := SourceBenefitRules.total(a, "AC")
	var r1 := AttachmentRules.attach(inv, host, g1, "gem_a")
	check.call(r1.success and not owns(a, g1) and str(AttachmentRules.attached(inv, host).gem_a.instance_id) == g1 and AttachmentRules.attached(inv, host).gem_a.state.get("cut", "") == "rose", "044 S-210 an exact part attaches with its own identity and state")
	var before := inv.to_dict()
	var refusals := [AttachmentRules.attach(inv, host, g2, "gem_a"), AttachmentRules.attach(inv, host, band, "gem_b"), AttachmentRules.attach(inv, host, g2, "crown"), AttachmentRules.attach(inv, host, host, "band")]
	check.call(refusals.all(func(x): return not x.success) and inv.to_dict() == before, "044 S-210 filled, wrong-part, undeclared and self sockets refuse before anything moves")
	AttachmentRules.attach(inv, host, g2, "gem_b")
	AttachmentRules.attach(inv, host, band, "band")
	check.call(SourceBenefitRules.total(a, "AC") == base_ac, "044 S-210 a carried host grants no set benefits")
	inv.equip_instance(Inventory.Slot.RING_1, host)
	check.call(SourceBenefitRules.total(a, "AC") == base_ac + 1 and SourceBenefitRules.total(a, "speed") == 1, "044 S-210 a worn host with complete sets grants each set's benefits")
	var off := AttachmentRules.detach(inv, host, "gem_b")
	check.call(off.success and owns(a, g2) and SourceBenefitRules.total(a, "AC") == base_ac and SourceBenefitRules.total(a, "speed") == 1, "044 S-210 removing one gem disables only the set that requires it")
	check.call(not AttachmentRules.detach(inv, host, "gem_b").success and inv.count_item(GEM) == 1, "044 S-210 detaching an empty socket refuses without duplicating")
	var again := AttachmentRules.attach_any(inv, g2)
	check.call(again.success and SourceBenefitRules.total(a, "AC") == base_ac + 1, "044 S-210 HUD attach finds the open socket and restores the set")
	var bag := add(a, Batch043Checks.SATCHEL)
	var loose_host := add(a, HOST)
	var g3 := add(a, GEM)
	AttachmentRules.attach(inv, loose_host, g3, "gem_a")
	check.call(not ContainerRules.put(inv, bag, loose_host, "main").success and not AttachmentRules.attach(inv, loose_host, bag, "band").success, "044 S-210 hosts with parts aren't stowed and containers aren't attached")
	var heir := wearer("b044_heir")
	check.call(inv.transfer_instance(loose_host, heir.inventory) and str(AttachmentRules.attached(heir.inventory, loose_host).gem_a.instance_id) == g3, "044 S-210 giving a host carries its exact attached parts")

static func _attachment_saves(check: Callable) -> void:
	var a := wearer("b044_set_save")
	var host := add(a, HOST)
	var g1 := add(a, GEM)
	var g2 := add(a, GEM)
	AttachmentRules.attach(a.inventory, host, g1, "gem_a")
	AttachmentRules.attach(a.inventory, host, g2, "gem_b")
	a.inventory.equip_instance(Inventory.Slot.RING_1, host)
	var dto := a.to_dict()
	check.call(AttachmentRules.saved_error(dto).is_empty(), "044 S-210 saved attachments validate (%s)" % AttachmentRules.saved_error(dto))
	var back := Character.new()
	back.from_dict(dto)
	check.call(str(AttachmentRules.attached(back.inventory, host).gem_b.instance_id) == g2 and SourceBenefitRules.total(back, "AC") == SourceBenefitRules.total(a, "AC"), "044 S-210 reload keeps exact parts and the completed set")
	var defects := {
		"duplicate": func(d): d.inventory.copies.records[host].state.attached["band"] = d.inventory.copies.records[host].state.attached.gem_a.duplicate(true),
		"also carried": func(d): d.inventory.copies.records[g1] = d.inventory.copies.records[host].state.attached.gem_a.duplicate(true),
		"undeclared": func(d): d.inventory.copies.records[host].state.attached["crown"] = d.inventory.copies.records[host].state.attached.gem_b,
		"wrong part": func(d): d.inventory.copies.records[host].state.attached.gem_b.definition_id = BAND,
		"non-host": func(d): d.inventory.copies.records[host].definition_id = MANTLE,
		"future serial": func(d): d.inventory.copies.records[host].state.attached.gem_a.instance_id = "%s:999" % d.inventory.copies.inventory_id,
	}
	var refused := 0
	for label in defects:
		var bad := dto.duplicate(true)
		defects[label].call(bad)
		if not AttachmentRules.saved_error(bad).is_empty(): refused += 1
	check.call(refused == 6, "044 S-210 saved attachments refuse duplicated, re-carried, undeclared, wrong-part, non-host and future-serial parts (%d/6)" % refused)
	var party := {"party": {"characters": {"a": dto, "b": dto.duplicate(true)}}}
	party.party.characters.b.inventory.copies.records = {"x": {"state": {"attached": {"gem_a": {"instance_id": g1}}}}}
	check.call(not InventoryCopies.ownership_error(party).is_empty(), "044 S-210 one attached part can't be owned by two characters")

static func _magic_validation(check: Callable) -> void:
	var e: Dictionary = DataLoader.get_spell(HUSH).effects[0].duplicate(true)
	check.call(MagicPropertyRules.effect_error(e).is_empty() and SharedSpell.content_error(DataLoader.get_spell(HUSH)).is_empty() and SharedSpell.content_error(DataLoader.get_spell(UNMAKE)).is_empty(), "044 S-203 declared suppression and destruction spells validate")
	var bad := 0
	for mutate in [func(x): x.properties = [], func(x): x.properties = ["everything"], func(x): x.properties = ["source_benefits", "source_benefits"], func(x): x.mode = "dispel", func(x): x["duration"] = 3]:
		var x := e.duplicate(true)
		mutate.call(x)
		if not MagicPropertyRules.effect_error(x).is_empty(): bad += 1
	check.call(bad == 5, "044 S-203 loader refuses empty, unknown, repeated, bad-mode and extra-field suppression (%d/5)" % bad)

static func _magic(check: Callable) -> void:
	var a := wearer("b044_hushed")
	var ring := add(a, MANTLE)
	a.inventory.equip_instance(Inventory.Slot.RING_1, ring)
	var other := wearer("b044_other")
	var other_ring := add(other, MANTLE)
	other.inventory.equip_instance(Inventory.Slot.RING_1, other_ring)
	var stop := DataLoader.get_spell(STOP)
	var ac := SourceBenefitRules.total(a, "AC")
	var perms := SpellPermissionRules.for_spell(a, stop).size()
	var r := cast(a, HUSH)
	check.call(r.get("magic_suppression", {}).get("applied", false) and SourceBenefitRules.total(a, "AC") == ac - 2 and SpellPermissionRules.for_spell(a, stop).size() == perms and perms > 0, "044 S-203 suppression removes only the listed property; the ring's spell permission stays")
	check.call(owns(a, ring) and a.inventory.equipped_instance_id(Inventory.Slot.RING_1) == ring and SourceBenefitRules.total(other, "AC") == 2, "044 S-203 the suppressed copy stays worn, and another wearer's copy is unaffected")
	SpellEffects.end_concentration(a, [a])
	check.call(SourceBenefitRules.total(a, "AC") == ac and a.inventory.equipped_instance_id(Inventory.Slot.RING_1) == ring, "044 S-203 ending the source restores the still-worn copy without re-equipping")
	var d := cast(a, UNMAKE)
	SpellEffects.prune(a)
	a.spell_effects.erase(str(d.get("effect_cast", {}).get("source_id", "")))
	check.call(d.get("magic_suppression", {}).get("applied", false) and SpellPermissionRules.for_spell(a, stop).is_empty() and SourceBenefitRules.total(a, "AC") == ac and a.inventory.get_instance(ring).state.destroyed_magic.spell_permissions.cause == UNMAKE, "044 S-203 destruction removes only the listed property permanently and records its cause")
	a.inventory.unequip(Inventory.Slot.RING_1)
	a.inventory.equip_instance(Inventory.Slot.RING_1, ring)
	check.call(SpellPermissionRules.for_spell(a, stop).is_empty() and SpellPermissionRules.for_spell(other, stop).size() == perms, "044 S-203 re-equipping does not restore destroyed magic; other copies keep theirs")
	var setter := wearer("b044_set_hush")
	var host := add(setter, HOST)
	for s in ["gem_a", "gem_b"]: AttachmentRules.attach(setter.inventory, host, add(setter, GEM), s)
	setter.inventory.equip_instance(Inventory.Slot.RING_1, host)
	var set_ac := SourceBenefitRules.total(setter, "AC")
	cast(setter, HUSH)
	var hushed := SourceBenefitRules.total(setter, "AC")
	SpellEffects.end_concentration(setter, [setter])
	check.call(hushed == set_ac - 1 and SourceBenefitRules.total(setter, "AC") == set_ac and AttachmentRules.attached(setter.inventory, host).size() == 2, "044 S-203/S-210 suppression mutes attachment sets and restores them with the parts in place")
	var bare := wearer("b044_bare")
	var none := cast(bare, HUSH)
	check.call(not none.get("magic_suppression", {}).get("applied", false) and int(bare.spell_slots.get("1", 0)) == 1, "044 S-203 a suppression with no affected copy applies nothing and keeps the slot (review 044 R1)")

static func _magic_saves(check: Callable) -> void:
	var a := wearer("b044_magic_save")
	var ring := add(a, MANTLE)
	a.inventory.equip_instance(Inventory.Slot.RING_1, ring)
	var d := cast(a, UNMAKE)
	a.spell_effects.erase(str(d.effect_cast.source_id))
	cast(a, HUSH)
	var dto := a.to_dict()
	check.call(MagicPropertyRules.saved_error(dto).is_empty() and dto.spell_effects.size() == 1, "044 S-203 live suppression and destroyed magic validate (%s)" % MagicPropertyRules.saved_error(dto))
	var back := Character.new()
	back.from_dict(dto)
	var stop := DataLoader.get_spell(STOP)
	check.call(SourceBenefitRules.total(back, "AC") == 0 and SpellPermissionRules.for_spell(back, stop).is_empty(), "044 S-203 reload keeps the live suppression and the destroyed property")
	var source := str(back.concentrating_on.get("effect_source", ""))
	SpellEffects.end_concentration(back, [back])
	check.call(not source.is_empty() and SourceBenefitRules.total(back, "AC") == 2 and SpellPermissionRules.for_spell(back, stop).is_empty(), "044 S-203 ending the reloaded source restores only the suppressed property")
	var key := ""
	for s in dto.spell_effects:
		if dto.spell_effects[s].has("magic_suppression"): key = s
	var defects := {
		"widened": func(x): x.spell_effects[key].magic_suppression.copies[ring] = ["source_benefits", "spell_permissions"],
		"retyped": func(x): x.spell_effects[key].magic_suppression.mode = "destroy",
		"no copies": func(x): x.spell_effects[key].magic_suppression.copies = {},
		"uncaused": func(x): x.inventory.copies.records[ring].state.destroyed_magic.spell_permissions = {"cause": ""},
		"absent property": func(x): x.inventory.copies.records[ring].state.destroyed_magic["incoming_negation_rule"] = {"cause": UNMAKE, "source_id": "s"},
	}
	var refused := 0
	for label in defects:
		var bad := dto.duplicate(true)
		defects[label].call(bad)
		if not MagicPropertyRules.saved_error(bad).is_empty(): refused += 1
	check.call(refused == 5, "044 S-203 saved magic refuses widened, retyped, empty, uncaused and absent-property records (%d/5)" % refused)


## Runtime Reviewer stress (RS1-RS8).
const MUTE := "fixture:b044_review_mute"
static func review_stress(check: Callable) -> void:
	if DataLoader.get_spell(MUTE).is_empty(): DataLoader._load_json_file("res://data/fixtures/batch_044/spells/review_mute.json", "spell")
	Batch041Checks.load_fixtures()
	if DataLoader.get_item(Batch043Checks.POUCH).is_empty(): DataLoader._load_json_file("res://data/fixtures/batch_043/items/review_pouch.json", "item")
	# RS1: no worn copy with the listed property -> refused before the slot is spent.
	var a := wearer("b044_rs1")
	a.spell_slots = {"1": 1}
	var r := SpellResolver.resolve(a, a, DataLoader.get_spell(HUSH).duplicate(true), true, {}, [], 1)
	check.call(int(a.spell_slots.get("1", 0)) == 1 and not r.get("magic_suppression", {}).get("applied", false) and not ActorProjectionRules.cast_error(a, DataLoader.get_spell(HUSH)).is_empty(), "044 RS1 suppression with nothing to suppress refuses before cost (slots=%s)" % str(a.spell_slots))
	# RS2: SRD Ring of Protection: its authored AC and save bonus are suppressible together and return after.
	var b := Batch041Checks.wearer("b044_rs2")
	var ac0 := b.get_ac()
	var sv0 := b.inventory.magic_item_saving_bonus(b.character_id)
	var m := cast(b, MUTE)
	var ac1 := b.get_ac()
	var sv1 := b.inventory.magic_item_saving_bonus(b.character_id)
	SpellEffects.end_concentration(b, [b])
	check.call(m.get("magic_suppression", {}).get("applied", false) and sv0 == 1 and sv1 == 0 and ac1 == ac0 - 1 and b.get_ac() == ac0 and b.inventory.magic_item_saving_bonus(b.character_id) == 1 and SourceBenefitRules.total(b, "AC") == 2, "044 RS2 Ring of Protection AC and save bonus are suppressed together, charm untouched, restored at end (ac %d->%d save %d->%d)" % [ac0, ac1, sv0, sv1])
	# RS3: tampered attached part state is refused like carried and contained copies.
	var c := wearer("b044_rs3")
	var host := add(c, HOST)
	var g := add(c, GEM)
	AttachmentRules.attach(c.inventory, host, g, "gem_a")
	var dto := c.to_dict()
	check.call(AttachmentRules.saved_error(dto).is_empty(), "044 RS3 an untampered attached part validates")
	var bad := dto.duplicate(true)
	bad.inventory.copies.records[host].state.attached.gem_a.state["charges"] = -5
	var bad2 := dto.duplicate(true)
	bad2.inventory.copies.records[host].state.attached.gem_a.state["destroyed_magic"] = {"source_benefits": {"cause": "x", "source_id": "y"}}
	check.call(not AttachmentRules.saved_error(bad).is_empty() and not AttachmentRules.saved_error(bad2).is_empty(), "044 RS3 tampered attached part state is refused (%s / %s)" % [AttachmentRules.saved_error(bad), AttachmentRules.saved_error(bad2)])
	# RS4: tampered destroyed magic on a stowed copy is refused.
	var d := wearer("b044_rs4")
	var pouch := add(d, Batch043Checks.POUCH)
	var ring := add(d, MANTLE)
	ContainerRules.put(d.inventory, pouch, ring, "main")
	var ddto := d.to_dict()
	var dbad := ddto.duplicate(true)
	for rec in dbad.inventory.copies.records.values():
		for compartment in rec.get("state", {}).get("contents", {}).values():
			for child in compartment: child.state["destroyed_magic"] = {"attachment_sets": {"cause": "x", "source_id": "y"}}
	check.call(ContainerRules.saved_error(ddto).is_empty() and not ContainerRules.saved_error(dbad).is_empty(), "044 RS4 tampered destroyed magic on a contained copy is refused (%s)" % ContainerRules.saved_error(dbad))
	# RS5: stowed copies are not worn and are never suppressed; 043 attunement counting unaffected.
	var e := wearer("b044_rs5")
	var p2 := add(e, Batch043Checks.POUCH)
	var ward := add(e, Batch043Checks.WARD)
	e.inventory.attune_instance(ward, e.character_id)
	ContainerRules.put(e.inventory, p2, ward, "main")
	var mantle := add(e, MANTLE)
	e.inventory.equip_instance(Inventory.Slot.RING_1, mantle)
	var h := cast(e, HUSH)
	var others: Array = []
	for i in 3: others.append(e.inventory.attune_instance(add(e, Batch043Checks.WARD), e.character_id).get("success", false))
	check.call(h.magic_suppression.copies.keys() == [mantle] and others == [true, true, false], "044 RS5 suppression touches only worn copies; stowed attuned copy still counts (%s %s)" % [str(h.magic_suppression.copies.keys()), str(others)])
	# RS6: layering with 041 merged-form suppression: each source restores only its own.
	var f := Batch041Checks.wearer("b044_rs6")
	f.inventory.unequip(Inventory.Slot.RING_1)
	var charm := add(f, MANTLE)
	f.inventory.equip_instance(Inventory.Slot.RING_1, charm)
	var applied := MagicPropertyRules.apply(f, {"source_id": "spell:%s:rs6" % f.character_id, "caster_id": f.character_id, "spell_id": HUSH}, DataLoader.get_spell(HUSH).effects[0])
	Batch041Checks.guise(f, "merged")
	var during := SourceBenefitRules.total(f, "AC")
	SpellEffects.end_concentration(f, [f])
	var after_form := SourceBenefitRules.total(f, "AC")
	f.spell_effects.erase("spell:%s:rs6" % f.character_id)
	check.call(applied.applied and charm in applied.copies and during == 0 and after_form == 0 and SourceBenefitRules.total(f, "AC") == 2 and f.inventory.magic_item_saving_bonus(f.character_id) == 1, "044 RS6 merged-form end keeps the live suppression; suppression end then restores (during=%d after_form=%d)" % [during, after_form])
	# RS7: detaching from a worn host also works and disables only its set.
	var w := wearer("b044_rs7")
	var hh := add(w, HOST)
	for s in ["gem_a", "gem_b"]: AttachmentRules.attach(w.inventory, hh, add(w, GEM), s)
	w.inventory.equip_instance(Inventory.Slot.RING_1, hh)
	var ac_full := SourceBenefitRules.total(w, "AC")
	var off := AttachmentRules.detach(w.inventory, hh, "gem_a")
	check.call(ac_full == 1 and off.success and SourceBenefitRules.total(w, "AC") == 0 and w.inventory.equipped_instance_id(Inventory.Slot.RING_1) == hh, "044 RS7 detach from a worn host works (ac %d)" % ac_full)
	# RS8: legacy save without any S-203/S-210 fields validates.
	var l := Batch041Checks.wearer("b044_rs8")
	var ldto := l.to_dict()
	check.call(MagicPropertyRules.saved_error(ldto).is_empty() and AttachmentRules.saved_error(ldto).is_empty() and InventoryCopies.saved_error(ldto.inventory).is_empty(), "044 RS8 a legacy save without parts or suppression validates")
