#!/bin/bash

###############################################################################
# MongoDB Major Version Checker
###############################################################################

set -euo pipefail

log() { echo "🔹 $1"; }
log_err() { echo "❌ $1" >&2; }

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
CUSTOM_MAP_FILE="$SCRIPT_DIR/mongo.custom.map"

declare -A MONGO_MAP
MONGO_MAP[ubuntu-noble]="8.0"
MONGO_MAP[ubuntu-jammy]="7.0"
MONGO_MAP[ubuntu-focal]="6.0"
MONGO_MAP[ubuntu-bionic]="5.0"

MONGO_MAP[debian-bookworm]="7.0"
MONGO_MAP[debian-bullseye]="6.0"

MONGO_MAP[rhel-9]="8.0"
MONGO_MAP[rhel-8]="7.0"
MONGO_MAP[rhel-7]="6.0"
MONGO_MAP[rocky-9]="8.0"
MONGO_MAP[rocky-8]="7.0"
MONGO_MAP[rocky-7]="6.0"
MONGO_MAP[almalinux-9]="8.0"
MONGO_MAP[almalinux-8]="7.0"
MONGO_MAP[almalinux-7]="6.0"
MONGO_MAP[centos-9]="8.0"
MONGO_MAP[centos-8]="7.0"
MONGO_MAP[centos-7]="6.0"

###############################################################################
# Load Custom Map
###############################################################################

if [[ -f "$CUSTOM_MAP_FILE" ]]; then
  log "Loading custom versions from $CUSTOM_MAP_FILE"
  . "$CUSTOM_MAP_FILE"
fi

###############################################################################
# OS & Package Manager Detection
###############################################################################

[[ -f /etc/os-release ]] || { log_err "Cannot find /etc/os-release"; exit 1; }
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
  DEPS=(curl gpg lsb-release)
elif command -v dnf &>/dev/null; then
  PACKMAN="dnf"
  DEPS=(curl gpg)
elif command -v yum &>/dev/null; then
  PACKMAN="yum"
  DEPS=(curl gpg)
else
  log_err "Unsupported package manager (apt/dnf/yum only)"
  exit 1
fi

log "Detected OS: $ID $VERSION_ID ($PACKMAN)"

echo "=============================================="
echo "🍃 MongoDB Major Version Checker"
echo "=============================================="

###############################################################################
# Dependency Check
###############################################################################

MISSING_DEPS=()

for cmd in "${DEPS[@]}"; do
  if ! command -v "$cmd" &>/dev/null; then
    MISSING_DEPS+=("$cmd")
  fi
done

if [[ $PACKMAN == "apt" ]] && ! dpkg -s apt-transport-https &>/dev/null; then
  MISSING_DEPS+=(apt-transport-https)
fi

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
# Current Version Detection
###############################################################################

CURRENT_VERSION="Not installed"
CURRENT_MAJOR="0"

if command -v mongod &>/dev/null; then
  CURRENT_FULL=$(mongod --version 2>/dev/null | awk '/db version/ {print $3}' | tr -d 'v')
  if [[ -n $CURRENT_FULL ]]; then
    CURRENT_VERSION=$CURRENT_FULL
    CURRENT_MAJOR=${CURRENT_FULL%%.*}
  fi
fi

###############################################################################
# Repository Resolution
###############################################################################

REPO_URL_BASE=""
OS_LOOKUP_KEY=""
REPO_OS_VERSION_YUM=""

case "$ID" in
  ubuntu)
    REPO_URL_BASE="https://repo.mongodb.org/apt/ubuntu"
    OS_LOOKUP_KEY="ubuntu-$VERSION_CODENAME"
    ;;
  debian)
    REPO_URL_BASE="https://repo.mongodb.org/apt/debian"
    OS_LOOKUP_KEY="debian-$VERSION_CODENAME"
    ;;
  rhel|rocky|almalinux|centos)
    REPO_URL_BASE="https://repo.mongodb.org/yum/redhat"
    REPO_OS_VERSION_YUM=${VERSION_ID%.*}
    [[ -z "$REPO_OS_VERSION_YUM" ]] && REPO_OS_VERSION_YUM="$VERSION_ID"
    OS_LOOKUP_KEY="$ID-$REPO_OS_VERSION_YUM"
    ;;
  fedora)
    log_err "MongoDB does not officially support Fedora"
    exit 1
    ;;
  *)
    log_err "Unsupported OS: $ID"
    exit 1
    ;;
esac

MAJOR_VERSION="${MONGO_MAP[$OS_LOOKUP_KEY]:-}"

###############################################################################
# Interactive Fallback
###############################################################################

