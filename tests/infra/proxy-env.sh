# shellcheck shell=bash
# Sourced from bashrc when proxy CA cert is mounted at /tmp/proxy-ca.pem.
# Builds a combined CA bundle (system CAs + proxy CA) so HTTPS through the
# caching proxy works without root.

[ -f /tmp/proxy-ca.pem ] || return 0

for sys_ca in /etc/ssl/certs/ca-certificates.crt \
              /etc/pki/tls/certs/ca-bundle.crt; do
  if [ -f "$sys_ca" ]; then
    cat "$sys_ca" /tmp/proxy-ca.pem > /tmp/ca-bundle.pem
    break
  fi
done

export SSL_CERT_FILE=/tmp/ca-bundle.pem
export GIT_SSL_CAINFO=/tmp/ca-bundle.pem
export CURL_CA_BUNDLE=/tmp/ca-bundle.pem
export NODE_EXTRA_CA_CERTS=/tmp/proxy-ca.pem
export HTTPS_PROXY=http://host.docker.internal:8080
export HTTP_PROXY=http://host.docker.internal:8080
export NO_PROXY=localhost,127.0.0.1
