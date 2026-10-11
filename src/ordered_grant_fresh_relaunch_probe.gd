extends Node

const SLOT := "ordered_grant_fresh_relaunch"
const MALFORMED_SLOT := "ordered_malformed_slot"
const MANIFEST_PATH := "user://ordered_grant_manifest.json"

var game_manager: Node
var data_loader: Node
var player_manager: Node
var party_manager: Node
var save_manager: Node


func _ready() -> void:
	game_manager = get_tree().get_root().get_node("GameManager")
	data_loader = get_tree().get_root().get_node("DataLoader")
	player_manager = get_tree().get_root().get_node("PlayerManager")
	party_manager = get_tree().get_root().get_node("PartyManager")
	save_manager = get_tree().get_root().get_node("SaveManager")
	game_manager.test_mode = true
	data_loader._load_content_type("res://data/fixtures/shared_spells/spells/", "spell")
	_register_fixture_spells_for_cleric()

	var phase := OS.get_environment("ORDERED_GRANT_RELAUNCH_PHASE")
	if phase == "prepare":
		_prepare()
	elif phase == "recover":
		_recover()
	else:
		_fail("unknown ordered grant relaunch phase: %s" % phase)


func _register_fixture_spells_for_cleric() -> void:
	var cleric_def: Dictionary = data_loader.classes.get("cleric", {})
	var spell_ids: Array = cleric_def.get("spell_list_ids", [])
	for spell_id in ["sandbox:save_then_attack", "sandbox:resolve"]:
		if spell_id not in spell_ids:
			spell_ids.append(spell_id)
	cleric_def["spell_list_ids"] = spell_ids
	data_loader.classes["cleric"] = cleric_def


func _find_ordered_cast_seed() -> Dictionary:
	for s in range(1, 5000):
		seed(s)
		var r1 := randi_range(1, 20)
		var r2 := randi_range(1, 20)
		var r3 := randi_range(1, 20)
		var d1 := randi_range(1, 8)
		var d2 := randi_range(1, 8)
		var best_atk := maxi(r2, r3)
		var total_dmg := d1 + d2
		if r1 <= 8 and best_atk >= 12 and best_atk < 20 and total_dmg <= 6:
			return {
				"seed": s,
				"save_d20": r1,
				"atk_d20": best_atk,
				"damage": total_dmg
			}
	return {}


