# CP2 — UNIR DevOps & Cloud

Infraestructura y despliegue automatizado en Microsoft Azure con Terraform y Ansible.

## Arquitectura

```
Nodo de control (Linux / macOS / WSL2)
├── Terraform  → crea → Azure: [ACR] [VM + Nginx HTTPS] [AKS + PVC]
├── Ansible    → VM:   Podman + systemd + TLS autofirmado + basic auth
└── Ansible    → AKS:  Deployment + Service LoadBalancer + PVC 1Gi
                        ↑ AcrPull (identity gestionada)
                    ──── ACR ────
                        ↑ push (tag casopractico2)
                    Imágenes locales (Podman build)
```

Dos aplicaciones distintas:

| App | Dónde corre | Tecnología |
|---|---|---|
| `app-podman` | VM (Ubuntu) | Nginx + HTTPS autofirmado + htpasswd |
| `app-aks` | AKS (Kubernetes) | Flask + Chart.js + PVC persistente |

## Requisitos del sistema

### macOS (Homebrew)

```bash
brew install azure-cli terraform ansible podman kubectl git
```

### Windows (WSL2)

Ansible no corre nativo en Windows. El resto de herramientas pueden instalarse tanto en Windows como dentro de WSL2.

```powershell
# En Windows (PowerShell)
winget install Microsoft.AzureCLI Hashicorp.Terraform Kubernetes.kubectl Git.Git

# En WSL2 (Ubuntu)
sudo apt update && sudo apt install -y ansible podman python3-pip
pip3 install kubernetes
```

El script `deploy.sh` debe ejecutarse **dentro de WSL2**, accediendo al repositorio desde `/mnt/c/...`.

## Configuración previa (una sola vez)

### 1. Autenticarse en Azure

```bash
az login
az account set --subscription "Azure for Students"
```

### 2. Clonar el repositorio

```bash
git clone https://github.com/macorman06/cp2-unir-devops
cd cp2-unir-devops
```

## Despliegue (comando único)

```bash
cd code
bash deploy.sh
```

El script es idempotente: si los recursos ya existen, terraform no los recrea. Tiempo total estimado: 12-18 minutos.

## Explicación paso a paso

A continuación se detalla cada fase del `deploy.sh` con los comandos equivalentes para ejecución manual.

### Fase 0 — Prerrequisitos

```bash
# Verificar herramientas instaladas
az --version && terraform --version && ansible --version
podman --version && kubectl version --client

# Autenticación Azure (si no se ha hecho)
az login
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"

# Generar clave SSH (si no existe)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/cp2_azure -N ""

# Instalar colecciones Ansible
ansible-galaxy collection install containers.podman kubernetes.core

# Registrar resource providers en Azure
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.ContainerService
```

### Fase 1 — Crear infraestructura (Terraform)

Crea: Resource Group, ACR (Basic), VNet + NSG (SSH 22, HTTPS 443), IP pública estática, VM (Ubuntu 22.04), AKS (Free, 1 nodo), rol AcrPull.

```bash
cd terraform
terraform init
terraform apply -auto-approve

# Obtener outputs necesarios para las siguientes fases
ACR_SERVER=$(terraform output -raw acr_login_server)
ACR_USER=$(terraform output -raw acr_admin_username)
ACR_PASS=$(terraform output -raw acr_admin_password)
VM_IP=$(terraform output -raw vm_public_ip)
RG_NAME=$(terraform output -raw resource_group_name)
AKS_NAME=$(terraform output -raw aks_cluster_name)
```

### Fase 2 — Build & push de imágenes

Construye las dos imágenes con Podman (plataforma linux/amd64) y las sube al ACR con tag `casopractico2`.

```bash
cd ..

# Login en ACR
echo "$ACR_PASS" | podman login "$ACR_SERVER" -u "$ACR_USER" --password-stdin

# Build y push app-podman (Nginx + HTTPS + basic auth)
podman build --arch=amd64 -t "$ACR_SERVER/app-podman:casopractico2" app-podman/
podman push "$ACR_SERVER/app-podman:casopractico2"

# Build y push app-aks (Flask + persistencia)
podman build --arch=amd64 -t "$ACR_SERVER/app-aks:casopractico2" app-aks/
podman push "$ACR_SERVER/app-aks:casopractico2"
```

