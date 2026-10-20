class_name Batch034Checks
extends RefCounted

static func load_fixtures() -> void:
	DataLoader._load_json_file("res://data/fixtures/batch_034/classes/vigil.json", "class")
	DataLoader._load_json_file("res://data/fixtures/batch_034/spells/aftermath.json", "spell")
	DataLoader._load_json_file("res://data/fixtures/batch_034/monsters/render.json", "monster")

static func rule(index: int = 0) -> Dictionary:
	return DataLoader.get_character_class("fixture:b034_class").features_by_level["1"][index].duplicate(true)

static func policy(spell_id: String) -> Dictionary:
	return DataLoader.get_spell(spell_id).get("zero_hp_aftermath", {}).duplicate(true)

static func downed(id: String, failures: int = 0) -> Character:
	var a := Batch031Checks._character(id, 30)
	a.current_hp = 0
	a.is_alive = false
	a.is_stable = false
	a.death_save_failures = failures
	a.add_condition("unconscious", 999)
	return a

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "034 neutral death-save class, aftermath spells and creature load: %s" % str(DataLoader.get_load_errors()))
	_death_saves(check)
	_aftermath(check)
	_validation(check)

static func _death_saves(check: Callable) -> void:
	var rolls := [0]
	var watch := func(d: Dictionary): if int(d.get("sides", 0)) == 20: rolls[0] += 1
	Dice.dice_rolled.connect(watch)
	var a := downed("b034_cancel", 1)
	a.death_save_successes = 1
	a.features.append(rule(0))
	a.add_condition("blessed", 999)
	var r := a.make_death_save(true, true)
	check.call(not r.rolled and r.automatic and r.canceled and a.death_save_failures == 1 and a.death_save_successes == 1 and not a.is_stable and rolls[0] == 0 and not r.bonus_offered, "034 S-093 canceled upcoming Death Save rolls no d20, offers no bonus and changes no counter")
	a.remove_condition("blessed")
	r = a.make_death_save()
	check.call(r.rolled and rolls[0] > 0, "034 S-093 rule without its condition leaves the ordinary rolled Death Save")
	var b := downed("b034_success", 1)
	b.death_save_successes = 2
	b.features.append(rule(1))
	b.add_condition("shielded", 999)
	rolls[0] = 0
	r = b.make_death_save(true)
	check.call(not r.rolled and r.outcome == "success" and b.is_stable and b.death_save_successes == 0 and b.death_save_failures == 0 and rolls[0] == 0, "034 S-093 automatic third success stabilizes with no d20 (only the existing stable-recovery clock)")
	var c := downed("b034_min", 0)
	c.features.append(rule(1))
	c.add_condition("shielded", 999)
	check.call(ZeroHpAftermathRules.pending_death_save_rule(c).is_empty(), "034 S-093 min_failures window excludes an ineligible save")
	var f := downed("b034_fail", 2)
	var fail_rule := rule(0)
	fail_rule.outcome = "failure"
	fail_rule.source_instance_id = "b034:doom"
	f.features.append(fail_rule)
	f.add_condition("blessed", 999)
	rolls[0] = 0
	r = f.make_death_save()
	check.call(not r.rolled and f.is_dead() and str(f.corpse_state.get("cause", "")) == "death_saves" and rolls[0] == 0, "034 S-093 automatic third failure kills through the existing Death Save cause without a roll")
	var alive := Batch031Checks._character("b034_alive", 30)
	alive.features.append(rule(0))
	alive.add_condition("blessed", 999)
	check.call(ZeroHpAftermathRules.pending_death_save_rule(alive).is_empty() and not alive.make_death_save().rolled, "034 S-093 conscious actor has no pending Death Save to cancel")
	Dice.dice_rolled.disconnect(watch)
	# Legacy save: a DTO without these features restores and rolls normally.
	var legacy := downed("b034_legacy", 1).to_dict()
	var restored := Character.new()
	restored.from_dict(legacy)
	check.call(ZeroHpAftermathRules.pending_death_save_rule(restored).is_empty() and restored.death_save_failures == 1, "034 S-093 legacy downed DTO restores without automatic outcome state")

