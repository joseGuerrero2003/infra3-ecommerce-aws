# E-Commerce AWS — Spec de Arquitectura
**Fecha:** 2026-05-28  
**Proyecto:** Infra3 — Plataforma E-Commerce Escalable en AWS con IaC  
**Curso:** Infraestructura III — ICESI  
**Autor:** José Guerrero

---

## 1. Objetivo

Desplegar una plataforma e-commerce funcional en AWS usando Infrastructure as Code (CloudFormation), con arquitectura escalable, segura, automatizada y de bajo costo compatible con el entorno AWS Academy Sandbox.

---

## 2. Stack Tecnológico

| Capa | Tecnología |
|---|---|
| Backend | Node.js 20 LTS, Express.js 4.x |
| ORM | Sequelize 6.x |
| Base de datos | PostgreSQL 15 en AWS RDS db.t3.micro |
| Frontend | HTML5, CSS3, JavaScript, jQuery 3.x |
| Proceso manager | PM2 |
| IaC | AWS CloudFormation (YAML) |
| CI/CD | GitHub Actions |
| Monitoreo | CloudWatch, SNS |
| Auditoría | CloudTrail |
| Acceso seguro | SSM Session Manager |

---

## 3. Topología de Red

### VPC
- CIDR: `10.0.0.0/16`
- Region: `us-east-1`
- DNS support: enabled
- DNS hostnames: enabled

### Subnets

| Nombre | CIDR | AZ | Tipo |
|---|---|---|---|
| PublicSubnetA | 10.0.1.0/24 | us-east-1a | Pública |
| PublicSubnetB | 10.0.2.0/24 | us-east-1b | Pública |
| PrivateSubnetA | 10.0.10.0/24 | us-east-1a | Privada |
| PrivateSubnetB | 10.0.20.0/24 | us-east-1b | Privada |

### Routing
- Internet Gateway → Public Route Table (0.0.0.0/0)
- NAT Gateway (single, en PublicSubnetA) → Private Route Table (0.0.0.0/0)
- VPC Flow Logs → CloudWatch Log Group `/vpc/flowlogs`

### Componentes por subnet

| Subnet | Recursos |
|---|---|
| Public A/B | ALB, Bastion Host |
| Public A | NAT Gateway |
| Private A/B | EC2 App (ASG), RDS PostgreSQL |

---

## 4. Security Groups

| SG | Puerto | Protocolo | Fuente | Propósito |
|---|---|---|---|---|
| sg-alb | 80 | TCP | 0.0.0.0/0 | Tráfico HTTP público |
| sg-app | 3000 | TCP | sg-alb | App desde ALB únicamente |
| sg-app | 22 | TCP | sg-bastion | SSH desde Bastion |
| sg-bastion | 22 | TCP | 0.0.0.0/0 | Acceso SSH (parametrizable a IP específica) |
| sg-rds | 5432 | TCP | sg-app | PostgreSQL desde App únicamente |

---

## 5. IAM

EC2 Instance Profile con las siguientes políticas managed:
- `AmazonSSMManagedInstanceCore` — SSM Session Manager
- `CloudWatchAgentServerPolicy` — CloudWatch Agent
- `AmazonSSMReadOnlyAccess` — lectura de SSM Parameter Store

**Nota de compatibilidad con sandbox:** Si el entorno sandbox restringe creación de IAM roles, usar `LabRole` / `LabInstanceProfile` pre-existente del AWS Academy Lab y documentar en deployment guide.

---

## 6. Compute

### EC2 Launch Template
- AMI: Amazon Linux 2023 (via `{{resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64}}`)
- Instance type: `t2.micro`
- Security Group: sg-app
- IAM Instance Profile: EC2InstanceProfile (del stack security)
- UserData: script completo de configuración automática

### Auto Scaling Group
| Parámetro | Valor |
|---|---|
| Min | 1 |
| Max | 3 |
| Desired | 1 |
| Subnets | PrivateSubnetA, PrivateSubnetB |
| Health check | ELB |
| Health check grace period | 300s |
| Scale out | CPU > 60% durante 2 períodos (2 min) |
| Scale in | CPU < 30% durante 5 períodos (5 min) |

### Application Load Balancer
- Scheme: internet-facing
- Subnets: PublicSubnetA, PublicSubnetB
- Security Group: sg-alb
- Target Group: port 3000, protocol HTTP
- Health check path: `/health`
- Health check healthy threshold: 2
- Health check unhealthy threshold: 5
- Health check interval: 30s

