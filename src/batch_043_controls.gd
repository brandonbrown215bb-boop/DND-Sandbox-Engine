class_name Batch043Controls
extends RefCounted

static func _cast(h: Node, combat: Node, caster: Character, spell_id: String, level_text: String) -> void:
	h._p_focus(combat, caster)
	combat.hud._show_spell_selection()
	for index in combat.hud.spells_registered.size():
		if combat.hud.spells_registered[index].get("id") == spell_id:
			combat.hud._on_spell_selected(index)
			break
	await Batch027Controls.answer(h, combat, "", level_text)
	combat._on_hex_clicked(Batch031Controls._position(combat, caster))
	for _frame in 300:
		await h.get_tree().process_frame
		if not combat._cast_in_progress and combat.pending_action_type.is_empty(): break
	h._assert(not combat._cast_in_progress, "043 cast finishes through its production continuation")

static func _combat(h: Node, a: Character) -> Node:
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
	combat.monster_entities[0]["hex_position"] = Vector2i(3, 0)
	combat._update_grid_entities()
	return combat

static func _prepare(b: Character, slots: Dictionary) -> void:
	var spells: Array[String] = ["remove_curse"]
	b.known_spells.assign(spells)
	b.wizard_spellbook.assign(spells)
	b.feature_choices[b.get_spellcasting_feature_id()] = spells.duplicate()
	b.features.append({"id": "fixture:b043_permission", "effects": [{"type": "always_prepared_spells", "spells": spells.duplicate(), "ability": "INT", "maximum_spell_level": 4}]})
	b.spell_slots = slots.duplicate()

