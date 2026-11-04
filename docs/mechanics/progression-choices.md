# Progression feature choices

## Ability generation (S-242)

Creation offers `point_buy`, `standard_array` (15, 14, 13, 12, 10, 8), and
`random_4d6` (six seeded rolls of 4d6, dropping the lowest die). Campaign
`ability_generation_methods` can restrict that list; omitted means all three.
The player assigns each generated result to one distinct ability. Back, Random
and the next player keep controls consistent; duplicate assignments and a
prohibited method block confirmation.

`creation_choices.ability_generation` records `method`, `seed`, `results` and
`assigned_abilities`. Standard Array uses seed 0; point buy uses seed 0 with
empty result/assignment arrays. Save preflight verifies the generated values,
assignment and campaign restriction on both party and player records. Restore
retains the receipt and final permanent scores without rerolling or replaying
creation bonuses. Existing saves without a generation receipt remain valid.

## Class proficiency choices at creation (Crown G2)

A class opts into the ordinary creation picker with
`"creation_proficiency_choices": true` (Bard, Cleric, Druid, Rogue, Monk, and
since PR C Barbarian, Fighter, Paladin, Ranger, Sorcerer, Warlock, Wizard).
`skill_choices` and `tool_choices` (`{"pick": N, "from": [tool ids]}`) size the
selectors; `"tool_proficiency_grants": [tool ids]` are fixed. Every id must be
an item of type `tool`; a choice may not repeat a fixed grant. Druid grants
`herbalism_kit`, Rogue `thieves_tools`, and Monk picks one Artisan's Tool or
Musical Instrument.

