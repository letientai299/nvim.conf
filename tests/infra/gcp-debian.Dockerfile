ARG BASE_IMAGE=debian:12-slim
FROM ${BASE_IMAGE}

RUN apt-get update && apt-get install -y --no-install-recommends \
      git curl ca-certificates bash libatomic1 libicu-dev \
    && rm -rf /var/lib/apt/lists/*

ARG UID=1000
ARG GID=1000
RUN getent group "$GID" >/dev/null || groupadd -g "$GID" testuser \
    && useradd -m -u "$UID" -g "$GID" -s /bin/bash testuser

USER testuser
WORKDIR /home/testuser
COPY bashrc.sh /tmp/bashrc.sh
RUN cat /tmp/bashrc.sh >> ~/.bashrc
