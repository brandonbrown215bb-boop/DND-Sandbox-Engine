## SC-03 support 04: generic shared `delayed_damage` (a spell-attack hit schedules a
## second roll at the end of the target's next turn, upcast with the initial damage)
## plus miss-half through `damage_scale_by_outcome`. Proven on a renamed neutral
## definition and on the real Melf's Acid Arrow through player controls.
class_name CrownSc03Support04Flow
extends RefCounted

const P := "SC-03 support 04: "

static func _contract_checks(h) -> void:
	var aa := DataLoader.get_spell("melfs_acid_arrow")
	h._assert(SharedSpell.uses(aa) and SharedSpell.content_error(aa).is_empty() and not aa.has("miss_damage_scale") and aa.get("damage_scale_by_outcome", {}) == {"hit": 1.0, "miss": 0.5}, P + "Melf's Acid Arrow is shared data (miss half via damage_scale_by_outcome, no native miss_damage_scale)")
	var cases := [["damage", "lots"], ["damage_type", "plasma"], ["trigger", "start_of_caster_turn"], ["bogus", 1]]
	for c in cases:
		var bad := aa.duplicate(true)
		bad.delayed_damage[c[0]] = c[1]
		h._assert(not SharedSpell.content_error(bad).is_empty(), P + "delayed_damage.%s = %s is rejected" % [c[0], str(c[1])])
	var bad := aa.duplicate(true)
	bad.attack_type = "none"
	bad.erase("damage_scale_by_outcome")
	bad["save"] = {"ability": "dex"}
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "delayed_damage without a spell attack is rejected")
	var caster := ConversionBatch002Checks.actor("crown-sc03s4-contract", "wizard", 5)
	h._assert(CombatAction.spell_damage_formula(caster, aa, 3) == "4d4 + 1d4" and CombatAction.spell_delayed_damage_for_resolution(caster, aa, {"hit": true, "slot_level": 3}).get("formula", "") == "2d4 + 1d4", P + "a 3rd-level slot adds 1d4 to both initial and later damage")
	h._assert(CombatAction.spell_delayed_damage_for_resolution(caster, aa, {"hit": false, "slot_level": 2}).is_empty(), P + "a miss schedules no later damage")

static func _renamed_checks(h) -> void:
	var spell := CrownSc01Support01Flow._renamed(h, "melfs_acid_arrow", "crown_sc_03_support_04:neutral_bolt")
	spell.damage = "4"
	spell.damage_type = "cold"
	spell.delayed_damage = {"damage": "1d6", "damage_type": "fire", "trigger": "end_of_target_next_turn"}
	spell.upcast = {"starting_level": 2, "damage_per_level": "1d4"}
	h._assert(SharedSpell.content_error(spell).is_empty(), P + "a renamed delayed-damage spell with other authored numbers validates with no ID registration")
	var caster := ConversionBatch002Checks.actor("crown-sc03s4-renamed", "wizard", 5)
	var ok := false
	for attempt in 6:
		var t := CrownSc01Support01Flow._monster("crown-sc03s4-hit-%d" % attempt, Vector2i(1, 0), -100)
		var res := CombatAction.resolve_spell(caster, t, spell, false, {}, [], 3, 5)
		if bool(res.get("hit", false)) and not bool(res.get("critical", false)):
			var later := CombatAction.spell_delayed_damage_for_resolution(caster, spell, res)
			var dealt := 1000 - int(t.current_hp)
			ok = dealt >= 5 and dealt <= 12 and later.get("formula", "") == "1d6 + 1d4" and later.get("damage_type", "") == "fire"
			break
	h._assert(ok, P + "renamed hit deals 4 + 1d4 cold now (non-critical hit) and schedules 1d6 + 1d4 fire through CombatAction.resolve_spell")
	ok = false
	for attempt in 6:
		var t := CrownSc01Support01Flow._monster("crown-sc03s4-miss-%d" % attempt, Vector2i(1, 0), 100)
		var res := CombatAction.resolve_spell(caster, t, spell, false, {}, [], 3, 5)
		if not bool(res.get("hit", true)):
			var dealt := 1000 - int(t.current_hp)
			ok = dealt >= 2 and dealt <= 4 and CombatAction.spell_delayed_damage_for_resolution(caster, spell, res).is_empty()
			break
	h._assert(ok, P + "renamed miss deals half the initial damage (2-4 of 5-8) and schedules nothing")
	CrownSc01Support01Flow._forget(str(spell.id))

