class_name Batch060Checks
extends RefCounted
## Batch 060 (S-156 command cost): the cost of commanding a created actor is
## declared in data (cost, per-order order_costs; free/none, action, bonus_action).

const HOUNDS := "fixture:b060_hounds"

static func load_fixtures() -> void:
	Batch055Checks.load_fixtures()
	if not DataLoader.get_spell(HOUNDS).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_060/spells/hounds.json", "spell")

static func hounds(owner: Character) -> Array:
	var spell := DataLoader.get_spell(HOUNDS)
	CreatedActorRules.create(owner, {"source_id": "spell:%s:b060" % owner.character_id, "caster_id": owner.character_id, "spell_id": HOUNDS, "concentration": true, "conditions": []}, spell.effects[0].template, 1, spell)
	return CreatedActorRules.actors(owner)

static func _stub(owner: Character, actors: Array) -> Batch055Checks.Stub:
	var s := Batch055Checks.Stub.new()
	s.active_character = owner
	s.budget = {"action": 1, "bonus_action": 1, "reaction": 1}
	s.player_entities = [{"character": owner, "combat_id": owner.character_id, "hex_position": Vector2i.ZERO}, {"character": actors[0], "combat_id": actors[0].character_id, "hex_position": Vector2i(1, 0)}, {"character": actors[1], "combat_id": actors[1].character_id, "hex_position": Vector2i(0, 1)}]
	s.monster_entities = [{"id": "b060_goblin", "name": "Goblin", "is_alive": true, "current_hp": 200, "max_hp": 200, "ac": 1, "hex_position": Vector2i(1, 1)}]
	return s

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty() and not DataLoader.get_spell(HOUNDS).is_empty(), "060 hound fixture loads: %s" % str(DataLoader.get_load_errors()))
	var bad := [{"cost": "reaction"}, {"cost": "magic_action"}, {"cost": 1}, {"order_costs": {}}, {"order_costs": []}, {"order_costs": {"flee": "free"}}, {"order_costs": {"dodge": "reaction"}}, {"orders": ["dodge"], "order_costs": {"attack": "free"}}]
	var good := [{"cost": "free"}, {"cost": "none"}, {"cost": "action"}, {"order_costs": {"attack": "action", "dodge": "free"}}, {"cost": "bonus_action", "order_costs": {"dodge": "none"}}]
	check.call(bad.all(func(p): return not CreatedCommandRules.policy_error(p).is_empty()) and good.all(func(p): return CreatedCommandRules.policy_error(p).is_empty()), "060 loader accepts free/none/action/bonus_action costs and per-order order_costs; refuses unknown costs, orders and orders the creature lacks")
	var legacy := CreatedCommandRules.policy({})
	var pack_policy := CreatedCommandRules.policy(DataLoader.get_spell(Batch055Checks.PACK).effects[0].template)
	check.call(CreatedCommandRules.cost(legacy, "attack") == "bonus_action" and CreatedCommandRules.cost(legacy, "dodge") == "bonus_action" and CreatedCommandRules.cost(pack_policy, "dodge") == "bonus_action", "060 legacy: absent cost fields keep 055's Bonus Action default for every order")
	var hp := CreatedCommandRules.policy(DataLoader.get_spell(HOUNDS).effects[0].template)
	check.call(CreatedCommandRules.cost(hp, "dodge") == "none" and CreatedCommandRules.cost(hp, "attack") == "action" and CreatedCommandRules.cost_label("none") == "Free" and CreatedCommandRules.cost_label("action") == "Action" and CreatedCommandRules.cost_label("bonus_action") == "Bonus Action", "060 declared cost free with order_costs attack=action resolves per order; labels read Free/Action/Bonus Action")
	var owner := Batch031Checks._character("b060_owner", 30)
	var hs := hounds(owner)
	var s := _stub(owner, hs)
	CombatAction.active_turn_serial += 1
	var free := CreatedCommandRules.issue(s, owner, hs[0].character_id, "dodge")
	check.call(free.success and s.spent == 0 and s.budget == {"action": 1, "bonus_action": 1, "reaction": 1} and hs[0].has_condition("dodging"), "060 a free Dodge command consumes no action, Bonus Action or reaction (%s)" % str(free.message))
	s.budget.action = 0
	var broke := CreatedCommandRules.issue(s, owner, hs[1].character_id, "attack", "b060_goblin")
	check.call(not broke.success and str(broke.message).ends_with("Nothing was spent.") and s.spent == 0 and s.budget.bonus_action == 1 and int(s.monster_entities[0].current_hp) == 200, "060 checklist (a): an attack order costing an Action with no Action left is refused and spends nothing, not even the Bonus Action")
	var stranger := Batch031Checks._character("b060_stranger", 30)
	s.budget.action = 1
	s.active_character = stranger
	var wrong := CreatedCommandRules.issue(s, owner, hs[1].character_id, "attack", "b060_goblin")
	s.active_character = owner
	owner.add_condition("stunned", 2)
	var stunned := CreatedCommandRules.issue(s, owner, hs[1].character_id, "attack", "b060_goblin")
	owner.remove_condition("stunned")
	var stale := CreatedCommandRules.issue(s, owner, "b060_gone_actor", "attack", "b060_goblin")
	check.call([wrong, stunned, stale].all(func(r): return not r.success and str(r.message).ends_with("Nothing was spent.")) and s.spent == 0 and s.budget.action == 1 and int(s.monster_entities[0].current_hp) == 200, "060 checklist (a): wrong turn, incapacitated owner and a stale actor id refuse a costed order before paying (%s)" % str([wrong.message, stunned.message, stale.message]))
	var paid := CreatedCommandRules.issue(s, owner, hs[1].character_id, "attack", "b060_goblin")
	check.call(paid.success and s.spent == 1 and s.budget.action == 0 and s.budget.bonus_action == 1, "060 the declared Action attack order charges exactly one Action, not the Bonus Action (%s)" % str(paid.message))
	var dto: Dictionary = JSON.parse_string(JSON.stringify(owner.to_dict()))
	var back := Character.new()
	back.from_dict(dto)
	var again := CreatedActorRules.actors(back)
	check.call(again.size() == 2 and CreatedCommandRules.cost(CreatedCommandRules.policy(CreatedCommandRules._template(back, again[0])), "dodge") == "none" and CreatedActorRules.saved_record_error(dto, dto.spell_effects.values()[0]).is_empty(), "060 checklist (b)/(d): no new saved field; reloaded hounds still resolve their declared cost from data")
