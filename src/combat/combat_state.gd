## Combat State Controller
## Manages tactical round initiative, player actions, enemy AI turns, and win/lose checks.
class_name CombatState
extends Node2D

@onready var hex_grid: HexGrid = $HexGrid
@onready var hud: CombatHUD = $CombatHUD

# Initiative queue
var tracker: InitiativeTracker = InitiativeTracker.new()

# Tactical entities state
# Maps entity_id -> position (Vector2i)
var player_entities: Array[Dictionary] = [] # Elements same as PlayerManager.players
var monster_entities: Array[Dictionary] = [] # Keys: name, monster_id, current_hp, max_hp, armor_class, speed, attacks, hex_position, color, is_alive

# Input states
var current_player_idx: int = -1
var active_combatant: Dictionary = {} # Reference from tracker
var active_character: Character = null # If active_combatant is player
var remaining_speed: float = 0.0
var has_acted_this_turn: bool = false

# Targeting action mode
var pending_action_type: String = "" # "attack", "spell"
var pending_spell_data: Dictionary = {}

# Guards against double-triggering battle end (victory/defeat).
var _battle_ending := false


func _ready() -> void:
	# Connect HUD action selectors
	hud.action_selected.connect(_on_hud_action)
	hud.settings_pressed.connect(func(): Settings.open_settings(self))
	hud.sheet_pressed.connect(func(): CharacterSheet.show_sheet(active_character))
	hex_grid.hex_clicked.connect(_on_hex_clicked)
	hex_grid.hex_hovered.connect(_on_hex_hovered)

	# Center the hex grid in the visible area to the right of the sidebar
	hex_grid.position = Vector2(775, 295)

	# Build small tactical grid (radius 4)
	hex_grid.tiles.clear()
	var center := Vector2i.ZERO
	var cells := HexUtils.get_hexes_in_range(center, 4)
	var terrain_str: String = GameManager.transition_context.get("terrain", "plains")
	var terrain_type = HexTile.TERRAIN_MAP.get(terrain_str, HexTile.TerrainType.PLAINS)

	for cell in cells:
		var tile := HexTile.new()
		tile.coord = cell
		tile.terrain = terrain_type
		tile.is_revealed = true
		tile.is_visible = true
		hex_grid.add_tile(tile)

	# Populate players
	_setup_combat_players()

	# Populate monsters
	_setup_combat_monsters()

	# Build initiative tracker
	_roll_initiative_and_start()
	_update_grid_entities()


func _update_grid_entities() -> void:
	hex_grid.clear_entities()
	
	# Add players
	for p in player_entities:
		if p.get("character") != null and p["character"].is_alive:
			hex_grid.add_entity({
				"hex_position": p.get("hex_position", Vector2i.ZERO),
				"color": p.get("color", Color.WHITE),
				"is_player": true,
				"character": p["character"]
			})
	
	# Add monsters
	for m in monster_entities:
		if m.get("is_alive", true):
			hex_grid.add_entity({
				"hex_position": m.get("hex_position", Vector2i.ZERO),
				"color": m.get("color", Color.RED),
				"is_player": false,
				"monster": m
			})


func _setup_combat_players() -> void:
	player_entities = []
	for p in PlayerManager.players:
		player_entities.append(p.duplicate())
	var player_count := player_entities.size()
	
	# Spawn players on the left side of tactical grid
	var spawn_points := [
		Vector2i(-3, 0),
		Vector2i(-3, 1),
		Vector2i(-3, -1),
		Vector2i(-2, 0)
	]
	
	for i in player_count:
		var pos = spawn_points[i]
		player_entities[i]["hex_position"] = pos
		player_entities[i]["reaction_available"] = true
		var char_data: Character = player_entities[i]["character"]
		if char_data != null:
			char_data.reset_combat_features()
			char_data.is_alive = char_data.current_hp > 0
			char_data.reaction_available = true


func _setup_combat_monsters() -> void:
	monster_entities.clear()
	var monster_ids: Array = GameManager.transition_context.get("monster_ids", [])
	if monster_ids.is_empty():
		# Fallback to simple goblins if debug combat launched
		monster_ids = ["goblin", "goblin"]

	# Spawn monsters on the right side of tactical grid
	var spawn_points := [
		Vector2i(3, 0),
		Vector2i(3, -1),
		Vector2i(3, 1),
		Vector2i(2, 0)
	]

	for i in monster_ids.size():
		var m_id = monster_ids[i]
		var base_monster := DataLoader.get_monster(m_id)
		if base_monster.is_empty(): continue

		# Make a unique clone for this combat instance
		var hp_str: String = base_monster.get("hit_points", "2d6")
		var max_hp := Dice.parse_dice_string(hp_str)
		
		var monster_inst := {
			"id": "monster_%d" % i,
			"name": "%s %d" % [base_monster.get("name", m_id), i + 1],
			"monster_id": m_id,
			"max_hp": max_hp,
			"current_hp": max_hp,
			"armor_class": int(base_monster.get("armor_class", 10)),
			"speed": int(base_monster.get("speed", 6)),
			"ability_scores": base_monster.get("ability_scores", {}),
			"attacks": base_monster.get("attacks", []),
			"ai_behavior": base_monster.get("ai_behavior", "aggressive"),
			"hex_position": spawn_points[i % spawn_points.size()],
			"color": Color(0.9, 0.3, 0.3),
			"is_alive": true,
			"conditions": {}
		}
		monster_entities.append(monster_inst)