### Bastion Host
- Instance type: t2.micro
- Subnet: PublicSubnetA
- Security Group: sg-bastion
- AMI: Amazon Linux 2023

---

## 7. Base de Datos

### RDS PostgreSQL
| Parámetro | Valor |
|---|---|
| Engine | PostgreSQL 15.x |
| Instance class | db.t3.micro |
| Storage | 20 GB gp2 |
| Multi-AZ | No (restricción sandbox) |
| DB Name | ecommerce |
| Subnet Group | PrivateSubnetA, PrivateSubnetB |
| Backup retention | 7 días |
| Auto minor version upgrade | enabled |
| Deletion protection | disabled (sandbox) |

### Esquema de Datos

**users** — autenticación y perfiles
```
id (UUID PK), username (VARCHAR 50 UNIQUE), email (VARCHAR 255 UNIQUE),
password_hash (VARCHAR 255), role (VARCHAR 20 DEFAULT 'customer'),
created_at, updated_at
```

**products** — catálogo
```
id (UUID PK), name (VARCHAR 255), description (TEXT), price (DECIMAL 10,2),
stock (INTEGER), image_url (VARCHAR 500), category (VARCHAR 100),
is_active (BOOLEAN DEFAULT true), created_at, updated_at
```

**carts** — carrito por usuario
```
id (UUID PK), user_id (UUID FK → users), created_at, updated_at
```

**cart_items** — ítems del carrito
```
id (UUID PK), cart_id (UUID FK → carts), product_id (UUID FK → products),
quantity (INTEGER), created_at, updated_at
```

**orders** — órdenes completadas
```
id (UUID PK), user_id (UUID FK → users), total_amount (DECIMAL 10,2),
status (VARCHAR 50), payment_status (VARCHAR 50),
shipping_address (JSONB), created_at, updated_at
```

**order_items** — ítems de órdenes
```
id (UUID PK), order_id (UUID FK → orders), product_id (UUID FK → products),
quantity (INTEGER), unit_price (DECIMAL 10,2), created_at, updated_at
```

---

## 8. API REST

### Auth `/api/auth`
- `POST /register` — crear usuario
- `POST /login` — obtener JWT tokens
- `POST /logout` — invalidar refresh token
- `GET /profile` — perfil del usuario autenticado

### Products `/api/products`
- `GET /` — listar productos (con paginación, filtros)
- `GET /:id` — obtener producto
- `POST /` — crear producto (admin)
- `PUT /:id` — actualizar producto (admin)
- `DELETE /:id` — eliminar producto (admin)

### Cart `/api/cart`
- `GET /` — ver carrito actual
- `POST /items` — agregar ítem
- `PUT /items/:id` — actualizar cantidad
- `DELETE /items/:id` — eliminar ítem
- `DELETE /` — vaciar carrito

### Orders `/api/orders`
- `POST /checkout` — procesar pago simulado + crear orden
- `GET /` — listar órdenes del usuario
- `GET /:id` — detalle de orden

### Health
- `GET /health` — health check para ALB

---

## 9. Seguridad de Aplicación

| Mecanismo | Implementación |
|---|---|
| Autenticación | JWT (access 15min, refresh 7 días) |
| Contraseñas | bcrypt cost factor 10 |
| Headers | Helmet.js |
| CORS | Restringido a origen del ALB |
| Rate limiting | 100 req/15min general; 5 req/15min en /auth |
| Validación | express-validator en todos los endpoints |
| Logs | Winston → CloudWatch Logs |
| SQL injection | Protegido por Sequelize ORM (parameterized queries) |
| XSS | Helmet CSP headers |

---

## 10. CloudFormation — 5 Stacks

### Stack 1: network.yaml
Recursos: VPC, subnets (4), IGW, NAT GW, EIP, route tables (2), subnet associations (8), VPC Flow Logs, CloudWatch Log Group

Outputs: VpcId, PublicSubnetAId, PublicSubnetBId, PrivateSubnetAId, PrivateSubnetBId

### Stack 2: security.yaml
Recursos: SG ALB, SG App, SG Bastion, SG RDS, IAM Role, IAM Instance Profile

Inputs: VpcId (de network stack)  
Outputs: SgAlbId, SgAppId, SgBastionId, SgRdsId, InstanceProfileArn

