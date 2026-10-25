class_name Batch070Controls
extends RefCounted
## Batch 070 (S-084/S-085): switching the Extra Attack count through the real
## HUD rule control mid-action keeps spent swings spent; cancel and stale
## answers change nothing; removal and a real save/load restore the values;
## batch_070_attack_ac_upgrades_reload rechecks them in a fresh process.

const SLOT := "batch_070_attack_ac"
const IDS := "user://batch_070_ids.txt"

static func _target(id: String, hp: int, at: Vector2i) -> Dictionary:
	return {"id": id, "name": "Drill Dummy", "creature_type": "construct", "hex_position": at, "is_alive": true, "current_hp": hp, "max_hp": hp, "temp_hp": 0, "armor_class": -100, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "damage_immunities": [], "damage_resistances": [], "saving_throw_bonuses": {}, "spell_slots": {}}

static func _settle(h: Node, combat: Node) -> void:
	for _frame in 180:
		await h.get_tree().process_frame
		if not combat.resolving_player_action: break
	combat.pending_action_type = ""

## Open the real rule popup and answer with the item whose text contains
## `pick` ("" = Cancel). `before` runs while the popup is open.
static func _choose(h: Node, combat: Node, fighter: Character, feature_id: String, pick: String, before: Callable = Callable()) -> bool:
	var row := ModeControls.row(fighter, feature_id)
	combat.hud.request_mode_control(fighter, {"feature_id": feature_id, "kind": "alternative", "token": row.token})
	for _frame in 120:
		for child in combat.hud.get_children():
			if child is PopupMenu and child.visible and child.item_count > 1:
				if before.is_valid(): before.call()
				var index := 0
				for i in child.item_count:
					if not pick.is_empty() and child.get_item_text(i).contains(pick): index = i
				child.id_pressed.emit(child.get_item_id(index))
				for _f in 5: await h.get_tree().process_frame
				return true
		await h.get_tree().process_frame
	return false

