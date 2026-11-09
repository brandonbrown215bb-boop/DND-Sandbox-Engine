## Encounter-only Ready declarations and completed, perceivable trigger delivery.
## A held response never borrows or refills the interrupted turn's budget.
class_name ReadyActionRules
extends RefCounted

const EVENTS := ["movement", "attack", "cast", "action", "sound"]
const RESPONSES := ["attack", "move", "ordinary", "spell"]
var held: Dictionary = {}
var receipts: Array[Dictionary] = []
var last_result: Dictionary = {}
var selection: Dictionary = {}
var picked_subject: Variant = null
var delivering := false
var generation := 0
var serial := 0
var events: Array[Dictionary] = []
var transient_disengage: Array[Dictionary] = []
var dash_movement: Dictionary = {}


static func trigger_error(trigger: Dictionary) -> String:
	if str(trigger.get("event", "")) not in EVENTS: return "Choose a represented Ready trigger."
	for field in trigger:
		if field not in ["event", "actor_id", "side", "within_hexes", "at_hex"]: return "Unsupported Ready trigger field."
	if trigger.get("side", "enemy") not in ["enemy", "ally", "any"]: return "Invalid trigger side."
	if trigger.has("actor_id") and (not trigger.actor_id is String or str(trigger.actor_id).is_empty()): return "Choose an exact trigger actor."
	if trigger.has("within_hexes") and not ResourcePoolRules._integer(trigger.within_hexes, 0, 100): return "Invalid trigger distance."
	if trigger.has("at_hex") and (not trigger.at_hex is Array or trigger.at_hex.size() != 2 or not trigger.at_hex.all(func(v): return v is int)): return "Invalid trigger space."
	return ""


func owner_entity(state: CombatState, actor: Character) -> Dictionary:
	for entry in state.player_entities:
		if entry.get("character") == actor: return entry
	return {}


func valid(state: CombatState, record: Dictionary, require_reaction: bool = true) -> bool:
	if not is_instance_valid(state): return false
	var actor: Character = record.get("actor")
	if actor == null or not actor.is_alive or CombatAction.is_incapacitated(actor) or state._battle_ending or not state.is_inside_tree(): return false
	if record.get("generation", -1) != generation or held.get(actor.character_id) != record: return false
	var entity := owner_entity(state, actor)
	if entity.is_empty() or (require_reaction and (not actor.reaction_available or not entity.get("reaction_available", true))): return false
	if record.response.kind == "spell" and actor.concentrating_on.get("ready_token", "") != record.token: return false
	return true


