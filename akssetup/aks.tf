resource "azurerm_virtual_network" "aksvnet" {
  name                = "aksvnet"
  resource_group_name = data.azurerm_resource_group.aksrg.name
  location            = data.azurerm_resource_group.aksrg.location
  address_space       = ["10.1.0.0/16"]  
}
resource "azurerm_subnet" "aksnodepoolsubnet" {
  name                 = "aksnodepoolsubnet"
  resource_group_name  = data.azurerm_resource_group.aksrg.name
  virtual_network_name = azurerm_virtual_network.aksvnet.name
  address_prefixes     = ["10.1.2.0/23"] 
  
}
resource "azurerm_subnet" "aksvnodepoolsubnet" {
  name                 = "aksvnodepoolsubnet"
  resource_group_name  = data.azurerm_resource_group.aksrg.name
  virtual_network_name = azurerm_virtual_network.aksvnet.name
  address_prefixes     = ["10.1.0.0/24"]   

  delegation {
    name = "aciDelegation"
    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}


resource "azurerm_kubernetes_cluster" "akscluster" {
  name                = "attendeecluster"
  location            = "north europe"
  resource_group_name = data.azurerm_resource_group.aksrg.name
  dns_prefix          = "aks1"

  role_based_access_control_enabled = true

  network_profile {
    network_plugin     = "azure"
    load_balancer_sku  = "standard"
    network_policy     = "calico"
  }

  default_node_pool {
    name       = "default"
    
    node_count = 1
    vm_size    = "Standard_DS2_v2"
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 2
    vnet_subnet_id   = azurerm_subnet.aksnodepoolsubnet.id
    
  }
 
    aci_connector_linux{
      subnet_name  = azurerm_subnet.aksvnodepoolsubnet.name
    }
    

    azure_policy_enabled = false
    open_service_mesh_enabled = true
    http_application_routing_enabled = false
   
    

    

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Production"
  }
  lifecycle {
    ignore_changes = [
      # Since autoscaling is enabled, let's ignore changes to the node count.
      default_node_pool[0].node_count,
      service_principal
    ]
  }
}


resource "azurerm_container_registry" "acr" {
  name                = replace("${var.attendee}","-","")
  resource_group_name = data.azurerm_resource_group.aksrg.name
  location            = data.azurerm_resource_group.aksrg.location
  sku                 = "Standard"
  admin_enabled       = true
  
}

resource "azurerm_role_assignment" "aks" {
  scope                = azurerm_kubernetes_cluster.akscluster.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_kubernetes_cluster.akscluster.identity[0].principal_id
}


resource "azurerm_role_assignment" "aksvnet" {
  scope                = azurerm_virtual_network.aksvnet.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.akscluster.identity[0].principal_id
}

data "azurerm_user_assigned_identity" "aks-aci_identity" {
  name = "aciconnectorlinux-${azurerm_kubernetes_cluster.akscluster.name}"
  resource_group_name = azurerm_kubernetes_cluster.akscluster.node_resource_group
}

resource "azurerm_role_assignment" "vnet_permissions_aci" {
  principal_id         = data.azurerm_user_assigned_identity.aks-aci_identity.principal_id
  scope                = azurerm_virtual_network.aksvnet.id
  role_definition_name = "Network Contributor"
}


resource "azurerm_role_assignment" "aks_acr" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.akscluster.kubelet_identity[0].object_id
}
resource "azurerm_role_assignment" "kubelet_managed_id_operator" {
  scope                = data.azurerm_resource_group.aksrg.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_kubernetes_cluster.akscluster.kubelet_identity.0.object_id
}

#resource "azurerm_role_assignment" "agentpool_msi" {
#  scope                            = data.azurerm_resource_group.aksrg.id
#  role_definition_name             = "Managed Identity Operator"
#  principal_id                     = azurerm_kubernetes_cluster.akscluster.kubelet_identity[0].object_id
#  skip_service_principal_aad_check = true

#}