## Combat State Controller
## Manages tactical round initiative, player actions, enemy AI turns, and win/lose checks.
class_name CombatState
extends Node2D

@onready var hex_grid: HexGrid = $HexGrid
@onready var hud: CombatHUD = $CombatHUD
@onready var cam: Camera2D = $Camera2D
@onready var fx_layer: Node2D = $FxLayer


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
var turn_budget: CombatTurnBudget = CombatTurnBudget.new()

# Targeting action mode
var pending_action_type: String = "" # "attack", "spell", "lay_on_hands", "bardic_inspiration", "unarmed_attack"
var pending_spell_data: Dictionary = {}
var pending_feature_data: Dictionary = {}

# Guards against double-triggering battle end (victory/defeat).
var _battle_ending := false

# Last computed enemy intent preview text (drawn above monster tokens).
var _intent_preview: String = ""

# Hexes currently showing the move-path preview (cleared before redraw).
var _path_preview_hexes: Array[Vector2i] = []

# Whether the first-turn hint has been shown (show once per battle).
var _hint_shown := false

# A disconnected controller keeps ownership of its current combatant. The
# turn waits in place until that stable seat is rebound.
var _waiting_for_owner_rebind := false
var _rebind_wait_before_turn_setup := false


func _ready() -> void:
	# Connect HUD action selectors
	hud.action_selected.connect(_on_hud_action)
	hud.cancel_pressed.connect(_cancel_pending_action)
	hud.settings_pressed.connect(func(): Settings.open_settings(self))
	hud.sheet_pressed.connect(_on_sheet_pressed)
	PlayerManager.device_binding_changed.connect(_on_device_binding_changed)
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


func _on_sheet_pressed() -> void:
	# Resolve the character when the button is pressed. A connection-time
	# closure would capture the null pre-turn value from _ready().
	CharacterSheet.show_sheet(active_character)


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


## --- Combat feedback / juice -------------------------------------------
## Spawn a floating combat-text label at a hex (damage numbers, misses, crits).
## Gated by Settings.show_damage_numbers (a toggle in the settings overlay).
func _spawn_floating_text(coord: Vector2i, text: String, color: Color) -> void:
	if not Settings.show_damage_numbers:
		return
	if fx_layer == null:
		return
	var center := HexUtils.hex_to_pixel(coord)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 22)
	label.position = center - Vector2(0, 24)
	label.z_index = 100
	fx_layer.add_child(label)
	# Pop + float up + fade. No await on the main beat (tween is fire-and-forget).
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", center.y - 64.0, 0.9).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "scale", Vector2(1.25, 1.25), 0.15).from(Vector2(0.6, 0.6))
	tween.chain().tween_callback(label.queue_free)

## Brief camera shake on impact. Gated by Settings.screen_shake.
func _shake_camera(intensity: float = 6.0) -> void:
	if not Settings.screen_shake:
		return
	if cam == null:
		return
	var base := Vector2(640, 360)
	var tween := create_tween()
	for i in 5:
		var off := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(cam, "position", base + off, 0.04)
	tween.tween_property(cam, "position", base, 0.06)

## Flash a hex's occupant by briefly re-highlighting it (cheap hit feedback).
func _flash_hex(coord: Vector2i, color: Color) -> void:
	if hex_grid == null:
		return
	hex_grid.add_highlight(coord, color)
	await get_tree().create_timer(0.12).timeout
	hex_grid.clear_highlights()
	# Restore any action-specific highlights for the active player.
	if pending_action_type == "attack":
		_highlight_attack_targets()
	elif pending_action_type == "spell":
		_highlight_spell_targets()
	else:
		_highlight_reachable()


## Build a human-readable intent string for a monster's planned action.
func _describe_intent(monster: Dictionary, intent: Dictionary) -> String:
	if intent.is_empty():
		return ""
	var action: String = intent.get("action", "none")
	match action:
		"attack", "move_attack":
			var tid: String = intent.get("target_id", "?")
			if action == "move_attack":
				return "Move + Attack %s" % tid
			return "Attack %s" % tid
		"move":
			return "Move"
		"none":
			return "Hold"
		_:
			return action.capitalize()
	return ""


