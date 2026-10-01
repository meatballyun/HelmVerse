#!/usr/bin/env bash

_hv_completions() {
  local current previous commands
  current="${COMP_WORDS[COMP_CWORD]}"
  previous="${COMP_WORDS[COMP_CWORD-1]}"
  commands="init doctor project cluster deploy sops status logs shell k9s rollback undeploy cert config completion version help"

  case "$previous" in
    hv)
      COMPREPLY=( $(compgen -W "$commands" -- "$current") )
      ;;
    project)
      COMPREPLY=( $(compgen -W "list show create validate" -- "$current") )
      ;;
    cluster)
      COMPREPLY=( $(compgen -W "up status down addon" -- "$current") )
      ;;
    cert)
      COMPREPLY=( $(compgen -W "install setup create-issuer status logs" -- "$current") )
      ;;
    sops)
      COMPREPLY=( $(compgen -W "init -p --project --env --help" -- "$current") )
      ;;
    -p|--project)
      COMPREPLY=( $(compgen -W "$(hv project list 2>/dev/null)" -- "$current") )
      ;;
    k9s)
      COMPREPLY=( $(compgen -W "--namespace --all --readonly --write --help" -- "$current") )
      ;;
    config)
      COMPREPLY=( $(compgen -W "show get set" -- "$current") )
      ;;
    *)
      if [[ "$current" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help --env --dry-run --timeout --values --secrets-file --yes" -- "$current") )
      else
        COMPREPLY=()
      fi
      ;;
  esac
}

complete -F _hv_completions hv
