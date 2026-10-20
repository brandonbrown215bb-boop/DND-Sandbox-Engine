## Derive spell permissions from the exact class/book/feature sources already
## owned by a Character. The result is transient cast-selection data.
class_name SpellPermissionRules
extends RefCounted

static func item_definition_error(item: Dictionary) -> String:
	var policies: Variant = item.get("spell_permissions", [])
	if not policies is Array or policies.is_empty() or policies.size() > 8: return "Item spell permissions must be a bounded nonempty array"
	for policy in policies:
		if not policy is Dictionary or str(policy.get("ability", "")) not in AbilityScores.ABILITIES: return "Item spell permission needs an ability"
		var spells: Variant = policy.get("spells")
		if not spells is Array or spells.is_empty() or spells.size() > 100: return "Item permission needs spell IDs"
		var seen := {}
		for id in spells:
			if not id is String or id.is_empty() or seen.has(id): return "Invalid item permission spell ID"
			seen[id] = true
		if not ResourcePoolRules._integer(policy.get("charges", 0), 0, int(item.get("maximum_charges", 0))): return "Invalid item permission charge cost"
		if policy.has("slot_payment_allowed") and not policy.slot_payment_allowed is bool: return "Invalid item slot permission"
		if not ResourcePoolRules._integer(policy.get("maximum_spell_level", 9), 0, 9): return "Invalid item spell level limit"
		for field in ["allowed_components", "spell_lists"]:
			if not policy.has(field): continue
			if not policy[field] is Array: return "Invalid item spell restriction"
			for value in policy[field]:
				if not value is String or (field == "allowed_components" and value not in ["V", "S", "M"]): return "Invalid item spell restriction value"
	return ""

