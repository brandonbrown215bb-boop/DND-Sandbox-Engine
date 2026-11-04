## SC-05 support 01: Color Spray as shared data. A 15-foot Cone Constitution save grants
## Blinded with the generic caster end-of-turn expiry (until the end of the caster's next turn).
class_name CrownSc05Support01Flow
extends RefCounted

const P := "SC-05 support 01: "

static func _renamed_checks(h) -> void:
	var renamed := CrownSc01Support01Flow._renamed(h, "color_spray", "crown_sc_05_support_01:neutral_glare")
	var caster := ConversionBatch002Checks.actor("crown-sc05s1-renamed", "wizard", 5)
	var target := CrownSc01Support01Flow._monster("crown-sc05s1-r", Vector2i(1, 0), 10, {"constitution": 1})
	var result := {}
	for _try in 40:
		result = CombatAction.resolve_spell(caster, target, renamed, false, {}, [], 1, 5)
		if target.conditions.has("blinded"): break
	var source := str(result.get("effect_cast", {}).get("source_id", ""))
	h._assert(target.conditions.has("blinded") and str(target.spell_effects.get(source, {}).get("expiry_phase", "")) == "end" and int(target.spell_effects.get(source, {}).get("remaining_seconds", 0)) == 12, P + "renamed cone grants Blinded until the end of the caster's next turn through CombatAction.resolve_spell with no ID registration")
	var bad := renamed.duplicate(true)
	bad.effects[1]["duration"] = 1
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "the old imported 'duration' field on grant_condition is still rejected")
	CrownSc01Support01Flow._forget(str(renamed.id))

static func run(h) -> void:
	h._enter_test("crown_sc_05_support_01_flow")
	h._setup_world()
	var spell := DataLoader.get_spell("color_spray")
	h._assert(SharedSpell.uses(spell) and SharedSpell.content_error(spell).is_empty() and int(spell.cone_size) == 3 and spell.save == "CON" and spell.components == ["V", "S", "M"] and spell.classes == ["bard", "sorcerer", "wizard"], P + "Color Spray is shared SRD 5.2.1 data (15-ft Cone, Con save, V/S/M, Bard/Sorcerer/Wizard)")
	_renamed_checks(h)
	var sorc := ConversionBatch002Checks.actor("crown-sc05s1-sorc", "sorcerer", 1)
	h._assert(ConversionBatch001Flow._prepare(sorc, ["color_spray"]), P + "Sorcerer learns Color Spray through ordinary class selection")
	sorc.inventory.add_item("component_pouch")
	PlayerManager.set_player_character(0, sorc)
	PartyManager.reset()
	PartyManager.register_player_character(0, sorc)
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	var a := CrownSc01Support01Flow._monster("crown-sc05s1-a", Vector2i(1, 0), 10, {"constitution": 1})
	var immune := CrownSc01Support01Flow._monster("crown-sc05s1-immune", Vector2i(2, 0), 10, {"constitution": 1})
	immune.condition_immunities = ["blinded"]
	var far := CrownSc01Support01Flow._monster("crown-sc05s1-far", Vector2i(6, 0), 10, {"constitution": 1})
	combat.monster_entities.clear()
	combat.monster_entities.assign([a, immune, far])
	combat._update_grid_entities()
	GameManager.test_mode = false
	var ok := false
	for _attempt in 40:
		for m in [a, immune, far]:
			m.conditions.clear(); m.condition_sources.clear(); m.spell_effects.clear()
		sorc.spell_slots["1"] = 2
		ConversionBatch002Flow._select(h, combat, sorc, "color_spray", 1)
		await combat._on_hex_clicked(Vector2i(1, 0))
		await ConversionBatch002Flow._wait_resolution(h, combat)
		if int(sorc.spell_slots["1"]) != 1:
			h._assert(false, P + "each cast pays exactly one slot (%s)" % combat.hud.log_text.text.right(300))
			break
		if a.conditions.has("blinded"):
			ok = true
			break
	var source := ""
	for key in a.spell_effects: source = str(key)
	var record: Dictionary = a.spell_effects.get(source, {})
	h._assert(ok and str(record.get("expiry_phase", "")) == "end" and int(record.get("remaining_seconds", 0)) == 12, P + "picker + cone click: a failed Con save Blinds the creature until the end of the caster's next turn")
	h._assert(not immune.conditions.has("blinded") and immune.spell_effects.is_empty(), P + "a Blinded-immune creature in the Cone gains nothing")
	h._assert(not far.conditions.has("blinded") and far.spell_effects.is_empty(), P + "a creature 30 feet away is outside the 15-foot Cone")
	h._assert(CombatAction.attacker_has_condition_disadvantage(a), P + "the Blinded creature's attack rolls have Disadvantage")
	var owner := SpellEffects.caster_id(sorc)
	SpellEffects.tick_boundary([a], str(a.id), "end")
	SpellEffects.tick_boundary([a], owner, "end")
	h._assert(a.conditions.has("blinded"), P + "Blinded survives the target's turn and the end of the casting turn")
	SpellEffects.tick_boundary([a], owner, "end")
	h._assert(not a.conditions.has("blinded") and not a.spell_effects.has(source), P + "Blinded ends at the end of the caster's next turn")
	GameManager.test_mode = true
	h._teardown_scene(combat)
	h._exit_test()