func _setup_combat_players() -> void:
	player_entities = []
	var active_members := PartyManager.get_active_party_members()
	if not active_members.is_empty():
		for i in active_members.size():
			var member: Dictionary = active_members[i]
			var member_character: Character = member["character"]
			var owner_index := int(member.get("owner_player_index", -1))
			player_entities.append({
				"name": member_character.character_name,
				"display_name": member_character.character_name,
				"player_id": i,
				"owner_player_index": owner_index,
				"party_slot_id": member.get("slot_id", ""),
				"is_companion": bool(member.get("is_companion", false)),
				"character": member_character,
				"is_alive": member_character.is_alive,
				"color": PlayerManager.get_player(owner_index).get("color", Color.WHITE) if owner_index >= 0 else Color.WHITE,
			})
	else:
		for p in PlayerManager.players:
			player_entities.append(p.duplicate())
	var player_count := player_entities.size()
	
	# Spawn players on the left side of the tactical grid using the party's
	# validated composition rather than encounter-local character assumptions.
	var spawn_points := PartyManager.get_formation_positions(player_count)
	
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
			"spells": base_monster.get("spells", []).duplicate(true),
			"spell_slots": base_monster.get("spell_slots", {}).duplicate(true),
			"damage_immunities": base_monster.get("damage_immunities", []).duplicate(true),
			"condition_immunities": base_monster.get("condition_immunities", []).duplicate(true),
			"saving_throw_bonuses": base_monster.get("saving_throw_bonuses", {}).duplicate(true),
			"special_abilities": base_monster.get("special_abilities", []).duplicate(true),
			"loot_table": base_monster.get("loot_table", []).duplicate(true),
			"is_boss": bool(base_monster.get("is_boss", false)),
			"creature_type": str(base_monster.get("creature_type", "")),
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
		var owner_index := int(p.get("owner_player_index", -1))
		var turn_name := char_data.character_name
		if owner_index >= 0:
			turn_name += " [Seat %d]" % (owner_index + 1)

		tracker.add_combatant(
			"player_%d" % i,
			turn_name,
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
	_clear_path_preview()

	var is_player: bool = active_combatant["is_player"]
	if is_player:
		# Player Turn
		active_character = active_combatant["entity"]
		current_player_idx = -1
		for i in player_entities.size():
			if player_entities[i]["character"] == active_character:
				current_player_idx = i
				break
		if not active_character.is_alive:
			hud.add_log("[color=gray]%s is knocked out and skips their turn.[/color]" % active_character.character_name)
			await get_tree().create_timer(1.0).timeout
			_end_active_turn()
			return
		var owner_index := _get_current_owner_index()
		if owner_index >= 0 and not PlayerManager.is_player_connected(owner_index):
			_wait_for_owner_rebind(owner_index, true)
			return

		# Process turn-start condition effects (like poison)
		if active_character.has_condition("poisoned"):
			var dmg := Dice.roll(4) # 1d4 poison damage
			var actual := active_character.take_damage(dmg)
			hud.add_log("[color=red]%s took %d poison damage from being poisoned![/color]" % [active_character.character_name, actual])
			var ppos: Vector2i = player_entities[current_player_idx]["hex_position"]
			_spawn_floating_text(ppos, "-%d" % actual, Color(0.3, 1.0, 0.3))
			_flash_hex(ppos, Color(0.3, 1.0, 0.3, 0.5))
			if not active_character.is_alive:
				hud.add_log("[color=red]%s was knocked out by poison![/color]" % active_character.character_name)
				await get_tree().create_timer(1.0).timeout
				_end_active_turn()
				return

		# Check turn-blocking conditions
		if active_character.has_condition("stunned") or active_character.has_condition("paralyzed"):
			var blocked_condition := "Paralyzed" if active_character.has_condition("paralyzed") else "Stunned"
			hud.add_log("[color=orange]%s is %s and skips their turn.[/color]" % [active_character.character_name, blocked_condition])
			await get_tree().create_timer(1.0).timeout
			_end_active_turn()
			return

		var speed_val := float(active_character.get_speed())
		if active_character.has_condition("prone"):
			speed_val /= 2.0
		remaining_speed = speed_val
		_reset_turn_action_economy()
		
		# Reset once-per-turn features/restrictions for this player
		for feature in active_character.features:
			if feature.get("uses_per", "") == "turn":
				active_character.feature_uses[feature.get("id", "")] = feature.get("uses", 1)
		if active_character.has_feature("barbarian_reckless_attack"):
			active_character.feature_uses["barbarian_reckless_attack_used_this_turn"] = 0
			active_character.remove_condition("reckless_attack")
		active_character.feature_uses.erase("paladin_divine_sense_targets")
		if active_character.has_feature("ranger_favored_foe"):
			active_character.feature_uses["ranger_favored_foe_used_this_turn"] = 0
		if active_character.has_feature("sneak_attack"):
			active_character.feature_uses["sneak_attack_used_this_turn"] = 0
		
		hud.update_hud(active_character, tracker)
		hud.set_controls_disabled(false)
		hud.add_log("[color=yellow]=== Turn: %s (Player) ===[/color]" % active_character.character_name)
		# First-turn contextual hint (P1 readability), shown once per battle.
		if not _hint_shown:
			_hint_shown = true
			hud.show_hint("Your turn. Click a highlighted hex to move (path previews on hover). Click Attack to strike in range — red hexes show your reach. Enemies show their intent above their token.")
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

		# --- Enemy intent preview (P1 readability) ---
		# Compute the monster's planned action from current state and surface it
		# above the token so the player can read what's coming.
		var monster_coord: Vector2i = monster.get("hex_position", Vector2i.ZERO)
		var intent := AIController.get_monster_action(monster, monster_coord, hex_grid, player_entities)
		monster["intent"] = intent
		_intent_preview = _describe_intent(monster, intent)
		monster["intent_text"] = _intent_preview
		# Re-draw so the badge appears immediately.
		hex_grid.queue_redraw()
		_update_grid_entities()

		await get_tree().create_timer(1.0).timeout
		_run_monster_ai()


func _get_current_owner_index() -> int:
	if current_player_idx < 0 or current_player_idx >= player_entities.size():
		return -1
	return int(player_entities[current_player_idx].get("owner_player_index", -1))


func _wait_for_owner_rebind(owner_index: int, before_turn_setup: bool) -> void:
	_waiting_for_owner_rebind = true
	_rebind_wait_before_turn_setup = before_turn_setup
	hud.set_controls_disabled(true)
	hex_grid.clear_highlights()
	_clear_path_preview()
	hud.add_log("[color=orange]Seat %d disconnected. Reconnect the controller or press Start to reclaim this turn.[/color]" % (owner_index + 1))


func _on_device_binding_changed(player_index: int, _device_id: int, connected: bool) -> void:
	if _battle_ending or active_combatant.is_empty() or not bool(active_combatant.get("is_player", false)):
		return
	if player_index != _get_current_owner_index():
		return
	if not connected:
		_wait_for_owner_rebind(player_index, false)
		return
	if not _waiting_for_owner_rebind:
		return
	var resume_before_setup := _rebind_wait_before_turn_setup
	_waiting_for_owner_rebind = false
	_rebind_wait_before_turn_setup = false
	hud.add_log("[color=green]Seat %d reconnected.[/color]" % (player_index + 1))
	if resume_before_setup:
		_start_combat_turn()
	else:
		hud.set_controls_disabled(false)
		if pending_action_type == "attack":
			_highlight_attack_targets()
		elif pending_action_type == "spell":
			_highlight_spell_targets()
		else:
			_highlight_reachable()


func _run_monster_ai() -> void:
	var monster: Dictionary = active_combatant["entity"]
	var monster_coord: Vector2i = monster.get("hex_position", Vector2i.ZERO)
	
	# Get AI decision
	var decision := AIController.get_monster_action(monster, monster_coord, hex_grid, player_entities)
	var command := AICommand.from_decision(decision, monster, player_entities, hex_grid)
	if command == null:
		hud.add_log("%s holds: invalid AI action was rejected." % monster["name"])
		_update_grid_entities()
		await get_tree().create_timer(1.2).timeout
		_end_active_turn()
		return
	var action_str: String = command.action_type

	match action_str:
		"move":
			var dest: Vector2i = command.move_to()
			var path := [monster_coord, dest]
			await _check_opportunity_attacks_for_path(null, monster, path, true)
			if monster["is_alive"]:
				hud.add_log("%s moved closer." % monster["name"])
		"attack":
			var target_name: String = command.target_id()
			var attack_idx: int = command.attack_idx()
			await _execute_monster_attack(monster, target_name, attack_idx)
		"cast_spell":
			await _execute_monster_spell(monster, command.target_id(), command.spell_id())
		"move_attack":
			# Move
			var dest: Vector2i = command.move_to()
			var path := [monster_coord, dest]
			await _check_opportunity_attacks_for_path(null, monster, path, true)
			if monster["is_alive"]:
				# Attack
				var target_name: String = command.target_id()
				var attack_idx: int = command.attack_idx()
				hud.add_log("%s moved and attacked!" % monster["name"])
				await _execute_monster_attack(monster, target_name, attack_idx)
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
	if target_char.has_condition("reckless_attack"):
		has_advantage = true
	if target_char.has_condition("prone"):
		var dist := HexUtils.get_distance(monster.get("hex_position", Vector2i.ZERO), target_pos)
		if dist == 1:
				has_advantage = true
		else:
				has_disadvantage = true

	var reaction_decisions := await _collect_reaction_decisions(target_char)

	# Roll attack
	var result := CombatAction.resolve_weapon_attack(
		# construct temporary character representing monster for simplicity
		_make_temp_monster_character(monster),
		target_char,
		attack_data,
		has_advantage,
		has_disadvantage,
		reaction_decisions
	)
	var rider_results := CombatAction.resolve_monster_attack_effects(monster, target_char, attack_data, result)
	for rider in rider_results:
		hud.add_log("[color=orange]%s[/color]" % rider.get("message", "Monster effect resolved."))
		result["damage"] = int(result.get("damage", 0)) + int(rider.get("damage", 0))

	hud.add_log(result.get("message", "Miss!"))

	# --- Feedback / juice ---
	var m_dmg: int = int(result.get("damage", 0))
	if result.get("hit", false) and m_dmg > 0:
		var m_crit: bool = result.get("crit", false)
		var m_color := Color.GOLD if m_crit else Color(1.0, 0.3, 0.3)
		var m_txt := ("CRIT %d!" % m_dmg) if m_crit else ("-%d" % m_dmg)
		_spawn_floating_text(target_pos, m_txt, m_color)
		_shake_camera(9.0 if m_crit else 5.0)
		_flash_hex(target_pos, Color(1.0, 0.3, 0.3, 0.6))
	else:
		_spawn_floating_text(target_pos, "Miss", Color(0.7, 0.7, 0.7, 0.9))
	# ---

	# Check if target died
	if not target_char.is_alive:
		hud.add_log("[color=red]%s has been knocked out![/color]" % target_char.character_name)
		if not target_char.concentrating_on.is_empty():
			_end_concentration(target_char)
	else:
		if result.get("hit", false) and result.get("damage", 0) > 0:
			_check_concentration_save(target_char, result["damage"])


func _make_monster_spellcaster(monster: Dictionary) -> Character:
	var caster := _make_temp_monster_character(monster)
	caster.class_id = "wizard"
	caster.level = maxi(1, int(monster.get("spellcaster_level", 8)))
	caster.known_spells.clear()
	for known in monster.get("spells", []):
		var spell_id := str(known.get("id", ""))
		if not spell_id.is_empty():
			caster.known_spells.append(spell_id)
	caster.spell_slots = monster.get("spell_slots", {}).duplicate(true)
	return caster


func _execute_monster_spell(monster: Dictionary, target_player_name: String, spell_id: String) -> void:
	var target_char: Character = null
	var target_pos := Vector2i.ZERO
	for p in player_entities:
		if p["character"].character_name == target_player_name:
			target_char = p["character"]
			target_pos = p["hex_position"]
			break
	if target_char == null or not target_char.is_alive:
		return
	var spell_data: Dictionary = DataLoader.get_spell(spell_id)
	var caster := _make_monster_spellcaster(monster)
	var counterspell_context := await _collect_counterspell_decisions(caster)
	var result := CombatAction.resolve_spell(caster, target_char, spell_data, true, counterspell_context.get("decisions", {}), counterspell_context.get("observers", []))
	hud.add_log(result.get("message", "%s's spell failed." % monster.get("name", "Monster")))
	var damage := int(result.get("damage", 0))
	if result.get("success", false) and damage > 0:
		_spawn_floating_text(target_pos, "-%d" % damage, Color(0.8, 0.3, 1.0))
		_flash_hex(target_pos, Color(0.7, 0.2, 1.0, 0.6))
		_check_concentration_save(target_char, damage)
	if not target_char.is_alive:
		hud.add_log("[color=red]%s was knocked out by %s's spell![/color]" % [target_char.character_name, monster.get("name", "Monster")])


func _collect_reaction_decisions(target: Character) -> Dictionary:
	var decisions: Dictionary = {}
	if target == null:
		return decisions
	var owner_label := target.character_name
	for player_entity in player_entities:
		if player_entity.get("character") != target:
			continue
		var owner_index := int(player_entity.get("owner_player_index", -1))
		owner_label = "Seat %d - %s" % [owner_index + 1, target.character_name] if owner_index >= 0 else target.character_name
		break
	if target.reaction_available and (target.has_feature("uncanny_dodge") or target.has_feature("rogue_uncanny_dodge")):
		decisions["uncanny_dodge"] = await hud.request_reaction(owner_label, "uncanny_dodge", "Halve the incoming weapon damage.")
	if target.reaction_available and "shield" in target.known_spells and target.spell_slots.get("1", 0) > 0:
		decisions["shield"] = await hud.request_reaction(owner_label, "shield", "Add the Shield spell's AC bonus before the attack resolves.")
	return decisions


func _collect_counterspell_decisions(caster: Character) -> Dictionary:
	var decisions: Dictionary = {}
	var observers: Array[Character] = []
	if caster == null:
		return {"decisions": decisions, "observers": observers}
	for player_entity in player_entities:
		var observer: Character = player_entity.get("character")
		if observer == null or observer == caster or not observer.is_alive:
			continue
		if not observer.reaction_available or "counterspell" not in observer.known_spells or observer.spell_slots.get("3", 0) <= 0:
			continue
		observers.append(observer)
		var observer_key := "counterspell:%s" % observer.character_name
		decisions[observer_key] = await hud.request_reaction(_owner_label_for_character(observer), "counterspell", "Interrupt %s's spell before it resolves." % caster.character_name)
		if decisions[observer_key]:
			break
	return {"decisions": decisions, "observers": observers}


func _make_temp_monster_character(m: Dictionary) -> Character:
	var c := Character.new()
	c.character_name = m["name"]
	c.ability_scores.from_dict(m.get("ability_scores", {}))
	c.proficiency_bonus = 2
	return c


func _highlight_reachable() -> void:
	_clear_path_preview()
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
	var command := CombatCommand.from_hud_for_character(action_type, extra_data, active_character)
	if command == null:
		hud.add_log("Invalid combat action.")
		return
	action_type = command.action_type
	extra_data = command.payload
	var cost_type := _action_cost_for_command(action_type, extra_data)
	if not _can_spend_action_cost(cost_type) and action_type not in ["end_turn", "cancel", "move"]:
		hud.add_log("You have no %s available this turn." % cost_type.replace("_", " "))
		return

	# Dismiss the first-turn hint once the player acts.
	hud.hide_hint()

	match action_type:
		"cancel":
			_cancel_pending_action()
			return
		"attack":
			pending_action_type = "attack"
			hud.add_log("Click on an enemy to Attack.")
			_highlight_attack_targets()
		"cast_spell":
			var spell_info: Dictionary = extra_data.get("spell", {})
			if str(spell_info.get("casting_time", "action")) == "reaction":
				hud.add_log("That spell is reaction-only and is offered when its trigger occurs.")
				return
			var spell_lvl: int = int(spell_info.get("level", 0))
			if spell_lvl > 0 and active_character != null:
				var slot_key := str(CombatAction.get_spell_slot_level(active_character, spell_info))
				if active_character.spell_slots.get(slot_key, 0) <= 0:
					hud.add_log("[color=orange]No level %s spell slots remaining for %s.[/color]" % [slot_key, spell_info.get("name", "this spell")])
					return
			pending_action_type = "spell"
			pending_spell_data = spell_info
			var spell_name: String = pending_spell_data.get("name", "Spell")
			hud.add_log("Casting %s. Select target hex." % spell_name)
			_highlight_spell_targets()
		"use_feature":
			var feature: Dictionary = extra_data.get("feature", {})
			if feature.get("id", "") == "bard_bardic_inspiration":
				pending_action_type = "bardic_inspiration"
				pending_feature_data = feature
				hud.add_log("Bardic Inspiration: select another ally within range.")
				_highlight_bardic_inspiration_targets()
				return
			if feature.get("id", "") == "paladin_lay_on_hands":
				pending_action_type = "lay_on_hands"
				pending_feature_data = feature
				hud.add_log("Lay on Hands: select an ally within touch range.")
				_highlight_lay_on_hands_targets()
				return
			if feature.get("id", "") in ["monk_martial_arts", "monk_bonus_unarmed_strike", "monk_flurry_of_blows"]:
				if not turn_budget.has_acted_this_turn:
					hud.add_log("Take the Attack action before making a Bonus Unarmed Strike.")
					return
				pending_action_type = "unarmed_attack"
				pending_feature_data = feature
				var unarmed_label := "Flurry of Blows" if feature.get("id", "") == "monk_flurry_of_blows" else "Bonus Unarmed Strike"
				hud.add_log("%s: select an adjacent enemy." % unarmed_label)
				_highlight_unarmed_targets()
				return
			_execute_class_feature(feature)
		"use_item":
			var item: Dictionary = extra_data.get("item", {})
			_execute_item(item)
		"dodge":
			pending_action_type = ""
			active_character.add_condition("dodging", 1)
			hud.add_log("%s is dodging (Attacks against them have disadvantage)." % active_character.character_name)
			_spend_action_cost("action")
			_highlight_reachable()
		"end_turn":
			_end_active_turn()


## Cancel any in-progress targeting (attack/spell) and return to movement.
## Bound to the HUD Cancel button and the Esc key so the player is never
## trapped in targeting mode with no way back to movement.
func _cancel_pending_action() -> void:
	if pending_action_type.is_empty():
		return
	var old := pending_action_type
	pending_action_type = ""
	pending_spell_data = {}
	pending_feature_data = {}
	hex_grid.clear_highlights()
	_clear_path_preview()
	_highlight_reachable()
	hud.hide_dice()
	hud.add_log("[color=yellow]Cancelled %s targeting.[/color]" % old)


func _clear_path_preview() -> void:
	for h in _path_preview_hexes:
		hex_grid.clear_highlight(h)
	_path_preview_hexes.clear()


func _highlight_attack_targets() -> void:
	_clear_path_preview()
	hex_grid.clear_highlights()
	
	var pos: Vector2i = player_entities[current_player_idx]["hex_position"]
	var weapon_id := active_character.inventory.get_weapon()
	var weapon := DataLoader.get_item(weapon_id)
	var max_range := int(weapon.get("range", 1))

	var highlights := {}
	# Show the weapon's reach as a ring of highlighted hexes (P1 readability),
	# so the player can see engagement range at a glance.
	if max_range >= 1:
		var ring := HexUtils.get_hexes_in_range(pos, max_range)
		for h in ring:
			if h == pos: continue
			# Subtle fill for range; targets keep the brighter attack color below.
			highlights[h] = Color(0.35, 0.07, 0.07, 0.35)
	for m in monster_entities:
		if not m["is_alive"]: continue
		var m_pos: Vector2i = m["hex_position"]
		if Targeting.is_in_range(pos, m_pos, max_range):
			highlights[m_pos] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.ATTACK]

	hex_grid.set_highlights(highlights)


