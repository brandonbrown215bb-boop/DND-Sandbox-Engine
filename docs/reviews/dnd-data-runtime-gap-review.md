# D&D data-to-runtime gap review

Reviewed 2026-10-11 against the current working tree and Windows Godot 4.7 stable.

**Status: structural first pass; the full review remains in progress.** The inventory and reproduced findings below remain useful evidence, but they do not establish comprehensive coverage of mechanics expressed in descriptions. The earlier completion claim was premature.

The [description-to-runtime review and coverage ledger](dnd-description-runtime-review.md) track the remaining work and newly adjudicated mechanics. All 37 core species traits, 36 skill references, the complete monster/spell domains, 353 core/fixture class units, 50 core/fixture subclass units and all 435 core item units have now been reviewed. Other domains remain explicitly pending. Production probes reproduced ignored values, broken form projection/expiry, Monk survival/defense and cadence gaps, Elusive spell attacks, Incarnate entitlement, Tome list scope and a shared Countercharm choice gap. The item probe also reproduced a resistance potion that poisons, Poison's missing damage, an ignored versatile die and unconditional Arrow-Catching AC. Actual winner attribution uses the [production registration table](dnd-runtime-source-ownership.json); fallback metadata misidentify 371 entries.

The owner's current request is documentation of distance and smallest wiring, with implementation later. The [wiring map](dnd-runtime-wiring-map.md) identifies existing hooks, missing connections and dependencies, separating connection fixes, parameter migration, shared operations, missing world capabilities and source repair. No gameplay implementation is part of this audit.

The project is **partly data-driven, but most of its rules catalog cannot yet execute independently of content-specific code**. There are two separate problems: authored data is sometimes ignored or overwritten, and the shared runtime cannot express many behaviors in that data. Adding more JSON records alone will not close either gap.

The intended boundary should remain the one in [ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md): code implements generic operations and world access; data supplies content rules, numbers, predicates, choices, progression, costs and recovery. Adding or renaming content that uses existing capabilities must require no loader, dispatcher, UI or save registration for its identity. New observable world capabilities can still require generic engine code.

## Scope and evidence

This first pass inventories all 276 JSON files in `data/core`, `data/mods`, `data/fixtures`, `5etools raw`, `_staging`, and the four root references (`items.json`, `races.json`, `skills.json`, `loot.json`). It checks record shapes, operation vocabularies, source ownership and runtime consumers. Representative suspect boundaries were reproduced in production GDScript. Mechanics expressed in descriptions have not yet been comprehensively traced to runtime behavior; this remains required by the original whole-project review. External book fidelity is a separate evidence question and does not excuse missing review of descriptions already present in the project.

The production loader has zero errors and 25 warnings about rejected effectless class features. Counts below come from its actual registries after manifest overrides and code curation, not from adding up JSON IDs. Mods currently contribute no records. Fixtures and staging are not loaded by default. Manifest metadata, backups, saves, generated indexes and test output are not additional rule catalogs.

| Domain | Records in core source files | Unique loaded records | What the inventory establishes |
|---|---:|---:|---|
| Base classes | 14 | 14 | Twelve core milestone classes plus parked Artificer/Mystic. Presence does not mean complete behavior. |
| Subclasses | 5 | 5 | Champion, Fiend Patron, Open Hand, Abjurer and Diviner; partial feature coverage. |
| Species/races | 9 | 9 | 37 trait entries; only 5 have nonempty effect arrays. Some other traits have working top-level fields such as Darkvision. |
| Items | 435 | 289 | 104 weapons, 32 armor, 8 shields, 57 consumables, 73 tools, 6 components, 7 currency, 1 ring and 1 wand. Only 28 records have nonempty effects; base-stat items do not necessarily need effects. |
| Spells | 410 | 362 | **12 shared, 122 native-available, 228 unavailable** in the exported noncombat context. Availability is not full support. |
| Monsters | 696 | 481 | 680 trait entries; only 1 declares the shared zero-HP rule type. 364 attack-effect entries use 101 distinct types. |
| Event tables | 4 | 4 | Authored choices/checks/effects use the existing event vocabulary. |
| Campaigns | 1 | 1 | Crown uses existing map, event, room, objective and encounter adapters. |
| **Total** | **1,574** | **1,165** | Duplicate sources are reconciled through the manifest. |

