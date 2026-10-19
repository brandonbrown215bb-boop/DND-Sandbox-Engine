extends Node

const SLOT := "batch_027_checkpoint"
const MANIFEST := "user://batch_027_manifest.json"

func _ready() -> void:
	GameManager.test_mode = true
	Batch027Checks.load_fixtures()
	if OS.get_environment("BATCH_027_RELAUNCH_PHASE") == "prepare": _prepare()
	else: _recover()

func _prepare() -> void:
	var file := FileAccess.open(SaveManager.SAVE_DIR + SLOT + ".sav", FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string("res://data/fixtures/save_v2_2024.json"))
	file.close()
	if not SaveManager.load_game(SLOT): return _fail("Base checkpoint refused")
	GameManager.campaign_elapsed_seconds = 0
	while PlayerManager.get_player_count() < 3: PlayerManager.add_player("Protection party")
	var supplier := Batch027Checks.actor("b027_saved_supplier", "fixture:027_class_plain")
	var second := Batch027Checks.actor("b027_saved_second", "fixture:027_class_renamed")
	var recipient := Batch027Checks.actor("b027_saved_recipient")
	PartyManager.reset()
	var actors: Array = [supplier, second, recipient]
	for index in actors.size():
		PlayerManager.set_player_character(index, actors[index])
		PartyManager.register_player_character(index, actors[index])
	var transferred := Batch027Checks.give(supplier, recipient)
	if not transferred.get("success", false): return _fail("Initial transfer refused: " + JSON.stringify(transferred))
	recipient.absorb_temporary_hp(2)
	AuraRules.refresh_party_context([{"character":supplier, "hex_position":Vector2i.ZERO}, {"character":second, "hex_position":Vector2i(1, 0)}, {"character":recipient, "hex_position":Vector2i(2, 0)}])
	var offers := AuraProtectionRules.offers(recipient, "entry_guard")
	if offers.size() != 2 or not AuraProtectionRules.choose(recipient, offers, str(offers.keys()[1])): return _fail("Aura selection refused")
	GameManager.campaign_elapsed_seconds = 12
	if not SaveManager.save_game(SLOT): return _fail("Allowed checkpoint refused")
	var manifest := {"pid":OS.get_process_id(), "supplier":supplier.character_id, "second":second.character_id, "recipient":recipient.character_id, "dtos":{}}
	for actor in actors: manifest.dtos[actor.character_id] = actor.to_dict()
	file = FileAccess.open(MANIFEST, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	print("BATCH 027 FRESH PREPARED: " + JSON.stringify({"pid":OS.get_process_id(), "hp":recipient.temp_hp, "grant":recipient.linked_temporary_hp, "aura_receipts":recipient.aura_entry_receipts}))
	get_tree().quit()

func _recover() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if int(manifest.pid) == OS.get_process_id() or not SaveManager.load_game(SLOT): return _fail("Distinct-process recovery refused")
	var supplier: Character = PartyManager.characters.get(str(manifest.supplier))
	var recipient: Character = PartyManager.characters.get(str(manifest.recipient))
	for id in manifest.dtos:
		var actor: Character = PartyManager.characters.get(id)
		if actor == null or _plain(actor.to_dict()) != manifest.dtos[id]: return _fail("Recovered actor state differs: " + str(id))
	if recipient.temp_hp != 6 or TemporaryHPRules.bonus(recipient, "ac_bonus") != 2 or AuraProtectionRules.bonus(recipient, "ac_bonus") != 3: return _fail("Recovered live protection differs")
	var receipts := recipient.aura_entry_receipts.duplicate(true)
	AuraRules.refresh_party_context([{"character":supplier, "hex_position":Vector2i.ZERO}, {"character":recipient, "hex_position":Vector2i(1, 0)}])
	if recipient.aura_entry_receipts != receipts: return _fail("Recovery/reentry restarted a use")
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_DIR + SLOT + ".sav"))
	var refused := 0
	for carrier in ["party", "players"]:
		for mutation in ["recipient", "supplier", "source", "serial", "deadline", "payload", "hp", "container", "aura_owner", "aura_deadline", "aura_payload", "aura_choice"]:
			var bad := base.duplicate(true)
			var dto: Dictionary = bad.party.characters[manifest.recipient] if carrier == "party" else bad.players[2].character
			match mutation:
				"recipient": dto.linked_temporary_hp.recipient_id = "other"
				"supplier": dto.linked_temporary_hp.supplier_id = "missing"
				"source": dto.linked_temporary_hp.source_instance_id = "wrong-source"
				"serial": dto.linked_temporary_hp.serial = 0
				"deadline": dto.linked_temporary_hp.expires_at_seconds = 999
				"payload": dto.linked_temporary_hp.spec.benefits.ac_bonus = 9
				"hp": dto.temp_hp = 99
				"container": dto.linked_temporary_hp = []
				"aura_owner": dto.aura_entry_receipts.values()[0].recipient_id = "other"
				"aura_deadline": dto.aura_entry_receipts.values()[0].expires_at_seconds = 999
				"aura_payload": dto.aura_entry_receipts.values()[0].effect.benefits.save_bonus = 8
				"aura_choice": dto.aura_protection_selections.entry_guard = "missing"
			var slot: String = "batch_027_invalid_%s_%s" % [carrier, mutation]
			var file := FileAccess.open(SaveManager.SAVE_DIR + slot + ".sav", FileAccess.WRITE)
			file.store_string(JSON.stringify(bad))
			file.close()
			var before: Variant = _plain(recipient.to_dict())
			if SaveManager.load_game(slot) or PartyManager.characters.get(recipient.character_id) != recipient or PartyManager.characters.get(supplier.character_id) != supplier or _plain(recipient.to_dict()) != before or int(GameManager.campaign_elapsed_seconds) != 12: return _fail("Malformed full save replaced live state: " + slot)
			refused += 1
	GameManager.campaign_elapsed_seconds = 30
	if not AuraProtectionRules.offers(recipient).is_empty(): return _fail("Recovered aura deadline restarted")
	GameManager.campaign_elapsed_seconds = 60
	recipient.take_damage(1)
	if recipient.temp_hp != 0 or not recipient.linked_temporary_hp.is_empty(): return _fail("Expired HP absorbed new damage")
	print("BATCH 027 FRESH RELAUNCH PASSED: " + JSON.stringify({"pid":OS.get_process_id(), "malformed_full_saves_refused":refused, "retained_hp":6, "original_hp_deadline":60, "original_aura_deadline":30}))
	get_tree().quit()

func _plain(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func _fail(message: String) -> void:
	push_error("[Batch027FreshRelaunchProbe] " + message)
	get_tree().quit(1)
