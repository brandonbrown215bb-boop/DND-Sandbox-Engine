class_name TetherGroupChecks
extends RefCounted

const SPELL := "fixture:paired_cords"
const RENAMED := "fixture:renamed_cords"
const OBJECT := "fixture:object_cords"

static func load_fixtures() -> void:
	if DataLoader.get_spell(SPELL).is_empty(): DataLoader._load_json_file("res://data/fixtures/tether_group/spells.json", "spell")

static func monster(id: String, save_bonus: int = -100) -> Dictionary:
	return {"id": id, "name": id, "is_alive": true, "ability_scores": {"STR": 10, "DEX": 10}, "saving_throw_bonuses": {"STR": save_bonus}, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "attacks": [{"range": 1, "damage": "1d4"}]}

## The resolver's existing per-recipient boundary receives one original cast.
## The actual controls scenario below also proves collection/payment by the host.
static func cast(caster: Character, victims: Array, spell_id: String = SPELL) -> Array:
	var spell := DataLoader.get_spell(spell_id).duplicate(true)
	spell["_effect_cast"] = SpellEffects.begin_cast(caster, spell)
	var host := SpellCastContext.new()
	host.caster = caster
	host.spell = spell
	caster.concentrating_on = {"spell_id": spell_id, "effect_source": spell._effect_cast.source_id, "targets": []}
	var outcomes := []
	for i in victims.size():
		outcomes.append(SpellResolver.resolve(caster, victims[i], spell, i == 0, {}, [], 1, -1, host))
		caster.concentrating_on.targets.append(victims[i])
	return outcomes

