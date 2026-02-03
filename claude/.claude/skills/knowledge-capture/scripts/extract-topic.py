#!/usr/bin/env python3
"""
Extract topic from a file using LLM inference.
Caches results to avoid repeated API calls.
"""

import json
import hashlib
import sys
from pathlib import Path
from datetime import datetime

CACHE_FILE = Path.home() / ".claude" / "knowledge" / "file-topics.json"


def load_cache() -> dict:
    """Load topic cache."""
    if CACHE_FILE.exists():
        try:
            return json.loads(CACHE_FILE.read_text())
        except json.JSONDecodeError:
            return {}
    return {}


def save_cache(cache: dict):
    """Save topic cache."""
    CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
    CACHE_FILE.write_text(json.dumps(cache, indent=2))


def get_file_hash(file_path: str) -> str:
    """Get hash of file for cache invalidation."""
    content = Path(file_path).read_text()
    return hashlib.md5(content.encode()).hexdigest()[:12]


def get_cached_topic(file_path: str) -> str | None:
    """Get cached topic for file if valid."""
    cache = load_cache()
    file_key = str(Path(file_path).resolve())

    if file_key in cache:
        entry = cache[file_key]
        current_hash = get_file_hash(file_path)
        if entry.get("hash") == current_hash:
            return entry.get("topic")
    return None


def set_cached_topic(file_path: str, topic: str):
    """Cache topic for file."""
    cache = load_cache()
    file_key = str(Path(file_path).resolve())

    cache[file_key] = {
        "topic": topic,
        "hash": get_file_hash(file_path),
        "updated": datetime.now().isoformat()
    }
    save_cache(cache)


def extract_topic_prompt(file_content: str) -> str:
    """Generate prompt for topic extraction."""
    # Limit content to first ~100 lines or 4000 chars
    lines = file_content.split('\n')[:100]
    truncated = '\n'.join(lines)[:4000]

    return f"""Analyze this document and identify the main topic/subject being discussed.

Look for:
- What specific feature, entity, or concept is this about?
- If abbreviations like SR, PA, CC are used, what do they refer to specifically?
- What type of ServiceRecord, PaymentArrangement, etc. is being discussed?

Document:
```
{truncated}
```

Respond with ONLY the topic in 2-5 words. Examples:
- "Contribution Return SR"
- "Surrender ServiceRecord"
- "HK Payment Rules"
- "User Authentication"

Topic:"""


def main():
    if len(sys.argv) < 2:
        print("Usage: extract-topic.py <file_path> [--no-cache]", file=sys.stderr)
        sys.exit(1)

    file_path = sys.argv[1]
    no_cache = "--no-cache" in sys.argv

    if not Path(file_path).exists():
        print(f"File not found: {file_path}", file=sys.stderr)
        sys.exit(1)

    # Check cache first
    if not no_cache:
        cached = get_cached_topic(file_path)
        if cached:
            print(cached)
            return

    # Read file and generate prompt
    content = Path(file_path).read_text()
    prompt = extract_topic_prompt(content)

    # Output prompt for LLM processing
    # This script outputs the prompt; caller sends to LLM
    print(json.dumps({
        "action": "extract_topic",
        "file_path": file_path,
        "prompt": prompt
    }))


if __name__ == "__main__":
    main()
