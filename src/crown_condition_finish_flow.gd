class_name CrownConditionFinishFlow
extends RefCounted

static func run(h: Node) -> void:
	h._enter_test("crown_condition_finish_flow")
	h._setup_world()
	PlayerManager.reset(); PartyManager.reset()
	for kind in ["monk", "wizard"]:
		var seat := PlayerManager.add_player(kind)
		var c: Character = h._fresh_char(kind, "human", kind, {"STR":12,"DEX":20,"CON":14,"INT":16,"WIS":16,"CHA":10})
		while c.level < 3: c.level_up()
		c.max_hp = 1000; c.current_hp = 1000
		PlayerManager.set_player_character(seat, c); PartyManager.register_player_character(seat, c)
	var combat: CombatState = await h._spawn_scene("res://scenes/combat.tscn", 0.5)
	var monk: Character = combat.player_entities[0].character
	var wizard: Character = combat.player_entities[1].character
	var enemy: Dictionary = combat.monster_entities[0]
	enemy.max_hp = 10000; enemy.current_hp = 10000; enemy.ac = -100; enemy.armor_class = -100
	combat.player_entities[0].hex_position = Vector2i.ZERO
	combat.player_entities[1].hex_position = Vector2i(0, 2)
	enemy.hex_position = Vector2i(1, 0)
	await initiative(h, combat, wizard)
	await hit_options(h, combat, monk, enemy)
	await character_death(h, combat, wizard)
	await concentration(h, combat, wizard, enemy)
	combat._end_monster_spell_sources()
	h._assert(monk.spell_effects.values().all(func(r): return str(r.get("caster_id", "")) != str(enemy.id)), "S235 encounter exit clears monster payloads before a party checkpoint")
	h._teardown_scene(combat)
	GameManager.game_in_progress = true
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.active_dungeon_state = {}
	monk.feature_uses["focus_points"] = 1
	h._assert(SaveManager.save_game("crown_condition_finish"), "Crown allowed checkpoint saves Open Hand progression and remaining Focus after encounter cleanup")
	h._exit_test()

static func reload(h: Node) -> void:
	h._enter_test("crown_condition_finish_reload")
	h._assert(SaveManager.load_game("crown_condition_finish"), "Crown fresh process loads its allowed checkpoint")
	var monk: Character = PlayerManager.get_player(0).character
	h._assert(CombatHitOptions.offers(monk, "flurry").size() == 1 and monk.get_focus_points() == 1, "Crown reload retains acquired executable Open Hand feature and exact Focus without replay")
	h._assert(monk.spell_effects.values().all(func(r): return not str(r.get("caster_id", "")).begins_with("monster_")), "S235 fresh process contains no orphaned monster caster payloads")
	h._exit_test()

static func character_death(h: Node, combat: CombatState, caster: Character) -> void:
	caster.known_spells.assign(["darkness", "dancing_lights"])
	h._own_class_spells(caster); h._ready_spell_components(caster)
	caster.wizard_spellbook = caster.wizard_spellbook.filter(func(id): return int(DataLoader.get_spell(id).get("level", 0)) > 0)
	for id in ["darkness", "dancing_lights"]:
		caster.spell_slots["2"] = 3
		h._p_focus(combat, caster)
		await h._cast_menu_spell(combat, id, 2 if id == "darkness" else 0)
		await combat._on_hex_clicked(Vector2i(1, 0))
		h._assert(not caster.concentrating_on.is_empty(), "S235 actual HUD establishes concentration before massive death: " + id)
		caster.take_damage(caster.current_hp + caster.max_hp + 10)
		h._assert(caster.is_dead() and caster.concentrating_on.is_empty() and not combat.dancing_light_sets.has(caster.character_id) and combat.active_spell_zones.values().all(func(z): return str(z.get("caster_id", "")) != caster.character_id), "S235 massive Character death immediately cleans live zone/light through actual owner: " + id)
		CorpseRules.revive(caster, int(GameManager.campaign_elapsed_seconds))
		caster.heal(caster.max_hp)

