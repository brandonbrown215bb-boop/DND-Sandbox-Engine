# Crown Campaign Recovery and Delivery Roadmap

**Status:** Canonical execution roadmap

**Updated:** 2026-08-09

**Milestone:** Playable Crown campaign, start to finish, from the repository

**Engine baseline:** Godot 4.7.x

**Supported validation host:** Windows. `run_tests.ps1` is the milestone gate;
`run_tests.sh` is retained as a compatibility helper and does not require native
Linux execution evidence.

This roadmap replaces the earlier phase-completion claims. A feature is not complete because a button, description, data record, or isolated resolver exists. It is complete when a player can reach it through the normal game, it produces the intended result using production data, and the relevant automated and manual gates pass.

`docs/ROADMAP_FUTURE.md` remains an idea backlog. It does not set current priorities.

---

## 1. Milestone outcome

The first milestone is a private, repository-run game in which one to four local players can create characters, recruit companions into empty party slots, complete the Crown campaign, defeat its final encounter, and reach a provisional ending.

The target experience is a broad and mechanically deep tabletop RPG in a top-down pixel-art presentation. Breadth does not permit decorative mechanics: every option exposed to a player must work.

### Product contract

- The active party contains at most four characters.
- Each local player creates one player character.
- Recruitable companions may fill remaining party slots.
- One exploration leader moves the party as a unit.
- Followers have a visual formation but no authoritative independent exploration position.
- Every active character, including companions, is assigned to a local player for combat decisions.
- One player may control multiple characters.
- Leadership and controller assignments can be changed outside combat and blocking conversations.
- Saving is supported only at explicit safe locations or states. Mid-combat and active-dungeon saves are rejected.
- Crown is the target baseline campaign; this is not a current completion claim.
- Campaign completion ends at a provisional completion screen. New Game+, ascension, and post-game play are future systems.
- Current 5E-derived content is for private play. Rules, content, presentation, and campaign data must remain separable so private content can later be replaced.

### Explicit non-goals for this milestone

- Online multiplayer or rollback networking
- Public distribution or storefront packaging
- A mod manager or visual content editor
- Independent split-party exploration
- New Game+, ascension, or a complete post-game loop
- Mechanics beyond the Crown campaign's confirmed level cap
- Public-release licensing clearance

Export support may be developed opportunistically, but the milestone gate requires a documented repository setup and launch path, not a packaged build.

---

## 2. Delivery rules

These rules apply to every task and gate.

1. **Normal-path proof:** Tests must construct characters and content through the same loaders and creation paths used by players. Test-only injection may test a resolver, but cannot prove a feature is wired.
2. **No decorative options:** An ability, spell, item, setting, or action with no implemented effect must be hidden, rejected with a clear explanation, or completed before the gate passes.
3. **Production-data proof:** At least one test per player-facing mechanic must use the production record by stable ID.
4. **Deterministic content:** Load order and override behavior must not depend on filesystem enumeration.
5. **Safe persistence:** Save files contain versioned data transfer objects, never live Godot objects, scene nodes, input-device IDs, or stringified engine types.
6. **Named integration tests:** Each integration scenario owns its scene/process lifecycle, timeout, log, and result. One scenario cannot prevent later scenarios from running.
7. **Evidence before status:** A gate is complete only when its evidence is recorded. Passing assertions alone does not override engine errors, skipped scenarios, or an unreachable player path.
8. **Debug/release boundary:** Developer control surfaces may exist in development, but must be visibly gated and absent from any friend-facing launch configuration.
9. **Documentation follows behavior:** Status documents are updated in the same change that alters shipped behavior.
10. **One vertical path stays playable:** After Gate 3, every later gate must preserve a known-good start-to-finish development path, even while content coverage expands.

### Task states

- `pending`: accepted but not started
- `in_progress`: owned and actively changing
- `blocked`: cannot proceed without a named decision or prerequisite
- `review`: implementation and automated checks complete; human or full-flow validation remains
- `done`: acceptance criteria and required gate evidence are recorded

