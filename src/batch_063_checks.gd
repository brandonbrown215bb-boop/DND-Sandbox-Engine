class_name Batch063Checks
extends RefCounted
## Batch 063 (queue item 5, Brandon: "Yes."): "magic" (the Magic action, SRD
## 5.2.1 p.185 / p.10) is a cost in the shared vocabulary for mode costs (057/062)
## and command costs (060). It spends the Action as the magic_action kind, which
## Action Surge's extra action can't pay (SRD 5.2.1 p.48).

const ARCANE := "fixture:b063_arcane"
const FOCUS := "fixture:b063_arcane_focus"
const MOTES := "fixture:b063_motes"

## The real CombatTurnBudget behind the mode/command budget interface.
class Real:
	extends RefCounted
	var active_character: Character
	var tb := CombatTurnBudget.new()
	var spent: Array = []
	var player_entities: Array = []
	var monster_entities: Array = []
	var tracker = null
	func can_pay_mode_cost(cost: String) -> bool: return tb.can_spend(cost)
	func _can_spend_action_cost(cost: String) -> bool: return tb.can_spend(cost)
	func _spend_action_cost(cost: String) -> bool:
		if not tb.spend(cost): return false
		spent.append(cost)
		return true
	func _update_grid_entities() -> void: pass

static func load_fixtures() -> void:
	Batch057Checks.load_fixtures()
	Batch060Checks.load_fixtures()
	if DataLoader.get_feat(ARCANE).is_empty(): DataLoader._load_json_file("res://data/fixtures/batch_063/feats/arcane.json", "feat")
	if DataLoader.get_spell(MOTES).is_empty(): DataLoader._load_json_file("res://data/fixtures/batch_063/spells/motes.json", "spell")

static func kit(c: Character) -> Character:
	while c.level < 4: c.level_up()
	FeatRules.choose_level_feat(c, ARCANE)
	return c

static func state(c: Character) -> String:
	return JSON.stringify([c.feature_uses.get(FOCUS, -1), c.feature_modes.get(FOCUS, {})])

