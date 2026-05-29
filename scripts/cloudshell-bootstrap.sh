#!/bin/bash
# cloudshell-bootstrap.sh — Automated full deploy from AWS CloudShell
# Run this script INSIDE AWS CloudShell after cloning the repo.
# Compatible with AWS Academy Learner Lab sandbox.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[PASS]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }
log_step()  { echo -e "\n${CYAN}${BOLD}==> $1${NC}"; }
hr()        { echo -e "${BLUE}──────────────────────────────────────────${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CFN_DIR="$PROJECT_ROOT/cloudformation"
PARAMS_FILE="$PROJECT_ROOT/cloudformation/parameters/my-dev.json"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
PROJECT="ecommerce"
ENV="dev"

# ══════════════════════════════════════════════════
# FASE 0 — Verificar entorno CloudShell
# ══════════════════════════════════════════════════
log_step "Fase 0: Verificar entorno AWS CloudShell"
hr

echo -e "${BOLD}--- Identidad AWS ---${NC}"
IDENTITY=$(aws sts get-caller-identity --output json 2>/dev/null) \
  || log_error "No hay credenciales AWS activas. Verifica que iniciaste el lab en AWS Academy."

ACCOUNT_ID=$(echo "$IDENTITY" | python3 -c "import json,sys; print(json.load(sys.stdin)['Account'])")
USER_ARN=$(echo "$IDENTITY"   | python3 -c "import json,sys; print(json.load(sys.stdin)['Arn'])")
log_ok "Account ID: $ACCOUNT_ID"
log_ok "User ARN:   $USER_ARN"

echo ""
echo -e "${BOLD}--- Región activa ---${NC}"
REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")
log_ok "Región: $REGION"
export AWS_DEFAULT_REGION="$REGION"

echo ""
echo -e "${BOLD}--- Herramientas requeridas ---${NC}"
for tool in python3 git jq curl; do
  if command -v "$tool" > /dev/null 2>&1; then
    log_ok "$tool: $(command -v $tool)"
  else
    if [ "$tool" = "jq" ]; then
      log_warn "jq no encontrado. Instalando..."
      sudo yum install -y jq -q && log_ok "jq instalado"
    else
      log_error "$tool no encontrado"
    fi
  fi
done

# ══════════════════════════════════════════════════
# FASE 1 — Límites del Sandbox
# ══════════════════════════════════════════════════
log_step "Fase 1: Verificar límites del Sandbox"
hr

echo -e "${BOLD}--- EC2: Instancias corriendo ---${NC}"
RUNNING=$(aws ec2 describe-instances \
  --filters Name=instance-state-name,Values=running \
  --query 'length(Reservations[*].Instances[*])' \
  --output text 2>/dev/null || echo "0")
log_ok "Instancias corriendo: $RUNNING / 9 máx (sandbox)"
[ "$RUNNING" -ge 8 ] && log_warn "Muy cerca del límite de 9 instancias — revisa antes de continuar"

echo ""
echo -e "${BOLD}--- VPCs existentes ---${NC}"
VPC_COUNT=$(aws ec2 describe-vpcs --query 'length(Vpcs)' --output text 2>/dev/null || echo "0")
log_ok "VPCs actuales: $VPC_COUNT (límite típico: 5)"
[ "$VPC_COUNT" -ge 4 ] && log_warn "Pocas VPCs disponibles — puede fallar al crear nueva"

echo ""
echo -e "${BOLD}--- Elastic IPs ---${NC}"
EIP_COUNT=$(aws ec2 describe-addresses --query 'length(Addresses)' --output text 2>/dev/null || echo "0")
log_ok "EIPs en uso: $EIP_COUNT (límite típico: 5)"
[ "$EIP_COUNT" -ge 4 ] && log_warn "Pocas EIPs disponibles — el stack network necesita 1 para NAT"

echo ""
echo -e "${BOLD}--- RDS instancias ---${NC}"
RDS_COUNT=$(aws rds describe-db-instances \
  --query 'length(DBInstances)' \
  --output text 2>/dev/null || echo "0")
log_ok "RDS instancias actuales: $RDS_COUNT"
[ "$RDS_COUNT" -ge 5 ] && log_warn "Muchas instancias RDS — puede haber límite de cuota"

echo ""
echo -e "${BOLD}--- Key Pair vockey ---${NC}"
if aws ec2 describe-key-pairs --key-names vockey --region "$REGION" > /dev/null 2>&1; then
  log_ok "Key pair 'vockey' existe en $REGION"
else
  log_warn "Key pair 'vockey' NO encontrado en $REGION"
  log_warn "Ve a EC2 Console → Key Pairs y crea/importa 'vockey'"
  log_warn "O edita my-dev.json: BastionKeyName=<tu-key-pair>"
fi

echo ""
echo -e "${BOLD}--- LabRole (AWS Academy) ---${NC}"
LAB_PROFILE_ARN=""
if aws iam get-instance-profile --instance-profile-name LabInstanceProfile > /dev/null 2>&1; then
  LAB_PROFILE_ARN=$(aws iam get-instance-profile \
    --instance-profile-name LabInstanceProfile \
    --query 'InstanceProfile.Arn' --output text)
  log_ok "LabInstanceProfile detectado: $LAB_PROFILE_ARN"
  log_info "Se usará LabInstanceProfile (modo AWS Academy)"
else
  log_info "LabInstanceProfile no encontrado — se creará EC2Role propio"
  log_info "(esto es normal en cuentas AWS fuera de Academy)"
fi

# ══════════════════════════════════════════════════
# FASE 2 — Generar my-dev.json
# ══════════════════════════════════════════════════
log_step "Fase 2: Generar my-dev.json con valores seguros"
hr

# Generate secure random secrets
DB_PASS=$(python3 -c "import secrets,string; \
  chars=string.ascii_letters+string.digits; \
  print('Ec0mm' + ''.join(secrets.choice(chars) for _ in range(11)) + '!')")
JWT_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
JWT_REFRESH=$(python3 -c "import secrets; print(secrets.token_hex(32))")

# Build my-dev.json
cat > "$PARAMS_FILE" <<JSONEOF
[
  { "ParameterKey": "Environment",           "ParameterValue": "$ENV" },
  { "ParameterKey": "ProjectName",           "ParameterValue": "$PROJECT" },
  { "ParameterKey": "GitHubRepoUrl",         "ParameterValue": "https://github.com/joseGuerrero2003/infra3-ecommerce-aws.git" },
  { "ParameterKey": "GitHubBranch",          "ParameterValue": "main" },
  { "ParameterKey": "BastionKeyName",        "ParameterValue": "vockey" },
  { "ParameterKey": "AllowedBastionCIDR",    "ParameterValue": "0.0.0.0/0" },
  { "ParameterKey": "DBUsername",            "ParameterValue": "dbadmin" },
  { "ParameterKey": "DBPassword",            "ParameterValue": "$DB_PASS" },
  { "ParameterKey": "DBName",                "ParameterValue": "ecommerce" },
  { "ParameterKey": "JwtSecret",             "ParameterValue": "$JWT_SECRET" },
  { "ParameterKey": "JwtRefreshSecret",      "ParameterValue": "$JWT_REFRESH" },
  { "ParameterKey": "NotificationEmail",     "ParameterValue": "joseguerrero1912cali@gmail.com" },
  { "ParameterKey": "AppPort",               "ParameterValue": "3000" },
  { "ParameterKey": "NodeEnvironment",       "ParameterValue": "production" },
  { "ParameterKey": "InstanceType",          "ParameterValue": "t2.micro" },
  { "ParameterKey": "AsgMinSize",            "ParameterValue": "1" },
  { "ParameterKey": "AsgMaxSize",            "ParameterValue": "3" },
  { "ParameterKey": "AsgDesiredSize",        "ParameterValue": "1" },
  { "ParameterKey": "LabInstanceProfileArn", "ParameterValue": "$LAB_PROFILE_ARN" }
]
JSONEOF

log_ok "my-dev.json generado en: $PARAMS_FILE"

echo ""
echo -e "${BOLD}--- Verificando my-dev.json ---${NC}"
if jq . "$PARAMS_FILE" > /dev/null 2>&1; then
  log_ok "JSON válido"
else
  log_error "JSON inválido en $PARAMS_FILE"
fi

PLACEHOLDER_COUNT=$(grep -c "CHANGE_ME\|YOUR_USER\|ACADEMY_AUTO_DETECT" "$PARAMS_FILE" 2>/dev/null || echo "0")
if [ "$PLACEHOLDER_COUNT" -gt 0 ]; then
  log_error "Aún hay $PLACEHOLDER_COUNT placeholders sin reemplazar en my-dev.json"
fi
log_ok "Sin placeholders — todos los valores están configurados"

# ══════════════════════════════════════════════════
# FASE 3 — Validar templates CloudFormation
# ══════════════════════════════════════════════════
log_step "Fase 3: Validar templates CloudFormation"
hr

VALIDATION_ERRORS=0
for TEMPLATE in network security database compute monitoring; do
  TPATH="$CFN_DIR/${TEMPLATE}.yaml"
  if aws cloudformation validate-template \
    --template-body "file://$TPATH" \
    --region "$REGION" > /dev/null 2>&1; then
    log_ok "$TEMPLATE.yaml: válido"
  else
    ERR=$(aws cloudformation validate-template \
      --template-body "file://$TPATH" \
      --region "$REGION" 2>&1 || true)
    log_warn "$TEMPLATE.yaml: $ERR"
    VALIDATION_ERRORS=$((VALIDATION_ERRORS+1))
  fi
done

[ "$VALIDATION_ERRORS" -gt 0 ] && log_error "$VALIDATION_ERRORS template(s) fallaron validación"
log_ok "Todos los templates son CloudFormation válidos"

# ══════════════════════════════════════════════════
# FASE 4 — Dar permisos y lanzar deploy
# ══════════════════════════════════════════════════
log_step "Fase 4: Ejecutar master-deploy.sh"
hr

chmod +x "$PROJECT_ROOT/scripts/"*.sh
log_ok "Permisos de ejecución aplicados a scripts/*.sh"

echo ""
log_info "Iniciando deploy de 5 stacks..."
log_info "Tiempo estimado total: 20-30 minutos (RDS tarda ~12 min)"
echo ""

"$PROJECT_ROOT/scripts/master-deploy.sh" \
  --env "$ENV" \
  --project "$PROJECT" \
  --params "$PARAMS_FILE" \
  --region "$REGION"

# ══════════════════════════════════════════════════
# FASE 5 — Esperar EC2 healthy en el Target Group
# ══════════════════════════════════════════════════
log_step "Fase 5: Esperar EC2 healthy en ALB Target Group"
hr

TG_ARN=$(aws elbv2 describe-target-groups \
  --names "${PROJECT}-${ENV}-tg" \
  --region "$REGION" \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text 2>/dev/null || echo "")

if [ -z "$TG_ARN" ]; then
  log_warn "Target Group no encontrado aún. Esperando..."
  sleep 30
  TG_ARN=$(aws elbv2 describe-target-groups \
    --names "${PROJECT}-${ENV}-tg" \
    --region "$REGION" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text 2>/dev/null || echo "")
fi

if [ -n "$TG_ARN" ]; then
  log_info "Esperando hasta 15 min para EC2 healthy..."
  for i in $(seq 1 30); do
    HEALTHY=$(aws elbv2 describe-target-health \
      --target-group-arn "$TG_ARN" \
      --region "$REGION" \
      --query "TargetHealthDescriptions[?TargetHealth.State=='healthy'] | length(@)" \
      --output text 2>/dev/null || echo "0")
    if [ "$HEALTHY" -ge 1 ]; then
      log_ok "EC2 healthy en Target Group: $HEALTHY instancia(s)"
      break
    fi
    echo "  Intento $i/30: 0 instancias healthy — esperando 30s..."
    sleep 30
  done
  [ "$HEALTHY" -eq 0 ] && log_warn "Ningún EC2 healthy aún — UserData puede tardar más"
fi

# ══════════════════════════════════════════════════
# FASE 6 — Verificar logs de UserData
# ══════════════════════════════════════════════════
log_step "Fase 6: Verificar logs de UserData via SSM"
hr

INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "${PROJECT}-${ENV}-asg" \
  --region "$REGION" \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
  --output text 2>/dev/null || echo "")

