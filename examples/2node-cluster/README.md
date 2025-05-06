# 2-Node MinIO Cluster Example

This example demonstrates how to set up a basic 2-node AIStor cluster using Lima VMs.

## Prerequisites

- Lima 1.0+ is installed and configured. Lima 1.1+ is recommended.
- At least 40GB of free disk space
- 8GB of available RAM

## Setup Steps

In the following steps we assume that you run all commands from the root directory of this repository.

1. Create the required disks:

```bash
./scripts/storage/create_disks.sh -n 8 -s 100GiB  # 4 disks per node
```

1. Create the cluster:

Use this command for Lima versions 1.1+

```bash
./scripts/cluster/create_lima_cluster.sh -t ./templates/minio/rocky-server.yaml -n 2 -d 4
```

If your Lima version is earlier than 1.1, please use this command:

```bash
./scripts/cluster/create_lima_cluster.sh -t ./templates/minio/rocky-server-pre1.1.yaml -n 2 -d 4
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
./scripts/minio/configure_minio_cluster.sh -n 2 -l ./config/license/minio.license -e ./config/env/aistor_env_template
```

1. Start the `minio` service:

```bash
./scripts/minio/start_minio_service.sh -n 2
```

1. Verify the setup:

```bash
./scripts/minio/verify_cluster_setup.sh -n 2
```

1. Access the cluster's console via http://localhost:9101 using `minioadmin:minioadmin`.

1. Create an alias for the cluster:

```bash
mc alias set aistor-lima http://localhost:9100 minioadmin minioadmin
```

## Cleanup

To delete the cluster:

```bash
./scripts/cluster/delete_lima_cluster.sh -p node
```
