ARG BASE_IMAGE=lopsided/archlinux:latest
FROM ${BASE_IMAGE}

RUN pacman -Syu --noconfirm git curl bash icu tar \
    && pacman -Scc --noconfirm

ARG UID=1000
ARG GID=1000
RUN getent group "$GID" >/dev/null || groupadd -g "$GID" testuser \
    && useradd -m -u "$UID" -g "$GID" -s /bin/bash testuser

USER testuser
WORKDIR /home/testuser
COPY bashrc.sh /tmp/bashrc.sh
RUN cat /tmp/bashrc.sh >> ~/.bashrc
