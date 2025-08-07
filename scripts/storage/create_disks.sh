#!/bin/bash

# Default values
DISK_PREFIX="minio"

# Help function
show_help() {
    echo "Usage: $0 -n NUM_DISKS -s SIZE [-k PREFIX]"
    echo
    echo "Create multiple Lima disks with specified size"
    echo
    echo "Options:"
    echo "  -n NUM_DISKS    Number of disks to create"
    echo "  -s SIZE         Size of each disk (e.g., 10GiB, 100GB)"
    echo "  -k PREFIX       Prefix for disk names (default: minio)"
    echo "  -f             Force creation without confirmation"
    echo "  -h             Show this help message"
    exit 1
}

# Parse command line arguments
FORCE=0
while getopts "n:s:k:fh" opt; do
    case $opt in
    n) NUM_DISKS="$OPTARG" ;;
    s) SIZE="$OPTARG" ;;
    k) DISK_PREFIX="$OPTARG" ;;
    f) FORCE=1 ;;
    h) show_help ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        show_help
        ;;
    esac
done

# Validate required parameters
if [ -z "$NUM_DISKS" ] || [ -z "$SIZE" ]; then
    echo "Error: Both number of disks (-n) and size (-s) are required"
    show_help
fi

# Validate number of disks
if ! [[ "$NUM_DISKS" =~ ^[0-9]+$ ]] || [ "$NUM_DISKS" -lt 1 ]; then
    echo "Error: Number of disks must be a positive integer"
    exit 1
fi

# Validate size format
if ! [[ "$SIZE" =~ ^[0-9]+[GT](iB|B)$ ]]; then
    echo "Error: Size must be in format like 10GiB, 100GB, 1TB"
    echo "Examples: 10GiB, 20GB, 1TB, 500GB"
    exit 1
fi

# Check for existing disks
EXISTING_DISKS=()
for ((i = 1; i <= NUM_DISKS; i++)); do
    disk_name="${DISK_PREFIX}${i}"
    if limactl disk list --json | grep -q "\"name\": \"$disk_name\""; then
        EXISTING_DISKS+=("$disk_name")
    fi
done

# Warn about existing disks
if [ ${#EXISTING_DISKS[@]} -gt 0 ]; then
    echo "Warning: The following disks already exist:"
    printf '%s\n' "${EXISTING_DISKS[@]}" | sed 's/^/- /'
    echo
    if [ "$FORCE" -eq 0 ]; then
        read -p "Do you want to skip existing disks and continue? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Operation cancelled"
            exit 1
        fi
    fi
fi

# Show creation plan
echo "Will create disks:"
for ((i = 1; i <= NUM_DISKS; i++)); do
    disk_name="${DISK_PREFIX}${i}"
    exists=0
    for existing in "${EXISTING_DISKS[@]}"; do
        if [ "$disk_name" = "$existing" ]; then
            exists=1
            break
        fi
    done
    if [ "$exists" -eq 0 ]; then
        echo "- ${disk_name} (${SIZE})"
    fi
done
echo

# Ask for confirmation unless -f is specified
if [ "$FORCE" -eq 0 ]; then
    read -p "Proceed with disk creation? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled"
        exit 1
    fi
fi

# Create disks
echo "Creating disks..."
for ((i = 1; i <= NUM_DISKS; i++)); do
    disk_name="${DISK_PREFIX}${i}"

    # Skip if disk already exists
    exists=0
    for existing in "${EXISTING_DISKS[@]}"; do
        if [ "$disk_name" = "$existing" ]; then
            exists=1
            break
        fi
    done
    if [ "$exists" -eq 1 ]; then
        echo "Skipping existing disk: ${disk_name}"
        continue
    fi

    echo "Creating ${disk_name} (${SIZE})..."
    if ! limactl disk create "${disk_name}" --size "$SIZE" --format raw; then
        echo "Failed to create disk: ${disk_name}"
        continue
    fi
    echo "✅ Created ${disk_name}"
done

echo
echo "Disk creation completed!"
echo "You can check the disks with: limactl disk list"
