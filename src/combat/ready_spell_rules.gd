## A readied spell is cast and paid now; its retained context releases once.
class_name ReadySpellRules
extends RefCounted


static func context(state: CombatState, actor: Character, spell: Dictionary) -> SpellCastContext:
	var cast := state._spell_cast_context(Vector2i.ZERO, Vector2i(9999, 9999), [], [], actor, spell)
	cast.divine_intervention = false
	cast.divine_intervention_wish = false
	cast.action_id = "ready"
	cast.ready_sound_host = true
	var cast_ref: WeakRef = weakref(cast)
	cast.reset_pending = func(_flags: int): pass
	cast.publish_spell = func(value: Dictionary):
		var target: SpellCastContext = cast_ref.get_ref()
		if target != null: target.spell = value
	cast.set_resolving = func(_resolving: bool): pass
	cast.begin_targeting = func(): pass
	cast.finish_targeting = func(): pass
	cast.highlight_reachable = func(): pass
	# This optional high-level rider reads the active turn owner in the native
	# host. Supply the captured caster explicitly for an off-turn release.
	cast.offer_potent_spellcasting_vitality = func(value: Dictionary, damage: int): await state._offer_potent_spellcasting_vitality(value, damage, actor)
	return cast


static func prepare(state: CombatState, actor: Character, selected: Dictionary, token: String) -> Dictionary:
	var command := CombatCommand.from_hud_for_character("cast_spell", {"spell":selected}, actor)
	if command == null: return {"success":false, "message":"The readied spell source/payment is no longer available."}
	var spell: Dictionary = AttackProfileRules.apply_cast(actor, command.payload.spell)
	if spell.get("casting_time", "action") != "action": return {"success":false, "message":"Only a spell with an Action casting time can be readied."}
	if not SpellSupport.availability(spell).available: return {"success":false, "message":"The selected spell is unavailable."}
	if not DruidRules.can_cast_spell(actor, spell) or CombatAction.is_incapacitated(actor): return {"success":false, "message":"The caster cannot cast this spell now."}
	if SorcererRules.quickened_spell_blocks_cast(actor, spell): return {"success":false, "message":"Quickened Spell prevents this cast."}
	var turn := CombatAction.active_turn_serial
	var cast := context(state, actor, spell)
	var turn_is_current := func(): return is_instance_valid(state) and state.is_inside_tree() and state.active_character == actor and turn == CombatAction.active_turn_serial and actor.is_alive and not CombatAction.is_incapacitated(actor) and not state._battle_ending
	var own_turn_guard := func(): return turn_is_current.call() and state.turn_budget.can_spend("magic_action")
	cast.commit_guard = own_turn_guard
	cast.can_spend = func(_cost: String): return own_turn_guard.call()
	cast.spend_action_cost = func(_cost: String): return false
	if not await SpellCastSelection.choose(cast, spell) or not own_turn_guard.call(): return {"success":false, "message":"The readied cast selection was cancelled or became stale."}
	spell = cast.spell
	cast.component_item_id = str(spell.get("material_component_item_id", spell.get("consumed_material_item_id", "")))
	cast.component_instance_id = actor.inventory.required_spell_component_instance(spell)
	if not actor.inventory.has_required_spell_component(spell, str(SpellPermissionRules.selected_permission(actor, spell).get("class_id", actor.class_id))): return {"success":false, "message":"The readied spell needs its normal components now."}
	if not cast.component_instance_id.is_empty(): cast.component_copy_validated = true
	if not SpellCastResources.revalidate_selection(cast): return {"success":false, "message":"The readied cast became unavailable."}
	# All eligibility checks precede either cost. This is the actual casting,
	# not a reservation that can be refunded by declining the later trigger.
	if not SpellCastResources.commit_metamagic(cast) or not SpellCastResources.commit_spell_resource(cast): return {"success":false, "message":"The spell payment is no longer available."}
	if not state._spend_action_cost("magic_action"): return {"success":false, "message":"The Ready casting Action is no longer available."}
	cast.ready_action_paid = true
	var cast_event := {"actor_id":actor.character_id, "spell_id":str(cast.spell.id)}
	SpellEffects.consume_spell(actor, "sanctuary", "cast", cast_event)
	if str(cast.spell.id) != "invisibility": SpellEffects.consume_spell(actor, "invisibility", "cast", cast_event)
	state._end_concentration(actor)
	cast.spell_origin = state.ready_actions.owner_entity(state, actor).hex_position
	cast.target_type = str(cast.spell.get("target", "single"))
	await SpellCastReactions._collect_spell_cast_reactions(cast)
	if not turn_is_current.call(): return {"success":false, "message":"The readied casting was interrupted."}
	cast.targets.assign(state._all_live_combat_entities().map(func(entry): return entry.hex_position))
	await SpellCastReactions.choose_preparation_options(cast)
	if not turn_is_current.call(): return {"success":false, "message":"The readied casting was interrupted."}
	if bool(cast.reaction_decisions.get("metamagic:heightened", false)):
		if SorcererRules.spend_metamagic_cost(actor, 2, cast.reaction_decisions):
			cast.reaction_decisions["metamagic:heightened_paid"] = true
			cast.counterspell_decisions["metamagic:heightened_paid"] = true
		else:
			cast.reaction_decisions.erase("metamagic:heightened")
			cast.counterspell_decisions.erase("metamagic:heightened")
	SpellCastResources.commit_material_components(cast)
	var reaction_data := {"decisions":cast.counterspell_decisions, "observers":cast.counterspell_observers}
	var resolution := SpellResolutionContext.new()
	resolution.caster = actor
	resolution.spell = cast.spell
	resolution.spell_definition_id = str(cast.spell.id)
	resolution.slot_level = cast.slot_level_used
	resolution.incoming_slot_spent = cast.incoming_slot_spent
	resolution.incoming_slot_key = str(cast.slot_level_used)
	resolution.incoming_slot_pool_id = cast.incoming_slot_pool_id
	resolution.decisions = reaction_data.decisions.duplicate(true)
	resolution.decisions["cast_payment_receipt"] = cast.payment_receipt
	resolution.observers = reaction_data.observers
	var interruption := CastInterruptionRules.resolve_cancellation(resolution)
	if not interruption.is_empty():
		state.hud.add_log(str(interruption.get("message", "The readied spell was interrupted.")))
		await state.ready_actions.publish(state, {"type":"cast", "actor":actor, "position":state.ready_actions.owner_entity(state, actor).get("hex_position", cast.spell_origin), "components":cast.spell.get("components", []), "producer_token":token})
		return {"success":false, "message":"The spell was interrupted while being readied; no energy is held."}
	if state.active_character != actor or turn != CombatAction.active_turn_serial or not actor.is_alive or CombatAction.is_incapacitated(actor): return {"success":false, "message":"The readied cast was interrupted."}
	if cast.incoming_slot_spent and cast.slot_level_used >= 1:
		for entry in WardRules.on_slot_spell_cast(actor, cast.spell, cast.slot_level_used): state.hud.add_log(str(entry.get("message", "")))
	cast.successful = true
	SpellCastResults._publish_completed_cast(cast)
	cast.successful = false
	cast.spell["_skip_counterspell"] = true
	cast.ready_release_token = token
	return {"success":true, "cast":cast, "action_paid":true}


