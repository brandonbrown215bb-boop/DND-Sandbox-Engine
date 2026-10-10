## Overworld State Controller
## Manages turn-by-turn exploration, hex movement, Fog of War, and event triggers.
class_name OverworldState
extends Node2D

@onready var hex_grid: HexGrid = $HexGrid
@onready var overworld_map: OverworldMap = $OverworldMap
@onready var hud: OverworldHUD = $OverworldHUD
@onready var event_dialog_scene := preload("res://scenes/ui/event_dialog.tscn")
@onready var shop_scene := preload("res://scenes/ui/shop.tscn")
@onready var camera: Camera2D = $Camera2D

# Active player turn state
var current_player_idx: int = 0
var remaining_speed: float = 0.0
var has_moved_this_turn: bool = false
var has_resolved_tile: bool = false
var companion_roster_open: bool = false

# Pathfinding visual highlights
var reachable_hexes: Dictionary = {}
var current_hovered_path: Array[Vector2i] = []


func _ready() -> void:
	# Set references
	overworld_map.hex_grid_path = hex_grid.get_path()

	# Connect grid signals
	hex_grid.hex_clicked.connect(_on_hex_clicked)
	hex_grid.hex_hovered.connect(_on_hex_hovered)
	hud.end_turn_pressed.connect(_on_end_turn_pressed)
	hud.rest_pressed.connect(_on_rest_pressed)
	hud.save_pressed.connect(_on_save_pressed)
	hud.menu_pressed.connect(_on_menu_pressed)
	hud.settings_pressed.connect(_on_settings_pressed)
	hud.sheet_pressed.connect(_on_sheet_pressed)
	hud.companion_roster_visibility_changed.connect(_on_companion_roster_visibility_changed)

	# Generate map from campaign
	overworld_map.generate_map()
	
	# Start Player turns
	var is_returning: bool = GameManager.transition_context.get("returning_from_dungeon", false) or GameManager.is_loading_save
	if not is_returning:
		PlayerManager.start_game()
	
	if PlayerManager.is_party_wiped():
		_handle_party_wiped()
		return
	_update_grid_entities()
	var initial_location := hex_grid.get_tile(PartyManager.get_exploration_position())
	GameManager.record_overworld_location(PartyManager.get_exploration_position(), initial_location.location_name if initial_location != null else "")
	_start_player_turn()

	# Clear loaded/returned transition flags
	if GameManager.transition_context.get("returning_from_dungeon", false):
		GameManager.transition_context["returning_from_dungeon"] = false
	if GameManager.is_loading_save:
		GameManager.is_loading_save = false


func _update_grid_entities() -> void:
	hex_grid.clear_entities()
	var player_count := PlayerManager.get_player_count()
	for i in player_count:
		var p_data := PlayerManager.get_player(i)
		hex_grid.add_entity({
			"hex_position": p_data.get("hex_position", Vector2i.ZERO),
			"color": p_data.get("color", Color.WHITE),
			"is_player": true,
			"player_index": i
		})


func _start_player_turn() -> void:

	current_player_idx = PlayerManager.active_player_index
	var player := PlayerManager.get_active_player()
	var char_data: Character = player.get("character")
	
	if char_data == null:
		push_error("[OverworldState] Active player character is null!")
		return

	# Reset turn actions
	remaining_speed = float(char_data.get_speed())
	has_moved_this_turn = false
	has_resolved_tile = false

	# Update Fog of War for player's new turn position
	FogOfWar.update_visibility(hex_grid)

	# Center camera on player
	var pos := PartyManager.get_exploration_position()
	camera.center_on(hex_grid.map_to_local(pos))

	# Highlight reachable tiles
	_recalculate_reachable()

	# Refresh HUD
	hud.update_hud()
	hud.add_log("[color=yellow]=== Round %d: %s's Turn ===[/color]" % [PlayerManager.current_round, char_data.character_name])


func _recalculate_reachable() -> void:
	var pos := PartyManager.get_exploration_position()
	
	# Use HexGrid's reachability wrapper
	reachable_hexes = hex_grid.get_reachable(pos, remaining_speed)

	# Highlight on grid
	hex_grid.clear_highlights()
	
	var highlights := {}
	for hex in reachable_hexes:
		# Don't highlight player's own tile
		if hex == pos: continue
		highlights[hex] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.MOVEMENT]

	hex_grid.set_highlights(highlights)


