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
var _exchange_window: Dictionary = {}
var _exchange_serial: int = 0
var _entry_open: bool = true
var _exchange_offered: Dictionary = {}

## One d20-test owner for encounter entry, late arrivals and rolled groups.
## Groups capture the first authored member's live modes once, then keep the count.
static func roll_result(actor, dex: int = -1, decisions: Dictionary = {}) -> Dictionary:
	if dex < 0:
		dex = actor.ability_scores.get_score("DEX") if actor is Character else int(actor.get("ability_scores", {}).get("DEX", 10))
	var advantage := CombatAction.is_invisible(actor)
	if actor is Character:
		advantage = advantage or actor.has_feature("champion_remarkable_athlete") or actor.has_feature_effect("initiative_advantage")
	var result := RollTokenRules.resolve_d20_test(actor, "initiative", advantage, CombatAction.is_incapacitated(actor) or (actor is Character and actor.untrained_worn_armor()), decisions)
	var exhaustion: int = actor.exhaustion_level if actor is Character else int(actor.get("exhaustion_level", actor.get("conditions", {}).get("exhaustion", 0)))
	result["modifier"] = AbilityScores.get_modifier(dex) - exhaustion * 2
	if actor is Character and FeatRules.initiative_benefit(actor, "proficiency"):
		result["modifier"] += actor.proficiency_bonus
	result["total"] = int(result.get("total", 1)) + int(result.modifier)
	return result


## Clear all tracked combatants.
func clear() -> void:
	combatants.clear()
	active_index = 0
	current_round = 1
	shared_groups.clear()
	_started_counts.clear()
	_shared_members.clear()
	_exchange_window.clear()
	_exchange_serial += 1
	_entry_open = true
	_exchange_offered.clear()


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


## A window is bound to this tracker, exact entries and one response. It cannot
## survive an encounter reset, a turn start, or either participant leaving.
func begin_exchange(owner_id: String) -> int:
	if not _exchange_window.is_empty() or not _entry_open or _exchange_offered.has(owner_id): return -1
	var owner := _exchange_entry(owner_id)
	if owner.is_empty() or not owner.entity is Character or not FeatRules.initiative_benefit(owner.entity, "willing_exchange") or CombatAction.is_incapacitated(owner.entity): return -1
	_exchange_offered[owner_id] = true
	_exchange_serial += 1
	_exchange_window = {"token": _exchange_serial, "owner": owner, "owner_entity": owner.entity}
	return _exchange_serial

func _exchange_entry(id: String) -> Dictionary:
	for entry in combatants:
		if str(entry.id) == id: return entry
	return {}

func exchange_candidates(token: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not _entry_open or _exchange_window.is_empty() or int(_exchange_window.get("token", -1)) != token: return out
	var owner: Dictionary = _exchange_window.owner
	if not combatants.any(func(entry): return is_same(entry, owner)) or owner.entity != _exchange_window.owner_entity or CombatAction.is_incapacitated(owner.entity): return out
	for entry in combatants:
		if entry != owner and entry.get("is_player", false) and entry.get("exchange_eligible", true) and entry.entity is Character and not entry.get("scheduling_only", false) and not CombatAction.is_incapacitated(entry.entity): out.append(entry)
	return out

func bind_exchange_target(token: int, target: Dictionary) -> bool:
	if not exchange_candidates(token).any(func(entry): return is_same(entry, target)): return false
	_exchange_window["target"] = target
	_exchange_window["target_entity"] = target.entity
	return true

func close_exchange_entry() -> void:
	_entry_open = false
	_exchange_window.clear()

func settle_exchange(token: int, target: Dictionary, willing: bool) -> bool:
	var candidates := exchange_candidates(token)
	if _exchange_window.is_empty() or int(_exchange_window.get("token", -1)) != token: return false
	var owner: Dictionary = _exchange_window.owner
	var bound: bool = is_same(_exchange_window.get("target", {}), target) and _exchange_window.get("target_entity") == target.get("entity")
	_exchange_window.clear()
	if not bound or not willing or target.is_empty() or not candidates.any(func(entry): return is_same(entry, target)) or not FeatRules.initiative_benefit(owner.entity, "willing_exchange"): return false
	var value: int = owner.roll
	owner.roll = target.roll
	target.roll = value
	return true

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
func add_shared_combatant(id: String, name: String, entity: Character, group_id: String, count_policy: String, anchor: Dictionary, dex: int, representative: Character = null) -> void:
	if combatants.any(func(c): return str(c.id) == id): return
	if not shared_groups.has(group_id):
		var receipt := {} if count_policy == "owner" else roll_result(representative if representative != null else entity, dex)
		shared_groups[group_id] = {"roll": anchor.roll if count_policy == "owner" else receipt.total, "dex": anchor.dex if count_policy == "owner" else dex, "follows": str(anchor.id) if count_policy == "owner" else "", "initiative_test": receipt}
	var group: Dictionary = shared_groups[group_id]
	var late := int(_started_counts.get(int(group.roll), -1)) == current_round
	if not _shared_members.has(id): _shared_members[id] = {"eligible_round": current_round + 1 if late else current_round, "started_round": -1}
	var member: Dictionary = _shared_members[id]
	var acted := int(member.started_round) == current_round
	combatants.append({"id": id, "name": name, "is_player": true, "entity": entity, "roll": group.roll, "dex": group.dex, "shared_group": group_id, "follows": group.follows, "has_acted": acted, "eligible_round": member.eligible_round})
	sort_initiative_preserving_active()


## Called at the actual turn boundary, before any action or suspended choice.
func mark_turn_started() -> void:
	_entry_open = false
	_exchange_window.clear()
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
