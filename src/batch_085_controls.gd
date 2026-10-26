class_name Batch085Controls
extends RefCounted
## Batch 085 (S-140): live player casts through the real spell menu, slot popup
## and target clicks. A qualifying Magic Missile is cast with its transformed
## range, components, school and Bonus Action timing; Fire Bolt in the same
## turn is unchanged; a refused transformed cast spends nothing.

static func _target(id: String, hex: Vector2i) -> Dictionary:
	return {"id": id, "name": "Dummy", "creature_type": "construct", "hex_position": hex, "is_alive": true, "current_hp": 300, "max_hp": 300, "temp_hp": 0, "armor_class": -100, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "damage_immunities": [], "damage_resistances": [], "saving_throw_bonuses": {}, "spell_slots": {}}

static func _turn(combat: Node, caster: Character, target: Dictionary) -> void:
	combat.current_player_idx = 0
	combat.active_character = caster
	combat.active_combatant = {"is_player": true, "entity": caster}
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	caster.feature_uses.erase("sorcerer_levelled_spell_cast_this_turn")
	combat.turn_budget.reset(caster, combat.player_entities)
	combat.monster_entities.clear()
	combat.monster_entities.append(target)
	combat._update_grid_entities()

static func _settle(h: Node, combat: Node) -> void:
	for _frame in 120:
		await h.get_tree().process_frame
		if not combat.resolving_player_action: break

