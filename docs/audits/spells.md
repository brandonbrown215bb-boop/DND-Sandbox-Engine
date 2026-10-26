# Spell inventory and rules-vocabulary audit (Batch 088)

**Status: PARTIAL AUDIT. Inventory is complete. Clause decomposition covers 93 of 362 unique loaded spell IDs (25.7%): 87 decomposed, 6 out-of-milestone IDs identified only. Families covered so far: direct_resolution (52) and control (41). The other 269 are UNREVIEWED.** This is not a complete audit. Nothing here enables, converts or certifies a spell. Accepted slice counts and checkpoint acceptance are unchanged.

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
| telekinesis | no | srd_add | Magic action each turn, may switch targets: H (S-148). Creature: Str save or move 30 ft, Restrained until end of next turn, suspended then falls: H (S-168) + P (S-181 fall). Object: unattended moves automatically; worn/carried needs a Str save: H (object host). Fine manipulation: J. **Extract tail cut off at a column break after "simple tool,". Re-read p.167–168 before conversion.** |
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

## Known limits of this pass

- 269 of 362 IDs are unreviewed for clauses. Families in spell-status.md remain the planning grouping.
- All 339 headers parsed from column-split text (088-2). Prismatic Spray row 8 and the Divine Word table were re-read on rendered pages in 088-3; both are complete. The Telekinesis tail is still cut off.
- `get_registry_hash()` isn't a hash. I recorded a SHA-256 of it. Changing it is runtime work and out of scope.
- No Windows supported-runner export was possible from the box.

## Recommended next queue

1. Windows export: optional confirmation (not blocking these batches).
2. Data-correction job (content lane) for the running defect table D-01 to D-23.
3. 088-4: timed_effects (45) and persistent_areas (45) families.
4. 088-5+: movement, visibility, objects, summons and utility families, where real gaps (`PROPOSED-spells-N`) are likeliest.
