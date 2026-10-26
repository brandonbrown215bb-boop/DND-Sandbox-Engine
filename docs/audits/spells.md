# Spell inventory and rules-vocabulary audit (Batch 088)

**Status: PARTIAL AUDIT. Inventory is complete. Clause decomposition covers 52 of 362 unique loaded spell IDs: 50 decomposed plus 2 out-of-milestone IDs identified only, all in the immediate attack/save/healing family. The other 310 are UNREVIEWED.** This is not a complete audit. Nothing here enables, converts or certifies a spell. Accepted slice counts and checkpoint acceptance are unchanged.

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

## Known limits of this pass

- 310 of 362 IDs are unreviewed for clauses. Families in spell-status.md remain the planning grouping.
- All 339 headers parsed from column-split text (088-2). Prismatic Spray row 8 and the end of the Divine Word table may be cut off at a column break. Re-read the PDF page before converting.
- `get_registry_hash()` isn't a hash. I recorded a SHA-256 of it. Changing it is runtime work and out of scope.
- No Windows supported-runner export was possible from the box.

## Recommended next queue

1. Brandon runs the Windows export (`scripts/invoke_godot_case.ps1`, Scene mode) and compares it with this SHA-256 and these totals.
2. Data-correction job (content lane) for the 7 record defects and 7 class-membership defects cited here.
3. 088-3: timed effects (45) and control (41) families.
4. 088-4+: persistent-areas, summons and utility families, where real gaps (`PROPOSED-spells-N`) are likeliest.
