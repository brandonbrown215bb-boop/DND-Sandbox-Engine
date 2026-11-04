class_name ConditionRecoveryFlow
extends RefCounted

static func run(h: Node) -> void:
	h._enter_test("condition_recovery_flow")
	h._setup_mixed_world()
	var combat: CombatState = await h._spawn_scene("res://scenes/combat.tscn", 0.5)
	var c: Character = combat.player_entities[0].character
	var enemy: Dictionary = combat.monster_entities[0]
	combat.player_entities[0].hex_position = Vector2i.ZERO
	enemy.hex_position = Vector2i(2, 0)
	enemy.current_hp = 10000; enemy.max_hp = 10000
	combat._update_grid_entities()
	var spell := {"id":"fixture:condition_save", "name":"Condition save", "save":"DEX", "save_advantage_if_fighting_target":true, "_save_dc_override":2, "target":"single"}
	CombatAction.apply_condition(enemy, "restrained", 100, "fixture:snare")
	var cast := SpellResolutionContext.new()
	cast.caster = c; cast.target = enemy; cast.spell = spell
	# SC-05 support 03 made "fighting" mean opposed initiative combatants, so
	# the fixture must cast through the live combat host (not a host-less cast).
	var unhosted := SpellSaveResolver.resolve(cast)
	h._assert(unhosted.get("save_test", {}).get("rolls", []).size() == 2, "S247 host-less cast is not fighting: Restrained Disadvantage stands alone")
	var host := SpellCastContext.new()
	host.caster = c; host.spell = spell; host.tracker = combat.tracker
	cast.spatial_host = host
	var result := SpellSaveResolver.resolve(cast)
	h._assert(SpellSaveResolver.is_fighting_caster_side(cast, enemy) and result.get("save_test", {}).get("rolls", []).size() == 1, "S247 spell and generic save owners cancel Restrained against Advantage once")
	CombatAction.apply_condition(enemy, "blessed", 100)
	CombatAction.apply_condition(enemy, "baned", 100)
	var receipt := BarbarianRules.roll_monster_save_result(enemy, "DEX")
	var bonus := 0
	for die in receipt.get("check_bonus_dice", []): bonus += int(die.value) * int(die.get("sign", 1))
	h._assert(receipt.get("check_bonus_dice", []).size() == 2 and int(receipt.total) == int(receipt.natural_roll) + int(receipt.get("base_modifier", 0)) + bonus and receipt.get("roll_mode") == "disadvantage", "S247 monster save captures modes and both Bless/Bane dice with reconstructible arithmetic")
	CombatAction.apply_condition(enemy, "charmed", 100, c.character_id)
	h._assert(EventResolver.resolve_skill_check(c, {"ability":"CHA", "skill":"Persuasion", "dc":10}, {}, {"social_target":enemy}).get("advantage", false), "S248 Character charmer gains social Advantage against actual monster")
	c.add_condition("charmed", 100, str(enemy.id))
	h._assert(EventResolver.resolve_monster_ability_check(enemy, "CHA", "Persuasion", 10, 0, {}, {"social_target":c}).get("advantage", false), "S248 monster charmer gains social Advantage against actual Character")
	c.remove_condition("charmed")
	# Damage from events/direct shared steps must clean through the same live owner.
	var grant := SpellEffects.begin_cast(c, DataLoader.get_spell("bless"))
	c.concentrating_on = {"spell_id":"bless", "effect_source":grant.source_id, "targets":[c]}
	SpellEffects.grant(c, grant, "blessed")
	c.take_damage(c.current_hp)
	h._assert(c.concentrating_on.is_empty() and not c.has_condition("blessed"), "S235 zero-HP damage immediately cleans concentration through actual encounter owner")
	c.heal(1)
	await actor_turns(h, combat)
	await concentration(h, combat)
	await ai_turns(h, combat)
	await sources_and_perception(h, combat)
	await stale_spell(h, combat)
	await crown_concentration(h, combat)
	await saves(h, combat)
	await check_routes(h, combat)
	h._teardown_scene(combat)
	await ambush(h)
	await checkpoint(h)
	h._exit_test()

static func crown_concentration(h: Node, combat: CombatState) -> void:
	var enemy: Dictionary = combat.monster_entities[0]
	var c: Character = combat.player_entities[0].character
	enemy.conditions.clear(); enemy.condition_sources.clear()
	enemy.spells = [{"id":"bane"}]; enemy.spell_slots = {"1":10}
	enemy.hex_position = Vector2i(1, 0); combat.player_entities[0].hex_position = Vector2i.ZERO
	c.add_modifier("roll", "save:CHA", -100, 100)
	await combat._execute_monster_spell(enemy, c.character_name, "bane")
	var owner := combat._make_monster_spellcaster(enemy)
	h._assert(not owner.concentrating_on.is_empty() and c.has_condition("baned"), "S235 actual monster cast retains its concentration owner and recipient payload")
	c.add_condition("baned", 100, "fixture:independent_bane")
	CombatAction.apply_condition(enemy, "stunned", 100, "fixture:stop_caster")
	h._assert(owner.concentrating_on.is_empty() and c.condition_sources.get("baned", {}).size() == 1 and c.condition_sources.get("baned", {}).has("fixture:independent_bane"), "S235 monster Incapacitated immediately ends only its actual source")
	CombatAction.remove_condition_source(enemy, "fixture:stop_caster", ["stunned"])
	c.remove_condition("baned")