---

## 3. Critical path

```mermaid
flowchart LR
    G0["Gate 0: Honest baseline"] --> G1["Gate 1: Trustworthy test gate"]
    G1 --> G2["Gate 2: Deterministic content"]
    G2 --> G3["Gate 3: Safe campaign state"]
    G3 --> G4["Gate 4: Party and local control"]
    G4 --> G5["Gate 5: Rules-engine proof"]
    G5 --> G6["Gate 6: Broad class and spell coverage"]
    G6 --> G7["Gate 7: Crown start-to-finish"]
    G7 --> G8["Gate 8: Repository-playable candidate"]

    G2 --> G5
    G3 --> G7
    G4 --> G7
```

Gates are sequential on the critical path. Work may be prepared in parallel, but a later gate cannot be declared complete while an earlier gate remains open.

---

## 4. Gate 0 — Honest baseline

**Objective:** Make the repository tell the truth about what works, what is reachable, and what remains unverified.

**Current evidence:** [Gate 0 evidence](docs/gate0_evidence.md), [feature matrix](docs/feature_matrix.md), [Crown campaign band](docs/crown_campaign_band.md), and [confirmed defect register](docs/defect_register.md). Status: `done`; the recorded P0/P1 defects are carried into later gates.

| ID | Priority | Task | Acceptance criteria |
|---|---:|---|---|
| BASE-01 | P0 | Replace stale completion claims | This roadmap is canonical; architecture and changelog entries no longer describe unwired class features, spells, save-anywhere, or skipped integration scenarios as complete. |
| BASE-02 | P0 | Establish supported engine version | Godot 4.7.x is documented; the exact validation version is recorded; launch commands do not rely on a developer-specific absolute path. |
| BASE-03 | P0 | Inventory player-facing features | Produce a generated matrix of classes, levels, features, spells, items, conditions, settings, scenes, and whether each is loaded, reachable, implemented, and tested. |
| BASE-04 | P0 | Register confirmed defects | Track duplicate IDs, empty feature effects, empty class spell lists, broken save state, missing terminal scenes, repeatable milestones, test-harness destruction, and runtime Beckett exposure as owned work items. |
| BASE-05 | P1 | Confirm Crown campaign band | Record starting level, intended final level, required dungeons, required milestones, final encounter, and minimum companion roster. Current planning assumes levels 1–5 until this inventory proves otherwise. |
| BASE-06 | P1 | Separate evidence from generated debris | Ignore or relocate disposable logs and generated dogfood output. Preserve intentional fixtures. Stale error logs must not look like current failures. |

### Gate 0 exit

- One feature matrix exists and is reproducible.
- Every confirmed P0/P1 defect has an owner or explicit `pending` status.
- No roadmap section labels a feature complete without a normal-path proof.
- Main boot behavior and current test counts are recorded against a named Godot build.

---

## 5. Gate 1 — Trustworthy test and developer loop

**Objective:** A green test command must mean the project parsed, booted, executed every named scenario, and exited without unexpected engine errors.

**Current evidence:** [Gate 1 evidence](docs/gate1_evidence.md). Status: `done`; the complete isolated suite is green from a cache-free committed tree with a recovery-mode first scan, 263 stable logic assertions (the earlier 242 note was stale), explicit scenario markers, hard timeouts, and disposable save/settings roots.

