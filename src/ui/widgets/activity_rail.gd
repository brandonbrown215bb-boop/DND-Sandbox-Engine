class_name ActivityRailWidget
extends VBoxContainer

## Resolved records only; session presentation stays out of campaign save data.
static var session: Dictionary = {}
@onready var card_scroll: ScrollContainer = $CardScroll
@onready var card_feed: VBoxContainer = $CardScroll/CardFeed
var current_filter := "all"
var _state: Dictionary
var _tabs: Dictionary
var _new_button: Button
var _new_count := 0
var _rebuilding := false

func _enter_tree() -> void:
	if not ActivityHistory.record_published.is_connected(_on_record_published):
		ActivityHistory.record_published.connect(_on_record_published)
	if card_feed != null:
		call_deferred("_rebuild")
		call_deferred("_restore_scroll")

static func create() -> ActivityRailWidget:
	var rail := ActivityRailWidget.new()
	var header := HBoxContainer.new()
	header.name = "RailHeader"
	rail.add_child(header)
	var title := Label.new()
	title.text = "Chronicle"
	title.theme_type_variation = "HeadingLabel"
	header.add_child(title)
	var tabs := HBoxContainer.new()
	tabs.name = "FilterTabs"
	rail.add_child(tabs)
	for spec in [["BtnAll", "All"], ["BtnRolls", "Rolls"], ["BtnCombat", "Combat"], ["BtnSystem", "System"]]:
		var button := Button.new()
		button.name = spec[0]
		button.text = spec[1]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
	var scroll := ScrollContainer.new()
	scroll.name = "CardScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rail.add_child(scroll)
	var feed := VBoxContainer.new()
	feed.name = "CardFeed"
	feed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(feed)
	return rail

func _ready() -> void:
	var campaign_key := str(GameManager.active_campaign.get("id", "campaign"))
	_state = session.get(campaign_key, {"filter": "all", "scroll": {}, "pinned": {}, "next_sequence": 1})
	if ActivityHistory.get_next_sequence() < int(_state.get("next_sequence", 1)):
		_state = {"filter": "all", "scroll": {}, "pinned": {}, "next_sequence": 1}
	session[campaign_key] = _state
	current_filter = str(_state.filter)
	_tabs = {"all": $FilterTabs/BtnAll, "roll": $FilterTabs/BtnRolls, "combat": $FilterTabs/BtnCombat, "system": $FilterTabs/BtnSystem}
	for key in _tabs:
		var button: Button = _tabs[key]
		button.custom_minimum_size = Vector2(40, 40)
		button.remove_theme_font_size_override("font_size")
		button.pressed.connect(_set_filter.bind(key))
	_new_button = Button.new()
	_new_button.hide()
	add_child(_new_button)
	_new_button.pressed.connect(_jump_to_newest)
	if not ActivityHistory.record_published.is_connected(_on_record_published):
		ActivityHistory.record_published.connect(_on_record_published)
	card_scroll.get_v_scroll_bar().value_changed.connect(_remember_scroll)
	_rebuild()
	call_deferred("_restore_scroll")

func _exit_tree() -> void:
	if ActivityHistory.record_published.is_connected(_on_record_published):
		ActivityHistory.record_published.disconnect(_on_record_published)

func _set_filter(filter_name: String) -> void:
	_remember_scroll(card_scroll.scroll_vertical)
	current_filter = filter_name
	_new_count = 0
	_new_button.hide()
	_state.filter = filter_name
	_rebuild()
	call_deferred("_restore_scroll")

func _remember_scroll(value: float) -> void:
	if not _rebuilding:
		_state.scroll[current_filter] = value

func _restore_scroll() -> void:
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	var bar := card_scroll.get_v_scroll_bar()
	card_scroll.scroll_vertical = int(_state.scroll.get(current_filter, maxf(0, bar.max_value - bar.page)))
	_rebuilding = false

func _at_bottom() -> bool:
	var bar := card_scroll.get_v_scroll_bar()
	return bar.value >= bar.max_value - bar.page - 8

func _jump_to_newest() -> void:
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	var bar := card_scroll.get_v_scroll_bar()
	bar.value = maxf(0, bar.max_value - bar.page)
	_new_count = 0
	_new_button.hide()

func _on_record_published(record: Dictionary) -> void:
	if not is_inside_tree() or card_feed == null: return
	var following := _at_bottom()
	var old_scroll := card_scroll.scroll_vertical
	_add_card(record)
	_state.next_sequence = ActivityHistory.get_next_sequence()
	while card_feed.get_child_count() > 200:
		var child := card_feed.get_child(0)
		_state.pinned.erase(str(child.get_meta("record", {}).get("id", "")))
		card_feed.remove_child(child)
		child.queue_free()
	if following:
		_jump_to_newest()
	else:
		card_scroll.scroll_vertical = old_scroll
		if _matches(record):
			_new_count += 1
			_new_button.text = "New (%d) ↓" % _new_count
			_new_button.show()

func _matches(record: Dictionary) -> bool:
	if current_filter == "all": return true
	if current_filter == "combat":
		return record.get("category") == "combat" or record.get("scene_context", {}).get("scene") == "combat"
	return record.get("category") == current_filter