static func actor_turns(h: Node, combat: CombatState) -> void:
	var c: Character = combat.player_entities[1].character
	while c.level < 2: c.level_up()
	for condition in ["incapacitated", "stunned", "petrified", "paralyzed", "unconscious", "restrained", "grappled"]:
		c.add_condition(condition, 100, "fixture:turn")
		await h._start_class_fixture_turn(combat, c)
		var cannot_act := CombatAction.is_incapacitated(c)
		if cannot_act and CombatAction.is_speed_zero(c):
			h._assert(not is_same(combat.tracker.get_active().get("entity"), c), "S235 immobile Incapacitated actor ends unusable production turn: " + condition)
			CombatAction.remove_condition_source(c, "fixture:turn", [condition])
			continue
		h._assert(combat.active_character == c and combat._can_spend_action_cost("action") != cannot_act and combat._can_spend_action_cost("bonus_action") != cannot_act and combat.hud.btn_attack.disabled == cannot_act, "S235 actual turn and HUD action refusal: " + condition)
		h._assert((combat.remaining_speed > 0) == (condition in ["stunned", "incapacitated"]), "S235 actual turn movement: " + condition)
		var before := c.feature_uses.duplicate(true)
		if cannot_act:
			await combat._on_hud_action("use_feature", {"feature":c.get_feature("rogue_cunning_action"), "selected_action":"dash"})
			h._assert(before == c.feature_uses and combat.turn_budget.bonus_action_available, "S235 refused feature spends no uses or Bonus Action: " + condition)
		CombatAction.remove_condition_source(c, "fixture:turn", [condition])
	c.inventory.equip(Inventory.Slot.WEAPON, "rapier", true)
	c.add_condition("prone", 100, "fixture:explicit_prone")
	c.add_condition("unconscious", 100, "fixture:slumber")
	var drops := combat.dropped_combat_items.size()
	c.take_damage(c.current_hp)
	c.heal(1)
	h._assert(c.has_condition("unconscious") and c.condition_sources.get("unconscious", {}).has("fixture:slumber") and c.condition_sources.get("prone", {}).has("fixture:explicit_prone") and combat.dropped_combat_items.size() == drops, "S235 healing zero HP preserves explicit sleep/Prone and never duplicates held-item drops")
	c.heal(c.max_hp)
	CombatAction.resolve_damage(c, 1, "force")
	h._assert(c.condition_sources.get("unconscious", {}).has("fixture:slumber"), "S235 damage ends only sources that declare waking on damage")
	CombatAction.remove_condition_source(c, "fixture:slumber", ["unconscious"])
	h._assert(not c.has_condition("unconscious") and c.has_condition("prone"), "S235 removing sleep removes derived Prone while the independent Prone source remains")
	c.remove_condition("prone")
	var hp := c.current_hp
	c.add_condition("poisoned", 100)
	await h._start_class_fixture_turn(combat, c)
	h._assert(c.current_hp == hp, "S235 Poisoned does not deal invented damage at production turn start")
	c.remove_condition("poisoned")
	for subject in [c, combat.monster_entities[0]]:
		CombatAction.apply_condition(subject, "petrified", 100, "fixture:stone")
		CombatAction.apply_condition(subject, "poisoned", 100, "fixture:venom")
		var poison := CombatAction.resolve_damage(subject, 10, "poison")
		var slash := CombatAction.resolve_damage(subject, 10, "slashing")
		h._assert(not CombatAction.has_condition(subject, "poisoned") and int(poison.resolved) == 0 and int(slash.resolved) == 5, "S235 live shared damage owner applies Petrified poison immunity and resistance: " + CombatAction.actor_id(subject))
		CombatAction.remove_condition_source(subject, "fixture:stone", ["petrified"])
	c.heal(c.max_hp)

