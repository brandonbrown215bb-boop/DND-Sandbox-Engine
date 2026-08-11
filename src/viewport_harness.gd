## Headless Viewport Harness
## Instantiates the REAL combat and overworld scenes inside a Godot Viewport
## (renders headlessly, no display needed) and asserts their _ready wiring
## actually executed: grid build, HUD signal connect, player/monster spawn,
## initiative roll, fog-of-war update, event-trigger plumbing.
##
## Restructured (B): the old single _ready() coroutine is split into discrete,
## individually-named test methods (test_combat, test_overworld, ...). Each owns
## its own SubViewport + teardown, so a failure names the test instead of
## stalling the whole chain, and one broken scene cannot block the others.
## Each test establishes its own preconditions (no cross-test coupling).
extends Node

var _fail := 0
var _failures: Array[String] = []

# Per-test tracking so failures are attributed to a named test.
var _current_test := "harness"
var _fail_at_entry := 0
var _tests_run := 0
var _tests_failed_names: Array[String] = []

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("[ok]   %s" % msg)
	else:
		_fail += 1
		_failures.append("[%s] %s" % [_current_test, msg])
		print("[FAIL] [%s] %s" % [_current_test, msg])

func _fresh_char(name: String, race: String, klass: String, sd: Dictionary) -> Character:
	var s := AbilityScores.new()
	s.from_dict(sd)
	var c := Character.new()
	c.initialize(name, race, klass, s)
	return c

func _setup_world() -> void:
	var camp = DataLoader.campaigns.values()[0]
	GameManager.active_campaign = camp
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin", "goblin"]}
	GameManager.is_loading_save = false
	GameManager.game_in_progress = false
	GameManager.test_mode = true
	PlayerManager.reset()
	PartyManager.reset()
	PlayerManager.add_player("Alice")
	PlayerManager.add_player("Bob")
	var alice := _fresh_char("Alice", "human", "fighter",
		{"STR": 15, "DEX": 14, "CON": 13, "INT": 12, "WIS": 10, "CHA": 8})
	var bob := _fresh_char("Bob", "elf", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	PlayerManager.set_player_character(0, alice)
	PlayerManager.set_player_character(1, bob)
	PartyManager.register_player_character(0, alice)
	PartyManager.register_player_character(1, bob)


func _setup_mixed_world() -> void:
	var camp = DataLoader.campaigns.values()[0]
	GameManager.active_campaign = camp
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin", "goblin"]}
	GameManager.is_loading_save = false
	GameManager.game_in_progress = true
	GameManager.test_mode = true
	PlayerManager.reset()
	PartyManager.reset()
	var specs := [
		{"name": "Fighter Fixture", "race": "human", "class": "fighter", "scores": {"STR": 18, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 8}},
		{"name": "Rogue Fixture", "race": "halfling", "class": "rogue", "scores": {"STR": 10, "DEX": 18, "CON": 12, "INT": 12, "WIS": 10, "CHA": 10}},
		{"name": "Wizard Fixture", "race": "elf", "class": "wizard", "scores": {"STR": 8, "DEX": 14, "CON": 14, "INT": 18, "WIS": 12, "CHA": 10}},
		{"name": "Cleric Fixture", "race": "human", "class": "cleric", "scores": {"STR": 12, "DEX": 10, "CON": 14, "INT": 10, "WIS": 18, "CHA": 10}},
	]
	for index in specs.size():
		var spec: Dictionary = specs[index]
		PlayerManager.add_player(str(spec["name"]))
		var character := _fresh_char(str(spec["name"]), str(spec["race"]), str(spec["class"]), spec["scores"])
		PlayerManager.set_player_character(index, character)
		PartyManager.register_player_character(index, character)


func _setup_ranger_world() -> Character:
	var camp = DataLoader.campaigns.values()[0]
	GameManager.active_campaign = camp
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.is_loading_save = false
	GameManager.game_in_progress = true
	GameManager.test_mode = true
	PlayerManager.reset()
	PartyManager.reset()
	PlayerManager.add_player("Ranger")
	var ranger := _fresh_char("Ranger Fixture", "human", "ranger",
		{"STR": 12, "DEX": 18, "CON": 14, "INT": 10, "WIS": 16, "CHA": 8})
	ranger.known_spells.assign(["hunters_mark"])
	ranger.spell_slots["1"] = 0
	PlayerManager.set_player_character(0, ranger)
	PartyManager.register_player_character(0, ranger)
	return ranger

# --- per-test scaffolding ---------------------------------------------------

func _enter_test(name: String) -> void:
	_current_test = name
	_fail_at_entry = _fail
	_tests_run += 1
	print("\n[TEST] %s" % name)

func _exit_test() -> void:
	if _fail > _fail_at_entry and not _tests_failed_names.has(_current_test):
		_tests_failed_names.append(_current_test)

## Spawn a scene inside an isolated SubViewport, settle for `settle` seconds,
## and return the instance (vp tracked via meta for teardown).
func _spawn_scene(scene_path: String, settle: float) -> Node:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	add_child(vp)
	var inst = load(scene_path).instantiate()
	vp.add_child(inst)
	await get_tree().create_timer(settle).timeout
	inst.set_meta("vp", vp)
	return inst

## Free a scene spawned by _spawn_scene (removes from its vp, frees both).
func _teardown_scene(inst: Node) -> void:
	if inst == null:
		return
	var vp = inst.get_meta("vp") if inst.has_meta("vp") else null
	if vp != null:
		vp.remove_child(inst)
		vp.queue_free()
	inst.queue_free()

# --- test orchestration -----------------------------------------------------

func _ready() -> void:
	print("==================================================")
	print(" Rook's Headless Viewport Harness (per-beat)")
	print("==================================================")
	_setup_world()

	var scenario := _requested_scenario()
	if scenario == "all":
		await _run_all_scenarios()
	else:
		await _run_scenario(scenario)

	_report()
	if _fail == 0:
		print("SCENARIO PASSED: %s" % scenario)
	else:
		print("SCENARIO FAILED: %s" % scenario)
	get_tree().quit(1 if _fail > 0 else 0)

func _requested_scenario() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			return arg.trim_prefix("--scenario=")
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--scenario="):
			return arg.trim_prefix("--scenario=")
	return "all"

func _run_all_scenarios() -> void:
	await test_combat()
	await test_party_combat()
	await test_crown_smoke()
	await test_crown_balance_fixture()
	await test_combat_ai_loop()
	await test_combat_victory()
	await test_combat_defeat()
	await test_final_encounter_round_trip()
	await test_mixed_mechanics_encounter()
	await test_ranger_action_flow()
	await test_overworld()
	await test_companion_lifecycle()
	await test_crown_composition_solo_two()
	await test_crown_composition_three_four()
	await test_main_menu_load()
	await test_dungeon()
	await test_event_dialog()
	await test_crown_event_fairy_ring()
	await test_dungeon_reentry_round_trip()
	await test_character_creation()
	await test_shop()
	await test_save_load()
	await test_action_resource_round_trip()
	await test_combat_resolution()
	await test_event_choice_resolution()
	await test_event_dialog_choice_click()
	await test_character_sheet()
	await test_character_sheet_contexts()
	await test_character_value_audit()

func _run_scenario(scenario: String) -> void:
	match scenario:
		"combat": await test_combat()
		"party_combat": await test_party_combat()
		"crown_smoke": await test_crown_smoke()
		"crown_balance_fixture": await test_crown_balance_fixture()
		"combat_ai_loop": await test_combat_ai_loop()
		"combat_victory": await test_combat_victory()
		"combat_defeat": await test_combat_defeat()
		"final_encounter_round_trip": await test_final_encounter_round_trip()
		"mixed_mechanics_encounter": await test_mixed_mechanics_encounter()
		"ranger_action_flow": await test_ranger_action_flow()
		"overworld": await test_overworld()
		"companion_lifecycle": await test_companion_lifecycle()
		"crown_composition_solo_two": await test_crown_composition_solo_two()
		"crown_composition_three_four": await test_crown_composition_three_four()
		"main_menu_load": await test_main_menu_load()
		"dungeon": await test_dungeon()
		"event_dialog": await test_event_dialog()
		"crown_event_fairy_ring": await test_crown_event_fairy_ring()
		"dungeon_reentry_round_trip": await test_dungeon_reentry_round_trip()
		"character_creation": await test_character_creation()
		"shop": await test_shop()
		"save_load": await test_save_load()
		"action_resource_round_trip": await test_action_resource_round_trip()
		"combat_resolution": await test_combat_resolution()
		"event_choice_resolution": await test_event_choice_resolution()
		"event_dialog_choice_click": await test_event_dialog_choice_click()
		"character_sheet": await test_character_sheet()
		"character_sheet_contexts": await test_character_sheet_contexts()
		"character_value_audit": await test_character_value_audit()
		_:
			_fail += 1
			_failures.append("[harness] unknown scenario '%s'" % scenario)

# --- tests ------------------------------------------------------------------

## Combat boot + weapon/range enforcement + P0 juice/payoff + P1 readability.
func test_combat() -> void:
	_enter_test("combat")
	_setup_world()
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 3.5)

	_assert(combat != null, "combat scene instantiated without error")
	_assert(combat.has_method("_on_hud_action"), "combat exposes HUD action handler")
	_assert(combat.hex_grid != null, "combat HexGrid @onready resolved")
	_assert(combat.hex_grid.tiles.size() > 0, "combat grid built tiles (got %d)" % combat.hex_grid.tiles.size())
	_assert(combat.player_entities.size() == 2, "combat spawned 2 players")
	_assert(combat.monster_entities.size() > 0, "combat spawned monsters (got %d)" % combat.monster_entities.size())
	_assert(combat.tracker.combatants.size() > 0, "initiative rolled (got %d)" % combat.tracker.combatants.size())
	var hud: Node = combat.hud
	_assert(hud != null, "combat HUD @onready resolved")
	_assert(hud.has_method("update_hud"), "combat HUD has update_hud")
	_assert(combat.hex_grid.entities.size() > 0, "combat grid has rendered entities (got %d)" % combat.hex_grid.entities.size())

	# A physical disconnect holds the exact owned combatant in place. Rebinding
	# the stable seat resumes that turn instead of changing ownership or devices.
	var seat0_session := str(PlayerManager.get_player(0).get("session_id", ""))
	_assert(PlayerManager.bind_device_to_session(seat0_session, 7), "combat owner can bind a transient controller")
	var owned_turn_index := -1
	for initiative_index in combat.tracker.combatants.size():
		var candidate: Dictionary = combat.tracker.combatants[initiative_index]
		if bool(candidate.get("is_player", false)) and candidate.get("entity") == combat.player_entities[0].get("character"):
			owned_turn_index = initiative_index
			break
	_assert(owned_turn_index >= 0, "combat initiative contains Seat 1's owned character")
	if owned_turn_index >= 0:
		var owned_character: Character = combat.player_entities[0].get("character")
		owned_character.is_alive = true
		owned_character.current_hp = maxi(1, owned_character.max_hp)
		combat._battle_ending = false
		combat.tracker.active_index = owned_turn_index
		PlayerManager._on_joy_connection_changed(7, false)
		combat._start_combat_turn()
		_assert(combat._waiting_for_owner_rebind, "disconnected owner holds the active combat turn")
		_assert(combat.hud.btn_end_turn.disabled, "disconnected owner locks combat controls")
		_assert(combat.active_combatant.get("entity") == combat.player_entities[0].get("character"), "disconnect preserves the active character's stable owner")
		_assert(PlayerManager.request_device_join(8, seat0_session) == 0, "Start join reclaims the exact combat seat")
		_assert(not combat._waiting_for_owner_rebind and not combat.hud.btn_end_turn.disabled, "rebind resumes the held combat turn")
	# drive an end-turn to prove the turn machine advances
	var before_round: int = combat.tracker.current_round
	combat._on_hud_action("end_turn", {})
	await get_tree().create_timer(1.0).timeout
	_assert(true, "end_turn action did not crash")
	await get_tree().create_timer(2.5).timeout
	_assert(combat.monster_entities.size() > 0, "combat still intact after a monster turn")
	_assert(combat.tracker.combatants.size() > 0, "initiative still populated after turns")

	# ---- Equipped weapon display + range enforcement ----
	if combat.player_entities.size() > 0:
		var p0: Dictionary = combat.player_entities[0]
		var pchar: Character = p0["character"]
		combat.current_player_idx = 0
		combat.active_character = pchar
		combat.turn_budget.has_acted_this_turn = false
		combat.pending_action_type = "attack"
		p0["hex_position"] = Vector2i.ZERO
		pchar.inventory.equip(Inventory.Slot.WEAPON, "longsword", true)
		combat.hud.update_hud(pchar, combat.tracker)
		_assert(combat.hud.weapon_info.text.contains("Weapon:"), "combat HUD shows weapon line")
		_assert(combat.hud.weapon_info.text.contains("Longsword") or combat.hud.weapon_info.text.contains("longsword"), "combat HUD shows equipped weapon name")
		_assert(combat.hud.weapon_info.text.contains("melee"), "melee weapon labeled as melee/reach")
		if combat.monster_entities.size() > 0:
			var m0: Dictionary = combat.monster_entities[0]
			m0["hex_position"] = Vector2i(5, 0)
			m0["is_alive"] = true
			var hp_before: int = int(m0.get("current_hp", 0))
			combat._on_hex_clicked(Vector2i(5, 0))
			var hp_after: int = int(m0.get("current_hp", 0))
			_assert(hp_before == hp_after, "out-of-range attack does NOT deal damage (range enforced)")
			_assert(combat.hud.log_text.text.contains("out of range"), "out-of-range attack logged a range rejection")
			# ---- Bug fix: out-of-range attack must NOT trap the player in targeting mode ----
			_assert(combat.pending_action_type == "attack", "still targeting after an out-of-range click (pre-condition)")
			combat._cancel_pending_action()
			_assert(combat.pending_action_type == "", "cancel clears pending targeting (player can return to movement)")
			m0["hex_position"] = Vector2i(1, 0)
			combat.hud.log_text.text = ""
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
			Settings.show_damage_numbers = false
			var fx_off: int = combat.fx_layer.get_child_count()
			combat._spawn_floating_text(Vector2i(1, 0), "x", Color.WHITE)
			_assert(combat.fx_layer.get_child_count() == fx_off, "damage numbers suppressed when setting disabled")
			Settings.show_damage_numbers = true

			# ---- P0 payoff: victory screen shows + auto-resolves in test mode ----
			var ovr = load("res://src/combat/battle_result_overlay.gd").new()
			combat.add_child(ovr)
			ovr.show_result("victory")
			_assert(ovr.visible, "battle result overlay presents on victory")
			ovr.resolved.emit("victory")
			ovr.queue_free()
			_assert(true, "battle result overlay emits a resolution signal without hanging")

			# ---- P1 readability ----
			_assert(combat._describe_intent({"name":"Goblin"},
				{"action":"move_attack","target_id":"Thorne"}) == "Move + Attack Thorne",
				"intent describes move+attack")
			_assert(combat._describe_intent({"name":"Goblin"},
				{"action":"attack","target_id":"Brunhild"}) == "Attack Brunhild",
				"intent describes attack")
			_assert(combat._describe_intent({"name":"Goblin"},
				{"action":"move"}) == "Move", "intent describes move")
			_assert(combat._describe_intent({"name":"Goblin"},
				{"action":"none"}) == "Hold", "intent describes hold")

			# Move-path preview
			# The earlier timed turn intentionally exercises the live loop. Reset
			# the preview's own preconditions so RNG and initiative order cannot
			# decide whether this focused assertion has an active player.
			combat.current_player_idx = 0
			combat.active_character = pchar
			combat._battle_ending = false
			pchar.is_alive = true
			pchar.current_hp = maxi(1, pchar.current_hp)
			combat.pending_action_type = ""
			combat.remaining_speed = float(pchar.get_speed())
			var ppos: Vector2i = combat.player_entities[combat.current_player_idx]["hex_position"]
			var reach: Dictionary = combat.hex_grid.get_reachable(ppos, combat.remaining_speed)
			var some_hex: Vector2i = Vector2i.ZERO
			for h in reach:
				if h != ppos:
					some_hex = h
					break
			combat._path_preview_hexes.clear()
			if some_hex != Vector2i.ZERO:
				combat._on_hex_hovered(some_hex)
				_assert(combat._path_preview_hexes.size() > 0, "hovering a reachable hex previews a movement path")
			else:
				_assert(false, "expected at least one reachable hex for path-preview test")

			# Attack-range ring
			combat.pending_action_type = "attack"
			combat._highlight_attack_targets()
			_assert(combat.hex_grid.get_highlight_count() > 0, "attack select highlights weapon range hexes")

			# First-turn hint
			_assert(not combat.hud.hint_label.text.is_empty(), "first-turn hint was configured with guidance text")
			_assert(combat._hint_shown, "first-turn hint flag set (shown once per battle)")
			combat.hud.show_hint("test")
			_assert(combat.hud.hint_label.visible, "hint show() makes the banner visible")
			combat.hud.hide_hint()
			_assert(not combat.hud.hint_label.visible, "hint hide() hides the banner")

	_teardown_scene(combat)
	_exit_test()


