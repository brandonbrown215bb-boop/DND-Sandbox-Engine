## SC-03 support 06: generic shared `save_disadvantage_creature_types` plus shared
## area `targets_objects` (unattended nonmagical objects in the area take the damage).
## Proven on a renamed neutral definition and on the real Shatter through player controls.
class_name CrownSc03Support06Flow
extends RefCounted

const P := "SC-03 support 06: "

static func _object(id: String, magical: bool = false, carried: bool = false) -> Dictionary:
	return {"id": id, "instance_id": id, "name": id, "definition_id": "fixture:%s" % id, "hp": 200, "max_hp": 200, "removed": false, "magical": magical, "carried": carried}

static func _contract_checks(h) -> void:
	var sh := DataLoader.get_spell("shatter")
	h._assert(SharedSpell.uses(sh) and SharedSpell.content_error(sh).is_empty() and sh.get("save_disadvantage_creature_types", []) == ["construct"] and bool(sh.get("targets_objects", false)) and int(sh.get("area_radius", 0)) == 2 and str(sh.get("save", "")) == "CON", P + "Shatter is shared data (CON save, 10-ft sphere, Constructs at Disadvantage, objects in area)")
	for bad_value in [[], ["robot"], ["construct", "construct"], "construct"]:
		var bad := sh.duplicate(true)
		bad.save_disadvantage_creature_types = bad_value
		h._assert(not SharedSpell.content_error(bad).is_empty(), P + "save_disadvantage_creature_types = %s is rejected" % str(bad_value))
	var no_save := sh.duplicate(true)
	no_save.erase("save")
	no_save.erase("half_on_save")
	h._assert(not SharedSpell.content_error(no_save).is_empty(), P + "save_disadvantage_creature_types without a save is rejected")
	var caster := ConversionBatch002Checks.actor("crown-sc03s6-contract", "wizard", 5)
	h._assert(CombatAction.spell_damage_formula(caster, sh, 3) == "3d8 + 1d8", P + "a 3rd-level slot adds 1d8")

static func _renamed_checks(h) -> void:
	var spell := CrownSc01Support01Flow._renamed(h, "shatter", "crown_sc_03_support_06:neutral_peal")
	spell.damage = "2d6"
	spell.damage_type = "cold"
	spell.save = "WIS"
	spell.save_disadvantage_creature_types = ["undead"]
	h._assert(SharedSpell.content_error(spell).is_empty(), P + "a renamed creature-type-disadvantage area spell validates with no ID registration")
	var caster := ConversionBatch002Checks.actor("crown-sc03s6-renamed", "wizard", 5)
	var undead := CrownSc01Support01Flow._monster("crown-sc03s6-undead", Vector2i(1, 0), 10, {"WIS": 10})
	undead.creature_type = "undead"
	var beast := CrownSc01Support01Flow._monster("crown-sc03s6-beast", Vector2i(1, 1), 10, {"WIS": 10})
	var ru := CombatAction.resolve_spell(caster, undead, spell, true, {}, [], 2, 5)
	var rb := CombatAction.resolve_spell(caster, beast, spell, true, {}, [], 2, 5)
	h._assert(bool(ru.get("save_disadvantage", false)) and not bool(rb.get("save_disadvantage", true)) and 1000 - int(undead.current_hp) >= 1 and 1000 - int(undead.current_hp) <= 12, P + "renamed: the listed type (undead) saves at Disadvantage and a beast does not; 2d6 (or half) cold lands")
	var plain := _object("crown-sc03s6-r-plain")
	var res := CombatObjectRules.resolve_area_object_damage(caster, plain, spell, 2)
	h._assert(bool(res.get("success", false)) and int(plain.hp) < 200 and int(plain.hp) >= 188, P + "renamed: an unattended nonmagical object takes the authored 2d6")
	CrownSc01Support01Flow._forget(str(spell.id))

static func run(h) -> void:
	h._enter_test("crown_sc_03_support_06_flow")
	h._setup_world()
	_contract_checks(h)
	_renamed_checks(h)
	var wizard := ConversionBatch002Checks.actor("crown-sc03s6-wizard", "wizard", 1)
	while wizard.level < 5: wizard.level_up()
	var book: Array[String] = ["shatter"]
	for option in DataLoader.get_castable_spell_list_options(wizard.get_spell_list_ids()):
		if book.size() >= wizard.wizard_spellbook_pending: break
		if int(option.get("level", 0)) in [1, 2, 3] and str(option.id) not in book: book.append(str(option.id))
	h._assert(ClassProgression.choose_wizard_spellbook(wizard, book) and CrownSc03Support04Flow._prepare_keeping(wizard, "shatter") and "shatter" in wizard.known_spells, P + "Wizard records Shatter in its spellbook and prepares it through ordinary class selection")
	wizard.inventory.add_item("component_pouch")
	wizard.spell_slots = {"2": 3, "3": 2}
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	var center := Vector2i(3, 0)
	var golem := CrownSc01Support01Flow._monster("crown-sc03s6-golem", center, 10, {"CON": 10})
	golem.creature_type = "construct"
	combat.monster_entities.clear()
	combat.monster_entities.assign([golem])
	combat._update_grid_entities()
	var plain := _object("crown-sc03s6-crate")
	var magic := _object("crown-sc03s6-relic", true)
	var held := _object("crown-sc03s6-satchel", false, true)
	combat.hex_grid.add_entity({"world_object": plain, "hex_position": center + Vector2i(1, 0)})
	combat.hex_grid.add_entity({"world_object": magic, "hex_position": center + Vector2i(0, 1)})
	combat.hex_grid.add_entity({"world_object": held, "hex_position": center + Vector2i(-1, 1)})
	GameManager.test_mode = false
	combat.turn_budget.action_available = true
	ConversionBatch002Flow._select(h, combat, wizard, "shatter", 3)
	await combat._on_hex_clicked(center)
	await ConversionBatch002Flow._wait_resolution(h, combat)
	var golem_dmg := 1000 - int(golem.current_hp)
	var crate_dmg := 200 - int(plain.hp)
	h._assert(golem_dmg >= 2 and golem_dmg <= 32, P + "picker + hex click: a 3rd-level Shatter deals 4d8 (or half) thunder to the Construct (%d)" % golem_dmg)
	h._assert(crate_dmg >= 4 and crate_dmg <= 32, P + "the unattended nonmagical crate in the area takes the 4d8 thunder damage (%d)" % crate_dmg)
	h._assert(int(magic.hp) == 200 and int(held.hp) == 200, P + "a magical object and a carried object in the area take no damage")
	h._assert(int(wizard.spell_slots.get("3", 0)) == 1 and int(wizard.spell_slots.get("2", 0)) == 3, P + "the cast spends the chosen 3rd-level slot")
	GameManager.test_mode = true
	h._teardown_scene(combat)
	h._exit_test()