static func concentration(h: Node, combat: CombatState) -> void:
	var wizard: Character = combat.player_entities[2].character
	var ally: Character = combat.player_entities[0].character
	while wizard.level < 5: wizard.level_up()
	wizard.known_spells.assign(["invisibility", "darkness", "dancing_lights"])
	h._own_class_spells(wizard); h._ready_spell_components(wizard)
	combat.player_entities[2].hex_position = Vector2i.ZERO
	combat.player_entities[0].hex_position = Vector2i(1, 0)
	for id in ["invisibility", "darkness", "dancing_lights"]:
		wizard.spell_slots["2"] = 3
		h._p_focus(combat, wizard)
		combat._update_grid_entities()
		await h._cast_menu_spell(combat, id, 2 if id != "dancing_lights" else 0)
		await combat._on_hex_clicked(Vector2i(1, 0))
		h._assert(not wizard.concentrating_on.is_empty(), "S235 actual HUD cast begins concentration: " + id)
		var source := str(wizard.concentrating_on.get("effect_source", ""))
		var zone_source := str(wizard.concentrating_on.get("darkness_source_id", ""))
		if id == "invisibility": ally.add_condition("invisible", 100, "fixture:independent_cloak")
		wizard.add_condition("incapacitated", 100, "fixture:stop")
		h._assert(wizard.concentrating_on.is_empty() and (source.is_empty() or not ally.spell_effects.has(source)) and (zone_source.is_empty() or not combat.active_spell_zones.has(zone_source)) and not combat.dancing_light_sets.has(wizard.character_id), "S235 Incapacitated immediately ends recipients, zone or lights through live owner: " + id)
		if id == "invisibility":
			h._assert(ally.has_condition("invisible") and ally.condition_sources.get("invisible", {}).has("fixture:independent_cloak"), "S235 concentration cleanup preserves another Invisible source")
			ally.remove_condition("invisible")
		wizard.remove_condition("incapacitated")
		combat._update_grid_entities()

static func ai_turns(h: Node, combat: CombatState) -> void:
	var enemy: Dictionary = combat.monster_entities[0]
	var target: Character = combat.player_entities[0].character
	target.max_hp = 10000; target.current_hp = 10000
	for p in combat.player_entities:
		p.character.current_hp = p.character.max_hp
		p.character.is_alive = true
	for p in combat.player_entities: p.hex_position = Vector2i(6, -3)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	enemy.conditions.clear(); enemy.condition_sources.clear()
	for behavior in ["aggressive", "defensive"]:
		for condition in ["incapacitated", "stunned", "petrified", "paralyzed", "unconscious", "restrained", "grappled"]:
			enemy.ai_behavior = behavior
			enemy.hex_position = Vector2i(3, 0)
			combat.turn_budget.reset(target, combat.player_entities)
			combat.tracker.clear()
			combat.tracker.add_combatant(str(enemy.id), str(enemy.name), false, enemy, 20, 14)
			combat.tracker.add_combatant(target.character_id, target.character_name, true, target, 10, 14)
			CombatAction.apply_condition(enemy, condition, 100, "fixture:ai")
			combat.active_combatant = {"is_player":false, "entity":enemy}
			combat.active_character = null; combat.current_player_idx = -1
			combat._update_grid_entities()
			var hp := target.current_hp
			await combat._run_monster_ai()
			h._assert((enemy.hex_position != Vector2i(3, 0)) == (condition in ["incapacitated", "stunned"]) and (not CombatAction.is_incapacitated(enemy) or target.current_hp == hp), "S246 production AI movement/action condition " + behavior + ": " + condition)
			CombatAction.remove_condition_source(enemy, "fixture:ai", [condition])
		for held in [false, true]:
			enemy.conditions.clear(); enemy.condition_sources.clear()
			enemy.hex_position = Vector2i(3, 0)
			CombatAction.apply_condition(enemy, "prone", 100)
			if held: CombatAction.apply_condition(enemy, "grappled", 100)
			combat.tracker.clear()
			combat.tracker.add_combatant(str(enemy.id), str(enemy.name), false, enemy, 20, 14)
			combat.tracker.add_combatant(target.character_id, target.character_name, true, target, 10, 14)
			await combat._start_combat_turn()
			h._assert(CombatAction.has_condition(enemy, "prone") == held and bool(enemy.get("fighter_stood_up", false)) != held, "S246 actual monster turn stands only with usable Speed: %s held=%s" % [behavior, held])
			await h.get_tree().create_timer(1.3).timeout
			enemy.conditions.clear(); enemy.condition_sources.clear()
	enemy.hex_position = Vector2i(1, 0)
	combat._update_grid_entities()
	var accepted := AICommand.from_decision({"action":"attack", "target_id":target.character_name, "attack_idx":0}, enemy, combat.player_entities, combat.hex_grid)
	CombatAction.apply_condition(enemy, "charmed", 100, target.character_id)
	var hp := target.current_hp
	await combat._execute_monster_attack(enemy, target.character_name, 0)
	h._assert(accepted != null and not accepted.is_valid(enemy, combat.player_entities, combat.hex_grid) and target.current_hp == hp, "S246 accepted attack becomes stale when its actual target charms the attacker")
	CombatAction.remove_condition_source(enemy, target.character_id, ["charmed"])

