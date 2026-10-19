## Encounter-local parent/child continuation. The existing combat routes resolve children.
class_name CombatChildActions
extends RefCounted

var frame: Dictionary = {}
var receipts: Array[Dictionary] = []
var serial := 0

static func units(definition: Dictionary) -> int:
	var rule: Variant = definition.get("attack_unit_substitution", {})
	if not rule is Dictionary or rule.size() != 1: return 0
	var count: Variant = rule.get("units")
	return int(count) if (count is int or count is float) and count == int(count) and int(count) in [1, 2] else 0

static func content_error(feature: Dictionary) -> String:
	if feature.get("executor") != "class_feature" or feature.get("type") != "active" or feature.get("action_cost") not in ["action", "bonus_action", "reaction"]: return "Child actions require an active Action, Bonus Action or Reaction parent."
	if feature.has("resource_pool") or feature.has("resource_exchange") or ["temporary_hp_grant", "allocation", "transfer_grant", "roll_intervention", "attack_unit_substitution"].any(func(field): return feature.has(field)) or not feature.get("effects", []).is_empty(): return "A child parent uses ordinary feature uses and only its declared children."
	if feature.get("uses_per") not in ["turn", "combat", "short_rest", "long_rest", "rest"] or int(feature.get("resource_cost", 1)) < 1: return "A child parent requires feature uses and recovery."
	var rule: Variant = feature.get("child_actions")
	if not rule is Dictionary or rule.size() != 3 or rule.get("cancel_policy") not in ["stop", "skip"] or not rule.get("classification") is String or str(rule.classification).is_empty(): return "Child actions require classification, cancel_policy (stop/skip), and children."
	var children: Variant = rule.get("children")
	if not children is Array or children.is_empty() or children.size() > 12: return "Declare 1–12 child actions."
	var ids: Array = []
	for child in children:
		if not child is Dictionary or not child.get("id") is String or str(child.id).is_empty() or child.id in ids: return "Each child requires a distinct ID."
		ids.append(child.id)
		if child.get("kind") not in ["strike", "cast", "move"]: return "Unsupported child action kind."
		var fields: Array = ["id", "kind", "spell_id"] if child.kind == "cast" else ["id", "kind", "distance"] if child.kind == "move" else ["id", "kind"]
		if child.size() != fields.size(): return "Unsupported child action fields."
		for field in fields:
			if not child.has(field): return "Missing child action field."
		if child.kind == "cast" and (not child.spell_id is String or str(child.spell_id).is_empty()): return "A cast child requires a spell ID."
		if child.kind == "move" and (not (child.distance is int or child.distance is float) or child.distance != int(child.distance) or int(child.distance) < 1 or int(child.distance) > 24): return "Move distance must be 1–24 hexes."
	return ""

static func available(actor: Character, feature: Dictionary, budget: CombatTurnBudget) -> bool:
	if not content_error(feature).is_empty(): return false
	var cost := str(feature.action_cost)
	return (actor.reaction_available if cost == "reaction" else budget.can_spend(cost)) and int(actor.feature_uses.get(str(feature.get("resource_id", feature.id)), 0)) >= int(feature.get("resource_cost", 1))

func valid(host: Node) -> bool:
	if frame.is_empty(): return false
	var actor: Character = frame.actor
	return is_instance_valid(host) and host.is_inside_tree() and not host._battle_ending and host.active_character == actor and actor.is_alive and not CombatAction.is_incapacitated(actor) and int(frame.turn) == CombatAction.active_turn_serial and actor.get_feature(str(frame.feature.id)) == frame.feature

func start(host: Node, feature: Dictionary) -> void:
	if not frame.is_empty() or not available(host.active_character, feature, host.turn_budget): return
	# Resolve capability references before parent payment; spell ownership is checked again at selection/commit.
	for child in feature.child_actions.children:
		if child.kind == "cast":
			var spell := DataLoader.get_spell(str(child.spell_id))
			if spell.get("execution") != "shared" or spell.get("casting_time", "action") != "action" or not SpellSupport.availability(spell).get("available", false) or SpellPermissionRules.payment_choices(host.active_character, str(child.spell_id)).is_empty():
				host.hud.add_log("A declared child spell is unavailable.")
				return
	var actor: Character = host.active_character
	if not actor.use_feature(str(feature.id)): return
	var cost := str(feature.action_cost)
	if cost == "reaction":
		actor.reaction_available = false
		for entry in host.player_entities:
			if entry.get("character") == actor: entry["reaction_available"] = false
	else: host._spend_action_cost(cost)
	serial += 1
	frame = {"actor":actor, "turn":CombatAction.active_turn_serial, "feature":feature.duplicate(true), "invocation":"child-parent:%d" % serial, "remaining":feature.child_actions.children.duplicate(true), "current":{}, "choosing":false, "settled":false}
	await choose(host)

