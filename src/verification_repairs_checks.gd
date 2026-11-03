class_name VerificationRepairsChecks
extends RefCounted
## Verification repairs: vessel save validation refuses, never throws, on a
## seat character that has no character_id.

static func run(check: Callable) -> void:
	var legacy_seat := {"party": {"characters": {}}, "players": [{"player_id": 0, "character": {"character_name": "Legacy"}}]}
	check.call(VesselProjectionRules.saved_error(legacy_seat) == "", "Vessel save check accepts a legacy seat copy without character_id that owns no projections")
	var projecting_seat := {"party": {"characters": {}}, "players": [{"player_id": 0, "character": {"character_name": "Legacy", "item_projections": {"p1": {"copy": {"definition_id": "x"}, "actor": {"actor_id": "a1"}}}}}]}
	check.call(VesselProjectionRules.saved_error(projecting_seat) == "A seat character with projected items has no character_id.", "Vessel save check refuses a seat copy with projections but no character_id")
	var blank_id := {"party": {"characters": {}}, "players": [{"player_id": 0, "character": {"character_id": "", "item_projections": {"p1": {}}}}]}
	check.call(VesselProjectionRules.saved_error(blank_id) != "", "Vessel save check refuses an empty character_id on a projecting seat copy")
	var identified := {"party": {"characters": {}}, "players": [{"player_id": 0, "character": {"character_id": "hero"}}]}
	check.call(VesselProjectionRules.saved_error(identified) == "", "Vessel save check still accepts an identified seat copy with no projections")
	var malformed := {"party": {"characters": {}}, "players": ["not a seat", {"player_id": 1, "character": null}]}
	check.call(VesselProjectionRules.saved_error(malformed) == "", "Vessel save check skips malformed seat rows instead of throwing")
	_canonical_party_knowledge(check)


static func _canonical_party_knowledge(check: Callable) -> void:
	var actor := Character.new()
	actor.initialize("Knowledge keeper", "human", "fighter", AbilityScores.new())
	var party := {"party_slots": [], "characters": {actor.character_id: actor.to_dict()}, "companion_roster": {}}
	check.call(SaveManager._validate_party_data(party).is_empty(), "Canonical party accepts a valid character before knowledge mutations")
	var saved: Dictionary = party.characters[actor.character_id]
	saved.known_languages = {"ForgedLanguage": true}
	check.call(SaveManager._validate_party_data(party) == "Known languages must be an array of at most 64 entries.", "Canonical party refuses dictionary language knowledge before restore")
	saved.known_languages = ["Common", "Common"]
	check.call(SaveManager._validate_party_data(party) == "Known language entries must be unique, nonempty strings.", "Canonical party refuses duplicate language knowledge")
	saved.known_languages = ["Common"]
	saved.known_recollections = []
	check.call(SaveManager._validate_party_data(party) == "Saved recollection knowledge is malformed.", "Canonical party refuses malformed recollection knowledge before restore")
	saved.known_recollections = {"room": ["memory", "memory"]}
	check.call(SaveManager._validate_party_data(party) == "Saved recollection IDs must be unique nonempty strings.", "Canonical party refuses duplicate recollection knowledge")
	saved.known_recollections = {"room": ["memory"]}
	check.call(SaveManager._validate_party_data(party).is_empty(), "Canonical party preserves valid language and recollection knowledge")
	saved.erase("known_languages")
	saved.erase("known_recollections")
	check.call(SaveManager._validate_party_data(party).is_empty(), "Canonical party keeps legacy characters without knowledge fields valid")
