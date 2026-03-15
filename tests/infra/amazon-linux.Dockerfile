ARG BASE_IMAGE=amazonlinux:2023
FROM ${BASE_IMAGE}

RUN dnf install -y git bash libatomic libicu \
    && (command -v curl || dnf install -y --allowerasing curl) \
    && dnf clean all

ARG UID=1000
ARG GID=1000
RUN getent group "$GID" >/dev/null || groupadd -g "$GID" testuser \
    && useradd -m -u "$UID" -g "$GID" -s /bin/bash testuser

USER testuser
WORKDIR /home/testuser
COPY bashrc.sh /tmp/bashrc.sh
RUN cat /tmp/bashrc.sh >> ~/.bashrc