func begin(state: CombatState, actor: Character, trigger: Dictionary, response: Dictionary) -> Dictionary:
	var error := trigger_error(trigger)
	if not error.is_empty(): return {"success":false, "message":error}
	if actor == null or not state.active_combatant.get("is_player", false) or not is_same(state.active_combatant.get("entity"), actor) or actor != state.active_character or state.turn_budget.budget_actor != actor or not state.turn_budget.can_spend("action") or state.resolving_player_action or state._cast_in_progress: return {"success":false, "message":"Ready needs your own available Action."}
	if response.get("kind", "") not in RESPONSES: return {"success":false, "message":"Choose a supported Ready response."}
	if response.kind == "spell" and not state.turn_budget.can_spend("magic_action"): return {"success":false, "message":"Readying a spell casts it now; a restricted extra action cannot supply that casting."}
	if response.kind == "ordinary" and str(response.get("action", "")) not in OrdinaryActionRules.ACTIONS.filter(func(a): return a != "ready"): return {"success":false, "message":"That ordinary action cannot be held."}
	if response.kind == "ordinary" and response.get("action", "") == "help_check":
		if not CheckHelpRules.owns(actor, str(response.get("proficiency_kind", "")), str(response.get("proficiency", ""))): return {"success":false, "message":"Help needs one of your actual proficiencies."}
		if response.get("help_mode", "physical") not in ["physical", "verbal"]: return {"success":false, "message":"Choose physical or verbal Help."}
		response["help_mode"] = str(response.get("help_mode", "physical"))
	if response.kind == "attack" and actor.class_id == "familiar": return {"success":false, "message":"A familiar cannot Ready an attack."}
	if trigger.has("at_hex") and not state.hex_grid.has_tile(Vector2i(trigger.at_hex[0], trigger.at_hex[1])): return {"success":false, "message":"The trigger space is not on this board."}
	var turn := CombatAction.active_turn_serial
	serial += 1
	var record := {"actor":actor, "trigger":trigger.duplicate(true), "response":response.duplicate(true), "token":"ready:%s:%d" % [actor.character_id, serial], "generation":generation, "turn":turn, "starts_after":serial}
	if response.kind == "spell":
		var prepared: Dictionary = await state._prepare_readied_spell(actor, response.get("spell", {}), record.token)
		if not prepared.get("success", false): return prepared
		record["cast"] = prepared.cast
		if actor != state.active_character or turn != CombatAction.active_turn_serial or not actor.is_alive or CombatAction.is_incapacitated(actor): return {"success":false, "message":"The Readying turn is no longer available."}
	if response.kind != "spell" and not state._spend_action_cost("action"): return {"success":false, "message":"The Ready Action is no longer available."}
	clear_owner(actor)
	if response.kind == "attack":
		record["weapon_copy"] = actor.inventory.equipped_instance_id(Inventory.Slot.WEAPON)
		record["weapon_id"] = actor.inventory.get_weapon()
	if response.kind == "move": record.response["mode"] = state.active_movement_mode
	held[actor.character_id] = record
	state.pending_action_type = ""
	state.pending_spell_data = {}
	state.pending_feature_data = {}
	if response.kind == "spell":
		state._end_concentration(actor)
		actor.concentrating_on = {"spell_id":str(record.cast.spell.id), "ready_token":record.token, "targets":[], "extended_spell":bool(record.cast.spell.get("_metamagic_extended", false))}
	state.hud.add_log("%s readies %s. Its response uses a Reaction before the next turn starts." % [actor.character_name, str(response.get("action", response.kind)).replace("_", " ")])
	if response.kind == "spell": await publish(state, {"type":"cast", "actor":actor, "position":owner_entity(state, actor).hex_position, "components":record.cast.spell.get("components", []), "producer_token":record.token})
	await publish(state, {"type":"action", "actor":actor, "position":owner_entity(state, actor).get("hex_position", Vector2i.ZERO), "producer_token":record.token})
	state.hud.update_hud(state.active_character, state.tracker)
	return {"success":true, "token":record.token}


func clear_owner(actor: Character) -> void:
	var record: Dictionary = held.get(actor.character_id, {})
	held.erase(actor.character_id)
	if not record.is_empty() and actor.concentrating_on.get("ready_token", "") == record.token:
		actor.concentrating_on.clear()


func clear() -> void:
	for record in held.values(): clear_owner(record.actor)
	for entry in transient_disengage: CombatAction.remove_condition_source(entry.actor, entry.source, ["disengaging"])
	transient_disengage.clear()
	dash_movement.clear()
	events.clear()
	last_result.clear()
	selection.clear()
	generation += 1


func end_turn() -> void:
	for entry in transient_disengage: CombatAction.remove_condition_source(entry.actor, entry.source, ["disengaging"])
	transient_disengage.clear()
	dash_movement.clear()


func publish(state: CombatState, event: Dictionary) -> void:
	if str(event.get("type", "")) not in EVENTS or state._battle_ending: return
	var sound := {}
	if event.type == "sound":
		if not CombatNoiseRules.error(event.get("noise", {})).is_empty(): return
		sound = event.duplicate()
		sound["noise"] = event.noise.duplicate(true)
	elif event.type == "cast" and "V" in event.get("components", []):
		sound = event.duplicate()
		sound["type"] = "sound"
		sound["noise"] = CombatNoiseRules.VERBAL_SOUND.duplicate()
	# Hide and hearing are world consequences even when nobody has readied.
	if not sound.is_empty(): CombatNoiseRules.emit(state, sound)
	if held.is_empty() and not delivering: return
	serial += 1
	var completed := sound.duplicate() if event.type == "sound" else event.duplicate()
	completed["serial"] = serial
	events.append(completed)
	if not sound.is_empty() and event.type != "sound":
		serial += 1
		sound["serial"] = serial
		events.append(sound)
	if delivering: return
	delivering = true
	while not events.is_empty() and is_instance_valid(state) and state.is_inside_tree() and not state._battle_ending:
		var occurrence: Dictionary = events.pop_front()
		for record in held.values().duplicate():
			if not valid(state, record): continue
			if not matches(state, record, occurrence): continue
			var actor: Character = record.actor
			var accepted := await state.hud.request_reaction(state._owner_label_for_character(actor), "ready_action", "The readied trigger has finished. Take your held response now?", "Respond to this trigger?", "Use Reaction")
			if not accepted or not valid(state, record) or not matches(state, record, occurrence):
				_receipt(record, occurrence, "declined" if not accepted else "stale")
				continue
			var result := await release(state, record, occurrence)
			last_result = result
			_receipt(record, occurrence, str(result.get("status", "refused")))
	delivering = false
	if is_instance_valid(state) and state.is_inside_tree():
		state._update_grid_entities()
		state.hud.update_hud(state.active_character, state.tracker)