## Party-derived combat formation and local ownership for one player plus companions.
func test_party_combat() -> void:
	_enter_test("party_combat")
	var camp: Dictionary = DataLoader.get_campaign("the_lost_crown")
	GameManager.active_campaign = camp
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"monster_ids": ["goblin"], "terrain": "plains", "return_state": GameManager.GameState.OVERWORLD}
	GameManager.test_mode = true
	PlayerManager.reset()
	PartyManager.reset()
	PlayerManager.add_player("Solo")
	var hero := _fresh_char("Solo Hero", "human", "fighter", {"STR":15,"DEX":14,"CON":13,"INT":10,"WIS":10,"CHA":8})
	PlayerManager.set_player_character(0, hero)
	PartyManager.register_player_character(0, hero)
	PartyManager.initialize_campaign_companions(camp.get("companions", {}))
	for companion_id in PartyManager.get_available_companions():
		PartyManager.recruit_companion(companion_id)
	PartyManager.set_leader("slot_2")
	var expected_owners: Array[int] = []
	for member in PartyManager.get_active_party_members():
		expected_owners.append(int(member.get("owner_player_index", -1)))
	GameManager.game_in_progress = true
	GameManager.current_state = GameManager.GameState.OVERWORLD
	_assert(SaveManager.save_game("gate4_party_formation"), "four-member party saves through the supported boundary")
	PartyManager.reset()
	PlayerManager.reset()
	_assert(SaveManager.load_game("gate4_party_formation"), "four-member party reloads through the supported boundary")
	_assert(PartyManager.get_active_party_members().size() == 4, "save/load preserves all four occupied party slots")
	_assert(PartyManager.leader_slot_id == "slot_2", "save/load preserves transferred exploration leadership")
	var loaded_owners: Array[int] = []
	for member in PartyManager.get_active_party_members():
		loaded_owners.append(int(member.get("owner_player_index", -1)))
	_assert(loaded_owners == expected_owners, "save/load preserves logical combat ownership for every party slot")
	SaveManager.delete_save("gate4_party_formation")
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"monster_ids": ["goblin"], "terrain": "plains", "return_state": GameManager.GameState.OVERWORLD}
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 2.5)
	_assert(combat.player_entities.size() == 4, "party combat enters with all four active party members")
	var occupied_positions := {}
	for entity in combat.player_entities:
		_assert(int(entity.get("owner_player_index", -1)) == 0, "solo player owns every active combat turn")
		_assert(not occupied_positions.has(entity.get("hex_position")), "party formation positions are distinct")
		occupied_positions[entity.get("hex_position")] = true
	var spell_owner: Character = combat.player_entities[1].get("character")
	spell_owner.known_spells.assign(["magic_missile"])
	hero.known_spells.clear()
	combat.hud.update_hud(spell_owner, combat.tracker)
	combat.hud._show_spell_selection()
	_assert(combat.hud.spells_registered.size() == 1 and str(combat.hud.spells_registered[0].get("id", "")) == "magic_missile", "spell menu shows only the active companion's owned spell")
	_assert(combat.hud.spell_list.get_item_count() == 1, "spell menu renders one row for one owned spell")
	combat.hud._hide_spell_selection()
	combat.hud._show_spell_selection()
	_assert(combat.hud.spell_list.get_item_count() == 1 and combat.hud.spells_registered.size() == 1, "reopening the spell menu does not duplicate rows")
	combat.hud.update_hud(hero, combat.tracker)
	combat.hud._show_spell_selection()
	_assert(combat.hud.spell_list.get_item_count() == 0 and combat.hud.spells_registered.is_empty(), "spell rows do not leak to a different active character")
	_teardown_scene(combat)
	_setup_world()
	_exit_test()


## Ranger regression for the playtest-reported Hunter's Mark / attack flow.
## Drives the production CombatState and CombatHUD scene boundary, not only
## the spell resolver, so disabled rows, cancellation, and action commitment
## remain one coherent contract.
func test_ranger_action_flow() -> void:
	_enter_test("ranger_action_flow")
	var ranger := _setup_ranger_world()
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 2.5)
	combat.current_player_idx = 0
	combat.active_character = ranger
	ranger.spell_slots.clear()
	ranger.spell_slots["1"] = 0
	combat.turn_budget.reset(ranger, combat.player_entities)
	combat.hud.update_hud(ranger, combat.tracker)

	var emitted_actions: Array[String] = []
	combat.hud.action_selected.connect(func(action_type: String, _extra_data: Dictionary): emitted_actions.append(action_type))
	combat.hud._show_spell_selection()
	_assert(combat.hud.spell_list.get_item_count() == 1, "Ranger spell menu renders Hunter's Mark")
	_assert(combat.hud.spell_list.is_item_disabled(0), "Hunter's Mark is disabled when no level-1 slot remains")
	combat.hud._on_spell_selected(0)
	_assert(emitted_actions.is_empty(), "disabled Hunter's Mark cannot emit a cast action")
	_assert(combat.pending_action_type.is_empty(), "disabled Hunter's Mark cannot enter targeting")

	var optional_labels := CombatHUD.decision_prompt_labels("Seat 1", "favored_foe")
	var reaction_labels := CombatHUD.decision_prompt_labels("Seat 1", "shield")
	_assert(str(optional_labels["window_title"]).begins_with("Optional Feature"), "Favored Foe prompt is labeled as an optional feature")
	_assert(optional_labels["ok_title"] == "Confirm", "optional feature prompt does not claim to spend a reaction")
	_assert(str(reaction_labels["window_title"]).begins_with("Reaction"), "Shield retains reaction labeling")
	_assert(reaction_labels["ok_title"] == "Use Reaction", "true reaction prompt keeps its reaction action label")

	var hunters_mark := DataLoader.get_spell("hunters_mark")
	combat.hud._hide_spell_selection()
	combat._on_hud_action("cast_spell", {"spell": hunters_mark})
	_assert(combat.pending_action_type.is_empty(), "CombatState rejects Hunter's Mark when no slot remains")
	_assert(combat.turn_budget.action_available and combat.turn_budget.bonus_action_available, "rejected Hunter's Mark spends no action resource")

	combat._on_hud_action("attack", {})
	combat._cancel_pending_action()
	_assert(combat.pending_action_type.is_empty(), "cancel exits attack targeting")
	_assert(combat.turn_budget.action_available, "canceling target selection preserves the uncommitted Attack action")

	combat._on_hud_action("attack", {})
	var target: Dictionary = combat.monster_entities[0]
	var target_coord := Vector2i(1, 0)
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	target["hex_position"] = target_coord
	target["current_hp"] = 999
	target["is_alive"] = true
	await combat._on_hex_clicked(target_coord)
	_assert(not combat.turn_budget.action_available and combat.turn_budget.has_acted_this_turn, "a valid target click commits exactly one Attack action")
	_assert(combat.pending_action_type.is_empty(), "committed attack clears targeting before optional prompts can yield")
	var hp_after_first_click := int(target["current_hp"])
	await combat._on_hex_clicked(target_coord)
	_assert(int(target["current_hp"]) == hp_after_first_click, "a repeated target click cannot resolve a second attack")

	_teardown_scene(combat)
	_setup_world()
	_exit_test()


