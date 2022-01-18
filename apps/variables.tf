variable "flux_token" {
  type = string
  }

variable "target_path" {
  default = "apps"
}

variable "repo_url" {
  }

variable "repository_name" {
  default = "CTK"
  }

variable "branch" {
  default = "main"
}

variable "default_components" {
  type = list
}

variable "components" {
  type = list
}

variable "repo_provider" {

}

variable "flux3" {
  description = "Customize Flux chart, see `flux2.tf` for supported values"
  type        = any
  default     = {}
}

variable "labels_prefix" {
  description = "Custom label prefix used for network policy namespace matching"
  type        = string
  default     = "project.eks"
}

variable "bucket" {}
variable "key" {}
variable "region" {}
variable "github_owner" {
  default = "catd87"
}