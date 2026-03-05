# Recommended Plugins

## Jellyfin

### Trakt

Scrobbles your watch history to [Trakt.tv](https://trakt.tv) automatically and enables personalized recommendations as your history grows.

**Installation**

1. Go to Jellyfin → Dashboard → Plugins → Catalog
2. Search for "Trakt" and install it
3. Restart Jellyfin

**Authorization**

1. After restart, go to Dashboard → Plugins → Trakt
2. Click "Authorize" — you'll receive a code to enter at `trakt.tv/activate`
3. Log in to your Trakt account and enter the code

**Configuration**

- Set scrobble threshold (80–90% watched is typical for marking an item complete)
- Enable "Scrobble" to automatically sync watches going forward
- Enable "Pull Watch History" to import existing Trakt history into Jellyfin

No changes to `docker-compose.yml` or `.env` are required — the plugin runs entirely inside Jellyfin.
