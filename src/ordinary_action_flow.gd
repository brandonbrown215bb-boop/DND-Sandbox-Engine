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


static func resolve_search_choice(h: Node, combat: CombatState, selected_id: int) -> bool:
	await choose(h, combat, "search")
	for _frame in 120:
		await h.get_tree().process_frame
		for child in combat.hud.get_children():
			if not child is PopupMenu or not child.visible or child.title != "Search: choose an approach": continue
			if selected_id < 0:
				child.hide()
				await h.get_tree().process_frame
				return true
			for index in child.item_count:
				if child.get_item_id(index) == selected_id:
					child.id_pressed.emit(child.get_item_id(index))
					child.hide()
					await h.get_tree().process_frame
					return true
	return false


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
	await spell_noise(h, combat)
	await help_routes(h, combat, actor, ally, enemy)
	await check_help_routes(h, combat, actor, ally)
	await cover_routes(h, combat, actor, enemy)
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
	var cancelled_search_choice := await resolve_search_choice(h, combat, -1)
	h._assert(cancelled_search_choice and combat.turn_budget.can_spend("action") and CombatAction.has_condition(enemy, "hidden"), "S237 cancelling the Search approach chooser preserves the Action and Hidden target")
	var search_choice_made := await resolve_search_choice(h, combat, 1)
	h._assert(search_choice_made and not CombatAction.has_condition(enemy, "hidden") and not combat.turn_budget.can_spend("action"), "S237 actual Search finds Hidden using recorded Perception DC and ends its Hide")
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


