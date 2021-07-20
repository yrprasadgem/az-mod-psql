resource "azurerm_postgresql_server" "server" {
  name                = var.server_name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku_name = var.sku_name

  storage_mb                   = var.storage_mb
  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup_enabled

  administrator_login           = var.admin_login
  administrator_login_password  = var.admin_password
  version                       = var.server_version
  ssl_enforcement_enabled       = var.ssl_enforcement_enabled
  public_network_access_enabled = var.public_network_access_enabled

  tags = var.tags
}

resource "azurerm_postgresql_database" "dbs" {
  count               = length(var.db_names)
  name                = var.db_names[count.index]
  resource_group_name = var.resource_group_name
  server_name         = azurerm_postgresql_server.server.name
  charset             = var.db_charset
  collation           = var.db_collation
}

resource "azurerm_postgresql_configuration" "db_configs" {
  count               = length(keys(var.postgresql_configurations))
  resource_group_name = var.resource_group_name
  server_name         = azurerm_postgresql_server.server.name
  name                = element(keys(var.postgresql_configurations), count.index)
  value               = element(values(var.postgresql_configurations), count.index)
}


resource "azurerm_private_dns_zone" "postgres_sql_privatednszone" {
  name = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "priv-dns-link" {
  name                  = "priv-dns-prdlink"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres_sql_privatednszone.name
  virtual_network_id    = var.virtual_net_id
  registration_enabled  = true
  tags = var.tags
}

resource "azurerm_private_endpoint" "psql_pvt_endpoint" {
  location = var.location
  name = var.pvt_endpoint_name
  resource_group_name = var.resource_group_name
  subnet_id = var.pvt_endpoint_subnet_id
  tags = var.tags
  private_dns_zone_group {
    name = "dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.postgres_sql_privatednszone.id]
  }
  private_service_connection {
    is_manual_connection = false
    name = "prdpsql-privateserviceconnection"
    subresource_names = [ "postgresqlServer" ]
    private_connection_resource_id = azurerm_postgresql_server.server.id

  }
}
