# Facturación Electrónica Serverless — Tema 10 (Servicios Cloud)

Repositorio del proyecto final. Contiene la infraestructura como código (Terraform),
las funciones serverless del flujo de facturación (APF1) y el componente de
backoffice contenerizado con Docker (APF2).

## Estructura

```
facturacion-electronica-cloud/
├── infra/terraform/     Infraestructura como Código (red, cómputo, datos, IAM, KMS,
│                        funciones, Pub/Sub, workflow, API Gateway y monitoreo)
├── api/                  Definición OpenAPI de la API (API Gateway)
├── functions/            7 Cloud Run functions (5 del flujo + api-emision + sincronizar-reportes)
├── backoffice/           Panel de reportería contenerizado (Docker)
├── workflows/            Orquestación del flujo (Cloud Workflows)
├── tests/                Pruebas de carga (k6) y de resiliencia (scripts)
└── docs/                 Informe técnico (Word) y diagramas
```

## Cómo correr cada componente localmente

### 1. Funciones serverless (`functions/*`)
Cada función es independiente. Para probarla:
```bash
cd functions/validar-comprobante
npm install
npm test              # corre las pruebas unitarias (test.js)
npm start             # levanta la función como servidor HTTP local (Functions Framework)
```
Repetir dentro de cada carpeta de `functions/` (cada una usa un puerto distinto: 8081–8085,
definido en su `package.json`).

### 2. Backoffice (Docker)
Verificación local multicontenedor (app + PostgreSQL):
```bash
cd backoffice
cp .env.example .env          # ajustar credenciales si se desea
docker compose up --build
# en otra terminal:
curl http://localhost:8080/health
curl -X POST http://localhost:8080/api/reportes/comprobantes \
  -H "Content-Type: application/json" \
  -d '{"serie":"F001","numero":"1","rucEmisor":"20123456789","cliente":"Cliente Final","total":100}'
curl http://localhost:8080/api/reportes/comprobantes
```

### 3. Infraestructura completa (Terraform)
Requiere una cuenta de GCP con facturación habilitada (créditos educativos) y las APIs listadas en el capítulo 12
del informe. Se ejecuta desde Cloud Shell o desde una máquina con `gcloud` y `terraform`:
```bash
export TF_VAR_db_password="<CONTRASEÑA>"       # nunca en el repositorio
export TF_VAR_alert_email="<CORREO>"
cd infra/terraform
terraform init
terraform apply -var="project_id=<TU_PROYECTO>" -var="admin_ip=<TU_IP>/32"
```
Crea la VPC con firewall de mínimo privilegio, las VMs, Cloud SQL (IP privada), Firestore, los buckets, KMS y secretos,
las cuentas de servicio, las 7 funciones, Pub/Sub con DLQ, el workflow, API Gateway y las alertas/dashboard.

Luego se habilita la API administrada y se crea la API key:
```bash
gcloud services enable $(terraform output -raw api_managed_service)
gcloud services api-keys create --display-name=clave-demo --api-target=service=$(terraform output -raw api_managed_service)
curl $(terraform output -raw gateway_url)/health
curl -X POST $(terraform output -raw gateway_url)/comprobantes -H "x-api-key: <CLAVE>" \
     -H "Content-Type: application/json" -d @../../tests/load/comprobante-ejemplo.json
```
Al terminar las pruebas: `terraform destroy` con las mismas variables (el key ring de KMS no se puede borrar;
si vuelven a desplegar usen `-var="kms_suffix=02"`).

### 4. Pruebas de carga y resiliencia
```bash
k6 run -e BASE_URL=<gateway_url> -e API_KEY=<CLAVE> -e ESCENARIO=PC01 tests/load/k6-emision.js   # PC01, PC02, PC03
gcloud workflows executions list proceso-facturacion --location=us-central1 --limit=1000 \
  --format="value(startTime,endTime,state)" | python3 tests/load/calcular-p95.py
tests/resilience/pr01-falla-vm.sh   pr02-falla-sunat.sh   pr03-restaurar-pitr.sh
```

## Estado de verificación

| Componente | Verificado | Cómo |
|---|---|---|
| 7 funciones serverless | Sí | Pruebas unitarias (`npm test`, con clientes simulados de KMS, Workflows y BD) y prueba HTTP local con Functions Framework |
| Perilla de fallas (`SUNAT_FAIL_RATE`) | Sí | Responde 503 cuando está activa |
| generar-pdf | Sí | Genera un PDF real y válido, verificado visualmente |
| Backoffice (Express + PostgreSQL) | Parcial | Arranca y responde `/health`; falta `docker compose up` y la prueba con PostgreSQL real en la máquina del equipo |
| Terraform (≈ 70 recursos) | Sintaxis y referencias | Parseo HCL y revisión de referencias cruzadas; falta `terraform apply` real (puede requerir ajustes menores en el primer despliegue) |
| Workflow y OpenAPI (YAML) | Sintaxis | Validados con un parser YAML; se validan al desplegar |
| k6 y scripts de resiliencia | Sintaxis / cálculo de p95 | `calcular-p95.py` probado con datos sintéticos; k6 y los scripts requieren el entorno desplegado |

## Convención de commits

Se usa [Conventional Commits](https://www.conventionalcommits.org/): `feat`, `fix`,
`infra`, `docs`, `chore`. Ver detalle en la sección 6.4 del informe técnico.
