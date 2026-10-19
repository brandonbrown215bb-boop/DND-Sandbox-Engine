# Progression feature choices

`ClassProgression` owns acquisition and replacement of passive `feature_choice`
options. `ClassTraining` provides the out-of-combat selectors and revalidates the
current character when a button is pressed. This is the bounded S-045/S-046
host; rest modes and native multiclass acquisition remain separate. Batch L adds bounded
[item/cast/progression AC and speed carriers](source-benefit-carriers.md), with independent acceptance pending.

## Definition

A feature declares at least two uniquely named/identified `options`, each with
supported effect records. `count` (or `pick`) defaults to one. Supplied counts
must be integral, between one and the option count; both aliases must agree
when supplied. Integral JSON numbers such as `2.0` are valid. Fractional values
and invalid aliases refuse loading. `minimum_level` is integral from one to20.

Each option can declare:

- `minimum_level`: minimum total character level.
- `class_id`: required represented class. Without explicit allocation this is
  the primary class; with `class_levels` the required class must have positive
  represented levels. This grants no native secondary-class features.
- `when`: shared nested `all`/`any`/`not` predicates using `actor.id` or
  `actor.level`, with the shared typed comparisons. Target, action, cast, result
  and other unavailable facts refuse loading. An unavailable actor identity
  remains unknown under negation and never supplies eligibility.
- `requires_choices`: option IDs that must be selected, including other picks
  in the same acquisition. The UI refreshes from pending picks and clears a
  dependent selection when its prerequisite is removed.
- `repeatable`: allows repeated occurrences of that option. Otherwise duplicates
  require feature-level `allow_duplicates: true`.

Acquisition requires the complete declared count and all filters before storing
choices or applying grants. Invalid/stale requests do not partially acquire.
Repeated permitted selections contribute their effects once per occurrence.

## Replacement and dependent selections

Replacement is **opt-in**: `allow_replacement: true` on the feature-choice
effect. Missing or false permission supplies no Replace controls and refuses
runtime replacement. Existing catalog choices therefore gain no new swap rights.

The runtime validates a proposed copy of all selections before changing the
character. Explicit prerequisites must remain satisfied, including another
remaining occurrence of a repeated prerequisite. Existing trained spells must
remain legal under the resulting capacity and cantrip/leveled spell lists.
Removing an expansion for cantrips cannot borrow an independent expansion
marked `level_1_plus_only`. Unearned primary-class features cannot supply grants.
An unsafe replacement refuses; it does not silently discard or retain invalid
training. A capacity increase marks spell training pending while retaining the
existing valid choices, so the character remains saveable.

Successful replacement removes the old option's proficiency grants only when
no represented supported source retains them. These sources include primary
class/race data, permanent feature grants, creation/skill choices, Fighter
training and other active feature options. Extra Attack and selected derived
effects are recalculated from retained sources. This does not implement general
item/cast source carriers or a new grant ledger.

## Checkpoints

Existing Character choice arrays remain the durable state. Full-save preflight
checks both player and party records before replacing the live session.
Count/duplicate/option, level/class/fact and prerequisite checks agree with
acquisition. Saved spell checks count every selected occurrence, distinguish
cantrip-only availability from leveled expansion, and scan earned primary-class
features through the represented primary level. Current spell capacity and slot
tables retain their existing total-character-level behavior; full native
multiclass spellcasting remains unimplemented.

Reconstruction restores choices and current derived grants without replaying
permanent acquisition or resource recovery. Existing 2024 namespace and allowed
checkpoint boundaries remain. Picker controls and pending local selections are
transient. See the [Batch K repair evidence](../../.artifacts/planning/vocabulary-reports/batch-K-repairs.md).


## Permanent acquisition extension (018; independent review pending)

Opt-in classes now use [permanent progression](permanent-progression.md) for
starting/multiclass grants and class/character-level permanent deltas. Ordered
receipts retain independent permanent proficiency grants when a feature option
is replaced. The existing native class/slot limitations above remain for other
classes; this bounded host accepts primary passive proficiency choices and
secondary classes without native features. It does not add multiclass casting.