| ID | Priority | Task | Acceptance criteria |
|---|---:|---|---|
| TEST-01 | P0 | Replace file-by-file `--script` preflight | Bootstrap a clean checkout's ignored Godot class cache, then parse in project context so autoload identifiers resolve. The gate reports real parse failures without falsely rejecting valid project scripts. |
| TEST-02 | P0 | Isolate viewport scenarios | Combat boot, AI loop, victory, overworld, dungeon, event, character creation, shop, save/load, settings, and character sheet each run in a fresh Godot process or fully isolated tree. |
| TEST-03 | P0 | Add hard timeouts and result markers | Every scenario has a bounded runtime, explicit pass marker, non-zero failure exit, and captured log. Timeout is a failure, never an apparent success. |
| TEST-04 | P0 | Treat engine errors as failures | Unexpected `SCRIPT ERROR`, parse errors, invalid calls, leaked test-owned nodes, and resource errors fail the owning scenario. Document narrowly allowed warnings. |
| TEST-05 | P0 | Provide the supported Windows entry point | Add a PowerShell runner that resolves an environment-provided or explicit portable Godot executable without hard-coded home paths. Retain the shell runner as compatibility-only tooling. |
| TEST-06 | P1 | Split logic and integration suites | Fast logic checks run first and scene integration runs second; each can be invoked alone. The fixed-seed campaign smoke is introduced and owned by Gate 7. |
| TEST-07 | P1 | Isolate save and settings data roots | Tests use disposable `user://` roots and cannot consume or alter a developer's real saves/settings. |
| TEST-08 | P1 | Publish a concise test manifest | List every named test scenario and the player-facing contract it covers. A test count without a contract map is not sufficient. |

### Gate 1 exit

- A clean checkout has one documented Windows test command. The compatibility shell runner is not completion evidence.
- Intentionally breaking an autoload reference fails the parse/boot gate quickly.
- Intentionally hanging one viewport scenario fails that scenario and does not hide the results of the others.
- The complete suite produces an enumerated pass/fail result and no unexplained Godot `ERROR` output.
- The current logic suite remains green; the measured 263-assertion count is stable and the earlier 242 note is explained in the evidence.

---

## 6. Gate 2 — Deterministic, validated content

**Objective:** Production data loads predictably, preserves curated mechanics, and fails loudly when content is ambiguous or structurally invalid.

| ID | Priority | Task | Acceptance criteria |
|---|---:|---|---|
| DATA-01 | P0 | Define content layers and precedence | Separate imported source material, curated mechanical records, campaign content, and future user packs. Precedence is explicit and documented. |
| DATA-02 | P0 | Detect duplicate IDs | CI fails on unapproved duplicate class, race, item, spell, monster, event, and campaign IDs. Intentional overrides require an explicit manifest entry naming the replaced source. |
| DATA-03 | P0 | Sort all discovery | Directory and file iteration is explicitly sorted and repeated Windows loads produce identical registry hashes. |
| DATA-04 | P0 | Preserve curated spell mechanics | Imported descriptive records cannot erase curated `effects`, action economy, targets, saves, concentration, or class-list assignments. `bless` and `shield` are regression fixtures. |
| DATA-05 | P0 | Populate class spell access | Character creation and level-up produce correct known/prepared spell choices from production data. A newly created caster reaches combat with a usable spell. |
| DATA-06 | P0 | Validate executable features | Active features require supported effects or a named custom resolver. Effectless active features are rejected by validation. |
| DATA-07 | P1 | Add schemas and semantic validation | Validate required fields, stable references, dice expressions, enum values, effect parameters, target types, resource cadence, and cross-record IDs before registration. |
| DATA-08 | P1 | Make import tooling portable | Remove developer-specific source paths, accept explicit inputs/outputs, avoid modifying curated files, and emit a collision/coverage report. |
| DATA-09 | P1 | Define content-pack manifest | Core and Crown content each have identity, version, dependencies, and ruleset compatibility. This is an internal boundary, not a user-facing mod manager. |
| DATA-10 | P1 | Add registry diagnostics | Development boot prints counts, active content layers, approved overrides, and validation failures without flooding normal player logs. |

### Gate 2 exit

- Zero unapproved ID collisions.
- Registry hashes match across repeated Windows runs, with no reliance on filesystem enumeration order.
- Every active feature has an executable effect or registered resolver.
- Every exposed caster receives legal production spell options.
- Production `bless`, `shield`, Second Wind, and one imported item/monster pass mechanics-backed regression tests.
- Re-running the importer cannot silently degrade curated gameplay records.

