## Focused production checks for source-owned spell access and payment choice.
class_name SpellPermissionChecks
extends RefCounted

static func run(check: Callable) -> void:
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 16, "CHA": 12})
	var bard := Character.new()
	bard.initialize("Permission Bard", "human", "bard", scores)
	var bard_spellcasting := bard.get_spellcasting_feature_id()
	bard.feature_choices[bard_spellcasting] = ["healing_word"]
	bard.known_spells = ["healing_word"]
	var bard_class_lists := bard.get_spell_list_ids().duplicate()
	var class_permissions := SpellPermissionRules.for_spell(bard, DataLoader.get_spell("healing_word"))
	check.call(class_permissions.size() == 1 and class_permissions[0].get("id", "") == "class:%s" % bard_spellcasting and class_permissions[0].get("ability", "") == "CHA", "A prepared class spell retains its owning class permission and ability")
	check.call(SpellPermissionRules.for_spell(bard, DataLoader.get_spell("mage_armor")).is_empty(), "Knowing a spell ID does not bypass the prepared class spell list")
	bard.features.append({"id": "fixture_wizard_expansion", "type": "passive", "effects": [{"type": "spell_list_expansion", "spell_lists": ["wizard"], "level_1_plus_only": true, "ability": "INT"}]})
	bard.feature_choices[bard_spellcasting].append("mage_armor")
	bard.known_spells.append("mage_armor")
	var expansion_permissions := SpellPermissionRules.for_spell(bard, DataLoader.get_spell("mage_armor"))
	check.call(expansion_permissions.size() == 1 and expansion_permissions[0].get("id", "") == "feature:fixture_wizard_expansion" and expansion_permissions[0].get("ability", "") == "INT", "A selected cross-list spell keeps the owning expansion source and ability")
	bard.feature_choices[bard_spellcasting].append("fireball")
	check.call(bard.get_spell_permissions("fireball").is_empty(), "A stale expanded-list choice cannot bypass its class's available spell level")
	bard.feature_choices[bard_spellcasting].erase("fireball")
	var innate_source := {
		"id": "fixture_innate_permission",
		"type": "passive",
		"effects": [{"type": "spell_free_cast", "spells": ["healing_word"], "uses": 1, "ability": "WIS"}],
	}
	bard.features.append(innate_source)
	bard.feature_uses["free_spell_cast:fixture_innate_permission"] = 1
	var owned_permissions := SpellPermissionRules.for_spell(bard, DataLoader.get_spell("healing_word"))
	var innate_permission: Dictionary = {}
	for permission in owned_permissions:
		if permission.get("id", "") == "innate:fixture_innate_permission":
			innate_permission = permission
	check.call(not innate_permission.is_empty() and innate_permission.get("ability", "") == "WIS", "An innate permission keeps its source-specific spellcasting ability")
	var free_payment := bard.free_spell_cast_feature("healing_word", "fixture_innate_permission")
	check.call(free_payment.get("feature_id", "") == "fixture_innate_permission" and bard.spend_free_spell_cast("healing_word", "fixture_innate_permission") and bard.feature_uses.get("free_spell_cast:fixture_innate_permission", -1) == 0, "A selected free-cast payment spends only its selected source")
	check.call(bard.free_spell_cast_feature("healing_word", "fixture_innate_permission").is_empty(), "An exhausted selected free-cast source cannot be replaced silently by another source")
	bard.features.append({"id": "fixture_point_permission", "type": "passive", "effects": [{"type": "always_prepared_spells", "spells": ["healing_word"], "ability": "WIS", "point_payment": {"resource_id": "fixture_points", "cost": 2}}]})
	bard.feature_uses["fixture_points"] = 1
	var point_permission: Dictionary = {}
	for permission in SpellPermissionRules.for_spell(bard, DataLoader.get_spell("healing_word")):
		if permission.get("id", "") == "feature:fixture_point_permission":
			point_permission = permission
	check.call(not SpellPermissionRules.can_pay_points(bard, point_permission, 1), "A point payment refuses when its exact source is short")
	bard.feature_uses["fixture_points"] = 2
	check.call(SpellPermissionRules.can_pay_points(bard, point_permission, 1) and SpellPermissionRules.spend_points(bard, point_permission, 1) and bard.feature_uses["fixture_points"] == 0, "A point payment spends only the permission's declared source and amount")
	var wizard_scores := AbilityScores.new()
	wizard_scores.from_dict({"STR": 10, "DEX": 10, "CON": 10, "INT": 16, "WIS": 10, "CHA": 10})
	var wizard := Character.new()
	wizard.initialize("Book Wizard", "human", "wizard", wizard_scores)
	wizard.wizard_spellbook = ["mage_armor"]
	wizard.feature_choices[wizard.get_spellcasting_feature_id()] = ["mage_armor"]
	wizard.known_spells = ["mage_armor"]
	var wizard_permissions := SpellPermissionRules.for_spell(wizard, DataLoader.get_spell("mage_armor"))
	check.call(wizard_permissions.any(func(permission: Dictionary) -> bool: return permission.get("id", "") == "book:wizard_spellbook" and permission.get("ability", "") == "INT"), "A prepared Wizard book entry retains its independent book permission")
	check.call("bard" in bard_class_lists and "wizard" not in bard_class_lists and "wizard" in bard.get_spell_list_ids(), "Spell list expansion adds only its selected source list to preparation options")
	var selected := DataLoader.get_spell("healing_word").duplicate(true)
	selected["_source_permission_id"] = "class:" + bard_spellcasting
	selected["_spell_payment_kind"] = "free_cast"
	selected["_spell_payment_source_id"] = "fixture_innate_permission"
	bard.feature_uses["free_spell_cast:fixture_innate_permission"] = 1
	check.call(CombatCommand.from_hud_for_character("cast_spell", {"spell":selected}, bard) == null, "A class permission cannot borrow an innate source's free payment or ability")
	selected.erase("_source_permission_id")
	check.call(CombatCommand.from_hud_for_character("cast_spell", {"spell":selected}, bard) == null, "An omitted permission is refused instead of picking the first source")
	selected["_source_permission_id"] = "innate:fixture_innate_permission"
	selected["_spell_payment_source_id"] = ""
	check.call(CombatCommand.from_hud_for_character("cast_spell", {"spell":selected}, bard) == null, "An omitted free-payment source cannot search sibling permissions")
	selected["_spell_payment_source_id"] = "fixture_innate_permission"
	var canonical := CombatCommand.from_hud_for_character("cast_spell", {"spell":selected}, bard)
	check.call(canonical != null and canonical.payload.spell._spellcasting_ability == "WIS", "An explicit innate permission/payment retains its own ability at the command boundary")
	check.call(not SpellPermissionRules._components_allowed({"components":["V"]}, {"allowed_components":[]}) and SpellPermissionRules._components_allowed({"components":[]}, {"allowed_components":[]}), "An explicit empty component allowlist permits only component-free spells")
	check.call(SpellPermissionRules._components_allowed({"components":["V"]}, {}) and not SpellPermissionRules._components_allowed({"components":["V", "S"]}, {"allowed_components":["V"]}), "Omitted component restrictions and explicit nonempty restrictions remain distinct")
	bard.features.append({"id":"fixture:mixed_source","type":"passive","effects":[{"type":"always_prepared_spells","spells":["healing_word"],"ability":"CHA"},{"type":"spell_free_cast","spells":["healing_word"],"ability":"WIS","uses":1}]})
	selected["_source_permission_id"] = "feature:fixture:mixed_source"
	selected["_spell_payment_source_id"] = "fixture:mixed_source"
	check.call(CombatCommand.from_hud_for_character("cast_spell", {"spell":selected}, bard) == null, "A prepared effect cannot borrow a differently attributed free effect in the same feature")
	wizard.get_feature_effect("spellcasting")["allowed_components"] = []
	check.call(wizard.get_spell_permissions("mage_armor").is_empty(), "A book alias cannot bypass its class's explicit component restriction")
	wizard.get_feature_effect("spellcasting").erase("allowed_components")
	wizard.get_feature_effect("spellcasting")["maximum_spell_level"] = 0
	check.call(wizard.get_spell_permissions("mage_armor").is_empty(), "A book alias cannot bypass its class's level restriction")
	wizard.get_feature_effect("spellcasting").erase("maximum_spell_level")
	var changed := DataLoader.get_spell("healing_word").duplicate(true)
	changed["_source_permission_id"] = "feature:fixture_point_permission"
	changed["_spell_payment_kind"] = "points"
	bard.feature_uses["fixture_points"] = 10
	var paid_command := CombatCommand.from_hud_for_character("cast_spell", {"spell":changed}, bard)
	bard.features.filter(func(feature): return feature.get("id", "") == "fixture_point_permission")[0].effects[0].point_payment.cost = 3
	check.call(paid_command != null and not SpellPermissionRules.selection_valid(bard, paid_command.payload.spell) and bard.feature_uses["fixture_points"] == 10, "A changed payment policy invalidates the captured selection instead of charging a new cost")
	var malformed: Dictionary = canonical.payload.spell.duplicate(true)
	malformed["_source_permissions"] = ["forged"]
	check.call(CombatCommand.from_hud_for_character("cast_spell", {"spell":malformed}, bard) == null, "Malformed source metadata refuses without a script error")
	bard.features.append({"id":"fixture:point_cantrip","type":"passive","effects":[{"type":"always_prepared_spells","spells":["light"],"point_payment":{"resource_id":"fixture_points","cost":2}}]})
	var cantrip := DataLoader.get_spell("light").duplicate(true)
	cantrip.merge({"_source_permission_id":"feature:fixture:point_cantrip","_spell_payment_kind":"points"})
	check.call(CombatCommand.from_hud_for_character("cast_spell", {"spell":cantrip}, bard) == null, "A forged point-paid cantrip is refused consistently with the picker")
	wizard.feature_choices[wizard.get_spellcasting_feature_id()] = []
	check.call(SpellPermissionRules.for_spell(wizard, DataLoader.get_spell("mage_armor")).is_empty(), "A book entry known through stale projection is not a prepared book permission")
	_run_repertoires(check)
	_ability_checks(check, bard, canonical.payload.spell)

