# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.26.0"
    }
  }

  required_version = ">= 1.1.0"
}

provider "helm" {
  kubernetes {
    config_path = local_file.kubeconfig.filename
  }
}
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "crossplane-aks-rg"
  location = "westus2"
}

resource "azurerm_kubernetes_cluster" "crossplane" {
  name                = "crossplane-aks1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "crossplaneaks1"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  
             upgrade_settings {
               drain_timeout_in_minutes      = 0
               max_surge                     = "10%"
               node_soak_duration_in_minutes = 0
            }
  }
  
  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Production"
  }
}

resource "helm_release" "local_provisioner" {
  name             = "crossplane"
  repository       = "https://charts.crossplane.io/stable"
  chart            = "crossplane"
  namespace        = "crossplane-system"
  create_namespace = true
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.crossplane.kube_config[0].client_certificate
  sensitive = true
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.crossplane.kube_config_raw
  sensitive = true
}

resource "local_file" "kubeconfig" {
  content  = azurerm_kubernetes_cluster.crossplane.kube_config_raw
  filename = "${path.module}/kubeconfig-crossplane.yaml"
}