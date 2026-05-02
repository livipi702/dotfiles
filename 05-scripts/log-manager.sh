#!/usr/bin/env bash
# =========================================================
# === Dev Journey Log Manager (Sort-Safe v1.2.1)
# === Features: JIT Logic, Safe Sorting, Dynamic Headers
# =========================================================

set -euo pipefail

# --- Configuration ---
VERSION="1.2.1"
BASE="${HOME}/dev-journey/00-logs"
mkdir -p "${BASE}"/{daily,weekly,monthly}

# Safe Argument Handling
TYPE=${1:-}
TOPIC=${2:-}
EDITOR=${EDITOR:-nano}

# --- Visuals ---
if [[ -t 1 ]]; then
  RESET="\e[0m"
  BOLD="\e[1m"
  CYAN="\e[36m"
  GREEN="\e[32m"
  RED="\e[31m"
  YELLOW="\e[33m"
  MAGENTA="\e[35m"
  WHITE="\e[97m"
  GRAY="\e[90m"
  BRIGHT_GREEN="\e[92m"
else
  RESET=""
  BOLD=""
  CYAN=""
  GREEN=""
  RED=""
  YELLOW=""
  MAGENTA=""
  WHITE=""
  GRAY=""
  BRIGHT_GREEN=""
fi

# ---------------------------------------------------------
# Help & Version
# ---------------------------------------------------------
if [[ "${TYPE}" == "--help" || "${TYPE}" == "-h" ]]; then
  echo -e "${BOLD}📔 Dev Journey Manager${RESET}"
  echo -e "Usage:"
  echo -e "  ${CYAN}log daily${RESET}          Open today's log"
  echo -e "  ${CYAN}log daily \"Topic\"${RESET}   Open log + append topic header"
  echo -e "  ${CYAN}log weekly${RESET}          Open current weekly review"
  echo -e "  ${CYAN}log monthly${RESET}         Open current monthly retro"
  echo -e "  ${CYAN}log --clean${RESET}         Delete empty (0-byte) logs"
  echo -e "  ${CYAN}log --version${RESET}       Show version info"
  exit 0
elif [[ "${TYPE}" == "--version" || "${TYPE}" == "-v" ]]; then
  echo -e "${BOLD}Dev Journey Log Manager${RESET} v${VERSION}"
  echo -e "WSL Native • Sort-Safe • Dynamic Headers"
  exit 0
fi

# ---------------------------------------------------------
# Editor Launcher
# ---------------------------------------------------------
open_log() {
  local file="$1"

  if [ -n "$EDITOR" ] && command -v "$EDITOR" >/dev/null 2>&1; then
    "$EDITOR" "$file"
  elif command -v code >/dev/null 2>&1; then
    code "$file"
  elif command -v nano >/dev/null 2>&1; then
    nano "$file"
  else
    vi "$file"
  fi
}

# ---------------------------------------------------------
# Helper: Ensure Monthly File Exists
# ---------------------------------------------------------
ensure_monthly_exists() {
  local MONTH_NAME="$1"
  local MONTH_FILE="${BASE}/monthly/${MONTH_NAME}.md"

  if [[ ! -f $MONTH_FILE ]]; then
    if ! {
      echo "# Monthly Retro (${MONTH_NAME})"
      echo "## 📈 High Level Progress"
      echo "- "
      echo
      echo "## 🌱 Weekly Logs"
    } >"${MONTH_FILE}"; then
      echo -e "${RED}❌ Error: Failed to create monthly log. Check permissions.${RESET}" >&2
      exit 1
    fi
    echo -e "${BRIGHT_GREEN}🆕 Created Monthly Log:${RESET} ${MONTH_FILE}" >&2
  fi
}

