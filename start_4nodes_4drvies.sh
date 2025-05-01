#!/bin/bash
set -e
set -x
LICENSE_FILE=minio.license
ENV_FILE=aistor_env_4disks_4nodes

for i in {1..4}; do
  limactl start --log-level=debug --name minio-node${i} \
    --tty=false \
    https://raw.githubusercontent.com/pavelanni/lima_templates/refs/heads/main/aistor_rocky_4disks_node${i}.yaml
done

# copy the license file to all nodes
for i in {1..4}; do
  limactl cp ${LICENSE_FILE} minio-node${i}:/tmp/minio.license
  limactl shell minio-node${i} bash -c "sudo mv /tmp/minio.license /etc/minio/minio.license"
done

# copy the environment file to all nodes
# add two commands to satisfy SELinux
for i in {1..4}; do
  limactl cp ${ENV_FILE} minio-node${i}:/tmp/minio.env
  limactl shell minio-node${i} bash -c "sudo mv /tmp/minio.env /etc/default/minio"
  limactl shell minio-node${i} bash -c "sudo semanage fcontext -a -t systemd_unit_file_t '/etc/default/minio'"
  limactl shell minio-node${i} bash -c "sudo restorecon -v /etc/default/minio"
done

# sleep for 5 sec before restarting MinIO
echo "Sleeping for 5 seconds..."
sleep 5

# start the minio service on all nodes
for i in {1..4}; do
  limactl shell minio-node${i} bash -c "sudo systemctl restart minio"
done