static func spell_noise(h: Node, combat: CombatState) -> void:
	var caster: Character = combat.player_entities[2].character
	var listener: Character = combat.player_entities[0].character
	var position: Vector2i = combat.player_entities[2].hex_position
	caster.known_spells.assign(["fixture:resonant_repair", "fixture:whisper_repair", "fixture:empty_boom", "fixture:resonant_bolt", "fixture:target_resonance"])
	h._own_class_spells(caster)
	caster.current_hp = caster.max_hp - 6
	caster.spell_slots["1"] = 4
	# Componentless, non-attack effects still have their declared sound.
	h._p_focus(combat, caster)
	OrdinaryActionRules.hide(caster, combat._ability_check_context(caster))
	caster.add_condition("invisible", 100, "fixture:effect_noise_cloak")
	var hp := caster.current_hp
	await h._cast_menu_spell(combat, "fixture:resonant_repair", 1)
	await combat._on_hex_clicked(position)
	h._assert(caster.current_hp == hp + 2 and caster.spell_slots["1"] == 3 and not caster.has_condition("hidden") and not combat.turn_budget.can_spend("action"), "S237 loaded componentless ordered effect emits loud sound after real effects and once-only slot/Action payment without Ready")
	h._assert(caster.condition_sources.get("invisible", {}).has("fixture:effect_noise_cloak"), "S237 loud effect sound preserves independent condition Invisibility")
	caster.remove_condition("invisible")
	# The sound actor stays the caster for Ready matching, while its source and
	# location are the exact selected ally. A remote boom leaves caster Hide alone.
	var target: Character = combat.player_entities[1].character
	var target_position: Vector2i = combat.player_entities[1].hex_position
	var owning_sound_receipts := combat.ready_actions.receipts.size()
	await ReadyActionFlow.declare(h, combat, listener, {"kind":"ordinary", "action":"dodge"}, {"event":"sound", "side":"ally", "actor_id":caster.character_id, "at_hex":[target_position.x, target_position.y]})
	h._p_focus(combat, caster)
	OrdinaryActionRules.hide(caster, combat._ability_check_context(caster))
	target.current_hp = target.max_hp - 2
	var sound_target_hp := target.current_hp
	caster.spell_slots["1"] = 3
	await ReadyActionFlow.answer(h, combat, func():
		await h._cast_menu_spell(combat, "fixture:target_resonance", 1)
		await combat._on_hex_clicked(target_position), null)
	h._assert(target.current_hp == sound_target_hp + 1 and caster.spell_slots["1"] == 2, "OA02 ordinary shared cast resolves and pays once against its selected target")
	h._assert(caster.has_condition("hidden"), "OA02 remote target-origin boom keeps the caster Hidden")
	h._assert(not listener.reaction_available and combat.ready_actions.receipts.size() == owning_sound_receipts + 1, "OA02 target-origin sound triggers one location-matched owning Ready Reaction")
	target.add_condition("hidden", 100, "fixture:oa02_source_hidden")
	CombatNoiseRules.emit(combat, {"type":"sound", "actor":caster, "source":target, "source_kind":"creature", "source_plane":"material", "position":target_position, "noise":{"volume":"loud", "range_feet":5}})
	h._assert(not target.has_condition("hidden") and caster.has_condition("hidden"), "OA02 loud target-source sound ends that creature's Hide without ending the caster's Hide")
	# Source-origin hearing still observes the shared range, route, plane and
	# Deafened rules. Put source and listener at distinct spaces.
	var listener_position: Vector2i = combat.player_entities[0].hex_position
	var exact_noise := {"volume":"loud", "range_feet":5}
	h._assert(CombatNoiseRules.can_hear(listener, listener_position, target_position, combat.hex_grid, exact_noise, target), "OA02 target-origin sound reaches a distinct adjacent listener at its inclusive range")
	h._assert(not CombatNoiseRules.can_hear(listener, listener_position, target_position, combat.hex_grid, {"volume":"loud", "range_feet":4}, target), "OA02 target-origin sound respects authored range")
	var saved_sound_blocks := {}
	for tile_position in combat.hex_grid.tiles:
		var props: Dictionary = combat.hex_grid.get_tile(tile_position).custom_properties
		saved_sound_blocks[tile_position] = {"had":props.has("blocks_sound"), "value":props.get("blocks_sound", false)}
		props["blocks_sound"] = tile_position != target_position
	h._assert(not CombatNoiseRules.can_hear(listener, listener_position, target_position, combat.hex_grid, exact_noise, target), "OA02 target-origin sound respects a blocked route")
	for tile_position in saved_sound_blocks:
		var props: Dictionary = combat.hex_grid.get_tile(tile_position).custom_properties
		if saved_sound_blocks[tile_position].had: props["blocks_sound"] = saved_sound_blocks[tile_position].value
		else: props.erase("blocks_sound")
	listener.add_condition("deafened", 20, "fixture:oa02_deaf")
	h._assert(not CombatNoiseRules.can_hear(listener, listener_position, target_position, combat.hex_grid, exact_noise, target), "OA02 target-origin sound excludes a Deafened listener")
	CombatAction.remove_condition_source(listener, "fixture:oa02_deaf", ["deafened"])
	var prior_plane: Variant = target.feature_uses.get("plane", "material")
	target.feature_uses["plane"] = "ethereal"
	h._assert(not CombatNoiseRules.can_hear(listener, listener_position, target_position, combat.hex_grid, exact_noise, target), "OA02 target-origin sound does not cross planes")
	if prior_plane == "material": target.feature_uses.erase("plane")
	else: target.feature_uses["plane"] = prior_plane
	# A source that became stale during target selection refuses at the existing
	# pre-payment resource validator and leaves the slot/action untouched.
	var stale_spell := DataLoader.get_spell("fixture:target_resonance")
	var stale_cast := combat._spell_cast_context(target_position, Vector2i(9999, 9999), [], [], caster, stale_spell)
	h._assert(SpellCastResources.revalidate_selection(stale_cast), "OA02 exact target source is captured by ordinary pre-payment revalidation")
	combat.player_entities[1].hex_position = Vector2i(-1, 1)
	var stale_slot := int(caster.spell_slots["1"])
	var stale_action := combat.turn_budget.can_spend("action")
	h._assert(not SpellCastResources.revalidate_selection(stale_cast) and int(caster.spell_slots["1"]) == stale_slot and combat.turn_budget.can_spend("action") == stale_action, "OA02 moved selected target is refused before spell payment")
	combat.player_entities[1].hex_position = target_position
	combat._update_grid_entities()
	# The same source capture accepts an exact eligible object and refuses a
	# replacement with the same authored key. Object sound can leave a blocked
	# source tile, as a Knock-like door sound must.
	var object_position := Vector2i.ZERO
	for neighbor in HexUtils.get_neighbors(listener_position):
		if not combat.hex_grid.has_tile(neighbor): continue
		var occupied := false
		for participant in combat.player_entities + combat.monster_entities:
			if participant.get("hex_position", Vector2i.ZERO) == neighbor: occupied = true
		if not occupied:
			object_position = neighbor
			break
	var source_object := {"id":"oa02_source_object", "name":"Source object", "kind":"container", "hp":10, "max_hp":10, "removed":false, "position":[object_position.x, object_position.y], "plane":"material"}
	var object_entity := {"hex_position":object_position, "world_object":source_object}
	combat.hex_grid.entities.append(object_entity)
	var object_spell := DataLoader.get_spell("fixture:target_resonance").duplicate(true)
	object_spell["target"] = "single"
	object_spell["targets_objects"] = true
	var object_cast := combat._spell_cast_context(object_position, Vector2i(9999, 9999), [], [], caster, object_spell)
	var object_slot := int(caster.spell_slots["1"])
	h._assert(SpellCastResources.revalidate_selection(object_cast) and object_cast.effect_noise_source_kind == "object" and object_cast.effect_noise_source_id == "oa02_source_object", "OA02 exact selected object is captured through the ordinary pre-payment validator")
	object_entity["world_object"] = source_object.duplicate(true)
	h._assert(not SpellCastResources.revalidate_selection(object_cast) and int(caster.spell_slots["1"]) == object_slot, "OA02 replaced selected object is refused before spell payment")
	combat.hex_grid.entities.erase(object_entity)
	var monster_source: Dictionary = combat.monster_entities[0]
	var old_conditions: Dictionary = monster_source.get("conditions", {}).duplicate(true)
	var old_condition_sources: Dictionary = monster_source.get("condition_sources", {}).duplicate(true)
	monster_source["conditions"] = {"hidden":100}
	monster_source["condition_sources"] = {"hidden":["fixture:oa02_hidden"]}
	var monster_event := {"type":"sound", "actor":caster, "source":monster_source, "source_kind":"creature", "source_plane":"material", "position":monster_source.hex_position, "noise":{"volume":"loud", "range_feet":300}}
	CombatNoiseRules.emit(combat, monster_event)
	var monster_location: Dictionary = combat.hex_grid.observer_locations.get(listener.character_id, {}).get(CombatAction.actor_id(monster_source), {})
	h._assert(not CombatAction.has_condition(monster_source, "hidden") and monster_event.heard_by.has(listener.character_id) and monster_location.get("position") == monster_source.hex_position, "OA02 loud target-origin sound ends a hidden monster source's Hide and records its location")
	monster_source["conditions"] = old_conditions
	monster_source["condition_sources"] = old_condition_sources
	OrdinaryActionRules.remove_hidden(caster)
	await ReadyActionFlow.declare(h, combat, listener, {"kind":"ordinary", "action":"dodge"}, {"event":"sound", "side":"ally", "actor_id":caster.character_id})
	h._p_focus(combat, caster)
	OrdinaryActionRules.hide(caster, combat._ability_check_context(caster))
	await h._cast_menu_spell(combat, "fixture:whisper_repair")
	await combat._on_hex_clicked(position)
	h._assert(caster.has_condition("hidden") and listener.reaction_available and not combat.turn_budget.can_spend("action"), "S237 whisper spell effect retains Hide and cannot trigger loud-sound Ready")
	h._p_focus(combat, caster)
	hp = caster.current_hp
	await h._cast_menu_spell(combat, "fixture:resonant_repair", 1)
	var receipts := combat.ready_actions.receipts.size()
	await ReadyActionFlow.answer(h, combat, func(): await combat._on_hex_clicked(position), null)
	h._assert(caster.current_hp == hp + 2 and not listener.reaction_available and combat.ready_actions.receipts.size() == receipts + 1 and not caster.has_condition("hidden"), "S237 ordered spell sound triggers exactly one actual owning Reaction after both effects")
	# Preparing/losing the held energy never emits its effect's sound.
	caster.spell_slots["1"] = 1
	h._p_focus(combat, caster)
	OrdinaryActionRules.hide(caster, combat._ability_check_context(caster))
	var options := SpellPermissionRules.payment_choices(caster, "fixture:resonant_repair")
	h._assert(not options.is_empty(), "S237 effect sound spell has an actual Ready source/payment choice")
	if options.is_empty(): return
	await ReadyActionFlow.declare(h, combat, caster, {"kind":"spell", "spell":options[0]}, {"event":"action", "side":"ally", "actor_id":listener.character_id})
	h._assert(caster.has_condition("hidden") and caster.spell_slots["1"] == 0, "S237 Ready pays last slot now but a held componentless spell emits no effect sound")
	h._p_focus(combat, listener)
	await ReadyActionFlow.answer(h, combat, func(): await combat._on_hud_action("ordinary_action", {"action":"dash"}), position)
	h._assert(not caster.has_condition("hidden") and caster.spell_slots["1"] == 0 and not caster.reaction_available, "S237 actual held release emits effect sound and ends Hide without paying the last slot again")
	# An empty effect area is still a completed paid cast with its actual boom.
	caster.spell_slots["1"] = 2
	await ReadyActionFlow.declare(h, combat, listener, {"kind":"ordinary", "action":"dodge"}, {"event":"sound", "side":"ally", "actor_id":caster.character_id})
	h._p_focus(combat, caster)
	OrdinaryActionRules.hide(caster, combat._ability_check_context(caster))
	await h._cast_menu_spell(combat, "fixture:empty_boom", 1)
	await ReadyActionFlow.answer(h, combat, func(): await combat._on_hex_clicked(Vector2i(0, 5)), null)
	h._assert(not caster.has_condition("hidden") and caster.spell_slots["1"] == 1 and not listener.reaction_available and not combat.turn_budget.can_spend("action"), "S237 paid empty-area spell still emits its declared sound and triggers Ready")
	# OA-13 target-origin monster sound uses the actual target as source while
	# retaining the monster as the cast/Ready actor.
	var monster: Dictionary = combat.monster_entities[0]
	var monster_position: Vector2i = monster.get("hex_position", Vector2i.ZERO)
	var old_spells: Variant = monster.get("spells", []).duplicate(true)
	var old_slots: Dictionary = monster.get("spell_slots", {}).duplicate(true)
	monster.hex_position = Vector2i(3, 0)
	combat._update_grid_entities()
	listener.current_hp = listener.max_hp
	monster.spells = [{"id":"fixture:monster_target_resonance"}]
	monster.spell_slots = {"1":1}
	CombatAction.apply_condition(monster, "hidden", 120, "fixture:monster_target_origin_hidden")
	listener.add_condition("hidden", 120, "fixture:monster_target_origin_hidden")
	CombatPerception.reveal_location(monster, listener, combat.player_entities[0].hex_position, combat.hex_grid)
	listener.reaction_available = true
	var target_hp := listener.current_hp
	var target_slot_before := int(monster.spell_slots["1"])
	var target_events_before := int(combat.action_history._event_serial)
	var target_receipts_before := combat.ready_actions.receipts.size()
	h._assert(AICommand.new("cast_spell", {"target_id":listener.character_name, "spell_id":"fixture:monster_target_resonance"}).is_valid(monster, combat.player_entities, combat.hex_grid, combat._all_live_combat_entities()), "OA13 target-origin sound declaration reaches the existing valid monster intent")
	await ReadyActionFlow.declare(h, combat, listener, {"kind":"ordinary", "action":"dodge"}, {"event":"sound", "side":"enemy", "actor_id":str(monster.id)})
	await ReadyActionFlow.answer(h, combat, func(): await combat._execute_monster_spell(monster, listener.character_name, "fixture:monster_target_resonance"), null)
	h._assert(monster.spell_slots["1"] == target_slot_before - 1 and listener.current_hp == target_hp and int(combat.action_history._event_serial) > target_events_before, "OA13 target-origin monster cast pays one slot, records the Action and completes its declared sound producer")
	h._assert(not listener.has_condition("hidden"), "OA13 loud target-origin monster sound ends the exact selected target's Hide")
	h._assert(monster.conditions.has("hidden"), "OA13 target-origin sound does not end the casting monster's Hide")
	h._assert(not listener.reaction_available and combat.ready_actions.receipts.size() == target_receipts_before + 1, "OA13 target-origin monster sound reaches the owning Ready Reaction exactly once")
	CombatAction.remove_condition_source(monster, "fixture:monster_target_origin_hidden", ["hidden"])
	listener.remove_condition("hidden")
	# A renamed caster-origin shared spell runs through the existing AI intent,
	# monster slot owner, shared resolver, completion and sound Ready owner.
	monster.hex_position = Vector2i(3, 0)
	monster.spells = [{"id":"fixture:monster_resonance"}]
	monster.spell_slots = {"1":1}
	var tally: Character = combat.player_entities[1].character
	tally.add_condition("deafened", 20, "fixture:oa03_deafened")
	tally.reaction_available = true
	var ally_plane: Variant = tally.feature_uses.get("plane", "material")
	tally.feature_uses["plane"] = "ethereal"
	listener.reaction_available = true
	var listener_hp_before := listener.current_hp
	var monster_slot_before := int(monster.spell_slots["1"])
	var monster_intent := AIController.get_monster_action(monster, monster.hex_position, combat.hex_grid, combat.player_entities, combat._all_live_combat_entities())
	h._assert(monster_intent.get("action") == "cast_spell" and monster_intent.get("spell_id") == "fixture:monster_resonance" and AICommand.from_decision(monster_intent, monster, combat.player_entities, combat.hex_grid, combat._all_live_combat_entities()) != null, "OA03 AI chooses the loaded renamed caster-origin monster spell through its real command validator")
	await ReadyActionFlow.declare(h, combat, tally, {"kind":"ordinary", "action":"dodge"}, {"event":"sound", "side":"enemy", "actor_id":str(monster.id)})
	await ReadyActionFlow.declare(h, combat, listener, {"kind":"ordinary", "action":"dodge"}, {"event":"sound", "side":"enemy", "actor_id":str(monster.id)})
	var player_budget_during := {"action":combat.turn_budget.action_available, "bonus":combat.turn_budget.bonus_action_available}
	var monster_events_before := int(combat.action_history._event_serial)
	var sound_receipts_before := combat.ready_actions.receipts.size()
	FighterChecks._seed_die(20, 1)
	await ReadyActionFlow.answer(h, combat, func(): await combat._execute_monster_spell(monster, listener.character_name, "fixture:monster_resonance"), null)
	var cast_fact := combat.action_history.fact(monster, "target.acted_since_combat_turn")
	h._assert(monster.spell_slots["1"] == monster_slot_before - 1 and listener.current_hp == listener_hp_before and bool(cast_fact.get("value", false)) and int(combat.action_history._event_serial) > monster_events_before and not listener.reaction_available and combat.ready_actions.receipts.size() == sound_receipts_before + 1, "OA03 real monster attack miss pays one slot, records one Action, emits once after completion and triggers one eligible sound Ready owner")
	h._assert(combat.turn_budget.action_available == player_budget_during.action and combat.turn_budget.bonus_action_available == player_budget_during.bonus and tally.reaction_available and combat.ready_actions.held.has(tally.character_id), "OA03 sound reaches only the eligible listener and leaves the Deafened/off-plane owner's Reaction and held Ready untouched")
	h._assert(CombatNoiseRules.can_hear(listener, combat.player_entities[0].hex_position, monster.hex_position, combat.hex_grid, {"volume":"loud", "range_feet":300}, monster, {}, PhysicalFactsRules.get_plane(monster, LocalRoomCombat.room())) and not CombatNoiseRules.can_hear(tally, combat.player_entities[1].hex_position, monster.hex_position, combat.hex_grid, {"volume":"loud", "range_feet":300}, monster, {}, PhysicalFactsRules.get_plane(monster, LocalRoomCombat.room())), "OA03 emitted caster-origin sound reaches the eligible listener but excludes Deafened and other-plane listeners")
	CombatAction.remove_condition_source(tally, "fixture:oa03_deafened", ["deafened"])
	combat.ready_actions.clear_owner(tally)
	if ally_plane == "material": tally.feature_uses.erase("plane")
	else: tally.feature_uses["plane"] = ally_plane
	monster.hex_position = monster_position
	combat._update_grid_entities()
	monster.spells = old_spells
	monster.spell_slots = old_slots
	# The bounded sphere completion host accepts only an actually empty footprint.
	var saved_area_spells: Array = monster.get("spells", []).duplicate(true)
	var saved_area_slots: Dictionary = monster.get("spell_slots", {}).duplicate(true)
	monster.spells = [{"id":"fixture:monster_empty_resonance"}]
	monster.spell_slots = {"1":1}
	var empty_center := Vector2i(9999, 9999)
	for candidate in combat.hex_grid.tiles.keys():
		if HexUtils.get_distance(monster.hex_position, candidate) > 12: continue
		var footprint := Targeting.get_sphere_targets(candidate, 1, combat.hex_grid)
		var occupied := false
		for participant in combat.player_entities + combat.monster_entities:
			var body = participant.get("character", participant)
			if OrdinaryActionRules._alive(body) and participant.get("hex_position", Vector2i.ZERO) in footprint: occupied = true
		if not occupied:
			empty_center = candidate
			break
	var area_intent := AICommand.from_decision({"action":"cast_area_spell", "spell_id":"fixture:monster_empty_resonance", "target_coord":empty_center}, monster, combat.player_entities, combat.hex_grid, combat._all_live_combat_entities())
	h._assert(empty_center != Vector2i(9999, 9999) and area_intent != null, "OA03 AI command validates a loaded shared empty-Sphere monster cast without recipient IDs")
	var occupied_slot_before := int(monster.spell_slots["1"])
	var occupied_area_serial := combat.action_history._event_serial
	await combat._execute_monster_area_spell(monster, combat.player_entities[0].hex_position, "fixture:monster_empty_resonance")
	h._assert(monster.spell_slots["1"] == occupied_slot_before and combat.action_history._event_serial == occupied_area_serial, "OA03 populated monster area intent is refused before slot payment or Action receipt")
	CombatAction.apply_condition(monster, "hidden", 100, "fixture:monster_hidden")
	monster["combat_hide_dc"] = 17
	listener.reaction_available = true
	var area_ready_receipts := combat.ready_actions.receipts.size()
	var area_slot_before := int(monster.spell_slots["1"])
	var area_events_before := combat.action_history._event_serial
	await ReadyActionFlow.declare(h, combat, listener, {"kind":"ordinary", "action":"dodge"}, {"event":"sound", "side":"enemy", "actor_id":str(monster.id)})
	await ReadyActionFlow.answer(h, combat, func(): await combat._execute_monster_area_spell(monster, empty_center, "fixture:monster_empty_resonance"), null)
	h._assert(monster.spell_slots["1"] == area_slot_before - 1 and combat.action_history._event_serial > area_events_before and not CombatAction.has_condition(monster, "hidden") and not monster.has("combat_hide_dc") and not listener.reaction_available and combat.ready_actions.receipts.size() == area_ready_receipts + 1, "OA03 actual empty monster Sphere pays once, completes once, ends caster Hide and delivers one caster-origin sound Ready Reaction")
	# Revalidation must reject a newly occupied area after an actual reaction window.
	SpellPermissionChecks.grant_slot_permission(tally, ["counterspell"])
	tally.spell_slots = {"3":1}
	tally.reaction_available = true
	monster.spell_slots = {"1":1}
	var mover := combat.player_entities[2]
	var mover_origin: Vector2i = mover.hex_position
	var area_action_serial := combat.action_history._event_serial
	var area_counter_state := {"done":false}
	GameManager.test_mode = false
	var begin_area_counter := func():
		await combat._execute_monster_area_spell(monster, empty_center, "fixture:monster_empty_resonance")
		area_counter_state["done"] = true
	begin_area_counter.call()
	var area_counter_prompt := false
	for _frame in 180:
		await h.get_tree().process_frame
		for dialog in combat.hud.get_children():
			if dialog is ConfirmationDialog and dialog.visible and str(dialog.dialog_text).contains("Force a Constitution save"):
				area_counter_prompt = true
				mover.hex_position = empty_center
				combat._update_grid_entities()
				dialog.canceled.emit()
		if area_counter_state.done: break
	GameManager.test_mode = true
	mover.hex_position = mover_origin
	combat._update_grid_entities()
	h._assert(area_counter_prompt and area_counter_state.done and monster.spell_slots["1"] == 1 and combat.action_history._event_serial == area_action_serial and tally.reaction_available, "OA03 occupied area after Counterspell window is stale-refused before slot, Action receipt, sound or reaction payment")
	monster.spells = saved_area_spells
	monster.spell_slots = saved_area_slots
	# A real Counterspell interrupts the declared effect sound, but the separate
	# Verbal casting event still reaches its own sound/Ready owner.
	var saved_counterspells: Array = monster.get("spells", []).duplicate(true)
	var saved_counter_slots: Dictionary = monster.get("spell_slots", {}).duplicate(true)
	monster.spells = [{"id":"fixture:monster_countered_verbal"}]
	monster.spell_slots = {"1":1}
	monster.saving_throw_bonuses = {"CON":-1000}
	SpellPermissionChecks.grant_slot_permission(tally, ["counterspell"])
	tally.spell_slots = {"3":1}
	tally.reaction_available = true
	listener.reaction_available = true
	var counter_target_hp := listener.current_hp
	var counter_slot_before := int(monster.spell_slots["1"])
	var counter_ready_receipts := combat.ready_actions.receipts.size()
	await ReadyActionFlow.declare(h, combat, listener, {"kind":"ordinary", "action":"dodge"}, {"event":"sound", "side":"enemy", "actor_id":str(monster.id)})
	var counter_cast_state := {"done":false}
	GameManager.test_mode = false
	var begin_counter_cast := func():
		await combat._execute_monster_spell(monster, listener.character_name, "fixture:monster_countered_verbal")
		counter_cast_state["done"] = true
	begin_counter_cast.call()
	var counterspell_prompt_seen := false
	for _frame in 240:
		await h.get_tree().process_frame
		for dialog in combat.hud.get_children():
			if dialog is ConfirmationDialog and dialog.visible:
				if str(dialog.dialog_text).contains("Force a Constitution save"):
					counterspell_prompt_seen = true
					dialog.confirmed.emit()
				elif str(dialog.dialog_text).contains("readied trigger"):
					dialog.confirmed.emit()
				else:
					dialog.canceled.emit()
		if counter_cast_state.done: break
	GameManager.test_mode = true
	h._assert(counterspell_prompt_seen and counter_cast_state.done and int(monster.spell_slots["1"]) == counter_slot_before and listener.current_hp == counter_target_hp and int(tally.spell_slots.get("3", 0)) == 0, "OA03 actual Counterspell interrupts monster effect before damage, refunds the cast slot once and spends the owner's Reaction")
	h._assert(not listener.reaction_available and combat.ready_actions.receipts.size() == counter_ready_receipts + 1, "OA03 interrupted Verbal cast still publishes one separate sound to its eligible Ready owner")
	monster.spells = saved_counterspells
	monster.spell_slots = saved_counter_slots
	monster.erase("saving_throw_bonuses")
	# Missing world hosts cannot silently drop the sound after spending a slot.
	var definition := DataLoader.get_spell("fixture:resonant_repair")
	caster.spell_slots["1"] = 1
	hp = caster.current_hp
	var refused := CombatAction.resolve_spell(caster, caster, definition, true)
	h._assert(not refused.success and refused.get("refused", false) and caster.spell_slots["1"] == 1 and caster.current_hp == hp, "S237 direct unsupported shared sound host refuses before slot or healing")
	var native_spell := DataLoader.get_spell("thunderwave")
	var native_direct := CombatAction.resolve_spell(caster, caster, native_spell, true)
	h._assert(not native_direct.success and native_direct.get("refused", false) and caster.spell_slots["1"] == 1, "S237 native Thunderwave sound refuses a direct resolver host before slot payment")
	var native_ready_context := combat._spell_cast_context(Vector2i.ZERO, Vector2i(9999, 9999), [], [], caster, native_spell)
	native_ready_context.action_id = "ready"
	h._assert(not SpellCastResources.revalidate_selection(native_ready_context) and caster.spell_slots["1"] == 1, "S237 native Thunderwave sound refuses a Ready-shaped context without ReadySpellRules host authority before payment")
	for invalid in [{}, {"volume":"loud", "range_feet":0}, {"volume":"loud", "range_feet":60, "origin":"target-ish"}]:
		var malformed := definition.duplicate(true)
		malformed.effect_noise = invalid
		h._assert(not SharedSpell.content_error(malformed).is_empty(), "S237 malformed or unsupported sound origin refuses content validation")
	var reaction := definition.duplicate(true)
	reaction.casting_time = "reaction"
	h._assert(not SharedSpell.content_error(reaction).is_empty(), "S237 unimplemented reaction sound host refuses content validation")
	await thunderwave_noise(h, combat, caster)
	OrdinaryActionRules.remove_hidden(caster)




