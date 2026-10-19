class_name Batch027Checks
extends RefCounted

static func load_fixtures() -> void:
	DataLoader._load_json_file("res://data/fixtures/batch_027/classes/guards.json", "class")

static func actor(id: String, class_id: String = "fighter") -> Character:
	var character := Batch020Checks.actor(id, class_id)
	character.willingness = "willing"
	for feature in character.features:
		if feature.has("resource_pool"): ResourcePoolRules.acquire(character, feature, str(feature.id))
	return character

static func source(actor: Character, feature_id: String) -> String:
	for id in actor.numeric_resource_pools:
		if actor.numeric_resource_pools[id].definition_id == actor.get_feature(feature_id).get("resource_pool", {}).get("id"): return id
	return ""

static func give(supplier: Character, recipient: Character, suffix: String = "plain") -> Dictionary:
	var feature_id: String = "fixture:027_guard_" + suffix
	var rules := TemporaryHPRules.new()
	var budget := CombatTurnBudget.new()
	budget.reset(supplier, [])
	var request := rules.begin(supplier, feature_id, source(supplier, feature_id), budget, recipient)
	if request.is_empty(): return {"success":false, "availability":TemporaryHPRules.availability(supplier, supplier.get_feature(feature_id), budget, source(supplier, feature_id)), "eligible":TemporaryHPRules.eligible(recipient), "pools":supplier.numeric_resource_pools}
	return rules.settle(request, true, [supplier, recipient])