static func tok(c: Character) -> String:
	return ModeControls.row(c, FOCUS).token

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty() and not DataLoader.get_feat(ARCANE).is_empty() and not DataLoader.get_spell(MOTES).is_empty(), "063 Magic-action fixtures load: %s" % str(DataLoader.get_load_errors()))
	# Loader: magic accepted in both vocabularies; unknowns (incl. the internal kind name) refused.
	var base: Dictionary = DataLoader.get_feat(ARCANE).features[0]
	var bad: Array = []
	for v in ["magic_action", "Magic", "reaction", " magic"]:
		var f := base.duplicate(true)
		f.costs = {"activate": v}
		bad.append(FeatureModeRules.validate_rule(f))
	var cmd_good := [{"cost": "magic"}, {"order_costs": {"attack": "magic", "dodge": "free"}}]
	var cmd_bad := [{"cost": "magic_action"}, {"cost": "MAGIC"}, {"order_costs": {"attack": "magic action"}}]
	check.call(FeatureModeRules.validate_rule(base).is_empty() and bad.all(func(e): return not e.is_empty()) and cmd_good.all(func(p): return CreatedCommandRules.policy_error(p).is_empty()) and cmd_bad.all(func(p): return not CreatedCommandRules.policy_error(p).is_empty()), "063 loader accepts magic for mode and command costs and still refuses unknowns (%s)" % str(bad))
	check.call(CombatTurnBudget.cost_label("magic") == "Magic action" and CreatedCommandRules.cost_label("magic") == "Magic action" and CombatTurnBudget.cost_label("bonus_action") == "Bonus Action" and CombatTurnBudget.cost_label("action") == "Action" and CombatTurnBudget.budget_kind("magic") == "magic_action" and CombatTurnBudget.budget_kind("action") == "action", "063 shared labels read Magic action/Action/Bonus Action; magic spends the magic_action kind")
	# Mode costs on the real turn budget.
	var c := kit(Batch050Checks.actor("b063_mode"))
	var b := Real.new()
	b.active_character = c
	var before := state(c)
	var canceled := ModeControls.apply(c, FOCUS, "activate", "", tok(c), b)
	var t := tok(c)
	c.feature_uses[FOCUS] = 1
	var stale := ModeControls.apply(c, FOCUS, "activate", "guard", t, b)
	c.feature_uses[FOCUS] = 2
	b.active_character = Batch050Checks.actor("b063_other")
	var wrong := ModeControls.apply(c, FOCUS, "activate", "guard", tok(c), b)
	b.active_character = c
	c.add_condition("stunned", 2)
	var stunned := ModeControls.apply(c, FOCUS, "activate", "guard", tok(c), b)
	c.remove_condition("stunned")
	b.tb.spend("action")
	var broke := ModeControls.apply(c, FOCUS, "activate", "guard", tok(c), b)
	b.tb.grant_surge_action()
	var surge_err := ModeControls.cost_error(c, FOCUS, "activate", b)
	var surged := ModeControls.apply(c, FOCUS, "activate", "guard", tok(c), b)
	check.call(canceled.reason == "canceled" and stale.reason == "stale" and wrong.reason == "wrong_turn" and stunned.reason in ["incapacitated", "unavailable"] and broke.reason == "unaffordable" and surged.reason == "unaffordable" and surge_err == "unaffordable" and b.tb.can_spend("action") and b.tb.surge_actions == 1 and b.tb.bonus_action_available and b.spent.is_empty() and state(c) == before, "063 checklist (a): cancelled, stale, wrong-turn, incapacitated, no-Action and surge-only attempts at a Magic-action activation spend nothing (%s)" % str([stunned.reason, surged.reason]))
	b.tb.reset()
	var on := ModeControls.apply(c, FOCUS, "activate", "guard", tok(c), b)
	check.call(on.success and on.cost == "magic" and on.cost_kind == "magic_action" and b.spent == ["magic_action"] and not b.tb.action_available and b.tb.bonus_action_available and b.tb.has_acted_this_turn and int(c.feature_uses[FOCUS]) == 1 and c.feature_modes[FOCUS].mode == "guard", "063 a Magic-action activation spends the Action once (kind magic_action), not the Bonus Action, and one use")
	var re := ModeControls.apply(c, FOCUS, "reselect", "dash", tok(c), b)
	check.call(re.success and re.cost_kind == "bonus_action" and b.spent == ["magic_action", "bonus_action"] and int(c.feature_uses[FOCUS]) == 1, "063 a plain cost on the same rule keeps its own kind tag")
	# Outside combat: 062 rules.
	var prior: int = GameManager.current_state
	GameManager.current_state = GameManager.GameState.DUNGEON
	var o := kit(Batch050Checks.actor("b063_out"))
	var offered := LocalRoomModes.offers(o)
	var out_on := ModeControls.apply(o, FOCUS, "activate", "dash", tok(o), ModeControls.outside_combat())
	GameManager.current_state = prior
	check.call(offered.size() == 1 and str(offered[0].text).contains("(Magic action; no turn outside combat)") and out_on.success and out_on.cost_outside_combat == "magic" and not out_on.has("cost") and int(o.feature_uses[FOCUS]) == 1, "063 outside combat the room shows (Magic action), spends no action and charges the use once (%s)" % str(offered.map(func(x): return x.text)))
	# Command cost: magic.
	var owner := Batch031Checks._character("b063_owner", 30)
	var spell := DataLoader.get_spell(MOTES)
	CreatedActorRules.create(owner, {"source_id": "spell:%s:b063" % owner.character_id, "caster_id": owner.character_id, "spell_id": MOTES, "concentration": true, "conditions": []}, spell.effects[0].template, 1, spell)
	var ms := CreatedActorRules.actors(owner)
	var s := Real.new()
	s.active_character = owner
	s.player_entities = [{"character": owner, "combat_id": owner.character_id, "hex_position": Vector2i.ZERO}, {"character": ms[0], "combat_id": ms[0].character_id, "hex_position": Vector2i(1, 0)}, {"character": ms[1], "combat_id": ms[1].character_id, "hex_position": Vector2i(0, 1)}]
	CombatAction.active_turn_serial += 1
	s.tb.spend("action")
	s.tb.grant_surge_action()
	var no_magic := CreatedCommandRules.issue(s, owner, ms[0].character_id, "dodge")
	check.call(not no_magic.success and str(no_magic.message).contains("No magic action") and str(no_magic.message).ends_with("Nothing was spent.") and s.spent.is_empty() and s.tb.surge_actions == 1 and not ms[0].has_condition("dodging"), "063 checklist (a): a Magic-action command with only a surge action left is refused and spends nothing (%s)" % str(no_magic.message))
	s.tb.reset()
	var ok := CreatedCommandRules.issue(s, owner, ms[0].character_id, "dodge")
	var second := CreatedCommandRules.command_error(s, owner, ms[1].character_id, "dodge")
	check.call(ok.success and s.spent == ["magic_action"] and not s.tb.action_available and s.tb.bonus_action_available and ms[0].has_condition("dodging") and second.contains("magic action"), "063 a Magic-action command spends the Action once; a second one is refused (%s)" % second)
	# (b)/(d): no new saved field; reload resolves the authored cost.
	var dto: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var back := Character.new()
	back.from_dict(dto)
	var odto: Dictionary = JSON.parse_string(JSON.stringify(owner.to_dict()))
	var oback := Character.new()
	oback.from_dict(odto)
	var again := CreatedActorRules.actors(oback)
	check.call(ModeControls.cost(back, FOCUS, "activate") == "magic" and state(back) == state(c) and not JSON.stringify(dto).contains("magic_action") and FeatureModeRules.saved_error(dto).is_empty() and again.size() == 2 and CreatedCommandRules.cost(CreatedCommandRules.policy(CreatedCommandRules._template(oback, again[0])), "dodge") == "magic" and CreatedActorRules.saved_record_error(odto, odto.spell_effects.values()[0]).is_empty(), "063 checklist (b)/(d): no new saved field; reloads resolve the Magic-action cost from data")
	# Legacy: 057 Rush and 060 defaults unchanged.
	check.call(CreatedCommandRules.cost(CreatedCommandRules.policy({}), "attack") == "bonus_action" and FeatureModeRules.validate_rule(DataLoader.get_feat(Batch057Checks.RUSH).features[0]).is_empty(), "063 legacy: undeclared command costs stay Bonus Action and 057 costs still validate")