func _roll_initiative_and_start() -> void:
	tracker.clear()

	# Roll players
	for i in player_entities.size():
		var p := player_entities[i]
		var char_data: Character = p.get("character")
		if char_data == null or not char_data.is_alive: continue

		var roll = Dice.roll(20)
		var dex = char_data.ability_scores.get_score("DEX")
		var mod = AbilityScores.get_modifier(dex)
		var total = roll + mod

		tracker.add_combatant(
			"player_%d" % i,
			char_data.character_name,
			true,
			char_data,
			total,
			dex
		)

	# Roll monsters
	for m in monster_entities:
		var roll = Dice.roll(20)
		var monster_scores: Dictionary = m.get("ability_scores", {})
		var dex = int(monster_scores.get("DEX", 10))
		var mod = AbilityScores.get_modifier(dex)
		var total = roll + mod

		tracker.add_combatant(
			m["id"],
			m["name"],
			false,
			m,
			total,
			dex
		)

	tracker.sort_initiative()
	_start_combat_turn()


func _start_combat_turn() -> void:
	active_combatant = tracker.get_active()
	if active_combatant.is_empty():
		return

	# Clear targeting highlights
	pending_action_type = ""
	hex_grid.clear_highlights()

	var is_player: bool = active_combatant["is_player"]
	if is_player:
		# Player Turn
		active_character = active_combatant["entity"]
		if not active_character.is_alive:
			hud.add_log("[color=gray]%s is knocked out and skips their turn.[/color]" % active_character.character_name)
			await get_tree().create_timer(1.0).timeout
			_end_active_turn()
			return

		# Process turn-start condition effects (like poison)
		if active_character.has_condition("poisoned"):
			var dmg := Dice.roll(4) # 1d4 poison damage
			var actual := active_character.take_damage(dmg)
			hud.add_log("[color=red]%s took %d poison damage from being poisoned![/color]" % [active_character.character_name, actual])
			if not active_character.is_alive:
				hud.add_log("[color=red]%s was knocked out by poison![/color]" % active_character.character_name)
				await get_tree().create_timer(1.0).timeout
				_end_active_turn()
				return

		# Check stunned condition
		if active_character.has_condition("stunned"):
			hud.add_log("[color=orange]%s is Stunned and skips their turn.[/color]" % active_character.character_name)
			await get_tree().create_timer(1.0).timeout
			_end_active_turn()
			return

		var speed_val := float(active_character.speed)
		if active_character.has_condition("prone"):
			speed_val /= 2.0
		remaining_speed = speed_val
		has_acted_this_turn = false
		
		# Reset once-per-turn features/restrictions for this player
		active_character.reaction_available = true
		for p in player_entities:
			if p["character"] == active_character:
				p["reaction_available"] = true
				break
		if active_character.has_feature("cunning_action"):
			active_character.feature_uses["cunning_action_dash"] = 1
			active_character.feature_uses["cunning_action_disengage"] = 1
			active_character.feature_uses["cunning_action_hide"] = 1
		if active_character.has_feature("sneak_attack"):
			active_character.feature_uses["sneak_attack_used_this_turn"] = 0
		
		# Find player idx
		current_player_idx = -1
		for i in player_entities.size():
			if player_entities[i]["character"] == active_character:
				current_player_idx = i
				break

		hud.update_hud(active_character, tracker)
		hud.set_controls_disabled(false)
		hud.add_log("[color=yellow]=== Turn: %s (Player) ===[/color]" % active_character.character_name)
		_highlight_reachable()
	else:
		# Monster Turn
		var monster: Dictionary = active_combatant["entity"]
		monster["reaction_available"] = true
		
		# Process turn-start condition effects (like poison)
		var monster_conditions: Dictionary = monster.get("conditions", {})
		if monster_conditions.has("poisoned"):
			var dmg := Dice.roll(4)
			var hp := int(monster.get("current_hp", 0))
			var actual := mini(dmg, hp)
			monster["current_hp"] = hp - actual
			hud.add_log("[color=red]%s took %d poison damage from being poisoned![/color]" % [monster["name"], actual])
			if monster["current_hp"] <= 0:
				monster["is_alive"] = false
				hud.add_log("[color=green]%s was defeated by poison![/color]" % monster["name"])
				tracker.remove_combatant(monster["id"])
				await get_tree().create_timer(1.0).timeout
				_end_active_turn()
				return

		# Check stunned condition
		if monster_conditions.has("stunned"):
			hud.add_log("[color=orange]%s is Stunned and skips their turn.[/color]" % monster["name"])
			await get_tree().create_timer(1.0).timeout
			_end_active_turn()
			return

		hud.update_hud(null, tracker)
		hud.set_controls_disabled(true)
		hud.add_log("[color=red]=== Turn: %s (Monster) ===[/color]" % active_combatant["name"])
		
		await get_tree().create_timer(1.0).timeout
		_run_monster_ai()


