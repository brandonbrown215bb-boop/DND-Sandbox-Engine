## SC-03 live player-control proof for shared Lightning Bolt and the generic
## caster-originating line area it consumes.
class_name CrownSc03Flow
extends RefCounted

const RENAMED_ID := "crown_sc_03:neutral_line"

static func _monster(id: String, hex: Vector2i, dex: int) -> Dictionary:
	return {"id": id, "name": id, "creature_type": "beast", "hex_position": hex, "is_alive": true, "current_hp": 1000, "max_hp": 1000, "temp_hp": 0, "armor_class": 10, "ability_scores": {"DEX": dex}, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "damage_resistances": [], "condition_immunities": [], "spell_slots": {}}

static func _loss(m: Dictionary) -> int:
	return 1000 - int(m.current_hp)

static func _cast(h, combat, caster: Character, slot: int, hex: Vector2i, label: String) -> bool:
	caster.spell_slots[str(slot)] = 4
	combat.turn_budget.action_available = true
	ConversionBatch002Flow._select(h, combat, caster, "lightning_bolt", slot)
	await combat._on_hex_clicked(hex)
	await ConversionBatch002Flow._wait_resolution(h, combat)
	var ok: bool = int(caster.spell_slots[str(slot)]) == 3 and not combat.turn_budget.action_available
	h._assert(ok, "SC-03: %s pays exactly one slot and the action" % label)
	return ok

static func _shape_checks(h) -> void:
	var spell := DataLoader.get_spell("lightning_bolt")
	h._assert(SharedSpell.uses(spell) and SharedSpell.content_error(spell).is_empty(), "SC-03: Lightning Bolt is shared data")
	var bad := spell.duplicate(true)
	bad.effects[0].erase("origin")
	h._assert(not SharedSpell.content_error(bad).is_empty(), "SC-03: a shared line without a self origin is rejected before play")
	bad.effects[0].origin = "self"
	bad.effects[0].size = 0
	h._assert(not SharedSpell.content_error(bad).is_empty(), "SC-03: a zero-length line is rejected before play")
	var cells := Targeting.get_self_line_targets(Vector2i.ZERO, Vector2i(1, 0), 20, null)
	h._assert(cells.size() == 20 and cells[0] == Vector2i(1, 0) and cells[19] == Vector2i(20, 0) and not cells.has(Vector2i.ZERO), "SC-03: a 100-foot line is 20 hexes long, starts beside the caster and excludes the caster's hex")
	var far_click := Targeting.get_self_line_targets(Vector2i.ZERO, Vector2i(3, 0), 20, null)
	h._assert(far_click == cells, "SC-03: any hex along the direction yields the same full-length line")
	var definition := spell.duplicate(true)
	for key in definition.keys():
		if str(key).begins_with("_"): definition.erase(key)
	definition.id = RENAMED_ID
	definition.name = "Neutral Line"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.artifacts/crown-sc-03"))
	var path := "res://.artifacts/crown-sc-03/renamed-spells.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify([definition]))
	file.close()
	DataLoader._load_json_file(path, "spell")
	var renamed := DataLoader.get_spell(RENAMED_ID)
	h._assert(DataLoader.get_load_errors().is_empty() and SharedSpell.uses(renamed) and SharedSpell.content_error(renamed).is_empty(), "SC-03: renamed Lightning Bolt passes the production loader as shared data")

## Ordinary level-up spell change: keep prior picks, fill open slots, add one new spell.
static func _prepare_one(caster: Character, wanted: String) -> bool:
	var previous: Array = caster.feature_choices.get(caster.get_spellcasting_feature_id(), [])
	var cantrips: Array[String] = []
	var spells: Array[String] = [wanted]
	for id in previous:
		if int(DataLoader.get_spell(str(id)).get("level", 0)) == 0: cantrips.append(str(id))
		elif str(id) != wanted: spells.append(str(id))
	for id in caster.get_spell_option_ids(true):
		if cantrips.size() >= caster.get_spellcasting_capacity("cantrips"): break
		if id not in cantrips: cantrips.append(id)
	var cap := caster.get_spellcasting_capacity("prepared_spells")
	for id in caster.get_spell_option_ids(false):
		if spells.size() >= cap: break
		if id not in spells: spells.append(id)
	if spells.size() > cap: spells.resize(cap)
	var chosen: Array[String] = cantrips
	chosen.append_array(spells)
	return ClassProgression.choose_spell_selection(caster, chosen)

