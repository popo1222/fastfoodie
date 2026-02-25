#!/bin/bash
# ─── FastFoodie Update Watcher ────────────────────────────
# Runs via cron every 30 seconds. Checks for trigger file
# written by the API when admin requests an update.

INSTALL_DIR="/opt/fastfoodie"
TRIGGER_FILE="${INSTALL_DIR}/triggers/update"
LOG_FILE="${INSTALL_DIR}/triggers/update.log"
REGISTRY="ghcr.io/popo1222"

# Exit if no trigger file
if [ ! -f "$TRIGGER_FILE" ]; then
  exit 0
fi

# Read requested version
VERSION=$(cat "$TRIGGER_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('version',''))" 2>/dev/null)

if [ -z "$VERSION" ]; then
  echo "$(date): Invalid trigger file" >> "$LOG_FILE"
  rm -f "$TRIGGER_FILE"
  exit 1
fi

echo "$(date): Update triggered to v${VERSION}" >> "$LOG_FILE"

# Remove trigger immediately to prevent re-runs
rm -f "$TRIGGER_FILE"

cd "$INSTALL_DIR"

# Write status file so API knows update is in progress
echo "{\"status\":\"updating\",\"version\":\"${VERSION}\",\"startedAt\":\"$(date -Iseconds)\"}" > "${INSTALL_DIR}/triggers/status"

# Update image tags in docker-compose.yml to the specific version
sed -i "s|${REGISTRY}/fastfoodie-api:.*|${REGISTRY}/fastfoodie-api:${VERSION}|" docker-compose.yml
sed -i "s|${REGISTRY}/fastfoodie-admin:.*|${REGISTRY}/fastfoodie-admin:${VERSION}|" docker-compose.yml
sed -i "s|${REGISTRY}/fastfoodie-webapp:.*|${REGISTRY}/fastfoodie-webapp:${VERSION}|" docker-compose.yml

echo "$(date): Pulling v${VERSION}..." >> "$LOG_FILE"

# Pull new images
if docker compose pull 2>> "$LOG_FILE"; then
  echo "$(date): Pull successful. Restarting..." >> "$LOG_FILE"

  # Restart with new images
  docker compose up -d 2>> "$LOG_FILE"

  echo "$(date): Update to v${VERSION} complete!" >> "$LOG_FILE"
  echo "{\"status\":\"complete\",\"version\":\"${VERSION}\",\"completedAt\":\"$(date -Iseconds)\"}" > "${INSTALL_DIR}/triggers/status"
else
  echo "$(date): Pull failed for v${VERSION}. Rolling back compose file." >> "$LOG_FILE"

  # Restore to latest on failure
  sed -i "s|${REGISTRY}/fastfoodie-api:.*|${REGISTRY}/fastfoodie-api:latest|" docker-compose.yml
  sed -i "s|${REGISTRY}/fastfoodie-admin:.*|${REGISTRY}/fastfoodie-admin:latest|" docker-compose.yml
  sed -i "s|${REGISTRY}/fastfoodie-webapp:.*|${REGISTRY}/fastfoodie-webapp:latest|" docker-compose.yml

  echo "{\"status\":\"failed\",\"version\":\"${VERSION}\",\"failedAt\":\"$(date -Iseconds)\",\"error\":\"Pull failed\"}" > "${INSTALL_DIR}/triggers/status"
fi
