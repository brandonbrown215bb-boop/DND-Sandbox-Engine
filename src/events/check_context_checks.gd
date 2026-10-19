## Focused development checks for loaded ability-check context and owned modifiers.
class_name CheckContextChecks
extends RefCounted


static func run(check: Callable) -> void:
	_optional_filters(check)
	DataLoader._load_content_type("res://data/fixtures/check_context/items/", "item")
	DataLoader._load_content_type("res://data/fixtures/check_context/events/", "event")
	DataLoader._load_content_type("res://data/fixtures/check_context/classes/", "class")
	DataLoader._validate_check_context_cross_references()
	if not DataLoader.get_load_errors().is_empty(): print("[batch_h_check_context_load_errors] ", DataLoader.get_load_errors())
	check.call(DataLoader.get_load_errors().is_empty(), "Check-context fixtures pass production loader and cross-reference validation")

	var neutral_record: Dictionary = DataLoader.get_event_check_record("fixture:survey_map_event", "read_map_check")
	var renamed_record: Dictionary = DataLoader.get_event_check_record("fixture:tidal_herbs_event", "identify_herbs_check")
	check.call(not neutral_record.is_empty() and not renamed_record.is_empty(), "Neutral and renamed event/check records resolve from the loaded event tables")
	var invalid_skill_event: Dictionary = neutral_record.get("event", {}).duplicate(true)
	invalid_skill_event["check"]["skill"] = "NotARealSkill"
	check.call(not DataLoader._check_context_event_error({"events": [invalid_skill_event]}).is_empty(), "Context-aware checks reject invalid nonempty skill names while allowing the separate ability-only form")
	check.call(DataLoader.get_event_check_record("missing_event", "read_map_check").is_empty() and DataLoader.get_event_check_record("fixture:survey_map_event", "caller_check").is_empty(), "Unknown event or check cannot supply a trusted context record")
	if neutral_record.is_empty() or renamed_record.is_empty():
		return
	_authored_roll_modes(check, neutral_record, renamed_record)
	await _owned_ability_check_bonus(check, neutral_record, renamed_record)
	await _owned_ability_check_rerolls(check, neutral_record, renamed_record)

	var owner_scores := AbilityScores.new()
	owner_scores.from_dict({"STR": 10, "DEX": 10, "CON": 10, "INT": 14, "WIS": 14, "CHA": 10})
	var owner := Character.new()
	owner.initialize("Surveyor", "human", "wizard", owner_scores)
	owner.character_id = "check_context_dev_owner"
	owner.inventory.add_item("fixture:surveyors_tools")
	var owned_tools := owner.inventory.backpack_instances()
	var exact_instance_id := str(owned_tools[0].get("instance_id", "")) if not owned_tools.is_empty() else ""
	var context := _authored_context(neutral_record)
	var neutral_check: Dictionary = neutral_record.get("check", {})
	var neutral_result := EventResolver.resolve_skill_check(owner, neutral_check, {}, context)
	var source: Dictionary = neutral_result.get("context_tool_source", {})
	var tool_backpack_index := -1
	for index in owned_tools.size():
		if str(owned_tools[index].get("definition_id", "")) == "fixture:surveyors_tools":
			exact_instance_id = str(owned_tools[index].get("instance_id", ""))
			tool_backpack_index = index
			break
	check.call(int(neutral_result.get("contextual_tool_bonus", 0)) == 3 and str(source.get("tool_item_id", "")) == "fixture:surveyors_tools" and str(source.get("tool_instance_id", "")) == exact_instance_id and str(source.get("tool_effect_id", "")) == "read_map_bonus", "Neutral task uses its carried exact tool copy and authored effect")
	check.call(source.get("tool_location", {}) == {"kind": "backpack", "index": tool_backpack_index} and str(neutral_result.get("actor_id", "")) == owner.character_id, "Resolved tool provenance retains actor and exact inventory location")
	check.call(int(EventResolver.resolve_skill_check(owner, neutral_check, {}, _changed(context, "task_id", "unrelated_task")).get("contextual_tool_bonus", 0)) == 0, "Same ability and skill do not qualify an unrelated task")
	check.call(int(EventResolver.resolve_skill_check(owner, neutral_check, {}, _changed(context, "purpose_id", "unknown_purpose")).get("contextual_tool_bonus", 0)) == 0, "Unknown purpose does not qualify the authored benefit")
	check.call(int(EventResolver.resolve_skill_check(owner, neutral_check, {}, _changed(context, "origin_check_id", "caller_check")).get("contextual_tool_bonus", 0)) == 0, "Wrong originating check does not qualify the authored benefit")
	var forged_check := neutral_check.duplicate(true)
	forged_check["check_context"] = {"task_id": "survey_archive", "purpose_id": "locate_nest", "required_tool_id": "fixture:surveyors_tools"}
	forged_check["_origin_event_id"] = "fixture:survey_map_event"
	forged_check["_origin_check_id"] = "read_map_check"
	check.call(int(EventResolver.resolve_skill_check(owner, forged_check).get("contextual_tool_bonus", 0)) == 0, "Check data and caller metadata alone cannot grant a tool bonus")
	var other_scores := AbilityScores.new()
	other_scores.from_dict({"STR": 10, "DEX": 10, "CON": 10, "INT": 14, "WIS": 14, "CHA": 10})
	var other_actor := Character.new()
	other_actor.initialize("Other", "human", "wizard", other_scores)
	other_actor.character_id = "check_context_other_owner"
	var missing_tool_result := EventResolver.resolve_skill_check(other_actor, neutral_check, {}, context)
	other_actor.inventory.add_item("fixture:field_guide")
	check.call(int(EventResolver.resolve_skill_check(other_actor, neutral_check, {}, context).get("contextual_tool_bonus", 0)) == 0, "A different owned tool does not satisfy the check's required source")
	check.call(int(missing_tool_result.get("contextual_tool_bonus", 0)) == 0, "Another actor without the owned tool receives no benefit")
	owner.inventory.destroy_instance(exact_instance_id)
	check.call(int(EventResolver.resolve_skill_check(owner, neutral_check, {}, context).get("contextual_tool_bonus", 0)) == 0, "Destroying the exact tool copy ends only its eligibility source")
	owner.inventory.add_item("fixture:surveyors_tools")
	var unrelated_record: Dictionary = DataLoader.get_event_check_record("fixture:unrelated_survey_event", "mark_boundary_check")
	var unrelated_context := _authored_context(unrelated_record)
	var unrelated_result := EventResolver.resolve_skill_check(owner, unrelated_record.get("check", {}), {}, unrelated_context)
	var ordinary_investigation_modifier := owner.get_skill_check_modifier("Investigation", "INT")
	check.call(int(unrelated_result.get("contextual_tool_bonus", 0)) == 0 and int(unrelated_result.get("modifier", -999)) == ordinary_investigation_modifier and int(unrelated_result.get("dc", 0)) == 12 and unrelated_result.get("check_context", {}).get("task_id", "") == "mark_boundary", "Loaded unrelated task carries its purpose and original DC without inheriting the map-reading benefit")
	var no_tool_record: Dictionary = DataLoader.get_event_check_record("fixture:untooled_field_event", "cross_field_check")
	var no_tool_context := _authored_context(no_tool_record)
	var no_tool_result := EventResolver.resolve_skill_check(owner, no_tool_record.get("check", {}), {}, no_tool_context)
	var ordinary_survival_modifier := owner.get_skill_check_modifier("Survival", "WIS")
	check.call(int(no_tool_result.get("contextual_tool_bonus", 0)) == 0 and int(no_tool_result.get("modifier", -999)) == ordinary_survival_modifier and int(no_tool_result.get("dc", 0)) == 11 and no_tool_result.get("check_context", {}).get("purpose_id", "") == "avoid_soft_ground", "Loaded no-tool context remains an ordinary roll with its declared purpose and DC")

	owner.inventory.add_item("fixture:field_guide")
	var renamed_context := _authored_context(renamed_record)
	var renamed_result := EventResolver.resolve_skill_check(owner, renamed_record.get("check", {}), {}, renamed_context)
	var renamed_source: Dictionary = renamed_result.get("context_tool_source", {})
	check.call(int(renamed_result.get("contextual_tool_bonus", 0)) == 5 and str(renamed_source.get("tool_item_id", "")) == "fixture:field_guide" and str(renamed_source.get("tool_effect_id", "")) == "identify_herbs_bonus", "Renamed context uses the same evaluator with different task, tool, ability and bonus data")

	var scene := load("res://scenes/ui/event_dialog.tscn") as PackedScene
	var dialog := scene.instantiate() as EventDialog
	var tree := Engine.get_main_loop() as SceneTree
	await tree.process_frame
	tree.root.add_child(dialog)
	var forged_event: Dictionary = neutral_record.get("event", {}).duplicate(true)
	forged_event["check"]["dc"] = 1
	forged_event["check"]["check_context"]["task_id"] = "caller_task"
	forged_event["success"] = {"description": "FORGED", "effects": [{"type": "gold", "value": 999}]}
	dialog.popup_event(owner, forged_event)
	check.call(int(dialog._pending_check_data.get("dc", 0)) == int(neutral_check.get("dc", -1)) and str(dialog._pending_check_data.get("check_context", {}).get("task_id", "")) == "survey_archive" and str(dialog._pending_option_or_event.get("success", {}).get("description", "")) == "The map reveals the route.", "EventDialog replaces copied check facts and consequences with the loaded event record")
	check.call(dialog._pending_authored_context.get("origin_event_id", "") == "fixture:survey_map_event" and dialog._pending_authored_context.get("origin_check_id", "") == "read_map_check", "EventDialog carries the loaded source and check identity separately from caller metadata")
	dialog.queue_free()

	var unknown_dialog := scene.instantiate() as EventDialog
	tree.root.add_child(unknown_dialog)
	unknown_dialog.popup_event(owner, {"id": "caller_event", "type": "skill_check", "check": {"id": "caller_check", "ability": "INT", "skill": "Investigation", "dc": 1, "check_context": context}, "success": {"effects": [{"type": "gold", "value": 999}]}, "failure": {"effects": [{"type": "gold", "value": 999}]}})
	check.call(unknown_dialog.btn_roll.disabled and unknown_dialog._pending_authored_context.is_empty() and owner.inventory.gold == 0, "Unloaded context check is refused before caller-authored consequences can run")
	unknown_dialog.queue_free()
	await tree.process_frame


