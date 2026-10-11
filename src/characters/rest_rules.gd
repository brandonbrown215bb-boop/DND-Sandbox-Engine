class_name RestRules
extends RefCounted

const SHORT_REST_SECONDS := 3600
const LONG_REST_SECONDS := 28800
const SUPPORTED_REST_TYPES := ["short_rest", "long_rest"]
const SUPPORTED_TRIGGERS := ["short_rest_completed"]
const SUPPORTED_BUDGET_FORMULAS := ["half_class_level_ceil", "class_level", "flat"]

static var _active_rest_choice_modal: Control = null
static var _active_recovery_modal: Control = null
static var _active_recovery_window: Dictionary = {}
static var _pending_recovery_queue: Array[Dictionary] = []
static var _pending_recovery_results: Array[Dictionary] = []
static var _pending_recovery_host: Node = null
static var _pending_recovery_finished: Callable = Callable()
static var _pending_rest_event: Dictionary = {}
static var _window_epoch: int = 0
static var _next_event_serial: int = 0


static func is_rest_window_open() -> bool:
	if _active_rest_choice_modal != null and is_instance_valid(_active_rest_choice_modal):
		return true
	if _active_recovery_modal != null and is_instance_valid(_active_recovery_modal):
		return true
	if not _active_recovery_window.is_empty() and not bool(_active_recovery_window.get("settled", true)):
		return true
	return false


static func get_active_rest_choice_modal() -> Control:
	if _active_rest_choice_modal != null and is_instance_valid(_active_rest_choice_modal):
		return _active_rest_choice_modal
	return null


static func get_active_recovery_modal() -> Control:
	if _active_recovery_modal != null and is_instance_valid(_active_recovery_modal):
		return _active_recovery_modal
	return null


static func get_active_recovery_window() -> Dictionary:
	if _active_recovery_window.is_empty():
		return {}
	return _active_recovery_window.duplicate(false)


static func reset_windows() -> void:
	if _active_rest_choice_modal != null and is_instance_valid(_active_rest_choice_modal):
		_active_rest_choice_modal.queue_free()
	_active_rest_choice_modal = null
	if _active_recovery_modal != null and is_instance_valid(_active_recovery_modal):
		_active_recovery_modal.queue_free()
	_active_recovery_modal = null
	_active_recovery_window.clear()
	_pending_recovery_queue.clear()
	_pending_recovery_results.clear()
	_pending_recovery_host = null
	_pending_recovery_finished = Callable()
	_pending_rest_event.clear()


static func eligible_participants(candidates: Array) -> Array[Character]:
	var result: Array[Character] = []
	for entry in candidates:
		if not (entry is Character):
			continue
		var c: Character = entry
		if c.is_dead() or c.current_hp <= 0:
			continue
		if c.class_id in ["familiar", "steed"]:
			continue
		if c not in result:
			result.append(c)
	return result


static func can_complete_rest(rest_type: String, participants: Array, context: Dictionary = {}) -> Dictionary:
	if rest_type not in SUPPORTED_REST_TYPES:
		return {"allowed": false, "reason": "unsupported_rest_type", "message": "Unsupported rest type."}
	if GameManager != null and GameManager.current_state == GameManager.GameState.COMBAT and not bool(context.get("allow_in_test", false)):
		return {"allowed": false, "reason": "combat_active", "message": "Cannot rest during active combat."}
	if context.get("local_view", null) != null:
		return {"allowed": false, "reason": "dungeon_local_room_active", "message": "Return to the entrance before resting."}
	if bool(context.get("companion_roster_open", false)):
		return {"allowed": false, "reason": "companion_roster_open", "message": "Close the companion roster before resting."}
	if is_rest_window_open() and not bool(context.get("ignore_open_window", false)):
		return {"allowed": false, "reason": "rest_window_open", "message": "A rest decision is already in progress."}
	var living := eligible_participants(participants)
	if living.is_empty():
		return {"allowed": false, "reason": "no_living_participants", "message": "No conscious party members can take a rest."}
	return {"allowed": true, "reason": "", "participants": living}


