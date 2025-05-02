#!/bin/bash

# delete_disks.sh - Script to delete multiple Lima disks for MinIO
# Usage: delete_disks.sh -n <number_of_disks> [-p <prefix>] [-f]

set -e

# Default values
DISK_PREFIX="minio"
FORCE=false

# Function to display usage
usage() {
    echo "Usage: $0 -n <number_of_disks> [-p <prefix>] [-f]"
    echo "Options:"
    echo "  -n <number>   Number of disks to delete (required)"
    echo "  -p <prefix>   Disk name prefix (default: minio)"
    echo "  -f           Force delete without confirmation"
    echo "  -h           Display this help message"
    exit 1
}

# Function to validate numeric input
validate_number() {
    if ! [[ "$1" =~ ^[0-9]+$ ]]; then
        echo "Error: '$1' is not a valid number"
        exit 1
    fi
    if [ "$1" -lt 1 ]; then
        echo "Error: Number of disks must be greater than 0"
        exit 1
    fi
}

# Parse command line arguments
while getopts "n:p:fh" opt; do
    case $opt in
    n)
        N_DISKS="$OPTARG"
        validate_number "$N_DISKS"
        ;;
    p)
        DISK_PREFIX="$OPTARG"
        ;;
    f)
        FORCE=true
        ;;
    h)
        usage
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        usage
        ;;
    esac
done

# Check if required arguments are provided
if [ -z "$N_DISKS" ]; then
    echo "Error: Number of disks (-n) is required"
    usage
fi

# Function to check if disk exists
disk_exists() {
    limactl disk list | grep -q "^${1}[[:space:]]"
}

# Function to delete a disk
delete_disk() {
    local disk_name="$1"
    if disk_exists "$disk_name"; then
        echo "Deleting disk: $disk_name"
        limactl disk delete "$disk_name"
        if [ $? -eq 0 ]; then
            echo "✓ Successfully deleted disk: $disk_name"
        else
            echo "✗ Failed to delete disk: $disk_name"
            return 1
        fi
    else
        echo "! Disk not found: $disk_name (skipping)"
    fi
}

# Display summary and ask for confirmation
echo "Will delete the following disks:"
for i in $(seq 1 "$N_DISKS"); do
    disk_name="${DISK_PREFIX}${i}"
    if disk_exists "$disk_name"; then
        echo "  - $disk_name"
    else
        echo "  - $disk_name (not found)"
    fi
done

# Ask for confirmation unless force flag is set
if [ "$FORCE" != true ]; then
    read -p "Do you want to proceed with deletion? (y/N) " confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        echo "Operation cancelled"
        exit 0
    fi
fi

# Delete the disks
echo "Deleting disks..."
failed=0
for i in $(seq 1 "$N_DISKS"); do
    if ! delete_disk "${DISK_PREFIX}${i}"; then
        failed=$((failed + 1))
    fi
done

# Summary
total_deleted=$((N_DISKS - failed))
echo
echo "Summary:"
echo "- Total disks processed: $N_DISKS"
echo "- Successfully deleted: $total_deleted"
if [ $failed -gt 0 ]; then
    echo "- Failed to delete: $failed"
    exit 1
fi

echo "All disks deleted successfully!"
