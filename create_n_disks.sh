#!/bin/bash
if [ $# -ne 2 ]; then
    echo "Usage: $0 <number of disks> <size>"
    exit 1
fi
N_DISKS=$1
SIZE=$2
for i in $(seq 1 $N_DISKS); do limactl disk create "minio${i}" --size $SIZE; done
