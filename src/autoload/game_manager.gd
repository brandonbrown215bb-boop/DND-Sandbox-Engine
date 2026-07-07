## Game Manager
## Autoloaded singleton that controls the top-level game state machine.
## Manages transitions between menu, character creation, overworld, combat, dungeon, and events.
extends Node

## Emitted when the game state changes.
signal state_changed(old_state: GameState, new_state: GameState)

## Game state enum.
enum GameState {
	MAIN_MENU,
	CHARACTER_CREATION,
	OVERWORLD,
	COMBAT,
	DUNGEON,
	EVENT,
	GAME_OVER,
}

## Current game state.
var current_state: GameState = GameState.MAIN_MENU

## The active campaign data (loaded from JSON).
var active_campaign: Dictionary = {}

## Persistent state for the current dungeon crawl (rooms, progress, etc.)
var active_dungeon_state: Dictionary = {}

## List of defeated monster IDs during this campaign.
var defeated_monsters: Array[String] = []

## Flag indicating that a save file is currently being loaded.
var is_loading_save: bool = false

## Scene paths for each state.
const STATE_SCENES := {
	GameState.MAIN_MENU: "res://scenes/main_menu.tscn",
	GameState.CHARACTER_CREATION: "res://scenes/ui/character_creation.tscn",
	GameState.OVERWORLD: "res://scenes/overworld.tscn",
	GameState.COMBAT: "res://scenes/combat.tscn",
	GameState.DUNGEON: "res://scenes/dungeon.tscn",
}

## Context data passed when transitioning between states.
## For example, combat state needs to know which monsters to spawn.
var transition_context: Dictionary = {}

## Whether the game is currently in progress.
var game_in_progress: bool = false


func _ready() -> void:
	pass


## Transition to a new game state with fade animation.
func change_state(new_state: GameState, context: Dictionary = {}) -> void:
	var old_state := current_state
	current_state = new_state
	transition_context = context

	print("[GameManager] State: %s -> %s" % [GameState.keys()[old_state], GameState.keys()[new_state]])
	
	# Instantiate transition overlay CanvasLayer
	var cl := CanvasLayer.new()
	cl.layer = 128
	var cr := ColorRect.new()
	cr.color = Color(0, 0, 0, 0)
	cr.anchors_preset = Control.PRESET_FULL_RECT
	cr.mouse_filter = Control.MOUSE_FILTER_STOP
	cl.add_child(cr)
	add_child(cl)

	# Fade to black
	var tween := create_tween()
	tween.tween_property(cr, "color:a", 1.0, 0.25)
	await tween.finished

	# Change scene
	state_changed.emit(old_state, new_state)
	if new_state in STATE_SCENES:
		get_tree().change_scene_to_file(STATE_SCENES[new_state])
	
	# Small delay while new scene loads
	await get_tree().create_timer(0.05).timeout

	# Fade from black
	var tween_out := create_tween()
	tween_out.tween_property(cr, "color:a", 0.0, 0.25)
	await tween_out.finished

	# Cleanup
	cl.queue_free()

	# Check campaign victory if we transitioned to overworld or dungeon
	if current_state in [GameState.OVERWORLD, GameState.DUNGEON]:
		check_campaign_victory()


## Start a new game with the given campaign and player count.
func start_new_game(campaign_id: String, player_count: int) -> void:
	active_campaign = DataLoader.get_campaign(campaign_id)
	if active_campaign.is_empty():
		push_error("[GameManager] Campaign not found: %s" % campaign_id)
		return

	# Reset player manager
	PlayerManager.reset()
	for i in player_count:
		PlayerManager.add_player()

	game_in_progress = true

	# Go to character creation
	change_state(GameState.CHARACTER_CREATION)


## Called when all players have created their characters.
func on_character_creation_complete() -> void:
	change_state(GameState.OVERWORLD)


