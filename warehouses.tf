locals {
  suffix = length(var.suffix) == 0 ? "" : "-${var.suffix}"

  # Handle tags for AWS
  aws_tags = var.cloud_name == "aws" ? {
    custom_tags = {
      key   = "key"
      value = "value"
    }
  } : {}
}

resource "databricks_sql_endpoint" "this" {
  for_each = { for endpoint in var.sql_endpoint : endpoint.name => endpoint }

  name                      = "${each.key}${local.suffix}"
  cluster_size              = each.value.cluster_size
  auto_stop_mins            = each.value.auto_stop_mins
  max_num_clusters          = each.value.max_num_clusters
  enable_photon             = each.value.enable_photon
  enable_serverless_compute = each.value.enable_serverless_compute
  spot_instance_policy      = each.value.spot_instance_policy
  warehouse_type            = each.value.warehouse_type

  # Dynamic AWS tags block
  dynamic "tags" {
    for_each = var.cloud_name == "aws" ? [local.aws_tags] : []
    content {
      custom_tags {
        key   = tags.value.custom_tags.key
        value = tags.value.custom_tags.value
      }
    }
  }
}

resource "databricks_permissions" "sql_endpoint" {
  for_each = {
    for endpoint in var.sql_endpoint : endpoint.name => endpoint
    if length(endpoint.permissions) != 0
  }

  sql_endpoint_id = databricks_sql_endpoint.this[each.key].id

  dynamic "access_control" {
    for_each = {
      for perm in each.value.permissions : perm.group_name => perm
    }
    content {
      group_name       = access_control.value.group_name
      permission_level = access_control.value.permission_level
    }
  }
}
