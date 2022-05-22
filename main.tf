
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0.0"
    }
  }
    backend "azurerm" {
        #resource_group_name  = "dowd-devops-rg"
        #storage_account_name = "dowdtf"
        #container_name       = "tfstatedowd"
        #key                  = "terraform.tfstate"
    }

}



provider "azurerm" {
  # Configuration options
  features {}
}


resource "azurerm_resource_group" "rg99" {
  name     = join("-", [var.env, var.reg, var.dom,"rgnw",var.index])
  location = var.location
}

resource "azurerm_virtual_network" "vnet99" {
  name                = join("-", [var.env, var.reg, var.dom, "vnet1", var.index])
  location            = var.location
  resource_group_name = azurerm_resource_group.rg99.name
  address_space       = ["10.254.0.0/16"]
}


resource "azurerm_subnet" "sub199" {
  name                 =  "frontendnw"
  resource_group_name  = azurerm_resource_group.rg99.name
  virtual_network_name = azurerm_virtual_network.vnet99.name
  address_prefixes     = ["10.254.0.0/24"]

}
resource "azurerm_network_security_group" "nsg99" {
  name                = join("-", [var.env, var.reg, var.dom, "nsg", var.index])
  location            = var.location
  resource_group_name = azurerm_resource_group.rg99.name

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "subnsg99" {
  subnet_id                 = azurerm_subnet.sub199.id
  network_security_group_id = azurerm_network_security_group.nsg99.id
}

resource "azurerm_subnet" "sub299" {
  name                 = "backendnw"
  resource_group_name  = azurerm_resource_group.rg99.name
  virtual_network_name = azurerm_virtual_network.vnet99.name
  address_prefixes     = ["10.254.2.0/24"]
}

resource "azurerm_network_security_group" "nsg299" {
  name                = join("-", [var.env, var.reg, var.dom,"nsg",var.index1])
  location            = var.location
  resource_group_name = azurerm_resource_group.rg99.name

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "subnsg299" {
  subnet_id                 = azurerm_subnet.sub299.id
  network_security_group_id = azurerm_network_security_group.nsg299.id
}

resource "azurerm_kubernetes_cluster" "aks99" {
  name                = join("-", [var.env, var.reg, var.dom,"aks",var.index])
  location            = azurerm_resource_group.rg99.location
  resource_group_name = azurerm_resource_group.rg99.name
  dns_prefix          = "aksdns1"

  default_node_pool {
    name       = "dnp"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Production"
  }
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.aks99.kube_config.0.client_certificate
  sensitive = true
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.aks99.kube_config_raw

  sensitive = true
}

resource "azurerm_public_ip" "publip" {
  name                = join("-", [var.env, var.reg, var.dom,"pip",var.index])
  resource_group_name = azurerm_resource_group.rg99.name
  location            = var.location
  allocation_method   = "Dynamic"
}

#&nbsp;since these variables are re-used - a locals block makes this more maintainable
locals {
  backend_address_pool_name      = "${azurerm_virtual_network.vnet99.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.vnet99.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.vnet99.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.vnet99.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.vnet99.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.vnet99.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.vnet99.name}-rdrcfg"
}

resource "azurerm_application_gateway" "agynetwork" {
  name                = join("-", [var.env, var.reg, var.dom,"agw",var.index])
  resource_group_name = azurerm_resource_group.rg99.name
  location            = var.location

  sku {
    name     = "Standard_Small"
    tier     = "Standard"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "rgnw-gateway-ip-configuration"
    subnet_id = azurerm_subnet.sub199.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.publip.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/path1/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
}
resource "azurerm_app_service_plan" "appsrv99" {
  name                = join("-", [var.env, var.reg, var.dom,"ap-pl",var.index])
  location            = var.location
  resource_group_name = azurerm_resource_group.rg99.name

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service" "apsr99" {
  name                = join("-", [var.env, var.reg, var.dom,"app",var.index])
  location            = var.location
  resource_group_name = azurerm_resource_group.rg99.name
  app_service_plan_id = azurerm_app_service_plan.appsrv99.id

  site_config {
    dotnet_framework_version = "v4.0"
    scm_type                 = "LocalGit"
  }

  app_settings = {
    "SOME_KEY" = "some-value"
  }

  connection_string {
    name  = "Database"
    type  = "SQLServer"
    value = "Server=some-server.mydomain.com;Integrated Security=SSPI"
  }
}

resource "azurerm_resource_group" "rg98" {
  name     = join("-", [var.env, var.reg, var.dom,"rgpaas",var.index])
  location = var.location
}

resource "azurerm_postgresql_server" "psql98" {
  name                = join("-", [var.env, var.reg, var.dom,"psql",var.index1])
  location            = var.location
  resource_group_name = azurerm_resource_group.rg98.name

  administrator_login          = var.adminlogin
  administrator_login_password = var.loginpassword

  sku_name   = "GP_Gen5_4"
  version    = "11"
  storage_mb = 640000

  backup_retention_days        = 7
  geo_redundant_backup_enabled = true
  auto_grow_enabled            = true

  public_network_access_enabled    = false
  ssl_enforcement_enabled          = true
  ssl_minimal_tls_version_enforced = "TLS1_2"
}

resource "azurerm_redis_cache" "rdcache" {
  name                = join("-", [var.env, var.reg, var.dom,"rdche",var.index1])
  location            = var.location
  resource_group_name = azurerm_resource_group.rg98.name
  redis_version = "6"
  public_network_access_enabled = true
  capacity            = 2
  family              =  "C"
  sku_name            = "Standard"
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"

  redis_configuration {
  }
}

resource "azurerm_user_assigned_identity" "mi98" {
  resource_group_name = azurerm_resource_group.rg98.name
  location            = var.location

  name = join("-", [var.env, var.reg,"mi"])
}
output "uai_client_id" {
  value = azurerm_user_assigned_identity.mi98.client_id
}
output "uai_principal_id" {
  value = azurerm_user_assigned_identity.mi98.principal_id
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "keyvl98" {
  name                        = join("-", [var.env, var.reg, var.dom, "akv", var.index1])
  location                    = var.location
  resource_group_name         = azurerm_resource_group.rg98.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get",
    ]

    storage_permissions = [
      "Get",
    ]
    certificate_permissions = [
      "Get",
    ]
  }
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.mi98.principal_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get",
    ]

    storage_permissions = [
      "Get",
    ]
    certificate_permissions = [
      "Get",
    ]
  }
}
resource "azurerm_storage_account" "stg198" {
  name                     = stg1paas
  resource_group_name      = azurerm_resource_group.rg98.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  static_website {
    index_document = "index.html"
  }

  network_rules {
    default_action             = "Deny"
    ip_rules                   = ["100.0.0.1"]
    virtual_network_subnet_ids = [azurerm_subnet.sub299.id]
  }
  tags = {
    environment = "staging"
  }
}
  resource "azurerm_cdn_profile" "cdn1paas" {
  name                = join("-", [var.env, var.reg, var.dom,"cp",var.index])
  location            = var.location
  resource_group_name = azurerm_resource_group.rg98.name
  sku                 = "Standard_Verizon"

  tags = {
    environment = "Production"
    cost_center = "MSFT"
  }
}
resource "azurerm_cdn_endpoint" "cdnpt1" {
  location            = var.location
  name                = join("-", [var.env, var.reg, var.dom,"edp",var.index])
  profile_name        = azurerm_cdn_profile.cdn1paas.name
  resource_group_name = azurerm_resource_group.rg98.name
  origin {
    name      = "example"
    host_name = "www.contoso.com"
  }
}

