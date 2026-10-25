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
## Encounter-local clocks survive an empty/rebuilt source group. A count which
## has begun cannot admit new members until the next round.
var shared_groups: Dictionary = {}
var _started_counts: Dictionary = {}
var _shared_members: Dictionary = {}


## Clear all tracked combatants.
func clear() -> void:
	combatants.clear()
	active_index = 0
	current_round = 1
	shared_groups.clear()
	_started_counts.clear()
	_shared_members.clear()


## Add a participant.
func add_combatant(id: String, name: String, is_player: bool, entity, roll: int, dex: int) -> void:
	# Re-entry replaces a scheduling anchor in place, retaining its round history.
	for c in combatants:
		if str(c.id) == id:
			if c.get("scheduling_only", false):
				c.erase("scheduling_only")
				c.erase("resume_when_available")
				c.merge({"name": name, "is_player": is_player, "entity": entity}, true)
			return
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
	combatants.sort_custom(_initiative_before)
	regroup_followers()
	active_index = 0
	current_round = 1


func sort_initiative_preserving_active() -> void:
	var active_id := str(get_active().get("id", ""))
	combatants.sort_custom(_initiative_before)
	regroup_followers()
	for index in combatants.size():
		if str(combatants[index].get("id", "")) == active_id:
			active_index = index
			return


func _initiative_before(a: Dictionary, b: Dictionary) -> bool:
	if a.roll != b.roll: return a.roll > b.roll
	if a.dex != b.dex: return a.dex > b.dex
	var a_group := str(a.get("shared_group", a.id))
	var b_group := str(b.get("shared_group", b.id))
	if a_group != b_group: return a_group < b_group
	return str(a.id) < str(b.id)


## One source supplies one count, but every member remains a normal combatant.
## Rejoining a started member never replays it, even after the group was empty.
func add_shared_combatant(id: String, name: String, entity: Character, group_id: String, count_policy: String, anchor: Dictionary, dex: int) -> void:
	if combatants.any(func(c): return str(c.id) == id): return
	if not shared_groups.has(group_id):
		shared_groups[group_id] = {"roll": anchor.roll if count_policy == "owner" else Dice.roll(20) + AbilityScores.get_modifier(dex), "dex": anchor.dex if count_policy == "owner" else dex, "follows": str(anchor.id) if count_policy == "owner" else ""}
	var group: Dictionary = shared_groups[group_id]
	var late := int(_started_counts.get(int(group.roll), -1)) == current_round
	if not _shared_members.has(id): _shared_members[id] = {"eligible_round": current_round + 1 if late else current_round, "started_round": -1}
	var member: Dictionary = _shared_members[id]
	var acted := int(member.started_round) == current_round
	combatants.append({"id": id, "name": name, "is_player": true, "entity": entity, "roll": group.roll, "dex": group.dex, "shared_group": group_id, "follows": group.follows, "has_acted": acted, "eligible_round": member.eligible_round})
	sort_initiative_preserving_active()


## Called at the actual turn boundary, before any action or suspended choice.
func mark_turn_started() -> void:
	var active := get_active()
	if active.is_empty(): return
	_started_counts[int(active.roll)] = current_round
	if active.has("shared_group"): _shared_members[str(active.id)].started_round = current_round


## Get the currently active combatant.
func get_active() -> Dictionary:
	if combatants.is_empty() or active_index < 0 or active_index >= combatants.size():
		return {}
	return combatants[active_index]


## Advance initiative to the next combatant. Returns true if a new combat round begins.
func next_turn() -> bool:
	if combatants.is_empty():
		return false

	# Mark current as acted (only if index is valid)
	if active_index >= 0 and active_index < combatants.size():
		combatants[active_index]["has_acted"] = true

	var wrapped := false
	while true:
		active_index += 1
		if active_index >= combatants.size():
			active_index = 0
			current_round += 1
			wrapped = true
			for c in combatants: c["has_acted"] = false
		var candidate := get_active()
		if (not candidate.has("shared_group") or not candidate.has_acted) and int(candidate.get("eligible_round", 1)) <= current_round: return wrapped
	return wrapped


## Remove a combatant (e.g. if they died during battle).
func remove_combatant(id: String) -> void:
	var remove_idx := -1
	for i in combatants.size():
		if combatants[i]["id"] == id:
			remove_idx = i
			break

	if remove_idx >= 0:
		var removed := combatants[remove_idx]
		if not removed.get("created_actor_dependents", []).is_empty():
			# Keep only the clock for linked creatures, never another owner turn.
			removed["scheduling_only"] = true
			removed["resume_when_available"] = removed.entity is Character and not removed.entity.is_alive
			return
		combatants.remove_at(remove_idx)
		# Correct active index pointer if shifted
		if remove_idx < active_index:
			active_index -= 1
		elif remove_idx == active_index:
			# Active combatant was removed. The next combatant is now at active_index.
			# Decrement by 1 so that next_turn() increments back to active_index.
			active_index -= 1


## Batch 061 review R1: an entry with "follows" (an after_owner created actor)
## must stay directly behind its anchor (and earlier followers) after any re-sort,
## even when another combatant ties the anchor on roll and DEX.
func regroup_followers() -> void:
	var followers := combatants.filter(func(c): return not str(c.get("follows", "")).is_empty() and combatants.any(func(o): return str(o.id) == str(c.follows)))
	if followers.is_empty(): return
	# Legacy after-owner actors first, then exact source groups and member IDs.
	followers.sort_custom(func(a, b):
		var ag := str(a.get("shared_group", ""))
		var bg := str(b.get("shared_group", ""))
		if ag.is_empty() and bg.is_empty(): return _initiative_before(a, b)
		return ag < bg if ag != bg else str(a.id) < str(b.id)
	)
	var rest := combatants.filter(func(c): return not followers.has(c))
	var out: Array = []
	for c in rest:
		out.append(c)
		for f in followers:
			if str(f.follows) == str(c.id): out.append(f)
	combatants.assign(out)
