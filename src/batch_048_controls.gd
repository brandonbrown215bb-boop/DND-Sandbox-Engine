class_name Batch048Controls
extends RefCounted

static func run(h: Node) -> void:
	h._enter_test("batch_048_item_types_measurements_flow")
	h._setup_world()
	Batch048Checks.load_fixtures()
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var a: Character = PlayerManager.get_player(0).get("character")
	# The real catalog backpack through the HUD Stow route (first carried container that fits).
	var pack := Batch048Checks.add(a, "backpack")
	var stowed := 0
	for id in ["crowbar", "bedroll", "climbers_kit", "healers_kit", "lantern_hooded"]:
		var copy := Batch048Checks.add(a, id)
		if ContainerRules.stow(a.inventory, copy).get("success", false) and ContainerRules.contents(a.inventory, pack).any(func(c): return str(c.instance_id) == copy): stowed += 1
	h._assert(stowed == 5, "048 actual HUD stow puts five real catalog items (29 lb.) in the real backpack (%d/5)" % stowed)
	# Checklist (a): a refused stow spends no time and moves nothing.
	var caltrops := Batch048Checks.add(a, "caltrops")
	var host_before := a.inventory.get_instance(pack)
	var clock := int(GameManager.campaign_elapsed_seconds)
	var over := ContainerRules.stow(a.inventory, caltrops)
	GameManager.advance_campaign_time(int(over.get("seconds", 0)))
	h._assert(not over.get("success", false) and a.inventory.get_instance(pack) == host_before and int(GameManager.campaign_elapsed_seconds) == clock and a.inventory.backpack_instances().any(func(c): return str(c.instance_id) == caltrops), "048 actual over-limit stow (31 lb.) is refused with no time spent and nothing moved")
	var bell := Batch048Checks.add(a, "bell")
	var unknown := ContainerRules.stow(a.inventory, bell)
	h._assert(not unknown.get("success", false) and not DataLoader.get_item("bell").has("weight") and ContainerRules.contents(a.inventory, pack).size() == 5, "048 actual a real bell with no SRD weight stays unknown and is refused")
	# Held staff and rod, worn wondrous boots.
	a.inventory.unequip(Inventory.Slot.SHIELD)
	a.inventory.add_item(Batch048Checks.STAFF)
	a.inventory.equip(Inventory.Slot.HANDS, Batch048Checks.STAFF)
	var ac_staff := SourceBenefitRules.total(a, "AC")
	a.inventory.add_item(Batch048Checks.BOOTS)
	a.inventory.equip(Inventory.Slot.FEET, Batch048Checks.BOOTS)
	var boots := a.inventory.equipped_instance_id(Inventory.Slot.FEET)
	var att := a.inventory.attune_instance(boots, a.character_id)
	h._assert(a.inventory.get_equipped(Inventory.Slot.HANDS) == Batch048Checks.STAFF and ac_staff == 1 and att.get("success", false) and SourceBenefitRules.total(a, "speed") == 1, "048 actual held staff and worn attuned wondrous boots apply their benefits")
	a.inventory.add_item(Batch048Checks.CHARM)
	var charm_slot := Inventory.Slot.values().filter(func(s): return a.inventory.can_equip(s, Batch048Checks.CHARM))
	h._assert(charm_slot.is_empty(), "048 actual an undeclared wondrous item can only be carried")
	# Real save and load: exact contents, held staff and attuned boots survive.
	var slot := "batch_048_item_types"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "048 actual real save with a loaded backpack, staff and boots (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(slot)
		var na: Character = PartyManager.characters.get(a.character_id, null)
		h._assert(loaded and na != null and na != a and ContainerRules.contents(na.inventory, pack).size() == 5 and na.inventory.get_equipped(Inventory.Slot.HANDS) == Batch048Checks.STAFF and SourceBenefitRules.total(na, "speed") == 1, "048 actual real load keeps the exact backpack contents and worn items")
		if na != null:
			var out := ContainerRules.retrieve_last(na.inventory, pack)
			var fits := ContainerRules.stow(na.inventory, caltrops)
			h._assert(out.get("success", false) and fits.get("success", false) and ContainerRules.contents(na.inventory, pack).any(func(c): return str(c.instance_id) == caltrops), "048 actual after taking out 2 lb. the caltrops fit the reloaded backpack")
		SaveManager.delete_save(slot)
	h._exit_test()