static func for_spell(character: Character, spell: Dictionary) -> Array[Dictionary]:
	var permissions: Array[Dictionary] = []
	if character == null or spell.is_empty():
		return permissions
	var spell_id := str(spell.get("id", ""))
	var spell_level := int(spell.get("level", -1))
	if spell_id.is_empty() or spell_level < 0:
		return permissions
	var ability := character.get_spellcasting_ability()
	var class_effect := character.get_feature_effect("spellcasting")
	var class_feature_id := character.get_spellcasting_feature_id()
	if not class_effect.is_empty() and not bool(class_effect.get("separate_repertoire", false)):
		var list_match := _on_lists(spell, class_effect.get("spell_lists", []))
		var class_owned: bool = not class_feature_id.is_empty() and character.feature_choices.get(class_feature_id, []).has(spell_id)
		if character.class_id == "wizard" and spell_level > 0:
			class_owned = spell_id in character.wizard_spellbook and spell_id in character.feature_choices.get(class_feature_id, [])
		if class_owned and list_match and spell_level <= int(class_effect.get("maximum_spell_level", 9)) and _components_allowed(spell, class_effect) and (spell_level == 0 or spell_level <= character.get_max_spell_slot_level()):
			permissions.append(_permission(class_feature_id, "class", ability, spell, class_effect))
	# A book is an independent source: a recorded spell is not usable merely
	# because a spell with the same ID is known through another permission.
	if character.class_id == "wizard" and not class_effect.is_empty() and spell_level > 0 and spell_id in character.wizard_spellbook and spell_id in character.feature_choices.get(class_feature_id, []) and spell_level <= mini(character.get_max_spell_slot_level(), int(class_effect.get("maximum_spell_level", 9))) and _components_allowed(spell, class_effect) and _on_lists(spell, class_effect.get("spell_lists", [])):
		permissions.append(_permission("wizard_spellbook", "book", ability, spell, class_effect))
	if character.class_id == "wizard" and character.has_feature("wizard_ritual_adept") and spell_level > 0 and spell_id in character.wizard_spellbook and bool(spell.get("ritual", false)):
		permissions.append(_permission("wizard_ritual_adept", "ritual", ability, spell, {"ritual_only":true,"maximum_spell_level":character.get_max_spell_slot_level()}))
	for feature in character.features:
		var feature_id := str(feature.get("id", ""))
		for effect in character._feature_effects(feature):
			if effect.get("type", "") == "spell_list_expansion" and spell_id in character.feature_choices.get(class_feature_id, []) and (spell_level == 0 or spell_level <= character.get_max_spell_slot_level()) and spell_level <= int(effect.get("maximum_spell_level", 9)) and _components_allowed(spell, effect):
				var is_cantrip_only := bool(effect.get("cantrips_only", false))
				var level_1_plus_only := bool(effect.get("level_1_plus_only", false))
				if (not is_cantrip_only or spell_level == 0) and (not level_1_plus_only or spell_level > 0) and _on_lists(spell, effect.get("spell_lists", [])):
					var expansion_ability := str(effect.get("ability", ability)).to_upper()
					if expansion_ability not in AbilityScores.ABILITIES:
						expansion_ability = ability
					permissions.append(_permission(feature_id, "feature", expansion_ability, spell, effect))
			if effect.get("type", "") != "always_prepared_spells" or spell_id not in effect.get("spells", []):
				continue
			if spell_level > int(effect.get("maximum_spell_level", 9)) or not _components_allowed(spell, effect):
				continue
			if effect.has("spell_lists") and not _on_lists(spell, effect.get("spell_lists", [])):
				continue
			var feature_ability := str(effect.get("ability", ability)).to_upper()
			if feature_ability not in AbilityScores.ABILITIES:
				feature_ability = ability
			permissions.append(_permission(feature_id, "feature", feature_ability, spell, effect))
	# Learned innate spells and feature-granted free casts retain the feature as
	# their permission owner. Their payment source is chosen separately below.
	for feature in character.features:
		var feature_id := str(feature.get("id", ""))
		for effect in character._feature_effects(feature):
			if effect.get("type", "") != "spell_free_cast" or spell_id not in effect.get("spells", []):
				continue
			if spell_level > int(effect.get("maximum_spell_level", 9)) or not _components_allowed(spell, effect):
				continue
			if effect.has("spell_lists") and not _on_lists(spell, effect.get("spell_lists", [])):
				continue
			var feature_ability := str(effect.get("ability", ability)).to_upper()
			if feature_ability not in AbilityScores.ABILITIES:
				feature_ability = ability
			permissions.append(_permission(feature_id, "innate", feature_ability, spell, effect))
	for effect in ClassProgression.selected_feature_effects(character):
		if effect.get("type", "") != "spell_free_cast" or spell_id not in effect.get("spells", []):
			continue
		if spell_level > int(effect.get("maximum_spell_level", 9)) or not _components_allowed(spell, effect):
			continue
		if effect.has("spell_lists") and not _on_lists(spell, effect.get("spell_lists", [])):
			continue
		var invocation_id := str(effect.get("invocation_selection", "warlock_invocation"))
		var invocation_ability := str(effect.get("ability", ability)).to_upper()
		if invocation_ability not in AbilityScores.ABILITIES:
			invocation_ability = ability
		permissions.append(_permission(invocation_id, "innate", invocation_ability, spell, effect))
	if character.class_id == "warlock" and WarlockRules.arcanum_cast_level(character, spell_id) > 0:
		permissions.append(_permission("warlock_mystic_arcanum", "innate", ability, spell, {"maximum_spell_level": 9, "spell_lists": ["warlock"]}))
	var special_free_cast := character.free_spell_cast_feature(spell_id)
	var special_source_id := str(special_free_cast.get("feature_id", ""))
	if special_source_id in ["wizard_spell_mastery", "wizard_signature_spells"]:
		permissions.append(_permission(special_source_id, "feature", ability, spell, {"maximum_spell_level": spell_level, "spell_lists": ["wizard"], "free_payment_allowed":true}))
	permissions.append_array(SpellRepertoireRules.permissions(character, spell))
	for source in SpellSlotRules.casting_sources(character):
		if spell_id not in source.get("ritual_spells", []) or not bool(spell.get("ritual", false)): continue
		if spell_level > int(source.get("maximum_spell_level", 9)) or not _components_allowed(spell, source): continue
		if source.has("spell_lists") and not _on_lists(spell, source.spell_lists): continue
		var ritual_ability := str(source.get("ability", ability)).to_upper()
		if ritual_ability not in AbilityScores.ABILITIES: continue
		var ritual_permission := _permission(str(source.feature_id), "ritual", ritual_ability, spell, source)
		ritual_permission["class_id"] = str(source.class_id)
		permissions.append(ritual_permission)
	character.inventory.copies.sync(character.inventory)
	for copy_id in character.inventory.copies.equipped.values():
		var copy: Dictionary = character.inventory.copies.records.get(copy_id, {})
		var item := DataLoader.get_item(str(copy.get("definition_id", "")))
		if bool(item.get("requires_attunement", false)) and copy.get("state", {}).get("attuned_to", "") != character.character_id:
			continue
		var policies: Array = item.get("spell_permissions", [])
		for index in policies.size():
			var policy: Dictionary = policies[index]
			if spell_id not in policy.get("spells", []) or spell_level > int(policy.get("maximum_spell_level", 9)) or not _components_allowed(spell, policy): continue
			if policy.has("spell_lists") and not _on_lists(spell, policy.spell_lists): continue
			var item_ability := str(policy.get("ability", "")).to_upper()
			if item_ability not in AbilityScores.ABILITIES: continue
			var permission := _permission(str(copy_id), "item", item_ability, spell, policy)
			permission["id"] = "item:" + JSON.stringify([copy_id, index])
			permission["charge_cost"] = int(policy.get("charges", 0))
			permission["label"] = "%s · %s" % [item.get("name", "Item"), str(copy_id).get_slice(":", 1)]
			permissions.append(permission)
	for permission in permissions:
		if permission.has("label"): continue
		permission["label"] = str(permission.kind).capitalize()
		for feature in character.features:
			if feature.get("id", "") == permission.source_id: permission.label = str(feature.get("name", permission.label))
	return _unique_permissions(permissions)


