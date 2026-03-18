# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Stack

Self-hosted media server using Docker Compose. Services:

| Service | Role | Port |
|---|---|---|
| Jellyfin | Media playback | 8096 |
| Prowlarr | Indexer manager | 9696 |
| Radarr | Movie automation | 7878 |
| Sonarr | TV automation | 8989 |
| Lidarr | Music automation | 8686 |
| Readarr | Books automation | 8787 |
| Gluetun | VPN gateway (qBittorrent sidecar) | — |
| qBittorrent | Torrent client (VPN-isolated) | 8081 |
| SABnzbd | Usenet downloader | 8080 |
| Jellyseerr | Media request portal | 5055 |

## Commands

```bash
docker compose up -d          # Start all services
docker compose down           # Stop all services
docker compose pull           # Update all images
docker compose logs -f <svc>  # Follow logs for a service
docker compose restart <svc>  # Restart a single service
```

Verify qBittorrent is routing through the VPN:
```bash
docker compose exec qbittorrent curl -s ifconfig.me
```

## Architecture

### VPN Isolation
`qbittorrent` uses `network_mode: "service:gluetun"` — all its traffic goes through Gluetun's WireGuard/OpenVPN tunnel. All ports for qBittorrent (8081, 6881) are declared on the `gluetun` service, not on qBittorrent directly. SABnzbd and all *arr services use the normal `media_network`.

### Volume Layout
All services that move files mount `./media` as `/data`. This keeps downloads and the organized library on the same filesystem, enabling hardlinks (no file copying). Configure each *arr app with:
- Torrent download path: `/data/downloads/torrents/<type>/`
- Usenet download path: `/data/downloads/usenet/<type>/`
- Library path: `/data/<type>/`

### Traefik Integration
Traefik is managed in a separate repo. All services route through Traefik — no host port bindings except qBittorrent's torrent peer port (6881). Prerequisites:
1. Run `docker network create traefik_proxy`
2. Ensure `LOCAL_WHITELIST` is set in the Traefik stack's `.env` (WireGuard/LAN CIDRs)
3. Set `DOMAIN=yourdomain.com` in `.env`

Access tiers:
- **Public** (own auth): `jellyfin.DOMAIN`, `jellyseerr.DOMAIN`
- **IP-whitelisted** (WireGuard/LAN only): all *arr services, qBittorrent, SABnzbd
- **Internal only** (no Traefik route): FlareSolverr

### Linux / Hardware Transcoding
On Linux, add device passthrough to the `jellyfin` service for hardware transcoding:
- Intel QuickSync: `devices: [/dev/dri:/dev/dri]`
- NVIDIA: `runtime: nvidia` + `NVIDIA_VISIBLE_DEVICES=all`

## Inter-Service Connections

When connecting services to each other, use Docker service names as hostnames (they resolve on `media_network`):

| From | To | URL |
|---|---|---|
| Radarr/Sonarr/etc. | Prowlarr | `http://prowlarr:9696` |
| Radarr/Sonarr/etc. | qBittorrent | `http://gluetun:8081` |
| Radarr/Sonarr/etc. | SABnzbd | `http://sabnzbd:8080` |
| Jellyseerr | Jellyfin | `http://jellyfin:8096` |

Note: qBittorrent is reached via `gluetun` (not `qbittorrent`) because it shares Gluetun's network namespace.

## Configuration Files
- `.env` — secrets and local config (gitignored, copy from `.env.example`)
- `config/<service>/` — runtime config for each app (gitignored, created on first run)
- `media/` — all media and downloads (gitignored)
