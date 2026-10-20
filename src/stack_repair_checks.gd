class_name StackRepairChecks
extends RefCounted
## Regressions found while reviewing the combined 034-046 stack.

static func run(check: Callable) -> void:
	Batch046Checks.load_fixtures()
	_projected_copies(check)
	_form_equipment_and_hp(check)
	_active_storage(check)
	_work_interruptions(check)
	_subclass_modes(check)

static func _projected_copies(check: Callable) -> void:
	var giver := Batch042Checks.linker("repair_giver")
	var owner := Batch042Checks.linker("repair_owner")
	var id := Batch041Checks.add_copy(giver, Batch042Checks.FIGURINE)
	check.call(giver.inventory.transfer_instance(id, owner.inventory) and ItemProjectionRules.project(owner, id).get("projected", false), "Stack: a transferred exact figurine can project")
	var dto := owner.to_dict()
	check.call(ItemProjectionRules.saved_error(dto).is_empty(), "Stack: a transferred projected copy remains saveable")
	var back := Character.new()
	back.from_dict(JSON.parse_string(JSON.stringify(dto)))
	check.call(ItemProjectionRules.revert(back, id).get("reverted", false) and back.inventory.get_instance(id).instance_id == id, "Stack: transferred projection reloads and returns the original identity")
	var bad := dto.duplicate(true)
	bad.item_projections[id].copy.state["active"] = true
	check.call(not ItemProjectionRules.saved_error(bad).is_empty(), "Stack: projected copies use the ordinary per-copy state validator")
	bad = dto.duplicate(true)
	bad.item_projections[id].copy.state["contents"] = {"bogus": []}
	check.call(not ItemProjectionRules.saved_error(bad).is_empty(), "Stack: projected copies cannot hide undeclared nested contents")
	var duplicate := Batch042Checks.linker("repair_duplicate")
	duplicate.inventory.receive_instance(dto.item_projections[id].copy)
	check.call(not InventoryCopies.ownership_error({"party": {"characters": {owner.character_id: dto, duplicate.character_id: duplicate.to_dict()}}}).is_empty(), "Stack: global ownership includes projected copies")
	check.call(not InventoryCopies.ownership_error({"players": [{"character": dto}, {"character": duplicate.to_dict()}]}).is_empty(), "Stack: legacy player-only ownership includes projected copies")
	var repeated := dto.duplicate(true)
	repeated.item_projections.clear()
	check.call(not InventoryCopies.ownership_error({"party": {"characters": {owner.character_id: dto}}, "players": [{"character": repeated}]}).is_empty(), "Stack: repeated player and party projection records must agree")
	var own := Batch042Checks.linker("repair_serial")
	var own_id := Batch041Checks.add_copy(own, Batch042Checks.FIGURINE)
	ItemProjectionRules.project(own, own_id)
	var reused := own.to_dict()
	reused.inventory.copies.next_id = int(own_id.get_slice(":", 1))
	check.call(not ItemProjectionRules.saved_error(reused).is_empty(), "Stack: the inventory serial cannot reuse a projected identity")
	ItemProjectionRules.revert(owner, id)
	ItemProjectionRules.revert(own, own_id)