static func run(h) -> void:
	h._enter_test("crown_sc_03_flow")
	h._setup_world()
	_shape_checks(h)
	var caster := ConversionBatch002Checks.actor("crown-sc03-sorcerer", "sorcerer", 5)
	var ally := ConversionBatch002Checks.actor("crown-sc03-ally", "fighter", 5)
	h._assert(_prepare_one(caster, "lightning_bolt"), "SC-03: Sorcerer prepares Lightning Bolt through ordinary class selection")
	caster.inventory.add_item("component_pouch")
	PlayerManager.set_player_character(0, caster)
	if PlayerManager.get_player_count() < 2: PlayerManager.add_player("Ally")
	PlayerManager.set_player_character(1, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, caster)
	PartyManager.register_player_character(1, ally)
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.player_entities[0].hex_position = Vector2i(-4, 0)
	combat.player_entities[1].hex_position = Vector2i(-4, 4)
	var fail_near := _monster("crown-sc03-fail-near", Vector2i(-1, 0), -100)
	var save_mid := _monster("crown-sc03-save-mid", Vector2i(1, 0), 100)
	var fail_far := _monster("crown-sc03-fail-far", Vector2i(4, 0), -100)
	var off_line := _monster("crown-sc03-off-line", Vector2i(0, 1), -100)
	var all := [fail_near, save_mid, fail_far, off_line]
	combat.monster_entities.clear()
	combat.monster_entities.assign(all)
	combat._update_grid_entities()
	GameManager.test_mode = false
	var ally_hp := int(ally.current_hp)

	# Clicking the far end of the line sets direction; every creature in the line saves.
	var ok := await _cast(h, combat, caster, 3, Vector2i(4, 0), "slot-3 cast")
	h._assert(ok and _loss(fail_near) >= 8 and _loss(fail_near) <= 48 and _loss(fail_far) >= 8 and _loss(fail_far) <= 48, "SC-03: failing creatures along the whole line take 8d6 Lightning")
	h._assert(_loss(save_mid) >= 4 and _loss(save_mid) <= 24, "SC-03: a creature that saves takes half damage")
	h._assert(_loss(off_line) == 0 and int(ally.current_hp) == ally_hp, "SC-03: creatures beside the 5-foot-wide line are untouched")
	for m in all: m.current_hp = 1000

	# Obstruction: a sight-blocking wall stops the line before the far creature.
	combat.hex_grid.get_tile(Vector2i(2, 0)).custom_properties["blocks_sight"] = true
	ok = await _cast(h, combat, caster, 4, Vector2i(-3, 0), "slot-4 obstructed cast")
	h._assert(ok and _loss(fail_near) >= 9 and _loss(fail_near) <= 54, "SC-03: a level-4 slot adds 1d6 (9d6)")
	h._assert(_loss(fail_far) == 0, "SC-03: total cover stops the line")
	combat.hex_grid.get_tile(Vector2i(2, 0)).custom_properties["blocks_sight"] = false
	for m in all: m.current_hp = 1000

	# Renamed copy: production line targeting + production resolver, no ID registration.
	# (Class spell lists are ID-keyed, so a renamed spell cannot enter the picker.)
	var cells := Targeting.get_self_line_targets(Vector2i(-4, 0), Vector2i(-3, 0), 20, combat.hex_grid)
	var hit: Array = []
	for m in all:
		if cells.has(m.hex_position): hit.append(m)
	var resolved := true
	for m in hit: resolved = resolved and bool(CombatAction.resolve_spell(caster, m, DataLoader.get_spell(RENAMED_ID), false, {}, [], 3, 5).get("success", false))
	h._assert(resolved and hit.size() == 3 and _loss(fail_near) >= 8 and _loss(fail_far) >= 8 and _loss(save_mid) >= 4 and _loss(off_line) == 0, "SC-03: the renamed definition resolves the same line with no ID registration")
	DataLoader.spells.erase(RENAMED_ID)
	DataLoader._registered_sources.get("spell", {}).erase(RENAMED_ID)
	h._teardown_scene(combat)
	print("CROWN_SC_03_PASSED")
	h._exit_test()
