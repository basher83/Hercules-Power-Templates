#!/bin/bash
#
# Enhanced Cloud Image Update Script for Proxmox VE
# Downloads the latest CentOS, Debian, Fedora or Ubuntu cloud images
# Designed for unattended execution via systemd timers
#
# Original source: https://github.com/trfore/proxmox-template-scripts
# Enhanced with production-ready features following CODING_STANDARDS.md
#
# Copyright 2022 Taylor Fore
# Enhanced 2025 - Production improvements
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ====================================================================
# ENHANCEMENT 1: Proper error handling per CODING_STANDARDS.md
# - Added set -euo pipefail for strict error handling
# - Added error trap to capture line numbers on failure
# ====================================================================
set -euo pipefail
trap 'echo "Error occurred at line $LINENO. Exit code: $?" >&2' ERR

# ====================================================================
# ENHANCEMENT 2: Logging Standards (CODING_STANDARDS.md Section 3)
# - Comprehensive logging to /var/log/ with timestamps
# - Dual console/file output for systemd journal + persistent logs
# - Fallback to /tmp if /var/log not writable
# ====================================================================

# Set up logging based on distribution info (will be set later)
setup_logging() {
  local dist="${1:-unknown}"
  local rel="${2:-unknown}"

  # Try /var/log first, fallback to /tmp
  LOG_FILE="/var/log/image-update-${dist}-${rel}-$(date +%Y%m%d_%H%M%S).log"
  if ! touch "$LOG_FILE" 2>/dev/null; then
    LOG_FILE="/tmp/image-update-${dist}-${rel}-$(date +%Y%m%d_%H%M%S).log"
  fi

  # Initialize log
  {
    echo "Image update started at $(date)"
    echo "Distribution: $dist, Release: $rel"
    echo "Script version: 1.1.0-enhanced"
    echo "Running as user: $(whoami)"
    echo "System: $(uname -a)"
  } > "$LOG_FILE"
}

# Logging functions per standards
log_info() {
  echo "[INFO] $*"
  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*" >> "$LOG_FILE"
}

log_warn() {
  echo "[WARN] $*" >&2
  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $*" >> "$LOG_FILE"
}

log_error() {
  echo "[ERROR] $*" >&2
  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >> "$LOG_FILE"
}

log_debug() {
  # Only to file, not console
  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $*" >> "$LOG_FILE"
}

# ====================================================================
# ENHANCEMENT 3: Process Management (CODING_STANDARDS.md Section 8)
# - Lock file to prevent concurrent execution
# - Important for systemd timer + manual runs
# ====================================================================
acquire_lock() {
  local dist="$1"
  local rel="$2"
  LOCKFILE="/var/lock/image-update-${dist}-${rel}.lock"

  exec 200>"$LOCKFILE"
  if ! flock -n 200; then
    log_error "Another instance is already running for ${dist}-${rel}"
    exit 1
  fi
  log_debug "Acquired lock: $LOCKFILE"
}

# ====================================================================
# ENHANCEMENT 4: Cleanup Pattern (CODING_STANDARDS.md Section 5)
# - Comprehensive cleanup trap for all temporary resources
# - Status reporting on exit
# ====================================================================
cleanup() {
  local exit_code=$?

  # Remove temp files
  [[ -n "${tmpfile:-}" ]] && [[ -f "$tmpfile" ]] && rm -f "$tmpfile"

  # Write status file
  if [[ -n "${DISTRO_NAME:-}" ]] && [[ -n "${RELEASE_NAME:-}" ]]; then
    local status_file="${STORAGE_PATH}/.image-update-status-${DISTRO_NAME}-${RELEASE_NAME}"
    if [[ $exit_code -eq 0 ]]; then
      cat > "$status_file" <<-EOF
				status=success
				timestamp=$(date -Iseconds)
				image=${file_basename:-unknown}.img
				log_file=${LOG_FILE:-unknown}
			EOF
      log_info "Status file written: $status_file"
    else
      cat > "$status_file" <<-EOF
				status=failed
				timestamp=$(date -Iseconds)
				exit_code=$exit_code
				log_file=${LOG_FILE:-unknown}
			EOF
      log_error "Script failed with exit code: $exit_code"
    fi
  fi

  # Report log location on failure
  if [[ $exit_code -ne 0 ]] && [[ -n "${LOG_FILE:-}" ]]; then
    echo "[ERROR] Script failed! Check the log for details: $LOG_FILE" >&2
  fi

  # Release lock
  [[ -n "${LOCKFILE:-}" ]] && rm -f "$LOCKFILE"
}
trap cleanup EXIT