# ---------------------------------------------------------
# Helper: Ensure Weekly File Exists (Sort-Safe Naming)
# ---------------------------------------------------------
ensure_weekly_exists() {
  local ISO_YEAR WEEK
  ISO_YEAR=$(date +%G)
  WEEK=$(date +%V)

  local mon_date sun_date
  mon_date=$(date -d "$(date +%Y-%m-%d) -$(($(date +%u) - 1)) days" +%Y-%m-%d)
  sun_date=$(date -d "$mon_date + 6 days" +%Y-%m-%d)

  # Check for Year Transition
  local y1 y2 file_prefix
  y1=$(date -d "$mon_date" +%Y)
  y2=$(date -d "$sun_date" +%Y)

  # LOGIC: Only use dual-naming if it's the start of the year (Week 01)
  # This ensures 2026-2025 sorts BEFORE 2026-week-02.
  if [[ "$y1" != "$y2" && "$WEEK" == "01" ]]; then
    file_prefix="${ISO_YEAR}-${y1}" # Result: 2026-2025
  else
    file_prefix="$ISO_YEAR" # Result: 2026 (or 2025 for Week 53)
  fi

  local WEEK_FILE="${BASE}/weekly/${file_prefix}-week-${WEEK}.md"

  # 1. Identify Unique Months
  declare -A unique_months
  local month_links=""
  local last_added_month=""
  local i m

  for i in {0..6}; do
    m=$(date -d "${mon_date} +${i} days" +%B-%Y)
    unique_months["$m"]=1
    if [[ "$m" != "$last_added_month" ]]; then
      ensure_monthly_exists "$m"
      month_links="${month_links}, [${m}](../monthly/${m}.md)"
      last_added_month="$m"
    fi
  done
  month_links="${month_links:2}"

  # 2. Create File if Missing
  if [[ ! -f $WEEK_FILE ]]; then
    if ! {
      echo "# Weekly Review (Week ${WEEK}, ${file_prefix})"
      echo "- **Part of:** ${month_links}"
      echo
      echo "## 🗓️ Daily Logs"
    } >"${WEEK_FILE}"; then
      echo -e "${RED}❌ Error: Failed to create weekly log. Check disk space.${RESET}" >&2
      exit 1
    fi
  fi

  # 3. Link Week -> Month
  local rel_path="../weekly/$(basename "$WEEK_FILE")"

  for m in "${!unique_months[@]}"; do
    local mf="${BASE}/monthly/${m}.md"
    if [[ -f "$mf" ]] && ! grep -Fq "Week ${WEEK}" "$mf"; then
      [[ -s $mf && -n $(tail -c 1 "$mf") ]] && echo >>"$mf"
      echo "- [Week ${WEEK}](${rel_path})" >>"$mf"
      echo -e "${GREEN}🔗 Linked Week ${WEEK} to Month: ${m}${RESET}" >&2
    fi
  done

  echo "$WEEK_FILE"
}

