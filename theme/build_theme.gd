## Validate the authored grimoire theme; this entry point no longer replaces it
## with a second, hardcoded palette. Edit main_theme.tres and the profile in Godot.
extends SceneTree

func _initialize() -> void:
	var theme := load("res://theme/main_theme.tres") as Theme
	if theme == null:
		push_error("The authored UI Theme could not be loaded.")
		quit(1)
		return
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		if not theme.has_stylebox(state, "Button"):
			push_error("UI Theme is missing Button/%s." % state)
			quit(1)
			return
	print("Authored grimoire Theme validated. No files were overwritten.")
	quit()
