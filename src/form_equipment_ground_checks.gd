class_name FormEquipmentGroundChecks
extends RefCounted

const ROSETTE := "fixture:ground_rosette"
const CLASP := "fixture:ground_clasp"

static func load_fixtures() -> void:
	Batch044Checks.load_fixtures()
	if DataLoader.get_item(ROSETTE).is_empty(): DataLoader._load_json_file("res://data/fixtures/form_ground/items.json", "item")

static func room(actors: Array) -> Dictionary:
	return LocalRoomRules.create({"id": "form_ground", "name": "Ground proof", "cells": [[0, 0], [1, 0], [0, 1]], "party_spawns": [[0, 0], [1, 0], [0, 1]], "objects": [], "walls": [], "exits": [], "monster_spawns": [], "encounter_monsters": []}, actors)

static func kit(actor: Character) -> Dictionary:
	var inv := actor.inventory
	for copy in inv.owned_instances():
		if not CurseRules.is_cursed(copy) and copy.state.has("attuned_to"): inv.unattune_instance(str(copy.instance_id), actor.character_id)
	# Clear starting equipment through normal removal transactions, keeping it in the bag.
	for slot in inv.equipped.keys(): inv.unequip(slot)
	var jewel := Batch041Checks.add_copy(actor, ROSETTE)
	var gem := Batch041Checks.add_copy(actor, Batch044Checks.GEM)
	var flask := Batch041Checks.add_copy(actor, Batch043Checks.FLASK)
	AttachmentRules.attach(inv, jewel, gem, "gem_a")
	ContainerRules.put(inv, jewel, flask, "main")
	inv.attune_instance(jewel, actor.character_id)
	var record := inv.get_instance(jewel)
	record.state.charges = 3
	record.state["source_link"] = {"source_id": "fixture:ground-source", "recipient_id": actor.character_id}
	inv.update_instance(record)
	inv.equip_instance(Inventory.Slot.RING_1, jewel)
	var blade := Batch041Checks.add_copy(actor, Batch043Checks.HEX)
	inv.attune_instance(blade, actor.character_id)
	inv.equip_instance(Inventory.Slot.WEAPON, blade)
	var clasp := Batch041Checks.add_copy(actor, CLASP)
	inv.attune_instance(clasp, actor.character_id)
	inv.equip_instance(Inventory.Slot.RING_2, clasp)
	var armor := Batch041Checks.add_copy(actor, "leather_armor")
	inv.equip_instance(Inventory.Slot.BODY, armor)
	while inv.backpack.size() < Inventory.MAX_BACKPACK_SIZE: inv.add_item("dagger")
	return {"jewel": jewel, "gem": gem, "flask": flask, "blade": blade, "clasp": clasp, "armor": armor, "payload": inv.get_instance(jewel)}

