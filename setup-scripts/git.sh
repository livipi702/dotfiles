#!/usr/bin/env bash

# =============================================================================
# gitid — Git Identity Switcher
#
# Usage:
#   gitid <command>
#
# Commands:
#   livipi   Switch to livipi702 identity
#   aryan    Switch to Aryan Shinde identity
#   show     Print the current repo's git identity
#   list     List all available identities
#   help     Show this help message
# =============================================================================

# ── ANSI colors (disabled automatically when not a terminal) ────────────────
if [[ -t 1 ]]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[1;33m'
  CYAN=$'\033[0;36m'
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RESET=$'\033[0m'
else
  RED='' GREEN='' YELLOW='' CYAN='' BOLD='' DIM='' RESET=''
fi

# ── Helpers ──────────────────────────────────────────────────────────────────
die() {
  printf "${RED}✗ %s${RESET}\n" "$*" >&2
  return 1
}

ok() {
  printf "${GREEN}✔ %s${RESET}\n" "$*"
}

info() {
  printf "${CYAN}%s${RESET}\n" "$*"
}

hr() {
  printf "${DIM}%s${RESET}\n" "────────────────────────────────"
}

# ── Require a git repo ───────────────────────────────────────────────────────
require_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    die "Not inside a Git repository."
}

# ── Display current identity ─────────────────────────────────────────────────
show_identity() {
  local name email

  name="$(git config user.name 2>/dev/null || echo '(not set)')"
  email="$(git config user.email 2>/dev/null || echo '(not set)')"

  hr
  printf "  ${BOLD}%-8s${RESET} %s\n" "Name" "${YELLOW}${name}${RESET}"
  printf "  ${BOLD}%-8s${RESET} %s\n" "Email" "${YELLOW}${email}${RESET}"
  hr
}

# ── Apply an identity ────────────────────────────────────────────────────────
set_identity() {
  local name="$1"
  local email="$2"
  local label="$3"

  git config user.name "$name"
  git config user.email "$email"

  ok "Switched to ${BOLD}${label}${RESET}"
  show_identity
}

# ── List all registered identities ──────────────────────────────────────────
list_identities() {
  hr
  printf "  ${CYAN}%-10s${RESET}  %s\n" \
    "livipi" "livipi702 <livipi7028@videobix.com>"
  printf "  ${CYAN}%-10s${RESET}  %s\n" \
    "aryan" "Aryan Shinde <aryanpshinde2006@gmail.com>"
  hr
}

# ── Usage / help ─────────────────────────────────────────────────────────────
usage() {
  printf "\n${BOLD}Usage:${RESET}  gitid <command>\n\n"

  printf "${BOLD}Commands:${RESET}\n"
  printf "  ${CYAN}%-8s${RESET}  %s\n" \
    "livipi" "Switch to livipi702 identity"
  printf "  ${CYAN}%-8s${RESET}  %s\n" \
    "aryan" "Switch to Aryan Shinde identity"
  printf "  ${CYAN}%-8s${RESET}  %s\n" \
    "show" "Print current repo identity"
  printf "  ${CYAN}%-8s${RESET}  %s\n" \
    "list" "List all available identities"
  printf "  ${CYAN}%-8s${RESET}  %s\n" \
    "help" "Show this help message"

  printf "\n"
}

# ── Public command ──────────────────────────────────────────────────────────
gitid() {
  case "${1:-}" in
  livipi)
    require_git_repo || return
    set_identity \
      "livipi702" \
      "livipi7028@videobix.com" \
      "livipi702"
    ;;
  aryan)
    require_git_repo || return
    set_identity \
      "Aryan Shinde" \
      "aryanpshinde2006@gmail.com" \
      "Aryan Shinde"
    ;;
  show)
    require_git_repo || return
    show_identity
    ;;
  list)
    list_identities
    ;;
  help | --help | -h)
    usage
    ;;
  "")
    usage
    ;;
  *)
    die "Unknown command: '$1'"
    printf "\n"
    usage
    ;;
  esac
}