static func target_coords(state: CombatState, actor: Character, spell: Dictionary) -> Array:
	var coords := []
	var origin: Vector2i = state.ready_actions.owner_entity(state, actor).get("hex_position", Vector2i.ZERO)
	var query := context(state, actor, spell)
	var range_hexes := SpellCastTargeting._spell_target_range(query, spell)
	var type := str(spell.get("target", "single"))
	if type == "self": return [origin]
	for coord in state.hex_grid.tiles:
		if HexUtils.get_distance(origin, coord) > range_hexes or not Targeting.has_line_of_sight(origin, coord, state.hex_grid): continue
		if type in ["area", "cone", "point"]:
			coords.append(coord)
			continue
		if type == "object" or bool(spell.get("targets_objects", false)):
			if not CombatObjectRules.all_at(state.hex_grid, coord, actor).is_empty(): coords.append(coord)
			if type == "object": continue
		for participant in state._all_live_combat_entities():
			if participant.get("hex_position") != coord: continue
			var subject = participant.get("character", participant)
			if not state.hex_grid.has_tile(coord) or not CombatPerception.can_locate_target(actor, subject, origin, coord, state.hex_grid): continue
			if bool(spell.get("requires_target_sight", false)) and not CombatPerception.can_see_target(actor, subject, origin, coord, state.hex_grid): continue
			if type == "single_ally" and not subject is Character: continue
			if subject is Character and not subject.is_alive and not SpellCastTargeting.can_target_downed(subject, spell): continue
			if subject is Dictionary and not subject.get("is_alive", false): continue
			if coord not in coords: coords.append(coord)
	return coords