static func open_rest_choice_dialog(host_parent: Node, on_selected: Callable, context: Dictionary = {}) -> Dictionary:
	if host_parent == null or not is_instance_valid(host_parent):
		return {"opened": false, "reason": "invalid_host"}
	if bool(context.get("companion_roster_open", false)):
		return {"opened": false, "reason": "companion_roster_open"}
	if context.get("local_view", null) != null:
		return {"opened": false, "reason": "dungeon_local_room_active"}
	if is_rest_window_open():
		return {"opened": false, "reason": "rest_window_open"}

	var overlay := ColorRect.new()
	overlay.name = "RestChoiceModalOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "RestChoicePanel"
	panel.custom_minimum_size = Vector2(420, 220)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "Make Camp — Choose Rest"
	title.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "SubtitleLabel"
	subtitle.text = "Short Rest advances campaign time by 1 hour and triggers short-rest recovery.\nLong Rest advances campaign time by 8 hours and restores full HP and spell slots."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(subtitle)

	var btn_short := Button.new()
	btn_short.name = "BtnShortRest"
	btn_short.text = "Short Rest (1 Hour)"
	vbox.add_child(btn_short)

	var btn_long := Button.new()
	btn_long.name = "BtnLongRest"
	btn_long.text = "Long Rest (8 Hours)"
	vbox.add_child(btn_long)

	var btn_cancel := Button.new()
	btn_cancel.name = "BtnCancelRest"
	btn_cancel.text = "Cancel"
	vbox.add_child(btn_cancel)

	overlay.set_meta("btn_short_rest", btn_short)
	overlay.set_meta("btn_long_rest", btn_long)
	overlay.set_meta("btn_cancel", btn_cancel)

	_active_rest_choice_modal = overlay
	host_parent.add_child(overlay)

	var settle_choice := func(choice: String) -> void:
		if _active_rest_choice_modal == overlay:
			_active_rest_choice_modal = null
		if is_instance_valid(overlay):
			overlay.queue_free()
		if on_selected.is_valid():
			on_selected.call(choice)

	btn_short.pressed.connect(func(): settle_choice.call("short_rest"))
	btn_long.pressed.connect(func(): settle_choice.call("long_rest"))
	btn_cancel.pressed.connect(func(): settle_choice.call(""))

	return {"opened": true, "modal": overlay}


