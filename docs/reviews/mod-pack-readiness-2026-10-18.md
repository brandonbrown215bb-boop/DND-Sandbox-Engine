# Mod-pack readiness and Antigravity handoff

Reviewed 2026-10-18 against the current working tree. This is a wiring review,
not a pack-format decision or a new rules-support acceptance. No runtime code
was changed. The existing working tree contains substantial unrelated work.

## Verdict

Repository-local modded JSON works now. A self-contained, installable content
pack does not. Antigravity can start the guided editor now, provided its first
version only authors supported operations and its export format remains a draft
until the game's pack loader exists. Completing all 226 vocabulary slices is
not a prerequisite for a small pack using the accepted subset.

## Current path

`DataLoader.load_all_data()` reads `res://data/core/`, then `res://data/mods/`.
Each root has flat `classes`, `subclasses`, `races`, `items`, `spells`,
`monsters`, `events` and `campaigns` directories. Files are sorted JSON objects
or arrays. `data/mods/<pack-id>/spells/` is not discovered. The current mods
tree contains only its README, so the baseline is not evidence of an installed
third-party pack.

The loader validates records, resolves explicit collisions and checks selected
cross-record references. Registries feed character creation, subclass controls,
spell selection, combat and saves. `execution: shared` spells use operation
validation rather than an ID allowlist. Common class features can use the
shared executor. Native-only mechanics, prose traits and invented effect names
do not become executable by appearing in JSON.

Owners: [loader](../../src/autoload/data_loader.gd),
[spell availability](../../src/spells/spell_support.gd),
[authoring guide](../modding_guide.md), [shared spells](../mechanics/shared-spells.md).

## Gaps that matter for a guided publisher

1. **There is no independent pack installation boundary.** The roots are fixed
   `res://` paths. The single repository manifest lists pack IDs, versions,
   dependency IDs and layers, but layers do not drive discovery; their paths
   and precedence are not used to select loading roots. Version and ruleset
   fields are checked for presence, not compatibility with the running engine.
   No external pack directory, ZIP installer or enable/disable flow was found.
   Exported-game pack installation has not been verified.

2. **Ordinary additions can require conflicting whole-record overrides.** A new
   spell must also be reachable through a class list or another owned casting
   source. Existing class-list authoring uses an approved class override.
   `_merge_missing_fields()` fills absent top-level fields; it does not combine
   arrays. Two independently authored Wizard spell-list overrides therefore do
   not automatically compose. Override permissions also name exact file paths
   and array indexes in the central manifest. A small explicit spell-list
   addition contract is preferable to making every wizard export a Wizard copy.
   `_populate_class_spell_access()` separately rewrites curated classes'
   `cantrips_known` and `spells_known_by_level`; the current picker reads
   `spell_list_ids`. Do not use those older fields as the editor's list API.

3. **Validation feedback can report success after removing content.**
   `_sanitize_class_features()` quarantines unsupported effectless features as
   warnings. The main menu's `_display_mod_errors()` only reads load errors,
   and prints success when that list is empty. The reviewed baseline actually
   produced 25 such warnings. The editor needs individual rejected-feature
   diagnostics and must distinguish structural validity from executable support.
   The item JSON schema also lags the runtime: it omits accepted `ring`, `wand`
   and `spell_component` types. There are no class/subclass/race/event schema
   files in `docs/json_schemas/`. Do not build the form solely from those files.

4. **Validation is not an isolated install preview.** `load_all_data()` clears
   and repopulates live registries before it knows whether the complete load is
   valid; `reload()` calls it directly. Errors suppress `data_loaded`, but the
   main menu still lists campaigns and its Start handler has no load-error
   guard. A pack workflow should validate a candidate set before accepting it,
   or refuse starting with an invalid installed set. Avoid live campaign reload
   for the first version; restart after changing installed packs is sufficient.

5. **Save safety is definition-based, not pack-based.** Existing preflight
   rejects missing required definitions on supported paths before replacing the
   party. Saves do not record installed pack IDs/versions, and cannot identify
   which pack to reinstall or detect every same-ID definition change. For the
   first local trial, keep the same packs installed throughout a campaign and
   explain that updates/removals are not migrations. A migration framework is
   not required to prove the first pack.

## Smallest useful implementation order

1. Agree one plain folder contract with a pack metadata file, namespaced stable
   IDs, content-type folders, and explicit additions/replacements. Connect that
   external folder to the existing loader. Use one fixed supported format and
   an exact compatibility marker first; no dependency solver is needed.
2. Add candidate validation using the production Godot rules checks, with
   pack/file/record diagnostics and visible unsupported-feature warnings. Prove
   one installed additive pack, then two packs extending the same spell list.
   Refuse invalid references, incompatible formats and unapproved collisions
   before accepting the candidate content set.
3. Connect the guided editor's export to that contract. A downloadable ZIP can
   simply wrap the agreed folder; publishing/uploading and automatic installation
   are separate work. No hosting service is needed for the first usable export.

The first finish line is: author one spell in the editor, export its pack,
install it without editing game source or the central manifest, learn/prepare
and cast it through normal controls, save, restart, and recover it with the same
pack installed. Verify missing-pack refusal without changing the active party.
Repeat with a second pack adding a spell to the same class list.

## Brief for Antigravity

Build a guided homebrew content editor. Begin with ordinary shared spells and
simple items using supported runtime behavior. Add subclass/common-feature
templates after those exports work; full custom classes already have a bounded
runtime path but make a much larger first form. General monsters, arbitrary AI,
forms and open-ended rule scripting are outside this first editor.

Flow: pack name/author/ID/version -> content type -> supported template ->
identity and description -> costs/targets/effects -> acquisition or class-list
placement -> validation and preview -> export.

Generate stable namespaced IDs once and retain them when display names change.
Show plain-language units: spell range/area uses five-foot hex counts internally,
so a feet-based form must convert explicitly. Keep executable fields tied to
current mechanic contracts; preserve prose as description. Unsupported behavior
may be saved as a draft, but must not receive a working-content label. Validate
the exported artifact with the game; a second rules engine in the editor would
drift. Treat the package syntax as proposed until the engine contract is agreed.
Export authored files and metadata only, rather than bundling the core catalog.

## Verification and limits

Ran the existing supported runner:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_tests.ps1 -Suite all -LogicGroup data -Scenario class_building_blocks
```

- Project bootstrap, 228-script parse gate and production boot gate passed.
- The data logic group returned **220 passed, 1 failed**. The failure is the
  Counterspell/Signature Spell interruption-and-slot-refund assertion at
  `src/test_runner.gd:683`. The overall run therefore failed. This review does
  not diagnose or repair that separate casting failure.
- `class_building_blocks` passed with zero failures: fixture JSON -> actual
  creation card -> subclass/ability choices -> combat feature activation and
  exact costs -> save/load -> missing-subclass refusal preserving the party.
  It explicitly loads a fixture root and is evidence for the supported content
  path, not external pack discovery or all custom class mechanics.
- Baseline production loading reported zero load errors and 25 quarantined
  unsupported-feature warnings.

Logs: `.artifacts/tests/e0d5f4dfda3e4aca863cb8769b0c9a03/`.
CodeGraph was checked: its index covers Python/liquid, not GDScript. CodeGraph
CLI and Agent Ground status tooling were unavailable; source inspection and
production Godot checks supplied the review evidence.
