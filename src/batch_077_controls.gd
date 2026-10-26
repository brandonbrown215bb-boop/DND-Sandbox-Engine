class_name Batch077Controls
extends RefCounted
## Batch 077 (#39 follow-up, S-127): live Extra Attack through the real Attack
## click and damage-type menu. A per-attack choice is asked on every swing and
## each pick applies to its own swing; an "attack_action" choice is asked once
## and carries; dismissing a later swing's menu holds that swing (logged, not a
## silent fallback to the weapon's own type) and it stays available.

static func _target(id: String, immune: Array) -> Dictionary:
	return {"id": id, "name": "Proof Dummy", "creature_type": "construct", "hex_position": Vector2i(1, 0), "is_alive": true, "current_hp": 300, "max_hp": 300, "temp_hp": 0, "armor_class": -100, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "damage_immunities": immune, "damage_resistances": [], "saving_throw_bonuses": {}, "spell_slots": {}}

static func _ready_turn(combat: Node, fighter: Character, target: Dictionary) -> void:
	combat.current_player_idx = 0
	combat.active_character = fighter
	combat.active_combatant = {"is_player": true, "entity": fighter}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.turn_budget.reset(fighter, combat.player_entities)
	combat.remaining_attack_swings = 0
	combat.attack_action_total = 0
	combat.attack_action_damage_choice = {}
	combat.monster_entities.clear()
	combat.monster_entities.append(target)
	combat._update_grid_entities()

## One real Attack click. `answers[i]` answers the i-th damage-type menu: a menu
## index, -1 to dismiss, or a Callable returning one. Returns the menus seen.
static func _click(h: Node, combat: Node, answers: Array) -> int:
	combat._on_hud_action("attack", {})
	combat.call_deferred("_on_hex_clicked", Vector2i(1, 0))
	var seen := {}
	var started := false
	var idle := 0
	for _frame in 900:
		await h.get_tree().process_frame
		for child in combat.hud.get_children():
			if child is PopupMenu and child.visible and child.item_count == 2 and not seen.has(child.get_instance_id()):
				var n := seen.size()
				seen[child.get_instance_id()] = true
				var answer = answers[n] if n < answers.size() else -1
				var index: int = answer.call() if answer is Callable else int(answer)
				if index < 0: child.hide()
				else: child.id_pressed.emit(index)
		if combat.resolving_player_action or not seen.is_empty(): started = true
		idle = idle + 1 if started and not combat.resolving_player_action else 0
		if idle > 20: break
	combat.pending_action_type = ""
	return seen.size()

static func run(h: Node) -> void:
	h._enter_test("batch_077_per_swing_choice_flow")
	h._setup_world()
	Batch077Checks.load_fixtures()
	var fighter: Character = h._fresh_char("Swing Fighter", "human", "fixture:b077_class", {"STR": 18, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	fighter.character_id = "b077_swing_fighter"
	fighter.extra_attacks = 1
	for id in ["longsword", "shortsword", "mace"]: fighter.inventory.add_item(id)
	fighter.inventory.equip(Inventory.Slot.WEAPON, "longsword")
	h._assert(RuleUpgradeRules.extra_attacks(fighter) == 1, "077 live the fighter has one Extra Attack")
	PlayerManager.set_player_character(0, fighter)
	PartyManager.reset()
	PartyManager.register_player_character(0, fighter)
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	GameManager.test_mode = false

	# 1. Per attack: swing 1 picks Radiant (target immune), swing 2 picks Force.
	var t1 := _target("b077_t1", ["slashing", "radiant"])
	_ready_turn(combat, fighter, t1)
	var hp_at_second_menu := [-1]
	seed(77001)
	var asked := await _click(h, combat, [0, func():
		hp_at_second_menu[0] = int(t1.current_hp)
		return 1])
	h._assert(asked == 2, "077 live a per-attack choice is asked on swing 1 AND swing 2 (asked %d)" % asked)
	h._assert(hp_at_second_menu[0] == 300 and int(t1.current_hp) < 300, "077 live swing 1's Radiant pick applied to swing 1 only (no damage to the radiant-immune target) and swing 2's Force pick landed (hp %d -> %d)" % [hp_at_second_menu[0], int(t1.current_hp)])
	h._assert(not combat.turn_budget.action_available and combat.remaining_attack_swings == 0, "077 live both swings spent one Attack action")

	# 2. Per Attack action: asked once on swing 1; Force carries to swing 2.
	fighter.inventory.equip(Inventory.Slot.WEAPON, "shortsword")
	var t2 := _target("b077_t2", ["piercing", "radiant"])
	_ready_turn(combat, fighter, t2)
	seed(77002)
	asked = await _click(h, combat, [1])
	var log2: String = combat.hud.log_text.text if combat.hud.log_text != null else ""
	h._assert(asked == 1 and combat.remaining_attack_swings == 0 and log2.contains("Force carries to this swing"), "077 live a per-Attack-action choice is asked once and carries to the Extra Attack (asked %d)" % asked)
	h._assert(300 - int(t2.current_hp) > 0, "077 live the carried Force damage landed on the piercing-immune target")

	# 3. Per Attack action at the hit window: one request, the pick carries.
	fighter.inventory.equip(Inventory.Slot.WEAPON, "mace")
	var t3 := _target("b077_t3", ["bludgeoning"])
	_ready_turn(combat, fighter, t3)
	seed(77003)
	asked = await _click(h, combat, [1])
	h._assert(asked == 1 and int(t3.current_hp) < 300 and combat.remaining_attack_swings == 0, "077 live a hit-window per-Attack-action pick is asked once and carries (asked %d)" % asked)

	# 4. Refusal: dismissing swing 2's menu holds the swing, logs it, never
	#    falls back to slashing; the held swing asks again on the next click.
	fighter.inventory.equip(Inventory.Slot.WEAPON, "longsword")
	var t4 := _target("b077_t4", ["radiant"])
	_ready_turn(combat, fighter, t4)
	seed(77004)
	asked = await _click(h, combat, [1, -1])
	var hp_after_held := int(t4.current_hp)
	var log4: String = combat.hud.log_text.text if combat.hud.log_text != null else ""
	h._assert(asked == 2 and combat.remaining_attack_swings == 1 and not combat.turn_budget.action_available and log4.contains("this swing is held and not spent"), "077 live dismissing swing 2's choice holds that swing (logged) instead of silently attacking with the weapon's own type")
	asked = await _click(h, combat, [1])
	h._assert(asked == 1 and combat.remaining_attack_swings == 0 and int(t4.current_hp) < hp_after_held, "077 live the held swing asks again on the next click and the new pick lands")
	GameManager.test_mode = true
	h._teardown_scene(combat)
	h._exit_test()
