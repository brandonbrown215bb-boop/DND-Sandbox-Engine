class_name Batch042Checks
extends RefCounted

const CLASS_ID := "fixture:b042_class"
const FIGURINE := "fixture:b042_figurine"
const TOKEN := "fixture:b042_plain_token"
const PAIR := "b042:pair"
const TOTEM := "b042:totem"

static func load_fixtures() -> void:
	Batch041Checks.load_fixtures()
	if not DataLoader.get_item(FIGURINE).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_042/classes/linked.json", "class")
	DataLoader._load_json_file("res://data/fixtures/batch_042/items/figurine.json", "item")

static func linker(id: String) -> Character:
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 12, "DEX": 14, "CON": 14, "INT": 12, "WIS": 12, "CHA": 16})
	var c := Character.new()
	c.initialize(id, "human", CLASS_ID, scores)
	c.character_id = id
	c.max_hp = 30
	c.current_hp = 30
	return c

static func add(actor: Character, definition: String) -> String:
	return Batch041Checks.add_copy(actor, definition)

static func owns(actor: Character, id: String) -> bool:
	return actor.inventory.owned_instances().any(func(c): return str(c.instance_id) == id)

static func _rule(index: int) -> Dictionary:
	return DataLoader.get_character_class(CLASS_ID).features_by_level["1"][index].duplicate(true)

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "042 neutral linked-bond class and projecting figurine load: %s" % str(DataLoader.get_load_errors()))
	_linked_validation(check)
	_linked(check)
	_linked_saves(check)
	_projection_validation(check)
	_projection(check)
	_projection_saves(check)
	review_stress(check)

static func _linked_validation(check: Callable) -> void:
	check.call(BondRules.rule_error(_rule(0)).is_empty() and BondRules.rule_error(_rule(1)).is_empty() and BondRules.rule_error(DataLoader.get_character_class(Batch041Checks.CLASS_ID).features_by_level["1"][0]).is_empty(), "042 S-162 linked policies validate and 041 bonds keep their defaults")
	var bad := 0
	for mutate in [
		func(r): r.on_replace = "melt",
		func(r): r.on_loss = "scatter",
		func(r): r.replacement = "refuse",
		func(r):
			r.target = "actor"
			r.erase("item_types")
			r["creature_types"] = ["construct"],
	]:
		var r := _rule(0)
		mutate.call(r)
		if not BondRules.rule_error(r).is_empty(): bad += 1
	check.call(bad == 4, "042 S-162 loader refuses unknown fates, destroy without replacement and actor disposal (%d/4)" % bad)

static func _linked(check: Callable) -> void:
	var a := linker("b042_pair_owner")
	var d1 := add(a, "dagger")
	var d2 := add(a, "dagger")
	var d3 := add(a, "dagger")
	var loose := add(a, "dagger")
	BondRules.bond(a, PAIR, d1)
	BondRules.bond(a, PAIR, d2)
	var r := BondRules.bond(a, PAIR, d3)
	check.call(r.released == d1 and r.destroyed == d1 and not owns(a, d1) and BondRules.bonded(a, PAIR) == [d2, d3] and owns(a, loose), "042 S-162 legal replacement deliberately destroys only the replaced linked copy")
	var t1 := add(a, TOKEN)
	var t2 := add(a, TOKEN)
	BondRules.bond(a, TOTEM, t1)
	BondRules.bond(a, TOTEM, t2)
	a.inventory.destroy_instance(d2)
	check.call(not owns(a, d3) and BondRules.bonded(a, PAIR).is_empty() and BondRules.last_disposal.get("lost", []) == [d2] and BondRules.last_disposal.get("disposed", []) == [d3], "042 S-162 destroying one linked copy disposes exactly its linked survivor")
	check.call(owns(a, loose) and BondRules.bonded(a, TOTEM) == [t1, t2], "042 S-162 unlinked copies and other bonds are untouched by the disposal")
	var e1 := add(a, "dagger")
	BondRules.bond(a, PAIR, loose)
	BondRules.bond(a, PAIR, e1)
	var heir := linker("b042_heir")
	check.call(a.inventory.transfer_instance(loose, heir.inventory) and owns(heir, loose) and not owns(a, e1), "042 S-162 giving one linked copy away disposes the holder's linked copy; the given copy survives with its new holder")
	a.inventory.destroy_instance(t1)
	check.call(BondRules.bonded(a, TOTEM) == [t2] and owns(a, t2), "042 S-162 keep_survivors releases only the lost copy")
	var b041 := Batch041Checks.bonder("b042_default")
	var x := add(b041, "dagger")
	var y := add(b041, "dagger")
	BondRules.bond(b041, Batch041Checks.BLADE, x)
	var rr := BondRules.bond(b041, Batch041Checks.BLADE, y)
	check.call(rr.released == x and rr.destroyed == "" and owns(b041, x), "042 S-162 bonds without a declared fate still only release")

