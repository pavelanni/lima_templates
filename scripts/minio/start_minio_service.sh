#!/bin/bash

# start_minio_service.sh - Script to enable and start MinIO service across all nodes
# This script starts the service on all nodes simultaneously to avoid blocking

# Default values
VM_PREFIX="node"

# Help function
show_help() {
    echo "Usage: $0 -n NUM_NODES [-p VM_PREFIX]"
    echo
    echo "Enable and start MinIO service across all nodes simultaneously"
    echo
    echo "Options:"
    echo "  -n NUM_NODES    Number of nodes (VMs) to process"
    echo "  -p VM_PREFIX    Prefix for VM names (default: node)"
    echo "  -h             Show this help message"
    exit 1
}

# Parse command line arguments
while getopts "n:p:h" opt; do
    case $opt in
    n) NUM_NODES="$OPTARG" ;;
    p) VM_PREFIX="$OPTARG" ;;
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

# Function to check if VM is running
check_vm_running() {
    local vm_name=$1
    limactl list | grep -q "^${vm_name}[[:space:]]*Running[[:space:]]"
}

# First enable the service on all nodes
echo "Enabling MinIO service on all nodes..."
for ((node = 1; node <= NUM_NODES; node++)); do
    vm_name="${VM_PREFIX}${node}"

    if ! check_vm_running "$vm_name"; then
        echo "Error: VM '$vm_name' is not running"
        exit 1
    fi

    echo "Enabling MinIO service on $vm_name..."
    if ! limactl shell "$vm_name" sudo systemctl enable minio.service; then
        echo "Warning: Failed to enable MinIO service on $vm_name"
    fi
done

# Start the service on all nodes simultaneously using background processes
echo "Starting MinIO service on all nodes simultaneously..."
pids=()
for ((node = 1; node <= NUM_NODES; node++)); do
    vm_name="${VM_PREFIX}${node}"
    echo "Starting MinIO service on $vm_name..."
    limactl shell "$vm_name" sudo systemctl start minio.service &
    pids+=($!)
done

# Wait for all start commands to complete
echo "Waiting for start commands to complete..."
failed=0
for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
        echo "Warning: Start command failed for one of the nodes"
        failed=$((failed + 1))
    fi
done

# Check service status on all nodes
echo -e "\nChecking MinIO service status across all nodes:"
for ((node = 1; node <= NUM_NODES; node++)); do
    vm_name="${VM_PREFIX}${node}"
    echo -e "\nStatus for $vm_name:"
    if ! limactl shell "$vm_name" sudo systemctl status minio.service --no-pager; then
        echo "Warning: MinIO service not running properly on $vm_name"
        failed=$((failed + 1))
    fi
done

if [ $failed -gt 0 ]; then
    echo -e "\nWarning: There were $failed failures during service startup"
    exit 1
else
    echo -e "\nMinIO service started successfully on all nodes!"
fi
