## SC-04 support 01: Chromatic Orb as shared data.
## Generic piece: shared `leap_on_matching_dice` (a hit whose damage roll repeats a face on the
## spell's damage die leaps to a new creature of the caster's choice within range of the last
## target, with a new attack and damage roll; leaps capped by slot level; each creature once).
## Reuses `damage_type_options` (S-127 choice route) and the costed-material component check.
class_name CrownSc04Support01Flow
extends RefCounted

const P := "SC-04 support 01: "

static func _terms(faces: Array, sides: int = 8) -> Dictionary:
	var kept := []
	for _f in faces: kept.append(true)
	return {"dice_terms": [{"sides": sides, "results": faces, "kept": kept}]}

static func _contract_checks(h) -> void:
	var orb := DataLoader.get_spell("chromatic_orb")
	h._assert(SharedSpell.uses(orb) and SharedSpell.content_error(orb).is_empty() and orb.damage == "3d8" and orb.damage_type_options == ["acid", "cold", "fire", "lightning", "poison", "thunder"] and int(orb.leap_on_matching_dice.range) == 6 and orb.leap_on_matching_dice.max_leaps == "slot_level", P + "Chromatic Orb is shared data (3d8, six damage types, 30-ft leap, leaps = slot level)")
	h._assert(int(orb.get("material_component_cost", 0)) == 50 and int(DataLoader.get_item(str(orb.material_component_item_id)).get("value", 0)) >= 50, P + "the 50+ GP diamond is a costed Material component")
	for bad_leap in [{"range": 0}, {"range": 6, "max_leaps": 0}, {"range": 6, "max_leaps": "caster_level"}, {"range": 6, "x": 1}, "6"]:
		var bad := orb.duplicate(true)
		bad.leap_on_matching_dice = bad_leap
		h._assert(not SharedSpell.content_error(bad).is_empty(), P + "leap_on_matching_dice %s is rejected" % str(bad_leap))
	var save_spell := orb.duplicate(true)
	save_spell.attack_type = "none"
	save_spell.save = "DEX"
	h._assert(not SharedSpell.content_error(save_spell).is_empty(), P + "a leap without a spell attack is rejected")
	h._assert(SpellCastResults.has_matching_faces(_terms([3, 5, 3]), 8) and not SpellCastResults.has_matching_faces(_terms([1, 2, 3]), 8) and not SpellCastResults.has_matching_faces(_terms([4, 4], 6), 8), P + "matching faces: two equal d8s match; distinct faces or other dice do not")
	var rerolled := {"dice_terms": [{"sides": 8, "results": [2, 5, 2], "kept": [false, true, true]}]}
	h._assert(not SpellCastResults.has_matching_faces(rerolled, 8), P + "a discarded (rerolled) die does not count toward a match")
	var caster := ConversionBatch002Checks.actor("crown-sc04s1-contract", "wizard", 5)
	h._assert(CombatAction.spell_damage_formula(caster, orb, 2) == "3d8 + 1d8", P + "a 2nd-level slot adds 1d8")
	h._assert(not caster.inventory.has_required_spell_component(orb, "wizard"), P + "without a 50 GP diamond a focus/pouch does not satisfy the Material component")

static func _renamed_checks(h) -> void:
	var spell := CrownSc01Support01Flow._renamed(h, "chromatic_orb", "crown_sc_04_support_01:neutral_spark")
	spell.damage = "2d6"
	spell.damage_type = "cold"
	spell.damage_type_options = ["cold", "fire"]
	spell.leap_on_matching_dice = {"range": 2, "max_leaps": 1}
	spell.erase("material_component_cost")
	spell.erase("material_component_item_id")
	h._assert(SharedSpell.content_error(spell).is_empty() and int(DataLoader.get_spell(str(spell.id)).get("leap_on_matching_dice", {}).get("max_leaps", 0)) == 1 and SharedSpell.damage_die_sides(spell) == 6, P + "a renamed leap spell (d6 matches, fixed 1 leap) loads and validates with no ID registration")
	var caster := ConversionBatch002Checks.actor("crown-sc04s1-renamed", "wizard", 5)
	var target := CrownSc01Support01Flow._monster("crown-sc04s1-r", Vector2i(1, 0), -100)
	var r: Dictionary = {}
	var dmg := 0
	# A natural 1 always misses; retry so the check is not flaky.
	for _try in 20:
		target.current_hp = 1000
		r = CombatAction.resolve_spell(caster, target, spell, true, {}, [], 1, 5)
		dmg = 1000 - int(target.current_hp)
		if bool(r.get("hit", false)): break
	h._assert(bool(r.get("hit", false)) and dmg >= 2 and dmg <= 24 and r.get("damage_roll", {}).get("dice_terms", []).size() >= 1, P + "renamed: CombatAction.resolve_spell hits for the authored 2d6 cold and reports its dice (%d)" % dmg)
	CrownSc01Support01Flow._forget(str(spell.id))

static func _setup_wizard(h, id: String) -> Character:
	var wizard := ConversionBatch002Checks.actor(id, "wizard", 1)
	while wizard.level < 5: wizard.level_up()
	var book: Array[String] = ["chromatic_orb"]
	for option in DataLoader.get_castable_spell_list_options(wizard.get_spell_list_ids()):
		if book.size() >= wizard.wizard_spellbook_pending: break
		if int(option.get("level", 0)) in [1, 2, 3] and str(option.id) not in book: book.append(str(option.id))
	h._assert(ClassProgression.choose_wizard_spellbook(wizard, book) and CrownSc03Support04Flow._prepare_keeping(wizard, "chromatic_orb") and "chromatic_orb" in wizard.known_spells, P + "Wizard records Chromatic Orb in its spellbook and prepares it through ordinary class selection")
	wizard.inventory.add_item("component_pouch")
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	return wizard