static func run(check: Callable) -> void:
	load_fixtures()
	var clock := int(GameManager.campaign_elapsed_seconds)
	GameManager.campaign_elapsed_seconds = 0
	for suffix in ["plain", "renamed"]:
		var supplier := actor("b027_supplier_" + suffix, "fixture:027_class_" + suffix)
		var recipient := actor("b027_recipient_" + suffix)
		var feature_id: String = "fixture:027_guard_" + suffix
		var feature := supplier.get_feature(feature_id)
		check.call(not feature.is_empty() and TemporaryHPRules.content_error(feature).is_empty(), "027 loaded neutral/renamed grant " + suffix)
		var source_id := source(supplier, feature_id)
		var budget := CombatTurnBudget.new()
		budget.reset(supplier, [])
		var rules := TemporaryHPRules.new()
		recipient.temp_hp = 12
		var before := recipient.to_dict().duplicate(true)
		var request := rules.begin(supplier, feature_id, source_id, budget, recipient)
		check.call(request.get("current") == 12 and request.get("incoming") == feature.temporary_hp_grant.amount, "027 offers actual lower incoming amount " + suffix)
		var kept := rules.settle(request, false, [supplier, recipient])
		check.call(kept.get("declined", false) and recipient.to_dict() == before and int(supplier.numeric_resource_pools[source_id].current) == 4 and budget.bonus_action_available, "027 retain leaves exact state, deadline and cost unchanged " + suffix)
		request = rules.begin(supplier, feature_id, source_id, budget, recipient)
		var replaced := rules.settle(request, true, [supplier, recipient])
		var grant := recipient.linked_temporary_hp.duplicate(true)
		check.call(replaced.get("success", false) and recipient.temp_hp == int(feature.temporary_hp_grant.amount) and grant.get("supplier_id") == supplier.character_id and grant.get("recipient_id") == recipient.character_id and int(supplier.numeric_resource_pools[source_id].current) == 3 and not budget.bonus_action_available, "027 smaller replacement binds separate supplier and recipient and pays once " + suffix)
		check.call(not rules.settle(request, true, [supplier, recipient]).get("success", false) and supplier.temporary_hp_supply_serial == 1, "027 replay cannot repay or issue another grant " + suffix)
		check.call(TemporaryHPRules.saved_error(recipient.to_dict(), 0).is_empty(), "027 valid linked checkpoint payload " + suffix)
		recipient.absorb_temporary_hp(1)
		check.call(recipient.linked_temporary_hp == grant, "027 partial absorption retains supplier and original deadline " + suffix)
		if suffix == "plain": check.call(recipient.get_ac() == actor("ac_base").get_ac()+2, "027 live AC consumes recipient linked protection")
		recipient.absorb_temporary_hp(100)
		check.call(recipient.linked_temporary_hp.is_empty() and TemporaryHPRules.bonus(recipient, "ac_bonus") == 0, "027 exhaustion ends linked benefit exactly once " + suffix)
		budget.reset(supplier, [])
		request = rules.begin(supplier, feature_id, source_id, budget, recipient)
		recipient.temp_hp = 1
		check.call(not rules.settle(request, true, [supplier, recipient]).get("success", false) and budget.bonus_action_available and int(supplier.numeric_resource_pools[source_id].current) == 3, "027 stale HP answer refuses before payment " + suffix)
		request = rules.begin(supplier, feature_id, source_id, budget, recipient)
		GameManager.campaign_elapsed_seconds = 1
		check.call(not rules.settle(request, true, [supplier, recipient]).get("success", false), "027 stale clock answer refuses " + suffix)
		GameManager.campaign_elapsed_seconds = 0
		request = rules.begin(supplier, feature_id, source_id, budget, recipient)
		check.call(not rules.settle(request, true, [supplier]).get("success", false), "027 removed recipient refuses " + suffix)
		request = rules.begin(supplier, feature_id, source_id, budget, recipient)
		supplier.numeric_resource_pools[source_id] = supplier.numeric_resource_pools[source_id].duplicate(true)
		check.call(not rules.settle(request, true, [supplier, recipient]).get("success", false), "027 equal-valued reacquired pool cannot settle an older exact-source offer " + suffix)
		var old := rules.begin(supplier, feature_id, source_id, budget, recipient)
		request = rules.begin(supplier, feature_id, source_id, budget, recipient)
		check.call(not rules.settle(old, true, [supplier, recipient]).get("success", false) and rules.settle(request, true, [supplier, recipient]).get("success", false), "027 old generation cannot settle or cancel newer offer " + suffix)
		GameManager.campaign_elapsed_seconds = 60
		TemporaryHPRules.prune(recipient, 60)
		TemporaryHPRules.prune(recipient, 60)
		check.call(recipient.temp_hp == 0 and recipient.linked_temporary_hp.is_empty(), "027 exact expiry removes only current qualifying HP " + suffix)
		GameManager.campaign_elapsed_seconds = 0
		give(supplier, recipient, suffix)
		recipient.temp_hp = 99
		TemporaryHPRules.prune(recipient, 60)
		check.call(recipient.temp_hp == 99 and recipient.linked_temporary_hp.is_empty(), "027 replaced unrelated HP survives old source expiry " + suffix)
		var malformed := feature.duplicate(true)
		malformed.temporary_hp_grant.benefits.ac_bonus = 100
		check.call(not TemporaryHPRules.content_error(malformed).is_empty(), "027 unsupported benefit refuses at content boundary " + suffix)
		var self_source := actor("b027_self_" + suffix, "fixture:027_class_" + suffix)
		check.call(give(self_source, self_source, suffix).get("success", false) and not self_source.linked_temporary_hp.is_empty(), "027 same actor can supply and receive the grant " + suffix)
		var self_source_id := source(self_source, feature_id)
		ResourcePoolRules.remove(self_source, self_source_id)
		check.call(self_source.temp_hp == 0 and self_source.linked_temporary_hp.is_empty(), "027 exact source removal ends its qualifying HP " + suffix)

	var a := actor("b027_aura_a", "fixture:027_class_plain")
	var b := actor("b027_aura_b", "fixture:027_class_renamed")
	var target := actor("b027_aura_recipient")
	var members: Array = [{"character":a, "hex_position":Vector2i.ZERO}, {"character":b, "hex_position":Vector2i(1, 0)}, {"character":target, "hex_position":Vector2i(2, 0)}]
	AuraRules.refresh_party_context(members)
	var offers := AuraProtectionRules.offers(target, "entry_guard")
	check.call(offers.size() == 2 and AuraProtectionRules.bonus(target, "ac_bonus") == 2, "027 overlapping entry protections offer two exact sources without stacking")
	var selected := str(offers.keys()[1])
	check.call(AuraProtectionRules.choose(target, offers, selected) and AuraProtectionRules.bonus(target, "ac_bonus") == 3 and AuraProtectionRules.bonus(target, "save_bonus") == 2, "027 explicit aura choice selects one source's protection")
	var receipts := target.aura_entry_receipts.duplicate(true)
	members[2].hex_position = Vector2i(10, 0)
	GameManager.campaign_elapsed_seconds = 12
	AuraRules.refresh_party_context(members)
	check.call(target.aura_entry_receipts == receipts and AuraProtectionRules.bonus(target, "ac_bonus") == 3, "027 leaving retains timed chosen benefit and original entry deadline")
	members[2].hex_position = Vector2i(2, 0)
	AuraRules.refresh_party_context(members)
	check.call(target.aura_entry_receipts == receipts, "027 reentry does not restart declared once-per-source use")
	GameManager.campaign_elapsed_seconds = 30
	AuraRules.refresh_party_context(members)
	check.call(AuraProtectionRules.offers(target).is_empty() and target.aura_entry_receipts == receipts and not AuraProtectionRules.choose(target, offers, selected), "027 expiry and reentry cannot restart a use or settle stale aura selection")
	check.call(AuraProtectionRules.saved_error(target.to_dict(), 30).is_empty(), "027 expired aura receipts remain valid to prevent replay after recovery")
	var member_source := actor("b027_membership_source", "fixture:027_membership_class")
	var member_target := actor("b027_membership_target")
	var member_party: Array = [{"character":member_source, "hex_position":Vector2i.ZERO}, {"character":member_target, "hex_position":Vector2i(1, 0)}]
	AuraRules.refresh_party_context(member_party)
	check.call(AuraProtectionRules.bonus(member_target, "ac_bonus") == 1, "027 membership-only aura protects an actual nearby recipient")
	member_party[1].hex_position = Vector2i(3, 0)
	AuraRules.refresh_party_context(member_party)
	check.call(AuraProtectionRules.bonus(member_target, "ac_bonus") == 0, "027 membership-only protection ends immediately on exit")
	member_party[1].hex_position = Vector2i(1, 0)
	AuraRules.refresh_party_context(member_party)
	check.call(AuraProtectionRules.bonus(member_target, "ac_bonus") == 1, "027 membership-only protection returns on reentry without a timed use")
	member_source.add_condition("incapacitated", 1, "b027-disable")
	check.call(AuraProtectionRules.bonus(member_target, "ac_bonus") == 0, "027 current bearer incapacitation suppresses membership protection")
	check.call(AuraProtectionRules.saved_error(member_target.to_dict(), 30).is_empty(), "027 membership receipt validates independently of combat projection")
	GameManager.campaign_elapsed_seconds = clock
	DataLoader.load_all_data()