func _highlight_spell_targets() -> void:
	hex_grid.clear_highlights()
	
	var pos: Vector2i = player_entities[current_player_idx]["hex_position"]
	var max_range := _spell_target_range(pending_spell_data)

	var highlights := {}
	# Display standard spellcasting range circles
	var area_hexes := HexUtils.get_hexes_in_range(pos, max_range)
	for hex in area_hexes:
		if hex_grid.has_tile(hex):
			highlights[hex] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.SPELL]

	hex_grid.set_highlights(highlights)


func _spell_target_range(spell_data: Dictionary) -> int:
	var max_range := int(spell_data.get("range", 6))
	for effect in spell_data.get("effects", []):
		if str(effect.get("type", "")) == "teleport":
			max_range = maxi(max_range, int(effect.get("distance", 0)))
	return max_range


func _is_occupied_hex(coord: Vector2i) -> bool:
	for player in player_entities:
		if player.get("character") != active_character and player.get("hex_position", Vector2i.ZERO) == coord and player.get("character") != null and player.get("character").is_alive:
			return true
	for monster in monster_entities:
		if monster.get("hex_position", Vector2i.ZERO) == coord and monster.get("is_alive", false):
			return true
	return false


func _highlight_lay_on_hands_targets() -> void:
	hex_grid.clear_highlights()
	var origin: Vector2i = player_entities[current_player_idx]["hex_position"]
	var highlights := {}
	for player in player_entities:
		var target: Character = player.get("character")
		if target == null or target.current_hp >= target.max_hp:
			continue
		var target_hex: Vector2i = player.get("hex_position", Vector2i.ZERO)
		if Targeting.is_in_range(origin, target_hex, 1):
			highlights[target_hex] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.SPELL]
	hex_grid.set_highlights(highlights)


