## Single shared ordered execution runtime for stepped spells and creature event rules.
## Executes ordered operations with gate evaluation, per-target resolution, and unified result semantics.
class_name SharedStepExecutor
extends RefCounted

const STEP_TYPES := ["attack", "save", "damage", "effect", "replace_hp"]
const STEP_GATES := ["always", "hit", "miss", "failed_save", "successful_save"]
const ABILITIES := ["STR", "DEX", "CON", "INT", "WIS", "CHA"]

const SPELL_STEP_TYPES := ["attack", "save", "damage", "effect"]
const SPELL_STEP_FIELDS := [
	"id", "type", "gate", "gate_step", "target", "shape", "radius", "size",
	"attack_type", "damage", "damage_type", "scaling", "upcast",
	"save", "half_on_save", "effects"
]

const EVENT_STEP_TYPES := ["save", "replace_hp"]
const EVENT_STEP_FIELDS := [
	"id", "type", "gate", "gate_step", "target",
	"save", "save_ability", "dc_base", "dc_add_damage",
	"replacement_hp"
]

const ZERO_HP_RULE_FIELDS := [
	"id", "name", "type", "trigger", "description",
	"bypass_damage_types", "bypass_critical", "steps",
	"save_ability", "save", "dc_base", "dc_add_damage", "replacement_hp"
]


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	if value is bool: return false
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum


static func _formula(value: Variant) -> bool:
	if value is bool: return false
	if value is int or value is float: return _integer(value, 0, 999)
	if not value is String: return false
	var expression := RegEx.new()
	expression.compile("^([0-9]{1,3}|[1-9][0-9]?d(4|6|8|10|12|20))([+][0-9]{1,3})?$")
	return expression.search(str(value).replace(" ", "")) != null


static func validate_spatial_context_for_steps(steps: Array, decisions: Dictionary) -> String:
	for step in steps:
		if not step is Dictionary:
			continue
		if str(step.get("target", "target")) == "area":
			if not decisions.has("area_targets"):
				if not decisions.has("grid") or decisions.get("grid") == null:
					return "Area targeting requires encounter grid and participants."
				var players = decisions.get("players", [])
				var monsters = decisions.get("monsters", [])
				var players_empty: bool = not (players is Array and not players.is_empty())
				var monsters_empty: bool = not (monsters is Array and not monsters.is_empty())
				if players_empty and monsters_empty:
					return "Area targeting requires encounter grid and participants."
	return ""


static func validate_step(step: Variant, step_index: int, step_ids: Dictionary, all_steps: Array = [], context: String = "") -> String:
	if not step is Dictionary:
		return "Shared step must be an object."
	var allowed_fields: Array = SPELL_STEP_FIELDS if context == "spell" else (EVENT_STEP_FIELDS if (context == "zero_hp_replacement" or context == "event") else (SPELL_STEP_FIELDS + ["save_ability", "dc_base", "dc_add_damage", "replacement_hp"]))
	var allowed_types: Array = SPELL_STEP_TYPES if context == "spell" else (EVENT_STEP_TYPES if (context == "zero_hp_replacement" or context == "event") else STEP_TYPES)
	for key in step:
		if not key is String:
			return "Shared step keys must be strings."
		if str(key) not in allowed_fields:
			return "Unsupported shared step field '%s'." % str(key)
	if not step.has("id") or not step["id"] is String or str(step["id"]).is_empty():
		return "Shared steps require a string id."
	var step_id := str(step["id"])
	if step_ids.has(step_id):
		return "Duplicate step id '%s'." % step_id
	if not step.has("type") or not step["type"] is String:
		return "Shared step type must be a string."
	var step_type := str(step["type"])
	if step_type not in allowed_types:
		return "Unsupported shared step type '%s'." % step_type
	var gate := "always"
	if step.has("gate"):
		if not step["gate"] is String:
			return "Shared step gate must be a string."
		gate = str(step["gate"])
		if gate not in STEP_GATES:
			return "Unsupported shared step gate '%s'." % gate
	if gate != "always" and step_index == 0:
		return "First step cannot specify gate without prerequisite."
	if step.has("gate_step") or (gate != "always" and step_index > 0):
		var ref = step.get("gate_step", step_index - 1)
		var ref_idx := -1
		if ref is int and not ref is bool:
			ref_idx = ref
		elif ref is String and step_ids.has(ref):
			ref_idx = int(step_ids[ref])
		else:
			return "Step '%s' references nonexistent or forward step '%s'." % [step_id, str(ref)]
		if ref_idx < 0 or ref_idx >= step_index:
			return "Step '%s' references nonexistent or forward step '%s'." % [step_id, str(ref)]
		if not all_steps.is_empty() and ref_idx < all_steps.size():
			var ref_step: Dictionary = all_steps[ref_idx]
			var ref_type: String = str(ref_step.get("type", ""))
			if gate in ["hit", "miss"] and ref_type != "attack":
				return "Gate '%s' on step '%s' requires an attack step prerequisite." % [gate, step_id]
			if gate in ["failed_save", "successful_save"] and ref_type != "save":
				return "Gate '%s' on step '%s' requires a save step prerequisite." % [gate, step_id]
			var ref_target: String = str(ref_step.get("target", "target"))
			var cur_target: String = str(step.get("target", "target"))
			if ref_target == "self" and cur_target != "self":
				return "Step '%s' with target '%s' cannot gate on self step '%s'." % [step_id, cur_target, str(ref_step.get("id", ref_idx))]
			if ref_target == "area" and cur_target == "self":
				return "Step '%s' with target 'self' cannot gate on area step '%s'." % [step_id, str(ref_step.get("id", ref_idx))]
	var step_target := "target"
	if step.has("target"):
		if not step["target"] is String:
			return "Shared step target must be a string."
		step_target = str(step["target"])
		if context in ["zero_hp_replacement", "event"]:
			if step_target != "target":
				return "Unsupported zero_hp_replacement step target '%s'; expected 'target'." % step_target
		else:
			if step_target not in ["target", "self", "area"]:
				return "Unsupported shared step target '%s'." % step_target
	if step_target == "area":
		if not step.get("shape") is String or step["shape"] not in ["sphere", "cone", "cube"]:
			return "Shared step area requires a supported shape."
		var geom_key := "radius" if step.get("shape") == "sphere" else "size"
		if not _integer(step.get(geom_key), 1, 100):
			return "Shared step area requires a positive integer radius/size."

	if step.has("scaling"):
		if not step["scaling"] is Dictionary:
			return "Shared %s step scaling must be an object." % step_type
		if not step.has("damage"):
			return "Shared %s step scaling requires damage payload." % step_type
		for threshold in step["scaling"]:
			if not str(threshold).is_valid_int() or int(threshold) < 1 or int(threshold) > 20 or not _formula(step["scaling"][threshold]):
				return "Invalid shared damage scaling."

	if step.has("upcast"):
		if not step["upcast"] is Dictionary:
			return "Shared %s step upcast must be an object." % step_type
		if not step.has("damage"):
			return "Shared %s step upcast requires damage payload." % step_type
		for key in step["upcast"]:
			if key == "damage_per_level":
				if not step["upcast"][key] is String or not SharedSpell._dice_formula(step["upcast"][key]):
					return "Shared upcast dice must be a plain dice expression."
			elif key in ["starting_level", "levels_per_increment"]:
				if not _integer(step["upcast"][key], 0, 100):
					return "Invalid shared upcast amount."
			else:
				return "Unsupported shared step upcast operation '%s'." % key

	if step.has("effects") and step_type != "effect":
		if not step["effects"] is Array:
			return "Shared step effects must be an array."
		for eff in step["effects"]:
			var err := SharedSpell._validate_single_effect(eff)
			if not err.is_empty(): return err

	match step_type:
		"attack":
			if not step.get("attack_type") is String or step.get("attack_type") not in ["ranged_spell", "melee_spell"]:
				return "Shared attack step requires a spell attack delivery."
			if not step.has("damage") or not _formula(step["damage"]) or not step.get("damage_type") is String or step.get("damage_type") not in DataLoader.VALID_DAMAGE_TYPES:
				return "Shared attack step requires valid damage and damage type."
		"save":
			if context == "spell":
				if not step.has("save") or not step["save"] is String or step["save"] not in ABILITIES:
					return "Shared save step requires a valid ability."
				if step.has("dc_base") or step.has("dc_add_damage") or step.has("save_ability"):
					return "Spell save step cannot declare dc_base, dc_add_damage, or save_ability."
				if step.has("half_on_save") and not step["half_on_save"] is bool:
					return "half_on_save must be a boolean."
				if step.has("damage") and (not _formula(step["damage"]) or not step.get("damage_type") is String or step.get("damage_type") not in DataLoader.VALID_DAMAGE_TYPES):
					return "Shared save step damage requires valid formula and damage type."
			else:
				var ability_val = step.get("save", step.get("save_ability", ""))
				if not ability_val is String or ability_val not in ABILITIES:
					return "Shared save step requires a valid ability."
				if step.has("dc_base") and not _integer(step["dc_base"], 0, 100):
					return "Shared save step dc_base must be an integer between 0 and 100."
				if step.has("dc_add_damage") and not step["dc_add_damage"] is bool:
					return "Shared save step dc_add_damage must be a boolean."
		"damage":
			if not step.has("damage") or not _formula(step["damage"]) or not step.get("damage_type") is String or step.get("damage_type") not in DataLoader.VALID_DAMAGE_TYPES:
				return "Shared damage step requires valid damage and damage type."
		"effect":
			if not step.has("effects") or not step["effects"] is Array or step["effects"].is_empty():
				return "Shared effect step requires a non-empty effects array."
			for eff in step["effects"]:
				var err := SharedSpell._validate_single_effect(eff)
				if not err.is_empty(): return err
		"replace_hp":
			if not step.has("replacement_hp") or not _integer(step["replacement_hp"], 1, 9999):
				return "Shared replace_hp step requires a positive integer replacement_hp."
	return ""


