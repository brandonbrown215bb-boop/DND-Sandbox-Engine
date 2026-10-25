class_name Batch067Controls
extends RefCounted
## Batch 067 (S-127): live combat weapon damage-type choices through the real
## Attack click and damage-type menu. Cancelling or a stale choice spends
## nothing; a chosen type changes only that attack; a hit-window choice is
## asked after the hit and before damage. The class-owned rule survives a real
## save/load; batch_067_weapon_damage_choice_reload rechecks it in a fresh process.

const SLOT := "batch_067_weapon_choice"

static func _target(id: String) -> Dictionary:
	return {"id": id, "name": "Slash-proof Dummy", "creature_type": "construct", "hex_position": Vector2i(1, 0), "is_alive": true, "current_hp": 300, "max_hp": 300, "temp_hp": 0, "armor_class": -100, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "damage_immunities": ["slashing"], "damage_resistances": [], "saving_throw_bonuses": {}, "spell_slots": {}}

static func _ready_turn(combat: Node, fighter: Character, target: Dictionary) -> void:
	combat.current_player_idx = 0
	combat.active_character = fighter
	combat.active_combatant = {"is_player": true, "entity": fighter}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(fighter, combat.player_entities)
	combat.remaining_attack_swings = 0
	combat.monster_entities.clear()
	combat.monster_entities.append(target)
	combat._update_grid_entities()

## Click Attack on the target; `answer` is the menu index, -1 to dismiss, or a
## Callable run while the menu is open (for stale cases) returning the index.
static func _attack(h: Node, combat: Node, answer) -> bool:
	combat._on_hud_action("attack", {})
	combat.call_deferred("_on_hex_clicked", Vector2i(1, 0))
	var asked := false
	for _frame in 180:
		for child in combat.hud.get_children():
			if child is PopupMenu and child.visible and child.item_count == 2 and not asked:
				asked = true
				var index: int = answer.call() if answer is Callable else int(answer)
				if index < 0: child.hide()
				else: child.id_pressed.emit(index)
		if asked: break
		await h.get_tree().process_frame
	for _frame in 180:
		await h.get_tree().process_frame
		if not combat.resolving_player_action: break
	combat.pending_action_type = ""
	return asked

static func run(h: Node) -> void:
	h._enter_test("batch_067_weapon_damage_choice_flow")
	h._setup_world()
	Batch067Checks.load_fixtures()
	var fighter: Character = h._fresh_char("Edge Fighter", "human", "fixture:b067_class", {"STR": 18, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	fighter.character_id = "b067_edge_fighter"
	fighter.inventory.add_item("longsword")
	fighter.inventory.equip(Inventory.Slot.WEAPON, "longsword")
	h._assert(fighter.features.any(func(f): return str(f.get("source_instance_id", "")) == "b067:declared"), "067 live the fixture class grants its authored attack profiles")
	PlayerManager.set_player_character(0, fighter)
	PartyManager.reset()
	PartyManager.register_player_character(0, fighter)
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	var target := _target("b067_live_dummy")
	_ready_turn(combat, fighter, target)
	GameManager.test_mode = false
	# Cancel: dismissing the activation menu spends nothing.
	var asked := await _attack(h, combat, -1)
	h._assert(asked and combat.turn_budget.action_available and int(target.current_hp) == 300, "067 live dismissing the activation choice spends no action and deals nothing")
	# Stale: the source leaves while the menu is open.
	var kept: Array[Dictionary] = fighter.features.duplicate(true)
	asked = await _attack(h, combat, func():
		fighter.features = fighter.features.filter(func(f): return str(f.get("source_instance_id", "")) != "b067:declared")
		return 1)
	h._assert(asked and combat.turn_budget.action_available and int(target.current_hp) == 300, "067 live a choice whose source left while the menu was open is refused before any cost")
	fighter.features = kept
	# Choose force: the attack spends the action once and deals force damage.
	seed(67067)
	asked = await _attack(h, combat, 1)
	var hp_after := int(target.current_hp)
	h._assert(asked and not combat.turn_budget.action_available and hp_after < 300, "067 live choosing Force spends one action and the slash-immune target takes the chosen type")
	asked = await _attack(h, combat, 0)
	h._assert(not asked and int(target.current_hp) == hp_after, "067 live with no action left the choice is not offered and nothing is spent")
	# Hit window: handaxe asks after the hit and before damage.
	fighter.inventory.add_item("handaxe")
	fighter.inventory.equip(Inventory.Slot.WEAPON, "handaxe")
	var target2 := _target("b067_live_dummy_2")
	_ready_turn(combat, fighter, target2)
	seed(67068)
	asked = await _attack(h, combat, 1)
	h._assert(asked and not combat.turn_budget.action_available and int(target2.current_hp) < 300, "067 live a hit-window choice is asked after the hit and the chosen Lightning damage lands")
	var target3 := _target("b067_live_dummy_3")
	_ready_turn(combat, fighter, target3)
	seed(67069)
	asked = await _attack(h, combat, -1)
	h._assert(asked and not combat.turn_budget.action_available and int(target3.current_hp) == 300, "067 live dismissing the hit-window choice keeps the weapon's own (immune) type; the attack still spends its action once")
	GameManager.test_mode = true
	h._teardown_scene(combat)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(SLOT)
	h._assert(saved, "067 live real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(SLOT)
		var nc: Character = PartyManager.characters.get(fighter.character_id, null)
		var choice := AttackProfileRules.damage_type_choice(nc, DataLoader.get_item("longsword")) if nc != null else {}
		h._assert(loaded and choice.get("options", []) == ["radiant", "force"] and str(DataLoader.get_item("longsword").get("damage_type")) == "slashing", "067 live real load rebuilds the class-owned choice; no per-attack choice is saved")
		var text := FileAccess.get_file_as_string(SaveManager.SAVE_DIR + SLOT + ".sav")
		h._assert(not text.contains(AttackProfileRules.DECISION_KEY) and not text.contains("attack_profile_choice_request"), "067 live the save carries no pending or chosen damage type")
	h._exit_test()

## Fresh process: reload the slot written by the flow scenario, then delete it.
static func reload(h: Node) -> void:
	h._enter_test("batch_067_weapon_damage_choice_reload")
	Batch067Checks.load_fixtures()
	var loaded := SaveManager.load_game(SLOT)
	var nc: Character = PartyManager.characters.get("b067_edge_fighter", null)
	var choice := AttackProfileRules.damage_type_choice(nc, DataLoader.get_item("longsword")) if nc != null else {}
	h._assert(loaded and nc != null and choice.get("window", "") == "activation" and choice.get("options", []) == ["radiant", "force"], "067 fresh process the saved fighter still offers its authored choice")
	SaveManager.delete_save(SLOT)
	h._exit_test()
