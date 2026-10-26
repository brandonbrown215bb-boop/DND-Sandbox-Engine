class_name Batch087Controls
extends RefCounted
## Batch 087 (S-127 continuation): the authored damage-type choice on the
## attack routes outside the Attack action's own swings, driven through the
## real hosts and the real damage-type menu (GameManager.test_mode off):
## Light/off-hand (Bonus Action, and Nick inside the Attack action), Cleave
## (once per turn), Opportunity Attack (Reaction) and a created creature's own
## turn attack (its action). Each route asks before its budget is spent; a
## dismissed or stale answer makes no attack and spends nothing; only Nick
## carries an "attack_action" pick from the Attack action.

const FIXTURE := "res://data/fixtures/batch_087/attack_profiles.json"

static func rules() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))

static func rule(id: String) -> Dictionary:
	for r in rules():
		if str(r.id) == id: return r.duplicate(true)
	return {}

static func _target(id: String, hex: Vector2i, immune: Array) -> Dictionary:
	return {"id": id, "name": "Proof Dummy %s" % id, "creature_type": "construct", "hex_position": hex, "is_alive": true, "current_hp": 300, "max_hp": 300, "temp_hp": 0, "armor_class": -100, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "damage_immunities": immune, "damage_resistances": [], "saving_throw_bonuses": {}, "spell_slots": {}, "reaction_available": true}

static func _ready_turn(combat: Node, actor: Character, targets: Array) -> void:
	combat.current_player_idx = 0
	combat.active_character = actor
	combat.active_combatant = {"is_player": true, "entity": actor}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	combat.player_entities[0]["reaction_available"] = true
	actor.reaction_available = true
	actor.feature_uses.erase("fighter_light_used")
	actor.feature_uses.erase("fighter_cleave_used")
	combat.turn_budget.reset(actor, combat.player_entities)
	combat.remaining_attack_swings = 0
	combat.attack_action_total = 0
	combat.attack_action_damage_choice = {}
	combat.light_attack_weapon = {}
	combat.monster_entities.clear()
	for t in targets: combat.monster_entities.append(t)
	combat._update_grid_entities()

## Run `work` while answering the real popups: every reaction/optional-attack
## ConfirmationDialog is accepted; the i-th damage-type PopupMenu is answered
## with answers[i] (index, -1 = dismiss, or a Callable returning one).
## Returns the number of damage-type menus seen.
static func _drive(h: Node, combat: Node, work: Callable, answers: Array) -> int:
	var done := [false]
	var runner := func():
		await work.call()
		done[0] = true
	runner.call()
	var seen := {}
	for _frame in 1200:
		await h.get_tree().process_frame
		for child in combat.hud.get_children():
			if child is ConfirmationDialog and child.visible and not seen.has(child.get_instance_id()):
				seen[child.get_instance_id()] = "confirm"
				child.confirmed.emit()
			elif child is PopupMenu and child.visible and child.item_count == 2 and not seen.has(child.get_instance_id()):
				var n := seen.values().count("menu")
				seen[child.get_instance_id()] = "menu"
				var answer = answers[n] if n < answers.size() else -1
				var index: int = answer.call() if answer is Callable else int(answer)
				if index < 0: child.hide()
				else: child.id_pressed.emit(index)
		if done[0]: break
	h._assert(done[0], "087 driven host finished (menus %d)" % seen.values().count("menu"))
	combat.pending_action_type = ""
	return seen.values().count("menu")

static func _attack(combat: Node, hex: Vector2i) -> Callable:
	return func():
		combat._on_hud_action("attack", {})
		await combat._on_hex_clicked(hex)

static func _log(combat: Node) -> String:
	return combat.hud.log_text.text if combat.hud.log_text != null else ""