## Enter combat from the overworld or a dungeon.
func enter_combat(monster_ids: Array, surprise: bool = false, return_state: GameState = GameState.OVERWORLD, terrain: String = "plains") -> void:
	change_state(GameState.COMBAT, {
		"monster_ids": monster_ids,
		"surprise": surprise,
		"return_state": return_state,
		"terrain": terrain,
	})


## Exit combat and return to the previous state.
func exit_combat(result: String) -> void:
	var return_state: GameState = transition_context.get("return_state", GameState.OVERWORLD)
	change_state(return_state, {"combat_result": result})


## Enter a dungeon from the overworld.
func enter_dungeon(dungeon_id: String) -> void:
	active_dungeon_state.clear()
	change_state(GameState.DUNGEON, {"dungeon_id": dungeon_id})


## Exit a dungeon and return to the overworld.
func exit_dungeon() -> void:
	active_dungeon_state.clear()
	change_state(GameState.OVERWORLD, {"returning_from_dungeon": true})


## Trigger an event (shows event dialog, pauses current state).
func trigger_event(event_data: Dictionary) -> void:
	change_state(GameState.EVENT, {"event_data": event_data, "return_state": current_state})


## Event resolved, return to previous state.
func resolve_event(result: Dictionary) -> void:
	var return_state: GameState = transition_context.get("return_state", GameState.OVERWORLD)
	change_state(return_state, {"event_result": result})


## End the game (win or lose).
func end_game(victory: bool, reason: String = "") -> void:
	game_in_progress = false
	change_state(GameState.GAME_OVER, {"victory": victory, "reason": reason})


## Return to main menu.
func return_to_menu() -> void:
	game_in_progress = false
	PlayerManager.reset()
	active_campaign = {}
	transition_context = {}
	active_dungeon_state.clear()
	defeated_monsters.clear()
	change_state(GameState.MAIN_MENU)


## Get the campaign's win condition data.
func get_win_condition() -> Dictionary:
	return active_campaign.get("win_condition", {})


## Get the campaign's milestone definitions.
func get_milestones() -> Array:
	return active_campaign.get("milestones", [])


## Check a milestone trigger. Returns true if a milestone was activated.
func check_milestone(trigger: String) -> bool:
	var milestones: Array = get_milestones()
	for milestone in milestones:
		if milestone.get("trigger", "") == trigger:
			# Apply milestone effects
			var effects: Array = milestone.get("effects", [])
			for effect in effects:
				_apply_milestone_effect(effect)
			return true
	return false


## Apply a single milestone effect.
func _apply_milestone_effect(effect: Dictionary) -> void:
	var effect_type: String = effect.get("type", "")
	match effect_type:
		"level_up":
			# Level up all players
			for i in PlayerManager.get_player_count():
				var player := PlayerManager.get_player(i)
				if player.get("character") != null:
					player["character"].level_up()
					print("[GameManager] %s leveled up!" % player["name"])
		_:
			push_warning("[GameManager] Unknown milestone effect type: %s" % effect_type)


## Check if campaign win conditions are met
func check_campaign_victory() -> void:
	if not game_in_progress or active_campaign.is_empty():
		return

	var win_cond := get_win_condition()
	if win_cond.is_empty():
		return

	var type: String = win_cond.get("type", "")
	if type == "goal":
		var goals: Array = win_cond.get("goals", [])
		var all_met := true
		for goal in goals:
			var goal_type: String = goal.get("type", "")
			match goal_type:
				"collect_item":
					var item_id: String = goal.get("item_id", "")
					var required_count: int = int(goal.get("count", 1))
					var total_count := 0
					# Count across all players' inventories
					for i in PlayerManager.get_player_count():
						var p := PlayerManager.get_player(i)
						var c: Character = p.get("character")
						if c != null:
							total_count += c.inventory.count_item(item_id)
					if total_count < required_count:
						all_met = false
						break
				"defeat_monster":
					var monster_id: String = goal.get("monster_id", "")
					if not monster_id in defeated_monsters:
						all_met = false
						break
				_:
					all_met = false
					break
		if all_met:
			end_game(true, "Campaign goals completed!")