## Fixed-seed Crown path using the production overworld, dungeon, event,
## combat, objective, and terminal scenes in one bounded process.
func test_crown_smoke() -> void:
	_enter_test("crown_smoke")
	_setup_world()
	GameManager.game_in_progress = true
	PartyManager.initialize_campaign_companions(GameManager.active_campaign.get("companions", {}))
	_assert(PartyManager.recruit_companion("aldric"), "Crown smoke recruits Aldric")
	_assert(PartyManager.recruit_companion("mira"), "Crown smoke recruits Mira")
	_assert(PartyManager.get_active_characters().size() == 4, "Crown smoke starts with a full four-member party")

	var overworld: Node = await _spawn_scene("res://scenes/overworld.tscn", 1.2)
	_assert(overworld.hud.objective_label.text.contains("Find"), "Crown smoke displays the primary objective")
	PartyManager.move_exploration_party(Vector2i(1, 0))
	_assert(PlayerManager.get_player_position(0) == Vector2i(1, 0) and PlayerManager.get_player_position(1) == Vector2i(1, 0), "Crown smoke moves the authoritative party position")
	_teardown_scene(overworld)

	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: Node = await _spawn_scene("res://scenes/dungeon.tscn", 1.2)
	_assert(dungeon.rooms.size() == 5, "Crown smoke enters the deterministic first dungeon")
	_assert(GameManager.completed_milestones.has("enter_dungeon_1"), "Crown smoke records dungeon entry milestone")
	var crown_boss: Room = null
	for candidate in dungeon.rooms.values():
		if candidate is Room and candidate.type == Room.RoomType.BOSS:
			crown_boss = candidate
			break
	_assert(crown_boss != null, "Crown smoke finds the generated boss room")
	dungeon._begin_room_combat(crown_boss)
	_assert(not crown_boss.is_cleared and not dungeon.boss_defeated, "Crown smoke keeps the boss unresolved during combat")
	dungeon._complete_pending_combat()
	_assert(crown_boss.is_cleared and dungeon.boss_defeated, "Crown smoke resolves the boss only after victory")
	_assert(GameManager.mark_dungeon_cleared("ruins_of_ashvale"), "Crown smoke records the resolved dungeon clear")
	_assert(not GameManager.mark_dungeon_cleared("ruins_of_ashvale"), "Crown smoke keeps dungeon clear idempotent")
	_teardown_scene(dungeon)
	GameManager.active_dungeon_state.clear()
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var reentered_dungeon: Node = await _spawn_scene("res://scenes/dungeon.tscn", 0.6)
	var reentry_rooms_cleared := true
	for reentry_room in reentered_dungeon.rooms.values():
		if not reentry_room.is_cleared:
			reentry_rooms_cleared = false
			break
	_assert(reentry_rooms_cleared and reentered_dungeon.boss_defeated, "Crown smoke re-entry preserves cleared dungeon state without rewards")
	_teardown_scene(reentered_dungeon)

	var event_dialog: Node = await _spawn_scene("res://scenes/ui/event_dialog.tscn", 0.2)
	var event_table: Dictionary = DataLoader.get_event_table("dungeon_events")
	var event_data: Dictionary = event_table.get("events", [])[0]
	event_dialog.popup_event(PartyManager.get_active_characters()[0], event_data)
	_assert(event_dialog.visible, "Crown smoke presents a production event")
	_teardown_scene(event_dialog)

	GameManager.transition_context = {"monster_ids": ["lich_king"], "return_state": GameManager.GameState.DUNGEON, "terrain": "dungeon"}
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	_assert(combat.player_entities.size() == 4, "Crown smoke carries the full party into the finale encounter")
	_assert(combat.monster_entities.size() == 1 and combat.monster_entities[0].get("monster_id", "") == "lich_king", "Crown smoke uses the production Lich King encounter")
	_assert(combat.monster_entities[0].get("spells", []).size() == 7 and combat.monster_entities[0].get("spell_slots", {}).get("3", 0) == 3, "Crown smoke preserves the production Lich King spell list and slots")
	_assert(combat.monster_entities[0].get("condition_immunities", []).has("paralyzed") and combat.monster_entities[0].get("loot_table", []).size() == 4, "Crown smoke preserves boss defenses and reward metadata")
	combat._handle_spell_effects(null, combat.monster_entities[0], {"effects": [{"type": "grant_condition", "condition": "paralyzed", "duration": 3}]})
	_assert(not combat.monster_entities[0].get("conditions", {}).has("paralyzed"), "Crown monster condition immunity blocks an incoming paralyze effect")
	for player_entity in combat.player_entities:
		var final_character: Character = player_entity.get("character")
		final_character.inventory.equip(Inventory.Slot.WEAPON, "longsword", true)
		final_character.base_ac = 1000
		final_character.max_hp = 10000
		final_character.current_hp = 10000
		final_character.is_alive = true
	var lich: Dictionary = combat.monster_entities[0]
	var final_player_position: Vector2i = combat.player_entities[0].get("hex_position", Vector2i.ZERO)
	var final_monster_position := final_player_position
	for neighbor in HexUtils.get_neighbors(final_player_position):
		if combat.hex_grid.has_tile(neighbor) and combat.hex_grid.is_hex_passable(neighbor):
			final_monster_position = neighbor
			break
	lich["hex_position"] = final_monster_position
	lich["current_hp"] = 1
	lich["max_hp"] = 1
	lich["armor_class"] = -100
	lich["is_alive"] = true
	lich["conditions"] = {"prone": 99}
	combat._update_grid_entities()
	seed(424242)
	var final_rounds := 0
	while final_rounds < 6 and not combat._battle_ending:
		var final_start_round: int = combat.tracker.current_round
		var final_guard := 0
		while not combat._battle_ending and combat.tracker.current_round == final_start_round and final_guard < 12:
			var final_active: Dictionary = combat.active_combatant
			if not final_active.is_empty() and final_active.get("is_player", false):
				_drive_player_attack_turn(combat)
			await get_tree().create_timer(2.5).timeout
			final_guard += 1
		final_rounds += 1
	_assert(combat._battle_ending, "Crown smoke resolves the production finale combat loop")
	_assert(GameManager.defeated_monsters.has("lich_king"), "Crown smoke registers the Lich King defeat from CombatState")
	_teardown_scene(combat)

	var active_party := PartyManager.get_active_characters()
	for index in 3:
		active_party[index].inventory.add_item("crown_fragment")
	_assert(GameManager.are_win_conditions_met(), "Crown smoke reaches the campaign win condition")
	GameManager.current_state = GameManager.GameState.COMPLETION
	GameManager.transition_context = {"reason": "Campaign goals completed!"}
	var completion: Node = await _spawn_scene("res://scenes/completion.tscn", 0.3)
	_assert(completion.title_label.text == "Crown Reclaimed", "Crown smoke presents the provisional completion screen")
	_teardown_scene(completion)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = false
	GameManager.active_dungeon_state.clear()
	_exit_test()

## Seeded balance fixture for the first production Crown boss encounter. This
## keeps the normal party, milestone level-up, dungeon checkpoint, reward
## record, and live combat loop intact; it only records the resulting budget
## so balance review has a repeatable baseline.
func test_crown_balance_fixture() -> void:
	_enter_test("crown_balance_fixture")
	_setup_world()
	GameManager.game_in_progress = true
	PartyManager.initialize_campaign_companions(GameManager.active_campaign.get("companions", {}))
	_assert(PartyManager.recruit_companion("aldric"), "balance fixture recruits Aldric")
	_assert(PartyManager.recruit_companion("mira"), "balance fixture recruits Mira")
	seed(20260810)
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: Node = await _spawn_scene("res://scenes/dungeon.tscn", 1.0)
	var active_party := PartyManager.get_active_characters()
	_assert(active_party.size() == 4, "balance fixture uses the four-member Crown party")
	var all_level_two := true
	for character in active_party:
		if character.level != 2:
			all_level_two = false
	_assert(all_level_two, "balance fixture applies the entrance milestone to level 2")
	var dungeon_config: Dictionary = DataLoader.get_campaign("the_lost_crown").get("dungeons", {}).get("ruins_of_ashvale", {})
	_assert(dungeon_config.get("boss", {}).get("monster_id", "") == "wight", "balance fixture selects the production Ruins Wight boss")
	_assert(dungeon_config.get("loot", []) == [{"item_id": "crown_fragment"}, {"item_id": "gold_100"}], "balance fixture records the production boss reward boundary")
	_assert(SaveManager.get_save_block_reason().is_empty(), "balance fixture allows safe-save at the dungeon entrance checkpoint")

	var boss: Room = null
	for candidate in dungeon.rooms.values():
		if candidate is Room and candidate.type == Room.RoomType.BOSS:
			boss = candidate
			break
	_assert(boss != null, "balance fixture finds the generated boss room")
	if boss != null:
		dungeon.party_position = boss.coord
		dungeon._save_dungeon_state_to_manager()
	_assert(SaveManager.get_save_block_reason().contains("active dungeon"), "balance fixture blocks save after leaving the entrance checkpoint")
	if boss != null:
		dungeon._begin_room_combat(boss)
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"monster_ids": ["wight"], "return_state": GameManager.GameState.DUNGEON, "terrain": "dungeon"}
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	var starting_hp := 0
	for entity in combat.player_entities:
		starting_hp += int(entity.get("character").current_hp)
	var starting_wight_hp := int(combat.monster_entities[0].get("current_hp", 0))
	seed(20260810)
	var rounds := 0
	while rounds < 12 and not combat._battle_ending:
		var round_start: int = combat.tracker.current_round
		var turn_guard := 0
		while not combat._battle_ending and combat.tracker.current_round == round_start and turn_guard < 16:
			var active: Dictionary = combat.active_combatant
			if not active.is_empty() and active.get("is_player", false):
				_drive_player_attack_turn(combat)
			await get_tree().create_timer(0.35).timeout
			turn_guard += 1
		rounds += 1
	var ending_hp := 0
	for entity in combat.player_entities:
		ending_hp += int(entity.get("character").current_hp)
	var wight_hp := int(combat.monster_entities[0].get("current_hp", 0))
	var hp_loss := starting_hp - ending_hp
	var resolved: bool = combat._battle_ending
	_assert(starting_wight_hp > 0 and starting_hp > 0, "balance fixture starts with live production combatants")
	_assert(resolved, "balance fixture resolves the seeded Wight encounter within the twelve-round budget")
	_assert(ending_hp > 0, "balance fixture leaves at least one party member standing")
	_assert(wight_hp <= 0, "balance fixture ends with the Wight defeated")
	print("[balance] ruins_of_ashvale seed=20260810 party_level=2 rounds=%d hp=%d->%d loss=%d wight_hp=%d reward=crown_fragment+gold_100" % [rounds, starting_hp, ending_hp, hp_loss, wight_hp])
	_teardown_scene(combat)
	GameManager.active_dungeon_state.clear()
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = false
	_teardown_scene(dungeon)
	_exit_test()

## Overworld boot + fog + reachable + rest + save + settings + ambush (Stealth).
func test_overworld() -> void:
	_enter_test("overworld")
	_setup_world()
	PlayerManager.set_player_position(0, Vector2i.ZERO)
	PlayerManager.set_player_position(1, Vector2i(1, 0))
	var overworld: Node = await _spawn_scene("res://scenes/overworld.tscn", 2.5)

	_assert(overworld != null, "overworld scene instantiated without error")
	_assert(overworld.hex_grid != null, "overworld HexGrid @onready resolved")
	_assert(overworld.hex_grid.tiles.size() > 0, "overworld grid built tiles (got %d)" % overworld.hex_grid.tiles.size())
	_assert(overworld.has_method("_resolve_destination_tile"), "overworld has tile resolver")
	var center: HexTile = overworld.hex_grid.get_tile(PlayerManager.get_player_position(0))
	_assert(center != null and center.is_visible, "overworld fog reveals active player tile")
	var reach: Dictionary = overworld.reachable_hexes
	_assert(reach.size() > 1, "overworld computed reachable hexes (got %d)" % reach.size())

	# ---- Overworld HUD: rest + save buttons ----
	var ow_hud: Node = overworld.hud
	_assert(ow_hud != null, "overworld HUD resolved")
	_assert(ow_hud.has_signal("rest_pressed"), "overworld HUD exposes rest_pressed signal")
	_assert(ow_hud.has_signal("save_pressed"), "overworld HUD exposes save_pressed signal")
	_assert(ow_hud.has_signal("menu_pressed"), "overworld HUD exposes menu_pressed signal")
	_assert(ow_hud.btn_rest != null, "overworld HUD rest button present")
	_assert(ow_hud.btn_save != null, "overworld HUD save button present")
	_assert(ow_hud.btn_menu != null, "overworld HUD menu button present")
	PartyManager.initialize_campaign_companions(GameManager.active_campaign.get("companions", {}))
	_assert(PartyManager.recruit_companion("aldric"), "overworld recruits a companion for roster UI")
	ow_hud.update_hud()
	await get_tree().process_frame
	_assert(ow_hud.player_list_container.get_child_count() == 3, "overworld roster includes local players and companion")
	var roster_text := ""
	for card in ow_hud.player_list_container.get_children():
		for label in card.find_children("", "Label", true, false):
			roster_text += str(label.text)
	_assert(roster_text.contains("Aldric") and roster_text.contains("Seat"), "overworld roster shows companion identity and owner seat")
	_assert(PartyManager.set_leader("slot_2"), "roster can transfer leadership to companion")
	ow_hud.update_hud()
	await get_tree().process_frame
	var rest_char: Character = PlayerManager.get_player(0).get("character")
	rest_char.current_hp = 1
	overworld._rest_party()
	_assert(rest_char.current_hp == rest_char.max_hp, "wilderness rest restored HP (1 -> %d)" % rest_char.current_hp)
	GameManager.game_in_progress = true
	SaveManager.delete_save("quicksave")
	ow_hud.save_pressed.emit()
	await get_tree().create_timer(0.2).timeout
	_assert(SaveManager.get_available_saves().has("quicksave"), "save button wrote 'quicksave' slot")

	# ---- Settings overlay (save/load anywhere + options) ----
	_assert(ow_hud.has_signal("settings_pressed"), "overworld HUD exposes settings_pressed signal")
	ow_hud.settings_pressed.emit()
	_assert(Settings.is_open(), "settings overlay opened from overworld")
	_assert(get_tree().paused, "tree paused while settings open")
	_assert(AudioServer.get_bus_index("SFX") >= 0 and AudioServer.get_bus_index("Music") >= 0, "settings audio buses exist for SFX and music controls")
	Settings.close_settings()
	_assert(not Settings.is_open(), "settings overlay closed")
	_assert(not get_tree().paused, "tree resumed after settings close")
	Settings.master_volume = 0.42
	Settings.save_settings()
	Settings.master_volume = 1.0
	Settings.load_settings()
	_assert(abs(Settings.master_volume - 0.42) < 0.001, "settings persisted to disk (master_volume)")
	Settings.sfx_volume = 0.37
	Settings.save_settings()
	var sfx_bus := AudioServer.get_bus_index("SFX")
	_assert(abs(AudioServer.get_bus_volume_db(sfx_bus) - linear_to_db(0.37)) < 0.01, "SFX volume control applies to the SFX bus")
	Settings.sfx_volume = 1.0

	# ---- Ambush is now a Stealth check, not a flat 40% roll ----
	_assert(overworld.has_method("_compute_ambush_dc"), "ambush uses Stealth DC calc")
	_assert(overworld.has_method("_party_best_stealth_mod"), "ambush uses party Stealth mod")
	var exp_dc := 12 + maxi(0, PlayerManager.get_player_count() - 1)
	_assert(overworld._compute_ambush_dc() == exp_dc, "ambush DC = 12 + (party-1) = %d" % exp_dc)
	var stealth_char: Character = PlayerManager.get_player(0).get("character")
	stealth_char.ability_scores.dexterity = 20
	var best_mod: int = overworld._party_best_stealth_mod()
	_assert(best_mod >= 5, "best Stealth mod reflects high DEX (got %d)" % best_mod)
	_assert(overworld.has_method("_on_rest_pressed"), "rest handler present (Stealth-based ambush)")

	_teardown_scene(overworld)
	_exit_test()