---

## 7. Gate 3 — Safe saves and idempotent campaign state

**Objective:** Supported saves round-trip without duplicating rewards, losing party state, or serializing live engine objects.

| ID | Priority | Task | Acceptance criteria |
|---|---:|---|---|
| SAVE-01 | P0 | Define safe-save policy | Save is allowed at the overworld, town/camp, and designated dungeon-entry checkpoints. It is disabled and rejected during combat, event resolution, scene transitions, and active dungeon traversal. |
| SAVE-02 | P0 | Add schema versioning | Every save has a schema version, game/content version, creation/update timestamp, and validated root structure. Unsupported versions fail without replacing active state. |
| SAVE-03 | P0 | Replace runtime objects with DTOs | Coordinates, rooms, inventories, characters, milestones, dungeons, party slots, and companion state serialize to plain dictionaries/arrays and reconstruct through explicit `to_dict`/`from_dict` paths. |
| SAVE-04 | P0 | Persist campaign ledgers | Completed milestones, cleared dungeons, claimed rewards, boss defeats, recruited/dismissed companions, and campaign completion are stored by stable ID. |
| SAVE-05 | P0 | Make rewards idempotent | Re-entering a cleared dungeon or re-evaluating a milestone cannot grant levels, gold, fragments, loot, or achievements twice unless the content explicitly declares repeatability. |
| SAVE-06 | P1 | Add transactional load | Parse and validate into temporary state. Replace active game state only after the complete save is accepted. A corrupt save leaves the current session intact. |
| SAVE-07 | P1 | Add save compatibility fixtures | Keep representative saves for the current schema and future migration tests. Fixtures contain no developer-specific paths or private player data. |
| SAVE-08 | P1 | Test repeated round-trips | Create, save, load, progress, save, and load again using a disposable data root. Compare stable gameplay state, not serialized string equality alone. |

### Gate 3 exit

- Save controls are unavailable in every unsafe state and API calls are rejected defensively.
- No save JSON contains `<RefCounted`, `Node`, raw `Vector2i` strings, callable values, or device IDs.
- A three-cycle save/load test preserves party, inventory, location, controller ownership, companion roster, milestones, and cleared dungeons.
- Replaying a cleared Crown dungeon cannot duplicate its one-time rewards.
- Corrupt and unsupported saves fail safely with a player-readable message.

---

## 8. Gate 4 — Party, companions, and couch co-op control

**Objective:** Model characters, active party membership, and local control separately so couch co-op works now and networking remains possible later.

| ID | Priority | Task | Acceptance criteria |
|---|---:|---|---|
| PARTY-01 | P0 | Introduce stable party slots | Four ordered slots reference character IDs and expose empty/occupied state. Character data does not own input or seat identity. |
| PARTY-02 | P0 | Introduce local player seats | A local seat has a stable session ID, display identity, color, joined state, and assigned party slots. Physical device bindings remain session-local. |
| PARTY-03 | P0 | Build 1–4 player join/create flow | Each joined player creates exactly one initial character. Starting the campaign with fewer than four leaves legal companion slots. |
| PARTY-04 | P0 | Add companion recruitment lifecycle | Crown exposes a minimum roster sufficient to fill a one-player party. Recruit, decline, dismiss, and replace operations enforce party capacity and unique companion identity. |
| PARTY-05 | P0 | Implement exploration leadership | One occupied slot is leader. Input moves the party once, followers render in formation, and events/transitions trigger from the authoritative party position. |
| PARTY-06 | P0 | Assign all combatants to players | Before combat, every active character has exactly one local owner. Companions can be redistributed among joined players; one player may own several turns. |
| PARTY-07 | P1 | Add leadership and assignment UI | Outside blocked states, players can transfer leadership and reassign companions. Current leader and active combat owner are always visible. |
| PARTY-08 | P1 | Define disconnect/reconnect behavior | Pausing and controller reconnection cannot strand a turn. Players reclaim seats after load; saved data does not assume “Controller 2” still exists. |
| PARTY-09 | P1 | Spawn coherent combat formations | Encounters derive all active combatants from the party snapshot and place them around the leader using validated formation positions. No member can be absent because of exploration distance. |
| PARTY-10 | P1 | Route intent through commands | Movement, action selection, targets, dialogue choices, inventory actions, and end-turn enter rules through explicit player commands rather than direct device events in domain logic. |

