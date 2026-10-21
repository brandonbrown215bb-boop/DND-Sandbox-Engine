class_name Batch056Checks
extends RefCounted
## Batch 056 (S-157/S-158): declared initiative and owner-state behaviour for created actors.

const HOUNDS := "fixture:b056_hounds"
const SPRITE := "fixture:b056_sprite"

static func load_fixtures() -> void:
	Batch055Checks.load_fixtures()
	if not DataLoader.get_spell(HOUNDS).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_056/spells/pack.json", "spell")

static func make(owner: Character, spell_id: String, tag: String) -> Array:
	var spell := DataLoader.get_spell(spell_id)
	CreatedActorRules.create(owner, {"source_id": "spell:%s:%s" % [owner.character_id, tag], "caster_id": owner.character_id, "spell_id": spell_id, "concentration": bool(spell.get("concentration", false)), "conditions": []}, spell.effects[0].template, 1, spell)
	owner.concentrating_on = {"effect_source": "spell:%s:%s" % [owner.character_id, tag]}
	return CreatedActorRules.actors(owner).filter(func(a): return str(a.get_meta("created_spell_id", "")) == spell_id)

## A stub battle: owner (initiative 15), goblin (10); the given actors placed beside the owner.
static func battle(owner: Character, actors: Array) -> Batch055Checks.Stub:
	var s := Batch055Checks.Stub.new()
	s.active_character = owner
	s.tracker = InitiativeTracker.new()
	s.player_entities = [{"name": owner.character_name, "character": owner, "combat_id": owner.character_id, "hex_position": Vector2i.ZERO}]
	var goblin := {"id": "b056_goblin", "name": "Goblin", "is_alive": true, "current_hp": 30, "max_hp": 30, "ac": 1, "hex_position": Vector2i(2, 0)}
	s.monster_entities = [goblin]
	s.tracker.add_combatant(owner.character_id, owner.character_name, true, owner, 15, 14)
	s.tracker.add_combatant("b056_goblin", "Goblin", false, goblin, 10, 10)
	s.tracker.sort_initiative()
	var spots := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	for i in actors.size():
		var a: Character = actors[i]
		s.player_entities.append({"name": a.character_name, "character": a, "combat_id": a.character_id, "hex_position": spots[i], "is_created_actor": true, "created_owner_id": owner.character_id})
		CreatedCommandRules.join_initiative(s, owner, a)
	return s