func _run_monster_ai() -> void:
	var monster: Dictionary = active_combatant["entity"]
	var monster_coord: Vector2i = monster.get("hex_position", Vector2i.ZERO)
	
	# Get AI decision
	var decision := AIController.get_monster_action(monster, monster_coord, hex_grid, player_entities)
	var action_str: String = decision.get("action", "none")

	match action_str:
		"move":
			var dest: Vector2i = decision["move_to"]
			var path := [monster_coord, dest]
			_check_opportunity_attacks_for_path(null, monster, path, true)
			if monster["is_alive"]:
				hud.add_log("%s moved closer." % monster["name"])
		"attack":
			var target_name: String = decision["target_id"]
			var attack_idx: int = decision["attack_idx"]
			_execute_monster_attack(monster, target_name, attack_idx)
		"move_attack":
			# Move
			var dest: Vector2i = decision["move_to"]
			var path := [monster_coord, dest]
			_check_opportunity_attacks_for_path(null, monster, path, true)
			if monster["is_alive"]:
				# Attack
				var target_name: String = decision["target_id"]
				var attack_idx: int = decision["attack_idx"]
				hud.add_log("%s moved and attacked!" % monster["name"])
				_execute_monster_attack(monster, target_name, attack_idx)
		_:
			hud.add_log("%s dodges." % monster["name"])

	_update_grid_entities()
	await get_tree().create_timer(1.2).timeout
	_end_active_turn()


func _execute_monster_attack(monster: Dictionary, target_player_name: String, attack_idx: int) -> void:
	var attack_data: Dictionary = monster["attacks"][attack_idx]
	
	# Find target player char and position
	var target_char: Character = null
	var target_pos := Vector2i.ZERO
	for p in player_entities:
		if p["character"].character_name == target_player_name:
			target_char = p["character"]
			target_pos = p["hex_position"]
			break

	if target_char == null: return

	# Determine advantage & disadvantage based on conditions
	var has_advantage := false
	var has_disadvantage := target_char.has_condition("dodging")
	
	# Monster conditions (blinded/poisoned)
	var monster_conditions: Dictionary = monster.get("conditions", {})
	if monster_conditions.has("blinded") or monster_conditions.has("poisoned"):
		has_disadvantage = true

	# Target conditions (blinded or prone)
	if target_char.has_condition("blinded"):
		has_advantage = true
	if target_char.has_condition("prone"):
		var dist := HexUtils.get_distance(monster.get("hex_position", Vector2i.ZERO), target_pos)
		if dist == 1:
			has_advantage = true
		else:
			has_disadvantage = true

	# Roll attack
	var result := CombatAction.resolve_weapon_attack(
		# construct temporary character representing monster for simplicity
		_make_temp_monster_character(monster),
		target_char,
		attack_data,
		has_advantage,
		has_disadvantage
	)

	hud.add_log(result.get("message", "Miss!"))
	
	# Check if target died
	if not target_char.is_alive:
		hud.add_log("[color=red]%s has been knocked out![/color]" % target_char.character_name)
		if not target_char.concentrating_on.is_empty():
			_end_concentration(target_char)
	else:
		if result.get("hit", false) and result.get("damage", 0) > 0:
			_check_concentration_save(target_char, result["damage"])


func _make_temp_monster_character(m: Dictionary) -> Character:
	var c := Character.new()
	c.character_name = m["name"]
	c.ability_scores.from_dict(m.get("ability_scores", {}))
	c.proficiency_bonus = 2
	return c


func _highlight_reachable() -> void:
	var pos: Vector2i = player_entities[current_player_idx]["hex_position"]
	var reachable := hex_grid.get_reachable(pos, remaining_speed)
	
	# Don't draw A* route on active player hex
	var highlights := {}
	for hex in reachable:
		if hex == pos: continue
		highlights[hex] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.MOVEMENT]
	
	hex_grid.set_highlights(highlights)


# --- Action handlers ---

func _on_hud_action(action_type: String, extra_data: Dictionary) -> void:
	var is_free_feature := false
	if action_type == "use_feature":
		var feature: Dictionary = extra_data.get("feature", {})
		if feature.get("action_cost", "action") == "free":
			is_free_feature = true

	if has_acted_this_turn and action_type != "end_turn" and not is_free_feature:
		hud.add_log("You have already taken an action this turn!")
		return

	match action_type:
		"attack":
			pending_action_type = "attack"
			hud.add_log("Click on an enemy to Attack.")
			_highlight_attack_targets()
		"cast_spell":
			pending_action_type = "spell"
			pending_spell_data = extra_data.get("spell", {})
			var spell_name: String = pending_spell_data.get("name", "Spell")
			hud.add_log("Casting %s. Select target hex." % spell_name)
			_highlight_spell_targets()
		"use_feature":
			var feature: Dictionary = extra_data.get("feature", {})
			_execute_class_feature(feature)
		"dodge":
			active_character.add_condition("dodging", 1)
			hud.add_log("%s is dodging (Attacks against them have disadvantage)." % active_character.character_name)
			has_acted_this_turn = true
			_highlight_reachable()
		"end_turn":
			_end_active_turn()