func _receipt(record: Dictionary, event: Dictionary, status: String) -> void:
	receipts.append({"token":record.token, "event":event.serial, "status":status})
	while receipts.size() > 64: receipts.pop_front()


func matches(state: CombatState, record: Dictionary, event: Dictionary) -> bool:
	var actor: Character = record.actor
	var subject = event.get("actor")
	if subject == null or int(event.get("serial", 0)) <= int(record.starts_after) or event.get("producer_token", "") == record.token: return false
	var self_observed := CombatAction.actor_id(subject) == actor.character_id
	var trigger: Dictionary = record.trigger
	if trigger.event != event.get("type"): return false
	if event.type == "cast" and not self_observed and not event.get("components", []).any(func(component): return component in ["V", "S", "M"]): return false
	if trigger.has("actor_id") and trigger.actor_id != CombatAction.actor_id(subject): return false
	var ally := subject is Character or (subject is Dictionary and subject.get("character") is Character)
	if trigger.get("side", "enemy") == "enemy" and ally: return false
	if trigger.get("side", "enemy") == "ally" and not ally: return false
	var origin: Vector2i = owner_entity(state, actor).get("hex_position", Vector2i.ZERO)
	var destination: Vector2i = event.get("position", Vector2i.ZERO)
	if event.type == "sound":
		if event.get("noise", {}).get("volume") != "loud" or not event.get("heard_by", {}).has(actor.character_id): return false
		origin = event.heard_by[actor.character_id]
	if trigger.has("within_hexes") and HexUtils.get_distance(origin, destination) > int(trigger.within_hexes): return false
	if trigger.has("at_hex") and destination != Vector2i(trigger.at_hex[0], trigger.at_hex[1]): return false
	if event.type == "sound": return true
	if self_observed: return true
	return CombatPerception.can_see_target(actor, subject, origin, destination, state.hex_grid)


func choose_hex(coord: Vector2i) -> bool:
	if selection.is_empty(): return false
	if coord in selection.coords:
		selection["coord"] = coord
		selection["subject"] = selection.subjects.get(coord)
		selection["done"] = true
	return true


func cancel_selection() -> bool:
	if selection.is_empty(): return false
	selection["done"] = true
	return true


func pick(state: CombatState, record: Dictionary, coords: Array, prompt: String, preparing: bool = false) -> Variant:
	if coords.is_empty(): return null
	var is_current := func() -> bool:
		if not preparing: return valid(state, record)
		return is_instance_valid(state) and state.is_inside_tree() and not state._battle_ending and state.active_character == record.actor and CombatAction.active_turn_serial == record.turn and generation == record.generation
	var original_highlights: Dictionary = state.hex_grid._highlighted_hexes.duplicate()
	state._update_grid_entities(record.actor)
	var subjects := {}
	for participant in state._all_live_combat_entities():
		if participant.get("hex_position") in coords: subjects[participant.hex_position] = participant.get("character", participant)
	for coord in coords:
		if not subjects.has(coord):
			var object := CombatObjectRules.at(state.hex_grid, coord, record.actor)
			if not object.is_empty(): subjects[coord] = object
	selection = {"coords":coords, "subjects":subjects, "done":false}
	picked_subject = null
	var request := selection
	var colors := {}
	for coord in coords: colors[coord] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.SPELL]
	state.hex_grid.set_highlights(colors)
	state.hud.add_log(prompt + " Cancel ignores this trigger.")
	while not bool(request.get("done", true)) and is_current.call(): await state.get_tree().process_frame
	selection = {}
	if not is_instance_valid(state) or not state.is_inside_tree(): return null
	picked_subject = request.get("subject")
	state._update_grid_entities()
	state.hex_grid.set_highlights(original_highlights)
	return request.get("coord") if bool(request.get("done", false)) and is_current.call() else null


