## Initiative Tracker
## Sorts and manages combat participants based on d20 + DEX initiative rolls.
class_name InitiativeTracker
extends RefCounted

## Combatant structure:
##   - "id": String (unique instance ID)
##   - "name": String
##   - "is_player": bool
##   - "entity": Character (Player) or Dictionary (Monster)
##   - "roll": int
##   - "dex": int
var combatants: Array[Dictionary] = []
var active_index: int = 0
var current_round: int = 1


## Clear all tracked combatants.
func clear() -> void:
	combatants.clear()
	active_index = 0
	current_round = 1


## Add a participant.
func add_combatant(id: String, name: String, is_player: bool, entity, roll: int, dex: int) -> void:
	combatants.append({
		"id": id,
		"name": name,
		"is_player": is_player,
		"entity": entity,
		"roll": roll,
		"dex": dex,
		"has_acted": false
	})


## Sort initiative: highest roll first, then highest DEX, then stable ID.
## The final key must be deterministic and transitive; a random comparator can
## violate the sort contract when three or more participants tie.
func sort_initiative() -> void:
	combatants.sort_custom(func(a, b):
		if a["roll"] != b["roll"]:
			return a["roll"] > b["roll"]
		if a["dex"] != b["dex"]:
			return a["dex"] > b["dex"]
		return str(a["id"]) < str(b["id"])
	)
	active_index = 0
	current_round = 1


func sort_initiative_preserving_active() -> void:
	var active_id := str(get_active().get("id", ""))
	combatants.sort_custom(func(a, b):
		if a["roll"] != b["roll"]:
			return a["roll"] > b["roll"]
		if a["dex"] != b["dex"]:
			return a["dex"] > b["dex"]
		return str(a["id"]) < str(b["id"])
	)
	for index in combatants.size():
		if str(combatants[index].get("id", "")) == active_id:
			active_index = index
			return


## Get the currently active combatant.
func get_active() -> Dictionary:
	if combatants.is_empty():
		return {}
	return combatants[active_index]


## Advance initiative to the next combatant. Returns true if a new combat round begins.
func next_turn() -> bool:
	if combatants.is_empty():
		return false

	# Mark current as acted (only if index is valid)
	if active_index >= 0 and active_index < combatants.size():
		combatants[active_index]["has_acted"] = true

	# Advance
	active_index += 1
	
	# Check if round complete
	if active_index >= combatants.size():
		active_index = 0
		current_round += 1
		# Reset has_acted for next round
		for c in combatants:
			c["has_acted"] = false
		return true

	return false


## Remove a combatant (e.g. if they died during battle).
func remove_combatant(id: String) -> void:
	var remove_idx := -1
	for i in combatants.size():
		if combatants[i]["id"] == id:
			remove_idx = i
			break

	if remove_idx >= 0:
		combatants.remove_at(remove_idx)
		# Correct active index pointer if shifted
		if remove_idx < active_index:
			active_index -= 1
		elif remove_idx == active_index:
			# Active combatant was removed. The next combatant is now at active_index.
			# Decrement by 1 so that next_turn() increments back to active_index.
			active_index -= 1