static func order(s) -> Array:
	return s.tracker.combatants.map(func(c): return str(c.name))

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty() and not DataLoader.get_spell(HOUNDS).is_empty() and not DataLoader.get_spell(SPRITE).is_empty(), "056 hound and sprite fixtures load: %s" % str(DataLoader.get_load_errors()))
	var bad := [{"initiative": "first"}, {"owner_incapacitated": "flee"}, {"owner_dead": "vanish"}, {"control_expired": "attack"}, {"concentration_end": "persist"}]
	check.call(bad.all(func(p): return not CreatedCommandRules.policy_error(p).is_empty()) and CreatedCommandRules.policy({}) == CreatedCommandRules.DEFAULT and CreatedCommandRules.DEFAULT.cost == "bonus_action", "056 loader refuses bad initiative, autonomy and concentration_end values; 055's unauthored default (Bonus Action) is unchanged")
	# S-157: after_owner sits right behind the owner, both hounds separately, before the goblin.
	var owner := Batch031Checks._character("b056_owner", 30)
	var hounds := make(owner, HOUNDS, "b056h")
	var s := battle(owner, hounds)
	check.call(order(s) == ["b056_owner", "Hound 1", "Hound 2", "Goblin"], "056 after_owner hounds take separate turns directly after the owner (%s)" % str(order(s)))
	var sprite_owner := Batch031Checks._character("b056_sprite_owner", 30)
	var sprites := make(sprite_owner, SPRITE, "b056s")
	var ss := battle(sprite_owner, sprites)
	check.call(ss.tracker.combatants.size() == 3 and order(ss).has("Sprite 1") and CreatedCommandRules.initiative(sprite_owner, sprites[0]) == "own", "056 an 'own' sprite rolls into initiative by itself (%s)" % str(order(ss)))
	# Owner pays once on its turn; the hound acts on its own turn with its own budget.
	var paid := CreatedCommandRules.issue(s, owner, hounds[1].character_id, "dodge")
	var owner_spent := s.spent
	check.call(paid.success and owner_spent == 1 and s.budget.bonus_action == 0 and not hounds[1].has_condition("dodging"), "056 an order to an own-turn hound charges the owner once and waits for the hound's turn (%s)" % str(paid.message))
	s.budget = {"action": 1, "bonus_action": 1}
	s.spent = 0
	s.active_character = hounds[1]
	var acted := CreatedCommandRules.take_turn(s, s.player_entities[2])
	check.call(hounds[1].has_condition("dodging") and s.spent == 1 and s.budget.action == 0 and s.budget.bonus_action == 1 and acted.contains("ordered"), "056 the hound's own turn spends its own Action, not the owner's (%s)" % acted)
	# S-158 unconscious owner: commands refused before pay; the hound attacks the nearest enemy on its own.
	CombatAction.active_turn_serial += 1
	owner.current_hp = 0
	owner.is_alive = false
	s.active_character = owner
	s.budget = {"action": 1, "bonus_action": 1}
	s.spent = 0
	var refused := CreatedCommandRules.issue(s, owner, hounds[0].character_id, "dodge")
	check.call(not refused.success and s.spent == 0 and str(refused.message).ends_with("Nothing was spent."), "056 an unconscious owner's command is refused and spends nothing")
	s.player_entities[1].hex_position = Vector2i(1, 0)
	s.active_character = hounds[0]
	var goblin_hp := int(s.monster_entities[0].current_hp)
	var auto := CreatedCommandRules.take_turn(s, s.player_entities[1])
	check.call(CreatedCommandRules.behaviour(owner, hounds[0]) == "attack_nearest" and s.spent == 1 and not hounds[0].has_condition("dodging") and not auto.is_empty() and (int(s.monster_entities[0].current_hp) <= goblin_hp), "056 unconscious owner: the hound takes its declared attack_nearest turn (%s)" % auto)
	# S-158 dead owner: declared 'none'; the hounds remain (nothing deletes them).
	owner.death_save_failures = 3
	s.budget = {"action": 1, "bonus_action": 1}
	s.spent = 0
	hounds[0].remove_condition("dodging")
	var dead_turn := CreatedCommandRules.take_turn(s, s.player_entities[1])
	check.call(owner.is_dead() and CreatedCommandRules.behaviour(owner, hounds[0]) == "none" and dead_turn.is_empty() and not hounds[0].has_condition("dodging") and CreatedActorRules.actors(owner).size() == 2 and s.player_entities.size() == 3, "056 dead owner: the hound does what is declared (nothing) and is not deleted")
	# Owner-turn (055) actors use the same owner-state fallback at the owner's turn end.
	var w_owner := Batch031Checks._character("b056_wolf_owner", 30)
	var wolves := Batch055Checks.pack(w_owner)
	var ws := battle(w_owner, wolves)
	w_owner.current_hp = 0
	w_owner.is_alive = false
	CombatAction.active_turn_serial += 1
	check.call(ws.tracker.combatants.size() == 2 and CreatedCommandRules.apply_defaults(ws, w_owner).size() == 2, "056 owner_turn wolves stay off the tracker and still take their default when the owner is unconscious")
	# Control expiry: declared behaviour, actor stays (055 rule kept).
	var e_owner := Batch031Checks._character("b056_exp_owner", 30)
	var e_hounds := make(e_owner, HOUNDS, "b056e")
	var es := battle(e_owner, e_hounds)
	var clock := int(GameManager.campaign_elapsed_seconds)
	GameManager.campaign_elapsed_seconds = clock + 61
	es.active_character = e_hounds[0]
	var expired := CreatedCommandRules.take_turn(es, es.player_entities[1])
	GameManager.campaign_elapsed_seconds = clock
	check.call(expired.contains("Dodge") and e_hounds[0].has_condition("dodging") and CreatedActorRules.actors(e_owner).size() == 2, "056 control expiry applies the declared behaviour and keeps the hounds (%s)" % expired)
	# Concentration end: the existing source cleanup ends them; the tracker neither replays nor skips.
	var c_owner := Batch031Checks._character("b056_conc_owner", 30)
	var c_sprites := make(c_owner, SPRITE, "b056c")
	var cs := battle(c_owner, c_sprites)
	for i in cs.tracker.combatants.size():
		if str(cs.tracker.combatants[i].name) == "Sprite 1": cs.tracker.active_index = i # mid-turn when concentration drops
	var expected_next := str(cs.tracker.combatants[(cs.tracker.active_index + 1) % 3].name)
	SpellEffects.end_concentration(c_owner, [c_owner])
	var gone := CreatedCommandRules.reconcile(cs)
	cs.tracker.next_turn()
	check.call(CreatedActorRules.actors(c_owner).is_empty() and gone == ["Sprite 1"] and order(cs).size() == 2 and str(cs.tracker.get_active().name) == expected_next and cs.player_entities.size() == 1, "056 concentration end removes the sprite mid-turn; the next turn is %s, nobody replays or is skipped (%s)" % [expected_next, str(order(cs))])
	# (b)/(d): the record is unchanged by 056 and still validates and reloads.
	var dto: Dictionary = JSON.parse_string(JSON.stringify(e_owner.to_dict()))
	var rec: Dictionary = dto.spell_effects.values()[0]
	var back := Character.new()
	back.from_dict(dto)
	check.call(CreatedActorRules.saved_record_error(dto, rec).is_empty() and CreatedActorRules.actors(back).size() == 2 and not JSON.stringify(dto).contains("_orders"), "056 checklist (b)/(d): saved records validate and reload; pending orders are transient")