static func complete_short_rest(
	participants: Array,
	context: Dictionary = {},
	host_parent: Node = null,
	decision_provider: Callable = Callable(),
	on_finished: Callable = Callable()
) -> Dictionary:
	var eligibility := can_complete_rest("short_rest", participants, context)
	if not bool(eligibility.get("allowed", false)):
		return {
			"success": false,
			"reason": str(eligibility.get("reason", "refused")),
			"message": str(eligibility.get("message", "Short Rest refused.")),
		}
	var living: Array[Character] = eligibility["participants"]
	var notifications: Array[Dictionary] = []
	if GameManager != null and not bool(context.get("skip_campaign_time", false)):
		notifications = GameManager.advance_campaign_time(SHORT_REST_SECONDS)
	for character in living:
		character.short_rest()

	_next_event_serial += 1
	var event := {
		"event_id": "rest_completed:%d" % _next_event_serial,
		"rest_type": "short_rest",
		"trigger": "short_rest_completed",
		"source": str(context.get("source", "party_rest")),
		"elapsed_seconds": SHORT_REST_SECONDS,
		"campaign_elapsed_seconds": GameManager.campaign_elapsed_seconds if GameManager != null else SHORT_REST_SECONDS,
		"participants": living,
	}

	var candidates: Array[Dictionary] = []
	for character in living:
		var char_candidates := find_rest_slot_recovery_candidates(character, "short_rest_completed")
		for cand in char_candidates:
			candidates.append(cand)

	if candidates.is_empty():
		var empty_out := {
			"success": true,
			"rest_type": "short_rest",
			"elapsed_seconds": SHORT_REST_SECONDS,
			"event": event,
			"recoveries": [],
			"notifications": notifications,
			"pending_recovery": false,
		}
		if on_finished.is_valid():
			on_finished.call(empty_out)
		return empty_out

	if decision_provider.is_valid():
		var recoveries: Array[Dictionary] = []
		for cand in candidates:
			var win := open_recovery_window(cand["character"], cand["feature"], cand["effect"], event)
			if not bool(win.get("opened", false)):
				continue
			var decision: Variant = decision_provider.call(get_active_recovery_window())
			var settled := settle_recovery_window(decision)
			recoveries.append(settled)
		var sync_out := {
			"success": true,
			"rest_type": "short_rest",
			"elapsed_seconds": SHORT_REST_SECONDS,
			"event": event,
			"recoveries": recoveries,
			"notifications": notifications,
			"pending_recovery": false,
		}
		if on_finished.is_valid():
			on_finished.call(sync_out)
		return sync_out

	if host_parent != null and is_instance_valid(host_parent):
		_pending_recovery_queue.clear()
		for cand in candidates:
			_pending_recovery_queue.append(cand)
		_pending_recovery_results.clear()
		_pending_recovery_host = host_parent
		_pending_recovery_finished = on_finished
		_pending_rest_event = event
		_advance_interactive_recovery_queue(notifications)
		return {
			"success": true,
			"rest_type": "short_rest",
			"elapsed_seconds": SHORT_REST_SECONDS,
			"event": event,
			"recoveries": _pending_recovery_results,
			"notifications": notifications,
			"pending_recovery": is_rest_window_open(),
			"active_window": get_active_recovery_window(),
		}

	# Non-UI caller without a synchronous decision_provider: open the first window
	# so the caller can inspect `get_active_recovery_window()` and invoke `settle_recovery_window(...)`.
	var first_cand := candidates[0]
	open_recovery_window(first_cand["character"], first_cand["feature"], first_cand["effect"], event)
	return {
		"success": true,
		"rest_type": "short_rest",
		"elapsed_seconds": SHORT_REST_SECONDS,
		"event": event,
		"recoveries": [],
		"notifications": notifications,
		"pending_recovery": true,
		"active_window": get_active_recovery_window(),
	}


static func _advance_interactive_recovery_queue(notifications: Array[Dictionary] = []) -> void:
	while not _pending_recovery_queue.is_empty():
		var next_cand: Dictionary = _pending_recovery_queue.pop_front()
		var win := open_recovery_window(next_cand["character"], next_cand["feature"], next_cand["effect"], _pending_rest_event)
		if not bool(win.get("opened", false)):
			continue
		if _pending_recovery_host != null and is_instance_valid(_pending_recovery_host):
			_open_slot_recovery_modal(_pending_recovery_host, _active_recovery_window, notifications)
			return
	var done_callback := _pending_recovery_finished
	var final_out := {
		"success": true,
		"rest_type": "short_rest",
		"elapsed_seconds": SHORT_REST_SECONDS,
		"event": _pending_rest_event,
		"recoveries": _pending_recovery_results.duplicate(true),
		"notifications": notifications,
		"pending_recovery": false,
	}
	_pending_recovery_host = null
	_pending_recovery_finished = Callable()
	if done_callback.is_valid():
		done_callback.call(final_out)