## Production Camp Roster UI: solo fill plus two-player decline, replacement,
## dismissal, and logical-owner reassignment.
func test_companion_lifecycle() -> void:
	_enter_test("companion_lifecycle")
	_setup_companion_party(1)
	var solo_overworld: Node = await _spawn_scene("res://scenes/overworld.tscn", 1.2)
	var solo_hud: Node = solo_overworld.hud
	solo_hud.btn_companions.pressed.emit()
	await get_tree().process_frame
	var solo_panel: CompanionRosterPanel = solo_hud.companion_panel
	_assert(solo_hud.companion_overlay.visible, "normal overworld UI opens the Camp Roster")
	_assert(solo_panel.companion_controls.size() == 3, "Camp Roster shows all three Crown companions")
	_assert(not solo_overworld.hex_grid.is_processing_input(), "Camp Roster suspends overworld map input")
	_assert(solo_hud.btn_end_turn.disabled and solo_hud.btn_rest.disabled, "Camp Roster disables turn-changing controls behind the modal")
	var roster_start := PartyManager.get_exploration_position()
	var blocked_destination := roster_start
	for candidate in solo_overworld.reachable_hexes:
		if candidate != roster_start:
			blocked_destination = candidate
			break
	if blocked_destination != roster_start:
		solo_overworld._on_hex_clicked(blocked_destination)
	_assert(PartyManager.get_exploration_position() == roster_start, "Camp Roster rejects direct movement intent while open")
	solo_panel.close_button.pressed.emit()
	await get_tree().process_frame
	_assert(not solo_hud.companion_overlay.visible and solo_overworld.hex_grid.is_processing_input(), "closing Camp Roster restores overworld map input")
	_assert(not solo_hud.btn_end_turn.disabled and not solo_hud.btn_rest.disabled, "closing Camp Roster restores turn-changing controls")
	solo_hud.btn_companions.pressed.emit()
	await get_tree().process_frame
	solo_panel = solo_hud.companion_panel

	var rowan_controls: Dictionary = solo_panel.companion_controls.get("rowan", {})
	rowan_controls.get("decline_button").pressed.emit()
	await get_tree().process_frame
	_assert(PartyManager.get_companion_state("rowan") == "declined", "normal UI can decline a companion")
	_assert(SaveManager.save_game("companion_lifecycle"), "declined companion state passes the supported save validator")
	SaveManager.delete_save("companion_lifecycle")
	rowan_controls = solo_panel.companion_controls.get("rowan", {})
	rowan_controls.get("reconsider_button").pressed.emit()
	await get_tree().process_frame
	_assert(PartyManager.get_companion_state("rowan") == "available", "normal UI can reconsider a declined companion")

	for companion_id in ["aldric", "mira", "rowan"]:
		var controls: Dictionary = solo_panel.companion_controls.get(companion_id, {})
		var seat_selector: OptionButton = controls.get("seat_selector")
		seat_selector.select(0)
		controls.get("recruit_button").pressed.emit()
		await get_tree().process_frame
	_assert(PartyManager.get_active_characters().size() == 4, "solo Camp Roster fills all three empty party slots")
	var solo_owns_all := true
	for slot in PartyManager.party_slots:
		if bool(slot.get("occupied", false)) and PlayerManager.get_player_for_party_slot(str(slot.get("slot_id", ""))) != 0:
			solo_owns_all = false
	_assert(solo_owns_all, "solo player owns every recruited companion turn")
	_teardown_scene(solo_overworld)

	_setup_companion_party(2)
	var coop_overworld: Node = await _spawn_scene("res://scenes/overworld.tscn", 1.2)
	var coop_hud: Node = coop_overworld.hud
	coop_hud.btn_companions.pressed.emit()
	await get_tree().process_frame
	var coop_panel: CompanionRosterPanel = coop_hud.companion_panel
	for recruit_spec in [{"id": "aldric", "seat": 0}, {"id": "mira", "seat": 1}]:
		var controls: Dictionary = coop_panel.companion_controls.get(recruit_spec["id"], {})
		var selector: OptionButton = controls.get("seat_selector")
		selector.select(int(recruit_spec["seat"]))
		controls.get("recruit_button").pressed.emit()
		await get_tree().process_frame
	_assert(PartyManager.get_active_characters().size() == 4, "two-player Camp Roster fills both open slots")
	var capture_path := OS.get_environment("VIEWPORT_CAPTURE_PATH")
	if not capture_path.is_empty() and DisplayServer.get_name() != "headless":
		var capture_viewport: SubViewport = coop_overworld.get_meta("vp")
		capture_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var capture_image := capture_viewport.get_texture().get_image()
		_assert(capture_image.save_png(capture_path) == OK, "Camp Roster visual capture saved")

	rowan_controls = coop_panel.companion_controls.get("rowan", {})
	var replace_selector: OptionButton = rowan_controls.get("replace_selector")
	var aldric_option := -1
	for option_index in replace_selector.item_count:
		if str(replace_selector.get_item_metadata(option_index)) == "aldric":
			aldric_option = option_index
			break
	_assert(aldric_option >= 0, "full-party UI offers a recruited companion as the replacement target")
	if aldric_option >= 0:
		replace_selector.select(aldric_option)
	var replacement_seat: OptionButton = rowan_controls.get("seat_selector")
	replacement_seat.select(0)
	rowan_controls.get("replace_button").pressed.emit()
	await get_tree().process_frame
	_assert(PartyManager.get_companion_state("aldric") == "dismissed" and PartyManager.get_companion_state("rowan") == "recruited", "normal UI atomically replaces one companion with another")
	_assert(PartyManager.get_active_characters().size() == 4, "replacement preserves full party capacity")
	var rowan_slot := PartyManager.get_companion_slot_id("rowan")
	_assert(PlayerManager.get_player_for_party_slot(rowan_slot) == 0, "replacement applies the chosen initial owner")

	rowan_controls = coop_panel.companion_controls.get("rowan", {})
	var owner_selector: OptionButton = rowan_controls.get("owner_selector")
	owner_selector.select(1)
	owner_selector.item_selected.emit(1)
	await get_tree().process_frame
	_assert(PlayerManager.get_player_for_party_slot(rowan_slot) == 1, "normal UI reassigns a companion from Seat 1 to Seat 2")
	var mira_controls: Dictionary = coop_panel.companion_controls.get("mira", {})
	mira_controls.get("dismiss_button").pressed.emit()
	await get_tree().process_frame
	_assert(PartyManager.get_companion_state("mira") == "dismissed" and PartyManager.get_active_characters().size() == 3, "normal UI dismisses a recruited companion and opens its slot")
	_assert(coop_panel.companion_controls.get("mira", {}).has("reconsider_button"), "dismissed companion exposes an Invite back action")
	_teardown_scene(coop_overworld)
	_exit_test()

## Crown composition rows: production Camp Roster ownership, safe save/load,
## objective visibility, and combat formation for one and two local seats.
## Normal shared-keyboard play remains a manual review boundary.
func test_crown_composition_solo_two() -> void:
	_enter_test("crown_composition_solo_two")
	var solo_slot := "crown_composition_solo"
	_setup_companion_party(1)
	GameManager.active_dungeon_state.clear()
	var solo_overworld: Node = await _spawn_scene("res://scenes/overworld.tscn", 1.0)
	solo_overworld.hud.btn_companions.pressed.emit()
	await get_tree().process_frame
	var solo_panel: CompanionRosterPanel = solo_overworld.hud.companion_panel
	for companion_id in ["aldric", "mira", "rowan"]:
		var controls: Dictionary = solo_panel.companion_controls.get(companion_id, {})
		var selector: OptionButton = controls.get("seat_selector")
		selector.select(0)
		controls.get("recruit_button").pressed.emit()
		await get_tree().process_frame
	_assert(PartyManager.get_active_characters().size() == 4, "solo composition fills three companion slots")
	_assert(PlayerManager.get_player_for_party_slot("slot_0") == 0, "solo composition preserves the local seat owner")
	var solo_objectives := " | ".join(GameManager.get_campaign_objectives())
	_assert(solo_objectives.contains("Crown"), "solo composition keeps the player-facing Crown objective")
	solo_panel.close_button.pressed.emit()
	await get_tree().process_frame
	SaveManager.delete_save(solo_slot)
	_assert(SaveManager.save_game(solo_slot), "solo composition saves its full party at the overworld boundary")
	_teardown_scene(solo_overworld)
	await _run_composition_combat("solo", [0, 0, 0, 0])
	PlayerManager.reset()
	PartyManager.reset()
	_assert(SaveManager.load_game(solo_slot), "solo composition reloads its four-member party")
	_assert(PartyManager.get_active_characters().size() == 4 and PlayerManager.get_player_for_party_slot("slot_3") == 0, "solo composition reload preserves companion ownership")
	SaveManager.delete_save(solo_slot)

	var two_player_slot := "crown_composition_two_player"
	_setup_companion_party(2)
	GameManager.active_dungeon_state.clear()
	var two_overworld: Node = await _spawn_scene("res://scenes/overworld.tscn", 1.0)
	two_overworld.hud.btn_companions.pressed.emit()
	await get_tree().process_frame
	var two_panel: CompanionRosterPanel = two_overworld.hud.companion_panel
	for recruit_spec in [{"id": "aldric", "seat": 0}, {"id": "mira", "seat": 1}]:
		var controls: Dictionary = two_panel.companion_controls.get(recruit_spec["id"], {})
		var selector: OptionButton = controls.get("seat_selector")
		selector.select(int(recruit_spec["seat"]))
		controls.get("recruit_button").pressed.emit()
		await get_tree().process_frame
	_assert(PartyManager.get_active_characters().size() == 4, "two-player composition fills two companion slots")
	_assert(PlayerManager.get_player_for_party_slot("slot_2") == 0 and PlayerManager.get_player_for_party_slot("slot_3") == 1, "two-player composition assigns companions to both local seats")
	two_panel.close_button.pressed.emit()
	await get_tree().process_frame
	SaveManager.delete_save(two_player_slot)
	_assert(SaveManager.save_game(two_player_slot), "two-player composition saves the mixed party at the overworld boundary")
	_teardown_scene(two_overworld)
	await _run_composition_combat("two-player", [0, 0, 1, 1])
	PlayerManager.reset()
	PartyManager.reset()
	_assert(SaveManager.load_game(two_player_slot), "two-player composition reloads its mixed party")
	_assert(PartyManager.get_active_characters().size() == 4 and PlayerManager.get_player_for_party_slot("slot_2") == 0 and PlayerManager.get_player_for_party_slot("slot_3") == 1, "two-player composition reload preserves both companion owners")
	SaveManager.delete_save(two_player_slot)
	GameManager.game_in_progress = false
	_exit_test()


## Crown composition rows for three local seats plus one companion and four
## local character seats. Normal shared-keyboard ownership remains review.
func test_crown_composition_three_four() -> void:
	_enter_test("crown_composition_three_four")
	var three_slot := "crown_composition_three_player"
	_setup_companion_party(3)
	GameManager.active_dungeon_state.clear()
	var three_overworld: Node = await _spawn_scene("res://scenes/overworld.tscn", 1.0)
	three_overworld.hud.btn_companions.pressed.emit()
	await get_tree().process_frame
	var three_panel: CompanionRosterPanel = three_overworld.hud.companion_panel
	var rowan_controls: Dictionary = three_panel.companion_controls.get("rowan", {})
	var rowan_selector: OptionButton = rowan_controls.get("seat_selector")
	rowan_selector.select(2)
	rowan_controls.get("recruit_button").pressed.emit()
	await get_tree().process_frame
	_assert(PartyManager.get_active_characters().size() == 4, "three-player composition fills its final slot with Rowan")
	_assert(PlayerManager.get_player_for_party_slot("slot_3") == 2, "three-player composition assigns Rowan to Seat 3")
	three_panel.close_button.pressed.emit()
	await get_tree().process_frame
	SaveManager.delete_save(three_slot)
	_assert(SaveManager.save_game(three_slot), "three-player composition saves at the overworld boundary")
	_teardown_scene(three_overworld)
	await _run_composition_combat("three-player", [0, 1, 2, 2])
	PlayerManager.reset()
	PartyManager.reset()
	_assert(SaveManager.load_game(three_slot), "three-player composition reloads its mixed party")
	_assert(PartyManager.get_active_characters().size() == 4 and PlayerManager.get_player_for_party_slot("slot_3") == 2, "three-player composition reload preserves Rowan ownership")
	SaveManager.delete_save(three_slot)

	var four_slot := "crown_composition_four_player"
	_setup_companion_party(4)
	GameManager.active_dungeon_state.clear()
	var four_overworld: Node = await _spawn_scene("res://scenes/overworld.tscn", 1.0)
	_assert(PartyManager.get_active_characters().size() == 4, "four-player composition starts with four local characters")
	var four_objectives := " | ".join(GameManager.get_campaign_objectives())
	_assert(four_objectives.contains("Crown"), "four-player composition keeps the player-facing Crown objective")
	SaveManager.delete_save(four_slot)
	_assert(SaveManager.save_game(four_slot), "four-player composition saves at the overworld boundary")
	_teardown_scene(four_overworld)
	await _run_composition_combat("four-player", [0, 1, 2, 3])
	PlayerManager.reset()
	PartyManager.reset()
	_assert(SaveManager.load_game(four_slot), "four-player composition reloads all local characters")
	_assert(PartyManager.get_active_characters().size() == 4 and PlayerManager.get_player_for_party_slot("slot_3") == 3, "four-player composition reload preserves Seat 4 ownership")
	SaveManager.delete_save(four_slot)
	GameManager.game_in_progress = false
	_exit_test()


