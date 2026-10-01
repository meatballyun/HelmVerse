#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=logger.sh
source "$SCRIPT_DIR/logger.sh"

# clone_project <project_dir> <repo_url> <branch> [repo_name] [force_clone]
#
# Existing Git checkouts are updated with a fast-forward-only pull. A non-Git
# directory is never removed unless force_clone=true is explicitly supplied.
# Credentials are delegated to SSH or Git's credential helper and are never
# embedded into a command or URL by this function.
clone_project() {
  local project_dir="${1:-}"
  local git_repo_url="${2:-}"
  local git_repo_branch="${3:-}"
  local git_repo_name="${4:-}"
  local force_clone="${5:-false}"
  local target_dir

  [[ -n "$project_dir" && -n "$git_repo_url" && -n "$git_repo_branch" ]] || \
    die "project_dir, git_repo_url, and git_repo_branch are required."

  if [[ -z "$git_repo_name" ]]; then
    git_repo_name="$(basename "$git_repo_url")"
    git_repo_name="${git_repo_name%.git}"
  fi
  [[ "$git_repo_name" =~ ^[A-Za-z0-9._-]+$ ]] || die "Invalid repository name: $git_repo_name"
  command -v git >/dev/null 2>&1 || die "Git is not installed."

  target_dir="$project_dir/$git_repo_name"
  mkdir -p "$project_dir"

  if [[ -d "$target_dir/.git" && "$force_clone" != true ]]; then
    info "Updating existing checkout: $target_dir"
    git -C "$target_dir" fetch origin "$git_repo_branch"
    git -C "$target_dir" checkout "$git_repo_branch"
    git -C "$target_dir" pull --ff-only origin "$git_repo_branch"
    success "Repository updated."
    return 0
  fi

  if [[ -e "$target_dir" ]]; then
    if [[ "$force_clone" != true ]]; then
      die "Target exists and is not an updatable Git checkout: $target_dir"
    fi
    warn "Force-clone requested; removing only the validated target: $target_dir"
    rm -rf -- "$target_dir"
  fi

  info "Cloning $git_repo_url ($git_repo_branch) into $target_dir"
  if ! git clone --branch "$git_repo_branch" -- "$git_repo_url" "$target_dir"; then
    error "Clone failed. Configure an SSH key or Git credential helper and retry."
    return 1
  fi

  success "Repository cloned successfully."
}