static func _permission(source_id: String, kind: String, ability: String, spell: Dictionary, policy: Dictionary) -> Dictionary:
	return {
		"id": "%s:%s" % [kind, source_id],
		"source_id": source_id,
		"kind": kind,
		"ability": ability,
		"spell_id": str(spell.get("id", "")),
		"maximum_level": int(policy.get("maximum_spell_level", 9)),
		"spell_lists": policy.get("spell_lists", []).duplicate(),
		"allowed_components": policy.get("allowed_components", []).duplicate(),
		"slot_payment_allowed": not bool(policy.get("ritual_only", false)) and bool(policy.get("slot_payment_allowed", kind in ["class", "book", "feature"])),
		"free_payment_allowed": bool(policy.get("free_payment_allowed", kind == "innate")),
		"ritual_allowed": bool(policy.get("ritual_allowed", kind in ["class", "book", "ritual"])),
		"ritual_only": bool(policy.get("ritual_only", kind == "ritual")),
		"ritual_time_seconds": int(policy.get("ritual_time_seconds", 600)),
		"point_payment": policy.get("point_payment", {}).duplicate(true) if policy.get("point_payment", {}) is Dictionary else {},
	}


static func _matches_any(left: Array, right: Array) -> bool:
	for value in left:
		if value in right:
			return true
	return false

static func _on_lists(spell: Dictionary, lists: Array) -> bool:
	if _matches_any(lists, spell.get("classes", [])): return true
	for entry in DataLoader.get_spell_list_options(lists):
		if entry.get("id", "") == spell.get("id", ""): return true
	return false


static func _components_allowed(spell: Dictionary, policy: Dictionary) -> bool:
	if not policy.has("allowed_components"): return true
	var allowed: Variant = policy["allowed_components"]
	if not allowed is Array: return false
	for component in spell.get("components", []):
		if component not in allowed:
			return false
	return true