func _highlight_bardic_inspiration_targets() -> void:
	hex_grid.clear_highlights()
	var origin: Vector2i = player_entities[current_player_idx]["hex_position"]
	var highlights := {}
	for player in player_entities:
		var target: Character = player.get("character")
		if target == null or target == active_character or not target.is_alive:
			continue
		var target_hex: Vector2i = player.get("hex_position", Vector2i.ZERO)
		if Targeting.is_in_range(origin, target_hex, 12):
			highlights[target_hex] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.SPELL]
	hex_grid.set_highlights(highlights)


func _highlight_unarmed_targets() -> void:
	hex_grid.clear_highlights()
	var origin: Vector2i = player_entities[current_player_idx]["hex_position"]
	var highlights := {}
	for monster in monster_entities:
		if not monster.get("is_alive", false):
			continue
		var target_hex: Vector2i = monster.get("hex_position", Vector2i.ZERO)
		if Targeting.is_in_range(origin, target_hex, 1):
			highlights[target_hex] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.ATTACK]
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

		# A valid target commits the Attack action before any optional prompts
		# yield. Clearing targeting here prevents a second click from starting a
		# concurrent attack while an optional feature decision is open.
		pending_action_type = ""
		_spend_action_cost("action")

		# (weapon / weapon_id already resolved above; reused for the attack roll)
		
		# Determine advantage/disadvantage based on conditions
		var has_advantage := false
		var has_disadvantage := false
		var attack_reaction_decisions: Dictionary = {}
		
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

		# Reckless Attack exposes the barbarian to advantage until their next
		# turn, while the activating attack itself gains advantage below.
		if active_character.has_feature("barbarian_reckless_attack") and active_character.level >= 2 and int(weapon.get("range", 1)) <= 1 and str(weapon.get("ability", "STR")) == "STR" and int(active_character.feature_uses.get("barbarian_reckless_attack_used_this_turn", 0)) <= 0:
			var reckless_detail := "Gain Advantage on Strength melee attacks this turn; enemies gain Advantage against you until your next turn."
			if await hud.request_reaction(_owner_label_for_character(active_character), "reckless_attack", reckless_detail, "Attack recklessly?", "Reckless Attack", "Reckless Attack — %s" % _owner_label_for_character(active_character)):
				var reckless_result := CombatAction.activate_reckless_attack(active_character)
				if reckless_result.get("success", false):
					has_advantage = true

		# Offer a held Bardic Inspiration die before the attack roll.
		if active_character.feature_uses.has("bardic_inspiration_die"):
			var inspiration_die := str(active_character.feature_uses.get("bardic_inspiration_die", "1d6"))
			if await hud.request_reaction(_owner_label_for_character(active_character), "bardic_inspiration", "Add %s to this attack roll?" % inspiration_die, "Use Bardic Inspiration?", "Use Inspiration", "Bardic Inspiration — %s" % _owner_label_for_character(active_character)):
				attack_reaction_decisions["bardic_inspiration"] = true

		# Resolve weapon attack
		var result := CombatAction.resolve_weapon_attack(active_character, clicked_monster, weapon, has_advantage, has_disadvantage, attack_reaction_decisions)

		# Ranger Favored Foe is offered on a confirmed hit. Marking replaces any
		# prior concentration-bound mark; the shared resolver owns the bonus damage.
		if result.get("hit", false) and active_character.has_feature("ranger_favored_foe"):
			var current_mark_id := str(active_character.feature_uses.get("ranger_favored_foe_target_id", ""))
			var already_marked: bool = current_mark_id == str(clicked_monster.get("id", "")) and clicked_monster.get("conditions", {}).has("favored_foe")
			if not already_marked:
				var favored_detail := "Mark %s for 1 minute; the first hit each turn deals extra damage." % clicked_monster.get("name", "the target")
				if await hud.request_reaction(_owner_label_for_character(active_character), "favored_foe", favored_detail, "Mark this target?", "Mark Target", "Favored Foe — %s" % _owner_label_for_character(active_character)):
					if not active_character.concentrating_on.is_empty():
						_end_concentration(active_character)
					var favored_mark := CombatAction.resolve_favored_foe_mark(active_character, clicked_monster)
					if favored_mark.get("success", false):
						result["message"] += " [color=green]%s[/color]" % favored_mark.get("message", "Favored Foe marked.")
			var favored_damage := CombatAction.resolve_favored_foe_damage(active_character, clicked_monster)
			if favored_damage.get("success", false):
				result["damage"] = int(result.get("damage", 0)) + int(favored_damage.get("damage", 0))
				result["message"] += " [color=green]%s[/color]" % favored_damage.get("message", "Favored Foe!")

		if result.get("hit", false):
			var hunters_mark_damage := CombatAction.resolve_hunters_mark_damage(active_character, clicked_monster)
			if hunters_mark_damage.get("success", false):
				result["damage"] = int(result.get("damage", 0)) + int(hunters_mark_damage.get("damage", 0))
				result["message"] += " [color=green]%s[/color]" % hunters_mark_damage.get("message", "Hunter's Mark!")

		# Paladin Divine Smite is offered after a melee hit and before the
		# ordinary attack result is committed to the combat log.
		if result.get("hit", false) and int(weapon.get("range", 1)) <= 1 and int(clicked_monster.get("current_hp", 0)) > 0 and active_character.has_feature("paladin_divine_smite"):
			var smite_slot := _lowest_available_spell_slot(active_character, 4)
			if smite_slot > 0:
				var smite_detail := "Spend a level %d spell slot for Divine Smite?" % smite_slot
				if await hud.request_reaction(_owner_label_for_character(active_character), "divine_smite", smite_detail, "Spend spell slot?", "Divine Smite", "Divine Smite — %s" % _owner_label_for_character(active_character)):
					var smite_result := CombatAction.resolve_divine_smite(active_character, clicked_monster, smite_slot)
					if smite_result.get("success", false):
						result["damage"] = int(result.get("damage", 0)) + int(smite_result.get("damage", 0))
						result["message"] += " [color=gold]%s[/color]" % smite_result.get("message", "Divine Smite!")
		
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

		# --- Feedback / juice ---
		var dmg_dealt: int = int(result.get("damage", 0))
		if result.get("hit", false) and dmg_dealt > 0:
			var crit: bool = result.get("crit", false)
			var dmg_color := Color.GOLD if crit else Color(1.0, 0.4, 0.3)
			var txt := ("CRIT %d!" % dmg_dealt) if crit else ("-%d" % dmg_dealt)
			_spawn_floating_text(coord, txt, dmg_color)
			_shake_camera(9.0 if crit else 5.0)
			_flash_hex(coord, Color(1.0, 0.3, 0.3, 0.6))
		else:
			_spawn_floating_text(coord, "Miss", Color(0.7, 0.7, 0.7, 0.9))
		# ---

		# Check if dead
		if int(clicked_monster.get("current_hp", 0)) <= 0:
			clicked_monster["is_alive"] = false
			hud.add_log("[color=green]%s was defeated![/color]" % clicked_monster["name"])
			tracker.remove_combatant(clicked_monster["id"])

		# Extra Attack is part of one Attack action, not a second action-cost.
		# Resolve the additional swings through the same CombatAction boundary.
		for extra_index in active_character.extra_attacks:
			if not clicked_monster.get("is_alive", false):
				break
			var extra_result := CombatAction.resolve_weapon_attack(active_character, clicked_monster, weapon, has_advantage, has_disadvantage)
			hud.add_log("[color=cyan]Extra Attack %d: %s[/color]" % [extra_index + 1, extra_result.get("message", "Miss!")])
			if int(clicked_monster.get("current_hp", 0)) <= 0:
				clicked_monster["is_alive"] = false
				hud.add_log("[color=green]%s was defeated![/color]" % clicked_monster["name"])
				tracker.remove_combatant(clicked_monster["id"])

		_check_battle_end_conditions()
		_highlight_reachable()

	elif pending_action_type == "lay_on_hands":
		var lay_target: Character = null
		for player in player_entities:
			var candidate: Character = player.get("character")
			if candidate != null and player.get("hex_position", Vector2i.ZERO) == coord and candidate.current_hp < candidate.max_hp:
				lay_target = candidate
				break
		if lay_target == null:
			return
		if not Targeting.is_in_range(player_pos, coord, 1):
			hud.add_log("That ally is out of touch range.")
			return
		var pool := int(active_character.feature_uses.get("paladin_lay_on_hands", 0))
		var requested := mini(pool, maxi(0, lay_target.max_hp - lay_target.current_hp))
		var result := CombatAction.resolve_lay_on_hands(active_character, lay_target, requested)
		hud.add_log(result.get("message", "Lay on Hands failed."))
		if result.get("success", false):
			_spend_action_cost("action")
			pending_action_type = ""
			pending_feature_data = {}
			hud.update_hud(active_character, tracker)
			_check_battle_end_conditions()
			_highlight_reachable()
	elif pending_action_type == "bardic_inspiration":
		var inspiration_target: Character = null
		for player in player_entities:
			var candidate: Character = player.get("character")
			if candidate != null and candidate != active_character and player.get("hex_position", Vector2i.ZERO) == coord:
				inspiration_target = candidate
				break
		if inspiration_target == null or not inspiration_target.is_alive:
			return
		if not Targeting.is_in_range(player_pos, coord, 12):
			hud.add_log("That ally is out of Bardic Inspiration range.")
			return
		var inspiration_result := CombatAction.resolve_bardic_inspiration(active_character, inspiration_target)
		hud.add_log(inspiration_result.get("message", "Bardic Inspiration failed."))
		if inspiration_result.get("success", false):
			_spend_action_cost("bonus_action")
			pending_action_type = ""
			pending_feature_data = {}
			hud.update_hud(active_character, tracker)
			_highlight_reachable()
	elif pending_action_type == "unarmed_attack":
		var unarmed_target: Dictionary = {}
		for monster in monster_entities:
			if monster.get("is_alive", false) and monster.get("hex_position", Vector2i.ZERO) == coord:
				unarmed_target = monster
				break
		if unarmed_target.is_empty() or not Targeting.is_in_range(player_pos, coord, 1):
			return
		if not active_character.use_feature(str(pending_feature_data.get("id", ""))):
			hud.add_log("No Bonus Unarmed Strike uses remain this turn.")
			return
		var feature_id := str(pending_feature_data.get("id", ""))
		var unarmed_results: Array[Dictionary] = []
		if feature_id == "monk_flurry_of_blows":
			unarmed_results = CombatAction.resolve_flurry_of_blows(active_character, unarmed_target)
		else:
			unarmed_results.append(CombatAction.resolve_unarmed_attack(active_character, unarmed_target))
		for strike_index in unarmed_results.size():
			hud.add_log("%s" % unarmed_results[strike_index].get("message", "Unarmed Strike missed."))
		_spend_action_cost("bonus_action")
		if int(unarmed_target.get("current_hp", 0)) <= 0:
			unarmed_target["is_alive"] = false
			hud.add_log("[color=green]%s was defeated![/color]" % unarmed_target.get("name", "Enemy"))
			tracker.remove_combatant(unarmed_target.get("id", ""))
		pending_action_type = ""
		pending_feature_data = {}
		hud.update_hud(active_character, tracker)
		_check_battle_end_conditions()
		_highlight_reachable()
	elif pending_action_type == "spell":
		# Cast spell at hex
		var spell_range := _spell_target_range(pending_spell_data)
		if not Targeting.is_in_range(player_pos, coord, spell_range):
			return # out of range

		await _execute_player_spell(coord)
	else:
		# Regular movement click
		var reachable := hex_grid.get_reachable(player_pos, remaining_speed)
		if coord in reachable and coord != player_pos:
			var path := hex_grid.find_path(player_pos, coord)
			var cost: float = reachable[coord]
			remaining_speed -= cost
			
			var disengaged := active_character.has_condition("disengaging")
			if not disengaged and path.size() >= 2:
				await _check_opportunity_attacks_for_path(active_character, player_entities[current_player_idx], path, false)
			else:
				# Teleport normally if disengaged or path too short
				CombatAction.resolve_movement_step(player_entities[current_player_idx], player_pos, coord)
			
			if active_character.is_alive:
				hud.add_log("%s moved." % active_character.character_name)
			
			_highlight_reachable()

	_update_grid_entities()


