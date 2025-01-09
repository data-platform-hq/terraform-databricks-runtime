output "sql_endpoint_jdbc_url" {
  value       = [for n in databricks_sql_endpoint.this : n.jdbc_url]
  description = "JDBC connection string of SQL Endpoint"
}

output "sql_endpoint_data_source_id" {
  value       = [for n in databricks_sql_endpoint.this : n.data_source_id]
  description = "ID of the data source for this endpoint"
}

output "token" {
  value       = length(databricks_token.pat) > 0 ? databricks_token.pat[0].token_value : null
  description = "Databricks Personal Authorization Token"
  sensitive   = true
}

output "clusters" {
  value = [for param in var.clusters : {
    name = param.cluster_name
    id   = databricks_cluster.this[param.cluster_name].id
  } if length(var.clusters) != 0]
  description = "Provides name and unique identifier for the clusters"
}

output "sql_warehouses_list" {
  value       = data.databricks_sql_warehouses.all.ids
  description = "List of IDs of all SQL warehouses in the Databricks workspace."
}

output "metastore_id" {
  value       = data.databricks_current_metastore.this.id
  description = "The ID of the current metastore in the Databricks workspace."
}