static func validate_steps(steps: Variant, context: String = "") -> String:
	if not steps is Array or steps.is_empty():
		return "Shared steps must be a non-empty array."
	var step_ids: Dictionary = {}
	for i in steps.size():
		var err := validate_step(steps[i], i, step_ids, steps, context)
		if not err.is_empty():
			return err
		step_ids[str(steps[i]["id"])] = i
	return ""


static func validate_zero_hp_replacement_rule(rule: Variant) -> String:
	if not rule is Dictionary:
		return "zero_hp_replacement rule must be an object."
	for key in rule:
		if not key is String:
			return "zero_hp_replacement rule keys must be strings."
		if str(key) not in ZERO_HP_RULE_FIELDS:
			return "Unsupported zero_hp_replacement field '%s'." % str(key)
	if rule.has("id") and not rule["id"] is String:
		return "zero_hp_replacement rule id must be a string."
	if rule.has("name") and not rule["name"] is String:
		return "zero_hp_replacement rule name must be a string."
	if rule.has("type"):
		if not rule["type"] is String or rule["type"] != "zero_hp_replacement":
			return "Unsupported type '%s' for zero_hp_replacement; expected 'zero_hp_replacement'." % str(rule["type"])
	if rule.has("trigger"):
		if not rule["trigger"] is String or rule["trigger"] != "zero_hp":
			return "Unsupported trigger '%s' for zero_hp_replacement; expected 'zero_hp'." % str(rule["trigger"])
	if not rule.has("type") and not rule.has("trigger"):
		return "zero_hp_replacement rule requires type 'zero_hp_replacement' and trigger 'zero_hp'."
	if rule.has("bypass_damage_types"):
		if not rule["bypass_damage_types"] is Array:
			return "bypass_damage_types must be an array of strings."
		for dt in rule["bypass_damage_types"]:
			if not dt is String or dt.to_lower() not in DataLoader.VALID_DAMAGE_TYPES:
				return "Invalid bypass damage type '%s'." % str(dt)
	if rule.has("bypass_critical") and not rule["bypass_critical"] is bool:
		return "bypass_critical must be a boolean."
	if rule.has("steps"):
		var steps_err := validate_steps(rule["steps"], "zero_hp_replacement")
		if not steps_err.is_empty():
			return steps_err
	else:
		var ability_val = rule.get("save_ability", rule.get("save", ""))
		if not ability_val is String or ability_val not in ABILITIES:
			return "zero_hp_replacement requires a valid save_ability."
		if not _integer(rule.get("dc_base", 5), 0, 100):
			return "zero_hp_replacement requires integer dc_base (0-100)."
		if rule.has("dc_add_damage") and not rule["dc_add_damage"] is bool:
			return "dc_add_damage must be a boolean."
		if not _integer(rule.get("replacement_hp", 1), 1, 9999):
			return "zero_hp_replacement requires a positive integer replacement_hp."
	return ""


static func validate_monster_special_abilities(monster: Dictionary) -> String:
	var abilities: Variant = monster.get("special_abilities", [])
	if not abilities is Array:
		return "special_abilities must be an array."
	for ability in abilities:
		if not ability is Dictionary:
			return "special_ability must be an object."
		if ability.has("type") and not ability["type"] is String:
			return "special_ability type must be a string."
		if ability.has("trigger") and not ability["trigger"] is String:
			return "special_ability trigger must be a string."
		var a_type := str(ability.get("type", ""))
		var a_trigger := str(ability.get("trigger", ""))
		if a_type == "zero_hp_replacement" or a_trigger == "zero_hp" or ability.has("steps") or a_type.begins_with("zero_hp") or a_trigger.begins_with("zero_hp"):
			var err := validate_zero_hp_replacement_rule(ability)
			if not err.is_empty():
				return err
	return ""


static func canonicalize_rule(rule: Dictionary) -> Dictionary:
	var canon := rule.duplicate(true)
	if not canon.has("steps"):
		var ability: String = str(canon.get("save", canon.get("save_ability", "CON")))
		var dc_base: int = int(canon.get("dc_base", 5))
		var dc_add_damage: bool = bool(canon.get("dc_add_damage", true))
		var replacement_hp: int = int(canon.get("replacement_hp", 1))
		canon["steps"] = [
			{
				"id": "zero_hp_save",
				"type": "save",
				"target": "target",
				"save": ability,
				"dc_base": dc_base,
				"dc_add_damage": dc_add_damage
			},
			{
				"id": "zero_hp_replacement",
				"type": "replace_hp",
				"target": "target",
				"gate": "successful_save",
				"gate_step": "zero_hp_save",
				"replacement_hp": replacement_hp
			}
		]
	return canon


static func get_zero_hp_replacement_rule(target) -> Dictionary:
	var raw_candidates: Array = []
	if target is Character:
		for feature in target.features:
			if feature is Dictionary:
				if (feature.has("type") and feature["type"] is String and feature["type"] == "zero_hp_replacement") or (feature.has("trigger") and feature["trigger"] is String and feature["trigger"] == "zero_hp"):
					raw_candidates.append(feature)
	elif target is Dictionary:
		for ability in target.get("special_abilities", []):
			if ability is Dictionary:
				if (ability.has("type") and ability["type"] is String and ability["type"] == "zero_hp_replacement") or (ability.has("trigger") and ability["trigger"] is String and ability["trigger"] == "zero_hp"):
					raw_candidates.append(ability)
		if raw_candidates.is_empty() and bool(target.get("undead_fortitude", false)):
			var zombie_data: Dictionary = DataLoader.get_monster("zombie")
			for ability in zombie_data.get("special_abilities", []):
				if ability is Dictionary and ability.get("type") is String and ability.get("type") == "zero_hp_replacement" and ability.get("trigger") is String and ability.get("trigger") == "zero_hp":
					raw_candidates.append(ability)
					break

	if raw_candidates.is_empty():
		return {}

	var valid_candidates: Array = []
	for candidate in raw_candidates:
		var err := validate_zero_hp_replacement_rule(candidate)
		if not err.is_empty():
			push_warning("[SharedStepExecutor] Malformed zero_hp_replacement rule on target: %s" % err)
			continue
		valid_candidates.append(candidate)

	if valid_candidates.size() > 1:
		push_warning("[SharedStepExecutor] Competing zero_hp_replacement rules on target (%d rules). Competing replacements refused." % valid_candidates.size())
		return {}
	elif valid_candidates.size() == 1:
		return valid_candidates[0]
	return {}


static func _same_actor(a, b) -> bool:
	if a == null or b == null:
		return false
	if a is Character and b is Character:
		return a == b or (not a.character_id.is_empty() and a.character_id == b.character_id)
	if a is Dictionary and b is Dictionary:
		if a.has("id") and b.has("id"):
			return str(a["id"]) == str(b["id"])
		return is_same(a, b)
	return false


static func _copy_target_outcomes(outcomes: Array) -> Array:
	var copy: Array = []
	for outcome in outcomes:
		if outcome is Dictionary:
			var outcome_copy: Dictionary = outcome.duplicate(false)
			if outcome_copy.has("result") and outcome_copy["result"] is Dictionary:
				outcome_copy["result"] = outcome_copy["result"].duplicate(false)
			copy.append(outcome_copy)
		else:
			copy.append(outcome)
	return copy


static func _copy_step_results(step_results: Array) -> Array:
	var copy: Array = []
	for sr in step_results:
		if sr is Dictionary:
			var sr_copy: Dictionary = sr.duplicate(false)
			if sr_copy.has("target_outcomes") and sr_copy["target_outcomes"] is Array:
				sr_copy["target_outcomes"] = _copy_target_outcomes(sr_copy["target_outcomes"])
			copy.append(sr_copy)
		else:
			copy.append(sr)
	return copy


