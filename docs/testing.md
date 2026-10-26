# Testing

The supported engine baseline is Godot 4.7.x on Windows. Provide a portable
executable through `GODOT_BIN` or pass its path to the PowerShell runner.

## Proportionate spell validation

`projected_vessel_flow` exercises exact loaded vessel copies through real room
projection, containment admission, cargo, movement and ending controls. It
checks separate retain/release policies, legal full-backpack return, blocked
destruction, actual physical footprints, stale/remote controls and malformed
checkpoint refusal. The runner follows it with a fresh-process probe that
restores and completes active/pending endings from both full-party and
player-only saves. Its verified host and limits live in
[VS-151](planning/vocabulary-slices.md#projected-vessel-contents).

The conversion batch scenarios also run their existing recovery modes in fresh
processes against the same isolated profile. Batch 001 checks its concentration
checkpoint; Batch 002 checks both full-party and player-only checkpoints.

`tether_group_flow` exercises ordinary two-recipient tether targeting, once-paid
casting, exact combat and room selection, Character and object anchors, object
movement/destruction, stale rescue selection, and the existing full/partial
checkpoint. The runner follows it with the Character and object recovery probes
in separate processes. Its verified boundary lives in the
[slice registry](planning/vocabulary-slices.md#character-tether-groups).

Do not run the entire logic suite after every spell record or small correction.
Choose checks for the behavior changed, then run broader coverage once at a
meaningful batch boundary. A passing assertion count is not spell completion.

| Change | Required development check | When to broaden |
|---|---|---|
| Description, class membership or metadata only | Inventory reconciliation and `-Suite logic -LogicGroup data` for changed loading/access contracts | Once when the content batch is ready |
| Spell using existing targeting/effect operations | `-Suite logic -LogicGroup spells`, plus its relevant live encounter | Full logic once after the batch |
| Shared damage, saving throws, conditions, targeting or concentration | `-Suite logic -LogicGroup spells,combat,conditions`, plus affected class/encounter checks | Full logic before accepting the shared behavior batch |
| Black Tentacles zone and duration rules | `-Suite logic -LogicGroup spells` and `-Suite integration -Scenario black_tentacles_spell_flow` | The scenario checks 8-, 24-hour and until-dispelled upcasts |
| Sleet Storm zone, start/entry saves and Concentration loss | `-Suite logic -LogicGroup spells` and `-Suite integration -Scenario sleet_storm_spell_flow` | The scenario checks no appearance save, one trigger per turn, target/caster cleanup |
| Saved fields, campaign time or delivery | Add `persistence,world` and actual save/reload or fresh-process checks | Full logic and affected integrations before accepting the persistence batch |
| Release/large mixed change | Default full logic and appropriate integration suite | Do not repeat without a new change or unresolved failure |

Focused examples (substitute the Godot executable available on the host):

Wave 3 acceptance adds `wave_three_foundations_flow` for barrier damage,
passage/sight changes, Water Walk heat exposure, disk reload, forced movement
through hazards and falling. `WaveThreeChecks` covers durable area ownership,
unloaded concentration cleanup, floor bounds and malformed barrier/heat data.
The runner accepts a comma-separated `-Scenario` array, reusing its gates once
for the requested batch. Its default logs and disposable Windows save profiles
live in `.artifacts/tests/<run-id>/` inside the writable project; `TEST_LOG_DIR`
still overrides that location. The runner never writes to the normal player
profile and does not bypass parse, boot or save guards.

```powershell
.\run_tests.ps1 -GodotPath '<Godot console executable>' -Suite logic -LogicGroup effects
.\run_tests.ps1 -GodotPath '<Godot console executable>' -Suite logic -LogicGroup barbarian
.\run_tests.ps1 -GodotPath '<Godot console executable>' -Suite logic -LogicGroup bard
.\run_tests.ps1 -GodotPath '<Godot console executable>' -Suite logic -LogicGroup cleric
.\run_tests.ps1 -GodotPath '<Godot console executable>' -Suite integration -Scenario bard_action_flow
.\run_tests.ps1 -GodotPath '<Godot console executable>' -Suite integration -Scenario bard_creation_flow
.\run_tests.ps1 -GodotPath '<Godot console executable>' -Suite integration -Scenario barbarian_action_flow
.\run_tests.ps1 -GodotPath '<Godot console executable>' -Suite integration -Scenario spell_effect_lifetime
.\run_tests.ps1 -GodotPath '<Godot console executable>' -Suite logic -LogicGroup spells
.\run_tests.ps1 -GodotPath '<Godot console executable>' -Suite logic -LogicGroup spells,combat,conditions
.\run_tests.ps1 -GodotPath '<Godot console executable>' -Suite integration -Scenario mixed_mechanics_encounter
```

Available groups are `data`, `spells`, `effects`, `barbarian`, `bard`, `cleric`, `combat`, `conditions`, `classes`,
`persistence`, `world`, and `ui`; `all` is the default. All groups still load
real production content. Focused success prints `SELECTED LOGIC TESTS PASSED`,
so it cannot be mistaken for a complete logic run. The existing default runs
every previous check in its original order. Startup/parse/boot prerequisites
remain, and the runner now stops immediately when one fails. Do not skip a
compile failure to manufacture a green focused result.

Batch 066–087 scenarios are registered in the Windows runner. For flows that
write checkpoints, it automatically launches the matching `*_reload` scenario
in a fresh process using the flow's isolated profile. Selecting a reload name
first runs its parent flow; each pair gets its own profile. Running those reloads
alone against a fresh or deleted profile is not a save-recovery test.

`batch_085_cast_transform_flow` checks qualifying/unrelated casts, both timing
directions after the original budget is spent, refusal and catalog isolation.
`batch_086_find_steed_arrival_flow` checks blocked/cancelled/stale arrivals,
unmounted and mounted footprint recovery; its paired reload runs in a fresh
process. `batch_087_choice_routes_flow` checks Light/Nick/Cleave/Opportunity and
created-creature menus, actual budgets and stale creature action/actor refusal.

The `effects` group is the small development loop for source-owned conditions,
repeat saves, caster expiry and saved effect records. The `spells` group covers
the older whole spell test function. Run the small group while changing the
shared effect batch, its live scenario when the flow changes, then full logic
once when accepting the batch. The mixed encounter checks several other spells.

The `barbarian` group protects the corrected Rage clock/cost/reload behavior,
Reckless attacks, Fast Movement, Danger Sense and Brutal Strike regressions.
`barbarian_action_flow` drives actual menu entry/extension, the declined Reckless
choice, Extra Attack, Forceful's push and movement, disk reload and campaign
expiry. `barbarian_choice_flow` drives accepted Reckless, declining Brutal
Strike on swing one and choosing it on swing two, an off-turn Opportunity
Attack, next-turn cleanup, optional event/sheet choices, disk policy reload,
malformed-policy preflight and equipment-versus-gold creation. The [class audit](mechanics/barbarian-2024.md) records the remaining
behavior separately; passing these checks does not certify the entire class.

The `bard` group protects Inspiration eligibility, expiry and reload, spell attacks,
Font ownership, Jack of All Trades, Magical Secrets, high-level slots, Countercharm
and Power Word death/standing behavior. `bard_action_flow` drives actual sheet
choices, class menus, reactions, two-target Power Words, downed-ally healing and
disk reload. `bard_creation_flow` drives chosen skills/instruments, equipment
or gold, duplicate gating, Back/Random/seat reset, Confirm, sheet display and
player/party save preflight. The [Bard audit](mechanics/bard-2024.md) records remaining gaps and the historical creation matrix
limitations separately. These checks do not certify the whole class.

The `cleric` group protects creation, preparation permissions, Channel Divinity,
source-owned turning, optional Divine Strike, damage-only vitality and saved
Wish cooldowns. `cleric_creation_flow` drives both equipment alternatives,
Divine Order/skills, duplicate gating, review/back/random/seat reset and disk
preflight. `cleric_action_flow` drives actual sheet/catalog/target choices,
downed-ally Spark, selected turning/Sear, vitality, component-free Intervention,
early-return spell cleanup and Wish casting/recovery. `cleric_strike_flow`
drives declining Divine Strike on the first hit and choosing Necrotic on the
Light weapon follow-up, settled damage history and next-turn eligibility.
The [Cleric audit](mechanics/cleric-2024.md) records curated catalog and engine
limits. These scenarios run headless; they do not claim manual visual acceptance.

The [spell delivery register](mechanics/spell-status.md) separates recorded
gameplay slices, existing checks needing audit, blocked spells and unaudited
records. Update it when a slice ships. Safe refusal and correct descriptive
metadata do not advance a spell into the recorded-playable count.

The initial October 5 audit found Hold Monster type-inference errors. They are
repaired. The slice registry and relevant authoring contract retain verified limits.
Startup/parse failure still stops before later tests. A suite total is neither a
spell completion count nor proof of every tabletop clause.

`core12_audit_repairs` exercises conscious-ally Sneak Attack eligibility,
per-creature-turn renewal, a Light attack after a miss, an accepted Opportunity
Attack, partial Wizard spellbook/preparation training buttons, and the actual
Empowered damage-die picker and settlement. Logic checks cover Evasion,
Wizard copying and mastery replacement, class grant corrections, saved legacy
choices, pending spell entitlements, selected-die validation, and one area-cast
damage roll/cost. These checks verify repairs, not full core-12 completion.

```powershell
$env:GODOT_BIN = 'C:\path\to\Godot_v4.7-stable_win64.exe'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_tests.ps1
```

`run_tests.sh` remains compatibility tooling. Native Linux execution is not
required for current Windows acceptance; historical gate names do not set scope.

The first case runs a headless recovery-mode editor scan. This creates the
ignored `.godot` class-name and import caches required by a clean checkout
without activating editor plugins. The parse gate then evaluates the project
with the same class registry a normal first editor launch would create.

The gate stops on a non-zero process exit, timeout, missing result marker, or
unexpected Godot error. Each scenario receives a disposable `user://` root;
the PowerShell runner redirects Windows profile roots. By default its logs and
profiles live under `.artifacts/tests/<run-id>/` in the project, and the retained
path is printed at the end. Set `TEST_LOG_DIR` to use another location.
The Windows Godot build may emit `Failed to read the root certificate store`
under this host profile; the runner allows that exact platform warning. Leak,
resource, and other generic `ERROR:` lines remain failures.

The gate-case manifest is:

| Case | Contract |
|---|---|
| `project_bootstrap` | A cache-free checkout can build Godot's generated class/import state |
| `parse_gate` | Every project script loads with autoload and `class_name` dependencies available |
| `boot_gate` | The production main scene settles without an unexpected engine error |
| `logic` | Data loading, character creation, dice, validated combat/player commands, spellcasting, action economy, AI, inventory, conditions, serialization, players, events, fog, hex math, bounded activity history, saves, and UI widget contracts |

The current integration scenario manifest is:

| Scenario | Player-facing contract |
|---|---|
| `combat` | Combat boot, party/monster spawn, initiative, HUD, and turn progression |
| `party_combat` | Four-member supported save/load, leadership and logical ownership persistence, active-character spell isolation, and distinct combat formation |
| `crown_smoke` | Bounded Crown path through overworld, dungeon, event, finale encounter, objectives, and completion screen |
| `owned_creature_lifecycle_flow` | Crown room summon/dismiss/recall, placement refusal without spending, familiar identity/HP/initiative, Help cleanup, incapacitated-owner Dodge, downed-owner steed survival, encounter return, entrance disk checkpoint/reload, familiar death and party defeat despite a living steed |
| `find_familiar_exploration_flow` | Normal Wizard spellbook/preparation, hour/ritual room buttons, incense/slot/time costs, form/type replacement, Long Rest distinction, pocket controls, authored check Help, safe entrance disk reload, encounter projection and long-cast combat refusal |
| `party_recovery_flow` | Level-5 Cleric preparation, merchant diamond/copper purchases, free component hand, dead/unconscious distinction, room revival/refusal and preservation, safe entrance corpse disk checkpoint/reload, ordinary Cure Wounds on a downed ally, normal Gentle Repose ritual after reload, and clicked combat Revivify with one action/slot/component |
| `created_undead_flow` | Crown Animate Dead preparation, protected-remains refusal, one-minute creation/renewal, Bonus-action clicked orders, independent initiative attack, damaged creature disk checkpoint, in-place control-expiry conversion and later hostile projection |
| `downed_area_damage_flow` | Real Wizard spellbook/preparation and clicked Fireball; persistent Cloud of Daggers movement damages an unconscious ally and records actual death |
| `combat_ai_loop` | Live monster AI intent and action through the combat loop |
| `combat_victory` | Live player actions reach victory and register defeated monsters |
| `combat_defeat` | Live combat detects a party wipe and the defeat screen exposes safe-save recovery and menu exit |
| `created_actor_scheduling_flow` | Removed-owner defaults and after-owner turns, several actors sharing one owner, downed/dead encounter entry, healing/revival/re-entry, control expiry, concentration and timed-source ending, defeat with persistent summons, combat save refusal and allowed checkpoint recovery |
| `shared_initiative_flow` | Loaded renamed exact-source groups sharing the owner count or one group roll; separate member budgets/condition boundaries, deterministic tied groups, death/source removal, late sibling/new-group arrivals, active/empty-group rebuild without settled attack replay, owner disconnect/resume and retained owner-removal anchor |
| `final_encounter_round_trip` | Production Lich King defeat, pre-finale safe reload, victory, idempotent reward claim, and completion screen |
| `mixed_mechanics_encounter` | Bounded production-data encounter composes martial attack, bonus action, owned reaction, concentration, healing, save spell, and area selection |
| `s121_exit_placement_flow` | Combat and local-room required exits retain the captured save through real choice/cancel controls, refuse stale or occupied destinations, settle damage/payment once, and recover represented overworld travel through its allowed checkpoint |
| `batch_053_legal_placement_flow` | Real creation controls cover distinct legal cells, cancel/stale answers, changed occupancy, refuse/spend no-space policies, once-only slot payment, and SaveManager recovery |
| `true_strike_spell_flow` | Live True Strike casting, weapon range/proficiency/material validation, damage-type choice, mixed damage settlement, Magic-action cost and activity history |
| `blindness_deafness_spell_flow` | Live upcast target scaling, Blinded/Deafened choice, source-owned repeat saves, and slot/Magic-action costs |
| `grease_spell_flow` | Live area saves, movement entry trigger, end-turn save, difficult-terrain movement cost, expiry and cleanup |
| `spike_growth_spell_flow` | Live 20-foot Sphere, per-hex travel damage, teleport exclusion, concentration and terrain cleanup |
| `entangle_spell_flow` | Live square saves, source-owned Restrained grants, Athletics escape action and concentration cleanup |
| `black_tentacles_spell_flow` | Live initial, entry and end-turn saves with once-per-turn gating, 3d6 damage, Athletics escape, concentration cleanup and level-5 duration/upcast behavior |
| `moonbeam_spell_flow` | Live initial save, Cylinder movement, per-turn save limit, end-turn trigger and concentration cleanup |
| `plant_growth_spell_flow` | Live Overgrowth cast, persistent 4x movement cost, existing-terrain composition and Instantaneous duration |
| `barkskin_spell_flow` | Live willing-ally cast, Armor Class floor, Bonus Action and slot costs, and one-hour expiry |
| `mage_armor_spell_flow` | Live AC recalculation, slot/Magic-action costs, and effect removal when armor is donned |
| `mass_cure_wounds_flow` | Live 30-foot Sphere selection, per-creature include choice, downed party recovery, monster healing and slot/action costs |
| `mass_healing_word_flow` | Live multi-target healing selection, wounded party recovery, monster healing and Bonus Action/slot costs |
| `ranger_natures_veil_blindsight` | Nature's Veil use/duration, invisible attack Advantage and Disadvantage, Blindsight range, and live sight-required spell targeting |
| `monk_action_flow` | 1-4 seat Focus ownership, cancellation, invalid targets, repeated clicks, shared spending, exhaustion, free/paid choices, target death, actual popup decisions, source-bound and overlapping stuns |
| `fighter_second_wind` | 1-4 seat ownership, real feature-menu activation, healing, bonus-action cost, repeated clicks, exhaustion, rest recovery and remaining-use display; level-4 SaveManager reload is covered by `action_resource_round_trip` |
| `fighter_progression` | 1-4 seat level-20 Fighter menu, once-per-turn Surge, production spell restrictions, four attacks per action, stale targeting, Tactical Shift, out-of-turn Push/Cleave/critical movement, level-9 Indomitable death-save turn and real SaveManager training/resource round-trips |
| `class_building_blocks` | New data-only class selection/creation, real sheet subclass and ability choice, custom/Monk final-use healing through the combat menu, repeated-click rejection and SaveManager preservation/missing-subclass preflight |
| `core12_shared_rules` | Non-Fighter Push, Cleave and Nick through normal attack targeting and real optional prompts, once-per-turn and action limits, settled extra-attack history, and live monster resistance metadata |
| `rogue_devious_strikes` | Level-14 Rogue attack through the live popup choices, affordable Sneak Attack die tradeoffs, failed Daze/Obscure saves, settled Sneak Attack damage, and end-of-turn expiry |
| `sorcerer_subtle_spell` | Live Sorcerer spell selection and Subtle Spell confirmation, component removal, actual cast, and preservation of an ally's Counterspell reaction |
| `overworld` | Overworld, fog, rest, save, settings overlay, and ambush path |
| `companion_lifecycle` | Production Camp Roster UI fills a solo party, declines/reconsiders candidates, replaces and dismisses companions, and reassigns ownership in two-player play |
| `crown_composition_solo_two` | Solo plus three companions and two-player plus two companions through Camp Roster ownership, safe save/load, Crown objective, combat ownership, and formation |
| `crown_composition_three_four` | Three players plus one companion and four local characters through Camp Roster/party setup, safe save/load, Crown objective, combat ownership, and formation |
| `main_menu_load` | Main-menu save-slot loading UI |
| `dungeon` | Dungeon scene, rooms, HUD, and traversal wiring |
| `event_dialog` | Event dialog presentation and resolver wiring |
| `crown_event_fairy_ring` | Production Fairy Ring chain, three legal Fairy Court choices, DEX success/failure branches, and UI follow-up |
| `dungeon_reentry_round_trip` | Production Crown dungeon clear, plain Room DTO checkpoint, supported reload, cleared-room rebuild, and idempotent boss/reward revisit |
| `located_source_end_flow` | Actual room mode activation/expiry, movement before delayed observation, clicked child cancellation/acceptance, actual object and entry-damage successors, shared spell destruction, identical item-copy and created-actor endings, entrance checkpoint, and fresh-process recovery of exact producer children without replaying costs or callbacks |
| `batch_051_feat_acquisition_flow` | Production Origin/ASI feat pickers, once-only ownership, safe save/load and malformed saved ability prerequisite refusal before session replacement |
| `form_equipment_ground_flow` | Actual combat equipment chooser with a full backpack and multiple drops, exact nested/cursed/charged copy pickup by another actor, destruction, battle-to-room capture, entrance checkpoint and fresh-process reversion without duplication |
| `item_form_return_flow` | Exact item voluntary ending, actual lethal monster hit and overflow, full-backpack legal ground return, blocked return retries, independent identical injured copy, dormant-room save-time settlement and fresh-process recovery of pending/completed returns |
| `containment_release_flow` | Several/nested occupants, creature/object movement and represented room travel, exact gear, reserved/rechecked release destinations, blocked/fallback/refuse policies, stale/cancelled choices, repeated expiry/destruction and actual release after full-party/player-only checkpoint recovery in a fresh process |
| `containment_harm_flow` | Authored internal/external effects, exact two-occupant spell/check selection, stale/cancelled/repeated choices, internal/object damage, creature/object container destruction, deferred release, active/pending party and player-only checkpoint recovery in a fresh process |
| `containment_flow` | Real room admission/inspection, multiple occupants, changed capacity, stale/cancelled choices, independent creature/object containers, exact gear ownership, internal locations, entrance checkpoint and both DTO paths through fresh-process recovery |
| `item_lifecycle_controls_flow` | Actual room/combat exact-copy Bond/Release and Project/Dismiss controls, identical names, cancellation, stale ownership/attunement/form, occupied space, authored actions/charges/no-space policy, full-inventory return with nested contents and fresh-process checkpoint recovery |
| `batch_052_hud_mode_controls_flow` | Production combat mode/upgrade popup controls, cancel/superseded/previous-turn answers, exact-copy suppression and safe save/load |
| `character_creation` | Character-creation scene boot and legal choices |
| `normal_creation_matrix` | Production main-menu player-count controls and character creation for one through four local players, including stable seat ownership and empty companion slots |
| `shop` | Shop scene, inventory, purchase, and sell wiring |
| `save_load` | Save/load round trip and cleanup of the test slot |
| `scripts/validate_crown_fresh_relaunch.ps1` | Separate-process Crown overworld safe-save recovery for party ownership, objective, cleared dungeon, reward ledger, and available state |
| `scripts/validate_crown_two_player_relaunch.ps1` | Separate-process progressed two-player Crown recovery for seat ownership, leadership, objectives, two dungeon clears, rewards, and quest fragments |
| `action_resource_round_trip` | Spends a production Fighter feature and Wizard spell slot, reloads at the overworld safe point, and boots the next combat from the restored state |
| `combat_resolution` | Combat result resolution through the live scene |
| `event_choice_resolution` | Event choices resolve through campaign state |
| `event_dialog_choice_click` | UI choice click reaches the event resolver |
| `character_sheet` | Character sheet opens, renders sections, and closes |
| `character_sheet_contexts` | The real Character Sheet button opens the correct character from overworld, dungeon, and combat HUDs |
| `character_value_audit` | Representative race/class values survive initialization, level-up, save/load, runtime HP mutation, and Character Sheet rendering |

The logic runner verifies its registered check scripts and requires the
`CHECK SCRIPT GATE` marker. Both logic and viewport harnesses count runtime
`SCRIPT ERROR`s and fail even if Godot would otherwise return zero after skipping
assertions. The wrappers also reject missing success markers. A parse-gate failure
stops both supported shell runners before launching an unparseable logic scene.

The viewport harness also supports `--scenario=all` for local debugging. The
repository runner accepts `-Scenario <name>` for a single integration case;
otherwise it invokes each scenario separately so each one owns its process
lifetime, timeout, log, and result marker.

`src/validate_and_test.py` checks JSON structure and copied reference formulas;
it does not execute game logic. `src/generate_feature_matrix.py` inventories
declarations and does not assign gameplay test evidence automatically. Current
production results belong in the conversation or existing PR; keep durable
support limits in the relevant authoring contract and slice registry.

## Grimoire visual and input probe

On the Windows Godot 4.7 host, run:

```powershell
.\scripts\capture_ui.ps1 -GodotPath '<path to Godot console executable>'
.\scripts\capture_ui.ps1 -GodotPath '<path to Godot console executable>' -Relaunch
```

The first command runs `scenes/ui_polish_probe.tscn` with a rendered window
and captures production scenes at 720p/1080p plus larger board compositions
and a second profile. It checks board bounds, chrome/modal input, focus,
creation backtracking, Chronicle reading/newest navigation, detail reveal,
capacity and theme seams. The second runs prepare/recover in separate
headless processes, comparing exact rendered resolver arithmetic after a
safe save and checking newest-valid-save selection.
Both redirect Windows profile roots under `.artifacts/`; no real player
saves or settings are used. The wrapper rejects runtime errors even when
Godot exits zero. Captures and logs are ignored development artifacts; the
approved concept and selected acceptance captures under `docs/ui/reference`
are intentional review deliverables. See [visual acceptance](ui/VISUAL_ACCEPTANCE.md).
