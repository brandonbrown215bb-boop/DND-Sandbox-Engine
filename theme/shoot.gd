## Screenshot scene — boots inside the full game (autoloads available),
## captures combat + overworld HUDs to PNGs, then quits.
## Run: godot --headless --path . res://theme/shoot.tscn
extends Node

func _shot(inst: Node, path: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera2D.new()
	vp.add_child(cam)
	vp.add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	var tex := vp.get_texture()
	var img = tex.get_image() if (tex != null) else null
	if img != null:
		img.save_png(path)
		print("saved %s (%dx%d)" % [path, img.get_width(), img.get_height()])
	else:
		print("WARN: no image for %s" % path)
	vp.queue_free()

func _ready() -> void:
	var camp = DataLoader.campaigns.values()[0]
	GameManager.active_campaign = camp
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin", "goblin"]}
	GameManager.test_mode = true
	PlayerManager.reset()
	PlayerManager.add_player("Alice")
	PlayerManager.add_player("Bob")
	var s1 := AbilityScores.new(); s1.from_dict({"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
	var c1 := Character.new(); c1.initialize("Alice","human","fighter",s1)
	var s2 := AbilityScores.new(); s2.from_dict({"STR":8,"DEX":14,"CON":14,"INT":16,"WIS":12,"CHA":10})
	var c2 := Character.new(); c2.initialize("Bob","elf","wizard",s2)
	PlayerManager.set_player_character(0, c1)
	PlayerManager.set_player_character(1, c2)
	PlayerManager.start_game()

	var combat = load("res://scenes/combat.tscn").instantiate()
	await _shot(combat, "res://theme/shot_combat.png")
	combat.queue_free()

	var ow = load("res://scenes/overworld.tscn").instantiate()
	await _shot(ow, "res://theme/shot_overworld.png")
	ow.queue_free()

	get_tree().quit()
