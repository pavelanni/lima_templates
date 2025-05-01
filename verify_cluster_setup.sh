#!/bin/bash

# Default values
VM_PREFIX="node"
MOUNT_PREFIX="/mnt/minio"
MINIO_USER="minio-user"
MINIO_GROUP="minio-user"
MINIO_UID=990
MINIO_GID=990

# Help function
show_help() {
    echo "Usage: $0 -n NUM_NODES [-p VM_PREFIX]"
    echo
    echo "Verify MinIO cluster setup across nodes"
    echo
    echo "Options:"
    echo "  -n NUM_NODES     Number of nodes to verify"
    echo "  -p VM_PREFIX     Prefix for VM names (default: node)"
    echo "  -h              Show this help message"
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
    if ! limactl list | grep -q "^${vm_name}[[:space:]]*Running[[:space:]]"; then
        echo "❌ VM '${vm_name}' is not running"
        return 1
    fi
    echo "✅ VM '${vm_name}' is running"
    return 0
}

# Function to verify disk mounts
verify_mounts() {
    local vm_name=$1
    echo "Verifying disk mounts on ${vm_name}..."

    local commands="
        # Check if mount points exist and are mounted
        for i in {1..4}; do
            mount_point='${MOUNT_PREFIX}'\$i
            if [ ! -d \"\$mount_point\" ]; then
                echo \"❌ Mount point \$mount_point does not exist\"
                continue
            fi

            if ! mountpoint -q \"\$mount_point\"; then
                echo \"❌ \$mount_point is not mounted\"
                continue
            fi

            # Check filesystem type
            if ! findmnt -n -o FSTYPE \"\$mount_point\" | grep -q '^xfs$'; then
                echo \"❌ \$mount_point is not XFS filesystem\"
                continue
            fi

            # Check permissions
            owner=\$(stat -c '%U:%G' \"\$mount_point\")
            if [ \"\$owner\" != \"${MINIO_USER}:${MINIO_GROUP}\" ]; then
                echo \"❌ \$mount_point has incorrect ownership: \$owner\"
                continue
            fi

            echo \"✅ \$mount_point is properly configured\"
        done
    "

    if ! limactl shell "${vm_name}" sudo bash -c "${commands}"; then
        return 1
    fi
    return 0
}

# Function to verify MinIO service
verify_minio_service() {
    local vm_name=$1
    echo "Verifying MinIO service on ${vm_name}..."

    local commands="
        # Check if MinIO service is enabled and running
        if ! systemctl is-enabled minio &>/dev/null; then
            echo \"❌ MinIO service is not enabled\"
            return 1
        fi
        echo \"✅ MinIO service is enabled\"

        if ! systemctl is-active minio &>/dev/null; then
            echo \"❌ MinIO service is not running\"
            systemctl status minio
            return 1
        fi
        echo \"✅ MinIO service is running\"

        # Check MinIO binary
        if [ ! -x /usr/local/bin/minio ]; then
            echo \"❌ MinIO binary not found or not executable\"
            return 1
        fi
        echo \"✅ MinIO binary is installed\"

        # Check MinIO client (mc)
        if [ ! -x /usr/local/bin/mcli ] && [ ! -x /usr/local/bin/mc ]; then
            echo \"❌ MinIO client (mc) not found or not executable\"
            return 1
        fi
        echo \"✅ MinIO client is installed\"

        # Check license file
        if [ ! -f /etc/minio/minio.license ]; then
            echo \"❌ MinIO license file not found\"
            return 1
        fi
        license_perms=\$(stat -c '%a %U:%G' /etc/minio/minio.license)
        if [ \"\$license_perms\" != \"400 ${MINIO_USER}:${MINIO_GROUP}\" ]; then
            echo \"❌ MinIO license file has incorrect permissions: \$license_perms\"
            return 1
        fi
        echo \"✅ MinIO license file is properly configured\"

        # Check environment file
        if [ ! -f /etc/default/minio ]; then
            echo \"❌ MinIO environment file not found\"
            return 1
        fi
        env_perms=\$(stat -c '%a %U:%G' /etc/default/minio)
        if [ \"\$env_perms\" != \"644 root:root\" ]; then
            echo \"❌ MinIO environment file has incorrect permissions: \$env_perms\"
            return 1
        fi
        echo \"✅ MinIO environment file is properly configured\"
    "

    if ! limactl shell "${vm_name}" sudo bash -c "${commands}"; then
        return 1
    fi
    return 0
}

# Function to verify network connectivity
verify_network() {
    local vm_name=$1
    echo "Verifying network connectivity from ${vm_name}..."

    # Get IP addresses of all nodes
    local ip_list=""
    for ((n = 1; n <= NUM_NODES; n++)); do
        local target_vm="${VM_PREFIX}${n}"
        if [ "$target_vm" != "$vm_name" ]; then
            local ip=$(limactl shell "$target_vm" ip -4 addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
            if [ -n "$ip" ]; then
                ip_list="$ip_list $ip"
            fi
        fi
    done

    # Test connectivity to each node
    local commands="
        for ip in $ip_list; do
            if ! ping -c 1 -W 2 \$ip &>/dev/null; then
                echo \"❌ Cannot reach \$ip from ${vm_name}\"
                continue
            fi
            echo \"✅ Successfully reached \$ip from ${vm_name}\"
        done
    "

    if ! limactl shell "${vm_name}" sudo bash -c "${commands}"; then
        return 1
    fi
    return 0
}

# Function to verify user/group configuration
verify_user_config() {
    local vm_name=$1
    echo "Verifying MinIO user/group configuration on ${vm_name}..."

    local commands="
        # Check if group exists with correct GID
        if ! getent group ${MINIO_GROUP} | grep -q \"^${MINIO_GROUP}:x:${MINIO_GID}\"; then
            echo \"❌ Group ${MINIO_GROUP} not found or has incorrect GID\"
            return 1
        fi
        echo \"✅ Group ${MINIO_GROUP} is properly configured\"

        # Check if user exists with correct UID and GID
        if ! getent passwd ${MINIO_USER} | grep -q \"^${MINIO_USER}:x:${MINIO_UID}:${MINIO_GID}\"; then
            echo \"❌ User ${MINIO_USER} not found or has incorrect UID/GID\"
            return 1
        fi
        echo \"✅ User ${MINIO_USER} is properly configured\"
    "

    if ! limactl shell "${vm_name}" sudo bash -c "${commands}"; then
        return 1
    fi
    return 0
}

# Function to verify SELinux configuration
verify_selinux() {
    local vm_name=$1
    echo "Verifying SELinux configuration on ${vm_name}..."

    local commands="
        # Check if SELinux is enabled and enforcing
        if ! command -v getenforce &>/dev/null; then
            echo \"❌ SELinux is not installed\"
            return 1
        fi

        selinux_status=\$(getenforce)
        if [ \"\$selinux_status\" != \"Enforcing\" ]; then
            echo \"❌ SELinux is not in enforcing mode (current: \$selinux_status)\"
            return 1
        fi
        echo \"✅ SELinux is enabled and enforcing\"

        # Check MinIO binary context
        minio_context=\$(ls -Z /usr/local/bin/minio | grep -o 'system_u:object_r:[^:]*' || true)
        if [ -z \"\$minio_context\" ]; then
            echo \"❌ Could not get SELinux context for MinIO binary\"
            return 1
        fi
        if ! echo \"\$minio_context\" | grep -q 'bin_t'; then
            echo \"❌ Incorrect SELinux context for MinIO binary: \$minio_context\"
            return 1
        fi
        echo \"✅ MinIO binary has correct SELinux context\"

        # Check MinIO environment file context
        env_context=\$(ls -Z /etc/default/minio | grep -o 'system_u:object_r:[^:]*' || true)
        if [ -z \"\$env_context\" ]; then
            echo \"❌ Could not get SELinux context for environment file\"
            return 1
        fi
        if ! echo \"\$env_context\" | grep -q 'systemd_unit_file_t'; then
            echo \"❌ Incorrect SELinux context for environment file: \$env_context\"
            return 1
        fi
        echo \"✅ Environment file has correct SELinux context\"

        # Check mount points context
        for i in {1..4}; do
            mount_point='${MOUNT_PREFIX}'\$i
            mount_context=\$(ls -Zd \"\$mount_point\" | grep -o 'system_u:object_r:[^:]*' || true)
            if [ -z \"\$mount_context\" ]; then
                echo \"❌ Could not get SELinux context for \$mount_point\"
                continue
            fi
            if ! echo \"\$mount_context\" | grep -q 'mnt_t'; then
                echo \"❌ Incorrect SELinux context for \$mount_point: \$mount_context\"
                continue
            fi
            echo \"✅ Mount point \$mount_point has correct SELinux context\"
        done
    "

    if ! limactl shell "${vm_name}" sudo bash -c "${commands}"; then
        return 1
    fi
    return 0
}

# Main verification loop
echo "Starting cluster verification..."
echo "================================"

for ((node = 1; node <= NUM_NODES; node++)); do
    vm_name="${VM_PREFIX}${node}"
    echo
    echo "Verifying node: ${vm_name}"
    echo "------------------------"

    # Check if VM is running
    if ! check_vm_running "${vm_name}"; then
        continue
    fi

    # Verify all components
    verify_user_config "${vm_name}"
    verify_mounts "${vm_name}"
    verify_minio_service "${vm_name}"
    verify_network "${vm_name}"
    verify_selinux "${vm_name}"

    echo "------------------------"
done

echo
echo "Verification completed!"