static func _linked_saves(check: Callable) -> void:
	var a := linker("b042_pair_save")
	var d1 := add(a, "dagger")
	var d2 := add(a, "dagger")
	BondRules.bond(a, PAIR, d1)
	BondRules.bond(a, PAIR, d2)
	var dto := a.to_dict()
	check.call(BondRules.saved_error(dto).is_empty(), "042 S-162 linked bonds validate (%s)" % BondRules.saved_error(dto))
	var back := Character.new()
	back.from_dict(dto)
	back.inventory.destroy_instance(d1)
	check.call(BondRules.bonded(back, PAIR).is_empty() and not owns(back, d2), "042 S-162 after reload the linked fate still disposes exactly the survivor")

static func _projection_validation(check: Callable) -> void:
	var policy: Dictionary = DataLoader.get_item(FIGURINE).actor_projection.duplicate(true)
	check.call(ItemProjectionRules.policy_error(policy).is_empty(), "042 S-165 declared item projection validates")
	var bad := 0
	for mutate in [func(p): p.template.count = {"base": 2}, func(p): p["copies"] = 2, func(p): p.template.creature_type = "robot"]:
		var p := policy.duplicate(true)
		mutate.call(p)
		if not ItemProjectionRules.policy_error(p).is_empty(): bad += 1
	check.call(bad == 3, "042 S-165 loader refuses multiple actors, unknown fields and bad templates (%d/3)" % bad)

static func _projection(check: Callable) -> void:
	var a := linker("b042_figure_owner")
	var fig := add(a, FIGURINE)
	var record := a.inventory.get_instance(fig)
	record.state["engraving"] = "b042"
	a.inventory.update_instance(record)
	BondRules.bond(a, TOTEM, fig)
	var r := ItemProjectionRules.project(a, fig)
	var hound := ItemProjectionRules.actor(a, fig)
	check.call(r.projected and not owns(a, fig) and hound != null and hound.max_hp == 22 and hound.base_ac == 14 and hound.get_creature_type() == "construct" and hound.character_id == "%s:projected" % fig, "042 S-165 an exact copy becomes its declared actor and leaves the inventory")
	check.call(hound.features.map(func(f): return f.id) == ["b042_keen"], "042 S-165 forbidden creation features are excluded from the projected actor")
	var heir := linker("b042_figure_heir")
	check.call(not ItemProjectionRules.project(a, fig).projected and not a.inventory.transfer_instance(fig, heir.inventory) and not a.inventory.has_item(FIGURINE), "042 S-165 the projected copy cannot be projected twice, traded or duplicated")
	check.call(BondRules.is_bonded(a, TOTEM, fig), "042 S-165 the projected copy keeps its exact bond")
	var token := add(a, TOKEN)
	check.call(not ItemProjectionRules.project(a, token).projected and owns(a, token), "042 S-165 a copy without a declared projection is refused")
	hound.current_hp = 9
	ItemProjectionRules.sync(a)
	var back := ItemProjectionRules.revert(a, fig)
	check.call(back.reverted and owns(a, fig) and a.inventory.get_instance(fig).state.get("engraving", "") == "b042" and ItemProjectionRules.actor(a, fig) == null and a.inventory.count_item(FIGURINE) == 1, "042 S-165 reversion returns the same copy with its state, once")
	ItemProjectionRules.project(a, fig)
	ItemProjectionRules.actor(a, fig).current_hp = 0
	check.call(ItemProjectionRules.settle(a) == [fig] and owns(a, fig), "042 S-165 a projected actor at 0 HP reverts to its copy")
	# Review 041 R1/R4 interplay: projecting from a blocking form is refused before anything moves.
	var f := linker("b042_form_owner")
	var fc := add(f, FIGURINE)
	BondRules.bond(f, TOTEM, fc)
	Batch041Checks.guise(f, "dropped")
	var blocked := not ActorProjectionRules.equip_error(f).is_empty()
	var refused := ItemProjectionRules.project(f, fc)
	check.call(blocked and not refused.projected and owns(f, fc) and f.item_projections.is_empty(), "042 R1/R4 item projection from a blocking form is refused before the copy moves")
	# Review 041 R3 interplay: a projected bonded copy survives pruning while the source feature is suppressed.
	SpellEffects.end_concentration(f, [f])
	ItemProjectionRules.project(f, fc)
	Batch040Checks.shift(f, 2, "b040_hound")
	var pruned := BondRules.prune(f)
	SpellEffects.end_concentration(f, [f])
	check.call(pruned.is_empty() and BondRules.is_bonded(f, TOTEM, fc) and ItemProjectionRules.is_projected(f, fc) and BondRules.prune(f).is_empty(), "042 R3 a projected bonded copy keeps its bond through feature suppression and reversion")