static func run(h: Node) -> void:
	h._enter_test("batch_043_container_curse_flow")
	h._setup_world()
	Batch043Checks.load_fixtures()
	var a: Character = PlayerManager.get_player(0).get("character")
	var b: Character = PlayerManager.get_player(1).get("character")
	var prior := {"known": b.known_spells.duplicate(), "book": b.wizard_spellbook.duplicate(), "choices": b.feature_choices.duplicate(true), "features": b.features.duplicate(true), "slots": b.spell_slots.duplicate(true)}
	# S-202: b carries one cursed copy it may unequip and loses another whose curse lingers.
	var kept := Batch043Checks.add(b, Batch043Checks.HEX)
	var lost := Batch043Checks.add(b, Batch043Checks.HEX)
	for id in [kept, lost]:
		b.inventory.attune_instance(id, b.character_id)
	b.inventory.equip_instance(Inventory.Slot.WEAPON, kept)
	var off := b.inventory.unequip(Inventory.Slot.WEAPON)
	b.inventory.equip_instance(Inventory.Slot.WEAPON, lost)
	var dropped := b.inventory.drop_equipped_instance(Inventory.Slot.WEAPON)
	h._assert(off == Batch043Checks.HEX and CurseRules.is_cursed(b.inventory.get_instance(kept)) and not dropped.is_empty() and b.item_curses.has(lost), "043 actual unequip keeps the copy's curse and dropping the other leaves its lingering curse")
	_prepare(b, {"3": 1, "4": 1})
	var combat: Node = await _combat(h, a)
	await _cast(h, combat, b, "remove_curse", "Level 3")
	h._assert(int(b.spell_slots.get("3", 1)) == 0 and CurseRules.is_cursed(b.inventory.get_instance(kept)) and b.item_curses.has(lost), "043 actual 3rd-level Remove Curse is spent but breaks neither declared curse (slots=%s)" % str(b.spell_slots))
	# A later turn: the 4th-level casting meets the exact requirement.
	for entry in combat.player_entities: entry["has_turn"] = true
	h._p_focus(combat, b)
	combat._reset_turn_action_economy()
	await _cast(h, combat, b, "remove_curse", "Level 4")
	h._assert(int(b.spell_slots.get("4", 1)) == 0 and not CurseRules.is_cursed(b.inventory.get_instance(kept)) and b.item_curses.is_empty(), "043 actual 4th-level Remove Curse breaks exactly the declared curses (slots=%s)" % str(b.spell_slots))
	h._teardown_scene(combat)
	b.known_spells.assign(prior.known)
	b.wizard_spellbook.assign(prior.book)
	b.feature_choices = prior.choices
	b.features = prior.features
	b.spell_slots = prior.slots
	# A third copy is attuned and lost, so a lingering curse goes through the real save.
	var third := Batch043Checks.add(b, Batch043Checks.HEX)
	b.inventory.attune_instance(third, b.character_id)
	b.inventory.attune_instance(kept, b.character_id)
	b.inventory.equip_instance(Inventory.Slot.WEAPON, third)
	b.inventory.drop_equipped_instance(Inventory.Slot.WEAPON)
	# S-196: a stows exact copies through the HUD route.
	var bag := Batch043Checks.add(a, Batch043Checks.SATCHEL)
	var flask := Batch043Checks.add(a, Batch043Checks.FLASK)
	var brick := Batch043Checks.add(a, Batch043Checks.BRICK)
	var s1 := ContainerRules.stow(a.inventory, flask)
	var s2 := ContainerRules.stow(a.inventory, brick)
	h._assert(s1.success and s2.success and ContainerRules.contents(a.inventory, bag).size() == 2 and not Batch043Checks.owns(a, flask) and not Batch043Checks.owns(a, brick), "043 actual HUD stow moves both exact copies into the satchel")
	# Real SaveManager round trip with contents and curses live.
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var slot := "batch_043_containers"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "043 actual real save with contents and curses (block='%s')" % block)
	if saved:
		h.get_tree().current_scene = null # Review: keep the harness alive; the real load swaps the current scene.
		var loaded := SaveManager.load_game(slot)
		var na: Character = PartyManager.characters.get(a.character_id, null)
		var nb: Character = PartyManager.characters.get(b.character_id, null)
		h._assert(loaded and na != null and na != a and ContainerRules.contents(na.inventory, bag).map(func(c): return str(c.instance_id)) == [flask, brick], "043 actual real load keeps the exact contents in place")
		var ring := Batch043Checks.add(nb, Batch043Checks.WARD) if nb != null else ""
		h._assert(nb != null and nb != b and nb.item_curses.has(third) and nb.item_curses.size() == 1 and CurseRules.is_cursed(nb.inventory.get_instance(kept)) and not nb.inventory.attune_instance(ring, nb.character_id).success, "043 actual real load keeps the re-attuned copy's curse and the lingering attunement block")
		if na != null:
			var out := ContainerRules.retrieve_last(na.inventory, bag)
			h._assert(out.success and str(out.instance_id) == brick and Batch043Checks.owns(na, brick) and na.inventory.count_item(Batch043Checks.BRICK) == 1, "043 actual take-out after reload returns the exact last copy once")
		# Review weak spot 4: the real post-load path (load -> overworld scene -> combat transition) must reach a player turn.
		await _post_load_combat(h, na)
		SaveManager.delete_save(slot)
	h._exit_test()

## Review: drive the production combat transition after a real load (no harness scene spawn).
static func _post_load_combat(h: Node, loaded_a: Character) -> void:
	var tree := h.get_tree()
	for _frame in 300:
		if tree.current_scene != null: break
		await tree.process_frame
	var overworld := tree.current_scene
	print("[review043] after load current_scene=%s" % (overworld.name if overworld != null else "null"))
	GameManager.change_state(GameManager.GameState.COMBAT, {"terrain": "plains", "monster_ids": ["goblin"]})
	var reached := false
	var scene_name := ""
	for _frame in 900:
		await tree.process_frame
		var cur := tree.current_scene
		if cur != null and cur != overworld and "active_combatant" in cur:
			scene_name = cur.name
			if cur.active_combatant.get("is_player", false):
				reached = cur.player_entities.any(func(e): return e.character == loaded_a)
				break
	print("[review043] combat scene=%s reached=%s" % [scene_name, reached])
	h._assert(reached, "043 review real post-load combat transition reaches a player turn with the loaded party (scene=%s)" % scene_name)
