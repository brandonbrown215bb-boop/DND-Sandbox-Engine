# Data-driven gameplay roadmap

Owner direction reconciled 2026-10-09. Build one shared in-process rules
runtime for classes, creatures, spells and their interactions. JSON defines
rule behavior; GDScript interprets supported operations and bridges to the
world. New content using those operations must not require native branches
for its class, creature, spell or feature ID.

[ADR-0018](docs/decisions/0018-shared-data-driven-rules-runtime.md) owns this
direction. [ADR-0017](docs/decisions/0017-shared-json-spell-execution.md) requires
ordered mixed spell checks. The [current checkpoint](docs/operations/current.md)
records accepted evidence and unfinished work; the Quest Board owns the exact
next action. The class and creature design documents supply requirements and
stress cases, not two separate engines or mandatory up-front module scaffolds.

## Next implementation

Define and prove the smallest shared ordered-execution contract against the
existing production pipeline. Start with a simple existing spell, then a new
namespaced definition combining an attack and a save. Give each step explicit
targets, gates and results. Preserve attack damage when a secondary save
succeeds, and resolve an independently declared area after a miss.

The same slice must exercise a suspended decision and one temporal class or
creature rule. Portent's stored replacement token, Zombie's zero-HP replacement
or a ward's damage interception are candidate stress cases; choose one and pin
its source clauses before coding. This tests shared semantics early instead of
migrating a large simple catalog first. Do not promise all three in one card.

Acceptance requires normal selection/commands, visible costs and results,
exactly-once commitment after resume, cancellation/refusal without unintended
cost, source-owned cleanup, and save validation appropriate to durable state.
Run an actual fresh-process recovery for new durable state; same-process disk
reload is insufficient for that claim. Add a renamed/homebrew JSON definition
without loader, UI, dispatcher or persistence registration of its identity.
Existing simple shared spells and affected Crown flows must retain their behavior.

## Delivery after the proof

1. Pin a rules corpus and clause ledger as each mechanic is selected. SRD 5.2.1
   is the current implemented baseline. Broader PHB subclasses and the revised
   monster catalog require their actual source and correction records; extracts
   and importer prose are not certification. Source gathering can overlap the
   first runtime proof; full-catalog verification is not an entry gate.
2. Extend shared queries, ordered steps, costs, choices and source-owned state
   only when a real rule needs them. Establish reaction order, conditional
   payment, scoped counters and conflict diagnostics before translating breadth.
3. Migrate mechanics by shared dependency: rolls/recovery, damage/healing,
   casting/progression, position/perception, actors/forms/objects and delayed
   or adjudicated outcomes. Include interactions with already migrated rules.
4. Reuse the current room, inventory-copy, campaign-clock, corpse and creature
   adapters. Replace rule-specific policy with data progressively. One migrated
   action has one execution owner; the old helper cannot apply it again.
5. Stabilize the authoring and version/compatibility contracts from proven
   examples, then expand the verified catalog. Complete support needs every
   in-scope clause, dependencies and normal player paths, not feature counts.

The longer-term class design covers twelve 2024 PHB classes, forty-eight
subclasses, levels 1–20 and multiclassing. The creature design targets a pinned
revised-rules catalog. These are target scopes, not current release claims.
Artificer, Mystic and later supplements remain separate/parked content.

## Carry-forward work

Animate Objects has partial, unvalidated hooks. Its normal cast module,
owner-following initiative, commands and room controls remain unfinished.
Finger of Death's created Zombie, reversible forms and authored NPC/illusion
interaction also remain open. Preserve this work; integrate it through the
shared capabilities when scheduled, rather than extending named handlers as
the default architecture. Do not expose unfinished paths based on an allowlist.

[Spell foundations](docs/mechanics/spell-foundations.md) and
[Wave 4 acceptance](docs/mechanics/wave4-acceptance.md) retain concrete world
gaps and bounded integration checks. Their historical wave sequence and
class-by-class order no longer choose the next implementation.

## Product and safety boundaries

- Crown remains a level 1–5 campaign with one to four shared-keyboard seats
  and four stable party slots. Higher-level fixtures prove mechanics without
  implying a new campaign. Full Crown readiness is not currently certified.
- Preserve schema-2 `user://saves/dnd2024/` and legacy files. A new interpreter
  state/version contract needs an explicit compatibility decision before
  release; proposed migrations are not authorization to rewrite saves.
- Unsupported mechanics stay unavailable or explicitly partial. Missing host
  capabilities refuse before cost or declare a precise supported approximation.
- Rules requiring fictional judgment need a typed adjudication path before
  claiming full support. A human GM workflow is not implemented today.
- Windows Godot checks own gameplay evidence. Python inventories own structure.
  Human sampling informs usability; it is not a repeated gate on every slice.
- Keep one obvious implementation card. No wholesale CombatState extraction
  or new service, dependency or framework is a prerequisite.

Controllers, networking, publication, friend runs, public-content clearance
and a new high-level campaign remain parked until wanted. The old Gates 0–8
remain historical evidence, not the active dependency chain. Packaging and
fresh-clone checks apply when a publication candidate is actually chosen.