static func find(state: Dictionary, id: String) -> Dictionary:
	for object in state.objects:
		for record in object.get("contents", []):
			if str(record.instance_id) == id: return object
	return {}

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "Ground fixture uses ordinary attachment/container/curse/charge rules: " + str(DataLoader.get_load_errors()))
	var actor := Batch041Checks.wearer("ground_owner")
	var other := Batch041Checks.bonder("ground_receiver")
	var kit_ids := kit(actor)
	var state := room([actor, other])
	var host := SpellCastContext.new()
	host.ground_room = state
	var result := Batch041Checks.guise(actor, "dropped", host)
	check.call(result.get("projection", {}).get("projected", false) and result.projection.equipment.dropped.size() == 3 and actor.inventory.backpack.size() == 40 and state.objects.size() == 3, "Ground full backpack drops all three exact copies in one transformation")
	if not result.get("projection", {}).get("projected", false): return
	check.call(result.has("cast_settlement"), "Ground synchronous room host keeps ordinary resolver-owned cast settlement")
	var jewel := find(state, kit_ids.jewel)
	check.call(jewel.position == [0, 0] and jewel.contents[0] == kit_ids.payload and actor.inventory.get_instance(kit_ids.jewel).is_empty() and actor.inventory.equipped_instance_id(Inventory.Slot.RING_2) == kit_ids.clasp, "Ground drop preserves complete nested copy and leaves the blocked curse worn")
	var destroyed := find(state, kit_ids.armor)
	CombatObjectRules.apply_damage(destroyed, 100, "force")
	check.call(destroyed.removed and destroyed.contents.is_empty() and not LocalRoomRules.interact(state, str(destroyed.id), "take", other, kit_ids.armor).success, "Ground destruction cannot be picked up while transformed")
	check.call(LocalRoomRules.interact(state, str(jewel.id), "take", other, kit_ids.jewel).success and other.inventory.get_instance(kit_ids.jewel).state.attached.gem_a.instance_id == kit_ids.gem, "Ground another actor picks up the exact copy and its attached part")
	SpellEffects.end_concentration(actor, [actor, other])
	check.call(actor.inventory.get_instance(kit_ids.jewel).is_empty() and actor.inventory.get_instance(kit_ids.blade).is_empty() and other.inventory.get_instance(kit_ids.jewel).state.charges == 3 and find(state, kit_ids.blade).contents.size() == 1, "Ground reversion neither reclaims transferred equipment nor recreates destroyed equipment")
	var linked := Batch042Checks.linker("ground_linked")
	var first := Batch041Checks.add_copy(linked, "dagger")
	var second := Batch041Checks.add_copy(linked, "dagger")
	BondRules.bond(linked, Batch042Checks.PAIR, first)
	BondRules.bond(linked, Batch042Checks.PAIR, second)
	linked.inventory.equip_instance(Inventory.Slot.WEAPON, first)
	linked.inventory.equip_instance(Inventory.Slot.OFFHAND, second)
	var linked_room := room([linked])
	host.ground_room = linked_room
	var linked_result := Batch041Checks.guise(linked, "dropped", host)
	check.call(linked_result.get("projection", {}).get("projected", false) and not find(linked_room, first).is_empty() and not find(linked_room, second).is_empty() and BondRules.bonded(linked, Batch042Checks.PAIR).is_empty(), "Ground simultaneous linked-copy departures cannot dispose a later selected copy mid-transfer")
	var shattered := CombatObjectRules.make_dropped_item(kit_ids.payload, Vector2i.ZERO, actor.character_id)
	CombatObjectRules.sync_resolution_target(shattered, {"current_hp": 0})
	var spill_room := room([other])
	LocalRoomCombat.capture_ground_items(spill_room, [shattered])
	check.call(find(spill_room, kit_ids.jewel).is_empty() and not find(spill_room, kit_ids.flask).is_empty() and not find(spill_room, kit_ids.gem).is_empty() and DungeonPersistence.local_error(spill_room).is_empty(), "Ground spell destruction/capture removes the host and preserves exact spilled cargo and parts")
	var damaged := {"instance_id": "damaged:copy", "definition_id": "dagger", "state": {"combat_object_hp": 2, "physical": {"hp": 9, "max_hp": 9}}}
	check.call(CombatObjectRules.make_dropped_item(damaged, Vector2i.ZERO, actor.character_id).hp == 2 and LocalRoomRules.placed_item(state, damaged, Vector2i.ZERO).hp == 2, "Ground transfer uses current item HP rather than healing to the old pickup snapshot")
	var damaged_ground := CombatObjectRules.make_dropped_item(damaged, Vector2i.ZERO, actor.character_id)
	CombatObjectRules.apply_damage(damaged_ground, 1, "force")
	var damaged_room := room([other])
	LocalRoomCombat.capture_ground_items(damaged_room, [damaged_ground])
	var damaged_object := find(damaged_room, "damaged:copy")
	var received_damage := LocalRoomRules.interact(damaged_room, str(damaged_object.id), "take", other, "damaged:copy")
	check.call(received_damage.success and CombatObjectRules.make_owned_item(other.inventory.get_instance("damaged:copy"), other.character_id, false, Vector2i.ZERO).hp == 1, "Ground damage survives encounter capture and another actor picking up the copy without healing")
	var cargo: Array = []
	for index in 101: cargo.append({"instance_id": "spill:%d" % index, "definition_id": "diamond_300gp", "state": {}})
	var packed := {"instance_id": "spill:backpack", "definition_id": "backpack", "state": {"contents": {"main": cargo}}}
	var large_spill := CombatObjectRules.make_dropped_item(packed, Vector2i.ZERO, actor.character_id)
	CombatObjectRules.apply_damage(large_spill, 100, "force")
	var large_room := room([other])
	LocalRoomCombat.capture_ground_items(large_room, [large_spill])
	check.call(large_room.objects[0].contents.size() == 101 and DungeonPersistence.local_error(large_room).is_empty(), "Ground spilling a legal weight-limited backpack preserves over 100 exact children through capture")
	var duplicate_room := room([other])
	duplicate_room.objects.append(LocalRoomRules.placed_item(duplicate_room, kit_ids.payload, Vector2i.ZERO))
	var nested_save := {"party": {"characters": {other.character_id: other.to_dict()}}, "active_dungeon_state": {"dungeon_id": "test", "local_rooms": {"room": duplicate_room}}}
	check.call(not InventoryCopies.ownership_error(nested_save).is_empty(), "Ground checkpoint ownership rejects a cargo/attachment copy duplicated in another actor's inventory")
	var malformed_room := duplicate_room.duplicate(true)
	malformed_room.objects[0].contents[0].state.attached.gem_a.state["charges"] = -1
	check.call(not DungeonPersistence.local_error(malformed_room).is_empty(), "Ground checkpoint validates nested part state with the inventory contract")
	# Refuse the complete batch if the final destination or a later copy is invalid.
	var refused_actor := Batch041Checks.wearer("ground_refuse")
	var refused_state := room([refused_actor])
	var before := refused_actor.to_dict()
	var conflict := refused_actor.inventory.get_instance(refused_actor.inventory.equipped_instance_id(Inventory.Slot.RING_2))
	refused_state.objects.append(LocalRoomRules.placed_item(refused_state, conflict, Vector2i.ZERO))
	host.ground_room = refused_state
	var refused := Batch041Checks.guise(refused_actor, "dropped", host)
	check.call(refused.get("refused", false) and refused_actor.inventory.to_dict() == before.inventory and refused_actor.ability_scores.to_dict() == before.ability_scores and refused_actor.spell_slots["2"] == 1 and not ActorProjectionRules.is_projected(refused_actor), "Ground later-copy collision refuses the whole transformation before payment or equipment mutation")
	# Two actors sharing combat cannot independently overfill the eventual room.
	var grid := HexGrid.new()
	grid.tiles[Vector2i.ZERO] = HexTile.new()
	var combat_host := SpellCastContext.new()
	combat_host.grid = grid
	combat_host.players = [{"character": refused_actor, "hex_position": Vector2i.ZERO}]
	var old_context := GameManager.transition_context
	GameManager.transition_context = {"local_room": room([refused_actor])}
	for index in 197: GameManager.transition_context.local_room.objects.append({"id": "filler:%d" % index, "contents": []})
	var pending := CombatObjectRules.make_dropped_item({"instance_id": "pending:1", "definition_id": "dagger", "state": {}}, Vector2i.ZERO, "someone")
	combat_host.ground_items.append(pending)
	combat_host.ground_items.append(CombatObjectRules.make_dropped_item({"instance_id": "pending:2", "definition_id": "dagger", "state": {}}, Vector2i.ZERO, "someone"))
	check.call(FormEquipmentGroundRules.plan(refused_actor, combat_host).has("error"), "Ground complete preflight includes copies already awaiting encounter capture")
	GameManager.transition_context = {}
	check.call(FormEquipmentGroundRules.plan(refused_actor, combat_host).has("error"), "Ground combat without a persistent destination refuses before loss")
	GameManager.transition_context = old_context
	grid.free()
