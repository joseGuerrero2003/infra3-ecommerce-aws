#!/bin/bash
# deploy.sh - Update application code on running instances
set -euo pipefail

APP_DIR="/app/ecommerce"
BRANCH="${BRANCH:-main}"

echo "=== Deploy Start: $(date) ==="

cd "$APP_DIR"

# Pull latest code
echo "Pulling latest code from $BRANCH..."
git fetch origin
git checkout "$BRANCH"
git pull origin "$BRANCH"

cd "$APP_DIR/backend"

# Reinstall dependencies if package.json changed
if git diff HEAD~1 HEAD --name-only 2>/dev/null | grep -q "package.json"; then
  echo "package.json changed, reinstalling dependencies..."
  npm ci --production
fi

# Run new migrations
echo "Running migrations..."
npx sequelize-cli db:migrate --env production

# Reload application (zero-downtime with PM2 cluster mode)
echo "Reloading application..."
pm2 reload ecommerce --update-env

# Verify service is healthy
sleep 3
if pm2 show ecommerce | grep -q "online"; then
  echo "Application is running"
else
  echo "ERROR: Application failed to start after deploy"
  pm2 logs ecommerce --lines 50
  exit 1
fi

echo "=== Deploy Complete: $(date) ==="