static func thunderwave_noise(h: Node, combat: CombatState, caster: Character) -> void:
	# Thunderwave's source-declared 300-foot boom is emitted by the native spell
	# through the same ordinary player combat completion owner.
	var caster_index := 2
	var target: Dictionary = combat.monster_entities[0]
	var saved_caster_position: Vector2i = combat.player_entities[caster_index].hex_position
	var saved_listener_position: Vector2i = combat.player_entities[3].hex_position
	var saved_ally_position: Vector2i = combat.player_entities[1].hex_position
	var saved_actor_position: Vector2i = combat.player_entities[0].hex_position
	var saved_target_position: Vector2i = target.hex_position
	var saved_target_hp := int(target.current_hp)
	var thunderwave_listener: Character = combat.player_entities[3].character
	var saved_listener_reaction: bool = thunderwave_listener.reaction_available
	combat.player_entities[caster_index].hex_position = Vector2i(-2, 0)
	combat.player_entities[3].hex_position = Vector2i(11, 0)
	combat.player_entities[1].hex_position = Vector2i(0, 3)
	combat.player_entities[0].hex_position = Vector2i(0, 5)
	target.hex_position = Vector2i(1, 0)
	for q in range(-2, 12):
		var line_cell := Vector2i(q, 0)
		if not combat.hex_grid.has_tile(line_cell):
			var tile := HexTile.new()
			tile.coord = line_cell
			combat.hex_grid.add_tile(tile)
	combat._update_grid_entities()
	caster.known_spells.append("thunderwave")
	h._own_class_spells(caster)
	caster.spell_slots["1"] = 4
	var source_position: Vector2i = combat.player_entities[caster_index].hex_position
	var direction: Vector2i = source_position + HexUtils.DIRECTIONS[0]
	var nearest_distance := 999
	for step_direction in HexUtils.DIRECTIONS:
		var candidate: Vector2i = source_position + step_direction
		var distance := HexUtils.get_distance(candidate, target.hex_position)
		if distance < nearest_distance:
			nearest_distance = distance
			direction = candidate
	var cube_cells: Array[Vector2i] = Targeting.get_cube_targets(source_position, direction, 3, combat.hex_grid)
	h._assert(target.hex_position in cube_cells, "S237 test selects a native Thunderwave direction whose Cube contains the target")
	await ReadyActionFlow.declare(h, combat, thunderwave_listener, {"kind":"ordinary", "action":"dodge"}, {"event":"sound", "side":"ally", "actor_id":caster.character_id, "at_hex":[source_position.x, source_position.y]})
	h._p_focus(combat, caster)
	var slots_before := int(caster.spell_slots["1"])
	await ReadyActionFlow.answer(h, combat, func():
		await h._cast_menu_spell(combat, "thunderwave", 1)
		await combat._on_hex_clicked(direction), null)
	h._p_focus(combat, caster, false)
	h._assert(int(target.current_hp) < saved_target_hp and int(caster.spell_slots["1"]) == slots_before - 1 and not combat.turn_budget.can_spend("action"), "S237 source-pinned Thunderwave resolves the selected native Cube and emits its boom after once-only slot/Action settlement")
	h._assert(not thunderwave_listener.reaction_available and thunderwave_listener.has_condition("dodging"), "S237 Thunderwave's 300-foot effect sound reaches a Ready listener 65 feet away, beyond the separate 60-foot Verbal sound")
	combat.player_entities[caster_index].hex_position = saved_caster_position
	combat.player_entities[3].hex_position = saved_listener_position
	combat.player_entities[1].hex_position = saved_ally_position
	combat.player_entities[0].hex_position = saved_actor_position
	target.hex_position = saved_target_position
	target.current_hp = saved_target_hp
	thunderwave_listener.reaction_available = saved_listener_reaction
	thunderwave_listener.remove_condition("dodging")
	combat._update_grid_entities()


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
	var room: Dictionary = LocalRoomRules.create({"id":"combat-help-study", "objects":StudyFlow.objects(), "party_spawns":[[0,0],[1,0]]}, [helper, recipient])
	var source: Dictionary = LocalRoomRules.get_object(room, "fixture:survey_stone")
	recipient.heal(recipient.max_hp)
	helper.skill_proficiencies.assign(["Athletics"])
	helper.tool_proficiencies.assign(["Thieves' Tools"])
	h._p_focus(combat, helper)
	await combat._on_hud_action("ordinary_action", {"action":"help_check", "proficiency_kind":"skill", "proficiency":"Arcana"})
	h._assert(combat.turn_budget.can_spend("action") and recipient.combat_check_help.is_empty(), "S237 unowned Help proficiency refuses before targeting or cost")
	combat.hud.ordinary_actions_button.pressed.emit()
	var menu: PopupMenu = combat.hud.get_node("OrdinaryActionsMenu")
	menu.id_pressed.emit(OrdinaryActionRules.ACTIONS.find("help_check")); menu.hide()
	var picked_proficiency: bool = false
	var picked_mode: bool = false
	for _frame in 120:
		await h.get_tree().process_frame
		for child in combat.hud.get_children():
			if not child is PopupMenu or not child.visible: continue
			if child.title == "Help: choose one of your proficiencies":
				for index in child.item_count:
					if child.get_item_text(index) == "Athletics (skill)":
						child.id_pressed.emit(child.get_item_id(index)); child.hide(); picked_proficiency = true; break
			elif child.title == "Help: choose assistance method":
				for index in child.item_count:
					if child.get_item_id(index) == 0:
						child.id_pressed.emit(child.get_item_id(index)); child.hide(); picked_mode = true; break
		if picked_proficiency and picked_mode: break
	await h.get_tree().process_frame
	await combat._on_hex_clicked(combat.player_entities[1].hex_position)
	h._assert(picked_proficiency and picked_mode and not combat.turn_budget.can_spend("action") and recipient.combat_check_help.size() == 1, "S237 actual Help proficiency/method choosers and exact ally click grant physical next-check assistance once")
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
	helper.known_languages.assign(["Common"])
	recipient.known_languages.assign(["Common"])
	helper.skill_proficiencies.assign(["History"])
	source.study[1]["dc"] = 15
	source.study[1]["verbal_help"] = true
	h._p_focus(combat, helper)
	combat.hud.ordinary_actions_button.pressed.emit()
	var verbal_menu: PopupMenu = combat.hud.get_node("OrdinaryActionsMenu")
	verbal_menu.id_pressed.emit(OrdinaryActionRules.ACTIONS.find("help_check")); verbal_menu.hide()
	var verbal_picked_proficiency: bool = false
	var verbal_picked_mode: bool = false
	for _frame in 120:
		await h.get_tree().process_frame
		for child in combat.hud.get_children():
			if not child is PopupMenu or not child.visible: continue
			if child.title == "Help: choose one of your proficiencies":
				for index in child.item_count:
					if child.get_item_text(index) == "History (skill)":
						child.id_pressed.emit(child.get_item_id(index)); child.hide(); verbal_picked_proficiency = true; break
			elif child.title == "Help: choose assistance method":
				for index in child.item_count:
					if child.get_item_text(index) == "Verbal help":
						child.id_pressed.emit(child.get_item_id(index)); child.hide(); verbal_picked_mode = true; break
		if verbal_picked_proficiency and verbal_picked_mode: break
	await h.get_tree().process_frame
	await combat._on_hex_clicked(combat.player_entities[1].hex_position)
	var recipient_position: Vector2i = combat.player_entities[1].hex_position
	source["position"] = [recipient_position.x, recipient_position.y]
	var verbal_result: Dictionary = StudyRules.resolve(room, recipient, source, "age", recipient_position, 0, combat.hex_grid, combat._ability_check_context(recipient))
	var verbal_check: Dictionary = verbal_result.get("check", {})
	h._assert(verbal_picked_proficiency and verbal_picked_mode and not combat.turn_budget.can_spend("action") and verbal_check.get("advantage", false) and verbal_check.get("ordinary_help_sources", []).size() == 1 and recipient.combat_check_help.is_empty(), "OA-09 actual combat Help menus grant language-eligible verbal Advantage on an authored eligible Study check")
	await h._start_class_fixture_turn(combat, helper)
	recipient.known_languages.clear()
	h._p_focus(combat, helper)
	await combat._on_hud_action("ordinary_action", {"action":"help_check", "proficiency_kind":"skill", "proficiency":"Athletics", "help_mode":"verbal"})
	await combat._on_hex_clicked(combat.player_entities[1].hex_position)
	h._assert(combat.turn_budget.can_spend("action") and recipient.combat_check_help.is_empty(), "OA-09 unshared combat languages refuse verbal Help before payment or grant")


