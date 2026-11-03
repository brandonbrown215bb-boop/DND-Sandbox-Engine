# Ordinary combat actions

The combat **Actions** button offers Ready, Dash, Disengage, Dodge, Hide, Help a
skill/tool check, Help an attack, Help to stabilize, Search (Perception for hidden
creatures, Insight for an authored live-creature clue, or Survival for authored
tracks), Influence for authored
creature requests, plus Utilize and Study for represented room objects. The existing Dodge button uses the same owner. `ordinary_action`
commands carry an action name and, for check Help, the selected proficiency;
`CombatState` assigns the Action cost. A caller cannot supply a cheaper cost.
Selecting a target costs nothing until a legal click; cancellation, a lost
Action, an unknown location, a dead target or an out-of-range click grants
nothing. Incapacitated actors cannot use these actions.

These rules follow the [SRD 5.2.1](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf),
pp. 18, 179, 181–183, 186–187 and 189. The
[slice registry](../planning/vocabulary-slices.md#ordinary-action-continuation)
owns verification and remaining S-237 scope.

## Effects and feature reuse

- Dash adds current effective Speed to this turn's remaining movement. It does
  not refill spent movement or replace terrain/path costs. Repeated legal Dash
  actions can each add Speed, with their own Action or Bonus Action costs.
- Disengage uses the movement owner's existing Opportunity Attack exclusion
  for the remainder of this turn.
- Dodge lasts through the current turn and ends at the next owner turn's start,
  before start-of-turn effects. Attacks have Disadvantage only when the defender
  can see the attacker. The central Character and monster save owners grant
  Dexterity-save Advantage. Incapacitation or effective Speed 0 removes Dodge;
  curing the disabling condition or expiring its speed modifier does not restore
  it. Using all remaining movement does not reduce Speed to 0.
- Help an attack distracts an exact known enemy within 5 feet, with an unblocked
  ray. The next actual allied weapon/spell attack consumes the benefit once;
  the helper cannot consume its own Help. The unused benefit ends at the helper's
  next turn start. This reuses the familiar Help carrier; multiple helpers do
  not bank several advantaged attacks on the same enemy.
- Help to stabilize selects a dying, unstable adjacent ally and resolves an
  actual DC 10 Wisdom (Medicine) check. Success calls the existing stable-state
  owner; it does not heal or wake the ally.
- Help a skill/tool check selects one of the helper's actual proficiencies and
  an adjacent ally with an unblocked ray. Half proficiency does not qualify.
  `CheckHelpRules` grants Advantage on that ally's next matching actual
  `EventResolver` check before the helper's next turn starts. Tool matching uses
  the check's `tool_id` (or `check_context.required_tool_id`) and the loaded tool
  name/ID. An unrelated check preserves assistance; multiple matching helpers
  are consumed by the same check, without banking later rolls. The live check
  context must contain the grid and both participants; assistance requires
  the same proximity, an able helper and its still-owned proficiency then.
  Existing conditions compose with this Advantage. Teardown clears unused Help.
  This host represents physical assistance; verbal assistance is a separate,
explicitly authored route below.

### Spoken communication

`CommunicationRules` answers only whether two represented local actors can
understand a spoken exchange. Each actor uses declared language knowledge:
characters persist `known_languages`, while loaded creature definitions may
declare `languages`. There is no inferred Common, automatic species conversion,
written comprehension or telepathy. The speaker must be alive, able to speak and
not Silenced; the listener must be alive, able to hear, not Deafened/Silenced,
and share a language. They must be on the same plane, within the host's 30-foot
range, and connected by an actual whisper sound route through current sound
obstacles. Hearing a voice alone does not prove comprehension. The 30-foot
communication range is explicit local-host policy, not a universal SRD range.
Language facts use the existing character save DTO and preflight; legacy saves
with no field keep an empty, unknown language list.
Preflight checks both player copies and canonical party characters, including
companions; malformed or duplicate language/recollection facts refuse the save
before restore rather than becoming knowledge or silently disappearing.

### Verbal Help

The local room and combat check-Help controls offer Physical or Verbal. Verbal
assistance still requires an actually owned skill/tool proficiency and retains
the same matching, once-only Advantage carrier. It uses OA-08 language, speaker,
listener, plane, range and sound-route eligibility, and is revalidated at the
check. The current authored task must declare `verbal_help: true`; ordinary
object manipulation and any undeclared task do not inherit it. Verbal Help cannot
make an otherwise inaccessible physical check eligible. It expires on the same
room interval/helper-turn boundary and uses the same Action/Reaction settlement.
This is a bounded extension of the Help action, not general Advantage or an
additional turn. Help's skill/tool requirements follow SRD 5.2.1, pp. 181–183.

Check Help's command is:

```json
{"action":"help_check", "proficiency_kind":"skill", "proficiency":"Athletics"}
```

Use `proficiency_kind: "tool"` with the owned tool proficiency name for tools.
The HUD offers owned choices and the command boundary revalidates ownership.

### Room Help

The room **Help a check** controls choose an owned skill/tool proficiency and
an ally. Choosing costs nothing; pressing Help resolves one six-second world
Action. Both characters must be able, outside containment, on the same plane,
within five feet horizontally and vertically, with an unblocked physical ray.
Search and physical object checks supply the actual room participants to the
same `CheckHelpRules`/`EventResolver` owner used in combat. The helper must
still own that proficiency and remain able and in reach when the check happens.
Unrelated checks preserve assistance; matching helpers all apply to one check.

The room's sequential world clock represents the next-turn deadline as the
next six-second interval after Help completes: a grant created at time T pays
through T+6, is usable before T+12, and expires at T+12. This is a bounded host
policy, not an SRD rule for exploration pacing. Unused Help clears on room exit,
does not enter combat or saves, and creates no new checkpoint. Verbal Help,
general overworld checks and other world check owners remain separate.

Native Rogue and Monk movement/defense features call the same effects after
their declared cost/resource settlement. A loaded, renamed `cunning_action`
feature with `options: ["dash", "disengage", "hide"]` also gets the existing
movement picker; no feature-ID registration is needed. Its resource declaration
still supplies its available uses and cadence. The picker refuses a response
after the owning turn changes.

## Ready and held spells

`ReadyActionRules` owns encounter-local declarations, completed triggers and
Reaction delivery. The Actions chooser selects a trigger, its creature/side,
optional space/proximity, and response. The equivalent `ready_action` command
uses this shape:

```json
{
  "trigger":{"event":"movement", "side":"enemy", "within_hexes":1},
  "response":{"kind":"attack"}
}
```

Triggers support `movement`, `attack`, `cast`, `action` and `sound`; `side` is
`enemy`, `ally` or `any`. Optional `actor_id` identifies an exact creature,
`within_hexes` bounds distance from the Ready owner and `at_hex: [q, r]` selects
a board space. Movement publishes after each completed step, including forced
movement and teleport arrival. Attack and cast publish after their current
resolution. Completed-action producers also cover paid player consumables,
Shield controls, feature effects and targeted features, mode/item projection
controls, created-creature orders, paid child-parent completion (including
forfeiture), marker movement, tether/zone escape, rescue and shaking Sleep awake.
They publish after the operation's choices and effects settle; opening a picker,
an unpaid refusal or cancellation does not publish a completed action. A paid
failed check still does. Ordinary actions and monster turns retain their events.
Sound comes from Verbal casting, declared paid object operations and declared
player combat spell effects, and needs a represented open sound route and a
non-Deafened observer; other noise producers remain open.
Declared shared spell effect sound also publishes after the spell's effect and
Action settlement, including a readied release; see [effect sound](#spell-effect-sound).
Visual triggers require the owner's actual sight. A componentless enemy cast
cannot trigger the cast response. A creature perceives its own movement/action
without needing to see itself.

Responses are `attack`, `move`, `ordinary` with `action`, or `spell` with the
normal permissioned `spell` payment selection (including slot-free cantrips).
Ordinary responses use the
supported actions above, excluding Ready itself; check Help also captures its
chosen proficiency. Ready pays the owner's Action now and expires before the
next owner turn starts. A perceivable completed trigger opens the owner's
Reaction prompt. Ignoring it or cancelling targeting preserves the held response
and Reaction. Acceptance revalidates the owner, exact targets, range, path and
resources after choices, then pays that owner's Reaction once. Attack releases
one strike with the captured exact weapon; Extra Attack does not apply. Movement
uses current Speed and the selected movement mode, ordinary terrain/fear/fall/
Opportunity Attack rules, and its own allowance. Neither response refills or
borrows the interrupted actor's Action, Bonus Action or movement.

`ReadySpellRules` casts an available Action-time spell immediately. It settles
the casting Action, slot/use, Metamagic, consumed component copy, Counterspell
and cast activity at that point. A restricted extra Action cannot supply the
spell's casting. Holding any spell requires temporary Concentration, replacing
the previous concentration. Losing it dissipates the spell without a refund.
The release uses the existing spell owners with fresh live targeting, including
point/object/area targets and multiple projectiles/recipients. Its private paid
context permits release after the last slot/component was spent. Cancelled
attempts cannot clear the retained paid spell; release does not repeat payment,
Counterspell, cast activity or cast-time Invisibility/Sanctuary cleanup. A
Concentration spell starts its normal effect concentration when released.

Readied Disengage ends with the triggering turn. Readied Dash adds movement
for that turn but grants no independent permission to move off turn; choose
Ready movement for that. All held responses, transient grants and chooser
state clear at encounter teardown. Nothing here is serialized or creates a
new save checkpoint.

## Utilize room objects

`{"action":"utilize"}` uses the ordinary Action command and highlights visible,
reachable objects in the encounter's captured local room. Clicking an object
offers its existing physical interactions: open/close, lock/unlock with a key,
pick a lock, pry/force open, bar/unbar, jam/unjam, extinguish and take/put an exact
item. Spell casting, weapon strikes and inspection use their existing owners;
they are not offered as Utilize interactions.

`CombatUtilizeRules` delivers those choices to `LocalRoomRules.interact`.
Opening a door updates actual movement/sight geometry; contents and inventory
change by exact instance identity. The actor's live combat position supplies
the room interaction origin. Skill/tool attempts receive the live encounter
check context, so matching adjacent Help is consumed by the real check.

The room, exact object, selected cell, actor/turn, sight, plane, horizontal and
vertical reach, available Action and selected item are checked again after
choices. Cancel, lost budgets, moved/replaced/removed objects and invalid tool
or inventory requests spend nothing. A legal attempt consumes one Action even
when its roll fails. Resolution and payment are synchronous after the last
guard. There is no campaign-time advance or new save checkpoint; changed room
objects use existing room persistence.

Ready can hold this ordinary response too. It selects an object and operation
at release, uses the same live guards, and pays only the Ready owner's Reaction
for an actual attempt. Objects sharing a creature's cell retain their own
identity. Cancelled or refused releases preserve both Ready and Reaction.
Encounters without a captured room have no object Utilize targets. Other tool
tasks and item-specific deployment effects still need their represented owners.

## Insight Search for an encounter creature

The combat **Actions → Search** chooser retains the existing Perception Search for
hidden creatures and adds a separate Wisdom (Insight) route for the SRD Search
clause: a Wisdom check to discern something not obvious, with Insight appropriate
to read a creature's intentions or emotions. See [SRD 5.2.1 Rules Glossary,
p. 187](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf#page=187)
and the Insight skill entry, pp. 181–183. OA-06 implements only this bounded
combat consumer; it does not broaden room or overworld Search.

A monster may declare exactly one clue:

```json
{"insight_search":{"dc":12,"kind":"intent_emotion","information":"Its gaze keeps returning to the sealed gate; it is anxious to protect someone behind it."}}
```

The target must be the exact living creature instance in the captured encounter,
with a matching encounter slot and authored monster source. The searcher must be
able, present outside containment, on the same plane, able to perceive the target,
and within the represented 30-foot horizontal/vertical access boundary. That
range and the visible-target control are bounded host policy, not a new SRD
range. Creatures without an authored clue are not selectable. After any exact
creature chooser, source, location, sight, plane, actor, Action and clue are
revalidated before the shared `EventResolver` Wisdom (Insight) check.

Success records `(encounter_index, monster_id, observer_id)` in the existing
local-room state. The clue appears in that character's **Field Notes** in their
party inspector, not in the shared Chronicle; another party member's inspector
does not acquire it. No attitude, thought,
obedience, other profile fields or failed-check information is disclosed. A
failed check still pays one ordinary Action; cancellation and stale selections
pay nothing. The actual check receives matching `CheckHelpRules` assistance.
The receipt is validated as part of existing room checkpoints; combat decisions
remain transient and this action adds no combat save. Ready, noncombat NPCs,
deception, illusion investigation, Medicine/Survival/overworld Search and
catalog conversion are outside this assignment.

## Study and authored knowledge

The room **Study** button and combat **Actions → Study a room source** use
`StudyRules` to answer a declared observation question on an exact known room
object. Study follows the Intelligence-check action in
[SRD 5.2.1, p. 189](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf#page=189).
An object can declare:

```json
"study": [
  {
    "id": "spiral",
    "question": "What does the spiral mean?",
    "skill": "Arcana",
    "dc": 15,
    "answer": "The spiral marks a ward against flame."
  }
]
```

All five fields are required. Questions have unique IDs within their object;
`study` contains 1–32 questions. `skill` is Arcana, History, Investigation,
Nature or Religion; DC is an integral 1–1000. Nonempty identity/question/answer
strings are bounded to 4,000 characters. Unsupported fields and malformed
definitions refuse. This is authored information about represented observable
clues, not a prose interpreter or a declaration of any additional world effect.
There is no inferred answer for an undeclared question: it returns explicit
unknown, without a roll or cost.

Choose an object and question before paying. Room Study makes one actual
Intelligence check through `EventResolver` and costs six campaign seconds even
on failure. Combat pays one ordinary Action; a held Study pays only its owner's
Reaction when actually attempted. Cancellation and stale choices cost nothing.
The room duration and five-foot horizontal/vertical observation boundary are
bounded host policy, not universal SRD Study ranges or research durations.
The source must be alive/present, discovered by the observer, on the same plane,
outside containment and actually visible. Real sensory eligibility, proficiency,
Expertise, conditions, Exhaustion and matching physical check Help still apply.

Combat handles several sources in the same cell with an exact-source chooser.
It rechecks the original selected cell, object reference, room, actor/turn,
proximity/sight, available cost and captured question declarations after popups.
Moving/replacing/removing a source or changing its question cannot settle an
old choice. A paid failed Study publishes a completed action for Ready; free
recall, refused and cancelled requests do not.

Success records `studied_by: {"spiral": ["exact-character-id"]}` on that source.
Another object with the same question ID and another observer remain separate.
The room's bounded scrolling **Knowledge** box shows only the selected
character's learned answers for that room, including remembered information
after the source is destroyed/removed. Recalling a known answer is free and
does not reroll or duplicate its receipt. A failed check reveals no answer.
Existing allowed checkpoints preserve the exact source/question/observer through
full-party and player-only recovery. Duplicate/orphaned/malformed receipts fail
save preflight. Objects without these fields keep their existing behavior;
there is no migration or new mid-room/combat checkpoint.

A room may also declare 1–32 source-independent `recollections`, each with exact
`id`, `question`, Intelligence skill, DC, `answer`, and optional `verbal_help`.
The room Study selector exposes these alongside object questions without faking
an observed source. A successful answer is recorded in that character's
`known_recollections` under the room ID; the Knowledge box shows it only to that
observer. Failure does not disclose the answer, unknown IDs remain unknown, and
remembered answers are free. Existing allowed full-party/player-only checkpoints
recover the character-owned receipt, with no replay or mid-room save. This host
uses the same six-second Study interval and the existing Intelligence check
(clause pinned to SRD 5.2.1, p. 189). It is one authored memory host, not general
research or a new source of facts.

**Limits:** declared observation questions on room objects and their captured
encounters. General memory research, written-language comprehension, creature
lore/ongoing-spell identification, illusion investigation, communication/sharing,
overworld knowledge and authored quest/social consequences still need their
actual hosts. This supplies a bounded S-219 knowledge prerequisite, not full
S-219 or S-237 acceptance. Broader Influence remains separate from the gesture
host below.

## Influence through gestures or spoken communication

**Actions → Influence a creature** and readied ordinary Influence can urge a
loaded encounter creature to open or close a represented room object. This
implements a bounded version of [SRD 5.2.1, pp. 182–184](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf#page=184):
authored Willing and Unwilling responses need no check; a Hesitant response uses
a real ability check. Friendly grants Advantage, Hostile Disadvantage, and
Indifferent adds neither. The default DC is the greater of 15 and the target's
actual Intelligence score.

A monster definition can declare:

```json
"influence": {
  "attitude": "indifferent",
  "manipulates_objects": true,
  "requests": [{
    "id": "open_gate",
    "label": "Open the gate",
    "outcome": {"object_id": "hall_gate", "action": "open"},
    "approaches": [{
      "id": "ritual_greeting",
      "label": "Offer the ritual greeting",
      "skill": "Performance",
      "disposition": "willing",
      "reason": "The sentry enjoys the greeting and wants to welcome its performer."
    }]
  }]
}
```

The disposition and motivation are campaign-authored judgment about that exact
request and gesture; callers cannot submit a success flag or rewrite them in
the action command. Attitude defaults to `indifferent`. Requests contain exactly
`id`, `label`, `outcome` and `approaches`; approaches contain exactly `id`,
`label`, `skill`, `disposition` and `reason`, plus optional `mode: "spoken"`.
Without `mode`, the approach is a gesture. Spoken mode permits only Persuasion or
Deception and requires OA-08 communication eligibility; it never infers a shared
language. Other approach skills remain the visible Intimidation/Performance or
eligible Animal Handling gestures. IDs are unique within their source;
nonempty strings are bounded to 4,000 characters. Profiles allow 1–32 requests
and 1–16 approaches per request. Unknown fields, unsupported outcomes and
malformed definitions refuse through DataLoader and the live command boundary.

Gesture approaches retain actual mutual sight and the 30-foot represented
boundary; Deafened does not block them. Spoken Persuasion/Deception instead use
OA-08 shared-language, eligible speaker/listener, same-plane, range and sound-
route checks, and can work without visual gestures. Both routes preserve the
existing approach disposition, target attitude and DC behavior. The 30-foot
Influence range is bounded host policy.

Selection pays nothing until an actual request resolves. An ordinary request
pays one Action, including an Unwilling refusal or failed Hesitant check. Ready
pays only the held response owner's Reaction on resolution. Willing/Unwilling
responses never roll or consume check Help. Hesitant checks use `EventResolver`,
with proficiency, Expertise, conditions, Exhaustion, matching physical Help,
attitude and exact-charmer Advantage composing normally. Charm does not change
the authored willingness or compel a repugnant request. The log shows the actual
check/DC or that no check was required. Paid refusals and failures publish a
completed Influence action; cancelled, stale and blocked requests do not.

The only outcomes are normal `open`/`close` delivered through
`LocalRoomRules.interact`. The creature must have a declared manipulation
capability, an available hand, same-plane physical reach within five feet, and
an available, uncontained, nonconcealed door/container. Locked/barred/stuck/jammed
opening refuses before roll or payment. This does not grant keys, remote
interaction, forced opening, movement, domination or arbitrary AI commands.
Opening updates actual room/grid geometry. Declared object interaction sound is
validated before rolling and emitted after settlement from the actual NPC;
malformed sound refuses without cost. Spoken attempts publish the existing
whisper sound event from the actual speaker after payment, so ordinary sound-
triggered Ready owners remain authoritative. That sound does not imply the
listener understood it. The response is an immediate authored
object interaction, not a banked NPC combat Action or general extra turn.

Choices retain the original selected cell, exact creature, room, source profile
and selected outcome object. Live sight/reach/plane/hands and the Action/Reaction
are rechecked after popups. Mutating/removing/replacing a source, changing its
request or losing the budget cannot grant a free outcome. Co-located creatures
use an exact-creature chooser.

A failed Hesitant attempt records a 24-hour retry deadline for that actor,
creature slot, request and approach. A new attempt is allowed at the deadline;
another actor or authored approach remains separate. Fulfilled requests are
one-shot per exact encounter creature and request, across all actors: retrying
does not repeat the operation or charge again, even if another operation later
changed the door. These are bounded campaign request semantics. The room's
`influence_attempts` records pin `encounter_index`, `monster_id`, `actor_id`,
`request_id`, `approach_id`, `result` (`failed`/`fulfilled`) and `retry_at`.
Monster spawning preserves authored plane/free-hand facts and its original
encounter index. Existing round ticks advance the retry clock; declaration,
selection and recovery do not advance it.

Existing allowed entrance checkpoints preserve the actual object consequence
and retry/fulfillment records through both full-party and player-only saves.
Freshly instantiated encounters use the original room slot, so re-entry/reload
cannot evade a retry delay or replay a completed request. Duplicate, numeric,
orphaned or contradictory receipt fields fail preflight before session
replacement. Legacy rooms with no Influence records keep their existing behavior.
There is no new mid-combat checkpoint or general monster-state persistence.

**Limits:** production loaded monster definitions in captured room encounters.
No catalog NPC conversion, room/overworld conversation UI, written language,
telepathy, arbitrary request interpreter, changed allegiance, quest/reward
effects, perception suspicion or complete S-188/S-218/S-219 support. S-237/S-238
remain open.

## Represented sound

An object can declare sound for an existing physical operation:

```json
"interaction_noise": {
  "force_open": {"volume": "loud", "range_feet": 60},
  "pry": {"volume": "loud", "range_feet": 60}
}
```

The operation must actually resolve through Utilize and pay its Action or
readied Reaction. A failed rolled attempt still produces its declared sound;
cancelled/stale choices, missing tools and other refusals do not. Invalid sound
declarations refuse before rolling, changing the object or paying. Volume is
`loud` (above a whisper) or `whisper`; range is an integral 1–5280 feet.
Only declared operations produce sound. Crown's Temple door and Offering chest
declare loud forcing/prying; existing saved room records are not rewritten.

`CombatNoiseRules` ends Hide on a loud sound even with no Ready declarations,
preserving independent Invisibility sources. Whisper sound retains Hide.
The existing **After a loud sound** Ready trigger accepts only loud sound.
Verbal casts publish a loud sound using the existing 60-foot encounter hearing
boundary. These ranges are represented encounter policy, not an SRD universal
hearing table. The SRD Hide ending is immediate after sound above a whisper
([SRD 5.2.1, p. 183](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf#page=183)).

Hearing uses the shortest open route through represented adjacent hexes, with
each step counting as five feet, within the inclusive authored range and on the
same plane. Missing cells and sound-blocking walls/doors block a route; if an
open route goes around them, the sound can still arrive. Deafened listeners and
silenced endpoints cannot hear it; Blinded, fog, darkness and independent
Invisibility do not prevent hearing. Room walls (including glass) and closed
doors update the actual grid. Outside a bound room, `blocks_sound` controls a
tile, falling back to `blocks_sight` when absent. Hearing is captured per
observer when sound occurs: an earlier readied response cannot open a door to
hear an old sound or erase sound already heard by closing it. Response legality
and Reaction costs are still checked live. Combat sound receipts are
encounter-local. A local-room spell returns its listener IDs with that completed
cast result; the room does not save a sound event or replay it at a checkpoint.

This is a flat, unattenuated hex route. It does not model elevation, sound
attenuation, arbitrary prose noise or other action/item/spell noise producers.
A sound declaration does not implement a missing tool task or deployment effect.

Room object controls also resolve `interaction_noise` after an actual paid
attempt, including failed forcing/prying. They supply live room check context
so matching skill/tool Help can apply. Invalid sound declarations, tool/reach/
plane refusals and unpaid operations produce no sound or cost. Room sound
queries use the resolved door geometry and report the actual party listeners;
they do not invent combat Ready declarations, hostile AI reactions, persistent
sound events or discoveries from a sound that has already ended.

### Spell effect sound

A shared spell can declare one sound at its caster's position, or at its one
selected target's position:

```json
"effect_noise": {"volume": "loud", "range_feet": 300}
```

`origin` may be `"caster"` (the compatible default) or `"target"`. Target
origin requires one selected creature or eligible object. An ordinary cast
captures its identity, position and plane before slot payment. Ready validates
the declaration before holding the spell, then captures the exact release-time
target before spending the Ready Reaction. A stale source refuses at that
boundary. It does not select an arbitrary area recipient. Knock is
the source-pinned example: its loud knock is audible up to 300 feet and
emanates from the target ([SRD 5.2.1, p. 143](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf#page=143)).

This uses the same sound validation, live hearing routes, observer receipts and
Hide ending as object noise. It describes sound made by the effect itself,
independently of Verbal components or Subtle Spell. It emits once after the
spell's effect stages and Action payment, including missed attacks and empty
areas. Multiple recipients or ordered steps do not multiply the sound. A
readied spell emits only when released; losing held energy emits nothing.
Cancelled, refused or interrupted casts emit no effect sound. Verbal casting
retains its separate casting sound, including when interrupted.

The actor who cast the spell remains the sound event's actor for Ready
matching. The event's source is the caster by default, including for a Touch
spell delivered by a familiar, or the exact selected target when `origin` is
`"target"`. A loud sound ends Hide for a creature that is its source; a remote
target/object sound does not end the caster's Hide merely because they cast
the spell. A whisper retains Hide. Independent condition Invisibility stays
with its existing source owner. Silence suppresses sound through the existing
sound host.

Player combat Action/Bonus Action spells and their readied releases use this
completion host. OA-03 enables caster-origin declarations on the ordinary
monster shared-spell path, using the monster's live origin and the common
sound/Ready publisher after settlement. The validated AI command path also
supports an explicitly selected empty spherical area for a simple shared spell
with a declared effect sound. It spends one slot and records one Action only
after an empty-footprint check, including revalidation after a Counterspell
choice; an occupied, non-Sphere or otherwise unsupported area refuses before
payment. It does not resolve populated monster areas. A real Counterspell can
interrupt the monster's effect sound and refund its cast slot while the separate
Verbal casting event still reaches its normal sound/Ready owner. OA-13 also
supports one exact selected living creature as the target origin on the ordinary
monster shared single-target spell path; the monster remains the cast/Ready actor,
while the selected target owns the sound position, plane and Hide ending. Other
monster targets/hosts remain unsupported. Native data-declared caster-origin
sounds are supported on the ordinary player combat Action host and on the
verified Ready-spell release host; room, monster, Reaction and direct-resolver
native hosts still refuse before payment. Thunderwave is the currently declared
source-backed producer: its ordinary player combat Action and verified Ready
release emit the caster-origin `effect_noise` only after the native Cube effects
and settlement. The declaration is loud and has a 300-foot range, matching the
SRD boom ([SRD 5.2.1, p. 169](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf#page=169));
a production Ready listener 65 feet away verifies the effect sound separately
from the 60-foot Verbal casting sound. Ready pays the Action and slot at
declaration; cancellation, stale selection, expiry, concentration loss and
Counterspell interruption do not publish the effect boom. Counterspell refunds
the interrupted slot but not the Action, and the separate Verbal event remains.
This does not convert Thunderwave to the shared spell executor or enable its
sound through room, monster, Reaction or direct-resolver hosts. It does not make
other spells loud. OA-04
supports caster-origin room casts; OA-12 also supports exact selected party-creature
target origins on those existing shared room casts. Room target origins use the
selected target's position and plane, report actual room listeners, and end only
the target's Hide. Room object target origins remain refused before payment.
These room hosts do not make more spells room-legal, create room sound
history/discovery, or add other room sound producers. Knock remains the
source-pinned target-origin example and is unconverted. Other native sound
producers, item/attack/movement noise, and attenuation/elevation remain separate
work.

## Represented combat cover

`CoverRules` queries actual intervening cells on the existing flat hex ray.
Half Cover adds 2 to AC and Dexterity saves; Three-Quarters adds 5. Only the
strongest obstruction applies. Total Cover refuses direct attacks/spell targets
before Action, Reaction or slot payment, including transparent glass that still
allows sight. Opening/removing a room obstruction refreshes the grid. Area
recipients use their represented effect origin; a separate sphere can contribute
only where its own radius includes that cell. The live ordinary area-cast fixture
uses an off-ray caster and a selected sphere center to verify that partial-cover
save bonuses follow the selected effect origin, and that an obstacle at the origin
cell is not intervening cover.

Room walls use a bounded standing five-foot profile: heights below 3 feet grant
no cover, 3 feet Half, 4 feet Three-Quarters, and 5+ feet Total. Closed doors are
Total. An exact live room object can declare `"cover": "half"`,
`"three_quarters"` or `"total"`; objects at the same cell are all considered.
Removed, destroyed, contained or other-plane objects do not contribute. A live
intervening creature footprint on the effect's plane supplies Half Cover,
including a creature absent from the observer's render list. Pure light/illusion
markers do not. Standalone grid fixtures use the same `cover` tile property;
legacy sight-blocking tiles retain Total Cover. Invalid obstacle tokens fail
closed. No cover flag belongs on the target or ordinary action command.

A source can declare `"ignore_cover": ["half"]` or
`["half", "three_quarters"]`. Shared spell validation rejects other degrees and
duplicates. This applies to that source's attack/save comparison; weapon profiles
use the same declaration. The actual monster-attack turn host also passes its
represented origin/target through this shared weapon resolver: Half and
Three-Quarters Cover raise the target AC by +2/+5, a clear ray uses normal AC,
and Total Cover refuses before an attack receipt or damage. The real player
Guiding Bolt cast host also hits on the clear ray, misses behind Half/Three-
Quarters Cover at a captured deterministic attack roll, and refuses Total Cover
before slot/Action payment. Actual ordinary Dexterity-save spell casts also apply
Half/Three-Quarters Cover; the production
flow checks that each bonus flips a deterministic save outcome. Sacred Flame's
source-declared exception leaves its save uncovered despite a Half-Cover ray.
Existing `ignore_cover_on_save: true` removes only partial-cover save bonuses,
including the real Sacred Flame definition. Neither
form bypasses Total Cover. Shield recalculation retains cover. Save modifiers
enter the original roll before feature floors; resumed rolls retain their
captured modifier, and feature rerolls retain cover without replaying a spent
roll-token selection.

Source: [SRD 5.2.1, pp. 15 and 159](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf).
This remains a bounded flat-grid host: it does not calculate body silhouettes,
posture, diagonal edge apertures or three-dimensional coverage from elevations.
Full S-238 acceptance and catalog-wide obstacle/item conversion remain open;
this adds no saved Character field or checkpoint.

## Hide and creature discovery

Hide checks the live board before charging or rolling: a represented heavily
obscured space (darkness or fog) or intervening Three-Quarters/Total Cover, and no
enemy that can see the actor. Enemy special senses still matter. Existing Hide's
own Invisible benefit cannot satisfy the legality gate for a new Hide attempt.
Partial cover alone does not make an actor unseen.

A DC 15 Dexterity (Stealth) check uses the shared check owner, including
proficiency, Expertise, conditions and Exhaustion. Success supplies a
source-owned Hidden marker with Invisible benefits and an encounter-only
discovery DC equal to the check total. It survives turn-end. An attack roll,
a committed Verbal spell (including an interrupted cast), or successful creature
discovery removes Hide. A non-Verbal spell that makes no attack roll retains it.
Independent spell/condition Invisibility is preserved when Hide ends. Faerie
Fire and Starry Wisp still suppress its Invisible benefits.

The creature Search action makes one Wisdom (Perception) hearing check against
the captured Hide totals. It uses the same represented sound routes within 60 feet;
Deafened automatically fails. Success ends the target's Hide and records the
discovered location. It does not pretend to see through fog or independent
Invisibility. Legacy arbitrary Hidden markers without a captured check total
are not assigned an invented discovery DC.

Ordinary Hide, Dodge, Disengage and captured Hide totals clear when the encounter
ends or its scene is torn down. They introduce no durable save state or new save
checkpoint. Sound attenuation, elevation, room/overworld Hide, broader Search
and the remaining ordinary actions are still separate work.

## Room Search and object discovery

The room **Search** button chooses one represented room space within 60 feet.
The **Look / Listen / Medicine / Survival** selector chooses visual, hearing,
authored medical-clue or authored track Search before the space is selected; changing it cancels an unpaid
Search. The Search action is a Wisdom check to discern something that is not
obvious; its table assigns Medicine to a creature's ailment or cause of death
([SRD 5.2.1, Rules Glossary, p. 187](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf#page=187)).
Click Search again to cancel. Switching characters cancels the choice; switching
between Search and an unpaid teleport, water, anchor or creature-placement
choice leaves only the newly requested operation active. Search adds no new save
checkpoint. Look is a visual Wisdom (Perception) Search, following the concealed
object entry in [SRD 5.2.1, p. 187](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf#page=187).

A room object can declare:

```json
"discovery": {"dc": 15, "range_feet": 5}
```

Both fields are required: DC is an integral 1–1000 and vicinity is an integral
1–60 feet. The command's 60-foot selection limit and six-second exploration
Action are this room host's represented policy, not universal SRD search ranges
or investigation durations. Ordinary objects without `discovery` retain their
existing known status; old room/save records need no migration.

One live shared Perception check searches only the selected space. Success
discovers eligible objects whose authored vicinity includes the searcher, on
the same plane and outside containment. A failed roll or empty-space search
still advances the campaign clock by six seconds. Cancelled, stale, incapacitated,
out-of-map/out-of-range or unavailable-sight choices roll nothing and spend no
time. Dim light gives sight Perception Disadvantage; Darkvision treats dim light
as bright and darkness as dim. Actual Blindsight/borrowed familiar sight can
supply sight while the searcher's eyes are Blinded. The shared check rechecks
the actual spatial sight host instead of accepting a caller's success flag.
Ambient/carried light and active room fog/Darkness sources feed those queries.

Discovery appends the searcher's exact identity to that object's `discovered_by`
array, once. Another character must discover it independently. The object
becomes available through the existing object, spell, containment and remains
controls and their live identity guards; discovery itself grants no item or
spell effect. Taking a discovered cache uses the ordinary exact-copy transfer.
Unknown objects remain in physical/area queries and collision. Their marker,
name and direct-target offers are hidden from an observer who has not discovered
them, including encounter views. Untargeted area effects retain the real object.

Existing allowed checkpoints preserve those per-object observer receipts and
exact contents through both full-party and player-only recovery. Malformed,
duplicate or orphaned discovery records refuse before load. This does not
serialize a pending Search or add mid-room/mid-combat saving.

**Limits:** represented flat room spaces and declared concealed-object Search.
Passive discovery, sharing discoveries, overworld Search, Insight tasks, trap
triggers/disarming, arbitrary knowledge, full three-dimensional sensing and
catalog conversion remain separate. The
[S-237 registry boundary](../planning/vocabulary-slices.md#ordinary-action-continuation)
owns verification and the remaining broader world Help, Study and Influence work.


### Hearing Search

An object with an ongoing audible clue can declare:

```json
"discovery": {
  "dc": 15, "range_feet": 30, "sense": "hearing",
  "noise": {"volume": "whisper", "range_feet": 10}
}
```

Omitted `sense` means `sight`, preserving existing definitions and saves. Only
hearing discovery accepts `noise`; the existing sound validation applies. This
declaration represents ongoing sound from that live object, not a remembered
operation or an automatic discovery. Listen Search makes one real Wisdom
(Perception) check for the selected space. Both the discovery vicinity and
sound range must include the searcher. Removed/destroyed/contained objects and
other planes cannot reveal a clue. Walls/glass/closed doors block a sound route
unless an open route goes around them; fog, darkness and Blinded do not. Deafened automatically fails the attempted
check and still pays six seconds. Sight Search cannot satisfy a hearing task,
and Listen cannot reveal a visual-only clue. Invalid declarations refuse before
rolling or time. Successful hearing discovery uses the same exact per-observer
receipts, target/interaction offers and allowed-checkpoint recovery as Look.

### Medicine Search for authored remains clues

Medicine Search reuses the room button, selected-space click and shared
check/Help owner. A remains source can declare one bounded clue:

```json
"medical_search": {
  "dc": 15, "range_feet": 5, "kind": "cause_of_death",
  "recent_until_seconds": 3600,
  "information": "A narrow puncture wound caused the death."
}
```

This bounded route supports the `cause_of_death` clue kind and requires its
recent-source deadline. Search checks the exact selected room space, source
identity, authored vicinity, remains state, containment and plane. The room
host requires sight of that space. It makes a real Wisdom (Medicine) check and
spends six seconds on a valid attempt. Failure reveals no authored text.
Success records the exact observer on that source and reveals only its declared
information in the result and that observer's Knowledge panel. A changed or
removed source captured when the chooser opened refuses before payment. Existing
allowed entrance checkpoints retain the clue and observer receipt; reload does
not roll or charge again. This route reveals authored information; it does not
heal or stabilize a target.

### Survival Search for authored local tracks

The room Search selector offers **Survival** for one authored track clue on an
exact represented room source. SRD 5.2.1's Search action is a Wisdom check to
discern something not obvious, and its Search table assigns Survival to finding
tracks ([Rules Glossary, p. 187](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf#page=187); Survival skill, pp. 182–183).

A source may declare:

```json
"tracks_search": {
  "dc": 15, "range_feet": 5, "kind": "tracks",
  "information": "Fresh bootprints head toward the eastern passage."
}
```

Search uses an actual Wisdom (Survival) check through `EventResolver`. The clue
applies only when searching the exact source's room space and within its authored
vicinity. The source must remain present, alive, on the observer's plane and
outside containment; the observer must see the selected space. A valid attempt
spends six campaign seconds even on failure or at the wrong space. Only success
adds the exact observer ID to `tracks_discovered_by` and reveals the declared text
in that character's room Knowledge panel. Matching physical Survival Help uses
the shared check owner. Failed, cancelled and stale choices disclose no clue; a
changed or removed source refuses before payment. Existing allowed room
checkpoints preserve the observer receipt without a new save point or reroll.

This is authored clue disclosure only: movement does not generate tracks,
identify or locate quarry, create a path, or move the party. The six-second Action
and clue vicinity are represented room-host policy, not universal SRD ranges or
durations. S-229, S-237 and S-238 remain in progress.