### Stack 3: database.yaml
Recursos: RDS Subnet Group, RDS Instance, SSM Parameters (endpoint, port)

Inputs: PrivateSubnetAId, PrivateSubnetBId, SgRdsId (de stacks anteriores)  
Outputs: RdsEndpoint, RdsPort, DbName

### Stack 4: compute.yaml
Recursos: Launch Template, ASG, ALB, Target Group, ALB Listener, Bastion EC2, Scale Out/In Policies, CloudWatch Scaling Alarms

Inputs: todos los outputs de stacks 1-3  
Outputs: AlbDnsName, AsgName, AlbArn

### Stack 5: monitoring.yaml
Recursos: SNS Topic, SNS Email Subscription, CloudWatch Alarms (5), CloudTrail, S3 Bucket (trail logs), CloudWatch Log Groups

Inputs: AsgName, AlbArn (de compute stack)  
Outputs: SnsTopicArn

---

## 11. CloudFormation Parameters (compartidos)

| Parámetro | Descripción | Default |
|---|---|---|
| Environment | dev/staging/prod | dev |
| ProjectName | Prefijo para recursos | ecommerce |
| GitHubRepoUrl | URL del repositorio | (requerido) |
| GitHubBranch | Branch a desplegar | main |
| DBUsername | Usuario RDS | dbadmin |
| DBPassword | Password RDS (SecureString) | (requerido) |
| DBName | Nombre de base de datos | ecommerce |
| NotificationEmail | Email para alertas SNS | (requerido) |
| BastionKeyName | Key pair para Bastion | (requerido) |
| AllowedBastionCIDR | CIDR para SSH al Bastion | 0.0.0.0/0 |
| AppPort | Puerto de la aplicación | 3000 |
| NodeEnvironment | NODE_ENV | production |

---

## 12. Automatización

### UserData (EC2 al arrancar)
1. Actualizar sistema (yum update)
2. Instalar Node.js 20 via NodeSource
3. Instalar PM2 globalmente
4. Instalar CloudWatch Agent
5. Clonar repositorio desde GitHubRepoUrl
6. Crear `.env` desde SSM Parameter Store
7. `npm ci --production`
8. `npx sequelize-cli db:migrate`
9. Seeder idempotente: verificar si tabla `products` tiene filas → solo ejecutar `db:seed:all` si está vacía (evita duplicados en reinicios del ASG)
10. `pm2 start ecosystem.config.js`
11. `pm2 startup` + `pm2 save`
12. Iniciar CloudWatch Agent

### Scripts

| Script | Propósito |
|---|---|
| `scripts/master-deploy.sh` | Despliega los 5 stacks en orden con validación entre pasos |
| `scripts/setup.sh` | Configuración inicial de instancia (llamado por UserData) |
| `scripts/deploy.sh` | Actualización de código en instancias existentes |
| `scripts/healthcheck.sh` | Validación del estado de la aplicación |
| `scripts/validate-infra.sh` | Verificación de recursos AWS post-deploy |
| `scripts/init-db.sh` | Inicialización manual de BD si UserData falla |
| `scripts/destroy.sh` | Eliminación de stacks en orden inverso |

---

## 13. PM2 — ecosystem.config.js

```js
apps: [{
  name: 'ecommerce',
  script: 'server.js',
  instances: 'max',       // usa todos los CPUs disponibles
  exec_mode: 'cluster',
  watch: false,
  env_production: {
    NODE_ENV: 'production',
    PORT: 3000
  },
  error_file: '/var/log/pm2/error.log',
  out_file: '/var/log/pm2/out.log',
  log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
}]
```

---

## 14. CI/CD — GitHub Actions

### validate.yml (on: PR)
1. Checkout código
2. `npm ci`
3. `npm test`
4. `cfn-lint` en todos los templates
5. `aws cloudformation validate-template` para cada YAML

### deploy.yml (on: push to main)
1. Validate job (anterior)
2. Deploy compute stack update (rolling update via ASG)

---

## 15. Monitoreo

| Alarma | Métrica | Threshold | Acción |
|---|---|---|---|
| HighCPUAlarm | EC2 CPUUtilization | > 60% (2 períodos) | Scale out + SNS |
| LowCPUAlarm | EC2 CPUUtilization | < 30% (5 períodos) | Scale in |
| ALB5xxAlarm | HTTPCode_ELB_5XX_Count | > 10/min | SNS |
| RDSHighCPU | RDS CPUUtilization | > 80% | SNS |
| ALBResponseTime | TargetResponseTime | > 1s | SNS |