`tool_proficiency_sources` maps each tool id to its source ids (`class:<id>`,
`class_choice:<id>`, `background:<id>`, `feat:<id>`, `species:<id>`).
`ClassProgression.grant_tool_proficiency` grants once per source and lists the
tool once however many sources own it (Rogue plus Criminal Thieves' Tools).
Owning a tool item is not proficiency. Save preflight refuses malformed,
duplicated or stale class sources and chosen tools without their source;
restore replays nothing. Saves without the key, or tools without a source,
remain valid legacy grants: restore records a pre-G2 save's tools in
`legacy_tool_proficiencies`, which is saved and exempts those retained creation
choices from the chosen-source rule on every later save. Limits: full equipment packs are not
offered, and classes without the flag keep their earlier creation.

Class tool items (SRD 5.2.1 Starting Equipment, `srd.txt` 2500-2504 Druid,
2972-2978 Monk): option A goes through the ordinary `starting_equipment` path.
Druid lists `herbalism_kit` with `starting_gold` 9; Monk declares
`starting_equipment_includes_tool_choice: true`, and the one generic
`ClassProgression.creation_starting_equipment` adds one copy of each already
validated `tools` choice (any class may use the declaration; no class or item
ID branch). Both declare `starting_gold_alternative` 50 (option B), which gives
no items. The item copy is inventory only; proficiency still comes from
`tool_proficiency_sources`. Items are granted once at Confirm (`initialize`
refuses a character whose class is already set) and are never re-added on
restore, so older saves keep their inventory without retroactive kits.
Option A also lists one `explorers_pack` for Druid and Monk through the same
`starting_equipment` path; it is one pack copy whose existing `pack_contents`
expand through `Inventory.expand_pack_instance` (Backpack, Bedroll, 2 Oil, 10
Rations, Rope, Tinderbox, 10 Torches, Waterskin; `srd.txt` 5839-5842). Druid
option A also owns `druidic_focus_quarterstaff` (a Quarterstaff weapon that
declares `"spellcasting_focus_kind": "druidic"`) listed before `sickle`, so the
existing placement holds the focus as first weapon beside the Shield and
carries the Sickle. A class declares `"spellcasting_focus_kinds": [...]` (Druid
and Ranger: `["druidic"]`); `Inventory.held_spellcasting_focus` accepts only a
matching item equipped in the Weapon or Off-hand slot, and that hand covers
non-costly, non-consumed Material components and their Somatic gestures (SRD
Material: the same hand may perform Somatic). The current project policy also
allows Somatic-only spells with this held focus; that is an additional house
ruling rather than a consequence of the SRD Material clause. Priced/consumed materials keep
their exact-copy and free-hand rules; a stowed focus or plain weapon does not
count. Known limit: the focus isn't yet recognized as a Quarterstaff for
Shillelagh or Topple. See
[the evidence](../reviews/druidic-focus-sickle.md).

PR C class skills (SRD 5.2.1 Core Traits; `srd.txt` lines): Barbarian 2 of 6
(1735-1737), Fighter 2 of 9 (2844-2848), Paladin 2 of 6 (3177-3181), Ranger 3
of 8 (3417-3420), Sorcerer 2 of 6 (3818-3822), Warlock 2 of 7 (4187-4190),
Wizard 2 of 7 (4604-4606). A pick may not repeat a species skill; Skilled
refuses skills the class picks already granted. Barbarian keeps its own A/B
selector (`starting_gold_alternative: 75`, SRD 1741-1745). The Fighter's two
picks *are* its training skills: the picker preselects Athletics and Perception
(minus species skills), Confirm passes the picks to `FighterRules.choose_skills`,
a pre-combat swap updates `creation_choices.skills`, refuses species-held and
(G4) Skilled-owned skills, and save preflight refuses picks that disagree with
training. Saves made before PR C (creation choices holding only the
generation receipt) stay valid with no class skills invented.

### Feat proficiency choices (Skilled, Crown G4)

A feat may declare `"proficiency_choices": {"pick": N, "skills": [...],
"tools": [...]}` (pick 1-20; skills from the loader's skill list; tools must be
items of type `tool`; entries distinct; no other keys). Any combination of
exactly `pick` distinct entries is legal. Core `data/core/feats/skilled.json`
is SRD 5.2.1 p.87 Skilled: an Origin feat, `repeatable`, `features: []`,
pick 3 from all 18 skills and the 37 SRD Artisan's Tools, Other Tools and
Musical Instruments, including Dice, Dragonchess, Playing Cards and
Three-Dragon Ante Gaming Sets. Gaming Set weight is unspecified in the SRD;
their item records omit `weight` rather than treating them as weightless.
These records support proficiency choices; their described Utilize tasks
are not implemented by this acquisition work.

Each acquisition is its own instance: `origin` for the creation Origin feat, or
the Ability Score Improvement feature id it replaced. `FeatRules.choose_origin`
and `choose_level_feat` take the picks (`{"skills": [], "tools": []}`) and
refuse, all-or-nothing and before anything is spent, missing/short/oversized,
duplicate, off-list or already-held picks (from any source). Skills are added
once; tools go through `grant_tool_proficiency` with source
`feat:<feat_id>@<instance>`. `Character.feat_proficiency_choices` records
`{instance: {"feat_id", "skills", "tools"}}`; restore replays nothing. Removing
another source keeps a skill a feat instance owns. Save preflight refuses a
chosen proficiency-choice feat without its record, a record for an instance that
does not hold that feat, wrong counts or off-list picks, a skill or tool picked
by two instances, a pick that is not held or a tool without its instance source,
and any `feat:` tool source no record owns. Saves from before G4 (no key) load
as `{}`. Creation preselects no Origin feat (there is no background step yet)
and shows `OriginFeatProficiency1..N`; the level-up sheet shows
`LevelFeatProficiency1..N` beside `LevelFeatPicker`.

## Feature choices

`ClassProgression` owns acquisition and replacement of passive `feature_choice`
options. `ClassTraining` provides the out-of-combat selectors and revalidates the
current character when a button is pressed. This is the bounded S-045/S-046
host; rest modes and native multiclass acquisition remain separate. Batch L adds bounded
[item/cast/progression AC and speed carriers](source-benefit-carriers.md), with independent acceptance pending.

## Definition

### Feat eligibility and repeats (S-233)

Feat `prerequisite` supports the existing `level` and `abilities_any` rules,
plus `class_levels` (a map from class ID to minimum class level) and
`features_any` (a list of named feature IDs, where owning any one qualifies).
Save preflight applies the same class and feature checks. A repeatable feat may
declare `repeatable_parameter_options`, a list of distinct choices; the saved
choice retains the selected parameter so taking another parameter is distinct
while taking the same parameter twice is refused.
Both the Origin picker and the level-up picker offer those parameters. The
stored Origin value is `feat_id|parameter`; improvement entries use
`feat:feat_id|parameter`. Plain existing feat IDs remain valid. Named-feature
save checks rebuild actual class/subclass/species/feat/equipment ownership;
an arbitrary `features` entry in a save cannot grant eligibility. Repeatable
feats still cannot declare mode/upgrade features with colliding feature IDs;
selection support does not supply Magic Initiate's spell mechanics.

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
