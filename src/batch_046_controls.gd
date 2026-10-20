class_name Batch046Controls
extends RefCounted

static func _prepare(b: Character) -> Dictionary:
	var prior := {"known": b.known_spells.duplicate(), "book": b.wizard_spellbook.duplicate(), "choices": b.feature_choices.duplicate(true), "features": b.features.duplicate(true), "slots": b.spell_slots.duplicate(true)}
	var spells: Array[String] = [Batch046Checks.SNARE]
	b.known_spells.assign(spells)
	b.wizard_spellbook.assign(spells)
	b.feature_choices[b.get_spellcasting_feature_id()] = spells.duplicate()
	b.features.append({"id": "fixture:b046_permission", "effects": [{"type": "always_prepared_spells", "spells": spells.duplicate(), "ability": "INT", "maximum_spell_level": 1}]})
	return prior

static func _restore(b: Character, prior: Dictionary) -> void:
	b.known_spells.assign(prior.known)
	b.wizard_spellbook.assign(prior.book)
	b.feature_choices = prior.choices
	b.features = prior.features
	b.spell_slots = prior.slots

## Real HUD casts of the snare at a monster until its save fails (the slot is refilled each try).
static func _bind(h: Node, combat: Node, b: Character, target: Dictionary, base: int) -> String:
	for i in 12:
		seed(base + i)
		b.spell_slots = {"1": 1}
		h._p_focus(combat, b)
		combat._reset_turn_action_economy()
		await Batch036Controls.cast(h, combat, b, target, Batch046Checks.SNARE)
		if not TetherRules.held(b).is_empty(): return str(TetherRules.held(b)[0])
	return ""

