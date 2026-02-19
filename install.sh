#!/bin/bash
# install.sh — Set up Claude CLI configuration for your machine
#
# Usage: ./install.sh
# Safe to re-run — backs up existing config before overwriting.

set -e

DEST="$HOME/.claude"
BACKUP="$HOME/.claude-backup-$(date +%Y%m%d-%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors (skip if not a terminal)
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  RED='\033[0;31m'
  NC='\033[0m'
else
  GREEN='' YELLOW='' RED='' NC=''
fi

info()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo "Claude CLI Configuration Installer"
echo "===================================="
echo ""

# Check Node.js (required for hook scripts)
if ! command -v node &> /dev/null; then
  error "Node.js 16+ is required for hook scripts. Install it first."
fi

NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VERSION" -lt 16 ]; then
  error "Node.js 16+ required. You have $(node -v)."
fi
info "Node.js $(node -v) detected"

# Backup existing config if present
BACKED_UP=false
for dir in agents commands rules scripts; do
  if [ -d "$DEST/$dir" ]; then
    if [ "$BACKED_UP" = false ]; then
      echo ""
      warn "Existing config found. Backing up to $BACKUP"
      mkdir -p "$BACKUP"
      BACKED_UP=true
    fi
    cp -r "$DEST/$dir" "$BACKUP/"
  fi
done

if [ -f "$DEST/settings.json" ]; then
  if [ "$BACKED_UP" = false ]; then
    echo ""
    warn "Existing config found. Backing up to $BACKUP"
    mkdir -p "$BACKUP"
    BACKED_UP=true
  fi
  cp "$DEST/settings.json" "$BACKUP/"
fi

# Create destination
mkdir -p "$DEST"

# Copy directories
echo ""
for dir in agents commands rules scripts; do
  if [ -d "$SCRIPT_DIR/$dir" ]; then
    cp -r "$SCRIPT_DIR/$dir" "$DEST/"
    info "Copied $dir/"
  else
    warn "Missing $dir/ in source — skipped"
  fi
done

# Install hooks into settings.json
if [ -f "$SCRIPT_DIR/hooks/hooks.json" ]; then
  if [ -f "$DEST/settings.json" ]; then
    # Check if existing settings already has hooks
    if node -e "const s=JSON.parse(require('fs').readFileSync('$DEST/settings.json','utf8'));process.exit(s.hooks?0:1)" 2>/dev/null; then
      warn "settings.json already has hooks — replacing hooks section"
    fi
    # Merge: preserve existing settings, overwrite hooks section
    node -e "
      const fs = require('fs');
      const existing = JSON.parse(fs.readFileSync('$DEST/settings.json', 'utf8'));
      const hooks = JSON.parse(fs.readFileSync('$SCRIPT_DIR/hooks/hooks.json', 'utf8'));
      existing.hooks = hooks.hooks;
      fs.writeFileSync('$DEST/settings.json', JSON.stringify(existing, null, 2) + '\n');
    "
    info "Merged hooks into existing settings.json"
  else
    cp "$SCRIPT_DIR/hooks/hooks.json" "$DEST/settings.json"
    info "Created settings.json with hooks"
  fi
else
  warn "Missing hooks/hooks.json — skipped"
fi

# Check CLAUDE_PLUGIN_ROOT
echo ""
if [ -z "$CLAUDE_PLUGIN_ROOT" ]; then
  warn "CLAUDE_PLUGIN_ROOT is not set"
  echo ""
  echo "  Add this to your shell profile (~/.zshrc or ~/.bashrc):"
  echo ""
  echo "    export CLAUDE_PLUGIN_ROOT=\"\$HOME/.claude\""
  echo ""
else
  info "CLAUDE_PLUGIN_ROOT=$CLAUDE_PLUGIN_ROOT"
fi

# Summary
echo ""
echo "===================================="
echo -e "${GREEN}Installation complete.${NC}"
echo ""
echo "Installed to: $DEST"
if [ "$BACKED_UP" = true ]; then
  echo "Backup at:    $BACKUP"
fi
echo ""
echo "What was installed:"
echo "  - 3 rules    (coding-style, security, performance)"
echo "  - 3 commands (/plan, /build-fix, /code-review)"
echo "  - 3 agents   (code-reviewer, build-error-resolver, architect)"
echo "  - 8 hooks    (auto-run at key events)"
echo "  - 8 scripts  (powers the hooks)"