static func _unique_permissions(permissions: Array[Dictionary]) -> Array[Dictionary]:
	var unique: Array[Dictionary] = []
	var seen: Dictionary = {}
	for permission in permissions:
		var key := str(permission.get("id", ""))
		if key.is_empty() or seen.has(key):
			continue
		seen[key] = true
		unique.append(permission)
	return unique


static func selected_ability(spell: Dictionary, fallback: String) -> String:
	var permission_id := str(spell.get("_source_permission_id", ""))
	for permission in spell.get("_source_permissions", []):
		if str(permission.get("id", "")) == permission_id:
			var ability := str(permission.get("ability", fallback)).to_upper()
			if ability in AbilityScores.ABILITIES:
				return ability
	var captured := str(spell.get("_spellcasting_ability", fallback)).to_upper()
	return captured if captured in AbilityScores.ABILITIES else fallback

static func save_dc(caster: Character, spell: Dictionary) -> int:
	var ability := selected_ability(spell, caster.get_spellcasting_ability())
	var dc := caster.get_spell_save_dc() + caster.ability_scores.get_ability_modifier(ability) - caster.ability_scores.get_ability_modifier(caster.get_spellcasting_ability())
	dc = AttackProfileRules.spell_dc(caster, spell, dc)
	return int(spell.get("_save_dc_override", dc))


## Resolve caller selections only against current production definitions. No fallback.
static func selected_permission(character: Character, spell: Dictionary) -> Dictionary:
	var id := str(spell.get("_source_permission_id", ""))
	if id.is_empty(): return {}
	var definition := DataLoader.get_spell(str(spell.get("id", "")))
	for permission in for_spell(character, definition):
		if permission.id == id: return permission
	return {}

## Reactions choose the same explicit permission/payment as normal casts.
static func payment_choices(character: Character, spell_id: String) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	var spell_level := int(DataLoader.get_spell(spell_id).get("level", 0))
	for permission in character.get_spell_permissions(spell_id):
		var base := DataLoader.get_spell(spell_id).duplicate(true)
		base.merge({"_source_permission_id":permission.id,"_source_permissions":[permission],"_spellcasting_ability":permission.ability}, true)
		var payments: Array[Dictionary] = []
		if permission.slot_payment_allowed:
			for slot in SpellSlotRules.pool_rows(character):
				if int(slot.remaining) >= 0 and int(slot.level) >= int(spell_level) and int(slot.remaining) > 0:
					payments.append({"_spell_payment_kind":"slot","_selected_spell_slot_level":int(slot.level),"_spell_slot_pool_id":str(slot.pool_id)})
		if bool(permission.get("free_payment_allowed", false)):
			payments.append({"_spell_payment_kind":"free_cast","_spell_payment_source_id":permission.source_id})
		if not permission.point_payment.is_empty(): payments.append({"_spell_payment_kind":"points"})
		if int(permission.get("charge_cost", 0)) > 0: payments.append({"_spell_payment_kind":"item_charges","_spell_payment_source_id":permission.source_id})
		for payment in payments:
			var row := base.duplicate(true)
			row.merge(payment, true)
			if selection_valid(character, row): choices.append(row)
	return choices

static func reaction_key(character: Character, spell_id: String) -> String:
	return "spell_payment:%s:%s" % [SpellEffects.caster_id(character), spell_id]

