# TechShop — E-Commerce en AWS
## Infraestructura III — ICESI 2026

---

## Slide 1: Introducción

**Objetivo:** Desplegar una plataforma de comercio electrónico escalable, segura y automatizada en AWS utilizando Infrastructure as Code.

**Problema que resuelve:**
- Un equipo de desarrollo necesita lanzar su primer producto en la nube
- Sin experiencia previa en infraestructura cloud
- Necesitan escalabilidad automática, alta disponibilidad y bajo costo

---

## Slide 2: Arquitectura General

```
Internet → ALB (público) → EC2 Auto Scaling (privado) → RDS PostgreSQL (privado)
                ↓
           CloudWatch + SNS + CloudTrail
```

**Componentes clave:**
- VPC privada con subnets públicas y privadas en 2 AZs
- Application Load Balancer distribuye tráfico
- Auto Scaling Group: 1-3 instancias t2.micro según demanda
- RDS PostgreSQL db.t3.micro en subnet privada
- Bastion Host para administración segura
- SSM Session Manager (sin necesidad de SSH público)

---

## Slide 3: CloudFormation — 5 Stacks Modulares

| Stack | Recursos | Propósito |
|---|---|---|
| network.yaml | VPC, Subnets, IGW, NAT, Routes | Red |
| security.yaml | Security Groups, IAM Role/Profile | Seguridad |
| database.yaml | RDS Subnet Group, RDS Instance, SSM Params | Persistencia |
| compute.yaml | Launch Template, ASG, ALB, TG, Bastion | Cómputo |
| monitoring.yaml | CloudWatch, SNS, CloudTrail | Observabilidad |

**Beneficios:**
- Deploy reproducible en 1 comando
- Modular: actualizar solo lo que cambia
- Cross-stack references via `Fn::ImportValue`
- Versionado en Git

---

## Slide 4: Auto Scaling

**Configuración:**
- Min: 1 instancia | Max: 3 instancias | Desired: 1
- Health check: ELB (usa el /health endpoint de la app)
- Grace period: 300 segundos (tiempo para que la app inicie)

**Política de escalado:**
- Scale Out: CPU > 60% por 2 minutos → +1 instancia
- Scale In: CPU < 30% por 5 minutos → -1 instancia

**Restricción sandbox:** Máximo 9 instancias totales → ASG max 3 + 1 Bastion = 4 total.

---

## Slide 5: Seguridad

**Capas de seguridad:**
1. **Red:** Instancias app en subnet privada — solo accesibles desde el ALB
2. **Security Groups:** Principio de mínimos permisos (sg-alb → sg-app → sg-rds)
3. **IAM:** EC2 Instance Role con solo las políticas necesarias (SSM + CloudWatch)
4. **Aplicación:** JWT, bcrypt, Helmet, rate limiting, express-validator
5. **SSM Session Manager:** Acceso a instancias sin SSH público expuesto
6. **CloudTrail:** Auditoría de todas las acciones en la cuenta

---

## Slide 6: Stack de la Aplicación

**Backend (Node.js + Express):**
- Arquitectura MVC modular
- API REST con 15+ endpoints
- JWT authentication (access 15min + refresh 7d)
- Sequelize ORM con migraciones y seeders
- PM2 en modo cluster (aprovecha todos los vCPUs)
- Logs estructurados con Winston → CloudWatch

**Frontend (HTML/CSS/JS):**
- Sin frameworks pesados — vanilla JS + jQuery
- Servido como estáticos por Express
- Responsive design

---

## Slide 7: Base de Datos

**Schema:**
```
users ──(1:1)── carts ──(1:N)── cart_items ──(N:1)── products
users ──(1:N)── orders ──(1:N)── order_items ──(N:1)── products
```

**Elecciones técnicas:**
- PostgreSQL 15 — robustez, JSONB para shipping_address
- Sequelize ORM — previene SQL injection, migraciones versionadas
- db.t3.micro, Single-AZ — optimización de costo para sandbox
- Backups automáticos 7 días de retención

---

## Slide 8: Monitoreo y Observabilidad

**CloudWatch Alarms configuradas:**
- CPU alta en EC2 → trigger scale out
- CPU baja en EC2 → trigger scale in
- Error 5XX en ALB > 10/min → alerta
- CPU alta en RDS > 80% → alerta
- Latencia ALB > 1s → alerta

**CloudTrail:** Auditoría completa de acciones en la cuenta AWS

**Logs:** Aplicación → CloudWatch Logs via CloudWatch Agent

---

## Slide 9: CI/CD Pipeline

```
Push to main branch
    ↓
validate.yml: npm test + cfn-lint
    ↓ (si pasan)
deploy.yml: aws cloudformation deploy (compute stack)
    ↓
Instance Refresh (rolling update, 0 downtime)
    ↓
Verify: curl /health → 200 OK
```

**GitHub Secrets:** Credenciales AWS, passwords de BD y JWT almacenados seguros.

---

## Slide 10: Automatización

**UserData (EC2 boot):**
1. Instala Node.js 20, PM2, CloudWatch Agent
2. Clona repositorio desde GitHub
3. Genera `.env` con valores de CloudFormation
4. Ejecuta migraciones (idempotente)
5. Seed solo si BD está vacía
6. Inicia app con PM2 en modo cluster
7. Configura startup automático

**Resultado:** Una EC2 nueva se auto-configura completamente sin intervención manual.

---

## Slide 11: Costos Estimados (Sandbox)

| Recurso | Tipo | Costo/hora |
|---|---|---|
| EC2 App (1 instancia) | t2.micro | ~$0.012 |
| RDS PostgreSQL | db.t3.micro | ~$0.017 |
| ALB | Application LB | ~$0.008 |
| NAT Gateway | — | ~$0.045 |
| Bastion | t2.micro | ~$0.012 |
| **Total estimado** | | **~$0.09/hora** |

> El sandbox de AWS Academy tiene límite de tiempo de sesión. Recursos se limpian al terminar la sesión.

---

## Slide 12: Lecciones Aprendidas

1. **IAM en sandbox:** La restricción de IAM read-only requiere usar `CAPABILITY_NAMED_IAM` y verificar si el sandbox permite crear roles vía CloudFormation. Tener `LabRole` como fallback.

2. **UserData es asíncrono:** La instancia arranca y el health check del ALB puede fallar mientras UserData se ejecuta. El `HealthCheckGracePeriod` de 300s es crítico.

3. **Idempotencia en scripts:** Los seeders deben verificar si los datos ya existen para no duplicar en restarts del ASG.

4. **NAT Gateway costo:** En producción real, considerar VPC Endpoints para SSM y S3 para evitar el costo del NAT.

5. **RDS timing:** RDS tarda ~10 minutos en aprovisionarse. El `wait stack-create-complete` es esencial en el deploy script.

6. **Cross-stack exports:** Deben ser únicos en la región. Usar `ProjectName-Environment-ResourceName` como naming convention.
