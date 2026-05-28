# TechShop — E-Commerce Platform on AWS

Proyecto final de Infraestructura III — ICESI. Plataforma de comercio electrónico desplegada en AWS con Infrastructure as Code (CloudFormation), Auto Scaling, RDS PostgreSQL, Application Load Balancer y monitoreo completo.

## Arquitectura

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────┐
│                  VPC (10.0.0.0/16)              │
│                                                  │
│  Public Subnets (10.0.1.0/24, 10.0.2.0/24)    │
│  ┌──────────────┐   ┌─────────────┐             │
│  │   ALB        │   │   Bastion   │             │
│  │ (internet-   │   │   Host      │             │
│  │  facing)     │   │ (t2.micro)  │             │
│  └──────┬───────┘   └─────────────┘             │
│         │             NAT Gateway                │
│  Private Subnets (10.0.10.0/24, 10.0.20.0/24) │
│  ┌──────▼─────────────────────────────────────┐ │
│  │         Auto Scaling Group (1-3)           │ │
│  │   EC2 t2.micro   EC2 t2.micro              │ │
│  │   Node.js/PM2    Node.js/PM2               │ │
│  └──────────────────────┬───────────────────  ┘ │
│                         │                        │
│  ┌──────────────────────▼───────────────────┐   │
│  │   RDS PostgreSQL (db.t3.micro)           │   │
│  │   Single-AZ, Private Subnets             │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
         │
    CloudWatch + SNS + CloudTrail
```

## Stack Tecnológico

| Componente | Tecnología |
|---|---|
| Backend | Node.js 20, Express.js 4.x |
| ORM | Sequelize 6.x |
| Base de datos | PostgreSQL 15 en AWS RDS db.t3.micro |
| Frontend | HTML5, CSS3, JavaScript vanilla + jQuery CDN |
| Proceso manager | PM2 (cluster mode) |
| IaC | AWS CloudFormation (5 stacks modulares) |
| CI/CD | GitHub Actions |
| Monitoreo | CloudWatch Alarms + SNS + CloudTrail |

## Prerrequisitos

- AWS CLI configurado con credenciales del Sandbox
- `jq` instalado (`brew install jq` o `sudo yum install -y jq`)
- Git
- Node.js 20+ (para desarrollo local)

## Deploy Rápido

### 1. Preparar parámetros

```bash
# Copiar y editar el archivo de parámetros
cp cloudformation/parameters/dev.json cloudformation/parameters/my-dev.json
```

Editar `my-dev.json` con tus valores:
- `GitHubRepoUrl` → URL de tu repositorio
- `BastionKeyName` → Nombre del key pair en AWS (usualmente `vockey` en sandbox)
- `DBPassword` → Contraseña fuerte para RDS
- `JwtSecret` → String aleatorio >= 32 caracteres
- `JwtRefreshSecret` → Otro string aleatorio >= 32 caracteres
- `NotificationEmail` → Tu email para alertas SNS

### 2. Desplegar infraestructura (1 comando)

```bash
chmod +x scripts/master-deploy.sh
./scripts/master-deploy.sh --env dev --params cloudformation/parameters/my-dev.json
```

El script despliega en orden:
1. `network.yaml` → VPC, subnets, IGW, NAT Gateway
2. `security.yaml` → Security Groups, IAM Role
3. `database.yaml` → RDS PostgreSQL
4. `compute.yaml` → Launch Template, ASG, ALB, Bastion
5. `monitoring.yaml` → CloudWatch Alarms, SNS, CloudTrail

**Tiempo estimado:** 15-25 minutos (RDS toma ~10 min)

### 3. Verificar deployment

```bash
# Validar recursos AWS
ENV=dev PROJECT=ecommerce REGION=us-east-1 ./scripts/validate-infra.sh