static func initiative(h: Node, combat: CombatState, owner: Character) -> void:
	Batch056Checks.load_fixtures(); SharedInitiativeChecks.load_fixtures()
	var made := Batch056Checks.make(owner, Batch056Checks.SPRITE, "condition_own")
	var actor: Character = made[-1]
	var events: Array = []
	var capture := func(r: Dictionary):
		if r.get("sides") == 20: events.append(r.duplicate(true))
	Dice.dice_rolled.connect(capture)
	for mode in ["invisible", "incapacitated", "both"]:
		actor.conditions.clear(); actor.condition_sources.clear(); actor.exhaustion_level = 2
		if mode != "incapacitated": actor.add_condition("invisible", 100)
		if mode != "invisible": actor.add_condition("incapacitated", 100)
		combat.tracker.remove_combatant(actor.character_id)
		events.clear()
		CreatedCommandRules.join_initiative(combat, owner, actor)
		var entries := combat.tracker.combatants.filter(func(c): return str(c.id) == actor.character_id)
		var expected := {"invisible":"advantage", "incapacitated":"disadvantage", "both":"single"}
		h._assert(entries.size() == 1 and events.size() == 1 and events[0].type == expected[mode] and int(entries[0].roll) == int(events[0].total) + actor.ability_scores.get_ability_modifier("DEX") - 4, "S235 production late-created own initiative uses shared modes and Exhaustion: " + mode)
	combat.tracker.remove_combatant(actor.character_id)
	var group := SharedInitiativeChecks.make(owner, SharedInitiativeChecks.ROLLED, "condition_group")
	var first: Character = group[0]
	first.add_condition("invisible", 100); first.exhaustion_level = 1; first.current_hp = 0
	events.clear()
	for member in [group[1], first]: CreatedCommandRules.join_initiative(combat, owner, member)
	var source := str(first.get_meta("created_source_id"))
	var captured: Dictionary = combat.tracker.shared_groups[source].duplicate(true)
	h._assert(events.size() == 1 and events[0].type == "single" and int(captured.roll) == int(events[0].total) + first.ability_scores.get_ability_modifier("DEX") - 2, "S235 reversed shared-group arrival uses first authored member's modes even downed")
	for member in group: combat.tracker.remove_combatant(member.character_id)
	first.remove_condition("invisible"); first.add_condition("incapacitated", 100)
	for member in [group[1], first]: CreatedCommandRules.join_initiative(combat, owner, member)
	h._assert(events.size() == 1 and combat.tracker.shared_groups[source] == captured, "S235 emptied/rebuilt group keeps one captured count without rerolling new conditions")
	for member in group: combat.tracker.remove_combatant(member.character_id)
	Dice.dice_rolled.disconnect(capture)
	owner.spell_effects.clear(); owner.concentrating_on.clear()

## Answers the actual popup, optionally changing live state while it is suspended.
static func answer(h: Node, hud: CombatHUD, label: String, change: Callable = Callable()) -> bool:
	for _frame in 180:
		for child in hud.get_children():
			if child is PopupMenu and child.visible and not child.is_queued_for_deletion():
				for index in child.item_count:
					if child.get_item_text(index) == label:
						if change.is_valid(): change.call()
						child.id_pressed.emit(child.get_item_id(index))
						child.hide()
						return true
		await h.get_tree().process_frame
	h._assert(false, "Actual hit-choice popup offers " + label)
	return false

static func flurry(h: Node, combat: CombatState, monk: Character, target: Dictionary, replies: Array, change: Callable = Callable()) -> void:
	await h._start_class_fixture_turn(combat, monk)
	monk.feature_uses["monk_flurry_of_blows"] = 1
	monk.feature_uses["focus_points"] = 3
	combat._update_grid_entities()
	await combat._on_hud_action("use_feature", {"feature":monk.get_feature("monk_flurry_of_blows")})
	var progress := {"done":false}
	var go := func():
		seed(20261003)
		await combat._on_hex_clicked(target.hex_position)
		progress.done = true
	go.call()
	for index in replies.size(): await answer(h, combat.hud, str(replies[index]), change if index == 0 else Callable())
	for _frame in 180:
		if progress.done: break
		await h.get_tree().process_frame
	h._assert(progress.done and monk.get_focus_points() == 2 and not combat.turn_budget.bonus_action_available, "S247 actual Flurry settles hit choices with one Focus/Bonus Action payment")