static func _form_equipment_and_hp(check: Callable) -> void:
	var full := Batch041Checks.wearer("repair_full")
	while full.inventory.backpack.size() < Inventory.MAX_BACKPACK_SIZE: full.inventory.add_item("dagger")
	var before := full.inventory.to_dict()
	full.spell_slots = {"2": 1}
	var spell := DataLoader.get_spell(Batch041Checks.GUISE).duplicate(true)
	spell["_projection_equipment"] = "dropped"
	var refused := SpellResolver.resolve(full, full, spell, true, {}, [], 2)
	check.call(refused.get("refused", false) and full.spell_slots["2"] == 1 and full.inventory.to_dict() == before and not ActorProjectionRules.is_projected(full), "Stack: full-bag dropped equipment refuses before slot, stats or copies change")
	var a := Batch040Checks.caster("repair_hp")
	a.temp_hp = 20
	Batch040Checks.shift(a, 2, "b040_hound")
	a.absorb_temporary_hp(15)
	SpellEffects.end_concentration(a, [])
	check.call(a.temp_hp == 5 and not ActorProjectionRules.is_projected(a), "Stack: reversion preserves unrelated Temporary HP after partial damage")
	a.temp_hp = 0
	Batch040Checks.shift(a, 2, "b040_hound")
	a.absorb_temporary_hp(3)
	var dto := a.to_dict()
	check.call(ActorProjectionRules.saved_record_error(dto, a.spell_effects.values()[0]).is_empty(), "Stack: damaged projection-owned Temporary HP validates")
	var back := Character.new()
	back.from_dict(JSON.parse_string(JSON.stringify(dto)))
	SpellEffects.end_concentration(back, [])
	check.call(back.temp_hp == 0 and not ActorProjectionRules.is_projected(back), "Stack: reload keeps Temporary HP ownership and self concentration cleanup")
	a.temp_hp = 30
	a.absorb_temporary_hp(25)
	SpellEffects.end_concentration(a, [])
	check.call(a.temp_hp == 5, "Stack: a replacement Temporary HP grant survives projection expiry")
	Batch027Checks.load_fixtures()
	var supplier := Batch027Checks.actor("repair_supplier", "fixture:027_class_plain")
	a.temp_hp = 0
	Batch040Checks.shift(a, 2, "b040_hound")
	a.absorb_temporary_hp(2) # Match the incoming eight-HP grant exactly.
	a.willingness = "willing"
	var replacement := Batch027Checks.give(supplier, a)
	SpellEffects.end_concentration(a, [])
	check.call(replacement.get("success", false) and a.temp_hp == 8 and not a.linked_temporary_hp.is_empty(), "Stack: explicitly accepting an equal amount transfers Temporary HP ownership")
	var reconciled := Batch040Checks.caster("repair_self")
	Batch040Checks.shift(reconciled, 2, "b040_hound")
	SpellEffects.reconcile([reconciled], [reconciled])
	check.call(ActorProjectionRules.is_projected(reconciled) and reconciled.concentrating_on.targets.is_empty(), "Stack: reconciliation preserves self concentration without a reference cycle")
	SpellEffects.end_concentration(reconciled, [])

static func _active_storage(check: Callable) -> void:
	var a := Batch045Checks.actor("repair_active")
	var lamp := Batch045Checks.add(a, Batch045Checks.LAMP)
	# Review pouch fixture is loaded explicitly because it is outside the batch chain.
	if DataLoader.get_item("fixture:b043_review_pouch").is_empty():
		DataLoader._load_json_file("res://data/fixtures/batch_043/items/review_pouch.json", "item")
	var bag := Batch045Checks.add(a, "fixture:b043_review_pouch")
	ActiveTimeRules.activate(a, lamp, 0)
	var before := a.inventory.to_dict()
	var refused := ContainerRules.put(a.inventory, bag, lamp, "main")
	check.call(not refused.get("success", false) and a.inventory.to_dict() == before, "Stack: active copies cannot hide their ticking budget inside containers")
	ActiveTimeRules.pause(a, lamp)
	var stored := ContainerRules.put(a.inventory, bag, lamp, "main")
	var hidden_active := a.to_dict()
	if stored.get("success", false): hidden_active.inventory.copies.records[bag].state.contents.main[0].state.active = true
	check.call(stored.get("success", false) and not ContainerRules.saved_error(hidden_active).is_empty(), "Stack: a saved container cannot hide an active clock")
	ActiveTimeRules.settle(a, 10000, 10000)
	ContainerRules.remove(a.inventory, bag, lamp)
	check.call(stored.get("success", false) and not ActiveTimeRules.is_active(a.inventory.get_instance(lamp)) and ActiveTimeRules.used(a.inventory.get_instance(lamp)) == 0, "Stack: a paused stored copy keeps its exact allowance")

