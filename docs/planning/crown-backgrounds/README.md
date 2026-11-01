# Crown background preparation (G5)

**Preparation only. Not loaded, not playable, not accepted.** This folder pins
the four Crown backgrounds to SRD 5.2.1 and maps each clause to the current
acquisition contract. It is the G5 item in
[Crown parallel work](../crown-parallel-work.md) and is linked from the
[Crown content scope](../crown-content-scope.md#species-backgrounds-and-feats).
Status stays in the [slice registry](../vocabulary-slices.md) under S-231; this
folder is not a second ledger.

[`candidates.json`](candidates.json) holds the candidate records. The
DataLoader reads only the content-type folders under `res://data/core/` and
`res://data/mods/` (`_load_directory` in `src/autoload/data_loader.gd`) and has
no background type, so nothing here is loaded. Do not copy these records into
`data/` until S-231 and the effect hosts below exist.

## Source

SRD 5.2.1 (`SRD_CC_v5.2.1.pdf`), "Character Origins", PDF page 83 = printed
page 83. Each candidate carries its verbatim quote. The general rules on the
same page:

> A background lists three of your character’s ability scores. Increase one by
> 2 and another one by 1, or increase all three by 1. None of these increases
> can raise a score above 20.

> A background gives your character a specified Origin feat (described in “Feats”).

> Each background gives a character proficiency with one tool—either a specific
> tool or one chosen from the Artisan’s Tools category.

> Each background offers a choice between a package of equipment and 50 GP.

Item clauses were checked against the Equipment chapter: Gaming Set variants
(PDF p.94), gear table and Ammunition (p.95–96), Book, Holy Symbol, Traveler’s
Clothes (p.96–97), Parchment (p.99). Feats: Alert, Magic Initiate, Savage
Attacker, Skilled on PDF p.87.

| Background | Abilities | Origin feat | Skills | Tool | Equipment A | B |
|---|---|---|---|---|---|---|
| Acolyte | INT, WIS, CHA | Magic Initiate (Cleric) | Insight, Religion | Calligrapher’s Supplies | Calligrapher’s Supplies, Book (prayers), Holy Symbol, Parchment ×10, Robe, 8 GP | 50 GP |
| Criminal | DEX, CON, INT | Alert | Sleight of Hand, Stealth | Thieves’ Tools | Dagger ×2, Thieves’ Tools, Crowbar, Pouch ×2, Traveler’s Clothes, 16 GP | 50 GP |
| Sage | CON, INT, WIS | Magic Initiate (Wizard) | Arcana, History | Calligrapher’s Supplies | Quarterstaff, Calligrapher’s Supplies, Book (history), Parchment ×8, Robe, 8 GP | 50 GP |
| Soldier | STR, DEX, CON | Savage Attacker | Athletics, Intimidation | one Gaming Set (choice) | Spear, Shortbow, Arrows ×20, Gaming Set (same as chosen), Healer’s Kit, Quiver, Traveler’s Clothes, 14 GP | 50 GP |

## Item and feat resolution (production DataLoader, headless Linux)

Resolved against the loaded registry (Linux headless Godot 4.7.2, commit
`bd54fa5`; supported Windows runner not used):

- Resolved: `calligraphers_supplies`, `crowbar`, `dagger`, `healers_kit`,
  `holy_symbol`, `quarterstaff`, `robe`, `shortbow`, `spear`, `thieves_tools`.
- Missing items: generic Book (with topic), Parchment, Pouch (not
  `component_pouch`/`gold_50`), Traveler’s Clothes, Arrows, Quiver, and all four
  Gaming Sets (Dice, Dragonchess, Playing Cards, Three-Dragon Ante; candidate IDs
  `dice_set` etc. are proposals). Item records are Crown item work, not part of
  this PR.
- Missing feats: `alert`, `magic_initiate`, `savage_attacker` (0 feats load).

## Clause → current contract → what S-231 still needs

| Clause | Existing contract | Still needed |
|---|---|---|
| +2/+1 or +1/+1/+1 among three listed, cap 20 | Only species `ability_bonuses` (fixed map) and S-242 generation receipts | Background-owned choice with both patterns, cap 20, receipt in `creation_choices`, save preflight; no replay on restore |
| Specified Origin feat | `Character.origin_feat` + `FeatRules.choose_origin` (S-233): a free Origin pick, `feat_id|parameter` | Grant fixed by background (not a free pick); parameter fixed (`cleric`/`wizard`); save check that origin feat matches background |
| Two fixed skills | Class skill choices append to `skill_proficiencies` without a per-source owner | Source-owned grant (S-047/V-027); overlap with class/species picks must not lose a source |
| Fixed tool / Gaming Set choice | `tool_proficiencies` assigned from class `choices.tools` (overwrites) | Source-owned tool grant + category choice; same-as-chosen item link for Soldier; G2 owns the class side |
| Equipment A or 50 GP | Class starting equipment is a flat ID list; GP alternative is class-ID branched in `Character` | Generic A/B package with quantities and GP, no class/background ID branches; missing items above |
| Feat effects | Feat features accept only `mode_choice`/`rule_upgrade` | Alert, Magic Initiate and Savage Attacker effects from their p.87 bodies (not pinned here); separate work, not supplied by an Origin picker |

## Source gaps and open interpretations

1. **Holy Symbol form**: p.97 says it takes one form from the Holy Symbols table
   (Amulet, Emblem, Reliquary). Acolyte does not specify; the loaded generic
   `holy_symbol` vs `amulet`/`emblem`/`reliquary` needs a decision (choice or generic).
2. **Book topic**: p.96 Book bonus depends on the Book's topic. "Book (prayers)"
   / "Book (history)" need a topic field; no generic Book is loaded.
3. **"Gaming Set (same as above)"**: item must equal the chosen proficiency;
   no contract links an equipment entry to a proficiency choice.
4. **Artisan’s Tools alternative**: the general rule allows a chosen Artisan’s
   Tool, but none of these four uses it. Not needed for Crown.
5. **Magic Initiate parameter vs. Wizard spell list**: Sage/Acolyte fix the
   list; feat body (p.87) still needs its own definition.

No rule text was missing for the four backgrounds themselves.

## Reconcile with G2 / G4

- **G2** (class skill/tool choices): background tool/skill grants must use the
  same source-owned proficiency path G2 builds. Today `tool_proficiencies.assign`
  overwrites, which would erase a background tool. Thieves’ Tools (Rogue + Criminal)
  and gaming-set/instrument choices overlap; duplicate-proficiency handling
  must be decided once.
- **G2** also distinguishes owning an item from proficiency; Criminal’s and
  Acolyte/Sage’s A packages give both, Soldier ties them.
- **G4** (Skilled): Skilled is not a background feat here, but G4’s
  "selectable skill/tool proficiency effect" and overlapping-source rules are
  the same host the background grants need. Background skills plus a Skilled
  pick of the same skill must keep both sources.
- **G4** keeps `origin_feat` as a free pick; S-231 needs it fixed by background.
  Agree whether background sets `origin_feat` or a separate source-owned grant.

## Checks

- Headless production DataLoader with this folder present: 0 load errors,
  0 feats, registry SHA-256
  `83c294bf99b0946754769bb51b377f5a34a343e89442a9af9739dd4e12369b31` — identical
  to the 2026-11-01 baseline in Crown parallel work, so nothing new is loaded.

  **How the hash is computed.** `DataLoader.get_registry_hash()`
  (`src/autoload/data_loader.gd`) returns `JSON.stringify` of an array of
  `{"type", "id", "data"}` entries for the class, subclass, race, item, spell,
  monster, event and campaign registries (IDs sorted per type; feats are not
  included). The value above is Godot's `String.sha256_text()` of that string,
  i.e. SHA-256 of its UTF-8 bytes, as lowercase hex. The check script lives in
  ignored `.artifacts/`, so here it is in full; save it as
  `.artifacts/crown-bg/registry_hash.gd` in a checkout of this branch:

  ```gdscript
  extends SceneTree
  func _initialize() -> void:
  	await process_frame  # let the DataLoader autoload finish loading
  	var L = root.get_node("DataLoader")
  	print("errors=", L.get_load_errors().size(), " feats=", L.feats.size())
  	print("registry_sha256=", L.get_registry_hash().sha256_text())
  	quit(0)
  ```

  Run (Linux headless Godot 4.7.2 here; the Windows runner takes the same arguments):

  ```sh
  godot --headless --path . --script res://.artifacts/crown-bg/registry_hash.gd
  ```

  Expected output: `errors=0 feats=0` and the hash above. Without
  `await process_frame` the autoload has not finished loading and a different
  hash is printed. Reproduced at `498b87e` (with `.gdignore`).
- Candidate JSON parses; every non-null `item_id` resolves; nulls are listed above.