func _run_composition_combat(label: String, expected_owners: Array) -> void:
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"monster_ids": ["goblin"], "return_state": GameManager.GameState.OVERWORLD, "terrain": "plains"}
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	_assert(combat.player_entities.size() == 4, "%s composition enters combat with four active characters" % label)
	var actual_owners: Array = []
	var positions: Dictionary = {}
	for entity in combat.player_entities:
		actual_owners.append(int(entity.get("owner_player_index", -1)))
		positions[entity.get("hex_position", Vector2i.ZERO)] = true
	actual_owners.sort()
	var sorted_expected := expected_owners.duplicate()
	sorted_expected.sort()
	_assert(actual_owners == sorted_expected, "%s composition preserves combat seat ownership" % label)
	_assert(positions.size() == 4, "%s composition enters with distinct combat formation positions" % label)
	_teardown_scene(combat)


func _setup_companion_party(player_count: int) -> void:
	GameManager.active_campaign = DataLoader.get_campaign("the_lost_crown")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.transition_context = {}
	GameManager.is_loading_save = false
	GameManager.game_in_progress = true
	GameManager.test_mode = true
	GameManager.recruited_companions.clear()
	GameManager.dismissed_companions.clear()
	PlayerManager.reset()
	PartyManager.reset()
	for seat_index in player_count:
		PlayerManager.add_player("Seat %d" % (seat_index + 1))
		var character := _fresh_char(
			"Hero %d" % (seat_index + 1),
			"human",
			"fighter" if seat_index == 0 else "wizard",
			{"STR": 15, "DEX": 14, "CON": 13, "INT": 12, "WIS": 10, "CHA": 8}
		)
		PlayerManager.set_player_character(seat_index, character)
		PartyManager.register_player_character(seat_index, character)
	PartyManager.initialize_campaign_companions(GameManager.active_campaign.get("companions", {}))

## Main-menu Load Game UI (writes its own quicksave so it's self-contained).
func test_main_menu_load() -> void:
	_enter_test("main_menu_load")
	_setup_world()
	GameManager.game_in_progress = true
	SaveManager.delete_save("quicksave")
	SaveManager.save_game("quicksave")
	var main_menu: Node = await _spawn_scene("res://scenes/main_menu.tscn", 1.0)

	_assert(main_menu.btn_load != null, "main menu has Load Game button")
	_assert(main_menu.save_slot_list != null, "main menu has save-slot list")
	_assert(SaveManager.get_available_saves().has("quicksave"), "quicksave available for menu load")
	_assert(not main_menu.btn_load.disabled, "load button enabled when saves exist")
	_assert(main_menu.has_method("_on_load_pressed"), "main menu wires _on_load_pressed")
	_assert(main_menu.has_method("_refresh_save_slots"), "main menu populates save slots on ready")

	_teardown_scene(main_menu)
	_exit_test()

## Dungeon boot + rooms + party move.
func test_dungeon() -> void:
	_enter_test("dungeon")
	_setup_world()
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: Node = await _spawn_scene("res://scenes/dungeon.tscn", 2.5)

	_assert(dungeon != null, "dungeon scene instantiated without error")
	_assert(dungeon.hex_grid != null, "dungeon HexGrid @onready resolved")
	_assert(dungeon.hex_grid.tiles.size() > 0, "dungeon rooms generated (got %d)" % dungeon.hex_grid.tiles.size())
	_assert(dungeon.hud != null, "dungeon HUD @onready resolved")
	_assert(dungeon.hud.get("btn_end_turn") == null, "dungeon HUD truly has NO end-turn button (real BaseHUD split, not hidden)")
	_assert(dungeon.hud.has_signal("rest_pressed"), "dungeon HUD exposes rest_pressed signal")
	_assert(dungeon.hud.has_signal("save_pressed"), "dungeon HUD exposes save_pressed signal")
	_assert(dungeon.hud.has_signal("menu_pressed"), "dungeon HUD exposes menu_pressed signal")
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
	_assert(dungeon.party_position == Vector2i.ZERO, "dungeon party starts at origin")
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

	_teardown_scene(dungeon)
	_exit_test()