# ====================================================================
# ENHANCEMENT 5: Network Resilience for Unattended Execution
# - Retry logic for downloads with exponential backoff
# - Timeout settings for hung transfers
# ====================================================================
download_with_retry() {
  local url="$1"
  local output="$2"
  local description="${3:-file}"
  local max_retries=3
  local retry=0
  local wait_time=30

  log_info "Downloading $description from: $url"

  while [[ $retry -lt $max_retries ]]; do
    if curl -fL \
            --connect-timeout 30 \
            --max-time 1800 \
            --retry 3 \
            --retry-delay 5 \
            "$url" \
            -o "$output" 2>&1 | tee -a "$LOG_FILE"; then
      log_info "Successfully downloaded $description"
      return 0
    fi

    retry=$((retry + 1))
    if [[ $retry -lt $max_retries ]]; then
      log_warn "Download attempt $retry/$max_retries failed, retrying in ${wait_time}s..."
      sleep $wait_time
      wait_time=$((wait_time * 2))  # Exponential backoff
    fi
  done

  log_error "Failed to download $description after $max_retries attempts"
  return 1
}

# ====================================================================
# ENHANCEMENT 6: Dry-Run Mode (for testing timer configurations)
# - Shows what would be done without making changes
# - Useful for testing systemd timer setups
# ====================================================================
DRY_RUN=false

# Original variables
APPEND_DATE=false
BACKUP_IMAGES=false
REMOVE_OLD_IMAGE=false
STORAGE_PATH='/var/lib/vz/template/iso'

function err() {
  log_error "$*"
  exit 2
}

