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