- CloudTrail: trail us-east-1, S3 bucket `{ProjectName}-cloudtrail-logs-{AccountId}`, log file validation ON
- CloudWatch Log Groups: `/ecommerce/app`, `/ecommerce/system`, `/vpc/flowlogs`

---

## 16. Frontend — Estructura

Servido como estáticos desde Express (`express.static('public')`).

Páginas HTML:
- `index.html` — catálogo de productos con búsqueda y filtros
- `login.html` — formulario de login
- `register.html` — registro de usuario
- `cart.html` — carrito de compras con totales
- `checkout.html` — dirección + pago simulado
- `order-confirmation.html` — confirmación de pedido
- `admin.html` — administración de productos

JavaScript modular:
- `api.js` — cliente HTTP centralizado con JWT headers
- `auth.js` — login/registro/logout
- `products.js` — catálogo, filtros, detalle
- `cart.js` — carrito, cantidades, totales
- `checkout.js` — formulario de pago simulado

---

## 17. Restricciones del Sandbox — Mitigaciones

| Restricción | Mitigación |
|---|---|
| Máx 9 instancias | ASG max 3, 1 Bastion = 4 total. Margen amplio. |
| RDS sin Multi-AZ | Single-AZ, db.t3.micro. Documentado. |
| IAM read-only posible | IAM role creado vía CloudFormation con CAPABILITY_IAM. Fallback a LabRole documentado. |
| No Route53 dominios | Se usa DNS del ALB directamente. |
| SSM read-only | Todos los params como outputs de CloudFormation, no solo SSM. |

---

## 18. Flujo de Despliegue (Paso a Paso)

```bash
# Prerrequisitos
1. aws configure (credenciales del sandbox)
2. Crear key pair en AWS Console → guardar .pem
3. Configurar parámetros en cloudformation/parameters/dev.json

# Deploy infraestructura (1 comando)
./scripts/master-deploy.sh --env dev --params cloudformation/parameters/dev.json

# El script hace:
# 1. Deploy network.yaml
# 2. Deploy security.yaml (importa network outputs)
# 3. Deploy database.yaml (importa network + security outputs)
# 4. Deploy compute.yaml (importa todo) → EC2 se auto-configura via UserData
# 5. Deploy monitoring.yaml (importa compute outputs)
# 6. Imprime ALB DNS Name para acceder a la app

# Verificación
./scripts/validate-infra.sh
./scripts/healthcheck.sh --alb-url <ALB_DNS>
```

---

## 19. Estructura de Archivos

```
/project
  /backend
    /src
      /config         database.js, app.js
      /controllers    auth, product, cart, order
      /models         index.js + 6 modelos
      /routes         index.js + 4 routers
      /middleware     auth, validate, error, rateLimiter
      /utils          logger.js, responseHelper.js, jwt.utils.js
    /migrations       001-006 (usuarios, productos, carts, etc.)
    /seeders          001-admin-user, 002-products (20 productos demo)
    server.js
    package.json
    ecosystem.config.js
    .sequelizerc
    .env.example
  /frontend
    /public
      index.html
      /css            styles.css
      /js             api.js, auth.js, products.js, cart.js, checkout.js
      /pages          login, register, cart, checkout, confirmation, admin
  /cloudformation
    network.yaml
    security.yaml
    database.yaml
    compute.yaml
    monitoring.yaml
    /parameters       dev.json
  /scripts
    master-deploy.sh
    setup.sh
    deploy.sh
    userdata.sh
    healthcheck.sh
    validate-infra.sh
    init-db.sh
    destroy.sh
  /.github
    /workflows
      validate.yml
      deploy.yml
  /docs
    README.md
    deployment-guide.md
    architecture.md
    api-reference.md
    troubleshooting.md
  /presentation
    architecture-overview.md
    slides-content.md
```

---

## 20. Testing

- Framework: Jest + Supertest
- Cobertura mínima: auth endpoints, product endpoints, cart endpoints, health check
- Test de integración: conexión RDS vía Sequelize
- Validación CloudFormation: `cfn-lint` en CI

---

*Spec validado y listo para implementación.*
