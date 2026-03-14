FROM alpine:3.21

RUN apk add --no-cache git curl bash shadow neovim libatomic

ARG UID=1000
ARG GID=1000
RUN getent group "$GID" >/dev/null || groupadd -g "$GID" testuser \
    && useradd -m -u "$UID" -g "$GID" -s /bin/bash testuser

USER testuser
WORKDIR /home/testuser
COPY ps1.sh /tmp/ps1.sh
RUN cat /tmp/ps1.sh >> ~/.bashrc \
    && printf '[ -f ~/.bashrc ] && . ~/.bashrc\n' >> ~/.profile
