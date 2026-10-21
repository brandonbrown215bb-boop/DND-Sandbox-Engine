## Spell-specific player choices at their existing cast boundaries.
class_name SpellCastChoices
extends RefCounted

static func choose_identify(cast: SpellCastContext) -> bool:
	if str(cast.spell.get("id", "")) == "identify":
		var identify_mode := await cast.hud.request_identify_mode(str(cast.spell.get("_test_identify_mode", "")))
		if identify_mode == "creature":
			var creature_id := SpellCastTargeting._identify_creature_id_at(cast, cast.target_coord)
			if creature_id.is_empty() or HexUtils.get_distance(cast.spell_origin, cast.target_coord) > 1:
				cast.hud.add_log("Identify needs a living creature within 5 feet, touched throughout the casting.")
				cast.highlight_reachable.call()
				return false
			cast.spell["_identify_target"] = {"kind": "creature", "target_id": creature_id}
		else:
			var carried_items: Array[Dictionary] = []
			for record in cast.caster.inventory.owned_instances():
				var item := DataLoader.get_item(str(record.get("definition_id", ""))).duplicate(true)
				if item.is_empty():
					continue
				item["id"] = str(record.get("instance_id", ""))
				item["definition_id"] = str(record.get("definition_id", ""))
				item["copy_state"] = record.get("state", {}).duplicate(true)
				carried_items.append(item)
			var chosen_item := await cast.hud.request_identify_item_choice(carried_items, str(cast.spell.get("_test_identify_item_id", "")))
			if chosen_item.is_empty():
				cast.hud.add_log("Identify needs an item you carry and can touch throughout the casting.")
				cast.highlight_reachable.call()
				return false
			var chosen_record := cast.caster.inventory.get_instance(chosen_item)
			cast.spell["_identify_target"] = {"kind": "item", "instance_id": chosen_item, "item_id": str(chosen_record.get("definition_id", ""))}
			cast.target_coord = cast.spell_origin
	return true


static func choose_dancing_lights(cast: SpellCastContext) -> bool:
	if str(cast.spell.get("id", "")) == "dancing_lights":
		if not cast.grid.has_tile(cast.target_coord) or not Targeting.is_in_range(cast.spell_origin, cast.target_coord, SpellCastTargeting._spell_target_range(cast, cast.spell)):
			cast.hud.add_log("[color=orange]Choose a space within Dancing Lights' range.[/color]")
			cast.highlight_reachable.call()
			return false
		var lights_form_choice := await cast.hud.request_dancing_lights_form()
		if not lights_form_choice.get("success", false):
			cast.clear_pending(SpellCastContext.CLEAR_ACTION)
			cast.clear_pending(SpellCastContext.CLEAR_SPELL)
			cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
			cast.clear_pending(SpellCastContext.CLEAR_WISH)
			cast.highlight_reachable.call()
			return false
		cast.spell["_dancing_lights_humanoid_form"] = bool(lights_form_choice.get("humanoid_form", false))
		cast.spell["_dancing_lights_count"] = clampi(int(lights_form_choice.get("light_count", 4)), 1, 4)
	return true


static func choose_spirit_guardians(cast: SpellCastContext) -> bool:
	if str(cast.spell.get("id", "")) == "spirit_guardians":
		var exempt_candidates: Array[Dictionary] = []
		for player_entity in cast.players:
			var candidate: Character = player_entity.get("character")
			if candidate != null and candidate.is_alive:
				exempt_candidates.append({"id": candidate.character_id, "name": candidate.character_name})
		for monster_entity in cast.monsters:
			if bool(monster_entity.get("is_alive", false)):
				exempt_candidates.append({"id": str(monster_entity.get("id", "")), "name": str(monster_entity.get("name", "Creature"))})
		cast.spell["_spirit_guardians_exempt_target_ids"] = await cast.hud.request_spirit_guardians_exemptions(exempt_candidates, cast.spell.get("_test_spirit_guardians_exempt_target_ids", []))
		var chosen_damage_type := "radiant"
		if GameManager.test_mode:
			chosen_damage_type = str(cast.spell.get("_test_spirit_guardians_damage_type", "radiant"))
		else:
			chosen_damage_type = await cast.hud.request_damage_type_choice(cast.spell.get("damage_type_choices", ["radiant", "necrotic"]), "Spirit Guardians alignment damage")
		if chosen_damage_type not in cast.spell.get("damage_type_choices", ["radiant", "necrotic"]):
			cast.clear_pending(SpellCastContext.CLEAR_ACTION)
			cast.clear_pending(SpellCastContext.CLEAR_SPELL)
			cast.highlight_reachable.call()
			return false
		cast.spell["_spirit_guardians_damage_type"] = chosen_damage_type
	return true