func pay_reaction(state: CombatState, record: Dictionary) -> bool:
	if not valid(state, record): return false
	var actor: Character = record.actor
	actor.reaction_available = false
	owner_entity(state, actor)["reaction_available"] = false
	held.erase(actor.character_id)
	return true


func release(state: CombatState, record: Dictionary, event: Dictionary) -> Dictionary:
	match str(record.response.kind):
		"attack": return await release_attack(state, record)
		"move": return await release_movement(state, record)
		"spell": return await state._release_readied_spell(record)
		"ordinary": return await release_ordinary(state, record)
	return {"status":"refused"}


func weapon(state: CombatState, record: Dictionary) -> Dictionary:
	var actor: Character = record.actor
	if actor.inventory.equipped_instance_id(Inventory.Slot.WEAPON) != record.weapon_copy or actor.inventory.get_weapon() != record.weapon_id: return {}
	var profile := DruidRules.current_attack_profile(actor) if DruidRules.is_shaped(actor) else DataLoader.get_item(actor.inventory.get_weapon()).duplicate(true)
	if profile.is_empty(): profile = CombatAction.unarmed_attack_profile(actor)
	return profile


func attack_targets(state: CombatState, record: Dictionary, profile: Dictionary) -> Array:
	LocalRoomCombat.bind_grid(state.hex_grid)
	var coords := []
	if profile.is_empty() or not AmmunitionRules.attack_error(record.actor, profile).is_empty(): return coords
	var actor: Character = record.actor
	var origin: Vector2i = owner_entity(state, actor).hex_position
	var reach := CombatAction.weapon_range_hexes(profile)
	if "reach" in profile.get("properties", []): reach = maxi(reach, 2)
	for enemy in state.monster_entities:
		var position: Vector2i = enemy.hex_position
		if not enemy.get("is_alive", false) or CombatAction.is_charmed_by(actor, enemy): continue
		if HexUtils.get_distance(origin, position) > reach or not Targeting.has_line_of_effect(origin, position, state.hex_grid): continue
		if not CombatPerception.can_locate_target(actor, enemy, origin, position, state.hex_grid): continue
		if state._spell_zones()._antilife_shell_blocks_melee(actor, origin, position, profile): continue
		coords.append(position)
	return coords


func release_attack(state: CombatState, record: Dictionary) -> Dictionary:
	var profile := weapon(state, record)
	var coord: Variant = await pick(state, record, attack_targets(state, record, profile), "%s: select a target for the readied attack." % record.actor.character_name)
	if coord == null or not valid(state, record) or coord not in attack_targets(state, record, weapon(state, record)): return {"status":"ignored"}
	var target: Dictionary = picked_subject if picked_subject is Dictionary else {}
	if target.is_empty(): return {"status":"stale"}
	var actor: Character = record.actor
	var origin: Vector2i = owner_entity(state, actor).hex_position
	profile["attack_distance"] = HexUtils.get_distance(origin, coord)
	profile["attack_action"] = false
	var still_error := func() -> String:
		return "" if valid(state, record) and state.monster_entities.any(func(candidate): return is_same(candidate, target)) and target.get("hex_position") == coord and owner_entity(state, actor).get("hex_position") == origin and coord in attack_targets(state, record, weapon(state, record)) else "The readied attack is no longer legal."
	var choice := await state._route_damage_choice(actor, profile, "Readied attack", false, still_error)
	if choice.get("held", false): return {"status":"ignored"}
	var decisions: Dictionary = await state._collect_attack_inspiration_decision(actor)
	decisions.merge(await state._collect_roll_token_decision(actor, "attack", "Readied attack", decisions), true)
	decisions.merge(choice.get("decisions", {}), true)
	decisions["combat_history"] = state.action_history
	if not str(still_error.call()).is_empty() or not pay_reaction(state, record): return {"status":"stale"}
	var result := await state._settle_attack_profile_hit_choice(CombatAction.resolve_weapon_attack(actor, target, profile, false, false, CombatPerception.weapon_decisions(state.hex_grid, actor, target, decisions, origin, coord)))
	await state._offer_sneak_attack(target, profile, result, actor)
	await state._offer_stunning_strike(target, profile, result, actor)
	await state._finish_fighter_attack(target, profile, result, actor)
	state.hud.add_log("Readied attack: " + str(result.get("message", "Resolved.")))
	if int(target.get("current_hp", 0)) <= 0 and target.get("is_alive", true):
		target.is_alive = false
		state.tracker.remove_combatant(str(target.id))
		state._trigger_enemy_defeat_features(target, actor)
	state._check_battle_end_conditions()
	await publish(state, {"type":"attack", "actor":actor, "position":origin})
	return {"status":"resolved", "result":result}