func _on_hex_clicked(coord: Vector2i) -> void:
	if companion_roster_open:
		return
	var command := PlayerCommand.move(coord)
	if command == null:
		return
	_execute_move_command(command)


func _execute_move_command(command: PlayerCommand) -> void:
	if companion_roster_open:
		return
	var coord := command.target_hex()
	if coord not in reachable_hexes or coord == PartyManager.get_exploration_position():
		return

	var path := hex_grid.find_path(PartyManager.get_exploration_position(), coord)
	if path.is_empty():
		return

	# Perform movement step-by-step or instantly
	var cost: float = reachable_hexes[coord]
	remaining_speed -= cost
	has_moved_this_turn = true

	# Update player position
	PartyManager.move_exploration_party(coord)
	_update_grid_entities()
	var visited_tile := hex_grid.get_tile(coord)
	GameManager.record_overworld_location(coord, visited_tile.location_name if visited_tile != null else "")

	# Recalculate Vision
	FogOfWar.update_visibility(hex_grid)

	hud.add_log("%s moved to hex %s (Spent %.1f movement points)" % [
		PlayerManager.get_active_player()["character"].character_name,
		coord,
		cost
	])

	# Update HUD
	hud.update_hud()

	# Resolve destination tile
	_resolve_destination_tile(coord)


func _on_hex_hovered(coord: Vector2i) -> void:
	if companion_roster_open:
		return
	# Clear previous path drawing
	current_hovered_path.clear()
	
	if coord in reachable_hexes and coord != PartyManager.get_exploration_position():
		var path := hex_grid.find_path(PartyManager.get_exploration_position(), coord)
		current_hovered_path = path

	# Re-render highlights
	_recalculate_reachable()
	
	# Overlay path highlights if any
	for p_coord in current_hovered_path:
		if p_coord == PartyManager.get_exploration_position(): continue
		hex_grid.add_highlight(p_coord, HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.PATH])


func _resolve_destination_tile(coord: Vector2i) -> void:
	var tile := hex_grid.get_tile(coord)
	if tile == null: return

	# 1. Check if it's a dungeon entrance
	if tile.terrain == HexTile.TerrainType.DUNGEON_ENTRANCE:
		hud.add_log("[color=purple]Stumbled upon a Dungeon entrance: %s![/color]" % tile.location_name)
		# Trigger entering dungeon state
		GameManager.enter_dungeon(tile.dungeon_id)
		return

	# 2. Check if it's a town
	if tile.terrain == HexTile.TerrainType.TOWN:
		var town_name := tile.location_name if not tile.location_name.is_empty() else "Elderwick"
		hud.add_log("[color=green]Entered Town: %s![/color]" % town_name)
		_trigger_shop_ui(town_name)
		return

	# 3. Trigger random event based on terrain table
	var event := EventSystem.trigger_event_for_tile(tile)
	if not event.is_empty():
		_trigger_event_ui(event)
	else:
		has_resolved_tile = true
		_recalculate_reachable()