static func choose_utility_options(cast: SpellCastContext) -> bool:
	if str(cast.spell.get("id", "")) == "minor_illusion":
		if not cast.grid.has_tile(cast.target_coord) or not Targeting.is_in_range(cast.spell_origin, cast.target_coord, MinorIllusionRules.RANGE_HEXES):
			cast.hud.add_log("[color=orange]Choose a point within 30 feet for Minor Illusion.[/color]")
			cast.highlight_reachable.call()
			return false
		var illusion_choice: Dictionary = await cast.hud.request_minor_illusion()
		if not illusion_choice.get("success", false):
			cast.clear_pending(SpellCastContext.CLEAR_ACTION)
			cast.clear_pending(SpellCastContext.CLEAR_SPELL)
			cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
			cast.clear_pending(SpellCastContext.CLEAR_WISH)
			cast.highlight_reachable.call()
			return false
		cast.spell["_minor_illusion_form"] = str(illusion_choice.get("form", ""))
		cast.spell["_minor_illusion_description"] = str(illusion_choice.get("description", ""))
	if str(cast.spell.get("id", "")) == "prestidigitation":
		if not cast.grid.has_tile(cast.target_coord) or not Targeting.is_in_range(cast.spell_origin, cast.target_coord, PrestidigitationRules.RANGE_HEXES):
			cast.hud.add_log("[color=orange]Choose a point within 10 feet for Prestidigitation.[/color]")
			cast.highlight_reachable.call()
			return false
		var prestidigitation_choice: Dictionary = await cast.hud.request_prestidigitation_effect()
		if not prestidigitation_choice.get("success", false):
			cast.clear_pending(SpellCastContext.CLEAR_ACTION)
			cast.clear_pending(SpellCastContext.CLEAR_SPELL)
			cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
			cast.clear_pending(SpellCastContext.CLEAR_WISH)
			cast.highlight_reachable.call()
			return false
		var chosen_effect_type := str(prestidigitation_choice.get("effect_type", ""))
		var current_effects: Array = cast.prestidigitation_effects.get(cast.caster.character_id, [])
		if not PrestidigitationRules.is_instantaneous(chosen_effect_type) and current_effects.size() >= PrestidigitationRules.MAX_ACTIVE_EFFECTS:
			cast.hud.add_log("[color=orange]You already have three non-instantaneous Prestidigitation effects active.[/color]")
			cast.highlight_reachable.call()
			return false
		cast.spell["_prestidigitation_effect_type"] = chosen_effect_type
		cast.spell["_prestidigitation_description"] = str(prestidigitation_choice.get("description", ""))
	if str(cast.spell.get("id", "")) == "alter_self":
		var natural_damage_type := await cast.hud.request_damage_type_choice(["slashing", "piercing", "bludgeoning"], "Alter Self — Natural Weapons (supported option)")
		if natural_damage_type not in ["slashing", "piercing", "bludgeoning"]:
			cast.hud.add_log("Choose a Natural Weapons damage type to cast Alter Self.")
			cast.highlight_reachable.call()
			return false
		cast.spell["_alter_self_natural_damage_type"] = natural_damage_type
	if str(cast.spell.get("id", "")) == "true_strike":
		var strike_weapon: Dictionary = DataLoader.get_item(str(cast.spell.get("_true_strike_weapon_id", "")))
		var normal_damage_type := str(strike_weapon.get("damage_type", "bludgeoning"))
		var strike_damage_options: Array = [normal_damage_type]
		if normal_damage_type != "radiant":
			strike_damage_options.append("radiant")
		var selected_strike_type := await cast.hud.request_damage_type_choice(strike_damage_options, "True Strike")
		if selected_strike_type not in [normal_damage_type, "radiant"]:
			cast.hud.add_log("Choose the True Strike attack's damage type.")
			cast.highlight_reachable.call()
			return false
		cast.spell["_true_strike_damage_type"] = selected_strike_type
	return true


