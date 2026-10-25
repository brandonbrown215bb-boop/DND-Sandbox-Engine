class_name Batch069Checks
extends RefCounted
## Batch 069 (S-032/S-196): unknown-weight room placement. Absent measurements
## stay unknown through placement, take, combat projection, containers, saved
## validation and legacy migration; volume stays PARTIAL.

const ROOM := "b069_room"

static func room() -> Dictionary:
	return {"id": ROOM, "objects": [], "party_positions": {}}

## A pre-d450b24 dropped copy: mixed/Tiny and item weight (else 1 lb) stamped.
static func legacy_record(id: String, definition: String) -> Dictionary:
	var item := DataLoader.get_item(definition)
	return {"instance_id": id, "definition_id": definition, "state": {"physical": {"room_id": ROOM, "object_id": "placed:" + id, "material": "mixed", "size": "Tiny", "weight_lb": item.get("weight", 1), "fixed": false, "hp": 1, "max_hp": 1}}}

static func legacy_object(id: String, definition: String, position: Vector2i) -> Dictionary:
	var item := DataLoader.get_item(definition)
	return {"id": "placed:" + id, "kind": "loose", "name": item.get("name", definition), "material": "mixed", "size": "Tiny", "weight_lb": item.get("weight", 1), "fixed": false, "hp": 1, "max_hp": 1, "position": [position.x, position.y], "contents": [{"instance_id": id, "definition_id": definition, "state": {}}], "removed": false}

