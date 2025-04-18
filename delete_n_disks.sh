#!/bin/bash
if [ $# -ne 1 ]; then
    echo "Usage: $0 <number of disks>"
    exit 1
fi
N_DISKS=$1
for i in $(seq 1 $N_DISKS); do limactl disk delete "minio${i}"; done
