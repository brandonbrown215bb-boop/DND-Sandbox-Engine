# Gate 2 evidence

> Historical snapshot, not current priority or acceptance. See the
> [documentation map](README.md) for current authority. Findings, counts,
> gate decisions and execution orders below apply to the dated snapshot;
> reproduce relevant behavior before reopening a defect or reusing a claim.

## Validation environment

- Engine: Godot 4.7.stable.official.5b4e0cb0f
- Host: Windows
- Runner: `run_tests.ps1 ... -Suite logic`
- Content manifest: `data/content_manifest.json`

## Automated result

The project-context parse and logic suite passed after the Gate 2 loader and
save-boundary changes:

| Check | Result |
|---|---|
| Project bootstrap | Pass |
| Project-context parse | Pass - 56 scripts loaded |
| Logic suite | Pass - 521 assertions, 0 failures |
| Cross-process registry digest | Pass - two fresh Godot processes produced identical digest `E1BB61BE26194989C435A355800EF1A40710F2BB55395869C906A27922151C8D`; both reported `LOAD_ERRORS=0` |
| Loaded registries | 14 classes, 9 races, 233 items, 198 spells, 453 monsters, 4 event tables, 1 campaign |
| Unapproved collisions/schema failures | 0 |
| Curated `bless` and `shield` mechanics | Pass |
| Curated spell cohort | Pass - Magic Missile, Scorching Ray, effect-only Mage Armor/Cure Wounds, and Ray of Frost production effects cross the shared resolver |
| Crown monster and consumable fixtures | Pass - all 10 Crown monsters expose validated actions/AI metadata; four production consumables expose executable effects |
| New wizard production spell access | Pass - known spell and level-1 slot |
| Unsupported effectless features | Rejected from player-facing records - unsupported records remain unavailable pending curation; the curated cohort is executable through shared effects |
| Cross-record references | Pass - campaign goals, dungeon pools/loot/bosses, event tables, and class spell access validate at load |
| Importer portability | Implementation pass - explicit source/raw/output arguments, sorted discovery, curated-output refusal, and JSON collision/coverage report |
| Safe save boundary | Pass - combat blocked; overworld and dungeon-entry checkpoint accepted |
| Party DTO round-trip | Pass - stable slots, companion roster, campaign ledgers, and structural reference validation persist |

## Clean-room importer run (2026-08-10)

Command:

```powershell
python src/convert_all_5etools.py --external-data-dir G:\linux\5etools-src\data --raw-dir ".\5etools raw" --output-dir <isolated-temp>\imported --report <isolated-temp>\import_report.json
```

The importer exited `0`, reported `completed`, and reported zero source
errors. The staged report contained no within-import duplicate IDs, 93
within-source duplicate IDs, and 754 existing-core overlap IDs. These overlaps
were reported in staging and were not promoted into curated content.

| Category | Source records | Exported | Skipped | Existing-core overlaps |
|---|---:|---:|---:|---:|
| Classes | 27 | 14 | 13 | 14 |
| Items | 196 | 60 | 136 | 60 |
| Spells | 361 | 198 | 163 | 198 |
| Monsters | 450 | 450 | 0 | 450 |

SHA-256 hashes for every file under `data/core/` matched before and after the
run. The staging output and report were written under a disposable Windows
temporary directory, outside `data/core/`.

## Promotion review (2026-08-10)

The generated feature matrix contains 43 mechanics-backed rows and 349
quarantined rows. It contains no exposed `description-only`, `test-only`, or
`missing` rows. The staged importer supplied descriptions and duplicate-source
records, but no executable `effects` or registered resolvers; it is not
evidence for promotion by itself.

Decision: promote no staged feature records. Retain all 349 quarantined rows,
including Druid Wild Shape and the remaining unsupported class features, until
each has an accepted effect/resolver contract, normal player path, and
mechanics test. The existing 43 mechanics-backed rows remain the only promoted
cohort.

The certificate-store message from the Windows host remains the existing
allowlisted environment warning. The loader warning about rejected unsupported
effectless features is expected and is documented by
`docs/content_pipeline.md`; it is not a completion claim for those features.

## Decision

`DONE`. DATA-01 through DATA-10 have implementation, clean-room, and promotion
review evidence. The staged source/core overlaps remain recorded and are not
runtime promotions; unsupported effectless records remain quarantined. No
staged feature was promoted without an executable effect/resolver contract.