static func choose_orders_and_types(cast: SpellCastContext) -> bool:
	if str(cast.spell.get("id", "")) == "animal_messenger":
		var messenger_target: Dictionary = {}
		for monster in cast.monsters:
			if monster.get("hex_position", Vector2i.ZERO) == cast.target_coord and monster.get("is_alive", false):
				messenger_target = monster
				break
		if messenger_target.is_empty():
			cast.hud.add_log("[color=orange]Animal Messenger needs a Tiny Beast in the combat encounter.[/color]")
			cast.highlight_reachable.call()
			return false
		var visited_locations := GameManager.get_visited_overworld_locations()
		if is_zero_approx(float(messenger_target.get("challenge_rating", 0.0))):
			if visited_locations.is_empty():
				cast.hud.add_log("[color=orange]Animal Messenger needs a destination the party has already visited.[/color]")
				cast.highlight_reachable.call()
				return false
			if GameManager.animal_messenger_deliveries.size() >= AnimalMessengerRules.MAX_SAVED_DELIVERIES:
				cast.hud.add_log("[color=orange]The campaign messenger ledger is full.[/color]")
				cast.highlight_reachable.call()
				return false
			var messenger_order: Dictionary = await cast.hud.request_animal_messenger_order(visited_locations)
			var order_validation := GameManager.validate_animal_messenger_order(messenger_order)
			if not order_validation.get("success", false):
				cast.hud.add_log("[color=orange]%s[/color]" % order_validation.get("message", "Animal Messenger was cancelled."))
				cast.highlight_reachable.call()
				return false
			cast.spell["_animal_messenger_order"] = order_validation
	if str(cast.spell.get("id", "")) == "message":
		var message_target: Character = null
		var message_target_owner := -1
		for player in cast.players:
			var candidate: Character = player.get("character")
			if player.get("hex_position", Vector2i.ZERO) == cast.target_coord and candidate != null and candidate.is_alive:
				message_target = candidate
				message_target_owner = int(player.get("owner_player_index", -1))
				break
		if message_target == null:
			cast.hud.add_log("[color=orange]Message currently needs a living party character to receive the hot-seat whisper.[/color]")
			cast.highlight_reachable.call()
			return false
		cast.spell["_message_target_id"] = message_target.character_id
		cast.spell["_message_target_owner"] = message_target_owner
	var damage_type_options: Array = cast.spell.get("damage_type_options", [])
	if not damage_type_options.is_empty():
		var selected_damage_type := await cast.hud.request_damage_type_choice(damage_type_options, str(cast.spell.get("name", "Spell")))
		if selected_damage_type.is_empty():
			cast.hud.add_log("Choose a damage type to cast %s." % cast.spell.get("name", "the spell"))
			cast.highlight_reachable.call()
			return false
		cast.spell["damage_type"] = selected_damage_type
	var condition_options: Array = cast.spell.get("condition_options", [])
	if not condition_options.is_empty():
		var selected_condition := await cast.hud.request_damage_type_choice(condition_options, str(cast.spell.get("name", "Spell")))
		if selected_condition not in condition_options:
			cast.hud.add_log("Choose a condition for %s." % str(cast.spell.get("name", "the spell")))
			cast.highlight_reachable.call()
			return false
		cast.spell["condition_on_failed_save"] = selected_condition
	return true


