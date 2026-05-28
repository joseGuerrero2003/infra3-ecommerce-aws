#!/bin/bash
# setup-github.sh — Automated GitHub repository setup
# Creates the GitHub repo, connects remote, pushes code, creates release.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }
log_step()  { echo -e "\n${CYAN}==> $1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ============================================================
# DEFAULTS (override via flags or prompts)
# ============================================================
REPO_NAME="${REPO_NAME:-infra3-ecommerce-aws}"
REPO_DESC="${REPO_DESC:-E-Commerce platform deployed on AWS using CloudFormation, Auto Scaling, RDS PostgreSQL, ALB — Infraestructura III ICESI}"
REPO_VISIBILITY="${REPO_VISIBILITY:-public}"
GH_USERNAME=""
SKIP_INSTALL="${SKIP_INSTALL:-false}"
DRY_RUN="${DRY_RUN:-false}"
RELEASE_TAG="v1.0.0"
RELEASE_TITLE="v1.0.0 — Initial Release"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --name        Repository name        [default: infra3-ecommerce-aws]
  --desc        Repository description [default: auto]
  --private     Make repository private [default: public]
  --username    GitHub username (auto-detected from gh auth)
  --dry-run     Show what would happen without executing
  --help        Show this help

Environment variables:
  REPO_NAME, REPO_VISIBILITY, SKIP_INSTALL

Examples:
  $0
  $0 --name my-ecommerce --private
  $0 --dry-run
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)     REPO_NAME="$2"; shift 2 ;;
    --desc)     REPO_DESC="$2"; shift 2 ;;
    --private)  REPO_VISIBILITY="private"; shift ;;
    --username) GH_USERNAME="$2"; shift 2 ;;
    --dry-run)  DRY_RUN="true"; shift ;;
    --help)     usage ;;
    *) log_error "Unknown option: $1" ;;
  esac
done

run() {
  if [ "$DRY_RUN" = "true" ]; then
    echo -e "  ${YELLOW}[DRY-RUN]${NC} $*"
  else
    eval "$@"
  fi
}

# ============================================================
# STEP 1: Verify we are in the project root
# ============================================================
log_step "Step 1: Verify project directory"

if [ ! -f "$PROJECT_ROOT/backend/package.json" ]; then
  log_error "Not in project root. Expected backend/package.json at: $PROJECT_ROOT"
fi
log_ok "Project root: $PROJECT_ROOT"

cd "$PROJECT_ROOT"

# ============================================================
# STEP 2: Check / Install git
# ============================================================
log_step "Step 2: Check git"

if ! command -v git > /dev/null 2>&1; then
  log_error "git not found. Install: https://git-scm.com/downloads"
fi
GIT_VERSION=$(git --version)
log_ok "$GIT_VERSION"

# ============================================================
# STEP 3: Check / Install GitHub CLI (gh)
# ============================================================
log_step "Step 3: Check GitHub CLI (gh)"

if ! command -v gh > /dev/null 2>&1; then
  log_warn "GitHub CLI (gh) not found."
  if [ "$SKIP_INSTALL" = "true" ]; then
    log_error "gh not installed and SKIP_INSTALL=true. Install manually: https://cli.github.com"
  fi

  log_info "Attempting to install GitHub CLI..."

  if command -v brew > /dev/null 2>&1; then
    log_info "Installing via Homebrew..."
    brew install gh
  elif command -v apt-get > /dev/null 2>&1; then
    log_info "Installing via apt..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update
    sudo apt install -y gh
  elif command -v dnf > /dev/null 2>&1; then
    log_info "Installing via dnf..."
    sudo dnf install -y 'dnf-command(config-manager)'
    sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
    sudo dnf install -y gh
  elif command -v winget > /dev/null 2>&1; then
    log_info "Installing via winget (Windows)..."
    winget install --id GitHub.cli --accept-package-agreements --accept-source-agreements
    log_warn "Restart your terminal after winget install, then re-run this script."
    exit 0
  elif command -v choco > /dev/null 2>&1; then
    log_info "Installing via Chocolatey..."
    choco install gh -y
  else
    cat <<EOF

${YELLOW}Automatic installation not possible for your OS.${NC}

Install GitHub CLI manually:
  macOS:   brew install gh
  Ubuntu:  https://cli.github.com/packages/
  Windows: winget install GitHub.cli  OR  https://cli.github.com/

Then re-run: ./scripts/setup-github.sh
EOF
    exit 1
  fi

  if ! command -v gh > /dev/null 2>&1; then
    log_error "Installation failed. Install gh manually: https://cli.github.com"
  fi
fi

GH_VERSION=$(gh --version | head -1)
log_ok "GitHub CLI: $GH_VERSION"