static func select_additional_targets(state: CombatState, record: Dictionary, cast: SpellCastContext) -> bool:
	var first := cast.target_coord
	var primary_subject = state.ready_actions.picked_subject
	var identities := [{"subject":primary_subject, "coord":first}]
	var point_count := int(cast.spell.get("area_point_count", 1))
	var projectiles := cast.spell.has("dart_count") or cast.spell.has("damage_per_ray")
	var required := point_count if point_count > 1 else SpellCastTargeting._spell_projectile_total(cast, cast.spell) if projectiles else 1
	if required > 1:
		cast.command_selection.assign([first])
		for index in range(1, required):
			var coords := target_coords(state, record.actor, cast.spell)
			if point_count > 1: coords = coords.filter(func(coord): return coord not in cast.command_selection)
			var next: Variant = await state.ready_actions.pick(state, record, coords, "Choose readied %s %d of %d." % ["area center" if point_count > 1 else "projectile target", index + 1, required])
			if next == null: return false
			cast.command_selection.append(next)
			identities.append({"subject":state.ready_actions.picked_subject, "coord":next})
	elif SpellCastTargeting._spell_grants_additional_target(cast, record.actor, cast.spell):
		var maximum := maxi(2, SpellCastTargeting._spell_upcast_maximum_targets(cast, cast.spell)) + int(cast.spell.get("_metamagic_twinned_extra_targets", 0))
		cast.command_selection.assign([first])
		for _index in range(1, maximum):
			var coords := target_coords(state, record.actor, cast.spell).filter(func(coord): return coord not in cast.command_selection and SpellCastTargeting._valid_additional_spell_target(cast, first, coord, cast.spell, cast.command_selection))
			if coords.is_empty(): break
			var next: Variant = await state.ready_actions.pick(state, record, coords, "Choose another readied spell recipient, or Cancel to finish with the selected recipients.")
			if next == null: break
			cast.command_selection.append(next)
			identities.append({"subject":state.ready_actions.picked_subject, "coord":next})
	if not state.ready_actions.valid(state, record): return false
	cast.ready_target_identities = identities
	return targets_still_valid(state, cast)


static func targets_still_valid(state: CombatState, cast: SpellCastContext) -> bool:
	if cast.spell.get("target", "single") in ["area", "cone", "point", "self"]: return true
	for selected in cast.ready_target_identities:
		var subject = selected.subject
		if subject == null: continue
		if subject is Dictionary and subject.get("is_object", false):
			if not is_same(CombatObjectRules.by_key(state.hex_grid, selected.coord, CombatObjectRules.target_key(subject), cast.caster), subject): return false
		elif subject is Character:
			if state.ready_actions.owner_entity(state, subject).get("hex_position") != selected.coord: return false
		elif not state.monster_entities.any(func(candidate): return is_same(candidate, subject)) or subject.get("hex_position") != selected.coord: return false
	return true