static func run(h: Node) -> void:
	h._enter_test("batch_087_choice_routes_flow")
	h._setup_world()
	var actor: Character = h._fresh_char("Route Barbarian", "human", "barbarian", {"STR": 18, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	actor.character_id = "b087_route_barbarian"
	for r in rules():
		if str(r.id) != "fixture:b087_zombie_slam": actor.features.append(r)
	h._assert(rules().all(func(r): return AttackProfileRules.validate_rule(r).is_empty()), "087 every authored route rule validates")
	for id in ["shortsword", "handaxe", "dagger", "greataxe", "longsword", "mace"]: actor.inventory.add_item(id)
	actor.inventory.unequip(Inventory.Slot.SHIELD)
	h._assert(FighterRules.choose_mastery(actor, "dagger") and FighterRules.choose_mastery(actor, "greataxe"), "087 the barbarian trains Nick (dagger) and Cleave (greataxe) through normal mastery")
	PlayerManager.set_player_character(0, actor)
	PartyManager.reset()
	PartyManager.register_player_character(0, actor)
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	GameManager.test_mode = false

	# --- Light / off-hand as a Bonus Action (handaxe: Vex, not Nick) ---
	actor.inventory.equip(Inventory.Slot.WEAPON, "shortsword")
	actor.inventory.equip(Inventory.Slot.OFFHAND, "handaxe")
	var l1 := _target("b087_l1", Vector2i(1, 0), ["slashing", "radiant"])
	_ready_turn(combat, actor, [l1])
	seed(87001)
	var hp_main := [-1]
	var bonus_at_menu := [false]
	var asked := await _drive(h, combat, _attack(combat, Vector2i(1, 0)), [func():
		hp_main[0] = int(l1.current_hp)
		bonus_at_menu[0] = combat.turn_budget.bonus_action_available
		return 1])
	h._assert(asked == 1 and bonus_at_menu[0], "087 Light: the off-hand choice is asked through the real menu BEFORE the Bonus Action is spent (asked %d)" % asked)
	h._assert(int(l1.current_hp) < hp_main[0] and not combat.turn_budget.bonus_action_available and actor.feature_uses.get("fighter_light_used", false), "087 Light: the Force pick lands on the slashing-immune target and the Bonus Action is spent once (hp %d -> %d)" % [hp_main[0], int(l1.current_hp)])

	var l2 := _target("b087_l2", Vector2i(1, 0), ["slashing"])
	_ready_turn(combat, actor, [l2])
	seed(87002)
	var hp_before_light := [-1]
	asked = await _drive(h, combat, _attack(combat, Vector2i(1, 0)), [func():
		hp_before_light[0] = int(l2.current_hp)
		return -1])
	h._assert(asked == 1 and int(l2.current_hp) == hp_before_light[0] and combat.turn_budget.bonus_action_available and not actor.feature_uses.get("fighter_light_used", false) and _log(combat).contains("the Light attack is not made and nothing was spent"), "087 Light: dismissing the menu makes no attack, keeps the Bonus Action and the once-per-turn use, and is logged (never the weapon's own type)")

	var l3 := _target("b087_l3", Vector2i(1, 0), [])
	_ready_turn(combat, actor, [l3])
	seed(87003)
	var hp_l3 := [-1]
	asked = await _drive(h, combat, _attack(combat, Vector2i(1, 0)), [func():
		hp_l3[0] = int(l3.current_hp)
		l3.hex_position = Vector2i(6, 0)
		return 0])
	h._assert(asked == 1 and int(l3.current_hp) == hp_l3[0] and combat.turn_budget.bonus_action_available and _log(combat).contains("no longer within the weapon's reach"), "087 Light: a target that leaves reach while the menu is open is rechecked; nothing is spent")

	# --- Nick: part of the Attack action, so an attack_action pick carries ---
	actor.inventory.equip(Inventory.Slot.WEAPON, "dagger")
	actor.inventory.add_item("dagger")
	actor.inventory.equip(Inventory.Slot.OFFHAND, "dagger")
	var n1 := _target("b087_n1", Vector2i(1, 0), ["piercing", "radiant"])
	_ready_turn(combat, actor, [n1])
	seed(87004)
	asked = await _drive(h, combat, _attack(combat, Vector2i(1, 0)), [0])
	h._assert(asked == 1 and _log(combat).contains("Force carries to this Light attack") and actor.feature_uses.get("fighter_light_used", false) and combat.turn_budget.bonus_action_available, "087 Nick: the Attack action's attack_action Force pick carries to the Nick attack without a second menu and without a Bonus Action (asked %d)" % asked)
	h._assert(300 - int(n1.current_hp) > 0, "087 Nick: carried Force damage lands on the piercing/radiant-immune target")

	# --- Cleave: its own extra attack; an attack_action pick does NOT carry ---
	actor.inventory.unequip(Inventory.Slot.OFFHAND)
	actor.inventory.equip(Inventory.Slot.WEAPON, "greataxe")
	var c1 := _target("b087_c1", Vector2i(1, 0), ["slashing"])
	var c2 := _target("b087_c2", Vector2i(1, -1), ["slashing", "force"])
	_ready_turn(combat, actor, [c1, c2])
	seed(87015)
	var cleave_unused_at_menu := [false]
	asked = await _drive(h, combat, _attack(combat, Vector2i(1, 0)), [0, func():
		cleave_unused_at_menu[0] = not actor.feature_uses.get("fighter_cleave_used", false)
		return 1])
	h._assert(asked == 2 and cleave_unused_at_menu[0], "087 Cleave: an attack_action Force pick does not carry; Cleave asks its own menu before its once-per-turn use is spent (asked %d, c1 %d)" % [asked, int(c1.current_hp)])
	h._assert(int(c1.current_hp) < 300 and int(c2.current_hp) < 300 and actor.feature_uses.get("fighter_cleave_used", false), "087 Cleave: the Radiant pick lands on the slashing/force-immune second creature and Cleave is used once")

	var c3 := _target("b087_c3", Vector2i(1, 0), ["slashing"])
	var c4 := _target("b087_c4", Vector2i(1, -1), ["slashing"])
	_ready_turn(combat, actor, [c3, c4])
	seed(87006)
	asked = await _drive(h, combat, _attack(combat, Vector2i(1, 0)), [0, -1])
	h._assert(asked == 2 and int(c4.current_hp) == 300 and not actor.feature_uses.get("fighter_cleave_used", false) and _log(combat).contains("the Cleave attack is not made and nothing was spent"), "087 Cleave: dismissing the Cleave menu makes no attack and keeps Cleave's once-per-turn use")

	# --- Opportunity Attack: the Reaction is spent only once the choice is made ---
	actor.inventory.equip(Inventory.Slot.WEAPON, "longsword")
	var o1 := _target("b087_o1", Vector2i(1, 0), ["slashing"])
	_ready_turn(combat, actor, [o1])
	combat.current_player_idx = -1
	combat.active_character = null
	seed(87007)
	var reaction_at_menu := [false]
	asked = await _drive(h, combat, func(): await combat._check_opportunity_attacks_for_path(null, o1, [Vector2i(1, 0), Vector2i(2, 0)], true), [func():
		reaction_at_menu[0] = actor.reaction_available
		return 1])
	h._assert(asked == 1 and reaction_at_menu[0] and not actor.reaction_available and int(o1.current_hp) < 300, "087 OA: the choice is asked before the Reaction is spent; the Force pick lands on the slashing-immune mover (hp %d)" % int(o1.current_hp))

	var o2 := _target("b087_o2", Vector2i(1, 0), ["slashing"])
	_ready_turn(combat, actor, [o2])
	combat.current_player_idx = -1
	combat.active_character = null
	seed(87008)
	asked = await _drive(h, combat, func(): await combat._check_opportunity_attacks_for_path(null, o2, [Vector2i(1, 0), Vector2i(2, 0)], true), [-1])
	h._assert(asked == 1 and actor.reaction_available and combat.player_entities[0].get("reaction_available", false) and int(o2.current_hp) == 300 and o2.hex_position == Vector2i(2, 0) and _log(combat).contains("the Opportunity Attack is not made and nothing was spent"), "087 OA: dismissing makes no attack, keeps the Reaction, logs it, and the mover continues")

	actor.inventory.equip(Inventory.Slot.WEAPON, "mace")
	var o3 := _target("b087_o3", Vector2i(1, 0), ["bludgeoning"])
	_ready_turn(combat, actor, [o3])
	combat.current_player_idx = -1
	combat.active_character = null
	seed(87009)
	asked = await _drive(h, combat, func(): await combat._check_opportunity_attacks_for_path(null, o3, [Vector2i(1, 0), Vector2i(2, 0)], true), [1])
	h._assert(asked == 1 and int(o3.current_hp) < 300 and not actor.reaction_available, "087 OA: a hit-window rule asks after the hit on the reaction route and the Lightning pick lands on the bludgeoning-immune mover")

	# --- Created creature: its own turn attack, answered by its controller ---
	var zombie_data: Dictionary = DataLoader.monsters.get("zombie", {})
	var original_abilities: Array = zombie_data.get("special_abilities", []).duplicate(true)
	zombie_data["special_abilities"] = original_abilities + [rule("fixture:b087_zombie_slam")]
	DataLoader.monsters["zombie"] = zombie_data
	var record := {"id": "created:b087", "serial": 87, "owner_id": actor.character_id, "source_spell": "animate_dead", "body_id": "b087", "form_id": "zombie", "current_hp": 15, "max_hp": 15, "created_at": 0, "control_started_at": 0, "control_until": int(GameManager.campaign_elapsed_seconds) + 86400, "existence_until": -1, "dungeon_id": "", "room_id": "", "position": [0, 2], "following": false, "order": "attack", "order_target": "b087_z1"}
	GameManager.created_creatures.append(record)
	var zombie := CreatedCreatureRules.character(record)
	var unit := {"name": zombie.character_name, "display_name": zombie.character_name, "character": zombie, "combat_id": zombie.character_id, "owner_player_index": 0, "hex_position": Vector2i(0, 2), "is_created_creature": true, "reaction_available": true}
	h._assert(not AttackProfileRules.damage_type_choice(zombie, CreatedCreatureRules.attack_profile(record)).is_empty(), "087 created: the zombie's authored choice comes from its monster data (special_abilities), not code")
	var z1 := _target("b087_z1", Vector2i(1, 2), ["bludgeoning", "necrotic"])
	_ready_turn(combat, actor, [z1])
	combat.player_entities.append(unit)
	combat.current_player_idx = combat.player_entities.find(unit)
	combat.active_character = zombie
	combat.turn_budget.reset(zombie, combat.player_entities)
	seed(87010)
	var action_at_menu := [false]
	asked = await _drive(h, combat, func(): await CreatedCreatureCombat.take_turn(combat, unit), [func():
		action_at_menu[0] = combat.turn_budget.action_available
		return 1])
	h._assert(asked == 1 and action_at_menu[0] and int(z1.current_hp) < 300 and not combat.turn_budget.action_available, "087 created: the zombie's turn asks before its attack resolves (its action unspent at the menu); the Cold pick lands on the bludgeoning/necrotic-immune target (hp %d, at menu %s, after %s)" % [int(z1.current_hp), action_at_menu[0], combat.turn_budget.action_available])

	var z2 := _target("b087_z1", Vector2i(1, 2), ["bludgeoning"])
	_ready_turn(combat, actor, [z2])
	combat.player_entities.append(unit)
	combat.current_player_idx = combat.player_entities.find(unit)
	combat.active_character = zombie
	record["order"] = "attack"
	record["order_target"] = "b087_z1"
	combat.turn_budget.reset(zombie, combat.player_entities)
	seed(87011)
	asked = await _drive(h, combat, func(): await CreatedCreatureCombat.take_turn(combat, unit), [-1])
	h._assert(asked == 1 and combat.turn_budget.action_available and int(z2.current_hp) == 300 and _log(combat).contains("attack is not made and nothing was spent"), "087 created: dismissing holds the creature's attack; its action is not spent and nothing falls back to Bludgeoning")
	combat.player_entities.erase(unit)
	# A menu answer cannot authorize an attack after its action has gone away.
	var z3 := _target("b087_z1", Vector2i(1, 2), [])
	_ready_turn(combat, actor, [z3])
	combat.player_entities.append(unit)
	combat.current_player_idx = combat.player_entities.find(unit)
	combat.active_character = zombie
	combat.turn_budget.reset(zombie, combat.player_entities)
	record["order"] = "attack"
	record["order_target"] = "b087_z1"
	asked = await _drive(h, combat, func(): await CreatedCreatureCombat.take_turn(combat, unit), [func():
		combat.turn_budget.spend("action")
		return 1])
	h._assert(asked == 1 and int(z3.current_hp) == 300 and not combat.turn_budget.action_available, "087 created: losing the action while the choice is open holds the attack without damage")
	combat.player_entities.erase(unit)
	var z4 := _target("b087_z1", Vector2i(1, 2), [])
	_ready_turn(combat, actor, [z4])
	combat.player_entities.append(unit)
	combat.current_player_idx = combat.player_entities.find(unit)
	combat.active_character = zombie
	combat.turn_budget.reset(zombie, combat.player_entities)
	record["order"] = "attack"
	record["order_target"] = "b087_z1"
	asked = await _drive(h, combat, func(): await CreatedCreatureCombat.take_turn(combat, unit), [func():
		combat.active_character = actor
		return 1])
	h._assert(asked == 1 and int(z4.current_hp) == 300 and combat.turn_budget.action_available, "087 created: changing the active actor while the choice is open holds the attack and preserves the action")
	combat.player_entities.erase(unit)
	GameManager.created_creatures.erase(record)
	zombie_data["special_abilities"] = original_abilities

	GameManager.test_mode = true
	h._teardown_scene(combat)
	h._exit_test()