static func check_routes(h: Node, combat: CombatState) -> void:
	var rogue: Character = combat.player_entities[1].character
	var enemy: Dictionary = combat.monster_entities[0]
	combat.player_entities[1].hex_position = Vector2i.ZERO
	rogue.skill_proficiencies.assign(["Stealth", "Acrobatics"])
	rogue.feature_choices["rogue_expertise"] = ["Stealth", "Acrobatics"]
	rogue.exhaustion_level = 2
	rogue.add_condition("poisoned", 100)
	var events: Array = []
	var capture := func(r: Dictionary): events.append(r.duplicate(true))
	Dice.dice_rolled.connect(capture)
	combat.hex_grid.obscurement_sources["fixture:legal_hide"] = {"kind":"fog", "coords":[combat.player_entities[1].hex_position]}
	for effect in ["cunning_hide", "cunning_action"]:
		h._p_focus(combat, rogue)
		events.clear()
		var feature := {"id":"fixture:" + effect, "name":"Hide check route", "action_cost":"bonus_action", "type":"active", "uses":1, "uses_per":"turn", "effects":[{"type":effect}], "selected_action":"hide"}
		rogue.features.append(feature)
		rogue.feature_uses[feature.id] = 1
		var legality := OrdinaryActionRules.hide_error(rogue, combat.player_entities[1].hex_position, combat.monster_entities, combat.hex_grid)
		h._assert(legality.is_empty(), "S248 Hide fixture has a legal place: " + legality)
		await combat._execute_class_feature(feature)
		h._assert(events.any(func(r): return r.get("type") == "disadvantage") and not combat.turn_budget.bonus_action_available and int(rogue.feature_uses[feature.id]) == 0, "S248 real Cunning Hide branch uses poisoned check owner and pays once: " + effect)
		var natural := int(events[0].total) if not events.is_empty() else -100
		var mod := rogue.get_skill_check_modifier("Stealth", "DEX")
		var expected := "Hide: Stealth %d vs DC 15" % (natural + mod)
		h._assert(combat.hud.log_text.text.contains(expected), "S248 Hide captures actual proficiency, expertise and Exhaustion arithmetic: " + effect)
		var count := events.size()
		await combat._execute_class_feature(feature)
		h._assert(events.size() == count and int(rogue.feature_uses[feature.id]) == 0, "S248 repeated Hide submission cannot roll or pay again: " + effect)
		rogue.features.erase(feature); rogue.feature_uses.erase(feature.id)
	combat.hex_grid.obscurement_sources.erase("fixture:legal_hide")
	rogue.remove_condition("poisoned")
	rogue.exhaustion_level = 0
	# The generic monster zone consumer must use the same check owner.
	enemy.conditions.clear(); enemy.condition_sources.clear()
	CombatAction.apply_condition(enemy, "restrained", 100, "entangle:condition_probe")
	CombatAction.apply_condition(enemy, "poisoned", 100)
	combat.active_spell_zones["entangle:condition_probe"] = {"spell_id":"entangle", "save_dc":100, "restrained_targets":[enemy]}
	events.clear()
	h._assert(combat._try_monster_escape_restrained_zone(enemy) and events.any(func(r): return r.get("type") == "disadvantage"), "S248 actual monster zone escape rolls Poisoned Disadvantage")
	combat.active_spell_zones.erase("entangle:condition_probe")
	enemy.conditions.clear(); enemy.condition_sources.clear()
	DataLoader._load_json_file("res://data/fixtures/condition_recovery/spells.json", "spell")
	var spell := DataLoader.get_spell("fixture:condition_cord")
	h._assert(not spell.is_empty(), "S248 executable cord fixture loads through production DataLoader")
	if spell.is_empty(): Dice.dice_rolled.disconnect(capture); return
	var caster: Character = combat.player_entities[2].character
	var source := SpellEffects.begin_cast(caster, spell)
	source["save_dc"] = 100
	caster.spell_effects[source.source_id] = source
	caster.concentrating_on = {"spell_id":spell.id, "effect_source":source.source_id, "targets":[enemy, rogue]}
	TetherRules.apply(caster, enemy, source, spell.effects[0], spell)
	TetherRules.apply(caster, rogue, source, spell.effects[0], spell)
	enemy["skills"] = {"Athletics":9}; enemy["exhaustion_level"] = 2
	CombatAction.apply_condition(enemy, "poisoned", 100)
	events.clear()
	h._assert(combat._try_monster_escape_tether(enemy) and events.any(func(r): return r.get("type") == "disadvantage"), "S248 actual monster tether escape applies Poisoned modes")
	var total := int(events[0].total) + 5 if not events.is_empty() else -100
	h._assert(combat.hud.log_text.text.contains("(%d vs DC 100)" % total), "S248 monster tether escape includes stat-block skill and Exhaustion exactly once")
	var helper: Dictionary = combat.monster_entities[1]
	helper.hex_position = enemy.hex_position + Vector2i(1, 0)
	helper["skills"] = {"Athletics":8}; helper["exhaustion_level"] = 1
	CombatAction.apply_condition(helper, "poisoned", 100)
	events.clear()
	h._assert(combat._try_monster_rescue_tether(helper) and events.any(func(r): return r.get("type") == "disadvantage"), "S248 actual monster tether rescue uses condition-aware check rather than a raw d20")
	rogue.exhaustion_level = 2; rogue.add_condition("poisoned", 100)
	h._p_focus(combat, rogue)
	events.clear()
	var attempted := await combat._try_escape_tether(rogue)
	var count := events.size()
	await combat._try_escape_tether(rogue)
	h._assert(attempted and events.any(func(r): return r.get("type") == "disadvantage") and events.size() == count and not combat._can_spend_action_cost("action"), "S248 actual Character tether escape applies modes and spends one Action without rerolling a repeated submission")
	combat._end_concentration(caster)
	rogue.exhaustion_level = 0; rogue.remove_condition("poisoned")
	Dice.dice_rolled.disconnect(capture)