func _execute_player_spell(target_coord: Vector2i) -> void:
	var spell_origin: Vector2i = player_entities[current_player_idx].get("hex_position", Vector2i.ZERO)
	var target_type := str(pending_spell_data.get("target", "single"))
	if str(pending_spell_data.get("casting_time", "action")) == "reaction":
		hud.add_log("[color=orange]%s resolves only through its reaction boundary.[/color]" % pending_spell_data.get("name", "This spell"))
		pending_action_type = ""
		_highlight_reachable()
		return
	if target_type == "self" and target_coord != spell_origin:
		hud.add_log("[color=orange]%s can only target its caster.[/color]" % pending_spell_data.get("name", "This spell"))
		_highlight_reachable()
		return
	if target_type == "single_ally":
		var ally_at_target := false
		for player in player_entities:
			if player.get("hex_position", Vector2i.ZERO) == target_coord and player.get("character") != null and player["character"].is_alive:
				ally_at_target = true
				break
		if not ally_at_target:
			hud.add_log("[color=orange]%s needs a living ally target.[/color]" % pending_spell_data.get("name", "This spell"))
			_highlight_reachable()
			return

	var area_selection := _area_selection_for_spell(pending_spell_data)
	if target_type in ["area", "cone"] and not area_selection.get("success", false):
		hud.add_log("[color=orange]%s[/color]" % area_selection.get("message", "Invalid area selection."))
		_highlight_reachable()
		return

	# Validate self-targeted teleport destinations before spending a spell slot.
	for effect in pending_spell_data.get("effects", []):
		if str(effect.get("type", "")) == "teleport" and (not hex_grid.has_tile(target_coord) or not hex_grid.is_hex_passable(target_coord) or _is_occupied_hex(target_coord)):
			hud.add_log("[color=orange]That teleport destination is not available.[/color]")
			_highlight_reachable()
			return

	# Deduct spell slot if leveled spell
	var spell_level: int = int(pending_spell_data.get("level", 0))
	var slot_level_used: int = spell_level
	if spell_level > 0:
		var slot_result := CombatAction.spend_spell_slot(active_character, pending_spell_data)
		if not slot_result.get("success", false):
			hud.add_log("[color=orange]%s[/color]" % slot_result.get("message", "No spell slots remaining!"))
			pending_action_type = ""
			_highlight_reachable()
			return
		slot_level_used = int(slot_result.get("slot_level", spell_level))
		hud.add_log("%s expended a level %d spell slot." % [active_character.character_name, int(slot_result.get("slot_level", spell_level))])

	# Self-targeted teleport spells resolve movement at the combat-state boundary;
	# there is no creature at the destination to pass through CombatAction.
	for effect in pending_spell_data.get("effects", []):
		if str(effect.get("type", "")) != "teleport":
			continue
		var origin: Vector2i = player_entities[current_player_idx].get("hex_position", Vector2i.ZERO)
		if not hex_grid.has_tile(target_coord) or not hex_grid.is_hex_passable(target_coord) or _is_occupied_hex(target_coord):
			hud.add_log("[color=orange]That teleport destination is not available.[/color]")
			_highlight_reachable()
			return
		player_entities[current_player_idx]["hex_position"] = target_coord
		hud.add_log("[color=cyan]%s teleports from %s to %s.[/color]" % [active_character.character_name, origin, target_coord])
		var teleport_cost := str(pending_spell_data.get("casting_time", "action"))
		_spend_action_cost(teleport_cost if teleport_cost in ["action", "bonus_action"] else "action")
		pending_action_type = ""
		_check_battle_end_conditions()
		_highlight_reachable()
		_update_grid_entities()
		return

	var spell_reaction_decisions: Dictionary = {}
	if active_character.has_feature("sorcerer_metamagic") and active_character.get_sorcery_points() > 0 and pending_spell_data.has("damage"):
		if await hud.request_reaction(_owner_label_for_character(active_character), "metamagic:empowered", "Spend 1 Sorcery Point to improve this spell's damage roll.", "Use Empowered Spell?", "Empower Spell", "Empowered Spell — %s" % _owner_label_for_character(active_character)):
			spell_reaction_decisions["metamagic:empowered"] = true

	var targets_list: Array = []
	var counterspell_context := await _collect_counterspell_decisions(active_character)
	var counterspell_observers: Array = counterspell_context.get("observers", [])
	var counterspell_decisions: Dictionary = counterspell_context.get("decisions", {})
	for decision_key in spell_reaction_decisions:
		counterspell_decisions[decision_key] = spell_reaction_decisions[decision_key]
	var counterspell_pending := true

	if target_type == "area" or pending_spell_data.get("target") == "cone":
		var radius := int(area_selection.get("radius", 2))
		var cone_size := int(area_selection.get("size", 3))
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
			var res := CombatAction.resolve_spell(active_character, p_target, pending_spell_data, false, counterspell_decisions if counterspell_pending else {}, counterspell_observers if counterspell_pending else [], slot_level_used)
			hud.add_log(res.get("message", ""))
			counterspell_pending = false
			if not res.get("success", true):
				break
			
			if pending_spell_data.get("concentration", false):
				active_character.concentrating_on["targets"].append(p_target)
				
			_handle_spell_effects(p_target, {}, pending_spell_data, player_entities[current_player_idx].get("hex_position", Vector2i.ZERO), target_hex)

		elif not m_target.is_empty():
			var res := CombatAction.resolve_spell(active_character, m_target, pending_spell_data, false, counterspell_decisions if counterspell_pending else {}, counterspell_observers if counterspell_pending else [], slot_level_used)
			hud.add_log(res.get("message", ""))
			counterspell_pending = false
			if not res.get("success", true):
				break
			
			if pending_spell_data.get("concentration", false):
				active_character.concentrating_on["targets"].append(m_target)
				
			_handle_spell_effects(null, m_target, pending_spell_data, player_entities[current_player_idx].get("hex_position", Vector2i.ZERO), target_hex)
			
			if int(m_target.get("current_hp", 0)) <= 0:
				m_target["is_alive"] = false
				hud.add_log("[color=green]%s was defeated![/color]" % m_target["name"])
				tracker.remove_combatant(m_target["id"])

	# Custom area effects like Sleep
	_handle_area_spell_effects(targets_list, pending_spell_data)

	# Finish spellcasting
	var spell_cost := str(pending_spell_data.get("casting_time", "action"))
	if spell_cost not in ["action", "bonus_action"]:
		spell_cost = "action"
	_spend_action_cost(spell_cost)
	pending_action_type = ""
	_check_battle_end_conditions()
	_highlight_reachable()


