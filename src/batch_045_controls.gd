class_name Batch045Controls
extends RefCounted

static func _prepare(b: Character) -> Dictionary:
	var prior := {"known": b.known_spells.duplicate(), "book": b.wizard_spellbook.duplicate(), "choices": b.feature_choices.duplicate(true), "features": b.features.duplicate(true), "slots": b.spell_slots.duplicate(true)}
	var spells: Array[String] = [Batch045Checks.LASH]
	b.known_spells.assign(spells)
	b.wizard_spellbook.assign(spells)
	b.feature_choices[b.get_spellcasting_feature_id()] = spells.duplicate()
	b.features.append({"id": "fixture:b045_permission", "effects": [{"type": "always_prepared_spells", "spells": spells.duplicate(), "ability": "INT", "maximum_spell_level": 1}]})
	return prior

static func _restore(b: Character, prior: Dictionary) -> void:
	b.known_spells.assign(prior.known)
	b.wizard_spellbook.assign(prior.book)
	b.feature_choices = prior.choices
	b.features = prior.features
	b.spell_slots = prior.slots

static func run(h: Node) -> void:
	h._enter_test("batch_045_active_tether_flow")
	h._setup_world()
	Batch045Checks.load_fixtures()
	var a: Character = PlayerManager.get_player(0).get("character")
	var b: Character = PlayerManager.get_player(1).get("character")
	var prior := _prepare(b)
	# S-064: a's ring is activated through the HUD route before the fight.
	var ring := Batch045Checks.add(a, Batch045Checks.WING)
	a.inventory.equip_instance(Inventory.Slot.RING_1, ring)
	var on := ActiveTimeRules.activate(a, ring, int(GameManager.campaign_elapsed_seconds))
	h._assert(on.success and SourceBenefitRules.total(a, "speed") == 2, "045 actual activation turns on the ring's benefit")
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	for entry in combat.player_entities:
		entry["hex_position"] = Vector2i.ZERO if entry.character == a else Vector2i(0, 1)
		entry["has_turn"] = true
	var enemy: Dictionary = combat.monster_entities[0]
	enemy["hex_position"] = Vector2i(2, 1)
	combat._update_grid_entities()
	# S-168: real HUD casts until the goblin fails its save (each try refills the slot).
	var bound := false
	for i in 12:
		seed(4510 + i)
		b.spell_slots = {"1": 1}
		h._p_focus(combat, b)
		combat._reset_turn_action_economy()
		await Batch036Controls.cast(h, combat, b, enemy, Batch045Checks.LASH)
		if not TetherRules.held(b).is_empty():
			bound = true
			break
	var source: String = TetherRules.held(b)[0] if bound else ""
	h._assert(bound and TetherRules.has_source(enemy, source) and CombatAction.has_condition(enemy, "restrained") and str(b.tethers[source].victim_id) == TetherRules.victim_id(enemy), "045 actual HUD cast tethers the goblin to the caster under its own source")
	# Checklist (a): a full capacity refuses before the slot is spent.
	b.spell_slots = {"1": 1}
	h._p_focus(combat, b)
	combat._reset_turn_action_economy()
	await Batch036Controls.cast(h, combat, b, enemy, Batch045Checks.LASH)
	h._assert(int(b.spell_slots.get("1", 0)) == 1 and TetherRules.held(b).size() == 1, "045 actual refused second tether leaves the slot unspent (slots=%s)" % str(b.spell_slots))
	CombatAction.apply_condition(enemy, "restrained", 10, "fixture:b045_other")
	var tried: bool = combat._try_monster_escape_tether(enemy)
	h._assert(tried, "045 actual monster turn spends its Action on the exact tether")
	if TetherRules.held(b).size() == 1:
		enemy["hex_position"] = Vector2i(6, 0)
	var used_before := ActiveTimeRules.used(a.inventory.get_instance(ring))
	combat._tick_active_time_and_tethers()
	h._assert(TetherRules.held(b).is_empty() and not TetherRules.has_source(enemy, source) and CombatAction.has_condition(enemy, "restrained"), "045 actual escape or range break ends only the tether; the other restraint stays")
	h._assert(ActiveTimeRules.used(a.inventory.get_instance(ring)) == used_before + 6, "045 actual combat round spends 6 seconds of active time")
	# Review 045 RT1: a captor moving out of range mid-turn breaks the tether at once (no round tick).
	enemy["hex_position"] = Vector2i(2, 1)
	CombatAction.remove_condition_source(enemy, "fixture:b045_other", ["restrained"])
	var rebound := false
	for i in 12:
		seed(4590 + i)
		b.spell_slots = {"1": 1}
		h._p_focus(combat, b)
		combat._reset_turn_action_economy()
		await Batch036Controls.cast(h, combat, b, enemy, Batch045Checks.LASH)
		if not TetherRules.held(b).is_empty():
			rebound = true
			break
	var mid_source: String = TetherRules.held(b)[0] if rebound else ""
	var tick_used := ActiveTimeRules.used(a.inventory.get_instance(ring))
	for entry in combat.player_entities:
		if entry.character == b: entry["hex_position"] = Vector2i(9, 0)
	combat._update_grid_entities()
	h._assert(rebound and TetherRules.held(b).is_empty() and not TetherRules.has_source(enemy, mid_source) and not CombatAction.has_condition(enemy, "restrained") and ActiveTimeRules.used(a.inventory.get_instance(ring)) == tick_used, "045 RT1 a mid-turn move beyond range ends the tether immediately, before any round tick")
	# Checklist (a): spent fuel refuses activation with nothing changed.
	var lamp := Batch045Checks.add(a, Batch045Checks.LAMP)
	var lrec := a.inventory.get_instance(lamp)
	lrec.state["active_used_seconds"] = 120
	a.inventory.update_instance(lrec)
	var before := a.inventory.get_instance(lamp)
	var no := ActiveTimeRules.activate(a, lamp, int(GameManager.campaign_elapsed_seconds))
	h._assert(not no.success and a.inventory.get_instance(lamp) == before, "045 actual activation of spent fuel refuses with the budget unchanged")
	h._teardown_scene(combat)
	if not b.concentrating_on.is_empty(): SpellEffects.end_concentration(b, [b])
	# Out of combat: the real resolver tethers ally a for the persistence round trip.
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var r := Batch045Checks.lash(b, a)
	var ally_source := str(r.get("tether", {}).get("source_id", ""))
	ActiveTimeRules.pause(a, ring)
	var paused_used := ActiveTimeRules.used(a.inventory.get_instance(ring))
	_restore(b, prior)
	var slot := "batch_045_active_tether"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = not ally_source.is_empty() and block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "045 actual real save with a live tether and paused active time (block='%s' source=%s)" % [block, ally_source])
	if saved:
		var loaded := SaveManager.load_game(slot)
		var na: Character = PartyManager.characters.get(a.character_id, null)
		var nb: Character = PartyManager.characters.get(b.character_id, null)
		h._assert(loaded and na != null and nb != null and na != a and TetherRules.binding(na, [nb]).size() == 1 and TetherRules.has_source(na, ally_source), "045 actual real load keeps the exact captor-victim tether")
		if na != null and nb != null:
			GameManager.advance_campaign_time(30)
			h._assert(ActiveTimeRules.used(na.inventory.get_instance(ring)) == paused_used, "045 actual paused time stays unspent across reload and campaign time")
			ActiveTimeRules.activate(na, ring, int(GameManager.campaign_elapsed_seconds))
			GameManager.advance_campaign_time(10)
			h._assert(ActiveTimeRules.used(na.inventory.get_instance(ring)) == paused_used + 10, "045 actual resumed time continues the same allowance after reload")
			var esc := {}
			for i in 40:
				seed(4560 + i)
				esc = TetherRules.escape(na, PartyManager.characters.values())
				if esc.get("success", false): break
			h._assert(esc.get("success", false) and TetherRules.held(nb).is_empty() and not TetherRules.has_source(na, ally_source), "045 actual HUD escape after reload ends exactly that tether")
		SaveManager.delete_save(slot)
	h._exit_test()
