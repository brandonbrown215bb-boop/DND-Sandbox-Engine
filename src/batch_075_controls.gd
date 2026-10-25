class_name Batch075Controls
extends RefCounted
## Batch 075 (S-162): real room Give / Place / Put and the real shop Sell button
## pass their removal cause through Inventory.remove_exact. The fixture pairs
## author only sale/destruction/projection, so give, drop and stow keep the
## mate while a sale disposes exactly the sold copy's mate and pays once. A
## stale sale (copy gone before the press) pays nothing. Real save/load here;
## batch_075_linked_removal_reload rechecks the bonds in a fresh process.

const SLOT := "batch_075_linked_removal"
const IDS := "user://batch_075_ids.json"
const SELLER_FEATURES := ["fixture:b075_pair_a", "fixture:b075_pair_b"]

static func _select(view: LocalRoomView, id: String) -> bool:
	return Batch074Controls._select_item(view, id)

static func _companion(h: Node) -> Character:
	var c: Character = PartyManager.characters.get(str(PartyManager.companion_roster.get("b075_keeper", {}).get("character_id", "")), null)
	if c == null:
		c = PartyManager.create_companion("b075_keeper", "Link Keeper", "human", Batch075Checks.CLASS_ID, {"STR": 12, "DEX": 14, "CON": 14, "INT": 12, "WIS": 12, "CHA": 16})
		h._assert(c != null and PartyManager.recruit_companion("b075_keeper"), "075 fixture-class companion joins the party")
	return c

static func run(h: Node) -> void:
	h._enter_test("batch_075_linked_removal_flow")
	h._setup_world()
	Batch075Checks.load_fixtures()
	var c := _companion(h)
	GameManager._reset_campaign_ledgers()
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = true
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: DungeonState = await h._spawn_scene("res://scenes/dungeon.tscn", 0.2)
	var room: Room
	for candidate in dungeon.rooms.values():
		if candidate.id == 1: room = candidate
	dungeon.hex_grid.hex_clicked.emit(room.coord)
	await h.get_tree().process_frame
	var view: LocalRoomView = dungeon.local_view
	var a: Character = PlayerManager.get_player(0).get("character")
	h._assert(c != null and view.characters.has(c), "075 the companion is in the room party")
	if c == null or not view.characters.has(c):
		h._exit_test()
		return
	var p := Batch075Checks.pairs(c)
	h._assert(BondRules.bonded(c, Batch075Checks.PAIR_A) == [p.a1, p.a2] and BondRules.bonded(c, Batch075Checks.PAIR_B) == [p.b1, p.b2], "075 two linked pairs of identical dagger copies are bonded")
	# Give (not authored): the exact copy moves, its mate and the other pair stay.
	h._assert(await Batch074Controls._walk(h, view, c, Batch074Controls._pos(view, a), 5), "075 the companion stands next to Alice")
	_select(view, p.a1)
	for i in view.characters.size():
		if view.characters[i] == a: view.recipients.select(i)
	h._local_room_press(view, "Give")
	h._assert(Batch075Checks.owns(a, p.a1) and Batch075Checks.owns(c, p.a2) and BondRules.bonded(c, Batch075Checks.PAIR_A) == [p.a2] and BondRules.bonded(c, Batch075Checks.PAIR_B) == [p.b1, p.b2] and Batch075Checks.owns(c, p.loose), "075 actual Give moves only the exact copy; an unauthored give keeps its linked mate and the other pair")
	# Place (drop, not authored).
	_select(view, p.b1)
	h._local_room_press(view, "Place")
	h._assert(not Batch075Checks.owns(c, p.b1) and Batch075Checks.owns(c, p.b2) and BondRules.bonded(c, Batch075Checks.PAIR_B) == [p.b2] and Batch075Checks.owns(c, p.a2), "075 actual Place drops only the exact copy and keeps its linked mate")
	# Put (stow into a room container, not authored).
	var here := Batch074Controls._pos(view, c)
	var spot := Vector2i(-9999, -9999)
	for cell in HexUtils.get_hexes_in_range(here, 1):
		if cell != here and LocalRoomRules.passable(view.state, cell) and LocalRoomRules.object_at(view.state, cell).is_empty() and not view.state.party_positions.values().any(func(v): return LocalRoomRules.coord(v) == cell):
			spot = cell
			break
	view.state.objects.append({"id": "b075_chest", "name": "Link Chest", "kind": "container", "open": true, "contents": [], "capacity": 5, "position": [spot.x, spot.y], "hp": 10, "max_hp": 10})
	view.refresh()
	for i in view.objects.item_count:
		if str(view.objects.get_item_metadata(i)) == "b075_chest":
			view.objects.select(i)
			view.objects.item_selected.emit(i)
	view.refresh()
	_select(view, p.a2)
	h._local_room_press(view, "Put")
	var chest := LocalRoomRules.get_object(view.state, "b075_chest")
	h._assert(chest.get("contents", []).any(func(r): return str(r.instance_id) == p.a2) and Batch075Checks.owns(c, p.b2) and Batch075Checks.owns(c, p.loose), "075 actual Put stows only the exact copy; nothing linked or unlinked is disposed")
	# Fresh linked pairs for the sale and the reload.
	var q := Batch075Checks.pairs(c)
	FileAccess.open(IDS, FileAccess.WRITE).store_string(JSON.stringify({"c": c.character_id, "q": q}))
	h._teardown_scene(dungeon)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(SLOT)
	h._assert(saved, "075 actual real save with two live linked pairs (block='%s')" % block)
	if saved:
		SaveManager.load_game(SLOT)
		var nc: Character = PartyManager.characters.get(c.character_id, null)
		h._assert(nc != null and nc != c and BondRules.bonded(nc, Batch075Checks.PAIR_A) == [q.a1, q.a2] and BondRules.bonded(nc, Batch075Checks.PAIR_B) == [q.b1, q.b2], "075 actual real load keeps both linked pairs on their exact copies")
	await _sale(h)
	h._exit_test()

