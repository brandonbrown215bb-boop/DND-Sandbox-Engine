class_name OrdinaryActionFlow
extends RefCounted

static func choose(h: Node, combat: CombatState, action: String) -> void:
	combat.hud.ordinary_actions_button.pressed.emit()
	var menu: PopupMenu = combat.hud.get_node_or_null("OrdinaryActionsMenu")
	h._assert(menu != null and menu.visible, "S237 actual Actions button opens chooser")
	if menu != null:
		menu.id_pressed.emit(OrdinaryActionRules.ACTIONS.find(action))
		menu.hide()
	await h.get_tree().process_frame


static func run(h: Node) -> void:
	h._enter_test("ordinary_action_flow")
	h._setup_mixed_world()
	DataLoader._load_json_file("res://data/fixtures/ordinary_actions/class.json", "class")
	DataLoader._load_json_file("res://data/fixtures/ordinary_actions/spells.json", "spell")
	var combat: CombatState = await h._spawn_scene("res://scenes/combat.tscn", 0.5)
	var actor: Character = combat.player_entities[0].character
	var ally: Character = combat.player_entities[1].character
	var enemy: Dictionary = combat.monster_entities[0]
	for i in combat.player_entities.size(): combat.player_entities[i].hex_position = Vector2i(-i, 0)
	actor.conditions.clear(); actor.condition_sources.clear(); actor.exhaustion_level = 0
	enemy.hex_position = Vector2i(1, 0); enemy.current_hp = 10000; enemy.max_hp = 10000; enemy.armor_class = -100
	enemy.erase("senses"); enemy.erase("darkvision_range_feet")
	h._p_focus(combat, actor)
	combat._update_grid_entities()
	combat._reset_turn_action_economy()
	combat.remaining_speed = 2.0
	var speed := combat._active_movement_speed_hexes()
	await choose(h, combat, "dash")
	h._assert(is_equal_approx(combat.remaining_speed, 2.0 + speed) and not combat.turn_budget.can_spend("action") and combat.turn_budget.can_spend("bonus_action"), "S237 ordinary Dash adds current Speed after partial movement and spends only Action")
	await combat._on_hud_action("ordinary_action", {"action":"dash", "action_cost":"free"})
	h._assert(is_equal_approx(combat.remaining_speed, 2.0 + speed), "S237 repeated/forged ordinary Dash cannot grant free movement")
	h._p_focus(combat, actor)
	await choose(h, combat, "disengage")
	h._assert(actor.has_condition("disengaging") and not combat.turn_budget.can_spend("action"), "S237 ordinary Disengage uses existing Opportunity Attack exclusion")
	actor.tick_conditions()
	h._assert(not actor.has_condition("disengaging"), "S237 Disengage ends this turn")
	h._p_focus(combat, actor)
	combat.hud.btn_dodge.pressed.emit()
	actor.tick_conditions()
	h._assert(CombatAction.dodge_active(actor), "S237 existing Dodge button keeps protection after own end-turn")
	h._assert(actor.make_saving_throw_result("DEX").roll_mode == "advantage" and actor.make_saving_throw_result("CON").roll_mode == "normal", "S237 Dodge grants Advantage only to DEX saves at central Character owner")
	var visibility := CombatPerception.attack_visibility(enemy, actor, 5, CombatPerception.weapon_decisions(combat.hex_grid, enemy, actor))
	h._assert(CombatAction.attack_target_imposes_disadvantage(actor, 1, visibility.target_sees_attacker), "S237 Dodge works against a seen attacker")
	CombatAction.apply_condition(enemy, "invisible", 100)
	visibility = CombatPerception.attack_visibility(enemy, actor, 5, CombatPerception.weapon_decisions(combat.hex_grid, enemy, actor))
	h._assert(not CombatAction.attack_target_imposes_disadvantage(actor, 1, visibility.target_sees_attacker), "S237 Dodge does not penalize an unseen attacker")
	enemy.conditions.erase("invisible")
	OrdinaryActionRules.start_turn(actor, combat.monster_entities)
	h._assert(not actor.has_condition("dodging"), "S237 Dodge ends at start of next owner turn")
	for condition in ["stunned", "grappled", "restrained"]:
		actor.add_condition("dodging", 2)
		actor.add_condition(condition, 100, "fixture:disable")
		CombatAction.remove_condition_source(actor, "fixture:disable", [condition])
		h._assert(not CombatAction.dodge_active(actor), "S237 Dodge cannot resume after disabling condition is removed: " + condition)
	actor.add_condition("dodging", 2); actor.speed = 0
	h._assert(not CombatAction.dodge_active(actor), "S237 numeric Speed 0 ends Dodge")
	actor.speed = 6
	actor.add_condition("dodging", 2)
	actor.add_modifier("stat", "speed", -6, 1)
	actor.tick_modifiers()
	h._assert(not CombatAction.dodge_active(actor), "S237 expiring numeric Speed 0 cannot restore Dodge")
	CombatAction.apply_condition(enemy, "dodging", 2)
	h._assert(BarbarianRules.roll_monster_save_result(enemy, "DEX").roll_mode == "advantage", "S237 generic monster save receives Dodge DEX Advantage")
	CombatAction.apply_condition(enemy, "grappled", 100, "fixture:snare")
	CombatAction.remove_condition_source(enemy, "fixture:snare", ["grappled"])
	h._assert(not CombatAction.dodge_active(enemy), "S237 monster Dodge does not resume after escape")
	await hide_routes(h, combat, actor, enemy)
	await spell_endings(h, combat, enemy)
	await help_routes(h, combat, actor, ally, enemy)
	await check_help_routes(h, combat, actor, ally)
	h._teardown_scene(combat)
	h._assert(not actor.has_condition("dodging") and not actor.has_condition("disengaging") and actor.combat_hide_dc == 0, "S237 encounter teardown clears ordinary transient state")
	h._exit_test()


