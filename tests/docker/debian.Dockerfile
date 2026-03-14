FROM debian:latest
# ca-certificates: required for curl HTTPS (mise install, GitHub clone)
RUN apt-get update && apt-get install -y --no-install-recommends curl bash git ca-certificates && rm -rf /var/lib/apt/lists/*
RUN useradd -m testuser
USER testuser
WORKDIR /home/testuser
