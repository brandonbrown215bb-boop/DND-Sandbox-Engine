class_name OrdinaryWorldActionFlow
extends RefCounted


static func choices(h: Node, combat: CombatState, operation: Callable, answers: Array, mutation: Callable = Callable(), ready_target: Variant = null) -> Dictionary:
	var done := {"done":false, "prompts":0, "menus":0}
	var seen := {}
	GameManager.test_mode = false
	ReadyActionFlow._run(operation, done)
	for _frame in 400:
		await h.get_tree().process_frame
		for child in combat.hud.get_children():
			if child is ConfirmationDialog and child.visible:
				if child.dialog_text.contains("readied trigger"):
					done.prompts += 1
					child.confirmed.emit()
				else: child.canceled.emit()
			if not child is PopupMenu or not child.visible or seen.has(child.get_instance_id()): continue
			seen[child.get_instance_id()] = true
			done.menus += 1
			if mutation.is_valid(): mutation.call(); mutation = Callable()
			var answer := str(answers.pop_front()) if not answers.is_empty() else ""
			var picked := -1
			for index in child.item_count:
				if answer == "*" or child.get_item_text(index).to_lower() == answer.to_lower(): picked = index; break
			h._assert(answer.is_empty() or picked >= 0, "S237 selects an actually offered interaction: " + answer)
			if picked >= 0: child.id_pressed.emit(child.get_item_id(picked))
			child.hide()
		if not combat.ready_actions.selection.is_empty() and ready_target is Vector2i: await combat._on_hex_clicked(ready_target)
		if done.done: break
	GameManager.test_mode = true
	h._assert(done.done and answers.is_empty(), "S237 actual object/feature choices complete without a stuck continuation")
	return done


static func utilize(h: Node, combat: CombatState, actor: Character, position: Vector2i, answers: Array, mutation: Callable = Callable()) -> Dictionary:
	h._p_focus(combat, actor)
	await combat._on_hud_action("ordinary_action", {"action":"utilize", "action_cost":"free"})
	h._assert(combat.pending_action_type == "ordinary_utilize" and combat.turn_budget.can_spend("action"), "S237 Utilize object selection is reachable and unpaid")
	return await choices(h, combat, func(): await combat._on_hex_clicked(position), answers, mutation)


