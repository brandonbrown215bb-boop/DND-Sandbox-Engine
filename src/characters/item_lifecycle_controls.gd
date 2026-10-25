## Player intents for exact item copies. No inventory or actor pool lives here.
class_name ItemLifecycleControls
extends RefCounted

static func copy_for(owner: Character, id: String) -> Dictionary:
	return owner.item_projections[id].copy if ItemProjectionRules.is_projected(owner, id) else owner.inventory.get_instance(id)

static func token(owner: Character, id: String) -> String:
	var projected := ItemProjectionRules.actor(owner, id)
	return JSON.stringify([owner.get_instance_id(), id, copy_for(owner, id), owner.exclusive_bonds, BondRules.rules(owner), projected.get_instance_id() if projected != null else 0, DataLoader.get_item(str(copy_for(owner, id).get("definition_id", ""))).get("actor_projection", {})])

static func offers(owner: Character) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if owner == null: return out
	BondRules.prune(owner)
	var copies := owner.inventory.owned_instances()
	for record in owner.item_projections.values(): copies.append(record.copy)
	for copy in copies:
		var id := str(copy.instance_id)
		var name := str(DataLoader.get_item(str(copy.definition_id)).get("name", copy.definition_id))
		var label := "%s [%s]" % [name, id]
		for rule in BondRules.rules(owner).values():
			if rule.target != "item": continue
			var bonded := BondRules.is_bonded(owner, str(rule.bond_id), id)
			if not bonded and not BondRules._eligible(owner, rule, id).is_empty(): continue
			out.append({"kind": "release" if bonded else "bond", "instance_id": id, "bond_id": str(rule.bond_id), "text": "%s %s: %s" % ["Release" if bonded else "Bond", str(rule.get("name", rule.bond_id)), label]})
		var policy := ItemProjectionRules._policy(str(copy.definition_id))
		if policy.is_empty(): continue
		var kind := "dismiss" if ItemProjectionRules.is_projected(owner, id) else "project"
		var price := cost(policy, kind)
		var charges := int(policy.get("activation", {}).get("charges", 0)) if kind == "project" else 0
		out.append({"kind": kind, "instance_id": id, "bond_id": "", "text": "%s %s (%s%s)" % [kind.capitalize(), label, CombatTurnBudget.cost_label(price), "; %d charges" % charges if charges > 0 else ""]})
		if kind == "dismiss" and policy.has("vessel"):
			out.append({"kind": "revert", "instance_id": id, "bond_id": "", "text": "Revert %s (%s)" % [label, CombatTurnBudget.cost_label(price)]})
	for offer in out: offer["token"] = token(owner, str(offer.instance_id))
	return out

static func cost(policy: Dictionary, kind: String) -> String:
	return str(policy.get("dismiss_cost", "none")) if kind in ["dismiss", "revert"] else str(policy.get("activation", {}).get("action_cost", "none")) if kind == "project" else "none"

static func error(owner: Character, offer: Dictionary, budget: Object) -> String:
	if owner == null or not owner.is_alive or FeatureModeRules.incapacitated(owner): return "That character cannot act."
	var id := str(offer.instance_id)
	var kind := str(offer.kind)
	if token(owner, id) != str(offer.token): return "That choice is no longer current."
	if not BondRules.held(owner, id): return "You no longer own that exact copy."
	if budget is ModeControls.OutsideCombat:
		if GameManager.current_state == GameManager.GameState.COMBAT: return "The room control is no longer current."
	else:
		if budget == null or budget.active_character != owner or budget.resolving_player_action or not budget.active_combatant.get("is_player", false): return "It is no longer that character's turn."
		if not budget.can_pay_mode_cost("free"): return "Finish the current action first."
	if kind in ["bond", "release"]:
		var rule: Dictionary = BondRules.rules(owner).get(str(offer.bond_id), {})
		if rule.is_empty() or rule.target != "item": return "That bond is no longer available."
		if kind == "bond": return BondRules._eligible(owner, rule, id)
		return "" if BondRules.is_bonded(owner, str(offer.bond_id), id) else "That copy is no longer bonded."
	if kind not in ["project", "dismiss", "revert"]: return "Unknown item control."
	var copy := copy_for(owner, id)
	var definition := DataLoader.get_item(str(copy.definition_id))
	var policy := ItemProjectionRules._policy(str(copy.definition_id))
	if policy.is_empty(): return "That item has no supported projection."
	if kind == "project":
		var blocked := ItemProjectionRules.project_error(owner, id)
		if not blocked.is_empty(): return blocked
		if bool(copy.state.get("degraded", false)): return "That copy has lost its magic."
		if bool(definition.get("requires_attunement", false)) and str(copy.state.get("attuned_to", "")) != owner.character_id: return "Attune that exact copy first."
		var activation: Dictionary = policy.get("activation", {})
		if not str(activation.get("bond_id", "")).is_empty() and not BondRules.is_bonded(owner, str(activation.bond_id), id): return "Bond that exact copy first."
		var charges := int(activation.get("charges", 0))
		if int(copy.state.get("charges", 0)) < charges: return "That copy has insufficient charges."
		if charges > 0 and definition.has("last_charge_aftermath"): return "Projection with last-charge aftermath is unsupported."
	elif not ItemProjectionRules.is_projected(owner, id): return "That exact form no longer exists."
	var price := cost(policy, kind)
	if not budget is ModeControls.OutsideCombat and not budget.can_pay_mode_cost("free" if price == "none" else CombatTurnBudget.budget_kind(price)): return "No %s is available." % CombatTurnBudget.cost_label(price)
	return ""

