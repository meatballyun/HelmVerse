#!/bin/bash
# zsh_emulate_fix.sh
#
# This script ensures that "emulate -L zsh" is present at the beginning of
# the .zshrc file to properly enable full zsh mode. This fixes issues with
# zsh plugins that use zsh-specific syntax like ${+VAR_NAME}.
#
# The script will:
# 1. Check if "emulate -L zsh" already exists in .zshrc
# 2. If not, add it to the beginning of the file
# 3. Create a backup of the original .zshrc file before making changes
# 4. Apply the changes to the current terminal session
#
# This is a reusable script that can be run any time zsh configuration issues occur.


# Safer scripting mode
set -euo pipefail
IFS=$'\n\t'

# Source logging functions for output messages (info, error, success)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logger.sh"

fix_zsh_permanent(){
  # Check if we're running in a zsh shell
  if [ -z "$ZSH_VERSION" ]; then
    warn "This script is being run outside of zsh. Changes will still be made to .zshrc, but cannot be applied to the current session."
    CAN_UPDATE_CURRENT_SESSION=false
  else
    CAN_UPDATE_CURRENT_SESSION=true
  fi

  # Check if .zshrc file exists
  if [ ! -f ~/.zshrc ]; then
    error "The ~/.zshrc file does not exist. Creating a new one."
    touch ~/.zshrc
  fi

  # Check if "emulate -L zsh" is already in .zshrc
  if grep -q "emulate -L zsh" ~/.zshrc; then
    info "The 'emulate -L zsh' command is already in your .zshrc file."
    info "No changes needed to the file."
    CHANGES_MADE=false
  else
    info "Adding 'emulate -L zsh' to the beginning of your .zshrc file..."

    # Create a backup of the original .zshrc file
    backup_file=~/.zshrc.backup.$(date +%Y%m%d%H%M%S)
    cp ~/.zshrc "$backup_file"
    info "Created backup of your original .zshrc file at: $backup_file"

    # Add the emulate command to the beginning of .zshrc
    echo -e "# Ensure zsh runs in full feature mode\nemulate -L zsh\n\n$(cat ~/.zshrc)" > ~/.zshrc

    info "Successfully added 'emulate -L zsh' to your .zshrc file."
    CHANGES_MADE=true
  fi

  # Check for duplicate PATH entries as a courtesy
  if grep -c 'export PATH=' ~/.zshrc | grep -q -v '^0$\|^1$'; then
    warn "Multiple PATH export statements detected in your .zshrc file."
    warn "Consider consolidating them for better maintainability."
  fi

  # Update current session if running in zsh
  if [ "$CAN_UPDATE_CURRENT_SESSION" = true ]; then
    info "Applying changes to the current terminal session..."

    # First, enable full zsh mode for current session
    emulate -L zsh 2>/dev/null

    # Then source the updated .zshrc file
    if [ "$CHANGES_MADE" = true ]; then
      source ~/.zshrc 2>/dev/null
      if [ $? -eq 0 ]; then
        info "Successfully applied changes to the current terminal session."
      else
        warn "Failed to source ~/.zshrc. You may still see some errors in the current session."
        warn "A new terminal session will work correctly."
      fi
    else
      info "Configuration is already correct. No need to reload."
    fi
  else
    warn "To apply changes to your current session, restart your terminal or run: source ~/.zshrc"
  fi

  success "Script completed successfully."
}