static func execute_steps(steps: Array, adapter: Object, start_step_index: int = 0, prior_state: Dictionary = {}, start_target_index: int = 0) -> Dictionary:
	var context_name := ""
	if adapter.has_method("get_context_name"):
		context_name = str(adapter.get_context_name())
	if start_step_index == 0 and start_target_index == 0:
		var preflight_err := validate_steps(steps, context_name)
		if not preflight_err.is_empty():
			push_warning("[SharedStepExecutor] Refusing execution before state mutation: %s" % preflight_err)
			return {
				"success": false,
				"refused": true,
				"error": preflight_err,
				"message": preflight_err
			}
		if adapter.has_method("validate_spatial_context"):
			var spatial_err: String = adapter.validate_spatial_context(steps)
			if not spatial_err.is_empty():
				push_warning("[SharedStepExecutor] Refusing execution before state mutation: %s" % spatial_err)
				return {
					"success": false,
					"refused": true,
					"error": spatial_err,
					"message": spatial_err
				}

	var step_results: Array = _copy_step_results(prior_state.get("step_results", []))
	var total_damage: int = int(prior_state.get("total_damage", 0))
	var messages: Array[String] = []
	for m in prior_state.get("messages", []): messages.append(str(m))
	var first_attack_hit: bool = bool(prior_state.get("first_attack_hit", false))
	var has_attack: bool = bool(prior_state.get("has_attack", false))
	var primary_save_saved: bool = bool(prior_state.get("primary_save_saved", false))
	var has_save: bool = bool(prior_state.get("has_save", false))
	var replaced: bool = bool(prior_state.get("replaced", false))

	for i in range(start_step_index, steps.size()):
		var step: Dictionary = steps[i]
		var step_id: String = str(step.get("id", str(i)))
		var step_type: String = str(step.get("type", ""))
		var gate: String = str(step.get("gate", "always"))
		var step_target_mode: String = str(step.get("target", "target"))

		var step_targets: Array = []
		if i == start_step_index and prior_state.has("step_targets"):
			step_targets = prior_state["step_targets"]
		else:
			step_targets = adapter.get_step_targets(step)

		var target_outcomes: Array = _copy_target_outcomes(prior_state.get("target_outcomes", [])) if i == start_step_index else []
		var step_damage: int = int(prior_state.get("step_damage", 0)) if i == start_step_index else 0
		var step_hit := false
		var step_saved := false
		var current_target_start := start_target_index if i == start_step_index else 0

		# Check if prerequisite step as a whole was skipped
		var prereq_skipped := false
		if gate != "always":
			var gate_ref = step.get("gate_step", i - 1)
			var ref_idx := -1
			if gate_ref is int:
				ref_idx = gate_ref
			elif gate_ref is String:
				for idx in step_results.size():
					if step_results[idx].get("step_id") == gate_ref:
						ref_idx = idx
						break
			if ref_idx >= 0 and ref_idx < step_results.size():
				var ref_res: Dictionary = step_results[ref_idx]
				if bool(ref_res.get("skipped", false)):
					prereq_skipped = true

		if prereq_skipped:
			step_results.append({
				"step_id": step_id,
				"type": step_type,
				"target_mode": step_target_mode,
				"skipped": true,
				"reason": "prerequisite_skipped",
				"target_outcomes": []
			})
			continue

		for target_idx in range(current_target_start, step_targets.size()):
			var s_target = step_targets[target_idx]
			if not adapter.is_target_eligible(step, s_target):
				continue

			# Per-target gate evaluation
			if gate != "always":
				var gate_ref = step.get("gate_step", i - 1)
				var ref_idx := -1
				if gate_ref is int:
					ref_idx = gate_ref
				elif gate_ref is String:
					for idx in step_results.size():
						if step_results[idx].get("step_id") == gate_ref:
							ref_idx = idx
							break
				if ref_idx < 0 or ref_idx >= step_results.size():
					target_outcomes.append({
						"target": s_target,
						"target_name": adapter.get_target_name(s_target),
						"skipped": true,
						"reason": "gate_not_found"
					})
					continue
				var ref_res: Dictionary = step_results[ref_idx]
				if bool(ref_res.get("skipped", false)):
					target_outcomes.append({
						"target": s_target,
						"target_name": adapter.get_target_name(s_target),
						"skipped": true,
						"reason": "prerequisite_skipped"
					})
					continue

				var ref_outcome: Dictionary = {}
				for to in ref_res.get("target_outcomes", []):
					if _same_actor(to.get("target"), s_target):
						ref_outcome = to
						break
				if ref_outcome.is_empty():
					if str(ref_res.get("target_mode", "target")) == "target" and not ref_res.get("target_outcomes", []).is_empty():
						ref_outcome = ref_res["target_outcomes"][0]
				if ref_outcome.is_empty():
					target_outcomes.append({
						"target": s_target,
						"target_name": adapter.get_target_name(s_target),
						"skipped": true,
						"reason": "gate_target_not_found"
					})
					continue
				if bool(ref_outcome.get("skipped", false)):
					target_outcomes.append({
						"target": s_target,
						"target_name": adapter.get_target_name(s_target),
						"skipped": true,
						"reason": "prerequisite_target_skipped"
					})
					continue

				var gate_satisfied := false
				match gate:
					"hit": gate_satisfied = bool(ref_outcome.get("hit", false))
					"miss": gate_satisfied = not bool(ref_outcome.get("hit", false))
					"failed_save": gate_satisfied = not bool(ref_outcome.get("saved", true))
					"successful_save": gate_satisfied = bool(ref_outcome.get("saved", false))
				if not gate_satisfied:
					target_outcomes.append({
						"target": s_target,
						"target_name": adapter.get_target_name(s_target),
						"skipped": true,
						"reason": "gate_not_satisfied",
						"gate": gate
					})
					continue

			if step_type in ["attack", "save"] and adapter.has_method("request_step_roll_choice"):
				var roll_state := {
					"step_results": _copy_step_results(step_results), "total_damage": total_damage,
					"step_damage": step_damage, "messages": messages.duplicate(),
					"first_attack_hit": first_attack_hit, "has_attack": has_attack,
					"primary_save_saved": primary_save_saved, "has_save": has_save,
					"step_targets": step_targets, "target_outcomes": _copy_target_outcomes(target_outcomes),
				}
				var roll_choice: Dictionary = adapter.request_step_roll_choice(step, s_target, i, target_idx, roll_state)
				if roll_choice.has("roll_choice_request"):
					return roll_choice

			match step_type:
				"attack":
					var is_first_attack := not has_attack
					has_attack = true
					var res: Dictionary = adapter.resolve_attack_step(step, s_target, i, target_idx, step_results, total_damage, messages, first_attack_hit, has_attack, primary_save_saved, has_save, target_outcomes, step_targets, step_damage, is_first_attack)
					if res.has("damage_request"):
						return res
					var hit := bool(res.get("hit", false))
					step_hit = hit
					if is_first_attack:
						first_attack_hit = hit
					var dmg := int(res.get("damage", 0))
					step_damage += dmg
					total_damage += dmg
					var msg := str(res.get("message", "")).strip_edges()
					if not msg.is_empty(): messages.append(msg)
					var outcome_entry := {
						"target": s_target,
						"target_name": adapter.get_target_name(s_target),
						"hit": hit,
						"damage": dmg,
						"result": res
					}
					for fact in ["resolved", "ward_absorbed", "ward_remaining_hp", "ward_projected", "temp_hp_absorbed", "hp_loss", "hp_before", "hp_after", "temp_hp_before", "temp_hp_after", "is_alive_before", "is_alive_after", "critical", "damage_is_critical"]:
						if res.has(fact):
							outcome_entry[fact] = res[fact]
					if adapter.has_method("settle_target_occurrence"):
						var settle_susp = adapter.settle_target_occurrence(s_target, step, res, outcome_entry, i, target_idx, step_results, total_damage, step_damage, messages, first_attack_hit, has_attack, primary_save_saved, has_save, target_outcomes, step_targets, is_first_attack)
						if settle_susp is Dictionary and (settle_susp.has("concentration_request") or settle_susp.has("roll_choice_request")):
							return settle_susp
					target_outcomes.append(outcome_entry)

				"save":
					has_save = true
					var res: Dictionary = adapter.resolve_save_step(step, s_target, i, target_idx, step_results, total_damage, messages, first_attack_hit, has_attack, primary_save_saved, has_save, target_outcomes, step_targets, step_damage)
					if res.has("damage_request"):
						return res
					var saved := bool(res.get("saved", false))
					step_saved = saved
					if adapter.is_primary_target(s_target) or not has_save:
						primary_save_saved = saved
					var dmg := int(res.get("damage", 0))
					step_damage += dmg
					total_damage += dmg
					var msg := str(res.get("message", "")).strip_edges()
					if not msg.is_empty(): messages.append(msg)
					var outcome_entry := {
						"target": s_target,
						"target_name": adapter.get_target_name(s_target),
						"saved": saved,
						"damage": dmg,
						"result": res
					}
					for fact in ["resolved", "ward_absorbed", "ward_remaining_hp", "ward_projected", "temp_hp_absorbed", "hp_loss", "hp_before", "hp_after", "temp_hp_before", "temp_hp_after", "is_alive_before", "is_alive_after", "critical", "damage_is_critical"]:
						if res.has(fact):
							outcome_entry[fact] = res[fact]
					if adapter.has_method("settle_target_occurrence"):
						var settle_susp = adapter.settle_target_occurrence(s_target, step, res, outcome_entry, i, target_idx, step_results, total_damage, step_damage, messages, first_attack_hit, has_attack, primary_save_saved, has_save, target_outcomes, step_targets, false)
						if settle_susp is Dictionary and (settle_susp.has("concentration_request") or settle_susp.has("roll_choice_request")):
							return settle_susp
					target_outcomes.append(outcome_entry)

				"damage":
					var res: Dictionary = adapter.resolve_damage_step(step, s_target, i, target_idx, step_results, total_damage, messages, first_attack_hit, has_attack, primary_save_saved, has_save, target_outcomes, step_targets, step_damage)
					if res.has("damage_request"):
						return res
					var dmg := int(res.get("damage", 0))
					step_damage += dmg
					total_damage += dmg
					var msg := str(res.get("message", "")).strip_edges()
					if not msg.is_empty(): messages.append(msg)
					var outcome_entry := {
						"target": s_target,
						"target_name": adapter.get_target_name(s_target),
						"damage": dmg,
						"result": res
					}
					for fact in ["resolved", "ward_absorbed", "ward_remaining_hp", "ward_projected", "temp_hp_absorbed", "hp_loss", "hp_before", "hp_after", "temp_hp_before", "temp_hp_after", "is_alive_before", "is_alive_after", "critical", "damage_is_critical"]:
						if res.has(fact):
							outcome_entry[fact] = res[fact]
					if adapter.has_method("settle_target_occurrence"):
						var settle_susp = adapter.settle_target_occurrence(s_target, step, res, outcome_entry, i, target_idx, step_results, total_damage, step_damage, messages, first_attack_hit, has_attack, primary_save_saved, has_save, target_outcomes, step_targets, false)
						if settle_susp is Dictionary and (settle_susp.has("concentration_request") or settle_susp.has("roll_choice_request")):
							return settle_susp
					target_outcomes.append(outcome_entry)

				"effect":
					var res: Dictionary = adapter.resolve_effect_step(step, s_target)
					var msg := str(res.get("message", "")).strip_edges()
					if not msg.is_empty(): messages.append(msg)
					target_outcomes.append({
						"target": s_target,
						"target_name": adapter.get_target_name(s_target),
						"result": res
					})

				"replace_hp":
					var res: Dictionary = adapter.resolve_replace_hp_step(step, s_target)
					replaced = bool(res.get("replaced", false))
					var msg := str(res.get("message", "")).strip_edges()
					if not msg.is_empty(): messages.append(msg)
					target_outcomes.append({
						"target": s_target,
						"target_name": adapter.get_target_name(s_target),
						"replaced": replaced,
						"replacement_hp": res.get("replacement_hp", 1),
						"result": res
					})

		var all_targets_skipped := not target_outcomes.is_empty()
		for to in target_outcomes:
			if not bool(to.get("skipped", false)):
				all_targets_skipped = false
				break

		step_results.append({
			"step_id": step_id,
			"type": step_type,
			"target_mode": step_target_mode,
			"hit": step_hit,
			"saved": step_saved,
			"replaced": replaced if step_type == "replace_hp" else false,
			"damage": step_damage,
			"skipped": all_targets_skipped,
			"target_outcomes": target_outcomes
		})

	var final_result := {
		"success": true,
		"damage": total_damage,
		"hit": first_attack_hit if has_attack else true,
		"saved": primary_save_saved if has_save else false,
		"replaced": replaced,
		"step_results": step_results,
		"message": " ".join(messages).strip_edges()
	}
	return adapter.finalize_result(final_result)


