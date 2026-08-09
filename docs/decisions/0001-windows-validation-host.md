# ADR 0001: Windows is the supported validation host

- Status: Accepted
- Date: 2026-08-09

## Context

The repository retains a shell runner from its earlier Linux development
environment. Current development and milestone validation happen on Windows,
and requiring native Linux execution would preserve an obsolete workstation
constraint rather than a product requirement.

## Decision

Windows is the supported validation host. `run_tests.ps1` is the authoritative
Gate 1 runner and its complete `all` suite is milestone evidence.

`run_tests.sh` remains compatibility tooling for environments that can satisfy
its Godot and `XDG_*` assumptions. Its presence is useful, but native Linux
execution is not required to complete Gate 1 or the Crown milestone.

The fixed-seed campaign smoke is not a third Gate 1 suite. Gate 1 owns the logic
and isolated scene-integration suites; Gate 7 introduces and owns campaign
smoke coverage.

## Consequences

- Gate documentation and evidence name Windows explicitly.
- Clean-checkout validation requires the documented PowerShell command.
- Shell-runner failures on unsupported hosts do not invalidate Gate 1.
- Any future cross-platform support decision requires new evidence and a new
  ADR rather than silently expanding this gate.
