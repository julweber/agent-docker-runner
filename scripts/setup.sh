#!/bin/bash

# Spec Framework v2 Setup Script
# Usage: ./scripts/setup.sh [--update] <project-name> <project-location>

set -e

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

UPDATE_MODE=false

if [ "$1" = "--update" ]; then
  UPDATE_MODE=true
  shift
fi

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 [--update] <project-name> <project-location>" >&2
  exit 1
fi

PROJECT_NAME="$1"
PROJECT_LOCATION="$2"

# ---------------------------------------------------------------------------
# Shared setup
# ---------------------------------------------------------------------------

# Resolve paths
FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$UPDATE_MODE" = true ]; then
  MODE_LABEL="update"
else
  MODE_LABEL="init"
fi

echo "###### CONFIGURATION ######"
echo ""
echo "Mode:            $MODE_LABEL"
echo "Project name:    $PROJECT_NAME"
echo "Framework dir:   $FRAMEWORK_DIR"
echo "###########################"
echo ""

# ---------------------------------------------------------------------------
# UPDATE MODE
# ---------------------------------------------------------------------------

if [ "$UPDATE_MODE" = true ]; then

  # Pre-flight: project directory must already exist
  if [ ! -d "$PROJECT_LOCATION" ]; then
    echo "Error: Project directory '$PROJECT_LOCATION' does not exist." >&2
    echo "       Run without --update to initialize a new project." >&2
    exit 1
  fi

  PROJECT_DIR="$(cd "$PROJECT_LOCATION" && pwd)"

  echo "Project dir:     $PROJECT_DIR"
  echo ""

  # Pre-flight: must be an initialized git repo
  if [ ! -d "$PROJECT_DIR/.git" ]; then
    echo "Error: No git repository found at '$PROJECT_DIR'." >&2
    echo "       This does not look like an initialized spec-framework project." >&2
    exit 1
  fi

  # Ensure scripts/ralph/ dir exists (it should, but be safe)
  mkdir -p "$PROJECT_DIR/scripts/ralph"

  echo "Copying ralph loop files..."
  cp "$FRAMEWORK_DIR/scripts/ralph/ralph.sh" "$PROJECT_DIR/scripts/ralph/ralph.sh"
  cp "$FRAMEWORK_DIR/scripts/ralph/prompt.md" "$PROJECT_DIR/scripts/ralph/prompt.md"
  chmod +x "$PROJECT_DIR/scripts/ralph/ralph.sh"

  echo "Copying scripts..."
  cp $FRAMEWORK_DIR/scripts/*.sh "$PROJECT_DIR/scripts/"
  chmod +x $PROJECT_DIR/scripts/*.sh

  echo "Refreshing skills directory..."
  rm -rf "$PROJECT_DIR/skills"
  cp -r "$FRAMEWORK_DIR/skills/." "$PROJECT_DIR/skills/"

  echo "Recreating agent skill symlinks..."
  "$FRAMEWORK_DIR/scripts/link-skills.sh" "$PROJECT_DIR"

  echo ""
  echo "Committing updated framework files..."
  git -C "$PROJECT_DIR" add scripts/ skills/
  git -C "$PROJECT_DIR" diff --cached --quiet \
    && echo "Nothing to commit — framework files already up to date." \
    || git -C "$PROJECT_DIR" commit -m "chore: update spec framework scripts and skills"

  echo ""
  echo "=========================================="
  echo "Update complete for project: $PROJECT_NAME"
  echo "Project directory: $PROJECT_DIR"
  echo "=========================================="
  echo ""
  echo "Framework files updated:"
  echo "  - scripts/"
  echo "  - scripts/ralph/"
  echo "  - skills/"
  echo "  - Agent symlinks (.pi, .claude, .opencode)"
  echo ""

  exit 0
fi

# ---------------------------------------------------------------------------
# INIT MODE (existing behaviour, unchanged)
# ---------------------------------------------------------------------------

# Create project location if it does not exist
if [ ! -d "$PROJECT_LOCATION" ]; then
  mkdir -p "$PROJECT_LOCATION"
  echo "Created project directory: $PROJECT_LOCATION"
fi

PROJECT_DIR="$(cd "$PROJECT_LOCATION" && pwd)"

echo "Project dir:     $PROJECT_DIR"
echo ""

# Safety check: abort if any specification/project/*.md files already exist with non-placeholder content
EXISTING_FILES=()
SPEC_PROJECT_DIR="$PROJECT_DIR/specification/project"
for fname in description.md concepts.md architecture.md conventions.md test-strategy.md; do
  fpath="$SPEC_PROJECT_DIR/$fname"
  if [ -f "$fpath" ]; then
    # Check if file contains non-placeholder content (more than just the comment line and headers)
    content=$(grep -v '^<!--' "$fpath" | grep -v '^#' | grep -v '^$' || true)
    if [ -n "$content" ]; then
      EXISTING_FILES+=("$fpath")
    fi
  fi
done

if [ "${#EXISTING_FILES[@]}" -gt 0 ]; then
  echo "Error: The following spec files already contain content. Aborting to prevent data loss:" >&2
  for f in "${EXISTING_FILES[@]}"; do
    echo "  - $f" >&2
  done
  echo "" >&2
  echo "Remove or back up these files before running setup." >&2
  exit 1
fi

echo "Creating directory structure..."

# Create all required directories
mkdir -p "$PROJECT_DIR/specification/project"
mkdir -p "$PROJECT_DIR/specification/features"
mkdir -p "$PROJECT_DIR/tasks"
mkdir -p "$PROJECT_DIR/scripts/ralph"
mkdir -p "$PROJECT_DIR/skills"

echo "Writing specification/project placeholder files..."

write_placeholder() {
  local file="$1"
  local title="$2"
  local sections="$3"
  cat > "$file" <<EOF
# $title

<!-- Fill in using /spec-project-brainstorm -->

$sections
EOF
}

write_placeholder "$PROJECT_DIR/specification/project/description.md" "Project Description" \
"## What It Does

## Problem It Solves

## Primary Users

## Core Capabilities

## Out of Scope"

write_placeholder "$PROJECT_DIR/specification/project/concepts.md" "Domain Concepts" \
"## Key Entities

## Terminology

## Relationships"

write_placeholder "$PROJECT_DIR/specification/project/architecture.md" "Architecture" \
"## Tech Stack

## System Structure

## Components

## External Integrations

## Deployment"

write_placeholder "$PROJECT_DIR/specification/project/conventions.md" "Conventions" \
"## Code Style

## Naming Conventions

## Architectural Patterns

## Libraries and Utilities

## Anti-Patterns"

write_placeholder "$PROJECT_DIR/specification/project/test-strategy.md" "Test Strategy" \
"## Test Types

## What Gets Tested

## Coverage Expectations

## Frameworks and Tools

## Quality Check Definition"

echo "Copying ralph loop files..."

cp "$FRAMEWORK_DIR/scripts/ralph/ralph.sh" "$PROJECT_DIR/scripts/ralph/ralph.sh"
cp "$FRAMEWORK_DIR/scripts/ralph/prompt.md" "$PROJECT_DIR/scripts/ralph/prompt.md"
chmod +x "$PROJECT_DIR/scripts/ralph/ralph.sh"

echo "Copying scripts..."
cp $FRAMEWORK_DIR/scripts/*.sh "$PROJECT_DIR/scripts/"
chmod +x $PROJECT_DIR/scripts/*.sh

echo "Copying skills directory..."

cp -r "$FRAMEWORK_DIR/skills/." "$PROJECT_DIR/skills/"

echo "Creating agent skill symlinks..."
"$FRAMEWORK_DIR/scripts/link-skills.sh" "$PROJECT_DIR"

echo "Initializing git repository (if needed)..."

if [ ! -d "$PROJECT_DIR/.git" ]; then
  git -C "$PROJECT_DIR" init
  echo "Git repository initialized."
else
  echo "Git repository already exists — skipping init."
fi

# Copy .gitignore template if it doesn't exist in project
if [ ! -f "$PROJECT_DIR/.gitignore" ]; then
  cp "$FRAMEWORK_DIR/templates/.gitignore.template" "$PROJECT_DIR/.gitignore"
  echo "Copied .gitignore template."
else
  echo ".gitignore already exists — skipping copy."
fi

# add all files and make an initial commit

echo ""
echo "adding initial commit ..."
pushd "$PROJECT_DIR"
  git add .
  git commit -m "initial commit - spec framework setup completed"
popd

echo ""
echo "=========================================="
echo "Setup complete for project: $PROJECT_NAME"
echo "Project directory: $PROJECT_DIR"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Open an agent session in $PROJECT_DIR"
echo "  2. Run /spec-project-brainstorm to define your project spec"
echo "  3. Run /spec-feature-brainstorm <feature-name> to define a feature"
echo "  4. Run /spec-review <feature-name> to review and finalize the spec"
echo "  5. Run /spec-to-tasks <feature-name> to generate the task list"
echo "  6. git commit the specification and tasks.yaml created"
echo "  7. Run ./scripts/implement-feature.sh <feature-name> to start implementation"
echo ""
