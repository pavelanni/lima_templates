FROM ubuntu:24.04

RUN apt-get update
RUN apt-get install -y curl

RUN groupadd -r -g 1001 minio-user
RUN useradd -r -u 1001 -g minio-user -d /opt/minio -s /sbin/nologin -c "MinIO User" minio-user
RUN curl -o /usr/local/bin/minio https://dl.min.io/aistor/minio/release/linux-arm64/minio
RUN chmod +x /usr/local/bin/minio

RUN curl -o /usr/local/bin/mc https://dl.min.io/aistor/mc/release/linux-arm64/mc
RUN chmod +x /usr/local/bin/mc

RUN mkdir -p /mnt/minio
RUN chown -R minio-user:minio-user /mnt/minio

VOLUME /mnt/minio

RUN mkdir -p /etc/minio
RUN chown minio-user:minio-user /etc/minio

USER minio-user

CMD ["sh", "-c", "/usr/local/bin/minio server /mnt/minio $MINIO_OPTS"]