static func hide_routes(h: Node, combat: CombatState, actor: Character, enemy: Dictionary) -> void:
	h._p_focus(combat, actor)
	await choose(h, combat, "hide")
	h._assert(combat.turn_budget.can_spend("action") and not actor.has_condition("hidden"), "S237 visible Hide refuses before Action or roll")
	var feature: Dictionary = DataLoader.get_character_class("fixture:ordinary_actions").features_by_level["1"][0].duplicate(true)
	actor.features.append(feature)
	actor.feature_uses[feature.id] = 1
	var movement_before := combat.remaining_speed
	h._assert(h._p_select(combat, str(feature.id)), "S237 renamed loaded feature is offered through actual feature menu")
	await h.get_tree().process_frame
	h._assert(not combat.turn_budget.can_spend("bonus_action") and combat.remaining_speed > movement_before, "S237 renamed feature menu offers ordinary movement without feature-ID dispatch")
	h._p_focus(combat, actor)
	actor.feature_uses[feature.id] = 1
	var selected := feature.duplicate(true); selected.selected_action = "hide"
	await combat._on_hud_action("use_feature", {"feature":selected})
	h._assert(combat.turn_budget.can_spend("bonus_action"), "S237 renamed loaded bonus Hide uses same legality gate before cost")
	combat.hex_grid.obscurement_sources["fixture:fog"] = {"kind":"fog", "coords":[Vector2i.ZERO]}
	actor.ability_scores.dexterity = 50
	# A seeded check still uses the production modifier and proficiency owners.
	FighterChecks._seed_die(20, 20)
	await choose(h, combat, "hide")
	h._assert(actor.has_condition("hidden") and CombatAction.is_invisible(actor) and actor.combat_hide_dc >= 15 and not combat.turn_budget.can_spend("action"), "S237 concealed ordinary Hide grants Invisible and captures discovery DC")
	actor.tick_conditions()
	h._assert(actor.has_condition("hidden"), "S237 successful Hide survives own end-turn")
	OrdinaryActionRules.remove_hidden(actor)
	combat.hex_grid.obscurement_sources["fixture:fog"] = {"kind":"fog", "coords":[Vector2i.ZERO]}
	h._p_focus(combat, actor)
	FighterChecks._seed_die(20, 20)
	await combat._on_hud_action("use_feature", {"feature":selected})
	h._assert(actor.has_condition("hidden") and combat.turn_budget.can_spend("action") and not combat.turn_budget.can_spend("bonus_action"), "S237 renamed loaded feature shares Hide effect at its declared Bonus Action cost")
	combat.hex_grid.obscurement_sources.clear()
	h._p_focus(combat, actor)
	await choose(h, combat, "hide")
	h._assert(combat.turn_budget.can_spend("action"), "S237 existing Hidden does not make visible re-Hide legal")
	CombatAction.reveal_hidden_attacker(actor)
	h._assert(not actor.has_condition("hidden") and actor.combat_hide_dc == 0, "S237 making an attack ends Hide and its captured DC")
	# A neutral renamed monster can use the same check/effect; Search reads its actual DC.
	combat.hex_grid.obscurement_sources["fixture:fog"] = {"kind":"fog", "coords":[enemy.hex_position]}
	enemy["skill_bonuses"] = {"Stealth":0}
	FighterChecks._seed_die(20, 20)
	OrdinaryActionRules.hide(enemy, combat._ability_check_context(enemy))
	actor.ability_scores.wisdom = 80
	h._p_focus(combat, actor)
	await choose(h, combat, "search")
	h._assert(not CombatAction.has_condition(enemy, "hidden") and not combat.turn_budget.can_spend("action"), "S237 actual Search finds Hidden using recorded Perception DC and ends its Hide")
	combat.hex_grid.obscurement_sources.clear()
	actor.features.erase(feature)
	actor.feature_uses.erase(feature.id)