function help() {
  echo "
  Enhanced Cloud Image Update Script

  Usage: ${0##*/} -d <DISTRO_NAME> -r <RELEASE_NAME> [ARGS]
  Examples:
    ${0##*/} -d ubuntu -r 20
    ${0##*/} -d ubuntu -r 20 --remove
    ${0##*/} -d ubuntu -r 20 --storage /tmp
    ${0##*/} -d debian -r 11 --remove
    ${0##*/} -d ubuntu -r 22 --dry-run

  Arguments:
    --help,    -h  Display this help message and exit
    --backup,  -b  Backup the existing image before creating a new one (default: false)
                    This flag is not compatiable with --remove flag.
    --date         Append the date to the image name, e.g. 'ubuntu*-\$DATE.img' (default: false)
    --distro,  -d  Specify the distribution name, e.g. 'ubuntu'.
    --dry-run      Test mode - show what would be done without downloading
    --remove       Remove old images before updating (default: false)
                    This flag is not compatiable with --backup flag.
    --release, -r  Specify the release version, e.g. 'focal' or '20'
    --storage, -s  Specify a storage path for the image (default: '/var/lib/vz/template/iso')


  Alternative Usage: ${0##*/} <DISTRO_NAME>-<RELEASE_NAME> [ARGS]
  Examples:
    ${0##*/} ubuntu-20
    ${0##*/} debian-11 --remove
    ${0##*/} ubuntu-22 --dry-run

  Enhanced Features:
    - Comprehensive logging to /var/log/
    - Retry logic for network failures
    - Lock file to prevent concurrent runs
    - Status file creation for monitoring
    - Dry-run mode for testing
  "
  exit 1
}

function usage() {
  printf "Usage: %s -d <DISTRO_NAME> -r <RELEASE_NAME> [ARGS] \n" "${0##*/}" >&2
  exit 1
}

#######################################
# Backup image files.
# Arguments:
#   $1 - file, string.
# Outputs:
#   Writes files to the current directory.
#######################################
function backup_images() {
  shopt -s extglob

  # avoid overwriting existing backups
  files="${1%.*}!(*.backup.*)"
  for file in $files; do
    log_info "Backing up ${file}"
    cp -nv "$file" "${file%.*}.backup.${file##*.}" 2>&1 | tee -a "$LOG_FILE"
  done

  shopt -u extglob
}

#######################################
# Compare the SHASUM of a local cloud image to remote image.
# Globals:
#   file_basename
#   file_name
#   remote_shasum_url
#   shasum_algorithm
# Returns:
#   0 if SHASUM matches.
#   1 if SHASUM does not match.
#######################################
function check_shasum() {
  local current_shasum latest_shasum

  # ENHANCEMENT: Ensure temp file cleanup
  tmpfile=$(mktemp /tmp/pve-image-shasum.XXXXXX)

  log_info "Checking SHA${shasum_algorithm} for ${file_name}"

  # get latest shasums with retry
  if ! download_with_retry "${remote_shasum_url}" "${tmpfile}" "SHA${shasum_algorithm} file"; then
    log_warn "Could not download checksum file, assuming image needs update"
    return 1
  fi

  latest_shasum=$(grep "${file_name}" "${tmpfile}" | grep -oE '[a-z0-9]{64,128}' - || true)

  if [[ -z "$latest_shasum" ]]; then
    log_warn "Could not find checksum for ${file_name} in checksum file"
    return 1
  fi

  # Check if the downloaded file exists with its original extension
  if [[ -f "${download_name}" ]]; then
    current_shasum=$(shasum -a "${shasum_algorithm}" "${download_name}" | awk '{print $1}')
  else
    log_info "Local image does not exist yet"
    return 1
  fi

  log_info "Current SHA${shasum_algorithm}: ${current_shasum}"
  log_info "Latest  SHA${shasum_algorithm}: ${latest_shasum}"

  rm -f "$tmpfile"
  tmpfile=""  # Clear so cleanup doesn't try to remove again

  if [[ $latest_shasum == "${current_shasum}" ]]; then
    log_info "Checksum match, image is up-to-date"
    return 0
  else
    log_info "No checksum match, image is outdated"
    return 1
  fi
}

#######################################
# Get Cloud Image Release Date
# Arguments:
#   $1 - url of the cloud image, string.
#   $2 - file name of the cloud image, string.
# Outputs:
#   file_date, string.
#######################################
function get_image_date() {
  local url file_date

  url=$(dirname "${1}")
  # get dates in YYYY-MM-DD or YYYY-MMM-DD format
  file_date=$(curl -sL "${url}" | grep "${2}" | grep -oiEm 1 '[0-9]{4}-([0-9]{2}-[0-9]{2}|[a-z]{3}-[0-9]{2})' || echo "unknown")

  log_debug "Image date: $file_date"
  echo "${file_date}"
}

#######################################
# Set Cloud Image Values
# Globals:
#   DISTRO_NAME
#   RELEASE_NAME
# Returns:
#   file_name, string.
#   remote_url, string.
#   remote_shasum_url, string.
#   shasum_algorithm, string.
#######################################
function set_image_values() {
  if [[ "${DISTRO_NAME}" == "debian" ]]; then
    case $RELEASE_NAME in
    buster | 10)
      file_name="debian-10-generic-amd64.qcow2"
      remote_url="https://cloud.debian.org/images/cloud/buster/latest/debian-10-generic-amd64.qcow2"
      remote_shasum_url="https://cloud.debian.org/images/cloud/buster/latest/SHA512SUMS"
      shasum_algorithm="512"
      ;;
    bullseye | 11)
      file_name="debian-11-generic-amd64.qcow2"
      remote_url="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"
      remote_shasum_url="https://cloud.debian.org/images/cloud/bullseye/latest/SHA512SUMS"
      shasum_algorithm="512"
      ;;
    bookworm | 12)
      file_name="debian-12-generic-amd64.qcow2"
      remote_url="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
      remote_shasum_url="https://cloud.debian.org/images/cloud/bookworm/latest/SHA512SUMS"
      shasum_algorithm="512"
      ;;
    trixie | 13)
      err "Debian 13 'Trixie' is not available"
      # file_name="debian-13-generic-amd64.qcow2"
      # remote_url= "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
      # remote_shasum_url="https://cloud.debian.org/images/cloud/trixie/latest/SHA512SUMS"
      # shasum_algorithm="512"
      ;;
    *)
      err "Unknown distro, only works for Debian 10-12"
      ;;
    esac
  elif [[ "${DISTRO_NAME}" == "centos" ]]; then
    case $RELEASE_NAME in
    9)
      file_name="CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
      remote_url="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
      remote_shasum_url="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2.SHA256SUM"
      shasum_algorithm="256"
      ;;
    *)
      err "Unknown distro, only works for CentOS Stream 9"
      ;;
    esac
  elif [[ "${DISTRO_NAME}" == "fedora" ]]; then
    case $RELEASE_NAME in
    40)
      file_name="Fedora-Cloud-Base-Generic.x86_64-40-1.14.qcow2"
      remote_url="https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-Generic.x86_64-40-1.14.qcow2"
      remote_shasum_url="https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-40-1.14-x86_64-CHECKSUM"
      shasum_algorithm="256"
      ;;
    41)
      file_name="Fedora-Cloud-Base-Generic-41-1.4.x86_64.qcow2"
      remote_url="https://download.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-41-1.4.x86_64.qcow2"
      remote_shasum_url="https://download.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/x86_64/images/Fedora-Cloud-41-1.4-x86_64-CHECKSUM"
      shasum_algorithm="256"
      ;;
    *)
      err "Unknown distro, only works for Fedora 40+"
      ;;
    esac
  elif [[ "${DISTRO_NAME}" == "ubuntu" ]]; then
    case $RELEASE_NAME in
    focal | 20)
      file_name="ubuntu-20.04-server-cloudimg-amd64.img"
      remote_url="https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img"
      remote_shasum_url="https://cloud-images.ubuntu.com/releases/focal/release/SHA256SUMS"
      shasum_algorithm="256"
      ;;
    jammy | 22)
      file_name="ubuntu-22.04-server-cloudimg-amd64.img"
      remote_url="https://cloud-images.ubuntu.com/releases/jammy/release/ubuntu-22.04-server-cloudimg-amd64.img"
      remote_shasum_url="https://cloud-images.ubuntu.com/releases/jammy/release/SHA256SUMS"
      shasum_algorithm="256"
      ;;
    noble | 24)
      file_name="ubuntu-24.04-server-cloudimg-amd64.img"
      remote_url="https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64.img"
      remote_shasum_url="https://cloud-images.ubuntu.com/releases/noble/release/SHA256SUMS"
      shasum_algorithm="256"
      ;;
    *)
      err "Unknown distro, only works for Ubuntu LTS 20+"
      ;;
    esac
  else
    err "Unsupported distro. Please specify 'centos', 'debian', 'fedora' or 'ubuntu'."
  fi

  readonly file_name remote_url remote_shasum_url shasum_algorithm
  return 0
}

