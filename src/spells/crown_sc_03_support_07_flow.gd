## SC-03 support 07: Thunderwave as shared data.
## Generic pieces: shared `push` effect (failed-save forced movement away from the caster),
## spell-level `area_object_push` (unsecured single-hex objects in the area pushed away),
## shared self-origin cube + effect_noise (already generic), and a generic pre-payment refusal
## for point-centered area spells aimed at a hex with no map tile.
class_name CrownSc03Support07Flow
extends RefCounted

const P := "SC-03 support 07: "

static func _object(id: String, extra: Dictionary = {}) -> Dictionary:
	var o := {"id": id, "instance_id": id, "name": id, "definition_id": "fixture:%s" % id, "hp": 50, "max_hp": 50, "removed": false, "magical": false, "carried": false, "size": "small", "position": [0, 0]}
	o.merge(extra, true)
	return o

static func _contract_checks(h) -> void:
	var tw := DataLoader.get_spell("thunderwave")
	h._assert(SharedSpell.uses(tw) and SharedSpell.content_error(tw).is_empty() and str(tw.get("save", "")) == "CON" and int(tw.get("area_object_push", {}).get("distance", 0)) == 2 and int(tw.get("effect_noise", {}).get("range_feet", 0)) == 300, P + "Thunderwave is shared data (CON save, cube from self, push 10 ft, object push 10 ft, 300-ft boom)")
	for bad_push in [{"type": "push"}, {"type": "push", "distance": 0}, {"type": "push", "distance": 2, "foo": 1}]:
		var bad := tw.duplicate(true)
		bad.effects = [tw.effects[0], bad_push]
		h._assert(not SharedSpell.content_error(bad).is_empty(), P + "shared push %s is rejected" % str(bad_push))
	for bad_obj in [{"distance": 2}, {"distance": 0, "scope": "unsecured"}, {"distance": 2, "scope": "all"}, {"distance": 2, "scope": "unsecured", "x": 1}]:
		var bad := tw.duplicate(true)
		bad.area_object_push = bad_obj
		h._assert(not SharedSpell.content_error(bad).is_empty(), P + "area_object_push %s is rejected" % str(bad_obj))
	var single := tw.duplicate(true)
	single.target = "single"
	single.effects = [tw.effects[1]]
	h._assert(not SharedSpell.content_error(single).is_empty(), P + "area_object_push on a non-area spell is rejected")
	var caster := ConversionBatch002Checks.actor("crown-sc03s7-contract", "wizard", 5)
	h._assert(CombatAction.spell_damage_formula(caster, tw, 2) == "2d8 + 1d8", P + "a 2nd-level slot adds 1d8")
	h._assert(CombatObjectRules.is_unsecured_single_hex(_object("a")) and not CombatObjectRules.is_unsecured_single_hex(_object("b", {"fixed": true})) and not CombatObjectRules.is_unsecured_single_hex(_object("c", {"carried": true})) and not CombatObjectRules.is_unsecured_single_hex(_object("d", {"size": "large"})), P + "unsecured = not fixed, not worn/carried, and fits entirely in one hex")

static func _renamed_checks(h) -> void:
	var spell := CrownSc01Support01Flow._renamed(h, "thunderwave", "crown_sc_03_support_07:neutral_gust")
	spell.damage = "2d6"
	spell.damage_type = "cold"
	spell.save = "STR"
	spell.effects = [spell.effects[0], {"type": "push", "distance": 1, "on_failed_save": true}]
	spell.area_object_push = {"distance": 1, "scope": "unsecured"}
	spell.erase("effect_noise") # a represented-cast sound needs a combat host; the bare resolver refuses it by design
	h._assert(SharedSpell.content_error(spell).is_empty() and DataLoader.get_spell(str(spell.id)).get("area_object_push", {}).get("distance", 0) == 1, P + "a renamed push/object-push cube spell loads and validates with no ID registration")
	var caster := ConversionBatch002Checks.actor("crown-sc03s7-renamed", "wizard", 5)
	var target := CrownSc01Support01Flow._monster("crown-sc03s7-r", Vector2i(1, 0), 10, {"STR": 10})
	var r := CombatAction.resolve_spell(caster, target, spell, true, {}, [], 1, 5)
	var dmg := 1000 - int(target.current_hp)
	h._assert(bool(r.get("success", false)) and dmg >= 1 and dmg <= 12, P + "renamed: CombatAction.resolve_spell applies the authored 2d6 cold (or half) (%d)" % dmg)
	CrownSc01Support01Flow._forget(str(spell.id))