static func relation(caster: Character, victim) -> String:
	var bound := TetherRules.binding(victim, [caster])
	return str(bound[0].relation) if not bound.is_empty() else ""

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty() and SharedSpell.content_error(DataLoader.get_spell(RENAMED)).is_empty(), "Tether group neutral and renamed definitions load through shared validation")
	var c := Batch031Checks._character("cord_owner")
	var a := monster("cord_a")
	var b := monster("cord_b")
	c.spell_slots = {"1": 2}
	var results := cast(c, [a, b])
	var source := str(c.concentrating_on.effect_source)
	var ar := relation(c, a)
	var br := relation(c, b)
	check.call(results.all(func(r): return r.get("tether", {}).get("bound", false)) and ar != br and not ar.is_empty() and not br.is_empty() and results[0].effect_cast.source_id == results[1].effect_cast.source_id and c.spell_cast_serial == 1 and int(c.spell_slots["1"]) == 1, "Tether group two failed saves share one cast source/payment with distinct victim relations")
	var initial := c.tethers.duplicate(true)
	check.call(not TetherRules.escape(a, [c], 20, br).attempted and not TetherRules.escape(a, [c], 20, source).attempted and not TetherRules.rescue(monster("helper"), a, [c], "strike", br).attempted and c.tethers == initial, "Tether group wrong-victim and parent-only selections refuse before rolling/damage")
	var duplicate := TetherRules.apply(c, a, results[0].effect_cast, DataLoader.get_spell(SPELL).effects[0], DataLoader.get_spell(SPELL))
	check.call(not duplicate.bound and c.tethers == initial, "Tether group duplicate application cannot reset either relation")
	SpellEffects._advance(a, source, 12)
	SpellEffects._advance(b, source, 12)
	var escaped := TetherRules.escape(a, [c], 20, ar)
	check.call(escaped.get("success", false) and escaped.relation_id == ar and not TetherRules.has_source(a, source) and not SpellEffects.records(a).has(source) and c.tethers.has(br) and TetherRules.has_source(b, source) and int(SpellEffects.records(b)[source].remaining_seconds) == 48 and str(c.concentrating_on.effect_source) == source, "Tether group successful exact escape preserves sibling and original remaining lifetime")
	check.call(not TetherRules.escape(a, [c], 20, ar).attempted and not TetherRules.rescue(monster("helper2"), a, [c], "check", ar, 20).attempted and c.tethers.size() == 1, "Tether group stale escape and rescue cannot fall through to the remaining sibling")
	var rescued := TetherRules.rescue(monster("helper3"), b, [c], "check", br, 20)
	check.call(rescued.get("success", false) and rescued.relation_id == br and c.tethers.is_empty() and c.concentrating_on.is_empty() and not TetherRules.has_source(b, source), "Tether group exact rescue releases the final victim and ends concentration")
	# Independent initial saves, in both orders: a successful recipient must not
	# consume a child slot or replay the already settled failed recipient.
	for reverse in [false, true]:
		var owner := Batch031Checks._character("mixed_%s" % reverse)
		owner.spell_slots = {"1": 2}
		var failed := monster("mixed_fail_%s" % reverse)
		var saved := monster("mixed_save_%s" % reverse, 100)
		var mixed := cast(owner, [saved, failed] if reverse else [failed, saved], RENAMED)
		check.call(mixed[int(not reverse)].saved and not mixed[int(reverse)].saved and TetherRules.binding(saved, [owner]).is_empty() and TetherRules.binding(failed, [owner]).size() == 1 and owner.spell_cast_serial == 1 and int(owner.spell_slots["1"]) == 1, "Tether group mixed initial saves settle independently (%s)" % reverse)
		SpellEffects.end_concentration(owner, [])
	# Damage, range break, and recipient source removal all preserve siblings.
	for route in ["damage", "range", "recipient", "concentration", "parent"]:
		var owner := Batch031Checks._character("route_" + route)
		owner.spell_slots = {"1": 2}
		var one := monster("one_" + route)
		var two := monster("two_" + route)
		cast(owner, [one, two])
		var src := str(owner.concentrating_on.effect_source)
		var first := relation(owner, one)
		var second := relation(owner, two)
		SpellEffects.clear_source_end_events()
		if route == "damage":
			var helper := monster("cutter")
			owner.tethers[first].hp = 1
			var cut := TetherRules.rescue(helper, one, [owner], "strike", first)
			check.call(cut.get("success", false) and cut.relation_id == first and int(owner.tethers[second].hp) == 5, "Tether group damage strikes the selected relation's own HP")
		elif route == "range":
			TetherRules.enforce_range([owner], {owner.character_id: Vector2i.ZERO, one.id: Vector2i(4, 0), two.id: Vector2i(1, 0)}, {one.id: one, two.id: two})
		elif route == "recipient":
			SpellEffects.remove(one, src)
			SpellEffects.reconcile([owner], [one, two])
		elif route == "concentration": SpellEffects.end_concentration(owner, [one])
		else: SpellEffects.remove(owner, src)
		if route in ["damage", "range", "recipient"]:
			check.call(not owner.tethers.has(first) and owner.tethers.has(second) and TetherRules.has_source(two, src) and not TetherRules.has_source(one, src) and not owner.concentrating_on.is_empty(), "Tether group %s releases only the selected/affected victim" % route)
			SpellEffects.end_concentration(owner, [])
		SpellEffects.end_concentration(owner, [one, two])
		SpellEffects.remove(owner, src)
		check.call(owner.tethers.is_empty() and owner.concentrating_on.is_empty() and not TetherRules.has_source(one, src) and not TetherRules.has_source(two, src) and SpellEffects.source_end_events().filter(func(e): return e.source_id == src).size() == 2, "Tether group %s cleanup ends all remaining recipients exactly once" % route)
	_object_anchors(check)
	_combat_object_positions(check)
	_saved(check)

static func _combat_object_positions(check: Callable) -> void:
	var caster := Batch031Checks._character("live_object_owner")
	var first := Batch031Checks._character("live_object_first")
	var second := Batch031Checks._character("live_object_second")
	var room := {"id": "live_object_room", "plane": "material", "party_positions": {first.character_id: [1, 0], second.character_id: [2, 0]}, "objects": []}
	var left := {"id": "left", "position": [0, 0], "plane": "material", "hp": 4}
	var right := {"id": "right", "position": [7, 0], "plane": "material", "hp": 4}
	room.objects = [left, right]
	var old_context: Dictionary = GameManager.transition_context
	var old_state := GameManager.current_state
	var old_areas := LocatedSourceEndRules.combat_areas
	var areas := CombatSpellZones.new()
	areas.player_entities.assign([{"character": first, "hex_position": Vector2i(8, 0)}, {"character": second, "hex_position": Vector2i(9, 0)}])
	LocatedSourceEndRules.combat_areas = weakref(areas)
	GameManager.transition_context = {"local_room": room}
	GameManager.current_state = GameManager.GameState.COMBAT
	var spell := DataLoader.get_spell(OBJECT)
	var cast := SpellEffects.begin_cast(caster, spell)
	var a := TetherRules.apply(caster, first, cast, spell.effects[0], spell)
	var b := TetherRules.apply(caster, second, cast, spell.effects[0], spell)
	check.call(a.get("bound", false) and b.get("bound", false) and a.get("anchor_id") == "right" and b.get("anchor_id") == "right" and left.get("tethers", {}).is_empty(), "Object tether combat casting selects anchors from live positions instead of stale room coordinates")
	areas.player_entities[0].hex_position = Vector2i(11, 0)
	var broken := TetherRules.enforce_range([caster], {first.character_id: Vector2i(11, 0), second.character_id: Vector2i(9, 0)}, {first.character_id: first, second.character_id: second})
	check.call(broken == [a.get("relation_id", "")] and first.condition_sources.get("restrained", {}).is_empty() and right.get("tethers", {}).has(b.get("relation_id", "")) and TetherRules.binding(second, [caster]).size() == 1, "Object tether combat range updates release only the recipient moved beyond the live anchor range")
	GameManager.transition_context = old_context
	GameManager.current_state = old_state
	LocatedSourceEndRules.combat_areas = old_areas