if [ -n "$INSTANCE_ID" ] && [ "$INSTANCE_ID" != "None" ]; then
  log_ok "EC2 Instance ID: $INSTANCE_ID"
  echo ""
  log_info "Últimas líneas del log de UserData:"
  aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters '{"commands":["tail -30 /var/log/userdata.log 2>/dev/null || echo NO_LOG_YET"]}' \
    --region "$REGION" \
    --output json > /tmp/ssm-cmd.json 2>/dev/null || true

  CMD_ID=$(python3 -c "import json; d=json.load(open('/tmp/ssm-cmd.json')); print(d.get('Command',{}).get('CommandId',''))" 2>/dev/null || echo "")
  if [ -n "$CMD_ID" ]; then
    sleep 5
    aws ssm get-command-invocation \
      --command-id "$CMD_ID" \
      --instance-id "$INSTANCE_ID" \
      --region "$REGION" \
      --query 'StandardOutputContent' \
      --output text 2>/dev/null || log_warn "SSM aún no disponible en esta instancia"
  fi

  echo ""
  log_info "PM2 status:"
  aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters '{"commands":["pm2 jlist 2>/dev/null | python3 -c \"import json,sys; apps=json.load(sys.stdin); [print(f\\\"  {a[\\\"name\\\"]}: {a[\\\"pm2_env\\\"][\\\"status\\\"]}\\\") for a in apps]\" 2>/dev/null || echo PM2_NOT_READY"]}' \
    --region "$REGION" \
    --output json > /tmp/ssm-pm2.json 2>/dev/null || true

  PM2_CMD=$(python3 -c "import json; d=json.load(open('/tmp/ssm-pm2.json')); print(d.get('Command',{}).get('CommandId',''))" 2>/dev/null || echo "")
  if [ -n "$PM2_CMD" ]; then
    sleep 5
    aws ssm get-command-invocation \
      --command-id "$PM2_CMD" \
      --instance-id "$INSTANCE_ID" \
      --region "$REGION" \
      --query 'StandardOutputContent' \
      --output text 2>/dev/null || true
  fi
