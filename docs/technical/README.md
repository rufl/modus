# Technical Documentation Index

> **Documentation status: maintained reference.** This index separates the few current technical boundaries from unvalidated historical design and completion reports.

## Maintained References

- `JSON_SCHEMAS.md` — live content data, runtime configuration, feature-profile, and mod-override ownership.
- `STEAM_INTEGRATION.md` — explicit ENet fallback, local simulation, and real Steam/GodotSteam proof boundary.

Project-wide source entry points are in `docs/architecture.md` and `docs/TECHNICAL_REFERENCE.md`. Test execution is documented in `tests/README.md` and `tests/runners/README.md`. Map-generator source and focused proof are summarized in `game/scripts/map_generator/README.md`.

## Historical Technical Files

All other Markdown files in this directory are historical snapshots unless their header explicitly says otherwise. That includes former component/service architecture, breakable-prop compatibility, map-threading design, all-purpose testing/type-safety guides, migrations, audits, CI plans, task-completion reports, and fix summaries.

Historical bodies have not been revalidated. Paths, APIs, diagrams, counts, timings, security claims, and conclusions may be wrong or superseded.

## Current Verification

```bash
bash tools/check_documentation_truth.sh
bash tools/check_project_truth.sh
```