static func _ability_checks(check: Callable, caster: Character, selected_spell: Dictionary) -> void:
	var target := Character.new()
	target.max_hp = 20
	target.current_hp = 1
	var spell := selected_spell.duplicate(true)
	caster.features.append({"id":"fixture:save_permission","type":"passive","effects":[{"type":"spell_free_cast","spells":["fixture:021_save"],"ability":"WIS","uses":1}]})
	spell = SpellPermissionRules.payment_choices(caster, "fixture:021_save")[0]
	var command := CombatCommand.from_hud_for_character("cast_spell", {"spell":spell}, caster)
	target.add_modifier("roll", "save:WIS", -1000, 5)
	spell = command.payload.spell
	var resolved := CombatAction.resolve_spell(caster, target, spell, false)
	check.call(resolved.get("save_dc", 0) == 13 and resolved.get("effect_cast", {}).get("save_dc", 0) == 13, "021: the actual saving-throw resolver and retained effect capture use selected WIS rather than primary CHA")
	SharedSpell.apply(caster, target, spell, resolved)
	var repeat := CombatAction.resolve_condition_spell_repeat_save(target, str(resolved.get("effect_cast", {}).get("source_id", "")))
	check.call(repeat.get("success", false) and repeat.get("save_dc", 0) == 13, "021: a later production repeat save retains the selected source DC")
	target.current_hp = 1
	var healing := selected_spell.duplicate(true)
	healing["execution"] = "shared"
	healing["effects"] = [{"type":"heal","value":2,"ability_bonus_from_caster":true}]
	SharedSpell.apply(caster, target, healing, {"success":true,"slot_level":1})
	check.call(target.current_hp == 6, "021: shared healing of a real Character uses selected WIS (+3) rather than primary CHA (+1)")
	var primary := Character.new()
	var scores := AbilityScores.new()
	scores.from_dict({"STR":10,"DEX":10,"CON":10,"INT":10,"WIS":12,"CHA":16})
	primary.initialize("Primary source", "human", "bard", scores)
	var choices: Array[String] = primary.get_spell_option_ids(true).slice(0, 2)
	choices.append_array(primary.get_spell_option_ids(false).slice(0, 4))
	ClassProgression.choose_spell_selection(primary, choices)
	primary.level = 2
	primary.class_levels = {"bard":1,"fighter":1}
	check.call(ClassProgression.saved_choices_error(primary.to_dict()).is_empty(), "021: primary native Bard1 preparation saves at Bard1 capacity in a level-2 allocation")
	var wizard := Character.new()
	var wizard_scores := AbilityScores.new()
	wizard_scores.from_dict({"STR":10,"DEX":10,"CON":10,"INT":16,"WIS":12,"CHA":10})
	wizard.initialize("Primary book", "human", "wizard", wizard_scores)
	ClassProgression.choose_wizard_spellbook(wizard, ["magic_missile","shield","mage_armor","sleep","ice_knife","burning_hands"])
	wizard.level = 2
	wizard.class_levels = {"wizard":1,"fighter":1}
	check.call(ClassProgression.saved_choices_error(wizard.to_dict()).is_empty(), "021: a primary Wizard1 book keeps six learned spells in a level-2 allocation")
	var reaction := Character.new()
	var reaction_scores := AbilityScores.new()
	reaction_scores.from_dict({"STR":10,"DEX":10,"CON":10,"INT":10,"WIS":16,"CHA":12})
	reaction.initialize("Innate reactor", "human", "bard", reaction_scores)
	reaction.features.append({"id":"fixture:innate_reaction","type":"passive","effects":[{"type":"spell_free_cast","spells":["shield","counterspell"],"ability":"WIS","uses":2}]})
	reaction.feature_uses["free_spell_cast:fixture:innate_reaction"] = 2
	reaction.spell_slots = {"1":1,"3":1}
	var shield_choices := SpellPermissionRules.payment_choices(reaction, "shield")
	check.call(shield_choices.size() == 1 and shield_choices[0]._spell_payment_kind == "free_cast", "021: an innate-only reaction does not borrow a class slot")
	var decisions := {"shield":true, SpellPermissionRules.reaction_key(reaction,"shield"):shield_choices[0]}
	var missile := CombatAction.resolve_spell(caster, reaction, DataLoader.get_spell("magic_missile"), false, decisions)
	check.call(missile.get("shield_used", false) and reaction.spell_slots["1"] == 1 and reaction.feature_uses["free_spell_cast:fixture:innate_reaction"] == 1, "021: the actual Shield resolver spends its chosen innate permission and preserves slots")
	reaction.reaction_available = true
	var counter_choice := SpellPermissionRules.payment_choices(reaction, "counterspell")[0]
	var counter_decisions := {"counterspell":true, SpellPermissionRules.reaction_key(reaction,"counterspell"):counter_choice}
	caster.add_modifier("roll", "save:CON", -1000, 1)
	var countered := CombatAction.resolve_spell(caster, target, DataLoader.get_spell("fireball"), false, counter_decisions, [reaction])
	check.call(countered.get("countered", false) and countered.get("counterspell_save_dc", 0) == 13 and reaction.spell_slots["3"] == 1 and reaction.feature_uses["free_spell_cast:fixture:innate_reaction"] == 0, "021: the actual Counterspell resolver uses the chosen WIS source DC and exact free payment")

