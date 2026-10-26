class_name CastLifetimeFlow
extends RefCounted

const SLOT := "cast_lifetime"
const PLAYER_SLOT := "cast_lifetime_players"
const OWNER := "lifetime_live_caster"
const ALLY := "lifetime_live_ally"

static func _source(actor: Character, spell_id: String) -> String:
	for source in actor.spell_effects:
		if str(actor.spell_effects[source].get("spell_id", "")) == spell_id: return str(source)
	return ""

static func _turn(combat: Node, caster: Character) -> void:
	combat.current_player_idx = 0
	combat.active_character = caster
	combat.active_combatant = {"is_player": true, "entity": caster}
	combat.turn_budget.reset(caster, combat.player_entities)
	combat.remaining_attack_swings = 0
	caster.feature_uses.erase("sorcerer_levelled_spell_cast_this_turn")
	combat._update_grid_entities()

static func _cast(h: Node, combat: Node, caster: Character, id: String, target: Vector2i) -> void:
	_turn(combat, caster)
	await h._cast_menu_spell(combat, id, 1)
	await combat._on_hex_clicked(target)
	for _frame in 120:
		await h.get_tree().process_frame
		if not combat.resolving_player_action: break

static func run(h: Node) -> void:
	h._enter_test("cast_lifetime_flow")
	h._setup_world()
	CastLifetimeChecks.load_fixtures()
	var caster: Character = h._fresh_char("Lifetime Wizard", "human", "wizard", {"STR": 10, "DEX": 12, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	caster.character_id = OWNER
	caster.spell_slots["1"] = 4
	var ally := Batch031Checks._character(ALLY)
	PlayerManager.set_player_character(0, caster)
	PlayerManager.set_player_character(1, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, caster)
	PartyManager.register_player_character(1, ally)
	var catalog := DataLoader.get_spell(CastLifetimeChecks.FREE).duplicate(true)
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	caster.features.append_array(CastLifetimeChecks.features())
	h._assert(CastLifetimeChecks.features().size() == 5 and DataLoader.get_load_errors().is_empty(), "S-141 all fixture permissions/profiles load without errors: %s" % str(DataLoader.get_load_errors()))
	if CastLifetimeChecks.features().size() != 5 or not DataLoader.get_load_errors().is_empty():
		h._teardown_scene(combat)
		h._exit_test()
		return
	combat.player_entities[0].hex_position = Vector2i.ZERO
	combat.player_entities[1].hex_position = Vector2i(1, 0)
	combat.monster_entities[0].hex_position = Vector2i(6, 0)
	GameManager.test_mode = true
	_turn(combat, caster)
	await h._cast_menu_spell(combat, CastLifetimeChecks.FREE, 1)
	h._assert(combat.pending_spell_data.get("duration_seconds") == 120 and not combat.pending_spell_data.get("concentration", true), "S-141 real HUD selection captures the extended nonconcentration invocation")
	await combat._on_hud_action("cancel", {})
	await combat._on_hex_clicked(Vector2i(1, 0))
	h._assert(int(caster.spell_slots["1"]) == 4 and combat.turn_budget.action_available and ally.spell_effects.is_empty(), "S-141 cancellation and a stale target click create nothing and spend nothing")
	await _cast(h, combat, caster, CastLifetimeChecks.FOCUS, Vector2i(1, 0))
	var old_focus := str(caster.concentrating_on.get("effect_source", ""))
	h._assert(not old_focus.is_empty() and int(ally.spell_effects.get(old_focus, {}).get("remaining_seconds", 0)) == 18 and caster.concentrating_on.get("targets", []) == [ally], "S-141 added concentration captures the shorter source and exact recipient")
	_turn(combat, caster)
	await h._cast_menu_spell(combat, CastLifetimeChecks.FREE, 1)
	var owned_features := caster.features.duplicate(true)
	caster.features = caster.features.filter(func(f): return str(f.get("source_instance_id", "")) != "lifetime:unbound")
	await combat._on_hex_clicked(Vector2i(1, 0))
	h._assert(int(caster.spell_slots["1"]) == 3 and combat.turn_budget.action_available and ally.spell_effects.size() == 1 and ally.spell_effects.has(old_focus) and str(caster.concentrating_on.get("effect_source", "")) == old_focus, "S-141 stale lifetime ownership preserves resources, the existing concentration and its exact grant")
	caster.features.assign(owned_features)
	await combat._on_hud_action("cancel", {})
	await _cast(h, combat, caster, CastLifetimeChecks.FREE, Vector2i(1, 0))
	var free_source := _source(ally, CastLifetimeChecks.FREE)
	await combat._on_hex_clicked(Vector2i(1, 0))
	h._assert(not free_source.is_empty() and int(ally.spell_effects.get(free_source, {}).get("remaining_seconds", 0)) == 120 and not ally.spell_effects.get(free_source, {}).get("concentration", true) and str(caster.concentrating_on.get("effect_source", "")) == old_focus and int(caster.spell_slots["1"]) == 2 and not combat.turn_budget.action_available, "S-141 removing concentration from this invocation preserves the older concentration and pays once despite a duplicate click")
	await _cast(h, combat, caster, CastLifetimeChecks.PLAIN, Vector2i.ZERO)
	h._assert(str(caster.concentrating_on.get("effect_source", "")) == old_focus and int(caster.spell_effects.get(_source(caster, CastLifetimeChecks.PLAIN), {}).get("remaining_seconds", 0)) == 60, "S-141 unrelated cast keeps its catalog lifetime and the existing concentration")
	await _cast(h, combat, caster, CastLifetimeChecks.FOCUS, Vector2i.ZERO)
	var focus_source := str(caster.concentrating_on.get("effect_source", ""))
	SpellEffects.reconcile([caster, ally], [caster, ally])
	h._assert(not focus_source.is_empty() and focus_source != old_focus and not ally.spell_effects.has(old_focus) and caster.spell_effects.has(focus_source) and ally.spell_effects.has(free_source) and int(caster.spell_slots["1"]) == 0, "S-141 replacing concentration removes only the old exact source and pays the new cast once")
	if not caster.spell_effects.has(focus_source) or not ally.spell_effects.has(free_source):
		h._teardown_scene(combat)
		h._exit_test()
		return
	ally.add_condition("blessed", 100, "lifetime:independent")
	SpellEffects.tick_boundary([caster, ally], caster.character_id, "start")
	h._assert(int(caster.spell_effects[focus_source].remaining_seconds) == 12 and int(ally.spell_effects[free_source].remaining_seconds) == 114, "S-141 combat boundaries age captured durations rather than catalog durations")
	h._assert(DataLoader.get_spell(CastLifetimeChecks.FREE) == catalog and int(caster.spell_cast_serial) == 4, "S-141 real casting never mutates the catalog or replays canceled invocations")
	h._teardown_scene(combat)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	h._assert(SaveManager.get_save_block_reason().is_empty() and SaveManager.save_game(SLOT), "S-141 active captured lifetimes save at the supported overworld checkpoint")
	var dto := SaveManager._read_save(SLOT)
	var player_only := dto.duplicate(true)
	player_only.erase("party")
	h._assert(SaveManager._validate_save_data(dto).is_empty() and SaveManager._validate_save_data(player_only).is_empty(), "S-141 full-party and player-only DTOs pass production preflight")
	var file := FileAccess.open(SaveManager.SAVE_DIR + PLAYER_SLOT + ".sav", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(player_only, "\t"))
		file.close()
	h._assert(file != null, "S-141 player-only checkpoint is available for fresh-process recovery")
	for defect in ["duration", "concentration"]:
		for players_only in [false, true]:
			var bad := (player_only if players_only else dto).duplicate(true)
			var owner_dto: Dictionary = bad.players[0].character if players_only else bad.party.characters[OWNER]
			if defect == "duration": owner_dto.spell_effects[focus_source].remaining_seconds = 0
			else: owner_dto.spell_effects[focus_source].concentration = "true"
			h._assert(not SaveManager._validate_save_data(bad).is_empty() and PartyManager.characters.get(OWNER) == caster, "S-141 malformed %s refuses on %s preflight without replacing the session" % [defect, "players" if players_only else "party"])
	h._exit_test()

static func run_reload(h: Node) -> void:
	h._enter_test("cast_lifetime_reload")
	CastLifetimeChecks.load_fixtures()
	for players_only in [false, true]:
		var slot := PLAYER_SLOT if players_only else SLOT
		h._assert(SaveManager.load_game(slot), "S-141 fresh process loads the %s checkpoint" % slot)
		var caster: Character = PlayerManager.get_player(0).get("character")
		var ally: Character = PlayerManager.get_player(1).get("character")
		if caster == null or ally == null:
			h._assert(false, "S-141 both exact character identities recover")
			continue
		var focused := str(caster.concentrating_on.get("effect_source", ""))
		var unbound := _source(ally, CastLifetimeChecks.FREE)
		h._assert(not focused.is_empty() and not unbound.is_empty() and int(caster.spell_effects.get(focused, {}).get("remaining_seconds", 0)) == 12 and int(ally.spell_effects.get(unbound, {}).get("remaining_seconds", 0)) == 114 and not ally.spell_effects.get(unbound, {}).get("concentration", true) and int(caster.spell_cast_serial) == 4 and int(caster.spell_slots["1"]) == 0, "S-141 recovery keeps exact sources, elapsed durations and payments without recasting")
		h._assert(AttackProfileRules.rules(caster, "spell").is_empty() and caster.concentrating_on.get("targets", []).is_empty(), "S-141 captured effects recover without the modifying feature or caster self-reference")
		GameManager.advance_campaign_time(11)
		h._assert(caster.spell_effects.has(focused) and ally.spell_effects.has(unbound), "S-141 recovered effects remain until their own exact deadline")
		if not players_only: SpellEffects.end_concentration(caster, [caster, ally])
		GameManager.advance_campaign_time(1)
		h._assert(caster.concentrating_on.is_empty() and not caster.spell_effects.has(focused) and caster.has_condition("blessed") and ally.spell_effects.has(unbound), "S-141 recovered concentration ends explicitly or at captured expiry while unrelated grants survive")
		GameManager.advance_campaign_time(101)
		h._assert(ally.spell_effects.has(unbound) and int(ally.spell_effects[unbound].remaining_seconds) == 1, "S-141 extended nonconcentration survives its catalog duration through the final second")
		GameManager.advance_campaign_time(1)
		h._assert(not ally.spell_effects.has(unbound) and ally.has_condition("blessed") and ally.condition_sources.get("blessed", {}).has("lifetime:independent") and int(caster.spell_cast_serial) == 4 and int(caster.spell_slots["1"]) == 0, "S-141 final expiry removes only its exact source without replay or resource changes")
	h._exit_test()
