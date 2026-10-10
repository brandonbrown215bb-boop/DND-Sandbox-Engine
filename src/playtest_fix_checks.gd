## Regression checks for the 2026-10-08 GUI playtest failures.
class_name PlaytestFixChecks
extends RefCounted

static func saved_coordinates(check: Callable) -> void:
	for accepted in [0, -12, 0.0, -12.0, 2147483647.0, -2147483648.0]:
		check.call(SaveManager._valid_json_coordinate(accepted), "Integral JSON coordinate accepted: %s" % str(accepted))
	for rejected in [0.5, NAN, INF, -INF, true, "0", null, 2147483648.0, -2147483649.0]:
		check.call(not SaveManager._valid_json_coordinate(rejected), "Malformed or overflowing coordinate rejected: %s" % str(rejected))
	for pass_name in ["a", "b"]:
		var path := "res://playtest-evidence/pass-%s-quicksave.json" % pass_name
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		check.call(data is Dictionary and SaveManager._validate_save_data(data).is_empty(), "Preserved GUI Pass %s checkpoint passes the production validator" % pass_name)
		if not data is Dictionary or not SaveManager._validate_save_data(data).is_empty():
			continue
		var slot := "playtest_preserved_%s" % pass_name
		var file := FileAccess.open(SaveManager.SAVE_DIR + slot + ".sav", FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		check.call(SaveManager.is_save_resumable(slot), "Preserved GUI Pass %s checkpoint is menu-eligible" % pass_name)
		GameManager.test_mode = true
		check.call(SaveManager.load_game(slot), "Preserved GUI Pass %s checkpoint actually loads" % pass_name)
		for location in GameManager.visited_overworld_locations:
			check.call(location["coord"][0] is int and location["coord"][1] is int, "Loaded visited coordinate is normalized after validation")
		var invalid: Dictionary = data.duplicate(true)
		invalid["campaign_ledger"]["visited_overworld_locations"][0]["coord"][0] = 0.5
		var before := GameManager.visited_overworld_locations.duplicate(true)
		file = FileAccess.open(SaveManager.SAVE_DIR + slot + ".sav", FileAccess.WRITE)
		file.store_string(JSON.stringify(invalid))
		file.close()
		check.call(not SaveManager.load_game(slot) and GameManager.visited_overworld_locations == before, "Fractional disk coordinates reject before changing the active campaign")
		SaveManager.delete_save(slot)
	GameManager._reset_campaign_ledgers()
	PlayerManager.reset()
	PartyManager.reset()

static func _character(klass: String) -> Character:
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 12, "DEX": 16, "CON": 14, "INT": 16, "WIS": 14, "CHA": 16})
	var actor := Character.new()
	actor.initialize("Playtest " + klass, "human", klass, scores)
	actor.inventory.add_item("shield")
	actor.inventory.equip(Inventory.Slot.SHIELD, "shield")
	return actor

