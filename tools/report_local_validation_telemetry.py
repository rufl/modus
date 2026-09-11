#!/usr/bin/env python3
"""Summarize opt-in local MODUS validation telemetry JSONL sessions."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path


def load_events(directory: Path) -> tuple[list[dict], list[Path]]:
    events: list[dict] = []
    files = sorted(directory.glob("*.jsonl")) if directory.is_dir() else []
    for path in files:
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if not line.strip():
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError as error:
                raise SystemExit(f"Malformed telemetry: {path}:{line_number}: {error}") from error
            if not isinstance(event, dict) or not event.get("event"):
                raise SystemExit(f"Invalid telemetry event: {path}:{line_number}")
            event["_file"] = str(path)
            events.append(event)
    return events, files


def report(events: list[dict], files: list[Path], directory: Path) -> str:
    sessions = Counter(str(event.get("session_id", "unknown")) for event in events)
    event_counts = Counter(str(event["event"]) for event in events)
    samples = [event for event in events if event.get("event") == "runtime_sample"]
    warnings = [event for event in events if event.get("event") == "log_signal"]
    checkpoints = [event for event in events if event.get("event") == "checkpoint"]
    lines = [
        "# Local Validation Telemetry Report",
        "",
        "This report summarizes opt-in local JSONL telemetry. No network upload is performed.",
        "",
        "## Summary",
        "",
        f"- Directory: `{directory}`",
        f"- Sessions: {len(sessions)}",
        f"- Files: {len(files)}",
        f"- Events: {len(events)}",
        f"- Runtime samples: {len(samples)}",
        f"- Warning/error signals: {len(warnings)}",
        f"- Checkpoints: {len(checkpoints)}",
        "",
        "## Event Counts",
        "",
        "| Event | Count |",
        "| --- | ---: |",
    ]
    lines.extend(f"| `{name}` | {count} |" for name, count in sorted(event_counts.items()))
    lines.extend(["", "## Sessions", "", "| Session | First event | Last event | Events |", "| --- | --- | --- | ---: |"])
    for session_id in sorted(sessions):
        session_events = [event for event in events if str(event.get("session_id")) == session_id]
        lines.append(
            f"| `{session_id}` | {session_events[0].get('timestamp', '')} | "
            f"{session_events[-1].get('timestamp', '')} | {len(session_events)} |"
        )
    lines.extend(["", "## Checkpoints", ""])
    if checkpoints:
        lines.extend(
            f"- `{event.get('session_id', '')}` `{event.get('fields', {}).get('name', '')}` "
            f"at {event.get('timestamp', '')}"
            for event in checkpoints
        )
    else:
        lines.append("- No checkpoints recorded.")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--logs", type=Path, default=Path("logs/validation_telemetry"))
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    events, files = load_events(args.logs)
    output = report(events, files, args.logs)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(output + "\n", encoding="utf-8")
        print(f"Telemetry report written to {args.report}")
    else:
        print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
