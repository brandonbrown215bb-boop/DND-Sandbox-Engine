# Spell behavior audit and character delivery plan

> Historical snapshot, not current priority or acceptance. See the
> [documentation map](../README.md) for current authority. Findings, counts,
> gate decisions and execution orders below apply to the dated snapshot;
> reproduce relevant behavior before reopening a defect or reusing a claim.

Implementation follow-up: the baseline and first seven-spell effect batch are
now implemented. Current verification is in [the checkpoint](../operations/current.md)
and the generated [single status list](../mechanics/spell-status.md). Findings
below describe the audit that prompted the work; they are not live defect status.

Reviewed 2026-10-05 against the current uncommitted production source, the
actual DataLoader export, and a narrow Windows Godot probe. This is a shared
behavior audit, not a complete SRD audit of 362 spells or twelve classes.
The earlier building-block review's five repaired defects remain historical;
the findings here concern current spell delivery.

## Decision

The next substantial chunk should be **source-owned timed effects and
concentration**, after repairing the current parse errors and spell picker.
The existing attack, typed damage, healing, progression and resource boundaries
are useful foundations. The missing repeatable behavior is the life of an
effect after casting: ownership, expiry, repeat saves, and selective cleanup.

Then resume character acceptance in the roadmap's class order. Complete the
spells required by each class feature and enough working choices to exercise
its progression; keep incomplete catalog coverage explicitly partial. Do not
turn finishing the entire catalog into the entry requirement for testing class
mechanics. Full caster completion still requires all its legal spell choices
and promised outcomes; this plan does not reduce the approved core-12 scope.

## Findings worth acting on

### 1. Fix now: ordinary high-level spells are disabled in the actual picker

A level-17 Cleric with Heal and a level-6 slot sees a disabled item labeled
`[No eligible Arcanum]`. The level-greater-than-five restriction in
`CombatHUD._show_spell_selection()` is not limited to Warlocks. The execution
path can accept ordinary high-level casting while the player cannot select it.
This blocks high-level characters regardless of how many spells are added.

Smallest fix: apply the Arcanum restriction only to the appropriate Warlock
path and check ordinary slot eligibility for other casters. Add a small picker
regression covering an ordinary caster, eligible Arcanum, exhausted Arcanum,
and a legitimate free cast. Use the actual item-selection path in acceptance.

Source: `src/combat/combat_hud.gd:319`, especially `:362`.
Godot reproduction: `.artifacts/spell-status/behavior-audit-probe.log`.

### 2. Fix now: effectless spells can be selected and charged as successful casts

The Godot probe casts Invisibility through the production resolver: success
is true, the level-2 slot falls from one to zero, and there is no Invisible
effect. The loaded record has no effect payload; the production effect handler
has no dedicated Invisibility implementation. Hold Person and Bane have save
metadata without their paralysis or roll-penalty payloads. Jump, Levitate,
Silent Image, Disguise Self, Arcane Eye and Speak with Dead also lack their
required payloads and dedicated handlers.

This is particularly visible in Warlock invocations: the free-cast grant can
work while the promised spell does nothing. The cast refusal guard covers
explicitly tagged partial records; unmarked legacy records slip through.

Smallest fix: one explicit runtime availability decision, shared by choice
screens, the combat picker and execution. A registered ID is not sufficient.
Refuse unsupported operations before spending actions, slots, components or
feature uses, and show a reason. Preserve existing choices/saves; do not delete
owned spells or silently replace them. The delivery register records evidence,
but should not become a runtime dependency on documentation or test totals.

Sources: `src/autoload/data_loader.gd:1171`,
`src/characters/character.gd:292`, `src/characters/class_progression.gd:212`,
`src/combat/combat_action.gd:1162` and `:1264`,
`src/combat/combat_state.gd:2669` and `:4772`.
These nine records now have `unimplemented_exposed` status in the single
[spell register](../mechanics/spell-status.md); Mending remains the tenth.
The remaining unaudited records have not been assumed safe.

### 3. Fix now: ordinary effects do not reliably own their lifetime or removal

Character conditions generally store only `condition -> remaining turns`.
Reapplication keeps the longer duration, and a target's end of turn decrements
all ordinary conditions. Generic concentration cleanup removes the condition
by name. If two casters grant the same condition, ending one concentration can
erase the other's benefit. Protection from Energy similarly stores one type,
while Protection from Evil and Good already demonstrates per-caster ownership.

Several spells have private duration functions and repeat-save branches.
Ray of Sickness already records a known mismatch between target-turn expiry
and caster-turn expiry. Adding more spell records to these paths repeats
special cases and carries timing mistakes into class abilities.

Smallest fix: extend the existing condition/source helpers to identify each
active cast and its caster, targets, expiry boundary and saved DC. Remove only
that cast's grants, while retaining other sources. Apply the same operations
to Characters and monster dictionaries. Migrate only the representative spells
in the next chunk; preserve current class conditions and legacy defaults.
This does not require a complete CombatState extraction or universal effect
engine.

Sources: `src/characters/character.gd:1290` and `:1307`,
`src/combat/combat_action.gd:58` and `:299`,
`src/combat/combat_state.gd:3396`, `:4547` and `:4663`.

### 4. Fix when touched: persistent areas need their own behavior batch

