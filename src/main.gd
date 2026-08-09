## Main Bootstrapper
## Boots up the game, initializes the random seed, and transitions to the main menu.
extends Node2D

func _ready() -> void:
	# Seed the RNG
	randomize()
	print("[Main] Game bootstrapper started. Transitioning to main menu...")
	
	# Small delay to ensure singletons are fully ready
	await get_tree().create_timer(0.1).timeout
	
	if GameManager.test_mode:
		print("[Main] Boot gate mode: leaving production scene in place")
		return

	# Transition to Main Menu
	GameManager.change_state(GameManager.GameState.MAIN_MENU)
