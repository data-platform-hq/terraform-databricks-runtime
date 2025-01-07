locals {
  secrets_acl_objects_list = flatten([for param in var.secret_scope : [
    for permission in param.acl : {
      scope = param.scope_name, principal = permission.principal, permission = permission.permission
    }] if param.scope_acl != null
  ])

  secret_scope_config = { for object in var.secret_scope : object.scope_name => object }

  secret_scope_config_secrets = { for object in flatten([for k, v in local.secret_scope_config : [for secret in v.secrets : {
    scope_name   = k,
    secret_key   = secret.key,
    secret_value = secret.string_value,
  }]]) : "${object.scope_name}:${object.secret_key}" => object }
}

# Secret Scope with SP secrets for mounting Azure Data Lake Storage
resource "databricks_secret_scope" "main" {
  count = var.cloud_name == "azure" && var.mount_enabled ? 1 : 0

  name                     = "main"
  initial_manage_principal = null
}

resource "databricks_secret" "main" {
  for_each = var.cloud_name == "azure" && var.mount_enabled ? local.mount_sp_secrets : {}

  key          = each.key
  string_value = each.value["value"]
  scope        = databricks_secret_scope.main[0].id

  lifecycle {
    precondition {
      condition     = var.cloud_name == "azure" && var.mount_enabled ? length(compact([var.mount_service_principal_client_id, var.mount_service_principal_secret, var.mount_service_principal_tenant_id])) == 3 : true
      error_message = "To mount ADLS Storage, please provide prerequisite Service Principal values - 'mount_service_principal_object_id', 'mount_service_principal_secret', 'mount_service_principal_tenant_id'."
    }
  }
}

# Custom additional Databricks Secret Scope
resource "databricks_secret_scope" "this" {
  for_each = {
    for param in var.secret_scope : (param.scope_name) => param
    if param.scope_name != null
  }

  name = each.key

  # Key Vault metadata block only for Azure
  dynamic "keyvault_metadata" {
    for_each = var.cloud_name == "azure" ? [for kv in var.key_vault_secret_scope : kv] : []
    content {
      resource_id = keyvault_metadata.value.key_vault_id
      dns_name    = keyvault_metadata.value.dns_name
    }
  }

  # This property is only relevant for Azure
  initial_manage_principal = var.cloud_name == "azure" ? null : null
}

resource "databricks_secret" "this" {
  for_each = local.secret_scope_config_secrets

  key          = each.value.secret_key
  string_value = each.value.secret_value
  scope        = databricks_secret_scope.this[each.value.scope_name].id
}

resource "databricks_secret_acl" "this" {
  for_each = var.cloud_name == "azure" && length(local.secrets_acl_objects_list) > 0 ? {
    for_each = { for entry in local.secrets_acl_objects_list : "${entry.scope}.${entry.principal}.${entry.permission}" => entry }
  } : {}

  scope      = databricks_secret_scope.this[each.value.scope].name
  principal  = length(var.iam_account_groups) != 0 ? data.databricks_group.account_groups[each.value.principal].display_name : databricks_group.this[each.value.principal].display_name
  permission = each.value.permission
}
