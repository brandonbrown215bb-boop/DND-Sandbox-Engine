## Game Manager
## Autoloaded singleton that controls the top-level game state machine.
## Manages transitions between menu, character creation, overworld, combat, dungeon, and events.
extends Node

const AnimalMessengerRulesRef = preload("res://src/spells/animal_messenger_rules.gd")

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
	DEFEAT,
	COMPLETION,
}

## Current game state.
var current_state: GameState = GameState.MAIN_MENU

## The active campaign data (loaded from JSON).
var active_campaign: Dictionary = {}

## Persistent state for the current dungeon crawl (rooms, progress, etc.)
var active_dungeon_state: Dictionary = {}
## Plain snapshots survive exiting/reentering a dungeon and safe disk saves.
var dungeon_snapshots: Dictionary = {}

## List of defeated monster IDs during this campaign.
var defeated_monsters: Array[String] = []

## Stable campaign ledgers. IDs, not scene objects, are persisted.
var completed_milestones: Array[String] = []
var cleared_dungeons: Array[String] = []
var claimed_rewards: Array[String] = []
var recruited_companions: Array[String] = []
var dismissed_companions: Array[String] = []
var visited_overworld_locations: Array[Dictionary] = []
var animal_messenger_deliveries: Array[Dictionary] = []
var campaign_elapsed_seconds: int = 0
var next_animal_messenger_id: int = 1
var created_creatures: Array[Dictionary] = []
var next_created_creature_id: int = 1
var campaign_completed: bool = false

## Flag indicating that a save file is currently being loaded.
var is_loading_save: bool = false

## Scene paths for each state.
const STATE_SCENES := {
	GameState.MAIN_MENU: "res://scenes/main_menu.tscn",
	GameState.CHARACTER_CREATION: "res://scenes/ui/character_creation.tscn",
	GameState.OVERWORLD: "res://scenes/overworld.tscn",
	GameState.COMBAT: "res://scenes/combat.tscn",
	GameState.DUNGEON: "res://scenes/dungeon.tscn",
	GameState.GAME_OVER: "res://scenes/defeat.tscn",
	GameState.DEFEAT: "res://scenes/defeat.tscn",
	GameState.COMPLETION: "res://scenes/completion.tscn",
}

## Context data passed when transitioning between states.
## For example, combat state needs to know which monsters to spawn.
var transition_context: Dictionary = {}

## Whether the game is currently in progress.
var game_in_progress: bool = false

## When true, end-of-battle flows resolve instantly (no human button press).
## Set by the headless test harness so battles don't hang awaiting input.
var test_mode: bool = false


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
	PartyManager.reset()
	ActivityHistory.clear()
	player_count = clampi(player_count, PlayerManager.MIN_PLAYERS, PlayerManager.MAX_PLAYERS)
	_reset_campaign_ledgers()
	for i in player_count:
		PlayerManager.add_player()

	game_in_progress = true

	# Go to character creation
	change_state(GameState.CHARACTER_CREATION)


## Called when all players have created their characters.
func on_character_creation_complete() -> void:
	PartyManager.initialize_campaign_companions(active_campaign.get("companions", {}))
	change_state(GameState.OVERWORLD)


## Enter combat from the overworld or a dungeon.
func enter_combat(monster_ids: Array, surprise: bool = false, return_state: GameState = GameState.OVERWORLD, terrain: String = "plains", local_room: Dictionary = {}, ambient_light: String = "") -> void:
	if ContainmentRules.active(local_room):
		push_warning("Contained bodies cannot enter an encounter yet.")
		return
	var context := {
		"monster_ids": monster_ids,
		"surprise": surprise,
		"return_state": return_state,
		"terrain": terrain,
		"local_room": local_room,
	}
	if not ambient_light.is_empty():
		context["ambient_light"] = ambient_light
	change_state(GameState.COMBAT, context)


## Exit combat and return to the previous state.
func exit_combat(result: String) -> void:
	var return_state: GameState = transition_context.get("return_state", GameState.OVERWORLD)
	change_state(return_state, {"combat_result": result})


## Enter a dungeon from the overworld.
func enter_dungeon(dungeon_id: String) -> void:
	active_dungeon_state = dungeon_snapshots.get(dungeon_id, {}).duplicate(true)
	change_state(GameState.DUNGEON, {"dungeon_id": dungeon_id})