static func spend_reaction(character: Character, spell_id: String, decisions: Dictionary) -> Dictionary:
	if not character.reaction_available or CombatAction.is_incapacitated(character): return {}
	var supplied: Variant = decisions.get(reaction_key(character, spell_id), {})
	if not supplied is Dictionary: return {}
	var selection: Dictionary = supplied
	# Old direct resolver callers can omit metadata only when there is one exact choice.
	if selection.is_empty():
		var choices := payment_choices(character, spell_id)
		if choices.is_empty(): return {}
		# Legacy callers may use the lowest slot of one unambiguous permission.
		var first: Dictionary = choices[0]
		for choice in choices:
			if choice._source_permission_id != first._source_permission_id or choice._spell_payment_kind != first._spell_payment_kind: return {}
		choices.sort_custom(func(a, b): return int(a.get("_selected_spell_slot_level", 0)) < int(b.get("_selected_spell_slot_level", 0)))
		selection = choices[0]
	if selection.get("id", "") != spell_id or not selection_valid(character, selection): return {}
	var permission := selected_permission(character, selection)
	var canonical := DataLoader.get_spell(spell_id).duplicate(true)
	canonical.merge({"_source_permission_id":permission.id,"_source_permissions":[permission],"_spellcasting_ability":permission.ability}, true)
	for field in ["_spell_payment_kind", "_spell_payment_source_id", "_selected_spell_slot_level", "_spell_slot_pool_id"]:
		if selection.has(field): canonical[field] = selection[field]
	selection = canonical
	var result := {"success":true,"spell":selection,"slot_level":0}
	match str(selection.get("_spell_payment_kind", "")):
		"slot":
			var paid := CombatAction.spend_spell_slot(character, selection, int(selection.get("_selected_spell_slot_level", 0)))
			if not paid.get("success", false): return {}
			result.merge(paid, true)
			if not bool(paid.get("slot_recalled", false)): result["ward_events"] = WardRules.on_slot_spell_cast(character, selection, int(paid.slot_level))
		"free_cast":
			if permission.source_id == "warlock_mystic_arcanum":
				if not WarlockRules.spend_arcanum_cast(character, spell_id): return {}
			elif not character.spend_free_spell_cast(spell_id, str(permission.source_id)): return {}
		"points":
			if not spend_points(character, permission, int(selection.get("level", 0))): return {}
		"item_charges":
			# Review R1: the exact-copy spend boundary settles S-060 last-charge aftermath.
			if not character.inventory.spend_instance_charges(str(permission.source_id), int(permission.charge_cost)): return {}
		_: return {}
	result["payment"] = CastInterruptionRules.payment_receipt(character, selection, result if str(selection.get("_spell_payment_kind", "")) == "slot" else {}, permission)
	result["reaction_spent"] = true
	character.reaction_available = false
	return result


static func selection_valid(character: Character, spell: Dictionary) -> bool:
	var permission := selected_permission(character, spell)
	if permission.is_empty(): return false
	if bool(permission.get("ritual_only", false)): return false
	if spell.has("_source_permissions"):
		if not spell._source_permissions is Array: return false
		var captured: Dictionary = {}
		for candidate in spell._source_permissions:
			if not candidate is Dictionary: return false
			if candidate.get("id", "") == permission.id: captured = candidate
		if captured != permission: return false
	if spell.has("_spellcasting_ability") and spell._spellcasting_ability != permission.ability: return false
	var definition := DataLoader.get_spell(str(spell.get("id", "")))
	var level := int(definition.get("level", 0))
	var source := str(spell.get("_spell_payment_source_id", ""))
	match str(spell.get("_spell_payment_kind", "")):
		"": return level == 0 and int(permission.get("charge_cost", 0)) == 0
		"slot":
			if level == 0 or not permission.slot_payment_allowed or not source.is_empty(): return false
			if not ResourcePoolRules._integer(spell.get("_selected_spell_slot_level", 0), 0, 9): return false
			var selected_level := int(spell.get("_selected_spell_slot_level", 0))
			var pool_id := str(spell.get("_spell_slot_pool_id", SpellSlotRules.default_pool_id(character)))
			if pool_id not in ["ordinary", "pact"]: return false
			for slot in SpellSlotRules.pool_rows(character):
				if str(slot.pool_id) == pool_id and int(slot.level) >= level and (selected_level == 0 or int(slot.level) == selected_level) and int(slot.remaining) > 0: return true
			return false
		"free_cast":
			if level == 0 or source.is_empty() or source != permission.source_id or not bool(permission.get("free_payment_allowed", false)): return false
			if source == "warlock_mystic_arcanum": return WarlockRules.arcanum_cast_level(character, str(definition.id)) > 0
			return not character.free_spell_cast_feature(str(definition.id), source).is_empty()
		"points": return level > 0 and source.is_empty() and can_pay_points(character, permission, level)
		"item_charges":
			if permission.kind != "item" or source != permission.source_id or int(permission.get("charge_cost", 0)) <= 0: return false
			return int(character.inventory.get_instance(source).get("state", {}).get("charges", 0)) >= int(permission.charge_cost)
	return false


