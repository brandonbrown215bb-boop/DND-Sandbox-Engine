# Spell inventory and rules-vocabulary audit (Batch 088)

**Status: INVENTORY AND CLAUSE DECOMPOSITION COMPLETE (362 of 362 unique loaded spell IDs, 100%): 339 decomposed against SRD 5.2.1, 23 out-of-milestone IDs identified only, 0 unreviewed. This is an audit, not certification: no spell is certified, no data was corrected, and spell_status.json was not regenerated. See Final reconciliation.**

## Evidence boundary

| Item | Value |
|---|---|
| Commit exported | `ede0a3cdfa66f21b0b3415f498c2e186e56a0db4` (origin/main, merge of #60) |
| Registry hash | `DataLoader.get_registry_hash()` returns the full JSON snapshot string, not a digest. SHA-256 of that string: `70a83cc74e530743e90f8fadc992bd0651f56b51cb84b06cd73fcaf22187845e` |
| Runner | **Not the supported Windows runner.** `scripts/invoke_godot_case.ps1` (docs/operations/development.md) can't run on the Linux box. I used `/workspace/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . res://scenes/spell_inventory_export.tscn` after two `--import` passes. Exit 0, `SPELL INVENTORY EXPORTED: 362 unique spells`, with no SCRIPT, Parse or Compile errors. Output is in `.artifacts/spell-status/runtime.json` (ignored), with logs beside it. A Windows export should confirm that the hash matches. |
| SRD source | SRD 5.2.1 PDF. 088-1 used reading-order `pdftotext`. 088-2 uses a column-split extract (`-x 0/297 -W 297 -H 783` per page, pp.100–180). |
| Per-spell table | [spell-inventory.csv](spell-inventory.csv): one row per loaded ID, with class memberships, SRD header classes, winning source file, shared or native execution, availability or refusal reason, milestone flag and audit batch. |

## Reconciled inventory totals (fresh export, not historical)

| Measure | Count |
|---|---:|
| Unique loaded spell IDs | 362 |
| Matching SRD 5.2.1 spells (milestone) | 339 |
| Out-of-milestone (not in SRD 5.2.1) | 23 |
| SRD 5.2.1 spells missing from the loaded inventory | 0 (339 SRD `Casting Time:` blocks, all matched to a loaded ID) |
| Cast-available / refused | 134 / 228 |
| Available milestone / available out-of-milestone | 132 / 2 (`blade_ward`, `cloud_of_daggers`) |
| Shared execution / native | 18 / 344 |
| Class memberships (8 casting classes) | 899 (bard 136, cleric 110, druid 125, paladin 46, ranger 49, sorcerer 139, warlock 75, wizard 219) |
| Loaded IDs with no class membership | 10 (all out-of-milestone) |
| IDs defined in more than one data file (winner = loaded `_source`) | 53 |

Winning sources: imported_spells.json 182, srd_additional_spells.json 155, core_spells.json 17, conversion_batch_002.json 4, conversion_batch_001.json 3, wizard_spellbook_spells.json 1.

The historical register said 362 / 898 memberships / 133 enabled. Today's export gives 899 memberships and 134 available. I didn't regenerate `spell_status.json` because its generator rewrites historical boundaries; see the open question below.

Out-of-milestone IDs: armor_of_agathys, arms_of_hadar, aura_of_vitality, beast_sense, blade_ward, blinding_smite, branding_smite, cloud_of_daggers, compelled_duel, conjure_barrage, cordon_of_arrows, crown_of_madness, crusaders_mantle, elemental_weapon, feign_death, friends, hail_of_thorns, hunger_of_hadar, lightning_arrow, thorn_whip, thunderous_smite, witch_bolt, wrathful_smite.

Renamed SRD names (ID → SRD 5.2.1 name): melfs_acid_arrow → Acid Arrow, nystuls_magic_aura → Arcanist's Magic Aura, leomunds_tiny_hut → Tiny Hut, tensers_floating_disk → Floating Disk, tashas_hideous_laughter → Hideous Laughter, resilient_sphere → Resilient Sphere (loaded as "Otiluke's Resilient Sphere").

### Class-membership discrepancies (superseded by the cited defect table in batch 088-2)

In 088-1, 21 headers didn't parse. 088-2 read all 339 from column-split PDF text and found the same 7 discrepancies.

| ID | SRD header classes | Loaded memberships |
|---|---|---|
| fire_bolt | Sorcerer, Wizard | + warlock |
| magic_missile | Sorcerer, Wizard | + warlock |
| guidance | Cleric, Druid | + bard |
| misty_step | Sorcerer, Warlock, Wizard | + ranger |
| resilient_sphere | Wizard | + cleric, paladin |
| mind_spike | Sorcerer, Warlock, Wizard | − sorcerer |
| phantasmal_force | Bard, Sorcerer, Wizard | − sorcerer, wizard |

Extra memberships may come from subclass or feature lists folded into class lists. Check `get_spell_list_options` before correcting anything; an ADR-0023 judgment may apply.

## Batch 088-1: clause decomposition (4 spells reviewed)

Classification key: **E** existing supported behavior (content only), **P** planned under an existing slice, **H** missing host or control, or a continuation of an accepted bounded slice, **G** genuine unaccounted gap, **J** source gap, deferred or ADR-0023 judgment.

| Spell (SRD 5.2.1) | Clause | Reusable behavior | Class | Owner / limit |
|---|---|---|---|---|
| Acid Splash | Action; 60 ft; V, S; Instantaneous | cast cost/action, range in hexes | E | shared execution; register limit "full clause audit open" |
| Acid Splash | point within range, 5-ft-radius Sphere, each creature | point-targeted area selection | E | `area_selection` sphere r=1 hex (hex approximates the sphere) |
| Acid Splash | Dex save or 1d6 Acid (no half on success) | per-target save, no-damage on success | E | shared save resolution |
| Acid Splash | Cantrip Upgrade 5/11/17 | character-level dice table | E | S-037 (Verified VS-44); data `scaling` 2d6/3d6/4d6 |
| Acid Splash | point needs a clear path (general targeting rule) | observer/obstruction check | P | S-190 (Planned) |
| Ray of Frost | ranged spell attack, creature within 60 ft | spell attack vs creature | E | range corrected to 12 hexes (register) |
| Ray of Frost | on hit Speed −10 ft until start of caster's next turn | source-timed speed reduction | E | `reduce_speed` effect; recorded slice |
| Ray of Frost | upgrade 1d8 → 4d8 | level dice table | E | S-037 |
| Ray of Frost | visibility of target | obstruction/sight | P | S-190/S-191 |
| Chill Touch | melee spell attack, target within reach (Touch) | touch spell attack | E | recorded slice |
| Chill Touch | can't regain HP until end of caster's next turn | source-timed healing prevention | E | `prevent_healing` effect |
| Chill Touch | upgrade 1d10 → 4d10 | level dice table | E | S-037 |
| Poison Spray | **SRD 5.2.1: ranged spell attack, 1d12 Poison** (not a Con save) | spell attack | E | winning record: `attack_type: ranged_spell`, no save, 1d12, which matches the SRD |
| Poison Spray | 30 ft; upgrade to 4d12 | range, level dice | E | S-037 |

Batch result: 0 genuine gaps (G). Line of sight is already planned (S-190/S-191). No new slice is needed.

## Genuine vocabulary gaps

Batch 088-1 found none. See PROPOSED-spells-1 to 3 under batch 088-2.

## Batch 088-2: immediate attacks, saves and healing (48 spells reviewed)

Scope: the rest of the register's `direct_resolution` family (52 IDs, 4 of them done in 088-1). Text comes from a column-split extract of the SRD 5.2.1 PDF (`pdftotext -x/-W` per half-page, pp.100–180). The "DATA" notes compare against the winning loaded record in the fresh export. Two IDs aren't in SRD 5.2.1 (arms_of_hadar, conjure_barrage). I recorded them as out-of-milestone and didn't decompose them, because a later supplement isn't milestone authority.

Shared clauses that every spell below uses, so they aren't repeated per row:
- Action/Bonus Action/Reaction cost, range in 5-ft hexes, V/S components, slot payment: **E** (S-134/S-135/S-136 verified).
- Damage, half on success, per-target saves: **E** (S-098 verified).
- "Using a Higher-Level Spell Slot": +dice per slot: **E** (data `scaling` and slot-scaled formulas).
- Cantrip Upgrade: **E** (S-037).
- "A creature you can see": **P** (S-190/S-191; currently only Invisible is checked).

| Spell | Avail | Clause-level decomposition → classification (owner) | Data defects vs SRD 5.2.1 |
|---|---|---|---|
| blight | yes | Con save 8d8 necrotic, half: E. Plant creature auto-fails: E (S-092 explicit failure plus S-001 type fact). Nonmagical plant object withers, no save: H (object target host; register limit "plant objects absent"). | — |
| burning_hands | yes | 15-ft Cone from self: E. Flammable unworn objects start burning: H (Meteor Swarm's saved `burning` flag on authored room objects is the existing piece; it isn't reached from Cone hosts). | — |
| chain_lightning | yes | First target seen ≤150 ft, up to 3 more ≤30 ft of it, creature or object, one bolt each: E (register limit). +1 bolt per slot: E. | — |
| chromatic_orb | **no** | Choose 1 of 6 damage types: E (S-127 Planned covers choice routes; S-036 source choice). Ranged spell attack 3d8: E. **Leap on matching d8 faces to a new target within 30 ft, new attack and damage, leaps ≤ slot level, each creature once**: G → PROPOSED-spells-2. 50 GP diamond (not consumed): E (S-136). | `target: area` should be a single target |
| circle_of_death | yes | 60-ft Sphere at a point ≤150 ft, Con save: E. 500 GP black-pearl powder, not consumed: E. | — |
| cone_of_cold | yes | 60-ft Cone: E. Creature killed becomes a frozen statue until it thaws: J (remains presentation; S-119 remains policy could carry it; "thaws" has no source duration). | — |
| cure_wounds | yes | Touch, 2d8 + modifier, +2d8 per slot: E (shared). | — |
| disintegrate | yes | Ray at creature, nonmagical object or force creation: H (objects and Wall of Force targets aren't in the host). Dex save 10d6+40 force: E. At 0 HP, target and nonmagical gear become dust, revival only by True Resurrection/Wish: E (S-119; S-175 Planned for revival eligibility). Large-or-smaller object or force creation destroyed automatically; Huge+ loses a 10-ft Cube portion: H/J (no object-portion model; S-213 Planned retains sections). | — |
| divine_word | **no** | Chosen creatures in range, Cha save: E. HP-band table (≤20 dies; 21–30 Blinded+Deafened+Stunned 1 h; 31–40 Blinded+Deafened 10 min; 41–50 Deafened 1 min): E (S-016 breakpoint lookup, S-043 HP gate, S-119 death). Celestial/Elemental/Fey/Fiend sent to home plane, can't return for 24 h: P (S-177/S-178). | no `effects` authored |
| eldritch_blast | yes | Creature **or object** target: H (objects not reached). Beams 2/3/4, separate attacks: E. | — |
| finger_of_death | **no** | Con save 7d8+30, half: E. Humanoid killed rises next turn as a Zombie under verbal orders: H (S-120 successor actor + S-154/S-156 created actor/commands, verified for Animate Dead; not hosted for this death cause). | — |
| fire_bolt | yes | Creature or object: H. Flammable object ignition: H (same burning piece as Burning Hands). | — |
| fire_storm | **no** | Up to ten 10-ft Cubes, each contiguous with another, arranged by caster: H (Meteor Swarm's verified multi-center selection with overlap dedupe; needs cube members and a contiguity check). Dex 7d10 fire: E. Ignition: H. | `area_radius` missing; no area effect |
| fireball | yes | 20-ft Sphere at a point ≤150 ft: E. Ignition: H. | — |
| flame_strike | **no** | 10-ft-radius × 40-ft Cylinder: E (cylinder flattened, as Moonbeam). **5d6 Fire + 5d6 Radiant** packets: E (S-111/two-packet settlement in Meteor Swarm). | **damage `10d6` fire should be 5d6 fire + 5d6 radiant** |
| freezing_sphere | **no** | 60-ft Sphere, Con 10d6 cold: E. Water struck freezes 6 in deep over 30-ft square for 1 min; swimmers Restrained; action Athletics vs DC to escape: G → PROPOSED-spells-3. Withheld globe item, thrown 40 ft or slung, explodes after 1 min: P (S-150/S-151 store/release an exact spell; S-087 timer). | — |
| guiding_bolt | yes | Next attack roll against target before end of caster's next turn has Advantage: E (`grant_condition`; S-076 Planned generalises "next selected attack"). | — |
| harm | **no** | Con save 14d6 necrotic; failed save reduces HP max by necrotic taken, not below 1: H (S-130 verified for Characters only + S-017 earlier-step damage sum; monster targets not hosted). | — |
| heal | yes | 70 HP, +10 per slot; ends Blinded/Deafened/Poisoned: E. | — |
| healing_word | yes | Bonus Action, 2d4 + mod, seen creature: E. | — |
| hellish_rebuke | **no** | Reaction trigger "taking damage from a creature you can see within 60 ft": H (documented: S-041/S-042/S-134/S-135; host emits only monster weapon attacks). | — |
| ice_knife | yes | Attack 1d10 piercing, then hit-or-miss burst: target + creatures within 5 ft, Dex 2d6 cold, no half: E. | — |
| ice_storm | **no** | 20-ft × 40-ft Cylinder, Dex: E. 2d10 Bludgeoning + 4d6 Cold packets: E. Ground becomes Difficult Terrain until end of caster's next turn: H (SpellZoneTerrain verified; needs instantaneous-spell child zone with timed expiry: S-087 child timer). | missing 4d6 cold packet |
| inflict_wounds | yes | Touch, Con 2d10 necrotic, half: E. | — |
| lightning_bolt | **no** | 100 ft × 5 ft Line from self in chosen direction: E (`line` shape exists for Wall of Fire). | `target: single` should be a line area |
| magic_missile | yes | Darts assigned to seen creatures, simultaneous, 1d4+1 each: E (register). | — |
| mass_cure_wounds | yes | Point ≤60 ft, up to six in 30-ft Sphere: E. | — |
| mass_heal | **no** | Up to 700 HP divided among any number of seen creatures; healed creatures lose Blinded/Deafened/Poisoned: E (S-101 one integer budget across recipients, verified for HP). | `heal 700` modelled as a single value |
| mass_healing_word | yes | Up to six seen, Bonus Action: E. | — |
| melfs_acid_arrow (Acid Arrow) | yes | Hit 4d4 + 2d4 at end of target's next turn; miss half initial only: E (native `delayed_damage`, verified in harness). | name differs from SRD ("Acid Arrow") |
| meteor_swarm | yes (gated per limit) | Four seen points ≤1 mile, 40-ft Spheres, affected once, 20d6 fire + 20d6 bludgeoning, unattended objects damaged and ignite: E/H (register: dropped gear not enumerated). | — |
| mind_spike | **no** | Wis 3d8 psychic, half; Concentration 1 h: E. On a failed save the caster knows the target's location on the same plane, the target can't hide from the caster, and gains no Invisible benefit against them: P (S-194 location-only disclosure, S-191 observer-relative concealment). | class list (see defects) |
| power_word_heal | yes | All HP; ends Charmed/Frightened/Paralyzed/Poisoned/Stunned; Prone may stand with Reaction: E. | — |
| power_word_kill | yes | ≤100 HP dies, else 12d12 psychic: E (shared settle_death). | — |
| prayer_of_healing | **no** | 10-minute cast; up to five creatures who stay in range the whole cast: H (S-066/S-067 work participants; S-142 interruption). Short Rest benefits + 2d8: P (S-071 benefit-only recovery and Hit Dice). Can't be affected again until a Long Rest: H (S-014 cooldown after expiry; rest-scoped recipient lockout via S-070 Planned). | `casting_time: minute` should be 10 minutes; `target: single` should be up to five |
| prismatic_spray | **no** | 60-ft Cone, Dex: E. Per-target 1d8 ray table: P (S-214 weighted table). Damage rows: E. Indigo: Restrained, end-of-turn Con saves, three successes end / three failures Petrified: E (S-069 counted saves, verified). Violet: Blinded, Wis save at start of caster's next turn; on failure, teleport to another plane (GM's choice): P (S-177/S-178) + J (GM choice; ADR-0023). Row 8 of the table: **source text not captured cleanly in this extract. Re-read PDF p.154 before conversion; not filled from memory.** | single `12d6 fire` value |
| sacred_flame | yes | Dex save 1d8 radiant; **no benefit from Half or Three-Quarters Cover**: G → PROPOSED-spells-1 (no cover model exists). | — |
| scorching_ray | yes | Rays assigned to targets, separate attacks, 2d6 each: E. | — |
| shatter | yes | 10-ft Sphere, Con: E. Construct has Disadvantage: E (S-091). Nonmagical unattended objects take the damage: H (object damage host exists for Chain Lightning/Meteor Swarm; not Shatter). | — |
| shocking_grasp | yes | Melee spell attack; target can't make Opportunity Attacks until start of its next turn: E. | — |
| sorcerous_burst | yes | Choose 1 of 7 damage types: E. Exploding d8s capped at spellcasting modifier: E (native `_roll_sorcerous_burst_damage`; per-ID branch, an ADR-0018 conversion concern, not a new capability). Object target: H. | — |
| spare_the_dying | yes | 0 HP, not dead, becomes Stable; range doubles at 5/11/17: E. The SRD spell text doesn't contain the 1d4-hour recovery; that's in the general rules, so it isn't a clause of this spell. | — |
| starry_wisp | yes | Creature or object: H. Dim Light 10 ft: P (S-190). No Invisible benefit until end of next turn: E. | — |
| sunburst | yes | 60-ft Sphere, Con 12d6 radiant, Blinded 1 min, end-of-turn repeat Con saves (S-068): E. Dispels spell Darkness in area: E (register). | — |
| thunderwave | yes | 15-ft Cube from self, push 10 ft on fail: E. Unsecured objects entirely in Cube pushed 10 ft: H (object movement host). Boom audible 300 ft: P (S-218 sender/listener; no consumer yet). | — |
| vitriolic_sphere | **no** | 20-ft Sphere at a point ≤150 ft, Dex: E. Fail: 10d4 + 5d4 at end of target's next turn; success half initial only; upcast initial only: H (native `delayed_damage` from Acid Arrow; needs the area/save host). | no area or delayed authored |
| arms_of_hadar, conjure_barrage | no | Not in SRD 5.2.1: out of milestone, not decomposed. | — |

### 088-2 classification summary

- **E, existing (content conversion or correction only):** most clauses. The 7 data defects in the table are correction candidates: chromatic_orb, flame_strike, ice_storm, lightning_bolt, mass_heal, prayer_of_healing and prismatic_spray. Fire_storm and divine_word lack authored effects. Melf's Acid Arrow's name differs from SRD's "Acid Arrow".
- **P, planned under existing slices:** S-190/S-191 sight; S-194 location knowledge; S-177/S-178 planar removal; S-214 random tables; S-071 Short Rest benefit; S-150/S-151 stored globe; S-218 audible boom; S-127 damage-type choice.
- **H, missing host or continuation:**
  - Object targets for creature/object spells: Disintegrate, Eldritch Blast, Fire Bolt, Sorcerous Burst, Starry Wisp, Shatter, Blight's plant, Thunderwave's push.
  - Ignition of flammable objects outside Meteor Swarm: Burning Hands, Fire Bolt, Fireball, Fire Storm.
  - Multi-cube contiguous areas (Fire Storm).
  - Timed child terrain from an instantaneous spell (Ice Storm).
  - Delayed damage on an area host (Vitriolic Sphere).
  - Monster max-HP reduction (Harm).
  - Zombie successor on death (Finger of Death).
  - Creature-damage reaction trigger (Hellish Rebuke).
  - Participant cast, rest-scoped lockout (Prayer of Healing).
- **J, judgment:** Cone of Cold statue thawing; the Violet ray's GM-chosen plane; Disintegrate's Huge-object portion.
- **G, genuine gaps:** 3, listed below.

## Proposed vocabulary (placeholders, not slice numbers)

### PROPOSED-spells-1: Cover degree and source-declared cover exemption
- **Source clause:** Sacred Flame: "The target gains no benefit from Half Cover or Three-Quarters Cover for this save". The general Cover rules give +2/+5 to AC and Dex saves, and Total Cover prevents targeting.
- **Affected:** Sacred Flame directly. Every Dex-save area and attack spell whose register limit says "cover … remain open": fireball, burning_hands, cone_of_cold, circle_of_death, chain_lightning, sunburst.
- **Reuse:** QRY-05 geometry; S-190 obstruction (planned); S-091 roll policy; S-095 AC change.
- **Depends on:** S-190.
- **Finish line:** in a represented combat map, an obstruction between origin and target yields Half/Three-Quarters/Total cover. Attack AC and Dex save totals change by the declared amounts. Total cover refuses targeting before costs. A spell declaring the exemption ignores Half and Three-Quarters but not Total. This is proved through a real cast input path with a saved encounter reload.

### PROPOSED-spells-2: Result-triggered retarget chain (leap)
- **Source clause:** Chromatic Orb: "If you roll the same number on two or more of the d8s, the orb leaps to a different target … within 30 feet … can leap a maximum number of times equal to the level of the slot expended, and a creature can be targeted only once by each casting".
- **Affected:** Chromatic Orb. No other milestone spell in batches 1–2. Re-check the remaining families before building.
- **Reuse:** S-051 captured faces; S-034 prior-result identity; S-027 distance to another actor; Chain Lightning's distinct-secondary-target selection.
- **Depends on:** S-127 (damage-type choice) for the type carried into each leap.
- **Finish line:** a captured damage roll with a matching face offers the caster a new legal target within 30 ft of the previous one. A fresh attack and damage roll follows. The leap count is capped by slot level and repeat creatures are refused. No match ends the chain. A refusal spends nothing extra.

### PROPOSED-spells-3: Surface state change with trapped occupants
- **Source clause:** Freezing Sphere: water "freezes … to a depth of 6 inches over an area 30 feet square. This ice lasts for 1 minute. Creatures that were swimming on the surface … are trapped … Restrained … action … Strength (Athletics) check against your spell save DC to break free".
- **Affected:** Freezing Sphere. Later families may share it (Control Water, Wall of Ice, Sleet Storm); they're unreviewed.
- **Reuse:** S-179 surface/terrain costs; S-168/S-169 restraint relation and escape; S-087 timed child.
- **Depends on:** a represented "water surface" terrain fact (S-032 material facts).
- **Finish line:** a declared terrain cell of water becomes ice for a timed duration. Creatures swimming at its surface gain a source-owned Restrained that an Athletics action check can end. Expiry restores water and releases the trapped creatures. Both states survive a fresh-process reload.

## Class-membership data defects (cited, not changed)

The authority is the SRD 5.2.1 spell header. All 339 headers were read from the column-split PDF text, so none are unknown now. Memberships come from `spell_list_ids` in `data/core/classes/<class>.json`, which `DataLoader.get_spell_list_options` reads.

| ID | SRD 5.2.1 header | Loaded | Defect | Data line |
|---|---|---|---|---|
| fire_bolt | Sorcerer, Wizard | + Warlock | extra | warlock.json:64 |
| magic_missile | Sorcerer, Wizard | + Warlock | extra | warlock.json:82 |
| guidance | Cleric, Druid | + Bard | extra | bard.json:123 |
| misty_step | Sorcerer, Warlock, Wizard | + Ranger | extra | ranger.json:72 |
| resilient_sphere | Wizard | + Cleric, Paladin | extra | cleric.json:143, paladin.json:774 |
| mind_spike | Sorcerer, Warlock, Wizard | − Sorcerer | missing | sorcerer.json |
| phantasmal_force | Bard, Sorcerer, Wizard | − Sorcerer, Wizard | missing | sorcerer.json, wizard.json |

Subclass merge: I could not show one. Each extra ID sits directly in the base `spell_list_ids` array; the sorcerer.json and wizard.json matches at lines ~337/274 are a separate nested list. No SRD 5.2.1 subclass list explains these additions.

## Register findings (spell_status.json not regenerated)

- **899 vs 898:** the register's own rows already sum to 899 class memberships, matching the fresh export. The 898 figure in its prose summary is stale text, not a data difference.
- **53 duplicate definitions:** 53 loaded IDs are defined in two or three files under `data/core/spells/`. Winners: imported_spells.json 30, core_spells.json 16, conversion_batch_002.json 4, conversion_batch_001.json 3. In all 30 imported-versus-srd_additional pairs, the legacy imported record wins over the srd_additional record. Whether each winner is the intended SRD 5.2.1 shape is unreviewed; check it per spell before any conversion.

## Batch 088-3: conditions, control and forced movement (41 spells reviewed)

Scope: register `primary_behavior: control` (41 IDs). 37 are in SRD 5.2.1 and decomposed. compelled_duel, crown_of_madness, friends and thorn_whip aren't in SRD 5.2.1; they're out of milestone and not decomposed. "Winner" is the loaded definition from the inventory CSV `source_file`. The shared clauses listed in 088-2 (cost, range, components, slot payment, per-target save, upcast extra targets, Concentration) apply here too: **E**.

**Re-read of the rendered PDF (088-2 carry-overs), checked against page images at 80 dpi:**
- **Prismatic Spray (p.155):** row 8 reads "**Special.** The target is struck by two rays. Roll twice, rerolling any 8." That is **P (S-215: controlled reroll/nested tables)**, on top of S-214.
- **Divine Word (p.125):** the table ends at row 41–50 (Deafened, 1 minute). It has 4 rows, 0–20 to 41–50, and the trigger is "50 Hit Points or fewer". So the 088-2 classification was complete and nothing was cut off.

| Spell | Avail | Winner | Clause decomposition → classification (owner) |
|---|---|---|---|
| animal_friendship | yes | imported | Beast seen, Wis or Charmed 24 h: E. Ends if caster or allies deal damage: E. 24-hour world persistence beyond the encounter: H (register limit; S-070 actor-specific duration). |
| antipathy_sympathy | no | srd_add | 1-hour cast: E. Creature or Huge-or-smaller object target; chosen creature kind: E (S-025 fact bindings). Wis save on coming within 120 ft: P (S-184 first-approach trigger). Frightened and must move away / Charmed and must move closer, by the safest route: **G → PROPOSED-spells-4**. Can't willingly leave 5 ft: H (S-179). Damaged by the target → save: H (S-031). Save when ending turn >120 ft away: E (S-068 + S-027). Immune 1 minute after a success: H (S-014 cooldown per recipient). 10-day duration: H (S-070). |
| bestow_curse | no | imported | Touch, Wis save. Option 1, Disadvantage on one ability's checks and saves: E (S-091 + S-036). Option 2, Disadvantage on attacks against the caster: E (S-040). Option 3, start-of-turn Wis save or forced Dodge: H (S-068 + forced-action host; S-148 child actions). Option 4, extra 1d8 Necrotic on caster's attack/spell damage: E (S-041 window + S-109). Slot-based duration/no-Concentration: P (S-141). |
| blindness/deafness | yes | imported | E (register slice). |
| calm_emotions | no | imported | Humanoids in a 20-ft Sphere, Cha save, choice per creature: E (S-036). Option 1, Charmed/Frightened immunity plus suppression of existing conditions: E (S-074/S-075). Option 2, Indifferent toward chosen creatures, ends on damage to it or allies it witnesses: P (S-219 attitude; S-190 witness). |
| charm_monster, charm_person | yes | srd_add / imported | E (register). Friendly attitude: P (S-219). Target knows afterwards: J (narrative, ADR-0023). |
| color_spray | yes | imported | 15-ft Cone, Con, Blinded until end of caster's next turn: E. |
| command | yes | imported | 5 options (Approach, Drop, Flee, Grovel, Halt): E (native; register limit, no pickup flow: H S-164). Approach/Flee forced movement is native per-ID: see PROPOSED-spells-4. |
| compulsion | no | srd_add | Each chosen seen creature, Wis or Charmed: E. Bonus Action each turn to name a horizontal direction: H (S-148 child action). Target must move that way by the safest route: **G → PROPOSED-spells-4**. Repeat save after moving: H (S-077 post-movement event, Planned → P). |
| confusion | no | srd_add | 10-ft Sphere, Wis: E. No Bonus Actions/Reactions: P (S-160). Start-of-turn 1d10 behavior table: P (S-214). Row 1: random 1d4 compass direction with all movement: G → PROPOSED-spells-4. Row 7–8: melee attack on a random creature in reach: H (S-096 creature-owned attack choice). Repeat save at end of turn: E. Radius +5 ft per slot: E (area upcast). |
| contagion | no | srd_add | Touch, Con save 11d8 Necrotic + Poisoned: E. Chosen ability has Disadvantage on saves while Poisoned: E (S-091). Three successes/failures, failure lasts 7 days: E (S-069) + H (S-070 long duration). Effects that would end Poisoned require a Con save: **G → PROPOSED-spells-5**. |
| dissonant_whispers | no | imported | Wis 3d6 Psychic, half: E. On failure, must immediately use Reaction to move away by the safest route: P (S-183 Reaction movement) + PROPOSED-spells-4. |
| dominate_beast / person / monster | no | srd_add / srd_add / imported | Type gate, Wis or Charmed, Advantage if fighting: E. Repeat save whenever it takes damage: H (S-031 + S-068 damage-triggered). Telepathic link on the same plane: P (S-218, S-033). Free-action commands on caster's turn: H (S-156 command authority, verified for created actors, not charmed creatures). Reaction command costs the caster's Reaction: P (S-160). Upcast Concentration duration: P (S-141). |
| entangle | yes | imported | E (register). |
| enthrall | no | imported | Chosen seen creatures, Wis; auto-success if fighting: E (S-092). −10 to Wisdom (Perception) and Passive Perception: E (S-028 purpose-aware checks). |
| eyebite | no | imported | Self, one seen creature within 60 ft, choice of 3 effects: E. Magic action each turn to target another, never a creature that already succeeded against this casting: H (S-034 prior-result identity + S-148). Asleep (Unconscious, wakes on damage/shake): E (Sleep pattern). Panicked: Frightened, must Dash away; ends at ≥60 ft and out of sight: PROPOSED-spells-4 + P (S-190). Sickened: Poisoned: E. |
| fear | no | imported | 30-ft Cone, Wis: E. Drop held items: E (Command Drop) + H (no pickup flow). Frightened, Dash away by the safest route: PROPOSED-spells-4. End-of-turn save only when out of line of sight: P (S-190). |
| flesh_to_stone | no | srd_add | Con save; failure Restrained, success Speed 0 until caster's next turn: E. Constructs auto-succeed: E (S-092). Three-of-a-kind repeat saves to Petrified: E (S-069). Petrified becomes permanent if Concentration lasts the full duration (expiry vs broken): E (S-086 source-end reason) + H (durable condition after source end). |
| geas | no | srd_add | 1-minute cast; auto-success if it can't understand: P (S-218). Charmed 30 days: H (S-070). 5d10 Psychic when acting directly counter to the command, at most once a day: J (S-220 campaign-authored outcome; "directly counter" is a GM judgment, ADR-0023). Suicidal command ends the spell: J. Ended by Remove Curse/Greater Restoration/Wish: H (named ending sources). Upcast durations: P (S-141). |
| grease | yes | imported | E (register). |
| hold_monster, hold_person | yes | conv_002 / imported | E (shared, register). |
| hypnotic_pattern | no | imported | 30-ft Cube, only creatures that can see it: E (S-029). Charmed + Incapacitated + Speed 0: E. Ends on damage or another creature's shake action: E (Sleep pattern). |
| irresistible_dance | no | srd_add | Success: dance in place until end of its next turn: E (Speed 0 equivalent). Failure Charmed; all movement spent dancing; Disadvantage on Dex saves and attacks; attackers have Advantage: E (S-091). An action on its turn to repeat the save: H (S-068 action-triggered repeat; Entangle/Web escape action is the existing pattern). |
| mass_suggestion, suggestion | no | srd_add / imported | Seen targets that can hear and understand: P (S-218). Course of activity ≤25 words, must sound achievable, not obviously harmful: J (ADR-0023 narrative order). Charmed until duration ends or damage from caster/allies: E. Ends upon completing the activity: P (S-216 objective facts). Mass upcast durations: P (S-141). |
| power_word_stun | yes | srd_add | E (register). |
| sleep | yes | core | E (register). Exhaustion-immune / non-sleeping creatures auto-succeed: E (curated data). |
| slow | no | imported | ≤6 chosen creatures in 40-ft Cube, Wis: E. Speed halved; −2 AC and Dex saves: E (S-179, S-095). No Reactions; action or Bonus Action, not both; one attack per Attack action: P (S-160) + E (S-146). Somatic spell 25% failure chance: H (S-142 failure/refund on a random gate). End-of-turn repeat save: E. |
| stinking_cloud | no | imported | 20-ft Sphere, Heavily Obscured: P (S-190). Start-of-turn Con save → Poisoned until end of turn, no action/Bonus Action: P (S-184) + E. Dispersed by strong wind: H (Gust of Wind interaction). |
| tashas_hideous_laughter (Hideous Laughter) | no | imported | Wis; Prone + Incapacitated, can't end Prone itself: E + H (stand-up refusal). End-of-turn and on-damage repeat saves, with Advantage when damage-triggered: H (S-031 + S-068 + S-091). Upcast extra targets: E. |
| telekinesis | no | srd_add | Magic action each turn, may switch targets: H (S-148). Creature: Str save or move 30 ft, Restrained until end of next turn, suspended then falls: H (S-168) + P (S-181 fall). Object: unattended moves automatically; worn/carried needs a Str save: H (object host). Fine manipulation: J. **Re-read on rendered p.168 (088-4): the published SRD 5.2.1 sentence itself ends "such as manipulating a simple tool," and the Telepathic Bond header follows. Nothing is missing from our extract; the source sentence is truncated (D-24, J).** |
| vicious_mockery | yes | imported | Creature seen **or heard**: P (S-190). Wis 1d6 Psychic + Disadvantage on next attack before end of its next turn: E. Cantrip Upgrade: E. |
| web | no | imported | 20-ft Cube, Difficult Terrain: E. Lightly Obscured: P (S-190). Collapses unless anchored: J (map anchoring fact; S-032 could carry it). First entry on a turn / start of turn Dex save, Restrained: P (S-184) + E. Athletics escape action: E (S-169). 5-ft cubes burn away when exposed to fire, 2d4 Fire to creatures starting their turn in them: H (burning piece from 088-2 + S-087 child timer). |
| compelled_duel, crown_of_madness, friends, thorn_whip | no | imported | Not in SRD 5.2.1: out of milestone, not decomposed. |

### 088-3 classification summary

- **E:** most save/condition/repeat-save clauses (S-068/S-069/S-091/S-092 verified).
- **P:**
  - S-141 upcast durations.
  - S-160 Reaction/action budgets.
  - S-183 Reaction movement.
  - S-184 entry/start-of-turn triggers.
  - S-190 sight/obscurement.
  - S-214 behavior table.
  - S-216 activity completion.
  - S-218 language/hearing.
  - S-219 attitudes.
- **H:**
  - Damage-triggered repeat saves (Dominate ×3, Hideous Laughter).
  - Action-triggered repeat saves (Irresistible Dance).
  - Commands to charmed creatures (Dominate ×3, S-156).
  - Long durations (S-070).
  - Forced Dodge (Bestow Curse).
  - Object targets (Telekinesis).
  - Somatic failure chance (Slow).
  - Recipient immunity window (Antipathy/Sympathy).
  - Repeat-target exclusion (Eyebite).
- **J:**
  - Suggestion content.
  - Geas "directly counter" and the suicidal command.
  - Web anchoring.
  - Telekinesis fine control.
  - Charm awareness.
- **G:** 2 (below).

### PROPOSED-spells-4: Compelled movement directive
- **Source clauses:**
  - Fear: "takes the Dash action and moves away from you by the safest route … unless there is nowhere to move".
  - Antipathy/Sympathy: "must use its movement … to get as far away as possible / as close as possible … by the safest route".
  - Compulsion: "must use as much of its movement as possible to move in that direction".
  - Eyebite: Panicked.
  - Confusion: row 1, random 1d4 direction.
  - Dissonant Whispers: Reaction move away.
  - Command: Approach and Flee (currently native per-ID).
- **Affected:** the 7 spells above.
- **Reuse:** S-027 distance; S-179 movement costs; S-158 autonomy defaults; S-183 Reaction movement; S-096 creature-owned choices.
- **Depends on:** S-183 for the Reaction variant; S-190 for the line-of-sight end checks.
- **Finish line:** a source-owned directive on an actor declares the anchor (source actor, point or compass direction), the sense (away, toward or fixed direction), the movement amount (all movement, Dash, or Reaction movement) and the route policy (safest/shortest, no willing provocation). Both player-controlled and AI turns obey it. "Nowhere to move" ends movement without refusal. The directive ends exactly when its source effect ends. Command Approach/Flee rebuilt on it gives identical results to the native path. All of this survives a combat save and reload.

### PROPOSED-spells-5: Guarded condition removal
- **Source clause:** Contagion: "Whenever the Poisoned target receives an effect that would end the Poisoned condition, the target must succeed on a Constitution saving throw, or the Poisoned condition doesn't end on it."
- **Affected:** Contagion. Re-check the unreviewed families (curses, diseases) before building.
- **Reuse:** S-074/S-075 suppression; S-116 one recipient's incoming effect negation; S-092 explicit save outcomes.
- **Depends on:** none beyond verified slices.
- **Finish line:** a source-owned condition marks its removal as guarded by a declared save. Any removal attempt (Lesser Restoration, a Paladin's Lay On Hands cure, a Heal-style end) triggers that save. Failure leaves that source's condition in place and reports it; the remover's own cost is still spent. Success removes it. Other sources of the same condition are unaffected.

## Settled decisions (recorded 088-4)

- **Command, Undead exclusion:** the loaded Undead exclusion is an SRD defect (confirms D-11). SRD 5.2.1 Command has no creature-type exclusion.
- **Duplicates:** fix field by field toward the SRD text in a later correction job. Do not pick one file wholesale. See the duplicate table and D-23.
- **PROPOSED-spells-4 vs native Command code:** whether the slice replaces Command's native code is an implementation choice for that slice. This audit takes no position.

## Batch 088-4: timed effects (45 spells reviewed)

Scope: every ID with `primary_behavior == timed_effects` (45). 41 are in SRD 5.2.1 and were decomposed against the column-split extract; 4 are out of milestone. persistent_areas (45) was **not** reviewed in this batch, to keep one batch inside 40–60.

| ID | Avail | Winner | Clauses → classification (owner) |
|---|---|---|---|
| aid | yes | imported | 3 creatures, +5 max and current HP, 8 h: E. Upcast +5/level: E. Campaign-time expiry: H (S-070). |
| aura_of_life | yes | srd_add | 30-ft Emanation: E (S-080/S-081). Necrotic Resistance: E. HP max can't be reduced: E. Ally at 0 HP regains 1 at turn start in aura: E. |
| bane | yes | batch_001 | Cha save, up to 3 seen, −1d4 attacks/saves: E. Upcast targets: E. |
| barkskin | yes | imported | Bonus Action (data says action, D-32). AC floor 17: E. |
| beacon_of_hope | yes | imported | Any number of creatures: E (data D-29). Adv on Wis saves and Death Saves: E. Max healing: E. |
| bless | yes | batch_001 | +1d4 attacks/saves, 3 targets, upcast, Holy Symbol: E. |
| blur | yes | imported | Disadvantage against you: E. Blindsight/Truesight exemption: P (S-190). |
| death_ward | yes | srd_add | First drop to 0 → 1 HP, ends: E. Instant-kill-without-damage negation: E. 8 h: H (S-070). |
| divine_favor | yes | imported | +1d4 Radiant on weapon hits, 1 min: E. |
| enhance_ability | yes | imported | Chosen ability, Advantage on checks: E. Upcast targets with a different ability each: E/H (data lacks upcast; spurious 2d6 force, D-23 class). |
| enlarge/reduce | no | imported | Unwilling Con save: E. Size category ±1 including gear: H (size change on a live actor; S-032 holds facts only, S-163 projection could carry it). Dropped items and thrown weapons revert: H. Str check/save Adv/Disadv: E. ±1d4 weapon/Unarmed damage, floor 1: E. Object target, not worn or carried: H (object host). |
| expeditious_retreat | no | imported | Dash now, then Dash as Bonus Action for 10 min: H (Bonus Action action-grant; S-160 budgets). |
| false_life | yes | imported | 2d4+4 Temp HP, +5/level: E. |
| fire_shield | no | srd_add | Light 10/10 ft: P (S-190). Warm/chill choice → Cold/Fire Resistance: E. Melee hit from within 5 ft → 2d8 retaliation: E (S-114 settled-damage counter-effect). |
| foresight | no | srd_add | Advantage on D20 Tests; Disadvantage against target: E. Ends if cast again: E. 8 h: H (S-070). 1-minute casting: P (S-141/S-216). |
| glibness | no | srd_add | Replace Cha check roll with 15: E (S-038 floors). Truth-detection magic reads truthful: P (S-195 masked detection). |
| guidance | yes | imported | Chosen skill, +1d4 to checks: E. |
| haste | no | imported | Speed ×2, +2 AC, Dex-save Adv: E. Extra restricted action (one Attack, Dash, Disengage, Hide, Utilize): P (S-160). End lethargy: Incapacitated, Speed 0 until end of next turn: E (S-086 aftermath). Data save DEX spurious (D-28). |
| heroes_feast | no | srd_add | 10-minute cast, 1,000 GP consumed bowl: P (S-216) + E. 1-hour meal before benefits, up to 12 partakers: H (S-067 deadline + S-086 child timer). 24 h: Poison Resistance, Frightened/Poisoned immunity, +2d10 HP max and HP: E + H (S-070). |
| heroism | yes | imported | Frightened immunity; Temp HP = spell mod at turn start: E. Upcast targets: E (runtime) / data lacks upcast (D-33). |
| hex | no | imported | +1d6 Necrotic on attack hits: E. Disadvantage on chosen-ability checks: E. Move curse as Bonus Action after target drops to 0: H (S-043 + S-148). Upcast Concentration lengths: P (S-141) + H (S-070); data lacks upcast (D-35). |
| holy_aura | no | srd_add | 30-ft Emanation, chosen creatures: E (S-080). Adv on all saves, Disadv against them: E. Fiend/Undead melee hit → Con save or Blinded: E (S-114) + E. Reliquary focus: E. |
| hunters_mark | no | imported | +1d6 Force on attack hits: E. Perception/Survival Adv to find it: E. Move mark as Bonus Action after 0 HP: H (S-043 + S-148). 8/24 h upcast: P (S-141) + H (S-070). Unavailable per known_limit. |
| longstrider | yes | imported | +10 ft Speed, 1 h, upcast targets: E. Campaign expiry: H (S-070). |
| mage_armor | yes | core | Base AC 13+Dex, unarmored willing, ends on donning armor: E. |
| magic_weapon | yes | imported | Bonus Action, nonmagical weapon +1/+2/+3 for 1 h: E as vocabulary; **runtime deviates** (D-25). Ends if cast again: E. |
| mind_blank | no | srd_add | Psychic and Charmed immunity: E. Unaffected by emotion/alignment/thought/location sensing; no spell (even Wish) gathers info, observes or controls mind: P (S-195) + J (scope of "control its mind"). 24 h: H (S-070). |
| mirror_image | no | imported | 3 duplicates; d6 per remaining duplicate, 3+ redirects the hit and destroys one: P (S-187 non-occupying duplicate) + E (S-112 redirect). Blinded/Blindsight/Truesight attackers unaffected: P (S-190). |
| protection_from_energy | yes | imported | Resistance to one chosen type of five: E. |
| protection_from_evil_and_good | yes | imported | Six creature types: Disadv on attacks, no Charmed/Frightened from them: E. Possession: P (S-173). Adv on new saves vs existing effect: H (source-aware save Adv). |
| protection_from_poison | yes | imported | End Poisoned; Adv vs Poisoned; Poison Resistance: E. |
| ray_of_enfeeblement | yes | imported | Con save; success: Disadv on next attack before your next turn; failure: Disadv Str D20 Tests, −1d8 damage, end-of-turn repeat: E. |
| ray_of_sickness | yes | imported | Ranged spell attack, 2d8 Poison, Poisoned to end of your next turn, upcast: E. |
| regenerate | yes | srd_add | 4d8+15, 1 HP at turn start for 1 h: E. Regrowth after 2 min: P (S-206/S-207). 1-minute cast: P (S-216); runtime approximates (D-36). |
| resistance | yes | imported | Chosen type of 11, reduce by 1d4, once per turn: E. |
| sanctuary | yes | imported | Wis save or retarget/lose; areas excluded; ends on attack/spell/damage: E. |
| shield | yes | core | Reaction on hit or Magic Missile; +5 AC incl. trigger; no MM damage: E. |
| shield_of_faith | yes | imported | +2 AC, 10 min Concentration: E. |
| shillelagh | yes | imported | Spell ability for attack/damage; d8 die; Force or normal type; ends if cast again or let go; die upgrade at 5/11/17: E + H (die-size override by character level). |
| stoneskin | no | srd_add | B/P/S Resistance; 100 GP consumed: E. |
| warding_bond | no | imported | +1 AC/saves, Resistance to all within 60 ft: E. Caster takes the same damage: H (S-111/S-112 copy, not split). Ends at caster 0 HP, >60 ft separation, or recast on either: E + H (distance watcher). Rings worn by both: J (per-target material). |
| armor_of_agathys, blade_ward, crusaders_mantle, elemental_weapon | blade_ward yes, rest no | imported | Not in SRD 5.2.1: out of milestone, not decomposed. blade_ward castable (D-26). |

### 088-4 classification summary

- **E:** most clauses. Riders, AC floors, Resistance, Temp HP, Adv/Disadv, auras and repeat saves already have verified owners.
- **P:**
  - S-070 long and campaign durations (listed under H where the clause can't run without it).
  - S-141 upcast durations (Hex, Hunter's Mark).
  - S-160 restricted extra action (Haste).
  - S-173 possession.
  - S-187 duplicates (Mirror Image).
  - S-190 sight and light.
  - S-195 masked detection (Glibness, Mind Blank).
  - S-206/S-207 regrowth.
  - S-216 long casting times.
- **H:**
  - Campaign-clock expiry on 8 h/24 h effects (S-070), the commonest blocker in this family.
  - Live size-category change (Enlarge/Reduce).
  - Mark/curse transfer after 0 HP (Hex, Hunter's Mark).
  - Bonus-Action Dash grant (Expeditious Retreat).
  - Delayed group benefit (Heroes' Feast).
  - Damage copy to caster (Warding Bond).
  - Source-aware save Advantage (Protection from Evil and Good).
  - Level-scaled die override (Shillelagh).
- **G:** none. No `PROPOSED-spells-N` was added in 088-4. The closest candidate is live size change, held as H because S-163's reversible projection may carry it; the owning slice should decide.
- **J:**
  - Telekinesis source truncation (D-24).
  - Mind Blank "control its mind" scope.
  - Warding Bond per-target ring material.

## Parked ADR-0023 judgment items

The SRD can't settle these. Each is parked for an ADR-0023 decision; no slice or data change in this audit depends on them. Every future judgment item is parked here the same way: the exact SRD 5.2.1 clause, verbatim, with its page. Quotes are from the column-split extract, checked against `pdftotext` page text; line-break hyphens are removed.

| # | Batch | Spell | SRD 5.2.1 clause (verbatim) | Page | Open question |
|---|---|---|---|---|---|
| J-01 | 088-4 | Telekinesis | "You can exert fine control on objects with your telekinetic grip, such as manipulating a simple tool," | 168 | What fine control allows. The published sentence stops at the comma (D-24). |
| J-02 | 088-4 | Mind Blank | "no spell—not even Wish—can gather information about the target, observe it remotely, or control its mind." | 149 | Whether "control its mind" blocks all compulsion (Command, Suggestion) or only Charmed-based control. |
| J-03 | 088-4 | Warding Bond | "M (a pair of platinum rings worth 50+ GP each, which you and the target must wear for the duration)" | 173 | How to model per-target worn material for both creatures. |
| J-04 | 088-5 | Glyph of Warding; Symbol | "You decide what triggers the glyph when you cast the spell." | 136 (Glyph); 167 (Symbol) | How far a free-form authored trigger may go (type filters, passwords, "seeing the glyph"). |
| J-05 | 088-5 | Call Lightning | "If you’re outdoors in a storm when you cast this spell, the spell gives you control over that storm instead of creating a new one. Under such conditions, the spell’s damage increases by 1d10." | 114 | No weather fact exists; who declares "outdoors in a storm". |
| J-06 | 088-5 | Guards and Wards | "at each intersection or branching passage offering a choice of direction, there is a 50 percent chance that a creature other than you believes it is going in the opposite direction from the one it chooses." | 138 | Needs map intersection facts and a belief-vs-actual direction model. |
| J-07 | 088-5 | Wall of Stone | "It must, however, merge with and be solidly supported by existing stone." | 173 | Needs a map material/support fact. |
| J-08 | 088-5 | Control Water | "Redirect Flow. You cause flowing water in the area to move in a direction you choose, even if the water has to flow over obstacles, up walls, or in other unlikely directions." Also: "Any Huge or smaller vehicles struck by the wave have a 25 percent chance of capsizing." | 120 | No water-flow or vehicle host; what each produces mechanically. |
| J-09 | 088-5 | Spirit Guardians | "On a failed save, the creature takes 3d8 Radiant damage (if you are good or neutral) or 3d8 Necrotic damage (if you are evil)." | 165 | Alignment isn't tracked; whether the caster chooses or a character fact decides. |
| J-10 | 088-6 | Teleport | "Your familiarity with the destination determines whether you arrive there successfully. The GM rolls 1d100 and consults the Teleportation Outcome table" | 168 | Who assigns the familiarity category (Very familiar, Seen casually, etc.) to a destination. |
| J-11 | 088-6 | Plane Shift | "you appear in or near that destination, as determined by the GM." | 153 | How "in or near" is chosen without a GM. |
| J-12 | 088-6 | Banishment | "The target is instead transported to a random location on a plane (GM’s choice) associated with its creature type." | 112 | Destination for permanently banished creatures. |
| J-13 | 088-6 | Gate | "You gain no special power over the creature, and it is free to act as the GM deems appropriate." | 135 | Behavior of a named, summoned creature. |
| J-14 | 088-6 | Dimension Door | "It can be a place you can see, one you can visualize, or one you can describe by stating distance and direction" | 123 | Whether unseen described destinations are allowed and how they resolve against map knowledge. |
| J-15 | 088-6 | Clairvoyance | "in a location familiar to you (a place you have visited or seen before) or in an obvious location that is unfamiliar to you (such as behind a door, around a corner, or in a grove of trees)." | 115 | What counts as an "obvious" unfamiliar location. |
| J-16 | 088-6 | Find Traps | "A trap, for the purpose of this spell, includes any object or mechanism that was created to cause damage or other danger." | 131 | Which authored hazards are tagged as traps. |
| J-17 | 088-6 | Meld into Stone | "Minor physical damage to the stone doesn’t harm you, but its partial destruction or a change in its shape (to the extent that you no longer fit within it) expels you" | 148 | Threshold between "minor" damage and "partial destruction". |
| J-18 | 088-6 | Magnificent Mansion | "Each servant can perform tasks that a human could perform, but they can’t attack or take any action that would directly harm another creature." | 147 | Which servant tasks produce mechanical results. |
| J-19 | 088-5 | Flaming Sphere | "When you move the sphere, you can direct it over barriers up to 5 feet tall and jump it across pits up to 10 feet wide." | 132 | Needs barrier-height and pit-width map facts for the sphere's path. |
| J-20 | 088-5 | Plant Growth (Enrichment) | "All plants in a half-mile radius centered on a point within range become enriched for 365 days. The plants yield twice the normal amount of food when harvested." | 153 | No harvest or crop economy exists; what the doubled yield produces. |
| J-21 | 088-7 | Magic Mouth | "The trigger can be as general or as detailed as you like," | 146 | How far a free-form authored trigger may go (same question as J-04). |
| J-22 | 088-7 | Programmed Illusion | "though it must be based on visual or audible phenomena that occur within 30 feet of the area." | 156 | Which observable events count as trigger phenomena. |
| J-23 | 088-7 | Fabricate | "The quality of any fabricated objects is based on the quality of the raw materials." | 129 | How raw-material quality maps to output item quality. |
| J-24 | 088-7 | Zone of Truth | "On a failed save, a creature can’t speak a deliberate lie while in the radius." | 175 | No dialogue-truth model; what an authored NPC line counts as a lie. |
| J-25 | 088-7 | Modify Memory | "change its memory of the event’s details, or create a memory of some other event." | 150 | How a free-form memory edit changes authored knowledge and attitude. |
| J-26 | 088-7 | Speak with Dead | "Answers are usually brief, cryptic, or repetitive," | 164 | Who authors the corpse's answers, and whether antagonism is decided by attitude. |
| J-27 | 088-7 | Hallucinatory Terrain | "The tactile characteristics of the terrain are unchanged, so creatures entering the area are likely to notice the illusion." | 139 | When entering creatures notice without a Study check. |
| J-28 | 088-8 | Augury | "The GM chooses the omen from the Omens table." | 111 | Who picks Weal or Woe without a GM. |
| J-29 | 088-8 | Commune | "the GM might offer a short phrase as an answer instead." | 116 | Source of deity answers and the 'unclear' boundary. |
| J-30 | 088-8 | Contact Other Plane | "The GM answers each question with one word," | 119 | Source of answers. |
| J-31 | 088-8 | Divination | "The GM offers a truthful reply, which might be a short phrase or cryptic rhyme." | 125 | Source of the reply. |
| J-32 | 088-8 | Legend Lore | "brief summary of the significant lore about that famous thing, as described by the GM." | 144 | Who authors lore and decides what is 'famous'. |
| J-33 | 088-8 | Commune with Nature | "Location of one Challenge Rating 10+ creature (GM’s choice)" | 117 | Which creature is disclosed. |
| J-34 | 088-8 | Reincarnate | "or the GM chooses another playable species." | 158 | Whether the d10 table is always used. |
| J-35 | 088-8 | Awaken | "The GM chooses statistics appropriate for the awakened Plant," | 112 | Which stat block an awakened plant uses. |
| J-36 | 088-8 | Planar Ally | "though you might get a different creature anyway (GM’s choice)." | 152 | Which creature arrives, and its price and behavior. |
| J-37 | 088-8 | Planar Binding | "If the creature is Hostile, it strives to twist your commands to achieve its own objectives." | 153 | How a bound Hostile creature twists commands. |
| J-38 | 088-8 | Control Weather | "you change the current weather conditions, which are determined by the GM." | 120 | Starting weather stage (also J-05). |
| J-39 | 088-8 | Contingency | "You describe that trigger when you cast the two spells." | 119 | Free-form trigger scope (also J-04/J-21). |
| J-40 | 088-8 | Sequester | "The condition can be anything you choose, but it must occur or be visible within 1 mile of the target." | 161 | Free-form end condition. |
| J-41 | 088-8 | Animate Dead (Create Undead analogous, p.121) | "or you can issue a general command, such as to guard a chamber or corridor." | 108 | How a general standing command resolves each turn. |
| J-42 | 088-8 | Wish (Reshape Reality) | "The GM has great latitude in ruling what occurs in such an instance;" | 175 | Reshape Reality outcomes; only listed effects are mechanical (S-221). |
| J-43 | 088-8 | Imprisonment | "The trigger can be as simple or as elaborate as you choose, but the GM must agree that it has a high likelihood of happening within the next decade." | 142 | How does a runtime check that an authored end trigger is likely within a decade, and which observable events can the trigger use? |

## Batch 088-5: persistent areas (45 spells reviewed)

Scope: every ID with `primary_behavior == persistent_areas` (45). 41 are in SRD 5.2.1 and decomposed; 4 are out of milestone. Long entries whose column-split extract ran past the first read (Control Water, Earthquake, Glyph of Warding, Guards and Wards, Hallow, Prismatic Wall, Symbol, Wall of Stone) were read to their end. The Prismatic Wall Indigo and Violet rows were read from `pdftotext -layout` p.155.

| ID | Avail | Winner | Clauses → classification (owner) |
|---|---|---|---|
| antilife_shell | yes | srd_add | 10-ft Emanation blocks non-Construct/Undead passing or reaching: P (S-185). Spells and ranged/reach attacks through it: P (S-185). Ends if caster forces a creature through: H (barrier-push end check). |
| antimagic_field | no | srd_add | No spells, Magic actions or magical effects inside: E (S-074/S-075 suppression) + H (cast refusal by location). Item properties off: E (S-203). AoEs can't extend in; no teleport/planar: H + P (S-177/S-178). Suppressed time counts against duration: E (S-074). Immune to Dispel; fields don't cancel: E. |
| black_tentacles | yes | srd_add | 20-ft square Difficult Terrain: E (S-179). Str save 3d6 + Restrained, entry/end-turn once per turn: P (S-184) + E. Athletics escape action: E (S-169). |
| blade_barrier | no | srd_add | Straight or ring wall: E (`line`) + H (ring shape). Three-Quarters Cover: P (PROPOSED-spells-1). Difficult Terrain: E. Dex 6d10 Force on cast, entry, end of turn, once per turn: P (S-184) + E. |
| call_lightning | no | imported | 60-ft-radius cloud; 5-ft burst Dex 3d10: E. Magic action to repeat: H (S-148 recast-from-effect). Existing storm +1d10: J (weather fact). Upcast: E (data lacks upcast, D-37). |
| cloudkill | yes | srd_add | 20-ft Sphere, Heavily Obscured: P (S-190). Con 5d8 on cast, area moving onto, entry, end of turn; once per turn: E (native moving area) + P (S-184). Moves 10 ft away each turn: E. Dispersed by strong wind: H. Upcast: E. |
| conjure_animals | yes | imported | Pack, Str-save Adv within 5 ft: E. Move pack 30 ft with your move: E (native). Dex 3d10 within 10 ft, once per turn: E + P (S-184). Data target/damage missing (D-38). |
| conjure_celestial | yes | srd_add | Cylinder, per-creature heal or Dex 6d12 choice: E. Bright Light: P (S-190). Move 30 ft with you; once per turn: E. |
| conjure_elemental | yes | srd_add | Element choice; Dex 8d8 + Restrained if none held; start-of-turn repeat 4d8 or free: E (S-068) + E. |
| conjure_fey | yes | srd_add | Melee spell attack 3d12+mod, Frightened with dual source: E. Bonus Action teleport 30 ft + attack: E. |
| conjure_minor_elementals | yes | srd_add | 15-ft Emanation rider 2d8 chosen type: E (S-080). Enemy Difficult Terrain: E. |
| conjure_woodland_beings | yes | srd_add | 10-ft Emanation Wis 5d8 Force: E. Bonus Action Disengage: E. |
| control_water | no | srd_add | 100-ft Cube; Magic action to switch modes: H (S-148). Flood/wave/vehicles 25% capsize: H (vehicle host) + J. Part Water trench and refill over a round: H (terrain mutation + S-087). Redirect Flow: J. Whirlpool pull 10 ft, Str 2d8, Athletics escape: E + H (water-depth precondition). |
| delayed_blast_fireball | no | srd_add | Bead at point; on spell end 20-ft Sphere Dex save for accumulated damage: E (S-086 aftermath). **+1d6 each time your turn ends:** G (PROPOSED-spells-6). Touch → Dex save, explode or throw 40 ft: H (object interaction). Flammables ignite: E. Data shape `line`, 2 points (D-39). |
| earthquake | no | srd_add | 100-ft circle Difficult Terrain: E. Cast and end-of-turn Dex save → Prone + Concentration broken: E. 1d6 fissures 1d10×10 ft deep, fall-in save: H (terrain creation) + P (S-181). Structures take 50: H (structure HP host). Collapse within half height → Dex 12d6, Prone, buried DC 20 escape: H + E (S-169). Data puts 12d6 on the main save (D-40). |
| flaming_sphere | no | imported | End-turn within 5 ft Dex 2d6: P (S-184). Bonus Action move 30 ft, ram into space then stop: E (moving area). Over 5-ft barriers/10-ft pits: J (map fact). Ignites flammables; light 20/20: E + P (S-190). |
| forbiddance | no | srd_add | 40,000 sq ft ward, 1 day: H (S-070). No teleport/portals/planar entry: P (S-177/S-178) + S-185. Chosen types take 5d10 Radiant/Necrotic on entry/end turn: P (S-184). Password: P (S-218). No overlap: H. 30-day permanence: H (S-070). Data casting/target/damage (D-41). |
| glyph_of_warding | no | imported | Hidden glyph, Perception DC to notice: P (S-188). Authored trigger with type and password filters: P (S-184) + J (free-form trigger). Explosive rune 20-ft Dex 5d8 chosen type: E. Spell glyph stores a spell: P (S-150/S-151). Broken if moved >10 ft: H. Upcast: E. Data damage type fire only (D-42). |
| guardian_of_faith | no | srd_add | Large invulnerable occupant: H (non-actor occupant). Enemy first move within 10 ft / start turn: Dex 20 Radiant half: P (S-184). Vanishes after 60 total damage: G (PROPOSED-spells-7). 8 h: H (S-070). |
| guards_and_wards | no | srd_add | 2,500 sq ft shaped ward, exemptions, password: H + P (S-218). Corridors fog + 50% direction reversal: P (S-190) + J. Doors Arcane Lock + illusory walls: H (object host) + P (S-189). Stairs Web regrowing in 10 min: H (S-087). Other effects (Dancing Lights, Magic Mouth, Stinking Cloud, Gust, Suggestion): H (spawn other spells' effects). Effects dispelled separately; all four → ends; 365-day permanence: H (S-070). Data casting time (D-43). |
| gust_of_wind | no | imported | 60×10 Line from self: E (`line`). Str save push 15 ft; end-of-turn repeat: E + P (S-184). Double cost moving closer: H (directional terrain cost). Disperses gas, douses flames: H (cross-spell dispersal). Bonus Action re-aim: H (S-148). Data range/target (D-44). |
| hallow | no | srd_add | 60-ft radius; no overlap: H. Types can't willingly enter: P (S-185). Charm/Fright/possession suspended inside: E (S-075) + P (S-173). One Extra Effect from 10 options (Courage, Darkness, Daylight, Peaceful Rest, Extradimensional Interference, Fear, Resistance, Silence, Tongues, Vulnerability): E for Courage/Fear/Resistance/Vulnerability; P (S-190) Darkness/Daylight; P (S-218) Silence/Tongues; P (S-175) Peaceful Rest; P (S-177) Extradimensional. Until dispelled: H (S-070). Data casting time (D-45). |
| incendiary_cloud | no | srd_add | Heavily Obscured: P (S-190). Dex 10d8 on appear, move-into, entry, end turn; once per turn: E. Moves 10 ft each turn: E. Wind dispersal: H. |
| insect_plague | no | srd_add | Lightly Obscured: P (S-190). Difficult Terrain: E. Con 4d10 on appear, first entry, end turn: P (S-184) + E. Upcast: E. |
| magic_circle | no | imported | 10-ft Cylinder, chosen types can't willingly enter nonmagically: P (S-185). Teleport/planar entry needs Cha save: H. Disadv on attacks into it; no possession/Charm/Fright: E + P (S-173). Reverse mode: P (S-185). Upcast duration +1 h: P (S-141). |
| moonbeam | yes | imported | 5-ft Cylinder Dim Light: P (S-190). Magic action move 60 ft: E. Con 2d10 on appear, move-into, entry, end turn: E. Shape-shifted reverts and can't shift while inside: H (S-163 forced reversion). Upcast: E. |
| plant_growth | yes | imported | Overgrowth 100-ft Sphere, 4× movement, exclusions: E (S-179). Enrichment 8 h cast, half-mile, 365 days, double yield: P (S-199) + J. |
| prismatic_wall | no | srd_add | Opaque wall or globe; ends if placed on a creature: P (S-186). Light 100/100: P (S-190). Designated pass-through: P (S-185). Seeing creature within 20 ft Con save or Blinded 1 min: P (S-184) + E. Seven layers, one Dex save each in order: P (S-088). Red–Blue damage: E. Indigo three-of-a-kind Con saves → Petrified: E (S-069). Violet Blinded then Wis or plane shift: P (S-177). Layer destruction by specific damage/spell, AC 10: G (PROPOSED-spells-8). Antimagic doesn't affect it; Dispel only violet: E. Data save CON on 12d6 (D-46). |
| sleet_storm | yes | imported | Heavily Obscured: P (S-190). Flames doused: H. Difficult Terrain: E. First entry/start turn Dex → Prone + lose Concentration: P (S-184) + E. |
| spike_growth | yes | imported | 20-ft Sphere Difficult Terrain; 2d4 per 5 ft moved: E (S-179 native). Camouflage: Search + Perception/Survival to recognize: P (S-188). Data damage type force (D-47). |
| spirit_guardians | yes | imported | 15-ft Emanation, designated exemptions: E (S-080). Speed halved: E. Wis 3d8 Radiant/Necrotic by alignment on emanation-moves-in, entry, end turn: E + J (alignment fact). Upcast: E. |
| storm_of_vengeance | no | srd_add | 300-ft cloud; Con save 2d6 Thunder + Deafened on appear: E. Turn-indexed schedule (acid, six bolts, hail, 5–10 cold): P (S-088). Difficult Terrain, Heavily Obscured, no ranged weapon attacks, strong wind: E + P (S-190) + H. Data half_on_save true (D-48). |
| sunbeam | no | srd_add | Line Con 6d8 + Blinded: E. Magic action new Line: H (S-148). Sunlight 30/30: P (S-190) + H (sunlight tag). |
| symbol | no | srd_add | Hidden glyph, trigger, broken if moved: as Glyph (P S-184/S-188, H). Activation: 60-ft Dim Light for 10 min, targets on activation/entry/end turn: P (S-184). Death/Discord/Fear/Pain/Sleep/Stunning: E (Fear's forced 30-ft move: P PROPOSED-spells-4). Data encodes Death only (D-49). |
| tsunami | no | srd_add | 300×300×50 wall, Str 6d10: E. Moves 50 ft carrying creatures: H (S-172 moving container analogue). Height −50 ft and −1d10 per round, ends at 0: G-adjacent, held H (S-090 escalation shape). Swim only with Athletics; leaving falls: E + P (S-181). |
| wall_of_fire | yes | srd_add | Line or ring; opaque: E + H (ring) + P (S-190). Dex 5d8 on appear; one damaging side within 10 ft end turn / entry: E (verified bounded slice). Upcast: E. |
| wall_of_force | no | srd_add | Invisible panels/dome/globe: P (S-185) + H (shape). Pushes occupants aside: P (S-186). Nothing passes; immune to damage and Dispel; Disintegrate destroys; blocks Ethereal: P (S-185) + H. Data target single (D-50). |
| wall_of_ice | no | srd_add | Panels/dome/globe; push aside + Dex 10d6: P (S-186) + E. AC 12, 30 HP per 10-ft section, immunities/vulnerability: G (PROPOSED-spells-8). Destroyed section → frigid air, first pass Con 5d6: G (PROPOSED-spells-8) + P (S-184). Upcast both: E. |
| wall_of_stone | no | srd_add | Panels, push aside, enclosed creature Dex save + Reaction move: P (S-186) + P (S-183). Bridges/ramps, support rule: J (map). Panel AC 15, 30 HP per inch: G (PROPOSED-spells-8). Permanent after full-duration Concentration: H (S-086 aftermath on completed duration). |
| wall_of_thorns | no | srd_add | Wall or circle; blocks sight: P (S-190). Dex 7d8 Piercing on appear: E. 4× movement through: E (S-179). First entry/end turn Dex 7d8 Slashing: P (S-184). Upcast: E (data lacks upcast, D-51). |
| wind_wall | no | imported | 50-ft path wall, Str 4d8 Bludgeoning on appear: E + H (path shape). Gases kept back: H. Small fliers/gaseous can't pass: P (S-185). Ordinary projectiles miss: P (S-185). Data 3d8 Force (D-52). |
| aura_of_vitality, cloud_of_daggers, cordon_of_arrows, hunger_of_hadar | cloud_of_daggers yes, rest no | imported | Not in SRD 5.2.1: out of milestone, not decomposed. cloud_of_daggers castable (D-53). |

### 088-5 classification summary

- **E:** area saves and damage, native moving areas, terrain cost, auras and emanations, repeat and counted saves (S-068/S-069), suppression (S-074/S-075/S-203).
- **P:**
  - S-184 entry/end-turn trigger scopes, the most common owner in this family.
  - S-185/S-186 barriers and placement over occupants.
  - S-190 obscurement and light.
  - S-088 ordered procedures (Prismatic Wall layers, Storm of Vengeance turns).
  - S-150/S-151 stored spell (Glyph of Warding).
  - S-188 hidden glyphs and camouflage.
  - S-173 possession; S-177/S-178 planar travel; S-181 falling; S-183 Reaction movement.
  - S-218 passwords and Silence/Tongues; S-199 Enrichment; S-141 upcast duration.
- **H:**
  - Long and permanent area wards (S-070): Forbiddance, Hallow, Guards and Wards, Guardian of Faith.
  - Ring/dome/panel/path wall shapes beyond `line` and sphere.
  - Magic action to re-use an effect (Call Lightning, Sunbeam, Control Water; S-148).
  - Cross-spell dispersal by strong wind (Cloudkill, Incendiary Cloud, Gust of Wind).
  - Terrain creation and structures (Earthquake, Control Water).
  - Non-actor invulnerable occupant (Guardian of Faith).
  - Forced reversion in an area (Moonbeam).
  - Moving wall carrying occupants with shrinking height (Tsunami).
- **G:** three new placeholders, below.
- **J:** Call Lightning "outdoors in a storm"; Control Water vehicles and flow; Flaming Sphere jump limits; Glyph free-form triggers; Guards and Wards direction confusion; Wall of Stone support; Spirit Guardians alignment.

### PROPOSED-spells-6: Accumulating payload released at source end

- **Need:** an effect owns a damage pool that grows by a fixed die at each end of the caster's turn and is released as one area save when the source ends, whether by Concentration loss, duration, touch failure or impact.
- **Spells:** Delayed Blast Fireball.
- **Finish line:** the pool starts at the slot-scaled base (12d6 + 1d6 per level above 7); each caster turn end while active adds 1d6; any end reason (Concentration break, 1-minute expiry, failed touch save, thrown bead hitting a creature or object) detonates once at the bead's current location with a 20-ft Sphere Dex save for full/half of the accumulated total; flammables ignite; a test covers each end reason and proves no double detonation. Owner: new slice beside S-086/S-087.

### PROPOSED-spells-7: Damage-dealt budget that ends the source

- **Need:** an effect tracks total damage it has dealt (after saves and mitigation) and ends when a cap is reached.
- **Spells:** Guardian of Faith (60 total).
- **Finish line:** each resolved hit adds its final damage to the budget; the effect ends immediately once total ≥ 60 (the last hit is not trimmed); budget survives save/load; a test proves half-damage saves and Resistance count only the damage actually dealt. Owner: new slice beside S-031 damage history.

### PROPOSED-spells-8: Damageable barrier segments with breach residue

- **Need:** a wall is made of independently targetable sections or layers with their own AC, HP, immunities/vulnerabilities or destruction condition; destroying one opens that section only, and may leave a residual area.
- **Spells:** Wall of Ice (AC 12, 30 HP per 10-ft section, Fire vulnerability, frigid-air residue), Wall of Stone (AC 15, 30 HP per inch per panel), Prismatic Wall (ordered layers destroyed by specific damage thresholds or spells).
- **Finish line:** each section/layer is an addressable object with AC/HP/damage modifiers or a declared destruction trigger; damage to one section never spills to another; a destroyed section stops blocking and, if declared, spawns its residue area (Wall of Ice frigid air with first-pass Con 5d6); Prismatic layers can only be destroyed in order; save/load preserves section state; tests cover each of the three spells. Owner: new slice beside S-185/S-186.

## Batch 088-6: movement/travel and visibility (58 spells reviewed)

Scope: every ID with `primary_behavior` of movement_travel (31) or visibility (27). 57 are in SRD 5.2.1 and decomposed; beast_sense is out of milestone. Judgment items are parked as J-10 to J-18 above.

| ID | Avail | Winner | Clauses → classification (owner) |
|---|---|---|---|
| arcane_eye | no | srd_add | Invisible invulnerable eye, sees all directions, Darkvision 30: P (S-187 + S-193). Bonus Action move 30 ft, 1-inch gaps: P (S-180). |
| astral_projection | no | srd_add | Up to 9 to the Astral Plane; bodies Unconscious, no food/air/aging: P (S-178) + E. Silver cord death: H (cut only by named effect). Return on leaving plane; separate damage; 0 HP ends per target; Magic action dismiss: P (S-177/S-178) + E. Data casting time (D-54). |
| banishment | no | srd_add | Cha save, demiplane, Incapacitated, return to space or nearest: P (S-178). Extraplanar types don't return after full minute: P (S-177) + J-12. Upcast targets: E. |
| blink | no | imported | d6 end of turn, 4–6 to Ethereal: E (roll) + P (S-178). Ethereal-only interaction, 60-ft gray sight: P (S-190/S-191). Return start of next turn within 10 ft: P (S-181 shunt). |
| clairvoyance | no | imported | Sensor at familiar/obvious location: P (S-193) + J-15. Seeing or hearing, Bonus Action switch: P (S-193). Visible as orb to See Invisibility/Truesight: P (S-191). 100 GP focus, 10-min cast: E + P (S-216). Data range (D-55). |
| continual_flame | no | imported | Bright 20/Dim 20, no heat, can't be quenched, can be covered: P (S-190) + H (S-070 until dispelled). |
| dancing_lights | yes | imported | Four lights or one Medium form, Dim 10 each: P (S-190). Bonus Action move 60 ft, 20-ft spacing, vanish beyond range: H. |
| darkness | yes | imported | 15-ft Sphere or object Emanation magical Darkness; Darkvision blocked: P (S-190). Covering blocks: H. **Dispels overlapping level ≤2 light:** G (PROPOSED-spells-9). |
| darkvision | yes | imported | Darkvision 150 ft, 8 h: E + H (S-070). |
| daylight | no | imported | 60-ft sunlight Sphere/Emanation: P (S-190). **Dispels overlapping level ≤3 Darkness:** G (PROPOSED-spells-9). |
| demiplane | no | srd_add | Door to 30-ft room; reconnect previous/other's demiplane: P (S-170 containment) + H (persistent created space). End: objects remain, creatures shunted Prone: P (S-181). |
| detect_evil_and_good | yes | imported | Sense listed types and Hallow within 30 ft: P (S-194). Blocked by stone/metal/lead: H (material blocking fact). |
| detect_magic | yes | imported | Sense magic within 30 ft; Magic action to see aura and learn school: P (S-194). Blocking: H. Ritual: E. |
| detect_poison_and_disease | yes | imported | Sense poisons, venomous creatures, contagions and kind: P (S-194/S-195). Blocking: H. |
| dimension_door | no | srd_add | Teleport up to 500 ft to seen/visualized/described point: P (S-177) + J-14. One willing creature within 5 ft: P (S-182). Occupied arrival → 4d6 Force each, fails: H. |
| etherealness | no | srd_add | Border Ethereal, vertical cost ×2: P (S-178) + E (S-179). Ethereal-only interaction, 60-ft gray sight: P (S-190/S-191). Return; occupied → shunt and 2 Force per foot: P (S-181) + H. Upcast 3 targets per level within 10 ft: E. Data duration "Up to 8 hours" (D-56). |
| faerie_fire | yes | imported | 20-ft Cube, Dex save; Dim 10; no Invisible benefit; Advantage if attacker sees: E + P (S-191). |
| feather_fall | no | imported | Reaction on fall; up to 5 creatures; 60 ft/round, no fall damage: P (S-160 + S-181). Data target single (D-57). |
| find_traps | no | imported | Sense presence (not location) and nature of traps in sight: P (S-194) + J-16. |
| fly | yes | imported | Fly 60, hover: E (S-179). Fall when spell ends: P (S-181). Upcast targets: E. |
| fog_cloud | yes | imported | Heavily Obscured Sphere: P (S-190). Strong-wind dispersal: H. Upcast radius: E. |
| freedom_of_movement | yes | srd_add | Ignore Difficult Terrain; magic can't reduce Speed or cause Paralyzed/Restrained: E (S-075). Swim Speed: E. 5 ft to escape nonmagical restraint: E (S-169). Upcast: E. |
| gaseous_form | no | imported | Fly 10 hover, enter others' spaces, narrow openings: P (S-180). BPS Resistance, Prone immunity, Adv Str/Dex/Con saves: E. No talking, objects, attacks or spells: E. Ends at 0 HP or Magic action: E. Data save CON spurious (D-58). |
| gate | no | srd_add | Portal 5–20 ft to a precise plane location; front-only travel: P (S-177). Named-creature summoning: P (S-177) + J-13. Deity prevention: J (covered by J-13 scope). |
| greater_invisibility | no | srd_add | Invisible for duration, not ended by attacking: P (S-191). |
| invisibility | yes | imported | Invisible; ends after attack, damage or spell; upcast: E + P (S-191). |
| jump | yes | imported | Once per turn jump 30 ft for 10 ft movement; upcast: E. |
| leomunds_tiny_hut (Tiny Hut) | no | imported | 10-ft stationary Emanation; fails if too small: H. Present-at-cast pass freely; others barred: P (S-185). Spells ≤3 blocked: P (S-185). Interior light, opaque out / clear in: P (S-190). Ends if caster leaves or recasts: E. Ritual, 8 h: E + H (S-070). |
| levitate | yes | imported | Rise 20 ft; 500-lb object; Con save if unwilling: E + H (object target). Climb-like movement only: E (S-179). Altitude change, Magic action if not self: H (S-148). Float down at end: P (S-181). |
| light | yes | core | Object sheds Bright 20/Dim 20; covering blocks; ends on recast: P (S-190) + E. |
| locate_animals_or_plants | no | imported | Direction and distance to closest kind within 5 miles: P (S-194). |
| locate_creature | no | srd_add | Direction within 1,000 ft; movement direction; known/kind rule; not in other form; lead blocks: P (S-194) + H. |
| locate_object | no | imported | As Locate Creature for objects: P (S-194) + H. |
| magnificent_mansion | no | srd_add | Door, designated entrants, imperceptible when closed: P (S-185) + H. Dwelling up to 50 Cubes; food; 100 servants: H (created space) + J-18. Expel on end: P (S-181). Data range 60 = 300 ft ✓. |
| maze | no | srd_add | Banish to labyrinth; Study action DC 20 Investigation escape; return to space: P (S-178) + E. |
| meld_into_stone | no | imported | Merge with stone; undetectable nonmagically; no sight out, Disadv to hear: P (S-180/S-190). Leave for 5 ft movement: E. Partial destruction 6d6 / full 50 Force, expelled Prone: H (host stone object) + J-17. Data puts 6d6 as primary damage (D-59). |
| mislead | no | srd_add | Invisible, ends on attack/damage/spell: E. Illusory double, Magic action move 2× Speed, see/hear through it: P (S-187 + S-193). |
| misty_step | yes | core | Bonus Action teleport 30 ft to seen space: E. |
| nondetection | no | imported | Creature, place or object can't be targeted by Divination or seen by sensors: P (S-195) + H (S-070). 25 GP consumed: E. |
| pass_without_trace | no | imported | 30-ft Emanation, chosen creatures +10 Stealth, no tracks: E (S-080) + H (tracking fact). |
| plane_shift | no | srd_add | Up to 9 who link hands to another plane; general destination: P (S-177 + S-182) + J-11. Teleportation circle sigil: P (S-177). |
| private_sanctum | no | srd_add | 5–100 ft Cube; chosen properties (sound, vision, sensors, Divination targeting, teleport, planar): P (S-185 + S-190 + S-195 + S-218). 365-day permanence: H (S-070). Upcast size: E. |
| produce_flame | yes | imported | Bright 20/Dim 20 in hand: P (S-190). Magic action ranged spell attack 1d8 Fire; cantrip upgrade: E. |
| reverse_gravity | no | srd_add | 50-ft Cylinder; unanchored fall upward; Dex save to grab; strike ceilings; hover; fall at end: P (S-181) + H (upward-fall direction). Data target single (D-60). |
| rope_trick | no | imported | Rope rises; invisible portal to space for 8 Medium; nothing passes except sight out; drop out at end: P (S-170 + S-185 + S-181). |
| scrying | no | srd_add | Wis save modified by knowledge/connection tables: E (S-038 save modifiers). Success: no reuse for 24 h: E (S-014). Sensor follows target or sits at location: P (S-193). 1,000 GP focus, 10-min cast: E + P (S-216). |
| see_invisibility | yes | imported | See Invisible as visible and into the Ethereal: P (S-191). |
| spider_climb | yes | imported | Walls/ceilings, hands free, Climb Speed: E (S-179). Upcast: E. |
| teleport | no | srd_add | Up to 9 creatures or one object to known destination: P (S-177 + S-182). Familiarity × d100 table → Mishap / Similar Area / Off Target / On Target: P (S-214) + J-10. Mishap 3d10 Force and reroll: P (S-214). Off Target 2d12 miles random direction: P (S-177). |
| teleportation_circle | no | srd_add | Portal to known permanent circle until end of next turn: P (S-177). Two known sigils; learn in 1 min; 365-day permanence: H (S-070) + P (S-219). |
| transport_via_plants | no | srd_add | Link to a seen/touched plant at any distance; 5 ft movement step-through: P (S-177) + H (plant fact). Data duration 10 minutes (D-61). |
| tree_stride | no | srd_add | Enter tree, know same-kind trees within 500 ft, exit within 5 ft, once per turn, end outside: P (S-180) + H (tree fact). |
| true_seeing | yes | srd_add | Truesight 120 ft, 25 GP consumed: E + P (S-191). |
| water_breathing | no | imported | Up to 10 willing breathe underwater, 24 h: P (S-205) + H (S-070). Data target single (D-62). |
| water_walk | yes | imported | Up to 10 move across liquid as solid ground; lava heat still applies; Bonus Action to pass through: E (S-179) + H. Data target single (D-62). |
| wind_walk | no | srd_add | Up to 11 cloud forms: Fly 300 hover, Prone immunity, BPS Resistance: E (S-163). Only Dash or Magic action to revert; revert takes 1 min Stunned: H (timed transformation). End aloft: descend 60 ft/round 1 min then fall: P (S-181). |
| word_of_recall | no | srd_add | Up to 6 within 5 ft teleport to prepared sanctuary; no sanctuary → no effect: P (S-177 + S-182). |
| beast_sense | no | imported | Not in SRD 5.2.1: out of milestone, not decomposed. |

### 088-6 classification summary

- **E:** Speed modes and terrain cost (S-179), Invisible-ending triggers, ritual casting, Resistance/immunity/save Advantage on form changes.
- **P:** this family leans hardest on planned slices.
  - S-177/S-178 destinations, planes and temporary removal (13 spells).
  - S-181 shunts, falls and descents; S-182 group travel; S-180 phasing.
  - S-190/S-191 light, obscurement, Invisible and Truesight (21 spells).
  - S-193 remote sensors; S-194 location-only detection; S-195 masked detection.
  - S-214 Teleport outcome table; S-185 sanctum/hut barriers; S-170 extradimensional containment.
- **H:**
  - Long and permanent durations (S-070).
  - Persistent created spaces (Demiplane, Magnificent Mansion).
  - Material blocking of detection (stone, metal, lead).
  - Covering a light/Darkness source.
  - Object and map-feature hosts (Levitate objects, Meld into Stone, plants and trees).
  - Occupied-arrival damage (Dimension Door, Etherealness).
  - Timed reversion while Stunned (Wind Walk); upward fall direction (Reverse Gravity).
- **G:** one new placeholder, below.
- **J:** parked as J-10 to J-18.

### PROPOSED-spells-9: Level-gated light/Darkness overlap dispel

- **Need:** when a light or Darkness area is created, any overlapping area of the opposite kind created by a spell of a stated level or lower is dispelled.
- **Spells:** Darkness (dispels light from spells of level 2 or lower), Daylight (dispels Darkness from spells of level 3 or lower). Hallow's Darkness/Daylight options use a related "lower than this spell" rule.
- **Finish line:** each light/Darkness area records its kind and source spell level (cast slot, per ADR choice); creating an area checks every overlapping opposite-kind area and ends those at or below the threshold through the normal source-end path (Concentration released, aftermath runs); higher-level areas are untouched; nonmagical light is never dispelled, only suppressed inside magical Darkness; tests cover equal level, one above, partial overlap and object-anchored Emanations. Owner: new slice beside S-190.

## Batch 088-7: objects and social/illusions (44 spells reviewed)

Scope: every ID with `primary_behavior` of objects (26) or social_illusions (18). All 44 are in SRD 5.2.1 and decomposed; none is out of milestone. Long entries were read to their end. New judgment items are parked as J-21 to J-27.

| ID | Avail | Clauses → classification (owner) |
|---|---|---|
| alarm | yes | Ward door/window/≤20-ft Cube; touch or entry alerts: P (S-184). Designated exempt creatures: E. Audible 60 ft or mental ping within 1 mile, wakes sleeper: P (S-218) + H (sleep state). 8 h, ritual: H (S-070) + E. |
| arcane_lock | no | Lock closed door/container; no nonmagical unlock; designated users: H (lock/door object fact). Password opens 1 min: P (S-218). 25 GP consumed: E. Until dispelled: H (S-070). Knock suppresses 10 min: P (S-203). |
| create_food_and_water | no | 45 lb food, 30 gal water; food spoils 24 h: P (S-197 + S-200). |
| create_or_destroy_water | yes | 10 gal create/destroy or rain/fog Cube; rain extinguishes exposed flames; fog removal: P (S-197 + S-190). Upcast gallons/Cube: E. |
| creation | no | Shadow object ≤5-ft Cube, seen form/material: P (S-198/S-199). Material-duration table, shortest wins: P (S-214-like lookup) + H (S-070). Using it as a Material component fails the other spell: H. Upcast Cube: E. |
| druidcraft | no | Weather sensor: G (PROPOSED-spells-10). Bloom, sensory effect: P (S-187). Light/snuff flames: P (S-190). |
| elementalism | no | Air closes unheld doors: H (door state). Earth dust or one written word: P (S-187). Fire embers light candles; Water mist or 1 cup water: P (S-190 + S-197). |
| fabricate | no | Raw materials → product, Large (Medium for mineral); no creatures/magic items; tool proficiency for skilled items: P (S-198/S-199) + J-23. |
| goodberry | yes | Ten berries 24 h; Bonus Action eat: 1 HP and a day's nourishment: P (S-196 + S-200) + E. Uneaten vanish: P (S-086). |
| heat_metal | no | Manufactured metal object in sight; 2d8 Fire to contact; Bonus Action repeat in range: E. Holder/wearer Con save or drop; else Disadv attacks/checks: E + H (worn armor can't drop). Upcast: E. |
| identify | yes | Touch object: magic properties, Attunement, charges, ongoing spells, creating spell; creature: ongoing spells: P (S-194/S-219). 100 GP focus, ritual: E. |
| illusory_script | no | Designated readers see true text; others unintelligible or altered meaning: P (S-218/S-219). Dispel removes both; Truesight reads: P (S-191). 10 days: H (S-070). |
| instant_summons | no | Mark ≤10 lb object; Magic action crush sapphire → object to hand regardless of plane: P (S-177). Held by another → learn holder and location: P (S-194). |
| knock | no | Unlock one mundane lock/stuck/bar: H (lock fact). Arcane Lock suppressed 10 min: P (S-203). Knock audible 300 ft: P (S-218 noise). |
| mage_hand | yes | Hand within 30 ft; manipulate, open, stow, pour; Magic action move 30; ≤10 lb; no attacks: H (object interaction host). Recast ends: E. |
| magic_mouth | no | Message ≤25 words in object; authored trigger; repeat or once: P (S-184 + S-218) + J-21. Until dispelled: H (S-070). 10 GP consumed: E. |
| mending | no | Repair one break ≤1 ft; no magic restoration: P (S-212). |
| move_earth | no | Reshape 40-ft dirt/sand/clay area over 10 min, new area each 10 min; not stone: P (S-179 terrain) + H (elevation map change). |
| nystuls_magic_aura | no | Mask creature type to spells; False Aura for detection: P (S-195). 30 days daily → until dispelled: H (S-070 + counted recasts). |
| passwall | no | 5×8×20-ft passage in wood/plaster/stone, 1 h; eject occupants at end: P (S-180 + S-181) + H (material fact). |
| prestidigitation | yes | Options; up to three non-instantaneous active: E (S-162 group cap). Sensory, fire play, clean/soil, sensation, mark, trinket: P (S-187/S-190) + H (cosmetic object states). |
| purify_food_and_drink | yes | Remove poison/rot in 5-ft Sphere: P (S-200). Ritual: E. |
| secret_chest | no | Chest to Ethereal; Magic action recall/send: P (S-178 + S-196). 60 days then cumulative 5% daily end: P (S-209) + H (S-070). Replica destroyed or recast ends; chest lost on Ethereal: P (S-086). |
| stone_shape | no | Reshape ≤Medium stone or 5-ft section; two hinges and latch: P (S-199) + H (stone material fact). |
| tensers_floating_disk | no | Disk 500 lb, follows within 20 ft, can't cross 10-ft elevation change; overload or 100 ft ends: P (S-196 + S-172) + H (elevation fact). |
| thaumaturgy | no | Options, three 1-minute effects at once: E (S-162). Booming Voice Adv Intimidation: E. Invisible Hand door: H (door state). Others: P (S-187/S-190). |
| disguise_self | no | Self + gear appearance, ±1 ft, same limbs: P (S-187). Fails physical inspection; Study + Investigation vs DC: P (S-188). |
| dream | no | Known target on same plane; messenger Incapacitated Speed 0: E. Converse in dreams while target sleeps: P (S-218) + H (sleep state). Terrifying: Wis save or no rest benefit and 3d6 Psychic on waking: H (rest-blocking). |
| hallucinatory_terrain | no | 150-ft Cube natural terrain looks/sounds/smells different; structures unchanged: P (S-187/S-189). Tactile unchanged → notice: J-27. Study + Investigation disbelief, vague image: P (S-188). 24 h: H (S-070). |
| major_image | no | ≤20-ft Cube image with sound/smell/temperature, no damage; Magic action move: P (S-187). Physical interaction reveals; Study check: P (S-188). Upcast 4+: permanent until dispelled: H (S-070). |
| minor_illusion | yes | Sound or ≤5-ft image; Study check; faint once discerned: P (S-187/S-188). Recast ends: E. |
| mirage_arcane | no | 1-mile terrain including tactile; can create Difficult Terrain: P (S-189 + S-179). Removed pieces vanish; Truesight sees true form but tactile remains: P (S-191). 10 days: H (S-070). |
| modify_memory | no | Wis save, Adv if fighting; Charmed + Incapacitated; ends on damage/spell: E. Memory of ≤10-min event in last 24 h edited: P (S-219) + J-25. Remove Curse/Greater Restoration restores: P (S-202). Upcast window: E. |
| phantasmal_force | no | Int save; phantasm ≤10-ft Cube perceived only by target: P (S-187 + S-190). Study check ends: P (S-188). Target treats as real; 2d8 Psychic per turn if in or within 5 ft of a harmful phantasm: P (S-189). |
| phantasmal_killer | no | Wis save, 4d10 Psychic + Disadv; repeat end-of-turn save, damage again: E (S-068). Upcast: E. |
| programmed_illusion | no | Dormant ≤30-ft Cube scripted 5-min performance; trigger within 30 ft: P (S-184 + S-187) + J-22. 10-min dormancy reactivation: H. Study check: P (S-188). |
| project_image | no | Copy at seen location within 500 miles; see/hear through: P (S-187 + S-193). Damage ends; Magic action move 60: E. Study check: P (S-188). |
| seeming | no | Chosen creatures' appearance, Cha save unwilling: P (S-187). Study check: P (S-188). 8 h: H (S-070). |
| silent_image | no | ≤15-ft Cube visual image; Magic action move: P (S-187). Physical interaction/Study: P (S-188). |
| speak_with_animals | no | Comprehend and talk to Beasts; Influence options; info on last day: P (S-218/S-219). Ritual: E. |
| speak_with_dead | no | Corpse with mouth, not Undead, not within 10 days; five questions; knows only life: P (S-219) + E (S-014 lockout) + J-26. |
| speak_with_plants | no | 30-ft Emanation plants: question on last day: P (S-219). Plant Difficult Terrain to normal or vice versa: E (S-179). Talk with Plant creatures: P (S-218). |
| weird | no | Chosen creatures in 30-ft Sphere: Wis save, 10d10 Psychic + Frightened; end-of-turn repeat 5d10, success ends: E (S-068). |
| zone_of_truth | no | 15-ft Sphere, entry/start-turn Cha save: P (S-184). Can't lie, caster knows result, can be evasive: P (S-218) + J-24. |

### 088-7 classification summary

- **E:** Option menus and active-effect caps (S-162), save/repeat-save damage (S-068), Advantage and Disadvantage riders.
- **P:**
  - S-187 located images and sounds; S-188 Study/Investigation discovery; S-189 tactile illusion realization (Mirage Arcane, Phantasmal Force).
  - S-196/S-197/S-200 contents, liquids and food; S-198/S-199 crafted output (Creation, Fabricate, Stone Shape); S-212 repair (Mending).
  - S-218/S-219 communication and knowledge (Speak with Animals/Dead/Plants, Zone of Truth, Modify Memory, Illusory Script).
  - S-184 triggers (Alarm, Magic Mouth, Programmed Illusion); S-203 lock suppression (Knock).
- **H:** door/lock/window object states; object interaction host for Mage Hand; sleep state (Alarm, Dream); rest-blocking (Dream); map material and elevation facts (Move Earth, Passwall, Stone Shape, Tenser's Floating Disk); long durations (S-070).
- **G:** one new placeholder, below.
- **J:** parked as J-21 to J-27.

### PROPOSED-spells-10: Staged weather state

- **Need:** a located weather fact with ordered stages for precipitation, temperature and wind (with direction), readable by spells and changeable one stage at a time after a delay.
- **Spells:** Control Weather (change one stage per change, 1d4 × 10 min delay, gradual return), Druidcraft Weather Sensor (24-hour forecast display), Call Lightning (storm present, J-05).
- **Finish line:** each outdoor region carries current and forecast stages from the three SRD tables (p.120); a source can request a one-stage change that applies after its rolled delay and is refused indoors; ending the source returns stages gradually; readers get the current stage and a 24-hour forecast; tests cover each table edge (no stage beyond 1 or 5), indoor refusal, delay timing and source end. The starting stage for authored regions is J-38. Owner: new slice; no existing slice covers weather.

## Batch 088-8: summons and all remaining families (77 spells reviewed)

Scope: summons (17), body_death (16), campaign_information (14), weapon_riders (15), wards_removal (9) and exceptional (6). 69 are decomposed. 8 are not in SRD 5.2.1 (milestone `out_of_milestone_non_srd521`, cast_available False) and are identified only: feign_death, blinding_smite, branding_smite, hail_of_thorns, lightning_arrow, thunderous_smite, witch_bolt, wrathful_smite. New judgment items are parked as J-28 to J-43.

| ID | Avail | Clauses → classification (owner) |
|---|---|---|
| animate_dead | yes | Bones/corpse → Skeleton/Zombie: E (S-154). Bonus Action command within 60 ft, same command to all, Dodge default: E (S-156/S-158) + J-41. 24-h control, recast reasserts up to four: H (S-070 + reassert target). Upcast +2 creatures: E (S-155). |
| animate_objects | yes | Objects up to ability modifier (size-weighted) → Animated Object stat block: E (S-154/S-155/S-165). Shares Initiative after yours; Bonus Action command within 500 ft: E (S-156/S-157). 0 HP reverts with carry-over: E (S-166). Upcast Slam: E. |
| arcane_hand | no | Large hand object AC 20, HP = your max, doesn't occupy: P (S-187) + E. Bonus Action move 60 then Clenched Fist 5d8 / Forceful push / Grasping grapple + 4d6 crush / Interposing Half Cover + Difficult Terrain: E (S-168) + P (S-160) + H (cover degree, PROPOSED-spells-1). Upcast: E. |
| arcane_sword | no | Sword; melee spell attack 4d12 + mod; Bonus Action move 30 and repeat: E (S-148). |
| awaken | no | 8-h cast; Beast/Plant Int ≤3 or plant → Int 10 + language: P (S-154) + J-35. Charmed 30 days or until damaged, then chooses attitude: P (S-219) + H (S-070). |
| create_undead | no | Night only: H (time-of-day fact). Up to three Ghouls: E (S-154). Bonus Action command within 120 ft: E (S-156) + J-41 analogue. 24-h reassert; upcast Ghasts/Wights/Mummies: H (S-070) + E (S-155). |
| faithful_hound | no | Invisible-to-others intangible hound; Truesight 30: P (S-187/S-191). Barks at unpassworded Small+ within 30 ft: P (S-184 + S-218). Start-of-turn bite Dex save 4d8 Force: E. Magic action move 30; ends beyond 300 ft: E. |
| find_familiar | yes | Familiar CR 0 Beast form as Celestial/Fey/Fiend: E (S-154). Telepathy 100 ft; Bonus Action borrow senses: P (S-193). Touch-spell delivery by Reaction: P (S-192 + S-160). Own Initiative, can't attack: E (S-157). Dismiss to pocket dimension and recall: P (S-178). One familiar only, recast changes form: E (S-162). |
| find_steed | yes | Otherworldly Steed stat block by spell level and type: E (S-154). Controlled mount sharing Initiative; independent when you're Incapacitated: E (S-157/S-158) + H (mounted combat). Disappears at 0 HP or your death; resummon choice: E (S-162). Life Bond healing: H. |
| giant_insect | no | Centipede/Spider/Wasp stat block by level: E (S-154). After-your-turn, verbal commands, Dodge default: E (S-156/S-157). |
| phantom_steed | no | Riding Horse with Speed 100, 13 miles/hour; equipment vanishes 10 ft away: E (S-154) + H (overland travel pace). Ends on damage; 1-minute fade: E + P (S-086). |
| planar_ally | no | Known entity sends Celestial/Elemental/Fiend: P (S-154) + J-36. Service bargained for payment by duration tiers: P (S-219) + H (payment negotiation host). Returns on completion or no agreement: P (S-178). |
| planar_binding | no | Creature in range for 1-hour cast; Cha save or bound 24 h; summoning spell extended: E + P (S-141). Follows commands; Hostile twists them: J-37. Report back on completion: H. Upcast 10/30/180/366 days: H (S-070). |
| simulacrum | no | 12-h cast; copy of Beast/Humanoid as Construct at half HP max; can't cast Simulacrum: E (S-154/S-161). Obeys, acts on your turn: E (S-157). No levels/rests; HP only by Long Rest repair at 100 GP/HP: H (paid repair). 0 HP melts; recast destroys previous: E (S-162). |
| spiritual_weapon | no | Bonus Action; melee spell attack 1d8 + mod; Bonus Action move 20 and repeat: E (S-148). Upcast: E. |
| summon_dragon | no | Draconic Spirit stat block by level; after-your-turn; verbal commands, Dodge default: E (S-154/S-156/S-157). |
| unseen_servant | no | Invisible Medium force AC 10, 1 HP, Str 2, can't attack: E (S-154). Bonus Action command move 15 + interact; simple tasks; ends beyond 60 ft: E (S-156) + H (object interaction host, as Mage Hand). |
| alter_self | yes | Aquatic Adaptation: Swim Speed + water breathing: E (S-179) + P (S-205). Change Appearance: P (S-187/S-188). Natural Weapons 1d6 Unarmed Strike with spell mod: E (S-126). Magic action swap option: E. |
| animal_shapes | no | Any number of willing creatures → Large-or-smaller Beast CR ≤4, retaining type/HP/mental scores; Temp HP = first form's HP: E (S-163/S-164). Magic action re-form; Bonus Action end; 24 h: E + H (S-070). |
| clone | no | 1-h cast; inert clone grows 120 days, chosen age: P (S-208) + H (S-070). Soul transfers on death if free and willing: P (S-175). Original remains can't be revived: P (S-175). |
| feign_death | no | Not in SRD 5.2.1: out of milestone, not decomposed. |
| gentle_repose | yes | Corpse protected from decay and Undead; days don't count toward revival limits: P (S-175 + S-064 paused time). 10 days, ritual: H (S-070) + E. |
| imprisonment | no | Wis save, 24-h immunity on success: E (S-014). Imprisoned needs no air/food, untargetable by Divination, no teleport: P (S-195) + E. Burial / Chaining / Hedged Prison / Minimus Containment / Slumber options: P (S-170/S-178/S-185) + E. Authored end trigger: J-43. Dispel only at level 9 on prison or component: G (PROPOSED-spells-11 threshold). |
| magic_jar | no | Soul in container; project 100 ft to return or possess Humanoid (Cha save, 24-h lockout; warded creatures immune): P (S-173/S-174) + E (S-014). Host stats swap (HP, physical scores, Speed, senses): P (S-173). Host death Cha save to return or die; container destroyed: P (S-174 + S-086). |
| polymorph | no | Wis save; Beast CR ≤ target's CR or level; retain alignment/personality/type/HP: E (S-163). Temp HP = form HP; ends when Temp HP gone: E (S-163). Gear melds: E (S-164). |
| raise_dead | no | 1-h cast; dead ≤10 days, not Undead: P (S-175). 1 HP, neutralize poisons, close wounds, no missing parts: P (S-176 + S-206). −4 D20 Tests, −1 per Long Rest: P (S-176). |
| reincarnate | no | Dead Humanoid ≤10 days; new body, d10 species table: P (S-175 + S-214) + J-34. Species traits swapped, capabilities kept: H (species swap on a Character). |
| resurrection | no | Dead ≤ a century, not old age, not Undead; full HP; restore parts: P (S-175/S-176 + S-206/S-207). −4 penalty: P (S-176). ≥365 days dead: caster can't cast and Disadv on D20 Tests until Long Rest: H (caster aftermath). |
| revivify | yes | Died within last minute; 1 HP; not old age or missing parts: P (S-175/S-176). |
| sequester | no | Object or willing creature Invisible, unaffected by Divination and remote viewing: P (S-191/S-195). Creature suspended (Unconscious, no aging/food/air): E + P (S-208). Authored end condition within 1 mile: J-40. Ends on damage: E. |
| shapechange | no | Form CR ≤ your level, seen before, not Construct/Undead; retain mental scores, HP, proficiencies, Spellcasting: E (S-163). Temp HP of first form; Magic action re-form: E. Equipment drops or resizes: E (S-164). |
| true_polymorph | no | Creature→creature, creature→object, object→creature (CR ≤9, Friendly, after your turn): E (S-163/S-165/S-154). Full-duration Concentration → until dispelled: H (concentration-completion permanence). Over an hour, object-creature control lapses: P (S-158). Wis save unwilling: E. |
| true_resurrection | no | Dead ≤200 years, not old age; full HP; cure contagions, curses, restore parts, un-Undead: P (S-175/S-176 + S-202 + S-206/S-207). New body by name, appears within 10 ft: P (S-175) + H. |
| animal_messenger | yes | Tiny Beast Cha save (auto-succeed if CR >0, as written): E. Travel to visited location, 25 or 50 miles/day, describe recipient, 25-word message: P (S-177 + S-218) + H (overland travel). Upcast +48 h: E (S-141). |
| augury | no | Omen for course within 30 min from Omens table: P (S-214/S-219) + J-28. Cumulative 25% no answer after first cast per Long Rest: P (S-209). |
| commune | no | Three yes/no questions answered correctly: P (S-219) + J-29. Cumulative 25%: P (S-209). |
| commune_with_nature | no | 3 miles outdoors, 300 ft underground, fails in construction: H (map setting fact). Choose three facts (settlements, portals, CR 10+ creature, prevalent kind, water): P (S-194/S-219) + J-33. |
| comprehend_languages | no | Understand heard/signed/touched written language; 1 min per page; no codes: P (S-218). |
| contact_other_plane | no | DC 15 Int save; success: five one-word answers: P (S-219) + J-30. Failure: 6d6 Psychic and Incapacitated until Long Rest; Greater Restoration ends: E + H (until-rest condition). |
| detect_thoughts | no | Sense Thoughts within 30 ft, blocked by stone/metal/lead: P (S-195) + H (material blocking). Read surface thought: P (S-219). Probe: Wis save; target's Arcana check action to end: E. |
| divination | no | One question about the next 7 days; truthful reply: P (S-219) + J-31. Cumulative 25%: P (S-209). 25 GP consumed: E. |
| find_the_path | no | Familiar location on same plane; direction, distance, and most direct path at choices: P (S-177 + S-194) + H (route graph). Fails for other plane, moving or unspecific destinations: P (S-177). |
| legend_lore | no | Famous person/place/object → lore summary; precision by prior knowledge; not famous → fails: P (S-219) + J-32. |
| message | yes | Whisper to creature within 120 ft and whispered reply: P (S-218). Through barriers if familiar; blocked by magical silence, 1 ft stone/metal/wood, lead: P (S-218) + H (material blocking). |
| sending | no | 25 words to a met or described creature, any distance and plane, 5% cross-plane failure, block for 8 h: P (S-218) + E. |
| telepathic_bond | no | Up to eight willing creatures with a language; telepathy at any distance, same plane: P (S-218). |
| tongues | no | Understand any language; be understood by any language-user: P (S-218). |
| befuddlement | no | Int save; 10d12 Psychic, can't cast or take Magic action; half on success: E. Repeat save every 30 days: P (S-068) + H (S-070). Ended by Greater Restoration, Heal, Wish: P (S-202-like removal list). |
| contingency | no | Store a level ≤5 action-cast self-targeting spell with both slots spent: P (S-150/S-151). Authored trigger fires once, self only: P (S-184) + J-39. One at a time; ends if statuette not on person: E (S-162) + H (carried-component check). |
| control_weather | no | Outdoors only, 5 miles; stage changes after 1d4 × 10 min; gradual return: G (PROPOSED-spells-10) + J-38. |
| forcecage | no | Invisible cage (20 ft bars) or box (10 ft solid, blocks spells): P (S-185/S-186). Partial occupants pushed out: P (S-186). Teleport/planar exit needs Cha save, wastes on failure: P (S-185). Extends to Ethereal; can't be dispelled by Dispel Magic: P (S-185) + G (PROPOSED-spells-11 exemption). |
| time_stop | no | 1d4 + 1 consecutive turns: P (S-159). Ends if you affect another creature or their gear, or move >1,000 ft: H (affect-other detection). |
| wish | no | Duplicate any level ≤8 spell without requirements: P (S-221 + S-222). Listed effects (Object Creation, Instant Health, Resistance, Spell Immunity, Sudden Learning, Roll Redo): P (S-221) + P (S-215 Roll Redo). Reshape Reality: J-42. Stress: 1d10 Necrotic per spell level until Long Rest, Str 3 for 2d4 days, 33% lose Wish: P (S-221). |
| blinding_smite | no | Not in SRD 5.2.1: out of milestone, not decomposed. |
| branding_smite | no | Not in SRD 5.2.1: out of milestone, not decomposed. |
| divine_smite | yes | Bonus Action after melee or Unarmed hit: P (S-160 + S-021). +2d8 Radiant, +1d8 vs Fiend/Undead: E (S-003). Upcast: E. |
| dragons_breath | no | Touch willing creature; chosen damage type; Magic action 15-ft Cone Dex save 3d6: E (S-012). Upcast: E. |
| ensnaring_strike | no | Bonus Action after weapon hit: P (S-160). Str save (Large+ Advantage) or Restrained; 1d6 Piercing each turn start; Athletics check action ends: E (S-068 + S-169). Upcast: E. |
| flame_blade | no | Blade in free hand; Bonus Action re-evoke; Magic action melee spell attack 3d6 + mod: E. Light 10/10: P (S-190). Upcast: E. |
| hail_of_thorns | no | Not in SRD 5.2.1: out of milestone, not decomposed. |
| lightning_arrow | no | Not in SRD 5.2.1: out of milestone, not decomposed. |
| searing_smite | no | Bonus Action after hit: P (S-160). +1d6 Fire; start-of-turn 1d6 then Con save to end: E (S-068). Upcast all damage: E. |
| shining_smite | no | Bonus Action after hit: P (S-160). +2d6 Radiant; target sheds light 5 ft, attacks have Advantage, no Invisible benefit: E + P (S-190/S-191). Upcast: E. |
| thunderous_smite | no | Not in SRD 5.2.1: out of milestone, not decomposed. |
| true_strike | yes | One attack with the component weapon using spellcasting ability; Radiant or normal type: E (S-126). Cantrip upgrade extra Radiant: E. |
| vampiric_touch | no | Melee spell attack 3d6 Necrotic; heal half dealt: E (S-017). Magic action repeat: E. Upcast: E. |
| witch_bolt | no | Not in SRD 5.2.1: out of milestone, not decomposed. |
| wrathful_smite | no | Not in SRD 5.2.1: out of milestone, not decomposed. |
| counterspell | yes | Reaction on seeing V/S/M casting within 60 ft: P (S-160). Con save or spell dissipates; action wasted; slot not expended: E (S-142). |
| dispel_evil_and_good | no | Disadv on attacks from five creature types: E. Break Enchantment (possession, Charmed, Frightened from those types): P (S-174) + E. Dismissal Cha save → home plane, Shadowfell or Feywild: P (S-177/S-178). |
| dispel_magic | no | End ongoing spells of level ≤3 on a creature, object or effect; check DC 10 + level for higher; upcast raises auto threshold: G (PROPOSED-spells-11). |
| globe_of_invulnerability | no | 10-ft immobile Emanation; spells of level ≤5 from outside have no effect inside and areas exclude it: P (S-185) + G (PROPOSED-spells-11 level threshold). Upcast threshold: E. |
| greater_restoration | no | Remove one: 1 Exhaustion level, Charmed or Petrified, a curse including attunement, ability score reduction, HP maximum reduction: P (S-202) + E (S-129-like reduction removal). 100 GP consumed: E. |
| lesser_restoration | no | Bonus Action touch: end Blinded, Deafened, Paralyzed or Poisoned: E. |
| remove_curse | yes | End all curses on a creature or object; cursed item keeps curse but attunement breaks: P (S-202). |
| resilient_sphere | yes | Large-or-smaller creature/object; Dex save if unwilling; nothing passes, immune to damage, breathable: P (S-170/S-185). Push to roll at half Speed; carried by others: P (S-172). Disintegrate destroys it: H (named-spell interaction). |
| silence | no | 20-ft Sphere: no sound, Thunder Immunity, Deafened, no Verbal components: P (S-190 + S-218) + E. Ritual: E. |

### 088-8 classification summary

- **E:** created actors, commands and Dodge defaults (S-154–S-158); forms (S-163–S-166); interruption with slot refund (S-142, Counterspell); repeat saves (S-068); condition removal (Lesser and Greater Restoration).
- **P:** revival (S-175/S-176) and age (S-208, Clone); possession (S-173/S-174, Magic Jar); copies (S-161, Simulacrum); inserted turns (S-159, Time Stop); stored spells (S-150/S-151, Contingency); Reaction budget (S-160) for smites and Counterspell; weapon post-roll riders (S-021); barriers (S-185/S-186, Forcecage, Globe, Resilient Sphere); communication and knowledge (S-218/S-219/S-220); curses (S-202); Wish (S-221).
- **H:** time-of-day facts (Create Undead); overland travel pace (Animal Messenger, Phantom Steed); mounted combat (Find Steed); material blocking for thought and message (Detect Thoughts, Message); species swap (Reincarnate); until-rest conditions (Contact Other Plane); paid repair (Simulacrum); payment negotiation (Planar Ally); affect-other detection (Time Stop).
- **G:** PROPOSED-spells-11 below. Control Weather uses PROPOSED-spells-10 from 088-7.
- **J:** parked as J-28 to J-43.

### PROPOSED-spells-11: Level-gated spell ending and spell-level thresholds

- **Need:** a shared rule that reads the level of an ongoing spell effect and either ends it automatically (at or below a threshold) or asks for an ability check against DC 10 + that level; the same level reading also powers exemptions and thresholds.
- **Spells:** Dispel Magic (level ≤3 auto, check above, upcast raises threshold), Globe of Invulnerability (level ≤5 from outside has no effect, upcast), Imprisonment (only a level 9 Dispel Magic on prison or component), Forcecage (can't be dispelled by Dispel Magic), and the level-limited light/Darkness overlap of PROPOSED-spells-9.
- **Finish line:** every ongoing spell effect records its cast level; a dispel request on a creature, object or magical effect lists its effects, ends each at or below the slot-scaled threshold, and rolls the caster's spellcasting-ability check vs DC 10 + level for each one above it; effects can declare "not dispellable" or "dispellable only at level N and on target X"; Globe filters incoming spells by level and source position; tests cover threshold edges (3/4, upcast 5), each declared exemption, partial success across several effects, and the PROPOSED-spells-9 overlap. Owner: new slice; S-203 covers suppression only.

## Final reconciliation (Batch 088)

**Totals by batch**

| Batch | Families | Reviewed | Decomposed | Out of milestone |
|---|---|---|---|---|
| 088-1 to 088-6 | direct_resolution, control, timed_effects, visibility and the other families named in those sections | 241 | 226 | 15 |
| 088-7 | objects, social_illusions | 44 | 44 | 0 |
| 088-8 | summons, body_death, campaign_information, weapon_riders, wards_removal, exceptional | 77 | 69 | 8 |
| **Total** | | **362** | **339** | **23** |

**Coverage:** 362 of 362 unique loaded IDs (100%) inventoried and decomposed or marked out of milestone. No spell is certified by this audit.

**New gaps vs planned slices**

- Planned slices cover most clauses: S-142, S-154–S-166 and S-202 are already verified; S-021, S-150/S-151, S-159–S-162, S-173–S-176, S-185–S-190, S-197–S-200, S-208, S-212, S-218–S-221 are planned owners.
- 11 new gaps, none owned by a planned slice: PROPOSED-spells-1 to PROPOSED-spells-11. In 088-7 and 088-8: PROPOSED-spells-10 (staged weather state) and PROPOSED-spells-11 (level-gated spell ending and thresholds, which also absorbs the dispel side of PROPOSED-spells-9).
- Host facts still missing (H) and repeated across batches: door/lock states, sleep and rest-blocking, long durations (S-070), map material and elevation, overland travel, mounted combat, species swap.

**Defects recorded:** D-01 to D-80 (data vs SRD; recorded, not corrected). Most common in 088-8: long casting times stored as `action` (D-67 to D-73).

**Parked ADR-0023 judgment items:** J-01 to J-43, each with verbatim SRD 5.2.1 clause and page.

**Recommended next queue**

1. Data-correction job for D-01 to D-80 (separate owner and review; then regenerate spell_status.json through its normal path).
2. ADR-0023 decision pass on J-01 to J-43, grouping by theme: GM-authored triggers (J-21, J-22, J-39, J-40, J-43), divination answers (J-28 to J-33), summoned-creature attitude and bargaining (J-35 to J-37, J-41), illusion and terrain judgment.
3. Import Gate integration of PROPOSED-spells-1 to PROPOSED-spells-11 into the vocabulary slice plan (by the plan's owner; this audit did not edit shared files).
4. Host-fact slices for door/lock, sleep/rest and long durations (S-070), which unblock the most H clauses.
5. Re-audit affected spells as each planned slice lands, starting with S-187–S-189 and S-218/S-219.

## Duplicate-definition accuracy: imported_spells.json vs srd_additional_spells.json

31 IDs are defined in both files. imported_spells.json wins 30 of them; mass_healing_word is won by conversion_batch_001.json, so it falls outside the 30. I compared each against the SRD 5.2.1 header and text (casting time, range in 5-ft hexes, target/area, save, damage type, Concentration, upcast and effects). A **DEFECT** is a winner that is less accurate than the loser. Many of these spells are available through native per-ID code, which may override the record; that override is unverified, so the records are still listed.

| ID | More accurate | Deciding differences (SRD 5.2.1) | Defect? |
|---|---|---|---|
| barkskin | srd_add | SRD Bonus Action (imported: action) | DEFECT |
| beacon_of_hope | srd_add | no save in SRD (imported: WIS) | DEFECT |
| blindness/deafness | srd_add | 120 ft = 24 (imported: 6); upcast targets; condition choice | DEFECT |
| blur | srd_add | effect authored; fields otherwise equal | DEFECT (minor) |
| cloud_of_daggers | n/a | not in SRD 5.2.1 | — |
| conjure_animals | srd_add | 2024 pack: Dex save 3d10 Slashing (imported: plain single target). The srd_add sphere is still an approximation | DEFECT |
| darkness | srd_add | 15-ft radius = 3 | DEFECT (minor) |
| darkvision | srd_add | effect authored | DEFECT (minor) |
| detect_evil_and_good | srd_add | effect authored | DEFECT (minor) |
| detect_magic | srd_add | effect authored; neither marks Ritual | DEFECT (minor) |
| detect_poison_and_disease | srd_add | effect authored; neither marks Ritual | DEFECT (minor) |
| divine_favor | equal | identical fields | — |
| enhance_ability | srd_add | imported carries a spurious 2d6 force damage; srd_add has upcast targets | DEFECT |
| entangle | srd_add | 20-ft square area + Restrained (imported: single) | DEFECT |
| faerie_fire | srd_add | 20-ft Cube area authored | DEFECT (minor) |
| fog_cloud | srd_add | 20-ft radius + upcast radius | DEFECT (minor) |
| goodberry | srd_add | Range Self (imported: 1/touch) | DEFECT |
| grease | srd_add | 10-ft square + Prone (imported: single) | DEFECT |
| heroism | srd_add | upcast targets | DEFECT (minor) |
| identify | equal | identical; neither marks Ritual | — |
| invisibility | srd_add | upcast targets + effect | DEFECT (minor) |
| magic_weapon | **imported** | SRD Bonus Action, 1 hour, no Concentration. srd_add has action + Concentration, and its bonus map (+2 at slot 4) is wrong against SRD (+2 at slots 3–5, +3 at 6+) | — (winner more accurate) |
| moonbeam | srd_add | 5-ft radius + upcast | DEFECT (minor) |
| plant_growth | srd_add | 100-ft radius area | DEFECT (minor) |
| sanctuary | **imported** | the SRD warding works through an attacker's Wis save; imported keeps WIS, srd_add blanks it | — |
| see_invisibility | srd_add | effect authored | DEFECT (minor) |
| shatter | srd_add | 10-ft radius + upcast | DEFECT (minor) |
| sleet_storm | srd_add | 20-ft-radius Cylinder + Prone (Concentration loss absent in both) | DEFECT (minor) |
| spike_growth | srd_add | **Piercing** (imported: force) + 20-ft radius | DEFECT |
| spirit_guardians | srd_add | Range Self emanation (imported: single at 3) | DEFECT |

**Totals:** 25 cases where the winner is less accurate: 12 material, 13 minor (missing area/effect/upcast fields only). 2 where the winner is more accurate (magic_weapon, sanctuary). 2 equal. 1 not in SRD.

## Running defect table (data not changed)

Cumulative across batches. Batch tag = where the defect was recorded. For the 088-3 duplicate-winner defects, see the table above.

| # | Batch | ID | Field | Loaded (winner) | SRD 5.2.1 |
|---|---|---|---|---|---|
| D-01 | 088-2 | chromatic_orb | target | area | one creature |
| D-02 | 088-2 | flame_strike | damage | 10d6 fire | 5d6 Fire + 5d6 Radiant |
| D-03 | 088-2 | ice_storm | damage | missing cold packet | 2d10 Bludgeoning + 4d6 Cold |
| D-04 | 088-2 | lightning_bolt | target | single | 100 ft × 5 ft Line |
| D-05 | 088-2 | mass_heal | heal | 700 to one | 700 divided among creatures |
| D-06 | 088-2 | prayer_of_healing | casting_time/target | minute / single | 10 minutes / up to five |
| D-07 | 088-2 | prismatic_spray | damage | single 12d6 fire | per-target 1d8 ray table |
| D-08 | 088-2 | fire_storm, divine_word | effects | none authored | see 088-2 rows |
| D-09 | 088-1/2 | 7 class lists | spell_list_ids | see class table | SRD headers |
| D-10 | 088-3 | dissonant_whispers | damage_type | fire | Psychic |
| D-11 | 088-3 | command | target_creature_type_exclusions | undead | no type exclusion in SRD 5.2.1 |
| D-12 | 088-3 | enthrall | duration/concentration | "1 minute", false | Concentration, up to 1 minute |
| D-13 | 088-3 | slow | save / target | DEX / single | Wisdom / up to six in a 40-ft Cube |
| D-14 | 088-3 | hypnotic_pattern | target | single | 30-ft Cube |
| D-15 | 088-3 | fear | range/area | 6, cone without size | Self, 30-ft Cone |
| D-16 | 088-3 | compulsion | target | single | each chosen creature in range |
| D-17 | 088-3 | antipathy_sympathy | casting_time | action | 1 hour |
| D-18 | 088-3 | dominate_monster | condition_duration | 10 rounds | Concentration, up to 1 hour |
| D-19 | 088-3 | confusion | area | no radius/upcast | 10-ft Sphere, +5 ft per slot |
| D-20 | 088-3 | calm_emotions | area | no radius | 20-ft Sphere, Humanoids only |
| D-21 | 088-3 | tashas_hideous_laughter | upcast | none | +1 creature per slot |
| D-22 | 088-3 | web, bestow_curse | damage fields | 2d4 fire / 1d8 necrotic as base damage | conditional riders only |
| D-23 | 088-3 | 25 duplicate IDs | winner | imported_spells.json | srd_additional closer (see table) |
| D-24 | 088-4 | telekinesis | SRD source | — | SRD 5.2.1 p.168 sentence ends "simple tool," (source truncation; J, not data) |
| D-25 | 088-4 | magic_weapon | runtime (known_limit) | Magic Action, Concentration, +1 at slots 2–3, +2 at 4–5 | Bonus Action, no Concentration (1 hour), +2 at 3–5, +3 at 6+ |
| D-26 | 088-4 | blade_ward | cast_available | true | not in SRD 5.2.1 (out of milestone yet castable) |
| D-27 | 088-4 | enlarge/reduce | damage | 1d4 force base damage | no base damage; ±1d4 weapon/Unarmed rider |
| D-28 | 088-4 | haste | save | DEX | no save (target gets Dex-save Advantage) |
| D-29 | 088-4 | beacon_of_hope | save / target | WIS / single | no save / any number of creatures |
| D-30 | 088-4 | heroes_feast | casting_time / target | minute / self | 10 minutes / up to twelve partakers |
| D-31 | 088-4 | fire_shield | damage_type | fire only | Fire (warm) or Cold (chill), caster's choice |
| D-32 | 088-4 | barkskin | casting_time | action | Bonus Action |
| D-33 | 088-4 | heroism / enhance_ability | upcast | none | one additional target per slot level above base |
| D-34 | 088-4 | mirror_image / holy_aura / foresight / mind_blank / stoneskin | effects | none | SRD effects not encoded (record only) |
| D-35 | 088-4 | hex | upcast | none | Concentration 4 h (L2), 8 h (L3–4), 24 h (L5+) |
| D-36 | 088-4 | regenerate | casting_time | runtime approximates 1 minute as an action (known_limit) | 1 minute |
| D-37 | 088-5 | call_lightning | upcast | none | +1d10 per slot level above 3 |
| D-38 | 088-5 | conjure_animals | target / damage | single / none | Large pack; Dex 3d10 Slashing |
| D-39 | 088-5 | delayed_blast_fireball | area | `line`, 2 points | 20-ft-radius Sphere at one point |
| D-40 | 088-5 | earthquake | damage / save | 12d6 Bludgeoning, Dex half on main save | main Dex save → Prone + Concentration broken; 12d6 only from collapse |
| D-41 | 088-5 | forbiddance | casting_time / target / damage | minute / single / none | 10 minutes or Ritual / area / 5d10 Radiant or Necrotic |
| D-42 | 088-5 | glyph_of_warding | damage_type | fire | Acid, Cold, Fire, Lightning or Thunder (chosen) |
| D-43 | 088-5 | guards_and_wards | casting_time | action | 1 hour |
| D-44 | 088-5 | gust_of_wind | range / target | 12 (60 ft) / single | Self / 60-ft×10-ft Line |
| D-45 | 088-5 | hallow | casting_time | action | 24 hours |
| D-46 | 088-5 | prismatic_wall | save / damage | CON half on 12d6 Fire | Con save → Blinded; layers use Dex saves, seven effects |
| D-47 | 088-5 | spike_growth | damage_type | force | Piercing |
| D-48 | 088-5 | storm_of_vengeance | half_on_save | true | failed save: 2d6 + Deafened; success: nothing |
| D-49 | 088-5 | symbol | effects | Death only (10d10 Necrotic) | six selectable effects |
| D-50 | 088-5 | wall_of_force / wall_of_stone | target | single | wall/panels |
| D-51 | 088-5 | wall_of_thorns | upcast | none | +1d8 both damage types per level above 6 |
| D-52 | 088-5 | wind_wall | damage | 3d8 Force | 4d8 Bludgeoning |
| D-53 | 088-5 | cloud_of_daggers | cast_available | true | not in SRD 5.2.1 (out of milestone yet castable) |
| D-54 | 088-6 | astral_projection | casting_time / target | action / single | 1 hour / caster + up to eight |
| D-55 | 088-6 | clairvoyance | range | 1 (5 ft) | 1 mile |
| D-56 | 088-6 | etherealness | duration | 8 hours | Up to 8 hours |
| D-57 | 088-6 | feather_fall | target | single | up to five falling creatures |
| D-58 | 088-6 | gaseous_form | save | CON | no save (willing) |
| D-59 | 088-6 | meld_into_stone | damage | 6d6 Force as primary | 6d6 only on partial destruction; 50 on complete |
| D-60 | 088-6 | reverse_gravity | target | single | 50-ft-radius, 100-ft Cylinder |
| D-61 | 088-6 | transport_via_plants | duration | 10 minutes | 1 minute |
| D-62 | 088-6 | water_breathing / water_walk / teleport / plane_shift / word_of_recall | target | single | groups (10 / 10 / 9 / 9 / 6) |
| D-63 | 088-7 | dream | range | 0 (self) | Special |
| D-64 | 088-7 | mirage_arcane | range | 20 (100 ft) | Sight |
| D-65 | 088-7 | phantasmal_force | duration / concentration / damage | missing / missing / 1d6 | Concentration, up to 1 minute / true / 2d8 Psychic |
| D-66 | 088-7 | speak_with_plants | range | 6 (30 ft) | Self (30-foot Emanation) |
| D-67 | 088-8 | clone | casting time | action | 1 hour |
| D-68 | 088-8 | raise_dead | casting time | action | 1 hour |
| D-69 | 088-8 | resurrection | casting time | action | 1 hour |
| D-70 | 088-8 | true_resurrection | casting time | action | 1 hour |
| D-71 | 088-8 | awaken | casting time | action | 8 hours |
| D-72 | 088-8 | planar_binding | casting time | action | 1 hour |
| D-73 | 088-8 | simulacrum | casting time | action | 12 hours |
| D-74 | 088-8 | lesser_restoration | casting time | action | Bonus Action |
| D-75 | 088-8 | animal_shapes | target | single | Any number of willing creatures |
| D-76 | 088-8 | telepathic_bond | target | single | Up to eight willing creatures |
| D-77 | 088-8 | sending | range | 1 | Unlimited |
| D-78 | 088-8 | dragons_breath | target | area | One willing creature touched |
| D-79 | 088-8 | find_steed | duration | missing | Instantaneous |
| D-80 | 088-8 | divine_smite | duration | missing | Instantaneous |

## Known limits of this pass

- 0 of 362 IDs are unreviewed. Decomposition is per clause, not a playtest; classifications are owner mappings, not verified behavior.
- All 339 headers parsed from column-split text (088-2). Prismatic Spray row 8 and the Divine Word table were re-read on rendered pages in 088-3; both are complete. The Telekinesis tail was re-read on rendered p.168 in 088-4: the SRD sentence itself stops at "simple tool," (source truncation, D-24).
- `get_registry_hash()` isn't a hash. I recorded a SHA-256 of it. Changing it is runtime work and out of scope.
- No Windows supported-runner export was possible from the box.

## Recommended next queue

1. Windows export: optional confirmation (not blocking these batches).
2. Data-correction job (content lane) for the running defect table D-01 to D-80, field by field toward the SRD text.
3. Batch 088 is done; see Final reconciliation for the next queue.
4. Later: movement, visibility, objects, summons and utility families, where real gaps (`PROPOSED-spells-N`) are likeliest.
