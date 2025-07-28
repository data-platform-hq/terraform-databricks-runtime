resource "databricks_database_instance" "this" {
  for_each = var.lakebase_instance

  name                        = each.value.name
  capacity                    = each.value.capacity
  node_count                  = each.value.node_count
  enable_readable_secondaries = each.value.enable_readable_secondaries
  retention_window_in_days    = each.value.retention_window_in_days
}
