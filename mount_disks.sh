#!/bin/bash
# Setup multiple disks for MinIO storage
# This script partitions, formats, and mounts multiple virtual disks

set -euo pipefail

# Configuration
MOUNT_PREFIX="/mnt/minio"
FILESYSTEM="xfs"
MINIO_USER="minio-user"
MINIO_GROUP="minio-user"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Function to detect available disks
detect_disks() {
    # List all block devices, filter out the main disk (vda) and CIDATA disk
    # Then extract just the disk names without the /dev/ prefix
    lsblk -d -n -o NAME,TYPE,LABEL | grep "disk" | grep -v "vda" | grep -v "cidata" | awk '{print $1}'
}

# Get the list of disks
DISKS=($(detect_disks))

# Check if disks are found
if [[ ${#DISKS[@]} -eq 0 ]]; then
    echo "No additional disks found. Please check your VM configuration."
    exit 1
fi

echo "Found ${#DISKS[@]} additional disks: ${DISKS[*]}"

# Function to get UUID of a partition
get_uuid() {
    blkid -s UUID -o value "$1"
}

disk_number=1

for disk in "${DISKS[@]}"; do
    device="/dev/${disk}"

    # Check if the disk exists
    if [[ ! -b "$device" ]]; then
        echo "Error: Disk $device does not exist"
        continue
    fi

    echo "Processing disk: $device"

    # Create a GPT partition table and a single partition
    echo "Creating partition table on $device..."
    parted -s "$device" mklabel gpt
    parted -s "$device" mkpart primary xfs 0% 100%

    # Wait for partition to be recognized by the system
    sleep 2

    partition="${device}1"

    # Format the partition with XFS
    echo "Formatting $partition with XFS..."
    mkfs.xfs -f "$partition"

    # Get UUID
    uuid=$(get_uuid "$partition")
    if [[ -z "$uuid" ]]; then
        echo "Error: Could not get UUID for $partition"
        continue
    fi

    # Create mount point
    mount_point="${MOUNT_PREFIX}${disk_number}"
    echo "Creating mount point: $mount_point"
    mkdir -p "$mount_point"

    # Mount the filesystem
    echo "Mounting $partition to $mount_point..."
    mount -t "$FILESYSTEM" "$partition" "$mount_point"

    # Add to /etc/fstab
    echo "Adding to /etc/fstab..."
    if ! grep -q "$uuid" /etc/fstab; then
        echo "UUID=$uuid $mount_point $FILESYSTEM defaults 0 2" >>/etc/fstab
        echo "Added $partition to /etc/fstab"
    else
        echo "$partition already in /etc/fstab"
    fi

    # Change ownership to MinIO user and group
    echo "Changing ownership of $mount_point to $MINIO_USER:$MINIO_GROUP..."
    chown "$MINIO_USER:$MINIO_GROUP" "$mount_point"

    echo "Disk $device setup complete, mounted at $mount_point"
    echo "-------------------------------------------"

    ((disk_number++))
done

echo "All disks have been processed"
