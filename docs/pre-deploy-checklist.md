# Pre-Deploy Checklist — ECommerce AWS

Generado después de validación técnica exhaustiva. Todos los checks pasaron.

---

## Bug Corregido en Esta Sesión

| Bug | Archivo | Impacto | Estado |
|---|---|---|---|
| `sequelize-cli` en `devDependencies` → falla `npm ci --production` | `backend/package.json` | CRÍTICO — migraciones no corren en producción | CORREGIDO |
| `static` path relativo al CWD → frontend 404 | `backend/src/config/app.js` | ALTO — sitio no carga | CORREGIDO |
| PM2 `cwd` incorrecto (`/app/ecommerce` vs `/app/ecommerce/backend`) | `backend/ecosystem.config.js` | ALTO — app no inicia | CORREGIDO |
| `CartItem` no importado en test | `backend/tests/auth.test.js` | BAJO — test cleanup incompleto | CORREGIDO |
| `!ImportValue` dentro de `!Sub` (syntax inválida) | `cloudformation/compute.yaml` | CRÍTICO — deploy falla | CORREGIDO (SSM runtime) |

---

## PASO 0: Prerrequisitos (verificar antes de empezar)

- [ ] AWS CLI instalado (`aws --version`)
- [ ] jq instalado (`jq --version`)
- [ ] git instalado (`git --version`)
- [ ] Credenciales AWS Academy activas (`aws sts get-caller-identity`)
- [ ] Key pair `vockey` existe en AWS Console → EC2 → Key Pairs
- [ ] Repositorio GitHub creado y código subido

---

## PASO 1: Subir código a GitHub

```bash
cd c:/Users/joseg/Documents/Infra3

git init
git add .
git commit -m "feat: initial ecommerce aws project"
git branch -M main

# Crear repo en GitHub, luego:
git remote add origin https://github.com/TU_USUARIO/infra3-ecommerce.git
git push -u origin main
```

Verificar: `git log --oneline` muestra el commit, `git remote -v` muestra la URL.

---

## PASO 2: Configurar parámetros de deploy

```bash
cp cloudformation/parameters/dev.json cloudformation/parameters/my-dev.json
```

Editar `cloudformation/parameters/my-dev.json` con estos valores:

| Parámetro | Valor requerido | Ejemplo |
|---|---|---|
| `GitHubRepoUrl` | URL del repo | `https://github.com/TU_USER/infra3-ecommerce.git` |
| `BastionKeyName` | `vockey` | `vockey` |
| `DBPassword` | >= 8 chars, alfanumérico | `MyPass123!` |
| `JwtSecret` | >= 32 chars aleatorio | `abcdef1234567890abcdef1234567890ab` |
| `JwtRefreshSecret` | >= 32 chars diferente | `xyz0987654321xyz0987654321xyz0987` |
| `NotificationEmail` | Tu email | `tu@email.com` |

Los demás valores pueden dejarse con sus defaults.

---

## PASO 3: Dar permisos de ejecución a scripts

```bash
chmod +x scripts/*.sh
```

---

## PASO 4: Deploy de infraestructura (15-25 minutos)

```bash
./scripts/master-deploy.sh \
  --env dev \
  --project ecommerce \
  --params cloudformation/parameters/my-dev.json \
  --region us-east-1
```

**Tiempos esperados por stack:**
- `network` → ~2 min
- `security` → ~1 min
- `database` → ~10-12 min (RDS provisioning)
- `compute` → ~5 min (incluye EC2 bootstrap vía UserData)
- `monitoring` → ~2 min

**Al finalizar verás:**
```
Application URL:  http://ecommerce-dev-alb-XXXXXXXX.us-east-1.elb.amazonaws.com
Bastion Host IP:  X.X.X.X
```

---

## PASO 5: Confirmar suscripción SNS

Revisar inbox del email configurado en `NotificationEmail` y hacer clic en **Confirm subscription**.

---

## PASO 6: Esperar bootstrap de EC2 (5-10 min extra)

El UserData de EC2 se ejecuta en background. Esperar ~5-10 minutos después que el stack de compute termine antes de verificar.

---

## PASO 7: Verificar infraestructura

```bash
ENV=dev PROJECT=ecommerce REGION=us-east-1 ./scripts/validate-infra.sh
```

