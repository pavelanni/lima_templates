#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
VM_PREFIX="node"
MOUNT_SCRIPT="${SCRIPT_DIR}/mount_disks.sh"

# Help function
show_help() {
    echo "Usage: $0 -n NUM_NODES [-p VM_PREFIX] [-s SCRIPT_PATH]"
    echo
    echo "Setup MinIO disks across multiple Lima VMs"
    echo
    echo "Options:"
    echo "  -n NUM_NODES     Number of nodes (VMs) to process"
    echo "  -p VM_PREFIX     Prefix for VM names (default: node)"
    echo "  -s SCRIPT_PATH   Path to the disk mounting script (default: ${SCRIPT_DIR}/mount_disks.sh)"
    echo "  -h              Show this help message"
    exit 1
}

# Parse command line arguments
while getopts "n:p:s:h" opt; do
    case $opt in
    n) NUM_NODES="$OPTARG" ;;
    p) VM_PREFIX="$OPTARG" ;;
    s) MOUNT_SCRIPT="$OPTARG" ;;
    h) show_help ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        show_help
        ;;
    esac
done

# Check required parameters
if [ -z "$NUM_NODES" ]; then
    echo "Error: Number of nodes (-n) is required"
    show_help
fi

# Validate parameters
if ! [[ "$NUM_NODES" =~ ^[0-9]+$ ]] || [ "$NUM_NODES" -lt 1 ]; then
    echo "Error: NUM_NODES must be a positive integer"
    exit 1
fi

# Check if mount script exists
if [ ! -f "$MOUNT_SCRIPT" ]; then
    echo "Error: Mount script '$MOUNT_SCRIPT' not found"
    exit 1
fi

# Function to check if VM is running
check_vm_running() {
    local vm_name=$1
    limactl list | grep -q "^${vm_name}[[:space:]]*Running[[:space:]]"
}

# Process each VM
for ((node = 1; node <= NUM_NODES; node++)); do
    vm_name="${VM_PREFIX}${node}"

    echo "Processing VM: $vm_name"

    # Check if VM is running
    if ! check_vm_running "$vm_name"; then
        echo "Error: VM '$vm_name' is not running"
        continue
    fi

    echo "Copying mount script to $vm_name..."
    if ! limactl cp "$MOUNT_SCRIPT" "$vm_name:/tmp/mount_disks.sh"; then
        echo "Error: Failed to copy mount script to $vm_name"
        continue
    fi

    echo "Making script executable and running it as root in $vm_name..."
    limactl shell "$vm_name" sudo chmod +x /tmp/mount_disks.sh
    if ! limactl shell "$vm_name" sudo /tmp/mount_disks.sh; then
        echo "Error: Failed to execute mount script in $vm_name"
        continue
    fi

    echo "Successfully configured disks in $vm_name"
    echo "----------------------------------------"
done

echo "Disk setup process completed"