static func hit_options(h: Node, combat: CombatState, monk: Character, target: Dictionary) -> void:
	h._assert(CombatHitOptions.offers(monk, "flurry").size() == 1, "Crown acquired Open Hand level-3 feature has executable hit options")
	GameManager.test_mode = false
	CombatAction.apply_condition(target, "stunned", 100, "fixture:auto_fail")
	CombatAction.apply_condition(target, "grappled", 100, "fixture:held")
	var events: Array = []
	var capture := func(r: Dictionary): events.append(r.duplicate(true))
	Dice.dice_rolled.connect(capture)
	await flurry(h, combat, monk, target, ["Topple", "Decline"])
	h._assert(CombatAction.has_condition(target, "prone") and events.filter(func(r): return r.get("sides") == 20).size() == 2, "S247 production Topple auto-fails Stunned DEX without a save die")
	for index in combat.tracker.combatants.size():
		if is_same(combat.tracker.combatants[index].entity, target): combat.tracker.active_index = index
	await combat._start_combat_turn()
	h._assert(CombatAction.has_condition(target, "prone"), "S235 actual Grappled monster turn preserves source-owned Topple through skipped standing and turn end")
	target.conditions.erase("prone"); target.condition_sources.erase("prone")
	CombatAction.remove_condition_source(target, "fixture:held", ["grappled"])
	events.clear()
	await flurry(h, combat, monk, target, ["Push", "15 feet"])
	h._assert(HexUtils.get_distance(Vector2i.ZERO, target.hex_position) == 4 and combat.remaining_flurry_swings == 1 and events.filter(func(r): return r.get("sides") == 20).size() == 1, "S247 actual Push auto-fails STR and moves 15 feet; next paid strike cannot hit out of reach")
	target.hex_position = Vector2i(1, 0)
	await combat._on_hud_action("use_feature", {"feature":monk.get_feature("monk_flurry_of_blows")})
	var done := {"value":false}
	var resume := func():
		await combat._on_hex_clicked(target.hex_position)
		done.value = true
	resume.call(); await answer(h, combat.hud, "Addle")
	for _frame in 180:
		if done.value: break
		await h.get_tree().process_frame
	h._assert(done.value and combat.remaining_flurry_swings == 0 and monk.get_focus_points() == 2 and CombatAction.blocks_opportunity_attack(target), "Crown resumes remaining paid Flurry strike without repaying and applies Addle")
	CombatAction.clear_shocking_grasp(target)
	h._assert(not CombatAction.blocks_opportunity_attack(target), "Crown Addle ends at actual target-start cleanup and leaves ordinary Reactions available")
	target.conditions.clear(); target.condition_sources.clear()
	await flurry(h, combat, monk, target, ["Topple"], func(): monk.add_condition("incapacitated", 100, "fixture:stale_hit"))
	h._assert(not CombatAction.has_condition(target, "prone") and combat.remaining_flurry_swings == 1, "S247 stale hit choice after Incapacitated has no consequence, repeat strike or extra cost")
	monk.remove_condition("incapacitated")
	# Renaming the executable feature leaves its data semantics intact.
	var original := monk.get_feature("monk_open_hand_technique")
	DataLoader._load_json_file("res://data/fixtures/condition_recovery/hit_options.json", "subclass")
	var renamed: Dictionary = DataLoader.get_subclass("fixture:renamed_hit_subclass").features_by_level["3"][0]
	monk.features.erase(original); monk.features.append(renamed)
	await flurry(h, combat, monk, target, ["Addle", "Decline"])
	h._assert(CombatAction.blocks_opportunity_attack(target), "ADR0018 renamed JSON hit-option feature loads and works through actual HUD Flurry without registration")
	monk.features.erase(renamed); monk.features.append(original)
	CombatAction.clear_shocking_grasp(target)
	events.clear()
	target.conditions.clear(); target.condition_sources.clear()
	for condition in ["restrained", "blessed", "baned"]: CombatAction.apply_condition(target, condition, 100)
	target["saving_throw_bonuses"] = {"DEX":-100}
	await flurry(h, combat, monk, target, ["Topple", "Decline"])
	var receipts := CombatAction.weapon_rider_rolls.values().filter(func(r): return r.actor == monk and r.result.get("hit_option", {}).get("save", {}).get("roll_mode", "") == "disadvantage")
	h._assert(events.any(func(r): return r.get("sides") == 20 and r.get("type") == "disadvantage") and not receipts.is_empty() and receipts[-1].result.hit_option.save.get("check_bonus_dice", []).size() == 2, "S247 actual Monk Topple uses Restrained mode and captured Bless/Bane dice from shared save owner")
	target.conditions.clear(); target.condition_sources.clear()
	Dice.dice_rolled.disconnect(capture)
	GameManager.test_mode = true