**Salida esperada:**
```
[PASS] Stack ecommerce-dev-network is CREATE_COMPLETE
[PASS] Stack ecommerce-dev-security is CREATE_COMPLETE
[PASS] Stack ecommerce-dev-database is CREATE_COMPLETE
[PASS] Stack ecommerce-dev-compute is CREATE_COMPLETE
[PASS] Stack ecommerce-dev-monitoring is CREATE_COMPLETE
[PASS] VPC exists
[PASS] ALB DNS reachable
[PASS] ASG has at least 1 healthy instance
[PASS] RDS instance is available
[PASS] SNS topic exists
```

---

## PASO 8: Verificar aplicación

```bash
ALB_URL=http://ecommerce-dev-alb-XXXXXXXX.us-east-1.elb.amazonaws.com
./scripts/healthcheck.sh $ALB_URL
```

**Salida esperada:**
```
[PASS] Health endpoint responds 200
[PASS] Health returns JSON with 'healthy'
[PASS] Products API returns 200
[PASS] 401 returned for protected route without auth
Results: 4 passed, 0 failed
```

---

## PASO 9: Verificar aplicación en browser

1. Abrir: `http://ecommerce-dev-alb-XXXXXXXX.us-east-1.elb.amazonaws.com`
2. Verificar catálogo de 20 productos cargado
3. Crear cuenta nueva: Register → usar email/password válidos
4. Login con admin: `admin@ecommerce.com` / `Admin123!`
5. Acceder a admin panel: `/pages/admin.html`
6. Agregar producto al carrito → ir a cart → hacer checkout

---

## Comandos de Diagnóstico

### Ver estado de UserData en EC2

```bash
# Obtener ID de instancia
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ecommerce-dev-asg \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
  --output text --region us-east-1)

# Conectar via SSM
aws ssm start-session --target "$INSTANCE_ID" --region us-east-1

# Una vez conectado, ver logs:
sudo tail -100 /var/log/userdata.log
sudo pm2 status
sudo pm2 logs ecommerce --lines 50
```

### Ver logs de la aplicación en CloudWatch

```bash
aws logs get-log-events \
  --log-group-name /ecommerce/app \
  --log-stream-name <instance-id>/out \
  --region us-east-1 \
  --limit 50
```

### Verificar que migraciones corrieron

```bash
# En la instancia via SSM:
cd /app/ecommerce/backend
npx sequelize-cli db:migrate:status --env production
```

### Ver health check del ALB

```bash
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names ecommerce-dev-tg --query 'TargetGroups[0].TargetGroupArn' \
    --output text --region us-east-1) \
  --region us-east-1
```

---

## Troubleshooting Rápido

| Síntoma | Causa más probable | Solución |
|---|---|---|
| ALB devuelve 502 | EC2 no healthy, UserData falló | `sudo tail /var/log/userdata.log` via SSM |
| `db:migrate` falla | RDS no accesible o UserData corrió antes que RDS esté listo | `./scripts/init-db.sh` manualmente via SSM |
| EC2 sin acceso SSM | IAM role no tiene SSM policy (sandbox IAM restriction) | Usar LabRole: ver troubleshooting.md |
| Stack `security` falla con `InsufficientCapabilities` | Falta `CAPABILITY_NAMED_IAM` | master-deploy.sh ya lo incluye; verificar que se ejecutó con ese script |
| Stack `compute` falla con `Invalid parameter` | dev.json tiene valores placeholder sin cambiar | Editar `my-dev.json` con valores reales |
| `CHANGE_ME` en parámetros | Olvidó editar my-dev.json | Editar parámetros y re-deploy del stack afectado |
| Seeder no corrió (0 productos) | Primera instancia corrió con error; ASG lanzó nueva | `npx sequelize-cli db:seed:all --env production` via SSM |

---

## Post-Deploy Validation Checklist

- [ ] `validate-infra.sh` → todos PASS
- [ ] `healthcheck.sh` → todos PASS  
- [ ] Browser → catálogo muestra 20 productos
- [ ] Register → funciona sin errores
- [ ] Login → funciona, JWT en localStorage
- [ ] Add to cart → carrito actualizado
- [ ] Checkout → orden creada, transaction_id visible
- [ ] Admin login → panel de admin accesible
- [ ] CloudWatch → log groups `/ecommerce/app` y `/ecommerce/system` con datos
- [ ] SNS → email confirmado, alarmas visibles en CloudWatch console
- [ ] CloudTrail → trail activo en us-east-1

---

## Limpieza

Cuando termines el proyecto o se acaben las credenciales del sandbox:

```bash
ENV=dev PROJECT=ecommerce REGION=us-east-1 ./scripts/destroy.sh
```

**ATENCIÓN:** Esto elimina TODOS los recursos y datos. Irreversible.