static func execute_spell(cast: SpellResolutionContext, start_step_index: int = 0, prior_state: Dictionary = {}, start_target_index: int = 0) -> Dictionary:
	var adapter := SpellAdapter.new(cast)
	return execute_steps(cast.spell.get("steps", []), adapter, start_step_index, prior_state, start_target_index)


static func resume_roll_choice(record: Dictionary, selected: Dictionary) -> Dictionary:
	var cast: SpellResolutionContext = record["cast"]
	var cont: Dictionary = record["ordered_continuation"]
	cont["settled"] = true
	var answered: Dictionary = cast.decisions.get("ordered_roll_choices_answered", {})
	answered[cont["choice_key"]] = true
	cast.decisions["ordered_roll_choices_answered"] = answered
	cast.decisions.erase("roll_token_replacement")
	if not selected.is_empty():
		var owned_choice := selected.duplicate()
		owned_choice["test_kind"] = record["test_kind"]
		owned_choice["roller"] = record["roller"]
		cast.decisions["roll_token_replacement"] = owned_choice
	var i := int(cont["step_index"])
	var target_idx := int(cont["target_index"])
	if str(cont["phase"]) == "step":
		return execute_spell(cast, i, cont["prior_state"], target_idx)
	var adapter := SpellAdapter.new(cast)
	var outcome: Dictionary = cont["current_outcome_entry"]
	var pending := adapter.settle_target_occurrence(record["target"], cont["step"], cont["result"], outcome, i, target_idx, cont["step_results"], cont["total_damage"], cont["step_damage"], cont["messages"], cont["first_attack_hit"], cont["has_attack"], cont["primary_save_saved"], cont["has_save"], cont["target_outcomes"], cont["step_targets"], cont["is_first_attack"])
	if pending.has("concentration_request") or pending.has("roll_choice_request"):
		return pending
	# Damage and step effects were settled before the pre-save prompt.
	cont["settled"] = false
	return resume_spell_steps_occurrence(cast.caster, record["target"], cont["result"], cast.decisions, cont, {"success": not record["target"].concentrating_on.is_empty()})


