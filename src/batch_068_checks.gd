class_name Batch068Checks
extends RefCounted
## Batch 068 (S-196/S-210): exact container compartment/content and attached
## part choices, demonstrated with two eligible copies of each container, item,
## host and part. Only the selected identity moves; stale offers refuse before
## anything moves; a settled offer cannot be replayed.

const SAT := Batch043Checks.SATCHEL
const FLASK := Batch043Checks.FLASK
const HOST := Batch044Checks.HOST
const GEM := Batch044Checks.GEM

static func load_fixtures() -> void:
	Batch044Checks.load_fixtures()

static func _ids(list: Array, key: String = "instance_id") -> Array:
	return list.map(func(c): return str(c.get(key, "")))

static func _opt(options: Array, a: String, b: String, k1: String, k2: String) -> Dictionary:
	for o in options:
		if str(o.get(k1, "")) == a and str(o.get(k2, "")) == b: return o
	return {}

static func run(check: Callable) -> void:
	load_fixtures()
	_containers(check)
	_parts(check)
	_review_stress(check)

static func _containers(check: Callable) -> void:
	var a := Batch043Checks.carrier("b068_carrier")
	var s1 := Batch043Checks.add(a, SAT)
	var s2 := Batch043Checks.add(a, SAT)
	var f1 := Batch043Checks.add(a, FLASK)
	var f2 := Batch043Checks.add(a, FLASK)
	var options := ContainerRules.stow_options(a.inventory, f1)
	var pairs: Array = options.map(func(o): return "%s/%s" % [o.container_id, o.compartment])
	pairs.sort()
	var want := ["%s/main" % s1, "%s/sleeve" % s1, "%s/main" % s2, "%s/sleeve" % s2]
	want.sort()
	check.call(pairs == want, "068 S-196 two satchel copies offer all four eligible exact compartments (%s)" % str(pairs))
	check.call(options.all(func(o): return not str(o.label).is_empty()) and options.map(func(o): return o.label).size() == 4, "068 S-196 every compartment option has a label")
	var into := ContainerRules.stow_into(a.inventory, f1, _opt(options, s2, "sleeve", "container_id", "compartment"))
	check.call(into.success and _ids(ContainerRules.contents(a.inventory, s2, "sleeve")) == [f1] and ContainerRules.contents(a.inventory, s1).is_empty() and ContainerRules.contents(a.inventory, s2, "main").is_empty() and Batch043Checks.owns(a, f2), "068 S-196 the chosen second satchel's sleeve gets exactly the chosen flask")
	# Stale: the chosen compartment filled after the offer (sleeve holds 1).
	var stale_full := _opt(ContainerRules.stow_options(a.inventory, f2), s2, "main", "container_id", "compartment")
	var sleeve_offer := {"container_id": s2, "compartment": "sleeve"}
	var before := a.inventory.to_dict()
	var full := ContainerRules.stow_into(a.inventory, f2, sleeve_offer)
	check.call(not full.success and a.inventory.to_dict() == before and Batch043Checks.owns(a, f2), "068 S-196 a full compartment refuses before anything moves")
	# Stale: the offered container left the holder between offer and pick.
	var s1_offer := _opt(ContainerRules.stow_options(a.inventory, f2), s1, "main", "container_id", "compartment")
	var gone := a.inventory.take_instance(s1)
	before = a.inventory.to_dict()
	var stale := ContainerRules.stow_into(a.inventory, f2, s1_offer)
	check.call(not s1_offer.is_empty() and not stale.success and a.inventory.to_dict() == before and Batch043Checks.owns(a, f2), "068 S-196 a container that left between offer and pick refuses; the copy stays put")
	a.inventory.receive_instance(gone)
	# Stale: the offered copy was destroyed between offer and pick.
	var f3 := Batch043Checks.add(a, FLASK)
	var f3_offer := _opt(ContainerRules.stow_options(a.inventory, f3), s1, "main", "container_id", "compartment")
	a.inventory.destroy_instance(f3)
	before = a.inventory.to_dict()
	check.call(not ContainerRules.stow_into(a.inventory, f3, f3_offer).success and a.inventory.to_dict() == before, "068 S-196 a copy destroyed between offer and pick refuses with nothing moved")
	check.call(ContainerRules.stow_into(a.inventory, f2, stale_full).success, "068 S-196 the second flask goes into the chosen main compartment")
	# Take out: two eligible contents in one container; only the chosen copy leaves.
	var held := ContainerRules.content_options(a.inventory, s2)
	var held_ids: Array = _ids(held)
	held_ids.sort()
	var both := [f1, f2]
	both.sort()
	check.call(held_ids == both, "068 S-196 take-out offers both exact contained copies")
	var pick := _opt(held, f1, "sleeve", "instance_id", "compartment")
	var out := ContainerRules.take_out(a.inventory, pick)
	check.call(out.success and str(out.instance_id) == f1 and Batch043Checks.owns(a, f1) and _ids(ContainerRules.contents(a.inventory, s2)) == [f2], "068 S-196 taking out the earlier-stowed copy (not last-out) moves only it")
	before = a.inventory.to_dict()
	var replay := ContainerRules.take_out(a.inventory, pick)
	check.call(not replay.success and bool(replay.get("stale", false)) and a.inventory.to_dict() == before, "068 S-196 replaying a settled take-out refuses; nothing moves twice")
	var f2_pick := _opt(ContainerRules.content_options(a.inventory, s2), f2, "main", "instance_id", "compartment")
	ContainerRules.remove(a.inventory, s2, f2)
	ContainerRules.put(a.inventory, s2, f1, "main")
	before = a.inventory.to_dict()
	var moved := ContainerRules.take_out(a.inventory, f2_pick)
	check.call(not moved.success and a.inventory.to_dict() == before and _ids(ContainerRules.contents(a.inventory, s2)) == [f1], "068 S-196 a take-out offer whose copy already left is stale and the other copy stays")
	# Saves: exact placement survives both save checks and a DTO reload.
	ContainerRules.put(a.inventory, s1, f2, "sleeve")
	var dto := a.to_dict()
	check.call(ContainerRules.saved_error(dto).is_empty() and InventoryCopies.saved_error(dto.inventory).is_empty() and AttachmentRules.saved_error(dto).is_empty(), "068 S-196 chosen placements pass the saved-record checks")
	var back := Character.new()
	back.from_dict(dto)
	check.call(_ids(ContainerRules.contents(back.inventory, s2, "main")) == [f1] and _ids(ContainerRules.contents(back.inventory, s1, "sleeve")) == [f2] and ContainerRules.content_options(back.inventory, s2).size() == 1, "068 S-196 reload keeps each chosen copy in its chosen container and compartment")