## Exit a dungeon and return to the overworld.
func exit_dungeon() -> void:
	for room in active_dungeon_state.get("local_rooms", {}).values():
		if room.get("containment_occupants", []).any(func(r): return r.container_kind == "character" or r.occupant_kind == "character"):
			push_warning("Release contained party bodies before leaving the dungeon.")
			return
	remember_dungeon()
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
	if not game_in_progress:
		return
	game_in_progress = false
	campaign_completed = victory
	var terminal_state: GameState = GameState.COMPLETION if victory else GameState.DEFEAT
	change_state(terminal_state, {"victory": victory, "reason": reason})


## Return to main menu.
func return_to_menu() -> void:
	game_in_progress = false
	PlayerManager.reset()
	PartyManager.reset()
	ActivityHistory.clear()
	active_campaign = {}
	transition_context = {}
	active_dungeon_state.clear()
	defeated_monsters.clear()
	_reset_campaign_ledgers()
	change_state(GameState.MAIN_MENU)


## Get the campaign's win condition data.
func get_win_condition() -> Dictionary:
	return active_campaign.get("win_condition", {})


## Get the campaign's milestone definitions.
func get_milestones() -> Array:
	return active_campaign.get("milestones", [])


## Return player-facing campaign progress lines with stable counts and status.
func get_campaign_objectives() -> Array[String]:
	var result: Array[String] = []
	var win_cond := get_win_condition()
	for goal in win_cond.get("goals", []):
		var goal_type := str(goal.get("type", ""))
		if goal_type == "collect_item":
			var item_id := str(goal.get("item_id", ""))
			var required := int(goal.get("count", 1))
			var owned := 0
			for character in PartyManager.get_active_characters():
				owned += character.inventory.count_item(item_id)
			var item_name := str(DataLoader.get_item(item_id).get("name", item_id))
			result.append("%s Find %s (%d/%d)" % ["✓" if owned >= required else "○", item_name, mini(owned, required), required])
		elif goal_type == "defeat_monster":
			var monster_id := str(goal.get("monster_id", ""))
			var monster_name := str(DataLoader.get_monster(monster_id).get("name", monster_id))
			result.append("%s Defeat %s" % ["✓" if monster_id in defeated_monsters else "○", monster_name])
		else:
			result.append("○ %s" % goal_type.capitalize())

	for milestone in get_milestones():
		var trigger := str(milestone.get("trigger", ""))
		if trigger.is_empty() or trigger in completed_milestones:
			continue
		result.append("Next: %s" % str(milestone.get("description", trigger)))
		break
	return result


func are_win_conditions_met() -> bool:
	var win_cond := get_win_condition()
	if win_cond.is_empty() or str(win_cond.get("type", "")) != "goal":
		return false
	for goal in win_cond.get("goals", []):
		match str(goal.get("type", "")):
			"collect_item":
				var required := int(goal.get("count", 1))
				var total := 0
				for character in PartyManager.get_active_characters():
					total += character.inventory.count_item(str(goal.get("item_id", "")))
				if total < required:
					return false
			"defeat_monster":
				if str(goal.get("monster_id", "")) not in defeated_monsters:
					return false
			_:
				return false
	return true


## Check a milestone trigger. Returns true if a milestone was activated.
func check_milestone(trigger: String) -> bool:
	if trigger in completed_milestones:
		return false
	var milestones: Array = get_milestones()
	for milestone in milestones:
		if milestone.get("trigger", "") == trigger:
			# Apply milestone effects
			var effects: Array = milestone.get("effects", [])
			for effect in effects:
				_apply_milestone_effect(effect)
			completed_milestones.append(trigger)
			return true
	return false


## Claim a dungeon's one-time clear transition. Returns false on replay.
func mark_dungeon_cleared(dungeon_id: String) -> bool:
	if dungeon_id.is_empty() or dungeon_id in cleared_dungeons:
		return false
	cleared_dungeons.append(dungeon_id)
	return true


func claim_reward(reward_id: String) -> bool:
	if reward_id.is_empty() or reward_id in claimed_rewards:
		return false
	claimed_rewards.append(reward_id)
	return true


func record_overworld_location(coord: Vector2i, location_name: String = "") -> void:
	var location_id := "%d,%d" % [coord.x, coord.y]
	for location in visited_overworld_locations:
		if str(location.get("id", "")) == location_id:
			return
	var display_name := location_name.strip_edges()
	if display_name.is_empty():
		display_name = "Wilderness hex (%d, %d)" % [coord.x, coord.y]
	visited_overworld_locations.append({"id": location_id, "name": display_name, "coord": [coord.x, coord.y]})


