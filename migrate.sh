#!/usr/bin/env bash
# migrate.sh — Copy media server config (and optionally media) to a production server.
#
# Usage:
#   ./migrate.sh <user@host:/destination/path> [--media] [--dry-run]
#
# Examples:
#   ./migrate.sh john@192.168.1.100:/opt/media-server           # config only
#   ./migrate.sh john@192.168.1.100:/opt/media-server --media   # config + media
#   ./migrate.sh john@192.168.1.100:/opt/media-server --dry-run # preview without transferring

set -euo pipefail

# ── Parse arguments ────────────────────────────────────────
DESTINATION=""
INCLUDE_MEDIA=false
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --media)    INCLUDE_MEDIA=true ;;
    --dry-run)  DRY_RUN=true ;;
    *)          DESTINATION="$arg" ;;
  esac
done

if [[ -z "$DESTINATION" ]]; then
  echo "Usage: $0 <user@host:/destination/path> [--media] [--dry-run]"
  exit 1
fi

# ── Resolve project root ───────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Helpers ────────────────────────────────────────────────
RSYNC_OPTS=(-az --progress --human-readable)
if $DRY_RUN; then
  RSYNC_OPTS+=(--dry-run)
  echo "── DRY RUN — no files will be transferred ──"
  echo ""
fi

section() { echo ""; echo "▶ $1"; }
done_msg() { echo "  ✓ $1"; }

# ── Transfer ───────────────────────────────────────────────
section "Syncing docker-compose.yml and .env.example → $DESTINATION/"
rsync "${RSYNC_OPTS[@]}" \
  "$SCRIPT_DIR/docker-compose.yml" \
  "$SCRIPT_DIR/.env.example" \
  "$DESTINATION/"
done_msg "Compose files synced"

section "Syncing config/ → $DESTINATION/config/"
rsync "${RSYNC_OPTS[@]}" \
  "$SCRIPT_DIR/config/" \
  "$DESTINATION/config/"
done_msg "App config synced (indexers, download clients, library DB, etc.)"

if $INCLUDE_MEDIA; then
  section "Syncing media/ → $DESTINATION/media/  (this may take a while)"
  rsync "${RSYNC_OPTS[@]}" \
    "$SCRIPT_DIR/media/" \
    "$DESTINATION/media/"
  done_msg "Media synced"
else
  echo ""
  echo "ℹ  Skipped media/ — pass --media to include it."
  echo "   If media already lives on the production server, just update"
  echo "   the volume paths in docker-compose.yml instead."
fi

# ── Post-migration reminders ───────────────────────────────
echo ""
echo "────────────────────────────────────────────────────────"
echo "  Done! Before starting the stack on the production server:"
echo ""
echo "  1. Copy your .env file:"
echo "       scp .env $DESTINATION/.env"
echo ""
echo "  2. Verify PUID/PGID match the production user:"
echo "       ssh <host> 'id \$USER'"
echo ""
echo "  3. If enabling Traefik, uncomment traefik_proxy network"
echo "     and labels blocks in docker-compose.yml, then:"
echo "       docker network create traefik_proxy"
echo ""
echo "  4. For hardware transcoding on Linux, add /dev/dri"
echo "     device passthrough to the jellyfin service."
echo ""
echo "  5. Start the stack:"
echo "       docker compose up -d"
echo "────────────────────────────────────────────────────────"