## The real shop Sell button: the seller (a player) carries the authored pair rules in session.
static func _sale(h: Node) -> void:
	var seller: Character = PlayerManager.get_player(0).get("character")
	var prior := seller.features.duplicate(true)
	for f in DataLoader.get_character_class(Batch075Checks.CLASS_ID).features_by_level["1"]: seller.features.append(f.duplicate(true))
	seller.exclusive_bonds.clear()
	var p := Batch075Checks.pairs(seller)
	var shop: ShopUI = await h._spawn_scene("res://scenes/ui/shop.tscn", 0.3)
	shop.setup_shop("Link Town")
	await h.get_tree().create_timer(0.2).timeout
	shop.active_player_index = 0
	shop._update_player_data()
	var price := int(DataLoader.get_item("dagger").get("value", 0)) / 2
	var listed := func(id: String) -> bool:
		for i in shop.sell_selector.item_count:
			if str(shop.sell_selector.get_item_metadata(i)) == id:
				shop.sell_selector.select(i)
				return true
		return false
	var gold := seller.inventory.gold
	var ok: bool = listed.call(p.a1)
	shop.btn_sell.pressed.emit()
	h._assert(ok and not Batch075Checks.owns(seller, p.a1) and not Batch075Checks.owns(seller, p.a2) and Batch075Checks.owns(seller, p.b1) and Batch075Checks.owns(seller, p.b2) and Batch075Checks.owns(seller, p.loose) and seller.inventory.gold == gold + price and BondRules.last_disposal.get("cause", "") == "sale", "075 actual Sell sells the exact copy, pays once (%d -> %d) and disposes exactly its authored linked mate" % [gold, seller.inventory.gold])
	# Stale: the selected copy leaves before the press; nothing is paid or disposed.
	gold = seller.inventory.gold
	ok = listed.call(p.b1)
	var friend: Character = PlayerManager.get_player(1).get("character")
	seller.inventory.transfer_instance(p.b1, friend.inventory)
	shop.btn_sell.pressed.emit()
	h._assert(ok and seller.inventory.gold == gold and Batch075Checks.owns(friend, p.b1) and Batch075Checks.owns(seller, p.b2) and Batch075Checks.owns(seller, p.loose), "075 actual a stale Sell (copy given away first) pays nothing and disposes nothing")
	# A replayed press after the pay-out cannot pay twice for the same copy.
	shop._refresh_sell_choices()
	ok = listed.call(p.loose)
	shop.btn_sell.pressed.emit()
	var after := seller.inventory.gold
	shop.sell_selector.set_item_metadata(maxi(0, shop.sell_selector.selected), p.loose)
	shop.btn_sell.pressed.emit()
	h._assert(ok and after == gold + price and seller.inventory.gold == after and Batch075Checks.owns(seller, p.b2), "075 actual a replayed Sell of the sold copy pays once")
	h._teardown_scene(shop)
	seller.features = prior
	seller.exclusive_bonds.clear()

## Fresh process: the loaded pairs keep their authored fate per cause.
static func reload(h: Node) -> void:
	h._enter_test("batch_075_linked_removal_reload")
	Batch075Checks.load_fixtures()
	var ids: Variant = JSON.parse_string(FileAccess.get_file_as_string(IDS))
	var loaded := SaveManager.load_game(SLOT)
	var nc: Character = PartyManager.characters.get(str(ids.c), null) if ids is Dictionary else null
	h._assert(loaded and nc != null and BondRules.bonded(nc, Batch075Checks.PAIR_A) == [str(ids.q.a1), str(ids.q.a2)], "075 fresh process both linked pairs load")
	if nc != null:
		var friend: Character = PlayerManager.get_player(0).get("character")
		var gave := nc.inventory.transfer_instance(str(ids.q.a1), friend.inventory)
		h._assert(gave and Batch075Checks.owns(nc, str(ids.q.a2)), "075 fresh process an unauthored give keeps the mate")
		nc.inventory.destroy_instance(str(ids.q.b1))
		h._assert(not Batch075Checks.owns(nc, str(ids.q.b2)) and Batch075Checks.owns(nc, str(ids.q.a2)) and Batch075Checks.owns(nc, str(ids.q.loose)), "075 fresh process an authored destruction disposes exactly its own mate")
	SaveManager.delete_save(SLOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IDS))
	h._exit_test()
