# Troubleshooting Guide

## CloudFormation Issues

### "Export not found" error
**Causa:** Se está intentando desplegar un stack que importa exports de otro stack que no existe aún.
**Solución:** Desplegar en orden: network → security → database → compute → monitoring.
```bash
./scripts/master-deploy.sh --env dev --skip-to network
```

### IAM - Insufficient permissions
**Causa:** El entorno sandbox tiene IAM read-only.
**Solución:** Usar `LabRole` pre-existente. En `security.yaml`, sustituir `EC2Role` y `EC2InstanceProfile` por:
```yaml
# En compute.yaml, reemplazar la referencia al InstanceProfile por:
IamInstanceProfile:
  Arn: arn:aws:iam::ACCOUNT_ID:instance-profile/LabInstanceProfile
```

### RDS creation timeout
**Causa:** RDS puede tardar 10-15 min en `CREATE_COMPLETE`.
**Solución:** Esperar. El `master-deploy.sh` usa `wait stack-create-complete` automáticamente.

### "CloudTrail bucket already exists"
**Causa:** Bucket S3 de CloudTrail ya existe de un deploy anterior.
**Solución:** El nombre del bucket incluye el `AccountId` para ser único. Si falla, verificar:
```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3 ls | grep "ecommerce-dev-cloudtrail-$ACCOUNT_ID"
```

---

## Aplicación

### EC2 no aparece healthy en el Target Group

1. Revisar UserData logs:
```bash
# Via SSM
aws ssm start-session --target INSTANCE_ID
sudo tail -200 /var/log/userdata.log
```

2. Verificar que PM2 está corriendo:
```bash
pm2 status
pm2 logs ecommerce --lines 50
```

3. Verificar que el puerto 3000 está escuchando:
```bash
ss -tlnp | grep 3000
```

4. Verificar conectividad a RDS:
```bash
source /app/ecommerce/backend/.env
nc -zv $DB_HOST $DB_PORT
```

### "No token provided" en todas las rutas
**Causa:** El header `Authorization: Bearer TOKEN` no está siendo enviado.
**Verificar:** El frontend guarda el token en `localStorage.accessToken`.

### Migraciones fallan en UserData
**Causa:** RDS no estaba disponible cuando se intentó migrar.
**Solución Manual:**
```bash
# Via SSM en la instancia
cd /app/ecommerce/backend
source .env
npx sequelize-cli db:migrate --env production
npx sequelize-cli db:seed:all --env production
pm2 restart ecommerce
```

### ALB devuelve 502 Bad Gateway
**Causa:** Las instancias en el Target Group no son healthy (app no corre o UserData falló).
**Solución:**
1. Revisar Target Group → Health checks en AWS Console
2. Conectar a la instancia y revisar `/var/log/userdata.log`
3. Verificar que el health check path `/health` responde 200

---

## Base de Datos

### Error "password authentication failed"
**Causa:** El password en `.env` no coincide con el de RDS.
**Solución:** Verificar que el `DBPassword` en `parameters/dev.json` coincide con el `.env` generado por UserData.

### Error "relation does not exist"
**Causa:** Las migraciones no se ejecutaron.
**Solución:**
```bash
cd /app/ecommerce/backend
npx sequelize-cli db:migrate --env production
```

---

## Auto Scaling

### Instancias se crean pero no llegan a Healthy

Verificar el health check grace period. Por defecto es 300s (5 min). La app puede tardar en iniciar.

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ecommerce-dev-asg \
  --query 'AutoScalingGroups[0].Instances'
```

### No scale out aunque CPU > 60%

Verificar que las alarmas de CloudWatch están en estado `ALARM`:
```bash
aws cloudwatch describe-alarms \
  --alarm-names ecommerce-dev-high-cpu \
  --query 'MetricAlarms[0].StateValue'
```

---

## Scripts

### Permission denied al ejecutar scripts
```bash
chmod +x scripts/*.sh
```

### `jq: command not found`
```bash
# Amazon Linux
sudo yum install -y jq

# Ubuntu
sudo apt-get install -y jq

# macOS
brew install jq
```

### AWS credentials expired (Sandbox)
Las credenciales del sandbox expiran cada 4 horas.
Actualizar con las nuevas credenciales del Learner Lab y volver a ejecutar.
