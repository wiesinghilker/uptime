#!/bin/sh
set -e

# Fix ownership of /app/data volume
# This runs as root, then switches to uptime-kuma user
if [ "$(id -u)" = "0" ]; then
    # Running as root, fix permissions
    chown -R 3001:3001 /app/data
    chmod -R 755 /app/data

    # Switch to uptime-kuma user and execute the command
    exec su-exec 3001:3001 "$@"
else
    # Already running as uptime-kuma user
    exec "$@"
fi