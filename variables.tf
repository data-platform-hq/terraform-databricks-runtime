variable "cloud_name" {
  type        = string
  description = "Cloud Name"
}

variable "workspace_admin_token_enabled" {
  type        = bool
  description = "Boolean flag to specify whether to create Workspace Admin Token"
}

variable "suffix" {
  type        = string
  description = "Optional suffix that would be added to the end of resources names."
  default     = ""
}

# Identity Access Management variables

variable "iam_account_groups" {
  type = list(object({
    group_name   = optional(string)
    entitlements = optional(list(string))
  }))
  description = "List of objects with group name and entitlements for this group"
  default     = []
}

variable "iam_workspace_groups" {
  type = map(object({
    user              = optional(list(string))
    service_principal = optional(list(string))
    entitlements      = optional(list(string))
  }))
  description = "Used to create workspace group. Map of group name and its parameters, such as users and service principals added to the group. Also possible to configure group entitlements."
  default     = {}

  validation {
    condition = length([for item in values(var.iam_workspace_groups)[*] : item.entitlements if item.entitlements != null]) != 0 ? alltrue([
      for entry in flatten(values(var.iam_workspace_groups)[*].entitlements) : contains(["allow_cluster_create", "allow_instance_pool_create", "databricks_sql_access"], entry) if entry != null
    ]) : true
    error_message = "Entitlements validation. The only suitable values are: databricks_sql_access, allow_instance_pool_create, allow_cluster_create"
  }
}

# SQL Endpoint variables
variable "sql_endpoint" {
  type = set(object({
    name                      = string
    cluster_size              = optional(string, "2X-Small")
    min_num_clusters          = optional(number, 0)
    max_num_clusters          = optional(number, 1)
    auto_stop_mins            = optional(string, "30")
    enable_photon             = optional(bool, false)
    enable_serverless_compute = optional(bool, false)
    spot_instance_policy      = optional(string, "COST_OPTIMIZED")
    warehouse_type            = optional(string, "PRO")
    permissions = optional(set(object({
      group_name       = string
      permission_level = string
    })), [])
  }))
  description = "Set of objects with parameters to configure SQL Endpoint and assign permissions to it for certain custom groups"
  default     = []
}

# Secret Scope variables
variable "secret_scope" {
  type = list(object({
    scope_name = string
    scope_acl = optional(list(object({
      principal  = string
      permission = string
    })))
    secrets = optional(list(object({
      key          = string
      string_value = string
    })))
  }))
  description = <<-EOT
Provides an ability to create custom Secret Scope, store secrets in it and assigning ACL for access management
scope_name - name of Secret Scope to create;
acl - list of objects, where 'principal' custom group name, this group is created in 'Premium' module; 'permission' is one of "READ", "WRITE", "MANAGE";
secrets - list of objects, where object's 'key' param is created key name and 'string_value' is a value for it;
EOT
  default     = []
}

# Azure Key Vault-backed Secret Scope
variable "key_vault_secret_scope" {
  type = list(object({
    name         = string
    key_vault_id = string
    dns_name     = string
    tenant_id    = string
  }))
  description = "Object with Azure Key Vault parameters required for creation of Azure-backed Databricks Secret scope"
  default     = []
}

variable "custom_cluster_policies" {
  type = list(object({
    name       = string
    can_use    = list(string)
    definition = any
  }))
  description = <<-EOT
Provides an ability to create custom cluster policy, assign it to cluster and grant CAN_USE permissions on it to certain custom groups
name - name of custom cluster policy to create
can_use - list of string, where values are custom group names, there groups have to be created with Terraform;
definition - JSON document expressed in Databricks Policy Definition Language. No need to call 'jsonencode()' function on it when providing a value;
EOT
  default = [{
    name       = null
    can_use    = null
    definition = null
  }]
}

