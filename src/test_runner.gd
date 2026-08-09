## Test Runner (scene-based)
## Runs inside the normal project boot, so autoloads (DataLoader, Dice,
## PlayerManager, GameManager, SaveManager) and class_name globals (Character,
## CombatAction, HexGrid, ...) are all live. Exercises the real combat, grid,
## AI, spell, inventory, event, fog-of-war and persistence code paths.
extends Node

var _passed := 0
var _failed := 0
var _failures: Array[String] = []

func _ready() -> void:
	print("==================================================")
	print(" Rook's In-Engine Test Harness (scene runner)")
	print("==================================================")
	_test_data_loader()
	_test_character_creation()
	_test_dice_parser()
	_test_combat_action()
	_test_spellcasting()
	_test_ai_controller()
	_test_inventory()
	_test_conditions()
	_test_character_serialization()
	_test_player_manager()
	_test_event_system()
	_test_fog_of_war()
	_test_hexutils()
	_test_save_load()
	_test_widgets()
	_report()
	get_tree().quit(1 if _failed > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_failures.append(msg)
		print("[FAIL] %s" % msg)

func _report() -> void:
	print("--------------------------------------------------")
	print(" RESULTS: %d passed, %d failed" % [_passed, _failed])
	if _failed > 0:
		print(" FAILURES:")
		for f in _failures:
			print("   - %s" % f)
		print("TESTS FAILED")
	else:
		print("ALL TESTS PASSED")

# ---- helpers ----
func _fresh_char(name: String, race: String, klass: String, scores_dict: Dictionary) -> Character:
	var s: AbilityScores = AbilityScores.new()
	s.from_dict(scores_dict)
	var c: Character = Character.new()
	c.initialize(name, race, klass, s)
	return c

func _build_grid(radius: int) -> HexGrid:
	var grid: HexGrid = HexGrid.new()
	var cells: Array[Vector2i] = HexUtils.get_hexes_in_range(Vector2i.ZERO, radius)
	for cell in cells:
		var t: HexTile = HexTile.new()
		t.coord = cell
		t.terrain = HexTile.TerrainType.PLAINS
		t.is_revealed = true
		t.is_visible = true
		grid.add_tile(t)
	return grid

func _monster_inst(id: String) -> Dictionary:
	var m: Dictionary = DataLoader.get_monster(id)
	return {
		"name": m.get("name", id), "monster_id": id,
		"max_hp": int(m.get("hit_points", 7)), "current_hp": int(m.get("hit_points", 7)),
		"armor_class": int(m.get("armor_class", 15)), "speed": int(m.get("speed", 6)),
		"ability_scores": m.get("ability_scores", {}), "attacks": m.get("attacks", []),
		"ai_behavior": m.get("ai_behavior", "aggressive"),
		"hex_position": Vector2i(3, 0), "is_alive": true, "conditions": {}
	}

# ---- groups ----
func _test_data_loader() -> void:
	print("\n[Group] DataLoader")
	_assert(not DataLoader.monsters.is_empty(), "monsters registry populated")
	_assert(not DataLoader.spells.is_empty(), "spells registry populated")
	_assert(DataLoader.classes.size() >= 1, "at least one class loaded")
	_assert(DataLoader.races.size() >= 1, "at least one race loaded")
	var goblin: Dictionary = DataLoader.get_monster("goblin")
	_assert(not goblin.is_empty(), "lookup 'goblin' returns data")
	_assert(goblin.has("hit_points"), "goblin has hit_points field")
	_assert(goblin.has("attacks"), "goblin has attacks field")
	# real spell + event tables exist
	var fb: Dictionary = DataLoader.get_spell("fireball")
	_assert(not fb.is_empty() and fb.has("damage"), "fireball spell loaded with damage")
	_assert(DataLoader.get_event_table("dungeon_events").size() > 0, "dungeon_events table loaded")
	var camp: Dictionary = DataLoader.get_campaign("")
	# at least one campaign present
	_assert(DataLoader.campaigns.size() >= 1, "at least one campaign loaded")

func _test_character_creation() -> void:
	print("\n[Group] Character creation")
	var c: Character = _fresh_char("Tester", "human", "fighter",
		{"STR": 15, "DEX": 14, "CON": 13, "INT": 12, "WIS": 10, "CHA": 8})
	_assert(c.max_hp > 0, "initialized character has positive max_hp")
	_assert(c.current_hp == c.max_hp, "current_hp starts at max")
	_assert(c.is_alive, "character starts alive")
	_assert(c.ability_scores.get_ability_modifier("STR") == 3, "STR 15 + human +1 = 16 -> +3 modifier")
	_assert(c.has_feature("fighting_style") or c.features.size() > 0, "level 1 features unlocked")
	var before := c.current_hp
	var dealt := c.take_damage(3)
	_assert(dealt == 3 and c.current_hp == before - 3, "take_damage reduces hp by dealt amount")
	var healed := c.heal(9999)
	_assert(c.current_hp == c.max_hp and healed <= 9999, "heal clamps to max_hp")
	# temp hp absorbs first
	c.temp_hp = 5
	var d2 := c.take_damage(3)
	_assert(d2 == 0 and c.temp_hp == 2, "temp hp absorbs damage before hp")
	c.take_damage(c.max_hp + 50)
	_assert(not c.is_alive, "lethal damage flips is_alive false")

func _test_dice_parser() -> void:
	print("\n[Group] Dice parser")
	var total: int = Dice.parse_dice_string("2D6+3")
	_assert(total >= 5 and total <= 15, "2d6+3 in [5,15] (got %d)" % total)
	var modded: int = Dice.parse_dice_string("1D20+STR", {"STR": 3})
	_assert(modded >= 4 and modded <= 23, "1d20+STR(3) in [4,23] (got %d)" % modded)
	var neg: int = Dice.parse_dice_string("1D20-2")
	_assert(neg >= -1 and neg <= 18, "1d20-2 in [-1,18] (got %d)" % neg)
	var adv: int = Dice.roll_with_advantage(20)
	_assert(adv >= 1 and adv <= 20, "advantage roll in [1,20] (got %d)" % adv)

func _test_combat_action() -> void:
	print("\n[Group] CombatAction")
	var atk: Character = _fresh_char("Attacker", "human", "fighter",
		{"STR": 16, "DEX": 14, "CON": 14, "INT": 10, "WIS": 12, "CHA": 8})
	var weapon: Dictionary = DataLoader.get_item("longsword")
	if weapon.is_empty():
		weapon = {"name": "Test Sword", "ability": "STR", "damage": "1d8", "damage_type": "slashing"}
	else:
		if not weapon.has("ability"): weapon["ability"] = "STR"
		if not weapon.has("damage"): weapon["damage"] = "1d8"
	var mi: Dictionary = _monster_inst("goblin")
	var saw_hit := false
	var saw_miss := false
	for i in 50:
		var res: Dictionary = CombatAction.resolve_weapon_attack(atk, mi, weapon)
		_assert(typeof(res) == TYPE_DICTIONARY, "attack returns a dictionary")
		_assert(res.has("hit") and res.has("message"), "attack result has hit + message keys")
		_assert(not res.get("hit", false) or int(res.get("damage", -1)) >= 0,
			"hit deals non-negative damage when present")
		if res.get("hit", false):
			saw_hit = true
		else:
			saw_miss = true
	_assert(saw_hit, "observed at least one hit across 50 attacks")
	_assert(saw_miss, "observed at least one miss across 50 attacks (RNG variance)")
	_assert(int(mi.get("current_hp", -99)) <= 7, "monster hp tracked during attacks")
	# advantage improves hit chance meaningfully over many rolls
	var hits_adv := 0
	for i in 200:
		var r: Dictionary = CombatAction.resolve_weapon_attack(atk, mi, weapon, true, false)
		if r.get("hit", false): hits_adv += 1
	_assert(hits_adv > 100, "advantage yields >50%% hits over 200 rolls (got %d)" % hits_adv)

func _test_spellcasting() -> void:
	print("\n[Group] Spellcasting")
	# Fireball: level 3 save-based AoE. Caster is a wizard with INT.
	var caster: Character = _fresh_char("Mage", "human", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	caster.spell_slots = {"3": 1}
	var fb: Dictionary = DataLoader.get_spell("fireball")
	var target: Dictionary = _monster_inst("goblin")
	# deduct slot true -> slot should decrement
	var res: Dictionary = CombatAction.resolve_spell(caster, target, fb, true)
	_assert(res.get("success", false), "fireball resolves with success")
	_assert(caster.spell_slots.get("3", 1) == 0, "spell slot deducted when deduct_slot=true")
	_assert(int(res.get("damage", -1)) >= 0, "fireball deals non-negative damage")
	_assert(int(res.get("damage", -1)) <= 48, "fireball damage <= 8d6 max (got %d)" % int(res.get("damage", -1)))
	# No slots left -> resolve fails cleanly
	var res2: Dictionary = CombatAction.resolve_spell(caster, target, fb, true)
	_assert(not res2.get("success", true), "fireball fails when no slots remain")
	# Spell-attack branch (magic_missile has no save/damage top-level -> spell attack)
	var mm: Dictionary = DataLoader.get_spell("magic_missile")
	var caster2: Character = _fresh_char("Mage2", "human", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	var t2: Dictionary = _monster_inst("goblin")
	var res3: Dictionary = CombatAction.resolve_spell(caster2, t2, mm, false)
	_assert(res3.get("success", false), "magic_missile spell resolves")
	_assert(res3.has("hit"), "spell-attack result has hit key")
	# Counterspell reaction: target with counterspell known interrupts
	var victim: Character = _fresh_char("Victim", "human", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	victim.known_spells.append("counterspell")
	victim.spell_slots = {"3": 1}
	victim.reaction_available = true
	var caster3: Character = _fresh_char("Mage3", "human", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	var res4: Dictionary = CombatAction.resolve_spell(caster3, victim, fb, false)
	_assert(not res4.get("success", true), "counterspell interrupts incoming spell")
	_assert("Counterspell" in res4.get("message", ""), "counterspell message present")

func _test_ai_controller() -> void:
	print("\n[Group] AIController")
	var grid: HexGrid = _build_grid(4)
	# aggressive: player far -> move towards / move_attack
	var mon_aggr := _monster_inst("goblin")
	mon_aggr["ai_behavior"] = "aggressive"
	mon_aggr["hex_position"] = Vector2i(3, 0)
	var pchar1: Character = _fresh_char("Hero", "human", "wizard", {"STR":10,"DEX":10,"CON":10,"INT":10,"WIS":10,"CHA":10})
	var players1 := [{"character": pchar1, "hex_position": Vector2i(-3, 0), "is_alive": true}]
	var d1: Dictionary = AIController.get_monster_action(mon_aggr, mon_aggr["hex_position"], grid, players1)
	_assert(d1["action"] in ["attack", "move", "move_attack", "none"], "aggressive action known (got '%s')" % d1.get("action",""))
	if d1.has("move_to"):
		_assert(grid.has_tile(d1["move_to"]), "aggressive move_to is on grid")
	# defensive: player adjacent -> should move_attack away or attack
	var mon_def := _monster_inst("goblin")
	mon_def["ai_behavior"] = "defensive"
	mon_def["hex_position"] = Vector2i(0, 0)
	var pchar2: Character = _fresh_char("Hero2", "human", "wizard", {"STR":10,"DEX":10,"CON":10,"INT":10,"WIS":10,"CHA":10})
	var players2 := [{"character": pchar2, "hex_position": Vector2i(1, 0), "is_alive": true}]
	var d2: Dictionary = AIController.get_monster_action(mon_def, mon_def["hex_position"], grid, players2)
	_assert(d2["action"] in ["attack", "move", "move_attack", "none"], "defensive action known (got '%s')" % d2.get("action",""))
	if d2["action"] == "move_attack":
		_assert(grid.has_tile(d2["move_to"]), "defensive move_attack move_to is on grid")
	# support: currently implemented as aggressive fallback
	var mon_sup := _monster_inst("goblin")
	mon_sup["ai_behavior"] = "support"
	mon_sup["hex_position"] = Vector2i(3, 0)
	var d3: Dictionary = AIController.get_monster_action(mon_sup, mon_sup["hex_position"], grid, players1)
	_assert(d3["action"] in ["attack", "move", "move_attack", "none"], "support action known (got '%s')" % d3.get("action",""))
	# no players alive -> none
	var d4: Dictionary = AIController.get_monster_action(mon_aggr, mon_aggr["hex_position"], grid, [])
	_assert(d4["action"] == "none", "no alive players -> action 'none'")
	grid.free()

func _test_inventory() -> void:
	print("\n[Group] Inventory")
	var inv: Inventory = Inventory.new()
	_assert(inv.add_item("gold_100"), "add_item succeeds when not full")
	_assert(inv.has_item("gold_100"), "has_item true after add")
	_assert(inv.count_item("gold_100") == 1, "count_item returns 1")
	_assert(inv.remove_item("gold_100"), "remove_item succeeds")
	_assert(not inv.has_item("gold_100"), "has_item false after remove")
	# equip a real weapon
	var wpn: Dictionary = DataLoader.get_item("longsword")
	if not wpn.is_empty():
		inv.add_item("longsword")
		var prev: String = inv.equip(Inventory.Slot.WEAPON, "longsword")
		_assert(inv.get_weapon() == "longsword", "get_weapon returns equipped weapon")
		_assert(prev == "", "equip returns empty previous when slot was empty")
		inv.unequip(Inventory.Slot.WEAPON)
		_assert(inv.get_weapon() == "", "unequip clears weapon slot")
	# backpack cap
	var inv2: Inventory = Inventory.new()
	for i in 20:
		inv2.add_item("gold_100")
	_assert(inv2.backpack.size() == 20, "backpack reaches max 20")
	_assert(not inv2.add_item("gold_100"), "add_item fails when backpack full")
	# ac bonus from equipped armor item with ac_bonus
	var bonus := 0
	for item_id in DataLoader.items.keys():
		var d: Dictionary = DataLoader.get_item(item_id)
		if int(d.get("ac_bonus", 0)) > 0:
			inv2.equip(Inventory.Slot.BODY, item_id)
			bonus = inv2.calculate_ac_bonus()
			break
	_assert(typeof(bonus) == TYPE_INT and bonus >= 0, "calculate_ac_bonus returns int >= 0 (got %d)" % bonus)
	# round-trip
	var snap: Dictionary = inv2.to_dict()
	var inv3: Inventory = Inventory.new()
	inv3.from_dict(snap)
	_assert(inv3.gold == inv2.gold, "inventory gold survives round-trip")

func _test_conditions() -> void:
	print("\n[Group] Conditions")
	var c: Character = _fresh_char("Cond", "human", "fighter",
		{"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
	c.add_condition("poisoned", 3)
	_assert(c.has_condition("poisoned"), "condition active after add")
	c.tick_conditions()
	_assert(c.has_condition("poisoned"), "condition persists after one tick")
	c.tick_conditions()
	c.tick_conditions()
	_assert(not c.has_condition("poisoned"), "condition expires after duration elapses")
	c.add_condition("blessed", 1)
	c.tick_conditions()
	_assert(not c.has_condition("blessed"), "single-turn condition expires")
	# blinded grants disadvantage path inside make_attack_roll (smoke)
	c.add_condition("blinded", 5)
	var roll: Dictionary = c.make_attack_roll("STR")
	_assert(roll.has("total"), "attack roll still produced while blinded")

func _test_character_serialization() -> void:
	print("\n[Group] Character serialization")
	var c: Character = _fresh_char("Hero", "human", "wizard",
		{"STR":8,"DEX":14,"CON":14,"INT":16,"WIS":12,"CHA":10})
	c.current_hp = 5
	c.inventory.add_item("gold_100")
	var d: Dictionary = c.to_dict()
	var c2: Character = Character.new()
	c2.from_dict(d)
	_assert(c2.character_name == "Hero", "name survives round-trip")
	_assert(c2.race_id == "human", "race survives round-trip")
	_assert(c2.class_id == "wizard", "class survives round-trip")
	_assert(c2.max_hp == c.max_hp, "max_hp survives round-trip")
	_assert(c2.current_hp == 5, "current_hp survives round-trip")
	_assert(c2.level == 1, "level survives round-trip")
	_assert(c2.inventory.has_item("gold_100"), "inventory item survives round-trip")
	_assert(c2.ability_scores.get_ability_modifier("INT") == c.ability_scores.get_ability_modifier("INT"), "ability mod survives round-trip")

func _test_player_manager() -> void:
	print("\n[Group] PlayerManager")
	PlayerManager.reset()
	var i0 := PlayerManager.add_player("A")
	var i1 := PlayerManager.add_player("B")
	_assert(i0 == 0 and i1 == 1, "add_player returns sequential indices")
	_assert(PlayerManager.get_player_count() == 2, "player count is 2")
	PlayerManager.start_game()
	_assert(PlayerManager.active_player_index == 0, "start_game sets active to 0")
	PlayerManager.next_turn()  # -> 1
	_assert(PlayerManager.active_player_index == 1, "next_turn advances to player 1")
	var nr := PlayerManager.next_turn()  # -> 0, new round
	_assert(PlayerManager.active_player_index == 0, "next_turn wraps to player 0")
	_assert(nr, "wrapping to first player starts a new round")
	_assert(PlayerManager.current_round == 2, "round incremented on wrap")
	# serialize / deserialize with real characters
	PlayerManager.reset()
	PlayerManager.add_player("Alice")
	PlayerManager.add_player("Bob")
	var ca: Character = _fresh_char("Alice", "human", "fighter", {"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
	var cb: Character = _fresh_char("Bob", "elf", "wizard", {"STR":8,"DEX":14,"CON":14,"INT":16,"WIS":12,"CHA":10})
	PlayerManager.set_player_character(0, ca)
	PlayerManager.set_player_character(1, cb)
	PlayerManager.set_player_position(0, Vector2i(2, 0))
	var snap: Array = PlayerManager.serialize()
	PlayerManager.reset()
	PlayerManager.deserialize(snap)
	_assert(PlayerManager.get_player_count() == 2, "player count survives serialize")
	_assert(PlayerManager.get_player(0)["name"] == "Alice", "player name survives serialize")
	_assert(PlayerManager.get_player(0)["character"].character_name == "Alice", "character survives serialize")
	_assert(PlayerManager.get_player_position(0) == Vector2i(2, 0), "player position survives serialize")
	# party wiped detection
	PlayerManager.reset()
	_assert(not PlayerManager.is_party_wiped(), "empty roster is not a wipe")
	PlayerManager.add_player("Dead")
	var dead: Character = _fresh_char("Dead", "human", "fighter", {"STR":10,"DEX":10,"CON":10,"INT":10,"WIS":10,"CHA":10})
	dead.current_hp = 0
	dead.is_alive = false
	PlayerManager.set_player_character(0, dead)
	_assert(PlayerManager.is_party_wiped(), "all-dead party reports wiped")

func _test_event_system() -> void:
	print("\n[Group] EventSystem")
	var known_ids := ["trapped_chest", "undead_ambush", "mysterious_fountain", "cave_in", "ghostly_warning", "treasure_room", "ooze_encounter"]
	var all_known := true
	for i in 200:
		var ev: Dictionary = EventSystem.roll_event("dungeon_events")
		if ev.is_empty() or ev.get("id", "") not in known_ids:
			all_known = false
			break
	_assert(all_known, "roll_event always returns a valid dungeon event over 200 rolls")
	var one: Dictionary = EventSystem.roll_event("dungeon_events")
	_assert(one.has("id") and one.has("weight"), "event has id + weight fields")
	# missing table -> empty dict
	_assert(EventSystem.roll_event("does_not_exist").is_empty(), "unknown table returns empty dict")
	# trigger via tile with explicit event_table_id
	var tile: HexTile = HexTile.new()
	tile.coord = Vector2i.ZERO
	tile.event_table_id = "dungeon_events"
	var tev: Dictionary = EventSystem.trigger_event_for_tile(tile)
	_assert(not tev.is_empty(), "trigger_event_for_tile returns an event")
	# terrain lookup requires an active campaign set
	var camp: Dictionary = DataLoader.campaigns.values()[0]
	GameManager.active_campaign = camp
	var tile2: HexTile = HexTile.new()
	tile2.coord = Vector2i.ZERO
	tile2.terrain = HexTile.TerrainType.DUNGEON_ENTRANCE
	var tid := EventSystem.get_table_for_terrain("dungeon")
	# not asserting specific value (campaign-dependent) but that it returns a string
	_assert(typeof(tid) == TYPE_STRING, "get_table_for_terrain returns a string")

func _test_fog_of_war() -> void:
	print("\n[Group] FogOfWar")
	PlayerManager.reset()
	PlayerManager.add_player("Scout")
	var scout: Character = _fresh_char("Scout", "human", "ranger",
		{"STR":12,"DEX":16,"CON":14,"INT":10,"WIS":14,"CHA":10})
	PlayerManager.set_player_character(0, scout)
	PlayerManager.set_player_position(0, Vector2i.ZERO)
	var grid: HexGrid = _build_grid(2)
	FogOfWar.update_visibility(grid)
	var center: HexTile = grid.get_tile(Vector2i.ZERO)
	_assert(center != null and center.is_visible, "tile under player is visible")
	# tile within default vision radius (2) is revealed
	var near: HexTile = grid.get_tile(Vector2i(0, 1))
	_assert(near != null and near.is_revealed, "tile within radius 2 is revealed")
	# tile at radius 3 does not exist in this grid; build bigger to test exclusion
	var grid2: HexGrid = _build_grid(3)
	FogOfWar.update_visibility(grid2)
	var far: HexTile = grid2.get_tile(Vector2i(3, 0))
	_assert(far != null, "far tile exists in radius-3 grid")
	# visibility resets each call; a tile outside vision should not be visible
	var far_visible := far.is_visible
	# radius 2 vision from origin cannot reach (3,0) (distance 3)
	_assert(not far_visible, "tile beyond vision radius is not visible")
	grid.free()
	grid2.free()

func _test_hexutils() -> void:
	print("\n[Group] HexUtils")
	_assert(HexUtils.get_distance(Vector2i.ZERO, Vector2i(3, 0)) == 3, "distance (0,0)->(3,0) == 3")
	_assert(HexUtils.get_distance(Vector2i.ZERO, Vector2i.ZERO) == 0, "distance to self == 0")
	var nb: Array[Vector2i] = HexUtils.get_neighbors(Vector2i.ZERO)
	_assert(nb.size() == 6, "a hex has 6 neighbors")
	var ring: Array[Vector2i] = HexUtils.get_hex_ring(Vector2i.ZERO, 2)
	_assert(ring.size() == 12, "hex ring radius 2 has 12 tiles (got %d)" % ring.size())
	var inrange: Array[Vector2i] = HexUtils.get_hexes_in_range(Vector2i.ZERO, 1)
	_assert(inrange.size() == 7, "hexes within radius 1 == 7 (center + 6)")
	# pixel round-trip
	var pix: Vector2 = HexUtils.hex_to_pixel(Vector2i(4, -2))
	var back: Vector2i = HexUtils.pixel_to_hex(pix)
	_assert(back == Vector2i(4, -2), "hex->pixel->hex round trips")
	# line of sight: straight line, no blockers -> true
	var los := HexUtils.has_line_of_sight(Vector2i.ZERO, Vector2i(3, 0), func(h: Vector2i) -> bool: return false)
	_assert(los, "clear line of sight returns true")
	var los_blocked := HexUtils.has_line_of_sight(Vector2i.ZERO, Vector2i(3, 0), func(h: Vector2i) -> bool: return h == Vector2i(1, 0))
	_assert(not los_blocked, "blocked intermediate hex breaks line of sight")
	# static A* pathfinding
	var path: Array[Vector2i] = HexUtils.find_path(Vector2i.ZERO, Vector2i(3, 0),
		func(h: Vector2i) -> bool: return true, func(h: Vector2i) -> float: return 1.0, 100)
	_assert(path.size() >= 2 and path[0] == Vector2i.ZERO and path[-1] == Vector2i(3, 0), "static find_path endpoints correct")

func _test_save_load() -> void:
	print("\n[Group] Save/Load")
	# Set up minimal game-in-progress state
	var camp: Dictionary = DataLoader.campaigns.values()[0]
	GameManager.active_campaign = camp
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	PlayerManager.reset()
	PlayerManager.add_player("Sava")
	var sc: Character = _fresh_char("Sava", "human", "fighter", {"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
	PlayerManager.set_player_character(0, sc)
	var slot := "rook_test_slot"
	# clean any prior
	SaveManager.delete_save(slot)
	var saved := SaveManager.save_game(slot)
	_assert(saved, "save_game returns true when game in progress")
	var saves: Array[String] = SaveManager.get_available_saves()
	_assert(slot in saves, "saved slot appears in available saves")
	var deleted := SaveManager.delete_save(slot)
	_assert(deleted, "delete_save returns true for existing slot")
	var saves2: Array[String] = SaveManager.get_available_saves()
	_assert(slot not in saves2, "slot gone after delete")
	GameManager.game_in_progress = false

func _test_widgets() -> void:
	print("\n[Group] UI Widgets")
	# LogPanel: severity-aware RichTextLabel wrapper, backwards-compatible with
	# the BaseHUD log_text contract (.text still holds the rendered log).
	var lp: LogPanel = LogPanel.new()
	add_child(lp)
	_assert(lp is RichTextLabel, "LogPanel is a RichTextLabel (HUD log_text contract survives)")
	lp.clear_logs()
	lp.log_info("scout moved")
	lp.log_danger("trap! 3 dmg")
	lp.add_log("legacy call still works")
	_assert(lp.text.contains("scout moved"), "LogPanel log_info appends text")
	_assert(lp.text.contains("trap! 3 dmg"), "LogPanel log_danger appends text")
	_assert(lp.text.contains("legacy call still works"), "LogPanel add_log shim works")
	lp.clear_logs()
	_assert(lp.text == "", "LogPanel clear_logs empties the log")
	lp.free()
	# ActionBar: consistent icon+label action row (icon optional).
	var bar: ActionBar = ActionBar.new()
	add_child(bar)
	_assert(bar is HBoxContainer, "ActionBar is an HBoxContainer")
	var rest_btn: Button = bar.add_action("rest", "Rest", null, func(): pass)
	_assert(rest_btn != null and rest_btn.text == "Rest", "ActionBar.add_action creates a labeled button")
	_assert(rest_btn.name == "Action_rest", "ActionBar button named Action_<id>")
	bar.push_right()
	var sheet_btn: Button = bar.add_action("sheet", "Sheet")
	_assert(sheet_btn != null, "ActionBar.add_action works icon-less (no art required)")
	var fired_state := {"id": ""}
	bar.action_pressed.connect(func(id: String): fired_state.id = id)
	bar.trigger("sheet")
	_assert(fired_state.id == "sheet", "ActionBar.trigger emits action_pressed with the action id")
	bar.clear_actions()
	_assert(bar.get_child_count() == 0, "ActionBar.clear_actions removes buttons")
	bar.free()
