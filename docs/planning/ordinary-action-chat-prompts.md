# Ordinary actions: prompts for separate chats

These are bounded assignments under S-237/S-238, not new counted engine slices.
The [registry](vocabulary-slices.md#ordinary-action-work-packages) owns their
status and the requirements left outside them. This split accepts no additional
behavior and does not change the 163/276 count or Crown's content scope.

**Dispatch history, not the current queue:** OA-01–OA-13 now have verified bounded
implementations in the registry. Do not start OA-01 or replay these prompts merely
because S-237/S-238 remain open. Select new consumers from the registry's retained
requirements; reuse completed packages and their evidence. The original OA-09/
OA-11 dependency on OA-08 and shared-file sequencing below describe dispatch.

Current Crown work follows the [cross-set engine mapping](crown-engine-mapping/README.md)
and its [bounded queue](crown-engine-mapping/assignments.md), starting with
**CXM-01/S-249 ammunition**. The delivered OA controls are reuse points for the
named later consumers; their whole parent slices are not prerequisites.

## Instructions shared by every prompt

Read AGENTS.md, roadmap.md, the registry's ordinary-action work packages and the
selected prompt below. Use current source and documented evidence; the original
uncommitted ordinary-action work has since integrated. Preserve unrelated work.
Read the relevant section of [ordinary-actions.md](../mechanics/ordinary-actions.md)
and source-pin the selected SRD 5.2.1 clauses before implementing them. For class
source work, start at [reference/2024](../../reference/2024/README.md).

Implement only the selected assignment. JSON must describe supported rules;
do not add spell, feature, item or monster ID branches. Loaded neutral/renamed
fixtures through actual production controls can prove the engine. Catalog
conversion is separate. Reuse delivered actions, Ready, Search/Help, Study,
Influence, hearing and cover rather than rebuilding them.

Finish the stated behavior and checks, then stop. If an absent prerequisite
would require another world system, record its exact missing fact/operation and
one finite follow-up rather than silently expanding this assignment. Do not
mark the assignment complete with that required behavior still missing.
Unsupported routes must refuse before payment; preserve existing native paths.

Use the supported Windows Godot runner from [testing](../testing.md) and
[development](../operations/development.md). Run the checks relevant to the
change; reuse applicable existing evidence rather than repeatedly running the
whole suite. Add regressions for likely failures introduced by the selected
behavior. For shared combat or persistence changes, use one focused independent
reviewer with a concrete question and reproducible checks, as AGENTS.md requires.
No mid-combat/mid-decision saves or automatic legacy migration.

Update the mechanics contract if behavior changes, this assignment's registry
status/evidence and any exact remaining dependency. Do not duplicate test logs
here, accept the whole parent slice, create a PR, publish, install tools or delete
files. Finish with what works, remaining limits and the relevant checks.

Each block below is a complete chat starter: it tells the next agent to read
these shared instructions as well as the selected assignment.

## OA-01 — Review and finish the represented flat-grid cover boundary

```text
Read docs/planning/ordinary-action-chat-prompts.md, including its shared
instructions. Work only on OA-01.

Review the existing S-238 flat-grid cover implementation against its documented
boundary. Cover Half/Three-Quarters/Total obstruction, intervening creatures,
weapon/shared-spell AC, DEX saves, direct targeting, area origins, source-specific
partial-cover exemptions and the cover-dependent Hide gate. This is review and
repair of an existing implementation, not a rewrite.

Use current source and existing receipts to identify missing proof or concrete
bugs. Exercise changed or unproven paths through production controls, including
transparent physical obstruction, opening/removing an obstacle, Sacred Flame's
save exception and Total Cover refusal before payment. Preserve familiar/effect
origins and captured/rerolled saves. Do not rerun every old green flow by default.

Finish by recording whether this exact standing, flat-grid boundary is verified.
List posture, diagonal apertures and elevation separately, with a named Crown
consumer if one is known; unknown demand is not proof those requirements are
finished or outside Crown. Do not build general 3D geometry or accept all S-238.
```

## OA-02 — Selected-target origins for player combat spell sound

```text
Read docs/planning/ordinary-action-chat-prompts.md, including its shared
instructions. Work only on OA-02.

Extend the existing declared effect_noise vocabulary so an ordinary player
shared combat cast can emit from its exact selected target/object rather than
always the caster. Source-pin Knock's target-origin sound as a requirement;
neutral/renamed fixtures may prove the operation without converting Knock.
Keep existing caster-origin declarations compatible.

Use the existing ordinary/readied spell completion and sound owners. Capture
the correct source identity/location, validate declarations before payment,
emit once after completion and snapshot listeners at emission. Keep the actor
who acted distinct from the place making sound; source-pin Hide-ending policy
rather than treating every distant boom as sound made by the caster.

Prove distinct caster/target positions, range/obstruction/plane and deafness,
ordinary completion, Ready hold/release/cancellation, stale target refusal and
one owning sound Reaction. Monster, room, Reaction-cast and native spell hosts,
attack/item/movement noise and catalog conversion are outside this assignment.
```

## OA-03 — Effect sound from ordinary monster shared-spell casts

```text
Read docs/planning/ordinary-action-chat-prompts.md, including its shared
instructions. Work only on OA-03.

Enable the existing caster-origin effect_noise declaration on ordinary monster
shared-spell casts through the actual AI/monster cast path. Reuse the existing
completion, hearing and Ready owners. Do not add a second sound implementation
or infer sound for every spell.

Prove a loaded renamed monster spell really casts and pays once, emits once
after completion (also on a miss or empty eligible area), reaches only eligible
listeners and triggers the correct Ready owner without stealing the monster's
or interrupted player's budgets. Interrupted/refused casts emit no effect sound.
Preserve the separate Verbal-component sound.

Player, room and target-origin extensions are separate assignments. Direct
resolver, Reaction-cast and native hosts remain refused for declarations they
cannot execute. Do not turn this into general monster casting repair.
```

## OA-04 — Effect sound from existing room shared-spell casts

```text
Read docs/planning/ordinary-action-chat-prompts.md, including its shared
instructions. Work only on OA-04.

Enable caster-origin effect_noise for shared spells already legal through the
represented local-room casting controls. Reuse current spell payment/completion,
room clock and sound/hearing owners. This does not authorize making every combat
spell legal in exploration or building a new room spell executor.

Drive an actual loaded renamed room cast. Prove once-only payment/time and sound,
actual party listener receipts, walls/open routes, plane, Deafened/Silence and
Hide ending while preserving independent Invisibility. Cancellation/refusal
must not advance time or emit; an allowed checkpoint must not replay the sound
or cast. Add fresh-process proof only if durable state changes or a recovery
route is affected.

No world sound history, automatic passive discovery, target-origin room sound,
Reaction casts, native conversion or overworld sound simulation in this task.
```

## OA-05 — Medicine Search for authored local clues

```text
Read docs/planning/ordinary-action-chat-prompts.md, including its shared
instructions. Work only on OA-05.

Add one bounded non-Perception Search route: Wisdom (Medicine) for an authored
injury/cause-of-death clue on an exact represented local source. Pin the SRD
Search clause first. The outcome must reveal actual declared information to
that observer, not just log a successful roll or heal/stabilize the target.

Reuse the local Search chooser, shared check/Help owner, source identity,
observer disclosure and existing allowed-checkpoint receipts where applicable.
Build only the source facts needed for this clue. Prove the real control,
success/failure non-disclosure, appropriate access, time/payment, stale source
refusal and observer-specific recovery without reroll/replay.

Limit this assignment to room controls and this one skill/task. Creature-wide
medical simulation, disease/poison diagnosis systems, combat/Ready expansion,
Insight, Survival, passive Search, sharing, traps and overworld Search stay out.
```

## OA-06 — Insight Search for authored local creature clues

```text
Read docs/planning/ordinary-action-chat-prompts.md, including its shared
instructions. Work only on OA-06.

Add Wisdom (Insight) Search for authored intent/emotion clues on an exact live
encounter creature, following the SRD Search clause. Reuse existing encounter
identity, ordinary Action targeting and shared check owners; use any reusable
authored-clue operation delivered by OA-05 without requiring that assignment.

An eligible success discloses only the authored clue to the searcher. It must
not read arbitrary thoughts, alter attitude, compel obedience or expose the
creature's complete profile. Prove actual combat controls, success/failure,
source/access guards, matching Help, cancellation/stale choice and once-only
Action payment. Preserve observer knowledge through existing allowed checkpoints
if this host stores durable knowledge; do not create combat saves.

Limit this task to combat ordinary Search on represented encounter creatures.
Ready, noncombat NPCs, deception simulation, illusion investigation and the
Medicine/Survival/overworld Search routes are separate.
```

## OA-07 — Survival Search for authored local tracks

```text
Read docs/planning/ordinary-action-chat-prompts.md, including its shared
instructions. Work only on OA-07.

Add Wisdom (Survival) Search for authored tracks on an exact represented room
space/source, following the SRD Search clause. Reuse the room Search control,
shared checks, location/access guards and observer receipts. A success reveals
declared track information to the searcher; it does not create a path, move the
party or invent the quarry's identity/location.

Prove the real room control, correct versus wrong vicinity, access/sense facts
appropriate to the authored clue, failure non-disclosure, matching Help,
once-only time and stale/cancelled choices. Preserve discovered information
through allowed checkpoint recovery without rolling or charging again.

Do not build overworld tracking, travel pace, navigation, foraging, passive
Search, general footprints generated by movement, Medicine or Insight here.
```

## OA-08 — Spoken communication between represented local actors

```text
Read docs/planning/ordinary-action-chat-prompts.md, including its shared
instructions. Work only on OA-08, the prerequisite for OA-09 and OA-11.

Supply a bounded spoken-communication eligibility operation for actual local
senders/listeners: declared known languages, same plane, an eligible speaker,
listener hearing, represented sound route and declared communication range.
Keep understood language separate from merely hearing a voice. Unknown language
facts must not silently become Common or shared understanding.

Use the simplest actor/data fields and existing persistence owners needed to
retain declared language knowledge. Reuse a current language owner if one has
landed. This is engine support with loaded renamed fixtures, not species/class
language-grant conversion or a creation-language chooser.

Prove shared versus unshared/unknown language, range/obstruction/plane,
Deafened/Silence, stale actors and allowed reload for any added durable facts.
This task determines eligibility; it grants no Help, knowledge, obedience or
free Action. Written language, telepathy, borrowed senses, speech spells and
overworld conversation controls remain separate. Document range as authored
host policy where the source does not specify it.
```

## OA-09 — Verbal Help on existing local checks

```text
Read docs/planning/ordinary-action-chat-prompts.md, including its shared
instructions. Work only on OA-09 after verifying OA-08 is available.

Add explicitly declared verbal assistance to the existing local combat/room
skill-check Help controls, using OA-08's actual speaker/listener eligibility.
Only checks whose authored task permits useful verbal assistance qualify;
hearing advice must not substitute for physically manipulating a tool/object.
Pin the SRD Help requirements rather than relaxing proficiency or expiry.

Reuse the exact next-matching-check benefit, payment, live revalidation and
turn/room-clock expiry. Prove a real supported local check receives Advantage
once, unrelated checks preserve it, expired/inaudible/ununderstood assistance
cannot apply, cancellation pays nothing and conditions still compose.

Keep delivered physical Help working. No general stored Advantage, banked
assistance, overworld/event Help, tool-task implementation or NPC conversation
system. This assignment does not require all future checks to support Help.
```

## OA-10 — Study from authored memory without a visible object

```text
Read docs/planning/ordinary-action-chat-prompts.md, including its shared
instructions. Work only on OA-10.

Extend Study to one authored recollection question with a declared Intelligence
skill/DC/answer, available to the actual character independently of observing
a live room object. Pin the SRD Study/recollection clause. Reuse existing
question validation, shared check resolution and per-observer knowledge where
possible; do not fake an invisible object to satisfy observation guards.

Expose this through the local-room Study/Knowledge controls. Prove a real
attempt, success/failure non-disclosure, actual matching Help where eligible,
once-only time, free recall of the learned answer, and per-character recovery
through allowed checkpoints without replay. Unknown questions remain unknown.

One recollection host is the finish line. Written-language comprehension,
creature/spell identification, illusion investigation, research durations,
quest rewards, combat/Ready memory controls and overworld knowledge are separate.
```

## OA-11 — Spoken Influence using existing combat requests/outcomes

```text
Read docs/planning/ordinary-action-chat-prompts.md, including its shared
instructions. Work only on OA-11 after verifying OA-08 is available.

Extend the existing encounter Influence requests with source-backed spoken
Persuasion/Deception approaches using actual OA-08 language/hearing eligibility.
Reuse authored willingness/motivation/attitude, live request selection, checks,
retry deadlines and once-only fulfillment. Keep the existing real open/close
object outcomes; do not add rewards, allegiance changes or arbitrary commands.

Prove ordinary combat and readied spoken requests through actual controls:
understood versus unheard/ununderstood speech, willing/unwilling/hesitant
outcomes, the exact participant/request/object, failed retry, one payment and
one object consequence. Preserve gesture Influence, correct Help eligibility,
and allowed checkpoint recovery without repeating a completed request. Speech
noise and communication must use the existing owners with explicit host policy.

No noncombat NPC representation/UI, overworld conversations, telepathy,
speech-spell conversion, general dialogue tree or new outcome kinds here.
```
