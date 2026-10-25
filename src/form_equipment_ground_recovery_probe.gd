extends Node

func _ready() -> void:
	FormEquipmentGroundChecks.load_fixtures()
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://form_ground_manifest.json"))
	if not manifest is Dictionary or int(manifest.get("pid", 0)) == OS.get_process_id(): return _fail("Fresh process manifest missing")
	if not SaveManager.load_game(FormEquipmentGroundControls.SLOT): return _fail("Ground checkpoint refused")
	if not FormEquipmentGroundControls.verify(manifest): return _fail("Split ownership, destroyed copy or reversion did not recover")
	print("FORM EQUIPMENT GROUND FRESH-PROCESS RECOVERY PASSED")
	get_tree().quit()

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