func release_movement(state: CombatState, record: Dictionary) -> Dictionary:
	var actor: Character = record.actor
	var entity := owner_entity(state, actor)
	var mode := str(record.response.get("mode", "walk"))
	var allowance := float(state._movement_speed_feet(mode, actor)) / 5.0
	var origin: Vector2i = entity.hex_position
	var reachable := state._player_reachable(origin, allowance, actor, mode)
	var coords: Array = reachable.keys().filter(func(coord): return coord != origin)
	var destination: Variant = await pick(state, record, coords, "%s: select readied movement up to current Speed." % actor.character_name)
	if destination == null or not valid(state, record): return {"status":"ignored"}
	allowance = minf(allowance, float(state._movement_speed_feet(mode, actor)) / 5.0)
	if destination not in state._player_reachable(entity.hex_position, allowance, actor, mode): return {"status":"stale"}
	var path := state._player_path(entity.hex_position, destination, actor, mode)
	if path.size() < 2 or state._path_breaks_fear(actor, path, state._all_live_combat_entities()) or not pay_reaction(state, record): return {"status":"stale"}
	var spent := 0.0
	for index in range(1, path.size()):
		if not actor.is_alive or CombatAction.is_incapacitated(actor) or generation != record.generation or state._battle_ending or entity.hex_position != path[index - 1]: break
		allowance = minf(allowance, float(state._movement_speed_feet(mode, actor)) / 5.0)
		var cost := state._player_step_movement_cost(path[index - 1], path[index], actor, mode)
		if spent + cost > allowance or not state._player_can_enter(path[index], actor, mode): break
		if state._path_breaks_fear(actor, [path[index - 1], path[index]], state._all_live_combat_entities()): break
		spent += cost
		await state._check_opportunity_attacks_for_path(actor, entity, [path[index - 1], path[index]], false, mode)
	state.hud.add_log("%s finishes readied movement." % actor.character_name)
	return {"status":"resolved", "spent":spent}


