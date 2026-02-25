#!/bin/bash
set -e

# ─── FastFoodie Update Script ────────────────────────────
# Run from the install directory:
#   cd /opt/fastfoodie && sudo ./update.sh

echo ""
echo "🔄 Updating FastFoodie..."
echo ""

cd /opt/fastfoodie

echo "📥 Pulling latest images..."
docker compose pull

echo ""
echo "🔄 Restarting services..."
docker compose up -d

echo ""
echo "✅ Update complete!"
echo ""
docker compose ps
echo ""
