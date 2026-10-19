## Focused controls for ordinary/Pact slots, fixed-level uses and ritual access.
class_name SpellSlotChecks
extends RefCounted

static func run(check: Callable) -> void:
	var scores := AbilityScores.new()
	scores.from_dict({"STR":10,"DEX":14,"CON":12,"INT":14,"WIS":12,"CHA":16})
	var multiclass := Character.new()
	multiclass.initialize("Multiclass Slots", "human", "bard", scores)
	multiclass.level = 7
	multiclass.class_levels = {"bard":4,"paladin":3}
	var ordinary := multiclass.get_max_spell_slots()
	check.call(ordinary == {"1":4,"2":3,"3":3}, "Batch 022: full and half-up spellcasting sources combine into the SRD caster-level 6 ordinary pool")

	var pact_caster := Character.new()
	pact_caster.initialize("Pact Pool", "human", "bard", scores)
	pact_caster.level = 7
	pact_caster.class_levels = {"bard":4,"warlock":3}
	pact_caster._update_spell_slots()
	check.call(pact_caster.spell_slots == {"1":4,"2":3} and pact_caster.pact_spell_slots == {"2":2}, "Batch 022: Pact slots stay in their own pool beside the ordinary pool")
	var permission := {}
	for row in pact_caster.get_spell_permissions("healing_word"):
		if row.kind == "class": permission = row
	var payment := DataLoader.get_spell("healing_word").duplicate(true)
	payment["_source_permission_id"] = permission.get("id", "")
	payment["_spell_payment_kind"] = "slot"
	payment["_spell_slot_pool_id"] = "pact"
	payment["_selected_spell_slot_level"] = 2
	payment["_spellcasting_ability"] = str(permission.get("ability", ""))
	payment["_source_permissions"] = [permission]
	var pact_payment_valid := not permission.is_empty() and SpellPermissionRules.selection_valid(pact_caster, payment)
	var spent := CombatAction.spend_spell_slot(pact_caster, payment, 2) if pact_payment_valid else {}
	check.call(pact_payment_valid and spent.get("success", false) and pact_caster.pact_spell_slots.get("2", -1) == 1 and pact_caster.spell_slots.get("2", -1) == 3 and spent.get("slot_level", 0) == 2, "Batch 022: a prepared Bard spell spends the selected Pact slot while retaining the Bard ability and ordinary slots")
	pact_caster.short_rest()
	check.call(pact_caster.pact_spell_slots.get("2", 0) == 2 and pact_caster.spell_slots.get("2", 0) == 3, "Batch 022: Short Rest restores Pact slots without changing the ordinary pool")
	var pact_only := Character.new()
	pact_only.initialize("Secondary Pact", "human", "fighter", scores)
	pact_only.level = 7
	pact_only.class_levels = {"fighter":4,"warlock":3}
	pact_only._update_spell_slots()
	check.call(pact_only.spell_slots.is_empty() and pact_only.pact_spell_slots == {"2":2} and SpellSlotRules.default_pool_id(pact_only) == "pact", "Batch 022: a secondary Pact source remains available even when no ordinary caster is present")

	var arcanum := Character.new()
	arcanum.initialize("Arcanum", "human", "warlock", scores)
	arcanum.level = 11
	arcanum.warlock_mystic_arcanum["6"] = "circle_of_death"
	arcanum.warlock_arcanum_uses["6"] = 1
	var arcanum_choices := SpellPermissionRules.payment_choices(arcanum, "circle_of_death")
	var arcanum_choice: Dictionary = arcanum_choices.filter(func(row): return str(row.get("_spell_payment_source_id", "")) == "warlock_mystic_arcanum").front() if not arcanum_choices.is_empty() else {}
	var arcanum_choice_valid := not arcanum_choice.is_empty() and SpellPermissionRules.selection_valid(arcanum, arcanum_choice)
	var ordinary_before := arcanum.spell_slots.duplicate(true)
	var arcanum_level := WarlockRules.arcanum_cast_level(arcanum, "circle_of_death")
	var arcanum_spent := WarlockRules.spend_arcanum_cast(arcanum, "circle_of_death")
	check.call(arcanum_level == 6 and arcanum_spent and arcanum.warlock_arcanum_uses.get("6", -1) == 0 and arcanum.spell_slots == ordinary_before and arcanum_choice_valid, "Batch 022: Mystic Arcanum keeps a fixed level and source use outside both slot pools")
	arcanum.long_rest()
	check.call(arcanum.warlock_arcanum_uses.get("6", 0) == 1, "Batch 022: Long Rest restores the exact fixed-level Arcanum use")

	var wizard := Character.new()
	wizard.initialize("Ritual Book", "human", "wizard", scores)
	wizard.wizard_spellbook.append("detect_magic")
	var ritual_permissions := wizard.get_spell_permissions("detect_magic").filter(func(row): return str(row.get("kind", "")) == "ritual")
	var ritual_permission: Dictionary = ritual_permissions[0] if not ritual_permissions.is_empty() else {}
	var normal_choices := SpellPermissionRules.payment_choices(wizard, "detect_magic")
	var slots_before := wizard.spell_slots.duplicate(true)
	var elapsed_before := int(GameManager.campaign_elapsed_seconds)
	var ritual_result := ClassProgression.cast_ritual(wizard, "detect_magic", str(ritual_permission.get("id", ""))) if not ritual_permission.is_empty() else {}
	check.call(not ritual_permission.is_empty() and not ritual_permission.get("slot_payment_allowed", true) and normal_choices.is_empty(), "Batch 022: Wizard book access can offer a ritual-only permission without normal slot casting")
	check.call(ritual_result.get("success", false) and int(ritual_result.get("ritual_seconds", 0)) == 606 and wizard.spell_slots == slots_before and int(GameManager.campaign_elapsed_seconds) == elapsed_before + 606, "Batch 022: the selected book source resolves its ritual, spends no slot and adds ten minutes to its six-second casting time")
	check.call(SpellEffects.has_spell(wizard, "detect_magic") and not wizard.concentrating_on.is_empty(), "Batch 022: a book ritual actually grants Detect Magic and concentration")
	SpellEffects.end_concentration(wizard, [wizard])
	_run_rituals(check)
	_run_reaction_pools(check)