static func choose_target_options(cast: SpellCastContext) -> bool:
	if str(cast.spell.get("id", "")) == "command":
		var chosen_command := await cast.hud.request_command_choice()
		if chosen_command.is_empty():
			cast.hud.add_log("Choose a command to cast Command.")
			cast.highlight_reachable.call()
			return false
		cast.spell["_command_choice"] = chosen_command
	if str(cast.spell.get("id", "")) == "guidance":
		var chosen_guidance_skill := await cast.hud.request_guidance_skill_choice()
		if chosen_guidance_skill.is_empty():
			cast.hud.add_log("Choose a skill to cast Guidance.")
			cast.highlight_reachable.call()
			return false
		cast.spell["_guidance_skill"] = chosen_guidance_skill
	if str(cast.spell.get("id", "")) == "resistance":
		var chosen_resistance_type := await cast.hud.request_resistance_damage_type()
		if chosen_resistance_type.is_empty():
			cast.hud.add_log("Choose a damage type to cast Resistance.")
			cast.highlight_reachable.call()
			return false
		cast.spell["_resistance_damage_type"] = chosen_resistance_type
	if str(cast.spell.get("id", "")) == "protection_from_energy":
		var energy_type := await cast.hud.request_damage_type_choice(["acid", "cold", "fire", "lightning", "thunder"], "Protection from Energy")
		if energy_type.is_empty():
			cast.hud.add_log("Choose a damage type for Protection from Energy.")
			cast.highlight_reachable.call()
			return false
		cast.spell["_protection_from_energy_type"] = energy_type
	if str(cast.spell.get("id", "")) == "conjure_elemental":
		var elemental_choice := str(cast.spell.get("_test_conjure_elemental_type", ""))
		if elemental_choice.is_empty():
			elemental_choice = await cast.hud.request_conjure_elemental_element()
		var elemental_types: Dictionary = cast.spell.get("element_choices", {})
		if not elemental_types.has(elemental_choice):
			cast.hud.add_log("Choose Air, Earth, Fire, or Water for Conjure Elemental.")
			cast.highlight_reachable.call()
			return false
		cast.spell["_conjure_elemental_choice"] = elemental_choice
		cast.spell["damage_type"] = str(elemental_types[elemental_choice])

	if str(cast.spell.get("id", "")) == "enhance_ability":
		var enhance_choices: Dictionary = {}
		var enhance_target_coords: Array[Vector2i] = [cast.target_coord]
		enhance_target_coords.append_array(cast.extra_target_coords)
		if cast.additional_target_coord != Vector2i(9999, 9999):
			enhance_target_coords.append(cast.additional_target_coord)
		for enhance_coord in enhance_target_coords:
			var coord_key := "%d,%d" % [enhance_coord.x, enhance_coord.y]
			if enhance_choices.has(coord_key):
				continue
			for party_entity in cast.players:
				var enhance_target: Character = party_entity.get("character")
				if enhance_target == null or not enhance_target.is_alive or party_entity.get("hex_position", Vector2i.ZERO) != enhance_coord:
					continue
				var seeded_enhance := str(cast.spell.get("_test_enhance_ability_choices", {}).get(coord_key, cast.spell.get("_test_enhance_ability_choice", "")))
				var enhance_choice := await cast.hud.request_enhance_ability_choice(enhance_target.character_name, seeded_enhance)
				if enhance_choice.is_empty():
					cast.hud.add_log("Choose an ability for each Enhance Ability target.")
					cast.highlight_reachable.call()
					return false
				enhance_choices[coord_key] = enhance_choice
				break
		cast.spell["_enhance_ability_choices"] = enhance_choices
	return true


## Card Q-20261020-173959-7e2c: shared chooser for a projection's declared form and
## legal equipment policy, asked before any cost. Cancel or a stale answer spends nothing.
static var _projection_request_serial := 0

const EQUIPMENT_LABELS := {"merged": "Merged — gear melds into the form", "worn": "Worn — gear stays worn", "dropped": "Dropped — gear is set aside"}