func get_visited_overworld_locations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for location in visited_overworld_locations:
		result.append(location.duplicate(true))
	return result


func validate_animal_messenger_order(order: Dictionary) -> Dictionary:
	return AnimalMessengerRulesRef.validate_order(order, get_visited_overworld_locations())


func register_animal_messenger(caster: Character, origin: Vector2i, spell_slot_level: int, can_fly: bool, order: Dictionary) -> Dictionary:
	if caster == null or animal_messenger_deliveries.size() >= AnimalMessengerRulesRef.MAX_SAVED_DELIVERIES:
		return {"success": false, "message": "The campaign cannot record another messenger right now."}
	var validated := AnimalMessengerRulesRef.validate_order(order, get_visited_overworld_locations())
	if not bool(validated.get("success", false)):
		return validated
	var destination: Dictionary = {}
	for location in visited_overworld_locations:
		if str(location.get("id", "")) == str(validated.get("destination_id", "")):
			destination = location.duplicate(true)
			break
	if destination.is_empty():
		return {"success": false, "message": "That visited location is no longer available."}
	var duration_seconds := (1 + maxi(0, spell_slot_level - 2) * 2) * 86400
	var delivery_id := "animal-messenger-%06d" % next_animal_messenger_id
	while animal_messenger_deliveries.any(func(existing: Dictionary) -> bool: return str(existing.get("id", "")) == delivery_id):
		next_animal_messenger_id += 1
		delivery_id = "animal-messenger-%06d" % next_animal_messenger_id
	next_animal_messenger_id += 1
	var miles_per_hex := float(active_campaign.get("map", {}).get("miles_per_hex", AnimalMessengerRulesRef.MILES_PER_OVERWORLD_HEX))
	var delivery := AnimalMessengerRulesRef.create_delivery(
		delivery_id,
		caster.character_id,
		caster.character_name,
		origin,
		destination,
		str(validated.get("recipient", "")),
		str(validated.get("message", "")),
		duration_seconds,
		can_fly,
		miles_per_hex
	)
	# The target may be the cast hex; dispatch starts when the next campaign time elapses.
	animal_messenger_deliveries.append(delivery)
	return {"success": true, "delivery": delivery.duplicate(true), "message": "%s sets out toward %s." % [caster.character_name, str(destination.get("name", "the visited location"))]}


func advance_campaign_time(elapsed_seconds: int) -> Array[Dictionary]:
	if elapsed_seconds <= 0:
		return []
	var prior_seconds := campaign_elapsed_seconds
	var prior_day := floori(float(campaign_elapsed_seconds) / 86400.0)
	campaign_elapsed_seconds += elapsed_seconds
	var recovery_receipts: Array[Dictionary] = []
	var work_receipts: Array = []
	for character in PartyManager.characters.values():
		if character is Character:
			recovery_receipts.append_array(ResourcePoolRules.advance_campaign_recovery(character, prior_seconds, campaign_elapsed_seconds))
	var current_day := floori(float(campaign_elapsed_seconds) / 86400.0)
	for day in range(prior_day, current_day):
		for character in PartyManager.characters.values():
			character.inventory.recover_daily_charges()
			OwnedFeatureSources.recover_dawn(character) # Batch 050: SRD 5.2.1 p.206 item recharge at dawn.
			SurvivalRules.settle_day(character, (day + 1) * 86400)
		OwnedFeatureSources.recover_dawn_rooms(saved_local_room_states()) # Brandon: dawn items recharge lying in rooms too.
	SpellEffects.advance_time(PartyManager.characters.values(), elapsed_seconds)
	var containment_receipts: Array[Dictionary] = []
	for room_state in saved_local_room_states():
		containment_receipts.append_array(ContainmentRules.advance_internal_damage(room_state, PartyManager.characters.values(), campaign_elapsed_seconds))
		LocatedSourceEndRules.observe(room_state, PartyManager.characters.values())
	remember_dungeon() # Commit consumed children to the dormant snapshot too.
	AnimatedObjectRules.reconcile()
	for room_state in saved_local_room_states():
		LocalRoomAreas.expire(room_state, campaign_elapsed_seconds)
	for character in PartyManager.characters.values():
		CapturedGrantRules.prune(character,campaign_elapsed_seconds)
		ProtectionRules.prune(character,campaign_elapsed_seconds)
		character.expire_campaign_modifiers(campaign_elapsed_seconds)
		LightSourceRules.advance_inventory(character.inventory, elapsed_seconds)
		ActiveTimeRules.settle(character, elapsed_seconds, campaign_elapsed_seconds)
		work_receipts.append_array(WorkRules.settle(character, elapsed_seconds, campaign_elapsed_seconds)) # Batch 074: site pauses/interruptions reach the log.
		BarbarianRules.advance_rage_time(character, elapsed_seconds)
		BardicInspirationRules.advance_time(character, elapsed_seconds)
		CorpseRules.advance_time(character, campaign_elapsed_seconds)
	var result := AnimalMessengerRulesRef.advance_deliveries(animal_messenger_deliveries, elapsed_seconds)
	animal_messenger_deliveries.assign(result.get("deliveries", []))
	var notifications: Array[Dictionary] = result.get("notifications", [])
	notifications.append_array(containment_receipts)
	for receipt in work_receipts:
		if receipt is Dictionary and receipt.has("message"): notifications.append(receipt)
	for receipt in recovery_receipts:
		notifications.append({"type":"resource_pool_recovered", "receipt":receipt})
	return notifications


