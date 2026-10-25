class_name Batch082Checks
extends RefCounted
## Batch 082 (#46 follow-up, S-066). Brandon: "the wording is 'past 1 hour':
## reset only after more than one hour; exactly one hour is allowed. Make the
## code, description and boundary checks agree. This is an authored interruption
## policy, not a universal crafting rule." The paused-site lapse applies only
## when the absence is strictly greater than the item's authored
## away_limit_seconds; exactly the limit keeps progress. No site, no reset rule.

const LOOM := Batch074Checks.LOOM

static func run(check: Callable) -> void:
	Batch074Checks.load_fixtures()
	var prior_dungeon: Dictionary = GameManager.active_dungeon_state
	var def := DataLoader.get_item(LOOM)
	check.call(int(def.work.site.away_limit_seconds) == 3600 and str(def.description).contains("past 1 hour") and str(def.work.on_interrupt) == "reset", "082 S-066 the loom description says 'past 1 hour' and its authored limit is 3600 s with reset")
	for away in [3599, 3600, 3601, 3660]:
		_boundary(check, away)
	_jump(check)
	_saves(check)
	_no_policy(check)
	_fallback_nit(check)
	GameManager.active_dungeon_state = prior_dungeon

## Start at t=0, accrue 1 h, helper steps away at 3600 and stays `away` seconds.
static func _setup(tag: String) -> Array:
	var a := Batch046Checks.actor("b082_a_" + tag)
	var h := Batch046Checks.actor("b082_h_" + tag)
	Batch046Checks._party([a, h])
	Batch074Checks._room({a.character_id: [0, 0], h.character_id: [1, 0]})
	var loom := Batch046Checks.add(a, LOOM)
	WorkRules.start(a, loom)
	WorkRules.join(h, a, loom)
	WorkRules.settle(a, 3600, 3600)
	Batch074Checks._place(h.character_id, [5, 0])
	WorkRules.settle(a, 600, 4200) # away_since = 3600
	return [a, h, loom]

static func _boundary(check: Callable, away: int) -> void:
	var s := _setup(str(away))
	var a: Character = s[0]
	var h: Character = s[1]
	var loom: String = s[2]
	var r := WorkRules.settle(a, 3600 + away - 4200, 3600 + away)
	var rec := a.inventory.get_instance(loom)
	if away <= 3600:
		check.call(r.size() == 1 and r[0].get("paused", false) and WorkRules.is_active(rec) and WorkRules.progress(rec) == 3600 and int(rec.state.work_away_since) == 3600, "082 S-066 an absence of %d s (not past 1 hour) keeps progress and stays paused" % away)
		Batch074Checks._place(h.character_id, [1, 0])
		WorkRules.settle(a, 60, 3660 + away)
		WorkRules.settle(a, 600, 4260 + away)
		check.call(WorkRules.progress(a.inventory.get_instance(loom)) == 4200, "082 S-066 after a %d s absence the helper returns and work resumes from kept progress (%d)" % [away, WorkRules.progress(a.inventory.get_instance(loom))])
	else:
		check.call(r.size() == 1 and r[0].get("interrupted", false) and int(r[0].at) == 7201 and int(r[0].lost_seconds) == 3600 and WorkRules.progress(rec) == 0 and not WorkRules.is_active(rec), "082 S-066 an absence of %d s is past 1 hour: reset lands at away_since + 3601 (at=%s)" % [away, str(r[0].get("at", "?")) if not r.is_empty() else "none"])
	Batch046Checks._leave([a, h])

static func _jump(check: Callable) -> void:
	var s := _setup("jump")
	var a: Character = s[0]
	var r := WorkRules.settle(a, 3000, 7200) # one span ending exactly at the limit
	check.call(r.size() == 1 and r[0].get("paused", false) and WorkRules.is_active(a.inventory.get_instance(s[2])), "082 S-066 a single jump ending exactly at away_since + limit is allowed")
	r = WorkRules.settle(a, 1, 7201)
	check.call(r.size() == 1 and r[0].get("interrupted", false) and int(r[0].at) == 7201, "082 S-066 one more second is past the limit and resets")
	Batch046Checks._leave([a, s[1]])

static func _saves(check: Callable) -> void:
	var s := _setup("save")
	var a: Character = s[0]
	var loom: String = s[2]
	var dto: Dictionary = JSON.parse_string(JSON.stringify(a.to_dict()))
	var back := Character.new()
	back.from_dict(dto)
	PartyManager.characters[a.character_id] = back
	var r := WorkRules.settle(back, 3000, 7200)
	check.call(r.size() == 1 and r[0].get("paused", false) and WorkRules.progress(back.inventory.get_instance(loom)) == 3600, "082 S-066 after a JSON round trip, exactly 1 hour away still keeps progress")
	r = WorkRules.settle(back, 60, 7260)
	check.call(r.size() == 1 and int(r[0].get("at", -1)) == 7201 and WorkRules.progress(back.inventory.get_instance(loom)) == 0, "082 S-066 after a JSON round trip, past 1 hour resets at away_since + 3601")
	Batch046Checks._leave([back, s[1]])

static func _no_policy(check: Callable) -> void:
	# Site-less work has no away rule: nothing lapses however long it runs.
	var a := Batch046Checks.actor("b082_legacy")
	Batch046Checks._party([a])
	GameManager.active_dungeon_state = {}
	var tome := Batch046Checks.add(a, Batch046Checks.TOME)
	WorkRules.start(a, tome)
	var r := WorkRules.settle(a, 7200, 7200)
	check.call(r.filter(func(x): return x.get("interrupted", false)).is_empty() and WorkRules.is_active(a.inventory.get_instance(tome)) and WorkRules.site_policy(a.inventory.get_instance(tome)).is_empty(), "082 S-066 work with no authored site policy has no away/reset rule")
	WorkRules.stop(a, tome)
	Batch046Checks._leave([a])
	# Interrupt sites cannot author an away limit at all (the limit is pause-only policy).
	var p: Dictionary = DataLoader.get_item(Batch074Checks.KILN).work.duplicate(true)
	p.site["away_limit_seconds"] = 3600
	check.call(not WorkRules.policy_error(p).is_empty(), "082 S-066 the away limit is per-site authored pause policy, refused on interrupt sites")

static func _fallback_nit(check: Callable) -> void:
	var base: Dictionary = Batch081Checks.pwk_policy()
	var good: Dictionary = base.duplicate(true)
	var flat: Dictionary = base.duplicate(true)
	flat.fallback.damage = "5"
	check.call(good.has("fallback") and ZeroHpAftermathRules.fallback_error(good).is_empty() and not ZeroHpAftermathRules.fallback_error(flat).is_empty(), "Review 081 nit: a flat '5' is refused as fallback damage; the declared dice still validate")