static func run(h: Node) -> void:
	h._enter_test("batch_046_work_rescue_flow")
	h._setup_world()
	Batch046Checks.load_fixtures()
	var a: Character = PlayerManager.get_player(0).get("character")
	var b: Character = PlayerManager.get_player(1).get("character")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	# S-066: the HUD routes start work; the real campaign clock accrues it.
	var tome := Batch046Checks.add(a, Batch046Checks.TOME)
	var frame := Batch046Checks.add(b, Batch046Checks.FRAME)
	var started := WorkRules.start(a, tome)
	GameManager.advance_campaign_time(3600)
	h._assert(started.success and WorkRules.progress(a.inventory.get_instance(tome)) == 3600, "046 actual started study accrues on the real campaign clock")
	# Checklist (a): stowing active work refuses with the copy and its progress unchanged.
	var bag := Batch046Checks.add(a, Batch043Checks.SATCHEL)
	var before := a.inventory.get_instance(tome)
	var stow := ContainerRules.stow(a.inventory, tome)
	h._assert(not stow.get("success", false) and a.inventory.get_instance(tome) == before and not bag.is_empty(), "046 actual refused stow leaves the active work and its progress untouched")
	WorkRules.start(b, frame)
	GameManager.advance_campaign_time(600)
	var waited := WorkRules.progress(b.inventory.get_instance(frame))
	# Review 046 R1: a studying character cannot also join; the same hours never accrue twice.
	var busy := WorkRules.join(a, b, WorkRules.active_id(b))
	WorkRules.stop(a, tome)
	var joined := WorkRules.join(a, b, WorkRules.active_id(b))
	GameManager.advance_campaign_time(1200)
	h._assert(waited == 0 and not busy.success and joined.success and WorkRules.progress(b.inventory.get_instance(frame)) == 1200 and WorkRules.progress(a.inventory.get_instance(tome)) == 4200, "046 actual group work waits for its second participant, then accrues; a busy helper must stop first (review 046 R1)")
	# Back to separate works before combat: the group work resets on leaving, the study resumes.
	WorkRules.stop(b, frame)
	WorkRules.start(a, tome)
	WorkRules.start(b, frame)
	GameManager.advance_campaign_time(1200)
	# Combat interrupts both works through their own policies.
	var prior := _prepare(b)
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin", "goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	var tome_rec := a.inventory.get_instance(tome)
	var frame_rec := b.inventory.get_instance(frame)
	h._assert(not WorkRules.is_active(tome_rec) and WorkRules.progress(tome_rec) == 4200 + 1200 and not WorkRules.is_active(frame_rec) and WorkRules.progress(frame_rec) == 0, "046 actual combat interrupts work: keep keeps the study, reset loses the group work (tome=%d frame=%d)" % [WorkRules.progress(tome_rec), WorkRules.progress(frame_rec)])
	for entry in combat.player_entities:
		entry["hex_position"] = Vector2i.ZERO if entry.character == a else Vector2i(0, 1)
		entry["has_turn"] = true
	var g1: Dictionary = combat.monster_entities[0]
	var g2: Dictionary = combat.monster_entities[1]
	g1["hex_position"] = Vector2i(2, 1)
	g2["hex_position"] = Vector2i(3, 1)
	combat._update_grid_entities()
	# S-169: the goblin's ally spends its turn cutting the exact tether.
	var source := await _bind(h, combat, b, g1, 4600)
	CombatAction.apply_condition(g1, "restrained", 10, "fixture:b046_other")
	var turns := 0
	while not source.is_empty() and TetherRules.has_source(g1, source) and turns < 8:
		combat._try_monster_rescue_tether(g2)
		turns += 1
	h._assert(not source.is_empty() and turns >= 1 and not TetherRules.has_source(g1, source) and TetherRules.held(b).is_empty() and CombatAction.has_condition(g1, "restrained") and b.concentrating_on.is_empty(), "046 actual monster ally cuts only the tether (turns=%d); the other restraint stays" % turns)
	CombatAction.remove_condition_source(g1, "fixture:b046_other", ["restrained"])
	# Checklist (a): a rescue with nothing to free refuses before the Action is spent.
	h._p_focus(combat, a)
	combat._reset_turn_action_economy()
	var could: bool = combat._can_spend_action_cost("action")
	var tried: bool = combat._try_rescue_tether(a, Vector2i(0, 1), Vector2i.ZERO)
	h._assert(could and not tried and combat._can_spend_action_cost("action"), "046 actual refused rescue leaves the Action unspent")
	# Destroyed victim: only its relation (and the caster's concentration) ends.
	var s2 := await _bind(h, combat, b, g2, 4620)
	g2["is_alive"] = false
	combat._update_grid_entities()
	h._assert(not s2.is_empty() and TetherRules.held(b).is_empty() and b.concentrating_on.is_empty() and not TetherRules.has_source(g2, s2), "046 actual a destroyed victim releases its tether through the grid update")
	g2["is_alive"] = true
	# Destroyed anchor: the captor is knocked out; the real knock-out route ends concentration and frees the victim.
	var s3 := await _bind(h, combat, b, g1, 4640)
	var hp := b.current_hp
	b.current_hp = 0
	b.is_alive = false
	combat._end_concentration(b)
	h._assert(not s3.is_empty() and not TetherRules.has_source(g1, s3) and not CombatAction.has_condition(g1, "restrained") and TetherRules.held(b).is_empty(), "046 actual a knocked-out anchor releases its victim")
	b.current_hp = hp
	b.is_alive = true
	h._teardown_scene(combat)
	_restore(b, prior)
	# Persistence: restart both works and round-trip through a real save.
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	WorkRules.start(b, frame)
	WorkRules.join(a, b, frame)
	var refused_second := WorkRules.start(a, tome)
	h._assert(not refused_second.success and not WorkRules.is_active(a.inventory.get_instance(tome)), "046 RW10 a participant in group work cannot start a second work (review 046 R1)")
	GameManager.advance_campaign_time(300)
	var slot := "batch_046_work_rescue"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "046 actual real save with an active group work (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(slot)
		var na: Character = PartyManager.characters.get(a.character_id, null)
		var nb: Character = PartyManager.characters.get(b.character_id, null)
		h._assert(loaded and na != null and nb != null and na != a and not WorkRules.is_active(na.inventory.get_instance(tome)) and WorkRules.progress(na.inventory.get_instance(tome)) == 5400 and WorkRules.progress(nb.inventory.get_instance(frame)) == 300 and nb.inventory.get_instance(frame).state.work_participants == [b.character_id, a.character_id], "046 actual real load keeps exact progress and participants")
		if na != null and nb != null:
			GameManager.advance_campaign_time(600)
			h._assert(WorkRules.progress(na.inventory.get_instance(tome)) == 5400 and WorkRules.progress(nb.inventory.get_instance(frame)) == 900, "046 actual work resumes accruing after reload (tome=%d frame=%d)" % [WorkRules.progress(na.inventory.get_instance(tome)), WorkRules.progress(nb.inventory.get_instance(frame))])
			var stop := WorkRules.stop(nb, frame)
			h._assert(stop.success and WorkRules.progress(nb.inventory.get_instance(frame)) == 0 and WorkRules.progress(na.inventory.get_instance(tome)) == 5400, "046 actual leaving the group work resets only that work")
		SaveManager.delete_save(slot)
	h._exit_test()
