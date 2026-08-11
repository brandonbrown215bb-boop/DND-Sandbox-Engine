# DISPATCH for Explorer 2: Data Loader & Effect Vocabulary Survey

## Objective
Survey `src/autoload/data_loader.gd` and related engine source code to analyze the existing `CURATED_FEATURE_EFFECTS` schema, effect vocabulary, and engine capabilities.

## Task Details
1. Read `src/autoload/data_loader.gd`.
2. Document all key-value structures, field schemas, effect types (e.g. `stat_modifier`, `grant_condition`, `heal_self`, `extra_attack`, `reaction`, `resource_spend`, `resource_refill`, `advantage`, `passive_bonus`, etc.).
3. Document supported fields: `type`, `action_cost`, `uses`, `uses_per`, `effects`, `resource_formula`, `activation_condition`, `target`, `duration`, etc.
4. Identify existing curated features in `CURATED_FEATURE_EFFECTS` as concrete reference examples.
5. Identify current limitations or missing vocabulary needed for features (e.g. forced movement, saving throw advantage, damage rerolls, reaction triggers).
6. Write your detailed analysis report to `.agents/explorer_2/effect_vocabulary_survey.md` and complete handoff at `.agents/explorer_2/handoff.md`.