static func _authored_roll_modes(check: Callable, neutral_record: Dictionary, renamed_record: Dictionary) -> void:
	var neutral_definition: Dictionary = DataLoader.classes.get("fixture:ability_check_roll_modes_neutral_class", {})
	var renamed_definition: Dictionary = DataLoader.classes.get("fixture:ability_check_roll_modes_renamed_class", {})
	var neutral_features: Array = neutral_definition.get("features_by_level", {}).get("1", [])
	var renamed_features: Array = renamed_definition.get("features_by_level", {}).get("1", [])
	check.call(neutral_features.size() == 6 and renamed_features.size() == 1, "Neutral and renamed roll-mode fixtures load through DataLoader")
	if neutral_features.size() != 6 or renamed_features.size() != 1:
		return
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 10, "DEX": 10, "CON": 10, "INT": 14, "WIS": 14, "CHA": 10})
	var owner := Character.new()
	owner.initialize("Mode Reader", "human", "wizard", scores)
	owner.character_id = "check_roll_mode_owner"
	var context := _authored_context(neutral_record)
	var check_data: Dictionary = neutral_record.get("check", {})
	owner.features.append(neutral_features[0].duplicate(true))
	owner.features.append(neutral_features[1].duplicate(true))
	var d20_rolls := {"count": 0}
	var listener := func(result: Dictionary):
		if int(result.get("sides", 0)) == 20:
			d20_rolls["count"] = int(d20_rolls["count"]) + int(result.get("count", 1))
	Dice.dice_rolled.connect(listener)
	var before_query := int(d20_rolls["count"])
	var duplicate_query := EventResolver.ability_check_roll_mode(owner, "INT", "Investigation", context)
	check.call(str(duplicate_query.get("effective_mode", "")) == "advantage" and duplicate_query.get("contributors", []).filter(func(row): return str(row.get("status", "")) == "active" and str(row.get("mode", "")) == "advantage").size() == 2 and int(d20_rolls["count"]) == before_query, "Duplicate same-mode sources remain visible but the eligibility query rolls nothing")
	var committed_advantage := EventResolver.resolve_skill_check(owner, check_data, {}, context)
	check.call(str(committed_advantage.get("roll_mode", "")) == "advantage" and committed_advantage.get("roll_details", {}).get("rolls", []).size() == 2 and committed_advantage.get("roll_mode_contributors", []).filter(func(row): return str(row.get("status", "")) == "active" and str(row.get("mode", "")) == "advantage").size() == 2, "The normal d20 resolver rolls Advantage once and captures both exact source contributors")
	owner.features.append(neutral_features[2].duplicate(true))
	var opposite_query := EventResolver.ability_check_roll_mode(owner, "INT", "Investigation", context)
	check.call(str(opposite_query.get("effective_mode", "")) == "normal", "Opposite eligible Advantage and Disadvantage resolve to Normal")
	var committed_normal := EventResolver.resolve_skill_check(owner, check_data, {}, context)
	check.call(str(committed_normal.get("roll_mode", "")) == "normal" and committed_normal.get("roll_details", {}).get("rolls", []).size() == 1, "Opposite mode contributors use the normal one-die engine resolution")
	owner.features.pop_back()
	owner.features.append(neutral_features[3].duplicate(true))
	var cancel_query := EventResolver.ability_check_roll_mode(owner, "INT", "Investigation", context)
	check.call(str(cancel_query.get("effective_mode", "")) == "advantage" and cancel_query.get("contributors", []).any(func(row): return str(row.get("source_definition_id", "")) == "fixture:survey_advantage_one" and str(row.get("status", "")) == "active") and cancel_query.get("contributors", []).any(func(row): return str(row.get("source_definition_id", "")) == "fixture:survey_advantage_two" and str(row.get("status", "")) == "canceled"), "Selective cancellation keeps its explicitly exempt source and cancels the other exact source")
	owner.features.pop_back()
	owner.features.append(neutral_features[4].duplicate(true))
	var prohibit_query := EventResolver.ability_check_roll_mode(owner, "INT", "Investigation", context)
	check.call(str(prohibit_query.get("effective_mode", "")) == "advantage" and prohibit_query.get("contributors", []).any(func(row): return str(row.get("source_definition_id", "")) == "fixture:survey_advantage_one" and str(row.get("status", "")) == "active") and prohibit_query.get("contributors", []).any(func(row): return str(row.get("source_definition_id", "")) == "fixture:survey_advantage_two" and str(row.get("status", "")) == "prohibited"), "Selective prohibition blocks only nonexempt source contributions")
	var old_mode := str(prohibit_query.get("effective_mode", ""))
	owner.features.erase(neutral_features[0])
	owner.features.erase(neutral_features[1])
	var stale_query := EventResolver.ability_check_roll_mode(owner, "INT", "Investigation", context)
	check.call(old_mode == "advantage" and str(stale_query.get("effective_mode", "")) == "normal", "A source removed after an earlier query no longer contributes at roll commitment")
	var committed := EventResolver.resolve_skill_check(owner, check_data, {}, context)
	check.call(str(committed.get("roll_mode", "")) == "normal" and committed.get("roll_mode_contributors", []).all(func(row): return str(row.get("source_definition_id", "")) != "fixture:survey_advantage_one" and str(row.get("source_definition_id", "")) != "fixture:survey_advantage_two"), "Committed receipt revalidates current sources and exposes its final mode contributors")
	var renamed_owner := Character.new()
	renamed_owner.initialize("Marsh Reader", "human", "druid", scores)
	renamed_owner.character_id = "check_roll_mode_renamed_owner"
	renamed_owner.features.append(renamed_features[0].duplicate(true))
	var renamed_context := _authored_context(renamed_record)
	var renamed_query := EventResolver.ability_check_roll_mode(renamed_owner, "WIS", "Nature", renamed_context)
	var wrong_context := EventResolver.ability_check_roll_mode(renamed_owner, "WIS", "Nature", context)
	var renamed_result := EventResolver.resolve_skill_check(renamed_owner, renamed_record.get("check", {}), {}, renamed_context)
	var wrong_result := EventResolver.resolve_skill_check(renamed_owner, check_data, {}, context)
	check.call(str(renamed_query.get("effective_mode", "")) == "disadvantage" and str(renamed_result.get("roll_mode", "")) == "disadvantage" and renamed_result.get("roll_details", {}).get("rolls", []).size() == 2 and str(wrong_context.get("effective_mode", "")) == "normal" and wrong_context.get("contributors", []).is_empty() and str(wrong_result.get("roll_mode", "")) == "normal", "Renamed source data selects only its exact bound roll; a nonqualifying check stays Normal")
	Dice.dice_rolled.disconnect(listener)


