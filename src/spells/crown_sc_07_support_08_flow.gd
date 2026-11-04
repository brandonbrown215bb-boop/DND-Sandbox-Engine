## SC-07 support 08: Bestow Curse converted.
## New generic pieces: duration_by_slot tiers (slot-dependent duration and
## concentration, -1 = until dispelled), the until_dispelled source flag, and
## nine data-driven cursed_* markers (per-ability save/check Disadvantage,
## attack Disadvantage only against the marker's source, a source damage rider,
## and a turn-start save that forces the Dodge action).
class_name CrownSc07Support08Flow
extends RefCounted

const P := "SC-07 s8: "
const SLOT := "crown_sc_07_support_08"
const OLD_SLOT := "crown_sc_07_support_06"

static func _target(id: String, hex: Vector2i) -> Dictionary:
	var m := CrownSc01Support01Flow._monster(id, hex, 10, {"wisdom": 10, "strength": 10})
	m["saving_throw_bonuses"] = {"WIS": -1000}
	return m

static func _rec(target) -> Dictionary:
	var all := SpellEffects.records(target)
	return all.values()[0] if not all.is_empty() else {}

static func _contract_checks(h) -> void:
	var spell := DataLoader.get_spell("bestow_curse")
	var options := ["cursed_str", "cursed_dex", "cursed_con", "cursed_int", "cursed_wis", "cursed_cha", "cursed_attack_source", "cursed_dodge", "cursed_necrotic"]
	h._assert(not spell.is_empty() and SharedSpell.content_error(spell).is_empty() and spell.effects[0].get("condition_options", []) == options, P + "Bestow Curse loads through the shared contract with nine authored curse options")
	var t3 := SharedSpell.duration_tier_for_slot(spell, 3)
	var t4 := SharedSpell.duration_tier_for_slot(spell, 4)
	var t6 := SharedSpell.duration_tier_for_slot(spell, 6)
	var t8 := SharedSpell.duration_tier_for_slot(spell, 8)
	var t9 := SharedSpell.duration_tier_for_slot(spell, 9)
	h._assert(t3.is_empty() and int(t4.duration_seconds) == 600 and bool(t4.concentration) and int(t6.duration_seconds) == 28800 and not bool(t6.concentration) and int(t8.duration_seconds) == 86400 and int(t9.duration_seconds) == -1 and not bool(t9.concentration), P + "slot tiers: 3 base (Concentration 1 min), 4 = 10 min Conc, 5-6 = 8 h, 7-8 = 24 h, 9 = until dispelled; 5+ drop Concentration")
	var bad := spell.duplicate(true)
	bad.duration_by_slot[0]["min_slot"] = 3
	var bad2 := spell.duplicate(true)
	bad2.duration_by_slot[1]["concentration"] = "no"
	var bad3 := spell.duplicate(true)
	bad3.duration_by_slot[2]["duration_seconds"] = -5
	h._assert(not SharedSpell.content_error(bad).is_empty() and not SharedSpell.content_error(bad2).is_empty() and not SharedSpell.content_error(bad3).is_empty(), P + "a tier at the spell level, a non-Boolean concentration and an invalid duration are rejected")