static func _object_anchors(check: Callable) -> void:
	var caster := Batch031Checks._character("object_cord_owner")
	var rescuer := Batch031Checks._character("object_cord_helper")
	var first := Batch031Checks._character("object_cord_first")
	var second := Batch031Checks._character("object_cord_second")
	var third := Batch031Checks._character("object_cord_third")
	for victim in [first, second, third]: victim.ability_scores.set_score("STR", 1)
	first.ability_scores.set_score("DEX", 1)
	second.ability_scores.set_score("DEX", 1)
	third.ability_scores.set_score("DEX", 1)
	var room := {"id": "tether_object_test", "plane": "material", "cells": [], "party_positions": {}, "objects": []}
	for x in 10: room.cells.append([x, 0])
	room.party_positions = {caster.character_id: [0, 5], rescuer.character_id: [2, 5], first.character_id: [1, 0], second.character_id: [2, 0], third.character_id: [8, 0]}
	var left := {"id": "anchor_left", "kind": "loose", "name": "Left anchor", "position": [0, 0], "plane": "material", "hp": 4, "max_hp": 4, "contents": [], "removed": false}
	var right := {"id": "anchor_right", "kind": "loose", "name": "Right anchor", "position": [7, 0], "plane": "material", "hp": 1, "max_hp": 1, "contents": [], "removed": false}
	room.objects = [left, right]
	var old_context: Dictionary = GameManager.transition_context.duplicate(true)
	GameManager.transition_context["local_room"] = room
	var source := ""
	var cast_serial_before := -1
	var remaining_slot := -1
	for attempt in 32:
		caster.spell_slots = {"1": 2}
		var serial_before := caster.spell_cast_serial
		seed(97100 + attempt)
		var outcomes := cast(caster, [first, second, third], OBJECT)
		var relations: int = left.get("tethers", {}).size() + right.get("tethers", {}).size()
		if relations == 3 and outcomes.all(func(outcome): return outcome.get("tether", {}).get("bound", false)):
			source = str(caster.concentrating_on.get("effect_source", ""))
			cast_serial_before = serial_before
			remaining_slot = int(caster.spell_slots.get("1", 0))
			break
		for anchor in [left, right]:
			for relation in anchor.get("tethers", {}).keys().duplicate():
				var victim_id_value := str(anchor.tethers[relation].get("victim_id", ""))
				for victim in [first, second, third]:
					if victim.character_id == victim_id_value: TetherRules._release_object_anchor(anchor, str(relation), victim)
	check.call(not source.is_empty() and caster.spell_cast_serial == cast_serial_before + 1 and remaining_slot == 1 and caster.tethers.is_empty() and left.tethers.size() == 2 and right.tethers.size() == 1 and TetherRules.binding(first, [caster]).size() == 1 and TetherRules.binding(second, [caster]).size() == 1 and TetherRules.binding(third, [caster]).size() == 1, "Object tether one cast binds three victims to two stable room anchors with one payment and no caster-owned relations: " + JSON.stringify({"source": source, "left": left.get("tethers", {}).keys(), "right": right.get("tethers", {}).keys(), "bindings": [TetherRules.binding(first, [caster]).size(), TetherRules.binding(second, [caster]).size(), TetherRules.binding(third, [caster]).size()], "serial_delta": caster.spell_cast_serial - cast_serial_before, "slot_left": remaining_slot}))
	if source.is_empty(): GameManager.transition_context = old_context; return
	var first_relation := str(TetherRules.binding(first, [caster])[0].relation)
	var second_relation := str(TetherRules.binding(second, [caster])[0].relation)
	var third_relation := str(TetherRules.binding(third, [caster])[0].relation)
	check.call(str(left.tethers[first_relation].anchor_id) == "anchor_left" and left.tethers[first_relation].anchor_position == [0, 0] and left.tethers[first_relation].anchor_plane == "material" and int(left.tethers[first_relation].anchor_hp) == 4 and str(right.tethers[third_relation].anchor_id) == "anchor_right", "Object tether captures exact anchor identity, actual position, plane and HP")
	var first_condition_source := str(left.tethers[first_relation].condition_source_id)
	caster.current_hp = 0
	check.call(TetherRules.binding(second, [caster]).size() == 1 and TetherRules.binding(third, [caster]).size() == 1, "Independent object anchors remain bound after the casting Character falls")
	SpellEffects.end_concentration(caster, [first, second, third])
	check.call(TetherRules.binding(first, [caster]).size() == 1 and TetherRules.binding(second, [caster]).size() == 1 and TetherRules.binding(third, [caster]).size() == 1, "Ending another source on the caster does not remove object-owned tether conditions")
	var object_characters := {caster.character_id: caster.to_dict(), rescuer.character_id: rescuer.to_dict(), first.character_id: first.to_dict(), second.character_id: second.to_dict(), third.character_id: third.to_dict()}
	var object_save := {"active_dungeon_state": {"local_rooms": {"tether_object_test": room}}, "campaign_ledger": {"dungeon_snapshots": {}}}
	check.call(TetherRules.saved_party_error(object_characters, object_save).is_empty() and SpellEffects.saved_party_error(object_characters, object_save).is_empty(), "Object tether relations and independent sources pass the existing room/party checkpoint validators")
	var moved := TetherRules.move_object_anchor(left, room, Vector2i(4, 0), [first, second, third])
	var second_bindings_after_move := TetherRules.binding(second, [caster])
	check.call(moved.success and not TetherRules.has_source(first, first_condition_source) and second_bindings_after_move.size() == 1 and TetherRules.binding(third, [caster]).size() == 1 and left.tethers.has(second_relation) and int(left.tethers.get(second_relation, {}).get("anchor_hp", -1)) == 4, "Moving one anchor releases only the out-of-range relation and refreshes surviving anchor facts: " + JSON.stringify({"moved": moved, "left": left.get("tethers", {}).keys(), "second_bindings": second_bindings_after_move.size(), "first_condition": TetherRules.has_source(first, first_condition_source)}))
	if second_bindings_after_move.is_empty(): GameManager.transition_context = old_context; return
	var remaining_victim: Dictionary = second_bindings_after_move[0]
	var stale_relation := str(remaining_victim.relation)
	var stale_source := str(remaining_victim.condition_source)
	# Two exact choices on one victim; invalidating the captured choice cannot
	# fall through and rescue the other source.
	rescuer.spell_slots = {"1": 2}
	for attempt in 32:
		rescuer.spell_slots = {"1": 2}
		seed(97200 + attempt)
		cast(rescuer, [second], OBJECT)
		if TetherRules.binding(second, [caster, rescuer]).size() > 1: break
	var choices := TetherRules.binding(second, [caster, rescuer])
	if choices.size() > 1:
		var selected := str(choices[-1].relation)
		var selected_owner: Character = choices[-1].captor
		var selected_object: Dictionary = choices[-1].object
		TetherRules._release_object_anchor(selected_object, selected, second)
		var before_sources := second.condition_sources.duplicate(true)
		var stale := TetherRules.rescue(rescuer, second, [caster, rescuer], "check", selected, 20)
		check.call(not stale.attempted and second.condition_sources == before_sources and TetherRules.binding(second, [caster, rescuer]).any(func(entry): return str(entry.relation) != selected), "Stale object rescue choice refuses without falling through to another anchor")
		if selected_owner != null: TetherRules.prune(selected_owner)
	else:
		check.call(false, "Object tether offers two exact rescue relations for stale-choice proof")
	var destroyed := CombatObjectRules.apply_damage(right, 2, "fire")
	check.call(destroyed == 1 and right.tethers.is_empty() and TetherRules.binding(third, [caster]).is_empty() and TetherRules.binding(second, [caster]).size() == 1, "Destroying the other anchor immediately releases only its victim and preserves the left-anchor sibling")
	var unrelated_source := "condition:unrelated"
	CombatAction.apply_condition(second, "frightened", 5, unrelated_source)
	rescuer.ability_scores.set_score("STR", 30)
	rescuer.inventory.add_item("longsword")
	rescuer.inventory.equip(Inventory.Slot.WEAPON, "longsword")
	var cut := TetherRules.rescue(rescuer, second, [caster, rescuer], "strike", second_relation)
	check.call(cut.attempted and cut.get("relation_id", "") == second_relation and not TetherRules.has_source(second, stale_source) and TetherRules.has_source(second, unrelated_source), "Melee damage cuts the exact selected object tether while preserving unrelated conditions")
	for anchor in [left, right]:
		for relation in anchor.get("tethers", {}).keys().duplicate():
			var victim_id_value := str(anchor.tethers[relation].get("victim_id", ""))
			for victim in [first, second, third]:
				if victim.character_id == victim_id_value: TetherRules._release_object_anchor(anchor, str(relation), victim)
	GameManager.transition_context = old_context