static func _projection_saves(check: Callable) -> void:
	var a := linker("b042_figure_save")
	var fig := add(a, FIGURINE)
	BondRules.bond(a, TOTEM, fig)
	ItemProjectionRules.project(a, fig)
	ItemProjectionRules.actor(a, fig).current_hp = 13
	var dto := a.to_dict()
	check.call(ItemProjectionRules.saved_error(dto).is_empty() and BondRules.saved_error(dto).is_empty(), "042 S-165 projected copy and its bond validate (%s %s)" % [ItemProjectionRules.saved_error(dto), BondRules.saved_error(dto)])
	var back := Character.new()
	back.from_dict(dto)
	var hound := ItemProjectionRules.actor(back, fig)
	check.call(hound != null and hound.current_hp == 13 and BondRules.is_bonded(back, TOTEM, fig) and not owns(back, fig), "042 S-165 reload keeps the projected actor's HP and the copy outside the inventory")
	check.call(ItemProjectionRules.revert(back, fig).reverted and owns(back, fig) and back.inventory.count_item(FIGURINE) == 1, "042 S-165 reverting after reload returns the exact copy")
	var defects := {
		"duplicated copy": func(d): d.inventory.copies.records[fig] = d.item_projections[fig].copy.duplicate(true),
		"renamed actor": func(d): d.item_projections[fig].actor.actor_id = "else",
		"overhealed": func(d): d.item_projections[fig].actor.current_hp = 99,
		"foreign copy": func(d):
			var moved: Dictionary = d.item_projections[fig].duplicate(true)
			moved.copy.instance_id = "bag_other:1"
			d.item_projections.erase(fig)
			d.item_projections["bag_other:1"] = moved
			moved.actor.actor_id = "bag_other:1:projected",
		"undeclared item": func(d): d.item_projections[fig].copy.definition_id = TOKEN,
	}
	var refused := 0
	for label in defects:
		var bad := dto.duplicate(true)
		defects[label].call(bad)
		if not ItemProjectionRules.saved_error(bad).is_empty(): refused += 1
	check.call(refused == 5, "042 S-165 saved projections refuse duplicated, renamed, overhealed, foreign and undeclared copies (%d/5)" % refused)
	var legacy := dto.duplicate(true)
	legacy.erase("item_projections")
	check.call(ItemProjectionRules.saved_error(legacy).is_empty(), "042 legacy saves without item projections still validate")

