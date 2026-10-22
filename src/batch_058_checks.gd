class_name Batch058Checks
extends RefCounted
## Batch 058 (S-155): uncapped creature lists and mixed kinds from one cast.

const BONES := "fixture:b058_raise_bones"

static func load_fixtures() -> void:
	Batch054Checks.load_fixtures()
	if not DataLoader.get_spell(BONES).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_058/spells/raise_bones.json", "spell")

static func cast(owner: Character, n: int) -> Dictionary:
	return {"source_id": "spell:%s:b058_%d" % [owner.character_id, n], "caster_id": owner.character_id, "spell_id": BONES, "concentration": false, "conditions": []}

## A loaded fixture spell with one effect replaced, for loader checks.
static func _spell(id: String, effect: Dictionary) -> Dictionary:
	var s: Dictionary = DataLoader.get_spell(id).duplicate(true)
	s.effects = [effect]
	return s

static func run(check: Callable) -> void:
	load_fixtures()
	var spell := DataLoader.get_spell(BONES)
	var effect := CreatedActorRules._effect(spell)
	check.call(DataLoader.get_load_errors().is_empty() and CreatedActorRules.is_mixed(effect) and CreatedActorRules.templates(effect).size() == 2, "058 raise-bones fixture loads as a mixed cast: %s" % str(DataLoader.get_load_errors()))
	# No inherent cap: ten distinct authored options load.
	var menagerie: Dictionary = CreatedActorRules._effect(DataLoader.get_spell(Batch054Checks.MENAGERIE)).duplicate(true)
	var many: Array = []
	for i in 10:
		var t: Dictionary = menagerie.options[0].duplicate(true)
		t.id = "b058_kind_%d" % i
		many.append(t)
	menagerie.options = many
	var many_error := SharedSpell.content_error(_spell(Batch054Checks.MENAGERIE, menagerie))
	check.call(many_error.is_empty() and CreatedActorRules.templates(menagerie).size() == 11, "058 a create_actor effect may list eleven creatures; no building-block cap (%s)" % many_error)
	var bad := []
	for mutate in ["shape", "formula", "single", "size", "command"]:
		var e: Dictionary = effect.duplicate(true)
		match mutate:
			"shape": e.mix = {"count": e.mix.count, "extra": 1}
			"formula": e.mix = {"count": {"base": 0}}
			"single": e.erase("options")
			"size": e.options[0].size = "large"
			"command": e.options[0].command = {"default": "act_freely"}
		bad.append(SharedSpell.content_error(_spell(BONES, e)))
	check.call(bad.all(func(x): return not str(x).is_empty()), "058 loader refuses a malformed mix, a bad total, a single kind, mixed sizes and mixed command policies (%s)" % str(bad))
	check.call(CreatedActorRules.counts(effect, {}, 0) == [1] and CreatedActorRules.counts(effect, {}, 1) == [1, 2, 3], "058 the shared total follows SRD Animate Dead: 1 at 3rd level, +2 per slot level above")
	var c := Batch031Checks._character("b058_owner", 20)
	var refused := [CreatedActorRules.create(c, cast(c, 1), effect.template, 4, spell, -1, {"b058_skeleton": 2, "b058_zombie": 2}), CreatedActorRules.create(c, cast(c, 2), effect.template, 4, spell, -1, {"b054_owl": 1}), CreatedActorRules.create(c, cast(c, 3), effect.template, 4, spell, -1, {}), CreatedActorRules.create(c, cast(c, 4), effect.template, 4, spell, -1, {"b058_skeleton": 0})]
	check.call(refused.all(func(r): return not r.created) and c.spell_effects.is_empty() and CreatedActorRules.actors(c).is_empty(), "058 too many, an undeclared kind, an empty or zero mix create nothing and leave no record")
	var made := CreatedActorRules.create(c, cast(c, 5), effect.template, 4, spell, -1, {"b058_skeleton": 1, "b058_zombie": 2})
	var live := CreatedActorRules.actors(c)
	var names: Array = live.map(func(a): return a.character_name)
	var zombie: Array = live.filter(func(a): return a.character_name == "Zombie 2")
	check.call(made.created and made.count == 3 and names == ["Skeleton 1", "Zombie 2", "Zombie 3"] and zombie.size() == 1 and zombie[0].base_ac == 8 and zombie[0].max_hp == 15 and zombie[0].speed == 4 and live[0].base_ac == 14 and live[0].max_hp == 13, "058 one cast creates one Skeleton and two Zombies with their own SRD stats and unique ids (%s)" % str(names))
	check.call(CreatedActorRules.attack_profile(c, zombie[0]).name == "Slam" and CreatedActorRules.attack_profile(c, live[0]).name == "Shortsword" and CreatedCommandRules._template(c, zombie[0]).id == "b058_zombie", "058 each actor reads its own kind's attack and command template")
	zombie[0].current_hp = 6
	CreatedActorRules.sync(c)
	var dto: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var rec: Dictionary = dto.spell_effects[cast(c, 5).source_id]
	check.call(CreatedActorRules.saved_record_error(dto, rec).is_empty(), "058 checklist (b): a mixed record passes the saved-record check: %s" % CreatedActorRules.saved_record_error(dto, rec))
	var tampered := []
	for mutate in ["unknown", "missing", "record_id", "hp", "more"]:
		var r: Dictionary = rec.duplicate(true)
		match mutate:
			"unknown": r.created_actors.actors[0].template_id = "b054_owl"
			"missing": r.created_actors.actors[0].erase("template_id")
			"record_id": r.created_actors.template_id = "b058_zombie"
			"hp": r.created_actors.actors[0].current_hp = 14 # Above the Skeleton's 13.
			"more": for i in 2: r.created_actors.actors.append({"actor_id": "%s:actor:%d" % [r.source_id, 4 + i], "current_hp": 1, "template_id": "b058_zombie"})
		tampered.append(CreatedActorRules.saved_record_error(dto, r))
	check.call(tampered.all(func(x): return not str(x).is_empty()), "058 saves with an undeclared kind, a missing kind, a record-level kind, HP over the kind's maximum or too many actors are refused (%s)" % str(tampered))
	var legacy: Dictionary = JSON.parse_string(JSON.stringify(Batch054Checks.cast(c, 9)))
	var c2 := Batch031Checks._character("b058_legacy", 20)
	CreatedActorRules.create(c2, Batch054Checks.cast(c2, 1), CreatedActorRules._effect(DataLoader.get_spell(Batch054Checks.MENAGERIE)).template, 1, DataLoader.get_spell(Batch054Checks.MENAGERIE), 2)
	var dto2: Dictionary = JSON.parse_string(JSON.stringify(c2.to_dict()))
	check.call(legacy is Dictionary and CreatedActorRules.saved_record_error(dto2, dto2.spell_effects[Batch054Checks.cast(c2, 1).source_id]).is_empty(), "058 legacy single-kind records (no per-actor kind) still validate")
	var back := Character.new()
	back.from_dict(dto)
	var again: Array = CreatedActorRules.actors(back).map(func(a): return "%s:%d" % [a.character_name, a.current_hp])
	check.call(again == ["Skeleton 1:13", "Zombie 2:6", "Zombie 3:15"], "058 checklist (d): reload rebuilds each actor from its own kind and HP (%s)" % str(again))
