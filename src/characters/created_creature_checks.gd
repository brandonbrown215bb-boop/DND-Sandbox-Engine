## Meaningful production regressions for permanent existence and expiring control.
class_name CreatedCreatureChecks
extends RefCounted

static func run(check: Callable) -> void:
	var old_records := GameManager.created_creatures.duplicate(true)
	var old_next := GameManager.next_created_creature_id
	var old_time := GameManager.campaign_elapsed_seconds
	var old_state := GameManager.current_state
	var old_dungeon := GameManager.active_dungeon_state
	GameManager.created_creatures.clear()
	GameManager.next_created_creature_id = 1
	GameManager.campaign_elapsed_seconds = 0
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.active_dungeon_state = {"dungeon_id": "ruins_of_ashvale"}
	var caster := Character.new()
	caster.initialize("Undead rules caster", "human", "cleric", AbilityScores.new())
	caster.character_id = "fixture:undead_owner"
	caster.known_spells.assign(["animate_dead"])
	caster.spell_slots = {"3": 2}
	caster.inventory.unequip(Inventory.Slot.SHIELD)
	caster.inventory.add_item("component_pouch")
	var room := {"id": "fixture:undead_room", "cells": [[0,0],[1,0],[2,0],[0,1],[1,1]], "walls": [], "party_positions": {caster.character_id: [0,0]}, "objects": [{"id": "bones", "name": "Humanoid remains", "kind": "remains", "position": [1,0], "size": "Medium", "body_creature_type": "humanoid", "remains": "bones", "preserved_until": 100, "hp": 10, "contents": []}]}
	var before := caster.spell_slots.duplicate()
	var failed := CreatedCreatureRules.animate(room, caster, [caster], "bones")
	check.call(not failed.get("success", false) and caster.spell_slots == before and GameManager.created_creatures.is_empty() and not room["objects"][0].get("removed", false), "Gentle Repose rejects animation without consuming remains or a slot")
	room["objects"][0]["preserved_until"] = 0
	var cast := CreatedCreatureRules.animate(room, caster, [caster], "bones")
	check.call(cast.get("success", false) and cast.get("seconds") == 60 and room["objects"][0].get("removed", false) and caster.spell_slots["3"] == 1, "Actual Animate Dead converts one pile of bones into one Skeleton using one level 3 slot and a minute")
	if GameManager.created_creatures.is_empty(): return
	GameManager.campaign_elapsed_seconds = 60
	var record: Dictionary = GameManager.created_creatures[0]
	check.call(record["form_id"] == "skeleton" and record["current_hp"] == 13 and record["existence_until"] == -1 and not record["following"] and record["order"] == "guard" and CreatedCreatureRules.saved_error(GameManager.created_creatures, 2, 60).is_empty(), "Created Skeleton has curated HP, indefinite existence, valid control and waits for explicit orders")
	before = caster.spell_slots.duplicate()
	check.call(not CreatedCreatureRules.animate(room, caster, [caster], "bones").get("success", false) and caster.spell_slots == before, "The same remains cannot be animated twice")
	var id := str(record["id"])
	record["current_hp"] = 7
	var renewal_ids: Array[String] = [id]
	var renew := CreatedCreatureRules.renew(room, caster, renewal_ids)
	check.call(renew.get("success", false) and record["id"] == id and record["current_hp"] == 7 and record["control_until"] == 86520, "Renewal changes only the control interval and preserves identity and damage")
	GameManager.campaign_elapsed_seconds = 120
	var copy: Array = JSON.parse_string(JSON.stringify(GameManager.created_creatures))
	check.call(CreatedCreatureRules.saved_error(copy, 2, 120).is_empty() and copy[0]["current_hp"] == 7, "Created creature DTO preserves clocks and damaged HP through JSON")
	var malformed: Array = copy.duplicate(true)
	malformed[0]["control_until"] += 1
	check.call(not CreatedCreatureRules.saved_error(malformed, 2, 120).is_empty(), "A malformed control interval rejects preflight")
	malformed = copy.duplicate(true)
	malformed.append(malformed[0].duplicate(true))
	check.call(not CreatedCreatureRules.saved_error(malformed, 2, 120).is_empty(), "Duplicate creature identities reject preflight")
	malformed = copy.duplicate(true)
	malformed[0]["created_at"] = 99999
	check.call(not CreatedCreatureRules.saved_error(malformed, 2, 120).is_empty(), "Creation clocks ahead of campaign time reject preflight")
	check.call(CreatedCreatureRules.controlled(record, 86519) and not CreatedCreatureRules.controlled(record, 86520) and record["current_hp"] == 7 and record["existence_until"] == -1, "Control expires at exactly 24 hours without deleting or healing the Undead")
	var skeleton := CreatedCreatureRules.character(record)
	check.call(skeleton.get_ac() == 14 and skeleton.creature_type == "undead" and CombatAction.is_immune_to_condition(skeleton, "poisoned"), "Controlled Skeleton uses its 2024 AC, creature type and condition immunities")
	CombatAction.resolve_damage(skeleton, 2, "poison")
	check.call(skeleton.current_hp == 7, "Created Skeleton's poison immunity affects actual damage")
	CombatAction.resolve_damage(skeleton, 2, "bludgeoning")
	check.call(skeleton.current_hp == 3, "Created Skeleton's Bludgeoning vulnerability doubles actual damage")
	var enemy := {"id": "fixture:undead_target", "name": "Undead target", "current_hp": 100, "armor_class": 0, "is_alive": true, "conditions": {}}
	for candidate in 10000:
		seed(candidate)
		var attack_die := randi_range(1, 20)
		var damage_die := randi_range(1, 6)
		if attack_die == 10 and damage_die == 4: seed(candidate); break
	var strike := CombatAction.resolve_weapon_attack(skeleton, enemy, CreatedCreatureRules.attack_profile(record))
	check.call(strike.get("damage", 0) == 7 and int(enemy["current_hp"]) == 93, "Skeleton actual Shortsword damage includes its +3 Dexterity bonus")
	var bow := CreatedCreatureRules.attack_profile(record, true)
	check.call(bow["name"] == "Shortbow" and bow["range"] == 16 and bow["long_range"] == 64 and "ranged" in bow["properties"] and CreatedCreatureRules.monster(record)["attacks"].size() == 2, "Skeleton projections retain both Shortsword and 80/320-foot Shortbow")
	var zombie_record := record.duplicate(true)
	zombie_record["form_id"] = "zombie"
	zombie_record["current_hp"] = 1
	zombie_record["max_hp"] = 15
	var zombie := CreatedCreatureRules.character(zombie_record)
	FighterChecks._seed_die(20, 20)
	var fortitude := CombatAction.resolve_damage(zombie, 1, "slashing")
	check.call(fortitude.get("undead_fortitude_saved", false) and zombie.current_hp == 1 and zombie.is_alive, "Zombie Undead Fortitude actually rolls a Constitution save and retains 1 HP on success")
	CombatAction.resolve_damage(zombie, 1, "radiant")
	check.call(zombie.current_hp == 0 and zombie.is_dead(), "Radiant damage bypasses Undead Fortitude and destroys the Zombie")
	zombie = CreatedCreatureRules.character(zombie_record)
	CombatAction.resolve_damage(zombie, 1, "slashing", {"damage_is_critical": true})
	check.call(zombie.current_hp == 0 and zombie.is_dead(), "Critical-hit damage bypasses Undead Fortitude")
	var hostile_zombie := CreatedCreatureRules.monster(zombie_record)
	FighterChecks._seed_die(20, 20)
	fortitude = CombatAction.resolve_damage(hostile_zombie, 1, "slashing")
	check.call(fortitude.get("undead_fortitude_saved", false) and hostile_zombie["current_hp"] == 1, "Uncontrolled Zombie retains the same Undead Fortitude rule in the shared damage path")
	FighterChecks._seed_die(20, 1)
	CombatAction.resolve_damage(hostile_zombie, 1, "slashing")
	check.call(hostile_zombie["current_hp"] == 0 and not hostile_zombie["is_alive"], "A failed Constitution save destroys an uncontrolled Zombie")
	var natural_zombie := DataLoader.get_monster("zombie").duplicate(true)
	natural_zombie["current_hp"] = 1
	natural_zombie["max_hp"] = 15
	natural_zombie["is_alive"] = true
	FighterChecks._seed_die(20, 20)
	var nat_fortitude := CombatAction.resolve_damage(natural_zombie, 1, "slashing")
	check.call(nat_fortitude.get("zero_hp_replacement_saved", false) and natural_zombie["current_hp"] == 1 and bool(natural_zombie["is_alive"]), "Naturally encountered Zombie triggers data-driven zero-HP replacement and survives on save")
	var zero_dmg_res := CombatAction.resolve_damage(natural_zombie, 0, "slashing")
	check.call(not zero_dmg_res.get("zero_hp_replacement_saved", false) and natural_zombie["current_hp"] == 1, "Exactly-zero damage does not trigger zero-HP replacement")
	natural_zombie["current_hp"] = 1
	natural_zombie["current_hp"] = 1
	natural_zombie["is_alive"] = true
	var radiant_res := CombatAction.resolve_damage(natural_zombie, 1, "radiant")
	check.call(not radiant_res.get("zero_hp_replacement_saved", false) and natural_zombie["current_hp"] == 0 and not bool(natural_zombie["is_alive"]), "Radiant damage bypasses zero-HP replacement on naturally encountered zombie")
	natural_zombie["current_hp"] = 15
	natural_zombie["max_hp"] = 15
	natural_zombie["is_alive"] = true
	natural_zombie["ability_scores"]["CON"] = 50
	FighterChecks._seed_die(20, 20)
	var overkill_saved := CombatAction.resolve_damage(natural_zombie, 35, "slashing")
	check.call(overkill_saved.get("zero_hp_replacement_saved", false) and natural_zombie["current_hp"] == 1 and bool(natural_zombie["is_alive"]), "Overkill damage with successful Constitution save triggers zero-HP replacement and leaves 1 HP (SRD 5.2.1 exclusions strictly radiant and critical)")
	natural_zombie["current_hp"] = 15
	natural_zombie["ability_scores"]["CON"] = 16
	natural_zombie["is_alive"] = true
	FighterChecks._seed_die(20, 1)
	var overkill_failed := CombatAction.resolve_damage(natural_zombie, 35, "slashing")
	check.call(not overkill_failed.get("zero_hp_replacement_saved", false) and natural_zombie["current_hp"] == 0 and not bool(natural_zombie["is_alive"]), "Overkill damage with failed Constitution save destroys creature")
	var temp_hp_zombie := CreatedCreatureRules.character(zombie_record)
	temp_hp_zombie.current_hp = 10
	temp_hp_zombie.temp_hp = 10
	var temp_survive := CombatAction.resolve_damage(temp_hp_zombie, 15, "slashing")
	check.call(not temp_survive.get("zero_hp_replacement_saved", false) and temp_hp_zombie.current_hp == 5 and temp_hp_zombie.temp_hp == 0, "Temporary HP absorbs damage before zero-HP replacement is evaluated")
	FighterChecks._seed_die(20, 20)
	var temp_lethal := CombatAction.resolve_damage(temp_hp_zombie, 10, "slashing")
	check.call(temp_lethal.get("zero_hp_replacement_saved", false) and temp_hp_zombie.current_hp == 1, "Zero-HP replacement succeeds on lethal damage after Temporary HP depletion")
	var malformed_actor := {"id": "malformed", "name": "Malformed Monster", "current_hp": 5, "max_hp": 10, "is_alive": true, "special_abilities": [{"type": "zero_hp_replacement", "save_ability": "INVALID_STAT"}]}
	var malformed_res := CombatAction.resolve_damage(malformed_actor, 10, "slashing")
	check.call(not malformed_res.get("zero_hp_replacement_saved", false) and malformed_actor["current_hp"] == 0 and not bool(malformed_actor["is_alive"]), "Malformed zero-HP replacement rule is refused and does not prevent death")
	var competing_actor := {"id": "competing", "name": "Competing Monster", "current_hp": 5, "max_hp": 10, "is_alive": true, "special_abilities": [{"id": "r1", "type": "zero_hp_replacement", "trigger": "zero_hp", "save_ability": "CON", "dc_base": 5, "dc_add_damage": true, "replacement_hp": 1}, {"id": "r2", "type": "zero_hp_replacement", "trigger": "zero_hp", "save_ability": "WIS", "dc_base": 10, "dc_add_damage": false, "replacement_hp": 5}]}
	var competing_res := CombatAction.resolve_damage(competing_actor, 10, "slashing")
	check.call(not competing_res.get("zero_hp_replacement_saved", false) and competing_actor["current_hp"] == 0 and not bool(competing_actor["is_alive"]), "Competing zero-HP replacement rules are refused with diagnostic without silently selecting first")
	# Homebrew Character projection test:
	# Verifies that successful replacement preserves affected states (raging) and death identity (body_death_serial),
	# that actor-dependent replacement HP never exceeds max_hp,
	# that failed/bypassed replacement proceeds to normal settlement once without clearing corpse_state afterwards,
	# and that an already dead character is not revived.
	var hb_barbarian := Character.new()
	hb_barbarian.initialize("Resilient Barbarian", "human", "barbarian", AbilityScores.new())
	hb_barbarian.character_id = "fixture:hb_barbarian"
	hb_barbarian.current_hp = 10
	hb_barbarian.max_hp = 20
	hb_barbarian.add_condition("raging", 60)
	var initial_serial := hb_barbarian.body_death_serial
	hb_barbarian.features.append({
		"id": "fixture_resilience",
		"name": "Fixture Resilience",
		"type": "zero_hp_replacement",
		"trigger": "zero_hp",
		"save_ability": "CON",
		"dc_base": 5,
		"dc_add_damage": true,
		"bypass_damage_types": ["radiant"],
		"bypass_critical": true,
		"replacement_hp": 5
	})
	FighterChecks._seed_die(20, 20)
	var hb_res := CombatAction.resolve_damage(hb_barbarian, 25, "slashing")
	check.call(hb_res.get("zero_hp_replacement_saved", false) and hb_barbarian.current_hp == 5 and hb_barbarian.is_alive and hb_barbarian.has_condition("raging") and hb_barbarian.body_death_serial == initial_serial and hb_barbarian.corpse_state.is_empty(), "Homebrew Character successful replacement preserves raging state, death identity, and does not create corpse_state")
	var hb_rule: Dictionary = hb_barbarian.features[hb_barbarian.features.size() - 1]
	hb_rule["replacement_hp"] = 500
	hb_barbarian.current_hp = 1
	FighterChecks._seed_die(20, 20)
	var clamp_res := CombatAction.resolve_damage(hb_barbarian, 10, "slashing")
	check.call(clamp_res.get("zero_hp_replacement_saved", false) and hb_barbarian.current_hp == hb_barbarian.max_hp and hb_barbarian.current_hp <= hb_barbarian.max_hp, "Actor-dependent replacement HP is bounded by max_hp before commit and never leaves HP > max")
	hb_rule["replacement_hp"] = 5
	var bypass_res := CombatAction.resolve_damage(hb_barbarian, hb_barbarian.max_hp + 50, "radiant")
	check.call(not bypass_res.get("zero_hp_replacement_saved", false) and hb_barbarian.current_hp == 0 and hb_barbarian.is_dead() and not hb_barbarian.has_condition("raging") and hb_barbarian.body_death_serial == initial_serial + 1 and not hb_barbarian.corpse_state.is_empty(), "Bypassed replacement proceeds to normal settlement once (rage ended, corpse created, body serial incremented)")
	var dead_serial := hb_barbarian.body_death_serial
	FighterChecks._seed_die(20, 20)
	var post_death_res := CombatAction.resolve_damage(hb_barbarian, 10, "slashing")
	check.call(not post_death_res.get("zero_hp_replacement_saved", false) and hb_barbarian.current_hp == 0 and hb_barbarian.is_dead() and not hb_barbarian.corpse_state.is_empty() and hb_barbarian.body_death_serial == dead_serial, "Further damage to an already dead actor does not resurrect or clear corpse_state")
	DataLoader._load_content_type("res://data/fixtures/shared_spells/monsters/", "monster")
	var dread_husk := DataLoader.get_monster("sandbox:dread_husk").duplicate(true)
	check.call(not dread_husk.is_empty(), "Fixture sandbox:dread_husk loaded through production loader")
	dread_husk["current_hp"] = 1
	dread_husk["max_hp"] = 15
	dread_husk["is_alive"] = true
	FighterChecks._seed_die(20, 20)
	var husk_res := CombatAction.resolve_damage(dread_husk, 1, "slashing")
	check.call(husk_res.get("zero_hp_replacement_saved", false) and dread_husk["current_hp"] == 1 and bool(dread_husk["is_alive"]), "Independently renamed monster sandbox:dread_husk uses the same data-driven zero-HP replacement")
	check.call(not CreatedCreatureRules.resolve_fortitude(zombie, 1, 1, "slashing", false), "Legacy CreatedCreatureRules.resolve_fortitude helper is neutralized and does not execute migrated rule")
	GameManager.campaign_elapsed_seconds = 86520
	caster.spell_slots["3"] = 1
	before = caster.spell_slots.duplicate()
	check.call(not CreatedCreatureRules.renew(room, caster, renewal_ids).get("success", false) and caster.spell_slots == before, "Expired control cannot be reasserted with Animate Dead and refuses without a slot")
	GameManager.campaign_elapsed_seconds = 120
	GameManager.current_state = GameManager.GameState.COMBAT
	check.call(not CreatedCreatureRules.renew(room, caster, renewal_ids).get("success", false) and caster.spell_slots == before, "One-minute control renewal is unavailable in combat and retains the slot")
	GameManager.current_state = GameManager.GameState.DUNGEON
	var next_room := room.duplicate(true)
	next_room["id"] = "fixture:next_room"
	record["following"] = false
	CreatedCreatureRules.enter_room(next_room, [caster])
	check.call(record["room_id"] == room["id"], "A Stay order leaves the controlled creature in its original room")
	record["following"] = true
	CreatedCreatureRules.enter_room(next_room, [caster])
	check.call(record["room_id"] == next_room["id"] and record["id"] == id and record["current_hp"] == 7, "A Follow order relocates the same damaged creature into a legal space in the next authored room")
	CorpseRules.mark_dead(caster, "fixture", "intact", 120)
	check.call(CreatedCreatureRules.controlled(record) and CreatedCreatureRules.get_record(id)["current_hp"] == 7 and CreatedCreatureRules.command_feature(caster, "created_attack").is_empty(), "Owner death retains the created creature and control interval but prevents new commands")
	GameManager.created_creatures.assign(old_records)
	GameManager.next_created_creature_id = old_next
	GameManager.campaign_elapsed_seconds = old_time
	GameManager.current_state = old_state
	GameManager.active_dungeon_state = old_dungeon
