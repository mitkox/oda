#!/bin/bash
set -euo pipefail

# Configuration variables
RAM_SIZE=$(free -g | awk '/^Mem:/{print $2}')
ARC_MAX_SIZE=$((RAM_SIZE / 8))  # 1/8 of total RAM
ARC_MIN_SIZE=$((ARC_MAX_SIZE / 2))
ZRAM_SIZE=$((RAM_SIZE / 2))  # Half of RAM
TMPFS_SIZE=$((RAM_SIZE / 4))  # Quarter of RAM
MODEL_CACHE="/mnt/model-cache"

# Function to check if running as root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root" 
        exit 1
    fi
}

# Function to check system requirements
check_requirements() {
    local required_packages=("zfsutils-linux" "zram-config" "util-linux")
    
    for pkg in "${required_packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            echo "Installing $pkg..."
            apt-get install -y "$pkg"
        fi
    done
}

# Function to configure ZFS ARC
configure_arc() {
    echo "Configuring ZFS ARC..."
    
    # Set ARC size limits
    local arc_min_bytes=$((ARC_MIN_SIZE * 1024 * 1024 * 1024))
    local arc_max_bytes=$((ARC_MAX_SIZE * 1024 * 1024 * 1024))
    
    echo "Setting ARC min size to ${ARC_MIN_SIZE}GB and max size to ${ARC_MAX_SIZE}GB"
    
    # Update sysctl.conf
    local sysctl_conf="/etc/sysctl.conf"
    grep -v "vfs.zfs.arc_" "$sysctl_conf" > "$sysctl_conf.tmp" || true
    echo "vfs.zfs.arc_min=$arc_min_bytes" >> "$sysctl_conf.tmp"
    echo "vfs.zfs.arc_max=$arc_max_bytes" >> "$sysctl_conf.tmp"
    mv "$sysctl_conf.tmp" "$sysctl_conf"
    
    # Apply settings immediately
    sysctl -p
}

# Function to configure L2ARC on SSD
configure_l2arc() {
    local ssd_device="$1"
    local pool_name="$2"
    
    echo "Configuring L2ARC on $ssd_device for pool $pool_name..."
    
    # Check if device exists
    if [ ! -b "$ssd_device" ]; then
        echo "Error: Device $ssd_device not found"
        return 1
    fi
    
    # Create a new partition for L2ARC
    echo "Creating partition for L2ARC..."
    parted "$ssd_device" mkpart primary 0% 100GB
    
    # Wait for partition to be available
    sleep 2
    
    # Get the new partition number
    local partition="${ssd_device}1"
    
    # Add L2ARC to the pool
    zpool add "$pool_name" cache "$partition"
}

# Function to configure zram
configure_zram() {
    echo "Configuring zram..."
    
    # Create zram config
    cat > /etc/default/zram-config <<EOF
# zram config for LLM cache
PERCENT=$((ZRAM_SIZE * 100 / RAM_SIZE))
PRIORITY=100
EOF
    
    # Restart zram service
    systemctl restart zram-config
}

# Function to setup tmpfs for model cache
setup_model_cache() {
    echo "Setting up model cache in RAM..."
    
    # Create mount point
    mkdir -p "$MODEL_CACHE"
    
    # Remove existing tmpfs mount if present
    if grep -qs "$MODEL_CACHE" /proc/mounts; then
        umount "$MODEL_CACHE"
    fi
    
    # Mount tmpfs
    mount -t tmpfs -o size=${TMPFS_SIZE}G,mode=1777 tmpfs "$MODEL_CACHE"
    
    # Add to fstab
    if ! grep -qs "$MODEL_CACHE" /etc/fstab; then
        echo "tmpfs $MODEL_CACHE tmpfs size=${TMPFS_SIZE}G,mode=1777 0 0" >> /etc/fstab
    fi
}

# Function to optimize ZFS dataset
optimize_zfs_dataset() {
    local pool_name="$1"
    local dataset_name="$2"
    
    echo "Optimizing ZFS dataset $pool_name/$dataset_name..."
    
    # Set optimal properties for LLM storage
    zfs set recordsize=1M "$pool_name/$dataset_name"
    zfs set compression=lz4 "$pool_name/$dataset_name"
    zfs set atime=off "$pool_name/$dataset_name"
    zfs set primarycache=metadata "$pool_name/$dataset_name"
    zfs set prefetch=1 "$pool_name/$dataset_name"
    zfs set logbias=throughput "$pool_name/$dataset_name"
    zfs set xattr=sa "$pool_name/$dataset_name"
    zfs set redundant_metadata=most "$pool_name/$dataset_name"
    zfs set sync=disabled "$pool_name/$dataset_name"
    
    # Show current settings
    zfs get all "$pool_name/$dataset_name" | grep -E 'recordsize|compression|atime|primarycache|prefetch|logbias|xattr|redundant_metadata|sync'
}

