ARG BASE_IMAGE=menci/archlinuxarm:base
FROM ${BASE_IMAGE}

# Disable CheckSpace — BuildKit's read-only mounts (/etc/resolv.conf, /etc/hosts)
# cause pacman to wrongly report "not enough free disk space".
RUN sed -i 's/^CheckSpace/#CheckSpace/' /etc/pacman.conf \
    && pacman -Syu --noconfirm git curl bash icu tar \
    && pacman -Scc --noconfirm

ARG UID=1000
ARG GID=1000
RUN getent group "$GID" >/dev/null || groupadd -g "$GID" testuser \
    && useradd -m -u "$UID" -g "$GID" -s /bin/bash testuser

USER testuser
WORKDIR /home/testuser
COPY bashrc.sh /tmp/bashrc.sh
RUN cat /tmp/bashrc.sh >> ~/.bashrc