static func _parts(check: Callable) -> void:
	var b := Batch044Checks.wearer("b068_wearer")
	var h1 := Batch044Checks.add(b, HOST)
	var h2 := Batch044Checks.add(b, HOST)
	var g1 := Batch044Checks.add(b, GEM)
	var g2 := Batch044Checks.add(b, GEM)
	var options := AttachmentRules.socket_options(b.inventory, g1)
	var pairs: Array = options.map(func(o): return "%s/%s" % [o.host_id, o.socket])
	check.call(pairs.size() == 6 and _opt(options, h2, "gem_b", "host_id", "socket").size() > 0 and _opt(options, h1, "gem_a", "host_id", "socket").size() > 0, "068 S-210 two host copies offer every eligible exact socket (%s)" % str(pairs))
	var at := AttachmentRules.attach_into(b.inventory, g1, _opt(options, h2, "gem_b", "host_id", "socket"))
	check.call(at.success and AttachmentRules.attached(b.inventory, h1).is_empty() and AttachmentRules.attached(b.inventory, h2).keys() == ["gem_b"] and str(AttachmentRules.attached(b.inventory, h2).gem_b.instance_id) == g1, "068 S-210 the chosen part goes into exactly the chosen socket of the chosen host")
	var g2_offer := _opt(AttachmentRules.socket_options(b.inventory, g2), h2, "gem_b", "host_id", "socket")
	check.call(g2_offer.is_empty(), "068 S-210 a filled socket is no longer offered")
	var g2_a := _opt(AttachmentRules.socket_options(b.inventory, g2), h2, "gem_a", "host_id", "socket")
	AttachmentRules.attach(b.inventory, h2, Batch044Checks.add(b, GEM), "gem_a")
	var before := b.inventory.to_dict()
	check.call(not AttachmentRules.attach_into(b.inventory, g2, g2_a).success and b.inventory.to_dict() == before, "068 S-210 a socket filled between offer and pick refuses before anything moves")
	AttachmentRules.detach(b.inventory, h2, "gem_a")
	check.call(AttachmentRules.attach_into(b.inventory, g2, g2_a).success, "068 S-210 the second gem goes into the chosen socket")
	var parts := AttachmentRules.part_options(b.inventory, h2)
	var part_ids: Array = _ids(parts)
	part_ids.sort()
	var both := [g1, g2]
	both.sort()
	check.call(part_ids == both, "068 S-210 detach offers both exact attached parts")
	var pick := _opt(parts, g1, "gem_b", "instance_id", "socket")
	var off := AttachmentRules.detach_part(b.inventory, pick)
	check.call(off.success and str(off.instance_id) == g1 and Batch044Checks.owns(b, g1) and AttachmentRules.attached(b.inventory, h2).keys() == ["gem_a"], "068 S-210 detaching the earlier part (not last-filled) moves only it")
	before = b.inventory.to_dict()
	check.call(not AttachmentRules.detach_part(b.inventory, pick).success and b.inventory.to_dict() == before, "068 S-210 replaying a settled detach refuses")
	var g2_pick := _opt(AttachmentRules.part_options(b.inventory, h2), g2, "gem_a", "instance_id", "socket")
	AttachmentRules.detach(b.inventory, h2, "gem_a")
	AttachmentRules.attach(b.inventory, h2, g1, "gem_a")
	before = b.inventory.to_dict()
	var swapped := AttachmentRules.detach_part(b.inventory, g2_pick)
	check.call(not swapped.success and bool(swapped.get("stale", false)) and b.inventory.to_dict() == before and str(AttachmentRules.attached(b.inventory, h2).gem_a.instance_id) == g1, "068 S-210 a detach offer whose socket now holds another copy is stale; the new part stays")
	var dto := b.to_dict()
	check.call(AttachmentRules.saved_error(dto).is_empty() and ContainerRules.saved_error(dto).is_empty(), "068 S-210 chosen parts pass the saved-record checks")
	var back := Character.new()
	back.from_dict(dto)
	check.call(str(AttachmentRules.attached(back.inventory, h2).get("gem_a", {}).get("instance_id", "")) == g1 and AttachmentRules.attached(back.inventory, h1).is_empty(), "068 S-210 reload keeps the chosen part on the chosen host socket")

