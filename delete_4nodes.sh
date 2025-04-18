#!/bin/bash
for i in {1..4}; do
    limactl stop minio-node${i}
done

for i in {1..4}; do
    limactl rm minio-node${i}
done