static func _authored_context(event_check: Dictionary) -> Dictionary:
	var event_record: Dictionary = event_check.get("event", {})
	var authored_check: Dictionary = event_check.get("check", {})
	return {
		"task_id": authored_check.get("check_context", {}).get("task_id", ""),
		"purpose_id": authored_check.get("check_context", {}).get("purpose_id", ""),
		"required_tool_id": authored_check.get("check_context", {}).get("required_tool_id", ""),
		"origin_event_id": event_record.get("id", ""),
		"origin_check_id": authored_check.get("id", ""),
		"source_table_id": event_check.get("table_id", ""),
	}


static func _changed(context: Dictionary, key: String, value: String) -> Dictionary:
	var result := context.duplicate(true)
	result[key] = value
	return result


static func _owned_ability_check_bonus(check: Callable, neutral_record: Dictionary, renamed_record: Dictionary) -> void:
	var neutral_class: Dictionary = DataLoader.classes.get("fixture:ability_check_bonus_neutral_class", {})
	var renamed_class: Dictionary = DataLoader.classes.get("fixture:ability_check_bonus_renamed_class", {})
	var unskilled_class: Dictionary = DataLoader.classes.get("fixture:ability_check_bonus_unskilled_class", {})
	var neutral_feature: Dictionary = neutral_class.get("features_by_level", {}).get("1", [{}])[0].duplicate(true) if not neutral_class.is_empty() else {}
	var renamed_feature: Dictionary = renamed_class.get("features_by_level", {}).get("1", [{}])[0].duplicate(true) if not renamed_class.is_empty() else {}
	var unskilled_features: Array = unskilled_class.get("features_by_level", {}).get("1", []).duplicate(true) if not unskilled_class.is_empty() else []
	check.call(not neutral_feature.is_empty() and not renamed_feature.is_empty() and unskilled_features.size() == 2, "DataLoader accepts skilled and ability-only fixed/die check modifiers")
	if neutral_feature.is_empty() or renamed_feature.is_empty() or unskilled_features.size() != 2:
		return

	var neutral_owner := Character.new()
	neutral_owner.initialize("Pathfinder", "human", "wizard", AbilityScores.new())
	neutral_owner.character_id = "fixture:ability_check_neutral_owner"
	neutral_owner.inventory.add_item("fixture:surveyors_tools")
	var neutral_source_id := "fixture:pathfinder_source"
	neutral_feature["source_instance_id"] = neutral_source_id
	neutral_owner.features.append(neutral_feature)
	var neutral_pool := ResourcePoolRules.acquire(neutral_owner, neutral_feature, neutral_source_id)
	check.call(bool(neutral_pool.get("success", false)), "Neutral check feature owns its exact numeric source")
	if not neutral_pool.get("success", false):
		return

	var renamed_owner := Character.new()
	renamed_owner.initialize("Naturalist", "human", "wizard", AbilityScores.new())
	renamed_owner.character_id = "fixture:ability_check_renamed_owner"
	renamed_owner.inventory.add_item("fixture:field_guide")
	var renamed_source_id := "fixture:field_notes_source"
	renamed_feature["source_instance_id"] = renamed_source_id
	renamed_owner.features.append(renamed_feature)
	var renamed_pool := ResourcePoolRules.acquire(renamed_owner, renamed_feature, renamed_source_id)
	check.call(bool(renamed_pool.get("success", false)), "Renamed check feature owns its exact numeric source")
	if not renamed_pool.get("success", false):
		return
	var test_host := Node.new()
	var roll_counts := {"d20": 0, "d8": 0}
	var count_roll: Callable = func(details: Dictionary) -> void:
		if str(details.get("type", "")) != "single":
			return
		if int(details.get("sides", 0)) == 20:
			roll_counts["d20"] = int(roll_counts["d20"]) + 1
		elif int(details.get("sides", 0)) == 8:
			roll_counts["d8"] = int(roll_counts["d8"]) + 1
		elif int(details.get("sides", 0)) == 6:
			roll_counts["d6"] = int(roll_counts.get("d6", 0)) + 1
	Dice.dice_rolled.connect(count_roll)

	var neutral_check: Dictionary = neutral_record.get("check", {})
	var neutral_context := _authored_context(neutral_record)
	var neutral_result: Dictionary = {}
	for _attempt in 40:
		neutral_result = EventResolver.resolve_skill_check(neutral_owner, neutral_check, {}, neutral_context)
		if not bool(neutral_result.get("success", true)):
			break
	check.call(not neutral_result.is_empty() and not bool(neutral_result.get("success", true)), "Neutral fixture produces a rolled failed check for its optional source")
	if neutral_result.is_empty() or bool(neutral_result.get("success", true)):
		return
	var neutral_options := SpellDamageRolls.ability_check_numeric_bonus_options(neutral_owner, neutral_result)
	var neutral_d20_before := int(roll_counts["d20"])
	var neutral_d8_before := int(roll_counts["d8"])
	var neutral_option_count := neutral_options.size()
	var neutral_source_pool_before := int(neutral_owner.numeric_resource_pools[neutral_source_id].get("current", 0))
	var neutral_request := SpellDamageRolls.create_ability_check_numeric_bonus_request(neutral_owner, neutral_result, neutral_options, test_host)
	check.call(neutral_option_count == 1 and bool(neutral_request.get("success", false)), "Exact loaded neutral context offers its matching fixed source")
	var neutral_settlement := SpellDamageRolls.settle_ability_check_numeric_bonus(neutral_owner, neutral_request, neutral_source_id)
	var neutral_final: Dictionary = neutral_settlement.get("check_result", {})
	check.call(bool(neutral_settlement.get("success", false)) and int(neutral_final.get("total", -999)) == int(neutral_result.get("total", 0)) + 5 and int(neutral_final.get("natural_roll", -999)) == int(neutral_result.get("natural_roll", 0)) and int(neutral_final.get("modifier", -999)) == int(neutral_result.get("modifier", 0)) and int(neutral_final.get("dc", -999)) == int(neutral_result.get("dc", 0)), "Fixed check bonus changes only the captured total and final outcome")
	check.call(int(neutral_owner.numeric_resource_pools[neutral_source_id].get("current", 0)) == neutral_source_pool_before - 1 and bool(neutral_final.get("post_roll_bonus_cost_paid", false)), "Neutral pay-on-choice source spends exactly one use")
	check.call(int(roll_counts["d20"]) == neutral_d20_before and int(roll_counts["d8"]) == neutral_d8_before, "Fixed settlement rolls no extra check or bonus die")
	check.call(SpellDamageRolls.ability_check_numeric_bonus_options(neutral_owner, neutral_final).is_empty() and bool(SpellDamageRolls.settle_ability_check_numeric_bonus(neutral_owner, neutral_request, neutral_source_id).get("refused", false)), "Resolved fixed check cannot acquire another modifier or spend on replay")

	var renamed_check: Dictionary = renamed_record.get("check", {})
	var renamed_context := _authored_context(renamed_record)
	var saw_conversion := false
	var saw_remaining_failure := false
	for _attempt in 60:
		renamed_owner.numeric_resource_pools[renamed_source_id]["current"] = 3
		var rolled: Dictionary = EventResolver.resolve_skill_check(renamed_owner, renamed_check, {}, renamed_context)
		if bool(rolled.get("success", true)):
			continue
		var before_query_d20 := int(roll_counts["d20"])
		var before_query_d8 := int(roll_counts["d8"])
		var options := SpellDamageRolls.ability_check_numeric_bonus_options(renamed_owner, rolled)
		if options.size() != 1:
			continue
		check.call(int(roll_counts["d20"]) == before_query_d20 and int(roll_counts["d8"]) == before_query_d8, "Looking up an owned die option rolls nothing")
		var source_pool_before := int(renamed_owner.numeric_resource_pools[renamed_source_id].get("current", 0))
		var request := SpellDamageRolls.create_ability_check_numeric_bonus_request(renamed_owner, rolled, options, test_host)
		var before_answer_d20 := int(roll_counts["d20"])
		var before_answer_d8 := int(roll_counts["d8"])
		var settled := SpellDamageRolls.settle_ability_check_numeric_bonus(renamed_owner, request, renamed_source_id)
		var final_result: Dictionary = settled.get("check_result", {})
		if not bool(settled.get("success", false)):
			continue
		var converted := bool(final_result.get("success", false))
		var expected_spend := 2 if converted else 0
		var receipt: Dictionary = final_result.get("post_roll_bonus_die", {})
		check.call(int(final_result.get("total", -999)) == int(rolled.get("total", 0)) + int(receipt.get("total", 0)) and int(final_result.get("natural_roll", -999)) == int(rolled.get("natural_roll", 0)) and int(final_result.get("dc", -999)) == int(rolled.get("dc", 0)), "Renamed die adds to the original captured check without rerolling")
		check.call(int(roll_counts["d20"]) == before_answer_d20 and int(roll_counts["d8"]) == before_answer_d8 + 1, "Accepted renamed source rolls exactly one d8 and no new check")
		check.call(int(renamed_owner.numeric_resource_pools[renamed_source_id].get("current", 0)) == source_pool_before - expected_spend and bool(final_result.get("post_roll_bonus_cost_paid", false)) == converted, "Conditional die source pays two uses only when its captured failure converts")
		if converted:
			saw_conversion = true
		else:
			saw_remaining_failure = true
		if saw_conversion and saw_remaining_failure:
			break
	check.call(saw_conversion and saw_remaining_failure, "Renamed conditional die demonstrates both converted success and free remaining failure")

	var unskilled_record: Dictionary = DataLoader.get_event_check_record("fixture:unskilled_estimate_event", "estimate_distance_check")
	var unskilled_owner := Character.new()
	unskilled_owner.initialize("Estimator", "human", "wizard", AbilityScores.new())
	unskilled_owner.character_id = "fixture:unskilled_estimate_owner"
	var unskilled_source_ids := ["fixture:estimate_fixed_source", "fixture:estimate_die_source"]
	for feature_index in unskilled_features.size():
		var unskilled_feature: Dictionary = unskilled_features[feature_index]
		unskilled_feature["source_instance_id"] = str(unskilled_source_ids[feature_index])
		unskilled_owner.features.append(unskilled_feature)
		var acquired := ResourcePoolRules.acquire(unskilled_owner, unskilled_feature, str(unskilled_source_ids[feature_index]))
		check.call(bool(acquired.get("success", false)), "Ability-only bonus source %d owns its exact pool" % feature_index)
	var unskilled_context := _authored_context(unskilled_record)
	var unskilled_check: Dictionary = unskilled_record.get("check", {})
	var unskilled_roll: Dictionary = {}
	for _attempt in 400:
		unskilled_roll = EventResolver.resolve_skill_check(unskilled_owner, unskilled_check, {}, unskilled_context)
		if int(unskilled_roll.get("natural_roll", 0)) == 20:
			break
	var unskilled_before_bonus_d20 := int(roll_counts["d20"])
	check.call(str(unskilled_roll.get("check_context", {}).get("skill", "missing")) == "" and int(unskilled_roll.get("modifier", -999)) == unskilled_owner.get_skill_check_modifier("", "INT") and int(unskilled_roll.get("dc", 0)) == 25 and int(unskilled_roll.get("natural_roll", 0)) == 20 and not bool(unskilled_roll.get("success", true)), "Loaded context-aware ability-only check preserves the unskilled modifier and original failed result")
	var unskilled_options := SpellDamageRolls.ability_check_numeric_bonus_options(unskilled_owner, unskilled_roll)
	var fixed_unskilled_option: Dictionary = {}
	var die_unskilled_option: Dictionary = {}
	for option in unskilled_options:
		if str(option.get("source_instance_id", "")) == str(unskilled_source_ids[0]):
			fixed_unskilled_option = option
		elif str(option.get("source_instance_id", "")) == str(unskilled_source_ids[1]):
			die_unskilled_option = option
	check.call(unskilled_options.size() == 2 and int(roll_counts["d20"]) == unskilled_before_bonus_d20, "Ability-only context exposes its distinct fixed and die sources without another test")
	var fixed_request := SpellDamageRolls.create_ability_check_numeric_bonus_request(unskilled_owner, unskilled_roll, unskilled_options, test_host)
	var fixed_unskilled := SpellDamageRolls.settle_ability_check_numeric_bonus(unskilled_owner, fixed_request, str(fixed_unskilled_option.get("source_instance_id", "")))
	var fixed_unskilled_result: Dictionary = fixed_unskilled.get("check_result", {})
	check.call(bool(fixed_unskilled.get("success", false)) and int(fixed_unskilled_result.get("total", -999)) == int(unskilled_roll.get("total", 0)) + 4 and int(fixed_unskilled_result.get("natural_roll", -999)) == 20 and int(fixed_unskilled_result.get("modifier", -999)) == int(unskilled_roll.get("modifier", 0)) and int(fixed_unskilled_result.get("dc", 0)) == 25 and not bool(fixed_unskilled_result.get("success", true)), "Ability-only fixed source changes only the captured total and keeps its final failure")
	var unskilled_die_roll: Dictionary = {}
	for _attempt in 400:
		unskilled_die_roll = EventResolver.resolve_skill_check(unskilled_owner, unskilled_check, {}, unskilled_context)
		if int(unskilled_die_roll.get("natural_roll", 0)) == 20:
			break
	var die_options := SpellDamageRolls.ability_check_numeric_bonus_options(unskilled_owner, unskilled_die_roll)
	var die_option: Dictionary = {}
	for option in die_options:
		if str(option.get("source_instance_id", "")) == str(unskilled_source_ids[1]):
			die_option = option
	var unskilled_die_before := int(roll_counts.get("d6", 0))
	var die_request := SpellDamageRolls.create_ability_check_numeric_bonus_request(unskilled_owner, unskilled_die_roll, die_options, test_host)
	var die_settlement := SpellDamageRolls.settle_ability_check_numeric_bonus(unskilled_owner, die_request, str(die_option.get("source_instance_id", "")))
	var die_result: Dictionary = die_settlement.get("check_result", {})
	var die_receipt: Dictionary = die_result.get("post_roll_bonus_die", {})
	check.call(int(unskilled_die_roll.get("natural_roll", 0)) == 20 and bool(die_settlement.get("success", false)) and int(die_result.get("total", -999)) == int(unskilled_die_roll.get("total", 0)) + int(die_receipt.get("total", 0)) and int(die_result.get("modifier", -999)) == int(unskilled_die_roll.get("modifier", 0)) and int(die_result.get("dc", 0)) == 25 and int(roll_counts.get("d6", 0)) == unskilled_die_before + 1, "Ability-only die source rolls once and settles against the original unskilled check")
	if Dice.dice_rolled.is_connected(count_roll):
		Dice.dice_rolled.disconnect(count_roll)

	var stale_result: Dictionary = {}
	for _attempt in 40:
		stale_result = EventResolver.resolve_skill_check(neutral_owner, neutral_check, {}, neutral_context)
		if not bool(stale_result.get("success", true)):
			break
	if not stale_result.is_empty() and not bool(stale_result.get("success", true)):
		var stale_options := SpellDamageRolls.ability_check_numeric_bonus_options(neutral_owner, stale_result)
		neutral_owner.numeric_resource_pools[neutral_source_id]["current"] = 3
		var stale_pool_before := int(neutral_owner.numeric_resource_pools[neutral_source_id].get("current", 0))
		var stale_request := SpellDamageRolls.create_ability_check_numeric_bonus_request(neutral_owner, stale_result, stale_options, test_host)
		neutral_owner.features.clear()
		var stale_settlement := SpellDamageRolls.settle_ability_check_numeric_bonus(neutral_owner, stale_request, neutral_source_id)
		var stale_final: Dictionary = stale_settlement.get("check_result", {})
		check.call(bool(stale_settlement.get("success", false)) and bool(stale_settlement.get("source_changed", false)) and int(stale_final.get("total", -999)) == int(stale_result.get("total", 0)) and int(neutral_owner.numeric_resource_pools[neutral_source_id].get("current", 0)) == stale_pool_before, "Removed offered source falls back to the original check without cost")
	await _ability_check_dialog_repopup(check, neutral_feature, neutral_record)
	test_host.free()