static func sources_and_perception(h: Node, combat: CombatState) -> void:
	var enemy: Dictionary = combat.monster_entities[0]
	var a: Character = combat.player_entities[0].character
	var b: Character = combat.player_entities[1].character
	var old_a := a.character_id
	a.character_id = "party:actual:source"
	combat.player_entities[0].hex_position = Vector2i.ZERO
	combat.player_entities[1].hex_position = Vector2i(2, 0)
	enemy.hex_position = Vector2i(1, 0)
	var cast_a := SpellEffects.begin_cast(a, {"id":"fixture:renamed_source", "duration_seconds":600})
	var cast_b := SpellEffects.begin_cast(b, {"id":"fixture:other_source", "duration_seconds":600})
	for cast in [cast_a, cast_b]:
		SpellEffects.grant(enemy, cast, "charmed")
		SpellEffects.grant(enemy, cast, "frightened")
	combat._update_grid_entities()
	for source in [a, b]:
		h._assert(CombatAction.is_charmed_by(enemy, source), "S235 actual actor owns simultaneous charm: " + source.character_id)
	h._assert(not CombatAction.is_charmed_by(enemy, "party"), "S235 colon-containing actual identity cannot invent a second charmer")
	for destination in [Vector2i.ZERO, Vector2i(2, 0)]:
		h._assert(CombatAction.frightened_forbids_movement_closer(enemy, enemy.hex_position, destination, combat._all_live_combat_entities()), "S246 either real simultaneous fear source prevents approach")
	SpellEffects.remove(enemy, str(cast_a.source_id))
	h._assert(not CombatAction.is_charmed_by(enemy, a) and CombatAction.is_charmed_by(enemy, b) and CombatAction.frightened_source_ids(enemy) == [b.character_id], "S235 ending one source preserves exactly the other charm/fear owner")
	var rolls: Array = []
	var capture := func(r: Dictionary):
		if r.get("sides") == 20: rolls.append(r.duplicate(true))
	Dice.dice_rolled.connect(capture)
	await combat._execute_monster_attack(enemy, a.character_name, 0)
	h._assert(not rolls.is_empty() and rolls[0].get("type") == "disadvantage", "S246 real monster attack has fear Disadvantage while remaining source is visible")
	b.add_condition("invisible", 100)
	rolls.clear()
	await combat._execute_monster_attack(enemy, a.character_name, 0)
	h._assert(not rolls.is_empty() and rolls[0].get("type") == "single", "S246 real monster attack loses fear Disadvantage when actual source becomes unseen")
	b.remove_condition("invisible")
	Dice.dice_rolled.disconnect(capture)
	SpellEffects.remove(enemy, str(cast_b.source_id))
	a.character_id = old_a
	combat.player_entities[1].hex_position = Vector2i(6, -3)
	enemy.erase("senses"); enemy.erase("blindsight_range_feet")
	for behavior in ["aggressive", "defensive"]:
		enemy.ai_behavior = behavior
		a.add_condition("invisible", 100)
		a.add_condition("hidden", 100)
		combat._update_grid_entities()
		var decision := AIController.get_monster_action(enemy, enemy.hex_position, combat.hex_grid, combat.player_entities)
		h._assert(decision.get("target_id", "") != a.character_name, "S246 AI cannot choose an unknown Hidden location: " + behavior)
		a.remove_condition("hidden")
		combat._update_grid_entities()
		decision = AIController.get_monster_action(enemy, enemy.hex_position, combat.hex_grid, combat.player_entities)
		h._assert(decision.get("target_id", "") == a.character_name and AICommand.from_decision(decision, enemy, combat.player_entities, combat.hex_grid) != null, "S246 AI can attack known Invisible location: " + behavior)
		enemy["spells"] = [{"id":"sacred_flame"}]
		CombatAction.apply_condition(enemy, "blinded", 100)
		decision = AIController.get_monster_action(enemy, enemy.hex_position, combat.hex_grid, combat.player_entities)
		h._assert(decision.get("action") != "cast_spell", "S246 Blinded AI refuses a sight-requiring spell: " + behavior)
		enemy["senses"] = {"blindsight":10}
		decision = AIController.get_monster_action(enemy, enemy.hex_position, combat.hex_grid, combat.player_entities)
		h._assert(decision.get("action") == "cast_spell" and AICommand.from_decision(decision, enemy, combat.player_entities, combat.hex_grid) != null, "S246 special sense supplies actual sight while Blinded: " + behavior)
		enemy.conditions.erase("blinded"); enemy.erase("senses")
		a.remove_condition("invisible")
		enemy["spells"] = []

