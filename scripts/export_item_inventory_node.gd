## Export the item registry after the project's autoloads have initialized.
## Run: Godot --headless --path . res://scenes/item_inventory_export.tscn
extends Node

func _ready() -> void:
	var loader := get_node_or_null("/root/DataLoader")
	if loader == null or not loader.get_load_errors().is_empty():
		push_error("Item inventory requires a valid production DataLoader registry.")
		get_tree().quit(1)
		return
	var destination := "res://.artifacts/items-audit/runtime.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			destination = argument.trim_prefix("--output=")
	var availability: Dictionary = {}
	for item in loader.get_all_items():
		availability[str(item["id"])] = _availability(item)
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write item inventory: %s" % destination)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify({"schema_version": 1, "items": loader.get_all_items(), "use_availability": availability, "layers": loader.get_content_layers(), "packs": loader.get_content_pack_ids(), "registry_hash_sha256": loader.get_registry_hash().sha256_text()}, "\t", true))
	file.close()
	print("ITEM INVENTORY EXPORTED: %d unique items" % loader.get_all_items().size())
	get_tree().quit(0)


## Mirrors the production consume gate in src/characters/inventory.gd (no new rules).
func _availability(item: Dictionary) -> Dictionary:
	var item_type := str(item.get("type", ""))
	if item.has("light_source"):
		return {"use": "light_source", "reason": ""}
	if item_type != "consumable":
		return {"use": "not_consumable", "reason": "That item cannot be consumed."}
	var effects: Array = item.get("effects", [])
	if effects.is_empty():
		return {"use": "refused", "reason": "no implemented effect"}
	for effect in effects:
		if not effect is Dictionary or not EventResolver.is_effect_supported(str(effect.get("type", ""))):
			return {"use": "refused", "reason": "unsupported effect %s" % str(effect.get("type", "")) if effect is Dictionary else "malformed effect"}
	return {"use": "supported_shared_effects", "reason": ""}