static func cover_routes(h: Node, combat: CombatState, actor: Character, enemy: Dictionary) -> void:
	for index in combat.player_entities.size(): combat.player_entities[index].hex_position = Vector2i(-index, -2)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	enemy.hex_position = Vector2i(2, 0)
	actor.conditions.clear(); actor.condition_sources.clear()
	enemy.conditions.clear(); enemy.condition_sources.clear()
	enemy.erase("senses"); enemy.erase("darkvision_range_feet")
	actor.ability_scores.dexterity = 50
	combat._update_grid_entities()
	var obstacle: Dictionary = combat.hex_grid.get_tile(Vector2i(1, 0)).custom_properties
	obstacle.cover = "half"
	CombatAction.apply_condition(actor, "invisible", 100, "fixture:independent_invisible")
	h._p_focus(combat, actor)
	await choose(h, combat, "hide")
	h._assert(combat.turn_budget.can_spend("action") and not actor.has_condition("hidden"), "S238 unseen actor still cannot Hide with only Half Cover")
	obstacle.cover = "three_quarters"
	FighterChecks._seed_die(20, 20)
	await choose(h, combat, "hide")
	h._assert(actor.has_condition("hidden") and actor.combat_hide_dc >= 15 and not combat.turn_budget.can_spend("action"), "S238 actual Hide uses Three-Quarters Cover plus unseen gate and one Action")
	OrdinaryActionRules.remove_hidden(actor)
	CombatAction.remove_condition_source(actor, "fixture:independent_invisible", ["invisible"])
	h._p_focus(combat, actor)
	await choose(h, combat, "hide")
	h._assert(combat.turn_budget.can_spend("action") and not actor.has_condition("hidden"), "S238 Three-Quarters Cover alone cannot bypass an enemy's actual sight")
	# Test physical targeting through a transparent obstacle using ordinary controls.
	obstacle.cover = "total"
	actor.inventory.add_item("shortbow")
	actor.inventory.equip(Inventory.Slot.WEAPON, "shortbow")
	h._p_focus(combat, actor)
	await combat._on_hud_action("attack", {})
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(combat.turn_budget.can_spend("action") and enemy.current_hp > 0, "S238 ordinary Attack refuses transparent Total Cover before payment")
	var caster: Character = combat.player_entities[3].character
	combat.player_entities[3].hex_position = Vector2i.ZERO
	combat.player_entities[0].hex_position = Vector2i(-2, -2)
	caster.known_spells.assign(["sacred_flame", "guiding_bolt"])
	h._own_class_spells(caster); h._ready_spell_components(caster)
	h._p_focus(combat, caster)
	var hp := int(enemy.current_hp)
	var slots: Dictionary = caster.spell_slots.duplicate(true)
	await h._cast_menu_spell(combat, "sacred_flame")
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(combat.turn_budget.can_spend("action") and enemy.current_hp == hp, "S238 actual Sacred Flame picker cannot bypass Total Cover or spend an Action")
	await h._cast_menu_spell(combat, "guiding_bolt")
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(combat.turn_budget.can_spend("action") and caster.spell_slots == slots and enemy.current_hp == hp, "S238 actual slotted cast refuses Total Cover without slot or Action")
	await monster_cover_routes(h, combat, actor, enemy, obstacle)
	await spell_save_cover_routes(h, combat, enemy, obstacle)
	await spell_attack_cover_routes(h, combat, enemy, obstacle)
	await area_cover_routes(h, combat, enemy, obstacle)
	obstacle.erase("cover")