static func weapon_damage(check: Callable) -> void:
	seed(20261009)
	for klass in ["paladin", "fighter", "cleric", "rogue"]:
		var actor := _character(klass)
		for weapon_id in ["longsword", "rapier", "shortbow"]:
			var weapon := DataLoader.get_item(weapon_id).duplicate(true)
			weapon["attack_bonus_override"] = 100
			weapon["attack_distance"] = 1
			var target := {"name": "Regression target", "armor_class": -100, "current_hp": 1000, "max_hp": 1000, "is_alive": true, "conditions": {"paralyzed": 1}}
			var result := CombatAction.resolve_weapon_attack(actor, target, weapon, true)
			check.call(result.get("hit", false), "%s production %s hits the fixture" % [klass, weapon_id])
			var detail: Dictionary = result.get("activity_damage", {})
			var rolled := 0
			for term in detail.get("dice_terms", []):
				rolled += int(term["subtotal"])
			var expected := 1 if weapon_id == "longsword" else 3
			check.call(int(detail.get("rolled_total", 0)) - rolled == expected, "%s %s adds its ability once, including on a critical" % [klass, weapon_id])
		var light := DataLoader.get_item("dagger").duplicate(true)
		light.merge({"light_extra": true, "attack_bonus_override": 100, "attack_distance": 1}, true)
		var light_result := CombatAction.resolve_weapon_attack(actor, {"name": "Target", "armor_class": -100, "current_hp": 1000, "conditions": {"paralyzed": 1}}, light, true)
		check.call(light_result.get("activity_damage", {}).get("modifiers", []).all(func(entry): return int(entry.get("value", 0)) <= 0), "Light extra attack omits the positive ability bonus")
	check.call(CombatAction._critical_dice_formula("1d8+INT+3") == "1d8", "Critical damage excludes all ability and flat terms")
	var paladin := _character("paladin")
	paladin.level_up()
	var target := {"name": "Undead target", "creature_type": "undead", "current_hp": 1000, "max_hp": 1000, "is_alive": true}
	paladin.spell_slots["2"] = 1
	var smite := CombatAction.resolve_divine_smite(paladin, target, 2, false, true)
	check.call(smite.get("success", false) and smite.get("damage_formula", "") == "8d8" and int(paladin.spell_slots["2"]) == 0, "Smite honors the chosen upcast, Undead bonus and triggering critical")
	var free := CombatAction.resolve_divine_smite(paladin, target, 1, true)
	check.call(free.get("success", false) and not paladin.has_free_spell_cast("divine_smite"), "Smite consumes its actual free Long Rest cast")
	check.call(not CombatAction.resolve_divine_smite(paladin, target, 1, true).get("success", false), "Repeated free Smite refuses without damage")