variable "clusters" {
  type = set(object({
    cluster_name       = string
    spark_version      = optional(string, "15.3.x-scala2.12")
    spark_conf         = optional(map(any), {})
    spark_env_vars     = optional(map(any), {})
    data_security_mode = optional(string, "USER_ISOLATION")
    aws_attributes = optional(object({
      availability           = optional(string)
      zone_id                = optional(string)
      first_on_demand        = optional(number)
      spot_bid_price_percent = optional(number)
      ebs_volume_count       = optional(number)
      ebs_volume_size        = optional(number)
      ebs_volume_type        = optional(string)
      }), {
      availability           = "ON_DEMAND"
      zone_id                = "auto"
      first_on_demand        = 0
      spot_bid_price_percent = 100
      ebs_volume_count       = 1
      ebs_volume_size        = 100
      ebs_volume_type        = "GENERAL_PURPOSE_SSD"
    })
    azure_attributes = optional(object({
      availability       = optional(string)
      first_on_demand    = optional(number)
      spot_bid_max_price = optional(number, 1)
      }), {
      availability    = "ON_DEMAND_AZURE"
      first_on_demand = 0
    })
    node_type_id                 = optional(string, null)
    autotermination_minutes      = optional(number, 20)
    min_workers                  = optional(number, 1)
    max_workers                  = optional(number, 2)
    cluster_log_conf_destination = optional(string, null)
    init_scripts_workspace       = optional(set(string), [])
    init_scripts_volumes         = optional(set(string), [])
    init_scripts_dbfs            = optional(set(string), [])
    init_scripts_abfss           = optional(set(string), [])
    single_user_name             = optional(string, null)
    single_node_enable           = optional(bool, false)
    custom_tags                  = optional(map(string), {})
    permissions = optional(set(object({
      group_name       = string
      permission_level = string
    })), [])
    pypi_library_repository = optional(set(string), [])
    maven_library_repository = optional(set(object({
      coordinates = string
      exclusions  = set(string)
    })), [])
  }))
  description = "Set of objects with parameters to configure Databricks clusters and assign permissions to it for certain custom groups"
  default     = []
}

variable "pat_token_lifetime_seconds" {
  type        = number
  description = "The lifetime of the token, in seconds. If no lifetime is specified, the token remains valid indefinitely"
  default     = 315569520
}

# Mount ADLS Gen2 Filesystem
variable "mount_enabled" {
  type        = bool
  description = "Boolean flag that determines whether mount point for storage account filesystem is created"
  default     = false
}

variable "mount_configuration" {
  type = object({
    service_principal = object({
      client_id     = string
      client_secret = string
      tenant_id     = string
    })
  })
  description = "Configuration for mounting storage, including only service principal details"
  default = {
    service_principal = {
      client_id     = null
      client_secret = null
      tenant_id     = null
    }
  }
  sensitive = true
}

variable "mountpoints" {
  type = map(object({
    storage_account_name = string
    container_name       = string
  }))
  description = "Mountpoints for databricks"
  default     = {}
}

variable "system_schemas" {
  type        = set(string)
  description = "Set of strings with all possible System Schema names"
  default     = ["access", "billing", "compute", "marketplace", "storage"]
}

variable "system_schemas_enabled" {
  type        = bool
  description = "System Schemas only works with assigned Unity Catalog Metastore. Boolean flag to enabled this feature"
  default     = false
}

variable "default_cluster_policies_override" {
  type = list(object({
    name       = string
    family_id  = string
    definition = any
  }))
  description = <<-EOT
Provides an ability to override default cluster policy
name - name of cluster policy to override
family_id - family id of corresponding policy
definition - JSON document expressed in Databricks Policy Definition Language. No need to call 'jsonencode()' function on it when providing a value;
EOT
  default = [{
    name       = null
    family_id  = null
    definition = null
  }]
}

variable "custom_config" {
  type        = map(string)
  description = "Map of AD databricks workspace custom config"
  default = {
    "enableResultsDownloading"                         = "false", # https://docs.databricks.com/en/notebooks/notebook-outputs.html#download-results
    "enableNotebookTableClipboard"                     = "false", # https://docs.databricks.com/en/administration-guide/workspace-settings/notebooks.html#enable-users-to-copy-data-to-the-clipboard-from-notebooks
    "enableVerboseAuditLogs"                           = "true",  # https://docs.databricks.com/en/administration-guide/account-settings/verbose-logs.html
    "enable-X-Frame-Options"                           = "true",
    "enable-X-Content-Type-Options"                    = "true",
    "enable-X-XSS-Protection"                          = "true",
    "enableDbfsFileBrowser"                            = "false", # https://docs.databricks.com/en/administration-guide/workspace-settings/dbfs-browser.html
    "enableExportNotebook"                             = "false", # https://docs.databricks.com/en/administration-guide/workspace-settings/notebooks.html#enable-users-to-export-notebooks
    "enforceUserIsolation"                             = "true",  # https://docs.databricks.com/en/administration-guide/workspace-settings/enforce-user-isolation.html
    "storeInteractiveNotebookResultsInCustomerAccount" = "true",  # https://docs.databricks.com/en/administration-guide/workspace-settings/notebooks.html#manage-where-notebook-results-are-stored
    "enableUploadDataUis"                              = "false", # https://docs.databricks.com/en/ingestion/add-data/index.html
    "enableIpAccessLists"                              = "true"
  }
}

variable "ip_addresses" {
  type        = map(string)
  description = "A map of IP address ranges"
  default = {
    "all" = "0.0.0.0/0"
  }
}