func _reset_campaign_ledgers() -> void:
	created_creatures.clear()
	next_created_creature_id = 1
	dungeon_snapshots.clear()
	completed_milestones.clear()
	cleared_dungeons.clear()
	claimed_rewards.clear()
	recruited_companions.clear()
	dismissed_companions.clear()
	visited_overworld_locations.clear()
	animal_messenger_deliveries.clear()
	campaign_elapsed_seconds = 0
	next_animal_messenger_id = 1
	campaign_completed = false


func remember_dungeon() -> void:
	var id := str(active_dungeon_state.get("dungeon_id", ""))
	if not id.is_empty():
		dungeon_snapshots[id] = SaveManager._serialize_dungeon_state(active_dungeon_state)


## Visit only existing saved room records. These dictionaries share the
## campaign's current state; no scenes or new room generation are involved.
func saved_local_room_states() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var active_id := str(active_dungeon_state.get("dungeon_id", ""))
	for dungeon in [active_dungeon_state] + dungeon_snapshots.values():
		if dungeon is Dictionary:
			# A dormant copy of the active dungeon is not another world. Ticking
			# both copies would replay source-end healing and other once-only work.
			if not is_same(dungeon, active_dungeon_state) and not active_id.is_empty() and str(dungeon.get("dungeon_id", "")) == active_id: continue
			for room_state in dungeon.get("local_rooms", {}).values():
				if room_state is Dictionary: result.append(room_state)
	var transition_room: Variant = transition_context.get("local_room", null)
	if transition_room is Dictionary and not transition_room.is_empty():
		var found := false
		for index in result.size():
			if is_same(result[index], transition_room): found = true; break
			if active_dungeon_state.get("local_rooms", {}).values().any(func(room): return is_same(room, result[index])) and str(result[index].get("id", "")) == str(transition_room.get("id", "")):
				result[index] = transition_room
				found = true
				break
		if not found: result.append(transition_room)
	return result


func clear_room_area_concentration(caster: Character) -> void:
	if caster == null: return
	var spell_id := str(caster.concentrating_on.get("spell_id", ""))
	var source_id := str(caster.concentrating_on.get("%s_source_id" % spell_id, ""))
	if source_id.is_empty(): return
	for room_state in saved_local_room_states():
		LocalRoomAreas.remove_concentration(room_state, caster.character_id, spell_id, source_id)


## Apply a single milestone effect.
func _apply_milestone_effect(effect: Dictionary) -> void:
	var effect_type: String = effect.get("type", "")
	match effect_type:
		"level_up":
			# Level up every active party member, including recruited companions.
			for character in PartyManager.get_active_characters():
				character.level_up()
				print("[GameManager] %s leveled up!" % character.character_name)
		_:
			push_warning("[GameManager] Unknown milestone effect type: %s" % effect_type)


## Check if campaign win conditions are met
func check_campaign_victory() -> void:
	if not game_in_progress or active_campaign.is_empty():
		return
	if are_win_conditions_met():
		end_game(true, "Campaign goals completed!")
