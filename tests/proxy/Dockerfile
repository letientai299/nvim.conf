FROM mitmproxy/mitmproxy:latest
COPY addon.py /opt/addon.py
ENTRYPOINT ["mitmdump", "--set", "connection_strategy=lazy", \
            "-s", "/opt/addon.py", "--listen-port", "8080"]