## Called synchronously after the chooser: validate everything before any cost.
static func apply(owner: Character, offer: Dictionary, host, origin: Vector2i, picks: Array, no_space: bool, budget: Object) -> Dictionary:
	var blocked := error(owner, offer, budget)
	if not blocked.is_empty(): return fail(blocked)
	var id := str(offer.instance_id)
	var kind := str(offer.kind)
	if kind == "bond":
		var result := BondRules.bond(owner, str(offer.bond_id), id, PartyManager.characters.values())
		return {"success": result.bonded, "message": "Exact copy bonded." if result.bonded else result.reason, "seconds": 0}
	if kind == "release":
		var released := BondRules.release(owner, str(offer.bond_id), id)
		return {"success": released, "message": "Exact copy released." if released else "The bond changed.", "seconds": 0}
	var policy := ItemProjectionRules._policy(str(copy_for(owner, id).definition_id))
	if kind == "project":
		var placement := PlacementRules.policy(policy)
		var size := str(policy.template.size)
		if PlacementRules._grid(host) == null or not PlacementRules._grid(host).has_tile(origin): return fail("The owner has no represented placement origin.")
		if no_space:
			if placement.no_space != "spend" or not PlacementRules.reserve(host, origin, size, int(placement.range_hexes), 1).is_empty(): return fail("The available placement changed; choose again.")
		else:
			if picks.size() != 1: return fail("Choose one legal destination.")
			blocked = PlacementRules.confirm_error(host, origin, size, int(placement.range_hexes), picks)
			if not blocked.is_empty(): return fail(blocked)
		# No suspension or world mutation between validation, payment and projection.
		var charges := int(policy.get("activation", {}).get("charges", 0))
		if charges > 0 and not owner.inventory.spend_instance_charges(id, charges): return fail("That copy's charges changed.")
		if not no_space:
			var projected := ItemProjectionRules.project(owner, id)
			if not projected.projected: return fail(str(projected.reason))
			if host is Dictionary:
				host.room.created_actor_positions[ItemProjectionRules.actor_id(id)] = [picks[0].x, picks[0].y]
			else:
				ItemProjectionRules.attach(host, owner, origin, {id: picks[0]})
	else:
		var result := ItemProjectionRules.revert(owner, id, int(owner.item_projections[id].copy.state.get("item_form_serial", 0)), "reverted" if kind == "revert" else "dismissed")
		if not result.reverted: return fail(str(result.reason))
		if not host is Dictionary: host._update_grid_entities()
	var price := cost(policy, kind)
	if not budget is ModeControls.OutsideCombat and price != "none": budget._spend_action_cost(CombatTurnBudget.budget_kind(price))
	return {"success": true, "message": "Activation paid; no space, so no form was created." if no_space else "Exact item projected." if kind == "project" else "Exact form dismissed.", "seconds": 0}

static func fail(message: String) -> Dictionary:
	return {"success": false, "message": message, "seconds": 0}
