extends Node2D

func _ready() -> void:
	DataLoader.load_all_data()
	await get_tree().create_timer(0.3).timeout
	var evd: Node = load("res://scenes/ui/event_dialog.tscn").instantiate()
	add_child(evd)
	var scores := AbilityScores.new()
	scores.from_dict({"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
	var ch := Character.new()
	ch.initialize("Probe", "human", "fighter", scores)
	# Find a skill_check event (rockslide)
	var evt := {}
	for tbl_id in DataLoader.events.keys():
		var tbl: Dictionary = DataLoader.events[tbl_id]
		for e in tbl.get("events", []):
			if e.get("type", "") == "skill_check":
				evt = e
				break
		if not evt.is_empty():
			break
	evd.popup_event(ch, evt)
	await get_tree().create_timer(0.3).timeout
	# 1) Print roll button rect (local in this bare scene, but shows relative layout)
	var rr: Rect2 = evd.btn_roll.get_global_rect()
	print("[PROBE] btn_roll local_rect pos=(%d,%d) size=(%d,%d) center=(%d,%d)" % [
		int(rr.position.x), int(rr.position.y), int(rr.size.x), int(rr.size.y),
		int(rr.get_center().x), int(rr.get_center().y)])
	# 2) Programmatically emit the pressed signal to confirm the HANDLER works
	print("[PROBE] emitting btn_roll.pressed ...")
	evd.btn_roll.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	print("[PROBE] btn_roll.disabled after emit = %s" % evd.btn_roll.disabled)
	print("[PROBE] roll_result_lbl.text = '%s'" % evd.roll_result_lbl.text)
	print("[PROBE] DONE")
	get_tree().quit(0)