> **Nota:** Se usa `--arch=amd64` porque la VM de Azure es arquitectura AMD64. Sin esto, Podman construiría para ARM en Apple Silicon.

### Fase 3 — Configurar acceso a AKS

```bash
az aks get-credentials \
  --resource-group "$RG_NAME" \
  --name "$AKS_NAME" \
  --overwrite-existing
```

### Fase 4 — Desplegar app Podman en VM

Conecta por SSH a la VM, instala Podman, descarga la imagen del ACR, y arranca el contenedor como servicio systemd.

```bash
ANSIBLE_HOST_KEY_CHECKING=False \
ansible-playbook ansible/podman-vm.yml \
  -i ansible/hosts \
  -e "acr_server=$ACR_SERVER" \
  -e "acr_user=$ACR_USER" \
  -e "acr_pass=$ACR_PASS" \
  -e "vm_ip=$VM_IP"
```

> `ANSIBLE_HOST_KEY_CHECKING=False` evita que la primera conexión SSH falle por host key desconocido.

### Fase 5 — Desplegar app en AKS con PVC

Crea en Kubernetes: namespace `cp2`, PVC 1Gi (managed-csi), Deployment con la imagen del ACR montando el PVC en `/data`, y Service tipo LoadBalancer (puerto 80 → 5000).

```bash
ansible-playbook ansible/aks-app.yml \
  -i ansible/hosts \
  -e "acr_server=$ACR_SERVER" \
  -e "acr_user=$ACR_USER" \
  -e "acr_pass=$ACR_PASS" \
  -e "vm_ip=$VM_IP"
```

Los manifiestos YAML se generan desde plantillas Jinja2 en `ansible/templates/`:
- `aks-namespace.j2` → Namespace
- `aks-pvc.j2` → PersistentVolumeClaim
- `aks-deployment.j2` → Deployment (1 réplica, monta PVC en /data)
- `aks-service.j2` → Service LoadBalancer

## Verificación

### App 1 — Podman en VM

```bash
curl -k -u alumno:unir2026 https://<IP_PUBLICA_VM>/
# Credenciales: alumno / unir2026

# Gestión como servicio:
ssh -i ~/.ssh/cp2_azure azureuser@<IP_PUBLICA_VM>
sudo systemctl status container-webapp
```

### App 2 — App en AKS con persistencia

```bash
kubectl -n cp2 get svc app-aks
IP=$(kubectl -n cp2 get svc app-aks -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

curl http://$IP/              # HTML Cookie Clicker
curl -X POST http://$IP/click # {"clicks": 1}
curl http://$IP/counter       # {"clicks": 1}

# Demostración de persistencia:
curl -X POST http://$IP/click
curl http://$IP/counter       # 2
kubectl -n cp2 delete pod -l app=app-aks
sleep 10
curl http://$IP/counter       # 2 (persiste tras reinicio)
```

## Destruir infraestructura

Para eliminar todos los recursos de Azure y dejar el sistema como estaba al principio:

```bash
cd code/terraform
terraform destroy -auto-approve
```

Esto borra: Resource Group, ACR, VM, AKS, VNet, NSG, IP pública, NIC, disco OS, y role assignment. Comprobar en [Azure Portal](https://portal.azure.com) que el grupo `rg-cp2-unir` ha desaparecido.

## Estructura del repositorio

```
cp2-unir-devops/
├── deploy.sh                   # Orquestador único
├── README.md                   # Este archivo
├── .gitignore
├── terraform/                  # IaC (main.tf, acr.tf, vm.tf, aks.tf...)
├── ansible/                    # Playbooks + templates K8s
│   ├── build-push.yml          # Build & push imágenes al ACR
│   ├── podman-vm.yml           # Configura VM + Podman + systemd
│   ├── aks-app.yml             # Despliega app en AKS con PVC
│   ├── hosts                   # Inventario Ansible
│   └── templates/              # Plantillas Jinja2 de manifiestos K8s
├── app-podman/                 # Imagen 1: Nginx + TLS + auth
│   ├── Containerfile
│   ├── nginx.conf
│   ├── htpasswd
│   ├── certs/
│   └── web/
└── app-aks/                    # Imagen 2: Flask + PVC
    ├── Containerfile
    ├── requirements.txt
    └── app.py
```