static func load_fixtures() -> void:
	for kind in ["class", "spell", "item"]:
		DataLoader._load_json_file("res://data/fixtures/batch_021/%s.json" % ("classes" if kind == "class" else kind + "s"), kind)

## Older resolver checks explicitly acquire a slot permission instead of seeding an ID.
static func grant_slot_permission(c: Character, spell_ids: Array) -> void:
	for id in spell_ids:
		c.features.append({"id":"fixture:reaction_" + str(id),"name":"Practice casting","type":"passive","effects":[{"type":"always_prepared_spells","spells":[id],"ability":c.get_spellcasting_ability()}]})
		if str(id) not in c.known_spells: c.known_spells.append(str(id))

static func actor() -> Character:
	var c := Character.new()
	var scores := AbilityScores.new()
	scores.from_dict({"STR":10,"DEX":12,"CON":14,"INT":14,"WIS":16,"CHA":12})
	c.initialize("Repertoire tester", "human", "fixture:021_a", scores)
	c.character_id = "fixture_hero"
	c.level = 2
	c.class_levels = {"fixture:021_a":1, "fixture:021_b":1}
	return c

static func _run_repertoires(check: Callable) -> void:
	load_fixtures()
	var previous_state := GameManager.current_state
	GameManager.current_state = GameManager.GameState.OVERWORLD
	var c := actor()
	var sources := SpellRepertoireRules.sources(c)
	check.call(sources.size() == 2 and SpellRepertoireRules.capacity(sources[0], "prepared_spells") == 1, "021: primary preparation uses its own class level rather than total level")
	check.call(not SpellRepertoireRules.choose(c, "fixture:021_a_casting", ["fixture:021_b0"], sources[0]), "021: primary repertoire cannot borrow the second class's list")
	check.call(SpellRepertoireRules.choose(c, "fixture:021_a_casting", ["fixture:021_shared0"], sources[0]) and SpellRepertoireRules.choose(c, "fixture:021_b_casting", ["fixture:021_shared0"], sources[1]), "021: two acquired classes train the same spell independently")
	var permissions := c.get_spell_permissions("fixture:021_shared0")
	check.call(permissions.size() == 2 and permissions[0].ability == "CHA" and permissions[1].ability == "WIS", "021: overlapping class repertoires retain distinct source abilities")
	var before := c.to_dict().duplicate(true)
	check.call(not SpellRepertoireRules.choose(c, "fixture:021_b_casting", ["fixture:021_b0"], sources[1]) and c.to_dict() == before, "021: trained source cannot replace before its own rest boundary")
	c.long_rest()
	check.call(SpellRepertoireRules.choose(c, "fixture:021_b_casting", ["fixture:021_b0"], sources[1]), "021: completed Long Rest opens only the declared replacement window")
	check.call(not SpellRepertoireRules.choose(c, "fixture:021_b_casting", ["fixture:021_shared0"], sources[1]) and not SpellRepertoireRules.choose(c, "fixture:021_a_casting", ["fixture:021_a0"], sources[0]), "021: replacement consumes its source's window and cannot unlock a sibling")
	check.call(SaveManager._validate_save_data(BatchKChecks.full_save(c)).is_empty(), "021: independent repertoires pass the full-save validator")
	var recovered := Character.new()
	recovered.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	if recovered.feature_choices != c.feature_choices or recovered.spell_repertoire_state != c.spell_repertoire_state or recovered.get_spell_permissions("fixture:021_b0").size() != 1:
		print("021 recovery diagnostic: " + JSON.stringify({"before":c.feature_choices,"after":recovered.feature_choices,"receipts":recovered.spell_repertoire_state,"expected_receipts":c.spell_repertoire_state,"sources":SpellRepertoireRules.sources(recovered),"permissions":recovered.get_spell_permissions("fixture:021_b0")}))
	check.call(recovered.feature_choices == c.feature_choices and recovered.spell_repertoire_state == c.spell_repertoire_state and recovered.get_spell_permissions("fixture:021_b0").size() == 1, "021: recovery retains independent choices and spent replacement windows")
	for mutation in ["list", "capacity", "receipt", "source"]:
		var dto := c.to_dict().duplicate(true)
		match mutation:
			"list": dto.feature_choices["fixture:021_a_casting"] = ["fixture:021_b0"]
			"capacity": dto.feature_choices["fixture:021_b_casting"] = ["fixture:021_b0", "fixture:021_b1"]
			"receipt": dto.spell_repertoire_state["fixture:021_a_casting"].level = 20
			"source": dto.spell_repertoire_state["missing"] = {"level":1,"rest_open":false}
		check.call(not ClassProgression.saved_choices_error(dto).is_empty(), "021: malformed repertoire save refuses " + mutation)
	c.level = 3
	c.class_levels["fixture:021_a"] = 2
	check.call(not SpellRepertoireRules.choose(c, "fixture:021_a_casting", ["fixture:021_a0", "fixture:021_a1"], sources[0]), "021: stale preparation controls refuse after a source level change")
	var grown := SpellRepertoireRules.sources(c)[0]
	check.call(SpellRepertoireRules.choose(c, "fixture:021_a_casting", ["fixture:021_a0", "fixture:021_a1"], grown), "021: source-level growth adds capacity and permits its one replacement")
	c.level = 2
	c.class_levels.erase("fixture:021_b")
	c.refresh_spell_selection_from_choices()
	check.call(c.get_spell_permissions("fixture:021_b0").is_empty() and not c.feature_choices.has("fixture:021_b_casting") and not c.spell_repertoire_state.has("fixture:021_b_casting"), "021: source removal revokes only its repertoire and receipt")
	GameManager.current_state = previous_state