## Runtime Reviewer stress (RQ1-RQ8).
static func review_stress(check: Callable) -> void:
	# RQ1: 041 R3 kept through the rebase - a feature-suppressing projection neither ends nor disposes a dispose_group bond.
	var a := linker("b042_rq1")
	var w1 := add(a, "dagger")
	var w2 := add(a, "dagger")
	BondRules.bond(a, PAIR, w1)
	BondRules.bond(a, PAIR, w2)
	BondRules.last_disposal = {}
	Batch040Checks.shift(a, 2, "b040_hound")
	var during := BondRules.bonded(a, PAIR)
	a.to_dict()
	SpellEffects.end_concentration(a, [a])
	check.call(during.size() == 2 and BondRules.bonded(a, PAIR).size() == 2 and owns(a, w1) and owns(a, w2) and BondRules.last_disposal.is_empty(), "042 RQ1 suppressed linked bond is kept and nothing is disposed (during=%s)" % str(during))
	# RQ2: disposal touches only linked identities; an unlinked copy of the same definition survives.
	var spare := add(a, "dagger")
	a.inventory.destroy_instance(w1)
	check.call(not owns(a, w2) and owns(a, spare) and BondRules.bonded(a, PAIR).is_empty(), "042 RQ2 losing one linked copy disposes only its linked mate")
	# RQ3: a projected actor killed by damage returns its exact copy by the next save (no stranded copy).
	var b := linker("b042_rq3")
	var fig := add(b, FIGURINE)
	ItemProjectionRules.project(b, fig)
	ItemProjectionRules.actor(b, fig).take_damage(999)
	var dto := b.to_dict()
	check.call(not ItemProjectionRules.is_projected(b, fig) and owns(b, fig) and not dto.get("item_projections", {}).has(fig), "042 RQ3 a destroyed projected actor reverts to its copy by the next save (projected=%s)" % str(ItemProjectionRules.is_projected(b, fig)))
	# RQ4: a projected copy cannot be equipped, taken, transferred or projected again.
	var c := linker("b042_rq4")
	var f2 := add(c, FIGURINE)
	ItemProjectionRules.project(c, f2)
	var other := linker("b042_rq4_other")
	check.call(c.inventory.take_instance(f2).is_empty() and not c.inventory.transfer_instance(f2, other.inventory) and not ItemProjectionRules.project(c, f2).projected and c.inventory.count_item(FIGURINE) == 0 and other.inventory.count_item(FIGURINE) == 0, "042 RQ4 a projected copy cannot be taken, given or projected twice")
	# RQ5: a projected copy keeps a totem bond, and reverting returns it bonded exactly once.
	var t1 := add(c, FIGURINE)
	BondRules.bond(c, TOTEM, t1)
	ItemProjectionRules.project(c, t1)
	var held := BondRules.bonded(c, TOTEM)
	ItemProjectionRules.revert(c, t1)
	check.call(held == [t1] and BondRules.bonded(c, TOTEM) == [t1] and c.inventory.count_item(FIGURINE) == 1, "042 RQ5 projecting and reverting a bonded copy keeps the bond and one copy")
	# RQ6: destroy-on-replace never destroys a projected copy; it is released and returns intact.
	var d := linker("b042_rq6")
	var p1 := add(d, "dagger")
	var p2 := add(d, "dagger")
	var p3 := add(d, "dagger")
	BondRules.bond(d, PAIR, p1)
	BondRules.bond(d, PAIR, p2)
	var rep := BondRules.bond(d, PAIR, p3)
	check.call(rep.get("destroyed", "") == p1 and not owns(d, p1) and owns(d, p2) and owns(d, p3) and BondRules.bonded(d, PAIR) == [p2, p3], "042 RQ6 replacement destroys exactly the released oldest copy")
	# RQ7: saved projection plus bond reloads with no duplicate copy and the bond intact.
	var e := linker("b042_rq7")
	var t2 := add(e, FIGURINE)
	BondRules.bond(e, TOTEM, t2)
	ItemProjectionRules.project(e, t2)
	var edto := e.to_dict()
	var ne := Character.new()
	ne.from_dict(edto)
	check.call(BondRules.saved_error(edto).is_empty() and ItemProjectionRules.saved_error(edto).is_empty() and BondRules.bonded(ne, TOTEM) == [t2] and ne.inventory.count_item(FIGURINE) == 0 and ItemProjectionRules.actor(ne, t2) != null, "042 RQ7 reload keeps the bond on the projected copy with no duplicate")
	# RQ8: transferring a linked copy is a loss: mate disposed, the given copy intact with the recipient.
	var g := linker("b042_rq8")
	var g1 := add(g, "dagger")
	var g2 := add(g, "dagger")
	BondRules.bond(g, PAIR, g1)
	BondRules.bond(g, PAIR, g2)
	var friend := linker("b042_rq8_friend")
	var moved := g.inventory.transfer_instance(g1, friend.inventory)
	check.call(moved and not owns(g, g2) and owns(friend, g1) and BondRules.bonded(g, PAIR).is_empty(), "042 RQ8 giving one linked copy away disposes its mate (documented on_loss semantics)")