static func _renamed_checks(h) -> void:
	var caster := ConversionBatch002Checks.actor("crown-sc07s8-renamed", "wizard", 9)
	var other := ConversionBatch002Checks.actor("crown-sc07s8-other", "fighter", 1)
	var hex := CrownSc01Support01Flow._renamed(h, "bestow_curse", "crown_sc_07_support_08:neutral_hex")
	var a := _target("crown-sc07s8-a", Vector2i(1, 0))
	var s := hex.duplicate(true); s["_chosen_condition"] = "cursed_wis"
	CombatAction.resolve_spell(caster, a, s, false, {}, [], 3, 5)
	var check_wis := EventResolver.resolve_monster_ability_check(a, "WIS", "", 10)
	var check_str := EventResolver.resolve_monster_ability_check(a, "STR", "", 10)
	h._assert(a.conditions.has("cursed_wis") and CombatAction.save_has_disadvantage(a, "WIS") and not CombatAction.save_has_disadvantage(a, "DEX") and bool(check_wis.get("disadvantage", false)) and not bool(check_str.get("disadvantage", false)), P + "renamed option 1: Disadvantage on the chosen ability's checks and saves only")
	var b := _target("crown-sc07s8-b", Vector2i(1, 1))
	s = hex.duplicate(true); s["_chosen_condition"] = "cursed_attack_source"
	CombatAction.resolve_spell(caster, b, s, false, {}, [], 3, 5)
	h._assert(CombatAction.attack_disadvantage_against(b, caster) and not CombatAction.attack_disadvantage_against(b, other) and CombatAction.attacker_has_condition_disadvantage(b, "STR", {"attack_target_id": caster.character_id}) and not CombatAction.attacker_has_condition_disadvantage(b, "STR", {"attack_target_id": other.character_id}), P + "renamed option 2: Disadvantage on attack rolls against the caster only")
	var c := _target("crown-sc07s8-c", Vector2i(0, 1))
	s = hex.duplicate(true); s["_chosen_condition"] = "cursed_necrotic"
	CombatAction.resolve_spell(caster, c, s, false, {}, [], 3, 5)
	var hp0 := int(c.current_hp)
	var mine := CombatAction.resolve_damage(c, 5, "fire", CombatAction.with_damage_origin({}, CombatAction.DAMAGE_ORIGIN_SPELL), false, false, caster)
	var riders: Array = mine.get("marker_rider_receipts", [])
	var hp1 := int(c.current_hp)
	var theirs := CombatAction.resolve_damage(c, 5, "fire", CombatAction.with_damage_origin({}, CombatAction.DAMAGE_ORIGIN_SPELL), false, false, other)
	h._assert(riders.size() == 1 and str(riders[0].get("damage_type", riders[0].get("type", ""))) == "necrotic" and hp0 - hp1 >= 6 and hp0 - hp1 <= 13 and theirs.get("marker_rider_receipts", []).is_empty() and hp1 - int(c.current_hp) == 5, P + "renamed option 4: the caster's damage adds 1d8 Necrotic once; another creature's damage does not (%s)" % str(riders))
	var d := _target("crown-sc07s8-d", Vector2i(-1, 0))
	s = hex.duplicate(true); s["_chosen_condition"] = "cursed_dodge"
	CombatAction.resolve_spell(caster, d, s, false, {}, [], 3, 5)
	var turn := CombatAction.resolve_turn_start_marker_save(d)
	var plain := CombatAction.resolve_turn_start_marker_save(a)
	h._assert(bool(turn.get("forced_dodge", false)) and str(turn.get("ability", "")) == "WIS" and not bool(plain.get("forced_dodge", false)), P + "renamed option 3: a failed turn-start WIS save forces the Dodge action; uncursed creatures roll nothing (%s)" % str(turn))
	# Slot tiers through CombatAction.resolve_spell.
	var e := _target("crown-sc07s8-e", Vector2i(-1, 1))
	s = hex.duplicate(true); s["_chosen_condition"] = "cursed_con"
	CombatAction.resolve_spell(caster, e, s, false, {}, [], 5, 5)
	var r5 := _rec(e)
	var f := _target("crown-sc07s8-f", Vector2i(0, -1))
	s = hex.duplicate(true); s["_chosen_condition"] = "cursed_cha"
	CombatAction.resolve_spell(caster, f, s, false, {}, [], 9, 5)
	var r9 := _rec(f)
	var r3 := _rec(a)
	h._assert(int(r3.get("remaining_seconds", 0)) == 60 and int(r5.get("remaining_seconds", 0)) == 28800 and not bool(r5.get("concentration", true)) and int(r9.get("remaining_seconds", 0)) == -1 and bool(r9.get("until_dispelled", false)), P + "renamed slot tiers: level 3 = 60 s, level 5 = 8 h without Concentration, level 9 = until dispelled (%s | %s)" % [str(r5), str(r9)])
	h._assert(f.conditions.has("cursed_cha"), P + "an until-dispelled curse is still in place")
	for t in [a, b, c, d, e, f]:
		for key in SpellEffects.records(t).keys(): SpellEffects.remove(t, str(key))
	h._assert(not f.conditions.has("cursed_cha") and not a.conditions.has("cursed_wis"), P + "removing the source (Remove Curse / dispel) ends the marker")
	CrownSc01Support01Flow._forget(str(hex.id))

static func _find_popup(combat) -> PopupMenu:
	for child in combat.hud.get_children():
		if child is PopupMenu and child.visible: return child
	return null

static func _level_item(menu: PopupMenu, level: int) -> int:
	for i in menu.item_count:
		if menu.get_item_text(i).begins_with("Level %d" % level): return i
	return 0

static func _cast(h, combat, wizard: Character, level_index: int, hex: Vector2i, option_text: String) -> String:
	combat.turn_budget.action_available = true
	ConversionBatch002Flow._select(h, combat, wizard, "bestow_curse", 3)
	for _frame in 60:
		var level_menu: PopupMenu = null
		for child in combat.hud.get_children():
			if child is PopupMenu and child.visible and child.item_count > 0 and child.get_item_text(0).begins_with("Level"): level_menu = child
		if level_menu != null:
			level_menu.id_pressed.emit(level_menu.get_item_id(_level_item(level_menu, level_index)))
			break
		await h.get_tree().process_frame
	await h.get_tree().process_frame
	combat._on_hex_clicked(hex)
	var seen := ""
	var handled := []
	for _frame in 600:
		var menu := _find_popup(combat)
		if menu != null and menu in handled: menu = null
		if menu != null:
			handled.append(menu)
			if menu.get_item_text(0).begins_with("Level"):
				menu.id_pressed.emit(menu.get_item_id(_level_item(menu, level_index)))
			else:
				for i in menu.item_count:
					seen += menu.get_item_text(i) + ";"
				for i in menu.item_count:
					if menu.get_item_text(i).to_lower().contains(option_text):
						menu.id_pressed.emit(menu.get_item_id(i))
						break
				break
		await h.get_tree().process_frame
	await ConversionBatch002Flow._wait_resolution(h, combat)
	return seen

