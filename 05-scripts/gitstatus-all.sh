#!/bin/bash
# =========================================================
# === Git Status Dashboard for ~/dev-journey
# =========================================================
# Scans all git repositories under ~/dev-journey and shows:
#  • Current branch name
#  • Uncommitted changes
#  • Unpushed commits
#  • Clean status indicator
# =========================================================
# Author: Aryan
# =========================================================

BASE_DIR=~/dev-journey

# --- Colors ---
RESET="\e[0m"
BOLD="\e[1m"
CYAN="\e[36m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
WHITE="\e[97m"

echo -e "${WHITE}${BOLD}🔍 Checking Git repos inside:${RESET} $BASE_DIR"
echo -e "${WHITE}--------------------------------------------------${RESET}"

# --- Find all Git repositories ---
find "$BASE_DIR" -type d -name ".git" 2>/dev/null | while read gitdir; do
    repo=$(dirname "$gitdir")
    cd "$repo" || continue

    # Get branch name
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

    # Get uncommitted changes
    changes=$(git status --porcelain 2>/dev/null)

    # Check unpushed commits
    git fetch -q 2>/dev/null
    ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
    behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo 0)

    echo -e "${BOLD}${CYAN}📁 Repository:${RESET} $repo"
    echo -e "   ${BOLD}Branch:${RESET} ${YELLOW}${branch}${RESET}"

    if [[ -n "$changes" ]]; then
        echo -e "   ${RED}⚠️  Uncommitted changes:${RESET}"
        git status -s
    else
        echo -e "   ${GREEN}✅ Clean working directory${RESET}"
    fi

    if [[ "$ahead" -gt 0 ]]; then
        echo -e "   ${YELLOW}⬆️  $ahead commit(s) ahead of remote${RESET}"
    fi

    if [[ "$behind" -gt 0 ]]; then
        echo -e "   ${RED}⬇️  $behind commit(s) behind remote${RESET}"
    fi

    echo ""
done

echo -e "${WHITE}--------------------------------------------------${RESET}"
echo -e "${BOLD}✨ Done scanning all repositories.${RESET}"

