#!/bin/bash
# Meeting Alarm — one-line installer
# Usage: curl -fsSL https://raw.githubusercontent.com/tomersh-ac/tomers-skills/main/install.sh | bash

set -e

REPO="https://raw.githubusercontent.com/tomersh-ac/tomers-skills/main"
SKILL_DIR="$HOME/.claude/skills/meeting-alarm"

echo ""
echo "=== Installing Meeting Alarm skill ==="
echo ""

# Check Claude Code is installed
if [ ! -d "$HOME/.claude" ]; then
    echo "✗ Claude Code not found. Install it from https://claude.ai/download first."
    exit 1
fi

mkdir -p "$SKILL_DIR/scripts"

echo "► Downloading skill files..."
curl -fsSL "$REPO/meeting-alarm/SKILL.md"                  -o "$SKILL_DIR/SKILL.md"
curl -fsSL "$REPO/meeting-alarm/scripts/setup.sh"          -o "$SKILL_DIR/scripts/setup.sh"
curl -fsSL "$REPO/meeting-alarm/scripts/daemon.sh"         -o "$SKILL_DIR/scripts/daemon.sh"
curl -fsSL "$REPO/meeting-alarm/scripts/overlay_helper.swift" -o "$SKILL_DIR/scripts/overlay_helper.swift"
chmod +x "$SKILL_DIR/scripts/setup.sh" "$SKILL_DIR/scripts/daemon.sh"

echo "✓ Skill installed to ~/.claude/skills/meeting-alarm/"
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  Next steps:                                         ║"
echo "║  1. Restart Claude Code                              ║"
echo "║  2. Run: /meeting-alarm setup                        ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