func _rebuild() -> void:
	_rebuilding = true
	for child in card_feed.get_children():
		card_feed.remove_child(child)
		child.queue_free()
	for record in ActivityHistory.get_records(): _add_card(record)
	for key in _tabs:
		_tabs[key].theme_type_variation = "PrimaryButton" if key == current_filter else "Button"
	_state.next_sequence = ActivityHistory.get_next_sequence()

func _add_card(record: Dictionary) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	card.visible = _matches(record)
	card.set_meta("record", record)
	card_feed.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(UiThemeProfile.current().spacing.get("small", 6)))
	card.add_child(box)
	var actor := str(record.get("actor", {}).get("name", ""))
	var title := str(record.get("title", "Activity"))
	var header := Label.new()
	header.text = "%s  %s" % [record.get("sequence", ""), (actor + " · " if not actor.is_empty() else "") + title]
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(header)
	var outcome := str(record.get("outcome", {}).get("label", ""))
	if not outcome.is_empty():
		var badge := Label.new()
		badge.text = outcome.to_upper()
		var code := str(record.get("outcome", {}).get("code", ""))
		badge.add_theme_color_override("font_color", UiThemeProfile.current().color("state/danger" if code == "miss" else "state/success"))
		box.add_child(badge)
	var summary := Label.new()
	summary.text = str(record.get("summary", ""))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(summary)
	var payload: Dictionary = record.get("payload", {})
	if payload.is_empty(): return
	var detail_text := describe_payload(payload)
	if detail_text.is_empty(): return
	var detail := Label.new()
	detail.text = detail_text
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var id := str(record.get("id", ""))
	detail.visible = bool(_state.pinned.get(id, false))
	var expand := Button.new()
	expand.text = "Roll details ▾"
	expand.tooltip_text = detail_text
	expand.custom_minimum_size.y = 40
	box.add_child(expand)
	box.add_child(detail)
	var hover_state := {"active": false}
	expand.pressed.connect(func():
		_state.pinned[id] = not bool(_state.pinned.get(id, false))
		detail.visible = bool(_state.pinned[id]) or hover_state.active
	)
	expand.focus_entered.connect(func(): detail.show())
	expand.focus_exited.connect(func(): detail.visible = bool(_state.pinned.get(id, false)) or hover_state.active)
	expand.mouse_entered.connect(func():
		hover_state.active = true
		await get_tree().create_timer(0.4).timeout
		if hover_state.active and is_instance_valid(detail): detail.show()
	)
	card.mouse_exited.connect(func():
		hover_state.active = false
		detail.visible = bool(_state.pinned.get(id, false)) or expand.has_focus()
	)

static func describe_payload(payload: Dictionary) -> String:
	# Copy stored terms, including grouped attacks and damage. Never recompute.
	var blocks: Array[String] = []
	var attacks: Array = payload.get("sections", {}).get("attacks", [])
	if attacks.is_empty():
		blocks.append(_roll_text(payload))
	else:
		for attack in attacks:
			blocks.append("Attack %s\n%s" % [_number(attack.get("index", "")), _roll_text(attack.get("roll", {}))])
			var damage: Dictionary = attack.get("damage", {})
			if not damage.is_empty(): blocks.append("Damage\n" + _roll_text(damage))
			for component in attack.get("damage_components", []):
				blocks.append("%s  %s %s" % [component.get("label", "Damage component"), _number(component.get("value", 0)), component.get("type", "")])
			blocks.append("Applied damage  %s" % _number(attack.get("applied_damage", 0)))
	return "\n\n".join(blocks)

static func _roll_text(roll: Dictionary) -> String:
	var lines: Array[String] = []
	for term in roll.get("dice_terms", []):
		var dice: Array[String] = []
		var results: Array = term.get("results", [])
		var kept: Array = term.get("kept", [])
		for index in results.size():
			var markers: Array[String] = ["kept" if index < kept.size() and kept[index] else "discarded"]
			if results[index] == 1: markers.append("minimum")
			if results[index] == term.get("sides"): markers.append("maximum")
			dice.append("%s (%s)" % [_number(results[index]), ", ".join(markers)])
		lines.append("%s  %s" % [term.get("label", "Die"), ", ".join(dice)])
	for modifier in roll.get("modifiers", []):
		lines.append("%s  %+d" % [modifier.get("label", "Modifier"), int(modifier.get("value", 0))])
	if roll.has("final_total"): lines.append("Total  %s" % _number(roll.final_total))
	for mitigation in roll.get("mitigation", []):
		lines.append("%s  %s → %s" % [mitigation.get("label", "Mitigation"), _number(mitigation.get("from", 0)), _number(mitigation.get("to", 0))])
	var comparison: Dictionary = roll.get("comparison", {})
	if not comparison.is_empty():
		lines.append("Target %s  %s" % ["AC" if comparison.get("kind") == "armor_class" else "DC", _number(comparison.get("target"))])
		lines.append("%s · Margin %s" % [str(comparison.get("result", "")).replace("_", " ").capitalize(), _number(comparison.get("margin"))])
	return "\n".join(lines)

static func _number(value: Variant) -> String:
	return str(int(value)) if value is float and value == int(value) else str(value)