static func resume_spell_steps(caster: Character, target, settled_result: Dictionary, _decisions: Dictionary, ordered_cont: Dictionary) -> Dictionary:
	if bool(ordered_cont.get("settled", false)):
		push_warning("[SharedStepExecutor] Continuation already settled; ignoring duplicate replay.")
		return settled_result
	ordered_cont["settled"] = true

	var step_index: int = int(ordered_cont.get("step_index", 0))
	var target_index: int = int(ordered_cont.get("target_index", 0))
	var pending_target = ordered_cont.get("pending_target", target)
	var step: Dictionary = ordered_cont.get("step", {})
	var cast: SpellResolutionContext = ordered_cont["cast"]

	# Apply step effects if save or attack had effects and was pending
	if step.has("effects") and not bool(settled_result.get("step_effects_applied", false)):
		settled_result["step_effects_applied"] = true
		settled_result = SharedSpell.apply_custom_effects(cast.caster, pending_target, step["effects"], settled_result, cast.slot_level)

	var target_outcomes: Array = _copy_target_outcomes(ordered_cont.get("target_outcomes", []))
	var step_results: Array = _copy_step_results(ordered_cont.get("step_results", []))
	var total_damage: int = int(ordered_cont.get("total_damage", 0)) + int(settled_result.get("damage", 0))
	var step_damage: int = int(ordered_cont.get("step_damage", 0)) + int(settled_result.get("damage", 0))
	var messages: Array[String] = []
	for m in ordered_cont.get("messages", []): messages.append(str(m))
	var settled_msg := str(settled_result.get("message", "")).strip_edges()
	if not settled_msg.is_empty():
		messages.append(settled_msg)

	var adapter := SpellAdapter.new(cast)
	var step_targets: Array = ordered_cont.get("step_targets", [])
	var next_target_idx := target_index + 1
	var is_first_attack: bool = bool(ordered_cont.get("is_first_attack", false))
	var current_first_attack_hit: bool = bool(ordered_cont.get("first_attack_hit", false))
	if is_first_attack and str(step.get("type", "")) == "attack":
		current_first_attack_hit = bool(settled_result.get("hit", false))

	var outcome_entry := {
		"target": pending_target,
		"target_name": adapter.get_target_name(pending_target),
		"hit": settled_result.get("hit", false),
		"saved": settled_result.get("saved", false),
		"damage": int(settled_result.get("damage", 0)),
		"result": settled_result
	}
	for fact in ["resolved", "ward_absorbed", "ward_remaining_hp", "ward_projected", "temp_hp_absorbed", "hp_loss", "hp_before", "hp_after", "temp_hp_before", "temp_hp_after", "is_alive_before", "is_alive_after", "critical", "damage_is_critical"]:
		if settled_result.has(fact):
			outcome_entry[fact] = settled_result[fact]
	if adapter.has_method("settle_target_occurrence"):
		var settle_susp = adapter.settle_target_occurrence(pending_target, step, settled_result, outcome_entry, step_index, target_index, step_results, total_damage, step_damage, messages, current_first_attack_hit, bool(ordered_cont.get("has_attack", false)), bool(ordered_cont.get("primary_save_saved", false)), bool(ordered_cont.get("has_save", false)), target_outcomes, step_targets, is_first_attack)
		if settle_susp is Dictionary and (settle_susp.has("concentration_request") or settle_susp.has("roll_choice_request")):
			return settle_susp
	target_outcomes.append(outcome_entry)

	# Cast-owned execution state (grid, participants, visibility, raw area roll,
	# choice context, Metamagic budget) stays exactly as the suspended cast holds
	# it. The owner's answer was already validated and applied by the registry, so
	# caller-supplied decisions are never merged here.

	var prior_state := {
		"step_results": step_results,
		"total_damage": total_damage,
		"step_damage": step_damage,
		"messages": messages,
		"first_attack_hit": current_first_attack_hit,
		"has_attack": bool(ordered_cont.get("has_attack", false)),
		"primary_save_saved": settled_result.get("saved", false) if adapter.is_primary_target(pending_target) and str(step.get("type", "")) == "save" else bool(ordered_cont.get("primary_save_saved", false)),
		"has_save": bool(ordered_cont.get("has_save", false)),
		"step_targets": step_targets,
		"target_outcomes": target_outcomes
	}

	var steps: Array = cast.spell.get("steps", [])

	if next_target_idx < step_targets.size():
		return execute_steps(steps, adapter, step_index, prior_state, next_target_idx)
	else:
		step_results.append({
			"step_id": str(step.get("id", str(step_index))),
			"type": str(step.get("type", "")),
			"target_mode": str(step.get("target", "target")),
			"hit": bool(settled_result.get("hit", false)),
			"saved": bool(settled_result.get("saved", false)),
			"replaced": false,
			"damage": step_damage,
			"target_outcomes": target_outcomes
		})
		prior_state["step_results"] = step_results
		prior_state.erase("step_targets")
		prior_state.erase("target_outcomes")
		prior_state["step_damage"] = 0
		return execute_steps(steps, adapter, step_index + 1, prior_state, 0)


static func resume_spell_steps_occurrence(caster: Character, target, settled_result: Dictionary, _decisions: Dictionary, ordered_cont: Dictionary, settlement: Dictionary = {}) -> Dictionary:
	if bool(ordered_cont.get("settled", false)):
		push_warning("[SharedStepExecutor] Continuation already settled; ignoring duplicate replay.")
		return settled_result
	ordered_cont["settled"] = true

	var step_index: int = int(ordered_cont.get("step_index", 0))
	var target_index: int = int(ordered_cont.get("target_index", 0))
	var pending_target = ordered_cont.get("pending_target", target)
	var step: Dictionary = ordered_cont.get("step", {})
	var cast: SpellResolutionContext = ordered_cont["cast"]

	var target_outcomes: Array = _copy_target_outcomes(ordered_cont.get("target_outcomes", []))
	var step_results: Array = _copy_step_results(ordered_cont.get("step_results", []))
	var total_damage: int = int(ordered_cont.get("total_damage", 0))
	var step_damage: int = int(ordered_cont.get("step_damage", 0))
	var messages: Array[String] = []
	for m in ordered_cont.get("messages", []): messages.append(str(m))

	var current_outcome: Dictionary = ordered_cont.get("current_outcome_entry", {})
	if current_outcome.is_empty():
		current_outcome = {
			"target": pending_target,
			"target_name": SpellAdapter.new(cast).get_target_name(pending_target),
			"hit": settled_result.get("hit", false),
			"saved": settled_result.get("saved", false),
			"damage": int(settled_result.get("damage", 0)),
			"result": settled_result
		}
	current_outcome["occurrence_settled"] = true
	current_outcome["concentration_maintained"] = bool(settlement.get("success", false))
	target_outcomes.append(current_outcome)

	var step_targets: Array = ordered_cont.get("step_targets", [])
	var next_target_idx := target_index + 1
	var adapter := SpellAdapter.new(cast)

	var is_first_attack: bool = bool(ordered_cont.get("is_first_attack", false))
	var current_first_attack_hit: bool = bool(ordered_cont.get("first_attack_hit", false))

	var prior_state := {
		"step_results": step_results,
		"total_damage": total_damage,
		"step_damage": step_damage,
		"messages": messages,
		"first_attack_hit": current_first_attack_hit,
		"has_attack": bool(ordered_cont.get("has_attack", false)),
		"primary_save_saved": bool(ordered_cont.get("primary_save_saved", false)),
		"has_save": bool(ordered_cont.get("has_save", false)),
		"step_targets": step_targets,
		"target_outcomes": target_outcomes
	}

	var steps: Array = cast.spell.get("steps", [])
	if next_target_idx < step_targets.size():
		return execute_steps(steps, adapter, step_index, prior_state, next_target_idx)
	else:
		step_results.append({
			"step_id": str(step.get("id", str(step_index))),
			"type": str(step.get("type", "")),
			"target_mode": str(step.get("target", "target")),
			"hit": bool(current_outcome.get("hit", false)),
			"saved": bool(current_outcome.get("saved", false)),
			"replaced": false,
			"damage": step_damage,
			"target_outcomes": target_outcomes
		})
		prior_state["step_results"] = step_results
		prior_state.erase("step_targets")
		prior_state.erase("target_outcomes")
		prior_state["step_damage"] = 0
		return execute_steps(steps, adapter, step_index + 1, prior_state, 0)


static func resolve_zero_hp_replacement(target, hp_before: int, damage: int, damage_type: String, critical: bool, decisions: Dictionary = {}) -> bool:
	if hp_before <= 0 or damage <= 0:
		return false
	if target is Character and target.is_dead():
		return false
	if target is Dictionary and not bool(target.get("is_alive", true)):
		return false
	var current_hp: int = target.current_hp if target is Character else int(target.get("current_hp", 0))
	if current_hp > 0:
		return false
	var rule := get_zero_hp_replacement_rule(target)
	if rule.is_empty():
		return false

	if critical and bool(rule.get("bypass_critical", false)):
		return false
	var bypass_types: Array = rule.get("bypass_damage_types", [])
	if damage_type.to_lower() in bypass_types:
		return false

	var canon_rule := canonicalize_rule(rule)
	var adapter := DamageEventAdapter.new(target, hp_before, damage, damage_type, critical, decisions)
	var result := execute_steps(canon_rule["steps"], adapter)
	return bool(result.get("replaced", false))