static func projection_options(spell: Dictionary) -> Dictionary:
	var effect := ActorProjectionRules._effect(spell)
	if effect.is_empty(): return {}
	var forms: Array = []
	for f in effect.get("forms", []):
		forms.append({"id": str(f.id), "label": "%s (%s %s, speed %d)" % [str(f.name), str(f.size), str(f.creature_type), int(f.speed)]})
	var equipment: Array = []
	for policy in effect.get("equipment", []):
		equipment.append({"id": str(policy), "label": str(EQUIPMENT_LABELS.get(str(policy), str(policy)))})
	return {"forms": forms, "equipment": equipment}

## One popup; returns {"value"} on a current answer, {"canceled"} or {"stale"} otherwise.
static func _ask_projection(cast: SpellCastContext, title: String, options: Array) -> Dictionary:
	_projection_request_serial += 1
	var mine := _projection_request_serial
	var ids: Array[String] = [""]
	var labels := {"": "Cancel"}
	for o in options:
		ids.append(str(o.id))
		labels[str(o.id)] = str(o.label)
	var picked: String = await cast.hud._request_popup_choice(title, ids, labels)
	if mine != _projection_request_serial or (cast.commit_guard.is_valid() and not cast.commit_guard.call()): return {"stale": true}
	if picked.is_empty() or options.all(func(o): return str(o.id) != picked): return {"canceled": true}
	return {"value": picked}

static func choose_projection_options(cast: SpellCastContext) -> bool:
	var options := projection_options(cast.spell)
	if options.is_empty(): return true
	# Normal refusals (already in another form) stay with validate_actor; nothing to choose then.
	if ActorProjectionRules.is_projected(cast.caster) or DruidRules.is_shaped(cast.caster): return true
	# Every cast chooses afresh: no pick carries over from an earlier popup.
	cast.spell.erase("_projection_form_id")
	cast.spell.erase("_projection_equipment")
	var picks := {"forms": "_projection_form_id", "equipment": "_projection_equipment"}
	var titles := {"forms": "Choose a form", "equipment": "Choose how equipment is handled"}
	for kind in ["forms", "equipment"]:
		if options[kind].size() < 2: continue
		if cast.hud == null: return false
		var answer := await _ask_projection(cast, titles[kind], options[kind])
		if answer.has("stale"):
			cast.spell.erase("_projection_form_id")
			cast.spell.erase("_projection_equipment")
			cast.hud.add_log("[color=orange]That choice is no longer current; nothing was spent.[/color]")
			return false # A newer cast owns the pending controls; leave them alone.
		if answer.has("canceled"):
			cast.hud.add_log("Casting canceled; nothing was spent.")
			cast.clear_pending(SpellCastContext.CLEAR_ACTION)
			cast.clear_pending(SpellCastContext.CLEAR_SPELL)
			cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
			cast.clear_pending(SpellCastContext.CLEAR_WISH)
			cast.highlight_reachable.call()
			return false
		cast.spell[picks[kind]] = str(answer.value)
	return true


## Batch 053 S-121/S-122: legal destinations for created actors, chosen and
## rechecked before any cost. Cancel, stale answers, a destination that became
## illegal before confirmation, or "refuse" with no legal space spend nothing.
static var _placement_request_serial := 0

static func _cancel_placement(cast: SpellCastContext, message: String) -> void:
	cast.spell.erase("_placement")
	cast.hud.add_log(message)
	cast.clear_pending(SpellCastContext.CLEAR_ACTION)
	cast.clear_pending(SpellCastContext.CLEAR_SPELL)
	cast.clear_pending(SpellCastContext.CLEAR_INTERVENTION)
	cast.clear_pending(SpellCastContext.CLEAR_WISH)
	if cast.highlight_reachable.is_valid(): cast.highlight_reachable.call()

