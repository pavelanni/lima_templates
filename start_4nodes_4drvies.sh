#!/bin/bash
for i in {1..4}; do
    limactl start --name minio-node${i} \
        --tty=false \
        https://raw.githubusercontent.com/pavelanni/lima_templates/refs/heads/main/aistor_rocky_4disks_node${i}.yaml
done

# copy the license file to all nodes
for i in {1..4}; do
    limactl cp minio.license minio-node${i}:/tmp/minio.license
    limactl shell minio-node${i} bash -c "sudo mv /tmp/minio.license /etc/minio/minio.license"
done

# start the minio service on all nodes
for i in {1..4}; do
    limactl shell minio-node${i} bash -c "sudo systemctl restart minio"
done
