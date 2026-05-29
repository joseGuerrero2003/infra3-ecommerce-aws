#!/bin/bash
# master-deploy.sh - Deploy all 5 CloudFormation stacks in order

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CFN_DIR="$PROJECT_ROOT/cloudformation"

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

# Filter params from the JSON file to only include params declared in the template.
# CloudFormation rejects unknown parameters — this prevents ValidationError.
filter_params() {
  local template="$1"
  local params_file="$2"

  python3 - "$template" "$params_file" <<'PYEOF'
import json, re, sys

template_path, params_path = sys.argv[1], sys.argv[2]

with open(template_path) as f:
    content = f.read()

# Extract only keys directly under the Parameters: top-level section
m = re.search(r'^Parameters:\n((?:  [A-Za-z]\w+:\s*\n(?:    [^\n]*\n)*)*)', content, re.MULTILINE)
declared = set()
if m:
    declared = set(re.findall(r'^  ([A-Za-z]\w+):', m.group(0), re.MULTILINE))

with open(params_path) as f:
    all_params = json.load(f)

filtered = [p for p in all_params if p['ParameterKey'] in declared]
print(' '.join(f"{p['ParameterKey']}={p['ParameterValue']}" for p in filtered))
PYEOF
}

deploy_stack() {
  local STACK_NAME="$1"
  local TEMPLATE="$2"

  log_info "Deploying stack: $STACK_NAME"

  local PARAMS
  PARAMS=$(filter_params "$TEMPLATE" "$PARAMS_FILE")

  aws cloudformation deploy \
    --stack-name "$STACK_NAME" \
    --template-file "$TEMPLATE" \
    --parameter-overrides $PARAMS \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$REGION" \
    --no-fail-on-empty-changeset

  log_ok "Stack deployed: $STACK_NAME"
}

wait_for_stack() {
  local STACK_NAME="$1"
  log_info "Waiting for stack to settle: $STACK_NAME"
  local STATUS
  for i in $(seq 1 60); do
    STATUS=$(aws cloudformation describe-stacks \
      --stack-name "$STACK_NAME" \
      --region "$REGION" \
      --query 'Stacks[0].StackStatus' \
      --output text 2>/dev/null || echo "NOT_FOUND")

    case "$STATUS" in
      *COMPLETE)   log_ok "Stack $STACK_NAME: $STATUS"; return 0 ;;
      *FAILED)     log_error "Stack $STACK_NAME FAILED: $STATUS" ;;
      *IN_PROGRESS) echo "  Status: $STATUS — waiting 20s... ($i/60)"; sleep 20 ;;
      NOT_FOUND)   log_error "Stack $STACK_NAME not found" ;;
      *)           echo "  Status: $STATUS — waiting 20s..."; sleep 20 ;;
    esac
  done
  log_error "Timeout waiting for stack $STACK_NAME"
}

get_output() {
  aws cloudformation describe-stacks \
    --stack-name "$1" \
    --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$2'].OutputValue" \
    --output text 2>/dev/null || echo ""
}

echo ""
echo "=============================================="
echo "  ECommerce AWS Deployment"
echo "  Environment: $ENV | Project: $PROJECT"
echo "  Region: $REGION"
echo "  Parameters: $PARAMS_FILE"
echo "=============================================="
echo ""

# Verify credentials
aws sts get-caller-identity --region "$REGION" > /dev/null 2>&1 \
  || log_error "AWS credentials not configured or expired"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
log_ok "AWS Account: $ACCOUNT_ID"

command -v jq > /dev/null 2>&1 || log_error "jq is required. Install: sudo yum install -y jq"
command -v python3 > /dev/null 2>&1 || log_error "python3 is required (for parameter filtering)"

STACKS_ORDER=(network security database compute monitoring)
START=0
if [ -n "$SKIP_TO" ]; then
  for i in "${!STACKS_ORDER[@]}"; do
    [ "${STACKS_ORDER[$i]}" = "$SKIP_TO" ] && START=$i && break
  done
fi

for ((i=START; i<${#STACKS_ORDER[@]}; i++)); do
  STACK="${STACKS_ORDER[$i]}"
  STACK_FULL_NAME="${PROJECT}-${ENV}-${STACK}"
  TEMPLATE="$CFN_DIR/${STACK}.yaml"

  [ ! -f "$TEMPLATE" ] && log_error "Template not found: $TEMPLATE"

  deploy_stack "$STACK_FULL_NAME" "$TEMPLATE"
  wait_for_stack "$STACK_FULL_NAME"
  echo ""
done

ALB_DNS=$(get_output "${PROJECT}-${ENV}-compute" "AlbDnsName")
BASTION_IP=$(get_output "${PROJECT}-${ENV}-compute" "BastionPublicIp")

echo "=============================================="
echo "  Deployment Complete"
echo "=============================================="
[ -n "$ALB_DNS" ] && log_ok "Application URL:  http://$ALB_DNS"
[ -n "$BASTION_IP" ] && log_ok "Bastion Host IP:  $BASTION_IP"
echo ""
echo "Next steps:"
echo "  1. Confirm SNS email subscription (check your inbox)"
echo "  2. Wait 5-10 min for EC2 UserData to finish"
echo "  3. Access the app: http://$ALB_DNS"
echo "  4. Run: ./scripts/healthcheck.sh http://$ALB_DNS"
echo ""