static func _owned_ability_check_rerolls(check: Callable, neutral_record: Dictionary, renamed_record: Dictionary) -> void:
	var neutral_class: Dictionary = DataLoader.classes.get("fixture:ability_check_bonus_neutral_class", {})
	var renamed_class: Dictionary = DataLoader.classes.get("fixture:ability_check_bonus_renamed_class", {})
	var neutral_features: Array = neutral_class.get("features_by_level", {}).get("1", []).duplicate(true)
	var renamed_features: Array = renamed_class.get("features_by_level", {}).get("1", []).duplicate(true)
	check.call(neutral_features.size() == 2 and renamed_features.size() == 2, "Loaded neutral and renamed classes retain separate post-roll reroll sources beside existing bonus effects")
	if neutral_features.size() != 2 or renamed_features.size() != 2:
		return
	var neutral_owner := Character.new()
	neutral_owner.initialize("Surveyor Reroll", "human", "wizard", AbilityScores.new())
	neutral_owner.character_id = "fixture:s105_neutral_owner"
	neutral_owner.inventory.add_item("fixture:surveyors_tools")
	neutral_owner.conditions["guidance"] = 1
	neutral_owner.guidance_skill = "Investigation"
	var neutral_bonus_source := "fixture:s105_neutral_bonus_source"
	var neutral_reroll_source := "fixture:s105_neutral_reroll_source"
	neutral_features[0]["source_instance_id"] = neutral_bonus_source
	neutral_features[1]["source_instance_id"] = neutral_reroll_source
	neutral_owner.features.append_array(neutral_features)
	var neutral_bonus_pool := ResourcePoolRules.acquire(neutral_owner, neutral_features[0], neutral_bonus_source)
	var neutral_reroll_pool := ResourcePoolRules.acquire(neutral_owner, neutral_features[1], neutral_reroll_source)
	check.call(bool(neutral_bonus_pool.get("success", false)) and bool(neutral_reroll_pool.get("success", false)), "Neutral overlapping bonus and reroll features each own a separate exact pool")
	if not bool(neutral_bonus_pool.get("success", false)) or not bool(neutral_reroll_pool.get("success", false)):
		return
	var renamed_owner := Character.new()
	renamed_owner.initialize("Naturalist Reroll", "human", "wizard", AbilityScores.new())
	renamed_owner.character_id = "fixture:s105_renamed_owner"
	renamed_owner.inventory.add_item("fixture:field_guide")
	renamed_owner.conditions["guidance"] = 1
	renamed_owner.guidance_skill = "Nature"
	var renamed_bonus_source := "fixture:s105_renamed_bonus_source"
	var renamed_reroll_source := "fixture:s105_renamed_reroll_source"
	renamed_features[0]["source_instance_id"] = renamed_bonus_source
	renamed_features[1]["source_instance_id"] = renamed_reroll_source
	renamed_owner.features.append_array(renamed_features)
	renamed_owner.features.append({"id": "fixture:s105_advantage", "passive_effects": [{"type": "ability_check_advantage", "ability": "WIS"}]})
	var renamed_bonus_pool := ResourcePoolRules.acquire(renamed_owner, renamed_features[0], renamed_bonus_source)
	var renamed_reroll_pool := ResourcePoolRules.acquire(renamed_owner, renamed_features[1], renamed_reroll_source)
	check.call(bool(renamed_bonus_pool.get("success", false)) and bool(renamed_reroll_pool.get("success", false)), "Renamed source and unrelated numeric bonus source retain independent pools")
	if not bool(renamed_bonus_pool.get("success", false)) or not bool(renamed_reroll_pool.get("success", false)):
		return
	var counts := {"d20": 0, "d4": 0}
	var count_dice: Callable = func(details: Dictionary) -> void:
		var sides := int(details.get("sides", 0))
		var rolls: Variant = details.get("rolls", [])
		var count: int = rolls.size() if rolls is Array else 1
		if sides == 20:
			counts["d20"] = int(counts["d20"]) + count
		elif sides == 4:
			counts["d4"] = int(counts["d4"]) + count
	Dice.dice_rolled.connect(count_dice)
	var host := Node.new()
	var neutral_check: Dictionary = neutral_record.get("check", {})
	var neutral_context := _authored_context(neutral_record)
	var worse_settlement: Dictionary = {}
	var worse_captured: Dictionary = {}
	for attempt in range(1, 161):
		seed(10500 + attempt)
		counts["d20"] = 0
		counts["d4"] = 0
		var captured: Dictionary = EventResolver.resolve_skill_check(neutral_owner, neutral_check, {}, neutral_context)
		if bool(captured.get("success", true)):
			continue
		var options := SpellDamageRolls.ability_check_post_roll_options(neutral_owner, captured)
		var numeric_option := false
		var reroll_option := false
		for option in options:
			numeric_option = numeric_option or str(option.get("operation_kind", "")) == "numeric_bonus"
			reroll_option = reroll_option or str(option.get("operation_kind", "")) == "mandatory_reroll"
		if not numeric_option or not reroll_option:
			continue
		var pool_before := int(neutral_owner.numeric_resource_pools[neutral_reroll_source].get("current", 0))
		var bonus_pool_before := int(neutral_owner.numeric_resource_pools[neutral_bonus_source].get("current", 0))
		var request := SpellDamageRolls.create_ability_check_post_roll_request(neutral_owner, captured, host)
		var final: Dictionary = {}
		for option in request.get("options", []):
			if str(option.get("operation_kind", "")) == "mandatory_reroll":
				var settlement := SpellDamageRolls.settle_ability_check_post_roll(neutral_owner, request, str(option.get("offer_id", "")))
				final = settlement.get("check_result", {})
				break
		if not final.is_empty() and int(final.get("total", 0)) < int(captured.get("total", 0)):
			worse_settlement = {"final": final, "d20": int(counts["d20"]), "d4": int(counts["d4"]), "reroll_pool_delta": pool_before - int(neutral_owner.numeric_resource_pools[neutral_reroll_source].get("current", 0)), "bonus_pool_delta": bonus_pool_before - int(neutral_owner.numeric_resource_pools[neutral_bonus_source].get("current", 0)), "captured": captured}
			worse_captured = captured
			break
		neutral_owner.numeric_resource_pools[neutral_reroll_source]["current"] = 2
		neutral_owner.numeric_resource_pools[neutral_bonus_source]["current"] = 3
	check.call(not worse_settlement.is_empty(), "A mandatory natural-only reroll can keep a worse new result in the production settlement path")
	if not worse_settlement.is_empty():
		var worse_final: Dictionary = worse_settlement["final"]
		check.call(int(worse_settlement["d20"]) == 2 and int(worse_settlement["d4"]) == 1 and int(worse_final.get("total", 0)) < int(worse_captured.get("total", 0)) and int(worse_final.get("raw_natural_roll", 0)) == int(worse_final.get("roll_details", {}).get("total", -1)), "Natural-only answer rolls one replacement d20, keeps original Guidance, and uses the new worse natural")
		check.call(int(worse_settlement["reroll_pool_delta"]) == 1 and int(worse_settlement["bonus_pool_delta"]) == 0 and SpellDamageRolls.ability_check_post_roll_options(neutral_owner, worse_final).is_empty(), "One overlapping choice spends only the selected reroll source and opens no second modifier pass")
	var renamed_check: Dictionary = renamed_record.get("check", {})
	var renamed_context := _authored_context(renamed_record)
	var conversion_results := {"failure_to_success": {}, "success_to_failure": {}}
	for attempt in range(1, 241):
		if not conversion_results["failure_to_success"].is_empty() and not conversion_results["success_to_failure"].is_empty():
			break
		seed(20500 + attempt)
		counts["d20"] = 0
		counts["d4"] = 0
		renamed_owner.numeric_resource_pools[renamed_reroll_source]["current"] = 2
		renamed_owner.numeric_resource_pools[renamed_bonus_source]["current"] = 3
		var captured: Dictionary = EventResolver.resolve_skill_check(renamed_owner, renamed_check, {}, renamed_context)
		var direction := "failure_to_success" if not bool(captured.get("success", false)) else "success_to_failure"
		if not conversion_results[direction].is_empty():
			continue
		var options := SpellDamageRolls.ability_check_post_roll_options(renamed_owner, captured)
		var request := SpellDamageRolls.create_ability_check_post_roll_request(renamed_owner, captured, host)
		var final: Dictionary = {}
		for option in request.get("options", []):
			if str(option.get("operation_kind", "")) == "mandatory_reroll":
				var settlement := SpellDamageRolls.settle_ability_check_post_roll(renamed_owner, request, str(option.get("offer_id", "")))
				final = settlement.get("check_result", {})
				break
		if final.is_empty() or bool(final.get("success", false)) == bool(captured.get("success", false)):
			renamed_owner.numeric_resource_pools[renamed_reroll_source]["current"] = 2
			renamed_owner.numeric_resource_pools[renamed_bonus_source]["current"] = 3
			continue
		conversion_results[direction] = {"old": captured, "new": final, "d20": int(counts["d20"]), "d4": int(counts["d4"]), "pool": int(renamed_owner.numeric_resource_pools[renamed_reroll_source].get("current", 0))}
	check.call(not conversion_results["failure_to_success"].is_empty() and not conversion_results["success_to_failure"].is_empty(), "Renamed eligibility allows both a failed test becoming success and a successful test becoming failure")
	for direction in ["failure_to_success", "success_to_failure"]:
		var transition: Dictionary = conversion_results[direction]
		if transition.is_empty():
			continue
		var old_result: Dictionary = transition["old"]
		var new_result: Dictionary = transition["new"]
		var new_guidance := int(new_result.get("check_bonus_dice", [{}])[0].get("value", 0)) if not new_result.get("check_bonus_dice", []).is_empty() else 0
		var old_guidance := int(old_result.get("check_bonus_dice", [{}])[0].get("value", 0)) if not old_result.get("check_bonus_dice", []).is_empty() else 0
		check.call(str(old_result.get("roll_mode", "")) == "advantage" and str(new_result.get("original_roll_mode", "")) == "advantage" and str(new_result.get("reroll_roll_mode", "")) == "advantage" and int(transition["d20"]) == 4 and int(transition["d4"]) == 2 and int(new_result.get("dc", -1)) == int(old_result.get("dc", -2)) and new_result.get("check_context", {}) == old_result.get("check_context", {}) and int(new_result.get("guidance_bonus", -1)) == new_guidance and int(new_result.get("total", -1)) == int(new_result.get("natural_roll", 0)) + int(new_result.get("modifier", 0)) + new_guidance and int(new_result.get("post_roll_reroll", {}).get("original", {}).get("bonus_dice", [{}])[0].get("value", -1)) == old_guidance, "Whole-test Advantage rerolls captured d20 and Guidance once, preserves the old die receipt, and updates its final displayed value")
	var synthetic_owner := Character.new()
	synthetic_owner.initialize("Floor Check", "human", "wizard", AbilityScores.new())
	var floor_capture := {"roll_mode": "normal", "raw_natural_roll": 5, "roll_floor_minimum": 1, "total_floor_minimum": 18, "total_floor_active": true, "roll_details": {"total": 5, "rolls": [5], "kept": [true]}, "base_modifier": -30, "modifier": -30, "dc": 20, "check_bonus_dice": [{"source": "guidance", "label": "Guidance", "sides": 4, "value": 1, "roll": {"total": 1, "rolls": [1], "kept": [true]}, "applied_before_total_floor": true}, {"source": "bardic_inspiration", "label": "Bardic Inspiration", "sides": 6, "value": 3, "roll": {"total": 3, "rolls": [3], "kept": [true]}, "applied_before_total_floor": false}]}
	seed(30500)
	var floor_reroll := EventResolver.reroll_captured_skill_check(synthetic_owner, floor_capture, "natural_only", "keep")
	var negative_capture := {"roll_mode": "normal", "raw_natural_roll": 5, "roll_floor_minimum": 1, "total_floor_minimum": 0, "total_floor_active": false, "roll_details": {"total": 5, "rolls": [5], "kept": [true]}, "base_modifier": -30, "modifier": -30, "dc": 20, "check_bonus_dice": []}
	seed(30501)
	var negative_reroll := EventResolver.reroll_captured_skill_check(synthetic_owner, negative_capture, "natural_only", "keep")
	check.call(int(floor_reroll.get("total", -1)) == 21 and int(floor_reroll.get("guidance_bonus", -1)) == 1 and int(floor_reroll.get("inspiration_bonus", -1)) == 3 and int(negative_reroll.get("total", 0)) < 0, "Captured total-floor stage remains before native Inspiration, and an absent floor does not clamp a negative check")
	var advantage_capture: Dictionary = floor_capture.duplicate(true)
	advantage_capture["roll_mode"] = "advantage"
	advantage_capture["advantage"] = true
	advantage_capture["disadvantage"] = false
	advantage_capture["familiar_help"] = true
	advantage_capture["raw_natural_roll"] = 14
	advantage_capture["roll_details"] = {"total": 14, "rolls": [14, 10], "kept": [true, false], "mode": "advantage"}
	var before_natural_only_d20 := int(counts["d20"])
	seed(30502)
	var natural_only_from_advantage := EventResolver.reroll_captured_skill_check(synthetic_owner, advantage_capture, "natural_only", "keep")
	check.call(int(counts["d20"]) == before_natural_only_d20 + 1 and str(natural_only_from_advantage.get("roll_mode", "")) == "normal" and not bool(natural_only_from_advantage.get("advantage", true)) and bool(natural_only_from_advantage.get("original_advantage", false)) and bool(natural_only_from_advantage.get("original_familiar_help", false)) and not bool(natural_only_from_advantage.get("familiar_help", true)), "Natural-only reroll records the captured Advantage/Familiar Help but does not claim they applied to its new single d20")
	var malformed_receipt: Dictionary = floor_capture.duplicate(true)
	malformed_receipt["check_bonus_dice"] = [{"source": "bad", "sides": 3, "value": 2, "roll": {"total": 2, "rolls": [2], "kept": [true]}}]
	var before_bad_receipt_d20 := int(counts["d20"])
	var before_bad_receipt_d4 := int(counts["d4"])
	check.call(not EventResolver.can_reroll_captured_skill_check(malformed_receipt, "natural_only", "reroll") and EventResolver.reroll_captured_skill_check(synthetic_owner, malformed_receipt, "natural_only", "reroll").is_empty() and int(counts["d20"]) == before_bad_receipt_d20 and int(counts["d4"]) == before_bad_receipt_d4, "Malformed captured bonus dice refuse in pure preflight before spending or rolling")
	if Dice.dice_rolled.is_connected(count_dice):
		Dice.dice_rolled.disconnect(count_dice)
	host.free()