static func complete_long_rest(participants: Array, context: Dictionary = {}) -> Dictionary:
	var eligibility := can_complete_rest("long_rest", participants, context)
	if not bool(eligibility.get("allowed", false)):
		return {
			"success": false,
			"reason": str(eligibility.get("reason", "refused")),
			"message": str(eligibility.get("message", "Long Rest refused.")),
		}
	var living: Array[Character] = eligibility["participants"]
	for character in living:
		character.long_rest()
	var notifications: Array[Dictionary] = []
	if GameManager != null and not bool(context.get("skip_campaign_time", false)):
		notifications = GameManager.advance_campaign_time(LONG_REST_SECONDS)
	_next_event_serial += 1
	var event := {
		"event_id": "rest_completed:%d" % _next_event_serial,
		"rest_type": "long_rest",
		"trigger": "long_rest_completed",
		"source": str(context.get("source", "party_rest")),
		"elapsed_seconds": LONG_REST_SECONDS,
		"campaign_elapsed_seconds": GameManager.campaign_elapsed_seconds if GameManager != null else LONG_REST_SECONDS,
		"participants": living,
	}
	return {
		"success": true,
		"rest_type": "long_rest",
		"elapsed_seconds": LONG_REST_SECONDS,
		"event": event,
		"notifications": notifications,
	}


static func compute_recovery_budget(character: Character, effect: Dictionary) -> int:
	if character == null:
		return 0
	var class_source := str(effect.get("class_level_source", "self")).strip_edges()
	var cls_level := character.get_class_level(class_source)
	if cls_level <= 0:
		return 0
	var formula := str(effect.get("budget_formula", "half_class_level_ceil"))
	match formula:
		"half_class_level_ceil":
			return maxi(1, int(ceil(float(cls_level) / 2.0)))
		"class_level":
			return cls_level
		"flat":
			return maxi(1, int(effect.get("flat_budget", 1)))
		_:
			return 0


static func eligible_missing_slots(character: Character, effect: Dictionary) -> Dictionary:
	if character == null:
		return {}
	var budget := compute_recovery_budget(character, effect)
	if budget <= 0:
		return {}
	var min_slot_level := maxi(1, int(effect.get("min_slot_level", 1)))
	var max_slot_level := clampi(int(effect.get("max_slot_level", 5)), min_slot_level, 9)
	var max_slots := character.get_max_spell_slots()
	var missing := {}
	for lvl in range(min_slot_level, max_slot_level + 1):
		if lvl > budget:
			continue
		var key := str(lvl)
		var max_count := int(max_slots.get(key, 0))
		var cur_count := int(character.spell_slots.get(key, 0))
		var diff := max_count - cur_count
		if diff > 0:
			missing[key] = diff
	return missing


static func find_rest_slot_recovery_candidates(character: Character, trigger: String = "short_rest_completed") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if character == null or character.is_dead() or character.current_hp <= 0:
		return out
	for feature in character.features:
		if not (feature is Dictionary):
			continue
		var feature_id := str(feature.get("id", ""))
		var pool_id := str(feature.get("resource_id", feature_id))
		var cost := maxi(1, int(feature.get("resource_cost", 1)))
		var remaining := int(character.feature_uses.get(pool_id, 0))
		if remaining < cost:
			continue
		for effect in feature.get("effects", []):
			if not (effect is Dictionary) or str(effect.get("type", "")) != "rest_slot_recovery":
				continue
			if str(effect.get("trigger", "short_rest_completed")) != trigger:
				continue
			var missing := eligible_missing_slots(character, effect)
			if missing.is_empty():
				continue
			out.append({
				"character": character,
				"feature": feature,
				"effect": effect,
				"missing_by_level": missing,
				"budget": compute_recovery_budget(character, effect),
			})
	return out