static func _player_orb(h) -> void:
	var wizard := _setup_wizard(h, "crown-sc04s1-wizard")
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	var a := CrownSc01Support01Flow._monster("crown-sc04s1-a", Vector2i(2, 0), -100)
	var b := CrownSc01Support01Flow._monster("crown-sc04s1-b", Vector2i(2, 5), -100)
	var c := CrownSc01Support01Flow._monster("crown-sc04s1-c", Vector2i(2, 10), -100)
	for m in [a, b, c]: m["damage_vulnerabilities"] = []
	combat.monster_entities.clear()
	combat.monster_entities.assign([a, b, c])
	combat._update_grid_entities()
	GameManager.test_mode = false
	# Without the diamond the cast is refused before payment.
	wizard.spell_slots = {"1": 4, "2": 3, "3": 2}
	combat.turn_budget.action_available = true
	ConversionBatch002Flow._select(h, combat, wizard, "chromatic_orb", 1)
	CrownSc03Support05Flow._answer_damage_type(h, combat.hud, 2)
	await combat._on_hex_clicked(a.hex_position)
	await ConversionBatch002Flow._wait_resolution(h, combat)
	h._assert(int(wizard.spell_slots["1"]) == 4 and a.current_hp == 1000, P + "without a 50 GP diamond the player cast is refused and no slot is spent")
	combat.pending_action_type = ""
	wizard.inventory.add_item("diamond_50gp")
	var fire_index: int = DataLoader.get_spell("chromatic_orb").damage_type_options.find("fire")
	var stats := {"casts": 0, "leaps_l1": 0, "leaps_l2": 0, "bad": [], "fire": true}
	for attempt in 40:
		var slot := 1 if attempt % 2 == 0 else 2
		wizard.spell_slots = {"1": 4, "2": 3, "3": 2}
		for m in [a, b, c]: m.current_hp = 1000
		combat.turn_budget.action_available = true
		var log_start: int = combat.hud.log_text.text.length()
		ConversionBatch002Flow._select(h, combat, wizard, "chromatic_orb", slot)
		combat.pending_spell_data["_test_leap_target_ids"] = ["monster:crown-sc04s1-b", "monster:crown-sc04s1-c"]
		_answer_damage_type(h, combat.hud, fire_index)
		await combat._on_hex_clicked(a.hex_position)
		await ConversionBatch002Flow._wait_resolution(h, combat)
		var log: String = combat.hud.log_text.text.substr(log_start)
		var hits := [a, b, c].map(func(m): return 1000 - int(m.current_hp))
		var leaps := log.count("Chromatic Orb leaps to")
		if int(wizard.spell_slots[str(slot)]) != (4 if slot == 1 else 3) - 1: stats.bad.append("slot %d not spent once" % slot)
		if leaps > slot: stats.bad.append("%d leaps on a level-%d slot" % [leaps, slot])
		if hits[1] > 0 and leaps < 1 or hits[2] > 0 and leaps < 2: stats.bad.append("damage without a leap %s" % str(hits))
		if hits[0] > 0 and hits[0] <= 40 and (hits[0] < 3 + slot - 1): stats.bad.append("low damage %d" % hits[0])
		if log.count("Chromatic Orb leaps to crown-sc04s1-a") > 0: stats.bad.append("the first target was targeted again")
		if hits[0] > 0 and not log.to_lower().contains("fire"): stats.fire = false
		if hits[0] > 0: stats.casts += 1
		if slot == 1: stats.leaps_l1 += leaps
		else: stats.leaps_l2 += leaps
		if stats.leaps_l2 >= 2 and stats.leaps_l1 >= 1 and attempt >= 9: break
	h._assert(stats.bad.is_empty(), P + "picker + damage-type popup + hex click: one slot per cast, leaps only after a hit, never above the slot level, never back to the first target (%s)" % str(stats.bad))
	h._assert(stats.casts > 0 and stats.fire, P + "the chosen Fire orb hits the clicked creature (%d hits)" % stats.casts)
	h._assert(stats.leaps_l1 >= 1 and stats.leaps_l2 >= 1, P + "matching d8 faces leapt through player casting on both a 1st- and 2nd-level slot (L1 %d, L2 %d)" % [stats.leaps_l1, stats.leaps_l2])
	h._assert(wizard.inventory.has_item("diamond_50gp"), P + "the diamond is not consumed")
	GameManager.test_mode = true
	h._teardown_scene(combat)

static func run(h) -> void:
	h._enter_test("crown_sc_04_support_01_flow")
	h._setup_world()
	_contract_checks(h)
	_renamed_checks(h)
	await _player_orb(h)
	h._exit_test()


## The slot-level picker can stay visible after it is answered, so answer only the popup that
## lists damage types.
static func _answer_damage_type(h, hud, index: int) -> void:
	for _frame in 120:
		for child in hud.get_children():
			if child is PopupMenu and child.visible and not child.is_queued_for_deletion() and child.item_count > 0 and child.get_item_text(0) == "Acid":
				child.id_pressed.emit(index)
				return
		await h.get_tree().process_frame
