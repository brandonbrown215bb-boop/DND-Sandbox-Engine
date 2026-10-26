# Spell inventory and rules-vocabulary audit (Batch 088)

**Status: PARTIAL AUDIT. Inventory is complete. Clause decomposition covers 4 of 362 unique loaded spell IDs (1.1%). The other 358 are UNREVIEWED.** This is not a complete audit. Nothing here enables, converts or certifies a spell. Accepted slice counts and checkpoint acceptance are unchanged.

## Evidence boundary

| Item | Value |
|---|---|
| Commit exported | `ede0a3cdfa66f21b0b3415f498c2e186e56a0db4` (origin/main, merge of #60) |
| Registry hash | `DataLoader.get_registry_hash()` returns the full JSON snapshot string, not a digest. SHA-256 of that string: `70a83cc74e530743e90f8fadc992bd0651f56b51cb84b06cd73fcaf22187845e` |
| Runner | **Not the supported Windows runner.** `scripts/invoke_godot_case.ps1` (docs/operations/development.md) can't run on the Linux box. I used `/workspace/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . res://scenes/spell_inventory_export.tscn` after two `--import` passes. Exit 0, `SPELL INVENTORY EXPORTED: 362 unique spells`, with no SCRIPT, Parse or Compile errors. Output is in `.artifacts/spell-status/runtime.json` (ignored), with logs beside it. A Windows export should confirm that the hash matches. |
| SRD source | SRD 5.2.1 PDF converted with `pdftotext` (reading-order flow). The two-column layout breaks up some text; see the limits below. |
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

### Class-membership discrepancies against SRD 5.2.1 spell headers (data correction candidates, not changed)

I parsed 318 SRD headers cleanly. The other 21 are marked `unparsed` in the CSV and remain unchecked.

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

## Genuine vocabulary gaps (PROPOSED-spells-N)

None yet from reviewed clauses. Proposals will be added as `PROPOSED-spells-N` with source clause, affected spells, reusable pieces, dependencies and an observable finish line once batches reach non-direct families.

## Known limits of this pass

- 358 of 362 IDs are unreviewed for clauses. Families in spell-status.md remain the planning grouping.
- Column-interleaved PDF text means 21 SRD headers weren't parsed for class checks. Spell text extracts must be read against the PDF page before any clause is classified.
- `get_registry_hash()` isn't a hash. I recorded a SHA-256 of it. Changing it is runtime work and out of scope.
- No Windows supported-runner export was possible from the box.

## Recommended next queue

1. Brandon runs the Windows export (`scripts/invoke_godot_case.ps1`, Scene mode) and compares it with this SHA-256 and these totals.
2. 088-2: the rest of the direct_resolution family (52 IDs), checking data fields against SRD text.
3. 088-3: class-membership correction review for the 7 discrepancies plus the 21 unparsed headers.
4. 088-4+: control, timed-effects and persistent-areas families, where real gaps (`PROPOSED-spells-N`) are likeliest.
