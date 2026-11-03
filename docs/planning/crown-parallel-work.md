# Crown local work and Grokbot PR queue

Planning snapshot: **2026-11-01, `7ce30378`**. This divides the owner's local and
Grokbot work; it does not change the [Crown finish line](crown-roadmap.md), select
a replacement roadmap, or accept engine slices. Recheck the base before starting
an assignment. GitHub showed no open PRs or issues during this review.

**Local sequencing update (2026-11-01):** the owner split S-237/S-238 into
[bounded work packages](vocabulary-slices.md#ordinary-action-work-packages) with
[prompts for separate chats](ordinary-action-chat-prompts.md). Those assignments
supersede this snapshot's instruction to finish all S-237 before selecting
movement/Hit Dice. The dated inventory below is not refreshed by that planning
change; delivered cover/Study/Influence continuations live in the registry.

## Current position

The engine has substantial reusable behavior, but the complete Crown package is
still unfinished. There is no defensible Crown completion percentage. The
registry's 163 accepted of 276 slices measures the wider engine, not this campaign.

A fresh production DataLoader export on Windows Godot 4.7, without fixtures,
reported:

| Boundary | Current evidence / remaining work |
|---|---|
| Loading | 14 classes, 12 offered; 5 subclasses; 9 species; 0 feats; 290 items; 362 spells; 481 monsters. Zero load errors, 25 rejected effectless features. |
| Scoped spells | All 183 present; 102 cast-available, 81 refused; 14 shared, 169 native. Neither availability nor an execution label certifies complete rules. |
| Character packages | Only 3 of the 12 target subclass records exist: Champion, Fiend and Open Hand. Nine are absent. These three records do not certify complete packages. |
| Species/backgrounds/feats | Seven target species names exist; Goliath/Orc are absent. Half-Elf/Half-Orc remain legacy records. No background content type or creation step; no production feat definitions. |
| Delivered runtime | Reuse accepted condition/roll hosts, bounded placement/commands/forms, source identity, rests, perception, ordinary combat actions, Ready/Utilize, and visual room-object Search. Their documented limits still apply. |
| Selected work | S-237 is still incomplete: cover-dependent Hide, remaining noise/Search hosts, world Help, Study and Influence. |
| Campaign proof | Transition/recovery fixtures exist. A normal creation-to-finale journey using legal resources and the actual boss remains unproven. Existing smoke-test victories are deliberately shortened. |

Inventory SHA-256:
`83c294bf99b0946754769bb51b377f5a34a343e89442a9af9739dd4e12369b31`.
Raw export and check logs are ignored under
`.artifacts/crown-work-review-2026-11-01/`. Feats were inspected separately;
the registry hash omits them. This inventory does not certify gameplay.

The supported Windows runner passed bootstrap, the 463-script parse gate, boot,
`normal_creation_matrix`, `ordinary_action_flow`, `ready_action_flow`,
`world_search_flow` and its fresh-process reload, and `crown_smoke`. These are
the checked boundaries; the wider historical scenario investigations and normal
full-campaign journey were not rerun or certified. One independent source review
checked the work split and the existing acquisition blockers.

Two stale claims must not turn into duplicate work:

- **Open Hand Technique is now loaded and enabled.** The older empty-level-3
  baseline predates the current condition/roll-host completion.
- **Multiclass prerequisite code already exists.**
  `PermanentProgressionRules.multiclass_prerequisite_error`, offer/confirm gates,
  loader validation and Fighter/Monk/Paladin/Ranger overrides are present.
  S-234 is still unaccepted, so verify the existing boundary rather than rewrite
  it. Actual production multiclassing remains blocked: no class opts into
  `permanent_progression`; its validator rejects subclasses, native acquisition/
  slot fields and most feature kinds; secondary classes with features are refused.
  Adding declarations to twelve JSON files cannot solve that.

## Local lane — select one bounded assignment

Use the registry's [S-237/S-238 work packages](vocabulary-slices.md#ordinary-action-work-packages)
and their [chat prompts](ordinary-action-chat-prompts.md). Start with OA-01's
review of the delivered cover boundary; then choose one ready capability or
independent Crown assignment by actual prerequisites. Movement/Grapple/Shove,
Hit Dice and character/content work need not wait for all S-237/S-238.
The registry retains the parent requirements and their unassigned follow-ups;
this sequencing change accepts no slices and drops no Crown-required behavior.

Local owns combat, targeting/perception, room Search/interactions, world/event
effects and their input checks. Keep `combat_state.gd`, `combat_action.gd`,
`combat_perception.gd`, `targeting.gd`, ordinary/Ready action owners,
`src/dungeon/`, `src/events/` and `src/overworld/` out of Grokbot's current lane.
For shared files such as Character, DataLoader and the harness, Grokbot changes
only the acquisition/validation sections named below; integrate those PRs
sequentially. No broad file reformatting or cleanup.

Local also owns reviewing/integrating PRs, supported Windows verification and
later live Godot observation. The completed Ready, equipment projection,
command pickers, ownership controls, condition quartet and room Search are not
new assignments.

## Grokbot lane — one bounded PR at a time

Use the following assignments in order. Start from the latest integrated main;
do not build a large unreviewed stack. Each PR description states the resulting
behavior, source clauses, exact checks and remaining limits. Keep status changes
in the slice registry and supported syntax in its existing mechanics reference.

### G1 — Correct class metadata already consumed by the game

Suggested branch: `codex/crown-class-metadata`.

- Correct Wizard and Rogue skill lists from their SRD Core Traits tables.
- Normalize Cleric's armor-proficiency token to the existing `shields` spelling.
- Add explicit level-3 subclass declarations where still absent: Barbarian,
  Bard and Cleric. Preserve declarations already supplied elsewhere.
- Scope: the selected `data/core/classes/*.json` fields and focused expectations
  in existing checks. Read [class views](../../reference/2024/README.md) and
  the [acquisition audit](../reviews/progression-acquisition-audit.md), then
  verify the actual SRD clauses rather than treating those views as authority.
- Check production loading and affected creation/sheet output. Run the classes
  logic group, `normal_creation_matrix` and affected creation flows.
- Exclude starting-package rewrites, tools, Rogue weapon restrictions, native
  feature conversion and progression opt-in. These need behavior beyond metadata.

### G2 — Deliver class skill/tool choices and fixed tool grants

Suggested branch: `codex/crown-class-proficiency-creation`. After G1.

- Reuse `ClassProgression` creation validation and current selectors. Expose
  source-defined class skill/tool choices through ordinary creation; remove
  class-specific UI assumptions only where needed for those choices.
- Deliver Druid's Herbalism Kit proficiency, Rogue's Thieves' Tools proficiency,
  and Monk's Artisan's Tool or Musical Instrument choice. Distinguish owning
  an item from being proficient with it. Resolve missing tool records from
  source if these actual grants require them.
- Touch only acquisition sections of Character/ClassProgression, creation UI,
  loader validation, the selected class/tool data and relevant existing probes.
  A top-level `tool_proficiencies` field currently does not grant itself.
- Prove actual creation, selected/fixed grants, duplicate/refused choices, Back,
  Random and seat reset, sheet/check usage, and both player/party save validation
  with fresh-process recovery. Legacy saves keep their represented grants;
  do not retroactively grant equipment/proficiencies on restore.
- Use classes/persistence checks plus `normal_creation_matrix`, affected class
  creation flows and a focused recovery probe. New persistence behavior needs
  the project's focused independent review before acceptance.
- Exclude background/species steps, combat eligibility and full equipment packs.

### G3 — Verify the existing S-234 entry gate and reconcile its status

Suggested branch: `codex/crown-multiclass-entry-proof`. After G2.

- Exercise the existing prerequisite implementation through offered classes and
  actual confirmation with loaded neutral class definitions. Do not replace it.
- Cover the proposed and every acquired class, all/any rules, scores 12/13,
  permanent versus projected scores, stale confirmation, refusal without costs,
  and continuing an already acquired class after a score drops.
- Check malformed loader declarations and retained class history across the
  existing allowed checkpoints. Fix only defects actually reproduced here.
- Scope: existing progression checks/fixtures, minimal gate repairs if needed,
  [permanent progression](../mechanics/permanent-progression.md) and S-234's
  registry boundary. Production class overrides already exist.
- Run classes and persistence logic plus the relevant production progression
  input/recovery checks. Accept S-234 only if its finish line is demonstrated;
  record narrower passing evidence otherwise. Do not invent a second slice.
- Exclude XP advancement, higher-level starts, enabling production multiclassing,
  secondary feature/casting/subclass migration and broad progression redesign.

### G4 — Deliver the real Skilled Origin feat

Suggested branch: `codex/crown-skilled-feat`. After G2/G3 integration.

- Add generic source-owned selectable skill/tool proficiency effects and the
  actual source-backed, repeatable Skilled definition. Use existing feat
  eligibility/acquisition and class proficiency-choice machinery where it fits.
- Current feat feature ownership accepts only `mode_choice`/`rule_upgrade`;
  this is a missing effect host, not a JSON-only assignment. Support distinct
  acquisition occurrences without colliding feature identities or losing
  overlapping class/species/other-feat proficiency sources.
- Prove legal skill/tool combinations, creation Origin selection, repeat
  acquisition through an entitled level-up, refusal/cancellation, and allowed
  save/reload without replaying grants. Neutral/renamed data must work too.
- Scope: feat/proficiency acquisition, exact saved choice ownership, one real
  feat definition and focused input/recovery checks. Use classes/persistence,
  `quick_wins_flow`, normal creation and the new focused actual-consumer checks.
- Exclude Alert/Savage Attacker combat rules, Magic Initiate casting, background
  acquisition, all ten feats in one PR, and another replacement feat chooser.

### G5 — Prepare the four backgrounds against actual contracts

Suggested branch: `codex/crown-background-preparation`. Source preparation can
start independently; reconcile with G2/G4 before finalizing.

- Source-pin Acolyte, Criminal, Sage and Soldier: allowed ability choices, Origin
  feat, skills, tools and equipment/GP alternatives with exact item quantities.
- Map clauses to the existing acquisition contract and identify precisely what
  S-231 still needs. Required feats are Magic Initiate, Alert, Skilled and
  Savage Attacker; the latter two combat/casting areas are not supplied merely
  by having an Origin picker.
- Keep candidate records in an explicitly non-loaded preparation location and
  link them from the existing Crown content scope. Do not add a production
  background type/creation step or expose incomplete records in this PR.
- This is a preparation PR, not background gameplay completion. Validate source
  references, item/quantity resolution and candidate structure; local production
  integration follows when the effect hosts are ready. Do not edit
  `tools/content_editor/` or create a parallel acceptance ledger.

### G6 — Prepare one missing subclass: Draconic levels 3–5

Suggested branch: `codex/crown-draconic-preparation`. Optional next independent
preparation job after the first implementation PRs; do not start nine subclasses.

- Read the selected Sorcerer source and map Draconic Resilience and Draconic
  Spells through class level 5 to current AC/max-HP/source-spell owners.
- Pin exact clauses, candidate declarations and actual missing consumers.
  Check the current AC host's limits before assuming another formula fits.
- Keep unsupported definitions outside runtime loading. No enabled placeholders,
  class-ID branches, level-6+ features or claim that a source map is acceptance.
- Update the existing class contract/content-scope row with preparation links;
  check references and candidate structure. A later implementation PR uses the
  pinned example once the specific generic gaps are ready.

## Work still required after this queue

These PRs buy useful progress; they do not finish the character milestone.
Background acquisition still needs its real step/grants and remaining Origin
effects. Species still need choices/languages, the two absent species and
character-level 3/5 grants. Rogue's restricted Martial proficiency needs a real
weapon-property eligibility consumer, not a replacement category string.
Production multiclassing needs staged feature/subclass/resource/casting support.
The other feats and twelve class packages retain their full scoped clauses.

The Crown roadmap also retains reaction/off-turn spell hosts, source lifetimes,
forced/compelled movement, spell-created actors/forms, cover/physical/environmental
effects, illusions/communication/knowledge, components/equipment/weight/ammunition,
travel/traps, reachable monster traits and actual spell conversion. Work on these
by named consumer and proven prerequisite; do not parcel broad slices or the 81
refused spells into arbitrary equal batches.

The final gate remains the ordinary level-1–5 campaign journey, checkpoint
recovery and live controls/pacing observation. Preserve the existing native
paths until replacements cover their consumers.

## Verification and integration rules

- Use `run_tests.ps1` and Windows Godot 4.7 for runtime evidence. If Grokbot lacks
  that host, state exactly what ran and what remains for local verification;
  Python/schema checks do not substitute for gameplay or acceptance.
- Add regressions for changed/likely failures, not another full harness. Extend
  the existing logic groups, input scenarios and fresh-process probes.
- Use one focused independent reviewer for shared combat or persistence changes,
  asking about exact source ownership, once-only grants/costs and stale/reload
  behavior. This planning review does not replace each implementation review.
- Integrate one PR, run its relevant checks, update its bounded acceptance, then
  start the next overlapping acquisition PR. Keep broad roadmap/registry edits
  small to avoid colliding with local S-237 updates.
- No deletion, installation, publication, automatic save migration or editor
  pipeline edits are part of these assignments. This document prepares work;
  it does not send a Grokbot message or open a GitHub issue/PR.
