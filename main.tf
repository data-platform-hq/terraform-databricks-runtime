resource "databricks_workspace_conf" "this" {
  custom_config = var.custom_config
}

resource "databricks_ip_access_list" "allowed_list" {
  label        = "allow_in"
  list_type    = "ALLOW"
  ip_addresses = flatten([for v in values(var.ip_addresses) : v])

  depends_on = [databricks_workspace_conf.this]
}

resource "databricks_token" "pat" {
  count            = var.workspace_admin_token_enabled ? 1 : 0
  comment          = "Terraform Provisioning"
  lifetime_seconds = var.pat_token_lifetime_seconds
}

resource "databricks_system_schema" "this" {
  for_each = var.system_schemas_enabled ? var.system_schemas : toset([])

  schema = each.value
}