func _highlight_attack_targets() -> void:
	hex_grid.clear_highlights()
	
	var pos: Vector2i = player_entities[current_player_idx]["hex_position"]
	var weapon_id := active_character.inventory.get_weapon()
	var weapon := DataLoader.get_item(weapon_id)
	var max_range := int(weapon.get("range", 1))

	var highlights := {}
	for m in monster_entities:
		if not m["is_alive"]: continue
		var m_pos: Vector2i = m["hex_position"]
		if Targeting.is_in_range(pos, m_pos, max_range):
			highlights[m_pos] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.ATTACK]

	hex_grid.set_highlights(highlights)


func _highlight_spell_targets() -> void:
	hex_grid.clear_highlights()
	
	var pos: Vector2i = player_entities[current_player_idx]["hex_position"]
	var max_range := int(pending_spell_data.get("range", 6))

	var highlights := {}
	# Display standard spellcasting range circles
	var area_hexes := HexUtils.get_hexes_in_range(pos, max_range)
	for hex in area_hexes:
		if hex_grid.has_tile(hex):
			highlights[hex] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.SPELL]

	hex_grid.set_highlights(highlights)


func _on_hex_clicked(coord: Vector2i) -> void:
	if current_player_idx == -1: return # Not player turn

	var player_pos: Vector2i = player_entities[current_player_idx]["hex_position"]

	if pending_action_type == "attack":
		# Attack enemy at hex
		var clicked_monster: Dictionary = {}
		for m in monster_entities:
			if m["hex_position"] == coord and m["is_alive"]:
				clicked_monster = m
				break

		if clicked_monster.is_empty():
			return # No valid monster selected

		# Enforce weapon range on execution (mirrors _highlight_attack_targets).
		var weapon_id := active_character.inventory.get_weapon()
		var weapon := DataLoader.get_item(weapon_id)
		var max_range := int(weapon.get("range", 1))
		var atk_dist := HexUtils.get_distance(player_pos, coord)
		if not Targeting.is_in_range(player_pos, coord, max_range):
			var w_name: String = weapon.get("name", weapon_id) if not weapon.is_empty() else "unarmed"
			hud.add_log("[color=red]%s is out of range of %s (distance %d, range %d).[/color]" % [clicked_monster["name"], w_name, atk_dist, max_range])
			return # out of range — do not resolve the attack

		# (weapon / weapon_id already resolved above; reused for the attack roll)
		
		# Determine advantage/disadvantage based on conditions
		var has_advantage := false
		var has_disadvantage := false
		
		# Attacker conditions
		if active_character.has_condition("blinded") or active_character.has_condition("poisoned"):
			has_disadvantage = true
		if active_character.has_condition("hidden"):
			has_advantage = true
			active_character.remove_condition("hidden") # Reveal after attacking
			hud.add_log("[color=green]%s attacks with Advantage from hiding![/color]" % active_character.character_name)

		# Target conditions (blinded or prone)
		var monster_conditions: Dictionary = clicked_monster.get("conditions", {})
		if monster_conditions.has("blinded"):
			has_advantage = true
		if monster_conditions.has("prone"):
			var dist := HexUtils.get_distance(player_pos, coord)
			if dist == 1:
				has_advantage = true
			else:
				has_disadvantage = true

		# Resolve weapon attack
		var result := CombatAction.resolve_weapon_attack(active_character, clicked_monster, weapon, has_advantage, has_disadvantage)
		
		# Check for Rogue Sneak Attack on a hit
		if result.get("hit", false) and _is_sneak_attack_valid(active_character, coord, has_advantage):
			var sa_dice := _get_sneak_attack_dice(active_character)
			var sa_damage := Dice.parse_dice_string(sa_dice)
			if result.get("crit", false):
				# Double the Sneak Attack dice on critical hit
				sa_damage += Dice.parse_dice_string(sa_dice)
			
			var hp: int = int(clicked_monster.get("current_hp", 0))
			var actual_sa_dealt := mini(sa_damage, hp)
			clicked_monster["current_hp"] = hp - actual_sa_dealt
			result["damage"] = result.get("damage", 0) + actual_sa_dealt
			result["message"] += " [color=orange]Sneak Attack! Deals +%d damage (%s).[/color]" % [actual_sa_dealt, sa_dice]
			
			active_character.feature_uses["sneak_attack_used_this_turn"] = 1

		hud.add_log(result.get("message", "Miss!"))
		
		# Check if dead
		if int(clicked_monster.get("current_hp", 0)) <= 0:
			clicked_monster["is_alive"] = false
			hud.add_log("[color=green]%s was defeated![/color]" % clicked_monster["name"])
			tracker.remove_combatant(clicked_monster["id"])

		has_acted_this_turn = true
		pending_action_type = ""
		_check_battle_end_conditions()
		_highlight_reachable()

	elif pending_action_type == "spell":
		# Cast spell at hex
		var spell_range := int(pending_spell_data.get("range", 6))
		if not Targeting.is_in_range(player_pos, coord, spell_range):
			return # out of range

		_execute_player_spell(coord)
	else:
		# Regular movement click
		var reachable := hex_grid.get_reachable(player_pos, remaining_speed)
		if coord in reachable and coord != player_pos:
			var path := hex_grid.find_path(player_pos, coord)
			var cost: float = reachable[coord]
			remaining_speed -= cost
			
			var disengaged := active_character.has_condition("disengaging")
			if not disengaged and path.size() >= 2:
				_check_opportunity_attacks_for_path(active_character, player_entities[current_player_idx], path, false)
			else:
				# Teleport normally if disengaged or path too short
				player_entities[current_player_idx]["hex_position"] = coord
			
			if active_character.is_alive:
				hud.add_log("%s moved." % active_character.character_name)
			
			_highlight_reachable()

	_update_grid_entities()


