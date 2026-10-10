extends Node

## Production-scene visual and input evidence in an isolated profile.
var failures := 0
const OUTPUT := "res://.artifacts/grimoire-captures/"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	print("[ui %s] %s" % ["ok" if ok else "FAIL", message])
	if not ok: failures += 1

func settle() -> void:
	for frame in 8: await get_tree().process_frame

func capture(name: String) -> void:
	await settle()
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		check(image.save_png(OUTPUT + name + ".png") == OK, "capture " + name)

func fixtures() -> void:
	GameManager.test_mode = true
	GameManager.active_campaign = DataLoader.campaigns.values()[0]
	PartyManager.reset()
	PlayerManager.reset()
	for spec in [{"name":"Sir Kaelen", "class":"fighter"}, {"name":"Elara", "class":"wizard"}, {"name":"Borin Stonebender", "class":"cleric"}, {"name":"Thalia Windrider", "class":"rogue"}]:
		var index := PlayerManager.get_player_count()
		PlayerManager.add_player(spec.name)
		var scores := AbilityScores.new()
		scores.from_dict({"STR":16,"DEX":12,"CON":14,"INT":16,"WIS":12,"CHA":10})
		var character := Character.new()
		character.initialize(spec.name, "human", spec["class"], scores)
		PlayerManager.set_player_character(index, character)
		PartyManager.register_player_character(index, character)
		if index == 2: character.conditions["poisoned"] = 1
		if index == 3: character.current_hp = 0
	PartyManager.initialize_campaign_companions(GameManager.active_campaign.get("companions", {}))
	ActivityHistory.clear()
	for index in 14:
		ActivityHistory.publish({"category":"system", "kind":"notice", "title":"Expedition journal", "summary":"The party reached Ashvale. The ruined gate stands open; distant footsteps echo beyond it.", "visibility":"public", "payload":{}})
	ActivityHistory.publish({"category":"roll","kind":"attack","actor":{"name":"Sir Kaelen"},"title":"Longsword","summary":"17 vs AC 14 · Hit; 8 slashing damage","outcome":{"code":"hit","label":"Hit"},"visibility":"public","payload":{"formula":"1d20 + 3 + 2","dice_terms":[{"count":1,"sides":20,"results":[12],"kept":[true],"label":"d20","subtotal":12}],"modifiers":[{"label":"Strength","value":3},{"label":"Proficiency","value":2}],"natural_total":12,"final_total":17,"comparison":{"kind":"armor_class","target":14,"margin":3,"result":"hit"}}})

