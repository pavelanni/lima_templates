# 2-Node MinIO Cluster Example

This example demonstrates how to set up a basic 2-node MinIO cluster using Lima VMs.

## Prerequisites

- Lima installed and configured
- At least 40GB of free disk space
- 8GB of available RAM

## Setup Steps

In the following steps we assume that you run all commands from the root directory of this repository.

1. Create the required disks:

```bash
./scripts/storage/create_disks.sh -n 8 -s 100GiB  # 4 disks per node
```

1. Create the cluster:

```bash
./scripts/cluster/create_lima_cluster.sh -t ./templates/minio/rocky-4disks.yaml -n 2 -d 4
```

1. Set up MinIO users:

```bash
./scripts/minio/setup_minio_users.sh -n 2
```

1. Set up disks in the cluster nodes:

```bash
./scripts/storage/setup_minio_disks.sh -n 2
```

1. Configure MinIO (replace the path to license with your actual path or copy your license file to the specified location):

```bash
./scripts/minio/configure_minio_cluster.sh -n 2 -l ./config/license/minio.license -e ./config/env/aistor_env_4disks_2nodes
```

1. Verify the setup:

```bash
./scripts/cluster/verify_cluster_setup.sh -n 2
```

## Cleanup

To delete the cluster:

```bash
./scripts/cluster/delete_lima_cluster.sh -p node
```
