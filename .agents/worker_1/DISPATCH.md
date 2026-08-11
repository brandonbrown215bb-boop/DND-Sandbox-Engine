# DISPATCH for Worker 1: Quarantined Features Remediation Specification Generation

## Objective
Write the complete, authoritative remediation plan and 157-feature taxonomy specification artifact at `docs/quarantined_features_remediation_plan.md`.

## Mandatory Rules & Guidelines
1. DO NOT CHEAT. All implementations and specifications must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
2. Ensure 100% of the 157 quarantined class features across 14 character classes are explicitly cataloged and assigned to one of the 4 taxonomy tiers:
   - Tier 1: Immediate Curation Candidates (maps to existing effect vocabulary in `data_loader.gd`)
   - Tier 2: Vocabulary Extension Candidates (requires new effect types or event resolver extensions)
   - Tier 3: Subsystem-Quarantined (blocked by un-implemented subsystems / ADRs)
   - Tier 4: Narrative / Non-Combat Ribbons (fluff or non-combat features tagged to stay out of combat action menus)
3. For EVERY Tier 1 and Tier 2 feature:
   - Verify official D&D 5e rules mechanics.
   - Provide the exact proposed GDScript `CURATED_FEATURE_EFFECTS` Dictionary code snippet ready to be added to `src/autoload/data_loader.gd`.
   - Specify `type`, `action_cost`, `uses`, `uses_per`, `resource_formula`, `effects`, and all parameters.
4. For Tier 3 features:
   - Detail specific blocking subsystem dependencies (e.g. Mystic psionic disciplines, Druid Wild Shape ADR-0002 / form rosters, Battle Master maneuvers, Artificer infusions).
5. For Tier 4 features:
   - Specify categorization and tagging schema (`"type": "narrative_ribbon"`) to keep non-combat features out of combat UI menus.
6. Detail the 6 Engine Effect Vocabulary Extensions:
   - Forced Movement / Displacement
   - Saving Throw Advantage & Rerolls
   - Dice Manipulation & Damage Rerolls
   - Contextual Reactions
   - Subsystem Resource Pools & Rosters
   - Spatial Radius & Aura Buffs
7. Ensure `python src/generate_feature_matrix.py` and `python src/validate_and_test.py` execute with exit code 0.
8. Deliver file directly to `docs/quarantined_features_remediation_plan.md`.

## 2026-08-10T22:02:11Z
Invocation received from parent (c0f90910-f637-4e67-8aee-71dd4e5d70a7). Task: Produce comprehensive remediation specification document at docs/quarantined_features_remediation_plan.md covering all 157 quarantined class features across 14 character classes into 4 tiers.

