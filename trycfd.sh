#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./trycfd.sh <creds.json> [port] [path-to-cloudflared]
#
# Examples:
#   ./trycfd.sh one.json                 # one.json, port 8080, cloudflared from PATH
#   ./trycfd.sh one.json 8043            # one.json, port 8043
#   ./trycfd.sh one.json 8043 /tmp/cloudflared

show_help() {
    cat <<EOF
Usage:
  ./trycfd.sh <creds.json> [port] [path-to-cloudflared]

Examples:
  ./trycfd.sh one.json                 # one.json, port 8080, cloudflared from PATH
  ./trycfd.sh one.json 8043            # one.json, port 8043
  ./trycfd.sh one.json 8043 /tmp/cloudflared
EOF
}

if [ $# -eq 0 ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    show_help
    exit 0
fi

CREDS_FILE="$1"
PORT="${2:-8080}"
CLOUDFLARED_BIN="${3:-cloudflared}"

ORIGIN_URL="${ORIGIN_URL:-http://localhost:${PORT}}"
API="https://api.trycloudflare.com/tunnel"

# Basic port validation
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    echo "[!] invalid port: $PORT" >&2
    show_help >&2
    exit 1
fi

# Validate the cloudflared binary is available and executable
if ! command -v "$CLOUDFLARED_BIN" >/dev/null 2>&1; then
    if [ -x "$CLOUDFLARED_BIN" ]; then
        : # direct path to an executable binary, fine
    else
        echo "[!] cloudflared not found / not executable: $CLOUDFLARED_BIN" >&2
        exit 1
    fi
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "[!] jq is required but was not found" >&2
    exit 1
fi

if [ ! -f "$CREDS_FILE" ]; then
    echo "[*] no creds file found, provisioning a new quick tunnel..."
    resp="$(curl -fsS -X POST "$API" \
        -H "Content-Type: application/json" \
        -H "User-Agent: cloudflared-script" \
        -d '')"

    echo "$resp" | jq -e '.success == true' >/dev/null || {
        echo "[!] provisioning failed: $resp" >&2
        exit 1
    }

    echo "$resp" | jq '.result | {
        Hostname:     .hostname,
        AccountTag:   .account_tag,
        TunnelID:     .id,
        TunnelSecret: .secret
    }' > "$CREDS_FILE"
    chmod 600 "$CREDS_FILE"

    hostname="$(jq -r '.Hostname' "$CREDS_FILE")"
    echo "[+] tunnel created: https://$hostname"
    echo "[+] credentials saved to $CREDS_FILE"
else
    echo "[*] reusing credentials from $CREDS_FILE"
    echo "[*] hostname: $(jq -r '.Hostname' "$CREDS_FILE")"
fi

TUNNEL_ID="$(jq -r '.TunnelID' "$CREDS_FILE")"
echo "[*] running tunnel $TUNNEL_ID -> $ORIGIN_URL (binary: $CLOUDFLARED_BIN)"

exec "$CLOUDFLARED_BIN" tunnel run \
    --credentials-file "$CREDS_FILE" \
    --url "$ORIGIN_URL" \
    "$TUNNEL_ID"