func _area_selection_for_spell(spell_data: Dictionary) -> Dictionary:
	var target_type := str(spell_data.get("target", "single"))
	if target_type not in ["area", "cone"]:
		return {"success": true, "type": "single_target", "persistent": false}

	var selection_effect: Dictionary = {}
	for effect in spell_data.get("effects", []):
		if str(effect.get("type", "")) == "area_selection":
			selection_effect = effect.duplicate(true)
			break
	if selection_effect.is_empty():
		selection_effect = {
			"type": "area_selection",
			"shape": "cone" if target_type == "cone" else "sphere",
			"size": int(spell_data.get("cone_size", 3)),
			"radius": int(spell_data.get("area_radius", 2)),
		}
	return EventResolver.resolve_area_selection(selection_effect)


func _on_hex_hovered(coord: Vector2i) -> void:
	# --- Move-path preview (P1 readability) ---
	# When no offensive action is pending, show the route to the hovered
	# reachable hex so the player commits with eyes open (no blind teleport).
	if pending_action_type == "" and active_character != null and not _battle_ending:
		_clear_path_preview()
		var player_pos: Vector2i = player_entities[current_player_idx]["hex_position"]
		if coord != player_pos and active_character.is_alive:
			var reachable := hex_grid.get_reachable(player_pos, remaining_speed)
			if coord in reachable:
				var path := hex_grid.find_path(player_pos, coord)
				for h in path:
					if h != player_pos:
						hex_grid.add_highlight(h, HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.PATH])
						_path_preview_hexes.append(h)
		return

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
			var area_selection := _area_selection_for_spell(pending_spell_data)
			if not area_selection.get("success", false):
				return
			var radius := int(area_selection.get("radius", 2))
			aoe_list = Targeting.get_sphere_targets(coord, radius, hex_grid)
		elif target_type == "cone":
			var area_selection := _area_selection_for_spell(pending_spell_data)
			if not area_selection.get("success", false):
				return
			var cone_size := int(area_selection.get("size", 3))
			aoe_list = Targeting.get_cone_targets(origin, coord, cone_size, hex_grid)

		for hex in aoe_list:
			hex_grid.add_highlight(hex, HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.SPELL])