### Gate 4 exit

- Automated scenarios start Crown with 1, 2, 3, and 4 local players.
- Empty slots can be filled by distinct companions and reassigned among players.
- One leader moves the full exploration party and all active slots enter combat.
- A player controlling multiple characters receives the correct turns without changing physical devices.
- Save/load preserves party slots, characters, companion state, leadership, and logical seat ownership; device rebinding happens after load.

---

## 9. Gate 5 — Rules-engine proof through a representative cohort

**Objective:** Establish a reusable action/effect vocabulary and prove it with Fighter, Rogue, Wizard, and Cleric across the Crown level band.

| ID | Priority | Task | Acceptance criteria |
|---|---:|---|---|
| RULE-01 | P0 | Define command and action contracts | Move, attack, cast, use feature, use item, react, interact, and end turn have typed/validated request and result shapes. Invalid actions do not partially mutate state. |
| RULE-02 | P0 | Define effect vocabulary | At minimum support damage, healing, temporary HP, movement, resource spend/restore, condition add/remove, roll modifiers, AC/stat modifiers, summon, area selection, duration, concentration, and triggered reactions. |
| RULE-03 | P0 | Centralize action economy | Action, bonus action, reaction, movement, free interactions, per-turn uses, short-rest uses, long-rest uses, and spell slots are consumed and restored consistently. |
| RULE-04 | P0 | Separate combat responsibilities | Extract stable session state, turn progression, action resolution, and presentation/VFX boundaries from `CombatState` without changing validated behavior. |
| RULE-05 | P0 | Complete Fighter 1–5 | Starting proficiencies/equipment, Second Wind, Action Surge, subclass-independent features in scope, resources, and level progression are reachable and tested. |
| RULE-06 | P0 | Complete Rogue 1–5 | Sneak Attack, Cunning Action, Uncanny Dodge or other in-band features, skill interactions, resources, and progression are reachable and tested. |
| RULE-07 | P0 | Complete Wizard 1–5 | Spell acquisition/preparation policy, slots, Arcane Recovery, concentration, reactions, save/attack spells, and progression are reachable and tested. |
| RULE-08 | P0 | Complete Cleric 1–5 | Preparation, healing, buffs, save spells, Channel Divinity/in-band resources, concentration, and progression are reachable and tested. |
| RULE-09 | P1 | Implement reaction ownership flow | Opportunity attacks, Shield, Counterspell, Uncanny Dodge, and future reactions prompt the owning player, respect timeouts/cancel, and cannot consume another seat's input. |
| RULE-10 | P1 | Add deterministic rules fixtures | Seeded dice and fixed combat states test success, failure, criticals, advantage/disadvantage, saves, resistance, concentration, KO, death/defeat, and resource reset. |

### Gate 5 exit

- A newly created Fighter, Rogue, Wizard, and Cleric each reach level-appropriate combat with their expected production-data actions.
- Every in-band feature for the cohort is either mechanically complete or deliberately excluded from selection with a recorded scope decision.
- At least one full encounter uses martial attacks, a bonus action, a reaction, concentration, healing, a save spell, and an area effect.
- Action/resource state survives a supported save between encounters.
- `CombatState` no longer owns domain resolution, input interpretation, scene transitions, and presentation as one undivided responsibility.