func _run() -> void:
	var phase := OS.get_environment("UI_RELAUNCH_PHASE")
	if not phase.is_empty():
		await relaunch(phase)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	fixtures()
	var stat = load("res://scenes/ui/stat_bar.tscn").instantiate()
	stat.configure("HP", 24)
	stat.set_value(17)
	add_child(stat)
	check(stat._bar.max_value == 24 and stat._bar.value == 17 and stat._label.text == "17/24", "vitals configured before ready retain their values")
	stat.queue_free()
	var window := get_window()
	for resolution in [Vector2i(1280,720), Vector2i(1920,1080)]:
		window.size = resolution
		var suffix := "%dx%d" % [resolution.x,resolution.y]
		var menu = load("res://scenes/main_menu.tscn").instantiate()
		add_child(menu)
		await capture("menu-" + suffix)
		menu._open_setup(false)
		await capture("campaign-selector-" + suffix)
		menu._close_setup()
		Settings.open_settings()
		await capture("settings-" + suffix)
		check(ModalSurface.blocks_world(), "settings blocks gameplay while paused")
		key(KEY_ESCAPE)
		await settle()
		check(not Settings.is_open(), "Escape closes settings")
		menu.queue_free()
		await settle()
		var creation = load("res://scenes/ui/character_creation.tscn").instantiate()
		add_child(creation)
		creation.selected_race_id = "human"
		creation.selected_class_id = "wizard"
		creation.current_step = 1
		creation._update_step_ui()
		var wizard_button: Button
		for button in creation.class_grid.get_children():
			if button.get_meta("choice_id") == "wizard": wizard_button = button
		creation.class_panel.ensure_control_visible(wizard_button)
		await capture("creation-" + suffix)
		check(creation._name_input.is_visible_in_tree(), "editable character name remains visible")
		wizard_button.grab_focus()
		wizard_button.pressed.emit()
		check(is_instance_valid(wizard_button) and wizard_button.has_focus(), "selecting a class preserves its keyboard control")
		creation._name_input.text = "Elara Moonshadow"
		creation._name_input.text_changed.emit(creation._name_input.text)
		creation.current_step = 2
		creation._update_step_ui()
		creation.current_step = 1
		creation._update_step_ui()
		check(creation.selected_name == "Elara Moonshadow" and creation.selected_class_id == "wizard", "backtracking preserves edited name and class")
		creation.queue_free()
		await settle()
		for mode in ["combat", "overworld", "dungeon"]:
			GameManager.current_state = {"combat":GameManager.GameState.COMBAT,"overworld":GameManager.GameState.OVERWORLD,"dungeon":GameManager.GameState.DUNGEON}[mode]
			GameManager.transition_context = {"terrain":"plains","monster_ids":["goblin","goblin"]} if mode=="combat" else ({"dungeon_id":"ruins_of_ashvale"} if mode=="dungeon" else {})
			var scene = load("res://scenes/" + mode + ".tscn").instantiate()
			add_child(scene)
			await settle()
			if mode == "combat":
				for attempt in 40:
					if scene.hud.active_character != null: break
					await get_tree().create_timer(0.1).timeout
			var shell := scene.find_child("Root", true, false) as VttShell
			check(shell != null, mode + " mounts shared shell")
			check(shell.board.size.x >= resolution.x - 72 - (380 if resolution.x > 1600 else 320) and shell.board.size.y >= resolution.y - 120, mode + " usable board " + str(shell.board.size))
			check(not shell.allows_world_point(Vector2(30,100)) and not shell.allows_world_point(Vector2(resolution.x - 80,100)), mode + " chrome excludes board input")
			var camera := scene.get_node("Camera2D") as Camera2D
			camera.position += Vector2(20,10)
			if camera is CameraController: camera.center_on(camera.position)
			var pan := camera.position
			var zoom := camera.zoom
			await capture(mode + "-" + suffix)
			var rail := scene.find_child("ActivityContent",true,false) as ActivityRailWidget
			rail._set_filter("all")
			await settle()
			rail.card_scroll.scroll_vertical = 0
			await settle()
			ActivityHistory.publish({"category":"system","kind":"notice","title":"New notice","summary":"New activity should preserve your reading position.","visibility":"public","payload":{}})
			await settle()
			check(rail.card_scroll.scroll_vertical == 0, mode + " preserves older-history reading")
			check(rail._new_button.visible, mode + " offers new activity without moving the viewport")
			rail._jump_to_newest()
			await settle()
			check(rail._at_bottom() and not rail._new_button.visible, mode + " New returns to the latest activity")
			var record_count := ActivityHistory.get_records().size()
			rail._set_filter("roll")
			await settle()
			check(ActivityHistory.get_records().size() == record_count, "filter keeps stored history")
			await check_roll_details(rail)
			await capture(mode + "-rolls-" + suffix)
			rail._set_filter("all")
			shell.set_activity_open(false)
			await capture(mode + "-collapsed-" + suffix)
			check(camera.position == pan and camera.zoom == zoom, mode + " resizing chrome preserves pan and zoom")
			shell.set_activity_open(true)
			shell._show_inspector(PlayerManager.get_player(1).character)
			await capture(mode + "-inspector-" + suffix)
			check(shell.inspector.size.y < resolution.y - 48 and shell.inspector.position.y >= 48, mode + " inspector stays within the board edge")
			shell.inspector.hide()
			var opener := shell.find_child("GlobalMenuButton",true,false) as Button
			opener.grab_focus()
			CharacterSheet.show_active()
			await capture(mode + "-sheet-" + suffix)
			check(ModalSurface.blocks_world(), mode + " modal blocks world input")
			var grid := scene.find_child("HexGrid",true,false) as HexGrid
			var clicks := {"count":0}
			grid.hex_clicked.connect(func(_coord): clicks.count += 1)
			var tile_point := Vector2.ZERO
			for coord in grid.tiles:
				var candidate: Vector2 = grid.get_global_transform_with_canvas() * HexUtils.hex_to_pixel(coord)
				if shell.board.get_global_rect().has_point(candidate):
					tile_point = candidate
					break
			check(tile_point != Vector2.ZERO, mode + " input probe targets a real board tile")
			click(tile_point)
			check(clicks.count == 0, mode + " actual modal pointer input cannot reach hex selection")
			key(KEY_TAB)
			var focus := get_viewport().gui_get_focus_owner()
			check(focus != null and CharacterSheet._layer.is_ancestor_of(focus), mode + " Tab stays within the character sheet")
			key(KEY_ESCAPE)
			await settle()
			check(not CharacterSheet.is_open() and opener.has_focus(), mode + " Escape closes the sheet and restores focus")
			if mode == "combat":
				GameManager.test_mode = false
				probe_prompt(scene.hud)
				await capture("reaction-" + suffix)
				check(ModalSurface.blocks_world(), "reaction decision blocks world input")
				for child in scene.hud.get_children():
					if child is ConfirmationDialog:
						child.confirmed.emit()
				await settle()
				GameManager.test_mode = true
			if mode == "overworld":
				var hud = scene.find_child("OverworldHUD",true,false)
				hud.open_companion_roster()
				await capture("roster-" + suffix)
				key(KEY_ESCAPE)
				await settle()
				var shop = load("res://scenes/ui/shop.tscn").instantiate()
				shell.add_child(shop)
				shop.setup_shop("Ashvale")
				await capture("shop-" + suffix)
				shop.queue_free()
				await settle()
				var event = load("res://scenes/ui/event_dialog.tscn").instantiate()
				shell.add_child(event)
				event.popup_event(PlayerManager.get_player(0).character, {"name":"The Watcher's Gate", "description":"Beyond the cracked archway, a lantern swings in the wind. A traveler waits by the road. Choose how the party approaches.", "type":"choice", "choices":[{"text":"Offer help to the traveler", "effects":[]},{"text":"Watch from a safe distance", "effects":[]}]})
				await capture("event-" + suffix)
				event.queue_free()
				await settle()
			scene.queue_free()
			await settle()
		GameManager.current_state = GameManager.GameState.COMPLETION
		var outcome = load("res://scenes/completion.tscn").instantiate()
		add_child(outcome)
		await capture("victory-" + suffix)
		outcome._show_chronicle()
		await capture("final-chronicle-" + suffix)
		outcome.queue_free()
		await settle()
		GameManager.current_state = GameManager.GameState.DEFEAT
		var defeat = load("res://scenes/defeat.tscn").instantiate()
		add_child(defeat)
		await capture("defeat-" + suffix)
		defeat.queue_free()
		await settle()
	await large_viewports(window)
	await profile_check()
	print("UI POLISH PROBE: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	get_viewport().push_input(event)
	event = event.duplicate()
	event.pressed = false
	get_viewport().push_input(event)

func probe_prompt(hud: CombatHUD) -> void:
	var accepted := await hud.request_reaction("Sir Kaelen", "ui_probe", "A blade flashes past your guard. Choose whether to spend your reaction.", "Use a reaction?", "Use reaction", "Reaction — Sir Kaelen")
	check(accepted, "reaction decision returns the chosen intent")

func click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event)
	event = event.duplicate()
	event.pressed = false
	get_viewport().push_input(event)