static func stale_spell(h: Node, combat: CombatState) -> void:
	var enemy: Dictionary = combat.monster_entities[0]
	var c: Character = combat.player_entities[0].character
	enemy.hex_position = Vector2i(1, 0)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	enemy.conditions.clear(); enemy.condition_sources.clear()
	enemy["spells"] = [{"id":"ray_of_enfeeblement"}, {"id":"sacred_flame"}]
	enemy["spell_slots"] = {"2":2}
	c.feature_uses["bardic_inspiration_die"] = "1d6"
	var before := c.current_hp
	var state := {"done":false}
	GameManager.test_mode = false
	var begin := func():
		await combat._execute_monster_spell(enemy, c.character_name, "ray_of_enfeeblement")
		state.done = true
	begin.call()
	var prompt: ConfirmationDialog
	for _frame in 120:
		for child in combat.hud.get_children():
			if child is ConfirmationDialog and str(child.title).contains("Bardic Inspiration") and not child.is_queued_for_deletion(): prompt = child
		if prompt != null: break
		await h.get_tree().process_frame
	h._assert(prompt != null and not state.done, "S246 actual monster spell opens the target's optional save choice")
	CombatAction.apply_condition(enemy, "stunned", 100, "fixture:interrupt")
	if prompt != null: prompt.confirmed.emit()
	for _frame in 120:
		if state.done: break
		await h.get_tree().process_frame
	h._assert(state.done and c.current_hp == before and enemy.spell_slots["2"] == 2 and c.feature_uses.has("bardic_inspiration_die"), "S246 becoming Incapacitated during the actual save chooser refuses stale spell before slot, die or damage")
	GameManager.test_mode = true
	c.feature_uses.erase("bardic_inspiration_die")
	CombatAction.remove_condition_source(enemy, "fixture:interrupt", ["stunned"])
	enemy.is_alive = false
	var dead_intent := AICommand.new("cast_spell", {"target_id":c.character_name, "spell_id":"ray_of_enfeeblement"})
	await combat._execute_monster_spell(enemy, c.character_name, "ray_of_enfeeblement")
	h._assert(not dead_intent.is_valid(enemy, combat.player_entities, combat.hex_grid) and enemy.spell_slots["2"] == 2 and c.current_hp == before, "S246 a dead monster's stale spell is refused before payment or target effects")
	enemy.is_alive = true
	c.add_modifier("roll", "save:DEX", -100, 100)
	await combat._execute_monster_spell(enemy, c.character_name, "sacred_flame")
	h._assert(c.current_hp < before and combat._make_monster_spellcaster(enemy).character_id == str(enemy.id), "S246 actual monster cast uses its declared spell permission and stable actor identity")
	enemy.spells.append({"id":"ray_of_sickness"})
	enemy.spell_slots["1"] = 2
	var serial := int(enemy.get("spell_cast_serial", 0))
	await combat._execute_monster_spell(enemy, c.character_name, "ray_of_sickness")
	await combat._execute_monster_spell(enemy, c.character_name, "ray_of_sickness")
	h._assert(int(enemy.get("spell_cast_serial", 0)) == serial + 2 and int(enemy.spell_slots["1"]) == 0, "S246 separate real monster casts retain distinct source serials and pay exactly one slot each")
	c.heal(c.max_hp)

