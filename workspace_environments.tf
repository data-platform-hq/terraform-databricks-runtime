resource "databricks_environments_workspace_base_environment" "this" {
  for_each = var.workspace_base_environments

  display_name          = each.value.display_name
  filepath              = each.value.filepath
  base_environment_type = each.value.base_environment_type
}

resource "databricks_environments_default_workspace_base_environment" "this" {
  count = (
    contains(keys(var.workspace_base_environments), "cpu") ||
    contains(keys(var.workspace_base_environments), "gpu")
  ) ? 1 : 0

  cpu_workspace_base_environment = (
    try(var.workspace_base_environments.cpu.set_as_default, false)
    ? databricks_environments_workspace_base_environment.this["cpu"].name
    : null
  )

  gpu_workspace_base_environment = (
    try(var.workspace_base_environments.gpu.set_as_default, false)
    ? databricks_environments_workspace_base_environment.this["gpu"].name
    : null
  )
}