static func _aftermath(check: Callable) -> void:
	var t := Batch031Checks._character("b034_dust_target", 20)
	t.inventory.add_item("dagger")
	t.inventory.add_item("ring_of_protection")
	var owned_before := t.inventory.owned_instances().size()
	var d := {"zero_hp_aftermath": policy("fixture:b034_dust"), "damage_source_instance_id": "spell:b034:1", "damage_source_actor_id": "b034_caster"}
	var r := CombatAction.resolve_damage(t, 30, "force", d)
	var body := t.corpse_state
	check.call(t.is_dead() and body.remains == "dust" and body.cause == "dust_aftermath" and body.character_id == "b034_dust_target" and body.cause_source.source_instance_id == "spell:b034:1" and body.cause_source.actor_id == "b034_caster" and body.cause_source.damage_type == "force", "034 S-119 reduced-to-zero declared death keeps identity and actual cause/source")
	check.call(r.zero_hp_aftermath.applied and r.hp_loss == 20 and r.zero_hp_aftermath.destroyed_gear.size() == owned_before - 1 and r.zero_hp_aftermath.retained_gear.size() == 1 and t.inventory.owned_instances().size() == 1 and t.inventory.has_item("ring_of_protection") and not t.inventory.has_item("dagger"), "034 S-119 destroyed_except_magic gear policy destroys only nonmagical copies; HP loss stays ordinary")
	check.call(not CorpseRules.target_error(t, "revivify", int(GameManager.campaign_elapsed_seconds)).is_empty() and CorpseRules.saved_error(t.to_dict()).is_empty(), "034 S-119 dust remains refuse Revivify and the corpse DTO validates")
	var reloaded := Character.new()
	reloaded.from_dict(t.to_dict())
	check.call(reloaded.corpse_state.get("cause_source", {}) == body.cause_source and reloaded.corpse_state.cause == "dust_aftermath", "034 S-119 saved corpse preserves cause detail for later revival queries")
	# Destruction: no remains, gear retained.
	var e := Batch031Checks._character("b034_erase_target", 20)
	e.inventory.add_item("dagger")
	r = CombatAction.resolve_damage(e, 30, "necrotic", {"zero_hp_aftermath": policy("fixture:b034_erase")})
	check.call(e.is_dead() and e.corpse_state.remains == "destroyed" and r.zero_hp_aftermath.outcome == "destruction" and e.inventory.has_item("dagger") and CorpseRules.target_error(e, "revivify", 0) == "No remains are available to touch.", "034 S-119 destruction leaves no remains, retains gear and refuses touch revival")
	# Ordinary HP loss control.
	var o := Batch031Checks._character("b034_plain_target", 20)
	r = CombatAction.resolve_damage(o, 30, "force")
	check.call(not o.is_dead() and o.is_downed() and r.zero_hp_aftermath.is_empty(), "034 S-119 same damage without a policy stays ordinary 0-HP unconsciousness")
	# Nonlethal: target survives -> no aftermath.
	var s := Batch031Checks._character("b034_survivor", 50)
	r = CombatAction.resolve_damage(s, 30, "force", {"zero_hp_aftermath": policy("fixture:b034_dust")})
	check.call(s.current_hp == 20 and s.corpse_state.is_empty() and r.zero_hp_aftermath.is_empty(), "034 S-119 damage that does not reach 0 HP never applies the aftermath")
	# Already downed: trigger is reduced_to_zero only.
	var z := downed("b034_down", 0)
	z.current_hp = 0
	r = CombatAction.resolve_damage(z, 5, "force", {"zero_hp_aftermath": policy("fixture:b034_dust")})
	check.call(r.zero_hp_aftermath.is_empty() and z.death_save_failures == 1 and z.corpse_state.is_empty(), "034 S-119 damage at 0 HP keeps the ordinary failed-save route")
	# Massive damage in the same occurrence: declared cause replaces generic cause once.
	var m := Batch031Checks._character("b034_massive", 10)
	r = CombatAction.resolve_damage(m, 30, "force", {"zero_hp_aftermath": policy("fixture:b034_dust")})
	check.call(m.corpse_state.cause == "dust_aftermath" and m.body_death_serial == 1 and r.zero_hp_aftermath.replaced_same_occurrence_death, "034 S-119 same-occurrence massive death records the declared cause without a second death")
	# Precedence with authored zero-HP replacement (S-117 cinder creature).
	if DataLoader.get_monster("fixture:b033_cinder").is_empty(): Batch033Checks.load_fixtures()
	var cinder := DataLoader.get_monster("fixture:b033_cinder").duplicate(true)
	cinder.merge({"id": "b034_cinder", "current_hp": 3, "max_hp": 30, "is_alive": true, "saving_throw_bonuses": {"CON": 100}}, true)
	r = CombatAction.resolve_damage(cinder, 7, "force", {"zero_hp_aftermath": policy("fixture:b034_dust")})
	check.call(not cinder.is_alive and r.zero_hp_receipt.is_empty() and cinder.zero_hp_aftermath.remains == "dust" and r.zero_hp_aftermath.identity == "b034_cinder", "034 S-119 preceding aftermath bypasses creature replacement without its save")
	var cinder2 := DataLoader.get_monster("fixture:b033_cinder").duplicate(true)
	cinder2.merge({"id": "b034_cinder2", "current_hp": 3, "max_hp": 30, "is_alive": true, "saving_throw_bonuses": {"CON": 100}}, true)
	r = CombatAction.resolve_damage(cinder2, 7, "necrotic", {"zero_hp_aftermath": policy("fixture:b034_erase")})
	check.call(cinder2.is_alive and cinder2.current_hp == 4 and r.zero_hp_aftermath.is_empty() and not r.zero_hp_receipt.is_empty(), "034 S-119 non-preceding aftermath yields to a successful replacement")
	# Weapon/monster attack consumer.
	var render := DataLoader.get_monster("fixture:b034_render").duplicate(true)
	var hit := Batch031Checks._character("b034_hit", 20)
	var attacker := Character.new()
	attacker.initialize("b034_render_attacker", "human", "fighter", hit.ability_scores)
	attacker.character_id = "b034_render_attacker"
	var res := CombatAction.resolve_weapon_attack(attacker, hit, render.attacks[0], false, false, {"damage_source_instance_id": "b034_render"})
	check.call(res.get("hit", false) and hit.is_dead() and hit.corpse_state.cause == "unmade" and hit.corpse_state.remains == "intact" and hit.corpse_state.cause_source.policy_id == "b034:unmake", "034 S-119 monster attack JSON carries its aftermath policy through weapon settlement")
	var construct := render.duplicate(true)
	construct.merge({"id": "b034_construct", "current_hp": 10, "max_hp": 10, "is_alive": true}, true)
	r = CombatAction.resolve_damage(construct, 40, "force", {"zero_hp_aftermath": render.attacks[0].zero_hp_aftermath})
	check.call(not construct.is_alive and not construct.has("zero_hp_aftermath") and r.zero_hp_aftermath.is_empty(), "034 S-119 excluded creature type takes ordinary defeat")

