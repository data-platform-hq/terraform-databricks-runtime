data "databricks_group" "account_groups" {
  for_each = local.iam_account_map

  display_name = each.key
}

data "databricks_current_metastore" "this" {
}

data "databricks_sql_warehouses" "all" {
}
