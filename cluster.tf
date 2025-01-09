locals {
  spark_conf_single_node = var.cloud_name == "azure" ? {
    "spark.master"                     = "local[*]",
    "spark.databricks.cluster.profile" = "singleNode"
  } : {}

  default_node_type_ids = {
    azure_node_type_id = "Standard_D4ds_v5"
    aws_node_type_id   = "m5d.large"
    # gcp_node_type_id   = "gcp-default-node-type-id"
  }
}

resource "databricks_cluster" "this" {
  for_each = { for cluster in var.clusters : cluster.cluster_name => cluster }

  cluster_name            = each.value.cluster_name
  spark_version           = each.value.spark_version
  node_type_id            = coalesce(each.value.node_type_id, local.default_node_type_ids["${var.cloud_name}_node_type_id"])
  autotermination_minutes = each.value.autotermination_minutes
  data_security_mode      = each.value.data_security_mode
  custom_tags             = var.cloud_name == "azure" && each.value.single_node_enable ? merge({ "ResourceClass" = "SingleNode" }, each.value.custom_tags) : each.value.custom_tags

  # Conditional configuration for Spark Conf 
  spark_conf = merge(
    each.value.single_node_enable == true ? local.spark_conf_single_node : {},
    each.value.spark_conf
  )

  # Autoscaling block 
  dynamic "autoscale" {
    for_each = !each.value.single_node_enable ? [1] : []
    content {
      min_workers = each.value.min_workers
      max_workers = each.value.max_workers
    }
  }

  # Specific attributes for AWS
  dynamic "aws_attributes" {
    for_each = var.cloud_name == "aws" ? [each.value] : []
    content {
      availability           = each.value.aws_attributes.availability
      zone_id                = each.value.aws_attributes.zone_id
      first_on_demand        = each.value.aws_attributes.first_on_demand
      spot_bid_price_percent = each.value.aws_attributes.spot_bid_price_percent
      ebs_volume_count       = each.value.aws_attributes.ebs_volume_count
      ebs_volume_size        = each.value.aws_attributes.ebs_volume_size
      ebs_volume_type        = each.value.aws_attributes.ebs_volume_type
    }
  }

  # Specific attributes for Azure
  dynamic "azure_attributes" {
    for_each = var.cloud_name == "azure" ? [each.value] : []
    content {
      availability       = each.value.azure_attributes.availability
      first_on_demand    = each.value.azure_attributes.first_on_demand
      spot_bid_max_price = each.value.azure_attributes.spot_bid_max_price
    }
  }

  # Specific configurations
  dynamic "cluster_log_conf" {
    for_each = var.cloud_name == "azure" && each.value.cluster_log_conf_destination != null ? [each.value.cluster_log_conf_destination] : []
    content {
      dynamic "dbfs" {
        for_each = var.cloud_name == "azure" ? [1] : []
        content {
          destination = cluster_log_conf.value
        }
      }

      # TODO
      # dynamic "s3" {
      #   for_each = var.cloud_name == "aws" ? [1] : []
      #   content {
      #     destination = "s3://acmecorp-main/cluster-logs"
      #     region      = var.region
      #   }
      # }
    }
  }

  dynamic "init_scripts" {
    for_each = each.value.init_scripts_workspace != null ? each.value.init_scripts_workspace : []
    content {
      workspace {
        destination = init_scripts.value
      }
    }
  }

  dynamic "init_scripts" {
    for_each = each.value.init_scripts_volumes != null ? each.value.init_scripts_volumes : []
    content {
      volumes {
        destination = init_scripts.value
      }
    }
  }

  dynamic "init_scripts" {
    for_each = var.cloud_name == "azure" && each.value.init_scripts_dbfs != null ? each.value.init_scripts_dbfs : []
    content {
      dbfs {
        destination = init_scripts.value
      }
    }
  }

  dynamic "init_scripts" {
    for_each = var.cloud_name == "azure" && each.value.init_scripts_abfss != null ? each.value.init_scripts_abfss : []
    content {
      abfss {
        destination = init_scripts.value
      }
    }
  }

  # Library configurations
  dynamic "library" {
    for_each = each.value.pypi_library_repository != null ? each.value.pypi_library_repository : []
    content {
      pypi {
        package = library.value
      }
    }
  }

  dynamic "library" {
    for_each = each.value.maven_library_repository != null ? each.value.maven_library_repository : []
    content {
      maven {
        coordinates = library.value.coordinates
        exclusions  = library.value.exclusions
      }
    }
  }
}

resource "databricks_cluster_policy" "this" {
  for_each = { for param in var.custom_cluster_policies : (param.name) => param.definition
    if param.definition != null
  }

  name       = each.key
  definition = jsonencode(each.value)
}

resource "databricks_cluster_policy" "overrides" {
  for_each = { for param in var.default_cluster_policies_override : (param.name) => param
    if param.definition != null
  }

  policy_family_id                   = each.value.family_id
  policy_family_definition_overrides = jsonencode(each.value.definition)
  name                               = each.key
}

resource "databricks_permissions" "policy" {
  for_each = { for param in var.custom_cluster_policies : param.name => param.can_use
    if param.can_use != null
  }

  cluster_policy_id = databricks_cluster_policy.this[each.key].id

  dynamic "access_control" {
    for_each = each.value
    content {
      group_name       = access_control.value
      permission_level = "CAN_USE"
    }
  }
}

resource "databricks_permissions" "clusters" {
  for_each = {
    for v in var.clusters : (v.cluster_name) => v
    if length(v.permissions) != 0
  }

  cluster_id = databricks_cluster.this[each.key].id

  dynamic "access_control" {
    for_each = each.value.permissions
    content {
      group_name       = access_control.value.group_name
      permission_level = access_control.value.permission_level
    }
  }
}