static func run(h: Node) -> void:
	h._enter_test("batch_085_cast_transform_flow")
	h._setup_world()
	Batch085Checks.load_fixtures()
	var caster: Character = h._fresh_char("Weave Wizard", "human", "wizard", {"STR": 8, "DEX": 14, "CON": 14, "INT": 18, "WIS": 10, "CHA": 10})
	caster.character_id = "b085_weave_wizard"
	caster.known_spells.assign(["magic_missile", "fire_bolt", "ray_of_frost"])
	caster.wizard_spellbook.assign(["magic_missile"])
	h._own_class_spells(caster)
	caster.features.append({"id": "fixture:b085_prepared_permission", "effects": [{"type": "always_prepared_spells", "spells": ["magic_missile"], "ability": "INT", "maximum_spell_level": 1}]})
	caster.spell_slots["1"] = 2
	PlayerManager.set_player_character(0, caster)
	PartyManager.reset()
	PartyManager.register_player_character(0, caster)
	var catalog := {}
	for id in ["magic_missile", "fire_bolt", "ray_of_frost"]: catalog[id] = DataLoader.get_spell(id).duplicate(true)
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	Batch085Checks.grant(caster)
	var target := _target("b085_dummy", Vector2i(2, 0))
	_turn(combat, caster, target)
	# 1. Refusal before payment: the transformed cast needs a Bonus Action.
	combat.turn_budget.spend("bonus_action")
	await h._cast_menu_spell(combat, "magic_missile", 1)
	for _i in 3:
		if combat.pending_action_type.is_empty(): break
		await combat._on_hex_clicked(target.hex_position)
	await _settle(h, combat)
	h._assert(int(caster.spell_slots.get("1", 0)) == 2 and combat.turn_budget.action_available and int(target.current_hp) == 300, "085 live a Bonus-Action-transformed Magic Missile with no Bonus Action left is refused and its slot and Action are unspent (slots=%s)" % caster.spell_slots.get("1"))
	combat.pending_action_type = ""
	combat.pending_spell_data = {}
	# The initial HUD budget gate must use the transformed timing too.
	_turn(combat, caster, target)
	combat.turn_budget.spend("magic_action")
	await h._cast_menu_spell(combat, "magic_missile", 1)
	h._assert(combat.pending_action_type == "spell" and combat.pending_spell_data.get("casting_time", "") == "bonus_action" and int(caster.spell_slots.get("1", 0)) == 2, "085 live an Action-to-Bonus-Action cast can begin after the Action is spent, without paying during selection")
	await combat._on_hud_action("cancel", {})
	# The reverse transformation must work with the Bonus Action already spent.
	caster.known_spells.append("healing_word")
	caster.wizard_spellbook.append("healing_word")
	h._own_class_spells(caster)
	caster.features.append({"id": "fixture:b085_reverse_permission", "effects": [{"type": "always_prepared_spells", "spells": ["healing_word"], "ability": "INT", "maximum_spell_level": 1}]})
	caster.features.append({"id": "fixture:b085_reverse_timing", "type": "attack_profile", "source_instance_id": "b085:reverse", "scope": {"kind": "spell", "ids": ["healing_word"]}, "replace": {"casting_time": "action"}})
	_turn(combat, caster, target)
	combat.turn_budget.spend("bonus_action")
	await h._cast_menu_spell(combat, "healing_word", 1)
	h._assert(combat.pending_action_type == "spell" and combat.pending_spell_data.get("casting_time", "") == "action" and int(caster.spell_slots.get("1", 0)) == 2, "085 live a Bonus-Action-to-Action cast can begin after the Bonus Action is spent, without paying during selection")
	await combat._on_hud_action("cancel", {})
	# 2. Qualifying cast through the real menu.
	_turn(combat, caster, target)
	await h._cast_menu_spell(combat, "magic_missile", 1)
	var pending: Dictionary = combat.pending_spell_data.duplicate(true)
	var profile: Dictionary = pending.get("_cast_profile", {})
	h._assert(int(pending.get("range", 0)) == int(catalog.magic_missile.range) + 12 and pending.get("components", []) == ["S"] and str(pending.get("casting_time", "")) == "bonus_action" and str(pending.get("school", "")) == "abjuration", "085 live the selected Magic Missile invocation carries +60 ft range, no V, Bonus Action timing and the replaced school (pending=%s)" % JSON.stringify({"range": pending.get("range"), "c": pending.get("components"), "t": pending.get("casting_time"), "s": pending.get("school")}))
	h._assert(profile.get("sources", []) == ["b085:reach", "b085:swift"] and profile.get("ignored", []).size() == 1, "085 live both compatible sources apply once; the conflicting school source is ignored")
	for _i in 3:
		if combat.pending_action_type.is_empty(): break
		await combat._on_hex_clicked(target.hex_position)
	await _settle(h, combat)
	var hp_after := int(target.current_hp)
	h._assert(int(caster.spell_slots.get("1", 0)) == 1 and not combat.turn_budget.bonus_action_available and combat.turn_budget.action_available and hp_after < 300, "085 live the transformed cast spends one slot and the Bonus Action once, leaving the Action (slots=%s hp=%d)" % [caster.spell_slots.get("1"), hp_after])
	# 3. Unrelated Fire Bolt in the same turn keeps its catalog fields and Action cost.
	await h._cast_menu_spell(combat, "fire_bolt")
	var fb: Dictionary = combat.pending_spell_data.duplicate(true)
	h._assert(not fb.is_empty() and not fb.has("_cast_profile") and fb.get("range") == catalog.fire_bolt.range and fb.get("components") == catalog.fire_bolt.components and fb.get("casting_time") == "action", "085 live unrelated Fire Bolt is selected with its own range, components and timing")
	await combat._on_hex_clicked(target.hex_position)
	await _settle(h, combat)
	h._assert(not combat.turn_budget.action_available and int(caster.spell_slots.get("1", 0)) == 1, "085 live Fire Bolt spends the Action and no slot")
	combat.pending_action_type = ""
	# 4. Range replacement shrinks Ray of Frost; a target beyond 10 ft is refused with nothing spent.
	var far := _target("b085_far", Vector2i(3, 0))
	_turn(combat, caster, far)
	await h._cast_menu_spell(combat, "ray_of_frost")
	h._assert(int(combat.pending_spell_data.get("range", 0)) == 2, "085 live Ray of Frost is selected with its replaced 10 ft range")
	await combat._on_hex_clicked(far.hex_position)
	await _settle(h, combat)
	h._assert(combat.turn_budget.action_available and int(far.current_hp) == 300, "085 live a target outside the transformed range is refused and the Action is unspent")
	combat.pending_action_type = ""
	combat.pending_spell_data = {}
	var unchanged := true
	for id in catalog: unchanged = unchanged and DataLoader.get_spell(id) == catalog[id]
	h._assert(unchanged, "085 live catalog spell records are unchanged after the casts")
	h._teardown_scene(combat)
	h._exit_test()
