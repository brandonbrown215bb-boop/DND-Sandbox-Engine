## Inventory quantity exchange through existing feature controls and commands.
class_name Batch023Controls
extends RefCounted

static func run(h: Node, combat: Node, owner: Character, recipient: Character, destination_definition: Dictionary) -> Dictionary:
	var feature: Dictionary = DataLoader.get_character_class("fixture:pool_exchange_class").features_by_level["1"][7].duplicate(true)
	owner.features.append(feature)
	var destination_id := "fixture:inventory_destination"
	ResourcePoolRules.acquire(recipient, destination_definition, destination_id)
	var destination := ResourcePoolRules._party_pool_token(recipient.character_id, destination_id)
	var policy: Dictionary = feature.resource_exchange
	var numeric_id := ResourcePoolRules.source_instance_ids(owner, "fixture:exchange_pool_a_uses")[0]
	for id in ResourcePoolRules.source_instance_ids(owner, "fixture:exchange_pool_a_uses"):
		var pool: Dictionary = owner.numeric_resource_pools[id]
		if pool.current > 0 and pool.current < pool.capacity: numeric_id = id
	var same_pool_before := owner.numeric_resource_pools.duplicate(true)
	var self_alias := ResourcePoolRules.exchange(owner, numeric_id, ResourcePoolRules._party_pool_token(owner.character_id, numeric_id), "fixture:exchange_pool_a_uses", 1, "fixture:exchange_pool_a_uses", 1, true, true)
	h._assert(not self_alias.get("success", false) and owner.numeric_resource_pools == same_pool_before, "023: a party-recipient alias cannot exchange a pool into itself and manufacture uses")
	var loaded_items := DataLoader.items
	DataLoader.items = {}
	var before_item_load := ClassFeature.content_error(feature)
	var unavailable := ResourcePoolRules.exchange_payment_sources(owner, policy)
	DataLoader.items = loaded_items
	h._assert(before_item_load.is_empty() and unavailable.is_empty(), "023: class validation works before items load, while offering an unavailable item payment refuses")
	var unknown := policy.duplicate(true)
	unknown.payment_pool_id = "inventory:fixture:missing_item"
	h._assert(ResourcePoolRules.exchange_payment_sources(owner, unknown).is_empty(), "023: an unknown authored inventory item is unavailable at runtime")
	h._assert(ClassFeature.content_error(feature).is_empty(), "023: loaded inventory-quantity exchange validates with an existing item definition")
	for index in 4: owner.inventory.add_item("torch")
	owner.inventory.add_item("dagger")
	var choices := ResourcePoolRules.exchange_payment_sources(owner, policy)
	var token := choices[0] if not choices.is_empty() else ""
	var selected := ResourcePoolRules._inventory_exchange_source(token)
	h._assert(selected.size() == 2, "023: selector captures exactly the authored quantity of distinct backpack copies")
	if selected.size() != 2: return owner.inventory.to_dict()
	var before := owner.inventory.to_dict().duplicate(true)
	for stage in ["payment", "restoration"]:
		var cancelled: Dictionary = await h._perform_numeric_pool_exchange_menu_activation(combat, owner, 0, str(feature.id), token, destination, stage)
		h._assert(cancelled.get("cancelled", false) and cancelled.get("action_available", false) and owner.inventory.to_dict() == before and recipient.numeric_resource_pools[destination_id].current == 0, "023: cancelling the %s popup keeps all inventory copies, destination and Action" % stage)
	var command := _command(owner, feature, token, destination)
	h._assert(command != null and owner.inventory.to_dict() == before, "023: production command preflight does not consume selected inventory copies")
	# Removing one selected copy must not silently substitute an identical sibling.
	var removed := owner.inventory.take_instance(selected[0])
	before = owner.inventory.to_dict().duplicate(true)
	var budget := CombatTurnBudget.new()
	var result: Dictionary = ClassFeature.execute(owner, command.payload.feature, null, budget) if command != null else {}
	h._assert(not result.get("success", false) and owner.inventory.to_dict() == before and recipient.numeric_resource_pools[destination_id].current == 0 and budget.action_available, "023: lost selected copy refuses atomically despite enough identical sibling copies")
	owner.inventory.receive_instance(removed)
	var record := owner.inventory.get_instance(selected[0])
	record.state.cursed_attunement = true
	owner.inventory.update_instance(record)
	before = owner.inventory.to_dict().duplicate(true)
	h._assert(_command(owner, feature, token, destination) == null and owner.inventory.to_dict() == before, "023: a newly cursed selected copy refuses before spending any sibling")
	record.state.erase("cursed_attunement")
	owner.inventory.update_instance(record)
	var wrong_id := ""
	for copy in owner.inventory.backpack_instances():
		if copy.definition_id == "dagger": wrong_id = str(copy.instance_id)
	for ids in [[selected[0], selected[0]], [selected[0]], [selected[0], wrong_id], [selected[0], "foreign:copy"]]:
		var forged := "inventory-copies:" + JSON.stringify(ids)
		before = owner.inventory.to_dict().duplicate(true)
		h._assert(_command(owner, feature, forged, destination) == null and owner.inventory.to_dict() == before and recipient.numeric_resource_pools[destination_id].current == 0, "023: duplicate, short, wrong-definition or foreign inventory payment refuses intact: %s" % JSON.stringify(ids))
	# Capacity and party membership can change while the two popups are open.
	command = _command(owner, feature, token, destination)
	recipient.numeric_resource_pools[destination_id].current = 3
	before = owner.inventory.to_dict().duplicate(true)
	budget = CombatTurnBudget.new()
	result = ClassFeature.execute(owner, command.payload.feature, null, budget) if command != null else {}
	h._assert(not result.get("success", false) and budget.action_available and owner.inventory.to_dict() == before and recipient.numeric_resource_pools[destination_id].current == 3, "023: destination filling after command creation refuses the entire inventory payment")
	recipient.numeric_resource_pools[destination_id].current = 0
	# Real awaited-choice mutation, before the command is built.
	var mutate := func() -> void: owner.inventory.take_instance(selected[1])
	var stale: Dictionary = await h._perform_numeric_pool_exchange_menu_activation(combat, owner, 0, str(feature.id), token, destination, "", mutate)
	h._assert(stale.get("payment_menu_found", false) and stale.get("restoration_menu_found", false) and stale.get("action_available", false) and recipient.numeric_resource_pools[destination_id].current == 0 and not owner.inventory.get_instance(selected[0]).is_empty(), "023: selected-copy loss during actual destination choice refuses without a substitute, result or Action payment")
	owner.inventory.add_item("torch")
	choices = ResourcePoolRules.exchange_payment_sources(owner, policy)
	token = choices[0] if not choices.is_empty() else ""
	selected = ResourcePoolRules._inventory_exchange_source(token)
	before = owner.inventory.to_dict().duplicate(true)
	var success: Dictionary = await h._perform_numeric_pool_exchange_menu_activation(combat, owner, 0, str(feature.id), token, destination)
	var unspent_ok := true
	for id in before.copies.records:
		if id not in selected and owner.inventory.get_instance(str(id)) != before.copies.records[id]: unspent_ok = false
	h._assert(success.get("payment_menu_found", false) and success.get("restoration_menu_found", false) and not success.get("action_available", true) and recipient.numeric_resource_pools[destination_id].current == 1 and selected.all(func(id): return owner.inventory.get_instance(id).is_empty()) and unspent_ok, "023: actual feature controls consume only both exact selected copies, preserve sibling state and restore the selected party pool once")
	before = owner.inventory.to_dict().duplicate(true)
	h._assert(_command(owner, feature, token, destination) == null and owner.inventory.to_dict() == before and recipient.numeric_resource_pools[destination_id].current == 1, "023: repeated inventory choice cannot replay the exchange")
	return owner.inventory.to_dict().duplicate(true)


static func _command(owner: Character, feature: Dictionary, payment: String, destination: String) -> CombatCommand:
	return CombatCommand.from_hud_for_character("use_feature", {"feature":{"id":feature.id,"selected_payment_source_instance_id":payment,"selected_restoration_source_instance_id":destination}}, owner)