static func concentration(h: Node, combat: CombatState, wizard: Character, target: Dictionary) -> void:
	var recipient: Character = combat.player_entities[0].character
	target.conditions.clear(); target.condition_sources.clear(); target.is_alive = true
	target.spells = [{"id":"bane"}]; target.spell_slots = {"1":10}
	target.saving_throw_bonuses = {"CON":100}
	recipient.add_modifier("roll", "save:CHA", -100, 100)
	await combat._execute_monster_spell(target, recipient.character_name, "bane")
	var owner := combat._make_monster_spellcaster(target)
	var first := str(owner.concentrating_on.get("effect_source", ""))
	h._assert(not first.is_empty() and target.spell_slots["1"] == 9 and recipient.spell_effects.has(first), "S235 real monster concentration cast retains source and pays one slot")
	await combat._execute_monster_spell(target, recipient.character_name, "bane")
	var second := str(owner.concentrating_on.get("effect_source", ""))
	h._assert(first != second and not recipient.spell_effects.has(first) and recipient.spell_effects.has(second) and target.spell_slots["1"] == 8, "S235 second concentration cast replaces exact previous source with one new payment")
	var rolls: Array = []
	var capture := func(r: Dictionary):
		if r.get("sides") == 20: rolls.append(r.duplicate(true))
	Dice.dice_rolled.connect(capture)
	var occurrence := WardRules.next_damage_occurrence_id()
	target.temp_hp = 100
	CombatAction.resolve_damage(target, 12, "fire", {}, false, false, wizard, occurrence)
	CombatAction.resolve_damage(target, 12, "cold", {}, false, false, wizard, occurrence)
	await combat._settle_monster_concentration()
	h._assert(rolls.size() == 1 and int(target.get("last_concentration_save", {}).get("damage", 0)) == 24 and int(target.last_concentration_save.dc) == 12 and not owner.concentrating_on.is_empty(), "S235 mixed typed packets into temp HP produce one captured concentration save at aggregate DC")
	rolls.clear()
	target.damage_immunities = ["poison"]
	CombatAction.resolve_damage(target, 10, "poison")
	await combat._settle_monster_concentration()
	h._assert(rolls.is_empty(), "S235 prevented damage has no concentration roll")
	target.erase("damage_immunities")
	# A real optional replacement suspends settlement. Another damage occurrence
	# queues behind it; neither an end-turn click nor a deferred flush can race it.
	ClassProgression.choose_subclass(wizard, "diviner")
	RollTokenRules.ensure_initialized(wizard)
	var tokens := RollTokenRules.available_tokens(wizard, "diviner_portent").size()
	var serial := CombatAction.active_turn_serial
	GameManager.test_mode = false
	CombatAction.resolve_damage(target, 1, "force")
	var prompt: ConfirmationDialog
	for _frame in 180:
		for child in combat.hud.get_children():
			if child is ConfirmationDialog and child.visible and str(child.title).contains("Replacement") and not child.is_queued_for_deletion(): prompt = child
		if prompt != null: break
		await h.get_tree().process_frame
	h._assert(prompt != null and combat._monster_concentration_flushing, "S235 actual monster concentration opens eligible party replacement chooser")
	await combat._on_hud_action("end_turn", {})
	CombatAction.resolve_damage(target, 2, "force")
	h._assert(CombatAction.active_turn_serial == serial and combat._monster_concentration_damage.size() == 2, "S235 held concentration chooser serializes new damage and refuses turn advancement")
	if prompt != null: prompt.confirmed.emit()
	for _frame in 180:
		for child in combat.hud.get_children():
			if child is ConfirmationDialog and child.visible and str(child.title).contains("Replacement") and not child.is_queued_for_deletion() and child != prompt: child.canceled.emit()
		if not combat._monster_concentration_flushing: break
		await h.get_tree().process_frame
	h._assert(not combat._monster_concentration_flushing and combat._monster_concentration_damage.is_empty() and RollTokenRules.available_tokens(wizard, "diviner_portent").size() == tokens - 1 and CombatAction.active_turn_serial == serial, "S235 concentration choices settle queued occurrences once with one token cost and no raced turn")
	await h._start_class_fixture_turn(combat, recipient)
	recipient.feature_uses["focus_points"] = 3
	recipient.feature_uses["monk_flurry_of_blows"] = 1
	await combat._on_hud_action("use_feature", {"feature":recipient.get_feature("monk_flurry_of_blows")})
	var mixed := {"done":false, "overlap":false, "hit_choices":0, "save_choices":0}
	var launch := func():
		seed(20261003)
		await combat._on_hex_clicked(target.hex_position)
		mixed.done = true
	launch.call()
	for _frame in 240:
		var windows := combat.hud.get_children().filter(func(child): return child is Window and child.visible and not child.is_queued_for_deletion())
		if windows.size() > 1: mixed.overlap = true
		# Observe a full frame before answering so deferred concentration work runs.
		await h.get_tree().process_frame
		for child in windows:
			if not is_instance_valid(child) or child.is_queued_for_deletion(): continue
			if child is ConfirmationDialog and str(child.title).contains("Replacement"):
				mixed.save_choices += 1; child.canceled.emit()
			elif child is PopupMenu:
				for index in child.item_count:
					if child.get_item_text(index) == "Decline":
						mixed.hit_choices += 1; child.id_pressed.emit(child.get_item_id(index)); child.hide(); break
		if mixed.done and not combat._monster_concentration_flushing and combat._monster_concentration_damage.is_empty(): break
	h._assert(mixed.done and not mixed.overlap and mixed.hit_choices == 2 and mixed.save_choices > 0 and recipient.get_focus_points() == 2, "S235/S247 actual Flurry hit choices and concentration replacements serialize without overlapping dialogs or duplicate payment")
	GameManager.test_mode = true
	wizard.known_spells.assign(["magic_missile"]); h._own_class_spells(wizard); h._ready_spell_components(wizard)
	wizard.wizard_spellbook = wizard.wizard_spellbook.filter(func(id): return int(DataLoader.get_spell(id).get("level", 0)) > 0)
	wizard.spell_slots["1"] = 2
	h._p_focus(combat, wizard); rolls.clear()
	await h._cast_menu_spell(combat, "magic_missile", 1)
	for _dart in 3: await combat._on_hex_clicked(target.hex_position)
	await combat._settle_monster_concentration()
	h._assert(not rolls.is_empty() and target.spell_slots["1"] == 8 and not owner.concentrating_on.is_empty(), "S235 actual HUD spell damage checks retained monster concentration without refunding monster slots")
	# Expiry uses the caster's normal turn boundary, once per phase and round.
	for actor in [recipient, target]:
		if SpellEffects.records(actor).has(second): SpellEffects.records(actor)[second].remaining_seconds = 6
	combat.tracker.current_round += 1
	combat._tick_spell_effect_boundary(owner, "start")
	SpellEffects.reconcile(combat._spell_casters(), combat._spell_effect_targets())
	h._assert(owner.concentrating_on.is_empty() and not recipient.spell_effects.has(second), "S235 monster owner clock expires recipient payload and concentration")
	await combat._execute_monster_spell(target, recipient.character_name, "bane")
	rolls.clear()
	CombatAction.resolve_damage(target, 20000, "force")
	h._assert(owner.concentrating_on.is_empty() and not recipient.has_condition("baned") and rolls.is_empty(), "S235 lethal damage immediately ends monster concentration without rolling")
	Dice.dice_rolled.disconnect(capture)
