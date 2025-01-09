locals {
  iam_account_map = tomap({
    for group in var.iam_account_groups : group.group_name => group.entitlements
    if group.group_name != null
  })
}

resource "databricks_group" "this" {
  count = var.cloud_name == "azure" && length(local.iam_account_map) == 0 ? length(toset(keys(var.iam_workspace_groups))) : 0

  display_name = keys(var.iam_workspace_groups)[count.index]

  lifecycle {
    ignore_changes = [external_id, allow_cluster_create, allow_instance_pool_create, databricks_sql_access, workspace_access]
  }
}

resource "databricks_entitlements" "this" {
  for_each = local.iam_account_map

  group_id                   = data.databricks_group.account_groups[each.key].id
  allow_cluster_create       = contains(coalesce(each.value, ["none"]), "allow_cluster_create")
  allow_instance_pool_create = contains(coalesce(each.value, ["none"]), "allow_instance_pool_create")
  databricks_sql_access      = contains(coalesce(each.value, ["none"]), "databricks_sql_access")
  workspace_access           = true
}
