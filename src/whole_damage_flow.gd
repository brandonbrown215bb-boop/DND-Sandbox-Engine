class_name WholeDamageFlow
extends RefCounted

static func run(h: Node) -> void:
	h._enter_test("whole_damage_flow")
	h._setup_world()
	GameManager.current_state = GameManager.GameState.COMBAT
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.4)
	var owner: Character = PlayerManager.get_player(0).character
	owner.origin_feat = "savage_attacker"
	var target: Dictionary = combat.monster_entities[0]
	target.merge({"current_hp": 500, "max_hp": 500, "armor_class": -100, "ac": -100, "is_alive": true}, true)
	CombatAction.advance_combat_turn(owner, 1)
	FighterChecks._seed_die(20, 20)
	var offer := CombatAction.resolve_weapon_attack(owner, target, DataLoader.get_item("greatsword"), false, false, {"allow_whole_damage_choice": true})
	var seen := {"offer": false, "choice": false}
	var answer := func() -> void:
		for _frame in 600:
			await h.get_tree().process_frame
			for child in combat.hud.get_children():
				if not child is PopupMenu or child.is_queued_for_deletion(): continue
				if str(child.title).contains("roll the weapon's damage dice twice") and not seen.offer:
					seen.offer = true
					child.id_pressed.emit(0)
				elif str(child.title).contains("choose a complete weapon damage roll") and not seen.choice:
					seen.choice = true
					child.id_pressed.emit(1)
					return
	var was_test_mode := GameManager.test_mode
	GameManager.test_mode = false
	answer.call()
	var hit: Dictionary = await combat._settle_attack_profile_hit_choice(offer)
	GameManager.test_mode = was_test_mode
	h._assert(seen.offer and seen.choice and hit.get("hit", false) and int(hit.get("whole_damage_selected", -1)) == 1 and int(target.current_hp) < 500, "Soldier's actual combat HUD offers both whole rolls and settles the selected one")
	h._exit_test()
