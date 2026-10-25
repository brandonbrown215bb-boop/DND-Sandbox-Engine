class_name ItemFormReturnChecks
extends RefCounted

const ITEM := "fixture:item_form_return"
const RENAMED := "fixture:item_form_renamed"

static func load_fixtures() -> void:
	Batch042Checks.load_fixtures()
	if DataLoader.get_item(ITEM).is_empty(): DataLoader._load_json_file("res://data/fixtures/item_form_return/items.json", "item")

static func fill(a: Character) -> void:
	while a.inventory.backpack.size() < Inventory.MAX_BACKPACK_SIZE: a.inventory.add_item("dagger")

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "S-166 neutral item return fixtures load")
	var policy: Dictionary = DataLoader.get_item(ITEM).actor_projection
	for patch in [{"hp_reset": "revive"}, {"overflow": "owner"}, {"on_zero_hp": "delete_mates"}, {"no_space": "overlap"}, {"destination": "new_copy"}, {"size": "unknown"}, {"range_hexes": 0}, {"original_hp": -1}, {"passengers": []}]:
		var bad := policy.duplicate(true)
		bad.reversion.merge(patch, true)
		check.call(not ItemProjectionRules.policy_error(bad).is_empty(), "S-166 rejects unsupported return declaration " + str(patch))
	for definition in [ITEM, RENAMED]:
		var a := Batch042Checks.linker("return_" + definition)
		var id := Batch042Checks.add(a, definition)
		var other := Batch042Checks.add(a, definition)
		var copy := a.inventory.get_instance(id)
		copy.state["engraving"] = "keep this exact copy"
		a.inventory.update_instance(copy)
		BondRules.bond(a, Batch042Checks.TOTEM, id)
		BondRules.bond(a, Batch042Checks.TOTEM, other)
		ItemProjectionRules.project(a, id)
		ItemProjectionRules.project(a, other)
		var first := ItemProjectionRules.actor(a, id)
		var second := ItemProjectionRules.actor(a, other)
		first.take_damage(7)
		var serial := int(first.get_meta("projection_serial"))
		var result := ItemProjectionRules.revert(a, id, serial)
		check.call(result.reverted and result.destination == "backpack" and a.inventory.get_instance(id).state.engraving == copy.state.engraving and a.inventory.get_instance(id).state.item_form_hp == 22 and ItemProjectionRules.actor(a, other) == second and second.current_hp == 22, "S-166 voluntary ending preserves exact state and independent identical form " + definition)
		check.call(not ItemProjectionRules.revert(a, id, serial).reverted and a.inventory.count_item(definition) == 1, "S-166 duplicate ending callback returns nothing twice")
		ItemProjectionRules.project(a, id)
		check.call(not ItemProjectionRules.revert(a, id, serial).reverted and ItemProjectionRules.actor(a, id).current_hp == 22, "S-166 stale ending callback cannot end a later activation")
		var form := ItemProjectionRules.actor(a, id)
		form.temp_hp = 5
		form.take_damage(30) # 5 temporary + 22 form + 3 original.
		var returned := a.inventory.get_instance(id)
		check.call(not ItemProjectionRules.is_projected(a, id) and returned.state.combat_object_hp == 9 and returned.state.item_form_hp == 22 and BondRules.bonded(a, Batch042Checks.TOTEM) == [id, other], "S-166 lethal damage uses post-temp-HP overflow and preserves both bonds")
		form.take_damage(100)
		ItemProjectionRules.settle(a)
		check.call(a.inventory.get_instance(id) == returned, "S-166 repeated damage/end settlement cannot replay overflow")
		ItemProjectionRules.revert(a, other)
	# Full inventory: damage settles now; only placement waits, across JSON reload.
	var a := Batch042Checks.linker("blocked_return")
	var id := Batch042Checks.add(a, ITEM)
	ItemProjectionRules.project(a, id)
	fill(a)
	var form := ItemProjectionRules.actor(a, id)
	form.take_damage(25)
	var dto := a.to_dict()
	check.call(ItemProjectionRules.is_projected(a, id) and not form.is_alive and dto.item_projections[id].ending.overflow == 3 and dto.item_projections[id].copy.state.combat_object_hp == 9 and ItemProjectionRules.saved_error(dto).is_empty(), "S-166 full backpack and unavailable ground preserve a valid pending exact copy")
	var restored := Character.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(dto)))
	for _i in 3:
		ItemProjectionRules.settle(restored)
		ItemProjectionRules.revert(restored, id)
	check.call(restored.item_projections[id].copy.state.combat_object_hp == 9 and restored.inventory.backpack.size() == 40, "S-166 blocked/recovered callbacks neither replay overflow nor exceed inventory capacity")
	var removed := str(restored.inventory.backpack_instances()[0].instance_id)
	restored.inventory.take_instance(removed)
	check.call(ItemProjectionRules.revert(restored, id).reverted and restored.inventory.get_instance(id).state.combat_object_hp == 9 and restored.inventory.backpack.size() == 40, "S-166 opening a bag slot returns the original identity once")
	for mutate in [func(d): d.item_projections[id].ending.overflow = -1, func(d): d.item_projections[id].ending.location = {"position": [0, 0]}, func(d): d.item_projections[id].actor.current_hp = 1, func(d): d.item_projections[id].copy.state.item_form_serial = "1", func(d): d.item_projections[id].copy.state.combat_object_hp = 99]:
		var bad := dto.duplicate(true)
		mutate.call(bad)
		check.call(not ItemProjectionRules.saved_error(bad).is_empty(), "S-166 malformed pending HP/location/serial refuses save preflight")
	# A voluntary refusal leaves the living form alone.
	var b := Batch042Checks.linker("voluntary_blocked")
	var blocked := Batch042Checks.add(b, ITEM)
	ItemProjectionRules.project(b, blocked)
	fill(b)
	check.call(not ItemProjectionRules.revert(b, blocked).reverted and ItemProjectionRules.actor(b, blocked).is_alive and not b.item_projections[blocked].has("ending"), "S-166 blocked voluntary ending does not commit reversion")
	# Authored preserve/discard/destruction branches, without a content-ID dispatch.
	var c := Batch042Checks.linker("ending_policies")
	var worn := Batch042Checks.add(c, ITEM)
	var old_copy := c.inventory.get_instance(worn)
	old_copy.state["physical"] = {"hp": 3}
	c.inventory.update_instance(old_copy)
	ItemProjectionRules.project(c, worn)
	ItemProjectionRules.actor(c, worn).take_damage(27)
	check.call(c.inventory.get_instance(worn).is_empty() and not ItemProjectionRules.is_projected(c, worn), "S-166 overflow honors existing physical HP instead of healing the original")
	var keep := Batch042Checks.add(c, "fixture:item_form_preserve")
	ItemProjectionRules.project(c, keep)
	ItemProjectionRules.actor(c, keep).take_damage(6)
	ItemProjectionRules.revert(c, keep)
	ItemProjectionRules.project(c, keep)
	check.call(ItemProjectionRules.actor(c, keep).current_hp == 16, "S-166 preserve HP policy survives returning and projecting again")
	ItemProjectionRules.revert(c, keep)
	var discard := Batch042Checks.add(c, "fixture:item_form_discard")
	ItemProjectionRules.project(c, discard)
	ItemProjectionRules.actor(c, discard).take_damage(999)
	check.call(not c.inventory.get_instance(discard).is_empty() and not c.inventory.get_instance(discard).state.has("combat_object_hp"), "S-166 discard overflow policy returns the original even after massive damage")
	var linked: Dictionary = DataLoader.get_character_class(Batch042Checks.CLASS_ID).features_by_level["1"][1].duplicate(true)
	linked["on_loss"] = "dispose_group"
	c.features.append(linked)
	for definition in [ITEM, "fixture:item_form_fragile", "fixture:item_form_spent"]:
		var doomed := Batch042Checks.add(c, definition)
		var mate := Batch042Checks.add(c, definition)
		BondRules.bond(c, Batch042Checks.TOTEM, doomed)
		BondRules.bond(c, Batch042Checks.TOTEM, mate)
		ItemProjectionRules.project(c, doomed)
		if definition == "fixture:item_form_spent": ItemProjectionRules.revert(c, doomed)
		else: ItemProjectionRules.actor(c, doomed).take_damage(34 if definition == ITEM else 22)
		check.call(not ItemProjectionRules.is_projected(c, doomed) and c.inventory.get_instance(doomed).is_empty() and not c.inventory.get_instance(mate).is_empty() and BondRules.bonded(c, Batch042Checks.TOTEM) == [mate], "S-166 declared destruction removes only the original identity " + definition)
		BondRules.release(c, Batch042Checks.TOTEM, mate)