#######################################
# Allow users to pass a single arg for distro and release
# This is a workaround for naming systemd timers
# Arguments:
#   $1 - string, ex: ubuntu-20
# Returns:
#   DISTRO_NAME, string.
#   RELEASE_NAME, string.
#######################################
function split_arg() {
  DISTRO_NAME=${1%-*}
  RELEASE_NAME=${1#*-}
}

function main() {
  if [[ ($? -ne 0) || ($# -eq 0) ]]; then
    usage
  fi

  OPTIONS=hd:r:s:b
  LONGOPTS=help,distro:,release:,storage:,backup,date,remove,dry-run
  NOARG_OPTS=(-h --help -b --backup --date --remove --dry-run)

  TEMP=$(getopt -n "${0##*/}" -o $OPTIONS --long $LONGOPTS -- "${@}") || exit 2
  eval set -- "$TEMP"
  unset TEMP

  while true; do
    [[ ! ${NOARG_OPTS[*]} =~ ${1} ]] && [[ ${2} == -* ]] && {
      err "Missing argument for ${1}"
    }
    case "${1}" in
    -h | --help)
      help
      ;;
    --backup | -b)
      BACKUP_IMAGES=true
      shift
      continue
      ;;
    --date)
      APPEND_DATE=true
      shift
      continue
      ;;
    --distro | -d)
      DISTRO_NAME=${2,,}
      shift 2
      continue
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      continue
      ;;
    --release | -r)
      RELEASE_NAME=${2,,}
      shift 2
      continue
      ;;
    --remove)
      REMOVE_OLD_IMAGE=true
      shift
      continue
      ;;
    --storage | -s)
      STORAGE_PATH=${2}
      shift 2
      continue
      ;;
    --)
      if [ -n "${2}" ]; then
        split_arg "${2,,}"
      fi
      shift
      break
      ;;
    *)
      err "Parsing arguments in main()"
      ;;
    esac
  done

  readonly DISTRO_NAME RELEASE_NAME REMOVE_OLD_IMAGE STORAGE_PATH DRY_RUN

  if [ -z "${DISTRO_NAME}" ] || [ -z "${RELEASE_NAME}" ]; then
    if [ -z "${DISTRO_NAME}" ]; then err "Missing Distribution"; fi
    if [ -z "${RELEASE_NAME}" ]; then err "Missing Release"; fi
    usage
  fi

  # Set up logging now that we have distro info
  setup_logging "$DISTRO_NAME" "$RELEASE_NAME"
  log_info "Starting image update for ${DISTRO_NAME}-${RELEASE_NAME}"

  # Acquire lock to prevent concurrent runs
  acquire_lock "$DISTRO_NAME" "$RELEASE_NAME"

  if [ ! -d "${STORAGE_PATH}" ]; then
    err "Storage path does not exist! Value: ${STORAGE_PATH}"
  fi

  if [ ! -w "${STORAGE_PATH}" ]; then
    err "You do not have write permission to ${STORAGE_PATH}, are you root?"
  fi

  if [ ${REMOVE_OLD_IMAGE} = true ] && [ ${BACKUP_IMAGES} = true ]; then
    err "Cannot remove old images and backup new ones at the same time!"
  fi

  log_info "Distribution:      ${DISTRO_NAME}"
  log_info "Release:           ${RELEASE_NAME}"
  log_info "Storage:           ${STORAGE_PATH}"
  log_info "Remove Old Images: ${REMOVE_OLD_IMAGE}"
  log_info "Dry-Run Mode:      ${DRY_RUN}"

  set_image_values "$@"

  if [ ${APPEND_DATE} = true ]; then
    image_date=$(get_image_date "${remote_url}" "${file_name}")
    file_basename="${file_name%.*}-${image_date}"
  else
    file_basename="${file_name%.*}"
  fi

  readonly file_basename

  # Preserve the original extension for checksum correctness
  download_name="${file_basename}.${file_name##*.}"
  readonly download_name

  # ====================================================================
  # ENHANCEMENT 7: Dry-Run Mode Implementation
  # - Shows what would happen without making changes
  # - Useful for testing timer configurations
  # ====================================================================
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY-RUN] Would check/download image:"
    log_info "[DRY-RUN]   URL: $remote_url"
    log_info "[DRY-RUN]   Destination: ${STORAGE_PATH}/${download_name}"
    log_info "[DRY-RUN]   SHA URL: $remote_shasum_url"

    cd "${STORAGE_PATH}"
    if [[ -e "${download_name}" ]]; then
      log_info "[DRY-RUN] Local image exists: ${download_name}"
      if check_shasum; then
        log_info "[DRY-RUN] Image is up-to-date, no download needed"
      else
        log_info "[DRY-RUN] Image is outdated, would download new version"
        if [[ "$REMOVE_OLD_IMAGE" == "true" ]]; then
          log_info "[DRY-RUN] Would remove old images before downloading"
        fi
      fi
    else
      log_info "[DRY-RUN] Local image does not exist, would download"
    fi

    log_info "[DRY-RUN] Dry-run complete. No changes made."
    log_info "Log saved to: $LOG_FILE"
    exit 0
  fi

  cd "${STORAGE_PATH}"

  if [[ ! -e "${download_name}" ]]; then
    log_info "Image does not exist, downloading..."
    if download_with_retry "${remote_url}" "${download_name}" "cloud image"; then
      log_info "Successfully downloaded new image: ${download_name}"

      # Calculate and log the SHA for verification
      local downloaded_sha
      downloaded_sha=$(shasum -a "${shasum_algorithm}" "${download_name}" | awk '{print $1}')
      log_info "Downloaded image SHA${shasum_algorithm}: $downloaded_sha"
    else
      err "Failed to download image"
    fi
  else
    log_info "Image exists, checking if update needed..."
    if check_shasum "$@"; then
      log_info "Image is current, no update needed"
    else
      log_info "Image is outdated, downloading new version..."

      if [ ${REMOVE_OLD_IMAGE} = true ]; then
        log_info "Removing old images..."
        # remove original and backup images
        rm -v "${file_name%.*}"* 2>&1 | tee -a "$LOG_FILE" || true
      elif [ ${BACKUP_IMAGES} = true ]; then
        # backup all images with or without date
        backup_images "${file_name}"
      fi

      if download_with_retry "${remote_url}" "${download_name}" "cloud image"; then
        log_info "Successfully downloaded updated image: ${download_name}"

        # Calculate and log the SHA for verification
        local downloaded_sha=$(shasum -a "${shasum_algorithm}" "${download_name}" | awk '{print $1}')
        log_info "Downloaded image SHA${shasum_algorithm}: $downloaded_sha"
      else
        err "Failed to download updated image"
      fi
    fi
  fi

  # Final status
  log_info "Image update completed successfully for ${DISTRO_NAME}-${RELEASE_NAME}"
  log_info "Final image: ${STORAGE_PATH}/${download_name}"
  log_info "Log saved to: $LOG_FILE"

  exit 0
}

main "$@"
