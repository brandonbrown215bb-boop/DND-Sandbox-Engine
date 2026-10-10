## Export the registry after the project's autoloads have initialized.
## Run: Godot --headless --path . res://scenes/spell_inventory_export.tscn
extends Node

func _ready() -> void:
	var loader := get_node_or_null("/root/DataLoader")
	if loader == null or not loader.get_load_errors().is_empty():
		push_error("Spell inventory requires a valid production DataLoader registry.")
		get_tree().quit(1)
		return
	var destination := "res://.artifacts/spell-status/runtime.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			destination = argument.trim_prefix("--output=")
	var memberships: Dictionary = {}
	for class_id in ["bard", "cleric", "druid", "paladin", "ranger", "sorcerer", "warlock", "wizard"]:
		var ids: Array[String] = []
		for spell in loader.get_spell_list_options([class_id]):
			ids.append(str(spell["id"]))
		ids.sort()
		memberships[class_id] = ids
	var availability: Dictionary = {}
	var support := load("res://src/spells/spell_support.gd")
	for spell in loader.get_all_spells():
		availability[str(spell["id"])] = support.availability(spell)
	var absolute_destination := ProjectSettings.globalize_path(destination)
	DirAccess.make_dir_recursive_absolute(absolute_destination.get_base_dir())
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write spell inventory: %s" % destination)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify({"schema_version": 1, "spells": loader.get_all_spells(), "class_lists": memberships, "cast_availability": availability, "registry_hash": loader.get_registry_hash()}, "\t", true))
	file.close()
	print("SPELL INVENTORY EXPORTED: %d unique spells" % loader.get_all_spells().size())
	get_tree().quit(0)
