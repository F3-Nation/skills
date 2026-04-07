#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_COMMANDS_DIR="$HOME/.claude/commands"
CODEX_HOME_SET=false
if [[ -n "${CODEX_HOME:-}" ]]; then
  CODEX_HOME_SET=true
fi
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CODEX_SKILLS_DIR="$CODEX_HOME/skills"

SKILLS=(
  "decide-for-me"
  "f3:auto"
  "f3:claude-md"
  "f3:code-review"
  "f3:demo"
  "f3:figma"
  "f3:ingest-pdf"
  "f3:markdown"
  "f3:next"
  "f3:patch"
  "f3:push"
  "f3:python-refactor"
  "f3:qa"
  "f3:rebase"
  "f3:resolve-threads"
  "f3:react-refactor"
  "f3:sweep"
  "f3:slop"
  "spec-gen"
  "validate-quality-gates"
)

# Old names that may exist as orphaned symlinks
OLD_SKILLS=(
  "f3-code-review"
  "f3-qa"
)

# ── Uninstall ────────────────────────────────────────────────────────
if [[ "${1:-}" == "--uninstall" ]]; then
  for skill in "${SKILLS[@]}" "${OLD_SKILLS[@]}"; do
    claude_dst="$CLAUDE_COMMANDS_DIR/$skill.md"
    if [[ -L "$claude_dst" ]]; then
      rm "$claude_dst"
      echo "Uninstalled /$skill from Claude Code (removed $claude_dst)"
    fi

    codex_dst="$CODEX_SKILLS_DIR/$skill"
    if [[ -L "$codex_dst" ]]; then
      rm "$codex_dst"
      echo "Uninstalled /$skill from Codex (removed $codex_dst)"
    fi
  done
  exit 0
fi

# ── Detect available CLIs ────────────────────────────────────────────
mkdir -p "$CLAUDE_COMMANDS_DIR"

CODEX_AVAILABLE=false
if [[ "$CODEX_HOME_SET" == true || -d "$CODEX_HOME" || -x "$(command -v codex 2>/dev/null)" ]]; then
  mkdir -p "$CODEX_HOME"
  mkdir -p "$CODEX_SKILLS_DIR"
  CODEX_AVAILABLE=true
fi

# ── Clean up orphaned symlinks ───────────────────────────────────────
for old in "${OLD_SKILLS[@]}"; do
  claude_dst="$CLAUDE_COMMANDS_DIR/$old.md"
  if [[ -L "$claude_dst" ]]; then
    rm "$claude_dst"
    echo "Removed orphaned /$old -> $claude_dst"
  fi

  if [[ "$CODEX_AVAILABLE" == true ]]; then
    codex_dst="$CODEX_SKILLS_DIR/$old"
    if [[ -L "$codex_dst" ]]; then
      rm "$codex_dst"
      echo "Removed orphaned /$old -> $codex_dst (Codex)"
    fi
  fi
done

# ── Install skills ───────────────────────────────────────────────────
for skill in "${SKILLS[@]}"; do
  # Claude Code: file symlink to SKILL.md
  claude_src="$REPO_DIR/skills/$skill/SKILL.md"
  claude_dst="$CLAUDE_COMMANDS_DIR/$skill.md"
  ln -sfn "$claude_src" "$claude_dst"
  echo "Installed /$skill -> $claude_src"

  # Codex: directory symlink to skill folder (includes scripts/ etc.)
  if [[ "$CODEX_AVAILABLE" == true ]]; then
    codex_src="$REPO_DIR/skills/$skill"
    codex_dst="$CODEX_SKILLS_DIR/$skill"
    ln -sfn "$codex_src" "$codex_dst"
    echo "Installed /$skill -> $codex_src (Codex)"
  fi
done

# ── External skill dependencies ──────────────────────────────────────
# f3:react-refactor layers on Vercel's react-best-practices.
# f3:figma layers on Figma's implement-design.
# Install globally so every project gets the latest industry rules.
# NOTE: These are Claude Code-specific via `npx skills add -g`.

EXTERNAL_SKILLS=(
  "vercel-labs/agent-skills"
  "https://github.com/figma/mcp-server-guide"
)

if command -v npx &>/dev/null; then
  for ext in "${EXTERNAL_SKILLS[@]}"; do
    echo ""
    echo "Installing external dependency: $ext"
    # shellcheck disable=SC2086
    npx -y skills@latest add $ext -g -y 2>&1 | sed 's/^/  /' || echo "  WARNING: Failed to install $ext (non-fatal)"
  done
else
  echo ""
  echo "WARNING: npx not found - skipping external skill dependencies."
  echo "         Install Node.js and run ./install.sh again to get external skills."
fi

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo "Skills installed for Claude Code (${#SKILLS[@]} skills -> ~/.claude/commands/)"
if [[ "$CODEX_AVAILABLE" == true ]]; then
  echo "Skills installed for OpenAI Codex  (${#SKILLS[@]} skills -> $CODEX_SKILLS_DIR/)"
  echo "Restart Codex to pick up new skills."
else
  echo "Codex CLI not detected and CODEX_HOME not set -- skipping Codex install."
  echo "Re-run ./install.sh after installing Codex or set CODEX_HOME to enable."
fi
echo ""
echo "Claude commands: /decide-for-me, /f3:auto, /f3:claude-md, /f3:code-review, /f3:demo, /f3:figma, /f3:ingest-pdf, /f3:markdown, /f3:next, /f3:patch, /f3:push, /f3:python-refactor, /f3:qa, /f3:rebase, /f3:react-refactor, /f3:resolve-threads, /f3:slop, /f3:sweep, /spec-gen, /validate-quality-gates"
if [[ "$CODEX_AVAILABLE" == true ]]; then
  echo "Codex skills: mention the skill name in your prompt, for example: 'Use f3:push to push this branch and validate the PR.'"
fi
