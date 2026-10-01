#!/bin/bash
# ./script/helmverse/setup_direnv.sh

# With strict mode for safer scripting
set -euo pipefail
IFS=$'\n\t'

# Detect project root directory using Git
ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)"

# Exit if not inside a Git repository (enforces script to be project-bound)
if [ -z "$ROOT_DIR" ]; then
  echo "[ERROR] Failed to detect project root. Make sure you're running inside a git repository." >&2
  exit 1
fi

# Detect current shell (bash or zsh)
SHELL_NAME=$(basename "$SHELL")
if [ "$SHELL_NAME" = "zsh" ]; then
  RC_FILE=~/.zshrc
  HOOK='eval "$(direnv hook zsh)"'
else
  RC_FILE=~/.bashrc
  HOOK='eval "$(direnv hook bash)"'
fi

# Ensure direnv hook is present
if ! grep -Fxq "$HOOK" "$RC_FILE"; then
  echo "🔧 Adding direnv hook to $RC_FILE..."
  echo "$HOOK" >> "$RC_FILE"
else
  echo "✅ direnv hook already present in $RC_FILE"
fi

# Approve .envrc for current project
echo "Allowing .envrc for $(pwd)..."
direnv allow

echo "🎉 Environment setup completed!"
echo "👉 Please restart your shell or run: exec \"\$SHELL\""