static func _player_casts(h) -> void:
	var wizard := ConversionBatch002Checks.actor("crown-sc07s8-wizard", "cleric", 1)
	var learned := ConversionBatch001Flow._prepare(wizard, [])
	for _level in 8: wizard.level_up()
	learned = learned and ConversionBatch001Flow._prepare(wizard, ["bestow_curse"])
	h._assert(learned and "bestow_curse" in wizard.get_spell_option_ids(false), P + "a level-9 Cleric prepares Bestow Curse")
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	h._ready_spell_components(wizard)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	var dodger := _target("crown-sc07s8-dodger", Vector2i(1, 0))
	var bleeder := _target("crown-sc07s8-bleeder", Vector2i(0, 1))
	combat.monster_entities.clear()
	combat.monster_entities.assign([dodger, bleeder])
	for m in [dodger, bleeder]: combat.tracker.add_combatant(str(m.id), str(m.name), false, m, 5, 10)
	combat._update_grid_entities()
	wizard.spell_slots = {"1": 0, "2": 0, "3": 1, "4": 0, "5": 1}
	GameManager.test_mode = false
	var seen := await _cast(h, combat, wizard, 3, Vector2i(1, 0), "dodge")
	var r3 := _rec(dodger)
	h._assert(seen.count(";") == 9 and dodger.conditions.has("cursed_dodge") and str(wizard.concentrating_on.get("spell_id", "")) == "bestow_curse" and int(r3.get("remaining_seconds", 0)) == 60 and int(wizard.spell_slots.get("3", 1)) == 0, P + "player cast at level 3: Level popup, target click, nine-option curse menu; the Dodge curse lands with Concentration (%s | %s)" % [seen, combat.hud.log_text.text.right(500)])
	var turn: Dictionary = combat._apply_turn_start_marker_save(dodger)
	h._assert(bool(turn.get("forced_dodge", false)) and CombatAction.has_condition(dodger, "dodging") and bool(dodger.get("forced_dodge_turn", false)), P + "at the cursed creature's turn start the failed WIS save forces the Dodge action (%s)" % str(turn))
	combat.turn_budget.action_available = true
	seen = await _cast(h, combat, wizard, 5, Vector2i(0, 1), "necrotic")
	var r5 := _rec(bleeder)
	h._assert(bleeder.conditions.has("cursed_necrotic") and int(r5.get("remaining_seconds", 0)) == 28800 and not bool(r5.get("concentration", true)) and int(wizard.spell_slots.get("5", 1)) == 0 and dodger.conditions.has("cursed_dodge") and CrownSc07Support01Flow._source(dodger) == str(wizard.concentrating_on.get("effect_source", "")), P + "player upcast at level 5: 8-hour curse without Concentration; the level-3 concentration curse is untouched (%s)" % str(r5))
	var hp0 := int(bleeder.current_hp)
	var dmg := CombatAction.resolve_damage(bleeder, 3, "fire", CombatAction.with_damage_origin({}, CombatAction.DAMAGE_ORIGIN_SPELL), false, false, wizard)
	h._assert(dmg.get("marker_rider_receipts", []).size() == 1 and hp0 - int(bleeder.current_hp) >= 4, P + "the player's damage to the cursed creature adds 1d8 Necrotic")
	SpellEffects.end_concentration(wizard, [dodger, bleeder])
	wizard.concentrating_on = {}
	h._assert(not dodger.conditions.has("cursed_dodge") and bleeder.conditions.has("cursed_necrotic"), P + "ending Concentration ends only the level-3 curse")
	GameManager.test_mode = true
	h._teardown_scene(combat)

