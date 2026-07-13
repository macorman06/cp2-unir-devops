#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TF_DIR="$PROJECT_DIR/terraform"

echo "ansible/deploy.sh — re-ejecutar solo la parte Ansible"
echo ""

# Leer outputs de Terraform (requiere terraform apply previo)
cd "$TF_DIR"
ACR_SERVER=$(terraform output -raw acr_login_server)
ACR_USER=$(terraform output -raw acr_admin_username)
ACR_PASS=$(terraform output -raw acr_admin_password)
VM_IP=$(terraform output -raw vm_public_ip)
AKS_NAME=$(terraform output -raw aks_cluster_name)
RG_NAME=$(terraform output -raw resource_group_name)
cd "$PROJECT_DIR"

ANSIBLE_EXTRA=(
  "acr_server=$ACR_SERVER"
  "acr_user=$ACR_USER"
  "acr_pass=$ACR_PASS"
  "vm_ip=$VM_IP"
)

# Build & push
echo "Build & push imagenes..."
ansible-playbook "$SCRIPT_DIR/build-push.yml" \
  -i "$SCRIPT_DIR/hosts" \
  -e "${ANSIBLE_EXTRA[@]}"

# Kubeconfig
echo "Kubeconfig..."
az aks get-credentials \
  --resource-group "$RG_NAME" \
  --name "$AKS_NAME" \
  --overwrite-existing

# App en VM
echo "App Podman en VM..."
ansible-playbook "$SCRIPT_DIR/podman-vm.yml" \
  -i "$SCRIPT_DIR/hosts" \
  -e "${ANSIBLE_EXTRA[@]}"

# App en AKS
echo "App en AKS..."
ansible-playbook "$SCRIPT_DIR/aks-app.yml" \
  -i "$SCRIPT_DIR/hosts" \
  -e "${ANSIBLE_EXTRA[@]}"

echo ""
echo "Hecho."
echo "Podman: curl -k -u alumno:unir2026 https://$VM_IP/"
echo "AKS:    kubectl -n cp2 get svc app-aks"
