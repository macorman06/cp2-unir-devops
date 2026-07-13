#!/usr/bin/env bash
set -e

# Ensure Ansible collections are installed
ansible-galaxy collection install containers.podman kubernetes.core >/dev/null 2>&1 || true

# Ensure Azure provider registered
for ns in Microsoft.ContainerRegistry Microsoft.Compute Microsoft.Network Microsoft.ContainerService; do
  az provider register --namespace "$ns" >/dev/null 2>&1 || true
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/terraform"
ANSIBLE_DIR="${SCRIPT_DIR}/ansible"
IMAGE_TAG="casopractico2"

echo "CP2 — Despliegue completo"
echo ""

# FASE 1 — Terraform: crear infraestructura en Azure
echo "Terraform: creando ACR + VM + AKS..."
cd "${TF_DIR}"
terraform init
terraform apply -auto-approve

ACR_SERVER=$(terraform output -raw acr_login_server)
ACR_USER=$(terraform output -raw acr_admin_username)
ACR_PASS=$(terraform output -raw acr_admin_password)
VM_IP=$(terraform output -raw vm_public_ip)
AKS_NAME=$(terraform output -raw aks_cluster_name)
RG_NAME=$(terraform output -raw resource_group_name)

echo "RG: ${RG_NAME} | ACR: ${ACR_SERVER} | VM: ${VM_IP} | AKS: ${AKS_NAME}"
echo ""

# FASE 2 — Build & push
echo "Build & push imagenes al ACR..."
cd "${SCRIPT_DIR}"

ansible-galaxy collection install containers.podman kubernetes.core

ansible-playbook "${ANSIBLE_DIR}/build-push.yml" \
  -i "${ANSIBLE_DIR}/hosts" \
  -e "acr_server=${ACR_SERVER}" \
  -e "acr_user=${ACR_USER}" \
  -e "acr_pass=${ACR_PASS}" \
  -e "vm_ip=${VM_IP}"
echo ""

# FASE 3 — Kubeconfig
echo "Configurando acceso a AKS..."
az aks get-credentials \
  --resource-group "${RG_NAME}" \
  --name "${AKS_NAME}" \
  --overwrite-existing
echo ""

# FASE 4 — Ansible: app Podman en VM
echo "Desplegando app en VM..."
ANSIBLE_HOST_KEY_CHECKING=False \
ansible-playbook "${ANSIBLE_DIR}/podman-vm.yml" \
  -i "${ANSIBLE_DIR}/hosts" \
  -e "acr_server=${ACR_SERVER}" \
  -e "acr_user=${ACR_USER}" \
  -e "acr_pass=${ACR_PASS}" \
  -e "vm_ip=${VM_IP}"
echo ""

# FASE 5 — Ansible: app en AKS con PVC
echo "Desplegando app en AKS..."
ansible-playbook "${ANSIBLE_DIR}/aks-app.yml" \
  -i "${ANSIBLE_DIR}/hosts" \
  -e "acr_server=${ACR_SERVER}" \
  -e "acr_user=${ACR_USER}" \
  -e "acr_pass=${ACR_PASS}" \
  -e "vm_ip=${VM_IP}"
echo ""

echo "Despliegue completado"
echo ""

echo "App Podman:"
echo "  curl -k -u alumno:unir2026 https://${VM_IP}/"
echo ""
echo "App AKS:"
for i in $(seq 1 12); do
  AKS_IP=$(kubectl -n cp2 get svc app-aks -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null)
  [ -n "$AKS_IP" ] && break
  sleep 5
done
echo "  http://${AKS_IP}/"
echo ""
echo "Para eliminar todo: cd ${TF_DIR} && terraform destroy -auto-approve"