func _execute_player_spell(target_coord: Vector2i) -> void:
	# Deduct spell slot if leveled spell
	var spell_level: int = int(pending_spell_data.get("level", 0))
	if spell_level > 0:
		var slot_key := str(spell_level)
		var current_slots: int = active_character.spell_slots.get(slot_key, 0)
		if current_slots <= 0:
			hud.add_log("[color=orange]No level %d spell slots remaining![/color]" % spell_level)
			pending_action_type = ""
			_highlight_reachable()
			return
		active_character.spell_slots[slot_key] = current_slots - 1
		hud.add_log("%s expended a level %d spell slot." % [active_character.character_name, spell_level])

	var target_type: String = pending_spell_data.get("target", "single")
	var targets_list: Array = []

	if target_type == "area" or pending_spell_data.get("target") == "cone":
		var radius := int(pending_spell_data.get("area_radius", 2))
		var cone_size := int(pending_spell_data.get("cone_size", 3))
		var origin: Vector2i = player_entities[current_player_idx]["hex_position"]

		if target_type == "cone":
			targets_list = Targeting.get_cone_targets(origin, target_coord, cone_size, hex_grid)
		else:
			targets_list = Targeting.get_sphere_targets(target_coord, radius, hex_grid)
	else:
		targets_list = [target_coord]

	# If spell requires concentration, handle existing concentration
	if pending_spell_data.get("concentration", false):
		_end_concentration(active_character)
		active_character.concentrating_on = {
			"spell_id": pending_spell_data["id"],
			"effects": pending_spell_data.get("effects", []),
			"targets": []
		}

	# Apply spell to all entities in the targets list
	for target_hex in targets_list:
		# Check if player is there
		var p_target: Character = null
		for p in player_entities:
			if p["hex_position"] == target_hex and p["character"].is_alive:
				p_target = p["character"]
				break

		# Check if monster is there
		var m_target: Dictionary = {}
		for m in monster_entities:
			if m["hex_position"] == target_hex and m["is_alive"]:
				m_target = m
				break

		if p_target != null:
			var res := CombatAction.resolve_spell(active_character, p_target, pending_spell_data, false)
			hud.add_log(res.get("message", ""))
			
			if pending_spell_data.get("concentration", false):
				active_character.concentrating_on["targets"].append(p_target)
				
			_handle_spell_effects(p_target, {}, pending_spell_data)

		elif not m_target.is_empty():
			var res := CombatAction.resolve_spell(active_character, m_target, pending_spell_data, false)
			hud.add_log(res.get("message", ""))
			
			if pending_spell_data.get("concentration", false):
				active_character.concentrating_on["targets"].append(m_target)
				
			_handle_spell_effects(null, m_target, pending_spell_data)
			
			if int(m_target.get("current_hp", 0)) <= 0:
				m_target["is_alive"] = false
				hud.add_log("[color=green]%s was defeated![/color]" % m_target["name"])
				tracker.remove_combatant(m_target["id"])

	# Custom area effects like Sleep
	_handle_area_spell_effects(targets_list, pending_spell_data)

	# Finish spellcasting
	has_acted_this_turn = true
	pending_action_type = ""
	_check_battle_end_conditions()
	_highlight_reachable()