else
  log_warn "No se encontró instancia en el ASG aún"
fi

# ══════════════════════════════════════════════════
# FASE 7 — Probar endpoints HTTP del ALB
# ══════════════════════════════════════════════════
log_step "Fase 7: Verificar endpoints HTTP del ALB"
hr

ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name "${PROJECT}-${ENV}-compute" \
  --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='AlbDnsName'].OutputValue" \
  --output text 2>/dev/null || echo "")

if [ -z "$ALB_DNS" ]; then
  log_warn "ALB DNS no disponible aún"
else
  log_ok "ALB DNS: $ALB_DNS"
  echo ""
  log_info "Probando endpoint /health..."
  HTTP_CODE=$(curl -s -o /tmp/health_resp.json -w "%{http_code}" \
    --max-time 15 "http://$ALB_DNS/health" 2>/dev/null || echo "000")
  echo "  HTTP Status: $HTTP_CODE"
  if [ "$HTTP_CODE" = "200" ]; then
    log_ok "/health → 200 OK"
    cat /tmp/health_resp.json 2>/dev/null && echo ""
  else
    log_warn "/health → $HTTP_CODE (UserData puede estar aún corriendo)"
  fi

  echo ""
  log_info "Probando GET /api/products..."
  PROD_CODE=$(curl -s -o /tmp/prod_resp.json -w "%{http_code}" \
    --max-time 15 "http://$ALB_DNS/api/products" 2>/dev/null || echo "000")
  echo "  HTTP Status: $PROD_CODE"
  if [ "$PROD_CODE" = "200" ]; then
    log_ok "/api/products → 200 OK"
    python3 -c "
