FROM mcr.microsoft.com/azurelinux/base/core:3.0

RUN tdnf install -y git curl bash ca-certificates shadow-utils libatomic \
    && tdnf clean all

ARG UID=1000
ARG GID=1000
RUN getent group "$GID" >/dev/null || groupadd -g "$GID" testuser \
    && useradd -m -u "$UID" -g "$GID" -s /bin/bash testuser

USER testuser
WORKDIR /home/testuser
COPY ps1.sh /tmp/ps1.sh
RUN cat /tmp/ps1.sh >> ~/.bashrc