class DamageEventAdapter:
	var target
	var hp_before: int
	var damage: int
	var damage_type: String
	var critical: bool
	var decisions: Dictionary = {}

	func _init(p_target, p_hp_before: int, p_damage: int, p_damage_type: String, p_critical: bool, p_decisions: Dictionary = {}) -> void:
		target = p_target
		hp_before = p_hp_before
		damage = p_damage
		damage_type = p_damage_type
		critical = p_critical
		decisions = p_decisions

	func get_context_name() -> String:
		return "zero_hp_replacement"

	func is_primary_target(t) -> bool:
		return SharedStepExecutor._same_actor(t, target)

	func get_step_targets(step: Dictionary) -> Array:
		var target_mode := str(step.get("target", "target"))
		if target_mode != "target":
			return []
		return [target]

	func is_target_eligible(_step: Dictionary, _target) -> bool:
		return true

	func get_target_name(t) -> String:
		return t.character_name if t is Character else str(t.get("name", "Target"))

	func resolve_attack_step(_step, _t, _i, _target_idx, _step_results, _total_damage, _messages, _first_attack_hit, _has_attack, _primary_save_saved, _has_save, _target_outcomes, _step_targets, _step_damage: int = 0, _is_first_attack: bool = false) -> Dictionary:
		return {"success": false, "error": "Attack step unsupported in zero_hp_replacement"}

	func resolve_save_step(step: Dictionary, t, _i, _target_idx, _step_results, _total_damage, _messages, _first_attack_hit, _has_attack, _primary_save_saved, _has_save, _target_outcomes, _step_targets, _step_damage: int = 0) -> Dictionary:
		var ability: String = str(step.get("save", step.get("save_ability", "CON")))
		var dc: int = int(step.get("dc_base", 5)) + (damage if bool(step.get("dc_add_damage", false)) else 0)
		var saved := false
		if t is Character:
			saved = t.saving_throw_to_dc(ability, dc, false, false, decisions) >= dc
		elif t is Dictionary:
			saved = BarbarianRules.roll_monster_save(t, ability, null, false, false, decisions) >= dc
		return {
			"success": true,
			"saved": saved,
			"dc": dc,
			"message": "%s rolls %s saving throw vs DC %d: %s" % [get_target_name(t), ability, dc, "Success" if saved else "Failure"]
		}

	func resolve_damage_step(_step, _t, _i, _target_idx, _step_results, _total_damage, _messages, _first_attack_hit, _has_attack, _primary_save_saved, _has_save, _target_outcomes, _step_targets, _step_damage: int = 0) -> Dictionary:
		return {"success": false, "error": "Damage step unsupported in zero_hp_replacement"}

	func resolve_effect_step(_step, _t) -> Dictionary:
		return {"success": false, "error": "Effect step unsupported in zero_hp_replacement"}

	func resolve_replace_hp_step(step: Dictionary, t) -> Dictionary:
		var replacement_hp: int = int(step.get("replacement_hp", 1))
		var max_hp_val: int = t.max_hp if t is Character else int(t.get("max_hp", 0))
		if max_hp_val > 0:
			replacement_hp = mini(replacement_hp, max_hp_val)
		replacement_hp = maxi(1, replacement_hp)
		if t is Character:
			t.current_hp = replacement_hp
			t.is_alive = true
			t.death_save_failures = 0
		elif t is Dictionary:
			t["current_hp"] = replacement_hp
			t["is_alive"] = true
		return {
			"success": true,
			"replaced": true,
			"replacement_hp": replacement_hp,
			"message": "%s drops to %d HP instead." % [get_target_name(t), replacement_hp]
		}

	func finalize_result(final_result: Dictionary) -> Dictionary:
		return final_result


