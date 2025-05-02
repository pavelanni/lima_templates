# Lima Templates Documentation

## Overview

This repository provides Lima VM templates optimized for running MinIO clusters. The templates are designed to work with Lima v1.1.0 and later, utilizing the new template composition feature.

## Template Structure

All templates use Lima's built-in base templates:

- `template://_images/rocky-9`: Provides the Rocky Linux 9 base image
- `template://_default/mounts`: Provides default mount configurations

## Available Templates

### Rocky Linux Templates

#### rocky-4disks.yaml

- **Purpose**: Basic MinIO node with 4 data disks
- **Requirements**:
  - CPU: 2 cores
  - Memory: 4 GiB
  - System Disk: 20 GB
  - Data Disks: 4 × user-defined size
- **Use Case**: Small to medium clusters, testing environments

#### rocky-8disks.yaml

- **Purpose**: High-capacity MinIO node with 8 data disks
- **Requirements**:
  - CPU: 4 cores
  - Memory: 8 GiB
  - System Disk: 20 GB
  - Data Disks: 8 × user-defined size
- **Use Case**: Production environments, high-capacity storage

## Template Features

### Networking

- Uses Lima's user-mode networking (lima: user-v2)
- Automatic DNS resolution between nodes
- Host access via SSH

### Storage

- Separate system and data disks
- Data disks left unformatted for MinIO setup
- XFS filesystem support
- 9p filesystem disabled for better performance

### Resource Allocation

- Configurable CPU and memory
- Recommended minimums provided
- Scalable for different workloads

## Usage Notes

1. **Disk Names**:
   - Follow the pattern: minio1, minio2, etc.
   - Limited to 7 characters due to XFS label limitations
   - Must be created before starting VMs

2. **Network Configuration**:
   - VMs can communicate using internal DNS
   - Format: lima-{vm_name}.internal
   - Example: lima-node1.internal

3. **Mount Points**:
   - Home directory mounted read-only
   - /tmp/lima mounted read-write
   - Additional mounts can be added as needed

## Pre-1.1.0 Templates

For Lima versions before 1.1.0, check the `templates/pre-1.1.0` directory. These templates:

- Don't use template composition
- Include all configuration in a single file
- May have different resource requirements
