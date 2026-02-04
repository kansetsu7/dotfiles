#!/usr/bin/env python3
"""
Knowledge CLI - Manage captured knowledge from knowledge-capture
"""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

# Paths
KNOWLEDGE_BASE = Path.home() / ".claude" / "knowledge"
SKILL_DIR = Path(__file__).parent.parent
CONFIG_FILE = SKILL_DIR / "config.json"

DOMAINS = ["business-logic", "testing", "site-specific", "architecture", "workflow"]


def get_project() -> str:
    """Detect project from git root, apply aliases."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True
        )
        git_root = Path(result.stdout.strip()).name
        aliases = load_config().get("projects", {}).get("aliases", {})
        return aliases.get(git_root, git_root)
    except Exception:
        return "_global"


def get_project_base() -> Path:
    """Get knowledge base path for current project."""
    return KNOWLEDGE_BASE / get_project()


def get_signals_file() -> Path:
    """Get signals file path for current project."""
    return get_project_base() / "signals.jsonl"


def load_config() -> dict:
    """Load skill configuration."""
    if CONFIG_FILE.exists():
        with open(CONFIG_FILE) as f:
            return json.load(f)
    return {}


def load_signals() -> list[dict]:
    """Load all knowledge signals for current project."""
    signals = []
    signals_file = get_signals_file()
    if signals_file.exists():
        with open(signals_file) as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        signals.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue
    return signals


def load_knowledge_files() -> list[dict]:
    """Load all knowledge files from domain directories for current project."""
    knowledge = []
    project_base = get_project_base()

    for domain in DOMAINS:
        domain_path = project_base / domain
        if not domain_path.exists():
            continue

        for file in domain_path.glob("*.md"):
            content = file.read_text()
            metadata = parse_frontmatter(content)
            metadata["_file"] = str(file)
            metadata["_domain"] = domain
            metadata["_content"] = content
            knowledge.append(metadata)

    return knowledge


def parse_frontmatter(content: str) -> dict:
    """Parse YAML frontmatter from markdown file."""
    metadata = {}

    if content.startswith("---"):
        parts = content.split("---", 2)
        if len(parts) >= 3:
            frontmatter = parts[1].strip()
            for line in frontmatter.split("\n"):
                if ":" in line:
                    key, value = line.split(":", 1)
                    key = key.strip()
                    value = value.strip()
                    # Parse lists
                    if value.startswith("[") and value.endswith("]"):
                        value = [v.strip() for v in value[1:-1].split(",")]
                    # Parse numbers
                    elif re.match(r"^[\d.]+$", value):
                        value = float(value) if "." in value else int(value)
                    metadata[key] = value

    return metadata


def cmd_status(args):
    """Show knowledge status by domain."""
    config = load_config()
    project = get_project()
    knowledge = load_knowledge_files()
    signals = load_signals()

    # Count pending signals
    pending = sum(1 for s in signals if not s.get("processed", False))

    print("=" * 60)
    print("KNOWLEDGE STATUS")
    print("=" * 60)
    print()
    print(f"Project: {project}")
    print(f"Path: {get_project_base()}")
    print()

    if pending > 0:
        print(f"Pending signals: {pending}")
        print()

    # Group by domain
    by_domain = {}
    for item in knowledge:
        domain = item.get("_domain", "unknown")
        if domain not in by_domain:
            by_domain[domain] = []
        by_domain[domain].append(item)

    stale_days = config.get("knowledge", {}).get("stale_days", 90)
    stale_cutoff = datetime.now() - timedelta(days=stale_days)

    total_count = 0
    stale_count = 0
    low_confidence = 0

    for domain in DOMAINS:
        items = by_domain.get(domain, [])
        if not items:
            print(f"{domain}/")
            print("  (empty)")
            print()
            continue

        print(f"{domain}/ ({len(items)} items)")

        for item in sorted(items, key=lambda x: x.get("confidence", 0), reverse=True):
            item_id = item.get("id", Path(item["_file"]).stem)
            confidence = item.get("confidence", 0.5)
            last_validated = item.get("last_validated", "")

            # Check staleness
            is_stale = False
            if last_validated:
                try:
                    validated_date = datetime.fromisoformat(last_validated)
                    is_stale = validated_date < stale_cutoff
                except ValueError:
                    pass

            # Status indicators
            indicators = []
            if confidence < 0.5:
                indicators.append("LOW")
                low_confidence += 1
            if is_stale:
                indicators.append("STALE")
                stale_count += 1

            status = f" [{', '.join(indicators)}]" if indicators else ""
            sites = item.get("sites", [])
            sites_str = f" [{', '.join(sites)}]" if sites else ""

            print(f"  {item_id}: {confidence:.1f}{sites_str}{status}")
            total_count += 1

        print()

    # Summary
    print("-" * 60)
    print(f"Total: {total_count} | Stale: {stale_count} | Low confidence: {low_confidence}")

    if pending > 0:
        print(f"\nRun 'knowledge-cli.py process' to extract pending signals")


def cmd_search(args):
    """Search knowledge content."""
    query = args.query.lower()
    knowledge = load_knowledge_files()

    matches = []
    for item in knowledge:
        content = item.get("_content", "").lower()
        item_id = item.get("id", Path(item["_file"]).stem).lower()

        if query in content or query in item_id:
            matches.append(item)

    if not matches:
        print(f"No matches for '{args.query}'")
        return

    print(f"Found {len(matches)} matches for '{args.query}':")
    print()

    for item in matches:
        item_id = item.get("id", Path(item["_file"]).stem)
        domain = item.get("_domain", "unknown")
        confidence = item.get("confidence", 0.5)

        print(f"  {domain}/{item_id} (confidence: {confidence:.1f})")
        print(f"    File: {item['_file']}")

        # Show matching context
        content = item.get("_content", "")
        for line in content.split("\n"):
            if query in line.lower():
                print(f"    > {line.strip()[:70]}...")
                break
        print()


def cmd_review(args):
    """Show items needing review (stale or low confidence)."""
    config = load_config()
    knowledge = load_knowledge_files()

    stale_days = config.get("knowledge", {}).get("stale_days", 90)
    stale_cutoff = datetime.now() - timedelta(days=stale_days)

    needs_review = []

    for item in knowledge:
        confidence = item.get("confidence", 0.5)
        last_validated = item.get("last_validated", "")

        is_stale = False
        if last_validated:
            try:
                validated_date = datetime.fromisoformat(last_validated)
                is_stale = validated_date < stale_cutoff
            except ValueError:
                is_stale = True
        else:
            is_stale = True

        if confidence < 0.5 or is_stale:
            item["_reason"] = []
            if confidence < 0.5:
                item["_reason"].append(f"low confidence ({confidence:.1f})")
            if is_stale:
                item["_reason"].append("stale")
            needs_review.append(item)

    if not needs_review:
        print("No items need review!")
        return

    print(f"Items needing review: {len(needs_review)}")
    print()

    for item in needs_review:
        item_id = item.get("id", Path(item["_file"]).stem)
        domain = item.get("_domain", "unknown")
        reasons = ", ".join(item["_reason"])

        print(f"  {domain}/{item_id}")
        print(f"    Reason: {reasons}")
        print(f"    File: {item['_file']}")
        print()


def cmd_validate(args):
    """Validate a knowledge item (bump confidence and update timestamp)."""
    item_id = args.id
    knowledge = load_knowledge_files()

    # Find matching item
    target = None
    for item in knowledge:
        if item.get("id") == item_id or Path(item["_file"]).stem == item_id:
            target = item
            break

    if not target:
        print(f"Knowledge item not found: {item_id}")
        sys.exit(1)

    file_path = Path(target["_file"])
    content = file_path.read_text()

    # Update frontmatter
    today = datetime.now().strftime("%Y-%m-%d")
    new_confidence = min(1.0, target.get("confidence", 0.6) + 0.1)

    # Update last_validated
    if "last_validated:" in content:
        content = re.sub(
            r"last_validated:.*",
            f"last_validated: {today}",
            content
        )
    else:
        content = content.replace("---\n\n", f"last_validated: {today}\n---\n\n", 1)

    # Update confidence
    if "confidence:" in content:
        content = re.sub(
            r"confidence:.*",
            f"confidence: {new_confidence}",
            content
        )

    file_path.write_text(content)
    print(f"Validated {item_id}: confidence {new_confidence:.1f}, last_validated {today}")


def cmd_signals(args):
    """Show pending signals."""
    signals = load_signals()
    pending = [s for s in signals if not s.get("processed", False)]

    if not pending:
        print("No pending signals")
        return

    print(f"Pending signals: {len(pending)}")
    print()

    verbose = getattr(args, 'verbose', False)

    for i, signal in enumerate(pending[-10:], 1):  # Show last 10
        signal_type = signal.get("signal_type", "unknown")
        timestamp = signal.get("timestamp", "")[:19]
        content = signal.get("content", "")[:80]
        source_file = signal.get("source_file")
        file_topic = signal.get("file_topic")
        context = signal.get("context", {})

        print(f"{i}. [{signal_type}] {timestamp}")
        print(f"   {content}...")

        if source_file:
            print(f"   Source: {source_file}")

        if file_topic:
            print(f"   Topic: {file_topic}")
        elif verbose and context:
            ctx_before = context.get("before", "")
            if ctx_before:
                # Look for topic hints in context
                lines = ctx_before.split("\n")
                for line in lines:
                    line_lower = line.lower()
                    # Look for full SR type mentions
                    if " sr " in line_lower or line_lower.endswith(" sr"):
                        for sr_type in ["contribution return", "surrender", "maturity", "reinstatement"]:
                            if sr_type in line_lower:
                                print(f"   Topic hint: {sr_type.title()} SR")
                                break
                        break
        print()


def cmd_scan(args):
    """Scan a file for knowledge signals with a specified topic."""
    file_path = args.file
    topic = args.topic
    clear = getattr(args, 'clear', False)
    project = get_project()
    signals_file = get_signals_file()

    if not Path(file_path).exists():
        print(f"File not found: {file_path}")
        sys.exit(1)

    # Clear existing signals if requested
    if clear and signals_file.exists():
        signals_file.unlink()

    # Read file content
    content = Path(file_path).read_text()
    lines = content.split('\n')

    # Load detection patterns from config
    config = load_config()
    patterns = config.get("detection", {}).get("patterns", {})
    all_patterns = (
        patterns.get("explicit", []) +
        patterns.get("domain", []) +
        patterns.get("correction", [])
    )

    hook_script = SKILL_DIR / "hooks" / "detect-knowledge.sh"
    signals_found = 0

    print(f"Scanning: {file_path}")
    print(f"Topic: {topic}")
    print(f"Project: {project}")
    print()

    for line_num, line in enumerate(lines, 1):
        line = line.strip()
        if not line or len(line) < 10:
            continue

        # Check if line matches any pattern
        matched = False
        for pattern in all_patterns:
            try:
                if re.search(pattern, line, re.IGNORECASE):
                    matched = True
                    break
            except re.error:
                continue

        if matched:
            # Send to hook with topic and project
            payload = json.dumps({
                "user_message": line,
                "source_file": str(Path(file_path).resolve()),
                "line_number": line_num,
                "file_topic": topic,
                "project": project
            })

            try:
                result = subprocess.run(
                    [str(hook_script)],
                    input=payload,
                    capture_output=True,
                    text=True
                )
                if "signal_detected" in result.stderr:
                    signals_found += 1
                    print(f"  [{line_num}] {line[:70]}...")
            except Exception as e:
                print(f"  Error processing line {line_num}: {e}", file=sys.stderr)

    print()
    print(f"Signals captured: {signals_found}")


def main():
    parser = argparse.ArgumentParser(
        description="Manage captured knowledge",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # status
    status_parser = subparsers.add_parser("status", help="Show knowledge status by domain")
    status_parser.set_defaults(func=cmd_status)

    # search
    search_parser = subparsers.add_parser("search", help="Search knowledge content")
    search_parser.add_argument("query", help="Search query")
    search_parser.set_defaults(func=cmd_search)

    # review
    review_parser = subparsers.add_parser("review", help="Show items needing review")
    review_parser.set_defaults(func=cmd_review)

    # validate
    validate_parser = subparsers.add_parser("validate", help="Validate a knowledge item")
    validate_parser.add_argument("id", help="Knowledge item ID")
    validate_parser.set_defaults(func=cmd_validate)

    # signals
    signals_parser = subparsers.add_parser("signals", help="Show pending signals")
    signals_parser.add_argument("-v", "--verbose", action="store_true", help="Show context and topic hints")
    signals_parser.set_defaults(func=cmd_signals)

    # scan
    scan_parser = subparsers.add_parser("scan", help="Scan a file for knowledge signals")
    scan_parser.add_argument("file", help="File to scan")
    scan_parser.add_argument("-t", "--topic", required=True, help="Topic for all signals (e.g., 'Contribution Return SR')")
    scan_parser.add_argument("-c", "--clear", action="store_true", help="Clear existing signals before scanning")
    scan_parser.set_defaults(func=cmd_scan)

    args = parser.parse_args()

    if args.command is None:
        parser.print_help()
        sys.exit(1)

    args.func(args)


if __name__ == "__main__":
    main()
