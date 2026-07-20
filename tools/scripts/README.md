# Development Helper Scripts

> **Documentation status: maintained reference.** These scripts exist in this directory, but they can install tools or report legacy policy checks. Inspect them before running.

| Script | Current role |
| --- | --- |
| `tools/scripts/setup-ci-environment.sh` | Checks/sets up parts of the local CI-style tool environment. |
| `tools/scripts/setup-dev-tools.sh` | Installs/checks development tools. |
| `tools/scripts/pre-commit-checks.sh` | Runs repository quality heuristics and lint/format checks available to it. |
| `tools/scripts/validate-gut-integration.py` | Inspects GUT integration. |

Run from the repository root with the real path, for example:

```bash
bash tools/scripts/pre-commit-checks.sh
python3 tools/scripts/validate-gut-integration.py
```

These helpers are not the canonical project-readiness gate. Use:

```bash
bash tools/check_documentation_truth.sh
bash tools/check_project_truth.sh
bash tools/check_headless_runner_manifest.sh
```

Review install commands before executing setup scripts, especially in managed Python/system environments. A successful helper script does not imply the Godot suite, manual evidence, or release gate is green.
