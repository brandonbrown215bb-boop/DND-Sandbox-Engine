# Gate 8 shipping evidence

> **Archived material.** This preserves a past snapshot, not current instructions.
> Read the [current checkpoint](../../operations/current.md) and [roadmap](../../../roadmap.md) before acting.


> Historical snapshot, not current priority or acceptance. See the
> [documentation map](../../README.md) for current authority. Findings, counts,
> gate decisions and execution orders below apply to the dated snapshot;
> reproduce relevant behavior before reopening a defect or reusing a claim.

## Automated result

| Check | Result |
|---|---|
| Setup and test documentation | Pass - repository README and `run_tests.ps1` document Godot 4.7.x setup, launch, suites, and current limitations |
| Development control surface | Pass - Beckett is absent from the default autoload list and the default project configuration |
| Settings honesty | Pass - Master, SFX, and Music buses are created by `AudioManager`; settings controls write to real bus volumes, while missing audio assets are skipped with a warning |
| Clean-process validation | Pass - isolated runner creates disposable APPDATA/LOCALAPPDATA roots and fresh Godot processes for bootstrap, parse, boot, logic, and each viewport scenario |
| Clone-equivalent clean copy | Pass - `scripts/validate_clean_copy.ps1` copied the latest tree without `.git`, Godot caches, Codex state, saves, or build outputs, then passed bootstrap, parse, boot, 521-assertion logic, and every named viewport scenario |
| Full runner | Pass - two consecutive 2026-08-10 runs passed 521 logic assertions and all named integration scenarios |

The prior feature-exposure quarantine checkpoint passed the isolated
521-assertion logic suite, the full runner, and clone-equivalent clean-copy
validation. Gate 1 recovery on 2026-08-10 removed the nondeterministic fixture;
the complete runner then passed twice with exit code `0`.

## Open Gate 8 work

True fresh-clone validation, private-content approval, generated-artifact
cleanup, and friend-run work are publication-only checks parked until
publication is wanted. A full manual playthrough is optional and nonblocking.
Gate 8 remains `in_progress` behind the unfinished upstream gates and an
agent-owned readiness audit. Passing local automation is necessary evidence;
it does not by itself satisfy the publication boundary.
