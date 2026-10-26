class_name Batch072Controls
extends RefCounted
## Batch 072 (S-060/S-203): the last item charge is spent through the real HUD
## spell picker and target click on one of two identical ember rings. The spent
## copy loses its spell permission (not in keep_properties) but keeps its AC
## benefit; the other copy is untouched. Cancel spends nothing; the stale picker
## row for the spent copy is refused before any cost. Real save/load and the
## batch_072_last_charge_reload fresh process keep the per-copy loss.

const SLOT := "batch_072_last_charge"

static func _rows(combat: Node, c: Character, copy: String) -> Array:
	combat.hud.update_hud(c, combat.tracker)
	combat.hud._show_spell_selection()
	return combat.hud.spells_registered.filter(func(row): return row.get("id") == Batch072Checks.MEND and row.get("_spell_payment_kind", "") == "item_charges" and str(row.get("_spell_payment_source_id", "")) == copy)

static func _cast(h: Node, combat: Node, c: Character, copy: String) -> bool:
	var rows := _rows(combat, c, copy)
	if rows.is_empty(): return false
	combat.hud._on_spell_selected(combat.hud.spells_registered.find(rows[0]))
	await combat._execute_player_spell(Batch031Controls._position(combat, c))
	for _f in 30:
		await h.get_tree().process_frame
		if not combat._cast_in_progress: break
	return true

static func run(h: Node) -> void:
	h._enter_test("batch_072_last_charge_flow")
	h._setup_world()
	Batch072Checks.load_fixtures()
	var b: Character = PlayerManager.get_player(1).get("character")
	var prior := Batch044Controls._prepare(b)
	var spells: Array[String] = [Batch072Checks.MEND]
	b.known_spells.assign(spells)
	b.wizard_spellbook.assign(spells)
	b.feature_choices[b.get_spellcasting_feature_id()] = spells.duplicate()
	b.spell_slots = {"1": 1}
	var ac_before := b.get_ac()
	var ra := Batch041Checks.add_copy(b, Batch072Checks.EMBER)
	var rb := Batch041Checks.add_copy(b, Batch072Checks.EMBER)
	b.inventory.equip_instance(Inventory.Slot.RING_1, ra)
	b.inventory.equip_instance(Inventory.Slot.RING_2, rb)
	var ac_worn := b.get_ac()
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	Batch071Controls._turn(combat, b)
	var stale: Array = _rows(combat, b, ra)
	h._assert(ac_worn == ac_before + 2 and stale.size() == 1 and _rows(combat, b, rb).size() == 1, "072 actual picker offers each ember copy separately; both grant AC (%d -> %d)" % [ac_before, ac_worn])
	# Cancel spends nothing.
	combat.hud._on_spell_selected(combat.hud.spells_registered.find(stale[0]))
	combat._cancel_pending_action()
	h._assert(int(b.inventory.get_instance(ra).state.charges) == 2 and int(b.inventory.get_instance(rb).state.charges) == 2 and combat.turn_budget.action_available, "072 actual cancel spends no charge and no action")
	b.current_hp = maxi(1, b.max_hp - 6)
	var hp := b.current_hp
	var cast1 := await _cast(h, combat, b, ra)
	h._assert(cast1 and int(b.inventory.get_instance(ra).state.charges) == 1 and b.current_hp == hp + 2 and not b.inventory.get_instance(ra).state.has("degraded"), "072 actual first item cast pays one charge from copy A only")
	Batch071Controls._turn(combat, b)
	var cast2 := await _cast(h, combat, b, ra)
	var r: Dictionary = b.inventory.last_charge_receipt
	h._assert(cast2 and int(b.inventory.get_instance(ra).state.charges) == 0 and r.get("degraded", false) and r.get("lost_properties", []) == ["spell_permissions"] and int(b.inventory.get_instance(rb).state.charges) == 2, "072 actual last-charge cast degrades copy A once, by its data (%s)" % str(r))
	Batch071Controls._turn(combat, b)
	var slots_before := b.spell_slots.duplicate(true)
	h._assert(_rows(combat, b, ra).is_empty() and _rows(combat, b, rb).size() == 1 and b.get_ac() == ac_worn, "072 actual picker drops copy A's spell; copy A keeps its AC; copy B still offers")
	h._assert(CombatCommand.from_hud_for_character("cast_spell", {"spell": stale[0]}, b) == null and not SpellCastResources.commit_spell_resource(Batch021Controls._resource_context(b, stale[0], combat.hud, combat.turn_budget)) and combat.turn_budget.action_available and b.spell_slots == slots_before and int(b.inventory.get_instance(ra).state.charges) == 0, "072 actual stale row for the lost permission is refused before any cost")
	h._teardown_scene(combat)
	Batch044Controls._restore(b, prior)
	var dto := b.to_dict()
	var json_back := Character.new()
	json_back.from_dict(JSON.parse_string(JSON.stringify(dto)))
	h._assert(not Batch072Checks.offers(json_back, ra) and Batch072Checks.offers(json_back, rb) and SourceBenefitRules.total(json_back, "AC") == 2, "072 actual JSON-text DTO keeps the per-copy loss")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(SLOT)
	h._assert(saved, "072 actual real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(SLOT)
		var nb: Character = PartyManager.characters.get(b.character_id, null)
		h._assert(loaded and nb != null and nb != b and not Batch072Checks.offers(nb, ra) and Batch072Checks.offers(nb, rb) and int(nb.inventory.get_instance(rb).state.charges) == 2 and nb.get_ac() == ac_worn, "072 actual real load keeps copy A's loss and AC, copy B's charges")
		var f := FileAccess.open("user://batch_072_ids.txt", FileAccess.WRITE)
		f.store_string("%s|%s|%s|%d" % [b.character_id, ra, rb, ac_worn])
		f.close()
	h._exit_test()

static func reload(h: Node) -> void:
	h._enter_test("batch_072_last_charge_reload")
	Batch072Checks.load_fixtures()
	var p := FileAccess.get_file_as_string("user://batch_072_ids.txt").strip_edges().split("|")
	var loaded := SaveManager.load_game(SLOT)
	var nb: Character = PartyManager.characters.get(p[0], null) if p.size() == 4 else null
	h._assert(loaded and nb != null and bool(nb.inventory.get_instance(p[1]).state.get("degraded", false)) and not Batch072Checks.offers(nb, p[1]) and Batch072Checks.offers(nb, p[2]) and nb.get_ac() == int(p[3]), "072 fresh process keeps copy A's lost permission and kept AC; copy B intact")
	if nb != null:
		nb.inventory.recover_daily_charges()
		h._assert(int(nb.inventory.get_instance(p[1]).state.charges) == 0 and not Batch072Checks.offers(nb, p[1]), "072 fresh process dawn recovery does not revive copy A")
	SaveManager.delete_save(SLOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://batch_072_ids.txt"))
	h._exit_test()