import json, sys
try:
  d = json.load(open('/tmp/prod_resp.json'))
  count = len(d.get('data',{}).get('products',[]))
  print(f'  Productos en catálogo: {count}')
except:
  pass
" 2>/dev/null || true
  else
    log_warn "/api/products → $PROD_CODE"
  fi

  echo ""
  log_info "Probando que /api/auth/profile requiere auth (401)..."
  AUTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time 10 "http://$ALB_DNS/api/auth/profile" 2>/dev/null || echo "000")
  [ "$AUTH_CODE" = "401" ] && log_ok "/api/auth/profile → 401 (JWT requerido — correcto)" \
    || log_warn "/api/auth/profile → $AUTH_CODE (esperado 401)"
fi

# ══════════════════════════════════════════════════
# FASE 8 — Verificar CloudWatch y SNS
# ══════════════════════════════════════════════════
log_step "Fase 8: Verificar CloudWatch, SNS, CloudTrail"
hr

echo -e "${BOLD}--- CloudWatch Alarms ---${NC}"
aws cloudwatch describe-alarms \
  --alarm-name-prefix "${PROJECT}-${ENV}" \
  --region "$REGION" \
  --query 'MetricAlarms[*].{Name:AlarmName,State:StateValue}' \
  --output table 2>/dev/null || log_warn "No se pudieron obtener alarmas"