---

## 10. Gate 6 — Broad class, spell, item, and monster coverage

**Objective:** Extend the proven rules contracts across every player option exposed within the Crown level band.

### Class cohorts

| Cohort | Classes | Required proof before next cohort |
|---|---|---|
| A | Fighter, Rogue, Wizard, Cleric | Gate 5 |
| B | Barbarian, Monk, Paladin, Ranger | Rage/stance resources, unarmed/multiattack behavior, smites, half-casting, and class-specific action economy work through production data. |
| C | Bard, Druid, Sorcerer, Warlock | Inspiration, wild-shape decision or explicit scope, metamagic, pact casting, short-rest restoration, and distinct spell-list behavior work. |
| D | Artificer, Mystic, remaining variants | Non-core rules are explicitly specified, mechanically implemented, and prevented from bypassing shared resource/effect contracts. |

### Coverage tasks

| ID | Priority | Task | Acceptance criteria |
|---|---:|---|---|
| CONTENT-01 | P0 | Build mechanics coverage report | Report every exposed class feature and spell with implementation status, resolver/effects, player path, and test IDs. The report is generated from production content. |
| CONTENT-02 | P0 | Complete cohorts B–D | Each class has legal creation choices, starting equipment, level progression, resources, class actions, and spells where applicable across the confirmed Crown band. |
| CONTENT-03 | P0 | Audit every exposed spell | Every selectable spell has casting time, range, targets, costs, resolution, feedback, AI compatibility where applicable, and at least one mechanics test. Hide unsupported spells. |
| CONTENT-04 | P0 | Audit items and equipment | Weapons, armor, shields, consumables, quest items, shops, inventory limits, equip restrictions, and gold transactions use validated production records. |
| CONTENT-05 | P0 | Audit monsters and encounters | Every Crown monster has valid actions, movement, defenses, rewards, AI profile, and encounter placement. Unsupported imported monsters remain unavailable. |
| CONTENT-06 | P1 | Complete condition interactions | Durations, stacking, immunity, removal, save timing, turn timing, concentration links, UI indicators, and persistence are defined and tested. |
| CONTENT-07 | P1 | Add AI action parity | AI consumes the same validated action/effect contracts as players. It cannot cast or use an ability through a private shortcut unavailable to rules validation. |
| CONTENT-08 | P1 | Balance the Crown band | Establish encounter budgets, resource attrition assumptions, rest availability, item economy, and expected party compositions for 1–4 players. |

### Gate 6 exit

- The coverage report has no exposed feature or spell in `missing`, `description-only`, or `test-only` state.
- All 14 current classes can be created and complete representative Crown encounters across their supported levels.
- Every Crown encounter record passes schema and mechanics validation.
- Unsupported imported content is quarantined from player selection rather than pretending to work.
- A mixed party can rest, level, equip rewards, prepare/learn spells, and retain state correctly between encounters.

---

## 11. Gate 7 — Crown campaign start to finish

**Objective:** Turn the working systems into one complete campaign with a visible beginning, progression, final encounter, defeat path, and provisional ending.

