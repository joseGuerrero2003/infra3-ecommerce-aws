#!/bin/bash
# init-db.sh - Manual database initialization (fallback if UserData fails)
set -euo pipefail

APP_DIR="/app/ecommerce/backend"

[ ! -d "$APP_DIR" ] && echo "ERROR: App directory not found: $APP_DIR" && exit 1

cd "$APP_DIR"
[ ! -f ".env" ] && echo "ERROR: .env not found" && exit 1

echo "Running migrations..."
npx sequelize-cli db:migrate --env production

echo "Seeding data..."
npx sequelize-cli db:seed:all --env production

echo "Database initialized successfully"
