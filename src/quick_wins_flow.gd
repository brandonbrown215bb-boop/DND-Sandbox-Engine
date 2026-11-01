class_name QuickWinsFlow
extends RefCounted

const SLOT := "quick_wins"
const PLAYER_SLOT := "quick_wins_players"

static func run(h: Node) -> void:
	h._enter_test("quick_wins_flow")
	h._setup_world()
	QuickWinsChecks.load_fixtures()
	var c := await creation(h)
	if c == null: h._exit_test(); return
	await combat_controls(h, c)
	await room_controls(h, c)
	# An ordinary damage-only cast retains 50 of its 60-point budget.
	var spell := DataLoader.get_spell("fixture:budget_light")
	var victim := QuickWinsChecks.target()
	var result := CombatAction.resolve_spell(c, victim, spell)
	var source := str(result.get("effect_cast", {}).get("source_id", ""))
	var continued := spell.duplicate(true)
	continued["_effect_cast"] = result.get("effect_cast", {})
	CombatAction.resolve_spell(c, victim, continued)
	victim["damage_resistances"] = ["radiant"]
	CombatAction.resolve_spell(c, victim, continued)
	h._assert(c.spell_effects.get(source, {}).get("damage_budget_total", 0) == 50, "S272 actual cast and resisted continuation retain 50 damage")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = true
	h._assert(SaveManager.save_game(SLOT), "Quick wins allowed full-party checkpoint saves generation, parameterized feats, equipment, campaign time and damage budget")
	var dto := SaveManager._read_save(SLOT)
	if dto.is_empty(): h._exit_test(); return
	var players := dto.duplicate(true)
	players.erase("party")
	h._assert(SaveManager._validate_save_data(players).is_empty(), "Quick wins player-only checkpoint passes the same preflight")
	var file := FileAccess.open(SaveManager.SAVE_DIR + PLAYER_SLOT + ".sav", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(players)); file.close()
	h._assert(file != null, "Quick wins player-only checkpoint written for fresh-process recovery")
	var campaign := DataLoader.get_campaign(str(dto.campaign_id))
	var old_methods: Variant = campaign.get("ability_generation_methods")
	campaign["ability_generation_methods"] = ["point_buy"]
	var party_only_receipts := dto.duplicate(true)
	for player in party_only_receipts.players: player.character.creation_choices.erase("ability_generation")
	h._assert(SaveManager._validate_save_data(players).contains("method is not allowed") and SaveManager._validate_save_data(party_only_receipts).contains("method is not allowed"), "S242 campaign restrictions validate both player receipts and party-only receipts")
	if old_methods == null: campaign.erase("ability_generation_methods")
	else: campaign["ability_generation_methods"] = old_methods
	for defect in ["generation", "repeat", "budget"]:
		for players_only in [false, true]:
			var bad := (players if players_only else dto).duplicate(true)
			var actor: Dictionary = bad.players[0].character if players_only else bad.party.characters[c.character_id]
			if defect == "generation": actor.creation_choices.ability_generation.results[0] += 1
			elif defect == "repeat":
				for key in actor.feature_choices:
					if actor.feature_choices[key] == ["feat:fixture:distinct_origin|divine"]: actor.feature_choices[key] = ["feat:fixture:distinct_origin|arcane"]
			else: actor.spell_effects[source].damage_budget_total = 60
			h._assert(not SaveManager._validate_save_data(bad).is_empty() and PlayerManager.get_player(0).get("character") == c, "Quick wins malformed %s refuses %s checkpoint before session mutation" % [defect, "players" if players_only else "party"])
	h._exit_test()