func _trigger_event_ui(event_data: Dictionary) -> void:
	# Instantiate and show event dialog
	var dialog: EventDialog = event_dialog_scene.instantiate()
	add_child(dialog)
	dialog.popup_event(PlayerManager.get_active_player()["character"], event_data)
	
	# Block grid clicks until event is closed
	hex_grid.set_process_input(false)
	
	dialog.event_resolved.connect(func(result: Dictionary):
		hex_grid.set_process_input(true)
		has_resolved_tile = true
		
		# Log result
		var msg: String = result.get("message", "Event resolved.")
		hud.add_log("[color=light_blue]%s[/color]" % msg)
		
		# Check if event triggered combat
		var next_state_combat: Array = result.get("monsters", [])
		if not next_state_combat.is_empty():
			# Enter combat!
			var tile_terrain := "plains"
			var current_tile := hex_grid.get_tile(PartyManager.get_exploration_position())
			if current_tile != null:
				tile_terrain = current_tile.get_terrain_name()
			GameManager.enter_combat(next_state_combat, result.get("surprise", false), GameManager.GameState.OVERWORLD, tile_terrain)
			return
		
		# Check if event teleported player
		if result.get("teleported", false):
			# Choose random passable hex and place player there
			var all_hexes := hex_grid.tiles.keys()
			var passable_hexes: Array[Vector2i] = []
			for hex in all_hexes:
				var tile: HexTile = hex_grid.get_tile(hex)
				if tile != null and tile.is_passable():
					passable_hexes.append(hex)
			
			if not passable_hexes.is_empty():
				var rand_hex: Vector2i = passable_hexes.pick_random()
				PartyManager.move_exploration_party(rand_hex)
				FogOfWar.update_visibility(hex_grid)
				hud.add_log("Teleported to hex %s!" % str(rand_hex))

		# Check milestone check triggers if any
		var milestone_trigger: String = result.get("milestone", "")
		if not milestone_trigger.is_empty():
			GameManager.check_milestone(milestone_trigger)

		if PlayerManager.is_party_wiped():
			_handle_party_wiped()
			return

		# Refresh HUD and highlights
		hud.update_hud()
		_recalculate_reachable()
	)


func _trigger_shop_ui(town_name: String) -> void:
	var shop: ShopUI = shop_scene.instantiate()
	add_child(shop)
	shop.setup_shop(town_name)
	
	# Block grid clicks until shop is closed
	hex_grid.set_process_input(false)
	
	shop.closed.connect(func():
		hex_grid.set_process_input(true)
		has_resolved_tile = true
		_recalculate_reachable()
		hud.update_hud()
	)


func _on_end_turn_pressed() -> void:
	if companion_roster_open:
		return
	var command := PlayerCommand.simple("end_turn")
	if command == null:
		return
	_execute_end_turn_command(command)


func _execute_end_turn_command(_command: PlayerCommand) -> void:
	if companion_roster_open:
		return
	# Clear active player path/reach highlights
	hex_grid.clear_highlights()
	
	# Pass turn to next player
	var new_round := PlayerManager.next_turn()
	if new_round:
		report_animal_messenger_notifications(GameManager.advance_campaign_time(86400))
	_start_player_turn()


func report_animal_messenger_notifications(notifications: Array[Dictionary]) -> void:
	for notification in notifications:
		var delivery: Dictionary = notification.get("delivery", {})
		if str(notification.get("status", "")) == "delivered":
			hud.add_log("[color=cyan]The messenger reaches %s and delivers its message to %s: “%s”[/color]" % [delivery.get("destination_name", "the destination"), delivery.get("recipient", "the recipient"), delivery.get("message", "")])
		elif str(notification.get("status", "")) == "returned":
			hud.add_log("[color=orange]The messenger cannot reach %s before the spell ends. The message is lost and the Beast returns.[/color]" % delivery.get("destination_name", "the destination"))


## Wilderness rest (Phase 2 gap): rest the party for free, then a Stealth check
## decides whether the camp is discovered. Resting restores HP, spell slots, and
## per-rest feature uses (same recovery as the paid tavern rest in ShopUI).
## A Stealth check (best stealthy party member) vs a DC scaled by party size
## determines if the night passes safely. Failing means a surprise encounter.
func _on_rest_pressed() -> void:
	if companion_roster_open:
		return
	var command := PlayerCommand.simple("rest")
	if command == null:
		return
	_execute_rest_command(command)


