## SC-03 support 02: generic shared weapon_attack payload (attack with the
## material-component weapon using the spellcasting ability, a data-authored
## damage-type choice, and character-level extra damage bands). Proven on a
## renamed neutral definition and on the real True Strike through player controls.
class_name CrownSc03Support02Flow
extends RefCounted

const P := "SC-03 support 02: "

static func _contract_checks(h) -> void:
	var strike := DataLoader.get_spell("true_strike").duplicate(true)
	h._assert(SharedSpell.uses(strike) and SharedSpell.content_error(strike).is_empty() and not SharedSpell.weapon_attack_effect(strike).is_empty(), P + "True Strike is shared weapon_attack data")
	var bad := strike.duplicate(true)
	bad.effects[0].ability = "STR"
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "a non-spellcasting ability is rejected")
	bad = strike.duplicate(true)
	bad.effects[0].damage_type_options = ["radiant"]
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "damage options without the weapon's own type are rejected")
	bad = strike.duplicate(true)
	bad.effects[0].extra_damage.by_character_level = {"five": "1d6"}
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "non-integer level bands are rejected")
	bad = strike.duplicate(true)
	bad.effects[0].weapon = "any"
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "an unknown weapon requirement is rejected")
	var effect := SharedSpell.weapon_attack_effect(strike)
	h._assert(SharedSpell.weapon_attack_extra_formula(effect, 4).is_empty() and SharedSpell.weapon_attack_extra_formula(effect, 5) == "1d6" and SharedSpell.weapon_attack_extra_formula(effect, 11) == "2d6" and SharedSpell.weapon_attack_extra_formula(effect, 17) == "3d6", P + "extra Radiant dice follow the authored level bands 5/11/17")

static func _renamed_checks(h) -> void:
	var neutral := CrownSc01Support01Flow._renamed(h, "true_strike", "crown_sc_03_support_02:neutral_strike")
	neutral.effects[0].damage_type_options = ["weapon", "necrotic"]
	neutral.effects[0].extra_damage = {"type": "necrotic", "by_character_level": {"1": "1d4"}}
	h._assert(SharedSpell.content_error(neutral).is_empty() and SharedSpell.weapon_attack_extra_formula(SharedSpell.weapon_attack_effect(neutral), 1) == "1d4", P + "a renamed weapon_attack with other authored types and bands validates with no ID registration")
	var caster := ConversionBatch002Checks.actor("crown-sc03s2-renamed", "wizard", 5)
	caster.inventory.equipped[Inventory.Slot.WEAPON] = "spear"
	var cast := SpellCastContext.new()
	cast.caster = caster
	var reach := SpellCastTargeting._spell_target_range(cast, neutral)
	h._assert(reach == maxi(1, CombatAction.weapon_range_hexes(DataLoader.get_item("spear"))), P + "renamed weapon_attack takes its targeting range from the equipped weapon")
	var target := CrownSc01Support01Flow._monster("crown-sc03s2-renamed-target", Vector2i(1, 0), -100)
	var res := CombatAction.resolve_spell(caster, target, neutral, false, {}, [], 0, 1)
	h._assert(bool(res.get("success", false)) and int(target.current_hp) == 1000, P + "renamed definition resolves through CombatAction.resolve_spell; the weapon swing belongs to the player cast host")
	CrownSc01Support01Flow._forget(str(neutral.id))

static func _answer_choice(h, combat, index: int) -> bool:
	for _frame in 120:
		for child in combat.hud.get_children():
			if child is PopupMenu and child.visible and child.item_count == 2:
				child.id_pressed.emit(index)
				return true
		await h.get_tree().process_frame
	return false

static func run(h) -> void:
	h._enter_test("crown_sc_03_support_02_flow")
	h._setup_world()
	_contract_checks(h)
	_renamed_checks(h)
	var wizard := ConversionBatch002Checks.actor("crown-sc03s2-sorcerer", "sorcerer", 1)
	h._assert(CrownSc01Support01Flow._prepare_cantrips(wizard, ["true_strike"]), P + "Sorcerer learns True Strike through ordinary class selection")
	while wizard.level < 5: wizard.level_up()
	h._assert("true_strike" in wizard.known_spells, P + "True Strike stays known through level 5")
	wizard.inventory.equipped[Inventory.Slot.WEAPON] = "club"
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	var radiant_target := CrownSc01Support01Flow._monster("crown-sc03s2-radiant", Vector2i(1, 0), -100)
	var weapon_target := CrownSc01Support01Flow._monster("crown-sc03s2-weapon", Vector2i(0, 1), -100)
	var far_target := CrownSc01Support01Flow._monster("crown-sc03s2-far", Vector2i(3, 0), -100)
	combat.monster_entities.clear()
	combat.monster_entities.assign([radiant_target, weapon_target, far_target])
	combat._update_grid_entities()
	GameManager.test_mode = false
	var results := {}
	for pair in [[radiant_target, 1, "radiant"], [weapon_target, 0, "bludgeoning"]]:
		var slots := wizard.spell_slots.duplicate(true)
		var asked := false
		for _attempt in 6: # a natural 1 still misses AC -100
			ActivityHistory.clear()
			ConversionBatch002Flow._select(h, combat, wizard, "true_strike", 0)
			combat.call_deferred("_on_hex_clicked", pair[0].hex_position)
			asked = await _answer_choice(h, combat, pair[1])
			await ConversionBatch002Flow._wait_resolution(h, combat)
			if int(pair[0].current_hp) < 1000: break
		var records: Array = ActivityHistory.get_records().filter(func(record): return str(record.get("kind", "")) == "spell_attack" and str(record.get("title", "")) == "True Strike — Club")
		var attacks: Array = records[-1].get("payload", {}).get("sections", {}).get("attacks", []) if not records.is_empty() else []
		var comps: Array = attacks[0].get("damage_components", []) if not attacks.is_empty() else []
		var types := comps.map(func(c): return str(c.get("type", "")))
		h._assert(asked and int(pair[0].current_hp) < 1000 and pair[2] in types and "radiant" in types and not combat.turn_budget.action_available and wizard.spell_slots == slots, P + "picker + hex click swings the Club with %s damage plus level-5 Radiant, spending the action and no slot" % pair[2])
		if pair[2] == "bludgeoning":
			h._assert(str(attacks[0].get("damage", {}).get("additional_damage_formula", "")) == "1d6" if not attacks.is_empty() else false, P + "the recorded extra dice come from the authored level band")
	# Out of the Club's reach: the click does not resolve the spell.
	ConversionBatch002Flow._select(h, combat, wizard, "true_strike", 0)
	await combat._on_hex_clicked(far_target.hex_position)
	await ConversionBatch002Flow._wait_resolution(h, combat)
	h._assert(int(far_target.current_hp) == 1000, P + "a creature beyond the weapon's reach is not struck")
	combat._on_hud_action("cancel", {})
	# Without a proficient, valued weapon the spell refuses before spending the action.
	wizard.inventory.equipped[Inventory.Slot.WEAPON] = ""
	ConversionBatch002Flow._select(h, combat, wizard, "true_strike", 0)
	await combat._on_hex_clicked(radiant_target.hex_position)
	await ConversionBatch002Flow._wait_resolution(h, combat)
	h._assert(combat.turn_budget.action_available, P + "with no weapon equipped the cast is refused and the action is kept")
	GameManager.test_mode = true
	h._teardown_scene(combat)
	h._exit_test()