static func monster_cover_routes(h: Node, combat: CombatState, target: Character, monster: Dictionary, obstacle: Dictionary) -> void:
	var old_attacks: Array = monster.get("attacks", []).duplicate(true)
	var old_monster_position: Vector2i = monster.get("hex_position", Vector2i.ZERO)
	var old_reaction: bool = target.reaction_available
	var old_target_hp := target.current_hp
	var old_positions: Array[Vector2i] = []
	for index in combat.player_entities.size():
		old_positions.append(combat.player_entities[index].hex_position)
		combat.player_entities[index].hex_position = Vector2i(-index * 2, -3)
	for participant in combat.player_entities:
		if participant.character == target: participant.hex_position = Vector2i.ZERO
	monster.hex_position = Vector2i(2, 0)
	monster.attacks = [{"name":"Cover probe", "type":"weapon", "damage":"1d4", "damage_type":"piercing", "range":5, "attack_bonus":0}]
	target.reaction_available = false
	combat._update_grid_entities()
	var target_ac := target.get_ac()
	obstacle["cover"] = "half"
	FighterChecks._seed_die(20, 1)
	await combat._execute_monster_attack(monster, target.character_name, 0)
	var half_result: Dictionary = combat.last_monster_weapon_attack_result
	h._assert(int(half_result.get("target_ac", -1)) == target_ac + 2 and not half_result.get("hit", true) and target.current_hp == old_target_hp, "S238 actual monster attack resolver adds Half Cover to its target AC without changing outcomes on a natural miss")
	obstacle["cover"] = "three_quarters"
	FighterChecks._seed_die(20, 1)
	await combat._execute_monster_attack(monster, target.character_name, 0)
	var three_quarters_result: Dictionary = combat.last_monster_weapon_attack_result
	h._assert(int(three_quarters_result.get("target_ac", -1)) == target_ac + 5 and not three_quarters_result.get("hit", true) and target.current_hp == old_target_hp, "S238 actual monster attack resolver adds Three-Quarters Cover to its target AC")
	obstacle["cover"] = "none"
	FighterChecks._seed_die(20, 1)
	await combat._execute_monster_attack(monster, target.character_name, 0)
	var open_result: Dictionary = combat.last_monster_weapon_attack_result
	h._assert(int(open_result.get("target_ac", -1)) == target_ac and not open_result.get("hit", true), "S238 the same monster attack resolves at normal AC when its physical ray is clear")
	obstacle["cover"] = "total"
	var serial_before := combat.action_history._event_serial
	await combat._execute_monster_attack(monster, target.character_name, 0)
	h._assert(combat.action_history._event_serial == serial_before and target.current_hp == old_target_hp, "S238 actual monster attack through Total Cover is refused before attack receipt or damage")
	monster.attacks = old_attacks
	monster.hex_position = old_monster_position
	target.reaction_available = old_reaction
	target.current_hp = old_target_hp
	for index in old_positions.size(): combat.player_entities[index].hex_position = old_positions[index]
	obstacle.erase("cover")
	combat._update_grid_entities()


