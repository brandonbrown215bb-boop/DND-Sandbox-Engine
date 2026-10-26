class_name Batch078Checks
extends RefCounted
## Batch 078 (#41 follow-up, S-032/S-196). Brandon: "stop presenting the default
## 20 as a real container capacity. Use declared capacities, and keep any
## temporary technical limit separate and labeled. Fill in documented weights
## but don't invent them; the SRD lists the bell as '—' (p.95)."

static func room() -> Dictionary:
	return {"id": "b078_room", "objects": [
		{"id": "b078_declared", "kind": "container", "name": "Declared box", "position": [0, 0], "open": true, "contents": [], "capacity": 1},
		{"id": "b078_undeclared", "kind": "container", "name": "Plain box", "position": [0, 0], "open": true, "contents": []},
	], "party_positions": {}}

static func run(check: Callable) -> void:
	var state := room()
	var c := Batch031Checks._character("b078_actor", 60)
	state.party_positions[c.character_id] = [0, 0]
	var d1 := Batch041Checks.add_copy(c, "dagger")
	var d2 := Batch041Checks.add_copy(c, "dagger")
	var declared := LocalRoomRules.get_object(state, "b078_declared")
	var undeclared := LocalRoomRules.get_object(state, "b078_undeclared")
	check.call(LocalRoomRules.interact(state, "b078_declared", "put", c, d1).success, "078 a container with declared capacity 1 accepts one item")
	var refused := LocalRoomRules.interact(state, "b078_declared", "put", c, d2)
	check.call(not refused.success and str(refused.message).contains("declared capacity 1") and declared.contents.size() == 1 and not c.inventory.get_instance(d2).is_empty(), "078 the declared capacity is enforced and the refused copy stays held")
	check.call(RoomMeasurements.declared_capacity(undeclared) == null and not RoomMeasurements.capacity_text(undeclared).contains("capacity 20"), "078 an undeclared container has no capacity number")
	var inspect := LocalRoomRules.interact(state, "b078_undeclared", "inspect", c)
	check.call(str(inspect.message).contains("capacity undeclared") and str(inspect.message).contains("engine technical limit %d items (not a game rule)" % RoomMeasurements.TECHNICAL_CONTENTS_LIMIT), "078 inspect labels undeclared capacity and the technical limit separately")
	check.call(str(LocalRoomRules.interact(state, "b078_declared", "inspect", c).message).contains("capacity 1 items (declared)"), "078 inspect reports the declared capacity as data")
	for i in RoomMeasurements.TECHNICAL_CONTENTS_LIMIT: undeclared.contents.append({"instance_id": "b078:f%d" % i, "definition_id": "torch", "state": {}})
	var limit := LocalRoomRules.interact(state, "b078_undeclared", "put", c, d2)
	check.call(not limit.success and str(limit.message).contains("Engine technical limit") and str(limit.message).contains("not a game rule") and not c.inventory.get_instance(d2).is_empty(), "078 the technical limit refuses with its own label, not as container capacity")
	var big := {"id": "b078_big", "kind": "container", "capacity": 40, "contents": undeclared.contents.duplicate()}
	check.call(RoomMeasurements.put_error(big).contains("Engine technical limit"), "078 the technical limit stays separate from a larger declared capacity")
	check.call(not RoomMeasurements.put_error(big).contains("capacity is undeclared"), "Review: reaching the technical limit does not mislabel a declared capacity")
	var invalid_refused := 0
	for invalid in ["1", -1, 1.5, NAN, INF]:
		var malformed := {"capacity": invalid, "contents": []}
		if not RoomMeasurements.put_error(malformed).is_empty(): invalid_refused += 1
	check.call(invalid_refused == 5 and RoomMeasurements.put_error({"capacity": 0, "contents": []}).contains("full"), "Review: malformed capacities refuse instead of becoming undeclared; capacity zero stays full")
	check.call(not DataLoader.get_item("bell").has("weight") and RoomMeasurements.describe_item("bell").contains("Weight: unknown"), "078 the Bell's SRD '—' weight stays unknown (p.95)")
	check.call(float(DataLoader.get_item("dagger").get("weight", -1)) == 1.0 and RoomMeasurements.describe_item("dagger").contains("Weight: 1 lb"), "078 the filled SRD Dagger weight (1 lb, p.91) is used")
	check.call(not DataLoader.get_item("sling").has("weight") and float(DataLoader.get_item("chain_mail").get("weight", -1)) == 55.0 and float(DataLoader.get_item("dart").get("weight", -1)) == 0.25, "078 Sling '—' stays unknown; Chain Mail 55 lb and Dart 1/4 lb come from the SRD")