if [[ -z "$MAJOR_VERSION" ]]; then
  log_err "No supported MongoDB version for $ID (Lookup Key: $OS_LOOKUP_KEY)"
  read -p "Do you know the new major version? (e.g., 8.0) or (q) to quit: " NEW_VER

  if [[ "$NEW_VER" == "q" || -z "$NEW_VER" ]]; then
    log_err "Cancelled."
    exit 1
  fi

  if [[ ! "$NEW_VER" =~ ^[0-9]+\.[0-9]+$ ]]; then
    log_err "Invalid version format."
    exit 1
  fi

  echo "MONGO_MAP[$OS_LOOKUP_KEY]=\"$NEW_VER\"" >> "$CUSTOM_MAP_FILE"
  MAJOR_VERSION="$NEW_VER"
fi

LATEST_MAJOR=${MAJOR_VERSION%%.*}

log "Current MongoDB version: $CURRENT_VERSION"
log "Target major version for $ID: $MAJOR_VERSION"
echo

###############################################################################
# Version Comparison
###############################################################################

if [[ $CURRENT_MAJOR == "$LATEST_MAJOR" ]]; then
  echo "Already on latest supported major ($CURRENT_MAJOR.x)"
  exit 0
fi

if [[ $CURRENT_MAJOR -gt $LATEST_MAJOR ]]; then
  log_err "Newer version detected. Downgrade not attempted."
  exit 0
fi

###############################################################################
# Confirmation
###############################################################################

AUTO_YES="${AUTO_YES:-false}"

if [[ $AUTO_YES != "true" ]]; then
  read -p "Proceed with install/upgrade to MongoDB $MAJOR_VERSION? (y/n): " -n 1 -r
  echo
  [[ $REPLY =~ ^[Yy]$ ]] || exit 0
fi

###############################################################################
# Repository Configuration
###############################################################################

GPG_KEY_URL="https://pgp.mongodb.com/server-${LATEST_MAJOR}.asc"

case "$PACKMAN" in
  apt)
    $SUDO_CMD rm -f /etc/apt/sources.list.d/mongodb-*.list

    ARCH=$(dpkg --print-architecture)
    REPO_COMPONENT=$([[ "$ID" == "ubuntu" ]] && echo "multiverse" || echo "main")

    GPG_KEY_FILE="/usr/share/keyrings/mongodb-server-${LATEST_MAJOR}.gpg"

    log "Downloading GPG key..."
    if ! curl -fsSL --tlsv1.2 --proto '=https' "$GPG_KEY_URL" | \
         $SUDO_CMD gpg --dearmor -o "$GPG_KEY_FILE"; then
      log_err "Failed to download or import GPG key."
      exit 1
    fi

    REPO_FILE="/etc/apt/sources.list.d/mongodb-org-${LATEST_MAJOR}.list"
    echo "deb [arch=$ARCH signed-by=$GPG_KEY_FILE] \
${REPO_URL_BASE}/$(lsb_release -cs)/mongodb-org/${MAJOR_VERSION} $REPO_COMPONENT" | \
      $SUDO_CMD tee "$REPO_FILE" >/dev/null

    if ! $SUDO_CMD apt update -qq; then
      log_err "apt update failed after adding MongoDB repo."
      exit 1
    fi
    ;;
  dnf|yum)
    $SUDO_CMD rm -f /etc/yum.repos.d/mongodb-*.repo
    REPO_FILE="/etc/yum.repos.d/mongodb-org-${LATEST_MAJOR}.repo"

    $SUDO_CMD tee "$REPO_FILE" >/dev/null <<EOF
[mongodb-org-${LATEST_MAJOR}]
name=MongoDB Repository
baseurl=${REPO_URL_BASE}/${REPO_OS_VERSION_YUM}/mongodb-org/${MAJOR_VERSION}/\$basearch/
gpgcheck=1
enabled=1
gpgkey=${GPG_KEY_URL}
EOF

    $SUDO_CMD "$PACKMAN" makecache -q
    ;;
esac

###############################################################################
# Installation
###############################################################################

echo "Installing MongoDB ${MAJOR_VERSION}..."
if ! $SUDO_CMD "$PACKMAN" install -y mongodb-org; then
  log_err "Installation failed."
  exit 1
fi

###############################################################################
# Start & Enable
###############################################################################

$SUDO_CMD systemctl daemon-reload
$SUDO_CMD systemctl enable mongod
$SUDO_CMD systemctl restart mongod

###############################################################################
# Verification
###############################################################################

NEW_VERSION=$(mongod --version 2>/dev/null | awk '/db version/ {print $3}' | tr -d 'v')

echo
echo "=============================================="
echo "MongoDB upgraded to v${NEW_VERSION}"
echo "=============================================="

if systemctl is-active --quiet mongod; then
  log "Service Status: Active (Running)"
else
  log_err "Service Status: Inactive (Check 'journalctl -u mongod')"
fi

if systemctl is-enabled --quiet mongod; then
  log "Boot Status: Enabled"
else
  log_err "Boot Status: Disabled"
fi

echo "=============================================="
