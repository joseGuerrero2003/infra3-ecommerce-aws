#!/bin/bash
# master-deploy.sh - Deploy all 5 CloudFormation stacks in order

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CFN_DIR="$PROJECT_ROOT/cloudformation"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --env         Environment (dev|staging|prod)  [default: dev]
  --project     Project name                    [default: ecommerce]
  --params      Path to parameters JSON file    [default: cloudformation/parameters/dev.json]
  --region      AWS Region                      [default: us-east-1]
  --skip-to     Start from a specific stack     (network|security|database|compute|monitoring)
  --help        Show this help

Example:
  $0 --env dev --params cloudformation/parameters/dev.json
EOF
  exit 0
}

ENV="dev"
PROJECT="ecommerce"
PARAMS_FILE="$CFN_DIR/parameters/dev.json"
REGION="us-east-1"
SKIP_TO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)     ENV="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --params)  PARAMS_FILE="$2"; shift 2 ;;
    --region)  REGION="$2"; shift 2 ;;
    --skip-to) SKIP_TO="$2"; shift 2 ;;
    --help)    usage ;;
    *) log_error "Unknown option: $1" ;;
  esac
done

[ ! -f "$PARAMS_FILE" ] && log_error "Parameters file not found: $PARAMS_FILE"

deploy_stack() {
  local STACK_NAME="$1"
  local TEMPLATE="$2"
  local EXTRA_PARAMS="${3:-}"

  log_info "Deploying stack: $STACK_NAME"

  local PARAMS
  PARAMS=$(jq -r '.[] | "\(.ParameterKey)=\(.ParameterValue)"' "$PARAMS_FILE" | tr '\n' ' ')

  local CMD="aws cloudformation deploy \
    --stack-name $STACK_NAME \
    --template-file $TEMPLATE \
    --parameter-overrides $PARAMS $EXTRA_PARAMS \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION \
    --no-fail-on-empty-changeset"

  if eval "$CMD"; then
    log_ok "Stack deployed: $STACK_NAME"
  else
    log_error "Failed to deploy: $STACK_NAME"
  fi
}

wait_for_stack() {
  local STACK_NAME="$1"
  log_info "Waiting for stack: $STACK_NAME"
  aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$REGION" 2>/dev/null \
    || aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME" --region "$REGION" 2>/dev/null \
    || true
}

get_output() {
  local STACK_NAME="$1"
  local KEY="$2"
  aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$KEY'].OutputValue" \
    --output text
}

echo ""
echo "=============================================="
echo "  ECommerce AWS Deployment"
echo "  Environment: $ENV | Project: $PROJECT"
echo "  Region: $REGION"
echo "  Parameters: $PARAMS_FILE"
echo "=============================================="
echo ""

# Check AWS credentials
aws sts get-caller-identity --region "$REGION" > /dev/null 2>&1 || log_error "AWS credentials not configured or expired"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
log_ok "AWS Account: $ACCOUNT_ID"

# Check jq is available
command -v jq > /dev/null 2>&1 || log_error "jq is required. Install: sudo yum install -y jq or brew install jq"

STACKS_ORDER=(network security database compute monitoring)
START=0
if [ -n "$SKIP_TO" ]; then
  for i in "${!STACKS_ORDER[@]}"; do
    if [ "${STACKS_ORDER[$i]}" = "$SKIP_TO" ]; then
      START=$i; break
    fi
  done
fi

for ((i=START; i<${#STACKS_ORDER[@]}; i++)); do
  STACK="${STACKS_ORDER[$i]}"
  STACK_FULL_NAME="${PROJECT}-${ENV}-${STACK}"
  TEMPLATE="$CFN_DIR/${STACK}.yaml"

  [ ! -f "$TEMPLATE" ] && log_error "Template not found: $TEMPLATE"

  deploy_stack "$STACK_FULL_NAME" "$TEMPLATE"
  wait_for_stack "$STACK_FULL_NAME"
  log_ok "Stack $STACK complete"
  echo ""
done

# Print final outputs
echo "=============================================="
echo "  Deployment Complete"
echo "=============================================="
ALB_DNS=$(get_output "${PROJECT}-${ENV}-compute" "AlbDnsName" 2>/dev/null || echo "N/A")
BASTION_IP=$(get_output "${PROJECT}-${ENV}-compute" "BastionPublicIp" 2>/dev/null || echo "N/A")
echo ""
log_ok "Application URL:  http://$ALB_DNS"
log_ok "Bastion Host IP:  $BASTION_IP"
echo ""
echo "Next steps:"
echo "  1. Confirm SNS email subscription (check your inbox)"
echo "  2. Access the app: http://$ALB_DNS"
echo "  3. Admin login: admin@ecommerce.com / Admin123!"
echo ""
