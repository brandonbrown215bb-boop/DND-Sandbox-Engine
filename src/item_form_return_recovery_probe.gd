extends Node

func _ready() -> void:
	ItemFormReturnChecks.load_fixtures()
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://item_form_return_manifest.json"))
	if not manifest is Dictionary or int(manifest.get("pid", 0)) == OS.get_process_id(): return _fail("Fresh process manifest missing")
	if not ItemFormReturnControls.verify(manifest): return _fail("Exact item return/overflow did not recover")
	print("ITEM FORM RETURN FRESH-PROCESS RECOVERY PASSED")
	get_tree().quit()

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