func _on_hex_hovered(coord: Vector2i) -> void:
	# Standard movement A* trace handled by state.
	# For spell casting, overlay targeting shapes (e.g. highlight AoE sphere or cone on hover)
	if pending_action_type == "spell":
		var target_type: String = pending_spell_data.get("target", "single")
		var origin: Vector2i = player_entities[current_player_idx]["hex_position"]
		var max_range := int(pending_spell_data.get("range", 6))

		if not Targeting.is_in_range(origin, coord, max_range):
			return # Out of cast range, keep default highlights

		# Recalculate range markers
		_highlight_spell_targets()
		
		# Overlay AoE area hover highlights
		var aoe_list: Array = []
		if target_type == "area":
			var radius := int(pending_spell_data.get("area_radius", 2))
			aoe_list = Targeting.get_sphere_targets(coord, radius, hex_grid)
		elif target_type == "cone":
			var cone_size := int(pending_spell_data.get("cone_size", 3))
			aoe_list = Targeting.get_cone_targets(origin, coord, cone_size, hex_grid)

		for hex in aoe_list:
			hex_grid.add_highlight(hex, HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.SPELL])


func _end_active_turn() -> void:
	# Resolve victory/defeat before advancing the turn order. This is the
	# chokepoint for both player and monster turns, so a monster wiping the
	# last standing player (or any death during turn-start) is caught here.
	if _check_battle_end_conditions():
		return

	# Tick active conditions at turn end
	if active_combatant["is_player"] and active_character != null:
		active_character.tick_conditions()
	elif not active_combatant["is_player"] and not active_combatant.is_empty():
		var monster: Dictionary = active_combatant["entity"]
		_tick_monster_condition_durations(monster)

	var round_complete := tracker.next_turn()
	_start_combat_turn()


func _tick_monster_condition_durations(monster: Dictionary) -> void:
	var conditions: Dictionary = monster.get("conditions", {})
	if conditions.is_empty(): return
	var expired: Array[String] = []
	for cond in conditions:
		conditions[cond] -= 1
		if conditions[cond] <= 0:
			expired.append(cond)
	for cond in expired:
		conditions.erase(cond)


func _check_battle_end_conditions() -> bool:
	# If a battle-end was already triggered, don't trigger it again.
	if _battle_ending:
		return true

	# Check if all monsters dead
	var monsters_alive := false
	for m in monster_entities:
		if m["is_alive"]:
			monsters_alive = true
			break

	if not monsters_alive:
		_battle_ending = true
		hud.add_log("[color=green]VICTORY! All monsters defeated.[/color]")
		# Register defeated monsters
		for m in monster_entities:
			GameManager.defeated_monsters.append(m["monster_id"])
		_end_battle("victory")
		return true

	# Check if all players dead (TPK / party wipe)
	var players_alive := false
	for p in player_entities:
		var c: Character = p.get("character")
		if c != null and c.is_alive:
			players_alive = true
			break

	if not players_alive:
		_battle_ending = true
		hud.add_log("[color=red]DEFEAT! TPK - Entire party was wiped.[/color]")
		_end_battle("defeat")
		return true

	return false


func _end_battle(result: String) -> void:
	set_process_input(false)
	# Display victory/defeat pop-up and return
	await get_tree().create_timer(2.0).timeout
	GameManager.exit_combat(result)


func _execute_class_feature(feature: Dictionary) -> void:
	var f_id: String = feature.get("id", "")
	
	if not active_character.use_feature(f_id):
		hud.add_log("You have no uses of %s remaining!" % feature.get("name", f_id))
		return

	hud.add_log("[color=cyan]%s uses class feature: %s![/color]" % [active_character.character_name, feature.get("name", f_id)])

	var effects: Array = feature.get("effects", [])
	var cost_type: String = feature.get("action_cost", "action")

	for effect in effects:
		var type: String = effect.get("type", "")
		match type:
			"grant_extra_action":
				has_acted_this_turn = false
				hud.add_log("[color=green]%s gains an additional action this turn![/color]" % active_character.character_name)
			"cunning_dash":
				remaining_speed += active_character.speed
				hud.add_log("[color=green]%s uses Cunning Action: Dash! Speed doubled to %.1f.[/color]" % [active_character.character_name, remaining_speed])
			"cunning_disengage":
				active_character.add_condition("disengaging", 1)
				hud.add_log("[color=green]%s uses Cunning Action: Disengage! Opportunity attacks against them are disabled this turn.[/color]" % active_character.character_name)
			"cunning_hide":
				# Roll stealth check vs passive perception of monsters (or standard DC)
				var roll := Dice.roll(20)
				var dex_mod := active_character.ability_scores.get_ability_modifier("DEX")
				var stealth_bonus := dex_mod
				if "Stealth" in active_character.skill_proficiencies:
					stealth_bonus += active_character.proficiency_bonus
				var total := roll + stealth_bonus
				
				# Check vs typical passive perception (e.g. DC 12)
				var dc := 12
				var success := total >= dc
				if success:
					active_character.add_condition("hidden", 1)
					hud.add_log("[color=green]%s uses Cunning Action: Hide! Stealth check: %d (Roll %d + %d bonus) vs DC %d. SUCCESS! They are now hidden.[/color]" % [active_character.character_name, total, roll, stealth_bonus, dc])
				else:
					hud.add_log("[color=yellow]%s uses Cunning Action: Hide! Stealth check: %d (Roll %d + %d bonus) vs DC %d. FAILED! They failed to hide.[/color]" % [active_character.character_name, total, roll, stealth_bonus, dc])
			"recover_spell_slots":
				_recover_wizard_spell_slots(active_character)
			_:
				var res := EventResolver.apply_effects(active_character, [effect])
				for r in res:
					hud.add_log(r.get("message", ""))

	if cost_type == "action":
		has_acted_this_turn = true

	hud.update_hud(active_character, tracker)
	_highlight_reachable()


