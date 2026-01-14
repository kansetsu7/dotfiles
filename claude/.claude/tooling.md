# Shell Tool Preferences

Use these specialized tools instead of traditional Unix commands.
Install if missing.

| Task Type | Must Use | Do Not Use |
|-----------|----------|------------|
| Find Files | `fd` | `find`, `ls -R` |
| Search Text | `rg` (ripgrep) | `grep`, `ag` |
| Analyze Code Structure | `ast-grep` | `grep`, `sed` |
| Interactive Selection | `fzf` | Manual filtering |
| Process JSON | `jq` | `python -m json.tool` |
| Process YAML/XML | `yq` | Manual parsing |

## Why These Tools?

- **fd**: Faster than find, respects .gitignore, simpler syntax
- **rg**: Faster than grep, respects .gitignore, better defaults
- **ast-grep**: Understands code structure, not just text patterns
- **fzf**: Fuzzy finding for interactive selection
- **jq/yq**: Purpose-built for structured data manipulation