static func spell_ids(character: Character) -> Array[String]:
	var ids: Array[String] = character.known_spells.duplicate()
	for source in SpellRepertoireRules.sources(character):
		for id in character.feature_choices.get(source.id, []):
			if id not in ids: ids.append(str(id))
	for feature in character.features:
		for effect in character._feature_effects(feature):
			if effect.get("type", "") in ["always_prepared_spells", "spell_free_cast"]:
				for id in effect.get("spells", []):
					if id not in ids: ids.append(str(id))
	character.inventory.copies.sync(character.inventory)
	for copy_id in character.inventory.copies.equipped.values():
		var copy: Dictionary = character.inventory.copies.records.get(copy_id, {})
		for policy in DataLoader.get_item(str(copy.get("definition_id", ""))).get("spell_permissions", []):
			for id in policy.get("spells", []):
				if id not in ids: ids.append(str(id))
	return ids


## Ritual selection has its own route; book-only entries never become normal casts.
static func ritual_permissions(character: Character, spell: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if character == null or not bool(spell.get("ritual", false)) or int(spell.get("level", 0)) < 1: return out
	for permission in for_spell(character, spell):
		if bool(permission.get("ritual_allowed", false)) and int(spell.level) <= int(permission.maximum_level):
			out.append(permission)
	return out


static func ritual_choices(character: Character) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if character == null: return out
	var ids := spell_ids(character)
	for id in character.wizard_spellbook:
		if id not in ids: ids.append(str(id))
	for source in SpellSlotRules.casting_sources(character):
		for id in source.get("ritual_spells", []):
			if id not in ids: ids.append(str(id))
	for effect in ClassProgression.selected_feature_effects(character):
		for id in effect.get("spells", []):
			if id not in ids: ids.append(str(id))
	for id in ids:
		for permission in ritual_permissions(character, DataLoader.get_spell(id)):
			out.append({"spell_id":id,"permission":permission})
	return out


static func point_payment_cost(permission: Dictionary, spell_level: int) -> int:
	var policy: Variant = permission.get("point_payment", {})
	if not policy is Dictionary or policy.is_empty():
		return 0
	var by_level: Variant = policy.get("cost_by_level", {})
	var cost := int(by_level.get(str(spell_level), policy.get("cost", 0))) if by_level is Dictionary else int(policy.get("cost", 0))
	return cost if cost > 0 else 0


static func can_pay_points(character: Character, permission: Dictionary, spell_level: int) -> bool:
	if character == null:
		return false
	var cost := point_payment_cost(permission, spell_level)
	if cost <= 0:
		return false
	var resource_id := str(permission.get("point_payment", {}).get("resource_id", ""))
	if resource_id == "sorcery_points":
		return character.get_sorcery_points() >= cost
	return int(character.feature_uses.get(resource_id, 0)) >= cost


static func spend_points(character: Character, permission: Dictionary, spell_level: int) -> bool:
	if not can_pay_points(character, permission, spell_level):
		return false
	var resource_id := str(permission.get("point_payment", {}).get("resource_id", ""))
	var cost := point_payment_cost(permission, spell_level)
	if resource_id == "sorcery_points":
		return character.spend_sorcery_points(cost)
	character.feature_uses[resource_id] = int(character.feature_uses.get(resource_id, 0)) - cost
	return true