static func choose_placement(cast: SpellCastContext) -> bool:
	cast.spell.erase("_placement") # Every cast places afresh.
	var effect := {}
	for e in cast.spell.get("effects", []):
		if e is Dictionary and e.get("type", "") == "create_actor": effect = e
	if effect.is_empty() or cast.grid == null or cast.player_index < 0 or cast.player_index >= cast.players.size(): return true
	var policy := PlacementRules.policy(effect)
	var factory: Dictionary = cast.spell.get("_factory", {})
	var template: Dictionary = CreatedActorRules._template(cast.spell, str(factory.get("template_id", "")))
	if template.is_empty(): template = effect.template
	var level := maxi(0, int(cast.spell.get("_selected_spell_slot_level", cast.spell.get("level", 0))) - int(cast.spell.get("level", 0)))
	var count := int(factory.get("count", CreatedActorRules.value(template.count, level)))
	var size := str(template.size)
	var reach := int(policy.range_hexes)
	var origin: Vector2i = cast.players[cast.player_index].get("hex_position", Vector2i.ZERO)
	var available := PlacementRules.reserve(cast, origin, size, reach, count)
	if available.is_empty():
		if policy.no_space == "spend":
			cast.spell["_placement"] = []
			cast.hud.add_log("There is no legal space for %d %s; casting anyway spends the cost and creates nothing." % [count, template.name])
			return true
		_cancel_placement(cast, "There is no legal space for %d %s within %d hexes; nothing was spent." % [count, template.name, reach])
		return false
	if not bool(policy.choose) or cast.hud == null:
		cast.spell["_placement"] = PlacementRules.encode(available)
		return true
	var picks: Array[Vector2i] = []
	for i in count:
		var options := PlacementRules.candidates(cast, origin, size, reach, picks)
		var ids: Array[String] = [""]
		var labels := {"": "Cancel"}
		for hex in options:
			var id := "%d,%d" % [hex.x, hex.y]
			ids.append(id)
			labels[id] = "Hex (%d, %d)" % [hex.x, hex.y]
		_placement_request_serial += 1
		var mine := _placement_request_serial
		var picked: String = await cast.hud._request_popup_choice("Place %s %d of %d" % [template.name, i + 1, count], ids, labels)
		if mine != _placement_request_serial or (cast.commit_guard.is_valid() and not cast.commit_guard.call()):
			cast.spell.erase("_placement")
			cast.hud.add_log("[color=orange]That choice is no longer current; nothing was spent.[/color]")
			return false # A newer cast owns the pending controls; leave them alone.
		if picked.is_empty() or picked not in ids:
			_cancel_placement(cast, "Casting canceled; nothing was spent.")
			return false
		var parts := picked.split(",")
		picks.append(Vector2i(int(parts[0]), int(parts[1])))
	var recheck := PlacementRules.confirm_error(cast, origin, size, reach, picks)
	if not recheck.is_empty():
		_cancel_placement(cast, "That space is no longer available (%s); nothing was spent." % recheck)
		return false
	cast.spell["_placement"] = PlacementRules.encode(picks)
	return true



## Batch 054 S-155: choose a permitted template and count before placement and
## before any cost. Cancel or a stale answer spends nothing; only declared
## options and counts are offered.
static var _factory_request_serial := 0

static func _ask_factory(cast: SpellCastContext, title: String, ids: Array[String], labels: Dictionary) -> Dictionary:
	_factory_request_serial += 1
	var mine := _factory_request_serial
	var picked: String = await cast.hud._request_popup_choice(title, ids, labels)
	if mine != _factory_request_serial or (cast.commit_guard.is_valid() and not cast.commit_guard.call()): return {"stale": true}
	if picked.is_empty() or picked not in ids: return {"canceled": true}
	return {"value": picked}

