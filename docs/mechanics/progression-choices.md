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

Picked starting items (CXM-03): a class declares
`"starting_equipment_choices": [{"key": K, "label": L, "from": [item ids]}]`.
Each slot stores its pick in `creation_choices[K]` (default: the first `from`
id), and option A adds that one item. The GP option needs no pick. A pick outside
`from` is refused with "Choose a starting L." The loader refuses a slot whose key
reuses `skills`, `tools`, `equipment` or `ability_generation`. Bard uses slot
`instrument` (any Musical Instrument, independent of its three instrument
proficiencies). The creation screen shows one generic `<Class>Starting<Key>`
picker per slot and one `<Class>StartingEquipment` selector for any class with
`starting_gold_alternative`; no class has its own selector or ID branch.
SRD kits (option A, then the GP option): Paladin (Chain Mail, Shield, Longsword,
6 Javelins, Holy Symbol, Priest's Pack, 9 GP; or 150 GP), Fighter A (Chain
Mail, Greatsword, Flail, 8 Javelins, Dungeoneer's Pack, 4 GP; or C, 155 GP),
Sorcerer (Spear, 2 Daggers, Arcane Crystal, Dungeoneer's Pack, 28 GP; or 50 GP),
Warlock (Leather Armor, Sickle, 2 Daggers, Arcane Orb, Book of occult lore,
Scholar's Pack, 15 GP; or 100 GP) and Wizard A (Arcane Focus Quarterstaff, 2
Daggers, Robe, Spellbook, Scholar's Pack, 5 GP). The staff is listed first so
it is held, like Druid's focus; it declares `"spellcasting_focus_kind":
"arcane"`, which Sorcerer, Warlock and Wizard accept. Ranger (Studded Leather,
Scimitar, Shortsword, Longbow, 20 Arrows, Quiver, Sprig of Mistletoe,
Explorer's Pack, 7 GP; or 150 GP), Rogue (Leather Armor, 2 Daggers, Shortsword,
Shortbow, 20 Arrows, Quiver, Thieves' Tools, Burglar's Pack, 8 GP; or 100 GP)
and Fighter B (Studded Leather, Scimitar, Shortsword, Longbow, 20 Arrows,
Quiver, Dungeoneer's Pack, 11 GP) complete the class kits.

Extra kits: `"starting_equipment_alternatives": [{"id", "label", "gold",
"items"}]` adds options between option A (`equipment`) and `gold`; the stored
choice is the option id (Fighter B is `equipment_b`), and
`ClassProgression.equipment_options`/`creation_starting_gold` serve creation,
validation and the screen. Picked-item slots apply to option A only.

Starting ammunition: Arrows are catalog `ammunition` pieces (`ammunition_kind:
arrow`) and the Quiver has a 20-piece `ammunition` compartment. After a kit is
granted, `Inventory.add_starting_equipment` stows each item into a carried
compartment that names its item type, so 20 Arrows use one backpack slot and
the kit's pack can still expand; untyped compartments are left alone. Catalog
bows still don't declare `ammunition_kind`, so Arrows aren't spent yet (see
[ammunition](ammunition.md)). Wizard option B is 55 GP plus the Spellbook
(`spellbook_and_gold`): house ruling that the book belongs to the class feature,
which load restore already assumes. The creation screen groups repeated items
("Arrows ×20"); the granted copies are unchanged.
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
refuses skills the class picks already granted. Barbarian uses the generic A/B
selector (`starting_gold` 15, `starting_gold_alternative` 75, SRD 1741-1745). The Fighter's two
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
as `{}`. A character made without a background (a legacy path the creation
screen no longer reaches) may pick any Origin feat through `OriginFeatPicker`
and `OriginFeatProficiency1..N`; with a background the feat is fixed (below).
The level-up sheet shows `LevelFeatProficiency1..N` beside `LevelFeatPicker`.

## Backgrounds (CXM-04 / S-231)

`data/core/backgrounds/` is a content type (SRD 5.2.1 p.83). A background
declares `ability_options` (three abilities), `origin_feat` (a loaded Origin
feat id, `feat_id|parameter` for a parameterised one), two `skills`, the class
tool keys `tool_proficiency_grants` / `tool_choices` /
`starting_equipment_includes_tool_choice`, `starting_equipment`,
`starting_gold` and `starting_gold_alternative`. The loader refuses a bad
shape; a missing feat, tool or item, an illegal feat parameter, or an Origin
feat with `proficiency_choices` (not supported on backgrounds yet) is a load
error. Core holds Acolyte, Criminal, Sage and Soldier; no code names them.

The creation screen has a Background step after Class. One `BackgroundAbilities`
picker lists the seven legal spreads (each +2/+1 pair, or +1 to all three);
`BackgroundTool1..N` appear for a tool choice (Soldier's Gaming Set); and
`BackgroundEquipment` chooses the kit or the GP. Next stays disabled until the
picks are legal. The Equipment step shows the fixed Origin feat instead of the
feat picker, disables class skills the background gives, and clears a class
pick the background takes over. Random picks a legal background every time.

`Character.initialize(..., background_id, background_choices)` validates the
whole background before changing anything (`BackgroundRules.creation_error`):
the spread, no score above 20, the tool pick, the option, no class skill pick
that repeats a background skill, and that the kit fits after the class kit.
It then applies the increases before HP, the two skills, the tool with source
`background:<id>`, the kit (Soldier's kit includes the chosen Gaming Set) or
the GP on top of the class GP, and the Origin feat. `background_id` and
`background_choices` (`{"abilities", "tools", "equipment"}`) are saved. Restore
replays nothing. Save preflight refuses an unknown background, illegal or extra
picks, a missing Origin feat or skill, and a missing or stale `background:`
tool source, on both party and player records.

Species boundary: a character with a background takes no species
`ability_bonuses`; one without keeps them, so the two never stack. Old saves
and directly built characters have no background and are unchanged. Species
data was not rewritten.

Alert declares `"initiative": {"proficiency": true, "willing_exchange": true}`
on the feat. An owner adds proficiency to Initiative; after the initial rolls
and before the first turn, the owner can choose an ally and that ally must
confirm. The exact initiative totals exchange, retaining each creature's own
Dexterity tie-break. The initial choice is transient, consumed once, and is
rechecked after consent; incapacitated or removed participants cannot exchange.
Steeds sharing an owner's count follow the exchanged count. Late or grouped
arrivals do not reopen the initial window.

Savage Attacker declares `"weapon_damage_roll_choice": {"rolls": 2,
"uses_per": "turn"}`. On a weapon hit its owner can decline, or roll the
weapon's complete damage dice twice and choose either result. Critical weapon
dice belong to each complete roll; separate damage riders are not rerolled.
The use refreshes on each creature's turn, including an opportunity attack.
The room-object strike host also offers the choice.

Limits: Magic Initiate remains an acquisition record with `"effects_pending":
true`; its rules are pending CXM-60, and `FeatRules.options` does not offer an
effects-pending feat as a pick. Magic Initiate records its fixed
list (`magic_initiate|cleric`) but no spells or casting ability. Book topics
and the Holy Symbol form are not represented. A Fighter cannot swap a training
skill onto a background skill.

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