func large_viewports(window: Window) -> void:
	GameManager.current_state = GameManager.GameState.OVERWORLD
	for resolution in [Vector2i(2560,1440), Vector2i(3440,1440)]:
		window.size = resolution
		var scene = load("res://scenes/overworld.tscn").instantiate()
		add_child(scene)
		await settle()
		var shell := scene.find_child("Root",true,false) as VttShell
		check(shell.board.size.x >= resolution.x - 452 and shell.board.size.y >= 1320, "larger window gains logical board space " + str(shell.board.size))
		await capture("overworld-%dx%d" % [resolution.x,resolution.y])
		scene.queue_free()
		await settle()

func profile_check() -> void:
	var original := UiThemeProfile.current()
	var variant := original.duplicate(true) as UiThemeProfile
	variant.profile_id = "acceptance-cool"
	variant.colors["accent/primary"] = Color("9ab9cf")
	variant.colors["text/primary"] = Color("e5eaf0")
	variant.colors["surface/base"] = Color("0a1722")
	variant.colors["surface/overlay"] = Color("162e42")
	variant.spacing["small"] = 10
	variant.icons["crest"] = original.icons.sheet
	variant.icons["attack"] = original.icons.dodge
	variant.icons["rest"] = original.icons.sheet
	variant.ornament = null
	for type in ["Label", "Button", "RichTextLabel"]:
		variant.ui_theme.set_color("font_color" if type != "RichTextLabel" else "default_color", type, variant.color("text/primary"))
	for type in ["Panel", "PanelContainer", "OverlayPanel", "ShellPanel"]:
		var style := variant.ui_theme.get_stylebox("panel", type).duplicate() as StyleBoxFlat
		style.bg_color = variant.color("surface/overlay")
		style.border_color = variant.color("accent/primary")
		variant.ui_theme.set_stylebox("panel", type, style)
	UiThemeProfile.use_profile(variant)
	get_window().size = Vector2i(1280,720)
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await capture("second-profile-1280x720")
	check(menu.theme == variant.ui_theme, "screens accept a second presentation profile without game changes")
	menu.queue_free()
	await settle()
	GameManager.current_state = GameManager.GameState.OVERWORLD
	var world = load("res://scenes/overworld.tscn").instantiate()
	add_child(world)
	await capture("second-profile-gameplay-1280x720")
	var shell := world.find_child("Root", true, false) as VttShell
	check(shell.party_list.get_theme_constant("separation") == 10 and shell.find_child("BtnRest", true, false).icon == variant.icons.rest, "second profile changes gameplay spacing and icons")
	world.queue_free()
	await settle()
	UiThemeProfile.use_profile(original)
	for index in 210:
		ActivityHistory.publish({"category":"system","kind":"notice","title":"Capacity check","summary":"Recorded notice %d" % index,"visibility":"public","payload":{}})
	check(ActivityHistory.get_records().size() == 200, "Chronicle retains its bounded 200-record history")

