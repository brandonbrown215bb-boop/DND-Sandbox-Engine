## SC-03 support 03: generic shared `projectiles` payload (multi-target split of
## automatic darts or per-projectile spell attacks, slot or character-level count
## scaling, data-flagged Shield negation). Proven on renamed neutral definitions
## and on the real Magic Missile / Scorching Ray / Eldritch Blast through player controls.
class_name CrownSc03Support03Flow
extends RefCounted

const P := "SC-03 support 03: "

static func _contract_checks(h) -> void:
	for id in ["magic_missile", "scorching_ray", "eldritch_blast"]:
		var spell := DataLoader.get_spell(id)
		h._assert(SharedSpell.uses(spell) and SharedSpell.content_error(spell).is_empty() and spell.get("projectiles") is Dictionary and not spell.has("upcast") and not spell.has("damage_per_dart") and not spell.has("damage_per_ray"), P + "%s is shared projectiles data with no native per-dart/ray keys" % id)
	var mm := DataLoader.get_spell("magic_missile")
	var cases := [["delivery", "homing"], ["count", 0], ["count", 2.5], ["noun", ""], ["damage", "lots"], ["extra_per_slot_level", -1], ["shield_negates", "yes"], ["count_by_character_level", {"1": 1}], ["bogus", 1]]
	for c in cases:
		var bad := mm.duplicate(true)
		bad.projectiles[c[0]] = c[1]
		h._assert(not SharedSpell.content_error(bad).is_empty(), P + "projectiles.%s = %s is rejected" % [c[0], str(c[1])])
	var bad := mm.duplicate(true)
	bad["attack_type"] = "ranged_spell"
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "automatic delivery with a spell attack_type is rejected")
	bad = mm.duplicate(true)
	bad["damage"] = "1d4"
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "a top-level damage beside projectiles is rejected")
	h._assert(SpellProjectileResolver.shield_negates(mm) and not SpellProjectileResolver.shield_negates(DataLoader.get_spell("scorching_ray")), P + "Shield negation is a data flag on Magic Missile only")
	h._assert(CombatAction.magic_missile_dart_count(mm, 1) == 3 and CombatAction.magic_missile_dart_count(mm, 3) == 5, P + "Magic Missile: 3 darts, +1 per slot level above 1st")
	var sr := DataLoader.get_spell("scorching_ray")
	h._assert(CombatAction.scorching_ray_count(null, sr, 2) == 3 and CombatAction.scorching_ray_count(null, sr, 4) == 5, P + "Scorching Ray: 3 rays, +1 per slot level above 2nd")
	var eb := DataLoader.get_spell("eldritch_blast")
	var counts := []
	for lvl in [1, 4, 5, 10, 11, 16, 17]:
		var c := ConversionBatch002Checks.actor("crown-sc03s3-eb-%d" % lvl, "warlock", 1)
		while c.level < lvl: c.level_up()
		counts.append(CombatAction.scorching_ray_count(c, eb, 0))
	h._assert(counts == [1, 1, 2, 2, 3, 3, 4], P + "Eldritch Blast beams follow the authored bands 1/5/11/17: %s" % str(counts))

static func _renamed_checks(h) -> void:
	var darts := CrownSc01Support01Flow._renamed(h, "magic_missile", "crown_sc_03_support_03:neutral_darts")
	darts.projectiles = {"noun": "shard", "delivery": "automatic", "damage": "2", "count": 2, "extra_per_slot_level": 2}
	darts.damage_type = "cold"
	h._assert(SharedSpell.content_error(darts).is_empty() and SpellProjectileResolver.noun(darts) == "shard", P + "a renamed automatic projectile spell with other authored numbers validates with no ID registration")
	var caster := ConversionBatch002Checks.actor("crown-sc03s3-renamed", "wizard", 5)
	var target := CrownSc01Support01Flow._monster("crown-sc03s3-renamed-target", Vector2i(1, 0), 10)
	var res := CombatAction.resolve_spell(caster, target, darts, false, {}, [], 2, 5)
	h._assert(bool(res.get("success", false)) and int(res.get("dart_count", 0)) == 4 and int(target.current_hp) == 992, P + "renamed darts resolve 2 + 2 per slot level = 4 x 2 cold through CombatAction.resolve_spell")
	var one := darts.duplicate(true)
	one["_projectile_count_for_target"] = 1
	var target2 := CrownSc01Support01Flow._monster("crown-sc03s3-renamed-target2", Vector2i(2, 0), 10)
	CombatAction.resolve_spell(caster, target2, one, false, {}, [], 2, 10)
	h._assert(int(target2.current_hp) == 998, P + "a per-target allocation of one projectile deals exactly one projectile's damage")
	var cast := SpellCastContext.new()
	cast.caster = caster
	h._assert(SpellCastTargeting._spell_target_range(cast, darts) == int(darts.range), P + "renamed projectile spell uses its authored range")
	CrownSc01Support01Flow._forget(str(darts.id))
	var rays := CrownSc01Support01Flow._renamed(h, "scorching_ray", "crown_sc_03_support_03:neutral_rays")
	rays.projectiles = {"noun": "bolt", "delivery": "spell_attack", "damage": "1", "count": 2, "extra_per_slot_level": 0}
	h._assert(SharedSpell.content_error(rays).is_empty(), P + "a renamed attack-roll projectile spell validates")
	var hit := false
	for _attempt in 6:
		var rt := CrownSc01Support01Flow._monster("crown-sc03s3-ray-target-%d" % _attempt, Vector2i(1, 0), -100)
		var rr := CombatAction.resolve_spell(caster, rt, rays, false, {}, [], 2, 5)
		if bool(rr.get("success", false)) and int(rr.get("ray_count", 0)) == 2 and int(rr.get("rays_hit", 0)) == 2 and int(rt.current_hp) == 998:
			hit = true
			break
	h._assert(hit, P + "renamed rays make one spell attack per projectile through CombatAction.resolve_spell")
	CrownSc01Support01Flow._forget(str(rays.id))