static func creation(h: Node) -> Character:
	PlayerManager.reset()
	PartyManager.reset()
	PlayerManager.add_player("Quick owner")
	PlayerManager.add_player("Next seat")
	GameManager.current_state = GameManager.GameState.CHARACTER_CREATION
	var screen: Node = await h._spawn_scene("res://scenes/ui/character_creation.tscn", 0.1)
	screen.selected_race_id = "human"
	screen.selected_class_id = "fighter"
	screen.current_step = screen.CreationStep.STATS
	screen._update_step_ui()
	screen._random_method_button.pressed.emit()
	h._assert(screen._ability_generation_results.size() == 6 and not screen.btn_next.disabled and screen._ability_choice_error().is_empty(), "S242 actual Roll button records and assigns six seeded scores")
	var campaign := GameManager.active_campaign
	var original_methods: Variant = campaign.get("ability_generation_methods")
	GameManager.active_campaign["ability_generation_methods"] = ["standard_array"]
	screen._refresh_stats_ui()
	h._assert(screen._random_method_button.disabled and screen._point_buy_method_button.disabled and screen.btn_next.disabled, "S242 campaign restriction disables prohibited controls and blocks an existing prohibited selection")
	screen._standard_method_button.pressed.emit()
	var controls: Array = screen._generation_assignment_controls
	controls[0].select(5); controls[0].item_selected.emit(5)
	screen._refresh_stats_ui()
	h._assert(screen.btn_next.disabled, "S242 duplicate assignment stays invalid across refresh")
	controls[5].select(0); controls[5].item_selected.emit(0)
	h._assert(not screen.btn_next.disabled and screen.selected_stats.get_score("CHA") == 15 and screen.selected_stats.get_score("STR") == 8, "S242 actual assignment controls swap two generated results")
	if original_methods == null: campaign.erase("ability_generation_methods")
	else: campaign["ability_generation_methods"] = original_methods
	GameManager.active_campaign = campaign
	screen.current_step = screen.CreationStep.EQUIPMENT
	screen._update_step_ui()
	var picker: OptionButton = screen.equip_list.get_node_or_null("OriginFeatPicker")
	var origin_selected := false
	if picker != null:
		for index in picker.item_count:
			if str(picker.get_item_metadata(index)) == "fixture:distinct_origin|arcane": picker.select(index); picker.item_selected.emit(index); origin_selected = true; break
	h._assert(origin_selected, "S233 actual Origin picker exposes distinct parameter labels")
	screen.current_step = screen.CreationStep.SUMMARY
	screen._update_step_ui()
	screen.btn_next.pressed.emit()
	var c: Character = PlayerManager.get_player(0).get("character")
	h._assert(c != null and c.origin_feat == "fixture:distinct_origin|arcane" and c.creation_choices.get("ability_generation", {}).get("method", "") == "standard_array", "S242/S233 actual Confirm records assigned generation and parameterized Origin")
	h._assert(screen.current_player_idx == 1 and screen._ability_generation_method == "point_buy" and screen._ability_generation_results.is_empty() and screen.selected_origin_feat.is_empty(), "S242 next player starts with fresh generation and feat state")
	h._teardown_scene(screen)
	if c == null: return null
	# Give the second seat an ordinary actor so both checkpoint routes are real.
	var rolled := AbilityScores.roll_generation(123456)
	var scores := AbilityScores.new()
	scores.from_dict(AbilityScores.assign_generation(rolled, AbilityScores.ABILITIES).scores)
	var ally := Character.new()
	ally.initialize("Rolled Ally", "human", "fighter", scores)
	ally.creation_choices["ability_generation"] = {"method":"random_4d6", "seed":123456, "results":rolled, "assigned_abilities":AbilityScores.ABILITIES.duplicate()}
	PlayerManager.set_player_character(1, ally)
	PartyManager.register_player_character(1, ally)
	while c.level < 4: c.level_up()
	GameManager.current_state = GameManager.GameState.OVERWORLD
	CharacterSheet.show_sheet(c)
	await h.get_tree().process_frame
	var level_picker: OptionButton = CharacterSheet._content.find_child("LevelFeatPicker", true, false)
	var take: Button = CharacterSheet._content.find_child("LevelFeatTake", true, false)
	var took := false
	if level_picker != null and take != null:
		for index in level_picker.item_count:
			if str(level_picker.get_item_metadata(index)) == "fixture:distinct_origin|divine": level_picker.select(index); take.pressed.emit(); took = true; break
	h._assert(took and ClassProgression.pending_improvements(c).is_empty(), "S233 actual level-up control takes a different parameter")
	CharacterSheet.close_sheet()
	return c

static func combat_controls(h: Node, c: Character) -> void:
	c.inventory.add_item("fixture:banded_bow")
	c.inventory.equip(Inventory.Slot.WEAPON, "fixture:banded_bow")
	c.ability_scores.dexterity = 13
	GameManager.transition_context = {"terrain":"plains", "monster_ids":["goblin"]}
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.5)
	h._p_focus(combat, c)
	combat._reset_turn_action_economy()
	combat.player_entities[0].hex_position = Vector2i.ZERO
	var enemy: Dictionary = combat.monster_entities[0]
	enemy.hex_position = Vector2i(6, 0)
	enemy.armor_class = -100
	enemy.current_hp = 200; enemy.max_hp = 200
	combat._update_grid_entities()
	combat.hud.btn_attack.pressed.emit()
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(not combat._can_spend_action_cost("action") and enemy.current_hp < 200, "S250 actual Attack targeting accepts a long-range target despite legacy range 1")
	combat._reset_turn_action_economy()
	enemy.hex_position = Vector2i(13, 0)
	combat._update_grid_entities()
	var hp := int(enemy.current_hp)
	combat.hud.btn_attack.pressed.emit()
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(combat._can_spend_action_cost("action") and enemy.current_hp == hp, "S250 actual beyond-maximum click spends neither Action nor damage")
	await combat._on_hud_action("cancel", {})
	# Fighter starts with a Shield; don/doff uses the actual equipment button.
	if c.inventory.get_equipped(Inventory.Slot.SHIELD).is_empty(): c.inventory.add_item("shield")
	combat._reset_turn_action_economy()
	var before := c.inventory.get_equipped(Inventory.Slot.SHIELD)
	combat.hud.shield_equipment_button.pressed.emit()
	var after := c.inventory.get_equipped(Inventory.Slot.SHIELD)
	combat.hud.shield_equipment_button.pressed.emit()
	h._assert(before != after and c.inventory.get_equipped(Inventory.Slot.SHIELD) == after and not combat._can_spend_action_cost("action"), "S252 actual Shield button spends one Action and repeated click cannot reverse it")
	for id in ["chain_mail", "scale_mail"]:
		c.inventory.add_item(id)
		var copy := c.inventory.backpack_instances().filter(func(r): return r.definition_id == id)
		if not copy.is_empty():
			var refused := c.inventory.equipment_control_equip(Inventory.Slot.BODY, str(copy[0].instance_id), combat)
			h._assert(not refused.success and refused.seconds == 0, "S252 combat refuses donning " + id)
	h._teardown_scene(combat)
	await h.get_tree().process_frame

