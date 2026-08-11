## Presentation boundary for the end-of-combat payoff overlay.
##
## CombatState owns the battle outcome and transition policy. This presenter
## owns only overlay lifetime and the test-mode rule that keeps the harness's
## scene tree in place.
class_name CombatResultPresenter
extends RefCounted

const BattleResultOverlayScript := preload("res://src/combat/battle_result_overlay.gd")


## Present an outcome and return the player's requested next destination.
## In test mode the overlay is dismissed immediately and the outcome is
## returned without changing scenes.
func present(host: Node, result: String, test_mode: bool) -> String:
	if host == null:
		return ""
	var overlay := BattleResultOverlayScript.new()
	host.add_child(overlay)
	overlay.show_result(result)
	if test_mode:
		overlay.queue_free()
		return result
	var choice: String = await overlay.resolved
	overlay.queue_free()
	return choice
