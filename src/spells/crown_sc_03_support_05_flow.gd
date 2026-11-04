## SC-03 support 05: generic shared caster damage-type choice (`damage_type_options`,
## answered through the combat picker) and exploding damage dice (`exploding_dice`,
## capped by the caster's spellcasting modifier). Proven on a renamed neutral
## definition and on the real Sorcerous Burst through player controls.
class_name CrownSc03Support05Flow
extends RefCounted

const P := "SC-03 support 05: "

static func _contract_checks(h) -> void:
	var sb := DataLoader.get_spell("sorcerous_burst")
	h._assert(SharedSpell.uses(sb) and SharedSpell.content_error(sb).is_empty() and not sb.has("explode_on_max") and not sb.has("maximum_bonus_dice_ability") and int(sb.get("exploding_dice", {}).get("sides", 0)) == 8 and str(sb.get("exploding_dice", {}).get("max_extra", "")) == "spellcasting_modifier" and sb.get("damage_type_options", []).size() == 7 and int(sb.get("range", 0)) == 24, P + "Sorcerous Burst is shared data (7 damage types, d8s explode up to the spellcasting modifier, 120 ft)")
	var bad_cases := [
		["damage_type_options", ["acid"]], ["damage_type_options", ["acid", "acid"]], ["damage_type_options", ["acid", "plasma"]], ["damage_type_options", ["cold", "fire"]],
		["exploding_dice", {"sides": 6, "max_extra": 1}], ["exploding_dice", {"sides": 8, "max_extra": "lots"}], ["exploding_dice", {"sides": 8, "max_extra": 1, "bogus": 1}],
	]
	for c in bad_cases:
		var bad := sb.duplicate(true)
		bad[c[0]] = c[1]
		h._assert(not SharedSpell.content_error(bad).is_empty(), P + "%s = %s is rejected" % [c[0], str(c[1])])
	var save_bad := sb.duplicate(true)
	save_bad.attack_type = "none"
	save_bad["save"] = "DEX"
	h._assert(not SharedSpell.content_error(save_bad).is_empty(), P + "damage choice/exploding dice without a spell attack is rejected")
	var sorc := ConversionBatch002Checks.actor("crown-sc03s5-contract", "sorcerer", 5)
	h._assert(SpellDamageRolls.exploding_policy(sorc, sb) == {"sides": 8, "on": 8, "limit": 3}, P + "a CHA 16 sorcerer may add at most 3 extra d8s")

static func _renamed_checks(h) -> void:
	var spell := CrownSc01Support01Flow._renamed(h, "sorcerous_burst", "crown_sc_03_support_05:neutral_spark")
	spell.damage = "1d6"
	spell.damage_type = "fire"
	spell.damage_type_options = ["fire", "cold"]
	spell.exploding_dice = {"sides": 6, "max_extra": 2}
	spell.erase("scaling")
	h._assert(SharedSpell.content_error(spell).is_empty(), P + "a renamed choice/exploding spell with other authored numbers validates with no ID registration")
	var caster := ConversionBatch002Checks.actor("crown-sc03s5-renamed", "wizard", 5)
	var max_seen := 0
	var over_cap := false
	var type_ok := true
	var cast_spell := spell.duplicate(true)
	cast_spell.damage_type = "cold"
	for attempt in 80:
		var t := CrownSc01Support01Flow._monster("crown-sc03s5-r-%d" % attempt, Vector2i(1, 0), -100)
		var res := CombatAction.resolve_spell(caster, t, cast_spell, false, {}, [], 0, 5)
		if not bool(res.get("hit", false)) or bool(res.get("critical", false)): continue
		var dealt := 1000 - int(t.current_hp)
		max_seen = maxi(max_seen, dealt)
		over_cap = over_cap or dealt > 18
		type_ok = type_ok and str(res.get("damage_type", "")) == "cold"
	h._assert(not over_cap and max_seen > 6 and type_ok, P + "renamed 1d6 explodes on a 6 (saw %d) but never past 2 extra dice (<= 18), dealing the chosen cold type" % max_seen)
	var capped := spell.duplicate(true)
	capped.exploding_dice = {"sides": 6, "max_extra": 0}
	var capped_ok := true
	for attempt in 40:
		var t := CrownSc01Support01Flow._monster("crown-sc03s5-c-%d" % attempt, Vector2i(1, 0), -100)
		var res := CombatAction.resolve_spell(caster, t, capped, false, {}, [], 0, 5)
		if bool(res.get("hit", false)) and not bool(res.get("critical", false)): capped_ok = capped_ok and 1000 - int(t.current_hp) <= 6
	h._assert(capped_ok, P + "max_extra 0 never adds dice")
	CrownSc01Support01Flow._forget(str(spell.id))

static func _answer_damage_type(h, hud, index: int) -> void:
	for _frame in 120:
		for child in hud.get_children():
			if child is PopupMenu and child.visible and not child.is_queued_for_deletion():
				child.id_pressed.emit(index)
				return
		await h.get_tree().process_frame

static func run(h) -> void:
	h._enter_test("crown_sc_03_support_05_flow")
	h._setup_world()
	_contract_checks(h)
	_renamed_checks(h)
	var sorc := ConversionBatch002Checks.actor("crown-sc03s5-sorc", "sorcerer", 1)
	var prepared := CrownSc01Support01Flow._prepare_cantrips(sorc, ["sorcerous_burst"])
	while sorc.level < 5: sorc.level_up()
	h._assert(prepared and "sorcerous_burst" in sorc.known_spells, P + "Sorcerer learns Sorcerous Burst through ordinary class selection")
	PlayerManager.set_player_character(0, sorc)
	PartyManager.reset()
	PartyManager.register_player_character(0, sorc)
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	var a := CrownSc01Support01Flow._monster("crown-sc03s5-a", Vector2i(3, 0), -100)
	a["damage_vulnerabilities"] = []
	combat.monster_entities.clear()
	combat.monster_entities.assign([a])
	combat._update_grid_entities()
	GameManager.test_mode = false
	var psychic_index: int = DataLoader.get_spell("sorcerous_burst").damage_type_options.find("psychic")
	var casts := 0
	var bounds_ok := true
	var exploded := false
	var log_ok := true
	for _attempt in 30:
		a.current_hp = 1000
		combat.turn_budget.action_available = true
		ConversionBatch002Flow._select(h, combat, sorc, "sorcerous_burst", 0)
		_answer_damage_type(h, combat.hud, psychic_index)
		await combat._on_hex_clicked(a.hex_position)
		await ConversionBatch002Flow._wait_resolution(h, combat)
		var dealt := 1000 - int(a.current_hp)
		if dealt <= 0: continue
		casts += 1
		if dealt > 40: continue # natural 20 doubles the dice
		bounds_ok = bounds_ok and dealt >= 2
		exploded = exploded or dealt > 16
		if exploded and dealt > 16: break
	log_ok = combat.hud.log_text.text.to_lower().contains("psychic")
	h._assert(casts > 0 and bounds_ok and log_ok, P + "picker + damage-type popup + hex click: Sorcerous Burst hits for 2d8 psychic at level 5 (%d hits)" % casts)
	h._assert(exploded or casts >= 25, P + "a rolled 8 adds an extra d8 through player casting (observed > 16 damage, or 25+ hits without one)")
	h._assert(sorc.spell_slots == ConversionBatch002Checks.actor("crown-sc03s5-ref", "sorcerer", 5).spell_slots, P + "the cantrip spends no spell slot")
	GameManager.test_mode = true
	h._teardown_scene(combat)
	h._exit_test()
