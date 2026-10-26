class_name Batch085Checks
extends RefCounted
## Batch 085 (S-126/S-140): cast-local range, components, school and timing on
## one permissioned invocation. Catalog records and unrelated casts stay as they are.

const FILE := "res://data/fixtures/batch_085/classes/cast_transforms.json"

static func load_fixtures() -> void:
	if DataLoader.get_character_class("fixture:b085_class").is_empty():
		DataLoader._load_json_file(FILE, "class")

static func features() -> Array:
	return DataLoader.get_character_class("fixture:b085_class").get("features_by_level", {}).get("1", []).duplicate(true)

static func grant(c: Character) -> void:
	load_fixtures()
	for f in features(): c.features.append(f)

static func invocation(id: String, source_id: String = "wizard") -> Dictionary:
	var spell := DataLoader.get_spell(id).duplicate(true)
	spell["_source_permission_id"] = "perm:%s" % source_id
	spell["_source_permissions"] = [{"id": "perm:%s" % source_id, "source_id": source_id}]
	return spell

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(not DataLoader.get_spell("magic_missile").has("_magic_item_activation"), "085 a wand activation earlier in the run left the catalog Magic Missile record unmarked (copy, not catalog)")
	check.call(features().size() == 5, "085 S-140 the loader keeps all five authored cast-transform profiles (got %d)" % features().size())
	var c := Batch031Checks._character("b085_caster", 30)
	grant(c)
	var catalog_mm := DataLoader.get_spell("magic_missile").duplicate(true)
	var catalog_rf := DataLoader.get_spell("ray_of_frost").duplicate(true)
	var catalog_fb := DataLoader.get_spell("fire_bolt").duplicate(true)
	# Qualifying cast: compatible changes from two sources apply together.
	var mm := AttackProfileRules.apply_cast(c, invocation("magic_missile"))
	var p: Dictionary = mm.get("_cast_profile", {})
	check.call(int(mm.range) == int(catalog_mm.range) + 12 and mm.components == ["S"] and mm.casting_time == "bonus_action" and mm.school == "abjuration", "085 S-140 qualifying Magic Missile gets +60 ft range, loses V, becomes a Bonus Action and changes school (range=%s comps=%s)" % [mm.get("range"), mm.get("components")])
	check.call(p.get("sources", []) == ["b085:reach", "b085:swift"] and p.get("ignored", []) == [{"source": "b085:rival", "field": "school"}], "085 S-140 first replacement of a field wins; the conflicting later school is recorded as ignored")
	check.call(p.get("inherited", {}).get("school", "") == "evocation" and p.get("inherited", {}).get("casting_time", "") == "action", "085 S-140 the invocation records its inherited fields")
	# Scope uses inherited fields: the abjuration-only DC source does not qualify.
	check.call(SpellPermissionRules.save_dc(c, mm) == SpellPermissionRules.save_dc(c, invocation("magic_missile")), "085 S-140 a school change does not make an abjuration-scoped source qualify")
	# Once only.
	var again := AttackProfileRules.apply_cast(c, mm)
	check.call(int(again.range) == int(mm.range) and again.components == ["S"] and again._cast_profile.sources == p.sources, "085 S-140 re-applying the profile to the same invocation changes nothing (once only)")
	# Unrelated casts side by side.
	var fb := AttackProfileRules.apply_cast(c, invocation("fire_bolt"))
	check.call(not fb.has("_cast_profile") and fb.range == catalog_fb.range and fb.components == catalog_fb.components and fb.casting_time == catalog_fb.casting_time and fb.school == catalog_fb.school, "085 S-140 unrelated Fire Bolt is inherited unchanged in the same caster")
	var rf := AttackProfileRules.apply_cast(c, invocation("ray_of_frost"))
	check.call(int(rf.range) == 2 and rf.components == catalog_rf.components, "085 S-140 a range replacement shrinks only Ray of Frost to 10 ft")
	# Unpermissioned or item activations are not invocations this host transforms.
	var raw := AttackProfileRules.apply_cast(c, DataLoader.get_spell("magic_missile"))
	var item := invocation("magic_missile"); item["_magic_item_activation"] = true
	check.call(not raw.has("_cast_profile") and not AttackProfileRules.apply_cast(c, item).has("_cast_profile"), "085 S-140 raw records and item activations are not transformed")
	# permission_sources scope: same spell, other permission is unrelated.
	var scoped := {"id": "fixture:b085_perm", "type": "attack_profile", "source_instance_id": "b085:perm", "scope": {"kind": "spell", "ids": ["fire_bolt"], "permission_sources": ["fixture_feat"]}, "add": {"range_feet": 30}}
	check.call(AttackProfileRules.validate_rule(scoped).is_empty(), "085 S-140 permission_sources scope validates")
	c.features.append(scoped)
	check.call(int(AttackProfileRules.apply_cast(c, invocation("fire_bolt", "fixture_feat")).range) == int(catalog_fb.range) + 6 and not AttackProfileRules.apply_cast(c, invocation("fire_bolt", "wizard")).has("_cast_profile"), "085 S-140 a permission-scoped source changes only the cast made through that permission")
	# No catalog mutation.
	check.call(DataLoader.get_spell("magic_missile") == catalog_mm and DataLoader.get_spell("ray_of_frost") == catalog_rf and DataLoader.get_spell("fire_bolt") == catalog_fb, "085 S-140 catalog spell records are unchanged after transformations")
	# Not-applicable fields: touch/self range and reaction timing are skipped.
	var touch := {"id": "fixture:b085_touch", "type": "attack_profile", "source_instance_id": "b085:touch", "scope": {"kind": "spell", "ids": ["shield", "mage_armor"]}, "add": {"range_feet": 30}, "replace": {"casting_time": "action"}}
	c.features.append(touch)
	var shield := AttackProfileRules.apply_cast(c, invocation("shield"))
	var armor := AttackProfileRules.apply_cast(c, invocation("mage_armor"))
	check.call(shield.casting_time == "reaction" and not shield.has("_cast_profile") and int(armor.range) == int(DataLoader.get_spell("mage_armor").range) and armor.casting_time == "action", "085 S-140 reaction timing and Touch range are never transformed")
	# Malformed rules refuse at load.
	for defect in ["range_zero", "range_odd", "range_str", "school", "timing", "remove_m", "remove_key", "remove_weapon", "perm_weapon", "weapon_range", "scope_typo", "unknown_op", "replace_unknown"]:
		var bad := {"id": "x", "type": "attack_profile", "source_instance_id": "b085:bad", "scope": {"kind": "spell", "ids": ["magic_missile"]}, "add": {"range_feet": 30}}
		match defect:
			"range_zero": bad["replace"] = {"range_feet": 0}
			"range_odd": bad.add.range_feet = 7
			"range_str": bad.add.range_feet = "far"
			"school": bad["replace"] = {"school": "chronurgy"}
			"timing": bad["replace"] = {"casting_time": "reaction"}
			"remove_m": bad["remove"] = {"components": ["M"]}
			"remove_key": bad["remove"] = {"material": true}
			"remove_weapon": bad.scope = {"kind": "weapon", "ids": ["longsword"]}; bad.erase("add"); bad["remove"] = {"components": ["V"]}
			"perm_weapon": bad.scope = {"kind": "weapon", "permission_sources": ["x"]}; bad.add = {"damage_bonus": 1}
			"weapon_range": bad.scope = {"kind": "weapon", "ids": ["longsword"]}
			"scope_typo": bad.scope = {"kind": "spell", "school": ["abjuration"]}
			"unknown_op": bad["multiply"] = {"range_feet": 2}
			"replace_unknown": bad["replace"] = {"duration": "1 hour"}
		check.call(not AttackProfileRules.validate_rule(bad).is_empty(), "085 S-140 malformed cast profile %s refuses" % defect)
	# Profiles are source-owned features; the invocation copy is not saved state.
	var saved := c.to_dict()
	check.call(not JSON.stringify(saved).contains("_cast_profile"), "085 S-140 a character save carries no cast-transformation state")