static func _work_interruptions(check: Callable) -> void:
	var a := Batch046Checks.actor("repair_worker")
	var helper := Batch046Checks.actor("repair_helper")
	PartyManager.characters[a.character_id] = a
	PartyManager.characters[helper.character_id] = helper
	var frame := Batch046Checks.add(a, Batch046Checks.FRAME)
	WorkRules.start(a, frame)
	WorkRules.join(helper, a, frame)
	WorkRules.settle(a, 600, 600)
	var other_work := Batch046Checks.add(helper, Batch046Checks.TOME)
	var helper_dto := helper.to_dict()
	helper_dto.inventory.copies.records[other_work].state["work_active"] = true
	helper_dto.inventory.copies.records[other_work].state["work_participants"] = [helper.character_id]
	check.call(not InventoryCopies.ownership_error({"players": [{"character": a.to_dict()}, {"character": helper_dto}]}).is_empty(), "Stack: player-only saves refuse double-booked work")
	check.call(not InventoryCopies.ownership_error({"party": {"characters": {a.character_id: a.to_dict()}}, "players": [{"character": helper_dto}]}).is_empty(), "Stack: mixed party/player saves refuse double-booked work")
	check.call(InventoryCopies.ownership_error({"party": {"characters": {a.character_id: a.to_dict(), helper.character_id: helper.to_dict()}}, "players": [{"character": a.to_dict()}]}).is_empty(), "Stack: a repeated canonical party member is not counted as a second work")
	check.call(a.inventory.transfer_instance(frame, helper.inventory) and WorkRules.progress(helper.inventory.get_instance(frame)) == 0 and not WorkRules.is_active(helper.inventory.get_instance(frame)), "Stack: losing work resets immediately, even if the copy returns before time advances")
	helper.inventory.transfer_instance(frame, a.inventory)
	WorkRules.start(a, frame)
	WorkRules.join(helper, a, frame)
	WorkRules.settle(a, 600, 1200)
	var prior_state := GameManager.current_state
	GameManager.current_state = GameManager.GameState.OVERWORLD
	var rest := RestRules.complete_long_rest([helper], {"skip_campaign_time": true})
	check.call(rest.get("success", false) and not WorkRules.is_active(a.inventory.get_instance(frame)) and WorkRules.progress(a.inventory.get_instance(frame)) == 0, "Stack: a resting helper interrupts group work through its own reset policy")
	var tome := Batch046Checks.add(a, Batch046Checks.TOME)
	WorkRules.start(a, tome)
	WorkRules.settle(a, 600, 1800)
	RestRules.complete_long_rest([a], {"skip_campaign_time": true})
	WorkRules.settle(a, 28800, 30600)
	check.call(not WorkRules.is_active(a.inventory.get_instance(tome)) and WorkRules.progress(a.inventory.get_instance(tome)) == 600, "Stack: rest time cannot accrue work and keeps only previously earned progress")
	GameManager.current_state = prior_state
	PartyManager.characters.erase(a.character_id)
	PartyManager.characters.erase(helper.character_id)

static func _subclass_modes(check: Callable) -> void:
	Batch038Checks.load_fixtures()
	var id := "fixture:repair_subclass"
	var features: Array = []
	for records in DataLoader.get_character_class("fixture:b038_class").features_by_level.values(): features.append_array(records)
	DataLoader.subclasses[id] = {"id": id, "class_id": "fighter", "features_by_level": {"3": features}}
	var a := Batch031Checks._character("repair_subclass", 40)
	a.subclass_id = id
	while a.level < 3: a.level_up()
	var stance := Batch038Checks.STANCE
	var chosen := RuleUpgradeRules.choose_alternative(a, stance, "focus", "fixture:b038_alt_b")
	a.feature_uses[stance] = a.get_feature_max_uses(stance)
	var activated := FeatureModeRules.activate(a, stance, "guard")
	FeatureModeRules.on_event(a, "hit")
	var dto := a.to_dict()
	check.call(chosen and activated.success and FeatureModeRules.saved_error(dto).is_empty() and RuleUpgradeRules.saved_error(dto).is_empty(), "Stack: subclass mode, upgrade alternative and hit window all validate")
	var back := Character.new()
	back.from_dict(JSON.parse_string(JSON.stringify(dto)))
	check.call(back.feature_modes == a.feature_modes and back.rule_alternatives == a.rule_alternatives and FeatureModeRules.switch(back, stance, "guard", "hit").reason == "same_mode", "Stack: subclass mode state and its event window survive reload")
	var unowned := dto.duplicate(true)
	unowned.level = 2
	check.call(not FeatureModeRules.saved_error(unowned).is_empty() and not RuleUpgradeRules.saved_error(unowned).is_empty(), "Stack: subclass features above the saved level remain unowned")
	DataLoader.subclasses.erase(id)
