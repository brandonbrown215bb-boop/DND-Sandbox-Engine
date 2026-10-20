class_name Batch037Controls
extends RefCounted

static func run(h: Node) -> void:
	h._enter_test("batch_037_mode_upgrade_flow")
	h._setup_world()
	Batch037Checks.load_fixtures()
	var a: Character = PlayerManager.get_player(0).get("character")
	var prior_features := a.features.duplicate()
	var prior_uses := a.feature_uses.duplicate(true)
	var stance := Batch037Checks.STANCE
	a.features.append(Batch037Checks.catalog("1", 0))
	a.features.append(Batch037Checks.catalog("1", 1))
	a.feature_uses[stance] = a.get_feature_max_uses(stance)
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	for entry in combat.player_entities:
		entry["hex_position"] = Vector2i.ZERO if entry.character == a else Vector2i(0, 1)
	var enemy: Dictionary = combat.monster_entities[0]
	enemy["hex_position"] = Vector2i(1, 0)
	combat._update_grid_entities()
	var base_ac := a.get_ac()
	var r := FeatureModeRules.activate(a, stance, "guard")
	h._assert(r.success and int(a.feature_uses[stance]) == 1, "037 actual party member activates a declared mode and pays one parent use")
	Batch031Controls._seed_hit()
	await combat._execute_monster_attack(enemy, a.character_name, 0)
	h._assert(int(combat.last_monster_weapon_attack_result.get("target_ac", -1)) == base_ac + 2, "037 actual monster attack reads the active mode's AC grant (%d vs %d)" % [int(combat.last_monster_weapon_attack_result.get("target_ac", -1)), base_ac])
	var remaining := int(a.feature_modes[stance].remaining_seconds)
	r = FeatureModeRules.choose(a, stance, "guard")
	h._assert(not r.success and FeatureModeRules.choose(a, stance, "stride").success and a.get_ac() == base_ac and int(a.feature_uses[stance]) == 1 and int(a.feature_modes[stance].remaining_seconds) == remaining, "037 actual reselect swaps grants without restarting the parent")
	Batch031Controls._seed_hit()
	await combat._execute_monster_attack(enemy, a.character_name, 0)
	h._assert(int(combat.last_monster_weapon_attack_result.get("target_ac", -1)) == base_ac, "037 actual next attack sees the replaced mode, not the old grant")
	h._teardown_scene(combat)
	a.current_hp = a.max_hp
	FeatureModeRules.choose(a, Batch037Checks.ATTUNE, "warded")
	RestRules.complete_long_rest([a], {"allow_in_test": true, "skip_campaign_time": true})
	h._assert(not a.feature_modes[stance].active and int(a.feature_uses[stance]) == 2 and a.get_ac() == base_ac + 1, "037 actual Long Rest ends the activation, restores uses and keeps the rest mode until replaced")
	h._assert(FeatureModeRules.choose(a, Batch037Checks.ATTUNE, "swift").success and a.get_ac() == base_ac, "037 actual post-rest choice replaces the rest mode's grant")
	await _review_reload(h, a)
	a.features = prior_features
	a.feature_uses = prior_uses
	a.feature_modes.clear()
	h._exit_test()

## Review: a real SaveManager save/load mid-activation (the builder scenario never reloaded).
## A recruited fixture-class companion owns the mode as a persistent class rule.
static func _review_reload(h: Node, _a: Character) -> void:
	var stance := Batch037Checks.STANCE
	_a.feature_modes.clear() # The builder's fighter only carries appended (non-persistent) fixture rules.
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var a: Character = PartyManager.characters.get(PartyManager.companion_roster.get("b037_review", {}).get("character_id", ""), null)
	if a == null:
		a = PartyManager.create_companion("b037_review", "Stance Keeper", "human", "fixture:b037_class", {"STR": 12, "DEX": 12, "CON": 14, "INT": 10, "WIS": 16, "CHA": 10})
		var recruited := a != null and PartyManager.recruit_companion("b037_review")
		h._assert(recruited, "037 review fixture-class companion joins the party")
		if not recruited: return
	a.feature_uses[stance] = a.get_feature_max_uses(stance)
	var act := FeatureModeRules.activate(a, stance, "guard")
	var live := {"uses": int(a.feature_uses.get(stance, -1)), "serial": int(a.feature_modes.get(stance, {}).get("activation_serial", 0)), "remaining": int(a.feature_modes.get(stance, {}).get("remaining_seconds", 0)), "temp": a.temp_hp}
	var slot := "batch_037_review"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = act.success and block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "037 review real save mid-activation (act=%s block='%s')" % [str(act.get("reason", "")), block])
	if not saved: return
	var bad: Dictionary = SaveManager._read_save(slot).duplicate(true)
	var tampered := false
	if bad.has("party") and bad.party.get("characters", {}).has(a.character_id):
		bad.party.characters[a.character_id].feature_modes[stance].mode = "bogus"
		tampered = true
	var bad_file := FileAccess.open(SaveManager.SAVE_DIR + slot + "_bad.sav", FileAccess.WRITE)
	bad_file.store_string(JSON.stringify(bad))
	bad_file.close()
	h._assert(tampered and not SaveManager.load_game(slot + "_bad") and PartyManager.characters.get(a.character_id) == a and str(a.feature_modes[stance].mode) == "guard", "037 review malformed saved mode refuses before replacing the live party")
	FeatureModeRules.end(a, stance, "dismissed")
	a.feature_uses[stance] = 0
	a.temp_hp = 0
	var loaded := SaveManager.load_game(slot)
	var b: Character = PartyManager.characters.get(a.character_id, null)
	var ok: bool = loaded and b != null and b != a and bool(b.feature_modes.get(stance, {}).get("active", false)) and str(b.feature_modes[stance].mode) == "guard" and int(b.feature_uses.get(stance, -1)) == live.uses and int(b.feature_modes[stance].activation_serial) == live.serial and int(b.feature_modes[stance].remaining_seconds) == live.remaining and b.temp_hp == live.temp
	h._assert(ok, "037 review real load restores the active mode, spent use, serial, deadline and Temporary HP without refill (%s vs %s)" % [str(b.feature_modes.get(stance, {}) if b else {}), str(live)])
	if b != null:
		var ac_with := b.get_ac()
		h._assert(FeatureModeRules.choose(b, stance, "stride").success and b.get_ac() == ac_with - 2 and int(b.feature_uses[stance]) == live.uses and FeatureModeRules.activate(b, stance, "guard").reason == "already_active", "037 review loaded actor reselects without respending and swaps exactly one grant")
	SaveManager.delete_save(slot)
	SaveManager.delete_save(slot + "_bad")