func _end_active_turn() -> void:
	_waiting_for_owner_rebind = false
	_rebind_wait_before_turn_setup = false
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
		CombatState.tick_monster_condition_durations(monster)

	var round_complete := tracker.next_turn()
	_start_combat_turn()


## Tick monster conditions and restore movement after a spell slow expires.
## Kept as a stateless boundary so duration cleanup can be exercised without
## constructing a full combat scene.
static func tick_monster_condition_durations(monster: Dictionary) -> void:
	var conditions: Dictionary = monster.get("conditions", {})
	if conditions.is_empty(): return
	var expired: Array[String] = []
	for cond in conditions:
		conditions[cond] -= 1
		if conditions[cond] <= 0:
			expired.append(cond)
	for cond in expired:
		conditions.erase(cond)
		if cond == "speed_reduced" and monster.has("speed_before_spell_slow"):
			monster["speed"] = int(monster.get("speed_before_spell_slow", monster.get("speed", 6)))
			monster.erase("speed_before_spell_slow")


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
			var defeated_id := str(m.get("monster_id", ""))
			if not defeated_id.is_empty() and defeated_id not in GameManager.defeated_monsters:
				GameManager.defeated_monsters.append(defeated_id)
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
	var presenter := CombatResultPresenter.new()
	var choice: String = await presenter.present(self, result, GameManager.test_mode)
	if GameManager.test_mode:
		# Headless / test: never block on a button press or replace the harness.
		# The viewport harness owns the scene tree. A real scene transition here
		# would replace that supervisor before it can publish its result marker.
		# The battle has already resolved and registered its defeated monsters.
		print("[CombatState] Test mode: skipping post-battle scene transition")
		return
	if choice == "menu":
		GameManager.return_to_menu()
	else:
		GameManager.exit_combat(result)


func _execute_class_feature(feature: Dictionary) -> void:
	var f_id: String = feature.get("id", "")
	var cost_type: String = feature.get("action_cost", "action")
	if not _can_spend_action_cost(cost_type):
		hud.add_log("You have no %s available for %s." % [cost_type.replace("_", " "), feature.get("name", f_id)])
		return
	
	if not active_character.use_feature(f_id):
		hud.add_log("You have no uses of %s remaining!" % feature.get("name", f_id))
		return

	hud.add_log("[color=cyan]%s uses class feature: %s![/color]" % [active_character.character_name, feature.get("name", f_id)])

	var effects: Array = feature.get("effects", [])
	_spend_action_cost(cost_type)

	for effect in effects:
		var type: String = effect.get("type", "")
		match type:
			"grant_extra_action":
				turn_budget.grant_action()
				hud.add_log("[color=green]%s gains an additional action this turn![/color]" % active_character.character_name)
			"cunning_dash":
				remaining_speed += active_character.get_speed()
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
			"cunning_action":
				var selected_action := str(feature.get("selected_action", "dash"))
				match selected_action:
					"dash":
						remaining_speed += active_character.get_speed()
						hud.add_log("[color=green]%s uses Cunning Action: Dash! Speed doubled to %.1f.[/color]" % [active_character.character_name, remaining_speed])
					"disengage":
						active_character.add_condition("disengaging", 1)
						hud.add_log("[color=green]%s uses Cunning Action: Disengage![/color]" % active_character.character_name)
					"hide":
						var hide_roll := Dice.roll(20) + active_character.ability_scores.get_ability_modifier("DEX")
						if hide_roll >= 12:
							active_character.add_condition("hidden", 1)
							hud.add_log("[color=green]%s uses Cunning Action: Hide! Stealth check %d vs DC 12 succeeded.[/color]" % [active_character.character_name, hide_roll])
						else:
							hud.add_log("[color=yellow]%s uses Cunning Action: Hide! Stealth check %d vs DC 12 failed.[/color]" % [active_character.character_name, hide_roll])
			"step_of_the_wind":
				var step_action := str(feature.get("selected_action", "dash"))
				match step_action:
					"dash":
						remaining_speed += active_character.get_speed()
						hud.add_log("[color=green]%s uses Step of the Wind: Dash! Speed doubled to %.1f.[/color]" % [active_character.character_name, remaining_speed])
					"disengage":
						active_character.add_condition("disengaging", 1)
						hud.add_log("[color=green]%s uses Step of the Wind: Disengage![/color]" % active_character.character_name)
			"divine_sense":
				var sense_origin: Vector2i = player_entities[current_player_idx].get("hex_position", Vector2i.ZERO)
				var sense_result := CombatAction.resolve_divine_sense(active_character, monster_entities, sense_origin)
				hud.add_log("[color=cyan]%s[/color]" % sense_result.get("message", "Divine Sense resolves."))
			"recover_spell_slots":
				_recover_wizard_spell_slots(active_character)
			_:
				var res := EventResolver.apply_effects(active_character, [effect])
				for r in res:
					hud.add_log(r.get("message", ""))

	hud.update_hud(active_character, tracker)
	_highlight_reachable()