static func _saved(check: Callable) -> void:
	var c := Batch031Checks._character("save_cords")
	var a := Batch031Checks._character("save_cord_a")
	var b := Batch031Checks._character("save_cord_b")
	c.spell_slots = {"1": 2}
	# Save tests need live Character victims, so choose a deterministic failed pair.
	for i in 30:
		seed(90700 + i)
		cast(c, [a, b])
		if c.tethers.size() == 2: break
		SpellEffects.end_concentration(c, [a, b])
		c.spell_slots = {"1": 2}
	var first := relation(c, a)
	var second := relation(c, b)
	check.call(not first.is_empty() and not second.is_empty(), "Tether group saved fixture binds two persistent Characters")
	if first.is_empty() or second.is_empty(): return
	c.tethers[second].hp = 3
	var records := {c.character_id: c.to_dict(), a.character_id: a.to_dict(), b.character_id: b.to_dict()}
	check.call(TetherRules.saved_error(records[c.character_id]).is_empty() and SpellEffects.saved_party_error(records).is_empty(), "Tether group saved identities, HP, caster and victim sources validate")
	# Encounter-only victims disappear without orphaning a persistent sibling.
	var foe := monster("checkpoint_foe")
	var legacy: Dictionary = records[c.character_id].duplicate(true)
	legacy.tethers = {records[c.character_id].spell_concentration.effect_source: legacy.tethers[first].duplicate(true)}
	legacy.tethers.values()[0].erase("source_id")
	check.call(TetherRules.saved_error(legacy).is_empty(), "Tether group still reads legacy source-keyed relations without migration")
	for defect in ["identity", "source", "victim", "dc", "hp", "fractional_range"]:
		var bad: Dictionary = records.duplicate(true)
		var t: Dictionary = bad[c.character_id].tethers[second]
		match defect:
			"identity": bad[c.character_id].tethers[second + "stale"] = t; bad[c.character_id].tethers.erase(second)
			"source": t.source_id += "stale"
			"victim": t.victim_id = a.character_id
			"dc": t.dc += 1
			"hp": t.hp = 6
			"fractional_range": t.range_hexes = 3.5
		check.call(not TetherRules.saved_error(bad[c.character_id]).is_empty() or not SpellEffects.saved_party_error(bad).is_empty(), "Tether group malformed saved %s refuses" % defect)
	SpellEffects.end_concentration(c, [a, b])
	for i in 30:
		seed(90800 + i)
		c.spell_slots = {"1": 2}
		cast(c, [a, foe])
		if c.tethers.size() == 2: break
		SpellEffects.end_concentration(c, [a, foe])
	var character_relation := relation(c, a)
	SpellEffects.finish_encounter([c], [c, a, foe])
	var mixed_records := {c.character_id: c.to_dict(), a.character_id: a.to_dict()}
	check.call(not character_relation.is_empty() and c.tethers.size() == 1 and c.tethers.has(character_relation) and not c.concentrating_on.is_empty() and TetherRules.saved_party_error(mixed_records).is_empty(), "Tether mixed encounter cleanup drops monster relations and preserves a saveable Character sibling")
	SpellEffects.end_concentration(c, [a])
