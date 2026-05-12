#!/usr/bin/env python3
"""Derive a SeedX project folder name.

The target shape is:
  english-topic-slug-yymmdd-HHMMSS
"""

from __future__ import annotations

import argparse
import re
from datetime import datetime
from pathlib import Path


TIMESTAMP_RE = re.compile(r"(?P<ts>\d{6}-\d{6})")
STOPWORDS = {
    "a",
    "an",
    "and",
    "are",
    "as",
    "be",
    "for",
    "from",
    "how",
    "i",
    "in",
    "is",
    "it",
    "of",
    "on",
    "or",
    "should",
    "the",
    "to",
    "use",
    "what",
    "when",
    "where",
    "why",
    "with",
}

TOPIC_PATTERNS = [
    (("meme", "\u8868\u60c5\u5305", "\u6897"), "meme"),
    (("ai agent", "ai-agent", "\u667a\u80fd\u4f53"), "ai-agent"),
    (("agent", "\u4ee3\u7406"), "agent"),
    (("\u65f6\u4ee3", "era"), "era"),
    (("\u5feb\u901f\u5b66\u4e60", "fast learning", "fast-learning"), "fast-learning"),
    (("\u5b66\u4e60", "learning"), "learning"),
    (("\u5f00\u53d1", "\u6784\u5efa", "development", "develop", "build"), "development"),
    (("\u7206\u6b3e", "viral"), "viral"),
    (("\u8bb0\u5fc6", "memory"), "memory"),
    (("\u5de5\u7a0b", "engineering"), "engineering"),
    (("harness", "\u7f16\u6392\u5668"), "harness"),
    (("\u63d0\u793a\u8bcd", "prompt"), "prompt"),
    (("\u8bc4\u4f30", "evaluation", "review"), "evaluation"),
    (("\u53ef\u89c6\u5316", "visualization", "visualizer"), "visualization"),
    (("\u4e2a\u4eba", "personal"), "personal"),
    (("\u5e94\u5bf9", "\u9762\u5bf9", "strategy"), "strategy"),
]


def slugify(text: str) -> str:
    words = re.findall(r"[a-zA-Z][a-zA-Z0-9]+", text.lower())
    filtered = [word for word in words if word not in STOPWORDS]
    return "-".join(filtered[:5])


def clean_slug(text: str) -> str:
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    text = re.sub(r"-+", "-", text).strip("-")
    return text


def timestamp_from_path(path: Path) -> str:
    match = TIMESTAMP_RE.search(path.stem)
    if match:
        return match.group("ts")

    if path.exists():
        return datetime.fromtimestamp(path.stat().st_mtime).strftime("%y%m%d-%H%M%S")

    return datetime.now().strftime("%y%m%d-%H%M%S")


def slug_from_filename(path: Path, timestamp: str) -> str:
    stem = path.stem
    for prefix in ("question-source-", "question-", "source-"):
        if stem.startswith(prefix):
            stem = stem[len(prefix) :]
            break

    stem = re.sub(rf"-?{re.escape(timestamp)}$", "", stem)
    stem = clean_slug(stem)
    if not stem or stem == "question" or re.fullmatch(r"\d+", stem.replace("-", "")):
        return ""
    return stem


def first_meaningful_line(body: str) -> str:
    for raw_line in body.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("#"):
            line = line.lstrip("#").strip()
        return line
    return ""


def slug_from_body(body: str) -> str:
    lowered = body.lower()

    if ("meme" in lowered or "\u8868\u60c5\u5305" in body or "\u6897" in body) and (
        "ai agent" in lowered or "ai-agent" in lowered or "agent" in lowered or "\u667a\u80fd\u4f53" in body
    ):
        return "meme-ai-agent"

    if ("agent" in lowered or "\u667a\u80fd\u4f53" in body) and "\u65f6\u4ee3" in body and (
        "\u5feb\u901f\u5b66\u4e60" in body or "fast learning" in lowered or "fast-learning" in lowered
    ):
        return "agent-era-fast-learning"

    matched: list[str] = []
    for patterns, token in TOPIC_PATTERNS:
        if any(pattern in lowered or pattern in body for pattern in patterns):
            if token == "agent" and "ai-agent" in matched:
                continue
            if token not in matched:
                matched.append(token)
        if len(matched) >= 4:
            break

    if matched:
        return "-".join(matched)

    return slugify(first_meaningful_line(body))


def derive_project_name(path: Path) -> str:
    timestamp = timestamp_from_path(path)
    slug = slug_from_filename(path, timestamp)

    if not slug and path.exists():
        slug = slug_from_body(path.read_text(encoding="utf-8", errors="ignore"))

    if not slug:
        slug = "learning-question"

    slug = clean_slug(slug) or "learning-question"
    if slug.endswith(f"-{timestamp}"):
        return slug
    return f"{slug}-{timestamp}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", help="Question markdown path")
    args = parser.parse_args()

    print(derive_project_name(Path(args.path)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
