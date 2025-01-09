locals {
  mount_sp_secrets = var.cloud_name == "azure" ? {
    mount_sp_client_id = { value = var.mount_configuration.service_principal.client_id }
    mount_sp_secret    = { value = var.mount_configuration.service_principal.client_secret }
  } : {}
}

resource "databricks_mount" "adls" {
  for_each = var.mount_enabled && var.cloud_name == "azure" ? var.mountpoints : {}

  name = each.key
  uri  = "abfss://${each.value["container_name"]}@${each.value["storage_account_name"]}.dfs.core.windows.net"
  extra_configs = {
    "fs.azure.account.auth.type" : "OAuth",
    "fs.azure.account.oauth.provider.type" : "org.apache.hadoop.fs.azurebfs.oauth2.ClientCredsTokenProvider",
    "fs.azure.account.oauth2.client.id" : var.mount_configuration.service_principal.client_id,
    "fs.azure.account.oauth2.client.secret" : databricks_secret.main["mount-sp-secret"].config_reference,
    "fs.azure.account.oauth2.client.endpoint" : "https://login.microsoftonline.com/${var.mount_configuration.service_principal.tenant_id}/oauth2/token",
    "fs.azure.createRemoteFileSystemDuringInitialization" : "false",
  }
}
