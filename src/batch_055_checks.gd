class_name Batch055Checks
extends RefCounted
## Batch 055 (S-156): command authority over exact owned created actors.

const PACK := "fixture:b055_pack"

class Stub:
	extends RefCounted
	var active_character: Character
	var player_entities: Array = []
	var monster_entities: Array = []
	var tracker = null
	var budget := {"action": 1, "bonus_action": 1}
	var spent := 0
	func _can_spend_action_cost(cost: String) -> bool: return int(budget.get(cost, 0)) > 0
	func _spend_action_cost(cost: String) -> bool:
		if int(budget.get(cost, 0)) <= 0: return false
		budget[cost] = int(budget[cost]) - 1
		spent += 1
		return true
	func _update_grid_entities() -> void: pass

static func load_fixtures() -> void:
	Batch054Checks.load_fixtures()
	if not DataLoader.get_spell(PACK).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_055/spells/pack.json", "spell")

static func pack(owner: Character) -> Array:
	var spell := DataLoader.get_spell(PACK)
	CreatedActorRules.create(owner, {"source_id": "spell:%s:b055" % owner.character_id, "caster_id": owner.character_id, "spell_id": PACK, "concentration": true, "conditions": []}, spell.effects[0].template, 1, spell)
	return CreatedActorRules.actors(owner)

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty() and not DataLoader.get_spell(PACK).is_empty(), "055 wolf pack fixture loads: %s" % str(DataLoader.get_load_errors()))
	var bad := [{"cost": "reaction"}, {"range_hexes": 0}, {"orders": []}, {"orders": ["attack", "attack"]}, {"orders": ["flee"]}, {"default": "flee"}, {"control_seconds": 1}, {"obey": true}]
	var tpl: Dictionary = DataLoader.get_spell(PACK).effects[0].template.duplicate(true)
	tpl.command = {"cost": "reaction"}
	check.call(bad.all(func(p): return not CreatedCommandRules.policy_error(p).is_empty()) and not CreatedActorRules.template_error(tpl).is_empty() and CreatedCommandRules.policy({}) == CreatedCommandRules.DEFAULT, "055 loader refuses bad command cost, range, orders, default, control and unknown keys; unauthored command uses the documented default")
	var owner := Batch031Checks._character("b055_owner", 30)
	var wolves := pack(owner)
	var data: Dictionary = owner.spell_effects.values()[0].created_actors
	check.call(wolves.size() == 2 and wolves[0].character_id != wolves[1].character_id and wolves[0].character_name == "Wolf 1" and wolves[1].character_name == "Wolf 2" and int(data.control_until) == int(GameManager.campaign_elapsed_seconds) + 60, "055 two same-named wolves keep separate identities; control deadline recorded")
	var s := Stub.new()
	s.active_character = owner
	var goblin := {"id": "b055_goblin", "name": "Goblin", "is_alive": true, "current_hp": 1, "max_hp": 7, "ac": 1, "hex_position": Vector2i(2, 0)}
	s.player_entities = [{"character": owner, "combat_id": owner.character_id, "hex_position": Vector2i.ZERO}, {"character": wolves[0], "combat_id": wolves[0].character_id, "hex_position": Vector2i(1, 0)}, {"character": wolves[1], "combat_id": wolves[1].character_id, "hex_position": Vector2i(0, 1)}]
	s.monster_entities = [goblin]
	var turn := CombatAction.active_turn_serial
	var ok := CreatedCommandRules.issue(s, owner, wolves[1].character_id, "dodge")
	check.call(ok.success and s.spent == 1 and wolves[1].has_condition("dodging") and not wolves[0].has_condition("dodging"), "055 commanding the exact second wolf charges the owner's Bonus Action once and affects only that wolf")
	var stranger := Batch031Checks._character("b055_stranger", 30)
	var refusals := [CreatedCommandRules.issue(s, owner, wolves[0].character_id, "dodge"), CreatedCommandRules.issue(s, owner, wolves[1].character_id, "dodge")]
	s.budget.bonus_action = 1
	refusals.append(CreatedCommandRules.issue(s, owner, wolves[1].character_id, "dodge"))
	s.active_character = stranger
	refusals.append(CreatedCommandRules.issue(s, stranger, wolves[0].character_id, "dodge"))
	s.active_character = owner
	refusals.append(CreatedCommandRules.issue(s, owner, wolves[0].character_id, "flee"))
	refusals.append(CreatedCommandRules.issue(s, owner, wolves[0].character_id, "attack", "nobody"))
	s.player_entities[1].hex_position = Vector2i(9, 0)
	refusals.append(CreatedCommandRules.issue(s, owner, wolves[0].character_id, "dodge"))
	s.player_entities[1].hex_position = Vector2i(1, 0)
	check.call(refusals.all(func(r): return not r.success and str(r.message).ends_with("Nothing was spent.")) and s.spent == 1 and s.budget.bonus_action == 1 and not wolves[0].has_condition("dodging"), "055 checklist (a): no budget, already commanded, not the owner, undeclared order, no target and out of range all spend nothing (%s)" % str(refusals.map(func(r): return r.message)))
	var hit := CreatedCommandRules.issue(s, owner, wolves[0].character_id, "attack", "b055_goblin")
	check.call(hit.success and s.spent == 2 and s.budget.bonus_action == 0, "055 a valid attack order charges the owner once (%s)" % str(hit.message))
	CombatAction.active_turn_serial += 1
	wolves[0].remove_condition("dodging")
	wolves[1].remove_condition("dodging")
	s.budget.bonus_action = 1
	CreatedCommandRules.issue(s, owner, wolves[0].character_id, "dodge")
	wolves[0].remove_condition("dodging")
	var defaulted := CreatedCommandRules.apply_defaults(s, owner)
	check.call(defaulted == [wolves[1].character_id] and wolves[1].has_condition("dodging") and not wolves[0].has_condition("dodging"), "055 at turn end only the uncommanded wolf takes its declared default Dodge")
	CombatAction.active_turn_serial += 1
	s.budget.bonus_action = 1
	var clock := int(GameManager.campaign_elapsed_seconds)
	GameManager.campaign_elapsed_seconds = clock + 61
	var expired := CreatedCommandRules.issue(s, owner, wolves[0].character_id, "dodge")
	check.call(not expired.success and s.budget.bonus_action == 1 and CreatedActorRules.actors(owner).size() == 2 and str(expired.message).contains("control"), "055 control expiry refuses commands without spending and does not delete the wolves")
	GameManager.campaign_elapsed_seconds = clock
	var dto: Dictionary = JSON.parse_string(JSON.stringify(owner.to_dict()))
	var rec: Dictionary = dto.spell_effects.values()[0]
	var missing := rec.duplicate(true)
	missing.created_actors.erase("control_until")
	var foreign := rec.duplicate(true)
	foreign.created_actors.control_until = -5
	check.call(CreatedActorRules.saved_record_error(dto, rec).is_empty() and not CreatedActorRules.saved_record_error(dto, missing).is_empty() and not CreatedActorRules.saved_record_error(dto, foreign).is_empty(), "055 checklist (b): the saved control deadline is required when declared and validated")
	var back := Character.new()
	back.from_dict(dto)
	var again := CreatedActorRules.actors(back)
	check.call(again.size() == 2 and again[0].character_name == "Wolf 1" and again[1].character_name == "Wolf 2" and int(back.spell_effects.values()[0].created_actors.control_until) == int(data.control_until), "055 checklist (d): reload keeps both wolves and the control deadline")