static func release(state: CombatState, record: Dictionary) -> Dictionary:
	var actor: Character = record.actor
	# A refused/cancelled target can clear its working context. The paid spell
	# remains immutable so ignoring one trigger cannot erase the held energy.
	var paid: SpellCastContext = record.cast
	var cast := context(state, actor, paid.spell)
	for field in ["invocation_id", "spell_level", "slot_level_used", "incoming_slot_spent", "incoming_slot_pool_id", "component_item_id", "component_instance_id", "component_copy_validated", "material_components_paid", "ready_release_token", "ready_action_paid"]:
		cast.set(field, paid.get(field))
	cast.payment_receipt = paid.payment_receipt.duplicate(true)
	cast.completed_cast_facts = paid.completed_cast_facts.duplicate(true)
	cast.reaction_decisions = paid.reaction_decisions.duplicate(true)
	cast.counterspell_decisions = paid.counterspell_decisions.duplicate(true)
	cast.recipient_exemption_selection = paid.recipient_exemption_selection.duplicate(true)
	for field in ["apotheosis_available", "apotheosis_assigned", "quickened_selected", "twinned_selected", "spell_attack_available"]: cast.set(field, paid.get(field))
	var coord: Variant = await state.ready_actions.pick(state, record, target_coords(state, actor, cast.spell), "%s: release %s at a legal target." % [actor.character_name, cast.spell.get("name", "the spell")])
	if coord == null: return {"status":"ignored"}
	var subject = state.ready_actions.picked_subject
	if not state.ready_actions.valid(state, record) or coord not in target_coords(state, actor, cast.spell): return {"status":"stale"}
	cast.target_coord = coord
	if not await select_additional_targets(state, record, cast): return {"status":"ignored"}
	cast.ready_release_guard = func(): return state.ready_actions.valid(state, record) or (is_instance_valid(state) and state.is_inside_tree() and record.get("released", false) and record.generation == state.ready_actions.generation and actor.is_alive and not CombatAction.is_incapacitated(actor) and not state._battle_ending)
	cast.commit_guard = cast.ready_release_guard
	var release_guard := cast.ready_release_guard
	cast.can_spend = func(_cost: String): return release_guard.call()
	cast.spend_action_cost = func(_cost: String): return bool(record.get("released", false))
	# Target/space/options are live at release. Resource/source affordability is
	# deliberately not tested again: the last slot/use can already be spent.
	if not await SpellCastPreparation.validate_and_choose(cast) or not await SpellCastPreparation.choose_target_options(cast): return {"status":"refused"}
	if not targets_still_valid(state, cast): return {"status":"stale"}
	var sound_source_error := CombatNoiseRules.capture_target_origin(cast)
	if not sound_source_error.is_empty():
		state.hud.add_log(sound_source_error)
		return {"status":"stale"}
	if subject != null and str(cast.spell.get("target", "single")) not in ["area", "cone", "point", "self"]:
		var current_position: Variant = CombatPerception._position(subject, state.hex_grid)
		if current_position != coord: return {"status":"stale"}
	if not state.ready_actions.valid(state, record) or not state.ready_actions.pay_reaction(state, record): return {"status":"stale"}
	record["released"] = true
	if actor.concentrating_on.get("ready_token", "") == record.token: actor.concentrating_on.clear()
	cast.counterspell_pending = false
	cast.counterspell_observers.clear()
	if await SpellCastMovement._resolve_spell_cast_movement(cast): return {"status":"resolved"}
	if not release_guard.call(): return {"status":"stale"}
	if await SpellCastMarkers._resolve_spell_cast_markers(cast): return {"status":"resolved"}
	if not release_guard.call(): return {"status":"stale"}
	await SpellCastTargeting.collect_targets(cast)
	await SpellCastReactions._prepare_spell_cast_effects(cast)
	if not release_guard.call(): return {"status":"stale"}
	await SpellCastResults._resolve_spell_cast_targets(cast)
	await SpellCastAreas._create_spell_cast_areas(cast)
	await SpellCastResults._finish_spell_cast(cast)
	return {"status":"resolved"}