# ============================================================
# STEP 4: Authenticate GitHub CLI
# ============================================================
log_step "Step 4: GitHub authentication"

if ! gh auth status > /dev/null 2>&1; then
  log_warn "Not authenticated with GitHub."
  log_info "Starting interactive authentication..."
  log_info "(Choose: GitHub.com → HTTPS → Login with browser)"
  echo ""
  if [ "$DRY_RUN" = "true" ]; then
    echo -e "  ${YELLOW}[DRY-RUN]${NC} gh auth login"
  else
    gh auth login
  fi
else
  log_ok "Already authenticated with GitHub"
fi

# Get GitHub username
if [ -z "$GH_USERNAME" ]; then
  GH_USERNAME=$(gh api user --jq '.login' 2>/dev/null || echo "")
fi
if [ -z "$GH_USERNAME" ]; then
  log_error "Could not detect GitHub username. Pass --username YOUR_GITHUB_USER"
fi
log_ok "GitHub user: $GH_USERNAME"

# ============================================================
# STEP 5: Security scan — no secrets before commit
# ============================================================
log_step "Step 5: Security scan (pre-commit)"

SECRETS_FOUND=false

# Check .env files exist (should be ignored)
if git -C "$PROJECT_ROOT" check-ignore -q backend/.env 2>/dev/null; then
  log_ok ".env is gitignored"
else
  if [ -f "$PROJECT_ROOT/backend/.env" ]; then
    log_warn "backend/.env exists but .gitignore may not cover it — verify manually"
  else
    log_ok "No backend/.env file to worry about"
  fi
fi

# Check node_modules won't be added
if git -C "$PROJECT_ROOT" check-ignore -q backend/node_modules 2>/dev/null; then
  log_ok "node_modules/ is gitignored"
fi

# Check for AWS credential patterns in staged/tracked files
if git -C "$PROJECT_ROOT" status --porcelain | grep -v "^??" | xargs -I{} 2>/dev/null; then
  :
fi

# Scan for common secret patterns in source files
SECRET_PATTERNS=(
  "AKIA[0-9A-Z]{16}"
  "aws_secret_access_key\s*=\s*[A-Za-z0-9/+]{40}"
  "password\s*=\s*['\"][^'\"]{8,}['\"]"
)

log_info "Scanning files for accidental secrets..."
SCAN_ERRORS=0

for dir in backend/src backend/migrations backend/seeders cloudformation scripts; do
  if [ -d "$PROJECT_ROOT/$dir" ]; then
    # Check for hardcoded AKIA keys
    if grep -rl "AKIA[0-9A-Z]\{16\}" "$PROJECT_ROOT/$dir" 2>/dev/null | grep -q .; then
      log_error "SECURITY: AWS Access Key ID found in $dir — remove before committing"
      SCAN_ERRORS=$((SCAN_ERRORS + 1))
    fi
    # Check for .env password patterns only in non-.env.example files
    if grep -rl "DB_PASSWORD=.\{8,\}" "$PROJECT_ROOT/$dir" 2>/dev/null | grep -v ".example" | grep -q .; then
      log_warn "Possible hardcoded DB_PASSWORD found in $dir — verify this is not a real password"
    fi
  fi
done

# Check that parameters/dev.json still has placeholder values
if [ -f "$PROJECT_ROOT/cloudformation/parameters/dev.json" ]; then
  if grep -q "CHANGE_ME" "$PROJECT_ROOT/cloudformation/parameters/dev.json"; then
    log_ok "cloudformation/parameters/dev.json: contains placeholder values (expected)"
  else
    log_warn "cloudformation/parameters/dev.json may contain real secrets — verify before commit"
  fi
fi

if [ "$SCAN_ERRORS" -gt 0 ]; then
  log_error "Security scan failed. Fix secrets before proceeding."
fi
log_ok "Security scan passed — no obvious secrets in source files"

# ============================================================
# STEP 6: Initialize git if not already done
# ============================================================
log_step "Step 6: Git initialization"

if [ ! -d "$PROJECT_ROOT/.git" ]; then
  log_info "Initializing git repository..."
  run "git -C \"$PROJECT_ROOT\" init"
  run "git -C \"$PROJECT_ROOT\" checkout -b main"
else
  log_ok "Git repository already initialized"
  CURRENT_BRANCH=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo "unknown")
  log_ok "Current branch: $CURRENT_BRANCH"
  if [ "$CURRENT_BRANCH" != "main" ]; then
    log_info "Switching to main branch..."
    run "git -C \"$PROJECT_ROOT\" checkout -B main"
  fi
fi

# ============================================================
# STEP 7: Stage and commit
# ============================================================
log_step "Step 7: Create initial commit"

cd "$PROJECT_ROOT"

