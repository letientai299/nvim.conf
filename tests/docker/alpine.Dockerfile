FROM alpine:latest
# neovim: mise only provides glibc builds; Alpine (musl) needs the system package
RUN apk add --no-cache curl bash git neovim
RUN adduser -D testuser
USER testuser
WORKDIR /home/testuser
