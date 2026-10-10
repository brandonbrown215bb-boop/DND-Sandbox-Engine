extends Node

func _ready() -> void:
	call_deferred("_run")


func _make_roll(actor_name: String, target_name: String, action_title: String, d20_val: int, mod_val: int, total: int, target_val: int, outcome_code: String, outcome_label: String, dmg: int = 0, is_check: bool = false) -> Dictionary:
	return {
		"category": "roll",
		"kind": "check" if is_check else "attack",
		"actor": {"id": actor_name.to_lower().replace(" ", "-"), "name": actor_name},
		"targets": [{"id": target_name.to_lower().replace(" ", "-"), "name": target_name}],
		"title": action_title,
		"summary": "1d20 (%d) + %d = %d vs %s %d" % [d20_val, mod_val, total, "DC" if is_check else "AC", target_val],
		"outcome": {"code": outcome_code, "label": outcome_label},
		"visibility": "public",
		"payload": {
			"formula": "1d20 + %d" % mod_val,
			"dice_terms": [{
				"count": 1,
				"sides": 20,
				"results": [d20_val],
				"kept": [true],
				"label": "d20",
				"subtotal": d20_val,
			}],
			"modifiers": [
				{"label": "Bonus", "value": mod_val},
			],
			"natural_total": d20_val,
			"final_total": total,
			"comparison": {
				"kind": "difficulty_class" if is_check else "armor_class",
				"target": target_val,
				"margin": total - target_val,
				"result": outcome_code,
			},
			"sections": {
				"total_damage": dmg
			}
		}
	}


func _run() -> void:
	if not DirAccess.dir_exists_absolute("res://.artifacts/vtt-preview"):
		DirAccess.make_dir_recursive_absolute("res://.artifacts/vtt-preview")

	GameManager.test_mode = true
	var camp = DataLoader.campaigns.values()[0]
	GameManager.active_campaign = camp

	# Set up 2 players: Fighter & Wizard
	PlayerManager.reset()
	PartyManager.reset()
	PlayerManager.add_player("Sir Kaelen")
	PlayerManager.add_player("Elara")

	var scores1 := AbilityScores.new()
	scores1.from_dict({"STR": 16, "DEX": 12, "CON": 14, "INT": 10, "WIS": 12, "CHA": 8})
	var fighter := Character.new()
	fighter.initialize("Sir Kaelen", "human", "fighter", scores1)

	var scores2 := AbilityScores.new()
	scores2.from_dict({"STR": 8, "DEX": 14, "CON": 12, "INT": 16, "WIS": 14, "CHA": 10})
	var wizard := Character.new()
	wizard.initialize("Elara", "elf", "wizard", scores2)

	PlayerManager.set_player_character(0, fighter)
	PlayerManager.set_player_character(1, wizard)
	PartyManager.register_player_character(0, fighter)
	PartyManager.register_player_character(1, wizard)

	# 1. Preview Combat with rich Activity Rail history
	ActivityHistory.clear()
	ActivityHistory.publish({
		"category": "combat",
		"kind": "round_start",
		"title": "Round 1 Initiative",
		"summary": "Initiative resolved: Sir Kaelen (19), Elara (18), Goblins (11).",
		"visibility": "public",
		"payload": {}
	})
	ActivityHistory.publish(_make_roll("Sir Kaelen", "Goblin 1", "Longsword Attack", 14, 5, 19, 15, "hit", "Hit", 9))
	ActivityHistory.publish(_make_roll("Elara", "Goblin 2", "Fire Bolt Cantrip", 18, 5, 23, 15, "critical_hit", "Critical Hit", 14))
	ActivityHistory.publish(_make_roll("Goblin 1", "Sir Kaelen", "Scimitar Strike", 7, 4, 11, 19, "miss", "Miss", 0))

	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin", "goblin"]}
	var combat_scene = load("res://scenes/combat.tscn").instantiate()
	add_child(combat_scene)

	for i in 25:
		await get_tree().process_frame


	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("res://.artifacts/vtt-preview/combat_preview.png")
		print("[Preview] Saved combat_preview.png")

	combat_scene.queue_free()
	for i in 5:
		await get_tree().process_frame

	# 2. Preview Overworld with expedition Activity Rail history
	ActivityHistory.clear()
	ActivityHistory.publish({
		"category": "world",
		"kind": "travel",
		"title": "Expedition: Ashvale Plains",
		"summary": "The party departed the crossroad and entered the wild plains.",
		"visibility": "public",
		"payload": {}
	})
	ActivityHistory.publish(_make_roll("Sir Kaelen", "Terrain", "Survival (Navigation)", 14, 2, 16, 12, "hit", "Success", 0, true))
	ActivityHistory.publish(_make_roll("Elara", "Surroundings", "Perception (Scouting)", 17, 3, 20, 14, "critical_hit", "Great Success", 0, true))
	ActivityHistory.publish({
		"category": "system",
		"kind": "rest",
		"title": "Wilderness Camp",
		"summary": "The party pitched camp. HP and feature uses fully replenished.",
		"visibility": "public",
		"payload": {}
	})

	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.transition_context = {}
	var ow_scene = load("res://scenes/overworld.tscn").instantiate()
	add_child(ow_scene)

	for i in 25:
		await get_tree().process_frame

	var img_ow := get_viewport().get_texture().get_image()
	if img_ow != null:
		img_ow.save_png("res://.artifacts/vtt-preview/overworld_preview.png")
		print("[Preview] Saved overworld_preview.png")

	ow_scene.queue_free()
	for i in 5:
		await get_tree().process_frame

	# 3. Preview Dungeon with delve Activity Rail history
	ActivityHistory.clear()
	ActivityHistory.publish({
		"category": "world",
		"kind": "delve",
		"title": "Ruins of Ashvale (Entrance)",
		"summary": "Party entered the sunken sanctuary. Sconces flicker with green witchfire.",
		"visibility": "public",
		"payload": {}
	})
	ActivityHistory.publish(_make_roll("Sir Kaelen", "Iron Portcullis", "Athletics (Force Gate)", 15, 3, 18, 15, "hit", "Success", 0, true))
	ActivityHistory.publish({
		"category": "combat",
		"kind": "trap",
		"title": "Dart Trap Resolved",
		"summary": "Wall trap disarmed! Party avoided piercing dart volley.",
		"visibility": "public",
		"payload": {}
	})
	ActivityHistory.publish({
		"category": "world",
		"kind": "loot",
		"title": "Ornate Chest Opened",
		"summary": "Discovered 50 gold coins and a Potion of Healing.",
		"visibility": "public",
		"payload": {}
	})

	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon_scene = load("res://scenes/dungeon.tscn").instantiate()
	add_child(dungeon_scene)

	for i in 25:
		await get_tree().process_frame

	var img_dg := get_viewport().get_texture().get_image()
	if img_dg != null:
		img_dg.save_png("res://.artifacts/vtt-preview/dungeon_preview.png")
		print("[Preview] Saved dungeon_preview.png")

	dungeon_scene.queue_free()
	for i in 5:
		await get_tree().process_frame

	print("[Preview] COMPLETED")
	get_tree().quit(0)
