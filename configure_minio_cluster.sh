#!/bin/bash

# Default values
VM_PREFIX="node"
ARCH="arm64" # or amd64

# Help function
show_help() {
    echo "Usage: $0 -n NUM_NODES [-p VM_PREFIX] [-a ARCH] -l LICENSE_FILE -e ENV_FILE"
    echo
    echo "Install and configure MinIO across cluster nodes"
    echo
    echo "Options:"
    echo "  -n NUM_NODES     Number of nodes (VMs) to process"
    echo "  -p VM_PREFIX     Prefix for VM names (default: node)"
    echo "  -a ARCH         Architecture: arm64 or amd64 (default: arm64)"
    echo "  -l LICENSE_FILE Path to MinIO license file"
    echo "  -e ENV_FILE     Path to MinIO environment file"
    echo "  -h              Show this help message"
    exit 1
}

# Parse command line arguments
while getopts "n:p:a:l:e:h" opt; do
    case $opt in
    n) NUM_NODES="$OPTARG" ;;
    p) VM_PREFIX="$OPTARG" ;;
    a) ARCH="$OPTARG" ;;
    l) LICENSE_FILE="$OPTARG" ;;
    e) ENV_FILE="$OPTARG" ;;
    h) show_help ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        show_help
        ;;
    esac
done

# Check required parameters
if [ -z "$NUM_NODES" ] || [ -z "$LICENSE_FILE" ] || [ -z "$ENV_FILE" ]; then
    echo "Error: Missing required parameters"
    show_help
fi

# Validate parameters
if ! [[ "$NUM_NODES" =~ ^[0-9]+$ ]] || [ "$NUM_NODES" -lt 1 ]; then
    echo "Error: NUM_NODES must be a positive integer"
    exit 1
fi

if [ ! -f "$LICENSE_FILE" ]; then
    echo "Error: License file '$LICENSE_FILE' not found"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file '$ENV_FILE' not found"
    exit 1
fi

if [[ "$ARCH" != "arm64" && "$ARCH" != "amd64" ]]; then
    echo "Error: Architecture must be either 'arm64' or 'amd64'"
    exit 1
fi

# Function to check if VM is running
check_vm_running() {
    local vm_name=$1
    limactl list | grep -q "^${vm_name}[[:space:]]*Running[[:space:]]"
}

# Function to install MinIO and MC on a node
install_minio() {
    local vm_name=$1
    echo "Installing MinIO and MC on ${vm_name}..."

    local commands="
        # Install net-tools
        dnf install -y net-tools

        # Install MinIO
        curl -o /tmp/minio.rpm https://dl.min.io/aistor/minio/release/linux-${ARCH}/minio.rpm
        rpm -i /tmp/minio.rpm

        # Install MinIO Client (mc)
        curl -o /tmp/mc.rpm https://dl.min.io/aistor/mc/release/linux-${ARCH}/mc-enterprise.rpm
        rpm -i /tmp/mc.rpm
        ln -sf /usr/local/bin/mcli /usr/local/bin/mc

        # Create necessary directories
        mkdir -p /etc/minio
        mkdir -p /etc/default
    "

    if ! limactl shell "${vm_name}" sudo bash -c "${commands}"; then
        echo "Error: Failed to install MinIO on ${vm_name}"
        return 1
    fi

    echo "Successfully installed MinIO on ${vm_name}"
    return 0
}

# Function to configure MinIO on a node
configure_minio() {
    local vm_name=$1
    echo "Configuring MinIO on ${vm_name}..."

    # Copy license file
    echo "Copying license file..."
    if ! limactl cp "${LICENSE_FILE}" "${vm_name}:/tmp/minio.license"; then
        echo "Error: Failed to copy license file to ${vm_name}"
        return 1
    fi

    # Copy environment file
    echo "Copying environment file..."
    if ! limactl cp "${ENV_FILE}" "${vm_name}:/tmp/minio.env"; then
        echo "Error: Failed to copy environment file to ${vm_name}"
        return 1
    fi

    # Move files and set SELinux context
    local config_commands="
        # Move license file
        mv /tmp/minio.license /etc/minio/minio.license
        chown minio-user:minio-user /etc/minio/minio.license
        chmod 400 /etc/minio/minio.license

        # Move and configure environment file
        mv /tmp/minio.env /etc/default/minio
        chown root:root /etc/default/minio
        chmod 644 /etc/default/minio

        # Configure SELinux
        semanage fcontext -a -t systemd_unit_file_t '/etc/default/minio'
        restorecon -v /etc/default/minio

        # Enable and start MinIO service
        systemctl enable minio
        systemctl start minio
    "

    if ! limactl shell "${vm_name}" sudo bash -c "${config_commands}"; then
        echo "Error: Failed to configure MinIO on ${vm_name}"
        return 1
    fi

    echo "Successfully configured MinIO on ${vm_name}"
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

    # Install MinIO
    if ! install_minio "${vm_name}"; then
        echo "Failed to install MinIO on ${vm_name}"
        continue
    fi

    # Configure MinIO
    if ! configure_minio "${vm_name}"; then
        echo "Failed to configure MinIO on ${vm_name}"
        continue
    fi

    echo "----------------------------------------"
done

echo "MinIO cluster setup completed"
