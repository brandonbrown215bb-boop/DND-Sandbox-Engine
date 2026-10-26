## Export loaded class/subclass features and feats after the production DataLoader initializes.
## Inventory only: no availability decision is made here beyond what the loader already kept or rejected.
## Run: Godot --headless --path . res://scenes/feature_inventory_export.tscn -- --output=res://.artifacts/feature-status/runtime.json
extends Node

func _ready() -> void:
	var loader := get_node_or_null("/root/DataLoader")
	if loader == null or not loader.get_load_errors().is_empty():
		push_error("Feature inventory requires a valid production DataLoader registry.")
		get_tree().quit(1)
		return
	var destination := "res://.artifacts/feature-status/runtime.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			destination = argument.trim_prefix("--output=")
	var creation_ids: Array[String] = []
	for record in loader.get_all_classes():
		creation_ids.append(str(record["id"]))
	var feats: Array = []
	for id in loader.feats:
		feats.append(loader.feats[id])
	var payload := {
		"schema_version": 1,
		"registry_hash": loader.get_registry_hash(),
		"registry_hash_sha256": loader.get_registry_hash().sha256_text(),
		"content_layers": loader.get_content_layers(),
		"creation_class_ids": creation_ids,
		"classes": loader.classes.values(),
		"subclasses": loader.subclasses.values(),
		"feats": feats,
		"species": loader.get_all_races(),
		"validation_warnings": loader.get_validation_warnings(),
	}
	var absolute_destination := ProjectSettings.globalize_path(destination)
	DirAccess.make_dir_recursive_absolute(absolute_destination.get_base_dir())
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write feature inventory: %s" % destination)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(payload, "\t", true))
	file.close()
	print("FEATURE INVENTORY EXPORTED: %d classes, %d subclasses, %d feats" % [loader.classes.size(), loader.subclasses.size(), feats.size()])
	get_tree().quit(0)