The shared area-selection operation is explicitly transient and returns
`persistent: false`. Selecting hexes and resolving damage once does not provide
a standing zone's entry/turn triggers, movement restrictions, recurring costs
or concentration removal. Forty-five spell IDs are assigned to this planning
family; that number is a backlog grouping, not 45 proved identical defects.

Smallest fix when a character requires a zone: implement one bounded zone with
the required placement, lifetime, trigger and movement behavior, then reuse it
for compatible spells. Do not fold every wall, aura and unusual area into the
first implementation.

Source: `src/events/event_resolver.gd:50`; register family `persistent_areas`.

## Next chunk and its finish line

First restore parsing: the active SRD quest owns the three Hold Monster type
annotations identified in the current checkpoint. Fix the picker defect and
the availability decision before adding more selectable unsupported spells.

Use these seven spells as the first effect-lifetime batch:

| Representative | Behavior it must prove |
|---|---|
| Bless and Shield of Faith | Multi/single-target benefits; correct duration; overlapping sources; selective concentration cleanup. |
| Hold Person and Hold Monster | Eligible creature targeting; failed-save paralysis; repeat saves; release and source-specific cleanup on both entity types. |
| Ray of Sickness | Hit-only condition; expiry tied to the correct caster boundary. |
| Ray of Enfeeblement | Distinct successful/failed-save outcomes; repeat save and consumption/expiry of the temporary penalty. |
| Animal Friendship | Existing source ownership and damage break remain correct; long duration has an explicit cross-encounter policy. |

Finish this chunk when the actual UI can select and cast them, costs are paid
once, invalid selections/cancellation spend nothing, and applied effects change
gameplay. Successful enemy saves and interruptions follow their actual casting
cost rules. Switching concentration, losing it, expiry and repeat-save success
must remove only the matching cast. Reordering initiative must not change which
turn boundary expires an effect. Two casters supplying the same condition must
not cancel each other or create unintended stacking.

Define what happens when combat ends and campaign time advances. Save only at
existing legal safe points: retain any effect required to survive that boundary
with stable identities/remaining duration, or explicitly document the remaining
unsupported behavior. Never claim full long-duration spell support from combat
timers alone. Do not add mid-combat saves to accomplish this.

## Return to characters, with an explicit dependency queue

| Class dependency | What must be accepted before claiming it works |
|---|---|
| All eight casting classes | Real selection, preparation/book choices, slots/free casts, action costs, targeting, result, recovery and save/reload. Working choices at the levels/capacities being tested. |
| Bard | Power Word Heal/Kill grants and outcomes; Magical Secrets choices must execute. Existing checks are not complete certification. |
| Cleric | Divine Intervention routes to a supported selected spell without forbidden costs; Greater Intervention's Wish modes and rest cooldown stay explicitly partial until delivered. |
| Druid | Wild Companion's familiar behavior; Wild Shape/Beast Spells casting restrictions and components through the shared cast path. |
| Paladin | Divine Smite after a qualifying hit; Find Steed ownership, command/recovery and persistence. Reuse existing helpers where verified. |
| Ranger | Hunter's Mark costs, target transfer, concentration and later feature interactions. |
| Sorcerer | Metamagic on representative attacks, saves, multiple targets and timed effects; components and duration must affect real casting. |
| Warlock | Ten fixed spell grants listed below, plus Pact slots, invocations and level-6–9 Arcanum choices. Seven granted utilities are currently effectless. |
| Wizard | Book/preparation capacities across progression; ordinary high-level casting, recovery, Mastery and Signature free/paid choices; save/reload. |

The ten fixed Warlock dependencies found in current class effects are Arcane
Eye, Contact Other Plane, Disguise Self, False Life, Invisibility, Jump,
Levitate, Mage Armor, Silent Image and Speak with Dead. The effectless seven
are all except Contact Other Plane, False Life and Mage Armor; those three
still need complete acceptance. Selected Fiend grants add separate control and
zone dependencies, including Suggestion, Stinking Cloud and Wall of Fire.
Selected subclasses stay separate from base-class completion.

After the lifetime batch, implement only the missing shared operation needed
by the next class dependency: visibility/concealment, movement, illusion or
information interaction, companion behavior, or a persistent zone. Give each
one a bounded representative and observable finish line. Then batch remaining
spells by the existing fourteen families. Keep the full catalog backlog open
and update the one register after each accepted batch.

## Verification and limits

No 1,700-assertion run was needed for this audit. A narrow Godot probe reproduced
the high-level picker defect and the Invisibility resolver result in seconds,
and printed the other eight empty payloads. Source tracing confirmed no
dedicated handler for those records. The probe constructs the production HUD
controller and ItemList without rendering a full encounter; it does not prove
full scene wiring. Logs and disposable probe live in ignored `.artifacts/`.

The lifetime/overlap finding is source-confirmed, not a new live encounter
pass. Current full gameplay parsing remains blocked by the Hold Monster errors.
Use focused `spells,combat,conditions` checks while implementing this chunk,
plus actual picker/turn-order/overlap encounters. Add `classes` for class
integration and `persistence,world` when cross-encounter effects change. Run
the full logic suite once at batch acceptance, not after every spell addition.
The current focused spell group still contains the whole spell test function;
add narrower selection only if its measured runtime warrants it.

This audit changed reports/register evidence only. It did not repair gameplay,
claim current source is green, or take over the live implementation quest.
The configured team contracts were unavailable, so this was a solo audit;
no independent shared-combat review is claimed.
