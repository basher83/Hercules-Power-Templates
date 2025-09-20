#!/bin/bash
#
# Create a Proxmox Template
# Source: https://github.com/trfore/proxmox-template-scripts
#
# Copyright 2022 Taylor Fore
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
# ENHANCEMENT 1: Proper error handling
# - Added set -euo pipefail for strict error handling
# - Added error trap to capture line numbers on failure
# ====================================================================
set -euo pipefail
trap 'echo "Error occurred at line $LINENO. Exit code: $?" >&2' ERR

# ====================================================================
# ENHANCEMENT 2: Comprehensive logging
# - Added file-based logging to /var/log with fallback to /tmp
# - Color-coded output for better readability
# - Timestamps in log files for debugging
# ====================================================================
# Logging setup
LOG_FILE="/var/log/proxmox-template-build-$(date +%Y%m%d_%H%M%S).log"
if ! touch "$LOG_FILE" 2>/dev/null; then
    LOG_FILE="/tmp/proxmox-template-build-$(date +%Y%m%d_%H%M%S).log"
fi
readonly LOG_FILE

# Color codes
if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]] && [[ -z "${NO_COLOR:-}" ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly NC='\033[0m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly NC=''
fi

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "$LOG_FILE"
}

# ====================================================================
# ENHANCEMENT 3: True dry-run mode support
# - Added run() wrapper function for all mutating commands
# - Ensures no actual changes in dry-run mode
# - Shows what would be executed without side effects
# ====================================================================
# Dry-run wrapper function
run() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would run: $*"
    else
        "$@"
    fi
}

# Cleanup function
VM_CREATION_STARTED=false
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script failed with exit code: $exit_code"
        if [[ "$VM_CREATION_STARTED" == "true" ]] && [[ -n "${VM_ID:-}" ]]; then
            log_info "Attempting to clean up partial VM creation..."
            qm destroy "$VM_ID" 2>/dev/null || true
        fi
        echo -e "${RED}Script failed! Check the log for details: $LOG_FILE${NC}"
    fi
}
trap cleanup EXIT

log_info "Starting Proxmox template builder"
log_info "Log file: $LOG_FILE"

# Required Values
VM_ID=${VM_ID:-9000}
VM_NAME=${VM_NAME:-"template"}
VM_IMAGE=${VM_IMAGE:-""}
# Optional Values
VM_BIOS=${VM_BIOS:-"seabios"}
VM_CPU_CORES=${VM_CPU_CORES:-1}
VM_CPU_SOCKETS=${VM_CPU_SOCKETS:-1}
VM_CPU_TYPE=${VM_CPU_TYPE:-"host"}
VM_MACHINE=${VM_MACHINE:-"q35"}
VM_MEMORY=${VM_MEMORY:-1024}
VM_NET_BRIDGE=${VM_NET_BRIDGE:-"vmbr0"}
VM_NET_TYPE=${VM_NET_TYPE:-"virtio"}
VM_NET_VLAN=${VM_NET_VLAN:-""}
VM_NET_IP=${VM_NET_IP:-"dhcp"}
VM_NET_GW=${VM_NET_GW:-""}

