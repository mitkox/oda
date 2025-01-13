#!/bin/bash
set -euo pipefail

# Default values
PARALLEL_TRANSFERS=4
VERIFY_CHECKSUMS=true
VERBOSE=false
DRY_RUN=false

# Function to show usage
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]
Migrate and optimize Hugging Face cache for ZFS storage.

Options:
    -d, --destination DIR    New cache directory location
    -p, --parallel NUM      Number of parallel transfers (default: 4)
    --no-verify            Skip checksum verification
    --dry-run             Show what would be done without making changes
    -v, --verbose         Show detailed progress
    -h, --help            Show this help message
EOF
    exit 1
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--destination)
                NEW_CACHE_DIR="$2"
                shift 2
                ;;
            -p|--parallel)
                PARALLEL_TRANSFERS="$2"
                shift 2
                ;;
            --no-verify)
                VERIFY_CHECKSUMS=false
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done
}

# Function to check available space
check_space() {
    local source_size=$(du -sb "$1" 2>/dev/null | cut -f1)
    local target_free=$(df -B1 --output=avail "$2" | tail -n1)
    
    if [ -n "$source_size" ] && [ -n "$target_free" ]; then
        echo "Source size: $(numfmt --to=iec $source_size)"
        echo "Target free space: $(numfmt --to=iec $target_free)"
        if [ "$source_size" -gt "$target_free" ]; then
            echo "Error: Insufficient space in target location."
            exit 1
        fi
    fi
}

# Function to verify ZFS dataset with enhanced optimizations
verify_zfs_dataset() {
    local path="$1"
    if ! zfs list -H -o mountpoint | grep -q "^$path$"; then
        echo "Warning: $path is not a ZFS dataset mountpoint."
        read -p "Would you like to create a new ZFS dataset for this path? (y/n) " create_dataset
        if [[ "$create_dataset" =~ ^[Yy]$ ]]; then
            read -p "Enter the pool name for the new dataset: " pool_name
            sudo zfs create "$pool_name/huggingface_cache"
            
            # Enhanced ZFS optimizations
            sudo zfs set compression=lz4 "$pool_name/huggingface_cache"
            sudo zfs set recordsize=1M "$pool_name/huggingface_cache"
            sudo zfs set atime=off "$pool_name/huggingface_cache"
            sudo zfs set primarycache=metadata "$pool_name/huggingface_cache"
            sudo zfs set logbias=throughput "$pool_name/huggingface_cache"
            sudo zfs set xattr=sa "$pool_name/huggingface_cache"
            sudo zfs set redundant_metadata=most "$pool_name/huggingface_cache"
            sudo zfs set sync=disabled "$pool_name/huggingface_cache"
            
            # Verify settings
            echo "ZFS dataset settings:"
            zfs get all "$pool_name/huggingface_cache" | grep -E 'compression|recordsize|atime|primarycache|logbias|xattr|redundant_metadata|sync'
        else
            exit 1
        fi
    fi
}

# Function to verify file integrity
verify_integrity() {
    local source_count=$(find "$1" -type f | wc -l)
    local target_count=$(find "$2" -type f | wc -l)
    
    if [ "$source_count" -ne "$target_count" ]; then
        echo "Error: File count mismatch. Source: $source_count, Target: $target_count"
        return 1
    fi
    return 0
}

# Function to calculate and verify checksums
verify_checksums() {
    local source="$1"
    local target="$2"
    
    if [ "$VERIFY_CHECKSUMS" = true ]; then
        echo "Verifying file checksums..."
        find "$source" -type f -exec sh -c '
            src_sum=$(sha256sum "$1" | cut -d" " -f1)
            dst_sum=$(sha256sum "${2}${1#$3}" | cut -d" " -f1)
            if [ "$src_sum" != "$dst_sum" ]; then
                echo "Checksum mismatch for: ${1#$3}"
                exit 1
            fi
        ' sh {} "$target" "$source" \;
    fi
}