Supporting artifacts:

- [Per-record inventory](dnd-data-runtime-inventory.csv): all 1,165 winning records, their source locators, fields and structural operation flags. These flags deliberately do not claim gameplay certification.
- [Detailed inventory and observations](dnd-data-runtime-inventory.json): source hashes, per-class feature counts, species trait IDs, monster effect frequencies, quarantined features, spell level breakdown and probe outputs.

The twelve core classes contain 244 top-level source features: 212 survive loading, 28 are explicitly disabled and 4 are rejected as effectless. Six use the common active self-effect executor; 52 name native resolvers. **No resolver label does not imply shared execution**: Rogue, Bard, Warlock and Wizard also have content-specific callers and helpers. All core class/subclass files together contain 297 source features and 233 loaded features, including the parked classes.

There are still 45 files in `_staging/staged`, containing 305 features, 225 disabled. Abjurer and Diviner now also exist in core, so those staging counts must not be added to production as unique subclasses. The other staging trees contain extracts, duplicate versions and templates. Root references contain 2,451 items, 158 races, 97 subraces, 36 skill entries and multiple loot-table families; none is read by the production loader. Raw class files mix sources/editions. These are migration inputs, not additional supported content.

## Findings, in practical priority order

### 1. Fix now — accepted data can disappear before or during execution

**What happens.** Normal monster construction copies selected fields and drops other modeled fields. The attack rider resolver silently ignores unknown operations. Species grants have similar breaks between loading, character creation and roll evaluation.

**Production observations:**

- A Skeleton loses its JSON `damage_vulnerabilities: ["bludgeoning"]` when `_setup_combat_monsters` creates the encounter actor. `CombatAction.resolve_damage` already supports vulnerability; the connecting projection is missing.
- An Owl loses `senses`, `proficiency_bonus`, `fly_speed_feet` and `climb_speed_feet` through the same construction path. Its Darkvision is 120 feet in data. Temporary monster Character projections assign proficiency 2 unconditionally; changing source proficiency cannot affect that path.
- A monster `bonus_damage` rider returns an empty result and leaves target HP unchanged. That type occurs **120 times** in loaded attack data. The normal rider resolver handles only `poison_save`, `restrain`, `paralyze_save`, `corrode_armor` and `reduce_max_hp`: **347 of 364 rider entries are outside that vocabulary**. This is operation coverage, not a count of 347 distinct monsters or unsupported complete stat blocks.
- Even recognized `reduce_max_hp` riders are partial: production probes show `necrotic_dealt`/`acid_dealt` reduce nothing and `requires_charmed` does not gate the reduction. The description pass also traced all monster traits: ordinary enemy turns have no general Multiattack, legendary-action/resistance, recharge, regeneration or prose spellcasting consumer. The typed Zombie zero-HP rule is a working shared exception; Ogre Zombie's prose-only rule is not.
- An Elf Wizard finishes creation with weapon proficiency `["simple"]` and no Longbow proficiency even though `elf_weapon_training` declares it. Class assignment replaces the racial list; the later proficiency fallback looks at racial `features` rather than `traits`.
- A Gnome Wizard has no INT save advantage. `gnome_gnomish_cunning` is prose with an empty effects array; the save query evaluates class features, not a shared set of trait effects.

**Why the owner should care.** Characters and monsters can look fully specified while fighting differently from their data. This undermines balancing, homebrew editing and player trust even before a larger interpreter is built.

**Smallest reasonable fix.** Preserve fields already supported by settlement/perception when constructing actors, merge acquisition grants, and add capability validation for declared monster operations. Make an unsupported action or trait explicitly partial/unavailable before commitment instead of silently skipping it. Do not disable every existing monster wholesale: retain deliberately bounded encounters while declaring their supported subset. Translate extra typed damage through the existing damage boundary as the next small shared operation.

**Source:** [monster construction](../../src/combat/combat_state.gd) lines 643–705 and 1657–1680; [monster riders and damage](../../src/combat/combat_action.gd) lines 555–562 and 1503–1553; [character acquisition and saves](../../src/characters/character.gd) lines 702–747, 1187–1203 and 1259–1274; [Gnome data](../../data/core/races/gnome.json).

