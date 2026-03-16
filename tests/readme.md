# Test containers

Manual test environments for the nvim config across Linux distros. Each
Dockerfile builds a minimal image with a non-root user. The project is mounted
read-only at `~/work`.

## Quick start

```bash
./tests/run.sh ub        # pick ubuntu, build, drop into shell
./tests/run.sh -b fedora # boot: install, source bashrc, open nvim
```

Inside the container, `install` runs the install script and `se` re-sources
`.bashrc`. See `run.sh -h` for all flags.

## Cloud images and glibc

The cloud-specific images simulate base images used in managed K8s services
([EKS][eks], [AKS][aks], GKE). [tree-sitter][ts] v0.26+ ships prebuilt binaries
that require glibc 2.39+. The native images from Amazon and Azure are stuck on
older glibc and have no newer major versions on the horizon:

- **Amazon Linux 2023** — glibc 2.34, locked for the AL2023 lifetime
- **Azure Linux 3.0** — glibc 2.38, no 4.0 announced

Both EKS and AKS support Ubuntu nodes, and Ubuntu 24.04 (glibc 2.39) is the
default EKS node OS from 1.33 onward. The cloud Dockerfiles use Ubuntu 24.04
from each cloud's own registry:

- `amazon-linux.Dockerfile` — `public.ecr.aws/ubuntu/ubuntu:24.04`
- `azure-linux.Dockerfile` —
  `mcr.microsoft.com/mirror/docker/library/ubuntu:24.04`
- `gcp-debian.Dockerfile` — `debian:trixie-slim` (glibc 2.41)

If Amazon Linux or Azure Linux ship a release with glibc 2.39+, switch back to
the native images.

## Caching proxy

A [mitmproxy][mitm]-based HTTPS proxy caches all responses on disk. The proxy
runs in Docker alongside the test container and is **on by default**. Cached
responses are replayed with the original latency to preserve race-condition
behavior.

Cache and CA data live in `tests/proxy/cache/` and `tests/proxy/ca/`
(gitignored). They persist across proxy restarts — the container is stateless.

Use `-x` / `--bypass` to skip the proxy and hit the network directly. Use
`--clear-cache` to wipe cached responses.

### Speed multiplier

`-s N` replays cached responses N times faster. Useful for automation tests
where latency fidelity doesn't matter.

```bash
./tests/run.sh -s4 ub # 4x faster replay
```

The proxy container restarts automatically when the speed setting changes.

### Port

The proxy listens on host port 8090 by default. Override with `PROXY_PORT`:

```bash
PROXY_PORT=9090 ./tests/run.sh ub
```

### Lifecycle

The proxy container (`nvim-test-proxy`) stays running across test runs. It is
not cleaned up automatically — stop it with `docker rm -f nvim-test-proxy` when
done.

[mitm]: https://mitmproxy.org/
[ts]: https://github.com/tree-sitter/tree-sitter
[eks]: https://aws.amazon.com/eks/
[aks]: https://azure.microsoft.com/en-us/products/kubernetes-service