# Function to setup enhanced monitoring
setup_monitoring() {
    cat > /usr/local/bin/monitor-llm-cache.sh <<EOF
#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "\${BLUE}=== ZFS Cache Stats ===\${NC}"
arc_summary | grep -E "cache hit|cache miss|hit rate"

echo -e "\n\${BLUE}=== ZFS Latency Stats ===\${NC}"
zpool iostat -v 1 3

echo -e "\n\${BLUE}=== IO Stats and Queue Depth ===\${NC}"
iostat -dx 1 3

echo -e "\n\${BLUE}=== Memory Usage ===\${NC}"
free -h
echo -e "\nVirtual Memory Stats:"
vmstat -w 1 3

echo -e "\n\${BLUE}=== Memory Fragmentation ===\${NC}"
cat /proc/buddyinfo

echo -e "\n\${BLUE}=== ZFS Dataset Performance ===\${NC}"
zpool status
zfs get compressratio,used,available,logicalused

# Monitor L2ARC if available
if zpool status | grep -q "cache"; then
    echo -e "\n\${BLUE}=== L2ARC Stats ===\${NC}"
    arc_summary | grep -A 10 "L2 ARC Summary"
fi

EOF
    
    chmod +x /usr/local/bin/monitor-llm-cache.sh

    # Create a systemd service for periodic monitoring
    cat > /etc/systemd/system/llm-cache-monitor.service <<EOF
[Unit]
Description=LLM Cache Performance Monitor
After=zfs.target

[Service]
Type=simple
ExecStart=/usr/local/bin/monitor-llm-cache.sh
StandardOutput=append:/var/log/llm-cache-monitor.log
StandardError=append:/var/log/llm-cache-monitor.log
Restart=always
RestartSec=300

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable llm-cache-monitor.service
    systemctl start llm-cache-monitor.service
}

# Function to create model preload script
create_preload_script() {
    local zfs_storage="$1"
    
    cat > /usr/local/bin/preload-models.sh <<EOF
#!/bin/bash

MODEL_CACHE="$MODEL_CACHE"
ZFS_STORAGE="$zfs_storage"

preload_model() {
    local model_path="\$1"
    local model_name=\$(basename "\$model_path")
    
    echo "Preloading \$model_name into RAM cache..."
    if [ -d "\$model_path" ]; then
        cp -r "\$model_path" "\$MODEL_CACHE/"
        ln -sf "\$MODEL_CACHE/\$model_name" "\$model_path"
    fi
}

# Add your frequently used models here
# Example: preload_model "\$ZFS_STORAGE/model1"
EOF
    
    chmod +x /usr/local/bin/preload-models.sh
}

# Main script execution
main() {
    check_root
    
    echo "LLM Storage Optimization Setup"
    echo "=============================="
    echo "Total RAM: ${RAM_SIZE}GB"
    echo "ARC Size: ${ARC_MAX_SIZE}GB"
    echo "ZRAM Size: ${ZRAM_SIZE}GB"
    echo "Model Cache Size: ${TMPFS_SIZE}GB"
    
    # Get user input
    read -p "Enter ZFS pool name: " POOL_NAME
    read -p "Enter dataset name for LLM storage: " DATASET_NAME
    read -p "Enter SSD device for L2ARC (e.g., /dev/sda): " SSD_DEVICE
    read -p "Enter ZFS storage path: " ZFS_STORAGE
    
    # Confirm settings
    echo -e "\nConfirm settings:"
    echo "Pool name: $POOL_NAME"
    echo "Dataset: $DATASET_NAME"
    echo "L2ARC device: $SSD_DEVICE"
    echo "Storage path: $ZFS_STORAGE"
    read -p "Continue? (y/n): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
    
    # Run setup steps
    check_requirements
    configure_arc
    configure_l2arc "$SSD_DEVICE" "$POOL_NAME"
    configure_zram
    setup_model_cache
    optimize_zfs_dataset "$POOL_NAME" "$DATASET_NAME"
    create_preload_script "$ZFS_STORAGE"
    setup_monitoring
    
    echo -e "\nSetup complete!"
    echo "To monitor performance, run: /usr/local/bin/monitor-llm-cache.sh"
    echo "To preload models, edit and run: /usr/local/bin/preload-models.sh"
}

main "$@"