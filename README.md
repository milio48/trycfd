# trycfd

> Persistent trycloudflare

Keep your Cloudflare quick tunnel hostname persistent across restarts by reusing tunnel credentials.

## Installation

Using **curl**:
```bash
curl -fsSL https://raw.githubusercontent.com/milio48/trycfd/main/trycfd.sh -o trycfd.sh && chmod +x trycfd.sh
```

Using **wget**:
```bash
wget -qO trycfd.sh https://raw.githubusercontent.com/milio48/trycfd/main/trycfd.sh && chmod +x trycfd.sh
```

## Requirements

- `curl`
- `jq`
- `cloudflared`

## Usage

```bash
./trycfd.sh <creds.json> [port] [path-to-cloudflared]
```

### Examples

```bash
./trycfd.sh one.json                 # one.json, port 8080, cloudflared from PATH
./trycfd.sh one.json 8043            # one.json, port 8043
./trycfd.sh one.json 8043 /tmp/cloudflared
```

### Environment Variables

- `ORIGIN_URL`: Override default origin (default: `http://localhost:<port>`).

## How It Works

- **Auto-provisioning**: If the specified credentials file does not exist, the script automatically provisions a new tunnel and saves the credentials into that JSON file.
- **Persistent Subdomain**: Reusing the same JSON file keeps your assigned `*.trycloudflare.com` subdomain persistent across restarts.
- **Portable**: You can copy this JSON file to another machine or server to host the exact same subdomain there.

## Disclaimer

This project is an unofficial, independent tool created strictly for educational and research purposes. It is not affiliated with, sponsored by, or endorsed by Cloudflare, Inc.

The method used may conflict with Cloudflare's Terms of Service. This software is provided "as is", without warranty of any kind. The author assumes no legal liability or responsibility for any account restrictions, service disruptions, or consequences resulting from its use. Users assume full responsibility for their own actions and compliance with all applicable terms and laws.