# ====================================================================
# ENHANCEMENT 5: Dual network interface support
# Author: basher83
# Date: September 2025
#
# This enhancement extends the original script to support dual network
# interfaces on Proxmox VMs. This is particularly useful for VMs that
# need to span multiple network segments (e.g., management + data networks).
#
# Features:
# - Second network bridge (--net2-bridge)
# - Independent VLAN tagging for second interface (--net2-vlan)
# - Separate IP configuration for second interface (--net2-ip, --net2-gw)
# - Support for both DHCP and static IP on second interface
#
# Based on original work from proxmox-template-scripts by Taylor Fore
# ====================================================================
VM_NET2_BRIDGE=${VM_NET2_BRIDGE:-""}
VM_NET2_TYPE=${VM_NET2_TYPE:-"virtio"}
VM_NET2_VLAN=${VM_NET2_VLAN:-""}
VM_NET2_IP=${VM_NET2_IP:-"dhcp"}
VM_NET2_GW=${VM_NET2_GW:-""}
VM_OS=${VM_OS:-"l26"}
VM_RESIZE=${VM_RESIZE:-"1G"}
VM_SCSIHW=${VM_SCSIHW:-"virtio-scsi-pci"}
VM_STORAGE=${VM_STORAGE:-"local-lvm"}
VM_VENDOR_FILE=${VM_VENDOR_FILE:-"vendor-data.yaml"}
# ====================================================================
# ENHANCEMENT 4: SSH key injection and custom cloud-init username
# - Added VM_SSH_KEYS for SSH public key injection
# - Added VM_CI_USER for custom cloud-init username
# - Integrates with Proxmox cloud-init for secure access
# ====================================================================
VM_SSH_KEYS=${VM_SSH_KEYS:-""}
VM_CI_USER=${VM_CI_USER:-""}  # Cloud-init username
DRY_RUN=${DRY_RUN:-false}

function err() {
  log_error "$*"
  exit 2
}