static func spell_save_cover_routes(h: Node, combat: CombatState, enemy: Dictionary, obstacle: Dictionary) -> void:
	PerceptionChecks.fixtures()
	var caster: Character = combat.player_entities[2].character
	var cleric: Character = combat.player_entities[3].character
	var original_positions: Array[Vector2i] = []
	for index in combat.player_entities.size():
		original_positions.append(combat.player_entities[index].hex_position)
		combat.player_entities[index].hex_position = Vector2i(-index * 2, -3)
	combat.player_entities[2].hex_position = Vector2i.ZERO
	enemy.hex_position = Vector2i(2, 0)
	combat._update_grid_entities()
	var old_hp := int(enemy.current_hp)
	var old_abilities: Dictionary = enemy.get("ability_scores", {}).duplicate(true)
	var old_save_bonuses: Dictionary = enemy.get("saving_throw_bonuses", {}).duplicate(true)
	var had_save_bonuses: bool = enemy.has("saving_throw_bonuses")
	var old_caster_spells: Array = caster.known_spells.duplicate(true)
	var old_caster_choices: Dictionary = caster.feature_choices.duplicate(true)
	var old_spellbook: Array = caster.wizard_spellbook.duplicate(true)
	var old_cleric_spells: Array = cleric.known_spells.duplicate(true)
	var old_cleric_choices: Dictionary = cleric.feature_choices.duplicate(true)
	enemy.ability_scores = {"DEX":10}
	enemy.saving_throw_bonuses = {"DEX":0}
	caster.known_spells.append("fixture:cover_save")
	h._own_class_spells(caster)
	h._ready_spell_components(caster)
	obstacle["cover"] = "half"
	var hp_before := int(enemy.current_hp)
	await h._start_class_fixture_turn(combat, caster)
	h._p_focus(combat, caster)
	FighterChecks._seed_die(20, 13)
	await h._cast_menu_spell(combat, "fixture:cover_save")
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(int(enemy.current_hp) == hp_before and not combat.turn_budget.can_spend("action"), "S238 actual ordinary spell cast applies Half Cover to a Dexterity save and changes its outcome")
	obstacle["cover"] = "three_quarters"
	hp_before = int(enemy.current_hp)
	await h._start_class_fixture_turn(combat, caster)
	h._p_focus(combat, caster)
	FighterChecks._seed_die(20, 9)
	await h._cast_menu_spell(combat, "fixture:cover_save")
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(int(enemy.current_hp) == hp_before and not combat.turn_budget.can_spend("action"), "S238 actual ordinary spell cast applies Three-Quarters Cover to a Dexterity save and changes its outcome")
	# Sacred Flame's authored source exception removes only partial-cover save
	# bonuses. A raw 13 fails DC 14 without its bonus, but would succeed with +2.
	obstacle["cover"] = "half"
	cleric.known_spells.assign(["sacred_flame"])
	h._own_class_spells(cleric)
	h._ready_spell_components(cleric)
	hp_before = int(enemy.current_hp)
	await h._start_class_fixture_turn(combat, cleric)
	h._p_focus(combat, cleric)
	FighterChecks._seed_die(20, 13)
	await h._cast_menu_spell(combat, "sacred_flame")
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(int(enemy.current_hp) < hp_before and not combat.turn_budget.can_spend("action"), "S238 actual Sacred Flame Dex save ignores Half Cover despite sight through the obstacle")
	for index in original_positions.size(): combat.player_entities[index].hex_position = original_positions[index]
	enemy.current_hp = old_hp
	enemy.ability_scores = old_abilities
	if had_save_bonuses: enemy.saving_throw_bonuses = old_save_bonuses
	else: enemy.erase("saving_throw_bonuses")
	caster.known_spells.assign(old_caster_spells)
	caster.feature_choices = old_caster_choices
	caster.wizard_spellbook.assign(old_spellbook)
	cleric.known_spells.assign(old_cleric_spells)
	cleric.feature_choices = old_cleric_choices
	combat._update_grid_entities()


