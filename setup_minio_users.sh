#!/bin/bash

# Default values
VM_PREFIX="node"
MINIO_GID=990
MINIO_UID=990
MINIO_USER="minio-user"
MINIO_GROUP="minio-user"

# Help function
show_help() {
    echo "Usage: $0 -n NUM_NODES [-p VM_PREFIX] [-u UID] [-g GID]"
    echo
    echo "Setup MinIO user and group across cluster nodes"
    echo
    echo "Options:"
    echo "  -n NUM_NODES     Number of nodes (VMs) to process"
    echo "  -p VM_PREFIX     Prefix for VM names (default: node)"
    echo "  -u UID          User ID for minio user (default: 990)"
    echo "  -g GID          Group ID for minio group (default: 990)"
    echo "  -h              Show this help message"
    exit 1
}

# Parse command line arguments
while getopts "n:p:u:g:h" opt; do
    case $opt in
    n) NUM_NODES="$OPTARG" ;;
    p) VM_PREFIX="$OPTARG" ;;
    u) MINIO_UID="$OPTARG" ;;
    g) MINIO_GID="$OPTARG" ;;
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

if ! [[ "$MINIO_UID" =~ ^[0-9]+$ ]] || ! [[ "$MINIO_GID" =~ ^[0-9]+$ ]]; then
    echo "Error: UID and GID must be positive integers"
    exit 1
fi

# Function to check if VM is running
check_vm_running() {
    local vm_name=$1
    limactl list | grep -q "^${vm_name}[[:space:]]*Running[[:space:]]"
}

# Function to create user and group on a node
setup_minio_user() {
    local vm_name=$1
    echo "Setting up MinIO user and group on ${vm_name}..."

    # Create commands
    local commands="
        # Check if group exists
        if ! getent group ${MINIO_GROUP} >/dev/null; then
            groupadd --system --gid ${MINIO_GID} ${MINIO_GROUP}
            echo 'Created MinIO group'
        else
            echo 'MinIO group already exists'
        fi

        # Check if user exists
        if ! getent passwd ${MINIO_USER} >/dev/null; then
            useradd --system --uid ${MINIO_UID} --gid ${MINIO_GROUP} \
                   --no-create-home --shell /sbin/nologin ${MINIO_USER}
            echo 'Created MinIO user'
        else
            echo 'MinIO user already exists'
        fi
    "

    # Execute commands on the VM
    if ! limactl shell "${vm_name}" sudo bash -c "${commands}"; then
        echo "Error: Failed to setup user/group on ${vm_name}"
        return 1
    fi

    echo "Successfully configured MinIO user and group on ${vm_name}"
    return 0
}

# Process each VM
for ((node = 1; node <= NUM_NODES; node++)); do
    vm_name="${VM_PREFIX}${node}"

    echo "Processing VM: ${vm_name}"

    # Check if VM is running
    if ! check_vm_running "${vm_name}"; then
        echo "Error: VM '${vm_name}' is not running"
        continue
    fi

    # Setup user and group
    if ! setup_minio_user "${vm_name}"; then
        echo "Failed to setup MinIO user/group on ${vm_name}"
        continue
    fi

    echo "----------------------------------------"
done

echo "User setup process completed"