static func spell_endings(h: Node, combat: CombatState, enemy: Dictionary) -> void:
	var caster: Character = combat.player_entities[2].character
	combat.player_entities[2].hex_position = Vector2i(0, 1)
	caster.ability_scores.dexterity = 50
	caster.known_spells.assign(["fixture:quiet_repair", "fixture:spoken_repair"])
	h._own_class_spells(caster)
	h._ready_spell_components(caster)
	h._p_focus(combat, caster)
	FighterChecks._seed_die(20, 20)
	OrdinaryActionRules.hide(caster, combat._ability_check_context(caster))
	caster.current_hp = caster.max_hp - 2
	var hp := caster.current_hp
	await h._cast_menu_spell(combat, "fixture:quiet_repair")
	await combat._on_hex_clicked(Vector2i(0, 1))
	h._assert(caster.current_hp == hp + 1 and caster.has_condition("hidden") and not combat.turn_budget.can_spend("action"), "S237 actual permissioned non-Verbal nonattack cast retains Hide")
	caster.add_condition("starry_wisp", 100)
	h._assert(not CombatAction.is_invisible(caster) and CombatPerception.can_see_target(enemy, caster, enemy.hex_position, Vector2i(0, 1), combat.hex_grid), "S237 glowing Hidden target loses Invisible benefits for actual sight query")
	caster.remove_condition("starry_wisp")
	caster.add_condition("invisible", 100, "fixture:independent_cloak")
	h._p_focus(combat, caster)
	await h._cast_menu_spell(combat, "fixture:spoken_repair")
	await combat._on_hex_clicked(Vector2i(0, 1))
	h._assert(caster.current_hp == hp + 2 and not caster.has_condition("hidden") and caster.combat_hide_dc == 0 and caster.condition_sources.get("invisible", {}).has("fixture:independent_cloak"), "S237 actual Verbal cast ends only Hide and preserves independent Invisibility")
	caster.remove_condition("invisible")


static func help_routes(h: Node, combat: CombatState, actor: Character, ally: Character, enemy: Dictionary) -> void:
	h._p_focus(combat, actor)
	await choose(h, combat, "help_attack")
	await combat._on_hud_action("cancel", {})
	h._assert(combat.turn_budget.can_spend("action") and not enemy.has("familiar_helped_by"), "S237 cancelled Help has no cost or benefit")
	await choose(h, combat, "help_attack")
	combat.turn_budget.spend("action")
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(not enemy.has("familiar_helped_by"), "S237 stale Help selection cannot grant benefit after Action is gone")
	h._p_focus(combat, actor)
	await choose(h, combat, "help_attack")
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(not combat.turn_budget.can_spend("action") and str(enemy.get("familiar_helped_by", "")) == actor.character_id, "S237 actual Help target click pays once for exact enemy")
	h._assert(not CombatAction.consume_attack_help(enemy, actor) and enemy.has("familiar_helped_by"), "S237 helper cannot consume own Help")
	h._assert(CombatAction.consume_attack_help(enemy, ally) and not CombatAction.consume_attack_help(enemy, ally), "S237 ally consumes Help only once")
	h._p_focus(combat, actor)
	await choose(h, combat, "help_attack")
	await combat._on_hex_clicked(enemy.hex_position)
	OrdinaryActionRules.start_turn(actor, combat.monster_entities)
	h._assert(not enemy.has("familiar_helped_by"), "S237 unused Help expires at helper's next turn start")
	ally.current_hp = 0; ally.is_alive = true; ally.is_stable = false
	h._p_focus(combat, actor)
	await choose(h, combat, "stabilize")
	FighterChecks._seed_die(20, 20)
	await combat._on_hex_clicked(combat.player_entities[1].hex_position)
	h._assert(ally.is_stable and ally.current_hp == 0 and not combat.turn_budget.can_spend("action"), "S237 actual Help Medicine stabilizes adjacent dying ally without healing")


