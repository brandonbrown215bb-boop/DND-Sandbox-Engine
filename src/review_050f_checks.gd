class_name Review050FChecks
extends RefCounted
## Runtime Reviewer: post-merge review of the Batch 050 follow-up
## (9453530/a5d56c6/a495177): dawn recharge wherever the copy is.

const W := "ward@"

static func _stamp(record: Dictionary, id: String) -> int:
	return int(record.get("state", {}).get("feature_uses", {}).get(W + id, -1))

static func run(check: Callable) -> void:
	Batch050Checks.load_fixtures()
	var B := Batch050Checks.BLADE
	# F1 through the real clock: party pack, loaded room, unloaded dungeon, transition room.
	var a := Batch050Checks.actor("r050f_clock")
	var pack := Batch048Checks.add(a, "backpack")
	var stowed := Batch050Checks._spent(a, B)
	ContainerRules.stow(a.inventory, stowed)
	var lying := Batch050Checks._spent(a, B)
	var floor_rec := a.inventory.take_instance(lying)
	var deep := Batch050Checks._spent(a, B)
	var deep_rec := a.inventory.take_instance(deep)
	deep_rec.state["rule_alternatives"] = {W + deep + "|edge": "deep@" + deep}
	var pack2 := Batch048Checks.add(a, "backpack")
	var inner := Batch050Checks._spent(a, B)
	ContainerRules.put(a.inventory, pack2, inner, "main")
	var pack2_rec := a.inventory.take_instance(pack2)
	var shared_room := {"id": "r050f_t", "objects": [{"id": "loose:t", "kind": "loose", "contents": [floor_rec]}]}
	var saved := {"active": GameManager.active_dungeon_state, "snaps": GameManager.dungeon_snapshots, "trans": GameManager.transition_context, "chars": PartyManager.characters, "t": GameManager.campaign_elapsed_seconds}
	GameManager.active_dungeon_state = {"dungeon_id": "r050f_live", "local_rooms": {"1": shared_room}}
	GameManager.dungeon_snapshots = {"r050f_cold": {"dungeon_id": "r050f_cold", "local_rooms": {"9": {"id": "r050f_c", "objects": [{"id": "chest", "kind": "chest", "contents": [deep_rec, pack2_rec]}]}}}}
	GameManager.transition_context = {"local_room": shared_room}
	PartyManager.characters = {a.character_id: a}
	GameManager.campaign_elapsed_seconds = 86400 * 10 + 3600
	GameManager.advance_campaign_time(86400)
	var cold: Array = GameManager.dungeon_snapshots.r050f_cold.local_rooms["9"].objects[0].contents
	var nested_in_room: Dictionary = cold[1].state.contents.values()[0][0]
	check.call(_stamp(ContainerRules.contents(a.inventory, pack)[0], stowed) == 2, "R050F F1 the real campaign clock recharges a blade stowed in the party pack")
	check.call(_stamp(floor_rec, lying) == 2, "R050F F1 a room reachable both as the live room and the transition room recharges once to max 2, never past it (got %d)" % _stamp(floor_rec, lying))
	check.call(_stamp(deep_rec, deep) == 3, "R050F F1 a copy in an unloaded dungeon's room refills to its remembered Deep max 3 (got %d)" % _stamp(deep_rec, deep))
	check.call(_stamp(nested_in_room, inner) == 2, "R050F F1 a copy inside a backpack lying in an unloaded room recharges (got %d)" % _stamp(nested_in_room, inner))
	# F2 save/load: the stamp survives a JSON round trip and a pickup honours it.
	var snap: Variant = JSON.parse_string(JSON.stringify(GameManager.dungeon_snapshots))
	var back_rec: Dictionary = snap.r050f_cold.local_rooms["9"].objects[0].contents[0]
	var finder := Batch050Checks.actor("r050f_finder")
	finder.inventory.receive_instance(back_rec)
	finder.inventory.equip_instance(Inventory.Slot.WEAPON, deep)
	var fr := Character.new()
	fr.from_dict(JSON.parse_string(JSON.stringify(finder.to_dict())))
	check.call(int(finder.feature_uses.get(W + deep, -1)) == 3 and int(fr.feature_uses.get(W + deep, -1)) == 3 and fr.rule_alternatives.get(W + deep + "|edge", "") == "deep@" + deep, "R050F F2 a room copy recharged before save, saved and picked up keeps 3 uses and its option through a character reload")
	# F3 projected (S-165) copies are still the owner's copy: dawn must reach them.
	var vessel := DataLoader.get_item(B).duplicate(true)
	vessel.id = "fixture:r050f_vessel_blade"
	vessel["actor_projection"] = DataLoader.get_item("fixture:b042_figurine").get("actor_projection", {}).duplicate(true)
	check.call(Batch048Checks._loads(vessel), "R050F F3 a dawn item that also projects is a valid definition")
	DataLoader.items[vessel.id] = vessel
	var p := Batch050Checks.actor("r050f_projector")
	var pid := Batch050Checks._spent(p, vessel.id)
	var projected := ItemProjectionRules.project(p, pid)
	OwnedFeatureSources.recover_dawn(p)
	var proj_copy: Dictionary = p.item_projections.get(pid, {}).get("copy", {})
	check.call(projected.get("projected", false) and _stamp(proj_copy, pid) == 2, "R050F F3 a dawn while the copy is projected into an actor recharges it (got %d, projected=%s)" % [_stamp(proj_copy, pid), str(projected)])
	# F4 loader: malformed recharge_while values.
	for bad in [["equipped"], 1, "", "Equipped"]:
		var item := DataLoader.get_item(B).duplicate(true)
		for key in ["_source", "_source_record"]: item.erase(key)
		item.features[0]["recharge_while"] = bad
		check.call(not Batch048Checks._loads(item), "R050F F4 recharge_while %s is refused at load" % JSON.stringify(bad))
	var short := DataLoader.get_item(B).duplicate(true)
	for key in ["_source", "_source_record"]: short.erase(key)
	short.features[0]["uses_per"] = "long_rest"
	short.features[0]["recharge_while"] = "equipped"
	check.call(not Batch048Checks._loads(short), "R050F F4 recharge_while on a long-rest power is refused")
	GameManager.active_dungeon_state = saved.active
	GameManager.dungeon_snapshots = saved.snaps
	GameManager.transition_context = saved.trans
	PartyManager.characters = saved.chars
	GameManager.campaign_elapsed_seconds = saved.t