# Health check de la aplicación
./scripts/healthcheck.sh http://<ALB-DNS-NAME>
```

### 4. Acceder a la aplicación

El script imprime la URL del ALB al finalizar:
```
Application URL: http://ecommerce-dev-alb-XXXXXXXX.us-east-1.elb.amazonaws.com
```

**Credenciales admin por defecto:**
- Email: `admin@ecommerce.com`
- Password: `Admin123!`

### 5. Confirmar suscripción SNS

Revisa tu email y confirma la suscripción de SNS para recibir alertas.

## Estructura del Proyecto

```
/
├── backend/                    # Node.js + Express API
│   ├── src/
│   │   ├── config/            # app.js, database.js
│   │   ├── controllers/       # auth, product, cart, order
│   │   ├── models/            # Sequelize models
│   │   ├── routes/            # Express routers
│   │   ├── middleware/        # auth, validate, error, rateLimit
│   │   └── utils/             # logger, responseHelper, jwt
│   ├── migrations/            # 6 migraciones Sequelize
│   ├── seeders/               # datos iniciales
│   ├── tests/                 # Jest + Supertest
│   ├── server.js
│   ├── ecosystem.config.js    # PM2 config
│   └── .env.example
├── frontend/
│   └── public/                # HTML/CSS/JS estáticos
│       ├── index.html         # catálogo de productos
│       ├── css/styles.css
│       ├── js/                # api.js, auth.js, products.js, cart.js, checkout.js
│       └── pages/             # login, register, cart, checkout, confirmation, admin
├── cloudformation/
│   ├── network.yaml           # VPC, subnets, routing
│   ├── security.yaml          # Security Groups, IAM
│   ├── database.yaml          # RDS PostgreSQL
│   ├── compute.yaml           # ALB, ASG, EC2, Bastion
│   ├── monitoring.yaml        # CloudWatch, SNS, CloudTrail
│   └── parameters/dev.json
├── scripts/
│   ├── master-deploy.sh       # deploy orquestado
│   ├── setup.sh               # configuración inicial EC2
│   ├── deploy.sh              # actualización de código
│   ├── healthcheck.sh         # validación de salud
│   ├── validate-infra.sh      # validación de infraestructura
│   └── destroy.sh             # eliminación de stacks
├── .github/workflows/
│   ├── validate.yml           # tests + cfn-lint en PRs
│   └── deploy.yml             # deploy automático en push a main
└── docs/
    ├── README.md
    ├── deployment-guide.md
    ├── api-reference.md
    └── troubleshooting.md
```

## Desarrollo Local

```bash
# 1. Levantar PostgreSQL local
docker run -d --name pg -e POSTGRES_USER=dbadmin -e POSTGRES_PASSWORD=changeme \
  -e POSTGRES_DB=ecommerce -p 5432:5432 postgres:15

# 2. Configurar variables de entorno
cd backend
cp .env.example .env
# Editar .env con DB_HOST=localhost

# 3. Instalar dependencias y migrar
npm install
npm run migrate
npm run seed

# 4. Iniciar servidor
npm run dev

# 5. Tests
npm test
```

## API Endpoints

Ver [api-reference.md](api-reference.md) para la documentación completa.

## Monitoreo

| Alarma | Trigger | Acción |
|---|---|---|
| HighCPU | CPU > 60% (2 periodos) | Scale out + SNS email |
| LowCPU | CPU < 30% (5 periodos) | Scale in |
| ALB5xx | 5XX > 10/min | SNS email |
| RDSHighCPU | RDS CPU > 80% | SNS email |
| ALBLatency | Response time > 1s | SNS email |

## Limitaciones del Sandbox

| Restricción | Configuración aplicada |
|---|---|
| Máx 9 instancias | ASG max=3, 1 Bastion = 4 total |
| RDS sin Multi-AZ | Single-AZ con db.t3.micro |
| IAM limitado | `CAPABILITY_NAMED_IAM` en deploy |
| Sin Route53 | Usar DNS del ALB directamente |

## Troubleshooting

Ver [troubleshooting.md](troubleshooting.md)