static func _checkpoint(h) -> void:
	var caster := ConversionBatch002Checks.actor("crown-sc07s8-saver", "wizard", 9)
	var ally := ConversionBatch002Checks.actor("crown-sc07s8-ally", "fighter", 1)
	PartyManager.reset()
	PlayerManager.set_player_character(0, caster)
	PlayerManager.set_player_character(1, ally)
	PartyManager.register_player_character(0, caster)
	PartyManager.register_player_character(1, ally)
	var ally2 := caster # the until-dispelled curse rides on the saving caster itself
	for a in [ally, caster]: a.ability_scores.from_dict({"STR": 16, "DEX": 10, "CON": 12, "INT": 10, "WIS": 1, "CHA": 1})
	var spell := DataLoader.get_spell("bestow_curse").duplicate(true)
	spell["_chosen_condition"] = "cursed_str"
	for _attempt in 80:
		CombatAction.resolve_spell(caster, ally2, spell.duplicate(true), false, {}, [], 9, 5)
		if ally2.conditions.has("cursed_str"): break
		for key in SpellEffects.records(ally2).keys(): SpellEffects.remove(ally2, str(key))
	spell["_chosen_condition"] = "cursed_attack_source"
	for _attempt in 80:
		CombatAction.resolve_spell(caster, ally, spell.duplicate(true), false, {}, [], 4, 5)
		if ally.conditions.has("cursed_attack_source"): break
		for key in SpellEffects.records(ally).keys(): SpellEffects.remove(ally, str(key))
	caster.concentrating_on = {"spell_id": "bestow_curse", "effect_source": CrownSc07Support01Flow._source(ally), "targets": [ally]}
	h._assert(bool(_rec(ally2).get("until_dispelled", false)) and int(_rec(ally).get("remaining_seconds", 0)) == 600, P + "the caster carries an until-dispelled curse and a party member a 10-minute Concentration curse")
	GameManager.test_mode = true
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	h._assert(SaveManager.save_game(SLOT) and SaveManager._validate_save_data(SaveManager._read_save(SLOT)).is_empty() and SaveManager.load_game(SLOT), P + "both curses save, pass preflight and reload")
	var tampered := SaveManager._read_save(SLOT)
	var tampered_ok := false
	for entry in _find_records(tampered):
		if bool(entry.get("until_dispelled", false)):
			entry["remaining_seconds"] = 30
			tampered_ok = true
	h._assert(tampered_ok and not SaveManager._validate_save_data(tampered).is_empty(), P + "preflight rejects an until_dispelled record whose remaining time is not -1")
	print("CROWN_SC_07_SUPPORT_08_CHECKPOINT_READY")

static func _find_records(node) -> Array:
	var out := []
	if node is Dictionary:
		if node.has("source_id") and node.has("spell_id"): out.append(node)
		for v in node.values(): out.append_array(_find_records(v))
	elif node is Array:
		for v in node: out.append_array(_find_records(v))
	return out

static func _recover(h) -> void:
	h._assert(SaveManager.load_game(SLOT), P + "a fresh process loads the checkpoint")
	var ally: Character = PartyManager.characters.get("crown-sc07s8-ally")
	var caster: Character = PartyManager.characters.get("crown-sc07s8-saver")
	var ally2: Character = ally
	ally = caster
	var r9 := _rec(ally) if ally != null else {}
	var r4 := _rec(ally2) if ally2 != null else {}
	h._assert(ally != null and ally.has_condition("cursed_str") and bool(r9.get("until_dispelled", false)) and int(r9.get("remaining_seconds", 0)) == -1 and CombatAction.save_has_disadvantage(ally, "STR"), P + "fresh-process recovery keeps the until-dispelled curse and its effect (%s)" % str(r9))
	h._assert(ally2 != null and ally2.has_condition("cursed_attack_source") and int(r4.get("remaining_seconds", 0)) == 600 and caster != null and str(caster.concentrating_on.get("spell_id", "")) == "bestow_curse" and CombatAction.attack_disadvantage_against(ally2, caster), P + "fresh-process recovery keeps the Concentration curse and its source-scoped attack Disadvantage (%s | %s | %s)" % [str(r4), str(ally2.conditions) if ally2 != null else "", str(caster.concentrating_on) if caster != null else "null"])
	if SaveManager._read_save(OLD_SLOT).is_empty():
		h._assert(false, P + "old support-06 checkpoint present (run crown_sc_07_support_06_flow first)")
	else:
		var old_ok := SaveManager.load_game(OLD_SLOT)
		var old_ally: Character = PartyManager.characters.get("crown-sc07s6-ally")
		h._assert(old_ok and old_ally != null and old_ally.has_condition("calmed_indifferent") and SaveManager.save_game(OLD_SLOT + "_resaved8") and SaveManager.load_game(OLD_SLOT + "_resaved8"), P + "old-.sav round trip: a pre-until_dispelled checkpoint loads, re-saves and reloads")
	print("CROWN_SC_07_SUPPORT_08_FRESH_PROCESS_PASSED")

static func run(h) -> void:
	h._enter_test("crown_sc_07_support_08_flow")
	if OS.get_environment("CROWN_SC_07_SUPPORT_08_RECOVER") == "1":
		_recover(h)
		h._exit_test()
		return
	h._setup_world()
	_contract_checks(h)
	_renamed_checks(h)
	await _player_casts(h)
	_checkpoint(h)
	h._exit_test()