static func run(h: Node, combat: CombatState, actor: Character, other: Character, enemy: Dictionary) -> void:
	# A real completed item and a loaded renamed feature trigger Ready only after effects.
	combat.player_entities[0].hex_position = Vector2i.ZERO
	combat.player_entities[1].hex_position = Vector2i(-1, 0)
	combat.player_entities[2].hex_position = Vector2i(-2, 0)
	combat.player_entities[3].hex_position = Vector2i(-3, 0)
	enemy.hex_position = Vector2i(3, 0)
	combat._update_grid_entities()
	other.inventory.add_item("antidote")
	other.add_condition("poisoned", 10)
	await ReadyActionFlow.declare(h, combat, actor, {"kind":"ordinary", "action":"dodge"}, {"event":"action", "side":"ally", "actor_id":other.character_id})
	h._p_focus(combat, other)
	await ReadyActionFlow.answer(h, combat, func(): await combat._on_hud_action("use_item", {"item":{"id":"antidote"}}), null)
	h._assert(not other.has_condition("poisoned") and not combat.turn_budget.can_spend("action") and not actor.reaction_available, "S237 completed consumable effect publishes Ready after real item and Action payment")
	var feature: Dictionary = DataLoader.get_character_class("fixture:ordinary_actions").features_by_level["1"][0].duplicate(true)
	other.features.append(feature)
	other.feature_uses[feature.id] = 1
	await ReadyActionFlow.declare(h, combat, actor, {"kind":"ordinary", "action":"dodge"}, {"event":"action", "side":"ally", "actor_id":other.character_id})
	h._p_focus(combat, other)
	var before := combat.remaining_speed
	var selected := feature.duplicate(true); selected.selected_action = "dash"
	await ReadyActionFlow.answer(h, combat, func(): await combat._on_hud_action("use_feature", {"feature":selected}), null)
	h._assert(combat.remaining_speed > before and not combat.turn_budget.can_spend("bonus_action") and not actor.reaction_available, "S237 renamed paid feature triggers after Dash without borrowing interrupted budgets")
	await ReadyActionFlow.declare(h, combat, actor, {"kind":"ordinary", "action":"dodge"}, {"event":"action", "side":"ally", "actor_id":other.character_id})
	h._p_focus(combat, other)
	var serial := combat.ready_actions.serial
	await combat._on_hud_action("use_item", {"item":{"id":"antidote", "instance_id":"missing"}})
	h._assert(combat.ready_actions.serial == serial and actor.reaction_available and combat.turn_budget.can_spend("action"), "S237 refused item produces no fictitious completed action")
	combat.ready_actions.clear_owner(actor)
	var parent: Dictionary = DataLoader.get_character_class("fixture:ordinary_actions").features_by_level["1"][2].duplicate(true)
	other.features.append(parent)
	other.feature_uses[parent.id] = 1
	await ReadyActionFlow.declare(h, combat, actor, {"kind":"ordinary", "action":"dodge"}, {"event":"action", "side":"ally", "actor_id":other.character_id})
	h._p_focus(combat, other)
	var parent_choice := await choices(h, combat, func(): await combat._on_hud_action("use_feature", {"feature":parent}), ["*"])
	h._assert(parent_choice.prompts == 0 and not combat.child_actions.frame.is_empty() and not combat.turn_budget.can_spend("action") and actor.reaction_available, "S237 paying a parent and choosing its first child does not prematurely trigger Ready")
	await ReadyActionFlow.answer(h, combat, func(): await combat._on_hud_action("cancel", {}), null)
	h._assert(combat.child_actions.frame.is_empty() and not actor.reaction_available and not combat.turn_budget.can_spend("action"), "S237 forfeiting the paid parent completes its event once without refunding the interrupted Action")
	# Supply the represented room consumed by the actual encounter grid.
	var old_room: Dictionary = GameManager.transition_context.get("local_room", {})
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/fixtures/ordinary_actions/room.json"))
	definition.cells = []
	for position in combat.hex_grid.tiles: definition.cells.append([position.x, position.y])
	var room := LocalRoomRules.create(definition, [actor, other])
	GameManager.transition_context["local_room"] = room
	var door := LocalRoomRules.get_object(room, "fixture:door")
	var chest := LocalRoomRules.get_object(room, "fixture:chest")
	combat._update_grid_entities()
	var result := await utilize(h, combat, actor, Vector2i(1, 0), ["Open"])
	h._assert(door.open and not combat.turn_budget.can_spend("action") and result.menus == 1 and combat.hex_grid.is_hex_passable(Vector2i(1, 0)), "S237 Utilize opens exact persistent room door and refreshes real movement blocking with one canonical Action")
	result = await utilize(h, combat, actor, Vector2i(1, 0), [])
	h._assert(door.open and combat.turn_budget.can_spend("action"), "S237 cancelling object operation costs nothing")
	var nonparty: Character = combat.player_entities[2].character
	var nonparty_position: Vector2i = combat.player_entities[2].hex_position
	combat.player_entities[2].hex_position = Vector2i.ZERO
	result = await utilize(h, combat, nonparty, Vector2i(1, 0), ["Close"])
	h._assert(not door.open and not room.party_positions.has(nonparty.character_id), "S237 combat-only participants use live origin without entering the durable party-position map")
	combat.player_entities[2].hex_position = nonparty_position
	result = await utilize(h, combat, actor, Vector2i(0, 1), ["Take", "*"])
	h._assert(not actor.inventory.get_instance("fixture:chest:potion").is_empty() and chest.contents.is_empty() and not combat.turn_budget.can_spend("action"), "S237 Utilize transfers the exact room item once")
	var records := actor.inventory.backpack_instances()
	var item_label := ""
	for index in records.size():
		if records[index].instance_id == "fixture:chest:potion": item_label = InventoryCopies.display_name(records[index], index + 1)
	result = await utilize(h, combat, actor, Vector2i(0, 1), ["Put", item_label])
	h._assert(actor.inventory.get_instance("fixture:chest:potion").is_empty() and chest.contents.size() == 1 and not combat.turn_budget.can_spend("action"), "S237 actual Put chooser stows the selected exact copy with one Action")
	var current := func(): return combat._can_spend_action_cost("action")
	var pay := func(): return combat._spend_action_cost("action")
	var replay := CombatUtilizeRules.settle(combat, actor, room, chest, Vector2i(0, 1), "take", "fixture:chest:potion", current, pay)
	h._assert(replay.status == "stale" and chest.contents.size() == 1, "S237 replay without Action cannot mutate the room")
	# Missing tools refuse; a failed actual roll still spends and consumes matching Help.
	door.open = false; door.locked = true
	result = await utilize(h, combat, actor, Vector2i(1, 0), ["Pick lock"])
	h._assert(combat.turn_budget.can_spend("action") and door.locked, "S237 missing tool refuses without Action payment")
	actor.inventory.add_item("thieves_tools")
	other.skill_proficiencies.append("Sleight of Hand")
	var help := CheckHelpRules.grant(other, actor, "skill", "Sleight of Hand")
	h._assert(help.get("success", false), "S237 fixture grants an actual owned matching Help source")
	FighterChecks._seed_die(20, 1)
	result = await utilize(h, combat, actor, Vector2i(1, 0), ["Pick lock"])
	h._assert(door.locked and not combat.turn_budget.can_spend("action"), "S237 failed live tool attempt spends its Action while leaving the actual lock intact")
	h._assert(actor.combat_check_help.is_empty(), "S237 actual object check consumes matching spatial Help: " + str(actor.combat_check_help))
	await noise_routes(h, combat, actor, other, door)
	await sound_snapshot(h, combat, actor, other, door)
	# A changed budget, removed/replaced object, moved target, altitude or plane cannot be used.
	door.locked = false
	result = await utilize(h, combat, actor, Vector2i(1, 0), ["Open"], func(): combat.turn_budget.spend("action"))
	h._assert(not door.open, "S237 lost Action during operation choice cannot change object")
	result = await utilize(h, combat, actor, Vector2i(1, 0), ["Open"], func(): combat.player_entities[0].hex_position = Vector2i(-2, 1))
	h._assert(not door.open and combat.turn_budget.can_spend("action"), "S237 lost proximity during operation choice refuses before payment")
	combat.player_entities[0].hex_position = Vector2i.ZERO
	result = await utilize(h, combat, actor, Vector2i(1, 0), ["Open"], func(): h._p_focus(combat, other))
	h._assert(not door.open and combat.turn_budget.can_spend("action"), "S237 changed owner/turn cannot finish an old object choice or charge the new owner")
	result = await utilize(h, combat, actor, Vector2i(1, 0), ["Open"], func(): door.removed = true)
	h._assert(not door.open and combat.turn_budget.can_spend("action"), "S237 removed object refuses before payment")
	door.removed = false
	h._p_focus(combat, actor)
	await combat._on_hud_action("ordinary_action", {"action":"utilize"})
	door.position = [1, -1]
	await combat._on_hex_clicked(Vector2i(1, 0))
	h._assert(not door.open and combat.turn_budget.can_spend("action"), "S237 old highlighted cell cannot operate a moved object")
	door.position = [1, 0]
	combat._cancel_pending_action()
	var copy := door.duplicate(true)
	result = await utilize(h, combat, actor, Vector2i(1, 0), ["Open"], func(): room.objects[0] = copy)
	h._assert(not copy.open and combat.turn_budget.can_spend("action"), "S237 replacement with same authored object ID cannot inherit a stale choice")
	room.objects[0] = door
	combat.player_entities[0].altitude_feet = 10
	h._assert(not CombatUtilizeRules.targets(combat, actor).has(Vector2i(1, 0)), "S237 flying above an object cannot interact across vertical reach")
	combat.player_entities[0].altitude_feet = 0
	door.plane = "ethereal"
	h._assert(not CombatUtilizeRules.targets(combat, actor).has(Vector2i(1, 0)), "S237 object interactions cannot cross planes")
	door.erase("plane")
	# A loose object under the owner uses exact object identity despite the creature sharing its hex.
	await ReadyActionFlow.declare(h, combat, actor, {"kind":"ordinary", "action":"utilize"}, {"event":"action", "side":"ally", "actor_id":other.character_id})
	h._p_focus(combat, other)
	before = combat.remaining_speed
	result = await choices(h, combat, func(): await combat._on_hud_action("ordinary_action", {"action":"dash"}), [], Callable(), Vector2i.ZERO)
	h._assert(actor.reaction_available and combat.ready_actions.held.has(actor.character_id) and actor.inventory.get_instance("fixture:ground:potion").is_empty(), "S237 cancelling readied Utilize preserves held response and owning Reaction")
	h._p_focus(combat, other)
	result = await choices(h, combat, func(): await combat._on_hud_action("ordinary_action", {"action":"dash"}), ["Take", "*"], Callable(), Vector2i.ZERO)
	h._assert(result.prompts == 1 and not actor.reaction_available and not actor.inventory.get_instance("fixture:ground:potion").is_empty() and not combat.turn_budget.can_spend("action") and combat.remaining_speed > before, "S237 readied Utilize takes a real co-located object with one owning Reaction and preserves the interrupted Dash")
	GameManager.transition_context["local_room"] = old_room