static func check_help_routes(h: Node, combat: CombatState, helper: Character, recipient: Character) -> void:
	recipient.heal(recipient.max_hp)
	helper.skill_proficiencies.assign(["Athletics"])
	helper.tool_proficiencies.assign(["Thieves' Tools"])
	h._p_focus(combat, helper)
	await combat._on_hud_action("ordinary_action", {"action":"help_check", "proficiency_kind":"skill", "proficiency":"Arcana"})
	h._assert(combat.turn_budget.can_spend("action") and recipient.combat_check_help.is_empty(), "S237 unowned Help proficiency refuses before targeting or cost")
	combat.hud.ordinary_actions_button.pressed.emit()
	var menu: PopupMenu = combat.hud.get_node("OrdinaryActionsMenu")
	menu.id_pressed.emit(OrdinaryActionRules.ACTIONS.find("help_check")); menu.hide()
	var picked := false
	for _frame in 120:
		await h.get_tree().process_frame
		for child in combat.hud.get_children():
			if not child is PopupMenu or not child.visible or not str(child.title).begins_with("Help:"): continue
			for index in child.item_count:
				if child.get_item_text(index) == "Athletics (skill)":
					child.id_pressed.emit(child.get_item_id(index)); child.hide(); picked = true; break
		if picked: break
	await h.get_tree().process_frame
	await combat._on_hex_clicked(combat.player_entities[1].hex_position)
	h._assert(picked and not combat.turn_budget.can_spend("action") and recipient.combat_check_help.size() == 1, "S237 actual Help proficiency chooser and exact ally click grant next-check assistance once")
	var unrelated := EventResolver.resolve_skill_check(recipient, {"ability":"DEX", "skill":"Acrobatics", "dc":10}, {}, combat._ability_check_context(recipient))
	h._assert(unrelated.ordinary_help_sources.is_empty() and recipient.combat_check_help.size() == 1, "S237 unrelated ability check cannot consume selected proficiency Help")
	var check := EventResolver.resolve_skill_check(recipient, {"ability":"STR", "skill":"Athletics", "dc":10}, {}, combat._ability_check_context(recipient))
	h._assert(check.advantage and check.ordinary_help_sources.size() == 1 and recipient.combat_check_help.is_empty(), "S237 actual shared proficient check consumes exact Help source and grants Advantage")
	var repeated := EventResolver.resolve_skill_check(recipient, {"ability":"STR", "skill":"Athletics", "dc":10}, {}, combat._ability_check_context(recipient))
	h._assert(not repeated.advantage and repeated.ordinary_help_sources.is_empty(), "S237 a later matching check cannot reuse spent Help")
	h._p_focus(combat, helper)
	await combat._on_hud_action("ordinary_action", {"action":"help_check", "proficiency_kind":"tool", "proficiency":"Thieves' Tools"})
	await combat._on_hex_clicked(combat.player_entities[1].hex_position)
	check = EventResolver.resolve_skill_check(recipient, {"ability":"DEX", "skill":"Sleight of Hand", "tool_id":"thieves_tools", "dc":10}, {}, combat._ability_check_context(recipient))
	h._assert(check.advantage and check.ordinary_help_sources.size() == 1, "S237 tool Help matches the actual tool check rather than becoming general Advantage")
	h._p_focus(combat, helper)
	await combat._on_hud_action("ordinary_action", {"action":"help_check", "proficiency_kind":"skill", "proficiency":"Athletics"})
	await combat._on_hex_clicked(combat.player_entities[1].hex_position)
	recipient.add_condition("poisoned", 100)
	check = EventResolver.resolve_skill_check(recipient, {"ability":"STR", "skill":"Athletics", "dc":10}, {}, combat._ability_check_context(recipient))
	h._assert(check.rolls.size() == 1 and check.ordinary_help_sources.size() == 1, "S237 Help Advantage composes with Poisoned Disadvantage on one captured check")
	recipient.remove_condition("poisoned")
	h._p_focus(combat, helper)
	await combat._on_hud_action("ordinary_action", {"action":"help_check", "proficiency_kind":"skill", "proficiency":"Athletics"})
	await combat._on_hex_clicked(combat.player_entities[1].hex_position)
	await h._start_class_fixture_turn(combat, helper)
	h._assert(recipient.combat_check_help.is_empty(), "S237 actual helper turn start expires unused exact-proficiency assistance")
