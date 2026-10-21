## Per-turn action and reaction budget for a combatant.
##
## CombatState still owns presentation and turn sequencing. This object owns
## only the mutable budget that those responsibilities consume, so action
## economy can be tested without constructing a complete combat scene.
class_name CombatTurnBudget
extends RefCounted

var has_acted_this_turn: bool = false
var action_available: bool = true
var bonus_action_available: bool = true
var surge_actions: int = 0


## Restore the active player's action, bonus-action, and reaction budget.
func reset(active_character: Character = null, player_entities: Array = []) -> void:
	has_acted_this_turn = false
	action_available = true
	bonus_action_available = true
	surge_actions = 0
	CombatAction.advance_combat_turn(active_character)
	if active_character == null:
		return
	active_character.reaction_available = true
	for player_entity in player_entities:
		if player_entity.get("character") == active_character:
			player_entity["reaction_available"] = true
			break


## Batch 063 (queue item 5, Brandon: "Yes."): the shared authored cost
## vocabulary used by mode costs (057/062) and command costs (060), mapped to
## the budget kind it spends. "magic" is the Magic action (SRD 5.2.1 p.185,
## Rules Glossary; p.10 Actions table): it spends the Action, but as the
## distinct magic_action kind, because Action Surge's extra action is "one
## additional action, except the Magic action" (SRD 5.2.1 p.48).
const AUTHORED_COSTS := {"action": "action", "bonus_action": "bonus_action", "magic": "magic_action"}

static func budget_kind(authored: String) -> String:
	return str(AUTHORED_COSTS.get(authored, authored))

## HUD label for an authored cost ("free"/"none" read as Free).
static func cost_label(authored: String) -> String:
	return {"none": "Free", "free": "Free", "action": "Action", "bonus_action": "Bonus Action", "magic": "Magic action"}.get(authored, authored.replace("_", " ").capitalize())


func can_use_turn_feature(character: Character, pool_id: String) -> bool:
	var pool := RollTokenRules.pool_definition(character, pool_id)
	return RollTokenRules.can_use_pool_this_turn(character, pool)


func can_spend(cost_type: String) -> bool:
	match cost_type:
		"action":
			return action_available or surge_actions > 0
		"magic_action":
			return action_available
		"bonus_action":
			return bonus_action_available
		"free":
			return true
	return false


func spend(cost_type: String) -> bool:
	if not can_spend(cost_type):
		return false
	match cost_type:
		"action":
			if surge_actions > 0:
				surge_actions -= 1
			else:
				action_available = false
			has_acted_this_turn = true
		"magic_action":
			action_available = false
			has_acted_this_turn = true
		"bonus_action":
			bonus_action_available = false
	return true


## Grant a main action again, as used by Action Surge.
func grant_action() -> void:
	action_available = true
	has_acted_this_turn = false


func grant_surge_action() -> void:
	surge_actions += 1