static func noise_routes(h: Node, combat: CombatState, actor: Character, listener: Character, door: Dictionary) -> void:
	# The loaded declaration survives renaming; it is not a door-ID dispatch.
	var old_id := str(door.id)
	door.id = "fixture:renamed_noisy_object"
	actor.add_condition("invisible", 100, "fixture:noise_cloak")
	OrdinaryActionRules.hide(actor, combat._ability_check_context(actor))
	# No Ready owner: noise still ends Hide after a failed but paid attempt.
	FighterChecks._seed_die(20, 1)
	await utilize(h, combat, actor, Vector2i(1, 0), ["Force open"])
	h._assert(not door.open and not combat.turn_budget.can_spend("action") and not actor.has_condition("hidden") and actor.combat_hide_dc == 0 and actor.condition_sources.get("invisible", {}).has("fixture:noise_cloak"), "S237 failed authored loud attempt ends Hide without any Ready owner and preserves independent Invisibility")
	# Quiet operations, cancelled choices, invalid declarations and missing tools
	# must not manufacture sounds or spend the observing owner's Reaction.
	await ReadyActionFlow.declare(h, combat, listener, {"kind":"ordinary", "action":"dodge"}, {"event":"sound", "side":"ally", "actor_id":actor.character_id})
	h._p_focus(combat, actor)
	OrdinaryActionRules.hide(actor, combat._ability_check_context(actor))
	var result := await utilize(h, combat, actor, Vector2i(1, 0), [])
	h._assert(result.prompts == 0 and actor.has_condition("hidden") and combat.turn_budget.can_spend("action") and listener.reaction_available, "S237 cancelled loud-operation chooser stays silent and preserves Hide/Action/Ready")
	actor.inventory.remove_item("crowbar")
	result = await utilize(h, combat, actor, Vector2i(1, 0), ["Pry"])
	h._assert(result.prompts == 0 and actor.has_condition("hidden") and combat.turn_budget.can_spend("action") and listener.reaction_available, "S237 missing-tool refusal makes no sound and preserves Hide/Action/Ready")
	var authored: Dictionary = door.interaction_noise.force_open
	door.interaction_noise.force_open = {"volume":"loud", "range_feet":0}
	result = await utilize(h, combat, actor, Vector2i(1, 0), ["Force open"])
	h._assert(result.prompts == 0 and actor.has_condition("hidden") and combat.turn_budget.can_spend("action") and not door.open, "S237 invalid noise declaration refuses before object mutation, roll or cost")
	door.interaction_noise.force_open = authored
	listener.add_condition("deafened", 10)
	FighterChecks._seed_die(20, 1)
	result = await utilize(h, combat, actor, Vector2i(1, 0), ["Force open"])
	h._assert(result.prompts == 0 and listener.reaction_available and not actor.has_condition("hidden") and not combat.turn_budget.can_spend("action"), "S237 actual loud attempt ends Hide but cannot trigger a Deafened Ready owner")
	listener.remove_condition("deafened")
	listener.add_condition("blinded", 10)
	OrdinaryActionRules.hide(actor, combat._ability_check_context(actor))
	FighterChecks._seed_die(20, 1)
	result = await utilize(h, combat, actor, Vector2i(1, 0), ["Force open"])
	h._assert(result.prompts == 1 and not listener.reaction_available and not combat.ready_actions.held.has(listener.character_id) and not combat.turn_budget.can_spend("action") and actor.combat_hide_dc == 0, "S237 actual paid loud failure triggers one owning Reaction despite Invisibility/Blinded without borrowing interrupted budget")
	listener.remove_condition("blinded")
	# Whisper metadata on the same real operation neither ends Hide nor discloses
	# a new location. Its actual lock/door result and Action still settle.
	door.interaction_noise.force_open = {"volume":"whisper", "range_feet":5}
	await ReadyActionFlow.declare(h, combat, listener, {"kind":"ordinary", "action":"dodge"}, {"event":"sound", "side":"ally", "actor_id":actor.character_id})
	h._p_focus(combat, actor)
	OrdinaryActionRules.hide(actor, combat._ability_check_context(actor))
	FighterChecks._seed_die(20, 1)
	result = await utilize(h, combat, actor, Vector2i(1, 0), ["Force open"])
	h._assert(result.prompts == 0 and listener.reaction_available and actor.has_condition("hidden") and not combat.turn_budget.can_spend("action") and not door.open, "S237 authored whisper retains Hide and cannot trigger loud-sound Ready while the actual attempt and Action settle")
	combat.ready_actions.clear_owner(listener)
	door.interaction_noise.force_open = authored
	actor.remove_condition("invisible")
	OrdinaryActionRules.remove_hidden(actor)
	door.id = old_id
	combat._update_grid_entities()