static func open_recovery_window(character: Character, feature: Dictionary, effect: Dictionary, event: Dictionary = {}) -> Dictionary:
	if character == null or character.is_dead() or character.current_hp <= 0:
		return {"opened": false, "reason": "invalid_character"}
	var feature_id := str(feature.get("id", ""))
	var pool_id := str(feature.get("resource_id", feature_id))
	var cost := maxi(1, int(feature.get("resource_cost", 1)))
	if int(character.feature_uses.get(pool_id, 0)) < cost:
		return {"opened": false, "reason": "no_uses_remaining"}
	var budget := compute_recovery_budget(character, effect)
	if budget <= 0:
		return {"opened": false, "reason": "zero_budget"}
	var missing := eligible_missing_slots(character, effect)
	if missing.is_empty():
		return {"opened": false, "reason": "no_eligible_missing_slots"}
	var min_slot_level := maxi(1, int(effect.get("min_slot_level", 1)))
	var max_slot_level := clampi(int(effect.get("max_slot_level", 5)), min_slot_level, 9)

	_window_epoch += 1
	var request_id := "rest_slot_recovery:%d" % _window_epoch
	_active_recovery_window = {
		"request_id": request_id,
		"epoch": _window_epoch,
		"event_id": str(event.get("event_id", "")),
		"trigger": str(effect.get("trigger", "short_rest_completed")),
		"character": character,
		"owner_id": character.get_instance_id(),
		"character_id": character.character_id,
		"character_name": character.character_name,
		"feature_id": feature_id,
		"feature_name": str(feature.get("name", feature_id)),
		"pool_id": pool_id,
		"resource_cost": cost,
		"effect": effect.duplicate(true),
		"budget": budget,
		"min_slot_level": min_slot_level,
		"max_slot_level": max_slot_level,
		"missing_by_level": missing.duplicate(true),
		"settled": false,
	}
	return {"opened": true, "window": _active_recovery_window.duplicate(false)}


static func _normalize_selected_slots(raw_selection: Variant) -> Dictionary:
	var counts := {}
	if raw_selection is Dictionary:
		var dict_sel: Dictionary = raw_selection
		for raw_key in dict_sel:
			var key_str := str(raw_key).strip_edges()
			if not key_str.is_valid_int():
				return {"ok": false, "error": "invalid_slot_level", "message": "Slot level must be an integer."}
			var lvl := int(key_str)
			var raw_val: Variant = dict_sel[raw_key]
			if typeof(raw_val) == TYPE_BOOL or not (raw_val is int or raw_val is float) or float(raw_val) != float(int(raw_val)):
				return {"ok": false, "error": "invalid_slot_count", "message": "Slot count must be an integer."}
			var count := int(raw_val)
			if count < 0:
				return {"ok": false, "error": "negative_slot_count", "message": "Slot count cannot be negative."}
			if count == 0:
				continue
			counts[str(lvl)] = int(counts.get(str(lvl), 0)) + count
		return {"ok": true, "counts": counts}
	elif raw_selection is Array:
		var arr_sel: Array = raw_selection
		for item in arr_sel:
			if typeof(item) == TYPE_BOOL or not (item is int or item is float) or float(item) != float(int(item)):
				return {"ok": false, "error": "invalid_slot_level", "message": "Slot level must be an integer."}
			var lvl := int(item)
			if lvl <= 0:
				return {"ok": false, "error": "invalid_slot_level", "message": "Slot level must be positive."}
			counts[str(lvl)] = int(counts.get(str(lvl), 0)) + 1
		return {"ok": true, "counts": counts}
	return {"ok": false, "error": "invalid_selection_format", "message": "Slot selection must be a Dictionary or Array."}


