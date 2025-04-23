# Project notes

**2025-04-22** Lessons learned:

- Run `sudo chown -R minio-user:minio-user /mnt/lima-minio{1..4} && sudo chmod u+rwx /mnt/lima-minio{1..4}` in all nodes
- Delete `.minio.sys` from all volumes on all nodes after testing a config (need a script or Ansible playbook for that)