static func sound_snapshot(h: Node, combat: CombatState, source: Character, first: Character, door: Dictionary) -> void:
	var second: Character = combat.player_entities[2].character
	var saved_first: Vector2i = combat.player_entities[1].hex_position
	var saved_second: Vector2i = combat.player_entities[2].hex_position
	combat.player_entities[1].hex_position = Vector2i(0, 1)
	combat.player_entities[2].hex_position = Vector2i(2, 0)
	door.locked = false
	var trigger := {"event":"sound", "side":"ally", "actor_id":source.character_id}
	# First response opens a closed door; the second owner never heard that
	# earlier sound, even though the geometry now has an open ray.
	door.open = false
	combat._update_grid_entities()
	await ReadyActionFlow.declare(h, combat, first, {"kind":"ordinary", "action":"utilize"}, trigger)
	await ReadyActionFlow.declare(h, combat, second, {"kind":"ordinary", "action":"dodge"}, trigger)
	h._p_focus(combat, source)
	await combat._on_hud_action("ordinary_action", {"action":"utilize"})
	FighterChecks._seed_die(20, 1)
	var result := await choices(h, combat, func(): await combat._on_hex_clicked(Vector2i(1, 0)), ["Force open", "Open"], Callable(), Vector2i(1, 0))
	h._assert(result.prompts == 1 and door.open and not first.reaction_available and second.reaction_available and combat.ready_actions.held.has(second.character_id) and not combat.turn_budget.can_spend("action"), "S237 opening a door in an earlier Ready response cannot make a blocked sound retroactively audible")
	combat.ready_actions.clear_owner(second)
	# The reverse: first closes the door, but second already heard the sound.
	# Add a declared sound to the real Take operation on the nearby chest so
	# the original door is open at emission and closes during its response.
	var chest := LocalRoomRules.get_object(LocalRoomCombat.room(), "fixture:chest")
	chest["interaction_noise"] = {"take":{"volume":"loud", "range_feet":60}}
	await ReadyActionFlow.declare(h, combat, first, {"kind":"ordinary", "action":"utilize"}, trigger)
	await ReadyActionFlow.declare(h, combat, second, {"kind":"ordinary", "action":"dodge"}, trigger)
	h._p_focus(combat, source)
	await combat._on_hud_action("ordinary_action", {"action":"utilize"})
	result = await choices(h, combat, func(): await combat._on_hex_clicked(Vector2i(0, 1)), ["Take", "*", "Close"], Callable(), Vector2i(1, 0))
	h._assert(result.prompts == 2 and not door.open and not first.reaction_available and not second.reaction_available and not combat.ready_actions.held.has(second.character_id), "S237 closing a door in an earlier Ready response cannot erase a sound already heard")
	# Restore the exact item for the remaining interaction checks.
	var record := source.inventory.remove_exact("fixture:chest:potion", "stow")
	if not record.is_empty(): chest.contents.append(record)
	chest.erase("interaction_noise")
	combat.player_entities[1].hex_position = saved_first
	combat.player_entities[2].hex_position = saved_second
	combat._update_grid_entities()
