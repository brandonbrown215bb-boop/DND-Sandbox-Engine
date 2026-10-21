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