static func run(check: Callable) -> void:
	var state := room()
	# Fresh placement of a real SRD item with no printed weight (Bell, SRD 5.2.1 p.95 lists no weight).
	var bell := LocalRoomRules.placed_item(state, {"instance_id": "b069:bell", "definition_id": "bell", "state": {}}, Vector2i(1, 0))
	check.call(not bell.has("weight_lb") and not bell.has("material") and not bell.has("size") and PhysicalFactsRules.get_mass_lb(bell) == null, "069 a dropped Bell keeps unknown weight, material and size (no 1 lb, no Tiny)")
	var mirror := LocalRoomRules.placed_item(state, {"instance_id": "b069:mirror", "definition_id": "mirror", "state": {}}, Vector2i(2, 0))
	check.call(is_equal_approx(float(mirror.get("weight_lb", -1)), 0.5) and RoomMeasurements.describe_object(mirror).contains("0.5 lb") and RoomMeasurements.describe_object(mirror).contains("unknown material"), "069 a weighed Mirror keeps its 0.5 lb data; its missing material is reported unknown")
	check.call(RoomMeasurements.describe_object(bell) == "unknown material, unknown size, unknown weight", "069 inspect text names every unknown measurement")
	check.call(RoomMeasurements.describe_item("bell").contains("Weight: unknown") and RoomMeasurements.describe_item("bell").contains("PARTIAL") and RoomMeasurements.describe_item("mirror").contains("Weight: 0.5 lb"), "069 item inspection reports data weight or unknown; volume says PARTIAL")
	# Legacy stamps on placed copies are dropped only for facts the data lacks.
	var lb := LocalRoomRules.placed_item(state, legacy_record("b069:old_bell", "bell"), Vector2i(3, 0))
	check.call(not lb.has("weight_lb") and not lb.has("material") and not lb.has("size") and str(lb.id) == "placed:b069:old_bell", "069 a legacy-stamped Bell (mixed/Tiny/1 lb) re-places with unknown measurements and the same identity")
	var lm := LocalRoomRules.placed_item(state, legacy_record("b069:old_mirror", "mirror"), Vector2i(4, 0))
	check.call(is_equal_approx(float(lm.get("weight_lb", -1)), 0.5) and not lm.has("material") and not lm.has("size"), "069 a legacy-stamped Mirror keeps its data weight; stamped material/size return to unknown")
	var authored := {"id": "crate", "kind": "loose", "material": "mixed", "size": "Tiny", "weight_lb": 1, "contents": [{"instance_id": "b069:x", "definition_id": "bell", "state": {}}]}
	check.call(RoomMeasurements.legacy_invented(authored, "bell").is_empty(), "069 an authored (non-placed) object with the same values is data, not a stamp")
	var odd := legacy_record("b069:odd", "bell")
	odd.state.physical.weight_lb = 2
	check.call(RoomMeasurements.legacy_invented(odd.state.physical, "bell").is_empty(), "069 a placed copy whose weight differs from the legacy formula is not treated as a stamp")
	# Combat projection of the same legacy copy.
	var combat := CombatObjectRules.make_dropped_item(legacy_record("b069:c_bell", "bell"), Vector2i.ZERO, "b069_actor")
	check.call(not combat.has("weight_lb") and PhysicalFactsRules.get_mass_lb(combat) == null, "069 a legacy-stamped copy projected into combat has unknown weight")
	var verdict := PhysicalFactsRules.evaluate_physical_eligibility(combat, {"max_mass_lb": 5})
	check.call(not verdict.eligible and str(verdict.reason).contains("unknown"), "069 a max-weight rule refuses the unknown-weight Bell instead of passing it as weightless")
	# Load migration over a dungeon snapshot.
	var dungeon := {"local_rooms": {"0": {"id": ROOM, "objects": [legacy_object("b069:m1", "bell", Vector2i.ZERO), legacy_object("b069:m2", "mirror", Vector2i(1, 0)), authored.duplicate(true)]}}}
	dungeon.local_rooms["0"].objects[0].contents[0].state = legacy_record("b069:m1", "bell").state
	var migrated := RoomMeasurements.migrate_dungeon(dungeon)
	var objs: Array = dungeon.local_rooms["0"].objects
	check.call(migrated == 3 + 3 + 2 and not objs[0].has("weight_lb") and not objs[0].contents[0].state.physical.has("weight_lb") and is_equal_approx(float(objs[1].weight_lb), 0.5) and not objs[1].has("material") and objs[2].has("weight_lb"), "069 load migration clears legacy stamps on placed objects and their copies only (migrated %d)" % migrated)
	check.call(RoomMeasurements.migrate_dungeon(dungeon) == 0, "069 load migration is idempotent")
	# Take keeps unknown in the copy's physical record.
	var take_state := room()
	take_state.objects.append(legacy_object("b069:t", "bell", Vector2i.ZERO))
	var taker := Batch031Checks._character("b069_taker", 30)
	take_state.party_positions[taker.character_id] = [0, 0]
	var took := LocalRoomRules.interact(take_state, "placed:b069:t", "take", taker, "b069:t")
	var held := taker.inventory.get_instance("b069:t")
	check.call(took.success and not held.is_empty() and not held.state.physical.has("weight_lb") and not held.state.physical.has("size"), "069 taking a stamped Bell stores no invented measurement on the copy")
	# Containers: unmeasured occupants are unknown, never 0 lb.
	var fit := ContainerRules._fits({"id": "main", "max_weight": 30}, [{"definition_id": "bell"}], "mirror")
	check.call(fit.contains("no recorded weight"), "069 a weight-limited compartment holding an unmeasured item refuses instead of counting it as 0 lb: %s" % fit)
	check.call(ContainerRules._fits({"id": "main", "max_weight": 30}, [{"definition_id": "mirror"}], "mirror").is_empty(), "069 measured occupants still sum normally")
	check.call(ContainerRules._fits({"id": "main", "max_count": 3}, [{"definition_id": "bell"}], "bell").is_empty(), "069 a count-only compartment needs no weight")
	# Saved physical facts: absent is unknown; present must be real.
	var good := legacy_record("b069:s", "bell")
	good.state.physical.erase("weight_lb")
	check.call(RoomMeasurements.physical_error(good).is_empty() and InventoryCopies.record_state_error(good).is_empty(), "069 a saved copy with absent weight is valid (unknown)")
	for bad_value in [-1, "1 lb", INF]:
		var bad := legacy_record("b069:s", "bell")
		bad.state.physical.weight_lb = bad_value
		check.call(not InventoryCopies.record_state_error(bad).is_empty(), "069 saved physical weight %s is refused" % str(bad_value))
	var bad_size := legacy_record("b069:s", "bell")
	bad_size.state.physical.size = ""
	check.call(not InventoryCopies.record_state_error(bad_size).is_empty(), "069 an empty saved size is refused (absent means unknown)")