static func choose_factory(cast: SpellCastContext) -> bool:
	cast.spell.erase("_factory") # Every cast chooses afresh.
	var effect := CreatedActorRules._effect(cast.spell)
	if effect.is_empty(): return true
	var options := CreatedActorRules.templates(effect)
	var level := maxi(0, int(cast.spell.get("_selected_spell_slot_level", cast.spell.get("level", 0))) - int(cast.spell.get("level", 0)))
	var factory := {"template_id": str(options[0].id)}
	# Batch 059 S-155: declared material targets (corpses/bones) cap the count; none means no legal target.
	var material := MaterialTargetRules.cap(cast, effect)
	if not material.is_empty() and int(material.total) <= 0:
		_cancel_placement(cast, "There are no eligible remains within range; nothing was spent.")
		return false
	if CreatedActorRules.is_mixed(effect):
		return await _choose_mix(cast, effect, options, level, material)
	if options.size() > 1:
		if cast.hud == null: return false
		var ids: Array[String] = [""]
		var labels := {"": "Cancel"}
		for t in options:
			ids.append(str(t.id))
			labels[str(t.id)] = "%s (%s %s, up to %d)" % [t.name, t.size, t.creature_type, CreatedActorRules.value(t.count, level)]
		var answer := await _ask_factory(cast, "Choose a creature", ids, labels)
		if not _factory_answer_ok(cast, answer): return false
		factory.template_id = str(answer.value)
	var allowed := _capped(CreatedActorRules.counts(effect, CreatedActorRules._template(cast.spell, factory.template_id), level), material)
	factory["count"] = int(allowed[-1])
	if allowed.size() > 1:
		if cast.hud == null: return false
		var ids: Array[String] = [""]
		var labels := {"": "Cancel"}
		for n in allowed:
			ids.append(str(n))
			labels[str(n)] = str(n)
		var answer := await _ask_factory(cast, "How many to create?", ids, labels)
		if not _factory_answer_ok(cast, answer): return false
		factory.count = int(answer.value)
	cast.spell["_factory"] = factory
	return true

## Batch 058 S-155: a mixed cast asks how many of each declared kind, within the shared total.
static func _choose_mix(cast: SpellCastContext, effect: Dictionary, options: Array, level: int, material: Dictionary = {}) -> bool:
	if cast.hud == null: return false
	var allowed := _capped(CreatedActorRules.counts(effect, {}, level), material)
	var left := int(allowed[-1])
	var mix := {}
	for i in options.size():
		var t: Dictionary = options[i]
		var last := i == options.size() - 1
		var lo := maxi(0, int(allowed[0]) - _mix_total(mix)) if last else 0
		var hi := mini(left, int(material.kinds[str(t.id)])) if not material.is_empty() and material.kinds.has(str(t.id)) else left
		if lo > hi:
			_cancel_placement(cast, "There are not enough eligible remains for that combination; nothing was spent.")
			return false
		var ids: Array[String] = [""]
		var labels := {"": "Cancel"}
		for n in range(lo, hi + 1):
			ids.append(str(n))
			labels[str(n)] = str(n)
		var answer := await _ask_factory(cast, "How many %s? (up to %d)" % [t.name, hi], ids, labels)
		if not _factory_answer_ok(cast, answer): return false
		mix[str(t.id)] = int(answer.value)
		left -= int(answer.value)
	if not CreatedActorRules.mix_choice_error(effect, mix, level).is_empty() or not MaterialTargetRules.mix_cap_error(mix, material).is_empty():
		_cancel_placement(cast, "That combination is not permitted; nothing was spent.")
		return false
	cast.spell["_factory"] = {"template_id": str(options[0].id), "count": _mix_total(mix), "mix": mix}
	return true

## Batch 059: permitted counts no larger than the available material targets.
## A fixed count above the cap becomes the cap (the cast creates as many as it can).
static func _capped(allowed: Array, material: Dictionary) -> Array:
	if material.is_empty(): return allowed
	var out := allowed.filter(func(n): return int(n) <= int(material.total))
	return out if not out.is_empty() else [int(material.total)]

static func _mix_total(mix: Dictionary) -> int:
	var total := 0
	for id in mix: total += int(mix[id])
	return total

static func _factory_answer_ok(cast: SpellCastContext, answer: Dictionary) -> bool:
	if answer.has("stale"):
		cast.spell.erase("_factory")
		cast.hud.add_log("[color=orange]That choice is no longer current; nothing was spent.[/color]")
		return false
	if answer.has("canceled"):
		cast.spell.erase("_factory")
		_cancel_placement(cast, "Casting canceled; nothing was spent.")
		return false
	return true
