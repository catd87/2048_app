terraform {
  required_providers {
    flux = {
      source  = "fluxcd/flux"
      version = "0.2.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.10.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.2"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "github" {
  token = var.flux_token
}

locals {
  labels_prefix = var.labels_prefix

  flux = merge (
        {
          enabled                  = true
          create_ns                = true
          namespace                = "flux_system_example"
          target_path              = var.target_path
          default_network_policy   = true
          version                  = true
          repo_url                 = var.repo_url
          create_github_repository = false
          repository               = var.repository_name
          repository_visibility    = "public"
          branch                   = var.branch
          flux_sync_branch         = ""
          default_components       = var.default_components
          components               = var.components
          provider                 = var.repo_provider
          auto_image_update        = false
        }
        var.flux2
    )

  apply = local.flux["enabled"] ? [for v in data.kubectl_file_documents.apply[0].documents : {
    data : yamldecode(v)
    content : v
    }
  ] : null 

  sync = local.flux["enabled"] ? [for v in data.kubectl_file_documents.sync[0].documents : {
    data : yamldecode(v)
    content : v
    } 
  ] : null
}

resource "kubernetes_namespace" "flux"{
  count = local.flux[enabled] && local.flux["create_ns"] ? 1 : 0

  metadata {
    labels = {
      name = local.flux["namespace"]
    }

    name = local.flux["namespace"]

  }

  lifecycle {
    ignore_changes = [metada[0].labels,]
  }

}

data "flux_install" "main" {
  count          = local.flux["enabled"] ? 1 : 0
  namespace      = local.flux["namespace"]
  target_path    = local.flux["target_path"]
  network_policy = false
  version = local.flux["version"]
  components = distinct(concat(local.flux["default_components"], local.flux["components"], local.flux["auto_image_update"] ? ["image-reflector-controller", "image-automation-controller"] : []))
}


# Split multi-doc YAML with
# https://registry.terraform.io/providers/gavinbunney/kubectl/latest
data "kubectl_file_documents" "apply" {
  count   = local.flux["enabled"] ? 1 : 0
  content = data.flux_install.main[0].content 
}

# Apply manifests on the cluster
resource "kubectl_manifest" "apply" {
  for_each = local.flux["enabled"] ? { for v in local.sync : ower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content } : {}
  depends_on = [kubernetes_namespace.flux]
  yaml_body = each.value 
}

#Generate manifest
data "flux_sync" "main" {
  count       = local.flux["enabled"] ? 1 : 0
  target_path = local.flux["target_path"]
  url         = local.flux["repo_url"]
  branch      = local.flux["flux_sync_bran"] != "" ? local.flux["flux_sync_branch"] : loca.flux["branch"]
  namespace   = local.flux["namespace"]
}

#split multi-doc YAML with
# https://registry.terraform.io/providers/gavinbunney/kubectl/latest
data "kubectl_file_documents" "sync" {
  count   = local.flux["enabled"] ? 1 : 0
  content = data.flux_install.main[0].content 
}

#Apply manifest on the cluster
resource "kubectl_manifest" "sync" {
  for_each = local.flux["enabled"] ? {for v in local.sync : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content } : {}
  depends_on = [
    kubernetes_namespace.flux,
    kubernetes_manifest.apply
    
  ]
  yaml_body = each.value  
}

#Generate a Kubernates secret wuth the Git credentials
resource "kubernetes_secret" "main" {
  count = local.flux["enabled"] ? 1 : 0
  depends_on = [kubectl_manifest]

  metadata {
    name      = data.flux_sync_main[0].name
    namespace = data.flux_sync_main[0].namespace
  }

  data = {
    name     = "catd87"
    password =  var.flux_token
  }
}

#Github
resource "github_repository" "main" {
  count      = local.flux["enbled"] && local.flux[create_github_repository] && (local.flux["provider"] == "github") ? 1 : 0
  name       = local.flux["repository"]
  visibility = local.flux["repository_visibility"]
  auto_init  = true  
}

data "github_repository" "main" {
  count = local.flux["enabled"] &&!local.flux["create_github_repository"] && (local.flux["provider"] == "github") ? 1 : 0 
  full_name = "${var.github.owner}/${var.repository_name}"  
}

resource "github_branch_default" "main" {
  count      = local.flux["enabled"] && local.flux["create_github_repository"] && (local.flux["provider"] == "github") ? 1 : 0
  repository = local.flux["create_github_repository"] ? github_repository.main[0].name : data.github_repository.main[0].name
  branch     = local.flux["branch"]  
}

output "data_github" {
  value = data.github_repository.main[0]  
}

resource "kubernetes_network_policy" "flux_allow_monitoring" {
  count      = local.flux["enabled"] && local.flux["default_network_policy"] ? 1 : 0 

  metadata {
    name      = "${local.flux["create_ns"] ? kubernetes_namespace.flux.*.metadata.0.name[count.index] : local.flux["namespace"]}-allow-monitoring"
    namespace = local.flux["create_ns"] ? kubernetes_namespace.flux.*.metadata.0.name[count.index] : local.flux["namespace"]
  }

  spec {
    pod_selector {
    }
    
    ingress {
      
      ports {
        port    = "8080"
        protocol = "TCP"
      }

      from {
        namespace_selector {
          match_labels = {
            "${local.labels_prefix}/component" = "monitoring"
          }
        }
      }
    }

    policy_types = [ "Ingress" ]
  } 
}

resource "kubernetes_network_policy" "flux_allow_namespace" {
  count = local.flux["enabled"] && local.flux["default_network_policy"] ? 1 : 0

  metadata {
    name      = "${local.flux["create_ns"] ? kubernetes_namespace.flux.*.metadata.0.name[count.index] : local.flux["namespace"]}-allow-namespace"
    namespace = local.flux["create_ns"] ? kubernetes_namespace.flux.*.metadata.0.name[count.index] : local.flux["namespace"]
  }


  spec {
    pod_selector{
    }

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = local.flux["create_ns"] ? kubernetes_namespace.flux.*.metadata.0.name[count.index] : local.flux["namespace"]
          }
        }
      }
    }

    policy_types = [ "Ingress" ]
  }  
  
}