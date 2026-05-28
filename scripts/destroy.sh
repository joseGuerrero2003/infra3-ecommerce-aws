#!/bin/bash
# destroy.sh - Delete all stacks in reverse order (USE WITH CAUTION)
set -euo pipefail

ENV="${ENV:-dev}"
PROJECT="${PROJECT:-ecommerce}"
REGION="${REGION:-us-east-1}"

echo "WARNING: This will DELETE all CloudFormation stacks for $PROJECT-$ENV"
echo "Region: $REGION"
echo ""
read -p "Type 'yes' to confirm: " CONFIRM
[ "$CONFIRM" != "yes" ] && echo "Aborted." && exit 0

delete_stack() {
  local STACK="$1"
  echo "Deleting: $STACK"
  aws cloudformation delete-stack --stack-name "$STACK" --region "$REGION"
  aws cloudformation wait stack-delete-complete --stack-name "$STACK" --region "$REGION" || true
  echo "Deleted: $STACK"
}

for STACK in monitoring compute database security network; do
  FULL="${PROJECT}-${ENV}-${STACK}"
  STATUS=$(aws cloudformation describe-stacks --stack-name "$FULL" --region "$REGION" \
    --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_EXISTS")
  if [ "$STATUS" != "NOT_EXISTS" ]; then
    delete_stack "$FULL"
  else
    echo "Stack $FULL does not exist, skipping"
  fi
done

# Empty and delete CloudTrail S3 bucket
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="${PROJECT}-${ENV}-cloudtrail-${ACCOUNT_ID}"
if aws s3 ls "s3://$BUCKET" --region "$REGION" > /dev/null 2>&1; then
  echo "Emptying CloudTrail bucket: $BUCKET"
  aws s3 rm "s3://$BUCKET" --recursive --region "$REGION"
fi

echo "All stacks deleted."
