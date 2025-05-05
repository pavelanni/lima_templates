#!/bin/bash

# Help function
show_help() {
    echo "Usage: $0 -t TEMPLATE_FILE -n NUM_NODES -d DISKS_PER_NODE [-p VM_PREFIX] [-k DISK_PREFIX]"
    echo
    echo "Create Lima VMs with configurable number of nodes and disks per node"
    echo
    echo "Options:"
    echo "  -t TEMPLATE_FILE    Path to the Lima template YAML file"
    echo "  -n NUM_NODES       Number of nodes (VMs) to create"
    echo "  -d DISKS_PER_NODE  Number of disks per node"
    echo "  -p VM_PREFIX       Prefix for VM names (default: node)"
    echo "  -k DISK_PREFIX     Prefix for disk names (default: minio)"
    echo "  -h                 Show this help message"
    exit 1
}

# Default values
DISK_PREFIX="minio"
VM_PREFIX="node"

# Parse command line arguments
while getopts "t:n:d:p:k:h" opt; do
    case $opt in
    t) TEMPLATE_FILE="$OPTARG" ;;
    n) NUM_NODES="$OPTARG" ;;
    d) DISKS_PER_NODE="$OPTARG" ;;
    p) VM_PREFIX="$OPTARG" ;;
    k) DISK_PREFIX="$OPTARG" ;;
    h) show_help ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        show_help
        ;;
    esac
done

# Check required parameters
if [ -z "$TEMPLATE_FILE" ] || [ -z "$NUM_NODES" ] || [ -z "$DISKS_PER_NODE" ]; then
    echo "Error: Missing required parameters"
    show_help
fi

# Validate parameters
if ! [[ "$NUM_NODES" =~ ^[0-9]+$ ]] || [ "$NUM_NODES" -lt 1 ]; then
    echo "Error: NUM_NODES must be a positive integer"
    exit 1
fi

if ! [[ "$DISKS_PER_NODE" =~ ^[0-9]+$ ]] || [ "$DISKS_PER_NODE" -lt 1 ]; then
    echo "Error: DISKS_PER_NODE must be a positive integer"
    exit 1
fi

# Function to check if all required disks exist
check_required_disks() {
    local existing_disks
    existing_disks=$(limactl disk list --json | grep '"name":' | cut -d'"' -f4)
    local missing_disks=()

    # Check all required disk names
    for ((node = 1; node <= NUM_NODES; node++)); do
        local start_disk=$(((node - 1) * DISKS_PER_NODE + 1))
        for ((i = 0; i < DISKS_PER_NODE; i++)); do
            local disk_num=$((start_disk + i))
            local disk_name="${DISK_PREFIX}${disk_num}"

            if ! echo "$existing_disks" | grep -q "^${disk_name}$"; then
                missing_disks+=("$disk_name")
            fi
        done
    done

    if [ ${#missing_disks[@]} -gt 0 ]; then
        echo "Error: The following required disks are missing:"
        printf '%s\n' "${missing_disks[@]}"
        echo
        echo "Please create the missing disks before running this script."
        echo "You can use 'limactl disk create' to create the required disks."
        exit 1
    fi

    echo "All required disks exist. Proceeding with VM creation..."
}

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file '$TEMPLATE_FILE' not found"
    exit 1
fi

# Check that all required disks exist before proceeding
check_required_disks

# Function to generate the --set argument for disk names
generate_disk_names() {
    local node_num=$1
    local start_disk=$(((node_num - 1) * DISKS_PER_NODE + 1))
    local set_args=""

    for ((i = 0; i < DISKS_PER_NODE; i++)); do
        disk_num=$((start_disk + i))
        if [ -n "$set_args" ]; then
            set_args="$set_args | "
        fi
        set_args="${set_args}.additionalDisks[$i].name = \"$DISK_PREFIX$disk_num\" | .additionalDisks[$i].format = false"
    done

    echo "$set_args"
}

# Function to generate the --set argument for portForwards
# For each VM, hostPorts start at 9100 + (node_num-1)*100 and 9101 + (node_num-1)*100
# guestPorts are always 9000 and 9001
# hostIP is always "0.0.0.0"
generate_port_forwards() {
    local node_num=$1
    local base_host_port=$((9100 + (node_num - 1) * 100))
    local set_args=".portForwards = ["
    set_args="${set_args}{\"guestPort\":9000,\"hostPort\":$base_host_port,\"hostIP\":\"0.0.0.0\"},"
    set_args="${set_args}{\"guestPort\":9001,\"hostPort\":$((base_host_port + 1)),\"hostIP\":\"0.0.0.0\"}"
    set_args="${set_args}]"
    echo "$set_args"
}

# Create VMs
for ((node = 1; node <= NUM_NODES; node++)); do
    vm_name="${VM_PREFIX}${node}"
    disk_names=$(generate_disk_names $node)
    port_forwards=$(generate_port_forwards $node)

    combined_set_args="$disk_names | $port_forwards"

    echo "Creating $vm_name with --set: $combined_set_args"
    limactl start --tty=false "$TEMPLATE_FILE" --name "$vm_name" --set "$combined_set_args"

    if [ $? -eq 0 ]; then
        echo "Successfully created and started $vm_name"
    else
        echo "Failed to create/start $vm_name"
        exit 1
    fi
done

echo "All VMs created successfully!"
