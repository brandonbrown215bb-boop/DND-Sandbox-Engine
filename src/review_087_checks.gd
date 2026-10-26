class_name Review087Checks
extends RefCounted
## Review 087 (runtime-reviewer): function-level checks for the shared route
## host CombatState._route_damage_choice (Batch 087, S-127). The host never
## spends a budget itself; callers spend only after it returns without "held".
## These pin: pick -> decision with no spend; dismissal -> held + log, no spend;
## stale answer (still_error) -> held, no spend; forged/unoffered pick refused;
## carry only when carry=true and only from the same attack_action source;
## run() awaits the host, but the stub HUD never suspends, so every check
## completes synchronously inside the logic suite.
## per-attack and hit-window rules never carry; a cleared record carries nothing.

class StubHud extends CombatHUD:
	var answer := ""
	var asked := 0
	var lines: Array[String] = []
	func request_damage_type_choice(options: Array, _label: String) -> String:
		asked += 1
		return answer
	func add_log(msg: String, _publish_activity: bool = true) -> void:
		lines.append(msg)

static func _snap(c: CombatState, a: Character) -> Array:
	return [c.turn_budget.action_available, c.turn_budget.bonus_action_available, a.reaction_available, a.feature_uses.duplicate(true)]

static func run(check: Callable) -> void:
	var a := Batch031Checks._character("r087_actor", 60)
	for r in Batch087Controls.rules():
		if str(r.id) != "fixture:b087_zombie_slam": a.features.append(r)
	var c := CombatState.new()
	var hud := StubHud.new()
	c.hud = hud
	c.active_character = a
	var handaxe := DataLoader.get_item("handaxe")   # activation, per attack
	var dagger := DataLoader.get_item("dagger")     # activation, attack_action
	var mace := DataLoader.get_item("mace")         # hit window
	var club := DataLoader.get_item("club")         # no rule
	var ok := func() -> String: return ""
	var stale := func() -> String: return "The target is no longer within reach."
	var before := _snap(c, a)
	# No rule: nothing asked.
	var r0: Dictionary = await c._route_damage_choice(a, club, "Light attack", false, ok)
	check.call(r0 == {"decisions": {}} and hud.asked == 0, "R087 no authored choice: host asks nothing and adds no decision")
	# Accepted pick.
	hud.answer = "force"
	var r1: Dictionary = await c._route_damage_choice(a, handaxe, "Light attack", false, ok)
	check.call(not r1.has("held") and r1.decisions.get(AttackProfileRules.DECISION_KEY) == "force" and hud.asked == 1 and _snap(c, a) == before, "R087 accepted pick returns the decision and spends nothing itself")
	# Dismissal.
	hud.answer = ""
	hud.lines.clear()
	var r2: Dictionary = await c._route_damage_choice(a, handaxe, "Opportunity Attack", false, ok)
	check.call(bool(r2.get("held", false)) and hud.lines.size() == 1 and "cancelled" in hud.lines[0] and "nothing was spent" in hud.lines[0] and _snap(c, a) == before, "R087 dismissal holds the attack, logs it, no fallback, nothing spent")
	# Stale answer.
	hud.answer = "radiant"
	hud.lines.clear()
	var r3: Dictionary = await c._route_damage_choice(a, handaxe, "Cleave attack", false, stale)
	check.call(bool(r3.get("held", false)) and "no longer within reach" in hud.lines[0] and _snap(c, a) == before, "R087 a stale answer (still_error) is refused with nothing spent")
	# Forged / unoffered pick.
	hud.answer = "psychic"
	var r4: Dictionary = await c._route_damage_choice(a, handaxe, "Light attack", false, ok)
	check.call(bool(r4.get("held", false)) and _snap(c, a) == before, "R087 an unoffered (forged) type is refused, nothing spent")
	# Rule removed while the menu is open -> refused.
	var b := Batch031Checks._character("r087_gone", 60)
	for r in Batch087Controls.rules():
		if str(r.id) != "fixture:b087_zombie_slam": b.features.append(r)
	hud.answer = "force"
	var r5: Dictionary = await c._route_damage_choice(b, handaxe, "Light attack", false, func() -> String: return "")
	b.features = b.features.filter(func(f): return str(f.get("source_instance_id", "")) != "b087:handaxe_each")
	check.call(not r5.has("held") and AttackProfileRules.activation_choice_error(b, handaxe, AttackProfileRules.damage_type_choice(a, handaxe), "force") != "", "R087 a pick whose rule left before commit is refused by the recheck")
	# Carry: Nick (carry=true) reuses a same-source attack_action pick without asking.
	c.attack_action_damage_choice = AttackProfileRules.carry_record(a, dagger, "radiant")
	hud.asked = 0
	var r6: Dictionary = await c._route_damage_choice(a, dagger, "Light attack", true, ok)
	check.call(r6.decisions.get(AttackProfileRules.DECISION_KEY) == "radiant" and hud.asked == 0, "R087 Nick carries the same-source Attack-action pick without a new menu")
	# Non-Nick routes never carry, even with a live record.
	hud.answer = "force"
	var r7: Dictionary = await c._route_damage_choice(a, dagger, "Opportunity Attack", false, ok)
	check.call(r7.decisions.get(AttackProfileRules.DECISION_KEY) == "force" and hud.asked == 1, "R087 a non-Nick route asks its own menu despite a live carry record")
	# Per-attack rule never carries even when carry=true and a record is forged.
	c.attack_action_damage_choice = {"source_instance_id": "b087:handaxe_each", "damage_type": "radiant"}
	hud.answer = "force"
	var r8: Dictionary = await c._route_damage_choice(a, handaxe, "Light attack", true, ok)
	check.call(r8.decisions.get(AttackProfileRules.DECISION_KEY) == "force" and hud.asked == 2, "R087 a forged record for a per-attack rule is not carried")
	# Other-source record does not carry.
	c.attack_action_damage_choice = {"source_instance_id": "b087:greataxe_action", "damage_type": "radiant"}
	hud.answer = "force"
	var r9: Dictionary = await c._route_damage_choice(a, dagger, "Light attack", true, ok)
	check.call(r9.decisions.get(AttackProfileRules.DECISION_KEY) == "force" and hud.asked == 3, "R087 another source's Attack-action pick does not carry")
	# Cleared record (new Attack action / new turn) carries nothing.
	c.attack_action_damage_choice = {}
	var r10: Dictionary = await c._route_damage_choice(a, dagger, "Light attack", true, ok)
	check.call(hud.asked == 4 and r10.decisions.get(AttackProfileRules.DECISION_KEY) == "force", "R087 after the record resets (new action/turn) Nick asks again")
	# Hit window: allowed through, no menu, no decision yet.
	var r11: Dictionary = await c._route_damage_choice(a, mace, "Cleave attack", false, ok)
	check.call(hud.asked == 4 and r11.decisions.get(AttackProfileRules.ALLOW_KEY, false) and not r11.decisions.has(AttackProfileRules.DECISION_KEY), "R087 a hit-window rule defers to the hit settle with no activation menu")
	check.call(_snap(c, a) == before, "R087 no host call changed any budget, Reaction or feature use")
	hud.free()
	c.free()