static func run(h: Node) -> void:
	h._enter_test("batch_070_attack_ac_upgrades_flow")
	h._setup_world()
	Batch070Checks.load_fixtures()
	var fighter: Character = h._fresh_char("Drill Fighter", "human", Batch070Checks.CLASS, {"STR": 18, "DEX": 14, "CON": 16, "INT": 10, "WIS": 12, "CHA": 10})
	fighter.character_id = "b070_drill_fighter"
	fighter.inventory.add_item("longsword")
	fighter.inventory.equip(Inventory.Slot.WEAPON, "longsword")
	var id := Batch070Checks.wear(fighter)
	h._assert(RuleUpgradeRules.extra_attacks(fighter) == 2 and fighter.get_ac() == 15, "070 live attuned bracers: 2 extra attacks and AC 15")
	PlayerManager.set_player_character(0, fighter)
	PartyManager.reset()
	PartyManager.register_player_character(0, fighter)
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	var weak := _target("b070_weak", 1, Vector2i(1, 0))
	var next := _target("b070_next", 300, Vector2i(0, 1))
	Batch067Controls._ready_turn(combat, fighter, weak)
	combat.monster_entities.append(next)
	combat._update_grid_entities()
	GameManager.test_mode = false
	seed(70070)
	combat._on_hud_action("attack", {})
	combat.call_deferred("_on_hex_clicked", Vector2i(1, 0))
	await _settle(h, combat)
	var left := int(combat.remaining_attack_swings)
	h._assert(not weak.is_alive or int(weak.current_hp) <= 0, "070 live the first swing drops the 1-HP target")
	h._assert(not combat.turn_budget.action_available and left == 2 and combat.attack_action_total == 3, "070 live one Attack action of 3 swings, 2 left (%d/%d)" % [left, combat.attack_action_total])
	var shown := await _choose(h, combat, fighter, Batch070Checks.EXTRA, "")
	h._assert(shown and combat.remaining_attack_swings == 2 and fighter.rule_alternatives.get(Batch070Checks.EXTRA + "|drill", "drill_a@" + id) == "drill_a@" + id, "070 live Cancel on the rule popup changes nothing")
	shown = await _choose(h, combat, fighter, Batch070Checks.EXTRA, "drill_b")
	h._assert(shown and RuleUpgradeRules.extra_attacks(fighter) == 1 and combat.remaining_attack_swings == 1, "070 live switching to Steady Drill mid-action leaves 1 of 2 swings (1 spent stays spent)")
	shown = await _choose(h, combat, fighter, Batch070Checks.EXTRA, "drill_a")
	h._assert(shown and RuleUpgradeRules.extra_attacks(fighter) == 2 and combat.remaining_attack_swings == 1 and not combat.turn_budget.action_available, "070 live switching back does not refund a swing or supply a fresh action")
	shown = await _choose(h, combat, fighter, Batch070Checks.EXTRA, "drill_b", func(): ModeControls.apply(fighter, Batch070Checks.EXTRA, "alternative", "drill|drill_b@" + id, str(ModeControls.row(fighter, Batch070Checks.EXTRA).token)))
	h._assert(shown and combat.remaining_attack_swings == 1, "070 live a popup answer after the option changed underneath is stale and changes nothing (%d)" % combat.remaining_attack_swings)
	shown = await _choose(h, combat, fighter, Batch070Checks.GUARD, "guard_b")
	h._assert(shown and fighter.get_ac() == 15 and fighter.rule_alternatives.get(Batch070Checks.GUARD + "|base_ac", "") == "guard_b@" + id, "070 live choosing Sturdy Frame: AC 10 + DEX + CON = 15")
	combat.monster_entities.erase(weak)
	next.hex_position = Vector2i(1, 0)
	combat._update_grid_entities()
	combat._on_hud_action("attack", {})
	combat.call_deferred("_on_hex_clicked", Vector2i(1, 0))
	await _settle(h, combat)
	h._assert(combat.remaining_attack_swings == 0 and not combat.turn_budget.action_available, "070 live the remaining swing is used on a new target with no new action")
	combat._on_hud_action("attack", {})
	combat.call_deferred("_on_hex_clicked", Vector2i(1, 0))
	var hp := int(next.current_hp)
	await _settle(h, combat)
	h._assert(int(next.current_hp) == hp, "070 live with no action or swing left, Attack is refused before any roll")
	GameManager.test_mode = true
	h._teardown_scene(combat)
	fighter.inventory.unequip(Inventory.Slot.HEAD)
	h._assert(RuleUpgradeRules.extra_attacks(fighter) == 1 and fighter.get_ac() == 13 and fighter.rule_alternatives.is_empty(), "070 live removing the bracers restores 1 extra attack and AC 13")
	fighter.inventory.equip_instance(Inventory.Slot.HEAD, id)
	h._assert(fighter.get_ac() == 15 and fighter.rule_alternatives.get(Batch070Checks.GUARD + "|base_ac", "") == "guard_b@" + id, "070 live re-wearing restores the remembered Sturdy Frame")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(SLOT)
	h._assert(saved, "070 live real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(SLOT)
		var nc: Character = PartyManager.characters.get(fighter.character_id, null)
		h._assert(loaded and nc != null and RuleUpgradeRules.extra_attacks(nc) == 1 and nc.get_ac() == 15, "070 live real load keeps Steady Drill and Sturdy Frame")
		var f := FileAccess.open(IDS, FileAccess.WRITE)
		f.store_string(id)
		f.close()
	h._exit_test()

static func reload(h: Node) -> void:
	h._enter_test("batch_070_attack_ac_upgrades_reload")
	Batch070Checks.load_fixtures()
	var id := FileAccess.get_file_as_string(IDS).strip_edges()
	var loaded := SaveManager.load_game(SLOT)
	var nc: Character = PartyManager.characters.get("b070_drill_fighter", null)
	h._assert(loaded and nc != null and not id.is_empty() and RuleUpgradeRules.extra_attacks(nc) == 1 and nc.get_ac() == 15 and nc.rule_alternatives.get(Batch070Checks.GUARD + "|base_ac", "") == "guard_b@" + id, "070 fresh process the saved choices rebuild once")
	if nc != null:
		nc.inventory.unequip(Inventory.Slot.HEAD)
		h._assert(RuleUpgradeRules.extra_attacks(nc) == 1 and nc.get_ac() == 13, "070 fresh process removal still restores the base values")
	SaveManager.delete_save(SLOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IDS))
	h._exit_test()
