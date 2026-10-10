# ADR-0000: Windows is the supported validation host

Date: 2026-08-09
Status: Accepted; renumbered 2026-10-09 to resolve duplicate ADR-0001

## Decision and reason

Windows Godot 4.7 is the supported validation host. `run_tests.ps1` is the
authoritative runner. Current development uses Windows; requiring Linux would
preserve an old workstation assumption rather than a product requirement.

`run_tests.sh` remains compatibility tooling. Its presence is not native Linux
acceptance, and Linux execution is not required for current feature acceptance.
Any expanded platform claim requires evidence for that host.

## Validation contract

The runner owns recovery bootstrap, project parsing, production boot, logic
and named scene integration with isolated profiles, failure markers, timeouts
and engine-error checks. Use proportionate focused runs during development;
run broader coverage at an acceptance boundary ([testing](../testing.md)).
Campaign smoke is one bounded scenario, not complete campaign certification.
Packaging/fresh-clone checks apply when publication is chosen.

Renumbering changes no policy or runtime behavior. Historical references to
the Windows-host ADR-0001 refer to this record; ADR-0001 now uniquely identifies
shared-keyboard seats. The old gate numbering is historical only.