static func _setup_wizard(h, id: String, wanted: String) -> Character:
	var wizard := ConversionBatch002Checks.actor(id, "wizard", 1)
	while wizard.level < 5: wizard.level_up()
	var book: Array[String] = ["thunderwave", "shatter"]
	for option in DataLoader.get_castable_spell_list_options(wizard.get_spell_list_ids()):
		if book.size() >= wizard.wizard_spellbook_pending: break
		if int(option.get("level", 0)) in [1, 2, 3] and str(option.id) not in book: book.append(str(option.id))
	h._assert(ClassProgression.choose_wizard_spellbook(wizard, book) and CrownSc03Support04Flow._prepare_keeping(wizard, wanted) and wanted in wizard.known_spells, P + "Wizard records %s in its spellbook and prepares it through ordinary class selection" % wanted)
	wizard.inventory.add_item("component_pouch")
	wizard.spell_slots = {"1": 4, "2": 3, "3": 2}
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	return wizard

static func _offmap_refusal(h) -> void:
	var wizard := _setup_wizard(h, "crown-sc03s7-offmap", "shatter")
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	var golem := CrownSc01Support01Flow._monster("crown-sc03s7-offmap-g", Vector2i(5, 0), 10, {"CON": 10})
	combat.monster_entities.clear()
	combat.monster_entities.assign([golem])
	combat._update_grid_entities()
	h._assert(not combat.hex_grid.has_tile(Vector2i(5, 0)) and Targeting.is_in_range(Vector2i.ZERO, Vector2i(5, 0), 12), P + "(5,0) is in Shatter range but has no map tile")
	GameManager.test_mode = false
	combat.turn_budget.action_available = true
	ConversionBatch002Flow._select(h, combat, wizard, "shatter", 3)
	await combat._on_hex_clicked(Vector2i(5, 0))
	await ConversionBatch002Flow._wait_resolution(h, combat)
	h._assert(int(wizard.spell_slots.get("3", 0)) == 2 and int(wizard.spell_slots.get("2", 0)) == 3, P + "off-map area center refused before the slot is spent")
	h._assert(combat.turn_budget.action_available and golem.current_hp == 1000, P + "refused cast keeps the action and deals nothing")
	h._assert("Choose a point on the map for the center of Shatter" in combat.hud.log_text.text, P + "refusal is logged")
	GameManager.test_mode = true
	h._teardown_scene(combat)

static func _player_thunderwave(h) -> void:
	var wizard := _setup_wizard(h, "crown-sc03s7-wizard", "thunderwave")
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	var foe := CrownSc01Support01Flow._monster("crown-sc03s7-foe", Vector2i(1, 0), 10, {"CON": 1})
	combat.monster_entities.clear()
	combat.monster_entities.assign([foe])
	var crate := _object("crown-sc03s7-crate", {"position": [2, -1]})
	var bolted := _object("crown-sc03s7-bolted", {"position": [1, 1], "fixed": true})
	combat.dropped_combat_items.append(crate)
	combat.dropped_combat_items.append(bolted)
	combat._update_grid_entities()
	GameManager.test_mode = false
	combat.turn_budget.action_available = true
	var log_start: int = combat.hud.log_text.text.length()
	ConversionBatch002Flow._select(h, combat, wizard, "thunderwave", 1)
	await combat._on_hex_clicked(Vector2i(1, 0))
	await ConversionBatch002Flow._wait_resolution(h, combat)
	var log: String = combat.hud.log_text.text.substr(log_start)
	var dmg := 1000 - int(foe.current_hp)
	var pushed := HexUtils.get_distance(Vector2i(1, 0), foe.hex_position) * 5
	h._assert(log.count("CON save") == 1, P + "the pushed creature is resolved once even though the push carries it across later cube hexes")
	h._assert(int(wizard.spell_slots.get("1", 0)) == 3, P + "picker + adjacent-hex click spends one 1st-level slot")
	h._assert((pushed == 10 and dmg >= 2 and dmg <= 16) or (pushed == 0 and dmg >= 1 and dmg <= 8), P + "failed save: 2d8 thunder and pushed 10 ft away; success: half and not pushed (dmg %d, pushed %d ft)" % [dmg, pushed])
	var crate_at := Vector2i(int(crate.position[0]), int(crate.position[1]))
	h._assert(HexUtils.get_distance(Vector2i(2, -1), crate_at) == 2 and HexUtils.get_distance(Vector2i.ZERO, crate_at) > HexUtils.get_distance(Vector2i.ZERO, Vector2i(2, -1)) and combat.hex_grid.has_tile(crate_at), P + "the unsecured crate in the cube is pushed 10 ft away from the caster (%s)" % str(crate.position))
	h._assert(bolted.position == [1, 1], P + "a fixed object in the cube is not pushed")
	GameManager.test_mode = true
	h._teardown_scene(combat)

static func run(h) -> void:
	h._enter_test("crown_sc_03_support_07_flow")
	h._setup_world()
	_contract_checks(h)
	_renamed_checks(h)
	await _offmap_refusal(h)
	await _player_thunderwave(h)
	h._exit_test()