func _prepare() -> void:
	save_manager.delete_save(SLOT)
	save_manager.delete_save(MALFORMED_SLOT)
	if FileAccess.file_exists(MANIFEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MANIFEST_PATH))

	var fixture_text := FileAccess.get_file_as_string("res://data/fixtures/save_v2_2024.json")
	var fixture_file := FileAccess.open(save_manager.SAVE_DIR + "%s.sav" % SLOT, FileAccess.WRITE)
	if fixture_text.is_empty() or fixture_file == null:
		_fail("could not stage repository save fixture")
		return
	fixture_file.store_string(fixture_text)
	fixture_file.close()

	if not save_manager.load_game(SLOT):
		_fail("repository save fixture did not load")
		return

	game_manager.current_state = GameManager.GameState.OVERWORLD
	game_manager.transition_context = {}
	game_manager.game_in_progress = true
	game_manager.active_dungeon_state.clear()
	game_manager.campaign_elapsed_seconds = 0

	var active_party: Array = party_manager.get_active_characters()
	if active_party.is_empty():
		_fail("repository save fixture did not restore a party")
		return
	var hero: Character = active_party[0]

	party_manager.initialize_campaign_companions(game_manager.active_campaign.get("companions", {}))
	if not party_manager.recruit_companion("aldric"):
		_fail("could not recruit companion aldric")
		return

	var aldric_char_id: String = str(party_manager.companion_roster.get("aldric", {}).get("character_id", ""))
	var aldric: Character = party_manager.characters.get(aldric_char_id)
	if aldric == null:
		_fail("aldric was not found in party characters (id: %s)" % aldric_char_id)
		return

	# Ensure legal class choices and legal spell preparation without mutating ability scores
	if "cleric_divine_order" in ClassProgression.pending_feature_choices(aldric):
		if not ClassProgression.choose_feature_option(aldric, "cleric_divine_order", "protector"):
			_fail("could not choose cleric_divine_order for aldric")
			return

	var cantrip_cap := aldric.get_spellcasting_capacity("cantrips")
	var prepared_cap := aldric.get_spellcasting_capacity("prepared_spells")
	var allowed_cantrips := aldric.get_spell_option_ids(true)
	var allowed_spells := aldric.get_spell_option_ids(false)
	var legal_selection: Array[String] = []
	for i in range(mini(cantrip_cap, allowed_cantrips.size())):
		legal_selection.append(allowed_cantrips[i])
	for req_spell in ["sandbox:save_then_attack", "sandbox:resolve"]:
		if req_spell not in allowed_spells:
			_fail("expected %s in aldric allowed_spells" % req_spell)
			return
		legal_selection.append(req_spell)
	for spell_opt in allowed_spells:
		if legal_selection.size() >= mini(cantrip_cap, allowed_cantrips.size()) + mini(prepared_cap, allowed_spells.size()):
			break
		if spell_opt not in legal_selection:
			legal_selection.append(spell_opt)

	aldric.cleric_preparation_free_change = true
	aldric.spell_choices_pending = true
	if not ClassProgression.choose_spell_selection(aldric, legal_selection):
		_fail("could not legally prepare sandbox:save_then_attack and sandbox:resolve on aldric")
		return
	if not ClassProgression.saved_choices_error(aldric.to_dict()).is_empty():
		_fail("aldric failed saved_choices_error: %s" % ClassProgression.saved_choices_error(aldric.to_dict()))
		return
	if not ClassProgression.saved_choices_error(hero.to_dict()).is_empty():
		_fail("hero failed saved_choices_error: %s" % ClassProgression.saved_choices_error(hero.to_dict()))
		return

	if int(aldric.spell_slots.get("1", 0)) != 2 or aldric.spell_cast_serial != 0:
		_fail("expected aldric to start with 2 level-1 slots and spell_cast_serial 0")
		return

	var ordered_spell: Dictionary = data_loader.get_spell("sandbox:save_then_attack")
	var resolve_spell: Dictionary = data_loader.get_spell("sandbox:resolve")
	if ordered_spell.is_empty() or resolve_spell.is_empty():
		_fail("fixture spells sandbox:save_then_attack or sandbox:resolve not found")
		return

	var det := _find_ordered_cast_seed()
	if det.is_empty():
		_fail("could not find deterministic seed for ordered cast")
		return
	seed(int(det["seed"]))

	# Direct CombatAction.resolve_spell with consume_slot = true after legal spell preparation
	var cast_res: Dictionary = CombatAction.resolve_spell(aldric, hero, ordered_spell, true, {}, [], 1, 5)
	if not bool(cast_res.get("success", false)):
		_fail("ordered spell cast did not succeed: %s" % JSON.stringify(cast_res))
		return
	var step_results: Array = cast_res.get("step_results", [])
	if step_results.size() != 2:
		_fail("expected 2 step_results from sandbox:save_then_attack, got %d" % step_results.size())
		return
	var step0_target: Dictionary = step_results[0].get("target_outcomes", [{}])[0]
	var step1_target: Dictionary = step_results[1].get("target_outcomes", [{}])[0]
	var step1_res: Dictionary = step1_target.get("result", {})
	if bool(step0_target.get("saved", true)) or not hero.has_condition("restrained"):
		_fail("step 0 did not fail save and apply restrained before step 1")
		return
	if not bool(step1_res.get("attack_advantage", false)) or not bool(step1_target.get("hit", false)):
		_fail("step 1 did not consume restrained advantage and hit on the same cast")
		return
	var expected_hp: int = 10 - int(det["damage"])
	if hero.current_hp != expected_hp:
		_fail("expected hero current_hp %d after ordered cast, got %d" % [expected_hp, hero.current_hp])
		return
	if int(aldric.spell_slots.get("1", -1)) != 1 or aldric.spell_cast_serial != 1:
		_fail("expected aldric level-1 slots == 1 and spell_cast_serial == 1 after first cast")
		return

	var ordered_source_id := "spell:%s:1" % aldric.character_id
	if not hero.spell_effects.has(ordered_source_id):
		_fail("hero missing ordered_source_id %s in spell_effects" % ordered_source_id)
		return

	# Advance production campaign clock by 24s before casting the second spell
	var tick_events_24: Array = game_manager.advance_campaign_time(24)
	if not tick_events_24.is_empty() or game_manager.campaign_elapsed_seconds != 24:
		_fail("expected 24s campaign advance with no expiry events")
		return
	if int(hero.spell_effects[ordered_source_id].get("remaining_seconds", -1)) != 36:
		_fail("expected ordered_source_id remaining_seconds == 36 after 24s")
		return
	if int(hero.condition_sources.get("restrained", {}).get(ordered_source_id, -1)) != 6:
		_fail("expected condition_sources[restrained][ordered_source_id] == 6 after 24s")
		return

	# Cast second legally prepared spell sandbox:resolve with real slot expenditure
	var resolve_res: Dictionary = CombatAction.resolve_spell(aldric, hero, resolve_spell, true, {}, [], 1, 5)
	if not bool(resolve_res.get("success", false)):
		_fail("second spell sandbox:resolve did not succeed")
		return
	var resolve_source_id := "spell:%s:2" % aldric.character_id
	aldric.concentrating_on = {
		"spell_id": "sandbox:resolve",
		"effect_source": resolve_source_id,
		"targets": [hero]
	}
	if int(aldric.spell_slots.get("1", -1)) != 0 or aldric.spell_cast_serial != 2:
		_fail("expected aldric level-1 slots == 0 and spell_cast_serial == 2 after second cast")
		return
	if not hero.spell_effects.has(resolve_source_id) or not hero.has_condition("blessed"):
		_fail("hero missing resolve_source_id %s or blessed condition" % resolve_source_id)
		return

	# Verify mid-combat / non-checkpoint save refusal
	game_manager.current_state = GameManager.GameState.COMBAT
	if save_manager.get_save_block_reason().is_empty() or save_manager.save_game(SLOT):
		_fail("mid-combat save was not refused by SaveManager")
		return
	game_manager.current_state = GameManager.GameState.OVERWORLD

	if not save_manager.get_save_block_reason().is_empty():
		_fail("Safe point was rejected: %s" % save_manager.get_save_block_reason())
		return

	save_manager.delete_save(SLOT)
	if not save_manager.save_game(SLOT):
		_fail("Ordered grant save could not be committed")
		return

	var manifest := {
		"hero_id": hero.character_id,
		"aldric_id": aldric.character_id,
		"party_slots": party_manager.party_slots.duplicate(true),
		"hero_ability_scores": hero.ability_scores.to_dict(),
		"aldric_ability_scores": aldric.ability_scores.to_dict(),
		"hero_current_hp": hero.current_hp,
		"hero_max_hp": hero.max_hp,
		"aldric_current_hp": aldric.current_hp,
		"aldric_max_hp": aldric.max_hp,
		"campaign_elapsed_seconds": game_manager.campaign_elapsed_seconds,
		"current_state": int(game_manager.current_state),
		"aldric_spell_cast_serial": aldric.spell_cast_serial,
		"aldric_spell_slots": aldric.spell_slots.duplicate(true),
		"aldric_known_spells": aldric.known_spells.duplicate(),
		"aldric_feature_choices": aldric.feature_choices.duplicate(true),
		"aldric_concentrating_on": {
			"spell_id": "sandbox:resolve",
			"effect_source": resolve_source_id,
			"target_ids": [hero.character_id]
		},
		"ordered_source_id": ordered_source_id,
		"resolve_source_id": resolve_source_id,
		"hero_spell_effects": hero.spell_effects.duplicate(true),
		"hero_condition_sources": hero.condition_sources.duplicate(true),
		"hero_conditions": hero.conditions.duplicate(true)
	}
	var manifest_file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if manifest_file == null:
		_fail("could not open manifest path for writing")
		return
	manifest_file.store_string(JSON.stringify(manifest, "\t"))
	manifest_file.close()

	print("ORDERED GRANT FRESH PREPARED: source-owned timed grants and manifest committed")
	get_tree().quit()


