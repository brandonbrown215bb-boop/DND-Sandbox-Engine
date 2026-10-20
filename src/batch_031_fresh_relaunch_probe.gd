extends Node

const SLOT := "batch_031_damage_links"
const MANIFEST := "user://batch_031_damage_links_manifest.json"

func _ready() -> void:
	call_deferred("_recover")

func _recover() -> void:
	if OS.get_environment("B031_LINK_RELAUNCH_PHASE") != "recover":
		_fail("unexpected process phase")
		return
	var app_root := get_tree().root
	var data_loader = app_root.get_node("DataLoader")
	data_loader._load_json_file("res://data/fixtures/batch_031/spells/linked_damage.json", "spell")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not parsed is Dictionary or not app_root.get_node("SaveManager").load_game(SLOT):
		_fail("fresh process could not load the allowed Overworld checkpoint")
		return
	var manifest: Dictionary = parsed
	var characters: Dictionary = app_root.get_node("PartyManager").characters
	var target: Character = characters.get(str(manifest.get("target_id", "")))
	var caster: Character = characters.get(str(manifest.get("caster_id", "")))
	var source := str(manifest.get("source_id", ""))
	var record: Dictionary = SpellEffects.records(target).get(source, {}) if target != null else {}
	var expected_policy: Dictionary = manifest.get("policy", {})
	var concentration: Dictionary = caster.concentrating_on if caster != null else {}
	if target != null and (record.get("conditions", []) != manifest.get("conditions", []) or not target.has_condition("blessed") or not target.condition_sources.get("blessed", {}).has(source)):
		_fail("fresh process lost the link's co-owned condition or exact condition source")
		return
	if target == null or caster == null or record.is_empty() or str(record.get("source_id", "")) != source or str(record.get("recipient_id", "")) != target.character_id or str(record.get("caster_id", "")) != caster.character_id or record.get("damage_link", {}) != expected_policy or int(record.get("remaining_seconds", -1)) != int(manifest.get("remaining_seconds", -2)) or str(concentration.get("effect_source", "")) != source or not SpellEffectPersistence.saved_party_error(characters_to_dto(characters)).is_empty():
		_fail("fresh process changed exact link source, recipient, lifetime, policy or concentration ownership")
		return
	print("BATCH 031 FRESH RELAUNCH PASSED: exact linked source, recipient, caster, policy, lifetime and concentration restored")
	get_tree().quit(0)

func characters_to_dto(characters: Dictionary) -> Dictionary:
	var out := {}
	for actor_id in characters:
		out[actor_id] = characters[actor_id].to_dict()
	return out

func _fail(message: String) -> void:
	printerr("BATCH 031 FRESH RELAUNCH FAILED: %s" % message)
	get_tree().quit(1)
