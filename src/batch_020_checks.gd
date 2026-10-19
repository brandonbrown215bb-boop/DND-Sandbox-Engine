class_name Batch020Checks
extends RefCounted

static func load_fixtures() -> void:
	DataLoader._load_json_file("res://data/fixtures/batch_020/classes/condition_auras.json", "class")


static func actor(id: String, class_id: String) -> Character:
	var character := Character.new()
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 10, "DEX": 10, "CON": 12, "INT": 10, "WIS": 10, "CHA": 16})
	character.initialize(id, "human", class_id, scores)
	character.character_id = id
	return character


static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "Batch 020: loaded plain and renamed standalone condition-aura definitions")
	var base_clock := GameManager.campaign_elapsed_seconds
	GameManager.campaign_elapsed_seconds = 0
	for suffix in ["plain", "changed"]:
		var class_id := "fixture:condition_aura_%s" % suffix
		var bearer := actor("b020_bearer_%s" % suffix, class_id)
		var second := actor("b020_second_%s" % suffix, class_id)
		var recipient := actor("b020_recipient_%s" % suffix, "fighter")
		var party: Array = [
			{"character": bearer, "hex_position": Vector2i.ZERO},
			{"character": recipient, "hex_position": Vector2i(1, 0)},
			{"character": second, "hex_position": Vector2i(2, 0)},
		]
		recipient.add_condition("frightened", 2, "fear:original")
		AuraRules.refresh_party_context(party)
		var original_condition_sources: Dictionary = recipient.condition_sources.get("frightened", {})
		check.call(bearer.get_feature_effect("saving_throw_aura").is_empty() and not recipient.has_condition("frightened") and recipient.conditions.get("frightened", 0) == 2 and original_condition_sources.get("fear:original", 0) == 2, "Batch 020: source-only condition aura suppresses without deleting the original condition source or clock " + suffix)
		check.call(recipient.aura_source_memberships.size() == 2 and recipient.aura_source_memberships.any(func(entry): return entry.get("source_owner_id", "") == bearer.character_id and entry.get("bearer_id", "") == bearer.character_id and entry.get("recipient_id", "") == recipient.character_id), "Batch 020: movement projection retains giver, bearer and recipient identity " + suffix)
		recipient.tick_conditions()
		check.call(not recipient.has_condition("frightened") and recipient.conditions.get("frightened", 0) == 1, "Batch 020: the original duration keeps ticking under suppression " + suffix)
		party[0]["hex_position"] = Vector2i(10, 0)
		AuraRules.refresh_party_context(party)
		check.call(not recipient.has_condition("frightened"), "Batch 020: leaving one overlapping suppressor leaves the other active " + suffix)
		second.add_condition("incapacitated", 1, "fixture:incapacitated")
		party[2]["hex_position"] = Vector2i(10, 0)
		AuraRules.refresh_party_context(party)
		check.call(recipient.has_condition("frightened"), "Batch 020: condition returns only after the last suppressor ends " + suffix)
		party[0]["hex_position"] = Vector2i.ZERO
		AuraRules.refresh_party_context(party)
		check.call(not recipient.has_condition("frightened"), "Batch 020: re-entry suppresses the same condition without reacquisition " + suffix)
		var radius := int(bearer.get_feature_effect("condition_immunity_aura").get("radius_feet", 0))
		party[0]["hex_position"] = Vector2i.ZERO
		party[1]["hex_position"] = Vector2i(3, 0)
		party[2]["hex_position"] = Vector2i(10, 0)
		AuraRules.refresh_party_context(party)
		check.call(recipient.has_condition("frightened") == (radius < 15), "Batch 020: renamed neutral definition applies its authored radius " + suffix)
		if suffix == "plain":
			recipient.remove_condition("frightened")
			recipient.add_condition("frightened", 1, "fear:expires-under-mask")
			party[1]["hex_position"] = Vector2i(1, 0)
			party[0]["hex_position"] = Vector2i.ZERO
			AuraRules.refresh_party_context(party)
			recipient.tick_conditions()
			party[0]["hex_position"] = Vector2i(10, 0)
			AuraRules.refresh_party_context(party)
			check.call(not recipient.conditions.has("frightened") and not recipient.has_condition("frightened"), "Batch 020: an expired condition cannot return when suppression later ends")
	GameManager.campaign_elapsed_seconds = base_clock
	DataLoader.load_all_data()