# Check if there are already commits
HAS_COMMITS=$(git log --oneline 2>/dev/null | wc -l | tr -d ' ')

if [ "$HAS_COMMITS" -gt 0 ]; then
  log_warn "Repository already has $HAS_COMMITS commit(s). Skipping initial commit."
else
  log_info "Staging all files..."
  run "git add ."

  # Show what will be committed
  log_info "Files to be committed:"
  if [ "$DRY_RUN" = "false" ]; then
    git diff --cached --name-status | head -30
    TOTAL_FILES=$(git diff --cached --name-status | wc -l | tr -d ' ')
    if [ "$TOTAL_FILES" -gt 30 ]; then
      echo "  ... and $((TOTAL_FILES - 30)) more files"
    fi
  fi

  log_info "Creating initial commit..."
  run "git commit -m \"feat: initial project setup

AWS e-commerce platform — Infraestructura III ICESI

Stack:
- Backend: Node.js 20 + Express.js + Sequelize ORM
- Database: PostgreSQL 15 on AWS RDS (db.t3.micro)
- Frontend: HTML5 + CSS3 + JavaScript (vanilla + jQuery)
- IaC: AWS CloudFormation (5 modular stacks)
- Process: PM2 cluster mode
- CI/CD: GitHub Actions
- Monitoring: CloudWatch + SNS + CloudTrail

Infrastructure:
- VPC with public/private subnets across 2 AZs
- Application Load Balancer (internet-facing)
- Auto Scaling Group (1-3 x t2.micro)
- Bastion Host + SSM Session Manager
- Single NAT Gateway (cost-optimized)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>\""
fi

log_ok "Commit created successfully"

# ============================================================
# STEP 8: Create GitHub repository
# ============================================================
log_step "Step 8: Create GitHub repository"

REPO_URL="https://github.com/$GH_USERNAME/$REPO_NAME"

# Check if repo already exists
if gh repo view "$GH_USERNAME/$REPO_NAME" > /dev/null 2>&1; then
  log_warn "Repository $GH_USERNAME/$REPO_NAME already exists on GitHub"
  log_info "Will connect to existing repository"
else
  log_info "Creating GitHub repository: $GH_USERNAME/$REPO_NAME"

  VISIBILITY_FLAG="--public"
  [ "$REPO_VISIBILITY" = "private" ] && VISIBILITY_FLAG="--private"

  run "gh repo create \"$REPO_NAME\" \
    $VISIBILITY_FLAG \
    --description \"$REPO_DESC\" \
    --homepage \"\" \
    --disable-wiki \
    --confirm 2>/dev/null || true"

  # Fallback create without some flags if older gh version
  if ! gh repo view "$GH_USERNAME/$REPO_NAME" > /dev/null 2>&1 && [ "$DRY_RUN" = "false" ]; then
    log_info "Retrying with minimal flags..."
    gh repo create "$REPO_NAME" $VISIBILITY_FLAG --description "$REPO_DESC" || \
      log_error "Failed to create repository. Try manually: gh repo create $REPO_NAME"
  fi

  log_ok "Repository created: $REPO_URL"
fi

# ============================================================
# STEP 9: Configure remote origin
# ============================================================
log_step "Step 9: Configure remote origin"

if git -C "$PROJECT_ROOT" remote get-url origin > /dev/null 2>&1; then
  EXISTING_REMOTE=$(git -C "$PROJECT_ROOT" remote get-url origin)
  log_warn "Remote 'origin' already configured: $EXISTING_REMOTE"
  if [ "$EXISTING_REMOTE" != "https://github.com/$GH_USERNAME/$REPO_NAME.git" ] && \
     [ "$EXISTING_REMOTE" != "git@github.com:$GH_USERNAME/$REPO_NAME.git" ]; then
    log_info "Updating remote to: $REPO_URL"
    run "git -C \"$PROJECT_ROOT\" remote set-url origin https://github.com/$GH_USERNAME/$REPO_NAME.git"
  else
    log_ok "Remote already points to correct repository"
  fi
else
  log_info "Adding remote origin..."
  run "git -C \"$PROJECT_ROOT\" remote add origin https://github.com/$GH_USERNAME/$REPO_NAME.git"
fi

if [ "$DRY_RUN" = "false" ]; then
  REMOTE_URL=$(git -C "$PROJECT_ROOT" remote get-url origin 2>/dev/null || echo "not configured")
  log_ok "Remote origin: $REMOTE_URL"
fi

# ============================================================
# STEP 10: Push to GitHub
# ============================================================
log_step "Step 10: Push to GitHub"

log_info "Pushing main branch..."
run "git -C \"$PROJECT_ROOT\" push -u origin main"

log_ok "Code pushed to GitHub"