func _recover() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_fail("manifest file missing in recover process")
		return
	var manifest_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not (manifest_parsed is Dictionary):
		_fail("manifest JSON invalid in recover process")
		return
	var manifest: Dictionary = manifest_parsed

	# 1. Load prepared save in fresh process
	if not save_manager.load_game(SLOT):
		_fail("fresh process could not load the prepared save")
		return

	var active_party: Array = party_manager.get_active_characters()
	if active_party.size() != 2:
		_fail("expected recovered active party size 2, got %d" % active_party.size())
		return

	var hero: Character = active_party[0]
	var aldric: Character = active_party[1]
	var hero_id: String = str(manifest.get("hero_id", ""))
	var aldric_id: String = str(manifest.get("aldric_id", ""))
	var ordered_source_id: String = str(manifest.get("ordered_source_id", ""))
	var resolve_source_id: String = str(manifest.get("resolve_source_id", ""))

	# 2. Verify exact manifest parity and canonical seat/party reference identity
	if hero == null or aldric == null:
		_fail("hero or aldric null after fresh-process load")
		return
	if hero.character_id != hero_id or aldric.character_id != aldric_id:
		_fail("recovered character IDs do not match manifest")
		return
	if _normalize(party_manager.party_slots) != _normalize(manifest.get("party_slots", [])):
		_fail("recovered party_manager.party_slots does not match manifest")
		return
	if party_manager.characters.get(hero_id) != hero or party_manager.characters.get(aldric_id) != aldric:
		_fail("party_manager.characters does not hold canonical hero/aldric references")
		return
	if player_manager.get_player(0).get("character") != hero:
		_fail("player seat 0 does not point to canonical recovered hero instance")
		return
	if int(game_manager.current_state) != int(manifest.get("current_state", -1)):
		_fail("recovered current_state does not match manifest")
		return
	if game_manager.campaign_elapsed_seconds != int(manifest.get("campaign_elapsed_seconds", -1)):
		_fail("recovered campaign_elapsed_seconds (%d) != manifest (%d)" % [
			game_manager.campaign_elapsed_seconds,
			int(manifest.get("campaign_elapsed_seconds", -1))
		])
		return
	if _normalize(hero.ability_scores.to_dict()) != _normalize(manifest.get("hero_ability_scores", {})):
		_fail("recovered hero ability_scores do not match manifest")
		return
	if _normalize(aldric.ability_scores.to_dict()) != _normalize(manifest.get("aldric_ability_scores", {})):
		_fail("recovered aldric ability_scores do not match manifest")
		return
	if hero.current_hp != int(manifest.get("hero_current_hp", -1)) or hero.max_hp != int(manifest.get("hero_max_hp", -1)):
		_fail("recovered hero HP (%d/%d) does not match manifest" % [hero.current_hp, hero.max_hp])
		return
	if aldric.spell_cast_serial != int(manifest.get("aldric_spell_cast_serial", -1)):
		_fail("recovered aldric spell_cast_serial (%d) != manifest" % aldric.spell_cast_serial)
		return
	if int(aldric.spell_slots.get("1", -1)) != int(manifest.get("aldric_spell_slots", {}).get("1", -2)):
		_fail("recovered aldric level-1 spell_slots != manifest")
		return
	if _normalize(aldric.known_spells) != _normalize(manifest.get("aldric_known_spells", [])):
		_fail("recovered aldric known_spells != manifest")
		return
	if _normalize(aldric.feature_choices) != _normalize(manifest.get("aldric_feature_choices", {})):
		_fail("recovered aldric feature_choices != manifest")
		return
	if _normalize(hero.spell_effects) != _normalize(manifest.get("hero_spell_effects", {})):
		_fail("recovered hero.spell_effects != manifest")
		return
	if _normalize(hero.condition_sources) != _normalize(manifest.get("hero_condition_sources", {})):
		_fail("recovered hero.condition_sources != manifest")
		return
	if _normalize(hero.conditions) != _normalize(manifest.get("hero_conditions", {})):
		_fail("recovered hero.conditions != manifest")
		return
	if str(aldric.concentrating_on.get("spell_id", "")) != "sandbox:resolve" \
			or str(aldric.concentrating_on.get("effect_source", "")) != resolve_source_id \
			or aldric.concentrating_on.get("targets", []) != [hero]:
		_fail("recovered aldric.concentrating_on did not rebind to canonical hero target")
		return

	# 3. Verify malformed/structured-invalid save and missing spell definition refusal BEFORE session replacement
	var base_save_text := FileAccess.get_file_as_string(save_manager.SAVE_DIR + "%s.sav" % SLOT)
	if not _verify_refusal_preserves_live_session(base_save_text, hero, aldric, ordered_source_id, resolve_source_id):
		return
	print("ORDERED GRANT LOAD REFUSAL: structured-invalid and missing-definition saves refused without mutating live session")

	# 4. Advance campaign clock by 36s -> ordered_source_id (36s) expires, resolve_source_id (60s -> 24s) remains
	game_manager.advance_campaign_time(36)
	if game_manager.campaign_elapsed_seconds != 60:
		_fail("expected campaign_elapsed_seconds == 60 after +36s advance, got %d" % game_manager.campaign_elapsed_seconds)
		return
	if hero.has_condition("restrained") or hero.spell_effects.has(ordered_source_id) or hero.condition_sources.has("restrained"):
		_fail("ordered_source_id / restrained remained on hero after 36s post-load advance")
		return
	if not hero.has_condition("blessed") or not hero.spell_effects.has(resolve_source_id):
		_fail("resolve_source_id / blessed did not survive independent expiry of ordered_source_id")
		return
	if int(hero.spell_effects[resolve_source_id].get("remaining_seconds", -1)) != 24:
		_fail("expected resolve_source_id remaining_seconds == 24 after 36s post-load advance")
		return
	if int(hero.condition_sources.get("blessed", {}).get(resolve_source_id, -1)) != 4:
		_fail("expected condition_sources[blessed][resolve_source_id] == 4 after 36s post-load advance")
		return
	if str(aldric.concentrating_on.get("effect_source", "")) != resolve_source_id:
		_fail("aldric concentration did not remain bound to resolve_source_id at +36s")
		return

	# 5. Advance campaign clock by remaining 24s -> resolve_source_id expires and clears concentration
	game_manager.advance_campaign_time(24)
	if game_manager.campaign_elapsed_seconds != 84:
		_fail("expected campaign_elapsed_seconds == 84 after +24s advance, got %d" % game_manager.campaign_elapsed_seconds)
		return
	if hero.has_condition("blessed") or not hero.spell_effects.is_empty() or not hero.condition_sources.is_empty():
		_fail("hero still has active spell effects or conditions after all timed sources expired")
		return
	if not aldric.concentrating_on.is_empty():
		_fail("aldric.concentrating_on was not cleared when resolve_source_id expired")
		return

	# 6. Clean up test slots and manifest
	save_manager.delete_save(SLOT)
	save_manager.delete_save(MALFORMED_SLOT)
	if FileAccess.file_exists(MANIFEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MANIFEST_PATH))

	print("ORDERED GRANT FRESH RELAUNCH PASSED: source-owned timed grants, manifest parity, refusal, and post-load expiry survived fresh process")
	get_tree().quit()


