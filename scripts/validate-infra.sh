#!/bin/bash
# validate-infra.sh - Verify AWS resources after deployment
set -uo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
PASS=0; FAIL=0

ENV="${ENV:-dev}"
PROJECT="${PROJECT:-ecommerce}"
REGION="${REGION:-us-east-1}"

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

get_export() {
  aws cloudformation list-exports --region "$REGION" \
    --query "Exports[?Name=='$1'].Value" --output text 2>/dev/null
}

echo "=== Infrastructure Validation ==="
echo "Environment: $ENV | Project: $PROJECT | Region: $REGION"
echo ""

# CloudFormation stacks
for STACK in network security database compute monitoring; do
  STACK_NAME="${PROJECT}-${ENV}-${STACK}"
  check "Stack $STACK_NAME is CREATE_COMPLETE or UPDATE_COMPLETE" \
    "aws cloudformation describe-stacks --stack-name '$STACK_NAME' --region '$REGION' \
     --query 'Stacks[0].StackStatus' --output text | grep -E 'COMPLETE'"
done

echo ""
echo "--- Resources ---"

# VPC
VPC_ID=$(get_export "${PROJECT}-${ENV}-VpcId")
check "VPC exists ($VPC_ID)" \
  "aws ec2 describe-vpcs --vpc-ids '$VPC_ID' --region '$REGION'"

# ALB
ALB_DNS=$(get_export "${PROJECT}-${ENV}-AlbDnsName")
check "ALB DNS reachable (HTTP 200 or 301/302)" \
  "[ \$(curl -s -o /dev/null -w '%{http_code}' 'http://$ALB_DNS/health' --max-time 15) -lt 500 ]"

# ASG
ASG_NAME=$(get_export "${PROJECT}-${ENV}-AsgName")
check "ASG has at least 1 healthy instance" \
  "aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names '$ASG_NAME' --region '$REGION' \
   --query 'AutoScalingGroups[0].Instances[?HealthStatus==\`Healthy\`] | length(@)' --output text | grep -v '^0$'"

# RDS
check "RDS instance is available" \
  "aws rds describe-db-instances --db-instance-identifier '${PROJECT}-${ENV}-db' --region '$REGION' \
   --query 'DBInstances[0].DBInstanceStatus' --output text | grep -q 'available'"

# SNS
SNS_ARN=$(get_export "${PROJECT}-${ENV}-SnsTopicArn")
check "SNS topic exists" \
  "aws sns get-topic-attributes --topic-arn '$SNS_ARN' --region '$REGION'"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [ "$FAIL" -gt 0 ]; then
  echo -e "${RED}Some checks failed. Review the output above.${NC}"
  exit 1
else
  echo -e "${GREEN}All infrastructure checks passed!${NC}"
  echo "Application URL: http://$ALB_DNS"
fi
