#!/usr/bin/env python3
"""
Extract knowledge signals from a file with context.
Test script for knowledge-capture.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

SKILL_DIR = Path(__file__).parent.parent
CONFIG_FILE = SKILL_DIR / "config.json"
HOOK_SCRIPT = SKILL_DIR / "hooks" / "detect-knowledge.sh"


def load_config():
    with open(CONFIG_FILE) as f:
        return json.load(f)


def compile_patterns(config):
    """Compile all detection patterns."""
    patterns = {}
    for signal_type, pattern_list in config["detection"]["patterns"].items():
        patterns[signal_type] = [re.compile(p, re.IGNORECASE) for p in pattern_list]
    return patterns


def detect_signal(line, patterns):
    """Check if a line matches any pattern."""
    for signal_type in ["explicit", "domain", "correction"]:
        for pattern in patterns.get(signal_type, []):
            if pattern.search(line):
                return signal_type, pattern.pattern
    return None, None


def get_context(lines, line_num, before=5, after=2):
    """Get surrounding context lines."""
    start = max(0, line_num - before)
    end = min(len(lines), line_num + after + 1)

    ctx_before = "\n".join(lines[start:line_num])
    ctx_after = "\n".join(lines[line_num:end])

    return ctx_before, ctx_after


def infer_topic(context_before, file_header):
    """Infer the specific topic from context."""
    combined = (file_header + "\n" + context_before).lower()

    # Look for SR type mentions
    sr_types = [
        ("contribution return", "Contribution Return SR"),
        ("surrender", "Surrender SR"),
        ("maturity", "Maturity SR"),
        ("reinstatement", "Reinstatement SR"),
        ("policy loan", "Policy Loan SR"),
    ]

    for pattern, topic in sr_types:
        if f"{pattern} sr" in combined:
            return topic

    # Look for other topic patterns
    if "servicerecord" in combined or "service record" in combined:
        return "ServiceRecord"

    return None


def expand_abbreviations(content, topic):
    """Expand SR abbreviation with inferred topic."""
    if topic and "SR" in topic:
        # Replace standalone SR with full topic
        content = re.sub(r'\bSR\b', topic, content)
    return content


def main():
    if len(sys.argv) < 2:
        print("Usage: extract-from-file.py <file_path>")
        sys.exit(1)

    file_path = Path(sys.argv[1])
    if not file_path.exists():
        print(f"File not found: {file_path}")
        sys.exit(1)

    config = load_config()
    patterns = compile_patterns(config)

    lines = file_path.read_text().split("\n")

    # Get file header (first 10 non-empty lines)
    file_header = "\n".join([l for l in lines[:30] if l.strip()][:10])

    print(f"Scanning: {file_path}")
    print(f"Total lines: {len(lines)}")
    print("=" * 70)
    print()

    signals = []

    for i, line in enumerate(lines):
        signal_type, pattern = detect_signal(line, patterns)
        if signal_type:
            ctx_before, ctx_after = get_context(lines, i)
            topic = infer_topic(ctx_before, file_header)

            signals.append({
                "line_num": i + 1,
                "signal_type": signal_type,
                "content": line.strip(),
                "topic": topic,
                "context_before": ctx_before,
            })

    print(f"Found {len(signals)} knowledge signals")
    print()

    # Group by inferred topic
    by_topic = {}
    for sig in signals:
        topic = sig["topic"] or "General"
        if topic not in by_topic:
            by_topic[topic] = []
        by_topic[topic].append(sig)

    for topic, sigs in by_topic.items():
        print(f"## {topic}")
        print()

        for sig in sigs:
            line_num = sig["line_num"]
            content = sig["content"]
            signal_type = sig["signal_type"]

            # Expand abbreviations
            if sig["topic"]:
                expanded = expand_abbreviations(content, sig["topic"])
            else:
                expanded = content

            print(f"  L{line_num} [{signal_type}]")
            print(f"    Original: {content[:70]}{'...' if len(content) > 70 else ''}")
            if expanded != content:
                print(f"    Expanded: {expanded[:70]}{'...' if len(expanded) > 70 else ''}")
            print()

    print("=" * 70)
    print(f"Summary: {len(signals)} signals across {len(by_topic)} topics")


if __name__ == "__main__":
    main()
