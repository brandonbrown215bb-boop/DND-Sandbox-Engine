## Batch 062: owned mode controls in the local room (outside combat).
## Costed acts (action / bonus_action) are usable here with no action economy;
## uses are still charged exactly once by ModeControls.apply. Cancel, a
## superseded popup, a changed actor or changed state spend nothing.
class_name LocalRoomModes
extends RefCounted

## Every pressable mode act for the actor: [{feature_id, kind, token, text}].
static func offers(actor: Character) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var context := ModeControls.outside_combat()
	for r in ModeControls.rows(actor):
		for kind in r.actions:
			var price := ModeControls.cost(actor, r.feature_id, kind)
			var block := ModeControls.cost_error(actor, r.feature_id, kind, context)
			if not block.is_empty(): continue
			var cost_text := "" if price == "none" else " (%s; no turn outside combat)" % CombatTurnBudget.cost_label(price)
			var seconds := FeatureModeRules.activation_seconds(actor, r.feature_id, kind)
			# Batch 064: the data-declared time is shown; the room clock is not advanced (PARTIAL).
			var time_text := "" if seconds <= 0 else " [takes %s; time not advanced]" % ModeControls.duration_label(seconds)
			out.append({"feature_id": r.feature_id, "kind": kind, "token": r.token, "owner_id": actor.character_id, "activation_seconds": seconds, "text": "%s: %s%s%s" % [ModeControls.kind_label(kind), ModeControls.label(r), cost_text, time_text]})
	return out

static func refresh(view: LocalRoomView) -> void:
	for child in view.mode_row.get_children():
		view.mode_row.remove_child(child)
		child.queue_free()
	var list := offers(view.actor())
	view.mode_offers = OptionButton.new()
	view.mode_offers.name = "RoomModeOffers"
	view.mode_offers.fit_to_longest_item = false
	view.mode_offers.clip_text = true
	view.mode_offers.custom_minimum_size.x = 160
	view.mode_row.add_child(view.mode_offers)
	view.mode_row.visible = not list.is_empty()
	for offer in list:
		view.mode_offers.add_item(offer.text)
		view.mode_offers.set_item_metadata(view.mode_offers.item_count - 1, offer)
	if list.is_empty(): return
	view._add_button(view.mode_row, "Use mode", func(): open(view))

## Opens Cancel plus exactly the offered options for the selected offer.
static func open(view: LocalRoomView) -> PopupMenu:
	if view.mode_offers == null or view.mode_offers.selected < 0: return null
	var offer: Dictionary = view.mode_offers.get_item_metadata(view.mode_offers.selected)
	var owner := view.actor()
	var r := ModeControls.row(owner, str(offer.feature_id))
	view.mode_popup_serial += 1
	var serial := view.mode_popup_serial
	var menu := PopupMenu.new()
	menu.name = "RoomModePopup"
	menu.title = "%s: %s" % [ModeControls.kind_label(str(offer.kind)), r.name]
	menu.add_item("Cancel", 0)
	var choices: Array[String] = ModeControls.options(r, str(offer.kind))
	for i in choices.size(): menu.add_item(choices[i].replace("|", ": "), i + 1)
	menu.id_pressed.connect(func(id):
		answer(view, owner, offer, "" if id == 0 else choices[id - 1], serial)
		menu.queue_free())
	menu.popup_hide.connect(func(): if is_instance_valid(menu): menu.queue_free())
	view.panel.add_child(menu)
	menu.popup_centered()
	return menu

static func answer(view: LocalRoomView, owner: Character, offer: Dictionary, picked: String, serial: int) -> Dictionary:
	var name := str(owner.get_feature(str(offer.feature_id)).get("name", offer.feature_id))
	if picked.is_empty():
		view.hud.add_log("%s: canceled; nothing was spent." % name)
		return {"success": false, "reason": "canceled"}
	if serial != view.mode_popup_serial or view.actor() != owner:
		view.hud.add_log("That choice is no longer current; nothing was spent.")
		return {"success": false, "reason": "stale"}
	var result := ModeControls.apply(owner, str(offer.feature_id), str(offer.kind), picked, str(offer.token), ModeControls.outside_combat())
	var ok := bool(result.get("success", false))
	var message := "%s: %s %s." % [name, ModeControls.kind_label(str(offer.kind)).to_lower(), picked.replace("|", ": ")] if ok else "%s: refused (%s); nothing was spent." % [name, str(result.get("reason", "")).replace("_", " ")]
	if ok and int(result.get("activation_seconds", 0)) > 0:
		message += " (takes %s; time not advanced)" % ModeControls.duration_label(int(result.activation_seconds))
	view._result({"success": ok, "seconds": 0, "message": message}) # Batch 064: seconds stay 0, no clock is advanced.
	return result
