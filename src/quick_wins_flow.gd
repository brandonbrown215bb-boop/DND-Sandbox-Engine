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
	for defect in ["generation", "repeat", "budget", "base_ac"]:
		for players_only in [false, true]:
			var bad := (players if players_only else dto).duplicate(true)
			var actor: Dictionary = bad.players[0].character if players_only else bad.party.characters[c.character_id]
			if defect == "generation": actor.creation_choices.ability_generation.results[0] += 1
			elif defect == "repeat":
				for key in actor.feature_choices:
					if actor.feature_choices[key] == ["feat:fixture:distinct_origin|divine"]: actor.feature_choices[key] = ["feat:fixture:distinct_origin|arcane"]
			elif defect == "budget": actor.spell_effects[source].damage_budget_total = 60
			else: actor["base_ac_choice"] = JSON.stringify(["protection", "forged:protection:999"])
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
	# Use the actual attack control at normal range so the armor is the only
	# source of Disadvantage, then restore training for the other scenarios.
	if c.inventory.get_armor() != "fixture:renamed_plate": c.inventory.equip(Inventory.Slot.BODY, "fixture:renamed_plate", true)
	var strength_before := c.ability_scores.strength
	c.ability_scores.strength = 12
	var below_threshold := c.armor_speed_penalty() == 2
	c.ability_scores.strength = 13
	h._assert(below_threshold and c.armor_speed_penalty() == 0, "CXM-07 renamed worn armor applies its Strength threshold inclusively")
	c.ability_scores.strength = strength_before
	var old_training := c.armor_proficiencies.duplicate()
	var wand := Batch041Checks.add_copy(c, "wand_of_magic_missiles")
	var wand_equipped := c.inventory.equip_instance(Inventory.Slot.HANDS, wand)
	var charges_before := int(c.inventory.get_instance(wand).get("state", {}).get("charges", 0))
	var pending_command := CombatCommand.from_hud_for_character("activate_magic_item", {"instance_id":wand, "charges":1}, c)
	c.armor_proficiencies.erase("heavy")
	var saved_features := c.features.duplicate(true)
	var saved_known := c.known_spells.duplicate()
	var saved_slots := c.spell_slots.duplicate(true)
	SpellPermissionChecks.grant_slot_permission(c, ["magic_missile"])
	c.spell_slots["1"] = 1
	var ordinary_cast_choices := SpellPermissionRules.payment_choices(c, "magic_missile")
	if not ordinary_cast_choices.is_empty():
		await combat._on_hud_action("cast_spell", {"spell": ordinary_cast_choices[0]})
	h._assert(not ordinary_cast_choices.is_empty() and int(c.spell_slots.get("1", 0)) == 1 and combat._can_spend_action_cost("action") and combat.pending_action_type.is_empty(), "CXM-07 actual ordinary spell control refuses untrained armor before slot or Action")
	c.features.assign(saved_features)
	c.known_spells.assign(saved_known)
	c.spell_slots = saved_slots
	await combat._on_hud_action("activate_magic_item", {"instance_id": wand, "charges": 1})
	h._assert(wand_equipped and charges_before > 0 and int(c.inventory.get_instance(wand).get("state", {}).get("charges", 0)) == charges_before and combat._can_spend_action_cost("action") and combat.pending_action_type.is_empty(), "CXM-07 actual magic-item spell control refuses untrained armor before charge or Action")
	if pending_command != null:
		var no_coords: Array[Vector2i] = []
		var no_targets: Array[String] = []
		var stale_cast: SpellCastContext = combat._spell_cast_context(Vector2i.ZERO, Vector2i(9999, 9999), no_coords, no_targets, c, pending_command.payload.spell)
		stale_cast.spell["_metamagic_subtle"] = true
		c.feature_uses["sorcery_points"] = 3
		var before_uses := c.feature_uses.duplicate(true)
		var metamagic_paid := SpellCastResources.commit_metamagic(stale_cast)
		stale_cast.spell = pending_command.payload.spell.duplicate(true)
		var spell_paid := SpellCastResources.commit_spell_resource(stale_cast)
		h._assert(not metamagic_paid and not spell_paid and c.feature_uses == before_uses and int(c.inventory.get_instance(wand).get("state", {}).get("charges", 0)) == charges_before and combat._can_spend_action_cost("action"), "CXM-07 stale spell choice refuses before metamagic, item charge or Action payment")
		c.feature_uses.erase("sorcery_points")
	else:
		h._assert(false, "CXM-07 captured item cast remains available for stale preflight")
	c.inventory.unequip(Inventory.Slot.HANDS)
	enemy.hex_position = Vector2i(3, 0)
	combat._update_grid_entities()
	var records_before := ActivityHistory.get_records().size()
	combat.hud.btn_attack.pressed.emit()
	await combat._on_hex_clicked(enemy.hex_position)
	var records := ActivityHistory.get_records()
	var last_attack: Dictionary = records.back() if records.size() > records_before else {}
	h._assert(last_attack.get("kind", "") == "attack" and last_attack.get("payload", {}).get("disadvantage", false), "CXM-07 actual Attack control rolls with renamed untrained armor Disadvantage")
	c.armor_proficiencies.assign(old_training)
	combat._reset_turn_action_economy()
	enemy.hex_position = Vector2i(6, 0)
	combat._update_grid_entities()
	combat.hud.btn_attack.pressed.emit()
	var log_before: int = combat.hud.log_text.text.length()
	var hp_before_long_attack := int(enemy.current_hp)
	await combat._on_hex_clicked(enemy.hex_position)
	# Acceptance and hit are separate facts. 30 ft is past the bow's 20 ft
	# normal range, so the roll has Disadvantage and a natural 1 on the kept
	# die misses even AC -100 (~10% of runs). Acceptance must not depend on it.
	var attack_log: String = combat.hud.log_text.text.substr(log_before)
	var hit := attack_log.contains("Hit!")
	h._assert(not combat._can_spend_action_cost("action") and not attack_log.contains("out of range") and (hit or attack_log.contains("Miss!")), "S250 actual Attack targeting accepts a long-range target despite legacy range 1")
	h._assert((enemy.current_hp < hp_before_long_attack) == hit, "S250 accepted long-range attack deals damage exactly when it hits")
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
	combat._reset_turn_action_economy()
	combat.remaining_speed = float(c.get_speed())
	var before_move: float = combat.remaining_speed
	var destination := Vector2i(9999, 9999)
	var origin: Vector2i = combat.player_entities[combat.current_player_idx].hex_position
	for coord in combat._player_reachable(origin, combat.remaining_speed, c):
		if HexUtils.get_distance(origin, coord) == 1:
			destination = coord
			break
	if destination != Vector2i(9999, 9999): await combat._on_hex_clicked(destination)
	var spent: float = before_move - combat.remaining_speed
	var doffed := c.inventory.equipment_control_unequip(Inventory.Slot.BODY, combat)
	combat._sync_changed_movement_speed()
	h._assert(spent > 0 and doffed.success and is_equal_approx(combat.remaining_speed, float(c.get_speed()) - spent), "CXM-07 removing heavy armor refreshes Speed without refunding movement already spent")
	h._teardown_scene(combat)
	await h.get_tree().process_frame
	c.inventory.equip(Inventory.Slot.BODY, "chain_mail")

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
	h._assert(c.armor_speed_penalty() == 2 and EventResolver.ability_check_roll_mode(c, "DEX", "Stealth", {}).disadvantage, "CXM-07 the actual donned chain applies its Strength and Stealth penalties")
	var saved_training := c.armor_proficiencies.duplicate()
	c.armor_proficiencies.erase("heavy")
	h._assert(c.untrained_worn_armor() and CombatAction.save_has_disadvantage(c, "STR") and CombatAction.attacker_has_condition_disadvantage(c, "DEX"), "CXM-07 the actual worn copy imposes untrained STR/DEX penalties")
	c.armor_proficiencies.assign(saved_training)
	# The second player chooses a lower legal base through the actual room menu;
	# the first player's completed armor change remains in the same checkpoints.
	var ally: Character = PlayerManager.get_player(1).get("character")
	var ally_index := view.characters.find(ally)
	if ally_index >= 0:
		view.actors.select(ally_index)
		view.actors.item_selected.emit(ally_index)
		view.slots.select(Inventory.Slot.BODY)
		if not ally.inventory.get_armor().is_empty(): TetherGroupFlow.press(view, "Unequip")
		var cast := CombatAction.resolve_spell(ally, ally, DataLoader.get_spell("mage_armor"), false, {}, [], 1, 0)
		if cast.get("success", false): SpellEffects.grant(ally, cast.get("effect_cast", {}), "mage_armor", "start")
		LocalRoomModes.refresh(view)
		var offer_index := -1
		for index in view.mode_offers.item_count:
			if view.mode_offers.get_item_metadata(index).get("feature_id", "") == ModeControls.BASE_AC_CONTROL: offer_index = index; break
		var chosen := false
		if offer_index >= 0:
			view.mode_offers.select(offer_index)
			var offer: Dictionary = view.mode_offers.get_item_metadata(offer_index)
			var options := ModeControls.options(ModeControls.row(ally, ModeControls.BASE_AC_CONTROL), "base_ac")
			var ordinary := JSON.stringify(["unarmored"])
			var popup := LocalRoomModes.open(view)
			if popup != null and ordinary in options:
				popup.id_pressed.emit(options.find(ordinary) + 1)
				chosen = ally.base_ac_choice == ordinary
		h._assert(cast.get("success", false) and chosen and ally.get_ac() == 10 + ally.ability_scores.get_ability_modifier("DEX") + ally.trained_shield_bonus(), "CXM-07 actual room menu selects ordinary AC over Mage Armor: cast=%s chosen=%s offer=%d ac=%d expected=%d armor=%s" % [str(cast), str(chosen), offer_index, ally.get_ac(), 10 + ally.ability_scores.get_ability_modifier("DEX") + ally.trained_shield_bonus(), ally.inventory.get_armor()])
	else:
		h._assert(false, "CXM-07 second player is available in the room")
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
		if ally != null:
			h._assert(ally.base_ac_choice == JSON.stringify(["unarmored"]) and ally.has_condition("mage_armor") and ally.get_ac() == 10 + ally.ability_scores.get_ability_modifier("DEX") + ally.trained_shield_bonus(), "CXM-07 fresh-process checkpoint restores the selected ordinary base beside Mage Armor")
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
