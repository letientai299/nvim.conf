ARG BASE_IMAGE=alpine:edge
FROM ${BASE_IMAGE}

RUN apk add --no-cache git curl bash shadow neovim libatomic icu-libs \
      build-base tree-sitter-cli

ARG UID=1000
ARG GID=1000
RUN getent group "$GID" >/dev/null || groupadd -g "$GID" testuser \
    && useradd -m -u "$UID" -g "$GID" -s /bin/bash testuser

USER testuser
WORKDIR /home/testuser
COPY bashrc.sh /tmp/bashrc.sh
RUN cat /tmp/bashrc.sh >> ~/.bashrc \
    && printf '[ -f ~/.bashrc ] && . ~/.bashrc\n' >> ~/.profile