## Review 068 stress: state-twin copies, capacity before move, single option.
static func _review_stress(check: Callable) -> void:
	var a := Batch043Checks.carrier("b068_review")
	var s1 := Batch043Checks.add(a, SAT)
	var f1 := Batch043Checks.add(a, FLASK)
	var f2 := Batch043Checks.add(a, FLASK)
	var r1 := a.inventory.get_instance(f1)
	r1.state["charges"] = 3
	r1.state["upgrades"] = ["keen"]
	a.inventory.update_instance(r1)
	var r2 := a.inventory.get_instance(f2)
	r2.state["charges"] = 1
	a.inventory.update_instance(r2)
	ContainerRules.put(a.inventory, s1, f1, "main")
	ContainerRules.put(a.inventory, s1, f2, "main")
	var held := ContainerRules.content_options(a.inventory, s1)
	var pick := _opt(held, f1, "main", "instance_id", "compartment")
	var out := ContainerRules.take_out(a.inventory, pick)
	var back := a.inventory.get_instance(f1)
	check.call(out.success and int(back.state.get("charges", 0)) == 3 and back.state.get("upgrades", []) == ["keen"] and _ids(ContainerRules.contents(a.inventory, s1)) == [f2] and int(ContainerRules.contents(a.inventory, s1)[0].state.get("charges", 0)) == 1, "068 review state-twin copies: the picked copy leaves with its own charges/upgrades; the twin stays untouched")
	# Capacity: a brick that would exceed main's weight is never offered, and a forced stale pick refuses before moving.
	var b1 := Batch043Checks.add(a, Batch043Checks.BRICK)
	var b2 := Batch043Checks.add(a, Batch043Checks.BRICK)
	ContainerRules.put(a.inventory, s1, b1, "main")
	var offers := ContainerRules.stow_options(a.inventory, b2)
	var before := a.inventory.to_dict()
	var forced := ContainerRules.stow_into(a.inventory, b2, {"container_id": s1, "compartment": "main"})
	check.call(_opt(offers, s1, "main", "container_id", "compartment").is_empty() and not forced.success and a.inventory.to_dict() == before and Batch043Checks.owns(a, b2), "068 review over-capacity compartments are not offered and a forged pick refuses with nothing moved")
	# Single eligible option: only one compartment accepts, so the HUD applies it directly.
	var c := Batch043Checks.carrier("b068_review_single")
	var s := Batch043Checks.add(c, SAT)
	var fa := Batch043Checks.add(c, FLASK)
	var fb := Batch043Checks.add(c, FLASK)
	ContainerRules.put(c.inventory, s, fa, "sleeve")
	var one := ContainerRules.stow_options(c.inventory, fb)
	check.call(one.size() == 1 and str(one[0].compartment) == "main" and ContainerRules.content_options(c.inventory, s).size() == 1, "068 review a single eligible compartment/content yields one option (menu skipped)")
	# Options never offer a container whose owner is someone else.
	var other := Batch043Checks.carrier("b068_review_other")
	check.call(ContainerRules.content_options(other.inventory, s).is_empty() and not ContainerRules.take_out(other.inventory, {"container_id": s, "compartment": "sleeve", "instance_id": fa}).success, "068 review another holder cannot list or take out of a container it does not carry")