class SpellAdapter:
	var cast: SpellResolutionContext

	func _init(p_cast: SpellResolutionContext) -> void:
		cast = p_cast

	func get_context_name() -> String:
		return "spell"

	func is_primary_target(t) -> bool:
		return SharedStepExecutor._same_actor(t, cast.target)

	func validate_spatial_context(steps: Array) -> String:
		return SharedStepExecutor.validate_spatial_context_for_steps(steps, cast.decisions)

	func request_step_roll_choice(step: Dictionary, s_target, i: int, target_idx: int, prior_state: Dictionary) -> Dictionary:
		var cast_ctx: SpellCastContext = cast.decisions.get("cast_context")
		var choice_key := "%d:%d:step" % [i, target_idx]
		if cast_ctx == null or not cast_ctx.collect_roll_token_decision.is_valid() or cast.decisions.get("ordered_roll_choices_answered", {}).has(choice_key):
			return {}
		var roller = cast.caster if str(step["type"]) == "attack" else s_target
		var test_kind := "attack" if str(step["type"]) == "attack" else "save" if s_target is Character else "monster_save"
		var label := "spell attack for %s" % cast.spell.get("name", "Spell") if test_kind == "attack" else "%s saving throw against %s" % [step.get("save", "Spell"), cast.spell.get("name", "Spell")]
		return SpellDamageRolls.create_roll_choice_request(cast, s_target, roller, test_kind, label, {
			"settled": false, "phase": "step", "choice_key": choice_key,
			"step_index": i, "target_index": target_idx, "prior_state": prior_state,
			"step_results": prior_state.get("step_results", []),
		})

	func settle_target_occurrence(s_target, step: Dictionary, res: Dictionary, outcome_entry: Dictionary = {}, i: int = 0, target_idx: int = 0, step_results: Array = [], total_damage: int = 0, step_damage: int = 0, messages: Array = [], first_attack_hit: bool = false, has_attack: bool = false, primary_save_saved: bool = false, has_save: bool = false, target_outcomes: Array = [], step_targets: Array = [], is_first_attack: bool = false) -> Dictionary:
		var dmg_resolved: int = int(res.get("resolved", res.get("damage", 0)))
		var hp_loss: int = int(res.get("damage", 0))

		if dmg_resolved > 0 or hp_loss > 0:
			ClericRules.clear_turning_after_damage(s_target)

		var cast_ctx: SpellCastContext = cast.decisions.get("cast_context")
		var hud = cast.decisions.get("hud", cast_ctx.hud if cast_ctx != null else null)
		var tracker = cast.decisions.get("tracker", cast_ctx.tracker if cast_ctx != null else null)
		var trigger_defeat = cast.decisions.get("trigger_enemy_defeat_features", cast_ctx.trigger_enemy_defeat_features if cast_ctx != null else null)

		# Defeat processing for 0 HP monster actors:
		if s_target is Dictionary and int(s_target.get("current_hp", 0)) <= 0 and not bool(s_target.get("_defeat_processed", false)):
			s_target["_defeat_processed"] = true
			s_target["is_alive"] = false
			if hud != null:
				hud.add_log("[color=green]%s was defeated![/color]" % str(s_target.get("name", "The creature")))
			if tracker != null:
				tracker.remove_combatant(str(s_target.get("id", "")))
			if trigger_defeat != null and trigger_defeat.is_valid():
				trigger_defeat.call(s_target, cast.caster)

		# Concentration save per occurrence for concentrating Characters:
		if s_target is Character and not s_target.concentrating_on.is_empty():
			if not s_target.is_alive or s_target.current_hp <= 0 or s_target.has_condition("incapacitated") or s_target.has_condition("unconscious"):
				SpellEncounterLifecycle._end_concentration(cast_ctx, s_target)
				outcome_entry["occurrence_settled"] = true
				return {}
			elif dmg_resolved > 0:
				var concentration_spell_id := str(s_target.concentrating_on.get("spell_id", ""))
				var protected_hunter := false
				for feature in s_target.features:
					for effect in s_target._feature_effects(feature):
						if effect.get("type", "") == "concentration_protection" and concentration_spell_id in effect.get("spells", []):
							protected_hunter = true
							break
				if protected_hunter:
					outcome_entry["occurrence_settled"] = true
					return {}

				var dc: int = mini(30, maxi(10, int(floor(float(dmg_resolved) / 2.0))))
				var choice_key := "%d:%d:concentration" % [i, target_idx]
				if cast_ctx != null and cast_ctx.collect_roll_token_decision.is_valid() and not cast.decisions.get("ordered_roll_choices_answered", {}).has(choice_key):
					return SpellDamageRolls.create_roll_choice_request(cast, s_target, s_target, "save", "CON concentration save", {
						"settled": false, "phase": "concentration", "choice_key": choice_key,
						"step_index": i, "target_index": target_idx, "step": step, "cast": cast,
						"step_results": SharedStepExecutor._copy_step_results(step_results),
						"total_damage": total_damage, "step_damage": step_damage, "messages": messages.duplicate(),
						"first_attack_hit": first_attack_hit, "has_attack": has_attack,
						"primary_save_saved": primary_save_saved, "has_save": has_save,
						"target_outcomes": SharedStepExecutor._copy_target_outcomes(target_outcomes), "step_targets": step_targets,
						"current_outcome_entry": outcome_entry, "result": res, "is_first_attack": is_first_attack,
					})
				var save_test: Dictionary = s_target.saving_throw_test_to_dc("CON", dc, bool(s_target.concentrating_on.get("extended_spell", false)), false, cast.decisions)
				var roll := int(save_test.get("total", 0))
				var success: bool = roll >= dc

				if not success:
					var has_stroke: bool = s_target.has_feature("rogue_stroke_of_luck") and int(s_target.feature_uses.get("rogue_stroke_of_luck", 0)) > 0
					var has_bardic: bool = BardicInspirationRules.has_die(s_target)
					if has_stroke or has_bardic:
						var stroke_dec = SpellDamageRolls.get_concentration_decision(cast.decisions, s_target, "stroke_of_luck", cast.caster) if has_stroke else null
						var bardic_dec = SpellDamageRolls.get_concentration_decision(cast.decisions, s_target, "bardic_inspiration", cast.caster) if has_bardic else null

						# If stroke can be decided immediately via supplied decisions:
						if has_stroke and stroke_dec != null:
							var stroke_accepted: bool = bool(stroke_dec)
							var stroke := RogueRules.apply_stroke_of_luck(s_target, save_test, stroke_accepted)
							if stroke.get("used", false):
								save_test = stroke.get("result", save_test)
								roll = int(save_test.get("total", roll))
								success = bool(save_test.get("success", false))

						# If stroke succeeded, concentration is maintained! Bardic is not offered.
						if success:
							if hud != null:
								hud.add_log("[color=green]%s maintained concentration![/color]" % s_target.character_name)
							outcome_entry["occurrence_settled"] = true
							return {}

						# If bardic decision is supplied and stroke is resolved (or stroke was not chosen for concentration):
						if has_bardic and bardic_dec != null:
							var bardic_accepted: bool = bool(bardic_dec)
							var inspiration := BardicInspirationRules.apply_to_test(s_target, roll, dc, bardic_accepted)
							if inspiration.get("used", false):
								roll = int(inspiration.get("total", roll))
								success = bool(inspiration.get("success", false))
							if success:
								if hud != null:
									hud.add_log("[color=green]%s maintained concentration![/color]" % s_target.character_name)
							else:
								SpellEncounterLifecycle._end_concentration(cast_ctx, s_target)
								if hud != null:
									hud.add_log("[color=red]%s failed CON save! Concentration lost.[/color]" % s_target.character_name)
							outcome_entry["occurrence_settled"] = true
							return {}

						# If stroke was supplied (and failed) and no bardic is available:
						if (has_stroke and stroke_dec != null) and not has_bardic:
							SpellEncounterLifecycle._end_concentration(cast_ctx, s_target)
							if hud != null:
								hud.add_log("[color=red]%s failed CON save! Concentration lost.[/color]" % s_target.character_name)
							outcome_entry["occurrence_settled"] = true
							return {}

						# Needs suspension! Choice sequencing: offer Stroke first if available and undecided, else Bardic.
						var feature_choice: String = "stroke_of_luck" if (has_stroke and stroke_dec == null) else "bardic_inspiration"
						var req_id := SpellDamageRolls.create_concentration_request(cast.caster, s_target, dc, roll, feature_choice, cast.decisions, res, save_test)
						var continuation := {
							"continuation_id": req_id,
							"request_id": req_id,
							"kind": "concentration",
							"step_index": i,
							"target_index": target_idx,
							"pending_target": s_target,
							"step_results": SharedStepExecutor._copy_step_results(step_results),
							"total_damage": total_damage,
							"step_damage": step_damage,
							"messages": messages,
							"first_attack_hit": bool(res.get("hit", false)) if (not has_attack or is_first_attack) else first_attack_hit,
							"has_attack": has_attack,
							"is_first_attack": is_first_attack,
							"primary_save_saved": primary_save_saved,
							"has_save": has_save,
							"cast": cast,
							"step": step,
							"step_targets": step_targets,
							"target_outcomes": SharedStepExecutor._copy_target_outcomes(target_outcomes),
							"current_outcome_entry": outcome_entry,
							"settled": false
						}
						SpellDamageRolls.attach_continuation(req_id, continuation, cast)
						var susp_res := res.duplicate()
						susp_res["concentration_request"] = {
							"request_id": req_id,
							"target": s_target,
							"dc": dc,
							"roll": roll,
							"feature": feature_choice,
							"save_test": save_test.duplicate(true)
						}
						susp_res["ordered_continuation"] = continuation
						susp_res["suspended_step"] = i
						susp_res["step_results"] = SharedStepExecutor._copy_step_results(step_results)
						return susp_res

					# No reaction feature available: failed CON save drops concentration immediately
					SpellEncounterLifecycle._end_concentration(cast_ctx, s_target)
					if hud != null:
						hud.add_log("[color=red]%s failed CON save! Concentration lost.[/color]" % s_target.character_name)
				else:
					if hud != null:
						hud.add_log("[color=green]%s maintained concentration![/color]" % s_target.character_name)

		outcome_entry["occurrence_settled"] = true
		return {}

	func get_step_targets(step: Dictionary) -> Array:
		var step_target_mode: String = str(step.get("target", "target"))
		if step_target_mode == "area":
			# One raw roll per area step, shared by all of that step's targets. A
			# resumed step never reaches here again, so the roll survives suspension.
			cast.decisions["spell_damage_context"] = {}
		else:
			cast.decisions.erase("spell_damage_context")

		if step_target_mode == "self":
			return [cast.caster]
		elif step_target_mode == "area":
			if cast.decisions.has("area_targets"):
				return cast.decisions["area_targets"]
			var grid: HexGrid = cast.decisions.get("grid")
			if grid == null:
				return []

			var caster_coord := Vector2i.ZERO
			for p in cast.decisions.get("players", []):
				if p.get("character") == cast.caster:
					caster_coord = p.get("hex_position", Vector2i.ZERO)
					break
			if caster_coord == Vector2i.ZERO and cast.decisions.has("spell_visibility"):
				caster_coord = cast.decisions["spell_visibility"].get("caster_position", Vector2i.ZERO)

			var target_coord := Vector2i.ZERO
			if cast.target is Character:
				for p in cast.decisions.get("players", []):
					if p.get("character") == cast.target:
						target_coord = p.get("hex_position", Vector2i.ZERO)
						break
			elif cast.target is Dictionary:
				target_coord = cast.target.get("hex_position", Vector2i.ZERO)
			if target_coord == Vector2i.ZERO and cast.decisions.has("spell_visibility"):
				target_coord = cast.decisions["spell_visibility"].get("target_position", Vector2i.ZERO)

			var shape: String = str(step.get("shape", "sphere"))
			var area_hexes: Array[Vector2i] = []
			if shape == "cone":
				var size := int(step.get("size", step.get("cone_size", 3)))
				area_hexes = Targeting.get_cone_targets(caster_coord, target_coord, size, grid)
				area_hexes = area_hexes.filter(func(h): return Targeting.has_line_of_sight(caster_coord, h, grid))
			elif shape == "cube":
				var size := int(step.get("size", 2))
				area_hexes = Targeting.get_cube_targets(caster_coord, target_coord, size, grid)
				area_hexes = area_hexes.filter(func(h): return Targeting.has_line_of_sight(caster_coord, h, grid))
			else:
				var radius := int(step.get("radius", step.get("size", 2)))
				area_hexes = Targeting.get_sphere_targets(target_coord, radius, grid)
				area_hexes = area_hexes.filter(func(h): return Targeting.has_line_of_sight(target_coord, h, grid))

			var step_targets: Array = []
			for p in cast.decisions.get("players", []):
				var ch: Character = p.get("character")
				if p.get("hex_position") in area_hexes and ch != null and not ch.is_dead():
					step_targets.append(ch)
			for m in cast.decisions.get("monsters", []):
				if m.get("hex_position") in area_hexes and bool(m.get("is_alive", false)):
					step_targets.append(m)
			return step_targets
		return [cast.target]

	func is_target_eligible(step: Dictionary, t) -> bool:
		if t is Character:
			if t.is_dead() and not step.has("revive"):
				return false
			return true
		if t is Dictionary and not bool(t.get("is_alive", true)):
			return false
		return true

	func get_target_name(t) -> String:
		return t.character_name if t is Character else str(t.get("name", "Target"))

	func _clean_step_spell(step: Dictionary) -> Dictionary:
		var step_spell := cast.spell.duplicate(true)
		step_spell.erase("steps")
		step_spell.erase("attack_type")
		step_spell.erase("save")
		step_spell.erase("half_on_save")
		step_spell.erase("damage")
		step_spell.erase("damage_type")
		step_spell.erase("scaling")
		step_spell.erase("upcast")
		step_spell.erase("effects")
		if step.has("damage"):
			step_spell["damage"] = step["damage"]
			step_spell["damage_type"] = step.get("damage_type", "untyped")
		if step.has("scaling"): step_spell["scaling"] = step["scaling"]
		if step.has("upcast"): step_spell["upcast"] = step["upcast"]
		if step.has("effects"): step_spell["effects"] = step["effects"]
		return step_spell

	func _create_step_cast(s_target, step_spell: Dictionary) -> SpellResolutionContext:
		return SharedSpell._create_step_cast(cast, s_target, step_spell)

	func resolve_attack_step(step: Dictionary, s_target, i: int, target_idx: int, step_results: Array, total_damage: int, messages: Array, first_attack_hit: bool, has_attack: bool, primary_save_saved: bool, has_save: bool, target_outcomes: Array, step_targets: Array, step_damage: int, is_first_attack: bool = false) -> Dictionary:
		var step_spell := _clean_step_spell(step)
		step_spell["attack_type"] = step["attack_type"]
		var step_cast := _create_step_cast(s_target, step_spell)
		var res := SpellAttackResolver.resolve(step_cast)
		if res.has("damage_request"):
			var req_id: String = str(res["damage_request"].get("request_id", ""))
			var continuation := {
				"continuation_id": req_id if not req_id.is_empty() else "cont_%d_%d_%d" % [cast.get_instance_id(), i, target_idx],
				"request_id": req_id,
				"step_index": i,
				"target_index": target_idx,
				"pending_target": s_target,
				"step_results": SharedStepExecutor._copy_step_results(step_results),
				"total_damage": total_damage,
				"step_damage": step_damage,
				"messages": messages,
				"first_attack_hit": bool(res.get("hit", false)) if (not has_attack or is_first_attack) else first_attack_hit,
				"has_attack": has_attack,
				"is_first_attack": is_first_attack,
				"primary_save_saved": primary_save_saved,
				"has_save": has_save,
				"cast": cast,
				"step": step,
				"step_targets": step_targets,
				"target_outcomes": SharedStepExecutor._copy_target_outcomes(target_outcomes),
				"settled": false
			}
			SpellDamageRolls.attach_continuation(req_id, continuation, cast)
			res["ordered_continuation"] = continuation
			res["suspended_step"] = i
			res["step_results"] = SharedStepExecutor._copy_step_results(step_results)
			return res
		if bool(res.get("hit", false)) and step.has("effects"):
			res = SharedSpell.apply_custom_effects(cast.caster, s_target, step["effects"], res, cast.slot_level)
		return res

	func resolve_save_step(step: Dictionary, s_target, i: int, target_idx: int, step_results: Array, total_damage: int, messages: Array, first_attack_hit: bool, has_attack: bool, primary_save_saved: bool, has_save: bool, target_outcomes: Array, step_targets: Array, step_damage: int) -> Dictionary:
		var step_spell := _clean_step_spell(step)
		step_spell["save"] = step["save"]
		step_spell["half_on_save"] = bool(step.get("half_on_save", false))
		var step_cast := _create_step_cast(s_target, step_spell)
		var res := SpellSaveResolver.resolve(step_cast)
		if res.has("damage_request"):
			var req_id: String = str(res["damage_request"].get("request_id", ""))
			var continuation := {
				"continuation_id": req_id if not req_id.is_empty() else "cont_%d_%d_%d" % [cast.get_instance_id(), i, target_idx],
				"request_id": req_id,
				"step_index": i,
				"target_index": target_idx,
				"pending_target": s_target,
				"step_results": SharedStepExecutor._copy_step_results(step_results),
				"total_damage": total_damage,
				"step_damage": step_damage,
				"messages": messages,
				"first_attack_hit": first_attack_hit,
				"has_attack": has_attack,
				"is_first_attack": false,
				"primary_save_saved": primary_save_saved,
				"has_save": has_save,
				"cast": cast,
				"step": step,
				"step_targets": step_targets,
				"target_outcomes": SharedStepExecutor._copy_target_outcomes(target_outcomes),
				"settled": false
			}
			SpellDamageRolls.attach_continuation(req_id, continuation, cast)
			res["ordered_continuation"] = continuation
			res["suspended_step"] = i
			res["step_results"] = SharedStepExecutor._copy_step_results(step_results)
			return res
		if step.has("effects"):
			res = SharedSpell.apply_custom_effects(cast.caster, s_target, step["effects"], res, cast.slot_level)
		return res

	func resolve_damage_step(step: Dictionary, s_target, i: int, target_idx: int, step_results: Array, total_damage: int, messages: Array, first_attack_hit: bool, has_attack: bool, primary_save_saved: bool, has_save: bool, target_outcomes: Array, step_targets: Array, step_damage: int) -> Dictionary:
		var step_spell := _clean_step_spell(step)
		var formula := SpellDamageRolls.spell_damage_formula(cast.caster, step_spell, cast.slot_level)
		var roll := SpellDamageRolls._roll_spell_damage(cast.caster, formula, 1, cast.decisions)
		var res := SpellDamageRolls._finish_spell_damage(cast.caster, s_target, roll, CombatAction.spell_damage_bonus(cast.caster, step_spell), 1.0, str(step_spell["damage_type"]), cast.decisions, {"success": true, "hit": true, "effect_cast": cast.effect_cast, "message": "%s deals {damage} %s damage." % [cast.spell["name"], step_spell["damage_type"]]})
		if res.has("damage_request"):
			var req_id: String = str(res["damage_request"].get("request_id", ""))
			var continuation := {
				"continuation_id": req_id if not req_id.is_empty() else "cont_%d_%d_%d" % [cast.get_instance_id(), i, target_idx],
				"request_id": req_id,
				"step_index": i,
				"target_index": target_idx,
				"pending_target": s_target,
				"step_results": SharedStepExecutor._copy_step_results(step_results),
				"total_damage": total_damage,
				"step_damage": step_damage,
				"messages": messages,
				"first_attack_hit": first_attack_hit,
				"has_attack": has_attack,
				"is_first_attack": false,
				"primary_save_saved": primary_save_saved,
				"has_save": has_save,
				"cast": cast,
				"step": step,
				"step_targets": step_targets,
				"target_outcomes": SharedStepExecutor._copy_target_outcomes(target_outcomes),
				"settled": false
			}
			SpellDamageRolls.attach_continuation(req_id, continuation, cast)
			res["ordered_continuation"] = continuation
			res["suspended_step"] = i
			res["step_results"] = SharedStepExecutor._copy_step_results(step_results)
			return res
		if step.has("effects"):
			res = SharedSpell.apply_custom_effects(cast.caster, s_target, step["effects"], res, cast.slot_level)
		return res

	func resolve_effect_step(step: Dictionary, s_target) -> Dictionary:
		if step.has("effects"):
			var res := {"success": true, "hit": true, "slot_level": cast.slot_level, "effect_cast": cast.effect_cast}
			res = SharedSpell.apply_custom_effects(cast.caster, s_target, step["effects"], res, cast.slot_level)
			return res
		return {}

	func resolve_replace_hp_step(_step, _s_target) -> Dictionary:
		return {"success": false, "error": "replace_hp step unsupported in spells"}

	func finalize_result(final_result: Dictionary) -> Dictionary:
		final_result["slot_level"] = cast.slot_level
		final_result["effect_cast"] = cast.effect_cast
		if cast.target != null:
			var primary_outcomes: Array = []
			for sr in final_result.get("step_results", []):
				for to in sr.get("target_outcomes", []):
					if SharedStepExecutor._same_actor(to.get("target"), cast.target):
						primary_outcomes.append(to)
			if not primary_outcomes.is_empty():
				var first_to: Dictionary = primary_outcomes[0]
				var last_to: Dictionary = primary_outcomes[primary_outcomes.size() - 1]
				var primary_resolved := 0
				var primary_ward_absorbed := 0
				var primary_ward_remaining := 0
				var primary_ward_projected := false
				var primary_temp_absorbed := 0
				var primary_hp_loss := 0
				var had_damage_fact := false
				var any_critical := false
				for to in primary_outcomes:
					if to.has("resolved"):
						primary_resolved += int(to["resolved"])
						had_damage_fact = true
					if to.has("ward_absorbed"):
						primary_ward_absorbed += int(to["ward_absorbed"])
						had_damage_fact = true
					if to.has("ward_remaining_hp"):
						primary_ward_remaining = int(to["ward_remaining_hp"])
					if bool(to.get("ward_projected", false)):
						primary_ward_projected = true
					if to.has("temp_hp_absorbed"):
						primary_temp_absorbed += int(to["temp_hp_absorbed"])
					if to.has("hp_loss"):
						primary_hp_loss += int(to["hp_loss"])
					elif to.has("damage"):
						primary_hp_loss += int(to["damage"])
					if bool(to.get("critical", false)) or bool(to.get("damage_is_critical", false)):
						any_critical = true
				if had_damage_fact:
					final_result["resolved"] = primary_resolved
					final_result["ward_absorbed"] = primary_ward_absorbed
					final_result["ward_remaining_hp"] = primary_ward_remaining
					final_result["ward_projected"] = primary_ward_projected
					final_result["temp_hp_absorbed"] = primary_temp_absorbed
					final_result["hp_loss"] = primary_hp_loss
					if first_to.has("hp_before"):
						final_result["hp_before"] = first_to["hp_before"]
					if last_to.has("hp_after"):
						final_result["hp_after"] = last_to["hp_after"]
					if first_to.has("temp_hp_before"):
						final_result["temp_hp_before"] = first_to["temp_hp_before"]
					if last_to.has("temp_hp_after"):
						final_result["temp_hp_after"] = last_to["temp_hp_after"]
					if first_to.has("is_alive_before"):
						final_result["is_alive_before"] = first_to["is_alive_before"]
					if last_to.has("is_alive_after"):
						final_result["is_alive_after"] = last_to["is_alive_after"]
					if any_critical:
						final_result["critical"] = true
						final_result["damage_is_critical"] = true
		if cast.spell.has("effects"):
			final_result = SharedSpell.apply(cast.caster, cast.target, cast.spell, final_result)
		return final_result