### 2. Fix now — JSON is not consistently authoritative

**What happens.** Code supplies or selects rule policy by exact class, feature, spell, weapon or item ID. Some code tables overwrite authored fields; other behaviors ignore authored numerical effects.

| Concrete code policy | Data that should own it | Observable consequence |
|---|---|---|
| `CURATED_SPELL_ACCESS`, `CURATED_PACT_MAGIC`, `CURATED_FEATURE_EFFECTS`, `CURATED_SPELL_EFFECTS`, `CURATED_MONSTER_TYPES` | Class spell access, slot progression, feature effects, creature types | Loaded records can have semantics not present in their winning source file. Class cantrip/known-spell projections are overwritten by curated lists; newer `spell_list_ids` paths also exist. |
| `FighterRules.MASTERIES`, weapon property ID lists, Monk weapon ID lists | Weapon categories, properties, mastery references | A weapon's rules can change when its ID changes; curated masteries/categories can overwrite authored values. |
| `SpellSupport.AVAILABLE_SLICES`, named resolver branches and spell-specific benefits | Capability requirements, steps, modifiers and triggers | Renaming native spells disables them, even when all their fields are retained. |
| `magic_item_saving_bonus` and Wand command/HUD branches | Item equip/attunement effects, activation, charge costs and depletion policy | New item definitions cannot reuse the same behaviors without engine changes. |
| `CreatedCreatureRules.FORMS` and named form helpers | Referenced creature templates and projection/ownership policy | Created Skeleton/Zombie stats differ from natural catalog actors; editing the catalog does not uniformly change both. The new zero-HP trait is shared, but the whole created creature is not. |

**Production observations:** renaming Fire Bolt to a namespaced ID preserves availability; renaming Shield or Magic Missile disables availability. A renamed native Barbarian resolver feature is rejected with `Resolver has no registered behavior for this feature`. A renamed Ring of Protection can be equipped and attuned but grants 0 bonus. Changing the original ring's two JSON bonuses to 7 still grants 1. The latter proves numerical data is ignored, not merely that a renamed ID lacks a button.

The class description pass also confirms that Rage's native timer overrides declared effect durations and disappears when the feature is renamed; Bardic Inspiration's native range ignores its payload. A renamed generic self-heal executes its authored formula and use cost correctly. These are concrete migration boundaries, not a reason to replace working shared operations.

**Why the owner should care.** Copying, renaming or editing data will not reliably produce the intended game behavior. An author must know hidden engine exceptions, creating recurring maintenance work.

**Smallest reasonable fix.** Move static content tables into their winning definitions and make code read those fields. For already modeled effects, read effect parameters rather than item identity. Replace availability lists with capability checks as each mechanic migrates. Keep existing native paths explicitly transitional until the replacement has a normal-controls proof; do not simply delete the lists and expose unimplemented casts.

**Source:** [loader curation](../../src/autoload/data_loader.gd) lines 23–232, 470–483 and 1042–1132; [weapon curation](../../src/characters/fighter_rules.gd) lines 8–17 and 80–104; [spell availability](../../src/spells/spell_support.gd); [spell dispatch](../../src/spells/spell_resolver.gd); [ring behavior and focus identity lists](../../src/characters/inventory.gd) lines 153–167 and 365–436; [Wand command](../../src/combat/combat_command.gd) lines 41–58 and [HUD](../../src/combat/combat_hud.gd) lines 589–595; [created forms](../../src/characters/created_creature_rules.gd) lines 5–7 and 137–179.

### 3. Fix now — shared execution is a bounded subset, not a common rules language yet

**What happens.** `SharedStepExecutor` is a real shared engine, but it currently offers attack/save/damage/effect steps for spells and save/replace-HP steps for zero-HP events. Its gates refer to an earlier hit/miss/save. It does not expose general queries, expressions, choices, event subscriptions, reactions, conditional payment, invocation of data-defined procedures or actor/world transitions. Class activations still route through `ClassFeature`/`EventResolver`, while temporal rules have focused token/ward/rest runtimes.

**Why the owner should care.** A long list of rule-named operations or empty native `resolver` records still requires content-specific code for each new mechanic. This blocks reuse across classes, species, creatures and items. Already working tokens, wards and slot recovery do not establish that arbitrary triggers and effects are supported.

