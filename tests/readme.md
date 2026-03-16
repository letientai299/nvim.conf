# Test containers

Manual test environments for the nvim config across Linux distros. Each
Dockerfile builds a minimal image with a non-root user. The project is mounted
read-only at `~/work`.

## Quick start

```bash
./tests/run.sh ub          # pick ubuntu, build, drop into shell
./tests/run.sh -b fedora   # boot: install, source bashrc, open nvim
```

Inside the container, `install` runs the install script and `se` re-sources
`.bashrc`. See `run.sh -h` for all flags.

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
./tests/run.sh -s4 ub      # 4x faster replay
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