static func _ability_check_dialog_repopup(check: Callable, feature_template: Dictionary, event_check: Dictionary, reroll_feature_template: Dictionary = {}) -> void:
	var previous_test_mode := GameManager.test_mode
	GameManager.test_mode = false
	var scene := load("res://scenes/ui/event_dialog.tscn") as PackedScene
	var tree := Engine.get_main_loop() as SceneTree
	if scene == null or tree == null:
		check.call(false, "EventDialog production scene is available for re-popup lifecycle check")
		GameManager.test_mode = previous_test_mode
		return
	await tree.process_frame
	var first_owner := _dialog_check_owner(feature_template, "fixture:check_dialog_first_owner", "fixture:dialog_first_source")
	var second_owner := _dialog_check_owner(feature_template, "fixture:check_dialog_second_owner", "fixture:dialog_second_source")
	if not reroll_feature_template.is_empty():
		for pair in [[first_owner, "fixture:dialog_first_reroll_source"], [second_owner, "fixture:dialog_second_reroll_source"]]:
			var pair_owner: Character = pair[0]
			var pair_source := str(pair[1])
			var pair_feature: Dictionary = reroll_feature_template.duplicate(true)
			pair_feature["source_instance_id"] = pair_source
			pair_owner.features.append(pair_feature)
			ResourcePoolRules.acquire(pair_owner, pair_feature, pair_source)
	var dialog := scene.instantiate() as EventDialog
	tree.root.add_child(dialog)
	var first_event: Dictionary = event_check.get("event", {})
	var first_menu_ready := await _roll_until_bonus_menu(dialog, first_owner, first_event, tree)
	var first_source := "fixture:dialog_first_source"
	var first_pool_before := int(first_owner.numeric_resource_pools.get(first_source, {}).get("current", -1))
	var old_request_id := str(SpellDamageRolls._active_request_id_by_caster.get(str(first_owner.get_instance_id()), ""))
	var old_gold := first_owner.inventory.gold
	var old_menu: PopupMenu = dialog._active_ability_bonus_menu
	check.call(first_menu_ready and not old_request_id.is_empty() and is_instance_valid(old_menu) and old_menu.visible, "Actual EventDialog roll opens the owned-source chooser before its consequences")
	if not first_menu_ready or old_request_id.is_empty():
		dialog.queue_free()
		await tree.process_frame
		await tree.process_frame
		GameManager.test_mode = previous_test_mode
		return
	var unrelated_event_record: Dictionary = DataLoader.get_event_check_record("fixture:unrelated_survey_event", "mark_boundary_check")
	dialog.popup_event(first_owner, unrelated_event_record.get("event", {}))
	await tree.process_frame
	check.call((not is_instance_valid(old_menu) or not old_menu.visible) and dialog.last_skill_check_result.is_empty() and first_owner.inventory.gold == old_gold and int(first_owner.numeric_resource_pools[first_source].get("current", 0)) == first_pool_before and str(SpellDamageRolls._active_request_id_by_caster.get(str(first_owner.get_instance_id()), "")).is_empty(), "Same-actor re-popup closes and cancels the old chooser without resolving old consequences")
	var replacement_event: Dictionary = event_check.get("event", {})
	var same_actor_new_menu := await _roll_until_bonus_menu(dialog, first_owner, replacement_event, tree)
	var same_actor_new_id := str(SpellDamageRolls._active_request_id_by_caster.get(str(first_owner.get_instance_id()), ""))
	var same_actor_pool_before := int(first_owner.numeric_resource_pools[first_source].get("current", 0))
	var same_actor_reroll_pool_before := int(first_owner.numeric_resource_pools.get("fixture:dialog_first_reroll_source", {}).get("current", -1))
	var first_owner_gold_after_new_menu := first_owner.inventory.gold
	var stale_answer_dice := {"count": 0}
	var stale_answer_watcher: Callable = func(details: Dictionary) -> void:
		var rolls: Variant = details.get("rolls", [])
		stale_answer_dice["count"] = int(stale_answer_dice["count"]) + int(details.get("count", rolls.size() if rolls is Array and not rolls.is_empty() else 1))
	Dice.dice_rolled.connect(stale_answer_watcher)
	var stale_answer_count_before := int(stale_answer_dice["count"])
	var old_answer := SpellDamageRolls.settle_ability_check_post_roll(first_owner, {"ability_check_post_roll_request": {"request_id": old_request_id}}, "")
	var wrong_actor_pool_before := int(second_owner.numeric_resource_pools["fixture:dialog_second_source"].get("current", 0))
	var wrong_actor_reroll_pool_before := int(second_owner.numeric_resource_pools.get("fixture:dialog_second_reroll_source", {}).get("current", -1))
	var wrong_actor_gold_before := second_owner.inventory.gold
	var wrong_actor_answer := SpellDamageRolls.settle_ability_check_post_roll(second_owner, {"ability_check_post_roll_request": {"request_id": same_actor_new_id}}, "")
	var stale_answer_no_effects := int(stale_answer_dice["count"]) == stale_answer_count_before and int(first_owner.numeric_resource_pools[first_source].get("current", 0)) == same_actor_pool_before and int(first_owner.numeric_resource_pools.get("fixture:dialog_first_reroll_source", {}).get("current", -1)) == same_actor_reroll_pool_before and first_owner.inventory.gold == first_owner_gold_after_new_menu and int(second_owner.numeric_resource_pools["fixture:dialog_second_source"].get("current", 0)) == wrong_actor_pool_before and int(second_owner.numeric_resource_pools.get("fixture:dialog_second_reroll_source", {}).get("current", -1)) == wrong_actor_reroll_pool_before and second_owner.inventory.gold == wrong_actor_gold_before
	check.call(same_actor_new_menu and not same_actor_new_id.is_empty() and bool(old_answer.get("refused", false)) and bool(wrong_actor_answer.get("refused", false)) and str(SpellDamageRolls._active_request_id_by_caster.get(str(first_owner.get_instance_id()), "")) == same_actor_new_id and stale_answer_no_effects, "Old and wrong-actor answers are refused against the current post-roll request without dice, payment, consequence or request loss")
	if Dice.dice_rolled.is_connected(stale_answer_watcher):
		Dice.dice_rolled.disconnect(stale_answer_watcher)
	if not same_actor_new_menu or same_actor_new_id.is_empty():
		dialog.queue_free()
		await tree.process_frame
		await tree.process_frame
		GameManager.test_mode = previous_test_mode
		return
	var same_actor_menu: PopupMenu = dialog._active_ability_bonus_menu
	var same_actor_menu_answered := is_instance_valid(same_actor_menu) and same_actor_menu.visible
	if same_actor_menu_answered:
		same_actor_menu.id_pressed.emit(same_actor_menu.get_item_id(0))
	for _frame in 240:
		if dialog.btn_close.visible and not dialog.last_skill_check_result.is_empty():
			break
		await tree.process_frame
	check.call(same_actor_menu_answered and str(SpellDamageRolls._active_request_id_by_caster.get(str(first_owner.get_instance_id()), "")).is_empty() and first_owner.inventory.gold == first_owner_gold_after_new_menu + 1 and int(first_owner.numeric_resource_pools[first_source].get("current", 0)) == same_actor_pool_before, "The current chooser remains answerable and its real decline settles only its captured result")
	var second_menu_ready := await _roll_until_bonus_menu(dialog, second_owner, replacement_event, tree)
	var second_request_id := str(SpellDamageRolls._active_request_id_by_caster.get(str(second_owner.get_instance_id()), ""))
	var second_menu: PopupMenu = dialog._active_ability_bonus_menu
	var second_pool_before := int(second_owner.numeric_resource_pools.get("fixture:dialog_second_source", {}).get("current", -1))
	var second_owner_gold_before_decline := second_owner.inventory.gold
	check.call(second_menu_ready and not second_request_id.is_empty() and str(SpellDamageRolls._active_request_id_by_caster.get(str(first_owner.get_instance_id()), "")).is_empty() and first_owner.inventory.gold == first_owner_gold_after_new_menu + 1, "Re-popup to another actor cancels the old roll instead of overwriting the new dialog")
	if second_menu_ready and is_instance_valid(second_menu):
		second_menu.id_pressed.emit(0)
	for _frame in 60:
		if not dialog.last_skill_check_result.is_empty() and str(SpellDamageRolls._active_request_id_by_caster.get(str(second_owner.get_instance_id()), "")).is_empty():
			break
		await tree.process_frame
	check.call(not dialog.last_skill_check_result.is_empty() and str(dialog.last_skill_check_result.get("actor_id", "")) == second_owner.character_id and second_owner.inventory.gold == second_owner_gold_before_decline + 1 and int(second_owner.numeric_resource_pools["fixture:dialog_second_source"].get("current", 0)) == second_pool_before, "Replacement actor can decline normally and resolves exactly its own captured consequence once")
	dialog.queue_free()
	await tree.process_frame
	await tree.process_frame
	GameManager.test_mode = previous_test_mode


