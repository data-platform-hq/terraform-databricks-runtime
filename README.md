# Databricks Premium Runtime Terraform module
Terraform module for creation Databricks Premium Runtime

## Usage
### **Requires Workspace with "Premium" SKU** 

The main idea behind this module is to deploy resources for Databricks Workspace with Premium SKU only.

Here we provide some examples of how to provision it with a different options.

### In example below, these features of given module would be covered:
1. Workspace admins assignment, custom Workspace group creation, group assignments, group entitlements
2. Clusters (i.e., for Unity Catalog and Shared Autoscaling)             
3. Workspace IP Access list creation                                     
4. ADLS Gen2 Mount                                                       
5. Create Secret Scope and assign permissions to custom groups                                                  
6. SQL Endpoint creation and configuration                               
7. Create Cluster policy                                                 
8. Create an Azure Key Vault-backed secret scope                         
9. Connect to already existing Unity Catalog Metastore                   

```hcl
# Prerequisite resources

# Databricks Workspace with Premium SKU
data "azurerm_databricks_workspace" "example" {
  name                = "example-workspace"
  resource_group_name = "example-rg"
}

# Databricks Provider configuration
provider "databricks" {
  alias                       = "main"
  host                        = data.azurerm_databricks_workspace.example.workspace_url
  azure_workspace_resource_id = data.azurerm_databricks_workspace.example.id
}

# Key Vault where Service Principal's secrets are stored. Used for mounting Storage Container
data "azurerm_key_vault" "example" {
  name                = "example-key-vault"
  resource_group_name = "example-rg"
}

# Example usage of module for Runtime Premium resources.
module "databricks_runtime_premium" {
  source  = "data-platform-hq/databricks-runtime-premium/databricks"

  project  = "datahq"
  env      = "example"
  location = "eastus"

  # Parameters of Service principal used for ADLS mount
  # Imports App ID and Secret of Service Principal from target Key Vault
  key_vault_id             =  data.azurerm_key_vault.example.id
  sp_client_id_secret_name = "sp-client-id" # secret's name that stores Service Principal App ID
  sp_key_secret_name       = "sp-key" # secret's name that stores Service Principal Secret Key
  tenant_id_secret_name    = "infra-arm-tenant-id" # secret's name that stores tenant id value

  # 1.1 Workspace admins 
  workspace_admins = {
    user = ["user1@example.com"]
    service_principal = ["example-app-id"]
  }

  # 1.2 Custom Workspace group with assignments.
  # In addition, provides an ability to create group and entitlements.
  iam = [{
    group_name = "DEVELOPERS"
    permissions  = ["ADMIN"]
    entitlements = [
      "allow_instance_pool_create",
      "allow_cluster_create",
      "databricks_sql_access"
    ] 
  }]

  # 2. Databricks clusters configuration, and assign permission to a custom group on clusters.
  databricks_cluster_configs = [ {
    cluster_name       = "Unity Catalog"
    data_security_mode = "USER_ISOLATION"
    availability       = "ON_DEMAND_AZURE"
    spot_bid_max_price = 1
    permissions        = [{ group_name = "DEVELOPERS", permission_level = "CAN_RESTART" }]
  },
  {
    cluster_name       = "shared autoscaling"
    data_security_mode = "NONE"
    availability       = "SPOT_AZURE"
    spot_bid_max_price = -1
    permissions        = [{group_name = "DEVELOPERS", permission_level = "CAN_MANAGE"}]
  }]

  # 3. Workspace could be accessed only from these IP Addresses:
  ip_rules = {
    "ip_range_1" = "10.128.0.0/16",
    "ip_range_2" = "10.33.0.0/16",
  }
  
  # 4. ADLS Gen2 Mount
  mountpoints = {
    storage_account_name = data.azurerm_storage_account.example.name
    container_name       = "example_container"
  }

  # 5. Create Secret Scope and assign permissions to custom groups 
  secret_scope = [{
    scope_name = "extra-scope"
    acl        = [{ principal = "DEVELOPERS", permission = "READ" }] # Only custom workspace group names are allowed. If left empty then only Workspace admins could access these keys
    secrets    = [{ key = "secret-name", string_value = "secret-value"}]
  }]

  # 6. SQL Warehouse Endpoint
  databricks_sql_endpoint = [{
    name        = "default"  
    enable_serverless_compute = true  
    permissions = [{ group_name = "DEVELOPERS", permission_level = "CAN_USE" },]
  }]

  # 7. Databricks cluster policies
  custom_cluster_policies = [{
    name     = "custom_policy_1",
    can_use  =  "DEVELOPERS", # custom workspace group name, that is allowed to use this policy
    definition = {
      "autoscale.max_workers": {
        "type": "range",
        "maxValue": 3,
        "defaultValue": 2
      },
    }
  }]

  # 8. Azure Key Vault-backed secret scope
  key_vault_secret_scope = [{
    name         = "external"
    key_vault_id = data.azurerm_key_vault.example.id
    dns_name     = data.azurerm_key_vault.example.vault_uri
  }]  
    
  providers = {
    databricks = databricks.main
  }
}

# 9 Assignment already existing Unity Catalog Metastore
module "metastore_assignment" {
  source  = "data-platform-hq/metastore-assignment/databricks"
  version = "1.0.0"

  workspace_id = data.azurerm_databricks_workspace.example.workspace_id
  metastore_id = "<uuid-of-metastore>"

  providers = {
    databricks = databricks.workspace
  }
}

```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_databricks"></a> [databricks](#requirement\_databricks) | ~>1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_databricks"></a> [databricks](#provider\_databricks) | ~>1.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [databricks_cluster.this](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/cluster) | resource |
| [databricks_cluster_policy.overrides](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/cluster_policy) | resource |
| [databricks_cluster_policy.this](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/cluster_policy) | resource |
| [databricks_entitlements.this](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/entitlements) | resource |
| [databricks_group.this](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/group) | resource |
| [databricks_ip_access_list.allowed_list](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/ip_access_list) | resource |
| [databricks_mount.adls](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/mount) | resource |
| [databricks_permissions.clusters](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/permissions) | resource |
| [databricks_permissions.policy](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/permissions) | resource |
| [databricks_permissions.sql_endpoint](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/permissions) | resource |
| [databricks_secret.main](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/secret) | resource |
| [databricks_secret.this](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/secret) | resource |
| [databricks_secret_acl.this](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/secret_acl) | resource |
| [databricks_secret_scope.main](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/secret_scope) | resource |
| [databricks_secret_scope.this](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/secret_scope) | resource |
| [databricks_sql_endpoint.this](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/sql_endpoint) | resource |
| [databricks_system_schema.this](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/system_schema) | resource |
| [databricks_token.pat](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/token) | resource |
| [databricks_workspace_conf.this](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/workspace_conf) | resource |
| [databricks_current_metastore.this](https://registry.terraform.io/providers/databricks/databricks/latest/docs/data-sources/current_metastore) | data source |
| [databricks_group.account_groups](https://registry.terraform.io/providers/databricks/databricks/latest/docs/data-sources/group) | data source |
| [databricks_sql_warehouses.all](https://registry.terraform.io/providers/databricks/databricks/latest/docs/data-sources/sql_warehouses) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloud_name"></a> [cloud\_name](#input\_cloud\_name) | Cloud Name | `string` | n/a | yes |
| <a name="input_clusters"></a> [clusters](#input\_clusters) | Set of objects with parameters to configure Databricks clusters and assign permissions to it for certain custom groups | <pre>set(object({<br>    cluster_name       = string<br>    spark_version      = optional(string, "15.3.x-scala2.12")<br>    spark_conf         = optional(map(any), {})<br>    spark_env_vars     = optional(map(any), {})<br>    data_security_mode = optional(string, "USER_ISOLATION")<br>    aws_attributes = optional(object({<br>      availability           = optional(string)<br>      zone_id                = optional(string)<br>      first_on_demand        = optional(number)<br>      spot_bid_price_percent = optional(number)<br>      ebs_volume_count       = optional(number)<br>      ebs_volume_size        = optional(number)<br>      ebs_volume_type        = optional(string)<br>      }), {<br>      availability           = "ON_DEMAND"<br>      zone_id                = "auto"<br>      first_on_demand        = 0<br>      spot_bid_price_percent = 100<br>      ebs_volume_count       = 1<br>      ebs_volume_size        = 100<br>      ebs_volume_type        = "GENERAL_PURPOSE_SSD"<br>    })<br>    azure_attributes = optional(object({<br>      availability       = optional(string)<br>      first_on_demand    = optional(number)<br>      spot_bid_max_price = optional(number, 1)<br>      }), {<br>      availability    = "ON_DEMAND_AZURE"<br>      first_on_demand = 0<br>    })<br>    node_type_id                 = optional(string, null)<br>    autotermination_minutes      = optional(number, 20)<br>    min_workers                  = optional(number, 1)<br>    max_workers                  = optional(number, 2)<br>    cluster_log_conf_destination = optional(string, null)<br>    init_scripts_workspace       = optional(set(string), [])<br>    init_scripts_volumes         = optional(set(string), [])<br>    init_scripts_dbfs            = optional(set(string), [])<br>    init_scripts_abfss           = optional(set(string), [])<br>    single_user_name             = optional(string, null)<br>    single_node_enable           = optional(bool, false)<br>    custom_tags                  = optional(map(string), {})<br>    permissions = optional(set(object({<br>      group_name       = string<br>      permission_level = string<br>    })), [])<br>    pypi_library_repository = optional(set(string), [])<br>    maven_library_repository = optional(set(object({<br>      coordinates = string<br>      exclusions  = set(string)<br>    })), [])<br>  }))</pre> | `[]` | no |
| <a name="input_custom_cluster_policies"></a> [custom\_cluster\_policies](#input\_custom\_cluster\_policies) | Provides an ability to create custom cluster policy, assign it to cluster and grant CAN\_USE permissions on it to certain custom groups<br>name - name of custom cluster policy to create<br>can\_use - list of string, where values are custom group names, there groups have to be created with Terraform;<br>definition - JSON document expressed in Databricks Policy Definition Language. No need to call 'jsonencode()' function on it when providing a value; | <pre>list(object({<br>    name       = string<br>    can_use    = list(string)<br>    definition = any<br>  }))</pre> | <pre>[<br>  {<br>    "can_use": null,<br>    "definition": null,<br>    "name": null<br>  }<br>]</pre> | no |
| <a name="input_custom_config"></a> [custom\_config](#input\_custom\_config) | Map of AD databricks workspace custom config | `map(string)` | <pre>{<br>  "enable-X-Content-Type-Options": "true",<br>  "enable-X-Frame-Options": "true",<br>  "enable-X-XSS-Protection": "true",<br>  "enableDbfsFileBrowser": "false",<br>  "enableExportNotebook": "false",<br>  "enableIpAccessLists": "true",<br>  "enableNotebookTableClipboard": "false",<br>  "enableResultsDownloading": "false",<br>  "enableUploadDataUis": "false",<br>  "enableVerboseAuditLogs": "true",<br>  "enforceUserIsolation": "true",<br>  "storeInteractiveNotebookResultsInCustomerAccount": "true"<br>}</pre> | no |
| <a name="input_default_cluster_policies_override"></a> [default\_cluster\_policies\_override](#input\_default\_cluster\_policies\_override) | Provides an ability to override default cluster policy<br>name - name of cluster policy to override<br>family\_id - family id of corresponding policy<br>definition - JSON document expressed in Databricks Policy Definition Language. No need to call 'jsonencode()' function on it when providing a value; | <pre>list(object({<br>    name       = string<br>    family_id  = string<br>    definition = any<br>  }))</pre> | <pre>[<br>  {<br>    "definition": null,<br>    "family_id": null,<br>    "name": null<br>  }<br>]</pre> | no |
| <a name="input_iam_account_groups"></a> [iam\_account\_groups](#input\_iam\_account\_groups) | List of objects with group name and entitlements for this group | <pre>list(object({<br>    group_name   = optional(string)<br>    entitlements = optional(list(string))<br>  }))</pre> | `[]` | no |
| <a name="input_iam_workspace_groups"></a> [iam\_workspace\_groups](#input\_iam\_workspace\_groups) | Used to create workspace group. Map of group name and its parameters, such as users and service principals added to the group. Also possible to configure group entitlements. | <pre>map(object({<br>    user              = optional(list(string))<br>    service_principal = optional(list(string))<br>    entitlements      = optional(list(string))<br>  }))</pre> | `{}` | no |
| <a name="input_ip_addresses"></a> [ip\_addresses](#input\_ip\_addresses) | A map of IP address ranges | `map(string)` | <pre>{<br>  "all": "0.0.0.0/0"<br>}</pre> | no |
| <a name="input_key_vault_secret_scope"></a> [key\_vault\_secret\_scope](#input\_key\_vault\_secret\_scope) | Object with Azure Key Vault parameters required for creation of Azure-backed Databricks Secret scope | <pre>list(object({<br>    name         = string<br>    key_vault_id = string<br>    dns_name     = string<br>    tenant_id    = string<br>  }))</pre> | `[]` | no |
| <a name="input_mount_configuration"></a> [mount\_configuration](#input\_mount\_configuration) | Configuration for mounting storage, including only service principal details | <pre>object({<br>    service_principal = object({<br>      client_id     = string<br>      client_secret = string<br>      tenant_id     = string<br>    })<br>  })</pre> | <pre>{<br>  "service_principal": {<br>    "client_id": null,<br>    "client_secret": null,<br>    "tenant_id": null<br>  }<br>}</pre> | no |
| <a name="input_mount_enabled"></a> [mount\_enabled](#input\_mount\_enabled) | Boolean flag that determines whether mount point for storage account filesystem is created | `bool` | `false` | no |
| <a name="input_mountpoints"></a> [mountpoints](#input\_mountpoints) | Mountpoints for databricks | <pre>map(object({<br>    storage_account_name = string<br>    container_name       = string<br>  }))</pre> | `{}` | no |
| <a name="input_pat_token_lifetime_seconds"></a> [pat\_token\_lifetime\_seconds](#input\_pat\_token\_lifetime\_seconds) | The lifetime of the token, in seconds. If no lifetime is specified, the token remains valid indefinitely | `number` | `315569520` | no |
| <a name="input_secret_scope"></a> [secret\_scope](#input\_secret\_scope) | Provides an ability to create custom Secret Scope, store secrets in it and assigning ACL for access management<br>scope\_name - name of Secret Scope to create;<br>acl - list of objects, where 'principal' custom group name, this group is created in 'Premium' module; 'permission' is one of "READ", "WRITE", "MANAGE";<br>secrets - list of objects, where object's 'key' param is created key name and 'string\_value' is a value for it; | <pre>list(object({<br>    scope_name = string<br>    scope_acl = optional(list(object({<br>      principal  = string<br>      permission = string<br>    })))<br>    secrets = optional(list(object({<br>      key          = string<br>      string_value = string<br>    })))<br>  }))</pre> | `[]` | no |
| <a name="input_sql_endpoint"></a> [sql\_endpoint](#input\_sql\_endpoint) | Set of objects with parameters to configure SQL Endpoint and assign permissions to it for certain custom groups | <pre>set(object({<br>    name                      = string<br>    cluster_size              = optional(string, "2X-Small")<br>    min_num_clusters          = optional(number, 0)<br>    max_num_clusters          = optional(number, 1)<br>    auto_stop_mins            = optional(string, "30")<br>    enable_photon             = optional(bool, false)<br>    enable_serverless_compute = optional(bool, false)<br>    spot_instance_policy      = optional(string, "COST_OPTIMIZED")<br>    warehouse_type            = optional(string, "PRO")<br>    permissions = optional(set(object({<br>      group_name       = string<br>      permission_level = string<br>    })), [])<br>  }))</pre> | `[]` | no |
| <a name="input_suffix"></a> [suffix](#input\_suffix) | Optional suffix that would be added to the end of resources names. | `string` | `""` | no |
| <a name="input_system_schemas"></a> [system\_schemas](#input\_system\_schemas) | Set of strings with all possible System Schema names | `set(string)` | <pre>[<br>  "access",<br>  "billing",<br>  "compute",<br>  "marketplace",<br>  "storage"<br>]</pre> | no |
| <a name="input_system_schemas_enabled"></a> [system\_schemas\_enabled](#input\_system\_schemas\_enabled) | System Schemas only works with assigned Unity Catalog Metastore. Boolean flag to enabled this feature | `bool` | `false` | no |
| <a name="input_workspace_admin_token_enabled"></a> [workspace\_admin\_token\_enabled](#input\_workspace\_admin\_token\_enabled) | Boolean flag to specify whether to create Workspace Admin Token | `bool` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_clusters"></a> [clusters](#output\_clusters) | Provides name and unique identifier for the clusters |
| <a name="output_metastore_id"></a> [metastore\_id](#output\_metastore\_id) | The ID of the current metastore in the Databricks workspace. |
| <a name="output_sql_endpoint_data_source_id"></a> [sql\_endpoint\_data\_source\_id](#output\_sql\_endpoint\_data\_source\_id) | ID of the data source for this endpoint |
| <a name="output_sql_endpoint_jdbc_url"></a> [sql\_endpoint\_jdbc\_url](#output\_sql\_endpoint\_jdbc\_url) | JDBC connection string of SQL Endpoint |
| <a name="output_sql_warehouses_list"></a> [sql\_warehouses\_list](#output\_sql\_warehouses\_list) | List of IDs of all SQL warehouses in the Databricks workspace. |
| <a name="output_token"></a> [token](#output\_token) | Databricks Personal Authorization Token |
<!-- END_TF_DOCS -->

## License

Apache 2 Licensed. For more information please see [LICENSE](https://github.com/data-platform-hq/terraform-databricks-databricks-runtime-premium/blob/main/LICENSE)
