locals {
  catalogs_flat = {
    for item in flatten([
      for inst_key, inst in var.lakebase_instance : [
        for cat in inst.catalogs : {
          key = "${inst_key}_${cat.name}"
          value = {
            database_instance_key         = inst_key
            name                          = cat.name
            database_name                 = cat.database_name
            create_database_if_not_exists = cat.create_database_if_not_exists
            grants                        = cat.grants
          }
        }
      ]
    ]) : item.key => item.value
  }
}

resource "databricks_database_instance" "this" {
  for_each = length(var.lakebase_instance) > 0 ? var.lakebase_instance : {}

  name                        = each.value.name
  capacity                    = each.value.capacity
  node_count                  = each.value.node_count
  enable_readable_secondaries = each.value.enable_readable_secondaries
  retention_window_in_days    = each.value.retention_window_in_days
  enable_pg_native_login      = each.value.enable_pg_native_login
  purge_on_delete             = each.value.purge_on_delete
}

resource "databricks_database_database_catalog" "this" {
  for_each = length(local.catalogs_flat) > 0 ? local.catalogs_flat : {}

  name                          = each.value.name
  database_instance_name        = databricks_database_instance.this[each.value.database_instance_key].name
  database_name                 = each.value.database_name
  create_database_if_not_exists = each.value.create_database_if_not_exists
}

resource "databricks_grants" "this" {
  for_each = {
    for v in local.catalogs_flat : v.name => v
    if length(v.grants) != 0
  }

  catalog = each.value.name

  dynamic "grant" {
    for_each = each.value.grants
    content {
      principal  = grant.value.principal
      privileges = grant.value.privileges
    }
  }

  depends_on = [
    databricks_database_database_catalog.this
  ]
}

resource "databricks_permissions" "this" {
  for_each = var.lakebase_instance

  database_instance_name = databricks_database_instance.this[each.key].name

  dynamic "access_control" {
    for_each = each.value.access_control
    content {
      user_name        = access_control.value.user_name
      permission_level = access_control.value.permission_level
    }
  }
}
