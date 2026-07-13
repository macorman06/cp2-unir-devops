output "resource_group_name" {
  description = "Nombre del resource group"
  value       = azurerm_resource_group.rg.name
}

output "acr_login_server" {
  description = "URL del servidor ACR"
  value       = azurerm_container_registry.acr.login_server
}

output "acr_admin_username" {
  description = "Usuario admin del ACR"
  value       = azurerm_container_registry.acr.admin_username
}

output "acr_admin_password" {
  description = "Contraseña admin del ACR"
  value       = azurerm_container_registry.acr.admin_password
  sensitive   = true
}

output "vm_public_ip" {
  description = "IP pública de la VM"
  value       = azurerm_linux_virtual_machine.vm.public_ip_address
}

output "vm_ssh_command" {
  description = "Comando SSH para conectar a la VM"
  value       = "ssh -i ~/.ssh/cp2_azure ${var.vm_admin_username}@${azurerm_linux_virtual_machine.vm.public_ip_address}"
}

output "aks_cluster_name" {
  description = "Nombre del cluster AKS"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_kubeconfig_command" {
  description = "Comando para obtener el kubeconfig del AKS"
  value       = "az aks get-credentials -g ${azurerm_resource_group.rg.name} -n ${azurerm_kubernetes_cluster.aks.name} --overwrite-existing"
}

output "acr_resource_id" {
  description = "ID del recurso ACR"
  value       = azurerm_container_registry.acr.id
}
