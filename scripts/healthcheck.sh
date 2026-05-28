#!/bin/bash
# healthcheck.sh - Validate application and infrastructure health
set -uo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0

check() {
  local name="$1"; local cmd="$2"
  if eval "$cmd" > /dev/null 2>&1; then
    echo -e "${GREEN}[PASS]${NC} $name"
    ((PASS++))
  else
    echo -e "${RED}[FAIL]${NC} $name"
    ((FAIL++))
  fi
}

ALB_URL="${1:-http://localhost:3000}"

echo "=== ECommerce Health Check ==="
echo "Target: $ALB_URL"
echo ""

# Application health
check "Health endpoint responds 200" "curl -sf --max-time 10 '$ALB_URL/health'"
check "Health returns JSON with 'healthy'" "curl -sf --max-time 10 '$ALB_URL/health' | grep -q 'healthy'"
check "Products API returns 200" "curl -sf --max-time 10 '$ALB_URL/api/products'"
check "401 returned for protected route without auth" \
  "[ \$(curl -s -o /dev/null -w '%{http_code}' '$ALB_URL/api/auth/profile') = '401' ]"

# Local checks (when running on EC2)
if command -v pm2 > /dev/null 2>&1; then
  check "PM2 process is online" "pm2 show ecommerce | grep -q 'online'"
fi

if command -v nc > /dev/null 2>&1 && [ -f /app/ecommerce/backend/.env ]; then
  DB_HOST=$(grep DB_HOST /app/ecommerce/backend/.env | cut -d= -f2 | tr -d ' ')
  check "Database port 5432 reachable" "nc -z -w5 '$DB_HOST' 5432"
fi

check "Port 3000 is listening" "nc -z localhost 3000"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

[ "$FAIL" -gt 0 ] && exit 1 || exit 0
