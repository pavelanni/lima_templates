# Lima templates for MinIO deployments

These templates can be used to create MinIO server instances using Lima virtual machines.

## Create Lima disks

If you want to use Lima VMs with additional disks, you should create them first.
In the provided templates we use disk names `minio1`, `minio2`, etc.

**Note**: please don't use disk names longer than 7 characters due to the limit in XFS file system labels.

We provide templates with four and eight disks.

To create eight disks 100 GiB each run the following command:

```shell
for i in {1..8}; do limactl disk create "minio${i}" --size 100GiB ; done
```

## Start the VMs

Start the server VM without additional disks:

```shell
limactl start --name minio-server --tty=false https://raw.githubusercontent.com/pavelanni/lima_templates/refs/heads/main/minio_ubuntu.yaml
```

Or, start the server VM with 4 additional disks:

```shell
limactl start --name minio-server-4d --tty=false https://raw.githubusercontent.com/pavelanni/lima_templates/refs/heads/main/minio_ubuntu_4disks.yaml
```

Or, start the server VM with 8 additional disks:

```shell
limactl start --name minio-server-8d --tty=false https://raw.githubusercontent.com/pavelanni/lima_templates/refs/heads/main/minio_ubuntu_8disks.yaml
```

Start the client VM:

```shell
limactl start --name minio-client --tty=false https://raw.githubusercontent.com/pavelanni/lima_templates/refs/heads/main/minio_ubuntu.yaml
```

Check if you can SSH into the client VM and ping the server VM:

```shell
limactl shell minio-client
cd            # get to the home directory of the VM user
ping lima-minio-server.internal  # this is the domain name of the server VM
exit
```

## Useful commands

To stop the VM and start it again, use `limactl stop VM_NAME` and `limactl start VM_NAME`.

To get the VM's internal IP address:

```shell
limactl shell VM_NAME bash -c 'hostname -i | cut -d" " -f1'
```
