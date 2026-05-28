#!/bin/bash
# setup.sh - Initial server setup (called by UserData or manually)
set -euo pipefail
exec > >(tee -a /var/log/ecommerce-setup.log) 2>&1

echo "=== Setup Start: $(date) ==="

REPO_URL="${REPO_URL:-https://github.com/YOUR_USER/YOUR_REPO.git}"
BRANCH="${BRANCH:-main}"
APP_DIR="/app/ecommerce"
NODE_ENV="${NODE_ENV:-production}"

# System update
echo "Updating system packages..."
dnf update -y

# Install Node.js 20
if ! command -v node > /dev/null 2>&1; then
  echo "Installing Node.js 20..."
  curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
  dnf install -y nodejs
fi
echo "Node.js version: $(node -v)"
echo "npm version: $(npm -v)"

# Install git
dnf install -y git nc

# Install PM2
if ! command -v pm2 > /dev/null 2>&1; then
  echo "Installing PM2..."
  npm install -g pm2
fi

# Install CloudWatch Agent
if ! command -v amazon-cloudwatch-agent-ctl > /dev/null 2>&1; then
  dnf install -y amazon-cloudwatch-agent
fi

# Clone or update repository
mkdir -p /app
if [ -d "$APP_DIR/.git" ]; then
  echo "Updating existing repository..."
  cd "$APP_DIR"
  git fetch origin
  git checkout "$BRANCH"
  git pull origin "$BRANCH"
else
  echo "Cloning repository from $REPO_URL..."
  git clone -b "$BRANCH" "$REPO_URL" "$APP_DIR"
fi

cd "$APP_DIR/backend"

# Install Node.js dependencies
echo "Installing dependencies..."
npm ci --production

# Create .env if not exists (expects it to be injected by UserData)
if [ ! -f ".env" ]; then
  echo "WARNING: .env file not found. Copying from .env.example..."
  cp .env.example .env
  echo "Please edit /app/ecommerce/backend/.env with your actual values"
fi

# Run database migrations
echo "Running migrations..."
DB_HOST=$(grep DB_HOST .env | cut -d= -f2 | tr -d ' ')
DB_PORT=$(grep DB_PORT .env | cut -d= -f2 | tr -d ' ' || echo "5432")

echo "Waiting for database at $DB_HOST:$DB_PORT..."
for i in {1..30}; do
  if nc -z "$DB_HOST" "${DB_PORT:-5432}" 2>/dev/null; then
    echo "Database is reachable"
    break
  fi
  echo "Attempt $i/30: waiting 10s..."
  sleep 10
done

npx sequelize-cli db:migrate --env production

# Seed if empty
SEED_CHECK=$(node -e "
  require('dotenv').config();
  const { Product } = require('./src/models');
  Product.count().then(c => { process.stdout.write(String(c)); process.exit(0); }).catch(() => { process.stdout.write('0'); process.exit(0); });
" 2>/dev/null || echo "0")

if [ "$SEED_CHECK" = "0" ]; then
  echo "Seeding initial data..."
  npx sequelize-cli db:seed:all --env production
fi

# Create PM2 log dir
mkdir -p /var/log/pm2

# Start application
echo "Starting application with PM2..."
pm2 delete ecommerce 2>/dev/null || true
pm2 start ecosystem.config.js --env production
pm2 startup systemd -u ec2-user --hp /home/ec2-user | bash || true
pm2 save

echo "=== Setup Complete: $(date) ==="
echo "App running at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'localhost'):3000"
