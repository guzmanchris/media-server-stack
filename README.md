# Media Server

Self-hosted media server stack built with Docker Compose. Includes automated downloading, library management, and media playback — with torrent traffic isolated behind a VPN.

## Services

| Service | Role | Local URL |
|---|---|---|
| [Jellyfin](https://jellyfin.org) | Media playback | http://localhost:8096 |
| [Jellyseerr](https://github.com/fallenbagel/jellyseerr) | Media request portal | http://localhost:5055 |
| [Prowlarr](https://prowlarr.com) | Indexer manager | http://localhost:9696 |
| [Radarr](https://radarr.video) | Movie automation | http://localhost:7878 |
| [Sonarr](https://sonarr.tv) | TV automation | http://localhost:8989 |
| [Lidarr](https://lidarr.audio) | Music automation | http://localhost:8686 |
| [Readarr](https://readarr.com) | Books automation | http://localhost:8787 |
| [qBittorrent](https://www.qbittorrent.org) | Torrent client (VPN) | http://localhost:8081 |
| [SABnzbd](https://sabnzbd.org) | Usenet downloader | http://localhost:8080 |
| [FlareSolverr](https://github.com/FlareSolverr/FlareSolverr) | CloudFlare bypass proxy (used by Prowlarr) | — |
| [Gluetun](https://github.com/qdm12/gluetun) | VPN gateway (NordVPN, Linux only) | — |

## Architecture

### VPN Isolation
qBittorrent runs inside Gluetun's network namespace (`network_mode: service:gluetun`). All torrent traffic is routed through NordVPN via OpenVPN UDP. SABnzbd and all \*arr services use the normal network — no VPN overhead.

### Hardlink-Compatible Storage
All services that handle files mount `./media` as `/data`. Downloads and the organized library share the same filesystem, so the \*arr apps can use hardlinks instead of copying files.

```
media/
├── movies/        ← Radarr library
├── tv/            ← Sonarr library
├── music/         ← Lidarr library
├── books/         ← Readarr library
└── downloads/
    ├── torrents/  ← qBittorrent (movies/ tv/ music/ books/)
    └── usenet/    ← SABnzbd     (movies/ tv/ music/ books/)
```

### Traefik (Optional)
Traefik is managed in a separate repo. Each service has Traefik labels pre-written but commented out. See [Enabling Traefik](#enabling-traefik) below.

---

## Setup

### Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (macOS / Windows) or Docker Engine + Compose plugin (Linux)
- A [NordVPN](https://nordvpn.com) subscription with OpenVPN service credentials

### 1. Configure environment

```bash
cp .env.example .env
```

Edit `.env` and fill in:

| Variable | Description |
|---|---|
| `PUID` / `PGID` | Your user/group ID. On Linux run `id $USER` to find them. |
| `TZ` | Your timezone (e.g. `America/Puerto_Rico`) |
| `OPENVPN_USER` | NordVPN service username — **not** your account email |
| `OPENVPN_PASSWORD` | NordVPN service password |
| `DOMAIN` | Your domain (only needed when Traefik is enabled) |

> **NordVPN service credentials:** Log in at nordvpn.com → My Account → Services → NordVPN → Manual Setup → OpenVPN

### 2. Start the stack

```bash
docker compose up -d
```

### 3. Wire up services

Once all UIs are accessible, connect the services to each other using their Docker hostnames:

**Prowlarr** (`http://localhost:9696`)
- Add your indexers under *Indexers*
- Under *Settings → Apps*, add Radarr, Sonarr, Lidarr, and Readarr to sync indexers automatically

**Radarr / Sonarr / Lidarr / Readarr**
- *Settings → Download Clients* → Add qBittorrent: `http://qbittorrent:8081`
- *Settings → Download Clients* → Add SABnzbd: `http://sabnzbd:8080`
- Set root folder paths to `/data/movies`, `/data/tv`, `/data/music`, `/data/books`

**Prowlarr** — CloudFlare-protected indexers
- *Settings → Indexers → Proxies → Add* → FlareSolverr: `http://flaresolverr:8191`
- Assign the FlareSolverr tag to any indexer that returns a CloudFlare error

**Jellyseerr** (`http://localhost:5055`)
- Sign in with Jellyfin, connect to Jellyfin at `http://jellyfin:8096`
- Add Radarr and Sonarr under *Settings → Radarr / Sonarr*

### 4. Verify VPN is working (production Linux only)

```bash
docker compose exec qbittorrent curl -s ifconfig.me
```

The returned IP should be a NordVPN server address, not your home IP. See [Migrating to Production](#migrating-to-production) for VPN setup.

---

## Common Commands

```bash
docker compose up -d           # Start all services
docker compose down            # Stop all services
docker compose pull            # Pull latest images
docker compose restart <svc>   # Restart a single service
docker compose logs -f <svc>   # Follow logs for a service
```

---

## Enabling Traefik

When your Traefik stack is running:

1. Create the shared network (once):
   ```bash
   docker network create traefik_proxy
   ```

2. In `docker-compose.yml`, uncomment for each service:
   - `# - traefik_proxy` under `networks:`
   - The `# labels:` block and its contents
   - The `traefik_proxy` network declaration at the bottom of the file

3. Set `DOMAIN=yourdomain.com` in `.env`

4. Restart the stack:
   ```bash
   docker compose up -d
   ```

---

## Migrating to Production

All service state (indexers, download client connections, library databases) is stored in `./config/`. Use the included migration script to transfer everything to a production server:

```bash
# Config only
./migrate.sh user@host:/opt/media-server

# Config + media files
./migrate.sh user@host:/opt/media-server --media

# Preview without transferring
./migrate.sh user@host:/opt/media-server --dry-run
```

After migrating, check these settings on the production server:
- **`PUID`/`PGID`** — run `id $USER` to confirm they match
- **Hardware transcoding** — add `/dev/dri` device passthrough to the `jellyfin` service for Intel QuickSync, or configure the NVIDIA runtime for GPU transcoding
- **Traefik** — follow [Enabling Traefik](#enabling-traefik) once the network exists