func check_roll_details(rail: ActivityRailWidget) -> void:
	for card in rail.card_feed.get_children():
		if card.get_meta("record").get("title") != "Longsword": continue
		var buttons := card.find_children("*", "Button", true, false)
		if buttons.is_empty(): continue
		var button := buttons[0] as Button
		var detail := button.get_parent().get_child(button.get_index() + 1) as Label
		check(detail.text.contains("Strength  +3") and detail.text.contains("Proficiency  +2") and detail.text.contains("Total  17") and detail.text.contains("Target AC  14"), "roll detail presents the recorded terms and comparison")
		button.grab_focus()
		check(detail.visible, "keyboard focus exposes roll detail")
		button.pressed.emit()
		rail._tabs.roll.grab_focus()
		check(detail.visible, "pinned roll detail survives leaving focus")
		button.pressed.emit()
		check(not detail.visible, "click can unpin the same arithmetic")
		button.mouse_entered.emit()
		await get_tree().create_timer(0.42).timeout
		check(detail.visible, "hover reveals the same stored arithmetic")
		card.mouse_exited.emit()
		button.grab_focus()
		return
	check(false, "recorded attack has an accessible arithmetic control")

func relaunch(phase: String) -> void:
	GameManager.test_mode = true
	const SLOT := "ui_grimoire_newest"
	if phase == "prepare":
		DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)
		var file := FileAccess.open(SaveManager.SAVE_DIR + "ui_grimoire_older.sav", FileAccess.WRITE)
		file.store_string(FileAccess.get_file_as_string("res://data/fixtures/save_v2_2024.json"))
		file.close()
		check(SaveManager.load_game("ui_grimoire_older"), "prepare loads a real resumable campaign")
		fixtures()
		ActivityHistory.clear()
		var actor: Character = PartyManager.get_active_characters()[0]
		var target := {"id":"probe_target","name":"Practice target","ac":14,"current_hp":100,"max_hp":100,"conditions":{}}
		var weapon := DataLoader.get_item("longsword")
		var result := CombatAction.resolve_weapon_attack(actor, target, weapon)
		var results: Array[Dictionary] = [result]
		ActivityHistory.publish(CombatActivityRecord.attack_action(actor, target, weapon, results))
		var record: Dictionary = ActivityHistory.get_records()[0]
		var expected := FileAccess.open("user://ui_expected_detail.txt", FileAccess.WRITE)
		expected.store_string(ActivityRailWidget.describe_payload(record.payload))
		expected.close()
		await get_tree().create_timer(1.1).timeout
		check(SaveManager.save_game(SLOT), "save preserves the settled roll ledger")
		check(SaveManager.get_latest_resumable_save() == SLOT, "Continue selects the newest valid save")
	elif phase == "recover":
		check(SaveManager.get_latest_resumable_save() == SLOT, "fresh process locates the newest valid save")
		check(SaveManager.load_game(SLOT), "fresh process resumes the campaign")
		var records := ActivityHistory.get_records()
		check(records.size() == 1, "fresh process retains exactly one settled attack record")
		if not records.is_empty():
			check(ActivityRailWidget.describe_payload(records[0].payload) == FileAccess.get_file_as_string("user://ui_expected_detail.txt"), "fresh process renders identical resolved arithmetic")
	else:
		check(false, "unknown relaunch phase")
	print("UI RELAUNCH %s: %d failures" % [phase, failures])
	get_tree().quit(1 if failures > 0 else 0)
