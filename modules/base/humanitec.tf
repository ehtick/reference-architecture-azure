# Humanitec resource definition to connect the cluster to Humanitec

resource "humanitec_resource_account" "cluster_account" {
  id   = var.cluster_name
  name = var.cluster_name
  type = "azure-identity"

  credentials = jsonencode({
    "azure_identity_tenant_id" : azuread_service_principal.humanitec.application_tenant_id
    "azure_identity_client_id" : azuread_service_principal.humanitec.client_id
  })
}

resource "humanitec_resource_definition" "k8s_cluster_driver" {
  driver_type = "humanitec/k8s-cluster-aks"
  id          = var.cluster_name
  name        = var.cluster_name
  type        = "k8s-cluster"

  driver_account = humanitec_resource_account.cluster_account.id
  driver_inputs = {
    values_string = jsonencode({
      "loadbalancer" : azurerm_public_ip.ingress.ip_address
      "name" : module.azure_aks.aks_name
      "resource_group" : azurerm_resource_group.main.name
      "subscription_id" : var.subscription_id,
      "server_app_id" : data.azuread_service_principal.aks.client_id
    })
  }
}

resource "humanitec_resource_definition_criteria" "k8s_cluster_driver" {
  resource_definition_id = humanitec_resource_definition.k8s_cluster_driver.id
  env_type               = var.environment
}

resource "humanitec_resource_definition" "k8s_namespace" {
  driver_type = "humanitec/echo"
  id          = "default-namespace"
  name        = "default-namespace"
  type        = "k8s-namespace"

  driver_inputs = {
    values_string = jsonencode({
      "namespace" = "$${context.app.id}-$${context.env.id}"
    })
  }
}

resource "humanitec_resource_definition_criteria" "k8s_namespace" {
  resource_definition_id = humanitec_resource_definition.k8s_namespace.id
}

# in-cluster postgres

module "default_postgres" {
  source = "github.com/humanitec-architecture/resource-packs-in-cluster//humanitec-resource-defs/postgres/basic?ref=v2024-11-05"

  prefix = "default-"
}

resource "humanitec_resource_definition_criteria" "default_postgres" {
  resource_definition_id = module.default_postgres.id
  env_type               = var.environment
}

module "default_mysql" {
  source = "github.com/humanitec-architecture/resource-packs-in-cluster//humanitec-resource-defs/mysql/basic?ref=v2024-11-05"

  prefix = "default-"
}

resource "humanitec_resource_definition_criteria" "default_mysql" {
  resource_definition_id = module.default_mysql.id
  env_type               = var.environment
}

resource "humanitec_resource_definition" "emptydir_volume" {
  driver_type = "humanitec/template"
  id          = "volume-emptydir"
  name        = "volume-emptydir"
  type        = "volume"
  driver_inputs = {
    values_string = jsonencode({
      "templates" = {
        "manifests" = {
          "emptydir.yaml" = {
            "location" = "volumes"
            "data"     = <<END_OF_TEXT
name: $${context.res.guresid}-emptydir
emptyDir:
  sizeLimit: 1024Mi
END_OF_TEXT
          }
        }
      }
    })
  }
}

resource "humanitec_resource_definition_criteria" "emptydir_volume" {
  resource_definition_id = humanitec_resource_definition.emptydir_volume.id
  env_type               = var.environment

  force_delete = true
}