resource "azurerm_storage_account" "stg298" {
  name                     = stg2paas
  resource_group_name      = azurerm_resource_group.rg98.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  static_website {
    index_document = "index.html"
  }

  network_rules {
    default_action             = "Deny"
    ip_rules                   = ["100.0.0.1"]
    virtual_network_subnet_ids = [azurerm_subnet.sub299.id]
  }

  tags = {
    environment = "staging"
  }
}

  resource "azurerm_cdn_profile" "cdn2paas" {
  name                = join("-", [var.env, var.reg, var.dom,"cp",var.index1])
  location            = var.location
  resource_group_name = azurerm_resource_group.rg98.name
  sku                 = "Standard_Verizon"

  tags = {
    environment = "Production"
    cost_center = "MSFT"
  }
}
resource "azurerm_cdn_endpoint" "cdnpt2" {
  location            = var.location
  name                = join("-", [var.env, var.reg, var.dom,"edp",var.index1])
  profile_name        = azurerm_cdn_profile.cdn2paas.name
  resource_group_name = azurerm_resource_group.rg98.name
  origin {
    name      = "example1"
    host_name = "www.contoso1.com"
  }
}
resource "azurerm_network_interface" "nic" {
  name                = join("-", [var.env, var.reg, var.dom,"nic",var.index])
  location            = var.location
  resource_group_name = azurerm_resource_group.rg99.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.sub299.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "example-machine"
  resource_group_name = azurerm_resource_group.rg99.name
  location            = var.location
  size                = "Standard_F2"
  admin_username      = var.adminlogin
  admin_password = var.loginpassword
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]



  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}