static func _run_reaction_pools(check: Callable) -> void:
	var scores := AbilityScores.new()
	scores.from_dict({"STR":10,"DEX":12,"CON":14,"INT":14,"WIS":12,"CHA":16})
	var reactor := Character.new()
	reactor.initialize("Pact reactor", "human", "bard", scores)
	reactor.level = 11
	reactor.class_levels = {"bard":6,"warlock":5}
	reactor._update_spell_slots()
	SpellPermissionChecks.grant_slot_permission(reactor, ["shield", "counterspell"])
	var caster := Character.new()
	caster.initialize("Reaction caster", "human", "wizard", scores)
	var ordinary := reactor.spell_slots.duplicate(true)
	var choices := SpellPermissionRules.payment_choices(reactor, "shield").filter(func(row): return row.get("_spell_slot_pool_id", "") == "pact")
	var selection: Dictionary = choices[0] if not choices.is_empty() else {}
	var decisions := {"shield":true, SpellPermissionRules.reaction_key(reactor, "shield"):selection}
	var result := CombatAction.resolve_spell(caster, reactor, DataLoader.get_spell("magic_missile"), false, decisions)
	check.call(result.get("shield_used", false) and reactor.pact_spell_slots.get("3", -1) == 1 and reactor.spell_slots == ordinary and not reactor.reaction_available, "Batch 022: actual Shield spends the selected Pact slot and preserves every ordinary slot")
	reactor.reaction_available = true
	# A Pact reaction must still work with an ordinary caster whose slots are empty.
	for key in reactor.spell_slots: reactor.spell_slots[key] = 0
	ordinary = reactor.spell_slots.duplicate(true)
	choices = SpellPermissionRules.payment_choices(reactor, "counterspell").filter(func(row): return row.get("_spell_slot_pool_id", "") == "pact")
	selection = choices[0] if not choices.is_empty() else {}
	decisions = {"counterspell":true, SpellPermissionRules.reaction_key(reactor, "counterspell"):selection}
	caster.add_modifier("roll", "save:CON", -1000, 1)
	result = CombatAction.resolve_spell(caster, caster, DataLoader.get_spell("fireball"), false, decisions, [reactor])
	check.call(result.get("countered", false) and reactor.pact_spell_slots.get("3", -1) == 0 and reactor.spell_slots == ordinary and not reactor.reaction_available, "Batch 022: actual Counterspell spends Pact when ordinary slots are empty")
	reactor.reaction_available = true
	var refused := SpellPermissionRules.spend_reaction(reactor, "counterspell", decisions)
	check.call(refused.is_empty() and reactor.spell_slots == ordinary and reactor.reaction_available and reactor.pact_spell_slots.get("3", -1) == 0, "Batch 022: a stale selected Pact reaction refuses without another payment or Reaction spend")