static func spell_attack_cover_routes(h: Node, combat: CombatState, enemy: Dictionary, obstacle: Dictionary) -> void:
	var caster: Character = combat.player_entities[3].character
	var original_positions: Array[Vector2i] = []
	for index in combat.player_entities.size():
		original_positions.append(combat.player_entities[index].hex_position)
		combat.player_entities[index].hex_position = Vector2i(-index * 2, -3)
	combat.player_entities[3].hex_position = Vector2i.ZERO
	enemy.hex_position = Vector2i(2, 0)
	combat._update_grid_entities()
	var old_hp := int(enemy.current_hp)
	var old_ac: Variant = enemy.get("armor_class", 10)
	var old_slots: Dictionary = caster.spell_slots.duplicate(true)
	var old_spells: Array = caster.known_spells.duplicate(true)
	var old_choices: Dictionary = caster.feature_choices.duplicate(true)
	var old_spellbook: Array = caster.wizard_spellbook.duplicate(true)
	caster.known_spells.assign(["guiding_bolt"])
	h._own_class_spells(caster)
	h._ready_spell_components(caster)
	caster.spell_slots["1"] = 5
	enemy["armor_class"] = 20
	obstacle["cover"] = "none"
	var hp_before := int(enemy.current_hp)
	await h._start_class_fixture_turn(combat, caster)
	h._p_focus(combat, caster)
	FighterChecks._seed_die(20, 15)
	await h._cast_menu_spell(combat, "guiding_bolt", 1)
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(int(enemy.current_hp) < hp_before and not combat.turn_budget.can_spend("action"), "S238 ordinary player spell attack hits the same target when its physical ray is clear")
	obstacle["cover"] = "half"
	hp_before = int(enemy.current_hp)
	await h._start_class_fixture_turn(combat, caster)
	h._p_focus(combat, caster)
	FighterChecks._seed_die(20, 15)
	await h._cast_menu_spell(combat, "guiding_bolt", 1)
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(int(enemy.current_hp) == hp_before and not combat.turn_budget.can_spend("action"), "S238 ordinary player spell attack misses after Half Cover raises target AC")
	obstacle["cover"] = "three_quarters"
	await h._start_class_fixture_turn(combat, caster)
	h._p_focus(combat, caster)
	FighterChecks._seed_die(20, 15)
	await h._cast_menu_spell(combat, "guiding_bolt", 1)
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(int(enemy.current_hp) == hp_before and not combat.turn_budget.can_spend("action"), "S238 ordinary player spell attack misses after Three-Quarters Cover raises target AC")
	obstacle["cover"] = "total"
	var slot_before := int(caster.spell_slots.get("1", 0))
	await h._start_class_fixture_turn(combat, caster)
	h._p_focus(combat, caster)
	await h._cast_menu_spell(combat, "guiding_bolt", 1)
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(int(enemy.current_hp) == hp_before and int(caster.spell_slots.get("1", 0)) == slot_before and combat.turn_budget.can_spend("action"), "S238 ordinary player spell attack through Total Cover refuses before slot or Action payment")
	for index in original_positions.size(): combat.player_entities[index].hex_position = original_positions[index]
	enemy.current_hp = old_hp
	enemy["armor_class"] = old_ac
	caster.spell_slots = old_slots
	caster.known_spells.assign(old_spells)
	caster.feature_choices = old_choices
	caster.wizard_spellbook.assign(old_spellbook)
	obstacle.erase("cover")
	combat._update_grid_entities()


