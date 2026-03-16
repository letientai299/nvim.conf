ARG BASE_IMAGE=rockylinux:9
FROM ${BASE_IMAGE}

# --allowerasing: Rocky 9 ships curl-minimal which conflicts with full curl
RUN dnf install -y --allowerasing git curl bash libatomic libicu \
    && dnf clean all

ARG UID=1000
ARG GID=1000
RUN getent group "$GID" >/dev/null || groupadd -g "$GID" testuser \
    && useradd -m -u "$UID" -g "$GID" -s /bin/bash testuser

USER testuser
WORKDIR /home/testuser
COPY bashrc.sh /tmp/bashrc.sh
RUN cat /tmp/bashrc.sh >> ~/.bashrc
