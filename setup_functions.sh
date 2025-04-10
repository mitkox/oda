#!/bin/bash

# Color codes for output
readonly RED='[0;31m'
readonly GREEN='[0;32m'
readonly YELLOW='[1;33m'
readonly BLUE='[0;34m'
readonly NC='[0m'

# Helper functions
log() {
    echo -e "${GREEN}[ODA]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
    exit 1
}

check_sudo() {
    if ! sudo -v; then
        error "Sudo privileges are required for installation"
    fi
    # Keep sudo alive
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
}

check_disk_space() {
    local free_space
    free_space=$(df -BG "$HOME" | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$free_space" -lt "$REQUIRED_SPACE_GB" ]; then
        error "Insufficient disk space. At least ${REQUIRED_SPACE_GB}GB required, found ${free_space}GB"
    fi
}

check_internet_connection() {
    if ! ping -c 1 google.com &> /dev/null; then
        error "No internet connection detected"
    fi
}

setup_package_manager() {
    case "$DISTRO" in
        ubuntu)
            PACKAGE_MANAGER="apt-get"
            INSTALL_CMD="sudo apt-get install -y"
            UPDATE_CMD="sudo apt-get update"
            ;;
        redhat)
            PACKAGE_MANAGER="dnf"
            INSTALL_CMD="sudo dnf install -y"
            UPDATE_CMD="sudo dnf check-update"
            ;;
    esac
}

detect_distribution() {
    # Read os-release file
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu)
                DISTRO="ubuntu"
                log "Detected Ubuntu distribution"
                # Check version
                if [ "${VERSION_ID%%.*}" -lt 20 ]; then
                    error "Ubuntu version must be 20.04 or newer (found $VERSION_ID)"
                fi
                ;;
            rhel|centos|rocky|almalinux)
                DISTRO="redhat"
                log "Detected Red Hat compatible distribution: $ID"
                # Check version
                if [ "${VERSION_ID%%.*}" -lt 8 ]; then
                    error "Red Hat compatible distribution version must be 8 or newer (found $VERSION_ID)"
                fi
                ;;
            *)
                error "Unsupported Linux distribution: $ID. Currently supporting Ubuntu and Red Hat compatible distributions"
                ;;
        esac
        setup_package_manager
    else
        error "Could not detect Linux distribution"
    fi
}

detect_gpu() {
    if lspci | grep -i nvidia > /dev/null; then
        HAS_GPU=true
        # Check NVIDIA driver compatibility
        if nvidia-smi &> /dev/null; then
            local driver_version
            driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader)
            log "NVIDIA GPU detected with driver version: $driver_version"
        else
            warn "NVIDIA GPU detected but no drivers installed"
        fi
    else
        warn "No NVIDIA GPU detected, installing CPU-only versions"
    fi
}

# Function to mark a step as completed
mark_completed() {
    local step=$1
    mkdir -p "$(dirname "$STATUS_FILE")"
    touch "$STATUS_FILE"
    if ! grep -q "^$step$" "$STATUS_FILE" 2>/dev/null; then
        echo "$step" >> "$STATUS_FILE"
    fi
}

# Function to check if a step is completed
is_completed() {
    local step=$1
    [ -f "$STATUS_FILE" ] && grep -q "^$step$" "$STATUS_FILE" 2>/dev/null
}

# Function to run a step if not already completed
run_step() {
    local step=$1
    local step_func=$2
    
    if ! is_completed "$step"; then
        log "Running step: $step"
        if $step_func; then
            mark_completed "$step"
            log "Step completed successfully: $step"
        else
            error "Step failed: $step"
            return 1
        fi
    else
        log "Skipping completed step: $step"
    fi
    return 0
}

validate_system_requirements() {
    log "Validating system requirements..."
    
    # Check disk space (20GB minimum)
    local free_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$free_space" -lt 20 ]; then
        error "Insufficient disk space. Need at least 20GB free, have ${free_space}GB"
    fi

    # Check internet connectivity
    if ! ping -c 1 google.com &> /dev/null; then
        error "No internet connection detected"
    fi

    # Check if running as root
    if [ "$(id -u)" = "0" ]; then
        warn "This script is running as root. It is recommended to run it as a normal user"
    fi

    # Check if sudo is available
    if ! command -v sudo &> /dev/null; then
        error "sudo is required but not installed"
    fi

    # Verify sudo access
    if ! sudo -v; then
        error "User does not have sudo privileges"
    fi

    log "System requirements validated successfully"
}

cleanup() {
    log "Cleaning up temporary files..."
    
    # Remove temporary directories
    sudo rm -rf /tmp/oda-*
    
    # Clean package manager cache based on distribution
    if [ "$PACKAGE_MANAGER" = "apt-get" ]; then
        sudo apt-get clean
    elif [ "$PACKAGE_MANAGER" = "dnf" ]; then
        sudo dnf clean all
    fi
    
    # Remove downloaded installers
    rm -f ~/cuda*.run
    rm -f ~/vscode*.deb
    rm -f ~/vscode*.rpm
    
    log "Cleanup completed successfully"
}

# Function to display a usage message
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message and exit"
    echo "  --no-gpu        Disable GPU installation"
    echo "  --verbose       Enable verbose output"
    exit 1
}