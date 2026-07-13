variable "subscription_id" {
  description = "ID de suscripción Azure (vacío si usas ARM_SUBSCRIPTION_ID)"
  type        = string
  default     = ""
}

variable "location" {
  description = "Región de Azure donde desplegar"
  type        = string
  default     = "swedencentral"
}

variable "resource_group_name" {
  description = "Nombre del resource group"
  type        = string
  default     = "rg-cp2-unir"
}

variable "prefix" {
  description = "Prefijo para los recursos"
  type        = string
  default     = "cp2unir"
}

variable "acr_name" {
  description = "Nombre del ACR (único en todo Azure)"
  type        = string
  default     = "mcorpcp2unir"
}

variable "acr_sku" {
  description = "SKU del ACR"
  type        = string
  default     = "Basic"
}

variable "vm_size" {
  description = "Tamaño de la VM (recomendado profesor: B2ats_v2)"
  type        = string
  default     = "Standard_B2ats_v2"
}

variable "vm_admin_username" {
  description = "Usuario admin de la VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Ruta a la clave pública SSH"
  type        = string
  default     = "~/.ssh/cp2_azure.pub"
}

variable "aks_node_size" {
  description = "Tamaño de los nodos AKS (D2s_v3 sin capacidad en Suecia → B2s_v2)"
  type        = string
  default     = "Standard_B2s_v2"
}

variable "aks_node_count" {
  description = "Número de nodos AKS"
  type        = number
  default     = 1
}

variable "tags" {
  description = "Tags para los recursos"
  type        = map(string)
  default = {
    environment = "casopractico2"
    project     = "cp2-unir-devops"
    managed_by  = "terraform"
  }
}