func release_ordinary(state: CombatState, record: Dictionary) -> Dictionary:
	var actor: Character = record.actor
	var action := str(record.response.action)
	if action in ["utilize", "study", "influence"]:
		var targets := StudyRules.combat_targets(state, actor) if action == "study" else CombatUtilizeRules.targets(state, actor)
		if action == "influence": targets = InfluenceRules.targets(state, actor)
		var position: Variant = await pick(state, record, targets.keys(), "%s: select the room source for readied %s." % [actor.character_name, action.capitalize()])
		if position == null: return {"status":"ignored"}
		var selected: Variant = targets.get(position, {} if action == "utilize" else [])
		if not valid(state, record) or selected.is_empty(): return {"status":"stale"}
		if action == "utilize" and not CombatUtilizeRules.error(state, actor, LocalRoomCombat.room(), selected, position).is_empty(): return {"status":"stale"}
		var current := func(): return valid(state, record)
		var pay := func(): return pay_reaction(state, record)
		var result: Dictionary
		if action == "influence": result = await InfluenceRules.request(state, actor, selected, position, current, pay)
		elif action == "study": result = await StudyRules.combat_request(state, actor, selected, position, current, pay)
		else: result = await CombatUtilizeRules.request(state, actor, selected, current, pay)
		if result.has("message"): state.hud.add_log(result.message)
		if result.get("status") == "resolved": await state._completed_player_action(actor, result.get("noise", {}))
		return result
	var origin: Vector2i = owner_entity(state, actor).hex_position
	var coord: Variant = null
	var selected_target: Variant = null
	if action in ["help_attack", "stabilize", "help_check"]:
		var verbal_help: bool = action == "help_check" and str(record.response.get("help_mode", "physical")) == "verbal"
		var target_range: int = 6 if verbal_help else 1
		var coords: Array = attack_targets(state, record, {"range":1}) if action == "help_attack" else state.player_entities.filter(func(p): return p.get("character") != actor and not p.character.is_dead() and (action == "help_check" or (p.character.is_downed() and not p.character.is_stable)) and HexUtils.get_distance(origin, p.hex_position) <= target_range).map(func(p): return p.hex_position)
		coord = await pick(state, record, coords, "%s: select the readied Help target." % actor.character_name)
		if coord == null: return {"status":"ignored"}
		selected_target = picked_subject
	if not valid(state, record): return {"status":"stale"}
	origin = owner_entity(state, actor).hex_position
	if action in ["help_attack", "stabilize", "help_check"]:
		var verbal_help: bool = action == "help_check" and str(record.response.get("help_mode", "physical")) == "verbal"
		if verbal_help:
			if not CommunicationRules.eligibility_error(actor, selected_target, origin, coord, state.hex_grid, LocalRoomCombat.room()).is_empty(): return {"status":"stale"}
		elif HexUtils.get_distance(origin, coord) > 1 or not Targeting.has_line_of_effect(origin, coord, state.hex_grid): return {"status":"stale"}
		if action == "help_attack":
			if not selected_target is Dictionary or not state.monster_entities.any(func(enemy): return is_same(enemy, selected_target)) or selected_target.get("hex_position") != coord or not selected_target.get("is_alive", false) or not CombatPerception.can_locate_target(actor, selected_target, origin, coord, state.hex_grid): return {"status":"stale"}
		else:
			if not selected_target is Character or selected_target == actor or owner_entity(state, selected_target).get("hex_position") != coord or selected_target.is_dead(): return {"status":"stale"}
			if action == "stabilize" and (not selected_target.is_downed() or selected_target.is_stable): return {"status":"stale"}
			if action == "help_check" and not CheckHelpRules.owns(actor, str(record.response.get("proficiency_kind", "")), str(record.response.get("proficiency", ""))): return {"status":"stale"}
	if action == "hide" and not OrdinaryActionRules.hide_error(actor, origin, state.monster_entities, state.hex_grid).is_empty(): return {"status":"refused"}
	if not pay_reaction(state, record): return {"status":"stale"}
	match action:
		"dodge": actor.add_condition("dodging", 2)
		"disengage":
			actor.add_condition("disengaging", -1, record.token)
			transient_disengage.append({"actor":actor, "source":record.token})
		"dash":
			var bonus := float(state._movement_speed_feet("walk", actor)) / 5.0
			dash_movement[actor.character_id] = float(dash_movement.get(actor.character_id, 0.0)) + bonus
			if state.active_combatant.get("is_player", false) and state.active_combatant.get("entity") == actor:
				state._grant_extra_movement_speed()
			state.hud.add_log("Readied Dash grants %d feet of additional movement this turn. Moving outside your turn still needs permission; Ready movement supplies that response." % int(bonus * 5))
		"hide": OrdinaryActionRules.hide(actor, state._ability_check_context(actor))
		"search": OrdinaryActionRules.search(actor, origin, state.monster_entities, state.hex_grid, state._ability_check_context(actor))
		"help_attack":
			selected_target["familiar_helped_by"] = actor.character_id
		"help_check":
			if str(record.response.get("help_mode", "physical")) == "verbal": CheckHelpRules.grant_verbal(actor, selected_target, str(record.response.proficiency_kind), str(record.response.proficiency), origin, coord, state.hex_grid, LocalRoomCombat.room())
			else: CheckHelpRules.grant(actor, selected_target, str(record.response.proficiency_kind), str(record.response.proficiency))
		"stabilize":
			var check := EventResolver.resolve_skill_check(actor, {"ability":"WIS", "skill":"Medicine", "dc":10}, {}, state._ability_check_context(actor))
			if check.success: selected_target.stabilize()
	await publish(state, {"type":"action", "actor":actor, "position":origin})
	return {"status":"resolved"}