echo ""
echo -e "${BOLD}--- SNS Topic ---${NC}"
SNS_ARN=$(aws cloudformation describe-stacks \
  --stack-name "${PROJECT}-${ENV}-monitoring" \
  --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='SnsTopicArn'].OutputValue" \
  --output text 2>/dev/null || echo "")
[ -n "$SNS_ARN" ] && log_ok "SNS Topic: $SNS_ARN" || log_warn "SNS Topic no encontrado"

echo ""
echo -e "${BOLD}--- CloudWatch Log Groups ---${NC}"
for LG in "/ecommerce/app" "/ecommerce/system"; do
  COUNT=$(aws logs describe-log-streams \
    --log-group-name "$LG" \
    --region "$REGION" \
    --query 'length(logStreams)' \
    --output text 2>/dev/null || echo "0")
  log_ok "Log group $LG: $COUNT stream(s)"
done

echo ""
echo -e "${BOLD}--- CloudTrail ---${NC}"
CT_ARN=$(aws cloudformation describe-stacks \
  --stack-name "${PROJECT}-${ENV}-monitoring" \
  --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='CloudTrailArn'].OutputValue" \
  --output text 2>/dev/null || echo "")
[ -n "$CT_ARN" ] && log_ok "CloudTrail activo: $CT_ARN" || log_warn "CloudTrail no encontrado"

# ══════════════════════════════════════════════════
# RESUMEN FINAL
# ══════════════════════════════════════════════════
log_step "Resumen Final"
hr

echo ""
echo -e "${GREEN}${BOLD}=============================================="
echo -e "  Deploy Completado"
echo -e "==============================================${NC}"
echo ""
[ -n "$ALB_DNS" ] && echo -e "  ${BOLD}App URL:${NC}      http://$ALB_DNS"
echo -e "  ${BOLD}Admin:${NC}        admin@ecommerce.com / Admin123!"
echo -e "  ${BOLD}Región:${NC}       $REGION"
echo -e "  ${BOLD}Account:${NC}      $ACCOUNT_ID"
echo ""
echo -e "${CYAN}Comandos útiles desde CloudShell:${NC}"
echo ""
echo "  # Healthcheck completo"
echo "  ./scripts/healthcheck.sh http://$ALB_DNS"
echo ""
echo "  # Validar infraestructura"
echo "  ENV=dev PROJECT=ecommerce REGION=$REGION ./scripts/validate-infra.sh"
echo ""
echo "  # Ver logs de UserData via SSM"
echo "  INSTANCE_ID=\$(aws autoscaling describe-auto-scaling-groups \\"
echo "    --auto-scaling-group-names ecommerce-dev-asg \\"
echo "    --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text)"
echo "  aws ssm start-session --target \"\$INSTANCE_ID\""
echo ""
echo "  # Ver logs de app en CloudWatch"
echo "  aws logs tail /ecommerce/app --follow"
echo ""
echo "  # Ver alarmas CloudWatch"
echo "  aws cloudwatch describe-alarms --alarm-name-prefix ecommerce-dev"
echo ""
echo -e "${YELLOW}IMPORTANTE: Confirma la suscripción SNS en tu email.${NC}"
echo ""