| ID | Priority | Task | Acceptance criteria |
|---|---:|---|---|
| CROWN-01 | P0 | Define Crown campaign graph | Document required and optional locations, events, companion opportunities, dungeons, milestones, boss prerequisites, rewards, and final transition by stable ID. |
| CROWN-02 | P0 | Add player-facing objectives | The party can always determine its current primary objective and completed milestones without reading developer logs. |
| CROWN-03 | P0 | Complete event outcomes | Required events resolve legal choices, checks, rewards, consequences, companion changes, and follow-up state through shared rules and campaign ledgers. |
| CROWN-04 | P0 | Complete dungeon lifecycle | Entry, rooms, traps, encounters, loot, boss, clear state, exit, and re-entry behavior are deterministic where required and persist one-time results. |
| CROWN-05 | P0 | Complete final encounter | The final fight uses production party, rules, monster, reward, and campaign data; win and loss both transition correctly. |
| CROWN-06 | P0 | Add defeat flow | Party defeat presents a clear result and offers load safe save or return to menu. It does not silently change scenes. |
| CROWN-07 | P0 | Add provisional completion flow | Campaign victory records completion and presents a summary with return-to-menu and continue-from-before-finale choices. It does not promise undefined post-game systems. |
| CROWN-08 | P0 | Build fixed-seed campaign smoke | Automation exercises creation, companion fill, overworld travel, required progression, representative dungeon/combat/event flows, final victory, and completion state. Expensive content may use bounded test fixtures, but not alternate mechanics. |
| CROWN-09 | P1 | Run composition matrix | Validate solo player + three companions, two players + two companions, three players + one companion, and four player characters. Include martial-heavy and caster-heavy parties. |
| CROWN-10 | P1 | Add interruption recovery checks | Quit/relaunch from every supported safe-save point and verify the next objective, party ownership, cleared content, and available actions remain correct. |

### Gate 7 exit

- The fixed-seed Crown smoke reaches the completion screen with zero skipped required stages and no unexpected engine errors.
- A manual couch co-op run completes with at least two local players and companion reassignment.
- Defeat, reload, dungeon re-entry, and final victory do not duplicate rewards or corrupt progression.
- The objective display always identifies a valid next step.
- The provisional ending records campaign completion without requiring New Game+ or ascension.

---

## 12. Gate 8 — Repository-playable candidate

**Objective:** A friend can obtain the repository, follow the setup instructions, and complete Crown without access to the original developer's machine state.

| ID | Priority | Task | Acceptance criteria |
|---|---:|---|---|
| SHIP-01 | P0 | Write setup and play documentation | Document supported Godot version, repository setup, launch, local-player joining, controls, safe saving, known limitations, and test commands. |
| SHIP-02 | P0 | Gate development control surfaces | Beckett editor/runtime functionality is disabled by default for friend-facing play and cannot accept runtime control commands unless an explicit development flag enables it. |
| SHIP-03 | P0 | Remove machine-specific dependencies | No launch, import, conversion, test, content, or documentation path requires `/home/pigeon`, mounted drives, or this workstation's absolute paths. |
| SHIP-04 | P0 | Run fresh-clone validation | Validate from a new clone with an isolated Godot profile and empty save directory. Do not rely on imported editor cache. |
| SHIP-05 | P1 | Make settings honest | Audio buses/assets and accessibility settings are wired, or unavailable settings are removed/marked unavailable. Player options cannot be placebo controls. |
| SHIP-06 | P1 | Complete minimum feedback | Turn ownership, leader identity, objectives, valid targets, damage/healing, conditions, resource use, victory, and defeat are readable without developer logs. |
| SHIP-07 | P1 | Establish private-content boundary | Document which data/assets are private third-party-derived content and keep them separable from original engine and campaign-independent code. |
| SHIP-08 | P1 | Clean repository artifacts | Generated logs, caches, test saves, dogfood output, orphan probes, and debug-only scenes are removed, ignored, or explicitly documented as fixtures. |
| SHIP-09 | P1 | Reconcile architecture documentation | Current architecture notes describe actual boundaries, save policy, content precedence, test topology, and party/control model with repository-relative links. |

### Gate 8 exit

- A friend can follow the README on a clean machine and launch the project from the repository.
- The complete Gate 1 suite and Gate 7 campaign smoke pass from a clean clone.
- A manual start-to-finish run has no developer console intervention.
- No friend-facing run starts Beckett control services.
- Known limitations are written plainly and do not contradict the UI or roadmap.

---

## 13. Definition of milestone complete

The Crown milestone is complete only when all of the following are true:

