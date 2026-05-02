#!/bin/bash

###############################################################################
# Redis Major-Aware Installer / Upgrader
###############################################################################

set -euo pipefail

log() { echo "🔹 $1"; }
log_err() { echo "❌ $1" >&2; }

###############################################################################
# OS & Package Manager Detection
###############################################################################

if [[ ! -f /etc/os-release ]]; then
  log_err "Cannot find /etc/os-release. This script is unsupported."
  exit 1
fi

. /etc/os-release

PACKMAN=""
SUDO_CMD="sudo"
SERVICE_NAME="redis-server"
export DEBIAN_FRONTEND=noninteractive

if [[ "$EUID" -eq 0 ]]; then
  SUDO_CMD=""
elif ! command -v sudo &>/dev/null; then
  log_err "This script requires sudo, but it's not installed."
  exit 1
fi

if command -v apt &>/dev/null; then
  PACKMAN="apt"
  DEPS=("curl" "gpg" "lsb-release" "ca-certificates")
elif command -v dnf &>/dev/null; then
  PACKMAN="dnf"
  SERVICE_NAME="redis"
  DEPS=("curl" "gnupg2")
elif command -v yum &>/dev/null; then
  PACKMAN="yum"
  SERVICE_NAME="redis"
  DEPS=("curl" "gnupg2")
else
  log_err "Unsupported package manager. Only apt, dnf, and yum are supported."
  exit 1
fi

log "Detected OS: $ID ($PACKMAN)"

echo "=============================================="
echo "Redis Version Checker"
echo "=============================================="

###############################################################################
# Dependency Check
###############################################################################

MISSING_DEPS=()

for cmd in "${DEPS[@]}"; do
  case "$cmd" in
    ca-certificates) dpkg -s ca-certificates &>/dev/null 2>&1 || MISSING_DEPS+=("$cmd") ;;
    lsb-release) command -v lsb_release &>/dev/null || MISSING_DEPS+=("$cmd") ;;
    gnupg|gnupg2) command -v gpg &>/dev/null || MISSING_DEPS+=("$cmd") ;;
    *) command -v "$cmd" &>/dev/null || MISSING_DEPS+=("$cmd") ;;
  esac
done

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
  log "Installing missing dependencies: ${MISSING_DEPS[*]}..."
  case "$PACKMAN" in
    apt) $SUDO_CMD apt update -qq && $SUDO_CMD apt install -y "${MISSING_DEPS[@]}" ;;
    *)   $SUDO_CMD "$PACKMAN" install -y "${MISSING_DEPS[@]}" ;;
  esac
fi

###############################################################################
# Repository Configuration
###############################################################################

log "Configuring packages.redis.io repository..."

case "$PACKMAN" in
  apt)
    $SUDO_CMD rm -f /etc/apt/sources.list.d/redis*.list
    $SUDO_CMD rm -f /usr/share/keyrings/redis-archive-keyring.gpg

    if ! curl -fsSL https://packages.redis.io/gpg | \
      $SUDO_CMD gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg; then
      log_err "Failed to import GPG key."
      exit 1
    fi

    $SUDO_CMD chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg

    REPO_FILE="/etc/apt/sources.list.d/redis.list"
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] \
https://packages.redis.io/deb $(lsb_release -cs) main" | \
      $SUDO_CMD tee "$REPO_FILE" >/dev/null

    if ! $SUDO_CMD apt update -qq; then
      log_err "apt update failed."
      exit 1
    fi
    ;;

  dnf|yum)
    $SUDO_CMD rm -f /etc/yum.repos.d/redis*.repo

    REPO_FILE="/etc/yum.repos.d/redis.repo"
    REPO_VER="${VERSION_ID%.*}"
    [[ -z "$REPO_VER" ]] && REPO_VER="$VERSION_ID"

    $SUDO_CMD tee "$REPO_FILE" >/dev/null <<EOF
[redis]
name=Redis
baseurl=https://packages.redis.io/rpm/rhel/${REPO_VER}/\$basearch
enabled=1
gpgcheck=1
gpgkey=https://packages.redis.io/gpg
EOF

    $SUDO_CMD "$PACKMAN" makecache -q || {
      log_err "Failed to fetch repo metadata."
      exit 1
    }
    ;;
esac

###############################################################################
# Version Detection (Repository Source of Truth)
###############################################################################

CURRENT_MAJOR="0"
if command -v redis-server &>/dev/null; then
  CURRENT_MAJOR=$(redis-server --version 2>/dev/null | \
    sed -n 's/.*v=\([0-9]\+\)\..*/\1/p')
fi

CANDIDATE_VERSION=""

case "$PACKMAN" in
  apt)
    CANDIDATE_VERSION=$(apt-cache policy redis-server | \
      grep 'Candidate:' | awk '{print $2}')
    CANDIDATE_VERSION=${CANDIDATE_VERSION#*:}
    ;;
  dnf|yum)
    if command -v repoquery &>/dev/null; then
      CANDIDATE_VERSION=$(repoquery --quiet \
        --queryformat='%{version}' redis 2>/dev/null | head -n1)
    else
      CANDIDATE_VERSION=$($SUDO_CMD "$PACKMAN" info redis 2>/dev/null | \
        grep -Ei '^Version' | awk '{print $3}' | head -n1)
    fi
    ;;
esac

if [[ -z "$CANDIDATE_VERSION" ]]; then
  log_err "Could not determine available Redis version from repository."
  exit 1
fi

CANDIDATE_MAJOR=$(echo "$CANDIDATE_VERSION" | cut -d. -f1)

log "Installed major: ${CURRENT_MAJOR:-0}"
log "Available major (Repo): $CANDIDATE_MAJOR"
echo

###############################################################################
# Version Comparison
###############################################################################

if [[ "$CURRENT_MAJOR" == "$CANDIDATE_MAJOR" ]]; then
  echo "Already on the latest supported major branch (${CURRENT_MAJOR}.x)"
  exit 0
fi

if [[ "$CURRENT_MAJOR" -gt "$CANDIDATE_MAJOR" ]]; then
  log_err "Installed version is newer than repo version."
  exit 0
fi

###############################################################################
# Confirmation
###############################################################################

AUTO_YES="${AUTO_YES:-false}"

if [[ "$AUTO_YES" != "true" ]]; then
  read -p "Proceed with major upgrade to Redis ${CANDIDATE_MAJOR}.x? (y/n): " -n 1 -r
  echo
  [[ ! "$REPLY" =~ ^[Yy]$ ]] && log_err "Cancelled." && exit 0
fi

###############################################################################
# Installation
###############################################################################

echo "Installing Redis ${CANDIDATE_MAJOR}.x ($CANDIDATE_VERSION)..."

if ! $SUDO_CMD "$PACKMAN" install -y redis; then
  log_err "Installation failed."
  exit 1
fi

###############################################################################
# Service Management
###############################################################################

log "Starting/enabling $SERVICE_NAME service..."
$SUDO_CMD systemctl daemon-reload
$SUDO_CMD systemctl enable "$SERVICE_NAME"
$SUDO_CMD systemctl restart "$SERVICE_NAME"

###############################################################################
# Verification
###############################################################################

NEW_VERSION=$(redis-server --version | \
  sed -n 's/.*v=\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')

echo
echo "=============================================="
echo "Redis successfully upgraded to v${NEW_VERSION}"
echo "=============================================="

if systemctl is-active --quiet "$SERVICE_NAME"; then
  log "Service Status: Active"
else
  log_err "Service Status: Inactive"
fi

log "Location: $(command -v redis-server)"
echo "=============================================="
