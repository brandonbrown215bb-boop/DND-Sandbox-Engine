class_name Batch058Controls
extends RefCounted
## Batch 058 scenario: a real HUD cast creates Skeletons and/or Zombies in one cast.

static func _created(b: Character) -> Array:
	return CreatedActorRules.actors(b).filter(func(a): return str(a.get_meta("created_spell_id", "")) == Batch058Checks.BONES)

static func _texts(menu: PopupMenu) -> Array:
	var out: Array = []
	if menu != null:
		for i in menu.item_count: out.append(menu.get_item_text(i))
	return out

## The real HUD cast at a 4th-level slot (Batch047Controls.begin answers Level 1).
static func begin(h: Node, combat: Node, caster: Character) -> void:
	h._p_focus(combat, caster)
	combat.hud._show_spell_selection()
	for index in combat.hud.spells_registered.size():
		if combat.hud.spells_registered[index].get("id") == Batch058Checks.BONES:
			combat.hud._on_spell_selected(index)
			break
	await Batch027Controls.answer(h, combat, "", "Level 4")
	combat._on_hex_clicked(Batch031Controls._position(combat, caster))

static func run(h: Node) -> void:
	h._enter_test("batch_058_summon_lists_flow")
	h._setup_world()
	Batch058Checks.load_fixtures()
	var a: Character = PlayerManager.get_player(0).get("character")
	var b: Character = PlayerManager.get_player(1).get("character")
	var prior := {"known": b.known_spells.duplicate(), "book": b.wizard_spellbook.duplicate(), "choices": b.feature_choices.duplicate(true), "features": b.features.duplicate(true)}
	var spells: Array[String] = [Batch058Checks.BONES]
	b.known_spells.assign(spells)
	b.wizard_spellbook.assign(spells)
	b.feature_choices[b.get_spellcasting_feature_id()] = spells.duplicate()
	b.features.append({"id": "fixture:b058_permission", "effects": [{"type": "always_prepared_spells", "spells": spells.duplicate(), "ability": "INT", "maximum_spell_level": 4}]})
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	for entry in combat.player_entities:
		entry["hex_position"] = Vector2i.ZERO if entry.character == a else Vector2i(0, 3)
		entry["has_turn"] = true
	combat.monster_entities[0]["hex_position"] = Vector2i(6, 6)
	combat._update_grid_entities()
	# 1. Cancel at the Zombie count spends nothing and creates nothing.
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_effects.clear()
	b.spell_slots = {"4": 2}
	await begin(h, combat, b)
	var first := await Batch053Controls._popup(h, combat, "How many Skeleton")
	var offered := _texts(first)
	await Batch054Controls._pick(h, first, "1")
	await Batch054Controls._pick(h, await Batch053Controls._popup(h, combat, "How many Zombie"), "Cancel")
	await Batch047Controls.settle(h, combat)
	h._assert(offered == ["Cancel", "0", "1", "2", "3"] and b.spell_slots.get("4", 0) == 2 and _created(b).is_empty(), "058 actual a 4th-level cast offers 0-3 Skeletons; Cancel at Zombies leaves the slot unspent (%s)" % str(offered))
	# 2. One Skeleton and two Zombies from one cast; the slot is paid once.
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_slots = {"4": 2}
	await begin(h, combat, b)
	await Batch054Controls._pick(h, await Batch053Controls._popup(h, combat, "How many Skeleton"), "1")
	var zmenu := await Batch053Controls._popup(h, combat, "How many Zombie")
	var zoffered := _texts(zmenu)
	await Batch054Controls._pick(h, zmenu, "2")
	await Batch047Controls.settle(h, combat)
	var names: Array = _created(b).map(func(x): return x.character_name)
	h._assert(zoffered == ["Cancel", "0", "1", "2"] and b.spell_slots.get("4", 0) == 1 and names == ["Skeleton 1", "Zombie 2", "Zombie 3"] and Batch053Controls._no_overlap(combat), "058 actual one cast creates a Skeleton and two Zombies and pays one slot (%s, zombies offered %s)" % [str(names), str(zoffered)])
	# 3. Real save/load rebuilds each kind.
	h._teardown_scene(combat)
	b.known_spells.assign(prior.known)
	b.wizard_spellbook.assign(prior.book)
	b.feature_choices = prior.choices
	b.features = prior.features
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var slot := "batch_058_summon_lists"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "058 actual real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(slot)
		var nb: Character = PartyManager.characters.get(b.character_id, null)
		var back: Array = [] if nb == null else _created(nb).map(func(x): return "%s/%d" % [x.character_name, x.base_ac])
		h._assert(loaded and back == ["Skeleton 1/14", "Zombie 2/8", "Zombie 3/8"] and not JSON.stringify(nb.to_dict()).contains("_factory"), "058 actual real load rebuilds each kind (%s)" % str(back))
		SaveManager.delete_save(slot)
	h._exit_test()
