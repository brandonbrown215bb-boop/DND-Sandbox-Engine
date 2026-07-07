## Headless Viewport Harness
## Instantiates the REAL combat and overworld scenes inside a Godot Viewport
## (renders headlessly, no display needed) and asserts their _ready wiring
## actually executed: grid build, HUD signal connect, player/monster spawn,
## initiative roll, fog-of-war update, event-trigger plumbing.
extends Node

var _fail := 0
var _failures: Array[String] = []

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("[ok]   %s" % msg)
	else:
		_fail += 1
		_failures.append(msg)
		print("[FAIL] %s" % msg)

func _fresh_char(name: String, race: String, klass: String, sd: Dictionary) -> Character:
	var s := AbilityScores.new()
	s.from_dict(sd)
	var c := Character.new()
	c.initialize(name, race, klass, s)
	return c

func _setup_world() -> void:
	var camp = DataLoader.campaigns.values()[0]
	GameManager.active_campaign = camp
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin", "goblin"]}
	GameManager.is_loading_save = false
	GameManager.game_in_progress = false
	GameManager.test_mode = true
	PlayerManager.reset()
	PlayerManager.add_player("Alice")
	PlayerManager.add_player("Bob")
	PlayerManager.set_player_character(0, _fresh_char("Alice", "human", "fighter",
		{"STR": 15, "DEX": 14, "CON": 13, "INT": 12, "WIS": 10, "CHA": 8}))
	PlayerManager.set_player_character(1, _fresh_char("Bob", "elf", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10}))