## Ordinary class spell selection with the wanted spells first, cantrips and open slots filled.
static func _prepare(caster: Character, wanted: Array[String]) -> bool:
	var cantrips: Array[String] = []
	for id in caster.get_spell_option_ids(true):
		if cantrips.size() >= caster.get_spellcasting_capacity("cantrips"): break
		cantrips.append(id)
	var spells: Array[String] = wanted.duplicate()
	for id in caster.get_spell_option_ids(false):
		if spells.size() >= caster.get_spellcasting_capacity("prepared_spells"): break
		if id not in spells: spells.append(id)
	var chosen: Array[String] = cantrips
	chosen.append_array(spells)
	return ClassProgression.choose_spell_selection(caster, chosen)

static func _cast(h, combat, caster, id: String, slot: int, clicks: Array) -> void:
	ConversionBatch002Flow._select(h, combat, caster, id, slot)
	for i in clicks.size():
		if i == clicks.size() - 1:
			combat.call_deferred("_on_hex_clicked", clicks[i])
		else:
			await combat._on_hex_clicked(clicks[i])
	await ConversionBatch002Flow._wait_resolution(h, combat)

static func run(h) -> void:
	h._enter_test("crown_sc_03_support_03_flow")
	h._setup_world()
	_contract_checks(h)
	_renamed_checks(h)
	var wizard := ConversionBatch002Checks.actor("crown-sc03s3-sorcerer", "sorcerer", 5)
	h._assert(_prepare(wizard, ["magic_missile", "scorching_ray"]) and "magic_missile" in wizard.known_spells and "scorching_ray" in wizard.known_spells, P + "Sorcerer prepares Magic Missile and Scorching Ray through ordinary class selection")
	wizard.spell_slots = {"1": 4, "2": 2}
	PlayerManager.set_player_character(0, wizard)
	PartyManager.reset()
	PartyManager.register_player_character(0, wizard)
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	var a := CrownSc01Support01Flow._monster("crown-sc03s3-a", Vector2i(2, 0), -100)
	var b := CrownSc01Support01Flow._monster("crown-sc03s3-b", Vector2i(0, 2), -100)
	combat.monster_entities.clear()
	combat.monster_entities.assign([a, b])
	combat._update_grid_entities()
	GameManager.test_mode = false
	# Magic Missile 2 + 1 split: darts auto-hit, so damage bounds prove the allocation.
	await _cast(h, combat, wizard, "magic_missile", 1, [a.hex_position, a.hex_position, b.hex_position])
	await ConversionBatch002Flow._wait_resolution(h, combat)
	var da := 1000 - int(a.current_hp)
	var db := 1000 - int(b.current_hp)
	h._assert(da >= 4 and da <= 10 and db >= 2 and db <= 5 and int(wizard.spell_slots.get("1", 0)) == 3, P + "picker + three hex clicks split Magic Missile 2 + 1 (A took %d, B took %d) and spend one 1st-level slot" % [da, db])
	# Scorching Ray 1 + 2 split from a 2nd-level slot.
	a.current_hp = 1000
	b.current_hp = 1000
	combat.turn_budget.action_available = true
	await _cast(h, combat, wizard, "scorching_ray", 2, [a.hex_position, b.hex_position, b.hex_position])
	await ConversionBatch002Flow._wait_resolution(h, combat)
	da = 1000 - int(a.current_hp)
	db = 1000 - int(b.current_hp)
	h._assert(da <= 12 and db <= 24 and (da > 0 or db > 0) and int(wizard.spell_slots.get("2", 0)) == 1, P + "Scorching Ray splits 1 + 2 rays by hex clicks (A took %d of max 12, B %d of max 24) and spends a 2nd-level slot" % [da, db])
	GameManager.test_mode = true
	h._teardown_scene(combat)
	# Eldritch Blast at warlock level 5: two beams split 1 + 1 by hex clicks.
	var warlock := ConversionBatch002Checks.actor("crown-sc03s3-warlock", "warlock", 1)
	h._assert(CrownSc01Support01Flow._prepare_cantrips(warlock, ["eldritch_blast"]), P + "Warlock learns Eldritch Blast through ordinary class selection")
	while warlock.level < 5: warlock.level_up()
	PlayerManager.set_player_character(0, warlock)
	PartyManager.reset()
	PartyManager.register_player_character(0, warlock)
	combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	a = CrownSc01Support01Flow._monster("crown-sc03s3-eb-a", Vector2i(2, 0), -100)
	b = CrownSc01Support01Flow._monster("crown-sc03s3-eb-b", Vector2i(0, 2), -100)
	combat.monster_entities.clear()
	combat.monster_entities.assign([a, b])
	combat._update_grid_entities()
	GameManager.test_mode = false
	var split := false
	for _attempt in 6:
		a.current_hp = 1000
		b.current_hp = 1000
		combat.turn_budget.action_available = true
		await _cast(h, combat, warlock, "eldritch_blast", 0, [a.hex_position, b.hex_position])
		await ConversionBatch002Flow._wait_resolution(h, combat)
		if int(a.current_hp) < 1000 and int(b.current_hp) < 1000:
			split = 1000 - int(a.current_hp) <= 20 and 1000 - int(b.current_hp) <= 20
			break
	h._assert(split, P + "picker + two hex clicks send one level-5 Eldritch Blast beam to each creature (each took at most one 1d10 beam, crit included)")
	GameManager.test_mode = true
	h._teardown_scene(combat)
	h._exit_test()