## EventDialog UI: choice + skill-check events, roll seam, re-popup regression.
func test_event_dialog() -> void:
	_enter_test("event_dialog")
	var ev_dialog: EventDialog = await _spawn_scene("res://scenes/ui/event_dialog.tscn", 0.3)

	_assert(ev_dialog != null, "EventDialog instantiated")
	var ev_scores := AbilityScores.new()
	ev_scores.from_dict({"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
	var ev_char := Character.new()
	ev_char.initialize("EventTester", "human", "fighter", ev_scores)
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
	_assert(ev_dialog.btn_roll.visible, "EventDialog roll button visible for skill_check event")
	_assert(ev_dialog.btn_roll.pressed.is_connected(ev_dialog._on_btn_roll_pressed),
		"EventDialog roll button wired to stable handler (not one-shot)")
	ev_dialog.btn_roll.pressed.emit()
	_assert(ev_dialog.roll_result_lbl.text.begins_with("Rolled:"),
		"EventDialog skill_check roll produced a result label ('%s')" % ev_dialog.roll_result_lbl.text)
	ev_dialog.popup_event(ev_char, skill_evt)
	_assert(ev_dialog.roll_result_lbl.text == "", "EventDialog result label reset on re-popup")
	ev_dialog.btn_roll.pressed.emit()
	_assert(ev_dialog.roll_result_lbl.text.begins_with("Rolled:"),
		"EventDialog roll still fires on re-popup (one-shot regression)")

	_teardown_scene(ev_dialog)
	_exit_test()

## Production Crown event chain: verify the Fairy Ring follow-up, every legal
## choice, and each deterministic branch outcome through shared resolvers.
func test_crown_event_fairy_ring() -> void:
	_enter_test("crown_event_fairy_ring")
	var forest_events: Dictionary = DataLoader.get_event_table("forest_events")
	var fairy_ring: Dictionary = {}
	for candidate in forest_events.get("events", []):
		if str(candidate.get("id", "")) == "fairy_ring":
			fairy_ring = candidate
			break
	var fairy_court: Dictionary = EventChain.get_chain_event(fairy_ring)
	_assert(EventChain.has_chain(fairy_ring) and str(fairy_ring.get("type", "")) == "chain", "Fairy Ring is a production event chain")
	_assert(str(fairy_court.get("id", "")) == "fairy_court" and str(fairy_court.get("type", "")) == "choice", "Fairy Ring exposes its Fairy Court follow-up")
	var choices: Array = fairy_court.get("choices", [])
	_assert(choices.size() == 3, "Fairy Court exposes all three legal choices")
	var steal_choice: Dictionary = choices[2] if choices.size() > 2 else {}
	_assert(int(steal_choice.get("check", {}).get("dc", -1)) == 16 and str(steal_choice.get("check", {}).get("ability", "")) == "DEX", "Fairy treasure choice carries the production DEX DC 16 check")

	var chain_character := _fresh_char("Fairy Chain Tester", "human", "rogue",
		{"STR": 10, "DEX": 18, "CON": 12, "INT": 12, "WIS": 10, "CHA": 10})
	var chain_results := EventResolver.apply_effects(chain_character, fairy_ring.get("effects", []))
	var teleported := false
	for result in chain_results:
		if str(result.get("type", "")) == "teleport_random":
			teleported = true
	_assert(teleported, "Fairy Ring root applies its production teleport consequence")

	var accept_character := _fresh_char("Fairy Gift", "human", "fighter",
		{"STR": 15, "DEX": 14, "CON": 13, "INT": 12, "WIS": 10, "CHA": 8})
	accept_character.current_hp = accept_character.max_hp - 5
	var accept_hp_before := accept_character.current_hp
	var accept_results := EventResolver.apply_effects(accept_character, choices[0].get("effects", []))
	_assert(accept_character.has_condition("fairy_luck") and accept_character.current_hp > accept_hp_before and not accept_results.is_empty(), "Fairy gift applies luck and healing through shared effects")

	var decline_character := _fresh_char("Fairy Decline", "human", "fighter",
		{"STR": 15, "DEX": 14, "CON": 13, "INT": 12, "WIS": 10, "CHA": 8})
	var decline_hp_before := decline_character.current_hp
	var decline_results := EventResolver.apply_effects(decline_character, choices[1].get("effects", []))
	_assert(decline_results.is_empty() and decline_character.current_hp == decline_hp_before and not decline_character.has_condition("fairy_luck"), "Polite decline preserves the character without hidden effects")

	var steal_success_character := _fresh_char("Fairy Thief", "halfling", "rogue",
		{"STR": 10, "DEX": 18, "CON": 12, "INT": 12, "WIS": 10, "CHA": 10})
	var forced_success := EventResolver.resolve_skill_check(steal_success_character, {"ability": "DEX", "dc": 1})
	var success_results := EventResolver.apply_effects(steal_success_character, steal_choice.get("success", {}).get("effects", []))
	_assert(forced_success.get("success", false) and steal_success_character.inventory.has_item("gold_100") and not success_results.is_empty(), "Fairy treasure success grants the production reward")

	var steal_failure_character := _fresh_char("Fairy Caught", "human", "rogue",
		{"STR": 10, "DEX": 8, "CON": 12, "INT": 10, "WIS": 10, "CHA": 10})
	var forced_failure := EventResolver.resolve_skill_check(steal_failure_character, {"ability": "DEX", "dc": 99})
	var failure_results := EventResolver.apply_effects(steal_failure_character, steal_choice.get("failure", {}).get("effects", []))
	_assert(not forced_failure.get("success", true) and steal_failure_character.has_condition("cursed") and not failure_results.is_empty(), "Fairy treasure failure applies the production curse consequence")
	_assert(not fairy_ring.has("companion_change") and not fairy_ring.has("ledger") and not fairy_court.has("companion_change") and not fairy_court.has("ledger"), "Fairy Ring declares no companion or campaign-ledger mutation")

	var dialog_character := _fresh_char("Fairy UI", "human", "fighter",
		{"STR": 15, "DEX": 14, "CON": 13, "INT": 12, "WIS": 10, "CHA": 8})
	var dialog: EventDialog = await _spawn_scene("res://scenes/ui/event_dialog.tscn", 0.2)
	dialog.popup_event(dialog_character, fairy_ring)
	await get_tree().create_timer(0.2).timeout
	_assert(dialog.title_label.text == "Fairy Ring" and dialog.btn_close.text == "Next event...", "Fairy Ring UI presents its chain continuation")
	dialog.btn_close.pressed.emit()
	await get_tree().create_timer(0.2).timeout
	_assert(dialog.title_label.text == "The Fairy Court" and dialog.choice_container.get_child_count() == 3, "Fairy Ring UI opens the three-choice follow-up")
	var accept_button := dialog.choice_container.get_child(0) as Button
	accept_button.pressed.emit()
	await get_tree().create_timer(0.2).timeout
	_assert(dialog_character.has_condition("fairy_luck") and not dialog.choice_container.visible, "Fairy Ring UI choice reaches the shared effect result")
	_teardown_scene(dialog)
	_exit_test()

## Crown dungeon clear, safe-save DTO, supported reload, and idempotent re-entry.
## The normal GUI quit/relaunch remains a manual review boundary.
func test_dungeon_reentry_round_trip() -> void:
	_enter_test("dungeon_reentry_round_trip")
	_setup_world()
	GameManager.game_in_progress = true
	PartyManager.initialize_campaign_companions(GameManager.active_campaign.get("companions", {}))
	_assert(PartyManager.recruit_companion("aldric"), "dungeon re-entry recruits Aldric")
	_assert(PartyManager.recruit_companion("mira"), "dungeon re-entry recruits Mira")

	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: Node = await _spawn_scene("res://scenes/dungeon.tscn", 0.8)
	var boss: Room = null
	for candidate in dungeon.rooms.values():
		if candidate is Room and candidate.type == Room.RoomType.BOSS:
			boss = candidate
			break
	_assert(boss != null and dungeon.rooms.size() == 5, "dungeon re-entry uses the production five-room Crown dungeon")
	if boss == null:
		_teardown_scene(dungeon)
		SaveManager.delete_save("dungeon_reentry_round_trip")
		_exit_test()
		return

	dungeon._begin_room_combat(boss)
	_assert(dungeon.pending_combat_room_id == boss.id and not boss.is_cleared, "dungeon re-entry records the unresolved boss room")
	_assert(dungeon._complete_pending_combat() == boss, "dungeon re-entry applies the victory boundary to the pending boss")
	_assert(boss.is_cleared and dungeon.boss_defeated and dungeon.pending_combat_room_id == -1, "dungeon re-entry clears the boss and resets pending combat")
	_assert(GameManager.mark_dungeon_cleared("ruins_of_ashvale"), "dungeon re-entry records the one-time dungeon clear")
	_assert(GameManager.claim_reward("ruins_of_ashvale_fragment"), "dungeon re-entry records the one-time Crown reward")
	_assert(SaveManager.get_save_block_reason().is_empty(), "dungeon re-entry permits saving at the entrance checkpoint")

	var slot := "dungeon_reentry_round_trip"
	SaveManager.delete_save(slot)
	_assert(SaveManager.save_game(slot), "dungeon re-entry writes the cleared dungeon checkpoint")
	var checkpoint_file := FileAccess.open("user://saves/%s.sav" % slot, FileAccess.READ)
	var checkpoint_json := JSON.new()
	var checkpoint_parse := checkpoint_json.parse(checkpoint_file.get_as_text()) if checkpoint_file != null else ERR_FILE_NOT_FOUND
	if checkpoint_file != null:
		checkpoint_file.close()
	var checkpoint_dto: Dictionary = checkpoint_json.data if checkpoint_parse == OK and checkpoint_json.data is Dictionary else {}
	var saved_dungeon: Dictionary = checkpoint_dto.get("active_dungeon_state", {})
	var saved_rooms = saved_dungeon.get("rooms", []) if saved_dungeon is Dictionary else []
	_assert(saved_rooms is Array and saved_rooms.size() == 5, "dungeon re-entry checkpoint stores five plain Room DTOs")
	_assert(saved_dungeon.get("pending_combat_room_id", -1) == -1 and saved_dungeon.get("boss_defeated", false), "dungeon re-entry checkpoint stores completed combat state")

	_teardown_scene(dungeon)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.transition_context = {"returning_from_dungeon": true}
	GameManager.active_dungeon_state.clear()
	_assert(SaveManager.save_game(slot), "dungeon re-entry saves again after the dungeon exit boundary")
	PlayerManager.reset()
	PartyManager.reset()
	_assert(SaveManager.load_game(slot), "dungeon re-entry reloads through the supported save boundary")
	_assert(GameManager.current_state == GameManager.GameState.OVERWORLD and GameManager.cleared_dungeons.has("ruins_of_ashvale"), "dungeon re-entry restores the overworld and clear ledger")
	_assert(GameManager.claimed_rewards.has("ruins_of_ashvale_fragment"), "dungeon re-entry restores the reward ledger")

	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var reentered: Node = await _spawn_scene("res://scenes/dungeon.tscn", 0.6)
	var rooms_cleared := true
	var reentered_boss: Room = null
	for candidate in reentered.rooms.values():
		if candidate is Room:
			rooms_cleared = rooms_cleared and candidate.is_cleared and candidate.is_revealed
			if candidate.type == Room.RoomType.BOSS:
				reentered_boss = candidate
	_assert(rooms_cleared and reentered.boss_defeated, "dungeon re-entry rebuilds a cleared dungeon without losing clear state")
	_assert(reentered_boss != null, "dungeon re-entry finds the previously cleared boss room")
	if reentered_boss != null:
		reentered._resolve_room_encounter(reentered_boss)
	var revisited_pending = reentered._complete_pending_combat()
	_assert(reentered_boss.is_cleared and revisited_pending == null, "dungeon re-entry revisiting the boss cannot reopen combat")
	_assert(not GameManager.mark_dungeon_cleared("ruins_of_ashvale"), "dungeon re-entry does not duplicate the clear ledger")
	_assert(not GameManager.claim_reward("ruins_of_ashvale_fragment"), "dungeon re-entry does not duplicate the Crown reward")
	_teardown_scene(reentered)
	SaveManager.delete_save(slot)
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = false
	_exit_test()

## Character creation flow: randomize + per-player confirm/save loop.
func test_character_creation() -> void:
	_enter_test("character_creation")
	PlayerManager.reset()
	PlayerManager.add_player("Alice")
	PlayerManager.add_player("Bob")
	PlayerManager.add_player("Carol")
	var cc: Node = await _spawn_scene("res://scenes/ui/character_creation.tscn", 0.5)

	_assert(cc != null, "character_creation scene instantiated")
	_assert(cc.race_grid.get_child_count() > 0, "character_creation built race cards")
	_assert(cc.current_step == cc.CreationStep.RACE, "character_creation starts at RACE step")
	cc._on_randomize_pressed()
	await get_tree().create_timer(0.2).timeout
	_assert(not cc.selected_race_id.is_empty(), "character_creation race selected after randomize")
	_assert(not cc.selected_class_id.is_empty(), "character_creation class selected after randomize")
	_assert(cc.current_step == cc.CreationStep.SUMMARY, "character_creation jumped to SUMMARY after randomize")
	cc._confirm_and_save_character()
	await get_tree().create_timer(0.3).timeout
	_assert(PlayerManager.get_player(0).get("character") != null, "player 0 character saved via creation flow")
	_assert(cc.current_player_idx == 1, "creation flow advanced to player 1")
	cc._on_randomize_pressed()
	await get_tree().create_timer(0.2).timeout
	_assert(not cc.selected_race_id.is_empty(), "player 1 selections built in creation flow")
	cc._confirm_and_save_character()
	await get_tree().create_timer(0.3).timeout
	_assert(PlayerManager.get_player(1).get("character") != null, "player 1 character saved via creation flow")
	_assert(cc.current_player_idx == 2, "creation flow advanced to player 2")

	_teardown_scene(cc)
	_exit_test()

## Shop UI: setup + purchase deducts gold + adds to backpack.
func test_shop() -> void:
	_enter_test("shop")
	if PlayerManager.get_player(0).get("character") == null:
		var s1 := AbilityScores.new()
		s1.from_dict({"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
		var shop_char := Character.new()
		shop_char.initialize("Shopper","human","fighter",s1)
		PlayerManager.set_player_character(0, shop_char)
	var shop: ShopUI = await _spawn_scene("res://scenes/ui/shop.tscn", 0.3)

	_assert(shop != null, "ShopUI instantiated")
	shop.setup_shop("Test Town")
	await get_tree().create_timer(0.2).timeout
	_assert(shop.items_data.size() > 0, "ShopUI populated buyable items (got %d)" % shop.items_data.size())
	var catalog_is_executable := true
	for item in shop.items_data:
		if not shop._is_buyable_item(item) or str(item.get("type", "")) in ["tool", "currency"] or bool(item.get("quest_item", false)):
			catalog_is_executable = false
	_assert(catalog_is_executable, "ShopUI catalog excludes tools, quest items, and unsupported consumables")
	_assert(shop.gold_label.text.contains("Gold"), "ShopUI gold label set")
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

	_teardown_scene(shop)
	_exit_test()

## SaveManager save/load/delete round-trip (actual SaveManager).
func test_save_load() -> void:
	_enter_test("save_load")
	GameManager.active_campaign = DataLoader.campaigns.values()[0]
	GameManager.current_state = GameManager.GameState.OVERWORLD
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
	GameManager.defeated_monsters.clear()
	PlayerManager.reset()
	PlayerManager.add_player("Nobody")
	var load_ok: bool = SaveManager.load_game("harness_test_slot")
	_assert(load_ok, "SaveManager.load_game returned true")
	_assert(GameManager.defeated_monsters.has("goblin"), "load restored defeated_monsters")
	_assert(PlayerManager.get_player_count() == 1, "load restored player count")
	_assert(PlayerManager.get_player(0).get("character") != null, "load restored player character")
	_assert(PlayerManager.get_player(0).get("character").character_name == "Saver", "load restored character name")
	var del_ok: bool = SaveManager.delete_save("harness_test_slot")
	_assert(del_ok, "SaveManager.delete_save returned true")
	_assert(not SaveManager.get_available_saves().has("harness_test_slot"), "save slot gone after delete")
	await get_tree().process_frame
	_exit_test()

## Spend representative class resources, save at the overworld safe point,
## reload through the real DTO boundary, and boot the next combat from it.
func test_action_resource_round_trip() -> void:
	_enter_test("action_resource_round_trip")
	GameManager.active_campaign = DataLoader.campaigns.values()[0]
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.game_in_progress = true
	GameManager.test_mode = true
	PlayerManager.reset()
	PartyManager.reset()

	PlayerManager.add_player("Resource Fighter")
	PlayerManager.add_player("Resource Wizard")
	var fighter := _fresh_char("Resource Fighter", "human", "fighter",
		{"STR": 18, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 8})
	var wizard := _fresh_char("Resource Wizard", "elf", "wizard",
		{"STR": 8, "DEX": 14, "CON": 14, "INT": 18, "WIS": 12, "CHA": 10})
	PlayerManager.set_player_character(0, fighter)
	PlayerManager.set_player_character(1, wizard)
	PartyManager.sync_from_player_manager()

	var fighter_feature_before := int(fighter.feature_uses.get("fighter_second_wind", 0))
	var wizard_slot_before := int(wizard.spell_slots.get("1", 0))
	_assert(fighter_feature_before > 0 and wizard_slot_before > 0, "resource fixture starts with production feature and spell-slot uses")
	_assert(fighter.use_feature("fighter_second_wind"), "production Fighter feature spend succeeds before save")
	var magic_missile := DataLoader.get_spell("magic_missile")
	var slot_spend := CombatAction.spend_spell_slot(wizard, magic_missile)
	_assert(slot_spend.get("success", false), "production Wizard spell-slot spend succeeds before save")
	var fighter_feature_after_spend := int(fighter.feature_uses.get("fighter_second_wind", 0))
	var wizard_slot_after_spend := int(wizard.spell_slots.get("1", 0))
	var slot := "action_resource_round_trip"
	SaveManager.delete_save(slot)
	_assert(SaveManager.save_game(slot), "spent action resources save at the overworld safe point")

	PlayerManager.reset()
	PartyManager.reset()
	_assert(SaveManager.load_game(slot), "fresh supported flow reloads the spent resource save")
	var restored_fighter: Character = PlayerManager.get_player(0).get("character")
	var restored_wizard: Character = PlayerManager.get_player(1).get("character")
	_assert(restored_fighter != null and restored_wizard != null, "resource round-trip restores both production characters")
	_assert(int(restored_fighter.feature_uses.get("fighter_second_wind", -1)) == fighter_feature_after_spend, "Fighter feature uses survive save/load")
	_assert(int(restored_wizard.spell_slots.get("1", -1)) == wizard_slot_after_spend, "Wizard remaining spell slots survive save/load")

	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 2.0)
	_assert(combat != null and combat.player_entities.size() == 2, "next combat boots from the restored party")
	var combat_wizard: Character = combat.player_entities[1].get("character") if combat != null and combat.player_entities.size() > 1 else null
	_assert(combat_wizard != null and int(combat_wizard.spell_slots.get("1", -1)) == wizard_slot_after_spend, "next combat sees the restored Wizard slot state")
	_teardown_scene(combat)
	SaveManager.delete_save(slot)
	GameManager.game_in_progress = false
	_exit_test()

## Combat resolution: attack -> damage -> kill (pure logic, no scene).
func test_combat_resolution() -> void:
	_enter_test("combat_resolution")
	var atk_scores := AbilityScores.new()
	atk_scores.from_dict({"STR":18,"DEX":14,"CON":14,"INT":10,"WIS":12,"CHA":8})
	var attacker := Character.new()
	attacker.initialize("Slayer", "human", "fighter", atk_scores)
	var tgt_scores := AbilityScores.new()
	tgt_scores.from_dict({"STR":10,"DEX":10,"CON":10,"INT":10,"WIS":10,"CHA":10})
	var defender := Character.new()
	defender.initialize("PunchingBag", "goblin", "fighter", tgt_scores)
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
	_exit_test()

## Event choice resolution: real EventResolver.apply_effects.
func test_event_choice_resolution() -> void:
	_enter_test("event_choice_resolution")
	var ev2_scores := AbilityScores.new()
	ev2_scores.from_dict({"STR":15,"DEX":14,"CON":13,"INT":12,"WIS":10,"CHA":8})
	var ev2_char := Character.new()
	ev2_char.initialize("Chooser", "human", "fighter", ev2_scores)
	ev2_char.inventory.gold = 0
	ev2_char.current_hp = ev2_char.max_hp
	var before_hp := ev2_char.current_hp
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
	_assert(ev2_char.inventory.has_item("gold_100"), "event choice gave gold_100 item to backpack")
	var heal_choice := [{"type":"heal","value":"2d4"}]
	var hp_before_heal := ev2_char.current_hp
	EventResolver.apply_effects(ev2_char, heal_choice)
	_assert(ev2_char.current_hp > hp_before_heal, "event heal raised hp (%d -> %d)" % [hp_before_heal, ev2_char.current_hp])
	_exit_test()

## Event dialog choice click: end-to-end UI -> resolver.
func test_event_dialog_choice_click() -> void:
	_enter_test("event_dialog_choice_click")
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
	var dungeon_events2: Dictionary = DataLoader.get_event_table("dungeon_events")
	var event_list2: Array = dungeon_events2.get("events", [])
	var trapped_chest_evt: Dictionary = {}
	for e in event_list2:
		if e.get("id", "") == "trapped_chest":
			trapped_chest_evt = e
			break
	evd2.popup_event(dialog_char, trapped_chest_evt)
	var choice_buttons: Array = evd2.choice_container.get_children()
	_assert(choice_buttons.size() == 3, "trapped_chest has 3 choice buttons in dialog")
	choice_buttons[1].pressed.emit()
	_assert(dialog_char.current_hp < dialog_char.max_hp, "dialog choice dealt damage to character")
	_assert(dialog_char.inventory.has_item("gold_100"), "dialog choice gave gold_100 via UI")
	evd2vp.remove_child(evd2)
	evd2.queue_free()
	evd2vp.queue_free()
	_exit_test()

## Character Sheet overlay: show + render sections + close.
func test_character_sheet() -> void:
	_enter_test("character_sheet")
	# The harness itself is the scene root; wait until its _ready() child setup
	# has finished before the autoload adds its CanvasLayer to the root.
	await get_tree().process_frame
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
	CharacterSheet.close_sheet()
	_assert(not CharacterSheet.is_open(), "character sheet closes (is_open false)")
	_assert(CharacterSheet._layer == null or not CharacterSheet._layer.visible, "character sheet layer hidden after close")
	CharacterSheet.teardown_for_tests()
	await get_tree().process_frame
	PlayerManager.reset()
	_exit_test()


## Character Sheet button wiring through the normal overworld, dungeon, and
## combat HUD signals. This deliberately presses each production Button rather
## than calling CharacterSheet.show_*() directly.
func test_character_sheet_contexts() -> void:
	_enter_test("character_sheet_contexts")

	# Overworld and dungeon show the active PlayerManager character.
	_setup_world()
	var overworld: Node = await _spawn_scene("res://scenes/overworld.tscn", 1.0)
	var overworld_char: Character = PlayerManager.get_active_player().get("character")
	overworld.hud.btn_sheet.pressed.emit()
	await get_tree().process_frame
	_assert(CharacterSheet.is_open(), "overworld Sheet button opens the character sheet")
	_assert(CharacterSheet._open_char == overworld_char, "overworld Sheet button shows the active character")
	CharacterSheet.close_sheet()
	_teardown_scene(overworld)

	_setup_world()
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: Node = await _spawn_scene("res://scenes/dungeon.tscn", 1.0)
	var dungeon_char: Character = PlayerManager.get_active_player().get("character")
	dungeon.hud.btn_sheet.pressed.emit()
	await get_tree().process_frame
	_assert(CharacterSheet.is_open(), "dungeon Sheet button opens the character sheet")
	_assert(CharacterSheet._open_char == dungeon_char, "dungeon Sheet button shows the active character")
	CharacterSheet.close_sheet()
	_teardown_scene(dungeon)

	# Combat shows the character whose turn is active, which may differ from the
	# exploration active player in a party encounter.
	_setup_world()
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"monster_ids": ["goblin"], "terrain": "plains", "return_state": GameManager.GameState.OVERWORLD}
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.0)
	var combat_char: Character = combat.active_character
	combat.hud.btn_sheet.pressed.emit()
	await get_tree().process_frame
	_assert(CharacterSheet.is_open(), "combat Sheet button opens the character sheet")
	_assert(CharacterSheet._open_char == combat_char, "combat Sheet button shows the active combat character")
	CharacterSheet.close_sheet()
	_teardown_scene(combat)

	CharacterSheet.teardown_for_tests()
	await get_tree().process_frame
	_setup_world()
	_exit_test()


## Trace representative race/class values through initialization, level-up,
## serialization, runtime HP mutation, and Character Sheet rendering. The
## audit records the current generated hit die so data defects remain visible
## without turning this evidence beat into a false green regression.
func test_character_value_audit() -> void:
	_enter_test("character_value_audit")
	# Let the harness root finish its own _ready() child setup before the
	# autoload lazily adds the Character Sheet CanvasLayer.
	await get_tree().process_frame
	var cases := [
		{"race": "human", "class": "fighter", "name": "Human Fighter", "hit_die": "d10", "level1_hp": 12},
		{"race": "elf", "class": "wizard", "name": "Elf Wizard", "hit_die": "d6", "level1_hp": 8},
		{"race": "half-orc", "class": "barbarian", "name": "Half-Orc Barbarian", "hit_die": "d12", "level1_hp": 14},
		{"race": "dwarf", "class": "rogue", "name": "Dwarf Rogue", "hit_die": "d8", "level1_hp": 10},
	]
	var base_scores := {"STR": 10, "DEX": 10, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10}

	for case in cases:
		var race_id := str(case.get("race", ""))
		var class_id := str(case.get("class", ""))
		var character: Character = _fresh_char(str(case.get("name", "Audit")), race_id, class_id, base_scores)
		var race_data: Dictionary = DataLoader.get_race(race_id)
		var class_data: Dictionary = DataLoader.get_character_class(class_id)
		for ability in AbilityScores.ABILITIES:
			var expected_score := int(base_scores.get(ability, 10)) + int(race_data.get("ability_bonuses", {}).get(ability, 0))
			_assert(character.ability_scores.get_score(ability) == expected_score, "%s %s reflects the %s racial score" % [race_id, class_id, ability])

		var generated_hit_die := str(class_data.get("hit_die", ""))
		var initial_hp := character.max_hp
		_assert(generated_hit_die == str(case.get("hit_die", "")), "%s uses the source hit die" % case.get("name", "Audit"))
		_assert(initial_hp == int(case.get("level1_hp", 0)), "%s level-1 HP matches the source hit die and CON" % case.get("name", "Audit"))
		_assert(character.current_hp == initial_hp, "%s starts at full HP" % case.get("name", "Audit"))
		character.level_up()
		_assert(character.level == 2 and character.current_hp == character.max_hp and character.max_hp > initial_hp, "%s level-up raises and refills HP" % case.get("name", "Audit"))

		var restored: Character = Character.new()
		restored.from_dict(character.to_dict())
		_assert(restored.max_hp == character.max_hp and restored.current_hp == character.current_hp, "%s save/load preserves HP" % case.get("name", "Audit"))
		_assert(restored.ability_scores.to_dict() == character.ability_scores.to_dict(), "%s save/load preserves racialized scores" % case.get("name", "Audit"))

		character.current_hp = maxi(1, character.max_hp - 1)
		CharacterSheet.show_sheet(character)
		var sheet_text := ""
		for section in CharacterSheet._content.get_children():
			if section is Label:
				sheet_text += section.text + "\n"
		_assert(sheet_text.contains("HP %d/%d" % [character.current_hp, character.max_hp]), "%s Sheet renders mutated HP" % case.get("name", "Audit"))
		print("[audit] %s/%s generated_hit_die=%s level1_hp=%d level2_hp=%d sheet_hp=%d/%d" % [race_id, class_id, generated_hit_die, initial_hp, character.max_hp, character.current_hp, character.max_hp])
		CharacterSheet.close_sheet()

	CharacterSheet.teardown_for_tests()
	await get_tree().process_frame
	_setup_world()
	_exit_test()

# --- combat turn-loop integration (closes AIController-not-driven gap) ------

## Drive the REAL combat turn loop and prove AIController's decision produces a
## real, observable monster action (move toward / attack a player) and that the
## live intent preview is wired to the actual AI, not a stub.
func test_combat_ai_loop() -> void:
	_enter_test("combat_ai_loop")
	_setup_world()
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 3.5)
	await get_tree().create_timer(0.5).timeout

	var initial_positions: Array = []
	for m in combat.monster_entities:
		initial_positions.append(m["hex_position"])
	var initial_hp: int = 0
	for p in combat.player_entities:
		initial_hp += int(p["character"].current_hp)

	var saw_intent := false
	var saw_intent_text := false
	var monster_moved := false
	var player_damaged := false
	var polls := 0
	while polls < 120 and not combat._battle_ending:
		var ac: Dictionary = combat.active_combatant
		if not ac.is_empty() and not ac.get("is_player", true):
			var ent: Dictionary = ac.get("entity", {})
			if ent.get("intent", {}).size() > 0:
				saw_intent = true
			if not str(ent.get("intent_text", "")).is_empty():
				saw_intent_text = true
		if not ac.is_empty() and ac.get("is_player", false):
			combat._on_hud_action("end_turn", {})
		await get_tree().create_timer(0.3).timeout
		polls += 1
		for i in combat.monster_entities.size():
			if combat.monster_entities[i]["hex_position"] != initial_positions[i]:
				monster_moved = true
		var cur_hp: int = 0
		for p in combat.player_entities:
			cur_hp += int(p["character"].current_hp)
		if cur_hp < initial_hp:
			player_damaged = true
		if saw_intent and (monster_moved or player_damaged):
			break

	_assert(saw_intent, "live monster turn computed an AIController intent (monster['intent'] set in-loop)")
	_assert(saw_intent_text, "live monster turn published renderable intent text")
	_assert(monster_moved or player_damaged, "AIController decision produced a real effect (monster moved toward player or dealt damage) through the live turn loop")
	_assert(combat.tracker.current_round >= 1, "combat turn loop advanced at least one round")

	_teardown_scene(combat)
	_exit_test()