**Smallest reasonable fix.** Extend the existing runtime only for a selected real behavior: e.g. one generic typed-damage component invoked after a hit, with event facts and per-target outcomes. Then add the next required query/choice/trigger/cost capability and migrate its consumers. Keep one execution owner and the existing damage, budget, clock and identity adapters. Do not build a new monster interpreter or implement the entire proposed DSL before shipping another useful slice.

**Source:** [step types and capability validation](../../src/combat/shared_step_executor.gd) lines 6–29 and 65–124; [shared spell fields/effects](../../src/spells/shared_spell.gd) lines 6–12 and 54–105; [common feature restrictions and native exceptions](../../src/characters/class_feature.gd) lines 9–44 and 128–220; [event vocabulary](../../src/events/event_resolver.gd) lines 6–15; [token](../../src/characters/roll_token_rules.gd), [ward](../../src/characters/ward_rules.gd) and [rest](../../src/characters/rest_rules.gd) capability constants.

### 4. Fix when touched — new rules need generic acquisition, controls and durable state

**What happens.** Class choice/save handling and player/AI commands still encode particular rule families. Generic persistent rule instances and content-driven control descriptions are absent. Timed spell grants, tokens and wards already have bounded source-owned persistence; other families use named fields, save exceptions and zone lists.

Examples: Wizard spellbook/mastery/signature choices and Sorcerer/Warlock progression have named save validation. Ring/Wand controls are ID-specific. Monster AI can issue only attack, move, move-attack, cast-spell or none; it cannot choose a declared recharge ability, reaction, multiattack sequence or legendary action. Its offensive spell picker ignores steps-only spells without a top-level attack/damage marker. Shared exploration only offers bounded single/self party effects and single-object attacks. Multi-target exploration and general zones are not shared.

One control defect is **Fix now**: Countercharm's ordinary combat choice collector only reads the legacy failed-save condition field. A valid shared Frightened grant is recognized by the save resolver but yields no player reaction choice or observers. The isolated production probe reproduces this without relying on injected reaction decisions. Reuse the existing condition query in the collector and protect that normal-control boundary with a meaningful check.

**Why the owner should care.** Defining an effect is insufficient if players/AI cannot select it, acquire its choices, retain its state or recover it safely. Simply widening a schema would create inaccessible rules or saves that depend on bespoke code.

**Smallest reasonable fix.** As each mechanic is selected, let its definition provide the generic choices/actions and let state be keyed by definition/source/owner with validated versions. Reuse existing owned commands and safe save preflight. Generalize a bounded state family first; preserve schema-2 and legacy files. Mid-combat/mid-choice saving is not required to finish current data-driven content and is not authorized by this review.

**Source:** [progression/save validation](../../src/characters/class_progression.gd) lines 624–813; [Character serialization](../../src/characters/character.gd) `to_dict`/`from_dict`; [spell persistence exceptions](../../src/spells/spell_effect_persistence.gd) lines 29–73; [zone transfer](../../src/dungeon/local_room_combat.gd) `capture_spell_zones`; [AI commands](../../src/combat/ai_command.gd) line 7; [AI spell choice](../../src/ai/ai_controller.gd) `_choose_offensive_spell`; [shared exploration](../../src/dungeon/local_room_shared_spells.gd) lines 5–16.

### 5. Fix when touched — some data has lost the semantics the engine would need

**What happens.** Imported records and staging often contain abbreviated prose, empty effects or heuristic defaults rather than executable rules. A richer engine cannot recover omitted actions, numbers or restrictions reliably from those records.

The class importer drops features above level 5, truncates descriptions at 300 characters, guesses activation from words such as `action`, and supplies default uses/recovery. It does not translate subclass mechanics into an executable shared contract. The monster importer extracts simplified attack-shaped records, guesses attack ability from range, and creates a default Claws attack if it recognizes none. Of 481 loaded monsters, 466 lack explicit creature type, 477 lack structured senses and only one has explicit `spells`/`spell_slots`, despite 47 `spellcasting` trait entries. Missing-source-field counts are not proof that every creature requires that field.