/*
# creating resource group


resource "azurerm_resource_group" "rg0123" {

  location = var.location
  name     = join("-", [var.env, var.reg, var.dom,"rg",var.index])
}


resource "azurerm_virtual_network" "vnet" {
  name                = join("-", [var.env, var.reg, var.dom,"vnet",var.index])
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg0123.name
}

resource "azurerm_subnet" "subnet" {
  name                 = join("-", [var.env, var.reg, var.dom,"subnet",var.index])
  resource_group_name  = azurerm_resource_group.rg0123.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
}


output "subnet" {
  value = "azurerm_subnet.subnet.id"
}

resource "azurerm_subnet" "subnet1" {
  name                 = join("-", [var.env, var.reg, var.dom,"subnet",var.index1])
  resource_group_name  = azurerm_resource_group.rg0123.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
}
output "subnet1" {
  value = "azurerm_subnet.subnet1.id"
}




resource "azurerm_network_interface" "nic" {
  name                = join("-", [var.env, var.reg, var.dom,"nic",var.index])
  location            = var.location
  resource_group_name = azurerm_resource_group.rg0123.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "example" {
  name                = join("-", [var.env, var.reg, var.dom,"vm",var.index])
  resource_group_name = azurerm_resource_group.rg0123.name
  location            = var.location
  size                = "Standard_F2"
  admin_username      = var.adminlogin
  admin_password      = var.loginpassword
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}



resource "azurerm_resource_group" "rg013" {

  location = var.location
  name     = join("-", [var.env, var.reg, var.dom,"rg",var.index1])
}


resource "azurerm_storage_account" "stg1" {
  account_replication_type = "LRS"
  account_tier             = "Standard"
  location                 = var.location
  name                     = join("", [var.env, var.reg, var.dom, "stg", var.index1])
  resource_group_name      = azurerm_resource_group.rg013.name
  depends_on = [azurerm_resource_group.rg013,azurerm_virtual_network.vnet]
}
resource "azurerm_storage_account_network_rules" "test" {
  storage_account_id = azurerm_storage_account.stg1.id

  default_action             = "Deny"
  ip_rules                   = ["127.0.0.1"]
  virtual_network_subnet_ids = [azurerm_subnet.subnet.id,azurerm_subnet.subnet1.id]
  bypass                     = ["Metrics"]
}



resource "azurerm_postgresql_server" "psql" {
  name                = join("",[var.env,var.reg,var.dom,"psql", var.index])
  location            = var.location
  resource_group_name = azurerm_resource_group.rg0123.name

  sku_name   = "GP_Gen5_4"

  storage_mb = 640000
  backup_retention_days        = 7
  geo_redundant_backup_enabled = true
  auto_grow_enabled            = true

  administrator_login          = var.adminlogin
  administrator_login_password = var.loginpassword
  version                      = "11"
  public_network_access_enabled    = true
  #deny_public_network_access = true
  ssl_enforcement_enabled          = true
  ssl_minimal_tls_version_enforced = "TLS1_2"
}

resource "azurerm_postgresql_database" "psqldb" {
  name                = join("",[var.env,var.reg,var.dom,"psqldb", var.index])
  resource_group_name = azurerm_resource_group.rg0123.name
  server_name         = azurerm_postgresql_server.psql.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}


resource "azurerm_user_assigned_identity" "mi" {
  resource_group_name = azurerm_resource_group.rg0123.name
  location            = var.location

  name = join("-", [var.env, var.reg,"mi"])
}

output "uai_client_id" {
  value = azurerm_user_assigned_identity.mi.client_id
}

output "uai_principal_id" {
  value = azurerm_user_assigned_identity.mi.principal_id
}



data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "example" {
  name                        = "tesbkeyvault"
  location                    = azurerm_resource_group.rg0123.location
  resource_group_name         = azurerm_resource_group.rg0123.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get",
    ]

    storage_permissions = [
      "Get",
    ]
    certificate_permissions = [
       "Get",
    ]
  }
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.mi.principal_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get",
    ]

    storage_permissions = [
      "Get",
    ]
    certificate_permissions = [
       "Get",
    ]
  }
}
*/





