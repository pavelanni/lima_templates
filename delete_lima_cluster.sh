#!/bin/bash

# Default values
VM_PREFIX="node"

# Help function
show_help() {
    echo "Usage: $0 [-p VM_PREFIX] [-f]"
    echo
    echo "Delete all Lima VMs with the specified prefix"
    echo
    echo "Options:"
    echo "  -p VM_PREFIX     Prefix for VM names to delete (default: node)"
    echo "  -f              Force deletion without confirmation"
    echo "  -h              Show this help message"
    exit 1
}

# Parse command line arguments
FORCE=0
while getopts "p:fh" opt; do
    case $opt in
    p) VM_PREFIX="$OPTARG" ;;
    f) FORCE=1 ;;
    h) show_help ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        show_help
        ;;
    esac
done

# Get list of VMs with the specified prefix
VM_LIST=$(limactl list --json | grep '"name": "'"${VM_PREFIX}"'[^"]*"' | cut -d'"' -f4)

if [ -z "$VM_LIST" ]; then
    echo "No VMs found with prefix '${VM_PREFIX}'"
    exit 0
fi

# Show VMs that will be deleted
echo "The following VMs will be deleted:"
echo "$VM_LIST" | sed 's/^/- /'
echo

# Ask for confirmation unless -f is specified
if [ "$FORCE" -eq 0 ]; then
    read -p "Are you sure you want to delete these VMs? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled"
        exit 1
    fi
fi

# Stop and delete each VM
for vm in $VM_LIST; do
    echo "Processing $vm..."

    # Check if VM is running
    if limactl list | grep -q "^${vm}[[:space:]]*Running[[:space:]]"; then
        echo "Stopping $vm..."
        if ! limactl stop "$vm"; then
            echo "Failed to stop $vm"
            continue
        fi
    fi

    # Delete the VM
    echo "Deleting $vm..."
    if ! limactl delete "$vm"; then
        echo "Failed to delete $vm"
        continue
    fi

    echo "Successfully deleted $vm"
    echo "------------------------"
done

echo "Cleanup completed!"
