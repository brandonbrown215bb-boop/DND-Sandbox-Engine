class_name Batch054Checks
extends RefCounted
## Batch 054 (S-155): permitted template/count choices and creation refusal.

const MENAGERIE := "fixture:b054_menagerie"

static func load_fixtures() -> void:
	Batch053Checks.load_fixtures()
	if not DataLoader.get_spell(MENAGERIE).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_054/spells/menagerie.json", "spell")

static func cast(owner: Character, n: int) -> Dictionary:
	return {"source_id": "spell:%s:b054_%d" % [owner.character_id, n], "caster_id": owner.character_id, "spell_id": MENAGERIE, "concentration": true, "conditions": []}

static func run(check: Callable) -> void:
	load_fixtures()
	var spell := DataLoader.get_spell(MENAGERIE)
	var effect := CreatedActorRules._effect(spell)
	check.call(DataLoader.get_load_errors().is_empty() and CreatedActorRules.templates(effect).size() == 2, "054 menagerie fixture loads with one alternative template: %s" % str(DataLoader.get_load_errors()))
	var bad := []
	for mutate in ["four", "dup", "broken", "count"]:
		var e: Dictionary = effect.duplicate(true)
		match mutate:
			"four": e.options = [e.options[0], e.options[0], e.options[0], e.options[0]]
			"dup": e.options[0].id = e.template.id
			"broken": e.options[0].erase("attack")
			"count": e.count_choice = "yes"
		bad.append(SharedSpell.content_error({"id": "x", "level": 1, "execution": "shared", "target": "self", "effects": [e]}))
	check.call(bad.all(func(x): return not str(x).is_empty()), "054 loader refuses too many options, duplicate ids, a broken option and a non-boolean count_choice (%s)" % str(bad))
	var hound: Dictionary = effect.template
	var owl: Dictionary = effect.options[0]
	check.call(CreatedActorRules.counts(effect, hound, 0) == [1, 2] and CreatedActorRules.counts(effect, owl, 0) == [1] and CreatedActorRules.counts(DataLoader.get_spell(Batch053Checks.PAIR).effects[0], DataLoader.get_spell(Batch053Checks.PAIR).effects[0].template, 0) == [2], "054 counts: a declared count_choice offers 1..N, otherwise exactly the formula")
	var c := Batch031Checks._character("b054_owner", 20)
	var foreign: Dictionary = DataLoader.get_spell(Batch053Checks.PAIR).effects[0].template
	var refused := [CreatedActorRules.create(c, cast(c, 1), foreign, 1, spell), CreatedActorRules.create(c, cast(c, 2), hound, 1, spell, 3), CreatedActorRules.create(c, cast(c, 3), hound, 1, spell, 0)]
	check.call(refused.all(func(r): return not r.created) and c.spell_effects.is_empty() and CreatedActorRules.actors(c).is_empty(), "054 an undeclared template or count creates nothing and leaves no record")
	var made := CreatedActorRules.create(c, cast(c, 4), owl, 1, spell)
	var two := CreatedActorRules.create(c, cast(c, 5), hound, 1, spell, 2)
	var live := CreatedActorRules.actors(c)
	var ids: Array = live.map(func(a): return a.character_id)
	var owls := live.filter(func(a): return a.character_name == "Owl 1")
	check.call(made.created and made.count == 1 and two.count == 2 and live.size() == 3 and ids.size() == 3 and ids.duplicate().filter(func(i): return ids.count(i) == 1).size() == 3 and owls.size() == 1 and owls[0].base_ac == 11 and owls[0].max_hp == 5 and c.spell_effects[cast(c, 4).source_id].created_actors.template_id == "b054_owl" and not c.spell_effects[cast(c, 5).source_id].created_actors.has("template_id"), "054 the chosen option creates exactly its declared actors with unique identities")
	var dto: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var rec: Dictionary = dto.spell_effects[cast(c, 4).source_id]
	check.call(CreatedActorRules.saved_record_error(dto, rec).is_empty() and CreatedActorRules.saved_record_error(dto, dto.spell_effects[cast(c, 5).source_id]).is_empty(), "054 checklist (b): chosen template and count pass the saved-record check")
	var tampered := []
	for mutate in ["unknown", "empty", "more", "none"]:
		var r: Dictionary = rec.duplicate(true)
		match mutate:
			"unknown": r.created_actors.template_id = "b053_pair_warden"
			"empty": r.created_actors.template_id = ""
			"more": r.created_actors.actors.append({"actor_id": "%s:actor:2" % r.source_id, "current_hp": 5})
			"none": r.created_actors.actors.clear()
		tampered.append(CreatedActorRules.saved_record_error(dto, r))
	check.call(tampered.all(func(x): return not str(x).is_empty()), "054 saves with an undeclared template, an empty id, too many or zero actors are refused (%s)" % str(tampered))
	var back := Character.new()
	back.from_dict(dto)
	var names: Array = CreatedActorRules.actors(back).map(func(a): return a.character_name)
	names.sort()
	check.call(names == ["Hound 1", "Hound 2", "Owl 1"], "054 checklist (d): reload rebuilds each record from its chosen template (%s)" % str(names))
