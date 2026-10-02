#!/bin/sh
set -eu
umask 077

# Usage:
#   ./trycfd.sh <creds.json> [port] [path-to-cloudflared]
#
# Examples:
#   ./trycfd.sh one.json                 # one.json, port 8080, cloudflared from PATH
#   ./trycfd.sh one.json 8043            # one.json, port 8043
#   ./trycfd.sh one.json 8043 /tmp/cloudflared

show_help() {
    cat <<'EOF'
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
case "$PORT" in
    ???????* | "" | *[!0-9]* | 0*)
        echo "[!] invalid port: $PORT" >&2
        show_help >&2
        exit 1
        ;;
esac

if [ "$PORT" -gt 65535 ]; then
    echo "[!] invalid port: $PORT" >&2
    show_help >&2
    exit 1
fi

# Validate the cloudflared binary is available and executable
if ! command -v "$CLOUDFLARED_BIN" >/dev/null 2>&1; then
    echo "[!] cloudflared not found: $CLOUDFLARED_BIN" >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "[!] jq is required but was not found" >&2
    exit 1
fi

if [ ! -f "$CREDS_FILE" ]; then
    echo "[*] no creds file found, provisioning a new quick tunnel..."
    if ! resp="$(curl -fsS -X POST "$API" \
        -H "Content-Type: application/json" \
        -H "User-Agent: cloudflared-script" \
        -d '{}')"; then
        echo "[!] failed to reach provisioning API" >&2
        exit 1
    fi

    if ! printf '%s\n' "$resp" | jq -e '
        .success == true and
        (.result.id     | type == "string" and length > 0) and
        (.result.secret | type == "string" and length > 0)
    ' >/dev/null 2>&1; then
        echo "[!] provisioning failed or returned incomplete data" >&2
        exit 1
    fi

    if ! printf '%s\n' "$resp" | jq '.result | {
        Hostname:     .hostname,
        AccountTag:   .account_tag,
        TunnelID:     .id,
        TunnelSecret: .secret
    }' > "$CREDS_FILE"; then
        echo "[!] failed to write credentials" >&2
        rm -f "$CREDS_FILE"
        exit 1
    fi

    chmod 600 "$CREDS_FILE" || {
        echo "[!] failed to secure credentials file" >&2
        rm -f "$CREDS_FILE"
        exit 1
    }

    echo "[+] credentials saved to $CREDS_FILE"
else
    echo "[*] reusing credentials from $CREDS_FILE"
fi

# `|| TUNNEL_ID=""` / `|| hostname=""` are required, not cosmetic.
# Under `set -e`, if jq fails to PARSE the file (malformed JSON --
# e.g. a truncated copy from another VPS), the shell exits right on
# this line and never reaches the `[ -z ... ]` check below, so the
# friendly error message would never print. The fallback keeps the
# assignment itself "successful" so the explicit check can run.
TUNNEL_ID="$(jq -r '.TunnelID // empty' "$CREDS_FILE" 2>/dev/null)" || TUNNEL_ID=""
if [ -z "$TUNNEL_ID" ]; then
    echo "[!] invalid credentials file: missing or unparsable TunnelID in $CREDS_FILE" >&2
    exit 1
fi

hostname="$(jq -r '.Hostname // empty' "$CREDS_FILE" 2>/dev/null)" || hostname=""
if [ -n "$hostname" ]; then
    echo "[*] hostname: https://$hostname"
fi

echo "[*] running tunnel $TUNNEL_ID -> $ORIGIN_URL (binary: $CLOUDFLARED_BIN)"

exec "$CLOUDFLARED_BIN" tunnel run \
    --credentials-file "$CREDS_FILE" \
    --url "$ORIGIN_URL" \
    "$TUNNEL_ID"