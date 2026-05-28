# Deployment Guide — Paso a Paso

## Requisitos Previos

### 1. Configurar AWS CLI con credenciales del Sandbox

```bash
aws configure
# AWS Access Key ID: [de AWS Academy Learner Lab]
# AWS Secret Access Key: [de AWS Academy Learner Lab]
# Default region name: us-east-1
# Default output format: json
```

O exportar las variables del Sandbox:
```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
```

Verificar:
```bash
aws sts get-caller-identity
```

### 2. Crear Key Pair en AWS Console (si no existe)

AWS Academy Sandbox usualmente provee el key pair `vockey`.
- Ir a EC2 → Key Pairs → verificar que `vockey` existe
- Si no existe, crear uno y descargar el `.pem`

### 3. Crear repositorio GitHub y subir el código

```bash
# Inicializar git en el proyecto
cd /path/to/infra3-project
git init
git add .
git commit -m "feat: initial project setup"
git branch -M main

# Crear repo en GitHub (via web o CLI)
gh repo create infra3-ecommerce --public
git remote add origin https://github.com/YOUR_USER/infra3-ecommerce.git
git push -u origin main
```

### 4. Editar parámetros

```bash
cp cloudformation/parameters/dev.json cloudformation/parameters/my-dev.json
```

Editar los valores requeridos en `my-dev.json`:

| Parámetro | Valor requerido |
|---|---|
| `GitHubRepoUrl` | `https://github.com/YOUR_USER/infra3-ecommerce.git` |
| `BastionKeyName` | `vockey` (o nombre de tu key pair) |
| `DBPassword` | Mínimo 8 chars, ej: `MyP@ss123!` |
| `JwtSecret` | String random ≥ 32 chars |
| `JwtRefreshSecret` | Otro string random ≥ 32 chars |
| `NotificationEmail` | Tu email |

### 5. Instalar jq (si no está instalado)

```bash
# macOS
brew install jq

# Amazon Linux / RHEL
sudo yum install -y jq

# Ubuntu/Debian
sudo apt-get install -y jq
```

---

## Deploy Completo

### Paso 1: Dar permisos de ejecución a los scripts

```bash
chmod +x scripts/*.sh
```

### Paso 2: Desplegar los 5 stacks

```bash
./scripts/master-deploy.sh \
  --env dev \
  --project ecommerce \
  --params cloudformation/parameters/my-dev.json \
  --region us-east-1
```

**Progreso esperado:**
```
[INFO] Deploying stack: ecommerce-dev-network      (~2 min)
[OK]   Stack deployed: ecommerce-dev-network
[INFO] Deploying stack: ecommerce-dev-security     (~1 min)
[OK]   Stack deployed: ecommerce-dev-security
[INFO] Deploying stack: ecommerce-dev-database     (~10 min)
[OK]   Stack deployed: ecommerce-dev-database
[INFO] Deploying stack: ecommerce-dev-compute      (~5 min)
[OK]   Stack deployed: ecommerce-dev-compute
[INFO] Deploying stack: ecommerce-dev-monitoring   (~2 min)
[OK]   Stack deployed: ecommerce-dev-monitoring

Application URL: http://ecommerce-dev-alb-XXXXXXXX.us-east-1.elb.amazonaws.com
Bastion Host IP: X.X.X.X
```

### Paso 3: Confirmar suscripción SNS

Revisar email y hacer clic en **Confirm subscription**.

### Paso 4: Verificar infraestructura

```bash
ENV=dev PROJECT=ecommerce REGION=us-east-1 ./scripts/validate-infra.sh
```

### Paso 5: Verificar aplicación

```bash
./scripts/healthcheck.sh http://ecommerce-dev-alb-XXXXXXXX.us-east-1.elb.amazonaws.com
```

Abrir en browser: `http://ecommerce-dev-alb-XXXXXXXX.us-east-1.elb.amazonaws.com`

---

## Deploy Parcial (actualizar solo un stack)

```bash
# Solo actualizar compute (nueva versión de la app)
./scripts/master-deploy.sh --env dev --params cloudformation/parameters/my-dev.json --skip-to compute
```

---

## Deploy Individual por Stack

```bash
# Solo network
aws cloudformation deploy \
  --stack-name ecommerce-dev-network \
  --template-file cloudformation/network.yaml \
  --parameter-overrides Environment=dev ProjectName=ecommerce \
  --region us-east-1

# Solo security
aws cloudformation deploy \
  --stack-name ecommerce-dev-security \
  --template-file cloudformation/security.yaml \
  --parameter-overrides Environment=dev ProjectName=ecommerce \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

---

## Acceder a EC2 via SSM (sin SSH)

```bash
# Obtener ID de una instancia
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ecommerce-dev-asg \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
  --output text)

# Abrir sesión SSM
aws ssm start-session --target "$INSTANCE_ID" --region us-east-1
```

---

## Acceder via Bastion SSH

```bash
# Obtener IP del Bastion
BASTION_IP=$(aws cloudformation describe-stacks \
  --stack-name ecommerce-dev-compute \
  --query 'Stacks[0].Outputs[?OutputKey==`BastionPublicIp`].OutputValue' \
  --output text)

# Conectar al Bastion
chmod 400 vockey.pem
ssh -i vockey.pem ec2-user@$BASTION_IP

# Desde el Bastion, conectar a una instancia privada
PRIVATE_IP=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ecommerce-dev-asg \
  --query 'AutoScalingGroups[0].Instances[0].PrivateIpAddress' \
  --output text)

ssh -i vockey.pem ec2-user@$PRIVATE_IP
```

---

## Actualizar Código

```bash
# Desde una instancia EC2 (via SSM o Bastion)
cd /app/ecommerce
BRANCH=main ./scripts/deploy.sh
```

---

## Destruir Infraestructura

```bash
ENV=dev PROJECT=ecommerce REGION=us-east-1 ./scripts/destroy.sh
```

---

## GitHub Actions Secrets (para CI/CD)

Configurar en GitHub → Settings → Secrets:

| Secret | Descripción |
|---|---|
| `AWS_ACCESS_KEY_ID` | Credencial AWS |
| `AWS_SECRET_ACCESS_KEY` | Credencial AWS |
| `AWS_SESSION_TOKEN` | Token de sesión (sandbox) |
| `GITHUB_REPO_URL` | URL del repo |
| `BASTION_KEY_NAME` | Nombre del key pair |
| `DB_USERNAME` | Usuario RDS |
| `DB_PASSWORD` | Password RDS |
| `JWT_SECRET` | JWT secret |
| `JWT_REFRESH_SECRET` | JWT refresh secret |