func _is_sneak_attack_valid(attacker: Character, target_coord: Vector2i, has_advantage: bool) -> bool:
	if not attacker.has_feature("sneak_attack"):
		return false
		
	if attacker.feature_uses.get("sneak_attack_used_this_turn", 0) > 0:
		return false

	var has_ally_adjacent := false
	for p in player_entities:
		if p["character"] == attacker: continue
		if p["character"].is_alive and HexUtils.get_distance(p["hex_position"], target_coord) == 1:
			has_ally_adjacent = true
			break
			
	return has_advantage or has_ally_adjacent


func _get_sneak_attack_dice(attacker: Character) -> String:
	var dice := "1d6"
	for f in attacker.features:
		var effects = f.get("effects", [])
		for eff in effects:
			if eff.get("type", "") in ["sneak_attack", "sneak_attack_upgrade"]:
				dice = eff.get("dice", dice)
	return dice


func _end_concentration(caster: Character) -> void:
	if caster.concentrating_on.is_empty(): return
	
	var spell_id: String = caster.concentrating_on["spell_id"]
	var targets: Array = caster.concentrating_on["targets"]
	hud.add_log("[color=yellow]%s's concentration on %s ends.[/color]" % [caster.character_name, DataLoader.get_spell(spell_id).get("name", spell_id)])
	
	# Remove conditions applied by this spell
	var effects: Array = caster.concentrating_on.get("effects", [])
	for target in targets:
		for effect in effects:
			if effect.get("type", "") == "grant_condition":
				var cond = effect.get("condition", "")
				if target is Character:
					target.remove_condition(cond)
				elif target is Dictionary:
					target.get("conditions", {}).erase(cond)
					
	caster.concentrating_on.clear()


func _check_concentration_save(character: Character, damage_taken: int) -> void:
	if damage_taken <= 0 or character.concentrating_on.is_empty(): return
	
	var dc: int = max(10, int(floor(float(damage_taken) / 2.0)))
	var roll := character.make_saving_throw("CON")
	var success: bool = roll >= dc
	
	hud.add_log("%s makes a CON save to maintain concentration: %d vs DC %d." % [character.character_name, roll, dc])
	if success:
		hud.add_log("[color=green]%s maintained concentration![/color]" % character.character_name)
	else:
		hud.add_log("[color=red]%s failed CON save! Concentration lost.[/color]" % character.character_name)
		_end_concentration(character)


func _handle_spell_effects(p_target: Character = null, m_target: Dictionary = {}, spell_data: Dictionary = {}) -> void:
	var effects: Array = spell_data.get("effects", [])
	for effect in effects:
		var type: String = effect.get("type", "")
		match type:
			"grant_condition":
				var cond = effect.get("condition", "")
				var dur = int(effect.get("duration", 3))
				if p_target != null:
					p_target.add_condition(cond, dur)
					hud.add_log("[color=green]%s is now %s for %d turns![/color]" % [p_target.character_name, cond, dur])
				elif m_target != null:
					m_target["conditions"][cond] = dur
					hud.add_log("[color=green]%s is now %s for %d turns![/color]" % [m_target["name"], cond, dur])
			"ac_bonus":
				var val = int(effect.get("value", 5))
				var dur = int(effect.get("duration", 1))
				if p_target != null:
					p_target.add_condition("shield", dur)
					hud.add_log("[color=green]%s is protected by a magical barrier (+5 AC)![/color]" % p_target.character_name)
			"set_base_ac":
				var val = int(effect.get("value", 13))
				if p_target != null:
					p_target.add_condition("mage_armor", 99)
					hud.add_log("[color=green]%s's AC is set to 13 + DEX from Mage Armor![/color]" % p_target.character_name)


func _handle_area_spell_effects(targets_list: Array, spell_data: Dictionary) -> void:
	var effects: Array = spell_data.get("effects", [])
	for effect in effects:
		var type: String = effect.get("type", "")
		match type:
			"sleep":
				var hp_pool_str: String = effect.get("hp_pool", "5d8")
				var hp_pool := Dice.parse_dice_string(hp_pool_str)
				hud.add_log("[color=purple]Sleep spell rolled an HP pool of %d![/color]" % hp_pool)
				
				var candidates: Array = []
				for target_hex in targets_list:
					for p in player_entities:
						if p["hex_position"] == target_hex and p["character"].is_alive:
							candidates.append({"type": "player", "entity": p["character"], "hp": p["character"].current_hp})
					for m in monster_entities:
						if m["hex_position"] == target_hex and m["is_alive"]:
							candidates.append({"type": "monster", "entity": m, "hp": m["current_hp"]})
							
				candidates.sort_custom(func(a, b): return a["hp"] < b["hp"])
				
				for cand in candidates:
					var hp = cand["hp"]
					if hp_pool >= hp:
						hp_pool -= hp
						if cand["type"] == "player":
							cand["entity"].add_condition("stunned", 10)
							hud.add_log("[color=purple]%s fell into a magical slumber![/color]" % cand["entity"].character_name)
						else:
							cand["entity"]["conditions"]["stunned"] = 10
							hud.add_log("[color=purple]%s fell into a magical slumber![/color]" % cand["entity"]["name"])
					else:
						break


