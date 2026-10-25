extends Node

func _ready() -> void:
	ItemLifecycleControlsFlow.load_fixtures()
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://item_lifecycle_manifest.json"))
	if not manifest is Dictionary or int(manifest.get("pid", 0)) == OS.get_process_id() or not ItemLifecycleControlsFlow.verify(manifest):
		push_error("Item control checkpoint recovery failed")
		get_tree().quit(1)
		return
	print("ITEM LIFECYCLE FRESH-PROCESS RECOVERY PASSED")
	get_tree().quit()