static func validate_slot_selection(window: Dictionary, decision: Variant) -> Dictionary:
	if window.is_empty() or bool(window.get("settled", true)):
		return {"valid": false, "error": "stale_or_closed_window", "message": "Recovery window is closed or already settled."}
	if not (decision is Dictionary):
		return {"valid": false, "error": "invalid_decision", "message": "Recovery decision must be a Dictionary."}
	var dec: Dictionary = decision
	if dec.has("epoch") and int(dec.get("epoch", -1)) != int(window.get("epoch", -2)):
		return {"valid": false, "error": "stale_epoch", "message": "Recovery decision epoch does not match the active window."}
	if dec.has("request_id") and str(dec.get("request_id", "")) != str(window.get("request_id", "")):
		return {"valid": false, "error": "stale_request_id", "message": "Recovery decision request_id does not match the active window."}

	var character: Character = window.get("character")
	if character == null or character.is_dead() or character.current_hp <= 0:
		return {"valid": false, "error": "invalid_character", "message": "Character cannot recover slots."}
	if dec.has("actor") and dec.get("actor") != character:
		return {"valid": false, "error": "wrong_actor", "message": "Only the owning character can settle this recovery window."}
	if dec.has("owner_id") and int(dec.get("owner_id", 0)) != int(window.get("owner_id", -1)):
		return {"valid": false, "error": "wrong_actor", "message": "Owner ID mismatch for recovery window."}
	if dec.has("feature_id") and str(dec.get("feature_id", "")) != str(window.get("feature_id", "")):
		return {"valid": false, "error": "wrong_feature", "message": "Feature ID mismatch for recovery window."}

	if bool(dec.get("declined", false)) or str(dec.get("action", "")) == "decline":
		return {"valid": true, "declined": true, "selected_slots": {}, "budget_spent": 0}

	var pool_id := str(window.get("pool_id", ""))
	var cost := int(window.get("resource_cost", 1))
	if int(character.feature_uses.get(pool_id, 0)) < cost:
		return {"valid": false, "error": "no_uses_remaining", "message": "No feature uses remaining."}

	if not dec.has("selected_slots"):
		return {"valid": false, "error": "missing_selected_slots", "message": "Confirming slot recovery requires selected_slots."}
	var normalized := _normalize_selected_slots(dec.get("selected_slots"))
	if not bool(normalized.get("ok", false)):
		return {
			"valid": false,
			"error": str(normalized.get("error", "invalid_selection")),
			"message": str(normalized.get("message", "Invalid slot selection.")),
		}
	var counts: Dictionary = normalized["counts"]
	if counts.is_empty():
		return {"valid": false, "error": "empty_selection", "message": "Choose at least one expended spell slot or decline recovery."}

	var min_slot_level := int(window.get("min_slot_level", 1))
	var max_slot_level := int(window.get("max_slot_level", 5))
	var budget := int(window.get("budget", 0))
	var max_slots := character.get_max_spell_slots()
	var total_level_sum := 0

	for key in counts:
		var lvl := int(key)
		var req_count := int(counts[key])
		if lvl < min_slot_level or lvl > max_slot_level:
			return {
				"valid": false,
				"error": "slot_level_ineligible",
				"message": "Slot level %d is outside the eligible range (%d-%d)." % [lvl, min_slot_level, max_slot_level],
			}
		var max_for_lvl := int(max_slots.get(key, 0))
		var cur_for_lvl := int(character.spell_slots.get(key, 0))
		var missing_for_lvl := maxi(0, max_for_lvl - cur_for_lvl)
		if req_count > missing_for_lvl:
			return {
				"valid": false,
				"error": "slot_not_expended",
				"message": "Cannot recover %d level-%d slot(s); only %d expended." % [req_count, lvl, missing_for_lvl],
			}
		total_level_sum += lvl * req_count

	if total_level_sum > budget:
		return {
			"valid": false,
			"error": "budget_exceeded",
			"message": "Selected slot levels (%d) exceed recovery budget (%d)." % [total_level_sum, budget],
		}

	return {
		"valid": true,
		"declined": false,
		"selected_slots": counts,
		"budget_spent": total_level_sum,
		"budget_max": budget,
	}