# ============================================================
# STEP 11: Create release v1.0.0
# ============================================================
log_step "Step 11: Create release $RELEASE_TAG"

if git -C "$PROJECT_ROOT" tag -l "$RELEASE_TAG" | grep -q "$RELEASE_TAG"; then
  log_warn "Tag $RELEASE_TAG already exists — skipping"
else
  log_info "Creating tag $RELEASE_TAG..."
  run "git -C \"$PROJECT_ROOT\" tag -a \"$RELEASE_TAG\" -m \"$RELEASE_TITLE

First stable release of the AWS e-commerce platform.

Features:
- Full e-commerce API (products, cart, orders, auth)
- CloudFormation IaC with 5 modular stacks
- Auto Scaling + ALB + RDS PostgreSQL
- PM2 cluster mode + CloudWatch monitoring
- GitHub Actions CI/CD pipeline

Deployment: See docs/deployment-guide.md\""
  run "git -C \"$PROJECT_ROOT\" push origin \"$RELEASE_TAG\""
fi

# Create GitHub Release via gh CLI
if gh release view "$RELEASE_TAG" --repo "$GH_USERNAME/$REPO_NAME" > /dev/null 2>&1; then
  log_warn "GitHub Release $RELEASE_TAG already exists"
else
  log_info "Creating GitHub Release..."
  run "gh release create \"$RELEASE_TAG\" \
    --repo \"$GH_USERNAME/$REPO_NAME\" \
    --title \"$RELEASE_TITLE\" \
    --notes \"## E-Commerce Platform on AWS

**Course:** Infraestructura III — ICESI
**Stack:** Node.js + Express + PostgreSQL + CloudFormation

### What's included

- **Backend:** REST API with JWT auth, Sequelize ORM, bcrypt, rate limiting
- **Frontend:** Responsive HTML/CSS/JS catalog, cart, checkout, admin panel
- **Infrastructure as Code:** 5 CloudFormation stacks (VPC, Security, RDS, Compute, Monitoring)
- **Auto Scaling:** 1-3 EC2 t2.micro instances behind Application Load Balancer
- **Monitoring:** CloudWatch alarms + SNS notifications + CloudTrail audit

### Deploy in one command

\`\`\`bash
./scripts/master-deploy.sh --env dev --params cloudformation/parameters/my-dev.json
\`\`\`

See [deployment guide](docs/deployment-guide.md) for full instructions.\""
fi

# ============================================================
# STEP 12: Configure GitHub repository settings
# ============================================================
log_step "Step 12: GitHub repository settings"

# Add topics/tags
run "gh repo edit \"$GH_USERNAME/$REPO_NAME\" \
  --add-topic aws \
  --add-topic cloudformation \
  --add-topic nodejs \
  --add-topic ecommerce \
  --add-topic infrastructure-as-code \
  --add-topic auto-scaling \
  --add-topic postgresql 2>/dev/null || true"

log_ok "Repository topics configured"

# ============================================================
# FINAL SUMMARY
# ============================================================
echo ""
echo -e "${GREEN}=============================================="
echo -e "  Setup Complete!"
echo -e "==============================================  ${NC}"
echo ""
log_ok "Repository:  https://github.com/$GH_USERNAME/$REPO_NAME"
log_ok "Branch:      main"
log_ok "Release:     $RELEASE_TAG"
echo ""
echo -e "${CYAN}Useful Git commands:${NC}"
echo ""
echo "  # See recent commits"
echo "  git log --oneline -10"
echo ""
echo "  # Create a feature branch"
echo "  git checkout -b feature/your-feature"
echo ""
echo "  # After changes, commit and push"
echo "  git add ."
echo "  git commit -m \"feat(scope): description\""
echo "  git push origin feature/your-feature"
echo ""
echo "  # Update dev.json with real values and push"
echo "  git add cloudformation/parameters/my-dev.json"
echo "  git commit -m \"chore: configure deployment parameters\""
echo "  git push"
echo ""
echo -e "${CYAN}GitHub CLI useful commands:${NC}"
echo ""
echo "  # Open repo in browser"
echo "  gh repo view --web"
echo ""
echo "  # Create a PR"
echo "  gh pr create --title 'feat: add X' --body 'Description'"
echo ""
echo "  # Check CI status"
echo "  gh run list"
echo ""
echo -e "${CYAN}Before deploying to AWS:${NC}"
echo ""
echo "  1. Edit cloudformation/parameters/my-dev.json with real values"
echo "  2. chmod +x scripts/*.sh"
echo "  3. ./scripts/master-deploy.sh --env dev --params cloudformation/parameters/my-dev.json"
echo ""
echo -e "${GREEN}Repository URL: https://github.com/$GH_USERNAME/$REPO_NAME${NC}"
echo ""