# =========================================================
# 🔵 DAILY LOG
# =========================================================
if [[ $TYPE == "daily" ]]; then
  DATE=$(date +%Y-%m-%d)
  TIME=$(date "+%I:%M %p")
  WEEK=$(date +%V)
  YEAR=$(date +%G)

  FILE="${BASE}/daily/${DATE}.md"

  # Generate correct sort-safe filename
  WEEK_FILE=$(ensure_weekly_exists)
  WEEK_BASENAME=$(basename "$WEEK_FILE")

  if [[ ! -f $FILE ]]; then
    # --- DYNAMIC HEADER LOGIC START ---
    HOUR=$(date +%H)
    if ((HOUR < 12)); then
      GOAL_TITLE="🌞 Morning Goals"
    elif ((HOUR < 18)); then
      GOAL_TITLE="🌤️ Afternoon Goals"
    else
      GOAL_TITLE="🌙 Night Goals"
    fi
    # --- DYNAMIC HEADER LOGIC END ---

    # 1. Create Daily File
    if ! {
      echo "# Daily Log (${DATE})"
      echo "- **Part of:** [Week ${WEEK}](../weekly/${WEEK_BASENAME})"
      echo "- **Start Time:** ${TIME}"
      echo
      echo "## ${GOAL_TITLE}"
      echo "- "
      echo
    } >"${FILE}"; then
      echo -e "${RED}❌ Error: Failed to create daily log.${RESET}" >&2
      exit 1
    fi

    # 2. JIT Banner Logic (Updated: Uses %-d to prevent octal error on days 08/09)
    if [[ $(date -d "$DATE" +%-d) -le 7 ]]; then
      # Calculate Monday of this week to see if we crossed a month boundary
      MON_DATE=$(date -d "$DATE - $(($(date +%u) - 1)) days" +%Y-%m-%d)
      MON_MONTH=$(date -d "$MON_DATE" +%m)
      CURR_MONTH=$(date -d "$DATE" +%m)

      if [[ "$MON_MONTH" != "$CURR_MONTH" ]]; then
        CURR_MONTH_NAME=$(date -d "$DATE" +%B)
        CURR_YEAR_NUM=$(date -d "$DATE" +%Y)
        BANNER_TEXT="Crossed into ${CURR_MONTH_NAME}"
        NEW_YEAR_TEXT="HAPPY NEW YEAR"

        # Only append if banner is NOT already in the file
        if ! grep -Fq "${BANNER_TEXT}" "${WEEK_FILE}" && ! grep -Fq "${NEW_YEAR_TEXT}" "${WEEK_FILE}"; then
          # Correctly calculate the transition dates (End of Prev Month -> 1st of Curr Month)
          TRANSITION_1ST=$(date -d "${YEAR}-${CURR_MONTH}-01" +%Y-%m-%d)
          PREV_DATE_STR=$(date -d "$TRANSITION_1ST - 1 day" "+%d %b %Y")
          CURR_DATE_STR=$(date -d "$TRANSITION_1ST" "+%d %b %Y")

          [[ -s $WEEK_FILE && -n $(tail -c 1 "$WEEK_FILE") ]] && echo >>"${WEEK_FILE}"

          if [[ "$CURR_MONTH" == "01" ]]; then
            echo "- # 🎆 ${NEW_YEAR_TEXT} ${CURR_YEAR_NUM}! (${PREV_DATE_STR} → ${CURR_DATE_STR})" >>"${WEEK_FILE}"
          else
            echo "- # 🏁 ${BANNER_TEXT} (${PREV_DATE_STR} → ${CURR_DATE_STR})" >>"${WEEK_FILE}"
          fi
        fi
      fi
    fi

    # 3. Append Link
    if ! grep -Fq "(${DATE}.md)" "${WEEK_FILE}"; then
      [[ -s $WEEK_FILE && -n $(tail -c 1 "$WEEK_FILE") ]] && echo >>"${WEEK_FILE}"
      echo "- [${DATE}](../daily/${DATE}.md)" >>"${WEEK_FILE}"
    fi
    echo -e "${BRIGHT_GREEN}🆕 Created New Log:${RESET} ${FILE}" >&2
  fi

  # Topic Sanitization (Updated: Allows C++, C#, .js)
  if [[ -n ${TOPIC// /} ]]; then
    SAFE_TOPIC=$(echo "$TOPIC" | sed 's/[^a-zA-Z0-9 _\-\.\+\#]//g')
    if [[ -n "$SAFE_TOPIC" ]] && ! grep -q "^## 🔵 ${SAFE_TOPIC}$" "${FILE}"; then
      echo >>"${FILE}"
      echo "## 🔵 ${SAFE_TOPIC}" >>"${FILE}"
      echo "- " >>"${FILE}"
      echo -e "${GREEN}➕ Appended Header '${SAFE_TOPIC}'${RESET}" >&2
    fi
  fi

  open_log "${FILE}"

# =========================================================
# 🔵 WEEKLY / MONTHLY
# =========================================================
elif [[ $TYPE == "weekly" ]]; then
  FILE=$(ensure_weekly_exists)
  echo -e "${BRIGHT_GREEN}📂 Weekly Log:${RESET} ${FILE}" >&2
  open_log "${FILE}"

elif [[ $TYPE == "monthly" ]]; then
  MONTH=$(date +%B-%Y)
  FILE="${BASE}/monthly/${MONTH}.md"
  ensure_monthly_exists "$MONTH"
  echo -e "${BRIGHT_GREEN}📂 Monthly Log:${RESET} ${FILE}" >&2
  open_log "${FILE}"

# =========================================================
# 🧹 CLEANUP
# =========================================================
elif [[ $TYPE == "--clean" ]]; then
  echo -e "${WHITE}${BOLD}🧹 Log Cleanup (0-byte files)${RESET}"
  mapfile -d '' EMPTY < <(find "${BASE}" -type f -empty -name "*.md" -print0)

  if ((${#EMPTY[@]} == 0)); then
    echo -e "${GREEN}✅ No empty log files found.${RESET}"
    exit 0
  fi

  printf "${YELLOW}Found empty files:${RESET}\n"
  printf '  • %s\n' "${EMPTY[@]}"
  read -rp "$(echo -e ${MAGENTA}"❓ Delete? (y/n): "${RESET})" confirm
  if [[ $confirm =~ ^[Yy]$ ]]; then
    printf '%s\0' "${EMPTY[@]}" | xargs -0 rm -v
    echo -e "${BRIGHT_GREEN}✅ Empty logs deleted.${RESET}"
  else
    echo -e "${YELLOW}⚠️  Cleanup aborted.${RESET}"
  fi

# =========================================================
# 📊 DASHBOARD
# =========================================================
fi
if [[ -z "${TYPE}" || "${TYPE}" == "--clean" ]]; then
  echo -e "${WHITE}${BOLD}=============================================${RESET}"
  echo -e "${BOLD}📔  Dev Journey Dashboard${RESET}"
  echo -e "${WHITE}${BOLD}=============================================${RESET}"

  DAILY_COUNT=$(find "${BASE}/daily" -name '*.md' -type f | wc -l)

  echo -e "${CYAN}📅 Today:${RESET}  $(date '+%A, %d %B %Y')"
  echo -e "${CYAN}📁 Root:${RESET}   ${BASE}"
  echo -e "   Logs: ${GREEN}${DAILY_COUNT}${RESET}"
  echo

  echo -e "${BOLD}🕓 Recent Logs:${RESET}"
  if ((DAILY_COUNT == 0)); then
    echo -e "  ${GRAY}(No logs yet)${RESET}"
  else
    # UPDATED: Sorts by FILENAME (Date) instead of modification time
    find "${BASE}/daily" -name '*.md' -type f |
      sort -r | head -3 |
      while read -r path; do
        filename=$(basename "$path")
        echo -e "  • ${filename%.*}"
      done
  fi
  echo

  echo -e "${MAGENTA}💡 Tip:${RESET} Use ${BOLD}log --help${RESET} to see commands."
  echo -e "${WHITE}${BOLD}=============================================${RESET}"
fi