static func saves(h: Node, combat: CombatState) -> void:
	var c: Character = combat.player_entities[0].character
	var enemy: Dictionary = combat.monster_entities[0]
	var events: Array = []
	var capture := func(r: Dictionary): events.append(r.duplicate(true))
	Dice.dice_rolled.connect(capture)
	for condition in ["paralyzed", "stunned", "unconscious", "petrified"]:
		c.add_condition(condition, 100, "fixture:save")
		CombatAction.apply_condition(enemy, condition, 100, "fixture:save")
		for ability in ["STR", "DEX"]:
			events.clear()
			var pc := c.saving_throw_test_to_dc(ability, 2)
			var monster := BarbarianRules.roll_monster_save_result(enemy, ability)
			var cast := SpellResolutionContext.new()
			cast.caster = c; cast.target = enemy; cast.spell = {"id":"fixture:automatic", "save":ability, "_save_dc_override":2}
			var result := SpellSaveResolver.resolve(cast)
			h._assert(pc.get("auto_failed", false) and monster.get("auto_failed", false) and not result.get("saved", true) and events.is_empty(), "S247 generic Character/monster and spell auto-failure emits no dice: " + condition + " " + ability)
		CombatAction.remove_condition_source(c, "fixture:save", [condition])
		CombatAction.remove_condition_source(enemy, "fixture:save", [condition])
	# Exercise the actual permissioned HUD cast, not just the save methods.
	var diviner: Character = combat.player_entities[2].character
	ClassProgression.choose_subclass(diviner, "diviner")
	RollTokenRules.ensure_initialized(diviner)
	var tokens_before := RollTokenRules.available_tokens(diviner, "diviner_portent").size()
	var cleric: Character = combat.player_entities[3].character
	cleric.known_spells.assign(["sacred_flame"]); h._own_class_spells(cleric)
	h._ready_spell_components(cleric)
	combat.player_entities[3].hex_position = Vector2i.ZERO
	enemy.hex_position = Vector2i(2, 0)
	CombatAction.apply_condition(enemy, "paralyzed", 100, "fixture:save")
	h._p_focus(combat, cleric); combat._update_grid_entities()
	h._assert(tokens_before > 0 and not combat._collect_eligible_roll_token_entries("monster_save", enemy).is_empty(), "S247 actual save target has an eligible visible party roll-token owner")
	events.clear()
	await h._cast_menu_spell(combat, "sacred_flame")
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(not combat._can_spend_action_cost("action") and not events.any(func(r): return r.get("sides") == 20), "S247 actual HUD save cast resolves automatic failure without rolling a d20 (action=%s dice=%s log=%s)" % [combat._can_spend_action_cost("action"), str(events), combat.hud.log_text.text.right(500)])
	CombatAction.remove_condition_source(enemy, "fixture:save", ["paralyzed"])
	h._assert(RollTokenRules.available_tokens(diviner, "diviner_portent").size() == tokens_before, "S247 automatic HUD save does not spend an eligible roll token")
	# The monster's route must not open a Bardic Inspiration chooser for an
	# automatic failure either, even with real dialogs enabled.
	c.add_condition("paralyzed", 100, "fixture:no_roll")
	c.feature_uses["bardic_inspiration_die"] = "1d6"
	GameManager.test_mode = false
	var state := {"done":false}
	var begin := func():
		await combat._execute_monster_spell(enemy, c.character_name, "sacred_flame")
		state.done = true
	begin.call()
	for _frame in 120:
		if state.done: break
		await h.get_tree().process_frame
	h._assert(state.done and c.feature_uses.has("bardic_inspiration_die") and RollTokenRules.available_tokens(diviner, "diviner_portent").size() == tokens_before, "S247 actual monster spell automatic save bypasses optional chooser, Inspiration and roll tokens")
	# Release a bad chooser too so a regression reports a failure, not a hang.
	if not state.done:
		for child in combat.hud.get_children():
			if child is ConfirmationDialog and not child.is_queued_for_deletion(): child.canceled.emit()
	GameManager.test_mode = true
	c.feature_uses.erase("bardic_inspiration_die")
	CombatAction.remove_condition_source(c, "fixture:no_roll", ["paralyzed"])
	Dice.dice_rolled.disconnect(capture)

static func ambush(h: Node) -> void:
	h._setup_world()
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var rogue := h._fresh_char("Camp watch", "human", "rogue", {"DEX":50, "CON":14}) as Character
	rogue.skill_proficiencies.assign(["Stealth", "Acrobatics"])
	rogue.feature_choices["rogue_expertise"] = ["Stealth", "Acrobatics"]
	rogue.exhaustion_level = 2
	var wizard: Character = PlayerManager.get_player(1).character
	PlayerManager.set_player_character(0, rogue)
	PartyManager.reset()
	PartyManager.register_player_character(0, rogue); PartyManager.register_player_character(1, wizard)
	var world: OverworldState = await h._spawn_scene("res://scenes/overworld.tscn", 0.2)
	var events: Array = []
	var capture := func(r: Dictionary):
		if r.get("sides") == 20: events.append(r.duplicate(true))
	Dice.dice_rolled.connect(capture)
	world._execute_rest_command(PlayerCommand.rest("long_rest"))
	Dice.dice_rolled.disconnect(capture)
	var natural := int(events.back().total) if not events.is_empty() else -100
	var mod := rogue.get_skill_check_modifier("Stealth", "DEX")
	h._assert(world._party_best_stealth_character() == rogue and world._party_best_stealth_mod() == mod and world.hud.log_text.text.contains("(rolled %d + %d)" % [natural, mod]), "S248 production rest ambush uses the same proficient/expert/Exhaustion modifier as the selected watcher's check")
	h._teardown_scene(world)

