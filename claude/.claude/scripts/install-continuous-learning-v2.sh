#!/bin/bash
# Install continuous-learning-v2 for Claude Code
#
# Usage:
#   ./install-continuous-learning-v2.sh                    # Install to ~/.claude
#   ./install-continuous-learning-v2.sh /path/to/project   # Install to project .claude
#
# Source repo: https://github.com/anthropics/everything-claude-code

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Determine installation target
TARGET_DIR="${1:-$HOME}/.claude"
HOMUNCULUS_DIR="$HOME/.claude/homunculus"

# Source directory - check multiple locations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR=""

# Try to find source files
for candidate in \
    "$SCRIPT_DIR/../skills/continuous-learning-v2" \
    "$HOME/.dotfiles/claude/.claude/skills/continuous-learning-v2" \
    "/project/everything-claude-code/skills/continuous-learning-v2" \
    "./skills/continuous-learning-v2"; do
    if [[ -f "$candidate/hooks/observe.sh" ]]; then
        SOURCE_DIR="$candidate"
        break
    fi
done

# Commands source
COMMANDS_SOURCE=""
for candidate in \
    "$SCRIPT_DIR/../commands" \
    "$HOME/.dotfiles/claude/.claude/commands" \
    "/project/everything-claude-code/commands"; do
    if [[ -f "$candidate/evolve.md" ]]; then
        COMMANDS_SOURCE="$candidate"
        break
    fi
done

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║       Continuous Learning v2 - Installation Script         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check Python 3
if ! command -v python3 &> /dev/null; then
    error "Python 3 is required but not installed"
fi
success "Python 3 found: $(python3 --version)"

# Validate source
if [[ -z "$SOURCE_DIR" ]]; then
    error "Cannot find continuous-learning-v2 source files.

Expected structure:
  skills/continuous-learning-v2/
  ├── hooks/observe.sh
  ├── scripts/instinct-cli.py
  └── config.json

Please run from the everything-claude-code repo or ensure files exist."
fi

info "Source directory: $SOURCE_DIR"
info "Target directory: $TARGET_DIR"
info "Homunculus data:  $HOMUNCULUS_DIR"
echo ""

# Create directory structure
info "Creating directory structure..."
mkdir -p "$TARGET_DIR/skills/continuous-learning-v2/hooks"
mkdir -p "$TARGET_DIR/skills/continuous-learning-v2/scripts"
mkdir -p "$TARGET_DIR/skills/continuous-learning-v2/agents"
mkdir -p "$TARGET_DIR/commands"
mkdir -p "$HOMUNCULUS_DIR/instincts/personal"
mkdir -p "$HOMUNCULUS_DIR/instincts/inherited"
mkdir -p "$HOMUNCULUS_DIR/evolved/skills"
mkdir -p "$HOMUNCULUS_DIR/evolved/commands"
mkdir -p "$HOMUNCULUS_DIR/evolved/agents"
mkdir -p "$HOMUNCULUS_DIR/observations.archive"
success "Directories created"

# Copy core files
info "Copying core files..."

cp "$SOURCE_DIR/hooks/observe.sh" "$TARGET_DIR/skills/continuous-learning-v2/hooks/"
chmod +x "$TARGET_DIR/skills/continuous-learning-v2/hooks/observe.sh"
success "  hooks/observe.sh"

cp "$SOURCE_DIR/scripts/instinct-cli.py" "$TARGET_DIR/skills/continuous-learning-v2/scripts/"
chmod +x "$TARGET_DIR/skills/continuous-learning-v2/scripts/instinct-cli.py"
success "  scripts/instinct-cli.py"

cp "$SOURCE_DIR/config.json" "$TARGET_DIR/skills/continuous-learning-v2/"
success "  config.json"

# Copy optional files if they exist
[[ -f "$SOURCE_DIR/SKILL.md" ]] && cp "$SOURCE_DIR/SKILL.md" "$TARGET_DIR/skills/continuous-learning-v2/"
[[ -f "$SOURCE_DIR/agents/observer.md" ]] && cp "$SOURCE_DIR/agents/observer.md" "$TARGET_DIR/skills/continuous-learning-v2/agents/"

# Copy commands if source found
if [[ -n "$COMMANDS_SOURCE" ]]; then
    info "Copying slash commands..."
    for cmd in evolve instinct-status instinct-export instinct-import; do
        if [[ -f "$COMMANDS_SOURCE/$cmd.md" ]]; then
            cp "$COMMANDS_SOURCE/$cmd.md" "$TARGET_DIR/commands/"
            success "  commands/$cmd.md"
        fi
    done
else
    warn "Commands source not found - skipping slash commands"
    warn "You can run the CLI directly: python3 ~/.claude/skills/continuous-learning-v2/scripts/instinct-cli.py"
fi

# Initialize observations file
touch "$HOMUNCULUS_DIR/observations.jsonl"
success "Initialized observations.jsonl"

# Generate hooks config snippet
HOOKS_CONFIG=$(cat <<'EOF'
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "~/.claude/skills/continuous-learning-v2/hooks/observe.sh pre"
      }]
    }],
    "PostToolUse": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "~/.claude/skills/continuous-learning-v2/hooks/observe.sh post"
      }]
    }]
  }
}
EOF
)

# Check if settings.json exists and needs updating
SETTINGS_FILE="$TARGET_DIR/settings.json"
echo ""
echo "────────────────────────────────────────────────────────────"
echo ""

if [[ -f "$SETTINGS_FILE" ]]; then
    if grep -q "continuous-learning-v2" "$SETTINGS_FILE" 2>/dev/null; then
        success "Hooks already configured in settings.json"
    else
        warn "settings.json exists but hooks not configured"
        echo ""
        echo "Add the following to your $SETTINGS_FILE:"
        echo ""
        echo -e "${YELLOW}$HOOKS_CONFIG${NC}"
    fi
else
    info "Creating settings.json with hooks configuration..."
    echo "$HOOKS_CONFIG" > "$SETTINGS_FILE"
    success "Created settings.json"
fi

echo ""
echo "────────────────────────────────────────────────────────────"
echo ""
success "Installation complete!"
echo ""
echo "Installed files:"
echo "  $TARGET_DIR/skills/continuous-learning-v2/"
echo "  $TARGET_DIR/commands/ (if available)"
echo "  $HOMUNCULUS_DIR/"
echo ""
echo "Usage:"
echo "  /instinct-status     - View learned instincts"
echo "  /evolve              - Cluster instincts into skills"
echo "  /instinct-export     - Export for sharing"
echo "  /instinct-import     - Import from others"
echo ""
echo "Or use CLI directly:"
echo "  python3 ~/.claude/skills/continuous-learning-v2/scripts/instinct-cli.py status"
echo ""
echo "To disable temporarily:"
echo "  touch ~/.claude/homunculus/disabled"
echo ""