static func settle_recovery_window(decision: Variant) -> Dictionary:
	var check := validate_slot_selection(_active_recovery_window, decision)
	if not bool(check.get("valid", false)):
		return {
			"success": false,
			"error": str(check.get("error", "invalid_selection")),
			"message": str(check.get("message", "Invalid recovery selection.")),
		}

	var character: Character = _active_recovery_window["character"]
	var feature_id := str(_active_recovery_window.get("feature_id", ""))
	var feature_name := str(_active_recovery_window.get("feature_name", feature_id))
	var budget := int(_active_recovery_window.get("budget", 0))

	if bool(check.get("declined", false)):
		_active_recovery_window["settled"] = true
		_active_recovery_window.clear()
		return {
			"success": true,
			"declined": true,
			"character_name": character.character_name,
			"feature_id": feature_id,
			"feature_name": feature_name,
			"restored_slots": {},
			"budget_spent": 0,
			"budget_max": budget,
			"message": "%s declines %s." % [character.character_name, feature_name],
		}

	if not character.use_feature(feature_id):
		return {
			"success": false,
			"error": "use_feature_failed",
			"message": "No uses remaining for %s." % feature_name,
		}

	var counts: Dictionary = check["selected_slots"]
	var summary_parts: Array[String] = []
	var sorted_keys := counts.keys()
	sorted_keys.sort_custom(func(a, b): return int(a) < int(b))
	for key in sorted_keys:
		var count := int(counts[key])
		character.spell_slots[key] = int(character.spell_slots.get(key, 0)) + count
		summary_parts.append("%d×L%s" % [count, key])

	var budget_spent := int(check.get("budget_spent", 0))
	_active_recovery_window["settled"] = true
	_active_recovery_window.clear()

	return {
		"success": true,
		"declined": false,
		"character_name": character.character_name,
		"feature_id": feature_id,
		"feature_name": feature_name,
		"restored_slots": counts.duplicate(true),
		"budget_spent": budget_spent,
		"budget_max": budget,
		"message": "%s uses %s to recover spell slots (%s; %d/%d budget)." % [
			character.character_name,
			feature_name,
			", ".join(summary_parts),
			budget_spent,
			budget,
		],
	}