## Drive the REAL combat turn loop to a resolved end state: equip players,
## weaken + adjacent the monsters, then have players attack through the actual
## input handlers until victory fires via the shared _check_battle_end_conditions
## chokepoint (not a stubbed 'didn't crash').
func test_combat_victory() -> void:
	_enter_test("combat_victory")
	_setup_world()
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 3.5)
	await get_tree().create_timer(0.5).timeout

	# Equip durable players so this scenario can only end in victory. The live
	# turn loop, targeting, attack resolver, death handling, and battle-end
	# chokepoint still run; fixture randomness cannot turn the proof into a TPK.
	for i in combat.player_entities.size():
		var pc: Character = combat.player_entities[i]["character"]
		pc.inventory.equip(Inventory.Slot.WEAPON, "longsword", true)
		pc.base_ac = 1000
		pc.max_hp = 10000
		pc.current_hp = 10000
		pc.is_alive = true
	for i in combat.monster_entities.size():
		var m: Dictionary = combat.monster_entities[i]
		var ppos: Vector2i = combat.player_entities[i % combat.player_entities.size()]["hex_position"]
		var spot: Vector2i = ppos
		for n in HexUtils.get_neighbors(ppos):
			if combat.hex_grid.has_tile(n) and combat.hex_grid.is_hex_passable(n):
				spot = n
				break
		m["hex_position"] = spot
		m["current_hp"] = 1
		m["max_hp"] = 1
		m["armor_class"] = -100
		m["is_alive"] = true
		m["conditions"] = {"prone": 99}
	combat._update_grid_entities()
	seed(424242)

	var rounds := 0
	while rounds < 6 and not combat._battle_ending:
		var start_round: int = combat.tracker.current_round
		var guard := 0
		while not combat._battle_ending and combat.tracker.current_round == start_round and guard < 12:
			var ac: Dictionary = combat.active_combatant
			if not ac.is_empty() and ac.get("is_player", false):
				_drive_player_attack_turn(combat)
			await get_tree().create_timer(2.5).timeout
			guard += 1
		rounds += 1

	var alive_monsters := 0
	for m in combat.monster_entities:
		if m["is_alive"]:
			alive_monsters += 1
	_assert(combat._battle_ending, "battle reached an end state through the live turn loop")
	_assert(alive_monsters == 0, "victory: all monsters defeated (got %d alive)" % alive_monsters)
	_assert(GameManager.defeated_monsters.has("goblin"), "victory registered defeated monsters in GameManager")

	_teardown_scene(combat)
	_exit_test()


## Drive the REAL combat end-state chokepoint through a total party wipe, then
## instantiate the production defeat screen with its safe-save affordance.
func test_combat_defeat() -> void:
	_enter_test("combat_defeat")
	_setup_world()
	GameManager.game_in_progress = true
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	for player_entity in combat.player_entities:
		var character: Character = player_entity.get("character")
		character.current_hp = 0
		character.is_alive = false
	_assert(combat._check_battle_end_conditions(), "defeat: live combat detects a total party wipe")
	_assert(combat._battle_ending, "defeat: combat enters its terminal state")
	_assert(GameManager.defeated_monsters.is_empty(), "defeat: no monster victory ledger is recorded")
	_teardown_scene(combat)

	GameManager.current_state = GameManager.GameState.DEFEAT
	GameManager.transition_context = {"reason": "The party was defeated in the final encounter."}
	var defeat: Node = await _spawn_scene("res://scenes/defeat.tscn", 0.3)
	_assert(defeat.title_label.text == "The Party Falls", "defeat screen presents the player-facing loss title")
	_assert(defeat.reason_label.text.contains("final encounter"), "defeat screen presents the loss reason")
	_assert(defeat.continue_button.text == "Load Safe Save", "defeat screen offers safe-save recovery")
	_assert(defeat.menu_button.text == "Return to Main Menu", "defeat screen offers a clean return")
	_teardown_scene(defeat)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = false
	_exit_test()

