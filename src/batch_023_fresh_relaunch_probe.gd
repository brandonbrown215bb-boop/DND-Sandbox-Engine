extends Node

const SLOT := "batch_023_checkpoint"
const MANIFEST := "user://batch_023_manifest.json"

func _ready() -> void:
	GameManager.test_mode = true
	DataLoader._load_json_file("res://data/fixtures/shared_numeric_pool_exchange.json", "class")
	if OS.get_environment("BATCH_023_RELAUNCH_PHASE") == "prepare": _prepare()
	else: _recover()

func _prepare() -> void:
	var file := FileAccess.open(SaveManager.SAVE_DIR + SLOT + ".sav", FileAccess.WRITE)
	if file == null: return _fail("Cannot stage checkpoint")
	file.store_string(FileAccess.get_file_as_string("res://data/fixtures/save_v2_2024.json"))
	file.close()
	if not SaveManager.load_game(SLOT): return _fail("Base checkpoint refused")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	PlayerManager.reset()
	PartyManager.reset()
	var scores := AbilityScores.new()
	scores.from_dict({"STR":10,"DEX":10,"CON":12,"INT":16,"WIS":10,"CHA":10})
	var actors: Array[Character] = []
	for index in 2:
		var c := Character.new()
		c.initialize("Exchange %d" % index, "human", "fixture:pool_exchange_class", scores)
		c.character_id = "fixture:023_owner_%d" % index
		if not ResourcePoolRules.acquire(c, c.get_feature("fixture:exchange_pool_b"), "fixture:023:destination:%d" % index).get("success", false): return _fail("Destination pool acquisition refused")
		PlayerManager.add_player(c.character_name)
		PlayerManager.set_player_character(index, c)
		PartyManager.register_player_character(index, c)
		actors.append(c)
	var owner: Character = actors[0]
	var recipient: Character = actors[1]
	for index in 3: owner.inventory.add_item("torch")
	var before := owner.inventory.backpack_instances()
	var feature := owner.get_feature("fixture:exchange_inventory_to_party_member").duplicate(true)
	var payment := ResourcePoolRules.exchange_payment_sources(owner, feature.resource_exchange)[0]
	var destination_id := ResourcePoolRules.source_instance_ids(recipient, "fixture:exchange_pool_b_uses")[0]
	feature.selected_payment_source_instance_id = payment
	feature.selected_restoration_source_instance_id = ResourcePoolRules._party_pool_token(recipient.character_id, destination_id)
	var result := ClassFeature.execute(owner, feature)
	if not result.get("success", false) or owner.inventory.count_item("torch") != 1 or recipient.numeric_resource_pools[destination_id].current != 1: return _fail("Inventory exchange refused")
	if not SaveManager.save_game(SLOT): return _fail("Allowed checkpoint refused")
	var manifest := {"pid":OS.get_process_id(),"owner":owner.character_id,"recipient":recipient.character_id,"destination":destination_id,"inventory":owner.inventory.to_dict(),"owner_pools":owner.numeric_resource_pools,"recipient_pools":recipient.numeric_resource_pools,"spent":[before[0].instance_id,before[1].instance_id],"survivor":before[2]}
	file = FileAccess.open(MANIFEST, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	print("BATCH 023 FRESH PREPARED: " + JSON.stringify(manifest))
	get_tree().quit()

func _recover() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if int(manifest.get("pid", 0)) == OS.get_process_id() or not SaveManager.load_game(SLOT): return _fail("Distinct-process recovery refused")
	var owner: Character = PartyManager.characters.get(str(manifest.owner))
	var recipient: Character = PartyManager.characters.get(str(manifest.recipient))
	if owner == null or recipient == null or _plain(owner.inventory.to_dict()) != manifest.inventory or _plain(owner.numeric_resource_pools) != manifest.owner_pools or _plain(recipient.numeric_resource_pools) != manifest.recipient_pools: return _fail("Exchange inventory or either source quantity changed on recovery")
	for id in manifest.spent:
		if not owner.inventory.get_instance(str(id)).is_empty(): return _fail("Spent inventory copy was recreated")
	if _plain(owner.inventory.get_instance(str(manifest.survivor.instance_id))) != manifest.survivor: return _fail("Unspent copy identity/state changed")
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_DIR + SLOT + ".sav"))
	var refused := 0
	for mutation in ["duplicate_copy", "missing_copy", "over_capacity", "foreign_pool"]:
		for carrier in ["party", "players"]:
			var invalid := base.duplicate(true)
			var dto: Dictionary = invalid.party.characters[str(manifest.owner)] if carrier == "party" else invalid.players[0].character
			match mutation:
				"duplicate_copy": dto.inventory.copies.backpack.append(dto.inventory.copies.backpack[0])
				"missing_copy": dto.inventory.copies.records.erase(str(manifest.survivor.instance_id))
				"over_capacity": dto.numeric_resource_pools.values()[0].current = 101
				"foreign_pool": dto.numeric_resource_pools.values()[0].owner_id = manifest.recipient
			var slot := "batch_023_invalid_%s_%s" % [mutation, carrier]
			var file := FileAccess.open(SaveManager.SAVE_DIR + slot + ".sav", FileAccess.WRITE)
			file.store_string(JSON.stringify(invalid))
			file.close()
			var before := owner.to_dict().duplicate(true)
			var recipient_before := recipient.to_dict().duplicate(true)
			if SaveManager.load_game(slot) or PartyManager.characters.get(str(manifest.owner)) != owner or PartyManager.characters.get(str(manifest.recipient)) != recipient or owner.to_dict() != before or recipient.to_dict() != recipient_before: return _fail("Malformed full save changed live state: " + slot)
			refused += 1
	print("BATCH 023 FRESH RELAUNCH PASSED: " + JSON.stringify({"pid":OS.get_process_id(),"full_saves_refused":refused,"survivor":manifest.survivor,"spent":manifest.spent,"destination_current":recipient.numeric_resource_pools[str(manifest.destination)].current}))
	get_tree().quit()

func _plain(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func _fail(message: String) -> void:
	push_error("[Batch023FreshRelaunchProbe] " + message)
	get_tree().quit(1)