func _verify_refusal_preserves_live_session(
	base_save_text: String,
	hero: Character,
	aldric: Character,
	ordered_source_id: String,
	resolve_source_id: String
) -> bool:
	var party_snap: Array = party_manager.party_slots.duplicate(true)
	var effects_snap: Dictionary = hero.spell_effects.duplicate(true)
	var sources_snap: Dictionary = hero.condition_sources.duplicate(true)
	var conds_snap: Dictionary = hero.conditions.duplicate(true)
	var slots_snap: Dictionary = aldric.spell_slots.duplicate(true)
	var hp_snap: int = hero.current_hp
	var clock_snap: int = game_manager.campaign_elapsed_seconds
	var state_snap: int = int(game_manager.current_state)

	var variants: Array[Dictionary] = []

	# Case 1: invalid schema version
	var c1: Dictionary = JSON.parse_string(base_save_text)
	c1["schema_version"] = 999
	variants.append(c1)

	# Case 2: invalid durable remaining_seconds type
	var c2: Dictionary = JSON.parse_string(base_save_text)
	c2["party"]["characters"][hero.character_id]["spell_effects"][ordered_source_id]["remaining_seconds"] = "forever"
	variants.append(c2)

	# Case 3: undeclared shared condition on sandbox:save_then_attack
	var c3: Dictionary = JSON.parse_string(base_save_text)
	c3["party"]["characters"][hero.character_id]["spell_effects"][ordered_source_id]["conditions"] = ["invisible"]
	c3["party"]["characters"][hero.character_id]["condition_sources"]["invisible"] = {ordered_source_id: 6}
	c3["party"]["characters"][hero.character_id]["conditions"]["invisible"] = 6
	variants.append(c3)

	# Case 4: non-existent caster_id on active spell_effects record
	var c4: Dictionary = JSON.parse_string(base_save_text)
	c4["party"]["characters"][hero.character_id]["spell_effects"][ordered_source_id]["caster_id"] = "missing_caster"
	variants.append(c4)

	for idx in range(variants.size()):
		var f := FileAccess.open(save_manager.SAVE_DIR + "%s.sav" % MALFORMED_SLOT, FileAccess.WRITE)
		if f == null:
			_fail("could not write malformed slot variant %d" % idx)
			return false
		f.store_string(JSON.stringify(variants[idx], "\t"))
		f.close()
		if save_manager.load_game(MALFORMED_SLOT):
			_fail("structured-invalid save variant %d was unexpectedly loaded" % idx)
			return false

	# Case 5: missing selected/active spell definition
	var saved_spell_def: Dictionary = data_loader.spells.get("sandbox:save_then_attack", {})
	data_loader.spells.erase("sandbox:save_then_attack")
	var missing_def_loaded: bool = save_manager.load_game(SLOT)
	data_loader.spells["sandbox:save_then_attack"] = saved_spell_def
	if missing_def_loaded:
		_fail("save referencing missing spell definition sandbox:save_then_attack was unexpectedly loaded")
		return false

	# Assert live session references and values are untouched
	if party_manager.party_slots != party_snap:
		_fail("refused load mutated party_manager.party_slots")
		return false
	if party_manager.characters.get(hero.character_id) != hero or party_manager.characters.get(aldric.character_id) != aldric:
		_fail("refused load replaced canonical character instances in party_manager.characters")
		return false
	if player_manager.get_player(0).get("character") != hero:
		_fail("refused load mutated player seat 0 character reference")
		return false
	if game_manager.campaign_elapsed_seconds != clock_snap or int(game_manager.current_state) != state_snap:
		_fail("refused load mutated campaign clock or game state")
		return false
	if hero.current_hp != hp_snap or aldric.spell_slots != slots_snap:
		_fail("refused load mutated hero HP or aldric spell_slots")
		return false
	if hero.spell_effects != effects_snap or hero.condition_sources != sources_snap or hero.conditions != conds_snap:
		_fail("refused load mutated hero active spell effects or conditions")
		return false
	if str(aldric.concentrating_on.get("effect_source", "")) != resolve_source_id \
			or aldric.concentrating_on.get("targets", []) != [hero]:
		_fail("refused load mutated aldric concentration binding")
		return false
	return true


func _normalize(v: Variant) -> Variant:
	if v is float and is_finite(v) and v == floor(v):
		return int(v)
	if v is Array:
		var out: Array = []
		for item in v:
			out.append(_normalize(item))
		return out
	if v is Dictionary:
		var out: Dictionary = {}
		for k in v:
			out[str(k)] = _normalize(v[k])
		return out
	return v


func _fail(message: String) -> void:
	push_error("[OrderedGrantFreshRelaunchProbe] " + message)
	get_tree().quit(1)