func _recover_wizard_spell_slots(character: Character) -> void:
	var max_recovery_levels := int(ceil(float(character.level) / 2.0))
	var recovered_slots: Array[String] = []
	
	var class_data := DataLoader.get_character_class(character.class_id)
	var slot_table: Dictionary = class_data.get("spell_slots_by_level", {})
	var level_key := str(character.level)
	if not level_key in slot_table:
		return
		
	var max_slots: Dictionary = slot_table[level_key]
	
	var remaining_recovery_levels := max_recovery_levels
	var slot_levels := max_slots.keys()
	slot_levels.sort_custom(func(a, b): return int(a) > int(b))
	
	for slot_lvl_str in slot_levels:
		var slot_lvl := int(slot_lvl_str)
		if slot_lvl > 5: continue
		
		var max_qty: int = int(max_slots[slot_lvl_str])
		var current_qty: int = character.spell_slots.get(slot_lvl_str, 0)
		var expended := max_qty - current_qty
		
		while expended > 0 and remaining_recovery_levels >= slot_lvl:
			character.spell_slots[slot_lvl_str] = character.spell_slots.get(slot_lvl_str, 0) + 1
			remaining_recovery_levels -= slot_lvl
			expended -= 1
			recovered_slots.append("Level %d" % slot_lvl)
	
	if recovered_slots.is_empty():
		hud.add_log("No spell slots needed recovery.")
	else:
		hud.add_log("[color=green]%s recovered spell slots: %s[/color]" % [character.character_name, ", ".join(recovered_slots)])


func _check_opportunity_attacks_for_path(entity, entity_dict: Dictionary, path: Array, is_entity_monster: bool) -> void:
	if path.size() < 2: return
	
	for k in range(path.size() - 1):
		var from_hex: Vector2i = path[k]
		var to_hex: Vector2i = path[k+1]
		
		# Move entity_dict hex_position step-by-step
		entity_dict["hex_position"] = to_hex
		
		if is_entity_monster:
			# Monster is moving. Check players who can make opportunity attacks.
			for p in player_entities:
				var char_data: Character = p["character"]
				if char_data == null or not char_data.is_alive: continue
				if not p.get("reaction_available", true): continue
				if char_data.has_condition("stunned"): continue
				
				# Check if player was adjacent at from_hex and is no longer adjacent at to_hex
				var dist_from := HexUtils.get_distance(p["hex_position"], from_hex)
				var dist_to := HexUtils.get_distance(p["hex_position"], to_hex)
				if dist_from == 1 and dist_to > 1:
					p["reaction_available"] = false
					hud.add_log("[color=yellow]%s makes an Opportunity Attack against %s![/color]" % [char_data.character_name, entity_dict["name"]])
					
					var weapon_id := char_data.inventory.get_weapon()
					var weapon := DataLoader.get_item(weapon_id)
					var result := CombatAction.resolve_weapon_attack(char_data, entity_dict, weapon)
					hud.add_log(result.get("message", "Miss!"))
					
					if int(entity_dict.get("current_hp", 0)) <= 0:
						entity_dict["is_alive"] = false
						hud.add_log("[color=green]%s was defeated by opportunity attack![/color]" % entity_dict["name"])
						tracker.remove_combatant(entity_dict["id"])
						entity_dict["hex_position"] = from_hex # Stops at from_hex
						return
		else:
			# Player is moving. Check monsters who can make opportunity attacks.
			for m in monster_entities:
				if not m["is_alive"]: continue
				if not m.get("reaction_available", true): continue
				if m.get("conditions", {}).has("stunned"): continue
				
				# Check if monster was adjacent at from_hex and is no longer adjacent at to_hex
				var dist_from := HexUtils.get_distance(m["hex_position"], from_hex)
				var dist_to := HexUtils.get_distance(m["hex_position"], to_hex)
				if dist_from == 1 and dist_to > 1:
					m["reaction_available"] = false
					hud.add_log("[color=red]%s makes an Opportunity Attack against %s![/color]" % [m["name"], entity.character_name])
					
					var attack_data = m["attacks"][0]
					var result := CombatAction.resolve_weapon_attack(_make_temp_monster_character(m), entity, attack_data)
					hud.add_log(result.get("message", "Miss!"))
					
					if not entity.is_alive:
						hud.add_log("[color=red]%s was knocked out by opportunity attack![/color]" % entity.character_name)
						entity_dict["hex_position"] = from_hex # Stops at from_hex
						_end_concentration(entity)
						return
