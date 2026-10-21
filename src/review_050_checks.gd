class_name Review050Checks
extends RefCounted
## Runtime Reviewer stress cases for Batch 050 (dawn recovery edges).


static func _spend(a: Character, w: String) -> void:
	FeatureModeRules.activate(a, w, "protect")
	FeatureModeRules.end(a, w, "dismissed")

static func _reload(a: Character) -> Character:
	var back := Character.new()
	back.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	return back

static func run(check: Callable) -> void:
	Batch050Checks.load_fixtures()
	# S1 save/load then dawn, and several dawns.
	var a := Batch050Checks.actor("r050_s1")
	var id := Batch050Checks.wield(a)
	var w := Batch050Checks.ward(id)
	RuleUpgradeRules.choose_alternative(a, w, "edge", "deep@" + id)
	a.feature_uses[w] = 3
	_spend(a, w); _spend(a, w)
	var b := _reload(a)
	var spent_ok := int(b.feature_uses.get(w, -1)) == 1
	OwnedFeatureSources.recover_dawn(b)
	var one := int(b.feature_uses.get(w, -1))
	OwnedFeatureSources.recover_dawn(b); OwnedFeatureSources.recover_dawn(b)
	check.call(spent_ok and one == 3 and int(b.feature_uses[w]) == 3, "R050 S1 spent uses survive reload; dawn refills to the upgraded max 3 and repeated dawns never exceed it (got %d/%d)" % [one, int(b.feature_uses.get(w, -1))])
	# S2 given away spent, dawn at the new holder (carried, unworn), then equip.
	var g := Batch050Checks.actor("r050_s2_giver")
	var gid := Batch050Checks.wield(g)
	var gw := Batch050Checks.ward(gid)
	_spend(g, gw)
	var rec := g.inventory.drop_equipped_instance(Inventory.Slot.WEAPON)
	var r := Batch050Checks.actor("r050_s2_taker")
	r.inventory.receive_instance(rec)
	OwnedFeatureSources.recover_dawn(g)
	var giver_clean := not g.feature_uses.has(gw) or not g.has_feature(gw)
	OwnedFeatureSources.recover_dawn(r)
	r.inventory.equip_instance(Inventory.Slot.WEAPON, gid)
	check.call(giver_clean and int(r.feature_uses.get(gw, -1)) == 2 and InventoryCopies.record_state_error(r.inventory.get_instance(gid)).is_empty(), "R050 S2 a given-away spent blade recharges at its new holder's dawn, not the giver's")
	# S3 dawn while suppressed must refill to the owned max, and suppression must not eat uses.
	var s := Batch050Checks.actor("r050_s3")
	var sid := Batch050Checks.wield(s)
	var sw := Batch050Checks.ward(sid)
	RuleUpgradeRules.choose_alternative(s, sw, "edge", "deep@" + sid)
	s.feature_uses[sw] = 3
	Batch050Checks.mute(s, "r050_mute")
	var during := int(s.feature_uses[sw])
	s.spell_effects.erase("r050_mute")
	FeatureModeRules.refresh(s)
	var after_lift := int(s.feature_uses[sw])
	_spend(s, sw)
	Batch050Checks.mute(s, "r050_mute2")
	OwnedFeatureSources.recover_dawn(s)
	s.spell_effects.erase("r050_mute2")
	check.call(during == 3 and after_lift == 3 and int(s.feature_uses[sw]) == 3, "R050 S3 suppression keeps the upgraded pool (3) and a dawn during suppression refills to the owned max 3 (got during=%d lift=%d dawn=%d)" % [during, after_lift, int(s.feature_uses[sw])])
	# S4 dawn while merged into a form.
	var m := Batch050Checks.actor("r050_s4")
	var mid := Batch050Checks.wield(m)
	var mw := Batch050Checks.ward(mid)
	RuleUpgradeRules.choose_alternative(m, mw, "edge", "deep@" + mid)
	m.feature_uses[mw] = 3
	_spend(m, mw)
	Batch041Checks.guise(m, "merged")
	OwnedFeatureSources.recover_dawn(m)
	check.call(ActorProjectionRules.merged(m, mid) and int(m.feature_uses[mw]) == 3, "R050 S4 a dawn while the blade is merged into a form refills to the owned max 3 (got %d)" % int(m.feature_uses[mw]))
	# S5 acquisition refresh and JSON restore must use owned capacity too.
	Batch050Checks.mute(s, "r050_refresh")
	var dagger := Batch041Checks.add_copy(s, "dagger")
	var equipped := s.inventory.equip_instance(Inventory.Slot.OFFHAND, dagger)
	var restored := _reload(s)
	check.call(equipped and int(s.feature_uses[sw]) == 3 and int(restored.feature_uses[sw]) == 3, "R050 S5 equipping an unrelated item and reloading while suppressed preserve all 3 owned uses")
	OwnedFeatureSources.sync(m)
	check.call(int(m.feature_uses[mw]) == 3, "R050 S5 refreshing acquisition while merged preserves all 3 owned uses")
	# S6 attached copies are owned records too, including nested room storage.
	var host := DataLoader.get_item("dagger").duplicate(true)
	host.id = "fixture:r050_socket_host"
	host.attachments = {"sockets": [{"id": "power", "accepts": [Batch050Checks.BLADE]}]}
	check.call(Batch048Checks._loads(host), "R050 S6 the attachment host is a valid item definition")
	DataLoader.items[host.id] = host
	var c := Batch050Checks.actor("r050_attached")
	var child := Batch050Checks.wield(c)
	var cw := Batch050Checks.ward(child)
	_spend(c, cw)
	c.inventory.unequip(Inventory.Slot.WEAPON)
	var host_id := Batch041Checks.add_copy(c, host.id)
	var attached := AttachmentRules.attach(c.inventory, host_id, child, "power")
	OwnedFeatureSources.recover_dawn(c)
	var child_record: Dictionary = AttachmentRules.attached(c.inventory, host_id).get("power", {})
	check.call(attached.get("success", false) and int(child_record.get("state", {}).get("feature_uses", {}).get(cw, -1)) == 2, "R050 S6 an attached copy recharges at its holder's dawn")
	var stored_host := c.inventory.get_instance(host_id)
	stored_host.state.attached.power.state.feature_uses[cw] = 1
	c.inventory.update_instance(stored_host)
	var host_record := c.inventory.take_instance(host_id)
	var room := {"objects": [{"contents": [host_record]}]}
	OwnedFeatureSources.recover_dawn_rooms([room])
	check.call(int(room.objects[0].contents[0].state.attached.power.state.feature_uses[cw]) == 2 and InventoryCopies.record_state_error(host_record).is_empty(), "R050 S6 an attached copy in a saved room recharges and its containing record remains valid")
	# S7 equipped does not also mean attuned: inactive copies can recharge.
	var conditional := DataLoader.get_item("fixture:b050_bound_blade").duplicate(true)
	conditional.id = "fixture:r050_equipped_dawn"
	conditional.features[0].recharge_while = "equipped"
	check.call(Batch048Checks._loads(conditional), "R050 S7 an attunement item can declare recharge_while equipped")
	DataLoader.items[conditional.id] = conditional
	var d := Batch050Checks.actor("r050_equipped")
	var did := Batch041Checks.add_copy(d, conditional.id)
	d.inventory.equip_instance(Inventory.Slot.WEAPON, did)
	d.inventory.attune_instance(did, d.character_id)
	var dw := Batch050Checks.ward(did)
	_spend(d, dw)
	d.inventory.unattune_instance(did, d.character_id)
	OwnedFeatureSources.recover_dawn(d)
	check.call(d.inventory.equipped_instance_id(Inventory.Slot.WEAPON) == did and not d.has_feature(dw) and int(d.inventory.get_instance(did).state.feature_uses[dw]) == 2, "R050 S7 an equipped but unattuned copy recharges without granting its power")
	d.inventory.unequip(Inventory.Slot.WEAPON)
	var unworn := d.inventory.get_instance(did)
	unworn.state.feature_uses[dw] = 1
	d.inventory.update_instance(unworn)
	OwnedFeatureSources.recover_dawn(d)
	check.call(int(d.inventory.get_instance(did).state.feature_uses[dw]) == 1, "R050 S7 recharge_while equipped refuses a carried unworn copy")
	var rest := {"id": "rest", "type": "mode_choice", "boundary": "rest", "rest": "long_rest", "recharge_while": "equipped", "modes": conditional.features[0].modes}
	check.call(not FeatureModeRules.validate_rule(rest, true).is_empty(), "R050 S7 rest choices refuse the dawn-only recharge_while field")
	# S8 the same owned capacity applies to declared rest recovery.
	var sleeper := Batch049Checks.actor("r050_suppressed_rest")
	var circlet := Batch049Checks.wear(sleeper)
	var focus := Batch049Checks.focus(circlet)
	RuleUpgradeRules.choose_alternative(sleeper, focus, "tuning", "deep@" + circlet)
	sleeper.feature_uses[focus] = 1
	Batch050Checks.mute(sleeper, "r050_long_rest_mute")
	sleeper.long_rest()
	var while_suppressed := int(sleeper.feature_uses[focus])
	sleeper.spell_effects.erase("r050_long_rest_mute")
	check.call(while_suppressed == 3 and int(sleeper.feature_uses[focus]) == 3, "R050 S8 long rest refills the suppressed circlet to its owned upgraded 3 uses")
	var short_item := DataLoader.get_item(Batch049Checks.CIRCLET).duplicate(true)
	short_item.id = "fixture:r050_short_rest_circlet"
	short_item.features[0].uses_per = "short_rest"
	check.call(Batch048Checks._loads(short_item), "R050 S8 the short-rest item definition is valid")
	DataLoader.items[short_item.id] = short_item
	var napper := Batch049Checks.actor("r050_merged_rest")
	var short_id := Batch041Checks.add_copy(napper, short_item.id)
	napper.inventory.equip_instance(Inventory.Slot.HEAD, short_id)
	napper.inventory.attune_instance(short_id, napper.character_id)
	var short_focus := Batch049Checks.focus(short_id)
	RuleUpgradeRules.choose_alternative(napper, short_focus, "tuning", "deep@" + short_id)
	napper.feature_uses[short_focus] = 1
	Batch041Checks.guise(napper, "merged")
	napper.short_rest()
	check.call(ActorProjectionRules.merged(napper, short_id) and int(napper.feature_uses[short_focus]) == 3, "R050 S8 short rest refills a merged item to its owned upgraded 3 uses")