# Enhanced rsync with progress
enhanced_rsync() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] Would copy files from $CURRENT_CACHE_DIR to $NEW_CACHE_DIR"
        return 0
    fi
    
    if command -v pv >/dev/null 2>&1; then
        tar cf - "$CURRENT_CACHE_DIR" | pv -s "$(du -sb "$CURRENT_CACHE_DIR" | awk '{print $1}')" | tar xf - -C "$(dirname "$NEW_CACHE_DIR")"
    else
        rsync -av --progress --remove-source-files \
              --parallel="$PARALLEL_TRANSFERS" \
              "$CURRENT_CACHE_DIR/" "$NEW_CACHE_DIR/"
    fi
}

# Main script starts here
echo "Hugging Face Cache Migration Script (ZFS-optimized)"

# Check for required commands
for cmd in zfs rsync python3 numfmt; do
    if ! command -v "$cmd" >/dev/null; then
        echo "Error: Required command '$cmd' not found. Please install it first."
        exit 1
    fi
done

parse_args "$@"

# Define the current cache directory
CURRENT_CACHE_DIR="$HOME/.cache/huggingface"

# Verify ZFS dataset
verify_zfs_dataset "$NEW_CACHE_DIR"

# Check available space
check_space "$CURRENT_CACHE_DIR" "$NEW_CACHE_DIR"

# Create the new cache directory with proper permissions
echo "Creating new cache directory at $NEW_CACHE_DIR..."
sudo mkdir -p "$NEW_CACHE_DIR"
sudo chown $USER:$USER "$NEW_CACHE_DIR"
sudo chmod 755 "$NEW_CACHE_DIR"

# Move existing cache data using enhanced rsync
if [ -d "$CURRENT_CACHE_DIR" ]; then
    echo "Moving existing cache from $CURRENT_CACHE_DIR to $NEW_CACHE_DIR..."
    echo "This will free up space on your SSD as files are moved..."
    
    enhanced_rsync
    
    # Remove empty directories after rsync
    find "$CURRENT_CACHE_DIR" -type d -empty -delete
    
    # Verify file count integrity
    if ! verify_integrity "$CURRENT_CACHE_DIR" "$NEW_CACHE_DIR"; then
        echo "Warning: File count mismatch detected. Please verify the migration manually."
    fi
    
    # Verify checksums
    verify_checksums "$CURRENT_CACHE_DIR" "$NEW_CACHE_DIR"
else
    echo "No existing cache found at $CURRENT_CACHE_DIR."
fi

# Set the HF_HOME environment variable
echo "Setting HF_HOME environment variable..."
# Detect shell and update the appropriate configuration file
if [ "$SHELL" == "/bin/zsh" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [ "$SHELL" == "/bin/bash" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
else
    echo "Unsupported shell: $SHELL. Please set HF_HOME manually in your shell configuration."
    exit 1
fi

# Update or add the HF_HOME environment variable
if ! grep -q "export HF_HOME=" "$SHELL_CONFIG"; then
    echo "export HF_HOME=$NEW_CACHE_DIR" >> "$SHELL_CONFIG"
    echo "Added HF_HOME to $SHELL_CONFIG."
else
    sed -i "s|^export HF_HOME=.*|export HF_HOME=$NEW_CACHE_DIR|" "$SHELL_CONFIG"
    echo "Updated HF_HOME in $SHELL_CONFIG."
fi

# Reload shell configuration
echo "Reloading $SHELL_CONFIG..."
source "$SHELL_CONFIG"

# Verify the new cache directory with Python
echo "Verifying new cache directory with Python..."
if ! python3 -c "from transformers.utils import logging; logging.get_logger().info('Cache directory:'); print(logging.HF_CACHE)"; then
    echo "Error: Failed to verify cache directory with Python. Please check your Hugging Face installation."
    exit 1
fi

# Final ZFS optimization checks
echo "Applying ZFS optimizations..."
zfs_dataset=$(zfs list -H -o name,mountpoint | grep "$NEW_CACHE_DIR" | cut -f1)
if [ -n "$zfs_dataset" ]; then
    sudo zfs get compression,recordsize,atime "$zfs_dataset"
fi

echo "Migration completed successfully!"
echo "New cache location: $NEW_CACHE_DIR"
echo "Please verify that your applications work correctly with the new cache location."