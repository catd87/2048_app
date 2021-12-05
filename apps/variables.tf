variable "flux_token" {
  type = string
  }

variable "labels_prefix" {
  default = "local_var_flux"
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

variable "flux" {
  description = "Customize Flux chart, see `flux2.tf` for supported values"
  type        = any
  default     = {}
}

variable "labels_prefix" {
  description = "Custom label prefix used for network policy namespace matching"
  type        = string
  default     = {}
}

variable "bucket" {}
variable "key" {}
variable "region" {}