static func room_controls(h: Node, c: Character) -> void:
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id":"ruins_of_ashvale"}
	GameManager.active_dungeon_state.clear()
	ContainmentFlow.fixtures() # Reuse an authored entrance room for ordinary equipment controls.
	GameManager.active_campaign = DataLoader.get_campaign(str(GameManager.active_campaign.id))
	var dungeon: DungeonState = await h._spawn_scene("res://scenes/dungeon.tscn", 0.2)
	dungeon._enter_local_room("0")
	await h.get_tree().process_frame
	var view := dungeon.local_view
	if view == null: h._assert(false, "S252 ordinary local room equipment is available"); h._teardown_scene(dungeon); return
	view.slots.select(Inventory.Slot.BODY)
	var old := c.inventory.get_equipped(Inventory.Slot.BODY)
	var expected := Inventory.armor_change_seconds(DataLoader.get_item(old), false)
	var time := int(GameManager.campaign_elapsed_seconds)
	h._assert(TetherGroupFlow.press(view, "Unequip"), "S252 actual room Unequip exists")
	h._assert(c.inventory.get_equipped(Inventory.Slot.BODY).is_empty() and int(GameManager.campaign_elapsed_seconds) == time + expected, "S252 actual room doff charges its armor table time")
	view.slots.select(Inventory.Slot.BODY)
	var selected := false
	for index in view.items.item_count:
		var id := str(view.items.get_item_metadata(index))
		if str(c.inventory.get_instance(id).get("definition_id", "")) == "chain_mail": view.items.select(index); selected = true; break
	time = int(GameManager.campaign_elapsed_seconds)
	h._assert(selected and TetherGroupFlow.press(view, "Equip"), "S252 actual room selects an exact Heavy Armor copy")
	h._assert(c.inventory.get_equipped(Inventory.Slot.BODY) == "chain_mail" and int(GameManager.campaign_elapsed_seconds) == time + 600 and "600 seconds" in view.hud.log_text.text, "S252 actual Heavy donning advances ten minutes and reports elapsed time")
	h._teardown_scene(dungeon)
	await h.get_tree().process_frame

static func run_reload(h: Node) -> void:
	h._enter_test("quick_wins_reload")
	QuickWinsChecks.load_fixtures()
	for slot in [SLOT, PLAYER_SLOT]:
		h._assert(SaveManager.load_game(slot), "Quick wins fresh-process load: " + slot)
		var c: Character = PlayerManager.get_player(0).get("character")
		if c == null: continue
		var receipt: Dictionary = c.creation_choices.get("ability_generation", {})
		var ally: Character = PlayerManager.get_player(1).get("character")
		h._assert(ally != null and ally.creation_choices.get("ability_generation", {}).get("method", "") == "random_4d6" and ally.creation_choices.ability_generation.seed == 123456 and AbilityScores.saved_generation_error(ally.to_dict()).is_empty(), "S242 fresh process retains seeded random generation without rerolling")
		h._assert(receipt.get("method", "") == "standard_array" and AbilityScores.saved_generation_error(c.to_dict()).is_empty() and receipt.get("assigned_abilities", []) == ["CHA","DEX","CON","INT","WIS","STR"] and c.origin_feat == "fixture:distinct_origin|arcane" and "fixture:distinct_origin|arcane" not in FeatRules.options(c, "") and "fixture:distinct_origin|divine" not in FeatRules.options(c, ""), "S242/S233 fresh-process checkpoint retains assigned rolls and both distinct parameters")
		h._assert(c.inventory.get_equipped(Inventory.Slot.BODY) == "chain_mail", "S252 fresh-process checkpoint retains completed armor change")
		var source := ""
		for id in c.spell_effects:
			if c.spell_effects[id].get("spell_id", "") == "fixture:budget_light": source = str(id); break
		h._assert(not source.is_empty() and c.spell_effects.get(source, {}).get("damage_budget_total", 0) == 50, "S272 fresh-process checkpoint retains the exact partial counter")
		if source.is_empty(): continue
		var spell := DataLoader.get_spell("fixture:budget_light").duplicate(true)
		spell["_effect_cast"] = c.spell_effects[source]
		var victim := QuickWinsChecks.target()
		var last := CombatAction.resolve_spell(c, victim, spell)
		h._assert(last.get("damage", 0) == 20 and victim.current_hp == 180 and not c.spell_effects.has(source), "S272 recovered 50/60 source deals its full final 20 and ends at 70")
	h._exit_test()
