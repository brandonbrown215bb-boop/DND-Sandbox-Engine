## SC-02 live player-control proof for shared Ice Knife: an ordered attack step
## followed by a hit-or-miss Dexterity burst centred on the attacked creature.
class_name CrownSc02Flow
extends RefCounted

const RENAMED_ID := "crown_sc_02:neutral_shard"

static func _monster(id: String, hex: Vector2i, ac: int, dex: int) -> Dictionary:
	return {"id": id, "name": id, "creature_type": "beast", "hex_position": hex, "is_alive": true, "current_hp": 1000, "max_hp": 1000, "temp_hp": 0, "armor_class": ac, "ability_scores": {"DEX": dex}, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "damage_resistances": [], "condition_immunities": [], "spell_slots": {}}

static func _reset(list: Array) -> void:
	for m in list: m.current_hp = 1000

static func _cast(h, combat, caster: Character, slot: int, hex: Vector2i, label: String) -> bool:
	caster.spell_slots[str(slot)] = 4
	combat.turn_budget.action_available = true
	ConversionBatch002Flow._select(h, combat, caster, "ice_knife", slot)
	await combat._on_hex_clicked(hex)
	await ConversionBatch002Flow._wait_resolution(h, combat)
	var ok: bool = int(caster.spell_slots[str(slot)]) == 3 and not combat.turn_budget.action_available
	h._assert(ok, "SC-02: %s pays exactly one slot and the action" % label)
	return ok

static func _renamed_check(h) -> void:
	var definition := DataLoader.get_spell("ice_knife").duplicate(true)
	for key in definition.keys():
		if str(key).begins_with("_"): definition.erase(key)
	definition.id = RENAMED_ID
	definition.name = "Neutral Shard"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.artifacts/crown-sc-02"))
	var path := "res://.artifacts/crown-sc-02/renamed-spells.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify([definition]))
	file.close()
	DataLoader._load_json_file(path, "spell")
	var renamed := DataLoader.get_spell(RENAMED_ID)
	h._assert(DataLoader.get_load_errors().is_empty() and SharedSpell.uses(renamed) and SharedSpell.content_error(renamed).is_empty(), "SC-02: renamed Ice Knife passes the production loader as shared data")
	var caster := ConversionBatch002Checks.actor("crown-sc02-renamed-caster", "wizard", 5)
	var target := _monster("crown-sc02-renamed-target", Vector2i(1, 0), 1000, -100)
	var near := _monster("crown-sc02-renamed-near", Vector2i(2, 0), 1000, -100)
	var ctx := SpellResolutionContext.new()
	ctx.caster = caster
	ctx.target = target
	ctx.spell = renamed
	ctx.effect_cast = SpellEffects.begin_cast(caster, renamed)
	ctx.decisions = {"area_targets": [target, near]}
	SharedStepExecutor.execute_spell(ctx)
	h._assert(int(target.current_hp) < 1000 and int(target.current_hp) >= 1000 - 12 and int(near.current_hp) < 1000, "SC-02: renamed definition misses the shard yet still bursts with no ID registration")
	DataLoader.spells.erase(RENAMED_ID)
	DataLoader._registered_sources.get("spell", {}).erase(RENAMED_ID)

static func run(h) -> void:
	h._enter_test("crown_sc_02_flow")
	h._setup_world()
	_renamed_check(h)
	var spell := DataLoader.get_spell("ice_knife")
	h._assert(SharedSpell.uses(spell) and SharedSpell.content_error(spell).is_empty() and int(spell.range) == 12, "SC-02: Ice Knife is shared data with the SRD 60-foot range")
	var caster := ConversionBatch002Checks.actor("crown-sc02-sorcerer", "sorcerer", 1)
	var ally := ConversionBatch002Checks.actor("crown-sc02-ally", "fighter", 5)
	h._assert(ConversionBatch001Flow._prepare(caster, ["ice_knife"]), "SC-02: Sorcerer prepares Ice Knife through ordinary class selection")
	while caster.level < 5: caster.level_up()
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
	var hit_t := _monster("crown-sc02-hit", Vector2i(2, 0), -100, -100)
	var miss_t := _monster("crown-sc02-miss", Vector2i(0, 3), 1000, -100)
	var neighbour := _monster("crown-sc02-neighbour", Vector2i(3, 0), 1000, -100)
	var saver := _monster("crown-sc02-saver", Vector2i(2, -1), 1000, 100)
	var outside := _monster("crown-sc02-outside", Vector2i(4, 0), 1000, -100)
	var all := [hit_t, miss_t, neighbour, saver, outside]
	combat.monster_entities.clear()
	combat.monster_entities.assign(all)
	combat._update_grid_entities()
	GameManager.test_mode = false

	var ally_hp := int(ally.current_hp)
	var caster_hp := int(caster.current_hp)
	# Hit: 1d10 piercing + 2d6 cold on the target; the adjacent failing creature takes cold only;
	# the adjacent creature that saves takes nothing (no half); 10 feet away is untouched.
	var ok := await _cast(h, combat, caster, 1, Vector2i(2, 0), "hit cast")
	var hit_loss := 1000 - int(hit_t.current_hp)
	var n_loss := 1000 - int(neighbour.current_hp)
	h._assert(ok and hit_loss >= 3 and hit_loss <= 22, "SC-02: a hit deals 1d10 Piercing plus the 2d6 Cold burst to the target")
	h._assert(n_loss >= 2 and n_loss <= 12, "SC-02: a creature within 5 feet that fails takes 2d6 Cold")
	h._assert(int(saver.current_hp) == 1000, "SC-02: a successful Dexterity save takes no damage")
	h._assert(int(outside.current_hp) == 1000 and int(miss_t.current_hp) == 1000, "SC-02: creatures beyond 5 feet of the target are untouched")
	h._assert(int(ally.current_hp) == ally_hp and int(caster.current_hp) == caster_hp, "SC-02: the caster and a distant ally are outside the burst")
	_reset(all)

	# Miss: the shard deals no piercing but the burst still happens (cold only, 2..12).
	ok = await _cast(h, combat, caster, 1, Vector2i(0, 3), "miss cast")
	var miss_loss := 1000 - int(miss_t.current_hp)
	h._assert(ok and miss_loss >= 2 and miss_loss <= 12, "SC-02: hit or miss, the burst deals 2d6 Cold to a failing target")
	_reset(all)

	# Upcast slot 3: cold is 4d6 on the missed target (4..24) and the formula scales only the cold.
	# A natural 20 always hits even AC 1000 and adds piercing; recast so only a missed shard is measured.
	for _attempt in 5:
		_reset(all)
		ok = await _cast(h, combat, caster, 3, Vector2i(0, 3), "upcast cast")
		miss_loss = 1000 - int(miss_t.current_hp)
		if miss_loss <= 24: break
	h._assert(ok and miss_loss >= 4 and miss_loss <= 24, "SC-02: a level-3 slot raises the Cold burst to 4d6")
	h._teardown_scene(combat)
	print("CROWN_SC_02_PASSED")
	h._exit_test()