func _execute_rest_command(_command: PlayerCommand) -> void:
	if companion_roster_open:
		return
	_rest_party()
	report_animal_messenger_notifications(GameManager.advance_campaign_time(28800))
	hud.add_log("[color=green]The party makes camp and rests. HP, spell slots, and feature uses restored.[/color]")
	hud.update_hud()
	_recalculate_reachable()

	# Ambush check: the most stealthy party member tries to keep the camp quiet.
	var dc := _compute_ambush_dc()
	var best_stealth := _party_best_stealth_mod()
	var roll := Dice.roll(20)
	var total := roll + best_stealth
	hud.add_log("[color=yellow]Stealth check: %d (rolled %d + %d) vs DC %d.[/color]" % [total, roll, best_stealth, dc])

	if total >= dc:
		hud.add_log("[color=green]The camp stays hidden. The night passes peacefully.[/color]")
	else:
		var ambush_pool := ["goblin", "wolf", "bandit", "giant_spider", "skeleton"]
		var count := randi_range(2, 3)
		var monsters: Array[String] = []
		for i in count:
			monsters.append(ambush_pool.pick_random())
		var tile_terrain := "plains"
		var current_tile := hex_grid.get_tile(PartyManager.get_exploration_position())
		if current_tile != null:
			tile_terrain = current_tile.get_terrain_name()
		hud.add_log("[color=red]Ambush! A %s pack stalks the camp![/color]" % tile_terrain)
		GameManager.enter_combat(monsters, true, GameManager.GameState.OVERWORLD, tile_terrain)


## Ambush Stealth DC: base 12, +1 per extra party member (more people = noisier).
func _compute_ambush_dc() -> int:
	var party_size := PlayerManager.get_player_count()
	return 12 + maxi(0, party_size - 1)


## Best party Stealth bonus (DEX mod + proficiency if Stealth-trained), over
## all alive characters. Used as the static part of the ambush Stealth check.
func _party_best_stealth_mod() -> int:
	var best := -99
	var count := PlayerManager.get_player_count()
	for i in count:
		var char_data: Character = PlayerManager.get_player(i).get("character")
		if char_data == null or not char_data.is_alive:
			continue
		var mod := char_data.ability_scores.get_ability_modifier("DEX")
		if "STEALTH" in char_data.skill_proficiencies:
			mod += char_data.proficiency_bonus
		best = maxi(best, mod)
	if best == -99:
		best = 0
	return best


## Heal and restore the whole party (no gold cost). Mirrors ShopUI._on_rest_pressed.
func _rest_party() -> void:
	var player_count := PlayerManager.get_player_count()
	for i in player_count:
		var char_data: Character = PlayerManager.get_player(i).get("character")
		if char_data == null: continue
		char_data.long_rest()


## Manual save from the overworld HUD.
func _on_save_pressed() -> void:
	var command := PlayerCommand.simple("save")
	if command == null:
		return
	_execute_save_command(command)


func _execute_save_command(_command: PlayerCommand) -> void:
	if not GameManager.game_in_progress:
		hud.add_log("[color=orange]Nothing to save yet.[/color]")
		return
	var ok := SaveManager.save_game("quicksave")
	if ok:
		hud.add_log("[color=green]Game saved to 'quicksave'.[/color]")
	else:
		hud.add_log("[color=red]Save failed (see logs).[/color]")


## Quit to main menu from the overworld HUD.
func _on_menu_pressed() -> void:
	var command := PlayerCommand.simple("menu")
	if command == null:
		return
	_execute_menu_command(command)


func _execute_menu_command(_command: PlayerCommand) -> void:
	hud.add_log("[color=yellow]Returning to main menu...[/color]")
	hex_grid.set_process_input(false)
	GameManager.return_to_menu()


## Open the settings / pause overlay (save/load anywhere + options).
func _on_settings_pressed() -> void:
	var command := PlayerCommand.simple("settings")
	if command == null:
		return
	_execute_settings_command(command)


func _execute_settings_command(_command: PlayerCommand) -> void:
	Settings.open_settings(self)


func _on_sheet_pressed() -> void:
	var command := PlayerCommand.simple("sheet")
	if command == null:
		return
	_execute_sheet_command(command)


func _execute_sheet_command(_command: PlayerCommand) -> void:
	CharacterSheet.show_active()


func _on_companion_roster_visibility_changed(is_open: bool) -> void:
	companion_roster_open = is_open
	hex_grid.set_process_input(not is_open)
	if is_open:
		current_hovered_path.clear()
		hex_grid.clear_highlights()
	else:
		_recalculate_reachable()


func _handle_party_wiped() -> void:
	hud.add_log("[color=red]Party was wiped. Opening defeat screen...[/color]")
	hex_grid.set_process_input(false)
	if hud.btn_end_turn != null:
		hud.btn_end_turn.disabled = true
	GameManager.end_game(false, "The party was defeated.")
