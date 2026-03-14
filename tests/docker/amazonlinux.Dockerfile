FROM amazonlinux:latest
# tar: required by mise's install script to extract binaries
# curl-minimal is pre-installed; installing curl would conflict
RUN yum install -y bash git tar gzip && yum clean all
RUN useradd -m testuser
USER testuser
WORKDIR /home/testuser