## Ordinary re-selection after level-ups: keep the cantrips already chosen, add `wanted`, fill open slots.
static func _prepare_keeping(caster: Character, wanted: String) -> bool:
	var chosen: Array[String] = []
	var options := caster.get_spell_option_ids(true)
	for id in caster.known_spells:
		if id in options and chosen.size() < caster.get_spellcasting_capacity("cantrips"): chosen.append(id)
	for id in options:
		if chosen.size() >= caster.get_spellcasting_capacity("cantrips"): break
		if id not in chosen: chosen.append(id)
	var spells: Array[String] = [wanted]
	for id in caster.get_spell_option_ids(false):
		if spells.size() >= caster.get_spellcasting_capacity("prepared_spells"): break
		if id not in spells: spells.append(id)
	chosen.append_array(spells)
	return ClassProgression.choose_spell_selection(caster, chosen)

static func run(h) -> void:
	h._enter_test("crown_sc_03_support_04_flow")
	h._setup_world()
	_contract_checks(h)
	_renamed_checks(h)
	var wizard := ConversionBatch002Checks.actor("crown-sc03s4-wizard", "wizard", 1)
	while wizard.level < 5: wizard.level_up()
	var book: Array[String] = ["melfs_acid_arrow"]
	for option in DataLoader.get_castable_spell_list_options(wizard.get_spell_list_ids()):
		if book.size() >= wizard.wizard_spellbook_pending: break
		if int(option.get("level", 0)) in [1, 2, 3] and str(option.id) not in book: book.append(str(option.id))
	h._assert(ClassProgression.choose_wizard_spellbook(wizard, book) and _prepare_keeping(wizard, "melfs_acid_arrow") and "melfs_acid_arrow" in wizard.known_spells, P + "Wizard records Melf's Acid Arrow in its spellbook and prepares it through ordinary class selection")
	wizard.inventory.add_item("component_pouch")
	wizard.spell_slots = {"2": 3, "3": 2}
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	var a := CrownSc01Support01Flow._monster("crown-sc03s4-a", Vector2i(2, 0), -100)
	combat.monster_entities.clear()
	combat.monster_entities.assign([a])
	combat._update_grid_entities()
	GameManager.test_mode = false
	# Hit from a 3rd-level slot: 5d4 now, 3d4 scheduled for the end of A's next turn.
	var hit_ok := false
	var later_ok := false
	for _attempt in 4:
		a.current_hp = 1000
		a["delayed_spell_damage"] = []
		combat.turn_budget.action_available = true
		ConversionBatch002Flow._select(h, combat, wizard, "melfs_acid_arrow", 3)
		await combat._on_hex_clicked(a.hex_position)
		await ConversionBatch002Flow._wait_resolution(h, combat)
		var now := 1000 - int(a.current_hp)
		var pending: Array = a.get("delayed_spell_damage", [])
		if now > 20: continue # natural 20 doubles the dice
		hit_ok = now >= 5 and pending.size() == 1 and pending[0].get("formula", "") == "2d4 + 1d4" and pending[0].get("damage_type", "") == "acid"
		await combat._resolve_delayed_spell_damage(a)
		var later := 1000 - int(a.current_hp) - now
		later_ok = later >= 3 and later <= 12 and a.get("delayed_spell_damage", []).is_empty()
		break
	h._assert(hit_ok, P + "picker + hex click: a 3rd-level hit deals 5d4 acid and schedules 2d4 + 1d4 acid on the target")
	h._assert(later_ok, P + "the target's end-of-turn hook deals the scheduled 3d4 acid once and clears it")
	# Miss: half the initial damage, nothing scheduled.
	var b := CrownSc01Support01Flow._monster("crown-sc03s4-b", Vector2i(0, 2), 100)
	combat.monster_entities.assign([a, b])
	combat._update_grid_entities()
	var miss_ok := false
	for _attempt in 4:
		b.current_hp = 1000
		combat.turn_budget.action_available = true
		ConversionBatch002Flow._select(h, combat, wizard, "melfs_acid_arrow", 2)
		await combat._on_hex_clicked(b.hex_position)
		await ConversionBatch002Flow._wait_resolution(h, combat)
		var dmg := 1000 - int(b.current_hp)
		if dmg > 8 or not b.get("delayed_spell_damage", []).is_empty(): # a natural 20 still hits
			b["delayed_spell_damage"] = []
			continue
		miss_ok = dmg >= 2 and dmg <= 8 and b.get("delayed_spell_damage", []).is_empty()
		break
	h._assert(miss_ok, P + "a miss splashes half of 4d4 (2-8) and schedules no later damage")
	h._assert(int(wizard.spell_slots.get("3", 0)) <= 1 and int(wizard.spell_slots.get("2", 0)) <= 2, P + "casts spend the chosen slot levels")
	GameManager.test_mode = true
	h._teardown_scene(combat)
	h._exit_test()