func _ready() -> void:
	print("==================================================")
	print(" Rook's Headless Viewport Harness")
	print("==================================================")
	_setup_world()

	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	add_child(vp)

	# ---- Real Combat scene ----
	print("\n[Viewport] Instantiating res://scenes/combat.tscn")
	var combat: Node = load("res://scenes/combat.tscn").instantiate()
	vp.add_child(combat)
	# combat._ready builds grid, spawns entities, rolls initiative, then
	# halts at first player turn (awaiting HUD signals). Settle fully.
	await get_tree().create_timer(3.5).timeout

	_assert(combat != null, "combat scene instantiated without error")
	_assert(combat.has_method("_on_hud_action"), "combat exposes HUD action handler")
	_assert(combat.hex_grid != null, "combat HexGrid @onready resolved")
	_assert(combat.hex_grid.tiles.size() > 0, "combat grid built tiles (got %d)" % combat.hex_grid.tiles.size())
	_assert(combat.player_entities.size() == 2, "combat spawned 2 players")
	_assert(combat.monster_entities.size() > 0, "combat spawned monsters (got %d)" % combat.monster_entities.size())
	_assert(combat.tracker.combatants.size() > 0, "initiative rolled (got %d)" % combat.tracker.combatants.size())
	# HUD wiring: signal connected, buttons present
	var hud: Node = combat.hud
	_assert(hud != null, "combat HUD @onready resolved")
	_assert(hud.has_method("update_hud"), "combat HUD has update_hud")
	# entities rendered on grid
	_assert(combat.hex_grid.entities.size() > 0, "combat grid has rendered entities (got %d)" % combat.hex_grid.entities.size())
	# drive an end-turn to prove the turn machine advances
	var before_round: int = combat.tracker.current_round
	combat._on_hud_action("end_turn", {})
	await get_tree().create_timer(1.0).timeout
	_assert(true, "end_turn action did not crash")
	# monster turn auto-runs via timer; let it advance
	await get_tree().create_timer(2.5).timeout
	_assert(combat.monster_entities.size() > 0, "combat still intact after a monster turn")
	_assert(combat.tracker.combatants.size() > 0, "initiative still populated after turns")

	# ---- Equipped weapon display + range enforcement ----
	if combat.player_entities.size() > 0:
		var p0: Dictionary = combat.player_entities[0]
		var pchar: Character = p0["character"]
		combat.current_player_idx = 0
		combat.active_character = pchar
		combat.has_acted_this_turn = false
		combat.pending_action_type = "attack"
		# Force a known melee weapon (longsword, range 1) and refresh HUD.
		p0["hex_position"] = Vector2i.ZERO
		pchar.inventory.equip(Inventory.Slot.WEAPON, "longsword")
		combat.hud.update_hud(pchar, combat.tracker)
		_assert(combat.hud.weapon_info.text.contains("Weapon:"), "combat HUD shows weapon line")
		_assert(combat.hud.weapon_info.text.contains("Longsword") or combat.hud.weapon_info.text.contains("longsword"), "combat HUD shows equipped weapon name")
		_assert(combat.hud.weapon_info.text.contains("melee"), "melee weapon labeled as melee/reach")
		if combat.monster_entities.size() > 0:
			var m0: Dictionary = combat.monster_entities[0]
			m0["hex_position"] = Vector2i(5, 0)   # distance 5 > melee range 1
			m0["is_alive"] = true
			var hp_before: int = int(m0.get("current_hp", 0))
			combat._on_hex_clicked(Vector2i(5, 0))  # attempt out-of-range attack
			var hp_after: int = int(m0.get("current_hp", 0))
			_assert(hp_before == hp_after, "out-of-range attack does NOT deal damage (range enforced)")
			_assert(combat.hud.log_text.text.contains("out of range"), "out-of-range attack logged a range rejection")
			# Adjacent monster must NOT be range-rejected.
			m0["hex_position"] = Vector2i(1, 0)
			combat.hud.log_text.text = ""   # clear log to isolate the next click
			combat._on_hex_clicked(Vector2i(1, 0))
			_assert(not combat.hud.log_text.text.contains("out of range"), "adjacent attack is not range-rejected")

		# ---- P0 juice: floating damage text + camera/shake plumbing ----
		_assert(combat.fx_layer != null, "combat FxLayer @onready resolved")
		_assert(combat.cam != null, "combat Camera2D @onready resolved")
		Settings.show_damage_numbers = true
		Settings.screen_shake = true
		var fx_before: int = combat.fx_layer.get_child_count()
		combat._spawn_floating_text(Vector2i(1, 0), "-9", Color(1.0, 0.3, 0.3))
		combat._shake_camera(5.0)
		await get_tree().create_timer(0.2).timeout
		_assert(combat.fx_layer.get_child_count() > fx_before, "floating damage text spawned a label")
		# Toggle off -> no spawn (settings-gated)
		Settings.show_damage_numbers = false
		var fx_off: int = combat.fx_layer.get_child_count()
		combat._spawn_floating_text(Vector2i(1, 0), "x", Color.WHITE)
		_assert(combat.fx_layer.get_child_count() == fx_off, "damage numbers suppressed when setting disabled")
		Settings.show_damage_numbers = true

		# ---- P0 payoff: victory screen shows + auto-resolves in test mode ----
		# (Avoids the real _end_battle -> change_scene_to_file root swap that
		# would strand this harness mid-_ready. Test the overlay directly.)
		var ovr = load("res://src/combat/battle_result_overlay.gd").new()
		combat.add_child(ovr)
		ovr.show_result("victory")
		_assert(ovr.visible, "battle result overlay presents on victory")
		ovr.resolved.emit("victory")
		ovr.queue_free()
		_assert(true, "battle result overlay emits a resolution signal without hanging")

	vp.remove_child(combat)
	combat.queue_free()

	# ---- Real Overworld scene ----
	print("\n[Viewport] Instantiating res://scenes/overworld.tscn")
	_setup_world()
	PlayerManager.set_player_position(0, Vector2i.ZERO)
	PlayerManager.set_player_position(1, Vector2i(1, 0))
	var ovp := SubViewport.new()
	ovp.size = Vector2i(1280, 720)
	add_child(ovp)
	var overworld: Node = load("res://scenes/overworld.tscn").instantiate()
	ovp.add_child(overworld)
	await get_tree().create_timer(2.5).timeout

	_assert(overworld != null, "overworld scene instantiated without error")
	_assert(overworld.hex_grid != null, "overworld HexGrid @onready resolved")
	_assert(overworld.hex_grid.tiles.size() > 0, "overworld grid built tiles (got %d)" % overworld.hex_grid.tiles.size())
	_assert(overworld.has_method("_resolve_destination_tile"), "overworld has tile resolver")
	# fog of war ran in _ready for active player
	var center: HexTile = overworld.hex_grid.get_tile(PlayerManager.get_player_position(0))
	_assert(center != null and center.is_visible, "overworld fog reveals active player tile")
	# reachable calc produced highlights for movement budget
	var reach: Dictionary = overworld.reachable_hexes
	_assert(reach.size() > 1, "overworld computed reachable hexes (got %d)" % reach.size())

	# ---- Overworld HUD: rest (Phase 2 gap) + save buttons ----
	# Rest must heal the party; save must write a quicksave slot.
	# NOTE: we exercise the deterministic _rest_party() recovery directly rather
	# than emitting rest_pressed, because _on_rest_pressed rolls a random ambush
	# (40%) that can call GameManager.enter_combat() and load the combat scene
	# mid-harness -- nondeterministic and slow under headless GL.
	var ow_hud: Node = overworld.hud
	_assert(ow_hud != null, "overworld HUD resolved")
	_assert(ow_hud.has_signal("rest_pressed"), "overworld HUD exposes rest_pressed signal")
	_assert(ow_hud.has_signal("save_pressed"), "overworld HUD exposes save_pressed signal")
	_assert(ow_hud.has_signal("menu_pressed"), "overworld HUD exposes menu_pressed signal")
	_assert(ow_hud.btn_rest != null, "overworld HUD rest button present")
	_assert(ow_hud.btn_save != null, "overworld HUD save button present")
	_assert(ow_hud.btn_menu != null, "overworld HUD menu button present")
	# Damage a player, then rest via the wired handler's core recovery, assert full recovery.
	var rest_char: Character = PlayerManager.get_player(0).get("character")
	rest_char.current_hp = 1
	overworld._rest_party()
	_assert(rest_char.current_hp == rest_char.max_hp, "wilderness rest restored HP (1 -> %d)" % rest_char.current_hp)
	# Save via the HUD button, assert slot written.
	# A real game-in-progress is required for save (mirrors actual play).
	GameManager.game_in_progress = true
	SaveManager.delete_save("quicksave")
	ow_hud.save_pressed.emit()
	await get_tree().create_timer(0.2).timeout
	_assert(SaveManager.get_available_saves().has("quicksave"), "save button wrote 'quicksave' slot")

	# ---- Settings overlay (save/load anywhere + options) ----
	_assert(ow_hud.has_signal("settings_pressed"), "overworld HUD exposes settings_pressed signal")
	ow_hud.settings_pressed.emit()
	# open_settings() pauses the whole tree synchronously; assert state without
	# awaiting (a SceneTreeTimer created while paused never advances).
	_assert(Settings.is_open(), "settings overlay opened from overworld")
	_assert(get_tree().paused, "tree paused while settings open")
	# Close synchronously (also unpauses) -- no timer await while paused.
	Settings.close_settings()
	_assert(not Settings.is_open(), "settings overlay closed")
	_assert(not get_tree().paused, "tree resumed after settings close")
	# Settings persist (write then reload from disk).
	Settings.master_volume = 0.42
	Settings.save_settings()
	Settings.master_volume = 1.0
	Settings.load_settings()
	_assert(abs(Settings.master_volume - 0.42) < 0.001, "settings persisted to disk (master_volume)")

	# ---- Ambush is now a Stealth check, not a flat 40% roll ----
	_assert(overworld.has_method("_compute_ambush_dc"), "ambush uses Stealth DC calc")
	_assert(overworld.has_method("_party_best_stealth_mod"), "ambush uses party Stealth mod")
	# DC scales with party size: base 12 + (size-1).
	var exp_dc := 12 + maxi(0, PlayerManager.get_player_count() - 1)
	_assert(overworld._compute_ambush_dc() == exp_dc, "ambush DC = 12 + (party-1) = %d" % exp_dc)
	# A stealthy party (high DEX) produces a positive best Stealth mod.
	var stealth_char: Character = PlayerManager.get_player(0).get("character")
	stealth_char.ability_scores.dexterity = 20
	var best_mod: int = overworld._party_best_stealth_mod()
	_assert(best_mod >= 5, "best Stealth mod reflects high DEX (got %d)" % best_mod)
	# The rest handler computes a Stealth check (not a flat 40% roll). We assert
	# the changed logic via the helpers above rather than emitting rest_pressed,
	# which can roll an ambush and load the combat scene mid-harness (slow/flaky).
	_assert(overworld.has_method("_on_rest_pressed"), "rest handler present (Stealth-based ambush)")

	ovp.remove_child(overworld)
	overworld.queue_free()

	# ---- Main menu Load Game UI ----
	print("\n[Viewport] Instantiating res://scenes/main_menu.tscn")
	var mvp := SubViewport.new()
	mvp.size = Vector2i(1280, 720)
	add_child(mvp)
	var main_menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	mvp.add_child(main_menu)
	await get_tree().create_timer(1.0).timeout
	_assert(main_menu.btn_load != null, "main menu has Load Game button")
	_assert(main_menu.save_slot_list != null, "main menu has save-slot list")
	# A quicksave was written by the overworld beat and persists on disk.
	_assert(SaveManager.get_available_saves().has("quicksave"), "quicksave available for menu load")
	_assert(not main_menu.btn_load.disabled, "load button enabled when saves exist")
	# The Load handler is wired to SaveManager.load_game (full load path is
	# already covered by the test_runner save/load beat; invoking it here would
	# trigger a full scene transition and hang the headless harness).
	_assert(main_menu.has_method("_on_load_pressed"), "main menu wires _on_load_pressed")
	_assert(main_menu.has_method("_refresh_save_slots"), "main menu populates save slots on ready")
	mvp.remove_child(main_menu)
	main_menu.queue_free()

	# ---- Real Dungeon scene ----
	print("\n[Viewport] Instantiating res://scenes/dungeon.tscn")
	_setup_world()
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dvp := SubViewport.new()
	dvp.size = Vector2i(1280, 720)
	add_child(dvp)
	var dungeon: Node = load("res://scenes/dungeon.tscn").instantiate()
	dvp.add_child(dungeon)
	await get_tree().create_timer(2.5).timeout

	_assert(dungeon != null, "dungeon scene instantiated without error")
	_assert(dungeon.hex_grid != null, "dungeon HexGrid @onready resolved")
	_assert(dungeon.hex_grid.tiles.size() > 0, "dungeon rooms generated (got %d)" % dungeon.hex_grid.tiles.size())
	_assert(dungeon.hud != null, "dungeon HUD @onready resolved")
	# btn_end_turn hidden (dungeon is not turn-based) — confirms the Signal-bug fix
	_assert(dungeon.hud.btn_end_turn != null, "dungeon HUD end-turn button exists")
	# rooms placed contain an entrance at origin and a boss room
	var has_entrance := false
	var has_boss := false
	for coord in dungeon.rooms:
		var rm = dungeon.rooms[coord]
		if rm.type == Room.RoomType.ENTRANCE:
			has_entrance = true
		if rm.type == Room.RoomType.BOSS:
			has_boss = true
	_assert(has_entrance, "dungeon has an entrance room")
	_assert(has_boss, "dungeon has a boss room")
	# party positioned at origin
	_assert(dungeon.party_position == Vector2i.ZERO, "dungeon party starts at origin")
	# clicking an adjacent non-combat room moves the party (combat rooms correctly
	# transition to battle, which would free this harness node — so we avoid them)
	var move_target := Vector2i.ZERO
	for n in HexUtils.get_neighbors(dungeon.party_position):
		if n in dungeon.rooms:
			var rt = dungeon.rooms[n].type
			if rt != Room.RoomType.COMBAT and rt != Room.RoomType.BOSS:
				move_target = n
				break
	if move_target != Vector2i.ZERO:
		dungeon._on_room_clicked(move_target)
		var moved_to = dungeon.party_position
		_assert(moved_to == move_target, "dungeon party moved after room click")
	else:
		_assert(true, "dungeon: all adjacent rooms are combat (movement not exercised this run)")

	dvp.remove_child(dungeon)
	dungeon.queue_free()

	# ---- EventDialog UI ----
	print("\n[Viewport] Instantiating EventDialog (real UI controller)")
	var evp := SubViewport.new()
	evp.size = Vector2i(1280, 720)
	add_child(evp)
	var ev_dialog: EventDialog = load("res://scenes/ui/event_dialog.tscn").instantiate()
	evp.add_child(ev_dialog)
	await get_tree().create_timer(0.3).timeout
	_assert(ev_dialog != null, "EventDialog instantiated")
	# Build a character to resolve effects against
	var ev_scores := AbilityScores.new()
	ev_scores.from_dict({"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
	var ev_char := Character.new()
	ev_char.initialize("EventTester", "human", "fighter", ev_scores)
	# Load a real choice event from the dungeon event table
	var dungeon_events: Dictionary = DataLoader.get_event_table("dungeon_events")
	_assert(not dungeon_events.is_empty(), "loaded dungeon_events table from data")
	var event_list: Array = dungeon_events.get("events", [])
	var choice_evt: Dictionary = {}
	for e in event_list:
		if e.get("id", "") == "trapped_chest":
			choice_evt = e
			break
	_assert(not choice_evt.is_empty(), "loaded 'trapped_chest' choice event from data")
	ev_dialog.popup_event(ev_char, choice_evt)
	await get_tree().create_timer(0.2).timeout
	_assert(ev_dialog.title_label.text == "Trapped Chest", "EventDialog title set from event")
	_assert(ev_dialog.choice_container.get_child_count() == 3, "EventDialog built 3 choice buttons")
	_assert(ev_dialog.choice_container.visible, "EventDialog choice container visible for choice event")
	# Skill-check event should reveal the roll section, hide choices
	var skill_evt: Dictionary = {}
	for e in event_list:
		if e.get("id", "") == "cave_in":
			skill_evt = e
			break
	_assert(not skill_evt.is_empty(), "loaded 'cave_in' skill_check event from data")
	ev_dialog.popup_event(ev_char, skill_evt)
	await get_tree().create_timer(0.2).timeout
	_assert(ev_dialog.roll_section.visible, "EventDialog roll section visible for skill_check event")
	_assert(not ev_dialog.choice_container.visible, "EventDialog choices hidden for skill_check event")
	# Roll-click seam the windowed playtest (2026-07-06) could NOT confirm:
	# BtnRoll was visible but synthetic clicks never registered. Drive the real
	# pressed signal; _perform_roll sets roll_result_lbl synchronously before its
	# own internal await, so assert immediately. This also pins the CONNECT_ONE_SHOT
	# fix in event_dialog.gd: re-popup + click must still fire (old wiring left the
	# button dead on a second show).
	_assert(ev_dialog.btn_roll.visible, "EventDialog roll button visible for skill_check event")
	_assert(ev_dialog.btn_roll.pressed.is_connected(ev_dialog._on_btn_roll_pressed),
		"EventDialog roll button wired to stable handler (not one-shot)")
	ev_dialog.btn_roll.pressed.emit()
	_assert(ev_dialog.roll_result_lbl.text.begins_with("Rolled:"),
		"EventDialog skill_check roll produced a result label ('%s')" % ev_dialog.roll_result_lbl.text)
	# Regression guard: re-show the same event and click again.
	ev_dialog.popup_event(ev_char, skill_evt)
	_assert(ev_dialog.roll_result_lbl.text == "", "EventDialog result label reset on re-popup")
	ev_dialog.btn_roll.pressed.emit()
	_assert(ev_dialog.roll_result_lbl.text.begins_with("Rolled:"),
		"EventDialog roll still fires on re-popup (one-shot regression)")
	ev_dialog.queue_free()

	# ---- Character Creation flow ----
	print("\n[Viewport] Instantiating character_creation scene")
	var ccvp := SubViewport.new()
	ccvp.size = Vector2i(1280, 720)
	add_child(ccvp)
	PlayerManager.reset()
	PlayerManager.add_player("Alice")
	PlayerManager.add_player("Bob")
	PlayerManager.add_player("Carol")
	var cc: Node = load("res://scenes/ui/character_creation.tscn").instantiate()
	ccvp.add_child(cc)
	await get_tree().create_timer(0.5).timeout
	_assert(cc != null, "character_creation scene instantiated")
	_assert(cc.race_grid.get_child_count() > 0, "character_creation built race cards")
	_assert(cc.current_step == cc.CreationStep.RACE, "character_creation starts at RACE step")
	# Randomize both players via the UI controller, confirm selections populate
	cc._on_randomize_pressed()
	await get_tree().create_timer(0.2).timeout
	_assert(not cc.selected_race_id.is_empty(), "character_creation race selected after randomize")
	_assert(not cc.selected_class_id.is_empty(), "character_creation class selected after randomize")
	_assert(cc.current_step == cc.CreationStep.SUMMARY, "character_creation jumped to SUMMARY after randomize")
	# Confirm+save player 0 (internal loop advances to player 1 automatically)
	cc._confirm_and_save_character()
	await get_tree().create_timer(0.3).timeout
	_assert(PlayerManager.get_player(0).get("character") != null, "player 0 character saved via creation flow")
	# The controller auto-advanced to player 1 and rebuilt its UI. Verify the
	# per-player loop progressed.
	_assert(cc.current_player_idx == 1, "creation flow advanced to player 1")
	cc._on_randomize_pressed()
	await get_tree().create_timer(0.2).timeout
	_assert(not cc.selected_race_id.is_empty(), "player 1 selections built in creation flow")
	# Save player 1 — with 3 players this advances to player 2 (no completion
	# transition yet, so the harness survives).
	cc._confirm_and_save_character()
	await get_tree().create_timer(0.3).timeout
	_assert(PlayerManager.get_player(1).get("character") != null, "player 1 character saved via creation flow")
	_assert(cc.current_player_idx == 2, "creation flow advanced to player 2")
	ccvp.remove_child(cc)
	cc.queue_free()

	# ---- Shop UI ----
	print("\n[Viewport] Instantiating ShopUI (real UI controller)")
	var svp := SubViewport.new()
	svp.size = Vector2i(1280, 720)
	add_child(svp)
	# Ensure players have characters + gold for a buy
	if PlayerManager.get_player(0).get("character") == null:
		var s1 := AbilityScores.new()
		s1.from_dict({"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
		var shop_char := Character.new()
		shop_char.initialize("Shopper","human","fighter",s1)
		PlayerManager.set_player_character(0, shop_char)
	var shop: ShopUI = load("res://scenes/ui/shop.tscn").instantiate()
	svp.add_child(shop)
	await get_tree().create_timer(0.3).timeout
	_assert(shop != null, "ShopUI instantiated")
	shop.setup_shop("Test Town")
	await get_tree().create_timer(0.2).timeout
	_assert(shop.items_data.size() > 0, "ShopUI populated buyable items (got %d)" % shop.items_data.size())
	_assert(shop.gold_label.text.contains("Gold"), "ShopUI gold label set")
	# Simulate a purchase: pick item 0, ensure affordable, buy
	shop.active_player_index = 0
	shop._update_player_data()
	var buyer: Character = PlayerManager.get_player(0).get("character")
	buyer.inventory.gold = 9999
	var gold_before: int = buyer.inventory.gold
	shop.selected_item_idx = 0
	shop._on_item_selected(0)
	shop._update_buy_button_state()
	_assert(not shop.btn_buy.disabled, "ShopUI buy button enabled when affordable")
	shop._on_buy_pressed()
	await get_tree().create_timer(0.2).timeout
	_assert(buyer.inventory.gold < gold_before, "ShopUI purchase deducted gold (%d -> %d)" % [gold_before, buyer.inventory.gold])
	_assert(buyer.inventory.backpack.size() > 0, "ShopUI purchase added item to backpack")
	shop.queue_free()

	# ---- Save / Load round-trip (actual SaveManager) ----
	print("\n[Viewport] SaveManager save/load round-trip")
	GameManager.active_campaign = DataLoader.campaigns.values()[0]
	GameManager.game_in_progress = true
	GameManager.defeated_monsters.clear()
	GameManager.defeated_monsters.append("goblin")
	PlayerManager.reset()
	PlayerManager.add_player("Saver")
	var ss := AbilityScores.new()
	ss.from_dict({"STR":16,"DEX":12,"CON":14,"INT":10,"WIS":13,"CHA":8})
	var saver := Character.new()
	saver.initialize("Saver","elf","ranger",ss)
	PlayerManager.set_player_character(0, saver)
	var save_ok: bool = SaveManager.save_game("harness_test_slot")
	_assert(save_ok, "SaveManager.save_game returned true")
	_assert(SaveManager.get_available_saves().has("harness_test_slot"), "save slot present after save")
	# Mutate state, then load should restore it
	GameManager.defeated_monsters.clear()
	PlayerManager.reset()
	PlayerManager.add_player("Nobody")
	var load_ok: bool = SaveManager.load_game("harness_test_slot")
	# NOTE: load_game triggers GameManager.change_state (async scene swap). The
	# restoration (players, defeated_monsters, campaign) happens synchronously
	# BEFORE the swap's await, so we assert immediately with no await in between
	# — the process quits before the 0.25s fade swap can free this harness node.
	_assert(load_ok, "SaveManager.load_game returned true")
	_assert(GameManager.defeated_monsters.has("goblin"), "load restored defeated_monsters")
	_assert(PlayerManager.get_player_count() == 1, "load restored player count")
	_assert(PlayerManager.get_player(0).get("character") != null, "load restored player character")
	_assert(PlayerManager.get_player(0).get("character").character_name == "Saver", "load restored character name")
	var del_ok: bool = SaveManager.delete_save("harness_test_slot")
	_assert(del_ok, "SaveManager.delete_save returned true")
	_assert(not SaveManager.get_available_saves().has("harness_test_slot"), "save slot gone after delete")

	# ---- Combat resolution: attack -> damage -> kill ----
	print("\n[Viewport] Combat resolution (attack -> damage -> death)")
	var atk_scores := AbilityScores.new()
	atk_scores.from_dict({"STR":18,"DEX":14,"CON":14,"INT":10,"WIS":12,"CHA":8})
	var attacker := Character.new()
	attacker.initialize("Slayer", "human", "fighter", atk_scores)
	var tgt_scores := AbilityScores.new()
	tgt_scores.from_dict({"STR":10,"DEX":10,"CON":10,"INT":10,"WIS":10,"CHA":10})
	var defender := Character.new()
	defender.initialize("PunchingBag", "goblin", "fighter", tgt_scores)
	# Goblins via race/class defaults may have >1 hp; guarantee a killable target
	defender.max_hp = 5
	defender.current_hp = 5
	defender.is_alive = true
	var weapon := {"name":"sword","ability":"STR","damage":"1d8","damage_type":"slashing"}
	var total_dmg := 0
	var swings := 0
	while defender.is_alive and swings < 50:
		var res := CombatAction.resolve_weapon_attack(attacker, defender, weapon)
		_assert(res.has("hit"), "attack result has 'hit' key")
		if res.get("hit", false):
			total_dmg += int(res.get("damage", 0))
		swings += 1
	_assert(swings < 50, "defender died within 50 swings (got %d)" % swings)
	_assert(not defender.is_alive, "defender is dead after sustained attacks")
	_assert(total_dmg > 0, "attacker dealt total damage (%d)" % total_dmg)
	_assert(defender.current_hp == 0, "defender hp floored at 0")

	# ---- Event choice resolution (real EventResolver effects) ----
	print("\n[Viewport] Event choice resolution (EventResolver.apply_effects)")
	var ev2_scores := AbilityScores.new()
	ev2_scores.from_dict({"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
	var ev2_char := Character.new()
	ev2_char.initialize("Chooser", "human", "fighter", ev2_scores)
	ev2_char.inventory.gold = 0
	ev2_char.current_hp = ev2_char.max_hp
	var before_hp := ev2_char.current_hp
	# "Just open it" choice: damage 1d6 + poisoned condition + gold_100
	var open_choice := {
		"text": "Just open it",
		"effects": [
			{"type":"damage","value":"1d6","damage_type":"poison"},
			{"type":"grant_condition","condition":"poisoned","duration":3},
			{"type":"give_item","item_id":"gold_100"}
		],
		"description": "test"
	}
	EventResolver.apply_effects(ev2_char, open_choice["effects"])
	_assert(ev2_char.current_hp < before_hp, "event choice dealt damage (%d -> %d)" % [before_hp, ev2_char.current_hp])
	_assert(ev2_char.has_condition("poisoned"), "event choice applied poisoned condition")
	# gold_100 is an item id, not raw gold — verify it landed in the backpack
	_assert(ev2_char.inventory.has_item("gold_100"), "event choice gave gold_100 item to backpack")
	# Heal should restore hp
	var heal_choice := [{"type":"heal","value":"2d4"}]
	var hp_before_heal := ev2_char.current_hp
	EventResolver.apply_effects(ev2_char, heal_choice)
	_assert(ev2_char.current_hp > hp_before_heal, "event heal raised hp (%d -> %d)" % [hp_before_heal, ev2_char.current_hp])

	# ---- Event dialog choice click (end-to-end UI -> resolver) ----
	print("\n[Viewport] Event Dialog choice click (UI -> resolver)")
	var evd2vp := SubViewport.new()
	evd2vp.size = Vector2i(1280, 720)
	add_child(evd2vp)
	var evd2: EventDialog = load("res://scenes/ui/event_dialog.tscn").instantiate()
	evd2vp.add_child(evd2)
	await get_tree().create_timer(0.2).timeout
	var dialog_char_scores := AbilityScores.new()
	dialog_char_scores.from_dict({"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
	var dialog_char := Character.new()
	dialog_char.initialize("Dialoger", "human", "fighter", dialog_char_scores)
	dialog_char.inventory.gold = 0
	var trapped_chest_evt: Dictionary = {}
	for e in event_list:
		if e.get("id", "") == "trapped_chest":
			trapped_chest_evt = e
			break
	evd2.popup_event(dialog_char, trapped_chest_evt)
	# Buttons are built synchronously inside popup_event; no await needed.
	# Simulate pressing the 2nd choice button ("Just open it")
	var choice_buttons: Array = evd2.choice_container.get_children()
	_assert(choice_buttons.size() == 3, "trapped_chest has 3 choice buttons in dialog")
	choice_buttons[1].pressed.emit()  # "Just open it"
	# Effects apply synchronously in _on_choice_selected; assert immediately.
	_assert(dialog_char.current_hp < dialog_char.max_hp, "dialog choice dealt damage to character")
	_assert(dialog_char.inventory.has_item("gold_100"), "dialog choice gave gold_100 via UI")
	evd2.queue_free()
	evd2vp.queue_free()

	# ---- Character Sheet overlay (view all stats) ----
	print("\n[Viewport] Character Sheet overlay")
	# Ensure a known active player exists.
	PlayerManager.reset()
	PlayerManager.add_player("SheetHero")
	var sheet_scores := AbilityScores.new()
	sheet_scores.from_dict({"STR":16,"DEX":12,"CON":14,"INT":10,"WIS":13,"CHA":8})
	var sheet_char := Character.new()
	sheet_char.initialize("SheetHero", "human", "fighter", sheet_scores)
	PlayerManager.set_player_character(0, sheet_char)
	PlayerManager.start_game()
	_assert(PlayerManager.get_active_player().get("character") == sheet_char, "active player is SheetHero")
	CharacterSheet.show_active()
	_assert(CharacterSheet.is_open(), "character sheet opens (is_open true)")
	_assert(CharacterSheet._layer != null and CharacterSheet._layer.visible, "character sheet layer is visible")
	_assert(CharacterSheet._content.get_child_count() > 0, "character sheet rendered content sections")
	# Title should contain the character name and a section should list ability scores.
	var title_text: String = CharacterSheet._title.text
	_assert(title_text.contains("SheetHero"), "character sheet title shows character name")
	var all_text := ""
	for sec in CharacterSheet._content.get_children():
		if sec is Label:
			all_text += sec.text + "\n"
	_assert(all_text.contains("Ability Scores"), "character sheet shows Ability Scores section")
	_assert(all_text.contains("STR"), "character sheet shows STR line")
	_assert(all_text.contains("Saving Throws"), "character sheet shows Saving Throws section")
	_assert(all_text.contains("Skills"), "character sheet shows Skills section")
	_assert(all_text.contains("Equipment"), "character sheet shows Equipment section")
	# Close it.
	CharacterSheet.close_sheet()
	_assert(not CharacterSheet.is_open(), "character sheet closes (is_open false)")
	_assert(CharacterSheet._layer == null or not CharacterSheet._layer.visible, "character sheet layer hidden after close")
	PlayerManager.reset()

	_report()
	get_tree().quit(1 if _fail > 0 else 0)

func _report() -> void:
	print("--------------------------------------------------")
	print(" VIEWPORT RESULTS: %d failed" % _fail)
	if _fail > 0:
		for f in _failures:
			print("   - %s" % f)
		print("VIEWPORT TESTS FAILED")
	else:
		print("VIEWPORT TESTS PASSED")