static func _dialog_check_owner(feature_template: Dictionary, actor_id: String, source_id: String) -> Character:
	var owner := Character.new()
	owner.initialize("Check Dialog Owner", "human", "wizard", AbilityScores.new())
	owner.character_id = actor_id
	var feature: Dictionary = feature_template.duplicate(true)
	feature["source_instance_id"] = source_id
	owner.features.append(feature)
	ResourcePoolRules.acquire(owner, feature, source_id)
	return owner


static func _optional_filters(check: Callable) -> void:
	var effects: Array[Dictionary] = [
		{"type": "ability_check_roll_mode", "id": "broad_mode", "domain": "event_skill_check", "ability": "INT", "skill": "Investigation", "mode": "advantage"},
		{"type": "ability_check_roll_mode_policy", "id": "broad_policy", "domain": "event_skill_check", "ability": "INT", "mode": "disadvantage", "operation": "prohibit"},
		{"type": "ability_check_numeric_bonus", "id": "broad_bonus", "domain": "event_skill_check", "ability": "INT", "amount": 3, "cost": 1},
		{"type": "ability_check_mandatory_reroll", "id": "broad_reroll", "domain": "event_skill_check", "ability": "INT", "eligible_outcomes": ["failure"], "reroll_mode": "natural_only", "bonus_dice_policy": "keep", "cost": 1},
	]
	var context := {"task_id": "read_map", "purpose_id": "find_exit", "origin_event_id": "fixture:event", "origin_check_id": "check_map"}
	for effect in effects:
		check.call(ClassFeature.passive_effect_content_error(effect).is_empty() and EventResolver.ability_check_context_matches(effect, {}), "Omitted filters validate and leave context unrestricted: " + str(effect.type))
		for field in ["task_id", "purpose_id", "source_event_id", "source_check_id"]:
			var fact: String = "origin_event_id" if field == "source_event_id" else "origin_check_id" if field == "source_check_id" else field
			var restricted := effect.duplicate(true)
			restricted[field] = context[fact]
			check.call(ClassFeature.passive_effect_content_error(restricted).is_empty() and EventResolver.ability_check_context_matches(restricted, context) and not EventResolver.ability_check_context_matches(restricted, {}) and not EventResolver.ability_check_context_matches(restricted, {fact: "other"}), "One declared filter matches only its represented fact: %s/%s" % [effect.type, field])
			for invalid in ["", " ", null, 7, [], {}]:
				restricted[field] = invalid
				check.call(not ClassFeature.passive_effect_content_error(restricted).is_empty() and not EventResolver.ability_check_context_matches(restricted, context), "Malformed declared filter refuses: %s/%s/%s" % [effect.type, field, str(invalid)])
		var combined := effect.duplicate(true)
		combined.merge({"task_id": "read_map", "purpose_id": "find_exit", "source_event_id": "fixture:event", "source_check_id": "check_map"})
		check.call(EventResolver.ability_check_context_matches(combined, context) and not EventResolver.ability_check_context_matches(combined, _changed(context, "purpose_id", "other")), "Declared filters combine rather than override one another: " + str(effect.type))


static func _roll_until_bonus_menu(dialog: EventDialog, owner: Character, event_record: Dictionary, tree: SceneTree) -> bool:
	for _attempt in 120:
		dialog.popup_event(owner, event_record)
		seed(_attempt + 31415)
		dialog.btn_roll.pressed.emit()
		for _frame in 45:
			if is_instance_valid(dialog._active_ability_bonus_menu) and dialog._active_ability_bonus_menu.visible:
				return true
			if not dialog.last_skill_check_result.is_empty():
				break
			await tree.process_frame
	return false
