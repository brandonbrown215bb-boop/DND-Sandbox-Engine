# Original User Request

## Initial Request — 2026-08-10T22:00:57-05:00

Perform a deep architectural review and taxonomy audit of all 157 quarantined/effectless class feature records in data/core/classes/. Produce a comprehensive remediation specification document mapping every feature to its 5e rules mechanics, required effect vocabulary, and proposed CURATED_FEATURE_EFFECTS dictionary definitions for data_loader.gd.

Working directory: c:/Users/brand/Documents/linux/Top Down Party Game
Integrity mode: development

## Requirements

### R1. Comprehensive 14-Class Feature Audit & Taxonomy
Examine all 157 quarantined class feature records across the 14 character classes (barbarian, bard, cleric, druid, fighter, monk, mystic, paladin, ranger, rogue, sorcerer, warlock, wizard, artificer). Categorize every feature into one of four distinct tiers:
1. Immediate Curation Candidates: Features that map cleanly to existing effect vocabulary (stat_modifier, grant_condition, heal_self, extra_attack, reaction, resource_spend, etc.).
2. Vocabulary Extension Candidates: Features requiring small additions to the engine's effect vocabulary or event resolvers (e.g. forced movement, saving throw advantage, damage rerolls).
3. Subsystem-Quarantined: Features dependent on complex un-implemented subsystems (e.g. Mystic psionics, Druid Wild Shape form rosters) that should remain quarantined until their ADRs/subsystems are ready.
4. Narrative / Non-Combat Ribbons: Fluff or non-combat features (e.g. Thieves' Cant, Scholar, Ritual Adept) that should remain intentionally quarantined or tagged as passive narrative markers so they never clutter combat UI.

### R2. 5E Rules Verification & Exact Curation Specification
For every feature in Tiers 1 and 2, verify its official D&D 5e mechanics (using web-search or 5eTools data if local text is incomplete). Document the exact proposed JSON/Dictionary structure to add to CURATED_FEATURE_EFFECTS in src/autoload/data_loader.gd, including type, action_cost, uses, uses_per, effects, and resource_formula.

### R3. Remediation Report & Matrix Validation
Deliver the complete audit and specification as a clean Markdown artifact (docs/quarantined_features_remediation_plan.md). Ensure python src/generate_feature_matrix.py and python src/validate_and_test.py run cleanly without errors.

## Acceptance Criteria

### Audit & Categorization Coverage
- [ ] 100% of the 157 quarantined class feature records are explicitly cataloged and assigned to one of the four taxonomy tiers.
- [ ] Every Tier 1 and Tier 2 feature has a fully specified CURATED_FEATURE_EFFECTS code snippet matching 5e rules and engine conventions.

### Subsystem & Quarantine Boundaries
- [ ] Subsystem-blocked features (Mystic psionics, Druid Wild Shape) are documented with their specific blocking dependencies/ADRs.
- [ ] Narrative/ribbon features are categorized to remain cleanly quarantined from combat action menus.

### Verification & Documentation
- [ ] Deliverable created at docs/quarantined_features_remediation_plan.md.
- [ ] python src/generate_feature_matrix.py and python src/validate_and_test.py complete with exit code 0.
