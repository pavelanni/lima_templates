# Lima Templates for MinIO

This repository contains Lima VM templates and automation scripts for setting up MinIO clusters.

> **Note**: Most of the content from this repository has been copied to [github.com/pavelanni/lima-ops](https://github.com/pavelanni/lima-ops) to combine it with an Ansible-based approach. You may want to check that repository for the latest developments.

## Repository Structure

```none
lima_templates/
├── templates/          # Lima VM templates
│   └── minio/         # MinIO-specific templates
├── scripts/
│   ├── cluster/       # Cluster management scripts
│   ├── storage/       # Storage management scripts
│   └── minio/         # MinIO-specific scripts
├── config/
│   └── env/          # Environment configurations
│   └── license/      # AIStor licenses
├── examples/         # Example configurations
└── docs/             # Documentation
```

## Quick Start

See the [2-node cluster example](examples/2node-cluster/README.md) for a basic setup.

## Templates

There are several templates you can use:

- `rocky-server.yaml`: Rocky Linux 9 template to be used with Lima version 1.1+
- `rocky-server-pre1.1.yaml`: Rocky Linux 9 template to be used with Lima version 1.0
- `rocky-client.yaml`: Rocky 9 template with MinIO client and Warp tool installed; use it with Lima 1.1+
- `rocky-client-pre1.1.yaml`: Rocky 9 template with MinIO client and Warp tool installed; use it with Lima 1.0

## Scripts

### Cluster Management

- `create_lima_cluster.sh`: Create a new cluster
- `delete_lima_cluster.sh`: Delete an existing cluster

### Storage Management

- `create_disks.sh`: Create Lima disks
- `delete_disks.sh`: Delete Lima disks
- `mount_disks.sh`: Format and mount disks (used by `setup_minio_disks.sh`)
- `setup_minio_disks.sh`: Run `mount_disks.sh` in each cluster's node

### MinIO Configuration

- `setup_minio_users.sh`: Set up MinIO user and group (`minio-user:minio-user`)
- `configure_minio_cluster.sh`: Configure MinIO service in the cluster nodes
- `start_minio_service.sh`: Enable and start `systemd` MinIO service
- `verify_cluster_setup.sh`: Verify the cluster's setup and MinIO services
- `stop_minio_service.sh`: Stop `systemd` MinIO service

## Requirements

- Lima v1.0 or later (v1.1+ is recommended)
- macOS or Linux host
- Sufficient disk space for VMs and data
- Sufficient RAM for the cluster

## Cluster setup

### Create disks

Create a number of disks suitable for your cluster configuration.
E.g., a 4-node cluster with 4 disks per node will require 16 disks.
Specify the disk size in the format "100GiB" or "2TB".
The disks are thin-provisioned so they won't take a lot of space on your host.

```bash
./scripts/storage/create_disks.sh -n 16 -s 100GiB  # 4 disks per node for 4 nodes
```

### Create the cluster

Create the cluster from one of the provided templates.
The initial templates use Rocky Linux as it's one of the popular options among our customers.
Ubuntu-based templates will be added later.

Specify the number of nodes with the `-n` flag and the number of disks per node with the `-d` flag.
Use the template appropriate for the number of disks per node.
Currently we provide 4-disk and 8-disk templates.

```bash
./scripts/cluster/create_lima_cluster.sh -t ./templates/minio/rocky-server.yaml -n 2 -d 4
```

### Set up the MinIO user and group

By default, we run the MinIO `systemd` service as a user `minio-user`.
At this step, we create the user and group named `minio-user` with UID and GID 990.

In the following command specify the number of nodes in your cluster.

```bash
./scripts/minio/setup_minio_users.sh -n 2
```

### Set up disks in the cluster nodes

The disks you created are now attached to the cluster nodes, but they are not formatted or mounted.
On each node, they have to be mounted on `/mnt/minio1`, `/mnt/minio2` and so on.

The following script:

- Creates a partition on each disk on each node
- Formats them as XFS
- Gets the file system UUID from each file system
- Adds the appropriate records to the `/etc/fstab` file
- Mounts all file systems on each node

```bash
./scripts/storage/setup_minio_disks.sh -n 2
```

### Configure MinIO

To run AIStor on this cluster we have to install the software and configure it.
We have to add the AIStor license to each node and the environment variables file used by the `systemd` service.

The following script:

- Installs the `minio` and `mc` packages to each node
- Copies the license file from the host machine (you have to specify the location) to the appropriate location on each node (by default, `/etc/minio/minio.license`)
- Copies the environment variables file to the default location (`/etc/default/minio`)
- Sets the right permissions and ownership on all the files
- Set the right SELinux context for the environment variables file

Check available environment files in the `config/env` directory or create your own.

```bash
./scripts/minio/configure_minio_cluster.sh -n 2 -l ./config/license/minio.license -e ./config/env/aistor_env_template
```

### Start the AIStor service

You have to start the `systemd` service configured for AIStor.
The key moment here is that on each node you should run the `systemctl start` command,
leave it running in the background, and move on to the next node.
Only after the service has been started on all the nodes, the AIStor cluster gets quorum and reports that it's ready.

```bash
./scripts/minio/start_minio_service.sh -n 2
```

### Verify the cluster setup

This script verifies the installation, checking for all the components, permissions, and SELinux contexts.

```bash
./scripts/cluster/verify_cluster_setup.sh -n 2
```

### Create an alias

The cluster exposes the API on http://localhost:9100 and the console UI at http://localhost:9101.
Use these addresses and the default credentials `minioadmin:minioadmin` to create an alias and access the AIStor console.

```bash
mc alias set aistor-lima http://localhost:9100 minioadmin minioadmin
```

### Start the client VM (optional)

If you don't want to run the `mc` client on your laptop, you can use the provided client VM.
It has the MinIO Client (`mc`) installed as well as the Warp tool to test your cluster.

```shell
limactl start --name aistor-client --tty=false https://raw.githubusercontent.com/pavelanni/lima_templates/refs/heads/main/templates/minio/rocky-client.yaml
```

Check if you can SSH into the client VM and create an alias:

```shell
limactl shell aistor-client
cd            # get to the home directory of the VM user
mc alias set http://lima-node1.internal:9000 minioadmin minioadmin
```

## Useful commands

To stop the VM and start it again, use `limactl stop VM_NAME` and `limactl start VM_NAME`.

To get the VM's internal IP address:

```shell
limactl shell VM_NAME bash -c 'hostname -i | cut -d" " -f1'
```

## License

See [LICENSE](LICENSE) file.
