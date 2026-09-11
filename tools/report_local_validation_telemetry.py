#!/usr/bin/env python3
"""Summarize opt-in local MODUS validation telemetry JSONL sessions."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


class TelemetryParseError(ValueError):
    """Raised when a JSONL telemetry record cannot be consumed safely."""


def _parse_error(path: Path, line_number: int, message: str) -> TelemetryParseError:
    return TelemetryParseError(f"Malformed telemetry at {path}:{line_number}: {message}")


def _text(value: Any, default: str = "") -> str:
    """Convert nullable telemetry values to stable report text."""
    if value is None:
        return default
    if isinstance(value, (dict, list)):
        return json.dumps(value, sort_keys=True, separators=(",", ":"))
    return str(value)


def _cell(value: Any, default: str = "") -> str:
    """Make arbitrary telemetry safe for a Markdown table cell."""
    return _text(value, default).replace("|", r"\|").replace("\r", " ").replace("\n", " ")


def _fields(event: dict[str, Any]) -> dict[str, Any]:
    value = event.get("fields")
    return value if isinstance(value, dict) else {}


def load_events(directory: Path) -> tuple[list[dict], list[Path]]:
    events: list[dict] = []
    files = sorted(directory.glob("*.jsonl")) if directory.is_dir() else []
    for path in files:
        try:
            stream = path.open("rb")
        except OSError as error:
            raise SystemExit(f"Unable to read telemetry file {path}: {error}") from error
        with stream:
            for line_number, raw_line in enumerate(stream, 1):
                try:
                    line = raw_line.decode("utf-8")
                except UnicodeDecodeError as error:
                    raise SystemExit(str(_parse_error(path, line_number, str(error)))) from error
                if not line.strip():
                    continue
                try:
                    event = json.loads(line)
                except json.JSONDecodeError as error:
                    raise SystemExit(str(_parse_error(path, line_number, str(error)))) from error
                if not isinstance(event, dict):
                    raise SystemExit(
                        str(
                            _parse_error(
                                path,
                                line_number,
                                "expected a JSON object, got %s" % type(event).__name__,
                            )
                        )
                    )
                event_name = event.get("event")
                if not isinstance(event_name, str) or not event_name.strip():
                    raise SystemExit(
                        str(_parse_error(path, line_number, "missing non-empty string field 'event'"))
                    )
                event["_file"] = str(path)
                events.append(event)
    return events, files


def _checkpoint_values(event: dict[str, Any]) -> tuple[str, str, str, str]:
    fields = _fields(event)
    data = fields.get("data")
    data = data if isinstance(data, dict) else {}
    checkpoint_name = fields.get("name")
    test_name = data.get("test_name", fields.get("test_name", checkpoint_name or ""))
    result = data.get("result", fields.get("result", ""))
    notes = data.get("notes", fields.get("notes", ""))
    return (
        _text(checkpoint_name),
        _text(test_name),
        _text(result),
        _text(notes),
    )


def report(events: list[dict], files: list[Path], directory: Path) -> str:
    sessions = Counter(_text(event.get("session_id"), "unknown") for event in events)
    event_counts = Counter(_text(event.get("event"), "unknown") for event in events)
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
    lines.extend(f"| `{_cell(name)}` | {count} |" for name, count in sorted(event_counts.items()))
    lines.extend(
        [
            "",
            "## Sessions",
            "",
            "| Session | First event | Last event | Events |",
            "| --- | --- | --- | ---: |",
        ]
    )
    for session_id in sorted(sessions):
        session_events = [
            event for event in events if _text(event.get("session_id"), "unknown") == session_id
        ]
        lines.append(
            f"| `{_cell(session_id)}` | {_cell(session_events[0].get('timestamp'))} | "
            f"{_cell(session_events[-1].get('timestamp'))} | {len(session_events)} |"
        )

    lines.extend(
        [
            "",
            "## Checkpoints",
            "",
            "| Session | Checkpoint | Test name | Result | Notes | Timestamp |",
            "| --- | --- | --- | --- | --- | --- |",
        ]
    )
    if checkpoints:
        for event in checkpoints:
            checkpoint_name, test_name, result, notes = _checkpoint_values(event)
            lines.append(
                f"| `{_cell(_text(event.get('session_id'), 'unknown'))}` | `{_cell(checkpoint_name)}` | "
                f"`{_cell(test_name)}` | `{_cell(result)}` | {_cell(notes)} | "
                f"{_cell(event.get('timestamp'))} |"
            )
    else:
        lines.append("| No checkpoints recorded. | | | | | |")

    lines.extend(
        [
            "",
            "## Runtime Samples",
            "",
            "| Session | FPS | Frame time (ms) | Memory (MB) | Scene | Timestamp |",
            "| --- | ---: | ---: | ---: | --- | --- |",
        ]
    )
    if samples:
        for event in samples:
            fields = _fields(event)
            lines.append(
                f"| `{_cell(_text(event.get('session_id'), 'unknown'))}` | {_cell(fields.get('fps'))} | "
                f"{_cell(fields.get('frame_time_ms'))} | {_cell(fields.get('memory_mb'))} | "
                f"{_cell(fields.get('scene', event.get('scene')))} | {_cell(event.get('timestamp'))} |"
            )
    else:
        lines.append("| No runtime samples recorded. | | | | | |")

    lines.extend(
        [
            "",
            "## Warning/Error Messages",
            "",
            "| Session | Level | Context | Message | Timestamp |",
            "| --- | --- | --- | --- | --- |",
        ]
    )
    if warnings:
        for event in warnings:
            fields = _fields(event)
            lines.append(
                f"| `{_cell(_text(event.get('session_id'), 'unknown'))}` | {_cell(fields.get('level'))} | "
                f"{_cell(fields.get('context'))} | {_cell(fields.get('message'))} | "
                f"{_cell(event.get('timestamp'))} |"
            )
    else:
        lines.append("| No warning/error messages recorded. | | | | |")

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
