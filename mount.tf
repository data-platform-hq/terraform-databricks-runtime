resource "databricks_mount" "adls" {
  for_each = var.mount_enabled && var.cloud_name == "azure" ? var.mountpoints : {}

  name       = each.key
  cluster_id = var.mount_cluster_name != null ? databricks_cluster.this[var.mount_cluster_name].id : null
  uri        = "abfss://${each.value["container_name"]}@${each.value["storage_account_name"]}.dfs.core.windows.net"
  extra_configs = {
    "fs.azure.account.auth.type" : "OAuth",
    "fs.azure.account.oauth.provider.type" : "org.apache.hadoop.fs.azurebfs.oauth2.ClientCredsTokenProvider",
    "fs.azure.account.oauth2.client.id" : var.mount_service_principal_client_id,
    "fs.azure.account.oauth2.client.secret" : databricks_secret.main["mount-sp-secret"].config_reference,
    "fs.azure.account.oauth2.client.endpoint" : "https://login.microsoftonline.com/${var.mount_service_principal_tenant_id}/oauth2/token",
    "fs.azure.createRemoteFileSystemDuringInitialization" : "false",
  }
}