func choose(host: Node) -> void:
	if not valid(host) or frame.remaining.is_empty():
		clear()
		return
	var invocation := str(frame.invocation)
	frame.choosing = true
	host.resolving_player_action = true
	var options: Array[String] = []
	var labels := {}
	for child in frame.remaining:
		options.append(str(child.id))
		labels[str(child.id)] = "%s: %s" % [str(child.kind).capitalize(), str(child.id)]
	var selected: String = await host.hud._request_popup_choice("Choose child action", options, labels)
	if str(frame.get("invocation", "")) != invocation: return
	host.resolving_player_action = false
	if not valid(host):
		clear()
		return
	frame.choosing = false
	if selected.is_empty():
		clear() # Closing the chooser ends the paid parent; never restarts it.
		return
	for child in frame.remaining:
		if str(child.id) == selected:
			frame.current = child.duplicate(true)
			break
	if frame.current.is_empty(): return
	frame.settled = false
	match str(frame.current.kind):
		"strike":
			host.pending_action_type = "attack"
			host._highlight_attack_targets()
		"move":
			host.pending_action_type = "child_move"
			host._highlight_reachable()
		"cast":
			frame.choosing = true
			host.resolving_player_action = true
			var payment: Dictionary = await host.hud.request_spell_payment(frame.actor, str(frame.current.spell_id))
			if not owns_child(invocation, selected): return
			if not valid(host):
				host.resolving_player_action = false
				clear()
				return
			var command := CombatCommand.from_hud_for_character("cast_spell", {"spell":payment}, frame.actor) if not payment.is_empty() else null
			var selection: SpellCastContext = host._spell_cast_context()
			# Selection callbacks belong to this exact child, even across a slot popup.
			selection.begin_targeting = func():
				if owns_child(invocation, selected) and valid(host): host._begin_spell_targeting()
			selection.publish_spell = func(spell: Dictionary):
				if owns_child(invocation, selected) and valid(host): host._replace_pending_cast_spell(spell)
			selection.reset_pending = func(flags: int):
				if owns_child(invocation, selected) and valid(host): host._reset_pending_spell_cast(flags)
			var accepted := command != null and await SpellCastSelection.choose(selection, command.payload.spell)
			if not owns_child(invocation, selected): return
			host.resolving_player_action = false
			frame.choosing = false
			if not valid(host) or not accepted:
				await cancel(host)
				return
			host.pending_spell_data["_parent_action_id"] = str(frame.feature.child_actions.classification)
			host._highlight_spell_targets()
	host.hud.add_log("Choose a target for %s. Cancel follows this parent's %s policy." % [selected, str(frame.feature.child_actions.cancel_policy)])

func owns_child(invocation: String, id: String) -> bool:
	return str(frame.get("invocation", "")) == invocation and str(frame.get("current", {}).get("id", "")) == id

func current(kind: String) -> bool:
	return not frame.is_empty() and str(frame.get("current", {}).get("kind", "")) == kind

func settle(host: Node) -> bool:
	if not valid(host) or frame.current.is_empty() or frame.settled: return false
	frame.settled = true
	receipts.append({"parent":frame.invocation, "source_id":frame.feature.id, "action_id":frame.feature.child_actions.classification, "child_id":frame.current.id, "kind":frame.current.kind})
	return true

func complete(host: Node) -> void:
	if frame.is_empty() or not frame.settled: return
	var id := str(frame.current.id)
	frame.remaining = frame.remaining.filter(func(child): return str(child.id) != id)
	frame.current = {}
	host.pending_action_type = ""
	host.pending_spell_data = {}
	await choose(host)

func cancel(host: Node) -> void:
	if frame.is_empty(): return
	if not valid(host) or frame.feature.child_actions.cancel_policy == "stop":
		clear()
	else:
		frame.settled = true # Skip only the selected child; no effect/payment receipt.
		await complete(host)

func clear() -> void:
	frame.clear()