static func area_cover_routes(h: Node, combat: CombatState, enemy: Dictionary, obstacle: Dictionary) -> void:
	PerceptionChecks.fixtures()
	var caster: Character = combat.player_entities[2].character
	var original_positions: Array[Vector2i] = []
	for index in combat.player_entities.size():
		original_positions.append(combat.player_entities[index].hex_position)
		combat.player_entities[index].hex_position = Vector2i(-8, -4 + index * 2)
	combat.player_entities[2].hex_position = Vector2i(-2, 4)
	enemy.hex_position = Vector2i(2, 0)
	combat._update_grid_entities()
	var original_hp := int(enemy.current_hp)
	var old_abilities: Dictionary = enemy.get("ability_scores", {}).duplicate(true)
	var old_saves: Dictionary = enemy.get("saving_throw_bonuses", {}).duplicate(true)
	var had_saves: bool = enemy.has("saving_throw_bonuses")
	var old_spells: Array = caster.known_spells.duplicate(true)
	var old_choices: Dictionary = caster.feature_choices.duplicate(true)
	var old_spellbook: Array = caster.wizard_spellbook.duplicate(true)
	enemy.current_hp = 1000
	enemy.ability_scores = {"DEX":10}
	enemy.saving_throw_bonuses = {"DEX":0}
	caster.known_spells.assign(["fixture:cover_area"])
	h._own_class_spells(caster)
	h._ready_spell_components(caster)
	var hp_before := int(enemy.current_hp)
	obstacle["cover"] = "none"
	await h._start_class_fixture_turn(combat, caster)
	h._p_focus(combat, caster)
	FighterChecks._seed_die(20, 13)
	await h._cast_menu_spell(combat, "fixture:cover_area")
	await combat._on_hex_clicked(Vector2i.ZERO)
	h._assert(int(enemy.current_hp) == hp_before - 1, "S238 actual area spell's clear effect-origin ray leaves a DC 14 Dexterity save failed")
	obstacle["cover"] = "half"
	hp_before = int(enemy.current_hp)
	await h._start_class_fixture_turn(combat, caster)
	h._p_focus(combat, caster)
	FighterChecks._seed_die(20, 13)
	await h._cast_menu_spell(combat, "fixture:cover_area")
	await combat._on_hex_clicked(Vector2i.ZERO)
	h._assert(int(enemy.current_hp) == hp_before, "S238 actual area spell uses its selected origin and applies the intervening Half Cover save bonus")
	# Move the selected center onto the obstacle tile: cover at the origin is
	# excluded, so the same target and die fail the save again.
	hp_before = int(enemy.current_hp)
	await h._start_class_fixture_turn(combat, caster)
	h._p_focus(combat, caster)
	FighterChecks._seed_die(20, 13)
	await h._cast_menu_spell(combat, "fixture:cover_area")
	await combat._on_hex_clicked(Vector2i(1, 0))
	h._assert(int(enemy.current_hp) == hp_before - 1, "S238 area effect origin excludes the selected origin cell itself from intervening cover")
	for index in original_positions.size(): combat.player_entities[index].hex_position = original_positions[index]
	enemy.current_hp = original_hp
	enemy.ability_scores = old_abilities
	if had_saves: enemy.saving_throw_bonuses = old_saves
	else: enemy.erase("saving_throw_bonuses")
	caster.known_spells.assign(old_spells)
	caster.feature_choices = old_choices
	caster.wizard_spellbook.assign(old_spellbook)
	obstacle.erase("cover")
	combat._update_grid_entities()