static func checkpoint(h: Node) -> void:
	h._setup_world()
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id":"ruins_of_ashvale"}
	var c: Character = PlayerManager.get_player(0).character
	c.current_hp = maxi(1, c.current_hp); c.is_alive = true
	c.inventory.equip(Inventory.Slot.WEAPON, "longsword", true)
	var dropped_id := c.inventory.equipped_instance_id(Inventory.Slot.WEAPON)
	c.add_condition("prone", 100, "fixture:checkpoint_prone")
	c.add_condition("unconscious", 100, "fixture:checkpoint_sleep")
	var dungeon: DungeonState = await h._spawn_scene("res://scenes/dungeon.tscn", 0.2)
	dungeon._enter_local_room("1")
	var view: LocalRoomView = dungeon.local_view
	if view == null: h._assert(false, "S235 authored room owner attaches"); h._teardown_scene(dungeon); return
	h._assert(c.inventory.equipped_instance_id(Inventory.Slot.WEAPON).is_empty() and room_has_copy(view.state, dropped_id), "S235 entering actual room asleep drops the exact held copy into durable ground")
	h._assert(not SaveManager.save_game("condition_recovery_forbidden"), "S235 active-room save remains refused at the existing checkpoint boundary")
	var wizard: Character = PlayerManager.get_player(1).character
	view.actors.select(1)
	for condition in ["stunned", "incapacitated"]:
		var grant := SpellEffects.begin_cast(wizard, DataLoader.get_spell("bless"))
		wizard.concentrating_on = {"spell_id":"bless", "effect_source":grant.source_id, "targets":[c]}
		SpellEffects.grant(c, grant, "blessed")
		wizard.add_condition(condition, 100, "fixture:room_stop")
		h._assert(wizard.concentrating_on.is_empty() and not c.has_condition("blessed"), "S235 actual room owner immediately cleans incapacitated source recipients: " + condition)
		var origin := LocalRoomRules.coord(view.state.party_positions[wizard.character_id])
		var destination := origin
		for candidate in HexUtils.get_neighbors(origin):
			if LocalRoomRules.passable(view.state, candidate) and LocalRoomRules.object_at(view.state, candidate).is_empty() and candidate != LocalRoomRules.coord(view.state.party_positions[c.character_id]): destination = candidate; break
		view.click(destination)
		h._assert(destination != origin and LocalRoomRules.coord(view.state.party_positions[wizard.character_id]) == destination, "S235 actual room click preserves generic incapacitated movement: " + condition)
		CombatAction.remove_condition_source(wizard, "fixture:room_stop", [condition])
	view.state.party_positions[wizard.character_id] = view.state.exits[0].duplicate()
	dungeon._leave_local_room()
	dungeon._save_dungeon_state_to_manager()
	var expected := FileAccess.open("user://condition_recovery_expected.json", FileAccess.WRITE)
	expected.store_string(JSON.stringify({"dropped_id":dropped_id}))
	h._assert(SaveManager.save_game("condition_recovery"), "S235 allowed entrance checkpoint preserves exact dropped gear, sleep and independent Prone")
	h._teardown_scene(dungeon)

static func room_has_copy(room: Dictionary, id: String) -> bool:
	for object in room.get("objects", []):
		for copy in object.get("contents", []):
			if copy.get("instance_id") == id: return true
	return false

static func reload(h: Node) -> void:
	h._enter_test("condition_recovery_reload")
	h._assert(SaveManager.load_game("condition_recovery"), "S235 fresh-process condition checkpoint loads")
	var c: Character = PlayerManager.get_player(0).character
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://condition_recovery_expected.json"))
	var found := false
	for room in GameManager.active_dungeon_state.get("local_rooms", {}).values():
		found = found or room_has_copy(room, str(expected.dropped_id))
	h._assert(found and c.inventory.equipped_instance_id(Inventory.Slot.WEAPON).is_empty() and c.inventory.get_instance(str(expected.dropped_id)).is_empty(), "S235 fresh process restores the exact ground copy once, outside the actor's inventory")
	h._assert(c.has_condition("unconscious") and c.has_condition("prone") and not c.condition_consequence_handler.is_valid(), "S235 fresh process restores source state without persisting live scene owner")
	c.heal(1)
	CombatAction.remove_condition_source(c, "fixture:checkpoint_sleep", ["unconscious"])
	h._assert(not c.has_condition("unconscious") and c.has_condition("prone") and c.condition_sources.get("prone", {}).has("fixture:checkpoint_prone"), "S235 recovered source-exact ending preserves independent Prone")
	h._exit_test()