Species are mixed versions and many abilities are prose-only. Root skill/loot/item/species references and staging are deliberately outside loader paths. Adding those paths recursively would introduce collisions and unsupported semantics rather than activate the missing rules.

**Why the owner should care.** Runtime migration could faithfully execute an incomplete or guessed record. That would meet a superficial “JSON-only” goal while retaining wrong behavior.

**Smallest reasonable fix.** For the selected mechanic, pin source/version, retain complete relevant clauses and explicit unresolved dependencies, then author its executable operations. Preserve import staging and manifest winners. Do not interpret empty effects as success or infer rules from descriptions. Leave Artificer/Mystic outside the core-12 milestone.

**Source:** [importer](../../src/convert_all_5etools.py) lines 280–316 and 667–717; [loader discovery](../../src/autoload/data_loader.gd) lines 341–364; [source reconciliation direction](../content_pipeline.md); source hashes and field counts in the accompanying inventory.

## Capability map across all domains

This maps the remaining data requirements to shared capabilities, rather than recommending a separate native helper for every name. Proposed names below describe behavior; they are **not executable schema syntax**.

| Capability needed | Existing data/examples blocked or tied to code | Current boundary / smallest extension |
|---|---|---|
| Unified grants and acquisition | Species defenses/proficiencies, class/subclass choices, feat and background references | Class passive/choice support exists; species are separate. Merge grants and expose owned effects from every grant source. There are no production feat/background registries; broader creation is a content-and-engine gap. |
| Queries and bounded formulas | Class vs total level, proficiency-scaled uses, creature type/size, armor/weapon prerequisites, conditional bonuses | Small level tables and fixed formula labels work. Add only required typed predicates/expressions; multiclass levels and slot composition are absent (`get_class_level` is single-class). |
| General roll modification | Species save advantage, Lucky, Sneak Attack eligibility, Magic Resistance, Legendary Resistance, metamagic | Stored pre-roll replacement works; other changes use named callers. Supply test facts and explicit replacement/modifier timing, costs and limits. |
| Ordered creature attacks and typed damage | Multiattack (160 traits), bonus damage (120 riders), save-based breaths and other attack riders | Player/monster base attacks and five rider types work. Use shared steps for selected creature actions; typed components must settle once through existing damage code. |
| Events, reactions and scoped counters | On-hit/on-damage abilities, regeneration/death bursts, recharge, legendary actions, Rage, Action Surge | Zero-HP, token, ward and rest events are bounded proofs. Add declared subscriptions, timing/order, turn/round/rest scopes and conflict/refusal policy as needed. |
| Choice workflows and conditional cost | Cunning Strike, metamagic, resource conversion, reactions and attack replacement | Named UI prompts and budgets exist. Data must declare legal choices and when payment commits; cancellation/resume retains previous outcomes. |
| Modifier/condition definitions | Shield (+5), Shield of Faith (+2), Mage Armor (13 + DEX), Barkskin floor (17), racial defenses | Some shared conditions are supported, but their numerical benefit lives in code. Define modifiers/formulas and combination policy; unsupported conditions must refuse rather than be inert labels. |
| Item activation and equip rules | Protection rings, charged wands, imported magic weapons/tools/consumables | Copy identity, attunement, daily charge recovery, base damage/AC, tools/components and a few consumable effects work. Read equip/activation effects and charge-to-spell policy generically. Focus compatibility is currently named class/item lists. |
| Spatial effects and ongoing areas | Spike Growth, Moonbeam, auras, breath lines/cylinders, walls, moving zones | Hex targeting, LOS, some elevation/movement and named zones work. Shared spell geometry is sphere/cone/cube; turn/entry/movement events and area lifecycle need shared descriptors. Exact volumes/cover remain bounded world gaps. |
| Actor/template lifecycle and forms | Wild Shape, familiars, steeds, Animate Dead/Objects, Polymorph, created Zombie | Existing identity ledgers and bounded helpers are valuable. Move template/projection, control, initiative, command, duration/reversion and excess-damage policy into data. Do not duplicate natural/created stats in code. |
| Campaign time and rest policy | Trait-specific resting, Hit Dice spending, regeneration/recharge and delayed effects | Short/Long Rest and Arcane Recovery are reachable; Hit Dice spending is absent. Rest durations, survival size tables and named recovery resets are still code policy. Extend event/recovery rules as a selected mechanic requires. |
| World changes and adjudication | Illusions/social commands, Divination, Wish, portals/planes, creation/transmutation, long-term recovery | Room/object/corpse/clock adapters already support bounded outcomes. Add missing observable operations or a typed human-adjudication path before claiming complete behavior; descriptive JSON cannot supply a missing world model. |
| Compatibility and recovery | New rule instances, selections, counters, effects and changed definitions | Schema-2 preflight and bounded state validation exist. General content-owned state/compatibility is unfinished; retain missing-content refusal, source cleanup and no replayed permanent grants. |
| Capability-driven reachability | Native spell allowlist, steps-only monster spells, namespaced features/items | Validate host capabilities and generate controls from owned action definitions. Availability must describe context and partial behavior, not simply registry membership. |