static func _open_slot_recovery_modal(host_parent: Node, window: Dictionary, notifications: Array[Dictionary] = []) -> void:
	if _active_recovery_modal != null and is_instance_valid(_active_recovery_modal):
		_active_recovery_modal.queue_free()
		_active_recovery_modal = null

	var character: Character = window["character"]
	var feature_name := str(window.get("feature_name", "Arcane Recovery"))
	var budget := int(window.get("budget", 1))
	var max_slot_level := int(window.get("max_slot_level", 5))
	var missing_by_level: Dictionary = window.get("missing_by_level", {})

	var overlay := ColorRect.new()
	overlay.name = "SlotRecoveryModalOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "SlotRecoveryPanel"
	panel.custom_minimum_size = Vector2(460, 280)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "%s — %s" % [feature_name, character.character_name]
	title.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc := Label.new()
	desc.name = "DescriptionLabel"
	desc.text = "Choose expended spell slots to recover (combined slot levels up to %d; max slot level %d)." % [budget, max_slot_level]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	var budget_label := Label.new()
	budget_label.name = "BudgetLabel"
	vbox.add_child(budget_label)

	var rows_vbox := VBoxContainer.new()
	rows_vbox.name = "SlotRowsContainer"
	rows_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(rows_vbox)

	var selected_counts := {}
	var row_controls := {}
	var level_keys := missing_by_level.keys()
	level_keys.sort_custom(func(a, b): return int(a) < int(b))
	for key in level_keys:
		selected_counts[str(key)] = 0

	var btn_confirm := Button.new()
	btn_confirm.name = "BtnConfirmRecovery"
	btn_confirm.text = "Confirm Recovery"

	var btn_decline := Button.new()
	btn_decline.name = "BtnDeclineRecovery"
	btn_decline.text = "Skip / Decline"

	var refresh_ui := func() -> void:
		var spent := 0
		for k in selected_counts:
			spent += int(k) * int(selected_counts[k])
		budget_label.text = "Selected Slot Budget: %d / %d" % [spent, budget]
		btn_confirm.disabled = spent <= 0 or spent > budget
		for k in row_controls:
			var lvl := int(k)
			var count := int(selected_counts.get(k, 0))
			var max_missing := int(missing_by_level.get(k, 0))
			var ctrl: Dictionary = row_controls[k]
			var lbl: Label = ctrl["label"]
			var btn_sub: Button = ctrl["btn_sub"]
			var btn_add: Button = ctrl["btn_add"]
			lbl.text = "Level %d Slots: %d / %d expended selected" % [lvl, count, max_missing]
			btn_sub.disabled = count <= 0
			btn_add.disabled = count >= max_missing or (spent + lvl) > budget

	for key in level_keys:
		var k_str := str(key)
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		rows_vbox.add_child(hbox)

		var row_label := Label.new()
		row_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(row_label)

		var btn_sub := Button.new()
		btn_sub.name = "BtnSubLevel%s" % k_str
		btn_sub.text = "-"
		btn_sub.custom_minimum_size = Vector2(36, 0)
		hbox.add_child(btn_sub)

		var btn_add := Button.new()
		btn_add.name = "BtnAddLevel%s" % k_str
		btn_add.text = "+"
		btn_add.custom_minimum_size = Vector2(36, 0)
		hbox.add_child(btn_add)

		row_controls[k_str] = {"label": row_label, "btn_sub": btn_sub, "btn_add": btn_add}
		overlay.set_meta("btn_sub_level_%s" % k_str, btn_sub)
		overlay.set_meta("btn_add_level_%s" % k_str, btn_add)

		btn_sub.pressed.connect(func():
			selected_counts[k_str] = maxi(0, int(selected_counts.get(k_str, 0)) - 1)
			refresh_ui.call()
		)
		btn_add.pressed.connect(func():
			var max_m := int(missing_by_level.get(k_str, 0))
			var cur_s := 0
			for sk in selected_counts:
				cur_s += int(sk) * int(selected_counts[sk])
			if int(selected_counts.get(k_str, 0)) < max_m and (cur_s + int(k_str)) <= budget:
				selected_counts[k_str] = int(selected_counts.get(k_str, 0)) + 1
				refresh_ui.call()
		)

	var actions_hbox := HBoxContainer.new()
	actions_hbox.add_theme_constant_override("separation", 12)
	actions_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(actions_hbox)
	actions_hbox.add_child(btn_confirm)
	actions_hbox.add_child(btn_decline)

	overlay.set_meta("btn_confirm", btn_confirm)
	overlay.set_meta("btn_decline", btn_decline)
	overlay.set_meta("budget_label", budget_label)
	overlay.set_meta("selected_counts", selected_counts)

	refresh_ui.call()
	_active_recovery_modal = overlay
	host_parent.add_child(overlay)

	btn_confirm.pressed.connect(func():
		var res := settle_recovery_window({
			"epoch": window.get("epoch", -1),
			"request_id": window.get("request_id", ""),
			"owner_id": window.get("owner_id", 0),
			"selected_slots": selected_counts.duplicate(true),
		})
		if not bool(res.get("success", false)):
			return
		_pending_recovery_results.append(res)
		if _active_recovery_modal == overlay:
			_active_recovery_modal = null
		if is_instance_valid(overlay):
			overlay.queue_free()
		_advance_interactive_recovery_queue(notifications)
	)

	btn_decline.pressed.connect(func():
		var res := settle_recovery_window({
			"epoch": window.get("epoch", -1),
			"request_id": window.get("request_id", ""),
			"owner_id": window.get("owner_id", 0),
			"declined": true,
		})
		_pending_recovery_results.append(res)
		if _active_recovery_modal == overlay:
			_active_recovery_modal = null
		if is_instance_valid(overlay):
			overlay.queue_free()
		_advance_interactive_recovery_queue(notifications)
	)
