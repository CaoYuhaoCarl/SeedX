#!/usr/bin/env python3
"""Validate `_run/state.json` and `_run/events.jsonl` against schemas + protocol.

Usage:
    python3 tools/validate-run.py OUTPUT_DIR

Exits non-zero when any finding is reported.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterator

REPO_ROOT = Path(__file__).resolve().parent.parent
SCHEMA_DIR = REPO_ROOT / "docs" / "specs"


@dataclass(frozen=True)
class Finding:
    file: str
    line: int | None
    kind: str  # "schema" or "protocol"
    pointer: str
    message: str

    def format(self) -> str:
        loc = self.file if self.line is None else f"{self.file}:{self.line}"
        ptr = f" {self.pointer}" if self.pointer else ""
        return f"{loc}: {self.kind}:{ptr} {self.message}"


# ---------------------------------------------------------------------------
# Minimal JSON Schema validator (subset used by our two schemas).
# ---------------------------------------------------------------------------


class SchemaValidator:
    """Validate against the JSON Schema subset used in docs/specs/*.schema.json.

    Supported keywords: type, required, properties, additionalProperties,
    patternProperties, items, minItems, enum, const, pattern, minLength,
    minimum, oneOf, $ref (local), $defs.
    """

    def __init__(self, schema: dict[str, Any]):
        self.schema = schema

    def errors(self, instance: Any) -> Iterator[tuple[str, str]]:
        yield from self._check(instance, self.schema, "")

    def _check(self, inst: Any, schema: dict[str, Any], pointer: str) -> Iterator[tuple[str, str]]:
        if "$ref" in schema:
            schema = self._resolve(schema["$ref"])

        if "type" in schema:
            types = schema["type"]
            if isinstance(types, str):
                types = [types]
            if not any(self._type_match(inst, t) for t in types):
                yield pointer, f"expected type {types}, got {self._type_name(inst)}"
                return

        if "const" in schema and inst != schema["const"]:
            yield pointer, f"expected const {schema['const']!r}, got {inst!r}"

        if "enum" in schema and inst not in schema["enum"]:
            yield pointer, f"value {inst!r} not in enum {schema['enum']}"

        if isinstance(inst, str):
            if "pattern" in schema and not re.search(schema["pattern"], inst):
                yield pointer, f"string does not match pattern {schema['pattern']!r}"
            if "minLength" in schema and len(inst) < schema["minLength"]:
                yield pointer, f"string shorter than minLength {schema['minLength']}"

        if isinstance(inst, (int, float)) and not isinstance(inst, bool):
            if "minimum" in schema and inst < schema["minimum"]:
                yield pointer, f"value {inst} < minimum {schema['minimum']}"

        if isinstance(inst, list):
            if "minItems" in schema and len(inst) < schema["minItems"]:
                yield pointer, f"array shorter than minItems {schema['minItems']}"
            if "items" in schema:
                for i, v in enumerate(inst):
                    yield from self._check(v, schema["items"], f"{pointer}[{i}]")

        if isinstance(inst, dict):
            for r in schema.get("required", []):
                if r not in inst:
                    yield pointer, f"missing required field {r!r}"
            props = schema.get("properties", {})
            pat_props = schema.get("patternProperties", {})
            additional = schema.get("additionalProperties", True)
            for k, v in inst.items():
                child_ptr = f"{pointer}.{k}" if pointer else k
                handled = False
                if k in props:
                    handled = True
                    yield from self._check(v, props[k], child_ptr)
                for pat, sub in pat_props.items():
                    if re.search(pat, k):
                        handled = True
                        yield from self._check(v, sub, child_ptr)
                if not handled and additional is False:
                    yield pointer, f"unexpected property {k!r}"

        if "oneOf" in schema:
            yield from self._check_one_of(inst, schema["oneOf"], pointer)

    def _check_one_of(
        self, inst: Any, variants: list[dict[str, Any]], pointer: str
    ) -> Iterator[tuple[str, str]]:
        # Discriminator: when instance is an object with a `type` field that
        # matches some variant's properties.type.const, validate against that
        # variant. Otherwise fall back to "try all, exactly-one-must-pass".
        disc_idx = self._find_discriminator(inst, variants)
        if disc_idx is not None:
            yield from self._check(inst, variants[disc_idx], pointer)
            return

        matches: list[int] = []
        first_errors: list[tuple[int, list[tuple[str, str]]]] = []
        for i, sub in enumerate(variants):
            errs = list(self._check(inst, sub, pointer))
            if not errs:
                matches.append(i)
            else:
                first_errors.append((i, errs))
        if len(matches) == 1:
            return
        if not matches:
            yield pointer, "value does not match any oneOf variant"
            return
        yield pointer, f"value matched multiple oneOf variants: {matches}"

    def _find_discriminator(
        self, inst: Any, variants: list[dict[str, Any]]
    ) -> int | None:
        if not isinstance(inst, dict) or "type" not in inst:
            return None
        for i, sub in enumerate(variants):
            const = sub.get("properties", {}).get("type", {}).get("const")
            if const == inst["type"]:
                return i
        return None

    def _resolve(self, ref: str) -> dict[str, Any]:
        if not ref.startswith("#/"):
            return {}
        node: Any = self.schema
        for part in ref[2:].split("/"):
            if not isinstance(node, dict):
                return {}
            node = node.get(part, {})
        return node if isinstance(node, dict) else {}

    @staticmethod
    def _type_match(v: Any, t: str) -> bool:
        if t == "object":
            return isinstance(v, dict)
        if t == "array":
            return isinstance(v, list)
        if t == "string":
            return isinstance(v, str)
        if t == "integer":
            return isinstance(v, int) and not isinstance(v, bool)
        if t == "number":
            return isinstance(v, (int, float)) and not isinstance(v, bool)
        if t == "boolean":
            return isinstance(v, bool)
        if t == "null":
            return v is None
        return False

    @staticmethod
    def _type_name(v: Any) -> str:
        if v is None:
            return "null"
        if isinstance(v, bool):
            return "boolean"
        if isinstance(v, int):
            return "integer"
        if isinstance(v, float):
            return "number"
        if isinstance(v, str):
            return "string"
        if isinstance(v, list):
            return "array"
        if isinstance(v, dict):
            return "object"
        return type(v).__name__


# ---------------------------------------------------------------------------
# File loaders
# ---------------------------------------------------------------------------


def load_schema(name: str) -> dict[str, Any]:
    path = SCHEMA_DIR / name
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def load_state(path: Path, findings: list[Finding]) -> dict[str, Any] | None:
    rel = _rel(path)
    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        findings.append(Finding(rel, None, "schema", "", "file not found"))
        return None
    try:
        return json.loads(text)
    except json.JSONDecodeError as e:
        findings.append(Finding(rel, e.lineno, "schema", "", f"JSON parse error: {e.msg}"))
        return None


def load_events(path: Path, findings: list[Finding]) -> list[tuple[int, dict[str, Any]]]:
    rel = _rel(path)
    events: list[tuple[int, dict[str, Any]]] = []
    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        findings.append(Finding(rel, None, "schema", "", "file not found"))
        return events
    for i, raw in enumerate(text.splitlines(), start=1):
        line = raw.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError as e:
            findings.append(Finding(rel, i, "schema", "", f"JSON parse error: {e.msg}"))
            continue
        if not isinstance(obj, dict):
            findings.append(Finding(rel, i, "schema", "", "event must be a JSON object"))
            continue
        events.append((i, obj))
    return events


def _rel(path: Path) -> str:
    try:
        return str(path.relative_to(Path.cwd()))
    except ValueError:
        return str(path)


# ---------------------------------------------------------------------------
# Protocol checks
# ---------------------------------------------------------------------------


LIFECYCLE_TYPES = {"agent_finished", "agent_resumed", "evaluation_finished"}


def protocol_checks(
    events: list[tuple[int, dict[str, Any]]],
    events_rel: str,
    state: dict[str, Any] | None,
    state_rel: str,
) -> list[Finding]:
    findings: list[Finding] = []
    started: set[tuple[str, str]] = set()  # (role, task) seen via agent_started
    project_started_seen = False
    project_finished_line: int | None = None

    for line, ev in events:
        et = ev.get("type")
        if et == "project_started":
            if project_started_seen:
                findings.append(
                    Finding(events_rel, line, "protocol", "type", "duplicate project_started")
                )
            project_started_seen = True
        if et == "project_finished":
            if project_finished_line is not None:
                findings.append(
                    Finding(events_rel, line, "protocol", "type", "duplicate project_finished")
                )
            project_finished_line = line
        elif project_finished_line is not None:
            findings.append(
                Finding(
                    events_rel,
                    line,
                    "protocol",
                    "type",
                    f"event after project_finished (line {project_finished_line})",
                )
            )

        if et == "agent_started":
            role = ev.get("role")
            task = ev.get("task")
            if isinstance(role, str) and isinstance(task, str):
                started.add((role, task))
        elif et in LIFECYCLE_TYPES:
            role = ev.get("role")
            task = ev.get("task")
            if (
                isinstance(role, str)
                and isinstance(task, str)
                and (role, task) not in started
            ):
                findings.append(
                    Finding(
                        events_rel,
                        line,
                        "protocol",
                        "type",
                        f"{et} for role={role!r} task={task!r} with no prior agent_started",
                    )
                )

    if state is not None:
        current = state.get("current_task")
        tasks = state.get("tasks")
        if isinstance(current, str) and isinstance(tasks, dict) and current not in tasks:
            findings.append(
                Finding(
                    state_rel,
                    None,
                    "protocol",
                    "current_task",
                    f"current_task {current!r} not present in tasks",
                )
            )
        if isinstance(tasks, dict):
            for task_id, task in tasks.items():
                if not isinstance(task, dict):
                    continue
                status = task.get("status")
                judgment = task.get("judgment")
                if judgment == "PASS" and status not in ("✅", None):
                    findings.append(
                        Finding(
                            state_rel,
                            None,
                            "protocol",
                            f"tasks.{task_id}",
                            f"judgment=PASS but status={status!r} (expected ✅)",
                        )
                    )
                if judgment == "LOW_QUALITY_PASS" and status not in ("⚠️", None):
                    findings.append(
                        Finding(
                            state_rel,
                            None,
                            "protocol",
                            f"tasks.{task_id}",
                            f"judgment=LOW_QUALITY_PASS but status={status!r} (expected ⚠️)",
                        )
                    )
    return findings


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def validate_run(output_dir: Path) -> list[Finding]:
    findings: list[Finding] = []
    state_path = output_dir / "_run" / "state.json"
    events_path = output_dir / "_run" / "events.jsonl"
    state_rel = _rel(state_path)
    events_rel = _rel(events_path)

    state_schema = SchemaValidator(load_schema("state.schema.json"))
    event_schema = SchemaValidator(load_schema("events.schema.json"))

    state = load_state(state_path, findings)
    if state is not None:
        for ptr, msg in state_schema.errors(state):
            findings.append(Finding(state_rel, None, "schema", ptr, msg))

    events = load_events(events_path, findings)
    for line, ev in events:
        for ptr, msg in event_schema.errors(ev):
            findings.append(Finding(events_rel, line, "schema", ptr, msg))

    findings.extend(protocol_checks(events, events_rel, state, state_rel))
    return findings


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output_dir", type=Path, help="run output directory (contains _run/)")
    args = parser.parse_args(argv)

    if not args.output_dir.is_dir():
        print(f"{args.output_dir}: not a directory", file=sys.stderr)
        return 2

    findings = validate_run(args.output_dir)
    if not findings:
        print(f"{_rel(args.output_dir)}: OK")
        return 0
    for f in findings:
        print(f.format())
    print(f"\n{len(findings)} finding(s) in {_rel(args.output_dir)}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
