extends Node

const SLOT := "batch_021_checkpoint"
const MANIFEST := "user://batch_021_manifest.json"

func _ready() -> void:
	GameManager.test_mode = true
	SpellPermissionChecks.load_fixtures()
	if OS.get_environment("BATCH_021_RELAUNCH_PHASE") == "prepare": _prepare()
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
	var c := SpellPermissionChecks.actor()
	for source in SpellRepertoireRules.sources(c):
		if not SpellRepertoireRules.choose(c, str(source.id), ["fixture:021_shared0"], source): return _fail("Preparation refused")
	c.long_rest()
	var second := SpellRepertoireRules.sources(c)[1]
	if not SpellRepertoireRules.choose(c, str(second.id), ["fixture:021_b0"], second): return _fail("Rest replacement refused")
	for index in 2: c.inventory.add_item("fixture:021_ring")
	var rings := c.inventory.backpack_instances()
	for index in 2:
		if not c.inventory.equip_instance(Inventory.Slot.RING_1 if index == 0 else Inventory.Slot.RING_2, str(rings[index].instance_id)): return _fail("Equip refused")
		if not c.inventory.attune_instance(str(rings[index].instance_id), c.character_id).get("success", false): return _fail("Attunement refused")
	var permission: Dictionary = c.get_spell_permissions("fixture:021_shared0").filter(func(row): return row.kind == "item")[0]
	var cast := SpellCastContext.new()
	cast.caster = c
	cast.spell = DataLoader.get_spell("fixture:021_shared0").duplicate(true)
	cast.spell.merge({"_source_permission_id":permission.id,"_spell_payment_kind":"item_charges","_spell_payment_source_id":permission.source_id,"_spellcasting_ability":permission.ability})
	if not SpellCastResources.commit_spell_resource(cast): return _fail("Item payment refused")
	PlayerManager.set_player_character(0, c)
	PartyManager.characters[c.character_id] = c
	if not SaveManager.save_game(SLOT): return _fail("Allowed checkpoint refused")
	var manifest := {"pid":OS.get_process_id(),"owner":c.character_id,"choices":c.feature_choices,"receipts":c.spell_repertoire_state,"inventory":c.inventory.to_dict(),"permissions":c.get_spell_permissions("fixture:021_shared0"),"slots":c.spell_slots}
	file = FileAccess.open(MANIFEST, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	print("BATCH 021 FRESH PREPARED: " + JSON.stringify(manifest))
	get_tree().quit()

func _recover() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if int(manifest.get("pid", 0)) == OS.get_process_id() or not SaveManager.load_game(SLOT): return _fail("Distinct-process recovery refused")
	var c: Character = PartyManager.characters.get(str(manifest.owner))
	if c == null or c.feature_choices != manifest.choices or _plain(c.spell_repertoire_state) != manifest.receipts or _plain(c.inventory.to_dict()) != manifest.inventory or _plain(c.spell_slots) != manifest.slots or _plain(c.get_spell_permissions("fixture:021_shared0")) != manifest.permissions: return _fail("Source identity, choices, replacement windows or payment changed during recovery")
	if SpellRepertoireRules.can_edit(c, SpellRepertoireRules.sources(c)[1]): return _fail("Spent replacement window reopened during recovery")
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_DIR + SLOT + ".sav"))
	var refused := 0
	for mutation in ["shape", "list", "capacity", "level", "fraction", "receipt", "boundary", "charge"]:
		for carrier in ["party", "players"]:
			var invalid := base.duplicate(true)
			var dto: Dictionary = invalid.party.characters[str(manifest.owner)] if carrier == "party" else invalid.players[0].character
			match mutation:
				"shape": dto.spell_repertoire_state = []
				"list": dto.feature_choices["fixture:021_a_casting"] = ["fixture:021_b0"]
				"capacity": dto.feature_choices["fixture:021_b_casting"] = ["fixture:021_b0", "fixture:021_b1"]
				"level": dto.spell_repertoire_state["fixture:021_a_casting"].level = 20
				"fraction": dto.spell_repertoire_state["fixture:021_a_casting"].level = 1.5
				"receipt": dto.spell_repertoire_state["missing"] = {"level":1,"rest_open":false}
				"boundary": dto.spell_repertoire_state["fixture:021_a_casting"].rest_open = true
				"charge": dto.inventory.copies.records.values()[0].state.charges = 4
			var slot: String = "batch_021_invalid_" + mutation + "_" + carrier
			var file := FileAccess.open(SaveManager.SAVE_DIR + slot + ".sav", FileAccess.WRITE)
			file.store_string(JSON.stringify(invalid))
			file.close()
			var before := c.to_dict().duplicate(true)
			if SaveManager.load_game(slot) or PartyManager.characters.get(str(manifest.owner)) != c or c.to_dict() != before: return _fail("Malformed full save changed live state: " + slot)
			refused += 1
	print("BATCH 021 FRESH RELAUNCH PASSED: " + JSON.stringify({"pid":OS.get_process_id(),"owner":c.character_id,"full_saves_refused":refused,"choices":c.feature_choices,"receipts":c.spell_repertoire_state,"permissions":c.get_spell_permissions("fixture:021_shared0")}))
	get_tree().quit()

func _fail(message: String) -> void:
	push_error("[Batch021FreshRelaunchProbe] " + message)
	get_tree().quit(1)

func _plain(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))
