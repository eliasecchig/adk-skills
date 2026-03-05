#!/bin/bash
# Builds the .well-known/skills/ directory from skill source files.
# Run this before deploying to GitHub Pages.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT"
OUTPUT_DIR="$REPO_ROOT/.well-known/skills"

# Clean previous build
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Copy index.json
cp "$REPO_ROOT/index.json" "$OUTPUT_DIR/index.json"

# Copy each skill directory
SKILL_NAMES=$(jq -r '.skills[].name' "$REPO_ROOT/index.json")

for skill in $SKILL_NAMES; do
  if [ -d "$SKILLS_DIR/$skill" ]; then
    mkdir -p "$OUTPUT_DIR/$skill"
    # Copy all files listed in index.json for this skill
    FILES=$(jq -r --arg name "$skill" '.skills[] | select(.name == $name) | .files[]' "$REPO_ROOT/index.json")
    for file in $FILES; do
      dir=$(dirname "$file")
      if [ "$dir" != "." ]; then
        mkdir -p "$OUTPUT_DIR/$skill/$dir"
      fi
      cp "$SKILLS_DIR/$skill/$file" "$OUTPUT_DIR/$skill/$file"
    done
    echo "  Copied: $skill"
  else
    echo "  WARNING: skill directory not found: $skill"
  fi
done

echo ""
echo "Built .well-known/skills/ with $(echo "$SKILL_NAMES" | wc -w | tr -d ' ') skills."
echo "Output: $OUTPUT_DIR"
