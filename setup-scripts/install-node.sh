#!/bin/bash

###############################################################################
# Node.js Major-Aware Installer / Upgrader
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
export DEBIAN_FRONTEND=noninteractive

if [[ "$EUID" -eq 0 ]]; then
  SUDO_CMD=""
elif ! command -v sudo &>/dev/null; then
  log_err "This script requires sudo, but it's not installed."
  exit 1
fi

if command -v apt &>/dev/null; then
  PACKMAN="apt"
  DEPS=("curl" "jq" "ca-certificates" "gnupg")
elif command -v dnf &>/dev/null; then
  PACKMAN="dnf"
  DEPS=("curl" "jq" "gnupg2")
elif command -v yum &>/dev/null; then
  PACKMAN="yum"
  DEPS=("curl" "jq" "gnupg2")
else
  log_err "Unsupported package manager. Only apt, dnf, and yum are supported."
  exit 1
fi

log "Detected OS: $ID ($PACKMAN)"

echo "=============================================="
echo "Node.js Major Version Checker"
echo "=============================================="

###############################################################################
# Dependency Check
###############################################################################

MISSING_DEPS=()

for cmd in "${DEPS[@]}"; do
  case "$cmd" in
    ca-certificates)
      dpkg -s ca-certificates &>/dev/null 2>&1 || MISSING_DEPS+=("$cmd")
      ;;
    gnupg|gnupg2)
      command -v gpg &>/dev/null || MISSING_DEPS+=("$cmd")
      ;;
    *)
      command -v "$cmd" &>/dev/null || MISSING_DEPS+=("$cmd")
      ;;
  esac
done

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
  log "Installing missing dependencies: ${MISSING_DEPS[*]}..."
  case "$PACKMAN" in
    apt)
      $SUDO_CMD apt update -qq
      $SUDO_CMD apt install -y "${MISSING_DEPS[@]}"
      ;;
    *)
      $SUDO_CMD "$PACKMAN" install -y "${MISSING_DEPS[@]}"
      ;;
  esac
fi

###############################################################################
# Version Detection
###############################################################################

CURRENT_VERSION="0"
if command -v node &>/dev/null; then
  CURRENT_VERSION=$(node -v 2>/dev/null | sed 's/v//g' | cut -d. -f1)
fi

log "Fetching latest Node.js LTS version..."
LATEST_MAJOR=""

JSON_DATA=$(curl -sS --fail --connect-timeout 10 "https://nodejs.org/dist/index.json" 2>/dev/null)

if [[ -n "$JSON_DATA" ]]; then
  LATEST_MAJOR=$(echo "$JSON_DATA" | jq -r '[.[] | select(.lts != false)][0].version' | sed 's/v//g' | cut -d. -f1)
else
  log_err "Failed to fetch version index from nodejs.org"
  exit 1
fi

if [[ -z "$LATEST_MAJOR" ]]; then
  log_err "Failed to parse latest LTS version."
  exit 1
fi

log "Current major: $CURRENT_VERSION"
log "Latest LTS major: $LATEST_MAJOR"
echo

###############################################################################
# Version Comparison
###############################################################################

if [[ "$CURRENT_VERSION" == "$LATEST_MAJOR" ]]; then
  echo "Already on the latest LTS branch (${CURRENT_VERSION}.x)"
  exit 0
fi

###############################################################################
# Confirmation
###############################################################################

AUTO_YES="${AUTO_YES:-false}"

if [[ "$AUTO_YES" != "true" ]]; then
  read -p "Proceed with major upgrade to Node ${LATEST_MAJOR}.x? (y/n): " -n 1 -r
  echo
  [[ ! "$REPLY" =~ ^[Yy]$ ]] && log_err "Cancelled." && exit 0
fi

###############################################################################
# Repository Configuration
###############################################################################

echo "Configuring Node.js ${LATEST_MAJOR}.x repository..."

case "$ID_LIKE $ID" in
  *debian* | *ubuntu*)
    KEYRING_PATH="/usr/share/keyrings/nodesource.gpg"
    $SUDO_CMD rm -f "$KEYRING_PATH"

    log "Downloading GPG key..."
    if ! curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
      $SUDO_CMD gpg --dearmor -o "$KEYRING_PATH"; then
        log_err "Failed to download or import GPG key."
        exit 1
    fi

    REPO_FILE="/etc/apt/sources.list.d/nodesource.list"
    echo "deb [signed-by=$KEYRING_PATH] https://deb.nodesource.com/node_${LATEST_MAJOR}.x nodistro main" | \
      $SUDO_CMD tee "$REPO_FILE" >/dev/null

    log "Running apt update..."
    if ! $SUDO_CMD apt update -qq; then
        log_err "apt update failed."
        exit 1
    fi
    ;;

  *rhel* | *fedora* | *centos* | *rocky* | *almalinux*)
    REPO_FILE="/etc/yum.repos.d/nodesource.repo"

    $SUDO_CMD tee "$REPO_FILE" >/dev/null <<EOF
[nodesource-node-${LATEST_MAJOR}]
name=Node.js Packages for Linux
baseurl=https://rpm.nodesource.com/pub_${LATEST_MAJOR}.x/el/\$releasever/\$basearch
enabled=1
gpgcheck=1
gpgkey=https://rpm.nodesource.com/gpgkey/nodesource.gpg.key
EOF

    log "Updating package metadata..."
    $SUDO_CMD "$PACKMAN" makecache -q
    ;;

  *)
    log_err "This OS ($ID) is not supported."
    exit 1
    ;;
esac

###############################################################################
# Installation
###############################################################################

echo "Installing Node.js ${LATEST_MAJOR}.x..."
if ! $SUDO_CMD "$PACKMAN" install -y nodejs; then
    log_err "Installation failed."
    exit 1
fi

###############################################################################
# Verification
###############################################################################

NEW_VERSION=$(node -v | tr -d 'v')

echo
echo "=============================================="
echo "Node.js successfully upgraded to v${NEW_VERSION}"
echo "=============================================="

if command -v npm &>/dev/null; then
  log "npm version: $(npm -v)"
fi

log "Location: $(command -v node)"
echo "=============================================="
