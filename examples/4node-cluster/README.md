# 4-Node MinIO Cluster Example

This example demonstrates how to set up a high-availability MinIO cluster using Lima VMs.

## Prerequisites

- Lima v1.1.0 or later
- At least 100GB of free disk space
- 16GB of available RAM

## Architecture

This setup creates a distributed MinIO cluster with:

- 4 nodes
- 4 disks per node
- Total of 16 data drives
- Distributed erasure coding
- High availability configuration

## Setup Steps

1. Create the required disks (16 total, 4 per node):

```bash
./scripts/storage/create_disks.sh -n 16 -s 20GiB
```

1. Create the cluster:

```bash
./scripts/cluster/create_lima_cluster.sh -t ./templates/minio/rocky-4disks.yaml -n 4 -d 4
```

1. Set up MinIO users:

```bash
./scripts/minio/setup_minio_users.sh -n 4
```

1. Configure MinIO:

```bash
./scripts/minio/configure_minio_cluster.sh -n 4 -l ./config/license/minio.license -e ./config/env/aistor_env_4disks_4nodes
```

1. Verify the setup:

```bash
./scripts/cluster/verify_cluster_setup.sh -n 4
```

## Cluster Details

### Network Configuration

- Each node is accessible via DNS: lima-node[1-4].internal
- Internal network for cluster communication
- Host access through Lima's user networking

### Storage Layout

Each node has:

- 20GB system disk
- 4 × 20GB data disks
- XFS filesystem on data disks
- Mounted at `/mnt/minio{1..4}`

### MinIO Configuration

- Distributed setup across all nodes
- All disks participate in erasure coding
- Automatic replication and healing
- High availability with no single point of failure

## Testing the Cluster

TODO: Update these instructions

1. Access MinIO Console:
   - URL: https://lima-node1.internal:9443
   - Default credentials in the environment file

1. Upload test data:

   ```bash
   mc alias set myminio https://lima-node1.internal:9443 admin password
   mc cp testfile myminio/bucket/
   ```

1. Test failover:

   ```bash
   # Stop one node
   ../scripts/cluster/stop_node.sh -n node2

   # Verify cluster is still accessible
   mc ls myminio/bucket/
   ```

## Cleanup

To delete the entire cluster:

```bash
./scripts/cluster/delete_lima_cluster.sh -p node -f
```