**Concrete availability mismatch:** `animate_objects` is reported available by `SpellSupport`, while the current checkpoint records missing normal casting, command/initiative and exploration integration. This review reproduced its availability result, not a completed Animate Objects cast. Gate it by the implemented host capability before treating it as usable.

## What is already worth keeping

- Twelve shared spells: Acid Splash, Burning Hands, Cone of Cold, Cure Wounds, Fire Bolt, Fireball, Healing Word, Hold Person, Inflict Wounds, Poison Spray, Sacred Flame and Shield of Faith.
- Ordered steps with per-target gates, shared area rolls and bounded suspend/resume.
- JSON zero-HP replacement, stored roll-token pools, ward pools/projection and rest slot recovery. The namespaced Dread Husk, Oracle, Runeguard and Leyline Savant fixtures exercise reuse without registering each new identity. Broader acceptance evidence remains in the [current checkpoint](../operations/current.md); this review did not rerun that entire batch.
- Stable inventory-copy/world/owner identities, campaign time, source-owned cleanup, owned commands, one damage settlement boundary and save preflight.

These are migration foundations. The proposed class and creature DSLs are not implemented. The modding guide's sentence saying ordered mixed checks are unsupported is stale relative to current source and the shared-spell contract; it should be corrected when that guide is touched.

## Example of a bounded later implementation

**Make a creature's declared extra typed damage execute through shared ordered resolution.** Preserve supported actor fields at the encounter boundary and reject/diagnose unsupported declared action operations before commitment. Use an existing `bonus_damage` attack plus a namespaced copy with different dice/type; neither should need an identity branch. Reuse `SharedStepExecutor` and `CombatAction.resolve_damage`, with one execution owner.

Acceptance should demonstrate actual AI/player reachability, an unchanged miss, both damage components on a hit, correct mitigation/concentration/ward interaction per declared damage occurrence, one action/payment, and a renamed definition retaining behavior. Keep one small card; do not make the complete capability map its scope. Static content tables and the ring/proficiency defects can be repaired as bounded data-authority fixes alongside their owning domains.

When deciding whether a converted rule is done, trace the whole path: **winning data → owned actor grants → available action → legal choices → cost → execution → cleanup/recovery**. A JSON/schema pass or a native allowlist entry covers only a fraction of that path.

## Verification and limits

Fresh production Godot processes exported the actual registries and reproduced the rename, rider, projection, item-bonus and species observations above. The final probe exited 0 with zero loader errors and no engine errors; the 25 existing loader quarantine warnings remain. Mutations used disposable in-memory records and an isolated profile inside `.artifacts/rules-runtime-audit/profile`; no player save or content definition was changed.

Local ignored evidence: `.artifacts/rules-runtime-audit/export.gd`, `export.tscn`, `export.log`, `runtime.json` and `analyze.py`. The probe can be rerun on this checkout with the existing portable Godot and scene `res://.artifacts/rules-runtime-audit/export.tscn`, then the analyzer; both use production GDScript for behavior and Python only for inventory. The committed JSON/CSV retain the measured results, counts and input hashes if ignored evidence is removed.

No runtime implementation, full combat regression batch, Linux run, exhaustive published-rule reconciliation, or manual UI acceptance was performed. CodeGraph was attempted but unavailable; Agent Ground tools were not exposed; team routing/role contracts were absent, so the review proceeded solo. The review does not supersede roadmap priorities, save boundaries or ADRs.
