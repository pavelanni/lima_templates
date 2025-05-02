#!/bin/bash

# stop_minio_service.sh - Script to stop MinIO service across all nodes
# This script stops the service on all nodes simultaneously

# Default values
VM_PREFIX="node"

# Help function
show_help() {
    echo "Usage: $0 -n NUM_NODES [-p VM_PREFIX]"
    echo
    echo "Stop MinIO service across all nodes simultaneously"
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

# Stop the service on all nodes simultaneously using background processes
echo "Stopping MinIO service on all nodes simultaneously..."
pids=()
for ((node = 1; node <= NUM_NODES; node++)); do
    vm_name="${VM_PREFIX}${node}"

    if ! check_vm_running "$vm_name"; then
        echo "Error: VM '$vm_name' is not running"
        continue
    fi

    echo "Stopping MinIO service on $vm_name..."
    limactl shell "$vm_name" sudo systemctl stop minio.service &
    pids+=($!)
done

# Wait for all stop commands to complete
echo "Waiting for stop commands to complete..."
failed=0
for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
        echo "Warning: Stop command failed for one of the nodes"
        failed=$((failed + 1))
    fi
done

# Check service status on all nodes
echo -e "\nChecking MinIO service status across all nodes:"
for ((node = 1; node <= NUM_NODES; node++)); do
    vm_name="${VM_PREFIX}${node}"

    if ! check_vm_running "$vm_name"; then
        echo "Skipping status check for non-running VM: $vm_name"
        continue
    fi

    echo -e "\nStatus for $vm_name:"
    if limactl shell "$vm_name" sudo systemctl is-active minio.service --quiet; then
        echo "Warning: MinIO service is still running on $vm_name"
        failed=$((failed + 1))
    else
        echo "✓ MinIO service stopped successfully on $vm_name"
    fi
done

if [ $failed -gt 0 ]; then
    echo -e "\nWarning: There were $failed failures during service shutdown"
    exit 1
else
    echo -e "\nMinIO service stopped successfully on all nodes!"
fi