- Gates 0–8 have recorded evidence.
- One to four local players can start a legal campaign.
- Companions fill empty party slots and are assignable among players.
- One exploration leader moves a coherent four-slot party.
- All exposed classes, features, spells, items, conditions, and Crown monsters work across the confirmed campaign band.
- Safe saves survive repeated load/progress/save cycles.
- Crown milestones, dungeons, rewards, and completion are idempotent.
- The party can win, lose, reload, and reach a visible ending.
- Automated suites run every named scenario and fail on engine errors, timeouts, and skipped completion markers.
- A clean-clone manual run completes without machine-specific state or developer intervention.

“Most content exists” is not a substitute for this list.

---

## 14. Recommended next execution tranche

Gates 0 and 1 supplied the baseline and trustworthy test gate. Continue in this
order:

1. `DATA-01` through `DATA-06`: deterministic loading, collision failures, curated mechanics, spell access, feature validation.
2. `SAVE-01`: enforce safe-save states immediately so known-corrupt saves cannot be created through normal UI.
3. `SAVE-02` through `SAVE-05`: versioned DTOs and idempotent campaign ledgers.
4. `CROWN-06` and `CROWN-07`: add explicit defeat and provisional completion destinations to close the state machine.
5. Begin `PARTY-01` through `PARTY-06` only after save and content identities are stable.

The trustworthy test checkpoint is now established; each later gate extends it
without weakening its failure controls.

---

## 15. Gate evidence template

Every gate review should record:

```text
Gate:
Commit:
Godot version:
Automated commands:
Passed scenarios:
Expected warnings:
Unexpected warnings/errors:
Manual flow exercised:
Data/save root used:
Open limitations:
Reviewer:
Decision: pass | review | fail
```

If a required manual couch-co-op, clean-clone, or full-campaign run remains, the gate stays in `review`.

---

## 16. Risk register

| Risk | Evidence | Control |
|---|---|---|
| Breadth overwhelms integration | Fourteen classes and 198 loaded spells currently exceed implemented mechanics | Complete representative cohorts against shared contracts; quarantine unsupported content. |
| Tests regress into false confidence | The former file preflight rejected valid autoloads and viewport victory prevented later tests | Preserve Gate 1 isolation, markers, timeouts, engine-error policy, and test manifest. |
| Imported data destroys curated behavior | Duplicate IDs silently overwrite records | Deterministic layers, collision failure, explicit override manifests, registry hashes. |
| Save corruption appears late | Live objects and engine-specific keys enter JSON | Versioned DTOs, safe-save policy, transactional load, repeated round-trips. |
| Couch co-op becomes welded to devices | Current code conflates active player and active character | Separate seats, party slots, characters, commands, and transient device bindings. |
| Campaign rewards are farmable | Milestones and dungeon state are not recorded idempotently | Stable completion ledgers and one-time reward claims. |
| Combat changes become progressively unsafe | `CombatState` owns too many responsibilities | Extract contracts after Gate 2 and before multiplying class mechanics. |
| Private 5E content blocks future release | Imported names/data are mixed with engine records | Content-pack boundary and rules/content separation; public clearance is a future release gate. |
| Polish hides incomplete systems | Existing roadmap prioritized achievements/VFX while core paths were unwired | Gates order integrity before breadth, breadth before polish. |

---

## 17. Post-milestone roadmap

These begin only after Gate 8 unless they are necessary to repair a milestone contract.

1. Online multiplayer transport, authority, synchronization, reconnect, and desync recovery using the command/state boundaries proven by couch co-op.
2. Higher-level progression and additional campaigns.
3. New Game+, ascension, or another post-game progression model.
4. User-facing content packs, mod discovery, validation, enable/disable, and authoring tools.
5. Public-release content replacement, asset provenance, licensing review, export presets, packaging, and storefront requirements.
6. Expanded companion relationships, reactive narrative, and campaign branches.
7. Advanced tactical layers such as surfaces, verticality, environmental interactions, and deeper enemy coordination.

The destination can stay enormous. The gates keep the floor from moving while we build it.