static func phase_one_wiring(check: Callable) -> void:
	# 1. Divine Smite trigger in CombatAction.resolve_weapon_attack
	var paladin := _character("paladin")
	paladin.level_up()
	var melee_weapon := DataLoader.get_item("longsword").duplicate(true)
	melee_weapon["attack_bonus_override"] = 100
	melee_weapon["attack_distance"] = 1
	var ranged_weapon := DataLoader.get_item("shortbow").duplicate(true)
	ranged_weapon["attack_bonus_override"] = 100
	ranged_weapon["attack_distance"] = 4
	var foe := {"name": "Undead foe", "creature_type": "undead", "current_hp": 100, "max_hp": 100, "is_alive": true}

	var melee_hit := CombatAction.resolve_weapon_attack(paladin, foe, melee_weapon, false)
	check.call(melee_hit.get("hit", false), "Paladin melee attack hits")
	check.call(melee_hit.get("can_divine_smite", false), "Paladin melee hit flags can_divine_smite as eligible")
	check.call(not melee_hit.has("divine_smite"), "Without smite reaction, divine_smite is not auto-resolved")

	var ranged_hit := CombatAction.resolve_weapon_attack(paladin, foe, ranged_weapon, false)
	check.call(not ranged_hit.get("can_divine_smite", false), "Ranged attack cannot use Divine Smite")

	var fighter := _character("fighter")
	var fighter_hit := CombatAction.resolve_weapon_attack(fighter, foe, melee_weapon, false)
	check.call(not fighter_hit.get("can_divine_smite", false), "Fighter melee attack cannot use Divine Smite")

	paladin.spell_slots["1"] = 2
	var prev_slots := int(paladin.spell_slots["1"])
	var smite_attack := CombatAction.resolve_weapon_attack(paladin, foe, melee_weapon, false, false, {"divine_smite": true})
	check.call(smite_attack.has("divine_smite"), "Attack with divine_smite reaction resolves Divine Smite")
	check.call(smite_attack.get("divine_smite", {}).get("success", false), "Divine Smite succeeded")
	check.call(smite_attack.get("damage", 0) > melee_hit.get("damage", 0), "Divine Smite added radiant damage to attack total")
	check.call(int(paladin.spell_slots["1"]) < prev_slots or not paladin.has_free_spell_cast("divine_smite"), "Divine Smite consumed resource")

	# 2. Escape key cancellation handling
	var esc_event := InputEventKey.new()
	esc_event.pressed = true
	esc_event.keycode = KEY_ESCAPE
	check.call(CombatHUD._is_cancel_event(esc_event), "KEY_ESCAPE recognized as cancel event")
	var space_event := InputEventKey.new()
	space_event.pressed = true
	space_event.keycode = KEY_SPACE
	check.call(not CombatHUD._is_cancel_event(space_event), "KEY_SPACE is not cancel event")

	# 3. HexGrid marker z-ordering and label collision position
	var center_pixel := Vector2(200.0, 200.0)
	var label_width := 60.0
	var unoccupied_pos := HexGrid.object_label_position(center_pixel, label_width, false)
	var occupied_pos := HexGrid.object_label_position(center_pixel, label_width, true)
	check.call(unoccupied_pos.y < center_pixel.y, "Unoccupied object label renders above the hex")
	check.call(occupied_pos.y > center_pixel.y, "Occupied object label offsets below the hex to prevent actor collision")
	check.call(occupied_pos == center_pixel + Vector2(-label_width / 2.0, 28.0), "Occupied label matches expected y + 28 offset")

	# 4. Racial traits wiring and Darkvision in Character.initialize and FogOfWar
	var dwarf := Character.new()
	dwarf.initialize("Bruenor", "dwarf", "fighter", AbilityScores.new())
	check.call(dwarf.traits.size() > 0, "Dwarf traits wired from JSON into character")
	check.call(dwarf.darkvision, "Dwarf darkvision flag set from JSON")
	check.call(dwarf.darkvision_feet == 120, "Dwarf darkvision standardized to 120 feet")
	check.call(dwarf.has_darkvision(), "Dwarf has_darkvision() helper returns true")
	check.call(dwarf.has_trait("dwarf_dwarven_resilience"), "Dwarf has dwarven resilience trait")

	var human := Character.new()
	human.initialize("Arthur", "human", "paladin", AbilityScores.new())
	check.call(human.traits.size() > 0, "Human traits wired from JSON into character")
	check.call(not human.darkvision, "Human darkvision flag is false")
	check.call(human.darkvision_feet == 0, "Human darkvision_feet is 0")
	check.call(not human.has_darkvision(), "Human has_darkvision() helper returns false")
	check.call(human.has_trait("human_versatility"), "Human has versatility trait")

	var elf := Character.new()
	elf.initialize("Legolas", "elf", "ranger", AbilityScores.new())
	check.call(elf.darkvision and elf.darkvision_feet == 60, "Elf darkvision wired to 60 feet")

	PlayerManager.reset()
	PlayerManager.add_player("Dwarf Player")
	PlayerManager.set_player_character(0, dwarf)
	PlayerManager.set_player_position(0, Vector2i.ZERO)
	var dwarf_grid := HexGrid.new()
	for c in HexUtils.get_hexes_in_range(Vector2i.ZERO, 4):
		var t := HexTile.new()
		t.coord = c
		dwarf_grid.add_tile(t)
	FogOfWar.update_visibility(dwarf_grid)
	var r3_tile: HexTile = dwarf_grid.get_tile(Vector2i(3, 0))
	check.call(r3_tile != null and r3_tile.is_visible, "Dwarf darkvision grants +1 exploration vision radius in FogOfWar")

	PlayerManager.reset()
	PlayerManager.add_player("Human Player")
	PlayerManager.set_player_character(0, human)
	PlayerManager.set_player_position(0, Vector2i.ZERO)
	var human_grid := HexGrid.new()
	for c in HexUtils.get_hexes_in_range(Vector2i.ZERO, 4):
		var t := HexTile.new()
		t.coord = c
		human_grid.add_tile(t)
	FogOfWar.update_visibility(human_grid)
	var human_r3_tile: HexTile = human_grid.get_tile(Vector2i(3, 0))
	check.call(human_r3_tile != null and not human_r3_tile.is_visible, "Human without darkvision stays at default radius 2 in FogOfWar")
	PlayerManager.reset()
	dwarf_grid.free()
	human_grid.free()

