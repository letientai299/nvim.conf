FROM lopsided/archlinux:latest

RUN pacman -Syu --noconfirm git curl bash \
    && pacman -Scc --noconfirm

ARG UID=1000
ARG GID=1000
RUN getent group "$GID" >/dev/null || groupadd -g "$GID" testuser \
    && useradd -m -u "$UID" -g "$GID" -s /bin/bash testuser

USER testuser
WORKDIR /home/testuser
COPY ps1.sh /tmp/ps1.sh
RUN cat /tmp/ps1.sh >> ~/.bashrc
