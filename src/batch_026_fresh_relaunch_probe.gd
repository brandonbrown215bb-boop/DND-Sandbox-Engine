extends Node

const SLOT := "batch_026_checkpoint"
const MANIFEST := "user://batch_026_manifest.json"

func _ready() -> void:
	GameManager.test_mode = true
	DataLoader._load_content_type("res://data/fixtures/shared_spells/spells/", "spell")
	if OS.get_environment("BATCH_026_RELAUNCH_PHASE") == "prepare": _prepare()
	else: _recover()

func _prepare() -> void:
	var seed_file := FileAccess.open(SaveManager.SAVE_DIR + SLOT + ".sav", FileAccess.WRITE)
	if seed_file == null: return _fail("Cannot stage checkpoint")
	seed_file.store_string(FileAccess.get_file_as_string("res://data/fixtures/save_v2_2024.json"))
	seed_file.close()
	if not SaveManager.load_game(SLOT): return _fail("Base checkpoint refused")
	var actor: Character = PartyManager.characters.values()[0]
	var spell := DataLoader.get_spell("fixture:026_target_turn_staged")
	var effect := SpellEffects.begin_cast(actor, spell)
	var source := str(effect["source_id"])
	SpellEffects.grant(actor, effect, "restrained")
	var dc := int(actor.spell_effects[source].get("save_dc", 0))
	SpellEffects.record_shared_repeat_save(actor, source, false, dc - 1, dc)
	if not SpellEffects.saved_state_error(actor.to_dict()).is_empty(): return _fail("Repeat-save state failed pre-save validation")
	if not SaveManager.save_game(SLOT): return _fail("Allowed checkpoint refused")
	var manifest := {"pid": OS.get_process_id(), "owner": actor.character_id, "source": source, "record": actor.spell_effects[source].duplicate(true), "conditions": actor.condition_sources.duplicate(true)}
	var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	print("BATCH 026 FRESH PREPARED: " + JSON.stringify(manifest))
	get_tree().quit()

func _recover() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if int(manifest.get("pid", 0)) == OS.get_process_id() or not SaveManager.load_game(SLOT): return _fail("Distinct-process recovery refused")
	var actor: Character = PartyManager.characters.get(str(manifest.get("owner", "")))
	var source := str(manifest.get("source", ""))
	if actor == null or not actor.spell_effects.has(source) or _plain(actor.spell_effects[source]) != manifest.get("record", {}) or _plain(actor.condition_sources) != manifest.get("conditions", {}): return _fail("Repeat-save history, exact source or stage condition changed during recovery")
	var malformed := 0
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_DIR + SLOT + ".sav"))
	for carrier in ["party", "players"]:
		for mutation in ["attempts", "recipient", "stage", "all_history", "context", "purpose"]:
			var invalid := base.duplicate(true)
			var dto: Dictionary = invalid.party.characters[source.split(":")[1]] if carrier == "party" else invalid.players[0].character
			var bad_record: Dictionary = dto.spell_effects[source]
			match mutation:
				"attempts": bad_record.repeat_save_attempts = -1
				"recipient": bad_record.recipient_id = "someone-else"
				"stage": bad_record.repeat_save_stage_index = 8
				"all_history":
					for key in bad_record.keys():
						if str(key).begins_with("repeat_save_"): bad_record.erase(key)
				"context": bad_record.erase("repeat_save_context")
				"purpose": bad_record.erase("repeat_save_purpose")
			var slot := "batch_026_invalid_%s_%s" % [mutation, carrier]
			var file := FileAccess.open(SaveManager.SAVE_DIR + slot + ".sav", FileAccess.WRITE)
			file.store_string(JSON.stringify(invalid))
			file.close()
			var before := actor.to_dict().duplicate(true)
			if SaveManager.load_game(slot) or PartyManager.characters.get(actor.character_id) != actor or actor.to_dict() != before: return _fail("Malformed full save replaced live state: " + slot)
			malformed += 1
	print("BATCH 026 FRESH RELAUNCH PASSED: " + JSON.stringify({"pid": OS.get_process_id(), "owner": actor.character_id, "attempts": actor.spell_effects[source]["repeat_save_attempts"], "dc_adjustment": actor.spell_effects[source]["repeat_save_dc_adjustment"], "malformed_full_saves_refused": malformed}))
	get_tree().quit()

func _fail(message: String) -> void:
	push_error("[Batch026FreshRelaunchProbe] " + message)
	get_tree().quit(1)

func _plain(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))
