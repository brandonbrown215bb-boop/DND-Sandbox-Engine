# Grimoire Content Workbench (`tools/content_editor/`)

Standalone tabletop content workbench for Rook's 5e-lite engine, built against the pinned **VS-83** contract snapshot (`tools/content_editor/contracts/pinned_vs83_2026_10_18.json`) and styled with the game's **Grimoire** UI profile (`theme/grimoire_profile.tres`).

## Ownership & Isolation Contract

- **Read-Only Inputs**: `data/core/`, `data/content_manifest.json`, and `reference/2024/`. The workbench never mutates shipped game files or runtime scripts.
- **Mutable Workspaces**: `tools/content_editor/workspaces/<pack_id>/`
- **Versioned Pack Exports**: `tools/content_editor/exports/<pack_id>_<revision>_<mode>/`

## Quick Start

```powershell
# 1. Run the automated round-trip, ordered-steps, and 2024 reference comparator test suite
python tools/content_editor/test_editor.py -v
node --test tools/content_editor/test_workbench.js

# 2. Seed the demo workspace (`ember_pack`) and generate both export modes
python tools/content_editor/app.py seed-demo

# 3. Launch the local Grimoire Content Workbench UI
python tools/content_editor/app.py serve --port 8765
```

Open `http://127.0.0.1:8765` in your browser.

## Key Capabilities

Selection and validation responses are bound to the current workspace and record.
Saving refuses a still-loading or mismatched record, and the update endpoint
rejects an ID mismatch before writing a draft. Edits made while a save is pending
remain visible and unsaved afterward.

1. **Authentic Grimoire 3-Pane Workbench (`ui/index.html`, `ui/styles.css`, `ui/workbench.js`)**:
   - Styled directly from `theme/grimoire_profile.tres` (`#0c0d10` base obsidian, `#17191f` raised slate, `#302a21` warm bronze selection, `#c69a4a` burnished gold accents).
   - Native `<dialog>` modals for **Create from Archetype Template**, **Duplicate as Homebrew**, **Export Pack Bundle**, and **Workspace Settings** (zero browser `prompt()`/`alert()` dialogs).
   - Live keystroke validation (`POST /api/validate_live`) and `Ctrl+S` save / `/` search keyboard shortcuts.
2. **Structured Visual Builders for Spells (Zero Raw JSON Textareas)**:
   - **Flat Delivery vs. Ordered Steps Pipeline (`ADR-0019` / `SharedStepExecutor`)**: Switch between flat `attack_type`/`save`/`damage` and sequential `steps` cards with `gate` (`always`, `hit`, `miss`, `failed_save`, `successful_save`), `gate_step`, per-step area geometry, and per-step effects.
   - **Shared Effects Builder**: Visual cards for `heal`, `temporary_hp`, `grant_condition`, `remove_condition`, `area_selection`, and `grant_source_benefits`.
   - **Coupled Dual-Unit Inputs**: Bidirectional **Hexes ↔ Feet** (`1 hex = 5 ft`) for `range`, `area_radius`, `cone_size`, and step radii, plus **Duration Preset + Text ↔ Seconds (`1 round = 6s`)**.
   - **Repeat Save Stages & Source-End Rules**: Visual builders for `repeat_save_stages` and `source_end_rules` (`attack`, `cast`, `movement`, `status`, `equipment`, `range`, `damage`).
3. **Structured Visual Builders for Items**:
   - Contextual **Weapon** (`weapon_type`, `ability`, `damage`, `range` hex/ft, `properties` pills) and **Armor/Shield** (`armor_type`, `armor_class`, `dex_cap`, `stealth_disadvantage`) cards.
   - **Batch L `source_benefits` Carrier Builder**: Live `+AC` and `+Walking Speed (hexes ↔ ft)` inputs.
   - **Batch 021 `spell_permissions` & Wand Charges Builder**: Visual permission blocks with granted spell IDs, casting ability, and charges.
4. **2024 SRD 5.2.1 / XPHB Class Progression Comparator**:
   - Selecting any class in the catalog renders a **Level 1–20 Feature Parity Matrix** comparing `data/core/classes/<id>.json` (`Enabled` vs. `Quarantined / Effectless` features) against `reference/2024/classes/<id>.json` (subclasses, SRD 5.2 tags, and clean collapsible rules prose), plus a breakdown of the class's curated spell list and active pack additions.
5. **Two Export Modes (`draft_lossless` & `game_pack_candidate`)**:
   - `draft_lossless`: Preserves 100% of unknown top-level, effect, and step fields in their exact original positions.
   - `game_pack_candidate`: Parks non-`SharedSpell` top-level, effect, and step fields under `_editor_meta` so `SharedSpell.content_error()` accepts the record without losing data, and emits composable `spell_list_additions` and `starting_equipment_additions` in `pack.json`.
