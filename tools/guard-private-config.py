#!/usr/bin/env python3
"""Block local-only files and private-looking values from commits."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Finding:
    path: str
    reason: str
    line: int | None = None

    def format(self) -> str:
        if self.line is None:
            return f"{self.path}: {self.reason}"
        return f"{self.path}:{self.line}: {self.reason}"


PATH_DENYLIST: tuple[tuple[re.Pattern[str], str], ...] = (
    (re.compile(r"(^|/)\.env(?:$|\.)"), "local environment file"),
    (re.compile(r"(^|/)\.obsidian/workspace.*\.json$"), "Obsidian workspace state"),
    (re.compile(r"(^|/)\.obsidian/plugins(/|$)"), "Obsidian plugin installation"),
    (re.compile(r"(^|/)\.obsidian/themes(/|$)"), "Obsidian theme installation"),
    (re.compile(r"(^|/)\.claudian(/|$)"), "Claudian local state"),
    (re.compile(r"(^|/)\.claude/settings\.local\.json$"), "Claude local settings"),
    (re.compile(r"(^|/)\.claude/agent-memory(/|$)"), "Claude agent memory"),
    (re.compile(r"(^|/).*\.(pem|p12|pfx|key)$", re.IGNORECASE), "private key material"),
)

PATH_ALLOWLIST: set[str] = {
    ".env.example",
}

TOKEN_PATTERNS: tuple[tuple[re.Pattern[bytes], str], ...] = (
    (re.compile(rb"\bsk-(?:proj-|ant-[A-Za-z0-9-]*-)?[A-Za-z0-9_-]{20,}\b"), "provider token"),
    (re.compile(rb"\bAIza[0-9A-Za-z_-]{35}\b"), "provider token"),
    (re.compile(rb"\bgh[pousr]_[A-Za-z0-9_]{20,}\b"), "GitHub token"),
    (re.compile(rb"\bxox[baprs]-[A-Za-z0-9-]{20,}\b"), "Slack token"),
    (re.compile(rb"\bAKIA[0-9A-Z]{16}\b"), "AWS access key"),
    (re.compile(rb"-----BEGIN [A-Z ]*PRIVATE KEY-----"), "private key block"),
)

PRIVATE_FIELD_RE = re.compile(
    rb"""(?ix)
    ["']?
    [A-Za-z0-9_.-]*
    (?:api[_-]?key|token|secret|password|credential|access[_-]?key|private[_-]?key)
    [A-Za-z0-9_.-]*
    ["']?
    \s*[:=]\s*
    (?P<quote>["'])
    (?P<value>[^"'\r\n]{8,})
    (?P=quote)
    """
)

PLACEHOLDER_RE = re.compile(
    rb"""(?ix)
    ^(
      changeme|change-me|example|sample|placeholder|dummy|test|testing|
      your[_-]?[a-z0-9_-]+|xxx+|<[^>]+>|\$\{[^}]+\}|process\.env\.[a-z0-9_]+
    )$
    """
)


def run_git(args: list[str]) -> bytes:
    return subprocess.check_output(["git", *args], stderr=subprocess.DEVNULL)


def staged_paths() -> list[str]:
    raw = run_git(["diff", "--cached", "--name-only", "-z", "--diff-filter=ACMR"])
    return [item.decode("utf-8", "replace") for item in raw.split(b"\0") if item]


def tracked_paths() -> list[str]:
    raw = run_git(["ls-files", "-z"])
    return [item.decode("utf-8", "replace") for item in raw.split(b"\0") if item]


def staged_blob(path: str) -> bytes | None:
    try:
        return run_git(["show", f":{path}"])
    except subprocess.CalledProcessError:
        return None


def working_tree_blob(path: str) -> bytes | None:
    try:
        return Path(path).read_bytes()
    except OSError:
        return None


def line_for_offset(blob: bytes, offset: int) -> int:
    return blob.count(b"\n", 0, offset) + 1


def path_findings(path: str) -> list[Finding]:
    if path in PATH_ALLOWLIST:
        return []

    return [
        Finding(path, reason)
        for pattern, reason in PATH_DENYLIST
        if pattern.search(path)
    ]


def content_findings(path: str, blob: bytes) -> list[Finding]:
    if b"\0" in blob:
        return []

    findings: list[Finding] = []

    for pattern, reason in TOKEN_PATTERNS:
        for match in pattern.finditer(blob):
            findings.append(Finding(path, reason, line_for_offset(blob, match.start())))

    for match in PRIVATE_FIELD_RE.finditer(blob):
        value = match.group("value").strip()
        if PLACEHOLDER_RE.match(value):
            continue
        findings.append(Finding(path, "private-looking configured value", line_for_offset(blob, match.start())))

    return findings


def scan(paths: list[str], *, staged: bool) -> list[Finding]:
    findings: list[Finding] = []
    for path in paths:
        findings.extend(path_findings(path))

        blob = staged_blob(path) if staged else working_tree_blob(path)
        if blob is None:
            continue
        findings.extend(content_findings(path, blob))

    return findings


def main() -> int:
    parser = argparse.ArgumentParser()
    scope = parser.add_mutually_exclusive_group()
    scope.add_argument("--staged", action="store_true", help="scan staged files")
    scope.add_argument("--all", action="store_true", help="scan tracked files")
    args = parser.parse_args()

    staged = not args.all
    paths = staged_paths() if staged else tracked_paths()
    findings = scan(paths, staged=staged)

    if not findings:
        print("private config guard: ok")
        return 0

    print("private config guard: blocked commit", file=sys.stderr)
    for finding in findings:
        print(f"- {finding.format()}", file=sys.stderr)
    print("\nMove local-only values out of Git, then stage the cleanup.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
