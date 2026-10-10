# Repository content mods

Put JSON directly in content-type directories here: `classes`, `subclasses`,
`races`, `items`, `spells`, `monsters`, `events`, `campaigns`. Discovery is
sorted; named pack folders are not recursively loaded. Prefer namespaced IDs.
Duplicate IDs need an approved winner/replacement in `data/content_manifest.json`.

Use the [authoring guide](../../docs/modding_guide.md) for implemented contracts
and [shared spells](../../docs/mechanics/shared-spells.md) for ordinary JSON
execution. Current shape schemas and descriptive examples are not proof that
all rules run. The target class/creature language is still unimplemented.
Keep required saved content installed; missing required definitions reject
load before changing the session. No mod manager or automatic migration exists.