static func _validation(check: Callable) -> void:
	for defect in ["outcome", "remains", "gear", "trigger", "mismatch", "cause", "precedes"]:
		var bad := policy("fixture:b034_dust")
		match defect:
			"outcome": bad.outcome = "banish"
			"remains": bad.remains = "ash"
			"gear": bad.gear = "dropped"
			"trigger": bad.trigger = "damaged"
			"mismatch": bad.outcome = "destruction"
			"cause": bad.cause = ""
			"precedes": bad.precedes_zero_hp_replacement = "yes"
		check.call(not ZeroHpAftermathRules.validate_policy(bad).is_empty(), "034 malformed aftermath %s refuses at content validation" % defect)
	for defect in ["outcome", "roll", "source", "window"]:
		var bad := rule(0)
		match defect:
			"outcome": bad.outcome = "reroll"
			"roll": bad.roll = true
			"source": bad.erase("source_instance_id")
			"window": bad.min_failures = 3
		check.call(not ZeroHpAftermathRules.validate_death_save_rule(bad).is_empty(), "034 malformed death-save outcome %s refuses" % defect)
	var t := Batch031Checks._character("b034_dto", 10)
	CombatAction.resolve_damage(t, 30, "force", {"zero_hp_aftermath": policy("fixture:b034_dust")})
	var good := t.to_dict()
	for defect in ["type", "key", "outcome", "contradiction"]:
		var bad := good.duplicate(true)
		match defect:
			"type": bad.corpse_state.cause_source = "x"
			"key": bad.corpse_state.cause_source["extra"] = "x"
			"outcome": bad.corpse_state.cause_source.outcome = "banish"
			"contradiction": bad.corpse_state.cause_source.outcome = "destruction"
		check.call(not CorpseRules.saved_error(bad).is_empty(), "034 malformed saved cause detail %s refuses" % defect)
	var legacy := good.duplicate(true)
	legacy.corpse_state.erase("cause_source")
	check.call(CorpseRules.saved_error(legacy).is_empty(), "034 legacy corpse DTO without cause detail still validates")