func _execute_item(item: Dictionary) -> void:
	var item_id := str(item.get("id", ""))
	var item_data := DataLoader.get_item(item_id)
	var cost_type := str(item_data.get("action_cost", "action"))
	if not _can_spend_action_cost(cost_type):
		hud.add_log("You have no %s available to use that item." % cost_type.replace("_", " "))
		return
	var result := active_character.inventory.consume(item_id, active_character)
	if not result.get("success", false):
		hud.add_log("[color=orange]%s[/color]" % result.get("message", "Item could not be used."))
		return
	_spend_action_cost(cost_type)
	for effect_result in result.get("results", []):
		hud.add_log(effect_result.get("message", ""))
	hud.update_hud(active_character, tracker)
	_highlight_reachable()


func _action_cost_for_command(action_type: String, extra_data: Dictionary) -> String:
	if action_type == "use_feature":
		return str(extra_data.get("feature", {}).get("action_cost", "action"))
	if action_type == "cast_spell":
		var spell_cost := str(extra_data.get("spell", {}).get("casting_time", "action"))
		return spell_cost if spell_cost in ["action", "bonus_action"] else "action"
	if action_type in ["attack", "dodge"]:
		return "action"
	return "free"


func _can_spend_action_cost(cost_type: String) -> bool:
	return turn_budget.can_spend(cost_type)


func _reset_turn_action_economy() -> void:
	turn_budget.reset(active_character, player_entities)


func _spend_action_cost(cost_type: String) -> bool:
	return turn_budget.spend(cost_type)


func _is_sneak_attack_valid(attacker: Character, target_coord: Vector2i, has_advantage: bool) -> bool:
	if not attacker.has_feature("sneak_attack") and not attacker.has_feature("rogue_sneak_attack"):
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
	var concentration_name: String = str(DataLoader.get_spell(spell_id).get("name", spell_id))
	if spell_id == "ranger_favored_foe":
		concentration_name = "Favored Foe"
	hud.add_log("[color=yellow]%s's concentration on %s ends.[/color]" % [caster.character_name, concentration_name])
	if spell_id == "ranger_favored_foe":
		var marked_id := str(caster.feature_uses.get("ranger_favored_foe_target_id", ""))
		for monster in monster_entities:
			if str(monster.get("id", "")) == marked_id:
				monster.get("conditions", {}).erase("favored_foe")
		caster.feature_uses.erase("ranger_favored_foe_target_id")
	if spell_id == "hunters_mark":
		var marked_id := str(caster.feature_uses.get("hunters_mark_target_id", ""))
		for monster in monster_entities:
			if str(monster.get("id", "")) == marked_id:
				monster.get("conditions", {}).erase("hunters_mark")
		caster.feature_uses.erase("hunters_mark_target_id")
	
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


func _handle_spell_effects(p_target: Character = null, m_target: Dictionary = {}, spell_data: Dictionary = {}, origin: Vector2i = Vector2i.ZERO, target_coord: Vector2i = Vector2i.ZERO) -> void:
	var effects: Array = spell_data.get("effects", [])
	for effect in effects:
		var type: String = effect.get("type", "")
		match type:
			"heal", "heal_self", "reduce_speed", "vision_bonus":
				if p_target != null:
					for result in EventResolver.apply_effects(p_target, [effect]):
						hud.add_log(result.get("message", ""))
				elif not m_target.is_empty() and type == "reduce_speed":
					var reduction := maxi(0, int(effect.get("value", 2)))
					var duration := maxi(1, int(effect.get("duration", 1)))
					var conditions: Dictionary = m_target.get("conditions", {})
					if not conditions.has("speed_reduced"):
						m_target["speed_before_spell_slow"] = int(m_target.get("speed", 6))
						m_target["speed"] = maxi(0, int(m_target.get("speed", 6)) - reduction)
					conditions["speed_reduced"] = duration
					m_target["conditions"] = conditions
					hud.add_log("[color=cyan]%s's movement is reduced by %d for %d turns.[/color]" % [m_target.get("name", "Target"), reduction, duration])
			"grant_condition":
				var cond = effect.get("condition", "")
				var dur = int(effect.get("duration", 3))
				if p_target != null:
					p_target.add_condition(cond, dur)
					hud.add_log("[color=green]%s is now %s for %d turns![/color]" % [p_target.character_name, cond, dur])
				elif not m_target.is_empty():
					var immunities: Array = m_target.get("condition_immunities", [])
					if cond in immunities:
						hud.add_log("[color=gray]%s is immune to %s.[/color]" % [m_target.get("name", "Target"), cond])
						continue
					var monster_conditions: Dictionary = m_target.get("conditions", {})
					monster_conditions[cond] = dur
					m_target["conditions"] = monster_conditions
					hud.add_log("[color=green]%s is now %s for %d turns![/color]" % [m_target.get("name", "Target"), cond, dur])
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
			"push":
				if not m_target.is_empty():
					var push_distance := int(effect.get("distance", 1))
					var pushed_to: Vector2i = m_target.get("hex_position", target_coord)
					for _step in push_distance:
						var best_hex := pushed_to
						var best_distance := HexUtils.get_distance(origin, pushed_to)
						for neighbor in HexUtils.get_neighbors(pushed_to):
							if not hex_grid.has_tile(neighbor) or not hex_grid.is_hex_passable(neighbor) or _is_occupied_hex(neighbor):
								continue
							var candidate_distance := HexUtils.get_distance(origin, neighbor)
							if candidate_distance > best_distance:
								best_hex = neighbor
								best_distance = candidate_distance
						if best_hex == pushed_to:
							break
						pushed_to = best_hex
					m_target["hex_position"] = pushed_to
					hud.add_log("[color=cyan]%s is pushed %d hexes.[/color]" % [m_target.get("name", "Target"), HexUtils.get_distance(target_coord, pushed_to)])


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


func _lowest_available_spell_slot(character: Character, max_level: int) -> int:
	for level in range(1, max_level + 1):
		if int(character.spell_slots.get(str(level), 0)) > 0:
			return level
	return 0


func _check_opportunity_attacks_for_path(entity, entity_dict: Dictionary, path: Array, is_entity_monster: bool) -> void:
	if path.size() < 2: return
	
	for k in range(path.size() - 1):
		var from_hex: Vector2i = path[k]
		var to_hex: Vector2i = path[k+1]
		
		# Move through the shared action boundary before checking reactions.
		var movement_result := CombatAction.resolve_movement_step(entity_dict, from_hex, to_hex)
		if not movement_result.get("success", false):
			return
		
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
					var owner_label := _owner_label_for_character(char_data)
					var accepted := await hud.request_reaction(owner_label, "opportunity_attack", "Make a weapon attack against %s before it leaves your reach." % entity_dict["name"])
					if not accepted:
						hud.add_log("[color=gray]%s declines the opportunity attack.[/color]" % owner_label)
						continue
					p["reaction_available"] = false
					char_data.reaction_available = false
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
					var reaction_decisions := await _collect_reaction_decisions(entity)
					var result := CombatAction.resolve_weapon_attack(_make_temp_monster_character(m), entity, attack_data, false, false, reaction_decisions)
					hud.add_log(result.get("message", "Miss!"))
					
					if not entity.is_alive:
						hud.add_log("[color=red]%s was knocked out by opportunity attack![/color]" % entity.character_name)
						entity_dict["hex_position"] = from_hex # Stops at from_hex
						_end_concentration(entity)
						return


func _owner_label_for_character(character: Character) -> String:
	if character == null:
		return "Unknown seat"
	for player_entity in player_entities:
		if player_entity.get("character") != character:
			continue
		var owner_index := int(player_entity.get("owner_player_index", -1))
		return "Seat %d - %s" % [owner_index + 1, character.character_name] if owner_index >= 0 else character.character_name
	return character.character_name