static func load_fixtures() -> void:
	for kind in ["class", "spell", "item"]:
		DataLoader._load_json_file("res://data/fixtures/batch_022/%s.json" % ("classes" if kind == "class" else kind + "s"), kind)


static func ritual_actor() -> Character:
	load_fixtures()
	var scores := AbilityScores.new()
	scores.from_dict({"STR":10,"DEX":12,"CON":14,"INT":14,"WIS":16,"CHA":12})
	var c := Character.new()
	c.initialize("Ritual controls", "human", "fixture:022_source", scores)
	c.character_id = "fixture_ritual_hero"
	return c


static func _run_rituals(check: Callable) -> void:
	var prior_state := GameManager.current_state
	GameManager.current_state = GameManager.GameState.OVERWORLD
	var c := ritual_actor()
	check.call(DataLoader.get_load_errors().is_empty(), "Batch 022: neutral ritual fixtures load through production validation")
	var spell := DataLoader.get_spell("fixture:022_renewal")
	var choices := SpellPermissionRules.ritual_choices(c)
	var permissions := SpellPermissionRules.ritual_permissions(c, spell)
	check.call(not permissions.is_empty(), "Batch 022: loaded feature exposes ritual permission")
	if permissions.is_empty():
		GameManager.current_state = prior_state
		return
	var permission: Dictionary = permissions[0]
	var normal := SpellPermissionRules.payment_choices(c, str(spell.id))
	check.call(choices.size() == 3 and normal.size() == 1 and normal[0]._spellcasting_ability == "CHA" and permission.ability == "WIS", "Batch 022: loaded feature ritual access stays separate from the same spell's normal CHA permission")
	var forged: Dictionary = normal[0].duplicate(true)
	forged.merge({"_source_permission_id":permission.id,"_source_permissions":[permission],"_spellcasting_ability":permission.ability,"_spell_payment_kind":"free_cast","_spell_payment_source_id":permission.source_id}, true)
	check.call(not SpellPermissionRules.selection_valid(c, forged), "Batch 022: a ritual-only permission cannot masquerade as a normal free cast")
	c.current_hp = 1
	var slots := c.spell_slots.duplicate(true)
	var clock := int(GameManager.campaign_elapsed_seconds)
	var result := ClassProgression.cast_ritual(c, str(spell.id), str(permission.id), permission)
	check.call(result.get("success", false) and c.current_hp == 6 and c.spell_slots == slots and GameManager.campaign_elapsed_seconds == clock + 606, "Batch 022: selected feature ritual applies the WIS effect without spending normal slots")
	var old_permission := permission.duplicate(true)
	var feature: Dictionary = c.get_feature("fixture:022_ritual")
	feature.effects[0].ability = "INT"
	clock = int(GameManager.campaign_elapsed_seconds)
	var hp := c.current_hp
	result = ClassProgression.cast_ritual(c, str(spell.id), str(old_permission.id), old_permission)
	check.call(not result.get("success", false) and c.current_hp == hp and c.spell_slots == slots and GameManager.campaign_elapsed_seconds == clock, "Batch 022: a stale ritual ability refuses without falling back or advancing time")
	feature.effects[0].ability = "WIS"
	permission = SpellPermissionRules.ritual_permissions(c, DataLoader.get_spell("fixture:022_material"))[0]
	result = ClassProgression.cast_ritual(c, "fixture:022_material", str(permission.id), permission)
	check.call(not result.get("success", false) and GameManager.campaign_elapsed_seconds == clock and c.spell_slots == slots, "Batch 022: missing consumed material refuses before time, effect or slots")
	c.inventory.add_item("fixture:022_dust")
	result = ClassProgression.cast_ritual(c, "fixture:022_material", str(permission.id), permission)
	check.call(result.get("success", false) and not c.inventory.has_item("fixture:022_dust") and c.spell_slots == slots, "Batch 022: a successful ritual consumes its required material once while preserving slots")
	permission = SpellPermissionRules.ritual_permissions(c, DataLoader.get_spell("fixture:022_lasting"))[0]
	result = ClassProgression.cast_ritual(c, "fixture:022_lasting", str(permission.id), permission)
	var source := str(result.get("effect_cast", {}).get("source_id", ""))
	check.call(result.get("success", false) and c.spell_effects.get(source, {}).get("remaining_seconds", 0) == 60 and c.has_condition("blessed"), "Batch 022: a short ritual effect retains its full duration after casting finishes")
	check.call(ClassProgression._spell_casting_time_seconds({"casting_time":"minute"}) == 60 and ClassProgression._spell_casting_time_seconds({"casting_time":"hour"}) == 3600 and ClassProgression._spell_casting_time_seconds({"cast_time_seconds":90}) == 90, "Batch 022: ritual time retains authored minute, hour and explicit second casting times")
	GameManager.current_state = GameManager.GameState.COMBAT
	clock = int(GameManager.campaign_elapsed_seconds)
	result = ClassProgression.cast_ritual(c, "fixture:022_lasting", str(permission.id), permission)
	check.call(not result.get("success", false) and GameManager.campaign_elapsed_seconds == clock, "Batch 022: combat cannot invoke the exploration ritual route")
	SpellEffects.end_concentration(c, [c])
	GameManager.current_state = GameManager.GameState.OVERWORLD
	var outsider := {"name":"Prior target","current_hp":10,"max_hp":10,"is_alive":true,"conditions":{},"spell_effects":{}}
	var previous := SpellEffects.begin_cast(c, DataLoader.get_spell("fixture:022_lasting"))
	SpellEffects.grant(outsider, previous, "blessed")
	c.concentrating_on = {"spell_id":"fixture:022_lasting","effect_source":previous.source_id,"targets":[outsider]}
	permission = SpellPermissionRules.ritual_permissions(c, spell)[0]
	result = ClassProgression.cast_ritual(c, str(spell.id), str(permission.id), permission)
	check.call(result.get("success", false) and outsider.spell_effects.is_empty() and outsider.conditions.is_empty() and c.concentrating_on.is_empty(), "Batch 022: starting a ritual removes prior managed concentration from retained non-party targets")
	var prior_party: Dictionary = PartyManager.characters.duplicate()
	var prior_clock := int(GameManager.campaign_elapsed_seconds)
	var interrupted := Character.new()
	interrupted.initialize("Interrupted ritual", "human", "fixture:022_source", AbilityScores.new())
	interrupted.character_id = "interrupted_ritual"
	interrupted.exhaustion_level = 5
	interrupted.food_eaten_today_pounds = 1.0
	interrupted.inventory.add_item("fixture:022_dust")
	PartyManager.characters = {"interrupted_ritual":interrupted}
	GameManager.campaign_elapsed_seconds = 86399
	permission = SpellPermissionRules.ritual_permissions(interrupted, DataLoader.get_spell("fixture:022_material"))[0]
	result = ClassProgression.cast_ritual(interrupted, "fixture:022_material", str(permission.id), permission)
	check.call(not result.get("success", false) and result.get("interrupted", false) and not interrupted.is_alive and GameManager.campaign_elapsed_seconds == 87005 and interrupted.inventory.has_item("fixture:022_dust") and interrupted.spell_effects.is_empty(), "Batch 022: death during the casting delay retains elapsed time but completes no ritual effect or material consumption")
	PartyManager.characters = prior_party
	GameManager.campaign_elapsed_seconds = prior_clock
	GameManager.current_state = prior_state