function help() {
  echo "
  Usage: ${0##*/} -i <VM_ID> -n <VM_NAME> --img <VM_IMAGE>
  Examples:
    ${0##*/} -i 9000 -n ubuntu20 --img /var/lib/vz/template/iso/ubuntu-20.04-server-cloudimg-amd64.img
    ${0##*/} -i 9000 -n ubuntu20-$(date +'%Y%m%d') --img /var/lib/vz/template/iso/ubuntu-20.04-server-cloudimg-amd64.img
    ${0##*/} --cpu-cores 2 --cpu-sockets 2 -i 9000 -n ubuntu20 --img /var/lib/vz/template/iso/ubuntu-20.04-server-cloudimg-amd64.img
    ${0##*/} --net-vlan 10 -i 9000 -n ubuntu20 --img /var/lib/vz/template/iso/ubuntu-20.04-server-cloudimg-amd64.img
    ${0##*/} --net-bridge vmbr0 --net2-bridge vmbr1 -i 9000 -n ubuntu20 --img /var/lib/vz/template/iso/ubuntu-20.04-server-cloudimg-amd64.img
    ${0##*/} --net-ip 192.168.1.100/24 --net-gw 192.168.1.1 -i 9000 -n ubuntu20 --img /var/lib/vz/template/iso/ubuntu-20.04-server-cloudimg-amd64.img
    ${0##*/} --net-bridge vmbr0 --net-ip 192.168.1.100/24 --net2-bridge vmbr1 --net2-ip 10.0.0.100/24 -i 9000 -n ubuntu20 --img /var/lib/vz/template/iso/ubuntu-20.04-server-cloudimg-amd64.img

  Arguments:
    --help, -h      Display this help message and exit
    --bios, -b      Specify the VM bios, ex: 'seabios' or 'ovmf' (default: 'seabios')
    --cpu-cores     Specify the number of CPU cores (default: '1')
    --cpu-sockets   Specify the number of CPU sockets (default: '1')
    --cpu-type      Specify the CPU type (default: 'host')
    --id, -i        Specify the VM ID (1-999999999)
    --image, --img  Specify the VM image (path), ex: /PATH/TO/image.{img,iso,qcow2}
    --machine       Specify the VM machine type, ex: 'pc' for i440 (default: 'q35')
    --memory, -m    Specify the VM memory (default: '1024')
    --name, -n      Specify the VM name (default: 'template')
    --net-bridge    Specify the VM network bridge (default: 'vmbr0')
    --net-type      Specify the VM network type (default: 'virtio')
    --net-vlan      Specify the VM network vlan tag (optional)
    --net-ip        Specify the VM network IP address (default: 'dhcp')
                    Format: 'dhcp' or 'x.x.x.x/xx' (e.g., '192.168.1.100/24')
    --net-gw        Specify the VM network gateway (optional)
                    Only used with static IP configuration
    --net2-bridge   Specify a second VM network bridge (optional)
    --net2-type     Specify the second VM network type (default: 'virtio')
    --net2-vlan     Specify the second VM network vlan tag (optional)
    --net2-ip       Specify the second VM network IP address (default: 'dhcp')
                    Format: 'dhcp' or 'x.x.x.x/xx' (e.g., '192.168.2.100/24')
    --net2-gw       Specify the second VM network gateway (optional)
                    Only used with static IP configuration
    --os            Specify the VM OS (default: 'l26')
    --resize        Increase the VM boot disk size (default: '1G')
    --scsihw        Specify the VM storage controller (default: 'virtio-scsi-pci')
    --storage, -s   Specify the VM storage (default: 'local-lvm')
    --vendor-file   Specify the cloud-init vendor file (default: 'vendor-data.yaml')
    --ssh-keys      Path to SSH public keys file to inject
    --ci-user       Cloud-init username for the default user
    --dry-run       Test mode - show what would be done without making changes

  Using Environment Variables:
    VM_ID
    VM_NAME
    VM_IMAGE
  "
  exit 1
}

function usage() {
  printf "Usage: %s -i <VM_ID> -n <VM_NAME> --img <VM_IMAGE> \n" "${0##*/}" >&2
  exit 1
}

function main() {
  if [[ ($? -ne 0) || ($# -eq 0) ]]; then
    usage
  fi

  # Check for --dry-run early
  for arg in "$@"; do
    if [[ "$arg" == "--dry-run" ]]; then
      DRY_RUN=true
      break
    fi
  done

  # Skip permission check in dry-run mode
  if [[ "${DRY_RUN:-false}" == "false" ]]; then
    if [ "$(id -u)" -ne 0 ] && [ ! -x /usr/sbin/qm ]; then
      err "You do not have permission to execute /usr/sbin/qm"
    fi
  fi

  OPTIONS=hb:i:m:n:s:
  LONGOPTS=help,bios:,cpu-cores:,cpu-sockets:,cpu-type:,id:,img:,image:,machine:,memory:,name:,net-bridge:,net-type:,net-vlan:,net-ip:,net-gw:,net2-bridge:,net2-type:,net2-vlan:,net2-ip:,net2-gw:,os:,resize:,scsihw:,storage:,vendor-file:,ssh-keys:,ci-user:,dry-run
  NOARG_OPTS=(-h --help --dry-run)

  TEMP=$(getopt -n "${0##*/}" -o $OPTIONS --long $LONGOPTS -- "${@}") || exit 2
  eval set -- "$TEMP"
  unset TEMP

  while true; do
    [[ ! ${NOARG_OPTS[*]} =~ ${1} ]] && [[ ${2} == -* ]] && {
      err "Missing argument for ${1}"
    }
    case "${1}" in
    --help | -h)
      help
      ;;
    --bios | -b)
      VM_BIOS=${2}
      shift 2
      continue
      ;;
    --cpu-cores)
      VM_CPU_CORES=${2}
      shift 2
      continue
      ;;
    --cpu-sockets)
      VM_CPU_SOCKETS=${2}
      shift 2
      continue
      ;;
    --cpu-type)
      VM_CPU_TYPE=${2}
      shift 2
      continue
      ;;
    --id | -i)
      VM_ID=${2}
      shift 2
      continue
      ;;
    --img | --image)
      VM_IMAGE=${2}
      shift 2
      continue
      ;;
    --machine)
      VM_MACHINE=${2}
      shift 2
      continue
      ;;
    --memory | -m)
      VM_MEMORY=${2}
      shift 2
      continue
      ;;
    --name | -n)
      VM_NAME=${2}
      shift 2
      continue
      ;;
    --net-bridge)
      VM_NET_BRIDGE=${2}
      shift 2
      continue
      ;;
    --net-type)
      VM_NET_TYPE=${2}
      shift 2
      continue
      ;;
    --net-vlan)
      VM_NET_VLAN=${2}
      shift 2
      continue
      ;;
    --net-ip)
      VM_NET_IP=${2}
      shift 2
      continue
      ;;
    --net-gw)
      VM_NET_GW=${2}
      shift 2
      continue
      ;;
    --net2-bridge)
      VM_NET2_BRIDGE=${2}
      shift 2
      continue
      ;;
    --net2-type)
      VM_NET2_TYPE=${2}
      shift 2
      continue
      ;;
    --net2-vlan)
      VM_NET2_VLAN=${2}
      shift 2
      continue
      ;;
    --net2-ip)
      VM_NET2_IP=${2}
      shift 2
      continue
      ;;
    --net2-gw)
      VM_NET2_GW=${2}
      shift 2
      continue
      ;;
    --os)
      VM_OS=${2}
      shift 2
      continue
      ;;
    --resize)
      VM_RESIZE=${2}
      shift 2
      continue
      ;;
    --scsihw)
      VM_SCSIHW=${2}
      shift 2
      continue
      ;;
    --storage | -s)
      VM_STORAGE=${2}
      shift 2
      continue
      ;;
    --vendor-file)
      VM_VENDOR_FILE=${2}
      shift 2
      continue
      ;;
    --ssh-keys)
      VM_SSH_KEYS=${2}
      shift 2
      continue
      ;;
    --ci-user)
      VM_CI_USER=${2}
      shift 2
      continue
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      continue
      ;;
    --)
      shift
      break
      ;;
    *)
      err "Parsing arguments in main()"
      ;;
    esac
  done

  readonly VM_BIOS VM_CPU_CORES VM_CPU_SOCKETS VM_CPU_TYPE VM_ID VM_IMAGE
  readonly VM_MACHINE VM_MEMORY VM_NAME VM_NET_BRIDGE VM_NET_TYPE VM_NET_VLAN VM_NET_IP VM_NET_GW
  readonly VM_NET2_BRIDGE VM_NET2_TYPE VM_NET2_VLAN VM_NET2_IP VM_NET2_GW
  readonly VM_OS VM_RESIZE VM_SCSIHW VM_STORAGE VM_VENDOR_FILE

  # check required variables
  if [ -z "${VM_ID}" ] || [ -z "${VM_NAME}" ] || [ -z "${VM_IMAGE}" ]; then
    if [ -z "${VM_ID}" ]; then err "Missing VM ID"; fi
    if [ -z "${VM_NAME}" ]; then err "Missing VM Name"; fi
    if [ -z "${VM_IMAGE}" ]; then err "Missing VM Image '*.{img,iso,qcow2}'"; fi
  elif [ ! -e "$VM_IMAGE" ]; then
    err "VM Image file is missing, '${VM_IMAGE}'"
  fi

  # Check if VM ID already exists (skip in dry-run mode)
  if [[ "$DRY_RUN" == "false" ]]; then
    if command -v qm &>/dev/null && qm list 2>/dev/null | grep -q "^${VM_ID} "; then
      err "VM ID ${VM_ID} already exists. Please choose a different ID or remove the existing VM."
    fi
  fi

  # check for cloud-init file storage and config (skip in dry-run for non-Proxmox testing)
  if [[ "${DRY_RUN:-false}" == "false" ]]; then
    if [ -e /var/lib/vz/snippets ]; then
      if [ ! -e /var/lib/vz/snippets/"$VM_VENDOR_FILE" ]; then
        err "cloud-init file is missing, '/var/lib/vz/snippets/${VM_VENDOR_FILE}'"
      fi
    else
      err "/var/lib/vz/snippets directory is missing, enable 'snippets' storage"
    fi
  else
    log_warn "[DRY-RUN] Skipping cloud-init file checks"
  fi

  echo "VM ID:             ${VM_ID}"
  echo "VM Name:           ${VM_NAME}"
  echo "VM Image:          ${VM_IMAGE}"
  echo "VM OS:             ${VM_OS}"
  echo "VM Bios:           ${VM_BIOS}"
  echo "VM Machine Type:   ${VM_MACHINE}"
  echo "VM CPU Type:       ${VM_CPU_TYPE}"
  echo "VM CPU Cores:      ${VM_CPU_CORES}"
  echo "VM CPU Sockets:    ${VM_CPU_SOCKETS}"
  echo "VM Memory:         ${VM_MEMORY}"
  echo "VM Network Type:   ${VM_NET_TYPE}"
  echo "VM Network Bridge: ${VM_NET_BRIDGE}"
  if [ -n "${VM_NET_VLAN}" ]; then
    echo "VM Network VLAN:   ${VM_NET_VLAN}"
  fi
  echo "VM Network IP:     ${VM_NET_IP}"
  if [ "${VM_NET_IP}" != "dhcp" ] && [ -n "${VM_NET_GW}" ]; then
    echo "VM Network GW:     ${VM_NET_GW}"
  fi
  if [ -n "${VM_NET2_BRIDGE}" ]; then
    echo "VM Network2 Type:  ${VM_NET2_TYPE}"
    echo "VM Network2 Bridge: ${VM_NET2_BRIDGE}"
    if [ -n "${VM_NET2_VLAN}" ]; then
      echo "VM Network2 VLAN:  ${VM_NET2_VLAN}"
    fi
    echo "VM Network2 IP:    ${VM_NET2_IP}"
    if [ "${VM_NET2_IP}" != "dhcp" ] && [ -n "${VM_NET2_GW}" ]; then
      echo "VM Network2 GW:    ${VM_NET2_GW}"
    fi
  fi
  echo "VM Storage:        ${VM_STORAGE}"
  echo "VM Storage HW:     ${VM_SCSIHW}"
  echo "Resize Boot Drive: ${VM_RESIZE}"
  echo "Cloud-init File:   ${VM_VENDOR_FILE}"

  log_info "Building Proxmox Template..."

  if [[ "$DRY_RUN" == "true" ]]; then
    log_warn "DRY-RUN MODE: No actual changes will be made"
  fi

  # create a new VM
  # Create base command
  local qm_cmd="/usr/sbin/qm create ${VM_ID} --name ${VM_NAME} \
    --description \"template created on $(date)\" \
    --ostype ${VM_OS} \
    --bios ${VM_BIOS} --machine ${VM_MACHINE} \
    --scsihw ${VM_SCSIHW} --agent enabled=1 \
    --cores ${VM_CPU_CORES} --sockets ${VM_CPU_SOCKETS} --cpu ${VM_CPU_TYPE} --memory ${VM_MEMORY} \
    --net0 ${VM_NET_TYPE},bridge=${VM_NET_BRIDGE}"

  # Add VLAN tag if specified
  if [ -n "${VM_NET_VLAN}" ]; then
    qm_cmd="${qm_cmd},tag=${VM_NET_VLAN}"
  fi

  # ====================================================================
  # ENHANCEMENT 5: Second network interface configuration
  # This code implements dual network support for VMs that need to span
  # multiple network segments or require network isolation between services.
  # ====================================================================
  # Add second network interface if bridge is specified
  if [ -n "${VM_NET2_BRIDGE}" ]; then
    qm_cmd="${qm_cmd} \
    --net1 ${VM_NET2_TYPE},bridge=${VM_NET2_BRIDGE}"

    # Add VLAN tag if specified for second interface
    if [ -n "${VM_NET2_VLAN}" ]; then
      qm_cmd="${qm_cmd},tag=${VM_NET2_VLAN}"
    fi
  fi

  # Execute the command
  if [[ "$DRY_RUN" == "false" ]]; then
    VM_CREATION_STARTED=true
    log_info "Creating VM ${VM_ID}..."
    eval "${qm_cmd}"
  else
    log_info "[DRY-RUN] Would execute: ${qm_cmd}"
  fi

  # import the cloud image
  run /usr/sbin/qm disk import "${VM_ID}" "${VM_IMAGE}" "${VM_STORAGE}"

  # attach the disk to the VM and set it as boot
  run /usr/sbin/qm set "${VM_ID}" --boot order=scsi0 \
    --scsi0 "${VM_STORAGE}":vm-"${VM_ID}"-disk-0,cache=writeback,discard=on,ssd=1

  # increase the disk image size
  run /usr/sbin/qm resize "${VM_ID}" scsi0 +"${VM_RESIZE}"

  # configure cloud-init drive
  local ipconfig0=""

  # Configure first network interface
  if [ "${VM_NET_IP}" = "dhcp" ]; then
    ipconfig0="ip=dhcp"
  else
    ipconfig0="ip=${VM_NET_IP}"
    if [ -n "${VM_NET_GW}" ]; then
      ipconfig0="${ipconfig0},gw=${VM_NET_GW}"
    fi
  fi

  local cloudinit_cmd="/usr/sbin/qm set ${VM_ID} --ide2 ${VM_STORAGE}:cloudinit --ipconfig0 ${ipconfig0}"

  # ====================================================================
  # ENHANCEMENT 5: Second network interface cloud-init configuration
  # Configures IP settings for the second network interface through
  # Proxmox cloud-init. Supports both DHCP and static IP configuration.
  # ====================================================================
  # Add ipconfig1 if second network interface is configured
  if [ -n "${VM_NET2_BRIDGE}" ]; then
    local ipconfig1=""

    # Configure second network interface
    if [ "${VM_NET2_IP}" = "dhcp" ]; then
      ipconfig1="ip=dhcp"
    else
      ipconfig1="ip=${VM_NET2_IP}"
      if [ -n "${VM_NET2_GW}" ]; then
        ipconfig1="${ipconfig1},gw=${VM_NET2_GW}"
      fi
    fi

    cloudinit_cmd="${cloudinit_cmd} --ipconfig1 ${ipconfig1}"
  fi

  # Complete the command
  cloudinit_cmd="${cloudinit_cmd} --citype nocloud --cicustom vendor=local:snippets/${VM_VENDOR_FILE}"

  # ====================================================================
  # ENHANCEMENT: Custom cloud-init username support
  # - Allows setting custom default username instead of distro defaults
  # - Useful for standardizing usernames across templates
  # ====================================================================
  # Add cloud-init username if provided
  if [ -n "${VM_CI_USER}" ]; then
    cloudinit_cmd="${cloudinit_cmd} --ciuser ${VM_CI_USER}"
  fi

  # Execute the command
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY-RUN] Would run: ${cloudinit_cmd}"
  else
    eval "${cloudinit_cmd}"
  fi

  if [ "$VM_BIOS" = "ovmf" ]; then
    # add UEFI disk
    run /usr/sbin/qm set "${VM_ID}" --efidisk0 "${VM_STORAGE}":1,efitype=4m,pre-enrolled-keys=1
  fi

  # ====================================================================
  # ENHANCEMENT: SSH key injection for secure access
  # - Injects SSH public keys via Proxmox cloud-init
  # - Enables passwordless SSH access to VMs
  # - Supports both individual keys and authorized_keys files
  # ====================================================================
  # add SSH keys if provided
  if [ -n "${VM_SSH_KEYS}" ]; then
    log_info "Adding SSH keys from ${VM_SSH_KEYS}"
    run /usr/sbin/qm set "${VM_ID}" --sshkey "${VM_SSH_KEYS}"
  fi

  # convert the VM into a template
  run /usr/sbin/qm template "${VM_ID}"

  exit
}

main "$@"
