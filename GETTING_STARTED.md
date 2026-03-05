# Getting Started

Complete setup guide for the media server stack. Follow the steps in order.

---

## Step 1 — Usenet Subscriptions

You need two separate services before configuring SABnzbd.

### Usenet Provider
Stores the actual content. SABnzbd connects to this. Pick one:

| Provider | Price | Notes |
|---|---|---|
| [Newshosting](https://www.newshosting.com) | ~$10/mo | Fast, high completion rate, good retention |
| [Eweka](https://www.eweka.nl) | ~$8/mo | European servers, excellent retention |
| [Frugal Usenet](https://www.frugalusenet.com) | ~$4/mo | Budget option, solid |
| [UsenetExpress](https://usenetexpress.com) | ~$7/mo | Good performance |

Save your **hostname, port, username, and password** — you'll enter these in SABnzbd.

### Usenet Indexers
Search engines for Usenet content. These plug into Prowlarr. Use at least one paid + one free:

| Indexer | Cost | Notes |
|---|---|---|
| [NZBGeek](https://nzbgeek.info) | ~$12/year | Most popular, excellent catalog |
| [NZBFinder](https://nzbfinder.ws) | Free (10/day) or $10/year | Good free tier to start |
| [Althub](https://althub.co.za) | Free (register) | Decent free option |
| [NZBIndex](https://nzbindex.com) | Free | Basic, no registration needed |

Register at each site and save your **API keys**.

---

## Step 2 — SABnzbd

Go to http://localhost:8080

1. Complete the setup wizard
2. Add your Usenet provider: *Config → Servers → Add Server*
   - Host, port `563` (SSL), username, password
   - Enable SSL
3. Add categories under *Config → Categories*:

| Category | Folder |
|---|---|
| `movies` | `/data/downloads/usenet/movies` |
| `tv` | `/data/downloads/usenet/tv` |
| `music` | `/data/downloads/usenet/music` |
| `books` | `/data/downloads/usenet/books` |

---

## Step 3 — qBittorrent

Go to http://localhost:8081

Newer qBittorrent versions generate a temporary password on each startup. Find it with:
```bash
docker compose logs qbittorrent | grep "temporary password"
```
Username is always `admin`. Set a permanent password immediately after logging in: *Tools → Options → Web UI → Password*.

Add categories from the **main window** (not Options):
- In the left sidebar, right-click **"All"** → **"Add category..."**
- Add one entry for each type:

| Category | Save Path |
|---|---|
| `movies` | `/data/downloads/torrents/movies` |
| `tv` | `/data/downloads/torrents/tv` |
| `music` | `/data/downloads/torrents/music` |
| `books` | `/data/downloads/torrents/books` |

---

## Step 4 — Prowlarr

Go to http://localhost:9696

### Configure FlareSolverr (CloudFlare bypass)
Many public torrent indexers are protected by CloudFlare. FlareSolverr is already running in the stack — wire it up before adding indexers:

1. *Settings → Indexers → "+" next to Proxies* → select **FlareSolverr**
2. Set **Host** to `http://flaresolverr:8191`
3. Add a **Tag** (e.g. `flaresolverr`) and save

When adding any indexer that fails with a CloudFlare error, assign this tag to it.

### Add Indexers
*Indexers → Add Indexer* — search for and add:
- **NZBGeek** — paste your API key
- **NZBFinder** — paste your API key
- **Althub** / **NZBIndex** — free, no key needed
- Public torrent indexers (1337x, YTS, EZTV, etc.) — assign the `flaresolverr` tag if you get a CloudFlare error

### Sync to *arr Apps
*Settings → Apps* — add each app so Prowlarr pushes indexers to them automatically.
API keys are found in each app under *Settings → General*.

| App | URL | Port |
|---|---|---|
| Radarr | `http://radarr` | `7878` |
| Sonarr | `http://sonarr` | `8989` |
| Lidarr | `http://lidarr` | `8686` |
| Readarr | `http://readarr` | `8787` |

---

## Step 5 — Radarr / Sonarr / Lidarr / Readarr

Repeat the following for each app.

### Add Download Clients
*Settings → Download Clients → Add*:

| Client | Host | Port | Extra |
|---|---|---|---|
| qBittorrent | `qbittorrent` | `8081` | — |
| SABnzbd | `sabnzbd` | `8080` | API key from SABnzbd *Config → General* |

### Set Root Folders
*Settings → Media Management → Root Folders → Add*:

| App | Root Folder |
|---|---|
| Radarr | `/data/movies` |
| Sonarr | `/data/tv` |
| Lidarr | `/data/music` |
| Readarr | `/data/books` |

### Enable Hardlinks
*Settings → Media Management → Use Hardlinks instead of Copy* → **On**

This avoids duplicating files on disk when the *arr app moves a download into the library.

---

## Step 6 — Jellyfin

Go to http://localhost:8096

Complete the setup wizard, then add a library for each media type:
*Dashboard → Libraries → Add Media Library*

| Library Type | Folder |
|---|---|
| Movies | `/data/movies` |
| TV Shows | `/data/tv` |
| Music | `/data/music` |
| Books | `/data/books` |

---

## Step 7 — Jellyseerr

Go to http://localhost:5055

1. Sign in with your Jellyfin admin account
2. Connect Jellyfin: `http://jellyfin:8096`
3. Add Radarr: `http://radarr:7878` + API key — set default root folder and quality profile
4. Add Sonarr: `http://sonarr:8989` + API key — set default root folder and quality profile

Once connected, users can search for any movie or TV show in Jellyseerr. It sends the request to Radarr/Sonarr → Prowlarr finds it → SABnzbd or qBittorrent downloads it → the file lands in your Jellyfin library automatically.

---

## Quick Reference — Service URLs

| Service | URL | Default Login |
|---|---|---|
| Jellyfin | http://localhost:8096 | Set during wizard |
| Jellyseerr | http://localhost:5055 | Jellyfin account |
| Prowlarr | http://localhost:9696 | None |
| Radarr | http://localhost:7878 | None |
| Sonarr | http://localhost:8989 | None |
| Lidarr | http://localhost:8686 | None |
| Readarr | http://localhost:8787 | None |
| qBittorrent | http://localhost:8081 | `admin` / `adminadmin` |
| SABnzbd | http://localhost:8080 | Set during wizard |

---

## Enabling VPN for qBittorrent (Production Linux Only)

Gluetun requires `iptables` which is not available in Docker Desktop on macOS. When deploying to Linux:

1. Uncomment the `gluetun` service block in `docker-compose.yml`
2. Remove `ports`, `networks`, and the `# - traefik_proxy` comment from `qbittorrent`
3. Replace them with:
   ```yaml
   network_mode: "service:gluetun"
   depends_on:
     - gluetun
   ```
4. Restart: `docker compose up -d`
5. Verify: `docker compose exec qbittorrent curl -s ifconfig.me` — should return a NordVPN IP