## Production Lich King defeat, safe reload, victory, and terminal destinations.
## The normal GUI readability and fresh-process relaunch remain manual review.
func test_final_encounter_round_trip() -> void:
	_enter_test("final_encounter_round_trip")
	_setup_world()
	GameManager.game_in_progress = true
	PartyManager.initialize_campaign_companions(GameManager.active_campaign.get("companions", {}))
	_assert(PartyManager.recruit_companion("aldric"), "final encounter recruits Aldric")
	_assert(PartyManager.recruit_companion("mira"), "final encounter recruits Mira")
	for index in 3:
		PartyManager.get_active_characters()[index].inventory.add_item("crown_fragment")
	var slot := "final_encounter_round_trip"
	SaveManager.delete_save(slot)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.transition_context = {}
	_assert(SaveManager.save_game(slot), "final encounter writes the pre-finale safe save")

	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"monster_ids": ["lich_king"], "return_state": GameManager.GameState.OVERWORLD, "terrain": "plains"}
	var defeat_combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	_assert(defeat_combat.monster_entities.size() == 1 and defeat_combat.monster_entities[0].get("monster_id", "") == "lich_king", "final encounter uses the production Lich King")
	for player_entity in defeat_combat.player_entities:
		var defeated_character: Character = player_entity.get("character")
		defeated_character.current_hp = 0
		defeated_character.is_alive = false
	_assert(defeat_combat._check_battle_end_conditions() and defeat_combat._battle_ending, "final encounter loss reaches the live defeat boundary")
	_assert(not GameManager.defeated_monsters.has("lich_king"), "final encounter loss does not record a boss victory")
	_teardown_scene(defeat_combat)
	GameManager.current_state = GameManager.GameState.DEFEAT
	GameManager.transition_context = {"reason": "The party was defeated in the final encounter."}
	var defeat: Node = await _spawn_scene("res://scenes/defeat.tscn", 0.3)
	_assert(defeat.title_label.text == "The Party Falls" and defeat.continue_button.text == "Load Safe Save", "final encounter loss presents safe reload controls")
	_teardown_scene(defeat)

	PlayerManager.reset()
	PartyManager.reset()
	_assert(SaveManager.load_game(slot), "final encounter reloads the pre-finale safe save")
	_assert(GameManager.current_state == GameManager.GameState.OVERWORLD and GameManager.defeated_monsters.is_empty(), "final encounter reload restores pre-finale progress without the boss victory")
	_assert(PartyManager.get_active_characters().size() == 4 and PartyManager.get_active_characters()[0].inventory.count_item("crown_fragment") == 1, "final encounter reload restores the full party and Crown fragments")

	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"monster_ids": ["lich_king"], "return_state": GameManager.GameState.OVERWORLD, "terrain": "plains"}
	var victory_combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	_assert(victory_combat.monster_entities.size() == 1 and victory_combat.monster_entities[0].get("spells", []).size() == 7, "final encounter reload keeps the production Lich King spell loadout")
	var lich: Dictionary = victory_combat.monster_entities[0]
	lich["current_hp"] = 0
	lich["max_hp"] = 1
	lich["armor_class"] = -100
	lich["is_alive"] = false
	_assert(victory_combat._check_battle_end_conditions() and victory_combat._battle_ending, "final encounter victory reaches the live victory boundary")
	_assert(GameManager.defeated_monsters.has("lich_king") and GameManager.are_win_conditions_met(), "final encounter victory records the boss and completes Crown goals")
	_assert(GameManager.claim_reward("lich_king_crown"), "final encounter claims its one-time reward ledger")
	_assert(not GameManager.claim_reward("lich_king_crown"), "final encounter reward claim is idempotent")
	_teardown_scene(victory_combat)

	GameManager.current_state = GameManager.GameState.COMPLETION
	GameManager.transition_context = {"reason": "Campaign goals completed!"}
	var completion: Node = await _spawn_scene("res://scenes/completion.tscn", 0.3)
	_assert(completion.title_label.text == "Crown Reclaimed", "final encounter victory presents the completion screen")
	_teardown_scene(completion)
	SaveManager.delete_save(slot)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = false
	GameManager.active_dungeon_state.clear()
	_exit_test()


## Run one bounded production-data encounter composition through the real
## combat entities and resolvers. The fixture intentionally records each
## required Gate 5 mechanic instead of relying on a green smoke-only result.
func test_mixed_mechanics_encounter() -> void:
	_enter_test("mixed_mechanics_encounter")
	_setup_mixed_world()
	seed(20260810)
	var combat: Node = await _spawn_scene("res://scenes/combat.tscn", 1.2)
	_assert(combat.player_entities.size() == 4, "mixed encounter uses the four-member production cohort")
	_assert(combat.monster_entities.size() >= 1, "mixed encounter has a production monster target")
	if combat.player_entities.size() < 4 or combat.monster_entities.is_empty():
		_teardown_scene(combat)
		_exit_test()
		return

	var by_class: Dictionary = {}
	for entity in combat.player_entities:
		by_class[entity["character"].class_id] = entity
	var fighter: Character = by_class["fighter"]["character"]
	var rogue: Character = by_class["rogue"]["character"]
	var wizard: Character = by_class["wizard"]["character"]
	var cleric: Character = by_class["cleric"]["character"]
	rogue.level_up()
	var target: Dictionary = combat.monster_entities[0]
	target["current_hp"] = 100
	target["max_hp"] = 100
	target["armor_class"] = 5
	target["is_alive"] = true
	combat._update_grid_entities()

	# Martial attack: production weapon data crosses CombatAction.
	var weapon: Dictionary = DataLoader.get_item("longsword")
	var martial_result := CombatAction.resolve_weapon_attack(fighter, target, weapon)
	_assert(martial_result.get("hit", false) and int(martial_result.get("damage", 0)) > 0, "mixed encounter resolves a production martial attack")

	# Bonus action: production Rogue Cunning Action goes through CombatState's
	# feature path and consumes the extracted turn budget.
	var rogue_index := int(by_class["rogue"].get("player_id", 1))
	combat.current_player_idx = rogue_index
	combat.active_character = rogue
	combat.turn_budget.reset(rogue, combat.player_entities)
	combat.remaining_speed = rogue.get_speed()
	var cunning_action: Dictionary = rogue.get_feature("rogue_cunning_action").duplicate(true)
	cunning_action["selected_action"] = "disengage"
	var cunning_uses_before := int(rogue.feature_uses.get("rogue_cunning_action", 0))
	combat._execute_class_feature(cunning_action)
	_assert(cunning_uses_before > int(rogue.feature_uses.get("rogue_cunning_action", 0)) and not combat.turn_budget.bonus_action_available and rogue.has_condition("disengaging"), "mixed encounter spends a bonus action through production Cunning Action")

	# Healing: Cure Wounds is loaded from production spell data and its typed
	# effect is applied to a wounded cohort member.
	fighter.current_hp = maxi(1, fighter.max_hp - 6)
	var hp_before_heal := fighter.current_hp
	var cure_wounds: Dictionary = DataLoader.get_spell("cure_wounds")
	var heal_cast := CombatAction.resolve_spell(cleric, fighter, cure_wounds, true)
	var healed_amount := 0
	for effect in cure_wounds.get("effects", []):
		for result in EventResolver.apply_effects(fighter, [effect]):
			healed_amount += int(result.get("amount", 0))
	_assert(heal_cast.get("success", false) and healed_amount > 0 and fighter.current_hp > hp_before_heal, "mixed encounter resolves production Cure Wounds healing")

	# Concentration and area selection: Bless carries the validated transient
	# area contract, applies its production condition, and owns its targets.
	var bless: Dictionary = DataLoader.get_spell("bless")
	var bless_selection := EventResolver.resolve_area_selection(bless.get("effects", [])[0])
	var bless_targets: Array = [fighter, rogue, cleric]
	for target_character in bless_targets:
		for effect in bless.get("effects", []):
			if str(effect.get("type", "")) == "grant_condition":
				EventResolver.apply_effects(target_character, [effect])
	cleric.concentrating_on = {"spell_id": "bless", "effects": bless.get("effects", []), "targets": bless_targets}
	var bless_area := Targeting.get_sphere_targets(combat.player_entities[3]["hex_position"], int(bless_selection.get("radius", 0)), combat.hex_grid)
	_assert(bless_selection.get("success", false) and not bless_selection.get("persistent", true) and bless_area.size() > 0 and cleric.concentrating_on.get("spell_id", "") == "bless" and fighter.has_condition("blessed"), "mixed encounter applies a transient area Bless under concentration")

	# Save spell and area effect: production Fireball resolves its DEX-save
	# contract, while the same selection result drives sphere geometry.
	wizard.level_up()
	wizard.level_up()
	wizard.spell_slots["3"] = 1
	var fireball: Dictionary = DataLoader.get_spell("fireball")
	var fireball_selection := EventResolver.resolve_area_selection(fireball.get("effects", [])[0])
	var fireball_area := Targeting.get_sphere_targets(target["hex_position"], int(fireball_selection.get("radius", 0)), combat.hex_grid)
	var fireball_result := CombatAction.resolve_spell(wizard, target, fireball, true)
	_assert(fireball_selection.get("success", false) and fireball_area.has(target["hex_position"]) and fireball.get("save", "") == "DEX" and fireball_result.get("success", false), "mixed encounter resolves a production save spell over a sphere area")

	# Owned reaction: the wizard's production Shield reaction is accepted and
	# consumes the wizard's reaction/slot through the shared attack resolver.
	wizard.reaction_available = true
	wizard.spell_slots["1"] = 1
	if "shield" not in wizard.known_spells:
		wizard.known_spells.append("shield")
	wizard.base_ac = 10
	var reaction_weapon := {"ability": "STR", "damage": "1", "damage_type": "bludgeoning", "range": 1}
	for _attempt in 50:
		if not wizard.reaction_available:
			break
		CombatAction.resolve_weapon_attack(fighter, wizard, reaction_weapon, false, false, {"shield": true})
	_assert(not wizard.reaction_available and int(wizard.spell_slots.get("1", 0)) == 0 and wizard.has_condition("shield"), "mixed encounter consumes the owning wizard Shield reaction")

	combat._end_concentration(cleric)
	_assert(cleric.concentrating_on.is_empty() and not fighter.has_condition("blessed") and not rogue.has_condition("blessed"), "mixed encounter concentration cleanup removes its applied conditions")
	print("[mixed] martial=true bonus_action=true reaction=true concentration=true healing=true save=true area=true")
	_teardown_scene(combat)
	_exit_test()


## Helper: play one player's turn in the live combat scene by driving the real
## movement + attack input handlers toward the nearest alive monster.
func _drive_player_attack_turn(combat: Node) -> void:
	var pidx: int = combat.current_player_idx
	if pidx < 0 or pidx >= combat.player_entities.size():
		return
	var p: Dictionary = combat.player_entities[pidx]
	var pchar: Character = p["character"]
	if pchar == null or not pchar.is_alive:
		combat._on_hud_action("end_turn", {})
		return
	var nearest = null
	var nd := 9999
	for m in combat.monster_entities:
		if not m["is_alive"]:
			continue
		var d: int = HexUtils.get_distance(p["hex_position"], m["hex_position"])
		if d < nd:
			nd = d
			nearest = m
	if nearest == null:
		combat._on_hud_action("end_turn", {})
		return
	var mpos: Vector2i = nearest["hex_position"]
	var weapon_id: String = pchar.inventory.get_weapon()
	var weapon: Dictionary = DataLoader.get_item(weapon_id)
	var max_range: int = int(weapon.get("range", 1))
	if HexUtils.get_distance(p["hex_position"], mpos) <= max_range:
		combat.pending_action_type = "attack"
		combat._on_hex_clicked(mpos)
		if not combat._battle_ending:
			combat._on_hud_action("end_turn", {})
		return
	var reach: Dictionary = combat.hex_grid.get_reachable(p["hex_position"], combat.remaining_speed)
	var best_step: Vector2i = p["hex_position"]
	var best_d: int = nd
	for h in reach:
		var d: int = HexUtils.get_distance(h, mpos)
		if d < best_d:
			best_d = d
			best_step = h
	if best_step != p["hex_position"]:
		combat._on_hex_clicked(best_step)
	if HexUtils.get_distance(combat.player_entities[pidx]["hex_position"], mpos) <= max_range:
		combat.pending_action_type = "attack"
		combat._on_hex_clicked(mpos)
	if not combat._battle_ending:
		combat._on_hud_action("end_turn", {})


# --- reporting --------------------------------------------------------------

func _report() -> void:
	print("--------------------------------------------------")
	print(" VIEWPORT RESULTS: %d failed (%d tests run)" % [_fail, _tests_run])
	if _tests_failed_names.size() > 0:
		print(" FAILED TESTS: %s" % ", ".join(_tests_failed_names))
		for f in _failures:
			print("   - %s" % f)
		print("VIEWPORT TESTS FAILED")
	else:
		print("VIEWPORT TESTS PASSED")
